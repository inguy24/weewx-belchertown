# Phase 2 task 3b round 12 — /aqi/iqair

**Round identity.** Fourth + final AQI provider per [ADR-013](../../decisions/ADR-013-aqi-handling.md). Adds `providers/aqi/iqair.py`. **Closes the AQI domain.** Free-tier Community endpoint (`/v2/nearest_city`); pollutant concentration fields are paid-tier-only (Startup+ plan) with unverified wire path, so CAPABILITY enumerates only the verified free-tier fields. Reuses every existing shared helper — no new `_units.py` additions, no new datetime helper. Smaller surface than 3b-11.

**Pre-brief verifications (3b-7/10/11 lessons applied):**

- **Cross-check rule (5×-validated)**: applied at brief-draft. Three canonical §4.2 cells (`aqiCategory`, `pollutantPM25`, Notes §523) disagreed with the api-docs evidence. All three lead-direct-amended in canonical before brief-draft. Detail:
  - F1: §4.2 `aqiCategory` cell now reads `(derive from aqius via EPA bands)` — was `"data.current.pollution.mainus-derived category"` which was impossible (`mainus` is a pollutant code, not a category).
  - F2: §4.2 `pollutantPM25` cell now reads `— (paid Startup+ tier; wire path unverified)` — was `data.current.pollution.pm25 (µg/m³ — convert if needed)` which doesn't exist on free-tier wire.
  - F3: §523 Notes rewritten to distinguish Community-tier (only AQI + dominant pollutant code, no concentrations) from paid Startup+ tier (adds per-pollutant concentrations, wire field names unverified).
- **Codebase-state verification (3b-10 ext)**: every cited path opened and verified —
  - `_units.py` has `epa_category` (used for `aqiCategory` derivation), `_EPA_CATEGORY_BANDS`. **No new helpers needed** — IQAir publishes EPA AQI directly (no concentration→sub-AQI computation in the IQAir path; `concentration_to_sub_aqi` is unused by this module).
  - `_common/datetime_utils.py` has `to_utc_iso8601_from_offset(s, ...)`. Py 3.11+ `datetime.fromisoformat` accepts the `Z` suffix, so IQAir's `"2019-04-08T18:00:00.000Z"` parses cleanly through this helper. **DRY reuse — no new helper needed** (same pattern Aeris uses).
  - `config/settings.py::AQISettings.validate` at L405 currently accepts `{"openmeteo", "aeris", "openweathermap"}` — must extend with `"iqair"`. Class also has the comment `"Additional providers (iqair) land in 3b-12."` at L410 — remove on completion.
  - `config/settings.py::AQISettings` currently has only `provider` field (no credentials). IQAir is AQI-only (not in forecast/alerts), so credentials live on `AQISettings.iqair_key` directly — see Q1.
  - `endpoints/aqi.py::wire_aqi_settings` has the "When 3b-12 lands IQAir: add elif provider == 'iqair': branch" comment at L183. Extend.
  - `endpoints/aqi.py::get_aqi_current` dispatch (L247–286): add fourth `elif provider_id == "iqair":` branch.
  - `providers/_common/dispatch.py` `PROVIDER_MODULES`: needs `("aqi", "iqair"): aqi_iqair` row + import.
  - `__main__.py::_wire_providers_from_config` valid-providers list update from `"openmeteo, aeris, openweathermap"` to `"openmeteo, aeris, openweathermap, iqair"`.
  - `logging/redaction_filter.py` query-param patterns (`_APPID_RE`, `_CLIENT_ID_RE`, `_CLIENT_SECRET_RE`, `_APIKEY_RE`) — none match a bare `key=`. NEW pattern `_KEY_RE` needed (one-line addition mirroring `_APIKEY_RE`).
