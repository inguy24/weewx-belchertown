# Charts Feature Parity — Belchertown → Clear Skies Execution Plan

**Status:** SUPERSEDED by [CHARTS-REWRITE-PLAN.md](../briefs/CHARTS-REWRITE-PLAN.md) (2026-06-06). Parser fields, pruning fix, wizard persistence, gauge/hays components, and wind rose tests shipped. Renderer and migration tool quality issues identified — full rewrite planned.
**Component:** Charts system feature parity. Ensures every operator-configurable Belchertown `graphs.conf` feature has a working Clear Skies equivalent.
**Parent:** [CONFIGURABLE-CHARTS-PLAN.md](docs/archive/CONFIGURABLE-CHARTS-PLAN.md), [LAYER-CORRECTION-PLAN.md](docs/archive/LAYER-CORRECTION-PLAN.md), [UI-REDESIGN-PLAN.md](docs/planning/UI-REDESIGN-PLAN.md).

---

## Context

The configurable charts system (complete 2026-06-05) replaced Belchertown's Highcharts with Recharts and a `charts.conf`-driven renderer. A thorough audit of Belchertown's Python backend (`belchertown.py`, lines 2427–3720 chart generation) and JS frontend (`belchertown.js.tmpl`, lines 4025–5160 Highcharts rendering) against the Clear Skies parser and renderer reveals gaps in three areas:

1. **8 features parsed but not rendered** — API serves the config field, dashboard ignores it
2. **12 features not parsed at all** — Belchertown supports them, Clear Skies doesn't
3. **2 special chart types missing** — gauge and hays/pollen charts
4. **2 bugs** — chart pruning too restrictive (airquality group pruned despite `aqi` column existing in DB), wizard column mappings lost on re-run

Goal: any `graphs.conf` that works in Belchertown works in Clear Skies after migration, with documented exceptions only for Highcharts-only concepts with no Recharts equivalent.

Additionally, the charts page layout needs to be brought into compliance with the UI design system — it's the only page that doesn't use Grid, PageHeaderCard, or card-based layout.

---

## PHASE 7 — Charts page layout redesign (Dashboard)

The charts page (`src/routes/charts.tsx`, 206 lines) is the only page that doesn't follow the Grid + PageHeaderCard pattern. It uses a bare `flex-col` with a sr-only `<h1>`, raw tab buttons floating over the background, and date controls loose inside ConfigDrivenGroup. Every other page (Now, Forecast, Almanac, Seismic, Records) uses `Grid` → `PageHeaderCard` → content cards.

### Target layout

```
[  PageHeaderCard — "Charts" + ph:chart-line icon        — full, strip height  ]
[  TabNavCard — group tabs LEFT + date controls RIGHT    — full, strip height  ]
[  Chart content (ConfigDrivenGroup minus its controls)  — full width below    ]
```

### Changes

**T7.1 — Restructure charts.tsx to use Grid + PageHeaderCard**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (visual render + ADR-051 check)
- Modify: `src/routes/charts.tsx`
- Do:
  - Replace `<div className="flex flex-col gap-6 max-w-4xl mx-auto">` with the standard Grid pattern:
    ```tsx
    <div className="flex flex-col gap-4">
      <Grid className="md:auto-rows-[auto]">
        <PageHeaderCard title={t('title')} icon={<ChartLine weight="duotone" />} />
        {/* Tab + controls card */}
        {/* Chart content */}
      </Grid>
    </div>
    ```
  - Import `Grid`, `PageHeaderCard`, `Card` from UI components
  - Import `ChartLine` from `@phosphor-icons/react`
  - Move the sr-only `<h1>` into PageHeaderCard (it handles the heading via `as="h1"`)
- Accept: PageHeaderCard renders at top of charts page with "Charts" title and chart icon. Grid wraps all content.

**T7.2 — Create combined TabNavCard (tabs + date controls in one strip)**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (visual render + keyboard nav test)
- Modify: `src/routes/charts.tsx` and `src/components/charts/ConfigDrivenGroup.tsx`
- Do:
  - Create a `Card footprint="full"` with strip-height styling (`py-2`) that contains:
    - LEFT: the group tab buttons (existing WAI-ARIA tablist from charts.tsx lines 148-179)
    - RIGHT: the date controls from ConfigDrivenGroup (rolling range buttons OR year/month dropdowns)
  - The date controls currently live in ConfigDrivenGroup (lines 591-698). They need to be **lifted up** to charts.tsx so they render inside the TabNavCard, not inside the chart content area.
  - ConfigDrivenGroup needs a new prop like `hideControls?: boolean` or the controls need to be extracted into a separate component that charts.tsx renders in the card.
  - When the active group has rolling ranges: right side shows `[1d] [3d] [7d] [30d] [90d]`
  - When the active group has year/month dropdowns: right side shows `[Year ▼] [Month ▼]`
  - When the active group has neither (timespan_specific, climatology): right side is empty
  - Date control state (selectedRange, selectedYear, selectedMonth) stays in charts.tsx and is passed down to ConfigDrivenGroup
