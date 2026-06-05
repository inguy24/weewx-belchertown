# Plan: Planetary Viewing Quality Index — 7Timer Integration + BFF Enrichment

**Status:** IMPLEMENTED (2026-06-04)
**Date approved:** 2026-06-04
**Parent:** C7 Almanac Page (Track C)
**Continuation prompt:** `C:\tmp\planet-viewing-quality-continuation-prompt.md`

---

## Context

The Planets card's "Good Viewing Conditions" badge and per-planet "Excellent View" / "Good View" labels are hardcoded with no logic behind them. The card is meant to be an *outlook* (forecast), not current conditions. Viewing quality depends on atmospheric seeing (upper-atmosphere turbulence), transparency (moisture/dust), cloud cover, and the planet's altitude above the horizon.

7Timer is a free, no-key-required API that provides exactly what we need: pre-computed seeing and transparency forecasts derived from the GFS model. It's widely used by amateur astronomers and astrophotographers. Its seeing index (1-8 arcseconds) captures upper-atmosphere turbulence — the dominant factor for planetary viewing — which we cannot derive from surface weather station data.

**Key design decisions (operator-directed 2026-06-04):**
- Per-planet viewing quality computed in the BFF. The API is a communications tool only.
- Remove the overall card-level "Good Viewing Conditions" indicator.
- The API delivers provider-agnostic seeing/transparency data via a new `/almanac/seeing-forecast` endpoint.
- The BFF combines seeing forecast with planet altitude to produce the final per-planet rating.
- Viewing quality is a FORECAST (outlook for tonight), not current conditions.

---

## Architecture

```
7Timer API (free, no key)
    ↓ HTTP GET (astro product, 3-hour intervals, 3-day forecast)
API (new seeing provider module)
    ↓ canonical seeing/transparency/cloud forecast
    ↓ served via new /almanac/seeing-forecast endpoint
    ↓ cached by cache warmer (3-hour TTL)
BFF (new enrichment module)
    ↓ intercepts proxied /almanac/planets response
    ↓ fetches tonight's seeing forecast from API
    ↓ for each planet: seeing + altitude + cloud gate → viewingQuality
    ↓ injects viewingQuality field into each PlanetEntry
Dashboard
    ↓ reads viewingQuality from planet data
    ↓ displays per-planet rating badge (Excellent/Good/Fair/Poor)
    ↓ no overall card-level indicator
```

**Critical architectural constraint:** The BFF currently only enriches `/current` responses. The BFF proxy must be extended to support enrichment of `/almanac/planets` responses. This modification goes in the BFF (`__main__.py` enrichment registration), NOT the API.

---

## 7Timer Data Reference

**Endpoint:** `GET http://www.7timer.info/bin/api.pl?lon={lon}&lat={lat}&product=astro&output=json`

- No API key required. No registration.
- Updates 4x daily (00, 06, 12, 18 UTC). 3-hour intervals. 3-day forecast. ~20km resolution (GFS grid).
- Non-commercial use only. Personal weather stations are fine.
- Full documentation: `docs/reference/api-docs/7timer.md`

**Response structure:**
```json
{
  "product": "astro",
  "init": "2026060412",
  "dataseries": [
    {
      "timepoint": 3,
      "cloudcover": 1,
      "seeing": 2,
      "transparency": 4,
      "lifted_index": 10,
      "rh2m": 10,
      "wind10m": { "direction": "SW", "speed": 2 },
      "temp2m": 17,
      "prec_type": "none"
    }
  ]
}
```

**Key fields:**
- `seeing` (1-8): Upper-atmosphere turbulence. 1 = perfect (<0.5"), 8 = severe (>2.5"). **Primary input (~80% weight).**
- `transparency` (1-8): Sky clarity (mag/airmass). 1 = pristine, 8 = obscured. **Minimal weight for planets (~5%)** — planets are bright enough to punch through haze.
- `cloudcover` (1-9): Octet coverage. 1 = clear (0-6%), 9 = overcast (94-100%). **Gate: if > 6, planet = "Not Visible".**
- `lifted_index`: Atmospheric stability. Positive = stable (good). Negative = convective (bad).
- `timepoint`: Hours from `init` time.
- All fields use `-9999` for undefined values.

