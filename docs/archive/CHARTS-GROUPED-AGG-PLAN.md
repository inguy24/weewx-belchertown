# Charts System Fix — Undo Bandaids, Mirror Belchertown Faithfully

**Status:** APPROVED
**Date:** 2026-06-07
**Component:** API (`/archive/grouped`), Dashboard (ConfigDrivenGroup rewrite), Migration tool
**Parent:** [CHARTS-REWRITE-PLAN.md](CHARTS-REWRITE-PLAN.md)

---

## Context

Session f72c6d67 (2026-06-07) wasted time and money because the charts system invented interpretation logic instead of faithfully mirroring Belchertown. The system created a "climatology" special path, group-level mode detection, stock column gates, and arbitrary API limits — all bandaids that break for any operator with a different `graphs.conf`.

**Problem summary:** Belchertown has 5 data paths in `get_observation_data()` (bin/user/belchertown.py lines 3861–4990): windRose, weatherRange, haysChart, xAxis_groupby (categorical aggregation using `archive_day_*` tables or raw archive), and standard time-series. Clear Skies incorrectly replaced the `xAxis_groupby` path with a hardcoded `/climatology/monthly` endpoint that serves 4 fixed fields with no time filtering and no per-field aggregation control. This endpoint must be replaced with a general-purpose grouped aggregation endpoint.

**Design principles (agreed with user 2026-06-07):**
1. The config IS the specification — no interpretation, no auto-detection by container name
2. Migration tool surfaces ALL Belchertown implicit behaviors as explicit `charts.conf` values
3. Known series types (`weatherRange`, `haysChart`, `windRose`) have appropriate dynamic defaults — explicit config always overrides
4. `force_full_year` defaults true for year-spanning charts
5. No "climatology" concept — it's just `xAxis_groupby` with a time range
6. Each chart independently sources its own data — group is just a container
7. Per-field aggregation: each series carries its own `aggregate_type` + `average_type`

**Proportional scaling status:** Already implemented and working for the standard `/archive` path (rolling ranges). NOT affected by this plan. The `xAxis_groupby` charts bypass proportional scaling entirely — they use `/archive/grouped` which groups by calendar period (month/day/year), not fixed-width time buckets. T-A3 fixes the default per-field aggregation fallback for fields not in `agg_map`.

---

## 0. Orientation

- **Load:** [CLAUDE.md](../../../CLAUDE.md), [rules/coding.md](../../../rules/coding.md), [docs/ARCHITECTURE.md](../../ARCHITECTURE.md), [docs/decisions/ADR-054-configurable-charts.md](../../decisions/ADR-054-configurable-charts.md), [docs/reference/belchertown-auto-behaviors.md](../../reference/belchertown-auto-behaviors.md), [docs/reference/recharts-components-reference.md](../../reference/recharts-components-reference.md)
- **Repos:** `weewx-clearskies-api` (new endpoint + remove climatology), `weewx-clearskies-dashboard` (ConfigDrivenGroup rewrite), `weather-belchertown` (meta/docs/graphs.conf revert)
- **Belchertown source:** `bin/user/belchertown.py` lines 4476–4896 (xAxis_groupby SQL), lines 3504–3560 (proportional scaling), lines 3861–4990 (get_observation_data)
- **Existing generalized SQL patterns to reuse:** `weewx_clearskies_api/services/climatology.py` lines 342–493 — two-level aggregation helpers (`_query_avg_of_daily_agg`, `_query_straight_avg`, `_query_avg_of_monthly_total`, `_query_monthly_sum`). These have the correct SQL for both SQLite and MySQL but lack `from`/`to` time filtering and only support `group_by=month`.
- **Dashboard files to modify:** `src/components/charts/ConfigDrivenGroup.tsx` (964 lines — climatology code at lines 120–131, 253–255, 301, 415, 463–464, 483, 570, 579, 583–620, 664–665, 678, 681, 685, 694, 699, 1252–1255), `src/routes/almanac.tsx` (line 56), `src/components/almanac/MonthlyAveragesCard.tsx`
- **Deploy:** API on weewx container (`systemctl restart weewx-clearskies-api`, wait 120s for cache warmer), Dashboard on weather-dev (`scripts/redeploy-weather-dev.sh` or manual npm build + rsync)

