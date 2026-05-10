# Phase 2 task 3b round 8 brief — clearskies-api alerts domain (OpenWeatherMap)

**Round identity.** Phase 2 task 3 sub-round 3b round 8. **Closes the alerts
domain.** First two alerts providers landed in 3b-1 (NWS) and 3b-7 (Aeris) per
ADR-016. This round adds OpenWeatherMap as the third (last) day-1 alerts
provider — sixth concrete provider integration on this project; third module to
consume the `/data/3.0/onecall` endpoint after 3b-5 (OWM forecast). The
forecast module already excludes alerts via `exclude=current,minutely,alerts`;
this alerts module fires a SEPARATE outbound call with
`exclude=current,minutely,hourly,daily` (alerts-only payload). Two distinct
cache entries, two outbound paths, one shared appid env var.

This is a **single-deliverable round.** Shared infrastructure (HTTP wrapper with
`status_code`-bearing canonical exceptions, retry, error taxonomy, capability
registry, cache backends, rate limiter, `epoch_to_utc_iso8601` datetime helper)
lives. The `/alerts` endpoint at `endpoints/alerts.py` has two dispatch branches
(`nws`, `aeris`); this round adds a third. `AlertRecord`, `AlertList`, and
`AlertListResponse` canonical types live. The redaction filter at
`logging/redaction_filter.py` already covers `appid` from 3b-1. This round
adds:

1. **`weewx_clearskies_api/providers/alerts/openweathermap.py`** — third
   concrete alerts provider per ADR-016 + ADR-038. Five module
   responsibilities; structural twin of `providers/alerts/nws.py` (single
   canonical AlertList shape) + reuses keyed-provider patterns from
   `providers/forecast/openweathermap.py` (One Call 3.0 endpoint, `appid`
   query auth, basic-tier 401 → graceful empty result per Q1 user decision).
2. **One new row in `_common/dispatch.py`** —
   `("alerts", "openweathermap") → providers.alerts.openweathermap`.
3. **`openweathermap_appid` field on `AlertsSettings`** sourced from the same
   env var `ForecastSettings` reads (`WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID`).
   Provider-scoped per 3b-5 brief Q2 user decision 2026-05-08; same key works
   across forecast + alerts (mirrors 3b-7 Aeris precedent). Loaded at
   `__init__` per ADR-027 §3 (secrets never in INI).
4. **`wire_openweathermap_credentials()` helper in `endpoints/alerts.py`** —
   mirror-pattern of `endpoints/forecast.py wire_openweathermap_credentials()`
   and `endpoints/alerts.py wire_aeris_credentials()`. Extend
   `wire_alerts_settings()` to call it.
5. **`elif provider_id == "openweathermap":` dispatch branch in
   `endpoints/alerts.py`** — passes lat/lon + appid to
   `openweathermap.fetch()`.

