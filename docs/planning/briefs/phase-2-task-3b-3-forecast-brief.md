# Phase 2 task 3b round 3 brief — clearskies-api forecast domain (NWS)

**Round identity.** Phase 2 task 3 sub-round 3b round 3. Third of 5 expected
3b rounds. 3b round 1 (alerts/NWS + shared `providers/_common/`) closed
2026-05-07. 3b round 2 (forecast/Open-Meteo) closed 2026-05-07. **3b round 3
adds the NWS forecast provider** — second concrete forecast provider, first
canonical `ForecastDiscussion` end-to-end via NWS Area Forecast Discussion
(AFD). Future 3b forecast rounds add Aeris, OpenWeatherMap, and Wunderground
in their own rounds; one provider per round per ADR-007 implementation
guidance and the audit-surface-manageability lesson from 3b-2.

This is a **single-deliverable round.** Shared infrastructure (HTTP wrapper,
retry, error taxonomy, capability registry, both cache backends, rate
limiter) already lives. Forecast canonical types (`HourlyForecastPoint`,
`DailyForecastPoint`, `ForecastDiscussion`, `ForecastBundle`,
`ForecastResponse`) already live in `models/responses.py`. The `/forecast`
endpoint already lives at `endpoints/forecast.py` with one dispatch branch
(openmeteo). `ForecastSettings` already lives. This round adds:

1. **`weewx_clearskies_api/providers/forecast/nws.py`** — second concrete
   forecast provider per ADR-007 + ADR-038. Five module responsibilities;
   structural twin of `providers/alerts/nws.py` (UA wiring) and
   `providers/forecast/openmeteo.py` (forecast bundle shape).
2. **One new row in `_common/dispatch.py`** —
   `("forecast", "nws") → providers.forecast.nws`.
3. **`nws_user_agent_contact` field on `ForecastSettings`** — mirrors
   `AlertsSettings.nws_user_agent_contact`; reads from
   `[forecast] nws_user_agent_contact` in api.conf.
4. **`wire_forecast_settings` + `wire_nws_user_agent_contact` helpers in
   `endpoints/forecast.py`** — mirrors `endpoints/alerts.py`'s pattern. Called
   from `__main__.py` after settings load.
5. **`__main__.py` extension** — call
   `forecast.wire_forecast_settings(settings)` after settings load (alongside
   the existing `alerts.wire_alerts_settings` call).
