# Phase 2 task 3b-13 — round brief

**Round:** 3b-13 (opens earthquakes domain)
**Drafted:** 2026-05-11
**Lead:** Opus (this session)
**Teammates:** clearskies-api-dev (Sonnet), clearskies-test-author (Sonnet)
**Auditor:** clearskies-auditor (Opus, source-only review)

## Round identity

3b-13 opens the **earthquakes** clearskies-api provider domain per [ADR-040](../../decisions/ADR-040-earthquake-providers.md). Day-1 set: `usgs` (global keyless, also the global fallback per ADR-040), `geonet` (NZ, keyless), `emsc` (EU+Mediterranean+global, keyless), `renass` (France, keyless). All four FDSN-compliant or near-equivalent GeoJSON; no API keys.

Per ADR-040 §"Single source per deploy": **operator picks ONE earthquake module at setup**, same single-provider-per-domain pattern as forecast / AQI / alerts. No multi-source aggregation, no fallback dispatch, no novel routing logic. The 3b-12 → 3b-13 resume prompt's claim of "dual-provider-per-region with USGS fallback dispatch" was wrong — this round is identical in shape to AQI / alerts opener rounds.

Structural lift in this round (NEW vs prior rounds):

1. **New canonical entity:** `EarthquakeRecord` Pydantic model in `models/responses.py` (mirrors `AlertRecord`, no unit conversion per canonical-data-model §2.4). Plus `EarthquakeList` / `EarthquakeListResponse` envelopes per OpenAPI `EarthquakeListResponse` schema.
2. **New endpoint:** `/earthquakes` per OpenAPI `getEarthquakes` operation. Mirrors `/alerts` endpoint shape (capability registry → station info → if/elif dispatch → canonical envelope). Two query params: `min_magnitude`, `radius_km` (post-cache filter); plus `from` / `to` ISO timestamps for time window.
3. **New settings section:** `[earthquakes]` with `provider` field. All four providers are keyless — no per-provider env vars.
4. **New shared helper:** `epoch_ms_to_utc_iso8601(ms)` in `providers/_common/datetime_utils.py` (USGS uses epoch milliseconds; existing `epoch_to_utc_iso8601` takes seconds).
5. **New dispatch table rows:** 4 entries in `providers/_common/dispatch.py` `PROVIDER_MODULES` dict + 4 imports.
6. **New providers/earthquakes/ package:** `__init__.py` + 4 provider modules.
7. **New params model:** `EarthquakesQueryParams` in `models/params.py`.
8. **App wiring:** register the new router in `app.py`; call `wire_earthquakes_settings()` from `__main__.py`.

This is a domain-opener round, but each individual provider module is small (keyless, simple GeoJSON parse → map). Total impl size estimate: ~1500-2000 lines across api-dev work; ~2500-3500 lines test-author work (4 providers × unit + integration + fixture each).

## Pre-round verification (lead-completed before this brief)

- ✓ api repo origin/main HEAD: `617c185` (3b-12 close).
- ✓ meta repo origin/master HEAD: `1fb5788` (3b-12 close).
- ✓ weather-dev synced to api `617c185`; both working trees clean.
- ✓ Lead-pytest-verify (per 3b-12 rule extension): full suite at `617c185` on weather-dev = **1766 passed, 311 skipped, 0 failed** (504 s). The 3b-12 → 3b-13 resume prompt's "102 pre-existing failures parking-lot" claim was wrong; baseline is fully clean. The 12 files the resume prompt named as failure-bearing all pass (1086/0). No parking-lot triage round needed.
- ✓ Cross-check rule fired (per `rules/clearskies-process.md`): 6 canonical-table mismatches surfaced for ReNaSS + GeoNet, all pre-amended into `canonical-data-model.md §4.4`, `ADR-040 References`, `EARTHQUAKE-PROVIDER-RESEARCH.md`. Per user direction 2026-05-11, ADR-040 stays Accepted (URL-only fix, no decision content change).
- ✓ Codebase-state verification: precedent module is `providers/alerts/nws.py` (keyless GeoJSON, similar shape). Existing `epoch_to_utc_iso8601(seconds)` helper at `_common/datetime_utils.py:70` is the seconds variant; sibling for ms is needed (USGS uses epoch milliseconds).
- ✓ Numerical sanity check: live USGS capture today shows `time: 1778492931604` (ms) — `datetime.fromtimestamp(1778492931604/1000, tz=UTC)` decodes to 2026-05-11 (the day the event happened, matches the live capture). Coordinate sign convention: EMSC + ReNaSS `geometry.coordinates[2]` is negative (GeoJSON Z-up); `properties.depth` is positive km below surface — brief mandates `properties.depth` everywhere.
- ✓ All four `docs/reference/api-docs/{usgs,geonet,emsc,renass}.md` written from live captures today.

