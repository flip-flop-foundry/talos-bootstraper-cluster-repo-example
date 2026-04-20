#!/bin/bash
# install-tools.sh — Installs CLI tools with versions resolved from the overlay env file.
# Called by devcontainer postCreateCommand.

set -euo pipefail

WORKSPACE="${1:-.}"
ARCH=$(dpkg --print-architecture)

# --- Resolve env file ---
# Reuse the last selection saved by the VS Code task picker, or ask interactively.
SELECTED_ENV_CACHE="$WORKSPACE/.vscode/current/selected-env"
if [[ -f "$SELECTED_ENV_CACHE" && -s "$SELECTED_ENV_CACHE" ]]; then
  _cached=$(tr -d '[:space:]' < "$SELECTED_ENV_CACHE")
  # Task picker saves relative paths; resolve to absolute
  [[ "$_cached" = /* ]] && ENV_FILE="$_cached" || ENV_FILE="$WORKSPACE/$_cached"
else
  mapfile -t _ENV_OPTIONS < <(find "$WORKSPACE/overlays" -maxdepth 2 -name '*.env' | sort)
  if [[ ${#_ENV_OPTIONS[@]} -eq 0 ]]; then
    ENV_FILE=""
  elif [[ ${#_ENV_OPTIONS[@]} -eq 1 || ! -t 0 ]]; then
    ENV_FILE="${_ENV_OPTIONS[0]}"
  else
    echo "🔍 Multiple overlay env files found. Select one:"
    select ENV_FILE in "${_ENV_OPTIONS[@]}"; do
      [[ -n "$ENV_FILE" ]] && break
    done
  fi
fi

if [[ -z "$ENV_FILE" || ! -f "$ENV_FILE" ]]; then
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

K9S_VERSION="${K9S_VERSION:-v0.50.18}"
ARGOCD_VERSION="${ARGOCD_VERSION:-v3.3.6}"
CMCTL_VERSION="${CMCTL_VERSION:-v2.4.1}"
VIRTCTL_VERSION="${VIRTCTL_VERSION:-v1.8.1}"
COPILOT_CLI_VERSION="${COPILOT_CLI_VERSION:-v1.0.31}"

log_step()  { echo "⏳ $*"; }
log_ok()    { echo "✅ $*"; }
log_skip()  { echo "⏭️  $*"; }
log_compl() { echo "   📝 completions: bash + zsh"; }

# Installs a tool only if it's missing or at a different version.
# Usage: needs_install <binary> <wanted_version> <actual_version_cmd>
# Returns 0 (install needed) or 1 (already correct).
needs_install() {
  local bin="$1" wanted="$2" version_cmd="$3"
  if ! command -v "$bin" &>/dev/null; then
    return 0  # not installed
  fi
  local actual
  actual=$(eval "$version_cmd" 2>/dev/null || true)
  if [[ "$actual" != *"${wanted#v}"* ]]; then
    return 0  # wrong version
  fi
  return 1  # already correct
}

echo "🔧 Tool versions for linux/${ARCH}:"
echo "   kubectl      ${KUBECTL_VERSION}"
echo "   helm         ${HELM_VERSION}"
echo "   talosctl     ${TALOSCTL_VERSION}"
echo "   yq           ${YQ_VERSION}"
echo "   cilium-cli   ${CILIUM_CLI_VERSION}"
echo "   k9s          ${K9S_VERSION}"
echo "   argocd       ${ARGOCD_VERSION}"
echo "   cmctl        ${CMCTL_VERSION}"
echo "   virtctl      ${VIRTCTL_VERSION}"
echo "   copilot-cli  ${COPILOT_CLI_VERSION}"
echo "   helm-diff    (helm plugin)"
echo ""

# --- kubectl ---
if needs_install kubectl "$KUBECTL_VERSION" "kubectl version --client -o json | jq -r .clientVersion.gitVersion"; then
  log_step "kubectl ${KUBECTL_VERSION}..."
  sudo curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" -o /usr/local/bin/kubectl
  sudo chmod +x /usr/local/bin/kubectl
  log_ok "kubectl $(kubectl version --client -o json | jq -r .clientVersion.gitVersion) installed"
else
  log_skip "kubectl ${KUBECTL_VERSION} already installed"
fi

# --- helm ---
if needs_install helm "$HELM_VERSION" "helm version --short"; then
  log_step "helm ${HELM_VERSION}..."
  curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz" | sudo tar xz --strip-components=1 -C /usr/local/bin "linux-${ARCH}/helm"
  sudo chmod +x /usr/local/bin/helm
  log_ok "helm $(helm version --short) installed"
else
  log_skip "helm ${HELM_VERSION} already installed"
fi

# --- talosctl ---
if needs_install talosctl "$TALOSCTL_VERSION" "talosctl version --client --short 2>/dev/null | head -1"; then
  log_step "talosctl ${TALOSCTL_VERSION}..."
  sudo curl -fsSL "https://github.com/siderolabs/talos/releases/download/${TALOSCTL_VERSION}/talosctl-linux-${ARCH}" -o /usr/local/bin/talosctl
  sudo chmod +x /usr/local/bin/talosctl
  log_ok "talosctl $(talosctl version --client --short 2>/dev/null | head -1) installed"
else
  log_skip "talosctl ${TALOSCTL_VERSION} already installed"
fi

# --- yq (mikefarah) ---
if needs_install yq "$YQ_VERSION" "yq --version"; then
  log_step "yq ${YQ_VERSION}..."
  sudo curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${ARCH}" -o /usr/local/bin/yq
  sudo chmod +x /usr/local/bin/yq
  log_ok "yq $(yq --version) installed"
else
  log_skip "yq ${YQ_VERSION} already installed"
fi

# --- cilium-cli ---
if needs_install cilium "$CILIUM_CLI_VERSION" "cilium version --client 2>/dev/null | head -1"; then
  log_step "cilium-cli ${CILIUM_CLI_VERSION}..."
  curl -fsSL "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz" | sudo tar xz -C /usr/local/bin
  sudo chmod +x /usr/local/bin/cilium
  log_ok "cilium $(cilium version --client 2>/dev/null | head -1) installed"
else
  log_skip "cilium-cli ${CILIUM_CLI_VERSION} already installed"
fi

# --- k9s ---
if needs_install k9s "$K9S_VERSION" "k9s version --short 2>/dev/null | grep Version | awk '{print \$2}'"; then
  log_step "k9s ${K9S_VERSION}..."
  curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_${ARCH}.tar.gz" | sudo tar xz -C /usr/local/bin k9s
  sudo chmod +x /usr/local/bin/k9s
  log_ok "k9s $(k9s version --short 2>/dev/null | grep Version | awk '{print $2}') installed"
else
  log_skip "k9s ${K9S_VERSION} already installed"
fi

# --- argocd CLI ---
if needs_install argocd "$ARGOCD_VERSION" "argocd version --client --short 2>/dev/null | head -1"; then
  log_step "argocd ${ARGOCD_VERSION}..."
  sudo curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${ARCH}" -o /usr/local/bin/argocd
  sudo chmod +x /usr/local/bin/argocd
  log_ok "argocd $(argocd version --client --short 2>/dev/null | head -1) installed"
else
  log_skip "argocd ${ARGOCD_VERSION} already installed"
fi

# --- cmctl (cert-manager CLI) ---
if needs_install cmctl "$CMCTL_VERSION" "cmctl version --client 2>/dev/null | head -1"; then
  log_step "cmctl ${CMCTL_VERSION}..."
  sudo curl -fsSL "https://github.com/cert-manager/cmctl/releases/download/${CMCTL_VERSION}/cmctl_linux_${ARCH}" -o /usr/local/bin/cmctl
  sudo chmod +x /usr/local/bin/cmctl
  log_ok "cmctl $(cmctl version --client 2>/dev/null | head -1) installed"
else
  log_skip "cmctl ${CMCTL_VERSION} already installed"
fi

# --- virtctl (KubeVirt CLI) ---
if needs_install virtctl "$VIRTCTL_VERSION" "virtctl version --client 2>/dev/null | head -1"; then
  log_step "virtctl ${VIRTCTL_VERSION}..."
  sudo curl -fsSL "https://github.com/kubevirt/kubevirt/releases/download/${VIRTCTL_VERSION}/virtctl-v${VIRTCTL_VERSION#v}-linux-${ARCH}" -o /usr/local/bin/virtctl
  sudo chmod +x /usr/local/bin/virtctl
  log_ok "virtctl $(virtctl version --client 2>/dev/null | head -1) installed"
else
  log_skip "virtctl ${VIRTCTL_VERSION} already installed"
fi

# --- GitHub Copilot CLI ---
# Copilot release assets use 'x64' for amd64 and 'arm64' for arm64.
case "$ARCH" in
  amd64)   COPILOT_ARCH="x64"   ;;
  arm64)   COPILOT_ARCH="arm64" ;;
  *)       echo "⚠️  Unsupported arch for copilot-cli: ${ARCH}"; COPILOT_ARCH="" ;;
esac
if [[ -z "$COPILOT_ARCH" ]]; then
  log_skip "copilot-cli (unsupported arch: ${ARCH})"
elif needs_install copilot "$COPILOT_CLI_VERSION" "copilot --version"; then
  log_step "copilot-cli ${COPILOT_CLI_VERSION}..."
  curl -fsSL "https://github.com/github/copilot-cli/releases/download/${COPILOT_CLI_VERSION}/copilot-linux-${COPILOT_ARCH}.tar.gz" \
    | sudo tar xz -C /usr/local/bin copilot
  sudo chmod +x /usr/local/bin/copilot
  log_ok "copilot $(copilot --version 2>/dev/null || true) installed"
else
  log_skip "copilot-cli ${COPILOT_CLI_VERSION} already installed"
fi

# --- helm-diff (helm plugin) ---
if ! helm plugin list 2>/dev/null | grep -q '^diff'; then
  log_step "helm-diff..."
  helm plugin install https://github.com/databus23/helm-diff
  log_ok "helm-diff $(helm plugin list | grep '^diff' | awk '{print $2}') installed"
else
  log_skip "helm-diff already installed"
fi

# --- k9s plugins ---
echo ""
log_step "Installing k9s plugins..."
K9S_PLUGINS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/k9s/plugins"
mkdir -p "$K9S_PLUGINS_DIR"
K9S_PLUGINS_BASE="https://raw.githubusercontent.com/derailed/k9s/master/plugins"

for plugin in argocd cert-manager helm-diff liveMigration; do
  dest="$K9S_PLUGINS_DIR/${plugin}.yaml"
  curl -fsSL "${K9S_PLUGINS_BASE}/${plugin}.yaml" -o "$dest"
  log_ok "k9s plugin: ${plugin}"
done

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

k9s completion bash      | sudo tee /usr/local/share/bash-completion/completions/k9s > /dev/null
k9s completion zsh       | sudo tee /usr/local/share/zsh/site-functions/_k9s > /dev/null
log_compl "k9s"

argocd completion bash   | sudo tee /usr/local/share/bash-completion/completions/argocd > /dev/null
argocd completion zsh    | sudo tee /usr/local/share/zsh/site-functions/_argocd > /dev/null
log_compl "argocd"

cmctl completion bash    | sudo tee /usr/local/share/bash-completion/completions/cmctl > /dev/null
cmctl completion zsh     | sudo tee /usr/local/share/zsh/site-functions/_cmctl > /dev/null
log_compl "cmctl"

if copilot completion bash > /dev/null 2>&1; then
  copilot completion bash | sudo tee /usr/local/share/bash-completion/completions/copilot > /dev/null
  copilot completion zsh  | sudo tee /usr/local/share/zsh/site-functions/_copilot > /dev/null
  log_compl "copilot"
fi

echo ""
log_step "Configuring shell aliases..."

ensure_alias_line() {
  local shell_rc="$1"
  local alias_line="$2"
  touch "$shell_rc"
  if ! grep -Fqx "$alias_line" "$shell_rc"; then
    echo "$alias_line" >> "$shell_rc"
  fi
}

ensure_alias_line "$HOME/.bashrc" "alias k='kubectl'"
ensure_alias_line "$HOME/.bashrc" "alias t='talosctl'"
ensure_alias_line "$HOME/.zshrc" "alias k='kubectl'"
ensure_alias_line "$HOME/.zshrc" "alias t='talosctl'"

log_ok "aliases configured: k -> kubectl, t -> talosctl"

echo ""
echo "✅ All tools installed, completions generated, and aliases configured."
