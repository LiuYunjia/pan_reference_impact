#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 5 ]]; then
    echo "Usage: $0 APPLET_ID [INSTANCE_TYPE] [--submit|--dry-run] [BUILDS] [PRIORITY]" >&2
    echo "BUILDS is all or a comma-separated subset such as hg38 or hg15,hg16,hs1" >&2
    echo "PRIORITY is low, normal, or high; default: normal" >&2
    exit 2
fi

applet_id="$1"
instance_type="${2:-mem2_ssd1_v2_x32}"
mode="${3:---dry-run}"
build_selector="${4:-all}"
priority="${5:-normal}"
project_id="project-JB6zPY00Z7Q7KBpj1P5yKYv4"
root="$(cd "$(dirname "$0")/.." && pwd)"
builds_tsv="$root/config/dnanexus-minimap2-hg002.tsv"
reads_tsv="$root/config/dnanexus-hg002-ccs-15x-files.tsv"
subset_file="$project_id:/config/subset_cells_15x.txt"

[[ "$applet_id" =~ ^applet-[A-Za-z0-9]{24}$ ]] || {
    echo "Invalid applet ID: $applet_id" >&2
    exit 2
}
[[ "$mode" == "--submit" || "$mode" == "--dry-run" ]] || {
    echo "Third argument must be --submit or --dry-run" >&2
    exit 2
}
[[ "$priority" == "low" || "$priority" == "normal" || "$priority" == "high" ]] || {
    echo "Fifth argument must be low, normal, or high" >&2
    exit 2
}
if [[ "$build_selector" != "all" ]]; then
    IFS=',' read -r -a requested_builds <<< "$build_selector"
    for requested_build in "${requested_builds[@]}"; do
        case "$requested_build" in
            hg15|hg16|hg17|hg18|hg19|hg38|hs1) ;;
            *) echo "Unsupported requested build: $requested_build" >&2; exit 2 ;;
        esac
    done
fi
[[ "$(awk 'END {print NR-1}' "$reads_tsv")" -eq 20 ]]

read_args=()
while IFS=$'\t' read -r name file_id size_bytes; do
    [[ "$file_id" =~ ^file-[A-Za-z0-9]{24}$ ]]
    read_args+=("-ireads=$file_id")
done < <(tail -n +2 "$reads_tsv")

while IFS=$'\t' read -r build index_bundle_id index_bundle_sha256; do
    if [[ "$build_selector" != "all" && ",$build_selector," != *",$build,"* ]]; then
        continue
    fi
    cmd=(dx run "$applet_id"
        --destination "$project_id:/results/minimap2/$build"
        --name "HG002-CCS15x-minimap2-2.31-$build"
        --instance-type "$instance_type"
        --priority "$priority"
        -ibuild="$build"
        -isubset_manifest="$subset_file"
        -iindex_bundle="$index_bundle_id"
        -iexpected_index_sha256="$index_bundle_sha256"
        -imapper_threads=26
        -isort_threads=4
        -isort_memory_gib=3
        "${read_args[@]}"
        --brief
        --yes)

    if [[ "$mode" == "--submit" ]]; then
        run_output="$("${cmd[@]}")"
        if [[ "$run_output" =~ ^job-[A-Za-z0-9]{24}$ ]]; then
            printf '%s\n' "$run_output"
        else
            printf '%s\n' "$run_output" | jq -er '.id | select(startswith("job-"))'
        fi
    else
        printf '%q ' "${cmd[@]}"
        printf '\n'
    fi
done < <(tail -n +2 "$builds_tsv")
