# Aeris Xcast Forecast Model Selection — Execution Plan

**Status:** COMPLETE — All phases executed, code deployed, ADR-063 consolidated into PROVIDER-MANUAL.md. Archived 2026-06-27.
**Created:** 2026-06-20
**Components:** API (`weewx-clearskies-api`), Config Wizard (`weewx-clearskies-stack`)

---

## Context

XWeather (Vaisala) offers a second forecast endpoint — `/xcast/forecasts` — alongside the standard `/forecasts` endpoint that Clear Skies currently uses. Xcast uses machine learning to blend Vaisala's proprietary sensor network, global weather models, satellite data, and connected car data to produce ML-enhanced forecasts for temperature and wind speed. All other fields use the standard XWeather forecast blend automatically.

The operator confirmed that `/xcast/forecasts` is available within the standard PWS contributor subscription tier (no add-on required).

**Design decision:** Rather than auto-probing or building fallback logic, the wizard presents operators who choose Aeris with an explicit choice between "Standard" and "Xcast (ML-enhanced)" forecast models. This keeps the operator in control. If XWeather changes pricing or the operator's tier doesn't support xcast, they simply select the standard model — no fallback machinery needed.

---

## Research Findings (2026-06-20)

### XWeather API Endpoint Inventory (verified from docs)

The XWeather Weather API lists 50+ endpoints at `https://www.xweather.com/docs/weather-api/endpoints`. The three relevant to this work:

| Endpoint | URL | Purpose |
|----------|-----|---------|
| `/forecasts` | `https://data.api.xweather.com/forecasts/{location}` | Standard forecasts — up to 15 days, hourly/daynight/custom intervals. Currently used by Clear Skies. |
| `/xcast/forecasts` | `https://data.api.xweather.com/xcast/forecasts/{location}` | ML-enhanced forecasts — same structure as `/forecasts` plus confidence limits for temp and wind. |
| `/conditions` | `https://data.api.xweather.com/conditions/{location}` | Interpolated current/forecast/historical conditions. Separate product, NOT the target of this migration. |

### Xcast Technology

- **What it is:** "Xcast" is Vaisala's ML-based weather prediction technology
- **Data sources:** Proprietary Xcast wireless sensors (AtmoCast, GroundCast, TempCast — Vaisala hardware), global weather models, satellite measurements, connected car data
- **NOT PWS data:** The PWS Contributor program is a separate thing — operators share PWS data on PWSWeather.com in exchange for free API access. There is no evidence that PWS contributor data feeds into xcast forecasts.
- **Accuracy improvement:** Documented up to 78% improvement for temp/wind where Xcast sensors are deployed
- **Enhanced fields:** Currently temperature and wind speed ONLY — "All other attributes are utilizing the standard Xweather forecast blend"

### Live API Verification (2026-06-20)

Both endpoints tested with operator's PWS contributor credentials against Huntington Beach, CA (33.6568, -117.9827):

| Aspect | `/forecasts` | `/xcast/forecasts` |
|--------|-------------|-------------------|
| HTTP status | 200 OK | 200 OK |
| Envelope | `{success: true, error: null, response: [...]}` | Identical |
| Period field names | tempC, tempF, windSpeedKPH, etc. | Identical set + `tempConfidenceLimit`, `windConfidenceLimit` |
| Sample values (same hour) | tempC: 19.8, windSpeedMPH: 13 | tempC: 20.36, windSpeedMPH: 13 |
| Confidence limits | Not present | Present but `null` (no Xcast sensors near this location) |
| Location snapping | 33.657, -117.983 | 33.69125, -118.00965 (slightly different grid) |
| Profile (tz, elev) | Identical | Identical |

**Conclusion:** Wire-compatible for hourly (`filter=1hr`). Existing `_AerisHourlyPeriod` Pydantic model (with `extra="ignore"`) parses xcast responses without modification. ML enhancement is active even without local sensors (values differ). Confidence limits are null where no sensors are deployed.

**Daynight limitation (verified 2026-06-20):** `/xcast/forecasts?filter=daynight` ignores the filter and returns hourly periods (`interval: "1hr"`) instead of day/night summaries. Standard `/forecasts?filter=daynight` correctly returns `interval: "daynight"` with proper paired periods. Implementation: xcast path used for hourly call only; daynight call always uses standard `/forecasts`.

### Operator Corrections to Initial Assumptions

