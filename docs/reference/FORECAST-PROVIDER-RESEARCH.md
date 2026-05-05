# Forecast Provider Research

**Date:** 2026-04-30
**Purpose:** Verify which weather/forecast providers from the Clear Skies candidate set have public APIs technically compatible with our architecture, so we can write Python client modules for each in Phase 2. Per [ADR-006](../decisions/ADR-006-compliance-model.md), end users register and manage their own keys; this research scope is technical compatibility only — no commercial-use weighing, no pricing detail, no provider ranking.

**Candidate set:** Aeris, NWS, OpenMeteo, OpenWeatherMap, Weather Underground. (Meteoblue was eliminated 2026-04-29 — free-tier API call limit was so restrictive that practical use required upgrading; other providers covering the same geography offer more generous free tiers.)

## Verification table

| Provider | Public API? | Free tier exists? | Auth model | API docs URL | Endpoints (current / hourly / daily / alerts) | Response format | Notes |
|---|---|---|---|---|---|---|---|
| **Aeris (AerisWeather / Xweather)** | ✅ Yes | ✅ Yes (free developer trial) | `client_id+secret` (query params) | https://www.xweather.com/docs/weather-api/endpoints | current: `/observations`, `/conditions` — hourly: `/forecasts` (hourly interval) — daily: `/forecasts` (daily interval), `/conditions/summary` — alerts: `/alerts`, `/alerts/summary` | JSON, GeoJSON | Base URL: `https://data.api.xweather.com/`. `client_id` and `client_secret` are passed as query parameters on every request. Alerts coverage is US/Canada/Europe per docs. |
| **NWS (National Weather Service)** | ✅ Yes | ✅ Yes (no key required) | `none` (User-Agent header required) | https://www.weather.gov/documentation/services-web-api | current: `/stations/{stationId}/observations/latest` — hourly: `/gridpoints/{office}/{gridX},{gridY}/forecast/hourly` — daily: `/gridpoints/{office}/{gridX},{gridY}/forecast` — alerts: `/alerts/active` | GeoJSON (default), JSON-LD, DWML/CAP/ATOM (XML); set via `Accept` header | **Geography limited to USA.** Lookup `/points/{lat},{lon}` first to get the gridpoint office and X/Y. User-Agent header is mandatory — clients that omit it may be blocked. |
| **OpenMeteo** | ✅ Yes | ✅ Yes (non-commercial) | `none` for free use; `api-key` for commercial customer URLs | https://open-meteo.com/en/docs | current: `/v1/forecast` (with `current=` parameter) — hourly: `/v1/forecast` (with `hourly=`) — daily: `/v1/forecast` (with `daily=`) — alerts: ❌ not provided | JSON (default), CSV, XLSX | Base URL: `https://api.open-meteo.com/v1/forecast`. Single unified endpoint — all data types are parameter-controlled rather than separate paths. **No alerts endpoint exists.** Commercial tier uses a customer-specific server URL prefix plus `apikey` parameter. |
| **OpenWeatherMap** | ✅ Yes | ✅ Yes (limited APIs) | `api-key` (`appid` query param) | https://openweathermap.org/api | current: `/data/2.5/weather` — hourly: `/data/3.0/onecall` (One Call 3.0, separate subscription) — daily: `/data/3.0/onecall` (One Call 3.0) — alerts: `/data/3.0/onecall` (One Call 3.0) | JSON (default), XML (`mode=xml`), HTML (`mode=html`) | Base URL: `https://api.openweathermap.org/`. Basic free tier covers `/data/2.5/weather` (current) and `/data/2.5/forecast` (5 day / 3 hour). **Hourly/daily/alerts all live in One Call 3.0**, which requires the separate "One Call by Call" subscription — distinct from the basic free tier. |
| **Weather Underground** | ⚠️ Yes — PWS API only | ⚠️ Yes (free key for PWS network contributors only) | `api-key` (query param) | (gated; see Sources note) | current: `/v2/pws/observations/current` — hourly: ❌ not provided in PWS API — daily: `/v3/wx/forecast/daily/5day` — alerts: ❌ not provided | JSON | Base URL: `https://api.weather.com/`. The original public `api.wunderground.com` REST API was shut down. Current API is hosted by The Weather Company / IBM and is **gated to PWS network participants** — a developer obtains a key by registering a personal weather station. Documented limits: 1500 calls/day, 30 calls/minute. |

## Findings (hard surprises worth flagging)

- **Weather Underground:** Original public REST API at `api.wunderground.com` is gone. Current API at `api.weather.com` is **only issued to PWS contributors** — a developer cannot obtain a key without registering a personal weather station. Endpoint surface is narrower than the legacy API: no hourly forecast, no alerts.
- **NWS:** USA-only. Custom `User-Agent` header is mandatory; clients that omit it may be blocked.
- **OpenMeteo:** No alerts endpoint at all. Single `/v1/forecast` endpoint serves current/hourly/daily via query parameters rather than separate paths.
- **OpenWeatherMap:** Hourly forecast, daily forecast, and alerts are only available through **One Call API 3.0**, which is a separately-subscribed product (not the same as the basic free tier). A client module must talk to `data/3.0/onecall` for those data types.
- **Aeris/Xweather:** Auth is `client_id` + `client_secret` as **query parameters** (not headers, not OAuth bearer tokens despite docs labeling it "OAuth 2.0 userless access"). Unusual pattern — needs explicit handling in the client module.

## Sources note

- **Weather Underground:** Could not directly fetch the current PWS API documentation. Authoritative documentation is referenced as a Google Doc linked from the logged-in `wunderground.com/member/api-keys` page, gated behind member login. Facts above verified via Wunderground's own community forum (`apicommunity.wunderground.com`) and the public `wunderground.com/about/data` page; actual REST endpoint contracts will need to be confirmed by an end user with a PWS account once a client module is being implemented.
- **Aeris/Xweather:** Endpoint listing and authentication mechanism retrieved directly from `xweather.com/docs/weather-api/...`. Free trial existence confirmed from `xweather.com/pricing`.
- All other providers' docs retrieved directly from their primary developer documentation pages.

## Detailed API documentation

Per-provider API documentation is preserved locally to avoid re-fetching during Phase 2 module implementation. See [docs/reference/api-docs/](api-docs/).

## Re-research triggers

- Any provider deprecates an endpoint we use.
- Auth model changes (e.g., header-based replacing query params).
- A provider's free tier is removed entirely (forces re-evaluation of whether to keep the module in the day-1 set).
- New provider candidate proposed by user.