## Reading list (api-dev + test-author both)

Read these in order before any code:

1. [CLAUDE.md](../../../CLAUDE.md) — domain routing + always-applicable rules.
2. [rules/clearskies-process.md](../../../rules/clearskies-process.md) — full file.
3. [rules/coding.md](../../../rules/coding.md) — full file. §1 (security), §3 (organization, dispatch on attrs not strings, DRY, no dead code).
4. `.claude/agents/clearskies-api-dev.md` (api-dev only) / `.claude/agents/clearskies-test-author.md` (test-author only) — full file.
5. [docs/decisions/ADR-040-earthquake-providers.md](../../decisions/ADR-040-earthquake-providers.md) — full file.
6. [docs/decisions/ADR-010-canonical-data-model.md](../../decisions/ADR-010-canonical-data-model.md), [ADR-017](../../decisions/ADR-017-provider-response-caching.md), [ADR-018](../../decisions/ADR-018-api-versioning-policy.md), [ADR-020](../../decisions/ADR-020-time-zone-handling.md), [ADR-027](../../decisions/ADR-027-config-and-setup-wizard.md), [ADR-038](../../decisions/ADR-038-data-provider-module-organization.md) — at least the §Decision blocks of each.
7. [docs/contracts/canonical-data-model.md](../../contracts/canonical-data-model.md) — §3.7 (EarthquakeRecord), §4.4 (provider mapping table — already amended for this round), §2.4 (earthquakes are unit-system-invariant).
8. [docs/contracts/openapi-v1.yaml](../../contracts/openapi-v1.yaml) — `/earthquakes` operation (line 296), `EarthquakeRecord` schema (line 1120), `EarthquakeListResponse` schema (line 1603).
9. [docs/reference/api-docs/usgs.md](../../reference/api-docs/usgs.md), [geonet.md](../../reference/api-docs/geonet.md), [emsc.md](../../reference/api-docs/emsc.md), [renass.md](../../reference/api-docs/renass.md) — written today; live captures verified.
10. [docs/reference/EARTHQUAKE-PROVIDER-RESEARCH.md](../../reference/EARTHQUAKE-PROVIDER-RESEARCH.md) — amended today for ReNaSS endpoint move.

**Closest precedent module for impl shape:** [`weewx_clearskies_api/providers/alerts/nws.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/nws.py) — keyless GeoJSON fetch + parse + canonical map + cache. Same shape as USGS / GeoNet / EMSC / ReNaSS. The 4 earthquake provider modules follow the same internal layout (CAPABILITY constant, wire-shape Pydantic models, `_to_canonical()` helper, `fetch()` entrypoint, cache key from station lat/lon, rate limiter).

**Closest precedent endpoint:** [`weewx_clearskies_api/endpoints/alerts.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/alerts.py). The `/earthquakes` endpoint is a near-mirror, simpler in two ways: (a) no severity-filter logic — earthquakes use `min_magnitude` instead, plain numeric comparison; (b) no per-provider credential wiring (all four are keyless), so no `wire_aeris_credentials()`-style helpers.

## Per-endpoint spec — `/earthquakes`

OpenAPI source: [`docs/contracts/openapi-v1.yaml`](../../contracts/openapi-v1.yaml) lines 296-328 (`getEarthquakes` operation) + 1120-1165 (`EarthquakeRecord` schema) + 1603-1611 (`EarthquakeListResponse` schema).

### Behavior decision tree

Mirrors `/alerts` (endpoints/alerts.py L1-44):

