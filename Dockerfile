# agent-dev-base: Lightweight base image for AI agent development
#
# Bundles Gas City (gc) orchestration, Beads (bd) issue tracking,
# Dolt database, and AI coding CLIs on Ubuntu Noble.
#
# Ubuntu Noble (24.04 LTS) chosen over Debian bookworm because the
# prebuilt beads binary requires ICU 74+ (libicui18n.so.74), which
# bookworm (ICU 72) does not provide.
#
# Build:
#   docker build --platform linux/amd64 -t agent-dev-base .
# Multi-arch:
#   docker buildx build --platform linux/amd64,linux/arm64 -t agent-dev-base .

FROM ubuntu:resolute

# ---------------------------------------------------------------------------
# Build arguments — version pins for orchestration tools
# ---------------------------------------------------------------------------
ARG GC_VERSION=0.13.4
ARG BD_VERSION=1.0.0
ARG DOLT_VERSION=1.85.0

# TARGETARCH is injected by BuildKit (amd64 | arm64)
ARG TARGETARCH

# ---------------------------------------------------------------------------
# 1. System packages (single layer, cache cleaned)
# ---------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        jq \
        tmux \
        procps \
        lsof \
        util-linux \
        sudo \
        locales \
        openssh-client \
        make \
        wget \
        unzip \
        libicu74 \
        systemd \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# 2. Locale setup — en_US.UTF-8
# ---------------------------------------------------------------------------
RUN sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ---------------------------------------------------------------------------
# 3. Dolt — SQL database backing Beads
#
# Release archive: dolt-linux-{amd64,arm64}.tar.gz
# Note: Dolt does not publish checksums.txt — verified by version check only
# ---------------------------------------------------------------------------
RUN set -eux; \
    ARCH="${TARGETARCH:-amd64}"; \
    TARBALL="dolt-linux-${ARCH}.tar.gz"; \
    curl -fsSL "https://github.com/dolthub/dolt/releases/download/v${DOLT_VERSION}/${TARBALL}" \
        -o "/tmp/${TARBALL}"; \
    tar -xzf "/tmp/${TARBALL}" -C /tmp; \
    install "/tmp/dolt-linux-${ARCH}/bin/dolt" /usr/local/bin/dolt; \
    rm -rf /tmp/dolt*; \
    dolt version

# ---------------------------------------------------------------------------
# 4. Gas City (gc) — multi-agent orchestration CLI
#
# Release archive: gascity_<V>_linux_{amd64,arm64}.tar.gz
# Checksums:       checksums.txt in the release
# ---------------------------------------------------------------------------
RUN set -eux; \
    ARCH="${TARGETARCH:-amd64}"; \
    TARBALL="gascity_${GC_VERSION}_linux_${ARCH}.tar.gz"; \
    curl -fsSL "https://github.com/gastownhall/gascity/releases/download/v${GC_VERSION}/${TARBALL}" \
        -o "/tmp/${TARBALL}"; \
    curl -fsSL "https://github.com/gastownhall/gascity/releases/download/v${GC_VERSION}/gascity_${GC_VERSION}_checksums.txt" \
        -o /tmp/checksums.txt; \
    cd /tmp && grep "${TARBALL}" checksums.txt | sha256sum -c -; \
    tar -xzf "/tmp/${TARBALL}" -C /tmp; \
    install /tmp/gc /usr/local/bin/gc; \
    rm -rf /tmp/gc* /tmp/gascity* /tmp/checksums.txt; \
    gc version

# ---------------------------------------------------------------------------
# 5. Beads (bd) — distributed issue tracker
#
# Release archive: beads_<V>_linux_{amd64,arm64}.tar.gz
# Checksums:       checksums.txt in the release
#
# ---------------------------------------------------------------------------
RUN set -eux; \
    ARCH="${TARGETARCH:-amd64}"; \
    TARBALL="beads_${BD_VERSION}_linux_${ARCH}.tar.gz"; \
    curl -fsSL "https://github.com/gastownhall/beads/releases/download/v${BD_VERSION}/${TARBALL}" \
        -o "/tmp/${TARBALL}"; \
    curl -fsSL "https://github.com/gastownhall/beads/releases/download/v${BD_VERSION}/checksums.txt" \
        -o /tmp/checksums.txt; \
    cd /tmp && grep "${TARBALL}" checksums.txt | sha256sum -c -; \
    tar -xzf "/tmp/${TARBALL}" -C /tmp; \
    install /tmp/bd /usr/local/bin/bd; \
    rm -rf /tmp/bd* /tmp/beads* /tmp/checksums.txt; \
    bd version

