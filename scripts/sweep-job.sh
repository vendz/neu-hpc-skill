#!/bin/bash
#===============================================================================
# Hyperparameter Sweep via Slurm Job Array
# Usage: sbatch scripts/sweep-job.sh
#
# Each array task reads its hyperparams from a config file or uses
# SLURM_ARRAY_TASK_ID to index into parameter combinations.
#===============================================================================

#SBATCH --job-name=hp_sweep
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/sweep_%A_%a.out
#SBATCH --error=logs/sweep_%A_%a.err
#SBATCH --array=1-12%4

# --array=1-12%4 means:
#   - 12 total jobs (task IDs 1 through 12)
#   - At most 4 running concurrently
#   - Each job gets its OWN allocation of the resources above

#--- Environment Setup --------------------------------------------------------
module purge
module load explorer anaconda3/2024.06 cuda/12.1.1
source activate /scratch/$USER/conda_envs/pytorch_env

#--- Hyperparameter Configuration ---------------------------------------------
# Option A: Define arrays and index by task ID
LEARNING_RATES=(1e-2 1e-3 1e-4 5e-4)
BATCH_SIZES=(16 32 64)

# Calculate indices (0-based)
NUM_LR=${#LEARNING_RATES[@]}
NUM_BS=${#BATCH_SIZES[@]}
TASK_IDX=$(( SLURM_ARRAY_TASK_ID - 1 ))
LR_IDX=$(( TASK_IDX / NUM_BS ))
BS_IDX=$(( TASK_IDX % NUM_BS ))

LR=${LEARNING_RATES[$LR_IDX]}
BS=${BATCH_SIZES[$BS_IDX]}

# Option B: Read from a CSV config file (uncomment to use instead)
# CONFIG_FILE="configs/sweep_params.csv"
# LR=$(sed -n "${SLURM_ARRAY_TASK_ID}p" $CONFIG_FILE | cut -d',' -f1)
# BS=$(sed -n "${SLURM_ARRAY_TASK_ID}p" $CONFIG_FILE | cut -d',' -f2)

#--- Logging ------------------------------------------------------------------
RESULTS_DIR="/scratch/$USER/results/sweep_${SLURM_ARRAY_JOB_ID}"
RUN_DIR="${RESULTS_DIR}/run_${SLURM_ARRAY_TASK_ID}"
mkdir -p "$RUN_DIR"

echo "=========================================="
echo "Sweep Job ${SLURM_ARRAY_JOB_ID}, Task ${SLURM_ARRAY_TASK_ID}"
echo "LR: $LR | Batch Size: $BS"
echo "Node: $(hostname) | GPU: $CUDA_VISIBLE_DEVICES"
echo "Output: $RUN_DIR"
echo "Start: $(date)"
echo "=========================================="

#--- Main Execution -----------------------------------------------------------
python train.py \
    --lr $LR \
    --batch-size $BS \
    --epochs 20 \
    --output-dir "$RUN_DIR" \
    --run-id "${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"

#--- Post-job -----------------------------------------------------------------
echo "=========================================="
echo "End: $(date)"
echo "Results saved to: $RUN_DIR"
echo "=========================================="
