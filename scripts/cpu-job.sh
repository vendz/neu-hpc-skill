#!/bin/bash
#===============================================================================
# CPU Batch Job Template for NEU Explorer HPC
# Usage: sbatch scripts/cpu-job.sh
# Customize the SBATCH directives and the commands section below.
#===============================================================================

#SBATCH --job-name=cpu_job            # Short descriptive name
#SBATCH --partition=short             # short (24h), express (1h), debug (20min)
#SBATCH --nodes=1                     # Number of nodes (max 2 on short)
#SBATCH --ntasks=1                    # Number of tasks
#SBATCH --cpus-per-task=4             # CPU cores
#SBATCH --mem=16G                     # Memory per node
#SBATCH --time=04:00:00              # Max wall time HH:MM:SS
#SBATCH --output=logs/%j_%x.out       # Stdout
#SBATCH --error=logs/%j_%x.err        # Stderr
##SBATCH --mail-type=END,FAIL          # Uncomment to get email on job end/fail
##SBATCH --mail-user=$USER@northeastern.edu

#--- Environment Setup --------------------------------------------------------
module load anaconda3/2024.06

source activate /scratch/$USER/conda_envs/ml_env

#--- Pre-flight Checks --------------------------------------------------------
echo "=========================================="
echo "Job ID:        $SLURM_JOB_ID"
echo "Job Name:      $SLURM_JOB_NAME"
echo "Node:          $(hostname)"
echo "Partition:     $SLURM_JOB_PARTITION"
echo "CPUs:          $SLURM_CPUS_PER_TASK"
echo "Memory:        $SLURM_MEM_PER_NODE MB"
echo "Start Time:    $(date)"
echo "Working Dir:   $(pwd)"
echo "Python:        $(which python)"
echo "=========================================="

#--- Main Execution -----------------------------------------------------------
# Replace with your command
python process_data.py \
    --input /scratch/$USER/data/raw \
    --output /scratch/$USER/data/processed

#--- Post-job -----------------------------------------------------------------
echo "=========================================="
echo "End Time:      $(date)"
echo "=========================================="
