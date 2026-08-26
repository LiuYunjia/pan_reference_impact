#!/usr/bin/env bash

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mkdir -p logs state

tools_job="$(sbatch --parsable slurm/01-install-index-tools.slurm)"
refs_job="$(sbatch --parsable slurm/02-download-reference.slurm)"
base_dependency="afterok:${tools_job}:${refs_job}"

minimap2_job="$(sbatch --parsable --dependency="$base_dependency" slurm/03-minimap2-index.slurm)"
minibwa_job="$(sbatch --parsable --dependency="$base_dependency" slurm/03-minibwa-index.slurm)"
ngmlr_job="$(sbatch --parsable --dependency="$base_dependency" slurm/03-ngmlr-index.slurm)"
lra_job="$(sbatch --parsable --dependency="$base_dependency" slurm/03-lra-index.slurm)"
winnowmap_job="$(sbatch --parsable --dependency="$base_dependency" slurm/03-winnowmap-index.slurm)"
final_dependency="afterok:${minimap2_job}:${minibwa_job}:${ngmlr_job}:${lra_job}:${winnowmap_job}"
manifest_job="$(sbatch --parsable --dependency="$final_dependency" slurm/04-finalize-index-manifest.slurm)"

{
    printf 'stage\tjob_id\tdependency\n'
    printf 'tools\t%s\t-\n' "$tools_job"
    printf 'references\t%s\t-\n' "$refs_job"
    printf 'minimap2\t%s\t%s\n' "$minimap2_job" "$base_dependency"
    printf 'minibwa\t%s\t%s\n' "$minibwa_job" "$base_dependency"
    printf 'ngmlr\t%s\t%s\n' "$ngmlr_job" "$base_dependency"
    printf 'lra\t%s\t%s\n' "$lra_job" "$base_dependency"
    printf 'winnowmap\t%s\t%s\n' "$winnowmap_job" "$base_dependency"
    printf 'manifest\t%s\t%s\n' "$manifest_job" "$final_dependency"
} > state/submitted-jobs.tsv

cat state/submitted-jobs.tsv
