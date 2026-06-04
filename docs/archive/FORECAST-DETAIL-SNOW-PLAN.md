# 7-Day Forecast Detail + Precipitation/Snow — Granular Implementation Plan

**Status: COMPLETE — 2026-06-03.** All three phases implemented, deployed, and verified live.

### Completion summary

**Phase 1 (API):** All 8 tasks (A1–A8) complete. New fields (dewpoint, humidity, visibility,
snow, storm risk) added to DailyForecastPoint model, OpenAPI contract, and all 5 provider
mappings (Aeris, Open-Meteo, OWM, NWS, Wunderground). Snow/snowRate blended into /current.
Aeris convective outlook endpoint integrated for storm risk fields.

**Phase 2 (Dashboard):** All 4 tasks (D1–D4) complete. TypeScript types updated. Daily detail
panel redesigned with full chip grid (dewpoint, humidity, visibility, UV, rain, snow, gust,
sunrise, sunset, storm risks). Precipitation card updated with snow display. Forecast cards
show precipType icons and amounts.

**Phase 3 (Convective):** Tasks S1–S3 complete. Aeris convective outlook fetched and mapped
to thunderRisk/tornadoRisk/hailRisk/windRisk. Wunderground thunderCategory/thunderIndex mapped.

**Post-implementation fixes (2026-06-03 session):**
- Sunrise/sunset computed locally via Skyfield almanac (Aeris daynight filter lacks these fields)
- Narrative mapped from Aeris weatherPrimary (was hardcoded to None)
- Precip centering fixed in daily columns
- Detail panel gradient aligned with selected column background
- Hourly card fixed: 24-hour windows per tab instead of calendar-date partition
- All detail panel labels i18n'd via forecast.json translation keys
- Unit suffixes driven by API units block (not hardcoded)
- First column auto-selected so detail panel is visible on load
- Card title icons removed (matches Now page convention)
- Page hero icon added to PageHeaderCard

**API commits:** `e09f5ab`–`f80e8ab` (11 commits on weewx-clearskies-api main)
**Dashboard commits:** `bdac9d5`–`5b809ba` (13 commits on weewx-clearskies-dashboard main)

---

## Session Context (for cold-start)