### Git safety
Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree.

---

## 1. Issue Inventory

### ARCHITECTURAL (wrong by design — must be ripped out)

| # | Issue | Root cause | Fix |
|---|-------|-----------|-----|
| A1 | `/climatology/monthly` endpoint hardcodes 4 fields, no time filter, no per-field agg | Invented "climatology" concept instead of generalized grouped aggregation | Replace with `/archive/grouped` accepting per-field specs + time range |
| A2 | `allClimatology` group-level flag blocks archive data for all charts | Group-level mode detection | Remove — each chart independently sources data |
| A3 | `CLIMATOLOGY_FIELD_MAP` manually maps series config to hardcoded response keys | Bandaid for a broken endpoint | Remove — new endpoint returns data keyed by field name |
| A4 | `useClimatologyMonthly` hook fetches all-time data regardless of selected year | No time filtering | Remove — new hook passes `from`/`to` from selected year |
| A5 | `hasRangeChart` was blocking main archive fetch for all other charts in group | Group-level mode detection | Already partially fixed but root cause (group-level flags) persists |
| A6 | Almanac page `MonthlyAveragesCard` depends on `/climatology/monthly` | Will break when endpoint is removed | Rewire to use `/archive/grouped` |

### DATA CORRECTNESS (produces wrong values)

| # | Issue | Root cause | Fix |
|---|-------|-----------|-----|
| D1 | Custom-interval mode defaults ALL fields to AVG | `archive.py` line 599: `resolved_map.get(col, "avg")` | Use `DAY_AGGREGATOR.get(col, "avg")` as fallback |
| D2 | Grouped charts don't filter by selected year | No `from`/`to` on climatology endpoint | New endpoint accepts time range |
| D3 | `average_type` not implemented for grouped charts | Only works via the climatology endpoint (which is being removed) | New `/archive/grouped` endpoint handles per-field `average_type` |

### RENDERING (visual bandaids from prior session)

| # | Issue | Root cause | Fix |
|---|-------|-----------|-----|
| R1 | weatherRange uses gradient instead of flat color bands | Recharts SVG gradient misuse | Multiple `<ReferenceArea>` with solid fills per temperature zone |
| R2 | Y-axis doesn't auto-scale to data | Domain hardcoded or poorly computed | `domain` snaps to nearest 5 around actual data min/max |
| R3 | X-axis formatter keyed on `selectedRange` (rolling range button) | Doesn't work for year/month groups (no rolling range) | Derive format from actual `from`/`to` time range |
| R4 | Charts not same width (weatherRange wider than others) | Per-chart sizing instead of shared container | All charts use identical ResponsiveContainer + margin config |

---

## 2. Implementation Phases

### PHASE A — New API endpoint: `/archive/grouped` (API repo)

**T-A1: Create `/archive/grouped` endpoint**
- Owner: `clearskies-api-dev` · QC: coordinator (verify response shape)
- Files: NEW `endpoints/archive_grouped.py`, modify `app.py` (register router)
- Do: New endpoint `GET /api/v1/archive/grouped` with parameters:
  - `group_by`: required, one of `month`, `day`, `hour`, `year`
  - `from` / `to`: optional epoch or ISO timestamps (omit = all time)
  - `fields`: required, comma-separated per-field specs in format `field:aggregate_type:average_type`
    - Examples: `outTemp:avg:max`, `outTemp:avg:min`, `rain:avg:sum`, `dewpoint:avg`
    - `average_type` is optional (omit for straight aggregation)
  - `force_full_period`: optional boolean, default `true` for `group_by=month`