**No redaction-filter changes** — `appid` redaction already shipped in 3b-1
(`_APPID_RE`). Verify in test by adding a logged-URL redaction assertion to
the new OWM alerts unit suite (mirror of 3b-5). **No `__main__.py` changes**
— `wire_alerts_settings()` is already called and extends transparently. **No
canonical-data-model or OpenAPI changes** — `AlertRecord` and `/alerts`
contract are unchanged. **No new ADRs** — ADR-016 already prescribes OWM as
the third day-1 alerts provider.

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after both
submit and pytest is green on `weather-dev`.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` (clone of
`github.com/inguy24/weewx-clearskies-api`). **Default branch `main`** (verified
2026-05-10 against `git symbolic-ref refs/remotes/origin/HEAD`). Parallel-pull
command: `git fetch origin main && git merge --ff-only origin/main`. The
meta-repo (this `weather-belchertown/` workspace) is `master`.

**Pre-round HEADs verified 2026-05-10:**
- api repo: `5e64cd1` (3b-7 audit remediation: F1 + F2 + F3 + F4 lead-direct)
- meta repo: `671480d` (3b-7 close: Aeris alerts + canonical amendment + 4
  audit findings + 1 new rule)
- weather-dev: `5e64cd1` (already up to date)

**Pytest baseline at `5e64cd1` (trusted from 3b-7 close, <24h ago):**
- Default + integration combined: 1392 / 37 skipped / 0 failed
- Redis tier (CLEARSKIES_CACHE_URL=redis://127.0.0.1:6380/0 +
  `integration and redis`): 15 / 0

---

## Cross-check audit — canonical §4.3 OWM column vs api-docs example response

**NEW RULE FIRES THIS ROUND** (added to `rules/clearskies-process.md` 2026-05-09
at 3b-7 close, lessons triage P2): "Cross-check canonical mapping cells against
api-docs example responses at brief-draft." The rule exists to pre-empt the
canonical-vs-real-wire mismatch class that triggered 3b-7's mid-flight
amendment. Below is the brief-draft cross-check for every canonical §4.3 OWM
mapping cell against `docs/reference/api-docs/openweathermap.md` L161-213
example response (the One Call 3.0 alerts[] entry at L203-211).

| Canonical (§4.3 OWM column) | Wire path | api-docs example confirms? | Notes |
|---|---|---|---|
| `id` | concat(`event` + `start` + `sender_name`) | ✓ — all three source fields present | Synthetic id (OWM wire has no stable alert id). Operationalization in lead-call 13. |
| `headline` | `event` | ✓ — example: `"event": "Wind Advisory"` | Direct passthrough. |
| `description` | `description` | ✓ — example: `"description": "* WHAT...Southerly winds..."` | Direct passthrough; no NWS-style `instruction` append (OWM has no equivalent). |
| `severity` | severity-mapping from `event` keyword | ✓ — example `event` = `"Wind Advisory"` exercises the `*Advisory*` row → `advisory` | Substring/keyword match table in lead-call 12. |
| `urgency` | (not provided) | ✓ — confirmed absent from example | PARTIAL-DOMAIN per L1; not in CAPABILITY (lead-call 16). |
| `certainty` | (not provided) | ✓ — confirmed absent from example | PARTIAL-DOMAIN; not in CAPABILITY. |
| `event` | `event` | ✓ — example: `"event": "Wind Advisory"` | Direct passthrough; canonical `event` is "Provider's event name" (§3.6 — `"Wind Advisory"` matches the human-readable definition exactly). |
| `effective` | `start` (epoch s, convert) | ✓ — example: `"start": 1714485600` | epoch_to_utc_iso8601 — DRY reuse of helper from 3b-5 (lead-call 14). |
| `expires` | `end` (epoch s, convert) | ✓ — example: `"end": 1714521600` | epoch_to_utc_iso8601 (lead-call 14). |
| `senderName` | `sender_name` | ✓ — example: `"sender_name": "NWS Seattle WA"` | Direct passthrough. Wire field is `sender_name` (snake_case), canonical is `senderName` (camelCase). |
| `areaDesc` | (not provided) | ✓ — confirmed absent from example | PARTIAL-DOMAIN; not in CAPABILITY. |
| `category` | (not provided) | ✓ — confirmed absent from example | PARTIAL-DOMAIN; not in CAPABILITY. |

**Wire fields NOT mapped to canonical:**

- `tags` (example: `"tags": ["Wind"]`) — wire surfaces tags array; canonical
  AlertRecord has no `extras` field per §3.6. Tags drop silently. This is
  consistent with the canonical contract (no extras bag on alerts); no
  ambiguity to surface.

**Verdict: no canonical-vs-wire mismatches to surface.** The full OWM column in
§4.3 maps cleanly against the api-docs example. No canonical-data-model
amendment required. No mid-flight rewrite class triggered. This brief proceeds
on solid canonical-wire ground.

---

## Scope — 1 provider module + plumbing

| # | Unit | Notes |
|---|---|---|
| 1 | `weewx_clearskies_api/providers/alerts/openweathermap.py` | New file. **One outbound call per cache miss:** `GET /data/3.0/onecall?lat=&lon=&appid=&exclude=current,minutely,hourly,daily`. Returns `alerts[]` array only (may be empty when no active alerts). Same endpoint as 3b-5 forecast/owm but with different `exclude` set. |
| 2 | `_common/dispatch.py` | Add `("alerts", "openweathermap") → providers.alerts.openweathermap` row. One import + one entry. |
| 3 | `config/settings.py` `AlertsSettings` | Add `openweathermap_appid: str \| None` field populated from env var `WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID` at `__init__` (NOT from `[alerts]` INI section — secrets per ADR-027 §3). Update `validate()` so existing logic still passes. |
| 4 | `endpoints/alerts.py` | Add module-level `_openweathermap_appid` + `wire_openweathermap_credentials()` (mirror `endpoints/forecast.py`). Extend `wire_alerts_settings()` to also call it. Add `elif provider_id == "openweathermap":` dispatch branch. |
| 5 | `__main__.py` | **No change** — already calls `alerts.wire_alerts_settings(settings)`. The new `wire_openweathermap_credentials()` plugs into that wrapper transparently. |
| 6 | Recorded fixtures | `tests/fixtures/providers/openweathermap/alerts_paid.json` (One Call 3.0 with alerts[] populated; synthetic-from-api-docs-example per L3 since no paid access likely available), `alerts_paid_empty.json` (paid response with `alerts: []`), `alerts_basic_tier_401.json` (basic-tier 401; may reuse from 3b-5 forecast fixtures), `alerts_error_429.json`. Sidecar `.md` documents synthetic origin clearly. |

**Out of scope this round (defer to later 3b rounds / Phase 3+ / Phase 4):**

- **Setup-wizard region-based provider suggestion** (ADR-016 §Decision +
  ADR-027). Phase 4.
- **Operator overrides for alerts TTL or rate-limit.** Uses ADR-017's default
  300s for alerts; same as NWS + Aeris.
- **All other provider domains.** /aqi/* /earthquakes /radar/* are separate 3b
  rounds (3b-9 onward).
- **Multi-source aggregation across alerts providers** (ADR-016 §B rejected).
  Single source per deploy.
- **OWM `tags` array surfacing.** Wire field exists; canonical AlertRecord has
  no `extras` bag (§3.6); drop silently. Future canonical-amendment work could
  add an alerts `extras` field if dashboard demand surfaces; not v0.1.
- **OWM AI weather summary** (`/data/3.0/onecall/overview`). Out of scope for
  v0.1 same as 3b-5.
- **Reusing the 3b-5 forecast module's `_OWMOneCallResponse` wire model.**
  The forecast module's wire model excludes the `alerts[]` field (forecast
  excludes alerts via URL param); the alerts module needs a fresh wire model
  enumerating `alerts[]` only. Cross-module coupling at the wire-model level
  would force a refactor when either module's exclude set changes. Keep the
  models separate; both files reuse the SAME `epoch_to_utc_iso8601()` helper
  from `_common/datetime_utils.py` (DRY).
- **OWM language/locale param.** Same disposition as 3b-5: defaults to English;
  dashboard handles i18n catalog. Future enhancement.

---

## Lead-resolved calls (no user sign-off needed — ADRs and contracts settle these)

The "Brief questions audit themselves before draft" rule
(`rules/clearskies-process.md`) requires every "open question" to be audited
against the ADRs first. The "brief-vs-canonical cross-check" rule (3b-2 F2) +
the NEW "canonical-vs-api-docs cross-check" rule (3b-7) require every
lead-resolved call to cross-check against `canonical-data-model.md` +
`openapi-v1.yaml` + the relevant api-docs file before drafting. All three
audits performed; every call below has been verified against all three.
Numbered for reference, not for sign-off.

### Inherited from prior 3b rounds (no change, no re-audit needed)

1. **HTTP client = `httpx` (sync).** `ProviderHTTPClient` from
   `_common/http.py`. Already covers TLS, timeouts, retry/backoff, error-class
   translation, structured `status_code` attribute on `ProviderError`,
   `retry_after_seconds` on quota errors, and 4xx body logging at ERROR.

2. **Alerts cache TTL = 300s (5 min).** ADR-016 §Polling cadence + ADR-017
   defaults table. Module's `CAPABILITY.default_poll_interval_seconds = 300`.
   Matches `providers/alerts/nws.py` and `providers/alerts/aeris.py`.

3. **Capability-registry populate path.** ADR-038 §3 + 3b-2's
   `_wire_providers_from_config()`. No change needed — adding the dispatch
   row in step 2 is enough; the existing `__main__.py` lookup picks
   `openweathermap` automatically when `[alerts] provider = openweathermap`.

4. **Both cache backends already live.** ADR-017 + 3b-1's `MemoryCache` +
   `RedisCache`. alerts/openweathermap consumes `get_cache()` like the other
   modules.

5. **No live-network tests in CI.** ADR-038 §Testing pattern. Recorded
   fixtures + `respx` for everything.

6. **Source field when no provider configured = literal `"none"`.**
   `endpoints/alerts.py` already does this (line 192); no change.

7. **OWM provider-scoped credential env var
   (`WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID`).** Locked by 3b-5 brief Q2 user
   decision 2026-05-08. Same key works for forecast + alerts (mirrors 3b-7
   Aeris precedent: `WEEWX_CLEARSKIES_AERIS_CLIENT_ID/_SECRET` works for both
   forecast + alerts). AlertsSettings reads the same env var; values match
   ForecastSettings at startup (env vars don't drift between init steps). No
   new env var introduced.

8. **OWM credentials missing → `KeyInvalid` early-raise at `fetch()` entry,
   before any HTTP call.** 3b-5 brief lead-call 14 carry-forward. Loud failure
   beats silent disable; operator intent to enable OWM alerts is unambiguous
   when `[alerts] provider = openweathermap`.

9. **Dispatch on exception state via attributes, not message strings.** Per
   `rules/coding.md` §3 (added 2026-05-08 from 3b-3 F2). OWM alerts module
   uses `exc.status_code == 401` for the basic-tier branch (Q1 USER
   DECIDED 2026-05-10 — see operationalization in Q1 section below). No `"X" in str(exc)` patterns.

10. **Bare `client.get()` calls — let canonical exceptions propagate; no
    narrow wraps.** L2 carry-forward (3b-4 audit F1). EXCEPT for the
    One-Call-401 → graceful empty list dispatch (Q1 USER DECIDED above + Q1 user
    decision below) which is an INTENTIONAL narrow swallow documented inline
    + commit body. Same exception-handling shape as 3b-5 forecast/owm.

11. **Synthetic-from-real fixture pattern when paid-tier provider access is
    unavailable.** L3 carry-forward (3b-4). For OWM, synthetic-from-api-docs-
    example pattern applies — `docs/reference/api-docs/openweathermap.md`
    L203-211 IS the literal wire shape the module parses. Sidecar `.md`
    documents synthetic origin clearly: "synthetic-from-api-docs/openweathermap.md
    L203-211 — fields mirrored, not captured live." Same approach as 3b-5
    forecast/owm fixtures.

12. **Severity normalization (canonical-data-model §4.3 verbatim).** OWM wire
    has no severity field; severity is derived from the `event` keyword via
    case-insensitive substring match per the §4.3 table:
    - `*Warning*` (e.g., "Tornado Warning") → `"warning"`
    - `*Watch*` (e.g., "Severe Thunderstorm Watch") → `"watch"`
    - `*Advisory*` / `*Statement*` (e.g., "Wind Advisory") → `"advisory"`
    - (other / no match) → `"advisory"` (default to least-severe per NWS
      precedent in 3b-1 + Aeris precedent in 3b-7).

    Helper `_owm_severity_from_event(event: str) -> str`: case-insensitive
    substring check in priority order (warning > watch > advisory/statement
    > default). Document the priority in the helper docstring — an event
    like "Severe Weather Warning" matches both `*Warning*` and `*Severe*`
    (which isn't in the table but might appear); priority order ensures
    `*Warning*` wins.

    Unknown / unmatched events default to `"advisory"` **with no WARNING
    log** — unlike NWS (which logs schema drift) and Aeris (which logs
    unknown suffix), OWM's event field is the agency's natural-language
    label (issued by NWS/MeteoFrance/JMA/etc., not OWM's vocabulary). New
    event strings ARE expected and aren't schema drift. Suppressing the log
    avoids noise on every novel event name.

13. **`id` synthesis = `f"{event}|{start}|{sender_name}"`.** Canonical §4.3
    says `id = concat(event + start + sender_name)`. Operationalization with
    `|` separator for human-readability + grep-ability in operator logs.
    Handles None defensively: when `sender_name` is None or empty,
    `f"{event}|{start}|"` (empty trailing segment). The wire field `start`
    is required (always present in real OWM alerts payloads per
    api-docs example); `event` and `sender_name` are also reliably populated.
    No SHA hashing — the concat is stable enough; OWM clients reading the
    id are not us.

14. **Datetime conversion via `epoch_to_utc_iso8601`.** OWM `start` / `end`
    are epoch UTC seconds. DRY-reuse the helper from
    `providers/_common/datetime_utils.py` (added by 3b-5 forecast/owm).
    Result matches canonical §3.6 / §3.11 (UTC ISO-8601 Z).

15. **Cache key shape.** `SHA-256(json({"provider_id": "openweathermap",
    "endpoint": "alerts", "params": {"lat4": ..., "lon4": ...}}, sort_keys=True))`.
    No target_unit dimension (alerts have no unit conversion).
    Logical-endpoint key `"alerts"` distinct from the forecast module's
    `"forecast_bundle"` — two cache entries per station, one per domain,
    even though both modules hit the same `/data/3.0/onecall` URL with
    different `exclude` sets. Cache stores
    `[record.model_dump() for record in records]` (list of dicts —
    JSON-serializable for Redis per ADR-017); `[AlertRecord.model_validate(d)
    for d in cached]` on hit. Matches `providers/alerts/nws.py` cache shape.

16. **CAPABILITY supplied_canonical_fields = canonical §4.3 OWM-supplied
    fields ONLY (PARTIAL-DOMAIN per L1 rule).** Per the cross-check audit
    above, canonical §4.3 OWM column has eight cells mapped to wire fields,
    four "not provided" (urgency, certainty, areaDesc, category).
    CAPABILITY enumerates the eight supplied:

    ```
    "id", "headline", "description", "severity", "event",
    "effective", "expires", "senderName",
    # "source" included for completeness (provider id literal, not a fetched wire field)
    "source",
    ```

    NOT in CAPABILITY: `urgency`, `certainty`, `areaDesc`, `category` — they
    populate as `None` on canonical AlertRecord unconditionally (no plan-tier
    variance — OWM categorically doesn't supply these on any tier).

    **PARTIAL-DOMAIN per L1 extension** (3b-7 lesson — Aeris precedent for
    urgency/certainty/category being categorically absent, PARTIAL-DOMAIN
    rather than tier-conditional). Auditor flagging this as ADR-038 static-
    CAPABILITY drift: lead's response is "PARTIAL-DOMAIN per canonical §4.3
    OWM column (not-provided cells)."

17. **CAPABILITY geographic_coverage = `"global"`.** ADR-016 day-1 set
    table column says "Global government alerts" for OWM. Trust OWM's
    authoritative answer; no client-side geographic gate. Matches 3b-5
    forecast/owm CAPABILITY.

18. **CAPABILITY auth_required = `("appid",)`.** Single-credential tuple,
    same shape as `providers/forecast/openweathermap.py` (3b-5).

19. **Active-alert-only filter is the upstream's job.** OWM `/data/3.0/onecall`
    `alerts[]` returns currently-active alerts only per the api-docs
    "Known issues / gotchas" section ("Alerts in One Call cover a region's
    official issuing agency"). No client-side `active=true` filter needed.
    Matches NWS `/alerts/active` + Aeris `/alerts` semantics.

20. **Rate limiter.** `RateLimiter("openweathermap-alerts", max_calls=5,
    window_seconds=1)` — "be polite" guard. Per-call acquire before the
    single outbound call per cache miss. With 5-min TTL + single-worker
    default, ~290 calls/day per station (288 actually — 24*60/5) plus the
    ~48/day forecast calls = ~338/day shared appid load, well within the
    1000/day One Call by Call quota.

21. **URL form for OWM `/data/3.0/onecall`.** Same base URL constant
    `OWM_BASE_URL = "https://api.openweathermap.org"` as forecast/owm; same
    path constant `OWM_ONECALL_PATH = "/data/3.0/onecall"`. Brief lead-call:
    **import these constants from `providers/forecast/openweathermap.py`**
    rather than redefining locally. Cross-module-constant DRY — when OWM's
    base URL changes (rare but possible), one file edit covers both
    modules. Document the import-from-sibling-module pattern in the alerts
    module docstring so future readers understand the unusual import.

22. **OWM `exclude` URL param = `current,minutely,hourly,daily`.** Alerts-only
    payload. Per api-docs §"One Call API 3.0" the `exclude` CSV may list any
    of `current,minutely,hourly,daily,alerts`. Excluding the other four
    cuts response payload by ~99% on alerts-only fetches (alerts array is
    typically 0-2 entries vs 48 hourly + 8 daily). This is the inverse of
    3b-5 forecast/owm's `exclude=current,minutely,alerts`. Document the
    inverse-exclude pattern in commit body so future readers don't try
    to consolidate into one call.

23. **Wire-shape Pydantic model — `_OWMAlertEntry` + `_OWMOneCallAlertsResponse`.**
    Two new models in this file (not reused from 3b-5 forecast/owm because the
    forecast wire model deliberately doesn't enumerate `alerts[]`):

    ```python
    class _OWMAlertEntry(BaseModel):
        """One entry in alerts[] array."""
        model_config = ConfigDict(extra="ignore")

        sender_name: str | None = None
        event: str                    # required for id synthesis + severity derivation
        start: int                    # epoch UTC seconds; required for id + effective
        end: int | None = None        # epoch UTC seconds; nullable for expires
        description: str | None = None
        # tags: list[str] | None = None  # OUT OF SCOPE — wire field exists, no canonical mapping

    class _OWMOneCallAlertsResponse(BaseModel):
        """Top-level One Call 3.0 response, alerts-only projection."""
        model_config = ConfigDict(extra="ignore")

        lat: float
        lon: float
        # timezone_offset NOT needed (alerts have no station-local date derivation)
        alerts: list[_OWMAlertEntry] = Field(default_factory=list)
    ```

    `extras="ignore"` so OWM schema additions (e.g., a future `severity`
    wire field added to alerts) don't break us. **Note: `event` and `start`
    are REQUIRED at the wire layer per the api-docs example** — Pydantic
    raises `ValidationError → ProviderProtocolError` if either is absent.

24. **No `tags` field surfacing.** Wire's `tags: list[str]` is documented
    in api-docs example (L209) but canonical AlertRecord has no `extras` bag
    (§3.6) and no equivalent canonical field. Drop silently — wire model
    omits the field entirely (`extras="ignore"` plus explicit non-declaration).
    Auditor flagging this as data-loss: lead's response is "canonical §3.6
    has no extras bag for alerts; tags dropped per canonical contract."

25. **No `wire_openweathermap_credentials()` redefinition in
    `endpoints/forecast.py`.** That helper already exists at 3b-5. This
    round adds the SAME-NAMED helper in `endpoints/alerts.py` (mirror of
    `wire_aeris_credentials()` which exists in both files). Two helpers,
    one in each endpoint module; both read from the same env var via
    `settings.alerts.openweathermap_appid` or `settings.forecast.openweathermap_appid`
    at startup. AlertsSettings and ForecastSettings BOTH carry the field;
    `__main__.py` wires both transparently.

### Operationalization audit checklist (canonical-spec rule, 3b-3)

For every canonical-mapped field, the verb in canonical §4.3 was checked for
parser-definition ambiguity:

- `id = concat(event + start + sender_name)`: ambiguous "concat" verb —
  separator? formatting? Resolved by lead-call 13 (`|` separator,
  None-handling specified).
- `headline = event`: unambiguous.
- `description = description`: unambiguous — direct passthrough; OWM has no
  NWS-style `instruction` field to append.
- `severity = severity-mapping from event keyword`: ambiguous "from event
  keyword" — substring vs equality? case-sensitive? priority of overlap?
  Resolved by lead-call 12 (case-insensitive substring, priority order).
- `urgency / certainty / areaDesc / category = (not provided)`: PARTIAL-DOMAIN
  per lead-call 16.
- `event = event`: passthrough; canonical §3.6 is "Provider's event name" —
  OWM's `event` field is human-readable (`"Wind Advisory"`), matches §3.6's
  example exactly. **Lead-call: pass through raw.**
- `effective = start (epoch s, convert)`: clear — epoch_to_utc_iso8601 reuse
  per lead-call 14.
- `expires = end (epoch s, convert)`: clear — same helper.
- `senderName = sender_name`: clear passthrough.
- `source = "openweathermap"` (provider_id literal): unambiguous.

---

## Open questions for user sign-off

(Audited each candidate against ADRs/contracts/api-docs. One real question
remains — symmetry with 3b-5 forecast/owm Q1, which is a design decision
worth re-confirming for the alerts domain rather than auto-applying.)

### Q1 USER DECIDED 2026-05-10: A — graceful empty alert list on basic-tier 401.

Module catches `KeyInvalid` raised from the One Call 3.0 outbound call
**specifically** (where `exc.status_code == 401`) and returns an empty
`list[AlertRecord]` — the endpoint then wraps that in
`AlertList(alerts=[], source="openweathermap", ...)`. NOT an error. Other 401s
(non-existent in v0.1's single-endpoint module, but defensive) re-raise as
KeyInvalid → 502. The wrap is intentional and documented inline; per L2 this
is NOT a "re-construct canonical exception" anti-pattern — it's a deliberate
dispatch-on-attribute swallow at one specific call site (mirror of 3b-5
forecast/owm).

Cache parity with success path: empty result IS cached for the same 300s TTL
as a populated response (mirror of 3b-5 forecast/owm audit F2 remediation).
Without cache parity, a basic-tier-misconfigured deployment hits
`/data/3.0/onecall` on every dashboard poll — capped only by rate limiter at
5 req/s = 432K/day vs the success path's ~290 calls/day. The fetch() body
operationalizes this in `providers/alerts/openweathermap.py` (mirror of the
3b-5 forecast/owm Q1 fetch() shape).

**Why this question was asked.** OWM's basic-tier API key returns `401` from
`/data/3.0/onecall` (paid endpoint). This module hits the paid endpoint
unconditionally — no fallback to `/data/2.5/forecast` or any free endpoint.
3b-5 forecast/owm landed Q1 as **(A) graceful empty bundle** — same shape as
"no provider configured" rather than raising KeyInvalid 502. The user-side
behavior is identical in both cases (dashboard hides the panel); operator
recovery action is identical (verify key at OWM dashboard).

**Carry-forward consideration.** Alerts have a different modal behavior than
forecast: empty alerts is the EXPECTED MODAL response (most stations, most
of the time, have no active alerts). A "no alerts" state is normal and
unremarkable — distinguishing "no alerts because no active alerts" from "no
alerts because basic-tier 401" is harder for the operator to spot than the
parallel forecast case (where an empty hourly+daily bundle is visually
striking and triggers operator investigation).

**Argument for (A) symmetry:** Same provider, same endpoint, same OWM
gotcha. Two adjacent modules answering the same question two different ways
is a process smell. The operator-side recovery action is identical.

**Argument against (A):** Alerts being silently broken is HARDER to notice
than forecast being silently broken. A KeyInvalid 502 in alerts surfaces
loudly via operator logs + 5xx dashboard panel; graceful-empty hides the
misconfiguration.

**Lead's recommendation: (A) graceful empty list** — symmetry with 3b-5
forecast/owm wins. The operator-recovery-identical argument is stronger
than the surface-visibility argument; the audit log line + `operator_notes`
on CAPABILITY make the misconfiguration discoverable to anyone who looks.

**User confirmed (A) 2026-05-10.**

**Audit trail (per "Brief questions audit themselves before draft"):**

- (A) Graceful empty list per 3b-5 precedent — lead's recommendation.
  Aligns with L1 paid-tier-max-surface rule. CAPABILITY enumerates the
  full OWM-supplied surface (lead-call 16); runtime population is empty
  on basic-tier deployments. Dashboard hides panel via same code path as
  no-provider-configured.
- (B) Strict KeyInvalid 502 — louder operator-side, more discoverable
  misconfiguration. Asymmetric with 3b-5; introduces precedent drift across
  same-provider rounds.
- (C) Operator-config tier flag — same disposition as 3b-5 Q1 (rejected
  there). Not justified by current scope.

**Operationalization (locked).** The fetch() body in
`providers/alerts/openweathermap.py` implements (A), mirroring the 3b-5
forecast/owm fetch() shape. The wrap is intentional (NOT an L2 re-construct)
and documented inline + commit body.

---

(Hypothetical Q2 considered: `tags` field surfacing. Resolved per the
"Brief questions audit themselves before draft" rule — canonical §3.6 has
no `extras` bag for alerts, so the wire `tags` field has no canonical
home. Drop silently per lead-call 24. Not a real question — canonical
contract settles it.)

---

## Per-module spec — `providers/alerts/openweathermap.py`

Five module responsibilities per ADR-038 §2:

1. **Outbound API call** — single GET per cache miss:
   `GET https://api.openweathermap.org/data/3.0/onecall?lat={lat}&lon={lon}&appid={appid}&exclude=current,minutely,hourly,daily`
