# Aeris (AerisWeather / Xweather) — API Reference

**Source:**
- https://www.xweather.com/docs/weather-api/getting-started/authentication
- https://www.xweather.com/docs/weather-api/getting-started/responses
- https://www.xweather.com/docs/weather-api/getting-started/queries
- https://www.xweather.com/docs/weather-api/endpoints
- https://www.xweather.com/docs/weather-api/endpoints/observations
- https://www.xweather.com/docs/weather-api/endpoints/conditions
- https://www.xweather.com/docs/weather-api/endpoints/forecasts
- https://www.xweather.com/docs/weather-api/endpoints/alerts

**Last verified:** 2026-04-30

## Authentication

OAuth 2.0 "userless access" model. Two credentials are issued at app registration:

- `client_id`
- `client_secret`

Both are passed as **query parameters** on every request. No header auth, no signed token, no exchange step.

Each `client_id`/`client_secret` pair is bound to a namespace recorded at registration time:

- Web app: top-level domain (e.g. `mydomain.com` or `*.mydomain.com`)
- Mobile app: bundle identifier (e.g. `com.mydomain.MyProject`)

The API validates that the calling host/identifier matches before responding.

### Example HTTP request

```
GET https://data.api.xweather.com/observations/seattle,wa?client_id=ABC123&client_secret=SECRETXYZ HTTP/1.1
Host: data.api.xweather.com
```

Curl:

```
curl "https://data.api.xweather.com/observations/seattle,wa?client_id=$AERIS_ID&client_secret=$AERIS_SECRET"
```

## Base URL

```
https://data.api.xweather.com/
```

HTTP and HTTPS are both supported. Use HTTPS in production.

## Endpoints

All endpoints use a path of the form `/<endpoint>/<action>` where `<action>` is one of:

- `:id` — single location identifier (city name, `lat,long`, US/CA postal code, station ID, etc.)
- `closest` — results ordered by distance from a reference point (uses `p=`)
- `within` — circle or polygon area search
- `search` — generalized action; behavior driven by query parameters
- `route` — multiple coordinates along a custom path

### Current observations

- **Path:** `/observations/<action>`
- **Method:** GET
- **Required parameters:** `client_id`, `client_secret`, plus a location specifier (either `:id` in path or `p=` query string)
- **Optional parameters:** `format` (json|geojson), `filter`, `limit`, `fields`, `query`, `sort`
- **Example request:**
  ```
  curl "https://data.api.xweather.com/observations/seattle,wa?client_id=$ID&client_secret=$SECRET"
  ```
- **Example response (truncated):**
  ```json
  {
    "success": true,
    "error": null,
    "response": {
      "id": "KSEA",
      "dataSource": "madis-metar",
      "loc": { "lat": 47.45, "long": -122.31 },
      "place": { "name": "seattle", "state": "wa", "country": "us" },
      "profile": { "tz": "America/Los_Angeles", "elevM": 132, "elevFT": 433 },
      "ob": {
        "timestamp": 1714485600,
        "dateTimeISO": "2026-04-30T10:00:00-07:00",
        "tempC": 12.0, "tempF": 53.6,
        "dewpointC": 8.0, "dewpointF": 46.4,
        "humidity": 76,
        "pressureMB": 1015, "pressureIN": 29.97,
        "spressureMB": 999, "spressureIN": 29.50,
        "altimeterMB": 1015, "altimeterIN": 29.97,
        "windSpeedKTS": 6, "windSpeedKPH": 11, "windSpeedMPH": 7, "windSpeedMPS": 3.1,
        "windDirDEG": 220, "windDir": "SW",
        "windGustKTS": null, "windGustKPH": null, "windGustMPH": null,
        "weather": "Mostly Cloudy", "weatherShort": "Mostly Cloudy",
        "weatherCoded": "::OVC", "weatherPrimary": "Mostly Cloudy", "weatherPrimaryCoded": "::OVC",
        "cloudsCoded": "OV", "icon": "cloudy.png",
        "visibilityKM": 16.09, "visibilityMI": 10.0,
        "ceilingFT": 8500, "ceilingM": 2591,
        "sky": 88,
        "uvi": null,
        "feelslikeC": 12.0, "feelslikeF": 53.6,
        "heatindexC": null, "windchillC": null,
        "precipMM": 0, "precipIN": 0,
        "snowDepthCM": null, "snowDepthIN": null,
        "solradWM2": 240,
        "QC": "OK", "QCcode": 10, "trustFactor": 95,
        "isDay": true,
        "sunrise": 1714477200, "sunriseISO": "2026-04-30T06:00:00-07:00",
        "sunset": 1714528800, "sunsetISO": "2026-04-30T20:20:00-07:00"
      }
    }
  }
  ```
