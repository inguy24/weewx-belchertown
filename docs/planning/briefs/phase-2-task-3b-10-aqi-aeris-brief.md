# Phase 2 task 3b-10 — /aqi/aeris (second AQI provider)

**Round identity:** 3b-10 is the second round of the AQI series. 3b-9 (2026-05-10) opened the AQI domain with the shared `providers/aqi/` infrastructure (`__init__.py`, `_units.py` with µg/m³→ppm + EPA category bands) + `endpoints/aqi.py` (with `/aqi/current` full + `/aqi/history` 501 stub) + Open-Meteo as the first AQI provider. 3b-10 adds Aeris as the second AQI provider per ADR-013. The remaining day-1 AQI providers (OpenWeatherMap, IQAir) queue for 3b-11 / 3b-12.

**Scope sizing:** Shared infrastructure is locked. The genuinely new work for 3b-10 is:

1. A new `providers/aqi/aeris.py` provider module modeled on `providers/aqi/openmeteo.py` (3b-9) + `providers/alerts/aeris.py` (3b-7) — capability declaration, wire-shape Pydantic models, fetch entrypoint with keyed credentials, translation to canonical AQIReading, with Aeris-specific behaviors (filter-by-type pollutants[] array, PPB → ppm conversion, lowercase category/dominant normalization).
2. One new helper in `providers/aqi/_units.py`: `ppb_to_ppm(ppb)` — division-by-1000 for direct PPB→ppm conversion.
3. One new `elif provider_id == "aeris":` branch in `endpoints/aqi.py` dispatch (line 175 area).
4. Settings + wiring extensions in `endpoints/aqi.py:wire_aqi_settings()` to extract Aeris credentials when `provider = aeris`.
5. Tests covering the Aeris module + endpoint behavior.

## User decisions baked into this brief (2026-05-10)

**Q1 — Provider for 3b-10:** **Aeris.** Per resume prompt recommendation (second AQI provider, smallest scope of the keyed AQI providers, reuses existing Aeris auth plumbing from 3b-4 forecast + 3b-7 alerts, no new shared-infrastructure work in `_units.py` beyond the trivial `ppb_to_ppm` helper).

**Q2 — Canonical §4.2 aeris column amendment (USER DECIDED 2026-05-10 — Lead-direct amend, COMMITTED a599d17):** Two corrections applied before brief draft:
  - Wire-path correction: six pollutant cells (`pollutantPM25`/`PM10`/`O3`/`NO2`/`SO2`/`CO`) now read `periods[0].pollutants[]` where `type=="..."` → `valueUGM3` (particulates) or `valuePPB` (gases). The previous `periods[].pollutants[].{name}` cells implied object-keyed access; Aeris's actual wire shape is a typed array.
  - Unit annotation correction: gas cells (O3/NO2/SO2/CO) now read `(convert PPB → ppm)`; the Aeris module uses `valuePPB` divided by 1000, NOT the `ugm3_to_ppm` helper that Open-Meteo uses.
  - New §4.2 footnote summarizing the Aeris pollutants[] shape, PPB → ppm conversion, lowercase `periods[].category` normalization (derive via `epa_category(aqi)` — Open-Meteo pattern), lowercase `dominant` → canonical id mapping, and pm1 drop.
  - api-docs/aeris.md extended with `### Air Quality` section (full example response with realistic pollutants[] array, wire-shape notes, documentation-gaps section).

Same bug class as 3b-7 caught for Aeris alerts (canonical §4.3 `priority`/`cat` mismatches). Cross-check rule fourth validation in a row (3b-7, 3b-8, 3b-9, 3b-10).

## Cross-check rule findings (canonical §4.2 vs api-docs)