2. **Response parsing** — wire-shape Pydantic models for the alerts-only
   projection.
3. **Translation to canonical AlertRecord** (severity-from-event-keyword
   derivation + datetime conversion + synthetic id).
4. **Capability declaration** — `CAPABILITY` symbol consumed at startup.
5. **Error handling** — provider errors translated to canonical taxonomy via
   `ProviderHTTPClient.get()` (bare propagation EXCEPT for the Q1 narrow
   wrap if user picks A).

### Module-level structure (target shape)

```
weewx_clearskies_api/providers/alerts/openweathermap.py
├── module docstring (5 responsibilities + Q1 dispatch rationale + cross-module-constants)
├── PROVIDER_ID = "openweathermap"
├── DOMAIN = "alerts"
├── DEFAULT_ALERTS_TTL_SECONDS = 300
├── _API_VERSION = "0.1.0"
├── (imports from sibling module: OWM_BASE_URL, OWM_ONECALL_PATH from providers.forecast.openweathermap)
├── _SEVERITY_KEYWORD_PRIORITY = [("warning", ("warning",)), ("watch", ("watch",)), ("advisory", ("advisory", "statement"))]
├── _logged_unknown_severities: set[str]   # for unknown-event no-log behavior (lead-call 12)
├── CAPABILITY = ProviderCapability(...)
├── Wire-shape Pydantic models (extras="ignore"):
│     _OWMAlertEntry — sender_name/event/start/end/description
│     _OWMOneCallAlertsResponse — lat/lon/alerts[]
├── Helper functions:
│     _owm_severity_from_event(event: str) -> str
│     _build_alerts_cache_key(lat, lon)
│     _synthesize_alert_id(event, start, sender_name)
│     _owm_alert_to_canonical(entry) -> AlertRecord
├── _rate_limiter = RateLimiter(...)
├── _owm_basic_tier_warned: bool (if Q1=A)
├── _client_for() -> ProviderHTTPClient
└── fetch(*, lat, lon, appid, http_client=None) -> list[AlertRecord]
```

