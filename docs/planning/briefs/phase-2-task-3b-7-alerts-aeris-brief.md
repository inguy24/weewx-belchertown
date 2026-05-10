# Phase 2 task 3b round 7 brief — clearskies-api alerts domain (Aeris)

**Round identity.** Phase 2 task 3 sub-round 3b round 7. **First round AFTER the
3b-forecast series closed in 3b-6 (2026-05-09).** All five day-1 forecast
providers (Open-Meteo, NWS, Aeris, OpenWeatherMap, Wunderground) per ADR-007
shipped in 3b-2 through 3b-6. **3b-7 returns to the alerts domain to add Aeris
as the second alerts provider** — third concrete keyed-provider integration on
this project (Aeris forecast 3b-4, OWM forecast 3b-5, Wunderground forecast
3b-6 were the prior keyed-provider rounds).

This is a **single-deliverable round.** Shared infrastructure (HTTP wrapper,
retry, error taxonomy, capability registry, cache backends, rate limiter,
datetime utils) lives. The `/alerts` endpoint at `endpoints/alerts.py` lives
with one dispatch branch (NWS) from 3b-1. `AlertRecord`, `AlertList`, and
`AlertListResponse` canonical types live in `models/responses.py`. The
redaction filter at `logging/redaction_filter.py` already covers
`client_id` and `client_secret` query params (3b-4 work; F13 closed). This
round adds:

1. **`weewx_clearskies_api/providers/alerts/aeris.py`** — second concrete
   alerts provider per ADR-016 + ADR-038. Five module responsibilities;
   structural twin of `providers/alerts/nws.py` (single canonical AlertList
   shape) + reuses keyed-provider patterns from `providers/forecast/aeris.py`
   (envelope parsing, credential validation, `KeyInvalid` early-raise).
2. **One new row in `_common/dispatch.py`** —
   `("alerts", "aeris") → providers.alerts.aeris`.
3. **`aeris_client_id` + `aeris_client_secret` fields on `AlertsSettings`**
   sourced from the same env vars `ForecastSettings` reads
   (`WEEWX_CLEARSKIES_AERIS_CLIENT_ID` / `_SECRET`). Provider-scoped per
   3b-4 brief Q1 user decision 2026-05-08; same key works across forecast +
   alerts. Loaded at `__init__` per ADR-027 §3 (secrets never in INI).
4. **`wire_aeris_credentials()` helper in `endpoints/alerts.py`** —
   mirror-pattern of `endpoints/forecast.py wire_aeris_credentials()`.
   Extend `wire_alerts_settings()` to call it.
5. **`elif provider_id == "aeris":` dispatch branch in `endpoints/alerts.py`**
   — passes lat/lon + credentials to `aeris.fetch()`.

