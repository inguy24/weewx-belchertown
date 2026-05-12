# Phase 2 task 3b-14 — round brief

**Round:** 3b-14 (opens radar domain — keyless half)
**Drafted:** 2026-05-11
**Lead:** Opus (this session)
**Teammates:** clearskies-api-dev (Sonnet), clearskies-test-author (Sonnet)
**Auditor:** clearskies-auditor (Opus, source-only review)

## Round identity

3b-14 opens the **radar** clearskies-api provider domain per [ADR-015](../../decisions/ADR-015-radar-map-tiles-strategy.md) + [ADR-037](../../decisions/ADR-037-inbound-traffic-architecture.md). Scope for this round: **5 keyless providers + `/radar/providers/{provider_id}/frames` endpoint**. Per user choice 2026-05-11 (Option A) — 3 keyed providers + tile proxy deferred to 3b-15; iframe slot deferred to 3b-16.

Day-1 keyless set (this round):

- `rainviewer` — global, slippy XYZ tiles, JSON frame index.
- `iem_nexrad` — US CONUS, WMS-T, GetCapabilities frame index.
- `noaa_mrms` — US AK/HI/PR/Guam/Caribbean, WMS-T, GetCapabilities frame index.
- `msc_geomet` — Canada, WMS-T, GetCapabilities frame index.
- `dwd_radolan` — Germany, WMS-T, GetCapabilities frame index.

**Structural realities new this round** (compared to 3b-13 earthquakes):

1. **No canonical-entity mapping.** Radar tiles are bytes — no `EarthquakeRecord`-style normalization. Per canonical-data-model §4.5 + ADR-015. `supplied_canonical_fields=()` for all radar providers.
2. **TWO module patterns, not one.** `rainviewer` uses slippy XYZ + JSON frame index; the 4 WMS-T providers share a different frame-index-getter shape (parse `<Dimension name="time">` from WMS GetCapabilities XML). Means 5 provider modules but only **2 precedent shapes** — not 5.
3. **Multi-provider per domain.** Unlike forecast/alerts/aqi/earthquakes (single-source-per-deploy), the dashboard renders the operator's region radar based on lat/lon. **For v0.1, single-source-per-deploy still applies** per ADR-015's setup flow — operator picks one provider for their lat/lon. Per-region auto-pick is a setup-wizard concern (out of scope this round).
4. **Provider returns no fetched data to the api endpoint for tile bytes** — keyless providers' tile URLs are fetched directly by the browser. The api's job here is (a) the FRAME INDEX endpoint and (b) the CAPABILITY declaration that publishes the tile URL template + content type for browser-side composition.
5. **`ProviderCapability` dataclass needs optional radar fields.** Per ADR-038 line 86 ("capability declaration adds a `tile_format` field for the radar domain"). Adding `tile_url_template: str | None = None`, `tile_content_type: str | None = None` as optional kwargs. Non-radar providers continue to leave these as None.

Total impl estimate: ~1500-2000 lines api-dev work; ~2500-3500 lines test-author work. Comparable to 3b-13.

## Pre-round verification (lead-completed before this brief)