6. **`elif provider_id == "nws":` dispatch branch in
   `endpoints/forecast.py`** — passes lat/lon/units_param/user_agent_contact
   to `nws.fetch()`.

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after both
submit and pytest is green on `weather-dev`.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` (clone of
github.com/inguy24/weewx-clearskies-api). **Default branch `main`** (verified
via `git symbolic-ref refs/remotes/origin/HEAD` 2026-05-07). Parallel-pull
command: `git fetch origin main && git merge --ff-only origin/main`. The
meta-repo (this `weather-belchertown/` workspace) is `master`.

---

## Scope — 1 provider module + plumbing

| # | Unit | Notes |
|---|---|---|
| 1 | `weewx_clearskies_api/providers/forecast/nws.py` | New file. Two-step API: `/points/{lat,lon}` → `/gridpoints/{office}/{x,y}/forecast` + `/forecast/hourly`. Plus `/products?type=AFD&location={cwa}` + `/products/{id}` for the discussion. Five outbound calls per cache miss; 30-min cache TTL covers them all. |
| 2 | `_common/dispatch.py` | Add `("forecast", "nws") → providers.forecast.nws` row. One import + one entry. |
| 3 | `config/settings.py` `ForecastSettings` | Add `nws_user_agent_contact: str \| None` field; same `__init__` parsing as `AlertsSettings.nws_user_agent_contact`. |
| 4 | `endpoints/forecast.py` | Add `wire_nws_user_agent_contact()` + `wire_forecast_settings()` (mirror alerts.py L67-85). Add `elif provider_id == "nws":` dispatch branch (mirror alerts.py L186-198). |
| 5 | `__main__.py` | After the existing `alerts.wire_alerts_settings(settings)` call, add `forecast.wire_forecast_settings(settings)`. |
| 6 | Recorded fixtures | `tests/fixtures/providers/nws/forecast_points.json`, `forecast_hourly.json`, `forecast.json` (12-hour daily/night periods), `products_afd_list.json`, `products_afd_body.json`. Sidecar `.md` documents capture date + lat/lon. |

**Out of scope this round (defer to later 3b rounds / Phase 3+ / Phase 4):**

- **Aeris / OpenWeatherMap / Wunderground forecast.** Three remaining 3b
  forecast rounds. The first keyed provider (Aeris or OWM) will:
    - Land secrets.env wiring per ADR-027 (already exists from 3b-1's NWS
      alerts UA pattern, but no real secret has been exercised).
    - Extend `logging/redaction_filter.py` to strip the new query-string
      credential (F13 deferred from 3b-1; `client_id` for Aeris,
      `apiKey` for Wunderground; `appid` for OWM is already stripped).
- **All other provider domains.** /aqi/* /earthquakes /radar/* are separate
  3b rounds.
- **NWS raw `/gridpoints/{office}/{x,y}` (un-suffixed) endpoint.** Carries
  unit-tagged numeric fields for `outHumidity`, `windGust`, `precipAmount`,
  `cloudCover` per canonical §4.1.2's "(not in default; grid-data raw has it)"
  notes. Adding a third outbound call to fill those canonical fields is a
  future enhancement; for v0.1, leave them `null` and document in the module's
  `operator_notes`.
- **Setup-wizard region-based provider suggestion** (ADR-007 §Implementation
  guidance, ADR-027). Wizard ships in Phase 4.
- **Operator overrides for forecast TTL or rate-limit.** This round uses
  ADR-017's default 30 min for forecast; same as Open-Meteo round.
- **Multi-location.** ADR-011 single-station.
- **Pre-flight US-coverage bounding-box check.** No client-side geo gate;
  module relies on `/points/{lat,lon}` returning 404 for non-US lat/lon →
  translate to `GeographicallyUnsupported` → 503 ProviderUnavailable. Same
  posture as 3b-1's NWS alerts module (which lets NWS handle non-US queries
  natively and returns empty alerts). The forecast posture differs from
  alerts only because /points 404s instead of returning empty — the response
  shape is canonical taxonomy, not module-internal opinion.

---

## Lead-resolved calls (no user sign-off needed — ADRs and contracts settle these)

The "Brief questions audit themselves before draft" rule
(`rules/clearskies-process.md`) requires every "open question" to be audited
against the ADRs first. The "brief-vs-canonical cross-check" rule (post-3b-2,
F2) requires every lead-resolved call to cross-check against
`canonical-data-model.md` + `openapi-v1.yaml` before drafting. Both audits
performed; every call below has been verified against both. Numbered for
reference, not for sign-off.

### Inherited from 3b round 2 (no change, no re-audit needed)

1. **HTTP client = `httpx` (sync).** `ProviderHTTPClient` from
   `_common/http.py`. Already covers TLS, timeouts, retry/backoff, error-class
   translation, and 4xx body logging at ERROR (3b-2 F1).
2. **Forecast cache TTL = 30 min.** ADR-017 §Per-provider TTL declaration.
   Module's `CAPABILITY.default_poll_interval_seconds = 1800`.
3. **Capability-registry populate path.** ADR-038 §3 + 3b-2's
   `_wire_providers_from_config()`. No change needed — adding the dispatch
   row in step 2 above is enough; the existing `__main__.py` lookup picks up
   nws automatically when `[forecast] provider = nws`.
4. **Both cache backends already live.** ADR-017 + 3b-1's `MemoryCache` +
   `RedisCache`. Forecast/nws consumes `get_cache()` like the other modules.
5. **No live-network tests in CI.** ADR-038 §Testing pattern. Recorded
   fixtures + `respx` for everything.
6. **Source field when no provider configured = literal `"none"`.**
   `endpoints/forecast.py` already does this; no change.
7. **`precipType` derivation rule (forecast-domain, all providers).** Use
   §3.3 enum values literally — `"rain"` / `"snow"` / `"sleet"` /
   `"freezing-rain"` / `"hail"` / `"none"`. **Do NOT flatten freezing variants
   to `"rain"`.** Locked in canonical-data-model §4.1.2 in commit `b669e5e`
   from 3b-2 audit (F2). Applies here even though NWS doesn't use WMO codes
   — same enum-literal discipline against NWS's icon shortNames.
8. **Slice-after-cache pattern.** `endpoints/forecast.py` already slices the
   bundle's `hourly` and `daily` arrays after cache lookup. NWS provides ~156
   hourly periods and 14 day/night periods (paired into 7 daily points); the
   slice cap is whatever NWS returned. No new behavior.
9. **F13 redaction-filter `client_id` strip — STAYS DEFERRED.** NWS is
   keyless. F13 still defers until Aeris (or another `client_id`-using
   provider) lands. **No change to `logging/redaction_filter.py` this round.**

### NWS-specific (this round)

10. **Three-host endpoint set, two-step lookup.** NWS forecast workflow per
    `docs/reference/api-docs/nws.md` §Endpoints:
    1. `GET /points/{lat},{lon}` → returns `cwa`, `gridId`, `gridX`, `gridY`,
       `forecast`/`forecastHourly` URLs, `timeZone`. Required for all
       subsequent calls.
    2. `GET /gridpoints/{office}/{gridX},{gridY}/forecast/hourly` →
       hourly periods (~156 of them, 7 days).
    3. `GET /gridpoints/{office}/{gridX},{gridY}/forecast` →
       12-hour day/night periods (~14 of them, 7 days × 2 paired into 7
       canonical daily points).
    4. `GET /products?type=AFD&location={cwa}` → list of recent AFD products
       (NWS Area Forecast Discussions; the cwa is the office code from step 1).
    5. `GET /products/{id}` → AFD body (`productText`, `issuanceTime`,
       `wmoCollectiveId`, `issuingOffice`).

    All five outbound calls happen on cache miss; the post-normalization
    `ForecastBundle` is cached for 30 min (ADR-017). Single cache key per
    `(station, target_unit)`; `/points` result is internal scaffolding, not a
    separate cache entry.

11. **NWS unit handling: `units=us|si` query param on the forecast endpoints.**
    Per ADR-019 §Decision (server passes weewx target_unit through; provider
    conversions at ingest). NWS forecast endpoints accept a single
    `units=us|si` param; the response includes a `temperatureUnit` ("F" or
    "C") tag. Mapping table:
      - `target_unit=US` → `units=us` (response in F, mph).
      - `target_unit=METRIC` → `units=si` (response in C, km/h).
      - `target_unit=METRICWX` → `units=si` then post-convert wind from km/h
        to m/s (÷ 3.6) at the canonical-translation step. NWS does not offer
        m/s directly. Document the conversion in the commit body.

    Note: NWS observation endpoints (not exercised this round) always return
    SI regardless of `units=` — relevant only if a future round wires the
    `current` slot via NWS observation. Out of scope here.

12. **NWS User-Agent contact wiring.** Module accepts `user_agent_contact:
    str | None` parameter on `fetch()` (mirrors the alerts module's signature
    line 362-367). When set, UA = `(weewx-clearskies-api/<version>, <contact>)`;
    when unset, UA = `(weewx-clearskies-api/<version>)` plus a one-time
    WARN per ADR-006 (operator-managed compliance — no project-level
    fallback). Endpoint reads `_nws_user_agent_contact` from
    `wire_nws_user_agent_contact()`, set at startup from
    `settings.forecast.nws_user_agent_contact`. **Same UA string can be
    wired into both alerts and forecast** — operators paste the same contact
    into `[alerts] nws_user_agent_contact` and `[forecast]
    nws_user_agent_contact`. Future ADR-027 amendment may consolidate to a
    shared `[nws] user_agent_contact` if the duplication grows; for v0.1, the
    section-isolation pattern wins simplicity-vs-DRY tradeoff.

13. **Non-US location handling: 404 from `/points` → `GeographicallyUnsupported`
    → 503 ProviderUnavailable.** ADR-007 §Per-module behavior says "USA-only
    check at config time; if user's configured location is outside the US,
    module reports 'geography unsupported' and disables itself." The 3b-1
    alerts module honors the spirit of this with no client-side bounding box
    (NWS alerts returns 200+empty for non-US `?point=`); the runtime
    response shape is canonical-taxonomy 503. For forecast, NWS `/points`
    returns HTTP 404 with a problem document for non-US lat/lon — the module
    catches this at the HTTP wrapper boundary, raises
    `GeographicallyUnsupported` from the canonical taxonomy, which the
    existing `errors.py` handler maps to 503 ProviderProblem with
    `errorCode="GeographicallyUnsupported"`. The dashboard hides the panel
    per ADR-006. No client-side geo gate; trust the API's authoritative
    answer.

14. **Discussion fetch is part of the same `fetch()` call; soft-failure if
    AFD endpoint hiccups.** ADR-038 §2 names "Outbound API call" as a single
    module responsibility; NWS forecast and AFD live in the same module.
    `fetch()` returns a `ForecastBundle` containing all three slots
    (hourly, daily, discussion). When `/products?type=AFD&location={cwa}`
    returns an empty list (rare — every CWA issues AFDs regularly) OR when
    `/products/{id}` body fetch raises a transient error, the module logs at
    WARN and returns the bundle with `discussion=None`. The forecast points
    are the load-bearing deliverable; the discussion is supplementary.
    Hourly/daily failures still raise from the canonical taxonomy
    (TransientNetworkError / ProviderProtocolError / etc.) — the soft-failure
    only covers AFD.

    **Cross-check against canonical:** §3.10 ForecastBundle declares
    `discussion: ForecastDiscussion | null` and `discussion` is NOT in the
    `required` list per openapi-v1.yaml line 1088. Soft-failure to `null`
    is canonical-shape-conformant.

15. **`weatherCode` extraction from icon URL.** Canonical §4.1.2 NWS column
    says "extract from `periods[].icon` URL." NWS icon URLs are
    `/icons/land/{day|night}/{shortName}?size=medium` (or with comma-prefix
    intensities like `/icons/land/day/sct,30?size=medium` for "30% chance of
    showers"). The shortName segment carries the iconic class — `sct`, `bkn`,
    `rain`, `snow`, `tsra`, `fzra`, etc. Module extracts the shortName
    pre-comma (strip query string, take basename, split on comma, take [0])
    and uses it as the canonical `weatherCode` string. NWS icon docs at
    https://api.weather.gov/icons enumerate the set; module tolerates unknown
    shortNames (passes through as-is; `weatherText` falls back to
    `shortForecast`).

16. **`weatherText`.**
    - Hourly: `periods[].shortForecast` directly (e.g., "Mostly Cloudy").
    - Daily: paired day-period's `shortForecast` (canonical §4.1.3 row says
      "day-period `shortForecast`").

17. **`narrative` (DailyForecastPoint).** `periods[].detailedForecast` from
    the day period of each day/night pair. Canonical §4.1.3 NWS column row.

18. **Day/night period pairing for daily.** NWS `/forecast` returns periods
    that alternate `isDaytime: true` and `isDaytime: false`. The module pairs
    each day-period with the immediately-following night-period to form one
    canonical `DailyForecastPoint`:
    - `validDate` = day-period's `startTime` date part (station-local
      YYYY-MM-DD per canonical §3.4).
    - `tempMax` = day-period's `temperature`.
    - `tempMin` = night-period's `temperature`.
    - `precipProbabilityMax` = max of day-period and night-period's
      `probabilityOfPrecipitation.value` (treat `null` as 0).
    - `windSpeedMax` = upper bound of `windSpeed` parsed from the string
      range (see call 19); take max across the day/night pair.
    - `weatherCode` / `weatherText` / `narrative` = day-period's values.

    Edge case: the first response period may be a night period (e.g., if the
    forecast was generated late evening). In that case, the first canonical
    daily point is incomplete — the module skips it and starts pairing from
    the first day-period. Document this in the impl docstring.

19. **`windSpeed` string range parsing.** Canonical §4.1.2 NWS column note:
    "parse range string." NWS `/forecast/hourly` returns single values like
    `"7 mph"`; `/forecast` (12-hour periods) returns ranges like
    `"5 to 10 mph"`. Helper `_parse_wind_speed(s) -> float | None`:
    - Strip the unit suffix (`" mph"` or `" km/h"`).
    - Split on `" to "`; take the upper bound (last element); parse to float.
    - Single-value form (`"7 mph"`) returns 7.0.
    - Empty / unparseable → `None` (log at DEBUG with the input).

20. **`windDirection` compass abbreviation → degrees.** Canonical §4.1.2 NWS
    column note. Standard 16-point compass table:
    `N=0, NNE=22.5, NE=45, ENE=67.5, E=90, ESE=112.5, SE=135, SSE=157.5,
    S=180, SSW=202.5, SW=225, WSW=247.5, W=270, WNW=292.5, NW=315,
    NNW=337.5`. Helper `_compass_to_degrees(s) -> float | None`. Unknown /
    empty → `None` (log at DEBUG with the input). NWS sometimes emits
    `null` directly (typically very low wind speed); module passes that
    through as `None` without parsing.

21. **`precipType` derivation from icon shortName.** Per the forecast-domain
    rule (call 7), use canonical §3.3 enum literally. Lookup table from the
    NWS icon shortName set documented at https://api.weather.gov/icons:
      - `rain` / `rain_showers` / `rain_showers_hi` → `"rain"`
      - `snow` / `snow_showers` / `blizzard` / `cold` (cold-with-precip
        contexts only) → `"snow"`
      - `fzra` / `rain_fzra` / `snow_fzra` → `"freezing-rain"`
      - `sleet` / `rain_sleet` / `snow_sleet` → `"sleet"`
      - `tsra` / `tsra_sct` / `tsra_hi` → `"rain"` (thunderstorms accompany
        rain in NWS's classification; canonical has no `"thunderstorm"`)
      - `mix` / `rain_snow` / `rain_showers_snow` → `"rain"` (mixed precip;
        canonical has no mixed-precip enum value, log a DEBUG so a future
        canonical-model amendment is informed by real-data prevalence)
      - All other shortNames (`few`, `bkn`, `sct`, `ovc`, `skc`, `wind`,
        `fog`, `hot`, `dust`, `smoke`, `tornado`, `hurricane`, `tropical_storm`)
        → `None`
    
    The exact NWS icon shortName set ships with the icon endpoint and changes
    rarely; module tolerates unknown shortNames (returns `None`, logs at
    DEBUG once).

22. **Hours/days slice caps.** OpenAPI just says `minimum: 0` with defaults
    48/7 — no max. NWS hourly returns ~156 periods (7 days × 24 hours - some
    edge); daily pairing yields 7 days. Module returns whatever NWS provided;
    `ForecastQueryParams` validation (already in `models/params.py`) caps
    `hours` at 384 and `days` at 16 from the Open-Meteo round. Those caps
    don't need adjustment for NWS — they're ceilings, not floors. NWS
    requests max out at 156 / 7 naturally and the endpoint slice handles
    "requested more than available" by returning all available (per existing
    `endpoints/forecast.py` slice logic, line 172-173).

23. **Datetime conversion.** NWS forecast emits ISO-8601 with offset
    (`"2026-04-30T13:00:00-07:00"`). Module reuses the existing
    `_to_utc_iso8601()` helper from `providers/alerts/nws.py` line 275-299
    by lifting it to a shared helper OR duplicating in
    `providers/forecast/nws.py`. **Lead-call: lift to a shared helper at
    `providers/_common/datetime_utils.py`** (new file, one function). The
    function exists already in alerts/nws.py — moving it eliminates the
    duplicate before it lands. Update alerts/nws.py to import from the new
    shared location; keep the alerts module's tests intact (tests import via
    the module's namespace, not the function directly, per the existing test
    fixture pattern).

    **Cross-check against rules:** `rules/coding.md` §3 DRY ("search before
    writing a new helper") explicitly calls for fixing the existing version
    over forking a near-duplicate. This call honors the rule.

24. **Cache key shape.** `SHA-256(json({"provider_id": "nws", "endpoint":
    "forecast_bundle", "params": {"lat4": "...", "lon4": "...", "target_unit":
    "..."}}, sort_keys=True))`. The "endpoint" string is `"forecast_bundle"`
    (a logical name covering all five upstream calls), not a literal path —
    the cache stores the post-normalization bundle, so the key reflects the
    bundle's identity, not any single underlying URL. Mirrors openmeteo's
    pattern (which uses `OPENMETEO_FORECAST_PATH` for its single endpoint).
    Note in the impl docstring + commit body that `"forecast_bundle"` is a
    deliberate logical key, not a URL path.

25. **Rate limiter for NWS.** ADR-038 §3 names the primitive. NWS docs say
    "rate limit is not public information." Both 3b-1 alerts and 3b-2
    openmeteo use `max_calls=5, window_seconds=1` — NWS forecast follows the
    same shape. **The same `_rate_limiter` instance MAY be shared with
    alerts/nws.py via a module-level lift to `providers/_common/`**, but the
    duplication cost is one line per provider and the shared limiter would
    couple alerts and forecast quotas into one bucket — undesirable. Lead-call:
    keep separate `_rate_limiter` per provider module. The alerts/forecast
    modules both call the same NWS host but at different cadences (alerts =
    5 min TTL, forecast = 30 min TTL); shared limiter would penalize alerts
    when forecast bursts. Match the openmeteo pattern: per-module limiter at
    `max_calls=5, window_seconds=1`.

26. **Module emits no observation slot.** Canonical §4.1.1 includes a
    NWS column for `/stations/{id}/observations/latest`, but `/forecast`
    endpoint per OpenAPI line 186-213 returns a `ForecastBundle` with
    hourly/daily/discussion only — no current-observation slot. Out of
    scope this round; a future enhancement might wire NWS observations into
    the bundle (or, more likely, weewx archive serves the current
    observation via `/observations`). Do NOT attempt to fill a "current"
    slot from `/observations/latest` in this round.

---

## Hard reading list (once per session)

**Both api-dev and test-author:**

- `CLAUDE.md` — domain routing + always-applicable rules (lessons-capture,
  memory-disabled, `.claude/` private, plain-English, scope discipline).
- `rules/clearskies-process.md` — full file. Carry-forward from 3b-2:
  poll-don't-wait (lead side, user-prompt-boundary cadence verified
  2026-05-07); verify default branch name (`main` for api, `master` for
  meta); brief questions audit themselves at draft (3b-1 lesson); brief-vs-
  canonical cross-check at draft (3b-2 F2 lesson); tests verify the brief,
  brief is the authority; STOP-and-ping when impl matches canonical but
  diverges from brief literal; real schemas in unit tests; audit modes are
  complementary; lead synthesizes auditor findings; ADR conflicts → STOP;
  round briefs land in the project, not in tmp.
- `rules/coding.md` — full file. §1 carry-forward: Pydantic + Depends pattern
  for query-param routes; IPv4/IPv6-agnostic (`httpx` resolves natively); no
  dangerous functions; no hardcoded secrets (NWS keyless — secrets path not
  exercised). §3: catch specific exceptions, never bare `except Exception:`;
  search before writing a new helper (call 23 honors this).
  §5 a11y: non-applicable — backend round.
- `docs/contracts/openapi-v1.yaml`:
  - `/forecast` at line 186 (no change; NWS reuses the existing endpoint).
  - `HourlyForecastPoint` at line 1016 (no change).
  - `DailyForecastPoint` at line 1035 (no change).
  - `ForecastDiscussion` at line 1058 (this round's first end-to-end
    consumer).
  - `ForecastBundle` at line 1073 (`discussion` is `oneOf` `null` or
    `ForecastDiscussion`; not in `required`).
  - `ForecastResponse` at line 1562.
  - `ProviderProblem` at line 863, `ProviderError` 502 response at line 799,
    `ProviderUnavailable` 503 response at line 807,
    `CapabilityDeclaration` at line 1432.
- `docs/contracts/canonical-data-model.md`:
  - §3.3 (HourlyForecastPoint).
  - §3.4 (DailyForecastPoint).
  - §3.5 (ForecastDiscussion — this round's first end-to-end
    consumer).
  - §3.10 (ForecastBundle).
  - §4.1.2 (Hourly forecast — NWS column for the per-field mapping).
  - §4.1.3 (Daily forecast — NWS column).
  - §4.1.4 (Forecast discussion — NWS column).
- `docs/contracts/security-baseline.md`:
  - §3.4 (secrets — N/A this round; NWS keyless).
  - §3.5 (input validation — Pydantic models for the wire shape inside the
    normalizer per ADR-038).
  - §3.6 (logging — provider URL logged at INFO; UA string is operator-set
    contact; redaction filter strips its existing set).
- `docs/reference/api-docs/nws.md` — full file. The endpoints table and
  example responses at lines 47-265 are the source of truth for the wire-
  shape Pydantic models. Specifically:
  - `/points/{lat,lon}` example at lines 56-90 (cwa, gridId, gridX, gridY,
    timeZone).
  - `/forecast` (12-hour periods) at lines 139-183 (windSpeed string range,
    isDaytime alternation).
  - `/forecast/hourly` at lines 185-191 (single-value windSpeed string).
  - `/products` and `/products/{id}` for AFD body — the file mentions
    `/products` at line 262 but doesn't show example response shapes for AFD
    list/body. Wire-shape models for AFD must reference the canonical-data-
    model §4.1.4 NWS column entries (`productText`, `issuanceTime`,
    `wmoCollectiveId`, `issuingOffice`); manually exercise the live API once
    on weather-dev to capture the recorded fixtures.
  - "Known issues / gotchas" at lines 285-294 — `User-Agent` mandatory,
    `windSpeed` is a string range, grid coordinates can change (we
    re-resolve every 30 min via cache TTL), observation lag (irrelevant
    here), USA-only coverage.
- `docs/planning/briefs/phase-2-task-3b-2-forecast-brief.md` — round 2's
  brief is the closest pattern reference. Reuse the per-module-spec
  structure (constants → wire-shape Pydantic → fetch() → _to_canonical() →
  helpers); reuse the test-author parallel-scope structure. Don't re-derive
  what already works.
- `docs/planning/briefs/phase-2-task-3b-1-alerts-brief.md` — pattern
  reference for the NWS UA contact wiring and the `_to_utc_iso8601` helper.
- `.claude/agents/clearskies-api-dev.md` — agent definition. Three
  constraints active for this round:
    (a) tests verify the brief; STOP and ping the lead at signature
        divergence; do NOT flip impl to match tests (3b-1 F12 lesson);
    (b) when impl matches canonical contracts but diverges from the literal
        text of the brief, STOP and ping the lead (3b-2 F2 lesson);
    (c) Mid-flight status reporting via SendMessage at every milestone;
        4-min cadence floor; STOP and ping on blocker.
- `.claude/agents/clearskies-test-author.md` — same Mid-flight block plus
  brief-gate honesty (no silent skips on cache-tier or DB-tier coverage).

**ADRs to load before implementing:**

- ADR-006 (compliance — operator-managed UA contact; NO project-level
  fallback).
- ADR-007 (forecast providers — day-1 set is 5; this round adds the
  second; remaining three Aeris/OWM/Wunderground are future 3b rounds).
  §Per-module behavior NWS row text says "USA-only check at config time" —
  this round honors the spirit via runtime 503 GeographicallyUnsupported,
  not a client-side bounding box. Same posture as 3b-1 alerts.
- ADR-010 (canonical data model — HourlyForecastPoint, DailyForecastPoint,
  ForecastDiscussion, ForecastBundle).
- ADR-011 (single-station — operator lat/lon from station metadata).
- ADR-017 (provider response caching — pluggable backend; forecast TTL 30
  min; cache key shape).
- ADR-018 (URL-path versioning, RFC 9457 errors, ProviderProblem extension
  carrying providerId/domain/errorCode).
- ADR-019 (units handling — server passes weewx target_unit through;
  conversions at provider ingest).
- ADR-020 (time zone — UTC ISO-8601 Z on the wire; station-local
  YYYY-MM-DD for daily.validDate).
- ADR-027 (config — `[forecast] provider = nws` and `[forecast]
  nws_user_agent_contact = ...` in api.conf).
- ADR-029 (logging — INFO per-request access log; provider URL logged;
  redaction filter runs).
- ADR-038 (provider module organization — five module responsibilities,
  shared infra split, capability declaration fields, canonical error
  taxonomy, testing pattern).

ADRs explicitly NOT in scope this round:

- ADR-013 (AQI), ADR-015 (radar), ADR-016 (alerts — done), ADR-040
  (earthquakes) — separate 3b rounds.
- ADR-022 / ADR-023 / ADR-026 (theming, dark mode, a11y — Phase 3).

---

## Existing code (read, do not rewrite)

3b-1 + 3b-2 + earlier rounds landed:

- `weewx_clearskies_api/providers/_common/` — six files. Reusable as-is.
  `errors.py`, `http.py`, `cache.py`, `rate_limiter.py`, `capability.py`,
  `dispatch.py`. **One new helper file lifted from alerts/nws.py per call 23:**
  `providers/_common/datetime_utils.py` containing
  `to_utc_iso8601_from_offset(s: str, *, provider_id: str, domain: str) ->
  str` (the function currently at alerts/nws.py L275-299). Update
  alerts/nws.py to import from the new shared module. This is a small
  refactor inside the round; keep its diff isolated to one commit.

- `weewx_clearskies_api/providers/alerts/nws.py` — pattern reference for the
  NWS UA wiring + datetime conversion helper. **Read it first.** The
  forecast/nws module mirrors the UA pattern but does NOT mirror the cache
  shape (alerts caches the canonical list; forecast caches the canonical
  bundle).

- `weewx_clearskies_api/providers/forecast/openmeteo.py` — pattern reference
  for the forecast-bundle shape (`fetch() -> ForecastBundle`,
  `_to_canonical()`, slice-after-cache). **Read it first.** The forecast/nws
  module mirrors the bundle shape but the wire-shape models are very
  different (NWS GeoJSON envelope vs Open-Meteo column-oriented arrays).

- `weewx_clearskies_api/providers/forecast/__init__.py` — empty package
  marker. No change.

- `weewx_clearskies_api/services/station.py` — `get_station_info()` exposes
  lat/lon/timezone. Same wiring openmeteo and alerts use.

- `weewx_clearskies_api/services/units.py` — `get_units_block()` and
  `get_target_unit()`. Forecast endpoint already consumes both; no change.

- `weewx_clearskies_api/config/settings.py:347 ForecastSettings` — exists
  with `provider: str | None`. **Add `nws_user_agent_contact: str | None`**
  field this round (mirror AlertsSettings 314-344). No change to
  `validate()` — the day-1 set already lists `"nws"`.

- `weewx_clearskies_api/__main__.py` — already calls
  `_wire_providers_from_config(settings)` and (per 3b-1) calls
  `alerts.wire_alerts_settings(settings)`. **Add
  `forecast.wire_forecast_settings(settings)`** alongside, and add a
  matching `wire_forecast_settings()` helper to `endpoints/forecast.py`
  (mirror alerts.py L77-85).

- `weewx_clearskies_api/errors.py` — RFC 9457 + ProviderError handler is
  wired. NWS forecast errors flow through unchanged — same canonical
  taxonomy → same 502/503 + ProviderProblem mapping.

- `weewx_clearskies_api/models/responses.py` — Pydantic response models
  (`HourlyForecastPoint`, `DailyForecastPoint`, `ForecastDiscussion`,
  `ForecastBundle`, `ForecastResponse`, `utc_isoformat`). **No new models.**

- `weewx_clearskies_api/models/params.py` — `ForecastQueryParams` with
  `hours` and `days`. **No new params.**

- `weewx_clearskies_api/endpoints/forecast.py` — already exists with the
  no-provider branch and the openmeteo dispatch. **Add the nws dispatch
  branch (mirror alerts.py L186-198)** plus the UA wiring helpers
  (mirror alerts.py L60-85). The existing slice logic at L172-173 covers
  NWS naturally.

- `weewx_clearskies_api/endpoints/alerts.py` — pattern reference for the
  UA contact wiring (`wire_nws_user_agent_contact`, `wire_alerts_settings`,
  module-level `_nws_user_agent_contact`). **Same shape mirrored into
  forecast.py this round.** Two parallel UA contacts may be set
  (alerts + forecast); same operator-paste-twice papercut documented above.

- `weewx_clearskies_api/app.py` — forecast router already registered. No
  change.

- `weewx_clearskies_api/logging/redaction_filter.py` — strips Authorization,
  X-Clearskies-Proxy-Auth, appid, client_secret, SQL params.
  **No change this round** (NWS keyless, F13 stays deferred).

- `weewx_clearskies_api/providers/_common/dispatch.py` — already maps
  `("alerts", "nws")` and `("forecast", "openmeteo")`. **Add
  `("forecast", "nws")` row + matching import.**

`pyproject.toml` runtime deps already cover this round: `httpx` (3b-1),
`redis` (3b-1), `pydantic`, `cachetools`, `configobj`, `fastapi`,
`sqlalchemy`. **No new runtime or dev-extras deps this round.** Specifically:
NO `requests`, NO `aiohttp`, NO `tenacity`, NO `pyyaml`, NO XML parsers
(NWS AFD body is plain ASCII; no DWML/CAP parsing). STOP and ping the lead
if you think you need anything else.

---

## Per-module spec — `providers/forecast/nws.py`

Five responsibilities per ADR-038 §2. Module structure mirrors
`providers/forecast/openmeteo.py` from 3b-2 — five sections in the same
order, with the addition of an "intermediate state" section for the points
lookup result.

### Module-level constants

```python
PROVIDER_ID = "nws"
DOMAIN = "forecast"
NWS_BASE_URL = "https://api.weather.gov"
NWS_POINTS_PATH = "/points"
NWS_PRODUCTS_PATH = "/products"
DEFAULT_FORECAST_TTL_SECONDS = 1800   # 30 min per ADR-017