| Initial assumption | Correction |
|-------------------|------------|
| Endpoint called "xforecast" | Actually `/xcast/forecasts` |
| Uses PWS station data for hyperlocal | Uses Vaisala proprietary sensors (AtmoCast), not general PWS data |
| Need fallback for tier access | PWS contributor tier includes xcast; operator chooses model in wizard instead of auto-detection |

### Current Aeris Provider Implementation

**File:** `repos/weewx-clearskies-api/weewx_clearskies_api/providers/forecast/aeris.py` (~1340 lines)

**Constants (lines 104-114):**
```
AERIS_BASE_URL = "https://data.api.xweather.com"
AERIS_FORECASTS_PATH = "/forecasts"
```

**Two outbound calls per cache miss:**
1. `_fetch_hourly()` (~line 888) → `GET /forecasts/{lat},{lon}?filter=1hr&limit=240`
2. `_fetch_daynight()` (~line 924) → `GET /forecasts/{lat},{lon}?filter=daynight&limit=16`

**Optional third call:** `_fetch_convective_outlook()` (~line 974) → `GET /convective/outlook/{lat},{lon}` (US only, non-fatal)

**Wire-shape Pydantic models:**
- `_AerisHourlyPeriod` (~line 237): Per-hour forecast fields
- `_AerisDayNightPeriod` (~line 278): Per-day/night forecast fields
- `_AerisEnvelope` (~line 357): `{success, error, response}` envelope

**Canonical output:** `ForecastBundle` (in `models/responses.py` ~line 966) containing `HourlyForecastPoint`, `DailyForecastPoint`, `ForecastDiscussion`.

**Wiring pattern:**
- `__main__.py` calls `wire_forecast_settings(settings)` at startup
- `wire_forecast_settings()` in `endpoints/forecast.py` (~line 243) extracts credentials from `settings.forecast` and calls `wire_aeris_credentials()`
- The endpoint dispatch branch (~line 380-393) calls `aeris.fetch(lat, lon, target_unit, client_id, client_secret)`
- `fetch()` (~line 1146) checks cache → on miss calls `_fetch_hourly()` + `_fetch_daynight()` → normalizes → caches → returns `ForecastBundle`

**Cache:** SHA-256 key of `(provider_id, endpoint="forecast_bundle", {lat4, lon4, target_unit})`. TTL 1800s (30 min).

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — security, testing, manual compliance
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/manuals/PROVIDER-MANUAL.md` — §1 module contract, §3 caching, §4 forecast providers, §10 error taxonomy

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-api` — Aeris forecast provider module. Branch: `main`. Lint: `ruff check`, `mypy`.
- `weewx-clearskies-stack` — Config wizard (Jinja2 + HTMX + Pico CSS). Branch: `main`. No build step.

**Deploy:**
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (takes ~2 min to warm cache)
- Wizard: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`

**Key files:**
- `repos/weewx-clearskies-api/weewx_clearskies_api/providers/forecast/aeris.py` — the module being modified
- `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/forecast.py` — endpoint handler, `wire_forecast_settings()`
- `repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py` — `ForecastSettings` class
- `repos/weewx-clearskies-api/tests/providers/forecast/test_aeris.py` — unit tests
- `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py` — wizard routes
- `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/state.py` — WizardState
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/` — wizard step templates

**ADR:** New ADR-063 (next available after ADR-062).

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** QC after EVERY phase — not batched at the end.

---

## 1. Gap Inventory

### A. API Provider Module Changes

| # | Item | Status | Change |
|---|------|--------|--------|
| A1 | Xcast path constant | TODO | Add `AERIS_XCAST_FORECASTS_PATH = "/xcast/forecasts"` alongside existing `AERIS_FORECASTS_PATH` |
| A2 | Model selection in fetch() | TODO | `fetch()` accepts `forecast_model: str` ("standard" or "xcast"). Uses the corresponding path constant for both `_fetch_hourly()` and `_fetch_daynight()`. |
| A3 | Confidence-limit Pydantic fields | TODO | Add optional `tempConfidenceLimit` and `windConfidenceLimit` (dict or None) to `_AerisHourlyPeriod` and `_AerisDayNightPeriod` |
| A4 | Confidence-limit pass-through | TODO | Write confidence limits to the canonical point's `extras` dict (NOT new canonical fields) |
| A5 | Cache key includes model | TODO | Include `"forecast_model": "xcast"` or `"standard"` in cache key so switching models doesn't serve stale data |
| A6 | Config key + wiring | TODO | `aeris_forecast_model` in `api.conf [forecast]` (default `"xcast"`). Wired through `wire_forecast_settings()` to `aeris.fetch()`. |

