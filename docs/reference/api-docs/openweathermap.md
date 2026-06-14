# OpenWeatherMap — API Reference

**Source:**
- https://openweathermap.org/api (overview)
- https://openweathermap.org/current (Current Weather Data)
- https://openweathermap.org/forecast5 (5 Day / 3 Hour Forecast)
- https://openweathermap.org/api/one-call-3 (One Call API 3.0)
- https://openweathermap.org/api/air-pollution (Air Pollution API)

**Last verified:** 2026-05-10 (Air Pollution section added 3b-11); 2026-04-30 (Current / Forecast / One Call 3.0); 2026-06-13 (regional AQI scales confirmed documentation-only; NH3/NO retention policy changed)

## Authentication

API key passed as the **query parameter `appid`** on every request. No header auth.

Keys are tied to a subscription plan. The free tier gates which endpoints are available — Current Weather and 5-Day/3-Hour Forecast are free; One Call 3.0 is a separate "One Call by Call" subscription with its own quota.

### Example HTTP request

```
GET /data/2.5/weather?lat=47.6062&lon=-122.3321&appid=YOUR_KEY&units=imperial HTTP/1.1
Host: api.openweathermap.org
```

Curl:

```
curl "https://api.openweathermap.org/data/2.5/weather?lat=47.6062&lon=-122.3321&appid=$OWM_KEY&units=imperial"
```

## Base URL

- Free / data 2.5: `https://api.openweathermap.org/data/2.5/`
- One Call 3.0:    `https://api.openweathermap.org/data/3.0/`

## Endpoints

### Current weather (free)

- **Path:** `/data/2.5/weather`
- **Method:** GET
- **Required parameters:**
  - `appid` — API key
  - One location specifier:
    - `lat` + `lon` (recommended)
    - `q=<city,state,country>` (deprecated)
    - `id=<city-id>` (deprecated)
    - `zip=<zip,country>` (deprecated)
- **Optional parameters:**
  - `units` — `standard` (Kelvin, default), `metric` (Celsius), `imperial` (Fahrenheit)
  - `lang` — language code (30+ supported, e.g. `en`, `es`, `fr`, `zh_cn`)
  - `mode` — `json` (default), `xml`, `html`
- **Example request:**
  ```
  curl "https://api.openweathermap.org/data/2.5/weather?lat=47.6062&lon=-122.3321&appid=$OWM_KEY&units=imperial"
  ```
- **Example response (truncated):**
  ```json
  {
    "coord": { "lon": -122.33, "lat": 47.61 },
    "weather": [
      { "id": 803, "main": "Clouds", "description": "broken clouds", "icon": "04d" }
    ],
    "base": "stations",
    "main": {
      "temp": 54.5,
      "feels_like": 52.7,
      "temp_min": 51.0, "temp_max": 58.0,
      "pressure": 1015,
      "humidity": 76,
      "sea_level": 1015,
      "grnd_level": 1010
    },
    "visibility": 10000,
    "wind": { "speed": 7.2, "deg": 220, "gust": 12.1 },
    "clouds": { "all": 75 },
    "rain":  { "1h": 0.2 },
    "dt": 1714485600,
    "sys": { "country": "US", "sunrise": 1714477200, "sunset": 1714528800 },
    "timezone": -25200,
    "id": 5809844,
    "name": "Seattle",
    "cod": 200
  }
  ```
- **Notes:**
  - Wind speed unit varies with `units`: m/s for `standard`/`metric`, mph for `imperial`.
  - `visibility` is in meters (max 10000).
  - `rain.1h` / `snow.1h` only present if precipitation reported in the last hour.
  - Searching by city name is deprecated — prefer lat/lon (use the Geocoding API to translate names).

### 5 Day / 3 Hour forecast (free)

- **Path:** `/data/2.5/forecast`
- **Method:** GET
- **Required parameters:** `lat`, `lon`, `appid`
- **Optional parameters:** `units`, `lang`, `mode` (json|xml), `cnt` (limit timestamps)
- **Example request:**
  ```
  curl "https://api.openweathermap.org/data/2.5/forecast?lat=47.6062&lon=-122.3321&appid=$OWM_KEY&units=imperial"
  ```
