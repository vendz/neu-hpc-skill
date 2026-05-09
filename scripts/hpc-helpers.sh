#!/bin/bash
#===============================================================================
# HPC Helper Functions for NEU Explorer
# Source this file: source scripts/hpc-helpers.sh
# Or add to your .bashrc: source ~/scripts/hpc-helpers.sh
#===============================================================================

# Quick interactive GPU session (default: 1 V100, 2h, 10GB RAM)
gpu-shell() {
    local gpu_type="${1:-v100-sxm2}"
    local time="${2:-02:00:00}"
    local mem="${3:-10GB}"
    echo "Requesting GPU node: $gpu_type | Time: $time | Mem: $mem"
    srun --partition=gpu-interactive --nodes=1 --ntasks=1 \
         --gres=gpu:${gpu_type}:1 --cpus-per-task=2 \
         --mem=$mem --time=$time --pty /bin/bash
}

# Quick interactive CPU session (default: 2h, 4GB RAM, short partition)
cpu-shell() {
    local time="${1:-02:00:00}"
    local mem="${2:-4G}"
    local cpus="${3:-2}"
    echo "Requesting CPU node: CPUs=$cpus | Time: $time | Mem: $mem"
    srun --partition=short --nodes=1 --ntasks=1 \
         --cpus-per-task=$cpus --mem=$mem --time=$time --pty /bin/bash
}

# H200 interactive session
h200-shell() {
    local time="${1:-01:00:00}"
    local mem="${2:-10GB}"
    echo "Requesting H200 node: Time: $time | Mem: $mem"
    srun --partition=gpu-interactive --nodes=1 --ntasks=1 \
         --gres=gpu:h200:1 --cpus-per-task=2 \
         --mem=$mem --time=$time --pty /bin/bash
}

# Show my jobs (formatted)
myjobs() {
    echo "=== Jobs for $USER ==="
    squeue -u $USER --format="%.10i %.12P %.30j %.8T %.12M %.4D %.4C %.8m %R"
}

# Watch my jobs (refreshes every 10s)
watchjobs() {
    watch -n 10 'squeue -u $USER --format="%.10i %.12P %.30j %.8T %.12M %.4D %.4C %.8m %R"'
}

# Tail the latest output log in ./logs/
taillog() {
    local logfile=$(ls -t logs/*.out 2>/dev/null | head -1)
    if [ -z "$logfile" ]; then
        echo "No .out files found in logs/"
        return 1
    fi
    echo "Tailing: $logfile"
    tail -f "$logfile"
}

# Show GPU partition availability
gpu-status() {
    echo "=== GPU Partition Status ==="
    sinfo -p gpu --Format=partition,avail,timelimit,nodes,statecompact,nodelist,gres
    echo ""
    echo "=== GPU-Interactive Partition Status ==="
    sinfo -p gpu-interactive --Format=partition,avail,timelimit,nodes,statecompact,nodelist,gres
}

# Quick disk usage check (must be on compute node)
diskusage() {
    echo "=== Home Directory ==="
    du -sh /home/$USER/ 2>/dev/null
    echo ""
    echo "=== Scratch ==="
    du -sh /scratch/$USER/ 2>/dev/null
    echo ""
    echo "=== Conda Envs ==="
    du -sh /scratch/$USER/conda_envs/*/ 2>/dev/null
    echo ""
    echo "Run 'check-quota' for official quota numbers."
}

# Cancel all my jobs
cancelall() {
    read -p "Cancel ALL your jobs? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        scancel -u $USER
        echo "All jobs cancelled."
    else
        echo "Cancelled."
    fi
}

# Load standard ML modules
ml-modules() {
    module purge
    module load explorer anaconda3/2024.06 cuda/12.1.1
    echo "Loaded: explorer, anaconda3/2024.06, cuda/12.1.1"
}

echo "HPC helpers loaded. Available commands:"
echo "  gpu-shell [type] [time] [mem]  - Interactive GPU session"
echo "  cpu-shell [time] [mem] [cpus]  - Interactive CPU session"
echo "  h200-shell [time] [mem]        - Interactive H200 session"
echo "  myjobs                         - Show your jobs"
echo "  watchjobs                      - Live job monitor"
echo "  taillog                        - Tail latest log"
echo "  gpu-status                     - GPU partition info"
echo "  diskusage                      - Disk usage summary"
echo "  cancelall                      - Cancel all your jobs"
echo "  ml-modules                     - Load ML module stack"