### Public fetch entrypoint

```python
def fetch(
    *,
    lat: float,
    lon: float,
    appid: str | None,
    http_client: ProviderHTTPClient | None = None,
) -> list[AlertRecord]:
    """GET /data/3.0/onecall (alerts-only) and return canonical AlertRecord list.

    One outbound call per cache miss. Cache stores list[dict] for Redis
    JSON-compat per ADR-017; reconstructed via AlertRecord.model_validate()
    on hit.

    Q1 user decision (2026-05-10) — narrow try/except KeyInvalid (if A picked):
      [Same shape as 3b-5 forecast/owm Q1 — basic-tier 401 → empty list.]

    Raises:
        KeyInvalid: appid is None/empty, or OWM returned 401 with
            status_code != 401 (defensive); OR — if Q1 chose B — all 401s.
        QuotaExhausted: Aeris returned 429.
        ProviderProtocolError: Response validation failed (missing event/start).
        TransientNetworkError: Network failure / 5xx after retries.
    """
```

Cache-first lookup (lead-call 15). KeyInvalid early-raise (lead-call 8).
Bare `client.get()` (lead-call 10). `_owm_alert_to_canonical()` per the §4.3
table verbatim (severity from event keyword per lead-call 12, datetime via
epoch_to_utc_iso8601 per lead-call 14, synthetic id per lead-call 13).

