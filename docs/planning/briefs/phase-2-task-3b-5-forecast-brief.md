# Phase 2 task 3b round 5 brief — clearskies-api forecast domain (OpenWeatherMap)

**Round identity.** Phase 2 task 3 sub-round 3b round 5. Fifth of 5 expected
3b rounds (3b-1 alerts/NWS + shared `_common/`; 3b-2 forecast/Open-Meteo;
3b-3 forecast/NWS + AFD; 3b-4 forecast/Aeris; **this round adds the
OpenWeatherMap forecast provider** — fourth concrete forecast provider out
of five in ADR-007's day-1 set; second keyed provider). One day-1 forecast
provider remains for a future 3b-6 round: Weather Underground.

This is a **single-deliverable round.** Shared infrastructure (HTTP wrapper
with `status_code`-bearing canonical exceptions, retry, error taxonomy,
capability registry, both cache backends, rate limiter, `to_utc_iso8601_
from_offset` datetime helper) already lives. Forecast canonical types
(`HourlyForecastPoint`, `DailyForecastPoint`, `ForecastDiscussion`,
`ForecastBundle`, `ForecastResponse`) already live in `models/responses.py`.
The `/forecast` endpoint already lives at `endpoints/forecast.py` with three
dispatch branches (openmeteo, nws, aeris). `ForecastSettings` already lives
with NWS UA contact + Aeris credentials. This round adds:

1. **`weewx_clearskies_api/providers/forecast/openweathermap.py`** — fourth
   concrete forecast provider per ADR-007 + ADR-038. Five module
   responsibilities; structural twin of `providers/forecast/aeris.py`
   (single-credential keyed provider; rich-coverage single-endpoint shape).
   **One outbound call per cache miss** — `/data/3.0/onecall` with
   `exclude=current,minutely,alerts` (forecast scope only this round).
2. **One new row in `_common/dispatch.py`** —
   `("forecast", "openweathermap") → providers.forecast.openweathermap`.
3. **`openweathermap_appid` field on `ForecastSettings`** sourced from env
   var `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID` per ADR-027 §3 + Q2 user
   decision (long form, mirrors module filename).
4. **`wire_openweathermap_credentials()` helper in `endpoints/forecast.py`**
   — mirror of `wire_aeris_credentials()`. Plugs into the existing
   `wire_forecast_settings()` wrapper.
5. **`elif provider_id == "openweathermap":` dispatch branch in
   `endpoints/forecast.py`** — passes lat/lon/target_unit + appid to
   `openweathermap.fetch()`.

**No `__main__.py` change** — already calls
`forecast.wire_forecast_settings(settings)`. **No
`logging/redaction_filter.py` extension** — `appid` redaction already
shipped in 3b-1 (the filter strips both `appid` and `client_secret` query
params; `client_id` was added in 3b-4). **No `__main__.py` startup-banner
change.**

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after
both submit and pytest is green on `weather-dev`.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` (clone of
`github.com/inguy24/weewx-clearskies-api`). **Default branch `main`** (verified
2026-05-08 against `git symbolic-ref refs/remotes/origin/HEAD`). Parallel-pull
command: `git fetch origin main && git merge --ff-only origin/main`. The
meta-repo (this `weather-belchertown/` workspace) is `master`.

**Pre-round HEADs verified 2026-05-08:**
- api repo: `ab3294a` (3b-4 remediation followup: 8 tests fixed after F4 timestamp restoration)
- meta repo: `f4f4097` (3b-4 close)
- weather-dev: `ab3294a` (already up to date)

**Pre-round pytest baseline (trusted from 3b-4 close, <24h ago):**
- Default tier: 1056 / 29 skipped / 0 failed in ~14 min
- Integration MariaDB: 188 / 29 skipped / 0
- Integration SQLite: ~205 / 20 skipped / 0
- Redis tier: 7 / 0 / 0 in 2.5s

---

## Scope — 1 provider module + plumbing

| # | Unit | Notes |
|---|---|---|
| 1 | `weewx_clearskies_api/providers/forecast/openweathermap.py` | New file. One outbound call per cache miss: `GET /data/3.0/onecall?lat=&lon=&appid=&units=&exclude=current,minutely,alerts`. Returns `hourly[]` (48 entries) + `daily[]` (8 entries) in a single response. **Discussion stays `None`** — canonical §4.1.4 OWM column shows all `—`. CAPABILITY enumerates the One Call max-surface; runtime population depends on the operator's tier. |
| 2 | `_common/dispatch.py` | Add `("forecast", "openweathermap") → providers.forecast.openweathermap` row. One import + one entry. |
| 3 | `config/settings.py` `ForecastSettings` | Add `openweathermap_appid: str \| None` field populated from env var `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID` at `__init__` (NOT from the `[forecast]` INI section — secrets per ADR-027 §3). |
| 4 | `endpoints/forecast.py` | Add `wire_openweathermap_credentials()` (mirror `wire_aeris_credentials`). Extend `wire_forecast_settings()` to also call it. Add `elif provider_id == "openweathermap":` dispatch branch (mirror `aeris` branch L246-259). |
| 5 | `__main__.py` | **No change** — already calls `forecast.wire_forecast_settings(settings)`. |
| 6 | `logging/redaction_filter.py` | **No change** — `appid` redaction already shipped in 3b-1 (`_APPID_RE`). Verify in test by adding a logged-URL redaction assertion to the new OWM unit suite. |
| 7 | Recorded fixtures | `tests/fixtures/providers/openweathermap/onecall.json` (full One Call 3.0 paid-tier shape), `error_401_basic_tier.json` (basic-tier key hitting `/data/3.0/onecall`), `error_429_quota.json`. Sidecar `.md` documents capture date + lat/lon + tier captured against. **Synthetic-from-real if no paid access** (per L3 rule) — fixture origin clearly marked. |

**Out of scope this round (defer to later 3b rounds / Phase 3+ / Phase 4):**

- **OWM free-tier fallback paths.** `/data/2.5/forecast` (5-day/3-hour, free)
  and `/data/2.5/weather` (current, free) are NOT exercised. v0.1's OWM forecast
  module is One Call 3.0 only; basic-tier deployments see empty bundle per
  Q1 user decision.
- **OWM alerts.** OWM One Call 3.0 returns an `alerts[]` array. This round is
  forecast-only; alerts are a separate domain. The URL parameter
  `exclude=current,minutely,alerts` keeps the response payload smaller. A
  future `providers/alerts/openweathermap.py` round (separate 3b-alerts
  series) reads `/data/3.0/onecall` without the `alerts` exclude.
- **OWM current-observation slot.** Canonical §4.1.1 OWM column references
  `/data/2.5/weather` for the observation slot — separate work; not
  part of `/forecast` endpoint.
- **OWM AI weather summary** (`/data/3.0/onecall/overview`). Could populate
  `ForecastDiscussion.body` on paid-tier deployments. Out of scope for v0.1
  — adds a second outbound call and is undocumented for the canonical
  `body` mapping. Future enhancement.
- **OWM timemachine / day_summary historical endpoints.** Not in `/forecast`
  scope.
- **Wunderground forecast.** One remaining 3b-forecast round (3b-6 or later).
  That round will fire F-future-redaction-extension (`apiKey` query param)
  and will be the first **partial-domain** provider (no hourly).
- **All other provider domains** — /aqi/* /earthquakes /radar/* are separate
  3b rounds.
- **Operator overrides for forecast TTL or rate-limit.** This round uses
  ADR-017's default 30 min for forecast; same as Open-Meteo + NWS + Aeris.
- **Multi-location.** ADR-011 single-station.
- **Setup-wizard region-based provider suggestion.** ADR-027 wizard ships
  in Phase 4.

---

## Lead-resolved calls (no user sign-off needed — ADRs and contracts settle these)

The "Brief questions audit themselves before draft" rule
(`rules/clearskies-process.md`) requires every "open question" to be audited
against the ADRs first. The "brief-vs-canonical cross-check" rule (post-3b-2,
F2) requires every lead-resolved call to cross-check against
`canonical-data-model.md` + `openapi-v1.yaml` before drafting. Both audits
performed; every call below has been verified against both. Numbered for
reference, not for sign-off.

### Inherited from 3b rounds 2, 3 & 4 (no change, no re-audit needed)

1. **HTTP client = `httpx` (sync).** `ProviderHTTPClient` from
   `_common/http.py`. Already covers TLS, timeouts, retry/backoff, error-class
   translation, structured `status_code` attribute on `ProviderError` (3b-3
   F2 remediation), `retry_after_seconds` on quota errors (3b-4 F1
   remediation), and 4xx body logging at ERROR (3b-2 F1).

2. **Forecast cache TTL = 30 min.** ADR-017 §Per-provider TTL declaration.
   Module's `CAPABILITY.default_poll_interval_seconds = 1800`.

3. **Capability-registry populate path.** ADR-038 §3 + 3b-2's
   `_wire_providers_from_config()`. No change needed — adding the dispatch
   row in step 2 above is enough; the existing `__main__.py` lookup picks
   `openweathermap` automatically when `[forecast] provider = openweathermap`.

4. **Both cache backends already live.** ADR-017 + 3b-1's `MemoryCache` +
   `RedisCache`. Forecast/openweathermap consumes `get_cache()` like the
   other modules.

5. **No live-network tests in CI.** ADR-038 §Testing pattern. Recorded
   fixtures + `respx` for everything.

6. **Source field when no provider configured = literal `"none"`.**
   `endpoints/forecast.py` already does this; no change.

7. **`precipType` derivation rule (forecast-domain, all providers).** Use
   §3.3 enum values literally — `"rain"` / `"snow"` / `"sleet"` /
   `"freezing-rain"` / `"hail"` / `"none"`. **Do NOT flatten freezing variants
   to `"rain"`.** Locked in canonical-data-model §4.1.2 from 3b-2 audit (F2).
   OWM-specific lookup table operationalizing this rule is **call 17** below.

8. **Slice-after-cache pattern.** `endpoints/forecast.py` already slices the
   bundle's `hourly` and `daily` arrays after cache lookup. OWM One Call 3.0
   provides 48 hourly + 8 daily; the slice cap is whatever OWM returned. No
   new behavior at the endpoint level. ForecastQueryParams' 384-hour /
   16-day caps are well above OWM's response size.

9. **Dispatch on exception state via attributes, not message strings.** Per
   `rules/coding.md` §3 (added 2026-05-08 from 3b-3 F2). OWM module uses
   `exc.status_code == 401` for KeyInvalid translation, `exc.status_code ==
   429` for QuotaExhausted, `exc.status_code in (400, 422)` for protocol
   errors. **No `"X" in str(exc)` patterns.** **Special case** — see lead-
   call 18 below for the One-Call-401 → empty-bundle dispatch (Q1 decision).

10. **Reuse `providers/_common/datetime_utils.py` for offset-aware ISO
    timestamps.** OWM emits epoch UTC seconds (`dt`), NOT offset-aware ISO
    strings, so `to_utc_iso8601_from_offset` does NOT apply directly. **Add
    a sibling helper `epoch_to_utc_iso8601(epoch_seconds: int, *,
    provider_id: str, domain: str) -> str`** at the same path. Per
    `rules/coding.md` §3 DRY ("search before writing a new helper"), check
    for an existing epoch-to-ISO helper first; none exists in the
    `_common/` tree as of `ab3294a`. Adding it as a sibling in
    `datetime_utils.py` keeps the helper neighborhood tidy. Lead-call.

    Helper signature mirrors the existing one's arg pattern:
    ```python
    def epoch_to_utc_iso8601(
        epoch_seconds: int | float,
        *,
        provider_id: str,
        domain: str,
    ) -> str:
        """Convert epoch UTC seconds to ISO-8601 Z form (ADR-020).

        Raises ProviderProtocolError on out-of-range / non-numeric input.
        """
        try:
            dt = datetime.fromtimestamp(epoch_seconds, tz=UTC)
        except (OverflowError, ValueError, OSError, TypeError) as exc:
            raise ProviderProtocolError(
                f"Epoch parse failed for {epoch_seconds!r}: {exc}",
                provider_id=provider_id,
                domain=domain,
            ) from exc
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    ```

    `to_utc_iso8601_from_offset` stays alongside; the OWM module imports
    only the new helper.

11. **Don't re-construct canonical exceptions you've already received.** Per
    the 3b-4 L2 carry-forward in `.claude/agents/clearskies-api-dev.md`.
    `ProviderHTTPClient.get()` raises canonical exceptions with all
    structured attributes set. The OWM module makes **bare `client.get()`
    calls** and lets canonical exceptions propagate, EXCEPT for the
    One-Call-401 → empty-bundle dispatch (lead-call 18) where the exception
    is intercepted intentionally. **No `try / except <CanonicalException>:
    raise <CanonicalException>(...) from exc` patterns.**

12. **Synthetic-from-real fixture pattern when paid-tier provider access is
    unavailable.** Per the 3b-4 L3 carry-forward in `.claude/agents/
    clearskies-test-author.md`. test-author **first attempts a real
    paid-tier capture** of `/data/3.0/onecall` (One Call by Call subscription
    is the gating credential — operator may have one). If no paid access
    is available, fixture is constructed from the OpenWeatherMap api-docs
    example response at `docs/reference/api-docs/openweathermap.md`
    L161-213 — that example IS the literal wire shape the module parses.
    Sidecar `.md` documents synthetic origin clearly: "constructed from
    api-docs/openweathermap.md L161-213 example response — fields mirrored,
    not captured live." **Do NOT skip the One Call 3.0 path because the
    fixture is missing.** The basic-tier 401 fixture is captured from a
    real basic-tier key (free tier of OWM is widely available; both
    test-author and lead can register if needed) OR synthesized from
    api-docs gotchas section ("A free-tier API key alone returns 401 from
    `/data/3.0/onecall`"). Same sidecar marker.

### OWM-specific (this round)

13. **One outbound call per cache miss.** OWM One Call 3.0 workflow per
    `docs/reference/api-docs/openweathermap.md` §"One Call API 3.0":
    1. `GET /data/3.0/onecall?lat={lat}&lon={lon}&appid={appid}&units={units}&exclude=current,minutely,alerts`
       → returns `hourly[]` (48 entries) + `daily[]` (8 entries) in one
       payload.

    `exclude=current,minutely,alerts` — current is served via a different
    canonical mapping (§4.1.1, separate work); minutely is per-minute
    precipitation we don't surface; alerts is a separate domain (3b-future).
    Excluding minutely cuts the response payload by ~60% with no canonical
    impact.

    The post-normalization `ForecastBundle` is cached for 30 min (ADR-017).
    Single cache key per `(station, target_unit)`. Cache stores
    `model_dump(mode="json")`; reconstructed via `model_validate()`.

14. **OWM auth: single `appid` query param.** Per ADR-007 line 72 +
    openweathermap.md §Authentication. Single credential; no client_secret
    pair. Sourced from env var per ADR-027 §3 + Q2 user decision (long
    form):
      - `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID`

    **Module wiring.** `wire_openweathermap_credentials()` reads the env
    var at startup (in `endpoints/forecast.py`, mirror of
    `wire_aeris_credentials()`); module-level `_openweathermap_appid` is
    passed to `openweathermap.fetch()` from the dispatch branch.

    **Missing-credential behavior at fetch time.** If the operator sets
    `[forecast] provider = openweathermap` but does NOT set the env var,
    the module raises `KeyInvalid("OpenWeatherMap appid missing — set
    WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID")` on the first request.
    Translated to 502 ProviderProblem with `errorCode="KeyInvalid"`.
    Same loud-failure posture as the 3b-4 Aeris missing-credential branch.
    **Do NOT silently disable the module at startup** — the operator's
    intent (`provider = openweathermap`) is unambiguous; refusing to serve
    forecasts loudly beats serving no-provider-configured silently.

15. **OWM unit handling: `units` query param + post-conversion for
    METRIC pressure/precip and METRIC wind.** Per ADR-019 §Decision (server
    passes weewx target_unit through; provider conversions at ingest).
    OWM One Call 3.0 accepts `units=imperial|metric|standard`. Per
    openweathermap.md gotchas §"Pressure and precipitation units do not
    change with `units`" — pressure is ALWAYS hPa, precip is ALWAYS mm,
    regardless of `units`. Mapping table:

    | target_unit | `units` query param | Wind speed | Pressure | Precip |
    |---|---|---|---|---|
    | `US` | `imperial` | mph (no convert) | hPa → inHg (× 0.02953) | mm → in (÷ 25.4) |
    | `METRIC` | `metric` | m/s → km/h (× 3.6) | hPa → mb (= hPa, no convert) | mm (no convert) |
    | `METRICWX` | `metric` | m/s (no convert; already correct for METRICWX) | hPa → mb (= hPa, no convert) | mm (no convert) |

    Helper `_convert_owm_units(value, *, field_kind, target_unit)` for the
    repeatable cases (wind, pressure, precip). Field-kind enum:
    `wind_speed`, `wind_gust`, `pressure`, `precip_amount`. `outTemp`,
    `outHumidity`, `cloudCover`, `windDir`, `pop`, `uvi`, `dewpoint` need
    no conversion (OWM's `units=imperial` returns °F directly; `metric`
    returns °C; humidity/cloud/dir are dimensionless or always in
    consistent units).

    NB: pressure conversion 1 hPa = 0.02953 inHg. Per ADR-019 the
    canonical unit for `barometer` (US) is inHg; OWM's hPa is the same as
    mb so METRIC + METRICWX pass through. Module documents the conversion
    factors in the impl docstring + commit body.

16. **`weatherCode` extraction = pass-through `weather[0].id`.**
    Canonical §4.1.2 OWM column: `hourly[].weather[0].id`. Canonical §4.1.3
    OWM column: `daily[].weather[0].id`. Format is integer (e.g., 803 =
    "broken clouds"); module passes through as the canonical `weatherCode`
    string after `str()` conversion. Dashboard maps to icon. Same opaque-
    pass-through posture as Open-Meteo's WMO codes, NWS's icon shortNames,
    and Aeris's `weatherPrimaryCoded`.

17. **`precipType` derivation from OWM weather code ID ranges.** Per the
    forecast-domain rule (call 7), use canonical §3.3 enum literally. OWM
    weather codes are documented at https://openweathermap.org/weather-
    conditions and grouped into ranges:

      - **2xx (Thunderstorm):** 200, 201, 202, 210, 211, 212, 221, 230, 231,
        232 → `"rain"` (thunder accompanies rain in canonical framing,
        consistent with NWS `tsra` and Aeris `T` mappings)
      - **3xx (Drizzle):** 300, 301, 302, 310, 311, 312, 313, 314, 321 →
        `"rain"` (drizzle is rain class in canonical §3.3, same as Aeris
        `L` and WMO 51-55)
      - **5xx (Rain):** 500, 501, 502, 503, 504, 520, 521, 522, 531 →
        `"rain"`
      - **511 (Freezing rain):** → `"freezing-rain"` (the only freezing
        variant in OWM's code set)
      - **6xx (Snow):** 600, 601, 602, 620, 621, 622 → `"snow"`
      - **611 (Sleet) + 612, 613 (light/heavy sleet) + 615, 616 (mix):** →
        `"sleet"` for 611-613; **`"rain"` for 615-616** (mixed precip,
        log DEBUG once per encounter; consistent with NWS `mix`/`rain_snow`
        and Aeris `RS`/`WM`/`SI` mappings)
      - **7xx (Atmosphere — fog/haze/dust/etc):** 701-781 → `None`
      - **800 (Clear):** → `None`
      - **8xx (Clouds):** 801-804 → `None`
      - **All other / unknown codes:** → `None` (log DEBUG once on first
        encounter)

    Helper `_owm_weather_code_to_precip_type(code: int) -> str | None`:
    range-based lookup; unknown → `None`. Hail: OWM codes 906 ("hail")
    exists per the conditions doc but is rare; map → `"hail"` for
    completeness even though OWM doesn't typically use it for forecast
    classes.

18. **Q1 user decision: graceful empty bundle on `/data/3.0/onecall` 401.**
    USER DECIDED 2026-05-08 — see "Brief-draft sign-off" §Q1 below for the
    audit trail. Operationalization here:

    - The module wraps the **One Call 3.0 outbound call only** in a narrow
      `try / except KeyInvalid` block. Other endpoints (none in this
      round, but future-proof) do not wrap.
    - When `client.get(/data/3.0/onecall, ...)` raises `KeyInvalid` AND
      `exc.status_code == 401`: catch, log at WARN once per process
      ("OpenWeatherMap appid lacks One Call 3.0 subscription — returning
      empty forecast bundle"), return
      `ForecastBundle(hourly=[], daily=[], discussion=None,
      source="openweathermap", generatedAt=<now>)`.
    - When `KeyInvalid` is raised with `exc.status_code` other than 401
      (defensive — `KeyInvalid` from this provider should always be 401,
      but the dispatch is defensive): re-raise. Lets canonical taxonomy
      handle (502 ProviderProblem KeyInvalid).
    - When `client.get(...)` raises ANY other canonical exception
      (TransientNetworkError, QuotaExhausted, ProviderProtocolError,
      etc.): no wrap; let them propagate.

    **Per the L2 rule (3b-4), the wrap is INTENTIONAL — it's not a
    re-construct of an inner canonical exception. It's a deliberate
    swallow at one specific dispatch point, on attribute (`status_code`)
    not message string (per `rules/coding.md` §3, lead-call 9).** Document
    inline in the impl docstring and commit body so future readers
    understand the deviation from "let canonical exceptions propagate."

    **Audit risk surfaced (lead's recorded concern, user-overridden):** the
    pattern blurs the line between "key invalid entirely" and "key valid
    but lacks One Call subscription." From the OWM API's perspective, both
    return 401 from this endpoint with no way to distinguish them in the
    response body without parsing. We accept the conflation: an
    operator-misconfigured key that happens to return 401 from One Call
    will silently surface as empty bundle (no panel) instead of
    KeyInvalid 502 (also no panel). User-side behavior identical;
    operator's recovery action identical (verify key works at OWM's
    dashboard). If post-audit the auditor flags this as ADR-038 strict-
    error-mapping drift, the lead's response is "user-accepted trade-off,
    see brief Q1."

19. **CAPABILITY declares the One Call 3.0 max-surface — applies the L1
    rule from 3b-4.** Per `rules/clearskies-process.md` "Provider
    CAPABILITY declares paid-tier maximum supply set; runtime population
    is conditional." OWM CAPABILITY enumerates every canonical hourly +
    daily field One Call 3.0 can supply. Runtime population is
    conditional on the operator's tier (Q1 above): paid-tier deployments
    see populated bundles; basic-tier deployments see `hourly=[],
    daily=[]`. This applies the L1 rule wider than 3b-4's Aeris case
    (which exercised it for one optional `summary` field) — OWM exercises
    it for the entire hourly+daily surface.

    **CAPABILITY.supplied_canonical_fields** (final list, hourly + daily):

    ```
    # HourlyForecastPoint
    "validTime", "outTemp", "outHumidity", "windSpeed", "windDir",
    "windGust", "precipProbability", "precipAmount", "precipType",
    "cloudCover", "weatherCode", "weatherText",
    # DailyForecastPoint
    "validDate", "tempMax", "tempMin", "precipAmount",
    "precipProbabilityMax", "windSpeedMax", "windGustMax",
    "sunrise", "sunset", "uvIndexMax", "weatherCode", "weatherText",
    "narrative",
    # ForecastDiscussion — NOT supplied (canonical §4.1.4 OWM column = all "—")
    ```

    **NB:** `narrative` IS supplied (canonical §4.1.3 maps it to
    `daily[].summary`). `dewpoint` (hourly) is NOT in HourlyForecastPoint
    canonical type per §3.3, so not in CAPABILITY even though OWM provides
    `hourly[].dew_point`. Discussion fields (`headline`, `body`, etc.)
    are NOT in the list.

    **operator_notes:** "OpenWeatherMap One Call 3.0 (paid 'One Call by
    Call' subscription required for /data/3.0/onecall). Basic-tier appid
    returns empty forecast bundle (Q1 user decision 2026-05-08). Coverage
    global; per ADR-007 §Per-module behavior."

20. **`weatherText` extraction.**
    - Hourly: `hourly[].weather[0].description` directly (e.g., "broken
      clouds"). OWM provides this as a human-readable label parallel to
      the coded form (canonical §4.1.2 OWM column).
    - Daily: `daily[].summary` **preferred**, fallback to
      `daily[].weather[0].description` if `summary` is absent or empty.
      Canonical §4.1.3 OWM column states `daily[].summary` (preferred) or
      `weather[0].description`. Operationalize: prefer `summary`; if
      `summary is None or summary.strip() == ""`, fallback to
      `weather[0].description`.

21. **`narrative` (DailyForecastPoint).** `daily[].summary` per canonical
    §4.1.3 OWM column. Same field as the preferred `weatherText` — both
    fields end up with the same string when OWM returns a `summary`. This
    is canonical-mapping-conformant; the canonical model allows this overlap
    (canonical §3.4 doesn't require `narrative` and `weatherText` to differ).
    When `summary` is absent, `narrative=None`.

22. **`pop * 100` precipitation probability.** Per canonical §4.1.2
    + §4.1.3 + openweathermap.md gotchas §"`pop` is 0–1, not percent". OWM
    `pop` is 0-1 float; canonical `precipProbability` /
    `precipProbabilityMax` are 0-100 percent. Multiply by 100 in the
    normalizer. Document inline + in commit body (gotcha-source).

23. **`rain.1h` + `snow.1h` → `precipAmount` (hourly).** Per canonical §4.1.2
    OWM column: `hourly[].rain.1h + hourly[].snow.1h`. Per openweathermap.md
    gotchas §"Rain/snow keys may be absent. Always check before reading":
    treat absence as 0 mm. Helper `_owm_hourly_precip_mm(period: dict) ->
    float`: returns `(rain.get("1h", 0) or 0) + (snow.get("1h", 0) or 0)`,
    with defensive coercion if `rain` / `snow` keys are themselves absent
    (returns 0 in that case). Then the `target_unit` conversion (mm → in
    for US per call 15) applies.

24. **`daily[].rain` + `daily[].snow` → `precipAmount` (daily).** Per
    canonical §4.1.3 OWM column: `daily[].rain + daily[].snow`. NB: on
    `daily[]` these are total mm (NOT a `1h` sub-object — One Call 3.0
    daily uses scalar mm per the api-docs example response L194-201).
    Treat absence as 0. Helper `_owm_daily_precip_mm(day: dict) -> float`:
    returns `(day.get("rain") or 0) + (day.get("snow") or 0)`. Then the
    `target_unit` conversion applies (call 15).

25. **Datetime conversion.** OWM emits epoch UTC seconds for `dt`,
    `sunrise`, `sunset`. Module reuses `epoch_to_utc_iso8601()` from
    `providers/_common/datetime_utils.py` (added per call 10). Result
    matches canonical §3.3 / §3.4 (UTC ISO-8601 Z).

    `validDate` (DailyForecastPoint): per canonical §3.4 = station-local
    YYYY-MM-DD. Derive from `daily[].dt + timezone_offset` (both fields
    in seconds — OWM's `timezone_offset` is at the response root level).
    Helper `_owm_validdate(epoch_utc: int, tz_offset_seconds: int) -> str`:
    `datetime.fromtimestamp(epoch_utc + tz_offset_seconds, tz=UTC).
    strftime("%Y-%m-%d")` — adding the offset BEFORE construction shifts
    the wall-clock to station-local time; we then format the date part
    only. The station's actual tz isn't needed because OWM gives us the
    offset directly.

26. **`sunrise` / `sunset` parsing.** OWM `daily[].sunrise` /
    `daily[].sunset` are epoch UTC seconds. Module reuses
    `epoch_to_utc_iso8601()` (call 10). Result matches canonical §3.4
    (UTC ISO-8601 Z).

27. **`validTime` (HourlyForecastPoint) parsing.** OWM `hourly[].dt` is
    epoch UTC seconds. `epoch_to_utc_iso8601()` produces canonical
    `validTime` (UTC ISO-8601 Z per canonical §3.3).

28. **`outHumidity`, `windDir`, `cloudCover`, `uvIndexMax`.** Direct
    pass-through from OWM:
    - Hourly `outHumidity` = `hourly[].humidity` (already 0-100 percent).
    - Hourly `windDir` = `hourly[].wind_deg` (already degrees).
    - Hourly `cloudCover` = `hourly[].clouds` (already 0-100 percent).
    - Daily `uvIndexMax` = `daily[].uvi` (already a float).
    - Daily `windDir`: not a canonical field per §3.4 — skip.

    Lead-resolved per canonical §4.1.2 / §4.1.3.

29. **Geographic coverage: trust OWM's authoritative answer.** ADR-007 +
    openweathermap.md says OWM has global coverage. The module does NOT
    carry a client-side geographic gate. CAPABILITY
    `geographic_coverage="global"`. Posture matches Open-Meteo + Aeris.

30. **Rate limiter for OWM.** Per ADR-038 §3 + 3b-3 F4 lesson on
    per-call acquire. OWM publishes:
    - Free tier (Current + 5-day): 60/min, 1M/month.
    - One Call by Call free: 1000/day; default paid: 2000/day.

    The 1000/day limit is the binding one for One Call subscribers. With
    cache TTL = 30 min, an operator hits OWM ~48 times/day — well within
    1000/day. Configure
    `RateLimiter("openweathermap-forecast", max_calls=5,
    window_seconds=1)` as a "be polite" guard matching Open-Meteo + NWS +
    Aeris — covers the per-second cap and well below any plan's
    per-second floor. **Per-call acquire** before the single outbound
    call per cache miss.

    Operator override for daily quota is out of scope (ADR-017 may grow
    that knob in a future revision; this round doesn't need it because
    cache TTL keeps real usage 50× below quota).

31. **Cache key shape.** `SHA-256(json({"provider_id": "openweathermap",
    "endpoint": "forecast_bundle", "params": {"lat4": "...", "lon4":
    "...", "target_unit": "..."}}, sort_keys=True))`. The `"endpoint"`
    string is `"forecast_bundle"` (a logical name; OWM has only one
    endpoint per cache miss but the convention matches Aeris's
    "forecast_bundle" key shape). Mirrors the Aeris pattern — note in
    impl docstring + commit body that the logical-key choice is
    deliberate.

32. **`extras` field on canonical OWM hourly / daily points.** OWM
    surfaces fields that don't map 1:1 to canonical (`feels_like`,
    `pressure_mean_sea_level`, `dew_point` on hourly; `moonrise`,
    `moonset`, `moon_phase`, `feels_like.morn/day/eve/night`, `temp.morn/
    day/eve/night` on daily). Per canonical §3.3 + §3.4, `extras: object`
    is provider-specific; v0.1 treatment: **leave `extras: {}` empty for
    OWM this round.** Same as Aeris (3b-4 lead-call 24). Future round
    may add `feelsLike` if/when canonical adds an "apparent temperature"
    field for hourly/daily forecast points.

33. **No discussion runtime detection for OWM v0.1.** Canonical §4.1.4
    OWM column shows ALL `—` — OWM's One Call 3.0 does not surface a
    forecast-discussion-shape product in the One Call response. The
    `/data/3.0/onecall/overview` endpoint exists (AI-generated weather
    summary) but is OUT OF SCOPE this round (would add a 2nd outbound
    call; canonical mapping doesn't sanction it for `body`). Bundle
    ships with `discussion=None` unconditionally. CAPABILITY does NOT
    list `headline` / `body` / etc. **No L1 paid-tier-conditional
    detection for the discussion slot.**

34. **No "alerts" field on bundle from OWM forecast module.** OWM One
    Call 3.0 returns `alerts[]` when present — but this is the FORECAST
    domain module; alerts is a separate domain (3b-future-alerts/owm
    round). Forecast scope sets `exclude=current,minutely,alerts` on the
    URL; the alerts array won't be in the response. ForecastBundle has
    no alerts slot per canonical §3.10 (alerts is its own canonical
    AlertList type, surfaced via `/alerts` endpoint).

35. **`mode` and `lang` query params not used.** OWM accepts `mode=json`
    (default) and `lang=<locale>` (30+ supported). v0.1 uses defaults:
    `mode` defaults to JSON, `lang` defaults to English. Operator's i18n
    locale is handled at the dashboard layer per ADR-021; api passes
    English forecast text through and the dashboard's i18n catalog
    handles localization of canonical UI strings. Future enhancement may
    pass `lang` based on a server-side config; not v0.1 scope.

---

## Brief-draft sign-off — USER DECIDED 2026-05-08

The "Brief questions audit themselves before draft" rule says drop questions
the ADR settles. Two operationalization questions surfaced — both real
ADR-vs-fit / canonical-spec-operationalization decisions. Both decided by
the user 2026-05-08 before brief draft.

### Q1. OWM tier handling — `/data/3.0/onecall` 401 from basic-tier key → **(A) Graceful empty bundle** (per user decision)

**Decision:** Module catches `KeyInvalid` raised from the One Call 3.0
outbound call **specifically** (where `exc.status_code == 401`) and
returns `ForecastBundle(hourly=[], daily=[], discussion=None,
source="openweathermap", ...)` — empty bundle, NOT error. Other 401s
(non-existent in v0.1's single-endpoint module, but defensive) re-raise
as KeyInvalid 502. The wrap is intentional and documented inline; per L2
this is NOT a "re-construct canonical exception" anti-pattern — it's a
deliberate dispatch-on-attribute swallow at one specific call site.

**Audit trail.** Considered options:

- (A) Graceful empty bundle — chosen. Aligns with L1 paid-tier-max-surface
  rule (CAPABILITY enumerates One Call max; runtime population conditional
  on tier). Aligns with ADR-007 §Per-module behavior wording ("returns
  'not available with this subscription'" → empty rather than error).
  Dashboard hides panel via the same path as no-provider-configured.
- (B) Strict KeyInvalid 502 — rejected. Conflates basic-tier-no-One-Call
  with key-entirely-invalid; harder to distinguish in operator logs. The
  user-side behavior is identical (dashboard hides panel) but operator
  log clarity favors (A).
- (C) Operator-config tier flag — rejected. Adds config surface for a
  signal already inferable from the API's own response. Also adds
  setup-wizard surface for Phase 4. Not justified by current scope.

**Operationalization.** Lead-call 18 above implements this. The wrap is
documented inline in the module docstring + commit body. Auditors flagging
this as L2 anti-pattern get the lead's response: "intentional dispatch-
on-attribute swallow at one specific call site, not a re-construct;
user-accepted trade-off, see brief Q1."

**Lead-recorded concern (user-overridden):** option (A) blurs the line
between "key invalid entirely" and "key valid but lacks One Call
subscription" — both return 401 from this endpoint. We accept the
conflation. Operator-side recovery action is the same regardless.

**Test-author scope addition.** Tests cover BOTH paths:
- Captured paid-tier fixture with full hourly/daily → bundle populated.
- Captured (or synthesized) basic-tier 401 fixture → bundle is empty,
  source="openweathermap", **no** 502 error response.

### Q2. OWM env-var naming brevity → **(A) Long form `OPENWEATHERMAP`** (per user decision)

**Decision:** `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID`. Long form matching
the module filename `openweathermap.py` and the dispatch key
`("forecast", "openweathermap")`. Consistent with the 3b-4 Aeris
precedent (`WEEWX_CLEARSKIES_AERIS_*` matches `aeris.py` + dispatch key
`aeris`).

**Audit trail.** Considered options:

- (A) Long form `OPENWEATHERMAP` — chosen. No new abbreviation
  introduced. Module filename + dispatch key + env-var domain prefix all
  the same string.
- (B) Short form `OWM` — rejected. Common community abbreviation, but
  introduces drift between env-var name and code-side identifiers
  (module file is `openweathermap.py`, dispatch key is `openweathermap`).

**Operationalization.** Lead-call 14 above implements this.
`config/settings.py` reads `os.environ.get("WEEWX_CLEARSKIES_
OPENWEATHERMAP_APPID")` at `ForecastSettings.__init__`. Provider-scoped
naming (no domain prefix) follows the 3b-4 Q1 precedent — no
re-litigation. Inline docstring notes the deviation from ADR-027 §3
literal schema (which prescribes `<DOMAIN>_<PROVIDER>_<FIELD>`).

---

## Hard reading list (once per session)

**Both api-dev and test-author:**

- `CLAUDE.md` — domain routing + always-applicable rules (lessons-capture,
  memory-disabled, `.claude/` private, plain-English, scope discipline).
- `rules/clearskies-process.md` — full file. **Carry-forward (NEW from
  3b-4 close 2026-05-08):**
    - "Provider CAPABILITY declares paid-tier maximum supply set; runtime
      population is conditional" — lead-call 19 above operationalizes the
      L1 rule wider than 3b-4's Aeris case. OWM exercises it across the
      whole hourly+daily surface (basic-tier sees empty bundle; paid-tier
      sees populated bundle).
  Carry-forward (from 3b-3 close): live-scratchpad rule
  (`c:\tmp\3b-5-scratch.md` is the lead's scratchpad); lead-direct
  remediation when surface ≲50 lines / ≲3 files; canonical-spec-
  operationalization is a brief-draft question (Q1+Q2 above are this
  rule firing); `git commit -F c:\tmp\<task>-msg.txt` for multi-line
  PowerShell commit messages.
  Carry-forward (from prior rounds): poll-don't-wait at user-prompt
  boundaries; brief-questions-audit at draft; brief-vs-canonical
  cross-check at draft; tests verify the brief; ADR conflicts → STOP;
  round briefs land in the project, not in tmp; `.claude/` stays
  private; lead synthesizes auditor findings, doesn't forward.
- `rules/coding.md` — full file. **§3 carry-forward** (from 3b-3): "Dispatch
  on exception state via attributes, not message strings" — lead-call 9
  above. OWM module dispatches on `exc.status_code`, never on
  `str(exc)`. Carry-forward: §1 Pydantic + Depends pattern (already in
  `endpoints/forecast.py`), IPv4/IPv6-agnostic networking (`httpx.Client`
  resolves via `getaddrinfo` natively), no dangerous functions, no
  hardcoded secrets (OWM `appid` in env vars per ADR-027 §3; never inline
  in source). §3: catch specific exceptions, never `except Exception:`.
  §3 "search before writing a new helper" — `epoch_to_utc_iso8601()` is
  a NEW helper added per call 10; verify no existing one before adding
  (none in `_common/` as of `ab3294a` — confirmed). §5 (a11y) is
  non-applicable — backend round.
- **`.claude/agents/clearskies-api-dev.md`** — agent definition. **Carry-
  forward (NEW from 3b-4 close):** "Don't re-construct canonical
  exceptions you've already received" (L2). OWM module makes BARE
  `client.get()` calls. The ONE narrow `try / except KeyInvalid` block
  for the One-Call-401 graceful path is intentional and documented
  (lead-call 18 + Q1 user decision). All OTHER call sites: bare client
  calls, let canonical exceptions propagate.
  Carry-forward: tests verify the brief; brief-vs-canonical STOP-and-
  ping; **commit early and often**; mid-flight SendMessage cadence (no
  >4 min silent); commit messages document non-obvious provenance.
- **`.claude/agents/clearskies-test-author.md`** — agent definition.
  **Carry-forward (NEW from 3b-4 close):** "Synthetic-from-real fixture
  pattern when paid-tier provider access is unavailable" (L3). For OWM,
  synthetic-from-api-docs-example pattern applies if no paid One Call
  subscription is available — see lead-call 12 + the fixtures row in the
  scope table. Sidecar `.md` documents synthetic origin clearly. Brief-
  gate honesty (no silent skips on cache-tier or DB-tier coverage);
  commit early and often.
- **`.claude/agents/clearskies-auditor.md`** — agent definition.
- `docs/contracts/openapi-v1.yaml`:
  - `/forecast` at line 186 (no change; OWM reuses the existing endpoint).
  - `HourlyForecastPoint` at line 1016 (no change).
  - `DailyForecastPoint` at line 1035 (no change).
  - `ForecastDiscussion` at line 1058 (OWM uses `null`; structural
    reference only).
  - `ForecastBundle` at line 1073 (`discussion: oneOf null or
    ForecastDiscussion`; not in `required`).
  - `ForecastResponse` at line 1562.
  - `ProviderProblem` at line 863, `ProviderError` 502 response at line 799,
    `ProviderUnavailable` 503 response at line 807,
    `CapabilityDeclaration` at line 1432.
- `docs/contracts/canonical-data-model.md`:
  - §3.3 (HourlyForecastPoint per-field enumeration + unit groups).
  - §3.4 (DailyForecastPoint per-field enumeration + unit groups).
  - §3.5 (ForecastDiscussion — for the canonical type even though OWM
    bundle ships `null`).
  - §3.10 (ForecastBundle container — `null` discussion is canonical-
    shape-conformant).
  - §4.1.2 (Hourly forecast — OWM column for the per-field mapping).
  - §4.1.3 (Daily forecast — OWM column).
  - §4.1.4 (Forecast discussion — OWM column = all `—`; bundle ships
    `null`).
- `docs/contracts/security-baseline.md`:
  - §3.4 (secrets — fires this round. OWM `appid` from env var; never
    inline in source).
  - §3.5 (input validation — Pydantic models for the wire shape inside
    the normalizer per ADR-038).
  - §3.6 (logging — provider URL logged at INFO with `appid` query
    param present; redaction filter strips before formatter emits.
    Test coverage: a logged URL containing `?appid=ABC123` redacts
    `[REDACTED]`).
- `docs/reference/api-docs/openweathermap.md` — full file. The One Call
  API 3.0 example response at L161-213 is the source of truth for the
  wire-shape Pydantic models. The §Authentication section at L11-28
  confirms `appid` query string. The §"Known issues / gotchas" section
  at L257-265 lists the One-Call-3.0 401 case (Q1 dispatch source),
  `pop` 0-1 (call 22), pressure/precip-units-ignore-`units=` (call 15
  conversion source), rain/snow-keys-may-be-absent (call 23-24).
- `docs/planning/briefs/phase-2-task-3b-3-forecast-brief.md` — third-
  forecast-provider structure pattern. NWS pre-AFD (single-endpoint-
  shape, multi-call) is less relevant to OWM than 3b-4 (single-call
  rich-coverage), but lead-direct remediation patterns apply.
- `docs/planning/briefs/phase-2-task-3b-4-forecast-brief.md` — first
  keyed provider; closest structural twin to OWM. Aeris's two-call
  shape vs OWM's one-call shape is the only material difference. Q1+Q2
  pattern (canonical-spec-operationalization at brief-draft time)
  inherited directly.
- `docs/decisions/INDEX.md` — pointer to all ADRs.

**ADRs to load before implementing:**

- ADR-006 (compliance — operator-managed API keys; OWM is the second
  keyed provider after Aeris; basic-tier conflation per Q1 falls under
  operator-managed compliance).
- ADR-007 (forecast providers — OWM is in the day-1 set; auth pattern
  per the table at line 67-73; line 81 §Per-module behavior is the
  basis for Q1 graceful-empty-bundle decision).
- ADR-008 (auth model — provider modules don't add user auth; OWM
  appid is a provider credential, not a user secret).
- ADR-010 (canonical data model — HourlyForecastPoint,
  DailyForecastPoint, ForecastDiscussion, ForecastBundle).
- ADR-011 (single-station — operator lat/lon comes from station
  metadata, not query param).
- ADR-017 (provider response caching — pluggable backend already
  wired; forecast TTL 30 min default; cache key shape).
- ADR-018 (URL-path versioning, RFC 9457 errors, ProviderProblem
  extension carrying providerId/domain/errorCode).
- ADR-019 (units handling — server passes weewx target_unit through;
  provider conversions at ingest. OWM's
  pressure-and-precip-don't-change-with-units is the conversion source
  for call 15).
- ADR-020 (time zone — UTC ISO-8601 Z on the wire; station-local for
  date-only fields. `epoch_to_utc_iso8601()` helper per call 10).
- ADR-027 (config — secrets in `secrets.env`; env-var naming
  convention in §3; **lead-call 14 + Q2 above** lock long-form
  `OPENWEATHERMAP` provider-scoped naming).
- ADR-029 (logging — INFO per-request access log; provider URL logged
  with redaction filter applied; `appid` redaction shipped in 3b-1 —
  no extension this round, but verify in test coverage).
- ADR-038 (provider module organization — five module
  responsibilities, shared infra split, capability declaration fields,
  canonical error taxonomy, testing pattern; **L1 paid-tier-max-
  surface from 3b-4 + Q1 graceful-empty-bundle apply**).

ADRs explicitly NOT in scope this round:

- ADR-013 (AQI — separate 3b round).
- ADR-015 (radar — separate 3b round).
- ADR-016 (alerts — handled via the alerts/nws.py module from 3b-1; an
  alerts/openweathermap.py module is a future round).
- ADR-040 (earthquakes — separate 3b round).

---

## Per-endpoint spec — `/forecast` for OWM provider

Same `/forecast` endpoint, new dispatch branch. OpenAPI shape unchanged
(line 186-213). Decision tree extended:

  1. `[forecast] provider = openweathermap`, env var
     `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID` unset
     → KeyInvalid at fetch time → 502 ProviderProblem KeyInvalid.
  2. `[forecast] provider = openweathermap`, env var set, `/data/3.0/
     onecall` returns 200 → normalize per canonical mapping → 200
     ForecastResponse with populated hourly + daily.
  3. `[forecast] provider = openweathermap`, env var set, `/data/3.0/
     onecall` returns 401 (basic-tier key) → graceful empty bundle per
     Q1 → 200 ForecastResponse with `hourly=[], daily=[],
     discussion=null, source="openweathermap"`.
  4. `[forecast] provider = openweathermap`, env var set, `/data/3.0/
     onecall` returns 429 → 503 ProviderProblem QuotaExhausted +
     `Retry-After` header (canonical taxonomy via ProviderHTTPClient,
     bare propagate).
  5. Network failure / 5xx after retries → 502 ProviderProblem
     TransientNetworkError.
  6. 400 / Pydantic validation failure → 502 ProviderProblem
     ProviderProtocolError.

---

## CAPABILITY declaration spec

```python
CAPABILITY = ProviderCapability(
    provider_id=PROVIDER_ID,                    # "openweathermap"
    domain=DOMAIN,                              # "forecast"
    supplied_canonical_fields=(
        # HourlyForecastPoint
        "validTime", "outTemp", "outHumidity", "windSpeed", "windDir",
        "windGust", "precipProbability", "precipAmount", "precipType",
        "cloudCover", "weatherCode", "weatherText",
        # DailyForecastPoint
        "validDate", "tempMax", "tempMin", "precipAmount",
        "precipProbabilityMax", "windSpeedMax", "windGustMax",
        "sunrise", "sunset", "uvIndexMax", "weatherCode", "weatherText",
        "narrative",
        # NB: ForecastDiscussion fields (headline, body, etc.) NOT supplied
        # — canonical §4.1.4 OWM column = all "—".  Bundle ships
        # discussion=None unconditionally (lead-call 33).
    ),
    geographic_coverage="global",
    auth_required=("appid",),
    default_poll_interval_seconds=DEFAULT_FORECAST_TTL_SECONDS,    # 1800
    operator_notes=(
        "OpenWeatherMap One Call 3.0 (paid 'One Call by Call' subscription "
        "required for /data/3.0/onecall). Basic-tier appid returns empty "
        "forecast bundle — bundle.hourly=[], bundle.daily=[] (Q1 user "
        "decision 2026-05-08; module dispatches on /data/3.0/onecall 401 "
        "to graceful empty rather than KeyInvalid 502). Coverage global "
        "per ADR-007 §Per-module behavior."
    ),
)
```

The L1 paid-tier-max-surface rule fires here for the entire hourly+daily
surface: CAPABILITY declares the One Call max-surface; runtime population
is conditional on the operator's tier. Auditor: this is the
capability-vs-runtime-fidelity nuance to call out if you see drift — the
user accepted the trade-off explicitly per Q1 + the 3b-4 L1 rule.

---

## Module file structure (target shape)

```
weewx_clearskies_api/providers/forecast/openweathermap.py
├── module docstring (5 responsibilities + cache + helpers + Q1 dispatch)
├── PROVIDER_ID = "openweathermap"
├── DOMAIN = "forecast"
├── OWM_BASE_URL = "https://api.openweathermap.org"
├── OWM_ONECALL_PATH = "/data/3.0/onecall"
├── DEFAULT_FORECAST_TTL_SECONDS = 1800
├── _API_VERSION = "0.1.0"
├── CAPABILITY = ProviderCapability(...)
├── _OWM_CODE_TO_PRECIP_TYPE: dict[int, str] (or range-based helper)
├── _logged_unknown_codes: set[int]
├── _logged_mixed_precip_codes: set[int]
├── Wire-shape Pydantic models (extras="ignore"):
│     _OWMWeatherEntry — id/main/description/icon
│     _OWMHourlyPeriod — dt/temp/humidity/wind_speed/wind_deg/wind_gust/
│                         pressure/dew_point/clouds/uvi/pop/visibility/
│                         weather/rain/snow
│     _OWMDailyPeriod — dt/sunrise/sunset/temp.max/temp.min/humidity/
│                        wind_speed/wind_deg/wind_gust/pressure/dew_point/
│                        clouds/uvi/pop/summary/weather/rain/snow
│     _OWMOneCallResponse — lat/lon/timezone/timezone_offset/hourly[]/daily[]
├── Helper functions:
│     _epoch_to_utc_iso8601(...)           # imported from _common/datetime_utils
│     _owm_validdate(epoch, tz_offset)     # local helper, station-local YYYY-MM-DD
│     _convert_owm_units(...)              # wind/pressure/precip conversions
│     _owm_weather_code_to_precip_type(...)# range-based lookup
│     _owm_hourly_precip_mm(...)           # rain.1h + snow.1h with absent-handling
│     _owm_daily_precip_mm(...)            # daily.rain + daily.snow with absent-handling
│     _safe_weather_text_daily(...)        # summary preferred, weather[0].description fallback
│     _build_cache_key(...)
│     _owm_to_hourly_point(...)
│     _owm_to_daily_point(...)
│     _owm_to_canonical_bundle(...)
├── _rate_limiter = RateLimiter(...)
└── fetch(*, lat, lon, target_unit, appid, http_client=None) -> ForecastBundle
```

---

## Process gates (round-close requirements)

The lead does NOT close the round until all of the following pass:

1. **api repo `origin/main` HEAD** advances past `ab3294a` with the new
   provider module + dispatch + settings + endpoint dispatch landed.
2. **meta repo `origin/master` HEAD** advances past `f4f4097` with a
   round-close commit (plan status update + lessons routing).
3. **Default tier:** ≥ 1056 + (this round's new unit tests) / 0 failed.
   Baseline 1056/29/0; new tests should add ~50-80 unit tests for OWM.
4. **Integration MariaDB:** ≥ 188 + (new OWM integration tests) /
   29 skipped / 0 failed.
5. **Integration SQLite:** ≥ 205 + (new OWM integration tests) /
   20 skipped / 0 failed.
6. **Redis tier (CLEARSKIES_CACHE_URL=redis://127.0.0.1:6380/0 +
   `"integration and redis"`):** all green; non-skip count includes the
   new OWM Redis-backend test (mirror Aeris's `test_aeris_redis_cache_*`
   pattern). **Brief gate: Redis MUST PASS not skip** — same as 3b-3 +
   3b-4.
7. **No live-network tests.** All tests use `respx` against recorded /
   synthetic fixtures.
8. **Provenance documented** in commit messages: which fields are
   captured-real vs synthetic-from-api-docs; cite the api-docs section.
9. **Auditor review** clean OR all findings remediated (lead-direct
   per surface-size rule, or remediation round if needed).
10. **Lessons triaged** at round close per CLAUDE.md "Capture lessons in
    the right place" routing rules. Decision-log narrative in
    `docs/planning/CLEAR-SKIES-PLAN.md`; rule-shaped lessons lift into
    `rules/clearskies-process.md`, `rules/coding.md`, or relevant
    `.claude/agents/<agent>.md`.

---

## Spawn-prompt content (lead briefs each teammate)

Each spawn prompt MUST restate (not trust agent-def auto-load alone):

- **Mid-flight SendMessage cadence** — no >4 min in active work without
  a `SendMessage` to the lead. Long-running actions (pytest, fixture
  capture) framed by ETA + result messages.
- **The "no >5 min in pure file-reading without a SendMessage" research-
  mode mitigation.** Even silent reading of the brief or canonical
  emits "still reading <area>" via SendMessage.
- **Commit early and often** — staged-but-uncommitted survives TaskStop;
  in-workdir-only does not. Per file landed: `git add` + `git commit -s`
  + `git push origin main` + SendMessage. Don't accumulate.
- **L2 "don't re-construct canonical exceptions"** — pre-empt the
  3b-4 F1 anti-pattern. OWM module makes BARE `client.get()` calls.
  The ONE narrow `try / except KeyInvalid` for the One-Call-401
  graceful path is intentional and documented per Q1; ALL OTHER call
  sites are bare. If api-dev finds itself writing
  `try: client.get(...) except KeyInvalid: raise KeyInvalid(...)`, STOP.
- **Tests verify the brief; brief is the authority.** STOP-and-ping the
  lead at any signature divergence between impl and tests, OR at any
  brief-vs-canonical mismatch the impl would silently reconcile.
- **Pull-then-pytest gate** — `git fetch origin main && git merge --ff-
  only origin/main` BEFORE the pre-submit pytest run. Default branch
  is `main`.
- **Synthetic-from-real fixture pattern** (test-author) — if no paid
  One Call 3.0 access, fixture from api-docs/openweathermap.md L161-213
  example. Sidecar marker REQUIRED. SendMessage to lead BEFORE submitting
  closeout naming the synthetic origin and which fields are simulated.

---

## Branching policy

No feature branches. Commit straight to default branch (`main` on api,
`master` on meta). DCO + Co-Authored-By trailer on every commit.

## Dev environment

- DILBERT (Windows) — edit-only.
- weather-dev LXD container at 192.168.2.113 on ratbert — pytest,
  integration runs.
- Sync: `scripts/sync-to-weather-dev.sh` after pushing.
- pytest never runs on DILBERT.

---

## Lead's running-state pointers (live during round)

- **Scratchpad:** `c:\tmp\3b-5-scratch.md` — append-as-you-go.
  Round-close: triage queued lessons per CLAUDE.md routing rules.
- **Spawn cadence:** api-dev + test-author parallel after brief sign-off;
  auditor after both submit + pytest is green on weather-dev.
- **Polling cadence:** every user-prompt boundary, lead checks
  `git log -20 origin/main` + `SendMessage` any silent teammate per the
  poll-don't-wait rule. Pre-empt the idle bug.

---

## Round close — after auditor's final review

1. Lead synthesizes auditor findings per the "Lead synthesizes auditor
   findings; doesn't forward" rule. Per-finding: accept (with specific
   remediation), push back, defer. Lead-direct remediation when surface
   is small (≲50 lines / ≲3 files).
2. Lessons triage per CLAUDE.md "Capture lessons in the right place" —
   route each lesson to its durable home (rules / agent defs /
   decision-log).
3. Plan-status commit on meta repo. Decision-log narrative covers what
   happened on this date; rule-shaped lessons lift into rules/agent
   files.
4. Update `docs/planning/CLEAR-SKIES-PLAN.md` to mark 3b-5 close + queue
   3b-6 (Wunderground forecast — F-future-redaction-extension fires
   there; partial-domain CAPABILITY exercise).
