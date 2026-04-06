# ai-dev-base: Lightweight base image for AI agent development
# Bundles gascity orchestration + AI CLIs on Debian slim
#
# Build: docker build --platform linux/amd64 -t ai-dev-base .
# Multi-arch: docker buildx build --platform linux/amd64,linux/arm64 -t ai-dev-base .

FROM debian:bookworm-slim

# Version pins — update these to upgrade
ARG GC_VERSION=0.13.4
ARG BD_VERSION=1.0.0
ARG DOLT_VERSION=1.85.0
ARG TARGETARCH

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    zsh \
    git \
    curl \
    wget \
    jq \
    tmux \
    sudo \
    ca-certificates \
    openssh-client \
    gnupg \
    lsof \
    procps \
    util-linux \
    unzip \
    less \
    && rm -rf /var/lib/apt/lists/*

# Create vscode user (devcontainer convention)
RUN groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid vscode --shell /bin/bash --create-home vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode

# --- Orchestration tools ---

# Dolt (SQL database for beads)
RUN ARCH=${TARGETARCH:-amd64} \
    && curl -fsSL "https://github.com/dolthub/dolt/releases/download/v${DOLT_VERSION}/dolt-linux-${ARCH}.tar.gz" \
       -o /tmp/dolt.tar.gz \
    && tar -xzf /tmp/dolt.tar.gz -C /tmp \
    && install /tmp/dolt-linux-${ARCH}/bin/dolt /usr/local/bin/dolt \
    && rm -rf /tmp/dolt* \
    && dolt version

# Gas City (gc) — multi-agent orchestration
RUN ARCH=${TARGETARCH:-amd64} \
    && curl -fsSL "https://github.com/gastownhall/gascity/releases/download/v${GC_VERSION}/gascity_${GC_VERSION}_linux_${ARCH}.tar.gz" \
       -o /tmp/gc.tar.gz \
    && tar -xzf /tmp/gc.tar.gz -C /tmp \
    && install /tmp/gc /usr/local/bin/gc \
    && rm -rf /tmp/gc* \
    && gc version

# Beads (bd) — work tracking
RUN ARCH=${TARGETARCH:-amd64} \
    && curl -fsSL "https://github.com/gastownhall/beads/releases/download/v${BD_VERSION}/beads_${BD_VERSION}_linux_${ARCH}.tar.gz" \
       -o /tmp/bd.tar.gz \
    && tar -xzf /tmp/bd.tar.gz -C /tmp \
    && install /tmp/bd /usr/local/bin/bd \
    && rm -rf /tmp/bd* \
    && bd version

# --- AI CLIs ---
# These install scripts may evolve — pinning is handled by the scripts themselves.
# If a CLI install fails, the build fails. No silent fallbacks.

# Node.js (required by Claude Code and Codex — both are npm-based)
ARG NODE_VERSION=20
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && node --version && npm --version

# Claude Code
RUN npm install -g @anthropic-ai/claude-code \
    && claude --version

# Codex CLI (OpenAI)
RUN npm install -g @openai/codex \
    && codex --version

# Amp CLI
RUN curl -fsSL https://raw.githubusercontent.com/nichochar/amp/main/install.sh | bash -s -- --prefix /usr/local \
    && amp --version

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# --- User setup ---

USER vscode
WORKDIR /home/vscode

# Default shell
ENV SHELL=/bin/bash

# Labels for GHCR
LABEL org.opencontainers.image.source="https://github.com/DataViking-Tech/ai-dev-base"
LABEL org.opencontainers.image.description="Lightweight base image for AI agent development with gascity orchestration"
LABEL org.opencontainers.image.licenses="MIT"

CMD ["bash"]