- ✓ api repo origin/main HEAD: `ecd7e75` (resume-prompt expected `42843c0`; 2 more audit-fix commits landed — F1 ISO-8601 validation, F2 dead-code defense — both preserve test counts).
- ✓ meta repo origin/master HEAD: `f961b67` (3b-13 close).
- ✓ weather-dev synced to api `ecd7e75`; both working trees clean.
- ✓ Lead-pytest-verify on weather-dev at `ecd7e75`: **1954 passed, 364 skipped, 36 warnings, 0 failed** in 505s (matches 3b-13 baseline exactly).
- ✓ Cross-check rule fired (per `rules/clearskies-process.md`): no canonical-table mismatches surfaced — radar has no canonical-entity mapping in §4.5, so the cross-check pass reduces to "does each api-doc file match its provider's documented endpoint + content type?" — all 5 verified against live JSON/docs today.
- ✓ Codebase-state verification: precedent for new-domain wiring is the **earthquakes** package (3b-13). Endpoint precedent (simpler shape — no station-lat/lon dependency for frame index) is **alerts/earthquakes** style without the if/elif provider dispatch in the endpoint (because radar's frame index is per-provider-path, not a single-provider lookup).
- ✓ All 5 `docs/reference/api-docs/{rainviewer,iem_nexrad,noaa_mrms,msc_geomet,dwd_radolan}.md` written today from live verification (rainviewer live JSON) + provider documentation (4 WMS-T services).

## Reading list (api-dev + test-author both)

In order, before any code:

1. [CLAUDE.md](../../../CLAUDE.md) — domain routing + always-applicable rules.
2. [rules/clearskies-process.md](../../../rules/clearskies-process.md) — full file.
3. [rules/coding.md](../../../rules/coding.md) — §1 (security), §3 (organization, DRY, dead code).
4. `.claude/agents/clearskies-api-dev.md` / `.claude/agents/clearskies-test-author.md` — agent-specific.
5. [docs/decisions/ADR-015-radar-map-tiles-strategy.md](../../decisions/ADR-015-radar-map-tiles-strategy.md) — full file.
6. [docs/decisions/ADR-037-inbound-traffic-architecture.md](../../decisions/ADR-037-inbound-traffic-architecture.md) — §Decision + §Implementation guidance (where it states keys never leak to browser; keyless = direct browser fetch).
7. [docs/decisions/ADR-038-data-provider-module-organization.md](../../decisions/ADR-038-data-provider-module-organization.md) — §Decision (esp. line 86 — radar tile_format field anticipated).
8. [docs/decisions/ADR-017-provider-response-caching.md](../../decisions/ADR-017-provider-response-caching.md) §Decision — applies to frame-index responses (small, low-TTL).
9. [docs/decisions/ADR-027-config-and-setup-wizard.md](../../decisions/ADR-027-config-and-setup-wizard.md) §Decision — `[radar]` settings section follows existing pattern.
10. [docs/contracts/canonical-data-model.md](../../contracts/canonical-data-model.md) §4.5 (radar — confirms no canonical-entity mapping).
11. [docs/contracts/openapi-v1.yaml](../../contracts/openapi-v1.yaml) — `/radar/providers/{provider_id}/frames` (lines 639-656), `RadarFrame` (1482-1489), `RadarFrameList` (1491-1499), `RadarFramesResponse` (1691-1696), `CapabilityDeclaration` (1432-1448).
12. Per-provider api-docs (written today): [rainviewer.md](../../reference/api-docs/rainviewer.md), [iem_nexrad.md](../../reference/api-docs/iem_nexrad.md), [noaa_mrms.md](../../reference/api-docs/noaa_mrms.md), [msc_geomet.md](../../reference/api-docs/msc_geomet.md), [dwd_radolan.md](../../reference/api-docs/dwd_radolan.md).

**Closest precedent module for shape:** none of the existing providers cleanly precedent radar's no-canonical-entity shape. The closest **shape** precedent for module structure (CAPABILITY constant, module constants, cache wiring, error taxonomy use, rate limiter) is [`weewx_clearskies_api/providers/alerts/nws.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/nws.py); the closest **endpoint** precedent for "endpoint reads registry, dispatches by provider_id, returns response model" is [`weewx_clearskies_api/endpoints/earthquakes.py`](../../../repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/earthquakes.py) — but radar's endpoint is simpler (no station-lat/lon, no filter params, path-param dispatch instead of registry single-pick).

## Per-endpoint spec — `/radar/providers/{provider_id}/frames`

OpenAPI source: `docs/contracts/openapi-v1.yaml` lines 639-656.

### Behavior decision tree

1. `provider_id` is not in the radar dispatch table → `404 Problem`.
2. `provider_id` IS in dispatch but is NOT registered in the capability registry → `404 Problem` (operator configured a different provider). Distinguished from #1 only in problem `detail` text; both 404.
3. Provider configured + registered, frame-index fetch succeeds → `200 RadarFramesResponse` with the list.
4. Frame-index fetch returns network failure / 5xx after retries → `502 ProviderProblem` (TransientNetworkError).
5. Frame-index fetch returns 429 → `503 ProviderProblem` (QuotaExhausted) + `Retry-After`.
6. Frame-index parse failure (JSON malformed / GetCapabilities XML missing TIME dimension) → `502 ProviderProblem` (ProviderProtocolError).

### Path parameters

- `provider_id`: required, lowercase string, one of the 5 keyless radar providers.

### Query parameters

None this round. (Future: maybe `?since=<iso>` to limit to recent frames. Out of scope.)

### Response shape

`RadarFramesResponse` per OpenAPI:
```
{
  "data": {
    "providerId": "rainviewer",
    "frames": [
      {"time": "2026-05-11T16:30:00Z", "kind": "past"},
      …
      {"time": "2026-05-11T17:50:00Z", "kind": "current"}
    ],
    "attribution": "RainViewer (https://www.rainviewer.com/)"
  },
  "generatedAt": "2026-05-11T18:00:00Z"
}
```

### Dispatch

In `endpoints/radar.py`, path-param `provider_id` selects the provider module via `get_provider_module(domain="radar", provider_id=<id>)` (from `_common/dispatch.py` — extended this round with 5 new rows). Each radar module exposes `get_frames() -> RadarFrameList` (NOT `fetch()` — different shape from data providers).

### Caching (ADR-017)

Frame index responses are tiny (~1-5 KB), update every 5-10 min depending on provider. Cache key: SHA-256 of `(provider_id, "frames")`. No lat/lon component — frame index is per-provider, not per-station. TTL: **60s** (frames roll forward every 5-10 min; 60s cache is fresh enough). Same `get_cache()` infrastructure as 3b-13.

**Cache serialization:** `RadarFrameList` is a Pydantic model — store via `frames_list.model_dump(mode="json")` (returns a dict with ISO-8601 strings already serialized) and reconstruct on read via `RadarFrameList.model_validate(cached_dict)`. Same pattern as `EarthquakeRecord` caching in 3b-13. Do NOT cache the raw Pydantic instance (Redis JSON-serializes to string; the dict form is the canonical cache shape).

## Per-provider impl — module shape

All five modules go in `weewx_clearskies_api/providers/radar/`:

- `__init__.py` (empty).
- `rainviewer.py` (XYZ + JSON frame index).
- `iem_nexrad.py` (WMS-T + GetCapabilities frame index).
- `noaa_mrms.py` (WMS-T + GetCapabilities frame index).
- `msc_geomet.py` (WMS-T + GetCapabilities frame index).
- `dwd_radolan.py` (WMS-T + GetCapabilities frame index).

### Module-level constants (every provider)

```python
PROVIDER_ID = "rainviewer"
DOMAIN = "radar"
BASE_URL = "https://api.rainviewer.com"
FRAMES_PATH = "/public/weather-maps.json"  # or WMS GetCapabilities path for WMS-T providers
_CACHE_TTL = 60
```

### CAPABILITY shape

**XYZ slippy provider (rainviewer):**
```python
CAPABILITY = ProviderCapability(
    provider_id=PROVIDER_ID,
    domain=DOMAIN,
    supplied_canonical_fields=(),                          # radar has no canonical-entity mapping
    geographic_coverage="global",
    auth_required=(),
    default_poll_interval_seconds=_CACHE_TTL,
    operator_notes="Free for personal/educational use; attribution: https://www.rainviewer.com/",
    tile_url_template="{host}{path}/256/{z}/{x}/{y}/2/1_1.png",  # {host}+{path} resolved from frame-index JSON per request
    tile_content_type="image/png",
)
```

**WMS-T provider (e.g. iem_nexrad):**
```python
CAPABILITY = ProviderCapability(
    provider_id=PROVIDER_ID,
    domain=DOMAIN,
    supplied_canonical_fields=(),
    geographic_coverage="us-conus",
    auth_required=(),
    default_poll_interval_seconds=_CACHE_TTL,
    operator_notes="NEXRAD imagery courtesy of Iowa Environmental Mesonet.",
    wms_endpoint_url="https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0q-t.cgi?",
    wms_layer_name="nexrad-n0q-wmst",
    tile_content_type="image/png",
)
```

### Frame-index getter — two shapes

**rainviewer (JSON):**

```python
def get_frames() -> RadarFrameList:
    cache = get_cache()
    key = _cache_key()
    hit = cache.get(key)
    if hit is not None:
        return _from_cached(hit)

    client = ProviderHTTPClient(...)
    payload = client.get(f"{BASE_URL}{FRAMES_PATH}").json()
    # Pydantic wire model validation
    parsed = _RainViewerWeatherMaps.model_validate(payload)
    frames = _to_canonical_frames(parsed)
    result = RadarFrameList(providerId=PROVIDER_ID, frames=frames, attribution=ATTRIBUTION)
    cache.set(key, _to_cacheable(result), ttl=_CACHE_TTL)
    return result
```

**WMS-T providers (GetCapabilities XML):**

```python
def get_frames() -> RadarFrameList:
    cache = get_cache()
    key = _cache_key()
    hit = cache.get(key)
    if hit is not None:
        return _from_cached(hit)

    client = ProviderHTTPClient(...)
    xml_bytes = client.get(
        f"{BASE_URL}{FRAMES_PATH}",
        params={"service": "WMS", "version": "1.3.0", "request": "GetCapabilities"},
    ).content
    times = parse_wms_time_dimension(xml_bytes, layer=LAYER_NAME)  # shared helper
    frames = _to_canonical_frames(times)
    result = RadarFrameList(providerId=PROVIDER_ID, frames=frames, attribution=ATTRIBUTION)
    cache.set(key, _to_cacheable(result), ttl=_CACHE_TTL)
    return result
```

### Frame-kind mapping

**rainviewer:** `radar.past[i].time < generated` → `"past"`; `radar.past[i].time == generated` (the latest) → `"current"`; `radar.nowcast[i]` (if any) → `"nowcast"`. Verbatim per api-docs file.

**WMS-T providers:** all frames `"past"` EXCEPT the latest timestamp which is `"current"`. No nowcast frames available from these providers in this round.

## Shared infrastructure additions

### `providers/_common/wms_capabilities.py` (NEW)

Parses WMS GetCapabilities XML, extracts the `<Dimension name="time">` value for a named layer, returns `list[str]` (ISO-8601 UTC timestamps). Uses **`defusedxml`** (NOT `xml.etree.ElementTree` directly — see [coding.md §1 "Avoid dangerous functions"] for the XML-attack rationale; stdlib XML is vulnerable to billion-laughs, external-entity-expansion, quadratic-blowup attacks).

```python
def parse_wms_time_dimension(xml_bytes: bytes, *, layer: str) -> list[str]:
    """Extract TIME dimension values from a WMS GetCapabilities response.

    Args:
        xml_bytes: Raw GetCapabilities response body.
        layer: Layer name to find within the capabilities tree.

    Returns:
        List of ISO-8601 UTC timestamps from the layer's <Dimension name="time"> element.
        May be a comma-separated list, OR an ISO start/end/period notation per WMS 1.3.0 spec.
        The function handles both forms and returns expanded individual timestamps.

    Raises:
        ProviderProtocolError: malformed XML, layer not found, or no TIME dimension.
    """
```

Add `defusedxml==0.7.1` to `pyproject.toml` `dependencies = [...]` (exact pin matches project convention — other deps are `==`-pinned). Verified at brief-draft: `defusedxml` is NOT currently in `pyproject.toml`. Pure-Python MIT-licensed.

### `providers/_common/capability.py` (EXTEND)

Add four optional fields to `ProviderCapability` — two distinct access patterns (XYZ slippy vs WMS) require distinct shape:

```python
@dataclass(frozen=True)
class ProviderCapability:
    provider_id: str
    domain: str
    supplied_canonical_fields: tuple[str, ...]
    geographic_coverage: str
    auth_required: tuple[str, ...] = field(default_factory=tuple)
    default_poll_interval_seconds: int = 300
    operator_notes: str | None = None
    # NEW (3b-14, radar domain only — None for non-radar providers):
    tile_url_template: str | None = None      # XYZ slippy URL template ({z}/{x}/{y} placeholders)
    wms_endpoint_url: str | None = None       # WMS GetMap base URL (Leaflet L.tileLayer.wms())
    wms_layer_name: str | None = None         # WMS layer name (e.g. "RADAR_1KM_RDPR")
    tile_content_type: str | None = None      # "image/png" etc. — any radar provider
```

XYZ providers (rainviewer) set `tile_url_template` + `tile_content_type`; leave the WMS fields None. WMS-T providers (the 4 others) set `wms_endpoint_url` + `wms_layer_name` + `tile_content_type`; leave `tile_url_template` None. The dashboard reads which path applies by inspecting which fields are non-None.

Non-radar provider module CAPABILITY declarations don't change (they continue to omit the new fields, which default to `None`). The OpenAPI `CapabilityDeclaration` schema does NOT change this round — the new fields are runtime-only for now; the `/capabilities` endpoint surfaces them only via radar-aware response shaping (TBD when dashboard wires up).

> **Lead call:** OpenAPI schema extension for `tile_url_template` + `tile_content_type` deferred to the dashboard-integration round (after 3b-15/16) — at that point the dashboard's actual consumption pattern is concrete and the schema extension can be sized correctly. For 3b-14, the fields exist on the Python dataclass and the registry, but `/capabilities` response includes them only if non-None (additive, doesn't break existing clients). Document the deferral in the commit body.

