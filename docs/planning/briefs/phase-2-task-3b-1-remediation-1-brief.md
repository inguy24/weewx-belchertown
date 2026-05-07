# Phase 2 task 3b round 1 — remediation round 1

**Round identity.** Round 2 of Phase 2 task 3b round 1. Round 1 closed 2026-05-07
with 642/24 pytest pass on weather-dev (both DB backends + both cache backends);
auditor surfaced 17 findings (1 HIGH, 2 MEDIUM, 3 LOW, 11 audit-confirmed-no-issue).
Lead synthesized into 5 findings to fix this round + 1 deferred to round 2 + 1
lead-owned (already applied as a0f5b5b's follow-up).

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (impl fixes),
`clearskies-test-author` (test updates for F12 only). Auditor (Opus) does NOT
re-pass unless the lead requests it.

**Repo.** `c:\CODE\weather-belchertown\repos\weewx-clearskies-api\` on branch
`main`.

**Round-1 brief stays the source of truth.** This document patches it. Read
[`phase-2-task-3b-1-alerts-brief.md`](phase-2-task-3b-1-alerts-brief.md) in
full first if you weren't on round 1.

---

## Findings to fix

### F1a — `except Exception:` in `endpoints/alerts.py` (HIGH, api-dev)

- **Where:** `weewx_clearskies_api/endpoints/alerts.py:101`
- **Code:** the wrap around `AlertsQueryParams.model_validate(...)`
  catches `Exception` and falls back on a `hasattr(exc, "errors")` defensive
  form. Pydantic v2's `model_validate` only raises `ValidationError` on
  validation failure; the broad catch swallows programmer errors and
  KeyboardInterrupt as 422s. Brief §Anti-patterns explicitly bans
  `except Exception:`; `rules/coding.md` §3 same.
- **Fix:** catch `pydantic.ValidationError` specifically, drop the
  `hasattr(exc, "errors")` defensive form. The 3a-1/3a-2 endpoints already
  use this exact pattern — copy.

### F1b — `except Exception:` in `providers/_common/cache.py` (HIGH, api-dev)

- **Where:** `weewx_clearskies_api/providers/_common/cache.py:169`
- **Code:** the wrap around `Redis.from_url(...).ping()` catches `Exception`.
  The defensive comment justifies the broad catch; that's not exemption.
  redis-py exposes `redis.exceptions.RedisError` as the base class for
  ConnectionError, ResponseError, AuthenticationError, TimeoutError — covers
  the documented set without swallowing programmer errors.
- **Fix:** catch `redis.exceptions.RedisError`. Same import path as the rest of
  the cache module.

### F2 — `RedisCache.get()` / `set()` leak raw redis exceptions (MEDIUM, api-dev)

- **Where:** `weewx_clearskies_api/providers/_common/cache.py:180-192` (`get`)
  and the corresponding `set` call site.
- **Code:** `self._client.get(key.encode())` and `self._client.set(...)` are
  not wrapped. If Redis goes down between the startup `ping()` and a request,
  raw `redis.exceptions.ConnectionError` propagates out of the cache layer.
  The `errors.py` exception handler then catches it as the generic 500 path
  rather than translating to 502 ProviderProblem (errorCode=TransientNetworkError).
  Defense-in-depth gap — ADR-038 §5 says "no upstream provider exception type
  leaks"; this is the cache analog.
- **Fix:**
  - `get()` — wrap `self._client.get(...)` in `try/except redis.exceptions.RedisError as exc:`. On exception: log at WARNING with the key + error class, return `None` (cache miss is the correct degraded behavior — provider call still goes through).
  - `set()` — wrap in same. On exception: log at WARNING, swallow (the next request just re-fetches; cache write failure is non-fatal).
- **Why log at WARNING not ERROR:** transient cache backend failure is
  recoverable from the request's perspective (provider call still happens);
  ERROR is reserved for genuinely-unrecoverable conditions per ADR-029.

### F12 — `nws.fetch()` return type → flip back to `list[AlertRecord]` (MEDIUM, api-dev + test-author)

- **Where:** `weewx_clearskies_api/providers/alerts/nws.py:360-365` (the
  `fetch()` signature + return) + the cache-hit defensive branch at
  `nws.py:386-393` + the consumer at `endpoints/alerts.py:200`.
- **Code:** commit d4e8d2c flipped `fetch()` from `→ list[AlertRecord]` to
  `→ list[dict]` because tests used dict access. The cache-hit branch has a
  dead `isinstance(item, AlertRecord)` defensive arm that exists only to
  accommodate test-injection. The endpoint reconstructs AlertRecord via
  `model_validate(d)` at the wire boundary.
- **Lead's call:** **option (a) — flip back to `list[AlertRecord]`.** ADR-038
  §2 says provider modules' third responsibility is "Translation to canonical
  Clear Skies fields"; canonical entities are Pydantic models, not their JSON
  serializations. Brief explicitly typed `fetch() → list[AlertRecord]`. Tests
  should match the contract; not the other way around.

#### api-dev's part of F12

- `providers/alerts/nws.py:fetch()` — return type back to `list[AlertRecord]`.
  Construct AlertRecord from `_to_canonical(props)` and return that list.
- `providers/alerts/nws.py` cache-write path — call
  `[record.model_dump() for record in canonical]` to store dicts in the cache
  (cache stays JSON-serializable for Redis); cache-read path reconstructs via
  `[AlertRecord.model_validate(d) for d in cached_dicts]` and returns the
  reconstructed list.
- `providers/alerts/nws.py` cache-hit defensive branch — drop the
  `isinstance(item, AlertRecord)` arm. Cached items are always dicts (post-
  `model_dump()`); reconstruction is unconditional via `model_validate`.
- `endpoints/alerts.py` — the `[AlertRecord.model_validate(d) for d in raw_dicts]`
  loop at the consumer site goes away; `fetch()` now returns AlertRecord
  objects directly.

#### test-author's part of F12

- `tests/test_providers_alerts_unit.py` — every test that does
  `alert_dict["severity"]` / `alert_dict["headline"]` / etc. on `fetch()`
  output switches to attribute access (`alert.severity`, `alert.headline`).
  Search-and-replace + a careful eye for assertions that compared dict shape.
- `tests/test_providers_alerts_integration.py` — same; the integration test
  side may not have many of these (the endpoint is the consumer; the response
  is JSON), but check.
- The cache pre-population pattern in
  `test_cache_hit_returns_cached_data_no_nws_call` — pre-populate with dicts
  (post-`model_dump()`), since that's what `fetch()` actually stores. Do NOT
  pre-populate with AlertRecord instances anymore (that pattern is what made
  the dead `isinstance` branch necessary).

### F17 — `_NwsAlertsActiveResponse.type` accepts any string (LOW, api-dev)

- **Where:** `weewx_clearskies_api/providers/alerts/nws.py:181`
- **Code:** `type: str`. GeoJSON FeatureCollection's `type` is fixed to
  `"FeatureCollection"`. Accepting any string lets a malformed NWS response
  with `type: "Feature"` slip past wire-shape validation and proceed to
  `wire.features` extraction (which works because `features` defaults to
  `[]`). A protocol drift the wire model is supposed to catch returns `[]`
  silently instead of raising `ProviderProtocolError`.
- **Fix:** `type: Literal["FeatureCollection"]`. Same for
  `_NwsAlertFeature.type` if NWS docs say it's always `"Feature"` (per
  `docs/reference/api-docs/nws.md` and the recorded fixture, yes — apply
  there too).

---

## Lead-owned (already applied)

### F15 — `integration_app_no_provider` teardown asymmetry (LOW)

Applied 2026-05-07 by lead in this same diff. `integration_app_no_provider`
gained the `reset_cache_for_tests()` + `reset_provider_registry_for_tests()`
calls before `wire_cache_from_env()` AND after `yield app` to mirror the
`integration_app_nws` shape. 6-line edit. Not committed yet — bundled into
the api-dev remediation commit OR pushed first as a lead-only commit (api-dev
choose; either is fine).

---

## Deferred to a later round

### F13 — Redaction filter doesn't strip `client_id` (LOW)

Defer to 3b round 2 (Aeris alerts provider). Aeris uses `client_id` as a
query-string param; until that round lands, no provider in the codebase
exercises the filter gap at runtime. Round 2's brief carries this as a
must-fix before the Aeris module ships.

---

## Findings the auditor explicitly verified as correct (no fix needed)

For the record: F3 (severity normalization), F4 (cache key shape), F5 (per-TTL
pattern in MemoryCache), F6 (Redis fail-closed at startup — the broader
flow is correct; F1b is a sub-issue), F7 (unknown-provider-id startup),
F8 (datetime normalization rejects naive timestamps), F9 (no-provider
behavior emits envelope `source="none"`), F10 (`/capabilities`
canonicalFieldsAvailable union calculation), F11 (Pydantic+Depends pattern
wires `extra="forbid"` correctly — F1a is the broad-catch sub-issue),
F14 (ProviderProblem response body matches OpenAPI), F16 (HTTP wrapper
retries only on 5xx + listed httpx exceptions, never on 4xx).

---

## Process gates (carry-forward, not new)

1. **Branch is `main`** (verified in round 1; doesn't change).
2. **No new dependencies.** All deps from round 1 cover this round.
3. **Pull-then-pytest gate** before submitting. `git fetch origin main && git
   merge --ff-only origin/main`.
4. **Run pytest on weather-dev.** Both DB backends + both cache backends green
   (642 passed, 24 skipped is the round-1 baseline; this round shouldn't
   change the count materially — F12 changes test internals but not coverage,
   and F17 may add 1-2 wire-shape tests).
5. **Submit closeout immediately after final pytest run.** Don't idle. Lead
   will TaskStop after 3 polling cycles per `rules/clearskies-process.md`.
6. **DCO + co-author trailer:** `git commit -s` plus
   `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`.
7. **Diff budget:** target ~150-300 line impl diff (api-dev). Test-author's
   diff is mostly mechanical attribute-access updates; ~100-200 line delta.
   Smaller than round 1 by an order of magnitude — surgical fixes.

---

## Reporting back

When you're done, report to the lead:

- **Files touched + LOC delta.**
- **F1a, F1b, F2** — confirm specific exception classes used at each site;
  describe the WARNING-vs-ERROR log level choice for F2.
- **F12** — confirm `fetch()` signature now returns `list[AlertRecord]`;
  describe the cache write/read shape (dicts in cache, models out of
  `fetch()`); confirm the `isinstance` defensive branch was removed; describe
  the test attribute-access switch (count of test methods touched).
- **F17** — confirm both `_NwsAlertsActiveResponse.type` and
  `_NwsAlertFeature.type` are now `Literal[...]` with the correct values.
- **Pytest counts** both backends — confirm green; flag any skip-count
  changes.
- **Anything that surprised you** during the remediation.
- **Any deviation from this brief** (and why).
