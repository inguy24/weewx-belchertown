# Canonical data model

**Status:** Draft (Phase 1 deliverable; companion to [`openapi-v1.yaml`](openapi-v1.yaml) and [ADR-010](../decisions/ADR-010-canonical-data-model.md))
**Last updated:** 2026-05-05

This document is the exhaustive catalog [ADR-010](../decisions/ADR-010-canonical-data-model.md) defers and that [`openapi-v1.yaml`](openapi-v1.yaml) deliberately does not duplicate. Three things live here that no other artifact owns:

1. **Per-field enumeration** for every canonical entity, including the weewx-source columns and provider-source fields that resolve to each canonical name.
2. **Per-field unit mapping** for each weewx `target_unit` system (US / METRIC / METRICWX) — populates the `units` block every API response embeds per [ADR-019](../decisions/ADR-019-units-handling.md).
3. **Provider → canonical mapping tables** for every day-1 provider in [ADR-007](../decisions/ADR-007-forecast-providers.md), [ADR-013](../decisions/ADR-013-aqi-handling.md), [ADR-016](../decisions/ADR-016-severe-weather-alerts.md), [ADR-040](../decisions/ADR-040-earthquake-providers.md), [ADR-015](../decisions/ADR-015-radar-map-tiles-strategy.md).

When this document and ADR-010 disagree, ADR-010 wins; when this document and `openapi-v1.yaml` disagree, the OpenAPI wins for wire-shape questions and this document wins for unit-mapping and provider-mapping questions. Drift is a bug — fix the spec, not the ADR / OpenAPI.

---

## 1. Naming and serialization

Recap of [ADR-010](../decisions/ADR-010-canonical-data-model.md) §Decision; this section is a one-paragraph pointer, not a re-derivation.

- **One name per field**, in weewx-aligned camelCase. Identical spelling in Python attribute and JSON key (`outTemp`, `windSpeed`, `precipProbability`). No alias mechanism, no two-name bridge. PEP 8's mixed-case warning (ruff `N815`) is suppressed per-file for `weewx_clearskies_api/models/canonical.py` — PEP 8 is a style guide, not a language rule.
- weewx-aligned names where weewx has a name (`outTemp`, `windSpeed`, `barometer`, `dewpoint`, `windchill`, `heatindex`, `rainRate`, `radiation`, `UV`, …).
- Forecast-only camelCase invented to fit (`precipProbability`, `precipType`, `cloudCover`, `weatherCode`, `weatherText`, `tempMax`, `tempMin`, `validTime`, `validDate`).
- All-fields-optional: every observation/forecast field is `T | None`. `exclude_none=False` — keys always present, `null` for missing.
- Time: UTC ISO-8601 with explicit `Z` suffix on the wire; Python `datetime` with `tzinfo=UTC`.
- Provenance: every entity carries `source: str`. `"weewx"` for archive-derived; provider id for upstream-derived.

The catalog below uses these field names verbatim — same in Python and JSON.

---

## 2. weewx unit systems and the `units` block

> **Internal-implementation reference.** §2.1's group→unit table is a startup lookup used by `services/units.py` to populate the `units` block on each response. **weewx groups are NOT exposed on the wire** — every API response carries a flat per-field unit map, not a per-group one. The dashboard sees `{ "outTemp": "°F", "windSpeed": "mph", … }`, never group names. This section documents the lookup so a future implementer can rebuild it; it is not part of the dashboard's contract.

Every API response embeds a `units` object mapping each canonical field name to a unit string. The unit reflects whatever weewx is configured to write that field in (its `[StdConvert] target_unit`). The server does not convert per [ADR-019](../decisions/ADR-019-units-handling.md).

Three unit-system presets are loaded at startup. The table below enumerates the unit string per field per system. Source: [`docs/reference/weewx-5.3/reference/units.md`](../reference/weewx-5.3/reference/units.md), unit-group definitions verbatim.

### 2.1 Unit-system reference

| weewx group | Members (canonical fields) | US | METRIC | METRICWX |
|---|---|---|---|---|
| group_temperature | outTemp, dewpoint, windchill, heatindex, inTemp, appTemp, extraTemp1..N, soilTemp1..4, leafTemp1..2, heatingTemp, humidex, THSW, tempMax, tempMin | `°F` | `°C` | `°C` |
| group_speed | windSpeed, windGust, wind, windgustvec, windvec, windSpeedMax, windGustMax | `mph` | `km/h` | `m/s` |
| group_speed2 | rms, vecavg | `mph` | `km/h` | `m/s` |
| group_direction | windDir, windGustDir, gustdir, vecdir | `°` | `°` | `°` |
| group_pressure | barometer, altimeter, pressure | `inHg` | `mbar` | `mbar` |
| group_pressurerate | barometerRate, altimeterRate, pressureRate | `inHg/h` | `mbar/h` | `mbar/h` |
| group_rain | rain, ET, hail, snowDepth, snowRate, precipAmount | `in` | `cm` | `mm` |
| group_rainrate | rainRate, hailRate | `in/h` | `cm/h` | `mm/h` |
| group_radiation | radiation, maxSolarRad | `W/m²` | `W/m²` | `W/m²` |
| group_uv | UV, uvIndexMax | `uv_index` | `uv_index` | `uv_index` |
| group_percent | outHumidity, inHumidity, extraHumid1..N, cloudcover, cloudCover, pop, precipProbability, precipProbabilityMax, rxCheckPercent, snowMoisture | `%` | `%` | `%` |
| group_moisture | soilMoist1..4 | `cb` | `cb` | `cb` |
| group_count | leafWet1..2, lightning_strike_count, lightning_disturber_count, lightning_noise_count, felt | `count` | `count` | `count` |
| group_distance | windrun, lightning_distance | `mile` | `km` | `km` |
| group_altitude | altitude, cloudbase | `foot` | `meter` | `meter` |
| group_volt | consBatteryVoltage, heatingVoltage, referenceVoltage, supplyVoltage | `V` | `V` | `V` |
| group_amp | (operator-defined) | `amp` | `amp` | `amp` |
| group_power | (operator-defined) | `W` | `W` | `W` |
| group_energy | (operator-defined) | `Wh` | `Wh` | `Wh` |
| group_energy2 | (operator-defined) | `Ws` | `Ws` | `Ws` |
| group_data | (operator-defined) | `byte` | `byte` | `byte` |
| group_db | noise | `dB` | `dB` | `dB` |
| group_deltatime | rainDur, daySunshineDur, sunshineDurDoc | `s` | `s` | `s` |
| group_degree_day | cooldeg, heatdeg, growdeg | `°F·day` | `°C·day` | `°C·day` |
| group_concentration | pollutantPM25, pollutantPM10, pm1_0, pm2_5, pm10_0, no2 | `µg/m³` | `µg/m³` | `µg/m³` |
| group_fraction | pollutantO3, pollutantSO2, pollutantCO, pollutantNO2, co, co2, nh3, o3, pb, so2, nh3 | `ppm` | `ppm` | `ppm` |
| group_frequency | (operator-defined) | `Hz` | `Hz` | `Hz` |
| group_illuminance | illuminance | `lx` | `lx` | `lx` |
| group_interval | interval | `minute` | `minute` | `minute` |
| group_length | (operator-defined) | `inch` | `cm` | `cm` |
| group_volume | (operator-defined) | `gallon` | `liter` | `liter` |
| group_NONE | NONE | (no unit) | (no unit) | (no unit) |

