---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-039: Distribution and installation mechanism

## Context

The cat 8 walk surfaced this as an open question: "pip install is hostile to non-Python Windows users; people understand downloadable installers." This ADR locks how clearskies-* artifacts reach operators across operating systems. Sibling: [ADR-028](INDEX.md) (update mechanism, Pinned).

## Decision

### Three distribution channels

1. **PyPI** — `pip install weewx-clearskies-api` (and -realtime). For Linux / macOS operators running native installs alongside weewx.
2. **Container registry** (GitHub Container Registry / Docker Hub) — pre-built images for api / realtime / dashboard. The `clearskies-stack` docker-compose pulls from there.
3. **GitHub Releases** — tagged source artifacts (`.tar.gz`) per repo for operators who want to build from source.

### Per-OS recommendation

| OS | Recommended install path |
|---|---|
| Linux (Debian / Ubuntu / RHEL / Pi OS) | Native (pip + systemd) OR docker-compose. Per [ADR-034](ADR-034-deployment-topology-default.md). |
| macOS | Native (pip + launchd via a generated `.plist` template) OR docker-compose (Docker Desktop or Colima). |
| Windows | **docker-compose with Docker Desktop**, full stop. |

### What the user concern is about

Cat 8 captured: "pip install is hostile to non-Python Windows users." The honest answer for v0.1: **don't recommend pip install for Windows users** — recommend docker-compose with Docker Desktop. Docker is the cross-platform install seam; pip is the Linux/macOS-native option for operators comfortable with Python tooling. Same reasoning applies to non-technical macOS users.

### No bespoke OS installers

Clear Skies does NOT ship MSI installers, `.pkg` bundles, AppImages, Snap, or Flatpak at v0.1. Reasoning:

- A Python web service is awkward to bundle as a native OS installer (interpreter, venv, service registration, auto-start config, log routing — each OS has different conventions).
- Docker Desktop on Windows / macOS is the established way to run Linux-style services on those OSes.
- Bespoke installers are a maintenance black hole (signing certs, packaging tools per OS, update flows per format) for a single-maintainer GPL project.

If a native installer is a frequent ask post-launch, revisit in Phase 6+.

## Options considered

| Option | Verdict |
|---|---|
| A. PyPI + Docker images + GitHub source releases; Docker for Windows / macOS non-Python users (this ADR) | **Selected** — uses standard ecosystem channels; Docker handles cross-OS without bespoke installer maintenance. |
| B. Native installers per OS (MSI, .pkg, AppImage, etc.) | Rejected — disproportionate maintenance burden for a single-maintainer project. |
| C. PyPI only | Rejected — leaves Windows / macOS non-Python users with no clear path. |
| D. Docker only | Rejected — many Linux operators run native alongside weewx and don't want Docker overhead. |

## Consequences

- Phase 5 work: CI release workflow per repo publishes to (1) PyPI for api/realtime, (2) container registry for all four containerized components, (3) GitHub Releases tag with source.
- `clearskies-stack` README points Windows / macOS users at Docker Desktop with a one-page setup walk-through.
- Per-repo INSTALL.md has Linux native + Linux Docker + macOS native + macOS Docker + Windows Docker sections; Windows native is documented as "unsupported, operator's risk."
- No code-signing certs needed (no MSI/pkg/dmg/AppImage to sign).

## Out of scope

- Native OS installers (MSI / pkg / AppImage / Snap / Flatpak) — Phase 6+ if asked for repeatedly.
- Homebrew formula — Phase 6+ if a maintainer takes it on.
- Auto-update flows — [ADR-028](INDEX.md) (Pinned).

## References

- Related: [ADR-001](ADR-001-component-breakdown.md), [ADR-002](ADR-002-tech-stack.md), [ADR-018](ADR-018-api-versioning-policy.md), [ADR-028](INDEX.md), [ADR-032](ADR-032-versioning-across-repos.md), [ADR-034](ADR-034-deployment-topology-default.md).
- Walk artifact: cat 8 cross-cutting threads in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
