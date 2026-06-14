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

**Last verified:** 2026-04-30; 2026-06-13 (AQI multi-jurisdiction filters documented)

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

**Captured:** 2026-04-30 (initial); **updated 2026-06-13** (multi-jurisdiction filters, AQHI health object, complete response field reference from Xweather docs, changelog, and blog post)

Xweather provides **four** air quality endpoints:

| Endpoint | URL | Purpose | Time Range | Update | Cost Multiplier |
|----------|-----|---------|------------|--------|-----------------|
| `airquality` | `/airquality/{action}` | Current AQI + pollutants | Latest | 1 hour | 5x |
| `airquality/index` | `/airquality/index/{action}` | Current AQI only (simplified) | Latest | 1 hour | — |
| `airquality/forecasts` | `/airquality/forecasts/{action}` | Up to 5 days forecast | 5 days | 1 hour | — |
| `airquality/archive` | `/airquality/archive/{action}` | Historical (Jan 2024–present) | Jan 2024+ | 1 hour | 5x |

**Coverage:** Global. The API returns data for any coordinates worldwide — the `filter` parameter only affects which AQI calculation methodology is applied, not data availability.

#### Primary endpoint: `/airquality/<action>`

- **Path:** `/airquality/<action>`
- **Method:** GET
- **Required parameters:** `client_id`, `client_secret`, plus a location (either `:id` in path or `p=` query string)
- **Optional parameters:** `filter` (regional AQI methodology — see filter table below), `format` (json|geojson), `fields`
- **Supported actions:** `:id` (single location), `route` (multiple coordinates along a custom path)
- **Cost multiplier:** 5x (per Aeris docs)
- **Update interval:** 1 hour (per Aeris docs)
- **Time range:** Latest only (no history on this endpoint — use `/airquality/archive` for historical)
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

#### Filter parameter — complete list of regional AQI methods

The `filter` parameter selects which regional AQI calculation methodology to apply. Supported on the `airquality`, `airquality/forecasts`, and `airquality/archive` endpoints (NOT on `airquality/index`, which always uses AirNow/EPA).

| Filter value | AQI Standard | Region | Scale | Added |
|--------------|-------------|--------|-------|-------|
| `airnow` | US EPA AirNow AQI | United States (global default) | 0–500 | Original |
| `china` | China AQI (GB 3095-2012) | China | 0–500 | Original |
| `india` | India National AQI (CPCB) | India | 0–500 | Original |
| `eaqi` | European Air Quality Index | European Union | 6 categories (qualitative) | v1.30.0 (Aug 2023) |
| `caqi` | Common Air Quality Index | Europe (AirQualityNow) | 0–100+ | v1.30.0 (Aug 2023) |
| `uk` | UK Daily Air Quality Index (DAQI) | United Kingdom | 1–10 | v1.30.0 (Aug 2023) |
| `de` | German Luftqualitatsindex (LQI) | Germany | 5 categories (qualitative) | v1.30.0 (Aug 2023) |
| `cai` | Comprehensive Air-quality Index | South Korea | 0–500 | v1.31.0 (Oct 2023) |

**Total: 8 filter values.** There is no `canada` / `aqhi` / `australia` / `japan` / `brazil` filter. The API does NOT auto-detect the regional AQI based on coordinates — the default is always `airnow` (EPA) regardless of location. Pass `filter=` explicitly for a regional calculation.

#### Category names and scales by filter

**`airnow` (US EPA AirNow) — Default, scale 0–500:**

| AQI Range | Category |
|-----------|----------|
| 0–50 | good |
| 51–100 | moderate |
| 101–150 | usg |
| 151–200 | unhealthy |
| 201–300 | very unhealthy |
| 301–500 | hazardous |

Pollutants used: PM2.5, PM10, O3, NO2, SO2, CO. Note: Xweather returns category names in lowercase; `usg` stands for "Unhealthy for Sensitive Groups."

**`china` (China AQI) — Scale 0–500:**

