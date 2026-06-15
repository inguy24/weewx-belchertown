# Charts System Complete Rewrite — Execution Plan

**Status:** ACTIVE
**Component:** ConfigDrivenChart + ConfigDrivenGroup complete rewrite to achieve Belchertown Highcharts feature parity.
**Parent:** [UI-REDESIGN-PLAN.md](docs/planning/UI-REDESIGN-PLAN.md), [CONFIGURABLE-CHARTS-PLAN.md](docs/archive/CONFIGURABLE-CHARTS-PLAN.md)

---

## Context

The current ConfigDrivenChart renderer is fundamentally broken. A side-by-side comparison of the same data rendered by the Almanac page's MonthlyAveragesCard (working) vs the Charts page's ConfigDrivenChart (broken) reveals the renderer is not translating Belchertown's graphs.conf options into Recharts props correctly. Temperature charts show no data. Wind direction renders wrong colors. Rain bars are missing. Axis labels are absent. Barometer, Solar/UV, and Lightning charts don't render at all.

The root causes are not individual bugs — they are systemic failures in the data pipeline and rendering logic:

1. **Data pipeline drops fields** — archive fetch only collects `observationType`, ignoring `seriesId` fallback. Virtual series (windRose, rainTotal) sent as field names, causing API 422 errors.
2. **Custom SQL data never fetched** — no client function, no hook, no merge into chart data.
3. **Axis labels never derived** — Belchertown auto-generates labels from weewx's unit system. Clear Skies doesn't, and the migration tool doesn't inject defaults.
4. **Rendering ignores config fields** — 8+ SeriesConfig fields parsed but never read by the renderer (softMin/Max, borderWidth, connectEnds, polar, numberFormat, states, yAxisMinorTicks).
5. **Layout wrong** — charts not in cards, titles misplaced, export buttons floating, no 2-column grid like Belchertown.
6. **Tooltip formatting primitive** — no number formatting, no unit labels, no compass direction labels for wind.

Additionally, the migration tool (`clearskies-migrate-charts`) produces an incomplete `charts.conf`. Belchertown auto-derives axis labels, unit labels, number formatting, and observation aliases from weewx's unit system at runtime. Clear Skies doesn't have that runtime derivation — the migration tool must inject all of this into the config file so the renderer has everything it needs. The migration tool must be fixed FIRST (Phase 0), then the renderer rewritten against a correct config.

---

## 0. Orientation

- **Load:** [CLAUDE.md](CLAUDE.md), [rules/coding.md](rules/coding.md) (§5 WCAG, §6 Recharts, §7 build verification), [rules/clearskies-process.md](rules/clearskies-process.md).
- **Repos:** `weewx-clearskies-dashboard` (primary), `weewx-clearskies-api` (migration tool + axis label injection)
- **Reference implementation:** `src/components/almanac/MonthlyAveragesCard.tsx` — THIS is what a correctly rendered Recharts chart looks like. Every chart the renderer produces should match this quality.
- **Recharts reference:** `docs/reference/recharts-axis-reference.md`
- **Deploy:** Dashboard on weather-dev (`scripts/redeploy-weather-dev.sh`), API on weewx container.
- **Belchertown source:** `docs/snapshots/server-skin-2026-04-29/Belchertown/js/belchertown.js.tmpl` (JS), `bin/user/belchertown.py` (Python)

### Git safety
Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree.

---

## 1. Bug inventory (from audit)

### CRITICAL (nothing renders)
| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| C1 | Archive fetch drops most fields | `fields` set only collects `observationType`, not `seriesId` fallback | Use `observationType ?? seriesId`, skip virtual series (windRose, weatherRange, haysChart), alias rainTotal→rain |
| C2 | Custom SQL data never fetched | No client function, no hook, no merge | Add `getCustomQuery()` client, `useCustomQueries()` hook, merge into grouped archive data by month index or timestamp (archive) |
| C3 | ~~CLIMATOLOGY_FIELD_MAP keys don't match config~~ | **OBSOLETE (2026-06-07)** — `CLIMATOLOGY_FIELD_MAP` was removed. Grouped archive charts now call `GET /api/v1/archive/grouped` directly; there is no client-side field map. Two-level aggregation is expressed as `field:agg_type:avg_type` in the `fields` parameter (e.g., `outTemp:avg:max`). | No action needed. |

