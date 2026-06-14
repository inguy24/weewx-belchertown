---
status: Accepted
date: 2026-06-13
deciders: shane
amends: ADR-013
---

# ADR-059: Multi-jurisdiction AQI — provider-native scales, pass-through architecture

## Context

ADR-013 locked AQI handling to the EPA (US) scale. The `aqiScale` field discriminates between `"epa"` and `"owm"`, and `aqiCategory` is always null from providers. NO and NH3 pollutants are explicitly dropped during canonical translation because they have "no EPA AQI band."

This is wrong on two counts:
1. **Dropping data.** NO and NH3 are valid pollutant measurements returned by providers. Other jurisdictions band them (India NAQI bands NH3). Dropping them at ingestion means they're gone for all consumers.
2. **EPA-only assumption.** Operators outside the US see AQI values on a scale that doesn't match their jurisdiction. An Indian operator using Aeris gets EPA AQI by default — not the NAQI their country uses.

Phase 0 research (T0.4, corrected) documented each provider's native scale support:
- **Aeris:** 8 regional filters (`airnow`, `china`, `india`, `eaqi`, `caqi`, `uk`, `de`, `cai`). Does NOT auto-detect — defaults to `airnow`. Must be configured explicitly. AQHI returned in `health` object on every response. Response shape identical across filters; only derived values (aqi, category, color, method) change.
- **IQAir:** Only `aqius` (US EPA) and `aqicn` (China MEP). No other scales. Does not vary by location.
- **OpenMeteo:** `us_aqi` and `european_aqi`, both computed server-side and available globally. No other indices.
- **OWM:** Own 1-5 ordinal scale only. Regional scales published as documentation-only reference tables, not returned in the API. Returns NO (`no`) and NH3 (`nh3`) globally — currently dropped.

Full provider documentation: `docs/reference/api-docs/{aeris,iqair,openmeteo,openweathermap}.md`.

## Options considered

| Option | Verdict |
|---|---|
| A. Pass through provider-native scales; provider-specific configuration | **Selected.** Providers already compute regional AQI — we don't duplicate that. |
| B. Build breakpoint tables and compute AQI ourselves from concentrations | Rejected — we are a dashboard, not an AQI computation service. Providers do this already. |
| C. Add a global "jurisdiction" setting that overrides all providers | Rejected — each provider supports different scales. Configuration must be per-provider. |

## Decision

Providers compute AQI natively. We pass through what they return. No breakpoint tables, no AQI computation engine.

**Schema changes (amends ADR-013):**
- Add `pollutantNO: float | None` and `pollutantNH3: float | None` to `AQIReading`. Stop dropping pollutant data.
- `aqiScale` carries the provider's actual scale identifier (e.g., `"airnow"`, `"india"`, `"eaqi"`, `"epa"`, `"mep"`, `"owm"`), not a hardcoded value.
- `aqiCategory` passes through from the provider instead of being null. Each provider returns category names appropriate to its scale.

**Provider-specific regional configuration:**
- **Aeris:** `aqi_filter` setting (one of `airnow|china|india|eaqi|caqi|uk|de|cai`). Passed as the `filter=` parameter on API calls. Defaults to `airnow`. Configured in wizard step 6 when Aeris is selected as AQI provider, auto-suggested by station lat/lon → country.
- **OpenMeteo:** `aqi_index` setting (one of `us_aqi|european_aqi`). Determines which variable to request. Default `us_aqi`.
- **IQAir:** `aqi_scale` setting (one of `us|cn`). Determines whether to read `aqius` or `aqicn`. Default `us`.
- **OWM:** No regional configuration. Always returns OWM 1-5 ordinal.

**Dashboard rendering:**
- Render per `aqiScale`. Category names and colors come from the provider's response.
- All available pollutants always shown. The scale governs which are "primary" (part of the AQI calculation) vs "supplementary."
- Different scales render differently: EPA 0-500, CAQI 0-100+, UK DAQI 1-10, OWM 1-5, qualitative scales (EAQI, German LQI).

## Consequences

- **Amends ADR-013:** `aqiScale` is no longer limited to `"epa"` / `"owm"`. `aqiCategory` is no longer always null. NO and NH3 are no longer dropped. The provider module contract adds regional configuration as a provider-specific setting.
- **No breakpoint tables in the codebase.** The EPA breakpoint table in `_units.py` (used for computing EPA AQI from OWM concentrations) remains — OWM doesn't return EPA AQI natively, so that computation stays. No new breakpoint tables are added.
- **Aeris becomes the most versatile AQI provider** for multi-jurisdiction operators, covering 8 regional scales plus global AQHI.
- **Wizard step 6 gains provider-specific AQI config:** a regional filter dropdown when Aeris is selected, a scale toggle for OpenMeteo and IQAir. Auto-suggested by station location.
- **Provider capability declarations updated:** each AQI provider's `CAPABILITY` documents which scales it supports.

## Acceptance criteria

- [ ] `AQIReading` has 8 pollutant fields (PM2.5, PM10, O3, NO2, SO2, CO, NO, NH3)
- [ ] OWM provider passes through `no` and `nh3` instead of dropping them
- [ ] `aqiScale` reflects the provider's actual scale (not hardcoded `"epa"`)
- [ ] `aqiCategory` is non-null from all providers
- [ ] Aeris provider passes the configured `filter` parameter; changing filter changes the response
- [ ] Wizard step 6 shows regional config when an AQI provider is selected
- [ ] Dashboard AQI card renders correctly for EPA, European, OWM, and Indian scales
- [ ] No new breakpoint computation code added (existing OWM→EPA computation stays)

## Implementation guidance

- Update each provider's `_wire_to_canonical()` to pass through NO/NH3 and the provider's native scale/category
- Aeris: add `aqi_filter` to provider settings, pass as `filter=` query param
- OpenMeteo: add `aqi_index` to provider settings, request the configured variable name
- IQAir: add `aqi_scale` to provider settings, read `aqius` or `aqicn` accordingly
- OWM: map `components.no` → `pollutantNO`, `components.nh3` → `pollutantNH3`; stop dropping them
- Dashboard: AQI card reads `aqiScale` and renders category names/colors accordingly. Aeris returns `color` hex per category; other providers need a scale→color lookup in the dashboard.
- Wizard: inline dropdown on step 6's AQI provider selection. Aeris shows 8 filter options; OpenMeteo shows US/European toggle; IQAir shows US/China toggle.

## Out of scope

- Computing AQI indices from raw concentrations (except the existing OWM→EPA path)
- Adding new AQI providers (e.g., Google Air Quality API with 70+ scales)
- AQHI as a standalone index (Aeris returns it in the `health` object — surfacing it is a dashboard concern, not an API schema change)

## References

- Amends: [ADR-013](ADR-013-aqi-handling.md) (AQI handling)
- Related: [ADR-038](ADR-038-data-provider-module-organization.md) (provider module organization)
- Provider docs: [aeris.md](../reference/api-docs/aeris.md), [iqair.md](../reference/api-docs/iqair.md), [openmeteo.md](../reference/api-docs/openmeteo.md), [openweathermap.md](../reference/api-docs/openweathermap.md)
- Backlog: FIX-003, FIX-004
