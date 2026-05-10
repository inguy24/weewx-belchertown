# Phase 2 task 3b-9 — /aqi/* infrastructure + Open-Meteo provider

**Round identity:** 3b-9 is the first round of the AQI series. 3b-8 (2026-05-10) closed the alerts domain with the third + final day-1 alerts provider (OpenWeatherMap). 3b-9 opens the AQI domain analogous to how 3b-1 opened alerts: shared `providers/aqi/` infrastructure lands alongside the first AQI provider (Open-Meteo), and remaining day-1 providers (Aeris, OpenWeatherMap, IQAir) queue for 3b-10 / 3b-11 / 3b-12 per ADR-013.

**Scope sizing:** The shared `providers/_common/` infrastructure (HTTP client, cache abstraction, rate limiter, capability registry, dispatcher, errors taxonomy) was built in 3b-1 and has been carry-forwarded through six alerts and forecast rounds. 3b-9 does NOT re-build any of that. The genuinely new work for 3b-9 is:

1. A new `providers/aqi/_units.py` helper carrying two static tables (µg/m³→ppm conversion factors + EPA AQI breakpoint bands).
2. A new `providers/aqi/openmeteo.py` provider module modeled on `providers/alerts/openweathermap.py` (3b-8) — capability declaration, wire-shape Pydantic models, fetch entrypoint, translation to canonical AQIReading.
3. A new `endpoints/aqi.py` mirroring `endpoints/alerts.py`'s dispatch structure, with two routes: `GET /aqi/current` (full) and `GET /aqi/history` (501 Not Implemented stub).
4. Settings + wiring extensions in `config/settings.py` and `__main__.py` for an `[aqi]` config section.

## User decisions baked into this brief (2026-05-10)

**Q1 — First provider:** **Open-Meteo.** Keyless. Mirrors 3b-1 NWS / 3a-2 OpenMeteo precedent of landing shared infrastructure with the simplest provider. Open-Meteo pre-computes `current.us_aqi` and per-pollutant sub-AQIs (`us_aqi_pm2_5`, `us_aqi_pm10`, `us_aqi_nitrogen_dioxide`, `us_aqi_ozone`, `us_aqi_sulphur_dioxide`, `us_aqi_carbon_monoxide`); the EPA 1-5→0-500 conversion logic (which OWM needs) lands in 3b-11 when OWM AQI lands. The EPA-category-band table and µg/m³→ppm table land in 3b-9 since both are needed by Open-Meteo's translation.

**Q2 — /aqi/history scope:** **Defer.** 3b-9 wires the route at `endpoints/aqi.py` returning `501 Not Implemented` with RFC 9457 `application/problem+json` body. Persistent AQI store (writeable datastore separate from the read-only weewx archive per ADR-013) is a separate architecture decision that deserves its own round — queued for 3b-10+ explicitly.

**Q3 — Canonical §4.2 NO2/SO2 conversion-annotation amendment (USER DECIDED 2026-05-10 — Lead-direct amend):** The §4.2 footnote covers µg/m³→ppm for O3/NO2/SO2/CO; the openmeteo and openweathermap **cells** annotated the conversion on O3 + CO but NOT on NO2 + SO2. Single-line per-cell amendments. **APPLIED before teammate spawn:** four cells (openmeteo NO2, openmeteo SO2, OWM NO2, OWM SO2) now read `(µg/m³ — convert to ppm)` matching the O3 + CO cells. No impl impact (footnote is authoritative); impl reads `_units.ugm3_to_ppm` regardless. Committed lead-direct on meta repo before teammates spawn.

## Cross-check rule findings (canonical §4.2 vs api-docs)

Applied per `rules/clearskies-process.md` "Cross-check canonical mapping cells against api-docs example responses at brief-draft." Verified each cell in §4.2 openmeteo column against `docs/reference/api-docs/openmeteo.md` (extended in this brief-draft session to include the `### Air Quality` subsection, source verified 2026-05-10).

| Canonical | §4.2 says | api-docs example | Match? |
|---|---|---|---|
| `aqi` | `current.us_aqi` | `current.us_aqi`: 42 | ✓ |
| `aqiCategory` | derive from us_aqi via EPA bands | (no provider field; derive client-side) | ✓ |
| `aqiMainPollutant` | derive from highest sub-AQI | `current.us_aqi_pm2_5` etc. exist on current= (note in api-docs) | ✓ |
| `aqiLocation` | — | (no provider field) | ✓ PARTIAL-DOMAIN |
| `pollutantPM25` | `current.pm2_5` (µg/m³) | `current.pm2_5`: 9.1, units μg/m³ | ✓ |
| `pollutantPM10` | `current.pm10` (µg/m³) | `current.pm10`: 12.4, units μg/m³ | ✓ |
| `pollutantO3` | `current.ozone` (µg/m³ — convert to ppm) | `current.ozone`: 84.3, units μg/m³ | ✓ |
| `pollutantNO2` | `current.nitrogen_dioxide` (µg/m³) — **no convert annotation in cell** | `current.nitrogen_dioxide`: 14.2, units μg/m³ | F-C1 |
| `pollutantSO2` | `current.sulphur_dioxide` (µg/m³) — **no convert annotation in cell** | `current.sulphur_dioxide`: 0.4, units μg/m³ | F-C1 |
| `pollutantCO` | `current.carbon_monoxide` (µg/m³ — convert to ppm) | `current.carbon_monoxide`: 130.0, units μg/m³ | ✓ |
| `observedAt` | `current.time` | `current.time`: "2026-05-10T18:00" | ✓ (note: local-naive, see §LC4) |

**F-C1:** Cell-vs-footnote inconsistency described in Q3 above; footnote covers conversion for all four (O3/NO2/SO2/CO); cell annotations missing on NO2 + SO2 across both openmeteo and OWM columns. Proposed amendment in this brief's Q3.

## Lead+user-confirmed calls (resolved before spawn)

Per `rules/clearskies-process.md` "Brief questions audit themselves before draft" — non-judgment-call items are lead-resolved inline and listed here for traceability. Items that would have been numbered questions in earlier briefs but are settled by ADR / contract / precedent appear in this section with the citation.

**LC1 — Module location.** New AQI provider modules live at `weewx_clearskies_api/providers/aqi/{provider}.py` per ADR-038 §2 + ADR-013 §Decision.