**No redaction-filter changes** — `_CLIENT_ID_RE` and `_CLIENT_SECRET_RE`
already in place from 3b-4. **No `__main__.py` changes** —
`wire_alerts_settings()` is already called and extends transparently. **No
canonical-data-model or OpenAPI changes** — `AlertRecord` and `/alerts`
contract are unchanged.

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after both
submit and pytest is green on `weather-dev`.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` (clone of
`github.com/inguy24/weewx-clearskies-api`). **Default branch `main`** (verified
2026-05-09 via `git symbolic-ref refs/remotes/origin/HEAD`). Parallel-pull
command: `git fetch origin main && git merge --ff-only origin/main`. The
meta-repo (this `weather-belchertown/` workspace) is `master`.

**Pre-round HEADs verified 2026-05-09:**
- api repo: `1c4b57f` (3b-6 audit remediation: F1 + F2 + F3 lead-direct)
- meta repo: `7c2190d` (3b-6 close)
- weather-dev: `1c4b57f` (already up to date)

**Pytest baseline at `1c4b57f`:**
- Default tier: 1077 / 0 / 0
- Integration MariaDB: 224 / 35 / 0
- Integration SQLite: 224 / 35 / 0
- Redis tier (CLEARSKIES_CACHE_URL=redis://127.0.0.1:6380/0 +
  `integration and redis`): 13 / 0

---

## Scope — 1 provider module + plumbing

| # | Unit | Notes |
|---|---|---|
| 1 | `weewx_clearskies_api/providers/alerts/aeris.py` | New file. **One outbound call per cache miss:** `GET /alerts/{lat},{lon}?client_id=...&client_secret=...`. Aeris `/alerts` returns active alerts only (api-docs §Alerts notes). No filter-pair pattern (forecast had hourly+daynight; alerts is single-call). |
| 2 | `_common/dispatch.py` | Add `("alerts", "aeris") → providers.alerts.aeris` row. One import + one entry. Update header comment from "When 3b round 2 adds Aeris alerts" (stale; was written before 3b sequencing finalized) to reflect actual round-7 wiring. |
| 3 | `config/settings.py` `AlertsSettings` | Add `aeris_client_id: str \| None` + `aeris_client_secret: str \| None` fields populated from env vars `WEEWX_CLEARSKIES_AERIS_CLIENT_ID` + `WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET` at `__init__` (NOT from `[alerts]` INI section — secrets per ADR-027 §3). Update `validate()` so existing logic still passes. |
| 4 | `endpoints/alerts.py` | Add module-level `_aeris_client_id` / `_aeris_client_secret` + `wire_aeris_credentials()` (mirror `endpoints/forecast.py`). Extend `wire_alerts_settings()` to also call it. Add `elif provider_id == "aeris":` dispatch branch. |
| 5 | `__main__.py` | **No change** — already calls `alerts.wire_alerts_settings(settings)` (line 386). The new `wire_aeris_credentials()` plugs into that wrapper transparently. |
| 6 | Recorded fixtures | `tests/fixtures/providers/aeris/alerts.json` (real capture per Q1 below). Plus error-shape fixtures: `alerts_error_401.json`, `alerts_error_429.json`, `alerts_warn_invalid_location.json`. Sidecar `.md` documents capture date + lat/lon + tier + which canonical fields appeared. |

**Out of scope this round (defer to later 3b rounds / Phase 3+ / Phase 4):**

- **OpenWeatherMap alerts** (8th alerts provider in domain, third still missing
  per ADR-016). Separate 3b round; OWM One Call 3.0 returns alerts in the same
  payload 3b-5's forecast already consumes — module would drop the
  `exclude=alerts` URL parameter. Pattern decided this round so OWM round is
  formulaic.
- **Setup-wizard region-based provider suggestion** (ADR-016 §Decision). Wizard
  ships in Phase 4 per ADR-027.
- **Operator overrides for alerts TTL or rate-limit.** This round uses ADR-017's
  default 300s for alerts; same as NWS.
- **All other provider domains.** /aqi/* /earthquakes /radar/* are separate 3b
  rounds.
- **Multi-source aggregation across alerts providers** (ADR-016 §B rejected).
  Single source per deploy.
- **Aeris namespace-binding gotcha at registration time.** Aeris `client_id` /
  `client_secret` are bound to a registered namespace (domain or bundle ID);
  server-side calls from an unregistered host are rejected. Operator
  responsibility per ADR-006 (same disposition as 3b-4 forecast/aeris).
- **Refactoring `_parse_aeris_envelope_raw` into a shared helper.**
  `providers/forecast/aeris.py` has it as a private module-level helper. DRY
  rule says "search before writing" — but promoting it to
  `providers/_common/` is a refactor outside this round's scope. Lead-call:
  duplicate the envelope-parser inside `providers/alerts/aeris.py` for now.
  If a third Aeris-domain module lands (e.g. observations), then promote.
  Anti-pattern guard: don't preemptively share.

---

## Lead-resolved calls (no user sign-off needed — ADRs and contracts settle these)

The "Brief questions audit themselves before draft" rule
(`rules/clearskies-process.md`) requires every "open question" to be audited
against the ADRs first. The "brief-vs-canonical cross-check" rule (3b-2 F2)
requires every lead-resolved call to cross-check against
`canonical-data-model.md` + `openapi-v1.yaml` before drafting. Both audits
performed; every call below has been verified against both. Numbered for
reference, not for sign-off.

### Inherited from prior 3b rounds (no change, no re-audit needed)

1. **HTTP client = `httpx` (sync).** `ProviderHTTPClient` from
   `_common/http.py`. Already covers TLS, timeouts, retry/backoff, error-class
   translation, structured `status_code` attribute on `ProviderError`, and 4xx
   body logging at ERROR.

2. **Alerts cache TTL = 300s (5 min).** ADR-016 §Polling cadence + ADR-017
   defaults table. Module's `CAPABILITY.default_poll_interval_seconds = 300`.
   Matches `providers/alerts/nws.py`.

3. **Capability-registry populate path.** ADR-038 §3 + 3b-2's
   `_wire_providers_from_config()`. No change needed — adding the dispatch
   row in step 2 above is enough; the existing `__main__.py` lookup picks
   `aeris` automatically when `[alerts] provider = aeris`.

4. **Both cache backends already live.** ADR-017 + 3b-1's `MemoryCache` +
   `RedisCache`. alerts/aeris consumes `get_cache()` like the other modules.

5. **No live-network tests in CI.** ADR-038 §Testing pattern. Recorded
   fixtures + `respx` for everything.

6. **Source field when no provider configured = literal `"none"`.**
   `endpoints/alerts.py` already does this (line 162); no change.

7. **Aeris provider-scoped credential env vars
   (`WEEWX_CLEARSKIES_AERIS_CLIENT_ID` + `_SECRET`).** Locked by 3b-4 brief
   Q1 user decision 2026-05-08. Same key works for forecast + alerts. The
   AlertsSettings field-load reads the same env vars (loaded values match
   ForecastSettings's at startup; env vars don't drift between init steps).
   No new env var.

8. **Aeris credentials missing → `KeyInvalid` early-raise at `fetch()`
   entry, before any HTTP call.** 3b-4 brief lead-call 12 carry-forward.
   Loud failure beats silent disable; operator intent to enable Aeris alerts
   is unambiguous when `[alerts] provider = aeris`.

9. **Bare `client.get()` calls — let canonical exceptions propagate; no
   narrow wraps.** L2 carry-forward (3b-4 audit F1). The shared
   `ProviderHTTPClient.get()` raises members of the canonical taxonomy
   (`KeyInvalid`, `QuotaExhausted`, `TransientNetworkError`,
   `ProviderProtocolError`) with all structured attributes set
   (`status_code`, `retry_after_seconds`). Catching to re-construct silently
   drops attributes. Anti-pattern: `except QuotaExhausted: raise QuotaExhausted(...)
   from exc`. Don't do it.

10. **Active-alert-only filter is the upstream's job.** Aeris `/alerts`
    returns active alerts only per api-docs §Alerts notes ("`/alerts` returns
    latest alerts only. For history use the (separate) archive endpoints").
    No client-side `active=true` filter needed. Matches NWS `/alerts/active`
    semantics from 3b-1.

11. **Rate limiter.** `RateLimiter("aeris-alerts", max_calls=5,
    window_seconds=1)` — "be polite" guard. Per-call acquire before the
    single outbound call per cache miss. With 5-min TTL + single-worker
    default, never trips in normal use.

12. **Severity normalization (canonical-data-model §4.3 verbatim).** Aeris
    `details.priority` is integer 1–5; map per the §4.3 table:
    - `1` → `"warning"` (Extreme)
    - `2` → `"watch"` (Severe)
    - `3` → `"advisory"` (Moderate)
    - `4` → `"advisory"` (Minor)
    - `5` → `"advisory"` (Unknown)
    Unknown integer values → `"advisory"` (default to least-severe per
    NWS precedent in 3b-1) **with WARNING log** to surface schema drift.
    `_AERIS_SEVERITY_MAP: dict[int, str]` keyed by integer.

13. **Description mapping = `details.body` straight passthrough.** Canonical
    §4.3 says `description = details.body`. No NWS-style instruction-append
    (Aeris has no equivalent field).

14. **Datetime conversion from ISO-with-offset.** Aeris timestamps come as
    both `issued` (epoch s) and `issuedISO` (offset-aware ISO-8601 string);
    same for `expires`. Use the ISO form +
    `to_utc_iso8601_from_offset()` from `_common/datetime_utils.py` (DRY —
    already used by `providers/forecast/aeris.py` and
    `providers/forecast/nws.py`).

15. **Cache key shape.** `(provider_id, endpoint="alerts", {lat4, lon4})` —
    no target_unit dimension (alerts have no unit conversion). Cache stores
    `[record.model_dump() for record in records]` (list of dicts —
    JSON-serializable for Redis per ADR-017); `[AlertRecord.model_validate(d)
    for d in cached]` on hit. Matches `providers/alerts/nws.py` cache shape.

16. **CAPABILITY supplied_canonical_fields = full §3.6 surface (paid-tier
    maximum, per L1 rule).** Declare all canonical AlertRecord fields the
    canonical-data-model §4.3 mapping table names as Aeris-supplied:
    `id`, `headline`, `description`, `severity`, `urgency`, `certainty`,
    `event`, `effective`, `expires`, `senderName`, `areaDesc`, `category`,
    `source`. **Note: `source` is canonical-data-model §3.6's `source`
    field (provider id literal, not a fetched wire field) — included for
    completeness.**

    The `urgency` / `certainty` / `category` fields are documented as
    Aeris-supplied in canonical §4.3 but the api-docs example fixture is
    truncated. **If the captured fixture lacks one or more of these, lead
    handles via auditor-time PARTIAL-DOMAIN amendment** (CAPABILITY drops the
    field; canonical-data-model §4.3 amendment flags Aeris as not-supplying
    it). Test-author SendMessage lead at fixture-capture time naming which
    canonical-mapped fields appear in the real response.

17. **CAPABILITY geographic_coverage = `"us-ca-eu"`.** ADR-016 day-1 set
    table column says "US + Canada + Europe (NWS + Environment Canada +
    MeteoAlarm + UK Met + JMA + BoM redistributed)". Use the
    `"us-ca-eu"` token as the coverage marker for the Phase-4
    setup-wizard recommendation engine. Note that ADR-016's prose says
    Aeris re-distributes JMA + BoM too — but the day-1 table column
    canonically lists US/CA/EU only. Use the table column as authoritative.

18. **CAPABILITY auth_required = `("client_id", "client_secret")`.** Same
    tuple shape as `providers/forecast/aeris.py`.

19. **`senderName` operationalization** (cross-reference with Q2 below).
    Canonical §4.3 says `senderName = details.emergency (or place.name)` —
    operationalize as: prefer `details.emergency` when non-empty string;
    fall back to `place.name` when present; else None. Per Q2 user
    decision below.

20. **URL form for Aeris `/alerts`.** api-docs §Alerts shows
    `GET /alerts/{location}` where `{location}` can be `seattle,wa` (city,
    state) OR `lat,lon`. Use `lat,lon` form — already station-anchored at
    the endpoint level via `services/station.py get_station_info()`. Mirror
    the 3b-4 forecast URL form: `f"{AERIS_BASE_URL}/alerts/{round(lat, 4)},{round(lon, 4)}"`.

21. **Aeris envelope parsing pattern.** Aeris uses the same
    `success`/`error`/`response[]` envelope across ALL endpoints (api-docs
    §Response format conventions). `success=false` → `ProviderProtocolError`.
    `success=true` with warning → log WARNING + return empty list (e.g.
    `warn_location` for an off-grid lat/lon). Duplicate `_AerisEnvelope` +
    `_parse_aeris_envelope_raw` in `providers/alerts/aeris.py` (per
    out-of-scope note above; don't preemptively promote to shared module).

### Operationalization audit checklist (canonical-spec rule, 3b-3)

For every canonical-mapped field, the verb in canonical §4.3 was checked for
parser-definition ambiguity. Findings:

- `id = id` (top-level): unambiguous.
- `headline = details.name`: unambiguous.
- `description = details.body`: unambiguous (call 13 confirms passthrough).
- `severity = details.priority` mapped: integer-to-enum, mapping locked in
  call 12. Operationalization: integer comparison, not string.
- `urgency / certainty / category = details.<field>` straight passthrough —
  no normalization (NWS CAP vocabulary preserved).
- `event = details.type`: passthrough; canonical §3.6 is "Provider's event
  name" — Aeris `details.type` is short code ("WIN", "TOR") rather than
  human-readable. **Lead-call: pass through `details.type` raw.** The
  canonical column-by-column trace from §4.3 is authoritative; downstream
  consumers (dashboard) handle display normalization.

  Cross-check anti-drift: do NOT also pull `details.name` (already mapped to
  `headline`); do NOT synthesize a longer event string.
- `effective = timestamps.issued` mapped via `issuedISO` (ISO-with-offset),
  see call 14.
- `expires = timestamps.expires` mapped via `expiresISO`, see call 14.
- `senderName = details.emergency or place.name`: disjunction operationalized
  in call 19; disambiguated user-facing in Q2.
- `areaDesc = place.name`: passthrough.
- `category = details.category`: passthrough (per call 16, may be absent).
- `source = "aeris"` (provider_id literal): unambiguous.

---

## Open questions for user sign-off

(Audited each candidate against ADRs/contracts. Two real questions remain.)

### Q1 USER DECIDED 2026-05-09: A — real Aeris fixture capture.

Test-author captures `/alerts` fixture from Shane's existing Aeris credentials
at a lat/lon under a known active advisory. Saves raw JSON to
`tests/fixtures/providers/aeris/alerts.json`. Sidecar `.md` documents capture
date, lat/lon used, account tier, and **which canonical-mapped fields appeared
in the real response** (urgency, certainty, category in particular — call 16
PARTIAL-DOMAIN settles based on this real-shape evidence).

**Test-author SendMessage lead at fixture-capture time** naming which fields
appeared. If capture is blocked (rate-limit lockout, account expired,
namespace-binding rejection), test-author SendMessages STOP — lead falls
back to synthetic-from-published per L3 and PARTIAL-DOMAIN gets handled at
audit time.

### Q2 USER DECIDED 2026-05-09: A — return None when both `details.emergency` and `place.name` are empty.

Canonical §3.6 says `senderName` is nullable; canonical wins. Dashboard handles
null per ADR-024 alert-banner UX. No cross-provider drift (NWS reads
`senderName` from the wire; Aeris also returns `None` rather than a synthetic
construction). Operationalization (call 19): prefer `details.emergency` when
non-empty string; else `place.name` when present; else `None`.

---

## Per-module spec — `providers/alerts/aeris.py`

Five module responsibilities per ADR-038 §2:

1. **Outbound API call** — single GET per cache miss:
   `GET https://data.api.xweather.com/alerts/{lat,lon}?client_id=...&client_secret=...`
