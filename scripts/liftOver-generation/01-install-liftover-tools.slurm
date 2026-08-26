#!/bin/bash
#SBATCH --job-name=lift-tools
#SBATCH --time=02:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=logs/%x_%j.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/06-install-liftover-tools.sh
