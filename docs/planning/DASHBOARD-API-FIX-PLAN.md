# DASHBOARD-API-FIX-PLAN — Restore unit labels + wire API enrichment

**Goal:** (1) Restore unit label display on dashboard cards and pages where prior agent rewrites or the ADR-058 merge stripped them, (2) wire API enrichment (AQI category, records conversion) that was lost during the merge, (3) fix ADR-042 violations (hardcoded units instead of API-supplied labels).

**Status:** Complete (2026-06-14). All phases deployed and verified.

**Source:** Live dashboard regression observed 2026-06-14 after Phase 2A deployment. Multiple cards show values without units. AQI card shows null category. Other pages have missing or hardcoded units.

**Repos involved:**
- `weewx-clearskies-dashboard` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`) — card and page fixes
- `weewx-clearskies-api` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-api`) — records conversion, AQI enrichment

**Dev/test environment:** Dashboard on `weather-dev` container (192.168.2.113). API on `weewx` container (192.168.7.20). SSH: `ssh -F .local/ssh/config <host> "<cmd>"`. Hosts: `weewx`, `weather-dev`, `ratbert`.

---

## Execution context for new sessions

**What happened before this plan:**

1. **EXTENSION-HARDENING-PLAN-2 Phases 2A-3 (2026-06-14 session 3, completed):** Fixed the extension (moved to `restful_services`, hardened accept loop), unified REST `/current` to return ConvertedValue dicts `{value, label, formatted}` instead of flat scalars (ADR-010 amendment), established single unit authority from `api.conf [units]` instead of weewx.conf, wired `/setup/apply` to accept unit config, cleaned wizard of all realtime/MQTT dead code, passed all 4 integration tests.

2. **Dashboard regression discovered (same session):** After deploying the ConvertedValue shape change, multiple dashboard cards lost unit labels. Root cause analysis found two separate problems:
   - **Precipitation card:** Commit `282cf9f` ("hotfix card regressions") stripped the unit label rendering that commit `b357d01` had added. The card uses `.formatted` (number only) and never reads `.label` (unit suffix). This was a prior-session agent rewrite that removed working code.
   - **Multiple endpoints missing BFF enrichment:** The old BFF (realtime service) enriched ALL responses before they reached the dashboard. When merged into the API (ADR-058), `apply_conversion()` was only wired on `/current` and `/archive`. Records, forecast, AQI, and other endpoints send raw data. Additionally, `epa_category()` exists but is never called — AQI cards show null category.

3. **Other pages audited:** Forecast page hourly strip has no unit designation on temperatures ("66°" not "66°F"). Forecast daily hi/lo missing suffix (tempSuffix defined but unused). Reports page has no units on any numeric value. Lightning card hardcodes "km". Seismic page hardcodes "km" for depth.

**Current state of repos:**

| Repo | Branch | HEAD | Working tree |
|------|--------|------|-------------|
| weewx-clearskies-dashboard | main | `08539dd` | Clean |
| weewx-clearskies-api | main | `0efd35e` | Clean |
| weewx-clearskies-stack | main | `70c4b0a` | Clean |
| weather-belchertown (meta) | master | `592c562` | Clean (except this plan file) |

**Current container state:**

| Container | Service | Status | Notes |
|-----------|---------|--------|-------|
| weewx | weewx.service | Active | Extension v1.1.0 in restful_services |
| weewx | weewx-clearskies-api.service | Active | ConvertedValue dicts on /current, single unit authority from api.conf |
| weather-dev | caddy.service | Active | Routes to weewx:8765 |
| weather-dev | weewx-clearskies-config.service | Active | Wizard cleaned of realtime/MQTT |

**Key files to read first (coordinator reads these directly):**
- This plan
- [CLAUDE.md](../../CLAUDE.md) — operating rules, git safety, agent orchestration
- [rules/clearskies-process.md](../../rules/clearskies-process.md) — process discipline, scope binding
- [rules/coding.md](../../rules/coding.md) — coding standards, accessibility
- [docs/ARCHITECTURE.md](../ARCHITECTURE.md) — current system architecture

---

## Orientation

**Coordinator reads directly.** No delegation of reading or diagnosis.

**Agent briefs are self-contained.** No scope confirmation via SendMessage required — agents proceed directly.