| AQI Range | Category |
|-----------|----------|
| 0–50 | excellent |
| 51–100 | good |
| 101–150 | lightly polluted |
| 151–200 | moderately polluted |
| 201–300 | heavily polluted |
| 301–500 | severely polluted |

**`india` (India National AQI) — Scale 0–500:**

| AQI Range | Category |
|-----------|----------|
| 0–50 | good |
| 51–100 | satisfactory |
| 101–200 | moderately polluted |
| 201–300 | poor |
| 301–400 | very poor |
| 401–500 | severe |

**`eaqi` (European Air Quality Index) — 6 qualitative categories:**

| Category | PM2.5 (ug/m3) | PM10 (ug/m3) | O3 (ug/m3) | NO2 (ug/m3) | SO2 (ug/m3) |
|----------|---------------|--------------|------------|-------------|-------------|
| good | 0–5 | 0–15 | 0–60 | 0–10 | 0–20 |
| fair | 6–15 | 16–45 | 61–100 | 11–25 | 21–40 |
| moderate | 16–50 | 46–120 | 101–120 | 26–60 | 41–125 |
| poor | 51–90 | 121–195 | 121–160 | 61–100 | 126–190 |
| very poor | 91–140 | 196–270 | 161–180 | 101–150 | 191–275 |
| extremely poor | 140+ | 270+ | 180+ | 150+ | 275+ |

5 pollutants (no CO). Based on 1-hour averaging periods. Updated 2024 methodology aligned with 2021 WHO guidelines.

**`caqi` (Common Air Quality Index) — Scale 0–100+:**

| Index Range | Category |
|-------------|----------|
| 0–25 | very low |
| 25–50 | low |
| 50–75 | medium |
| 75–100 | high |
| >100 | very high |

Pollutants: NO2, PM10, O3, PM2.5. Defined in hourly and daily versions with separate "roadside/traffic" and "background" sub-indices.

**`uk` (UK Daily Air Quality Index — DAQI) — Scale 1–10:**

| Index Value | Band | Category |
|-------------|------|----------|
| 1–3 | Low | low |
| 4–6 | Moderate | moderate |
| 7–9 | High | high |
| 10 | Very High | very high |

Pollutants: NO2, SO2, O3, PM2.5, PM10.

**`de` (German Luftqualitatsindex — LQI) — 5 qualitative categories:**

| Category | PM10 (ug/m3) | PM2.5 (ug/m3) | O3 (ug/m3) | NO2 (ug/m3) | SO2 (ug/m3) |
|----------|-------------|---------------|------------|-------------|-------------|
| very good | 0–9 | 0–5 | 0–24 | 0–10 | 0–10 |
| good | 10–27 | 6–15 | 24–72 | 11–30 | 11–30 |
| moderate | 28–54 | 16–30 | 73–144 | 31–60 | 31–60 |
| poor | 55–90 | 31–50 | 145–240 | 61–100 | 61–100 |
| very poor | >90 | >50 | >240 | >100 | >100 |

Based on hourly means. Source: German Environment Agency (UBA).

**`cai` (South Korea Comprehensive Air-quality Index) — Scale 0–500:**

| CAI Range | Category |
|-----------|----------|
| 0–50 | good |
| 51–100 | moderate |
| 101–250 | unhealthy |
| 251–500 | very unhealthy |

Pollutants: PM2.5, PM10, CO, SO2, NO2, O3.

#### Response field reference

**Top-level response object:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string/null | Station identifier (often null for interpolated data) |
| `loc.lat` | number | Latitude |
| `loc.long` | number | Longitude |
| `place.name` | string | Location name |
| `place.state` | string/null | State/province abbreviation (null for many countries) |
| `place.country` | string | ISO-3166 2-letter country code |
| `periods` | array | Array of observation/forecast periods |
| `profile.tz` | string | IANA timezone name |
| `profile.sources` | array | Data source attribution array |
| `profile.stations` | array | Station IDs used for interpolation |

