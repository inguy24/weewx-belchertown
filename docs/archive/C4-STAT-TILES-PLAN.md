# C4 — Now-page stat tiles — execution plan

**Status:** COMPLETE (2026-06-01). All phases done. Archived to `docs/archive/C4-STAT-TILES-PLAN.md`.
**Component:** C4 of the UI redesign. Parent roadmap: [UI-REDESIGN-PLAN.md](../UI-REDESIGN-PLAN.md) Track C.
**Per-component workflow:** [UI-REDESIGN-PLAN.md](../UI-REDESIGN-PLAN.md) "Per-component workflow" (step 0 inspiration → step 1 data → step 2 composition → step 3 mockup → step 4 code).

---

## 0. Orientation for a fresh session (read first)

- Project rules routing: [../../CLAUDE.md](../../CLAUDE.md). **Load before acting:** [../../rules/coding.md](../../rules/coding.md), [../../rules/clearskies-process.md](../../rules/clearskies-process.md), [../../rules/github.md](../../rules/github.md).
- **Memory system is OFF** ([../../CLAUDE.md](../../CLAUDE.md)); plans live here in `docs/planning/`.
- **Three sub-repos** under `../../repos/`:
  - `weewx-clearskies-realtime` — BFF (Python). Agent: `clearskies-realtime-dev`.
  - `weewx-clearskies-api` — FastAPI + SQLAlchemy backend. Agent: `clearskies-api-dev`.
  - `weewx-clearskies-dashboard` — React 19 + Vite + Tailwind v4 + shadcn/ui + Recharts SPA. Agent: `clearskies-dashboard-dev`.
- **Data flow:** dashboard → BFF `/api/v1/current` (REST) + SSE (live) + `/api/v1/archive` (historical).
- **Deploy target:** `weather-dev`. Production Belchertown skin untouched.
- **Architecture source of truth:** [../ARCHITECTURE.md](../ARCHITECTURE.md). Contract: [../contracts/openapi-v1.yaml](../contracts/openapi-v1.yaml).

### Git safety (ALL agents, ALL repos — non-negotiable)
Implementation agents may ONLY `git add`, `git commit` (local), `git status`, `git log`, `git diff`. **NO `git pull/push/fetch/rebase/merge/remote`, NO checkout of remote branches, NO worktree isolation.** If unexpected repo state → STOP and report. Coordinator pushes only when operator types "push."

---

## 1. Context — what exists and what is changing

C4 covers **eight 1×1 stat tiles** on the Now page. All eight already exist as Phase 2 implementations — this is a presentation-layer re-skin plus splitting two combined cards, not greenfield.

**Grid change (2026-06-01):** Precipitation & Barometer split into separate tiles; Solar & UV split into separate tiles. Today's Highlights shrinks from `full` 4×1 to `wide` 2×1 and moves up to pair with Today's Forecast. The eight stat tiles fill two full 4-column rows below.

```
Row 1:    [Hero 4×1]
Row 2-3:  [Current Conditions 2×2] [Wind Compass 2×2]
Row 4:    [Today's Forecast 2×1]   [Today's Highlights 2×1]
Row 5:    [Precip 1×1] [Barometer 1×1] [Solar Rad 1×1] [UV Index 1×1]
Row 6:    [AQI 1×1] [Sun & Moon 1×1] [Lightning 1×1] [Earthquake 1×1]
Row 7-8:  [Radar 2×2] [Webcam 2×2]
```

**Today's Highlights move (C5 scope, but affects now.tsx grid order):** Today's Highlights shrinks
from `full` 4×1 to `wide` 2×1 and moves UP to Row 4, paired right of Today's Forecast. This
affects the render order in `now.tsx`. The C4 agent wiring task (T2c.9) must ensure the 8 stat tiles
render BELOW the Forecast+Highlights row. The Highlights card itself is NOT re-skinned in C4 — only
its footprint and grid position change. If the Highlights card already has a `footprint` prop,
change it to `"wide"`; if not, add `footprint="wide"`.

### Current code locations
| Surface | File | State | Lines |
|---|---|---|---|
| A. Precipitation | `src/components/precipitation-barometer-card.tsx` | Extracted (split out baro) | 1–184 |
| B. Barometer | `src/components/precipitation-barometer-card.tsx` | Extracted (split out precip) | 1–184 |
| C. Solar Radiation | `src/components/solar-uv-card.tsx` | Extracted (split out UV) | 1–263 |
| D. UV Index | `src/components/solar-uv-card.tsx` | Extracted (split out solar) | 1–263 |
| E. AQI | `src/routes/now.tsx` inline + AqiGauge | Inline — must extract | ~91–160, 392–417 |
| F. Sun & Moon | `src/routes/now.tsx` inline | Inline — must extract | ~418–456 |
| G. Lightning | `src/routes/now.tsx` inline | Inline — must extract | ~458–489 |
| H. Earthquake | `src/routes/now.tsx` inline | Inline — must extract | ~491–521 |

---

## 2. Locked operator directives (2026-06-01)

1. **Grid restructure:** split Precip & Barometer and Solar & UV into separate 1×1 tiles. Today's Highlights shrinks to 2×1, paired right of Today's Forecast.
2. **All stat values render `ConvertedValue.formatted` verbatim.** The BFF controls decimal places and significant figures. No client-side rounding or formatting overrides. Previous mockups that deviated were wrong — BFF output is source of truth.
3. **Icon semantics:** icons represent the *observed measurement*, not a weather condition. No forecast-style icons on observation tiles. E.g. `ph:drop` (raindrop) for precipitation, NOT `ph:cloud-rain`.
4. **Gauge style (for bounded metrics):** semi-circular gauge with thick tick marks (img-21 style), larger indicator/marker, **ticks fill in to the left** of the indicator (progress-arc), value centered inside, endpoints labeled (e.g. "Low" / "High").

---

## 3. Locked constraints (already decided — do NOT re-theorize)

### Universal document reading list (MUST read before any code/mockup)

**TIER 1 — Locking ADRs / token specs:**
- [docs/design/design-tokens-typography.md](../design/design-tokens-typography.md) — LOCKED font families, sizes, weights
- [docs/decisions/ADR-048-theme-color-tokens.md](../decisions/ADR-048-theme-color-tokens.md) — theme colors, accent palette
- [docs/decisions/ADR-049-hero-weather-icons.md](../decisions/ADR-049-hero-weather-icons.md) — hero weather icons (N/A for stat tiles)
- [docs/decisions/ADR-050-utility-stat-nav-icons.md](../decisions/ADR-050-utility-stat-nav-icons.md) — Phosphor base + curated cross-pack; 3 deferred sub-families
- [docs/decisions/ADR-051-card-footprint-model.md](../decisions/ADR-051-card-footprint-model.md) — footprints, glass surface
- [docs/decisions/ADR-047-background-system.md](../decisions/ADR-047-background-system.md) — cards sit over background

