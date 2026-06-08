# Recharts Component API Reference (v3.x)

Saved from recharts.github.io. Read this before any Recharts chart work.

---

## ResponsiveContainer

Container that adjusts width/height based on parent element size. Uses ResizeObserver.

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `width` | `${number}%` or number | `"100%"` | Container width. Use `"99%"` (not 100%) to force resize recalculation. |
| `height` | `${number}%` or number | `"100%"` | Container height |
| `aspect` | number | — | Width/height ratio; height = width/aspect |
| `minWidth` | number or string | `0` | Minimum width |
| `minHeight` | number or string | — | Minimum height |
| `maxHeight` | number | — | Maximum height |
| `debounce` | number | `0` | Debounce delay (ms) for resize events |
| `initialDimension` | `{width, height}` | `{width:-1, height:-1}` | Starting dimensions |
| `onResize` | `(width, height) => void` | — | Resize callback |

**Parent of:** AreaChart, BarChart, ComposedChart, LineChart, etc.

---

## ComposedChart

Combines Area, Bar, Line, Scatter in one chart.

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `data` | `ReadonlyArray<object>` | — | Source data array |
| `width` | number or `${number}%` | — | Chart width |
| `height` | number or `${number}%` | — | Chart height |
| `margin` | `{top, right, bottom, left}` | `{top:5, right:5, bottom:5, left:5}` | Empty space around chart. ADDITIVE with axis widths. |
| `layout` | `"horizontal"` or `"vertical"` | `"horizontal"` | Orientation of axes |
| `stackOffset` | `"none"` / `"expand"` / `"positive"` / `"sign"` / `"silhouette"` / `"wiggle"` | `"none"` | Stacking algorithm |
| `reverseStackOrder` | boolean | `false` | Reverse stack direction |
| `barCategoryGap` | number or string | `"10%"` | Gap between bar categories |
| `barGap` | number or string | `4` | Gap between bars in same category |
| `barSize` | number or string | — | Width/height of each bar |
| `syncId` | string or number | — | Sync tooltip/brush across charts with same syncId |

**Accepts children:** Area, Bar, Line, Scatter, XAxis, YAxis, CartesianGrid, Tooltip, Legend, Brush, ReferenceArea, ReferenceDot, ReferenceLine

---

## Area

Renders filled area under a curve. Can be stacked.

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `dataKey` | string / number / function | **required** | Which data property to plot |
| `type` | string | `"linear"` | Curve interpolation: `"linear"`, `"monotone"`, `"step"`, `"basis"`, `"natural"`, `"bump"`, etc. |
| `fill` | string | — | Fill color. Use `"url(#gradientId)"` for gradient fills. |
| `stroke` | string | `"#3182bd"` | Line color. `"none"` hides the line. |
| `strokeWidth` | number | `1` | Line width |
| `fillOpacity` | number | — | Fill opacity (0-1) |
| `stackId` | string or number | — | Areas with same stackId and axisId stack together |
| `baseValue` | `"dataMin"` / `"dataMax"` / number | — | Baseline for non-stacked areas. Ignored for stacked areas. |
| `dot` | boolean / object / ReactElement / function | `false` | Data point markers |
| `activeDot` | boolean / object / ReactElement / function | `true` | Dot on hover |
| `connectNulls` | boolean | `false` | Connect curve across null values |
| `hide` | boolean | `false` | Hide but keep in axis domain and legend |
| `isAnimationActive` | boolean or `"auto"` | `"auto"` | Animation control |
| `animationDuration` | number | `1500` | Animation duration ms |
| `legendType` | string | `"line"` | Icon in legend. `"none"` hides from legend. |
| `unit` | string or number | — | Unit shown in tooltip |
| `name` | string | — | Display name in tooltip/legend (falls back to dataKey) |
| `xAxisId` | string or number | `0` | Which XAxis this belongs to |
| `yAxisId` | string or number | `0` | Which YAxis this belongs to |
| `zIndex` | number | `100` | Render layer depth |

### Gradient fill pattern

```tsx
<ComposedChart data={data}>
  <defs>
    <linearGradient id="colorTemp" x1="0" y1="0" x2="0" y2="1">
      <stop offset="5%" stopColor="#ff7300" stopOpacity={0.8} />
      <stop offset="95%" stopColor="#ff7300" stopOpacity={0} />
    </linearGradient>
  </defs>
  <Area
    dataKey="value"
    fill="url(#colorTemp)"
    fillOpacity={1}
    stroke="none"
  />
</ComposedChart>
```

For gradients tied to Y-axis positions (temperature zones), use `gradientUnits="userSpaceOnUse"` with pixel coordinates:

```tsx
<defs>
  <linearGradient
    id="tempGradient"
    x1="0" y1={plotTopPixels}
    x2="0" y2={plotBottomPixels}
    gradientUnits="userSpaceOnUse"
  >
    <stop offset="0%" stopColor="red" />    {/* yMax temperature */}
    <stop offset="50%" stopColor="green" />  {/* mid temperature */}
    <stop offset="100%" stopColor="blue" />  {/* yMin temperature */}
  </linearGradient>
</defs>
```

