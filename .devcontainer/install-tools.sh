#!/bin/bash
# install-tools.sh — Installs CLI tools with versions resolved from the overlay env file.
# Called by devcontainer postCreateCommand.

set -euo pipefail

WORKSPACE="${1:-.}"
ARCH=$(dpkg --print-architecture)

# --- Resolve env file from .vscode/tasks.json (first option in inputs) ---
TASKS_JSON="$WORKSPACE/.vscode/tasks.json"
if [[ -f "$TASKS_JSON" ]]; then
  ENV_FILE_REL=$(jq -r '.inputs[] | select(.id == "envFile") | .options[0]' "$TASKS_JSON")
  ENV_FILE="$WORKSPACE/$ENV_FILE_REL"
else
  ENV_FILE=""
fi

if [[ -z "$ENV_FILE" ]]; then
  echo "⚠️  No overlay .env file found under overlays/. Installing tools with fallback versions."
  KUBERNETES_VERSION="1.35.0"
  TALOS_INSTALL_VERSION="v1.12.4"
else
  echo "📂 Sourcing env file: $ENV_FILE"
  # Source in a subshell-safe way: only extract the variables we need.
  # The env file uses bash arrays and other bashisms, so source with bash.
  eval "$(bash -c "source '$ENV_FILE' && echo KUBERNETES_VERSION=\$KUBERNETES_VERSION && echo TALOS_INSTALL_VERSION=\$TALOS_INSTALL_VERSION")"
fi

# Normalize: kubectl expects a "v" prefix
KUBECTL_VERSION="v${KUBERNETES_VERSION#v}"
TALOSCTL_VERSION="${TALOS_INSTALL_VERSION}"

# --- Fallback for tools without env-file versions ---
HELM_VERSION="${HELM_VERSION:-v3.18.2}"
YQ_VERSION="${YQ_VERSION:-v4.45.4}"
# Cilium CLI version != Cilium Helm chart version; pin CLI separately
CILIUM_CLI_VERSION="${CILIUM_CLI_VERSION:-v0.19.1}"

log_step()  { echo "⏳ $*"; }
log_ok()    { echo "✅ $*"; }
log_compl() { echo "   📝 completions: bash + zsh"; }

echo "🔧 Installing tools for linux/${ARCH}:"
echo "   kubectl      ${KUBECTL_VERSION}"
echo "   helm         ${HELM_VERSION}"
echo "   talosctl     ${TALOSCTL_VERSION}"
echo "   yq           ${YQ_VERSION}"
echo "   cilium-cli   ${CILIUM_CLI_VERSION}"
echo ""

# --- kubectl ---
log_step "kubectl ${KUBECTL_VERSION}..."
sudo curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" -o /usr/local/bin/kubectl
sudo chmod +x /usr/local/bin/kubectl
log_ok "kubectl $(kubectl version --client -o json | jq -r .clientVersion.gitVersion) installed"

# --- helm ---
log_step "helm ${HELM_VERSION}..."
curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" | sudo tar xz --strip-components=1 -C /usr/local/bin "linux-${ARCH}/helm"
sudo chmod +x /usr/local/bin/helm
log_ok "helm $(helm version --short) installed"

# --- talosctl ---
log_step "talosctl ${TALOSCTL_VERSION}..."
sudo curl -fsSL "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-${ARCH}" -o /usr/local/bin/talosctl
sudo chmod +x /usr/local/bin/talosctl
log_ok "talosctl $(talosctl version --client --short 2>/dev/null | head -1) installed"

# --- yq (mikefarah) ---
log_step "yq ${YQ_VERSION}..."
sudo curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" -o /usr/local/bin/yq
sudo chmod +x /usr/local/bin/yq
log_ok "yq $(yq --version) installed"

# --- cilium-cli ---
log_step "cilium-cli ${CILIUM_CLI_VERSION}..."
curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz" | sudo tar xz -C /usr/local/bin
sudo chmod +x /usr/local/bin/cilium
log_ok "cilium $(cilium version --client 2>/dev/null | head -1) installed"

# --- Shell completions (bash + zsh) ---
echo ""
log_step "Generating shell completions..."
sudo mkdir -p /usr/local/share/bash-completion/completions /usr/local/share/zsh/site-functions

kubectl completion bash  | sudo tee /usr/local/share/bash-completion/completions/kubectl > /dev/null
kubectl completion zsh   | sudo tee /usr/local/share/zsh/site-functions/_kubectl > /dev/null
log_compl "kubectl"

helm completion bash     | sudo tee /usr/local/share/bash-completion/completions/helm > /dev/null
helm completion zsh      | sudo tee /usr/local/share/zsh/site-functions/_helm > /dev/null
log_compl "helm"

talosctl completion bash | sudo tee /usr/local/share/bash-completion/completions/talosctl > /dev/null
talosctl completion zsh  | sudo tee /usr/local/share/zsh/site-functions/_talosctl > /dev/null
log_compl "talosctl"

cilium completion bash   | sudo tee /usr/local/share/bash-completion/completions/cilium > /dev/null
cilium completion zsh    | sudo tee /usr/local/share/zsh/site-functions/_cilium > /dev/null
log_compl "cilium"

yq shell-completion bash | sudo tee /usr/local/share/bash-completion/completions/yq > /dev/null
yq shell-completion zsh  | sudo tee /usr/local/share/zsh/site-functions/_yq > /dev/null
log_compl "yq"

echo ""
echo "✅ All tools installed and completions generated."