**TIER 2 — Process & coding rules:**
- [rules/clearskies-process.md](../../rules/clearskies-process.md)
- [rules/coding.md](../../rules/coding.md) — §5 WCAG 2.1 AA, "Render and LOOK"

**TIER 3 — Design references:**
- [docs/design/mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) — locked footprints (updated 2026-06-01 for the split)
- [docs/design/inspiration/NOTES.md](../design/inspiration/NOTES.md) + specific images opened AS IMAGES

**TIER 4 — Data contracts:**
- [docs/contracts/openapi-v1.yaml](../contracts/openapi-v1.yaml) — `radiation`, `maxSolarRad`, `barometer`, etc.
- [docs/contracts/canonical-data-model.md](../contracts/canonical-data-model.md) — field types, unit groups
- `repos/weewx-clearskies-dashboard/src/api/types.ts` — TS type definitions
- `repos/weewx-clearskies-dashboard/src/hooks/useWeatherData.ts` — data hooks

**TIER 5 — Reference implementations:**
- `repos/weewx-clearskies-dashboard/src/components/WindCompassCard.tsx` — C2 card pattern
- `repos/weewx-clearskies-dashboard/src/components/forecast/NowForecastCard.tsx` — C3 tabbed card

### Footprint
All eight tiles: **`tile` 1×1** (col-span-1 row-span-1). On the 4-col desktop grid (`repeat(4,1fr)`, `gap:1rem`, `grid-auto-rows:5.5rem`) = ~19rem wide × 11rem tall. Tablet 2-col: 1×1. Phone 1-col: full-width, auto height.

### Typography tokens (LOCKED — `design-tokens-typography.md`)
- Card title: `--text-card-title` (0.82rem), Manrope 600 semibold
- Stat numeral: Outfit 600 (size TBD per tile — smaller than C1's 4.75rem and C2's 3rem)
- Body/labels: `--text-body` (0.9rem) / `--text-label` (0.75rem) / `--text-micro` (0.7rem), Manrope 400
- Chart SVG text: `--font-chart` (Lexend)

### Data wiring in now.tsx (how archive data reaches the new tiles)
`now.tsx` already calls `useArchive()` to fetch today's archive records (used by `useTodayStats`).
The Solar Radiation and UV Index tiles need the same archive but with specific fields:
`useArchive({ from: todayStartIso, fields: ['radiation', 'maxSolarRad', 'UV'] })`. Either reuse the
existing call (if it fetches all fields) or add a second call with the chart-specific fields. The
resulting `ArchiveRecord[]` is passed as a `todayArchive` prop to `SolarRadiationCard` and
`UvIndexCard`. The `useObservation` hook (lines 142–166 of `useWeatherData.ts`) returns
`{ observation, barometerTrendDirection, scene, loading, error, refetch }` — the observation object
is what all tiles consume for current values.

### ConvertedValue.formatted vs formatValue()
- **ConvertedValue fields** (`rain`, `rainRate`, `barometer`, `radiation`, `UV`, `windSpeed`, etc.):
  render `.formatted` verbatim (P3). The BFF controls decimal places.
- **Raw number fields** (`aqi.aqi`, `earthquakes[0].magnitude`, `earthquakes[0].depth`, etc.): use
  `formatValue(value, type)` from `utils/format.ts` which has per-type decimal precision.
- **Never invent decimal places.** If a field is ConvertedValue, use `.formatted`. If raw number,
  use `formatValue`.

### Shared sub-component: SemiCircularGauge
The Barometer (T2c.2) builds a reusable `SemiCircularGauge` SVG component at
`src/components/ui/semi-circular-gauge.tsx`. The AQI tile (T2c.5) reuses it with a color-band
mode prop. Props: `value`, `min`, `max`, `label`, `colorMode` ("uniform" | "gradient"),
`colorBands` (optional array of `{from, to, color}`), `endpointLabels` (`[string, string]`).

### Inspiration images (open AS IMAGES before designing any tile)
The mockup agent MUST open these files and look at the pixels before building:
- `docs/design/inspiration/raw/img-21.jpg` — PRIMARY tile grid model (all tiles)
- `docs/design/inspiration/raw/img-19.jpg` — pressure radial gauge (Barometer)
- `docs/design/inspiration/raw/img-14.jpg` — sun/moon arcs (Sun & Moon)
- `docs/design/inspiration/raw/img-28.jpeg` — lightning time-vs-distance scatter (Lightning)
- `docs/design/inspiration/raw/img-11.jpg` — sun arc + moon phase reference (Sun & Moon)
- `docs/design/inspiration/raw/img-18.jpg` — UV severity curve reference (UV — simplified)

### Render-and-LOOK (mandatory)
Headless render command:
```
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu `
  --screenshot="C:\tmp\render.png" --window-size=1400,900 "file:///<absolute-path-to.html>"