- **Numerical sanity check (3b-11 ext)**: brief cites `epa_category(aqi)` for `aqiCategory` derivation. Reference point: IQAir Nashville example `aqius=10` → `epa_category(10)` walks `_EPA_CATEGORY_BANDS`, first band is `(50, "Good")`, returns `"Good"`. ✅ Correct. Brief cites `to_utc_iso8601_from_offset` for `observedAt`. Reference: `to_utc_iso8601_from_offset("2019-04-08T18:00:00.000Z", ...)` → `datetime.fromisoformat` parses Z suffix in Py 3.11+ → tz-aware UTC → `dt.strftime("%Y-%m-%dT%H:%M:%SZ")` → `"2019-04-08T18:00:00Z"` (millis dropped, correct per ADR-020). ✅ Correct.
- **Structural-novelty re-framing**: the resume prompt's "first header-auth keyed provider" framing was wrong — verified against pyairvisual source code (`kwargs["params"]["key"] = self._api_key`) and multiple third-party examples. IQAir v2 uses **query-param `key=` auth**, NOT `X-Key` header. IQAir is the FOURTH keyed query-param provider on the project. The only real structural novelty is the redaction-filter `_KEY_RE` pattern addition (generic-named credential param, accepting LC22 over-redaction risk per existing `_APIKEY_RE` precedent).

---

## Scope (in / out)

**In scope (this round):**

1. `weewx_clearskies_api/providers/aqi/iqair.py` — NEW module (~350–400 lines, smaller than OWM/Aeris since no concentration translation).
2. `weewx_clearskies_api/providers/_common/dispatch.py` — add `("aqi", "iqair")` import + row.
3. `weewx_clearskies_api/config/settings.py` — `AQISettings.validate` accept `"iqair"`; `AQISettings.__init__` reads `WEEWX_CLEARSKIES_IQAIR_KEY` env var into `iqair_key` (see Q1).
4. `weewx_clearskies_api/endpoints/aqi.py` — add module-level `_IQAIR_KEY` + extend `wire_aqi_settings` + extend `get_aqi_current` dispatch.
5. `weewx_clearskies_api/__main__.py` valid-providers list update.
6. `weewx_clearskies_api/logging/redaction_filter.py` — add `_KEY_RE` query-param pattern.
7. Tests covering all of the above (see §Coverage shape).

**Out of scope:**

- `/aqi/history` — still 501 stub per LC21 (3b-9/10/11 carry-forward).
- IQAir paid-tier endpoints (`/v2/nearest_station`, `/v2/city`, `/v2/station`, `/v2/city_ranking`) — v0.1 uses `/v2/nearest_city` only.
- Per-pollutant concentration fields — paid-tier features with unverified wire path; PARTIAL-DOMAIN on free tier, NOT in IQAir's CAPABILITY this round. Future round can lift them after real-capture verification.
- AQI persistence to a writable datastore — deferred per ADR-013 §Out of scope.

---

## Reading list (in order)