### B. Wizard: Model Selection UI

| # | Item | Status | Change |
|---|------|--------|--------|
| B1 | WizardState field | TODO | Add `aeris_forecast_model: str = "xcast"` to WizardState |
| B2 | Provider step UI | TODO | When Aeris is selected as forecast provider, show a radio/select: "Standard" vs "Xcast (ML-enhanced)" with brief description of what xcast provides. Default: Xcast. |
| B3 | Key test validates chosen model | TODO | When operator tests their Aeris key, test against the selected model's endpoint (not just `/forecasts`). If xcast is selected and the test fails with 401/403, show a clear message suggesting they switch to Standard. |
| B4 | Persist + apply | TODO | Write `aeris_forecast_model` to `api.conf [forecast]` via the apply payload. Pre-fill on wizard re-run. Show on review step. |

### C. Testing + Fixtures

| # | Item | Status | Change |
|---|------|--------|--------|
| C1 | Xcast fixture | TODO | Save the live xcast response captured in T0.2 as `tests/fixtures/providers/aeris/xcast_forecasts_hourly.json` |
| C2 | Unit tests: model selection | TODO | Test that `fetch()` uses correct path for each model value. Test that unknown model raises error. |
| C3 | Unit tests: confidence limits | TODO | Test Pydantic parsing with/without confidence fields. Test extras pass-through. |
| C4 | Unit tests: cache key | TODO | Test that different model values produce different cache keys. |

### D. Documentation

| # | Item | Status | Change |
|---|------|--------|--------|
| D1 | ADR-063 | TODO | Document the xcast model-selection decision |
| D2 | PROVIDER-MANUAL.md §4 | TODO | Update Aeris entry to note model selection |
| D3 | api.conf.example | TODO | Add `aeris_forecast_model = xcast` under `[forecast]` |

### E. Out of Scope (Explicit Deferrals)

| Feature | Why Deferred |
|---------|-------------|
| Dashboard rendering of confidence intervals | `extras` dict already passes through; rendering is a separate UI task |
| 10-minute resolution (`filter=10min`) | Changes data volume significantly; would need its own ADR |
| Auto-probe/fallback logic | Operator makes explicit choice in wizard; no auto-detection needed |

---

## 2. Implementation Phases

### PHASE 0 — ADR + Fixture Capture

**T0.1 — Draft ADR-063: Aeris Forecast Model Selection**
- Owner: Coordinator (Opus)
- File: New `docs/decisions/ADR-063-aeris-xcast-model-selection.md`
- Content:
  - Context: XWeather offers `/xcast/forecasts` with ML-enhanced temp/wind alongside standard `/forecasts`. Both are wire-compatible. PWS contributor tier includes xcast.
  - Options: (A) Always use standard — ignores available improvement. (B) Always use xcast — no operator control. (C) Operator selects model in wizard [recommended] — operator controls which endpoint, can switch if pricing changes.
  - Decision: Option C. Wizard presents the choice when Aeris is selected. Default: xcast. Config key: `aeris_forecast_model` in `api.conf [forecast]`.
  - Consequences: One new config key. One new wizard UI element (Aeris-specific). No fallback logic. Operator responsible for choosing a model their key supports.
- Accept: ADR follows template. Status = Proposed. User approves before Phase 1.

**T0.2 — Save live xcast fixture**
- Owner: Coordinator (Opus)
- Do: Capture `/xcast/forecasts?filter=1hr&limit=24` as test fixture. Daynight fixture NOT needed — live testing (2026-06-20) confirmed xcast ignores `filter=daynight` and returns hourly periods regardless. The module uses xcast for hourly only; daynight always uses standard `/forecasts`.
- Files: New `tests/fixtures/providers/aeris/xcast_forecasts_hourly.json`
- Accept: Fixture is valid JSON. Provenance documented in `fixtures.md` (live capture, date, location).

**QC (Opus) — after Phase 0:** ADR content review. Fixtures captured. User approves ADR.

---

### PHASE 1 — API Provider Module Changes

