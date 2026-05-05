# Weather Underground (The Weather Company / api.weather.com) — API Reference

**Source:**
- https://www.wunderground.com/member/api-keys (key issuance, refers to a Google Doc — see below)
- https://www.wunderground.com/about/data (data sources overview)
- https://apicommunity.wunderground.com/ (community forum; live status varied during research)
- Google Doc: https://docs.google.com/document/d/1eKCnKXI9xnoMGRRzOL1xPCBihNV2rOet08qpE_gArAY/edit ("APIs for Personal Weather Station Contributors") — **gated, requires login as a PWS contributor.** This is the canonical doc.
- Community/library references for endpoint shapes:
  - https://github.com/gablau/weather-underground-node
  - https://github.com/MarcoBuster/WUndergroundPWS-API

**Last verified:** 2026-04-30

> **GATING NOTICE:** Weather Underground retired its public REST API in 2018. The current API at `api.weather.com` is restricted: a key is issued only to **Personal Weather Station (PWS) contributors** (people who upload data from their own station). The formal endpoint contract is published only inside the gated Google Doc linked above. The information below is reconstructed from publicly visible community usage and known-good URLs; an end user with PWS access **must** retrieve the canonical Google Doc and verify parameter names, response field names, and quotas during Phase 2 implementation.

## Authentication

API key passed as the **query parameter `apiKey`** on every request. No header auth.

To obtain a key:

1. Register a personal weather station at https://www.wunderground.com/pws/overview
2. Once the station is uploading data, navigate to https://www.wunderground.com/member/api-keys
3. The page issues a key intended for personal/non-commercial use of the PWS endpoints

Keys are gated by the requirement to operate an active PWS. Without one, the dashboard does not surface a key.

### Example HTTP request

```
GET /v2/pws/observations/current?stationId=KMAHANOV10&format=json&units=e&apiKey=YOUR_KEY HTTP/1.1
Host: api.weather.com
```

Curl:

```
curl "https://api.weather.com/v2/pws/observations/current?stationId=KMAHANOV10&format=json&units=e&apiKey=$WU_KEY"
```

## Base URL

```
https://api.weather.com
```

## Endpoints

### PWS current conditions (`/v2/pws/observations/current`)

- **Path:** `/v2/pws/observations/current`
- **Method:** GET
- **Required parameters:**
  - `stationId` — PWS identifier (e.g. `KMAHANOV10`, `IONTARIO226`)
  - `format` — `json`
  - `units` — `e` (English/imperial), `m` (metric), `h` (hybrid/UK)
  - `apiKey`
- **Optional parameters:** `numericPrecision=decimal` returns floats with decimals; otherwise integers may be returned for some metric fields.
- **Example request:**
  ```
  curl "https://api.weather.com/v2/pws/observations/current?stationId=KMAHANOV10&format=json&units=e&apiKey=$WU_KEY"
  ```
- **Example response (truncated, units=e):**
  ```json
  {
    "observations": [
      {
        "stationID": "KMAHANOV10",
        "obsTimeUtc": "2026-04-30T17:53:00Z",
        "obsTimeLocal": "2026-04-30 13:53:00",
        "neighborhood": "Hanover Center",
        "softwareType": "EasyWeatherV1.5.5",
        "country": "US",
        "solarRadiation": 240.5,
        "lon": -71.05,
        "realtimeFrequency": null,
        "epoch": 1714506780,
        "lat": 42.05,
        "uv": 3.0,
        "winddir": 220,
        "humidity": 76,
        "qcStatus": 1,
        "imperial": {
          "temp": 54,
          "heatIndex": 54,
          "dewpt": 46,
          "windChill": 54,
          "windSpeed": 7,
          "windGust": 12,
          "pressure": 29.97,
          "precipRate": 0.00,
          "precipTotal": 0.05,
          "elev": 433
        }
      }
    ]
  }
  ```
- **Notes:**
  - The unit-specific block is named after `units`: `imperial` (for `units=e`), `metric` (for `units=m`), `uk_hybrid` (for `units=h`).
  - `qcStatus`: `-1`/`null` no QC, `1` passed, other values indicate review.
  - `realtimeFrequency` indicates the upload cadence.
  - "Current" = the last record reported within the past 60 minutes; if the station has been silent longer, an empty `observations` array is returned.

### PWS historical observations (`/v2/pws/...`)

- `GET /v2/pws/observations/all/1day?stationId=&format=json&units=e&apiKey=` — all observations for the past day
- `GET /v2/pws/observations/all/7day?stationId=&format=json&units=e&apiKey=` — past 7 days, every observation
- `GET /v2/pws/observations/hourly/1day?stationId=&format=json&units=e&apiKey=`
- `GET /v2/pws/observations/hourly/7day?stationId=&format=json&units=e&apiKey=`
- `GET /v2/pws/dailysummary/7day?stationId=&format=json&units=e&apiKey=`
- `GET /v2/pws/history/hourly?stationId=&format=json&units=e&date=YYYYMMDD&apiKey=`
- `GET /v2/pws/history/daily?stationId=&format=json&units=e&date=YYYYMMDD&apiKey=`
- `GET /v2/pws/history/all?stationId=&format=json&units=e&date=YYYYMMDD&apiKey=`