_API_VERSION = "0.1.0"

CAPABILITY = ProviderCapability(
    provider_id=PROVIDER_ID,
    domain=DOMAIN,
    supplied_canonical_fields=(
        # HourlyForecastPoint — what NWS /forecast/hourly actually supplies
        "validTime", "outTemp",
        "windSpeed", "windDir",
        "precipProbability",
        "precipType",
        "weatherCode", "weatherText",
        # DailyForecastPoint — paired day/night periods
        "validDate", "tempMax", "tempMin",
        "precipProbabilityMax", "windSpeedMax",
        "weatherCode", "weatherText",
        "narrative",
        # ForecastDiscussion — first end-to-end consumer
        "headline", "body", "issuedAt", "senderName",
        # NB: outHumidity, windGust, precipAmount, cloudCover (hourly),
        # precipAmount/windGustMax/sunrise/sunset/uvIndexMax (daily) require
        # the raw /gridpoints endpoint — out of scope this round.
    ),
    geographic_coverage="us",  # USA + territories
    auth_required=(),  # no key; UA contact recommended via [forecast] section
    default_poll_interval_seconds=DEFAULT_FORECAST_TTL_SECONDS,
    operator_notes=(
        "NWS forecast: USA-only coverage. Set [forecast] "
        "nws_user_agent_contact in api.conf for best results "
        "(reduces block risk during NWS security events). "
        "Hourly outHumidity / windGust / precipAmount / cloudCover and "
        "daily windGustMax / sunrise / sunset / uvIndexMax are not "
        "supplied via the standard forecast endpoints; see "
        "https://weather.gov for raw gridpoint data."
    ),
)

