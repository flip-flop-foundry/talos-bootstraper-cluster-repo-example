FROM mcr.microsoft.com/devcontainers/base:bookworm

# Core packages: envsubst (gettext-base), rsync, jq, curl, git, bash-completion
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        gettext-base \
        rsync \
        jq \
        curl \
        git \
        bash-completion \
        dnsutils \
        iputils-ping \
        htop \
        ca-certificates \
        gnupg \
        unzip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
# # --- Bitwarden CLI ---
# RUN curl -fsSL "https://vault.bitwarden.com/download/?app=cli&platform=linux" -o /tmp/bw.zip \
#     && unzip -o /tmp/bw.zip -d /usr/local/bin \
#     && chmod +x /usr/local/bin/bw \
#     && rm /tmp/bw.zip

# # --- envoke (build from source) ---
# ARG GO_VERSION=1.25.0
# RUN ARCH=$(dpkg --print-architecture) \
#     && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" | tar xz -C /usr/local
# ENV PATH="/usr/local/go/bin:/home/vscode/go/bin:${PATH}"
# RUN go install github.com/eficode/secure-handling-of-secrets/cmd/envoke@latest

