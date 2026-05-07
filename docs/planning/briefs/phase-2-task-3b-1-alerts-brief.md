# Phase 2 task 3b round 1 brief — clearskies-api alerts domain (NWS + shared provider infrastructure)

**Round identity.** Phase 2 task 3 sub-round 3b round 1. First of 5 expected 3b
rounds (one per provider domain: alerts → forecast → AQI → earthquakes → radar).
3a-2 closed 2026-05-07. 3b is the per-ADR-038 plugin-module work; one round per
domain to keep audit surface manageable. Alerts is first per the plan: cleanest
single-source-per-deploy semantics (ADR-016), NWS is keyless and free, and the
domain has a small canonical entity (`AlertRecord`) that doesn't drag forecast's
hourly+daily+discussion shape behind it.

This is a **dual-deliverable round.** Two tightly coupled but separable bodies of
work:

1. **Shared provider infrastructure** under `weewx_clearskies_api/providers/_common/`
   — every future 3b round consumes this. Get it right; refactoring it later costs
   five rounds of churn, not one.
2. **NWS alerts module** under `weewx_clearskies_api/providers/alerts/nws.py` —
   the first concrete consumer of the shared infrastructure. Validates the contract
   shape before forecast/AQI/etc. inherit it.

Plus the `/alerts` endpoint and the `/capabilities` populate path that 3a-2
left as `providers: []`.

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after both
submit and pytest is green on `weather-dev`.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` (clone of
github.com/inguy24/weewx-clearskies-api). **Default branch `main`** (verified
2026-05-07 via `git symbolic-ref refs/remotes/origin/HEAD`). The
parallel-pull command is `git fetch origin main && git merge --ff-only origin/main`.

---

## Scope — 1 endpoint + 2 module units

| # | Unit | Notes |
|---|---|---|
| 1 | `GET /alerts` | OpenAPI line 219. Reads from the configured alerts provider per ADR-016; returns `AlertList(alerts=[], source="none")` when no provider is configured. |
| 2 | `weewx_clearskies_api/providers/_common/` | Shared infra: HTTP client wrapper (sync httpx), retry/backoff helper, canonical error class hierarchy (ADR-038 §5), capability-registry append API, **both** cache backends per ADR-017 (memory default + Redis when `CLEARSKIES_CACHE_URL` is set), rate-limiter primitive. |
| 3 | `weewx_clearskies_api/providers/alerts/nws.py` | First concrete provider module per ADR-038. Calls NWS `/alerts/active?point=<lat>,<lon>`; normalizes GeoJSON `features[].properties` → canonical `AlertRecord`; declares `CAPABILITY` symbol consumed at startup. |
| 4 | `/capabilities` providers-list populate | 3a-2 returned `providers: []`; this round wires the lead-side startup hook that registers configured providers' `CAPABILITY` declarations. |

Out of scope this round (defer to later 3b rounds / Phase 3+ / Phase 4):

- **Aeris and OpenWeatherMap alerts modules.** ADR-016 names all three for day-1
  but ships them in subsequent rounds. Per ADR-016 "Single source per deploy"
  semantics, the operator picks one. NWS first because it's keyless; the keyed
  providers (Aeris + OWM) ride into a later 3b round once the shared infra has
  one validated consumer.
- **All other provider domains.** /forecast, /aqi/*, /earthquakes, /radar/* are
  separate 3b rounds. Their canonical entities, ADRs, and providers are out of
  scope here even when the shared infra would technically support them.
- **Setup-wizard region-based provider suggestion** (ADR-016 §Decision). Wizard
  ships in Phase 4 per ADR-027.
- **Capability registry HTTP endpoint changes.** /capabilities schema is already
  locked. This round populates it; doesn't reshape it.
- **Multi-source aggregation across alerts providers** (ADR-016 §B rejected).
  Single source per deploy.

---

## Lead+user-confirmed calls (resolved 2026-05-07 before spawn)

The earlier draft of this brief padded the question list with items already
locked by ADR-016/017/027/038. User pushback 2026-05-07 trimmed it to real
decisions. The settled calls below combine ADR locks + the two genuine open
questions resolved in chat.

1. **HTTP client library = `httpx` (sync mode).** ADR-038 §Out-of-scope explicitly
   defers this to Phase 2; user delegated 2026-05-07 ("whichever works best").
   Lead picks httpx because `respx` (mock-network test library) is built on it
   and FastAPI's ecosystem already depends on starlette which uses httpx
   internally. Sync mode per ADR-002. New runtime dep `httpx`; new dev-extras
   dep `respx`.

2. **api.conf section shape = `[alerts] provider = nws`.** Locked by
   ADR-027 §Implementation guidance (the example file at line 162–173 uses
   `[forecast] provider = openmeteo` — same domain-named pattern). Each
   provider domain gets its own `[<domain>]` section; provider-specific
   non-secret knobs (e.g. NWS UA contact, see #7) land in the same section.

3. **Capability-registry populate = imperative `wire_providers()` at startup.**
   Locked by ADR-038 §3 (shared `_common/` infra) + the existing 3a-1/3a-2
   wire-pattern (`wire_registry`, `wire_ephemeris_directory`,
   `wire_content_directory`, `wire_reports_directory`). New file
   `providers/_common/capability.py` exposes
   `wire_providers(list[ProviderCapability])` and `get_provider_registry()`;
   `__main__.py` calls it after config-load and before uvicorn starts.
   Module discovery via explicit `PROVIDER_MODULES` dict in
   `providers/_common/dispatch.py` — NOT Python entry-points (forbidden by
   ADR-038 §Internal contract).

4. **Cache backends = memory + Redis, both shipping this round.** ADR-017
   §Decision and §Consequences mandate both as Phase 2 work; the earlier
   draft incorrectly proposed deferring Redis. Memory backend default;
   Redis activates when operator sets `CLEARSKIES_CACHE_URL=redis://...`
   per ADR-017 §Decision. New runtime dep `redis-py` (small, always installed
   so the operator's env-var-set path "just works"); new dev-extras dep
   `fakeredis` for the Redis-backend test path. CI's docker-compose dev
   stack gains a `redis` service profile.

5. **Rate-limiter primitive ships in `providers/_common/`.** Locked by
   ADR-038 §3 (rate-limiter primitive is named in the shared-infrastructure
   bullet). NWS configures `RateLimiter("nws", max_calls=5, window_seconds=1)`
   as a "be polite" guard; never trips in normal use.

6. **NWS outside-coverage handling = let NWS return empty features.** No
   bounding-box pre-check in our code. NWS handles non-US `?point=` queries
   gracefully (200 with empty features); the endpoint emits
   `AlertList(alerts=[], source="nws")`. Lead-call; ADR-016 doesn't pin and
   the answer is obvious.

7. **NWS User-Agent contact = operator-config knob.** Per ADR-006
   (operator-managed compliance — the project is not responsible for the
   operator's actions or accounts with service providers): operators put
   their own contact email/URL in api.conf via
   `[alerts] nws_user_agent_contact = <email-or-url>`. Module composes UA
   as `(weewx-clearskies-api/<version>, <contact>)` when set;
   `(weewx-clearskies-api/<version>)` + one-line WARN log at startup when
   unset. **No project-level hardcoded fallback** (would put the project on
   the hook for any individual operator's traffic patterns — exactly what
   ADR-006 says we don't do).

8. **NWS query strategy = `?point=<lat>,<lon>`.** Single call; lat/lon
   rounded to 4 decimals (matches ADR-017 §Cache key normalization). Lead-call.

9. **`source` field when no provider configured = literal `"none"`.** Both
   `AlertList.source` and `AlertListResponse.source` set to `"none"`.
   Lead-call; trivial.

10. **No live-network tests in CI.** Locked by ADR-038 §Testing pattern.
    Recorded fixture at `tests/fixtures/providers/nws/alerts_active.json`
    (captured manually from a real NWS response — use Seattle
    47.6062,-122.3321 from the api-docs example as the source location).
    Mock-network tests use respx to load the fixture as the canned response.

---

## Hard reading list (once per session)

**Both api-dev and test-author:**

- `CLAUDE.md` — domain routing + always-applicable rules.
- `rules/clearskies-process.md` — full file. **Two new sections added 2026-05-07
  carry forward into 3b:** "Poll background teammates at fixed cadence" (lead
  side, but the polling cadence affects how teammates work); "Verify the default
  branch name before writing it into a round brief" (lead side; verified for this
  brief — the api repo's default branch is `main`). Also still in force from
  prior rounds: real schemas in unit tests where shape matters; audit modes are
  complementary; lead synthesizes auditor findings; plain English to user; ADR
  conflicts → STOP; round briefs land in the project not in tmp.
- `rules/coding.md` — full file. §1 with carry-forward entries that govern 3b:
  Pydantic+Depends pattern for query-param routes; IPv4/IPv6-agnostic networking
  (provider HTTP outbound is the new touchpoint — `httpx.Client` resolves via
  `getaddrinfo` natively, but URL construction must bracket IPv6 literals
  correctly, and our test fixtures use both v4 and v6 hostnames where relevant);
  no dangerous functions; no hardcoded secrets (operator API keys flow via
  config refs to env vars per ADR-027 — NWS is keyless so this round doesn't
  exercise the secrets path, but the test infra needs to land for next round).
  §3 still applies: catch specific exceptions, never `except Exception:`. §5
  (a11y) is non-applicable — backend round.
- `docs/contracts/openapi-v1.yaml` — `/alerts` at line 219; `AlertRecord` at
  line 1090; `AlertList` at line 1110; `AlertListResponse` at line 1571;
  `ProviderProblem` at line 863; `ProviderError` response at line 799;
  `ProviderUnavailable` response at line 807; `CapabilityDeclaration` at line
  1432; `CapabilityRegistry` at line 1450.
- `docs/contracts/canonical-data-model.md` §3.6 (AlertRecord per-field
  enumeration), §3.11 (AlertList container), §4.3 (provider→canonical mapping
  for alerts; severity normalization table).
- `docs/contracts/security-baseline.md` §3.1 (provider HTTP outbound is new
  ground — TLS-cert verification is httpx default; respect it), §3.4 (env-var
  injection for keyed providers; keyless for NWS but the path lands here),
  §3.5 (Pydantic models for **provider** wire shape per
  "Validate provider responses → Pydantic models for each provider's wire shape
  inside the normalizer"), §3.6 (logging/redaction filter — provider URLs and
  query strings logged at INFO; auth headers and api keys never logged per
  redaction filter; NWS URLs are keyless so nothing sensitive in the URL itself).
- `docs/reference/api-docs/nws.md` — full file. The `/alerts/active` example
  response at line 215 is the source of truth for the wire-shape Pydantic
  model. UA requirement at line 11.
- `docs/planning/briefs/phase-2-task-3a-2-brief.md` + remediation brief —
  template structure; existing-code section; reading-list shape; per-endpoint
  spec format; process gates; reporting-back format. Reuse the structure;
  don't re-derive.
- `.claude/agents/clearskies-api-dev.md` — agent definition, including the
  new bullet (2026-05-07) about commit messages documenting non-obvious
  provenance. Round 1 of 3a-2's `b7642ae` ("no such table" branch, opaque
  commit message) cost a clarification round; commit messages this round
  explicitly name speculative vs test-driven choices.

**ADRs to load before implementing:**

- ADR-006 (compliance — operator-managed API keys; v0.1 NWS is keyless but
  the pattern frames future-proofing)
- ADR-008 (auth model — provider modules don't add user auth; UA header is
  not auth, it's identification)
- ADR-010 (canonical entities — AlertRecord, AlertList)
- ADR-011 (single-station — operator lat/lon comes from station metadata, not
  query param)
- ADR-016 (severe weather alerts — single source per deploy, day-1 set is
  nws/aeris/owm, NWS coverage US+territories+marine, 5-min TTL via ADR-017)
- ADR-017 (provider response caching — pluggable backend; memory default;
  per-provider TTL; cache key shape; multi-worker → redis)
- ADR-018 (URL-path versioning, RFC 9457 errors carry providerId/domain/errorCode
  on ProviderProblem extension)
- ADR-027 (config — `[alerts] provider = nws` lands in api.conf; secrets in
  secrets.env loaded via env vars; NWS is keyless but the pattern lands)
- ADR-029 (logging — INFO per-request access log; provider URL logged; redaction
  filter runs; auth headers and api keys redacted; NWS keyless so no redaction
  required by NWS specifically)
- ADR-038 (provider module organization — five module responsibilities, shared
  infra split, capability declaration fields, canonical error taxonomy, testing
  pattern)

ADRs explicitly NOT in scope this round:
- ADR-007 (forecast — next 3b round, not this one)
- ADR-013 (AQI — separate 3b round)
- ADR-015 (radar — separate 3b round)
- ADR-040 (earthquakes — separate 3b round)
- ADR-022/023/026 (theming, dark mode, a11y — Phase 3 dashboard)

---

## Existing code (do not rewrite)

Tasks 1 + 2 + 3a-1 + 3a-2 landed:

- `weewx_clearskies_api/app.py` (178 LOC) — FastAPI app + middleware + routers
  (almanac, archive, capabilities, charts, content, observations, pages, records,
  reports, station). Add the new alerts router following the existing pattern.
- `weewx_clearskies_api/providers/__init__.py` — placeholder docstring only.
  Wire actual subpackages this round.
- `weewx_clearskies_api/db/registry.py` — `wire_registry()` / `get_registry()`
  for `ColumnRegistry`. **Read but don't edit.** The provider registry is a
  parallel structure at `providers/_common/capability.py` — DO NOT collapse
  them into one module; the column registry is DB-backed, the provider
  registry is config-backed.
- `weewx_clearskies_api/endpoints/capabilities.py` — currently returns
  `providers: []`. **This round populates it.** The endpoint reads from
  `providers/_common/capability.py`'s `get_provider_registry()` and merges into
  the existing response; the existing weewxColumns/canonicalFieldsAvailable
  paths stay. canonicalFieldsAvailable is the **union** of stock-column
  canonical fields AND provider-supplied canonical fields per CapabilityRegistry
  schema.
- `weewx_clearskies_api/services/station.py` — `load_station_metadata()` exposes
  station latitude/longitude/timezone for the NWS module (no duplicate weewx.conf
  parse — consume the cached `services/weewx_conf.py` parse).
- `weewx_clearskies_api/config/settings.py` — settings loader. Add an
  `AlertsSettings` block reading the new `[alerts]` section: `provider`
  (optional), `nws_user_agent_contact` (optional). Validate at startup.
- `weewx_clearskies_api/__main__.py` — startup sequence. Add `wire_providers()`
  call after `wire_registry()`, BEFORE uvicorn starts. Same fail-closed-or-warn
  pattern as the existing wires.
- `weewx_clearskies_api/errors.py` — RFC 9457 handler is wired. Extend with
  ProviderProblem subclass that carries providerId/domain/errorCode/retryAfterSeconds
  per OpenAPI ProviderProblem schema. New exception → ProviderProblem mapping
  for the canonical taxonomy.
- `weewx_clearskies_api/models/responses.py` (518 LOC) — Pydantic response models
  for existing endpoints. Add `AlertRecord`, `AlertList`, `AlertListResponse`
  here following the camelCase + extras="ignore" pattern. The
  `CapabilityDeclaration` model already exists from 3a-2; reuse it.
- `weewx_clearskies_api/models/params.py` — Pydantic+Depends pattern from 3a-1.
  Add `AlertsQueryParams` for the `severity` filter; wire the
  `Depends(_get_alerts_params)` route binding.
- `weewx_clearskies_api/logging/redaction_filter.py` — already strips
  Authorization, X-Clearskies-Proxy-Auth, appid, client_secret, SQL params.
  **Verify it also strips httpx-emitted query strings carrying api keys**
  (we don't have a keyed provider this round, but the redaction filter
  needs to be ready for Aeris/OWM next round; document any gap as a flag-not-fix
  finding). The current filter shape works on log RECORD attributes; httpx
  request URLs that include query strings will surface in INFO-level access
  logs — and Aeris's `client_id`/`client_secret` are query-string params. Flag
  if missing; round-1 doesn't need to fix (no keyed provider yet) but a flag
  is owed.

`pyproject.toml` deps already pinned: `cachetools==5.5.2` (used by 3a-2 for
ConfigObj cache; reuse for the memory cache backend's TTLCache),
`configobj==5.0.9`, `fastapi==0.136.1`, `pydantic==2.11.4`, `skyfield>=1.48`,
`sqlalchemy==2.0.49`. **New runtime deps this round:** `httpx` (sync mode) +
`redis` (the redis-py package — required so operators who set
`CLEARSKIES_CACHE_URL` get a working backend without a separate install
step). **New dev-extras:** `respx` (mock-network for httpx) + `fakeredis`
(in-process Redis fake for the redis-backend test path).

---

## Per-endpoint spec

### `GET /alerts` — active severe-weather alerts

- **Query.** `severity` — optional, enum `advisory`/`watch`/`warning` per
  OpenAPI line 230-236. Filter by **minimum** severity (advisory returns all;
  watch returns watch+warning; warning returns warning only). Pydantic-validate
  via `Depends(_get_alerts_params)` (`extra="forbid"`); reject unknown query
  keys with 400 RFC 9457; reject invalid severity value with 400.
- **Response shape per OpenAPI:**
  - 200 → `AlertListResponse(data=AlertList(alerts=[...], retrievedAt=..., source=...), source=..., generatedAt=...)`. Both `data.source` and envelope `source` set to the configured provider id (e.g. `"nws"`) OR `"none"` per Q9.
  - 502 → `ProviderError` (RFC 9457 ProviderProblem) for `KeyInvalid`,
    `TransientNetworkError`, `ProviderProtocolError`.
  - 503 → `ProviderUnavailable` (RFC 9457 ProviderProblem) for `QuotaExhausted`
    (with `Retry-After` header from the provider's response or a sensible
    default like 60 seconds), `GeographicallyUnsupported`. NWS doesn't
    surface 429 in normal use, but the path lands.
  - default → standard Problem.
- **Behavior decision tree:**
  1. `[alerts] provider` not set in api.conf → 200 with `AlertList(alerts=[], retrievedAt=now(), source="none")`. No upstream call. No error.
  2. `[alerts] provider = nws` and NWS API returns 200 with empty features → 200 with `AlertList(alerts=[], retrievedAt=now(), source="nws")`. No error.
  3. `[alerts] provider = nws` and NWS API returns 200 with features → normalize each per §4.3 mapping; apply severity filter; return 200 with `AlertList(alerts=[...], retrievedAt=now(), source="nws")`.
  4. `[alerts] provider = nws` and NWS API returns 5xx / network failure / DNS timeout → raise `TransientNetworkError` → 502 ProviderProblem with `errorCode="TransientNetworkError"`.
  5. `[alerts] provider = nws` and NWS API returns 429 → raise `QuotaExhausted` → 503 ProviderProblem with `errorCode="QuotaExhausted"` + `Retry-After: 60` header.
  6. `[alerts] provider = nws` and NWS API returns 401/403 → raise `KeyInvalid` → 502. (NWS is keyless; this case is exotic — would only fire on a hypothetical UA-block. Lands for free with the canonical taxonomy.)
  7. `[alerts] provider = nws` and NWS response shape unexpected (Pydantic validation failure on the wire model) → raise `ProviderProtocolError` → 502 ProviderProblem with `errorCode="ProviderProtocolError"`. Log at ERROR with the full response body for triage.
- **Cache integration.** Module calls `cache.get(key)` first; key per ADR-017
  is `hash((provider_id="nws", endpoint="/alerts/active", normalized_params={"point": f"{round(lat, 4)},{round(lon, 4)}"}))`. Cache hit → use cached response. Cache miss → call NWS, populate cache with TTL=300s (5 min per ADR-017), return.
- **Severity filter applied AFTER cache lookup.** Per ADR-017 cache key shape, the cache stores the FULL provider response (post-normalization, all severities). The endpoint applies the operator's `severity` query filter to the cached canonical list — one cache entry per station, not one per filter value.
- **No DB hit.** Alerts come from the provider, not weewx archive.
- **Operator lat/lon source.** Read from `services/station.py`'s cached
  `StationMetadata`. Single-station per ADR-011; no `?station=` param.
- **Failure mode: station not yet wired.** If `wire_station()` hasn't completed at request time (impossible per startup ordering — station wires before uvicorn starts), endpoint returns 503 with `Problem(title="Service starting", status=503)`. Defense in depth.

---

## Per-module specs

### Module 1: `providers/_common/` — shared infrastructure

Six files. Read each in order — each builds on the prior.

#### `_common/__init__.py`

Re-export the public API:

```python
from weewx_clearskies_api.providers._common.errors import (
    QuotaExhausted, KeyInvalid, GeographicallyUnsupported,
    FieldUnsupported, TransientNetworkError, ProviderProtocolError,
    ProviderError,  # base class
)
from weewx_clearskies_api.providers._common.capability import (
    ProviderCapability, get_provider_registry, wire_providers,
)
from weewx_clearskies_api.providers._common.http import ProviderHTTPClient
from weewx_clearskies_api.providers._common.cache import (
    CacheBackend, MemoryCache, get_cache,
)
from weewx_clearskies_api.providers._common.rate_limiter import RateLimiter
```

#### `_common/errors.py` — canonical exception taxonomy (ADR-038 §5)

```python
class ProviderError(Exception):
    """Base class for the canonical provider taxonomy.

    Subclasses must NOT carry upstream provider exception types.
    All translation happens in the calling provider module.
    """

    def __init__(
        self,
        message: str,
        *,
        provider_id: str,
        domain: str,
        retry_after_seconds: int | None = None,
    ) -> None:
        super().__init__(message)
        self.provider_id = provider_id
        self.domain = domain
        self.retry_after_seconds = retry_after_seconds


class QuotaExhausted(ProviderError): ...        # → 503 + Retry-After
class KeyInvalid(ProviderError): ...             # → 502
class GeographicallyUnsupported(ProviderError):  # → 503
    ...
class FieldUnsupported(ProviderError): ...       # → 502
class TransientNetworkError(ProviderError): ...  # → 502
class ProviderProtocolError(ProviderError): ...  # → 502, log at ERROR
```

`error_code` for each class is the class name (Pythonic). The mapping
class → HTTP status → ProviderProblem `errorCode` happens in `errors.py`'s
exception handler (extending the existing RFC 9457 path). Add a new handler:

```python
@app.exception_handler(ProviderError)
def provider_error_handler(request, exc):
    status = 503 if isinstance(exc, (QuotaExhausted, GeographicallyUnsupported)) else 502
    body = {
        "type": f"https://clearskies.weewx.org/errors/provider/{exc.__class__.__name__.lower()}",
        "title": exc.__class__.__name__,
        "status": status,
        "detail": str(exc),
        "providerId": exc.provider_id,
        "domain": exc.domain,
        "errorCode": exc.__class__.__name__,
    }
    headers = {}
    if exc.retry_after_seconds is not None:
        body["retryAfterSeconds"] = exc.retry_after_seconds
        headers["Retry-After"] = str(exc.retry_after_seconds)
    return JSONResponse(
        status_code=status,
        content=body,
        media_type="application/problem+json",
        headers=headers,
    )
```

#### `_common/http.py` — HTTP client wrapper

```python
class ProviderHTTPClient:
    """Sync HTTP client wrapped around httpx.Client.

    Owns: timeouts (connect/read/write/pool), TLS verification (default on),
    User-Agent header injection, retry/backoff for transient errors,
    error-class translation to the canonical taxonomy.

    Each provider module instantiates ONE of these at module-load time
    (not per-request).
    """

    def __init__(
        self,
        *,
        provider_id: str,
        domain: str,
        user_agent: str,
        connect_timeout: float = 5.0,
        read_timeout: float = 15.0,
        max_retries: int = 2,
    ) -> None:
        self.provider_id = provider_id
        self.domain = domain
        self._client = httpx.Client(
            headers={"User-Agent": user_agent},
            timeout=httpx.Timeout(connect=connect_timeout, read=read_timeout, write=5.0, pool=5.0),
            verify=True,    # TLS cert verification — never disable
            http2=False,    # NWS doesn't use h2; keep simple. Re-evaluate per provider next round.
            follow_redirects=False,  # provider modules opt into redirect handling; default-off avoids token-leak via 30x
        )

    def get(self, url: str, params: dict[str, str] | None = None) -> httpx.Response:
        """Perform a GET with retry on transient errors.

        Translates upstream error classes to canonical taxonomy:
        - httpx.ConnectError, httpx.ReadTimeout, httpx.RemoteProtocolError,
          5xx response → TransientNetworkError (after retries)
        - 429 → QuotaExhausted (with Retry-After if header present)
        - 401, 403 → KeyInvalid
        - other 4xx → ProviderProtocolError (unexpected client-side error)
        """
        ...

    def close(self) -> None:
        self._client.close()
```

- **Retry/backoff.** Up to 2 retries on `httpx.ConnectError`, `httpx.ReadTimeout`,
  `httpx.RemoteProtocolError`, 5xx responses. Exponential backoff with jitter:
  base 0.5s, factor 2.0, cap 5.0s. **No retries on 4xx** — they're
  not transient.
- **Catch SPECIFIC exception classes** (`httpx.ConnectError`,
  `httpx.ReadTimeout`, etc.) — NOT `Exception`. Per `rules/coding.md` §3.
- **TLS verification.** Default ON. NEVER disable. NWS uses standard CA-signed
  certs; httpx default works.
- **IPv4/IPv6.** httpx uses Python's `socket.getaddrinfo` natively — both
  families work. No special handling required. URL construction does NOT
  embed bracketed IPv6 literals (NWS API hostname is `api.weather.gov`, not
  an IP). Per `rules/coding.md` §1 the rule still applies — don't write a
  regex that only matches IPv4 dotted-quad anywhere in the codebase.
- **No follow_redirects.** Provider modules opt-in if their docs say redirects
  are normal. NWS doesn't redirect; default-off matches.

#### `_common/cache.py` — cache abstraction + memory + redis backends (per ADR-017)

```python
class CacheBackend(Protocol):
    def get(self, key: str) -> Any | None: ...
    def set(self, key: str, value: Any, ttl_seconds: int) -> None: ...


class MemoryCache:
    """In-process LRU+TTL cache backed by cachetools.TTLCache.

    Default backend per ADR-017. Per ADR-017 §Worker-count guidance:
    multi-worker deploys SHOULD switch to RedisCache to avoid burning
    operator API quotas N-times-over.
    """

    def __init__(self, *, max_size: int = 1000) -> None:
        self._cache: TTLCache[str, tuple[Any, float]] = TTLCache(
            maxsize=max_size, ttl=86400,
        )
        # NOTE: TTLCache uses a single ttl per cache instance. We bypass
        # that by storing (value, expires_at) tuples and checking on get.
        # ADR-017 mandates per-provider TTL — the abstraction has to handle it.
        ...

    def get(self, key: str) -> Any | None: ...
    def set(self, key: str, value: Any, ttl_seconds: int) -> None: ...


class RedisCache:
    """Redis-backed cache. Activates when CLEARSKIES_CACHE_URL is set.

    Operator points at a Redis server via env var:
        CLEARSKIES_CACHE_URL=redis://localhost:6379/0
    Multi-worker deploys must use this backend per ADR-017
    §Worker-count guidance.

    Values serialise via JSON (canonical AlertRecord lists are
    JSON-serialisable; future provider domains stick to JSON-friendly shapes).
    Per-key TTL via Redis's native EXPIRE (set with PX milliseconds).
    """

    def __init__(self, *, url: str) -> None:
        # redis-py's Redis.from_url; decode_responses=False so we control
        # encoding (binary keys + JSON-encoded bytes).
        self._client = redis.Redis.from_url(url, decode_responses=False)
        # Verify connectivity at construction; fail fast on misconfig.
        self._client.ping()

    def get(self, key: str) -> Any | None: ...
    def set(self, key: str, value: Any, ttl_seconds: int) -> None: ...


_cache: CacheBackend | None = None


def wire_cache_from_env() -> None:
    """Construct the cache backend from CLEARSKIES_CACHE_URL.

    Unset → MemoryCache().  Set with redis://... → RedisCache(url=...).
    Other URI schemes → CRITICAL log + exit non-zero (operator typo).
    """
    global _cache
    url = os.environ.get("CLEARSKIES_CACHE_URL")
    if not url:
        _cache = MemoryCache()
        return
    if url.startswith("redis://") or url.startswith("rediss://"):
        _cache = RedisCache(url=url)
        return
    raise ConfigError(f"Unsupported CLEARSKIES_CACHE_URL scheme: {url!r}")


def get_cache() -> CacheBackend: ...
```

- **Per-provider TTL.** Memory backend wraps `(value, expires_at_epoch)` so
  cachetools's single-TTL-per-instance limit doesn't bite (~20 LOC). Redis
  backend uses `SET key value PX <ttl_ms>` for native per-key expiry.
- **Cache key construction** lives in the provider module, not here:
  `key = hashlib.sha256(json.dumps(...).encode()).hexdigest()`. Per ADR-017
  §Cache key.
- **Backend selection at startup.** `wire_cache_from_env()` reads
  `CLEARSKIES_CACHE_URL` per ADR-017 §Decision; constructs the right backend.
  `__main__.py` calls it before uvicorn starts.
- **Redis-backend fail-closed at startup.** `Redis.from_url(...).ping()` runs
  at construction; unreachable Redis at startup → CRITICAL log + exit
  non-zero. Same pattern as the read-only DB user check at startup.
- **NOT a request-result cache for /alerts.** This is the **provider response
  cache** per ADR-017 — keyed on `(provider_id, endpoint, params)`, populated
  by the HTTP wrapper, consumed by the provider module. The endpoint-handler
  layer is unaware of caching.
- **CI dev/test stack adds a `redis` profile.** Existing
  `repos/weewx-clearskies-stack/dev/docker-compose.yml` already has
  `mariadb` / `sqlite` / `all` profiles. Add a `redis` profile bringing up
  `redis:7-alpine` so the Redis-backend integration test path runs against
  a real Redis. Memory-backend tests don't need it; they run unchanged.

#### `_common/rate_limiter.py` — per-provider rate limiter

```python
class RateLimiter:
    """In-process sliding-window rate limiter.

    Provider modules instantiate one at module-load time; the HTTP wrapper
    consults it before each outbound call. On limit exceeded, raises
    QuotaExhausted with retry_after_seconds set to the time until the
    earliest call ages out of the window.
    """

    def __init__(self, *, name: str, max_calls: int, window_seconds: int) -> None: ...

    def acquire(self) -> None:
        """Block (or raise) until a call slot is available.

        Implementation: deque of recent call timestamps; at acquire time,
        pop expired entries; if remaining count >= max_calls, raise
        QuotaExhausted with retry_after.
        """
        ...
```

- **Sliding-window over a deque** of timestamps. ~50 LOC. No external lib.
- **Multi-worker note.** Like the cache, per-worker state. Aggressive
  multi-worker deploys may collectively exceed the configured limit; this is
  the Redis trade-off (Pinned for a later round). For NWS at 5 req/s it's
  irrelevant — single-worker default + 5-min cache TTL means we make 1
  request per 5 minutes per station, not 5 per second.
- **Anti-pattern:** thread-safety. Sync FastAPI / sync uvicorn worker doesn't
  multiplex inside a worker, so the deque is single-threaded by construction.
  Don't reach for a lock that isn't needed. (If a future async path lands,
  revisit.)

#### `_common/capability.py` — provider capability registry

```python
@dataclass(frozen=True)
class ProviderCapability:
    """Static capability declaration per ADR-038 §4.

    Each provider module exports one of these as its CAPABILITY symbol.
    """
    provider_id: str
    domain: str             # one of: forecast, alerts, aqi, earthquakes, radar
    supplied_canonical_fields: tuple[str, ...]
    geographic_coverage: str  # "global" or operator-meaningful descriptor
    auth_required: tuple[str, ...] = ()
    default_poll_interval_seconds: int = 300
    operator_notes: str | None = None


_provider_registry: list[ProviderCapability] = []


def wire_providers(declarations: list[ProviderCapability]) -> None:
    """Register configured providers' capability declarations.

    Called once from __main__.py after config-load. Tests may call directly
    with hand-built declarations.
    """
    global _provider_registry
    # Sanity: no two providers may share (domain, provider_id).
    seen = set()
    for d in declarations:
        key = (d.domain, d.provider_id)
        if key in seen:
            raise ValueError(f"duplicate provider capability: {key!r}")
        seen.add(key)
    _provider_registry = list(declarations)


def get_provider_registry() -> list[ProviderCapability]: ...
```

The `/capabilities` endpoint reads `get_provider_registry()` and converts each
`ProviderCapability` → `CapabilityDeclaration` Pydantic model for the
response.

`canonicalFieldsAvailable` becomes the union of:
- weewx-archive canonical fields (existing 3a-2 path: `registry.stock.values()`)
- provider-supplied canonical fields (this round: `{f for p in registry for f in p.supplied_canonical_fields}`)

#### `_common/dispatch.py` — module-by-id dispatch

```python
"""Provider module dispatch.

Maps (domain, provider_id) → the provider module's CAPABILITY + fetch entrypoint.
Phase-2 simple: explicit dict, NOT entry-points (per ADR-038 §Internal contract).

Adding a new provider = importing the new module and adding one row.
"""

from weewx_clearskies_api.providers.alerts import nws as alerts_nws

PROVIDER_MODULES: dict[tuple[str, str], Any] = {
    ("alerts", "nws"): alerts_nws,
}


def get_provider_module(*, domain: str, provider_id: str) -> Any:
    """Return the provider module by (domain, provider_id).

    Raises:
        KeyError: unknown (domain, provider_id) pair.
    """
    return PROVIDER_MODULES[(domain, provider_id)]
```

When 3b round 2 adds Aeris alerts, this gets a new row. When forecast lands,
five new rows. No magic.

### Module 2: `providers/alerts/__init__.py` — empty package marker

One-line file. The dispatch module imports concrete providers from here.

### Module 3: `providers/alerts/nws.py` — the NWS alerts provider

Five responsibilities per ADR-038 §2.

#### Module-level constants

```python
PROVIDER_ID = "nws"
DOMAIN = "alerts"
NWS_BASE_URL = "https://api.weather.gov"
NWS_ALERTS_PATH = "/alerts/active"

CAPABILITY = ProviderCapability(
    provider_id=PROVIDER_ID,
    domain=DOMAIN,
    supplied_canonical_fields=(
        "id", "headline", "description", "severity", "urgency",
        "certainty", "event", "effective", "expires", "senderName",
        "areaDesc", "category", "source",
    ),
    geographic_coverage="us",   # US + territories + adjacent marine zones
    auth_required=(),
    default_poll_interval_seconds=300,
    operator_notes="NWS API requires a User-Agent identifying your app; "
                   "set [alerts] nws_user_agent_contact in api.conf for best results.",
)
```

#### Wire-shape Pydantic models

Per security-baseline §3.5 "Validate provider responses → Pydantic models for
each provider's wire shape inside the normalizer." Per
`rules/clearskies-process.md` "Real schemas in unit tests where the schema
shape matters" — use the recorded fixture shape, don't invent.

```python
class _NwsAlertProperties(BaseModel):
    """NWS /alerts/active feature properties — wire shape.

    Source: https://api.weather.gov/openapi.json + recorded fixture at
    tests/fixtures/providers/nws/alerts_active.json.

    extras="ignore" so NWS schema additions don't break us; missing required
    fields raise → ProviderProtocolError.
    """
    model_config = ConfigDict(extra="ignore")

    id: str
    areaDesc: str | None = None
    sent: str | None = None
    effective: str
    onset: str | None = None
    expires: str | None = None
    ends: str | None = None
    status: str | None = None
    messageType: str | None = None
    category: str | None = None
    severity: str  # CAP enum: Extreme/Severe/Moderate/Minor/Unknown
    certainty: str | None = None
    urgency: str | None = None
    event: str
    sender: str | None = None
    senderName: str | None = None
    headline: str
    description: str | None = ""
    instruction: str | None = None
    response: str | None = None


class _NwsAlertFeature(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str | None = None
    type: str | None = None
    properties: _NwsAlertProperties


class _NwsAlertsActiveResponse(BaseModel):
    """NWS /alerts/active response envelope — wire shape."""
    model_config = ConfigDict(extra="ignore")
    type: str
    features: list[_NwsAlertFeature] = Field(default_factory=list)
    title: str | None = None
    updated: str | None = None
```

#### `fetch(*, lat: float, lon: float) -> AlertList` — public entrypoint

Single callable per domain (alerts). Future domains may have multiple (forecast
has hourly+daily+discussion). The `fetch` shape is locked by domain ADR per
ADR-038 §Implementation guidance.

```python
def fetch(*, lat: float, lon: float, user_agent_contact: str | None) -> list[AlertRecord]:
    """Call NWS /alerts/active and return canonical AlertRecord list.

    Caching, rate-limiting, error-class translation handled by ProviderHTTPClient
    + module-level instances. Raises canonical taxonomy on failure.

    Returns empty list when NWS returns 200 with no features (operator outside
    US coverage, or no active alerts in the area).
    """
    cache_key = _build_cache_key(lat, lon)
    cached = get_cache().get(cache_key)
    if cached is not None:
        return cached

    rate_limiter.acquire()
    user_agent = _build_user_agent(user_agent_contact)
    client = _client_for(user_agent)

    point_str = f"{round(lat, 4)},{round(lon, 4)}"
    response = client.get(
        f"{NWS_BASE_URL}{NWS_ALERTS_PATH}",
        params={"point": point_str},
    )

    try:
        wire = _NwsAlertsActiveResponse.model_validate(response.json())
    except ValidationError as exc:
        raise ProviderProtocolError(
            f"NWS response validation failed: {exc}",
            provider_id=PROVIDER_ID,
            domain=DOMAIN,
        ) from exc

    canonical = [_to_canonical(feature.properties) for feature in wire.features]
    get_cache().set(cache_key, canonical, ttl_seconds=300)
    return canonical
```

Notes:
- **Lat/lon rounded to 4 decimals.** Matches ADR-017 §Cache key normalization.
- **`Accept` header.** httpx default is `*/*`; NWS prefers `application/geo+json`.
  Set per request: `client.get(url, params=..., headers={"Accept": "application/geo+json"})`.
- **Cache layer.** Stores the canonical list (post-normalization), not the raw
  GeoJSON. Saves re-normalization cost on cache hit.

#### `_to_canonical(props)` — wire → canonical normalization

Per canonical-data-model §4.3.

```python
def _to_canonical(props: _NwsAlertProperties) -> AlertRecord:
    description = props.description or ""
    if props.instruction:
        description = f"{description}\n\n{props.instruction}".strip()

    return AlertRecord(
        id=props.id,
        headline=props.headline,
        description=description,
        severity=_normalize_severity(props.severity),
        urgency=props.urgency,
        certainty=props.certainty,
        event=props.event,
        effective=_to_utc_iso8601(props.effective),
        expires=_to_utc_iso8601(props.expires) if props.expires else None,
        senderName=props.senderName,
        areaDesc=props.areaDesc,
        category=props.category,
        source=PROVIDER_ID,
    )
```

#### Severity normalization (canonical-data-model §4.3)

```python
_NWS_SEVERITY_MAP: dict[str, str] = {
    "Extreme": "warning",
    "Severe": "watch",
    "Moderate": "advisory",
    "Minor": "advisory",
    "Unknown": "advisory",
}


def _normalize_severity(nws_severity: str) -> str:
    """Map NWS CAP severity to canonical {advisory, watch, warning}.

    Unknown values default to 'advisory' (least severe canonical) per the
    §4.3 mapping table; log at WARNING so a future NWS schema change
    surfaces in operator logs.
    """
    canonical = _NWS_SEVERITY_MAP.get(nws_severity)
    if canonical is None:
        logger.warning(
            "Unknown NWS CAP severity %r; defaulting to 'advisory'",
            nws_severity,
        )
        return "advisory"
    return canonical
```

#### `_to_utc_iso8601(s)` — date-time normalization

NWS emits ISO-8601 with offset (`2026-04-30T16:00:00-07:00`). The canonical
contract is UTC ISO-8601 with `Z` per ADR-020. Convert via stdlib `datetime`.

```python
def _to_utc_iso8601(s: str) -> str:
    """NWS timestamp (offset form) → UTC ISO-8601 with Z suffix.

    Raises ProviderProtocolError on parse failure (response shape unexpected).
    """
    try:
        dt = datetime.fromisoformat(s)
    except ValueError as exc:
        raise ProviderProtocolError(
            f"NWS timestamp parse failed for {s!r}: {exc}",
            provider_id=PROVIDER_ID, domain=DOMAIN,
        ) from exc
    if dt.tzinfo is None:
        # NWS always emits offset; bare-naive is a protocol violation
        raise ProviderProtocolError(
            f"NWS timestamp {s!r} has no timezone offset",
            provider_id=PROVIDER_ID, domain=DOMAIN,
        )
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
```

Reuse `utc_isoformat` from `models/responses.py` if it accepts arbitrary
tz-aware datetimes; otherwise this dedicated helper handles the offset-form
parse.

---

## Cross-cutting requirements

### Pydantic + `Depends(_get_alerts_params)` pattern (carry-forward from 3a-1)

`/alerts` takes the optional `severity` query param. Use the wrapper pattern.
`extra="forbid"` only fires when the whole query string flows through Pydantic
via `Depends()`. The other 3b rounds will follow the same pattern for their
query params.

### RFC 9457 errors (carry-forward + extension)

Existing `errors.py` handles RFC 9457 for the standard error path. Extend with
the `ProviderError` handler (per `_common/errors.py` snippet above) that emits
`application/problem+json` with the `ProviderProblem` extension fields
(`providerId`, `domain`, `errorCode`, optional `retryAfterSeconds`).

### Logging (carry-forward + extension)

Per ADR-029. Provider HTTP outbound calls log at INFO with: provider_id,
domain, URL (sans query string for keyed providers — keyless NWS is fine to
log), elapsed_ms, status_code. On error: log at WARNING (transient) or ERROR
(protocol). Cache hit/miss counters log at DEBUG (don't spam INFO).

**Redaction-filter check for next round.** The redaction filter strips
Authorization/X-Clearskies-Proxy-Auth/appid/client_secret/SQL params today.
Aeris uses `client_id`/`client_secret` in query strings; OWM uses `appid`.
**Verify the filter strips these from log URLs** when 3b round 2 lands. For
this round (NWS keyless), the filter doesn't need a change — but the test
infra to test the filter against keyed-provider URL strings does need to land.
Document in the closeout report whether the existing filter handles the case
or whether next round needs to extend it.

### Catch specific exceptions (carry-forward from 3a-1, 3a-2)

`rules/coding.md` §3 — no `except Exception:`. The HTTP wrapper catches
specific httpx exception classes (`ConnectError`, `ReadTimeout`,
`RemoteProtocolError`, etc.) and the `httpx.HTTPStatusError` for 4xx/5xx
classification. The Pydantic validation path catches `ValidationError`. The
canonical taxonomy is what the rest of the code base catches from provider
modules — never the upstream httpx classes.

### No live-network tests in CI (ADR-038 §Testing pattern)

Recorded fixture: `tests/fixtures/providers/nws/alerts_active.json` (real NWS
response captured manually once). All mock-network tests use `respx` to
patch the URL → fixture mapping. No conftest hook makes outbound HTTP from CI.

### Capability-population wire (one-time, at startup)

In `__main__.py`, after `wire_registry()` completes:

```python
def _wire_providers_from_config(settings: Settings) -> None:
    """Build the provider declarations list from operator config and register.

    Single source per domain per ADR-016. If [alerts] provider is set,
    look up the module via dispatch and register its CAPABILITY.
    """
    declarations: list[ProviderCapability] = []
    if settings.alerts.provider:
        module = get_provider_module(domain="alerts", provider_id=settings.alerts.provider)
        declarations.append(module.CAPABILITY)
    # Future rounds extend this with forecast, aqi, earthquakes, radar.
    wire_providers(declarations)


_wire_providers_from_config(settings)
```

**Failure modes:**
- `[alerts] provider = <unknown-id>` → `KeyError` from `get_provider_module()`
  → CRITICAL log + exit non-zero at startup. Operator misconfiguration; fail
  closed.
- `[alerts] provider` absent → empty declarations list; `/alerts` returns
  `source="none"` per Q9.

### No new ADRs

ADR-038 already covers the module organization. ADR-016 covers alerts-domain
specifics. ADR-017 covers caching. ADR-018 covers the error format. **STOP and
ping the lead** if implementation surfaces a need for a new ADR; that's a
process call, not a code call.

### No new dependencies except those listed

Pre-approved this round:

- **Runtime:** `httpx` (sync mode), `redis` (the redis-py package).
- **Dev-extras:** `respx` (mock-network for httpx), `fakeredis`
  (in-process Redis fake for unit tests of the Redis backend).

Add via `uv add httpx redis` (runtime), `uv add --dev respx fakeredis`
(dev-extras). Pin in `pyproject.toml`. Regenerate `uv.lock`. STOP and ping
the lead if you think you need anything else. Specifically: NO `requests`,
NO `aiohttp`, NO `tenacity` (write retry inline — ~30 LOC, simpler than
configuring a library), NO `cachetools` reach (already in deps; use it for
the memory backend).

---

## Test-author parallel scope

Run `pytest` on `weather-dev` (192.168.2.113); never on DILBERT.

### Recorded fixture capture

`tests/fixtures/providers/nws/alerts_active.json` — captured manually from a
real NWS response. Recommended capture command (run once on `weather-dev`,
not in CI):

```bash
curl -H "User-Agent: (clearskies-test-fixture-capture, contact@example.com)" \
     -H "Accept: application/geo+json" \
     "https://api.weather.gov/alerts/active?point=47.6062,-122.3321" \
     | python -m json.tool > tests/fixtures/providers/nws/alerts_active.json
```

The fixture should include AT LEAST ONE alert (capture during an active-alert
window, OR commit a hand-crafted-from-a-prior-real-response fixture if no
alerts active). Document the capture date in a sidecar `.md` next to the
fixture for future replay context.

Also capture/craft these adjacent fixtures for negative-path testing:
- `alerts_active_empty.json` — NWS 200 with `features: []` (operator location
  with no active alerts; common case).
- `alerts_active_extreme.json` — at least one Extreme severity alert (for
  severity-mapping test).
- `alerts_active_unknown_severity.json` — hand-crafted variant with a
  hypothetical unknown CAP severity (e.g., `"Critical"`) for the
  unknown-severity-default-to-advisory test path.
- `alerts_active_malformed.json` — hand-crafted variant missing the required
  `headline` field for the ProviderProtocolError path.

### Unit tests (no DB, no network — `respx` mock or pure-compute)

- **Severity normalization.** Each of the five CAP severities maps correctly:
  Extreme→warning, Severe→watch, Moderate/Minor/Unknown→advisory. Unknown CAP
  string (e.g. `"Critical"`) → advisory + WARNING log.
- **Time normalization.** NWS `2026-04-30T16:00:00-07:00` →
  `2026-04-30T23:00:00Z`. NWS UTC `2026-04-30T16:00:00+00:00` →
  `2026-04-30T16:00:00Z`. NWS naive `2026-04-30T16:00:00` →
  `ProviderProtocolError`. NWS bogus → `ProviderProtocolError`.
- **`_to_canonical` mapping.** `_NwsAlertProperties` instance with
  description+instruction populated → canonical AlertRecord with
  `description = description + "\n\n" + instruction`. With instruction
  null → description as-is.
- **Wire-shape Pydantic.** Real fixture loads cleanly. Missing required field
  (e.g., headline) → `ValidationError`. Extra field (NWS adds a new property)
  → ignored cleanly.
- **AlertsQueryParams.** Reject unknown query keys (`extra="forbid"`); reject
  invalid severity value; accept valid severities; missing severity OK
  (no filter applied).
- **Severity filter.** Given a canonical list of 3 alerts (advisory, watch,
  warning), severity=advisory returns all 3; watch returns 2; warning
  returns 1.
- **Cache abstraction — memory backend.** `MemoryCache.set(key, value, 60)`
  then `get(key)` returns value. Wait past TTL (use `freezegun` or
  sleep-then-check with a short TTL), `get(key)` returns None. Two writes
  with different TTLs are independent.
- **Cache abstraction — redis backend (using `fakeredis`).** Same get/set
  contract; per-key TTL semantics (`fakeredis` honours TTLs). JSON
  serialisation round-trip preserves the canonical AlertRecord shape.
  Connection refused at construction → exception (paired with the
  startup-fail-closed test below).
- **`wire_cache_from_env()`.** `CLEARSKIES_CACHE_URL` unset → MemoryCache.
  Set to `redis://...` (with fakeredis monkey-patched) → RedisCache.
  Set to a bogus scheme (`memcached://...`) → ConfigError.
- **RateLimiter.** 5 calls in 1 second succeed; 6th raises `QuotaExhausted`
  with retry_after_seconds set. After window expires, slots free up.
- **HTTP wrapper error translation.**
  - 200 → response returned, no exception.
  - 5xx (mocked via respx) → after retries, `TransientNetworkError`.
  - 429 with Retry-After header → `QuotaExhausted` with retry_after.
  - 401 → `KeyInvalid`.
  - Connection error (mocked) → `TransientNetworkError`.
  - Timeout (mocked) → `TransientNetworkError`.
- **NWS module fetch (respx-mocked).**
  - 200 with empty features → returns `[]`.
  - 200 with one alert → returns one canonical AlertRecord; severity mapped
    correctly; description-with-instruction concatenation correct.
  - 200 with malformed payload (missing required field) → `ProviderProtocolError`.
  - 5xx → after retries, `TransientNetworkError` (translated from httpx).
  - 429 → `QuotaExhausted`.
- **Capability registry.** `wire_providers([cap1, cap2])` populates;
  `get_provider_registry()` returns the same list. Duplicate (domain, provider_id)
  raises `ValueError`. Empty list → empty registry.
- **/capabilities response.** With NWS configured, response has 1 entry in
  `providers` with provider_id=nws, domain=alerts; canonicalFieldsAvailable
  is the union of stock columns AND NWS's supplied fields. With no provider
  configured, `providers: []` (carry-forward from 3a-2 baseline).
- **/alerts endpoint with no provider configured.** Response shape: 200,
  `data.alerts: []`, `data.source: "none"`, `data.retrievedAt` set,
  envelope `source: "none"`, envelope `generatedAt` set.
- **/alerts endpoint with NWS configured (respx-mocked NWS) — happy path.**
  200; data.alerts has the expected entries; source: "nws".
- **/alerts endpoint with NWS configured + cache hit.** Pre-populate cache;
  endpoint returns cached canonical list; no NWS call (assert via respx
  call count = 0). Run twice — once with `wire_cache_from_env()` configured
  for memory, once for redis (via fakeredis).
- **/alerts endpoint with NWS down.** respx-mocked 503 from NWS → endpoint
  returns 502 ProviderProblem with errorCode=TransientNetworkError, after
  retries.
- **/alerts endpoint with NWS quota exhausted.** respx-mocked 429 → 503
  ProviderProblem with errorCode=QuotaExhausted + Retry-After header.

### Integration tests (against the docker-compose dev/test stack — both DB backends + both cache backends)

Mark each with `@pytest.mark.integration`.

- **/alerts with no provider configured** — full TestClient → 200,
  `alerts: []`, `source: "none"`. No network involved.
- **/alerts with NWS configured + respx-mocked NWS** — TestClient calls /alerts;
  respx intercepts the outbound httpx call to NWS; returns the recorded
  fixture; endpoint normalizes and returns 200. Both backends green
  (the alerts endpoint doesn't hit the DB but the test infra runs against
  both backends per `rules/clearskies-process.md` "Real schemas in unit
  tests where the schema shape matters" — schema-shape doesn't apply here,
  but the test runs in both contexts to confirm the endpoint is DB-stack
  agnostic).
- **/capabilities with NWS configured** — response includes the NWS provider
  declaration; canonicalFieldsAvailable is the union of stock + NWS supplied.
- **Startup with `[alerts] provider = unknown_provider`** — process exits
  non-zero; stderr contains the canonical error message. Use a subprocess
  test harness OR a unit test of `_wire_providers_from_config` raising
  `KeyError` cleanly.
- **Startup with `CLEARSKIES_CACHE_URL=redis://unreachable:6379/0`** —
  process exits non-zero at startup (Redis ping fails). Use the
  subprocess-style harness OR unit-test `wire_cache_from_env()` raising
  cleanly.
- **Redis-backend integration (real Redis via `redis` compose profile).**
  Optional integration tier: `pytest -m "integration and redis"` runs
  /alerts end-to-end against a real Redis. Default `pytest -m integration`
  skips the redis tier; the `redis` mark adds it for CI's Redis matrix job.

### Schema-shape rule (`rules/clearskies-process.md`)

The provider tests don't depend on weewx archive schema shape (alerts come
from the provider, not the DB) so the schema-shape rule mostly doesn't apply
here. However: the wire-shape Pydantic models for NWS responses MUST be
validated against the recorded fixture — synthetic minimal stand-ins (e.g.,
just `{"id", "headline"}`) hide the real NWS-shape bugs the same way
synthetic DB schemas hid them in 3a-1. Rule applies to provider wire shapes
too. Use the recorded fixture or hand-crafted-from-real-response variants;
not minimal synthetic.

### Tests run on `weather-dev` BEFORE the dev submits for audit

Per `rules/clearskies-process.md` "Audit modes are complementary, not
redundant" — pytest-on-real-stack catches a different bug class than the
auditor's source review. Both gates fire.

### Marker

All integration tests carry `@pytest.mark.integration` so the existing
`pytest -m integration` selector picks them up. Unit tests run by default.

---

## Process gates

1. **ADR conflicts → STOP.** If anything in `openapi-v1.yaml` disagrees with
   an ADR or with canonical-data-model, do not proceed-and-flag at closeout.
   Stop at the first conflict, message the lead, wait for a call.
2. **Deps PRE-APPROVED by the lead 2026-05-07.** Runtime: `httpx`, `redis`.
   Dev-extras: `respx`, `fakeredis`. Add via `uv add httpx redis` and
   `uv add --dev respx fakeredis`. Pin in `pyproject.toml`. Regenerate
   `uv.lock`. Anything else → STOP.
3. **Diff size budget.** Target ~2500–4000 line diff for the implementation
   (not counting tests). Larger than 3a-2 by ~75–100% because of the shared
   infra (HTTP wrapper + retry + error taxonomy + capability registry +
   memory cache + Redis cache + rate limiter) plus the NWS module.
   If it crosses 4500, ping the lead before submitting for audit; we may
   split the round retroactively.
4. **Run pytest on weather-dev before submitting for audit.** Both backends
   green via `pytest -m integration` against MariaDB and SQLite profiles.
   Pre-existing skipped test (`test_mariadb_writable_seed_user_probe_exits_nonzero`)
   stays skipped; not a regression.
5. **Parallel-pull-then-pytest.** `git fetch origin main && git merge --ff-only
   origin/main` BEFORE the pre-submit pytest run, so api-dev's suite covers
   test-author's latest. Hard gate. **Branch is `main`** (verified 2026-05-07).
6. **Auditor reviews after both api-dev and test-author submit + green
   pytest.** Lead synthesizes findings and routes back to the relevant agent.
   Don't auto-loop. Lead picks remediation per finding.
7. **Submit closeout report immediately after the final pytest run.** Don't
   idle. The lead-side polling cadence (4-min ScheduleWakeup + SendMessage)
   is the safety net, not the primary path.
8. **Commit messages document non-obvious provenance** per the
   `clearskies-api-dev` agent definition update 2026-05-07. Especially for:
   - Why the cache abstraction wraps cachetools (per-TTL payload pattern, not
     direct TTLCache use)
   - Why a specific httpx exception class is caught at a specific site
   - Why retry counts / backoff base / jitter are the chosen values
   - Any defensive workaround you add and why
9. **DCO + co-author trailer.** `git commit -s` plus
   `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>` for api-dev /
   test-author work; Opus uses `Co-Authored-By: Claude Opus 4.7 (1M context)
   <noreply@anthropic.com>`.

---

## Anti-patterns (don't)

- Don't add Aeris or OpenWeatherMap alerts modules this round. ADR-016 day-1
  set is three providers, but they ship one round at a time.
- Don't add forecast/AQI/earthquakes/radar provider modules. Separate 3b
  rounds.
- Don't reach for `requests`, `aiohttp`, `tenacity`, or any other HTTP/retry
  library. `httpx` covers the surface.
- Don't disable TLS verification. NEVER. Even for testing — use respx.
- Don't bypass the canonical error taxonomy. Provider modules raise from the
  `ProviderError` hierarchy; nowhere else in the codebase catches httpx
  exception classes.
- Don't catch `Exception:`. Catch the specific class. (`rules/coding.md` §3)
- Don't skip the recorded fixture. Synthetic minimal stand-ins for the wire
  shape hide protocol-evolution bugs the same way synthetic DB schemas hid
  multi-column constraint bugs. Use the real fixture.
- Don't make outbound HTTP from CI tests. Live-network tests are
  developer-local per ADR-038.
- Don't store the full GeoJSON in the cache; cache the post-normalization
  canonical list. Saves cycles on cache hit.
- Don't add a request-result cache at the FastAPI handler level. The
  ADR-017 cache is at the provider response level — keyed by
  (provider_id, endpoint, params), not by URL+request-headers.
- Don't write a regex for "an IP address" anywhere. We don't need one for
  alerts work, but the `coding.md` §1 rule applies — IP parsing uses
  `ipaddress.ip_address` if it ever surfaces.
- Don't read api.conf twice. The settings loader caches it; provider modules
  consume settings via the existing pattern, not by re-parsing.
- Don't import skyfield in provider modules. Almanac is a separate concern.
- Don't import sqlalchemy in provider modules. Alerts come from the provider,
  not the DB. (Future weewx-archive-fed providers may import it; this round
  doesn't have one.)
- Don't add a multi-provider aggregation path. ADR-016 §B is rejected; one
  source per deploy.
- Don't hardcode the project's git URL or maintainer email as the NWS
  User-Agent contact. Per Q7, that's an operator config knob.
- Don't break 3a-2's `/capabilities` response shape. The endpoint extends —
  the existing weewxColumns/canonicalFieldsAvailable paths stay; providers
  appears with content instead of `[]`.
- Don't hold across turns. Write to a file as you go.

---

## Reporting back

When you're done, report to the lead:

- **Files touched.** Relative paths + LOC delta. Group by `_common/`,
  `providers/alerts/`, `endpoints/`, `models/`, `__main__.py`, `errors.py`,
  `config/`, `tests/`.
- **ADRs and rules that governed each substantive choice.** Reference the
  10 lead+user-confirmed calls at the top of this brief.
- **Pytest counts both backends.** Total / unit / integration / passes /
  failures / skips. Note any newly-skipped tests and why.
- **Recorded fixture provenance.** When was the NWS response captured? From
  what location? How many alerts in the fixture? Sidecar `.md` documents
  this; reference it.
- **Cache abstraction + per-TTL pattern.** Confirm the per-TTL semantics work
  through cachetools.TTLCache (the wrap-with-expires_at_epoch trick) and that
  the unit test verifies expiration after TTL.
- **HTTP retry behavior.** Confirm the retry counts / backoff base / jitter
  values; describe the 5xx path; confirm 4xx never retries.
- **Redaction-filter check for next round.** Does the existing redaction
  filter cover query-string `client_id`/`client_secret`/`appid`? If not,
  flag (don't fix) — next round (3b round 2: keyed alerts providers) owns
  the extension.
- **Capability registry shape verified against /capabilities response.**
  Spot-check the JSON output of /capabilities with NWS configured; confirm
  it round-trips through the OpenAPI CapabilityDeclaration schema.
- **Anything that surprised you in the existing task 1 / 2 / 3a-1 / 3a-2
  code** — especially around how the existing `wire_*` patterns interact
  with the new `wire_providers()` and `wire_cache()` calls.
- **Any deviation from this brief** (and why).

---

## Out of scope, parking lot for follow-ups

- **Aeris alerts module.** Next 3b round (or one after).
- **OpenWeatherMap alerts module.** Next 3b round (or one after).
- **Setup wizard region-based provider suggestion** — Phase 4 per ADR-027.
- **Capability-registry HTTP endpoint shape changes** — locked at v0.1.
- **Multi-source aggregation across alerts providers** — ADR-016 §B rejected;
  Phase 6+ if demand surfaces.
- **Per-operator alert-thresholds (e.g. "notify when wind > 50 mph")** —
  ADR-016 §Out of scope; orthogonal to upstream alerts; Phase 6+.
- **Push notifications (web push / email / SMS)** — ADR-016 §Out of scope;
  Phase 6+.
- **`_GROUP_MEMBERS` parity test against canonical-data-model §2.1** — still
  open from 3a-1 parking lot; not 3b round 1 scope.
- **Redaction filter extension for query-string keys** — flag if missing this
  round; next round (3b keyed providers) extends. Don't extend in 3b round 1
  unless the existing tests fail.
- **Live-network test against api.weather.gov** — developer-local workflow
  per ADR-038 §Testing pattern. Document the manual capture command in the
  fixture sidecar.
- **HTTP/2 for provider clients** — httpx supports h2 with the `h2` extra;
  NWS doesn't use h2 today; revisit per provider next round if a provider's
  docs recommend it.
- **`follow_redirects` per provider** — default off; revisit per provider
  if their docs say redirects are normal.