### `providers/_common/dispatch.py` (EXTEND)

Add 5 imports + 5 rows to `PROVIDER_MODULES`:

```python
from weewx_clearskies_api.providers.radar import dwd_radolan as radar_dwd_radolan
from weewx_clearskies_api.providers.radar import iem_nexrad as radar_iem_nexrad
from weewx_clearskies_api.providers.radar import msc_geomet as radar_msc_geomet
from weewx_clearskies_api.providers.radar import noaa_mrms as radar_noaa_mrms
from weewx_clearskies_api.providers.radar import rainviewer as radar_rainviewer

PROVIDER_MODULES: dict[tuple[str, str], ModuleType] = {
    …existing entries…,
    ("radar", "dwd_radolan"): radar_dwd_radolan,
    ("radar", "iem_nexrad"): radar_iem_nexrad,
    ("radar", "msc_geomet"): radar_msc_geomet,
    ("radar", "noaa_mrms"): radar_noaa_mrms,
    ("radar", "rainviewer"): radar_rainviewer,
}
```

## New `RadarSettings` (`config/settings.py`)

Mirror `EarthquakesSettings`:

```python
class RadarSettings:
    """[radar] section settings (3b-14)."""
    provider: str | None
    # No per-provider credentials — all five keyless this round. Keyed providers in 3b-15.

    def __init__(self, config_section=None):
        if config_section is None:
            self.provider = None
            return
        self.provider = config_section.get("provider") or None

    def validate(self) -> None:
        valid_providers = {"rainviewer", "iem_nexrad", "noaa_mrms", "msc_geomet", "dwd_radolan"}
        # Note: 3b-15 will extend this set with the keyed providers.
        if self.provider is not None and self.provider not in valid_providers:
            raise ValueError(
                f"[radar] provider {self.provider!r} not in {valid_providers}. "
                "Supported values for 3b-14 (more added in 3b-15): "
                "'rainviewer', 'iem_nexrad', 'noaa_mrms', 'msc_geomet', 'dwd_radolan'."
            )
```

