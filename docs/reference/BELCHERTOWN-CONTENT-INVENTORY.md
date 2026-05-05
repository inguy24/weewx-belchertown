# Belchertown Content Inventory — weather.shaneburkhardt.com

Captured: 2026-05-01. Source: live crawl (https://weather.shaneburkhardt.com) supplemented by reading the live skin templates at `c:\CODE\weather-belchertown\docs\snapshots\server-skin-2026-04-29\Belchertown\` (sha256-verified against the running weewx container as of 2026-04-29) and the current local fork's `skins/Belchertown/graphs.conf` (which adds the `airquality` graphgroup that's live but post-dates the snapshot).

This is a **must-retain** checklist for the Clear Skies redesign. Every numeric field, every chart series, every selector, every external feed listed below is currently visible to a visitor. Anything dropped is a regression unless the user explicitly waives it.

The user has emphasized that Belchertown's strength is the *amount of data* on screen — the redesign cannot be a "modernized but dumbed-down" weather page. This file is the data-density floor.

---

## Pages

The site has **6 top-level pages** plus 1 footer-linked legal page plus 2 special-purpose pages (kiosk + pi) that are not in the public nav but exist on disk.

### Home (`/`)

Top-to-bottom layout (driven by `index.html.tmpl`):

#### Row 0 — Station info bar (`.wx-stn-info-container`)

- `<h1>` station heading: **"GW2292 Huntington Beach Weather Conditions"** (configurable via `home_page_header` label)
- "Powered by" subtitle slot (configurable via `powered_by` label; currently empty)
- **Live-update marker**: three states displayed as colored dots — `loadingMarker`, `onlineMarker`, `offlineMarker` (driven by MQTT websocket connection status)
- **Last Updated** timestamp (moment.js, format `LL, LTS`, e.g. "May 1, 2026, 5:48:32 PM"). Updates live as MQTT loop packets arrive.
- **Social share** slot (`$social_html` — Twitter/Facebook share buttons, gated by `twitter_enabled` / `facebook_enabled`; currently disabled)
- **Stale-data alert banner** (`.last-updated-alert`) — appears only if MQTT is disabled AND the report timestamp is older than `last_updated_alert_threshold` seconds. Red triangle icon + warning text.
- **Forecast alert banner** (`.wx-stn-alert`) — appears when Aeris/forecast provider returns an active NWS alert; gated by `forecast_alert_enabled`. Currently `0` in default skin.conf but server config differs.

#### Row 1 — Three-column "current conditions" block

##### Col 1 (left) — Temperature + wind block (`.col-lg-4`)

**Temperature panel:**
- Forecast weather icon (current_obs_icon, PNG from `images/`, e.g. `clear-night.png`) — only if `forecast_enabled = 1`
- Large current outdoor temperature (`$current.outTemp.formatted`) with unit superscript (`$unit.label.outTemp` → `°F`). MQTT-live.
- Current observation summary text (`$current_obs_summary`) — e.g. "Clear" — derived from Aeris weather code lookup
- AQI block (gated by `aqi_enabled`):
  - "AQI:" label + current AQI number (`$aqi`)
  - Category in parens (`$aqi_category`) — e.g. "moderate"
  - Optional location/pollutant subtext (`$aqi_location`) — currently shows the dominant pollutant (e.g. "PM2.5"), gated by `aqi_location_enabled`
- "Feels like" line (`$current.appTemp`)
- High/Low table for today:
  - "High" with `$day.outTemp.max`
  - "Low" with `$day.outTemp.min`

**Wind panel** (under temperature panel, separated by `.obs-wind-divider`):
- Compass dial graphic (`.compass`) — animated arrow that rotates to current `$current.windDir`
  - Shows ordinal compass label inside dial (N, NNE, NE, …, NNW; "--" when N/A)
  - Shows numeric degree value below ordinal
  - Arrow direction tweens via `rotateThis()` JS function on every MQTT update
- Wind table to the right of compass:
  - "Speed" column header / `$current.windSpeed` value / unit label `$unit.label.windSpeed` (mph)
  - "Gust" column header / `$current.windGust` value / same unit
  - **Beaufort scale label** row (e.g. "light breeze") — gated by `beaufort_category`; computed client-side from windSpeed in knots → Beaufort number → label string. Values: calm, light air, light breeze, gentle breeze, moderate breeze, fresh breeze, strong breeze, near gale, gale, strong gale, storm, violent storm, hurricane force.
- **Wind hook slot** (`index_hook_after_wind_table.inc`) — operator-customizable injection point; not present on live site

##### Col 2 (middle) — Station observations + Sun & Moon (`.col-lg-3`)

**Station observations table** (`$station_obs_html`, configured via `station_observations` extra). Default config = `barometer, dewpoint, outHumidity, rainWithRainRate`. Each row is `Label : value unit`. The full set of observations the operator can pick from (see `belchertown.js.tmpl` and `Labels.Generic`):
- Barometer (`$current.barometer`, inHg) **+ trend arrow / 3-hour delta** (`$trend.barometer`) — Belchertown special
- Dew Point (`$current.dewpoint`, °F)
- Outside Humidity (`$current.outHumidity`, %)
- Rain (combined "rainWithRainRate" — daily rain `$day.rain.sum` + current rain rate `$current.rainRate` in one row, e.g. "0.00 in / 0.00 in/hr")
- Heat Index (`$current.heatindex`, °F)
- Wind Chill (`$current.windchill`, °F)
- Solar Radiation (`$current.radiation`, W/m²)
- UV Index (`$current.UV`, dimensionless 0–14)
- Apparent Temperature / Feels Like (`$current.appTemp`)
- Cloud Base (`$current.cloudbase`, ft)
- Visibility (`$current.visibility`, mi)
- Wind Run (`$current.windrun`, mi)
- Cloud Cover (`$current.cloud_cover`, %)
- Inside Temp (`$current.inTemp`, °F)
- Inside Humidity (`$current.inHumidity`, %)
- ET (evapotranspiration), extraTemp1 — exposed in JSON, available if installed

**Live site row order observed** (per WebFetch of `/`): Barometer, Dew Point, Outside Humidity, Rain, Heat Index, Wind Chill, Radiation, UV Index. Rain is the combined rainWithRainRate row.

**Station observations hook** (`index_hook_after_station_observations.inc`) — operator-customizable injection point.

**Sun & Moon mini-block** (under station observations):
- "Sun & Moon" section title
- Two-column row:
  - Left (`.col-sm-5 sun`): sunrise icon + time, sunset icon + time (live computed from almanac)
  - Right (`.col-sm-7 moon`):
    - Moon icon (CSS-rendered moon phase visualization)
    - Moon phase title (e.g. "Full Moon", "Waning Crescent" — from `$almanac.moon_phase`)
    - Moon fullness percent (e.g. "100% visible") — from `$almanac.moon_fullness`
- "More Almanac Information" link (gated by `almanac_extras` and `$almanac.hasExtras`) — opens **Almanac Modal** (Bootstrap modal `#almanac`)

**Almanac Modal** content (`celestial.inc`, two-column table):
- **Sun column:**
  - Start civil twilight (time)
  - Rise (time)
  - Transit (time)
  - Set (time)
  - End Civil Twilight (time)
  - Azimuth (degrees, e.g. "183.5°")
  - Altitude (degrees)
  - Right ascension (degrees)
  - Declination (degrees)
  - Equinox (next equinox date) — order swaps with solstice based on which comes first
  - Solstice (next solstice date)
  - Total daylight (e.g. "12 hours, 34 minutes, 56 seconds") + delta vs yesterday (e.g. "1 minute, 30 seconds more than yesterday" / "less than yesterday")
- **Moon column:**
  - Rise (time)
  - Transit (time)
  - Set (time)
  - Azimuth (degrees)
  - Altitude (degrees)
  - Right ascension (degrees)
  - Declination (degrees)
  - Full moon (next full moon datetime) — order swaps with new moon based on which comes first
  - New moon (next new moon datetime)
  - Phase: human-readable phase name + "X% full"

If pyephem isn't installed, the modal shows "Install pyephem for detailed celestial timings" instead.

##### Col 3 (right) — Radar / Webcam tabs (`.col-lg-5 radar-map`)

Server has `index_radar.inc` with **3 tabs** (currently active tab = Webcam):

- **Radar tab** — embeds `$radar_html` (a Windy.com embed iframe per the credits panel; configurable via `radar_html` extra)
- **Webcam tab** — `<img src="webcam/weather_cam.jpg">`, link wraps to full-size image; auto-refreshes every 60s via JS (`reloadWebcam()`)
- **Webcam Timelapse tab** — `<video>` element loading `/webcam/weewx_timelapse.mp4`; reloads every 15 minutes via `reloadTimelapse()`

CSS hack at bottom of `index_radar.inc` forces `.toprow-height { min-height: 402px }` to align the radar pane with the temperature/almanac columns.

#### Row 1.5 — `index_hook_after_station_info.inc` (operator slot, not present on live site)

#### Row 2 — Forecast row (`.row.forecastrow`)

Gated by `forecast_enabled = 1`.

- Forecast title text (`$obs.label.forecast_header` = "Forecast") + subtitle (forecast last-updated time, moment.js, format `LLL`)
- **Interval selector buttons** (right side): "Forecast Interval (hours):" label + three clickable buttons: **1**, **3**, **24**
- Three forecast container divs, only one visible at a time:
  - `.1hr_forecasts` — JS-populated 1-hour outlook (16 entries fetched from Aeris)
  - `.3hr_forecasts` — 3-hour outlook (8 entries)
  - `.24hr_forecasts` — daily outlook (7 days)
- Each forecast card contains: weather icon, day-of-week or hour label, condition text, high/low temp, precipitation chance, wind, optionally humidity/dewpoint (gated by `forecast_show_humidity_dewpoint`)
- Optional "Daily Forecast" link to deeper forecast page (gated by `forecast_show_daily_forecast_link`)

#### Row 2.5 — `index_hook_after_forecast.inc` (operator slot, not present on live site)

#### Row 3 — Weather snapshots + Earthquake (`.row.eq-stats-row`)

Two-section layout (snapshot block takes col-9 if earthquake is enabled, col-12 otherwise).

##### Weather snapshots block (`.stn-quick-stats`)

Header text: "Weather Record Snapshots." + link "View all weather records here." → `/records/`.

Two side-by-side stat tables:

- **Today block** (`.snapshot-records-today-header` is JS-populated with today's date, e.g. "Friday, May 1, 2026"):
  - High `$day.outTemp.max` | Low `$day.outTemp.min`
  - Average Wind `$day.wind.avg` | Highest Wind `$day.wind.max`
  - Today's Rain `$day.rain.sum` | Highest Rate `$day.rainRate.max`
- **Month block** (`.snapshot-records-month-header` is JS-populated with current month/year, e.g. "May 2026"):
  - High `$month.outTemp.max` | Low `$month.outTemp.min`
  - Average Wind `$month.wind.avg` | Highest Wind `$month.wind.max`
  - Total Rain `$month.rain.sum` | Highest Rate `$month.rainRate.max`

(Note: skin.conf labels also define `snapshot_today_high_uv` / `snapshot_month_high_uv`. Server template doesn't currently include these rows but the labels exist if someone re-adds them.)

##### Earthquake block (right col-3) — gated by `earthquake_enabled = 1`

- Title: "Recent Local Earthquake"
- Earthquake datetime (moment.js, format `LLL`)
- Map-marker icon + clickable place name (`$earthquake_place`, e.g. "21.8 miles ENE of Ensenada, B.C., MX") — links to `$earthquake_url` (USGS event page)
- Earthquake row split in two:
  - Left: earthquake icon + "Magnitude" label + `$earthquake_magnitude`
  - Right: `$earthquake_distance_away $earthquake_distance_label $earthquake_bearing` (e.g. "151.01 miles SE")

#### Row 3.5 — `index_hook_after_snapshot.inc` (operator slot, not present on live site)

#### Row 4 — Homepage charts (`.highcharts-row`)

Gated by `highcharts_enabled = 1`. Renders the **homepage graphgroup** (configured via `highcharts_homepage_graphgroup`, set to `"homepage"`).

- Section title: chart group title from graphs.conf — `"Last 24 Hours/Week/Month"`
- Inline link "View more here." → `/graphs/`
- Charts rendered in 2-column grid (`.col-sm-6` per chart):
  - **chart1 — Temperature**: line chart, series outTemp (zIndex 1, "Temperature"), windchill, heatindex (#f7a35c), dewpoint (purple). connectNulls.
  - **chart2 — Wind Speed and Direction**: yAxis_min=0; series windDir (zIndex 1, secondary y-axis 0–360, lineWidth 0, marker only); windGust; windSpeed (zIndex 2). connectNulls on speed/gust.
  - **roseplt — Wind Rose**: radial windRose chart with 7 Beaufort color bands (#1278c8, #1fafdd, #71bc3c, #ffae00, #ff7f00, #ff4500, #9f00c5)
  - **chart3 — Rain**: rainRate on secondary axis (#28a745, aggregate max), rainTotal "Rain Total" (#007bff, aggregate sum)
  - **chart4 — Barometer**: spline, single series barometer (#BECC00, yAxis tick interval 0.01)
  - **solarRadGraph — Solar Radiation and UV Index**: radiation (#ffc83f, "Solar Radiation"), maxSolarRad as area shading (#f7f2b4, "Theoretical Max Solar Radiation"), UV on secondary axis (#90ed7d, 0–14, "UV Index")
  - **homeLightningInfo — Lightning**: lightning_strike_count column (orange, "Number of Strikes", aggregate sum) + lightning_distance scatter (blue, "Distance (miles)", aggregate avg)

**Time-range selector dropdown** is rendered above the charts (per `enable_date_ranges = true` and `rolling_ranges = 1d, 3d, 7d, 30d, 90d` in graphs.conf). Default `time_length = 86400` (24 hours).

#### Row 4.5 — `index_hook_after_charts.inc` (operator slot, not present on live site)

---

### Graphs (`/graphs/`)

`graphs/index.html.tmpl` driven by Highcharts JSON files generated by `user.belchertown.HighchartsJsonGenerator`.

#### Page header

- Standard page-header bar with mini current conditions (icon + outTemp) + page title `"Weather Observation Graphs"`

#### Button row (`.wx-buttons`)

URL-driven (`?graph=<name>`). Buttons defined by `show_button = true` in each graphgroup section of `graphs.conf`:

1. **All** — special button (gated by `graph_page_show_all_button = 1`); renders every graphgroup stacked vertically with section titles
2. **Average Climate** — `[averageclimate]` graphgroup
3. **Last 24 Hours/Week/Month** — `[homepage]` (same charts as homepage Row 4)
4. **Monthly** — `[monthly]`
5. **Yearly** — `[ANNUAL]`
6. **TS Hilary 2023** — `[Tropical_Storm_Hilary]`
7. **Air Quality** — `[airquality]` (added post-2026-04-29 snapshot, present in current local repo + live site)

#### Per-group chart inventories

**`[averageclimate]` — "Average Climate by Month"** (`time_length = all`, daily aggregate, x-axis grouped by month with categorical Jan–Dec):
- **avgclimatetotal — "Average Climatological Values by Month"** (spline):
  - outTemp avg-of-max ("Average High Temperature", red, primary axis)
  - outTemp avg-of-min ("Average Low Temperature", primary axis)
  - dewpoint avg ("Average Dewpoint", purple)
  - custom_average_rains ("Average Monthly Rain Total", column on secondary axis, #268bd2) — uses **custom SQL query** `SELECT month, AVG(rain_total) FROM archive_month_raintotal GROUP BY month`

**`[homepage]` — "Last 24 Hours/Week/Month"** (default `time_length = 86400`, range selector 1d/3d/7d/30d/90d, gapsize 300s, aggregate_interval 500s):
- chart1 Temperature (outTemp, windchill, heatindex, dewpoint)
- chart2 Wind Speed and Direction (windDir, windGust, windSpeed)
- roseplt Wind Rose (windRose, 7-Beaufort color bands)
- chart3 Rain (rainRate, rainTotal)
- chart4 Barometer (spline)
- solarRadGraph Solar Radiation and UV Index (radiation, maxSolarRad area, UV)
- homeLightningInfo Lightning (lightning_strike_count column, lightning_distance scatter)

**`[monthly]` — "Monthly Observations"** (spline, daily aggregate, max default; year selector for 2025/2024/2023/2022; month-breakdown enabled):
- radialChartName — **"Temperature Ranges for Month"** — radial weatherRange chart (Highcharts windbarb-style polar plot, range_type=outTemp, area_display)
- chart2 Wind Speed and Direction (windDir avg, windGust, windSpeed)
- roseplt Wind Rose
- chart3 Rain (rainRate, rainTotal sum)
- chart4 Barometer (avg)
- weekLightningInfo Lightning (count column + distance scatter)

**`[ANNUAL]` — "Annual Observations"** (`force_full_year = true`, year selector 2025/2024/2023/2022, daily aggregate):
- avgclimate2025 — **"Annual Average Climatological Values"** (spline, monthly aggregate Jan–Dec):
  - outTemp avg-of-max (red, "Average High Temperature")
  - outTemp avg-of-min ("Average Low Temperature")
  - dewpoint avg (purple, "Average Dewpoint")
  - rainTotal sum (#268bd2, "Rain Total", column on secondary axis)
- radialChartName "Temperature Ranges for Year" (weatherRange radial)
- chart2 Wind Speed and Direction
- roseplt Wind Rose
- chart3 Rain (rainRate, rainTotal sum)
- chart4 Barometer (avg)
- weekLightningInfo Lightning

**`[Tropical_Storm_Hilary]` — "Tropical Storm Hilary August 2023"** (timespan-specific, Aug 19–22 2023, generates daily). Includes **page_content HTML block** with explanatory paragraph + Wikipedia link about Hurricane Hilary.
- chart1 Temperature (outTemp/windchill/heatindex/dewpoint)
- chart2 Wind Speed and Direction
- roseplt Wind Rose
- chart3 Rain (rainRate, rainTotal)
- chart4 Barometer (spline)
- solarRadGraph Solar Radiation and UV Index
- dayLightningInfo Lightning

**`[airquality]` — "Air Quality Index"** (added in Phase 3 of AQI-CENTRALIZATION, post-snapshot):
- chart1 — **"AQI - 24 Hours"** (`time_length = 86400`): single series `aqi` ("AQI", #7cb5ec)
- chart2 — **"AQI - 7 Days"** (`time_length = 604800`): same series, 7-day window

#### Chart interactivity (Highcharts Stock 10 features)

- **Time-range navigator** at bottom of each chart with draggable selector (Highcharts Stock built-in)
- **Range selector buttons** above each chart for `[homepage]` group (1d, 3d, 7d, 30d, 90d) — driven by `rolling_ranges`
- **Year/month dropdown selectors** for `[monthly]` and `[ANNUAL]` (`available_years = 2025, 2024, 2023, 2022`, `enable_monthly_breakdown`)
- **Tooltip** on hover (format `"LLL"` for short ranges, `"dddd LL"` for monthly/annual)
- **Series legend** at bottom — clickable to toggle visibility
- **Export menu** (PNG, JPEG, PDF, SVG, CSV, XLS, "View data table") — Highcharts Exporting module loaded
- **Page-content HTML block** above charts (used by Hilary group for narrative; available to any group)

---

### Marine Forecast (`/marine/`)

`marine.inc`. Surf + tide widgets. **No native weewx data here.**

- Page header with mini current conditions
- **Surf Forecast Widget** — iframe embed from `surf-forecast.com/breaks/Huntington-Pier/forecasts/widget/i` (their stylesheet `widget.css` is loaded too). Footer image with link "View detailed surf forecast for Huntington Pier."
- **TidesPro embeds** (3 separate `<script>` includes):
  1. **Tide Table** — script ID `f7e60c1488…/tidetable/us/california/newport-beach-newport-bay-entrance-corona-del-mar`
  2. **Tide Chart** — script ID `71adcf5a8f…/tidechart/...`
  3. **Solunar Table Week** — script ID `1843beb008…/tidesolunartableweek/...` (renders weekly solunar/sunrise/sunset/major-minor activity periods)

The TidesPro scripts inject HTML at runtime; WebFetch of the live page misses them because they're JS-rendered. Their content typically includes: today's high/low tide times and heights, multi-day tide chart graphic, fishing/hunting solunar predictions per day.

(There is no template for AI to "verify what tide data is shown" on a static fetch — it's external.)

---

### Records (`/records/`)

`records/index.html.tmpl`. Single large striped table grouped into sections; each row shows **(Year-to-date | All-time)** pair with associated timestamp.

#### Sections and rows

**Temperature Records:**
- Highest Temperature
- Lowest Temperature
- Highest Apparent Temperature (only if data has appTemp)
- Lowest Apparent Temperature (only if data has appTemp)
- Highest Heat Index
- Lowest Wind Chill
- Largest Daily Temperature Range — shows the date + "(Min: X °F - Max: Y °F)"
- Smallest Daily Temperature Range — same format

**Wind Records:**
- Strongest Wind Gust (with timestamp)
- Highest Daily Wind Run (only if windrun data exists)

**Rain Records:**
- Highest Daily Rainfall (with date)
- Highest Daily Rain Rate (with timestamp)
- Month with Highest Total Rainfall (shows month name)
- Total Rainfall for `<Year>` (shows YTD total + all-time year-with-highest-total)
- Consecutive Days With Rain (count + ending date / range)
- Consecutive Days Without Rain (count + ending date / range)

**Humidity Records:**
- Highest Humidity (with timestamp)
- Lowest Humidity
- Highest Dewpoint
- Lowest Dewpoint

**Barometer Records:**
- Highest Barometer
- Lowest Barometer

**Sun Records** (only if radiation/UV data exists):
- Highest Solar Radiation
- Highest UV

**Inside Temp Records** (`records-table.inc.example` — only included if a `records-table.inc` exists; not present in current snapshot):
- Highest inside Temp
- Lowest inside Temp

Records-page custom intro slot: `records.inc` (operator-customizable; not present in current snapshot).

Column headings: current year (e.g. "2026") | "All Time".

---

### Reports (`/reports/`)

`reports/index.html.tmpl`. NOAA-format text reports.

- Page heading "NOAA Reports"
- Year/month selector grid (`$noaa_header_html`) — generated by weewx ReportEngine. One row per available year (2022–2026 on live site), each row contains 12 month buttons (Jan–Dec). Clicking links to `?yr=YYYY&mo=MM`.
- Direct link: "Click here to view this report directly or click on a month or year to change the NOAA report." — opens the raw `.txt` file
- `<pre>` block (`#noaa_contents`) loaded by AJAX from `/NOAA/NOAA-YYYY.txt` or `/NOAA/NOAA-YYYY-MM.txt`. The NOAA report is the standard fixed-width weewx NOAA template containing:
  - Monthly summary: high temp + date, low temp + date, avg temp, heating degree days, cooling degree days
  - Day-by-day table: max/min/avg temp, heat/cool deg-days, rain, avg wind speed, hi wind + dir + time, dom wind dir
  - Year reports: monthly summaries
- Page heading also displays current observation icon + temperature in left

---

### About (`/about/`)

`about.inc`. Standard about page.

#### Left column (`.col-sm-4`):
- Live webcam image (`/webcam/weather_cam.jpg`)
- Static weather station photo (`/images/weather_station.jpg`)
- Hardware/location table:
  - Hardware: **Ambient Weather WS-5000-IP**
  - Camera: **Amcrest Outdoor**
  - Location: Lat 33.6568N Long -117.9826W
  - Altitude: 40 feet

#### Right column (`.col-sm-8`):
- Intro paragraph explaining real-time updates (~5s) + station identity (Atlanta Ave between Newland St and Beach Blvd, Huntington Beach, CA) + tech stack (weewx + Apache + EMQX websockets)
- **Sensors list** (12 readings from the Ambient WS-5000):
  - Temperature
  - Humidity
  - Dew Point
  - Wind speed
  - Wind direction
  - Wind Gust
  - Precipitation amount
  - Precipitation rate
  - UV radiation
  - Solar radiation (irradiance)
  - Barometric pressure
  - Lightning count
  - Lightning distance
- Note about software-derived observations + QC mention
- **"Posted to" external aggregator list** (4 sites):
  - KCAHUNTI278 on Weather Underground
  - GW2292 on Ambient Weather
  - Vaisala XWeather
  - GW2292 on NWS NOAA/CWOP Program
- NOAA/CWOP Logo image + paragraph about CWOP participation (7,000 stations, 800 organizations using the data)
- **Credits list** (5 external data sources used by the site):
  - Forecast data — Vaisala XWeather (link)
  - Earthquake data — USGS.gov Earthquake Catalog (link)
  - Radar — Windy.com (link)
  - Surf forecast — Surf-Forecast.com (link)
  - Tide forecast — TidesPro (link)

About-page also renders any Highcharts via `showChart("about")` script call (currently no `[about]` graphgroup defined).

---

### Legal Disclaimer (`/legal/`) — footer-linked, not in top nav

`legal.inc`.

- "Weather Data Disclaimer" header
- "Please Read Carefully" sub-header
- Five labeled bullets:
  - Data Accuracy (PWS limitations, sensor errors, transmission issues)
  - Not for Critical Decisions ("informational and entertainment purposes only")
  - Official Sources (defer to NWS for warnings)
  - No Guarantees
  - Limitation of Liability
- Use at Your Own Risk paragraph
- "By continuing to use this website, you acknowledge..."
- **Privacy Policy for weather.shaneburkhardt.com** — Effective Date May 23 2025
  - Information We Collect (Google Analytics network activity + IP + essential cookies)
  - How We Use Your Information (4 bullets)
  - How We Share Your Information (only Google Analytics)
  - California Privacy Rights — Right to Know / Delete / Correct / Opt-Out / Non-Discrimination
  - How to Exercise Your Rights (email weather@shaneburkhardt.com)
  - Changes to This Privacy Policy
  - Contact Us

---

### Kiosk (`/kiosk.html`) — not in top nav, present on disk

`kiosk.html.tmpl`. Single-screen full-page wall-display variant (intended for a Pi or a TV). Uses `radar_html_kiosk`, `radar_width_kiosk`, `radar_height_kiosk` and a kiosk-specific MQTT host. AQI gated separately by `aqi_enabled_kiosk`. Loads `kiosk.css` instead of (or in addition to) the regular site stylesheet. Does not load Highcharts. Logic mirrors home page minus charts.

### Pi (`/pi/`) — not in top nav, present on disk

`pi/index.html.tmpl`. A Raspberry Pi-targeted layout variant using `pi_kiosk_bold` and `pi_theme` settings. Bold-font readable variant for in-house display.

---

## Cross-page features

- **Top navigation menu** (in `header.html.tmpl` `<ul id="menu-menu">`):
  - Home
  - Graphs (gated by `highcharts_enabled = 1`)
  - Marine Forecast
  - Records
  - Reports
  - About
  - **Theme switch** (light/dark slider) — gated by `theme_toggle_enabled = 1`. Persists to `sessionStorage`.
- **Logo image** in header — supports both `logo_image` (light) and `logo_image_dark` (auto-swaps in dark mode). Falls back to `site_title` text.
- **Auto theme** — if `theme = auto`, header.html.tmpl computes whether current hour is between sunrise and sunset and selects light or dark accordingly. Otherwise honors `theme = light` / `theme = dark`.
- **Back-to-top button** — gated by `back_to_top_button_enabled`; configurable position (left/right) and opacity.
- **Footer** (`footer.html.tmpl`):
  - Left: Copyright © `<year> Shane Burkhardt`
  - Center: "Legal Disclaimer" link → `/legal/`
  - Right: "weewx theme by Pat O'Brien" → github.com/poblabs/weewx-belchertown
  - Belchertown skin version comment (HTML comment, e.g. `<!-- Belchertown Skin Version: 1.x -->`)
  - Page-generated timestamp comment
- **PWA manifest** — `manifest.json.tmpl` defines `manifest_name` ("My Weather Website" default) and `manifest_short_name`. Apple-touch-icons declared at 48/72/96/144/168/192 px.
- **Page-header injection slot** — `header.inc` (loaded by header.html.tmpl if present, except on kiosk page)
- **Custom CSS slot** — `custom.css` loaded if `custom_css_exists` is true
- **Google Analytics** — gated by `googleAnalyticsId` (currently disabled in default skin.conf, but Privacy Policy references it as live)
- **Schema.org structured data** — every page is marked up as `WebPage` with `CreativeWork` article element

### Live data path (MQTT websockets — applies to home + kiosk + pi)

- Subscribes to MQTT broker over WSS at `wss://weather.shaneburkhardt.com:443/mqtt`, topic `weewx/loop`
- On each loop packet (every ~5s) updates: outTemp, outHumidity, dewpoint, barometer, barometer_trend, windSpeed, windDir, windGust, rainRate, rain, UV, radiation, plus any custom observations
- "Connected. Data received" / "Connected. Waiting for data." / "Live updates have stopped." / "Connecting..." / "Failed connecting..." / "Lost connection..." status states
- After `disconnect_live_website_visitor` ms (default 1800000 = 30 min) the browser disconnects to save resources. User can click "Continue live updates" to reconnect.

### Color conventions

- Outdoor temperature value text color is dynamically tinted by `get_outTemp_color()` based on the current value (cold = blue, warm = red).
- AQI value color tinted by `get_aqi_color()` based on category (good=green … hazardous=maroon).
- Beaufort label likely color-coded as well via CSS classes.

---

## External data sources

| Source | What it feeds | Endpoint / library | Refresh cadence | Geographic / filter |
|---|---|---|---|---|
| **USGS Earthquake Catalog** | Recent local earthquake (home page right block) | `http://earthquake.usgs.gov/fdsnws/event/1/query` (GeoJSON) | `earthquake_stale = 10740s` (~3 hr) per skin.conf default. Live config likely ~1 hour. | Latitude/longitude of station + `earthquake_maxradiuskm = 1000` km, minmag 2 |
| **GeoNet** (alternate) | Earthquake (NZ users) | `geonet.org.nz` | Same | Configurable; not used here |
| **ReNaSS / France Seisme** (alternate) | Earthquake (FR/EU users) | `api.franceseisme.fr` | Same | Not used here |
| **Aeris/Vaisala XWeather** | Forecast (1-hr, 3-hr, daily 7-day), current observation icon + summary, optional radar map, NWS-derived weather alerts | `api.aerisapi.com/forecasts/`, `api.aerisapi.com/observations/`, `api.aerisapi.com/alerts/`, `maps.aerisapi.com/` (radar tiles) | `forecast_stale = 3540s` (~59 min) | Station lat/lon |
| **Windy.com** | Radar tile (default home page Radar tab) | iframe embed at `windy.com/?...` (configured via `radar_html` extra) | Page-load + optional `reload_images_radar = 300s` | Station lat/lon/zoom |
| **Surf-Forecast.com** | Surf forecast widget on /marine/ | iframe embed `surf-forecast.com/breaks/Huntington-Pier/forecasts/widget/i` | Lazy iframe (their refresh cadence) | Hard-coded to Huntington-Pier break |
| **TidesPro** | Tide table + chart + weekly solunar table on /marine/ | 3 `<script>` includes from `tidespro.com/scripts/...` | Page-load (their JS) | Hard-coded to Newport Beach / Newport Bay Entrance / Corona del Mar (CA) |
| **AirVisual / IQAir** (server-side, not in skin) | AQI value + main pollutant + AQI level + AQI location → written to weewx archive `aqi`/`main_pollutant`/`aqi_level`/`aqi_location` columns. Skin reads from archive. | Configured in `weewx.conf` `[AirVisualService]` (separate weewx extension) | Per archive interval (~5 min) | Closest IQAir monitoring station to lat/lon |
| **Local webcam** | Webcam tab + about-page image | `/webcam/weather_cam.jpg` (Amcrest IP camera, presumably written by a cron / motion job into the lxd shared mount) | 60 s (per `index_radar.inc` JS interval) | Local |
| **Local timelapse** | Webcam timelapse tab | `/webcam/weewx_timelapse.mp4` | 900 s | Local |
| **Custom SQL** (averageclimate group) | "Average Monthly Rain Total" climatology bars | Reads `archive_month_raintotal` table from weewx DB | Per report cycle | Station-local |
| **Google Analytics** (per privacy policy) | Visitor analytics | `googletagmanager.com/gtag/js` | Continuous | All pages |
| **CDN-hosted libraries** | Highcharts Stock 10, jQuery 3.3, Bootstrap 3.4.1, moment-with-locales 2.24, moment-timezone, paho-mqtt 1.1, weather-icons, font-awesome 4.7, Roboto from Google Fonts | Cloudflare cdnjs, code.highcharts.com, fonts.googleapis.com, stackpath.bootstrapcdn.com | Page-load | n/a |

### Aeris weather code lookups (text expansions used in forecasts/alerts)

- **Cloud codes** (5): CL, FW, SC, BK, OV → "Clear" … "Cloudy"
- **Coverage codes** (16): AR, BR, C, D, FQ, IN, IS, L, NM, O, PA, PD, S, SC, VC, WD → "Areas of", "Brief", "Chance of", "Definite", etc.
- **Intensity codes** (4): VL, L, H, VH → "Very Light", "Light", "Heavy", "Very Heavy"
- **Weather codes** (~28): A=Hail, BD=Blowing Dust, BN=Blowing Sand, BR=Mist, BS=Blowing Snow, BY=Blowing Spray, F=Fog, FR=Frost, H=Haze, IC=Ice Crystals, IF=Ice Fog, IP=Sleet, K=Smoke, L=Drizzle, R=Rain, RW=Rain Showers, RS=Rain/Snow Mix, SI=Snow/Sleet Mix, WM=Wintry Mix, S=Snow, SW=Snow Showers, T=Thunderstorms, UP=Unknown Precipitation, VA=Volcanic Ash, WP=Waterspouts, ZF=Freezing Fog, ZL=Freezing Drizzle, ZR=Freezing Rain, ZY=Freezing Spray, W=Windy (DarkSky), TO=Tornado (DarkSky)
- **NWS alert codes** (~140): TOE/911 Telephone Outage, ADR/Administrative Message, AQA/Air Quality Alert, AS_Y/Air Stagnation Advisory, AVW/Avalanche Warning, BZ_W/Blizzard Warning, CF_W/Coastal Flood Warning, EH_W/Excessive Heat Warning, EW_W/Extreme Wind Warning, FF_W/Flash Flood Warning, FR_Y/Frost Advisory, GL_W/Gale Warning, HU_W/Hurricane Warning, IS_W/Ice Storm Warning, RP_S/Rip Current Statement, SV_W/Severe Thunderstorm Warning, TO_W/Tornado Warning, TR_W/Tropical Storm Warning, TS_W/Tsunami Warning, WS_W/Winter Storm Warning, WC_W/Wind Chill Warning, etc.
- **European AW alert codes** (~52): AW_WI_*, AW_SI_*, AW_TS_*, AW_LI_*, AW_FG_*, AW_HT_*, AW_LT_*, AW_CE_*, AW_FR_*, AW_AV_*, AW_RA_*, AW_FL_*, AW_RF_*, AW_UK_* — minor/moderate/severe/extreme variants
- **Beaufort scale** (13): calm / light air / light breeze / gentle breeze / moderate breeze / fresh breeze / strong breeze / near gale / gale / strong gale / storm / violent storm / hurricane force

---

## Configuration / customization surface

The operator can configure the following without touching templates (all in `skin.conf` `[Extras]` plus `[Belchertown]` in weewx.conf):

### Branding & theme
- `site_title` — text logo fallback
- `logo_image`, `logo_image_dark` — light/dark logos
- `theme = light | dark | auto` — auto switches at sunrise/sunset
- `theme_toggle_enabled` — show/hide the toggle slider in nav
- `pi_theme = light | dark | auto` — separate theme for /pi/ page
- `pi_kiosk_bold = true | false`
- Custom CSS via `custom.css`

### Locale & internationalization
- `belchertown_locale = "auto"` or specific locale string
- Translations via `lang/<locale>.conf` (en/ca/de/it shipped). All Aeris codes/labels translatable per locale.

### Feature toggles
- `highcharts_enabled` (charts on/off)
- `forecast_enabled` (forecast row on/off) + `forecast_provider` (aeris) + `forecast_api_id` / `forecast_api_secret`
- `forecast_interval_hours = 0|1|3|24` — default forecast view
- `forecast_alert_enabled` + `forecast_alert_limit`
- `forecast_show_daily_forecast_link` + `forecast_daily_forecast_link`
- `forecast_show_humidity_dewpoint`
- `aqi_enabled` / `aqi_location_enabled`
- `aqi_enabled_kiosk` (separate setting for kiosk view)
- `beaufort_category` (show Beaufort name under wind table)
- `earthquake_enabled` + `earthquake_maxradiuskm` + `earthquake_stale` + `earthquake_server = USGS|GeoNet|ReNaSS` + `geonet_mmi`
- `almanac_extras` (almanac modal on/off)
- `back_to_top_button_enabled` + `back_to_top_button_position` + `back_to_top_button_opacity`
- `mqtt_websockets_enabled` (live data on/off) + host/port/ssl/topic/username/password + `disconnect_live_website_visitor` ms
- `webpage_autorefresh` (ms; only used when MQTT disabled)
- `show_last_updated_alert` + `last_updated_alert_threshold` (alert banner if data stale)
- `googleAnalyticsId`

### Layout knobs
- `station_observations` — comma-separated list of which observations to show in the middle column (e.g. `barometer, dewpoint, outHumidity, rainWithRainRate`)
- `radar_html`, `radar_html_dark`, `radar_width`, `radar_height` — light/dark radar embed code + dimensions
- `radar_html_kiosk` + dims — separate radar for kiosk page
- `aeris_map = 0|1` — use Aeris radar maps service instead of Windy embed
- `highcharts_homepage_graphgroup` — which graphgroup name to render on home (default `homepage`)
- `graph_page_default_graphgroup` — which graphgroup is default on /graphs/ (default `day`)
- `graph_page_show_all_button` — toggle the "All" button
- `highcharts_decimal` / `highcharts_thousands` — number formatting separators

### Charts (`graphs.conf`)
- Each graphgroup has: `title`, `button_text`, `show_button`, `time_length`, `tooltip_date_format`, `gapsize`, `aggregate_type`, `aggregate_interval`, `enable_date_ranges`, `rolling_ranges`, `available_years`, `enable_monthly_breakdown`, `force_full_year`, `start_at_beginning_of_month`, `timespan_start` / `timespan_stop` (for fixed events), `page_content` (HTML block), `generate = daily`, `colors` (default palette), `xAxis_groupby`, `xAxis_categories`
- Each chart inside a group: `title`, `type` (line/spline/area/column), `connectNulls`, `yAxis_min`, `yAxis_max`, `yAxis_label`, `yAxis_tickinterval`, `aggregate_type`, `stacking`, `lineWidth`, `marker`, `states.hover`, `zIndex`, `color`, `name`, `visible`, `opacity`, `observation_type` (override), `average_type` (max/min/avg)
- Special chart types: `windRose` (with 7 Beaufort color bands), `weatherRange` (radial range plot with `range_type` + `area_display`), custom SQL via `use_custom_sql = true` + `custom_sql_query` + `x_column` + `y_column`

### Operator content slots (any-HTML inserts)
- `header.inc` — extra `<head>` content (e.g. tracking pixels)
- `index_hook_after_station_info.inc`
- `index_hook_after_forecast.inc`
- `index_hook_after_snapshot.inc`
- `index_hook_after_charts.inc`
- `index_hook_after_wind_table.inc`
- `index_hook_after_station_observations.inc`
- `records.inc` — intro paragraph above records table
- `records-table.inc` — extra rows in records table (e.g. inside-temp records)
- `about.inc` (or fallback `about.inc.example`)
- `marine.inc`
- `index_radar.inc` (replaces default radar pane entirely)
- `legal.inc`
- Image refresh timers: `reload_hook_images = 0|1`, `reload_images_radar`, `reload_images_hook_asi/_af/_as/_ac` (seconds)

### Social
- `facebook_enabled` / `twitter_enabled` / `social_share_html` / `twitter_text` / `twitter_owner` / `twitter_hashtags`

### NOAA reports
- `[CheetahGenerator]` — auto-generates `NOAA-YYYY.txt` (yearly) and `NOAA-YYYY-MM.txt` (monthly) reports for /reports/

### PWA
- `manifest_name`, `manifest_short_name` — both inserted into manifest.json.tmpl

---

## Live config supplement (added 2026-05-01)

Read directly from the running weewx container (`/etc/weewx/weewx.conf` `[StdReport][[Belchertown]][[[Extras]]]`) and `/var/www/weewx/index.html`. This closes the "Open questions" below for everything operator-configurable.

### Live `[Extras]` values vs skin.conf defaults

| Setting | Live | Default | Notes |
|---|---|---|---|
| `belchertown_debug` | `1` | `0` | Debug mode on (verbose JS console) |
| `belchertown_locale` | `en_US.UTF-8` | `auto` | Pinned to US English |
| `theme` | (commented; effective `light`) | `light` | sessionStorage default = `light` |
| `theme_toggle_enabled` | `1` | `1` | Theme switch shown in nav |
| `logo_image` / `logo_image_dark` | `/images/logo_light.png` / `/images/logo_dark.png` | (none) | Custom branded logos for both themes |
| `site_title` | `HBWeather` | (default) | |
| `station_observations` | `barometer, dewpoint, outHumidity, rainWithRainRate, heatindex, windchill, radiation, UV` | `barometer, dewpoint, outHumidity, rainWithRainRate` | **8 obs in middle column**, not the 4 the default suggests |
| `beaufort_category` | `1` | `1` | Beaufort label shown under wind |
| `manifest_name` / `manifest_short_name` | `HB Weather` / `HBWeather` | `My Weather Website` | Custom PWA |
| `aeris_map` | (commented; effective `0`) | `0` | NOT using Aeris radar — uses Windy via `index_radar.inc` |
| `radar_html` / `radar_html_dark` | (commented; default behavior) | (auto) | Default Windy embed, station-centered |
| `radar_zoom` / `radar_marker` | `8` / `1` | (defaults) | Zoom 8, station marker shown |
| `almanac_extras` | `1` | `0` | **Almanac modal enabled** |
| `highcharts_enabled` | `1` | `1` | Charts on |
| `graph_page_show_all_button` | `1` | `0` | "All" button shown on /graphs/ |
| `graph_page_default_graphgroup` | **`all`** | `day` | **/graphs/ defaults to "All" — every graphgroup stacked vertically** |
| `highcharts_homepage_graphgroup` | `homepage` | `homepage` | |
| `highcharts_decimal` / `highcharts_thousands` | `auto` / `auto` | `auto` | Locale-driven |
| `googleAnalyticsId` | (commented) | (none) | **GA NOT actually enabled** — Privacy Policy claim is stale |
| `webpage_autorefresh` | `0` | `0` | No fallback autorefresh (MQTT carries it) |
| `mqtt_websockets_enabled` | `1` | `1` | Live MQTT on |
| `mqtt_websockets_host` / `_port` / `_ssl` / `_topic` | `weather.shaneburkhardt.com` / `443` / `1` / `weewx/loop` | (defaults) | WSS through Apache |
| `disconnect_live_website_visitor` | **`1800000`** (30 min) | `1800000` | **The 30-min auto-disconnect the user dislikes — it's the upstream default, not custom** |
| `forecast_enabled` | `1` | `1` | Forecast row on |
| `forecast_provider` | `aeris` | `aeris` | Vaisala XWeather (rebranded Aeris); same API |
| `forecast_units` | `us` | `us` | |
| `forecast_lang` | `en` | `en` | |
| `forecast_stale` | `3540` (~59 min) | `3540` | Re-fetch forecast hourly |
| `forecast_interval_hours` | **`24`** | `0` | **Default forecast view is 7-day daily**, not 1-hour |
| `forecast_alert_enabled` | **`1`** | `0` | NWS alerts banner enabled (currently no alerts active) |
| `forecast_alert_limit` | `5` | `5` | Up to 5 active alerts shown |
| `forecast_show_humidity_dewpoint` | (commented; effective `0`) | `0` | Forecast cards do not show humidity/dewpoint |
| `forecast_show_daily_forecast_link` | (commented; effective `0`) | `0` | No "Daily Forecast" deeper link |
| `aqi_enabled` / `aqi_location_enabled` | `1` / `1` | `1` / `0` | AQI on, dominant pollutant subtext on |
| `earthquake_enabled` | `1` | `1` | Earthquake widget on |
| `earthquake_maxradiuskm` | **`400`** | `1000` | Tighter radius — only earthquakes within 400 km |
| `earthquake_stale` | `10740` (~3 hr) | `10740` | Re-fetch every 3 hours |
| `earthquake_server` | `USGS` | `USGS` | |
| `facebook_enabled` | **`1`** | `0` | **Facebook share button enabled** (visible in rendered HTML as `fb-like` widget; loads `connect.facebook.net` SDK) |
| `twitter_enabled` | (commented; effective `0`) | `0` | Twitter share off |
| `social_share_html` | `https://weather.shaneburkhardt.com` | (default) | |
| `back_to_top_button_enabled` | (not in [Extras]; effective default `0`) | `0` | Back-to-top button NOT shown |
| `show_last_updated_alert` / `last_updated_alert_threshold` | (commented) | `0` / `1800` | Stale-data alert disabled |
| Kiosk overrides (`*_kiosk`) | (all commented) | (defaults) | Kiosk page uses defaults if rendered |

### Hook files actually deployed

Files present in `/etc/weewx/skins/Belchertown/`:

- ✅ `about.inc` — custom About page content
- ✅ `index_radar.inc` — custom radar pane (the Windy.com embed lives here, replacing the default)
- ✅ `marine.inc` — custom Marine page (Surf-Forecast + TidesPro embeds)
- ✅ `legal.inc` — custom Legal Disclaimer page
- ✅ `page-header.inc` — custom page-header content (likely the mini-current-conditions strip seen on /graphs, /records, /reports, /about)
- ✅ `celestial.inc` — almanac modal contents (built-in include)
- ✅ `kiosk.html.tmpl` + `kiosk.css` — kiosk page on disk (not linked from public nav)
- ✅ `pi/index.html.tmpl` — Raspberry Pi variant
- 🆕 `graphs.conf.bak-pre-aqi-rewire` — backup made during the AQI rewire (April 2026)

Hook slots NOT used (default behavior):

- ❌ `header.inc` — no extra `<head>` injection
- ❌ `index_hook_after_station_info.inc` — no row-1.5 custom content
- ❌ `index_hook_after_forecast.inc` — no row-2.5 custom content
- ❌ `index_hook_after_snapshot.inc` — no row-3.5 custom content
- ❌ `index_hook_after_charts.inc` — no row-4.5 custom content
- ❌ `index_hook_after_wind_table.inc` — no extra wind content
- ❌ `index_hook_after_station_observations.inc` — no extra obs content
- ❌ `records.inc` — no records-page intro
- ❌ `records-table.inc` — no extra records rows (e.g., inside-temp records)
- ❌ `custom.css` — no operator CSS overrides

### Confirmed by reading rendered `/var/www/weewx/index.html`

- ✅ Page `<title>`: "Huntington Beach, CA Weather Conditions"
- ✅ `<meta name="description">`: "Weather conditions for Huntington Beach, CA as observed by a personal weather station and the weewx weather software"
- ✅ Open Graph metadata (og:title, og:description, og:site_name, og:locale, og:type)
- ✅ `<meta name="robots" content="noodp">` — opt-out of ODP-derived snippets (legacy)
- ✅ Schema.org `WebPage` and `CreativeWork` markup
- ✅ PWA `manifest.json` linked
- ✅ Apple-touch-icons declared at 7 sizes (no 48px on this server, but 72/96/144/168/192 are there + base + sizes)
- ✅ DNS prefetch hints for code.highcharts.com, fonts.googleapis.com, stackpath.bootstrapcdn.com, cdnjs.cloudflare.com
- ✅ Both `style.css` and `belchertown-dark.min.css` loaded simultaneously — theme switch toggles via class on `<body>`, not by swapping stylesheets
- ✅ `loadingMarker` / `onlineMarker` / `offlineMarker` spans rendered (initial state hidden, JS shows them)
- ✅ `wx-stn-alert` div rendered but currently empty (no active alert at fetch time)
- ✅ `last-updated-alert` div rendered with `display:none` (feature off)
- ✅ Facebook share widget (`fb-like` div + Facebook SDK script) rendered and active
- ❌ NO Google Analytics / GTM / `gtag.js` script tag rendered
- ❌ NO RSS or alternate-feed `<link>` tags
- ✅ Initial values at fetch time: outTemp `61.0°F`, AQI `55.0` (moderate, PM2.5), feels-like `59.9°F`, wind `274° / W`, today high `72.1°F`, today low `61.0°F`, station heading `GW2292 Huntington Beach Weather Conditions`
- ✅ Six graphgroups loaded into client JS: `averageclimate`, `homepage`, `monthly`, `ANNUAL`, `Tropical_Storm_Hilary`, `airquality`

### NOAA report sample

One report retrieved (`NOAA-2026-04.txt`). Standard weewx ReportEngine output:

- Header: `NAME`, `ELEV`, `LAT`, `LONG`
- Monthly summary: mean temp, monthly high (with date), monthly low (with date), total rainfall, average wind speed, highest wind gust (with date)
- Day-by-day rows with rain
- Heating/cooling degree days
- Wind direction summary (predominantly westerly observed)
- Does NOT include solar radiation / UV columns by default (matches the default weewx NOAA template; would require a custom NOAA template to add)

### Open questions now closed

- ✅ Live `[Extras]` overrides — captured above
- ✅ Forecast provider — Aeris (Vaisala XWeather is the rebrand)
- ✅ AQI provider — AirVisualService writes to archive, skin reads from archive (no live API call from skin)
- ✅ Live radar — Windy.com embed via `index_radar.inc` (default radar_html is commented; aeris_map = 0)
- ✅ `forecast_show_humidity_dewpoint` — off
- ✅ NOAA report content — standard weewx columns (no UV/solar)
- ✅ Footer hooks — `header.inc` not present
- ✅ Disabled-by-default features:
  - Social share: **Facebook ON, Twitter off**
  - Google Analytics: **OFF** (despite the Privacy Policy mentioning it — privacy doc is stale)
  - Kiosk AQI: default off (kiosk not publicly linked anyway)
  - Back-to-top button: off
  - Last-updated stale alert: off
  - Forecast alert banner: **ON** (currently no alerts active so banner is empty)
- ⚠️ Lightning data populated: not directly DB-queried, but the WS-5000-IP has a lightning sensor (per About) and the `homepage` chart group includes `homeLightningInfo` chart, so reasonable to assume yes

### Net inconsistencies worth flagging to user

1. **Privacy Policy claims Google Analytics is in use; the rendered page does not load GA.** Either restore GA (and document the actual tracking ID in `[Extras]`) or update the Privacy Policy to remove the GA section. Production/policy mismatch.
2. **Facebook share widget is live and loads `connect.facebook.net` SDK** on every page view. The Privacy Policy currently mentions only Google Analytics — Facebook's pixel/SDK should be disclosed too if it stays.
3. **The 30-minute MQTT auto-disconnect** the user complained about is the upstream default (`1800000` ms). Not custom-configured. Lowering or removing it is a one-line skin.conf change today; for Clear Skies it's a default-behavior decision (per ADR-005's realtime architecture) — the SSE service should default to no wall-clock timeout and instead pause via `document.visibilityState`.

---

## Open questions / couldn't determine

- **Live `[Extras]` values**: the snapshot's `skin.conf` is the upstream default; the running server has overrides we don't see in the snapshot directory tree. From the cross-reference with `REPO-VS-SERVER-DIFF-2026-04-29.md`, server `skin.conf` has uncommitted drift. From observed live behavior we can infer: `forecast_enabled=1`, `aqi_enabled=1`, `aqi_location_enabled=1`, `earthquake_enabled=1`, `almanac_extras=1`, `mqtt_websockets_enabled=1`, `theme_toggle_enabled=1`. Cannot confirm exact threshold values (`earthquake_maxradiuskm`, `forecast_stale`, etc.) without reading the server config directly.
- **Forecast provider currently**: about page credits "Vaisala XWeather" but `belchertown.py` only knows the `aeris` API endpoints. XWeather is the new branding for AerisWeather (acquired by Vaisala in 2022). Confirmed Aeris-API-compatible. The default `forecast_provider = "aeris"` likely still applies.
- **AQI provider on the live server**: per `reference/weather-skin.md`, AQI is now sourced from the `archive` DB columns written by `AirVisualService` (an AirVisual / IQAir extension). The skin only reads the value/category/pollutant/location from the archive — it does not call the AQI API itself. Confirmed via Phase 3 of the AQI-CENTRALIZATION-PLAN (committed). Older Belchertown versions called Aeris for AQI directly; that path is dead in this deployment.
- **Live radar implementation**: about page credits Windy.com. The default skin uses `radar_html` (operator-supplied iframe). We cannot see the exact embed HTML without the live `[Extras][[radar_html]]` value. Reasonable assumption: a Windy embed iframe centered on lat 33.7, lon -118.0.
- **Hilary chart group has `generate = daily`**: meaning these charts only regenerate once per day (not per archive record), to save CPU on a fixed-historical event.
- **Lightning data**: schema includes `lightning_strike_count` and `lightning_distance` columns. The Ambient WS-5000-IP has lightning detection per the about page. Cannot confirm from outside whether these fields are currently populated (would require querying the archive DB).
- **`forecast_show_humidity_dewpoint`**: default `0`. Cannot tell from a static fetch whether the live forecast cards show humidity/dewpoint or not.
- **NOAA report content**: pre-formatted weewx output. Exact column set (whether it includes solar/UV beyond the standard temp/rain/wind) wasn't fetched; would require pulling one of the .txt files.
- **Footer hooks / page-bottom content**: there are slots `header.inc` and `custom.css` that may inject extra content at runtime. Not visible in the snapshot, would need a live HTML dump.
- **Marine page header**: marine-page template includes `marine.inc` but the surrounding template currently has a typo (`#include "marine.inc"` inside an `if os.path.exists("about.inc")` block — this works because both files exist on disk and the marine path is taken via the file existence check). Cosmetic only.
- **Live "Air Quality" graph**: the `[airquality]` graphgroup currently in the local repo's `graphs.conf` post-dates the 2026-04-29 server snapshot. Reasonable to assume it's deployed to the live server because the live /graphs/ page shows the "Air Quality" button. Confirmed via WebFetch.
- **Disabled-by-default features** (visible in skin.conf but not currently active per defaults — could be active via server overrides): social share buttons, Google Analytics ID, kiosk-mode AQI, back-to-top button, last-updated stale-data alert, forecast alert banner.