- Accept: Tabs and date controls render in a single glass-surface card. Controls update when switching tabs. Keyboard navigation works.

**T7.3 — Wrap chart content in appropriate container**
- Owner: `clearskies-dashboard-dev` (same agent as T7.1/T7.2) · QC: coordinator
- The charts rendered by ConfigDrivenGroup (below the TabNavCard) should render inside the Grid flow. Each ConfigDrivenGroup output (one or more charts + optional table toggle + export buttons) can either:
  - Render as a single full-width card containing all charts for the group, OR
  - Render bare within the Grid (charts are already self-contained visual elements)
- Decision: render bare within Grid — charts have their own internal structure (sr-only tables, tooltips, legends). Wrapping in an additional Card adds visual noise without benefit. The glass surface is already on the page background.
- Accept: Chart content renders below the TabNavCard within the Grid. Table toggle and export buttons still work.

**T7.4 — Audit**
- Owner: `clearskies-auditor` · QC: coordinator
- Audit scope: `charts.tsx` changes, `ConfigDrivenGroup.tsx` changes
- Audit against:
  - ADR-051: PageHeaderCard with `footprint="full"`, universal card discipline, cards sit in Grid
  - coding.md §5: WCAG tab pattern preserved (role="tablist", aria-selected, keyboard nav), focus indicators, heading order
  - coding.md §7: `tsc --noEmit` 0 errors, `vite build` clean
  - Backward compat: all 6 chart groups still render, date controls still functional
- Accept: 0 high findings. Medium/low remediated before close.

### Files touched
- `src/routes/charts.tsx` — restructure layout, lift date controls
- `src/components/charts/ConfigDrivenGroup.tsx` — extract or hide date controls, accept lifted state
- No API changes needed

### Acceptance criteria
- PageHeaderCard with "Charts" title and chart icon visible at top of page
- Tab buttons + date controls in a single glass-surface strip card
- Date controls update when switching tabs (rolling ranges vs year/month vs none)
- Keyboard navigation on tabs still works (ArrowRight/Left/Home/End)
- Chart content renders below the cards
- `tsc --noEmit` → 0 errors, `vite build` clean
- axe-core: 0 new violations

### QC gates
- Gate 1: `tsc` + `vite build` clean
- Gate 2: Visual render — PageHeaderCard visible, tabs in card, date controls right-justified
- Gate 3: ADR-051 compliance — PageHeaderCard with footprint="full", universal card discipline
- Gate 4: Accessibility — existing WAI-ARIA tab pattern preserved, keyboard nav works, focus indicators visible
- Gate 5: Backward compat — all 6 chart groups still render, no data regression

---

## 0. Orientation for a fresh session

- **Load before acting:** [CLAUDE.md](CLAUDE.md), [rules/coding.md](rules/coding.md) (§5 WCAG, §6 Recharts, §7 build verification), [rules/clearskies-process.md](rules/clearskies-process.md).
- **Three sub-repos** under `repos/`:
  - `weewx-clearskies-api` — FastAPI backend. Parser + data models.
  - `weewx-clearskies-realtime` — BFF. **No changes in this plan.**
  - `weewx-clearskies-dashboard` — React 19 + Vite + Recharts. Chart renderer.
  - `weewx-clearskies-stack` — Config UI / wizard. Column mapping persistence fix.
- **Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Key constraint: **API = general-purpose data, no chart awareness. BFF = unit conversion + derived values. Dashboard = rendering + presentation binning** (ADR-041/042 computation boundary).
- **Belchertown reference:** `skins/Belchertown/graphs.conf` (local), `/etc/weewx/skins/Belchertown/graphs.conf` (weewx container).
- **Migrated config:** `/etc/weewx-clearskies/charts.conf` (deployed 2026-06-06).
- **Deploy:** API on weewx container (`systemctl restart weewx-clearskies-api`), Dashboard on weather-dev (`scripts/redeploy-weather-dev.sh`), Redis flush after API changes.