---

## Per-module spec — wiring changes

### `endpoints/alerts.py`

Add module-level state + helper, mirror of `endpoints/forecast.py` and the
existing `wire_aeris_credentials()`:

```python
_openweathermap_appid: str | None = None


def wire_openweathermap_credentials(appid: str | None) -> None:
    """Store OWM appid for the alerts endpoint dispatch.

    Called from wire_alerts_settings() at startup. Tests that don't exercise
    OWM path leave this as None; openweathermap.fetch() will raise KeyInvalid.
    Mirror of endpoints/forecast.py wire_openweathermap_credentials() (3b-5).
    """
    global _openweathermap_appid  # noqa: PLW0603
    _openweathermap_appid = appid
```

Extend `wire_alerts_settings()`:

```python
def wire_alerts_settings(settings: object) -> None:
    alerts_section = getattr(settings, "alerts", None)
    contact = getattr(alerts_section, "nws_user_agent_contact", None)
    wire_nws_user_agent_contact(contact)

    aeris_id = getattr(alerts_section, "aeris_client_id", None)
    aeris_secret = getattr(alerts_section, "aeris_client_secret", None)
    wire_aeris_credentials(aeris_id, aeris_secret)

    owm_appid = getattr(alerts_section, "openweathermap_appid", None)
    wire_openweathermap_credentials(owm_appid)
```