All historical endpoints accept the same `stationId`, `format=json`, `units`, `apiKey` parameters as `/observations/current`. `date` is `YYYYMMDD`.

### Daily forecast (`/v3/wx/forecast/daily/5day`)

- **Path:** `/v3/wx/forecast/daily/5day`
- **Method:** GET
- **Required parameters:** *one* of
  - `geocode=<lat>,<lon>`
  - `postalKey=<zip>:<country>` (e.g. `98101:US`, `L5R:CA`)
  - `placeid=<id>` (TWC place ID, returned by location services)
  - `iataCode=<airport>` / `icaoCode=<airport>`
- **Plus:**
  - `units` — `e`, `m`, `h`, or `s` (SI)
  - `language` — locale, e.g. `en-US`
  - `format` — `json`
  - `apiKey`
- **Example request:**
  ```
  curl "https://api.weather.com/v3/wx/forecast/daily/5day?geocode=47.6062,-122.3321&format=json&units=e&language=en-US&apiKey=$WU_KEY"
  ```
- **Example response (truncated):**
  ```json
  {
    "calendarDayTemperatureMax": [64, 66, 70, 68, 65],
    "calendarDayTemperatureMin": [48, 49, 52, 51, 50],
    "dayOfWeek": ["Thursday","Friday","Saturday","Sunday","Monday"],
    "expirationTimeUtc": [1714510380, 1714510380, 1714510380, 1714510380, 1714510380],
    "moonPhase": ["Waxing Gibbous","Full Moon","Waning Gibbous","Last Quarter","Waning Crescent"],
    "moonPhaseCode": ["WXG","F","WNG","LQ","WNC"],
    "moonPhaseDay": [10, 11, 12, 13, 14],
    "moonriseTimeLocal": ["2026-04-30T15:00:00-0700","..."],
    "moonsetTimeLocal":  ["2026-05-01T03:30:00-0700","..."],
    "narrative": ["Mostly cloudy. High 64F.","..."],
    "qpf":   [0.0, 0.05, 0.10, 0.0, 0.0],
    "qpfSnow":[0.0, 0.0, 0.0, 0.0, 0.0],
    "sunriseTimeLocal": ["2026-04-30T06:00:00-0700","..."],
    "sunsetTimeLocal":  ["2026-04-30T20:20:00-0700","..."],
    "temperatureMax": [64, 66, 70, 68, 65],
    "temperatureMin": [48, 49, 52, 51, 50],
    "validTimeLocal": ["2026-04-30T07:00:00-0700","..."],
    "validTimeUtc":   [1714485600, 1714572000, 1714658400, 1714744800, 1714831200],
    "daypart": [
      {
        "cloudCover":          [60, 40, 20, 30, 50, 70, 60, 80, 30, 40],
        "dayOrNight":          ["D","N","D","N","D","N","D","N","D","N"],
        "daypartName":         ["Today","Tonight","Friday","Friday Night", "..."],
        "iconCode":            [28, 27, 30, 29, "..."],
        "iconCodeExtend":      [2800,2700,3000,2900],
        "narrative":           ["Mostly cloudy. High 64F. Winds SW at 5 to 10 mph.","..."],
        "precipChance":        [20, 10, 30, 30, "..."],
        "precipType":          ["rain","rain","rain","rain"],
        "qpf":                 [0.0, 0.0, 0.05, 0.0],
        "qpfSnow":             [0.0, 0.0, 0.0, 0.0],
        "qualifierCode":       [null, null, null, null],
        "qualifierPhrase":     [null, null, null, null],
        "relativeHumidity":    [70, 80, 65, 78],
        "snowRange":           ["", "", "", ""],
        "temperature":         [64, 48, 66, 49],
        "temperatureHeatIndex":[64, 48, 66, 49],
        "temperatureWindChill":[54, 45, 56, 46],
        "thunderCategory":     ["No thunder","No thunder","No thunder","No thunder"],
        "thunderIndex":        [0, 0, 0, 0],
        "uvDescription":       ["Moderate","Low","High","Low"],
        "uvIndex":             [4, 0, 6, 0],
        "windDirection":       [220, 180, 240, 200],
        "windDirectionCardinal":["SW","S","WSW","SSW"],
        "windPhrase":          ["Winds SW at 5 to 10 mph.","..."],
        "windSpeed":           [7, 4, 9, 5],
        "wxPhraseLong":        ["Mostly Cloudy","Mostly Clear","Sunny","Partly Cloudy"],
        "wxPhraseShort":       ["M Cloudy","M Clear","Sunny","P Cloudy"]
      }
    ]
  }
  ```