### Git safety (ALL agents, ALL repos — non-negotiable)
Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. **NO pull/push/fetch/rebase/merge/remote/worktree.** Coordinator pushes only when operator types "push."

---

## 1. Implementation reference — exact file:line for every touch point

### API repo (`repos/weewx-clearskies-api`)

| What | File | Lines | Notes |
|------|------|-------|-------|
| SeriesConfig dataclass | `models/chart_config.py` | 30–89 | 27 fields. Missing: states, numberFormat, dashStyle, fillColor, softMin/Max, subtitle, credits, fillOpacity, mirroredValue, cssClass/height/width, exporting, gauge color fields |
| ChartConfig dataclass | `models/chart_config.py` | 96–124 | 11 fields. Missing: subtitle |
| ChartGroupConfig dataclass | `models/chart_config.py` | 131–174 | 21 fields. Missing: exporting |
| ChartsConfig dataclass | `models/chart_config.py` | 181–209 | 6 fields. Complete. |
| Parser entry | `services/charts_config.py` | 1–504 | `load_charts_config()`, series parsing at ~lines 300–400 |
| **Pruner (THE BUG)** | `services/charts_config.py` | 505–673 | `prune_charts_config()`. Line 536–540 builds `available` set from `registry.stock.values()` ONLY — misses `registry.unmapped` |
| ColumnRegistry | `db/reflection.py` | 182–208 | Has `.stock` and `.unmapped` dicts. Has `all_columns()` method at line 199 that returns both. |
| Registry DI | `db/registry.py` | 14–41 | Module-level singleton. `wire_registry()` / `get_registry()`. |
| Migration tool | `tools/migrate_charts.py` | Full file | Warns on `[[[[states]]]]` and `generate`. Needs update after features are supported. |
| Setup apply (writes column_mapping) | `endpoints/setup.py` | 540–544 | Writes `[column_mapping]` section to api.conf. Format: `canonical = db_col`. |
| CurrentConfigResponse model | `endpoints/setup.py` | 395–401 | **Missing `column_mapping` field** — root cause of wizard persistence bug |
| current_config endpoint | `endpoints/setup.py` | 1025–1223 | **Never reads/returns column_mapping** |

### Dashboard repo (`repos/weewx-clearskies-dashboard`)

| What | File | Lines | Notes |
|------|------|-------|-------|
| SeriesConfig TS interface | `src/api/types.ts` | 582–610 | 27 fields matching API. `yAxisMax` exists but NOT used in renderer. |
| ChartConfig TS interface | `src/api/types.ts` | 612–624 | 11 fields |
| ChartGroupConfig TS interface | `src/api/types.ts` | 626–648 | 21 fields |
| **renderSeriesElement()** | `src/components/charts/ConfigDrivenChart.tsx` | 112–230 | Creates `<Line>`, `<Area>`, `<Bar>` elements. **Where dashStyle, fillColor, fillOpacity changes go.** |
| Series type handling | `ConfigDrivenChart.tsx` | 140–229 | spline→`monotone` (141), area (158), bar/column (178), scatter (193), line (212) |
| Marker/dot props | `ConfigDrivenChart.tsx` | 124–130 | From `markerEnabled`/`markerRadius` |
| Stacking | `ConfigDrivenChart.tsx` | 133 | `stackId = series.stacking ? 'stack' : undefined` |
| lineWidth→strokeWidth | `ConfigDrivenChart.tsx` | 137 | `strokeWidth = series.lineWidth ?? 2` |
| Opacity | `ConfigDrivenChart.tsx` | 138, 170, 187 | Per series type |
| Color resolution | `ConfigDrivenChart.tsx` | 84–94 | `resolveColor()` function |
| **Left YAxis config** | `ConfigDrivenChart.tsx` | 367–389 | Reads `yAxisMin` into domain. **yAxisMax NOT read — the gap at line 372** |
| Right YAxis config | `ConfigDrivenChart.tsx` | 398–431 | Same pattern, same gap |
| collectAxisConfigs() | `ConfigDrivenChart.tsx` | 246–263 | Collects min/label/tickInterval from series. **Doesn't collect max, softMin, softMax** |
| ComposedChart render | `ConfigDrivenChart.tsx` | 351–354 | `<ComposedChart data={data} margin={...}>` |
| File total | `ConfigDrivenChart.tsx` | **458 lines** | |
| Chart type detection | `src/components/charts/ConfigDrivenGroup.tsx` | 199–227 | Climatology (199), windRose (202), rangeChart (210) |
| Archive data fetch | `ConfigDrivenGroup.tsx` | 342–357 | `useArchive()` + dual range fetch |
| Data transformation | `ConfigDrivenGroup.tsx` | 363–450 | Archive→seriesId rows, wind rose matrix, climatology map, range points |
| **Gap insertion point** | `ConfigDrivenGroup.tsx` | ~365–379 | Archive path data transform — **where gapsize null-insertion goes** |
| Date range controls | `ConfigDrivenGroup.tsx` | 591–698 | Rolling ranges (591), year/month dropdowns (642) |
| **Force full year point** | `ConfigDrivenGroup.tsx` | ~270–295 | `archiveParams` computation — **where force_full_year domain expansion goes** |
| Export handlers | `ConfigDrivenGroup.tsx` | 535–571 | CSV (535), PNG (564) — **where exporting toggle goes** |
| Chart rendering | `ConfigDrivenGroup.tsx` | 886–958 | WindRose (888), Range (920), default ConfigDrivenChart (945) — **where gauge/hays detection goes** |
| File total | `ConfigDrivenGroup.tsx` | **964 lines** | |
| WindRoseChart (reference pattern) | `src/components/charts/WindRoseChart.tsx` | 623 lines | Custom SVG, `role="img"`, sr-only table (586–620), tooltip (489–505), `describeArc()` (64–106) |
| WeatherRangeChart | `src/components/charts/WeatherRangeChart.tsx` | 593 lines | Polar radial bars, `tempGradientColor()`, sr-only table |
| SemiCircularGauge (reuse target) | `src/components/semi-circular-gauge.tsx` | 348 lines | Viewbox 200×112, CX=100/CY=92/R=85, 36 ticks, color zones, indicator line. **Base for ChartGauge.** |
| BarometerCard (gauge usage example) | `src/components/barometer-card.tsx` | ~150 lines | Dynamic scale expansion, threshold ticks at 29.80/30.20 |