- **Example response (truncated):**
  ```json
  {
    "cod": "200",
    "message": 0,
    "cnt": 40,
    "list": [
      {
        "dt": 1714492800,
        "main": {
          "temp": 60.1, "feels_like": 58.9,
          "temp_min": 59.0, "temp_max": 60.1,
          "pressure": 1015, "sea_level": 1015, "grnd_level": 1010,
          "humidity": 70, "temp_kf": 0.6
        },
        "weather": [{ "id": 803, "main": "Clouds", "description": "broken clouds", "icon": "04d" }],
        "clouds": { "all": 75 },
        "wind": { "speed": 8.0, "deg": 230, "gust": 14 },
        "visibility": 10000,
        "pop": 0.2,
        "rain": { "3h": 0.5 },
        "sys": { "pod": "d" },
        "dt_txt": "2026-04-30 14:00:00"
      }
    ],
    "city": {
      "id": 5809844,
      "name": "Seattle",
      "coord": { "lat": 47.61, "lon": -122.33 },
      "country": "US",
      "population": 600000,
      "timezone": -25200,
      "sunrise": 1714477200,
      "sunset":  1714528800
    }
  }
  ```
- **Notes:**
  - 40 entries × 3 hours = 5 days.
  - All `dt` values are Unix UTC. `dt_txt` is UTC ISO; convert with `city.timezone` (seconds offset).
  - `pop` is precipitation probability **0–1** (not 0–100).
  - `rain.3h` / `snow.3h` are 3-hour totals (mm).
  - `sys.pod` = part of day, `d` or `n`.

### One Call API 3.0 (paid subscription)

- **Path:** `/data/3.0/onecall`
- **Method:** GET
- **Required parameters:**
  - `lat`, `lon`
  - `appid`
- **Optional parameters:**
  - `units` — `standard|metric|imperial`
  - `lang` — 50+ languages
  - `exclude` — CSV of blocks to skip: `current,minutely,hourly,daily,alerts`
- **Example request:**
  ```
  curl "https://api.openweathermap.org/data/3.0/onecall?lat=47.6062&lon=-122.3321&appid=$OWM_KEY&units=imperial&exclude=minutely"
  ```
- **Example response (truncated):**
  ```json
  {
    "lat": 47.61, "lon": -122.33,
    "timezone": "America/Los_Angeles",
    "timezone_offset": -25200,
    "current": {
      "dt": 1714485600,
      "sunrise": 1714477200, "sunset": 1714528800,
      "temp": 54.5, "feels_like": 52.7,
      "pressure": 1015, "humidity": 76, "dew_point": 46.4,
      "uvi": 3.2, "clouds": 75, "visibility": 10000,
      "wind_speed": 7.2, "wind_deg": 220, "wind_gust": 12.1,
      "weather": [{ "id": 803, "main": "Clouds", "description": "broken clouds", "icon": "04d" }]
    },
    "minutely": [
      { "dt": 1714485600, "precipitation": 0 }
    ],
    "hourly": [
      {
        "dt": 1714485600,
        "temp": 54.5, "feels_like": 52.7,
        "pressure": 1015, "humidity": 76, "dew_point": 46.4,
        "uvi": 3.2, "clouds": 75, "visibility": 10000,
        "wind_speed": 7.2, "wind_deg": 220, "wind_gust": 12.1,
        "weather": [{ "id": 803, "main": "Clouds", "description": "broken clouds", "icon": "04d" }],
        "pop": 0.2
      }
    ],
    "daily": [
      {
        "dt": 1714492800, "sunrise": 1714477200, "sunset": 1714528800,
        "moonrise": 1714510800, "moonset": 1714466400, "moon_phase": 0.42,
        "summary": "Mostly cloudy with afternoon sun",
        "temp":       { "morn": 49, "day": 60, "eve": 58, "night": 52, "min": 48, "max": 64 },
        "feels_like": { "morn": 47, "day": 58, "eve": 56, "night": 50 },
        "pressure": 1015, "humidity": 70, "dew_point": 46,
        "wind_speed": 8.0, "wind_deg": 230, "wind_gust": 14,
        "weather": [{ "id": 803, "main": "Clouds", "description": "broken clouds", "icon": "04d" }],
        "clouds": 75, "pop": 0.2, "uvi": 6,
        "rain": 0.5
      }
    ],
    "alerts": [
      {
        "sender_name": "NWS Seattle WA",
        "event": "Wind Advisory",
        "start": 1714485600, "end": 1714521600,
        "description": "* WHAT...Southerly winds 20 to 30 mph...",
        "tags": ["Wind"]
      }
    ]
  }
  ```