**Period object (within `periods[]`):**

| Field | Type | Description |
|-------|------|-------------|
| `dateTimeISO` | string | ISO 8601 timestamp |
| `timestamp` | number | Unix timestamp |
| `aqi` | number | Air Quality Index value (scale depends on filter) |
| `category` | string | Category name (lowercase, filter-specific — see scales above) |
| `color` | string | Hex color code for the category |
| `method` | string | Calculation method used (matches filter value) |
| `dominant` | string | Dominant pollutant id (e.g., `pm2.5`, `o3`, `no2`) |
| `health` | object | Air Quality Health Index (AQHI) — global, independent of filter |
| `health.index` | number | AQHI value on 0–20 scale |
| `health.category` | string | AQHI category: `low`, `moderate`, `high`, `very high` |
| `health.color` | string | Hex color for AQHI category |
| `pollutants` | array | Per-pollutant breakdown (see below) |

**Pollutant object (within `pollutants[]`):**

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Pollutant abbreviation: `co`, `no2`, `o3`, `pm1`, `pm10`, `pm2.5`, `so2` |
| `name` | string | Full name (e.g., "Carbon Monoxide", "PM2.5", "Ozone") |
| `valuePPB` | number/null | Concentration in parts per billion (null for particulates) |
| `valueUGM3` | number/null | Concentration in micrograms per cubic meter |
| `aqi` | number | Per-pollutant AQI value |
| `category` | string | Per-pollutant category (same scale as period-level) |
| `color` | string | Hex color for per-pollutant category |
| `method` | string | Calculation method (matches filter) |

**How the response shape changes with different filters:** The JSON **structure** is identical regardless of filter. What changes: `aqi` (recalculated per regional breakpoints), `category` (uses regional names), `color` (regional color scheme), `method` (reflects filter used). The raw pollutant concentration values (`valuePPB`, `valueUGM3`) do NOT change. For qualitative scales (EAQI, German LQI) that lack a 0–500 numeric index, the behavior of the `aqi` field is unclear from documentation.

#### Air Quality Health Index (AQHI)

Added in v1.32.0 (November 2023). Available on `airquality`, `airquality/forecasts`, and `airquality/archive` endpoints.

The AQHI is a **separate, global metric** returned **in addition to** the filter-specific AQI. It appears in every response regardless of which `filter` is used.

| AQHI Value | Category | Description |
|------------|----------|-------------|
| 0–3 | low | Low health risk |
| 4–6 | moderate | Moderate health risk |
| 7–10 | high | High health risk |
| >10 (up to 20) | very high | Very high health risk |

**Note:** This is NOT the same as Canada's AQHI (which goes 1–10+). Xweather's implementation extends to 0–20 and uses its own category scheme. There is no `canada` / `aqhi` filter value.

#### Pollutants returned (all endpoints)

| `type` | `name` | `valuePPB` | `valueUGM3` | Notes |
|--------|--------|-----------|-------------|-------|
| `co` | Carbon Monoxide | Yes | Yes | Gas |
| `no2` | Nitrogen Dioxide | Yes | Yes | Gas |
| `o3` | Ozone | Yes | Yes | Gas |
| `pm1` | Particle Matter (<1um) | null | Yes | Particulate — not part of most AQI scales |
| `pm2.5` | PM2.5 | null | Yes | Particulate |
| `pm10` | PM10 | null | Yes | Particulate |
| `so2` | Sulfur Dioxide | Yes | Yes | Gas |

**Total: 7 pollutants**, always returned regardless of filter. The set does NOT change by filter. NOT returned: NO (Nitrogen Monoxide — blog mentions it for map layers, not API), NH3 (Ammonia), Pb (Lead). `pm1` is returned but not part of any standard AQI scale — dropped during canonical translation.

#### Other air quality endpoints

**`airquality/index` (simplified):** Returns ONLY AQI value, category, and color — no pollutant breakdown, no health index. Always uses EPA AirNow calculations. Does NOT support the `filter` parameter.