1. No earthquakes provider in capability registry → `200`, `data: []`, `source: "none"`.
2. Provider configured, returns 200 + empty features → `200`, `data: []`, `source: <provider_id>`.
3. Provider configured, returns 200 + features → normalize, filter by `min_magnitude` and `radius_km`, return `200`.
4. Network failure / 5xx after retries → `502 ProviderProblem` (TransientNetworkError).
5. Provider returns 429 → `503 ProviderProblem` (QuotaExhausted) + `Retry-After`.
6. Provider returns 401/403 → `502 ProviderProblem` (KeyInvalid; should not fire for keyless providers but the canonical taxonomy carries it).
7. Pydantic validation failure on wire model → `502 ProviderProblem` (ProviderProtocolError).

### Query parameters

Per OpenAPI:
- `from` — ISO 8601 timestamp; lower bound on event time (`time >= from`). Optional.
- `to` — ISO 8601 timestamp; upper bound on event time (`time < to`). Optional.
- `min_magnitude` — number ≥ 0; filter to events at or above this magnitude. Optional.
- `radius_km` — number ≥ 0; override the operator-configured radius (km from station lat/lon). Optional; falls back to settings default.

The Pydantic+Depends pattern from `endpoints/alerts.py:_get_alerts_params` is mandatory — `extra="forbid"` must fire for unknown query keys (per `rules/coding.md` §1 "Pydantic `extra="forbid"` requires the right FastAPI wiring"). Add `EarthquakesQueryParams` to `models/params.py` mirroring `AlertsQueryParams`.

### Filter ordering (post-cache)

Cache stores the **full** canonical list returned by the provider for the configured radius (one entry per station, keyed by `(provider_id, endpoint, lat, lon, radius_km, from, to)`). `min_magnitude` filtering runs in the endpoint handler **after** cache lookup — same pattern as alerts severity filter (per ADR-017 §Cache key).

### Operator radius default

Add `default_radius_km` to `EarthquakesSettings` (default value: `100`). Operator overrides via `[earthquakes] default_radius_km = 250` in api.conf. The `?radius_km=` query param overrides the configured default per request.

### Dispatch shape

`if/elif` chain mirroring `endpoints/alerts.py:get_alerts` lines 244-273. All four providers are keyless, so `fetch()` signatures are uniform: `fetch(*, lat: float, lon: float, radius_km: float, from_dt: datetime | None, to_dt: datetime | None) -> list[EarthquakeRecord]`. **Do NOT** wire credential params; do NOT add per-provider `wire_*_credentials()` functions (there are no credentials).

## Per-provider impl — module shape

All four modules follow the `providers/alerts/nws.py` template:

- `PROVIDER_ID` / `DOMAIN` / `BASE_URL` / `PATH` module constants.
- `_<PROVIDER>_CACHE_TTL` constant — 60 s (the realtime feeds update every ~minute).
- `CAPABILITY = ProviderCapability(...)` symbol — `domain="earthquakes"`, `auth_required=()`, `geographic_coverage` per the §"Geographic coverage" column in canonical-data-model §4.4.
- `_rate_limiter = RateLimiter(...)` — 5 req/s polite-use guard.
- Wire-shape Pydantic models (`_<Provider>EventProperties`, `_<Provider>EventFeature`, `_<Provider>Response`) — `extra="ignore"` so upstream additions don't break us; missing required fields → `ValidationError → ProviderProtocolError`.
- `_to_canonical(props: _<Provider>EventProperties) -> EarthquakeRecord` — applies the §4.4 mapping for that provider. **All extras keys passed through verbatim** under `EarthquakeRecord.extras` per ADR-040 §Canonical fields.
- `fetch(*, lat, lon, radius_km, from_dt, to_dt) -> list[EarthquakeRecord]` — public entrypoint.
- `_build_cache_key(...)` — SHA-256 of `(PROVIDER_ID, PATH, params)` per ADR-017.
- Cache stores list of `EarthquakeRecord.model_dump()` dicts (JSON-serialisable for Redis); on cache hit, reconstruct via `EarthquakeRecord.model_validate()`.

### Per-provider mapping cells (from canonical-data-model §4.4 — already amended)

#### usgs