2. **Response parsing** — wire-shape Pydantic models for the
   `success`/`error`/`response[]` envelope and the alert-detail body.
3. **Translation to canonical AlertRecord** (severity-priority-int map +
   datetime conversion + senderName disjunction).
4. **Capability declaration** — `CAPABILITY` symbol consumed at startup.
5. **Error handling** — provider errors translated to canonical taxonomy via
   `ProviderHTTPClient.get()` (no narrow wraps; L2 rule).

### Wire-shape Pydantic models

Source: api-docs/aeris.md §Alerts + Q1's real-capture fixture
(test-author + lead validate against the real shape at fixture-capture time).
`extras="ignore"` so Aeris schema additions don't break us; missing required
fields raise `ValidationError → ProviderProtocolError`.

```python
class _AerisAlertDetails(BaseModel):
    model_config = ConfigDict(extra="ignore")
    type: str | None = None              # event short code ("WIN", "TOR")
    name: str | None = None              # human-readable headline
    loc: str | None = None
    priority: int | None = None          # severity, mapped via _AERIS_SEVERITY_MAP
    color: str | None = None
    body: str | None = None              # description passthrough
    emergency: str | None = None         # senderName candidate (Q2)
    urgency: str | None = None           # CAP vocab passthrough (call 16: may be absent)
    certainty: str | None = None         # CAP vocab passthrough (call 16: may be absent)
    category: str | None = None          # CAP vocab passthrough (call 16: may be absent)


class _AerisAlertTimestamps(BaseModel):
    model_config = ConfigDict(extra="ignore")
    issued: int | None = None
    issuedISO: str | None = None         # used for effective (call 14)
    expires: int | None = None
    expiresISO: str | None = None        # used for expires (call 14)
    begins: int | None = None            # not in canonical mapping
    beginsISO: str | None = None
    updated: int | None = None
    updatedISO: str | None = None


class _AerisAlertPlace(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str | None = None              # areaDesc + senderName fallback
    state: str | None = None
    country: str | None = None


class _AerisAlertRecord(BaseModel):
    """One alert from response[]."""
    model_config = ConfigDict(extra="ignore")
    id: str
    dataSource: str | None = None        # not in canonical mapping; preserved for debug log
    active: bool | None = None
    details: _AerisAlertDetails
    timestamps: _AerisAlertTimestamps
    place: _AerisAlertPlace | None = None


class _AerisEnvelope(BaseModel):
    """Aeris response envelope — same shape as forecast/aeris.py."""
    model_config = ConfigDict(extra="ignore")
    success: bool
    error: dict[str, Any] | None = None
    response: list[dict[str, Any]] = Field(default_factory=list)
```