### HIGH (renders wrong)
| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| H1 | No axis labels | Belchertown auto-derives from weewx unit system; migration tool doesn't inject | Migration tool injects default axis labels for common observation types |
| H2 | Right axis has no tick numbers | No data maps to right axis (custom SQL rain not merged) | Fix C2 + ensure right YAxis renders ticks |
| H3 | Chart margins too small | Hardcoded `{top:5, right:5, bottom:5, left:5}` | Match MonthlyAveragesCard: `{top:8, right:55, left:15, bottom:8}` when right axis present |
| H4 | numberFormat config ignored | Parsed but never read by renderer | Use `Intl.NumberFormat` in tooltip formatter with config decimals/decimalPoint/thousandsSep |
| H5 | Wind direction compass labels missing | Belchertown converts 0-360° to compass labels on right YAxis | Add tickFormatter for windDir axis: `(v) => compassLabel(v)` |
| H6 | Tooltip shows raw float values | No rounding, no unit labels | Format with numberFormat config or default to 1 decimal |

### MEDIUM (styling/layout wrong)
| # | Bug | Root cause | Fix |
|---|-----|-----------|-----|
| M1 | Charts not in cards | ConfigDrivenGroup renders bare over background | Single Card per group with glass surface |
| M2 | No card title | Group title missing from card | CardHeader with group title |
| M3 | Chart titles floating/mispositioned | sr-only caption bleeding through | Proper centered `<h3>` per chart, remove sr-only caption bleed |
| M4 | Export buttons outside card | Render between tab card and chart | Move inside group Card |
| M5 | Date range buttons outside card | Same | Move inside group Card |
| M6 | Charts stacked full-width | Belchertown uses 2-column grid | Consider 2-column grid for charts within a group |
| M7 | ResponsiveContainer width inconsistent | "99%" vs "100%" | Standardize to "99%" per Recharts reference |

---

## 2. Implementation phases

### PHASE 0 — Migration tool: produce a COMPLETE charts.conf (API repo)

The migration tool must bridge the gap between what Belchertown derives at runtime from weewx's unit system and what Clear Skies needs in the static config file. Every piece of information that Belchertown's Python backend auto-generates (axis labels, unit labels, number formatting, observation aliases) must be injected into charts.conf by the migration tool.

**T0.1 — Inject default axis labels for common observation types**
- Owner: `clearskies-api-dev` · QC: coordinator (verify labels in migrated config)
- File: `tools/migrate_charts.py`
- Do: After walking sections, scan each chart's series. For the FIRST series on each axis (yAxis=0 left, yAxis=1 right) that lacks `yAxis_label`, inject a default based on the observation type:

  | Observation type(s) | Default yAxis_label |
  |---------------------|-------------------|
  | outTemp, dewpoint, windchill, heatindex, inTemp | Temperature (°F) |
  | windSpeed, windGust | Wind Speed (mph) |
  | windDir | Wind Direction (°) |
  | barometer, pressure, altimeter | Barometer (inHg) |
  | rainRate | Rain Rate (in/hr) |
  | rain, rainTotal | Rain (in) |
  | radiation, maxSolarRad | Solar Radiation (W/m²) |
  | UV | UV Index |
  | lightning_strike_count | Number of Strikes |
  | lightning_distance | Distance (miles) |
  | outHumidity, inHumidity | Humidity (%) |
  | aqi | AQI |

  Note: these defaults assume US units. A future enhancement could read the weewx.conf unit system and adjust. For now, US defaults match the operator's current Belchertown installation.

- Accept: Re-migrated charts.conf has `yAxis_label` on temperature, wind, barometer, rain, solar, UV, lightning series. No encoding errors (handle ° symbol correctly — write file as UTF-8).

**T0.2 — Inject number formatting defaults**
- Owner: `clearskies-api-dev` · QC: coordinator
- File: `tools/migrate_charts.py`
- Do: For series that Belchertown applies specific rounding to (from weewx StringFormats), inject `[[[[numberFormat]]]]` sub-sections if not already present:

  | Observation type | Default decimals |
  |-----------------|-----------------|
  | outTemp, dewpoint, windchill, heatindex | 1 |
  | barometer | 3 |
  | rain, rainRate, rainTotal | 2 |
  | windSpeed, windGust | 1 |
  | UV | 1 |
  | radiation | 0 |
  | lightning_strike_count | 0 |
  | lightning_distance | 1 |

