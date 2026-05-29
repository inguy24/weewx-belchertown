---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-013: AQI handling

## Context

AQI is a first-class data category in Clear Skies — Now-page tile, Records section, homepage chart group. This ADR locks how AQI data reaches the dashboard at runtime.

## Decision

AQI providers are **clearskies-api plugin modules** per [ADR-038](ADR-038-data-provider-module-organization.md), same pattern as forecast providers per [ADR-007](ADR-007-forecast-providers.md). Modules live at `weewx_clearskies_api/providers/aqi/`.

**Day-1 provider set:** Aeris, OpenMeteo, OpenWeatherMap, IQAir AirVisual.

**Two operator paths:**
- **Path A — operator's own weewx extension** (e.g., `weewx-airvisual`) writes custom AQI columns to the archive. Operator maps those columns to canonical AQI fields at setup via [ADR-035](INDEX.md). Out of scope for Clear Skies — we never see the extension.
- **Path B — operator picks an AQI provider** in clearskies-api setup. The corresponding plugin module handles the API call and translation to canonical fields.

**Historical AQI:** `/aqi/history` reads from the weewx archive. Path A operators already have AQI columns in their archive — clearskies-api queries them like any other observation. Path B (provider-only) operators get live `/aqi/current` but no history unless they also configure a weewx extension to log AQI readings. clearskies-api does **not** maintain its own persistent AQI store; the weewx archive is the single source of truth for all time-series data.

**Canonical AQI fields** (defined in [ADR-010](ADR-010-canonical-data-model.md)): `aqi`, `aqiScale`, `aqiCategory`, `aqiMainPollutant`, `aqiLocation`, `observedAt`, `source`, plus optional `pollutantPM25` / `pollutantPM10` / `pollutantO3` / `pollutantNO2` / `pollutantSO2` / `pollutantCO`. **Scale discriminator:** Each `AQIReading` carries `aqiScale` identifying the native scale of the `aqi` value — `"epa"` (U.S. EPA 0–500, used by Aeris with `filter=airnow`) or `"owm"` (OpenWeatherMap 1–5 ordinal). Raw provider values are passed through **without ingest-time conversion** between scales; any display-scale conversion is applied by the dashboard using `aqiScale` as the discriminator. `aqiCategory` is always `None` from providers — it is dashboard-computed from `aqi + aqiScale`.

**AQI alerting** rides the existing alerts pipeline — NWS Air Quality Alerts (AQA) and Air Stagnation Advisories (AS_Y) already flow through cat 3. No separate AQI alerting in v0.1.

## Options considered

| Option | Verdict |
|---|---|
| A. AQI providers as clearskies-api plugin modules (this ADR) | **Selected** — uniform with every other provider integration per [ADR-038](ADR-038-data-provider-module-organization.md). |
| B. Bundled multi-provider AQI weewx extension that writes to the archive | Rejected — Clear Skies ships zero weewx extensions. |
| C. clearskies-api only reads operator-supplied archive columns; never calls AQI providers | Rejected — forces every operator to install some weewx extension; doesn't honor operators who'd rather pick a provider in setup. |

## Consequences

- Phase 2 builds Aeris / OpenMeteo / OpenWeatherMap / IQAir modules under `weewx_clearskies_api/providers/aqi/`, conforming to [ADR-038](ADR-038-data-provider-module-organization.md)'s five responsibilities.
- Setup wizard ([ADR-027](ADR-027-config-and-setup-wizard.md)) presents Path A vs Path B as a choice. Path A → column-mapping flow per [ADR-035](INDEX.md). Path B → provider-pick + key entry.
- Operators with neither path configured see no AQI features. The AQI card on the Now page renders a "no data" placeholder (`t('noData.airQuality')`) when `aqi` is null — the card itself is always present in the layout, not conditionally removed. AQI does not appear in the Charts page or the Records page at v0.1; those pages have no AQI components.
- `/aqi/history` implementation reads weewx archive AQI columns using the same DB access pattern as other observation history endpoints. No separate writeable datastore needed.
- Non-EPA-native AQI scales (OWM 1–5, European AQI, etc.) are passed through as-is with the corresponding `aqiScale` value. Ingest-time conversion to EPA scale is **not performed**. Display-scale normalization, if needed, is a dashboard concern.

## Out of scope

- AQI scale conversion table for non-EPA sources (Phase 2).
- AQI caching strategy ([ADR-017](INDEX.md), Pinned).
- Cross-station AQI ([ADR-011](ADR-011-multi-station-scope.md), single-station only).

## References

- Related ADRs: [ADR-006](ADR-006-compliance-model.md), [ADR-007](ADR-007-forecast-providers.md), [ADR-010](ADR-010-canonical-data-model.md), [ADR-011](ADR-011-multi-station-scope.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-035](INDEX.md) (Pinned), [ADR-038](ADR-038-data-provider-module-organization.md).
- Walk artifact: cat 4 in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