**Seeing index interpretation:**
| Value | Arcseconds | Quality | Planetary Impact |
|-------|-----------|---------|-----------------|
| 1 | < 0.5" | Perfect | Cassini Division visible |
| 2 | 0.5" - 0.75" | Excellent | Very stable, high magnification |
| 3 | 0.75" - 1.0" | Good | Sharp features, minimal shimmer |
| 4 | 1.0" - 1.25" | Fair | Standard viewing night |
| 5 | 1.25" - 1.5" | Moderate | Planets slightly blurry |
| 6 | 1.5" - 2.0" | Poor | Boiling image, fine details lost |
| 7 | 2.0" - 2.5" | Very Poor | Heavy distortion |
| 8 | > 2.5" | Severe | Do not observe |

**Important:** 7Timer seeing measures upper-atmosphere turbulence only. It does NOT capture ground-layer seeing (telescope thermal, local terrain). The UI should label this as "Upper Atmospheric Stability" not "Seeing."

**Planetary exception for transparency:** High transparency is vital for faint deep-sky objects, but planets are so bright they can pierce poor transparency. In fact, light haze often coincides with still atmosphere = best planetary viewing. Weight transparency at <5%.

---

## Per-Planet Viewing Quality Formula

### Evaluation point

Score each planet at its **transit time** (highest altitude = least atmosphere). Also report the clear viewing window (altitude > 20° AND cloudcover ≤ 6) for the UI.

UI example: "Jupiter: Excellent (Best at 11:30 PM, clear 9 PM–2 AM)"

### Standard planets (Venus, Mars, Jupiter, Saturn, Uranus, Neptune)

**Step 1: Cloud gate**
At the transit-hour forecast point: if `cloudcover > 6` (>69%) → "Not Visible". Stop.

**Step 2: Composite score**
```
score = (seeing_score * 0.80) + (transparency_score * 0.05) + (altitude_score * 0.15)
```

**Seeing score** (from 7Timer seeing index):
| 7Timer | Score |
|--------|-------|
| 1-2    | 1.0   |
| 3      | 0.85  |
| 4      | 0.65  |
| 5      | 0.45  |
| 6      | 0.25  |
| 7-8    | 0.10  |

**Transparency score** (from 7Timer transparency index):
| 7Timer | Score |
|--------|-------|
| 1-3    | 1.0   |
| 4-5    | 0.7   |
| 6-7    | 0.3   |
| 8      | 0.1   |

**Altitude score** (from planet altitude at transit, degrees):
| Altitude | Score |
|----------|-------|
| > 45°   | 1.0   |
| 30-45°  | 0.85  |
| 20-30°  | 0.60  |
| 10-20°  | 0.30  |
| < 10°   | 0.10  |

**Step 3: Moon penalty (Uranus and Neptune ONLY)**
Bright planets (Venus, Mars, Jupiter, Saturn) are unaffected by moonlight — skip this step.

For Uranus (mag ~5.7) and Neptune (mag ~7.8): if moon illumination > 50% AND moon is within 30° angular distance of the planet → downgrade one tier (e.g., Good → Fair).

Angular distance: `acos(sin(dec1)*sin(dec2) + cos(dec1)*cos(dec2)*cos(ra1-ra2))` using planet and moon RA/Dec from Skyfield.

**Step 4: Rating**
| Score     | Rating    |
|-----------|-----------|
| >= 0.75   | Excellent |
| 0.50-0.74 | Good      |
| 0.30-0.49 | Fair      |
| < 0.30    | Poor      |

### Mercury — special case

Mercury's viewing is dominated by solar geometry, not atmospheric seeing.

**Step 1: Elongation gate**
Compute solar elongation (angular distance Mercury–Sun). If elongation < 12° → "Not Visible (In Sun's Glare)". Stop.

Best viewing occurs near Greatest Elongation (18°–28°), roughly every 3–4 months.

**Step 2: Determine apparition type**
- Eastern elongation → evening planet (visible ~40 min after sunset, western horizon)
- Western elongation → morning planet (visible ~30-45 min before sunrise, eastern horizon)

**Step 3: Score cap**
Mercury is always low on the horizon (rarely > 10°–15° altitude during twilight). Ground-layer atmospheric distortion at these altitudes makes "Excellent" essentially impossible. **Cap Mercury's maximum rating at "Good"** regardless of the seeing forecast.

**Step 4: Cloud gate + seeing**
Apply standard cloud gate and seeing score at the forecast hour nearest to the viewing window (sunset+40min or sunrise-40min). Then apply the cap.

