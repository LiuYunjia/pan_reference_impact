#!/usr/bin/env bash

set -euo pipefail

project_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

genome_field() {
    local row_index="$1"
    local column="$2"
    local root
    root="$(project_root)"
    awk -F '\t' -v row="$((row_index + 2))" -v col="$column" 'NR == row { print $col }' \
        "$root/config/genomes.tsv"
}

require_file() {
    if [[ ! -s "$1" ]]; then
        echo "Required nonempty file is missing: $1" >&2
        exit 1
    fi
}

write_file_manifest() {
    local build="$1"
    local tool="$2"
    local target="$3"
    local root manifest
    root="$(project_root)"
    manifest="$root/artifacts/manifests/${build}.${tool}.tsv"
    mkdir -p "$(dirname "$manifest")"
    {
        printf 'path\ttype\tsize_bytes\tmodified\n'
        find "$target" -mindepth 1 -printf '%p\t%y\t%s\t%TY-%Tm-%TdT%TH:%TM:%TS%Tz\n' | sort
    } > "${manifest}.part"
    mv "${manifest}.part" "$manifest"
}
