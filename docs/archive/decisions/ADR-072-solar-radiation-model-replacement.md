---
status: Archived — consolidated into API-MANUAL.md + OPERATIONS-MANUAL.md + ARCHITECTURE.md
date: 2026-06-23
deciders: shane
supersedes:
superseded-by:
---

# ADR-072: Solar Radiation Model Replacement (R-S → McClear / Solis)

## Context

The seasonal calibration system (ADR-068) computes a clearness index Kcs = radiation / maxSolarRad as the basis for haze detection baselines. Investigation during Phase 9 verification revealed that **9 of 12 months had drift warnings** with Kcs baselines up to 2.77 — physically impossible values (Kcs should be ≤ ~1.0).

Root cause: weewx's `StdWXCalculate` computes `maxSolarRad` using the **Ryan-Stolzenbach (R-S) formula**, a direct-beam-only model that returns near-zero values at low solar elevations. The station's GW1000 lux-derived sensor reads real diffuse skylight at sunrise/sunset, producing legitimate nonzero radiation when maxSolarRad approaches zero. The bootstrap importer divides by near-zero → Kcs values of 5–10 at sunrise → the 92nd percentile of these poisoned samples becomes the monthly baseline.

The problem extends beyond calibration. The entire conditions engine (sky classification, haze detection, Kcs computation) is affected at sunrise/sunset edges. Existing workarounds (`_KC_MAX = 1.2` cap, `_SZA80_MSR_PROXY = 100`, solar elevation > 10° gate) exist because the reference model is broken at low angles.

**Validated finding (2026-06-22):** pvlib's Simplified Solis model with real atmospheric inputs eliminates the sunrise/sunset poison zone. At 6:00 AM PDT on May 12, 2024: R-S gives GHI = 1.4 W/m² (Kcs = 11.4); McClear gives GHI = 65.4 W/m² (Kcs ≈ 0.25); Solis with typical coastal AOD gives GHI ≈ 18.6 W/m² (Kcs ≈ 0.87). All three Clear Skies alternatives produce physically plausible Kcs by 6:00 AM — 40 minutes earlier than R-S.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| A. Keep R-S, add more workarounds | No dependency changes | Treats symptoms, not cause. Edge workarounds grow unboundedly. Calibration stays poisoned. |
| B. Replace R-S with Ineichen (pvlib) | Better at low angles | Still a formula-based model. Needs turbidity inputs we don't have locally. |
| C. Replace R-S with McClear for bootstrap, Simplified Solis for real-time | McClear uses satellite-measured atmosphere (most accurate for historical). Solis computes from station sensors (no network call in main loop). | Adds pvlib dependency. McClear needs SoDa account (free). Real-time extension needs CAMS API key (free). |
| D. Replace R-S with McClear for everything | Maximum accuracy | McClear is a web API — can't call it from the weewx main loop (60s archive cycle, latency, offline risk). |

## Decision

**Option C.** Two-component fix:

1. **Bootstrap (required):** The importer uses CAMS McClear historical clear-sky GHI (via `pvlib.iotools.get_cams()`) instead of `compute_max_solar_rad()`. McClear provides the ground-truth clear-sky GHI with real atmospheric conditions baked in — no AOD estimation, no formula. One bulk fetch per year covers the full bootstrap period.

2. **Real-time extension (optional):** A new weewx extension (`weewx-clearskies-truesun`) overrides `maxSolarRad` at the source using pvlib's Simplified Solis model + CAMS AOD forecast + station humidity-derived precipitable water. Registered as an XType before `StdWXXTypes`, so the overridden value flows to all consumers (archive, conditions engine, calibration). CAMS AOD fetched once daily in a background thread; main loop does only pure math with cached values.

**Key design choices:**
- `compute_max_solar_rad()` in the API is deleted after the McClear switch — zero callers remain.
- McClear auth: SoDa email registration (free, at soda-pro.com). Bootstrap passes operator's registered email.
- CAMS AOD auth: API key from ads.atmosphere.copernicus.eu (free registration). Only needed for the optional extension.
- Fallback chain: extension unavailable → weewx falls back to R-S. CAMS unavailable → extension uses `fallback_aod700` config value. Temp/humidity missing → extension raises `CannotCalculate`, R-S takes over.
- Calibration data must be reset and re-bootstrapped after the fix. Existing calibration.json is poisoned.

## Consequences