### Stack repo (`repos/weewx-clearskies-stack`)

| What | File | Lines | Notes |
|------|------|-------|-------|
| Wizard step 3 (column mapping) | `wizard/routes.py` | 1446–1497 | `step3_post()` — extracts `col_<name>` form fields, stores in `state.column_mapping` |
| **config_writer (NOT IMPLEMENTED)** | `wizard/config_writer.py` | 171–182 | `write_api_conf()` raises `NotImplementedError` — **BUG A7**. All config writing goes through API's `/setup/apply` |
| state_persistence read | `wizard/state_persistence.py` | 298–310 | `populate_from_config()` tries to read `[column_mapping]` from LOCAL `api.conf` — **but stack doesn't have a local api.conf** |
| API merge on re-run | `wizard/routes.py` | 2601–2741 | `_merge_from_api_current_config()` — calls API's `/setup/current-config`. **Column mappings not in response** → lost |

---

## 2. Implementation phases

### PHASE 1 — Wire parsed-but-not-rendered features (Dashboard only)

**T1.1 — Y-axis max + tick interval + soft limits (A1, A2, B5)**
- Modify: `ConfigDrivenChart.tsx` — `collectAxisConfigs()` at line 246 and YAxis render at lines 367–431
- Do: In `collectAxisConfigs()`, also collect `yAxisMax`, `yAxisSoftMin`, `yAxisSoftMax` from series. Apply to YAxis `domain`: `domain[0] = softMin ? Math.min(softMin, 'dataMin') : min ?? 'auto'`, `domain[1] = softMax ? Math.max(softMax, 'dataMax') : max ?? 'auto'`. For `yAxisTickInterval`: compute explicit `ticks` array from `[min, min+interval, min+2*interval, ...]` and pass with `interval={0}`.
- Accept: windDir chart with `yAxis_max = 360` constrains axis. Barometer with `yAxis_tickInterval = 0.01` shows fine ticks.

**T1.2 — Z-index sort order (A3)**
- Modify: `ConfigDrivenChart.tsx` — before the series `.map()` loop inside `<ComposedChart>` (after line 440)
- Do: Sort `visibleSeries` by `zIndex` ascending before rendering. Recharts renders SVG in array order; later = on top.
- Accept: Series with `zIndex = 2` renders above `zIndex = 1`.

**T1.3 — Gap size detection (A4)**
- Modify: `ConfigDrivenGroup.tsx` — archive data transform at lines 364–379
- Do: After building `archiveData` rows, if `group.gapsize` is set, iterate rows and insert a null-value row wherever `rows[i+1].timestamp - rows[i].timestamp > gapsize * 1000`. This makes Recharts break the line at data gaps.
- Accept: Chart with `gapsize = 300` breaks lines when archive has >5-min gaps.

