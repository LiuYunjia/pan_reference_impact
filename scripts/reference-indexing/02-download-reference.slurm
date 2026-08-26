#!/bin/bash
#SBATCH --job-name=refidx-ref
#SBATCH --array=0-6%7
#SBATCH --time=06:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --output=logs/%x_%A_%a.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/02-download-reference.sh "${SLURM_ARRAY_TASK_ID:?}"
