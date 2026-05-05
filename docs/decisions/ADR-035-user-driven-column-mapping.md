---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-035: User-driven column mapping

## Context

Operators run weewx with varying schemas. Stock weewx ships a known set of columns (`outTemp`, `barometer`, etc.); operators add custom columns via their own extensions or sensors. Clear Skies needs each archive column mapped to a canonical SPA variable per [ADR-010](ADR-010-canonical-data-model.md) so the dashboard knows what to render and where.

This ADR is the operator-side complement to [ADR-038](ADR-038-data-provider-module-organization.md): provider plugins translate API responses to canonical fields in code; the operator translates archive columns to canonical fields at setup.

## Decision

At first-run, clearskies-api introspects the weewx archive schema and the configuration UI ([ADR-027](ADR-027-config-and-setup-wizard.md)) walks the operator through a column-mapping flow:

1. **Stock weewx columns auto-map** silently using a built-in lookup table (`outTemp` → `outdoorTemperature`, `barometer` → `barometricPressure`, etc.). Operator can override later.
2. **Non-stock columns are presented to the operator** with a heuristic name-match suggestion (case-insensitive substring match against canonical field names). For each, the operator picks a canonical SPA variable from the catalog, OR `not mapped`.
3. **Mapping persists** in the operator's config file per [ADR-027](ADR-027-config-and-setup-wizard.md). It's config, not code.
4. **Re-mapping** at any time via the configuration UI; takes effect on the next request — no service restart.

**Worked example — AQI ([ADR-013](ADR-013-aqi-handling.md) Path A):** an operator running `weewx-airvisual` has columns `aqi`, `main_pollutant`, `aqi_level`, `aqi_location`. The flow suggests `aqi` → `aqi`, `main_pollutant` → `aqiMainPollutant`, `aqi_level` → `aqiCategory`, `aqi_location` → `aqiLocation`. Operator confirms.

## Options considered

| Option | Verdict |
|---|---|
| A. Schema introspection + auto-map stock + operator maps non-stock (this ADR) | **Selected.** |
| B. Operator manually maps every column from scratch | Rejected — friction for the common case where stock columns auto-map cleanly. |
| C. Only support stock weewx columns; operators rename custom columns to fit | Rejected — defeats accommodation of operators' existing extensions. |

## Consequences

- clearskies-api ships a stock-weewx column-to-canonical-field lookup table as part of [ADR-010](ADR-010-canonical-data-model.md)'s canonical model package.
- Configuration UI gains a column-mapping step at first-run setup and a re-mapping page in ongoing config — owned by [ADR-027](ADR-027-config-and-setup-wizard.md).
- Heuristic suggestions are confirmed by the operator, never auto-applied silently. Operator is final authority.
- Unmapped columns are invisible to the dashboard. Render-time sensor-availability detection (cat 10) handles "mapped but no data" separately.
- Per-provider modules ([ADR-038](ADR-038-data-provider-module-organization.md)) do NOT participate in column mapping — they translate API responses to canonical fields in code, no operator step.
- Future releases that add new canonical fields surface them as unmapped on next config-UI visit; operator maps as needed.

## Out of scope

- Specific configuration-UI layout — owned by [ADR-027](ADR-027-config-and-setup-wizard.md).
- Stock-weewx column lookup table contents — Phase 2, derived from weewx 5.x schema docs.
- Type validation per canonical field (e.g., `aqi` must be numeric) — Phase 2.
- Multi-column → single canonical field (e.g., averaging two temperature sensors) — Phase 6+.
- Mapping migrations when canonical fields rename — Phase 6+.

## References

- Related ADRs: [ADR-010](ADR-010-canonical-data-model.md), [ADR-013](ADR-013-aqi-handling.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-038](ADR-038-data-provider-module-organization.md).
- Walk artifact: cat 10 cross-cutting threads in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