**T1.4 — Force full year + start at month beginning (A5, A6)**
- Modify: `ConfigDrivenGroup.tsx` — `archiveParams` computation at ~lines 270–295
- Do: When `group.forceFullYear`, set `from` to Jan 1 and `to` to Dec 31 of selected year. When `group.startAtBeginningOfMonth`, anchor `from` to 1st of the current month.
- Accept: Annual charts show full Jan–Dec axis.

**T1.5 — Custom SQL column mapping (A8)**
- Modify: `ConfigDrivenGroup.tsx` — custom query data handling
- Do: When rendering a custom SQL series, use `series.xColumn` and `series.yColumn` to map the query result fields to the chart `dataKey`, instead of hardcoded `x`/`y`.
- Accept: Custom SQL with `x_column = month`, `y_column = avg_monthly_climo_rain` renders correctly.

### PHASE 2 — Add missing parser + renderer features (API + Dashboard)

**T2.1 — Add new fields to API dataclass + parser**
- Modify: `models/chart_config.py` — SeriesConfig (line 30), ChartConfig (line 96), ChartGroupConfig (line 131)
- Add to SeriesConfig: `states: dict | None = None`, `number_format: dict | None = None`, `dash_style: str | None = None`, `fill_color: str | None = None`, `y_axis_soft_min: float | None = None`, `y_axis_soft_max: float | None = None`, `y_axis_minor_ticks: bool | None = None`, `mirrored_value: bool | None = None`, `fill_opacity: float | None = None`, `border_width: int | None = None`, `connect_ends: bool | None = None`
- Add to ChartConfig: `subtitle: str | None = None`
- Add to ChartGroupConfig: `credits: str | None = None`, `credits_url: str | None = None`, `credits_position: dict | None = None`, `css_class: str | None = None`, `css_height: str | None = None`, `css_width: str | None = None`, `exporting: bool = True`, `legend: bool = True`
- Modify: `services/charts_config.py` — parser section (~lines 300–400). Parse `[[[[states]]]]` as nested dict, `[[[[numberFormat]]]]` as dict with `decimals`/`decimalPoint`/`thousandsSep`. Parse remaining scalar fields from series/chart/group blocks.
- Accept: `ruff` + `mypy` clean. API's `/charts/config` response includes all new fields.

**T2.2 — Update TypeScript types**
- Modify: `src/api/types.ts` — SeriesConfig (line 582), ChartConfig (line 612), ChartGroupConfig (line 626)
- Add matching fields for all new API fields. Use `Record<string, unknown> | null` for `states` and `numberFormat`.
- Accept: `tsc --noEmit` → 0 errors.

**T2.3 — Wire new fields in dashboard renderer**
- Modify: `ConfigDrivenChart.tsx` — `renderSeriesElement()` at line 112
- Wire:
  - `dashStyle` → `strokeDasharray` prop on Line/Area. Map: `Dash → "8 4"`, `Dot → "2 4"`, `DashDot → "8 4 2 4"`, `LongDash → "16 4"`, `ShortDash → "4 4"`, `Solid → undefined`
  - `fillColor` → Area `fill` prop (distinct from `stroke` which comes from `color`)
  - `fillOpacity` → Area/Bar `fillOpacity` prop (override the default at lines 170, 187)
  - `mirroredValue` → YAxis `tickFormatter` wraps values in `Math.abs()`
  - `states.hover` → No-op for `lineWidthPlus` (Recharts default). Parse `color` → `activeDot` color.
  - `numberFormat` → tooltip formatter uses `Intl.NumberFormat` with `decimals`, `decimalPoint`, `thousandsSep`
  - `subtitle` → render `<p className="text-xs text-muted-foreground">` below chart title
  - `credits` → small linked text at chart bottom-right
  - `cssClass` / `cssHeight` / `cssWidth` → wrapper div `className` + `style`
  - `exporting` → conditionally render PNG/CSV export buttons (ConfigDrivenGroup lines 535–571)
  - `legend` → conditionally render `<Legend>` component
  - `minorTicks` → add finer CartesianGrid lines between major ticks
- Accept: Each feature works independently. `tsc` clean. Visual check on at least one example.