# units= query-param mapping per call 11
_TARGET_UNIT_TO_NWS_UNITS: dict[str, str] = {
    "US": "us",
    "METRIC": "si",
    "METRICWX": "si",  # post-convert km/h → m/s in _zip_*()
}

# Compass abbreviation → degrees per call 20
_COMPASS_TO_DEGREES: dict[str, float] = {
    "N": 0.0, "NNE": 22.5, "NE": 45.0, "ENE": 67.5,
    "E": 90.0, "ESE": 112.5, "SE": 135.0, "SSE": 157.5,
    "S": 180.0, "SSW": 202.5, "SW": 225.0, "WSW": 247.5,
    "W": 270.0, "WNW": 292.5, "NW": 315.0, "NNW": 337.5,
}

# Icon shortName → precipType per call 21
_ICON_TO_PRECIP_TYPE: dict[str, str] = {
    "rain": "rain", "rain_showers": "rain", "rain_showers_hi": "rain",
    "snow": "snow", "snow_showers": "snow", "blizzard": "snow",
    "fzra": "freezing-rain", "rain_fzra": "freezing-rain",
    "snow_fzra": "freezing-rain",
    "sleet": "sleet", "rain_sleet": "sleet", "snow_sleet": "sleet",
    "tsra": "rain", "tsra_sct": "rain", "tsra_hi": "rain",
    "mix": "rain", "rain_snow": "rain", "rain_showers_snow": "rain",
}
```

### Wire-shape Pydantic models

Per security-baseline §3.5 + ADR-038 §Testing pattern. `extra="ignore"` so
future NWS schema additions don't break us; missing required fields raise
`ValidationError` → `ProviderProtocolError`.

NWS responses are GeoJSON Features with provider-specific properties.
Five wire-shape models needed (one per call):

```python
class _NwsPointProperties(BaseModel):
    """NWS /points/{lat,lon} feature properties — wire shape."""
    model_config = ConfigDict(extra="ignore")
    cwa: str
    gridId: str
    gridX: int
    gridY: int
    forecast: str           # URL
    forecastHourly: str     # URL
    timeZone: str           # IANA TZ
    radarStation: str | None = None  # not load-bearing


