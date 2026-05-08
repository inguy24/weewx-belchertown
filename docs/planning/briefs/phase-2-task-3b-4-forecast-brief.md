# Phase 2 task 3b round 4 brief — clearskies-api forecast domain (Aeris)

**Round identity.** Phase 2 task 3 sub-round 3b round 4. Fourth of 5 expected
3b rounds. 3b round 1 (alerts/NWS + shared `providers/_common/`) closed
2026-05-07; 3b round 2 (forecast/Open-Meteo) closed 2026-05-07; 3b round 3
(forecast/NWS + AFD) closed 2026-05-08. **3b round 4 adds the Aeris forecast
provider** — third concrete forecast provider, and the **first keyed
provider** to land on this project. Two remaining 3b forecast rounds add
OpenWeatherMap and Wunderground.

This is a **single-deliverable round.** Shared infrastructure (HTTP wrapper,
retry, error taxonomy, capability registry, both cache backends, rate
limiter, datetime utils) already lives. Forecast canonical types
(`HourlyForecastPoint`, `DailyForecastPoint`, `ForecastDiscussion`,
`ForecastBundle`, `ForecastResponse`) already live in `models/responses.py`.
The `/forecast` endpoint already lives at `endpoints/forecast.py` with two
dispatch branches (openmeteo, nws). `ForecastSettings` already lives. This
round adds:

1. **`weewx_clearskies_api/providers/forecast/aeris.py`** — third concrete
   forecast provider per ADR-007 + ADR-038. Five module responsibilities;
   structural twin of `providers/forecast/openmeteo.py` (single canonical
   bundle shape, no AFD analogue). Two outbound calls per cache miss
   (`/forecasts` filter=1hr; `/forecasts` filter=daynight).
2. **One new row in `_common/dispatch.py`** —
   `("forecast", "aeris") → providers.forecast.aeris`.
3. **`aeris_client_id` + `aeris_client_secret` fields on `ForecastSettings`**
   sourced from env vars per ADR-027 §3. Loaded into module-level state via
   a new `wire_aeris_credentials()` helper in `endpoints/forecast.py`,
   mirror-pattern of `wire_nws_user_agent_contact()`.
4. **`elif provider_id == "aeris":` dispatch branch in
   `endpoints/forecast.py`** — passes lat/lon/target_unit + credentials to
   `aeris.fetch()`.