1. [CLAUDE.md](../../../CLAUDE.md) — domain routing + always-applicable rules.
2. [rules/clearskies-process.md](../../../rules/clearskies-process.md) — full file. Carry-forwards relevant this round: cross-check rule (5× validated) + codebase-state-verification + numerical-sanity-check (3b-10+11 extensions, applied above); brief-questions-audit-themselves; L1 paid-tier-max-surface + PARTIAL-DOMAIN extension (IQAir has 6 PARTIAL-DOMAIN pollutant fields on free tier — categorical, NOT tier-conditional); "Lead-direct remediation when surface is small"; "Live scratchpad during multi-agent rounds"; "Poll background teammates at every user-prompt boundary"; "Multi-line commit messages on PowerShell: use `git commit -F`"; "Round briefs land in the project, not in tmp."
3. [rules/coding.md](../../../rules/coding.md) — §3 carry-forwards: dispatch on exception state via attributes (not message strings); DRY — search before writing a new helper (3b-12 reuses every existing helper, NO new ones); No dead code.
4. [.claude/agents/clearskies-api-dev.md](../../../.claude/agents/clearskies-api-dev.md) — L2 carry-forward (3b-4): don't re-construct canonical exceptions; bare `client.get()`. The ONLY narrow wrap allowed in this module is LC27 envelope mapping (200-success-false → canonical taxonomy) — intentional + documented in commit body per non-obvious-provenance rule. Plus wire-validation `(ValidationError, ValueError) → ProviderProtocolError` per OWM/Aeris precedent.
5. [.claude/agents/clearskies-test-author.md](../../../.claude/agents/clearskies-test-author.md) — L3 carry-forward: synthetic-from-real fixture pattern when paid-tier access unavailable. **EXPECTED to fire this round**: free-tier `/v2/nearest_city` real-capture works if operator IQAir Community credentials are on weather-dev (probably not — IQAir is new this round). Fallback: L3 synthetic-from-published-example (Nashville example response captured in `docs/reference/api-docs/iqair.md`).
6. [.claude/agents/clearskies-auditor.md](../../../.claude/agents/clearskies-auditor.md) — agent definition.
7. [docs/contracts/canonical-data-model.md](../../contracts/canonical-data-model.md) §3.8 (`AQIReading`) + §4.2 (provider mapping, IQAir column at row 504 — amended pre-brief per F1/F2/F3 above).
8. [docs/contracts/openapi-v1.yaml](../../contracts/openapi-v1.yaml) — `/aqi/current` + `/aqi/history` endpoint shapes (already wired in 3b-9/10/11).
9. [docs/reference/api-docs/iqair.md](../../reference/api-docs/iqair.md) — NEW (created pre-brief). Wire example response, auth (query-param `key=`, NOT header), `mainus`/`maincn` pollutant code lookup, 200-success-false envelope shape, Community-vs-paid tier surface, known gotchas.
10. [docs/decisions/ADR-013-aqi-handling.md](../../decisions/ADR-013-aqi-handling.md) — AQI provider plug-in pattern; this round closes the 4-provider day-1 set.
11. [docs/decisions/ADR-038-data-provider-module-organization.md](../../decisions/ADR-038-data-provider-module-organization.md) — module 5-responsibility pattern.
12. **Precedent modules** (read in this order):
    - [`providers/aqi/aeris.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/aqi/aeris.py) — **closest precedent** (keyed query-param provider; 200-success-false envelope LC27 mapping; `epa_category(aqi)` for `aqiCategory`; pollutant id lookup table similar to `_DOMINANT_TO_CANONICAL`; place-name aqiLocation supplied).
    - [`providers/aqi/openweathermap.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/aqi/openweathermap.py) — keyed query-param precedent for credential plumbing (env var → settings → module-level → fetch kwarg → params dict).

---

## Module spec — `providers/aqi/iqair.py`

### Five responsibilities (per ADR-038 §2)

1. **Outbound API call** — single GET per cache miss:
   ```
   GET https://api.airvisual.com/v2/nearest_city?lat={lat}&lon={lon}&key={key}
   ```
   Query-param `key=` is the API credential (NOT `X-Key` header). Lat/lon rounded to 6 decimal places (consistent with OWM/Aeris precedent). No `units=`/`lang=`/other params.

2. **Response parsing** — wire-shape Pydantic models with `extra="ignore"`:
   - `_IQAirPollution` — `ts: str`, `aqius: int | None = None`, `mainus: str | None = None`, `aqicn: int | None = None`, `maincn: str | None = None`. **No concentration fields declared** (paid-tier unverified; would only add them when real-capture confirms wire shape).
   - `_IQAirWeather` — minimal shell (not consumed by canonical AQIReading; declared so the envelope validates cleanly): `ts: str | None = None`. All other fields `extra="ignore"` drops.
   - `_IQAirCurrent` — `weather: _IQAirWeather | None = None`, `pollution: _IQAirPollution`.
   - `_IQAirData` — `city: str | None = None`, `state: str | None = None`, `country: str | None = None`, `current: _IQAirCurrent`.
   - `_IQAirResponse` — top-level envelope: `status: str`, `data: _IQAirData | None = None`.

