#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
base_manifest_job="${1:-}"
cd "$root"
mkdir -p logs state

tools_job="$(sbatch --parsable slurm/06-install-liftover-tools.slurm)"
references_job="$(sbatch --parsable --dependency="afterok:${tools_job}" slurm/07-prepare-liftover-reference.slurm)"
chains_job="$(sbatch --parsable --dependency="afterok:${tools_job}:${references_job}" slurm/08-build-liftover-chain.slurm)"

state_file="state/submitted-liftover-jobs.tsv"
{
    printf 'stage\tjob_id\tdependency\n'
    printf 'liftover-tools\t%s\t-\n' "$tools_job"
    printf 'liftover-references\t%s\tafterok:%s\n' "$references_job" "$tools_job"
    printf 'liftover-chains\t%s\tafterok:%s:%s\n' "$chains_job" "$tools_job" "$references_job"
} > "$state_file"

if [[ -n "$base_manifest_job" ]]; then
    base_state="$(sacct -X -n -j "$base_manifest_job" --format=State | awk 'NF {print $1; exit}')"
    base_state="${base_state%%+*}"
    case "$base_state" in
        COMPLETED)
            manifest_dependency="afterok:${chains_job}"
            ;;
        PENDING|RUNNING|CONFIGURING|COMPLETING)
            manifest_dependency="afterok:${chains_job}:${base_manifest_job}"
            ;;
        *)
            echo "Base manifest job $base_manifest_job is not successful/active: $base_state" >&2
            exit 1
            ;;
    esac
else
    manifest_dependency="afterok:${chains_job}"
fi
manifest_job="$(sbatch --parsable --dependency="$manifest_dependency" slurm/09-finalize-liftover-manifest.slurm)"

printf 'combined-manifest\t%s\t%s\n' "$manifest_job" "$manifest_dependency" >> "$state_file"

cat "$state_file"
