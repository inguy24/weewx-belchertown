# Round 3BC-2: Enrichment Processors + Endpoint Enrichment Registry + Wiring

## Round identity

- **Round:** 3BC-2
- **Date:** 2026-06-14
- **Lead:** Opus (orchestration + judgment)
- **Teammate:** Sonnet (`clearskies-api-dev`)
- **Auditor:** deferred to close
- **Repos:** `weewx-clearskies-api` (target), `weewx-clearskies-realtime` (read-only source)

## Scope

### Files to create

Under `weewx_clearskies_api/sse/enrichment/`:

| # | File | Lines | Type | Source |
|---|------|-------|------|--------|
| 1 | `__init__.py` | ~5 | New | Package init, docstring only |
| 2 | `input_smoother.py` | ~91 | Straight port | `realtime/enrichment/input_smoother.py` |
| 3 | `uv_smoother.py` | ~105 | Straight port | `realtime/enrichment/uv_smoother.py` |
| 4 | `sky_tap.py` | ~58 | Straight port | `realtime/enrichment/sky_tap.py` |
| 5 | `wind_rolling_window.py` | ~363 | Adaptation | `realtime/enrichment/wind_rolling_window.py` |
| 6 | `lightning_strike_buffer.py` | ~278 | Straight port | `realtime/enrichment/lightning_strike_buffer.py` |
| 7 | `barometer_trend.py` | ~250 | HTTP→internal | `realtime/enrichment/barometer_trend.py` |
| 8 | `scene_enrichment.py` | ~250 | HTTP→internal | `realtime/enrichment/scene_enrichment.py` |
| 9 | `scene_packet_tap.py` | ~44 | Straight port | `realtime/enrichment/scene_packet_tap.py` |
| 10 | `weather_text.py` | ~232 | Straight port | `realtime/enrichment/weather_text.py` |
| 11 | `planet_viewing.py` | ~400 | HTTP→internal | `realtime/enrichment/planet_viewing.py` |

Under `weewx_clearskies_api/sse/`:

| # | File | Lines | Type |
|---|------|-------|------|
| 12 | `endpoint_enrichment.py` | ~50 | New (endpoint enrichment registry) |

### Files to modify

| File | What changes |
|------|-------------|
| `__main__.py` | Register all 5 packet-tap processors. Register all 7 endpoint enrichments. Create UnitTransformer from settings. Configure wind_rolling_window with transformer. Wire scene_packet_tap. |
| `endpoints/observations.py` | Call `apply_enrichments("current", data)` after building the /current response |
| `endpoints/almanac.py` | Call `apply_enrichments("almanac/planets", data)` for the planets sub-endpoint |

### Files NOT to touch

- `units/` — ported in 3BC-1
- `sse/conditions_text.py`, `sse/sky_condition.py`, `sse/temperature_comfort.py`, `sse/scene.py`, `sse/field_utils.py` — ported in 3BC-1
- `sse/ring_buffer.py`, `sse/packet_tap.py`, `sse/emitter.py`, `sse/direct_adapter.py`, `endpoints/sse.py` — ported in 3A-1
- Test files — test-author scope
- Any file in `weewx-clearskies-realtime` — READ-ONLY source

### Verification command

```bash
ssh -F "c:/CODE/weather-belchertown/.local/ssh/config" weewx \
  "cd /home/ubuntu/repos/weewx-clearskies-api && sudo -n .venv/bin/python -c \"
from weewx_clearskies_api.sse.enrichment import input_smoother, uv_smoother, sky_tap
from weewx_clearskies_api.sse.enrichment import wind_rolling_window, lightning_strike_buffer
from weewx_clearskies_api.sse.enrichment import barometer_trend, scene_enrichment
from weewx_clearskies_api.sse.enrichment import scene_packet_tap, weather_text, planet_viewing
from weewx_clearskies_api.sse.endpoint_enrichment import register_enrichment, apply_enrichments
print('All enrichment modules importable')
\""
```

### Deliverable definition

N commits on API `main` implementing all 11 enrichment processors + endpoint enrichment registry + wiring. All imports resolve. No references to `weewx_clearskies_realtime` in any new code. Verification command passes.

---

## Pre-round verification

- **API repo:** Clean, HEAD=`726f3c7` (3BC-1), `main` branch, 4 commits ahead of origin (not pushed)
- **Realtime repo:** Clean, HEAD=`a3f10f9`, `main` branch
- **3BC-1 modules confirmed present:** `units/` (6 files), `sse/conditions_text.py`, `sse/sky_condition.py`, `sse/temperature_comfort.py`, `sse/scene.py`, `sse/field_utils.py`
- **3A-1 modules confirmed present:** `sse/ring_buffer.py`, `sse/packet_tap.py`, `sse/emitter.py`, `sse/direct_adapter.py`, `endpoints/sse.py`

