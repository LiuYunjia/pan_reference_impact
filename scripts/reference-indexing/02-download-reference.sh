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
assembly="$(genome_field "$row_index" 2)"
source_type="$(genome_field "$row_index" 3)"
source_url="$(genome_field "$row_index" 4)"
outdir="$root/references/$build"
fasta="$outdir/$build.fa"

mkdir -p "$outdir" "$root/artifacts/manifests"

if [[ "$source_type" == "fa.gz" ]]; then
    archive="$outdir/$build.fa.gz"
    curl --fail --location --retry 8 --retry-delay 15 --continue-at - \
        "$source_url" --output "$archive"
    gzip -t "$archive"
    gzip -dc "$archive" > "${fasta}.part"
else
    archive="$outdir/chromFa.zip"
    extract_dir="$outdir/chromFa"
    curl --fail --location --retry 8 --retry-delay 15 --continue-at - \
        "$source_url" --output "$archive"
    unzip -t "$archive"
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"
    unzip -q "$archive" -d "$extract_dir"
    mapfile -d '' fasta_parts < <(find "$extract_dir" -type f -name '*.fa' -print0 | sort -zV)
    if [[ ${#fasta_parts[@]} -eq 0 ]]; then
        echo "No FASTA records found in $archive" >&2
        exit 1
    fi
    : > "${fasta}.part"
    for fasta_part in "${fasta_parts[@]}"; do
        sed -e '$a\' "$fasta_part" >> "${fasta}.part"
    done
fi

if ! awk 'BEGIN { seen=0 } /^>/ { seen=1; next } /^[A-Za-z*-]+$/ { next } { exit 1 } END { exit !seen }' \
    "${fasta}.part"; then
    echo "FASTA validation failed for $build" >&2
    exit 1
fi
mv "${fasta}.part" "$fasta"

sha256sum "$archive" > "$archive.sha256"
sha256sum "$fasta" > "$fasta.sha256"
{
    printf 'build\tassembly\tsource_url\tarchive\tfasta\n'
    printf '%s\t%s\t%s\t%s\t%s\n' "$build" "$assembly" "$source_url" "$archive" "$fasta"
} > "$outdir/source.tsv"
printf 'complete\n' > "$outdir/.complete"
write_file_manifest "$build" reference "$outdir"
