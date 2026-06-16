# Charts System Fixit — Execution Plan

**Status:** COMPLETE — executed 2026-06-06/07
**Component:** ConfigDrivenChart + ConfigDrivenGroup rendering defaults + migration tool defaults injection
**Parent:** [CHARTS-REWRITE-PLAN.md](docs/planning/briefs/CHARTS-REWRITE-PLAN.md), [CHARTS-FIXIT.md](docs/planning/briefs/CHARTS-FIXIT.md)
**Research:** [belchertown-chart-defaults.md](docs/reference/belchertown-chart-defaults.md)

---

## Cold-start context (read this first in a new session)

### What this project is
Clear Skies is a from-scratch modern weather UI replacing the Belchertown weewx skin. The configurable charts system renders charts from `charts.conf` (migrated from Belchertown's `graphs.conf`). The charts page is live on weather-dev but looks terrible compared to Belchertown because the renderer was built without studying Belchertown's hardcoded rendering defaults.

### What was already done (prior session, 2026-06-06)
- **Phase 0 complete:** Migration tool injects axis labels, number formats, observation aliases. Commit `302c69a` on API repo.
- **Phase 1 complete:** Data pipeline fixes (field collection, custom SQL, climatology map) already implemented by earlier sessions.
- **Phase 2+4 partial:** Compass labels on wind axis (T2.3), tooltip number formatting (T2.4), softMin/Max and borderWidth wiring (T4.1) done. Commit `d08c03b` + `bb4cde3` on dashboard repo.
- **API parser fix:** numberFormat, softMin/Max, borderWidth now flow through API response. Commit `406bfd4`.
- **Deployed:** Both repos pushed and deployed to weather-dev (dashboard) and weewx container (API).
- **webcam.json fix:** Moved from web root to `/etc/weewx-clearskies/`. Caddy route added. Stack repo commit `45bdf0a`.

### What's left (THIS PLAN)
13 visual defects (F1–F13) found during operator side-by-side review. Root causes: markers shown by default (Belchertown disables them), Y-axis doesn't auto-scale (Recharts includes 0), X-axis ticks overcrowded, no theme-responsive colors, date buttons outside card, wind rose empty.

### Repo locations
| Repo | Local path | Branch |
|------|-----------|--------|
| Dashboard | `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard` | main |
| API | `c:\CODE\weather-belchertown\repos\weewx-clearskies-api` | main |
| Meta (plans, rules, ADRs) | `c:\CODE\weather-belchertown` | master |

### Key files to read before acting
1. `CLAUDE.md` — project rules, domain routing, operating posture
2. `rules/coding.md` — §5 WCAG, §6 Recharts rules, §7 build verification (ZERO TS errors)
3. `rules/clearskies-process.md` — agent orchestration, scope binding, QC gates, API startup ~120s
4. `docs/reference/recharts-axis-reference.md` — MANDATORY before any Recharts changes
5. `docs/reference/belchertown-chart-defaults.md` — Belchertown's hardcoded Highcharts defaults (the gap analysis)
6. `src/components/almanac/MonthlyAveragesCard.tsx` (dashboard repo) — reference implementation for quality bar
7. `src/components/charts/ConfigDrivenChart.tsx` (dashboard repo) — the renderer being fixed
8. `src/components/charts/ConfigDrivenGroup.tsx` (dashboard repo) — data pipeline + layout
9. `src/lib/chart-contrast.ts` (dashboard repo) — theme-responsive color contrast utility

### Belchertown comparison target
- Live: `https://weather.shaneburkhardt.com/graphs/`
- Source: `docs/snapshots/server-skin-2026-04-29/Belchertown/js/belchertown.js.tmpl`

### Deployment
- Dashboard: push to GitHub, then `ssh weather-dev` and run `scripts/redeploy-weather-dev.sh` (or manual: git pull + npm ci --legacy-peer-deps + npm run build + rsync)
- API: push to GitHub, then `ssh ratbert "lxc exec weewx -- bash -c '...'"` (git pull + pip install + systemctl restart). **API takes ~120 seconds to start** (cache warmer).
- Charts config: run migration tool on weewx container, restart API, flush Redis (`redis-cli FLUSHDB`).
- Config files live in `/etc/weewx-clearskies/` — NEVER in the web root (rsync --delete destroys them).

---

## Context

Side-by-side visual comparison of deployed Clear Skies charts vs Belchertown revealed 13 rendering defects (documented in CHARTS-FIXIT.md as F1–F13). Root cause: the renderer was built without studying Belchertown's `belchertown.js.tmpl` plotOptions — the hardcoded Highcharts defaults that make charts look good regardless of operator config. Research into `belchertown.js.tmpl` and `belchertown.py` extracted every rendering default (documented in `docs/reference/belchertown-chart-defaults.md`).

**Design decisions (from operator dialog 2026-06-06):**
- **Colors:** Belchertown's 10-color palette stays (already in charts.conf, flows through API). Dashboard adapts for theme contrast via `ensureChartContrast()`. No separate color config file. No API changes — colors are presentation, dashboard-only.
- **Special axis handling:** Barometer 2-decimal precision, rain yAxisMin=0, windDir tickInterval=90 — injected into charts.conf by migration tool so operator can edit.
- **Chart type default:** Stays `"line"` (matches Belchertown). Operator overrides via charts.conf `type = spline`.
- **Almanac MonthlyAveragesCard:** Refactored to use same `ensureChartContrast()` instead of inline `isDark ?` ternaries.

---

## Operator-reported defects (from visual review 2026-06-06)

These are the operator's exact observations, with screenshots. Each one is a hard acceptance criterion — the fix is not done until the operator's described expectation is met.

### F1 — No default color scheme; not theme-responsive
Charts have no default color assignments per observation type. Colors must respond to light/dark theme changes (like the Almanac's MonthlyAveragesCard does — e.g., `isDark ? '#c084fc' : '#a855f7'` for dewpoint). Each observation type needs a consistent default color across all charts, and those colors must adapt to the current theme.

### F2 — Date range buttons (1d/3d/7d/30d/90d) floating outside the card
The 1d/3d/7d/30d/90d buttons float in empty space between the tab bar and the card. They must be inside the card, tied to the card layout.

### F3 — Y-axis does not auto-scale to data range
Y-axis shows a fixed range (0–80) instead of scaling to the actual data range. Belchertown auto-scales the Y-axis tightly around the data (e.g., 55–75 for temperature data in the 60–73 range). No hardcoded min/max unless the operator explicitly sets yAxisMin/yAxisMax.

### F4 — X-axis does not auto-scale; ticks are overcrowded
X-axis shows every single time label (9 PM, 10 PM, 10 PM, 1 AM, 1 AM, 2 AM...) — duplicated, overlapping, unreadable. Belchertown auto-scales X-axis ticks to fit the width (e.g., "3 Jun", "04:00", "08:00", "12:00", "16:00", "20:00"). Must show reasonable intervals with no duplicates or overlap.

### F5 — Data point markers shown on every point; lines invisible
Every single data point has a circle marker rendered, making lines completely invisible under a wall of dots. With 5-minute archive data over 24 hours, that's ~288 markers per series. Belchertown does NOT show markers for line/spline charts — clean lines only. Markers should only appear on hover (activeDot) or for scatter charts (lightning/windDir).

### F6 — Chart exceeds its container width
The chart visually overflows its card/container horizontally. Related to X-axis tick overflow.

### F7 — Wind chart: markers on windSpeed/windGust lines (same root cause as F5)
Wind Speed and Wind Gust have circle markers on every data point, lines buried under dots. These should be clean lines with NO markers. Wind Direction as scatter dots IS correct — that's the intended rendering.

### F8 — Wind Direction scatter dots: wrong color, not theme-responsive
windDir dots are white/light gray — they blend into the dark background and would be invisible in light mode. Belchertown uses a distinct blue. Need a theme-responsive color that contrasts in both themes.

### F9 — Wind Rose not rendering data; no chart title
Wind rose shows an empty polar chart — concentric circles and compass labels but NO data wedges. Missing chart title. Belchertown shows colored wedges radiating from center with Beaufort speed color coding. Our chart shows 0.0% Calm and empty rings — data is not being fetched, binned, or rendered.

### F10 — "Wind Rose Data - percentage..." text fixed on page
A line of text related to wind rose data is position-fixed on the page and does not scroll with content. This is a rendering artifact that needs removed entirely.

### F11 — Rain chart: markers on every data point (same root cause as F5)
Rain Rate and Rain Total lines have markers on every data point, making lines hard to read. Same default marker issue.

### F12 — Barometer chart completely broken
Multiple compounding issues: (1) Y-axis not auto-scaling — shows 0.00 at bottom, data at ~29.9–30.05 so line is flat at top. (2) Markers on every point. (3) X-axis overcrowded. (4) Chart overflows container. Barometer is the worst-case example because the tight data range (0.15 inHg span) against a 0–30 Y-axis makes the line completely flat. Expected: Y-axis 29.900–30.050, clean spline, fine tick intervals (0.025 inHg), auto-scaled X-axis.

### F13 — Solar Radiation and UV: markers on every point (same root cause as F5)
Solar Radiation, Theoretical Max Solar Radiation, and UV Index all have markers on every data point. Chart structure is otherwise OK (dual axes, area fill on maxSolarRad). Colors are not ideal but may be a graphs.conf configuration issue — Belchertown does NOT hardcode per-observation colors, they come from the `colors` array in graphs.conf.

---

## 0. Orientation

- **Load:** [CLAUDE.md](CLAUDE.md), [rules/coding.md](rules/coding.md) (§5 WCAG, §6 Recharts, §7 build verification), [rules/clearskies-process.md](rules/clearskies-process.md), [docs/reference/recharts-axis-reference.md](docs/reference/recharts-axis-reference.md), [docs/reference/belchertown-chart-defaults.md](docs/reference/belchertown-chart-defaults.md)
- **Repos:** `weewx-clearskies-dashboard` (Phases A–C), `weewx-clearskies-api` (Phase D)
- **Reference implementation:** `src/components/almanac/MonthlyAveragesCard.tsx` — quality bar
- **Deploy:** Dashboard on weather-dev (`scripts/redeploy-weather-dev.sh`), API on weewx container. API startup takes ~120 seconds (cache warmer).

### Git safety
Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree.

---

## 1. Defect inventory

### Root cause → defect mapping

| Root cause | Defects | Fix phase |
|-----------|---------|-----------|
| `dotProp` returns `undefined` → Recharts shows markers on every point | F5 (temperature), F7 (wind), F11 (rain), F13 (solar/UV) | A1 |
| Recharts Y-axis domain defaults to include 0 | F3 (temperature Y-axis), F12 (barometer flat at top) | A2 |
| No `minTickGap` on XAxis → overcrowded/duplicate labels | F4 (X-axis ticks), F6 (chart overflow) | A3 |
| No theme-responsive color adaptation | F1 (all charts), F8 (windDir invisible in dark) | A4 |
| Barometer Y-axis no decimal formatting | F12 (barometer ticks show integers) | A5 |
| Date range buttons rendered outside Card | F2 | B1 |
| Wind rose data not rendering | F9 | C1 |
| Wind rose missing chart title | F9 (partial) | C2 |
| Fixed-position "Wind Rose Data" text artifact | F10 | C3 |
| Migration tool doesn't inject markerEnabled defaults | All marker issues compound | D1 |
| Migration tool doesn't inject axis defaults | Barometer/rain axis issues compound | D2 |

---

## 2. Implementation phases

### PHASE A — Renderer defaults (Dashboard repo)

All Phase A tasks modify the same repo. Single agent handles A1–A5 together. A6 is a separate small task.

**T-A1 — Disable markers by default on line/spline/area (fixes F5, F7, F11, F13)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (visual render — verify clean lines, no dots)
- File: `src/components/charts/ConfigDrivenChart.tsx`
- Scope in: Lines 159-166, the `dotProp` computation
- Scope out: Do NOT change scatter rendering (line 251-268). Do NOT change `activeDot` behavior.
- Do: Change line 165 from `return undefined;` to `return false;`. This makes markers OFF by default for line/spline/area, matching Belchertown's `plotOptions.line.marker.enabled = false`. Markers still show when `markerEnabled = true` is set in config (lines 161-164). Scatter series already force `dot={{ r: markerRadius ?? 4 }}` at line 264 — unaffected.
- Before:
  ```typescript
  return undefined; // let Recharts decide
  ```
- After:
  ```typescript
  return false; // Belchertown default: markers off on line/spline/area
  ```
- Accept: Temperature chart shows 4 clean lines with NO circle markers. Wind chart shows clean windSpeed/windGust lines. windDir still shows scatter dots. Rain shows clean lines. Solar/UV shows clean lines/areas.
- Verification: Visual render of all chart types on the charts page.

**T-A2 — Y-axis auto-scale to data range (fixes F3, F12)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify barometer Y-axis range)
- File: `src/components/charts/ConfigDrivenChart.tsx`
- Scope in: Lines 375-395 (left domain), lines 397-421 (right domain)
- Scope out: Do NOT change wind direction domain (line 401-403, already `[0, 360]`). Do NOT change hard min/max or softMin/softMax logic.
- Do: Change the default return from `undefined` to `['auto', 'auto']` at line 394 and line 420. Recharts with `undefined` domain includes 0 in the range; `['auto', 'auto']` scales tight to the actual data.
- Additionally: Add observation-type-aware override for rain/rainRate/rainTotal — after computing the base domain, if the axis carries rain data, force the domain minimum to 0 (rain can't be negative; matches Belchertown `yAxis.min = 0`). Check the axis config's observation types (from the series mapped to that axis). Implementation: in `collectAxisConfigs`, track the observation types per axis; then in the domain computation, if any series on the axis is rain/rainRate/rainTotal, use `[0, 'auto']` instead of `['auto', 'auto']`.
- Before (line 394):
  ```typescript
  return undefined;
  ```
- After:
  ```typescript
  return ['auto', 'auto'];
  ```
- Accept: Barometer Y-axis shows ~29.900–30.050 (tight to data, NOT starting from 0). Temperature Y-axis shows ~55–75. Rain Y-axis starts from 0.
- Verification: Screenshot barometer chart, confirm Y-axis range is tight. Screenshot rain chart, confirm Y-axis starts at 0.

**T-A3 — X-axis tick spacing (fixes F4, F6)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify no overlapping ticks)
- File: `src/components/charts/ConfigDrivenChart.tsx`
- Scope in: Lines 515-521, the `<XAxis>` component
- Scope out: Do NOT change `xFormatter` (that's in ConfigDrivenGroup). Do NOT change `height` or `tick` styling.
- Do: Add `minTickGap={50}` prop to the `<XAxis>` component. This tells Recharts to leave at least 50px between tick labels, preventing overlap and duplication. Highcharts achieves the same via `minTickInterval: 900000` (15 min).
- Before:
  ```tsx
  <XAxis
    dataKey={xKey}
    height={30}
    tickFormatter={xFormatter}
    tick={{ fontSize: 11, fontFamily: CHART_FONT }}
    className="fill-muted-foreground"
  />
  ```
- After:
  ```tsx
  <XAxis
    dataKey={xKey}
    height={30}
    tickFormatter={xFormatter}
    minTickGap={50}
    tick={{ fontSize: 11, fontFamily: CHART_FONT }}
    className="fill-muted-foreground"
  />
  ```
- Accept: 24-hour temperature chart shows ~6 tick labels (roughly every 4 hours). No duplicate times ("10 PM, 10 PM"). Chart does not overflow its container horizontally.
- Verification: Screenshot temperature chart X-axis, count tick labels, confirm no duplicates.

**T-A4 — Theme-responsive color contrast (fixes F1, F8)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify colors in both themes)
- File: `src/lib/chart-contrast.ts`, `src/components/charts/ConfigDrivenChart.tsx`
- Scope in: The `ensureChartContrast()` function and where it's called in ConfigDrivenChart (lines 642-645)
- Scope out: Do NOT change the color resolution chain (series.color → globalColors[index] → FALLBACK_PALETTE). Do NOT add new config files or API endpoints.
- Do:
  1. Update FALLBACK_PALETTE (lines 35-43) to match Belchertown's 10-color default:
     ```typescript
     const FALLBACK_PALETTE = [
       '#7cb5ec', '#b2df8a', '#f7a35c', '#8c6bb1', '#dd3497',
       '#e4d354', '#268bd2', '#f45b5b', '#6a3d9a', '#33a02c',
     ];
     ```
  2. Verify `ensureChartContrast()` is called on every resolved color before rendering. It's already called at lines 642-645 — confirm it applies to all series types including scatter dots.
  3. Test `ensureChartContrast()` with problematic colors: white/near-white (windDir dots in dark mode), yellow (#e4d354 in light mode), light green (#b2df8a in light mode). If the function doesn't adjust these enough, increase the minimum contrast ratio or adjust the lightness step size in `chart-contrast.ts`.
- Accept: All series colors are clearly visible in BOTH light and dark themes. windDir scatter dots are NOT white/invisible in dark mode. Yellow and light green series are readable in light mode.
- Verification: Toggle between light and dark theme on the charts page. All lines/dots must be clearly distinguishable from the background in both.

**T-A5 — Barometer Y-axis decimal formatting (fixes F12 partial)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify barometer ticks show 2 decimals)
- File: `src/components/charts/ConfigDrivenChart.tsx`
- Scope in: Y-axis tick formatting logic, near lines 524-550 where the left YAxis is rendered
- Scope out: Do NOT change axis label rendering. Do NOT add new config fields to the API.
- Do: After the axis config is collected, detect if the axis carries barometer/pressure/altimeter observations. If so, add a `tickFormatter` that formats values to 2 decimal places: `tickFormatter={(v: number) => v.toFixed(2)}`. Detection: check if any series on the axis has `observationType` or `seriesId` matching `barometer`, `pressure`, or `altimeter`. Same detection pattern used for windDir compass labels (T2.3, lines 368-371).
- Additionally: If the migration tool injects a `yAxisTickDecimals` config key (Phase D, T-D2), the renderer should read it and use it for `tickFormatter`. This makes it operator-editable. Fallback to the observation-type detection when config doesn't specify.
- Accept: Barometer chart Y-axis shows "29.92", "29.94", "29.96" — NOT "30", "29", "28".
- Verification: Screenshot barometer chart, confirm 2-decimal tick labels.

**T-A6 — Refactor MonthlyAveragesCard to use ensureChartContrast (standardization)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify Almanac chart renders in both themes)
- File: `src/components/almanac/MonthlyAveragesCard.tsx`
- Scope in: Lines 306-313 where dewpoint stroke color uses `isDark ? '#c084fc' : '#a855f7'`
- Scope out: Do NOT change chart structure, data flow, or accessibility markup.
- Do: Import `ensureChartContrast` from `../../lib/chart-contrast`. Replace the inline ternary with:
  ```typescript
  stroke={ensureChartContrast('#a855f7', isDark)}
  ```
  Do the same for any other inline `isDark ?` color ternaries in the file. The base color stays the same; `ensureChartContrast` handles theme adaptation.