- **pvlib becomes a bootstrap dependency** of weewx-clearskies-api. It pulls in numpy, pandas, scipy — significant packages, but they run only on the weewx host (not the dashboard).
- **SoDa account required for bootstrap.** Operators must register a free email account. The email is stored in `secrets.env`.
- **CAMS API key required only for the optional extension.** Operators who skip the extension get R-S maxSolarRad in the archive but correct McClear-based calibration.
- **compute_max_solar_rad() removed from API.** Skyfield remains for almanac (sun/moon position) but R-S formula code is deleted.
- **Calibration reset required after deploy.** Existing poisoned baselines are cleared; re-bootstrap produces correct values.
- **Edge-case workarounds in conditions engine become less critical** but stay as defense-in-depth: `_KC_MAX = 1.2`, the SZA 80° proxy threshold, and solar elevation gates all remain. With correct maxSolarRad they simply don't fire as often.

## Acceptance criteria

- [ ] McClear data fetches successfully for station coordinates over a 3-year range via `pvlib.iotools.get_cams()`
- [ ] Bootstrap produces Kcs < 1.5 for all samples. No Kcs > 2.0 in the calibration dataset.
- [ ] All 12 monthly calibration baselines are in range 0.85–1.05 after re-bootstrap
- [ ] `grep -r "compute_max_solar_rad" repos/weewx-clearskies-api/` returns zero hits outside test files and changelogs
- [ ] API test suite (pytest) passes with zero introduced failures
- [ ] (Extension only) weewx starts cleanly with extension installed; maxSolarRad at sunrise > 10 W/m² at 6:00 AM
- [ ] (Extension only) CAMS AOD fetches in background without blocking weewx main loop

## Implementation guidance

**Bootstrap (API repo — `weewx-clearskies-api`):**
- New module `weewx_clearskies_api/bootstrap/mcclear_client.py`: fetches McClear clear-sky GHI via `pvlib.iotools.get_cams(email, lat, lon, start, end, identifier='mcclear')`. Chunks by year to stay within 100 req/day limit. Returns dict keyed by timestamp → `ghi_clear` value.
- `bootstrap/importer.py`: accepts McClear GHI dict. Kcs = radiation / mcclear_ghi. Gate: `mcclear_ghi > 50`. Ceiling: `kcs <= 1.5`. Floor: `kcs >= 0.3`.
- `__main__.py`: fetches McClear data before the PM record loop, passes to `run_bootstrap()`.
- `sse/auto_calibration.py`: delete `compute_max_solar_rad()` function and its Skyfield R-S imports.
- Add `pvlib` to API dependencies.
- McClear `ghi_clear` column is the atmosphere-adjusted clear-sky GHI (not `ghi_extra` which is extraterrestrial).
- SoDa email stored in `secrets.env` as `WEEWX_CLEARSKIES_SODA_EMAIL`.

**Extension (new repo — `weewx-clearskies-truesun`):**
- XType class overrides `maxSolarRad` via `simplified_solis(apparent_elevation, aod700, precipitable_water)`.
- Service class spawns daemon thread for daily CAMS AOD fetch via `cdsapi`.
- AOD at 550nm converted to 700nm via `pvlib.atmosphere.angstrom_aod_at_lambda()`.
- Precipitable water from `pvlib.atmosphere.gueymard94_pw(outTemp_celsius, outHumidity)`.
- Config in `[ClearSkiesTruesun]` stanza: `cams_api_key`, `fallback_aod700` (default 0.06), `aod_fetch_interval_hours` (default 12).
- CAMS response is NetCDF, parseable with h5py (already a pvlib dependency). No cfgrib/eccodes needed.

**Out of scope:** Changes to sky_condition.py edge-case workarounds (they stay as defense-in-depth). Changes to the dashboard solar radiation chart. PVGIS as a McClear alternative (data ends 2023, insufficient for recent bootstrap).

## References

- Related ADRs: ADR-068 (auto-calibration baseline), ADR-067 (haze detection architecture), ADR-044 (sky condition classification)
- Research: `docs/planning/solar-model-research/` (pvlib comparison scripts and CSVs from 2026-06-22)
- Plan: `docs/planning/SOLAR-MODEL-REPLACEMENT-PLAN.md`
- External: pvlib Simplified Solis — `pvlib.clearsky.simplified_solis()` docs; CAMS McClear — soda-pro.com/web-services/radiation/cams-mcclear; CAMS ADS — ads.atmosphere.copernicus.eu
