#!/usr/bin/env bash
# Standalone re-download of one raw reference FASTA from UCSC goldenPath.
# Source URLs come from the reference-assets build pipeline's config/genomes.tsv
# (Group4_2026:/reference-assets/releases/2026-08-25/provenance/build-workflow-scripts.tar.zst).

set -euo pipefail

BUILD="${1:?Usage: $0 BUILD   (e.g. hs1, hg38, hg19, hg18, hg17, hg16, hg15)}"
GENOMES_TSV="$(dirname "$0")/../config/genomes.tsv"
OUTDIR="${BUILD}"

row=$(awk -F'\t' -v b="$BUILD" '$1 == b { print; found=1 } END { exit !found }' "$GENOMES_TSV") \
    || { echo "ERROR: build '$BUILD' not found in $GENOMES_TSV" >&2; exit 1; }
IFS=$'\t' read -r _ assembly source_type source_url <<<"$row"

mkdir -p "$OUTDIR"
FASTA="$OUTDIR/$BUILD.fa"
echo "[download_reference] $BUILD ($assembly) <- $source_url"

if [[ "$source_type" == "fa.gz" ]]; then
    ARCHIVE="$OUTDIR/$BUILD.fa.gz"
    curl --fail --location --retry 8 --retry-delay 15 --continue-at - \
        "$source_url" --output "$ARCHIVE"
    gzip -t "$ARCHIVE"
    gzip -dc "$ARCHIVE" > "${FASTA}.part"
else
    ARCHIVE="$OUTDIR/chromFa.zip"
    EXTRACT_DIR="$OUTDIR/chromFa"
    curl --fail --location --retry 8 --retry-delay 15 --continue-at - \
        "$source_url" --output "$ARCHIVE"
    unzip -t "$ARCHIVE"
    rm -rf "$EXTRACT_DIR" && mkdir -p "$EXTRACT_DIR"
    unzip -q "$ARCHIVE" -d "$EXTRACT_DIR"
    mapfile -d '' fasta_parts < <(find "$EXTRACT_DIR" -type f -name '*.fa' -print0 | sort -zV)
    [[ ${#fasta_parts[@]} -gt 0 ]] || { echo "ERROR: no FASTA records found in $ARCHIVE" >&2; exit 1; }
    : > "${FASTA}.part"
    for part in "${fasta_parts[@]}"; do
        sed -e '$a\' "$part" >> "${FASTA}.part"
    done
fi

mv "${FASTA}.part" "$FASTA"
sha256sum "$ARCHIVE" "$FASTA" > "$OUTDIR/$BUILD.sha256"
echo "[download_reference] done: $FASTA"