5. **`logging/redaction_filter.py` extension** — add `client_id` query-param
   redaction pattern. **F13 from 3b round 1 fires here** (deferred since
   3b-1 because no keyed provider had landed; first keyed provider does).
   `client_secret` is already redacted (3b-1 work).

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after both
submit and pytest is green on `weather-dev`.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` (clone of
`github.com/inguy24/weewx-clearskies-api`). **Default branch `main`** (verified
2026-05-08 against `git symbolic-ref refs/remotes/origin/HEAD`). Parallel-pull
command: `git fetch origin main && git merge --ff-only origin/main`. The
meta-repo (this `weather-belchertown/` workspace) is `master`.

**Pre-round HEADs verified 2026-05-08:**
- api repo: `98ec7dc` (3b-3 remediation: 6 audit findings fixed)
- meta repo: `5c21ae1` (Plan status: 3b-3 close)
- weather-dev: `98ec7dc` (already up to date)

---

## Scope — 1 provider module + plumbing + redaction-filter extension

| # | Unit | Notes |
|---|---|---|
| 1 | `weewx_clearskies_api/providers/forecast/aeris.py` | New file. Two outbound calls per cache miss: `/forecasts/{lat},{lon}?filter=1hr` for hourly periods, `/forecasts/{lat},{lon}?filter=daynight` for paired day/night periods. **No discussion fetch** — Aeris does not surface an AFD-shape product on the free-tier; canonical §4.1.4 Aeris column shows `headline` mapping but `body` "(not directly; some plans expose summary)" — see lead-call 14. Bundle ships with `discussion=None`. |
| 2 | `_common/dispatch.py` | Add `("forecast", "aeris") → providers.forecast.aeris` row. One import + one entry. |
| 3 | `config/settings.py` `ForecastSettings` | Add `aeris_client_id: str \| None` + `aeris_client_secret: str \| None` fields populated from env vars `WEEWX_CLEARSKIES_AERIS_CLIENT_ID` + `WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET` at `__init__` (NOT from the `[forecast]` INI section — secrets per ADR-027 §3). |
| 4 | `endpoints/forecast.py` | Add `wire_aeris_credentials()` (mirror `wire_nws_user_agent_contact`). Extend `wire_forecast_settings()` to also call it. Add `elif provider_id == "aeris":` dispatch branch. |
| 5 | `__main__.py` | **No change** — already calls `forecast.wire_forecast_settings(settings)`. The new `wire_aeris_credentials()` plugs into that wrapper. |
| 6 | `logging/redaction_filter.py` | Add `client_id` query-param redaction pattern. F13 fires. |
| 7 | Recorded fixtures | `tests/fixtures/providers/aeris/forecasts_hourly.json`, `forecasts_daynight.json`, plus error-shape fixtures: `error_401_invalid_credentials.json`, `error_429_rate_limit.json`, `error_warn_invalid_location.json` (the `success=true` + `error={...}` warning shape per aeris.md "Response format conventions"). Sidecar `.md` documents capture date + lat/lon + which Aeris account-tier the fixture was captured against. |

**Out of scope this round (defer to later 3b rounds / Phase 3+ / Phase 4):**

- **Aeris alerts.** Separate 3b alerts round. ADR-007 says Aeris alerts coverage is "US, Canada, Europe only" — the alerts round will carry the geographic-bounding logic. This round is forecast-only.
- **Aeris current observation `/observations/{lat,lon}`.** Used as latest-hour fallback per canonical §4.1.1 only when archive is empty; the `/forecast` endpoint surfaces forecast points, not the observation slot. Future endpoint work (e.g., a dedicated `/now` slot) would consume `/observations`.
- **Aeris paid-tier discussion (`summary` field on some plans).** Lead-call 14: free-tier and entry-paid don't expose forecast-discussion text; bundle ships with `discussion=None` for v0.1. Future enhancement: detect `summary` field at runtime and surface as a minimal `ForecastDiscussion` body. Out of scope this round.
- **Aeris `/conditions` endpoint.** Returns hourly increments for past/future ranges; canonical-mapping table reads `/forecasts` for the forecast bundle, not `/conditions`. Out of scope.
- **OpenWeatherMap / Wunderground forecast.** Two remaining 3b forecast rounds. The Wunderground round ships the third query-string credential redaction pattern (`apiKey`); OWM's `appid` is already redacted (3b-1).
- **All other provider domains.** /aqi/* /earthquakes /radar/* are separate 3b rounds.
- **Operator overrides for forecast TTL or rate-limit.** This round uses ADR-017's default 30 min for forecast; same as Open-Meteo + NWS.
- **Multi-location.** ADR-011 single-station.
- **Aeris namespace-binding gotcha at registration time.** aeris.md notes "client_id/client_secret are bound to a registered namespace (domain or bundle ID)." Server-side calls from an unregistered host are rejected. **Operator-responsibility per ADR-006**; the module surfaces a `KeyInvalid` (HTTP 401 with appropriate Aeris error code) and the dashboard hides the panel. The setup wizard (Phase 4 per ADR-027) will document the domain-binding step at credential entry.

---

## Lead-resolved calls (no user sign-off needed — ADRs and contracts settle these)

The "Brief questions audit themselves before draft" rule
(`rules/clearskies-process.md`) requires every "open question" to be audited
against the ADRs first. The "brief-vs-canonical cross-check" rule (post-3b-2,
F2) requires every lead-resolved call to cross-check against
`canonical-data-model.md` + `openapi-v1.yaml` before drafting. Both audits
performed; every call below has been verified against both. Numbered for
reference, not for sign-off.

### Inherited from 3b rounds 2 & 3 (no change, no re-audit needed)

1. **HTTP client = `httpx` (sync).** `ProviderHTTPClient` from
   `_common/http.py`. Already covers TLS, timeouts, retry/backoff, error-class
   translation, structured `status_code` attribute on `ProviderError` (3b-3
   F2 remediation), and 4xx body logging at ERROR (3b-2 F1).

2. **Forecast cache TTL = 30 min.** ADR-017 §Per-provider TTL declaration.
   Module's `CAPABILITY.default_poll_interval_seconds = 1800`.

3. **Capability-registry populate path.** ADR-038 §3 + 3b-2's
   `_wire_providers_from_config()`. No change needed — adding the dispatch
   row in step 2 above is enough; the existing `__main__.py` lookup picks
   `aeris` automatically when `[forecast] provider = aeris`.

4. **Both cache backends already live.** ADR-017 + 3b-1's `MemoryCache` +
   `RedisCache`. Forecast/aeris consumes `get_cache()` like the other modules.

5. **No live-network tests in CI.** ADR-038 §Testing pattern. Recorded
   fixtures + `respx` for everything.

6. **Source field when no provider configured = literal `"none"`.**
   `endpoints/forecast.py` already does this; no change.

7. **`precipType` derivation rule (forecast-domain, all providers).** Use
   §3.3 enum values literally — `"rain"` / `"snow"` / `"sleet"` /
   `"freezing-rain"` / `"hail"` / `"none"`. **Do NOT flatten freezing variants
   to `"rain"`.** Locked in canonical-data-model §4.1.2 from 3b-2 audit (F2).
   Aeris-specific lookup table operationalizing this rule is **call 16**
   below.

8. **Slice-after-cache pattern.** `endpoints/forecast.py` already slices the
   bundle's `hourly` and `daily` arrays after cache lookup. Aeris provides
   ~120-360 hourly periods and 14 daynight periods (paired into 7 daily
   points) depending on plan; the slice cap is whatever Aeris returned. No
   new behavior at the endpoint level.

9. **Dispatch on exception state via attributes, not message strings.** Per
   `rules/coding.md` §3 (added 2026-05-08 from 3b-3 F2). Aeris module uses
   `exc.status_code == 401` for KeyInvalid translation, `exc.status_code ==
   429` for QuotaExhausted, `exc.status_code in (400, 422)` for protocol
   errors. **No `"X" in str(exc)` patterns.**

10. **Reuse `providers/_common/datetime_utils.py:to_utc_iso8601_from_offset`.**
    Lifted from `alerts/nws.py` in 3b-3 (3b-3 F3 remediation). Aeris responses
    carry ISO-8601 strings with offset already (e.g.,
    `"2026-04-30T10:00:00-07:00"`); module reuses the helper to normalize
    to UTC `Z` form. **Do NOT fork a new datetime helper.**

### Aeris-specific (this round)

11. **Two outbound calls per cache miss.** Aeris forecast workflow per
    `docs/reference/api-docs/aeris.md` §Forecasts:
    1. `GET /forecasts/{lat},{lon}?filter=1hr&limit=N&client_id=...&client_secret=...`
       → hourly periods.
    2. `GET /forecasts/{lat},{lon}?filter=daynight&limit=M&client_id=...&client_secret=...`
       → paired day/night periods (Aeris day-period + immediately-following
       night-period).

    Both outbound calls happen on cache miss; the post-normalization
    `ForecastBundle` is cached for 30 min (ADR-017). Single cache key per
    `(station, target_unit)`. NB: `target_unit` is part of the cache key
    even though Aeris returns both metric and imperial fields in the same
    payload — because the canonical bundle is normalized to a single unit
    set at write time per ADR-019.

    **`limit` parameter.** Aeris accepts `limit=N` to cap returned periods.
    Use `limit=240` for hourly (10 days × 24h, well above the 384-hour
    `ForecastQueryParams.hours` upper bound) and `limit=14` for daynight
    (7 days × 2). The endpoint's `hours`/`days` slice runs after cache
    lookup, so a single cache entry serves any operator slice.

12. **Aeris auth: `client_id` + `client_secret` query params.** Per ADR-007
    line 67-69 + aeris.md §Authentication. **Aeris is the first keyed
    provider on this project.** Both credentials sourced from env vars per
    ADR-027 §3:
      - `WEEWX_CLEARSKIES_AERIS_CLIENT_ID`
      - `WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET`

    **Naming deviation surfaced for user judgment** — see
    "Brief-draft sign-off questions" §Q1 below. ADR-027 §3's literal naming
    schema is `WEEWX_CLEARSKIES_<DOMAIN>_<FIELD>` and
    `WEEWX_CLEARSKIES_<DOMAIN>_<PROVIDER>_<FIELD>` — both forms include a
    domain. The provider-scoped form proposed here drops the domain because
    Aeris credentials are provider-wide (the same key works for `/forecasts`
    AND `/alerts` AND `/observations`). User picks: (A) provider-scoped
    (proposed), (B) domain-scoped per literal ADR-027 with operators
    pasting the same key into two env vars, OR (C) ADR-027 amendment.

    **Module wiring.** `wire_aeris_credentials()` reads both env vars at
    startup (in `endpoints/forecast.py`, mirror of
    `wire_nws_user_agent_contact()`); module-level `_aeris_client_id` and
    `_aeris_client_secret` are passed to `aeris.fetch()` from the dispatch
    branch.

    **Missing-credential behavior at fetch time.** If the operator sets
    `[forecast] provider = aeris` but does NOT set both env vars, the
    module raises `KeyInvalid("Aeris credentials missing — set
    WEEWX_CLEARSKIES_AERIS_CLIENT_ID and WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET")`
    on the first request. Translated to 502 ProviderProblem with
    `errorCode="KeyInvalid"`. **Do NOT silently disable the module at
    startup** — the operator's intent (`provider = aeris`) is unambiguous;
    refusing to serve forecasts loudly beats serving no-provider-configured
    silently.

13. **Aeris unit handling: pick fields from the bilingual response.** Per
    ADR-019 §Decision (server passes weewx target_unit through; provider
    conversions at ingest). Aeris returns BOTH metric and imperial fields
    in the same payload — no `units=` query param. Mapping table:
      - `target_unit=US` → `tempF`, `windSpeedMPH`, `windGustMPH`,
        `windSpeedMaxMPH`, `windGustMaxMPH`, `precipIN`, `dewpointF`,
        `maxTempF`, `minTempF`, `pressureIN`.
      - `target_unit=METRIC` → `tempC`, `windSpeedKPH`, `windGustKPH`,
        `windSpeedMaxKPH`, `windGustMaxKPH`, `precipMM`, `dewpointC`,
        `maxTempC`, `minTempC`, `pressureMB`.
      - `target_unit=METRICWX` → `tempC`, `windSpeedMPS`, `windGustMPS`,
        `windSpeedMaxMPS`, `windGustMaxMPS`, `precipMM`, `dewpointC`,
        `maxTempC`, `minTempC`, `pressureMB`.

    **NB:** Aeris does not document `windSpeedMaxMPS` explicitly in our
    aeris.md captured response, but the standard Aeris field-naming pattern
    is `<measurement><statistic><unit>` — module assumes the field exists
    in the daynight response. If validation fails on a captured fixture
    against this assumption, **STOP and ping the lead** (canonical §3.4
    `windSpeedMax` is a daily field; if Aeris doesn't expose
    `windSpeedMaxMPS` for METRICWX, options are (a) fall back to
    `windSpeedMaxKPH ÷ 3.6`, (b) leave the canonical field `null`).
    Pre-emptive lead-call: if `windSpeedMaxMPS`/`windGustMaxMPS` are absent
    and `KPH` variants are present, post-convert at canonical-translation
    time (matches NWS METRICWX km/h→m/s pattern from 3b-3).

14. **`ForecastDiscussion` for Aeris — runtime detection of `summary`
    field; `None` when absent (USER DECISION 2026-05-08).** Canonical
    §4.1.4 Aeris column shows `headline` mapping (from
    `response.forecasts[0].periods[0].weatherPrimary`) but `body: (not
    directly; some plans expose summary)`. Canonical §3.5 declares `body`
    with `Nullable=No` — REQUIRED. Module performs **runtime detection**
    of a paid-tier summary field on the daynight response and populates
    the discussion body when present:

    - **Detection point:** after wire-shape Pydantic validation of the
      daynight response, walk the parsed dict looking for a non-empty
      string at `response[0].summary` OR `response[0].periods[0].summary`
      (TBD — see STOP-and-ping note below). Per `extras="ignore"` the
      base Pydantic model accepts unknown fields; access the raw dict
      for the optional summary.
    - **When present + non-empty:** construct `ForecastDiscussion(
      headline=response[0].periods[0].weatherPrimary,
      body=<the detected summary string>, source="aeris",
      issuedAt=<UTC-converted from response[0].periods[0].dateTimeISO>,
      validFrom=None, validUntil=None, senderName=None)`. Bundle ships
      with that discussion.
    - **When absent / empty / whitespace-only:** module returns
      `ForecastBundle(..., discussion=None)`. Pattern matches Open-Meteo
      + OWM + Wunderground.

    **CAPABILITY.supplied_canonical_fields INCLUDES the
    `ForecastDiscussion` headline + body fields** since paid-tier Aeris
    can supply them. The capability declaration represents the maximum
    surface; runtime population is conditional. (Auditor: this is a
    capability-vs-runtime-fidelity nuance to call out if you see drift —
    the user accepted the trade-off explicitly per Q2 below.)

    **STOP-and-ping at impl time:** Aeris's documented paid-tier
    summary-field name is NOT confirmed in our local
    `docs/reference/api-docs/aeris.md`. The canonical-mapping note in
    §4.1.4 says "some plans expose summary" without naming the field.
    Two candidate locations:
      - `response[0].summary` (response-level summary, parallel to
        OpenWeatherMap's `daily.summary`)
      - `response[0].periods[0].summary` (per-period summary)
    api-dev should attempt detection of both shapes and surface results
    via SendMessage at impl time. If the captured paid-tier fixture
    (test-author scope) has neither, ping the lead — this round may need
    to defer the runtime-detection feature to a future round once we
    have a confirmed Aeris paid-tier response example.

    **Audit risk surfaced (lead's recorded concern, user-overridden
    2026-05-08):** Two CAPABILITY semantics — "always supplies
    discussion" (CAPABILITY says yes) vs. "may or may not supply
    discussion at runtime" (bundle reflects what was returned). User
    accepted the trade-off; the value is paid-tier discussion surfacing
    when available. If post-audit the auditor flags this as ADR-038
    static-CAPABILITY drift, the lead's response is "user-accepted
    trade-off, see brief Q2."

15. **`weatherCode` extraction = pass-through `weatherPrimaryCoded`.**
    Canonical §4.1.2 Aeris column says `weatherCode = periods[].weatherPrimaryCoded`.
    Format is `:<coverage>:<intensity>:<descriptor>` (colon-delimited;
    coverage and intensity may be empty for clouds-only). Module passes the
    full string through as the canonical `weatherCode`; dashboard maps to
    icon. Same opaque-pass-through posture as Open-Meteo's WMO codes and
    NWS's icon shortNames.

16. **`precipType` derivation from Aeris weather descriptor codes.** Per
    the forecast-domain rule (call 7), use canonical §3.3 enum literally.
    Lookup table from Aeris's documented weather descriptor codes (third
    colon-separated segment of `weatherPrimaryCoded`):
      - `R` (rain), `RW` (rain showers), `L` (drizzle) → `"rain"`
      - `S` (snow), `SW` (snow showers) → `"snow"`
      - `ZR` (freezing rain), `ZL` (freezing drizzle) → `"freezing-rain"`
      - `IP` (ice pellets / sleet) → `"sleet"`
      - `A` (hail) → `"hail"`
      - `T` (thunderstorms) → `"rain"` (thunder accompanies rain in canonical
        framing; consistent with NWS `tsra` mapping from 3b-3)
      - `RS` (rain/snow mix), `WM` (wintry mix), `SI` (snow/sleet) → `"rain"`
        (mixed precip — established rule per 3b-3; canonical has no mixed-
        precip enum value; log DEBUG once per mix-class encounter so future
        canonical amendment is informed by real-data prevalence)
      - All other descriptors (`OVC` overcast, `SCT` scattered, `BR` mist,
        `F` fog, `H` haze, `K` smoke, etc.) → `None`

    Helper `_aeris_descriptor_to_precip_type(coded: str) -> str | None`:
    parses the third colon-segment, looks up in the table above; unknown
    descriptors → `None` (log DEBUG once on first encounter).

17. **Geographic coverage: trust Aeris's authoritative answer.** ADR-007
    table says Aeris is broader than NWS (US/CA/EU + parts of Asia/SA).
    Real-world coverage varies by data type and Aeris plan. The module
    does NOT carry a client-side geographic gate. Posture matches
    Open-Meteo (global, no client-side bound). When Aeris returns a
    `warn_location` warning (per aeris.md §"Common error / warning codes"),
    the module surfaces as a `ProviderProtocolError` (the warning indicates
    Aeris couldn't resolve the requested location to an authoritative point;
    canonical taxonomy treats this as protocol-level). When Aeris returns
    HTTP 200 with `success=true, response=[]` for a location it doesn't
    cover, the module returns `ForecastBundle(hourly=[], daily=[], …)` —
    same shape as no-provider-configured but `source="aeris"`. Dashboard
    handles "no data" gracefully.

18. **Rate limiter for Aeris.** Per ADR-038 §3 (rate-limiter primitive in
    shared `_common/`) + 3b-3 F4 lesson on per-call acquire when published
    quota is per-second. Aeris paid plans publish per-second quotas (e.g.,
    10/s entry-tier, higher on bigger plans); free trial is undocumented
    but conservative. Configure
    `RateLimiter("aeris", max_calls=5, window_seconds=1)` as a
    "be polite" guard matching Open-Meteo and NWS — covers the lowest
    documented Aeris paid-tier and well below any reasonable free-trial
    cap. **Per-call acquire** before each of the two outbound calls per
    cache miss (the rate-limiter primitive does this naturally; module
    code calls `rate_limiter.acquire()` before each `client.get(...)`).
    Operator-override for the per-second cap is out of scope this round
    (ADR-017 may grow that knob in a future revision).

19. **`weatherText` extraction.**
    - Hourly: `periods[].weather` directly (e.g., "Mostly Cloudy"). Aeris
      provides this as a human-readable label parallel to the coded form.
    - Daily: `periods[].weather` for the day-period.

20. **`narrative` (DailyForecastPoint).** `null` for v0.1 free-tier Aeris.
    Canonical §4.1.3 Aeris column says `periods[].text` "(paid-tier on
    some plans)". Same paid-tier-only pattern as the discussion `body`;
    same v0.1 scope decision (call 14). Future ADR-007 amendment may
    surface `text` when the paid-tier coverage matters. Module emits
    `narrative=None` unconditionally this round.