- **Notes:**
  - 48 hourly entries, 8 daily entries.
  - `pop` is 0–1.
  - `rain` / `snow` on `daily` are total mm; on `hourly` they are `{1h: <mm>}`.
  - Free tier of One Call by Call: 1,000 calls/day; default paid tier: 2,000 calls/day. Updated every 10 minutes.

#### One Call related endpoints

- `/data/3.0/onecall/timemachine?lat=&lon=&dt=<unix>&appid=` — single timestamp historical/future point. `dt` accepts 1979-01-01 through +4 days. Optional: `units`, `lang`.
- `/data/3.0/onecall/day_summary?lat=&lon=&date=YYYY-MM-DD&appid=` — daily aggregate. Range 1979-01-02 through ~1.5 years ahead. Optional: `units`, `lang`, `tz` (`±HH:MM`).
- `/data/3.0/onecall/overview` — AI-generated weather summary string.

### Air Pollution (free)

- **Path:** `/data/2.5/air_pollution`
- **Method:** GET
- **Required parameters:**
  - `appid` — API key
  - `lat`, `lon` — location coordinates
- **Optional parameters:** none documented (no `units`, no `lang` — concentrations are always µg/m³; AQI is always the OWM 1–5 ordinal scale)
- **Example request:**
  ```
  curl "https://api.openweathermap.org/data/2.5/air_pollution?lat=47.6062&lon=-122.3321&appid=$OWM_KEY"
  ```
- **Example response:**
  ```json
  {
    "coord": [50.0, 50.0],
    "list": [
      {
        "dt": 1606147200,
        "main": {
          "aqi": 4
        },
        "components": {
          "co":    203.609,
          "no":      0.0,
          "no2":     0.396,
          "o3":     75.102,
          "so2":     0.648,
          "pm2_5":  23.253,
          "pm10":   92.214,
          "nh3":     0.117
        }
      }
    ]
  }
  ```
- **Field details:**
  - `coord` — `[latitude, longitude]` array.
  - `list[]` — single entry for current endpoint; multiple for forecast / history endpoints (4 days hourly for forecast).
  - `list[0].dt` — Unix UTC seconds.
  - `list[0].main.aqi` — **OWM 1–5 ordinal scale**, NOT EPA 0–500. See "AQI scale" subsection below.
  - `list[0].components.*` — all concentrations in **µg/m³**, including gases (no ppm/ppb here, unlike Aeris).
- **No location label.** The response carries `coord` (lat/lon) but NO city / state / country name field. Canonical `aqiLocation` is PARTIAL-DOMAIN for this provider.

#### AQI scale (OWM 1–5 ordinal, with per-pollutant breakpoints)

OWM publishes a 5-level ordinal scale (1 = Good ... 5 = Very Poor), assembled by taking the worst per-pollutant band across SO₂, NO₂, PM₁₀, PM₂.₅, O₃, CO. Each pollutant has its own per-band concentration range in **µg/m³**:

| Index | Name      | SO₂ µg/m³  | NO₂ µg/m³ | PM₁₀ µg/m³ | PM₂.₅ µg/m³ | O₃ µg/m³  | CO µg/m³        |
|-------|-----------|------------|-----------|------------|-------------|-----------|-----------------|
| 1     | Good      | [0; 20)    | [0; 40)   | [0; 20)    | [0; 10)     | [0; 60)   | [0; 4400)       |
| 2     | Fair      | [20; 80)   | [40; 70)  | [20; 50)   | [10; 25)    | [60; 100) | [4400; 9400)    |
| 3     | Moderate  | [80; 250)  | [70; 150) | [50; 100)  | [25; 50)    | [100; 140)| [9400; 12400)   |
| 4     | Poor      | [250; 350) | [150; 200)| [100; 200) | [50; 75)    | [140; 180)| [12400; 15400)  |
| 5     | Very Poor | ≥ 350      | ≥ 200     | ≥ 200      | ≥ 75        | ≥ 180     | ≥ 15400         |

**NH₃ and NO** are reported (0.1–200 µg/m³ and 0.1–100 µg/m³ respectively) but do **not** affect the OWM index calculation. They have no EPA AQI equivalent. **However, they should NOT be dropped during canonical translation (FIX-003, 2026-06-13).** NH3 and NO are valid pollutant measurements that may be needed for non-EPA regional AQI calculations client-side, and discarding data the API provides serves no purpose.

OWM also publishes regional variants (UK / Europe / USA / Mainland China) at https://openweathermap.org/air-pollution-index-levels; those are NOT returned in the API response — see "Regional AQI scales" section below for full reference tables.

#### Forecast and History sub-endpoints

| Sub-endpoint | Path                                      | Required extra params  | Notes                              |
|--------------|-------------------------------------------|------------------------|------------------------------------|
| Forecast     | `/data/2.5/air_pollution/forecast`        | `lat`, `lon`, `appid`  | 4 days hourly; same shape as current. |
| History      | `/data/2.5/air_pollution/history`         | `lat`, `lon`, `start`, `end`, `appid` | Unix UTC seconds for `start` / `end`; data available from 2020-11-27 onward. |

#### Regional AQI scales — documentation-only reference (NOT in API response)

**Captured:** 2026-06-13 from https://openweathermap.org/air-pollution-index-levels

OWM publishes regional AQI breakpoint tables at the index-levels page for **four regions**: UK, Europe, USA, and Mainland China. **These are NOT returned by the API.** There is no parameter to select a regional scale, no field in the response containing a regional AQI value, and no change in response shape based on queried location. The regional scales are reference material for developers who want to convert the raw pollutant concentrations into a region-specific AQI client-side.

##### UK Air Quality Index (DAQI) — 10-point scale

4 bands: Low (1-3), Moderate (4-6), High (7-9), Very High (10). Pollutants: SO2, NO2, PM2.5, PM10, O3. All ug/m3.

| Qualitative | Index | SO2 | NO2 | PM2.5 | PM10 | O3 |
|---|---|---|---|---|---|---|
| Low | 1 | 0-88 | 0-67 | 0-11 | 0-16 | 0-33 |
| Low | 2 | 89-177 | 68-134 | 12-23 | 17-33 | 34-66 |
| Low | 3 | 178-266 | 135-200 | 24-35 | 34-50 | 67-100 |
| Moderate | 4 | 267-354 | 201-267 | 36-41 | 52-58 | 101-120 |
| Moderate | 5 | 355-443 | 268-334 | 42-47 | 59-66 | 121-140 |
| Moderate | 6 | 444-532 | 335-400 | 48-53 | 67-75 | 141-160 |
| High | 7 | 533-710 | 401-467 | 54-58 | 76-83 | 161-187 |
| High | 8 | 711-887 | 468-534 | 59-64 | 84-91 | 188-213 |
| High | 9 | 888-1064 | 535-600 | 65-70 | 92-100 | 214-240 |
| Very High | 10 | >= 1065 | >= 601 | >= 71 | >= 101 | >= 241 |

##### European Air Quality Index — 5-level scale (0-100+)

Pollutants: NO2, PM10, O3, PM2.5. All hourly ug/m3.

