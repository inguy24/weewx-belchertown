# Solar Radiation Model Replacement — Implementation Plan

**Status:** COMPLETE — All phases done. Phases 0-3 deployed, Phase 1 extension live, Phase 4 docs consolidated, ADR-072 archived, calibration baselines verified (0.85-1.07)  
**Created:** 2026-06-23  
**Origin:** Investigation of poisoned calibration baselines (Kcs values up to 10.29) traced to weewx's Ryan-Stolzenbach maxSolarRad model producing near-zero values at low sun angles while the station's lux sensor reads real diffuse skylight  
**Components:** New weewx extension (`weewx-clearskies-truesun`), API bootstrap rework (`weewx-clearskies-api`), Meta (`weather-belchertown`)

---

## Context

### What prompted this

During verification of the seasonal calibration deployment (Phase 9), the admin page showed 9 of 12 months with drift warnings and Kcs baselines ranging from 0.95 to **2.77** — physically impossible values (Kcs should be ≤ ~1.0). Investigation traced the root cause:

1. **weewx uses the Ryan-Stolzenbach formula** for `maxSolarRad` — a direct-beam-only model that returns near-zero at low solar elevations
2. **The GW1000's lux-derived radiation sensor** reads real diffuse skylight at sunrise/sunset, producing legitimate nonzero values when maxSolarRad is near zero
3. **The bootstrap importer** computes `kcs = radiation / maxSolarRad` with no ceiling, producing Kcs values of 5–10 at 7:00 AM (14:00 UTC)
4. **The 92nd percentile** of these poisoned samples becomes the monthly baseline — garbage in, garbage out

The problem is not limited to calibration. The same faulty maxSolarRad model affects **the entire conditions engine** at sunrise/sunset edges — sky classification, haze detection, Kcs computation. Edge-case workarounds throughout the codebase (`_KC_MAX = 1.2` cap, `_SZA80_MSR_PROXY = 100`, solar elevation > 10° gate) exist because the reference model is broken at low angles.

### What the research proved

Testing with pvlib's Simplified Solis model fed with real atmospheric inputs (precipitable water from station humidity, AOD from CAMS satellite data) showed:

| Time | radiation | weewx maxSR | Solis maxSR | Kcs weewx | Kcs Solis |
|------|-----------|-------------|-------------|-----------|-----------|
| 5:55 AM | 11.6 | 0.4 | 12.0 | **32.1** | **0.97** |
| 6:00 AM | 16.1 | 1.4 | 21.4 | **11.4** | **0.75** |
| 6:30 AM | 55.7 | 41.1 | 97.6 | **1.35** | **0.57** |
| 12:00 PM | 907.3 | 1011.0 | 979.9 | 0.90 | 0.93 |

Solis with real atmosphere produces sane Kcs by **5:55 AM** — 40 minutes earlier than weewx's model. The sunrise/sunset poison zone is eliminated.

### Data sources available

- **CAMS McClear** (via pvlib `get_cams()`): Historical clear-sky GHI with real atmospheric conditions, 2004–present, free, 100 req/day — perfect for bootstrap
- **CAMS Global Forecast** (via `cdsapi`): Hourly AOD at 550nm, 5-day forecast, updated twice daily, free — perfect for real-time extension
- **Station sensors**: Temperature + humidity in every loop packet → precipitable water via `gueymard94_pw()` — no external call needed
- **CAMS ADS API key** (for optional weewx extension only): `d2b90754-d5d6-4f39-9e51-c4b2efe33ffd` (stored in CREDENTIALS.md). Operators register at https://ads.atmosphere.copernicus.eu/
- **SoDa account** (for bootstrap McClear — required): free email registration at https://www.soda-pro.com/. No API key needed — pvlib `get_cams()` uses email auth.

### Design decisions (settled in conversation 2026-06-22/23)