21. **`sunrise` / `sunset` parsing.** Aeris returns ISO with offset on
    `sunriseISO` / `sunsetISO` (`"2026-04-30T06:00:00-07:00"`). Module
    reuses `to_utc_iso8601_from_offset` from
    `providers/_common/datetime_utils.py` (no fork — call 10). Result
    matches canonical §3.4 (UTC ISO-8601 Z).

22. **`validTime` (HourlyForecastPoint) and `validDate` (DailyForecastPoint)
    parsing.** Aeris returns `dateTimeISO` with offset on every period.
    `validTime` (UTC ISO-8601 Z) reuses `to_utc_iso8601_from_offset`.
    `validDate` (station-local YYYY-MM-DD per canonical §3.4) is the date
    portion of `dateTimeISO` BEFORE conversion (the offset is the station-
    local one Aeris already pre-applies via its `profile.tz` lookup).
    Tests assert against both the UTC-converted hourly and the
    station-local daily.

23. **F13 redaction-filter `client_id` strip — FIRES THIS ROUND.** Per
    3b-2 brief call 16 (deferred): "Whichever future 3b round first ships
    Aeris extends `logging/redaction_filter.py`." `client_secret` is
    already stripped (3b-1 work). Add a sibling regex pattern for
    `client_id`. **One-line addition** — pattern shape mirrors the
    existing `_CLIENT_SECRET_RE`. Pattern:
    `r"((?:^|[?&])client_id=)[^&\s\n\"']+"`, case-insensitive, replacement
    `r"\g<1>[REDACTED]"`. Append to `_PATTERNS` after the existing
    `client_secret` entry. Test coverage: a logged URL containing
    `?client_id=ABC123&client_secret=DEF456` redacts BOTH values.

24. **`extras` field on canonical Aeris hourly / daily points.** Aeris
    surfaces fields that don't map 1:1 to canonical (e.g., `feelslike` /
    `heatindexC` / `windchillC`, `solradWM2`, `wetBulbGlobeTempC`,
    `iceaccumIN`, `QC`/`QCcode`/`trustFactor` data-quality flags). Per
    canonical §3.3 + §3.4, `extras: object` is provider-specific; v0.1
    treatment: **leave `extras: {}` empty for Aeris this round.** The
    canonical mapping for Aeris does NOT enumerate `extras` content;
    surfacing them would introduce shape-drift between Aeris and the other
    providers. Future round may add `feelslike` if a canonical field for
    "apparent temperature" is added (canonical model has `appTemp` for
    observations but not for hourly/daily forecast points).

25. **Hourly horizon = `?hours=` query param, default 48, max 384 (already
    enforced by `ForecastQueryParams`).** Aeris hourly returns up to ~360
    periods on entry-paid plans (15 days × 24h). The endpoint slice runs
    after cache lookup; module always asks Aeris with `limit=240` (10
    days × 24h, comfortably above 384h cap and well within Aeris's
    coverage range per aeris.md §"Forecast data extends to +15 days").
    No change to `models/params.py`.