### 2.2 Operator overrides change the per-field unit

The §2.1 table is the **system default per `target_unit`**. weewx allows operators to override individual fields via `[StdConvert]` and via per-skin `[Units] [[Groups]]` blocks (see [`docs/reference/weewx-5.3/reference/weewx-options/stdconvert.md`](../reference/weewx-5.3/reference/weewx-options/stdconvert.md)). For example, an operator on METRIC may force `group_pressure` to `hPa` instead of the default `mbar`, or force `group_speed` to `knot`.

**The api's startup must respect operator overrides, not just the system label.** The `services/units.py` module reads weewx's actual configured unit per group, not just the `target_unit` system identifier, and constructs the response `units` block from that. The §2.1 table is the fallback when no override is set.

### 2.3 Unit-string presentation rule

The `units` block emits the **display-friendly** form shown in §2.1 (`°F`, `mph`, `inHg`). Inside the api, the Python `services/units.py` module also keeps the weewx-canonical form (`degree_F`, `mile_per_hour`, `inHg`) for round-tripping with weewx's internal converters — that internal form is not part of the wire contract.

When weewx emits a field that doesn't appear above (operator-added column not yet promoted via [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md)), the field appears under `extras` and the `units` block carries no entry for it. The dashboard renders extras in a generic "Other observations" panel labeled by column name; per-extras unit metadata is acquired via the ADR-035 promotion flow.

### 2.4 Earthquakes are unit-system-invariant

`EarthquakeRecord` fields are agency-canonical, not weewx target_unit-driven:

- `latitude`/`longitude`: degrees (WGS84, signed; west of Greenwich negative).
- `depth`: kilometers below surface.
- `magnitude`: dimensionless.
- `mmi`: dimensionless (Modified Mercalli Intensity).
- `time`: UTC ISO-8601.

These do not appear in any response's `units` block. Earthquake provider modules do **not** call the units conversion layer.

---

## 3. Entity catalog

Each subsection enumerates the entity's full first-class field set. Operator-custom weewx columns route through `extras` (typed `dict[str, float | int | str | bool | None]`, keyed by the weewx column name verbatim) and are not enumerated here.

Entity types:

1. [`Observation`](#31-observation) — most-recent point reading from the weewx archive.
2. [`ArchiveRecord`](#32-archiverecord) — one archive interval row (used by `/archive` for history).
3. [`HourlyForecastPoint`](#33-hourlyforecastpoint) — one hourly forecast entry.
4. [`DailyForecastPoint`](#34-dailyforecastpoint) — one daily forecast entry.
5. [`ForecastDiscussion`](#35-forecastdiscussion) — free-form prose forecast.
6. [`AlertRecord`](#36-alertrecord) — one severe-weather alert.
7. [`EarthquakeRecord`](#37-earthquakerecord) — one earthquake event.
8. [`AQIReading`](#38-aqireading) — one AQI snapshot.
9. [`StationMetadata`](#39-stationmetadata) — station identity.

Containers:

10. [`ForecastBundle`](#310-forecastbundle) — `hourly` + `daily` + `discussion`.
11. [`AlertList`](#311-alertlist) — list of `AlertRecord`.

Plus almanac/records/page/chart/capability entities native to the OpenAPI; those are not weewx-data-bearing and are documented inline in the OpenAPI spec, not duplicated here.

### 3.1 Observation

Most-recent observation from the weewx archive (latest record within a small look-back window). The field set is **the FULL stock weewx column set** — every column in `wview` and `wview_extended` is a first-class field on this schema. Operator-custom columns route through `extras` per [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md). `extras` does NOT carry stock weewx columns.

Operators with archive schemas that omit a field (e.g., a wview-only install will not have `appTemp`) see `null` for that field; the JSON key is always present.

| JSON key | Type | Nullable | Unit group | weewx archive column | Notes |
|---|---|---|---|---|---|
| `timestamp` | string (date-time UTC) | No | — | `dateTime` (epoch s) | Converted at ingest. |
| **Core wview observation fields** | | | | | |
| `outTemp` | number | Yes | group_temperature | `outTemp` | Outdoor temperature. |
| `outHumidity` | number | Yes | group_percent | `outHumidity` | 0–100. |
| `windSpeed` | number | Yes | group_speed | `windSpeed` | |
| `windDir` | number | Yes | group_direction | `windDir` | 0–360 from true north. |
| `windGust` | number | Yes | group_speed | `windGust` | |
| `windGustDir` | number | Yes | group_direction | `windGustDir` | |
| `barometer` | number | Yes | group_pressure | `barometer` | |
| `pressure` | number | Yes | group_pressure | `pressure` | Station pressure. |
| `altimeter` | number | Yes | group_pressure | `altimeter` | |
| `dewpoint` | number | Yes | group_temperature | `dewpoint` | |
| `windchill` | number | Yes | group_temperature | `windchill` | |
| `heatindex` | number | Yes | group_temperature | `heatindex` | |
| `rainRate` | number | Yes | group_rainrate | `rainRate` | |
| `rain` | number | Yes | group_rain | `rain` | Per-interval accumulation. |
| `radiation` | number | Yes | group_radiation | `radiation` | Solar irradiance. |
| `UV` | number | Yes | group_uv | `UV` | |
| `inTemp` | number | Yes | group_temperature | `inTemp` | |
| `inHumidity` | number | Yes | group_percent | `inHumidity` | |
| **wview_extended core fields** | | | | | |
| `ET` | number | Yes | group_rain | `ET` | Evapotranspiration. |
| `hail` | number | Yes | group_rain | `hail` | Per-interval accumulation. |
| `hailRate` | number | Yes | group_rainrate | `hailRate` | |
| `appTemp` | number | Yes | group_temperature | `appTemp` | Apparent ("feels-like") temperature. |
| `cloudbase` | number | Yes | group_altitude | `cloudbase` | Calculated from temp/dewpoint/altitude. |
| `cloudcover` | number | Yes | group_percent | `cloudcover` | 0–100. |
| `windrun` | number | Yes | group_distance | `windrun` | Wind run = ∑(windSpeed × interval). |
| `maxSolarRad` | number | Yes | group_radiation | `maxSolarRad` | Theoretical clear-sky solar radiation. |
| `sunshineDur` | number | Yes | group_deltatime | `sunshineDur` | Duration of sunshine within the interval. |
| `daySunshineDur` | number | Yes | group_deltatime | `daySunshineDur` | Day-to-date cumulative sunshine. |
| `rainDur` | number | Yes | group_deltatime | `rainDur` | Duration of rainfall within the interval. |
| `THSW` | number | Yes | group_temperature | `THSW` | Temperature-Humidity-Sun-Wind (Davis VP series). |
| `humidex` | number | Yes | group_temperature | `humidex` | Canadian humidex index. |
| `pop` | number | Yes | group_percent | `pop` | Probability of precipitation (operator/extension-supplied). |
| `illuminance` | number | Yes | group_illuminance | `illuminance` | Light level in lux. |
| `noise` | number | Yes | group_db | `noise` | Sound level in dB. |
| **Lightning fields (wview_extended)** | | | | | |
| `lightning_strike_count` | number | Yes | group_count | `lightning_strike_count` | Strikes within the interval. |
| `lightning_distance` | number | Yes | group_distance | `lightning_distance` | Distance to the most recent strike. |
| `lightning_noise_count` | number | Yes | group_count | `lightning_noise_count` | |
| `lightning_disturber_count` | number | Yes | group_count | `lightning_disturber_count` | |
| **Snow fields (wview_extended)** | | | | | |
| `snow` | number | Yes | group_rain | `snow` | Per-interval accumulation. |
| `snowDepth` | number | Yes | group_rain | `snowDepth` | Total depth on ground. |
| `snowRate` | number | Yes | group_rainrate | `snowRate` | |
| **Wind summary fields** (typically populated only on archives where weewx promotes the wind aggregate from `archive_day_wind`) | | | | | |
| `vecdir` | number | Yes | group_direction | `vecdir` | Vector-mean wind direction. |
| `gustdir` | number | Yes | group_direction | `gustdir` | Direction of peak gust. |
| `vecavg` | number | Yes | group_speed2 | `vecavg` | Vector-mean wind speed. |
| `rms` | number | Yes | group_speed2 | `rms` | Root-mean-square wind speed. |
| **Degree-days** | | | | | |
| `heatdeg` | number | Yes | group_degree_day | `heatdeg` | Heating degree-days. |
| `cooldeg` | number | Yes | group_degree_day | `cooldeg` | Cooling degree-days. |
| **Sensor expansion slots (wview_extended)** | | | | | |
| `extraTemp1`, `extraTemp2`, `extraTemp3` | number | Yes | group_temperature | `extraTemp1..3` | |
| `extraHumid1`, `extraHumid2` | number | Yes | group_percent | `extraHumid1..2` | |
| `soilTemp1` … `soilTemp4` | number | Yes | group_temperature | `soilTemp1..4` | |
| `soilMoist1` … `soilMoist4` | number | Yes | group_moisture | `soilMoist1..4` | |
| `leafTemp1`, `leafTemp2` | number | Yes | group_temperature | `leafTemp1..2` | |
| `leafWet1`, `leafWet2` | number | Yes | group_count | `leafWet1..2` | |
| **Electrical / system telemetry** | | | | | |
| `consBatteryVoltage` | number | Yes | group_volt | `consBatteryVoltage` | |
| `heatingVoltage` | number | Yes | group_volt | `heatingVoltage` | |
| `referenceVoltage` | number | Yes | group_volt | `referenceVoltage` | |
| `supplyVoltage` | number | Yes | group_volt | `supplyVoltage` | |
| `rxCheckPercent` | number | Yes | group_percent | `rxCheckPercent` | Sensor reception health 0–100. |
| **Containers** | | | | | |
| `extras` | object | No | — | (see ADR-035) | **Operator-custom** columns only. Keys are weewx column names verbatim. May be empty. Stock weewx columns NEVER appear here. |
| `source` | string | No | — | — | Always `"weewx"` for archive-derived. |

**OpenAPI mapping:** [`#/components/schemas/Observation`](openapi-v1.yaml).

**Provenance.** The first-class field set above mirrors `STOCK_COLUMN_MAP` in `weewx_clearskies_api/db/reflection.py` (the stock-column lookup table loaded at startup by the schema reflector per [ADR-012](../decisions/ADR-012-database-access-pattern.md) + [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md)). When weewx adds a new stock column, both the lookup table and this section get a new entry; `extras` is reserved for operator extensions. Columns the operator's archive schema doesn't include surface as `null` — the JSON key is always present.

### 3.2 ArchiveRecord

`ArchiveRecord = Observation + interval`. Used by `/archive` for the historical time series. All fields above plus:

| JSON key | Type | Nullable | Unit group | weewx archive column | Notes |
|---|---|---|---|---|---|
| `interval` | integer | No | group_interval | `interval` | Archive interval length, minutes (typical 5). |

**OpenAPI mapping:** [`#/components/schemas/ArchiveRecord`](openapi-v1.yaml).

### 3.3 HourlyForecastPoint

One hour of provider forecast.

| JSON key | Type | Nullable | Unit group | Notes |
|---|---|---|---|---|
| `validTime` | string (date-time UTC) | No | — | Beginning of the hour. |
| `outTemp` | number | Yes | group_temperature | |
| `outHumidity` | number | Yes | group_percent | |
| `windSpeed` | number | Yes | group_speed | |
| `windDir` | number | Yes | group_direction | |
| `windGust` | number | Yes | group_speed | |
| `precipProbability` | number | Yes | group_percent | 0–100. |
| `precipAmount` | number | Yes | group_rain | Hourly accumulation. |
| `precipType` | string | Yes | — | `"rain"`, `"snow"`, `"sleet"`, `"freezing-rain"`, `"hail"`, `"none"` (best-effort; provider-dependent vocabulary normalized). |
| `cloudCover` | number | Yes | group_percent | 0–100. |
| `weatherCode` | string | Yes | — | Provider-defined code (e.g. WMO, NWS icon path, OWM `id`). Opaque to api; dashboard maps to icon. |
| `weatherText` | string | Yes | — | Short label, "Mostly sunny", "Light rain". |
| `extras` | object | No | — | Provider-specific fields not in canonical model. |
| `source` | string | No | — | Provider id. |

**OpenAPI mapping:** [`#/components/schemas/HourlyForecastPoint`](openapi-v1.yaml).

### 3.4 DailyForecastPoint

One day of provider forecast.

| JSON key | Type | Nullable | Unit group | Notes |
|---|---|---|---|---|
| `validDate` | string (date) | No | — | YYYY-MM-DD station-local. |
| `tempMax` | number | Yes | group_temperature | |
| `tempMin` | number | Yes | group_temperature | |
| `precipAmount` | number | Yes | group_rain | Daily total. |
| `precipProbabilityMax` | number | Yes | group_percent | 0–100. |
| `windSpeedMax` | number | Yes | group_speed | |
| `windGustMax` | number | Yes | group_speed | |
| `sunrise` | string (date-time UTC) | Yes | — | Day's sunrise; provider-supplied or skyfield-computed. |
| `sunset` | string (date-time UTC) | Yes | — | |
| `uvIndexMax` | number | Yes | group_uv | |
| `weatherCode` | string | Yes | — | |
| `weatherText` | string | Yes | — | Short label. |
| `narrative` | string | Yes | — | Multi-sentence summary (NWS, some Aeris plans). |
| `extras` | object | No | — | |
| `source` | string | No | — | |

**OpenAPI mapping:** [`#/components/schemas/DailyForecastPoint`](openapi-v1.yaml).

### 3.5 ForecastDiscussion

Free-form prose forecast (NWS Area Forecast Discussion or Aeris weather summary normalized into this shape).

| JSON key | Type | Nullable | Notes |
|---|---|---|---|
| `headline` | string | Yes | One-line summary. NWS uses the AFD's leading "AFD" tag, etc. |
| `body` | string | No | Plain text or basic Markdown. NWS AFD is fixed-width plain text. |
| `issuedAt` | string (date-time UTC) | No | |
| `validFrom` | string (date-time UTC) | Yes | |
| `validUntil` | string (date-time UTC) | Yes | |
| `senderName` | string | Yes | "NWS Seattle WA". |
| `source` | string | No | Provider id (`nws`, `aeris`, etc.). |

**OpenAPI mapping:** [`#/components/schemas/ForecastDiscussion`](openapi-v1.yaml).

### 3.6 AlertRecord

One severe-weather alert from the configured alerts provider.

| JSON key | Type | Nullable | Notes |
|---|---|---|---|
| `id` | string | No | Provider's stable alert id. |
| `headline` | string | No | Single-line summary. |
| `description` | string | No | Multi-sentence body. |
| `severity` | string enum | No | `advisory` / `watch` / `warning`. Normalized from provider vocab — see §4.3. |
| `urgency` | string | Yes | NWS CAP vocabulary — Immediate / Expected / Future / Past / Unknown. |
| `certainty` | string | Yes | NWS CAP vocabulary — Observed / Likely / Possible / Unlikely / Unknown. |
| `event` | string | No | Provider's event name ("Wind Advisory", "Tornado Warning"). |
| `effective` | string (date-time UTC) | No | |
| `expires` | string (date-time UTC) | Yes | |
| `senderName` | string | Yes | "NWS Seattle WA". |
| `areaDesc` | string | Yes | "King, WA". Free-form provider description of affected area. |
| `category` | string | Yes | NWS CAP vocabulary — Met / Geo / Safety / Security / etc. |
| `source` | string | No | Provider id. |

**OpenAPI mapping:** [`#/components/schemas/AlertRecord`](openapi-v1.yaml).

### 3.7 EarthquakeRecord

One earthquake event from the configured earthquake provider per [ADR-040](../decisions/ADR-040-earthquake-providers.md).

| JSON key | Type | Nullable | Notes |
|---|---|---|---|
| `id` | string | No | Provider's stable event id. |
| `time` | string (date-time UTC) | No | Origin time. |
| `latitude` | number | No | WGS84 degrees. |
| `longitude` | number | No | WGS84 degrees. |
| `magnitude` | number | No | Dimensionless; type in `magnitudeType`. |
| `magnitudeType` | string | Yes | `mw`, `ml`, `md`, `mb`, etc. |
| `depth` | number | Yes | Kilometers below surface. |
| `place` | string | Yes | Human-readable location ("12 km NE of Wellington"). |
| `url` | string (uri) | Yes | Detail page on the provider's site. |
| `tsunami` | boolean | Yes | Tsunami flag (USGS). |
| `felt` | integer | Yes | Count of "did you feel it" reports (USGS). |
| `mmi` | number | Yes | Modified Mercalli Intensity (USGS estimate or GeoNet measured). |
| `alert` | string enum | Yes | `green` / `yellow` / `orange` / `red` (USGS PAGER). `null` for non-USGS. |
| `status` | string | Yes | Review status — provider vocabulary (`automatic`, `reviewed`, `deleted`, `best`, `preliminary`). |
| `extras` | object | No | Provider-specific fields. |
| `source` | string | No | Provider id. |

**OpenAPI mapping:** [`#/components/schemas/EarthquakeRecord`](openapi-v1.yaml).

### 3.8 AQIReading

AQI snapshot. EPA 0–500 scale per [ADR-013](../decisions/ADR-013-aqi-handling.md).

| JSON key | Type | Nullable | Unit group | Notes |
|---|---|---|---|---|
| `aqi` | number | Yes | — | 0–500 integer (EPA scale). |
| `aqiCategory` | string | Yes | — | EPA category — `Good` / `Moderate` / `Unhealthy for Sensitive Groups` / `Unhealthy` / `Very Unhealthy` / `Hazardous`. |
| `aqiMainPollutant` | string | Yes | — | Canonical pollutant id — `PM2.5`, `PM10`, `O3`, `NO2`, `SO2`, `CO`. |
| `aqiLocation` | string | Yes | — | Free-form provider location label. |
| `pollutantPM25` | number | Yes | group_concentration | µg/m³. |
| `pollutantPM10` | number | Yes | group_concentration | µg/m³. |
| `pollutantO3` | number | Yes | group_fraction | ppm. |
| `pollutantNO2` | number | Yes | group_fraction | ppm. |
| `pollutantSO2` | number | Yes | group_fraction | ppm. |
| `pollutantCO` | number | Yes | group_fraction | ppm. |
| `observedAt` | string (date-time UTC) | No | — | |
| `source` | string | No | — | `"weewx"` for Path A; provider id for Path B. |

**OpenAPI mapping:** [`#/components/schemas/AQIReading`](openapi-v1.yaml).

Note on units: `pollutantO3/NO2/SO2/CO` are weewx group_fraction (ppm). Provider responses in µg/m³ (most non-US providers) need conversion at ingest in the AQI provider module — using molecular weight + standard atmosphere. The conversion table belongs in the provider module, not here.

### 3.9 StationMetadata

Station identity. One per deploy per [ADR-011](../decisions/ADR-011-multi-station-scope.md).

| JSON key | Type | Nullable | Unit group | Notes |
|---|---|---|---|---|
| `stationId` | string | No | — | Operator-supplied stable id (e.g. config-derived). |
| `name` | string | No | — | Human-readable. |
| `latitude` | number | No | — | WGS84 degrees. |
| `longitude` | number | No | — | WGS84 degrees. |
| `altitude` | number | No | group_altitude | Above mean sea level. |
| `timezone` | string | No | — | IANA TZ identifier per [ADR-020](../decisions/ADR-020-time-zone-handling.md). |
| `timezoneOffsetMinutes` | integer | No | — | Current offset, minutes. |
| `unitSystem` | string enum | No | — | `US` / `METRIC` / `METRICWX`. |
| `firstRecord` | string (date-time UTC) | Yes | — | Oldest archive row's timestamp. |
| `lastRecord` | string (date-time UTC) | Yes | — | Newest archive row's timestamp. |
| `hardware` | string | Yes | — | weewx-reported station hardware type. |

**OpenAPI mapping:** [`#/components/schemas/StationMetadata`](openapi-v1.yaml).

### 3.10 ForecastBundle

Container shape `/forecast` returns.

| JSON key | Type | Nullable | Notes |
|---|---|---|---|
| `hourly` | array<HourlyForecastPoint> | No | May be empty if provider omits hourly. |
| `daily` | array<DailyForecastPoint> | No | May be empty if provider omits daily. |
| `discussion` | ForecastDiscussion or `null` | Yes | `null` for providers without one (Open-Meteo, OWM, Wunderground PWS). |
| `source` | string | No | Provider id. |
| `generatedAt` | string (date-time UTC) | No | When the api assembled this bundle. |

**OpenAPI mapping:** [`#/components/schemas/ForecastBundle`](openapi-v1.yaml).

### 3.11 AlertList

Container shape `/alerts` returns.

| JSON key | Type | Nullable | Notes |
|---|---|---|---|
| `alerts` | array<AlertRecord> | No | Empty list when no alerts (NOT an error per ADR-016). |
| `retrievedAt` | string (date-time UTC) | No | |
| `source` | string | No | Provider id. |

**OpenAPI mapping:** [`#/components/schemas/AlertList`](openapi-v1.yaml).

---

## 4. Provider → canonical mapping tables

> **Internal-implementation reference.** These tables document each provider normalizer's wire-field-to-canonical-field mapping. The dashboard never sees provider-specific fields — by the time JSON reaches the dashboard, normalization has already happened. This section exists so a future implementer (or operator adding a new provider module per [ADR-038](../decisions/ADR-038-data-provider-module-organization.md)) can rebuild a normalizer correctly.

Each table maps the provider's wire field to the canonical field. Where the provider's response carries values in a non-target unit, the mapping note flags the conversion the normalizer module must perform. Capabilities not supplied by a provider get a "—" cell — the normalizer leaves the canonical field `null` per ADR-010 §Decision.4.

Sources for every table: the provider's own API documentation captured in [`docs/reference/api-docs/`](../reference/api-docs/) and (for earthquake providers) [`EARTHQUAKE-PROVIDER-RESEARCH.md`](../reference/EARTHQUAKE-PROVIDER-RESEARCH.md).

### 4.1 Forecast providers (per [ADR-007](../decisions/ADR-007-forecast-providers.md))

Day-1 set: `aeris`, `nws`, `openmeteo`, `openweathermap`, `wunderground`.

#### 4.1.1 Current observation (HourlyForecastPoint shape — used as latest-hour fallback when archive is empty / forecast endpoint serves "current")

| Canonical | aeris (`/observations`) | nws (`/stations/{id}/observations/latest`) | openmeteo (`/v1/forecast?current=`) | openweathermap (`/data/2.5/weather`) | wunderground (`/v2/pws/observations/current`) |
|---|---|---|---|---|---|
| `validTime` | `ob.dateTimeISO` | `properties.timestamp` | `current.time` | `dt` (epoch s, convert) | `observations[0].obsTimeUtc` |
| `outTemp` | `ob.tempF`/`ob.tempC` (pick by target_unit) | `properties.temperature.value` (always °C) | `current.temperature_2m` | `main.temp` | `observations[0].imperial.temp`/`metric.temp` |
| `outHumidity` | `ob.humidity` | `properties.relativeHumidity.value` | `current.relative_humidity_2m` | `main.humidity` | `observations[0].humidity` |
| `windSpeed` | `ob.windSpeedMPH`/`KPH`/`MPS` | `properties.windSpeed.value` (always km/h) | `current.wind_speed_10m` | `wind.speed` | `observations[0].imperial.windSpeed`/`metric.windSpeed` |
| `windDir` | `ob.windDirDEG` | `properties.windDirection.value` | `current.wind_direction_10m` | `wind.deg` | `observations[0].winddir` |
| `windGust` | `ob.windGustMPH`/`KPH`/`MPS` | — | `current.wind_gusts_10m` | `wind.gust` | `observations[0].imperial.windGust` |
| `barometer` | `ob.pressureIN`/`MB` | `properties.barometricPressure.value` (always Pa) | — | `main.pressure` (always hPa) | `observations[0].imperial.pressure` |
| `dewpoint` | `ob.dewpointF`/`C` | `properties.dewpoint.value` (always °C) | `current.dew_point_2m` (One Call) / — (Forecast 3.0) | — (current free) / `current.dew_point` (One Call 3.0) | `observations[0].imperial.dewpt` |
| `weatherCode` | `ob.weatherPrimaryCoded` | derived from `properties.icon` | `current.weather_code` (WMO) | `weather[0].id` | — |
| `weatherText` | `ob.weatherShort` | `properties.textDescription` | (decode from WMO code) | `weather[0].description` | — |

Notes:

- **NWS observation values are always SI** (°C, km/h, Pa). The normalizer converts to target units regardless of operator preference.
- **NWS forecast `windSpeed` is a string range** (`"5 to 10 mph"`) — the normalizer parses to numeric, taking the upper bound (matches "windSpeedMax" semantics where one number is needed).
- **OWM `wind.speed` unit varies with `units=` param**: `m/s` for `standard`/`metric`, `mph` for `imperial`. The normalizer requests with the unit matching target_unit.
- **OWM precipitation probability `pop`** is `0..1`, not `0..100` — multiply by 100 in the normalizer.
- **Wunderground PWS `observations[0]`** has `imperial` and `metric` sub-objects; the normalizer picks the one matching target_unit. Wunderground does not supply hourly forecast, alerts, or discussion.

#### 4.1.2 Hourly forecast (HourlyForecastPoint)

| Canonical | aeris (`/forecasts` hourly interval) | nws (`/gridpoints/.../forecast/hourly`) | openmeteo (`/v1/forecast?hourly=`) | openweathermap (`/data/3.0/onecall` hourly) | wunderground |
|---|---|---|---|---|---|
| `validTime` | `periods[].dateTimeISO` | `properties.periods[].startTime` | `hourly.time[i]` | `hourly[].dt` (epoch s, convert) | not supplied |
| `outTemp` | `periods[].tempF`/`C` | `periods[].temperature` (with `temperatureUnit`) | `hourly.temperature_2m[i]` | `hourly[].temp` | — |
| `outHumidity` | `periods[].humidity` | (not in default response; see grid-data raw) | `hourly.relative_humidity_2m[i]` | `hourly[].humidity` | — |
| `windSpeed` | `periods[].windSpeedMPH`/`KPH`/`MPS` | `periods[].windSpeed` (parse range string) | `hourly.wind_speed_10m[i]` | `hourly[].wind_speed` | — |
| `windDir` | `periods[].windDirDEG` | `periods[].windDirection` (compass abbrev — convert to degrees) | `hourly.wind_direction_10m[i]` | `hourly[].wind_deg` | — |
| `windGust` | `periods[].windGustMPH`/`KPH`/`MPS` | (not in default; grid-data raw has it) | `hourly.wind_gusts_10m[i]` | `hourly[].wind_gust` | — |
| `precipProbability` | `periods[].pop` | `periods[].probabilityOfPrecipitation.value` | `hourly.precipitation_probability[i]` | `hourly[].pop * 100` | — |
| `precipAmount` | `periods[].precipMM`/`IN` | (not in default; grid-data raw has it) | `hourly.precipitation[i]` | `hourly[].rain.1h` + `hourly[].snow.1h` | — |
| `precipType` | derived from `periods[].weatherPrimaryCoded` | (heuristic from `shortForecast`) | derived from `weather_code` (WMO) | derived from `weather[0].main` | — |
| `cloudCover` | `periods[].sky` | (not in default; grid-data raw has it) | `hourly.cloud_cover[i]` | `hourly[].clouds` | — |
| `weatherCode` | `periods[].weatherPrimaryCoded` | extract from `periods[].icon` URL | `hourly.weather_code[i]` (WMO) | `hourly[].weather[0].id` | — |
| `weatherText` | `periods[].weatherShort` | `periods[].shortForecast` | (decode from WMO) | `hourly[].weather[0].description` | — |

Notes:

- **NWS `/forecast/hourly` is the recommended hourly endpoint;** the richer `/gridpoints/.../{office}/{x},{y}` raw grid carries unit-tagged numeric fields for everything but is verbose and lower-level. The normalizer prefers `/forecast/hourly` for the canonical-listed fields and falls back to grid-data only for those marked "not in default" above.
- **NWS `windDirection`** is a compass abbreviation (`SW`, `WNW`, etc.); the normalizer maps to degrees via the standard 16-point compass table.
- **OWM `rain.1h`/`snow.1h`** are present only when nonzero. The normalizer treats absence as 0 mm.
- **WMO weather codes** (Open-Meteo): canonical ints 0–99 per WMO 4677. The dashboard's icon map handles them; the api passes through.
- **`precipType` derivation rule (forecast-domain, all providers):** when deriving `precipType` from a provider's weather code, use the §3.3 enum values **literally** — `"rain"` / `"snow"` / `"sleet"` / `"freezing-rain"` / `"hail"` / `"none"`. **Do NOT flatten freezing variants to `"rain"`.** WMO mapping (used by Open-Meteo, also the right shape for any provider whose codes overlap WMO): 51-55 (drizzle) → `"rain"`, 56-57 (freezing drizzle) → `"freezing-rain"`, 61-65 (rain) → `"rain"`, 66-67 (freezing rain) → `"freezing-rain"`, 71-77 (snow / snow grains) → `"snow"`, 80-82 (rain showers) → `"rain"`, 85-86 (snow showers) → `"snow"`, 95-99 (thunderstorm / thunderstorm with hail) → `"rain"`, everything else → `null`. Provider-specific code sets (Aeris `weatherPrimaryCoded`, OWM `weather[0].id`, NWS heuristics) follow the same enum-literal discipline; map their precipitation classes to the closest canonical value, never collapse precision the enum exists to carry. Established 2026-05-07 from the 3b round 2 audit (F2): the round 2 brief flattened freezing variants to `"rain"`; the impl correctly used the canonical enum; this paragraph is the locked rule for future forecast provider rounds.

#### 4.1.3 Daily forecast (DailyForecastPoint)

| Canonical | aeris (`/forecasts` daily interval) | nws (`/gridpoints/.../forecast`) | openmeteo (`/v1/forecast?daily=`) | openweathermap (`/data/3.0/onecall` daily) | wunderground (`/v3/wx/forecast/daily/5day`) |
|---|---|---|---|---|---|
| `validDate` | `periods[].dateTimeISO` (date part) | `periods[].startTime` (date part; periods alternate day/night — pair them) | `daily.time[i]` | `daily[].dt` (epoch s → date) | `validTimeLocal` (date part) |
| `tempMax` | `periods[].maxTempF`/`C` | day-period `temperature` | `daily.temperature_2m_max[i]` | `daily[].temp.max` | `temperatureMax` |
| `tempMin` | `periods[].minTempF`/`C` | night-period `temperature` | `daily.temperature_2m_min[i]` | `daily[].temp.min` | `temperatureMin` |
| `precipAmount` | `periods[].precipMM`/`IN` | (parse from `detailedForecast`) | `daily.precipitation_sum[i]` | `daily[].rain` + `daily[].snow` | `qpf` |
| `precipProbabilityMax` | `periods[].pop` | `periods[].probabilityOfPrecipitation.value` (max of day+night) | `daily.precipitation_probability_max[i]` | `daily[].pop * 100` | `daypart[0].precipChance` |
| `windSpeedMax` | `periods[].windSpeedMaxMPH`/`KPH`/`MPS` | `periods[].windSpeed` (parse upper bound) | `daily.wind_speed_10m_max[i]` | `daily[].wind_speed` | `daypart[0].windSpeed` |
| `windGustMax` | `periods[].windGustMaxMPH`/`KPH`/`MPS` | — | `daily.wind_gusts_10m_max[i]` | `daily[].wind_gust` | — |
| `sunrise` | `periods[].sunriseISO` | — | `daily.sunrise[i]` | `daily[].sunrise` (epoch s) | `sunriseTimeUtc` |
| `sunset` | `periods[].sunsetISO` | — | `daily.sunset[i]` | `daily[].sunset` (epoch s) | `sunsetTimeUtc` |
| `uvIndexMax` | `periods[].uvi` | — | `daily.uv_index_max[i]` | `daily[].uvi` | `daypart[0].uvIndex` |
| `weatherCode` | `periods[].weatherPrimaryCoded` | extract from `periods[].icon` | `daily.weather_code[i]` | `daily[].weather[0].id` | `daypart[0].iconCode` |
| `weatherText` | `periods[].weatherShort` | day-period `shortForecast` | (decode from WMO) | `daily[].summary` (preferred) or `weather[0].description` | `daypart[0].wxPhraseShort` |
| `narrative` | `periods[].text` (paid-tier on some plans) | day-period `detailedForecast` | — | `daily[].summary` | `narrative` |

Notes:

- **NWS `/forecast` periods alternate day/night.** The normalizer pairs them: day's `temperature` → `tempMax`, night's `temperature` → `tempMin`. `probabilityOfPrecipitation` takes the max across the pair.
- **OWM `daily.summary`** (One Call 3.0) is a one-sentence summary suitable for `weatherText`; the longer narrative path is provider-side only on Aeris paid plans, not free.
- **Wunderground daily forecast** has a `daypart` array with separate day/night entries; the normalizer takes `daypart[0]` (day) for daytime fields, `daypart[1]` (night) for night-only.

#### 4.1.4 Forecast discussion (ForecastDiscussion)

| Canonical | aeris | nws | openmeteo | openweathermap | wunderground |
|---|---|---|---|---|---|
| `headline` | `response.forecasts[0].periods[0].weatherPrimary` (first period) | `productText` first line | — | — | — |
| `body` | (not directly; some plans expose summary) | `productText` (full AFD body) | — | — | — |
| `issuedAt` | — | `issuanceTime` | — | — | — |
| `validFrom` | — | (parse from `productText` if present) | — | — | — |
| `validUntil` | — | (parse from `productText` if present) | — | — | — |
| `senderName` | — | `wmoCollectiveId` + `issuingOffice` (e.g. "NWS Seattle WA") | — | — | — |
| `source` | `aeris` | `nws` | (set to `null` upstream) | (set to `null` upstream) | (set to `null` upstream) |

Notes:

- **NWS AFD endpoint:** `/products?type=AFD&location={CWA}`, then `/products/{id}` to fetch the body. NWS AFD is plain ASCII fixed-width; surface as-is in `body`.
- Open-Meteo, OWM, Wunderground PWS expose **no equivalent**; `discussion: null` on those bundles.

### 4.2 AQI providers (per [ADR-013](../decisions/ADR-013-aqi-handling.md))

Day-1 set: `aeris`, `openmeteo`, `openweathermap`, `iqair`. Path B only — Path A maps weewx archive columns directly per ADR-035 (no provider involved).

| Canonical | aeris (`/airquality`) | openmeteo (`/v1/air-quality`) | openweathermap (`/data/2.5/air_pollution`) | iqair (`/v2/nearest_city`) |
|---|---|---|---|---|
| `aqi` | `periods[].aqi` (US EPA scale by default) | `current.us_aqi` | `list[0].main.aqi` (1–5 OWM scale; convert to EPA) | `data.current.pollution.aqius` |
| `aqiCategory` | `periods[].category` | (derive from `us_aqi` via EPA bands) | (derive from EPA bands after conversion) | `data.current.pollution.mainus`-derived category |
| `aqiMainPollutant` | `periods[].dominant` | (derive from highest sub-AQI in `us_aqi_pm2_5` / `us_aqi_pm10` / `us_aqi_o3` / etc.) | `list[0].components` largest contributor | `data.current.pollution.mainus` |
| `aqiLocation` | `place.name` | — | — | `data.city` + `data.state` |
| `pollutantPM25` | `periods[].pollutants[].pm2_5` | `current.pm2_5` (µg/m³) | `list[0].components.pm2_5` (µg/m³) | `data.current.pollution.pm25` (µg/m³ — convert if needed) |
| `pollutantPM10` | `periods[].pollutants[].pm10` | `current.pm10` (µg/m³) | `list[0].components.pm10` (µg/m³) | — |
| `pollutantO3` | `periods[].pollutants[].o3` (ppm) | `current.ozone` (µg/m³ — convert to ppm) | `list[0].components.o3` (µg/m³ — convert) | — |
| `pollutantNO2` | `periods[].pollutants[].no2` (ppm) | `current.nitrogen_dioxide` (µg/m³) | `list[0].components.no2` (µg/m³) | — |
| `pollutantSO2` | `periods[].pollutants[].so2` (ppm) | `current.sulphur_dioxide` (µg/m³) | `list[0].components.so2` (µg/m³) | — |
| `pollutantCO` | `periods[].pollutants[].co` (ppm) | `current.carbon_monoxide` (µg/m³ — convert to ppm) | `list[0].components.co` (µg/m³ — convert) | — |
| `observedAt` | `periods[].dateTimeISO` | `current.time` | `list[0].dt` (epoch s) | `data.current.pollution.ts` |

Notes:

- **OWM AQI scale is 1–5** (1 Good / 5 Very Poor) — NOT EPA 0–500. The normalizer converts: derive each pollutant's EPA sub-AQI from its concentration (EPA breakpoint table), take max → `aqi`.
- **µg/m³ → ppm conversion** for O3/NO2/SO2/CO: `ppm = µg/m³ × 24.45 / molecular_weight`, where 24.45 is the molar volume of an ideal gas at 25°C and 1 atm. Per-pollutant molecular weights (O3 = 48.00, NO2 = 46.01, SO2 = 64.07, CO = 28.01 g/mol) live in `weewx_clearskies_api/providers/aqi/_units.py`.
- **IQAir nearest-city endpoint** returns only PM2.5 and AQI; other pollutants require the paid Air Pollution endpoint not in the free tier — those canonical fields stay `null`.
- **Operator's own AQI extension (Path A)** — column names operator-defined; mapping happens at setup via [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md). Common patterns: `aqi_value`, `pm2_5`, `pm10_0`, `o3` — but the operator can name them anything and maps them to canonical fields explicitly.

### 4.3 Alert providers (per [ADR-016](../decisions/ADR-016-severe-weather-alerts.md))

Day-1 set: `nws`, `aeris`, `openweathermap`.

| Canonical | nws (`/alerts/active`) | aeris (`/alerts`) | openweathermap (`/data/3.0/onecall` alerts) |
|---|---|---|---|
| `id` | `properties.id` | `id` | concat(`event` + `start` + `sender_name`) |
| `headline` | `properties.headline` | `details.name` | `event` |
| `description` | `properties.description` (+ `instruction` appended) | `details.body` | `description` |
| `severity` | severity-mapping — see below | parse `details.type` suffix — see below | severity-mapping from `event` keyword |
| `urgency` | `properties.urgency` | (not provided) | (not provided) |
| `certainty` | `properties.certainty` | (not provided) | (not provided) |
| `event` | `properties.event` | `details.name` (human-readable) | `event` |
| `effective` | `properties.effective` | `timestamps.issuedISO` (UTC convert) | `start` (epoch s, convert) |
| `expires` | `properties.expires` | `timestamps.expiresISO` (UTC convert) | `end` (epoch s, convert) |
| `senderName` | `properties.senderName` | `details.emergency` (string only) ⇢ `place.name` | `sender_name` |
| `areaDesc` | `properties.areaDesc` | `place.name` | (not provided) |
| `category` | `properties.category` | `details.cat` | (not provided) |

**Aeris real-wire amendments (2026-05-09, 3b-7 fixture-capture evidence):**

- `details.priority` is **NOT** a severity field. It's a NOAA hazard-map display-priority code (e.g. `60` = Wind Advisory, `96` = Fire Weather Watch) for hazard-map ordering when alerts overlap. Aeris docs: "the lower the priority the higher the alert significance" — but the value range is 1–100+, indexed per event type, not by severity tier.
- Severity is encoded as the **suffix on `details.type`**. Aeris docs: "For non-US/Canadian alerts, the suffix indicates severity: `EX` (Extreme), `SV` (Severe), `MD` (Moderate), `MN` (Minor)." US/Canadian alerts use NWS [VTEC (Valid Time Event Code)](https://www.weather.gov/vtec/) format `XX.YY.Z` where `Z` is the action/severity code (`W`=Warning, `A`=Watch, `Y`=Advisory, `S`=Statement).
- `details.urgency`, `details.certainty`, `details.category` (full name) are **not** documented response fields and were absent from the captured real-wire response. PARTIAL-DOMAIN per L1 rule extension.
- `details.cat` IS the actual wire field name carrying category information (e.g. `"fire"`, `"thunderstorm"`).
- `details.emergency` is a JSON **boolean** when no emergency text is set (real-wire evidence), or a **string** when it is. Type is `bool | str | None`. senderName logic uses `isinstance(emergency, str) and emergency.strip()`; falsy or boolean values fall through to `place.name`.

#### Severity normalization

Canonical: `advisory` / `watch` / `warning`.

| NWS CAP severity | aeris `details.type` suffix (US/CA = VTEC; non-US = severity) | OWM `event` keyword pattern | Canonical |
|---|---|---|---|
| `Extreme` | `.W` (VTEC Warning) / `.EX` (Extreme) | `*Warning*` | `warning` |
| `Severe` | `.A` (VTEC Watch) / `.SV` (Severe) | `*Watch*` | `watch` |
| `Moderate` | `.Y` (VTEC Advisory) / `.S` (VTEC Statement) / `.MD` (Moderate) | `*Advisory*` / `*Statement*` | `advisory` |
| `Minor` | `.MN` (Minor) | (other) | `advisory` |
| `Unknown` | (no suffix or unknown suffix) | (default) | `advisory` |

Other NWS CAP fields (`urgency`, `certainty`, `category`) pass through unmapped on the NWS path. On the Aeris path, `urgency` and `certainty` always populate as `null` (PARTIAL-DOMAIN); `category` reads from `details.cat` rather than `details.category`.

### 4.4 Earthquake providers (per [ADR-040](../decisions/ADR-040-earthquake-providers.md))

Day-1 set: `usgs`, `geonet`, `emsc`, `renass`. Source for each provider's wire fields: [`EARTHQUAKE-PROVIDER-RESEARCH.md`](../reference/EARTHQUAKE-PROVIDER-RESEARCH.md). All four are free, keyless, and unauthenticated.

| Canonical | usgs (FDSN GeoJSON) | geonet (NZ) | emsc (FDSN JSON) | renass (FDSN GeoJSON) |
|---|---|---|---|---|
| `id` | `id` | `properties.publicID` | `properties.unid` | `id` |
| `time` | `properties.time` (epoch ms → ISO UTC) | `properties.time` | `properties.time` | `properties.time` |
| `latitude` | `geometry.coordinates[1]` | `geometry.coordinates[1]` | `properties.lat` | `geometry.coordinates[1]` |
| `longitude` | `geometry.coordinates[0]` | `geometry.coordinates[0]` | `properties.lon` | `geometry.coordinates[0]` |
| `magnitude` | `properties.mag` | `properties.magnitude` | `properties.mag` | `properties.mag` |
| `magnitudeType` | `properties.magType` | (not provided; assume `ml`) | `properties.magtype` | (often null; provider-specific) |
| `depth` | `geometry.coordinates[2]` (km) | `properties.depth` (km) | `properties.depth` (km) | `geometry.coordinates[2]` (km) |
| `place` | `properties.place` | `properties.locality` | `properties.flynn_region` | `properties.description` |
| `url` | `properties.url` | derived from `publicID` | derived from `unid` | `properties.url` |
| `tsunami` | `properties.tsunami` (0/1 → bool) | (not provided) | (not provided) | (not provided) |
| `felt` | `properties.felt` | (not provided) | (not provided) | (not provided) |
| `mmi` | `properties.mmi` | `properties.MMI` | (not provided) | (not provided) |
| `alert` | `properties.alert` (green/yellow/orange/red) | (not provided) | (not provided) | (not provided) |
| `status` | `properties.status` (`automatic`/`reviewed`/`deleted`) | `properties.quality` (`best`/`preliminary`/`automatic`/`deleted`) | (not in standard FDSN; in `extras`) | `properties.status` (FDSN standard) |
| `extras` | `properties.{net, code, ids, sources, types, sig, nst, dmin, rms, gap, type}` | `properties.{quality}` and any non-canonical | `properties.{evtype, auth, source_id, source_catalog, lastupdate}` | (provider-specific) |
| `source` | `usgs` | `geonet` | `emsc` | `renass` |

### 4.5 Radar providers (per [ADR-015](../decisions/ADR-015-radar-map-tiles-strategy.md))

Radar tiles do not have a canonical-field mapping — they are tile bytes (PNG/WebP/JPEG) at slippy-map (z, x, y) coordinates. The api proxies keyed providers per ADR-037, passes through keyless providers via direct browser fetch, and the dashboard renders the tile layer in Leaflet.

What the canonical layer carries for radar:

- **`CapabilityDeclaration`** entry per configured radar provider — `providerId`, `geographicCoverage`, optional `operatorNotes`. (See [`#/components/schemas/CapabilityDeclaration`](openapi-v1.yaml).)
- **`RadarFrame`** entries via `/radar/providers/{provider_id}/frames` — list of `{time: UTC ISO, kind: past|current|nowcast}`. Source: each provider module's frame index.

Day-1 provider set per ADR-015: `rainviewer`, `openweathermap`, `aeris`, `iem_nexrad`, `noaa_mrms`, `msc_geomet`, `dwd_radolan`, `mapbox_jma`, plus `iframe` config slot.

URL templates and tile content types live inside each provider module at `weewx_clearskies_api/providers/radar/{provider}.py` capability declaration; not re-stated here.

---

## 5. Pydantic configuration

Concrete config for `weewx_clearskies_api/models/canonical.py`. Source: [ADR-010](../decisions/ADR-010-canonical-data-model.md) §Implementation guidance, restated for completeness.

```python
from pydantic import BaseModel, ConfigDict

# ruff: noqa: N815  (canonical fields use weewx camelCase: outTemp, windSpeed, etc.)

class CanonicalModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",                   # core fields only; non-core columns route through `extras`
        ser_json_inf_nan="strings",       # NaN/Inf serialize as JSON strings, not invalid JSON literals
    )
```

Serialization invocation (per response):

```python
model.model_dump_json(exclude_none=False)
```

Datetime serialization: override default `+00:00` to explicit `Z` suffix. One-liner via a `@field_serializer` on every datetime field, OR a single custom JSON encoder registered globally.

---

## 6. Out of scope (intentionally not in this document)

- **Wire format / endpoint shape** — see [`openapi-v1.yaml`](openapi-v1.yaml).
- **Display-side unit conversion / per-user override** — see [ADR-019](../decisions/ADR-019-units-handling.md). Out of v0.1.
- **`extras` promotion UX** — see [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md).
- **Per-AQI-provider EPA breakpoint conversion table** — implementation detail of `weewx_clearskies_api/providers/aqi/_units.py`. Not contract-level.
- **Per-radar-provider URL templates** — capability-declaration content per ADR-015 + ADR-038. Not contract-level.
- **Realtime SSE event format** — `weewx-clearskies-realtime` ships its own contract. Both services share the `Observation` shape.
- **Multi-station** — see [ADR-011](../decisions/ADR-011-multi-station-scope.md). Single-station only at v0.1.

---

## 7. Update protocol

When this document changes, the trigger is one of:

1. **A new canonical field is added** (e.g. wview_extended column promoted out of `extras` after dashboard demand). Updates: add a row to the entity catalog (§3), add a row to the unit-system table (§2.1) if unit-bearing, add columns to relevant provider mapping tables (§4) where they supply the new field. OpenAPI schema gets a corresponding non-breaking minor bump per [ADR-018](../decisions/ADR-018-api-versioning-policy.md).
2. **A new provider is added** (post-day-1 module under `weewx_clearskies_api/providers/{domain}/{name}.py`). Updates: new column in the relevant §4 mapping table; cite the ADR (or new ADR) that justifies the addition.
3. **A provider's wire field changes upstream.** Updates: relevant §4 cell; if the change forces a behavioral mapping change, note in the relevant ADR's References.

This document is co-authoritative with [ADR-010](../decisions/ADR-010-canonical-data-model.md) and [`openapi-v1.yaml`](openapi-v1.yaml). Changes here that conflict with either need to be resolved before merging — the ADR/OpenAPI win on architecture, this spec wins on per-field unit and provider-mapping detail.
