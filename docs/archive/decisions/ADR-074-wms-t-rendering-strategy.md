---
status: Superseded — provider direction chose LibreWxR (XYZ tiles); WMS-T not on critical path
date: 2026-06-26
deciders: shane
supersedes:
superseded-by:
---

# ADR-074: WMS-T Rendering Strategy

> **Note (2026-06-26):** The provider architecture decision (2026-06-26)
> chose LibreWxR (XYZ tiles) over NOAA direct (WMS-T). This ADR's
> rendering approach is technically sound (PoC verified against live IEM
> NEXRAD) but is no longer on the critical path. Retained as reference
> material if WMS-T is ever needed for a future provider.
>
> See [RADAR-WMS-RESEARCH-PLAN.md](../planning/RADAR-WMS-RESEARCH-PLAN.md)
> Resolution section for the full decision chain.

## Context

The radar provider replacement plan (Phases 3-4) requires rendering WMS-T
(Web Map Service with Time dimension) animated radar layers in the
react-leaflet dashboard. The NOAA unified provider exposes two radar
sub-layers (IEM NEXRAD, NOAA MRMS) and five satellite layers (GOES bands)
as WMS-T endpoints — all time-animated, browser-direct.

The first implementation attempt (2026-06-24) failed because it treated
WMS tiles like CDN XYZ tiles. Every time frame was rendered as a separate
`<TileLayer>` component, all mounted simultaneously. With 300 NOAA frames
× ~12 tiles per viewport, this generated ~3,600 concurrent server-side
render requests. The WMS server cannot handle this — WMS renders on demand,
not from a CDN cache. Ten consecutive fix commits failed to correct the
architecture because the fundamental approach was wrong.

Additionally, the code used Leaflet's `TileLayer` (XYZ class) for WMS URLs,
embedding `{bbox-epsg-3857}` as a template variable. `TileLayer` only knows
`{x}`, `{y}`, `{z}` — any other variable crashes with "No value provided."

This decision establishes the correct rendering approach before any more
dashboard code is written.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| **leaflet-timedimension** (single layer, TIME swap) | Proven pattern; handles caching, preloading, multi-layer sync; 15KB minified; verified in PoC against live IEM endpoints | Last npm publish 2019; no React wrapper; requires iso8601-js-period dependency; control UI needs CSS overrides or replacement |
| Custom hook (L.TileLayer.WMS.setParams) | No dependency; full React control | Reinvents time management, caching, preloading, multi-layer sync; larger and less tested than library |
| Pre-render all frames as separate TileLayers | Works for CDN tiles (RainViewer pattern) | **Proven failure for WMS** — 3,600+ concurrent server-side render requests; crashes server or returns errors |
| OpenLayers | Native WMS-T support | Dashboard uses Leaflet/react-leaflet; would require full map library swap |

## Decision

Use **leaflet-timedimension 1.1.1** for WMS-T animation. Single
`L.TileLayer.WMS` per data source, wrapped with
`L.timeDimension.layer.wms`. The TIME parameter swaps per frame advance.
Preloading via `cacheBackward`/`cacheForward`. Multiple WMS-T layers
(NEXRAD, MRMS, satellite) share the same `L.TimeDimension` instance for
synchronized animation.

Integrate with react-leaflet v5 via a custom component using the `useMap()`
hook — no official React wrapper exists. The dashboard provides its own
animation controls (per the design manual); leaflet-timedimension's built-in
controls are not used. The TimeDimension and Player APIs are called
programmatically from React state.

## Consequences

**Positive:**
- WMS requests are sequential per frame, not simultaneous for all frames
- Frame preloading (cacheBackward/cacheForward) provides smooth animation
  without overwhelming the server
- Multi-layer sync is automatic — all layers on the same map share one
  TimeDimension and advance in lockstep
- Library handles edge cases (buffer underrun pause, time rounding, layer
  cleanup) that a custom implementation would need to build

**Negative:**
- Adds two npm dependencies: `leaflet-timedimension@1.1.1`,
  `iso8601-js-period@0.2.1`
- leaflet-timedimension is stable but unmaintained (last publish 2019).
  Risk: if a future Leaflet version breaks compatibility, we may need to
  fork or vendor the library. Mitigation: the library's API surface is
  small and well-understood; vendoring ~15KB is feasible.
- No `@types/leaflet-timedimension` — need a project-local `.d.ts` file
- The custom React component is imperative (useEffect + Leaflet API) rather
  than declarative (JSX). This is inherent to wrapping Leaflet plugins in
  react-leaflet.

**Trade-offs accepted:**
- Library maintenance risk is accepted because the alternative (custom
  implementation) is larger, less tested, and would duplicate proven logic.
- CSS override work is accepted because we're replacing the library's
  controls with our own UI anyway.

## Acceptance criteria

- [ ] `npm ls leaflet-timedimension` shows 1.1.1 installed in dashboard
- [ ] NEXRAD WMS-T layer animates through TIME values — verified in browser
      DevTools: one set of tile requests per frame advance, not all frames
      simultaneously
- [ ] Two WMS-T layers (NEXRAD + MRMS or NEXRAD + satellite) animate in sync
      — same TIME value on both layers' requests at each frame
- [ ] Frame preloading works — toggling to a cached frame shows tiles
      instantly (no loading flash)
- [ ] The dashboard's time slider drives frame changes via
      `timeDimension.setCurrentTime()`, not leaflet-timedimension's built-in
      control
- [ ] TypeScript declarations exist for `L.TimeDimension`,
      `L.timeDimension.layer.wms`, and `L.TimeDimension.Player`
- [ ] `tsc --noEmit` and `vite build` pass with zero errors

## Implementation guidance

**npm install:**
```bash
npm install leaflet-timedimension@1.1.1 iso8601-js-period@0.2.1
```

**Bundler setup:** Import iso8601-js-period as a side-effect before
leaflet-timedimension (it registers a global `nezasa` namespace):
```typescript
import 'iso8601-js-period';
import 'leaflet-timedimension';
```

**Custom React component pattern:** See `docs/reference/wms-t-implementation-ref.md`
for the full component code. The core pattern:
1. `useMap()` to get the Leaflet map instance
2. `useEffect` to create TimeDimension, WMS layer, and tdLayer
3. Expose `setCurrentTime`, `play`, `pause` via ref or callback props
4. Cleanup on unmount: remove layers, destroy TimeDimension

**Cache settings:**
- Card view (24 frames): `cacheBackward: 10, cacheForward: 5`
- Expanded view (up to 300 frames): `cacheBackward: 20, cacheForward: 10`
  (sliding window, NOT all 300 cached)

**Z-ordering with Leaflet panes:**
```typescript
map.createPane('satellite');   // z-index 350
map.createPane('radar');       // z-index 400
map.createPane('overlays');    // z-index 450
```

**Out of scope:**
- LibreWxR rendering (CDN XYZ tiles — existing pattern works, no WMS-T)
- RainViewer rendering (CDN XYZ tiles — existing pattern works)
- SPC/alert GeoJSON overlays (standard Leaflet GeoJSON, not WMS-T)
- leaflet-timedimension's built-in control UI (replaced by dashboard UI)

## References

- Research: `docs/reference/wms-t-rendering-research.md`
- PoC: `docs/reference/wms-t-poc/`
- Related: ADR-015 (radar map tiles strategy, amended for NOAA/LibreWxR)
- Library: github.com/socib/Leaflet.TimeDimension
- IEM WMS-T endpoint: mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r-t.cgi
