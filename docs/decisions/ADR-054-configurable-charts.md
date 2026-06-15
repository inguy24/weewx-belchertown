---
status: Accepted
date: 2026-06-07
deciders: shane
---

# ADR-054: Operator-configurable charts system

## Context

Clear Skies initially shipped with 4 hardcoded chart groups as Python constants and a 1,144-line `charts.tsx` with bespoke tab components. Operators had zero ability to configure which charts appeared, what data they showed, or how they were rendered — a regression from the Belchertown skin, where `graphs.conf` gave operators full control over chart groups, charts, series, aggregation, time ranges, colors, axes, wind roses, and custom SQL queries.

The configurable charts system replaces the hardcoded approach with a `charts.conf`-driven system where operators define everything without touching code.

## Options considered

| Option | Verdict |
|---|---|
| A. ConfigObj/INI config file (`charts.conf`) parsed at API startup | **Selected.** Same format as weewx `skin.conf` and Belchertown `graphs.conf` — operators already know it. Three-level nesting (group → chart → series) is a direct structural match. |
| B. JSON/YAML config file | Rejected — operators in the weewx ecosystem expect INI-style config. JSON lacks comments; YAML's indentation sensitivity is error-prone for non-developers. |
| C. Database-backed chart config with UI editor | Rejected for v0.1 — UI editor is significant scope; operators can edit the INI file directly. Deferred. |
| D. Keep hardcoded charts, add API params for customization | Rejected — doesn't scale. Every new chart type or operator preference requires a code change. |

## Decision

Charts are configured via `charts.conf`, a ConfigObj/INI file with three-level nesting (group → chart → series), parsed at API startup by `services/charts_config.py`, pruned against the `ColumnRegistry`, and served via `GET /api/v1/charts/config`. The dashboard renders dynamically from this config.

Key sub-decisions:

1. **Self-hide pruning:** series whose `observation_type` is not in the `ColumnRegistry` are removed at startup. Empty charts and groups cascade-removed. Operators don't see charts for data their station doesn't collect.

2. **Custom SQL security model:** queries come from the config file on disk (operator-controlled, same trust model as Belchertown) — never from HTTP. Pre-validated at startup via `EXPLAIN`. Executed in read-only transactions with a 10-second timeout and DDL keyword blocklist.

3. **Wind rose as client-side SVG:** custom SVG polar chart in the dashboard, not Recharts `RadialBarChart` (better accessibility and control). Binning reads the API-injected `beaufort` field from archive records (ADR-042). No Beaufort computation in the dashboard (ADR-041 computation boundary amendment).

