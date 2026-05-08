# Phase 2 task 3b round 2 brief — clearskies-api forecast domain (Open-Meteo)

**Round identity.** Phase 2 task 3 sub-round 3b round 2. Second of 5 expected
3b rounds (one per provider domain: alerts → **forecast** → AQI → earthquakes
→ radar). 3b round 1 (alerts/NWS + shared `providers/_common/` infrastructure)
closed 2026-05-07. 3b round 2 adds the forecast domain with **Open-Meteo as
the first forecast provider**. Future 3b forecast rounds add the remaining
four providers (NWS, Aeris, OpenWeatherMap, Wunderground), one per round, to
keep audit surface manageable. Each follows the per-domain provider-module
pattern locked by ADR-038.

This is a **single-deliverable round.** The shared infrastructure (HTTP
wrapper, retry, error taxonomy, capability registry, both cache backends,
rate limiter) already landed in 3b round 1. This round consumes it.

1. **Forecast domain canonical types** (Pydantic response models):
   `HourlyForecastPoint`, `DailyForecastPoint`, `ForecastDiscussion` (always
   `null` for Open-Meteo), `ForecastBundle`, `ForecastResponse`.
2. **Open-Meteo forecast module** at
   `weewx_clearskies_api/providers/forecast/openmeteo.py` — first concrete
   forecast provider per ADR-007 / ADR-038.
