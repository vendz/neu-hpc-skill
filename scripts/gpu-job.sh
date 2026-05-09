#!/bin/bash
#===============================================================================
# GPU Batch Job Template for NEU Explorer HPC
# Usage: sbatch scripts/gpu-job.sh
# Customize the SBATCH directives and the commands section below.
#===============================================================================

#SBATCH --job-name=gpu_train          # Short descriptive name
#SBATCH --partition=gpu               # gpu (1 GPU, 8h max) or gpu-interactive (1 GPU, 8h, interactive)
#SBATCH --nodes=1                     # Number of nodes (1 for single-GPU)
#SBATCH --ntasks=1                    # Number of tasks
#SBATCH --gres=gpu:v100-sxm2:1       # GPU type:count. Options: v100-sxm2, v100-pcie, h200, or just gpu:1 for any
#SBATCH --cpus-per-task=4             # CPU cores per task (2-8 typical for GPU jobs)
#SBATCH --mem=32G                     # CPU memory (not GPU memory)
#SBATCH --time=08:00:00              # Max wall time HH:MM:SS
#SBATCH --output=logs/%j_%x.out       # Stdout: %j=jobid, %x=jobname
#SBATCH --error=logs/%j_%x.err        # Stderr
##SBATCH --mail-type=END,FAIL          # Uncomment to get email on job end/fail
##SBATCH --mail-user=$USER@northeastern.edu

#--- Environment Setup --------------------------------------------------------
module purge
module load explorer anaconda3/2024.06 cuda/12.1.1

source activate /scratch/$USER/conda_envs/pytorch_env

#--- Pre-flight Checks --------------------------------------------------------
echo "=========================================="
echo "Job ID:        $SLURM_JOB_ID"
echo "Job Name:      $SLURM_JOB_NAME"
echo "Node:          $(hostname)"
echo "Partition:     $SLURM_JOB_PARTITION"
echo "GPUs:          $CUDA_VISIBLE_DEVICES"
echo "Start Time:    $(date)"
echo "Working Dir:   $(pwd)"
echo "Python:        $(which python)"
echo "PyTorch CUDA:  $(python -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null || echo 'N/A')"
echo "=========================================="

nvidia-smi

#--- Main Execution -----------------------------------------------------------
# Replace with your training command
python train.py \
    --epochs 50 \
    --batch-size 64 \
    --lr 1e-4 \
    --output-dir /scratch/$USER/results/$SLURM_JOB_ID

#--- Post-job -----------------------------------------------------------------
echo "=========================================="
echo "End Time:      $(date)"
echo "=========================================="