### Public fetch entrypoint

```python
def fetch(
    *,
    lat: float,
    lon: float,
    client_id: str | None,
    client_secret: str | None,
) -> list[AlertRecord]:
    """GET /alerts/{lat,lon} and return canonical AlertRecord list.

    Raises:
        KeyInvalid: Credentials missing (both args None) or 401/403.
        QuotaExhausted: Aeris returned 429.
        ProviderProtocolError: Response validation failed or success=false envelope.
        TransientNetworkError: Network failure / 5xx after retries.
    """
```

Cache-first lookup (call 15). KeyInvalid early-raise (call 8). Bare
`client.get()` (call 9). `_parse_aeris_envelope_raw` duplicate (out-of-scope
note). `_to_canonical()` per the §4.3 table verbatim (call 12 severity, call
13 description, call 14 datetime, call 16 paid-tier-max-surface, call 19
senderName).

---

## Per-module spec — wiring changes

### `endpoints/alerts.py`

Add module-level state + helper, mirror of `endpoints/forecast.py`:

```python
_aeris_client_id: str | None = None
_aeris_client_secret: str | None = None


def wire_aeris_credentials(client_id: str | None, client_secret: str | None) -> None:
    """Store Aeris credentials for the alerts endpoint dispatch.

    Called from wire_alerts_settings() at startup. Tests that don't exercise
    Aeris path leave these as None; aeris.fetch() will raise KeyInvalid.
    """
    global _aeris_client_id, _aeris_client_secret  # noqa: PLW0603
    _aeris_client_id = client_id
    _aeris_client_secret = client_secret
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
```