Extend dispatch tree:

```python
elif provider_id == "openweathermap":
    from weewx_clearskies_api.providers.alerts import openweathermap  # noqa: PLC0415
    all_records = openweathermap.fetch(
        lat=station.latitude,
        lon=station.longitude,
        appid=_openweathermap_appid,
    )
```

### `config/settings.py AlertsSettings`

Mirror the `ForecastSettings` OWM loader:

```python
#: OWM appid from env var WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID (ADR-027 §3).
#: Provider-scoped per 3b-5 brief Q2 user decision 2026-05-08; same key works
#: for forecast + alerts (mirrors 3b-7 Aeris precedent).
openweathermap_appid: str | None

# In __init__:
raw_owm_appid = os.environ.get("WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID", "").strip()
self.openweathermap_appid = raw_owm_appid if raw_owm_appid else None
```

`validate()` is unchanged — provider id list already includes `"openweathermap"`
(or — if it doesn't yet for the alerts validator — add it; api-dev confirms at
read-time).

---

## Test plan — `clearskies-test-author` deliverables

### Unit tests — `tests/unit/providers/alerts/test_openweathermap.py`

Coverage (mirror `tests/unit/providers/alerts/test_aeris.py` + `tests/unit/providers/forecast/test_openweathermap.py`):

