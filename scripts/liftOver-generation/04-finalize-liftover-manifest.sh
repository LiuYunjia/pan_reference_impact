#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
manifest="$root/artifacts/FILE-MANIFEST.tsv"
mkdir -p "$root/artifacts"

{
    printf 'path\ttype\tsize_bytes\tmodified\n'
    find "$root/references" "$root/indexes" "$root/tools" "$root/artifacts/manifests" \
        -mindepth 1 -printf '%p\t%y\t%s\t%TY-%Tm-%TdT%TH:%TM:%TS%Tz\n' | sort
} > "${manifest}.part"
mv "${manifest}.part" "$manifest"
printf 'complete\n' > "$root/artifacts/.complete"