### Conjunctions — bonus UI feature

When any planet is within 5° of the Moon, display a special badge: "Close Conjunction with Moon Tonight" — this is a positive visual highlight for casual observers, not a penalty.

---

## Implementation Tasks

### Task 1: API — 7Timer provider module

**Owner:** clearskies-api-dev (Sonnet)

**Files to create:**
- `weewx_clearskies_api/providers/seeing/__init__.py`
- `weewx_clearskies_api/providers/seeing/seven_timer.py`

**Files to modify:**
- `weewx_clearskies_api/config/settings.py` — add SeeingSettings (7Timer is default, no credentials needed)

**Spec:**
- HTTP client: `httpx` (already in deps). GET to 7Timer ASTRO endpoint with station lat/lon.
- Parse response: extract `dataseries` array, map each entry to canonical fields.
- Canonical output per time step:
  ```python
  @dataclass
  class SeeingForecastPoint:
      valid_time: datetime       # init + timepoint hours
      seeing_index: int          # 1-8
      transparency_index: int    # 1-8
      cloud_cover_octet: int     # 1-9
      lifted_index: int          # stability
      wind_speed_class: int      # 1-8
      wind_direction: str        # N/NE/E/SE/S/SW/W/NW
      temp_2m_c: int             # Celsius
      humidity_class: int        # -4 to 16
      prec_type: str             # none/rain/snow/frzr/icep
  ```
- Error handling: timeout 10s, return empty list on failure (graceful degradation)
- No credentials needed (no env vars for auth)

**Scope restrictions:** Do NOT modify existing provider modules. Do NOT touch endpoints yet.

### Task 2: API — Seeing forecast endpoint + cache warmer

**Owner:** clearskies-api-dev (Sonnet)

**Files to create:**
- `weewx_clearskies_api/endpoints/seeing.py` — new router

**Files to modify:**
- `weewx_clearskies_api/models/responses.py` — add response models
- `weewx_clearskies_api/services/cache_warmer.py` — add seeing forecast warming
- `weewx_clearskies_api/config/settings.py` — add `seeing_interval_seconds` (default 10800 = 3 hours)

**Spec:**
- Endpoint: `GET /almanac/seeing-forecast`
- Response: `{ data: { init: string, points: SeeingForecastPoint[] } }`
- Cache key: `warmer:seeing-forecast` with 3-hour TTL
- Cache warmer: call 7Timer on startup and every 3 hours
- Router registered in the almanac tags

### Task 3: BFF — Planet viewing quality enrichment

**Owner:** clearskies-realtime-dev (Sonnet)

**Files to create:**
- `weewx_clearskies_realtime/enrichment/planet_viewing.py`

**Files to modify:**
- `weewx_clearskies_realtime/__main__.py` — extend proxy to support enrichment of `/almanac/planets`, register new enrichment module

**Spec:**
- Extend BFF proxy to support enrichment of non-`/current` endpoints (currently only enriches `/current`)
- When BFF proxies `/api/v1/almanac/planets`, intercept the response
- Fetch tonight's seeing forecast from upstream `/api/v1/almanac/seeing-forecast`
- For each planet:
  1. Find forecast point closest to planet's transit time
  2. Apply cloud gate (cloudcover > 6 → "Not Visible")
  3. Compute composite score (seeing 80% + transparency 5% + altitude 15%)
  4. Apply Mercury special case (elongation gate, score cap)
  5. Apply Uranus/Neptune moon penalty
  6. Check for conjunctions (planet within 5° of Moon)
  7. Compute clear viewing window (altitude > 20° AND cloudcover ≤ 6)
  8. Inject: `viewingQuality`, `bestViewingTime`, `clearWindow`, `conjunction`
