---
name: neu-hpc
description: >
  Use when the user wants to run jobs on the NEU Explorer HPC cluster, submit Slurm
  batch or interactive jobs, manage GPU training, set up conda environments, transfer
  files, check job status, or write sbatch scripts. Also use when the user mentions
  "HPC", "Explorer", "Slurm", "cluster", "GPU job", "sbatch", "srun", "compute node",
  "login node", or "partition".
---

# NEU Explorer HPC Cluster Skill

## Setup

**Before using this skill**, ask the user for their Explorer username if it's not already known from context (e.g., from SSH config or prior messages). All paths and commands below use `<username>` as a placeholder — substitute the actual username when generating commands.

## Connection Details

- **Host:** `login.explorer.northeastern.edu`
- **Protocol:** SSH (port 22)
- **SSH Command:** `ssh <username>@login.explorer.northeastern.edu`
- **SSH with X11:** `ssh -Y <username>@login.explorer.northeastern.edu`

## Critical Rules

1. **NEVER run compute-intensive tasks on login nodes.** Always submit via `srun` (interactive) or `sbatch` (batch).
2. **Always request only the resources you need** — over-requesting hurts your fair-share score AND increases queue wait time.
3. **`/scratch/<username>`** is purged monthly. Move important files to `/home/<username>` promptly.
4. **Home directory quota is 75GB.** Conda envs eat space fast; clean caches with `conda clean --all`.
5. **Load modules inside sbatch scripts or after getting a compute node**, not in `.bashrc`.
6. **The `explorer` module** loads automatically and sets the HTTP proxy. If accidentally purged, log out and back in.

## Fair-Share Scheduling

Explorer uses **fair-share scheduling** — your job priority depends on your group's recent resource usage.

| Factor | Effect on priority |
|---|---|
| High recent usage by your group | Priority decreases |
| Low recent usage by your group | Priority increases |
| Smaller job (fewer nodes) | Higher priority |
| Longer time in queue | Priority increases over time |

**Practical impact:**
- Every `srun` session you leave idle burns fair-share budget for the whole group — `scancel` when done.
- Don't request 8 GPUs "just in case" — each wasted resource-hour penalizes future jobs.
- Break large sweeps into smaller jobs; small jobs queue faster AND preserve fair-share.
- Check your group's current standing: `sshare -u <username>` (higher LevelFS = better priority).

## Filesystem Layout

| Path | Purpose | Quota / Policy |
|---|---|---|
| `/home/<username>` | Home directory, scripts, small configs | 75GB hard limit, cannot be increased |
| `/scratch/<username>` | Temporary job I/O, large intermediate files | Purged monthly, no backups |
| `/projects/<group>` | Persistent group storage (PI must request) | Not purged; contact rchelp@northeastern.edu |
| `/courses/<code>/students/<username>` | Course-specific workspace (if applicable) | Managed by instructor |

**Storage tips:**
- **Preferred for conda envs:** `/projects/<group>/envs/<name>` — persistent, not purged. PI must request `/projects` access first.
- **Alternative:** `/scratch/<username>/conda_envs/<name>` — avoid filling `/home` but envs lost on monthly purge.
- After a job, move any results you need to `/home` or `/projects` before the monthly scratch purge.
- Run `check-quota` from a compute node on the `short` partition to see usage.

## Partitions Quick Reference

| Partition | Max Time | Max Nodes | GPUs | Use Case |
|---|---|---|---|---|
| `short` | 24h | 2 | None | CPU jobs, conda setup, data processing |
| `express` | 1h | 2 | None | Quick tests |
| `debug` | 20min | 2 | None | Debugging |
| `gpu-interactive` | 8h | 1 | 1 GPU | Interactive GPU dev/testing |
| `gpu` | 8h | 1 | 1 GPU | Batch GPU training |
| `gpu-short` | varies | 1 | 1 GPU | Short GPU jobs (H200 accessible here) |
| `multigpu` | varies | varies | 2-8 GPUs | Multi-GPU (requires approval) |

## Module System

```bash
module avail              # List all available modules
module avail cuda         # Search for CUDA versions
module load <name/ver>    # Load a module
module list               # Show loaded modules
module purge              # Unload all (explorer reloads on next login)
module show <name/ver>    # Show module details and dependencies
module swap <m1> <m2>     # Replace m1 with m2
```

**Key modules for ML/AI work:**
- `anaconda3/2024.06` -- Conda package manager
- `cuda/12.1.1` or `cuda/12.3.0` -- CUDA toolkit
- `matlab/R2024b` -- MATLAB (if needed)

## Interactive Sessions (srun)

Use `srun` when you need a live shell on a compute node for testing, debugging, or installing packages.

**CPU interactive session:**
```bash
srun --partition=short --nodes=1 --ntasks=1 --cpus-per-task=2 --mem=4G --time=02:00:00 --pty /bin/bash
```

**CPU interactive session with X11 forwarding** (must also use `ssh -Y` to connect):
```bash
srun --partition=short --nodes=1 --ntasks=1 --x11 --mem=2G --time=00:30:00 --pty /bin/bash
```

