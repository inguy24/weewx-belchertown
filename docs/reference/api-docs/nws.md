# National Weather Service (NWS) — API Reference

**Source:**
- https://www.weather.gov/documentation/services-web-api
- https://api.weather.gov/openapi.json (full OpenAPI 3 spec — large, do not embed)

**Last verified:** 2026-04-30

## Authentication

**No API key.** The service is free, public, and unmetered (subject to a non-public rate limit, see below).

A `User-Agent` header **is required** and must identify your application. Per the docs: "This string can be anything, and the more unique to your application the less likely it will be affected by a security event." Including a contact (URL or email) is recommended.

### Example HTTP request

```
GET /points/47.6062,-122.3321 HTTP/1.1
Host: api.weather.gov
User-Agent: (clearskies-weewx, contact@example.com)
Accept: application/geo+json
```

Curl:

```
curl -H "User-Agent: (clearskies-weewx, contact@example.com)" \
     -H "Accept: application/geo+json" \
     "https://api.weather.gov/points/47.6062,-122.3321"
```

If `User-Agent` is missing, requests may be blocked.

## Base URL

```
https://api.weather.gov
```

## Endpoints

The NWS forecast workflow is two-step:

1. Call `/points/{lat},{lon}` to discover the WFO (weather forecast office), grid X, grid Y, and the observation station list for a location.
2. Call the forecast endpoints under `/gridpoints/{office}/{gridX},{gridY}/...` and the latest observation under `/stations/{stationId}/observations/latest`.

### Point lookup

- **Path:** `/points/{latitude},{longitude}`
- **Method:** GET
- **Required parameters:** `latitude` and `longitude` in the path (decimal degrees, comma-separated, max 4 decimals).
- **Optional parameters:** None.
- **Example request:**
  ```
  curl -H "User-Agent: (clearskies, contact@example.com)" \
       "https://api.weather.gov/points/47.6062,-122.3321"
  ```
- **Example response (truncated):**
  ```json
  {
    "@context": [...],
    "id": "https://api.weather.gov/points/47.6062,-122.3321",
    "type": "Feature",
    "geometry": { "type": "Point", "coordinates": [-122.3321, 47.6062] },
    "properties": {
      "@id": "https://api.weather.gov/points/47.6062,-122.3321",
      "@type": "wx:Point",
      "cwa": "SEW",
      "gridId": "SEW",
      "gridX": 124,
      "gridY": 67,
      "forecast":      "https://api.weather.gov/gridpoints/SEW/124,67/forecast",
      "forecastHourly":"https://api.weather.gov/gridpoints/SEW/124,67/forecast/hourly",
      "forecastGridData":"https://api.weather.gov/gridpoints/SEW/124,67",
      "observationStations":"https://api.weather.gov/gridpoints/SEW/124,67/stations",
      "relativeLocation": {
        "type": "Feature",
        "geometry": { "type": "Point", "coordinates": [-122.33, 47.60] },
        "properties": { "city": "Seattle", "state": "WA",
                        "distance": { "value": 0, "unitCode": "wmoUnit:m" },
                        "bearing":  { "value": 0, "unitCode": "wmoUnit:degree_(angle)" } }
      },
      "forecastZone": "https://api.weather.gov/zones/forecast/WAZ001",
      "county":       "https://api.weather.gov/zones/county/WAC033",
      "fireWeatherZone":"https://api.weather.gov/zones/fire/WAZ001",
      "timeZone": "America/Los_Angeles",
      "radarStation": "KATX"
    }
  }
  ```
- **Notes:** `gridId`/`gridX`/`gridY` are the inputs to the forecast endpoints. The mapping is stable but can change occasionally — the docs explicitly recommend periodic re-resolution.

### Latest observation from a station

- **Path:** `/stations/{stationId}/observations/latest`
- **Method:** GET
- **Required parameters:** `stationId` in path (e.g. `KSEA`). Discover via `/gridpoints/{office}/{gridX},{gridY}/stations` or `/points/{lat},{lon}` then follow `observationStations`.
- **Optional parameters:** `require_qc=true` to exclude non-QC observations.
- **Example request:**
  ```
  curl -H "User-Agent: (clearskies, contact@example.com)" \
       "https://api.weather.gov/stations/KSEA/observations/latest"
  ```
