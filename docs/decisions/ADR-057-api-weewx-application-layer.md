---
status: Accepted
date: 2026-06-13
deciders: shane
supersedes:
superseded-by:
---

# ADR-057: The Clear Skies API is the weewx application layer

## Context

Through the process of building Clear Skies, the API has accumulated capabilities piecemeal — unit conversion, derived calculations, aggregations, real-time delivery, multi-source data merging. Stepping back, the pattern is clear: the Clear Skies API is becoming the application layer that weewx never built.

weewx excels at one thing: ingesting hardware data and writing it to a database. Everything above that — unit conversion, derived calculations (xtypes), aggregations, time-bounded queries, real-time delivery — weewx only exposes to skins running inside its own process via Python objects and Cheetah template tags. There is no external API. There is no HTTP interface. External applications cannot access these capabilities.

We've been treating the API as "the Clear Skies backend" — a backend for our dashboard. But what we're actually building is the weewx API that weewx never shipped. One that any frontend, any integration, any automation could talk to.

This reframing matters because it changes the API's completeness bar. We're not just building "enough API for our dashboard." We're building the canonical programmatic interface to a weewx station's data and capabilities.

## Options considered

| Option | Verdict |
|---|---|
| A. Reframe API as the weewx application layer (this ADR) | **Selected.** Matches what we're already building; provides a completeness target. |
| B. Keep API scoped to "Clear Skies dashboard backend only" | Rejected — artificially limits scope; we're already past this. |
| C. Fork weewx and build the API into it | Rejected — weewx is a separate project; we build on top, not inside. |

## Decision

The Clear Skies API is the weewx application-layer API. It encapsulates everything weewx provides to skins, plus external provider aggregation and multi-source merging that weewx never did.

**What the API must eventually cover (the capability surface):**

| Category | weewx skin capability | API status |
|---|---|---|
| Raw observations | Archive records, loop packets | Covered (REST + SSE after Phase 3) |
| Unit conversion | 14 unit groups, per-group display unit selection | Covered (merged into API per ADR-058) |
| Derived observations (xtypes) | windchill, heatindex, dewpoint, appTemp, humidex, ET, pressure reductions, beaufort, wind run | Partially covered (beaufort, comfort index). Remaining: future phase |
| Aggregation system | min/max/avg/sum/count over time spans | Covered (`/archive` with `agg` and `aggregate_interval`) |
| Time-bounded queries | Date range filtering | Covered (`from`/`to` params) |
| Daily summaries | Pre-aggregated min/max/sum/count per day | Not covered — future phase |
| Calendar grouping | Monthly/yearly aggregates | Covered (`/archive/grouped`) |
| String formatting | Unit labels, decimal places, compass directions | Covered (unit conversion module) |

**What Clear Skies adds beyond weewx:**

- External provider aggregation (forecast, AQI, alerts, radar, earthquakes, seeing)
- Multi-source data merging (provider API + weewx DB columns in same response)
- Multi-jurisdiction AQI with provider-native scales
- Real-time SSE without requiring MQTT
- RESTful HTTP interface with OpenAPI contract
- Caching, rate limiting, credential management for external providers
- Configuration wizard, branding, operator customization

**What this is NOT:**

- Not rewriting weewx's ingestion layer (hardware drivers, LOOP/archive collection). weewx remains the data collector.
- Not making weewx a dependency to eliminate. weewx is the foundation; we build the application layer on top.
- Not backwards-compatible with weewx's Cheetah tag syntax. Our interface is REST/JSON.
- Not a multi-station platform. Single station per [ADR-011](ADR-011-multi-station-scope.md).

## Consequences

- **Completeness bar rises.** The gap analysis table above becomes a planning input for future phases. Capabilities marked "not covered" are tracked, not forgotten.
- **API scope is broader than "what the dashboard needs."** Future consumers (Home Assistant integrations, mobile apps, custom scripts) are legitimate use cases, even though the dashboard is the primary consumer for v0.1.
- **xtypes integration is a future-phase goal.** ADR-056 establishes co-location and `weewx.units` import. Future work adds `weewx.xtypes` for derived observations the API currently can't compute (dewpoint, humidex, ET, etc.).
- **Daily summaries are a future-phase goal.** weewx's `archive_day_*` tables contain pre-aggregated data that the API doesn't currently use.
- **ADR-010 (canonical data model) remains authoritative** for the field contract between API and dashboard. This ADR doesn't change the data model — it changes the aspiration for what the API covers.

## Acceptance criteria

- [ ] Gap analysis table in this ADR is reviewed and accurate against current codebase
- [ ] ARCHITECTURE.md "Layer Responsibilities" section updated to reflect the reframed API role
- [ ] No existing endpoint removed or renamed (this is additive)

## Implementation guidance

This is a scope and vision ADR, not an implementation spec. No code changes are required for this ADR itself. It provides the architectural rationale for:
- Phase 2: co-location + unit auto-detection (ADR-056)
- Phase 3: realtime/BFF fold into API (T1.3 ADR)
- Future: xtypes integration, daily summary access, wind run, ET

The gap analysis table should be updated as capabilities are added in future phases.

## Out of scope

- Specific xtypes implementation plan (future phase)
- Daily summary table access implementation (future phase)
- Home Assistant integration design (separate project)
- Multi-station support ([ADR-011](ADR-011-multi-station-scope.md))

## References

- Related: [ADR-010](ADR-010-canonical-data-model.md) (data model), [ADR-011](ADR-011-multi-station-scope.md) (single station), [ADR-041](ADR-041-realtime-bff.md) (unit conversion / enrichment, merged into API), [ADR-056](ADR-056-api-weewx-co-location.md) (co-location)
- Backlog: FIX-006
- weewx capabilities: [docs/reference/weewx-5.3/](../../docs/reference/weewx-5.3/)
