# OpenWeatherMap — API Reference

**Source:**
- https://openweathermap.org/api (overview)
- https://openweathermap.org/current (Current Weather Data)
- https://openweathermap.org/forecast5 (5 Day / 3 Hour Forecast)
- https://openweathermap.org/api/one-call-3 (One Call API 3.0)

**Last verified:** 2026-04-30

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
