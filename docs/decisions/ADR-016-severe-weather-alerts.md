---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-016: Severe weather alerts source

## Context

Cat 3 walk thread locked the alert banner UX ([ADR-024](ADR-024-page-taxonomy.md)). [ADR-010](ADR-010-canonical-data-model.md) locks `AlertRecord` and `AlertList` canonical types. This ADR locks the source providers and the aggregation policy.

## Decision

### Alerts as a clearskies-api provider domain

Alerts are their own domain under [ADR-038](ADR-038-data-provider-module-organization.md), with provider modules at `weewx_clearskies_api/providers/alerts/`. Same pattern as forecast ([ADR-007](ADR-007-forecast-providers.md)) and AQI ([ADR-013](ADR-013-aqi-handling.md)).

### Day-1 provider set

| Module | Coverage | Free path |
|---|---|---|
| `nws` | US + US territories + adjacent waters | Free, no key |
| `aeris` | US + Canada + Europe (NWS + Environment Canada + MeteoAlarm + UK Met + JMA + BoM redistributed) | PWS-contributor track via PWSWeather |
| `openweathermap` | Global government alerts | Paid (One Call 3.0 subscription) |

### Single source per deploy

Operator picks **one** alerts module at setup; configuration UI suggests by region from operator lat/lon. Same single-provider-per-domain model as forecast and AQI. No multi-source aggregation in v0.1 — deduping the same NWS alert delivered via NWS-direct vs Aeris-redistribution is complicated and the user-visible benefit is small.

### Operators outside covered regions

If the operator's region isn't covered by any of the three modules, the alert banner doesn't render — render-time sensor-availability detection (cat 10) handles the empty case. No error, no nag.

### Canonical fields

Each module translates upstream payloads into `AlertRecord` per [ADR-010](ADR-010-canonical-data-model.md): `id`, `severity`, `urgency`, `certainty`, `event`, `headline`, `description`, `effective`, `expires`, `senderName`, `areaDesc`, `category`.

### Polling cadence

Alert provider responses cached via [ADR-017](ADR-017-provider-response-caching.md) at the 5-minute default TTL.

### AQI alerts

NWS Air Quality Alerts (AQA) and Air Stagnation Advisories (AS_Y) flow through the standard NWS alerts feed naturally — no separate AQI alerting per [ADR-013](ADR-013-aqi-handling.md).

## Options considered

| Option | Verdict |
|---|---|
| A. Single source per deploy, three day-1 modules per ADR-038 (this ADR) | **Selected** — uniform with forecast/AQI provider patterns. |
| B. Aggregate from multiple configured sources, dedupe across upstream IDs | Rejected — dedupe logic across upstream alert ID schemes is complex; user-visible benefit small. Phase 6+ if demand surfaces. |
| C. Primary + fallback | Rejected — adds branching for failure modes that are rare; operators can switch providers in config if their primary keeps failing. |
| D. No alerts at v0.1 | Rejected — severe-weather alerting is core for a weather dashboard. |

## Consequences

- Phase 2 builds three alerts modules under `weewx_clearskies_api/providers/alerts/`.
- Setup wizard suggests `nws` for US, `aeris` for Canada / Europe, `openweathermap` for everywhere else (with a note on the One Call 3.0 paid tier).
- Capability declarations carry geographic coverage for the recommendation engine.
- Operators in uncovered regions see no alert banner and no nag.
- Adding regional alert providers (BoM direct, MeteoAlarm direct, JMA direct, KMA, etc.) is a new-module PR per [ADR-038](ADR-038-data-provider-module-organization.md).

## Out of scope

- Multi-source aggregation — Phase 6+.
- Push notifications (web push, email, SMS) — Phase 6+.
- Custom user-defined alert thresholds (e.g., "notify when wind > 50 mph") — Phase 6+; orthogonal to upstream alerts.
- AQI-specific alerting — covered by NWS pipeline per [ADR-013](ADR-013-aqi-handling.md).

## References

- NWS Alerts API: https://www.weather.gov/documentation/services-web-api
- Aeris alerts endpoint: https://www.xweather.com/docs/weather-api/endpoints/alerts
- Walk artifact: cat 3 in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Related: [ADR-007](ADR-007-forecast-providers.md), [ADR-010](ADR-010-canonical-data-model.md), [ADR-013](ADR-013-aqi-handling.md), [ADR-017](ADR-017-provider-response-caching.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-038](ADR-038-data-provider-module-organization.md).