**GPU interactive session:**
```bash
srun --partition=gpu-interactive --nodes=1 --ntasks=1 --gres=gpu:v100-sxm2:1 --cpus-per-task=2 --mem=10GB --time=02:00:00 --pty /bin/bash
```

**A100 GPU interactive session:**
```bash
srun --partition=gpu-interactive --nodes=1 --ntasks=1 --gres=gpu:a100:1 --cpus-per-task=2 --mem=10GB --time=02:00:00 --pty /bin/bash
```

**H200 GPU interactive session:**
```bash
srun --partition=gpu-interactive --nodes=1 --ntasks=1 --gres=gpu:h200:1 --cpus-per-task=2 --mem=10GB --time=01:00:00 --pty /bin/bash
```

## Batch Jobs (sbatch)

Use `sbatch` for training runs, data processing, or anything that should run unattended.

### Template: CPU Batch Job

See `scripts/cpu-job.sh` in this skill directory for the full template.

```bash
#!/bin/bash
#SBATCH --job-name=my_cpu_job
#SBATCH --partition=short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%j_%x.out
#SBATCH --error=logs/%j_%x.err

module load anaconda3/2024.06
source activate /scratch/<username>/conda_envs/<env_name>

python your_script.py
```

### Template: GPU Batch Job

See `scripts/gpu-job.sh` in this skill directory for the full template.

```bash
#!/bin/bash
#SBATCH --job-name=my_gpu_job
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:v100-sxm2:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%j_%x.out
#SBATCH --error=logs/%j_%x.err

module load anaconda3/2024.06 cuda/12.1.1
source activate /scratch/<username>/conda_envs/<env_name>

python train.py
```

### Available GPU Types (for --gres flag)

| GPU Type | VRAM | Nodes | GPUs/Node | Gres Flag | Notes |
|---|---|---|---|---|---|
| V100-SXM2 | 32GB | ~10 | 4 | `gpu:v100-sxm2:1` | Most available, shortest queue |
| V100-PCIe | 16GB | 4 | 2 | `gpu:v100-pcie:1` | Fewer nodes, lower memory |
| T4 | 16GB | 1 | 4 | `gpu:t4:1` | Inference-oriented, low power |
| A100 | 80GB | 3 | 3-4 | `gpu:a100:1` | High performance, good availability |
| H200 | 141GB | 4 | 8 | `gpu:h200:1` | Fastest, largest memory, may queue longer |

**Recommendations:**
- **Default choice:** `v100-sxm2` — most nodes, shortest wait
- **Best performance:** `a100` or `h200` — 2-5x faster than V100 for training
- **Any GPU:** omit the type (`gpu:1`) to accept whatever is available first
- For large models or batch sizes, prefer A100/H200 for the extra VRAM

### Submit and manage:

```bash
sbatch my_job.sh                          # Submit
squeue -u <username>                          # Check your jobs
squeue -u <username> --format="%.18i %.9P %.30j %.8T %.10M %.6D %R"  # Detailed view
scancel <job_id>                          # Cancel a job
scancel -u <username>                         # Cancel all your jobs
seff <job_id>                             # Job efficiency after completion
historical-seff                           # Historical efficiency (current month)
historical-seff --starttime YYYY-MM-DD    # Historical efficiency from date
```

## Conda Environment Setup

**Always set up conda from a compute node, not the login node.**

### PyTorch + CUDA 12.1 Environment

```bash
# 1. Get on a GPU node
srun --partition=gpu-interactive --nodes=1 --gres=gpu:v100-sxm2:1 --cpus-per-task=2 --mem=10GB --time=02:00:00 --pty /bin/bash

# 2. Load modules
module purge
module load explorer anaconda3/2024.06 cuda/12.1.1

# 3. Create env in /scratch to save /home quota
conda create --prefix=/scratch/<username>/conda_envs/pytorch_env -c conda-forge python=3.12.4 -y

# 4. Activate and install
source activate /scratch/<username>/conda_envs/pytorch_env
conda install jupyterlab -y
pip install torch==2.4.1 torchvision==0.19.1 torchaudio==2.4.1 --index-url https://download.pytorch.org/whl/cu121

# 5. Verify
python -c 'import torch; print(torch.cuda.is_available())'
```

### TensorFlow + CUDA 12.1 Environment

```bash
srun --partition=gpu-interactive --nodes=1 --ntasks=1 --gres=gpu:v100-pcie:1 --cpus-per-task=2 --mem=10GB --time=02:00:00 --pty /bin/bash
module purge
module load explorer anaconda3/2024.06 cuda/12.1.1
conda create --prefix=/scratch/<username>/conda_envs/tf_env python=3.12.4 -y
source activate /scratch/<username>/conda_envs/tf_env
pip install --upgrade pip
pip install tensorflow[and-cuda] jupyterlab
python -c 'import tensorflow as tf; print(tf.config.list_physical_devices("GPU"))'
```

### General ML Environment (sklearn, numpy, pandas)