---

## Import path mapping

Every enrichment processor must update imports from the realtime package to the API package:

| Old import | New import |
|-----------|-----------|
| `weewx_clearskies_realtime.enrichment.ring_buffer.RingBuffer` | `weewx_clearskies_api.sse.ring_buffer.RingBuffer` |
| `weewx_clearskies_realtime.mqtt_fields.strip_suffix` | `weewx_clearskies_api.sse.field_utils.strip_suffix` |
| `weewx_clearskies_realtime.sky_condition` | `weewx_clearskies_api.sse.sky_condition` |
| `weewx_clearskies_realtime.conditions_text` | `weewx_clearskies_api.sse.conditions_text` |
| `weewx_clearskies_realtime.scene` | `weewx_clearskies_api.sse.scene` |
| `weewx_clearskies_realtime.enrichment.input_smoother` | `weewx_clearskies_api.sse.enrichment.input_smoother` |
| `weewx_clearskies_realtime.units.conversion.convert` | `weewx_clearskies_api.units.conversion.convert` |
| `weewx_clearskies_realtime.units.labels.*` | `weewx_clearskies_api.units.labels.*` |
| `weewx_clearskies_realtime.proxy.get_upstream_client` | **ELIMINATED** — replaced by internal function calls |
| `weewx_clearskies_realtime.proxy._transformer` | **ELIMINATED** — replaced by module-level `_transformer` |
| `weewx_clearskies_realtime.config.settings.load_settings` | **ELIMINATED** — config passed at startup |

---

## Per-deliverable specs

### 1. `endpoint_enrichment.py` (NEW)

Endpoint enrichment registry. Replaces the realtime's `proxy.py` `register_enrichment()` pattern.

```python
"""Endpoint enrichment registry — accumulate per-endpoint transform functions."""
import logging

logger = logging.getLogger(__name__)

_registry: dict[str, list] = {}

def register_enrichment(endpoint_key: str, fn) -> None:
    """Register fn to run on responses for endpoint_key."""
    _registry.setdefault(endpoint_key, []).append(fn)

def apply_enrichments(endpoint_key: str, data: dict) -> dict:
    """Run all registered enrichments for endpoint_key. Errors logged and skipped."""
    for fn in _registry.get(endpoint_key, []):
        try:
            data = fn(data)
        except Exception:
            logger.exception("Enrichment %s failed for endpoint %s", fn.__name__, endpoint_key)
    return data

def clear_enrichments() -> None:
    """Clear all registrations (testing only)."""
    _registry.clear()
```

All enrichment functions are **sync** `Callable[[dict], dict]`. No async support needed — all HTTP calls are replaced by sync internal function calls.

### 2. Straight-port processors

These are mechanical ports. Read the realtime source, update import paths per the mapping table, preserve all logic/thresholds/state.

**`input_smoother.py`** — 8 ring buffers (appTemp, dewpoint, outTemp, windSpeed, windGust, rainRate, heatindex, windchill). Exports: `process_packet(packet)`, `get_smoothed(field) -> float | None`, `reset()`.

**`uv_smoother.py`** — Single ring buffer for UV. Exports: `accumulate_uv(packet)`, `enrich_uv(data) -> dict`, `get_smoothed_uv() -> float | None`, `reset()`.

**`sky_tap.py`** — Feeds sky_condition from loop packets. Exports: `update_from_packet(packet)`.

**`lightning_strike_buffer.py`** — 24-hour strike history deque. Exports: `process_packet(packet)`, `get_strike_history() -> list[dict]`, `enrich_lightning_history(data) -> dict`, `reset()`.

**`scene_packet_tap.py`** — Injects scene descriptor into SSE packets. Exports: `inject_scene_into_packet(packet)`. Imports `sse.sky_condition` and `sse.scene`.

**`weather_text.py`** — Conditions text blending. Exports: `compose_weather_text(obs_data=None) -> str`, `enrich_weather_text(data) -> dict`. Imports `sse.sky_condition`, `sse.conditions_text`, `sse.enrichment.input_smoother`.

### 3. `wind_rolling_window.py` (adaptation needed)

Straight port EXCEPT for transformer access. The realtime version accesses `proxy._transformer._targets["group_speed"]` to resolve the target display unit for wind values.

**Adaptation:** Add a module-level `_transformer` reference and a `configure(transformer)` function:

```python
_transformer = None

def configure(transformer):
    """Set the UnitTransformer reference. Called once at startup."""
    global _transformer
    _transformer = transformer
```

In `enrich_wind_rolling_average()`, replace `proxy._transformer._targets["group_speed"]` with `_transformer._targets["group_speed"]`. If `_transformer` is None, skip enrichment (log warning, return data unchanged).

### 4. `barometer_trend.py` (HTTP→internal)

**Old pattern:** `httpx.get(f"{upstream_url}/api/v1/archive", params={"from": ts_from, "to": ts_to, "limit": 1, "fields": "barometer,timestamp"})`

**New pattern:**
```python
from weewx_clearskies_api.db.session import get_engine
from sqlalchemy.orm import Session as _Session
from sqlalchemy import text

def _fetch_historical_barometer(ts_from: int, ts_to: int) -> tuple[float, int] | None:
    """Get barometer reading closest to the target time window."""
    with _Session(get_engine()) as session:
        row = session.execute(
            text("SELECT barometer, dateTime FROM archive "
                 "WHERE dateTime BETWEEN :ts_from AND :ts_to "
                 "ORDER BY dateTime DESC LIMIT 1"),
            {"ts_from": ts_from, "ts_to": ts_to},
        ).fetchone()
        if row and row[0] is not None:
            return float(row[0]), int(row[1])
    return None
```

**Trend config:** Read `trend_time_delta` and `trend_time_grace` from module-level state set at startup (same `configure()` pattern as wind_rolling_window), NOT from settings file.

```python
_trend_time_delta = 10800  # default 3 hours
_trend_time_grace = 300    # default 5 min

def configure(trend_time_delta: int = 10800, trend_time_grace: int = 300):
    global _trend_time_delta, _trend_time_grace
    _trend_time_delta = trend_time_delta
    _trend_time_grace = trend_time_grace
```

**Remove:** All `httpx`/proxy client imports and calls. Remove `load_settings` import.

**Function changes:**
- `enrich_barometer_trend(data)` becomes **sync** (was async in realtime)
- Uses `_fetch_historical_barometer()` instead of HTTP call
- Unit resolution uses the module-level `_transformer` reference (same pattern as wind_rolling_window)
- Add `configure(transformer, trend_time_delta, trend_time_grace)` combining both concerns

### 5. `scene_enrichment.py` (HTTP→internal)

**Old pattern:**
- `httpx.get(f"{upstream_url}/api/v1/almanac", params={"date": date_str})` → sunrise/sunset
- `httpx.get(f"{upstream_url}/api/v1/forecast", params={"hours": 1, "days": 0})` → precipType

**New pattern for almanac:**
```python
from weewx_clearskies_api.services.almanac import compute_almanac
from weewx_clearskies_api.services.station import get_station_info

info = get_station_info()
almanac = compute_almanac(target_date, info.latitude, info.longitude, info.altitude, info.timezone)
# almanac.sun.rise, almanac.sun.set are ISO-8601 UTC strings
```

**New pattern for forecast (precipType):** Read `endpoints/forecast.py` and the provider dispatch to find the internal function that returns cached forecast data. The forecast is cached with a 30-minute TTL. Call the same provider dispatch or cache read function internally. If the internal API is unclear, the fallback is safe: skip precipType and rely on rain rate for precipitation detection (the realtime already has this fallback).

**Remove:** All `httpx`/proxy client imports. Remove `get_upstream_client`.

**Function changes:**
- `enrich_scene(data)` becomes **sync** (was async)
- Uses `compute_almanac()` + `get_station_info()` for sun times
- Uses internal forecast for precipType (with fallback)

### 6. `planet_viewing.py` (HTTP→internal)

**Old pattern:**
- `httpx.get(f"{upstream_url}/api/v1/almanac/seeing-forecast")` → 7Timer data
- `httpx.get(f"{upstream_url}/api/v1/almanac")` → moon RA/Dec/illumination, sun rise/set

**New pattern for seeing forecast:**
```python
from weewx_clearskies_api.providers.seeing.seven_timer import SevenTimerProvider
from weewx_clearskies_api.services.station import get_station_info

info = get_station_info()
provider = SevenTimerProvider(base_url="https://www.7timer.info/bin/astro.php", timeout_seconds=10)
forecasts = provider.fetch_forecast(info.latitude, info.longitude)
# Returns list[SeeingForecastPoint] or empty list on error
```

Note: check if a SevenTimerProvider instance already exists in the provider registry (via `__main__.py` wiring). If so, reuse it rather than creating a new one. If not, create one in `configure()` or at module level.

