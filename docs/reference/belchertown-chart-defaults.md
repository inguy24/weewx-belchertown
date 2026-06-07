# Belchertown Chart Rendering Defaults — Research Report

**Date:** 2026-06-06
**Source files:** `belchertown.js.tmpl` (JS renderer), `belchertown.py` (Python backend)
**Purpose:** Document every hardcoded chart default so we can decide what to carry over to Clear Skies.

---

## 1. Default Color Palette

**Source:** `belchertown.py` line 2336-2339

```python
colors = chart_options.get(
    "colors",
    "#7cb5ec, #b2df8a, #f7a35c, #8c6bb1, #dd3497, #e4d354, #268bd2, #f45b5b, #6a3d9a, #33a02c",
)
```

10-color default palette (used when no per-series colors specified):
| Index | Hex | Description |
|-------|-----|-------------|
| 0 | #7cb5ec | Light blue |
| 1 | #b2df8a | Light green |
| 2 | #f7a35c | Orange |
| 3 | #8c6bb1 | Purple |
| 4 | #dd3497 | Magenta/pink |
| 5 | #e4d354 | Yellow |
| 6 | #268bd2 | Blue |
| 7 | #f45b5b | Red/salmon |
| 8 | #6a3d9a | Dark purple |
| 9 | #33a02c | Dark green |

**Per-series colors:** Come from `color = xxx` in graphs.conf at the series level. These override the palette position.

**Operator's graphs.conf:** Has the same 10-color palette at line 31, plus extensive per-series color assignments (red for outTemp, purple for dewpoint, green/#28a745 for windGust, blue/#007bff for windSpeed, #BECC00 for radiation, orange for lightning strikes, blue for lightning distance, etc.).

**Clear Skies current state:** Has a 6-color FALLBACK_PALETTE (`#7cb5ec, #434348, #90ed7d, #f7a35c, #8085e9, #f15c80`) — different from Belchertown's. Global colors array flows from charts.conf through API to dashboard. Per-series colors also flow through. BUT: none are theme-responsive.

---

## 2. Default Chart Type

**Source:** `belchertown.py` line 2455-2457

```python
plottype = plot_options.get("type", "line")
```

Default chart type is `"line"`. Applied at the CHART level — all series in a chart inherit unless overridden at the series level.

**The operator's graphs.conf specifies chart types explicitly:**
- Most chart groups: `type = spline` (smooth curves)
- Wind Speed and Direction chart: `type = line` (sharp corners)
- Rain chart: `type = line` at chart level, `type = column` on rainTotal series
- Solar: `type = spline`, with `type = area` on maxSolarRad (Theoretical Max)
- No series-level `type` override on windDir — BUT windDir is conventionally rendered as scatter in Belchertown via `lineWidth = 0` + `marker.radius` (Highcharts trick)

**Clear Skies current state:** Resolution chain `series.type ?? config.type ?? globalType ?? 'line'`. Correctly falls through. The migration tool carries types through from graphs.conf.

---

## 3. Default Marker/Dot Behavior

**Source:** `belchertown.js.tmpl` lines 4263-4302

**CRITICAL FINDING: Markers are DISABLED by default on ALL line-based chart types.**

```javascript
plotOptions: {
    area: {
        lineWidth: 2,
        marker: { enabled: false, radius: 2 },
        threshold: null,
        softThreshold: true
    },
    line: {
        lineWidth: 2,
        marker: { enabled: false, radius: 2 },
    },
    spline: {
        lineWidth: 2,
        marker: { enabled: false, radius: 2 },
    },
    areaspline: {
        lineWidth: 2,
        marker: { enabled: false, radius: 2 },
        threshold: null,
        softThreshold: true
    },
    scatter: {
        marker: { radius: 2 },
        // Note: NO 'enabled: false' — scatter shows markers by default
    },
}
```

**Summary:**
- line: markers OFF, radius 2 (only visible on hover)
- spline: markers OFF, radius 2
- area: markers OFF, radius 2
- areaspline: markers OFF, radius 2
- scatter: markers ON (default), radius 2

**Clear Skies current state:** `dotProp` returns `undefined` when `markerEnabled` is not set in config — Recharts defaults to SHOWING markers on Line components. This is the ROOT CAUSE of F5/F7/F11/F13 (wall of dots).

---

## 4. Default Line Width

**Source:** `belchertown.js.tmpl` lines 4263-4302

All line-based chart types default to `lineWidth: 2`.