- Accept: Re-migrated charts.conf has numberFormat.decimals on series that need non-default rounding.

**T0.3 — Handle observation aliases in migration**
- Owner: `clearskies-api-dev` · QC: coordinator
- File: `tools/migrate_charts.py`
- Do: When a series uses `rainTotal` as its seriesId, ensure the migrated config has `observation_type = rain` so the archive fetch uses the correct DB column name. Same for any other Belchertown aliases that don't map 1:1 to DB column names. Document the alias map in the migration tool.
- Accept: `rainTotal` series in charts.conf has `observation_type = rain`. Archive fetch returns rain data for this series.

**T0.4 — Remove stale UNSUPPORTED comments from operator's graphs.conf**
- Owner: `clearskies-api-dev` · QC: coordinator
- File: `tools/migrate_charts.py`
- Do: The operator's local `skins/Belchertown/graphs.conf` was polluted with `# UNSUPPORTED:` comments from a prior migration run. The migration tool should strip any pre-existing `# UNSUPPORTED:` and `# NOTE:` comments from the INPUT file before processing, so they don't accumulate on repeated migrations.
- Accept: Running migration twice produces identical output. No duplicate comment accumulation.

**T0.5 — Re-run migration and deploy**
- Owner: coordinator
- Do: Run updated migration tool against `/etc/weewx/skins/Belchertown/graphs.conf` on weewx container. Deploy to `/etc/weewx-clearskies/charts.conf`. Restart API. Flush Redis. Verify `/charts/config` response has axis labels and numberFormat on relevant series.
- Accept: API serves complete config with all injected fields. 6 groups, all series have axis labels.

### PHASE 1 — Data pipeline fixes (Dashboard)

**T1.1 — Fix archive field collection**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify API request contains all fields)
- File: `ConfigDrivenGroup.tsx`
- Do: Use `observationType ?? seriesId` for field collection. Skip virtual series (windRose, weatherRange, haysChart). Skip `useCustomSql` series. Alias `rainTotal→rain`. 
- Accept: Archive request includes all observation fields. No 422 errors. All 7 homepage charts receive data.

**T1.2 — Custom SQL data pipeline**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify rain bars render)
- Files: `client.ts` (add `getCustomQuery()`), `useWeatherData.ts` (add `useCustomQueries()` hook), `ConfigDrivenGroup.tsx` (merge)
- Do: `useCustomQueries()` accepts array of series IDs, fetches all in parallel via `Promise.all`, returns `Record<seriesId, [{x,y}]>`. Merge into grouped archive data by month index (x=1-12 → row index 0-11). Merge into regular archive data by timestamp match. Support ANY number of custom SQL series per group.
- Accept: Average Climate chart shows rain column bars. Custom SQL data appears in tooltips.

**T1.3 — Fix climatology field map** — **SUPERSEDED (2026-06-07)**
- `CLIMATOLOGY_FIELD_MAP` and `useClimatologyMonthly` no longer exist. The `allClimatology` data store and `isChartClimatology` detection were removed. Grouped archive charts now use `useGroupedArchive` hook, which calls `GET /api/v1/archive/grouped` per-chart with `xAxis_groupby` detection. Two-level aggregation (`avg:max`, `avg:min`, `avg:sum`) is encoded as `field:agg_type:avg_type` in the API request and dispatched server-side. No client-side field map is needed.
- Charts that were "climatology charts" are now "grouped archive charts" — they use independent per-chart data sourcing via `xAxis_groupby` detection, not a shared `allClimatology` response.

### PHASE 2 — Axis & tooltip fixes (Dashboard)

