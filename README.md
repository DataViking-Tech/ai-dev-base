# ai-dev-base

Lightweight base image for AI agent development containers. Built on Debian
bookworm-slim for `linux/amd64` and `linux/arm64`. Published to GitHub Container
Registry (GHCR).

Bundles [Gas City](https://github.com/gastownhall/gascity) for multi-agent
orchestration, [Beads](https://github.com/gastownhall/beads) for distributed
issue tracking, [Dolt](https://github.com/dolthub/dolt) as the backing
database, and AI coding CLIs (Claude Code, Codex, Amp).

## Included tools

### Orchestration

| Tool | Binary | Version | Purpose |
|------|--------|---------|---------|
| Gas City | `gc` | 0.13.4 | Multi-agent orchestration CLI |
| Beads | `bd` | 1.0.0 | Distributed issue tracker |
| Dolt | `dolt` | 1.85.0 | SQL database backing Beads |

### AI coding CLIs

| Tool | Binary | Install method |
|------|--------|---------------|
| Claude Code | `claude` | Native installer (standalone, no Node.js) |
| Codex (OpenAI) | `codex` | npm global (`@openai/codex`) |
| Amp (Sourcegraph) | `amp` | Install script (standalone binary) |

### System packages

| Package | Purpose |
|---------|---------|
| `bash` | Default shell for gc, bd, and agent sessions |
| `ca-certificates` | HTTPS downloads |
| `curl` | HTTP client, health checks |
| `git` | Version control (gc prerequisite) |
| `jq` | JSON processing (gc prerequisite) |
| `tmux` | Session management (gc prerequisite) |
| `procps` | Provides `pgrep` (gc prerequisite) |
| `lsof` | File descriptor inspection (gc prerequisite) |
| `util-linux` | Provides `flock` for file locking |
| `sudo` | Privileged operations for devuser |
| `locales` | UTF-8 locale generation |
| `openssh-client` | Git SSH operations |
| `make` | Build tool for downstream Makefiles |
| `wget` | Alternate downloader |
| `unzip` | Archive extraction |
| `nodejs` | Node.js LTS (required by Codex CLI at runtime) |

### Runtime

| Property | Value |
|----------|-------|
| Node.js | v22 LTS (required by Codex CLI npm package) |

## What is NOT included

This is a **base image**. The following belong in downstream images:

- Python / pip / uv
- Go toolchain
- Rust toolchain
- Chromium / Playwright / headless browsers
- Docker CLI / Docker Compose
- Doppler / secrets management
- PostgreSQL client
- Project-specific config (CLAUDE.md, crew.json, etc.)
- Gas Town CLI (`gt`) -- install in downstream images if needed
- VS Code extensions / devcontainer metadata

## User setup

| Property | Value |
|----------|-------|
| Username | `devuser` |
| UID / GID | 1000 / 1000 |
| Home | `/home/devuser` |
| Shell | `/bin/bash` |
| sudo | Passwordless |
| Locale | `en_US.UTF-8` |
| WORKDIR | `/workspaces` |

## Usage

### Pull from GHCR

```bash
docker pull ghcr.io/dataviking-tech/ai-dev-base:latest
docker run -it ghcr.io/dataviking-tech/ai-dev-base:latest
```

### Extend in a downstream Dockerfile

```dockerfile
FROM ghcr.io/dataviking-tech/ai-dev-base:latest

# Add your language runtime
RUN sudo apt-get update && sudo apt-get install -y python3 python3-pip \
    && sudo rm -rf /var/lib/apt/lists/*
```

### Devcontainer

```json
{
  "image": "ghcr.io/dataviking-tech/ai-dev-base:latest"
}
```

## Tags

| Tag | When created | Description |
|-----|-------------|-------------|
| `latest` | Every push to `main` | Tracks the latest main branch build |
| `YYYY-MM-DD` | Every push to `main` | Date-stamped for reproducibility |
| `1.0.0` | Git tag `v1.0.0` | Immutable semver release |
| `1.0` | Git tag `v1.0.x` | Latest patch in minor series |
| `1` | Git tag `v1.x.x` | Latest minor in major series |
| `sha-<short>` | Every build | Commit SHA for traceability |

## Version pins

All orchestration tools are pinned via Dockerfile `ARG` directives. Override
at build time:

```bash
docker build \
  --build-arg GC_VERSION=0.14.0 \
  --build-arg BD_VERSION=1.1.0 \
  --build-arg DOLT_VERSION=1.86.0 \
  -t ai-dev-base .
```

## Building locally

```bash
# Single architecture
docker build --platform linux/amd64 -t ai-dev-base .

# Multi-architecture
docker buildx build --platform linux/amd64,linux/arm64 -t ai-dev-base .
```

## Checksum verification

All three orchestration tool binaries (gc, bd, dolt) are verified against the
`checksums.txt` published with each GitHub release. The SHA256 checksum is
validated after download and before installation. If verification fails, the
build fails.

## License

MIT
