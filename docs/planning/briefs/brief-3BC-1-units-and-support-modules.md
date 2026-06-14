# Brief: Round 3BC-1 — Units Module and Supporting Modules

**Date:** 2026-06-13
**Lead:** Opus (coordinator)
**Teammate:** api-dev (Sonnet)
**Phase:** 3B+3C merged (T3C.1 + supporting modules for T3B.2)

## Objective

Port the unit conversion module and stateful supporting modules from `weewx-clearskies-realtime` into `weewx-clearskies-api`. Add the `[units]` config section to the API's settings. Create a field-name normalization utility replacing the MQTT-specific `strip_suffix`.

These modules are foundational — the enrichment processors (Round 3BC-2) depend on them.

## Scope

### Files to create

| Target path in API repo | Source in realtime repo | Notes |
|---|---|---|
| `weewx_clearskies_api/units/__init__.py` | `units/__init__.py` | Package init |
| `weewx_clearskies_api/units/conversion.py` | `units/conversion.py` | Conversion formulas between units |
| `weewx_clearskies_api/units/derived.py` | `units/derived.py` | Beaufort scale, comfort index |
| `weewx_clearskies_api/units/groups.py` | `units/groups.py` | Unit group definitions, field→group mapping |
| `weewx_clearskies_api/units/labels.py` | `units/labels.py` | Display symbols, formatting |
| `weewx_clearskies_api/units/transformer.py` | `units/transformer.py` | UnitTransformer class (main conversion engine) |
| `weewx_clearskies_api/sse/conditions_text.py` | `conditions_text.py` | Weather text composer |
| `weewx_clearskies_api/sse/sky_condition.py` | `sky_condition.py` | Stateful sky classifier (kc buffer) |
| `weewx_clearskies_api/sse/temperature_comfort.py` | `temperature_comfort.py` | Comfort label 2D matrix |
| `weewx_clearskies_api/sse/scene.py` | `scene.py` | Scene descriptor (day/night, sky bucket, overlay) |
| `weewx_clearskies_api/sse/field_utils.py` | NEW (replaces `mqtt_fields.py`) | Field name normalization |

### Files to modify

| File | What changes |
|---|---|
| `weewx_clearskies_api/config/settings.py` | Add `UnitsSettings` class for `[units]` config section |

### Files NOT to touch

- `tests/` — test-author
- `sse/emitter.py`, `sse/direct_adapter.py`, `sse/packet_tap.py`, `sse/ring_buffer.py` — already done in 3A-1
- `__main__.py` — wiring happens in Round 3BC-2
- `app.py` — no changes this round
- Any existing endpoint file
- Any enrichment processor — those are Round 3BC-2

## Reading list

Read these files from the realtime repo before coding. Read EVERY file completely.

**Units module:**
1. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/units/__init__.py`
2. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/units/conversion.py`
3. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/units/derived.py`
4. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/units/groups.py`
5. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/units/labels.py`
6. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/units/transformer.py`

**Supporting modules:**
7. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/conditions_text.py`
8. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/sky_condition.py`
9. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/temperature_comfort.py`
10. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/scene.py`

**MQTT fields (for understanding strip_suffix):**
11. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/mqtt_fields.py`

**API settings (for understanding the pattern):**
12. `repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py` — understand how to add a new settings class

## Pre-round verification

- API repo: Clean, HEAD=`2fe9d95` (Round 3A-1), branch=`main`

## Per-deliverable spec

### 1. Units module (`units/`)

Port all 5 files from realtime's `units/` directory. These contain:

- **conversion.py** — Conversion formulas between units (e.g., F↔C, mph↔km/h). Conversion factors must exactly match weewx's own values from `weewx/units.py`.
- **derived.py** — `beaufort(wind_speed, source_unit)` returning Beaufort scale dict, `comfort_index(out_temp, ...)` returning "windChill"/"heatIndex"/"none".
- **groups.py** — Unit group definitions mapping every weewx observation field to its unit group. `FIELD_TO_GROUP` dict, `VALID_UNITS` per group, etc.
- **labels.py** — `get_label(unit)` returning display symbol, `format_value(value, unit, string_formats)` returning formatted string.
- **transformer.py** — `UnitTransformer` class that converts observation dicts from one unit system to the operator's display units. `transform_record(record, us_units)` is the main entry point.

**Adaptation:** Change all internal imports from `weewx_clearskies_realtime.units.X` to `weewx_clearskies_api.units.X`. No logic changes.

The `transformer.py` may import from `config.settings` for reading unit config — adapt the import path to the API's settings module.

### 2. Supporting modules (`sse/`)

Port these 4 files. They contain module-level stateful classifiers used by the enrichment pipeline.

- **conditions_text.py** — `build_weather_text(...)` composer. Imports `beaufort` from `units.derived` — update import path to `weewx_clearskies_api.units.derived`.
- **sky_condition.py** — Stateful sky classifier. `update(radiation, max_solar_rad)` feeds the 30-min rolling kc-buffer. `classify()` returns sky label. `is_daytime()` returns bool. Uses `time.time()` for timestamps. No external imports beyond stdlib.
- **temperature_comfort.py** — `classify(app_temp, dewpoint, ...)` returns comfort descriptor string. 12 temp tiers × 7 moisture tiers. Hysteresis + 5-min hold cache. No external imports beyond stdlib.
- **scene.py** — `update_sun_times()`, `detect_precip()`, `update_provider_sky()`, `build_scene()`. Uses `time.monotonic()` for linger timer. No external imports beyond stdlib.

**Adaptation:** Change all internal imports:
- `weewx_clearskies_realtime.sky_condition` → `weewx_clearskies_api.sse.sky_condition`
- `weewx_clearskies_realtime.conditions_text` → `weewx_clearskies_api.sse.conditions_text`
- `weewx_clearskies_realtime.temperature_comfort` → `weewx_clearskies_api.sse.temperature_comfort`
- `weewx_clearskies_realtime.scene` → `weewx_clearskies_api.sse.scene`
- `weewx_clearskies_realtime.units.derived` → `weewx_clearskies_api.units.derived`

### 3. Field utils (`sse/field_utils.py`)

Create a new utility replacing `mqtt_fields.strip_suffix`. Since MQTT is eliminated (ADR-058), field names in direct mode never have unit suffixes. Create a simplified version:

```python
"""Field name normalization — replaces mqtt_fields.strip_suffix.

MQTT is eliminated (ADR-058). In direct mode, field names arrive without
unit suffixes (e.g., 'outTemp' not 'outTemp_F'). This module exists for
compatibility with enrichment processors ported from the realtime service
that called strip_suffix() defensively.
"""

