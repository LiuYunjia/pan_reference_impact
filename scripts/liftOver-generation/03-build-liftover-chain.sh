#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/00-library.sh"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 ARRAY_INDEX" >&2
    exit 2
fi

row_index="$1"
root="$(project_root)"
source_build="$(awk -F '\t' -v row="$((row_index + 2))" 'NR == row {print $1}' "$root/config/liftover-pairs.tsv")"
target_build="$(awk -F '\t' -v row="$((row_index + 2))" 'NR == row {print $2}' "$root/config/liftover-pairs.tsv")"
source_fasta="$root/references/$source_build/$source_build.fa"
target_fasta="$root/references/$target_build/$target_build.fa"
source_sizes="$root/liftover/references/$source_build/$source_build.chrom.sizes"
target_sizes="$root/liftover/references/$target_build/$target_build.chrom.sizes"
bindir="$root/tools/liftover/bin"
target_label="${target_build^}"
pair_name="${source_build}To${target_label}"
outdir="$root/liftover/chains/$source_build/$target_build"
threads="${SLURM_CPUS_PER_TASK:-1}"

require_file "$root/tools/liftover.complete"
require_file "$source_fasta"
require_file "$target_fasta"
require_file "$source_sizes"
require_file "$target_sizes"
mkdir -p "$outdir"

scratch_base="${SLURM_TMPDIR:-/tmp}"
workdir="$(mktemp -d "$scratch_base/liftover.${source_build}.${target_build}.XXXXXX")"
trap 'rm -rf "$workdir"' EXIT
paf="$workdir/$pair_name.paf"
chain="$workdir/$pair_name.over.chain"

"$bindir/minimap2" -cx asm5 --cs -t "$threads" \
    "$target_fasta" "$source_fasta" > "$paf"
require_file "$paf"
"$bindir/transanno" minimap2chain "$paf" --output "$chain"
require_file "$chain"

awk 'NR==FNR {size[$1]=$2; next}
     $1=="chain" {n++; if (!($3 in size) || size[$3] != $4 || $5 != "+") bad=1}
     END {if (n==0 || bad) exit 1}' "$source_sizes" "$chain"
awk 'NR==FNR {size[$1]=$2; next}
     $1=="chain" {n++; if (!($8 in size) || size[$8] != $9) bad=1}
     END {if (n==0 || bad) exit 1}' "$target_sizes" "$chain"

"$bindir/pigz" -1 -p "$threads" -c "$paf" > "$outdir/$pair_name.paf.gz.part"
gzip -n -9 -c "$chain" > "$outdir/$pair_name.over.chain.gz.part"
mv "$outdir/$pair_name.paf.gz.part" "$outdir/$pair_name.paf.gz"
mv "$outdir/$pair_name.over.chain.gz.part" "$outdir/$pair_name.over.chain.gz"
gzip -t "$outdir/$pair_name.paf.gz"
gzip -t "$outdir/$pair_name.over.chain.gz"

sha256sum "$outdir/$pair_name.paf.gz" > "$outdir/$pair_name.paf.gz.sha256"
sha256sum "$outdir/$pair_name.over.chain.gz" > "$outdir/$pair_name.over.chain.gz.sha256"
{
    printf 'source\ttarget\taligner\tpreset\tconverter\tpaf\tchain\n'
    printf '%s\t%s\tminimap2 2.31\tasm5 --cs\ttransanno 0.4.5\t%s\t%s\n' \
        "$source_build" "$target_build" "$outdir/$pair_name.paf.gz" \
        "$outdir/$pair_name.over.chain.gz"
} > "$outdir/provenance.tsv"
{
    printf 'metric\tvalue\n'
    printf 'paf_records\t%s\n' "$(wc -l < "$paf")"
    printf 'chain_records\t%s\n' "$(awk '$1=="chain" {n++} END {print n+0}' "$chain")"
    printf 'chain_aligned_block_bases\t%s\n' \
        "$(awk '$1!="chain" && NF>0 {sum+=$1} END {print sum+0}' "$chain")"
} > "$outdir/summary.tsv"
printf 'complete\n' > "$outdir/.complete"
write_file_manifest "$pair_name" liftover "$outdir"