| Qualitative | Index Range | NO2 | PM10 | O3 | PM2.5 |
|---|---|---|---|---|---|
| Very Low | 0-25 | 0-50 | 0-25 | 0-60 | 0-15 |
| Low | 25-50 | 50-100 | 25-50 | 60-120 | 15-30 |
| Medium | 50-75 | 100-200 | 50-90 | 120-180 | 30-55 |
| High | 75-100 | 200-400 | 90-180 | 180-240 | 55-110 |
| Very High | >100 | >400 | >180 | >240 | >110 |

Note: This European scale on OWM's page differs from Open-Meteo's European AQI breakpoints. Open-Meteo's version has 6 categories (adds "Extremely Poor") and uses different concentration ranges. Multiple versions of the European AQI exist (EEA, CAMS, national variants).

##### USA EPA AQI — 0-500 scale (+ OWM extension to 1000)

Standard EPA 0-500 scale. OWM adds a 501-1000 "Very Hazardous" category beyond the standard table.

| AQI Range | Category | Color |
|---|---|---|
| 0-50 | Good | Green |
| 51-100 | Moderate | Yellow |
| 101-150 | Unhealthy for Sensitive Groups | Orange |
| 151-200 | Unhealthy | Red |
| 201-300 | Very Unhealthy | Purple |
| 301-500 | Hazardous | Maroon |
| 501-1000 | Very Hazardous | Brown |

EPA AQI formula: `I = ((I_high - I_low) / (C_high - C_low)) * (C - C_low) + I_low`

Pollutants: O3 (8-hr and 1-hr), PM2.5 (24-hr), PM10 (24-hr), CO (8-hr), SO2 (1-hr), NO2 (1-hr).

**EPA breakpoint concentration table:**

| I_low-I_high | O3 8-hr (ppb) | O3 1-hr (ppb) | PM2.5 24-hr (ug/m3) | PM10 24-hr (ug/m3) | CO 8-hr (ppm) | SO2 1-hr (ppb) | NO2 1-hr (ppb) |
|---|---|---|---|---|---|---|---|
| 0-50 | 0-54 | -- | 0.0-12.0 | 0-54 | 0.0-4.4 | 0-35 | 0-53 |
| 51-100 | 55-70 | -- | 12.1-35.4 | 55-154 | 4.5-9.4 | 36-75 | 54-100 |
| 101-150 | 71-85 | 125-164 | 35.5-55.4 | 155-254 | 9.5-12.4 | 76-185 | 101-360 |
| 151-200 | 86-105 | 165-204 | 55.5-150.4 | 255-354 | 12.5-15.4 | 186-304 | 361-649 |
| 201-300 | 106-200 | 205-404 | 150.5-250.4 | 355-424 | 15.5-30.4 | 305-604 (24-hr) | 650-1249 |
| 301-400 | -- | 405-504 | 250.5-350.4 | 425-504 | 30.5-40.4 | 605-804 (24-hr) | 1250-1649 |
| 401-500 | -- | 505-604 | 350.5-500.4 | 505-604 | 40.5-50.4 | 805-1004 (24-hr) | 1650-2049 |

Notes: O3 8-hr used for AQI 0-300; >200 ppb uses 1-hr only. O3 1-hr used for AQI 101-500. SO2 switches from 1-hr to 24-hr for AQI 201-500.

##### Mainland China AQI (GB 3095-2012) — 0-500 scale

| AQI Range | Level | Category |
|---|---|---|
| 0-50 | Level 1 | Excellent |
| 51-100 | Level 2 | Good |
| 101-150 | Level 3 | Lightly Polluted |
| 151-200 | Level 4 | Moderately Polluted |
| 201-300 | Level 5 | Heavily Polluted |
| >300 | Level 6 | Severely Polluted |

Pollutants: SO2, NO2, PM10, CO, O3, PM2.5. Uses the same linear interpolation formula as US EPA AQI.

**China IAQI breakpoint table (units: ug/m3 except CO in mg/m3):**

