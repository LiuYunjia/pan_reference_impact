#!/bin/bash
#SBATCH --job-name=lift-chain
#SBATCH --array=0-41%8
#SBATCH --time=11:55:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=48G
#SBATCH --output=logs/%x_%A_%a.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/08-build-liftover-chain.sh "${SLURM_ARRAY_TASK_ID:?}"
