# Plan: Per-Pollutant AQI Dot Coloring

**Status:** Executed 2026-06-23  
**Approved by:** Shane  
**Repos affected:** `weewx-clearskies-api`, `weewx-clearskies-dashboard`, `weather-belchertown` (docs)

---

## Context

The AQI card on the Now page shows individual pollutant readings (PM2.5, PM10, O3, NO2, SO2, CO) each with a colored dot. Currently **all dots use the same color** derived from the overall AQI value — if the overall AQI is 34 ("Good"), every dot is green, even if one pollutant is elevated. The user wants each dot colored independently based on that pollutant's own sub-index value, while continuing to display raw concentrations (not sub-index numbers).

All three remaining AQI providers (Aeris, Open-Meteo, IQAir) compute per-pollutant sub-indices server-side and return them on the wire. The current code throws them away. This is a pass-through change — no AQI breakpoint computation on our side, no violation of Provider Manual anti-pattern #11 ("Computing AQI from raw concentration breakpoints").

The AQI card already self-hides null pollutant rows (`PollutantRow` returns null when `value === null` at `aqi-card.tsx:570`), so providers that return fewer than 6 pollutants (like IQAir which may return only 3) won't produce empty slots.

---

## Governing documents to read before starting

1. `docs/ARCHITECTURE.md` — system topology, AQI data flow, port registry
2. `rules/clearskies-process.md` — agent orchestration, scope binding, QC gates, doc-code sync
3. `docs/PROVIDER-MANUAL.md` §5 — AQI provider rules, pass-through architecture, anti-patterns
4. `docs/API-MANUAL.md` §2 — data model, AQIReading entity, response shapes
5. `docs/DASHBOARD-MANUAL.md` — Now page card inventory, card plugin system
6. `docs/reference/api-docs/aeris.md` — Aeris AQI wire shape (§Air Quality, lines 286-576)
7. `docs/reference/api-docs/openmeteo.md` — Open-Meteo AQI wire shape (§Air Quality, lines 224-432)
8. `docs/reference/api-docs/iqair.md` — IQAir wire shape (verified paid-tier section, lines 161-228)
9. `docs/contracts/canonical-data-model.md` §3.8 — AQIReading field table
10. `docs/archive/decisions/ADR-059-multi-jurisdiction-aqi.md` — pass-through architecture decision

---

## Provider wire analysis (all verified)

### Aeris — sub-indices on the wire, currently dropped

Each `pollutants[]` entry in the `/airquality/{lat},{lon}` response includes per-pollutant sub-indices:

```json
{ "type": "o3", "valuePPB": 36, "valueUGM3": 72,
  "aqi": 33, "category": "good", "color": "00E400", "method": "airnow" }
```

- `aqi`: per-pollutant sub-index on the same scale as `periods[0].aqi`
- Available for **all 8 AQI scales** (airnow, china, india, eaqi, caqi, uk, de, cai)
- 6 pollutants: pm2.5, pm10, o3, no2, so2, co (pm1 also returned but has no canonical field)

**Currently:** `_AerisPollutant` model (`providers/aqi/aeris.py:241`) uses `extra="ignore"` which silently drops `aqi`, `category`, `color`, `method`, `name`. Only `type`, `valuePPB`, `valueUGM3` are captured.

**Source:** `docs/reference/api-docs/aeris.md` lines 329-336 (verified from Xweather docs).

### Open-Meteo — sub-indices on the wire, used for argmax then discarded

The `_OpenMeteoCurrentBlock` Pydantic model (`providers/aqi/openmeteo.py:208`) already declares all sub-AQI fields:

- **US EPA** (6 fields): `us_aqi_pm2_5`, `us_aqi_pm10`, `us_aqi_nitrogen_dioxide`, `us_aqi_ozone`, `us_aqi_sulphur_dioxide`, `us_aqi_carbon_monoxide`
- **European AQI** (5 fields — no CO in EAQI formula): `european_aqi_pm2_5`, `european_aqi_pm10`, `european_aqi_nitrogen_dioxide`, `european_aqi_ozone`, `european_aqi_sulphur_dioxide`

Both scale families work globally (not region-locked). Pre-computed server-side by Open-Meteo.

**Currently:** These fields are parsed into `_OpenMeteoCurrentBlock` but only used in `_main_pollutant_from_sub_aqis()` (line 334) for the argmax (determining dominant pollutant), then discarded. Never stored on `AQIReading`.