**T1.1 — Add xcast path constant and model selection to fetch()**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `aeris.py` (~line 108): Add `AERIS_XCAST_FORECASTS_PATH = "/xcast/forecasts"`.
  - `aeris.py` `_fetch_hourly()` (~line 888): Add `forecasts_path: str = AERIS_FORECASTS_PATH` parameter. Replace the hardcoded `AERIS_FORECASTS_PATH` in the URL construction with this parameter.
  - `aeris.py` `_fetch_daynight()` (~line 924): **NOT modified.** Xcast ignores `filter=daynight` (returns hourly periods instead). Daynight always uses standard `/forecasts`.
  - `aeris.py` `fetch()` (~line 1146): Add `forecast_model: str = "xcast"` parameter. Resolve to path:
    ```python
    if forecast_model == "xcast":
        path = AERIS_XCAST_FORECASTS_PATH
    else:
        path = AERIS_FORECASTS_PATH
    ```
    Pass `path` to `_fetch_hourly()` only. `_fetch_daynight()` always uses standard path. Log at INFO which model/path is being used on each cache miss.
- Accept: `fetch(forecast_model="xcast")` calls `/xcast/forecasts` for hourly and `/forecasts` for daynight. `fetch(forecast_model="standard")` calls `/forecasts` for both. Default is `"xcast"`. `ruff check` + `mypy` pass.

**T1.2 — Add confidence-limit fields to Pydantic models + extras pass-through**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `aeris.py`
- Do:
  - Add to `_AerisHourlyPeriod` (~line 237) only (NOT `_AerisDayNightPeriod` — xcast only applies to hourly):
    ```python
    tempConfidenceLimit: dict[str, float] | None = None
    windConfidenceLimit: dict[str, float] | None = None
    ```
  - In `_hourly_period_to_point()` (~line 575): If `period.tempConfidenceLimit` or `period.windConfidenceLimit` is not None, add to the point's `extras` dict.
- Accept: Existing standard fixtures still validate (fields default None). Xcast fixtures validate with confidence fields present. Confidence limits appear in hourly `extras` when non-null.

**T1.3 — Update cache key to include forecast model**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `aeris.py` `_build_cache_key()` (~line 463)
- Do: Add `forecast_model: str = "standard"` parameter. Include `"forecast_model": forecast_model` in the JSON payload dict. Update call site in `fetch()` to pass the active model.
- Accept: Different cache keys for xcast vs standard. Existing tests pass with the defaulted parameter.

**T1.4 — Add config key and wire through endpoint handler**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `config/settings.py` (`ForecastSettings`): Add `aeris_forecast_model: str` read from `[forecast]` section, default `"xcast"`. Validate value is `"standard"` or `"xcast"`.
  - `endpoints/forecast.py`: Add module-level `_aeris_forecast_model: str = "xcast"`. Add `wire_aeris_forecast_model(model: str)` setter. Call it from `wire_forecast_settings()` (~line 243). Pass `forecast_model=_aeris_forecast_model` to `aeris.fetch()` in the Aeris dispatch branch (~line 387).
- Accept: Setting `aeris_forecast_model = standard` in `api.conf [forecast]` causes the API to call `/forecasts`. Setting `xcast` (or omitting — default) calls `/xcast/forecasts`. `ruff check` + `mypy` pass.

**T1.5 — Update module docstring and CAPABILITY.operator_notes**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `aeris.py`
- Do: Update module docstring to describe the model selection (what xcast is, config key, default). Amend `CAPABILITY.operator_notes` to mention `aeris_forecast_model` config key and the two model options.
- Accept: Documentation accurate.

**QC (Opus) — after Phase 1:** Code review. Verify: (1) existing fixtures still parse, (2) confidence limits only in `extras`, (3) correct path used per model, (4) cache key differentiates models, (5) config wiring works end-to-end, (6) `ruff check` + `mypy` pass.

---

### PHASE 2 — Wizard: Model Selection UI

**T2.1 — Add forecast model field to WizardState**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/state.py`
- Do: Add `aeris_forecast_model: str = "xcast"` to WizardState.
- Accept: State serializes/deserializes with the new field. Default is `"xcast"`.

**T2.2 — Add model selection UI to provider step**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/` (the provider/forecast step template)
- Do: When the operator selects Aeris as their forecast provider, render a radio group or select:
  - **Xcast (ML-enhanced)** (default, selected) — "Uses machine learning to enhance temperature and wind speed predictions. Recommended for most operators."
  - **Standard** — "Traditional XWeather forecast model."
  - Only visible when Aeris is the selected forecast provider. Hidden for NWS, Open-Meteo, OWM, Wunderground.
  - Both options have `aria-describedby` with their descriptions (WCAG §5.2).
