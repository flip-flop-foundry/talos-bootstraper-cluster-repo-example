# My Cluster Repo

This repository manages the configuration for Talos Kubernetes cluster(s).
It uses [talos-bootstraper](https://github.com/flip-flop-foundry/talos-bootstraper)
as a git submodule, keeping private cluster config here and public scripts/base
templates in the submodule.

## Structure

```
my-cluster-repo/
├── talos-bootstraper/      # git submodule — scripts + base component templates
│   ├── adminTasks/         # Bootstrap, render, and utility scripts
│   └── base/               # Cluster-agnostic YAML templates
├── overlays/               # Cluster-specific configuration (this repo, private)
│   └── mycluster/
│       ├── mycluster.env   # All cluster configuration
│       └── talos/          # Generated Talos machine configs + secrets
├── rendered/               # Generated manifests (gitignored, re-run render to regenerate)
└── .vscode/
    └── tasks.json          # VSCode tasks referencing submodule scripts
```

## Setup

### 1. Add the submodule

This step has already been done in this example repo

```bash
git submodule add https://github.com/flip-flop-foundry/talos-bootstraper talos-bootstraper
git submodule update --init --recursive
```

### 2. Create your cluster overlay

Copy one of the example overlays from the submodule:

```bash
# L2 mode (ARP announcements, recommended for most setups)
cp -r talos-bootstraper/overlays/yourCluster-l2 overlays/mycluster

# OR BGP mode (eBGP to a router)
cp -r talos-bootstraper/overlays/yourCluster-bgp overlays/mycluster

# Rename the env file to match your cluster name
mv overlays/mycluster/yourCluster-l2.env overlays/mycluster/mycluster.env
```

Edit `overlays/mycluster/mycluster.env` and update at minimum:
- `OVERLAY_NAME` — must match the directory name
- `CLUSTER_EXTERNAL_DOMAIN` — your cluster's DNS domain
- `TALOS_CONTROL_NODES` and `TALOS_WORKER_NODES` — node FQDNs
- `CILIUM_LB_IP_CIDR` — LoadBalancer IP range
- Passwords/secrets (never commit real values to a public repo)

### 3. Set up VSCode tasks


Open: .vscode/tasks.json

Update the `options` list in the `envFile` input to include your overlay path(s).


## Script overview

### cluster-initialSetup.sh

This script triggers a complete deployment including Talos and ArgoCD steps. This can safely be run many times. You need to run this script if you have done any Talos level changes

```bash
./talos-bootstraper/adminTasks/cluster-initialSetup.sh overlays/mycluster/mycluster.env
```


### cluster-bootstrap.sh

This script is triggered by cluster-initialSetup.sh, but can also be run standalone. 
It´s main task is to render the manifests and make sure ArgoCD picks them up.

```bash
./talos-bootstraper/adminTasks/cluster-bootstrap.sh overlays/mycluster/mycluster.env
```



### render-overlay.sh

This script is triggered by both cluster-initialSetup.sh and cluster-bootstrap.sh. 
It renders the manifests. 

```bash
./talos-bootstraper/adminTasks/render-overlay.sh overlays/mycluster/mycluster.env
```



## Keeping the submodule updated

```bash
# Update to latest talos-bootstraper
git submodule update --remote talos-bootstraper
git add talos-bootstraper
git commit -m "chore: update talos-bootstraper submodule"
```