**Source:** `docs/reference/api-docs/openmeteo.md` lines 388-397.

### IQAir — sub-indices on the wire (paid tier), currently dropped

**Verified from real API response** (user-provided 2026-06-22, `/v2/nearest_station` endpoint, Startup tier):

```json
{
  "status": "success",
  "data": {
    "name": "St. John's",
    "city": "Mount Pearl",
    "state": "Newfoundland and Labrador",
    "country": "Canada",
    "location": { "type": "Point", "coordinates": [-52.7115, 47.56038] },
    "units": {
      "p2": "ugm3", "p1": "ugm3", "o3": "ugm3",
      "n2": "ugm3", "s2": "ugm3", "co": "ugm3",
      "pm25": "ugm3", "pm10": "ugm3"
    },
    "current": {
      "pollution": {
        "ts": "2025-09-08T07:00:00.000Z",
        "aqius": 7, "mainus": "p2",
        "aqicn": 6, "maincn": "o3",
        "p2": { "conc": 1.3, "aqius": 7, "aqicn": 2 },
        "p1": { "conc": 3.8, "aqius": 3, "aqicn": 4 },
        "o3": { "conc": 18.4, "aqius": 7, "aqicn": 6 }
      },
      "weather": {
        "ts": "2025-09-08T08:00:00.000Z",
        "ic": "04n", "hu": 97, "pr": 1016, "tp": 18,
        "wd": 225, "ws": 6.78, "heatIndex": 18
      }
    }
  }
}
```

Key facts (verified, no longer inferred):
- Per-pollutant objects keyed by code (`p2`, `p1`, `o3`, `n2`, `s2`, `co`), each with `conc`, `aqius`, `aqicn`
- **Not all 6 pollutants always present** — only those with data at the station appear
- All concentrations in µg/m³ (per `data.units` block — corrects old inference of ppb for gases)
- `data.units` block exists and declares units per pollutant code
- `data.name` field exists (station name, distinct from `data.city`)
- Free Community tier: pollution block has ONLY `ts`, `aqius`, `mainus`, `aqicn`, `maincn` — no per-pollutant objects

**Currently:** `_IQAirPollution` model (`providers/aqi/iqair.py:209`) uses `extra="ignore"` which drops all per-pollutant nested objects. All `pollutant*` canonical fields set to `None`.

**Source:** User-provided real Startup-tier API capture (2026-06-22). Previous documentation at `docs/reference/api-docs/iqair.md` was marked INFERRED; must be updated to VERIFIED.

---

## Execution model

Per `rules/clearskies-process.md` agent orchestration rules: **Opus coordinates, Sonnet implements.** Before delegating, Opus reads all relevant code and docs directly to understand what needs to change and write precise briefs. Agents get focused, single-task prompts with explicit scope blocks, reading lists, and verification commands.

### Round 1: API-side changes (one Sonnet api-dev agent)

**Pre-flight (Opus does before dispatch):**
- `git status` + `git log --oneline -1` on `repos/weewx-clearskies-api`
- Read `models/responses.py` AQIReading class
- Read all three provider modules (aeris.py, openmeteo.py, iqair.py)
- Read existing test files for all three providers
- Read test fixtures directory listing

**Agent scope — files to modify:**
- `weewx_clearskies_api/models/responses.py` — add `pollutantSubIndices` field to `AQIReading`
- `weewx_clearskies_api/providers/aqi/aeris.py` — add `aqi` field to `_AerisPollutant`, build sub-indices dict in `_wire_to_canonical()`
- `weewx_clearskies_api/providers/aqi/openmeteo.py` — build sub-indices dict in `_wire_to_canonical()` from already-parsed fields
- `weewx_clearskies_api/providers/aqi/iqair.py` — add `_IQAirPollutantData` model, add per-pollutant fields to `_IQAirPollution`, extract concentrations + sub-indices in `_wire_to_canonical()`, update CAPABILITY

**Agent scope — test files to modify:**
- `tests/providers/aqi/test_aeris.py` — assert `pollutantSubIndices` populated from fixture
- `tests/providers/aqi/test_openmeteo.py` — assert `pollutantSubIndices` populated; EAQI mode produces 5-key dict (no CO)
- `tests/providers/aqi/test_iqair.py` — add paid-tier fixture, assert concentrations + sub-indices extracted; assert free-tier fixture still returns `pollutantSubIndices=None`