- Accept: Radio renders when Aeris selected. Hidden for other providers. Default is xcast. Labels and descriptions are clear.

**T2.3 — Wire model through POST handler, key test, apply, and review**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `wizard/routes.py`, review step template
- Do:
  - POST handler: Save selected `aeris_forecast_model` to WizardState.
  - Key test: When testing Aeris credentials, use the selected model's endpoint for the test call. If xcast is selected, test against `/xcast/forecasts`. If the test fails with 401/403, show: "Your API key does not support Xcast forecasts. Try selecting the Standard model."
  - Apply: Include `aeris_forecast_model` in the API payload (written to `api.conf [forecast]`).
  - Review step: Show "Aeris Forecast Model: Xcast (ML-enhanced)" or "Standard".
  - Re-run pre-fill: Read `aeris_forecast_model` from existing config on wizard re-run.
- Accept: Full round-trip: select model → test key → review → apply → re-run → pre-fill correct value. Key test uses the selected model's endpoint.

**QC (Opus) — after Phase 2:** Walk wizard on weather-dev: select Aeris → see model radio → select xcast → test key → verify test hits `/xcast/forecasts` → review shows "Xcast" → apply → re-run → verify pre-fill. Also verify: selecting NWS hides the model radio.

---

### PHASE 3 — Testing

**T3.1 — Unit tests for model selection**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `tests/test_providers_forecast_aeris_unit.py`
- Do: New test class `TestForecastModelSelection`:
  1. `test_xcast_model_uses_xcast_path_for_hourly` — mock → verify hourly calls xcast path, daynight calls standard path
  2. `test_standard_model_uses_standard_path` — mock → verify both hourly and daynight call standard path
  3. `test_default_model_is_xcast` — omit parameter → verify xcast path used
  4. `test_cache_key_differs_by_model` — different model values → different cache keys
- Accept: All pass. No live-network calls.

**T3.2 — Unit tests for confidence limits**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `tests/test_providers_forecast_aeris_unit.py`
- Do: New test class `TestXcastConfidenceLimits`:
  1. Xcast fixture period validates with confidence fields present (null in fixture; synthetic non-null for extras test)
  2. Standard fixture period validates (fields are None)
  3. Hourly point `extras` contain confidence limits when present (non-null)
  4. Hourly point `extras` have no confidence keys when absent (null)
- Accept: All pass.

**QC (Opus) — after Phase 3:** Run Aeris test suite on weather-dev. All new and existing tests pass. No live-network calls. Fixture provenance documented.

---

### PHASE 4 — Documentation + Deploy

