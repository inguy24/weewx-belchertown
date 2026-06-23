# IQAir AirVisual — API Reference

**Source:**
- https://api-docs.iqair.com/ (official docs root — JS-rendered SPA; not directly fetchable)
- https://www.iqair.com/support/knowledge-base/access-airvisuals-aqi-air-quality-and-pollution-api (KB)
- https://www.iqair.com/in-en/air-pollution-data-api/plans (tier comparison)
- https://github.com/bachya/pyairvisual (well-maintained Python client; used by Home Assistant — definitive auth + error-code evidence)
- https://github.com/initialstate/airvisual/wiki/AirVisual-API (third-party wiki; definitive endpoint shape)

**Last verified:** 2026-05-11 (IQAir api-docs SPA blocks WebFetch + WWW pages were rate-limiting at draft time; cross-validated against pyairvisual source code + multiple example-response sources. Paid-tier wire shape NOT verified at draft; flagged inline.); 2026-06-13 (AQI scale coverage confirmed US+China only; paid-tier fields documented)

## Authentication

API key passed as the **query parameter `key`** on every request. **No header auth** — verified against pyairvisual source (`kwargs["params"]["key"] = self._api_key`). The v2 API does NOT use an `X-Key` HTTP header despite occasional third-party suggestions; only the query-param form is documented and used by the canonical clients.

Keys are tied to a subscription plan (Community / Startup / Enterprise / etc.). The plan tier gates which fields appear in responses, not which endpoints are reachable — every plan can call `/v2/nearest_city`, but free Community responses omit per-pollutant concentrations.

### Example HTTP request

```
GET /v2/nearest_city?lat=47.6062&lon=-122.3321&key=YOUR_KEY HTTP/1.1
Host: api.airvisual.com
```

Curl:

```
curl "https://api.airvisual.com/v2/nearest_city?lat=47.6062&lon=-122.3321&key=$IQAIR_KEY"
```

## Base URL

- v2:  `https://api.airvisual.com/v2/`

## Endpoints

### Nearest city by GPS (in scope)

