# NEU Explorer HPC Skill for Claude Code

## Installation

Copy the entire `neu-hpc` folder to your Claude Code skills directory:

```bash
# Global skill (available in all projects)
cp -r neu-hpc ~/.claude/skills/

# OR project-specific skill (available only in one project)
cp -r neu-hpc /path/to/your/project/.claude/skills/
```

After installation, the skill will be available as `/neu-hpc` in Claude Code and will also be auto-invoked when Claude detects HPC-related tasks.

## Optional: Install Helper Functions on the Cluster

SSH into Explorer and set up the helpers:

```bash
ssh <your-username>@login.explorer.northeastern.edu

# Copy helpers to your home directory
mkdir -p ~/scripts
# (upload hpc-helpers.sh via scp or paste contents)

# Add to your .bashrc for auto-loading
echo 'source ~/scripts/hpc-helpers.sh' >> ~/.bashrc
```

## What's Included

```
neu-hpc/
├── SKILL.md                  # Main skill (connection, partitions, modules, workflows)
├── README.md                 # This file
└── scripts/
    ├── gpu-job.sh            # GPU batch job template
    ├── cpu-job.sh            # CPU batch job template
    ├── sweep-job.sh          # Hyperparameter sweep job array template
    └── hpc-helpers.sh        # Shell helper functions (gpu-shell, myjobs, etc.)
```

## Usage in Claude Code

Once installed, you can:

- Type `/neu-hpc` to explicitly load the skill
- Or just ask naturally: "submit a GPU training job on the cluster", "set up a PyTorch conda env on Explorer", "write an sbatch script for my training run"

Claude will auto-detect when the skill is relevant and apply the correct cluster configuration.