- Accept: Almanac chart renders correctly in both light and dark themes. Dewpoint line is visible in both.
- Verification: Toggle theme on the Almanac page, confirm all lines are visible.

### PHASE B — Layout fix (Dashboard repo)

**T-B1 — Move date range buttons inside Card (fixes F2)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (visual render)
- File: `src/components/charts/ConfigDrivenGroup.tsx`
- Scope in: Lines 728-777 (date range button rendering) and the Card/CardHeader rendering (find the `<Card>` open tag and where the buttons are positioned relative to it)
- Scope out: Do NOT change button styling, keyboard accessibility, or selection logic. Do NOT change card structure for non-rolling-range groups (Monthly, Yearly, etc.).
- Do: Move the date range button row (`flex flex-wrap gap-2`) from its current position ABOVE the Card to INSIDE the Card, immediately after the CardHeader. The buttons should be visually part of the card.
- Accept: Date range buttons (1d/3d/7d/30d/90d) render inside the glass card, directly below the group title. No floating elements between the tab bar and the card.
- Verification: Screenshot the "Last 24 Hours" group showing card title + date buttons + first chart, all inside one card.

### PHASE C — Wind rose fixes (Dashboard repo)

**T-C1 — Fix wind rose data rendering (fixes F9)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify colored wedges appear)
- Files: `src/components/charts/ConfigDrivenGroup.tsx` (wind rose data flow), the wind rose chart component (find via grep for `WindRose` or `windRose` in `src/components/charts/`)
- Scope in: The data flow from archive response → windSpeed/windDir extraction → `buildWindRoseMatrix()` → chart props → SVG wedge rendering
- Scope out: Do NOT change the binning algorithm in `src/utils/wind-rose-binning.ts`. Do NOT change the Beaufort color palette.
- Do: Trace the data flow and find where it breaks. The wind rose shows "0.0% Calm" and empty rings, meaning either:
  (a) Archive data for the wind rose group doesn't include windSpeed/windDir fields, OR
  (b) `buildWindRoseMatrix()` isn't being called or returns empty, OR
  (c) The binned data isn't being passed to the SVG component, OR
  (d) The SVG component isn't rendering the wedges from the binned data
  Fix whatever is broken. Verify by logging the intermediate data at each stage.
