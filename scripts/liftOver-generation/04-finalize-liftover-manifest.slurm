#!/bin/bash
#SBATCH --job-name=lift-manifest
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=logs/%x_%j.log

set -euo pipefail
cd "${SLURM_SUBMIT_DIR:?}"
bash scripts/09-finalize-liftover-manifest.sh