- **Path:** `/v2/nearest_city`
- **Method:** GET
- **Required parameters:**
  - `key` — API key (query param)
  - `lat`, `lon` — GPS coordinates (both required together; if absent, IQAir falls back to IP-based geolocation, which we don't want for a fixed-station deployment)
- **Optional parameters:** none documented
- **Example request:**
  ```
  curl "https://api.airvisual.com/v2/nearest_city?lat=36.1767&lon=-86.7386&key=$IQAIR_KEY"
  ```
- **Example response (Community / free tier):**
  ```json
  {
    "status": "success",
    "data": {
      "city": "Nashville",
      "state": "Tennessee",
      "country": "USA",
      "location": {
        "type": "Point",
        "coordinates": [-86.7386, 36.1767]
      },
      "current": {
        "weather": {
          "ts": "2019-04-08T19:00:00.000Z",
          "tp": 18,
          "hu": 88,
          "pr": 1012,
          "wd": 90,
          "ws": 3.1,
          "ic": "04d"
        },
        "pollution": {
          "ts": "2019-04-08T18:00:00.000Z",
          "aqius": 10,
          "mainus": "p2",
          "aqicn": 3,
          "maincn": "p2"
        }
      }
    }
  }
  ```
- **Field details:**
  - `status` — envelope discriminator. `"success"` for valid responses; `"fail"` for errors (see `## Error envelope` below).
  - `data.city`, `data.state`, `data.country` — string place labels (e.g. `"Nashville"` + `"Tennessee"` + `"USA"`).
  - `data.location.coordinates` — **GeoJSON Point order: `[longitude, latitude]`**, NOT `[lat, lon]`. Important if anything reads this back; we use the lat/lon we sent on the request.
  - `data.current.weather.*` — current weather snapshot. Fields: `ts` (ISO-8601 UTC ms), `tp` (temperature °C), `hu` (humidity %), `pr` (pressure hPa), `wd` (wind direction degrees), `ws` (wind speed m/s), `ic` (icon code like `04d`). Not in scope for the AQI canonical mapping.
  - `data.current.pollution.ts` — observation timestamp, ISO-8601 UTC with milliseconds and `Z` suffix (e.g. `"2019-04-08T18:00:00.000Z"`). Distinct from `weather.ts` — the two timestamps may differ by an hour or more; the pollution one is what `observedAt` should map to.
  - `data.current.pollution.aqius` — **US EPA AQI value (0–500 scale)**, integer. This is the value canonical `aqi` reads. **No conversion needed** — IQAir publishes the EPA AQI directly (distinct from OWM Air Pollution which uses a 1–5 ordinal scale).
  - `data.current.pollution.mainus` — dominant pollutant code in the US AQI scale. String like `"p2"`. See pollutant-code lookup below.
  - `data.current.pollution.aqicn` — China AQI value. Not used by canonical (we use US AQI).
  - `data.current.pollution.maincn` — dominant pollutant code in the China AQI scale. Not used by canonical.
- **Free tier (`Community` plan) limitation: `pollution` block contains ONLY `ts`, `aqius`, `mainus`, `aqicn`, `maincn`. No per-pollutant concentration fields (no `pm25`, `pm10`, `o3`, `no2`, `so2`, `co`).** Per IQAir's plans page, pollutant concentrations are added on the `Startup` plan and above. Wire-shape field names for paid-tier concentrations NOT verified at draft time — likely `data.current.pollution.{pm25, pm10, o3, no2, so2, co}` based on naming convention, but real-capture or paid-tier sidecar evidence is the gate.

### Other endpoints (out of scope for v0.1)

| Endpoint | Path | Notes |
|---|---|---|
| Nearest station by GPS | `/v2/nearest_station` | Same shape; closest known measurement station rather than nearest city aggregate. |
| City lookup by name | `/v2/city?city=&state=&country=` | Requires explicit place strings. |
| Station lookup by name | `/v2/station?station=&city=&state=&country=` | Requires explicit place + station strings. |
| City ranking | `/v2/city_ranking` | Top 10 most/least polluted cities globally; no location params. |
| Countries / states / cities | `/v2/countries`, `/v2/states`, `/v2/cities` | Reference lookups; not data. |

## AQI scales supported

**Confirmed (2026-06-13): IQAir Cloud API v2 returns ONLY TWO AQI scales.** Every response, regardless of which country the station/city is in, returns both `aqius` (US EPA AQI) and `aqicn` (China MEP AQI). There is no `aqieu` field. There is no European CAQI. There is no Canadian AQHI. There is no Indian NAQI.

Evidence:
- IQAir's own AQI KB article says "Both US and Chinese AQI systems are available on the AirVisual app and Node." No other scales mentioned.
- IQAir's commercial API plans page says "Overall AQI (US & China)" across all three tiers (Community, Startup, Enterprise).
- The Microsoft Power Platform Connector schema lists exactly `aqius` and `aqicn` — no other AQI fields.
- Home Assistant sensor.py configures `aqi{locale}` where locale is `"cn"` or `"us"` only.
- Homebridge plugin `aqi_standard` accepts `"us"` or `"cn"` only.

**Scales NOT returned (must compute client-side from concentrations if needed):**
- European CAQI (Common Air Quality Index, 0–100)
- Canadian AQHI (Air Quality Health Index, 1–10+)
- Indian NAQI (National Air Quality Index, 0–500)
- UK DAQI (Daily Air Quality Index, 1–10)
- Australian AQI

### US EPA AQI (`aqius`) — scale 0–500

| Range | Category |
|-------|----------|
| 0–50 | Good |
| 51–100 | Moderate |
| 101–150 | Unhealthy for Sensitive Groups |
| 151–200 | Unhealthy |
| 201–300 | Very Unhealthy |
| 301–500 | Hazardous |

Computed from six criteria pollutants: PM2.5, PM10, O3, NO2, SO2, CO. IQAir states the US EPA scale "yields higher scores for AQI's under 200" compared to the Chinese scale.

### China MEP AQI (`aqicn`) — scale 0–500

| Range | Category |
|-------|----------|
| 0–50 | Excellent |
| 51–100 | Good |
| 101–150 | Lightly Polluted |
| 151–200 | Moderately Polluted |
| 201–300 | Heavily Polluted |
| 301–500 | Severely Polluted |

"Results of these two functions differ only in AQI scores of 200 and below" (IQAir KB). Above 200, US EPA and China MEP scales produce identical values.

## Pollutant code lookup (`mainus` / `maincn`)

| Code | Pollutant | Canonical id |
|---|---|---|
| `p1` | PM10 | `PM10` |
| `p2` | PM2.5 | `PM2.5` |
| `n2` | NO2 | `NO2` |
| `o3` | O3 | `O3` |
| `s2` | SO2 | `SO2` |
| `co` | CO | `CO` |

Confirmation status: `p2` confirmed via published examples, Pro Device API docs, Home Assistant, Homebridge, and multiple third-party docs. `p1` confirmed via Pro Device API docs (field `p1_sum`) and Home Assistant sensor definitions. `n2`, `o3`, `s2`, `co` confirmed via Home Assistant sensor.py pollutant unit mappings and Pro Device API docs.

## Pollutant concentration fields (paid tiers)

**Captured:** 2026-06-22. Status: **VERIFIED** — confirmed from a real Startup-tier API response (`/v2/nearest_station` endpoint) provided by the user.

On Startup and Enterprise tiers, each pollutant appears as a nested object inside `data.current.pollution`:

```json
"p2": {
  "conc": 1.3,
  "aqius": 7,
  "aqicn": 2
}
```

Fields per pollutant object:
- `conc` — Concentration value in µg/m³ (numeric)
- `aqius` — Per-pollutant US EPA AQI sub-index (integer)
- `aqicn` — Per-pollutant China MEP AQI sub-index (integer)

**Not all 6 pollutants always present** — only those with data at the station appear. The verified response contained only `p2`, `p1`, `o3` (3 of 6).

### Concentration units

All concentrations are µg/m³. Verified from `data.units` block in the real Startup-tier response:

```json
"units": {
  "p2": "ugm3", "p1": "ugm3", "o3": "ugm3",
  "n2": "ugm3", "s2": "ugm3", "co": "ugm3",
  "pm25": "ugm3", "pm10": "ugm3"
}
```

| Code | Pollutant | Unit |
|------|-----------|------|
| `p1` | PM10 | µg/m³ |
| `p2` | PM2.5 | µg/m³ |
| `o3` | O3 | µg/m³ |
| `n2` | NO2 | µg/m³ |
| `s2` | SO2 | µg/m³ |
| `co` | CO | µg/m³ |

**Correction (2026-06-22):** Previous INFERRED version (from Home Assistant sensor.py) listed gas units as ppb/ppm. The real `data.units` block confirms **all pollutants are µg/m³**, including gases. No unit conversion is needed in the provider module.

### Verified Startup-tier response shape

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

Additional verified fields not present in the earlier INFERRED version:
- `data.name` — station name (distinct from `data.city`)
- `data.units` — declares units per pollutant code (all µg/m³)
- Free Community tier: pollution block has ONLY `ts`, `aqius`, `mainus`, `aqicn`, `maincn` — no per-pollutant objects

### Available pollutants per tier

| Tier | Pollutant concentrations available |
|------|-----------------------------------|
| Community (Free) | **NONE** — only aggregate AQI + main pollutant code |
| Startup | PM2.5, PM10, O3, NO2, SO2, CO |
| Enterprise | PM2.5, PM10, O3, NO2, SO2, CO (+ forecasts & history) |

### Plan tiers & rate limits

| Tier | Calls/min | Calls/day | Calls/month | Extra data |
|------|-----------|-----------|-------------|------------|
| Community (Free) | 5 | 500 | 10,000 | City-level AQI only |
| Startup | 100 | 100,000 | 1,000,000 | + Station-level + pollutant concentrations |
| Enterprise | 1,000 | 1,000,000 | 10,000,000 | + 7-day forecast + 48h history + city ranking |

## Rate limits (Community / free plan)

- **5 calls per minute**
- **500 calls per day**
- **10,000 calls per month**

With the canonical 15-minute cache TTL (per ADR-017 AQI domain), a single station polling continuously calls IQAir at most ~96 times/day — well within all three limits. The per-minute cap is the most restrictive when multiple cache misses cluster (cold start, cache backend reset, etc.).

Higher tiers (Startup, Enterprise) raise these caps; exact figures depend on plan and aren't published in stable form.

## Error envelope

IQAir uses a **200-success-false envelope** pattern (same shape as Aeris — see [aeris.md](aeris.md)). The HTTP status code MAY be set per error class but the envelope `status` field is the primary discriminator that pyairvisual and the official docs dispatch on.

**Success:**
```json
{ "status": "success", "data": { ... } }
```

**Error:**
```json
{ "status": "fail", "data": { "message": "<error_string>" } }
```

Known error message strings (from pyairvisual `cloud_api.py` `ERROR_CODES` dispatch table):

| Message string | Maps to | Likely HTTP status |
|---|---|---|
| `incorrect_api_key` | invalid key | 401 |
| `api_key_expired` | expired key | 401 |
| `call_limit_reached` | quota exceeded | 429 |
| `too_many_requests` | rate-limit exceeded | 429 |
| `permission_denied` | unauthorized | 403 |
| `forbidden` | unauthorized | 403 |
| `feature_not_available` | tier-gated feature | 403 |
| `city_not_found` | no city for coords | 404 |
| `no_nearest_station` | no station near coords | 404 |
| `node not found` | (Pro device only) | 404 |
| `payment required` | subscription lapsed | 402 |

The HTTP status mapping above is best-guess — pyairvisual dispatches solely on the envelope message and ignores the status. Real-capture during error scenarios is the gate for confirming the HTTP-status-vs-envelope alignment.

## Response format conventions

- **Default format:** JSON. No alternative formats.
- **Times:** ISO-8601 with milliseconds and `Z` suffix (e.g. `2019-04-08T18:00:00.000Z`). UTC. Two timestamps in the response — `current.weather.ts` and `current.pollution.ts` — may differ; the pollution one is authoritative for `observedAt`.
- **Coordinates:** GeoJSON Point order `[longitude, latitude]`. Not `[lat, lon]`.
- **Units:** Weather block uses metric (°C, hPa, m/s). Not in scope for AQI canonical mapping.
- **AQI scale:** US EPA 0–500 directly. No conversion needed (distinct from OWM 1–5 ordinal).

## Known issues / gotchas

- **Auth is query-param `key=`, NOT header `X-Key`.** Despite occasional third-party suggestions to the contrary, the v2 API documents and the canonical clients use query-param exclusively.
- **Free Community tier does NOT expose pollutant concentrations.** `data.current.pollution` contains only `ts`/`aqius`/`mainus`/`aqicn`/`maincn`. Canonical `pollutantPM25`/`pollutantPM10`/`pollutantO3`/`pollutantNO2`/`pollutantSO2`/`pollutantCO` are PARTIAL-DOMAIN on free tier — categorical absence (the data isn't there at any time on this tier), not tier-conditional null.
- **EPA AQI is published directly.** No EPA-breakpoint computation needed for the `aqi` field on the IQAir path (distinct from OWM and Open-Meteo, both of which compute sub-AQIs from concentrations).
- **`mainus` is a code, not a category label.** Map to canonical pollutant id via the lookup table; do NOT assume `mainus` is a human-readable category.
- **`aqiCategory` derives from the AQI value, not from `mainus`.** Use `epa_category(aqi)` per LC13 single-source-of-truth pattern, mirroring aeris.py / openmeteo.py / openweathermap.py — `mainus` is the dominant pollutant id, not the category.
- **`location.coordinates` is GeoJSON `[lon, lat]`.** Not `[lat, lon]`. We use the lat/lon we sent on the request, so this only matters if anything ever reads it back.
- **`status` field is the primary error discriminator, not HTTP status.** A response can be HTTP 200 with `status: fail` in the body (LC27 precedent applies — same envelope-mapping pattern as Aeris). Wire validation must check `status` before consuming `data`.
- **Two timestamps in the response.** `weather.ts` and `pollution.ts` may differ by an hour or more (different upstream sources). For canonical `observedAt`, use `pollution.ts`.
- **City/state/country are strings as-is.** `data.city = "Nashville"`, `data.state = "Tennessee"`. Concatenation order for canonical `aqiLocation` is an operationalization question (`"Nashville, Tennessee"` vs `"Nashville TN"` vs `"Nashville/TN"`) — surface in the brief.
- **Paid-tier wire-shape inferred but not live-captured.** Per the "Pollutant concentration fields (paid tiers)" section above (added 2026-06-13), the Startup/Enterprise response likely uses `{ conc, aqius, aqicn }` nested objects keyed by pollutant code (`p2`, `p1`, `o3`, `n2`, `s2`, `co`). This is inferred from the AirVisual Pro Device API and client library implementations. A real API capture from a Startup-tier key remains the definitive gate. Units are likely: ug/m3 for particles, ppb for gases (NO2, O3, SO2), ppm for CO — per Home Assistant sensor.py mappings.
