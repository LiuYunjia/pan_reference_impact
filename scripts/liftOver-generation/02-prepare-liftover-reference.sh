#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/00-library.sh"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 ARRAY_INDEX" >&2
    exit 2
fi

row_index="$1"
root="$(project_root)"
build="$(genome_field "$row_index" 1)"
fasta="$root/references/$build/$build.fa"
bindir="$root/tools/liftover/bin"
outdir="$root/liftover/references/$build"

require_file "$root/tools/liftover.complete"
require_file "$root/references/$build/.complete"
require_file "$fasta"
mkdir -p "$outdir"

"$bindir/samtools" faidx "$fasta"
require_file "$fasta.fai"
cut -f 1,2 "$fasta.fai" > "$outdir/$build.chrom.sizes"
require_file "$outdir/$build.chrom.sizes"
printf 'complete\n' > "$outdir/.complete"
write_file_manifest "$build" liftover-reference "$outdir"
