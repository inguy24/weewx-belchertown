---
status: Accepted
date: 2026-04-30
deciders: shane
---

# ADR-004: Repo naming convention

## Context

The 5 components from [ADR-001](ADR-001-component-breakdown.md) each need a public GitHub repo name. Naming choice affects:
- Discoverability for weewx users searching for weather-skin replacements
- Brand cohesion across repos
- Clarity of family relationship between repos
- Length/typability in install commands

## Options considered

| Option | Example | Pros | Cons |
|---|---|---|---|
| Bare names | `api`, `dashboard` | Cleanest, shortest | Ambiguous in multi-org search; doesn't telegraph weewx ecosystem |
| `clearskies-*` prefix | `clearskies-api` | Branded as a family | Doesn't telegraph weewx affinity to ecosystem users |
| `weewx-clearskies-*` prefix | `weewx-clearskies-api` | Telegraphs both weewx ecosystem AND project family | Slightly longer |

## Decision

Use the **`weewx-clearskies-*`** prefix on all five repos:

- `weewx-clearskies-api`
- `weewx-clearskies-realtime`
- `weewx-clearskies-dashboard`
- `weewx-clearskies-stack`
- `weewx-clearskies-design-tokens` (deferred per [ADR-001](ADR-001-component-breakdown.md))

User intent (verbatim): "this needs to be clear to me and others this is weewx related."

## Consequences

- A weewx user searching GitHub for "weewx" surfaces all five repos as a coherent family.
- Repo URLs are slightly longer; install commands and docs accept this trade.
- Future modules in this project family adopt the same prefix.
- The existing fork at `github.com/inguy24/weewx-belchertown` keeps its name (it tracks an upstream); the prefix convention applies only to *new* Clear Skies repos.
- All five repos created under `github.com/inguy24/`.

## Implementation guidance

- Repo descriptions begin with the project family — e.g., "weewx-clearskies-api · Read-only HTTP/JSON API over weewx data."
- Documentation cross-references use the full prefixed name on first mention; subsequent references can shorten (e.g., "the api service" within a doc that already established context).
- Python packages within `weewx-clearskies-api` and `-realtime` use module names like `weewx_clearskies_api` (snake_case, prefix retained) so `pip` installs of those packages have unambiguous names too.
- npm package for `weewx-clearskies-design-tokens` (when extracted in Phase 6+) uses the scope `@inguy24/weewx-clearskies-design-tokens` or similar.

## References

- Related ADRs: [ADR-001](ADR-001-component-breakdown.md)
- Plan: [Components section in CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md)
