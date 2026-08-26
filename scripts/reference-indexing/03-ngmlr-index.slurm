#!/bin/bash
#SBATCH --job-name=refidx-ngmlr
#SBATCH --array=0-6%7
#SBATCH --time=10:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --output=logs/%x_%A_%a.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/03-build-index.sh ngmlr "${SLURM_ARRAY_TASK_ID:?}"