Applied per `rules/clearskies-process.md` "Cross-check canonical mapping cells against api-docs example responses at brief-draft." Verified each cell in §4.2 aeris column against `docs/reference/api-docs/aeris.md` (extended in this brief-draft session to include the `### Air Quality` subsection, source verified 2026-05-10 against https://www.xweather.com/docs/weather-api/endpoints/airquality).

| Canonical | §4.2 says (post-amend) | api-docs example | Match? |
|---|---|---|---|
| `aqi` | `periods[].aqi` (US EPA scale by default) | `periods[0].aqi`: 42 | ✓ |
| `aqiCategory` | `periods[].category` (lowercase / `usg` abbreviation — module derives via `epa_category(aqi)`) | `periods[0].category`: "good" | ✓ (normalize) |
| `aqiMainPollutant` | `periods[].dominant` (lowercase id — module normalizes to canonical) | `periods[0].dominant`: "pm2.5" | ✓ (normalize) |
| `aqiLocation` | `place.name` | `place.name`: "seattle" | ✓ (NOT PARTIAL-DOMAIN — Aeris IS supplied) |
| `pollutantPM25` | `periods[0].pollutants[]` where `type=="pm2.5"` → `valueUGM3` (µg/m³) | `pollutants[0].valueUGM3`: 8.5 | ✓ (post-amend) |
| `pollutantPM10` | `periods[0].pollutants[]` where `type=="pm10"` → `valueUGM3` (µg/m³) | `pollutants[1].valueUGM3`: 12.0 | ✓ (post-amend) |
| `pollutantO3` | `periods[0].pollutants[]` where `type=="o3"` → `valuePPB` (convert PPB → ppm) | `pollutants[2].valuePPB`: 32.1 | ✓ (post-amend) |
| `pollutantNO2` | `periods[0].pollutants[]` where `type=="no2"` → `valuePPB` (convert PPB → ppm) | `pollutants[3].valuePPB`: 5.3 | ✓ (post-amend) |
| `pollutantSO2` | `periods[0].pollutants[]` where `type=="so2"` → `valuePPB` (convert PPB → ppm) | `pollutants[4].valuePPB`: 1.2 | ✓ (post-amend) |
| `pollutantCO` | `periods[0].pollutants[]` where `type=="co"` → `valuePPB` (convert PPB → ppm) | `pollutants[5].valuePPB`: 150.0 | ✓ (post-amend) |
| `observedAt` | `periods[].dateTimeISO` | `periods[0].dateTimeISO`: "2026-04-30T10:00:00-07:00" | ✓ (with explicit-offset → UTC parsing) |

All eleven cells match post-amendment. The `aqiCategory` + `aqiMainPollutant` rows are still operationally normalized inside the module (Aeris's lowercase/abbreviated wire values don't match canonical Title Case directly), which is documented in the §4.2 footnote and in the api-docs file but NOT in the §4.2 cell text (the cells point at the wire fields; the module's normalization is internal). No new cross-check findings beyond the two amendments already applied.

## Lead+user-confirmed calls (resolved before spawn)

Per `rules/clearskies-process.md` "Brief questions audit themselves before draft" — non-judgment-call items are lead-resolved inline. Items here would have been numbered questions in earlier briefs but are settled by ADR / contract / 3b-9 precedent.

**LC1 — Module location.** `weewx_clearskies_api/providers/aqi/aeris.py` per ADR-038 §2 + ADR-013 §Decision.

**LC2 — Endpoint module.** `endpoints/aqi.py` already wired in 3b-9. Add `elif provider_id == "aeris":` branch around line 175. No new endpoint module.

**LC3 — Cache TTL.** **900s (15 min)** per ADR-017's per-domain TTL table. Same constant as openmeteo: `DEFAULT_AQI_TTL_SECONDS = 900`. Mirror 3b-9.

**LC4 — `observedAt` time-zone normalization.** Aeris returns `periods[0].dateTimeISO` as an explicit-offset ISO-8601 string (e.g. `"2026-04-30T10:00:00-07:00"`), NOT local-naive like Open-Meteo. Parse via `datetime.fromisoformat()`; if non-null, normalize to UTC and emit as canonical UTC ISO with `Z` suffix (use `providers/_common/datetime_utils.iso_to_utc_iso8601()` if a helper exists; otherwise inline the parse → `.astimezone(UTC)` → `.isoformat().replace("+00:00", "Z")` chain). DO NOT use `epoch_to_utc_iso8601()` on `periods[0].timestamp` even though it's available — `dateTimeISO` carries the explicit offset and matches the 3b-7 alerts/aeris precedent (which used `timestamps.issuedISO`).

**LC5 — Wire-model `extra="ignore"`.** Aeris response carries many fields canonical AQIReading doesn't consume (`color`, `method`, `health.*`, per-pollutant `aqi`/`category`/`color`/`method`/`name`, `profile.*`, `loc.*`, `id`). `model_config = ConfigDict(extra="ignore")` on every wire model per 3b-9 precedent. Required fields enumerated raise `ValidationError` if missing → `ProviderProtocolError` at the fetch boundary.

**LC6 — Cache value shape.** `dict` (post-`model_dump()`); reconstruction via `AQIReading.model_validate(cached_dict)`. Single-entry cache. Mirror 3b-9.

**LC7 — Cache key construction.** Deterministic SHA-256 over `{"provider_id": "aeris", "endpoint": "aqi_current", "params": {"lat4", "lon4"}}`. **Credentials NOT in the key** (privacy/leakage concern; cache scope is per-location-per-provider, not per-tenant). Mirror 3b-7 alerts/aeris + 3b-9 openmeteo aqi.

**LC8 — Rate limiter.** `max_calls=5, window_seconds=1` (be-polite guard). Mirror 3b-9.

**LC9 — Capability registration.** `providers/aqi/aeris.CAPABILITY`. Registered at startup by `_wire_providers_from_config()` in `__main__.py` reading `[aqi] provider = aeris`.

**LC10 — Geographic coverage.** `geographic_coverage="global"`. Aeris's airquality endpoint coverage is documented as global (per the api-docs file).

**LC11 — `auth_required` tuple.** `auth_required=("client_id", "client_secret")` per 3b-4 / 3b-7 aeris precedent. Keyed via query params (not header auth; that's 3b-12 IQAir).

**LC12 — `supplied_canonical_fields`.** All twelve canonical AQIReading fields (full max-surface for Aeris paid-tier — no documented free-vs-paid tier differences on this endpoint per public docs):
  - `aqi`, `aqiCategory`, `aqiMainPollutant`, `aqiLocation`
  - `pollutantPM25`, `pollutantPM10`, `pollutantO3`, `pollutantNO2`, `pollutantSO2`, `pollutantCO`
  - `observedAt`, `source`
  - **NO PARTIAL-DOMAIN omissions.** Aeris supplies every canonical AQI field (`aqiLocation` via `place.name`).

**LC13 — `aqiCategory` derivation.** Use the shared `epa_category(aqi)` helper from `providers/aqi/_units.py`. Do NOT use `periods[0].category` directly — it's lowercase with `usg` abbreviation (`good | moderate | usg | unhealthy | very unhealthy | hazardous`); canonical specifies Title Case full names. Deriving from `aqi` via EPA bands keeps Aeris consistent with Open-Meteo's pattern and ensures category always matches the AQI value via the same band table (single source of truth).

**LC14 — `aqiMainPollutant` derivation.** Lookup table from `periods[0].dominant` (lowercase Aeris id) → canonical pollutant id:

| Aeris `dominant` | Canonical pollutant id (§3.8) |
|---|---|
| `pm2.5` | `PM2.5` |
| `pm10` | `PM10` |
| `o3` | `O3` |
| `no2` | `NO2` |
| `so2` | `SO2` |
| `co` | `CO` |
| `pm1` | dropped (canonical has no `PM1` field — `aqiMainPollutant = None` if Aeris reports pm1 as dominant) |

If `dominant` is missing/null/unknown → `aqiMainPollutant = None`. Module-level constant `_DOMINANT_TO_CANONICAL: dict[str, str]`.

**LC15 — Pollutant value extraction.** Module helper `_extract_pollutants(periods: _AerisPeriod) -> dict[str, float | None]` filters `periods[0].pollutants` by `type` and pulls `valueUGM3` (PM2.5/PM10) or `valuePPB` (O3/NO2/SO2/CO). Returns a dict keyed by canonical pollutant id (`"PM25"`, `"PM10"`, `"O3"`, etc.). pm1 is ignored (not in canonical). For each gas, the value is then run through `ppb_to_ppm()` before assignment to the canonical record. For each particulate, the µg/m³ value passes through.

**LC16 — `ppb_to_ppm` helper.** NEW function in `providers/aqi/_units.py`:

```python
def ppb_to_ppm(ppb: float | None) -> float | None:
    """Convert ppb (parts per billion) to ppm (parts per million).

    Args:
        ppb: concentration in ppb (or None).

    Returns:
        ppm value (None propagates).  ppm = ppb / 1000.
    """
    if ppb is None:
        return None
    return ppb / 1000.0
```

No pollutant arg needed — the conversion is identical for all gases (no molar volume / mol weight involved). Pure function.

**LC17 — `source` literal.** `source = "aeris"` (provider_id). On canonical `AQIReading.source` and on `AQIResponse.source` envelope. Mirror every other Aeris module.

**LC18 — Settings extension.** Reuse the existing `[aeris]` settings section per the 3b-4 Q1 provider-scoped-credentials decision. Credentials live at `settings.aeris.client_id` + `settings.aeris.client_secret` (already populated from `WEEWX_CLEARSKIES_AERIS_CLIENT_ID` + `WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET` env vars per 3b-4 / 3b-7). No new `aqi_aeris_*` config keys; no new env vars.

**LC19 — Wiring entry.** Extend `wire_aqi_settings(settings)` in `endpoints/aqi.py` (currently a no-op for Open-Meteo): when `settings.aqi.provider == "aeris"`, read `settings.aeris.client_id` + `settings.aeris.client_secret` and stash in module-level `_AERIS_CLIENT_ID` + `_AERIS_CLIENT_SECRET` for the dispatcher to pass to `aeris.fetch()`. If either credential is missing, log an error and continue (capability is still registered; first `/aqi/current` call surfaces `KeyInvalid`). Mirror 3b-7 alerts/aeris wiring pattern.

**LC20 — Endpoint dispatch extension.** Add to `get_aqi_current` after the `if provider_id == "openmeteo":` branch:

```python
elif provider_id == "aeris":
    from weewx_clearskies_api.providers.aqi import aeris  # noqa: PLC0415
    record = aeris.fetch(
        lat=station.latitude,
        lon=station.longitude,
        client_id=_AERIS_CLIENT_ID,
        client_secret=_AERIS_CLIENT_SECRET,
    )
```

Mirror the openmeteo branch shape. Lazy import per the existing style. Credentials read from module-level vars stashed by `wire_aqi_settings()`.

**LC21 — `filter=airnow` explicit pass.** The Aeris module passes `filter=airnow` explicitly in the query params to lock the US EPA AQI methodology (Aeris supports `china` and `india` alternatives; default is `airnow`). Canonical / ADR-013 lock the 0–500 EPA scale, so being explicit pre-empts any future Aeris default change.

**LC22 — Action choice.** Use `:id` action with `lat,long` location specifier in the path: `GET /airquality/{lat},{lon}?filter=airnow&client_id=...&client_secret=...`. NOT the `p=` query string form, NOT the `closest`/`route` actions. Mirror 3b-4 forecast/aeris precedent.

**LC23 — Test fixture strategy (L3 synthetic-from-real).** Per the test-author agent-def: attempt real fixture capture first via the existing AERIS credentials available in `.env` / weather-dev. The /airquality endpoint MAY require a paid plan tier we don't have; if real capture returns `401`/`403`/`insufficient_scope`, fall back to synthetic-from-docs-example (the example response in `docs/reference/api-docs/aeris.md` `### Air Quality` section is realistic, with PM2.5-dominant clean-air values). Sidecar `.md` documents whether the fixture is real-captured or synthetic-from-docs.

**LC24 — Logging surface.** Same convention as 3b-9 openmeteo: `logger.debug` on cache hits/misses; `logger.info` on "AQI fetched: aqi=X mainPollutant=Y" cache miss; `logger.error` on wire-validation failures with first 2000 chars of response body. Logs include `extra={"provider_id": "aeris", "domain": "aqi"}`.

**LC25 — Module docstring "Five responsibilities".** Mirror 3b-9 openmeteo's docstring structure (1. Outbound API call / 2. Response parsing / 3. Translation / 4. Capability declaration / 5. Error handling). Adapt the specifics for Aeris (keyed query-param auth; explicit-offset ISO timestamp; pollutants[] array filter-by-type; PPB → ppm for gases; lowercase normalizations).

**LC26 — pm1 handling.** Aeris's `pollutants[]` may include `{"type": "pm1", ...}`. Canonical AQIReading has no `pollutantPM1` field — drop this pollutant during translation. `_DOMINANT_TO_CANONICAL` does NOT include `"pm1"`; if `dominant == "pm1"`, `aqiMainPollutant = None` (the module logs `logger.info` noting the unmappable dominant).

## Hard reading list (once per session)

api-dev + test-author each read these before writing any code:

1. **`docs/decisions/ADR-013-aqi-handling.md`** — AQI architecture decision (full file).
2. **`docs/decisions/ADR-017-provider-response-caching.md`** — Cache TTL + backend (full file).
3. **`docs/decisions/ADR-038-data-provider-module-organization.md`** — five-responsibility module pattern (full file).
4. **`docs/decisions/ADR-018-api-versioning-policy.md`** — RFC 9457 error response shape (full file).
5. **`docs/decisions/ADR-020-time-zone-handling.md`** — UTC at API boundary (full file).
6. **`docs/contracts/canonical-data-model.md`** §3.8 (AQIReading) and §4.2 (AQI providers — post-amend with Aeris pollutants[] footnote) and §5 (Pydantic config).
7. **`docs/contracts/openapi-v1.yaml`** `/aqi/current` + `AQIResponse` + `AQIReading` schemas (already wired in 3b-9; no schema change for 3b-10).
8. **`docs/reference/api-docs/aeris.md`** — full file; pay particular attention to the new `### Air Quality` subsection (added at brief-draft time 2026-05-10) and the wire-shape notes within it.
9. **`rules/coding.md`** — full file. §3 carry-forwards still apply (dispatch on attributes / DRY / no dead code).
10. **`rules/clearskies-process.md`** — full file. The "Provider CAPABILITY declares paid-tier maximum supply set" rule DOES fire here (Aeris is keyed/tiered; we declare the full surface; runtime population is conditional). The "Real schemas in unit tests where the schema shape matters" rule does NOT fire (no DB-schema dependency).

### Reference impls (read before writing — do NOT rewrite)

11. **`weewx_clearskies_api/providers/aqi/openmeteo.py`** — closest structural precedent (3b-9). The 3b-10 `providers/aqi/aeris.py` should track this file's overall shape (module-level constants, capability declaration, wire-shape Pydantic models, rate limiter, cache-key construction, fetch entrypoint, translation helper, test reset helpers). Differences below in §"Per-module spec."
12. **`weewx_clearskies_api/providers/alerts/aeris.py`** — closest Aeris-keyed precedent (3b-7). Use for the keyed-auth pattern (credentials in fetch signature, query-param injection, no credentials in cache key).
13. **`weewx_clearskies_api/providers/forecast/aeris.py`** — earliest Aeris precedent (3b-4). Read to confirm credentials handling + `auth_required` tuple shape.
14. **`weewx_clearskies_api/providers/aqi/_units.py`** — extend with `ppb_to_ppm`; do NOT modify existing `ugm3_to_ppm`, `epa_category`, or the constant tables.
15. **`weewx_clearskies_api/endpoints/aqi.py`** — extend dispatch + `wire_aqi_settings()`; do NOT modify the `/aqi/history` 501 handler or the openmeteo branch.
16. **`weewx_clearskies_api/providers/_common/`** — full directory. DO NOT rewrite or modify any file here.

## Existing code (do not rewrite)

Locked infrastructure built in prior rounds:

- `providers/_common/cache.py` — cache abstraction; `get_cache()`.
- `providers/_common/capability.py` — `ProviderCapability` + `get_provider_registry()` + `wire_providers()`.
- `providers/_common/datetime_utils.py` — `epoch_to_utc_iso8601()`. **Do not use for Aeris** (we parse `dateTimeISO` explicit-offset strings, not epoch timestamps).
- `providers/_common/dispatch.py` — module-by-id dispatcher.
- `providers/_common/errors.py` — canonical exception taxonomy.
- `providers/_common/http.py` — `ProviderHTTPClient` raises canonical taxonomy. **L2 carry-forward:** do NOT re-construct.
- `providers/_common/rate_limiter.py` — `RateLimiter`.
- `errors.py` (top-level) — RFC 9457 problem+json.
- `endpoints/aqi.py` openmeteo branch + history 501 handler — extend dispatch only, don't refactor.
- `providers/aqi/openmeteo.py` — reference impl; do NOT modify.
- `providers/aqi/_units.py` `ugm3_to_ppm` + `epa_category` + constants — extend with `ppb_to_ppm`, don't modify existing.

If you find yourself wanting to modify any of the above (beyond the specified additions), STOP and message the lead.

## Per-module spec

### Module 1: `providers/aqi/aeris.py` — NEW second AQI provider

Closest structural precedent: `providers/aqi/openmeteo.py` (3b-9). Differences in approximate order of importance:

**Endpoint:**
- Base URL: `https://data.api.xweather.com` (same as 3b-4 forecast/aeris + 3b-7 alerts/aeris).
- Path: `/airquality/{lat},{lon}` (NOT `/airquality?p={lat},{lon}` — use `:id` action with location-in-path per LC22).
- Method: GET
- Required query params: `client_id`, `client_secret`, `filter=airnow` (LC21).

**Module-level constants:**

```python
PROVIDER_ID = "aeris"
DOMAIN = "aqi"
DEFAULT_AQI_TTL_SECONDS = 900  # per LC3 / ADR-017
_API_VERSION = "0.1.0"
AERIS_AQ_BASE_URL = "https://data.api.xweather.com"
AERIS_AQ_PATH_TMPL = "/airquality/{lat},{lon}"  # location in path

_DOMINANT_TO_CANONICAL: dict[str, str] = {
    "pm2.5": "PM2.5",
    "pm10":  "PM10",
    "o3":    "O3",
    "no2":   "NO2",
    "so2":   "SO2",
    "co":    "CO",
    # "pm1" intentionally omitted — canonical has no pollutantPM1 field
}

# type-string in Aeris pollutants[] array → canonical pollutant id used by
# AQIReading field name (note: PM2.5 → field "pollutantPM25", NOT "pollutantPM2.5"
# since the canonical model uses dot-stripped suffix).
_TYPE_TO_CANONICAL_FIELD: dict[str, str] = {
    "pm2.5": "pollutantPM25",
    "pm10":  "pollutantPM10",
    "o3":    "pollutantO3",
    "no2":   "pollutantNO2",
    "so2":   "pollutantSO2",
    "co":    "pollutantCO",
    # "pm1" intentionally omitted
}

# Which canonical field uses PPB (gases) vs UGM3 (particulates).
_GAS_FIELDS: frozenset[str] = frozenset({
    "pollutantO3", "pollutantNO2", "pollutantSO2", "pollutantCO",
})
_PARTICULATE_FIELDS: frozenset[str] = frozenset({
    "pollutantPM25", "pollutantPM10",
})
```

**Capability declaration:**

```python
CAPABILITY = ProviderCapability(
    provider_id=PROVIDER_ID,
    domain=DOMAIN,
    supplied_canonical_fields=(
        "aqi", "aqiCategory", "aqiMainPollutant", "aqiLocation",
        "pollutantPM25", "pollutantPM10",
        "pollutantO3", "pollutantNO2", "pollutantSO2", "pollutantCO",
        "observedAt", "source",
    ),
    geographic_coverage="global",
    auth_required=("client_id", "client_secret"),
    default_poll_interval_seconds=DEFAULT_AQI_TTL_SECONDS,
    operator_notes=(
        "Aeris (Xweather) /airquality endpoint with filter=airnow (US EPA AQI). "
        "Keyed (query-param client_id + client_secret; reuses provider-scoped "
        "credentials from forecast/alerts Aeris). Gas concentrations converted "
        "PPB→ppm via providers/aqi/_units.ppb_to_ppm (NOT ugm3_to_ppm — Aeris "
        "returns valuePPB directly). aqiCategory derived client-side via "
        "epa_category(aqi) (Aeris's periods[].category is lowercase with "
        "'usg' abbreviation, doesn't match canonical Title Case). "
        "aqiMainPollutant normalized from lowercase periods[].dominant to "
        "canonical id. pm1 dropped (no pollutantPM1 field on canonical)."
    ),
)
```

**Wire-shape Pydantic models:**

```python
class _AerisPollutant(BaseModel):
    """One pollutant entry in periods[].pollutants[] (LC5)."""
    model_config = ConfigDict(extra="ignore")
    type: str  # "pm2.5", "pm10", "o3", "no2", "so2", "co", "pm1"
    valuePPB: float | None = None
    valueUGM3: float | None = None
    # name, aqi, category, color, method are present on the wire but unused.


class _AerisPlace(BaseModel):
    """response[0].place (LC5)."""
    model_config = ConfigDict(extra="ignore")
    name: str | None = None
    state: str | None = None
    country: str | None = None


class _AerisPeriod(BaseModel):
    """response[0].periods[0] (LC5)."""
    model_config = ConfigDict(extra="ignore")
    dateTimeISO: str  # explicit-offset ISO, e.g. "2026-04-30T10:00:00-07:00"
    aqi: float | None = None
    dominant: str | None = None
    pollutants: list[_AerisPollutant] = []
    # category, color, method, health, timestamp are present but unused
    # (category lowercase doesn't match canonical; derive via epa_category instead).


class _AerisLocation(BaseModel):
    """response[0] (LC5)."""
    model_config = ConfigDict(extra="ignore")
    place: _AerisPlace | None = None
    periods: list[_AerisPeriod] = []
    # id, loc, profile present on the wire but unused.


class _AerisError(BaseModel):
    """response.error envelope when success=false (or warning when success=true)."""
    model_config = ConfigDict(extra="ignore")
    code: str
    description: str | None = None


class _AerisAQResponse(BaseModel):
    """Top-level airquality response envelope (LC5)."""
    model_config = ConfigDict(extra="ignore")
    success: bool
    error: _AerisError | None = None
    response: list[_AerisLocation] = []
```

Aeris's `:id` action returns `response` as an array (per the api-docs "Response format conventions" — `:id` is documented as returning a single object, but the airquality endpoint specifically returns the response as an array containing one location object). The module reads `response[0]` (the single location) and `response[0].periods[0]` (the single current period). If `response` is empty or `periods` is empty: `_wire_to_canonical` returns None (no useful reading).

Aeris's success envelope: `success: false` + `error: {code, description}` is documented as a 200-with-error response shape. The module checks `wire.success` after Pydantic validation; if false, log the error code/description and raise `ProviderProtocolError` (the canonical taxonomy member matching "the provider responded but with a wire-level error" — different from `KeyInvalid`/`QuotaExhausted`/`TransientNetworkError`/`ProviderProtocolError` for HTTP-level errors, which the `ProviderHTTPClient.get` already maps).

Wait — that's a non-trivial decision. Let me revise: Aeris's "200 success: false" responses include both genuine wire-level errors (`invalid_query`, `warn_invalid_param`) AND tier/auth issues (`invalid_client`, `insufficient_scope`). Mapping all of them to `ProviderProtocolError` would lose the auth distinction. **Lead-call (LC27 below):** Inspect `error.code` after Pydantic validation:
- `invalid_client` / `insufficient_scope` / `unauthorized` / `forbidden_access` → `KeyInvalid`
- `maxhits_min` or any rate-limit-indication → `QuotaExhausted`
- everything else where `success: false` → `ProviderProtocolError`
- `success: true` → proceed to translation

This is consistent with 3b-7 alerts/aeris (which handled the same envelope) — verify with 3b-7's impl before authoring.

**LC27 — Aeris 200-success-false envelope mapping.** Inspect `wire.success` + `wire.error.code` after Pydantic validation:

| Aeris condition | Mapped canonical exception |
|---|---|
| `success: true, response: [{...periods: [{...}]}]` | (proceed to translation) |
| `success: true, response: []` OR `response[0].periods: []` | (no reading — return None, cache `_no_reading` sentinel) |
| `success: false, error.code ∈ {"invalid_client", "insufficient_scope", "unauthorized", "forbidden_access"}` | `KeyInvalid` |
| `success: false, error.code` matches a rate-limit indicator | `QuotaExhausted` (with `retry_after_seconds=None` since 200-not-429) |
| `success: false, error.code` is anything else (`invalid_query`, `warn_invalid_param`, etc.) | `ProviderProtocolError` |

api-dev cross-checks the actual error-code strings against 3b-7 `providers/alerts/aeris.py` since 3b-7 already handled this envelope; reuse whatever string set 3b-7 codified.

**`fetch(*, lat, lon, client_id, client_secret, http_client=None) -> AQIReading | None`:**

Public entrypoint. Keyed credentials in the signature (LC11 + LC22).

```python
def fetch(
    *,
    lat: float,
    lon: float,
    client_id: str,
    client_secret: str,
    http_client: ProviderHTTPClient | None = None,
) -> AQIReading | None:
    """GET /airquality/{lat},{lon}?filter=airnow and return canonical AQIReading or None.

    None: provider responded but no useful reading available (empty response
    or empty periods).
    Otherwise: canonical AQIReading with whatever fields the provider populated.

    Raises canonical taxonomy on provider failure (L2 carry-forward — bare
    propagation of HTTP-level errors from ProviderHTTPClient).  Wire-level
    success-false envelope mapped per LC27.
    """
    cache_key = _build_cache_key(lat, lon)  # credentials NOT in key
    cached = get_cache().get(cache_key)
    if cached is not None:
        if cached == {"_no_reading": True}:
            return None
        return AQIReading.model_validate(cached)

    url = AERIS_AQ_BASE_URL + AERIS_AQ_PATH_TMPL.format(
        lat=round(lat, 6),
        lon=round(lon, 6),
    )
    params = {
        "client_id": client_id,
        "client_secret": client_secret,
        "filter": "airnow",
    }

    client = http_client or _client_for()
    _rate_limiter.acquire()

    response = client.get(url, params=params)
    # L2 carry-forward: client.get() raises canonical taxonomy with
    # attributes set.  Do NOT catch and re-raise.

    try:
        wire = _AerisAQResponse.model_validate(response.json())
    except (ValidationError, ValueError) as exc:
        ...  # log + raise ProviderProtocolError (mirror openmeteo)

    # Envelope check (LC27)
    if not wire.success:
        _raise_for_envelope_error(wire)  # raises canonical taxonomy member

    if not wire.response or not wire.response[0].periods:
        # No reading at this location — cache sentinel
        get_cache().set(cache_key, {"_no_reading": True}, ttl_seconds=DEFAULT_AQI_TTL_SECONDS)
        return None

    record = _wire_to_canonical(wire.response[0])
    if record is None:
        get_cache().set(cache_key, {"_no_reading": True}, ttl_seconds=DEFAULT_AQI_TTL_SECONDS)
        return None

    get_cache().set(cache_key, record.model_dump(), ttl_seconds=DEFAULT_AQI_TTL_SECONDS)
    return record
```

**`_wire_to_canonical(location)` — wire → canonical normalization:**

```python
def _wire_to_canonical(location: _AerisLocation) -> AQIReading | None:
    """Translate Aeris response[0] to canonical AQIReading."""
    period = location.periods[0]  # caller guarantees non-empty

    # aqi: int round + cap at 500 (defensive)
    aqi_int: int | None = None
    if period.aqi is not None:
        aqi_int = min(round(period.aqi), 500)

    # aqiCategory: derive client-side via EPA bands (LC13)
    category = epa_category(aqi_int)

    # aqiMainPollutant: normalize lowercase Aeris id to canonical (LC14)
    main_pollutant = _DOMINANT_TO_CANONICAL.get(period.dominant or "")
    if not main_pollutant and period.dominant:
        # Unmappable (e.g. "pm1"): log + None
        logger.info(
            "Aeris dominant pollutant %r not in canonical id table; aqiMainPollutant=None",
            period.dominant,
        )

    # aqiLocation: place.name (with state/country fallback if name missing)
    aqi_location = None
    if location.place is not None:
        aqi_location = location.place.name

    # Pollutant values: filter by type, convert PPB → ppm for gases (LC15 + LC16)
    pollutant_values: dict[str, float | None] = {}
    for entry in period.pollutants:
        canonical_field = _TYPE_TO_CANONICAL_FIELD.get(entry.type.lower())
        if canonical_field is None:
            continue  # pm1 or unknown type — skip
        if canonical_field in _GAS_FIELDS:
            pollutant_values[canonical_field] = ppb_to_ppm(entry.valuePPB)
        else:
            pollutant_values[canonical_field] = entry.valueUGM3

    # observedAt: parse dateTimeISO explicit-offset → UTC ISO with Z (LC4)
    observed_at = _iso_offset_to_utc_z(period.dateTimeISO)

    # Empty-result check: aqi + all pollutants null → None
    has_data = aqi_int is not None or any(
        v is not None for v in pollutant_values.values()
    )
    if not has_data:
        return None

    return AQIReading(
        aqi=aqi_int,
        aqiCategory=category,
        aqiMainPollutant=main_pollutant,
        aqiLocation=aqi_location,
        pollutantPM25=pollutant_values.get("pollutantPM25"),
        pollutantPM10=pollutant_values.get("pollutantPM10"),
        pollutantO3=pollutant_values.get("pollutantO3"),
        pollutantNO2=pollutant_values.get("pollutantNO2"),
        pollutantSO2=pollutant_values.get("pollutantSO2"),
        pollutantCO=pollutant_values.get("pollutantCO"),
        observedAt=observed_at,
        source=PROVIDER_ID,
    )
```

**`_iso_offset_to_utc_z(iso_str)` helper:**

```python
def _iso_offset_to_utc_z(iso_str: str) -> str:
    """Parse explicit-offset ISO-8601 → UTC ISO with Z suffix.

    Aeris's dateTimeISO has explicit offsets like "2026-04-30T10:00:00-07:00".
    Parse → datetime → astimezone(UTC) → isoformat → swap +00:00 for Z.
    """
    dt = datetime.fromisoformat(iso_str)  # 3.11+ handles explicit offsets
    dt_utc = dt.astimezone(UTC)
    iso = dt_utc.isoformat()
    if iso.endswith("+00:00"):
        iso = iso[:-6] + "Z"
    return iso
```

Module-level helper; not exported. Mirror 3b-7 alerts/aeris if it had a similar helper (verify and reuse if so; otherwise add to `aeris.py`). DO NOT add to `providers/_common/datetime_utils.py` — single-caller; not yet a shared concern. Flag for DRY-extraction once 3b-11 OWM lands a similar parser (though OWM uses epoch seconds, so probably no consolidation opportunity).

**`_build_cache_key(lat, lon)`:**

```python
def _build_cache_key(lat: float, lon: float) -> str:
    """Deterministic SHA-256 over (provider_id, endpoint, {lat4, lon4}).

    Credentials NOT in key (LC7 — privacy/leakage concern).
    """
    payload = json.dumps({
        "provider_id": PROVIDER_ID,
        "endpoint": "aqi_current",
        "params": {"lat4": round(lat, 4), "lon4": round(lon, 4)},
    }, sort_keys=True)
    return hashlib.sha256(payload.encode()).hexdigest()
```

Endpoint key `"aqi_current"` distinct from any other module's endpoint key (matches 3b-9 openmeteo aqi).

**HTTP client singleton + test reset helpers:**

Same `_http_client` module-level pattern as 3b-9. `_reset_http_client_for_tests()` exposed for unit-test isolation.

### Module 2: `providers/aqi/_units.py` — ADD `ppb_to_ppm`

Append the `ppb_to_ppm()` function per LC16 at the end of the existing file. Do NOT modify `ugm3_to_ppm`, `epa_category`, or the constant tables. Module docstring updated to mention PPB → ppm conversion alongside the existing µg/m³ → ppm conversion.

### Module 3: `endpoints/aqi.py` — ADD aeris dispatch branch + extend `wire_aqi_settings`

**Dispatch addition (around line 175):**

```python
elif provider_id == "aeris":
    from weewx_clearskies_api.providers.aqi import aeris  # noqa: PLC0415

    if not _AERIS_CLIENT_ID or not _AERIS_CLIENT_SECRET:
        logger.error(
            "Aeris AQI provider configured but credentials not wired at request time"
        )
        raise HTTPException(status_code=502, detail="Aeris credentials missing")

    record = aeris.fetch(
        lat=station.latitude,
        lon=station.longitude,
        client_id=_AERIS_CLIENT_ID,
        client_secret=_AERIS_CLIENT_SECRET,
    )
```

Module-level: `_AERIS_CLIENT_ID: str | None = None` and `_AERIS_CLIENT_SECRET: str | None = None` declared at module top (mirror 3b-7 alerts/aeris).

**`wire_aqi_settings(settings)` extension:**

Currently a no-op for Open-Meteo. Add Aeris extraction:

```python
def wire_aqi_settings(settings: object) -> None:
    global _AERIS_CLIENT_ID, _AERIS_CLIENT_SECRET  # noqa: PLW0603

    if getattr(settings, "aqi", None) is None:
        return
    if settings.aqi.provider != "aeris":
        return

    # Provider-scoped credentials per 3b-4 Q1 — same [aeris] section as
    # forecast/alerts Aeris.
    aeris_section = getattr(settings, "aeris", None)
    if aeris_section is None:
        logger.error(
            "[aqi] provider = aeris but [aeris] settings section missing; "
            "credentials cannot be wired"
        )
        return

    _AERIS_CLIENT_ID = aeris_section.client_id
    _AERIS_CLIENT_SECRET = aeris_section.client_secret

    if not _AERIS_CLIENT_ID or not _AERIS_CLIENT_SECRET:
        logger.error(
            "[aqi] provider = aeris but [aeris] client_id/client_secret missing; "
            "capability still registered but /aqi/current will return 502 until wired"
        )
```

Mirror the 3b-7 alerts/aeris pattern. Don't refactor any other part of `endpoints/aqi.py`.

### Settings + capability registration

**`__main__.py` `_wire_providers_from_config()`:** extend to register `aeris.CAPABILITY` when `settings.aqi.provider == "aeris"`. Mirror the openmeteo registration shape. No new settings field needed — the `[aqi] provider` key already accepts string-typed values; the validator (if any) needs to accept `"aeris"` as a valid option alongside `"openmeteo"`.

**`config/settings.py` `AQISettings`:** the existing `provider: str | None = None` field accepts both `"openmeteo"` and `"aeris"` already (no enum constraint). If there IS a Literal constraint, extend it. No other field additions for 3b-10. Credentials reuse the existing `[aeris]` section.

## Cross-cutting requirements

### Pydantic + `Depends(_get_aqi_params)` pattern

Already wired in 3b-9. No change for 3b-10. `extra="forbid"` still fires on unknown query keys.

### RFC 9457 errors

All error paths return `application/problem+json` via existing errors.py. The canonical exception types already exist; mapping is in errors.py. No new exception types.

### Logging

`logger.info` on cache miss after wire-validation success, including `aqi=` and `mainPollutant=` and `aqiLocation=`. `logger.error` on wire-validation failures (first 2000 chars). `logger.error` also fires from LC27 envelope-error branches if `success: false`. All logs include `extra={"provider_id": "aeris", "domain": "aqi"}`.

### Catch specific exceptions

`except Exception` is forbidden. The only `except` clauses in this round catch named classes (`ValidationError, ValueError` on wire parsing). No string-based dispatch on exception messages.

### No live-network tests in CI

Unit tests use `respx` to mock the `data.api.xweather.com` host. Integration tests use captured (real or synthetic-from-docs) fixtures, never live calls. Live calls opt-in via `live_network` marker; don't run in CI.

### Capability paid-tier-max-surface rule (L1)

DOES fire. Aeris is keyed/tiered. `CAPABILITY.supplied_canonical_fields` declares the paid-tier maximum (every canonical AQI field — no documented free-vs-paid omissions on /airquality per public docs). Runtime population is conditional — if Aeris returns a response with some `pollutants[]` entries missing, those canonical fields populate as `None`.

### No new ADRs

All decisions settled by existing ADRs. If api-dev or test-author finds themselves wanting to draft an ADR change, STOP and message the lead.

### No new dependencies

Use only `pydantic`, `httpx` (via `ProviderHTTPClient`), `cachetools`/`redis-py` (via cache abstraction), `fastapi`, stdlib. No new deps.

## Test-author parallel scope

### Recorded fixture capture (L3 synthetic-from-real)

Per LC23 + the test-author agent-def "Synthetic-from-real fixture pattern when paid-tier provider access is unavailable":

**Step 1 — Attempt real capture.** Use the AERIS credentials in `.env` (env vars `WEEWX_CLEARSKIES_AERIS_CLIENT_ID` + `WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET`) against the live endpoint:

```bash
curl "https://data.api.xweather.com/airquality/47.6062,-122.3321?filter=airnow&client_id=$WEEWX_CLEARSKIES_AERIS_CLIENT_ID&client_secret=$WEEWX_CLEARSKIES_AERIS_CLIENT_SECRET"
```

**Step 2 — Inspect the response:**

- If `success: true` + non-empty `response[0].periods`: real capture succeeded. Save to `tests/fixtures/providers/aqi/aeris_current.json`. Sidecar marks as `real-capture`.
- If HTTP 401/403 OR `success: false` with `error.code` in `{invalid_client, insufficient_scope, unauthorized, forbidden_access}`: paid-tier required. Fall back to synthetic-from-docs.
- Any other error: SendMessage the lead before continuing.

**Step 3 (fallback) — Synthetic-from-docs-example.** Hand-craft `tests/fixtures/providers/aqi/aeris_current.json` from the example response in `docs/reference/api-docs/aeris.md` `### Air Quality` section. Sidecar `.md` marks as `synthetic-from-docs-example`. The docs example is realistic — PM2.5-dominant clean-air values, all six pollutant types present, both PPB and UGM3 fields populated where applicable.

**Sidecar:** `tests/fixtures/providers/aqi/aeris_current.md` documents:
- Capture date (UTC) or synthesis date.
- Source (real-capture from live endpoint vs synthetic-from-docs-example).
- Coordinates used or synthetic values.
- Full URL (real) or "n/a — synthetic".
- sha256 of the fixture body.

**SendMessage the lead** before submitting closeout naming the capture path taken + sidecar source attribution.

### Unit tests (`tests/providers/aqi/` and `tests/endpoints/`)

`tests/providers/aqi/test_units.py` — EXTEND existing file:
- `ppb_to_ppm` round-trips: known values like `O3 = 32.1 ppb → 0.0321 ppm`.
- `ppb_to_ppm(None)` returns `None`.
- (Existing `ugm3_to_ppm`, `epa_category` tests untouched.)

`tests/providers/aqi/test_aeris.py` — NEW:
- `_wire_to_canonical` happy path against the captured fixture: all canonical fields populated correctly; aqiCategory matches EPA band; aqiMainPollutant normalized to canonical id; gases in ppm (ppb/1000); particulates in µg/m³ from valueUGM3; aqiLocation = place.name.
- `_wire_to_canonical` with empty `periods` list raises IndexError (caller is `fetch` which guards via the empty check; this is a defensive unit test confirming the contract).
- `_wire_to_canonical` with empty `pollutants` list: aqi/category populate (from period.aqi), but all per-pollutant fields are None.
- `_wire_to_canonical` with `dominant: "pm1"`: aqiMainPollutant = None (drop unmappable); other fields populate normally.
- `_wire_to_canonical` with `dominant` missing/None: aqiMainPollutant = None.
- `_wire_to_canonical` with all per-pollutant `valuePPB` + `valueUGM3` null AND `aqi` null returns None.
- `_iso_offset_to_utc_z` round-trips: explicit-offset → Z-suffix UTC.
- `_iso_offset_to_utc_z` with already-UTC explicit offset (`+00:00`) emits Z.
- `_build_cache_key` deterministic + lat/lon rounding + credentials NOT in key (call with two different client_id values, assert same key — actually this is impossible since `_build_cache_key` signature doesn't take credentials; the test asserts key shape independent of credentials).
- `fetch` cache hit (canonical reconstruction from cached dict).
- `fetch` cache hit with `_no_reading` sentinel returns None.
- `fetch` cache miss happy path via `respx` mock + real (or synthetic) fixture.
- `fetch` cache miss + wire-validation failure → `ProviderProtocolError`.
- `fetch` cache miss + provider 401/403 → `KeyInvalid` (L2 propagation from `ProviderHTTPClient`).
- `fetch` cache miss + provider 429 → `QuotaExhausted` with `retry_after_seconds` preserved (L2).
- `fetch` cache miss + provider 5xx → `TransientNetworkError` (L2).
- `fetch` cache miss + `success: false, error.code = "invalid_client"` → `KeyInvalid` (LC27).
- `fetch` cache miss + `success: false, error.code = "invalid_query"` → `ProviderProtocolError` (LC27).
- `fetch` cache miss + empty `response` array → None + sentinel cached.
- `fetch` cache miss + non-empty response but `periods` empty → None + sentinel cached.

`tests/endpoints/test_aqi.py` — EXTEND existing file:
- `/aqi/current` with `aeris` registered via `wire_providers([aeris.CAPABILITY])` + credentials wired via `wire_aqi_settings()` + `respx` mock → 200 + canonical AQIReading.
- `/aqi/current` with `aeris` registered but credentials NOT wired (mock `_AERIS_CLIENT_ID = None`) → 502 with detail "Aeris credentials missing".
- `/aqi/current` with `aeris` registered + `respx` simulating provider 401 → 502 RFC 9457 (`KeyInvalid` → 502).
- `/aqi/current` with `aeris` registered + `respx` simulating provider 429 → 503 RFC 9457 + `Retry-After`.

### Integration tests (against docker-compose dev/test stack — both DB backends + both cache backends)

`tests/integration/test_aqi_aeris_integration.py` — NEW:
- Full startup with `[aqi] provider = aeris` + `[aeris]` credentials in test config.
- Fake the upstream via `respx`-on-startup-port OR by passing a test http_client into the aeris module.
- Exercise both cache backends (memory + redis).
- Assertions match the OpenAPI `AQIResponse` schema with `source: "aeris"`.

Or EXTEND `tests/integration/test_aqi_integration.py` (3b-9) with an aeris-provider variant; test-author's call which structure is cleaner.

### Schema-shape rule

Does NOT fire — AQI has no DB-schema dependency.

### Tests run on `weather-dev` BEFORE the dev submits for audit

Hard gate per the api-dev agent-def. The pull-then-pytest sequence: `git fetch origin main && git merge --ff-only origin/main && pytest`. Baseline (post-3b-9 close): 1637 passed / 41 skipped / 0 failed (default+integration combined); 19 passed / 0 failed (Redis tier). 3b-10's new tests should net-add green tests; no regression.

### Marker

Use the existing `live_network` marker for any optional live-capture test. Add no new markers. (Note: the parking-lot follow-up "register `live_network` in `pyproject.toml`" remains open — 3b-10 does NOT address it; surface in closeout if it bites.)

## Process gates

### G1 — Brief sign-off (this brief)

User reviews; teammates spawn after sign-off.

### G2 — Cross-check rule already fired + canonical amendment committed

Done at brief-draft time. Commit `a599d17` (meta repo) carries the §4.2 aeris column corrections + new footnote + api-docs/aeris.md extension. Will be pushed before teammate spawn.

### G3 — pytest green before audit

api-dev runs pytest on `weather-dev` after pull-then-merge. All new tests pass; existing 1637-test baseline not regressed. Counts surface in api-dev's closeout SendMessage.

### G4 — Audit phase

Auditor (Opus, source-only) spawned after BOTH dev + test-author submit AND pytest is green. Spawn prompt MUST name the lead's recipient name with fallbacks (`lead` → `team-lead` → `opus` → accumulate-to-closeout) per the 3b-5 through 3b-9 carry-forward of the harness addressability gap.

### G5 — Lead-synthesize per-finding

Per `rules/clearskies-process.md` "Lead synthesizes auditor findings; doesn't forward." Each finding gets accept (with remediation) / push back / defer triage. Lead-direct candidates ≤50 lines / ≤3 files.

## Anti-patterns (don't)

- Don't reach for `ugm3_to_ppm` on the Aeris path for gases. Aeris returns `valuePPB` directly; use the new `ppb_to_ppm` helper. The `valueUGM3` field for gases is supplied too but we don't need it (avoids compounded floating-point error via two-step conversion).
- Don't use `periods[].category` directly for `aqiCategory`. It's lowercase with `usg` abbreviation. Derive via `epa_category(aqi)` to match Open-Meteo's pattern.
- Don't try to map Aeris's `health.*` block to anything on canonical AQIReading. Out of scope.
- Don't add a `pollutantPM1` field. Canonical has no such field; pm1 is dropped during translation.
- Don't put credentials in the cache key. Per LC7 — privacy/leakage concern.
- Don't add a `domain=` query param. Aeris's airquality endpoint doesn't take one. The `filter` param controls AQI methodology (airnow / china / india).
- Don't try to support the `route` action. The `:id` action with lat/long in the path is the right shape per LC22.
- Don't introduce a fallback to Open-Meteo if Aeris fails. ADR-013 is single-provider-per-deploy. Failure propagates the canonical taxonomy.
- Don't extend `providers/_common/datetime_utils.py` with the `_iso_offset_to_utc_z` helper. Single-caller; not yet a shared concern. Flag for DRY-extraction once 3b-11 OWM lands a similar parser (probably won't — OWM uses epoch seconds).
- Don't refactor `endpoints/aqi.py:wire_aqi_settings` beyond adding the Aeris branch. The openmeteo no-op path stays untouched.
- Don't introduce a "current is stale" warning. Aeris's data is hourly-resolved; cache TTL is 15 min. They interact cleanly.

## Reporting back

### api-dev closeout

- Files added: `providers/aqi/aeris.py` (line count); `tests/providers/aqi/test_aeris.py` *if it lands in api-dev's scope vs test-author's* (probably test-author's).
- Files modified: `providers/aqi/_units.py` (+`ppb_to_ppm` ~10 lines), `endpoints/aqi.py` (+aeris dispatch ~20 lines, +wire_aqi_settings extension ~30 lines), `__main__.py` (+CAPABILITY registration ~5 lines), possibly `config/settings.py` (no change expected; existing `[aqi]` section + `[aeris]` section cover credentials).
- Pytest result on `weather-dev`: pass/skip/fail counts.
- L1/L2/L3 rule applications with citation in commit body.
- Surprises encountered, especially mid-round lead-call needs.

### test-author closeout

- Test files added: `tests/providers/aqi/test_aeris.py` + extensions to `test_units.py` + `test_aqi.py`.
- Integration test additions: file/section + line counts.
- Fixture captured: path + capture date + source (`real-capture` vs `synthetic-from-docs-example`) + sha256.
- Pytest result: pass/skip/fail counts.
- Coverage delta (if measured).

## Out of scope / parking lot

- OWM AQI (3b-11): paid keyed provider; adds EPA breakpoint per-pollutant table to `_units.py` for 1-5 → 0-500 conversion. Significant new code in `_units.py`.
- IQAir AQI (3b-12): first header-auth keyed provider; extends `logging/redaction_filter.py` for `X-Key` header redaction; PARTIAL-DOMAIN for most pollutants (free tier only PM2.5).
- `/aqi/history` persistence: deferred per ADR-013 §Out of scope. Endpoint still returns 501.
- Aeris's `health` block (heat index, low/moderate/high/very-high categorization): canonical has no equivalent. Out of scope.
- Aeris's per-pollutant `aqi`/`category`/`color`/`method` fields (inside each pollutants[] entry): unused. The top-level `periods[].aqi` + `dominant` are the canonical sources.
- Aeris's `route` action (multi-location): single-station per ADR-011; out of scope.
- Aeris's china/india methodologies: canonical / ADR-013 lock US EPA. Out of scope.
- Real-time AQI streaming via SSE: belongs to weewx-clearskies-realtime, not the api.
- Path A column-mapping flow: lands when ADR-035 column-mapping infrastructure does; out of scope for this round.
- Live-network marker registration in `pyproject.toml`: parking-lot follow-up from 3b-9; not in 3b-10's scope.