**Git safety:** Agents do NOT push. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`.

**QC model:** Coordinator independently verifies every acceptance criterion — runs the build, loads the dashboard, calls the endpoint. Agent self-attestation is not accepted.

---

## Research findings

### Dashboard audit summary

| Card/Page | Fields affected | Current unit source | Issue |
|-----------|----------------|--------------------|----|
| `precipitation-card.tsx` | rain, rainRate, dewpoint, humidity, snow, snowRate | `.formatted` only (lines 171-187) | `.label` never extracted. Commit `282cf9f` stripped the unit rendering from commit `b357d01`. |
| `lightning-card.tsx` | nearestDistanceKm | Hardcoded "km" (line 132) | ADR-042 violation. `lightning_distance` typed as `number\|null` in types.ts:187, not ConvertedValue. |
| `forecast/HourlyStrip.tsx` | outTemp, windSpeed | `°` only (line 167); no wind unit | `forecast.tsx:35` passes no `units` prop to ForecastHourlyCard. HourlyStrip has no access to unit info. |
| `forecast/DailyColumns.tsx` | tempMax, tempMin (main grid) | Missing unit suffix (lines 339-350) | `tempSuffix` defined at line 115 but NOT used in hi/lo display. Detail panel dewpoints (line 498) DO use it — inconsistent. |
| `routes/reports.tsx` | ALL numeric values | No units at all (lines 381-414) | `formatValue()` called but no unit suffix appended. Units envelope not used. |
| `routes/seismic.tsx` | earthquake depth | Hardcoded "km" (line 328, 430) | API should supply the unit (km) via the units envelope or ConvertedValue. Dashboard should read it, not hardcode it. |

### Cards with correct unit display (no changes needed)

- `current-conditions-card.tsx` — all fields use `.label` with fallbacks
- `barometer-card.tsx` — `.label` at line 192, displayed at line 285
- `solar-radiation-card.tsx` — `.label` at line 329, displayed at lines 394-407
- `todays-highlights-card.tsx` — `.label` with hardcoded fallbacks (lines 120-148)
- `WindCompassCard.tsx` — `.label` via `formatWindField()` helper
- `uv-index-card.tsx` — dimensionless, no unit needed
- `aqi-card.tsx` — AQI dimensionless; category comes from API field (separate fix below)

### API endpoint audit summary

| Endpoint | File | apply_conversion() | Issue |
|----------|------|-------------------|-------|
| `GET /current` | observations.py:296 | YES | Correct |
| `GET /archive` | observations.py:391 | YES | Correct |
| `GET /records` | records.py:101 | **NOT CALLED** | Records have observation values (highs/lows) that need conversion. Response matches Shape 2. |
| `GET /forecast` | forecast.py:459 | **NOT CALLED** | Nested structure (hourly/daily inside ForecastBundle) does NOT match any conversion shape. Provider normalizers already convert to target_unit during fetch. **Verify — may already be correct.** |
| `GET /aqi/current` | aqi.py:393 | NOT CALLED (correct) | AQI fields are not observations. apply_conversion would break the response. But `epa_category()` enrichment IS needed. |
| `GET /aqi/history` | aqi.py:448 | NOT CALLED (correct) | Same as above. |
| `GET /archive/grouped` | archive_grouped.py | NOT CALLED (intentional) | Per ADR-019: raw values, dashboard converts. |

### AQI enrichment gap

`epa_category()` at `providers/aqi/_units.py:141-158` maps AQI 0-500 → category name. **Never called in production.** IQAir and OpenMeteo both return `aqiCategory=None`. The old BFF computed this.

---

## Phase 1 — Dashboard: Now-page card fixes

### T1.1 — Restore precipitation card unit labels

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None
- **Do:**
  1. In `src/components/precipitation-card.tsx`, add `units` to the destructured props at line 162 (currently destructures `observation, loading, error, onRetry` but not `units`, even though `units` is in the interface at line 152).
  2. For each of the 6 fields, extract `.label` from the ConvertedValue and display it alongside the value. Add these lines after the existing CV extractions (lines 170-187):
     ```tsx
     const rainLabel = rainCV?.label ?? units?.rain ?? '';
     const rainRateLabel = rainRateCV?.label ?? units?.rainRate ?? '';
     const dewpointLabel = dewpointCV?.label ?? units?.dewpoint ?? '';
     const humidityLabel = humidityCV?.label ?? units?.outHumidity ?? '%';
     const snowLabel = snowCV?.label ?? units?.snow ?? '';
     const snowRateLabel = snowRateCV?.label ?? units?.snowRate ?? '';
     ```
  3. In the JSX, append the label to each displayed value. For primary values (line 228 rain, line 245 dewpoint, line 263 snow), render as `{rainFormatted}{rainLabel}`. For secondary values (line 230 rainRate, line 247 humidity, line 267 snowRate), render as `{rainRateFormatted}{rainRateLabel}`.
  4. Follow the barometer card pattern: value and unit label can be in the same span or separate spans — match the existing card typography.
  5. Do NOT change the card layout, icons, or any other element.
- **Accept:**
  - `grep -n '\.label' src/components/precipitation-card.tsx` returns 6+ matches
  - `grep -n 'units' src/components/precipitation-card.tsx` shows units in destructured props
  - Visual: rain shows "0.00 in", dewpoint shows "63.1°F", humidity shows "95%"
- **QC:** Coordinator builds dashboard, deploys, loads in browser. Confirms all 6 fields have unit suffixes.

### T1.2 — Fix lightning card hardcoded "km" (ADR-042)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None (parallel with T1.1)
- **Do:**
  1. In `src/components/lightning-card.tsx`, the distance unit is hardcoded as "km" at line 132.
  2. The `observation.lightning_distance` field is typed as `number | null` in types.ts:187. After Phase 2A, it arrives from the API as a ConvertedValue dict with `.label` = " miles" (or " km" depending on operator config).
  3. Extract the distance unit from the observation's ConvertedValue:
     ```tsx
     const distanceCV = asConverted(observation?.lightning_distance ?? null);
     const distanceUnit = distanceCV?.label?.trim() || 'km';
     ```
  4. Update line 132 to use `distanceUnit` instead of hardcoded "km".
  5. Update tooltip formatter (line 243) and SR table header (line 269) to use `distanceUnit`.
  6. Add `import { asConverted } from '../api/types';` if not already imported.
  7. The `lightning_distance` type in `types.ts:187` should be `ConvertedValue | number | null` (same as other observation fields), not just `number | null`. Check and fix if needed.
- **Accept:**
  - `grep -n '"km"' src/components/lightning-card.tsx` returns zero matches (no hardcoded "km")
  - `grep -n 'distanceUnit\|\.label' src/components/lightning-card.tsx` returns matches
  - Visual: distance shows with correct unit from API (miles for US config)
- **QC:** Coordinator loads dashboard, checks lightning card shows distance with API-supplied unit.

---

## Phase 2 — Dashboard: Forecast page fixes

### T2.1 — Pass units to ForecastHourlyCard

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. In `src/routes/forecast.tsx`, line 35: `ForecastHourlyCard` is called without the `units` prop. The `fcUnits` variable is already extracted at line 27. Pass it:
     ```tsx
     <ForecastHourlyCard ... units={fcUnits} />
     ```
  2. In `ForecastHourlyCard.tsx` (or wherever the component is defined): accept `units` prop and pass it through to `HourlyStrip`.
  3. In `HourlyStrip.tsx`, line 167: change `${Math.round(hour.outTemp)}°` to `${Math.round(hour.outTemp)}${tempSuffix}` where `tempSuffix` is derived from `units?.outTemp ?? '°'` (extract the last char — "°F" → "°F", "°C" → "°C").
  4. If wind speed is displayed without units, add the wind unit from `units?.windSpeed ?? ''`.
- **Accept:**
  - Hourly forecast temps show "66°F" or "19°C", not just "66°"
  - Wind speeds (if displayed) show unit suffix
- **QC:** Coordinator loads forecast page, confirms hourly strip shows full unit designation.

### T2.2 — Fix daily forecast hi/lo temperature suffix

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. In `src/components/forecast/DailyColumns.tsx`, lines 339-350: hi/lo temperatures in the main column grid display without unit suffix. The `tempSuffix` variable is already computed at line 115 from the units envelope.
  2. Add `tempSuffix` to the hi/lo display. Currently: `${Math.round(day.tempMax)}°`. Change to: `${Math.round(day.tempMax)}${tempSuffix}` (where tempSuffix is "°F" or "°C").
  3. Same for tempMin.
- **Accept:**
  - Daily hi/lo show "72°F" / "65°F", not "72°" / "65°"
  - Detail panel dewpoint still shows suffix (no regression)
- **QC:** Coordinator loads forecast page, confirms daily columns show full temp unit.

---

## Phase 3 — Dashboard: Reports page fixes

### T3.1 — Add unit suffixes to NOAA report tables

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. In `src/routes/reports.tsx`, lines 381-414: `formatValue()` is called for temperature, wind, rain, etc. but no unit suffix is appended.
  2. The reports endpoint currently returns NO units envelope. Check: does `useReport()` or `useReports()` return a units block? If not, use hardcoded defaults matching the station's unit system (read from station metadata or the observation's units envelope via a separate hook).
  3. Append the appropriate unit suffix after each formatted value in the monthly report table:
     - Temperature columns: append temp unit (°F or °C)
     - Wind columns: append speed unit (mph or km/h)
     - Rain columns: append rain unit (in or mm)
     - Degree columns: append °
  4. Same for yearly sub-table (line 508).
- **Accept:**
  - Monthly report table shows "72.5°F" not "72.5", "5.2 mph" not "5.2", "0.52 in" not "0.52"
  - `grep -n 'Suffix\|\.label\|units' src/routes/reports.tsx` returns matches
- **QC:** Coordinator loads reports page, confirms numeric values have unit suffixes.

---

## Phase 4 — Dashboard: Seismic page fix

### T4.1 — Remove hardcoded "km" from seismic page

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T5.2 (API supplies depth unit — see below)
- **Do:**
  1. In `src/routes/seismic.tsx`, lines 328 and 430: earthquake depth is displayed with hardcoded "km" suffix.
  2. Replace with the depth unit from the API response. The earthquakes endpoint should include a `units` envelope or the depth field should carry a unit label.
  3. Read the depth unit from the response: `const depthUnit = units?.depth ?? 'km';` (fallback to "km" if not provided).
  4. Replace all hardcoded "km" with `depthUnit`.
  5. Update the map popup (line 328), the list view (line 430), and any other depth display.
- **Accept:**
  - `grep -n '"km"' src/routes/seismic.tsx` returns zero matches (no hardcoded "km" for depth)
  - Depth displays with API-supplied unit
- **QC:** Coordinator loads seismic page, confirms depth unit comes from API.

---

## Phase 5 — API: Records conversion + AQI enrichment + earthquake units

### T5.1 — Add apply_conversion to GET /records

- **Owner:** `api-dev` (Sonnet)
- **Dep:** None (parallel with dashboard phases)
- **Do:**
  1. In `endpoints/records.py`, at the return statement (lines 101-106), change from returning the Pydantic model directly to:
     ```python
     from weewx_clearskies_api.units.response_conversion import apply_conversion
     from fastapi.responses import JSONResponse
     response_dict = response.model_dump(by_alias=True, exclude_none=True)
     response_dict = apply_conversion(response_dict)
     return JSONResponse(content=response_dict)
     ```
  2. Add `from fastapi.responses import JSONResponse` to file imports.
  3. The records response matches Shape 2 (`data: dict, units: dict`) — `apply_conversion()` will process it correctly.
- **Accept:**
  - `grep -n 'apply_conversion' endpoints/records.py` returns a match
  - `curl -sk https://localhost:8765/api/v1/records | python3 -c "..."` — verify observation values in records are ConvertedValue dicts