26. **`uvIndexMax` source.** Aeris daynight `periods[].uvi` per
    canonical §4.1.3 Aeris column. Same field both daytime and nighttime;
    module takes the day-period value.

---

## Brief-draft sign-off — USER DECIDED 2026-05-08

The "Brief questions audit themselves before draft" rule says drop questions
the ADR settles. Two operationalization questions surfaced — both real
ADR-vs-fit / canonical-spec-operationalization decisions. Both decided by
the user 2026-05-08.

### Q1. Aeris credential env-var naming → **(A) Provider-scoped** (per user decision)

**Decision:** `WEEWX_CLEARSKIES_AERIS_CLIENT_ID` +
`WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET`. Drops the domain prefix from
ADR-027 §3's literal schema. Operator pastes once; works for forecast AND
future alerts/observation modules.

**Audit trail.** Considered options:

- (A) Provider-scoped — chosen.
- (B) Domain-scoped per literal ADR-027 — rejected (foot-gun: copy-paste
  error puts different keys in two env vars).
- (C) ADR-027 amendment — rejected (overkill for a one-sentence
  convention; the convention has a real-world gap that's not carrying
  material decision content).

**Operationalization.** Lead-call 12 above implements this. The
deviation from ADR-027 §3's literal schema is documented inline in the
module + settings docstrings and called out at this round's close in the
plan's decision log. No ADR amendment.

### Q2. ForecastDiscussion for Aeris → **(B) Runtime detection** (per user decision)

**Decision:** Module performs runtime detection of a paid-tier summary
field. When present and non-empty, construct a `ForecastDiscussion` with
`headline = weatherPrimary`, `body = <detected summary>`, etc. When
absent / empty, `discussion=None`. CAPABILITY.supplied_canonical_fields
INCLUDES the discussion fields (paid-tier maximum surface).

**Audit trail.** Considered options:

- (A) `discussion=None` always for v0.1 — rejected by user.
- (B) Runtime detection — chosen.

**Lead-recorded concern (user-overridden):** option (B) introduces
capability-vs-runtime drift — CAPABILITY declares discussion supplied
but runtime population depends on which paid-tier Aeris account is in
use. Auditor may flag as ADR-038 static-CAPABILITY drift; the lead's
response on review is "user-accepted trade-off, see Q2." User's
priority: surface paid-tier discussion content when available rather
than uniformly returning None.

**Operationalization (incomplete — needs impl-time research).**
Lead-call 14 above implements this. The exact field name for the
summary content is **NOT confirmed** in our local
`docs/reference/api-docs/aeris.md`. api-dev attempts detection of
`response[0].summary` AND `response[0].periods[0].summary` and reports
back via SendMessage which (if either) is present in the captured
paid-tier fixture. If neither is present, this round may need to defer
runtime-detection to a future round once paid-tier shape is confirmed
— at which point the brief flips to (A) for v0.1.

**Test-author scope addition.** Tests cover BOTH paths:
- Captured paid-tier fixture with the detected summary field →
  bundle.discussion is a populated ForecastDiscussion.
- Free-tier-shaped fixture (no summary) → bundle.discussion is None.

---

## Hard reading list (once per session)

**Both api-dev and test-author:**

- `CLAUDE.md` — domain routing + always-applicable rules.
- `rules/clearskies-process.md` — full file. **Carry-forward (NEW from
  3b-3 close 2026-05-08):**
    - Live scratchpad during multi-agent rounds (lead-side; the live
      scratchpad lives at `c:\tmp\3b-4-scratch.md` and is the lead's
      audit trail).
    - Lead-direct remediation when the surface is small (≲50 lines / ≲3
      files; mechanical narrowings, off-by-one fixes, structural
      attribute extensions). Lead handles small audit findings post-
      audit instead of respawning teammates.
    - Canonical-spec operationalization is a brief-draft question, not
      an impl call. **Q1 + Q2 above are this rule firing.**
    - Multi-line commit messages on PowerShell: use `git commit -F
      c:\tmp\<task>-msg.txt`.
  Carry-forward (from prior rounds): poll-don't-wait at user-prompt
  boundaries (lead side); brief-questions-audit at draft (this brief
  applies it); brief-vs-canonical cross-check at draft (Q2 above);
  tests verify the brief, brief is the authority (governs api-dev's
  STOP-and-ping when test signature ≠ brief signature); ADR conflicts
  → STOP (Q1 above is a deviation, surfaced explicitly); round briefs
  land in the project, not in tmp; `.claude/` stays private; lead
  synthesizes auditor findings, doesn't forward.
- `rules/coding.md` — full file. **§3 carry-forward (NEW from 3b-3
  close):** "Dispatch on exception state via attributes, not message
  strings" — lead-call 9 above. Aeris module dispatches on
  `exc.status_code`, never on `str(exc)`. Carry-forward: §1 Pydantic +
  Depends pattern (already in `endpoints/forecast.py`), IPv4/IPv6-
  agnostic networking (`httpx.Client` resolves via `getaddrinfo`
  natively), no dangerous functions, no hardcoded secrets (Aeris
  credentials in env vars per ADR-027 §3; never inline in source). §3:
  catch specific exceptions, never `except Exception:`. §3 "search
  before writing a new helper" — `to_utc_iso8601_from_offset` already
  exists; reuse, don't fork (lead-call 10). §5 (a11y) is non-applicable
  — backend round.
- `docs/contracts/openapi-v1.yaml`:
  - `/forecast` at line 186.
  - `HourlyForecastPoint` at line 1016.
  - `DailyForecastPoint` at line 1035.
  - `ForecastDiscussion` at line 1058 (Aeris uses `null`; structure
    reference only).
  - `ForecastBundle` at line 1073.
  - `ForecastResponse` at line 1562.
  - `ProviderProblem` at line 863, `ProviderError` response at line 799,
    `ProviderUnavailable` response at line 807, `CapabilityDeclaration`
    at line 1432.
- `docs/contracts/canonical-data-model.md`:
  - §3.3 (HourlyForecastPoint per-field enumeration + unit groups).
  - §3.4 (DailyForecastPoint per-field enumeration + unit groups).
  - §3.5 (ForecastDiscussion — for the canonical type even though
    Aeris always returns `null` v0.1).
  - §3.10 (ForecastBundle container — `null` discussion is
    canonical-shape-conformant).
  - §4.1.2 (Aeris hourly mapping table — column 1, lines 437-449).
  - §4.1.3 (Aeris daily mapping table — column 1, lines 462-475).
  - §4.1.4 (Forecast discussion mapping — Aeris column 2, lines
    485-493; lead-call 14 above operationalizes the gap).
- `docs/contracts/security-baseline.md`:
  - §3.4 (secrets — **fires this round** for the first time. Aeris
    `client_id`/`client_secret` from env vars; never inline in source;
    redaction-filter strip via §logging update).
  - §3.5 (input validation — Pydantic models for the wire shape inside
    the normalizer per ADR-038; rule applies here).
  - §3.6 (logging — provider URL logged at INFO with `client_id` /
    `client_secret` query params present in the URL string.
    Redaction filter strips both before formatter emits — VERIFY in tests).
- `docs/reference/api-docs/aeris.md` — full file. The `/forecasts`
  example response at lines 181-223 is the source of truth for the
  wire-shape Pydantic models. The §Authentication section at lines
  15-42 confirms query-string auth (no header). The §"Common error /
  warning codes" section at lines 335-342 lists `invalid_location`,
  `warn_location`, `maxhits_min` etc. — module classifies these per
  canonical taxonomy (lead-call 17). §"HTTP status codes" at lines
  327-333 is the basis for status_code dispatch (lead-call 9). §"Known
  issues / gotchas" at lines 348-354 — particularly the
  namespace-binding gotcha (operator-responsibility per ADR-006).
- `docs/planning/briefs/phase-2-task-3b-2-forecast-brief.md` — second-
  forecast-provider structure pattern reference. Aeris's two-call
  shape is closer to Open-Meteo's single-call than NWS's five-call;
  this brief inherits 3b-2's overall shape more than 3b-3's.
- `docs/planning/briefs/phase-2-task-3b-3-forecast-brief.md` — third-
  forecast-provider structure pattern reference. The 3b-3 audit-finding
  tracking (F1 HIGH, F2-F6 MED-LOW) and the lead-direct remediation
  pattern from `c49ed12`/`ca6f099`/`976286a`/`98ec7dc` apply.
- `.claude/agents/clearskies-api-dev.md` — agent definition including
  the 2026-05-07/08 carry-forward: tests verify the brief; brief vs
  canonical STOP-and-ping; **commit early and often**; mid-flight
  SendMessage cadence (no >4 min silent).