**LC2 — Endpoint module location.** `weewx_clearskies_api/endpoints/aqi.py` (mirror of `endpoints/alerts.py` and `endpoints/forecast.py`). Single module, two routes (`/aqi/current` + `/aqi/history`-501-stub).

**LC3 — Cache TTL.** **900s (15 min)** per ADR-017's per-domain TTL table ("AQI current reading | 15 min"). Operator-overridable per ADR-038 §4. Module-level constant `DEFAULT_AQI_TTL_SECONDS = 900`.

**LC4 — `observedAt` time-zone normalization.** Open-Meteo returns `current.time` as `YYYY-MM-DDTHH:mm` (local-naive, in the timezone selected via `?timezone=` — defaults to GMT). When the module fetches with `timezone=GMT` (the lead's call — fixed, not operator-configurable for v0.1), the timestamp is GMT-naive; the module appends `Z` and parses as UTC for canonical `observedAt`. Rationale: AQI is a current-snapshot value, not a forecast bundle; the local-vs-UTC ambiguity collapses if we always fetch in GMT. ADR-020-compliant. (Mirror of 3b-2 forecast/openmeteo's UTC-fetch precedent.)

**LC5 — Wire-model `extra="ignore"`.** Open-Meteo response carries fields we don't consume (`elevation`, `generationtime_ms`, `utc_offset_seconds`, `timezone`, `timezone_abbreviation`, `current_units`, `interval`). `model_config = ConfigDict(extra="ignore")` on the wire models per the 3b-8 OWM alerts precedent. Required fields enumerated on the model raise `ValidationError` if missing → translated to `ProviderProtocolError` at the fetch boundary (canonical exception taxonomy per ADR-038 §5).

**LC6 — Cache value shape.** Cache stores `dict` (post-`model_dump()`), not the Pydantic model. Reconstruction on cache-hit via `AQIReading.model_validate(cached_dict)`. JSON-serializable for Redis backend per ADR-017. Single-entry cache (one AQI reading per station), not a list (one cache key per station per provider, not per-timestamp).

**LC7 — Cache key construction.** Deterministic SHA-256 hash of `{"provider_id", "endpoint": "aqi_current", "params": {"lat4", "lon4"}}` per ADR-017 §Cache key. Lat/lon rounded to 4 decimal places. No target_unit dimension (AQI has no unit conversion at request time — pollutant unit conversion happens inside the module, not at the API surface).

**LC8 — Rate limiter.** Per-module RateLimiter from `providers/_common/rate_limiter.py`. `max_calls=5, window_seconds=1` ("be polite" guard; 15-min cache TTL means ~96 calls/day per station — well under any plausible quota). Mirror of 3b-8 OWM alerts rate-limit.

**LC9 — Capability registration.** `providers/aqi/openmeteo.CAPABILITY` is a `ProviderCapability` from `providers/_common/capability.py`. Registered at startup by `_wire_providers_from_config()` in `__main__.py` reading the `[aqi]` config section's `provider = openmeteo` key.

**LC10 — Geographic coverage.** `geographic_coverage="global"` (Open-Meteo's CAMS data is worldwide; pollen subset is Europe-only but pollen isn't in canonical AQI surface).

**LC11 — `auth_required` tuple.** `auth_required=()` (empty tuple — keyless provider). Mirror of `providers/forecast/openmeteo.py`.

**LC12 — `supplied_canonical_fields`.** Eleven of the twelve canonical AQIReading fields (full max-surface for Open-Meteo):
  - `aqi` (from `current.us_aqi`)
  - `aqiCategory` (derived from `current.us_aqi` via EPA bands)
  - `aqiMainPollutant` (derived from max of per-pollutant sub-AQIs)
  - `pollutantPM25`, `pollutantPM10`, `pollutantO3`, `pollutantNO2`, `pollutantSO2`, `pollutantCO`
  - `observedAt`, `source`
  - **NOT supplied:** `aqiLocation` (PARTIAL-DOMAIN — Open-Meteo has no location label field; populates as `None` on canonical bundle).

**LC13 — `aqiCategory` derivation table.** Standard EPA breakpoints:

| AQI range | Category |
|---|---|
| 0–50 | `Good` |
| 51–100 | `Moderate` |
| 101–150 | `Unhealthy for Sensitive Groups` |
| 151–200 | `Unhealthy` |
| 201–300 | `Very Unhealthy` |
| 301–500 | `Hazardous` |

Implementation: bisect-by-upper-bound; `None` AQI → `None` category. Table lives in `providers/aqi/_units.py`. Spelling matches canonical §3.8 exactly.

**LC14 — `aqiMainPollutant` derivation.** `argmax` of `(us_aqi_pm2_5, us_aqi_pm10, us_aqi_nitrogen_dioxide, us_aqi_ozone, us_aqi_sulphur_dioxide, us_aqi_carbon_monoxide)`; map to canonical pollutant id table:

| Open-Meteo sub-AQI key | Canonical pollutant id (§3.8) |
|---|---|
| `us_aqi_pm2_5` | `PM2.5` |
| `us_aqi_pm10` | `PM10` |
| `us_aqi_nitrogen_dioxide` | `NO2` |
| `us_aqi_ozone` | `O3` |
| `us_aqi_sulphur_dioxide` | `SO2` |
| `us_aqi_carbon_monoxide` | `CO` |

Ties broken by table order above (PM2.5 wins a tie with PM10; arbitrary but deterministic). Missing per-pollutant sub-AQI fields (any None) excluded from the argmax — if ALL six are None, `aqiMainPollutant = None`.

**LC15 — `pollutantO3` and `pollutantCO` µg/m³ → ppm conversion.** Per canonical §4.2 footnote: `ppm = µg/m³ × 24.45 / molecular_weight`. Molecular weights table in `_units.py`:

| Pollutant | MW (g/mol) |
|---|---|
| O3 | 48.00 |
| NO2 | 46.01 |
| SO2 | 64.07 |
| CO | 28.01 |

Applies to NO2 + SO2 also (per Q3 amendment surfaced for user sign-off). Particulates `pollutantPM25` + `pollutantPM10` stay in µg/m³ (canonical §3.8 group_concentration).

**LC16 — `source` literal.** `source = "openmeteo"` (provider_id literal). On canonical `AQIReading` and on the `AQIResponse.source` envelope field. Mirror of every other provider module.