- Response shape:
  ```json
  {
    "data": {
      "labels": ["01", "02", ..., "12"],
      "series": {
        "outTemp:avg:max": [72.3, 68.1, ...],
        "outTemp:avg:min": [45.2, 42.8, ...],
        "rain:avg:sum": [2.8, 3.5, ...],
        "dewpoint:avg": [52.1, 48.3, ...]
      }
    },
    "generatedAt": "2026-06-07T12:00:00Z"
  }
  ```
- Implementation: Reuse SQL patterns from `services/climatology.py` (lines 342–493). Add `WHERE dateTime >= :from_ts AND dateTime < :to_ts` to all queries. Support `group_by` = month by selecting appropriate SQL expressions (already exist in `_month_number_sql`). Validate field names against `ColumnRegistry`. Null-pad missing periods when `force_full_period = true`.
- Accept: `GET /archive/grouped?group_by=month&fields=outTemp:avg:max,rain:avg:sum` returns 12-element arrays. With `from`/`to` for 2025: returns only 2025 data. Without: returns all-time averages.

**T-A2: Per-field aggregation routing**
- Owner: `clearskies-api-dev` · QC: coordinator (verify rain=sum, temp=max produce different values)
- File: NEW `services/archive_grouped.py`
- Do: Parse `fields` param into `[(field, aggregate_type, average_type), ...]`. For each field, dispatch to appropriate SQL helper:
  - `avg:max` → `_query_avg_of_daily_agg(db, col, "MAX", dialect, from_ts, to_ts, group_by)`
  - `avg:min` → `_query_avg_of_daily_agg(db, col, "MIN", dialect, from_ts, to_ts, group_by)`
  - `avg:sum` → `_query_avg_of_monthly_total(db, col, dialect, from_ts, to_ts, group_by)` (AVG of period SUMs)
  - `avg` (no average_type) → `_query_straight_avg(db, col, dialect, from_ts, to_ts, group_by)` (weighted avg)
  - `sum` → `_query_period_sum(db, col, dialect, from_ts, to_ts, group_by)`
  - `max` → `_query_period_max(db, col, dialect, from_ts, to_ts, group_by)`
  - `min` → `_query_period_min(db, col, dialect, from_ts, to_ts, group_by)`
- Accept: Same request with `outTemp:avg:max` and `rain:avg:sum` returns different aggregation strategies per field. Rain values are demonstrably higher (monthly totals averaged) vs if they were just AVG'd.

**T-A3: Fix custom-interval default aggregation (archive.py line 599)**
- Owner: `clearskies-api-dev` · QC: coordinator (verify rain defaults to sum, windSpeed to max when not in agg_map)
- File: `services/archive.py` line 599
- Do: Change `resolved_map.get(col, "avg").upper()` to `resolved_map.get(col, DAY_AGGREGATOR.get(col, "avg")).upper()`
- Accept: A request with `aggregate_interval=3600` and no `agg_map` for rain returns SUM values (not AVG). windSpeed returns MAX (not AVG).

### PHASE B — Remove climatology endpoint (API repo)

**T-B1: Delete `/climatology/monthly` endpoint and service**
- Owner: `clearskies-api-dev` · QC: coordinator (verify API starts without it)
- Files: DELETE `endpoints/climatology.py`, DELETE `services/climatology.py`, modify `app.py` (remove router registration), modify `config/settings.py` (remove any climatology config), modify `services/cache_warmer.py` (remove climatology warming)
- Do: Remove all traces of the climatology endpoint. The `/archive/grouped` endpoint replaces it entirely.
- Accept: API starts clean. `GET /climatology/monthly` returns 404. All other endpoints work. `ruff` + `mypy` clean.

### PHASE C — Dashboard: Replace climatology with grouped archive (Dashboard repo)

**T-C1: New `useGroupedArchive` hook**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify correct API call)
- Files: `hooks/useWeatherData.ts`, `api/client.ts`, `api/types.ts`
- Do: Add `getGroupedArchive(params)` client function calling `GET /archive/grouped`. Add `useGroupedArchive(params)` hook. Params built from chart config: `group_by` from `chart.xAxisGroupby`, `fields` from series `observationType:aggregateType:averageType`, `from`/`to` from selected year/time range.
- Accept: Hook returns `{ labels: string[], series: Record<string, (number|null)[]> }`. Correctly passes time range.