- Accept: Wind rose shows colored wedges radiating from center in the dominant wind direction(s). Beaufort speed categories are color-coded. Legend shows Calm/Light Air/Light Breeze/etc.
- Verification: Screenshot wind rose chart, confirm colored wedges are visible.

**T-C2 — Wind rose chart title (fixes F9 partial)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator
- File: Same wind rose component as T-C1
- Do: Add "Wind Rose" title above the chart, using the same `<h3>` pattern as other chart titles in ConfigDrivenChart.tsx.
- Accept: "Wind Rose" title appears above the polar chart.

**T-C3 — Remove fixed-position "Wind Rose Data" text artifact (fixes F10)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (scroll test)
- File: Find via grep for "Wind Rose Data" or "percentage" in `src/components/charts/`
- Do: Find the element generating the fixed-position text. Either remove it entirely or fix its positioning so it scrolls with the page.
- Accept: No fixed-position text artifact when scrolling the charts page.
- Verification: Scroll up and down on the charts page, confirm no text stays stuck in place.

### PHASE D — Migration tool defaults injection (API repo)

**T-D1 — Inject markerEnabled defaults for all series**
- Owner: `clearskies-api-dev` · QC: coordinator (verify migrated config)
- File: `weewx_clearskies_api/tools/migrate_charts.py`
- Scope in: Add new function `_inject_marker_defaults()`, called after existing injection functions in `migrate()`
- Scope out: Do NOT modify existing injection functions. Do NOT modify any other files.
- Do: Walk groups → charts → series. For each series (skip `marker`, `states`, `numberFormat` subsections):
  1. Determine the effective type: `series.get('type') ?? chart.get('type') ?? 'line'`
  2. If type is line, spline, area, or areaspline: inject `markerEnabled = false` if not already set
  3. If type is scatter: inject `markerEnabled = true` and `markerRadius = 2` if not already set
  4. **Special case:** If `lineWidth = 0` is set on a non-scatter series (Belchertown trick for scatter-like rendering, used for windDir), inject `type = scatter` to make the intent explicit, and `markerEnabled = true`, `markerRadius = 3` (matching the operator's graphs.conf `radius = 3`)
- Before (migration output):
  ```ini
  [[[windDir]]]
      lineWidth = 0
      radius = 3
  ```
- After:
  ```ini
  [[[windDir]]]
      type = scatter
      markerEnabled = true
      markerRadius = 3
      lineWidth = 0
      radius = 3
  ```
- Accept: Re-migrated charts.conf has `markerEnabled = false` on all line/spline/area series. windDir series has `type = scatter` and `markerEnabled = true`. Running migration twice produces identical output (idempotent).
- Verification:
  ```
  python -c "from weewx_clearskies_api.tools.migrate_charts import migrate; from pathlib import Path; text,_,_ = migrate(Path(r'c:\CODE\weather-belchertown\skins\Belchertown\graphs.conf')); print(text)" | grep -c "markerEnabled = false"
  ```
  Should show count > 40 (one per line/spline/area series).

**T-D2 — Inject special axis defaults for barometer and rain**
- Owner: `clearskies-api-dev` · QC: coordinator (verify migrated config)
- File: `weewx_clearskies_api/tools/migrate_charts.py`
- Scope in: Add new function `_inject_axis_defaults()`, called after `_inject_marker_defaults()`
- Scope out: Do NOT modify existing injection functions.
- Do: Walk groups → charts → series. For each series:
  1. **barometer/pressure/altimeter:** Inject `yAxisTickDecimals = 2` if not already set. This is a new config key that tells the renderer to format Y-axis ticks to N decimal places.
  2. **rain/rainRate/rainTotal:** Inject `yAxisMin = 0` if not already set. Rain can't be negative; Belchertown sets `yAxis.min = 0`.
- Accept: Re-migrated charts.conf has `yAxisTickDecimals = 2` on barometer series, `yAxisMin = 0` on rain/rainRate/rainTotal series.
- Verification: Grep migrated output for `yAxisTickDecimals` and `yAxisMin`.

**T-D3 — API parser: add yAxisTickDecimals field**
- Owner: `clearskies-api-dev` · QC: coordinator
- Files: `weewx_clearskies_api/models/chart_config.py` (dataclass), `weewx_clearskies_api/services/charts_config.py` (parser), `weewx_clearskies_api/models/responses.py` (response model), `weewx_clearskies_api/endpoints/charts.py` (mapping)
- Do: Add `yAxisTickDecimals: int | None` field to the series config dataclass, parser, response model, and mapping — same pattern as the existing `yAxisMin`/`yAxisMax` fields.
- Accept: API response includes `yAxisTickDecimals: 2` on barometer series.

---

## 3. QC gates

### Gate 1 — Code quality (every phase)
- Dashboard: `npx tsc --noEmit` → 0 errors (ZERO, not "just warnings")
- Dashboard: `npx vite build` → clean
- API: `ruff check` + `mypy` → 0 introduced errors
- No dead code, unused imports, commented-out blocks

### Gate 2 — Feature correctness (per task)
- Coordinator renders the chart page and visually compares against Belchertown
- Config round-trip verified: key in graphs.conf → charts.conf → API JSON → dashboard render
- Every chart must match Belchertown's visual quality (clean lines, proper axes, readable colors)

### Gate 3 — Architecture compliance
- ADR-010: No chart-specific API endpoints. Colors are presentation (dashboard-only).
- ADR-041/042: No unit conversion in dashboard.
- ARCHITECTURE.md layer responsibilities: API = data and transformation, Dashboard = presentation.

### Gate 4 — Accessibility (WCAG 2.1 AA)
- `ensureChartContrast()` guarantees 3:1 non-text contrast in both themes
- Color is not the only signal (legend labels accompany all series)
- sr-only data tables unchanged
- axe-core: 0 new violations

### Gate 5 — Belchertown parity (side-by-side comparison)
For each chart, screenshot Clear Skies and Belchertown side by side. Verify:
- [x] F1: Colors readable in both themes — 10-color Belchertown palette + ensureChartContrast
- [x] F2: Date range buttons inside card — moved into Card after CardHeader
- [x] F3: Y-axis auto-scales tight to data — domain=['auto','auto'], rain=[0,'auto']
- [x] F4: X-axis clean tick intervals, no duplicates — minTickGap={50}
- [x] F5: No markers on temperature lines — dot={false} default
- [x] F6: Charts don't overflow container — phantom right axis width=60, uniform margins, overflow:hidden
- [x] F7: No markers on wind speed/gust; windDir is scatter dots — dot={false}, scatter dot r=2
- [x] F8: windDir dots visible in both themes — ensureChartContrast on all colors
- [x] F9: Wind rose shows colored data wedges — API injects beaufort on archive; separate raw fetch
- [x] F10: No fixed-position text artifacts — sr-only tables wrapped in div
- [x] F11: No markers on rain lines — dot={false} default
- [x] F12: Barometer: auto-scale Y-axis, 2-decimal ticks, no markers — resolveTickDecimals + yAxisTickDecimals
- [x] F13: No markers on solar/UV lines — dot={false} default

---

## 4. Agent assignments

| Phase | Task | Owner | QC |
|-------|------|-------|----|
| A | T-A1 Markers off default | `clearskies-dashboard-dev` | Coordinator: visual render, verify clean lines |
| A | T-A2 Y-axis auto-scale | `clearskies-dashboard-dev` | Coordinator: screenshot barometer Y-axis |
| A | T-A3 X-axis tick spacing | `clearskies-dashboard-dev` | Coordinator: screenshot X-axis, count ticks |
| A | T-A4 Theme color contrast | `clearskies-dashboard-dev` | Coordinator: toggle theme, verify all colors |
| A | T-A5 Barometer tick decimals | `clearskies-dashboard-dev` | Coordinator: screenshot barometer ticks |
| A | T-A6 Almanac card refactor | `clearskies-dashboard-dev` | Coordinator: verify Almanac in both themes |
| B | T-B1 Date buttons in card | `clearskies-dashboard-dev` | Coordinator: screenshot layout |
| C | T-C1 Wind rose data | `clearskies-dashboard-dev` | Coordinator: verify colored wedges |
| C | T-C2 Wind rose title | `clearskies-dashboard-dev` | Coordinator: verify title |
| C | T-C3 Fixed text artifact | `clearskies-dashboard-dev` | Coordinator: scroll test |
| D | T-D1 Inject markerEnabled | `clearskies-api-dev` | Coordinator: grep migrated config |
| D | T-D2 Inject axis defaults | `clearskies-api-dev` | Coordinator: grep migrated config |
| D | T-D3 API parser field | `clearskies-api-dev` | Coordinator: verify API response |
| E | Redeploy + visual verify | Coordinator | Self (side-by-side with Belchertown) |

**Phasing:** A+D run in parallel (different repos). B+C run after A (same repo, may touch overlapping code). E runs after all code committed.

**Agent dispatch strategy:**
- Phase A: ONE agent handles T-A1 through T-A6 (all in same file area, interdependent)
- Phase B+C: ONE agent handles T-B1 + T-C1–C3 (layout + wind rose)
- Phase D: ONE agent handles T-D1 + T-D2 + T-D3 (all migration tool + API parser)

---

## 5. Files to modify

### Dashboard repo (`weewx-clearskies-dashboard`)
| File | Tasks | Changes |
|------|-------|---------|
| `src/components/charts/ConfigDrivenChart.tsx` | A1, A2, A3, A4, A5 | dot default, Y-axis domain, XAxis minTickGap, FALLBACK_PALETTE, barometer tick formatter |
| `src/lib/chart-contrast.ts` | A4 | Verify/improve contrast algorithm |
| `src/components/almanac/MonthlyAveragesCard.tsx` | A6 | Replace isDark ternaries with ensureChartContrast |
| `src/components/charts/ConfigDrivenGroup.tsx` | B1 | Move date buttons inside Card |
| Wind rose component (find path) | C1, C2, C3 | Fix data rendering, add title, remove artifact |

### API repo (`weewx-clearskies-api`)
| File | Tasks | Changes |
|------|-------|---------|
| `weewx_clearskies_api/tools/migrate_charts.py` | D1, D2 | Add _inject_marker_defaults(), _inject_axis_defaults() |
| `weewx_clearskies_api/models/chart_config.py` | D3 | Add yAxisTickDecimals field |
| `weewx_clearskies_api/services/charts_config.py` | D3 | Parse yAxisTickDecimals from config |
| `weewx_clearskies_api/models/responses.py` | D3 | Add yAxisTickDecimals to response model |
| `weewx_clearskies_api/endpoints/charts.py` | D3 | Wire yAxisTickDecimals in mapping |

### Files NOT to touch
- `src/api/client.ts` — no API client changes
- `src/hooks/useWeatherData.ts` — no data hook changes
- `src/utils/wind-rose-binning.ts` — binning algorithm is correct
- Any realtime/API code — colors are dashboard presentation
- Any Caddy/stack code — no routing changes

---

## 6. Implementation reference

### Belchertown defaults to replicate (from belchertown-chart-defaults.md)

| Default | Belchertown value | Our current value | Fix |
|---------|-------------------|-------------------|-----|
| Line/spline/area markers | `marker: { enabled: false, radius: 2 }` | `dot={undefined}` (shows markers) | `dot={false}` (T-A1) |
| Scatter markers | `marker: { radius: 2 }` (enabled) | `dot={{ r: 4 }}` | Keep (already works, radius differs) |
| Line width | `lineWidth: 2` | `strokeWidth: 2` | Already correct |
| Y-axis scaling | `endOnTick: true, startOnTick: true` | `domain={undefined}` (includes 0) | `domain={['auto','auto']}` (T-A2) |
| Rain Y-axis | `min: 0, minRange: 0.01` | No special handling | `domain={[0,'auto']}` for rain (T-A2) |
| Barometer ticks | `format: '{value:.2f}'` | No formatting | `tickFormatter: v.toFixed(2)` (T-A5) |
| X-axis tick spacing | `minTickInterval: 900000` (15 min) | No spacing control | `minTickGap={50}` (T-A3) |
| Default palette | 10 colors: `#7cb5ec, #b2df8a, ...` | 6 colors: `#7cb5ec, #434348, ...` | Match Belchertown's 10 (T-A4) |
| Area threshold | `threshold: null, softThreshold: true` | Not set | Minor — defer unless visual issue |

### Recharts rules (from docs/reference/recharts-axis-reference.md)
- NO negative margins
- NO `hide` on YAxis (bug #428) — use phantom axis workaround
- NO `margin.bottom` for labels — XAxis `height` controls label space
- Use `width="99%"` on ResponsiveContainer (not 100%)
- Use `interval={0}` with explicit `ticks` arrays
- Container div needs `minWidth:0, minHeight:0, width:'100%', height:'100%'`
- Build script is `tsc -b && vite build` — ZERO TS errors or deploy is stale

---

## 7. Scope exclusions

| Feature | Why excluded |
|---------|-------------|
| New color config file | Operator dialog: existing charts.conf colors + ensureChartContrast is sufficient |
| API color changes | Colors are presentation — dashboard only (ADR-010) |
| Highcharts zoomType | No Recharts equivalent; deferred (Brush component future) |
| Area threshold/softThreshold | Minor visual difference; defer unless operator flags it |
| Wind rose Beaufort colors | Already in charts.conf via beaufort0-beaufort6 keys |