Extend dispatch tree:

```python
elif provider_id == "aeris":
    from weewx_clearskies_api.providers.alerts import aeris  # noqa: PLC0415
    all_records = aeris.fetch(
        lat=station.latitude,
        lon=station.longitude,
        client_id=_aeris_client_id,
        client_secret=_aeris_client_secret,
    )
```

### `config/settings.py AlertsSettings`

Mirror the `ForecastSettings` Aeris loader:

```python
#: Aeris client_id from env var WEEWX_CLEARSKIES_AERIS_CLIENT_ID (ADR-027 §3).
#: Provider-scoped per 3b-4 brief Q1 user decision 2026-05-08.
aeris_client_id: str | None
#: Aeris client_secret from env var WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET.
aeris_client_secret: str | None

# In __init__:
raw_aeris_id = os.environ.get("WEEWX_CLEARSKIES_AERIS_CLIENT_ID", "").strip()
self.aeris_client_id = raw_aeris_id if raw_aeris_id else None

raw_aeris_secret = os.environ.get("WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET", "").strip()
self.aeris_client_secret = raw_aeris_secret if raw_aeris_secret else None
```

`validate()` is unchanged — provider id list already includes `"aeris"`
from 3b-1.

---

## Test plan — `clearskies-test-author` deliverables