**T2.4 — Update migration tool**
- Modify: `tools/migrate_charts.py`
- Do: Remove `# UNSUPPORTED` comments for `states`, `numberFormat`, and any other newly-supported features. Keep `# NOTE` only for Category E items (`generate`, Highstock features, `zoomType`).
- Accept: `clearskies-migrate-charts graphs.conf` produces zero UNSUPPORTED warnings on the operator's config.

### PHASE 3 — Special chart types (API + Dashboard)

**T3.1 — Gauge / Solid gauge component (C1)**
- Modify (API): `models/chart_config.py` SeriesConfig — add: `colors_enabled: bool = False`, `color_zones: list[dict] | None = None` (each dict: `{color, position, label}`)
- Modify (API): `services/charts_config.py` — parse `color1`–`color7`, `color1_position`–`color7_position`, `color1_label`–`color7_label` into `color_zones` list. Parse `colors_enabled` boolean.
- Create: `src/components/charts/ChartGauge.tsx`
  - Base pattern: `semi-circular-gauge.tsx` (348 lines, viewbox 200×112, CX=100/CY=92/R=85, 36 ticks)
  - Config-driven: accept `min`, `max`, `value`, `colorZones[]`, `unit`, `label` from charts config
  - Color zones: up to 7 bands, each with position threshold and color. Ticks filled with zone color.
  - Data label: current value centered in arc (same pattern as SemiGauge children, line 325–345)
  - WCAG: `role="img"`, `<title>`, sr-only value text
  - Both themes: use CSS variables for unfilled ticks (`--gauge-unfill`)
  - Belchertown reference: `belchertown.js.tmpl` lines 4613–4686 (gauge), 4688–4742 (AQI gauge)
- Modify: `ConfigDrivenGroup.tsx` line ~886 — add detection: `if (chart.type === 'gauge' || chart.type === 'solidgauge')` → render `<ChartGauge>`
- Modify: `src/api/types.ts` — add gauge fields to SeriesConfig
- Accept: `type = solidgauge` in charts.conf renders a gauge. Color zones display. sr-only value. Both themes. `tsc` clean.

**T3.2 — Hays / Pollen polar arearange component (C2)**
- Modify (API): `models/chart_config.py` — recognize `haysChart` as a series type
- Modify (API): `services/charts_config.py` — parse `haysChart` observation type, preserve `connectEnds`, `polar` fields
- Create: `src/components/charts/HaysChart.tsx`
  - Base pattern: `WeatherRangeChart.tsx` (593 lines, polar SVG, `radialBarPath()`, sr-only table)
  - Polar arearange: each position = time period, radial band = low→high values
  - Props: `data: {dateTime, low, high}[]`, `softMax`, `field`, `unit`, `reducedMotion`
  - WCAG: `role="img"`, sr-only table, keyboard-focusable segments, tooltip
  - Belchertown reference: `belchertown.js.tmpl` lines 4744–4818
- Modify: `ConfigDrivenGroup.tsx` line ~886 — add detection for `haysChart` series → render `<HaysChart>`
- Accept: `[[[haysChart]]]` in charts.conf renders polar arearange. sr-only table. Both themes. `tsc` clean.

### PHASE 4 — Bug fixes (API + Stack)

**T4.1 — Fix chart pruning to include all DB columns (D1)**
- Modify: `services/charts_config.py` lines 536–540
- The bug: `available` set built from `registry.stock.values()` only. Misses `registry.unmapped` (58 columns including `aqi`, `ow_pm25`, etc.).
- Fix: Change line 536–540 from:
  ```python
  available: set[str] = {
      info.canonical_name
      for info in registry.stock.values()
      if info.canonical_name is not None
  }
  ```
  To include unmapped DB columns:
  ```python
  available: set[str] = set()
  for info in registry.stock.values():
      if info.canonical_name is not None:
          available.add(info.canonical_name)
  for info in registry.unmapped.values():
      available.add(info.db_name)
  ```
- Accept: API logs show 6 groups (not 5). `airquality` group with `aqi` series is NOT pruned.

**T4.2 — Fix wizard column mapping persistence (D2)**

Root cause (fully traced):
1. Wizard step 3 (`routes.py:1446–1497`) saves mappings to `state.column_mapping` ✅
2. `/wizard/apply` calls API's `/setup/apply` which writes `[column_mapping]` to `api.conf` (`setup.py:540–544`) ✅
3. On re-run, `_merge_from_api_current_config()` (`routes.py:2601–2741`) calls `/setup/current-config` — but `CurrentConfigResponse` (`setup.py:395–401`) **has no `column_mapping` field** ❌
4. Fallback: `populate_from_config()` (`state_persistence.py:298–310`) tries to read `[column_mapping]` from LOCAL `api.conf` — **but stack doesn't have one** (only `stack.conf` is local) ❌
5. Result: mappings exist in api.conf on the API side, never round-trip back to the wizard