- Wire-shape Pydantic validation against synthetic-from-api-docs fixture.
- Severity-from-event-keyword mapping (table-driven):
  - `"Tornado Warning"` → `"warning"`
  - `"Severe Thunderstorm Watch"` → `"watch"`
  - `"Wind Advisory"` → `"advisory"`
  - `"Special Weather Statement"` → `"advisory"`
  - `"Heat Watch"` → `"watch"`
  - `"Coastal Flood Warning"` → `"warning"`
  - `"Unknown Mystery Hazard"` → `"advisory"` (default; NO log)
  - Case sensitivity: `"tornado warning"` → `"warning"` (lower-case input).
  - Priority overlap: `"Severe Weather Warning"` → `"warning"` (warning beats severe).
- Datetime conversion via `epoch_to_utc_iso8601` (epoch UTC → ISO Z).
- ID synthesis (lead-call 13):
  - Normal: `("Wind Advisory", 1714485600, "NWS Seattle WA")` → `"Wind Advisory|1714485600|NWS Seattle WA"`.
  - None sender_name: `("Foo", 100, None)` → `"Foo|100|"`.
  - Empty sender_name: `("Foo", 100, "")` → `"Foo|100|"`.
- Description passthrough (no instruction-append).
- urgency/certainty/areaDesc/category populate as `None` (PARTIAL-DOMAIN).
- Cache hit/miss via `MemoryCache` and `RedisCache` (parametrize via existing
  cache test fixtures from `tests/unit/providers/_common/test_cache.py`).
- Credentials missing (appid None or empty) → `KeyInvalid` raised, no HTTP.
- HTTP 401 →
  - **If Q1=A:** empty list returned + WARN log once per process + cache stored
    with empty list (mirror 3b-5 cache-parity for basic-tier 401).
  - **If Q1=B:** `KeyInvalid` raised, `status_code=401`.
- HTTP 429 → `QuotaExhausted` with `retry_after_seconds` propagated through
  (3b-4 F1 carry-forward; assert `exc.retry_after_seconds is not None` when
  `Retry-After` header present in fixture).
- HTTP 500 → `TransientNetworkError`.
- Pydantic `ValidationError` (e.g., alert entry missing `event` or `start`)
  → `ProviderProtocolError` with body excerpt logged.
- Empty `alerts: []` response → empty list (NOT an error).
- `tags` field present in wire → dropped silently (assert canonical
  AlertRecord has no tag-bearing field).
- Logged URL redaction: capture log record from a successful fetch; assert
  `?appid=ABC123` shows as `?appid=[REDACTED]` (verify the redaction filter's
  appid coverage carries from 3b-1).

### Integration tests — `tests/integration/providers/alerts/test_openweathermap_integration.py`

Coverage:

- End-to-end through `endpoints/alerts.py` with `[alerts] provider = openweathermap`
  and OWM appid wired via `wire_openweathermap_credentials()`.
- `MariaDB` + `SQLite` parametrize via existing dual-backend fixtures.
- `respx`-mocked OWM endpoint returning the captured fixture.
- Severity filter end-to-end (`?severity=warning` returns warning-only records).
- 200 + empty `alerts: []` → empty `AlertList(alerts=[], source="openweathermap")`.
- 200 + populated `alerts[]` → populated AlertList with synthesized IDs.
- Credentials missing → 502 `ProviderProblem` (matches existing endpoint
  error contract from 3b-1 + 3b-7).
- Unknown query param → 400/422 (extra="forbid" via Depends pattern from 3b-1).

### Redis-tier integration tests

