# My Cluster Repo

This repository manages the configuration for Talos Kubernetes cluster(s).
It uses [talos-bootstraper](https://github.com/flip-flop-foundry/talos-bootstraper)
as a git submodule, keeping private cluster config here and public scripts/base
templates in the submodule.

## Architecture

```
GitHub (public)                          Gitea (private)
┌─────────────────────┐                  ┌─────────────────────────────┐
│ talos-bootstraper    │                 │ my-cluster-repo             │
│  ├── adminTasks/     │◄─submodule──────│  ├── talos-bootstraper/     │
│  └── base/           │                 │  ├── overlays/              │
└─────────────────────┘                  │  │   ├── example/           │
                                         │  │   ├── cluster-a/ ───────────┐
┌─────────────────────┐                  │  │   └── cluster-b/ ─────────┐ │
│ cluster-repo-example│                  │  ├── .devcontainer/         ││ │
│  (this repo)        │──clone+push───►  │  └── .vscode/tasks.json     ││ │
└─────────────────────┘                  └─────────────────────────────┘│ │
                                                                        │ │
                                         ┌──────────────────────────┐   │ │
                                         │ cluster-a-overlay (repo) │◄──┘ │
                                         │  ├── cluster-a.env       │     │
                                         │  ├── talos/              │     │
                                         │  ├── cilium/             │     │
                                         │  └── _rendered/          │     │
                                         └──────────────────────────┘     │
                                         ┌──────────────────────────┐     │
                                         │ cluster-b-overlay (repo) │◄────┘
                                         │  ├── cluster-b.env       │
                                         │  ├── talos/              │
                                         │  └── _rendered/          │
                                         └──────────────────────────┘
```

Each cluster overlay is a separate private Git repository on Gitea, registered as a
submodule under `overlays/`. Rendered manifests (`_rendered/`) live inside each overlay
and are pushed to Gitea so ArgoCD can read them directly.

## Structure

```
my-cluster-repo/
├── talos-bootstraper/        # git submodule — scripts + base component templates
│   ├── adminTasks/           # Bootstrap, render, and utility scripts
│   └── base/                 # Cluster-agnostic YAML templates
├── overlays/                 # Cluster-specific configuration
│   ├── example/              # Inline example overlay (reference only)
│   └── mycluster/            # git submodule — private overlay repo on Gitea
│       ├── mycluster.env     # All cluster configuration variables
│       ├── talos/            # Generated Talos machine configs + secrets
│       ├── cilium/           # Optional overrides of base
│       └── _rendered/        # Generated manifests (ArgoCD reads from here)
├── .devcontainer/            # Dev container configuration
└── .vscode/
    └── tasks.json            # VSCode tasks referencing submodule scripts
```

## Getting started

### 1. Clone this repo and push to your Gitea

```bash
git clone https://github.com/flip-flop-foundry/talos-bootstraper-cluster-repo-example my-cluster-repo
cd my-cluster-repo

# Push to your private Gitea instance
git remote set-url origin https://gitea.example.com/my-org/my-cluster-repo.git
git push -u origin main

# Add the GitHub repo as upstream for pulling future improvements
git remote add upstream https://github.com/flip-flop-foundry/talos-bootstraper-cluster-repo-example.git
```

### 2. Initialize the talos-bootstraper submodule

```bash
git submodule update --init talos-bootstraper
```

### 3. Create your cluster overlay as a submodule

Create a new repo on Gitea for your cluster overlay, then add it as a submodule:

```bash
# Copy an example overlay to get started
cp -r talos-bootstraper/overlays/yourCluster-l2 /tmp/mycluster

# Rename the env file
mv /tmp/mycluster/yourCluster-l2.env /tmp/mycluster/mycluster.env

# Initialize the overlay repo on Gitea (create it via Gitea UI or API first)
cd /tmp/mycluster && git init && git add -A && git commit -m "initial overlay"
git remote add origin https://gitea.example.com/my-org/mycluster-overlay.git
git push -u origin main && cd -

# Add as submodule
git submodule add https://gitea.example.com/my-org/mycluster-overlay.git overlays/mycluster
```

Edit `overlays/mycluster/mycluster.env` and update at minimum:
- `OVERLAY_NAME` — must match the directory name
- `CLUSTER_EXTERNAL_DOMAIN` — your cluster's DNS domain
- `TALOS_CONTROL_NODES` and `TALOS_WORKER_NODES` — node FQDNs
- `CILIUM_LB_IP_CIDR` — LoadBalancer IP range

### 4. Set up VSCode tasks

Open `.vscode/tasks.json` and update the `options` list in the `envFile` input to
include your overlay path (e.g. `overlays/mycluster/mycluster.env`).

## Script overview

### cluster-initialSetup.sh

Triggers a complete deployment including Talos and ArgoCD steps. Can safely be
re-run. Required for any Talos-level changes.

```bash
./talos-bootstraper/adminTasks/cluster-initialSetup.sh overlays/mycluster/mycluster.env
```

### cluster-bootstrap.sh

Triggered by cluster-initialSetup.sh, or run standalone. Renders manifests and
ensures ArgoCD picks them up.

```bash
./talos-bootstraper/adminTasks/cluster-bootstrap.sh overlays/mycluster/mycluster.env
```

### render-overlay.sh

Triggered by both scripts above, or run standalone. Merges base templates with
overlay config and writes output to `overlays/mycluster/_rendered/`.

```bash
./talos-bootstraper/adminTasks/render-overlay.sh overlays/mycluster/mycluster.env
```

## Keeping up to date

### Pull talos-bootstraper updates

```bash
# Update to latest talos-bootstraper
git submodule update --remote talos-bootstraper
git add talos-bootstraper
git commit -m "chore: update talos-bootstraper submodule"
```

### Pull cluster-repo scaffolding improvements

```bash
# Fetch and merge upstream devcontainer/task improvements
git fetch upstream
git merge upstream/main
```
