# Open-Meteo — API Reference

**Source:** https://open-meteo.com/en/docs

**Last verified:** 2026-04-30

## Authentication

**No API key required for non-commercial use.** Open-Meteo is open and unauthenticated; the public endpoint accepts requests directly.

For commercial use, a paid plan issues a key passed as `apikey=<key>` and the host changes to a `customer-` prefixed domain (e.g. `customer-api.open-meteo.com`). The non-commercial host described below is what most clients use.

### Example HTTP request

```
GET /v1/forecast?latitude=47.6062&longitude=-122.3321&current=temperature_2m,wind_speed_10m HTTP/1.1
Host: api.open-meteo.com
```

Curl:

```
curl "https://api.open-meteo.com/v1/forecast?latitude=47.6062&longitude=-122.3321&current=temperature_2m,wind_speed_10m"
```

## Base URL

```
https://api.open-meteo.com/v1/forecast
```

(Single endpoint; the entire API is one path with a rich set of query parameters.)

## Endpoints

### Forecast

- **Path:** `/v1/forecast`
- **Method:** GET
- **Required parameters:**

  | Name | Type | Description |
  |---|---|---|
  | `latitude` | float (or comma list) | WGS84 latitude. Multiple locations are supported with `lat1,lat2,...` |
  | `longitude` | float (or comma list) | WGS84 longitude. West of Greenwich = negative |

- **Optional parameters:**

  | Name | Default | Notes |
  |---|---|---|
  | `elevation` | auto | 90m DEM auto-detected. Pass `nan` to disable downscaling, or pass a number to override |
  | `current` | — | CSV of current-condition variables (see "Current variables" below) |
  | `hourly` | — | CSV of hourly variables |
  | `daily` | — | CSV of daily variables. **Requires `timezone=`** |
  | `temperature_unit` | `celsius` | `fahrenheit` |
  | `wind_speed_unit` | `kmh` | `ms`, `mph`, `kn` |
  | `precipitation_unit` | `mm` | `inch` |
  | `timeformat` | `iso8601` | `unixtime` |
  | `timezone` | `GMT` | IANA name (e.g. `America/Los_Angeles`) or `auto` |
  | `past_days` | `0` | Range 0-92 |
  | `forecast_days` | `7` | Range 0-16 |
  | `forecast_hours` | — | Override forecast hour count |
  | `past_hours` | — | Historical hour range |
  | `forecast_minutely_15` | — | 15-minute resolution forecast count |
  | `past_minutely_15` | — | Historical 15-minute count |
  | `start_date` / `end_date` | — | `YYYY-MM-DD` |
  | `start_hour` / `end_hour` | — | `YYYY-MM-DDTHH:MM` |
  | `models` | `auto` | Manually choose weather models (CSV) |
  | `cell_selection` | `land` | `sea`, `nearest` |
  | `apikey` | — | Commercial use only |

- **Example request:**
  ```
  curl "https://api.open-meteo.com/v1/forecast?latitude=47.6062&longitude=-122.3321&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&hourly=temperature_2m,precipitation_probability&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=America%2FLos_Angeles&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch"
  ```

- **Example response (truncated):**
  ```json
  {
    "latitude": 47.625,
    "longitude": -122.34,
    "elevation": 44.8,
    "generationtime_ms": 0.85,
    "utc_offset_seconds": -25200,
    "timezone": "America/Los_Angeles",
    "timezone_abbreviation": "PDT",
    "current_units": {
      "time": "iso8601",
      "interval": "seconds",
      "temperature_2m": "°F",
      "relative_humidity_2m": "%",
      "wind_speed_10m": "mp/h",
      "weather_code": "wmo code"
    },
    "current": {
      "time": "2026-04-30T10:00",
      "interval": 900,
      "temperature_2m": 54.5,
      "relative_humidity_2m": 76,
      "wind_speed_10m": 7.2,
      "weather_code": 3
    },
    "hourly_units": { "time": "iso8601", "temperature_2m": "°F",
                      "precipitation_probability": "%" },
    "hourly": {
      "time": ["2026-04-30T00:00", "2026-04-30T01:00", "..."],
      "temperature_2m": [49.1, 48.7, 48.4, "..."],
      "precipitation_probability": [10, 10, 5, "..."]
    },
    "daily_units": { "time": "iso8601", "temperature_2m_max": "°F",
                     "temperature_2m_min": "°F", "precipitation_sum": "inch" },
    "daily": {
      "time": ["2026-04-30","2026-05-01"],
      "temperature_2m_max": [64.2, 66.0],
      "temperature_2m_min": [48.0, 49.5],
      "precipitation_sum":  [0.0, 0.02]
    }
  }
  ```

- **Notes:** Response is **column-oriented** — every variable in `hourly`/`daily` is an array, all arrays in a block share the index of `time`. Read variable `i` at hour `j` as `response.hourly[var][j]`.

## Variable lists

### Current variables (`current=`)

```
temperature_2m, relative_humidity_2m, apparent_temperature, is_day,
precipitation, rain, showers, snowfall,
weather_code, cloud_cover,
pressure_msl, surface_pressure,
wind_speed_10m, wind_direction_10m, wind_gusts_10m
```

### Hourly variables (`hourly=`)

**Temperature/humidity:**
`temperature_2m, relative_humidity_2m, dew_point_2m, apparent_temperature, wet_bulb_temperature_2m`

**Pressure:**
`pressure_msl, surface_pressure`

**Cloud / visibility:**
`cloud_cover, cloud_cover_low, cloud_cover_mid, cloud_cover_high, visibility`

**Wind:**
`wind_speed_10m, wind_speed_80m, wind_speed_120m, wind_speed_180m,
wind_direction_10m, wind_direction_80m, wind_direction_120m, wind_direction_180m,
wind_gusts_10m`