**T2.1 — Axis label injection in migration tool**
- Owner: `clearskies-api-dev` · QC: coordinator (re-migrate and verify labels appear)
- File: `tools/migrate_charts.py`
- Do: After walking sections, inject default `yAxis_label` for common observation types when not set. Map: outTemp/dewpoint/windchill/heatindex → "Temperature (°F)", windSpeed/windGust → "Wind Speed (mph)", barometer → "Barometer (inHg)", rainRate → "Rain Rate (in/hr)", rain/rainTotal → "Rain (in)", radiation → "Solar Radiation (W/m²)", UV → "UV Index", lightning_strike_count → "Number of Strikes", lightning_distance → "Distance (miles)". Handle encoding (degree symbol).
- Accept: Re-migrated charts.conf has axis labels on temperature, wind, barometer, rain, solar, UV, lightning series. API restart shows labels.

**T2.2 — Fix right axis tick numbers**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify right axis shows numbers)
- File: `ConfigDrivenChart.tsx`
- Do: Ensure right YAxis `tick` prop is always set when `rightAxisNeeded`. Current code already does this — the issue is that without data on the right axis (C2 fix), Recharts has no domain to generate ticks. After C2 fix, right axis should auto-generate ticks. If not, set explicit `domain` from series `yAxisMin`/`yAxisMax`.
- Accept: Wind direction chart right axis shows 0-360 tick numbers. Rain chart right axis shows rain values.

**T2.3 — Wind direction compass labels**
- Owner: `clearskies-dashboard-dev` · QC: coordinator
- File: `ConfigDrivenChart.tsx`
- Do: Detect when a series on the right axis is `windDir` (seriesId or observationType). Apply `tickFormatter` that converts degrees to compass labels: 0→N, 45→NE, 90→E, 135→SE, 180→S, 225→SW, 270→W, 315→NW, 360→N. Only apply when `yAxisMax=360`.
- Accept: Wind Speed and Direction chart shows N/NE/E/SE/S/SW/W/NW on right axis.

**T2.4 — Tooltip number formatting**
- Owner: `clearskies-dashboard-dev` · QC: coordinator
- File: `ConfigDrivenChart.tsx`
- Do: In Tooltip, use custom `formatter` that reads `series.numberFormat` (decimals, decimalPoint, thousandsSep) and applies via `Intl.NumberFormat` or manual formatting. Default to 1 decimal place when no numberFormat specified. Show unit from axis label if available.
- Accept: Tooltip shows "67.8°F" not "67.83410311645699". Wind direction tooltip shows compass label.

### PHASE 3 — Layout & card structure (Dashboard)

**T3.1 — Group Card with title + controls inside**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (visual render)
- File: `ConfigDrivenGroup.tsx`
- Do: Wrap entire group content (date controls + export buttons + charts + table view) in single `<Card footprint="full">`. Add `<CardHeader><CardTitle as="h2">{group.title}</CardTitle></CardHeader>`. Date range buttons render inside the card below the title. Export buttons render as small icons in the card header or below the title row.
- Accept: Each chart group is a glass card with its title visible. No floating elements.

**T3.2 — Per-chart title formatting**
- Owner: `clearskies-dashboard-dev` · QC: coordinator
- File: `ConfigDrivenChart.tsx`
- Do: Render chart title as centered `<h3 className="text-sm font-semibold text-center">`. Remove duplicate sr-only caption that bleeds into visible layout (add `className="sr-only"` directly to `<caption>` element).
- Accept: Each chart has a clean centered title. No duplicate text.

**T3.3 — Chart margins matching reference**
- Owner: `clearskies-dashboard-dev` · QC: coordinator
- File: `ConfigDrivenChart.tsx`
- Do: Set margin to `{top:8, right: rightAxisNeeded ? 55 : 10, bottom:8, left:15}`. Match MonthlyAveragesCard.
- Accept: Axis labels not clipped. Right axis label fully visible.

### PHASE 4 — Remaining config field wiring (Dashboard)

**T4.1 — Wire all unused SeriesConfig fields**
- Owner: `clearskies-dashboard-dev` · QC: coordinator + auditor
- File: `ConfigDrivenChart.tsx`
- Fields to wire:
  - `softMin`/`softMax` → YAxis domain computed as `[Math.min(softMin, 'dataMin'), Math.max(softMax, 'dataMax')]`
  - `borderWidth` → Bar `stroke` + `strokeWidth`
  - `numberFormat` → tooltip/axis tick formatter
  - `yAxisMinorTicks` → finer CartesianGrid (if feasible in Recharts)
  - `states` → parse but most are no-ops in Recharts (lineWidthPlus=0 is default)
  - `connectEnds` → only relevant for polar charts
  - `polar` → would require PolarGrid/PolarAngleAxis/PolarRadiusAxis (complex, defer if needed)
