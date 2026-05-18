# Phase 2 Task 3b-16 Brief — Radar iframe config slot

Round identity: **3b-16** (last radar round; closes radar domain + task 3b).
Baseline: api `ad1fe37`, pytest 2283/364/0.

## Scope

Implement `providers/radar/iframe.py` — a config-slot module that publishes an operator-supplied iframe URL via CAPABILITY. No API call, no tile bytes, no frames, no credentials. The dashboard renders `<iframe>` instead of a Leaflet tile layer when CAPABILITY carries `iframe_url`. Per ADR-015: "operator-supplied URL for regions without a tile-API path (BoM Australia, MetService NZ). Loses theming/composition; documented tradeoff."

Setup-wizard integration is OUT OF SCOPE (ADR-027).

## Lead calls

**LC-1: `/frames` returns 501, not remove-from-dispatch.**
iframe IS added to `_KNOWN_RADAR_PROVIDERS`. If an operator configures `[radar] provider = iframe` and something hits `/radar/providers/iframe/frames`, a 404 saying "not supported" is confusing — iframe IS their configured provider. 501 (Not Implemented) with a clear detail message ("iframe providers do not have frame indexes; the dashboard uses the iframe_url from /capabilities") is honest. `/tiles` already returns 404 via existing `_KEYED_RADAR_PROVIDERS` check (iframe is not keyed) — no change needed there.

**LC-2: `iframe_url` field on `ProviderCapability` dataclass.**
Same pattern as the 3b-14 radar field extensions (`tile_url_template`, `wms_endpoint_url`, etc.). One new optional field: `iframe_url: str | None = None`. Non-None only for the iframe provider. Dashboard checks this field to decide iframe-vs-Leaflet rendering.

**LC-3: `make_capability(iframe_url)` factory, not module-level `CAPABILITY` constant.**
Unlike every other provider, iframe's CAPABILITY depends on operator config (the URL). `ProviderCapability` is `frozen=True`, so it can't be mutated after creation. The iframe module exports `make_capability(iframe_url: str) -> ProviderCapability` instead of a static `CAPABILITY`. `_wire_providers_from_config()` in `__main__.py` calls it with `settings.radar.iframe_url`.

**LC-4: `iframe_url` in `[radar]` config section, not env var.**
The iframe URL is operator content (like a station name), not a secret. It goes in `api.conf` under `[radar]`, not in `secrets.env`. ADR-027 §3's secret-leak guard regex (`_(KEY|SECRET|TOKEN|PASSWORD)$`) won't match `iframe_url`, which is correct.

## Implementation spec

### 1. `providers/radar/iframe.py` (~50 lines)

```
PROVIDER_ID = "iframe"
DOMAIN = "radar"

def make_capability(iframe_url: str) -> ProviderCapability:
    return ProviderCapability(
        provider_id=PROVIDER_ID,
        domain=DOMAIN,
        supplied_canonical_fields=(),
        geographic_coverage="operator-defined",
        auth_required=(),
        default_poll_interval_seconds=0,  # no polling — static URL
        operator_notes="Operator-supplied iframe URL. No tile layer, no frame index...",
        iframe_url=iframe_url,
    )
```

No `get_frames()`. No `get_tile()`. No HTTP client. No cache. No rate limiter.

### 2. `ProviderCapability` extension (capability.py)

Add one field to the dataclass:

```python
iframe_url: str | None = None  # operator-supplied iframe URL (iframe provider only)
```

Update the docstring to document it alongside the 3b-14 fields.

### 3. `RadarSettings` (settings.py)

- Add `"iframe"` to `valid_providers` set.
- Add `iframe_url: str | None` attribute, read from `section.get("iframe_url", "")`.
- Validation: if `provider == "iframe"` and `iframe_url` is None/empty, raise `ValueError` with a message like "[radar] provider='iframe' requires iframe_url to be set".

### 4. `endpoints/radar.py`

- Add `"iframe"` to `_KNOWN_RADAR_PROVIDERS` frozenset.
- In `get_radar_frames()`: after the "in dispatch + registered" check, before the module dispatch block, add an early return for iframe:

```python
if provider_id == "iframe":
    raise HTTPException(
        status_code=501,
        detail="iframe providers do not have frame indexes. "
               "The dashboard reads iframe_url from /capabilities.",
    )
```

- `get_radar_tile()`: no change. iframe is not in `_KEYED_RADAR_PROVIDERS`, so the existing 404 branch handles it.
- `wire_radar_settings()`: no change needed — iframe has no credentials to wire.

### 5. `dispatch.py`

Add one import + one row:

```python
from weewx_clearskies_api.providers.radar import iframe as radar_iframe
# ...
("radar", "iframe"): radar_iframe,
```

### 6. `__main__.py` — `_wire_providers_from_config()`

In the radar provider wiring block (line ~302), add iframe-specific logic:

```python
if provider_id == "iframe":
    iframe_url = settings.radar.iframe_url
    cap = module.make_capability(iframe_url=iframe_url)
    declarations.append(cap)
else:
    # existing: module.CAPABILITY
    ...
```

### 7. `__init__.py` (providers/radar/)

Update module docstring to include iframe in the provider list.

## Test spec

### Unit tests (~8-10 tests)

- `test_make_capability_returns_valid_provider_capability` — verify fields
- `test_make_capability_iframe_url_populated` — iframe_url matches input
- `test_make_capability_no_tile_fields` — tile_url_template, wms_endpoint_url, wms_layer_name are all None
- `test_radar_settings_accepts_iframe_provider` — settings validation passes
- `test_radar_settings_iframe_requires_url` — ValueError when iframe_url missing
- `test_frames_endpoint_returns_501_for_iframe` — HTTP 501 with detail message
- `test_tiles_endpoint_returns_404_for_iframe` — existing logic, but confirm
- `test_capabilities_includes_iframe_url` — when iframe is configured, /capabilities response includes iframe_url
- `test_dispatch_table_includes_iframe` — `("radar", "iframe")` key exists

### No integration tests needed

iframe makes no API calls. No live network. No fixtures to capture. Pure config-slot + endpoint behavior.

## Open question for user

None. All decisions are lead calls within existing ADR bounds.

## Files changed (estimated)

| File | Change |
|---|---|
| `providers/radar/iframe.py` | **New** (~50 lines) |
| `providers/radar/__init__.py` | Docstring update |
| `providers/_common/capability.py` | +1 field on dataclass |
| `config/settings.py` | iframe in valid_providers + iframe_url attr + validation |
| `endpoints/radar.py` | "iframe" in frozenset + 501 branch |
| `providers/_common/dispatch.py` | +1 import + 1 dict row |
| `__main__.py` | iframe branch in `_wire_providers_from_config()` |
| `tests/test_radar_iframe.py` | **New** (~120 lines) |

Estimated: ~200 lines impl + ~120 lines tests.

## Agent task breakdown

**api-dev task 1:** Write `providers/radar/iframe.py` + extend `ProviderCapability` + update `providers/radar/__init__.py` docstring.

**api-dev task 2:** Wire iframe into settings + dispatch + endpoint + `__main__.py`.

**test-author:** Write `tests/test_radar_iframe.py`.