**Precipitation:**
`precipitation, rain, showers, snowfall, snow_depth, precipitation_probability`

**Solar radiation:**
`shortwave_radiation (GHI), direct_radiation, diffuse_radiation (DHI),
direct_normal_irradiance (DNI), global_tilted_irradiance (GTI),
terrestrial_radiation`,
plus `_instant` variants for each (e.g. `shortwave_radiation_instant`).

**Soil:**
`soil_temperature_0cm, soil_temperature_6cm, soil_temperature_18cm, soil_temperature_54cm,
 soil_moisture_0_to_1cm, soil_moisture_1_to_3cm, soil_moisture_3_to_9cm,
 soil_moisture_9_to_27cm, soil_moisture_27_to_81cm`

**Atmospheric:**
`weather_code, cape, evapotranspiration, et0_fao_evapotranspiration,
 vapour_pressure_deficit, freezing_level_height, lifted_index,
 convective_inhibition, boundary_layer_height`

**Other:**
`uv_index, uv_index_clear_sky, is_day, sunshine_duration, total_column_water_vapour`

### 15-minutely variables (`minutely_15=`)

Available primarily over Central Europe / North America:

```
temperature_2m, relative_humidity_2m, dew_point_2m, apparent_temperature,
precipitation, rain, showers, snowfall, snowfall_height, freezing_level_height,
sunshine_duration, weather_code,
wind_speed_10m, wind_speed_80m, wind_direction_10m, wind_direction_80m, wind_gusts_10m,
visibility, cape, lightning_potential, is_day,
shortwave_radiation, direct_radiation, diffuse_radiation,
direct_normal_irradiance, global_tilted_irradiance, terrestrial_radiation
```

### Daily variables (`daily=`)

**Temperature:**
`temperature_2m_max, temperature_2m_min, temperature_2m_mean,
 apparent_temperature_max, apparent_temperature_min, apparent_temperature_mean`

**Precipitation:**
`precipitation_sum, rain_sum, showers_sum, snowfall_sum, precipitation_hours,
 precipitation_probability_max, precipitation_probability_mean, precipitation_probability_min`

**Solar / UV:**
`shortwave_radiation_sum, uv_index_max, uv_index_clear_sky_max,
 sunshine_duration, daylight_duration`

**Wind:**
`wind_speed_10m_max, wind_gusts_10m_max, wind_direction_10m_dominant`

**Other:**
`weather_code, sunrise, sunset,
 et0_fao_evapotranspiration,
 cloud_cover_max, cloud_cover_mean, cloud_cover_min,
 dew_point_2m_max, dew_point_2m_mean, dew_point_2m_min,
 relative_humidity_2m_max, relative_humidity_2m_mean, relative_humidity_2m_min,
 pressure_msl_max, pressure_msl_mean, pressure_msl_min,
 surface_pressure_max, surface_pressure_mean, surface_pressure_min,
 visibility_max, visibility_mean, visibility_min,
 growing_degree_days, leaf_wetness_probability_mean`

### Pressure-level variables

19 levels (1000 hPa down to 30 hPa). Append the level: `temperature_1000hPa`, `wind_speed_500hPa`, etc.

```
temperature, relative_humidity, dew_point, cloud_cover,
wind_speed, wind_direction, geopotential_height
```

## Weather codes (`weather_code`)

WMO code values used in `current.weather_code`, `hourly.weather_code`, and `daily.weather_code`. Common values:

| Code | Meaning |
|---|---|
| 0 | Clear sky |
| 1, 2, 3 | Mainly clear, partly cloudy, overcast |
| 45, 48 | Fog, depositing rime fog |
| 51, 53, 55 | Drizzle: light, moderate, dense |
| 56, 57 | Freezing drizzle: light, dense |
| 61, 63, 65 | Rain: slight, moderate, heavy |
| 66, 67 | Freezing rain: light, heavy |
| 71, 73, 75 | Snowfall: slight, moderate, heavy |
| 77 | Snow grains |
| 80, 81, 82 | Rain showers: slight, moderate, violent |
| 85, 86 | Snow showers: slight, heavy |
| 95 | Thunderstorm: slight or moderate |
| 96, 99 | Thunderstorm with slight, heavy hail |

## Rate limits

- Not explicitly enumerated on the docs page reviewed. Open-Meteo publishes a fair-use threshold (commonly cited as ~10,000 calls/day for the free tier) elsewhere in its pricing/plans; free use is throttled rather than hard-capped.
- For higher volume or commercial use, switch to the `customer-` host with an `apikey`.

## Response format conventions

- **JSON only.**
- **Column-oriented** time series: each forecast block (`hourly`, `daily`, `minutely_15`) returns parallel arrays keyed by variable name, with `time` as the alignment index.
- Units are reported back in `*_units` sibling objects (e.g. `hourly_units.temperature_2m: "°F"`).
- `generationtime_ms` reports server-side compute time.
- `utc_offset_seconds` and `timezone_abbreviation` make local-time conversion straightforward when `timezone=auto`.

## Known issues / gotchas

- **`daily=` requires `timezone=`.** Without it, day boundaries default to UTC and may not match the user's expectation.
- **Variable names are case-sensitive** and must use exact underscores (e.g. `temperature_2m`, not `temperature2m`).
- **15-minute resolution is regional** (Central Europe / North America); requests outside coverage may return nulls.
- **Multiple locations:** `latitude=47.6,40.7&longitude=-122.3,-74.0` returns an array of forecast objects rather than a single one — code must handle both.
- **Historical data on this endpoint is limited** to `past_days=92`. Deeper history requires the separate `https://archive-api.open-meteo.com/v1/archive` endpoint.
- On invalid params the API returns `HTTP 400` with `{"error": true, "reason": "..."}`.