- Endpoint: `https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson`
- Query params for radius lookup: `latitude`, `longitude`, `maxradiuskm`, `starttime`, `endtime`, `minmagnitude`, `orderby=time`. **Note USGS-specific names** (`minmagnitude`, `maxradiuskm`) — differ from EMSC/ReNaSS (`minmag`, `maxradius`).
- Time conversion: `properties.time` is **epoch milliseconds**. Use the new `epoch_ms_to_utc_iso8601()` helper in `_common/datetime_utils.py` (see §"New shared infrastructure" below).
- Tsunami conversion: `properties.tsunami` is `0` or `1` integer; cast to `bool` at canonical mapping (`bool(props.tsunami)`).
- Depth source: `geometry.coordinates[2]` — USGS uses positive km below surface in coordinates (no sign flip needed).
- `id`: top-level `Feature.id`.
- Geographic coverage capability: `"global"`.

#### geonet

- Endpoint: `https://api.geonet.org.nz/quake?MMI=<n>`
- **Required `MMI` query param** — pass `MMI=-1` to get all events (operator radius filter is applied at the canonical layer post-fetch since GeoNet doesn't accept lat/lon/radius params).
- Time: `properties.time` is ISO 8601 string with Z suffix — use `to_utc_iso8601_from_offset()` to normalize (Z-suffix is treated as +00:00 by `datetime.fromisoformat`).
- Depth source: `properties.depth` (positive km).
- `id`: `properties.publicID` (no top-level Feature.id).
- `magnitudeType`: not provided; canonical leaves as `None` per §4.4.
- `mmi` field is **lowercase** in the response — confirmed live 2026-05-11. The §4.4 cell was previously documented as `MMI` (uppercase); amended this round.
- `url`: not in response; construct as `f"https://www.geonet.org.nz/earthquake/{props.publicID}"`.
- Geographic coverage capability: `"nz"`.

#### emsc

- Endpoint: `https://www.seismicportal.eu/fdsnws/event/1/query?format=json`
- Query params: `lat`, `lon`, `maxradiuskm`, `starttime`, `endtime`, `minmag`, `orderby=time`. **EMSC uses `minmag` not `minmagnitude`.**
- Time: `properties.time` is ISO 8601 with Z (sometimes 6-decimal microseconds). `to_utc_iso8601_from_offset()` handles both.
- Depth source: `properties.depth` (positive). **Do NOT use `geometry.coordinates[2]`** — that's negative (GeoJSON Z-up convention).
- `id`: top-level `Feature.id` (or `properties.unid`; identical values — pick `Feature.id` for consistency with USGS/ReNaSS).
- `place`: `properties.flynn_region`.
- `magnitudeType`: `properties.magtype` (lowercase — differs from USGS/ReNaSS camelCase).
- `status`: not in JSON flavor; route via `extras` per §4.4.
- `url`: not in response; construct as `f"https://www.seismicportal.eu/eventdetails.html?unid={props.unid}"`.
- Extras keys per §4.4: `evtype`, `auth`, `source_id`, `source_catalog`, `lastupdate`.
- Geographic coverage capability: `"eu"` (with global supplementary; primary use is EU+Mediterranean).

#### renass

- Endpoint: `https://api.franceseisme.fr/fdsnws/event/1/query?format=json` (NEW URL — legacy `https://renass.unistra.fr/fdsnws/event/1/query` returns 404; verified 2026-05-11).
- Query params: `latitude`, `longitude`, `maxradius` (degrees) or `maxradiuskm` (km), `starttime`, `endtime`, `minmag`, `orderby=time`.
- Time: `properties.time` is ISO 8601 with Z (microsecond precision). `to_utc_iso8601_from_offset()` handles it.
- Depth source: `properties.depth` (positive). **Do NOT use `geometry.coordinates[2]`.**
- `id`: top-level `Feature.id` (no `properties.publicID` / `properties.unid`).
- `place`: `properties.description.en` — bilingual `{fr, en}` object; canonical takes `.en`.
- `url`: `properties.url.en` — bilingual `{fr, en}` object; canonical takes `.en`.
- `magnitudeType`: `properties.magType` (camelCase like USGS, NOT EMSC's lowercase).
- `status`: derived from `properties.automatic` boolean — `true → "automatic"`, `false → "reviewed"`.
- Extras keys per §4.4 (amended this round): `type`, `description.fr`, `url.fr`. Note: route the *whole* `description` object's `.fr` half to `extras["description_fr"]` (and same for url) — flat string keys in the extras dict, not nested.
- Geographic coverage capability: `"fr"` (mainland France + neighbours).

### Wire-shape Pydantic notes

For each module:

- The `_<Provider>EventProperties` Pydantic model declares ONLY the canonical-bearing fields + extras-bound fields. Use `model_config = ConfigDict(extra="allow")` so the extras dict can be populated from the model — OR use `model_config = ConfigDict(extra="ignore")` and let `_to_canonical` reach into the raw dict directly for extras population. **Lead-resolved choice: `extra="ignore"` on the wire-shape Pydantic; `_to_canonical` takes both the parsed model (for typed access to canonical fields) and the raw dict (for extras population).** This matches the project precedent in `providers/forecast/openweathermap.py` and is more explicit about which fields are canonical-bound.
- Required-field rules: a missing required field must raise `ValidationError → ProviderProtocolError`. Canonical-required fields per OpenAPI: `id, time, latitude, longitude, magnitude, source`. Provider-side: any field the §4.4 mapping cell maps a canonical-required field from must be `required=True` on the wire model.
- For ReNaSS bilingual objects: declare `description: dict[str, str] | None = None` and `url: dict[str, str] | None = None` on the wire model; the `_to_canonical` reads `.get("en")` from each.

## New shared infrastructure (api-dev's responsibility)

### `EarthquakeRecord` + `EarthquakeList` + `EarthquakeListResponse` (models/responses.py)

Add at the bottom of `models/responses.py` after the AQI block. Mirror AlertRecord:

```python
# ruff: noqa: N815  (camelCase canonical names: magnitudeType, etc.)


class EarthquakeRecord(BaseModel):
    """Canonical earthquake record (ADR-010 §3.7, OpenAPI EarthquakeRecord schema).

    extra="ignore" so provider wire shapes that have extra fields don't break
    normalization.  Required fields per OpenAPI: id, time, latitude, longitude,
    magnitude, source.
    """

    model_config = ConfigDict(extra="ignore")

    id: str
    time: str  # UTC ISO-8601 with Z
    latitude: float
    longitude: float
    magnitude: float
    magnitudeType: str | None = None
    depth: float | None = None
    place: str | None = None
    url: str | None = None
    tsunami: bool | None = None
    felt: int | None = None
    mmi: float | None = None
    alert: str | None = None  # green/yellow/orange/red (USGS PAGER); None for non-USGS
    status: str | None = None
    extras: dict[str, Any] = Field(default_factory=dict)
    source: str


class EarthquakeListResponse(BaseModel):
    """EarthquakeListResponse envelope (OpenAPI EarthquakeListResponse schema).

    Note: OpenAPI EarthquakeListResponse does NOT carry a units block (per
    canonical-data-model §2.4, earthquakes are unit-system-invariant).
    """

    model_config = ConfigDict(extra="ignore")

    data: list[EarthquakeRecord]
    source: str  # provider_id or "none"
    generatedAt: str  # UTC ISO-8601 with Z
```

### `EarthquakesQueryParams` (models/params.py)

Mirror `AlertsQueryParams`. Validate `from` / `to` as parseable ISO 8601; validate `min_magnitude` / `radius_km` as non-negative numbers. `extra="forbid"`.

```python
class EarthquakesQueryParams(BaseModel):
    """Query params for /earthquakes (OpenAPI getEarthquakes operation).

    extra="forbid" so unknown query keys reject with 422 per security-baseline §3.5.
    """

    model_config = ConfigDict(extra="forbid")

    from_: str | None = Field(None, alias="from")
    to: str | None = None
    min_magnitude: float | None = Field(None, ge=0)
    radius_km: float | None = Field(None, ge=0)
```

### `EarthquakesSettings` (config/settings.py)

Add after `AQISettings`. All four providers are keyless — no env-var loading.

```python
class EarthquakesSettings:
    """[earthquakes] section settings (3b-13).

    Provider id for the earthquake data source.  All four day-1 providers (usgs,
    geonet, emsc, renass) are keyless — no env vars needed.

    Per ADR-040: single earthquake provider per deploy.  No multi-provider
    fallback or aggregation.
    """

    #: Provider id: "usgs", "geonet", "emsc", "renass", or absent.
    provider: str | None
    #: Default radius in km from station lat/lon.  Override per-request via ?radius_km.
    default_radius_km: float

    def __init__(self, section: dict[str, Any]) -> None:
        raw_provider = str(section.get("provider", "")).strip()
        self.provider = raw_provider if raw_provider else None

        raw_radius = section.get("default_radius_km", 100)
        try:
            self.default_radius_km = float(raw_radius)
        except (TypeError, ValueError) as exc:
            raise ValueError(
                f"[earthquakes] default_radius_km {raw_radius!r} must be a number."
            ) from exc
        if self.default_radius_km < 0:
            raise ValueError(
                f"[earthquakes] default_radius_km {self.default_radius_km!r} must be >= 0."
            )

    def validate(self) -> None:
        valid_providers = {"usgs", "geonet", "emsc", "renass"}
        if self.provider is not None and self.provider not in valid_providers:
            raise ValueError(
                f"[earthquakes] provider {self.provider!r} not in {valid_providers}. "
                "Supported values: 'usgs', 'geonet', 'emsc', 'renass'."
            )
```

Wire `earthquakes_cfg = EarthquakesSettings(dict(cfg.get("earthquakes", {})))` in the loader; add `earthquakes: EarthquakesSettings` to the top-level `Settings` class; add to its `validate()`.

### `epoch_ms_to_utc_iso8601` (providers/_common/datetime_utils.py)

Sibling to existing `epoch_to_utc_iso8601(seconds)`. Per `rules/coding.md` §3 DRY — searched for existing ms helper, none found.

```python
def epoch_ms_to_utc_iso8601(
    epoch_ms: int | float,
    *,
    provider_id: str,
    domain: str,
) -> str:
    """Convert epoch UTC milliseconds to ISO-8601 Z form (ADR-020).

    USGS earthquake feed uses milliseconds-since-epoch for the `time` and
    `updated` fields (the GeoJSON flavor only — the QuakeML flavor uses ISO).
    Sibling to ``epoch_to_utc_iso8601`` which takes seconds.

    Numerical sanity check: USGS event id us6000swvm has time=1778492931604 ms;
    1778492931604 / 1000 = 1778492931.604 s; datetime.fromtimestamp(...)
    decodes to 2026-05-11 (matches the day the event happened).

    Args:
        epoch_ms: Unix timestamp in milliseconds since 1970-01-01T00:00:00Z.
        provider_id: Provider identifier (e.g. ``"usgs"``).
        domain: Provider domain (e.g. ``"earthquakes"``).

    Returns:
        UTC ISO-8601 string with Z suffix.

    Raises:
        ProviderProtocolError: ``epoch_ms`` is out of platform range, non-numeric,
            or otherwise unparsable.
    """
    try:
        seconds = epoch_ms / 1000.0
        dt = datetime.fromtimestamp(seconds, tz=UTC)
    except (OverflowError, ValueError, OSError, TypeError) as exc:
        raise ProviderProtocolError(
            f"Epoch ms parse failed for {epoch_ms!r}: {exc}",
            provider_id=provider_id,
            domain=domain,
        ) from exc
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
```

### `providers/_common/dispatch.py` updates

Add 4 imports + 4 dict rows. Update the docstring's domain-summary line to add: `"Earthquakes domain: usgs, geonet, emsc, renass (3b-13 — domain opener; all keyless per ADR-040)."`.

### `providers/earthquakes/__init__.py`

New file. Keep minimal (matches `providers/aqi/__init__.py` pattern). Module docstring naming the domain + ADR-040 reference.

### `endpoints/earthquakes.py`

New file. Mirror `endpoints/alerts.py` structure. Specific differences:

- No `wire_*_credentials()` functions (keyless).
- `wire_earthquakes_settings(settings)` extracts `default_radius_km` from `settings.earthquakes` and stores in module-level `_default_radius_km`.
- `_get_earthquakes_params(request: Request)` Depends wrapper.
- `_filter_by_magnitude(records, min_magnitude)` post-cache helper (mirrors `_filter_by_severity`).
- Dispatch chain: `if provider_id == "usgs": ...` etc. for all four.

### `app.py` + `__main__.py` wiring

- `app.py`: import the new `earthquakes` router from `endpoints.earthquakes` and `app.include_router(earthquakes.router)`.
- `__main__.py`: call `wire_earthquakes_settings(settings)` after the existing `wire_alerts_settings` / `wire_aqi_settings` calls; call `wire_providers([...CAPABILITY])` chain to register the configured earthquakes provider's CAPABILITY in the registry (mirror what alerts/aqi already do — consult `_wire_providers_from_config()`).

## Lead-resolved calls (no user sign-off; trivial implementation choices)

1. **Wire-shape Pydantic `extra="ignore"` + raw-dict for extras population** — see "Wire-shape Pydantic notes" above. Matches forecast/openweathermap.py precedent.
2. **`EarthquakeRecord.extras: dict[str, Any]`** — matches the `Observation.extras` shape declared in `models/responses.py`. JSON-serialisable values only (the wire-shape may carry nested dicts; flatten where helpful or pass through if downstream consumers don't choke).
3. **`_<PROVIDER>_CACHE_TTL = 60` (seconds)** — earthquake feeds update every ~minute. ADR-040 declines to fix a domain default; per-module choice. 60 s is the aggressive end of polite-use; if a future operator hits rate-limit issues, bump per-module.
4. **GeoNet `MMI=-1` to fetch all events** — operator radius filter applies post-fetch (GeoNet doesn't accept lat/lon/radius params). All other providers do server-side radius filtering.
5. **ReNaSS extras `description.fr` → `extras["description_fr"]`, `url.fr` → `extras["url_fr"]`** — flat string keys, not nested. Matches the `extras` JSON-friendly contract.
6. **EMSC + ReNaSS `id` source = top-level `Feature.id`** (not `properties.unid` / nothing for ReNaSS). Consistent with USGS pattern.
7. **`_<Provider>Response` Pydantic models follow GeoJSON FeatureCollection shape** — `type: Literal["FeatureCollection"]`, `features: list[_<Provider>Feature]`. EMSC adds `metadata: dict | None = None`; allow as optional.
8. **Cache key includes `radius_km` and `from_dt` / `to_dt`** — different radii return different result sets; cache keys must distinguish.

## User-resolved calls (sign-off 2026-05-11)

**Q1 — Geographic-coverage capability strings.** User approved lead-recommended set as-is:
- usgs: `"global"`
- geonet: `"nz"`
- emsc: `"global, primary in eu+mediterranean"`
- renass: `"fr"`

These feed the Phase-4 setup-wizard recommendation engine.

**Q2 — Cache TTL.** User approved **60 s** for all four earthquake provider modules. Prioritize freshness over polite-use traffic reduction; override per-module if operators report rate-limit issues.

## Process gates

- **Pull-then-pytest before submit (api-dev):** `git fetch origin main && git merge --ff-only origin/main && pytest -m "not live_network"` BEFORE submitting closeout. Per `rules/clearskies-process.md` "Audit modes are complementary." Per `.claude/agents/clearskies-api-dev.md` hard constraints.
- **Lead-pytest-verify (3b-12 rule extension):** at Step H gate, lead independently re-runs the same pytest command from a fresh shell on weather-dev. Trust no teammate's pass/fail count without independent verify.
- **Spawn-prompt explicit constraints (3b-12 lessons not codified but worth repeating):**
  - api-dev: scope is impl + integration tests for that impl. **Do NOT write standalone unit test files** — that's test-author's exclusive surface (3b-12 F2 root cause: api-dev wrote 850-line FLAT-pattern duplicate unit-test file).
  - api-dev: **do NOT touch meta repo files** (CLAUDE.md, plan, ADRs, contracts) — that's the lead's surface (3b-12 P1 root cause: api-dev wrote the plan-status close commit prematurely).
  - test-author: when lowering a test to accept a known-buggy impl during the bug-fix window, mark with `# TODO TIGHTEN AFTER FIX` in code so the lead/auditor catches it post-fix (3b-12 F1 root cause).
  - All teammates: SendMessage cadence floor (~4 minutes); commit early and often; status updates at every milestone.

## Test surface (test-author scope)

For each of the four providers, write three test artifacts. Tests under `tests/`:

1. **Real-capture fixture** at `tests/fixtures/providers/earthquakes/<provider>_<scenario>.json` — captured today via the same curl commands the api-docs files document. Sidecar `<provider>_<scenario>.md` (e.g. `usgs_solomon_islands_m5_2.md`) documents source URL + capture date + fixture-derivation rationale per the existing project precedent.
2. **Unit tests** at `tests/providers/earthquakes/test_<provider>.py` (NESTED layout — match the `tests/providers/aqi/test_*.py` pattern, NOT the FLAT layout that 3b-12 surfaced as wrong). Cover: `_to_canonical()` mapping for every field; fetch happy-path with cache-miss + cache-hit + Redis fakeredis; ProviderProtocolError on invalid wire shape; rate limiter integration.
3. **Integration tests** at `tests/test_providers_earthquakes_<provider>_integration.py` (FLAT layout for cross-module integration tests — matches existing `test_providers_alerts_*_integration.py` pattern). Cover: full fetch path (real fixtures via `respx`-mocked HTTP), MariaDB cache backend dual-coverage per ADR-012 dialect-coverage rule.

Plus one endpoint-level test file at `tests/test_providers_earthquakes_endpoint.py` covering the seven decision-tree branches (mirrors `test_providers_alerts_endpoint.py`).

**No live_network tests** in CI — `live_network` marker isn't registered in `pyproject.toml` (parking-lot from 3b-9; not blocking this round). Real-capture is one-shot at fixture-capture time, then fixtures replay via `respx`.

**No paid-tier synthetic-from-real fixture pattern needed** (per `.claude/agents/clearskies-test-author.md`) — all four providers are free + keyless. Real captures suffice for every test path.

**No `live_network` marker registration in this round** (parking-lot). Brief flags this for a future round.

### Pytest baseline coverage

The round must finish with `pytest -m "not live_network"` showing **zero new failures vs the pre-round baseline of 1766 passed / 311 skipped / 0 failed** (verified today on weather-dev at HEAD `617c185`). New tests add to passed-count; skipped-count may grow if new tests intentionally skip in environments without Redis.

## Out of scope (intentionally not in this round)

- Multi-source aggregation (Phase 6+ per ADR-040).
- Push notifications for nearby quakes (Phase 6+ per ADR-040).
- User-defined alert thresholds (Phase 6+ per ADR-040).
- Tsunami advisories beyond the USGS `tsunami` flag (Phase 6+ per ADR-040).
- `/earthquakes/{id}` single-event endpoint (not in OpenAPI; out of v0.1).
- Live-network test marker registration (parking-lot from 3b-9).
- Earthquake page UI (clearskies-dashboard work, not api).
- Setup wizard recommendation engine (Phase 4 dashboard / config UI work).
- Pre-existing ruff violations cleanup (parking-lot).

## Round-close checklist (lead's responsibility)

1. Lead-pytest-verify both teammate claims (per 3b-12 rule extension).
2. Spawn auditor (Opus, source-only); auditor recipient name explicit in spawn prompt with fallbacks (per the addressability-gap workaround that's fired 7+ rounds running).
3. Lead synthesizes audit findings — accept, push back, or defer per finding (per "Lead synthesizes auditor findings; doesn't forward" rule).
4. Lead-direct remediation if surface ≤ ~50 lines / ≤ 3 files (per "Lead-direct remediation when the surface is small").
5. Lessons triage at round close per CLAUDE.md "Capture lessons in the right place" — only rules for things the existing process didn't catch; default to decision-log-only; fold into existing rules where possible (per durable user direction).
6. Plan-status commit on meta repo — mark 3b-13 closed; queue 3b-14.
7. Queue next-round resume prompt at `c:\tmp\3b-14-resume-prompt.md`.