### Unit tests — `tests/unit/providers/alerts/test_aeris.py`

Coverage (mirror `tests/unit/providers/alerts/test_nws.py` + `tests/unit/providers/forecast/test_aeris.py`):

- Wire-shape Pydantic validation against real fixture.
- Severity priority-int → canonical-enum mapping (table-driven).
- Datetime conversion via `to_utc_iso8601_from_offset()` (offset → UTC Z).
- senderName disjunction (emergency-present, place-name-only-present,
  both-empty → None per Q2).
- Description passthrough (no instruction-append).
- Category/urgency/certainty passthrough (assert canonical fields populated
  if real fixture has them; assert `None` if absent — per call 16).
- Cache hit/miss via `MemoryCache` and `RedisCache` (parametrize via existing
  cache test fixtures from `tests/unit/providers/_common/test_cache.py`).
- Credentials missing → `KeyInvalid`.
- Aeris envelope `success=false` → `ProviderProtocolError`.
- Aeris envelope `success=true + error={warn_location}` → log WARNING + empty
  list.
- HTTP 401 → `KeyInvalid` (status_code attribute set, not via message string;
  3b-3 F2 carry-forward).
- HTTP 429 → `QuotaExhausted` with `retry_after_seconds` propagated through
  (3b-4 F1 carry-forward; assert `exc.retry_after_seconds is not None` when
  `Retry-After` header present in fixture).
