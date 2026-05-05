---
status: Accepted
date: 2026-04-30
deciders: shane
---

# ADR-001: 5-component breakdown

## Context

The Clear Skies project replaces the existing Belchertown weewx skin with a modern, modular weather UI. Need to decide how the codebase is structured: monolith or multi-component, and at what granularity.

Constraints:
- Must be installable in pieces — not every weewx user wants every component (HA users may already run an MQTT broker; some users only need the API to drive their own UI)
- Must support independent versioning so components can release on independent cadences
- Must be approachable enough for the typical weewx user (one to two repos for core install, others optional)

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Single monolith repo | Simple to release, single CI pipeline | All-or-nothing adoption; couples release cadences; doesn't fit subset-adoption use cases |
| Many fine-grained components (~10+) | Maximum flexibility | Coordination overhead, version-skew risk, install confusion |
| Small modular set (5 components) | Adoptable in pieces, manageable count | Still requires inter-repo coordination |

## Decision

Five components, each in its own repo:

1. **`weewx-clearskies-api`** — read-only HTTP/JSON API over weewx data (Python/FastAPI)
2. **`weewx-clearskies-realtime`** — SSE bridge for live updates (Python). Per [ADR-005](ADR-005-realtime-architecture.md), supports both direct-read and MQTT subscriber modes
3. **`weewx-clearskies-dashboard`** — React SPA (the visible product)
4. **`weewx-clearskies-stack`** — meta repo serving **both** deployment paths:
   - **Docker-compose** with bundled Caddy (auto-LE TLS) for new users with no existing web infrastructure
   - **Drop-in install** for users with existing Apache or nginx — provides systemd unit files, example reverse-proxy vhost configs (TLS terminated at the user's existing proxy), and an upgrade guide
   - Plus: HA config examples (REST sensors + MQTT YAML), architecture diagrams, deployment topology variants
5. **`weewx-clearskies-design-tokens`** — Tailwind config + design variables as an npm package (deferred to Phase 6+; tokens live inside the dashboard repo until external demand exists)

## Consequences

- Five repos to maintain. CI scaffolding required per repo.
- Operators can adopt subsets:
  - HA-only user → run `api` only, point HA at it via REST sensor
  - SPA + own MQTT bridge → run `api` + `dashboard`, skip `realtime`
  - New user with no existing web infra → full stack via `stack`'s docker-compose path (Caddy bundled)
  - User with existing Apache/nginx → full stack via `stack`'s drop-in path (systemd units + example vhost configs, TLS at existing proxy)
- Inter-component versioning: `api` exposes a versioned URL contract (`/api/v1/...`); `dashboard` and `realtime` consume that contract. Breaking changes trigger `/api/v2/...`, never silent reshape.
- `design-tokens` deferred avoids premature packaging work; tokens still exist as code inside the dashboard from day 1.

## Implementation guidance

- Repo names follow [ADR-004](ADR-004-repo-naming.md).
- Each repo has its own `README`, `INSTALL`, `CONFIG`, `SECURITY`, `DEVELOPMENT`, `CHANGELOG`, `LICENSE` per Phase 1 documentation gate.
- The `stack` repo is the recommended entry point for new users — its README is the "front door" link from any community announcement.
- API contract is the inter-component coupling point.

## References

- Related ADRs: [ADR-002](ADR-002-tech-stack.md) (tech stack), [ADR-003](ADR-003-license.md) (license), [ADR-004](ADR-004-repo-naming.md) (repo naming), [ADR-005](ADR-005-realtime-architecture.md) (realtime architecture)
- Plan: [Components section in CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md)