- **Notes:**
  - Sources include METARs from airports, MADIS, and personal weather stations.
  - Station update cadence varies 1–60+ minutes.
  - Quality code `QCcode` values: `0` failed, `1` caution, `3` probation, `7` questioned, `10` OK.
  - Both metric and imperial fields are returned in the same payload — no `units=` switch needed.

### Conditions (current / past / future, hourly intervals)

- **Path:** `/conditions/<action>`
- **Method:** GET
- **Required parameters:** `client_id`, `client_secret`, location
- **Optional parameters:** `for=<timestamp>` (single point in time), `from=`/`to=` (range, returns hourly increments), `filter=minutelyprecip` (1-minute precipitation up to 60 minutes ahead), `format`, `fields`
- **Example request:**
  ```
  curl "https://data.api.xweather.com/conditions/47.6,-122.3?from=now&to=+12hours&client_id=$ID&client_secret=$SECRET"
  ```
- **Example response (truncated):**
  ```json
  {
    "success": true,
    "response": [{
      "loc": { "lat": 47.6, "long": -122.3 },
      "periods": [
        {
          "timestamp": 1714485600,
          "dateTimeISO": "2026-04-30T10:00:00-07:00",
          "tempC": 12.5, "tempF": 54.5,
          "feelslikeC": 12.5, "feelslikeF": 54.5,
          "dewpointC": 8.0, "dewpointF": 46.4,
          "humidity": 74,
          "pressureMB": 1015, "pressureIN": 29.97,
          "windDir": "SW", "windDirDEG": 220,
          "windSpeedKTS": 6, "windSpeedKPH": 11, "windSpeedMPH": 7, "windSpeedMPS": 3.1,
          "windGustKTS": 12, "windGustKPH": 22, "windGustMPH": 14, "windGustMPS": 6.1,
          "precipMM": 0, "precipIN": 0,
          "snowCM": 0, "snowIN": 0,
          "snowDepthCM": 0, "snowDepthIN": 0,
          "pop": 10,
          "weather": "Mostly Cloudy", "weatherCoded": "::OVC",
          "weatherPrimary": "Mostly Cloudy", "icon": "cloudy.png",
          "visibilityKM": 16, "visibilityMI": 10,
          "sky": 88, "uvi": 3, "isDay": true
        }
      ]
    }]
  }
  ```
- **Notes:**
  - Coverage range: 2004 to +15 days.
  - Historical hourly data extends back to January 2004.

### Forecasts

- **Path:** `/forecasts/<action>`
- **Method:** GET
- **Required parameters:** `client_id`, `client_secret`, location
- **Optional parameters:**
  - `filter=` controls interval. Documented values include `1hr`, `daynight`, `day`, `mdnt2mdnt`.
  - `limit=` number of forecast periods to return.
  - `plimit=` periods per place when querying multiple places.
  - `fields=` reduce returned fields.
  - `from=`/`to=` time range.
- **Example request:**
  ```
  curl "https://data.api.xweather.com/forecasts/seattle,wa?filter=daynight&limit=14&client_id=$ID&client_secret=$SECRET"
  ```