- HTTP 500 → `TransientNetworkError`.
- Pydantic `ValidationError` → `ProviderProtocolError` with body excerpt
  logged.

### Integration tests — `tests/integration/providers/alerts/test_aeris_integration.py`

Coverage:

- End-to-end through `endpoints/alerts.py` with `[alerts] provider = aeris`
  and Aeris credentials wired via `wire_aeris_credentials()`.
- `MariaDB` + `SQLite` parametrize via existing dual-backend fixtures.
- `respx`-mocked Aeris endpoint returning the captured fixture.
- Severity filter end-to-end (`?severity=warning` returns warning-only
  records).
- 200 + empty `response: []` → empty `AlertList(alerts=[], source="aeris")`.
- Credentials missing → 502 `ProviderProblem` (matches existing endpoint
  error contract from 3b-1 + 3b-4).
- Unknown query param → 400/422 (extra="forbid" via Depends pattern from
  3b-1).

### Redis-tier integration tests

Tag with `@pytest.mark.integration` and `@pytest.mark.redis`. Verify
cache-hit path against `RedisCache` (fakeredis fixture from 3b-1's
shared infrastructure).

### Fixture capture (Q1)

If A: SendMessage lead at fixture-capture time naming which fields
appeared in real response. If B: STOP and message lead.

---

## Acceptance gates (lead-checked before audit spawn)