from __future__ import annotations


def strip_suffix(name: str) -> tuple[str, str | None]:
    """Return (base_name, unit_suffix_or_None).

    In the merged API, all fields arrive via direct mode with no unit
    suffixes. Returns (name, None) for all inputs.

    Retained so ported processors can call it without code changes.
    """
    return (name, None)
```

This is intentionally a no-op. The processors that call it (input_smoother, sky_tap, wind_rolling_window, lightning_strike_buffer) use the result to try alternate field name lookups. In direct mode, the primary lookup always succeeds, so the suffix-stripped fallback is never reached.

### 4. Units settings (`config/settings.py`)

Add a `UnitsSettings` class following the existing pattern. This mirrors the `[units]` section from `realtime.conf`:

```python
class UnitsSettings:
    """[units] section — operator display unit preferences (ADR-042).
    
    Mirrors weewx skin.conf [Units] subsection names for operator familiarity.
    """
    
    def __init__(self, section: dict[str, Any]) -> None:
        # [[groups]] — display unit per group
        self.groups: dict[str, str] = dict(section.get("groups", {}))
        # [[string_formats]] — decimal places per unit
        self.string_formats: dict[str, str] = dict(section.get("string_formats", {}))
        # [[labels]] — display symbols per unit
        self.labels: dict[str, str] = dict(section.get("labels", {}))
        # [[ordinates]] — compass direction labels
        ordinates = section.get("ordinates", {})
        directions_raw = ordinates.get("directions", "") if isinstance(ordinates, dict) else ""
        self.directions: list[str] = [
            d.strip() for d in str(directions_raw).split(",") if d.strip()
        ] if directions_raw else []
        # [[trend]] — barometer trend window config
        trend = section.get("trend", {}) if isinstance(section.get("trend"), dict) else {}
        self.trend_time_delta: int = int(trend.get("time_delta", 10800))
        self.trend_time_grace: int = int(trend.get("time_grace", 300))
    
    def validate(self) -> None:
        pass
```

Add `units: UnitsSettings` to the `Settings` class, initialize from `cfg.get("units", {})`.

## Lead calls

1. **Straight ports with import path changes only.** The logic in all modules must be preserved exactly. Only import paths change from `weewx_clearskies_realtime.*` to `weewx_clearskies_api.*`.
2. **No wiring this round.** Don't modify `__main__.py` or `app.py`. Don't create the UnitTransformer instance. Don't register enrichments. That's Round 3BC-2.
3. **field_utils.strip_suffix is a no-op.** This is correct per ADR-058 (MQTT eliminated). Don't port the full MQTT suffix-stripping logic.
4. **Units config section uses ConfigObj nested dicts.** The `[units]` section has `[[groups]]`, `[[string_formats]]`, `[[labels]]`, `[[ordinates]]`, `[[trend]]` subsections. ConfigObj returns these as nested dicts.
5. **All modules must have `reset()` functions** where the original has them (sky_condition, temperature_comfort, scene, input_smoother, etc.) — these are test isolation hooks.

## Verification

After implementation:

1. Import checks:
```
python -c "from weewx_clearskies_api.units.conversion import convert; print('conversion OK')"
python -c "from weewx_clearskies_api.units.derived import beaufort; print('derived OK')"
python -c "from weewx_clearskies_api.units.groups import FIELD_TO_GROUP; print('groups OK')"
python -c "from weewx_clearskies_api.units.labels import get_label; print('labels OK')"
python -c "from weewx_clearskies_api.units.transformer import UnitTransformer; print('transformer OK')"
python -c "from weewx_clearskies_api.sse.conditions_text import build_weather_text; print('conditions_text OK')"
python -c "from weewx_clearskies_api.sse.sky_condition import classify, update; print('sky_condition OK')"
python -c "from weewx_clearskies_api.sse.temperature_comfort import classify; print('temperature_comfort OK')"
python -c "from weewx_clearskies_api.sse.scene import build_scene; print('scene OK')"
python -c "from weewx_clearskies_api.sse.field_utils import strip_suffix; print('field_utils OK')"
```

2. Commit all changes with a descriptive message.

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report. Do not resolve it yourself.