- **Example response (truncated):**
  ```json
  {
    "success": true,
    "response": [{
      "loc": { "long": -122.33, "lat": 47.6 },
      "place": { "name": "seattle", "state": "wa", "country": "us" },
      "profile": { "tz": "America/Los_Angeles", "elevFT": 175, "elevM": 53 },
      "interval": "day",
      "periods": [
        {
          "timestamp": 1714492800,
          "dateTimeISO": "2026-04-30T12:00:00-07:00",
          "maxTempC": 18, "maxTempF": 64,
          "minTempC": 9, "minTempF": 48,
          "avgTempC": 13, "avgTempF": 56,
          "tempC": 18, "tempF": 64,
          "maxFeelslikeF": 64, "minFeelslikeF": 48,
          "maxDewpointF": 50, "minDewpointF": 42,
          "humidity": 70, "maxHumidity": 90, "minHumidity": 50,
          "pop": 20,
          "precipMM": 0, "precipIN": 0,
          "snowCM": 0, "snowIN": 0,
          "iceaccumMM": 0, "iceaccumIN": 0,
          "windSpeedKTS": 8, "windSpeedKPH": 15, "windSpeedMPH": 9, "windSpeedMPS": 4.1,
          "windDir": "WSW", "windDirDEG": 250,
          "windGustMPH": 18,
          "pressureMB": 1015, "pressureIN": 29.97,
          "sky": 60, "cloudsCoded": "BK",
          "weather": "Partly Cloudy", "weatherPrimary": "Partly Cloudy",
          "weatherPrimaryCoded": "::SCT", "icon": "pcloudy.png",
          "uvi": 6,
          "solradWM2": 5800, "solradMaxWM2": 720, "solradMinWM2": 0, "solradClearSkyWM2": 6500,
          "visibilityKM": 16, "visibilityMI": 10,
          "sunrise": 1714477200, "sunriseISO": "2026-04-30T06:00:00-07:00",
          "sunset": 1714528800, "sunsetISO": "2026-04-30T20:20:00-07:00",
          "isDay": true,
          "wetBulbGlobeTempC": 16, "wetBulbGlobeTempF": 60
        }
      ]
    }]
  }
  ```
- **Notes:** Forecast data extends to +15 days. Updates hourly. Solar fields include `ghi`, `dni`, `dhi`, plus 80m-height wind variants in some plans.

### Alerts

- **Path:** `/alerts/<action>`
- **Method:** GET
- **Required parameters:** `client_id`, `client_secret`, location
- **Optional parameters:** `format` (json|geojson), `filter`, `limit`, `fields`
- **Example request:**
  ```
  curl "https://data.api.xweather.com/alerts/seattle,wa?client_id=$ID&client_secret=$SECRET"
  ```
- **Example response (truncated):**
  ```json
  {
    "success": true,
    "response": [{
      "id": "alert-12345",
      "dataSource": "NWS",
      "loc": { "lat": 47.6, "long": -122.3 },
      "active": true,
      "details": {
        "type": "WIN",
        "name": "Wind Advisory",
        "loc": "WAZ001",
        "priority": 60,
        "color": "AAAA00",
        "body": "Strong winds expected..."
      },
      "timestamps": {
        "issued": 1714480000, "issuedISO": "2026-04-30T08:00:00Z",
        "begins":  1714485600, "beginsISO":  "2026-04-30T10:00:00Z",
        "expires": 1714521600, "expiresISO": "2026-04-30T20:00:00Z",
        "updated": 1714480500, "updatedISO": "2026-04-30T08:08:20Z"
      },
      "includes": {
        "fips": ["53033"],
        "counties": ["King"],
        "wxzones":  ["WAZ001"],
        "zipcodes": [98101, 98102]
      },
      "place": { "name": "seattle", "state": "wa", "country": "us" },
      "geoPoly": { "type": "Polygon", "coordinates": [...] },
      "localLanguages": []
    }]
  }
  ```
- **Notes:** Coverage spans India, Brazil, South Africa, South Korea, Mexico, Japan, US, Canada, Europe, and Australia. Near-real-time updates. Latest data only (no history).

### Alerts summary