class _NwsPointResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    type: Literal["Feature"]
    properties: _NwsPointProperties


class _NwsForecastPeriod(BaseModel):
    """One period from /forecast or /forecast/hourly.

    /forecast (12-hour): startTime, endTime, isDaytime, temperature (number),
        windSpeed (string range "5 to 10 mph"), shortForecast, detailedForecast.
    /forecast/hourly: same shape but isDaytime not used for pairing,
        windSpeed is "7 mph" single-value, no detailedForecast.
    """
    model_config = ConfigDict(extra="ignore")
    number: int
    name: str | None = None
    startTime: str
    endTime: str
    isDaytime: bool
    temperature: float | None = None
    temperatureUnit: str  # "F" or "C"
    temperatureTrend: str | None = None
    probabilityOfPrecipitation: dict[str, Any] | None = None  # {unitCode, value}
    windSpeed: str | None = None  # range string for /forecast, single for /hourly
    windDirection: str | None = None  # compass abbrev
    icon: str | None = None  # URL — extract shortName segment
    shortForecast: str | None = None
    detailedForecast: str | None = None


class _NwsForecastProperties(BaseModel):
    model_config = ConfigDict(extra="ignore")
    updated: str | None = None
    units: str | None = None  # "us" or "si"
    forecastGenerator: str | None = None
    generatedAt: str | None = None
    updateTime: str | None = None
    validTimes: str | None = None
    periods: list[_NwsForecastPeriod] = Field(default_factory=list)


class _NwsForecastResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    type: Literal["Feature"]
    properties: _NwsForecastProperties


class _NwsAfdProductSummary(BaseModel):
    """One entry from /products?type=AFD&location={cwa} list."""
    model_config = ConfigDict(extra="ignore")
    id: str
    wmoCollectiveId: str | None = None
    issuingOffice: str | None = None
    issuanceTime: str | None = None
    productCode: str | None = None
    productName: str | None = None


class _NwsAfdListResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    # NWS returns @graph for product list endpoints
    graph: list[_NwsAfdProductSummary] = Field(
        default_factory=list, alias="@graph"
    )


class _NwsAfdProductBody(BaseModel):
    """Body of /products/{id} — full AFD content."""
    model_config = ConfigDict(extra="ignore")
    id: str
    wmoCollectiveId: str | None = None
    issuingOffice: str | None = None
    issuanceTime: str
    productCode: str | None = None
    productName: str | None = None
    productText: str
```

**Wire-shape sources of truth:** `docs/reference/api-docs/nws.md` example
responses at lines 56-90 (points), 148-181 (forecast), 188-191 (hourly),
219-249 (alerts — for cross-check only). For AFD, the field set comes from
the canonical-data-model §4.1.4 NWS column entries; the recorded fixture
captured by the test-author validates the wire-shape model on commit.

### `fetch(*, lat, lon, target_unit, user_agent_contact) -> ForecastBundle` — public entrypoint

Single callable. Returns canonical `ForecastBundle` (Pydantic model — NOT a
dict; per F12 lesson from 3b-1).

```python
def fetch(
    *,
    lat: float,
    lon: float,
    target_unit: str,
    user_agent_contact: str | None,
) -> ForecastBundle:
    """Call NWS forecast endpoints and return a canonical ForecastBundle.

    Five outbound calls per cache miss:
      1. /points/{lat,lon} → cwa, gridId, gridX, gridY
      2. /gridpoints/{office}/{x,y}/forecast/hourly → hourly periods
      3. /gridpoints/{office}/{x,y}/forecast → 12-hour day/night periods
      4. /products?type=AFD&location={cwa} → list of recent AFDs
      5. /products/{id} → AFD body (latest from step 4)

    Cache stores the post-normalization ForecastBundle for 30 min (ADR-017).

    Soft-failure on AFD: if calls 4-5 fail (transient, 404, parse error),
    log at WARN and return bundle with discussion=None. Hourly/daily failures
    raise from canonical taxonomy.

    Returns:
        ForecastBundle — single canonical Pydantic model.

    Raises:
        GeographicallyUnsupported: /points returned 404 (non-US lat/lon).
        QuotaExhausted: NWS returned 429.
        TransientNetworkError: Network/DNS failure or 5xx after retries.
        ProviderProtocolError: Wire-shape validation failed; or required
            forecast call (hourly/daily) returned malformed response.
    """