**Project:** Clear Skies — modern weather dashboard replacing Belchertown weewx skin.
**Repos (all under `c:\CODE\weather-belchertown\repos\`):**
- `weewx-clearskies-api` — FastAPI + SQLAlchemy, provider-agnostic weather API
- `weewx-clearskies-realtime` — Python BFF (SSE + REST proxy)
- `weewx-clearskies-dashboard` — React 19 + Vite + Tailwind v4 + Recharts

**Architecture:** API runs on weewx container (port 8765 HTTPS). BFF runs on
weather-dev (port 8766). Dashboard is static SPA served by Caddy on weather-dev.
API is provider-agnostic — providers map to canonical models. Dashboard is API-agnostic.

**Git rules:** Agents may ONLY `git add`, `commit`, `status`, `log`, `diff`. NO pull/
push/fetch/rebase/merge. Coordinator handles push + deploy.

**Deploy:** `scripts/redeploy-weather-dev.sh` (dashboard only). API deploy is manual
on the weewx container.

**Rules files:** `rules/clearskies-process.md`, `rules/coding.md`

---

## What we're building

### Feature 1: 7-Day Forecast Expanded Detail Panel

The 7-Day forecast card on the Forecast page has expandable columns (click a day →
detail panel appears below). The detail panel EXISTS but is minimal. We're enriching
it with more forecast detail fields.

**Inspiration:** img-12 (UNIAN Poltava) — selected column flows seamlessly into a
detail block below. We keep our column design; the detail panel gets its own layout.

**Detail panel content (operator-specified):**
- Summary/narrative statement
- Forecasted dewpoint (max or avg for the day)
- Forecasted humidity (max or avg)
- Forecasted visibility
- Forecasted UV index (already on DailyForecastPoint as uvIndexMax)
- Predicted precipitation amount by type (rain, snow — separate amounts)
- Sunrise / sunset (already on DailyForecastPoint)
- Storm outlook risks (thunderstorm, tornado, hail, wind) — shown ONLY when risk > 0

Wind speed/gust and precip probability are already in the column — not repeated.

### Feature 2: Precipitation & Snow

**Now page precipitation card:** Currently shows rain only. Must add snow accumulation
(visible when > 0, stays for the day, snowflake icon) and snow rate (if provider
supplies it). Rain always shown.

**Forecast cards (hourly + daily):** Must show precipitation type (rain/snow icon) and
amounts. Logic: both → both; snow only → snow; rain only → rain; neither → rain as 0.

---

## API Architecture (for agent prompts)

**Canonical model:** `weewx_clearskies_api/models/responses.py`
- `DailyForecastPoint` (Pydantic BaseModel, line ~686) — currently has: validDate,
  tempMax, tempMin, precipAmount, precipProbabilityMax, windSpeedMax, windGustMax,
  sunrise, sunset, uvIndexMax, weatherCode, weatherText, narrative, source, extras
- `HourlyForecastPoint` (line ~645) — has precipType, precipAmount, precipProbability
- `ProviderConditions` (line ~153) — internal DTO for current conditions blending

**Provider modules:** `weewx_clearskies_api/providers/forecast/`
- Each provider has: `CAPABILITY` declaration, wire Pydantic models, translation
  function (`_zip_daily()` or `_daynight_periods_to_daily()`), `fetch()` entrypoint
- Pattern: Wire Response → Pydantic validate → Translation → DailyForecastPoint
- Unit selection: Aeris selects field names (e.g. `tempF` vs `tempC`); Open-Meteo
  uses query params; NWS has its own parser

**OpenAPI contract:** `docs/contracts/openapi-v1.yaml` — DailyForecastPoint at line ~1269

**Adding a new field:** 
1. Add to Pydantic model (responses.py)
2. Add to OpenAPI yaml
3. Add mapping in each provider's translation function
4. Add to each provider's CAPABILITY `supplied_canonical_fields`

---

## Provider Data Availability

### Daily forecast detail fields

| Field | Aeris | Open-Meteo | OWM | NWS | Wunderground |
|-------|-------|-----------|-----|-----|-------------|
| Narrative | `weatherPrimary` | Derive from WMO code | `weather[].description` | `detailedForecast` (best) | `narrative` per daypart |
| Dewpoint | `maxDewpointF`/`minDewpointF` | hourly `dew_point_2m` only | hourly `dew_point` only | No | No |
| Humidity | `humidity`/`maxHumidity`/`minHumidity` | `rh_2m_max/mean/min` (daily) | hourly only | No | `relativeHumidity` per daypart |
| Visibility | `visibilityKM`/`visibilityMI` | `visibility_max/mean/min` (daily) | hourly only | No | No |
| UV Index | `uvi` | `uv_index_max` (daily) | hourly `uvi` | No | `uvIndex` per daypart |
| Precip amount | `precipIN`/`precipMM` | `precipitation_sum` | `rain`+`snow` | prose only | `qpf` per daypart |
| Snow amount | `snowIN`/`snowCM` | `snowfall_sum` | `snow` | No | `qpfSnow` |
| Sunrise/Sunset | `sunriseISO`/`sunsetISO` | `sunrise`/`sunset` | `sunrise`/`sunset` | prose | `sunriseTimeLocal` |

### Storm/convective outlook

| Provider | What they have | Endpoint/fields |
|----------|---------------|----------------|
| Aeris | Convective outlook (NOT in our captured docs — needs live doc capture) | Likely `/convective/outlook` — SPC data |
| Wunderground | Thunder risk (3-day) | `daypart[].thunderCategory` (string), `daypart[].thunderIndex` (numeric) |
| Open-Meteo | CAPE (hourly raw instability metric) | `cape` on hourly — would need our own heuristic to derive risk |
| OWM | Nothing | — |
| NWS | Nothing structured | Prose in `detailedForecast` only |

### Snow fields

| Provider | Current obs | Hourly forecast | Daily forecast |
|----------|------------|----------------|----------------|
| Aeris | No (depth only) | `snowIN`/`snowCM` | `snowIN`/`snowCM` |
| Open-Meteo | N/A | `snowfall` (cm) | `snowfall_sum` |
| OWM | `snow.1h` (mm) | `snow.1h` | `snow` |
| Wunderground | No | No hourly | `qpfSnow` |
| NWS | No | Not on standard | Not on standard |
| Weewx station | `snow`/`snowRate` if hardware | N/A | N/A |

---

## TASKS

### Phase 1: API — Add new canonical fields + provider mappings

#### Task A1: Add fields to DailyForecastPoint model + OpenAPI

**Owner:** clearskies-api-dev agent
**Files:**
- `weewx_clearskies_api/models/responses.py` — `DailyForecastPoint` class (~line 686)
- `docs/contracts/openapi-v1.yaml` — DailyForecastPoint schema (~line 1269)

**Do:**
Add these fields to the Pydantic model (all `float | None = None`) and matching
OpenAPI properties (`type: number, nullable: true`):

```python
# Daily detail fields
dewpointMax: float | None = None    # °F or °C depending on station unit system
dewpointMin: float | None = None
humidityMax: float | None = None    # 0-100 %
humidityMin: float | None = None
visibilityMax: float | None = None  # miles or km depending on station unit system
visibilityMin: float | None = None
snowAmount: float | None = None     # in or mm (same unit group as precipAmount)
# Storm outlook (0 = none, higher = greater risk; scale TBD per provider)
thunderRisk: float | None = None
tornadoRisk: float | None = None
hailRisk: float | None = None
windRisk: float | None = None
```

Fields that already exist (DO NOT add again): `uvIndexMax`, `precipAmount`,
`narrative`, `sunrise`, `sunset`, `weatherText`.

**Accept:** Model has all fields. OpenAPI matches. `pytest` passes (or at least
no new failures from adding nullable fields with defaults).

**QC (Opus):** Read the model and OpenAPI after edit. Verify field names match
exactly between Python and YAML. Verify all new fields are nullable with defaults.

---

#### Task A2: Add snow fields to Observation model + ProviderConditions

**Owner:** clearskies-api-dev agent
**Files:**
- `weewx_clearskies_api/models/responses.py` — `ProviderConditions` class (~line 153)
- `docs/contracts/openapi-v1.yaml` — Observation schema

**Do:**
`ProviderConditions` currently has no snow fields. Add:
```python
snow: float | None = None       # daily snow accumulation
snowRate: float | None = None   # snow rate (if provider supplies it)
```

Verify that the `Observation` schema in OpenAPI already has `snow`, `snowRate`,
`snowDepth` (it should — these are weewx archive fields). If not, add them.

**Accept:** ProviderConditions has snow fields. Observation schema has snow fields.

**QC (Opus):** Read both files. Confirm field names match canonical data model.

---

#### Task A3: Map Aeris daily detail fields

**Owner:** clearskies-api-dev agent
**Files:**
- `weewx_clearskies_api/providers/forecast/aeris.py`
  - `_daynight_periods_to_daily()` function (~line 581)
  - `CAPABILITY` declaration (~line 121)
  - Wire models (if needed for new fields)

**Do:**
In the `_daynight_periods_to_daily()` translation function, map these Aeris wire
fields to the new canonical fields:

```
Aeris Wire              → Canonical Field
maxDewpointF/C          → dewpointMax (use unit-field selection pattern at ~line 621)
minDewpointF/C          → dewpointMin
humidity / maxHumidity  → humidityMax
minHumidity             → humidityMin
visibilityMI/KM         → visibilityMax (MI for US, KM for METRIC/METRICWX)
snowIN/CM               → snowAmount (IN for US, CM for METRIC/METRICWX)
```

Add these new fields to Aeris CAPABILITY `supplied_canonical_fields`.

Check if the Aeris wire model (`_AerisWireForecastPeriod` or similar) already
includes `maxDewpointF`, `visibilityMI`, `snowIN` etc. If not, add them to the
wire model with `Field(default=None)`.

**Accept:** Aeris daily forecasts carry dewpoint, humidity, visibility, snow.
Verified by checking the DailyForecastPoint output for an Aeris-configured station.

**QC (Opus):** Read the mapping function. Verify every new canonical field has a
wire source. Verify unit selection follows the existing pattern (US/METRIC/METRICWX).
Verify CAPABILITY lists the new fields. Run `pytest` — no new failures.

---

#### Task A4: Map Open-Meteo daily detail fields

**Owner:** clearskies-api-dev agent
**Files:**
- `weewx_clearskies_api/providers/forecast/openmeteo.py`
  - `_OpenMeteoDailyBlock` wire model (~line 295)
  - `_zip_daily()` function (~line 532)
  - CAPABILITY (~line 108)

**Do:**
Add to `_OpenMeteoDailyBlock`:
```python
relative_humidity_2m_max: list[float | None] = Field(default_factory=list)
relative_humidity_2m_min: list[float | None] = Field(default_factory=list)
visibility_max: list[float | None] = Field(default_factory=list)
visibility_min: list[float | None] = Field(default_factory=list)
snowfall_sum: list[float | None] = Field(default_factory=list)
```

Add to the Open-Meteo API request `daily=` parameter string (find where the
daily variables are listed, add these).

Map in `_zip_daily()`:
```python
humidityMax=_nth(daily.relative_humidity_2m_max, i),
humidityMin=_nth(daily.relative_humidity_2m_min, i),
visibilityMax=_nth(daily.visibility_max, i),
visibilityMin=_nth(daily.visibility_min, i),
snowAmount=_nth(daily.snowfall_sum, i),
```

Open-Meteo has NO daily dewpoint — leave `dewpointMax`/`dewpointMin` as None.
Update CAPABILITY.

**Accept:** Open-Meteo daily forecasts carry humidity, visibility, snow.
Dewpoint is null (expected — hourly only).

**QC (Opus):** Read the wire model additions. Verify the API request string
includes the new daily variables. Verify `_zip_daily` maps every new wire field.

---

#### Task A5: Map OWM daily detail fields

**Owner:** clearskies-api-dev agent
**Files:**
- `weewx_clearskies_api/providers/forecast/openweathermap.py`

**Do:**
OWM One Call daily has: `humidity`, `dew_point`, `uvi`, `rain`, `snow`.
Map to canonical fields. Note: OWM daily fields are single values (not max/min)
— map `humidity` → `humidityMax`, `dew_point` → `dewpointMax`.
Map `snow` → `snowAmount`. Update CAPABILITY.

**Accept:** OWM daily forecasts carry humidity, dewpoint, snow, UV.

**QC (Opus):** Read the mapping. Verify field extraction from OWM wire format.

---

#### Task A6: Map NWS daily detail fields

**Owner:** clearskies-api-dev agent
**Files:**
- `weewx_clearskies_api/providers/forecast/nws.py`

**Do:**
NWS standard `/forecast` endpoint has NO structured dewpoint/humidity/visibility
fields on daily. Only `detailedForecast` (prose). Ensure `narrative` is mapped to
`detailedForecast`. No new numeric fields to map — all will be null.

**Accept:** NWS `narrative` carries `detailedForecast`. New fields are null.

**QC (Opus):** Confirm narrative mapping exists. Confirm no false field mappings.

---

#### Task A7: Map Wunderground daily detail fields

**Owner:** clearskies-api-dev agent
**Files:**
- `weewx_clearskies_api/providers/forecast/wunderground.py`

**Do:**
Wunderground daily daypart has: `relativeHumidity`, `uvIndex`, `qpfSnow`,
`thunderCategory`, `thunderIndex`, `narrative`.

Map:
```
daypart[].relativeHumidity → humidityMax (use day period)
daypart[].uvIndex          → uvIndexMax (use day period)
qpfSnow                   → snowAmount
daypart[].thunderIndex     → thunderRisk
daypart[].narrative        → narrative (use day period)
```

Update CAPABILITY.

**Accept:** Wunderground carries humidity, UV, snow, thunder risk, narrative.

**QC (Opus):** Read the mapping. Verify daypart index alignment (day=2i, night=2i+1).

---

#### Task A8: Wire snow into /current response

**Owner:** clearskies-api-dev agent
**Files:**
- `weewx_clearskies_api/endpoints/observations.py` — current conditions assembly
- Provider `fetch_current_conditions()` in each forecast provider module

**Do:**
The `/current` endpoint reads from the weewx archive DB. The `snow` and `snowRate`
columns already exist in the weewx schema (wview_extended). They should already
be in the observation response if the archive has them.

Check: does the observation assembly code (observations.py ~line 242) include
`snow` and `snowRate` when building the response from the archive row? If the
station doesn't have snow hardware, these will be null — that's correct.

For provider fallback: add `snow` to `ProviderConditions`. In each provider's
`fetch_current_conditions()`, if the provider supplies current snow data (OWM
has `snow.1h`), map it. The blending logic in observations.py should prefer
the station value when available, provider value when station is null.

**Accept:** `/current` response includes `snow` and `snowRate` fields. If station
has data, it's shown. If not and provider has it, provider value is used.

**QC (Opus):** `curl /api/v1/current | jq '.data.snow, .data.snowRate'` — should
return null (SoCal, no snow) but the fields should be present.

---

### Phase 2: Dashboard — Types + UI

#### Task D1: Update TypeScript types

**Owner:** clearskies-dashboard-dev agent
**Files:**
- `repos/weewx-clearskies-dashboard/src/api/types.ts`

**Do:**
Add to `DailyForecastPoint` (around line 265):
```typescript
dewpointMax: number | null;
dewpointMin: number | null;
humidityMax: number | null;
humidityMin: number | null;
visibilityMax: number | null;
visibilityMin: number | null;
snowAmount: number | null;
thunderRisk: number | null;
tornadoRisk: number | null;
hailRisk: number | null;
windRisk: number | null;
```

Add to `Observation` (if not already there):
```typescript
snow: ConvertedValue | number | null;
snowRate: ConvertedValue | number | null;
```

Add to `HourlyForecastPoint`:
```typescript
snowAmount: number | null;
```

**Accept:** `tsc --noEmit` passes. Types match the OpenAPI contract.

**QC (Opus):** Read types.ts. Verify every field name matches the API model exactly.

---

#### Task D2: Redesign 7-Day detail panel

**Owner:** clearskies-dashboard-dev agent
**Files:**
- `repos/weewx-clearskies-dashboard/src/components/forecast/DailyColumns.tsx`
  — detail panel section (currently lines 365-448)

**Do:**
Replace the current detail panel with a richer layout. The detail panel should show:

**Layout:** Two-column grid of label/value pairs (responsive — single column on mobile).

**CRITICAL RULE: Only render non-null values.** The dashboard is provider-agnostic —
it has no knowledge of which provider is configured. It simply checks each field
in the API response: if the value is non-null, render it. If null, skip it entirely.
No empty rows, no "N/A", no placeholder. The detail panel naturally adapts based
on what the API supplies. Storm risks rendered ONLY when > 0.

**Fields to display (in order):**
1. **Narrative** — full width, italic, if available
2. **Dewpoint** — "Dewpoint: {dewpointMax}°" (or "{dewpointMin}°–{dewpointMax}°" if both)
3. **Humidity** — "Humidity: {humidityMax}%" (or range)
4. **Visibility** — "Visibility: {visibilityMax} mi"
5. **UV Index** — "UV Index: {uvIndexMax}" (already on DailyForecastPoint)
6. **Precipitation** — "Rain: {precipAmount} in" (when > 0)
7. **Snow** — "Snow: {snowAmount} in" with snowflake icon (when > 0)
8. **Sunrise** — "Sunrise: {time}" (already available)
9. **Sunset** — "Sunset: {time}" (already available)
10. **Storm outlook** — only when any risk > 0:
    - "⚡ Thunderstorm Risk: {thunderRisk}"
    - "🌪 Tornado Risk: {tornadoRisk}"
    - "Hail Risk: {hailRisk}"
    - "Wind Risk: {windRisk}"

Keep the existing visual treatment: selected column background flows into the
detail panel (`selectedColBg` + gradient). Keep `aria-live="polite"`.

**Accept:**
- Detail panel shows all available fields for the selected day
- Fields are hidden when null
- Storm risks hidden when 0 or null
- Layout works on both desktop and mobile
- Clicking a different column updates the panel
- Clicking the same column closes it

**QC (Opus):** Deploy to weather-dev. Click each day column on the forecast page.
Verify: narrative text appears, UV index shows, sunrise/sunset shows. Snow/storm
fields will be null initially (SoCal) — verify they DON'T show when null.
Verify desktop and mobile layouts.

---

#### Task D3: Update precipitation card with snow

**Owner:** clearskies-dashboard-dev agent
**Files:**
- `repos/weewx-clearskies-dashboard/src/components/precipitation-card.tsx`

**Do:**
Currently shows rain rate + rain today only. Add:
- Snow today line with snowflake icon — visible ONLY when `observation.snow > 0`
- Snow rate — visible ONLY when `observation.snowRate` is non-null
- Snow stays visible for the rest of the day once it appears (check > 0)

Rain is ALWAYS shown (never removed). Snow appears below rain when active.

Use `asConverted()` for snow values same as rain.

**Accept:**
- Card shows rain always
- Card shows snow with snowflake icon when snow > 0
- Card does NOT show "Snow: 0.00" when there's no snow
- Snow rate appears only when provider supplies it
- Both rain and snow visible simultaneously when both are non-zero

**QC (Opus):** Deploy. Verify card shows rain only (SoCal, no snow). Verify
no "Snow: 0" line appears. Verify `tsc --noEmit` and `vite build` clean.

---

#### Task D4: Update forecast cards precipitation display

**Owner:** clearskies-dashboard-dev agent
**Files:**
- `repos/weewx-clearskies-dashboard/src/components/forecast/HourlyStrip.tsx`
- `repos/weewx-clearskies-dashboard/src/components/forecast/DailyColumns.tsx`

**Do:**
Currently both show `precipProbability` only. Add:
- Use `precipType` to select raindrop vs snowflake icon on hourly
- Show `precipAmount` alongside probability when non-null and > 0
- Show `snowAmount` with snowflake when non-null and > 0 (daily only)
- Logic: both → both; snow only → snow; rain only → rain; neither → rain as 0

**Accept:**
- Hourly strip shows appropriate icon per precipType
- Daily columns show precipitation amount when available
- Snow amount shown with snowflake when > 0
- No display when amount is 0 or null (probability still shows)

**QC (Opus):** Deploy. Check hourly strip — icons should match weather conditions.
Check daily — precip amounts appear if provider supplies them.

---

### Phase 3: Convective Outlook (separate, after Phases 1-2)

#### Task S1: Capture Aeris convective outlook API docs

**Owner:** Coordinator (me) — web research
**Do:** Fetch https://www.xweather.com/docs/weather-api/endpoints and find the
convective outlook endpoint. Document it in `docs/reference/api-docs/aeris.md`
with the same format as existing endpoint docs (example request, response, notes).

#### Task S2: Add convective endpoint to Aeris provider module

**Owner:** clearskies-api-dev agent (after S1)
**Do:** Implement the convective outlook fetch and map to `thunderRisk`, `tornadoRisk`,
`hailRisk`, `windRisk` on DailyForecastPoint.

#### Task S3: Map Wunderground thunderCategory/thunderIndex

**Owner:** clearskies-api-dev agent
**Do:** Already partially covered in Task A7. This task adds the specific mapping
of `thunderCategory` string → numeric risk level and `thunderIndex` → `thunderRisk`.

---

## Execution Order

```
Phase 1 (API — sequential, same repo):
  A1 (model + OpenAPI) → A2 (observation snow) → A3–A7 (provider mappings, parallel) → A8 (wire snow /current)

Phase 2 (Dashboard — after Phase 1 API is deployed):
  D1 (types) → D2 + D3 + D4 (parallel, different files)

Phase 3 (Convective — after Phases 1-2):
  S1 (doc capture) → S2 + S3 (parallel)
```

---

## Agent Assignments

| Task | Agent type | Repo |
|------|-----------|------|
| A1 | clearskies-api-dev | weewx-clearskies-api |
| A2 | clearskies-api-dev | weewx-clearskies-api |
| A3–A7 | clearskies-api-dev (one agent, sequential per file) | weewx-clearskies-api |
| A8 | clearskies-api-dev | weewx-clearskies-api |
| D1 | clearskies-dashboard-dev | weewx-clearskies-dashboard |
| D2 | clearskies-dashboard-dev | weewx-clearskies-dashboard |
| D3 | clearskies-dashboard-dev | weewx-clearskies-dashboard |
| D4 | clearskies-dashboard-dev | weewx-clearskies-dashboard |
| S1 | Coordinator (me) | docs (meta repo) |
| S2, S3 | clearskies-api-dev | weewx-clearskies-api |

---

## Definition of "Complete"

Each task is complete when ALL of the following are true:

1. **Code compiles** — `pytest` (API) or `tsc --noEmit` + `vite build` (dashboard)
   passes with 0 new errors
2. **Contract matches** — OpenAPI YAML and TypeScript types match the Python model
   field-for-field (same names, same nullability)
3. **CAPABILITY updated** — each provider's `supplied_canonical_fields` lists every
   field it now maps
4. **Functionally correct** — the feature does what was specified, verified by Opus QC:
   - Fields that should be null ARE null (not 0, not empty string)
   - Fields that should be hidden ARE hidden (not showing "0" or "null")
   - Fields that should show DO show with correct values
   - Layout works on both desktop (1400px) and mobile (375px)
5. **No regressions** — existing features still work (existing tests pass, existing
   UI elements unchanged)

---

## QC Protocol (Opus — after each task)

For API tasks:
1. Read the modified model file — verify field names/types match OpenAPI
2. Read the modified provider mapping — verify every new field has a wire source
3. Read the CAPABILITY — verify it lists the new fields
4. Run `pytest` — verify no new failures
5. Check the API response: `curl /api/v1/forecast?days=3 | jq '.data.daily[0]'`
   — verify new fields present (null is OK for providers that don't supply them)

For dashboard tasks:
1. Read the modified component — verify it consumes the correct field names
2. `tsc --noEmit` + `vite build` — 0 errors
3. Deploy to weather-dev
4. Open in browser — verify the feature works visually
5. Check null handling — fields not supplied by the current provider should NOT
   appear in the UI (no "null", no "0", no empty space)
6. Check both light and dark themes
7. Check both desktop and mobile