- `.claude/agents/clearskies-test-author.md` — same commit-early-and-
  often + brief-gate-honesty.

**ADRs to load before implementing:**

- ADR-006 (compliance — operator-managed API keys; **this round is the
  first to actually exercise the keyed-provider compliance pattern**).
- ADR-007 (forecast providers — Aeris is in the day-1 set; auth pattern
  per the table at line 67-73; coverage is broader than NWS's USA-only
  but module trusts Aeris's authoritative answer per lead-call 17).
- ADR-008 (auth model — provider modules don't add user auth; cross-host
  proxy auth is unrelated to Aeris client_id/client_secret).
- ADR-010 (canonical data model — HourlyForecastPoint, DailyForecastPoint,
  ForecastDiscussion, ForecastBundle).
- ADR-011 (single-station — operator lat/lon comes from station metadata,
  not query param).
- ADR-017 (provider response caching — pluggable backend already wired;
  forecast TTL 30 min default; cache key shape).
- ADR-018 (URL-path versioning, RFC 9457 errors, ProviderProblem
  extension carrying providerId/domain/errorCode).
- ADR-019 (units handling — server passes weewx target_unit through;
  provider conversions at ingest in the provider module). Aeris's
  bilingual response makes "convert at ingest" trivial: pick the right
  unit's field name.
- ADR-020 (time zone — UTC ISO-8601 Z on the wire; station-local for
  date-only fields).
- ADR-027 (config — secrets in `secrets.env`; env-var naming convention
  in §3; **lead-call 12 + Q1 above propose a deviation for user judgment**).
- ADR-029 (logging — INFO per-request access log; provider URL logged
  with redaction filter applied; ADR-029-mandated `client_id` redaction
  is the F13 work).
- ADR-038 (provider module organization — five module responsibilities,
  shared infra split, capability declaration fields, canonical error
  taxonomy, testing pattern; **static-CAPABILITY contract applies — see
  Q2**).

ADRs explicitly NOT in scope this round:

- ADR-013 (AQI — separate 3b round).
- ADR-015 (radar — separate 3b round).
- ADR-016 (alerts — handled via the alerts/nws.py module from 3b-1; an
  alerts/aeris.py module is a future round).
- ADR-040 (earthquakes — separate 3b round).
- ADR-022 / ADR-023 / ADR-026 (theming, dark mode, a11y — Phase 3
  dashboard).

---

## Existing code (read, do not rewrite)

3b rounds 1+2+3 + earlier rounds landed everything below. Aeris module
consumes these; do NOT modify.

- `weewx_clearskies_api/providers/_common/` — eight files. Reusable as-is:
  - `errors.py` — canonical `ProviderError` taxonomy (`QuotaExhausted`,
    `KeyInvalid`, `GeographicallyUnsupported`, `FieldUnsupported`,
    `TransientNetworkError`, `ProviderProtocolError`). Each carries
    structured `status_code: int | None` attribute since 3b-3 F2.
  - `http.py` — `ProviderHTTPClient` wraps `httpx.Client` with timeouts,
    TLS verify, retry/backoff, error-class translation, `status_code`
    propagation. Aeris module instantiates one at module load.
  - `cache.py` — `get_cache()` returns the active backend (memory or
    redis, chosen by `CLEARSKIES_CACHE_URL` env var per ADR-017).
  - `rate_limiter.py` — `RateLimiter` sliding-window primitive.
  - `capability.py` — `ProviderCapability` dataclass + `wire_providers()`
    + `get_provider_registry()`.
  - `dispatch.py` — `PROVIDER_MODULES` dict. Add one row this round.
  - `datetime_utils.py` — `to_utc_iso8601_from_offset(...)` helper from
    3b-3. **Reuse, don't fork** (lead-call 10).
- `weewx_clearskies_api/providers/forecast/openmeteo.py` — pattern reference
  for single-call-per-cache-miss flow. Aeris module follows the same
  five-section layout (constants, wire-shape Pydantic, `fetch()`,
  `_to_canonical()`, helpers). The hourly+daily shape parallel from
  Open-Meteo's column-oriented blocks does NOT apply to Aeris (Aeris
  uses row-oriented `periods[]` arrays); use Aeris-specific Pydantic
  models.
- `weewx_clearskies_api/providers/forecast/nws.py` — pattern reference for
  multi-call-per-cache-miss flow. NWS-specific helpers
  (`_extract_afd_headline_and_sender`, the AFD-product-list parsing) do
  NOT carry over to Aeris (which has no AFD analogue). The
  windSpeed/windDirection parsing helpers are NWS-specific (string
  ranges, compass abbrevs); Aeris returns numeric degrees + numeric
  speeds directly, no parsing helpers needed.
- `weewx_clearskies_api/providers/alerts/nws.py` — UA-wiring reference
  for **how to wire credential state at startup** (the wire_*
  pattern). Aeris's `wire_aeris_credentials()` follows this shape.
- `weewx_clearskies_api/services/station.py` — `get_station_info()`
  exposes `latitude`, `longitude`, `timezone`. Aeris module reads from
  this, not from weewx.conf.
- `weewx_clearskies_api/services/units.py` — `get_target_unit()` returns
  the `target_unit` string. Endpoint passes this through to
  `aeris.fetch()`.
- `weewx_clearskies_api/config/settings.py:347 ForecastSettings` — extend
  with the two Aeris credential fields per scope item 3 above. Mirror
  the `nws_user_agent_contact` env-loading pattern but ALSO initialize
  from env vars (NOT from `[forecast]` INI section — credentials per
  ADR-027 §3). Existing fields: `provider`, `nws_user_agent_contact`.
  Add: `aeris_client_id`, `aeris_client_secret`. The `validate()`
  method needs no change (provider-id whitelist already includes
  `aeris`; missing-credential KeyInvalid fires at fetch time, not
  startup, per lead-call 12).
- `weewx_clearskies_api/__main__.py` — **already calls
  `forecast.wire_forecast_settings(settings)`**. The new
  `wire_aeris_credentials()` is invoked from inside that wrapper —
  zero new calls in `__main__.py`.
- `weewx_clearskies_api/errors.py` — RFC 9457 + ProviderError handler is
  wired. Aeris errors flow through unchanged.
- `weewx_clearskies_api/models/responses.py` — canonical
  `HourlyForecastPoint`, `DailyForecastPoint`, `ForecastDiscussion`,
  `ForecastBundle`, `ForecastResponse` already exist. **No new
  canonical types this round.**
- `weewx_clearskies_api/models/params.py` — `ForecastQueryParams` already
  exists with `hours` + `days` validation. **No change.**
- `weewx_clearskies_api/endpoints/forecast.py` — endpoint handler
  already exists with `_get_forecast_params` Depends wrapper, two
  dispatch branches (openmeteo, nws), no-provider-configured path.
  Add: `wire_aeris_credentials()` helper, extension to
  `wire_forecast_settings()` to call it, `elif provider_id == "aeris":`
  dispatch branch (mirrors `nws` branch shape with credentials passed
  in addition to lat/lon/target_unit).
- `weewx_clearskies_api/app.py` — **no change** (forecast router already
  registered).
- `weewx_clearskies_api/logging/redaction_filter.py` — extend per scope
  item 6 + lead-call 23. **One new pattern entry only.**

`pyproject.toml` runtime deps already cover this round: `httpx`,
`redis`, `pydantic`, `cachetools`, `configobj`, `fastapi`, `sqlalchemy`.
**No new runtime or dev-extras deps this round.** Specifically: NO
`requests`, NO `aiohttp`, NO `tenacity`, NO `pyyaml`. STOP and ping the
lead if you think you need anything else.

---

## Per-endpoint spec

### `GET /forecast` — `aeris` dispatch branch

The `/forecast` endpoint shape is unchanged. The new dispatch branch
mirrors the `nws` branch:

- **Branch (after `elif provider_id == "nws":`):**

  ```python
  elif provider_id == "aeris":
      from weewx_clearskies_api.providers.forecast import aeris  # noqa: PLC0415

      bundle = aeris.fetch(
          lat=station.latitude,
          lon=station.longitude,
          target_unit=target_unit,
          client_id=_aeris_client_id,
          client_secret=_aeris_client_secret,
      )
  ```