```

Algorithm sketch:

1. Build cache key from `(lat, lon, target_unit)`. Cache lookup; on hit,
   reconstruct via `ForecastBundle.model_validate(cached)` and return.
2. Build UA string from `user_agent_contact` (helper lifted from alerts/nws.py
   pattern, or duplicated; lead-call: lift to a `_build_user_agent()` helper
   inside `providers/forecast/nws.py` for now — share with alerts in a
   later round if it grows again).
3. Acquire rate limiter.
4. Call `/points/{lat,lon}` with header `User-Agent: <ua>`,
   `Accept: application/geo+json`. On HTTP 404, raise
   `GeographicallyUnsupported`. On Pydantic validation failure of the response,
   raise `ProviderProtocolError`.
5. Call `/gridpoints/{cwa}/{gridX},{gridY}/forecast/hourly?units=us|si`.
   Same headers. Failures translate to canonical taxonomy via the HTTP
   wrapper.
6. Call `/gridpoints/{cwa}/{gridX},{gridY}/forecast?units=us|si`. Same.
7. Try-block for the AFD pair (calls 8-9):
   a. Call `/products?type=AFD&location={cwa}`. On any failure (transient,
      validation, empty list), log at WARN, set `discussion=None`, skip
      step 9.
   b. Take the first product from the `@graph` list (most recent).
   c. Call `/products/{id}`. On any failure (transient, validation), log
      at WARN, set `discussion=None`.
   d. On success, build canonical `ForecastDiscussion` from the body's
      `productText`, `issuanceTime`, `wmoCollectiveId`, `issuingOffice`.
8. `_to_canonical()`: zip hourly periods into `HourlyForecastPoint` list;
   pair day/night periods into `DailyForecastPoint` list; assemble the
   bundle.
9. Cache `bundle.model_dump(mode="json")` for 30 min.
10. Return `bundle`.

### `_to_canonical(...)` and helpers

Per canonical-data-model §4.1.2-§4.1.4. Helper functions:

- `_extract_icon_shortname(icon_url: str | None) -> str | None` — parse
  `/icons/land/day/sct,30?size=medium` → `"sct"`. Strips query string,
  takes basename, splits on comma, returns [0]. Returns `None` for `None`
  / unparseable. Pure function; tested in isolation.
- `_compass_to_degrees(s: str | None) -> float | None` — lookup table at
  module level (`_COMPASS_TO_DEGREES`). Pure function.
- `_parse_wind_speed(s: str | None) -> float | None` — strip unit, split
  on `" to "`, take upper bound, parse to float. Returns `None` for
  unparseable. Pure function.
- `_zip_hourly(periods, units)` — column-equivalent for NWS's row-per-period
  shape; just iterates `periods[]` and constructs `HourlyForecastPoint` for
  each. `validTime` via `to_utc_iso8601_from_offset()` (the lifted shared
  helper). `weatherCode` via icon-shortname extract. `weatherText` =
  `shortForecast` directly. `precipType` via `_ICON_TO_PRECIP_TYPE` lookup
  on the shortName. `windSpeed` via `_parse_wind_speed`. `windDir` via
  `_compass_to_degrees`. METRICWX wind post-convert km/h → m/s (÷ 3.6).
- `_pair_day_night(periods) -> list[tuple[period, period | None]]` —
  walk `periods[]` looking for day-period (`isDaytime=True`); pair with the
  immediately-following night-period; emit. If `periods[0]` is night, skip
  to first day-period. Trailing day-period without a night gets paired with
  `None` (no night data; canonical `tempMin` becomes `None`).
- `_zip_daily(pairs, units)` — for each `(day, night)` pair, build one
  `DailyForecastPoint`. Per call 18 mapping. METRICWX wind post-convert.
- `_now_utc_iso8601()` — reuse `utc_isoformat(datetime.now(tz=UTC))` from
  `models/responses.py` (per the helper-reuse rule + 3b-2 F4 fix).
- `_build_cache_key(lat, lon, target_unit)` — mirrors openmeteo's pattern
  from openmeteo.py L377-396.

### Helper functions

In addition to the listed `_to_canonical` helpers:

- `_get_http_client(user_agent: str) -> ProviderHTTPClient` — module-level
  singleton, UA-keyed (mirrors alerts/nws.py L196-210). On UA change
  between calls (rare — only at process restart with different config),
  reconstructs.
- `_build_user_agent(contact: str | None) -> str` — same shape as
  alerts/nws.py L220-233. NO project-level fallback per ADR-006.
- `_warn_once_missing_contact()` — fire one WARN per process start when
  contact is unset.
- `_reset_http_client_for_tests()` — test hook (mirrors openmeteo.py L712-715
  and alerts/nws.py L435-440).

---

## Cross-cutting requirements

### Pydantic + `Depends(_get_forecast_params)` pattern

`/forecast` query params already validated via the existing
`_get_forecast_params` Depends wrapper at endpoints/forecast.py L64-75.
**No change.**

### RFC 9457 errors

The existing `errors.py` ProviderError handler covers NWS forecast errors
unchanged. ProviderProblem extension (`providerId="nws"`, `domain="forecast"`,
`errorCode`, optional `retryAfterSeconds`) comes for free.

### Logging

Per ADR-029. Provider HTTP outbound calls log at INFO with: `provider_id`,
`domain`, URL (with sensitive query params stripped — NWS keyless so the
URL is safe to log), `elapsed_ms`, `status_code`. On error: WARNING
(transient) or ERROR (protocol). Cache hit/miss at DEBUG. AFD soft-failure
at WARN with the failure reason.

### Catch specific exceptions

`rules/coding.md` §3 — no `except Exception:`. The HTTP wrapper catches
specific httpx classes already. The forecast/nws module catches
`ValidationError` from Pydantic at the wire-model boundary; `ValueError`
from datetime parsing in helpers; everything else flows through the
canonical taxonomy.

### No live-network tests in CI (ADR-038 §Testing pattern)

Recorded fixtures: `tests/fixtures/providers/nws/` — see test-author scope
below. All mock-network tests use `respx` to patch URL → fixture mapping.

### Capability registry

`forecast/nws.py` exports `CAPABILITY`; `_wire_providers_from_config` in
`__main__.py` already calls `get_provider_module(domain="forecast",
provider_id=settings.forecast.provider)` and appends `module.CAPABILITY`.
With the dispatch-table row added in step 2, NWS auto-registers when
`[forecast] provider = nws` is set in api.conf.

**Failure modes:**

- `[forecast] provider = nws` and `[forecast] nws_user_agent_contact` unset
  → forecast/nws emits a one-time WARN; module otherwise functions (NWS may
  be more aggressive with rate limits without a contact-named UA). Per
  ADR-006.
- `[forecast] provider = nws` and operator's lat/lon outside US → first
  request raises `GeographicallyUnsupported` → 503 with
  `errorCode="GeographicallyUnsupported"`. Operator's logs surface the
  reason; dashboard hides the panel. No client-side bounding box check.
- `[forecast] provider = <unwired>` (e.g., `aeris`/`openweathermap`/
  `wunderground`) — ForecastSettings.validate accepts the day-1 set;
  dispatch lookup `KeyError` at startup → CRITICAL log + exit. Same fail-
  closed pattern as 3b-2's openmeteo round.

### No new ADRs

ADR-007 covers the forecast day-1 set. ADR-017 covers caching. ADR-038
covers module organization. ADR-019 covers units. ADR-020 covers timestamps.
**STOP and ping the lead** if implementation surfaces a need for a new ADR.

### No new dependencies

All deps required by this round are already in `pyproject.toml`. STOP and
ping the lead if you think you need anything else.

### Tests verify the brief; brief is the authority

Per `rules/clearskies-process.md` (added 2026-05-07) +
`.claude/agents/clearskies-api-dev.md`. If api-dev's `fetch()` signature
disagrees with what test-author wrote, **api-dev STOPs and pings the lead**.
The brief explicitly types `fetch(*, lat, lon, target_unit,
user_agent_contact) → ForecastBundle` (single canonical entity, not a list).
Don't flip the impl to a list, dict, or different signature without a lead
sign-off.

When impl matches canonical contracts but **diverges from the literal text
of the brief**, also STOP and ping the lead (3b-2 F2 lesson). Brief may be
wrong against the contract.

### Diff size budget

Target ~1200-2000 line impl diff (not counting tests). Smaller than 3b round
2 because no new Pydantic response models, no new query param model, no new
endpoint, and the dispatch+settings+__main__ delta is minimal. New code is
the nws module + the lifted `datetime_utils.py` helper + dispatch row +
ForecastSettings field + endpoint dispatch branch + UA wiring helpers.
If it crosses 2500 lines, ping the lead.

---

## Test-author parallel scope

Run `pytest` on `weather-dev` (192.168.2.113); never on DILBERT.

### Recorded fixture capture

`tests/fixtures/providers/nws/` — five fixtures, captured manually from real
NWS responses on weather-dev. Recommended capture sequence:

```bash
UA='(weewx-clearskies-api-test, capture@example.com)'

# 1. Points lookup (Seattle, WA, 47.6062,-122.3321 — well-supported US point)
curl -H "User-Agent: $UA" -H "Accept: application/geo+json" \
  "https://api.weather.gov/points/47.6062,-122.3321" \
  | python -m json.tool > tests/fixtures/providers/nws/forecast_points.json

# 2. Hourly forecast (use forecastHourly URL from step 1's response)
curl -H "User-Agent: $UA" -H "Accept: application/geo+json" \
  "https://api.weather.gov/gridpoints/SEW/124,67/forecast/hourly" \
  | python -m json.tool > tests/fixtures/providers/nws/forecast_hourly.json