Tag with `@pytest.mark.integration` and `@pytest.mark.redis`. Verify cache-hit
path against `RedisCache` (fakeredis fixture from 3b-1's shared infrastructure).

### Fixture content

`tests/fixtures/providers/openweathermap/alerts_paid.json`: Synthetic from
api-docs/openweathermap.md L161-213 example response, projecting only the
`alerts[]` field with two entries:
- One `event="Wind Advisory"` from the api-docs example verbatim.
- One additional entry hand-crafted to exercise the severity-warning path:
  `event="Tornado Warning"`, distinct `start`/`end`, different `sender_name`.

Sidecar `.md` clearly states: "synthetic-from-api-docs/openweathermap.md
L203-211 example — fields mirrored, not captured live; second entry
hand-crafted to exercise warning-severity path."

`alerts_paid_empty.json`: same shape, `alerts: []`.

`alerts_basic_tier_401.json`: 401 JSON body — can be reused from 3b-5 forecast
fixtures (`error_401_basic_tier.json`) if test-author confirms the body shape
matches.

`alerts_error_429.json`: 429 body with `Retry-After: 60` header.

---

## Acceptance gates (lead-checked before audit spawn)

1. `git fetch origin main && git merge --ff-only origin/main` on `weather-dev`
   before pytest runs (parallel-pull-then-pytest hard gate per
   `clearskies-api-dev` agent definition).
2. `pytest` on `weather-dev` BEFORE submitting:
   - **Default + integration combined:** all green; ≥1392 baseline + new
     alerts/openweathermap tests (estimate ~40-60 new unit + ~5-10 integration).
   - **Redis tier:** ≥15 baseline + new cache-hit alerts/openweathermap tests;
     0 failed.
3. **Brief-divergence STOP rule** (api-dev agent definition): if impl
   diverges from this brief OR canonical-data-model.md, STOP and
   SendMessage lead.
4. **L2 carry-forward** (3b-4 F1): bare `client.get()`. NO narrow wraps
   EXCEPT the intentional Q1=A wrap (if user picks A), documented inline.
5. **Commit-early-and-often** (api-dev / test-author agent defs): commit
   per file/chunk, not at end-of-round.
6. **Mid-flight SendMessage cadence**: ≤4 min active work without status
   update. Long-running actions framed by ETA + result messages.

---

## Audit spawn (after both teammates submit + pytest green)

Auditor (Opus) reviews against:

- ADR-016 (alerts source), ADR-017 (caching), ADR-027 §3 (secrets), ADR-038
  (provider-module organization), ADR-006 (operator-managed compliance).
- canonical-data-model.md §3.6 + §4.3 (AlertRecord + OWM column-by-column).
- security-baseline.md §3.5 (extra="forbid" Pydantic at trust boundaries),
  §4.1 (secret redaction in logs).
- rules/coding.md §1 (validation, secret redaction), §3 (DRY, dispatch on
  attributes not strings, no dead code).
- L1 paid-tier-max-surface CAPABILITY rule + PARTIAL-DOMAIN extension.
- L2 don't re-construct canonical exceptions.
- **NEW: cross-check rule (3b-7) — already applied at brief-draft time;
  auditor verifies the brief's cross-check audit table above is accurate.**

**Auditor recipient name** — explicit fallback chain in spawn prompt to
pre-empt the 3b-5/3b-6/3b-7 addressability gap. Try `lead`, then `team-lead`,
then `opus`, then accumulate to closeout.

---

## Closeout (lead, after audit)

1. Per-finding triage: accept (lead-direct when no design judgment),
   push back (with reasoning surfaced to user), defer.
2. Plan-status commit on meta repo updating
   `docs/planning/CLEAR-SKIES-PLAN.md` to mark 3b-8 closed and queue 3b-9.
3. Lessons triage per CLAUDE.md "Capture lessons in the right place"
   rule — **default to decision-log-only** (3b-5/3b-6/3b-7 user direction
   reinforced). Only rules for things existing process did NOT catch.
4. Queue next round resume prompt at `c:\tmp\3b-9-resume-prompt.md`.

---

## Carry-forward rules summary (don't trust agent-def auto-load alone)

Sonnet teammates (api-dev + test-author) get spawned with explicit restate of:

- Mid-flight SendMessage cadence (≤4 min floor).
- "No >5 min in pure file-reading without a SendMessage" research-mode
  mitigation.
- Commit early and often (per file, not end-of-round).
- L2: don't re-construct canonical exceptions you've already received from
  `ProviderHTTPClient.get()`. The Q1=A narrow wrap is INTENTIONAL and
  documented; ALL OTHER call sites are bare client calls.
- L3 synthetic-from-real fixture pattern (fires this round for alerts_paid.json
  + alerts_paid_empty.json — no OWM paid access; synthesize from api-docs
  example).
- L1 paid-tier-max-surface CAPABILITY + PARTIAL-DOMAIN extension (lead-call 16
  fires PARTIAL-DOMAIN for urgency/certainty/areaDesc/category — NOT
  tier-conditional, OWM categorically doesn't supply these on any plan).
- F2 attribute-dispatch on exceptions, not message strings (lead-call 9).
- Brief-vs-impl divergence STOP rule (api-dev agent def).
- Brief-gate honesty rule (test-author agent def — surface gate-misses
  early via SendMessage, don't quietly skip and submit closeout).
- **NEW**: cross-check rule (3b-7) — already applied at brief-draft (above);
  if api-dev finds an additional canonical-vs-wire mismatch during impl,
  STOP and SendMessage lead BEFORE attempting to reconcile.

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

- **Scratchpad:** `c:\tmp\3b-8-scratch.md` — append-as-you-go.
  Round-close: triage queued lessons per CLAUDE.md routing rules.
- **Spawn cadence:** api-dev + test-author parallel after brief sign-off;
  auditor after both submit + pytest is green on weather-dev.
- **Polling cadence:** every user-prompt boundary, lead checks
  `git log -20 origin/main` + `SendMessage` any silent teammate per the
  poll-don't-wait rule. Pre-empt the idle bug.

---

**Brief approved by user 2026-05-10 (Step D before spawn): Q1 = A (graceful
empty list on basic-tier 401 + cache parity, mirror of 3b-5 forecast/owm).**