- **Path:** `/alerts/summary/<action>`
- **Method:** GET
- **Purpose:** Summary of active weather events across covered regions.
- **Required parameters:** `client_id`, `client_secret`
- **Notes:** Same auth pattern as `/alerts`. Returns aggregated counts/types rather than individual alert objects.

### Air Quality

- **Path:** `/airquality/<action>`
- **Method:** GET
- **Required parameters:** `client_id`, `client_secret`, plus a location (either `:id` in path or `p=` query string)
- **Optional parameters:** `filter` (`airnow` US EPA — default / `china` / `india` — selects AQI methodology), `format` (json|geojson), `fields`
- **Supported actions:** `:id` (single location), `route` (multiple coordinates along a custom path)
- **Cost multiplier:** 5x (per Aeris docs)
- **Update interval:** 1 hour (per Aeris docs)
- **Time range:** Latest only (no history on this endpoint)
- **Example request:**
  ```
  curl "https://data.api.xweather.com/airquality/47.6,-122.3?filter=airnow&client_id=$ID&client_secret=$SECRET"
  ```
- **Example response (truncated):**
  ```json
  {
    "success": true,
    "error": null,
    "response": [{
      "id": null,
      "loc": { "lat": 47.6, "long": -122.3 },
      "place": { "name": "seattle", "state": "wa", "country": "us" },
      "periods": [
        {
          "dateTimeISO": "2026-04-30T10:00:00-07:00",
          "timestamp": 1714485600,
          "aqi": 42,
          "category": "good",
          "color": "00E400",
          "method": "airnow",
          "dominant": "pm2.5",
          "health": { "index": 3, "category": "low", "color": "00E400" },
          "pollutants": [
            { "type": "pm2.5", "name": "PM2.5",            "valuePPB": null,  "valueUGM3": 8.5,   "aqi": 42, "category": "good", "color": "00E400", "method": "airnow" },
            { "type": "pm10",  "name": "PM10",             "valuePPB": null,  "valueUGM3": 12.0,  "aqi": 11, "category": "good", "color": "00E400", "method": "airnow" },
            { "type": "o3",    "name": "Ozone",            "valuePPB": 32.1,  "valueUGM3": 64.5,  "aqi": 30, "category": "good", "color": "00E400", "method": "airnow" },
            { "type": "no2",   "name": "Nitrogen Dioxide", "valuePPB": 5.3,   "valueUGM3": 9.9,   "aqi": 5,  "category": "good", "color": "00E400", "method": "airnow" },
            { "type": "so2",   "name": "Sulfur Dioxide",   "valuePPB": 1.2,   "valueUGM3": 3.1,   "aqi": 2,  "category": "good", "color": "00E400", "method": "airnow" },
            { "type": "co",    "name": "Carbon Monoxide",  "valuePPB": 150.0, "valueUGM3": 172.0, "aqi": 2,  "category": "good", "color": "00E400", "method": "airnow" }
          ]
        }
      ],
      "profile": { "tz": "America/Los_Angeles", "sources": [{ "name": "..." }], "stations": [] }
    }]
  }
  ```
