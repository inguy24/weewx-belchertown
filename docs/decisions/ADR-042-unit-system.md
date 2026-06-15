---
status: Accepted
date: 2026-05-26
deciders: shane
---

# ADR-042: Unit system — full weewx compatibility

## Context

Clear Skies is a weewx skin but has no unit system. Traditional weewx skins get unit conversion and labeling for free from the Cheetah template engine via skin.conf `[Units]`. We chose React (ADR-002) for interactivity but never accounted for the unit handling we walked away from.

weewx defines 14 unit groups with specific valid units for each. Operators expect per-group unit selection. The current dashboard has 45+ hardcoded unit strings (`"°F"`, `"mph"`, `"inHg"`) and Beaufort/comfort-index thresholds in US units.

The API (ADR-041) needs to identify the source unit, convert to the operator's display unit, and attach the correct label.

> **Historical note:** MQTT field names previously arrived with unit suffixes (`outTemp_F`, `windSpeed_mph`) encoding the source unit. MQTT is eliminated per ADR-058; the API now reads loop packets via the socket reader. The suffix-stripping logic described below was part of the former realtime service (then called "BFF"), which has been merged into the API.

## Options considered

| Option | Verdict |
|---|---|
| A. Full weewx compatibility in API (14 groups, all valid units) | **Selected.** One conversion layer, compatible with skin.conf migration. |
| B. Partial compatibility (top 5 groups only) | Violates "weewx skin" positioning. Non-US operators hit gaps immediately. |
| C. Client-side conversion in dashboard | Duplicates logic for REST and SSE paths. Every component needs unit knowledge. |
| D. Force operators to set weewx `target_unit` to desired display | Breaks mixed-unit preferences (e.g., metric temp + imperial rain). Per-field overrides are the norm in skin.conf. |

## Decision

Clear Skies implements full weewx unit system compatibility. The API (ADR-041) is the single conversion authority.

### Unit groups (complete, from weewx 5.x docs)

| Group | Valid units | Default (US) |
|---|---|---|
| group_temperature | degree_F, degree_C, degree_K, degree_E | degree_F |
| group_speed | mile_per_hour, km_per_hour, knot, meter_per_second | mile_per_hour |
| group_speed2 | mile_per_hour2, km_per_hour2, knot2, meter_per_second2 | mile_per_hour2 |
| group_pressure | inHg, mbar, hPa, kPa | inHg |
| group_pressurerate | inHg_per_hour, mbar_per_hour, hPa_per_hour, kPa_per_hour | inHg_per_hour |
| group_rain | inch, cm, mm | inch |
| group_rainrate | inch_per_hour, cm_per_hour, mm_per_hour | inch_per_hour |
| group_altitude | foot, meter | foot |
| group_distance | mile, km | mile |
| group_direction | degree_compass | degree_compass |
| group_radiation | watt_per_meter_squared | watt_per_meter_squared |
| group_uv | uv_index | uv_index |
| group_percent | percent | percent |
| group_moisture | centibar | centibar |
| group_volt | volt | volt |

### How conversion works

**REST path:** API returns raw archive values with `usUnits` declaring the unit system. The API's enrichment pipeline reads `usUnits`, looks up each field's group, converts from archive unit to operator display unit, attaches label and formatted string.

**SSE path:** Loop packets arrive via the socket reader from the loop relay. The API identifies the source unit system from the packet's `usUnits` field, converts each observation to the operator's display unit, and attaches label.

**Output format:** `{ "value": 22.5, "label": "°C", "formatted": "22.5" }` — the dashboard renders this directly with zero unit math.

### Additional unit config (beyond group selection)

| Config subsection | What it controls | weewx equivalent | v0.1 status |
|---|---|---|---|
| `[[string_formats]]` | Decimal places per unit (`degree_F = %.1f`) | `[Units][[StringFormats]]` | supported |
| `[[labels]]` | Display symbols per unit (`degree_F = " °F"`) | `[Units][[Labels]]` | supported |
| `[[ordinates]]` | Compass direction labels (N, NNE, NE, ...) | `[Units][[Ordinates]]` | supported |
| `[[time_formats]]` | strftime patterns for different contexts | `[Units][[TimeFormats]]` | _out of scope — v0.1_ |
| `[[degree_days]]` | Base temps for HDD/CDD/GDD calculations | `[Units][[DegreeDays]]` | _out of scope — v0.1_ |
| `[[trend]]` | Barometer trend window and grace period | `[Units][[Trend]]` | supported |

