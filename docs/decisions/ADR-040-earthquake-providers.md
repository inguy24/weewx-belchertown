---
status: Accepted
date: 2026-05-05
deciders: shane
supersedes:
superseded-by:
---

# ADR-040: Earthquake providers

## Context

[ADR-024](ADR-024-page-taxonomy.md) makes the Earthquakes page a built-in v0.1 surface (recent events within configured radius, embedded map, provider-specific extras). [ADR-038](ADR-038-data-provider-module-organization.md) names the four day-1 modules but doesn't settle the same questions [ADR-016](ADR-016-severe-weather-alerts.md) (alerts) and [ADR-013](ADR-013-aqi-handling.md) (AQI) settle for their domains: single source per deploy vs. aggregate, default-by-region behaviour, what happens for operators outside coverage. This ADR closes that gap.

[ADR-010](ADR-010-canonical-data-model.md) (Proposed pending the 2026-05-05 EarthquakeRecord addition) defines the canonical event shape; provider research at [EARTHQUAKE-PROVIDER-RESEARCH.md](../reference/EARTHQUAKE-PROVIDER-RESEARCH.md).

## Decision

### Earthquakes as a clearskies-api provider domain

Earthquake providers are clearskies-api plugin modules per [ADR-038](ADR-038-data-provider-module-organization.md), at `weewx_clearskies_api/providers/earthquakes/`. Same pattern as forecast / AQI / alerts.

### Day-1 provider set

| Module | Coverage | Free path |
|---|---|---|
| `usgs` | Global (US-comprehensive; M2.5+ globally) | Free, no key |
| `geonet` | New Zealand | Free, no key (CC BY 4.0) |
| `emsc` | Europe + Mediterranean + global | Free, no key (CC BY 4.0) |
| `renass` | Mainland France + neighbouring countries | Free, no key (CC BY 4.0) |

All four are FDSN-Event-compliant or near-equivalent. Per-module capability declarations carry geographic coverage so the setup wizard can recommend per operator lat/lon.

### Single source per deploy

Operator picks **one** earthquake module at setup; configuration UI suggests by region from operator lat/lon. Same single-provider-per-domain model as forecast / AQI / alerts. No multi-source aggregation in v0.1 — deduping the same event delivered via USGS-direct vs EMSC-redistribution adds complexity for marginal user-visible benefit.

### Setup wizard recommendations

- US / Americas / global default → `usgs`
- New Zealand → `geonet`
- Europe / Mediterranean → `emsc`
- France / French-language preference → `renass`

Operator overrides freely; recommendations are suggestions, not gates.

### No uncovered-region case

USGS provides global coverage at M2.5+, so every operator can fall back to it. Unlike alerts ([ADR-016](ADR-016-severe-weather-alerts.md)) where some regions truly have no provider, earthquakes always have at least one option.

### Canonical fields

Each module translates upstream payloads into `EarthquakeRecord` per [ADR-010](ADR-010-canonical-data-model.md). Provider-specific fields not in the canonical (GeoNet `MMI` calculated for NZ, EMSC `flynn_region`, USGS `cdi`/`sig`/`gap`, etc.) flow through the `extras` dict.

### Polling / caching cadence

Per-module TTL declared in capability per [ADR-038](ADR-038-data-provider-module-organization.md), respecting each provider's update cadence and politeness guidance. Cached per [ADR-017](ADR-017-provider-response-caching.md). Earthquake-domain default TTL is intentionally not fixed in this ADR — modules pick.

## Options considered

| Option | Verdict |
|---|---|
| A. Single source per deploy, four day-1 modules per ADR-038 (this ADR) | **Selected** — uniform with forecast/AQI/alerts patterns. |
| B. Aggregate from multiple configured sources, dedupe on event ID | Rejected — dedupe across upstream IDs is complex; user-visible benefit small. Phase 6+ if demand surfaces. |
| C. USGS-only (global coverage means others are redundant) | Rejected — drops GeoNet's NZ-native MMI calculation and ReNaSS's regional French detail (both surfaced via `extras` per [ADR-024](ADR-024-page-taxonomy.md) cat 6). |
| D. No earthquakes at v0.1 | Rejected — Earthquakes page is in [ADR-024](ADR-024-page-taxonomy.md). |

## Consequences

- Phase 2 builds four modules under `weewx_clearskies_api/providers/earthquakes/`.
- Setup wizard suggests by lat/lon; operator confirms or overrides.
- Capability declarations carry geographic coverage for the recommendation engine.
- Adding regional providers (JMA Japan, IGN Spain, INGV Italy, etc.) is a new-module PR per [ADR-038](ADR-038-data-provider-module-organization.md).

## Out of scope

- Multi-source aggregation — Phase 6+.
- Push notifications for nearby quakes — Phase 6+.
- User-defined alert thresholds (e.g., notify when M ≥ 5 within 100 km) — Phase 6+.
- Tsunami advisories — USGS `tsunami` flag flows through `EarthquakeRecord`; richer tsunami-specific feeds out of scope at v0.1.

## References

- USGS FDSN-Event API: https://earthquake.usgs.gov/fdsnws/event/1/
- GeoNet API: https://api.geonet.org.nz/
- EMSC SeismicPortal: https://www.seismicportal.eu/webservices.html
- ReNaSS FDSN endpoint: https://renass.unistra.fr/fdsnws/event/1/query
- Research: [EARTHQUAKE-PROVIDER-RESEARCH.md](../reference/EARTHQUAKE-PROVIDER-RESEARCH.md).
- Related: [ADR-010](ADR-010-canonical-data-model.md), [ADR-013](ADR-013-aqi-handling.md), [ADR-015](ADR-015-radar-map-tiles-strategy.md), [ADR-016](ADR-016-severe-weather-alerts.md), [ADR-017](ADR-017-provider-response-caching.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-038](ADR-038-data-provider-module-organization.md).