- **Notes:**
  - The response is **column-oriented**: top-level arrays are 5 elements (one per day). `daypart[0]` arrays are **10 elements** (5 days × 2 dayparts: D/N), with `null` in slots whose period has already passed.
  - `validTimeLocal` includes the local timezone offset; `validTimeUtc` is the same instant in Unix.
  - Other 5-day variants exist with the same shape: `/v3/wx/forecast/daily/3day`, `/7day`, `/10day`, `/15day` (availability depends on the plan).

### Location services (`/v3/location/...`)

- `GET /v3/location/search?query=<text>&locationType=city&language=en-US&format=json&apiKey=`
- `GET /v3/location/point?geocode=<lat>,<lon>&language=en-US&format=json&apiKey=`
- `GET /v3/location/near?geocode=<lat>,<lon>&product=pws&format=json&apiKey=` — find nearby PWS stations

These return TWC place metadata including `placeId`, `latitude`, `longitude`, `ianaTimeZone`, `displayName`, `adminDistrict`, `country`, `postalCode`, etc.

### Legacy upload protocol (`/weatherstation/updateweatherstation.php`)

For completeness — this is how a PWS *uploads* observations, not how a client reads them:

- **Host:** `https://weatherstation.wunderground.com`
- **Path:** `/weatherstation/updateweatherstation.php`
- **Required parameters:** `ID` (station ID), `PASSWORD` (station password — distinct from the API key), `action=updateraw`, `dateutc=now`, plus per-sensor variables (`tempf`, `humidity`, `windspeedmph`, `baromin`, `dewptf`, `rainin`, etc.)
- **Notes:** Documented at http://wiki.wunderground.com/index.php/PWS_-_Upload_Protocol. Read-side endpoints listed above are the relevant ones for a forecast-provider client.

## Rate limits

- **Documented community quota:** **1,500 calls/day, 30 calls/minute** for PWS-contributor keys. Rate is enforced server-side; HTTP `429` is returned when exceeded.
- The exact contract may differ for newer accounts — verify against the Google Doc when implementing.

## Response format conventions

- **JSON only** for these endpoints (`format=json` is required by most).
- **Timestamps:** mixed.
  - PWS observations include both `obsTimeUtc` (ISO 8601 UTC) and `obsTimeLocal` (station local time, no offset).
  - Forecast endpoints provide `validTimeUtc` (Unix), `validTimeLocal` (ISO 8601 with offset), and `expirationTimeUtc` (Unix).
- **Units:** controlled by the `units` query param:
  - `e` — English/imperial (°F, mph, in, in/h)
  - `m` — Metric SI variant (°C, km/h, mm, mm/h)
  - `s` — Pure SI (m/s on wind)
  - `h` — Hybrid (UK; °C, mph, mm)
  - The PWS observation response wraps unit-dependent fields in a sub-object named `imperial` / `metric` / `metric_si` / `uk_hybrid`. The forecast response embeds the unit choice into the array values directly (no separate wrapper).
- **Forecast responses are column-oriented arrays** indexed by day (and `daypart[0].*` indexed by daypart slot). Past-period slots may be `null`.

## Known issues / gotchas

- **PWS-only gating.** Without an active uploading PWS, you cannot get a key from the public dashboard. End users without a PWS can register one (even a virtual/non-uploading station may not be sufficient — verify).
- **The canonical contract is in a Google Doc**, not on a public web page. The Doc requires login and PWS contributor status to view. Any field name or quota figure here that is not in the Google Doc must be confirmed against it before relying on it in production code.
- **Endpoint stability:** TWC has retired Weather Underground APIs in the past (notably the older `api.wunderground.com` REST API in 2018). The `api.weather.com` family is currently the supported one, but assume future deprecation risk.
- **`format=json` is mandatory** on the `/v2/pws/...` family; without it some endpoints default to a non-JSON response or `400`.
- **Empty observation list ≠ error.** `/v2/pws/observations/current` returns an empty `observations: []` if the station hasn't reported in the last hour; do not treat that as a failure.
- **Forecast `daypart[0]` arrays are double the length** of top-level arrays (D/N split). Keep the index alignment straight: top-level slot `i` maps to dayparts `[2*i, 2*i+1]`.
- **`pop`-equivalent here is `precipChance`** and is in **percent (0–100)**, not 0–1 like OpenWeatherMap.
- **No alerts endpoint** is exposed on this gated PWS API tier. Alerts on the wunderground.com website come from a separate enterprise feed.
- **Phase 2 must verify against the Google Doc** for: exact response field names, supported `units=` block names, available historical date ranges, and whether the 5-day endpoint has been quietly upgraded to `daily/<n>day` for arbitrary `n`.