### Derived values

- **Beaufort scale:** API computes from wind speed (any source unit) and emits the Beaufort number + label. Dashboard does not carry Beaufort thresholds.
- **Comfort index selector:** `comfortIndex` is a plain string field the API adds to every
  converted record. It selects which comfort metric applies at the current temperature:
  `"windChill"` (outTemp ≤ 50 °F), `"heatIndex"` (outTemp ≥ 80 °F), or `"none"` (moderate
  range). The dashboard uses this value to choose which of `windChill` or `heatIndex` to
  display — it does not re-derive the selection. The actual windChill and heatIndex values
  are separate fields converted by the normal unit pipeline.

## Consequences

- Dashboard stripped of ALL unit awareness — simpler components, no hardcoded strings.
- **As-built (confirmed):** `barometerTrendDirection` is classified by the API's
  `enrichment/barometer_trend.py` and emitted as a direction string
  (commits realtime cafb6b2, dashboard 6161f2f). `windDirCardinal` and
  `windGustDirCardinal` are API-computed 16-point codes emitted by `proxy.py`
  alongside every converted current-conditions record
  (commits realtime 3500659, dashboard 7340408). The dashboard performs zero
  client-side unit or direction math for these fields.
- Conversion factors must exactly match weewx's own values. Source: weewx Python source code (`weewx/units.py`), not approximations or Wikipedia.
- Floating-point precision handled by `StringFormats` rounding at format time — no accumulated error in display.
- Config format mirrors skin.conf `[Units]` subsection names for operator familiarity.
- Wizard can pre-fill unit config from imported skin.conf (ADR-043) or detected archive `usUnits`.
- **Historical (MQTT eliminated per ADR-058):** MQTT suffix stripping previously used a known-suffix map (not "split on last underscore") because some field names contained underscores. In direct mode (the only mode post-ADR-058), loop packets use weewx's native field names without suffixes.

## Implementation guidance

### File layout in API repo

```
weewx_clearskies_api/
├── units/
│   ├── __init__.py
│   ├── groups.py        # Group definitions, valid units, field→group mapping
│   ├── conversion.py    # Conversion factors (from weewx source)
│   ├── labels.py        # Display symbols per unit
│   ├── transformer.py   # Applies conversion + formatting to data dicts
│   └── derived.py       # API-computed derived fields: beaufort(), comfort_index()
```

### Config in `api.conf`

```ini
[units]
    [[groups]]
    group_temperature = degree_F
    group_speed = mile_per_hour
    group_pressure = inHg
    # ... defaults to US system if omitted

    [[string_formats]]
    degree_F = %.1f
    inch = %.2f

    [[labels]]
    degree_F = " °F"
    mile_per_hour = " mph"

    [[ordinates]]
    directions = N, NNE, NE, ENE, E, ESE, SE, SSE, S, SSW, SW, WSW, W, WNW, NW, NNW

    [[time_formats]]
    # strftime patterns

    [[degree_days]]
    heating_base = 65, degree_F
    cooling_base = 65, degree_F

    [[trend]]
    time_delta = 10800
    time_grace = 300
```

### Out of scope

- Custom unit definitions beyond weewx's documented set.
- Mixed units within a single group (weewx doesn't support this either).
- `[[time_formats]]` and `[[degree_days]]` config blocks: acknowledged as weewx config surface for operator familiarity, but API behavior is not wired in v0.1 — there is no dashboard consumer (degree-days reach the UI via the NOAA monthly-report text, already computed upstream; timestamps are formatted client-side per locale and station timezone per ADR-020/021).

## References

- weewx unit system docs: https://weewx.com/docs/5.1/reference/units/
- weewx source: `weewx/units.py` (conversion factors, UNIT_REDUCTIONS)
- Related: [ADR-041](ADR-041-realtime-bff.md) (realtime service / API), [ADR-010](ADR-010-canonical-data-model.md) (data model), [ADR-043](ADR-043-skinconf-compliance.md) (skin.conf)
- Research: [brief-weewx-units.md](../planning/briefs/brief-weewx-units.md), [brief-mqtt-field-names.md](../planning/briefs/brief-mqtt-field-names.md), [brief-dashboard-unit-audit.md](../planning/briefs/brief-dashboard-unit-audit.md)