Wire into `Settings.__init__` like the earthquakes section.

## App wiring (`app.py`, `__main__.py`)

- `app.py`: register the `endpoints/radar.py` router at `/radar` prefix.
- `__main__.py`: add step 6n (after 6m forecast wiring): "wire radar — register configured radar provider's CAPABILITY in registry". No `wire_radar_settings()` call needed this round (no per-request settings to pass — provider id is read from the capability registry directly, same as alerts).

## Lead calls (resolved at brief-draft — not open questions)

1. **WMS XML parsing → `defusedxml`** (not stdlib `xml.etree`). Per coding.md §1.
2. **Four optional radar fields added to `ProviderCapability`** (`tile_url_template`, `wms_endpoint_url`, `wms_layer_name`, `tile_content_type`) — not a subclass. Per ADR-038 line 86's anticipation + the simplicity bias. If 3b-15/16 surfaces 2+ more radar-only fields, refactor to a subclass at that point (current spec keeps the abstraction lazy).
3. **OpenAPI `CapabilityDeclaration` schema NOT extended this round.** Deferred until dashboard consumption is concrete. Runtime Python dataclass is wider than the wire schema; that's fine — the wire schema is additive when extended.
4. **Frame `kind` rule for WMS-T providers: latest = `current`, all others = `past`, no nowcast.** rainviewer follows its own JSON-derived rule per api-docs.
5. **Cache key = `(provider_id, "frames")`** — no station component (frame index is global per provider, not per-station). 60s TTL.
6. **No `wire_radar_settings()` startup wiring.** Provider id lives in the registry; no per-request settings (no min-magnitude/severity-style filter, no station lat/lon).
7. **No tile proxy endpoint** (`/radar/providers/{provider_id}/tiles/{z}/{x}/{y}`) this round. Deferred to 3b-15 with the keyed providers (where the proxy machinery is genuinely needed — keyless providers don't need a proxy). The OpenAPI spec already has it; the impl just doesn't exist yet, which is fine for a v0.1 contract where the contract may legitimately precede the impl.

## Open questions for user (real ones)

None known at brief-draft time. The 5 lead calls above are all locked by ADR / canonical / api-docs files.

## Test coverage (test-author)

Per-provider unit tests (5 files, mirroring `tests/providers/earthquakes/test_*.py`):

- **Fixture loading + parse** — recorded JSON / XML response → parsed model.
- **Canonical translation** — `_to_canonical_frames()` produces correct `RadarFrame` list with correct `time` and `kind` per provider's rule.
- **Cache integration** — `fakeredis` fixture, set + get round-trip.
- **Error mapping** — 429 → QuotaExhausted, 5xx → TransientNetworkError, malformed JSON/XML → ProviderProtocolError.
- **CAPABILITY shape** — `tile_url_template`, `tile_content_type` non-None for all 5; `supplied_canonical_fields == ()`.

Integration tests (one file, `tests/test_radar_endpoint_integration.py`):

- `/radar/providers/{provider_id}/frames` returns 200 + RadarFramesResponse with parsed frames per provider (5 cases, recorded fixtures for each).
- Unknown provider_id → 404.
- Configured provider in dispatch but NOT in registry → 404.
- Provider in registry but 429 from upstream → 503 + Retry-After.

WMS GetCapabilities fixture capture: use the **live** GetCapabilities response from each WMS-T provider's endpoint (captured to `tests/fixtures/providers/radar/{provider}/get_capabilities.xml`). RainViewer fixture from live `weather-maps.json`. Sidecar `fixtures.md` per provider documenting capture date + provenance.

## Process gates

- **lead-pytest-verify after both teammates commit** (Step H per `rules/clearskies-process.md`). Re-run `pytest tests/ -m "not live_network"` on weather-dev; counts must show 1954 → ~2100-2200 passed (no failures), no regressions.
- **api-dev: pull-then-pytest** before submitting closeout per agent definition. `git fetch origin main && git merge --ff-only origin/main` then full pytest with test-author's latest commits.
- **test-author: synthetic-from-real fixture pattern not applicable** this round (all 5 providers fully accessible without auth — capture real responses directly).
- **Auditor:** source-only review, fires after both teammates close. Lead synthesizes findings; lead-direct remediation for ≲50-line / ≲3-file mechanical fixes; spawn for larger.
- **Provenance:** all commits use `Co-Authored-By: Claude Sonnet 4.6 (1M context) <noreply@anthropic.com>` (teammates) or `Claude Opus 4.7 (1M context) <noreply@anthropic.com>` (lead-direct).

## STOP triggers (teammate-side, per agent definitions)

- `defusedxml` not installable / blocked by license → STOP, ping lead. (Defusedxml is MIT-licensed and pure-Python — should install cleanly.)
- WMS GetCapabilities response from any provider does NOT contain a `<Dimension name="time">` element → STOP, ping lead. (Provider may have changed endpoint shape; brief assumption needs revisit.)
- RainViewer JSON shape changed (e.g., `radar.past` renamed) → STOP, ping lead.
- Brief implies extending `ProviderCapability` dataclass; if api-dev finds an existing call site that breaks with the new optional fields → STOP, ping lead.
- Brief vs canonical / OpenAPI mismatch surfaced mid-impl → STOP, ping lead per agent rule.
- impl signature ≠ test-author's signature → STOP, ping lead. Do NOT flip impl unilaterally.

## Out of scope this round (carries into 3b-15 / 3b-16)

- `aeris`, `openweathermap`, `mapbox_jma` provider modules — 3b-15 (keyed).
- `/radar/providers/{provider_id}/tiles/{z}/{x}/{y}` proxy endpoint — 3b-15 (needed only for keyed providers; keyless are direct-browser-fetch).
- Binary-response cache for proxied tiles per ADR-017 — 3b-15.
- `iframe` config slot — 3b-16.
- OpenAPI `CapabilityDeclaration` schema extension for radar fields — dashboard-integration round (post-3b-16).
- Per-region auto-pick in the setup wizard — wizard-implementation round.
- `defaultPollIntervalSeconds` semantic refinement (it currently overlaps with cache TTL; for radar these are different concepts — frame index update cadence vs cache TTL; defer to a future round).

## Commit-message guidance

Each provider module + the shared helper + the endpoint should land as their own commit (no mega-end-commit). Per "Commit early and often" in agent definitions. Suggested commit slicing:

1. `_common/wms_capabilities.py` helper + tests.
2. `_common/capability.py` dataclass extension.
3. `providers/radar/__init__.py` + `rainviewer.py` + unit tests.
4. `providers/radar/iem_nexrad.py` + unit tests.
5. `providers/radar/noaa_mrms.py` + unit tests.
6. `providers/radar/msc_geomet.py` + unit tests.
7. `providers/radar/dwd_radolan.py` + unit tests.
8. `endpoints/radar.py` + `app.py` registration + `_common/dispatch.py` rows + integration tests.
9. `config/settings.py` `RadarSettings` + tests.
10. `__main__.py` wiring (step 6n).

api-dev commits impl + the shared helper; test-author commits tests in parallel. Both pull-then-pytest before submitting closeout.