**LC17 — Settings section.** New `[aqi]` section in `config/settings.py` Pydantic model:

```python
class AQISettings(BaseModel):
    model_config = ConfigDict(extra="forbid")
    provider: str | None = None    # currently only "openmeteo" valid; future: aeris/owm/iqair
    # No openmeteo_apikey field — Open-Meteo is keyless.
    # When 3b-10 lands Aeris AQI: add aeris_client_id + aeris_client_secret fields.
    # When 3b-11 lands OWM AQI: add openweathermap_appid field (or reuse alerts.openweathermap_appid via lookup; lead's call at 3b-11).
```

Mirror of `[alerts]` section's shape. `[aqi]` is the operator's *single* AQI provider choice per ADR-013 ("operator picks an AQI provider in clearskies-api setup"). No multi-provider fallback for v0.1.

**LC18 — Wiring entry point.** `wire_aqi_settings(settings)` in `endpoints/aqi.py` mirrors `wire_alerts_settings()` shape. For Open-Meteo (keyless), wiring is a no-op except for capability-registry registration via the startup `_wire_providers_from_config()` path.

**LC19 — Endpoint behavior when no provider configured.** `GET /aqi/current` returns `200` with `data: null`, `source: "none"`, `units` block, `generatedAt`. Mirror of `/alerts` (returns empty alerts list + source="none" when no alerts provider configured). Per OpenAPI `AQIResponse.data` schema `oneOf: [AQIReading, null]` — `null` is a valid response. No 404 / 503 when AQI is unconfigured — operator absence ≠ service unhealthy.

**LC20 — Endpoint behavior on provider error.** Same error envelope as `/alerts`:

| Provider exception | HTTP | Body |
|---|---|---|
| `TransientNetworkError` | 502 | RFC 9457 problem+json, `type=provider-error` |
| `QuotaExhausted` | 503 + `Retry-After` header | RFC 9457, `type=provider-unavailable` |
| `KeyInvalid` | 502 | RFC 9457, `type=provider-error` |
| `ProviderProtocolError` | 502 | RFC 9457, `type=provider-error` |

Open-Meteo is keyless so `KeyInvalid` won't trigger in normal operation, but the canonical exception path still applies (no-key-provided check at `fetch()` entry would be a no-op for Open-Meteo).

**LC21 — `/aqi/history` 501 body.** RFC 9457 problem+json:

```json
{
  "type": "https://example.com/probs/not-implemented",
  "title": "Not Implemented",
  "status": 501,
  "detail": "AQI history persistence is not yet implemented. Tracked for a future release.",
  "instance": "/aqi/history"
}
```

OpenAPI default `Problem` response covers this — no schema change. Endpoint always returns 501 regardless of provider config. Test asserts shape.

**LC22 — Test fixture scope.** One real captured fixture (the response to `GET /v1/air-quality` with the full `current=` projection) is required. Captured live from `air-quality-api.open-meteo.com` (no key, no rate-limit gate). Sidecar `.md` documents capture date + coordinates + response sha256.

**LC23 — Settings env-var mapping.** No env vars for `[aqi]` section in 3b-9 (keyless provider). When 3b-10/3b-11/3b-12 lands keyed providers, they'll add env-var-to-config mappings following the established pattern (`WEEWX_CLEARSKIES_OPENWEATHERMAP_APPID` precedent from 3b-5/3b-8).

**LC24 — Logging surface.** Same convention as 3b-8: `logger.debug` for cache hits/misses; `logger.info` for "AQI fetched: aqi=X mainPollutant=Y"; `logger.error` for wire-validation failures with the first 2000 chars of the response body. No `logger.warning` planned (Open-Meteo has no tier-conditional fields to warn about).

**LC25 — Module docstring "Five responsibilities".** Following the 3b-8 OWM alerts precedent: module-level docstring enumerates the ADR-038 §2 five responsibilities (outbound API call / response parsing / translation / capability declaration / error handling).

## Hard reading list (once per session)

api-dev + test-author each read these before writing any code:

1. **`docs/decisions/ADR-013-aqi-handling.md`** — AQI architecture decision (full file).
2. **`docs/decisions/ADR-017-provider-response-caching.md`** — Cache TTL + backend (full file).
3. **`docs/decisions/ADR-038-data-provider-module-organization.md`** — five-responsibility module pattern (full file).
4. **`docs/decisions/ADR-018-api-versioning-policy.md`** — RFC 9457 error response shape (full file).
5. **`docs/decisions/ADR-020-time-zone-handling.md`** — UTC at API boundary, IANA at config (full file).
6. **`docs/contracts/canonical-data-model.md`** §3.8 (AQIReading) and §4.2 (AQI providers) and §5 (Pydantic config). Section 4.2 with Q3 amendment applied.
7. **`docs/contracts/openapi-v1.yaml`** `/aqi/current` + `/aqi/history` + `AQIResponse` + `AQIHistoryResponse` + `AQIReading` schemas.
8. **`docs/reference/api-docs/openmeteo.md`** — full file; pay particular attention to the `### Air Quality` subsection (extended at brief-draft time 2026-05-10).
9. **`rules/coding.md`** — full file. §3 carry-forwards still apply (dispatch on attributes / DRY / no dead code).
10. **`rules/clearskies-process.md`** — full file. The "Provider CAPABILITY declares paid-tier maximum supply set" rule does NOT fire here (Open-Meteo is keyless, no tier conditional). The "Real schemas in unit tests where the schema shape matters" rule does NOT fire here (no DB-schema dependency).

### Reference impls (read before writing — do NOT rewrite)

11. **`weewx_clearskies_api/providers/alerts/openweathermap.py`** — closest structural precedent. 3b-8 module. The 3b-9 `providers/aqi/openmeteo.py` should track this file's overall shape (module-level constants, capability declaration, wire-shape Pydantic models, rate limiter, cache-key construction, fetch entrypoint, translation helper, test reset helpers). Differences below in §"Per-module specs."
12. **`weewx_clearskies_api/providers/forecast/openmeteo.py`** — Open-Meteo precedent for keyless wiring. Read to confirm `auth_required=()` shape and no-key code paths.
13. **`weewx_clearskies_api/endpoints/alerts.py`** — closest endpoint precedent. 3b-9 `endpoints/aqi.py` should track this file's dispatch pattern (registry lookup, station info, provider-id branch, response envelope construction).
14. **`weewx_clearskies_api/providers/_common/`** — full directory. DO NOT rewrite or modify any file here.

