---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-011: Multi-station scope for v0.1

## Context

[ADR-010](ADR-010-canonical-data-model.md) locked the canonical data model as single-station and deferred the "do we ship multi-station?" question here. This ADR makes the call so Phase 2 can implement without ambiguity.

The weewx ecosystem is fundamentally single-station: weewx itself runs one daemon per station; multi-station setups run multiple weewx instances; every major skin (Belchertown, Seasons, Smartphone, Beautiful Dashboard, Weather Eye) is single-station. The driving deployment is one station. No multi-station use case is requested today.

## Options considered

| Option | Verdict |
|---|---|
| A. Single-station only for v0.1; multi-station explicitly out-of-scope | **Selected.** Matches weewx ecosystem. No payload bloat, no station-selector UI, no `?station=` plumbing, no per-tenant config scope. |
| B. Single-station for v0.1 with documented forward-compat path (reserve `?station=`, document optional `stationId`) | Rejected — adds documentation/stub surface for a feature with no demand. Forward-compat is already structurally clean per [ADR-010](ADR-010-canonical-data-model.md). |
| C. Multi-station from day 1 | Rejected — pre-builds for no demand; expands Phase 2 massively (every endpoint gets `?station=`, every record gets `stationId`, dashboard gets a picker, configuration UI gets a tenant model, auth has to consider per-station access, alerts and forecasts fan out per station, realtime multiplexes N streams). |
| D. Multi-station as configurable mode | Rejected — every code path now has two branches; tests double; multi-mode is unproven. Classic over-engineering. |

## Decision

**Single-station only for v0.1.** One `weewx-clearskies-api` instance ↔ one weewx archive DB ↔ one `StationMetadata` ↔ one realtime stream ↔ one dashboard. Operators running multiple weewx stations run multiple Clear Skies stacks (one per station), each on its own subdomain or path.

Multi-station is explicitly **out-of-scope** for v0.1 — not "in the backlog." Revisit if concrete demand surfaces post-launch. Forward-compat is structurally clean per [ADR-010](ADR-010-canonical-data-model.md): adding optional `stationId` per record, optional `?station=<id>` query, list `StationMetadata` would all be non-breaking extensions. None of these break existing v0.1 clients.

## Consequences

- **Zero ambiguity for Phase 2.** Endpoints don't take a station parameter; realtime has one event stream; dashboard has no picker; configuration UI configures one station.
- **Smaller surface area** in every component. No tenant model in auth ([ADR-008](ADR-008-auth-model.md)). No fan-out in forecasts/alerts. No multiplexing in realtime.
- **Matches the weewx ecosystem** — operator installs Clear Skies and gets exactly what their weewx instance represents without learning a new model.
- **[ADR-010](ADR-010-canonical-data-model.md) already designed for this** — no retrofit.
- **Future flexibility preserved structurally** — multi-station extension is non-breaking per [ADR-010](ADR-010-canonical-data-model.md).

### Trade-offs accepted
- **One-pane-of-glass across multiple stations is a deployment-layer problem** for v0.1. Operators with two stations either (a) run two stacks behind one reverse-proxy on different paths, (b) wait for multi-station, or (c) merge data at the weewx layer. Same constraint every existing weewx skin imposes.
- **Configuration UI ([ADR-027](ADR-027-config-and-setup-wizard.md)) configures one station only.** Operators with two stacks configure each separately.
- **Auth ([ADR-008](ADR-008-auth-model.md)) has no per-station scope.** If multi-station is ever added, ADR-008 has to be revisited.

### Repos affected
No new code is gated on this ADR — it's a scope confirmation. What changes is what does NOT get built:
- **api:** no `?station=<id>` param on any v1 endpoint; `StationMetadata` is a singleton; no `/api/v1/stations` list endpoint.
- **realtime:** one SSE stream per instance; no per-station event filtering.
- **dashboard:** no station-picker UI.
- **stack:** configuration UI configures one station per deploy.
- **`docs/contracts/canonical-data-model.md`:** documents single-station scope and the non-breaking forward-compat path.
- **`docs/contracts/openapi-v1.yaml`:** no station path/query parameter on observation, archive, forecast, alert, AQI endpoints; `/api/v1/station` returns the singleton.

## Implementation guidance

### What "single-station" means concretely
- **api:** one archive DB connection (one `weewx.conf` path or one `database.url`); one `StationMetadata` from `/api/v1/station`; observation/archive/forecast/alert/AQI endpoints take no station identifier.
- **realtime:** one weewx loop packet source (one `weewx.conf` path or one MQTT topic); SSE clients subscribe to the stream.
- **dashboard:** one API base URL in config; one station's name and palette.
- **configuration UI:** one wizard pass configures one station.

### Edge cases that look like multi-station but aren't
- **Multiple sensors on one station** (extra temp/humidity, soil, lightning, AQI extension): single-station. Handled per [ADR-010](ADR-010-canonical-data-model.md) `extras` slot and [ADR-035](ADR-035-user-driven-column-mapping.md) promotion.
- **Station moved (lat/lon changed):** single-station; `StationMetadata` reflects current state. Historical archive rows are not retroactively re-tagged.
- **Two weewx instances on one host writing two databases:** that's two stations. Run two stacks.
- **One weewx instance with a custom service merging data from a remote station:** merging happens in weewx (out of Clear Skies scope). Clear Skies sees one archive DB → one station.

## Out of scope (and remains out of scope)
- `/api/v1/stations` list endpoint.
- `?station=<id>` query parameter on v1 endpoints.
- Per-station auth ([ADR-008](ADR-008-auth-model.md)).
- Per-station configuration tenancy ([ADR-027](ADR-027-config-and-setup-wizard.md)).
- Station-picker component in the dashboard.
- Multiplexing multiple weewx loop sources in realtime.

If any of these become required, that's a future ADR with its own scope and audit.

## References
- Related: [ADR-008](ADR-008-auth-model.md), [ADR-010](ADR-010-canonical-data-model.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-034](ADR-034-deployment-topology-default.md), [ADR-035](ADR-035-user-driven-column-mapping.md), [ADR-037](ADR-037-inbound-traffic-architecture.md).