- **Example response (truncated):**
  ```json
  {
    "type": "Feature",
    "geometry": { "type": "Point", "coordinates": [-122.31, 47.45] },
    "properties": {
      "@id": "https://api.weather.gov/stations/KSEA/observations/2026-04-30T17:53:00+00:00",
      "station": "https://api.weather.gov/stations/KSEA",
      "timestamp": "2026-04-30T17:53:00+00:00",
      "rawMessage": "KSEA 301753Z ...",
      "textDescription": "Mostly Cloudy",
      "icon": "https://api.weather.gov/icons/land/day/bkn?size=medium",
      "presentWeather": [],
      "temperature":          { "unitCode": "wmoUnit:degC", "value": 12.2,  "qualityControl": "V" },
      "dewpoint":             { "unitCode": "wmoUnit:degC", "value": 8.3,   "qualityControl": "V" },
      "windDirection":        { "unitCode": "wmoUnit:degree_(angle)",     "value": 220 },
      "windSpeed":            { "unitCode": "wmoUnit:km_h-1",             "value": 14.5 },
      "windGust":             { "unitCode": "wmoUnit:km_h-1",             "value": null },
      "barometricPressure":   { "unitCode": "wmoUnit:Pa",                 "value": 101510 },
      "seaLevelPressure":     { "unitCode": "wmoUnit:Pa",                 "value": 101830 },
      "visibility":           { "unitCode": "wmoUnit:m",                  "value": 16093 },
      "relativeHumidity":     { "unitCode": "wmoUnit:percent",            "value": 76 },
      "windChill":            { "unitCode": "wmoUnit:degC", "value": null },
      "heatIndex":            { "unitCode": "wmoUnit:degC", "value": null },
      "cloudLayers": [
        { "base": { "unitCode": "wmoUnit:m", "value": 1830 }, "amount": "BKN" }
      ]
    }
  }
  ```
- **Notes:**
  - All values are wrapped in `{unitCode, value, qualityControl}` triples. `unitCode` follows the WMO unit ontology (e.g. `wmoUnit:degC`, `wmoUnit:km_h-1`, `wmoUnit:Pa`).
  - Observation data may be delayed up to 20 minutes due to upstream MADIS QC processing.
  - `value` may be `null` when the station did not report or the value was QC-rejected.

### 7-day forecast (12-hour periods)

- **Path:** `/gridpoints/{office}/{gridX},{gridY}/forecast`
- **Method:** GET
- **Required parameters:** `office`, `gridX`, `gridY` in path (from `/points`).
- **Optional parameters:** `units=us|si` (default `us`), `Feature-Flags` header.
- **Example request:**
  ```
  curl -H "User-Agent: (clearskies, contact@example.com)" \
       "https://api.weather.gov/gridpoints/SEW/124,67/forecast"
  ```
- **Example response (truncated):**
  ```json
  {
    "type": "Feature",
    "properties": {
      "updated": "2026-04-30T15:00:00+00:00",
      "units": "us",
      "forecastGenerator": "BaselineForecastGenerator",
      "generatedAt": "2026-04-30T17:00:00+00:00",
      "updateTime": "2026-04-30T15:00:00+00:00",
      "validTimes": "2026-04-30T09:00:00+00:00/P7DT16H",
      "elevation": { "unitCode": "wmoUnit:m", "value": 53 },
      "periods": [
        {
          "number": 1,
          "name": "This Afternoon",
          "startTime": "2026-04-30T13:00:00-07:00",
          "endTime":   "2026-04-30T18:00:00-07:00",
          "isDaytime": true,
          "temperature": 64,
          "temperatureUnit": "F",
          "temperatureTrend": null,
          "probabilityOfPrecipitation": { "unitCode": "wmoUnit:percent", "value": 20 },
          "windSpeed": "5 to 10 mph",
          "windDirection": "SW",
          "icon": "https://api.weather.gov/icons/land/day/sct?size=medium",
          "shortForecast": "Mostly Sunny",
          "detailedForecast": "Mostly sunny, with a high near 64..."
        }
      ]
    }
  }
  ```
- **Notes:** Periods alternate day/night; usually 14 periods covering 7 days. `windSpeed` is a *string range* like `"5 to 10 mph"`, not a number — parse accordingly.

### Hourly forecast

- **Path:** `/gridpoints/{office}/{gridX},{gridY}/forecast/hourly`
- **Method:** GET
- **Same parameters as /forecast.**
- **Example response shape:** Same envelope as `/forecast`, but each `periods[]` entry is a 1-hour slot, `temperature` is numeric, and `windSpeed` is a single value string like `"7 mph"`.
- **Notes:** ~156 hourly periods (about 7 days). Available out to ~7 days.

### Active alerts

- **Path:** `/alerts/active`
- **Method:** GET
- **Required parameters:** None.
- **Optional parameters:**
  - `area=<state-or-marine-area>` (e.g. `WA`, `CA`)
  - `point=<lat>,<lon>`
  - `region=<land|marine>`
  - `region_type=land|marine`
  - `zone=<zoneId>`
  - `urgency=Immediate|Expected|Future|Past|Unknown`
  - `severity=Extreme|Severe|Moderate|Minor|Unknown`
  - `certainty=Observed|Likely|Possible|Unlikely|Unknown`
  - `event=<event-name>`
  - `limit=<n>`
