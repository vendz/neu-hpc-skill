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
3. **`/scratch/<username>`** is purged in the monthly maintenance window (first Tuesday; 20TB / 20M files limit; no backups). Copy results to `/home/<username>` after every job.
4. **Home directory quota is 75GB.** Conda envs eat space fast; clean caches with `conda clean --all`.
5. **Load modules inside sbatch scripts or after getting a compute node**, not in `.bashrc`.
6. **The `explorer` module** loads automatically and sets the HTTP proxy (`module load explorer` restores it after `module purge`). The proxy also catches `localhost` traffic — see "Proxy trap" below.
7. **Every GPU submission costs queue time you can't get back.** Read "Scheduling" below before you submit anything to a GPU partition.
8. **Never submit a duplicate job.** `sbatch` sometimes prints an error ("Unexpected message received") and still creates the job — always run `squeue -u <username>` before retrying.
9. **The cluster is free (no money).** The only cost is fair-share priority. Say "uses priority", never "charged".

## Scheduling: how it works and how not to waste queue time

### How priority works
Slurm orders pending jobs by priority. Sources: [queuing docs](https://rc-docs.northeastern.edu/en/latest/runningjobs/understandingqueuing.html), [partitions](https://rc.northeastern.edu/partitions/).

| Factor | Effect |
|---|---|
| **Fair-share** (your account's recent usage) | Heavy recent use → lower priority for **everyone in the account** (e.g. a course account shared by a whole class) |
| **Job size** | Fewer nodes/resources → higher priority, and easier to fit into gaps |
| **Age** | Priority rises the longer a job waits |
| Requesting max nodes/tasks | Does **not** make it run faster or raise priority |

- Check standing: `sshare -u <username>` (FairShare near 1 = good, near 0 = you are behind most users), `sprio -u <username>` (priority breakdown of your pending jobs).
- Observed on this cluster (Oct 2026, not in the docs): billing counts **GPU = 100, CPU = 1 per hour, the same for every GPU type**. One H200-hour costs the same priority as one V100-hour — so a faster GPU that finishes sooner is *cheaper* in priority, but popular types wait longer.
- Pending reasons (`squeue -u <username> -o "%i %j %T %r"`): `Priority` = higher-priority jobs are ahead (just wait); `Resources` = waiting for a free card of that type; `QOSMaxJobsPerUserLimit` = you hit your running-job cap; `QOSMaxSubmitJobPerUserLimit` = you hit the submit cap (job rejected); `JobHeldUser` = you held it.

### Backfill: why short, accurate `--time` matters
The scheduler lets small jobs jump ahead if they finish before a big job's reserved start ("backfill"). A job with an honest short `--time` fits these gaps; a job asking for the 8 h maximum "just in case" does not. Set `--time` to about 1.3–1.5x the expected runtime. A job that hits its limit is killed, so pair a tight limit with checkpointing.

### Start-time estimates are unreliable
`squeue --start -j <id>` and `sbatch --test-only ...` give estimates that the docs call "a bit inaccurate". Observed: every GPU type and even a 30-min CPU job all showed ~36 h — Slurm assumes every running job uses its full time limit. Real starts were often minutes to hours. Use estimates only to *compare* options (e.g. H200 vs A100), never to promise a time to the user.

### The cost of "randomly sending jobs"
| Bad habit | What it costs |
|---|---|
| A separate job for each small step (smoke test, then pilot, then eval) | Each job waits in the queue again. With low fair-share that can be hours to a day **per step**. |
| Cancel and resubmit to "fix" a pending job | Loses accumulated age priority; back of the line |
| Submitting many speculative jobs | Burns fair-share for the whole account; hits the 8-submitted / 4-running cap on `gpu` |
| Asking for 8 h, 8 CPUs, 64 GB for a 1 h job | Can't backfill; lowers future priority via billing |
| A GPU job that fails 5 min in (missing file, bad path, proxy) | All the queue wait is wasted; resubmitting waits again |
| GPU job doing CPU-only work (downloads, env builds, CPU benchmarks, long eval on CPU) | Idle GPU → IdleBot email, possible cancel; burns 100x CPU priority |
| `srun` session left open | Same as above |

### Workflow that minimizes queue time
1. **Prepare everything on CPU first** (partition `short`/`express`/`debug`, or the Mac): env builds, model/data downloads into `HF_HOME` on scratch, data prep. A GPU job should start computing within minutes.
2. **Dry-run the GPU job script on a CPU node** with the GPU parts stubbed or tiny (e.g. 20 steps on CPU). Catch path, import, proxy and quoting bugs before you queue.
3. **One GPU job per phase chain.** Put smoke test → real work → eval in **one** allocation, with in-job go/no-go checks that `exit` early (freeing the GPU) when a check fails. Never "smoke-test, then resubmit for real."
4. **Pack many small runs into one job** (loop over configs inside one allocation, or a small array with `%N`) instead of many separate submissions.
5. **Make work resumable** (append-only outputs, skip finished items, checkpoint every 10–15 min, keep only the latest checkpoint), and copy results to `/home` after each phase and in a `trap ... EXIT`. Then a time-limit kill loses nothing.
6. **Pick the GPU by fit, then by queue**: smallest card whose memory fits, compared with `sbatch --test-only` (see GPU table). `gpu-short` (≤ 2 h) has higher priority than `gpu`; use it for jobs that truly fit in 2 h.
7. **Don't touch a pending job unless it's wrong.** If code must change while a job waits: Slurm **copies the batch script at submit time**, but any script/file the job *calls* is read when it starts — put changeable logic in a callee on `/scratch` and replace it atomically (write temp, verify, `mv`). Holding a job (`scontrol hold <id>`, `scontrol release <id>`) keeps its place in the list but it does not start; a long hold likely costs age priority.
8. **Check before you submit:** `squeue -u <username>` (no duplicates), `sshare -u <username>` (priority), `sinfo -p gpu -o "%G %D %T"` (what exists).
9. **After a job:** `seff <jobid>`; for GPU use `historical-seff --starttime YYYY-MM-DD` and `gpu-logs <jobid>` (run from `srun -p short --constraint=ib --pty bash`). Shrink the next request to match what was used.

### Idle GPU policy (IdleBot)
IdleBot watches public GPU nodes: email after **15 min** under-used, job **cancelled after 1 h** ([idlebot docs](https://rc-docs.northeastern.edu/en/latest/gpus/idlebot.html)). Graphs land in `/scratch/<username>/idle_bot_graphs/<jobid>.png`. Put an in-job watchdog in every GPU batch job so you never get the email:
```bash
( idle=0; while sleep 60; do
    u=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits | head -1)
    if [ "${u:-0}" -lt 10 ]; then idle=$((idle+1)); else idle=0; fi
    [ $idle -ge 10 ] && { echo "EVICTED: GPU <10% for 10 min"; scancel $SLURM_JOB_ID; }
  done ) &
```
Start the watchdog only **after** slow startup (model load, server start) finishes, and keep CPU-only phases inside the job under ~5 min.

### Proxy trap (localhost servers)
Jobs inherit `http_proxy`/`https_proxy` (10.99.0.130:3128) from the submit shell. Requests to a server you start inside the job (vLLM, Jupyter, any `localhost`/`127.0.0.1` URL) then go **through the proxy and get HTTP 403**. In every job that talks to a local server:
```bash
export no_proxy=localhost,127.0.0.1,::1 NO_PROXY=localhost,127.0.0.1,::1
```
Also pick a free random port (other users share the node) and check that `/v1/models` lists *your* model before using the server.

### GPU drivers and CUDA wheels
Observed Oct 2026: H200 node driver **570.86.15** (native CUDA ≤ 12.8). Wheels built for CUDA 13 (e.g. the newest vLLM/torch from plain `pip install`) need driver ≥ 580 and fail there. Pin cu126/cu128/cu129 wheels, or use NVIDIA's `cuda-compat` forward-compat libraries (data-center GPUs) on `LD_LIBRARY_PATH`. Check a node's driver inside a job with `nvidia-smi` before building large envs. Build envs with `uv pip install` into node-local `/tmp` then move to scratch — plain `pip` into `/scratch` took > 90 min once; `uv` took 3 min.

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

Source: [rc.northeastern.edu/partitions](https://rc.northeastern.edu/partitions/) (Oct 2026). Verify live with `scontrol show partition <name>`.

| Partition | Approval | Time default / max | Running / submitted jobs per user | GPUs | Use Case |
|---|---|---|---|---|---|
| `short` | No | 4h / 48h | 50 / 1000 | None | CPU jobs, env builds, downloads, data prep (max 2 nodes) |
| `long` | Yes | 1d / 5d | 25 / 1000 | None | Only if code cannot checkpoint |
| `express` / `debug` | No | short | — | None | Quick tests, dry runs |
| `sharing` | No | 30m / 60m | 2 / 4 | 1 | PI-shared GPUs, quick tests |
| `gpu-short` | No | 1h / 2h | 2 / 4 | 1 | Short GPU jobs; **higher priority than `gpu`**; has H200 |
| `gpu-interactive` | No | 1h / 2h | 2 / 4 | 1 | Interactive GPU dev (rejects >1 GPU) |
| `gpu` | No | 4h / 8h | 4 / 8 | 1 per job, 4 per user | Batch GPU training |
| `multigpu` | Yes | 12h / 24h | 4 / 8 | up to 8 | Needs a scaling test (efficiency > 0.5) to get access |

The whole account (group) also has a 10,000-job cap; hitting it shows "job violates accounting/QOS policy". Arrays: max 50 running per user; throttle with `%N`. Monthly maintenance is the **first Tuesday**: no jobs run then, and jobs whose `--time` overlaps the window won't start before it.

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
| V100-SXM2 | 32GB | ~17 | 3-4 | `gpu:v100-sxm2:1` | Most nodes; no bf16/FP8 |
| V100-PCIe | 16-32GB (check) | ~4 | 2-4 | `gpu:v100-pcie:1` | Some cards are 16GB (68M-param pair models OOM'd there) |
| T4 | 16GB | 1-2 | 4 | `gpu:t4:1` | Slow; often shortest wait |
| A100 40GB | 40GB | 1 | 2-3 | `gpu:a100:1` | `gpu:a100:1` can land here |
| A100 80GB | 80GB | 2 | 4 | `gpu:a100:1 --constraint=a100@80g` | Only 8 cards; busy |
| H200 | 141-144GB | 4 | 8 | `gpu:h200:1` | Fastest; ~100+ jobs often pending |

Source: [rc.northeastern.edu/compute](https://rc.northeastern.edu/compute/); H100, L40S, A6000, A5000 are PI-owned (only via `sharing` or PI partitions). Live view: `sinfo -p gpu -h -o "%G|%f|%D|%T"`; pending demand per type: `squeue -p gpu -h -t PD -o "%b" | sort | uniq -c`. Node state MIXED refers to CPUs, not GPUs.

**How to choose:**
1. Smallest memory that fits the job (weights + activations + KV cache), with ~20% headroom.
2. Among the types that fit, compare `sbatch --test-only -p gpu --gres=gpu:<type>:1 -c 4 --mem=32G -t 02:00:00 --wrap=true` and pick the earliest relative start.
3. `gpu:1` (any type) starts soonest but may give a 16GB card — only for jobs that fit 16GB.
4. Faster cards cost the same priority per hour, so a job that runs 3x faster on H200 uses 1/3 the priority — if the H200 queue isn't much longer.
5. Exclude known-bad nodes with `--exclude=<node>` (e.g. a slow T4 node).

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

- RC says large transfers **must** use the transfer node `xfer.discovery.neu.edu` (or Globus), not the login node ([docs](https://rc-docs.northeastern.edu/en/latest/datamanagement/transferringdata.html)).
- If rsync fails with "unexpected end of file" / protocol errors, the login shell's `.bashrc`/MOTD is printing text; use `scp` per file, or fix `.bashrc` to print only for interactive shells.
- Always exclude `.venv`, caches and checkpoints you don't need (`--exclude .venv --exclude '*.pt'`).
- Use `-o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15` for scripted ssh/scp so a dead connection fails instead of hanging; run **one** ssh at a time, never parallel background ssh loops.

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
| IdleBot warning email | GPU under-used for 15 min; it cancels at 1 h. `scancel` now, add the in-job watchdog, move CPU-only work out of GPU jobs |
| Pending for many hours, reason `Priority` | Low fair-share. Don't resubmit (loses age). Compare other GPU types with `--test-only`; use `gpu-short` if it fits in 2 h; merge pending steps into one job |
| Job dies minutes after starting | Dry-run the script on a CPU node first; check `no_proxy`, paths that exist only on your laptop, env/driver mismatch (`nvidia-smi` driver vs wheel CUDA version) |
| Local server in job returns HTTP 403 | Proxy catches localhost: `export no_proxy=localhost,127.0.0.1,::1` |
| `sbatch` printed an error | It may still have created the job — `squeue -u <username>` before retrying |

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