| IAQI | SO2 24-hr | NO2 24-hr | PM10 24-hr | CO 24-hr (mg/m3) | O3 1-hr | O3 8-hr | PM2.5 24-hr |
|---|---|---|---|---|---|---|---|
| 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 50 | 50 | 40 | 50 | 2 | 160 | 100 | 35 |
| 100 | 150 | 80 | 150 | 4 | 200 | 160 | 75 |
| 150 | 475 | 180 | 250 | 14 | 300 | 215 | 115 |
| 200 | 800 | 280 | 350 | 24 | 400 | 265 | 150 |
| 300 | 1600 | 565 | 420 | 36 | 800 | 800 | 250 |
| 400 | 2100 | 750 | 500 | 48 | 1000 | -- | 350 |
| 500 | 2620 | 940 | 600 | 60 | 1200 | -- | 500 |

#### Air Pollution-specific gotchas

- **OWM AQI 1–5 ≠ EPA AQI 0–500.** To produce a canonical EPA 0–500 AQI value, the normalizer must compute each pollutant's EPA sub-AQI from its concentration via the EPA breakpoint table (in `providers/aqi/_units.py`) — NOT use `main.aqi` directly.
- **All pollutant concentrations are µg/m³.** Gases (O₃, NO₂, SO₂, CO) must be converted to ppm for canonical `pollutantO3` / `pollutantNO2` / `pollutantSO2` / `pollutantCO` (canonical group_fraction). PM₂.₅ / PM₁₀ pass through as µg/m³.
- **OWM does not differentiate averaging periods.** EPA AQI sub-tables are defined for 1-hr / 8-hr / 24-hr averages depending on pollutant; OWM returns a snapshot. The normalizer applies EPA breakpoints to the snapshot as an approximation (documented limitation — same pattern third-party AQI services use). Per Q1 Option A (2026-05-10): O3 uses the 8-hr table only and caps at sub-AQI 300 above 0.200 ppm; SO2 uses the 1-hr table only and caps at sub-AQI 200 above 0.304 ppm. Both caps reflect that the operationalization can't faithfully extend past the table's averaging-period top breakpoint for an instantaneous snapshot.
- **No tier gating.** Air Pollution is on the Free tier per https://openweathermap.org/price; FREE-tier appid works without a One Call subscription. Distinct from the One Call 3.0 endpoint which requires a separate "One Call by Call" sub.
- **No location label in the response.** Canonical `aqiLocation` stays null for this provider.
- **NH₃ and NO are extras but should be RETAINED (FIX-003).** Present on the wire, not in EPA AQI calculation, but should not be dropped during canonical translation. They are valid pollutant measurements that may be needed for non-EPA regional AQI calculations client-side.

### Weather Maps 1.0 (free)