**Clear Skies current state:** `strokeWidth = series.borderWidth ?? series.lineWidth ?? 2` — correct, matches Belchertown.

---

## 5. Default Axis Behavior

### Y-Axis defaults
**Source:** `belchertown.js.tmpl` lines 4251-4260

```javascript
yAxis: [{
    endOnTick: true,
    lineColor: '#555',
    minorGridLineWidth: 0,
    startOnTick: true,
    showLastLabel: true,
    title: {},
    opposite: false
}]
```

Highcharts with `endOnTick: true` and `startOnTick: true` auto-scales the Y-axis tightly around the data, rounding to nice tick boundaries. This is why Belchertown's barometer chart shows 29.900–30.050 instead of starting from 0.

### Special Y-Axis per observation type

**Barometer** (lines 4507-4513):
```javascript
if (obsType == "barometer" || obsType == "pressure" || obsType == "altimeter") {
    options.yAxis[this_yAxis].labels = {
        format: '{value:.2f}'  // 2 decimal precision
    };
}
```

**Rain/RainRate/RainTotal** (lines 4517-4521):
```javascript
if (obsType == "rain" || obsType == "rainRate" || obsType == "rainTotal") {
    options.yAxis[this_yAxis].min = 0;
    options.yAxis[this_yAxis].minRange = 0.01;
    options.yAxis[this_yAxis].minorGridLineWidth = 1;
}
```

**Wind Direction** (lines 4523-4529):
```javascript
if (obsType == "windDir") {
    options.yAxis[this_yAxis].tickInterval = 90;
    options.yAxis[this_yAxis].labels = {
        useHTML: true,
        formatter: function() {
            var value = weatherdirection[this.value];
            return value !== 'undefined' ? value : this.value;
        }
    };
}
```

### X-Axis defaults
**Source:** `belchertown.js.tmpl` lines 4233-4249

```javascript
xAxis: {
    dateTimeLabelFormats: {
        day: '%e %b',
        week: '%e %b',
        month: '%b %y',
    },
    lineColor: '#555',
    minRange: 900000,        // 15 minutes minimum
    minTickInterval: 900000,  // 15 minutes between ticks
    title: { style: { font: 'bold 12px ...' } },
    ordinal: false,
    type: 'datetime'
}
```

The `minRange` and `minTickInterval` of 900000ms (15 min) prevent overcrowding. Highcharts auto-selects appropriate intervals (e.g., every 4 hours for 24h charts).

**Clear Skies current state:** XAxis has NO `minTickGap`, `interval`, or equivalent. Recharts attempts to show many ticks and duplicates/overlaps result. This is the ROOT CAUSE of F4 (overcrowded X-axis).

---

## 6. Default Tooltip

**Source:** `belchertown.js.tmpl` lines 4330-4361

```javascript
tooltip: {
    enabled: true,
    crosshairs: true,
    dateTimeLabelFormats: { hour: '%e %b %H:%M' },
    formatter: function(tooltip) { ... },
    split: true,
}
```

- Split tooltips (each series gets its own tooltip box)
- Crosshairs enabled (vertical line at cursor position)
- Special formatting for windDir (cardinal direction labels)
- Uses `highcharts_tooltip_factory()` for number formatting with locale

**Global tooltip date format** (`belchertown.py` line 2348):
```python
tooltip_date_format = chart_options.get("tooltip_date_format", "LLLL")
```
Default: "LLLL" (moment.js full date/time format)

---

## 7. Other Highcharts Defaults

### Chart-level
```javascript
chart: {
    spacing: [5, 10, 10, 0],
    zoomType: 'x'  // horizontal zoom enabled
}
```

### Area/Areaspline specific
```javascript
threshold: null,     // allows area fill below 0
softThreshold: true  // area fill starts from the data minimum, not 0
```

### Gap handling
- Default gap size: 300 seconds (from Python: `gapsize = plot_options.get("gapsize", 300)`)
- `gapUnit: 'value'`

### Legend
- `enabled: true` (default from Python, configurable)

### Scrollbar/Navigator/RangeSelector
- All disabled by default (lines 4312-4321)

---

## 8. Wind Rose Defaults