3. **`/forecast` endpoint** at `weewx_clearskies_api/endpoints/forecast.py`.
4. **`[forecast]` settings section** + dispatch row + capability-wire wiring
   so the configured forecast provider's `CAPABILITY` joins the registry at
   startup.

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after both
submit and pytest is green on `weather-dev`.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` (clone of
github.com/inguy24/weewx-clearskies-api). **Default branch `main`** (verified
2026-05-07). The parallel-pull command is
`git fetch origin main && git merge --ff-only origin/main`.

---

## Scope — 1 endpoint + 1 provider module + plumbing

| # | Unit | Notes |
|---|---|---|
| 1 | `GET /forecast` | OpenAPI line 186. Reads from the configured forecast provider per ADR-007; returns `ForecastBundle(hourly=[], daily=[], discussion=null, source="none")` when no provider is configured (mirrors the alerts pattern). |
| 2 | `weewx_clearskies_api/providers/forecast/openmeteo.py` | First concrete forecast provider. Calls Open-Meteo `/v1/forecast` with hourly + daily variable lists; normalizes the column-oriented arrays to canonical `HourlyForecastPoint` / `DailyForecastPoint` lists; declares `CAPABILITY` symbol. |
| 3 | `providers/forecast/__init__.py` | Empty package marker (one-line file, mirrors `providers/alerts/__init__.py`). |
| 4 | `dispatch.py` | One new row: `("forecast", "openmeteo") → providers.forecast.openmeteo`. |
| 5 | `config/settings.py` | New `ForecastSettings` dataclass for the `[forecast]` section (mirrors `AlertsSettings`). |
| 6 | `__main__.py` | Extend `_wire_providers_from_config()` to look up the forecast provider in dispatch and append its `CAPABILITY`. |
| 7 | `models/responses.py` | New Pydantic models: `HourlyForecastPoint`, `DailyForecastPoint`, `ForecastDiscussion`, `ForecastBundle`, `ForecastResponse`. Reuse the existing `extras="ignore"` + camelCase pattern. |
| 8 | `models/params.py` | New `ForecastQueryParams` for `hours` + `days` query params. Wire via `Depends(_get_forecast_params)` per the §coding rule on Pydantic + Depends. |
| 9 | `app.py` | Register the new forecast router. |

**Out of scope this round (defer to later 3b rounds / Phase 3+ / Phase 4):**

- **NWS forecast.** Next 3b forecast round (or one after). NWS's two-step API
  call (`/points/{lat},{lon}` → `/gridpoints/.../forecast` + `/forecast/hourly`)
  and the AFD discussion endpoint warrant their own round once the canonical
  forecast bundle shape is validated by Open-Meteo's simpler wire.
- **Aeris / OpenWeatherMap / Wunderground forecast.** Later 3b forecast
  rounds. These three are keyed providers; the first one of them to land
  also extends the redaction filter to strip its query-string credential
  (`client_id` for Aeris per F13 deferral; `apiKey` for Wunderground; `appid`
  for OWM is already stripped).
- **All other provider domains.** /aqi/*, /earthquakes, /radar/* are
  separate 3b rounds.
- **Setup-wizard region-based provider suggestion** (ADR-007 §Implementation
  guidance, ADR-027). Wizard ships in Phase 4.
- **Operator overrides for forecast TTL or rate-limit.** ADR-017 says
  operators may override per-provider via config; the override mechanism
  (`[forecast] cache_ttl_seconds = N`) is a future round once we have a
  second forecast provider to compare against. This round uses ADR-017's
  default 30 min for forecast.
- **Multi-location.** ADR-011 single-station. Open-Meteo supports multiple
  lat/lon in one call but we don't use it.
- **Open-Meteo commercial host (`customer-api.open-meteo.com`) + `apikey`
  param.** v0.1 free-tier only. Future round if an operator surfaces demand.

---

## Lead-resolved calls (no user sign-off needed — ADRs and contracts settle these)

The "Brief questions audit themselves before draft" rule (added to
`rules/clearskies-process.md` 2026-05-07) requires every "open question" to
be audited against the ADRs first. After audit, every question for this
round was settled by an existing ADR, contract, or 3b-1 lead-call. Listing
them here as lead-resolved calls so api-dev / test-author can see the
reasoning at a glance, not because they need a sign-off step.

1. **HTTP client = `httpx` (sync).** Locked by 3b round 1 — already in deps,
   already wrapped by `ProviderHTTPClient` in `_common/http.py`. No change.

2. **Forecast cache TTL = 30 min.** Locked by ADR-017 §Per-provider TTL
   declaration table. Module's `CAPABILITY.default_poll_interval_seconds = 1800`
   and the cache `set(..., ttl_seconds=1800)` call. No operator override
   mechanism this round.

3. **`[forecast]` section shape: `provider = openmeteo`.** Locked by ADR-027
   §Implementation guidance (the example file uses `[forecast] provider = openmeteo`
   as the pattern; see ADR-027 line ~162-173). `ForecastSettings` mirrors
   `AlertsSettings` 1:1 in field naming + validate-on-load shape; no
   provider-specific knobs needed for Open-Meteo (it's keyless and the URL
   is hard-coded to the public host).

4. **Capability-registry populate path.** Locked by ADR-038 §3 + the
   existing `_wire_providers_from_config()` from 3b-1. Extend the function
   to also look up the forecast provider in dispatch and append its
   `CAPABILITY`. Same pattern, different domain. Single source per domain
   per ADR-007 §Decision (operator picks one forecast provider; each module
   is independently enable/disable).

5. **Both cache backends already live.** Locked by ADR-017 §Decision +
   3b-1's landed `MemoryCache` + `RedisCache`. Forecast module consumes
   `get_cache()` like alerts does.

6. **No live-network tests in CI.** Locked by ADR-038 §Testing pattern.
   Recorded fixture at `tests/fixtures/providers/openmeteo/forecast.json`;
   `respx`-mocked tests for everything.

7. **Time zone handling.** Per canonical-data-model §3.3 (HourlyForecastPoint
   `validTime` is UTC ISO-8601 with Z) AND §3.4 (DailyForecastPoint
   `validDate` is "YYYY-MM-DD station-local"). Open-Meteo requires
   `timezone=` for daily output to bucket days correctly. Module passes
   the station's IANA TZ from `services/station.py`'s
   `StationMetadata.timezone`; module then converts hourly times to UTC
   on the way to canonical `validTime`, leaves daily `validDate` in
   station-local form (already correctly bucketed by Open-Meteo). Per
   ADR-020.

8. **Per-unit handling.** Per ADR-019 §Decision (server passes weewx
   `target_unit` through; provider responses in non-target units must be
   converted at ingest in the provider module). Open-Meteo accepts per-unit
   query params (`temperature_unit`, `wind_speed_unit`,
   `precipitation_unit`); module sets these to match `target_unit` from
   `services/units.py`'s `get_units_block()`'s second return value
   (`target_unit: str` — `"US"` / `"METRIC"` / `"METRICWX"`). Mapping table:
   - `target_unit=US` → `temperature_unit=fahrenheit`, `wind_speed_unit=mph`, `precipitation_unit=inch`.
   - `target_unit=METRIC` → `temperature_unit=celsius`, `wind_speed_unit=kmh`, `precipitation_unit=mm`.
   - `target_unit=METRICWX` → `temperature_unit=celsius`, `wind_speed_unit=ms`, `precipitation_unit=mm`.

   The `ForecastResponse` envelope's `units` block comes from
   `services/units.py:get_units_block()` — same wiring as
   `endpoints/observations.py` and `endpoints/records.py`.

9. **`source` field when no provider configured = literal `"none"`.** Both
   `ForecastBundle.source` and envelope `ForecastResponse.source` set to
   `"none"`. Mirrors 3b-1 alerts pattern.

10. **`discussion: null` for Open-Meteo.** Per canonical-data-model §3.10
    explicitly: "`null` for providers without one (Open-Meteo, OWM,
    Wunderground PWS)". Module returns `ForecastBundle(..., discussion=None)`
    unconditionally.

11. **WMO weather codes pass through as `weatherCode` strings.** Per
    canonical-data-model §3.3 ("Provider-defined code... Opaque to api;
    dashboard maps to icon"). Module emits the WMO code as a string; no
    server-side icon mapping. `weatherText` is decoded from the WMO code
    via a small in-module lookup table per canonical-data-model §4.1.2's
    "(decode from WMO)" instruction. The lookup table covers the codes
    listed in the Open-Meteo docs (api-docs/openmeteo.md "Weather codes"
    section).

12. **`precipType` derived from `weather_code`.** Per canonical-data-model
    §4.1.2 "derived from weather_code (WMO)". Small in-module heuristic
    using the canonical-data-model §3.3 enum values literally — do NOT
    flatten freezing variants to `"rain"`:
    - WMO 51-55 (drizzle: light/moderate/dense) → `"rain"`
    - WMO 56-57 (freezing drizzle: light/dense) → `"freezing-rain"`
    - WMO 61-65 (rain: slight/moderate/heavy) → `"rain"`
    - WMO 66-67 (freezing rain: light/heavy) → `"freezing-rain"`
    - WMO 71-77 (snow / snow grains) → `"snow"`
    - WMO 80-82 (rain showers) → `"rain"`
    - WMO 85-86 (snow showers) → `"snow"`
    - WMO 95-99 (thunderstorm / hail-thunderstorm) → `"rain"`
    - everything else → `null`.

    **Forecast-domain rule for all future provider rounds:** when deriving
    `precipType` from a provider's weather code, use the canonical-data-model
    §3.3 enum values literally (`"rain"`, `"snow"`, `"sleet"`,
    `"freezing-rain"`, `"hail"`, `"none"`). Don't flatten precision the
    canonical model exists to carry. **Original 3b-2 brief said "rain" for
    codes 56/57/66/67; that was wrong against the canonical enum and was
    corrected post-audit (F2). Future Aeris/NWS/OWM/Wunderground forecast
    rounds inherit this corrected rule.**

13. **Hourly horizon = `?hours=` query param, default 48, max from
    Open-Meteo's `forecast_days` cap (16 days × 24 = 384 hours).** Per
    OpenAPI line 195-199. `hours` and `days` query params validate as
    integers, both ≥ 0, with sensible upper bounds (`hours ≤ 384`,
    `days ≤ 16` — Open-Meteo's documented `forecast_days=0..16` range,
    api-docs/openmeteo.md). Slice the canonical hourly[] / daily[] to
    the requested count at the endpoint layer; module always asks
    Open-Meteo for the full default forecast window so the cache entry is
    operator-uniform (one cache entry per station, not one per
    `(hours, days)` tuple).

14. **NWS-style two-step lookup, AFD discussion fetch — N/A here.** Open-Meteo
    has a single `/v1/forecast` endpoint and supplies no discussion. No
    additional outbound calls beyond the one cached call per cache-miss.

15. **Rate limiter for Open-Meteo.** ADR-038 §3 names the rate-limiter
    primitive in the shared `_common/` infrastructure. Open-Meteo's free
    tier publishes a fair-use threshold around ~10 000 calls/day (api-docs
    line 246; not a hard cap, throttled). With cache TTL = 30 min and
    single-station scope, real-world traffic is ~48 calls/day per station
    in steady state — three orders of magnitude under the throttle.
    Lead-call: configure `RateLimiter("openmeteo", max_calls=5,
    window_seconds=1)` as a "be polite" guard; it will essentially never
    trip. Same shape as 3b-1's NWS rate limiter.

16. **F13 redaction-filter `client_id` strip — STAYS DEFERRED.** Open-Meteo
    is keyless. F13 (deferred from 3b round 1) only matters when a keyed
    provider that uses `client_id` (Aeris) lands. Whichever future 3b round
    first ships Aeris extends `logging/redaction_filter.py`. This round is
    not the time. The brief surfaces this so the test-author and api-dev
    don't redo work; no code change to the filter this round.

---

## Hard reading list (once per session)

**Both api-dev and test-author:**

- `CLAUDE.md` — domain routing + always-applicable rules.
- `rules/clearskies-process.md` — full file. **Carry-forward from 3b-1:**
  poll-don't-wait (lead side); verify default branch name (verified — `main`);
  brief questions audit themselves (applied at draft); tests verify the
  brief, brief is the authority (governs api-dev's response when a test
  signature disagrees with this brief — STOP and ping the lead, do NOT
  flip the impl); real schemas in unit tests where shape matters; audit
  modes are complementary; lead synthesizes auditor findings; plain English
  to user; ADR conflicts → STOP; round briefs land in the project not in
  tmp.
- `rules/coding.md` — full file. §1 carry-forward: Pydantic + Depends pattern
  for query-param routes; IPv4/IPv6-agnostic networking (`httpx.Client`
  resolves via `getaddrinfo` natively); no dangerous functions; no hardcoded
  secrets (Open-Meteo is keyless so the secrets path doesn't fire). §3
  applies: catch specific exceptions, never `except Exception:`. §5 (a11y)
  is non-applicable — backend round.
- `docs/contracts/openapi-v1.yaml`:
  - `/forecast` at line 186.
  - `HourlyForecastPoint` at line 1016.
  - `DailyForecastPoint` at line 1035.
  - `ForecastDiscussion` at line 1058.
  - `ForecastBundle` at line 1073.
  - `ForecastResponse` at line 1562.
  - `ProviderProblem` at line 863, `ProviderError` response at line 799,
    `ProviderUnavailable` response at line 807, `CapabilityDeclaration` at
    line 1432.
- `docs/contracts/canonical-data-model.md`:
  - §3.3 (HourlyForecastPoint per-field enumeration + unit groups).
  - §3.4 (DailyForecastPoint per-field enumeration + unit groups).
  - §3.5 (ForecastDiscussion — for the canonical type even though
    Open-Meteo always returns `null`).
  - §3.10 (ForecastBundle container).
  - §4.1.2 (Open-Meteo hourly mapping table).
  - §4.1.3 (Open-Meteo daily mapping table).
  - §4.1.4 (forecast discussion — Open-Meteo column reads "—" because none
    is supplied).
- `docs/contracts/security-baseline.md`:
  - §3.4 (secrets — N/A this round, Open-Meteo keyless; the path is
    already present from 3b-1's NWS wiring for when keyed providers land).
  - §3.5 (input validation — Pydantic models for the wire shape inside
    the normalizer per ADR-038; rule applies here too).
  - §3.6 (logging — provider URL logged at INFO; no sensitive query params
    in Open-Meteo URLs since it's keyless).
- `docs/reference/api-docs/openmeteo.md` — full file. The `/v1/forecast`
  example response at line 77-119 is the source of truth for the wire-shape
  Pydantic models (column-oriented hourly + daily blocks plus the parallel
  `*_units` companion blocks). The variable lists at lines 123-222 are the
  reference for which `hourly=` and `daily=` CSV values to request. Weather
  codes table at line 224-242. Known issues at line 257-264 — particularly
  "`daily=` requires `timezone=`" (call 7), the case-sensitive variable
  names, and "`HTTP 400` with `{"error": true, "reason": "..."}`" on
  invalid params (forecast module classifies as `ProviderProtocolError`).
- `docs/planning/briefs/phase-2-task-3b-1-alerts-brief.md` — template
  structure. Reuse the per-endpoint-spec format, reading list shape,
  cross-cutting requirements, test-author parallel scope, process gates.
  Don't re-derive what's already there.
- `docs/planning/briefs/phase-2-task-3b-1-remediation-1-brief.md` — read
  the F1a/F1b/F2 entries as pattern reference for canonical-taxonomy
  exception handling and warning-vs-error log-level choice. F12's
  signature-vs-tests reasoning governs api-dev's behaviour when a test
  signature disagrees with this brief.
- `.claude/agents/clearskies-api-dev.md` — agent definition including the
  2026-05-07 constraint that tests verify the brief, brief is the authority.

**ADRs to load before implementing:**

- ADR-006 (compliance — operator-managed API keys; Open-Meteo is keyless
  so this doesn't fire, but the keyed-provider pattern frames future
  rounds).
- ADR-007 (forecast providers — day-1 set is 5; this round adds 1, the
  rest land in later 3b rounds).
- ADR-008 (auth model — provider modules don't add user auth).
- ADR-010 (canonical data model — HourlyForecastPoint, DailyForecastPoint,
  ForecastDiscussion, ForecastBundle).
- ADR-011 (single-station — operator lat/lon comes from station metadata,
  not query param).
- ADR-017 (provider response caching — pluggable backend already wired;
  forecast TTL 30 min default per the table; cache key shape).
- ADR-018 (URL-path versioning, RFC 9457 errors, ProviderProblem extension
  carrying providerId/domain/errorCode).
- ADR-019 (units handling — server passes weewx target_unit through;
  provider conversions at ingest in the provider module).
- ADR-020 (time zone — UTC ISO-8601 Z on the wire; station-local for
  date-only fields like DailyForecastPoint.validDate).
- ADR-027 (config — `[forecast] provider = openmeteo` in api.conf;
  secrets in secrets.env when relevant; Open-Meteo doesn't have any).
- ADR-029 (logging — INFO per-request access log; provider URL logged;
  redaction filter runs).
- ADR-038 (provider module organization — five module responsibilities,
  shared infra split, capability declaration fields, canonical error
  taxonomy, testing pattern).

ADRs explicitly NOT in scope this round:

- ADR-013 (AQI — separate 3b round).
- ADR-015 (radar — separate 3b round).
- ADR-016 (alerts — done in 3b round 1).
- ADR-040 (earthquakes — separate 3b round).
- ADR-022 / ADR-023 / ADR-026 (theming, dark mode, a11y — Phase 3
  dashboard).

---

## Existing code (read, do not rewrite)

3b round 1 + earlier rounds landed:

- `weewx_clearskies_api/providers/_common/` — six files. Reusable as-is:
  - `errors.py` — canonical `ProviderError` taxonomy (`QuotaExhausted`,
    `KeyInvalid`, `GeographicallyUnsupported`, `FieldUnsupported`,
    `TransientNetworkError`, `ProviderProtocolError`). Forecast module
    raises from this set; never raises raw httpx classes.
  - `http.py` — `ProviderHTTPClient` wraps `httpx.Client` with timeouts,
    TLS verify, retry/backoff, error-class translation. Forecast module
    instantiates one at module-load time with
    `provider_id="openmeteo", domain="forecast"`.
  - `cache.py` — `get_cache()` returns the active backend (memory or redis,
    chosen by `CLEARSKIES_CACHE_URL` env var per ADR-017). Cache stores
    JSON-serializable values; forecast module stores
    `[bundle.model_dump()]`-shaped dicts and reconstructs via
    `ForecastBundle.model_validate(...)` on cache-read (mirrors
    F12 remediation pattern from 3b-1).
  - `rate_limiter.py` — `RateLimiter` sliding-window primitive. Forecast
    module instantiates with `RateLimiter("openmeteo", max_calls=5,
    window_seconds=1)`.
  - `capability.py` — `ProviderCapability` dataclass + `wire_providers()`
    + `get_provider_registry()`. Forecast module exports a `CAPABILITY`
    of this dataclass at module level.
  - `dispatch.py` — `PROVIDER_MODULES` dict. Add one row this round.
- `weewx_clearskies_api/providers/alerts/nws.py` — working reference for
  the per-provider module shape. Read it; the forecast module follows the
  same five-section layout (constants, wire-shape Pydantic, `fetch()`,
  `_to_canonical()`, helpers).
- `weewx_clearskies_api/providers/alerts/__init__.py` — empty package
  marker. The new `providers/forecast/__init__.py` mirrors it exactly.
- `weewx_clearskies_api/services/station.py` — `load_station_metadata()`
  / `get_station_metadata()` exposes lat/lon/timezone for the forecast
  module. Same pattern alerts uses. Don't re-parse weewx.conf.
- `weewx_clearskies_api/services/units.py` — `load_units_block()` /
  `get_units_block()` returns `(units_block: dict[str, str],
  target_unit: str)`. Forecast endpoint consumes both: the dict goes into
  the response envelope's `units` field; `target_unit` decides
  Open-Meteo's `temperature_unit` / `wind_speed_unit` /
  `precipitation_unit` query params.
- `weewx_clearskies_api/config/settings.py:314 AlertsSettings` — template
  for `ForecastSettings`. Same shape: `provider: str | None`, validate the
  provider id is in the day-1 set per ADR-007 (`{"openmeteo", "nws",
  "aeris", "openweathermap", "wunderground"}` — accepts all five even
  though only `openmeteo` is in dispatch this round; mirrors
  `AlertsSettings`'s pattern of accepting the day-1 set per ADR and
  failing later at dispatch lookup if the operator picks one that hasn't
  been wired yet).
- `weewx_clearskies_api/__main__.py` — already calls
  `_wire_providers_from_config(settings)`. Extend that function to
  also look up the forecast provider via dispatch and append its
  `CAPABILITY`. Single source per domain per ADR-007.
- `weewx_clearskies_api/errors.py` — RFC 9457 + ProviderError handler is
  wired. Forecast errors flow through the existing handler unchanged
  (same canonical taxonomy → same 502/503 + ProviderProblem mapping).
- `weewx_clearskies_api/models/responses.py` — Pydantic response models
  for existing endpoints. Add `HourlyForecastPoint`, `DailyForecastPoint`,
  `ForecastDiscussion`, `ForecastBundle`, `ForecastResponse` here following
  the existing camelCase + extras="ignore" pattern. The `UnitsBlock` type
  alias already exists; reuse.
- `weewx_clearskies_api/models/params.py` — Pydantic + Depends pattern
  from 3a-1. Add `ForecastQueryParams` for the `hours` + `days` filters;
  wire the `Depends(_get_forecast_params)` route binding.
- `weewx_clearskies_api/endpoints/alerts.py` — working reference for the
  endpoint-handler shape (cache-aware fetch, no-provider-configured 200
  path, ProviderError raising flows to the global handler). The forecast
  endpoint follows the same shape with two query params instead of one.
- `weewx_clearskies_api/endpoints/observations.py` /
  `endpoints/records.py` — working reference for the response envelope
  pattern that includes `units: UnitsBlock`. Read either; the forecast
  envelope mirrors them.
- `weewx_clearskies_api/app.py` — register the new forecast router after
  the existing alerts router.
- `weewx_clearskies_api/logging/redaction_filter.py` — already strips
  Authorization, X-Clearskies-Proxy-Auth, appid, client_secret, SQL params.
  **No change this round** (Open-Meteo is keyless, F13 stays deferred).

`pyproject.toml` runtime deps already cover this round: `httpx` (3b-1),
`redis` (3b-1), `pydantic`, `cachetools`, `configobj`, `fastapi`,
`sqlalchemy`. **No new runtime or dev-extras deps this round.** Specifically:
NO `requests`, NO `aiohttp`, NO `tenacity`, NO `pyyaml`. The deps required
are already in the repo. STOP and ping the lead if you think you need
anything else.

---

## Per-endpoint spec

### `GET /forecast` — forecast bundle (hourly + daily + discussion)

- **Query.**
  - `hours` — optional integer ≥ 0, default 48, max 384 (Open-Meteo's
    `forecast_days=16 × 24h` limit). Number of hourly points.
  - `days` — optional integer ≥ 0, default 7, max 16. Number of daily
    points.
  - Pydantic-validate via `Depends(_get_forecast_params)`
    (`extra="forbid"`); reject unknown query keys with 400 RFC 9457; reject
    out-of-range values with 400.
- **Response shape per OpenAPI line 1562:**
  - 200 → `ForecastResponse(data=ForecastBundle(hourly=[...],
    daily=[...], discussion=null OR ForecastDiscussion, source=..., generatedAt=...),
    units=UnitsBlock, source=..., generatedAt=...)`. Both `data.source` and
    envelope `source` set to the configured provider id (e.g. `"openmeteo"`)
    OR `"none"` per call 9.
  - 502 → `ProviderError` (RFC 9457 ProviderProblem) for `KeyInvalid`,
    `TransientNetworkError`, `ProviderProtocolError`, `FieldUnsupported`.
  - 503 → `ProviderUnavailable` (RFC 9457 ProviderProblem) for
    `QuotaExhausted` (with `Retry-After`), `GeographicallyUnsupported`.
  - default → standard Problem.
- **Behaviour decision tree:**
  1. `[forecast] provider` not set in api.conf → 200 with
     `ForecastBundle(hourly=[], daily=[], discussion=null, source="none",
     generatedAt=now())`. No upstream call. No error.
  2. `[forecast] provider = openmeteo` and Open-Meteo returns 200 → normalize
     the column-oriented hourly + daily blocks per canonical-data-model
     §4.1.2 / §4.1.3; slice to `hours` / `days` (truncate from the head if
     the requested count is smaller than what Open-Meteo returned); return
     200.
  3. `[forecast] provider = openmeteo` and Open-Meteo returns 5xx / network
     failure / DNS timeout → raise `TransientNetworkError` → 502
     ProviderProblem with `errorCode="TransientNetworkError"` (after
     `_common/http.py`'s retry/backoff exhausts).
  4. `[forecast] provider = openmeteo` and Open-Meteo returns 429 → raise
     `QuotaExhausted` → 503 ProviderProblem with
     `errorCode="QuotaExhausted"` + `Retry-After: 60` header (Open-Meteo
     rarely surfaces 429 — fair-use is throttled, not hard-capped — but
     the path lands).
  5. `[forecast] provider = openmeteo` and Open-Meteo returns 400 with
     `{"error": true, "reason": "..."}` → `ProviderProtocolError` (we
     constructed an invalid request; the operator's lat/lon is bad, or the
     module's variable list disagrees with the API). Log at ERROR with the
     reason.
  6. `[forecast] provider = openmeteo` and Open-Meteo response shape
     unexpected (Pydantic validation on the wire model fails) → raise
     `ProviderProtocolError` → 502 with full response body logged at ERROR.
- **Cache integration.** Module calls `cache.get(key)` first; key per
  ADR-017 is hash of `(provider_id="openmeteo", endpoint="/v1/forecast",
  normalized_params={"latitude": round(lat, 4), "longitude": round(lon, 4),
  "target_unit": target_unit})`. Cache stores the **post-normalization
  ForecastBundle** as a `model_dump()`-ed dict; cache-read reconstructs via
  `ForecastBundle.model_validate(d)`. TTL = 1800s (30 min per ADR-017).
- **Slice AFTER cache lookup.** Cache stores the FULL bundle (every hourly
  + daily point Open-Meteo returned). Endpoint applies the operator's
  `hours` / `days` slice on the cached canonical bundle. One cache entry
  per `(station, target_unit)`, not one per `(hours, days)` tuple.
- **No DB hit.** Forecast comes from the provider, not weewx archive.
- **Operator lat/lon / target_unit / timezone source.** Read from
  `services/station.py`'s cached `StationMetadata` (lat, lon, timezone)
  and `services/units.py`'s `get_units_block()` (target_unit). Single-station
  per ADR-011; no `?station=` param.
- **Failure mode: settings not yet wired.** Impossible per startup
  ordering (`load_units_block()` and `load_station_metadata()` complete
  before uvicorn starts); endpoint trusts the cache. If a future ordering
  bug surfaces, the response is 503 with a `Problem(title="Service
  starting", status=503)`. Defense in depth.

---

## Per-module spec — `providers/forecast/openmeteo.py`

Five responsibilities per ADR-038 §2. Module structure mirrors
`providers/alerts/nws.py` from 3b-1 — five sections in the same order.

### Module-level constants

```python
PROVIDER_ID = "openmeteo"
DOMAIN = "forecast"
OPENMETEO_BASE_URL = "https://api.open-meteo.com"
OPENMETEO_FORECAST_PATH = "/v1/forecast"
DEFAULT_FORECAST_TTL_SECONDS = 1800   # 30 min per ADR-017

CAPABILITY = ProviderCapability(
    provider_id=PROVIDER_ID,
    domain=DOMAIN,
    supplied_canonical_fields=(
        # HourlyForecastPoint
        "validTime", "outTemp", "outHumidity",
        "windSpeed", "windDir", "windGust",
        "precipProbability", "precipAmount", "precipType",
        "cloudCover", "weatherCode", "weatherText",
        # DailyForecastPoint
        "validDate", "tempMax", "tempMin",
        "precipAmount", "precipProbabilityMax",
        "windSpeedMax", "windGustMax",
        "sunrise", "sunset", "uvIndexMax",
        # NB: discussion fields NOT supplied by Open-Meteo
    ),
    geographic_coverage="global",
    auth_required=(),
    default_poll_interval_seconds=DEFAULT_FORECAST_TTL_SECONDS,
    operator_notes=(
        "Open-Meteo free-tier; no API key required for non-commercial "
        "use. Throttled at ~10 000 calls/day fair-use. No forecast "
        "discussion available — bundle.discussion is always null."
    ),
)

# Open-Meteo unit-param mapping per ADR-019 + canonical §4.1.2
_TARGET_UNIT_TO_OPENMETEO_UNITS: dict[str, dict[str, str]] = {
    "US":       {"temperature_unit": "fahrenheit", "wind_speed_unit": "mph", "precipitation_unit": "inch"},
    "METRIC":   {"temperature_unit": "celsius",    "wind_speed_unit": "kmh", "precipitation_unit": "mm"},
    "METRICWX": {"temperature_unit": "celsius",    "wind_speed_unit": "ms",  "precipitation_unit": "mm"},
}

# WMO weather code → short text (canonical §3.3 weatherText)
_WMO_CODE_TO_TEXT: dict[int, str] = {
    0: "Clear sky",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Depositing rime fog",
    51: "Light drizzle", 53: "Moderate drizzle", 55: "Dense drizzle",
    56: "Light freezing drizzle", 57: "Dense freezing drizzle",
    61: "Slight rain", 63: "Moderate rain", 65: "Heavy rain",
    66: "Light freezing rain", 67: "Heavy freezing rain",
    71: "Slight snow", 73: "Moderate snow", 75: "Heavy snow",
    77: "Snow grains",
    80: "Slight rain showers", 81: "Moderate rain showers", 82: "Violent rain showers",
    85: "Slight snow showers", 86: "Heavy snow showers",
    95: "Thunderstorm",
    96: "Thunderstorm with slight hail", 99: "Thunderstorm with heavy hail",
}

# WMO weather code → precipType (canonical §3.3 precipType)
_WMO_CODE_TO_PRECIP_TYPE: dict[int, str] = {
    # rain family
    51: "rain", 53: "rain", 55: "rain",
    61: "rain", 63: "rain", 65: "rain",
    80: "rain", 81: "rain", 82: "rain",
    95: "rain", 96: "rain", 99: "rain",
    # freezing-rain family
    56: "freezing-rain", 57: "freezing-rain",
    66: "freezing-rain", 67: "freezing-rain",
    # snow family
    71: "snow", 73: "snow", 75: "snow", 77: "snow",
    85: "snow", 86: "snow",
    # everything else (0, 1, 2, 3, 45, 48) → null (no precip)
}

# Variable lists requested from Open-Meteo
_HOURLY_VARS = (
    "temperature_2m", "relative_humidity_2m",
    "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m",
    "precipitation_probability", "precipitation",
    "weather_code", "cloud_cover",
)
_DAILY_VARS = (
    "temperature_2m_max", "temperature_2m_min",
    "precipitation_sum", "precipitation_probability_max",
    "wind_speed_10m_max", "wind_gusts_10m_max",
    "sunrise", "sunset",
    "uv_index_max", "weather_code",
)
```

### Wire-shape Pydantic models

Per security-baseline §3.5 + canonical-rules. `extras="ignore"` so future
Open-Meteo additions don't break us; missing required fields raise
`ValidationError` → translated to `ProviderProtocolError`.

The wire shape is **column-oriented** — every variable in `hourly` /
`daily` is an array, all arrays in a block share the index of `time`. The
Pydantic model preserves that shape; row construction happens in
`_to_canonical()`.

```python
class _OpenMeteoCurrentBlock(BaseModel):
    """Reserved for future use; current observation isn't surfaced this round."""
    model_config = ConfigDict(extra="ignore")


class _OpenMeteoHourlyBlock(BaseModel):
    """Column-oriented hourly forecast block.

    Open-Meteo returns each variable as a parallel array keyed by `time`;
    array indices align across variables. _to_canonical() zips them
    into per-hour records.
    """
    model_config = ConfigDict(extra="ignore")
    time: list[str] = Field(default_factory=list)
    temperature_2m: list[float | None] = Field(default_factory=list)
    relative_humidity_2m: list[float | None] = Field(default_factory=list)
    wind_speed_10m: list[float | None] = Field(default_factory=list)
    wind_direction_10m: list[float | None] = Field(default_factory=list)
    wind_gusts_10m: list[float | None] = Field(default_factory=list)
    precipitation_probability: list[float | None] = Field(default_factory=list)
    precipitation: list[float | None] = Field(default_factory=list)
    weather_code: list[int | None] = Field(default_factory=list)
    cloud_cover: list[float | None] = Field(default_factory=list)


class _OpenMeteoDailyBlock(BaseModel):
    model_config = ConfigDict(extra="ignore")
    time: list[str] = Field(default_factory=list)
    temperature_2m_max: list[float | None] = Field(default_factory=list)
    temperature_2m_min: list[float | None] = Field(default_factory=list)
    precipitation_sum: list[float | None] = Field(default_factory=list)
    precipitation_probability_max: list[float | None] = Field(default_factory=list)
    wind_speed_10m_max: list[float | None] = Field(default_factory=list)
    wind_gusts_10m_max: list[float | None] = Field(default_factory=list)
    sunrise: list[str | None] = Field(default_factory=list)
    sunset: list[str | None] = Field(default_factory=list)
    uv_index_max: list[float | None] = Field(default_factory=list)
    weather_code: list[int | None] = Field(default_factory=list)


class _OpenMeteoForecastResponse(BaseModel):
    """Top-level Open-Meteo `/v1/forecast` envelope — wire shape."""
    model_config = ConfigDict(extra="ignore")
    latitude: float
    longitude: float
    timezone: str
    utc_offset_seconds: int
    hourly: _OpenMeteoHourlyBlock | None = None
    daily: _OpenMeteoDailyBlock | None = None
```

### `fetch(*, lat: float, lon: float, target_unit: str, timezone: str) -> ForecastBundle` — public entrypoint

Single callable. Returns canonical `ForecastBundle` (Pydantic model — NOT
a dict; per F12 lesson from 3b-1).

```python
def fetch(
    *,
    lat: float,
    lon: float,
    target_unit: str,
    timezone: str,
) -> ForecastBundle:
    """Call Open-Meteo /v1/forecast and return canonical ForecastBundle.

    Raises canonical ProviderError taxonomy on failure.

    Returns a ForecastBundle with discussion=None always (Open-Meteo
    has no discussion endpoint).
    """
    cache_key = _build_cache_key(lat, lon, target_unit)
    cached = get_cache().get(cache_key)
    if cached is not None:
        return ForecastBundle.model_validate(cached)

    rate_limiter.acquire()
    client = _client_for()

    unit_params = _TARGET_UNIT_TO_OPENMETEO_UNITS.get(target_unit)
    if unit_params is None:
        # Should never happen — services/units.py validates target_unit
        # at startup. Defensive raise: ProviderProtocolError so the
        # canonical-taxonomy handler emits 502.
        raise ProviderProtocolError(
            f"unknown target_unit {target_unit!r}",
            provider_id=PROVIDER_ID, domain=DOMAIN,
        )

    params = {
        "latitude": f"{round(lat, 4)}",
        "longitude": f"{round(lon, 4)}",
        "hourly": ",".join(_HOURLY_VARS),
        "daily": ",".join(_DAILY_VARS),
        "timezone": timezone,
        "timeformat": "iso8601",
        **unit_params,
    }
    response = client.get(
        f"{OPENMETEO_BASE_URL}{OPENMETEO_FORECAST_PATH}",
        params=params,
    )

    try:
        wire = _OpenMeteoForecastResponse.model_validate(response.json())
    except ValidationError as exc:
        raise ProviderProtocolError(
            f"Open-Meteo response validation failed: {exc}",
            provider_id=PROVIDER_ID, domain=DOMAIN,
        ) from exc

    bundle = _to_canonical(wire, utc_offset_seconds=wire.utc_offset_seconds)
    get_cache().set(
        cache_key,
        bundle.model_dump(mode="json"),
        ttl_seconds=DEFAULT_FORECAST_TTL_SECONDS,
    )
    return bundle
```

### `_to_canonical(wire, *, utc_offset_seconds)` — wire → canonical

Per canonical-data-model §4.1.2 + §4.1.3. Zips the column arrays into
per-hour and per-day records.

```python
def _to_canonical(
    wire: _OpenMeteoForecastResponse,
    *,
    utc_offset_seconds: int,
) -> ForecastBundle:
    hourly_points: list[HourlyForecastPoint] = []
    if wire.hourly is not None:
        hourly_points = _zip_hourly(wire.hourly, utc_offset_seconds)

    daily_points: list[DailyForecastPoint] = []
    if wire.daily is not None:
        daily_points = _zip_daily(wire.daily, utc_offset_seconds)

    return ForecastBundle(
        hourly=hourly_points,
        daily=daily_points,
        discussion=None,             # Open-Meteo supplies none, ever
        source=PROVIDER_ID,
        generatedAt=_now_utc_iso8601(),
    )
```

`_zip_hourly` walks `wire.hourly.time[i]` and pulls index `i` from each
companion array, building one `HourlyForecastPoint` per index. Times come
out of Open-Meteo as ISO local-time strings (`"2026-04-30T16:00"`); the
station-local-to-UTC conversion uses `wire.utc_offset_seconds` from the
response (the value Open-Meteo returns for the requested `timezone=`
param). Daily `time[i]` is `"YYYY-MM-DD"` station-local already and goes
into canonical `validDate` as-is.

### Helper functions

- `_zip_hourly(hourly_block, utc_offset_seconds) -> list[HourlyForecastPoint]`
  — column arrays → row records. `validTime` = local ISO + offset → UTC.
  `weatherCode` = stringified WMO int; `weatherText` = `_WMO_CODE_TO_TEXT.get(code)`;
  `precipType` = `_WMO_CODE_TO_PRECIP_TYPE.get(code)`.
- `_zip_daily(daily_block, utc_offset_seconds) -> list[DailyForecastPoint]`
  — same pattern; `validDate` is the date string as-is; `sunrise`/`sunset`
  are local ISO → UTC. `narrative` is always `None` (Open-Meteo doesn't
  supply one).
- `_local_iso_to_utc_iso8601(local_iso, utc_offset_seconds) -> str` —
  `"2026-04-30T16:00" + offset = -25200` → `"2026-04-30T23:00:00Z"`.
  Naive parse with `datetime.fromisoformat` then `astimezone(UTC)`.
- `_build_cache_key(lat, lon, target_unit) -> str` — sha256 of
  json-encoded normalized params (matches the alerts cache-key shape).
- `_client_for() -> ProviderHTTPClient` — module-level singleton; constructed
  on first call. UA = `(weewx-clearskies-api/<version>)` (no operator
  contact knob this round; Open-Meteo doesn't require one — only NWS
  does).
- `_now_utc_iso8601() -> str` — reuse the existing helper from
  `models/responses.py` if it exists; otherwise inline `datetime.now(UTC).strftime(...)`.

---

## Cross-cutting requirements

### Pydantic + `Depends(_get_forecast_params)` pattern

`/forecast` takes `hours` and `days` query params. Use the wrapper pattern
from `rules/coding.md` §1 ("Pydantic `extra="forbid"` requires the right
FastAPI wiring"). Same shape as `_get_alerts_params` and the 3a-1 endpoint
wiring.

### RFC 9457 errors

The existing `errors.py` ProviderError handler from 3b round 1 covers
forecast errors unchanged. ProviderProblem extension fields
(`providerId="openmeteo"`, `domain="forecast"`, `errorCode`, optional
`retryAfterSeconds`) come for free.

### Logging

Per ADR-029. Provider HTTP outbound calls log at INFO with: `provider_id`,
`domain`, URL (no sensitive query params for Open-Meteo since it's
keyless), `elapsed_ms`, `status_code`. On error: WARNING (transient) or
ERROR (protocol). Cache hit/miss counters at DEBUG.

### Catch specific exceptions

`rules/coding.md` §3 — no `except Exception:`. The HTTP wrapper from
`_common/http.py` already catches the specific httpx classes. The
forecast module catches `ValidationError` from Pydantic at the wire-model
boundary; everything else flows through the canonical taxonomy.

### No live-network tests in CI (ADR-038 §Testing pattern)

Recorded fixture: `tests/fixtures/providers/openmeteo/forecast.json` (real
Open-Meteo response captured manually). All mock-network tests use `respx`
to patch the URL → fixture mapping.

### Capability-population wire (extends 3b-1's `_wire_providers_from_config`)

In `__main__.py`'s `_wire_providers_from_config(settings)`, after the
existing alerts append, add a forecast lookup:

```python
def _wire_providers_from_config(settings: Settings) -> None:
    declarations: list[ProviderCapability] = []
    if settings.alerts.provider:
        module = get_provider_module(domain="alerts", provider_id=settings.alerts.provider)
        declarations.append(module.CAPABILITY)
    if settings.forecast.provider:
        module = get_provider_module(domain="forecast", provider_id=settings.forecast.provider)
        declarations.append(module.CAPABILITY)
    # Future rounds extend this with aqi, earthquakes, radar.
    wire_providers(declarations)
```

**Failure modes:**

- `[forecast] provider = <unknown-id-not-in-dispatch>` → `KeyError` from
  `get_provider_module()` → CRITICAL log + exit non-zero at startup.
  Operator misconfig; fail closed.
- `[forecast] provider = <ADR-007-listed-but-not-yet-wired>` (e.g. `nws`,
  `aeris`, `openweathermap`, `wunderground` this round) — `ForecastSettings`
  validates as accepted ID, then dispatch lookup raises `KeyError` at
  startup. Same failure mode as the alerts case in 3b-1 (auditor confirmed
  correct as F7 in the remediation brief).
- `[forecast] provider` absent → empty contribution; `/forecast` returns
  `source="none"` per call 9.

### No new ADRs

ADR-007 covers the forecast day-1 set. ADR-017 covers caching. ADR-038
covers module organization. ADR-019 covers units. ADR-020 covers
timestamps. **STOP and ping the lead** if implementation surfaces a need
for a new ADR — that's a process call, not a code call.

### No new dependencies

All deps required by this round are already in `pyproject.toml`. STOP and
ping the lead if you think you need anything else.

### Tests verify the brief; brief is the authority

Per `rules/clearskies-process.md` (added 2026-05-07) +
`.claude/agents/clearskies-api-dev.md`. If api-dev's `fetch()` signature
disagrees with what test-author wrote, **api-dev STOPs and pings the
lead**. The brief explicitly types `fetch() → ForecastBundle` (single
canonical entity, not a list — forecast bundles one of each canonical
type rather than alerts' list-shaped result). Don't flip the impl to a
list or to a dict.

### Diff size budget

Target ~1500-2500 line impl diff (not counting tests). Smaller than 3b
round 1 because the shared infrastructure (HTTP wrapper, retry, error
taxonomy, capability registry, both cache backends, rate limiter) already
lives. New code is the openmeteo module + endpoint + Pydantic models +
ForecastSettings + dispatch row. If it crosses 3000 lines, ping the lead
before submitting for audit; we may split the round.

---

## Test-author parallel scope

Run `pytest` on `weather-dev` (192.168.2.113); never on DILBERT.

### Recorded fixture capture

`tests/fixtures/providers/openmeteo/forecast.json` — captured manually
from a real Open-Meteo response. Recommended capture command (run once on
weather-dev, not in CI):

```bash
curl "https://api.open-meteo.com/v1/forecast?latitude=47.6062&longitude=-122.3321&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m,precipitation_probability,precipitation,weather_code,cloud_cover&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,sunrise,sunset,uv_index_max,weather_code&timezone=America%2FLos_Angeles&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch&timeformat=iso8601" \
  | python -m json.tool > tests/fixtures/providers/openmeteo/forecast.json
```

The fixture should include AT LEAST the default 7 days × 24 hours of
forecast points so the slice tests can verify truncation. Document the
capture date in a sidecar `.md` next to the fixture for future replay.

Adjacent fixtures for negative-path testing:

- `forecast_no_hourly.json` — hand-crafted variant with `hourly: null` in
  the wire shape (Open-Meteo can return this if the operator's request
  omits `hourly=`); test that `_to_canonical` returns `hourly=[]`.
- `forecast_no_daily.json` — same with `daily: null`.
- `forecast_unknown_wmo_code.json` — hand-crafted variant with a
  weather_code value not in `_WMO_CODE_TO_TEXT` (e.g. 200); verify that
  `weatherText` becomes `null` (not an exception) and `precipType` becomes
  `null`.
- `forecast_malformed.json` — hand-crafted variant missing the required
  `latitude` field; verify `ProviderProtocolError` raise.
- `forecast_400_error.json` — Open-Meteo error envelope
  `{"error": true, "reason": "Latitude must be in range of -90 to 90."}`;
  verify the HTTP wrapper translates 400 → `ProviderProtocolError`.

### Unit tests (no DB, no network — `respx` mock or pure-compute)

- **WMO code → text mapping.** Each documented code maps to its text
  string. Unknown code → `None` (no exception).
- **WMO code → precipType mapping.** Each rain/freezing-rain/snow code
  maps correctly. Codes 0/1/2/3/45/48/everything-else → `None`.
- **Local-ISO → UTC conversion.** `"2026-04-30T16:00"` with
  `utc_offset_seconds=-25200` → `"2026-04-30T23:00:00Z"`. UTC offset 0 →
  same time + `Z`. Positive offset (e.g. +9 h Tokyo) → `"...UTC..."`.
- **Per-target-unit param mapping.** `"US"` → fahrenheit/mph/inch.
  `"METRIC"` → celsius/kmh/mm. `"METRICWX"` → celsius/ms/mm. Unknown
  target_unit (defensive case) → `ProviderProtocolError`.
- **`_zip_hourly` correctness.** Given a 3-hour fixture column block,
  zips into 3 `HourlyForecastPoint` records with correct field-by-field
  values. Null entries in any companion array surface as `null` in the
  canonical record (not as the previous index's value).
- **`_zip_daily` correctness.** Same shape; `validDate` stays as-is;
  sunrise/sunset converted to UTC.
- **Wire-shape Pydantic.** Real fixture loads cleanly. Missing required
  field (e.g. `latitude`) → `ValidationError`. Extra field (Open-Meteo
  adds a new variable) → ignored cleanly.
- **`ForecastQueryParams`.** Reject unknown query keys (`extra="forbid"`);
  reject negative `hours` / `days`; reject `hours > 384`; reject `days > 16`;
  accept defaults; missing both OK.
- **Hourly slice.** Given a canonical bundle with 168 hourly points,
  `?hours=24` returns 24; `?hours=200` returns 168 (the full available);
  `?hours=0` returns 0. Daily slice is parallel.
- **Module fetch — happy path (respx-mocked).** 200 with the recorded
  fixture → returns a `ForecastBundle` with the correct counts of hourly
  + daily points; `discussion` is `None`; `source="openmeteo"`. Spot-check
  one hourly + one daily field for value correctness against the fixture.
- **Module fetch — cache hit.** Pre-populate cache with a serialized
  bundle; `fetch()` returns the reconstructed bundle without an outbound
  HTTP call (assert respx call count = 0). Run twice — once with memory
  cache, once with redis (via `fakeredis`, mirrors 3b-1 pattern).
- **Module fetch — 5xx.** respx-mocked 503 from Open-Meteo → after
  retries, `TransientNetworkError`.
- **Module fetch — 429.** respx-mocked 429 → `QuotaExhausted` with
  `retry_after_seconds` set.
- **Module fetch — 400 with error envelope.** respx-mocked 400 with
  `{"error": true, "reason": "..."}` body → `ProviderProtocolError`.
- **Module fetch — malformed wire shape.** respx-mocked 200 with
  `forecast_malformed.json` → `ProviderProtocolError`.
- **Module fetch — `hourly: null`.** Returns a bundle with `hourly=[]`,
  not an exception.
- **Capability registry — forecast module.** `wire_providers([alerts_cap,
  forecast_cap])` populates both; `get_provider_registry()` returns both.
- **`/capabilities` response — forecast configured.** Response includes
  the openmeteo provider declaration in `providers`;
  `canonicalFieldsAvailable` is the union of stock columns + alerts
  fields (if alerts also configured) + forecast fields.
- **`/forecast` endpoint — no provider configured.** Response shape:
  200, `data.hourly: []`, `data.daily: []`, `data.discussion: null`,
  `data.source: "none"`, `data.generatedAt` set, envelope `units` block
  populated, envelope `source: "none"`, envelope `generatedAt` set.
- **`/forecast` endpoint — Open-Meteo configured (respx-mocked) — happy
  path.** 200; data.hourly has the requested count; data.daily same;
  data.source: "openmeteo"; envelope `units` is the loaded UnitsBlock.
- **`/forecast` endpoint — slice via query params.** `?hours=24&days=3` →
  bundle has exactly 24 hourly points and 3 daily points.
- **`/forecast` endpoint — defaults.** No query params → 48 hourly, 7
  daily.
- **`/forecast` endpoint — invalid query.** `?nuke=1` → 422 RFC 9457.
  `?hours=-1` → 422. `?hours=999999` → 422 (above cap). `?days=20` → 422.
- **`/forecast` endpoint — Open-Meteo down.** respx-mocked 503 → 502
  ProviderProblem with `errorCode="TransientNetworkError"`.
- **`/forecast` endpoint — Open-Meteo quota exhausted.** respx-mocked 429
  → 503 ProviderProblem with `errorCode="QuotaExhausted"` + `Retry-After`
  header.

### Integration tests (against the docker-compose dev/test stack — both DB backends + both cache backends)

Mark each with `@pytest.mark.integration`.

- **`/forecast` with no provider configured** — full TestClient → 200,
  empty bundle, `source: "none"`. No network.
- **`/forecast` with Open-Meteo configured + respx-mocked** — TestClient
  calls `/forecast`; respx intercepts the outbound httpx call; returns
  the recorded fixture; endpoint normalizes and returns 200. Both DB
  backends green (the forecast endpoint doesn't touch DB but the test
  infra runs both for parity).
- **`/capabilities` with both alerts+forecast configured** — response
  includes both provider declarations; `canonicalFieldsAvailable` is the
  full union.
- **Startup with `[forecast] provider = openmeteo`** — process starts
  cleanly; `_wire_providers_from_config` succeeds.
- **Startup with `[forecast] provider = unknown_provider`** — process
  fails at `ForecastSettings.validate()` (rejected by the day-1 set
  enumeration).
- **Startup with `[forecast] provider = nws`** — process fails at
  dispatch lookup (`KeyError`) → CRITICAL log + exit non-zero. Same
  pattern as the alerts case in 3b-1's F7.
- **Redis-backend integration (real Redis via the existing `redis`
  compose profile from 3b-1).** Optional integration tier: `pytest -m
  "integration and redis"` runs `/forecast` end-to-end against a real
  Redis. Default `pytest -m integration` skips the redis tier.

### Schema-shape rule

Same as 3b-1: provider tests don't depend on weewx archive schema, but
the wire-shape Pydantic models for Open-Meteo MUST be validated against
the recorded fixture. No synthetic minimal stand-ins.

### Tests run on `weather-dev` BEFORE the dev submits for audit

Per `rules/clearskies-process.md` "Audit modes are complementary, not
redundant". Both gates fire.

### Marker

All integration tests carry `@pytest.mark.integration`. Unit tests run by
default.

---

## Process gates

1. **ADR conflicts → STOP.** If anything in `openapi-v1.yaml` disagrees
   with an ADR or with canonical-data-model, do not proceed-and-flag at
   closeout. Stop at the first conflict, ping the lead.
2. **No new dependencies.** All deps from prior rounds cover this round.
   Anything else → STOP.
3. **Diff size budget.** Target ~1500-2500 line impl diff. If it crosses
   3000, ping the lead before submitting.
4. **Run pytest on weather-dev before submitting for audit.** Both DB
   backends + both cache backends green. Pre-existing skipped tests
   (`test_mariadb_writable_seed_user_probe_exits_nonzero`) stay skipped;
   not a regression. The 3b-1 baseline is 642 passed / 24 skipped on
   `weather-dev`; this round adds tests, count goes up.
5. **Parallel-pull-then-pytest.** `git fetch origin main && git merge
   --ff-only origin/main` BEFORE the pre-submit pytest run, so api-dev's
   suite covers test-author's latest. Hard gate. **Branch is `main`**.
6. **Auditor reviews after both api-dev and test-author submit + green
   pytest.** Lead synthesizes findings; routes back to the relevant
   teammate per finding.
7. **Submit closeout report immediately after the final pytest run.**
   Don't idle. The lead-side polling cadence is the safety net.
8. **Commit messages document non-obvious provenance** per the
   `clearskies-api-dev` agent definition. Especially for: WMO code-text
   table choices (e.g., why `Drizzle` is the term for codes 51-55 instead
   of `Light rain`); per-target-unit param-mapping table (cite ADR-019);
   slice-after-cache pattern (cite ADR-017 cache-key shape).
9. **Tests verify the brief; brief is the authority.** If api-dev's
   signature for `fetch()` disagrees with what test-author wrote, api-dev
   STOPs and pings the lead. **`fetch()` returns `ForecastBundle`** — one
   Pydantic model, not a list, not a dict.
10. **DCO + co-author trailer.** `git commit -s` plus
    `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` for
    api-dev / test-author work; Opus uses `Co-Authored-By: Claude Opus
    4.7 (1M context) <noreply@anthropic.com>`.

---

## Anti-patterns (don't)

- Don't add NWS / Aeris / OpenWeatherMap / Wunderground forecast modules
  this round. Each lands in its own future 3b round.
- Don't add AQI / earthquakes / radar provider modules. Separate 3b
  rounds.
- Don't reach for `requests`, `aiohttp`, `tenacity`, `pyyaml`, or any
  other lib. The shared infrastructure covers everything.
- Don't disable TLS verification. EVER. Even for testing — use respx.
- Don't bypass the canonical error taxonomy. Open-Meteo errors map to
  the existing `ProviderError` hierarchy; nowhere else catches httpx.
- Don't catch `Exception:`. Catch specific classes. (`rules/coding.md` §3)
- Don't skip the recorded fixture. Synthetic minimal wire-shape stand-ins
  hide protocol-evolution bugs the same way synthetic DB schemas hid
  multi-column constraint bugs.
- Don't make outbound HTTP from CI tests. Live-network is developer-local
  per ADR-038.
- Don't store the wire response in cache. Cache the canonical
  `ForecastBundle` (post-normalization, as `model_dump()`-ed dict).
- Don't add a request-result cache at the FastAPI handler level. The
  ADR-017 cache lives at the provider level.
- Don't add a regex for "an IP address" anywhere.
- Don't read api.conf twice. Settings cache is loaded once at startup.
- Don't import skyfield, sqlalchemy, or any DB lib in the forecast module.
- Don't break 3a-2's `/capabilities` response shape or 3b-1's `/alerts`
  endpoint. Both extend rather than mutate.
- Don't extend `logging/redaction_filter.py` this round. F13 stays
  deferred until a `client_id`-using provider lands.
- Don't hardcode the project's git URL or maintainer email anywhere.
- Don't surface `extras` for forecast points unless Open-Meteo emits a
  variable that would land there. Open-Meteo's response is well-known —
  every variable we request maps to a canonical field. `extras = {}` is
  fine; the OpenAPI shape allows it (the schema reuses `Observation`'s
  `extras` definition; an empty dict serializes as `{}`).
- Don't flip `fetch()` to return a list or a dict to satisfy a test.
  Tests verify the brief; brief is the authority. STOP and ping the lead
  on signature divergence.
- Don't hold across turns. Write to a file as you go.

---

## Reporting back

When you're done, report to the lead:

- **Files touched.** Relative paths + LOC delta. Group by
  `providers/forecast/`, `endpoints/`, `models/`, `config/`, `__main__.py`,
  `app.py`, `tests/`.
- **ADRs and rules that governed each substantive choice.** Reference
  the lead-resolved calls list at the top of this brief.
- **Pytest counts both backends.** Total / unit / integration / passes /
  failures / skips. Note any newly-skipped tests and why. Compare against
  the 3b-1 baseline of 642/24/0.
- **Recorded fixture provenance.** When was the Open-Meteo response
  captured? From what location? How many hourly + daily points are in
  the fixture? Sidecar `.md` documents this; reference it.
- **WMO code-table coverage.** Confirm the `_WMO_CODE_TO_TEXT` and
  `_WMO_CODE_TO_PRECIP_TYPE` tables cover the codes listed in the
  Open-Meteo docs. Note any code in the docs that isn't in the table
  (intentional or oversight).
- **Time conversion correctness.** Confirm hourly times are converted
  station-local-ISO → UTC-Z; daily dates stay station-local. Spot-check
  with the fixture's `utc_offset_seconds`.
- **Per-target-unit handling.** Confirm `target_unit=US/METRIC/METRICWX`
  each map to the right Open-Meteo `*_unit` query params.
- **Slice behaviour.** Confirm hourly/daily slicing happens at the
  endpoint, not in the module; cache stores the full bundle.
- **Capability registry shape.** Spot-check the `/capabilities` JSON
  output with both alerts (NWS) AND forecast (Open-Meteo) configured;
  confirm `canonicalFieldsAvailable` is the union of stock columns +
  both providers' supplied fields.
- **F13 status.** Confirm the redaction filter is unchanged; F13 stays
  deferred until a `client_id`-using provider (Aeris) lands in a future
  3b forecast round.
- **Anything that surprised you in the existing task 1 / 2 / 3a / 3b-1
  code** — especially how the existing `_wire_providers_from_config`
  pattern interacts with the new forecast lookup.
- **Any deviation from this brief** (and why).

---

## Out of scope, parking lot for follow-ups

- **NWS forecast module.** Next 3b forecast round (or one after).
- **Aeris forecast module.** Later 3b forecast round; first round to ship
  Aeris extends `logging/redaction_filter.py` to strip `client_id` (F13).
- **OpenWeatherMap forecast module.** Later 3b forecast round; the
  free/basic/One-Call-3.0 tier-gating logic lands then.
- **Wunderground forecast module.** Later 3b forecast round; PWS-only
  gating + missing-hourly handling lands then.
- **Open-Meteo commercial host (`customer-api.open-meteo.com`) +
  `apikey`.** Future round if operator demand surfaces.
- **Operator-overridable forecast TTL.** Phase 2 sub-round once we have
  more than one forecast provider.
- **Operator-overridable rate-limit knobs.** Same.
- **Setup-wizard region-based provider suggestion.** Phase 4 per ADR-027.
- **Capability-registry HTTP endpoint shape changes.** Locked at v0.1.
- **Multi-station forecast.** ADR-011 single-station; future ADR if
  demand surfaces.
- **Dashboard icon-mapping for WMO codes.** Owned by the dashboard repo;
  api passes `weatherCode` through as the WMO integer-as-string per
  canonical §3.3.
- **Server-side narrative generation.** ADR-007 doesn't promise narrative
  generation; Open-Meteo doesn't supply one; canonical model marks it
  nullable. Phase 6+ if a use case surfaces.
- **Live-network test against api.open-meteo.com.** Developer-local
  workflow per ADR-038 §Testing pattern.
- **HTTP/2 for the Open-Meteo client.** Open-Meteo doesn't use h2 today;
  revisit per provider in future rounds.