- **QC:** Coordinator calls `/api/v1/records` on the weewx container and confirms values are converted.

### T5.2 — Wire epa_category() in AQI endpoint

- **Owner:** `api-dev` (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. In `endpoints/aqi.py`, in `get_aqi_current()`, after the multi-source merge (around line 385) and before the return (line 393), add:
     ```python
     if record is not None and record.aqiCategory is None and record.aqi is not None:
         if record.aqiScale in ("epa", "airnow"):
             from weewx_clearskies_api.providers.aqi._units import epa_category  # noqa: PLC0415
             record = record.model_copy(update={"aqiCategory": epa_category(record.aqi)})
     ```
  2. In `get_aqi_history_endpoint()`, apply the same enrichment to each record in the history list (iterate and replace).
  3. Do NOT call `apply_conversion()` on AQI responses — AQI fields are not weather observations and Shape 2 conversion would incorrectly wrap `aqi: 19` as a ConvertedValue dict.
- **Accept:**
  - `curl -sk https://localhost:8765/api/v1/aqi/current | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['aqiCategory'])"` returns "Good" (not null)
  - `grep -n 'epa_category' endpoints/aqi.py` returns matches in both functions
- **QC:** Coordinator calls `/api/v1/aqi/current` and confirms `aqiCategory` is "Good" for AQI 19.

### T5.3 — Add depth unit to earthquake endpoint response

- **Owner:** `api-dev` (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. The earthquake endpoint returns depth as a raw number (km by agency convention). The API should include a `units` block in the response with `depth: "km"` so the dashboard can read it instead of hardcoding.
  2. In `endpoints/earthquakes.py`, at the return statement, add a `units` field to the response with `{"depth": "km", "magnitude": ""}` (magnitude is dimensionless).
  3. If the response model doesn't have a `units` field, add one (optional dict).
- **Accept:**
  - `curl /api/v1/earthquakes | python3 -c "..."` — response includes `units.depth = "km"`
- **QC:** Coordinator verifies the endpoint response includes the units block.

### T5.4 — Verify forecast conversion status

- **Owner:** Coordinator (direct — read-only verification)
- **Dep:** None
- **Do:**
  1. Forecast provider normalizers already convert to `target_unit` during fetch (forecast.py line 312: `target_unit = get_target_unit()`).
  2. Verify by calling `/api/v1/forecast` and checking: are temperatures in °F (the configured US unit)? Are wind speeds in mph?
  3. If values are already converted: no API change needed. The issue is dashboard-side (Phases 2.1/2.2 above).
  4. If values are NOT converted: document and plan a fix (out of scope for this plan — would need custom conversion logic).
- **Accept:** Verification result documented. Forecast temperatures confirmed as °F or identified as needing conversion.
- **QC:** Coordinator runs the curl command directly.

---

## Phase 6 — Deploy and verify

### T6.1 — Commit and push dashboard changes

- **Owner:** Coordinator (direct)
- **Dep:** Phases 1-3 complete
- **Do:**
  1. In the dashboard repo: `git add` all changed files, commit with descriptive message, push.
  2. On weather-dev: `cd /home/ubuntu/repos/weewx-clearskies-dashboard && git pull && npm ci && npm run build`.
  3. Deploy: `rsync -av --delete --exclude webcam/ dist/ /var/www/clearskies/`.
- **Accept:** Dashboard deployed. Browser hard-refresh shows updated cards.

### T6.2 — Commit and push API changes, deploy

- **Owner:** Coordinator (direct)
- **Dep:** T4.1, T4.2 complete
- **Do:**
  1. In the API repo: `git add` changed files, commit, push.
  2. On weewx container: `cd /home/ubuntu/repos/weewx-clearskies-api && git pull && sudo systemctl restart weewx-clearskies-api`.
  3. Wait ~2 min for startup.
- **Accept:** API serves requests. `/api/v1/aqi/current` shows `aqiCategory: "Good"`.

### T6.3 — Full visual verification

- **Owner:** Coordinator (direct)
- **Dep:** T5.1, T5.2
- **Do:** Load the dashboard in browser. Check each card and page:
  1. **Precipitation card:** rain "0.00 in", rate "0.00 in/h", dewpoint "63.1°F", humidity "95%"
  2. **Lightning card:** distance shows unit from API (miles), not hardcoded "km"
  3. **AQI card:** category shows "Good" (not "—")
  4. **Forecast hourly:** temps show "66°F" not "66°"
  5. **Forecast daily:** hi/lo show "72°F"/"65°F" not "72°"/"65°"
  6. **Reports page:** numeric values have unit suffixes
  7. **No regressions:** Current conditions, barometer, solar, highlights, wind compass — all still correct
  8. **SSE flowing:** real-time updates arrive
- **Accept:** All listed items verified. Screenshots captured.
- **QC:** Coordinator performs all checks directly in the browser.

---

## Dependency graph

```
Phase 1 (Now-page cards)           Phase 5 (API)
T1.1 precipitation card ─┐        T5.1 records conversion ────┐
T1.2 lightning card ──────┤        T5.2 AQI enrichment ────────┤  all parallel
                          │        T5.3 earthquake depth unit ──┤
Phase 2 (Forecast page)   │        T5.4 forecast verify ───────┘
T2.1 hourly units ────────┤                │
T2.2 daily hi/lo suffix ──┤                │
                          │                │
Phase 3 (Reports page)    │                │
T3.1 report table units ──┤                │
                          │                │
Phase 4 (Seismic page)    │                │
T4.1 seismic depth unit ──┘                │
  (dep: T5.3 — API first)                 │
         │                                 │
         ├─────────────────────────────────┘
         ▼
Phase 6 (Deploy + verify)
T6.1 dashboard deploy ──┐
T6.2 API deploy ─────────┤  sequential
T6.3 visual verify ──────┘
```

---

## Verification bar — plan-level "done"

- **Precipitation card:** Unit labels on all 6 fields (rain, rainRate, dewpoint, humidity, snow, snowRate)
- **Lightning card:** Distance unit from API, not hardcoded
- **AQI card:** Category "Good" displayed (not "—")
- **Forecast hourly:** Temperature unit designation shown (°F/°C)
- **Forecast daily:** Hi/lo temperatures show full unit
- **Reports page:** Numeric values have unit suffixes
- **Seismic page:** Depth unit from API, not hardcoded
- **No regressions:** All other cards unchanged and correct
- **SSE flowing:** Real-time updates work
- **All changes committed and pushed.** Dashboard and API deployed.