**T-C2: Rip out all climatology code from ConfigDrivenGroup**
- Owner: `clearskies-dashboard-dev` · QC: coordinator + auditor (verify no `climatology` string in file)
- File: `components/charts/ConfigDrivenGroup.tsx`
- Do: Remove:
  - `CLIMATOLOGY_FIELD_MAP` (lines 120–131)
  - `allClimatology` variable and all usages (lines 253–255, 301, 415, 463–464, 570, 579, 664–665, 694, 699)
  - `useClimatologyMonthly()` call (line 483)
  - `climatologyData` useMemo (lines 583–620)
  - `climatologyResult` references in loading/error/refetch (lines 678, 681, 685)
  - Per-chart `isChartClimatology` routing (line 1252–1255)
- Replace with: Each chart with `xAxisGroupby` calls `useGroupedArchive` with its own params. Charts WITHOUT `xAxisGroupby` use the existing archive data. Both can coexist in the same group.
- Accept: `grep -r "climatology" src/components/charts/` returns ZERO results (excluding comments explaining the removal). All chart groups still render.

**T-C3: Per-chart independent data sourcing**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify mixed groups work)
- File: `components/charts/ConfigDrivenGroup.tsx`
- Do: In the rendering loop, each chart determines its own data:
  - Chart has `xAxisGroupby` → use grouped archive data for that chart
  - Chart has `windRose` series → use wind rose data (existing)
  - Chart has `weatherRange`/`haysChart` → use range data (existing)
  - Everything else → use standard archive data (existing)
  No group-level flags determine data mode. A group can have ALL of these chart types simultaneously.
- Accept: The ANNUAL group (which has climatology chart + weatherRange + Wind + Rain + Barometer + Lightning) renders ALL charts with data. No "Unable to load" errors.

**T-C4: Rewire Almanac page `MonthlyAveragesCard`**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify almanac page still renders chart)
- Files: `routes/almanac.tsx`, `components/almanac/MonthlyAveragesCard.tsx`
- Do: The Almanac page has a `MonthlyAveragesCard` that calls `useClimatologyMonthly()` (line 56 of `almanac.tsx`). Rewire it to use `useGroupedArchive` with params: `group_by=month`, `fields=outTemp:avg:max,outTemp:avg:min,dewpoint:avg,rain:avg:sum`, no `from`/`to` (all-time). Update `MonthlyAveragesCard` props to accept the new response shape instead of `ClimatologyMonthly`.
- Accept: Almanac page renders monthly averages chart correctly. Same visual output as before. No reference to `ClimatologyMonthly` type.

**T-C5: Remove `useClimatologyMonthly` and related dead code**
- Owner: `clearskies-dashboard-dev` · QC: coordinator
- Files: `hooks/useWeatherData.ts` (remove hook), `api/client.ts` (remove `getClimatologyMonthly`), `api/types.ts` (remove `ClimatologyMonthly` interface), `mock/climatology.ts` (delete), `api/openapi-v1.yaml` (remove `/climatology/monthly` spec)
- Accept: `tsc --noEmit` passes. No imports of removed code. Build clean. `grep -r "climatology" src/` returns ZERO (excluding comments).

### PHASE D — Dashboard rendering fixes

**T-D1: weatherRange flat color bands**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (visual render — MUST VIEW PNG)
- File: `components/charts/WeatherRangeChart.tsx`
- Do: Replace gradient/stacked-area approach with Recharts `<ReferenceArea>` components — one per temperature zone with a solid fill color. Zones from Belchertown (15 bands for °F, 15 for °C — already documented in `docs/reference/belchertown-auto-behaviors.md` lines 109–129). The area chart renders the high/low band on top; the reference areas behind provide the color zones.
- Accept: Rendered PNG shows distinct flat color bands (like Highcharts zones), NOT blended gradients. Green at bottom (cold), through yellow/gold, to orange/red at top (hot). Side-by-side with Belchertown screenshot — colors match.