# ---------------------------------------------------------------------------
# 5b. GitHub CLI (gh) — PR/issue management, used by agents for repo ops
# ---------------------------------------------------------------------------
RUN set -eux; \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg; \
    chmod 0644 /usr/share/keyrings/githubcli-archive-keyring.gpg; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh; \
    rm -rf /var/lib/apt/lists/*; \
    gh --version

# ---------------------------------------------------------------------------
# 6. AI Agent CLIs
#
# Claude Code — native installer (no Node.js required)
# Codex CLI  — npm package (Node.js required at runtime as wrapper)
# Amp        — standalone binary via install script
#
# Node.js is installed because Codex CLI is distributed via npm and uses
# Node.js as its runtime wrapper around the Rust binary. Per spec B.4:
# "If a CLI requires Node.js as a runtime dependency, Node.js stays."
# ---------------------------------------------------------------------------

# 6a. Node.js LTS (required by Codex CLI npm package at runtime)
ARG NODE_MAJOR=22
RUN set -eux; \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -; \
    apt-get install -y --no-install-recommends nodejs; \
    rm -rf /var/lib/apt/lists/*; \
    node --version; npm --version

# 6b. Claude Code — installed per-user after user setup (see section 8)
#     The native installer is Anthropic's recommended path over npm and
#     avoids the deprecation warning shown when launching via npm.

# 6c. Codex CLI (OpenAI) — installed via npm (Rust binary, Node wrapper)
RUN set -eux; \
    npm install -g @openai/codex; \
    codex --version

# 6d. Amp CLI (Sourcegraph) — standalone binary via install script
#     The installer places the binary at ~/.local/bin/amp. We move it to
#     /usr/local/bin so it is available to all users. Use full path for
#     verification since ~/.local/bin may not be in PATH.
RUN set -eux; \
    curl -fsSL https://ampcode.com/install.sh | bash; \
    if [ -f /root/.local/bin/amp ]; then \
        mv /root/.local/bin/amp /usr/local/bin/amp; \
    fi; \
    /usr/local/bin/amp --version

# ---------------------------------------------------------------------------
# 7. User setup — devuser (UID 1000, GID 1000)
# ---------------------------------------------------------------------------
# Ubuntu noble may already have a user/group with UID/GID 1000 (e.g. ubuntu).
# Remove any existing user/group first, then create devuser cleanly.
RUN (getent group 1000 | cut -d: -f1 | xargs -r groupdel || true) \
    && (getent passwd 1000 | cut -d: -f1 | xargs -r userdel -r || true) \
    && groupadd --gid 1000 devuser \
    && useradd --uid 1000 --gid devuser --shell /bin/bash --create-home devuser \
    && echo "devuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/devuser \
    && chmod 0440 /etc/sudoers.d/devuser

# Create /workspaces owned by devuser
RUN mkdir -p /workspaces \
    && chown devuser:devuser /workspaces

# ---------------------------------------------------------------------------
# 8. Claude Code — native installer, run as devuser
#     Places binary at /home/devuser/.local/bin/claude. Added to PATH below.
# ---------------------------------------------------------------------------
USER devuser
RUN set -eux; \
    curl -fsSL https://claude.ai/install.sh | bash; \
    /home/devuser/.local/bin/claude --version

# ---------------------------------------------------------------------------
# 9. Final configuration
# ---------------------------------------------------------------------------
WORKDIR /workspaces

ENV SHELL=/bin/bash
ENV PATH=/home/devuser/.local/bin:$PATH

# OCI image labels
LABEL org.opencontainers.image.source="https://github.com/dataviking-tech/agent-dev-base"
LABEL org.opencontainers.image.description="Lightweight base image for AI agent development with Gas City orchestration, Beads issue tracking, and AI coding CLIs"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.title="agent-dev-base"

CMD ["bash"]