- **Wire-shape notes (relevant to canonical §4.2 aeris mapping):**
  - `pollutants` is an **ARRAY** of typed objects, NOT an object keyed by pollutant name. Filter by `type` (lowercase, with dot for `pm2.5`) to extract each canonical pollutant.
  - Gas pollutants (`o3`, `no2`, `so2`, `co`) supply BOTH `valuePPB` (parts per billion) AND `valueUGM3` (micrograms per cubic meter). Particulates (`pm2.5`, `pm10`, `pm1`) supply only `valueUGM3` (PPB is `null`).
  - Aeris's `periods[].category` is lowercase with `usg` abbreviation (`good | moderate | usg | unhealthy | very unhealthy | hazardous`); canonical `AQIReading.aqiCategory` is Title Case full names. The Aeris module derives `aqiCategory` client-side via `epa_category(aqi)` for consistency with Open-Meteo's pattern (deterministic, single source of truth).
  - Aeris's `periods[].dominant` is the lowercase pollutant id (`pm2.5`, `pm10`, `o3`, `no2`, `so2`, `co`); the Aeris module normalizes to canonical ids (`PM2.5`, `PM10`, `O3`, `NO2`, `SO2`, `CO`).
  - Aeris also supports `pm1` (particles < 1µm) in `pollutants[]`; canonical `AQIReading` has no `pollutantPM1` field, so this pollutant is dropped during translation.
  - `filter=airnow` requests US EPA AQI methodology (Aeris's default). Canonical/ADR-013 lock the 0–500 EPA scale, so the Aeris module passes `filter=airnow` explicitly for determinism.
  - `aqiLocation` is supplied by Aeris via `place.name` (NOT PARTIAL-DOMAIN).
- **Documentation gaps** (from the public docs page):
  - Free-tier vs. paid-tier field restrictions not documented (no obvious omissions in the schema).
  - HTTP error codes specific to this endpoint not enumerated separately — falls back to the common Aeris status codes documented above.
  - Plan/tier requirements for endpoint access not stated.

## Common query parameters (all endpoints)

- `p=<location>` — place; alternative to passing the location in the path
- `format=json|geojson` — response format
- `filter=<filter-name>` — endpoint-specific filter (e.g. `1hr`, `daynight` on `/forecasts`)
- `limit=<n>` — maximum results
- `plimit=<n>` — limit per place (multi-place queries)
- `fields=<csv>` — restrict returned fields
- `query=<expr>` — advanced query expressions:
  - `name:seattle,state:wa` — string equality
  - `,` joins as AND, `;` as OR
  - `!` prefix = not-equal; `^` prefix = starts-with
  - `>=` and `<=` for numeric range
  - `property:NULL` and `property:!NULL` supported
- `sort=<field:asc|desc>`
- `skip=<n>` — pagination offset
- `from=<time>` / `to=<time>` — time range; accepts unix timestamps and relative values (`now`, `+12hours`, `-1day`)

## Rate limits

- Limits depend on the subscribed plan; not enumerated in the public docs page reviewed.
- HTTP `429` returned when exceeded.
- Cost-tracking response headers:
  - `X-Cost-Endpoint` — endpoint queried
  - `X-Cost-Tokens` — total request cost
  - `X-Cost-Multiplier` — per-multiplier breakdown (endpoint, spatial, temporal)

## Response format conventions

All responses share a common envelope:

```json
{
  "success": true,
  "error": null,
  "response": [ ... ]   // array OR object depending on action
}
```

- For `:id` (single-location) actions, `response` is a single object.
- The `/forecasts` endpoint always returns an array regardless of action.
- On error: `success=false`, `error={code, description}`, `response=[]`.
- On warning: `success=true`, `error={code, description}` is set alongside results.

### HTTP status codes

| Code  | Meaning                       |
|-------|-------------------------------|
| 200   | OK (may include warnings)     |
| 401   | Invalid credentials           |
| 404   | Endpoint not found            |
| 429   | Rate limit exceeded           |
| 5xx   | Server error                  |

### Common error / warning codes

- `invalid_location`
- `invalid_query`
- `insufficient_scope`
- `maxhits_min` (rate limits)
- `warn_location` (incomplete address)
- `warn_invalid_param` (improper parameter use)

### Units

Both metric and imperial fields are returned in the same payload (e.g. `tempC` and `tempF`, `windSpeedKPH` and `windSpeedMPH`). The client picks which to read; there is no global `units=` switch.

## Known issues / gotchas

- `client_id`/`client_secret` are bound to a registered namespace (domain or bundle ID) — server-side calls from an unregistered host will be rejected.
- The base host is `data.api.xweather.com` (NOT `api.aerisapi.com` from older docs — that host still resolves but the current canonical name is the xweather one).
- `/alerts` returns latest alerts only. For history use the (separate) archive endpoints.
- `/conditions` with `filter=minutelyprecip` covers max 60 minutes ahead.
- The same physical product is sold under both "AerisWeather" and "Xweather" branding; account dashboards may use either name.