- Accept: Every field in SeriesConfig that can be rendered in Recharts IS rendered. Unsupported fields documented.

### PHASE 5 — Migration tool + redeploy

**T5.1 — Re-run migration with axis labels**
- Owner: coordinator
- Do: Run updated migration tool. Deploy new charts.conf to weewx. Restart API. Flush Redis.
- Accept: API logs show 6 groups. All axis labels present in `/charts/config` response.

**T5.2 — Deploy dashboard and visual verification**
- Owner: coordinator
- Checklist:
  - [ ] Average Climate: 3 temp lines + rain bars, left axis "Temperature (°F)", right axis "Avg Monthly Rain Total (in)" with numbers, card title, centered chart title
  - [ ] Last 24 Hours/Temperature: 4 lines (outTemp, windchill, heatindex, dewpoint) with distinct colors, left axis "Temperature (°F)"
  - [ ] Last 24 Hours/Wind: windDir as scatter dots (correct color), windGust line, windSpeed line, left axis "Wind Speed (mph)", right axis 0-360 with compass labels
  - [ ] Last 24 Hours/Wind Rose: polar chart rendering with Beaufort colors
  - [ ] Last 24 Hours/Rain: rainRate line, rainTotal line, dual axis
  - [ ] Last 24 Hours/Barometer: spline line, axis with fine ticks
  - [ ] Last 24 Hours/Solar+UV: radiation + maxSolarRad (area) + UV on right axis
  - [ ] Last 24 Hours/Lightning: scatter-style dots (lineWidth=0, markers), dual axis
  - [x] Monthly tab with year/month dropdowns (2026-06-07: year/month dropdowns moved inside Card; hasRangeChart no longer blocks main fetch; time_length string parsing added)
  - [x] Yearly tab with weather range chart (2026-06-07: WeatherRangeChart rewritten as Recharts arearange with 15-band temperature color zones)
  - [ ] TS Hilary tab with page_content + epoch dates
  - [x] Air Quality tab with aqi chart (2026-06-07: all archive columns served without whitelist gate — aqi column queryable by DB column name)
  - [ ] All charts in glass cards with titles
  - [ ] Date range buttons work (1d/3d/7d/30d/90d)
  - [ ] Chart/table toggle works
  - [ ] Export buttons (PNG/CSV) inside cards
  - [ ] Both light and dark themes render
  - [ ] `tsc --noEmit` → 0 errors, `vite build` clean
  - [ ] axe-core: 0 new violations

---

## 3. QC gates

### Gate 1 — Code quality (every phase)
- `tsc --noEmit` → 0 errors
- `vite build` → clean
- `ruff` + `mypy` → 0 introduced errors (API)
- No dead code, unused imports, commented-out blocks

### Gate 2 — Feature correctness (per task)
- Coordinator renders the chart page and visually compares against Belchertown
- Config round-trip verified: key in graphs.conf → charts.conf → API JSON → dashboard render
- MonthlyAveragesCard quality bar: each chart must look as good as the Almanac version

### Gate 3 — Architecture + ADR compliance
- ADR-041/042: No unit conversion in dashboard. All derived values from API.
- ADR-010: No chart-specific API endpoints added.
- ARCHITECTURE.md layer responsibilities respected.

### Gate 4 — Accessibility (WCAG 2.1 AA)
- sr-only data table for every chart
- Keyboard-reachable interactive elements
- Color is not the only signal
- axe-core: 0 new violations

### Gate 5 — Belchertown parity
- Every chart group in Belchertown has a rendered equivalent
- Side-by-side comparison: each chart must produce visually equivalent output
- Migration tool produces zero UNSUPPORTED warnings

---

## 4. Agent assignments

