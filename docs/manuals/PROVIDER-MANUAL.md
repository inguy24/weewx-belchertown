# Clear Skies — Provider Manual

Single authority for building and modifying provider modules in the Clear Skies API. ADRs explain *why*; this manual says *what to do*.

When this document conflicts with any other source, **this document wins**.

Companion documents:
- **API-MANUAL.md** — API implementation rules (data model, units, enrichment)
- **ARCHITECTURE.md** — system topology, provider module layout
- **contracts/canonical-data-model.md** — per-field data catalog

Last updated: 2026-06-21

---

## Table of Contents

1. [Module Contract](#1-module-contract)
2. [Compliance](#2-compliance)
3. [Caching](#3-caching)
4. [Forecast Providers](#4-forecast-providers)
5. [Air Quality](#5-air-quality)
6. [Almanac](#6-almanac)
7. [Radar](#7-radar)
8. [Alerts](#8-alerts)
9. [Earthquakes](#9-earthquakes)
10. [Error Taxonomy](#10-error-taxonomy)
11. [Testing Pattern](#11-testing-pattern)
12. [Anti-Patterns](#12-anti-patterns)

---

## §1 Module Contract

### One module per provider; one module per domain

Each provider lives in a self-contained module (single file or directory package) named after the provider. A provider that spans multiple data domains (e.g., Aeris supplies both forecast and AQI) gets one module per domain — a `providers/forecast/aeris.py` and a separate `providers/aqi/aeris.py`. These modules share nothing except any common auth constants they each independently define. Do not create modules that cross domain boundaries.

Adding a provider means adding a new module. Removing a provider means deleting that module. Do not refactor existing modules to absorb a new provider.

### Five responsibilities per module

Every provider module is responsible for exactly these five things, and nothing else:

1. **Outbound API call** — provider URL, authentication, query parameters, rate-limit handling. The module owns its own rate limiter instance for per-provider quota enforcement.
2. **Response parsing** — interpret the provider's response format (JSON, GeoJSON, XML, WMS capabilities).
3. **Canonical field translation** — unit conversion, scale normalization, identifier normalization (`PM2.5` / `pm25` / `pm2_5` → canonical `PM2.5`), time format → ISO 8601 UTC `Z`. Translate per the field catalog in `contracts/canonical-data-model.md`.
4. **Capability declaration** — a static, deterministic statement of which canonical fields this module supplies. Read at process startup to populate the runtime capability registry.
5. **Error handling** — translate every provider error condition into the canonical error taxonomy (see §10). No upstream error type leaks past the module boundary.

Anything outside these five — caching, logging format, persistence, dashboard rendering, alert banner display — is owned by other system layers. Do not implement those concerns inside a provider module.

### Shared infrastructure vs. per-module code

**Shared (`weewx_clearskies_api/providers/_common/`):**
- HTTP client wrapper with TLS, timeouts, and dual-stack (IPv4/IPv6) per coding rules §1
- Retry/backoff helper
- Canonical error class hierarchy
- Capability declaration data structure and registry plumbing
- Rate-limiter primitive

**Per-module:**
- Provider URL, authentication scheme, query parameter construction
- Response parsing and translation to canonical fields
- Module-level rate limiter instance (instantiated from the shared primitive)
- Domain-specific helpers needed only by this provider

**Canonical model package (not in providers at all):**
- Domain-wide helpers such as EPA AQI category lookup, Beaufort scale conversion, US-NWS alert-code translation
- These belong in the canonical-model package per the data model contract — never implement them inside a provider module

### Module file layout

```
weewx_clearskies_api/providers/
├── _common/         # HTTP client, retry, errors, capability, rate-limiter
├── forecast/        # Forecast domain modules (§4)
├── aqi/             # AQI domain modules (§5)
├── alerts/          # Alerts domain modules (§8)
├── earthquakes/     # Earthquakes domain modules (§9)
├── radar/           # Radar domain modules (§7)
└── seeing/          # 7Timer seeing forecast (§6 exception — see below)
```

### Capability declaration fields

Every module exports a static `CAPABILITY` structure at module-load time. For most modules this is a plain module-level constant. Required fields:

| Field | Type | Description |
|---|---|---|
| `provider_id` | string | Stable identifier, lowercase, no spaces. Examples: `"aeris"`, `"openmeteo"`, `"usgs"`. |
| `domain` | string | One of `"forecast"`, `"aqi"`, `"alerts"`, `"earthquakes"`, `"radar"`. One module = one domain. |
| `supplied_canonical_fields` | list[str] | Enumerated canonical fields this module can supply. Reference the field catalog in `contracts/canonical-data-model.md`. |
| `geographic_coverage` | string or list[str] | `"global"` or enumerated regions. Used by the setup wizard to warn when operator's lat/lon is outside coverage. |
| `auth_required` | list[str] | Operator-config keys required (e.g., `["AERIS_CLIENT_ID", "AERIS_CLIENT_SECRET"]`). Empty list for keyless providers. |
| `default_poll_interval_seconds` | int | Recommended polling cadence. |
| `operator_notes` | string | Free text surfaced in the configuration UI for provider-specific quirks and ToS reminders. |
| `is_observed_source` | bool | Whether the provider returns observed (measured) data from monitoring stations vs. model/forecast data. Default `True`. Only model-based AQI providers (Open-Meteo AQI, OWM AQI) set `False`. Used by the haze detection engine (ADR-067) to determine which PM2.5/PM10 data is eligible for haze confirmation. Non-AQI modules omit this field or leave it at the default. |

Radar modules add these optional fields to the capability declaration:

| Field | Type | Description |
|---|---|---|
| `tile_url_template` | string or None | XYZ tile URL template for raster tile providers. |
| `wms_endpoint_url` | string or None | WMS endpoint URL for WMS-T providers. |
| `wms_layer_name` | string or None | WMS layer identifier. |
| `tile_content_type` | string or None | MIME type of tile response (e.g., `"image/png"`). |
| `iframe_url` | string or None | Operator-configured URL for the iframe provider. Null in CAPABILITY; populated at runtime. |

**Iframe provider exception:** The `iframe` radar module uses a `make_capability()` factory function instead of a static `CAPABILITY` constant. The `iframe_url` is operator-configured at runtime and cannot be known at module-load time. All other modules use the static `CAPABILITY` pattern.

**Seeing provider exception:** The 7Timer seeing forecast provider is wired via direct import in `__main__.py`, not through the dispatch registry. It does not follow the `PROVIDER_MODULES` dispatch pattern. All other providers use the dispatch registry.

### Dispatch registry

`PROVIDER_MODULES` in `dispatch.py` is an explicit `dict[(domain, provider_id) → ModuleType]`. The registry is the canonical source of which providers exist and are active.

To add a provider:
1. Write the module file in the appropriate domain subdirectory.
2. Add an `import` of that module at the top of `dispatch.py`.
3. Add one dict entry: `("domain", "provider_id"): module_name`.

No entry-points. No runtime loading from operator config. No dynamic module discovery. The bundled set is the full set. Outside contributors open a pull request; the project reviews and merges or declines.

### ProviderHTTPClient

Each provider module instantiates **one** `ProviderHTTPClient` at module-load time — not per-request. Instantiate it as a module-level constant.

Required configuration:

| Parameter | Value |
|---|---|
| Max retries | 2 (3 total attempts) |
| Retry base delay | 0.5 s |
| Retry backoff factor | 2.0 |
| Retry delay cap | 5.0 s |
| Retry jitter | ±25% |
| `follow_redirects` | `False` (prevent token leak via accidental 30x redirect) |

Do not bypass this client by calling `httpx`, `requests`, or any other HTTP library directly. Do not instantiate per-request clients. Do not override retry parameters without an ADR.

4xx errors are **not** retried. Only 5xx responses and transport-level errors (DNS, TCP, TLS) trigger the retry loop.

---

## §2 Compliance

### End-user-managed keys

End users register and manage their own API keys with each provider. The project ships code only. Do not bundle any working API key in source, configuration examples, or test fixtures that will be committed to the repository.

### No proxied calls through a project service

Do not proxy provider API calls through any project-run infrastructure. Each operator's deployment calls providers directly using their own credentials. Two server-side proxies are allowed: (1) the API tile proxy for keyed radar providers (OpenWeatherMap) — an anti-browser-key-exposure measure within a single operator's deployment, and (2) the Caddy reverse proxy for LibreWxR — routing all tile/alert traffic through the operator's own Caddy so visitors never contact external services directly. Neither is a cross-operator proxy.

### Per-provider documentation requirements

Every provider module's `operator_notes` field and its companion entry in `docs/reference/api-docs/` must include:

- Link to the provider's Terms of Service
- Free-tier limits and rate limits
- Key signup URL and process
- Any commercial-use restrictions
- Attribution requirements

### Key absence behavior

When a required key environment variable is unset or empty, the module reports itself as disabled at startup and the rest of the service starts normally. The log line for a disabled provider must include the signup URL so the operator can enable it later. Do not raise an exception that prevents other providers or endpoints from starting.

### No telemetry

Do not add any call, log, or metric that leaks usage patterns to providers, to the project, or to third parties. Usage data stays within the operator's own deployment.

---

## §3 Caching

### Cache backends

The cache backend is pluggable. Two backends are supported:

| Backend | Use case | Config |
|---|---|---|
| `memory` | Single-worker deployments (default) | No config needed; LRU+TTL, maxsize ~1000 entries |
| `redis` | Multi-worker deployments | `CLEARSKIES_CACHE_URL=redis://localhost:6379/0` in `secrets.env` |

Multi-worker deployments **must** use Redis. If multiple uvicorn workers run with the `memory` backend, each worker maintains a separate in-memory cache and the operator's API quotas are burned proportionally to the worker count.

### Per-provider TTLs

Default TTLs are operator-overridable via config. Declare the default in the module's capability structure. The table below is the project default:

| Domain / endpoint | Default TTL |
|---|---|
| Forecast (current, hourly, daily) | 30 min |
| Alerts | 5 min |
| AQI current reading | 15 min |
| Radar tile metadata (frame timestamps) | 5 min |
| Radar tile bytes (proxied keyed providers) | Match upstream `Cache-Control`; otherwise 5 min |
| Seeing forecast | 3 hours |

### Cache key construction

The cache key is a deterministic hash of `(provider_id, endpoint, normalized_params)`.

Normalization rules:
- Sort query parameters alphabetically by key.
- Round `lat` and `lon` to 4 decimal places before including in the hash.
- Use lowercase for all string keys.

### Cache invalidation

TTL-only. There is no manual purge endpoint at v0.1. Operators clear the cache by bouncing the service (memory backend) or running `redis-cli FLUSHDB` (Redis backend). Do not implement a purge endpoint without an ADR.

### Cache observability

Expose cache hit and miss counters in both structured logs and Prometheus metrics. Provider modules do not instrument this directly — the cache abstraction layer handles it. Do not add cache-hit logging inside provider modules.

### Background cache warming

A daemon thread pre-computes slow endpoints on configurable intervals. It reuses the same `CacheBackend` as provider response caching. The first warm pass runs at startup. A cache miss falls through to a live query — graceful degradation, never a hard dependency.

Warmer intervals and cache keys (all operator-overridable via `[cache_warmer]` in `api.conf`):

| Endpoint | Default interval | Cache key |
|---|---|---|
| Records (all-time) | 30 min | `records:all-time` |
| Records (YTD) | 30 min | `records:ytd` |
| Almanac sun-times (current year) | 6 hours | `almanac:sun-times:{year}` |
| Almanac moon-phases (current year) | 6 hours | `almanac:moon-phases:{year}` |
| AQI history | 30 min | `aqi:history` |
| Climatology monthly | 6 hours | `climatology:monthly` |
| Planets | 6 hours | `almanac:planets:{date}` |
| Eclipses | 24 hours | `almanac:eclipses` |
| Meteor showers | 24 hours | `almanac:meteor-showers:{year}` |

### Cache warmer configuration

```ini
[cache_warmer]
enabled = true
records_interval_minutes = 30
almanac_interval_minutes = 360
aqi_interval_minutes = 30
climatology_interval_minutes = 360
astronomy_interval_minutes = 360
eclipses_interval_minutes = 1440
```

---

## §4 Forecast Providers

### Day-1 provider set

Five forecast provider modules ship at v0.1:

| Module | Location | Key required | Coverage | Constraints |
|---|---|---|---|---|
| `aeris` | `providers/forecast/aeris.py` | Yes | US, Canada, Europe + global | Developer trial free tier. Operator selects forecast model: Standard (`/forecasts`) or Xcast (`/xcast/forecasts`, ML-enhanced temp/wind). Config key: `aeris_forecast_model` in `[forecast]` (default: `xcast`). Xcast applies to hourly only; daynight always uses standard. |
| `nws` | `providers/forecast/nws.py` | No (User-Agent header required) | USA only | USA-only geographic gate |
| `openmeteo` | `providers/forecast/openmeteo.py` | No (free, non-commercial) | Global | No alerts endpoint |
| `openweathermap` | `providers/forecast/openweathermap.py` | Yes | Global | Hourly/daily/alerts require One Call 3.0 subscription |
| `wunderground` | `providers/forecast/wunderground.py` | Yes (PWS contributor only) | PWS network | No hourly; no alerts; requires registered PWS station ID |

Each module is independently enable/disable. A missing key disables that provider's module only — other providers start normally.

### Geographic and feature limitations

These limitations are enforced at the module level, not the endpoint level:

- **NWS:** Disable at config time if operator's lat/lon is outside the USA. Report `GeographicallyUnsupported`.
- **OpenMeteo:** Report `FieldUnsupported` when alerts are queried. Current, hourly, and daily forecasts work normally.
- **Weather Underground:** Require both `WUNDERGROUND_API_KEY` and `WUNDERGROUND_PWS_STATION_ID`. If either is unset, log a clear message pointing to the PWS registration requirement.
- **OpenWeatherMap:** Distinguish basic-tier vs. One Call 3.0 at runtime. When the operator's key has only basic-tier access, return `FieldUnsupported` for hourly, daily, and alerts.

### Hidden data behavior

When no configured provider supplies a given data type (e.g., all configured providers lack an alerts endpoint), the dashboard hides that panel. Do not render any "no provider configured" message on the dashboard. Do not add explanatory text for absent data — absence is the correct rendering.

### Normalizer contract

Every forecast provider module must implement these five callables:

| Callable | Returns |
|---|---|
| `normalize_current(raw)` | Canonical current-conditions object |
| `normalize_hourly(raw)` | List of canonical hourly forecast objects |
| `normalize_daily(raw)` | List of canonical daily forecast objects |
| `normalize_discussion(raw)` | Canonical `ForecastDiscussion` object or `None` |
| `normalize_alerts(raw)` | List of canonical `AlertRecord` objects or empty list |

Return types reference the canonical model in `contracts/canonical-data-model.md`. Do not add callables beyond this set without updating this manual.

---

## §5 Air Quality

### Two operator paths

Operators supply AQI data through one of two independent paths:

**Path A — weewx archive columns:** The operator runs their own weewx extension that writes AQI columns to the archive. At setup, they map those columns to canonical AQI fields via the column-mapping wizard step. Clear Skies never sees the extension; it queries the archive the same way it queries any other observation columns.

**Path B — API provider module:** The operator selects an AQI provider in the setup wizard. The corresponding module handles the API call and canonical translation.

The two paths do not coordinate. An operator can use both simultaneously.

### Day-1 AQI provider set

| Module | Location | Key required | Coverage | Data type | Haze-eligible |
|---|---|---|---|---|---|
| `aeris` | `providers/aqi/aeris.py` | Yes | Global; 8 regional AQI scales | Observed (monitoring networks) | Yes |
| `iqair` | `providers/aqi/iqair.py` | Yes | Global; US EPA and China MEP scales | Observed (monitors + crowd-sourced) | Yes |
| `openaq` | `providers/aqi/openaq.py` | Yes (free) | 141 countries, ~2016–present | Observed (government reference monitors) | Yes |
| `openmeteo` | `providers/aqi/openmeteo.py` | No | Global; US EPA and European AQI | Model-based (CAMS forecast) | No |
| `openweathermap` | `providers/aqi/openweathermap.py` | Yes | Global; OWM 1-5 ordinal scale | Model-based (SILAM forecast) — **DEPRECATED** | No |

### Observed vs model data classification

Haze detection (ADR-067) requires *observed* PM2.5/PM10 — actual measurements from monitoring stations, not atmospheric model predictions. Providers that return model or forecast PM data cannot confirm that particulate matter is physically present at the station at the time of observation; they predict what should be present based on emissions inventories and atmospheric transport modeling.

The `is_observed_source` capability flag on each provider module controls haze eligibility. The haze detection engine ignores PM2.5 and PM10 values from any provider where `is_observed_source = False`.

| Provider | `is_observed_source` | Data origin |
|---|---|---|
| `aeris` | `True` | Blended real-time monitoring networks (observed) |
| `iqair` | `True` | Monitoring stations + crowd-sourced sensors (observed) |
| `openaq` | `True` | Government reference monitors (observed) |
| `openmeteo` | `False` | CAMS global atmospheric composition model (forecast) |
| `openweathermap` | `False` | SILAM atmospheric dispersion model (forecast) — deprecated |

Operators may still configure model-based providers for general AQI display. Only the haze detection engine enforces the `is_observed_source` gate; the AQI card renders normally regardless of which provider is configured.

### Multi-jurisdiction AQI — pass-through architecture

Providers compute AQI natively using their own regional scale. Pass through what they return. Do not compute AQI from raw concentrations (the existing OWM→EPA computation in `_units.py` is the only permitted exception — OWM does not return EPA AQI natively).

`aqiScale` carries the provider's actual scale identifier. `aqiCategory` passes through from the provider's response — do not set it to null. Possible scale values include `"airnow"`, `"india"`, `"eaqi"`, `"caqi"`, `"uk"`, `"de"`, `"cai"`, `"mep"`, `"owm"`.

Do not drop any pollutant field. All eight pollutant fields must be passed through when the provider returns them:

| Canonical field | Pollutant |
|---|---|
| `pollutantPM25` | PM2.5 |
| `pollutantPM10` | PM10 |
| `pollutantO3` | Ozone |
| `pollutantNO2` | Nitrogen dioxide |
| `pollutantSO2` | Sulfur dioxide |
| `pollutantCO` | Carbon monoxide |
| `pollutantNO` | Nitric oxide |
| `pollutantNH3` | Ammonia |

### Provider-specific regional configuration

Each AQI provider that supports multiple scales requires an operator-configurable setting:

| Provider | Setting | Valid values | Default |
|---|---|---|---|
| Aeris | `aeris_aqi_filter` | `airnow`, `china`, `india`, `eaqi`, `caqi`, `uk`, `de`, `cai` | `airnow` |

| OpenMeteo | `openmeteo_aqi_index` | `us_aqi`, `european_aqi` | `us_aqi` |
| IQAir | `iqair_aqi_scale` | `us`, `cn` | `us` |
| OpenWeatherMap | (none) | — | Always returns OWM 1-5 ordinal — **DEPRECATED** |

Pass the configured setting as the appropriate query parameter on each API call. Aeris: `filter=`. OpenMeteo: determines which variable name to request. IQAir: determines whether to read `aqius` or `aqicn`.

The setup wizard auto-suggests the regional setting based on the operator's station lat/lon → country lookup.

### Aeris AQI provider

**Module:** `providers/aqi/aeris.py`  
**`is_observed_source`:** `True`

**Endpoint:** Aeris conditions endpoint — `GET /conditions/{lat},{lon}` — returns current air quality with PM2.5, PM10, O3, NO2, SO2, and CO values alongside the composite AQI and scale.

**Auth:** Reuses existing Aeris (Xweather) credentials. The module reads `AERIS_CLIENT_ID` and `AERIS_CLIENT_SECRET` from `secrets.env` — the same credential pair used by the forecast module. No additional key registration is required if the operator already has an Aeris forecast subscription.

**Rate limits:** Per Aeris subscription tier. PWSWeather Contributor Plan (free for PWS data contributors): 1,000 API accesses/day at 100/minute. Air quality endpoints count as standard API accesses (1x multiplier for current conditions; the archive endpoint carries a 5x multiplier — see §3 cache warming).

**Regional configuration:** The `aeris_aqi_filter` setting in `[aqi]` selects the AQI scale (default: `airnow`). Valid values: `airnow`, `china`, `india`, `eaqi`, `caqi`, `uk`, `de`, `cai`. Passed as the `filter=` query parameter on each API call.

**Canonical field mapping:**

| Aeris wire field | Canonical field | Notes |
|---|---|---|
| `periods[0].aqi` | `aqi` | Composite AQI for the selected scale |
| `periods[0].category.p` | `aqiCategory` | Pass through as-is |
| `periods[0].pollutants[N].valueUGM3` where `type == "pm25"` | `pollutantPM25` | µg/m³; pollutants is an array of typed objects, not keyed by name |
| `periods[0].pollutants[N].valueUGM3` where `type == "pm10"` | `pollutantPM10` | µg/m³ |
| `periods[0].pollutants[N].valuePPB` → ppm where `type == "o3"` | `pollutantO3` | Convert ppb to ppm |
| `periods[0].pollutants[N].valuePPB` → ppm where `type == "no2"` | `pollutantNO2` | Convert ppb to ppm |
| `periods[0].pollutants[N].valuePPB` → ppm where `type == "so2"` | `pollutantSO2` | Convert ppb to ppm |
| `periods[0].pollutants[N].valuePPB` → ppm where `type == "co"` | `pollutantCO` | Convert ppb to ppm |

**`is_observed_source = True`** — Aeris blends real-time data from monitoring networks. PM2.5 and PM10 values are observed concentrations eligible for haze confirmation.

**ToS:** https://www.xweather.com/legal/terms  
**Key signup:** https://www.pwsweather.com/contributor-plan/ (free for PWS contributors) or https://www.xweather.com/

### OpenWeatherMap AQI provider (deprecated)

**Module:** `providers/aqi/openweathermap.py`  
**`is_observed_source`:** `False`

**Deprecated.** OWM AQI uses the SILAM atmospheric dispersion model — it returns predicted PM concentrations, not observed measurements. PM2.5 and PM10 values from this provider are not eligible for haze confirmation. The module logs a deprecation warning at startup when configured and logs a warning on each `fetch()` call. The module continues to function for general AQI display.

Operators should migrate to Aeris or IQAir for haze-eligible AQI data. OWM AQI will be removed in the next major version.

Existing operator behavior is unchanged: the AQI card renders normally. Only haze detection is affected — the haze engine ignores PM data from this provider.

### OpenAQ AQI provider

**Module:** `providers/aqi/openaq.py`  
**`is_observed_source`:** `True`

**Coverage:** 141 countries, approximately 2016–present. Data comes from government reference PM2.5 monitors only — the same regulatory-grade instruments used for official air quality reporting. PM2.5 and PM10 only; no composite AQI index and no gas-phase pollutants (O3, NO2, SO2, CO) are returned.

**Auth:** API key via `X-API-Key` request header. Register for a free key at https://explore.openaq.org/register. Set the key in `secrets.env` as `WEEWX_CLEARSKIES_OPENAQ_API_KEY=<your-key>`.

**Env var:** `WEEWX_CLEARSKIES_OPENAQ_API_KEY`

**Rate limits (free tier):** 60 requests/minute, 2,000 requests/hour.

**Cache TTL:** 3,600 s (1 hour). OpenAQ reference monitors typically update with a 1–2 hour lag relative to real-time. A 1-hour TTL matches that lag and avoids unnecessary API calls against a response that has not changed.

**`aqiScale`:** None. OpenAQ returns raw PM concentrations in µg/m³ only. No AQI index is computed. `aqi` and `aqiCategory` are `null` in the canonical response; the AQI card renders the available concentration fields.

**`is_observed_source = True`** — OpenAQ sourcing is limited to government reference monitors (`sensor_type = reference grade`). PM2.5 and PM10 values are observed concentrations eligible for haze confirmation.

**Canonical field mapping:**

| OpenAQ wire field | Canonical field | Notes |
|---|---|---|
| `results[0].measurements[N].value` where `parameter == "pm25"` | `pollutantPM25` | µg/m³ |
| `results[0].measurements[N].value` where `parameter == "pm10"` | `pollutantPM10` | µg/m³ |
| (not returned) | `aqi` | Always `null` — OpenAQ does not provide an index |
| (not returned) | `aqiCategory` | Always `null` |
| (not returned) | `aqiScale` | Always `null` |

**Bootstrap source:** OpenAQ is also used as the calibration bootstrap data source. The `clearskies-api bootstrap` CLI uses the OpenAQ API to pull historical PM2.5 records for seeding the auto-calibration baseline. See OPERATIONS-MANUAL §4 bootstrap procedure.

**Not recommended as primary AQI provider** for operators who need a composite AQI index or gas-phase pollutant data. Aeris and IQAir return lower-latency data with full pollutant coverage. Use OpenAQ when neither Aeris nor IQAir is available, or when PM-concentration-only data is acceptable for the AQI card.

**ToS:** https://openaq.org/about/licensing/  
**Key signup:** https://explore.openaq.org/register

### AQI provider recommendation hierarchy

| Priority | Provider | Key cost | Latency | AQI index | Haze-eligible | Notes |
|---|---|---|---|---|---|---|
| 1 | `aeris` | Free for PWS contributors | Minutes | Yes (8 scales) | Yes | Recommended default. Free via PWSWeather Contributor Plan; returns composite AQI + full pollutant suite from observed monitoring networks. |
| 2 | `iqair` | Paid | Minutes | Yes (US EPA, China MEP) | Yes | Gold standard for latency and data quality. Proprietary network + government monitors. Use when accuracy is the priority and budget allows. |
| 3 | `openaq` | Free | 1–2 hours | No | Yes | Free for all operators. Observed government reference data; haze-eligible. Data lag of 1–2 hours makes it unsuitable for real-time AQI display but acceptable for haze confirmation. |
| 4 | `openmeteo` | Free | Hours | Yes (US EPA, European) | No | Model-based (CAMS). No observed data; not haze-eligible. Use only when no observed provider is available and haze detection is not required. |

### Per-pollutant sub-index pass-through

All three active AQI providers (Aeris, Open-Meteo, IQAir Startup+) compute per-pollutant sub-AQI values server-side and return them on the wire. The `pollutantSubIndices` field on `AQIReading` passes these through as a dict keyed by canonical pollutant id (`"PM2.5"`, `"PM10"`, `"O3"`, `"NO2"`, `"SO2"`, `"CO"`). Values are numeric sub-AQI on the same scale as the main `aqi` field, capped at 500.

| Provider | Source | Keys |
|----------|--------|------|
| Aeris | `pollutants[].aqi` per entry | 6 (all standard pollutants) |
| Open-Meteo (US) | `us_aqi_pm2_5`, `us_aqi_pm10`, etc. | 6 |
| Open-Meteo (European) | `european_aqi_pm2_5`, `european_aqi_pm10`, etc. | 5 (no CO in EAQI formula) |
| IQAir (Startup+) | `{p2,p1,o3,n2,s2,co}.aqius` or `.aqicn` | Variable (only pollutants with data at the station) |
| IQAir (free Community) | — | `null` (no per-pollutant objects on free tier) |
| weewx Path A | — | `null` (archive columns have no sub-index concept) |

This is a pass-through — no AQI breakpoint computation on the Clear Skies side. Anti-pattern #11 ("Computing AQI from raw concentration breakpoints") still applies.

### AQI card rendering

The AQI card always renders on the Now page. When `aqi` is null (no provider configured, or provider returned no data), render the "no data" placeholder. Do not conditionally remove the AQI card from the layout.

---

## §6 Almanac

### Data source

All almanac calculations run server-side using **Skyfield** (https://rhodesmill.org/skyfield/), MIT-licensed, with NASA JPL DE421 ephemerides (~17 MB, bundled or downloaded on first run). Do not use `pyephem` — it is unmaintained.

Calculations are stateless given (lat, lon, time). Expensive computations (sun-times, moon-phases, planets, eclipses, meteor showers) are pre-computed by the background cache warmer (§3) on 6-hour or 24-hour intervals. Cache misses fall through to live Skyfield computation — never a hard dependency.

### Almanac endpoints

| Endpoint | Description |
|---|---|
| `GET /almanac` | Snapshot: today's sun/moon data |
| `GET /almanac/sun-times` | Year series: rise/set/transit/twilight for each day |
| `GET /almanac/moon-phases` | Year grid: new/first/full/last quarter dates |
| `GET /almanac/seeing-forecast` | 7Timer ASTRO seeing forecast (proxied) |
| `GET /almanac/planets` | Planet positions, visibility, and viewing quality |
| `GET /almanac/moon-names` | Cultural moon names for full moons in the year |
| `GET /almanac/eclipses/lunar` | Lunar eclipse list with visibility tiers |
| `GET /almanac/eclipses/solar` | Solar eclipse list with visibility tiers |
| `GET /almanac/meteor-showers` | Meteor shower list with viewing quality tiers |
| `GET /almanac/positions` | Current sky positions for sun, moon, planets |

Default twilight definition: **civil**. Do not change this default without an ADR.

### Visibility ranking — unified 5-tier color scale

All almanac visibility ratings use the same color scale. The tier label set is: Excellent, Good, Fair, Poor, Not Visible.

| Tier | Label | Color | Hex |
|---|---|---|---|
| 1 (best) | Excellent / Fully Visible | Green | `#22c55e` |
| 2 | Good / Mostly Visible | Lime | `#84cc16` |
| 3 | Fair / Partially Visible | Yellow | `#eab308` |
| 4 | Poor / Barely Visible | Orange | `#f97316` |
| 5 (worst) | Not Visible | Red | `#ef4444` |

Do not invent additional tiers. Do not use different colors for different event types.

### Solar eclipse visibility tiers

Solar eclipses use 4 tiers (no "Not Visible" tier — AstronomyAPI.com only returns eclipses whose shadow reaches the observer's location).

**Data source:** AstronomyAPI.com Events endpoint (`GET /api/v2/bodies/events/sun`). Use `output=rows` query parameter to get `data.rows[].events[]` structure.

**Important:** AstronomyAPI.com returns `extraInfo.obscuration` as a 0–1 fraction. Multiply by 100 before applying the thresholds below.

| Tier | Condition |
|---|---|
| 1 Green | `totalStart` is non-null (observer is in path of totality or annularity) |
| 2 Lime | Obscuration O ≥ 75% |
| 3 Yellow | 10% ≤ O < 75% |
| 4 Orange | O < 10% |

**Graceful degradation:** When AstronomyAPI.com credentials are not configured, return eclipse dates and types from Skyfield only. Set visibility tier to null. Do not crash.

### Lunar eclipse visibility tiers

**Data source:** AstronomyAPI.com Events endpoint (`GET /api/v2/bodies/events/moon`). Use `output=rows` query parameter.

Tier computation is based on peak altitude A at the observer's location and contact altitudes:

| Tier | Condition |
|---|---|
| 1 Green | Peak A > 15° AND all contact altitudes > 0° |
| 2 Lime | Peak A > 15° AND some contacts < 0° |
| 3 Yellow | 0° < Peak A ≤ 15° |
| 4 Orange | 0° < Peak A ≤ 5° |
| 5 Red | Peak A ≤ 0° (eclipse entirely below horizon) |

### Meteor shower visibility tiers

**Data source:** Skyfield (radiant altitude R, moon illumination M at peak date). Static shower catalog from IMO/AMS (ZHR, velocity, radiant RA/Dec, descriptions).

| Tier | Condition |
|---|---|
| 1 Green | R > 40° AND M < 25% |
| 2 Lime | R > 20° AND M < 50% (and not tier 1) |
| 3 Yellow | R > 10° AND (M ≥ 50% OR R ≤ 40°) (and not tier 1 or 2) |
| 4 Orange | R ≤ 10° OR (M > 75% AND R ≤ 30°) |
| 5 Red | R < 0° (radiant never rises at this latitude) |

### Planet viewing quality

**Formula:** `score = (seeing_score × 0.80) + (transparency_score × 0.05) + (altitude_score × 0.15)`

Special gates (applied before the score formula):
- Cloud gate: `cloudcover > 6` → Not Visible (tier 5). Do not compute a score.
- Mercury elongation gate: elongation < 12° → Not Visible. Elongation 12°–18° → cap result at Good (tier 2).
- Uranus/Neptune moon penalty: apply when applicable.

Score → tier mapping:

| Score | Tier |
|---|---|
| ≥ 0.75 | 1 Excellent |
| 0.50–0.74 | 2 Good |
| 0.30–0.49 | 3 Fair |
| < 0.30 | 4 Poor |

**Data sources:**
- Seeing and cloud cover: 7Timer ASTRO product (`GET /almanac/seeing-forecast`)
- Planet altitude, elongation, magnitude: Skyfield

### Eclipse query window and progressive fill

Both eclipse endpoints default to a **10-year window (3652 days)**.

Dashboard progressive fill rule (max 4 columns, no horizontal scroll):
1. Filter to eclipses within the next 2 years.
2. If the 2-year set fills or exceeds 4 columns, show only the first 4.
3. If fewer than 4 in the 2-year window, backfill from the full 10-year set until 4 columns are filled or data runs out.

### Data provenance

| Data | Source |
|---|---|
| Solar/lunar eclipse dates and types | Skyfield `eclipselib` |
| Eclipse contact times, altitudes, obscuration | AstronomyAPI.com Events endpoint (optional) |
| Meteor shower ZHR, velocity, radiant RA/Dec | IMO Meteor Shower Working List (static catalog) |
| Meteor shower descriptions | IMO + AMS published characteristics |
| Meteor shower radiant altitude | Skyfield (computed per observer location and peak date) |
| Meteor shower moon illumination | Skyfield (computed for peak date) |
| Planet positions, altitude, elongation, magnitude | Skyfield |
| Planet seeing forecast | 7Timer ASTRO product |

---

## §7 Radar

### Map library

Use **Leaflet** with **OpenStreetMap** base tiles. OSM attribution is required. Do not use MapLibre — it is a heavier WebGL stack with no advantage for the use cases here.

### Day-1 radar provider modules

Modules in `providers/radar/`:

| Module | Type | Key required | Coverage | Status |
|---|---|---|---|---|
| `rainviewer` | XYZ tiles (browser-direct to CDN) | No | Global mosaic | **Default.** Degraded since Jan 2026: zoom 7 max, no nowcast, single color scheme (Universal Blue), PNG only. |
| `librewxr` | XYZ tiles (Caddy-proxied) | No | Global (public API) or operator-defined (self-hosted) | **Optional upgrade.** Zoom 12, 13 color schemes, WebP, 60-min nowcast, satellite, weather alerts. |
| `openweathermap` | XYZ tiles (API-proxied) | Yes | Global — labeled "Model precipitation" in UI, NOT "Radar" | Active |
| `msc_geomet` | WMS-T | No | Canada national mosaic (Environment Canada) | Active (not in wizard — regional) |
| `dwd_radolan` | WMS-T | No | Germany RADOLAN (DWD GeoWebService) | Active (not in wizard — regional) |
| `iframe` | Iframe | Operator-supplied URL | Operator-defined (BoM Australia, MetService NZ, etc.) | Active |
| `iem_nexrad` | WMS-T | No | US CONUS NEXRAD (Iowa Environmental Mesonet) | **Deprecated.** Logs migration warning. Raw imagery too noisy — use LibreWxR instead. |
| `noaa_mrms` | WMS-T | No | US AK / HI / PR / Guam (NOAA MapServer) | **Deprecated.** Logs migration warning. Raw imagery too noisy — use LibreWxR instead. |

**Removed from radar domain:** `aeris` — 3,000 map units/day is unviable for radar tiles. Aeris is retained for forecast, AQI, and alerts domains.

### Tile routing model

Three routing patterns exist depending on the provider:

| Pattern | Providers | How it works |
|---|---|---|
| **Caddy-proxied** | `librewxr` | Caddy reverse-proxies `/librewxr/*` to the LibreWxR instance (public API or self-hosted). Browser talks to Caddy only. API never touches tile or alert traffic — it provides metadata (capabilities, frame lists) only. |
| **API-proxied** | `openweathermap` | API proxies tile requests server-side via `GET /api/v1/radar/providers/{id}/tiles/{z}/{x}/{y}`. API keys never reach the browser. |
| **Browser-direct** | `rainviewer`, `msc_geomet`, `dwd_radolan` | Browser fetches tiles directly from the provider CDN/WMS. No proxy involved. |

**Frame metadata for all providers:** `GET /api/v1/radar/providers/{id}/frames` — API fetches upstream metadata, normalizes to canonical `RadarFrameList`, caches.

### LibreWxR module rules

- **Configurable upstream:** `[radar] librewxr_endpoint` in `api.conf`. Default: `https://api.librewxr.net` (public API, no SLA). Operators can point to a self-hosted instance.
- **Metadata fetch:** `GET {endpoint}/public/weather-maps.json` — RainViewer v2-compatible wire format. Cached 60 seconds.
- **No `get_tile()` method.** Caddy proxies tiles directly. The API never handles tile bytes for LibreWxR.
- **Capability declaration includes:**
  - Provider name and attribution string
  - Geographic bounds (bounding box from `[radar] librewxr_bounds` config, or empty = global)
  - Caddy proxy path prefix (`/librewxr`) for tiles and alerts
  - Available features: `nowcast` (bool), `color_schemes` (list of `{id, name}`), `alerts` (bool)
  - Tile URL template (relative to Caddy): `/librewxr/{path}/{size}/{z}/{x}/{y}/{color}/{options}.webp`
  - Alert URL: `/librewxr/v2/alerts`
  - Refresh interval (from `[radar] librewxr_refresh_interval` config, default 600 seconds)
- **Rate limiter:** polite-use guard (5 req/s) for weather-maps.json fetches — prevents hammering the metadata endpoint.
- **Alert overlay data:** LibreWxR `/v2/alerts` returns GeoJSON FeatureCollection with WMO CAP metadata (severity, urgency, event, headline, expiry). Supports `?bbox=` query. Routed through Caddy at `/librewxr/v2/alerts`.
- **Color schemes:** 13 schemes (IDs 0–11 + 255). List comes from `weather-maps.json` → `radar.colorSchemes`. Dashboard uses the `color` path segment in tile URLs.
- **License:** AGPL-3.0 (code), CC-BY-4.0 (data).

### RainViewer degradation note

RainViewer gutted its free API tier on 2026-01-01:
- Zoom capped at 7 (was 8+)
- Nowcast discontinued
- Single color scheme (Universal Blue only)
- PNG only (no WebP)
- 100 req/IP/min rate limit

RainViewer remains the default because it works out of the box with zero infrastructure. The wizard displays a degradation note so operators know what they're getting. Operators who want better quality upgrade to LibreWxR.

### OpenWeatherMap radar label

Always label OpenWeatherMap radar as **"Model precipitation"** in the UI, operator notes, and documentation. Never label it as "Radar." It provides model-derived precipitation data, not true radar reflectivity.

### Geographic bounds

Provider capabilities include a geographic bounding box. The dashboard enforces `maxBounds` on the Leaflet map to prevent zooming out past the provider's coverage area.

- **RainViewer:** global (no bounds restriction)
- **LibreWxR (public API):** global (no bounds restriction)
- **LibreWxR (self-hosted):** bounds from `[radar] librewxr_bounds` config (operator sets this in wizard). For BBOX-cropped instances, the bounds match the crop area.
- **No bounds configured:** map allows global zoom (default behavior)

### Setup wizard radar suggestion

The wizard suggests radar providers based on simplicity, not quality:

| Recommendation | Provider | Note |
|---|---|---|
| Primary (all regions) | `rainviewer` | Works everywhere, zero setup |
| Alternative (all regions) | `librewxr` | "Better quality — requires public API or self-hosting" |

Operator may override the suggestion freely. Regional providers (`msc_geomet`, `dwd_radolan`) are not surfaced in the wizard — they exist for operators who configure manually.

### Attribution

Render attribution per each source's terms on the radar map. Required attribution strings:

| Provider | Attribution |
|---|---|
| `rainviewer` | `"RainViewer (https://www.rainviewer.com/)"` |
| `librewxr` | `"LibreWxR (https://librewxr.net/) — Data: CC-BY-4.0"` |
| `openweathermap` | `"OpenWeatherMap (https://openweathermap.org/)"` |
| `msc_geomet` | `"Environment and Climate Change Canada"` |
| `dwd_radolan` | `"Deutscher Wetterdienst"` |
| Base map (always) | `"© OpenStreetMap contributors"` |

Both the in-map Leaflet attribution control and any below-map caption must agree.

---

## §8 Alerts

### Day-1 provider set

Three alert provider modules ship at v0.1 in `providers/alerts/`. One source per deploy.

| Module | Coverage | Key required |
|---|---|---|
| `nws` | US + US territories + adjacent waters | No |
| `aeris` | US, Canada, Europe, UK, Japan, Australia, India, Brazil, South Africa, South Korea, Mexico | Yes (PWS-contributor path) |
| `openweathermap` | Global government alerts | Yes (One Call 3.0 paid tier) |

### Severity model

The canonical `AlertRecord` uses a two-field severity model:

| Field | Type | Description |
|---|---|---|
| `severityLevel` | `int \| null` | Integer 1–4 (1 = lowest, 4 = highest). Used for sorting, filtering, ARIA urgency. |
| `severityLabel` | `string \| null` | Source system's native severity name (e.g., "Amber", "Warning", "Vigilance jaune"). Used programmatically; not displayed as a visual badge in the alert banner. |

The old `advisory | watch | warning` severity enum is removed. The `?severity=` query parameter filter on `/alerts` is replaced by `?minLevel=` (integer).

### Severity level mapping across national systems

| Level | NWS (US/CA) | MeteoAlarm (EU) | UK Met Office | JMA (Japan) | BoM (Australia) | IMD (India) | INMET (Brazil) | SAWS (S. Africa) | KMA (S. Korea) | SMN (Mexico) |
|---|---|---|---|---|---|---|---|---|---|---|
| 4 (Extreme) | Warning | Red | Red | Emergency/Urgent Warning | Severe/Very Dangerous | Red | Red (Grande Perigo) | Level 9–10 | Red | Red/Purple |
| 3 (Severe) | Watch | Orange | Amber | Warning | Warning | Orange | Orange (Perigo) | Level 5–8 | Orange | Orange |
| 2 (Moderate) | Advisory | Yellow | Yellow | Advisory | Watch | Yellow | Yellow (Atenção) | Level 3–4 | Yellow | Yellow |
| 1 (Minor) | Statement | Green | — | — | Advice | Green | Gray | Level 1–2 | Green | Green |

### NWS provider severity fix

Map severity from the **event name tier** (Warning/Watch/Advisory/Statement suffix), NOT the CAP severity field. Use the event string suffix or VTEC code suffix (`.W`/`.A`/`.Y`/`.S`). Do not use `_NWS_SEVERITY_MAP` or any mapping from CAP severity values.

- Warning → `severityLevel=4`
- Watch → `severityLevel=3`
- Advisory → `severityLevel=2`
- Statement → `severityLevel=1`

### Aeris alert enrichment

The Aeris provider must capture these additional fields from the wire response:

| Wire field | Canonical field |
|---|---|
| `dataSource` | `alertSystem` |
| `localLanguages[0].name` | `nativeName` |
| `details.color` | `color` |
| `details.cat` | `hazardType` |

Map Aeris suffix codes to `severityLevel`: `.EX`→4, `.SV`→3, `.MD`→2, `.MN`→1.

### OWM default mode

OWM One Call 3.0 provides no severity metadata. Set `severityLevel=2` and `severityLabel="Alert"` for all OWM alerts. This is an operator directive: if an alert exists, it warrants advisory-level visibility. Do not set null.

Operator documentation must state this quality tradeoff explicitly: OWM alerts receive level-2 advisory visibility by default, not derived from provider metadata.

### Additional canonical alert fields

| Field | Source |
|---|---|
| `alertSystem` | Aeris `dataSource`, NWS literal `"nws"`, OWM `sender_name` where recognizable |
| `hazardType` | Aeris `details.cat`, OWM `tags[0]` |
| `nativeName` | Aeris `localLanguages[0].name` |
| `color` | Aeris `details.color` (provider-recommended hex; not the national system's official color) |

### Two rendering modes

**Rich mode** (Aeris, NWS): `severityLevel` and `severityLabel` are populated. Dashboard renders severity-colored icon panel, native label in ARIA, hazard-specific icon.

**OWM default mode**: `severityLevel=2`, `severityLabel="Alert"`. Dashboard renders level-2 (yellow/advisory) icon panel, `ph:warning` icon, `role="status"` ARIA.

### Uncovered regions

For operators whose region is not covered by any configured provider, return an empty `alerts` list. The `AlertBanner` component uses a direct early-return inside the component when `alerts.length === 0`. This is not part of the category-10 sensor-availability self-hide system. No error, no placeholder message.

### Setup wizard alert suggestion

| Operator region | Suggested module |
|---|---|
| US | `nws` |
| Canada, Europe | `aeris` |
| Elsewhere | `openweathermap` (with note on paid One Call 3.0 tier) |

---

## §9 Earthquakes

### Day-1 provider set

Four earthquake provider modules ship at v0.1 in `providers/earthquakes/`. All four are keyless. One source per deploy.

| Module | Coverage | License |
|---|---|---|
| `usgs` | Global (M2.5+ globally; US-comprehensive) | Public domain |
| `geonet` | New Zealand | CC BY 4.0 |
| `emsc` | Europe + Mediterranean + global | CC BY 4.0 |
| `renass` | Mainland France + neighboring countries | CC BY 4.0 |

USGS provides global coverage — there is no uncovered-region case for earthquakes.

### Setup wizard earthquake suggestion

| Operator region | Suggested module |
|---|---|
| US, Americas, global default | `usgs` |
| New Zealand | `geonet` |
| Europe, Mediterranean | `emsc` |
| France | `renass` |

### ReNASS endpoint

Use `https://api.franceseisme.fr/fdsnws/event/1/query`. The legacy endpoint `https://renass.unistra.fr/fdsnws/event/1/query` returns 404 since the EPOS-France migration. Do not reference the legacy URL anywhere.

### Canonical EarthquakeRecord fields

Required fields:

| Field | Type |
|---|---|
| `id` | string |
| `time` | ISO 8601 UTC string |
| `lat` | float |
| `lon` | float |
| `magnitude` | float |
| `source` | string (provider_id) |

Optional canonical fields:

| Field | Type |
|---|---|
| `depth` | float or null |
| `magnitudeType` | string or null |
| `place` | string or null |
| `url` | string or null |
| `tsunami` | bool or null |
| `felt` | int or null |
| `mmi` | float or null |
| `alert` | string or null |
| `status` | string or null |

Provider-specific data not listed above goes into the `extras` dict. Do not add provider-specific fields to the canonical schema — use `extras`.

### Provider-specific canonical mappings

These wire fields map to canonical fields directly — do not put them in `extras`:

| Provider | Wire field | Canonical field |
|---|---|---|
| GeoNet | `mmi` (lowercase) | `mmi` |
| EMSC | `flynn_region` | `place` |

### Per-provider extras keys

| Provider | `extras` keys |
|---|---|
| `usgs` | `cdi`, `sig`, `net`, `code`, `ids`, `sources`, `types`, `nst`, `dmin`, `rms`, `gap`, `type`, `title` |
| `geonet` | `quality` |
| `emsc` | `evtype`, `auth`, `source_id`, `source_catalog`, `lastupdate` |
| `renass` | `type`, `description_fr`, `url_fr` |

Only include `extras` keys when the value is non-null in the provider response.

### GEM Global Active Faults overlay

The seismic faults overlay is not a provider module. It is served from a bundled GeoJSON file at `GET /api/v1/earthquakes/faults`, radius-clipped to the operator's configured earthquake radius.

- Data: GEM Global Active Faults Database, CC-BY-SA 4.0
- Required attribution: `"Active faults: GEM Global Active Faults Database, CC-BY-SA 4.0"`
- Render attribution in both the in-map Leaflet attribution control and in a below-map caption
- The below-map caption is hidden when the fault layer is toggled off
- Fault toggle: default on (`showFaults` initialized `true`)
- Fault trace style: uniform amber, no fault-type differentiation
- Fault popups: `feature.properties.name` + `feature.properties.slip_type`; both fall back to localized "unknown" when absent
- Updates: periodic manual refresh from GEM GitHub — no auto-update mechanism

---

## §10 Error Taxonomy

### Canonical error types

All provider modules raise from this closed set. No other exception types may cross the module boundary.

| Error type | Meaning |
|---|---|
| `QuotaExhausted` | Rate-limit or daily cap hit; transient, retry after backoff |
| `KeyInvalid` | Authentication failure; permanent until operator updates config |
| `GeographicallyUnsupported` | Provider does not cover the operator's location |
| `FieldUnsupported` | Provider does not supply the requested data type |
| `TransientNetworkError` | DNS, TCP, TLS failure, or HTTP 5xx; retry with backoff |
| `ProviderProtocolError` | Unexpected response format (provider changed API silently); requires module update |

Do not catch and re-wrap these with generic Python exceptions. Do not let upstream provider exception types (e.g., `httpx.HTTPStatusError`, `requests.RequestException`) propagate past the module boundary.

### Error base class fields

Every canonical error carries:

| Field | Type | Description |
|---|---|---|
| `provider_id` | string | Which provider raised the error |
| `domain` | string | Which domain was being queried |
| `retry_after_seconds` | int or None | Present on `QuotaExhausted` when the provider supplies a `Retry-After` value |
| `status_code` | int or None | HTTP status code, for HTTP-boundary dispatch |

### Error → HTTP status mapping

| Error type | HTTP status | Notes |
|---|---|---|
| `QuotaExhausted` | 503 | Include `Retry-After` response header when `retry_after_seconds` is non-null |
| `GeographicallyUnsupported` | 503 | |
| `KeyInvalid` | 502 | |
| `FieldUnsupported` | 502 | |
| `TransientNetworkError` | 502 | |
| `ProviderProtocolError` | 502 | Log at ERROR level for triage; indicates module needs an update |

### Retry behavior

- 4xx errors: **never retried**. They indicate a permanent condition (bad key, bad request, geography gate).
- 5xx errors and transport errors: retried per the `ProviderHTTPClient` backoff policy (§1).
- `ProviderProtocolError`: not retried; log at ERROR and propagate.

---

## §11 Testing Pattern

### Fixture-first approach

Every provider module requires recorded fixtures of real provider API responses committed to the test suite. Fixtures live at:

```
tests/fixtures/providers/{provider_id}/
```

Use real response shapes. Do not construct synthetic fixtures from guesswork — capture from live API calls during initial module development, then commit. Use a real-capture fixture or the L3 synthetic-from-real fallback (documented in the test author's agent definition) when live-network access is unavailable during CI.

### Test file layout

Test files follow the nested pattern:

```
tests/providers/{domain}/test_{provider_id}.py       # Unit tests (parser)
tests/test_providers_{domain}_{provider_id}_integration.py  # Integration tests
```

Do not create flat test files at `tests/test_providers_{domain}_{provider_id}_unit.py` — the nested pattern is the project standard.

### Parser unit tests

Load the recorded fixture. Assert canonical field translation is correct:
- Units are converted correctly
- Identifiers are normalized to canonical form
- Times are in ISO 8601 UTC format with `Z` suffix
- Scale values match the expected canonical scale identifier
- `extras` dict contains only keys documented in §9 (for earthquake modules)
- Null fields are null, not absent, not empty string

### Mock-network tests

Use `respx` (or equivalent) to mock HTTP responses without live network calls. Verify:
- Authentication parameters are present and correctly formatted
- Rate-limit response (HTTP 429) raises `QuotaExhausted`
- Auth failure (HTTP 401/403) raises `KeyInvalid`
- HTTP 5xx raises `TransientNetworkError`
- Unexpected response shape raises `ProviderProtocolError`
- `retry_after_seconds` is populated when `Retry-After` header is present

### No live-network tests in CI

Live-network tests exist in the test suite but are gated behind an explicit environment variable or pytest marker (e.g., `@pytest.mark.live_network`). The CI pipeline never sets the enabling variable. The default `pytest` run (no markers, no env vars) never makes a live network call.

Developer-local live tests are permitted and encouraged for initial fixture capture and regression verification.

---

## §12 Anti-Patterns

The following patterns are forbidden. Any pull request introducing them must be rejected.

| Anti-pattern | Why forbidden |
|---|---|
| Bundling API keys in source, config templates, or committed fixtures | Violates ADR-006; every provider ToS prohibits key redistribution |
| Proxying provider calls through a project-run service | Violates ADR-006; creates project-level liability and uptime obligation |
| Leaking upstream provider exception types past the module boundary | Breaks the canonical error taxonomy; callers must not handle provider-specific errors |
| Live-network calls in CI tests | Makes CI non-deterministic and quota-burning; use fixtures and `respx` mocks |
| Hardcoding EPA AQI lookup tables, Beaufort scale, or other domain-wide helpers inside a provider module | These belong in the canonical-model package; duplicating them in providers creates drift |
| A single module spanning multiple data domains (e.g., one Aeris module that handles both forecast and AQI) | Violates "one module = one domain"; modules must be independently enable/disable per domain |
| Subclassing a shared `ProviderBase` or any other abstract base class | Rejected pattern; the project uses flat modules with a documented contract, not a class hierarchy |
| Storing credentials in `.conf` files | Credentials go in `secrets.env` as environment variables only; `.conf` files are world-readable on many deployments |
| Bypassing `ProviderHTTPClient` with a direct `httpx` or `requests` call | The shared client provides retry, backoff, follow_redirects=False, and dual-stack — these must not be bypassed |
| Per-request client instantiation | Instantiate `ProviderHTTPClient` once at module-load time; per-request instantiation wastes resources and bypasses connection pooling |
| Setting `follow_redirects=True` on any provider HTTP call | Redirects can leak auth tokens to a third-party destination |
| Computing AQI from raw concentration breakpoints (beyond the existing OWM→EPA path) | The project is a dashboard, not an AQI computation service; providers compute AQI natively |
| Implementing a purge/invalidation endpoint for the cache | No manual purge at v0.1; requires an ADR |
| Using `pyephem` for almanac calculations | Unmaintained; Skyfield is the mandated library |
| Referencing the legacy ReNASS endpoint `renass.unistra.fr` | Returns 404 since EPOS-France migration; use `api.franceseisme.fr` |
| Labeling OpenWeatherMap radar as "Radar" | It is model precipitation data; must be labeled "Model precipitation" |
| Adding a `mapbox_jma` module | Dropped from day-1 set — Mapbox JMA tilesets are raster-array / GL-JS-only, incompatible with Leaflet |
| Routing LibreWxR tile traffic through the API | Caddy proxies LibreWxR tiles and alerts directly; the API provides metadata only. Routing tiles through the API wastes resources and adds latency. |
| Adding `aeris` as a radar provider | Removed — 3,000 map units/day is unviable for radar tiles. Aeris is retained for forecast/AQI/alerts only. |
