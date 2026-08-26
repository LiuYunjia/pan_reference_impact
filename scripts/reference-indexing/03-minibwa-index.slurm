#!/bin/bash
#SBATCH --job-name=refidx-minibwa
#SBATCH --array=0-6%4
#SBATCH --time=11:55:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=96G
#SBATCH --output=logs/%x_%A_%a.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/03-build-index.sh minibwa "${SLURM_ARRAY_TASK_ID:?}"
