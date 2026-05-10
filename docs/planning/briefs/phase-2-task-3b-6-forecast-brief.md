# Phase 2 task 3b round 6 brief — clearskies-api forecast domain (Weather Underground)

**Round identity.** Phase 2 task 3 sub-round 3b round 6. Sixth of 5+ expected
3b rounds (3b-1 alerts/NWS + shared `_common/`; 3b-2 forecast/Open-Meteo;
3b-3 forecast/NWS + AFD; 3b-4 forecast/Aeris; 3b-5 forecast/OpenWeatherMap;
**this round adds the Weather Underground forecast provider** — fifth and FINAL
concrete forecast provider in ADR-007's day-1 set; third keyed provider).
After 3b-6 the day-1 forecast set is complete; remaining 3b rounds (if any)
cover other domains — alerts/aeris, alerts/openweathermap, /aqi/*, /earthquakes,
/radar/*, /observations/*.

This round is **doubly novel**:

- **First PARTIAL-DOMAIN provider.** Canonical §4.1.2 Wunderground hourly column
  is all "—". Wunderground PWS API has NO hourly forecast on any plan tier;
  CAPABILITY categorically excludes hourly fields regardless of tier. This
  EXTENDS the 3b-4 L1 paid-tier-max-surface rule one level wider:
  3b-4 said "max-surface within a plan"; 3b-6 says "categorically excluded
  sub-shape regardless of plan."
- **First F13 redaction-filter extension.** F13 was logged in 3b-1 as a
  deferred future-redaction-extension slot for `apiKey=` query params. OWM's
  `appid=` was already redacted in 3b-1; Aeris's `client_id=` shipped in 3b-4.
  Wunderground's `apiKey=` query param is the next opportunity. The extension
  is one new pattern (`_APIKEY_RE`) in `logging/redaction_filter.py`,
  mirroring `_CLIENT_ID_RE`/`_APPID_RE` shape exactly, plus 3 unit tests.

**Single-deliverable round.** Shared infrastructure (HTTP wrapper with
`status_code`-bearing canonical exceptions, retry, error taxonomy, capability
registry, both cache backends, rate limiter, `to_utc_iso8601_from_offset` +
`epoch_to_utc_iso8601` datetime helpers) already lives. Forecast canonical
types (`HourlyForecastPoint`, `DailyForecastPoint`, `ForecastDiscussion`,
`ForecastBundle`, `ForecastResponse`) already live in `models/responses.py`.
The `/forecast` endpoint already lives at `endpoints/forecast.py` with four
dispatch branches (openmeteo, nws, aeris, openweathermap).

`ForecastSettings` already lives with NWS UA contact + Aeris credentials +
OWM appid. `config/settings.py` `ForecastSettings.validate()` already accepts
`"wunderground"` as a valid provider id (added in 3b-2 and carried forward).
This round adds:

1. **`weewx_clearskies_api/providers/forecast/wunderground.py`** — fifth
   concrete forecast provider per ADR-007 + ADR-038. Five module
   responsibilities; structural twin of `providers/forecast/openweathermap.py`
   (single-credential keyed provider; single-endpoint shape) but with two
   wrinkles: (a) two env vars (apiKey + PWS station ID per ADR-007 line 79),
   (b) PARTIAL-DOMAIN — daily-only, no hourly, no discussion.
   **One outbound call per cache miss** — `/v3/wx/forecast/daily/5day` with
   `geocode=<lat>,<lon>&format=json&units=<e|m|s>&apiKey=<key>`.
2. **One new row in `_common/dispatch.py`** —
   `("forecast", "wunderground") → providers.forecast.wunderground`.
3. **Two new fields on `ForecastSettings`** — `wunderground_api_key` and
   `wunderground_pws_station_id`, sourced from env vars
   `WEEWX_CLEARSKIES_WUNDERGROUND_API_KEY` and
   `WEEWX_CLEARSKIES_WUNDERGROUND_PWS_STATION_ID` per ADR-027 §3 + the 3b-4/3b-5
   long-form provider-scoped naming precedent.
4. **`wire_wunderground_credentials()` helper in `endpoints/forecast.py`**
   — mirror of `wire_aeris_credentials()` but two-credential.
   Plugs into the existing `wire_forecast_settings()` wrapper.
5. **`elif provider_id == "wunderground":` dispatch branch in
   `endpoints/forecast.py`** — passes lat/lon/target_unit + api_key +
   pws_station_id to `wunderground.fetch()`.
6. **One-line redaction-filter extension** in
   `weewx_clearskies_api/logging/redaction_filter.py` — add `_APIKEY_RE`
   query-param redaction pattern, register in `_PATTERNS`. Plus 3 unit tests.

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after
both submit and pytest is green on `weather-dev`.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` (clone of
`github.com/inguy24/weewx-clearskies-api`). **Default branch `main`** (verified
2026-05-08 against `git symbolic-ref refs/remotes/origin/HEAD`). Parallel-pull
command: `git fetch origin main && git merge --ff-only origin/main`. The
meta-repo (this `weather-belchertown/` workspace) is `master`.

**Pre-round HEADs verified 2026-05-09:**

- api repo: `9db163b` (3b-5 audit F1 fixup: clear appid AFTER stack wiring in endpoint test)
- meta repo: `bc0283d` (3b-5 close)
- weather-dev: `9db163b` (already up to date)
- DILBERT working tree: clean

**Pre-round pytest baseline (trusted from 3b-5 close, <24h ago):**

- Default tier: 1206 / 32 skipped / 0 failed
- Integration MariaDB: 205 / 32 skipped / 0 failed
- Integration SQLite: 212 / 25 skipped / 0 failed
- Redis tier (`CLEARSKIES_CACHE_URL=redis://127.0.0.1:6380/0` + `"integration and redis"`):
  10 / 0 / 0

---

## Scope — 1 provider module + plumbing + redaction-filter extension

| # | Unit | Notes |
|---|---|---|
| 1 | `weewx_clearskies_api/providers/forecast/wunderground.py` | New file. ONE outbound call per cache miss: `GET /v3/wx/forecast/daily/5day?geocode={lat},{lon}&format=json&units={e|m|s}&apiKey={key}`. Returns column-oriented arrays (5 elements at top level; daypart[0] arrays of 10 elements = 5 days × D/N). **PARTIAL-DOMAIN: hourly NOT supplied; discussion NOT supplied.** Bundle ships `hourly=[], discussion=None` unconditionally; only `daily` populates. CAPABILITY enumerates ONLY DailyForecastPoint fields Wunderground actually supplies (categorical exclusion, not tier-conditional). |
| 2 | `_common/dispatch.py` | Add `("forecast", "wunderground") → providers.forecast.wunderground` row. One import + one entry. |
| 3 | `config/settings.py` `ForecastSettings` | Add two fields: `wunderground_api_key: str \| None` from env var `WEEWX_CLEARSKIES_WUNDERGROUND_API_KEY`, and `wunderground_pws_station_id: str \| None` from env var `WEEWX_CLEARSKIES_WUNDERGROUND_PWS_STATION_ID`. Both populated at `__init__` (NOT from the `[forecast]` INI section — secrets per ADR-027 §3). PWS station ID isn't strictly a "secret" but is gated identifier; co-locating with the api_key keeps the operator's mental model simple ("Wunderground stuff lives in env vars"). |
| 4 | `endpoints/forecast.py` | Add `wire_wunderground_credentials(api_key, pws_station_id)` (mirror `wire_aeris_credentials`, but two args). Extend `wire_forecast_settings()` to also call it. Add `elif provider_id == "wunderground":` dispatch branch (mirror `openweathermap` branch L295-308). |
| 5 | `__main__.py` | **No change** — already calls `forecast.wire_forecast_settings(settings)`. |
| 6 | `logging/redaction_filter.py` | **Extension this round (F13 fires).** Add `_APIKEY_RE = re.compile(r"((?:^\|[?&])apiKey=)[^&\s\n\"']+", re.IGNORECASE)` mirroring `_CLIENT_ID_RE` shape exactly; register in `_PATTERNS` list with replacement `r"\g<1>" + _REDACTED`. **Three unit tests**: (a) URL with `?apiKey=ABC123` → `apiKey=[REDACTED]`; (b) URL with `&apiKey=XYZ` mid-querystring → redacted; (c) URL with `apiKey=NOPE` followed by another query param → only the apiKey value redacted, the next param's value preserved. |
| 7 | Recorded fixtures | `tests/fixtures/providers/wunderground/forecast_daily_5day.json` (full /v3/wx/forecast/daily/5day shape), `error_401_invalid_key.json` (apiKey invalid or PWS no longer active), `error_429_quota.json`. Sidecar `.md` documents capture date + lat/lon + tier captured against. **Synthetic-from-real if no PWS access** (per L3 rule) — fixture origin clearly marked. Wunderground PWS API requires both an apiKey AND an active PWS contributor account; if neither test-author nor lead has one, fixture is constructed from the api-docs example response at `docs/reference/api-docs/wunderground.md` L138-189 with sidecar `fixtures.md` documenting synthetic origin. |

**Out of scope this round (defer to later 3b rounds / Phase 3+ / Phase 4):**

- **Wunderground PWS observations.** `/v2/pws/observations/current` is canonical
  §4.1.1 territory (current observation slot); separate work, not part of
  `/forecast` endpoint. The Wunderground PWS_STATION_ID env var IS required
  for forecast-module fetch even though the forecast endpoint doesn't use it
  on the URL — the env var is the config-time gate per ADR-007 line 79
  (defense-in-depth: an apiKey without an active PWS station eventually 401s
  anyway).
- **Wunderground location services.** `/v3/location/...` endpoints (search,
  point, near) are outside forecast-domain scope.
- **Wunderground historical observations.** `/v2/pws/observations/all/...`,
  `/v2/pws/observations/hourly/...`, `/v2/pws/dailysummary/...`,
  `/v2/pws/history/...` — all outside `/forecast` scope; future archive-domain
  rounds may consume them.
- **Other forecast endpoint variants.** Wunderground exposes `/v3/wx/forecast/
  daily/3day`, `/5day`, `/7day`, `/10day`, `/15day` (availability depends on
  the plan per api-docs L191-194). v0.1 uses `/5day` only; matches PWS-tier
  default and the api-docs example. Future round can add `/10day`/`/15day`
  for commercial-tier deployments if a real customer asks.
- **Wunderground hourly forecast.** Categorically NOT supplied by the PWS API
  on any tier (api-docs §"Known issues / gotchas" L240: "No alerts endpoint is
  exposed on this gated PWS API tier"). The api-docs lists `/v3/wx/forecast/
  hourly/...` for commercial enterprise tiers, not PWS-gated tiers. Bundle
  ships `hourly=[]` unconditionally.
- **Wunderground forecast discussion.** Canonical §4.1.4 Wunderground column =
  all "—". Bundle ships `discussion=None` unconditionally.
- **Wunderground alerts.** Per api-docs L240, no alerts endpoint on PWS API
  tier. Alerts is a separate domain (3b-future-alerts).
- **Operator overrides for forecast TTL or rate-limit.** This round uses
  ADR-017's default 30 min (matches the other four forecast providers). The
  Wunderground PWS-tier quota of 1500/day with 30-min TTL → ≈ 48 calls/day,
  30× under quota.
- **Multi-location.** ADR-011 single-station.
- **Setup-wizard region-based provider suggestion.** ADR-027 wizard ships
  in Phase 4.

---

## Lead-resolved calls (no user sign-off needed — ADRs and contracts settle these)

The "Brief questions audit themselves before draft" rule
(`rules/clearskies-process.md`) requires every "open question" to be audited
against the ADRs first. Audit performed for this round (scratchpad
`c:\tmp\3b-6-scratch.md` brief-draft questions audit section). **NO genuinely-
open questions surfaced for user sign-off this round.** Every anticipated
question and additional draft-time question resolved against ADRs / canonical /
3b-4-3b-5 precedent. Numbered for reference, not for sign-off.

### Inherited from 3b rounds 1-5 (no change, no re-audit needed)

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
   `wunderground` automatically when `[forecast] provider = wunderground`.

4. **Both cache backends already live.** ADR-017 + 3b-1's `MemoryCache` +
   `RedisCache`. Forecast/wunderground consumes `get_cache()` like the
   other modules.

5. **No live-network tests in CI.** ADR-038 §Testing pattern. Recorded /
   synthetic fixtures + `respx` for everything.

6. **Source field when no provider configured = literal `"none"`.**
   `endpoints/forecast.py` already does this; no change.

7. **`precipType` derivation rule (forecast-domain, all providers).** Use
   §3.3 enum values literally — `"rain"` / `"snow"` / `"sleet"` /
   `"freezing-rain"` / `"hail"` / `"none"`. **Do NOT flatten freezing variants
   to `"rain"`.** Locked in canonical-data-model §4.1.2 from 3b-2 audit (F2).
   Wunderground-specific lookup table operationalizing this rule is **call 14** below.

8. **Slice-after-cache pattern.** `endpoints/forecast.py` already slices the
   bundle's `hourly` and `daily` arrays after cache lookup. Wunderground
   /5day provides 5 daily entries; `hourly=[]` always (PARTIAL-DOMAIN).
   ForecastQueryParams' 16-day cap clips identically; nothing new at the
   endpoint level.

9. **Dispatch on exception state via attributes, not message strings.** Per
   `rules/coding.md` §3 (added 2026-05-08 from 3b-3 F2). Wunderground
   module uses `exc.status_code` attribute access only. **No `"X" in str(exc)`
   patterns.**

10. **Reuse `providers/_common/datetime_utils.py` for ISO timestamps.** Both
    `to_utc_iso8601_from_offset` and `epoch_to_utc_iso8601` already live.
    Wunderground's `validTimeUtc`/`sunriseTimeUtc`/`sunsetTimeUtc` are Unix
    epoch seconds → use `epoch_to_utc_iso8601`. Wunderground's
    `validTimeLocal` (date-extraction for `validDate`) does NOT need either
    helper — `.split("T")[0]` extracts the date portion directly (no time-zone
    conversion needed because validTimeLocal already carries the station-local
    offset, and we want the local date). **No new datetime helper required**
    (per `rules/coding.md` §3 DRY — existing helpers cover both shapes).

11. **Don't re-construct canonical exceptions you've already received.** Per
    the 3b-4 L2 carry-forward in `.claude/agents/clearskies-api-dev.md`.
    Wunderground module makes **bare `client.get()` calls** and lets canonical
    exceptions propagate. **No `try / except <CanonicalException>:
    raise <CanonicalException>(...) from exc` patterns.** Unlike OWM's
    Q1 narrow-wrap-for-graceful-empty-bundle (3b-5), Wunderground has no
    parallel here — there's no equivalent to the OWM basic-tier 401
    distinction. A 401 from Wunderground means the apiKey is invalid OR the
    PWS is no longer active; either way the operator's recovery action is
    "verify PWS at wunderground.com/member/api-keys." We surface that as
    standard `KeyInvalid` 502 ProviderProblem.

12. **Synthetic-from-real fixture pattern when paid-tier provider access is
    unavailable.** Per the 3b-4 L3 carry-forward in `.claude/agents/
    clearskies-test-author.md`. For Wunderground, the gating credential is
    "active PWS contributor" — far stricter than Aeris (free trial available)
    or OWM (free tier available). If neither test-author nor lead has an
    active PWS, the fixture is constructed from `docs/reference/api-docs/
    wunderground.md` L138-189 example response (the 5-day daily forecast
    example IS the literal wire shape the module parses). Sidecar `.md`
    documents synthetic origin clearly: "constructed from
    api-docs/wunderground.md L138-189 example response — fields mirrored,
    not captured live." **Do NOT skip the daily-forecast code path because
    the fixture is missing.** test-author SendMessages the lead BEFORE
    submitting closeout naming the synthetic origin and which fields are
    simulated.

### Wunderground-specific (this round)

13. **One outbound call per cache miss.** Wunderground `/v3/wx/forecast/
    daily/5day` workflow per `docs/reference/api-docs/wunderground.md` §"Daily
    forecast":
    1. `GET /v3/wx/forecast/daily/5day?geocode={lat},{lon}&format=json&units={e|m|s}&apiKey={key}&language=en-US`
       → returns column-oriented arrays at top level (5 elements, one per day)
       and `daypart[0]` array of 10 elements (5 days × 2 dayparts: D/N).

    The post-normalization `ForecastBundle` is cached for 30 min (ADR-017).
    Single cache key per `(station, target_unit)`. Cache stores
    `model_dump(mode="json")`; reconstructed via `model_validate()`.

    **Past-period null-handling.** Per api-docs L191: "Past-period slots may
    be null." If a request comes in late afternoon, `daypart[0]` slot 0
    ("Today") may have null fields (already passed). Module emits the day
    regardless (top-level fields like `temperatureMax[0]`, `validTimeLocal[0]`
    stay populated); daypart-derived fields (`precipChance[0]`, `windSpeed[0]`,
    `uvIndex[0]`) emit as None per the canonical-nullable contract. See
    lead-call 17 for the daypart-index alignment rule.

14. **Wunderground auth: `apiKey` query param + PWS station ID gate.** Per
    ADR-007 line 73 + line 79 + wunderground.md §Authentication.

    - `apiKey` is the request credential (query param on every request).
      Sourced from env var `WEEWX_CLEARSKIES_WUNDERGROUND_API_KEY`.
    - `WUNDERGROUND_PWS_STATION_ID` is the **config-time gate** required by
      ADR-007 line 79 ("explicit error message at config time if
      WUNDERGROUND_PWS_STATION_ID is unset, pointing to the PWS registration
      requirement"). Sourced from env var
      `WEEWX_CLEARSKIES_WUNDERGROUND_PWS_STATION_ID`.

    The forecast endpoint URL itself uses `geocode=<lat>,<lon>` from station
    metadata — the PWS station ID is NOT in the URL. So why require it at
    fetch time? **Defense-in-depth:** Wunderground apiKeys are issued only
    to active PWS contributors; an apiKey without a corresponding active PWS
    will eventually 401 anyway. Requiring both env vars ensures the
    operator's mental model matches the gating reality.

    **Module wiring.** `wire_wunderground_credentials(api_key,
    pws_station_id)` reads both env vars at startup (in
    `endpoints/forecast.py`, mirror of `wire_aeris_credentials()` but
    two-arg); module-level `_wunderground_api_key` and
    `_wunderground_pws_station_id` are passed to `wunderground.fetch()` from
    the dispatch branch.

    **Missing-credential behavior at fetch time.** If the operator sets
    `[forecast] provider = wunderground` but does NOT set BOTH env vars, the
    module raises `KeyInvalid("Wunderground credentials missing — set
    WEEWX_CLEARSKIES_WUNDERGROUND_API_KEY and WEEWX_CLEARSKIES_WUNDERGROUND_
    PWS_STATION_ID")` on the first request. Translated to 502 ProviderProblem
    with `errorCode="KeyInvalid"`. Same loud-failure posture as the 3b-4
    Aeris missing-credential branch and 3b-5 OWM missing-appid branch.
    **Do NOT silently disable the module at startup** — the operator's
    intent (`provider = wunderground`) is unambiguous.

    **ADR-007 line 79 "config time" interpretation.** ADR-007 says "config
    time" loud failure, but the 3b-4/3b-5 precedent operationalizes this as
    "loud failure at first use" (fetch-time `KeyInvalid`) rather than
    "refuse to start the service." This round follows the precedent;
    document the interpretation in the impl docstring + commit body.

    **Long-form provider-scoped naming** matches the 3b-4 (Aeris) + 3b-5
    (OWM) precedent. No domain prefix; no abbreviation. Inline docstring
    notes the deviation from ADR-027 §3 literal schema (which prescribes
    `<DOMAIN>_<PROVIDER>_<FIELD>`).

15. **Wunderground unit handling: `units` query param map.** Per ADR-019
    §Decision (server passes weewx target_unit through; provider conversions
    at ingest). Wunderground accepts `units=e|m|s|h`:

    | target_unit | `units` query param | Native field shape |
    |---|---|---|
    | `US`       | `e` (English/imperial) | °F, mph, in |
    | `METRIC`   | `m` (Metric SI variant) | °C, km/h, mm |
    | `METRICWX` | `s` (Pure SI) | °C, m/s, mm |

    Wunderground's `units=s` (Pure SI) gives m/s natively, so METRICWX needs
    NO post-conversion. (Contrast with OWM where `units=metric` gives m/s
    and METRIC needs km/h post-conversion — Wunderground's `units=m` is
    already km/h, so METRIC also needs no post-conversion.) **No
    `_convert_wunderground_units()` helper required.** Module passes
    response field values through directly per the `units` query param.

    Document the units mapping in the impl docstring + commit body.

16. **`weatherCode` extraction = pass-through `str(daypart[0].iconCode[i])`.**
    Canonical §4.1.3 Wunderground column: `daypart[0].iconCode`. Format is
    integer (e.g., `28` = "mostly cloudy"). Module passes through as the
    canonical `weatherCode` string after `str()` conversion. Dashboard maps to
    icon. Same opaque-pass-through posture as Aeris's `weatherPrimaryCoded`
    and OWM's integer-id-stringified codes.

    **Daypart index alignment** — top-level slot `i` maps to dayparts
    `[2*i, 2*i+1]` (Day, Night). Daily canonical fields use `daypart[0]
    [2*i]` (Day period) for daytime values per canonical §4.1.3 mapping
    note. Past-period slots may be null; canonical-nullable applies.

17. **`precipType` derivation from Wunderground daypart precipType array.**
    Per the forecast-domain rule (call 7), use canonical §3.3 enum literally.
    Wunderground returns one of `"rain"`/`"snow"`/`"precip"`/`"ice"` (or None)
    per daypart slot. Mapping:

    - `"rain"` → `"rain"`
    - `"snow"` → `"snow"`
    - `"precip"` → `"rain"` (mixed/general — defaults to rain class when
      ambiguous; matches NWS `mix`/`rain_snow` and Aeris `RS`/`WM`/`SI` and
      OWM 615/616 mappings; log DEBUG once per encounter)
    - `"ice"` → `"freezing-rain"` (ice on the ground — freezing-rain is the
      more general ice category in canonical §3.3; sleet is more specific to
      pellets and Wunderground's "ice" doesn't disambiguate)
    - Other / null → `None` (log DEBUG once on first encounter of an unknown
      string)

    Helper `_wu_precip_type_to_canonical(value: str | None) -> str | None`:
    string lookup; unknown → `None`; "precip"/"ice" log DEBUG once.

18. **CAPABILITY declares the daily-only surface — applies the L1 PARTIAL-DOMAIN
    extension.** Per `rules/clearskies-process.md` "Provider CAPABILITY
    declares paid-tier maximum supply set; runtime population is conditional"
    — but extended one level: Wunderground PWS API has NO hourly forecast
    on any tier (categorically excluded sub-shape, not max-surface-tier-
    conditional), and NO discussion product (canonical §4.1.4 column = all
    "—"). CAPABILITY enumerates ONLY DailyForecastPoint fields Wunderground
    actually supplies; hourly fields are NOT in `supplied_canonical_fields`,
    discussion fields (`headline`, `body`, etc.) are NOT in
    `supplied_canonical_fields`.

    This applies the L1 rule wider than 3b-4 (one optional discussion field)
    and 3b-5 (entire hourly+daily surface tier-conditional) — 3b-6 is the
    first PROVIDER WHERE A WHOLE CANONICAL SUB-SHAPE IS CATEGORICALLY EXCLUDED.

    **CAPABILITY.supplied_canonical_fields** (final list, daily only):

    ```
    # DailyForecastPoint fields supplied by Wunderground /5day
    "validDate", "tempMax", "tempMin", "precipAmount",
    "precipProbabilityMax", "windSpeedMax",
    "sunrise", "sunset", "uvIndexMax", "weatherCode", "weatherText",
    "narrative",
    # NB: HourlyForecastPoint fields NOT supplied — Wunderground PWS API
    # has no hourly forecast on any tier (canonical §4.1.2 column = all "—").
    # NB: ForecastDiscussion fields NOT supplied — Wunderground PWS API
    # has no discussion product (canonical §4.1.4 column = all "—").
    # NB: windGustMax NOT supplied — canonical §4.1.3 Wunderground column = "—"
    # for windGustMax.
    ```

    **operator_notes:** "Weather Underground PWS API (Personal Weather Station
    contributor tier). apiKey gated to active PWS owners — see api-docs/
    wunderground.md §Authentication. Forecast: daily-only (no hourly, no
    discussion). 5-day forecast horizon. apiKey OR PWS-no-longer-active
    returns 401 → bundle.daily=[] via standard KeyInvalid 502 propagation."

19. **`weatherText` extraction.** Daily: `daypart[0].wxPhraseShort[2*i]`
    (Day period of day i, short phrase). Canonical §4.1.3 Wunderground
    column: `daypart[0].wxPhraseShort`. When the slot is null (past-period),
    `weatherText=None`.

20. **`narrative` (DailyForecastPoint).** Top-level `narrative[i]` array per
    canonical §4.1.3 Wunderground column. Note: NOT `daypart[0].narrative`
    (which is per-daypart). When the top-level slot is null (rare; possible
    for past-period or paid-tier-only field), `narrative=None`.

21. **`precipProbabilityMax`.** `daypart[0].precipChance[2*i]` (Day period
    of day i). Wunderground's `precipChance` is already in percent (0-100),
    matching canonical `precipProbabilityMax` (0-100 percent). No
    multiplication needed (contrast with OWM's `pop * 100`).

22. **`precipAmount` (daily).** Top-level `qpf[i]` array per canonical
    §4.1.3 Wunderground column. Wunderground's `qpf` is already in the
    target_unit's precip unit (in for `units=e`, mm for `units=m|s`) so
    no post-conversion needed.

23. **`windSpeedMax` (daily).** `daypart[0].windSpeed[2*i]` (Day period of
    day i). Wunderground's daypart windSpeed is in the target_unit's wind
    unit (mph for `units=e`, km/h for `units=m`, m/s for `units=s`) — no
    post-conversion needed.

24. **`windGustMax` (daily) — NOT SUPPLIED.** Canonical §4.1.3 Wunderground
    column = "—" for windGustMax. Field is `None` on every Wunderground
    DailyForecastPoint. CAPABILITY excludes it.

25. **`sunrise` / `sunset` (daily).** Top-level `sunriseTimeUtc[i]` and
    `sunsetTimeUtc[i]` per canonical §4.1.3 Wunderground column. Both
    arrays carry epoch UTC seconds; convert via `epoch_to_utc_iso8601()`
    from `_common/datetime_utils.py`. When the slot is null, field is None.

    **Note on api-docs example.** The api-docs example response at L138-189
    shows only `sunriseTimeLocal`/`sunsetTimeLocal` (truncated). Community
    references confirm both `sunriseTimeUtc`/`sunsetTimeUtc` and `Local`
    forms exist in real PWS-tier responses. If a synthetic-from-api-docs
    fixture lacks the Utc form, the field is `None` for that fixture (per
    canonical §3.4 sunrise/sunset are nullable). When a real paid-tier
    capture becomes available in a future round, verify field is present;
    if not, fall back to `Local→Utc` conversion using the offset embedded
    in the Local string (e.g., `"2026-04-30T06:00:00-0700"` → parse with
    `datetime.fromisoformat` → `astimezone(UTC)` → ISO Z form). Document
    this future-affordance in the impl docstring + commit body.

26. **`tempMax` / `tempMin` (daily).** Top-level `temperatureMax[i]` and
    `temperatureMin[i]` per canonical §4.1.3 Wunderground column.
    Already in target_unit's temperature unit per `units=` query param;
    no conversion.

27. **`uvIndexMax` (daily).** `daypart[0].uvIndex[2*i]` (Day period of day
    i) per canonical §4.1.3 Wunderground column. Wunderground's `uvIndex`
    is the already-in-canonical-shape numeric UV index. When slot is
    null, field is None.

28. **`validDate` (DailyForecastPoint).** Top-level `validTimeLocal[i]` →
    `.split("T")[0]` extracts the date portion (YYYY-MM-DD). Per canonical
    §3.4 (validDate = station-local YYYY-MM-DD). Wunderground's
    `validTimeLocal` already carries the station-local time-with-offset
    (e.g., `"2026-04-30T07:00:00-0700"`); the date portion is already the
    station-local date. No date helper or timezone arithmetic needed.

    Helper `_wu_validdate_from_local(s: str) -> str`: returns
    `s.split("T")[0]`. Defensive: if `s` lacks `"T"`, raise
    `ProviderProtocolError` (provider schema change).

29. **Geographic coverage: trust Wunderground's authoritative answer.**
    ADR-007 + wunderground.md says coverage follows TWC's place network.
    The module does NOT carry a client-side geographic gate. CAPABILITY
    `geographic_coverage="global"`. Posture matches Aeris + OWM.

30. **Rate limiter for Wunderground.** Per ADR-038 §3 + 3b-3 F4 lesson on
    per-call acquire. Wunderground published quota: **1500 calls/day,
    30 calls/minute** for PWS-contributor keys (api-docs §"Rate limits"
    L213-215).

    With cache TTL = 30 min, an operator hits Wunderground ~48 times/day —
    well within 1500/day. Configure
    `RateLimiter("wunderground-forecast", max_calls=5,
    window_seconds=1)` as a "be polite" guard matching the other four
    forecast providers — covers the per-second cap and well below
    Wunderground's per-minute floor (30/min = 0.5/s; we cap at 5/s burst
    which is fine since we make ≈48 calls/day spread out, not bursts).
    **Per-call acquire** before the single outbound call per cache miss.

31. **Cache key shape.** `SHA-256(json({"provider_id": "wunderground",
    "endpoint": "forecast_bundle", "params": {"lat4": "...", "lon4":
    "...", "target_unit": "..."}}, sort_keys=True))`. The `"endpoint"`
    string is `"forecast_bundle"` (logical name; mirrors the Aeris/OWM
    convention). PWS station ID is NOT in the cache key — it's a
    config-time gate, not a per-request input.

32. **`extras` field on canonical Wunderground daily points.** Wunderground
    surfaces fields that don't map 1:1 to canonical (`moonPhase`,
    `moonPhaseCode`, `moonPhaseDay`, `moonriseTimeLocal`,
    `moonsetTimeLocal`, `qpfSnow`, `expirationTimeUtc`, `wxPhraseLong` etc.).
    Per canonical §3.3 + §3.4, `extras: object` is provider-specific; v0.1
    treatment: **leave `extras: {}` empty for Wunderground this round.**
    Same as Aeris (3b-4 lead-call 24) and OWM (3b-5 lead-call 32). Future
    round may add `moonPhase` if/when canonical adds an "almanac" field
    (it has its own /almanac endpoint, but that's not in scope here).

33. **`language` query param.** Wunderground accepts `language=en-US` (and
    other locales). v0.1 hard-codes `"en-US"`. Operator's i18n locale is
    handled at the dashboard layer per ADR-021; api passes English forecast
    text through and the dashboard's i18n catalog handles localization of
    canonical UI strings. Future enhancement may pass `language` based on
    a server-side config; not v0.1 scope.

34. **F13 redaction-filter extension scope.** ONE new pattern in
    `weewx_clearskies_api/logging/redaction_filter.py`:

    ```python
    # Match apiKey= query parameter value (Wunderground PWS API)
    # Pattern mirrors _APPID_RE / _CLIENT_ID_RE shape; both are query-param
    # credentials. Fires this round (3b-6) because Wunderground is the third
    # keyed provider on this project.
    _APIKEY_RE = re.compile(
        r"((?:^|[?&])apiKey=)[^&\s\n\"']+",
        re.IGNORECASE,
    )
    ```

    Register in `_PATTERNS` list with replacement `r"\g<1>" + _REDACTED`,
    placed alongside `_APPID_RE` and `_CLIENT_ID_RE`. The case-insensitive
    flag covers `apikey=` and `APIKEY=` variants.

    **Three unit tests** in `tests/unit/test_redaction_filter.py` (or
    wherever the existing redaction tests live):

    - `test_redaction_apikey_query_param_at_start` — URL with `?apiKey=ABC123`
      → output contains `apiKey=[REDACTED]`, NOT the literal value.
    - `test_redaction_apikey_query_param_mid_string` — URL with
      `?stationId=K1&apiKey=XYZ789` → output redacts only the apiKey value;
      preserves the stationId value.
    - `test_redaction_apikey_followed_by_another_param` — URL with
      `?apiKey=NOPE&format=json` → output redacts the apiKey value but
      preserves `format=json` intact.

    **Don't speculate-generalize.** Don't add patterns for `api_key=`,
    `ApiKey=`, `X-API-Key:` header form, or other potential variants —
    this round adds ONE pattern for the ONE shape Wunderground actually
    uses. Future rounds add more patterns when more shapes appear.
    Per `rules/coding.md` "Don't add features beyond what the task
    requires" + "Simple means simple."

---

## Brief-draft sign-off — NO USER QUESTIONS THIS ROUND

The "Brief questions audit themselves before draft" rule says drop questions
the ADR settles. Audit performed against ADRs (ADR-007, ADR-017, ADR-019,
ADR-027, ADR-038), canonical-data-model (§3.3, §3.4, §3.5, §3.10, §4.1.2,
§4.1.3, §4.1.4), and the 3b-4/3b-5 brief precedents.

**Result: every anticipated open question was settled by ADRs / canonical /
precedent.** Brief lands fully lead-resolved. No user sign-off required to
unblock spawn.

For transparency, the audit walkthrough lives in `c:\tmp\3b-6-scratch.md`
"Brief-draft questions audit" section — eleven anticipated questions, all
dropped to lead-resolved. Notable:

- **PWS station ID requirement** — settled by ADR-007 line 79 + 3b-4/3b-5
  fetch-time KeyInvalid precedent.
- **Long-form provider-scoped env var naming** — settled by 3b-4 Q1 + 3b-5
  Q2 user decisions; same precedent applies.
- **TTL** — settled by ADR-017 default 30 min.
- **Endpoint variant `/5day`** — settled by api-docs L191 evidence (PWS-tier
  default) + L1 max-surface rule (CAPABILITY declares what `/5day` supplies).
- **Discussion** — settled by canonical §4.1.4 Wunderground column = all "—".
- **Hourly** — settled by canonical §4.1.2 Wunderground column = all "—" +
  api-docs PWS-tier "no hourly forecast" gotcha.
- **F13 scope** — settled by precedent (one pattern per known auth shape;
  matches `_APPID_RE`/`_CLIENT_ID_RE`).

If you (the user) review this brief and find a question that SHOULD have
been surfaced, that's signal to push back before spawn. The point of the
audit isn't to skip user review of decisions; it's to skip *manufactured*
questions. A real question I missed is still a question — flag it and we'll
fold it in before spawning.

---

## Hard reading list (once per session)

**Both api-dev and test-author:**

- `CLAUDE.md` — domain routing + always-applicable rules (lessons-capture,
  memory-disabled, `.claude/` private, plain-English, scope discipline).
- `rules/clearskies-process.md` — full file. **Carry-forwards (NEW from
  3b-4 close 2026-05-08, extended through 3b-5):**
    - "Provider CAPABILITY declares paid-tier maximum supply set; runtime
      population is conditional" — lead-call 18 above EXTENDS this to
      PARTIAL-DOMAIN: CAPABILITY excludes hourly entirely (categorically,
      not tier-conditional).
  Carry-forward (from 3b-3 close): live-scratchpad rule
  (`c:\tmp\3b-6-scratch.md` is the lead's scratchpad); lead-direct
  remediation when surface ≲50 lines / ≲3 files; canonical-spec-
  operationalization is a brief-draft question (no opens this round but
  the audit still happened); `git commit -F c:\tmp\<task>-msg.txt` for
  multi-line PowerShell commit messages.
  Carry-forward (from prior rounds): poll-don't-wait at user-prompt
  boundaries; brief-questions-audit at draft; brief-vs-canonical
  cross-check at draft; tests verify the brief; ADR conflicts → STOP;
  round briefs land in the project, not in tmp; `.claude/` stays
  private; lead synthesizes auditor findings, doesn't forward.
- `rules/coding.md` — full file. **§3 carry-forwards** (from 3b-3 + 3b-5):
  "Dispatch on exception state via attributes, not message strings" —
  lead-call 9 above. Wunderground module dispatches on `exc.status_code`,
  never on `str(exc)`. §3 "search before writing a new helper" — verified
  no new datetime helper needed; existing `epoch_to_utc_iso8601` covers
  Utc-epoch fields and `.split("T")[0]` covers Local-date extraction
  (lead-call 10). §3: catch specific exceptions, never `except Exception:`.
  §1 Pydantic + Depends pattern (already in `endpoints/forecast.py`),
  IPv4/IPv6-agnostic networking, no dangerous functions, no hardcoded
  secrets (Wunderground apiKey + PWS station ID in env vars per ADR-027 §3).
  §5 (a11y) is non-applicable — backend round.
- **`.claude/agents/clearskies-api-dev.md`** — agent definition.
  **Carry-forward (NEW from 3b-4 close):** "Don't re-construct canonical
  exceptions you've already received" (L2). Wunderground module makes
  BARE `client.get()` calls; let canonical exceptions propagate. There's
  NO Q1-style narrow-wrap this round (unlike OWM 3b-5) — Wunderground
  401 means "key invalid OR PWS no longer active," surface as standard
  KeyInvalid 502.
  Carry-forward: tests verify the brief; brief-vs-canonical STOP-and-
  ping; **commit early and often**; mid-flight SendMessage cadence (no
  >4 min silent); commit messages document non-obvious provenance.
- **`.claude/agents/clearskies-test-author.md`** — agent definition.
  **Carry-forward (NEW from 3b-4 close):** "Synthetic-from-real fixture
  pattern when paid-tier provider access is unavailable" (L3). For
  Wunderground, the gating credential is "active PWS contributor" —
  far stricter than Aeris (free trial) or OWM (free tier). Synthetic-
  from-api-docs pattern applies; sidecar `.md` documents synthetic
  origin. Brief-gate honesty (no silent skips on cache-tier or DB-tier
  coverage); commit early and often.
- **`.claude/agents/clearskies-auditor.md`** — agent definition.
- `docs/contracts/openapi-v1.yaml`:
  - `/forecast` at line 186 (no change; Wunderground reuses the existing endpoint).
  - `HourlyForecastPoint` at line 1016 (Wunderground does NOT supply any of
    these — CAPABILITY excludes the entire surface).
  - `DailyForecastPoint` at line 1035 (Wunderground supplies a subset; see
    lead-call 18 for the exact list).
  - `ForecastDiscussion` at line 1058 (Wunderground bundle ships
    `discussion=null`; structural reference only).
  - `ForecastBundle` at line 1073 (`discussion: oneOf null or
    ForecastDiscussion`; not in `required`).
  - `ForecastResponse` at line 1562.
  - `ProviderProblem` at line 863, `ProviderError` 502 response at line 799,
    `ProviderUnavailable` 503 response at line 807,
    `CapabilityDeclaration` at line 1432.
- `docs/contracts/canonical-data-model.md`:
  - §3.3 (HourlyForecastPoint per-field enumeration — for context; not
    populated for Wunderground).
  - §3.4 (DailyForecastPoint per-field enumeration + unit groups).
  - §3.5 (ForecastDiscussion — for context; bundle ships null).
  - §3.10 (ForecastBundle container — `null` discussion is canonical-
    shape-conformant).
  - §4.1.2 (Hourly forecast — Wunderground column = all "—"; confirms
    PARTIAL-DOMAIN nature).
  - §4.1.3 (Daily forecast — Wunderground column for the per-field mapping).
  - §4.1.4 (Forecast discussion — Wunderground column = all "—"; bundle
    ships null).
- `docs/contracts/security-baseline.md`:
  - §3.4 (secrets — fires this round. Wunderground apiKey + PWS station ID
    from env vars; never inline in source).
  - §3.5 (input validation — Pydantic models for the wire shape inside
    the normalizer per ADR-038).
  - §3.6 (logging — provider URL logged at INFO with `apiKey` query
    param present; redaction filter strips before formatter emits via
    the new `_APIKEY_RE` pattern. Test coverage: a logged URL containing
    `?apiKey=ABC123` redacts to `[REDACTED]`).
- `docs/reference/api-docs/wunderground.md` — full file. The /5day daily
  forecast example response at L138-189 is the source of truth for the
  wire-shape Pydantic models. The §Authentication section at L17-39
  confirms `apiKey` query string. The §"Known issues / gotchas" section
  at L231-241 lists: PWS-only gating (call 14 source), no hourly forecast
  on PWS tier (call 18 source), `precipChance` is percent (call 21 source),
  no alerts endpoint on PWS tier (out-of-scope confirmation).
- `docs/planning/briefs/phase-2-task-3b-5-forecast-brief.md` — fourth-
  forecast-provider brief; closest structural twin (single-call keyed
  provider). Adapt for Wunderground's two-credential gate and PARTIAL-
  DOMAIN nature.
- `docs/decisions/INDEX.md` — pointer to all ADRs.

**ADRs to load before implementing:**

- ADR-006 (compliance — operator-managed API keys; Wunderground is the third
  keyed provider after Aeris + OWM).
- ADR-007 (forecast providers — Wunderground is in the day-1 set; auth pattern
  per the table at line 67-73; line 79 §Per-module behavior is the basis for
  the PWS station ID config-time gate per call 14).
- ADR-008 (auth model — provider modules don't add user auth; Wunderground
  apiKey is a provider credential, not a user secret).
- ADR-010 (canonical data model — DailyForecastPoint, ForecastBundle).
- ADR-011 (single-station — operator lat/lon comes from station
  metadata, not query param).
- ADR-017 (provider response caching — pluggable backend already
  wired; forecast TTL 30 min default; cache key shape).
- ADR-018 (URL-path versioning, RFC 9457 errors, ProviderProblem
  extension carrying providerId/domain/errorCode).
- ADR-019 (units handling — server passes weewx target_unit through;
  provider conversions at ingest. Wunderground `units=e|m|s` covers
  all three target_units natively per call 15).
- ADR-020 (time zone — UTC ISO-8601 Z on the wire; station-local for
  date-only fields. `epoch_to_utc_iso8601()` helper for sunrise/sunset
  per call 25).
- ADR-027 (config — secrets in `secrets.env`; env-var naming
  convention in §3; **lead-call 14 + 3b-4/3b-5 precedent** lock
  long-form `WUNDERGROUND` provider-scoped naming).
- ADR-029 (logging — INFO per-request access log; provider URL logged
  with redaction filter applied; **`apiKey` redaction extension fires
  this round** per call 34).
- ADR-038 (provider module organization — five module
  responsibilities, shared infra split, capability declaration fields,
  canonical error taxonomy, testing pattern; **L1 PARTIAL-DOMAIN
  extension applies — see call 18**).

ADRs explicitly NOT in scope this round:

- ADR-013 (AQI — separate 3b round).
- ADR-015 (radar — separate 3b round).
- ADR-016 (alerts — handled via the alerts/nws.py module from 3b-1; an
  alerts/aeris.py or alerts/openweathermap.py module is a future round).
- ADR-040 (earthquakes — separate 3b round).

---

## Per-endpoint spec — `/forecast` for Wunderground provider

Same `/forecast` endpoint, new dispatch branch. OpenAPI shape unchanged
(line 186-213). Decision tree extended:

  1. `[forecast] provider = wunderground`, env var
     `WEEWX_CLEARSKIES_WUNDERGROUND_API_KEY` OR
     `WEEWX_CLEARSKIES_WUNDERGROUND_PWS_STATION_ID` unset
     → KeyInvalid at fetch time → 502 ProviderProblem KeyInvalid.
  2. `[forecast] provider = wunderground`, both env vars set, `/v3/wx/
     forecast/daily/5day` returns 200 → normalize per canonical mapping →
     200 ForecastResponse with `hourly=[], daily=<5 entries>,
     discussion=null, source="wunderground"`. Bundle's `hourly` array is
     ALWAYS empty regardless of slice request — PARTIAL-DOMAIN.
  3. `[forecast] provider = wunderground`, both env vars set, /5day
     returns 401 (apiKey invalid OR PWS no longer active) → 502
     ProviderProblem KeyInvalid (canonical taxonomy via ProviderHTTPClient,
     bare propagate). Operator's recovery action: verify PWS at
     wunderground.com/member/api-keys.
  4. `[forecast] provider = wunderground`, both env vars set, /5day
     returns 429 → 503 ProviderProblem QuotaExhausted +
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
    provider_id=PROVIDER_ID,                    # "wunderground"
    domain=DOMAIN,                              # "forecast"
    supplied_canonical_fields=(
        # DailyForecastPoint fields (canonical §4.1.3 Wunderground column)
        "validDate", "tempMax", "tempMin", "precipAmount",
        "precipProbabilityMax", "windSpeedMax",
        "sunrise", "sunset", "uvIndexMax", "weatherCode", "weatherText",
        "narrative",
        # NB: HourlyForecastPoint fields NOT supplied — Wunderground PWS
        # API has no hourly forecast on any tier (canonical §4.1.2 column
        # = all "—"; api-docs §Known issues confirms PWS tier has no
        # hourly endpoint).  PARTIAL-DOMAIN exclusion, not tier-conditional.
        # NB: ForecastDiscussion fields NOT supplied — Wunderground PWS
        # API has no discussion product (canonical §4.1.4 column = all "—").
        # NB: windGustMax NOT supplied — canonical §4.1.3 Wunderground
        # column = "—" for windGustMax.
    ),
    geographic_coverage="global",
    auth_required=("apiKey", "pws_station_id"),
    default_poll_interval_seconds=DEFAULT_FORECAST_TTL_SECONDS,    # 1800
    operator_notes=(
        "Weather Underground PWS API (Personal Weather Station "
        "contributor tier).  apiKey gated to active PWS owners — "
        "see api-docs/wunderground.md §Authentication.  Forecast: "
        "daily-only (no hourly, no discussion).  5-day forecast horizon. "
        "apiKey OR PWS-no-longer-active returns 401 → bundle.daily=[] "
        "via standard KeyInvalid 502 propagation."
    ),
)
```

The L1 PARTIAL-DOMAIN extension fires here: CAPABILITY enumerates ONLY the
DailyForecastPoint fields Wunderground supplies; hourly fields are
categorically excluded (not tier-conditional). Auditor: this is the
PARTIAL-DOMAIN nuance to call out if you see drift; fully covered by the
3b-4 L1 rule extension documented in `rules/clearskies-process.md`.

---

## Module file structure (target shape)

```
weewx_clearskies_api/providers/forecast/wunderground.py
├── module docstring (5 responsibilities + cache + helpers + PARTIAL-DOMAIN note)
├── PROVIDER_ID = "wunderground"
├── DOMAIN = "forecast"
├── WUNDERGROUND_BASE_URL = "https://api.weather.com"
├── WUNDERGROUND_FORECAST_PATH = "/v3/wx/forecast/daily/5day"
├── DEFAULT_FORECAST_TTL_SECONDS = 1800
├── _API_VERSION = "0.1.0"
├── CAPABILITY = ProviderCapability(...)  # daily-only, no hourly, no discussion
├── _WU_PRECIP_TYPE_MAP: dict[str, str | None] (or string lookup helper)
├── _logged_unknown_precip: set[str]
├── _logged_mixed_precip: set[str]
├── Wire-shape Pydantic models (extras="ignore"):
│     _WUDaypart — cloudCover/dayOrNight/daypartName/iconCode/narrative/
│                   precipChance/precipType/qpf/qpfSnow/relativeHumidity/
│                   temperature/uvIndex/windDirection/windSpeed/
│                   wxPhraseShort  (each is a 10-element list)
│     _WU5DayResponse — calendarDayTemperatureMax/calendarDayTemperatureMin/
│                       narrative/qpf/qpfSnow/sunriseTimeUtc/sunsetTimeUtc/
│                       temperatureMax/temperatureMin/validTimeLocal/
│                       validTimeUtc/expirationTimeUtc/dayOfWeek/
│                       moonPhase/moonPhaseCode/moonPhaseDay/
│                       moonriseTimeLocal/moonsetTimeLocal/daypart  (lists)
├── Helper functions:
│     _wu_precip_type_to_canonical(value)       # string lookup
│     _wu_validdate_from_local(s)               # split T, return date part
│     _build_cache_key(...)
│     _wu_to_daily_point(...)
│     _wu_to_canonical_bundle(...)
├── _rate_limiter = RateLimiter(...)
└── fetch(*, lat, lon, target_unit, api_key, pws_station_id, http_client=None)
        -> ForecastBundle  (hourly=[] always, discussion=None always)
```

---

## Process gates (round-close requirements)

The lead does NOT close the round until all of the following pass:

1. **api repo `origin/main` HEAD** advances past `9db163b` with the new
   provider module + dispatch + settings + endpoint dispatch + redaction
   extension landed.
2. **meta repo `origin/master` HEAD** advances past `bc0283d` with a
   round-close commit (plan status update + lessons routing).
3. **Default tier:** ≥ 1206 + (this round's new unit tests) / 0 failed.
   Baseline 1206/32/0; new tests should add ~50-80 unit tests for
   Wunderground + 3 redaction-filter tests.
4. **Integration MariaDB:** ≥ 205 + (new Wunderground integration tests) /
   32 skipped / 0 failed.
5. **Integration SQLite:** ≥ 212 + (new Wunderground integration tests) /
   25 skipped / 0 failed.
6. **Redis tier (`CLEARSKIES_CACHE_URL=redis://127.0.0.1:6380/0` +
   `"integration and redis"`):** all green; non-skip count includes the
   new Wunderground Redis-backend test (mirror Aeris/OWM
   `test_*_redis_cache_*` pattern). **Brief gate: Redis MUST PASS not skip**
   — same as 3b-3, 3b-4, 3b-5.
7. **No live-network tests.** All tests use `respx` against recorded /
   synthetic fixtures.
8. **Provenance documented** in commit messages: which fields are
   captured-real vs synthetic-from-api-docs; cite the api-docs section
   (L138-189 example response).
9. **F13 redaction extension** lands: `_APIKEY_RE` pattern in
   `redaction_filter.py`, registered in `_PATTERNS`, plus 3 unit tests
   passing.
10. **Auditor review** clean OR all findings remediated (lead-direct
    per surface-size rule, or remediation round if needed).
11. **Lessons triaged** at round close per CLAUDE.md "Capture lessons in
    the right place" routing rules. Decision-log narrative in
    `docs/planning/CLEAR-SKIES-PLAN.md`; rule-shaped lessons lift into
    `rules/clearskies-process.md`, `rules/coding.md`, or relevant
    `.claude/agents/<agent>.md`. **Default to decision-log-only unless
    a lesson genuinely changes future behavior in a way existing rules
    don't already cover** (per 3b-5 user feedback).

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
- **L2 "don't re-construct canonical exceptions"** — Wunderground module
  makes BARE `client.get()` calls. Unlike OWM 3b-5 (which had a Q1-licensed
  narrow wrap for One-Call-401), Wunderground has NO such narrow wrap.
  All canonical exceptions propagate bare.
- **L3 synthetic-from-real fixture pattern** (test-author) — Wunderground
  PWS API gating is the strictest of the three keyed providers. If neither
  test-author nor lead has an active PWS, fixture is from api-docs/
  wunderground.md L138-189 example. Sidecar marker REQUIRED. SendMessage
  to lead BEFORE submitting closeout naming the synthetic origin.
- **L1 PARTIAL-DOMAIN extension** — CAPABILITY excludes hourly entirely
  (categorical, not tier-conditional). Bundle ships `hourly=[]` always.
  Dashboard hides hourly panel via the same path as no-provider-configured.
- **Tests verify the brief; brief is the authority.** STOP-and-ping the
  lead at any signature divergence between impl and tests, OR at any
  brief-vs-canonical mismatch the impl would silently reconcile.
- **Pull-then-pytest gate** — `git fetch origin main && git merge --ff-
  only origin/main` BEFORE the pre-submit pytest run. Default branch
  is `main`.
- **F13 redaction-filter extension scope** — ONE new `_APIKEY_RE` pattern
  + 3 unit tests; mirror `_CLIENT_ID_RE` shape exactly. Don't speculate-
  generalize to other key-name forms.

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

- **Scratchpad:** `c:\tmp\3b-6-scratch.md` — append-as-you-go.
  Round-close: triage queued lessons per CLAUDE.md routing rules.
- **Spawn cadence:** api-dev + test-author parallel after brief sign-off;
  auditor after both submit + pytest is green on weather-dev.
- **Polling cadence:** every user-prompt boundary, lead checks
  `git log -20 origin/main` + `SendMessage` any silent teammate per the
  poll-don't-wait rule. Pre-empt the idle bug.
- **Auditor spawn prompt MUST explicitly name the lead's recipient name**
  (per 3b-5 SendMessage addressability gap — auditor's `team-lead` and
  `opus` names both failed; pre-empt by naming).

---

## Round close — after auditor's final review

1. Lead synthesizes auditor findings per the "Lead synthesizes auditor
   findings; doesn't forward" rule. Per-finding: accept (with specific
   remediation), push back, defer. Lead-direct remediation when surface
   is small (≲50 lines / ≲3 files).
2. Lessons triage per CLAUDE.md "Capture lessons in the right place" —
   route each lesson to its durable home (rules / agent defs /
   decision-log). **Default to decision-log-only unless a lesson genuinely
   changes future behavior in a way existing rules don't already cover.**
3. Plan-status commit on meta repo. Decision-log narrative covers what
   happened on this date; rule-shaped lessons lift into rules/agent
   files.
4. Update `docs/planning/CLEAR-SKIES-PLAN.md` to mark 3b-6 close + queue
   the next round (likely alerts/aeris or alerts/openweathermap; or
   the start of /aqi/* or /earthquakes work). The 3b-forecast series
   closes with this round.
5. **Queue next round resume prompt** at `c:\tmp\3b-7-resume-prompt.md`
   if a 3b-7 is anticipated. If 3b-forecast series is complete after
   3b-6 (it is) but other 3b-domain rounds are coming, write a
   `3b-forecast-close-summary.md` capturing what shipped across 3b-2
   through 3b-6 (the five forecast providers), then queue 3b-7-alerts
   (or whatever's next).
