# WMS-T Radar Rendering Research — Work Plan

**Status:** NOT STARTED
**Created:** 2026-06-25
**Blocks:** [RADAR-PROVIDER-REPLACEMENT-PLAN.md](RADAR-PROVIDER-REPLACEMENT-PLAN.md) Phases 3-4 (dashboard)
**Session type:** Dedicated research session (separate from the main plan execution)

---

## Problem

The radar provider replacement plan requires rendering WMS-T (Web Map Service with Time dimension) animated radar layers in a React + Leaflet dashboard. The first implementation attempt failed because the agent did not understand how WMS-T animation differs from CDN XYZ tile animation. Specifically:

- WMS tiles are rendered server-side on every request. Pre-rendering all frames as separate TileLayers (the approach used for RainViewer CDN tiles) generates thousands of simultaneous server-side render requests.
- The correct WMS-T animation pattern uses a single WMS layer and swaps the TIME parameter per frame advance.
- The agent never researched this before implementation, never looked at existing libraries (e.g., leaflet-timedimension), and spent 10 fix commits patching the wrong architecture.

This research session fills that gap before any more dashboard code is written.

---

## Research Questions

1. **What is the established pattern for WMS-T time animation in Leaflet?** How does the TIME parameter get swapped? How are tiles preloaded for smooth animation? What handles the frame buffer?

2. **What libraries exist?** Evaluate at minimum:
   - `leaflet-timedimension` — the most widely used WMS-T animation library for Leaflet
   - Any react-leaflet wrappers or community examples
   - Other open-source WMS-T radar viewers (for pattern reference, not direct use)

3. **How does dual-layer sync work?** NOAA requires two WMS-T layers (NEXRAD + MRMS) animating in sync to the same TIME value. How do existing solutions handle multi-layer time synchronization?

4. **What are the gotchas?** Tile preloading, cache behavior, error handling for missing TIME values, browser memory with long frame histories (300 frames), WMS request rate, CORS on government endpoints.

5. **How does this integrate with react-leaflet?** Our dashboard uses `react-leaflet` v4+. Does leaflet-timedimension work with it? Are there React wrappers? Or do we need a custom hook/component that uses the library's API?

---

## Deliverables

### D1 — Research document
Save to `docs/reference/wms-t-rendering-research.md`. Must include:
- Summary of the correct WMS-T animation pattern (with explanation of why the pre-render-all approach is wrong)
- Library evaluation (leaflet-timedimension and alternatives)
- Dual-layer synchronization approach
- Known gotchas and mitigations
- Recommended approach for our dashboard (library choice + integration pattern)

### D2 — Proof-of-concept
A standalone HTML page (or minimal React app) that demonstrates:
- One WMS-T layer (IEM NEXRAD) animating through TIME values
- Play/pause control
- Frame preloading (smooth animation, no flash on frame change)
- Correct WMS GetMap requests (verify in browser dev tools: one layer, TIME parameter changes, NOT 300 simultaneous layers)

Save to `docs/reference/wms-t-poc/` with a README explaining how to run it.

The PoC must work against the live IEM NEXRAD WMS endpoint: `https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r-t.cgi`

### D3 — ADR: WMS-T rendering strategy
Draft a new ADR (Proposed) recording the decision about:
- Library choice (leaflet-timedimension, custom, or hybrid)
- Animation pattern (single-layer TIME swap vs. alternatives evaluated)
- Dual-layer synchronization approach
- react-leaflet integration strategy
- What was tried and failed in the first attempt (context for why this decision exists)

The ADR follows the standard lifecycle: Proposed → user reviews → Accepted → rules extracted into manuals.

### D4 — Manual updates (from accepted ADR)
Once the ADR is accepted, update the governing manuals with the implementation rules:
- **DASHBOARD-MANUAL.md** — add WMS-T rendering rules to the radar section: library to use, animation pattern, component architecture, dual-layer wiring, what the dashboard-dev agent must follow
- **DESIGN-MANUAL.md** — if the rendering approach affects visual behavior (animation timing, preload indicators), update the radar design spec

These manual updates are what unblock Phases 3-4 of the main plan. The dashboard agent follows the manual, not the ADR — the ADR records why; the manual says what to do.

### D5 — Agent-ready implementation reference
Save to `docs/reference/wms-t-implementation-ref.md`. This is NOT a manual section or narrative doc — it is a terse, code-heavy cheat sheet designed to be inlined into a dashboard-dev agent prompt. Structure:

**DO (proven in PoC):**
- Exact react-leaflet code snippets for WMS-T TIME animation (copy from PoC, adapt for React component)
- Exact preload/buffer technique that worked
- Exact dual-layer sync wiring (if tested in PoC)
- Exact component tree with prop signatures

**DO NOT (proven failures from first attempt):**
- Do NOT pre-render all frames as separate TileLayer components — causes 600+ simultaneous WMS server-side render requests
- Do NOT use `TileLayer` for WMS URLs — crashes on `{bbox-epsg-3857}` template variable
- Do NOT pass `undefined` to the `pane` prop — Leaflet `appendChild` crash
- Do NOT treat WMS tiles like CDN XYZ tiles — WMS renders server-side on every request
- Any other gotchas discovered during PoC development

**Component architecture:**
- What components exist, what props they take, what hooks they use
- How the time slider drives frame changes (event flow)
- How dual-layer sync is wired (shared state, coordinated TIME updates)

**Integration notes:**
- Library version and import paths
- Any react-leaflet compatibility workarounds
- CSS containment for Leaflet z-index (stacking context)

**Format rule:** Code snippets over prose. If a pattern can be shown in 5 lines of code, show the code — don't write 3 paragraphs explaining it. The agent reading this should be able to copy-adapt, not interpret.

The coordinator inlines relevant sections of this document into the agent prompt for T3.2 and T4.6. The agent should also be pointed at the PoC source code directly (`docs/reference/wms-t-poc/`).

### Dependency chain
```
Research (D1, D2) → ADR draft (D3, Proposed) → user approval → ADR Accepted
→ Manual updates (D4) + Implementation ref (D5) → Phases 3-4 of main plan UNBLOCKED
```

---

## Approach

1. **Web research first.** Search for leaflet-timedimension docs, tutorials, examples. Search for "WMS time animation leaflet" and "react-leaflet WMS-T." Read the leaflet-timedimension source code for the core animation loop. Find existing open-source radar viewers that use WMS-T.

2. **Build the PoC.** Use the research findings to build a minimal working example. This is the prototype step that was skipped in the first attempt.

3. **Verify the PoC works.** Open browser dev tools, confirm the WMS request pattern is correct (single layer, TIME parameter swapping, reasonable request count). Confirm animation is smooth.

4. **Document findings.** Write D1 and D3 based on what was learned building the PoC.

---

## NOT in scope

- Full dashboard implementation (that's Phases 3-4 of the main plan)
- LibreWxR rendering (uses XYZ tiles, not WMS-T — already works with existing animation)
- API changes (Phase 1 of main plan, independent of this research)
- Wizard changes (Phase 2 of main plan, independent of this research)
- SPC/alert GeoJSON overlays (standard Leaflet GeoJSON, not WMS-T)