**New pattern for almanac:**
```python
from weewx_clearskies_api.services.almanac import compute_almanac
from weewx_clearskies_api.services.station import get_station_info

info = get_station_info()
almanac = compute_almanac(target_date, info.latitude, info.longitude, info.altitude, info.timezone)
```

For moon RA/Dec/illumination and planet positions: check `services/almanac.py` for `compute_planets()` or `compute_current_positions()` — these should provide the data the enrichment needs for moon proximity and conjunction detection.

**Remove:** All `httpx`/proxy client imports.

**Function changes:**
- `enrich_planet_viewing(data)` becomes **sync** (was async)
- Uses `SevenTimerProvider.fetch_forecast()` directly
- Uses `compute_almanac()` and potentially `compute_current_positions()` for moon data

---

## Wiring spec for `__main__.py`

After the existing SSE infrastructure block (Step 7a, around line 800), add:

### Step 7b: Create UnitTransformer
```python
from weewx_clearskies_api.units.transformer import UnitTransformer
transformer = UnitTransformer.from_settings(settings.units)
app.state.transformer = transformer
```

### Step 7c: Register packet-tap processors
```python
from weewx_clearskies_api.sse.packet_tap import register_processor
from weewx_clearskies_api.sse.enrichment import (
    input_smoother, uv_smoother, sky_tap,
    wind_rolling_window, lightning_strike_buffer,
    scene_packet_tap,
)

# Configure modules that need startup state
wind_rolling_window.configure(transformer)
barometer_trend.configure(transformer, settings.units.trend_time_delta, settings.units.trend_time_grace)

register_processor(input_smoother.process_packet)
register_processor(uv_smoother.accumulate_uv)
register_processor(sky_tap.update_from_packet)
register_processor(wind_rolling_window.process_packet)
register_processor(lightning_strike_buffer.process_packet)
register_processor(scene_packet_tap.inject_scene_into_packet)
```

### Step 7d: Register endpoint enrichments
```python
from weewx_clearskies_api.sse.endpoint_enrichment import register_enrichment
from weewx_clearskies_api.sse.enrichment import (
    barometer_trend, weather_text, planet_viewing,
    scene_enrichment,
)

register_enrichment("current", barometer_trend.enrich_barometer_trend)
register_enrichment("current", wind_rolling_window.enrich_wind_rolling_average)
register_enrichment("current", lightning_strike_buffer.enrich_lightning_history)
register_enrichment("current", weather_text.enrich_weather_text)
register_enrichment("current", uv_smoother.enrich_uv)
register_enrichment("current", scene_enrichment.enrich_scene)
register_enrichment("almanac/planets", planet_viewing.enrich_planet_viewing)
```

### Endpoint handler modifications

**`endpoints/observations.py` — `get_current_endpoint()`:**
After building the response, before returning:
```python
from weewx_clearskies_api.sse.endpoint_enrichment import apply_enrichments

# Existing code builds response...
response = ObservationResponse(data=observation, units=units, ...)
response_dict = response.model_dump(by_alias=True, exclude_none=True)
response_dict = apply_enrichments("current", response_dict)
return response_dict
```

**`endpoints/almanac.py` — `get_planets()`:**
Same pattern — build response, model_dump(), apply_enrichments("almanac/planets", ...), return dict.

---

## Lead calls

1. **All enrichments sync.** No async. HTTP calls → sync internal calls. DB queries → sync SQLAlchemy.
2. **Module-level `configure()` pattern** for processors that need startup state (wind_rolling_window, barometer_trend, scene_enrichment if needed, planet_viewing if needed).
3. **`scene_packet_tap` as regular packet-tap processor** for now. Ordering vs unit conversion deferred to T3C.2.
4. **Endpoint handler returns dict** after `model_dump()` + `apply_enrichments()`. FastAPI serializes the dict.
5. **`endpoints/observations.py`** is the file for `/current` enrichment (not `current.py`).
6. **No new dependencies.** `sse-starlette` already added in 3A-1. No httpx needed (HTTP calls eliminated). SQLAlchemy already present.

## Open questions (agent must surface via SendMessage)

1. **Forecast internal API for scene_enrichment:** How does `endpoints/forecast.py` call the provider dispatch? Is there a service function that returns cached forecast data? If unclear, implement with fallback-only (rain rate → "rain") and flag for lead resolution.
2. **SevenTimerProvider reuse:** Is a `SevenTimerProvider` instance already in the provider registry from `__main__.py` wiring? If yes, reuse it. If no, create one in `configure()`.
3. **`compute_planets()` vs `compute_current_positions()`:** Which function in `services/almanac.py` provides moon RA/Dec/illumination for planet_viewing's moon proximity check?