**`airquality/forecasts`:** Up to 5 days of daily and hourly forecast data. Supports all filter values. Response shape identical to `airquality` but with multiple periods. Forecast model updated every 3 hours (v1.27.0).

**`airquality/archive`:** Historical data from January 2024 to present. Up to 24 hours per request. Supports all filter values. Cost multiplier 5x. Use `from=`/`to=` parameters.

#### Coverage recommendations by geography

| Region | Recommended filter | Notes |
|--------|-------------------|-------|
| United States | `airnow` (default) | EPA AQI, most familiar to US users |
| China | `china` | Chinese AQI standard (GB 3095-2012) |
| India | `india` | CPCB National AQI |
| European Union | `eaqi` | European Air Quality Index (EEA) |
| Europe (general) | `caqi` | Common Air Quality Index (AirQualityNow) |
| United Kingdom | `uk` | DEFRA Daily Air Quality Index (DAQI) |
| Germany | `de` | UBA Luftqualitatsindex (LQI) |
| South Korea | `cai` | Comprehensive Air-quality Index |
| Canada | `airnow` | No Canada-specific filter; AQHI returned globally via `health` |
| All other | `airnow` | Default EPA methodology |

#### Changelog — air quality related entries

| Version | Date | Changes |
|---------|------|---------|
| 1.9.0 | 2018-04-24 | New `airquality` endpoint (global observations); New `airquality/forecasts` (BETA) |
| 1.26.0 | 2023-04-03 | Ignoring QA value on station reporting inaccurate carbon monoxide |
| 1.27.0 | 2023-05-10 | Integrate Vaisala Xweather high-resolution global AQ forecast model (updated every 3 hours) |
| 1.30.0 | 2023-08-07 | New AQ calculations: UK, DE, EAQI, CAQI; initial AQ Add-on support |
| 1.31.0 | 2023-10-02 | New `airquality/index` support; CAI (South Korea) calculation added |
| 1.32.0 | 2023-11-20 | New Air Quality Health Index (AQHI) on `airquality` and `airquality/forecasts` |
| 1.34.0 | 2024-02-07 | Improvements for regional calculations |

#### Wire-shape notes (relevant to canonical mapping)