1. **Two-component fix, different priorities.** (a) **Bootstrap fix (REQUIRED):** importer uses CAMS McClear historical clear-sky GHI instead of `compute_max_solar_rad()`. This is the core fix — it eliminates the poisoned calibration data. (b) **weewx extension (OPTIONAL):** replaces real-time `maxSolarRad` at the source using pvlib Simplified Solis + CAMS AOD + station humidity. Improves the entire conditions engine at sunrise/sunset edges but is not required for correct calibration.
2. **Auth model reflects priority split.** Bootstrap requires only a free SoDa email registration (McClear via pvlib's `get_cams()`). The optional weewx extension additionally needs a CAMS ADS API key for real-time AOD forecast.
3. **Extension uses background thread for CAMS fetch.** Per weewx docs: external data sources should use a separate thread + queue to avoid blocking the main loop. AOD fetched once per day; main loop does only pure math with cached values.
4. **XTypes system for the override.** weewx's officially sanctioned extensibility mechanism. Custom XType registered before `StdWXXTypes` takes priority for `maxSolarRad` computation.
5. **McClear for bootstrap.** McClear provides clear-sky GHI directly with real atmospheric conditions baked in. No AOD estimation, no formula — just the answer. One bulk fetch covers the full historical period.
6. **Calibration data must be reset and re-bootstrapped** after the fix. The existing calibration.json is poisoned.
7. **Remove `compute_max_solar_rad()` from the API.** Once the bootstrap switches to McClear, this function has zero callers — the importer was its only consumer. The real-time path reads maxSolarRad from the weewx archive (computed by weewx's StdWXCalculate, or overridden by the optional extension). No API code should be reimplementing solar geometry.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, QC gates
- `rules/coding.md` — coding standards
- `reference/clearskies-dev.md` — repo paths, SSH access, sync, toolchain

**Repos:**
- `weewx-clearskies-extension` — Existing weewx extension (ClearSkiesLoopRelay). Pattern reference for the new extension.
- `weewx-clearskies-api` — API repo. Bootstrap importer + auto_calibration changes.
- `weather-belchertown` — Meta repo. Docs, planning, ADRs.
- NEW: `weewx-clearskies-truesun` — New weewx extension for pvlib-based maxSolarRad.

**Key libraries:**
- `pvlib` (0.15.2) — `clearsky.simplified_solis()`, `atmosphere.gueymard94_pw()`, `atmosphere.angstrom_aod_at_lambda()`, `iotools.get_cams()`
- `cdsapi` (≥0.7.7) — CAMS Atmosphere Data Store API client for AOD forecast retrieval
- `numpy`, `pandas` — pvlib dependencies

**weewx architecture (from docs):**
- Service pipeline: `xtype_services → data_services → process_services → archive_services → ...`
- `StdWXCalculate` (in `process_services`) computes maxSolarRad using R-S with `prefer_hardware` directive
- XTypes registered via `xtype_services` run before `StdWXCalculate`; a value provided by XType is treated as "hardware" and not overwritten
- Extension services bound to `NEW_LOOP_PACKET` and/or `NEW_ARCHIVE_RECORD` can modify records in-flight
- External data: use background threads + queues; don't block the main loop

**Current weewx.conf state:**
- `maxSolarRad = prefer_hardware` in `[StdWXCalculate][[Calculations]]`
- `ClearSkiesLoopRelay` already in `restful_services`
- Station: lat=33.65683, lon=-117.98267, alt=40ft, archive_interval=60s
- Database: MariaDB `weewx.archive`

**maxSolarRad consumers in the API (no field rename needed — we're replacing the VALUE, not the name):**
- `sky_condition.py` — Kcs = GHI / maxSolarRad, ring buffer, detrending
- `sky_tap.py` — reads maxSolarRad from live loop packets
- `importer.py` — bootstrap Kcs computation (this is what we fix)
- `__main__.py` — archive backfill SQL, bootstrap startup
- `auto_calibration.py` — `compute_max_solar_rad()` definition
- `models/responses.py`, `db/reflection.py`, `services/archive.py`, `units/groups.py` — schema/model definitions (unchanged)

---

## 1. Gap Inventory

### A. Bootstrap (poisoned calibration data)

| # | Problem | Status | Fix |
|---|---------|--------|-----|
| A1 | `compute_max_solar_rad()` uses R-S formula → near-zero at low sun angles | Root cause confirmed | Replace with McClear clear-sky GHI in importer |
| A2 | Importer has no Kcs ceiling; R-S denominator produces Kcs 5–10 at sunrise | Confirmed via data | McClear denominators are realistic; also add Kcs ceiling as defense-in-depth |
| A3 | Existing calibration.json has 3,371 samples with poisoned baselines | Confirmed | Reset + re-bootstrap after fix |
| A4 | Importer doesn't pull temp/humidity from archive | Missing data | Expand archive query (needed if we add PW-based fallback) |

### B. Real-time maxSolarRad (conditions engine edge cases)

| # | Problem | Status | Fix |
|---|---------|--------|-----|
| B1 | Archive maxSolarRad from weewx R-S is wrong at sunrise/sunset | Confirmed | weewx extension overwrites with pvlib Solis |
| B2 | sky_condition.py needs `_KC_MAX = 1.2` cap to prevent blowup | Workaround | Extension fixes the denominator; cap stays as defense-in-depth |
| B3 | `_SZA80_MSR_PROXY = 100` threshold is a workaround | Workaround | With correct maxSolarRad, the proxy threshold becomes accurate |
| B4 | haze_condition.py notes "R-S underestimates maxSolarRad by ~20% below 10°" | Known issue | Extension eliminates this underestimate |

### C. Infrastructure

| # | Item | Status | Fix |
|---|------|--------|-----|
| C1 | SoDa account for McClear bootstrap | Not registered | Operator registers free email account at soda-pro.com; email stored in `secrets.env` |
| C2 | CAMS ADS API key (extension only) | Key obtained | Store in weewx.conf `[ClearSkiesTruesun]` section; document operator registration |
| C3 | pvlib not on weewx container | Not installed | `pip install pvlib` in API venv (bootstrap dependency) |
| C4 | pvlib + cdsapi not on weewx host (extension only) | Not installed | Installed with weewx extension |
| C5 | No ADR for solar model change | Missing | Draft ADR documenting the R-S → Solis transition |

---

## 2. Implementation Phases

### PHASE 0 — Validation & ADR

**T0.1 — Validate McClear API access**
- Owner: Coordinator (Opus)
- Test: `pvlib.iotools.get_cams()` for station coordinates, one day in May 2024, verbose mode
- Confirm: data returns, columns include clear-sky GHI, values are sane at sunrise
- Confirm: verbose mode returns AOD/atmospheric parameters (needed to verify what CAMS provides)
- Accept: McClear GHI at 6:00 AM PDT on May 12, 2024 is > 15 W/m² (vs R-S's 1.4)

**T0.2 — Validate CAMS AOD forecast API access**
- Owner: Coordinator (Opus)
- Test: `cdsapi.Client().retrieve()` for `cams-global-atmospheric-composition-forecasts`, AOD at 550nm, single grid point, one day
- Confirm: data returns, AOD550 values are in range 0.02–0.5 for HB area
- Accept: API returns hourly AOD values. Request completes in < 60 seconds.

**T0.3 — Draft ADR for solar radiation model replacement**
- Owner: `clearskies-docs-author` (Sonnet)
- ADR covers: why R-S is inadequate, pvlib Solis as replacement, CAMS data sources, weewx XTypes integration, operator requirements (CAMS key), fallback behavior
- Accept: ADR Proposed. User approves → Accepted.

**QC (Opus):** Review ADR against conversation findings. Verify API tests produce expected results.

### PHASE 1 — weewx Extension (`weewx-clearskies-truesun`)

**T1.1 — Create extension repo and scaffolding**
- Owner: Coordinator (Opus)
- New repo: `weewx-clearskies-truesun` (or subdirectory of `weewx-clearskies-extension` — TBD)
- Structure (following ClearSkiesLoopRelay pattern):
  ```
  weewx-clearskies-truesun/
    install.py
    bin/user/clearskies_truesun.py
    README.md
    LICENSE (GPL v3)
    changelog
  ```
- `install.py`: registers service in `xtype_services`, injects `[ClearSkiesTruesun]` config stanza
- Accept: Extension structure matches weewx packaging conventions

**T1.2 — Implement XType for maxSolarRad**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `bin/user/clearskies_truesun.py`
- XType class `ClearSkiesTruesunXType(weewx.xtypes.XType)`:
  - `get_scalar(obs_type, record, db_manager)`: when `obs_type == 'maxSolarRad'`, compute via `simplified_solis(apparent_elevation, aod700, precipitable_water)`
  - Solar position from record timestamp + station lat/lon (pvlib `solarposition.get_solarposition()`)
  - Precipitable water from `gueymard94_pw(record['outTemp'], record['outHumidity'])` — convert °F to °C if US units
  - AOD700 from cached CAMS value (converted from AOD550 via `angstrom_aod_at_lambda()`)
  - Returns `ValueTuple(ghi, 'watt_per_meter_squared', 'group_radiation')`
  - Raises `weewx.UnknownType` for other obs_types
  - Raises `weewx.CannotCalculate` when inputs missing (no temp, no humidity, no cached AOD)
- Accept: XType returns values. Fallback to `CannotCalculate` lets StdWXCalculate R-S take over when inputs are missing.

**T1.3 — Implement CAMS AOD background fetch thread**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `bin/user/clearskies_truesun.py`
- Service class `ClearSkiesTruesunService(StdService)`:
  - `__init__`: read config from `[ClearSkiesTruesun]` (cams_api_key, latitude, longitude, aod_fetch_interval_hours=12, fallback_aod700=0.06)
  - Write `~/.cdsapirc` from config key if not present
  - Create `ClearSkiesTruesunXType` instance, prepend to `weewx.xtypes.xtypes`
  - Spawn daemon thread for CAMS AOD fetch
  - Thread-safe `_cached_aod550` float, protected by `threading.Lock`
- Background thread:
  - Fetches `cams-global-atmospheric-composition-forecasts` for station coordinates, today's date, AOD550 total column, hourly
  - Parses GRIB/netCDF response → extracts 24 hourly AOD550 values
  - Updates `_cached_aod550` (thread-safe)
  - Sleeps `aod_fetch_interval_hours`, repeats
  - On failure: logs warning, retains previous cached value, retries next interval
- `shutDown()`: signals thread to stop, joins, removes XType from `xtypes` list
- Accept: Service starts, fetches AOD in background, XType computes maxSolarRad. Thread doesn't block main loop.

**T1.4 — weewx.conf configuration**
- Config stanza injected by install.py:
  ```ini
  [ClearSkiesTruesun]
      # CAMS API key (register at https://ads.atmosphere.copernicus.eu/)
      cams_api_key = REPLACE_ME
      # Fallback AOD at 700nm when CAMS is unavailable (0.06 = typical clean coastal)
      fallback_aod700 = 0.06
      # How often to refresh CAMS AOD forecast (hours)
      aod_fetch_interval_hours = 12
  ```
- Extension reads station lat/lon/altitude from weewx.conf `[Station]` section (standard weewx config)
- Accept: Config is documented, has sensible defaults, follows weewx extension conventions

**T1.5 — Extension testing**
- Owner: `clearskies-test-author` (Sonnet)
- Unit tests for: XType returns correct GHI for known inputs, unit conversion (°F→°C), AOD thread-safety, fallback when CAMS unavailable, `CannotCalculate` when temp/humidity missing
- Accept: All tests pass.

**QC (Opus):** Review XType registration order (must be before StdWXXTypes). Verify thread safety. Verify fallback behavior. Test that weewx starts cleanly with extension installed.

### PHASE 2 — Bootstrap Fix (API Repo)

**T2.1 — Add McClear data fetcher to bootstrap**
- Owner: `clearskies-api-dev` (Sonnet)
- New file or addition to `weewx_clearskies_api/bootstrap/`: function to fetch McClear clear-sky GHI for a date range via `pvlib.iotools.get_cams()` 
- Uses SoDa API with operator's email (or CAMS key — verify which auth McClear uses)
- Fetches hourly clear-sky GHI for the full bootstrap period (up to 3 years)
- Returns dict keyed by timestamp → clear-sky GHI value
- Handles rate limiting (100 req/day) by chunking into yearly requests
- Accept: McClear data fetches successfully for 2024-2026 date range

**T2.2 — Rework importer to use McClear GHI instead of compute_max_solar_rad**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/bootstrap/importer.py`
- Changes:
  - Accept McClear GHI dict as new parameter to `run_bootstrap()`
  - For each PM record matched to an archive record: look up McClear clear-sky GHI at the nearest hour
  - Compute `kcs = radiation / mcclear_ghi` (instead of `radiation / compute_max_solar_rad(...)`)
  - Gate: `mcclear_ghi > 50` (replaces `maxSolarRad > 100` — McClear values are more realistic)
  - Defense-in-depth: cap Kcs at 1.5 (cloud enhancement can push to ~1.2-1.3; 1.5 provides margin)
  - Keep the existing `kcs > 0.3` floor gate
- Accept: Importer no longer calls `compute_max_solar_rad()`. Kcs values for May 12, 2024 7:00 AM are < 1.0.

**T2.3 — Wire McClear into bootstrap startup flow**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/__main__.py`
- Changes to `_run_bootstrap()` and `_bootstrap_thread()`:
  - Before the PM record loop: fetch McClear data for the bootstrap date range
  - Pass McClear dict to `run_bootstrap()`
  - McClear fetch requires either SoDa email or CAMS credentials — use CAMS API key from `secrets.env`
- Accept: Bootstrap startup fetches McClear data before matching PM records

**T2.4 — Remove `compute_max_solar_rad()` and Skyfield dependency**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/sse/auto_calibration.py`
- Remove: the `compute_max_solar_rad()` function (lines 713–792), its Skyfield imports, and any helper code only used by it
- Grep confirm: zero callers remain after T2.2 removes the importer's usage
- Remove Skyfield from API dependencies if no other module uses it (check `services/almanac.py` — it likely still uses Skyfield for sun position; if so, Skyfield stays but the R-S function goes)
- Accept: `grep -r "compute_max_solar_rad" repos/weewx-clearskies-api/` returns zero hits outside of test files and changelogs

**T2.5 — Expand archive query to include temp/humidity (future-proofing)**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/bootstrap/importer.py`
- Add `outTemp, outHumidity` to the archive SQL query in `_find_nearest_archive_record()`
- Not used immediately (McClear provides the clear-sky GHI directly), but available for future precipitable water computation if needed as a fallback
- Accept: Archive query returns temp/humidity. No functional change to current flow.

**T2.6 — Update bootstrap tests**
- Owner: `clearskies-test-author` (Sonnet)
- Extend `tests/test_auto_calibration.py` and add McClear-related tests:
  - Importer produces sane Kcs when given McClear GHI values
  - Kcs ceiling (1.5) works
  - McClear lookup by nearest hour works
  - Fallback behavior when McClear data is unavailable for a timestamp
  - `compute_max_solar_rad` tests removed (function deleted in T2.4)
- Accept: All tests pass. Full suite baseline maintained.

**QC (Opus):** Grep for `compute_max_solar_rad` across entire API repo — zero hits (function removed). Verify Kcs ceiling in place. Run test suite.

### PHASE 3 — Calibration Reset & Re-bootstrap

**T3.1 — Reset calibration data on weewx**
- Owner: Coordinator (Opus)
- Call `POST /setup/calibration-reset` via admin UI or curl
- Verify calibration.json is cleared
- Accept: `/setup/calibration-state` shows `overall_state: "no-data"`, `months_calibrated: 0`

**T3.2 — Deploy API with McClear bootstrap fix**
- Owner: Coordinator (Opus)
- Push API repo, pull on weewx, restart service
- Service auto-bootstraps with McClear data
- Accept: Startup logs show McClear fetch, bootstrap proceeds, no Kcs > 1.5 in samples

**T3.3 — Verify new calibration baselines**
- Owner: Coordinator (Opus)
- Query `/setup/calibration-state` — all monthly baselines should be 0.85–1.05
- No drift warnings on admin page
- Accept: All 12 monthly baselines are physically plausible. Zero drift warnings.

**QC (Opus):** Screenshot admin haze calibration page. Compare baselines to previous (poisoned) values. Verify sample counts are reasonable.

### PHASE 4 — Documentation

**T4.1 — Update API-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Add: McClear-based bootstrap, CAMS API key requirement, pvlib dependency
- Update: calibration section to reference McClear instead of compute_max_solar_rad for bootstrap
- Accept: No references to R-S for bootstrap. CAMS key documented.

**T4.2 — Update OPERATIONS-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Add: CAMS API key to `secrets.env` documentation, weewx extension installation instructions
- Accept: Operator can follow docs to install extension and configure CAMS key.

**T4.3 — Update ARCHITECTURE.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Add: weewx-clearskies-truesun extension to component table, pvlib dependency, CAMS data flow
- Accept: Architecture reflects new component.

**T4.4 — Archive ADR**
- Owner: `clearskies-docs-author` (Sonnet)
- Move ADR to `docs/archive/decisions/` after manual consolidation
- Accept: ADR archived, manuals updated.

**QC (Opus):** Doc-code sync audit. All new components documented. No stale R-S references in bootstrap docs.

### PHASE 5 — Deploy Extension & Final Verification

**T5.1 — Install pvlib + cdsapi on weewx container**
- Owner: Coordinator (Opus)
- `pip install pvlib cdsapi` in weewx Python environment
- Accept: `python -c "import pvlib; import cdsapi"` succeeds

**T5.2 — Install weewx-clearskies-truesun extension**
- Owner: Coordinator (Opus)
- `weectl extension install weewx-clearskies-truesun.tar.gz`
- Configure CAMS API key in weewx.conf `[ClearSkiesTruesun]`
- Restart weewx
- Accept: Extension loads, CAMS AOD fetches in background, maxSolarRad values in archive are pvlib-computed

**T5.3 — End-to-end verification**
- Owner: Coordinator (Opus)
- Verify: archive maxSolarRad values at sunrise are realistic (> 10 W/m² at 6:00 AM)
- Verify: sky_condition Kcs stays sane at sunrise/sunset (no values > 1.2)
- Verify: calibration baselines remain plausible after extension is active
- Verify: dashboard solar radiation chart shows maxSolarRad tracking radiation at edges
- Verify: full pytest baseline maintained
- Accept: All checks pass. Admin page shows healthy calibration. No edge-case anomalies.

**Final QC (Opus):** Walk all acceptance criteria. ADR compliance. Doc-code sync. Test suite clean.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 0 | T0.1–T0.2 API validation | Coordinator | Opus | Before Phase 1 |
| 0 | T0.3 ADR | `clearskies-docs-author` | Sonnet | After T0.3 |
| 1 | T1.1 Scaffolding | Coordinator | Opus | After T1.1 |
| 1 | T1.2 XType implementation | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 1 | T1.3 CAMS AOD thread | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 1 | T1.4 Config | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 1 | T1.5 Tests | `clearskies-test-author` | Sonnet | After Phase 1 |
| 2 | T2.1–T2.3 Bootstrap rework | `clearskies-api-dev` | Sonnet | After Phase 2 |
| 2 | T2.4 Remove compute_max_solar_rad | `clearskies-api-dev` | Sonnet | After Phase 2 |
| 2 | T2.5 Archive query expansion | `clearskies-api-dev` | Sonnet | After Phase 2 |
| 2 | T2.6 Tests | `clearskies-test-author` | Sonnet | After Phase 2 |
| 3 | T3.1–T3.3 Reset + deploy + verify | Coordinator | Opus | After Phase 3 |
| 4 | T4.1–T4.4 Docs | `clearskies-docs-author` | Sonnet | After Phase 4 |
| 5 | T5.1–T5.3 Deploy + verify | Coordinator | Opus | After Phase 5 |

**Sequencing:**
- Phase 0 (validation + ADR) → Phase 2 (bootstrap fix — PRIORITY) → Phase 3 (reset + re-bootstrap)
- Phase 1 (weewx extension — OPTIONAL) can run in parallel with Phase 2 or after Phase 3
- Phase 4 (docs) can start after Phase 2 is code-complete
- Phase 5 (deploy extension) depends on Phase 1 + 3
- **Minimum viable fix = Phase 0 + 2 + 3 + 4.** The bootstrap fix alone eliminates the poisoned calibration. Phase 1 and 5 are enhancements.

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- Extension: `python -m py_compile bin/user/clearskies_truesun.py` passes
- API: `ruff check` + full pytest suite, zero introduced failures
- No circular imports, no blocking calls in main loop

### Gate 2 — Feature Correctness
- Phase 1: weewx starts with extension, maxSolarRad values at sunrise are > 10 W/m² at 6 AM
- Phase 2: Bootstrap produces Kcs < 1.5 for all samples. No Kcs > 2.0.
- Phase 3: All 12 monthly baselines in range 0.85–1.05 after re-bootstrap

### Gate 3 — Fallback Behavior
- Extension missing: weewx falls back to R-S (existing behavior, no regression)
- CAMS unavailable: extension uses `fallback_aod700` from config
- Temp/humidity missing in record: XType raises `CannotCalculate`, R-S takes over

### Gate 4 — Thread Safety
- CAMS AOD cache accessed from main thread (read) and background thread (write) with lock
- No deadlocks, no race conditions, no stale reads longer than one fetch interval

---

## 5. Self-Audit

**Risk: McClear API requires registration.** SoDa API uses email-based auth, not API key. Need to verify whether `get_cams()` uses the SoDa email or the CDS API key. If SoDa, operators need a SoDa account in addition to CAMS. Validation in Phase 0 will clarify.

**Risk: CAMS AOD forecast requires GRIB parsing.** The forecast dataset returns GRIB format. `cdsapi` handles download, but parsing may need `cfgrib` or `eccodes`. Need to verify in Phase 0 whether pvlib or a lightweight parser can extract the single-point AOD value without heavy dependencies.

**Risk: pvlib dependency size on weewx.** pvlib + pandas + numpy are significant. weewx runs on embedded systems sometimes. Document minimum requirements. The extension is optional — operators on constrained hardware can skip it and use R-S.

**Risk: McClear 100 req/day limit.** 3 years of hourly data requires multiple requests. Need to chunk by year (3 requests × 365 days = 3 yearly bulk fetches). Verify SoDa returns full-year chunks in single requests.

**Risk: Extension only helps if installed.** Operators who don't install the extension still get R-S maxSolarRad in their archive. The bootstrap fix (McClear) is independent and fixes the calibration regardless. Document both paths clearly.

**Risk: Simplified Solis valid range.** AOD700 capped at 0.45, PW at 0.2–10 cm. Extreme conditions (wildfire AOD > 0.45) would be clamped. Acceptable — clear-sky model is inherently less meaningful during wildfire smoke events.

---

## 6. Key Files

### New repo (`weewx-clearskies-truesun`)
- `install.py` — Extension installer
- `bin/user/clearskies_truesun.py` — XType + Service + CAMS thread

### API repo (`repos/weewx-clearskies-api`)
- `weewx_clearskies_api/bootstrap/importer.py` — Switch from compute_max_solar_rad to McClear GHI
- `weewx_clearskies_api/bootstrap/mcclear_client.py` — New: McClear data fetcher via pvlib
- `weewx_clearskies_api/__main__.py` — Wire McClear into bootstrap startup
- `weewx_clearskies_api/sse/auto_calibration.py` — Remove `compute_max_solar_rad()` (dead code after McClear switch)
- `tests/test_auto_calibration.py` — New McClear-based bootstrap tests

### Meta repo (root)
- `docs/planning/SOLAR-MODEL-REPLACEMENT-PLAN.md` — This plan
- `docs/archive/decisions/ADR-XXX-solar-radiation-model.md` — New ADR
- `docs/API-MANUAL.md` — Bootstrap section update
- `docs/OPERATIONS-MANUAL.md` — Extension install + CAMS key docs
- `docs/ARCHITECTURE.md` — New component

### Spreadsheets (research artifacts at `c:\tmp\`)
- `kcs-analysis-2026-06-22.csv` — Raw archive data with Kcs
- `kcs-pvlib-comparison-2026-06-22.csv` — weewx vs Ineichen comparison
- `kcs-solis-comparison-2026-06-22.csv` — weewx vs Solis at various atmosphere settings