| Phase | Task | Owner | QC |
|-------|------|-------|----|
| 0 | T0.1 Axis label injection | `clearskies-api-dev` | Coordinator: verify migrated config |
| 0 | T0.2 Number format defaults | `clearskies-api-dev` | Coordinator: verify decimals in config |
| 0 | T0.3 Observation aliases | `clearskies-api-dev` | Coordinator: verify rainTotal→rain |
| 0 | T0.4 Strip stale comments | `clearskies-api-dev` | Coordinator: run twice, diff output |
| 0 | T0.5 Re-migrate + deploy | Coordinator | Self |
| 1 | T1.1 Field collection fix | `clearskies-dashboard-dev` | Coordinator: verify API request |
| 1 | T1.2 Custom SQL pipeline | `clearskies-dashboard-dev` | Coordinator: verify rain bars |
| 1 | ~~T1.3 Climatology field map~~ | SUPERSEDED — `CLIMATOLOGY_FIELD_MAP` removed; grouped archive via `useGroupedArchive` + `/archive/grouped` | — |
| 2 | T2.1 Migration tool axis labels | `clearskies-api-dev` | Coordinator: re-migrate + verify |
| 2 | T2.2 Right axis tick fix | `clearskies-dashboard-dev` | Coordinator: verify right axis numbers |
| 2 | T2.3 Compass labels | `clearskies-dashboard-dev` | Coordinator: verify N/E/S/W |
| 2 | T2.4 Tooltip formatting | `clearskies-dashboard-dev` | Coordinator: verify decimal rounding |
| 3 | T3.1 Group Card layout | `clearskies-dashboard-dev` | Coordinator: visual render |
| 3 | T3.2 Chart title formatting | `clearskies-dashboard-dev` | Coordinator: visual render |
| 3 | T3.3 Chart margins | `clearskies-dashboard-dev` | Coordinator: verify no clipping |
| 4 | T4.1 Wire unused config fields | `clearskies-dashboard-dev` | Coordinator + `clearskies-auditor` |
| 5 | T5.1 Re-migrate + deploy | Coordinator | Self |
| 5 | T5.2 Visual verification | Coordinator | Self (side-by-side with Belchertown) |

---

## 5. What's NOT ported (documented exceptions)

| Feature | Why | Impact |
|---------|-----|--------|
| Open-ended Highcharts pass-through | Recharts is component-based, not config-driven | Operators using exotic Highcharts options need feature requests |
| `generate = daily` | Static HTML generation; Clear Skies fetches live | None |
| Highstock navigator/scrollbar/rangeSelector | Disabled in Belchertown | None |
| `chart.zoomType = 'x'` | No built-in Recharts zoom | Future: Brush component |
| Polar coordinate system for operator-requested charts | `polar = true` in charts.conf triggers Recharts PolarGrid. WeatherRangeChart uses Cartesian arearange by default (correct per Belchertown wiki); polar mode available via `polar = true`. HaysChart is always polar by design. | Full PolarGrid support for arbitrary operator charts deferred. |

---

## 6. Implementation reference

### Working reference (copy these patterns)
- `MonthlyAveragesCard.tsx` lines 226-311: proper ComposedChart with dual axes, Bar + Line, correct margins, axis labels, custom dots
- `MonthlyAveragesCard.tsx` lines 239-263: YAxis with label, tickFormatter, proper styling
- `MonthlyAveragesCard.tsx` lines 272-280: Bar element with yAxisId, fill, fillOpacity, radius

### Files to modify
- `weewx_clearskies_api/tools/migrate_charts.py` — axis labels, number format, aliases, comment cleanup (Phase 0)
- `src/components/charts/ConfigDrivenChart.tsx` — renderer rewrite (Phases 2-4)
- `src/components/charts/ConfigDrivenGroup.tsx` — data pipeline + layout (Phases 1, 3)
- `src/api/client.ts` — add getCustomQuery() (Phase 1)
- `src/hooks/useWeatherData.ts` — add useCustomQueries() (Phase 1)

### Recharts rules (from docs/reference/recharts-axis-reference.md)
- NO negative margins
- NO `hide` on YAxis (bug #428) — use phantom axis workaround
- NO `margin.bottom` for labels — XAxis `height` controls label space
- Use `width="99%"` on ResponsiveContainer (not 100%)
- Use `interval={0}` with explicit `ticks` arrays
- Container div needs `minWidth:0, minHeight:0, width:'100%', height:'100%'`