### Stacked area range pattern (simulating Highcharts arearange)

```tsx
{/* Invisible base pushes the visible band up */}
<Area dataKey="base" stackId="range" fill="transparent" stroke="none" />
{/* Visible range band = high - low */}
<Area dataKey="range" stackId="range" fill="url(#gradient)" stroke="none" />
```

Where data has: `base = lowValue`, `range = highValue - lowValue`.

---

## YAxis

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `type` | `"number"` / `"category"` | `"number"` | Continuous or discrete values |
| `domain` | array | auto-calculated | `[min, max]`. Accepts numbers, `'auto'`, `'dataMin'`, `'dataMax'`, expressions like `'dataMax + 100'`, or functions. |
| `width` | number or `"auto"` | `60` | Pixel width carved for axis. `"auto"` resizes based on content. |
| `orientation` | `"left"` / `"right"` | `"left"` | Label position |
| `label` | boolean / string / object / ReactElement / function | `false` | Axis label |
| `ticks` | array | — | Manual tick positions |
| `tickFormatter` | `(value, index) => string` | — | Format tick labels |
| `tickCount` | number | `5` | Approximate tick count |
| `scale` | string or d3-scale | `"auto"` | `"log"`, `"sqrt"`, `"linear"`, etc. |
| `allowDataOverflow` | boolean | `false` | If true, data can extend beyond domain (clips). If false, domain adjusts. |
| `allowDecimals` | boolean | `true` | Allow decimal tick values |
| `minTickGap` | number | `5` | Min spacing between ticks |
| `niceTicks` | string | — | `"none"` / `"auto"` / `"adaptive"` / `"snap125"` |
| `reversed` | boolean | `false` | Reverse tick order |
| `mirror` | boolean | `false` | Flip labels inside chart |
| `hide` | boolean | `false` | **WARNING: known bug #428 — using hide on YAxis causes XAxis labels to vanish.** Use `tick={false} axisLine={false} tickLine={false} width={1}` instead. |
| `yAxisId` | string or number | `0` | Unique ID for multiple YAxes |

---

## XAxis

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `dataKey` | string | — | Property name from data |
| `type` | `"number"` / `"category"` | `"category"` | Value type |
| `domain` | array | auto | `['dataMin', 'dataMax']` for auto-scaling to data range |
| `height` | number | `30` | Pixel height for axis labels |
| `scale` | string | `"auto"` | `"time"` with `type="number"` for timestamp data |
| `tickFormatter` | function | — | Format tick labels |
| `minTickGap` | number | `5` | Min spacing between ticks (prevents overlap) |
| `interval` | number / `"preserveEnd"` / `"preserveStart"` / `"preserveStartEnd"` / `"equidistantPreserveStart"` | `"preserveEnd"` | Tick culling strategy |
| `ticks` | array | — | Manual tick positions |
| `tick` | boolean / object / ReactElement / function | `true` | Tick label rendering |
| `axisLine` | boolean / object | `true` | Horizontal baseline |
| `tickLine` | boolean / object | `true` | Vertical tick marks |
| `hide` | boolean | `false` | Hide axis |

---

## SVG Gradient Notes

### gradientUnits

- **`objectBoundingBox`** (SVG default): Coordinates are fractions (0-1) of the element's bounding box. `x1="0" y1="0" x2="0" y2="1"` = top to bottom of the filled path's bounding box.
- **`userSpaceOnUse`**: Coordinates are in the SVG's pixel coordinate system. You must specify actual pixel positions. Use this when gradient colors must map to specific Y-axis values (e.g., temperature zones).

### objectBoundingBox pitfall with stacked areas

When using `objectBoundingBox` on a stacked Area, the bounding box covers the FULL path (including the stacking offset). The gradient maps to the path's visual extent, not to the data domain. For temperature zones that must map to absolute Y-axis positions, use `userSpaceOnUse`.

### Computing pixel coordinates for userSpaceOnUse

```typescript
// Plot area boundaries in SVG pixels:
const plotTop = margin.top;  // where yMax renders
const plotBottom = chartHeight - margin.bottom - xAxisHeight;  // where yMin renders

// Temperature threshold to pixel:
const tempToPixel = (temp: number) =>
  plotTop + (yMax - temp) / (yMax - yMin) * (plotBottom - plotTop);
```

### Stepped color zones (flat bands, not smooth gradients)

To replicate Highcharts zones (flat color per temperature range, no blending):

```tsx
<linearGradient id="zones" x1="0" y1={plotTop} x2="0" y2={plotBottom} gradientUnits="userSpaceOnUse">
  {/* Each zone needs TWO stops at the same offset to prevent blending */}
  <stop offset="0%" stopColor="orange" />
  <stop offset="24.9%" stopColor="orange" />
  <stop offset="25%" stopColor="gold" />
  <stop offset="49.9%" stopColor="gold" />
  <stop offset="50%" stopColor="green" />
  <stop offset="100%" stopColor="green" />
</linearGradient>
```
