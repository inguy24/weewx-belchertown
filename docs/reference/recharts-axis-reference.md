# Recharts Axis Reference (v3.x)

Extracted from the installed `recharts@^3.8.1` source code. Read this before ANY chart work.

## Layout pipeline

The chart calculates a plot area using:

```
plotArea.left   = margin.left  + sum(width of all non-hidden left YAxes)
plotArea.right  = margin.right + sum(width of all non-hidden right YAxes)
plotArea.top    = margin.top   + sum(height of all non-hidden top XAxes)
plotArea.bottom = margin.bottom + sum(height of all non-hidden bottom XAxes)
```

**margin is ADDITIVE, not a substitute.** It adds extra padding on top of what the axes consume. Margin alone does NOT make axes visible.

## XAxis props

| Prop | Default | Behavior |
|------|---------|----------|
| `height` | **30** | Carves N pixels at the bottom for the XAxis. Tick labels render in this space. |
| `hide` | `false` | When `true`, CartesianAxis returns `null` — nothing renders, no space consumed. |
| `interval` | `'preserveEnd'` | Controls tick culling. `0` = show every tick. `'preserveEnd'` = auto-hide overlapping ticks. `'preserveStartEnd'` = keep first and last. |
| `tick` | `true` | Master switch for labels. `false` = no labels. Object `{}` = SVG text props. |
| `tickLine` | `true` | Small vertical line at each tick. `false` hides line but NOT the label. |
| `axisLine` | `true` | Horizontal baseline. `false` hides just the line. |
| `tickFormatter` | `undefined` | `(value, index) => string`. Raw value rendered if absent. |
| `scale` | `'auto'` | `'time'` with `type='number'` treats data as epoch ms. |

## YAxis props

| Prop | Default | Behavior |
|------|---------|----------|
| `width` | **60** | Carves N pixels on the left for the YAxis. Tick labels render in this space. |
| `hide` | `false` | Same as XAxis — returns `null`, no space consumed. |
| `tick` | `true` | Master switch for labels. |

## Zero-guard (CartesianAxis.js line 422)

```js
if (width != null && width <= 0 || height != null && height <= 0) {
  return null;
}
```

If axis width or height is 0 or negative, the axis silently returns null. Nothing renders.

## How margin and axes interact

- `margin.left` does NOT control YAxis visibility. It adds padding to the LEFT of the YAxis.
- `margin.bottom` does NOT control XAxis visibility. It adds padding BELOW the XAxis.
- With `margin.bottom: 0` and default XAxis `height: 30`, the XAxis gets 30px of space — sufficient for labels.
- With `margin.bottom: 14` and default XAxis `height: 30`, total bottom = 44px — the extra 14px is just padding below the labels.

## Chart margin defaults

When not specified: `{ top: 5, right: 5, bottom: 5, left: 5 }`. Your explicit `margin` prop replaces this entirely.

## Common mistakes

1. Setting `margin.bottom: 14` thinking it "makes room for labels" — the XAxis already has 30px by default. Extra margin just wastes chart space.
2. Setting `margin.left: -28` to "hide" a YAxis — this clips the leftmost chart data and any left-side labels.
3. Setting `width={0}` on a visible YAxis — triggers the zero-guard, axis returns null.
4. Setting `hide` on YAxis but leaving `width` unset — `hide` makes it invisible AND removes its space allocation.
5. Using `interval="preserveStartEnd"` with few ticks — can drop intermediate ticks unexpectedly.
6. Confusing Recharts `margin` (internal SVG padding) with CSS `margin`/`padding` on the container div.
7. Using `hide` on YAxis — **known bug** ([recharts/recharts#428](https://github.com/recharts/recharts/issues/428)): the `hide` prop on YAxis causes XAxis labels to disappear. Instead, use `tick={false} axisLine={false} tickLine={false} width={1}` to visually hide the YAxis without breaking XAxis layout.
8. Chart wrapper div in a flex/grid parent must have `minWidth: 0, minHeight: 0, width: '100%', height: '100%'` — otherwise ResizeObserver reads 0 dimensions and axis text nodes are omitted entirely.
9. Use `ResponsiveContainer width="99%"` not `"100%"` — the 100% value causes a layout calculation failure where resize triggers don't fire, resulting in labels not painting.
10. Tick generators must use LOCAL time boundaries (`new Date().setHours(...)`) — not UTC (`Math.ceil(ms / 3600000) * 3600000`). `getHours()` returns local hours; UTC-computed ticks won't match local 0/6/12/18.
11. **CRITICAL: The build script is `tsc -b && vite build`.** If tsc fails (even on unused variable warnings like TS6133), vite never runs and dist/ stays stale. Every deploy MUST verify zero tsc errors FIRST.