**T4.1 — Update PROVIDER-MANUAL.md**
- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md` §4
- Do: Update Aeris row in the forecast providers table. Add Constraints note: "Operator selects forecast model in wizard: Standard (`/forecasts`) or Xcast (`/xcast/forecasts`, ML-enhanced temp/wind). Config key: `aeris_forecast_model` in `[forecast]`. Default: xcast."
- Accept: Manual updated.

**T4.2 — Update api.conf.example**
- Owner: Coordinator
- File: `repos/weewx-clearskies-stack/config/api.conf.example`
- Do: Add `aeris_forecast_model = xcast` under `[forecast]` with a comment explaining the two options.
- Accept: Example file documents the config key.

**T4.3 — Archive ADR-063**
- Owner: Coordinator (Opus)
- Do: After user approves ADR, extract rules into PROVIDER-MANUAL.md (done in T4.1). Move ADR to `docs/archive/decisions/`. Update `docs/decisions/INDEX.md`.
- Accept: ADR archived. INDEX updated.

**T4.4 — Deploy and verify**
- Owner: Coordinator (Opus)
- Do: Push code. Deploy API + wizard. Wait 2+ min for API cache warm. Verify forecast endpoint returns data. Check logs for model path.
- Accept: API logs show "Using Aeris xcast forecast model" (or standard). `/api/v1/forecast` returns valid data.

**Final QC (Opus):** Walk all acceptance criteria. Doc-code sync verified. Full pytest on weather-dev.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC (Opus) | QC Timing |
|-------|------|-------|-------|-----------|-----------|
| 0 | T0.1 ADR draft | Coordinator | Opus | User reviews ADR | After T0.1 |
| 0 | T0.2 Fixture capture | Coordinator | Opus | Fixtures valid JSON | After T0.2 |
| 1 | T1.1–T1.5 Provider module | `clearskies-api-dev` | Sonnet | Code review, ruff+mypy | After Phase 1 |
| 2 | T2.1–T2.3 Wizard model selection | `clearskies-stack-dev` | Sonnet | Visual verify on weather-dev | After Phase 2 |
| 3 | T3.1–T3.2 Tests | `clearskies-api-dev` | Sonnet | Full pytest run | After Phase 3 |
| 4 | T4.1–T4.4 Docs + deploy | Coordinator | Opus | Final acceptance sweep | After Phase 4 |

**Sequencing:**
- Phase 0 (ADR + fixtures) → gates all implementation
- Phase 1 (provider module) and Phase 2 (wizard) can run in parallel — no code dependency
- Phase 3 (testing) depends on Phase 1
- Phase 4 (docs + deploy) depends on Phases 1, 2, 3

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- API: `ruff check` 0 errors. `mypy` no introduced errors.
- Wizard: `python -m py_compile <file>` passes. Templates render without Jinja2 errors.
- All existing tests pass unmodified (except `_build_cache_key` signature update with default parameter).

### Gate 2 — Feature Correctness (Phase 1 + 2 + 3, Opus verifies)
- `fetch(forecast_model="xcast")` → 2 calls to `/xcast/forecasts`.
- `fetch(forecast_model="standard")` → 2 calls to `/forecasts`.
- Default is `"xcast"`.
- Cache keys differ by model.
- Confidence limits in `extras` when present, absent when not.
- Wizard shows model radio only for Aeris. Key test hits the selected model's endpoint.
- Full wizard round-trip: select → test → review → apply → re-run → pre-fill.

### Gate 3 — ADR + Manual Compliance (Opus verifies after Phase 4)
- ADR-017: Cache key includes model. TTL unchanged (1800s).
- PROVIDER-MANUAL §1: Five responsibilities preserved.
- PROVIDER-MANUAL §12: Confidence limits in `extras`, not canonical fields.
- Doc-code sync: PROVIDER-MANUAL.md, module docstring, operator_notes, api.conf.example all consistent.

### Gate 4 — Accessibility (Opus verifies after Phase 2)
- Model radio has proper `<label>` elements and `aria-describedby` for descriptions.
- Keyboard accessible (Tab to reach, Space/Enter to select).

---

## 5. Self-Audit

**Risk: Xcast response shape drift.** XWeather could change the xcast response independently. **Mitigation:** Optional Pydantic fields (default None) absorb absent fields. `extra="ignore"` absorbs unknown new fields. `ProviderProtocolError` catches structural breaks.

**Risk: Operator selects xcast but key doesn't support it.** **Mitigation:** Wizard key test hits the selected model's endpoint. 401/403 shows a clear message suggesting they switch to Standard. No silent failure.

**Risk: Cache serves wrong model after config change.** Operator changes from standard to xcast (or vice versa) and restarts the API. **Mitigation:** Cache key includes the model string. Different models get separate cache entries. On restart, the memory cache is empty anyway (LRU resets). Redis users would see the old entry expire within 30 min TTL.

**Risk: Location snapping differs.** Live test showed xcast snaps to a slightly different grid point (33.691 vs 33.657). **Mitigation:** This is XWeather's internal grid resolution — not something we control. The forecast is still for the operator's general area. Standard and xcast are cached separately, so there's no mixing of grid points within a single cache entry.

---

## Verification Checklist (post-deploy)

1. **API logs on restart:** "Using Aeris xcast forecast model" (or standard) at INFO level.
2. **Forecast response:** `curl https://weather-test.shaneburkhardt.com/api/v1/forecast?hours=3` returns valid data.
3. **Wizard:** Providers step → Aeris → model radio visible → xcast default → test key → success → review shows "Xcast" → apply.
4. **Config switch:** Set `aeris_forecast_model = standard` in `api.conf`, restart API, verify `/forecasts` used in logs.
5. **Full pytest:** `ssh -F .local/ssh/config weather-dev "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=short -q"` — 0 failures.