**Provenance:** Written 2026-05-11 from upstream documentation (https://openweathermap.org/api/weathermaps). **NOT live-verified at brief-draft time.** Test-author should capture a live tile response during fixture work and surface any divergence per `rules/clearskies-process.md` "api-docs file provenance is part of the cross-check."

OpenWeatherMap exposes weather model layers as XYZ slippy-map raster tiles. Day-1 layer per [ADR-015](../../decisions/ADR-015-radar-map-tiles-strategy.md) is `precipitation_new` — labeled **"Model precipitation"** in the dashboard, NOT "Radar," because OWM serves NWP-model output, not radar reflectivity.

#### Tile URL template

```
https://tile.openweathermap.org/map/{layer}/{z}/{x}/{y}.png?appid={appid}
```

- `{layer}` — one of `precipitation_new`, `clouds_new`, `pressure_new`, `wind_new`, `temp_new`. Clear Skies day-1 uses `precipitation_new`.
- `{z}` / `{x}` / `{y}` — slippy-map zoom + tile coordinates.
- `{appid}` — OWM API key, query parameter.

#### Tile content type

`image/png`. Transparent background; meant to overlay on a basemap.

#### Time-stepping

**None — current-only.** Weather Maps 1.0 has no `?t=...` parameter; every request returns the latest available tile. Weather Maps 2.0 (paid) adds hourly historical + forecast layers, but that's out of v0.1 scope.

For the canonical `/radar/providers/openweathermap/frames` response, this means: at most one frame, kind=`current`. Acceptable per the canonical model (RadarFrameList allows an empty or single-entry list); the dashboard renders the static tile without a frame slider when `frames=[]` or `frames=[current]`.

#### Authentication / tier gating

- A basic OWM `appid` (free tier) is sufficient — no Weather Maps subscription required for the 1.0 layers.
- `precipitation_new` and the other four day-1 layers are documented as free.
- 401/403 from this endpoint indicates `appid` invalid or revoked → canonical `KeyInvalid`.

#### Rate limits

Free tier: 60 calls/min, 1,000,000 calls/month (shared bucket with other free-tier OWM endpoints per https://openweathermap.org/price). Tile requests count individually; a single map view typically loads 4–20 tiles. The api caches tile bytes per ADR-017, so polling cost is bounded.

#### Cache-Control on tile responses

Per ADR-017, the tile proxy honors upstream `Cache-Control: max-age=...` if present; defaults to 300s otherwise. Upstream behavior **not live-verified** — test-author should capture and document.

#### Known gotchas

- **Tile coverage is global.** No partial-domain restrictions like the WMS providers; works for any (z, x, y) the operator's viewport requests.
- **Layer is model precipitation, not radar reflectivity.** Operators expecting radar-style returns (e.g., NEXRAD echo intensity) will see something different. Dashboard labels this as "Model precipitation" per ADR-015 line 28.
- **No `t` parameter despite OpenAPI spec exposing `?t=` on the proxy.** Per LC-7 in the round brief, the api accepts `?t` but ignores it for OWM (always returns current). Documented behavior; not a bug.

### Other free / paid endpoints (overview only)

| Product | Path | Tier |
|---|---|---|
| Air Pollution | `/data/2.5/air_pollution` | Free |
| Air Pollution Forecast | `/data/2.5/air_pollution/forecast` | Free |
| Air Pollution History | `/data/2.5/air_pollution/history` | Free |
| Geocoding | `/geo/1.0/direct`, `/geo/1.0/reverse` | Free |
| Hourly Forecast (4 days) | `/data/2.5/forecast/hourly` | Developer+ |
| Daily Forecast (16 days) | `/data/2.5/forecast/daily` | Developer+ |
| Climatic Forecast (30 days) | `/data/2.5/forecast/climate` | Developer+ |

## Rate limits

- **Free tier (Current + 5-day):** 60 calls/minute, 1,000,000 calls/month.
- **One Call by Call free tier:** 1,000 calls/day; default paid: 2,000/day.
- HTTP `429` returned when exceeded.
- Specific limits depend on the plan listed at https://openweathermap.org/price.

## Response format conventions

- **Default format:** JSON. XML and HTML available via `mode=` on `/weather` and `/forecast`.
- **Times:** Unix UTC seconds in `dt`, `sunrise`, `sunset`. Convert to local with `timezone` (seconds offset, on `/weather`) or `timezone_offset` (on `/onecall`).
- **Units:**
  - `standard` (default): Kelvin, m/s, hPa, mm
  - `metric`: Celsius, m/s, hPa, mm
  - `imperial`: Fahrenheit, mph, hPa, mm
  - Pressure and precipitation units do **not** change with `units`.
- **Probability of precipitation (`pop`):** 0–1 float, **not 0–100 percent**.
- **Icons:** `weather[].icon` is a code like `04d` / `04n`. Render with `https://openweathermap.org/img/wn/{icon}@2x.png`.

## Known issues / gotchas

- **One Call 3.0 is a separate subscription** ("One Call by Call"). A free-tier API key alone returns `401` from `/data/3.0/onecall`.
- **`pop` is 0–1, not percent.** Common bug source.
- **Pressure and precipitation units ignore the `units=` parameter.**
- **City-name lookups are deprecated** — use `lat`/`lon`. Use the Geocoding API to convert.
- **Free-tier daily-forecast endpoints (`/forecast/daily`, `/forecast/hourly`, `/forecast/climate`) require a paid plan**, despite living under `/data/2.5/`.
- **Rain/snow keys may be absent.** Always check before reading `rain.1h` or `snow.3h`.
- **Alerts** in One Call cover a region's official issuing agency and are localized strings — do not assume English.