## Existing code (do not rewrite)

Treat the following as locked infrastructure built in prior rounds:

- `providers/_common/cache.py` — cache abstraction; `get_cache()` returns a `MemoryCacheBackend` or `RedisCacheBackend` based on `CLEARSKIES_CACHE_URL` env var.
- `providers/_common/capability.py` — `ProviderCapability` dataclass + `get_provider_registry()` + `wire_providers(list_of_capabilities)`.
- `providers/_common/datetime_utils.py` — `epoch_to_utc_iso8601()` (used by Aeris + OWM modules). For Open-Meteo we'll use a different helper since the wire is ISO-like local-naive (see "Per-module specs"); leave `datetime_utils.py` unmodified.
- `providers/_common/dispatch.py` — module-by-id dispatcher (used by endpoints).
- `providers/_common/errors.py` — canonical exception taxonomy: `KeyInvalid`, `QuotaExhausted`, `TransientNetworkError`, `ProviderProtocolError`, `ProviderError`. Each carries `status_code`, `retry_after_seconds` attributes per the 3b-4 F1 rule.
- `providers/_common/http.py` — `ProviderHTTPClient` wraps `httpx` and raises the canonical taxonomy. **L2 carry-forward (3b-4):** `client.get()` raises members of the canonical taxonomy with all attributes set. Do NOT re-construct.
- `providers/_common/rate_limiter.py` — `RateLimiter(name, provider_id, domain, max_calls, window_seconds)`.
- `errors.py` (top-level) — RFC 9457 problem+json response shape.
- `endpoints/alerts.py` — reference dispatch pattern; do NOT modify.

If you find yourself wanting to modify any of the above files, STOP and message the lead — it's almost certainly a brief gap, not a real refactor.

## Per-endpoint spec

### `GET /aqi/current` — current AQI reading

**Behavior decision tree:**

1. No AQI provider in capability registry → `200` with `data: null, source: "none"`.
2. Provider configured, fetch succeeds with valid AQI → `200` with canonical `AQIReading` in `data`.
3. Provider configured, fetch succeeds but `current.us_aqi` is null (provider returned a null) → `200` with canonical AQIReading and `aqi: null`, `aqiCategory: null`, `aqiMainPollutant: null`; per-pollutant fields populate per the wire (some may be null).
4. Network failure / 5xx after retries → `502` (`TransientNetworkError` → RFC 9457).
5. Provider returns 429 → `503 + Retry-After` (`QuotaExhausted`).
6. Provider returns 401/403 → `502` (`KeyInvalid`) — not expected for keyless Open-Meteo.
7. Pydantic validation failure on wire model (missing required field) → `502` (`ProviderProtocolError`).

**Query params:** none. `extra="forbid"` on the empty Pydantic params model; unknown query keys → 422 via the standard `Depends(_get_aqi_params)` wrapper.

**No DB hit.** AQI comes from the provider, not the weewx archive (Path B only; Path A — operator's own AQI extension — is a separate code path that lands in a future round once Path A's column-mapping flow lands per ADR-035).

**Operator lat/lon:** `get_station_info()` (single-station per ADR-011).

**Response envelope:**

```json
{
  "data": { ...AQIReading...} | null,
  "units": { ...UnitsBlock... },
  "source": "openmeteo" | "none",
  "generatedAt": "2026-05-10T18:00:00Z"
}
```

`units` field: For 3b-9, populate with the same `UnitsBlock` shape used by `/forecast` and `/alerts`. AQI is a unit-bearing canonical (pollutants are µg/m³ + ppm); the units block declares which group each pollutant belongs to. Lead-call: import-and-reuse the `_default_units_block()` helper from `endpoints/forecast.py` rather than duplicate. If that helper doesn't exist as a shared utility, do NOT create one — replicate the inline construction in `endpoints/aqi.py` and flag for DRY-extraction in a follow-up.

### `GET /aqi/history` — 501 stub

Returns `501` with RFC 9457 problem+json (LC21 body) regardless of provider config. Single test asserts the shape + status code + content-type. Routed in `endpoints/aqi.py` for future expansion.

## Per-module specs

### Module 1: `providers/aqi/__init__.py` — empty package marker

Empty file (or just a `__future__` import + module docstring). Mirror of `providers/alerts/__init__.py` and `providers/forecast/__init__.py`. **Do not** add re-exports here.

### Module 2: `providers/aqi/_units.py` — pollutant unit conversion + EPA AQI bands

NEW module. Two static tables + two pure-function helpers. No I/O, no state.

```python
"""µg/m³ → ppm gas conversion + EPA AQI category band table.

Conversion formula per canonical-data-model §4.2 footnote:
    ppm = µg/m³ × 24.45 / molecular_weight
where 24.45 L/mol is the molar volume of an ideal gas at 25°C and 1 atm.

EPA AQI category breakpoints per canonical-data-model §3.8 (canonical):
    0-50      → Good
    51-100    → Moderate
    101-150   → Unhealthy for Sensitive Groups
    151-200   → Unhealthy
    201-300   → Very Unhealthy
    301-500   → Hazardous

Tables are static; molecular weights and EPA bands are constants of nature
+ EPA regulation respectively (not provider-specific).
"""

# Molar volume at 25°C / 1 atm.  Used by µg/m³ → ppm conversion.
_MOLAR_VOLUME = 24.45  # L/mol

# Molecular weights for the four gases canonical stores in ppm (group_fraction).
# Particulates (PM2.5, PM10) stay in µg/m³ (group_concentration) — no conversion.
_MOLECULAR_WEIGHTS_G_PER_MOL: dict[str, float] = {
    "O3":  48.00,
    "NO2": 46.01,
    "SO2": 64.07,
    "CO":  28.01,
}

def ugm3_to_ppm(ugm3: float | None, *, pollutant: str) -> float | None:
    """Convert µg/m³ concentration to ppm for the given gas.

    Args:
        ugm3: concentration in µg/m³ (or None).
        pollutant: canonical pollutant id ("O3", "NO2", "SO2", "CO").
    Returns:
        ppm value (None propagates).
    Raises:
        KeyError: if pollutant is not in the conversion table.
    """
    if ugm3 is None:
        return None
    mw = _MOLECULAR_WEIGHTS_G_PER_MOL[pollutant]
    return ugm3 * _MOLAR_VOLUME / mw

# EPA AQI category breakpoints (upper bounds, inclusive).
# Bisect-by-upper-bound dispatch: aqi value <= upper → that category.
# Order matters — list MUST be sorted by upper bound ascending.
_EPA_CATEGORY_BANDS: list[tuple[int, str]] = [
    ( 50, "Good"),
    (100, "Moderate"),
    (150, "Unhealthy for Sensitive Groups"),
    (200, "Unhealthy"),
    (300, "Very Unhealthy"),
    (500, "Hazardous"),
]

def epa_category(aqi: int | float | None) -> str | None:
    """Map a 0–500 EPA AQI value to its category name.

    Args:
        aqi: AQI value (or None).
    Returns:
        EPA category name (canonical spelling per canonical §3.8) or None.
        Values > 500 fall into "Hazardous" (max band) for safety.
    """
    if aqi is None:
        return None
    for upper, name in _EPA_CATEGORY_BANDS:
        if aqi <= upper:
            return name
    # Above 500 — cap at "Hazardous" (top band) rather than raising. Spec is
    # 0-500 but provider-side bugs producing 501+ shouldn't crash us.
    return "Hazardous"
```