- **Example request:**
  ```
  curl -H "User-Agent: (clearskies, contact@example.com)" \
       "https://api.weather.gov/alerts/active?point=47.6062,-122.3321"
  ```
- **Example response (truncated):**
  ```json
  {
    "type": "FeatureCollection",
    "features": [
      {
        "id": "urn:oid:2.49.0.1.840.0.abc...",
        "type": "Feature",
        "geometry": { "type": "Polygon", "coordinates": [...] },
        "properties": {
          "id": "urn:oid:2.49.0.1.840.0.abc...",
          "areaDesc": "King, WA",
          "sent":    "2026-04-30T16:00:00-07:00",
          "effective":"2026-04-30T16:00:00-07:00",
          "onset":   "2026-04-30T18:00:00-07:00",
          "expires": "2026-04-30T22:00:00-07:00",
          "ends":    "2026-04-30T22:00:00-07:00",
          "status":   "Actual",
          "messageType":"Alert",
          "category": "Met",
          "severity": "Moderate",
          "certainty":"Likely",
          "urgency":  "Expected",
          "event":    "Wind Advisory",
          "sender":   "w-nws.webmaster@noaa.gov",
          "senderName":"NWS Seattle WA",
          "headline": "Wind Advisory issued April 30 ...",
          "description": "* WHAT...Southerly winds 20 to 30 mph ...",
          "instruction": "Use extra caution when driving ...",
          "response":  "Execute"
        }
      }
    ],
    "title": "Current watches, warnings, and advisories ...",
    "updated": "2026-04-30T17:00:00+00:00"
  }
  ```
- **Notes:** Alerts are 7 days available. Coverage: US states, territories, and adjacent marine zones. Use `point=` for lat/lon-targeted queries.

## Other notable endpoints (not detailed here)

Captured for reference; full schemas live in `https://api.weather.gov/openapi.json`:

- `/gridpoints/{office}/{gridX},{gridY}` — raw forecast grid (richer parameter set, time-series-of-everything)
- `/gridpoints/{office}/{gridX},{gridY}/stations` — stations list for a grid
- `/stations/{stationId}` — station metadata
- `/stations/{stationId}/observations` — observation history (paginated)
- `/zones/{type}/{zoneId}` — zone metadata
- `/products` / `/products/types` — text products (AFD, etc.)
- `/radar/stations` / `/radar/stations/{stationId}` — radar metadata only (NOT imagery)
- `/glossary`

## Rate limits

- Documented as: "The rate limit is not public information, but allows a generous amount for typical use."
- HTTP error returned when exceeded; per docs, retry after roughly 5 seconds.
- Direct client requests are less likely to trip the limit than aggregating proxies.

## Response format conventions

- **Default Content-Type:** `application/geo+json` (GeoJSON FeatureCollection or Feature).
- **Alternative formats** via `Accept` header:
  - `application/ld+json` — JSON-LD
  - `application/vnd.noaa.dwml+xml` — DWML
  - `application/vnd.noaa.obs+xml` — OXML
  - `application/cap+xml` — CAP (alerts)
  - `application/atom+xml` — Atom
- **Timestamps:** ISO-8601, usually with timezone offset.
- **Units:** Observation values use the `{unitCode, value, qualityControl}` envelope with WMO unit codes. Forecast endpoints accept `units=us|si` and embed unit strings inline (e.g. `temperatureUnit: "F"`, `windSpeed: "5 to 10 mph"`).
- **Quality control:** observation `qualityControl` flags include `V` (validated), `Z` (preliminary), `S` (subjective good), `C` (coarse), `B` (rejected), etc.

## Known issues / gotchas

- **`User-Agent` is mandatory.** Requests without one are blocked.
- **Forecast `windSpeed` is a string range** (`"5 to 10 mph"`) — do not assume numeric.
- **Grid coordinates can change.** Re-call `/points` periodically; cached `gridId`/`gridX`/`gridY` may stop returning data without warning.
- **Observation lag** up to ~20 minutes from upstream MADIS QC.
- **Coverage is US, US territories, and adjacent marine zones only.** No international forecasts.
- **Radar endpoints expose status only,** not display-ready imagery.
- **No API key.** Identify yourself via `User-Agent`. Including contact info reduces the risk of getting blocked during an abuse incident.
- **OpenAPI spec is large** (multi-MB). Don't embed; reference it from code as `https://api.weather.gov/openapi.json`.
