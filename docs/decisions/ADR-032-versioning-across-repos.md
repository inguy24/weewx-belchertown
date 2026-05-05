---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-032: Versioning policy across repos

## Context

Clear Skies ships five repos ([ADR-001](ADR-001-component-breakdown.md)): clearskies-api, clearskies-realtime, clearskies-dashboard, clearskies-stack, clearskies-design-tokens (deferred Phase 6+). Each is independently versioned. This ADR locks what triggers a major bump per repo and how versions correlate.

## Decision

### Semver per repo, no lockstep

Each repo follows independent SemVer (`MAJOR.MINOR.PATCH`). A major bump in one does NOT force a major bump in the others.

### Major-bump triggers per repo

| Repo | Major bump triggers |
|---|---|
| `clearskies-api` | URL-path API version change (`/api/v1` → `/api/v2`); any breaking-change item from [ADR-018](ADR-018-api-versioning-policy.md). |
| `clearskies-realtime` | Breaking SSE event format change; breaking config schema change. |
| `clearskies-dashboard` | Breaking config schema change; breaking minimum-API-version requirement. |
| `clearskies-stack` | Breaking change to docker-compose orchestration; recommended-versions matrix bumps to a new major in any required component. |

### Minor / patch within repos

- **Minor** — backward-compatible additions (new endpoint, new dashboard page, new optional config).
- **Patch** — bug fixes, internal refactors, doc-only changes.

### Pre-1.0 caveat

All repos start at `0.x`. **Pre-1.0, minor bumps can ship breaking changes** — standard SemVer interpretation that 0.x is unstable. 1.0.0 across all repos signals "API is stable; SemVer is enforced strictly."

### Cross-repo compatibility matrix

`clearskies-stack` README documents the compatibility matrix — which `api` / `realtime` / `dashboard` versions are tested together. Operators upgrading follow the matrix. Mixing untested combinations is the operator's risk, consistent with the AS-IS posture from [ADR-018](ADR-018-api-versioning-policy.md).

### No coupled major bumps

If api ships v2 (breaking REST change) but the dashboard's v1.x line is still on a "compatible with api v1" matrix row, dashboard stays at v1.y until a real breaking change happens to it. Major numbers track real breaks, not coordination optics.

## Options considered

| Option | Verdict |
|---|---|
| A. Independent SemVer per repo + compatibility matrix in stack (this ADR) | **Selected** — honors the 5-component breakdown; doesn't force unnecessary major bumps. |
| B. Lockstep versioning (`X.Y.Z` across all repos) | Rejected — couples release cadences; forces major bumps that don't reflect actual breakage. |
| C. Calendar versioning (CalVer) | Rejected — communicates nothing about breaking-change risk; doesn't help operators decide whether to upgrade. |

## Consequences

- Each repo's `CHANGELOG.md` records its own version line.
- `clearskies-stack` README has a maintained compatibility table.
- CI release workflow per repo enforces SemVer-style tag format (`vMAJOR.MINOR.PATCH`).
- Pre-1.0 → 1.0 is a deliberate per-repo decision signaling API stability.

## Out of scope

- Specific 1.0 timing — driven by stability signal, not calendar.
- Backporting policy — single-maintainer; no LTS branch commitment per the AS-IS posture.
- Auto-version-bump tooling (`semantic-release`, `release-please`) — Phase 2+; manual tagging is fine for v0.x.

## References

- SemVer 2.0: https://semver.org/
- Related: [ADR-001](ADR-001-component-breakdown.md), [ADR-003](ADR-003-license.md), [ADR-018](ADR-018-api-versioning-policy.md), [ADR-028](INDEX.md) (update mechanism — Pinned).