```bash
srun --partition=short --nodes=1 --cpus-per-task=2 --mem=4G --time=01:00:00 --pty /bin/bash
module load anaconda3/2024.06
conda create --prefix=/scratch/<username>/conda_envs/ml_env python=3.12.4 -y
source activate /scratch/<username>/conda_envs/ml_env
pip install numpy pandas scikit-learn matplotlib seaborn jupyterlab
```

## Job Arrays

**Max 50 jobs running concurrently per user** across all arrays. Use `%N` to cap array concurrency.

For running the same script with different parameters:

```bash
#!/bin/bash
#SBATCH --partition=short
#SBATCH --job-name=sweep
#SBATCH --output=logs/sweep_%A_%a.out
#SBATCH --error=logs/sweep_%A_%a.err
#SBATCH --array=1-10%5
#SBATCH --mem=8G
#SBATCH --time=04:00:00

module load anaconda3/2024.06
source activate /scratch/<username>/conda_envs/ml_env

python train.py --run-id $SLURM_ARRAY_TASK_ID
```

The `%5` limits concurrency to 5 simultaneous jobs. Each job gets its own allocation of the requested resources.

## File Transfer

```bash
# From local machine to cluster
scp local_file.py <username>@login.explorer.northeastern.edu:/home/<username>/

# From cluster to local
scp <username>@login.explorer.northeastern.edu:/home/<username>/results.csv ./

# Recursive directory copy
scp -r ./my_project <username>@login.explorer.northeastern.edu:/scratch/<username>/

# rsync (better for large transfers, resumes on failure)
rsync -avz ./data/ <username>@login.explorer.northeastern.edu:/scratch/<username>/data/
```

## Containers (Apptainer)

Apptainer is system-wide on Explorer (no module needed). Use it for reproducible environments:

```bash
apptainer pull docker://nvcr.io/nvidia/pytorch:24.01-py3
apptainer exec --nv pytorch_24.01-py3.sif python train.py
```

The `--nv` flag enables GPU passthrough inside the container.

## Cluster Status Commands

```bash
sinfo -p gpu                      # GPU partition status
sinfo -p short                    # Short partition status
sinfo --Format=partition,avail,timelimit,nodes,statecompact,nodelist
squeue -u <username>                  # Your queued/running jobs
check-quota                       # Disk usage (run from compute node)
```

## Common Workflow: Training a Model

1. **SSH in:** `ssh <username>@login.explorer.northeastern.edu`
2. **Transfer code:** `scp -r ./project <username>@login.explorer.northeastern.edu:/scratch/<username>/`
3. **Write sbatch script** (use templates above or in `scripts/`)
4. **Create logs dir:** `mkdir -p /scratch/<username>/project/logs`
5. **Submit:** `sbatch job.sh`
6. **Monitor:** `squeue -u <username>` and `tail -f logs/<jobid>_<name>.out`
7. **Check efficiency after:** `seff <jobid>`
8. **Copy results home:** `cp /scratch/<username>/project/results/* /home/<username>/results/`

## Troubleshooting

| Problem | Solution |
|---|---|
| Job stuck in `PD` (pending) | Request fewer resources, use a less busy partition, or check fair-share score with `sshare -u <username>` |
| `MODULE NOT FOUND` | Run `module avail <name>` to find correct version |
| GPU not detected in PyTorch/TF | Ensure `cuda` module is loaded AND you are on a GPU node |
| Home quota exceeded | Move conda envs to `/scratch`, run `conda clean --all` |
| `srun: error: Unable to allocate resources` | Partition may be full; try `sinfo -p <partition>` to check |
| X11 forwarding fails | Use `ssh -Y` and ensure passwordless SSH is set up |
| IdleBot warning email | You have allocated resources you are not using; release them with `scancel` |

## Common Mistakes

| Mistake | Fix |
|---|---|
| Running `pip install` or `conda create` on the login node | Always `srun` first to get a compute node |
| Using `conda activate` in sbatch scripts | Use `source activate /path/to/env` — `conda activate` needs `conda init` which sbatch shells skip |
| Storing conda envs in `/home` | Use `--prefix=/scratch/<username>/conda_envs/<name>` to avoid quota errors |
| Forgetting `mkdir -p logs/` before submitting | Job immediately fails with "cannot open output file"; create logs dir first |
| Loading modules in `.bashrc` | Module conflicts cause silent failures; load them inside the sbatch script or after `srun` |
| Requesting a GPU partition without `--gres=gpu:...` | Job gets allocated with no GPU; always include `--gres` on gpu/gpu-interactive partitions |
| Using `gpu:1` when you need a specific GPU type | Assigns any available GPU — fine for testing, risky for VRAM-sensitive models |
| Letting `srun` sessions sit idle | Triggers IdleBot warnings and blocks resources for others; `scancel` when done |
| Checking quota from the login node | `check-quota` must run from a compute node (`srun` into `short` partition first) |

## Reference Documentation

- Full docs: https://rc-docs.northeastern.edu/en/latest/
- Support email: rchelp@northeastern.edu
- Open OnDemand (web GUI): https://rc.northeastern.edu/ood/
