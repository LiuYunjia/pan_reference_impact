#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/00-library.sh"

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 TOOL ARRAY_INDEX" >&2
    exit 2
fi

tool="$1"
row_index="$2"
root="$(project_root)"
build="$(genome_field "$row_index" 1)"
fasta="$root/references/$build/$build.fa"
bindir="$root/tools/aligners/bin"
outdir="$root/indexes/$build/$tool"
threads="${SLURM_CPUS_PER_TASK:-1}"

require_file "$root/tools/.complete"
require_file "$root/references/$build/.complete"
require_file "$fasta"
mkdir -p "$outdir"

case "$tool" in
    minimap2)
        for preset in map-ont map-hifi map-pb; do
            "$bindir/minimap2" -x "$preset" -t "$threads" \
                -d "$outdir/$build.$preset.mmi" "$fasta"
            require_file "$outdir/$build.$preset.mmi"
        done
        ;;
    minibwa)
        "$bindir/minibwa" index -t "$threads" "$fasta" "$outdir/$build"
        require_file "$outdir/$build.l2b"
        require_file "$outdir/$build.mbw"
        ;;
    ngmlr)
        for preset in ont pacbio; do
            preset_dir="$outdir/$preset"
            mkdir -p "$preset_dir"
            ln -f "$fasta" "$preset_dir/$build.fa"
            printf '>index_probe\nACGTACGTACGTACGTACGTACGTACGTACGT\n' > "$preset_dir/index-probe.fa"
            "$bindir/ngmlr" -x "$preset" -t "$threads" -r "$preset_dir/$build.fa" \
                -q "$preset_dir/index-probe.fa" -o "$preset_dir/index-probe.sam"
            if ! find "$preset_dir" -maxdepth 1 -type f -name '*.ngm' -print -quit | grep -q .; then
                echo "NGMLR produced no $preset .ngm index files" >&2
                exit 1
            fi
        done
        ;;
    lra)
        for preset in ONT CCS CLR; do
            preset_dir="$outdir/$(printf '%s' "$preset" | tr '[:upper:]' '[:lower:]')"
            mkdir -p "$preset_dir"
            ln -f "$fasta" "$preset_dir/$build.fa"
            "$bindir/lra" index "-$preset" "$preset_dir/$build.fa"
            if ! find "$preset_dir" -maxdepth 1 -type f ! -name "$build.fa" -size +0c -print -quit | grep -q .; then
                echo "LRA produced no $preset index files" >&2
                exit 1
            fi
        done
        ;;
    winnowmap)
        db="$outdir/$build.k15.meryl"
        mask="$outdir/$build.repetitive-k15.txt"
        "$bindir/meryl" count k=15 threads="$threads" output "$db" "$fasta"
        "$bindir/meryl" print greater-than distinct=0.9998 "$db" > "$mask"
        require_file "$mask"
        for preset in map-ont map-pb; do
            "$bindir/winnowmap" -W "$mask" -x "$preset" -t "$threads" \
                -d "$outdir/$build.$preset.wmi" "$fasta"
            require_file "$outdir/$build.$preset.wmi"
        done
        ;;
    *)
        echo "Unsupported tool: $tool" >&2
        exit 2
        ;;
esac

printf 'complete\n' > "$outdir/.complete"
write_file_manifest "$build" "$tool" "$outdir"
