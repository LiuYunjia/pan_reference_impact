#!/bin/bash
#SBATCH --job-name=refidx-tools
#SBATCH --time=04:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=24G
#SBATCH --output=logs/%x_%j.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/01-install-index-tools.sh