# 3. 12-hour periods forecast (use forecast URL from step 1)
curl -H "User-Agent: $UA" -H "Accept: application/geo+json" \
  "https://api.weather.gov/gridpoints/SEW/124,67/forecast" \
  | python -m json.tool > tests/fixtures/providers/nws/forecast.json

# 4. AFD list (use cwa from step 1)
curl -H "User-Agent: $UA" -H "Accept: application/ld+json" \
  "https://api.weather.gov/products?type=AFD&location=SEW" \
  | python -m json.tool > tests/fixtures/providers/nws/products_afd_list.json

# 5. AFD body (use first id from step 4 list)
curl -H "User-Agent: $UA" -H "Accept: application/ld+json" \
  "https://api.weather.gov/products/<id-from-step-4>" \
  | python -m json.tool > tests/fixtures/providers/nws/products_afd_body.json
```

The hourly fixture should include AT LEAST 24 hours of forecast points so
slice tests can verify truncation. Document the capture date + cwa + lat/lon
in a sidecar `.md` next to the fixtures for future replay.

Hand-crafted variants for negative-path testing:

- `forecast_points_404.json` — NWS problem-document response shape for
  non-US lat/lon (manually crafted; structure is in the NWS OpenAPI spec).
  Test that fetch() raises `GeographicallyUnsupported`.
- `forecast_hourly_malformed.json` — hourly response missing `properties`
  or `periods`; verify `ProviderProtocolError`.
- `forecast_periods_starts_night.json` — variant of `forecast.json` where
  `periods[0].isDaytime=False`; verify `_pair_day_night` skips the leading
  night.
- `products_afd_list_empty.json` — AFD list with empty `@graph`; verify
  `discussion=None`, no AFD-body call attempted, WARN logged.
- `products_afd_body_400.json` — error response on body fetch; verify
  `discussion=None`, WARN logged, hourly/daily still returned.

### Unit tests (no DB, no network — `respx` mock or pure-compute)

- **Icon URL → shortName extraction.** `"/icons/land/day/sct,30?size=medium"`
  → `"sct"`. `"/icons/land/night/rain?size=medium"` → `"rain"`. `None` → `None`.
  Empty → `None`. Malformed (no slash, no shortName) → `None`.
- **Compass abbreviation → degrees.** Each documented compass code maps to
  its degree value. Unknown / empty / `None` → `None`.
- **windSpeed string range parse.** `"5 to 10 mph"` → 10.0. `"7 mph"` → 7.0.
  `"5 to 10 km/h"` → 10.0. `""` → `None`. `None` → `None`. Garbage
  (`"foo bar"`) → `None`.
- **`_pair_day_night`.** Day-night-day-night sequence pairs cleanly into
  `[(day1, night1), (day2, None)]` if list length is 3. Night-day-night-day
  skips leading night → `[(day1, night1)]`. All-night sequence → empty list.
- **`_zip_hourly` correctness.** Given a 3-period fixture, returns 3
  `HourlyForecastPoint` records with correct field-by-field values.
  windSpeed parsed from string, windDir from compass, weatherCode from
  icon, weatherText from shortForecast, precipType from icon shortName,
  validTime via `to_utc_iso8601_from_offset()`. METRICWX wind post-convert
  verified: km/h → m/s (÷ 3.6).
- **`_zip_daily` correctness.** Given 4 paired (day,night) periods,
  returns 4 `DailyForecastPoint` records. tempMax = day's temperature,
  tempMin = night's temperature. precipProbabilityMax = max across day+night.
  windSpeedMax = max upper-bound across day+night. weatherCode/Text/narrative
  from day-period. validDate = day's startTime date part.
- **Per-target-unit `units=` mapping.** US → `"us"`. METRIC → `"si"`.
  METRICWX → `"si"` (and post-convert wind km/h → m/s in zip helpers).
  Unknown → raises `ProviderProtocolError`.
- **Wire-shape Pydantic.** Each of the 5 real fixtures loads cleanly into
  its respective wire-shape model. Missing required field (e.g., `cwa` in
  points response) → `ValidationError`. Extra field (NWS adds a new
  property) → ignored cleanly.
- **`ForecastQueryParams`.** No new tests — already covered by 3b-2.
- **Module fetch — happy path (respx-mocked).** All five outbound URLs
  intercepted with the recorded fixtures; `fetch()` returns a
  `ForecastBundle` with the right counts of hourly + daily points;
  discussion is `ForecastDiscussion` not `None`; source = `"nws"`.
  Spot-check one hourly + one daily field for value correctness.
- **Module fetch — cache hit.** Pre-populate cache with a serialized
  bundle; `fetch()` returns reconstructed bundle; respx call count = 0.
  Run twice — once with memory cache, once with fakeredis.
- **Module fetch — /points 404.** respx-mocked `/points/...` returns 404
  → `GeographicallyUnsupported`. No subsequent calls fire.
- **Module fetch — /forecast/hourly 5xx after retries.** respx-mocked 503
  → `TransientNetworkError`. No daily or AFD calls.
- **Module fetch — /forecast 429.** respx-mocked 429 → `QuotaExhausted`
  with `retry_after_seconds` set.
- **Module fetch — AFD list empty.** respx-mocked AFD list returns
  `{"@graph": []}` → bundle returned with `discussion=None`; no
  `/products/{id}` call attempted; WARN logged.
- **Module fetch — AFD body 5xx.** respx-mocked body call returns 503
  after retries → bundle returned with `discussion=None`; hourly/daily
  populated normally; WARN logged.
- **Module fetch — AFD body parse failure.** respx-mocked body returns 200
  with malformed JSON → bundle's discussion = `None`; WARN logged.
- **Module fetch — malformed hourly wire shape.** respx-mocked 200 with
  `forecast_hourly_malformed.json` → `ProviderProtocolError`.
- **Module fetch — leading-night periods.** respx-mocked daily forecast
  with `forecast_periods_starts_night.json` → daily list excludes the
  leading night; first daily entry is the first day-period.
- **UA contact wiring.** When `user_agent_contact="me@example.com"`, the
  outbound UA header reads `(weewx-clearskies-api/0.1.0, me@example.com)`.
  When `None`, UA reads `(weewx-clearskies-api/0.1.0)` and a one-time WARN
  is logged.
- **Capability registry — forecast/nws module.** `wire_providers([
  forecast_nws.CAPABILITY])` populates the registry;
  `get_provider_registry()` returns it.
- **`/capabilities` response — nws configured.** Response includes the nws
  provider declaration; `canonicalFieldsAvailable` is the union of stock
  columns + alerts fields (if alerts also configured) + nws's
  `supplied_canonical_fields`.
- **`/forecast` endpoint — nws configured (respx-mocked) — happy path.**
  200; `data.hourly` has the requested count; `data.daily` same;
  `data.discussion` is populated (not null); `data.source: "nws"`;
  envelope `units` is the loaded UnitsBlock.
- **`/forecast` endpoint — slice via query params.** `?hours=24&days=3` →
  bundle has exactly 24 hourly points and 3 daily points (matches existing
  slice-after-cache test pattern from 3b-2).
- **`/forecast` endpoint — defaults.** No query params → 48 hourly, 7 daily.
  (NWS supplies ~156 hourly and 7 daily, so defaults always succeed.)
- **`/forecast` endpoint — invalid query.** Inherits from 3b-2; no new
  tests needed — just ensure the existing tests still pass with nws
  configured.
- **`/forecast` endpoint — NWS down.** respx-mocked 503 on /forecast →
  502 ProviderProblem with `errorCode="TransientNetworkError"`.
- **`/forecast` endpoint — NWS quota exhausted.** respx-mocked 429 →
  503 ProviderProblem with `errorCode="QuotaExhausted"` + `Retry-After`
  header.
- **`/forecast` endpoint — non-US lat/lon.** respx-mocked /points 404 →
  503 ProviderProblem with `errorCode="GeographicallyUnsupported"`.

### Integration tests (against the docker-compose dev/test stack — both DB backends + both cache backends)

Mark each with `@pytest.mark.integration`. Mark Redis-tier with `@pytest.mark.redis`.

- **`/forecast` with no provider configured** — already covered by 3b-2;
  re-run to verify nws addition didn't regress.
- **`/forecast` with nws configured + respx-mocked — happy path** —
  TestClient → 200, full bundle including discussion. Both DB backends
  green (forecast doesn't touch DB but the test infra runs both for parity).
- **`/forecast` with nws configured + AFD soft-failure** — TestClient →
  200, bundle populated, `discussion=None`. WARN log captured.
- **`/capabilities` with both alerts (nws) + forecast (nws) configured** —
  response includes both provider declarations; `canonicalFieldsAvailable`
  includes nws's full forecast field set.
- **Startup with `[forecast] provider = nws`** — process starts cleanly;
  `_wire_providers_from_config` succeeds.
- **Startup with `[forecast] provider = nws` + missing
  `nws_user_agent_contact`** — process starts cleanly; first /forecast
  request emits a one-time WARN.
- **Startup with `[forecast] provider = aeris`** — process fails at
  dispatch lookup (`KeyError`) → CRITICAL log + exit non-zero. Same pattern
  as 3b-2's F7-equivalent.
- **Redis-backend integration (real Redis via the existing `redis` compose
  profile from 3b-1).** Optional integration tier: `pytest -m "integration
  and redis"` runs `/forecast` end-to-end against a real Redis. Default
  `pytest -m integration` skips the redis tier. **The brief gate requires
  the redis tier to PASS, not skip.** If the redis tier can't run on
  `weather-dev` for any reason, surface that to the lead via SendMessage
  BEFORE submitting the closeout — do not silently skip.