**Tests for `_units.py`:** pure-compute unit tests in `tests/providers/aqi/test_units.py`:
- `ugm3_to_ppm` round-trips: known values like `O3 = 100 µg/m³ → 0.0509 ppm` (cross-check against a published source like EPA's Method 200.8 reference).
- `ugm3_to_ppm` with `ugm3=None` returns `None`.
- `ugm3_to_ppm` with unknown pollutant raises `KeyError`.
- `epa_category` for boundary values (0, 50, 51, 100, 101, 150, 151, 200, 201, 300, 301, 500, 501).
- `epa_category(None)` returns `None`.

### Module 3: `providers/aqi/openmeteo.py` — first AQI provider

Closest structural precedent: `providers/alerts/openweathermap.py` (3b-8). Differences in approximate order of importance:

**Endpoint:**
- Base URL: `https://air-quality-api.open-meteo.com` (NOTE: distinct host from `api.open-meteo.com` used by the forecast module).
- Path: `/v1/air-quality`
- Method: GET
- Query params: `latitude`, `longitude`, `current=us_aqi,us_aqi_pm2_5,us_aqi_pm10,us_aqi_nitrogen_dioxide,us_aqi_ozone,us_aqi_sulphur_dioxide,us_aqi_carbon_monoxide,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone` (fixed CSV; hardcoded module-level constant), `timezone=GMT` (fixed per LC4).

**Module-level constants:**
- `PROVIDER_ID = "openmeteo"`
- `DOMAIN = "aqi"`
- `DEFAULT_AQI_TTL_SECONDS = 900` (per LC3 / ADR-017)
- `_API_VERSION = "0.1.0"`
- `OPENMETEO_AQ_BASE_URL = "https://air-quality-api.open-meteo.com"`
- `OPENMETEO_AQ_PATH = "/v1/air-quality"`
- `_REQUESTED_CURRENT_VARS = "us_aqi,us_aqi_pm2_5,us_aqi_pm10,us_aqi_nitrogen_dioxide,us_aqi_ozone,us_aqi_sulphur_dioxide,us_aqi_carbon_monoxide,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone"`

**Capability declaration:**

```python
CAPABILITY = ProviderCapability(
    provider_id=PROVIDER_ID,
    domain=DOMAIN,
    supplied_canonical_fields=(
        "aqi", "aqiCategory", "aqiMainPollutant",
        "pollutantPM25", "pollutantPM10",
        "pollutantO3", "pollutantNO2", "pollutantSO2", "pollutantCO",
        "observedAt", "source",
        # aqiLocation is PARTIAL-DOMAIN — Open-Meteo has no location field.
    ),
    geographic_coverage="global",
    auth_required=(),  # keyless
    default_poll_interval_seconds=DEFAULT_AQI_TTL_SECONDS,
    operator_notes=(
        "Open-Meteo air-quality endpoint. Keyless, no quota gate. "
        "Source data is CAMS European Air Quality Forecast (Europe) + CAMS "
        "Global Atmospheric Composition (rest of world). "
        "aqiLocation is not supplied by this provider (PARTIAL-DOMAIN per "
        "canonical §4.2 openmeteo column); always null on canonical bundle. "
        "aqiCategory + aqiMainPollutant are derived client-side from us_aqi "
        "and per-pollutant sub-AQIs respectively (provider does not supply "
        "either field directly). Per-gas concentrations converted µg/m³→ppm "
        "via providers/aqi/_units.py."
    ),
)
```

**Wire-shape Pydantic models:**

```python
class _OpenMeteoCurrentBlock(BaseModel):
    """current= block of the air-quality response."""
    model_config = ConfigDict(extra="ignore")

    time: str  # local-naive ISO ("YYYY-MM-DDTHH:mm") — see LC4
    us_aqi: float | None = None
    us_aqi_pm2_5: float | None = None
    us_aqi_pm10: float | None = None
    us_aqi_nitrogen_dioxide: float | None = None
    us_aqi_ozone: float | None = None
    us_aqi_sulphur_dioxide: float | None = None
    us_aqi_carbon_monoxide: float | None = None
    pm2_5: float | None = None
    pm10: float | None = None
    ozone: float | None = None
    nitrogen_dioxide: float | None = None
    sulphur_dioxide: float | None = None
    carbon_monoxide: float | None = None


class _OpenMeteoAQResponse(BaseModel):
    """Top-level air-quality response with current= projection."""
    model_config = ConfigDict(extra="ignore")

    latitude: float
    longitude: float
    current: _OpenMeteoCurrentBlock
    # Other top-level fields (elevation, generationtime_ms, utc_offset_seconds,
    # timezone, timezone_abbreviation, current_units, hourly, hourly_units) are
    # all ignored via extra="ignore" — none consumed by canonical AQIReading.
```

Note: every `current.*` field except `time` is optional. Open-Meteo may omit individual variables (regional restrictions, model coverage gaps), and the wire-validation must not fail if a per-pollutant value is missing — fall through to `None` on the canonical bundle.

**`fetch(*, lat: float, lon: float, http_client=None) -> AQIReading | None` — public entrypoint:**

```python
def fetch(
    *,
    lat: float,
    lon: float,
    http_client: ProviderHTTPClient | None = None,
) -> AQIReading | None:
    """GET /v1/air-quality and return canonical AQIReading or None.

    None: no current reading available (provider returned but us_aqi + all
    per-pollutant values were null).
    Otherwise: canonical AQIReading with whatever fields the provider populated.

    Raises canonical taxonomy on provider failure (L2 carry-forward).
    """
    cache_key = _build_cache_key(lat, lon)
    cached = get_cache().get(cache_key)
    if cached is not None:
        # Sentinel for "no reading available"
        if cached == {"_no_reading": True}:
            return None
        return AQIReading.model_validate(cached)

    params = {
        "latitude": str(round(lat, 6)),
        "longitude": str(round(lon, 6)),
        "current": _REQUESTED_CURRENT_VARS,
        "timezone": "GMT",
    }

    client = http_client or _client_for()
    _rate_limiter.acquire()

    response = client.get(OPENMETEO_AQ_BASE_URL + OPENMETEO_AQ_PATH, params=params)
    # L2 carry-forward: client.get raises canonical taxonomy with attributes
    # set. Do NOT catch and re-raise.

    try:
        wire = _OpenMeteoAQResponse.model_validate(response.json())
    except (ValidationError, ValueError) as exc:
        logger.error(
            "Open-Meteo AQI response validation failed: %s. "
            "Response body (first 2000 chars): %.2000s",
            exc, response.text,
        )
        raise ProviderProtocolError(
            f"Open-Meteo AQI response validation failed: {exc}",
            provider_id=PROVIDER_ID, domain=DOMAIN,
        ) from exc

    record = _wire_to_canonical(wire)
    if record is None:
        # No AQI value present at all (provider returned but all values null) —
        # cache the sentinel so the next dashboard poll within TTL doesn't re-hit.
        get_cache().set(cache_key, {"_no_reading": True}, ttl_seconds=DEFAULT_AQI_TTL_SECONDS)
        return None

    get_cache().set(cache_key, record.model_dump(), ttl_seconds=DEFAULT_AQI_TTL_SECONDS)
    return record
```

**`_wire_to_canonical(wire)` — wire → canonical normalization:**

```python
def _wire_to_canonical(wire: _OpenMeteoAQResponse) -> AQIReading | None:
    """Translate Open-Meteo wire response to canonical AQIReading.

    Returns None if no AQI value AND no per-pollutant value is populated —
    indicating no useful reading at this location.

    Otherwise constructs the canonical record per canonical §4.2:
      - aqi:               current.us_aqi (rounded to int if non-None)
      - aqiCategory:       epa_category(aqi)
      - aqiMainPollutant:  argmax of us_aqi_pm2_5 / us_aqi_pm10 / etc.,
                           mapped to canonical pollutant id table (LC14)
      - aqiLocation:       None (PARTIAL-DOMAIN)
      - pollutantPM25/PM10: current.pm2_5 / pm10 (µg/m³ — passthrough)
      - pollutantO3:       ugm3_to_ppm(current.ozone, pollutant="O3")
      - pollutantNO2:      ugm3_to_ppm(current.nitrogen_dioxide, pollutant="NO2")
      - pollutantSO2:      ugm3_to_ppm(current.sulphur_dioxide, pollutant="SO2")
      - pollutantCO:       ugm3_to_ppm(current.carbon_monoxide, pollutant="CO")
      - observedAt:        current.time + "Z" → parsed as UTC ISO8601 (LC4)
      - source:            "openmeteo"
    """
```

The `current.time` field arrives as `"2026-05-10T18:00"` (local-naive in GMT per the `?timezone=GMT` query). The module appends `Z` to mark it as UTC and stores on canonical `observedAt` as `"2026-05-10T18:00:00Z"`. Open-Meteo's hourly grid means the time always has zero minutes/seconds — adding `:00` for canonical seconds is safe.

The `aqi` value: Open-Meteo returns it as a number (possibly float in edge cases though usually integer). Round to int before canonical assignment. Cap at 500 if the provider ever returns >500 (defensive; matches `_units.epa_category` upper-band behavior).

**`_main_pollutant_from_sub_aqis(current)` helper:**

Take a `_OpenMeteoCurrentBlock`, return canonical pollutant id string or None per LC14. Argmax over the six `us_aqi_*` sub-fields; None values excluded; tie-breaking by table order.

**Cache key construction `_build_cache_key(lat, lon)`:**

```python
def _build_cache_key(lat: float, lon: float) -> str:
    payload = json.dumps({
        "provider_id": PROVIDER_ID,
        "endpoint": "aqi_current",
        "params": {"lat4": round(lat, 4), "lon4": round(lon, 4)},
    }, sort_keys=True)
    return hashlib.sha256(payload.encode()).hexdigest()
```

Mirror of 3b-8 OWM alerts cache key. Endpoint key `"aqi_current"` distinct from any other module's endpoint key.

**HTTP client singleton + test reset helpers:**

Same `_http_client` module-level pattern as 3b-8. `_reset_http_client_for_tests()` exposed for unit-test isolation.

### Module 4: `endpoints/aqi.py` — endpoint dispatch

Mirror of `endpoints/alerts.py`. Two routes, both decorated:

```python
@router.get("/aqi/current", ...)
def get_aqi_current(
    params: Annotated[AQIQueryParams, Depends(_get_aqi_params)],
) -> AQIResponse:
    ...

@router.get("/aqi/history", ...)
def get_aqi_history(
    params: Annotated[AQIHistoryQueryParams, Depends(_get_aqi_history_params)],
) -> JSONResponse:
    # Always 501
    raise HTTPException(...)  # → translated to RFC 9457 by errors.py
```

`AQIQueryParams` is a Pydantic model with no fields (`extra="forbid"`); reused-from-thin-air through the `Depends(_get_aqi_params)` wrapper per coding.md §1 / security-baseline §3.5.

`AQIHistoryQueryParams`: per OpenAPI, accepts `from`, `to`, `limit`, `cursor`, `page`. Pydantic model with these fields and `extra="forbid"`. The handler validates the params (so the 501 response is consistent — invalid params → 422, valid params → 501) but then always returns 501.

`wire_aqi_settings(settings)` extracts `[aqi]` section. For Open-Meteo: no credentials to wire (empty config beyond `provider = openmeteo`). Future-proof for keyed providers.

Provider-id dispatch in `get_aqi_current`:

```python
if provider_id == "openmeteo":
    from weewx_clearskies_api.providers.aqi import openmeteo
    record = openmeteo.fetch(lat=station.latitude, lon=station.longitude)
else:
    logger.error("Unknown AQI provider at request time: %r", provider_id)
    raise HTTPException(status_code=502, detail=f"Unknown AQI provider: {provider_id!r}")
```

When 3b-10/11/12 add Aeris/OWM/IQAir, additional `elif` branches land then.

### Settings + wiring extensions

**`config/settings.py`** — add an `AQISettings` Pydantic model and an `aqi` field on the top-level `Settings` (per LC17). Mirror of `AlertsSettings`.

**`__main__.py`** — extend `_wire_providers_from_config()` to read `settings.aqi.provider` and append `openmeteo.CAPABILITY` to the registered providers list when set. Call `wire_aqi_settings(settings)` after `wire_alerts_settings(settings)` in the startup sequence.

**`app.py`** — register the new `aqi` router. Mirror of where `alerts.router` is registered.

## Cross-cutting requirements

### Pydantic + `Depends(_get_aqi_params)` pattern (carry-forward 3a-1, 3b-1, …)

Both `/aqi/current` and `/aqi/history` use `Depends(_get_aqi_params)` / `Depends(_get_aqi_history_params)` so `extra="forbid"` fires on unknown query keys.

### RFC 9457 errors (carry-forward + extension)

All error paths return `application/problem+json` via the existing errors.py infrastructure. New canonical exception types? No — Open-Meteo errors map to the existing taxonomy.

### Logging (carry-forward)

`logger.info` on cache miss after wire-validation success, including `aqi=` and `mainPollutant=`. `logger.error` on wire-validation failure including the first 2000 chars of the response body. Logs include `extra={"provider_id": PROVIDER_ID, "domain": DOMAIN}` for log filtering.

### Catch specific exceptions

`except Exception` is forbidden. The only `except` clauses in this round catch named classes (`ValidationError, ValueError` on wire parsing; canonical taxonomy is bare-propagation per L2). No string-based dispatch on exception messages.

### No live-network tests in CI (ADR-038 §Testing pattern)

Unit tests use `respx` to mock the `air-quality-api.open-meteo.com` host. Integration tests against the dev/test stack use the captured fixture, never a live call. Tests opt-in to live calls via a separate `live_network` marker (mirror of 3b-1 precedent) and don't run in CI.

### Capability-population wire (one-time, at startup)

The configured AQI provider's `CAPABILITY` symbol is appended to the registry via `_wire_providers_from_config()` in `__main__.py`. Endpoint dispatch reads the registry at request time, not at startup. Tests can populate the registry directly via `wire_providers([openmeteo.CAPABILITY])`.

### No new ADRs

All decisions in this brief are settled by existing ADRs. If api-dev or test-author finds themselves wanting to draft an ADR change, STOP and message the lead.

### No new dependencies

Use only `pydantic`, `httpx` (via `ProviderHTTPClient`), `cachetools` / `redis-py` (via cache abstraction), `fastapi`, stdlib. No new top-level deps. No new transitive deps. If a new dep seems necessary, STOP and message the lead.

## Test-author parallel scope

### Recorded fixture capture

One real captured fixture from Open-Meteo:

**Fixture file:** `tests/fixtures/providers/aqi/openmeteo_current.json` — captured live from `air-quality-api.open-meteo.com/v1/air-quality?latitude=47.6062&longitude=-122.3321&current=us_aqi,us_aqi_pm2_5,us_aqi_pm10,us_aqi_nitrogen_dioxide,us_aqi_ozone,us_aqi_sulphur_dioxide,us_aqi_carbon_monoxide,pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone&timezone=GMT`.

**Sidecar:** `tests/fixtures/providers/aqi/openmeteo_current.md` documents:
- Date of capture (UTC).
- Coordinates used (Seattle: 47.6062, -122.3321).
- Full URL.
- sha256 of the fixture body.
- Notes: which per-pollutant fields populated vs null in this particular capture (some may be null due to model coverage; that's normal).

If real-capture is blocked (no internet from `weather-dev`, etc.): STOP and message the lead — Open-Meteo is keyless so the unblock is straightforward (curl from any host with internet, paste the response, sha-sign).

### Unit tests (`tests/providers/aqi/` and `tests/endpoints/`)

`tests/providers/aqi/test_units.py`:
- `ugm3_to_ppm` round-trips against known values.
- `ugm3_to_ppm(None, pollutant="O3")` returns `None`.
- `ugm3_to_ppm(100, pollutant="UNKNOWN")` raises `KeyError`.
- `epa_category` boundary tests (every breakpoint).
- `epa_category(None)` returns `None`.
- `epa_category(600)` returns `"Hazardous"` (defensive cap).

`tests/providers/aqi/test_openmeteo.py`:
- `_wire_to_canonical` happy path against the captured fixture.
- `_wire_to_canonical` with all per-pollutant nulls returns `None`.
- `_wire_to_canonical` with us_aqi populated but per-pollutant sub-AQIs all null: `aqi` populates, `aqiMainPollutant = None`, per-pollutant fields = None.
- `_main_pollutant_from_sub_aqis` argmax behavior + tie-breaking + all-None case.
- `_build_cache_key` deterministic + lat/lon rounding.
- `fetch` cache hit path (canonical reconstruction from cached dict).
- `fetch` cache hit with `_no_reading` sentinel returns None.
- `fetch` cache miss happy path via `respx` mock.
- `fetch` cache miss + wire-validation failure → `ProviderProtocolError`.
- `fetch` cache miss + provider 502/503/429 → canonical taxonomy propagation (L2; do NOT assert exception messages).
- `fetch` cache miss + all-null reading caches the sentinel + returns None.

`tests/endpoints/test_aqi.py`:
- `/aqi/current` with no provider configured → 200 + `data: null, source: "none"`.
- `/aqi/current` with `openmeteo` registered via `wire_providers([openmeteo.CAPABILITY])` + `respx` mock → 200 + canonical AQIReading.
- `/aqi/current` with `respx` simulating provider 5xx → 502 RFC 9457.
- `/aqi/current` with `respx` simulating provider 429 → 503 RFC 9457 + `Retry-After`.
- `/aqi/current` with unknown query key → 422 (from `extra="forbid"`).
- `/aqi/history` → 501 RFC 9457 (no provider needed).
- `/aqi/history` with unknown query key → 422 (params validate before 501 lands).
- `/aqi/history` with valid `from`/`to` params → 501 anyway.

### Integration tests (against docker-compose dev/test stack — both DB backends + both cache backends)

`tests/integration/test_aqi_integration.py`:
- Full startup with `[aqi]` section in test config, `provider = openmeteo`.
- Fake the upstream via `respx`-on-startup-port OR by passing a test http_client into the openmeteo module.
- Exercise both cache backends (memory + redis) — one round each per ADR-012 + ADR-017.
- Assertions match the OpenAPI `AQIResponse` schema.

### Schema-shape rule (`rules/clearskies-process.md`)

Does NOT fire — AQI has no DB-schema dependency. Tests don't load the seeded production schema for this round.

### Tests run on `weather-dev` BEFORE the dev submits for audit

Hard gate. The pull-then-pytest sequence per the api-dev agent-def §"In parallel-teammate rounds." api-dev fetches origin/main, merges --ff-only, runs pytest, then submits. If anything fails, fix before submission.

### Marker

Use the existing `live_network` marker. Add no new markers.

## Process gates

### G1 — Brief sign-off (this brief)

User reviews this brief; bakes any open Qs as Q-USER-DECIDED. Then teammates spawn.

### G2 — Cross-check rule already fired

Done at brief-draft time (this document's "Cross-check rule findings" section). The §4.2 NO2/SO2 cell amendment lands lead-direct at brief-merge or before spawn (Q3).

### G3 — pytest green before audit

api-dev runs pytest on `weather-dev` (1489 baseline + new tests). All new tests pass; existing tests not regressed. Counts surface in api-dev's closeout SendMessage.

### G4 — Audit phase

Auditor (Opus, source-only review against ADRs + rules + this brief) spawned after BOTH dev + test-author submit AND pytest is green on weather-dev. The auditor's SendMessage recipient fallback chain MUST be in their spawn prompt: `lead` → `team-lead` → `opus` → accumulate-to-closeout (3b-5/6/7/8 carry-forward of harness addressability gap).

### G5 — Lead-synthesize per-finding

Per `rules/clearskies-process.md` "Lead synthesizes auditor findings; doesn't forward." Each finding gets accept (with remediation) / push back / defer triage. Lead-direct candidates ≤50 lines / ≤3 files.

## Anti-patterns (don't)

- Don't try to detect "air quality alerts" inside the AQI provider — ADR-013 explicitly says AQI alerting rides the existing `/alerts` pipeline (NWS AQA / Air Stagnation Advisories). The AQI provider produces a reading; not an alert.
- Don't add `aqiLocation` derivation logic for Open-Meteo — PARTIAL-DOMAIN. Provider has no location label. Always `None`.
- Don't try to support `domains=cams_europe` vs `domains=cams_global` as an operator-tunable in 3b-9. Use the Open-Meteo default (`auto`). Future operator-knob can land in a later round if a use case surfaces.
- Don't add `european_aqi` to the canonical bundle. Canonical is EPA 0-500 per ADR-013. European AQI is a different scale; not in scope for v0.1.
- Don't add a "current is stale" warning. Open-Meteo's data is hourly-resolved; clearskies-api's TTL is 15 min. The two interact cleanly. If staleness becomes a concern, that's a separate round.
- Don't extend `providers/_common/` files. The infrastructure is locked.
- Don't synthesize an `aqi` from per-pollutant concentrations if `us_aqi` is null. Canonical `aqi` is None when the provider couldn't compute it. The aqiMainPollutant + per-pollutant fields populate independently.
- Don't normalize `current.time` to UTC by adding `utc_offset_seconds` from the response — we asked for `timezone=GMT`, so the wire IS GMT/UTC. Adding the offset double-shifts. The wire-shape comment in the Pydantic model should note this.
- Don't introduce a "fallback provider" path. ADR-013 is single-provider-per-deploy. If the configured provider fails, the canonical taxonomy propagates and the dashboard shows an error state. No automatic fallback.

## Reporting back

### api-dev closeout

- Files added: list paths + line counts.
- Files modified (existing endpoints/settings/app): list paths + diff stats.
- Pytest result on `weather-dev`: pass/skip/fail counts.
- Any L1/L2/L3 rule applied with explicit citation in commit body.
- Surprises encountered: anything that diverged from this brief's spec, especially if a lead-call was needed mid-round (should be SendMessage'd in-flight, but recap in closeout).

### test-author closeout

- Test files added: paths + line counts.
- Fixture captured: path + capture date + sha256.
- Pytest result: pass/skip/fail counts; surface any failing tests as either real bugs (route to api-dev) or pre-existing baseline drift (cite the baseline commit).
- Coverage delta (if measured).

## Out of scope / parking lot

- Aeris AQI (3b-10): paid keyed provider; reuses aeris credential plumbing from 3b-7.
- OWM AQI (3b-11): paid keyed provider; lands the EPA 1-5 → 0-500 conversion (OWM uses a different AQI scale).
- IQAir AQI (3b-12): first header-auth keyed provider; extends `logging/redaction_filter.py` for `X-Key` header redaction.
- `/aqi/history` persistence (3b-?): separate architecture round — writeable datastore, retention policy, write-on-fetch hook, paginated read. ADR-013 §Out of scope explicitly defers the mechanism.
- Path A column-mapping flow (lands when ADR-035 column-mapping infrastructure does): operator's own AQI extension writes archive columns; mapped to canonical AQI at setup. Out of scope for 3b-9 (which lands Path B).
- Non-EPA scale conversion table (European AQI etc.): not in canonical v0.1; out of scope.
- Cache stampede / dogpile mitigation: ADR-017 explicitly defers to Phase 6+ if hot keys surface.
- Real-time AQI streaming via SSE: belongs to weewx-clearskies-realtime, not the api.
