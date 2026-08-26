#!/bin/bash
#SBATCH --job-name=lift-faidx
#SBATCH --array=0-6%7
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --output=logs/%x_%A_%a.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/07-prepare-liftover-reference.sh "${SLURM_ARRAY_TASK_ID:?}"