### Schema-shape rule

Same as 3b-2: provider tests don't depend on weewx archive schema, but the
wire-shape Pydantic models for NWS MUST be validated against real recorded
fixtures. No synthetic minimal stand-ins (3b-2 lesson).

### Tests run on `weather-dev` BEFORE the dev submits for audit

Per `rules/clearskies-process.md` "Audit modes are complementary, not
redundant". Both gates fire.

### Pull-then-pytest hard gate

`git fetch origin main && git merge --ff-only origin/main` BEFORE the pre-
submit pytest run. Branch is `main` on the api repo. **Hard gate** — not a
courtesy.

### Marker

All integration tests carry `@pytest.mark.integration`; Redis-tier
additionally carries `@pytest.mark.redis`. Unit tests run by default.

### Datetime-utils refactor — separate commit

The lift of `_to_utc_iso8601` from `providers/alerts/nws.py` into
`providers/_common/datetime_utils.py` (per call 23) goes in its own commit.
Diff: one new file with the function; alerts/nws.py imports from new
location; alerts/nws.py loses the function definition. No behavior change.
This commit lands BEFORE the new forecast/nws.py module commit so the new
module can import the shared helper from the start.

---

## Process gates

1. **ADR conflicts → STOP.** If anything in `openapi-v1.yaml` disagrees
   with an ADR or with canonical-data-model, do not proceed-and-flag at
   closeout. Stop at the first conflict, ping the lead.
2. **No new dependencies.** All deps from prior rounds cover this round.
   Anything else → STOP.
3. **Diff size budget.** Target ~1200-2000 line impl diff. If it crosses
   2500, ping the lead before submitting.
4. **Run pytest on weather-dev before submitting for audit.** Both DB
   backends + both cache backends green. Pre-existing skipped tests stay
   skipped; not a regression. The 3b-2 baseline was 781 passed / 25
   skipped on default-tier and 156 passed / 25 skipped on integration
   tier, plus 3 passed on the Redis tier. This round's test additions
   raise those counts; no test is expected to fail.
5. **Parallel-pull-then-pytest.** `git fetch origin main && git merge
   --ff-only origin/main` BEFORE the pre-submit pytest run, so api-dev's
   suite covers test-author's latest. Hard gate. **Branch is `main`**.
6. **Auditor reviews after both api-dev and test-author submit + green
   pytest.** Lead synthesizes findings; routes back to the relevant
   teammate per finding.
7. **Submit closeout report immediately after the final pytest run.**
   Don't idle. The lead-side polling cadence is the safety net but it
   relies on user-prompt boundaries — early submission shortens the
   round.
8. **Commit messages document non-obvious provenance** per the
   `clearskies-api-dev` agent definition. Especially for: per-target-unit
   `units=` query-param mapping (cite ADR-019), windSpeed-range upper-
   bound choice (cite canonical §4.1.3 note), AFD soft-failure pattern
   (cite §3.10 ForecastBundle.discussion nullability), datetime-utils
   refactor commit (cite `rules/coding.md` §3 DRY rule), USA-only handling
   via /points 404 (cite ADR-007 §Per-module behavior NWS row).
9. **Tests verify the brief; brief is the authority.** If api-dev's
   signature for `fetch()` disagrees with what test-author wrote, api-dev
   STOPs and pings the lead. **`fetch(*, lat, lon, target_unit,
   user_agent_contact) → ForecastBundle`** — one Pydantic model, not a
   list, not a dict, not a tuple.
10. **Brief-vs-canonical cross-check (3b-2 F2 lesson).** When impl matches
    canonical contracts but diverges from the literal text of the brief,
    STOP and ping the lead — the brief may be wrong against the contract.
11. **DCO + co-author trailer.** `git commit -s` plus
    `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` for
    api-dev / test-author work; Opus uses `Co-Authored-By: Claude Opus
    4.7 (1M context) <noreply@anthropic.com>`.
12. **Mid-flight SendMessage cadence.** Per the agent definitions —
    every milestone, ETA before long actions, result after, STOP-and-ping
    on blockers. Cadence floor: ~4 minutes of active work without a
    SendMessage triggers an idle suspicion at the lead end.

---

## Anti-patterns (don't)

- Don't add Aeris / OpenWeatherMap / Wunderground forecast modules this
  round. Each lands in its own future 3b round.
- Don't add AQI / earthquakes / radar provider modules. Separate 3b
  rounds.
- Don't add a pre-flight US bounding-box check on `(lat, lon)` to gate
  `/points`. Trust NWS's own 404; translate to canonical taxonomy. The
  3b-1 alerts module already established this posture.
- Don't reach for `requests`, `aiohttp`, `tenacity`, `pyyaml`, or any
  XML / DWML / CAP parser. NWS AFD body is plain ASCII.
- Don't disable TLS verification. EVER. Even for testing — use respx.
- Don't bypass the canonical error taxonomy. NWS errors map to the
  existing `ProviderError` hierarchy; nowhere else catches httpx.
- Don't catch `Exception:`. Catch specific classes.
  (`rules/coding.md` §3)
- Don't skip the recorded fixtures. Synthetic minimal wire-shape stand-ins
  hide protocol-evolution bugs the same way synthetic DB schemas hid
  multi-column constraint bugs.
- Don't make outbound HTTP from CI tests. Live-network is developer-local
  per ADR-038; the recorded-fixture capture happens once on weather-dev,
  not in CI.
- Don't store the wire response in cache. Cache the canonical
  `ForecastBundle` (post-normalization, as `model_dump(mode="json")` dict).
- Don't add a request-result cache at the FastAPI handler level. The
  ADR-017 cache lives at the provider level.
- Don't read api.conf twice. Settings cache is loaded once at startup.
- Don't import skyfield, sqlalchemy, or any DB lib in the forecast module.
- Don't break 3a-2's `/capabilities` shape, 3b-1's `/alerts` endpoint, or
  3b-2's `/forecast` openmeteo path. All extend, none mutate.
- Don't extend `logging/redaction_filter.py` this round. F13 stays
  deferred until a `client_id`-using provider lands.
- Don't hardcode the project's git URL or maintainer email anywhere.
- Don't fall back to a project-level NWS UA contact when
  `nws_user_agent_contact` is unset. ADR-006 prohibits this — operator-
  managed compliance, no exceptions.
- Don't surface `extras` for forecast points. NWS's response is well-known
  via the canonical mapping table; every supplied canonical field maps
  cleanly. `extras = {}` is fine.
- Don't pre-flight check icon shortName against an enumerated allow-list
  before the `_ICON_TO_PRECIP_TYPE` lookup. The lookup tolerates unknown
  shortNames (returns `None`); fall through is the correct posture per
  the canonical §3.3 enum.
- Don't flatten freezing-rain icon shortNames (`fzra`, `rain_fzra`,
  `snow_fzra`) to `"rain"`. Use `"freezing-rain"` per the post-3b-2 rule.
- Don't flip `fetch()` to return a list, dict, or tuple to satisfy a test.
  Tests verify the brief; brief is the authority. STOP and ping the lead
  on signature divergence.
- Don't share the `_rate_limiter` instance with `providers/alerts/nws.py`.
  Per-module limiter; alerts and forecast quotas are separate buckets.
- Don't try to fill `outHumidity`, `windGust`, `precipAmount`, `cloudCover`
  (hourly), `precipAmount`, `windGustMax`, `sunrise`, `sunset`, or
  `uvIndexMax` (daily) from the standard `/forecast{,/hourly}` endpoints.
  They're not there. Leave `null` per ADR-010 §Decision.4. The raw
  `/gridpoints/{office}/{x,y}` endpoint has them but is out of scope this
  round.
- Don't pre-resolve `/points` separately from the forecast bundle's cache
  entry. ONE cache entry per `(station, target_unit)`; on cache miss, all
  five outbound calls fire. The cache-key endpoint label is
  `"forecast_bundle"`, a logical name covering all five upstreams.