- `pollutants` is an **ARRAY** of typed objects, NOT an object keyed by pollutant name. Filter by `type` (lowercase, with dot for `pm2.5`) to extract each canonical pollutant.
- Gas pollutants (`o3`, `no2`, `so2`, `co`) supply BOTH `valuePPB` (parts per billion) AND `valueUGM3` (micrograms per cubic meter). Particulates (`pm2.5`, `pm10`, `pm1`) supply only `valueUGM3` (PPB is `null`).
- Aeris's `periods[].category` is lowercase with `usg` abbreviation (`good | moderate | usg | unhealthy | very unhealthy | hazardous`); canonical `AQIReading.aqiCategory` is Title Case full names. The Aeris module derives `aqiCategory` client-side via `epa_category(aqi)` for consistency with Open-Meteo's pattern (deterministic, single source of truth).
- Aeris's `periods[].dominant` is the lowercase pollutant id (`pm2.5`, `pm10`, `o3`, `no2`, `so2`, `co`); the Aeris module normalizes to canonical ids (`PM2.5`, `PM10`, `O3`, `NO2`, `SO2`, `CO`).
- Aeris also supports `pm1` (particles < 1um) in `pollutants[]`; canonical `AQIReading` has no `pollutantPM1` field, so this pollutant is dropped during translation.
- `filter=airnow` requests US EPA AQI methodology (Aeris's default). Canonical/ADR-013 lock the 0–500 EPA scale, so the Aeris module passes `filter=airnow` explicitly for determinism.
- `aqiLocation` is supplied by Aeris via `place.name` (NOT PARTIAL-DOMAIN).

#### Documentation gaps and uncertainties

- **Exact filter strings for `de` and `cai`:** Almost certainly lowercase (matching `uk` pattern) but not 100% confirmed via live API call.
- **Numeric AQI for qualitative scales:** For EAQI (6 categories) and German LQI (5 categories), it is unclear whether the `aqi` field returns a synthesized numeric value or null.
- **CAQI scale >100:** The standard allows values above 100 ("very high"). Handling of the open-ended upper range in the `aqi` field is unclear.
- **Cost/tier for regional filters:** Whether regional filters require a specific plan tier or add-on is not documented.
- **Free-tier vs. paid-tier field restrictions** not documented (no obvious omissions in the schema).
- **HTTP error codes specific to this endpoint** not enumerated separately — falls back to common Aeris status codes documented above.
- **Plan/tier requirements for endpoint access** not stated.

### Raster Maps (radar)

**Provenance:** Written 2026-05-11 from upstream documentation (https://www.xweather.com/docs/maps/getting-started/map-tiles; AerisWeather rebranded to Xweather mid-2025). **NOT live-verified at brief-draft time.** Test-author should capture a live tile response during fixture work and surface any divergence per `rules/clearskies-process.md` "api-docs file provenance is part of the cross-check."

Aeris exposes radar mosaic + many other weather layers as XYZ slippy-map raster tiles via the Maps API (formerly "AerisWeather Maps," now "Xweather Raster Maps"). Day-1 layer per [ADR-015](../../decisions/ADR-015-radar-map-tiles-strategy.md) is `radar` — global radar mosaic.

#### Tile URL template

```
https://maps.api.xweather.com/{client_id}_{client_secret}/{layers}/{z}/{x}/{y}/{offset}.png
```

- `{client_id}_{client_secret}` — credentials embedded in the URL **path**, joined by an underscore. This is structurally different from every other Aeris endpoint (which use query-string auth) and creates a logging-leak risk — see §3 lead-call LC-E in the round brief.
- `{layers}` — one or comma-separated; Clear Skies day-1 uses `radar`. Other useful layers: `flat` (basemap), `admin` (boundaries), `radar-global` (alias) — but day-1 sticks to plain `radar`.
- `{z}` / `{x}` / `{y}` — slippy-map zoom + tile coordinates. Normal range 1-21.
- `{offset}` — time offset. `current` for latest; documented relative-offset syntax (`-5min`, `-10min`, `-15min`, etc.) for past frames. Verbatim list of supported offsets not on the getting-started page; check the Time Offsets reference page during fixture capture.

#### Tile content type

`image/png`. Transparent background; meant to overlay on a basemap.

#### Time-stepping

**Supported** via the `{offset}` URL segment. Past frames at 5-min increments are typical for the radar mosaic. For Clear Skies v0.1 the tile proxy always passes `current` (time-step animation is a Phase-2 feature beyond this round — see brief LC-7). The `?t` query parameter on the proxy is accepted but ignored at v0.1; future round can wire it to `{offset}`.

For `/radar/providers/aeris/frames`, the api returns a single-entry list with `kind=current` (parity with OWM). The frame index can be extended in a later round to call Aeris's `/info` or `/maps/img` endpoints if Aeris exposes past-frame timestamps.

#### Authentication / tier gating

- Credentials live in the URL **path**, not the query string — `{client_id}_{client_secret}` joined by underscore.
- The **AerisWeather Contributor Plan** (free tier, granted via PWSWeather membership at https://pwsweather.com/contribute) bundles Maps API access. Operators who contribute their PWS data to PWSWeather get a client_id + client_secret pair usable across all Aeris endpoints, including the radar tiles documented here.
- **NOT live-verified during brief-draft** — confirm Contributor-Plan Maps access still includes the radar mosaic during fixture capture. If access is gated to a paid plan, brief assumptions need to flip and the round closes with a documented "free-path unavailable" finding.
- 401/403 → canonical `KeyInvalid`; 429 → `QuotaExhausted` with `Retry-After`.

#### Rate limits

Aeris Maps API plan-tier-conditional. Contributor Plan limits not documented on the page captured; operator pays via the Aeris portal for higher tiers if needed. Polling cost is bounded by ADR-017 tile cache (300s default).

#### Logging-leak risk (security baseline)

The path-embedded credential pattern is the only Aeris endpoint that puts secrets in the URL itself (other endpoints use query-string auth, which the `logging.Filter` redaction layer per ADR-029 already strips). The radar provider module **must** redact the path credential before any URL is logged. See brief LC-E.

#### Known gotchas

- **Layer name conventions can shift.** The page captured today uses `radar`; older Aeris docs reference `radar:global`. Brief assumption locks `radar`; cross-check at fixture time.
- **`{offset}` syntax not enumerated in full** on the captured page; check Time Offsets reference page during fixture capture.
- **The base URL is `maps.api.xweather.com`** (rebrand from `maps.api.aerisapi.com`). Confirm during live capture that the rebrand is server-side complete; some old docs still cite the aerisapi.com domain.

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

### Convective Outlook (storm risk)

**Captured:** 2026-06-03 via https://www.xweather.com/docs/weather-api/endpoints/convective-outlook/

**Coverage:** Continental US only. Up to Day 8.

**Endpoint:** `GET https://data.api.xweather.com/convective/outlook/{location}?client_id=...&client_secret=...`

Actions: `:id` (location query), `affects`, `contains`, `search`.

**Response:** Array of outlook objects, one per risk type per day:

```
response[].details.product     → "convective"
response[].details.category    → outlook category
response[].details.day         → 1–8
response[].details.risk.type   → "general" | "tornado" | "hail" | "wind"
response[].details.risk.name   → SPC full risk name
response[].details.risk.code   → numeric risk level (see scales below)
response[].details.range.minTimestamp / maxTimestamp
response[].details.range.minDateTimeISO / maxDateTimeISO
response[].details.issuedTimestamp / issuedDateTimeISO
response[].geoPoly             → GeoJSON polygon (null when no geo filter / no risk)
```

**Risk code scales:**

| Type    | 0    | 1   | 2        | 4   | 5   | 6        | 8        | 10  | 15  | 30  | 45  | 60  |
|---------|------|-----|----------|-----|-----|----------|----------|-----|-----|-----|-----|-----|
| general | None | Gen | Marginal |     |     | Enhanced | Moderate |     |     |     |     |     |
| general |      |     |          | Slt |     |          |          | Hgh |     |     |     |     |
| tornado | None |     | 2%       |     | 5%  |          |          | 10% | 15% | 30% | 45% | 60% |
| hail    | None |     |          |     | 5%  |          |          |     | 15% | 30% | 45% | 60% |
| wind    | None |     |          |     | 5%  |          |          |     | 15% | 30% | 45% | 60% |

**Canonical mapping (for clearskies-api):**
- `thunderRisk` ← `risk.code` where `risk.type === "general"` (0–10 scale)
- `tornadoRisk` ← `risk.code` where `risk.type === "tornado"` (0–60, percentage)
- `hailRisk` ← `risk.code` where `risk.type === "hail"` (0–60, percentage)
- `windRisk` ← `risk.code` where `risk.type === "wind"` (0–60, percentage)

Match to DailyForecastPoint by comparing `details.day` to the forecast day index.

## Known issues / gotchas

- `client_id`/`client_secret` are bound to a registered namespace (domain or bundle ID) — server-side calls from an unregistered host will be rejected.
- The base host is `data.api.xweather.com` (NOT `api.aerisapi.com` from older docs — that host still resolves but the current canonical name is the xweather one).
- `/alerts` returns latest alerts only. For history use the (separate) archive endpoints.
- `/conditions` with `filter=minutelyprecip` covers max 60 minutes ahead.
- The same physical product is sold under both "AerisWeather" and "Xweather" branding; account dashboards may use either name.
