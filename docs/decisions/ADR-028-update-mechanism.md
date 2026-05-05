---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-028: Update mechanism for end users

## Context

Operators need to move from `clearskies-* vX.Y.Z` to a newer release. Sibling: [ADR-039](ADR-039-distribution-installation-mechanism.md) (initial install). [ADR-032](ADR-032-versioning-across-repos.md) governs SemVer per repo (independent, no lockstep, pre-1.0 minor bumps may break). [ADR-018](ADR-018-api-versioning-policy.md) sets the AS-IS posture: GPL v3, no support-window promises.

## Decision

### Updates use the same channel as install

| Install path | Update command |
|---|---|
| Native (`pip install`) | `pip install -U weewx-clearskies-api` (and `-realtime`); restart the systemd unit. |
| Docker / docker-compose | `docker compose pull && docker compose up -d`. Image tag updates per [ADR-032](ADR-032-versioning-across-repos.md). |
| Source tarball | `git pull` (or download new tarball) + reinstall per the repo's INSTALL.md. |

No in-app self-update mechanism at v0.1. The dashboard does not check for updates; the api does not auto-pull; Docker images do not embed Watchtower or similar.

### Upgrade guidance lives in CHANGELOG.md

Each repo's `CHANGELOG.md` is the single source of upgrade-relevant information per release: breaking changes, config-file migrations, schema changes, manual steps. Operators read CHANGELOG before upgrading. No separate UPGRADE.md per release; CHANGELOG entries call out breaking changes inline.

The cross-repo compatibility matrix in `clearskies-stack/README.md` (per [ADR-032](ADR-032-versioning-across-repos.md)) is where operators check that an api version + dashboard version + realtime version combination is supported.

### No support-window promises

Per [ADR-018](ADR-018-api-versioning-policy.md) and [ADR-003](ADR-003-license.md): software is AS-IS under GPL v3. No commitment to backport security fixes to older minor or major lines, no LTS branch, no end-of-life schedule. Operators stay current or accept the risk of running an old release. CHANGELOG may note "this release contains a security fix" — that's information, not a support commitment.

### Pre-1.0 caveat already locked elsewhere

[ADR-032](ADR-032-versioning-across-repos.md) already establishes that pre-1.0 minor bumps may ship breaking changes. ADR-028 inherits that — operators upgrading `0.5.0 → 0.6.0` may face manual steps documented in CHANGELOG. Post-1.0, breaking changes are major-bump only.

### Configuration preservation across upgrades

Operator configuration MUST survive any upgrade by default. Three rules:

1. **Native (pip) path.** Configuration lives at `/etc/weewx-clearskies/` per [ADR-027](ADR-027-config-and-setup-wizard.md) — outside the Python package. `pip install -U` writes only to `site-packages/`; `/etc/` is untouched. Config preservation is automatic.
2. **Docker path.** `clearskies-stack`'s shipped `docker-compose.yaml` MUST bind-mount the host's `/etc/weewx-clearskies/` (or operator-chosen path) into the container so config lives on the host filesystem. `docker compose pull` swaps the image; the bind-mounted volume is unchanged. Operators rolling their own compose without the bind-mount lose config on pull — documented loudly in `clearskies-stack/INSTALL.md`.
3. **Schema drift.** When a release adds a new required config field, the package code SHOULD default the missing field gracefully so older configs continue to load. When that's not feasible, CHANGELOG calls out the manual edit before the operator upgrades. Either path is acceptable per release; the rule is that config-file schema changes are always CHANGELOG-flagged, never silent.

## Options considered

| Option | Verdict |
|---|---|
| A. `pip install -U` / `docker compose pull` + CHANGELOG.md (this ADR) | **Selected** — uses standard ecosystem update flows; zero new code; matches install channels. |
| B. In-app self-update (dashboard checks GitHub Releases, prompts operator) | Rejected — adds runtime network dep on github.com, security surface (auto-execution), and complexity (which repos to check, version-pinning). Not warranted at v0.1. |
| C. Auto-update daemon (Watchtower for Docker, unattended-upgrades for native) | Rejected as default — silent updates of a self-hosted weather site is a foot-gun (a breaking minor bump pre-1.0 takes the site down at 3am). Operators who want this can wire it themselves; we don't ship it. |
| D. LTS branch with backported security fixes | Rejected — single-maintainer project; LTS commitment incompatible with [ADR-018](ADR-018-api-versioning-policy.md) AS-IS posture. |

## Consequences

- No update-checker code in api, realtime, or dashboard. Saves implementation surface.
- Documentation acceptance gate per repo: CHANGELOG.md must exist and be updated on every tagged release. Already in [CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md) doc criteria.
- `clearskies-stack/README.md` carries the cross-repo compatibility matrix per [ADR-032](ADR-032-versioning-across-repos.md); operators consult it before mixing versions.
- Operators on long-running deployments may end up far behind. Acceptable — that's the AS-IS posture. No nag banner in the dashboard.
- Phase 5 work: per-repo INSTALL.md gets an "Updating" section that points at `pip install -U` / `docker compose pull` and at CHANGELOG.md.
- Re-evaluate in Phase 6+ if the user community asks repeatedly for either a version-check banner or an LTS branch. Not before.

## Out of scope

- In-app or daemon-driven auto-update — Phase 6+ if asked for.
- LTS branch / security backports — incompatible with AS-IS posture.
- Database migrations across releases — handled per-release in CHANGELOG; if migrations become non-trivial, that's a separate ADR (Pinned only if it materializes).
- Rollback procedure — operators run `pip install weewx-clearskies-api==X.Y.Z` or `docker compose` with the prior tag; documented in INSTALL.md "Updating" section, not its own ADR.

## References

- Related: [ADR-003](ADR-003-license.md) (GPL v3), [ADR-018](ADR-018-api-versioning-policy.md) (API versioning + AS-IS), [ADR-032](ADR-032-versioning-across-repos.md) (independent SemVer per repo), [ADR-034](ADR-034-deployment-topology-default.md) (deployment topology), [ADR-039](ADR-039-distribution-installation-mechanism.md) (sibling — initial install channels).