Fix (two changes):
- **API:** Add `column_mapping: dict[str, str] | None` to `CurrentConfigResponse` model at line 395. In `current_config()` endpoint at line 1025, read `[column_mapping]` section from the loaded api.conf ConfigObj and include it in the response.
- **Stack:** In `_merge_from_api_current_config()` at line 2601, read the `column_mapping` dict from the API response and populate `state.column_mapping` (inverting the key direction: API stores `canonical→db_col`, wizard state stores `db_col→canonical`).
- Accept: Map columns in wizard → apply → restart API → re-run wizard → step 3 shows previously mapped columns pre-filled.

### PHASE 5 — LC fixes (Dashboard)

- LC-1: Finish `WeatherRangeChart.tsx` CSS variable migration (CSS vars added to `index.css` this session; verify `readRangeColors()` works with dark theme, verify AA contrast)
- LC-2: Finish range chart table/CSV (`rangeTableData` from `rangeHighPoints`/`rangeLowPoints` — partially wired this session; verify table columns show "High"/"Low", CSV export uses range data)
- LC-3: ✅ Done (`agg` added to `useArchive` deps at `useWeatherData.ts:385`)
- LC-4: Create `src/utils/wind-rose-binning.test.ts` — cover: direction formula edge cases (0°, 359°, 180°), Beaufort cap at 6+, calm handling (speed=0, speed=null), null/incomplete records, percentage math
- LC-5: Verify `archiveResult` skip condition (added `|| hasRangeChart` this session at line 343)

### PHASE 6 — Deploy + visual verification

**T6.1 — Re-run migration tool + deploy**
- Run `clearskies-migrate-charts` against operator's `graphs.conf` with updated parser
- Deploy `charts.conf` to `/etc/weewx-clearskies/charts.conf` on weewx
- Push all repos, restart API, flush Redis, rebuild + deploy dashboard

**T6.2 — Visual verification checklist**
- [ ] All 6 tabs render from migrated config (including airquality after pruning fix)
- [ ] Range selector buttons work (1d/3d/7d/30d/90d)
- [ ] Average Climate tab shows 12-month climatological data
- [ ] Chart/table toggle works — range charts show High/Low columns
- [ ] Wind rose renders with operator's Beaufort colors
- [ ] Weather range chart renders with theme-aware gradient (CSS variables)
- [ ] Custom SQL queries execute and render (Average Monthly Rain Total)
- [ ] Tropical Storm Hilary (timespan_specific) renders with epoch dates + page_content
- [ ] Gauge chart renders with color zones (test config)
- [ ] Gap detection breaks lines at data gaps > gapsize
- [ ] `force_full_year` shows Jan–Dec axis on annual charts
- [ ] Wind direction axis shows compass labels with `yAxis_max = 360` + `yAxis_tickInterval`
- [ ] Barometer axis shows fine ticks with `yAxis_tickInterval = 0.01`
- [ ] Dashed lines render for series with `dashStyle` (test config)
- [ ] Column mappings persist across wizard re-run
- [ ] Both dark and light themes render correctly
- [ ] `tsc --noEmit` → 0 errors, `vite build` clean
- [ ] axe-core: 0 violations on `/charts`
- [ ] Side-by-side: every Belchertown chart group has a Clear Skies equivalent

---

## 3. QC gates (per phase)

### Gate 1 — Code quality (every phase)
- [ ] `tsc --noEmit` → 0 errors (dashboard)
- [ ] `vite build` → clean (dashboard)
- [ ] `ruff check` + `mypy` → 0 introduced errors (API)
- [ ] No dead code, no unused imports, no commented-out blocks (coding.md §3)
- [ ] No hardcoded secrets (coding.md §1)

### Gate 2 — Feature correctness (per task)
- [ ] Each task's acceptance criteria met (see Accept lines in each task)
- [ ] Coordinator renders the chart page and visually verifies each new feature works — not just that `tsc` passes (coding.md §4 "Render and LOOK")
- [ ] Config round-trip: key in `graphs.conf` → migrated to `charts.conf` → parsed by API → served in `/charts/config` JSON → consumed by dashboard → visible in rendered chart