4. **Weather range chart:** Recharts arearange/columnrange chart showing daily temperature range with 15-band temperature color zones (deep blue for cold through red for hot — matches Belchertown's `get_outTemp_color()` zones). Uses dual archive fetches (`agg=min` and `agg=max`) with `aggregate_interval=86400` (daily). Renders as Cartesian arearange (when `area_display = 1`) or columnrange (default); polar only when operator explicitly sets `polar = true`. This is NOT a polar chart by default — the initial implementation rendered it as a circular polar SVG regardless of config, which was incorrect. Rewritten 2026-06-07 as a standard Recharts arearange chart per Belchertown wiki behavior.

5. **Migration tool:** `clearskies-migrate-charts` CLI converts Belchertown `graphs.conf` → `charts.conf`. Most INI keys are 1:1 by design; unsupported keys are annotated with `# NOTE:` comments. The tool also injects rendering defaults: `markerEnabled=false` on line/spline/area, `type=scatter` promotion for `lineWidth=0` series, `yAxisTickDecimals=2` for barometer, `yAxis_min=0` for rain.

6. **Proportional data scaling (2026-06-07):** Rolling-range chart groups use Belchertown's proportional `aggregate_interval` approach. The dashboard computes `aggregate_interval = base_interval × max(1, range / base_time)` and passes it to the API. The API groups archive records into `FLOOR(dateTime/N)*N` buckets with per-field SQL aggregation.

7. **Per-field aggregation (2026-06-07):** Each series in `charts.conf` may specify `aggregate_type` (e.g., `sumcumulative` for cumulative rain, `max` for rainRate). The dashboard passes these to the API via an `agg_map` query parameter. Fields without an explicit type default to `AVG` (Belchertown's rolling-range default). Supported types: `avg`, `max`, `min`, `sum`, `count`, `sumcumulative`. The `sumcumulative` type (added 2026-06-07) applies SUM per bucket then accumulates into a running total — replacing Belchertown's hardcoded `rainTotal` post-processing with an explicit config option.

8. **API archive conversion (2026-06-07):** The API now applies `transform_record()` to `/archive` responses, injecting `beaufort` and unit-converting all fields. Wind rose data uses a separate raw (unaggregated) archive fetch to preserve wind speed distribution for correct Beaufort classification.

9. **Special series types (2026-06-07):** Three series names trigger automatic rendering behavior — the dashboard switches chart component and data strategy when it encounters them in the config:

   | Series name | Rendering | Key automatic behaviors |
   |-------------|-----------|------------------------|
   | `windRose` | Custom SVG polar chart | 16 directions × 7 Beaufort speed bands. Raw (unaggregated) separate archive fetch for `windSpeed`+`windDir`. Default Beaufort colors, overridable via `beaufort0`–`beaufort6`. Always polar. |
   | `weatherRange` | Recharts arearange (default) or columnrange. Polar ONLY when `polar=true` explicitly set. | 15-band temperature color zones (°F and °C variants). Dual archive fetch `agg=min`+`agg=max`, `aggregate_interval=86400`. |
   | `haysChart` | Recharts arearange, always polar | Circular 24-hour wind chart (Mount Washington Observatory style). Queries `windSpeed`+`windGust` max. `yAxis_softMax` controls radial scale. |
   | `rainTotal` (series name) | Standard time-series | Migration tool auto-promotes to `aggregate_type = sumcumulative`. Queries `rain` column with `observation_type = rain`. |

   These behaviors are config-driven (series name in `charts.conf` triggers them) but not further operator-configurable at the component level — they match the Belchertown auto-behavior model exactly.

10. **API serves all archive columns (2026-06-07):** The `/archive` endpoint has no stock/non-stock column gate. Any column present in the weewx archive table is queryable by passing its database column name as `observation_type`. The former `STOCK_COLUMN_MAP` was a convenience mapping for canonical field names, not a whitelist. Unmapped columns use their database column name as the API field name (identity mapping). This enables operators to chart any weewx extension column (e.g., `aqi` from an AirVisual extension) without API changes. The `ColumnRegistry` (used for self-hide pruning) is populated from the actual database schema at startup, not from a hardcoded list.

11. **Deferred:** UI-based chart config editor. Operators edit the INI file directly for v0.1.

## Consequences

- **API:** new `services/charts_config.py` parser, `GET /api/v1/charts/config` endpoint, `GET /api/v1/charts/custom-query/{series_id}` endpoint, `ChartsSettings` in config, migration tool in `tools/migrate_charts.py`. New `aggregate_interval` and `agg_map` query parameters on `/archive` for proportional scaling with per-field aggregation. Daily aggregation fixed to use `wsum/sumtime` for avg (no `avg` column in weewx day tables). Hourly aggregation `FROM_UNIXTIME` `%` escaping fixed. The `sumcumulative` aggregate type applies SQL SUM then post-processes query results into a running total. `aggregate_interval` upper bound removed — accepts any value `≥60` seconds (was capped at 604800). All archive columns served: no STOCK_COLUMN_MAP whitelist gate on `/archive`; any column in the database is queryable by its column name.
- **API:** now applies `transform_record()` to `/archive` responses (in `units/response_conversion.py`), injecting `beaufort` and unit-converting all fields. Values flattened to full-precision scalars; `beaufort` kept as ConvertedValue dict for wind rose binning.
- **Dashboard:** `charts.tsx` rewritten from 1,144 to 206 lines. New `ConfigDrivenGroup`, `ConfigDrivenChart`, `WindRoseChart`, `WeatherRangeChart` components. Client-side `wind-rose-binning.ts` utility. Rendering defaults match Belchertown: markers off, Y-axis auto-scale, X-axis `minTickGap`, 10-color palette, `ensureChartContrast`, phantom right axis for uniform chart widths, sr-only tables wrapped in `div.sr-only`. Wind rose uses separate raw archive fetch. Proportional `aggregate_interval` and `agg_map` computed from chart config. `WeatherRangeChart` rewritten from circular polar SVG to Recharts arearange with 15-band temperature color zones (2026-06-07) — the initial implementation incorrectly rendered as a polar chart regardless of config; the correct default is Cartesian arearange (or columnrange). Monthly/yearly data flow fixed: `hasRangeChart` no longer blocks the main archive fetch; groups with both range and regular charts render all charts. Year/month dropdowns moved inside the Card. X-axis formatter uses the actual displayed date range. `time_length` string parsing added (`month`→2592000, `year`→31536000). `sr-only` floating text fixed for `WeatherRangeChart` and `HaysChart` tables. `agg_map` key aliasing fixed: FIELD_ALIASES applied to keys; `"None"` aggregate type filtered out.
- **Hardcoded `_BUILTIN_GROUPS` deleted** from `services/charts.py`. The only chart source is the config file (or built-in defaults when no file exists).
- **Operator familiarity preserved:** the config format is intentionally identical to Belchertown's `graphs.conf` — operators migrating from Belchertown can run the migration tool and get a working config immediately.
- **No chart-specific API endpoints** beyond `custom-query`. The API serves general-purpose data (`/archive` for time-series, `/archive/grouped` for categorical grouped aggregation); the config tells the dashboard what to fetch and how to render. Per ADR-010 and ADR-041 computation boundary amendment.

- **No climatology concept.** `xAxis_groupby` charts (Average Climate, monthly averages) use `GET /api/v1/archive/grouped` with a calendar `group_by` parameter. There is no separate `/climatology/*` endpoint family. The `xAxis_groupby` key in `charts.conf` triggers grouped-archive fetching; time-range selection then replaces what was previously a dedicated climatology endpoint.

- **`/archive/grouped` endpoint** (`GET /api/v1/archive/grouped`): General-purpose categorical aggregation grouped by calendar period.

  | Parameter | Type | Description |
  |-----------|------|-------------|
  | `group_by` | string | Grouping period: `month`, `day`, `hour`, or `year` |
  | `fields` | string | Comma-separated field specs: `field:agg_type` or `field:agg_type:avg_type` |
  | `from` | integer (optional) | Start epoch timestamp (Unix seconds) |
  | `to` | integer (optional) | End epoch timestamp (Unix seconds) |
  | `force_full_period` | boolean (optional) | When true, fills missing calendar slots with null |

  Response shape:
  ```json
  {
    "data": {
      "labels": ["Jan", "Feb", ...],
      "series": { "outTemp": [45.2, 48.1, ...], "rain": [1.2, null, ...] }
    },
    "generatedAt": "2026-06-07T12:00:00Z"
  }
  ```

  Per-field aggregation dispatch (resolved from the `field:agg_type[:avg_type]` spec):

  | Spec example | Meaning |
  |---|---|
  | `outTemp:avg:max` | Average of daily MAX values (Belchertown "avg_max") |
  | `outTemp:avg:min` | Average of daily MIN values (Belchertown "avg_min") |
  | `rain:avg:sum` | Average of period totals |
  | `outTemp:avg` | Straight average across all records in the period |
  | `rain:sum` | Direct SUM across all records |
  | `outTemp:max` | Direct MAX across all records |
  | `outTemp:min` | Direct MIN across all records |

- **`average_type` per-series config key:** Operators specify two-level aggregation in `charts.conf` via `average_type`. The dashboard encodes this as `field:aggregate_type:average_type` in the `fields` parameter sent to `/archive/grouped`. Example: `aggregate_type = avg` + `average_type = max` → `outTemp:avg:max` (average of daily highs).

## Acceptance criteria

- [x] `GET /api/v1/charts/config` returns the full pruned config tree
- [x] `GET /api/v1/charts/custom-query/{series_id}` executes pre-validated queries
- [x] Dashboard `/charts` page renders tabs dynamically from config
- [x] Wind rose renders with client-side binning from API `beaufort` field
- [x] Weather range chart renders with dual `agg` fetch
- [x] Self-hide pruning removes series/charts/groups for missing observations
- [x] Migration tool converts Belchertown `graphs.conf` → `charts.conf`
- [x] `tsc --noEmit` 0 errors, `ruff` + `mypy` clean
- [x] 28 API unit tests pass

## Implementation guidance

### Files created (API repo)

- `models/chart_config.py` — `SeriesConfig`, `ChartConfig`, `ChartGroupConfig`, `ChartsConfig` dataclasses
- `services/charts_config.py` — parser, pruning, config search path
- `endpoints/custom_query.py` — custom SQL endpoint
- `services/custom_query.py` — query execution with security controls
- `tools/migrate_charts.py` — CLI migration tool
- `data/charts.conf.default` — built-in fallback config
- `etc/charts.conf.example` — documented example config

### Files created (Dashboard repo)

- `src/components/charts/ConfigDrivenChart.tsx` — renders any chart type from config
- `src/components/charts/ConfigDrivenGroup.tsx` — group container with range selectors
- `src/components/charts/WindRoseChart.tsx` — custom SVG polar wind rose
- `src/components/charts/WeatherRangeChart.tsx` — Recharts arearange/columnrange temperature range with 15-band color zones (rewritten 2026-06-07 from circular polar SVG)
- `src/utils/wind-rose-binning.ts` — client-side direction × Beaufort binning

### Out of scope

- UI-based chart config editor (operators edit the INI file directly)
- Visual verification of rendered charts (requires interactive browser session)

## References

- Related: [ADR-010](ADR-010-canonical-data-model.md) (API is general-purpose data access), [ADR-024](ADR-024-page-taxonomy.md) (chart page taxonomy), [ADR-027](ADR-027-config-and-setup-wizard.md) (ConfigObj format), [ADR-041](ADR-041-realtime-bff.md) (computation boundaries), [ADR-042](ADR-042-unit-system.md) (unit conversion), [ADR-048](ADR-048-theme-color-tokens.md) (chart color tokens)
- Execution plan: [CONFIGURABLE-CHARTS-PLAN.md](../planning/briefs/CONFIGURABLE-CHARTS-PLAN.md)