**T-D2: Y-axis auto-scaling**
- Owner: `clearskies-dashboard-dev` · QC: coordinator (verify no empty space)
- Files: `ConfigDrivenChart.tsx`, `WeatherRangeChart.tsx`
- Do: Domain = `[floor(dataMin/5)*5, ceil(dataMax/5)*5]`. Ticks = every 5 units within domain. Use `allowDataOverflow={false}`. Match Belchertown: `Math.ceil(Math.round(max / 5) / 5) * 5` for tick interval.
- Accept: Temperature chart for June data (58–78°F) shows Y-axis 55–80 with ticks at 55, 60, 65, 70, 75, 80. No empty space above or below data.

**T-D3: X-axis adaptive formatting**
- Owner: `clearskies-dashboard-dev` · QC: coordinator
- File: `ConfigDrivenGroup.tsx` (`formatTimestamp` function, line 137)
- Do: Instead of keying on `selectedRange` (which doesn't exist for year/month groups), compute the actual displayed time range from `archiveParams.from`/`archiveParams.to` and pick format accordingly. For grouped charts (`xAxisGroupby`), use `xAxis_categories` from config as labels (not timestamps at all).
- Accept: Monthly charts show month names. Daily rolling range shows dates. 24-hour shows times. No "undefined" or wrong format.

**T-D4: `force_full_year` default behavior**
- Owner: `clearskies-dashboard-dev` · QC: coordinator
- File: `ConfigDrivenGroup.tsx`
- Do: When building grouped archive params, if `group_by=month` and the group has `available_years` OR `time_length = year/all`, default `force_full_period = true`. The API pads missing months with null. Charts show 12 months even if data is incomplete.
- Accept: Viewing 2026 (which only has Jan–Jun data) shows 12 months on X-axis with Jul–Dec as gaps.

### PHASE E — Migration tool verification

**T-E1: Verify all Belchertown implicit behaviors are injected**
- Owner: `clearskies-api-dev` · QC: coordinator (diff migrated output vs expected)
- File: `tools/migrate_charts.py`
- Do: Verify (and fix if missing) that the migration tool injects:
  - `rainTotal` → `observation_type = rain`, `aggregate_type = sumcumulative`
  - `rainRate` → `aggregate_type = max`
  - `weatherRange` → `aggregate_interval = 86400`
  - `windRose` → nothing extra needed (runtime knows this series type)
  - `windDir` with `lineWidth = 0` → `type = scatter`
  - `barometer` → `yAxisTickDecimals = 2`
  - rain series → `yAxis_min = 0`
  - line/spline/area → `markerEnabled = false`
- Accept: Run migration tool on operator's `graphs.conf`. Diff output against expected. Every implicit behavior is explicit in the output.

### PHASE F — Documentation + ADR updates

**T-F1: Update ADR-054 (configurable charts)**
- Owner: `clearskies-docs-author` · QC: coordinator (verify no stale references)
- File: `docs/decisions/ADR-054-configurable-charts.md`
- Do:
  - Remove all references to `/climatology/monthly` endpoint
  - Add `/archive/grouped` endpoint documentation (parameters, response shape, per-field aggregation)
  - Document `average_type` as a per-series config key with spec format `field:aggregate_type:average_type`
  - Add design principle: "No climatology concept — `xAxis_groupby` with a time range replaces it"
  - Update Consequences section: remove climatology endpoint mention, add `/archive/grouped`
  - Update point 9 (Special series types table) if affected
  - Verify line 68 reference to `/climatology/monthly` is removed
- Accept: ADR-054 accurately describes the new system. Zero references to `/climatology/monthly`. All stated design principles are present.

**T-F2: Update ARCHITECTURE.md API endpoints table**
- Owner: `clearskies-docs-author` · QC: coordinator (verify endpoint table matches reality)
- File: `docs/ARCHITECTURE.md`
- Do:
  - Remove `/api/v1/climatology/monthly` from the Data endpoints table (currently not listed — verify)
  - Add `/api/v1/archive/grouped` to the Data endpoints table with purpose: "Categorical aggregation grouped by calendar period (month/day/hour/year), per-field aggregate_type + average_type"
  - Update Charts configuration section (lines 382–408): document that `xAxis_groupby` charts use `/archive/grouped` not a separate climatology endpoint
  - Update "Layer Responsibilities" table if needed (API does SQL grouping — this is general data access, not chart logic)
  - Remove any lingering reference to a climatology endpoint
- Accept: ARCHITECTURE.md endpoint table matches the actual running API. Charts section describes the correct data flow.

**T-F3: Update belchertown-auto-behaviors.md gap status**
- Owner: `clearskies-docs-author` · QC: coordinator
- File: `docs/reference/belchertown-auto-behaviors.md`
- Do:
  - Update the "Proportional data scaling" row status
  - Update "Per-field aggregation in rolling ranges" row
  - Add row for `xAxis_groupby` grouped aggregation (now working via `/archive/grouped`)
  - Add row for `average_type` two-level aggregation
  - Mark any newly-closed gaps
- Accept: Gap analysis accurately reflects current implementation state. No false "CLOSED" claims.

**T-F4: Update CHARTS-REWRITE-PLAN.md status**
- Owner: `clearskies-docs-author` · QC: coordinator
- File: `docs/planning/briefs/CHARTS-REWRITE-PLAN.md`
- Do: Update T1.3 (climatology field map — now removed entirely), update Phase 1 context to reflect that climatology was replaced with grouped archive. Mark any completed tasks. Note that CLIMATOLOGY_FIELD_MAP no longer exists.
- Accept: Plan reflects current reality. No references to code that no longer exists.

### PHASE G — Deploy + verify

**T-G1: Deploy API to weewx container**
- Owner: coordinator
- Do: Pull, install, restart. Verify `/archive/grouped` responds correctly. Wait 120s for cache warmer.

**T-G2: Re-run migration tool**
- Owner: coordinator
- Do: Re-migrate `graphs.conf` → `charts.conf`. Deploy to `/etc/weewx-clearskies/`. Restart API.

**T-G3: Deploy dashboard to weather-dev**
- Owner: coordinator
- Do: Pull, build (`tsc -b && vite build` — ZERO errors), rsync to web root.

**T-G4: Visual verification (MUST RENDER AND VIEW)**
- Owner: coordinator
- Checklist:
  - [ ] `averageclimate` group: all-time monthly averages correct (compare Belchertown)
  - [ ] ANNUAL year selector: 2025 shows 2025-only data, not all-time
  - [ ] Rain in grouped charts shows SUM (not AVG) — values match Belchertown
  - [ ] Temperature shows AVG of daily MAX/MIN correctly
  - [ ] `force_full_year`: viewing 2026 shows Jan–Dec with Jul–Dec as gaps
  - [ ] weatherRange: flat color bands, not gradients
  - [ ] windRose renders in all groups
  - [ ] Y-axis auto-scales tight to data
  - [ ] X-axis shows appropriate labels per chart type
  - [ ] No "Unable to load chart data" errors on any tab
  - [ ] Rolling ranges (1d/3d/7d/30d/90d) work with proportional scaling
  - [ ] Almanac page monthly averages card renders correctly
  - [ ] `tsc --noEmit` → 0 errors
  - [ ] Headless Edge render of charts page — view PNG before declaring done

---

## 3. QC Gates

### Gate 1 — Code quality (every phase)
- `tsc --noEmit` → 0 errors (dashboard)
- `vite build` → clean (dashboard)
- `ruff` + `mypy` → 0 introduced errors (API)
- No dead code, unused imports, commented-out blocks

### Gate 2 — Architecture + ADR compliance (every phase)
- ADR-010: API is general-purpose data access — no chart-specific logic in the API
- ADR-041/042: No unit conversion in dashboard. BFF handles all units.
- ADR-054: Charts are config-driven. No hardcoded chart groups.
- ARCHITECTURE.md layer responsibilities: API does SQL, BFF does conversion, dashboard does rendering
- **No group-level mode detection anywhere in the codebase**
- **No "climatology" concept anywhere in the codebase**
- **The word "climatology" must not appear in any NEW code** (only in removal comments/commit messages)

### Gate 3 — Prompt/plan compliance (every phase)
- Does the implementation match what was agreed in this plan?
- Does it violate any of the 7 design principles listed in Context?
- Would this break for an operator with a different `graphs.conf`?
- Is there any hidden interpretation by container name or chart position?
- If an operator adds a new group tomorrow, does it just work?

### Gate 4 — Visual verification (Phases D, G)
- Render to PNG using headless Edge. VIEW the image. Don't claim visual correctness from code.
- Side-by-side comparison with Belchertown for matching data ranges
- Both light and dark themes

### Gate 5 — Accessibility (WCAG 2.1 AA)
- sr-only data table for every chart
- axe-core: 0 new violations
- Keyboard-reachable interactive elements

---

## 4. Agent Assignments

| Phase | Task | Owner | QC |
|-------|------|-------|----|
| A | T-A1 New endpoint | `clearskies-api-dev` | Coordinator: verify response shape |
| A | T-A2 Per-field routing | `clearskies-api-dev` | Coordinator: verify rain≠temp agg |
| A | T-A3 Fix default aggregation | `clearskies-api-dev` | Coordinator: verify rain=sum default |
| B | T-B1 Delete climatology | `clearskies-api-dev` | Coordinator: API starts clean |
| C | T-C1 New hook | `clearskies-dashboard-dev` | Coordinator: verify API call |
| C | T-C2 Rip out climatology | `clearskies-dashboard-dev` | Coordinator: grep returns 0 |
| C | T-C3 Per-chart data | `clearskies-dashboard-dev` | Coordinator: mixed groups work |
| C | T-C4 Almanac rewire | `clearskies-dashboard-dev` | Coordinator: almanac renders |
| C | T-C5 Dead code removal | `clearskies-dashboard-dev` | Coordinator: build clean |
| D | T-D1 Color bands | `clearskies-dashboard-dev` | Coordinator: VIEW RENDERED PNG |
| D | T-D2 Y-axis scaling | `clearskies-dashboard-dev` | Coordinator: verify domain |
| D | T-D3 X-axis formatting | `clearskies-dashboard-dev` | Coordinator: verify labels |
| D | T-D4 force_full_year | `clearskies-dashboard-dev` | Coordinator: verify 12 months |
| E | T-E1 Migration verify | `clearskies-api-dev` | Coordinator: diff output |
| F | T-F1 ADR-054 update | `clearskies-docs-author` | Coordinator: no stale refs |
| F | T-F2 ARCHITECTURE.md update | `clearskies-docs-author` | Coordinator: endpoints match |
| F | T-F3 Gap analysis update | `clearskies-docs-author` | Coordinator: status accurate |
| F | T-F4 CHARTS-REWRITE-PLAN update | `clearskies-docs-author` | Coordinator: reflects reality |
| G | T-G1–G4 Deploy + verify | Coordinator | Self (visual check) |

---

## 5. What's NOT in this plan (documented scope boundaries)

| Item | Why excluded | When |
|------|-------------|------|
| `archive_day_*` table optimization | Raw archive queries produce correct results (just slower). Optimization deferred. | Future performance pass |
| Full `group_by = day/hour/year` support | Operator only uses `month`. Implement `month` first, extend later. | After this plan verified working |
| Recharts polar chart for arbitrary series | `polar = true` on operator-defined charts. Complex. | Separate plan |
| 2-column chart grid layout | Layout preference — not a correctness issue | Separate UI plan |
| Migration tool: reading weewx unit system for label localization | Currently assumes US units. Works for this operator. | i18n phase |

---

## 6. Revert (immediate, before implementation)

```
git checkout -- skins/Belchertown/graphs.conf
```

This file is the authoritative reference. The cosmetic changes from session f72c6d67 must be reverted.