3. **Translation to canonical `AQIReading`** (`_wire_to_canonical(data: _IQAirData)`):
   - `aqi` = `data.current.pollution.aqius` (EPA 0–500 directly; **no conversion**, no breakpoint computation, distinct from OWM/Open-Meteo).
   - `aqiCategory` = `epa_category(aqius)` (LC1 — single SOT per LC13 carry-forward; same pattern as Aeris/OWM/Open-Meteo).
   - `aqiMainPollutant` = `_MAINUS_TO_CANONICAL.get(mainus.lower())` if `mainus` present, else `None` (LC2). Unknown codes log + return None (LC3 — mirrors Aeris's `_DOMINANT_TO_CANONICAL` unmappable-id pattern).
   - `aqiLocation` = `f"{data.city}, {data.state}"` with comma+space delimiter per user decision 2026-05-11 (LC4). If either field is missing, `None`.
   - `pollutantPM25/PM10/O3/NO2/SO2/CO` = `None` (LC5 — all PARTIAL-DOMAIN on free tier).
   - `observedAt` = `to_utc_iso8601_from_offset(data.current.pollution.ts, ...)` (LC6 — `Z`-suffixed ISO parses cleanly through the existing helper in Py 3.11+; DRY reuse, no new helper).
   - `source` = `"iqair"`.

4. **Capability declaration** — `CAPABILITY` symbol consumed at startup:
   - `supplied_canonical_fields = ("aqi", "aqiCategory", "aqiMainPollutant", "aqiLocation", "observedAt", "source")` — conservative scope per user decision 2026-05-11 (Q2 answer): enumerate only verified free-tier fields. Pollutant concentration fields stay PARTIAL-DOMAIN (categorical, not tier-conditional). Future round can lift them after paid-tier real-capture (LC7).
   - `auth_required=("key",)` (LC8 — different shape from Aeris's `("client_id", "client_secret")` and OWM's `("appid",)`).
   - `geographic_coverage="global"`, `default_poll_interval_seconds=900` (15 min, same as other AQI providers per ADR-017).
   - `operator_notes` — documents the Community-tier-only categorical PARTIAL-DOMAIN for pollutant concentrations; the lookup-table `mainus` codes; the 200-success-false envelope; and the rate-limit budget (5/min, 500/day, 10000/month free-tier; 15-min TTL → ~96 calls/day well within all caps).

5. **Error handling**:
   - `ProviderHTTPClient.get()` raises canonical taxonomy with all attributes set — L2 carry-forward. **Do NOT re-construct.**
   - LC27 envelope mapping (intentional wrap — wire-level, adds context the HTTP layer doesn't have): `status:"fail"` on a 200 response → dispatch on `data.message` string to KeyInvalid (`incorrect_api_key`, `api_key_expired`, `payment required`, `permission_denied`, `forbidden`, `feature_not_available`) / QuotaExhausted (`call_limit_reached`, `too_many_requests`, `retry_after_seconds=None`) / ProviderProtocolError (everything else including `city_not_found`, `no_nearest_station`, `node not found`). Pattern mirrors Aeris `_raise_for_envelope_error`. Same caveat documented in commit body.
   - Wire-shape validation: `(ValidationError, ValueError) → ProviderProtocolError` at the boundary (mirrors OWM/Aeris precedent — intentional wrap, documented).
   - `key` validation: pre-call empty/None check raises KeyInvalid with provider context (matches OWM `appid` precedent at `openweathermap.py:493-499`).

### Pollutant code lookup

Add `_MAINUS_TO_CANONICAL` to the module:

```python
_MAINUS_TO_CANONICAL: dict[str, str] = {
    "p1": "PM10",
    "p2": "PM2.5",
    "n2": "NO2",
    "o3": "O3",
    "s2": "SO2",
    "co": "CO",
}
```

`p1`/`p2`/`n2` confirmed via published examples; `o3`/`s2`/`co` inferred from naming convention. Real-capture during testing should verify; if any captured response surfaces a code not in this table, add a line + log entry. Per `_DOMINANT_TO_CANONICAL` precedent: unknown codes return `None` for `aqiMainPollutant` with `logger.info` notice (LC3).

### Cache layer (ADR-017 / LC9)

- TTL: 900s (15 min) per ADR-017 AQI domain (same as openmeteo/aeris/openweathermap).
- Key: SHA-256 of `json.dumps({"provider_id":"iqair","endpoint":"aqi_current","params":{"lat4":round(lat,4),"lon4":round(lon,4)}}, sort_keys=True)`.
- `key` (the credential) NOT in cache key per LC7 — privacy/leakage concern. Cache scope is per-location-per-provider, not per-tenant.
- Sentinel `{"_no_reading": True}` for empty-result responses (status=success but pollution data missing/null).
- Reconstruction on hit: `AQIReading.model_validate(cached_dict)`.

### Rate limiter (LC10)

`RateLimiter(name="iqair-aqi", provider_id="iqair", domain="aqi", max_calls=5, window_seconds=60)` — honors IQAir's per-minute Community-tier cap directly. **Stricter than the OWM/Aeris `max_calls=5, window_seconds=1` shape**, because IQAir's per-minute cap is the most restrictive of its three rate limits (5/min, 500/day, 10000/month).

### Auth plumbing

- New env var: `WEEWX_CLEARSKIES_IQAIR_KEY` (LC11). Long-form provider-scoped naming, matching OWM/Wunderground precedent.
- Storage: `AQISettings.iqair_key: str | None` populated in `AQISettings.__init__` from `os.environ.get("WEEWX_CLEARSKIES_IQAIR_KEY", "").strip()` (or `None` if empty). See Q1 for the location rationale.
- Wiring: `endpoints/aqi.py::wire_aqi_settings` extended with `elif provider == "iqair":` branch reading `settings.aqi.iqair_key` into module-level `_IQAIR_KEY`; identical CRITICAL log on missing-creds pattern matching the Aeris and OWM branches.
- Dispatch: `get_aqi_current` extended with fourth `elif provider_id == "iqair":` branch calling `iqair.fetch(lat=..., lon=..., key=_IQAIR_KEY)`.

### Redaction filter extension (`logging/redaction_filter.py`)

Add `_KEY_RE` mirroring `_APIKEY_RE`:

```python
# Match key= query parameter value (IQAir AirVisual API).
# Pattern mirrors _APPID_RE / _APIKEY_RE shape; bare 'key=' is the IQAir
# credential convention.  Fires this round (3b-12) because IQAir is the
# fourth keyed query-param provider on this project.  Over-redaction risk
# (key= is a generic param name) is acceptable per the LC22 / _SQL_LITERAL_RE
# precedent — better to over-redact than leak credentials.
_KEY_RE = re.compile(
    r"((?:^|[?&])key=)[^&\s\n\"']+",
    re.IGNORECASE,
)
```

Add `(_KEY_RE, r"\g<1>" + _REDACTED)` to `_PATTERNS` list.

---

## Lead-calls (LC1–LC14, this round)

| LC | Call | Reasoning |
|---|---|---|
| **LC1** | `aqiCategory` derived via `epa_category(aqius)`, NOT from `mainus` | `mainus` is a pollutant code, not a category. Single SOT pattern per LC13 carry-forward (Aeris/OWM/Open-Meteo all use this). Canonical §4.2 amended pre-brief to match. |
| **LC2** | `aqiMainPollutant` = `_MAINUS_TO_CANONICAL.get(mainus.lower(), None)` | Mirrors Aeris's `_DOMINANT_TO_CANONICAL` exactly. Lookup-table normalization preserves the canonical id schema (`PM2.5`/`PM10`/`O3`/`NO2`/`SO2`/`CO`). |
| **LC3** | Unmappable `mainus` → `None` + `logger.info` notice | Defensive — IQAir may add codes (`p4` etc.) we haven't seen. Matches Aeris's `pm1` handling pattern (LC26 carry-forward). |
| **LC4** | `aqiLocation` = `f"{city}, {state}"` (comma+space) | User decision 2026-05-11. None if either field missing. |
| **LC5** | All `pollutant*` fields = `None` (PARTIAL-DOMAIN on free tier) | Wire evidence: free-tier `pollution` block has no concentration fields. Categorical, not tier-conditional. |
| **LC6** | `observedAt` = `to_utc_iso8601_from_offset(pollution.ts, ...)` | DRY reuse — Py 3.11+ `datetime.fromisoformat` parses `Z` suffix. Numerical sanity verified above. NO new datetime helper. |
| **LC7** | CAPABILITY enumerates ONLY 6 verified free-tier fields | User decision 2026-05-11 (Q2 answer): conservative. Paid-tier wire path unverified; promise only what we can prove. |
| **LC8** | `auth_required=("key",)` | Single credential, query-param. Distinct shape from Aeris pair and OWM appid. |
| **LC9** | Cache key construction: credential NOT in key | Privacy/leakage per LC7 carry-forward. Identical pattern to Aeris/OWM. |
| **LC10** | Rate limiter `max_calls=5, window_seconds=60` | Honors IQAir Community per-minute cap directly. Stricter than OWM/Aeris (per-second). |
| **LC11** | Env var name: `WEEWX_CLEARSKIES_IQAIR_KEY` | Provider-scoped long-form per OWM/Wunderground precedent. |
| **LC12** | LC27 envelope mapping (200-success-false) | Same pattern as Aeris. Wire-level dispatch on `data.message` string (NOT HTTP status — IQAir may return 200+envelope OR HTTP 4xx; LC27 envelope check is defense-in-depth). |
| **LC13** | Pre-call empty/None `key` check → `KeyInvalid` | Fail-fast — same pattern as OWM `openweathermap.py:493-499`. |
| **LC14** | Redaction filter `_KEY_RE` pattern | Over-redaction risk accepted per LC22 / `_SQL_LITERAL_RE` precedent. |

---

## Open questions for user sign-off

### Q1 USER DECIDED 2026-05-11 — IQAir credential location: Option A

`AQISettings.iqair_key` (domain-scoped). Credential lives where it's used. AQISettings currently has only `provider` field; adding `iqair_key` is a small structural extension (~5 lines + validate update). Natural for single-domain providers. NOT a deviation from 3b-4 Q1 "provider-scoped" decision — that decision applied to multi-domain providers (Aeris/OWM serve forecast + alerts + AQI). IQAir is AQI-only.

**Implementation footprint:**
- `AQISettings.iqair_key: str | None` (declared on the class).
- `AQISettings.__init__` reads `WEEWX_CLEARSKIES_IQAIR_KEY` env var (long-form provider-scoped naming per OWM/Wunderground precedent), strips, stores `None` if empty.
- `AQISettings.validate` accepts `"iqair"` in `valid_providers` set.
- `endpoints/aqi.py::wire_aqi_settings` reads `settings.aqi.iqair_key` (NOT `settings.forecast.iqair_key` — distinct from Aeris/OWM wiring path) into module-level `_IQAIR_KEY`.

---

## Coverage shape (test plan)

### Unit tests — `tests/test_providers_aqi_iqair_unit.py`

Mirrors `test_providers_aqi_openweathermap_unit.py` shape:

- **Wire validation**: extra="ignore" drops unknown keys; required fields enforced; envelope `status:"success"` accepted.
- **Translation** (`_wire_to_canonical`):
  - Nashville example (from api-docs): aqi=10, mainus=p2 → aqi=10, aqiCategory="Good", aqiMainPollutant="PM2.5", aqiLocation="Nashville, Tennessee", observedAt="2019-04-08T18:00:00Z", all pollutant* = None.
  - All-null pollution block → returns None.
  - Missing city OR state → aqiLocation = None.
  - Each `mainus` code in lookup table → correct canonical id.
  - Unknown `mainus` code → aqiMainPollutant = None + logger.info.
- **Envelope error mapping** (LC27, mirrors Aeris):
  - status=fail + message="incorrect_api_key" → KeyInvalid.
  - status=fail + message="call_limit_reached" → QuotaExhausted(retry_after_seconds=None).
  - status=fail + message="city_not_found" → ProviderProtocolError.
  - Each known error string mapped correctly.
- **Empty/None `key` pre-call check** → KeyInvalid before HTTP.
- **Cache hit/miss/sentinel**: 3-way path coverage with `clearskies_cache_url=memory://` (test default).
- **Cache key**: credentials NOT in key; lat/lon rounded to 4 decimals; deterministic across runs.
- **Rate limiter**: 6th call within 60s window blocks (or raises per RateLimiter contract).

### Integration tests — `tests/test_providers_aqi_iqair_integration.py`

- **Real-capture path** (skip if no `WEEWX_CLEARSKIES_IQAIR_KEY` env var): live call to `/v2/nearest_city` for Belchertown station coords; capture fixture to `tests/fixtures/iqair_nearest_city_real.json`; verify translation produces expected AQIReading shape; verify CAPABILITY supplied_canonical_fields enumerates only free-tier fields.
- **L3 synthetic-from-published-example fallback** (if real-capture skips): use the Nashville example response from `docs/reference/api-docs/iqair.md` as the fixture; sidecar marks `mode: synthetic-from-published-example` per L3 carry-forward.
- **End-to-end /aqi/current dispatch**: configure `[aqi] provider = iqair` + set `WEEWX_CLEARSKIES_IQAIR_KEY` env var → FastAPI TestClient call to `/aqi/current` → 200 + AQIReading body matching the captured fixture.
- **MariaDB + Redis isolation per 3b-11 carry-forward** (Aeris isolation fix `73c882c`): `setup_method` flushes Redis at the start AND any error-path; cache-miss verification inline before each assertion. Mirrors `test_providers_aqi_aeris_integration.py` post-3b-11-fix structure.

### Redaction filter test — `tests/test_logging_redaction.py`

Extend with one new case:

- `f"GET /v2/nearest_city?lat=1&lon=2&key=SECRET_VALUE_xyz"` → `f"GET /v2/nearest_city?lat=1&lon=2&key=[REDACTED]"` (no leak of `SECRET_VALUE_xyz`).
- Verify the existing `_APPID_RE` / `_APIKEY_RE` / etc. cases still pass (no pattern regression).

### Settings test — `tests/test_config_settings.py`

- `AQISettings(provider="iqair")` validates without raising.
- `AQISettings(provider="iqair").iqair_key` populated from `WEEWX_CLEARSKIES_IQAIR_KEY` env var.
- Missing env var → `iqair_key=None`.
- `AQISettings(provider="iqair").validate()` accepts; current validation error message updates to reflect 4-provider set.

### Pytest baseline expectations

- AQI domain isolated: was 361/21/0 at 3b-11 close; 3b-12 adds ~30–40 new tests → expect ~395–405 passed / ~21 skipped / 0 failed.
- Full project pytest (default+integration on weather-dev): no regression.

---

## Process gates (carry-forwards)

- **No feature branches.** Commit straight to `main` (api) / `master` (meta). DCO + Co-Authored-By trailer on every commit.
- **Commit early and often.** Each agent commits incrementally — wire model + translation + fetch + cache + tests as separate commits is better than one big drop. Easier audit + easier mid-flight pivots.
- **Mid-flight SendMessage cadence (4-min floor).** No silent runs > 4 min between commits OR SendMessage updates.
- **"No >5 min in pure file-reading without a SendMessage" research-mode mitigation** for the initial reading-list pass.
- **L2 — don't re-construct canonical exceptions.** Bare `client.get()`. The ONLY narrow wraps in the IQAir module are LC12 (LC27 envelope mapping) and wire-shape validation `(ValidationError, ValueError) → ProviderProtocolError` — both intentional and documented in commit bodies.
- **L3 synthetic-from-published-example fixture pattern** applies if no operator IQAir Community key is available on weather-dev.
- **L1 paid-tier-max-surface + PARTIAL-DOMAIN extension** applies — but the user's Q2 decision (conservative CAPABILITY) overrides the maximalist default for this round. Operator notes document the rationale.
- **PowerShell multi-line commit messages** use `git commit -F c:\tmp\3b-12-msg-<n>.txt`.
- **Live scratchpad** at `c:\tmp\3b-12-scratch.md` maintained by the lead throughout the round.
- **weather-dev runtime** for pytest; DILBERT edit-only.
- **Brief errors propagate** — if any agent finds a brief-vs-codebase mismatch mid-round, STOP and SendMessage the lead. Don't silently work around it (3b-10/11 lesson — the brief is the contract).

---

## Auditor spawn — addressability gap continues (SEVENTH round)

Per 3b-5 through 3b-11 cumulative experience: auditor's `team-lead` / `opus` / `lead` recipient names are unreliable on Windows in-process agent-teams mode. The auditor spawn prompt MUST explicitly enumerate the recipient fallback chain (`lead` → `team-lead` → `opus` → accumulate-to-closeout). Harness limitation per issues #24108 / #56930 — not fixable at the rule layer. The lead-direct remediation path absorbs 1-3 finding loads cleanly per recent precedent.

---

## Round-close commit message structure

Round-close meta-repo commit on `master`:

```
3b-12 close: AQI IQAir — fourth + final AQI provider; closes AQI domain
+ canonical §4.2 cross-check rule 5th validation (3 amendments lead-direct pre-brief)
+ redaction filter _KEY_RE extension (first generic-named credential param on the project)
+ N audit findings lead-direct (if applicable)
+ N rule extensions (if applicable per user direction "fold into existing rules where possible")
```

Plan-status meta-repo commit (separate): mark 3b-12 closed; queue 3b-13 (earthquakes domain opener per ADR-040 — usgs/geonet/emsc/renass).
