# IQAir AirVisual — API Reference

**Source:**
- https://api-docs.iqair.com/ (official docs root — JS-rendered SPA; not directly fetchable)
- https://www.iqair.com/support/knowledge-base/access-airvisuals-aqi-air-quality-and-pollution-api (KB)
- https://www.iqair.com/in-en/air-pollution-data-api/plans (tier comparison)
- https://github.com/bachya/pyairvisual (well-maintained Python client; used by Home Assistant — definitive auth + error-code evidence)
- https://github.com/initialstate/airvisual/wiki/AirVisual-API (third-party wiki; definitive endpoint shape)

**Last verified:** 2026-05-11 (IQAir api-docs SPA blocks WebFetch + WWW pages were rate-limiting at draft time; cross-validated against pyairvisual source code + multiple example-response sources. Paid-tier wire shape NOT verified at draft; flagged inline.)

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

## Pollutant code lookup (`mainus` / `maincn`)

| Code | Pollutant | Canonical id |
|---|---|---|
| `p1` | PM10 | `PM10` |
| `p2` | PM2.5 | `PM2.5` |
| `n2` | NO2 | `NO2` |
| `o3` | O3 | `O3` |
| `s2` | SO2 | `SO2` |
| `co` | CO | `CO` |

The first three (`p1`, `p2`, `n2`) are confirmed via published examples and third-party documentation. `o3`, `s2`, `co` are inferred from naming conventions consistent with the IQAir AirVisual Pro device data export (where `p1_sum` / `p2_sum` are documented). One source rendered `co` as `c0` (likely OCR error from a similar-looking glyph); treat as `co` until real-capture says otherwise. **Real-capture should verify** — if a captured response surfaces `mainus = "co"` or `"o3"` or `"s2"`, the lookup is confirmed. If a different code appears, this table needs amendment.

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
- **Paid-tier wire-shape unverified at draft.** If/when paid-tier credentials become available, capture a real response and confirm: do PM2.5/PM10/O3/NO2/SO2/CO appear under `data.current.pollution.*` with field names `pm25`/`pm10`/`o3`/`no2`/`so2`/`co`? In what units (µg/m³ for all, like OWM? or ppb for gases, like Aeris?)? Current draft is conservative — CAPABILITY enumerates only the fields confirmed on free-tier wire.