**Agent scope — files to create:**
- `tests/fixtures/providers/aqi/iqair_nearest_station_startup.json` — paid-tier fixture from verified response above

**Agent scope — files NOT to touch:**
- Dashboard code (Round 2)
- Docs/manuals (Round 3)
- Any other provider module (openaq, openweathermap)

**Verification command:** `pytest tests/providers/aqi/ -v`

**QC gate (Opus after agent completes):**
1. Re-run `pytest tests/providers/aqi/ -v` independently on weather-dev
2. Spot-check: open `aeris.py`, confirm `entry.aqi` is read and stored in `sub_indices` dict
3. Spot-check: open `iqair.py`, confirm free-tier path still returns `pollutantSubIndices=None`
4. Spot-check: open `openmeteo.py`, confirm European AQI mode produces 5-key dict (no CO)
5. Verify cache round-trip: `AQIReading.model_dump()` → `AQIReading.model_validate()` preserves the dict
6. Compare commits against scope block — no files outside scope touched

### Round 2: Dashboard-side changes (one Sonnet dashboard-dev agent)

**Pre-flight (Opus does before dispatch):**
- `git status` + `git log --oneline -1` on `repos/weewx-clearskies-dashboard`
- Read `src/components/aqi-card.tsx` fully
- Read `src/api/types.ts` AQIReading interface

**Agent scope — files to modify:**
- `src/api/types.ts` — add `pollutantSubIndices` to `AQIReading` interface
- `src/components/aqi-card.tsx` — add `getPollutantDotColor` helper, update each `PollutantRow` call to use per-pollutant color

**Agent scope — files NOT to touch:**
- API code (Round 1)
- Any other component
- Mock data files (unless needed for dev testing)

**Verification command:** `npm run build` (type check + bundle)

**QC gate (Opus after agent completes):**
1. Re-run `npm run build` independently
2. Start dev server, screenshot the AQI card with mock data that has differing sub-indices
3. Verify: pollutant dots show different colors when sub-indices differ
4. Verify: when `pollutantSubIndices` is null (IQAir free tier mock), behavior is identical to today (all dots same color)
5. Verify: when a pollutant concentration is null, row does not render (no empty slots)
6. Visual side-by-side: before vs after — only dot colors should differ, layout unchanged

### Round 3: Documentation (Opus direct — mechanical, < 50 lines per file)

Opus updates docs directly (per "lead-direct for small fixes" rule):

| Document | Change |
|----------|--------|
| `docs/reference/api-docs/iqair.md` | Replace INFERRED with VERIFIED (2026-06-22). Update response example with real JSON above. Correct units to µg/m³ for all pollutants. Add `data.units` block. Note not all 6 pollutants always present. Add `data.name` field. |
| `docs/contracts/canonical-data-model.md` §3.8 | Add `pollutantSubIndices` row to AQIReading table. Update §4.2 provider mapping table. |
| `docs/contracts/openapi-v1.yaml` | Add `pollutantSubIndices` property to AQIReading schema. |
| `docs/PROVIDER-MANUAL.md` §5 | Add sub-section on per-pollutant sub-index pass-through. Update IQAir section: VERIFIED, add concentration fields, note µg/m³ units, note Startup+ requirement. |
| `docs/DASHBOARD-MANUAL.md` | Add note: AQI card dots colored per-pollutant from `pollutantSubIndices` when available; fall back to overall AQI color when absent. |
| `docs/archive/decisions/ADR-059-multi-jurisdiction-aqi.md` | Append amendment: "2026-06-22: Added `pollutantSubIndices` field — per-pollutant sub-AQI values passed through from providers." |

---

## Implementation details

### Canonical model change

Add to `AQIReading` in `models/responses.py` (after `pollutantSources`, line ~1091):

```python
pollutantSubIndices: dict[str, float | None] | None = None
```

Keys: canonical pollutant ids (`"PM2.5"`, `"PM10"`, `"O3"`, `"NO2"`, `"SO2"`, `"CO"`). Values: numeric sub-AQI on the same scale as `aqi`. `None` when provider doesn't supply (IQAir free tier, weewx Path A). Precedent: `pollutantSources` already uses this dict pattern on the same model.

