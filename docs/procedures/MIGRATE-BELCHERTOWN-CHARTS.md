# Migrating Belchertown graphs.conf to Clear Skies charts.conf

Step-by-step guide for converting an existing Belchertown chart configuration to the Clear Skies configurable charts system.

## Prerequisites

- Python 3.12+
- Clear Skies API installed (`pip install weewx-clearskies-api`) — the migration tool is bundled as a CLI entry point
- Access to your Belchertown `graphs.conf` file

## Steps

### 1. Copy graphs.conf from your weewx installation

The file is typically at `/etc/weewx/skins/Belchertown/graphs.conf` on your weewx host.

```bash
# From your weewx host:
cp /etc/weewx/skins/Belchertown/graphs.conf /tmp/graphs.conf

# Or via SSH:
scp weewx-host:/etc/weewx/skins/Belchertown/graphs.conf ./graphs.conf
```

### 2. Run the migration tool

```bash
clearskies-migrate-charts /path/to/graphs.conf -o /etc/weewx-clearskies/charts.conf
```

Options:
- `-o PATH` — write output to a file (defaults to stdout if omitted)
- `--dry-run` — parse and report issues without writing output
- `--verbose` — show detailed key-by-key mapping log

The tool prints a summary to stderr: `Migrated: 6 group(s), 29 chart(s), 72 series`.

### 3. Review the output

The migration tool adds comments to guide your review:

- **`# NOTE:`** — marks keys that required non-trivial translation or have different behavior in Clear Skies. Read these carefully.
- **`# UNSUPPORTED:`** — marks Belchertown-only features that the Clear Skies parser ignores (e.g., `[[[[states]]]]` Highcharts hooks). These are preserved as comments for reference but have no effect.

Open the generated `charts.conf` and review each `# NOTE:` comment. Most configurations work without changes.

### 4. Restart the API

```bash
sudo systemctl restart weewx-clearskies-api
```

The API parses `charts.conf` at startup. Check the logs for any warnings about invalid series or failed custom SQL validation:

```bash
journalctl -u weewx-clearskies-api --since "1 min ago" | grep -i "chart\|warn"
```

### 5. Verify on the /charts page

Navigate to your Clear Skies dashboard's `/charts` page. Verify:

- All expected chart groups appear as tabs
- Date range selectors work (1d/3d/7d/30d/90d for rolling groups)
- Year/month dropdowns work (for monthly/annual groups)
- Average Climate tab shows 12-month climatological data
- Wind rose renders (if configured)
- Custom SQL charts render (if configured)
- Both light and dark themes display correctly

## Key mapping table

Most INI keys are identical between Belchertown and Clear Skies by design. The migration tool preserves them as-is.

| Belchertown key | Clear Skies key | Notes |
|---|---|---|
| `aggregate_type` | `aggregate_type` | `None`, `avg`, `max`, `min`, `sum`, `count`, `sumcumulative`. The migration tool auto-promotes `rainTotal` series from `sum` to `sumcumulative` (cumulative running total). |
| `time_length` | `time_length` | Identical — seconds (e.g., `90000` = 25 hours) |
| `type` | `type` | Identical — `line`, `spline`, `area`, `column`, `bar`, `scatter` |
| `color` | `color` | Identical — hex string (e.g., `#ff0000`) |
| `yAxis` | `yAxis` | Identical — `0` (left) or `1` (right) |
| `yAxis_label` | `yAxis_label` | Identical |
| `yAxis_min` | `yAxis_min` | Identical |
| `yAxis_max` | `yAxis_max` | Identical |
| `yAxis_softMin` | `yAxis_softMin` | Identical |
| `yAxis_softMax` | `yAxis_softMax` | Identical |
| `yAxis_tickInterval` | `yAxis_tickInterval` | Identical (also accepts `yaxis_tickinterval` — case-insensitive) |
| `zIndex` | `zIndex` | Identical |
| `lineWidth` | `lineWidth` | Identical |
| `name` | `name` | Identical — display name for the series |
| `observation_type` | `observation_type` | Identical — weewx archive column name |
| `aggregate_interval` | `aggregate_interval` | Identical |
| `connectNulls` | `connectNulls` | Identical — `true`/`false` |
| `marker_enabled` | `marker_enabled` | Identical |
| `marker_radius` | `marker_radius` | Identical |
| `xAxis_groupby` | `xAxis_groupby` | Identical — `month` for climatological grouping |
| `average_type` | `average_type` | Identical — `max`, `min` for climatological averages |
| `show_button` | `show_button` | Identical — `true`/`false` |
| `buttonText` | `buttonText` | Identical — label text for date range buttons |
| `timespan_start` | `timespan_start` | Identical — Unix epoch for fixed-window start |
| `timespan_stop` | `timespan_stop` | Identical — Unix epoch for fixed-window end |
| `use_custom_sql` | `use_custom_sql` | Identical — `true`/`false` |
| `custom_sql_query` | `custom_sql_query` | Identical — raw SQL string |
| `windRose` | `windRose` | Identical — `true` to enable wind rose rendering |
| `windRoseColors` | `windRoseColors` | Identical — comma-separated hex colors for Beaufort bands |
| `page_content` | `page_content` | Identical — Markdown/HTML rendered above the chart group |
| `generate` | `generate` | **Ignored** — Belchertown report-cadence flag; no effect in Clear Skies. Annotated with `# NOTE:` by the migration tool. |
| `[[[[states]]]]` | — | **Ignored** — Belchertown-only Highcharts hooks. Annotated with `# UNSUPPORTED:` by the migration tool. |

## Known differences and limitations

1. **Rendering engine:** Belchertown uses Highcharts (server-rendered); Clear Skies uses Recharts (client-side React) for standard charts and custom SVG for wind rose and weather range charts. Visual appearance differs but data is equivalent.

2. **`generate` key:** Belchertown uses this to control which timespan groups (`day`, `week`, `month`, `year`) generate reports. Clear Skies ignores it — all configured groups are always served.

3. **`[[[[states]]]]` sections:** Belchertown allows Highcharts-specific per-state styling hooks. These have no equivalent in Recharts and are ignored.

4. **Wind rose rendering:** Belchertown renders the wind rose server-side via Highcharts. Clear Skies renders it client-side as a custom SVG, using the BFF-injected `beaufort` field for speed classification. The visual layout (16 directions × 7 Beaufort bands) is equivalent.

5. **Custom SQL queries:** Both systems support operator-defined SQL. Clear Skies adds startup validation (`EXPLAIN`), read-only transaction enforcement, a 10-second timeout, and a DDL keyword blocklist — security controls Belchertown did not have.

6. **Self-hide pruning:** Clear Skies automatically removes series, charts, and groups when the referenced `observation_type` is not in the database. Belchertown shows empty charts. This is usually desirable but means a chart group may not appear if none of its series match your database schema.

7. **UI-based editor:** Not available in v0.1. Operators edit `charts.conf` directly (same as editing `graphs.conf` in Belchertown).