- **Module-level state added to `endpoints/forecast.py`:**

  ```python
  _aeris_client_id: str | None = None
  _aeris_client_secret: str | None = None


  def wire_aeris_credentials(client_id: str | None, client_secret: str | None) -> None:
      """Store Aeris credentials read from env vars at startup.

      Per ADR-027 §3, secrets come from env vars (loaded by systemd
      EnvironmentFile / docker-compose env_file).  Tests that don't care
      about Aeris leave both as None; if `[forecast] provider = aeris`
      and credentials are unset, the module raises KeyInvalid at fetch
      time per lead-call 12 (loud failure beats silent disable).
      """
      global _aeris_client_id, _aeris_client_secret  # noqa: PLW0603
      _aeris_client_id = client_id
      _aeris_client_secret = client_secret
  ```

- **`wire_forecast_settings()` extension** (existing function in
  `endpoints/forecast.py`):

  ```python
  def wire_forecast_settings(settings: object) -> None:
      """Wire forecast-related settings from the Settings object.

      Convenience wrapper for __main__.py — extracts NWS UA contact and
      Aeris credentials from settings.forecast and calls the per-provider
      wire_*() helpers.  Tests inject Settings directly or call the
      individual wire_* helpers.
      """
      forecast_settings = getattr(settings, "forecast", None)
      contact = getattr(forecast_settings, "nws_user_agent_contact", None)
      wire_nws_user_agent_contact(contact)

      aeris_id = getattr(forecast_settings, "aeris_client_id", None)
      aeris_secret = getattr(forecast_settings, "aeris_client_secret", None)
      wire_aeris_credentials(aeris_id, aeris_secret)
  ```

- **Behaviour decision tree extension (call 6 in existing endpoint):**

  Existing branches 1-5 unchanged. New branches for Aeris:
  - `[forecast] provider = aeris` and Aeris returns 200 with valid
    response → normalize per canonical-data-model §4.1.2 / §4.1.3;
    return 200 with `discussion=null`.
  - `[forecast] provider = aeris` and credentials unset → module raises
    `KeyInvalid` → 502 ProviderProblem.
  - `[forecast] provider = aeris` and Aeris returns 401 → module raises
    `KeyInvalid` (per `exc.status_code == 401`) → 502 ProviderProblem
    with `errorCode="KeyInvalid"`.
  - `[forecast] provider = aeris` and Aeris returns 429 → `QuotaExhausted`
    → 503 ProviderProblem + Retry-After.
  - `[forecast] provider = aeris` and Aeris returns 200 with
    `success=false` envelope → `ProviderProtocolError` → 502
    (the canonical-protocol-violation path; Aeris HTTP-level success
    but JSON-level failure).
  - `[forecast] provider = aeris` and Aeris returns 200 with
    `success=true, error={code:"warn_location", …}` warning AND empty
    `response=[]` → `ForecastBundle(hourly=[], daily=[], …)` returned;
    log WARN (lead-call 17). NOT a hard error.
  - `[forecast] provider = aeris` and wire-shape Pydantic validation
    fails → `ProviderProtocolError` → 502 with full response body
    logged at ERROR.
  - `[forecast] provider = aeris` and network failure / 5xx after retries
    → `TransientNetworkError` → 502 ProviderProblem.