### Aeris extraction (aeris.py)

Add `aqi: float | None = None` to `_AerisPollutant` (line 241). In the existing pollutant loop in `_wire_to_canonical()` (line ~483), collect `entry.aqi` into a `sub_indices` dict keyed by canonical id. Reuse `_DOMINANT_TO_CANONICAL` mapping from `entry.type.lower()`. Cap each value at 500. Pass `pollutantSubIndices=sub_indices or None` to `AQIReading()` constructor.

### Open-Meteo extraction (openmeteo.py)

In `_wire_to_canonical()` (line ~369), after `_main_pollutant_from_sub_aqis()`, iterate the active sub-AQI table (`_US_SUB_AQI_TO_POLLUTANT` or `_EUROPEAN_SUB_AQI_TO_POLLUTANT`) and build a `sub_indices` dict from the already-parsed fields on `current`. Use `getattr(current, field_name, None)`, round to int, cap at 500. Pass `pollutantSubIndices=sub_indices or None`.

### IQAir extraction (iqair.py)

Larger change — currently captures nothing per-pollutant:

1. New Pydantic model for per-pollutant data:
   ```python
   class _IQAirPollutantData(BaseModel):
       model_config = ConfigDict(extra="ignore")
       conc: float | None = None
       aqius: int | None = None
       aqicn: int | None = None
   ```

2. Add optional per-pollutant fields to `_IQAirPollution` (line 209):
   ```python
   p2: _IQAirPollutantData | None = None
   p1: _IQAirPollutantData | None = None
   o3: _IQAirPollutantData | None = None
   n2: _IQAirPollutantData | None = None
   s2: _IQAirPollutantData | None = None
   co: _IQAirPollutantData | None = None
   ```

3. Add mapping constant:
   ```python
   _CODE_TO_CANONICAL = {
       "p2": ("pollutantPM25", "PM2.5"),
       "p1": ("pollutantPM10", "PM10"),
       "o3": ("pollutantO3",   "O3"),
       "n2": ("pollutantNO2",  "NO2"),
       "s2": ("pollutantSO2",  "SO2"),
       "co": ("pollutantCO",   "CO"),
   }
   ```

4. In `_wire_to_canonical()` (line ~389), iterate codes, check `getattr(pollution, code)`, extract `conc` for concentration fields and `aqius`/`aqicn` (per `_AQI_SCALE`) for sub-indices. All concentrations are µg/m³ — no unit conversion needed.

5. Update `CAPABILITY.supplied_canonical_fields` to include `pollutantPM25`, `pollutantPM10`, `pollutantO3`, `pollutantNO2`, `pollutantSO2`, `pollutantCO` (no longer PARTIAL-DOMAIN when paid tier). Update `operator_notes` to note Startup+ requirement for concentration fields.

### Dashboard dot coloring (aqi-card.tsx)

Add helper function:
```typescript
function getPollutantDotColor(
  pollutantId: string,
  subIndices: Record<string, number | null> | null,
  scaleConfig: AQIScaleConfig,
  fallbackColor: string,
): string {
  if (!subIndices) return fallbackColor;
  const subAqi = subIndices[pollutantId];
  if (subAqi == null) return fallbackColor;
  return scaleConfig.dotColor(subAqi);
}
```

Update each `PollutantRow` call to use per-pollutant color. Fallback chain:
1. Sub-index available → `scaleConfig.dotColor(subAqi)`
2. Sub-index unavailable, overall AQI available → `scaleConfig.dotColor(overallAqi)` (same as today)
3. Neither available → neutral `#4A6A8A`

### Null-slot handling (already works)

`PollutantRow` (`aqi-card.tsx:569-570`) returns `null` when `value === null`. Providers returning fewer than 6 pollutants (e.g., IQAir station with only PM2.5, PM10, O3) show only rows for pollutants with data. No empty slots. QC gate in Round 2 step 5 explicitly verifies this.

---

## NOT in scope

- weewx Path A sub-indices (archive columns have no sub-index concept; dots use fallback)
- OpenAQ and OWM (being removed by user)
- Per-pollutant category strings (not needed — `dotColor()` works from numeric value alone)
- Replacing displayed concentrations with sub-index numbers (user wants raw concentrations)
- Computing sub-indices from breakpoint tables (Provider Manual anti-pattern #11)