**Beaufort scale colors** (`belchertown.py` lines 2894-2901):
```python
wind_rose_color[0] = line_options.get("beauford0", "#7cb5ec")  # < 1 mph
wind_rose_color[1] = line_options.get("beauford1", "#b2df8a")  # 1-3 mph
wind_rose_color[2] = line_options.get("beauford2", "#f7a35c")  # 4-7 mph
wind_rose_color[3] = line_options.get("beauford3", "#8c6bb1")  # 8-12 mph
wind_rose_color[4] = line_options.get("beauford4", "#dd3497")  # 13-18 mph
wind_rose_color[5] = line_options.get("beauford5", "#e4d354")  # 19-24 mph
wind_rose_color[6] = line_options.get("beauford6", "#268bd2")  # 25+ mph
```

**Chart configuration** (JS):
- `chart.type: 'column'`, `chart.polar: true`
- Column stacking: 'normal'
- Legend: verticalAlign top, floating, positioned right

---

## 9. Config Merging Strategy

**Source:** `belchertown.py` line 2322

Belchertown uses `accumulateLeaves()` for hierarchical config merging:

```
Global defaults (top-level graphs.conf keys)
  -> Chart Group (e.g., [day], [week])
    -> Chart (e.g., [[Temperature]])
      -> Series (e.g., [[[outTemp]]])
```

Each level inherits from its parent. A series in `[[[outTemp]]]` inherits from `[[Temperature]]`, which inherits from `[day]`, which inherits from global.

---

## 10. What the Operator's graphs.conf Explicitly Sets

These are NOT defaults — they're the operator's actual configuration:

| Series | Color | Type | Other |
|--------|-------|------|-------|
| outTemp | red | (inherits spline) | zIndex=1 |
| dewpoint | purple | (inherits spline) | |
| windchill | (palette[2]) | (inherits spline) | |
| heatindex | (palette[3]) | (inherits spline) | |
| windDir | (palette[0]) | (inherits line) | lineWidth=0, radius=3 (scatter effect) |
| windGust | #28a745 (green) | (inherits line) | |
| windSpeed | #007bff (blue) | (inherits line) | |
| rainRate | (palette[0]) | (inherits line) | |
| rainTotal | #268bd2 | column | yAxis_label="Average Monthly Rain Total (in)" |
| barometer | (palette[0]) | (inherits spline) | |
| radiation | #BECC00 | (inherits spline) | |
| maxSolarRad | #f7f2b4 | area | |
| UV | #90ed7d | (inherits spline) | yAxis_label="UV" |
| lightning_strike_count | orange | (inherits line) | yAxis_label="Number of Strikes" |
| lightning_distance | blue | (inherits line) | yAxis_label="Distance (miles)" |
| aqi | #7cb5ec | (inherits spline) | |

---

## 11. Gap Analysis: What Clear Skies Is Missing

| Belchertown Default | Clear Skies Current | Gap? |
|--------------------|--------------------|------|
| Markers OFF on line/spline/area | `dot={false}` default | CLOSED (2026-06-07) — T-A1 |
| Y-axis auto-scales (endOnTick, startOnTick) | `domain={['auto','auto']}`, rain `[0,'auto']` | CLOSED (2026-06-07) — T-A2 |
| X-axis minTickInterval 15min | `minTickGap={50}` | CLOSED (2026-06-07) — T-A3 |
| Barometer: 2-decimal Y-axis labels | `resolveTickDecimals()` + `yAxisTickDecimals` config | CLOSED (2026-06-07) — T-A5 |
| Rain: min=0, minRange=0.01 | Rain axis domain `[0,'auto']` | CLOSED (2026-06-07) — T-A2 |
| windDir: tickInterval=90, cardinal labels | Compass labels implemented (T2.3) | CLOSED |
| Area: threshold=null, softThreshold=true | Not applied | YES — minor, deferred |
| 10-color default palette | Belchertown 10-color FALLBACK_PALETTE | CLOSED (2026-06-07) — T-A4 |
| Theme-responsive colors | `ensureChartContrast()` on all series | CLOSED (2026-06-07) — T-A4 |
| Date buttons inside card | Inside Card after CardHeader | CLOSED (2026-06-07) — T-B1 |
| Wind rose rendering | BFF injects beaufort; separate raw fetch | CLOSED (2026-06-07) — T-C1 + BFF fix |
| No fixed text artifacts | sr-only tables wrapped in div | CLOSED (2026-06-07) — T-C3 |
| Proportional data scaling | `aggregate_interval` + `agg_map` API params | CLOSED (2026-06-07) — matches Belchertown |
| Per-field aggregation in rolling ranges | `agg_map` passes operator's `aggregate_type` per series | CLOSED (2026-06-07) |