1. `git fetch origin main && git merge --ff-only origin/main` on `weather-dev`
   before pytest runs (parallel-pull-then-pytest hard gate per
   `clearskies-api-dev` agent definition).
2. `pytest` on `weather-dev` BEFORE submitting:
   - **Default tier:** all green; ≥1077 (baseline) + new test counts.
   - **Integration MariaDB:** ≥224 baseline + new alerts/aeris tests; 35
     skipped baseline preserved.
   - **Integration SQLite:** ≥224 baseline + new alerts/aeris tests; 35
     skipped baseline preserved.
   - **Redis tier:** ≥13 baseline + new cache-hit alerts/aeris tests;
     0 failed.
3. **Brief-divergence STOP rule** (api-dev agent definition): if impl
   diverges from this brief OR canonical-data-model.md, STOP and
   SendMessage lead.
4. **L2 carry-forward** (3b-4 F1): bare `client.get()`. NO narrow wraps.
5. **Commit-early-and-often** (api-dev / test-author agent defs): commit
   per file/chunk, not at end-of-round.
6. **Mid-flight SendMessage cadence**: ≤4 min active work without status
   update. Long-running actions framed by ETA + result messages.

---

## Audit spawn (after both teammates submit + pytest green)

Auditor (Opus) reviews against:

- ADR-016 (alerts source), ADR-017 (caching), ADR-027 §3 (secrets), ADR-038
  (provider-module organization), ADR-006 (operator-managed compliance).
- canonical-data-model.md §3.6 + §4.3 (AlertRecord + Aeris column-by-column).
- security-baseline.md §3.5 (extra="forbid" Pydantic at trust boundaries),
  §4.1 (secret redaction in logs).
- rules/coding.md §1 (validation, secret redaction), §3 (DRY, dispatch on
  attributes not strings, no dead code).
- L1 paid-tier-max-surface CAPABILITY rule + PARTIAL-DOMAIN extension.
- L2 don't re-construct canonical exceptions.

**Auditor recipient name** — explicit fallback chain in spawn prompt to
pre-empt the 3b-5 + 3b-6 addressability gap. Try `lead`, then api-dev's
agent name, then accumulate to closeout.

---

## Closeout (lead, after audit)

1. Per-finding triage: accept (lead-direct when no design judgment),
   push back (with reasoning surfaced to user), defer.
2. Plan-status commit on meta repo updating
   `docs/planning/CLEAR-SKIES-PLAN.md` to mark 3b-7 closed and queue 3b-8.
3. Lessons triage per CLAUDE.md "Capture lessons in the right place"
   rule — **default to decision-log-only** (3b-5 + 3b-6 user direction).
   Only rules for things existing process did NOT catch.
4. Queue next round resume prompt at `c:\tmp\3b-8-resume-prompt.md`.

---

## Carry-forward rules summary (don't trust agent-def auto-load alone)

Sonnet teammates (api-dev + test-author) get spawned with explicit restate of:

- Mid-flight SendMessage cadence (≤4 min floor).
- "No >5 min in pure file-reading without a SendMessage" research-mode
  mitigation.
- Commit early and often (per file, not end-of-round).
- L2: don't re-construct canonical exceptions you've already received from
  `ProviderHTTPClient.get()`.
- L3 synthetic-from-real fixture pattern (only fires if Q1 lands on B).
- L1 paid-tier-max-surface CAPABILITY + PARTIAL-DOMAIN extension (call 16
  may fire if real fixture lacks urgency/certainty/category).
- F2 attribute-dispatch on exceptions, not message strings.
- Brief-vs-impl divergence STOP rule (api-dev agent def).
- Brief-gate honesty rule (test-author agent def — surface gate-misses
  early via SendMessage, don't quietly skip and submit closeout).

---

**Brief approved by user 2026-05-09 (Step D before spawn): Q1 = A (real capture), Q2 = A (None on empty senderName).**
