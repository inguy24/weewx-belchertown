# Charts System — Fixit List

**Source:** Operator visual review of deployed charts page (2026-06-06)
**Status:** ACTIVE — system-level fixes from 2026-06-07 session applied (see "What was already done" below). Per-chart rendering issues (F1–F13) remain open; operator is providing additional feedback.

**What was already done (2026-06-07):**

- **Per-field `aggregate_type` system complete.** Supported types: `avg`, `max`, `min`, `sum`, `count`, `sumcumulative`. The `sumcumulative` type applies SUM per time bucket then accumulates into a running total — used for cumulative rain totals (replaces Belchertown's hardcoded `rainTotal` post-processing). Migration tool auto-promotes `rainTotal` series from `sum` to `sumcumulative`.
- **API serves all archive columns.** Removed STOCK_COLUMN_MAP as a field validation gate on `/archive`. Any column in the weewx archive table (including operator-added extension columns like `aqi`) is directly queryable. Unmapped columns use their database column name as the field name (identity mapping). Fixes the Air Quality tab "unable to load chart data" error.
- **WeatherRangeChart rewritten.** Was incorrectly rendering as a circular polar SVG regardless of config. Now renders as a standard Recharts arearange chart with Belchertown's 15-band temperature color zones (blue cold → green mild → red hot). Per Belchertown wiki: default is Cartesian arearange (or columnrange when `area_display` not set); only goes polar when `polar = true` explicitly set.
- **`aggregate_interval` upper bound removed.** Was capped at 604800 (7 days); now accepts any value `≥60` seconds.
- **Monthly/yearly data flow fixed.** `hasRangeChart` no longer blocks the main archive fetch. Groups with both range and regular charts render all charts. Year/month dropdowns moved inside Card. X-axis formatter uses actual displayed date range. `time_length` string parsing added (`month`→2592000, `year`→31536000).
- **sr-only floating text fixed.** WeatherRangeChart and HaysChart sr-only data tables wrapped in `div.sr-only` — previously the text appeared as fixed-position floating artifacts on the page.
- **`agg_map` key aliasing fixed.** FIELD_ALIASES applied to `agg_map` keys; `"None"` aggregate type filtered from the map before sending to API.

---

## Issues

### F1 — No default color scheme; not theme-responsive
- **What's wrong:** Charts have no default color assignments per observation type. Colors must be assigned per series type AND must respond to light/dark theme changes (like the Almanac's MonthlyAveragesCard does — e.g., `isDark ? '#c084fc' : '#a855f7'` for dewpoint).
- **Expected:** Each observation type gets a consistent default color across all charts, and those colors adapt to the current theme.
- **Reference:** MonthlyAveragesCard.tsx uses theme-responsive colors. Belchertown's `belchertown.js.tmpl` has hardcoded default colors per series type.

### F2 — Date range buttons (1d/3d/7d/30d/90d) floating outside the card
- **What's wrong:** The 1d/3d/7d/30d/90d buttons float in empty space between the tab bar and the card. They are not visually connected to anything.
- **Expected:** Date range buttons must be inside the card, tied to the card layout (e.g., in the card header or directly below it).

### F3 — Y-axis does not auto-scale to data range
- **What's wrong:** Y-axis shows a fixed range (0–80) instead of scaling to the actual data range. Belchertown auto-scales the Y-axis tightly around the data (e.g., 55–75 for temperature).
- **Expected:** Y-axis domain should auto-scale to fit the data with a small padding margin. No hardcoded min/max unless the operator explicitly sets yAxisMin/yAxisMax in the config.
- **Reference:** Belchertown screenshot shows Y-axis from ~55 to ~75 for temperature data in the 60–73 range.

### F4 — X-axis does not auto-scale; ticks are overcrowded
- **What's wrong:** X-axis shows every single time label (9 PM, 10 PM, 10 PM, 1 AM, 1 AM, 2 AM...) — duplicated, overlapping, unreadable. Belchertown auto-scales X-axis ticks to fit the width (e.g., "3 Jun", "04:00", "08:00", "12:00", "16:00", "20:00").
- **Expected:** X-axis ticks must auto-scale to the date range: show reasonable intervals (every few hours for 24h, every day for 7d, etc.), no duplicates, no overlap. Recharts `interval="preserveStartEnd"` or calculated tick intervals.
- **Reference:** Belchertown screenshot shows clean 4-hour tick intervals for a 24h chart.

### F5 — Data point markers shown on every point; lines invisible
- **What's wrong:** Every single data point has a circle marker rendered, making the lines completely invisible under a wall of dots. With 5-minute archive data over 24 hours, that's ~288 markers per series — unusable.
- **Expected:** No markers by default on time-series line charts. Belchertown does NOT show individual markers for line/spline charts — it's a smooth line only. Markers should only appear on hover (activeDot) or when explicitly configured (e.g., scatter charts for lightning/windDir).
- **Reference:** Belchertown temperature chart shows clean lines with NO markers. Our chart is a wall of overlapping dots.