- Cache seeing forecast locally (don't re-fetch on every planets request)
- Graceful degradation: if seeing forecast unavailable, `viewingQuality = null`

### Task 4: API + Dashboard — Type updates + OpenAPI contract

**Owner:** clearskies-api-dev / clearskies-dashboard-dev (Sonnet)

**Files to modify:**
- `docs/contracts/openapi-v1.yaml` — add `/almanac/seeing-forecast` endpoint + schemas, add viewing fields to PlanetEntry
- `repos/weewx-clearskies-dashboard/src/api/openapi-v1.yaml` — sync copy
- `repos/weewx-clearskies-dashboard/src/api/types.ts` — add types
- `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py` — add response fields

### Task 5: Dashboard — Planet card viewing quality display + mockup update

**Owner:** clearskies-dashboard-dev (Sonnet) + Coordinator

**Files to modify:**
- `src/routes/almanac.tsx` — use `viewingQuality` from data instead of hardcoded text
- `docs/design/mockups/C7-almanac-page.html` — update mockup (coordinator)

**Spec:**
- Per-planet color-coded badge: Excellent (green), Good (blue), Fair (yellow), Poor (red), Not Visible (gray)
- Show best viewing time + clear window: "Excellent (Best at 11:30 PM, clear 9 PM–2 AM)"
- Conjunction badge: "Close Conjunction with Moon Tonight"
- Mercury: "Not Visible (In Sun's Glare)" when elongation < 12°
- Remove overall "Good Viewing Conditions" from card header

### Task 6: Documentation

**Owner:** Coordinator (direct)

**Files to modify:**
- `docs/planning/briefs/C7-ALMANAC-PAGE-PLAN.md` — update planets section
- `docs/ARCHITECTURE.md` — add `/almanac/seeing-forecast` endpoint, document 7Timer
- `docs/CHANGELOG.md` — log 7Timer integration

---

## Execution Order

```
Task 1 (7Timer provider) → Task 2 (endpoint + cache) → Task 3 (BFF enrichment)
                                                     → Task 4 (types + contract)
                                                     → Task 5 (dashboard + mockup)
Task 6 (docs) — runs last
```

Tasks 1 → 2 are sequential (endpoint needs the provider).
Task 3 depends on Task 2 (BFF needs the API endpoint).
Tasks 4 and 5 can overlap with Task 3.

---

## QC Gates

| Check | What to verify |
|-------|---------------|
| 7Timer response | curl the endpoint, confirm seeing/transparency/cloudcover fields parse correctly |
| Cache warmer | Log shows seeing forecast refreshed every 3 hours |
| BFF enrichment | `/api/v1/almanac/planets` response includes `viewingQuality` per planet |
| Cloud gate | When 7Timer cloudcover > 6, planet shows "Not Visible" |
| Mercury gate | When Mercury elongation < 12°, shows "Not Visible (In Sun's Glare)" |
| Mercury cap | Mercury never rated higher than "Good" |
| Uranus/Neptune moon | Downgraded when bright moon is within 30° |
| Conjunction badge | Planet within 5° of Moon gets conjunction callout |
| Altitude effect | Low-altitude planet rates lower than high-altitude |
| Best time + window | Each planet shows transit time and clear viewing window |
| Graceful degradation | When 7Timer unreachable, planets endpoint still works (viewingQuality = null) |
| No overall indicator | Card header has no "Good Viewing Conditions" badge |

---

## Prerequisite: Current repo state

As of 2026-06-04, the following commits from the C7 mockup session are deployed:

**API repo** (`weewx-clearskies-api`, main):
- `33fb5c5` — feat(almanac): add /almanac/positions endpoint for real-time sun/moon az/alt
- `eef53bf` — fix(cache): use station-local date in almanac warmer, pre-warm tomorrow

**Dashboard repo** (`weewx-clearskies-dashboard`, main):
- `a1ec596` — feat(sun-moon): add 1-minute timer to arc position markers
- `4c10e49` — feat(almanac): smart date switching — show tomorrow 2hr after sunset/moonset
- `d255f90` — feat(almanac): add useAlmanacPositions hook with 60s polling
- `05eff5a` — fix(almanac): only fetch tomorrow when today lacks the next rise
- `e953dfa` — docs(contract): sync openapi-v1.yaml with positions endpoint

**Meta repo** (`weather-belchertown`, master):
- `14681e9` — feat(mockup): C7 almanac page — full mockup with all 7 cards
- `b4c4932` — docs(contract): add /almanac/positions endpoint to OpenAPI spec

**Deploy targets:**
- API runs on **weewx** LXD container (192.168.7.20), NOT weather-dev
- Dashboard dev server runs on **weather-dev** LXD container (192.168.2.113)
- Deploy script: `scripts/redeploy-weather-dev.sh` (dashboard + BFF + config UI)
- API deploy: manual `git pull --ff-only` + `systemctl restart weewx-clearskies-api` on weewx container