- **Cache integration.** Module calls `cache.get(key)` first; key per
  ADR-017 is sha256 of `(provider_id="aeris",
  endpoint="forecast_bundle", normalized_params={"latitude":
  round(lat, 4), "longitude": round(lon, 4), "target_unit":
  target_unit})`. Cache stores the post-normalization `ForecastBundle`
  as a `model_dump(mode="json")`-ed dict; cache-read reconstructs via
  `ForecastBundle.model_validate(cached)`. TTL = 1800s.
  **`endpoint="forecast_bundle"`** is a deliberate logical key
  covering the two upstream calls (matches NWS's pattern from 3b-3).

---

## Per-module spec — `providers/forecast/aeris.py`

Five responsibilities per ADR-038 §2. Module structure mirrors
`providers/forecast/openmeteo.py` (single-domain, single-bundle-shape) —
five sections in the same order.

### Module-level constants

```python
PROVIDER_ID = "aeris"
DOMAIN = "forecast"
AERIS_BASE_URL = "https://data.api.xweather.com"
AERIS_FORECASTS_PATH = "/forecasts"
DEFAULT_FORECAST_TTL_SECONDS = 1800   # 30 min per ADR-017
HOURLY_LIMIT = 240                     # 10 days × 24h, comfortably above 384h cap
DAYNIGHT_LIMIT = 14                    # 7 days × 2 (paired)

_API_VERSION = "0.1.0"

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
        "weatherCode", "weatherText",
        # ForecastDiscussion — declared as max-surface; populated only on
        # paid-tier responses where summary field is present (Q2 user
        # decision, lead-call 14).
        "headline", "body",
        # NB: narrative NOT supplied by Aeris v0.1 (lead-call 20)
    ),
    geographic_coverage="global",   # see lead-call 17
    auth_required=("client_id", "client_secret"),
    default_poll_interval_seconds=DEFAULT_FORECAST_TTL_SECONDS,
    operator_notes=(
        "Aeris (AerisWeather/Xweather) free-tier and entry-paid plans. "
        "Requires client_id + client_secret bound to a registered domain "
        "or bundle id (see api-docs/aeris.md §Authentication). Forecast "
        "discussion populated when paid-tier summary field is present; "
        "free-tier returns bundle.discussion=null. Coverage: per Aeris's "
        "authoritative answer; module surfaces warn_location warnings "
        "as empty bundle."
    ),
)

# Aeris weather descriptor codes → canonical precipType (lead-call 16)
_AERIS_DESCRIPTOR_TO_PRECIP_TYPE: dict[str, str] = {
    # rain family
    "R": "rain", "RW": "rain", "L": "rain",
    # snow family
    "S": "snow", "SW": "snow",
    # freezing
    "ZR": "freezing-rain", "ZL": "freezing-rain",
    # ice/sleet
    "IP": "sleet",
    # hail
    "A": "hail",
    # thunder accompanies rain in canonical framing
    "T": "rain",
    # mixed precip → rain (canonical has no mixed-precip enum)
    "RS": "rain", "WM": "rain", "SI": "rain",
    # everything else (clouds, fog, etc.) → None
}
```

### Wire-shape Pydantic models

`extras="ignore"` so Aeris additions don't break us; missing required
fields raise `ValidationError` → translated to `ProviderProtocolError`.
Aeris responses are row-oriented (`periods[]` array); the Pydantic model
mirrors the row shape directly (no zip step like Open-Meteo).

```python
class _AerisLoc(BaseModel):
    model_config = ConfigDict(extra="ignore")
    lat: float
    long: float


class _AerisProfile(BaseModel):
    model_config = ConfigDict(extra="ignore")
    tz: str | None = None
    elevFT: float | None = None
    elevM: float | None = None


class _AerisHourlyPeriod(BaseModel):
    """One hourly period from /forecasts?filter=1hr."""
    model_config = ConfigDict(extra="ignore")
    timestamp: int
    dateTimeISO: str
    tempC: float | None = None
    tempF: float | None = None
    humidity: float | None = None
    pop: float | None = None
    windSpeedKPH: float | None = None
    windSpeedMPH: float | None = None
    windSpeedMPS: float | None = None
    windDirDEG: float | None = None
    windGustKPH: float | None = None
    windGustMPH: float | None = None
    windGustMPS: float | None = None
    precipMM: float | None = None
    precipIN: float | None = None
    sky: float | None = None
    weather: str | None = None
    weatherPrimaryCoded: str | None = None


class _AerisDayNightPeriod(BaseModel):
    """One paired day/night period from /forecasts?filter=daynight."""
    model_config = ConfigDict(extra="ignore")
    timestamp: int
    dateTimeISO: str
    maxTempC: float | None = None
    maxTempF: float | None = None
    minTempC: float | None = None
    minTempF: float | None = None
    pop: float | None = None
    precipMM: float | None = None
    precipIN: float | None = None
    windSpeedMaxKPH: float | None = None
    windSpeedMaxMPH: float | None = None
    windSpeedMaxMPS: float | None = None
    windGustMaxKPH: float | None = None
    windGustMaxMPH: float | None = None
    windGustMaxMPS: float | None = None
    sunriseISO: str | None = None
    sunsetISO: str | None = None
    uvi: float | None = None
    weather: str | None = None
    weatherPrimaryCoded: str | None = None


class _AerisForecastResponse(BaseModel):
    """Top-level Aeris /forecasts response (single-location action).

    aeris.md §"Response format conventions" notes /forecasts ALWAYS
    returns response as an array even for single-location queries.
    Module reads response[0] for the single-station-scope use case
    (ADR-011).
    """
    model_config = ConfigDict(extra="ignore")
    success: bool
    error: dict[str, Any] | None = None
    response: list[dict[str, Any]] = Field(default_factory=list)
```

### `fetch(*, lat, lon, target_unit, client_id, client_secret) -> ForecastBundle` — public entrypoint

Single callable. Returns canonical `ForecastBundle` (Pydantic model — NOT
a dict; per F12 lesson from 3b-1).

Sketch (api-dev fills in details):

```python
def fetch(
    *,
    lat: float,
    lon: float,
    target_unit: str,
    client_id: str | None,
    client_secret: str | None,
) -> ForecastBundle:
    """Call Aeris /forecasts twice and return canonical ForecastBundle.

    Two outbound calls per cache miss (lead-call 11):
      1. GET /forecasts/{lat,lon}?filter=1hr&limit=240
      2. GET /forecasts/{lat,lon}?filter=daynight&limit=14

    Bundle ships with discussion=None always (lead-call 14).

    Raises canonical ProviderError taxonomy on failure.  KeyInvalid when
    credentials missing or Aeris returns 401 (lead-call 12).
    """
    # Pre-flight credential check (loud over silent).
    if not client_id or not client_secret:
        raise KeyInvalid(
            "Aeris credentials missing — set "
            "WEEWX_CLEARSKIES_AERIS_CLIENT_ID and "
            "WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET",
            provider_id=PROVIDER_ID, domain=DOMAIN,
        )

    cache_key = _build_cache_key(lat, lon, target_unit)
    cached = get_cache().get(cache_key)
    if cached is not None:
        return ForecastBundle.model_validate(cached)

    client = _client_for()
    base_params = {
        "client_id": client_id,
        "client_secret": client_secret,
    }
    location_path = f"{lat},{lon}"

    # Per-call acquire (lead-call 18) — rate limiter primitive.
    rate_limiter.acquire()
    hourly_response = client.get(
        f"{AERIS_BASE_URL}{AERIS_FORECASTS_PATH}/{location_path}",
        params={**base_params, "filter": "1hr", "limit": HOURLY_LIMIT},
    )
    rate_limiter.acquire()
    daynight_response = client.get(
        f"{AERIS_BASE_URL}{AERIS_FORECASTS_PATH}/{location_path}",
        params={**base_params, "filter": "daynight", "limit": DAYNIGHT_LIMIT},
    )

    # Wire-shape parse + envelope-success check.
    hourly_wire = _parse_aeris_envelope(hourly_response.json(), "hourly")
    daynight_wire = _parse_aeris_envelope(daynight_response.json(), "daynight")

    bundle = _to_canonical(
        hourly_periods=hourly_wire,
        daynight_periods=daynight_wire,
        target_unit=target_unit,
    )

    get_cache().set(
        cache_key,
        bundle.model_dump(mode="json"),
        ttl_seconds=DEFAULT_FORECAST_TTL_SECONDS,
    )
    return bundle
```

### `_to_canonical(...)` — wire → canonical

Per canonical-data-model §4.1.2 + §4.1.3 + §4.1.4 + lead-calls 13, 14,
15, 16, 19, 21, 22.

Constructs:
- `hourly: list[HourlyForecastPoint]` — one per `_AerisHourlyPeriod`
- `daily: list[DailyForecastPoint]` — one per `_AerisDayNightPeriod`
- `discussion: ForecastDiscussion | None` — runtime-detected from the
  daynight raw response per lead-call 14. Helper `_extract_aeris_discussion`
  walks `response[0].summary` and `response[0].periods[0].summary` looking
  for non-empty text. When found, constructs `ForecastDiscussion(
  headline=response[0].periods[0].weatherPrimary, body=<text>,
  source="aeris", issuedAt=<UTC-converted dateTimeISO>, validFrom=None,
  validUntil=None, senderName=None)`. When absent, returns None.
- `source: "aeris"`
- `generatedAt: utc_isoformat(now())`

### Helper functions

- `_parse_aeris_envelope(payload: dict, kind: str) -> tuple[list[<wire-period>], dict]`
  — checks `success`, raises `ProviderProtocolError` when False; checks
  `error` warning (lead-call 17) — `warn_location` returns empty list,
  other warnings raise `ProviderProtocolError`; reads `response[0].periods`
  and validates each row through the appropriate Pydantic model. Also
  returns the raw `response[0]` dict so the caller can pass it to
  `_extract_aeris_discussion` (the helper needs the raw dict to walk
  optional fields not in the strict Pydantic shape).
- `_pick_unit_field(period, target_unit, base_name) -> float | None`
  — given a wire period and `target_unit`, picks the right
  `<base>F`/`<base>C`/`<base>MPH`/`<base>KPH`/`<base>MPS` field. Per
  lead-call 13.
- `_aeris_descriptor_to_precip_type(coded: str | None) -> str | None`
  — parses third colon-segment of `weatherPrimaryCoded`; looks up in
  the `_AERIS_DESCRIPTOR_TO_PRECIP_TYPE` table; unknown → `None` (log
  DEBUG once on first encounter per descriptor).
- `_extract_aeris_discussion(daynight_response_obj: dict) -> ForecastDiscussion | None`
  — runtime-detection per Q2 user decision + lead-call 14. Walks
  `daynight_response_obj.get("summary")` and
  `daynight_response_obj.get("periods", [{}])[0].get("summary")`
  looking for non-empty string. Returns populated ForecastDiscussion
  or None. Logs at INFO on first paid-tier-summary detection so the
  operator gets visibility ("Aeris discussion text detected; surfacing
  in /forecast bundle"). **STOP-and-ping if neither candidate field
  appears in real captured paid-tier fixtures** — see lead-call 14.
- `_build_cache_key(lat, lon, target_unit) -> str` — sha256 of
  json-encoded normalized params (matches the pattern from openmeteo +
  nws).
- `_client_for() -> ProviderHTTPClient` — module-level singleton;
  constructed on first call. UA = `(weewx-clearskies-api/<version>)`
  (no operator contact knob; Aeris doesn't require one).

---

## Cross-cutting requirements

### Pydantic + `Depends(_get_forecast_params)` pattern

Already in `endpoints/forecast.py`. **No change.** New dispatch branch
inherits the wrapper.

### RFC 9457 errors

The existing `errors.py` ProviderError handler covers Aeris errors
unchanged. ProviderProblem extension fields (`providerId="aeris"`,
`domain="forecast"`, `errorCode`, optional `retryAfterSeconds`) come
for free.

### Logging (ADR-029)

- Provider HTTP outbound calls log at INFO with: `provider_id="aeris"`,
  `domain="forecast"`, URL (with `client_id` AND `client_secret` query
  params PRESENT in the URL string — **the redaction filter strips
  them before formatter emits**), `elapsed_ms`, `status_code`.
- On error: WARNING (transient) or ERROR (protocol).
- Cache hit/miss counters at DEBUG.
- **Verify in tests** that a logged URL like
  `https://data.api.xweather.com/forecasts/47.6,-122.3?filter=1hr&limit=240&client_id=ABC123&client_secret=DEF456`
  emits with both `[REDACTED]` after the filter runs.

### Catch specific exceptions

Per `rules/coding.md` §3. Aeris module never uses `except Exception:`.
Catches: `pydantic.ValidationError` (wire-shape validation), `httpx`-
raised classes are translated by `ProviderHTTPClient`, `KeyError` /
`IndexError` / `TypeError` are NOT expected and pass-through (real bugs
should fail the test suite, not be swallowed).

### Dispatch on exception state via attributes (lead-call 9, `rules/coding.md` §3)

```python
# CORRECT
if exc.status_code == 401:
    raise KeyInvalid(...) from exc

# WRONG — do not do this
if "401" in str(exc):
    ...
```

### Commit early and often (`.claude/agents/clearskies-api-dev.md`)

After each meaningful chunk of work (new file written, helper added,
tests passing), `git add` + `git commit -s` + `git push origin main` +
`SendMessage` to lead. Don't accumulate hours of uncommitted work.
TaskStop / session-limit / idle-bug kills lose anything not committed-
and-pushed.

---

## Test author parallel scope

Per `.claude/agents/clearskies-test-author.md`. Scope mirrors 3b-3:

### Test files to add

- `tests/test_providers_forecast_aeris_unit.py` — unit suite. Real
  recorded fixtures + `respx` for outbound-call mocking. Coverage:
  - `_AerisHourlyPeriod` / `_AerisDayNightPeriod` Pydantic validation
    against captured fixture (success path).
  - `_aeris_descriptor_to_precip_type` table coverage (every entry,
    plus unknown-descriptor → None, plus None input).
  - `_pick_unit_field` for each `target_unit` × each base_name (`temp`,
    `windSpeed`, `windGust`, `precip`, etc.).
  - `_to_canonical` zips hourly + daily correctly; `source="aeris"`;
    discussion field reflects detection result (see below).
  - `_extract_aeris_discussion` (Q2 runtime-detection per lead-call 14):
    - response with non-empty `response[0].summary` → returns a
      ForecastDiscussion with body=<that string>, headline=
      `periods[0].weatherPrimary`, issuedAt=<converted>, source="aeris".
    - response with non-empty `response[0].periods[0].summary` → same
      shape (alternate detection point).
    - response with neither field set → returns None.
    - response with empty/whitespace-only summary → returns None.
  - `fetch()` cache-miss path: two outbound calls, response cached.
  - `fetch()` cache-hit path: zero outbound calls, returned bundle
    matches cached. Cached discussion=None and cached
    discussion=ForecastDiscussion(...) both round-trip correctly.
  - `fetch()` missing-credential KeyInvalid (lead-call 12).
  - Error-shape tests:
    - 401 → KeyInvalid (per `exc.status_code == 401`, lead-call 9).
    - 429 → QuotaExhausted.
    - 5xx → TransientNetworkError.
    - 200 + `success=false` → ProviderProtocolError.
    - 200 + `success=true, error={code:"warn_location"}` → empty bundle
      (lead-call 17).
    - Pydantic ValidationError on malformed wire shape → ProviderProtocolError.
  - **Redaction-filter test:** logged URL with `client_id=ABC123` and
    `client_secret=DEF456` query params has BOTH redacted in the
    captured log output (lead-call 23).
- `tests/test_providers_forecast_aeris_integration.py` — integration
  suite. Both cache backends covered:
  - Memory cache miss → fetch → cache hit.
  - Redis cache (marked `@pytest.mark.redis`) miss → fetch → cache hit.
  - **Brief gate:** Redis tier MUST PASS, not skip (3b-3 carry-forward).
- Endpoint integration in `tests/test_endpoints_forecast_integration.py`
  (extend, don't replace): `[forecast] provider = aeris` happy path
  through the dispatch branch.

### Fixture capture

- `tests/fixtures/providers/aeris/forecasts_hourly.json` — `/forecasts/
  {lat},{lon}?filter=1hr` real captured response. Sidecar `.md` records
  capture date, lat/lon, Aeris account-tier.
- `tests/fixtures/providers/aeris/forecasts_daynight.json` — same shape
  for `?filter=daynight` from a real account. **Free-tier shape: no
  `summary` field expected.** Sidecar documents which tier was captured.
- `tests/fixtures/providers/aeris/forecasts_daynight_with_summary.json`
  — synthetic OR captured paid-tier response that carries a
  non-empty `response[0].summary` (or `response[0].periods[0].summary`)
  to exercise the runtime-detection happy path. If a real paid-tier
  fixture isn't available, hand-craft one based on the free-tier
  capture + an injected `summary` string. Test-author signals via
  SendMessage which path was used (real vs synthetic).
- `tests/fixtures/providers/aeris/error_401_invalid_credentials.json`
  — Aeris's documented 401 envelope shape.
- `tests/fixtures/providers/aeris/error_429_rate_limit.json` — 429
  envelope.
- `tests/fixtures/providers/aeris/error_warn_invalid_location.json` —
  `success=true, error={code:"warn_location"}, response=[]`.

**Where to capture from:** real Aeris account (xweather.com developer
trial, free tier). The same account that exercised Belchertown's
existing Aeris integration is fine.

### Fixture sidecar discipline (3b-1 carry-forward)

- One sidecar `.md` per fixture documenting: capture date (ISO), lat/lon,
  Aeris account-tier, any redacted fields.
- Real `client_id`/`client_secret` MUST NOT appear in committed fixtures.
  Fixture URLs in tests use placeholder values; live capture replaces
  the credentials in the response with the literal token `[REDACTED]`
  before commit.

### Brief-gate honesty (`.claude/agents/clearskies-test-author.md`)

If a brief gate cannot be met (e.g., redis backend unavailable on
weather-dev), surface via `SendMessage` BEFORE submitting the closeout.
Don't quietly mark Redis-tier tests as "skipped" — that violates the
brief and the auditor will catch it.

---

## Process gates — pytest must pass on weather-dev BEFORE audit

Same gate as 3b-3, no looser. Both api-dev and test-author MUST run
their pre-submit pytest on `weather-dev` and report results via
`SendMessage` before submitting closeout. The auditor reviews
post-pytest.

### Per-tier expected baseline (post-3b-4 close)

The following targets are EXPECTED at 3b-4 close. Anything else triggers
investigation, not silent skip.

| Tier | Pre-3b-4 baseline | 3b-4 target |
|---|---|---|
| Default (`pytest`) | 764 / 0 / 0 in 7:48 | ~830-870 / 0 / 0 (Aeris unit tests added) |
| Integration MariaDB (`pytest -m integration`) | 177 / 27 skipped / 0 | ~200 / 27 skipped / 0 |
| Integration SQLite (`pytest -m integration`) | 184 / 20 skipped / 0 | ~205 / 20 skipped / 0 |
| Redis (`CLEARSKIES_CACHE_URL=redis://… pytest -m "integration and redis"`) | 5 / 0 / 0 in 1.79s | ≥6 / 0 / 0 (Aeris Redis test added) |

**Brief gate (3b-3 carry-forward):** Redis tier MUST PASS, not skip.

### Pull-then-pytest gate (api-dev's hard gate)

Before pre-submit pytest, api-dev runs:

```bash
git fetch origin main
git merge --ff-only origin/main
```

So the pytest run includes test-author's parallel commits. Round 1 of
3a-1 reported "0 failures" without this fetch; test-author's later run
found 3 real bugs that fail the parallel-pulled suite.

---

## STOP triggers — message the lead immediately

Per the `.claude/agents/clearskies-api-dev.md` constraint "tests verify
the brief; the brief is the authority":

- **Test signature ≠ brief signature.** If test-author's test of
  `aeris.fetch(...)` calls a different signature than the brief's
  per-module spec, **STOP and message the lead.** Do NOT flip the impl
  to match the tests — the brief is authoritative; tests verify the
  brief.
- **Impl matches canonical but diverges from brief.** If the brief says
  one thing and the canonical says another and api-dev's impl matches
  the canonical, **STOP and ping the lead** before committing — this is
  the 3b-2 F2 pattern. Lead amends the brief or asks api-dev to honor it.
- **ADR conflict.** If implementing leads to a clear ADR violation that
  the brief didn't surface, STOP. Don't override silently.
- **Q1 / Q2 above.** Both are user sign-off questions. Until user has
  signed off (or lead has confirmed lead-call), api-dev does NOT commit
  the affected code. Lead surfaces the answers before api-dev needs them.
- **Unexpected wire-shape gap.** If `windSpeedMaxMPS` (or any other
  expected Aeris field) is absent from a captured fixture against
  lead-call 13's assumption, STOP and ping. Do NOT silently fall back
  to a different unit conversion.

---

## Commit hygiene

- Per-module-feature commits: one for the new `providers/forecast/aeris.py`,
  one for the `dispatch.py` row + `endpoints/forecast.py` extension +
  `settings.py` extension, one for the `redaction_filter.py` extension,
  one per test module. Don't bundle.
- Commit messages document non-obvious provenance (3a-2 round 2 lesson).
  Multi-line messages on PowerShell use `git commit -F c:\tmp\3b-4-msg-
  <subject>.txt` (3b-3 close lesson).
- `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` trailer on
  api-dev / test-author commits; `Co-Authored-By: Claude Opus 4.7 (1M
  context) <noreply@anthropic.com>` on lead-direct commits.

---

## Multi-agent execution carry-forward

Unchanged from 3b-3:

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json`.
- 6 agents in `.claude/agents/`. Lead = Opus. Sonnet teammates implement;
  Opus auditor reviews. Active team size 3-5; auditor counts toward the
  limit.
- Windows = in-process mode only.
- Lead pings teammates at every user-prompt boundary if silent for >~4
  minutes since last commit (poll-don't-wait rule).
- Lead-direct remediation when post-audit fixes are ≲50 lines / ≲3 files.

### Spawn prompts MUST restate

- The Mid-flight SendMessage cadence (don't trust agent-def auto-load).
- The "no >5 min in pure file-reading without a SendMessage" research-
  mode mitigation.
- The "commit early and often" rule.

### Branching policy

No feature branches. Commit straight to default branch (`main` on api,
`master` on meta). DCO + Co-Authored-By trailer on every commit.

### Dev environment

DILBERT (Windows) edit-only. weather-dev LXD container at 192.168.2.113
on ratbert for runtime work. Sync via `scripts/sync-to-weather-dev.sh`
after pushing. pytest never runs on DILBERT.