### F6 — Chart exceeds its container width
- **What's wrong:** The chart visually overflows its card/container horizontally.
- **Expected:** Chart must fit within its card. ResponsiveContainer should constrain it. May be related to the X-axis tick overflow.

### F7 — Wind chart: markers on windSpeed/windGust lines make it unreadable (same root cause as F5)
- **What's wrong:** Wind Speed and Wind Gust have circle markers on every data point. Lines are buried under dots.
- **Expected:** Wind Speed and Wind Gust should be clean lines with NO markers (like Belchertown). Wind Direction IS correct as scatter dots — that's the intended rendering for windDir.
- **Reference:** Belchertown wind chart: windSpeed = solid orange line (no markers), windGust = solid green line (no markers), windDir = small blue scatter dots (no connecting line).

### F8 — Wind Direction scatter dots: wrong color, not theme-responsive
- **What's wrong:** windDir dots are white/light gray — they blend into the background in dark mode and would be invisible in light mode. Belchertown uses a distinct blue for windDir.
- **Expected:** windDir scatter dots need a distinct, theme-responsive color that contrasts against both light and dark backgrounds. Belchertown uses a sky blue (#5B9BD5 or similar).

### F9 — Wind Rose not rendering data; no chart title
- **What's wrong:** The wind rose shows an empty polar chart — concentric circles and compass labels but NO data wedges. Belchertown shows colored wedges radiating from center in the dominant wind direction(s) with Beaufort speed color coding. Also missing the chart title ("Wind Rose").
- **Expected:** Colored wedges per compass direction, stacked by Beaufort speed category (same colors as Belchertown: blue < 1mph, cyan 1-3, green 4-7, orange 8-12, dark orange 13-18, red 19-24, purple 25+). 16-point compass labels. "Frequency (%)" radial axis label. Chart title "Wind Rose" above the chart.
- **Reference:** Belchertown wind rose shows clear colored wedges pointing W/WNW with stacked Beaufort categories. Our chart shows 0.0% Calm and empty rings — data is either not being fetched, not being binned, or not being rendered.

### F10 — "Wind Rose Data - percentage..." text fixed on page, doesn't scroll
- **What's wrong:** There is a line of text related to wind rose data (something like "Wind Rose Data - percentage...") that is position-fixed on the page and does not scroll with the rest of the content. It stays stuck in place as the user scrolls. This is a rendering artifact/bug that needs to be removed entirely.
- **Expected:** No fixed-position text artifacts. Whatever is generating this text needs to be found and removed.

### F11 — Rain chart: markers on every data point (same root cause as F5)
- **What's wrong:** Rain Rate and Rain Total lines have markers on every data point, making the lines hard to read. Same default marker issue as F5/F7.
- **Expected:** Clean lines, no markers. This is the same root cause — the renderer defaults to showing markers on all line series. Belchertown defaults to no markers on line/spline/area charts.

### F12 — Barometer chart completely broken: Y-axis, X-axis, markers, overflow
- **What's wrong:** Multiple compounding issues:
  1. **Y-axis not auto-scaling** — shows 0.00 at the bottom, data is at ~29.9–30.05 so the line is pinned to the very top of the chart as a flat band. Belchertown auto-scales the Y-axis to 29.900–30.050 range.
  2. **Markers on every point** (same root cause as F5) — wall of dots on a line that should be a clean spline.
  3. **X-axis overcrowded** (same root cause as F4) — duplicate/overlapping time labels.
  4. **Chart overflows container** (same root cause as F6) — runs off the page horizontally.
- **Expected:** Belchertown barometer chart: Y-axis tightly scaled to data range (29.900–30.050), clean spline line with no markers, fine Y-axis tick intervals (0.025 inHg), auto-scaled X-axis ticks.
- **Root causes:** F3 (Y-axis auto-scale), F4 (X-axis auto-scale), F5 (default markers), F6 (container overflow). Barometer is the worst-case example because the tight data range (0.15 inHg span) against a 0–30 default Y-axis makes the line look completely flat.

### F13 — Solar Radiation and UV: markers on every point (same root cause as F5)
- **What's wrong:** Solar Radiation, Theoretical Max Solar Radiation, and UV Index all have markers on every data point. Otherwise the chart structure is OK — dual axes, area fill on maxSolarRad, correct general shape.
- **Expected:** Clean lines/areas with no markers. Same fix as F5.
- **Note:** Colors are not ideal (blue/green/orange vs Belchertown's orange/yellow/green) but those may be a graphs.conf configuration issue, not a renderer default issue. Need to check whether Belchertown hardcodes default colors for these series in belchertown.js.tmpl or if they come from graphs.conf.

---

*Waiting for more operator feedback before acting.*