### Gate 3 — Architecture + ADR compliance
- [ ] **ADR-041/042 computation boundary:** No unit conversion or Beaufort computation in the dashboard. All derived values come from BFF. Gauge/hays components read converted values, not raw archive data.
- [ ] **ADR-010 canonical data model:** API serves generic data. No chart-type-specific endpoints added. Charts page uses existing `/archive`, `/climatology/monthly`, `/charts/config`, `/charts/custom-query/{id}` endpoints only.
- [ ] **ADR-027 config format:** Any new config keys follow ConfigObj/INI format consistent with existing `charts.conf` structure. No YAML/JSON config files introduced.
- [ ] **ADR-051 universal card discipline:** Charts page doesn't bypass Grid/Card system if cards are used elsewhere.
- [ ] **ARCHITECTURE.md "Layer Responsibilities":** Dashboard does presentation-level computation only (binning, LTTB, gap insertion). No domain logic (Beaufort thresholds, comfort index, unit conversion).
- [ ] **ARCHITECTURE.md "Charts configuration":** Config flow matches: `charts.conf → charts_config.py → /charts/config → useChartsConfig() → ConfigDrivenGroup/Chart`. No shortcuts.

### Gate 4 — Accessibility (coding.md §5, WCAG 2.1 AA)
- [ ] New chart components (ChartGauge, HaysChart) have `role="img"` + `aria-labelledby` on SVG
- [ ] sr-only data table alongside every new chart type (WCAG 1.1.1)
- [ ] All interactive elements keyboard-reachable (Tab, Enter/Space, Escape)
- [ ] Color is not the only signal (gauge zones have labels, not just colors)
- [ ] Focus indicators visible in both themes
- [ ] axe-core: 0 new violations on `/charts`

### Gate 5 — Backward compatibility
- [ ] Existing charts (from built-in defaults or previous migrated config) render identically after changes
- [ ] `/charts/config` JSON response is backward-compatible (new fields are additive, nullable)
- [ ] No existing i18n keys removed or renamed
- [ ] Operators who don't use new features see no change in behavior

### Gate 6 — Belchertown parity verification
- [ ] Run migration tool against operator's full `graphs.conf` → zero UNSUPPORTED warnings
- [ ] Every chart group in Belchertown has a rendered equivalent in Clear Skies
- [ ] Every series option used in the operator's config produces a visible effect in the rendered chart
- [ ] Document any Category E (unsupported) items with rationale in the migration guide

---

## 4. What's NOT ported (Category E — documented exceptions)

The migration tool annotates these with `# NOTE:` comments. They have no Recharts equivalent.

| Feature | Why | Operator impact |
|---------|-----|-----------------|
| Open-ended property pass-through (any Highcharts prop in config → JS) | Recharts is component-based. Props must be explicitly mapped. | Operators using exotic Highcharts options need to file a feature request. All common options are mapped. |
| `generate = daily` | Static HTML generation directive. Clear Skies fetches live from API. | None — feature is obsolete. |
| Highstock navigator / scrollbar / rangeSelector | Disabled in Belchertown anyway. | None. |
| `chart.zoomType = 'x'` | Recharts has no built-in zoom. | Future: could add via Brush component. |

---

## 5. Verification bar (definition of "done")

- [ ] Every `graphs.conf` key documented in the Belchertown wiki has a mapping in the parser
- [ ] Operator's `graphs.conf` migrates with zero UNSUPPORTED warnings (only NOTE for Category E)
- [ ] All 6 chart groups render with correct data (including airquality after pruning fix)
- [ ] Unmapped DB columns (`aqi`, `ow_pm25`, etc.) available for charting without canonical mapping
- [ ] Column mappings persist across wizard re-runs and API restarts
- [ ] Wind direction compass labels via `yAxis_max = 360` + `yAxis_tickInterval`
- [ ] Barometer fine ticks via `yAxis_tickInterval = 0.01`
- [ ] Lightning scatter (`lineWidth=0`, `marker.enabled=true`) renders correctly
- [ ] Stacked series (`stacking = normal`) stack properly
- [ ] Gauge chart renders with configurable color zones
- [ ] Hays/pollen polar arearange chart renders
- [ ] Dashed lines render for `dashStyle` config
- [ ] Number formatting respects `[[[[numberFormat]]]]`
- [ ] Gap detection breaks lines at gaps > gapsize
- [ ] `force_full_year` shows full Jan–Dec axis
- [ ] States config parses without warnings
- [ ] `tsc --noEmit` → 0 errors
- [ ] `vite build` → clean
- [ ] axe-core: 0 violations on `/charts`