```
Then Read the PNG and LOOK. Markup / axe pass ≠ visual verification.

---

## 4. Cross-tile design patterns (accumulating — apply to ALL C4 tiles)

These patterns emerged from operator decisions and apply uniformly. Agents must follow them; deviations require operator approval.

### P1. Text-tile layout: icon-left, text-right
For tiles that are primarily text (no chart/gauge), the title icon sits LEFT of the text block, sized to match the text block height. The icon is decorative (`aria-hidden="true"`); meaning carried by text.

### P2. Icon semantics: observation, not forecast
Icons represent the observed measurement. No forecast-style weather icons on observation tiles (e.g. `ph:drop` not `ph:cloud-rain` for precipitation).

### P3. Values: ConvertedValue.formatted verbatim
Stat values render `ConvertedValue.formatted` from the BFF. No client-side rounding, no hardcoded decimal places, no formatting overrides. The BFF is the source of truth for significant figures.

### P4. Typography: locked tokens only
Outfit 600 for stat numerals. Manrope 600 for card titles. Manrope 400 for labels/secondary. Lexend for chart SVG text. No invented font sizes or families. All from `design-tokens-typography.md`.

### P5. Footprint: all tiles are `tile` 1×1
All eight stat tiles use `<Card footprint="tile">`. No exceptions.

### P6. Semi-circular gauge (bounded metrics)
For bounded metrics (pressure, potentially others), use the img-21 thick-tick semi-circular gauge:
- Thick tick marks around the arc
- Larger indicator/marker showing position
- **Ticks fill in to the left** of the indicator (progress-arc effect)
- Value centered inside the gauge
- Endpoint labels (e.g. "Low" / "High")
- Gauge is the centerpiece — no icon-left layout on gauge tiles.

### P7. Chart + current value layout
When a tile has a chart + current reading, the chart fills the upper portion. The current value anchors below with icon-left/value-right.

### P8. Severity-categorized values: colored dot, not colored text
For EPA/severity-categorized values (UV, AQI), use a **colored dot next to the value** — not colored text. Colored numbers risk failing WCAG contrast against glass surfaces, especially mid-range EPA yellows/oranges on light theme. The dot carries the color signal; the number stays `--foreground`.

### P9. No icons in card titles (1×1 stat tiles)
Card titles are **text-only** (Manrope 600, `--text-card-title`). No icon prefix in the CardHeader. Visual identity comes from the content area: gauges, charts, magnitude badges, or icons next to stat values. Adding title icons on top of content-area icons/visuals makes tiles too busy.

---

## 5. Per-surface spec (operator-approved)

### Surface A — Precipitation

| Field | Source | Treatment |
|---|---|---|
| Rain today | `observation.rain` (ConvertedValue) | Stat numeral (Outfit 600) |
| Rain rate | `observation.rainRate` (ConvertedValue) | Secondary value (Manrope 400) |

- **Layout:** P1 (icon-left, text-right). Icon = `ph:drop`.
- **Title:** "Precipitation" (Manrope 600, `--text-card-title`, text-only per P9).
- **Card:** `<Card footprint="tile">`. No gauge, no chart — text only.
- **Content icon:** `ph:drop` left of the value block (P1).
- **Existing file to split from:** `precipitation-barometer-card.tsx` → new `precipitation-card.tsx`.
- **Data hook:** existing `useRealtimeObservation` (no change).

### Surface B — Barometer

| Field | Source | Treatment |
|---|---|---|
| Pressure | `observation.barometer` (ConvertedValue) | Value centered inside gauge |
| Trend | `barometerTrendDirection` (BFF-derived) | Arrow icon inside gauge (ph:arrow-up/down/right) + text label |

- **Layout:** P6 (semi-circular gauge). Thick-tick arc, filled ticks left of indicator, "Low"/"High" endpoints.
- **Title:** "Barometer" (Manrope 600, text-only per P9). Gauge is the visual identity.
- **Card:** `<Card footprint="tile">`.
- **Existing file to split from:** `precipitation-barometer-card.tsx` → new `barometer-card.tsx`.
- **Data hook:** existing `useRealtimeObservation` + `barometerTrendDirection` (no change).
- **Utilities:** existing `barometerTrendLabel()` from `src/utils/barometer.ts`.

### Surface C — Solar Radiation

| Field | Source | Treatment |
|---|---|---|
| Radiation day chart (actual) | `/archive` today → `radiation` time series | Recharts area/line chart, upper portion of tile |
| Radiation day chart (theoretical) | `/archive` today → `maxSolarRad` time series | Dashed line overlay on same chart (clear-sky ceiling) |
| Current reading | `observation.radiation` (ConvertedValue) | Value below chart, icon-left (`ph:sun`) |

- **Layout:** P7 (chart + current value). Recharts chart fills upper ~70% of tile. Current value anchored below with `ph:sun` icon left of the number.
- **Title:** "Solar Radiation" (Manrope 600, text-only per P9).
- **Card:** `<Card footprint="tile">`.
- **Existing file to split from:** `solar-uv-card.tsx` → new `solar-radiation-card.tsx`.
- **Data hooks:** existing `useRealtimeObservation` (current) + `useArchive({ from: todayStart, fields: ['radiation', 'maxSolarRad'] })` (day chart). `useArchive` already exists in `useWeatherData.ts:341–365`.
- **Chart spec:** Lexend axis labels (`--font-chart`). Actual = solid area fill (accent). Theoretical = dashed line (muted). Minimal axes — Y-axis W/m², X-axis hours. Both fields already in OpenAPI (`radiation`, `maxSolarRad`) and canonical model (`group_radiation`, W/m²).
- **Net-new visualization** (data already exists, never charted in dashboard).

### Surface D — UV Index

| Field | Source | Treatment |
|---|---|---|
| UV day chart (actual) | `/archive` today → `UV` time series | Recharts area/line chart, upper portion of tile (same pattern as Solar Rad) |
| Current UV | `observation.UV` (ConvertedValue) | Value below chart, left position, with EPA category badge |
| Forecast peak UV | `todayForecast.uvIndexMax` (number) | Value below chart, right position, with EPA category badge |

- **Layout:** P7 (chart + current value). Chart fills upper portion. Below: two values side-by-side — current UV (left) + forecast peak UV (right), each with `UvBadge` (colored dot + category label).
- **Title:** "UV Index" (Manrope 600, text-only per P9).
- **Card:** `<Card footprint="tile">`.
- **Existing file to split from:** `solar-uv-card.tsx` → new `uv-index-card.tsx`.
- **Data hooks:** existing `useRealtimeObservation` (current UV) + `useArchive({ from: todayStart, fields: ['UV'] })` (day chart) + `useForecast` for `daily[0].uvIndexMax` (forecast peak). All hooks already exist.
- **Chart spec:** Lexend axis labels. Actual UV = solid area fill with EPA severity gradient coloring (green→yellow→orange→red→purple bands as background reference). Minimal axes — Y-axis UV index, X-axis hours.
- **Sub-components to preserve:** `UvBadge` (colored dot + value + risk label) from existing `solar-uv-card.tsx`. `UV_SEGMENTS` + `getUvSegment()` from `src/utils/uv.ts`.
- **Net-new visualization** (UV archive data exists, never charted in dashboard).

### Surface E — AQI

| Field | Source | Treatment |
|---|---|---|
| AQI value | `aqi.aqi` (number, 0–500) | Value centered inside gauge (Outfit 600) |
| EPA category | `aqi.aqiCategory` (string) | Category label below value inside gauge |
| Main pollutant | `aqi.aqiMainPollutant` (string) | Secondary label below category (Manrope 400, muted) |

- **Layout:** P6 (semi-circular gauge). Same thick-tick style as Barometer, BUT arc segments use **EPA severity color gradient** (green→yellow→orange→red→purple→maroon) instead of uniform fill. Ticks fill in to the left of the indicator with the severity colors. Value + category centered inside.
- **Title:** "AQI" (Manrope 600, text-only per P9). Gauge is the visual identity.
- **Card:** `<Card footprint="tile">`.
- **New file:** `aqi-card.tsx` (extract from `now.tsx` lines 91–160 AqiGauge + 392–417 card rendering).
- **Data hook:** existing `useAqi()` → `/aqi/current` (no change).
- **Gauge arc:** 0–500 range. EPA color bands: 0–50 green, 51–100 yellow, 101–150 orange, 151–200 red, 201–300 purple, 301–500 maroon. Continue using hardcoded `aqiColor()` (EPA palette not tokenized — ADR-048 tracked gap).
- **Deferred:** per-pollutant breakdown (doesn't fit 1×1). EPA palette tokenization (ADR-048 gap, not blocking).
- **ADR-050 icon resolution:** `ph:leaf` chosen by operator for AQI title icon (2026-06-01). Amend ADR-050 to record this pick.

### Surface F — Sun & Moon

| Field | Source | Treatment |
|---|---|---|
| Sun arc | `almanac.sun.rise`, `almanac.sun.set`, current time | Dashed semicircular arc (img-14 style), sun position marker on arc |
| Sunrise / sunset times | `almanac.sun.rise`, `almanac.sun.set` | Time labels below arc endpoints (left = rise, right = set) |
| Moon arc | `almanac.moon.rise`, `almanac.moon.set`, current time | Matching dashed semicircular arc, moon position marker |
| Moonrise / moonset times | `almanac.moon.rise`, `almanac.moon.set` | Time labels below arc endpoints |
| Moon phase | `almanac.moon.phaseName`, `almanac.moon.illuminationPercent` | Phase glyph + phase name |

- **Layout:** Graphical — two stacked arcs (sun above, moon below). NOT a text tile (P1 does not apply). Modeled on img-14 (dashed arc + position marker + endpoint times) with the NOTES upgrade: "moon gets its own matching arch."
- **Title:** "Sun & Moon" (Manrope 600, text-only per P9). Arcs are the visual identity.
- **Card:** `<Card footprint="tile">`.
- **New file:** `sun-moon-card.tsx` (extract from `now.tsx` lines 418–456, rewrite from text to arcs).
- **Data hook:** existing `useAlmanac()` → `/almanac` (no change). Needs `sun.rise`, `sun.set`, `moon.rise`, `moon.set`, `moon.phaseName`, `moon.illuminationPercent`.
- **Arc spec:** SVG dashed semicircular arcs. Sun marker = small sun glyph at current position along the arc (proportional to time between rise/set). Moon marker = small moon glyph. Sunrise/sunset times formatted via existing `formatLocalTime(iso, tz, locale)` using station timezone (ADR-020).
- **Arc layout — TWO OPTIONS, resolve in mockup (render both, pick one):**
  - **Option A — Nested:** larger sun arc with smaller moon arc inside, sharing the same center. Compact, uses vertical space efficiently.
  - **Option B — Stacked:** sun arc top half, moon arc bottom half, each ~half the tile height.
  - Operator picks after seeing both rendered at 1×1 size.
- **ADR-050 icon resolution:** astro sub-family deferred — `ph:moon-stars` as title icon for now. Operator to confirm.
- **Corrects the plan (2026-06-01):** UI-REDESIGN-PLAN.md previously said "mini tile is TEXT-ONLY; arcs → C7." Operator overrides: arcs appear on BOTH the Now mini tile (compact) and C7 Almanac (full detail). Plan updated.

### Surface G — Lightning

| Field | Source | Treatment |
|---|---|---|
| Strike scatter chart | **`lightningStrikeHistory`** (NEW, BFF — 24h rolling buffer of per-strike events) | Recharts scatter: X=time, Y=distance, one dot per strike. 24h window (fall back to 12h if too dense at 1×1 size — resolve in mockup) |
| Strikes in last hour | `lightning.count1h` (BFF-derived) | Below chart, icon-left (`ph:lightning`), primary line |
| Strikes in last 24h | `lightning.count24h` (BFF-derived) | Below chart, secondary line in same text block |
| Nearest distance | `lightning.nearestDistanceKm` | Below chart, secondary line in same text block |

- **Layout:** P7 (chart + current value). Time-vs-distance scatter chart fills upper portion (img-28 approach/recede V-shape pattern). Key stats anchored below.
- **Title:** "Lightning" (Manrope 600, text-only per P9).
- **Card:** `<Card footprint="tile">`.
- **New file:** `lightning-card.tsx` (extract from `now.tsx` lines 458–489, rewrite with chart).
- **Data hooks:** existing `useLightning(observation)` for summary stats. NEW: consume `lightningStrikeHistory` from BFF (see BFF spec below).
- **Chart spec:** Recharts scatter. Lexend axis labels. X=time (24h window), Y=distance. Semi-transparent dots. Minimal gridlines, tight axes. "No activity" state when history is empty.
- **"No activity" state:** when no strikes in window, show centered text message (existing pattern).

#### BFF: Lightning strike rolling buffer (NEW — data layer change)

**Module:** `enrichment/lightning_strike_buffer.py` (new). Same pattern as `enrichment/wind_rolling_window.py` (C2).

- **True wall-clock 86400-second (24h) rolling window.** Store `(timestamp, distance)` pairs from each loop packet that reports a strike. Evict entries older than 24h.
- **Detection:** a new strike is detected when `lightning_strike_count` increments between consecutive packets. Record the packet timestamp + `lightning_distance` at that moment.
- **Registration:** packet tap via `register_processor(...)` (same as wind). `/current` enrichment via `register_enrichment("current", ...)`.
- **Emit:** `lightningStrikeHistory: Array<{time: string, distance: number}>` on both `/current` REST and SSE. Empty array when no strikes. In-memory; resets on restart (acceptable — buffer repopulates from incoming strikes).
- **No min-coverage guard** (unlike wind avg — an empty array is a valid "no activity" state).
- **Contract:** add `lightningStrikeHistory` to OpenAPI Observation schema. Dashboard TS type: `Array<{time: string, distance: number}> | null`.

**This is a data layer change** — corrects the original plan's "no new BFF fields" claim. Scope is bounded: one new module + registration + contract field, same pattern as C2's wind rolling window.

### Surface H — Recent Earthquake

| Field | Source | Treatment |
|---|---|---|
| Magnitude | `earthquakes[0].magnitude` | Magnitude color badge (48×48, "M" + bold value, bg from `magnitudeClasses()`) |
| Place | `earthquakes[0].place` | Semibold, truncate if long |
| Time | `earthquakes[0].time` | Station TZ via `formatTime()`, muted |
| Depth | `earthquakes[0].depth` | Muted metadata row (conditional) |
| Source | `earthquakes[0].source` | Uppercase, muted metadata row |
| PAGER alert | `earthquakes[0].alert` | Colored inline badge (conditional) |

- **Layout:** Reuse the seismic page's earthquake row pattern (`seismic.tsx` lines 400–446). Magnitude color badge left, info block right. Displays the most recent earthquake (`earthquakes[0]`).
- **Magnitude badge:** `h-12 w-12` square, "M" label (text-xs) + value (text-xl font-bold), color-coded via existing `magnitudeClasses()` (sky→green→yellow→orange→red by magnitude).
- **Info block:** place (font-semibold, text-sm, truncate) + magnitudeType in parens, time (text-xs, muted, station TZ), metadata row (depth, source, felt count, tsunami flag, PAGER alert badge — all conditional, flex-wrap).
- **Title:** "Recent Earthquake" (Manrope 600, text-only per P9). Magnitude badge is the visual identity.
- **Card:** `<Card footprint="tile">`.
- **New file:** `earthquake-card.tsx` (extract from `now.tsx` lines 491–521, rewrite to match seismic page row pattern).
- **Data hook:** existing `useEarthquakes()` → `/earthquakes` (no change). Takes `earthquakes[0]`.
- **Shared code:** extract `magnitudeClasses()` (seismic.tsx lines 55–61) and `alertClasses()` (lines 65–73) to a shared utility so both the seismic page and this tile can use them.
- **"No recent earthquakes" state:** centered text message when `earthquakes` is empty or null.
- **ADR-050 icon resolution:** `ph:waves` chosen for earthquake title icon (pending operator confirmation 2026-06-01). Amend ADR-050 to record this pick.

---

## 6. Deferred icon sub-families (ADR-050) — revised

Per P9, **no icons appear in card titles** for C4 tiles. The ADR-050 deferred sub-families (astro, AQI, earthquake) are no longer needed for title icons. Content-area icons are resolved per-surface:

| Tile | Content-area icon | Resolution |
|---|---|---|
| A. Precipitation | `ph:drop` (left of value) | Per ADR-050 stat set |
| B. Barometer | Gauge is the visual; trend arrows `ph:arrow-up/down/right` | Per ADR-050 trend set |
| C. Solar Radiation | `ph:sun` (left of current reading below chart) | Per ADR-050 stat set |
| D. UV Index | Colored EPA dot next to values (P8) | No icon glyph needed |
| E. AQI | Gauge is the visual; no separate icon | No icon glyph needed |
| F. Sun & Moon | Sun/moon position markers on arcs (SVG glyphs) | Graphical, not icon-family |
| G. Lightning | `ph:lightning` (left of stats below chart) | Per ADR-050 alert set |
| H. Earthquake | Magnitude color badge (48×48) | Existing `magnitudeClasses()` pattern |

---

## 7. GRANULAR TASK LIST

Each task: **Owner** (agent) · **Dep** · **Files** · **Do** · **Accept** (pass/fail) · **QC** (different party verifies).

### PHASE 0 — Mockup (design gate; blocks ALL code)

**T0.1 — Build the C4 mockup (all 8 tiles on the real grid)**
- Owner: `clearskies-dashboard-dev` · Dep: none
- Files: `docs/design/mockups/C4-stat-tiles.html` (new)
- Do: Build a single HTML mockup showing all 8 stat tiles at their locked 1×1 footprints inside the real A4 grid (`grid-4col` + `grid-auto-rows:5.5rem`). Include the Forecast 2×1 and Highlights 2×1 above as context (placeholder boxes). Use locked @font-face (Manrope/Outfit/Lexend from `fonts/*.woff2`), type tokens from `design-tokens-typography.md`, grid + glass tokens verbatim from `A4-page-anatomy.html`. Tiles in order: Precipitation, Barometer, Solar Radiation, UV Index (row 1); AQI, Sun & Moon, Lightning, Recent Earthquake (row 2). Each tile at its spec from §5:
  - A (Precip): `ph:drop` icon left, "0.12 in" + "0.00 in/hr" right
  - B (Baro): semi-circular gauge (thick ticks, fill-left, "Low"/"High"), "30.12 inHg" centered, rising arrow
  - C (Solar): mini Recharts-style SVG day chart (actual solid + theoretical dashed), "342 W/m²" below with `ph:sun` left
  - D (UV): mini SVG day chart with EPA severity band colors, "3 Moderate" + "8 Very High" below with colored dots
  - E (AQI): semi-circular gauge with EPA severity gradient arc, "42" + "Good" centered, "PM2.5" below
  - F (Sun & Moon): two SVG arc options (nested AND stacked, side-by-side for comparison), sun/moon position markers, rise/set times
  - G (Lightning): mini scatter chart placeholder (dots at varying distances over 24h), `ph:lightning` + "12 strikes/hr" + "47 strikes/24h" below
  - H (Earthquake): magnitude color badge (48×48) left, "14km SW of Volcano" + "2 hours ago" + "Depth: 8 km" right
- Accept: (1) all 8 tiles at exactly 1×1 inside `.grid-4col`; (2) title text-only, no title icons (P9); (3) fonts match tokens; (4) both themes render; (5) minimal — no extra cards/toggles/galleries.
- QC: **coordinator** renders headless → Reads PNG → LOOKs → iterates. Sun & Moon: present both nested/stacked arc options for operator pick.

**T0.2 — Operator approval gate**
- Owner: coordinator · Dep: T0.1
- Do: present rendered PNG(s) to operator.
- Accept: **operator explicitly approves.** No Phase 1+ task starts until recorded.

### PHASE 1 — Doc corrections (Dep: T0.2)

**T1.1 — Amend ADR-050 (record icon decisions)**
- Owner: `clearskies-docs-author` · Dep: T0.2
- Files: `docs/decisions/ADR-050-utility-stat-nav-icons.md` (edit in place)
- Do: Add a dated note (2026-06-01) recording: C4 stat tiles use **no title icons** (P9); content-area icons resolved per-tile (§6 table); AQI uses `ph:leaf` (not deferred to C6); astro glyphs resolved as SVG arc markers (not icon-family); earthquake uses magnitude badge (not icon-family). Update the deferred sub-families section accordingly. Status → Proposed.
- Accept: `git diff` touches only the deferred/consequences sections + a dated note.
- QC: **coordinator** diff; **operator** re-approves → Accepted.

**T1.2 — Update UI-REDESIGN-PLAN.md (grid change + data layer note)**
- Owner: `clearskies-docs-author` · Dep: T0.2
- Files: `docs/planning/UI-REDESIGN-PLAN.md` (edit in place)
- Do: Update C4 description to note: (1) data layer change for lightning strike buffer (corrects "no new BFF fields"); (2) Sun & Moon has dual arcs on the Now mini tile (corrects "TEXT-ONLY"). Most grid changes already landed (2026-06-01).
- Accept: C4 section accurate vs this brief; no contradictions.
- QC: **coordinator** diff.

### PHASE 2 — Implementation (Dep: T0.2; BFF, contract, and dashboard tasks parallelize where noted)

#### BFF (realtime repo)

**T2a.1 — BFF: Lightning strike buffer module**
- Owner: `clearskies-realtime-dev` · Dep: T0.2
- Files: `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/enrichment/lightning_strike_buffer.py` (new)
- Do: Create `LightningStrikeBuffer` class following `wind_rolling_window.py` pattern (lines 56–121). True wall-clock **86400-second (24h)** rolling window. Store `(timestamp_iso, distance)` pairs. Detection: strike detected when `lightning_strike_count` increments between consecutive packets. Record packet timestamp + `lightning_distance`. Evict entries >24h. Thread-safe lock (like `wind_rolling_window`). No min-coverage guard (empty array = valid "no activity"). `process_packet(packet)` feeds the buffer (read-only, no packet mutation). `get_strike_history()` returns `List[Dict[str, Any]]` with `{time: str, distance: float}` entries. `reset()` for test isolation.
- Accept: `ruff` + `mypy` clean; no packet mutation; returns empty list before any strikes; evicts past 24h.
- QC: **auditor** + T2a.4 tests.

**T2a.2 — BFF: Register tap + /current enrichment**
- Owner: `clearskies-realtime-dev` · Dep: T2a.1
- Files: `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/__main__.py` (add registrations after line 293, alongside existing wind registrations)
- Do: `register_processor(lightning_process_packet)`; `register_enrichment("current", enrich_lightning_history)`. The enrichment injects `lightningStrikeHistory: [...]` into the `/current` envelope (mirror the `enrich_wind_rolling_average` pattern at `wind_rolling_window.py:229–263`).
- Accept: service boots; tap invoked per packet (log/test proof); `/current` carries `lightningStrikeHistory` array.
- QC: auditor.

**T2a.3 — BFF: Emit on SSE**
- Owner: `clearskies-realtime-dev` · Dep: T2a.1
- Files: `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/units/transformer.py` (`add_derived_fields`, alongside beaufort/wind injection)
- Do: Inject `lightningStrikeHistory` into SSE JSON when present. The array passes through as-is (no unit conversion — distances already in the station's configured unit from the packet).
- Accept: SSE JSON shows `lightningStrikeHistory` array after first strike; empty array when no strikes.
- QC: T2a.4 + manual SSE capture.

**T2a.4 — BFF: Tests**
- Owner: `clearskies-realtime-dev` · Dep: T2a.1–T2a.3
- Files: `repos/weewx-clearskies-realtime/tests/test_lightning_strike_buffer.py` (new) — follow `tests/test_wind_rolling_window.py` pattern
- Do: Cases — no strikes ⇒ empty array; single strike recorded with correct timestamp+distance; count increment detection (only records on increment, not every packet); eviction past 86400s; multiple strikes accumulate; reset() isolation; thread safety. Full realtime suite no new failures.
- Accept: **pytest output pasted: N passed / 0 failed**; full suite no regressions.
- QC: **auditor** re-runs pytest independently.

#### Contract

**T2b.1 — Contract: OpenAPI + TS types**
- Owner: `clearskies-dashboard-dev` · Dep: T0.2
- Files: `docs/contracts/openapi-v1.yaml` (authoritative) + `repos/weewx-clearskies-dashboard/src/api/openapi-v1.yaml` (sync) + `repos/weewx-clearskies-dashboard/src/api/types.ts` (Observation interface, after lightning fields at ~line 179)
- Do: Add `lightningStrikeHistory` to Observation schema: `type: array, items: {type: object, properties: {time: {type: string}, distance: {type: number}}}, nullable: true`. TS type: `lightningStrikeHistory?: Array<{time: string; distance: number}> | null`. Update `LightningData` interface (~line 705) or create new type alongside it.
- Accept: yaml valid; `tsc` 0 errors.
- QC: coordinator.

#### Dashboard — split & extract (can run in parallel with BFF once contract field names are fixed)

**T2c.1 — Split: precipitation-card.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2b.1
- Files: `repos/weewx-clearskies-dashboard/src/components/precipitation-card.tsx` (new)
- Do: Extract precipitation section from `precipitation-barometer-card.tsx` (lines 127–155). New component: `PrecipitationCard`. Props: `observation`, `loading`, `error`, `onRetry`. Use `<Card footprint="tile">`. Layout: P1 (icon-left `ph:drop`, text-right). Render `rain` + `rainRate` via `ConvertedValue.formatted` (P3). Title text-only "Precipitation" (P9). Outfit 600 for stat numeral, Manrope 400 for labels.
- Accept: `tsc` 0 errors; renders rain + rate; no barometer content.
- QC: coordinator diff + T2c.10 render-and-LOOK.

**T2c.2 — Split: barometer-card.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2b.1
- Files: `repos/weewx-clearskies-dashboard/src/components/barometer-card.tsx` (new)
- Do: Extract barometer section from `precipitation-barometer-card.tsx` (lines 156–184). New component: `BarometerCard`. Props: `observation`, `barometerTrendDirection`, `loading`, `error`, `onRetry`. Use `<Card footprint="tile">`. Layout: P6 (semi-circular gauge — thick ticks, fill-left, "Low"/"High" endpoints). Value centered (`ConvertedValue.formatted`), trend arrow inside gauge. Title text-only "Barometer" (P9). Build gauge as SVG (reusable `SemiCircularGauge` sub-component for AQI to share).
- Accept: `tsc` 0 errors; gauge renders with trend; no precipitation content.
- QC: coordinator diff + T2c.10 render-and-LOOK.

**T2c.3 — Split: solar-radiation-card.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2b.1
- Files: `repos/weewx-clearskies-dashboard/src/components/solar-radiation-card.tsx` (new)
- Do: Extract solar section from `solar-uv-card.tsx`. New component: `SolarRadiationCard`. Props: `observation`, `todayArchive` (ArchiveRecord[]), `loading`, `error`, `onRetry`. Use `<Card footprint="tile">`. Layout: P7 (chart above, value below). Recharts `AreaChart` with `radiation` (solid fill, accent) + `maxSolarRad` (dashed line, muted) from `todayArchive`. Current value below with `ph:sun` icon-left. Title text-only "Solar Radiation" (P9). Chart: Lexend axis labels, minimal Y (W/m²) + X (hours).
- Accept: `tsc` 0 errors; chart renders with both series; current value shows `formatted`.
- QC: coordinator diff + T2c.10 render-and-LOOK.

**T2c.4 — Split: uv-index-card.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2b.1
- Files: `repos/weewx-clearskies-dashboard/src/components/uv-index-card.tsx` (new)
- Do: Extract UV section from `solar-uv-card.tsx`. New component: `UvIndexCard`. Props: `observation`, `todayArchive`, `todayForecast`, `loading`, `error`, `onRetry`. Use `<Card footprint="tile">`. Layout: P7 (chart above, values below). Recharts chart with UV time series from `todayArchive`, EPA severity gradient bands as reference. Below: two values side-by-side — current UV (left) + forecast peak UV (right), each with `UvBadge` (colored dot + category, P8). Preserve existing `UvBadge` from `solar-uv-card.tsx:119–137` and `UV_SEGMENTS`/`getUvSegment()` from `utils/uv.ts`. Title text-only "UV Index" (P9).
- Accept: `tsc` 0 errors; chart renders; both current + forecast values show with badges.
- QC: coordinator diff + T2c.10 render-and-LOOK.

**T2c.5 — Extract: aqi-card.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2c.2 (shares SemiCircularGauge)
- Files: `repos/weewx-clearskies-dashboard/src/components/aqi-card.tsx` (new)
- Do: Extract AQI from `now.tsx` lines 91–160 (AqiGauge) + 392–417 (card). New component: `AqiCard`. Props: `aqi` (AQIReading | null), `loading`, `error`, `onRetry`. Use `<Card footprint="tile">`. Layout: P6 (semi-circular gauge with EPA severity gradient arc). Reuse `SemiCircularGauge` from T2c.2 with color-band mode. Value + category + pollutant centered inside gauge. Title text-only "AQI" (P9). Continue hardcoded `aqiColor()` for EPA palette.
- Accept: `tsc` 0 errors; gauge renders with severity colors; category + pollutant shown.
- QC: coordinator diff + T2c.10 render-and-LOOK.

**T2c.6 — Extract: sun-moon-card.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2b.1
- Files: `repos/weewx-clearskies-dashboard/src/components/sun-moon-card.tsx` (new)
- Do: Extract Sun & Moon from `now.tsx` lines 418–456. Full rewrite to dual-arc SVG (not text). New component: `SunMoonCard`. Props: `almanac` (AlmanacSnapshot | null), `loading`, `error`, `onRetry`, `stationTz`. Use `<Card footprint="tile">`. Layout: two SVG arcs (operator picks nested vs stacked in T0.2). Sun arc: dashed semicircle, sun position marker proportional to `(now - sunrise) / (sunset - sunrise)`, rise/set times at endpoints. Moon arc: matching style, moon position marker, rise/set times, phase glyph + phase name. Title text-only "Sun & Moon" (P9). Use existing `formatLocalTime()` (extract from now.tsx lines 41–50 to a shared util if not already shared).
- Accept: `tsc` 0 errors; arcs render with position markers; times correct in station TZ.
- QC: coordinator diff + T2c.10 render-and-LOOK.

**T2c.7 — Extract: lightning-card.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2b.1, T2a.1 (needs contract type for `lightningStrikeHistory`)
- Files: `repos/weewx-clearskies-dashboard/src/components/lightning-card.tsx` (new)
- Do: Extract Lightning from `now.tsx` lines 458–489. Full rewrite with chart. New component: `LightningCard`. Props: `observation` (Observation | null), `lightning` (LightningData | null), `loading`, `error`. Use `<Card footprint="tile">`. Layout: P7 (scatter chart above, stats below). Recharts `ScatterChart` with X=time (24h window), Y=distance from `observation.lightningStrikeHistory`. Semi-transparent dots. Below: `ph:lightning` icon-left, text block with 1h count + 24h count + nearest distance. Title text-only "Lightning" (P9). "No activity" centered text when history empty and no counts.
- Accept: `tsc` 0 errors; scatter chart renders with sample data; stats show below; no-activity state works.
- QC: coordinator diff + T2c.10 render-and-LOOK.

**T2c.8 — Extract: earthquake-card.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2b.1
- Files: `repos/weewx-clearskies-dashboard/src/components/earthquake-card.tsx` (new) + `repos/weewx-clearskies-dashboard/src/utils/earthquake.ts` (new — shared magnitude/alert utilities)
- Do: Extract Earthquake from `now.tsx` lines 491–521. Rewrite using seismic page row pattern (`seismic.tsx` lines 400–446). New component: `EarthquakeCard`. Props: `earthquakes` (EarthquakeRecord[] | null), `loading`, `error`, `onRetry`, `stationTz`. Use `<Card footprint="tile">`. Layout: magnitude color badge (48×48) left, info block right (place, time, depth/source/PAGER). Extract `magnitudeClasses()` (seismic.tsx:55–61) and `alertClasses()` (seismic.tsx:65–73) to shared `utils/earthquake.ts`. Title text-only "Recent Earthquake" (P9). "No recent earthquakes" state when empty.
- Accept: `tsc` 0 errors; badge renders with correct colors; info block matches seismic page pattern.
- QC: coordinator diff + T2c.10 render-and-LOOK.

**T2c.9 — Wire into now.tsx + delete dead code**
- Owner: `clearskies-dashboard-dev` · Dep: T2c.1–T2c.8
- Files: `repos/weewx-clearskies-dashboard/src/routes/now.tsx`
- Do: Import all 8 new card components. Replace inline AQI/Sun&Moon/Lightning/Earthquake code (lines ~91–160, 392–521). Replace `<PrecipitationBarometerCard>` and `<SolarUvCard>` imports with the 4 new split components. Wire `todayArchive` from existing `useArchive` for Solar Rad + UV charts. Delete old `precipitation-barometer-card.tsx` and `solar-uv-card.tsx` (dead after split). Delete inline `AqiGauge`, `formatLocalTime` (if moved to shared util), `formatPhaseName`, `aqiColor`, `aqiCategory`. Ensure grid order matches §1 layout diagram. **No commented-out code, no unused imports.**
- Accept: `tsc` 0 errors; `vite build` clean; `grep` confirms old inline components gone; 8 tile cards render on Now page.
- QC: coordinator diff.

**T2c.10 — Render-and-LOOK + axe (both themes)**
- Owner: `clearskies-dashboard-dev` · Dep: T2c.9
- Do: Build, start dev server, screenshot all 8 tiles in **both themes** (light + dark). Read the PNGs. Fix what's wrong, re-render. Run `@axe-core` on the Now page.
- Accept: render matches mockup; gauges/charts/arcs visible; typography matches tokens; **axe 0 new violations both themes**; contrast pass.
- QC: **coordinator** inspects PNGs (not markup).

**T2c.11 — i18n keys**
- Owner: `clearskies-dashboard-dev` · Dep: T2c.1–T2c.8
- Files: `repos/weewx-clearskies-dashboard/public/locales/en/common.json` (or relevant namespace)
- Do: Add keys for all 8 tile titles + labels: "Precipitation", "Barometer", "Solar Radiation", "UV Index", "AQI", "Sun & Moon", "Lightning", "Recent Earthquake", "No activity", "No recent earthquakes", "strikes/hr", "strikes/24h", "Nearest", "Low", "High", "Rising", "Falling", "Steady", "Sunrise", "Sunset", "Moonrise", "Moonset", "Current", "Forecast peak". En seeded; fallback safe.
- Accept: `grep` finds no hardcoded UI strings in new components; en keys present.
- QC: auditor.

### PHASE 3 — Audit (Dep: all Phase 2)

**T3.1 — Independent audit**
- Owner: `clearskies-auditor` · Dep: T2a–T2c all
- Do: Review every diff against this brief's §5 specs, ADR-050 amendment, locked token docs, `rules/coding.md` §5 a11y + security baseline; confirm render-and-LOOK evidence exists; **independently re-run the realtime + dashboard test suites**; report findings via mailbox. **No implementation, no push.**
- Accept: written report; **0 unresolved high/critical**; attaches test outputs + screenshots.
- QC: **coordinator** reads report and routes any finding back to the owning Phase-2 task.

### PHASE 4 — Deploy + live verify (Dep: T3.1; requires operator "push")

**T4.1 — Commit review, push (on operator word), deploy, verify live**
- Owner: coordinator · Dep: T3.1
- Do: Review local commits across repos; **push only when operator types "push"**; deploy to weather-dev; after BFF warm-up verify: `/current` carries `lightningStrikeHistory`; all 8 tiles render live in both themes; Solar Rad + UV charts show real archive data; gauges show real pressure + AQI; Sun & Moon arcs show correct times; Lightning scatter populates as strikes arrive; Earthquake shows most recent.
- Accept: **live evidence pasted** (curl `/current` excerpt, card screenshots both themes); operator confirms.

---

## 8. Dependency graph

```
T0.1 → T0.2 (GATE) → { T1.1, T1.2 }
                    → T2a.1 → (T2a.2, T2a.3) → T2a.4
                    → T2b.1
                    → T2c.1 ─┐
                    → T2c.2 ─┤ (T2c.2 builds SemiCircularGauge)
                    → T2c.3 ─┤
                    → T2c.4 ─┤
                    → T2c.5 ─┤ (depends on T2c.2 for shared gauge)
                    → T2c.6 ─┤
                    → T2c.7 ─┤ (depends on T2b.1 for lightningStrikeHistory type)
                    → T2c.8 ─┤
                              ↓
                           T2c.9 → T2c.10, T2c.11
                              ↓
                           T3.1 → T4.1
```

- **T2a.* (BFF)** and **T2c.* (dashboard)** run in PARALLEL once T2b.1 (contract) fixes field names.
- T2c.5 (AQI gauge) depends on T2c.2 (Barometer gauge) sharing `SemiCircularGauge`.
- T2c.7 (Lightning card) depends on T2b.1 for the TS type of `lightningStrikeHistory`.
- T2c.9 (wiring) waits for all 8 components.

## 9. QC ownership

| Party | Responsibilities |
|---|---|
| **Coordinator** | Mockup render-and-LOOK (T0.1), diff reviews, operator liaison, the only party who pushes. Inspects PNGs not markup. |
| **clearskies-auditor** | Independent re-run of realtime + dashboard suites + ADR/rules/a11y/security conformance (T3.1). |
| **Operator** | Approves the mockup (T0.2), approves ADR-050 amendment (T1.1), authorizes push (T4.1), picks nested vs stacked arcs for Sun & Moon. |

## 10. Verification bar (end-to-end "done" definition)

- **BFF:** `pytest` in realtime repo — new `test_lightning_strike_buffer.py` green + full suite no regressions.
- **Dashboard:** `tsc --noEmit` 0 errors + `vite build` clean + `@axe-core` 0 new violations in **both** themes.
- **Render-and-LOOK:** headless screenshots of BOTH the mockup and the built tiles; Read each PNG:
  - 8 tiles at 1×1 in the grid, correct order (Precip/Baro/Solar/UV row 1; AQI/SunMoon/Lightning/Earthquake row 2)
  - No title icons (P9)
  - Gauges: thick ticks, fill-left, value centered (Baro + AQI)
  - Charts: Solar Rad (actual+theoretical), UV (actual+severity bands), Lightning (scatter dots)
  - Sun & Moon: dual arcs with position markers + times
  - Earthquake: magnitude color badge + info block
  - Typography: Outfit numerals, Manrope labels, Lexend chart text
  - Both themes readable; glass surface visible
- **Live (weather-dev):** after BFF warm-up, `/current` carries `lightningStrikeHistory`; all 8 tiles render with real data; Solar/UV charts show today's archive; arcs show correct station-TZ times.

## 11. Implementation reference — verified file:line

**Dashboard (`repos/weewx-clearskies-dashboard/src/`):**
- Card primitive: `components/ui/card.tsx` — footprint type line 6; column mappings lines 23–28
- Existing precip+baro card: `components/precipitation-barometer-card.tsx` (184 lines) — Card at line 109 (NO footprint prop), precip section 127–155, baro section 156–184
- Existing solar+UV card: `components/solar-uv-card.tsx` (263 lines) — Card at line 174 (NO footprint prop), solar 193–207, UV 208+, UvBar 61–113, UvBadge 119–137
- Inline AQI: `routes/now.tsx` — AqiGauge 91–160, card rendering 392–417
- Inline Sun & Moon: `routes/now.tsx:418–456` — formatLocalTime 41–50, formatPhaseName 52–55
- Inline Lightning: `routes/now.tsx:458–489` — useLightning result
- Inline Earthquake: `routes/now.tsx:491–521` — earthquakes[0]
- Seismic page row pattern: `routes/seismic.tsx:400–446` — magnitude badge 402–410, info block 412–445, magnitudeClasses 55–61, alertClasses 65–73
- Observation type: `api/types.ts:139–211` — lightning fields 175–179, LightningData 705–710
- Data hooks: `hooks/useWeatherData.ts` — useObservation 142–166, useArchive 341–365, useAqi 270–288, useAlmanac 225–241, useEarthquakes 247–264, useLightning 507–527
- Barometer util: `utils/barometer.ts` (37 lines) — BarometerTrendDirection :15, trendArrow :21, trendLabel :32
- UV util: `utils/uv.ts` (69 lines) — UV_SEGMENTS :40, getUvSegment :54, getUvLabel :65
- Format util: `utils/format.ts` (32 lines) — formatValue :27 (per-type decimal precision)
- CSS tokens: `index.css:5–13` (font imports), `index.css:18–30` (theme vars)
- C2 reference: `components/WindCompassCard.tsx` — Card structure, footprint="wide", Phosphor icon, Outfit numerals, aria-live

**BFF (`repos/weewx-clearskies-realtime/weewx_clearskies_realtime/`):**
- Wind rolling window (our template): `enrichment/wind_rolling_window.py` — TimeWindowedBuffer 56–121, process_packet, enrich fn 229–263
- Packet tap registration: `enrichment/packet_tap.py:25–40` — `register_processor(fn)` signature
- Startup registrations: `__main__.py:264–293` — existing processor + enrichment calls (add ours after line 293)
- SSE derived-field injection: `units/transformer.py` `add_derived_fields()` — beaufort block ~207–252

**Contracts:**
- OpenAPI: `docs/contracts/openapi-v1.yaml` — lightning fields at ~line 1136
- Canonical model: `docs/contracts/canonical-data-model.md` — group_distance line 56

## 12. Out of scope

- No changes to the API repo (except OpenAPI yaml sync) — all new data comes from the BFF.
- No other Now-page cards (C1/C2/C3 are done; C5/C6 are future).
- No operator drag-grid engine.
- No per-pollutant AQI breakdown (deferred).
- No UV bell-curve full detail (deferred — chart is simplified).
- No Sun/Moon full-detail arcs (C7 Almanac owns the expanded version).
- No lightning weewx extension (long-term, out of C4 scope).
- No EPA AQI palette tokenization (ADR-048 tracked gap, not blocking).

---

*Brief started 2026-06-01 during step 0 card-by-card operator review. All 8 surfaces operator-approved. Granular tasks, QC gates, and implementation references completed.*
