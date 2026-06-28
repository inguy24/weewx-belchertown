# Clear Skies — Dashboard Manual

Single authority for Clear Skies dashboard technical behavior rules. Companion to **DESIGN-MANUAL.md** (visual design rules).

When this document conflicts with any other source, **this document wins**.

Companion documents:
- **DESIGN-MANUAL.md** — visual design rules (colors, tokens, card anatomy, icons)
- **API-MANUAL.md** — API implementation rules (data model, units, enrichment)
- **ARCHITECTURE.md** — system topology, dashboard pages, routes

Last updated: 2026-06-27

---

## Table of Contents

1. [Pages & Routes](#1-pages--routes)
2. [Time Zones](#2-time-zones)
3. [Internationalization](#3-internationalization)
4. [Browser Support](#4-browser-support)
5. [Performance Budget](#5-performance-budget)
6. [Charts System — Dashboard Side](#6-charts-system--dashboard-side)
7. [Data Refresh & Realtime](#7-data-refresh--realtime)
8. [Card Plugin Contract](#8-card-plugin-contract)
9. [Dynamic Now Page & Page Visibility](#9-dynamic-now-page--page-visibility)
10. [Radar Card & Expanded View](#10-radar-card--expanded-view)
11. [Anti-Patterns](#11-anti-patterns)

---

## §1 Pages & Routes

### Route table

Nine built-in pages plus a custom-page mechanism. React Router v7. All pages lazy-loaded.

| # | Page | Route | Default state |
|---|------|-------|---------------|
| 1 | Now (home) | `/` | Always visible — cannot be hidden |
| 2 | Forecast | `/forecast` | Visible |
| 3 | Charts | `/charts` | Visible |
| 4 | Almanac | `/almanac` | Visible |
| 5 | Seismic | `/seismic` | Visible |
| 6 | Records | `/records` | Visible |
| 7 | Reports | `/reports` | Visible (self-hides when NOAA files absent) |
| 8 | About | `/about` | Visible |
| 9 | Legal | `/legal` | Visible (linked from footer) |
| — | Custom pages | `/:slug` | Operator-defined, appear after Reports before About |
| — | 404 | `/*` | Any hidden or nonexistent route |

Register routes at runtime from operator config. Hidden pages return 404 — they are not reachable at all, not merely absent from navigation.

### Per-page default content

**Now (`/`):**
Current-conditions hero (operator-uploadable photo, `outTemp` primary, condition + feels-like secondary), active alert banner, Today's Highlights (today's hi/lo + peak gust + rain so far + peak AQI + records-broken-today), Wind tile (animated compass + speed/gust + Beaufort), Station observations tile (locked default 8: barometer + 3-hr trend, dewpoint, outHumidity, rain combined, heatindex, windchill, radiation, UV), Precipitation & Humidity tile, Sun & Moon mini-tile, AQI tile (pollutant dots colored per-pollutant from `pollutantSubIndices` when available; falls back to overall AQI color when absent), Lightning tile, Earthquake tile, Today's forecast card, Radar card (expands to full width when webcam is disabled), Webcam card (only when `webcam.json` `enabled: true` and image loads successfully; has Live / Timelapse tab toggle), homepage chart panel (default `homepage` group with 1d/3d/7d/30d/90d range selector and "View all charts →" link).

**Forecast (`/forecast`):**
Active alert banner header strip, hourly forecast (scrollable strip; provider-adaptive 1h or 3h intervals), daily forecast (7-day default, extending if the provider supplies more; per-day icon + day-of-week + condition + hi/lo + precip% + wind), forecast discussion / narrative tile (operator-toggled, off by default; renders NWS AFD or equivalent prose), forecast freshness indicator.

**Charts (`/charts`):**
Config-driven tabs — one tab per chart group from `GET /api/v1/charts/config`. Default tabs: `homepage`, `averageclimate`, `monthly`, `ANNUAL`, then operator-defined custom groups in operator-set order. Per-tab features: time-range navigator, range-selector buttons, year/month dropdowns for `monthly` and `ANNUAL`, hover tooltip, clickable legend, PNG + CSV export, `page_content` markdown narrative slot above charts.

**Almanac (`/almanac`):**
Sun details (civil twilight, rise/transit/set, azimuth/altitude/RA/declination, total daylight + delta vs yesterday, next equinox/solstice), Moon details (rise/transit/set, azimuth/altitude/RA/declination, phase name + % full, next full/new moon), year-long sunrise/sunset chart, year-long daylight chart, moon-phase calendar, planet visibility, lunar eclipses, meteor showers.

**Seismic (`/seismic`):**
Two-card layout: Leaflet/OSM map card (left on desktop, stacked on mobile) with earthquake markers sized by magnitude and colour-coded by age (oldest = blue, newest = red), station location marker, and GEM Global Active Faults overlay (show/hide toggle, default on; fault lines drawn in uniform amber). Scrollable earthquake list card (right on desktop). Clicking a list row flies the map to that earthquake; clicking a map marker scrolls the list. Settings summary bar (provider, radius, minimum magnitude, days). API endpoint: `/api/v1/earthquakes`.

**Records (`/records`):**
Per-section cards for Temperature, Wind, Rain, Humidity, Barometer, Sun (gated on radiation/UV), AQI (gated on AQI columns). Each card: non-sortable table with four columns — Record | Today | Value | Date. Single period toggle (YTD / All-Time) switches all cards simultaneously. "Broken in last 30 days" badge on freshly set records.

**Reports (`/reports`):**
Year/month dropdowns populated from `NOAA-*.txt` files actually present. HTML-parsed table as default rendered view. "Download .txt" link. Self-hide when NOAA files absent; configuration UI prompts operator to enable the weewx NOAA generator.

**About (`/about`):**
Operator-authored markdown. Setup wizard pre-populates from collected station fields. Operator edits via configuration UI.

**Legal (`/legal`):**
Legal/privacy text. Also linked from footer. Setup wizard requires acknowledgment checkboxes. Privacy Policy text auto-updates to match the configured analytics provider.

### Custom pages

Custom pages appear after Reports, before About. Operator picks slug (validated unique), display name, Phosphor icon (curated subset), nav-bar position, and content blocks. Content blocks: any canonical built-in cards, markdown narrative blocks, custom charts, custom records, embedded media. Custom pages are reorderable, renamable, hide-able, and deletable. Persists in operator config.

### Self-hide behavior

Cards self-hide when all backing data is null over the visible period. A page self-hides when all of its cards self-hide. Now never self-hides.

**Configured-but-no-data:** When backing data is transiently absent (network delay, provider outage), keep the card visible with a graceful empty state (display `—` for missing values). Do NOT hide a card for transient data absence — self-hide is for permanently missing sensors, not temporary gaps.

### API client configuration

The dashboard connects to a single backend: the API. Use relative `/api/v1` by default.

| Variable | Purpose | Default |
|----------|---------|---------|
| `VITE_API_BASE_URL` | Override the API base URL | `/api/v1` |
| `VITE_SSE_URL` | Override the SSE endpoint URL | `/sse` |

A global error boundary wraps the entire app tree. Any unhandled React error surfaces a top-level fallback rather than a blank screen.

---

## §2 Time Zones

### Wire format

Every timestamp on the API wire ends in `Z` (UTC ISO-8601). No local-time strings in API responses. Never accept or display a timestamp that lacks the `Z` suffix.

### Display

Render timestamps in the station's local time zone, not the visitor's browser-local zone. A visitor in Tokyo viewing a New England station sees Eastern times. This matches every weewx skin's precedent.

The station time zone is delivered via `StationMetadata` as an IANA identifier (e.g., `America/New_York`).

### TZ source priority (API-side, for reference)

| Priority | Source |
|----------|--------|
| 1 | Explicit operator setting in clearskies-api config |
| 2 | weewx config (`Station.timezone` if set) |
| 3 | OS timezone (resolved via `zoneinfo`) |
| 4 | UTC + WARN (logged at startup; operator must set a timezone) |

### Browser-side rendering

Use `Intl.DateTimeFormat` with the station IANA time zone and the active locale. No JS date library is required.

Never call `toLocaleString()` without an explicit `timeZone` option. Always supply the station IANA identifier.

### No per-user TZ override

No per-user time zone override at v0.1. All visitors see station-local time. Phase 6+ enhancement: localStorage override using `Intl.DateTimeFormat` (client-side only, no server change).

### Station clock utility

`utils/station-clock.ts` is the single module for station-date logic. Every component that needs to know the station's current date or time imports from this module. No component computes station dates ad-hoc.

The module exports four functions (ADR-075 §6):

```typescript
/** Extract stationClock.date from an API response. */
export function getStationDate(response: { stationClock?: StationClock }): string;

/** Increment a YYYY-MM-DD date string by n days. */
export function addDays(dateStr: string, n: number): string;

/** Is the given validDate "today" at the station? */
export function isStationToday(validDate: string, stationDate: string): boolean;

/** Convert stationClock.time to epoch ms for elapsed-time comparisons. */
export function stationTimeMs(stationClock: StationClock): number;
```

The `stationClock` block is present on every API response:

```json
{
  "data": { "..." : "..." },
  "stationClock": {
    "date": "2026-06-27",
    "time": "2026-06-27T22:30:00-04:00",
    "timezone": "America/New_York"
  }
}
```

- `date` — station-local date as YYYY-MM-DD. Canonical answer to "what day is it at the station?"
- `time` — station-local time as ISO-8601 with UTC offset.
- `timezone` — IANA identifier (redundant with `StationMetadata.timezone`; included for self-contained responses).

### Approved temporal patterns

Authority: ADR-075.

| Need | Pattern | Source |
|------|---------|--------|
| "What date is it at the station?" | Read `stationClock.date` from the most recent API response | API |
| "What time is it at the station?" | Read `stationClock.time`, or convert `Date.now()` using station IANA TZ via `Intl.DateTimeFormat` | API or Intl |
| "Is this forecast entry today?" | Compare `entry.validDate === stationClock.date` | API |
| "Format a timestamp for display" | `formatLocalTime(iso, stationTz, locale)` from `utils/time.ts` | Existing utility |
| "Has enough time elapsed since X?" | `Date.now() - new Date(iso).getTime() > thresholdMs` | Native (UTC epoch math) |
| "Should I refetch?" | `Date.now() > new Date(freshness.validUntil).getTime()` | API freshness envelope |
| "Tomorrow's date at the station" | Increment `stationClock.date` by one day via `addDays()` | Derived from API |

`Date.now()` used for display ticks — arc position updates, "last updated N seconds ago" elapsed-time display — is approved. These are not station-date computations. Mark such uses with `// ADR-075: display tick, not data refresh`.

### Banned temporal patterns

These are grep-checkable FAIL conditions (ADR-075 §6). Any of the following in dashboard source is a violation:

```
FAIL: new Date() used to determine station-local date or time
      (Date.now() is OK for UTC epoch elapsed-time math)
FAIL: .toISOString().split('T')[0] used to derive a station-local date
      (this gives a UTC date, not station-local)
FAIL: index === 0 as a proxy for "today" in forecast or any date-ordered list
FAIL: Hardcoded setInterval for data refresh without reference to freshness.validUntil
      or freshness.refreshInterval
FAIL: toLocaleString() or Intl.DateTimeFormat() without explicit timeZone option
FAIL: Any "is it daytime?" check that doesn't use station timezone or stationClock
```

---

## §3 Internationalization

### Supported locales (v0.1)

13 locales ship at v0.1:

| Code | Language |
|------|----------|
| `en` | English (default) |
| `de` | Deutsch (German) |
| `es` | Español (Spanish) |
| `fil` | Filipino |
| `fr` | Français (French) |
| `it` | Italiano (Italian) |
| `ja` | 日本語 (Japanese) |
| `nl` | Nederlands (Dutch) |
| `pt-PT` | Português (Portugal) |
| `pt-BR` | Português Brasil |
| `ru` | Русский (Russian) |
| `zh-CN` | 中文 简体 (Simplified Chinese) |
| `zh-TW` | 中文 繁體 (Traditional Chinese) |

### Framework and file layout

Use **react-i18next** for all user-facing string handling. All 13 locale directories are present under `public/locales/<lang>/<ns>.json`. Locale files are served as static assets via `i18next-http-backend` (loadPath: `/locales/{{lng}}/{{ns}}.json`). The `src/i18n/` directory contains only the i18next configuration and locale-sync hook — no locale JSON files under `src/`.

Default fallback locale is `en`. Missing keys fall back to `en` silently. Numbers, dates, and units format per locale via `Intl.NumberFormat` / `Intl.DateTimeFormat`.

### RTL

No RTL languages in v0.1. Write LTR-neutral CSS throughout: use `margin-inline-start` over `margin-left`, `padding-inline-end` over `padding-right`, and so on. RTL support must be a future addition, not a future rewrite.

### Document language attribute

Set `<html lang="...">` per active locale on every page render.

### CJK fonts

Use system CJK fonts for Japanese, Simplified Chinese, and Traditional Chinese. Do not bundle Noto-CJK or any other CJK web font — the bundle size cost is prohibitive.

---

## §4 Browser Support

### Supported matrix

| Browser | Minimum |
|---------|---------|
| Chrome / Edge / Chromium-based | Last 2 years (~Chrome 110+) |
| Firefox | Last 2 years (~Firefox 110+) |
| Safari (macOS / iPadOS) | 16.4+ |
| iOS Safari | 16.4+ |
| Android Chrome / Samsung Internet / WebView | Last 2 years |

Older browsers may render the dashboard, but do not test against them and do not accept bug reports for them.

### Browserslist config (Vite build target)

```
>0.5%, last 2 years, not dead, not op_mini all
```

This drives transpilation target and CSS prefixing.

### Explicitly not supported

- Internet Explorer (any version) — EOL 2022.
- Opera Mini.
- Any browser without ES2022 baseline, `fetch`, `Intl.DateTimeFormat`, CSS custom properties, or CSS Grid.
- No-JS rendering and progressive enhancement to static HTML — out of scope.

---

## §5 Performance Budget

### Lighthouse targets

Run Lighthouse against the primary pages: Now, Forecast, Charts, Records.

| Category | Target |
|----------|--------|
| Performance | ≥ 90 |

A Performance result below 90 on a release flags a pre-tag investigation.

**Accessibility target:** Lighthouse Accessibility ≥ 90 is tracked here for completeness but is governed by ADR-026 — it is **release-blocking**, not a soft target like the performance budget. A missed accessibility score blocks the release; a missed performance score does not.

### Core Web Vitals

| Metric | Target |
|--------|--------|
| Largest Contentful Paint (LCP) | ≤ 2.5 s |
| Interaction to Next Paint (INP) | ≤ 200 ms |
| Cumulative Layout Shift (CLS) | ≤ 0.1 |

### Bundle size

Initial JS bundle (Now-page route): target **≤ 200 KB gzipped**. Monitor in CI via `vite-bundle-visualizer` or equivalent. Going over flags a review — charting and i18n bundles can grow legitimately; the point is awareness.

### Targets, not gates

Missed targets are bugs to investigate, not release blockers. If a release misses a target: record the actual measured numbers in `docs/audits/<release>.md`, note the cause briefly, file a backlog issue if the miss is fixable, then ship.

Accessibility failures are release-blocking (they determine whether a class of users can use the dashboard at all). Performance misses are not.

### Stale-while-revalidate and CLS

The stale-while-revalidate pattern in `useApiQuery` (§7) is the concrete enforcement mechanism for the CLS ≤ 0.1 target. Skeleton swaps during background refetches cause layout shift. Preserve stale data during refetches to prevent those shifts.

---

## §6 Charts System — Dashboard Side

### Rendering architecture

Charts on the `/charts` page render dynamically from `GET /api/v1/charts/config`. Two components own chart rendering:

- **`ConfigDrivenGroup`** — group container; manages the tab, range selectors, and year/month dropdowns.
- **`ConfigDrivenChart`** — renders an individual chart from its config entry; switches chart component based on series type detection.

Use **Recharts** for all standard time-series charts. Use **custom SVG** for the wind rose.

### Proportional data scaling

For rolling-range chart groups, compute `aggregate_interval` client-side and pass it to the API:

```
aggregate_interval = base_interval × max(1, range / base_time)
```

Pass the result as the `aggregate_interval` query parameter on `/archive` requests. The API groups archive records into `FLOOR(dateTime / N) * N` buckets.

### Per-field aggregation

Each series in the config may specify `aggregate_type`. Pass these to the API via the `agg_map` query parameter. Fields without an explicit type default to `AVG`. Supported types: `avg`, `max`, `min`, `sum`, `count`, `sumcumulative`. The `sumcumulative` type applies SQL SUM per bucket then accumulates into a running total (used for cumulative rain).

### Special series auto-detection

When the dashboard encounters these series names in the chart config, it switches chart component and data strategy automatically:

| Series name | Component | Key behaviors |
|-------------|-----------|---------------|
| `windRose` | Custom SVG polar chart | 16 directions × 7 Beaufort speed bands. Separate raw (unaggregated) archive fetch for `windSpeed` + `windDir`. Reads `beaufort.value` from API-injected field. Always polar. Dashboard does NOT compute Beaufort. |
| `weatherRange` | Recharts arearange (default) or columnrange | 15-band temperature color zones. Dual archive fetch (`agg=min` + `agg=max`), `aggregate_interval=86400`. Default Cartesian. Polar ONLY when operator explicitly sets `polar=true`. |
| `haysChart` | Recharts arearange, always polar | Circular 24-hour wind chart (Mount Washington Observatory style). Queries `windSpeed` + `windGust` max. `yAxis_softMax` controls radial scale. |
| `rainTotal` | Standard time-series | Migration tool auto-promotes to `aggregate_type = sumcumulative`. Queries `rain` column. |

These behaviors are triggered by series name in `charts.conf` — they are not further configurable at the component level.

### Wind rose data fetch

The wind rose requires a **separate raw archive fetch** — no `aggregate_interval` — to preserve wind speed distribution for correct Beaufort classification. Read `beaufort.value` from the API-injected field on each archive record. The dashboard does not compute Beaufort from raw wind speed values.

### Weather range chart

Use dual archive fetches: one with `agg=min`, one with `agg=max`, both with `aggregate_interval=86400`. Render as Recharts arearange (default) or columnrange. Render as polar only when `polar=true` is explicitly set in the chart config. The default is Cartesian.

Apply 15-band temperature color zones (°F and °C variants) — deep blue for cold through red for hot, matching Belchertown's `get_outTemp_color()` zones.

### LTTB downsampling

Apply LTTB (Largest-Triangle-Three-Buckets) downsampling client-side for large datasets before passing data to Recharts. This keeps render performance within the INP ≤ 200 ms budget.

### Export

Provide PNG and CSV export per chart. Both exports are client-side operations.

### Grouped-archive charts

Charts with `xAxis_groupby` in their config use `GET /api/v1/archive/grouped` instead of `GET /api/v1/archive`. This endpoint returns calendar-grouped aggregate data (monthly averages, annual summaries). Do not use `/archive` for `xAxis_groupby` charts.

### What belongs in the API, not the dashboard

The computation boundary is strict. The API is the single conversion and enrichment authority. The dashboard does:

- Rendering and presentation-level logic.
- Client-side binning for visualizations (wind rose direction × Beaufort matrix from API-provided fields).
- LTTB downsampling.
- Chart layout, theming, accessibility.

The dashboard does NOT do:

- Unit conversion.
- Beaufort/comfort-index threshold logic.
- Raw SQL queries.
- Provider API calls.

---

## §7 Data Refresh & Realtime

### Stale-while-revalidate

Stale-while-revalidate is the default behavior for all data fetching. `useApiQuery` distinguishes between initial load (no prior data) and background refetch (prior data exists):

| State | `loading` | `refreshing` | UI behavior |
|-------|-----------|-------------|-------------|
| First page load, no data yet | `true` | `true` | Show skeletons |
| Background refetch with existing data | `false` | `true` | Keep showing stale data |
| Fetch complete | `false` | `false` | Update data in place |
| Refetch error with existing data | `false` | `false` | Keep stale data; set `error` |

**`loading=true`** only when `data` has never been populated. Never set `loading=true` on a background refetch where valid data already exists.

**`refreshing=true`** during any in-flight request (initial or background). Cards that want a subtle "updating..." indicator may destructure `refreshing`. No card is required to use it.

**Refetch error:** Stale data stays visible. Do not blank the UI on a failed background refetch. The visitor sees last-known-good data.

### Theme initialization

Gate `setDaytime(scene.daytime)` on `sceneLoaded=true`. Before `sceneLoaded`, the theme stays as determined by the `index.html` inline script (localStorage preference or OS `prefers-color-scheme`). This eliminates the dark-flash-then-correct-theme sequence on page load.

```tsx
useEffect(() => {
  if (sceneLoaded) {
    setDaytime(scene.daytime);
  }
}, [scene.daytime, sceneLoaded, setDaytime]);
```

`SCENE_DEFAULT = { sky: 'clear', daytime: true, overlay: null }` — the default is only used as the background photo layer initial state. It must not propagate to the theme system before real API data arrives.

### Wall-display use case

Do not create a blanking cycle on any interval. Unattended wall-mounted displays must run indefinitely without flashing or going blank. The stale-while-revalidate pattern and the theme initialization gate both serve this requirement.

### `useApiQuery` implementation

- Use `hasDataRef` (a `useRef`) to track whether data has been received at least once.
- Use a `fetcherRef` pattern to avoid stale closures in the polling `useEffect`.
- Use `AbortController` and clean up on component unmount.
- Use a `refetchCounter` for manual refetch triggering.
- Spread the `deps` array into the `useEffect` dependency array.

### `useSSE` hook

The SSE hook subscribes to the event stream at `VITE_SSE_URL` (default `/sse`).

Use `addEventListener("loop", ...)` — NOT `onmessage`. The named event type is `"loop"`. Using `onmessage` will miss all SSE events.

The browser `EventSource` API handles auto-reconnect automatically. Do not implement manual retry logic. The hook reports three statuses: `connecting`, `connected`, `disconnected`.

Skip SSE in mock mode (set `VITE_MOCK_MODE=true` in the build env to disable the live SSE connection for development).

### `useRealtimeObservation` merge

The realtime observation hook maintains a merged view: REST baseline overlaid with SSE updates.

**Merge behavior:**
- REST `GET /api/v1/current` provides the baseline.
- SSE `"loop"` events provide live updates via shallow merge over the REST baseline.
- `dateTime` (epoch integer from SSE) converts to `timestamp` (ISO string) on merge.
- Apply the `WEEWX_TO_OBSERVATION` field map explicitly — do not pass raw loop packet field names to components.

**Special-case plain strings (not `ConvertedValue` shape):**
- `comfortIndex` — plain string (`"windChill"`, `"heatIndex"`, or `"none"`).
- `windDirCardinal` — plain string (16-point compass code).
- `windGustDirCardinal` — plain string (16-point compass code).

Use the `isConvertedValue()` type guard before rendering any field as a `ConvertedValue`.

**`extras` field:** Not updated from SSE. The `extras` object stays at the REST baseline between full REST refetches.

**Scene:** From REST only. SSE events do not update the scene descriptor.

### API client

Use native `fetch` only. Do not add axios, ky, or TanStack Query.

- `fetchApi<T>` is the generic fetch wrapper. It parses `application/problem+json` error bodies.
- `getBranding()` fetches `/branding.json` — a static file served by Caddy — not `/api/v1/branding`.
- All other data comes from `/api/v1/*`.

### Freshness-driven polling

Every cacheable API response carries a `freshness` block (ADR-075 §4):

```json
{
  "data": { "..." : "..." },
  "freshness": {
    "generatedAt": "2026-06-28T02:30:00Z",
    "validUntil": "2026-06-28T03:00:00Z",
    "refreshInterval": 1800
  }
}
```

| Field | Meaning |
|-------|---------|
| `generatedAt` | When the API produced this response (UTC ISO-8601 Z) |
| `validUntil` | When the data should be considered stale. When `Date.now()` exceeds this timestamp, trigger a background refetch. |
| `refreshInterval` | How often the data type typically updates at the source (seconds). Cards that want proactive polling use this as their poll interval. |

`useApiQuery` is extended to schedule refetches from `validUntil`. When `Date.now()` exceeds the `validUntil` epoch, `useApiQuery` triggers a background refetch automatically. Cards do not set their own timers.

No hardcoded `setInterval` for data refresh. A call like `setInterval(fetch, 60_000)` is a banned pattern (§11). All refetch cadence comes from the `freshness` block.

The stale-while-revalidate pattern (§7 existing rule) applies to freshness-driven refetches. Never show skeletons during a background refetch where valid data already exists.

SSE responses and setup endpoints do not carry a `freshness` block — those are push-based or non-cacheable.

### Idle detection

The `useIdleDetector()` hook maintains a single idle state for the entire app tree. It is not per-card.

**Tracked events:** mouse move, keypress, scroll (passive listener), touch (passive listener).

**Provider:** `IdleDetectorProvider` wraps the app tree. Consumer cards call `useIsIdle()` to read the current idle state.

**Idle behavior (ADR-075 §7):**

| Setting | Type | Default | Meaning |
|---------|------|---------|---------|
| `idleTimeout` | integer (minutes) | 30 | Minutes of no interaction before idle mode activates |
| `idleRefreshFactor` | integer | 10 | Multiplier applied to `refreshInterval` during idle |

After `idleTimeout` minutes of no user interaction, all polling cards multiply their `refreshInterval` by `idleRefreshFactor`. A card that normally polls every 30 seconds polls every 300 seconds (5 minutes) while idle.

The SSE connection stays open during idle — it is push-based and has no cost to keeping alive.

Any user interaction (mouse move, keypress, scroll, touch) resets the idle timer and immediately restores normal refresh rates.

Setting `idleTimeout` to `0` disables idle detection entirely. Use this for wall-display and kiosk deployments that must refresh at full rate indefinitely.

`idleTimeout` and `idleRefreshFactor` are served to the dashboard as part of station metadata (populated by the operator via the wizard/admin UI).

---

## §8 Card Plugin Contract

### Card metadata

Every card — built-in and future third-party — declares metadata in a plain data file with no React imports:

- **`type`** — unique string identifier (e.g., `"aqi"`, `"wind-compass"`). The `CardType` is a string literal union of all registered card types.
- **`displayName`** — human-readable name for the admin layout editor (e.g., `"Air Quality Index"`).
- **`apiEndpoints`** — array of API endpoint paths the card needs (e.g., `["/api/v1/aqi/current"]`). Card authors determine these by reading the published OpenAPI spec at `/api/v1/openapi.json`. The container deduplicates across all active cards and fetches each endpoint once.
- **`allowedLayouts`** — array of `{ footprint, rowSpan }` configurations the card supports. A card may render differently for each. The operator selects from this list in the layout editor. Example: `[{ footprint: "tile", rowSpan: 1 }, { footprint: "wide", rowSpan: 1 }]`.
- **`thumbnail`** — path to a static preview image for the admin layout editor (relative to the build output root, e.g., `"/card-thumbnails/aqi.png"`).

The metadata file (`card-metadata.ts`) has **no React imports**. This is enforced by the build-time manifest script importing it in a non-React context.

### Card component props

Every card component receives a uniform props shape:

- **`dataBag`** — `Record<string, any>` keyed by API endpoint path. The container populates the bag by fetching all unique endpoints declared by active cards. Each card extracts the specific fields it needs internally. The loose typing is deliberate: a strongly-typed bag would require the container to know every endpoint's response shape, re-coupling page and card.
- **`layout`** — `{ footprint: CardFootprint; rowSpan: 1 | 2 | 2.5 }`. The active layout configuration for this card instance, selected by the operator via the layout editor.
- **`stationTz`** — IANA timezone string from station metadata.

**`stationClock` in dataBag:** Every API response stored in `dataBag` includes `stationClock` and `freshness` blocks at the response envelope level (ADR-075 §3–4). A card that needs station-date logic reads `stationClock.date` from its response data via `getStationDate()` from `utils/station-clock.ts`. Cards must not use `new Date()` to determine the station-local date. Example:

```typescript
// Inside ForecastCard component
const forecastData = dataBag["/api/v1/forecast/daily"];
if (!forecastData) return <CardSkeleton />;
const stationDate = getStationDate(forecastData);
// Compare entry.validDate === stationDate, not index === 0
```

Each card handles its own loading and error states based on whether its required data is present in the bag.

### Card registry

The card registry (`card-registry.ts`) combines metadata with lazy React component references. It provides:

- `getCard(type)` — returns the full registration (metadata + component) for a card type.
- `getAllCards()` — returns all registered cards.
- `getBuiltinCards()` — returns only built-in cards (excludes future v2 custom cards).
- `getEndpointsForCards(types)` — collects and deduplicates all API endpoints for a set of card types.

### Build-time card manifest

A prebuild script reads only the metadata file (no React) and writes `card-manifest.json` to the build output (`dist/`). This JSON artifact contains all card metadata (type, displayName, apiEndpoints, allowedLayouts, thumbnail path) and is consumed by the admin card layout editor (Python/HTMX) — no React required. The script runs as a `"prebuild"` entry in `package.json`, before `tsc -b && vite build`.

### Self-extraction pattern

Cards extract their own data from the data bag using their declared endpoint paths. The extraction logic lives inside the card component, not in the page container. This is the key architectural invariant: the container does not know what data each card needs or how it renders. Example pattern:

```
// Inside AqiCard component
const aqiData = dataBag["/api/v1/aqi/current"];
if (!aqiData) return <CardSkeleton />;
// ... render using aqiData
```

### 14 built-in cards

All 14 Now page cards conform to the plugin contract. Their card types, endpoint declarations, and allowed layouts match the current hardcoded arrangement in `now.tsx`. The full inventory is defined in `card-metadata.ts`.

---

## §9 Dynamic Now Page & Page Visibility

### Now page as container

The Now page is a generic container that renders cards from a layout configuration:

1. Fetch the layout config via `fetchNowLayout()` on mount (fetches `/now-layout.json`; falls back to `DEFAULT_NOW_LAYOUT` on 404 or parse error).
2. Look up each card in the card registry.
3. Collect all unique API endpoints from active cards via `getEndpointsForCards()`.
4. Fetch each unique endpoint once, build the data bag.
5. Render cards in layout order: for each entry, render `card.component` with `{ dataBag, layout, stationTz }`.
6. The NowHeroCard renders outside the grid unconditionally — it is a layout element, not a configurable card.

**React hooks constraint:** All data-fetching hooks must be called unconditionally at the top of the component (React rules of hooks). Endpoints not needed by the active card set use skip/enabled flags on hooks — never conditional hook calls. `tsc --noEmit` catches hook ordering violations.

### Layout config types

- `NowLayoutEntry` — `{ type: CardType; footprint: CardFootprint; rowSpan: 1 | 2 | 2.5 }`.
- `NowLayoutConfig` — `{ version: 1; cards: NowLayoutEntry[] }`.
- `DEFAULT_NOW_LAYOUT` — compiled-in constant matching the current hardcoded card arrangement (14 cards, current sizes and order). Used when `/now-layout.json` is absent or unparseable.

### Layout config fetch

`fetchNowLayout()` fetches `/now-layout.json` from Caddy. On 404 or parse error, returns `DEFAULT_NOW_LAYOUT`. Never throws. Cards not in the layout don't render — this is how operators hide individual Now page cards.

### Page visibility

The dashboard reads `/pages.json` at boot to determine which pages are visible. Format: `{ "hidden": ["seismic", "reports"] }`. Absent file or parse error = `{ "hidden": [] }` (all pages visible).

**Navigation filtering:** `NAV_ITEMS` in the nav rail and mobile bottom nav are filtered by the visibility config. Hidden pages are removed from navigation. "Now" is never filtered — it is always visible regardless of the config.

**Route filtering:** Routes for hidden pages render the 404 (Not Found) page. Hidden pages are not merely absent from navigation — they are unreachable.

**"Now" protection:** The dashboard ignores "now" if present in the hidden list. This is enforced independently of the admin UI's disabled checkbox — defense in depth.

### Branded 404 page

The Not Found page (`not-found.tsx`) renders:

- Operator logo (theme-aware, from `useBranding`).
- A weather-themed pun (randomly selected from a built-in array of 8–10 options).
- "Back to Now" link.
- WCAG AA compliant (contrast, heading hierarchy, keyboard focus).

---

## §10 Radar Card & Expanded View

### Radar card (Now page)

The radar card renders an animated XYZ tile map using Leaflet. Both RainViewer and LibreWxR use the same XYZ tile animation pattern — no WMS-T rendering is involved.

**Tile fetching by provider:**

| Provider | Tile source | Frame metadata source |
|---|---|---|
| `librewxr` | Caddy proxy (`/librewxr/{path}/{size}/{z}/{x}/{y}/{color}/{options}.webp`) | API `GET /api/v1/radar/providers/librewxr/frames` |
| `rainviewer` | Direct to CDN (`{host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.png`) | API `GET /api/v1/radar/providers/rainviewer/frames` |

Tile URL templates come from the API capability response. The dashboard does not hardcode tile paths.

**Expand button:** Phosphor `ArrowsOut` icon in the card header. Navigates to `/radar` (pushes to browser history). Opens the expanded view at the same zoom level and center as the card.

**Animation:**
- Adaptive speed: target ~15-20 second loop regardless of frame count. LibreWxR with 24+ frames and RainViewer with ~13 frames should both feel smooth.
- Card view caps at ~24 most recent frames.
- Nowcast frames visually distinguished (dashed border on timeline, opacity pulse, or similar visual marker).

**Provider-adaptive legend:** Legend gradient reflects the active provider's color scheme. Updates when the color scheme changes (LibreWxR only — RainViewer has a single scheme).

**Attribution:** Displayed per PROVIDER-MANUAL.md §7. Both the Leaflet attribution control and any below-card caption must agree.

### Live refresh

Periodically re-fetch frame metadata to pick up new frames as they become available. Drop oldest frames to maintain the cap. The animation loop always shows the latest data, not a stale snapshot from page load.

- Refresh interval: from API capability response `refresh_interval` field (operator-configurable, default 600 seconds).
- On new frames: seamlessly append to the animation loop, drop oldest to maintain cap.
- Applies to both card view and expanded view.

### Idle timeout

Stop animation, tile fetching, and live refresh after 60 minutes of no user interaction (mouse, touch, keyboard, scroll). Resume on interaction.

- **Tab visibility:** Pause immediately when the browser tab is hidden (Page Visibility API). When the tab becomes visible again, refresh frame metadata before resuming animation (data may have changed while hidden).
- Applies to both card view and expanded view.
- Purpose: prevent idle/hidden tabs from generating continuous load against the provider.

### Expanded radar view (`/radar`)

Full-viewport overlay with enhanced controls. Pushed as a SPA route (`/radar`) for bookmarkability — Caddy `try_files` handles it. Not a new "page" in the page taxonomy; it's an overlay that opens from the radar card.

**Overlay behavior:**
- Full viewport (100vw × 100vh).
- Opens at the same zoom level and center as the card — it provides room for controls and readable detail, not a different map.
- Close button (top-right, Phosphor `X`) + Escape key closes. Returns to the previous page.
- Focus trap for accessibility (Tab/Shift-Tab cycles within the overlay).
- Direct navigation to `/radar` renders the expanded view at the provider's default center/zoom.

**Time slider (bottom bar):**
- Horizontal scrubable slider showing all frames.
- Play/pause button, speed control (0.5x, 1x, 2x).
- Current timestamp display (formatted in station timezone).
- Nowcast frames visually distinguished on the slider (different color segment or marker).
- Drives the same XYZ tile animation as the card.

**Layer/config panel:**
- Sidebar on desktop (right side), bottom sheet on mobile (drag handle, half-height default).
- Provider-adaptive: shows controls relevant to the active provider.
- Collapsible/expandable. State persists in localStorage.

**Color scheme picker (LibreWxR only):**
- 13 color schemes displayed as a grid with swatch preview.
- Selection updates the `color` path segment in tile URLs + legend.
- Hidden when provider is RainViewer.
- Selected scheme persists in localStorage.

**Opacity slider:**
- 0-100%, default 70%.
- Affects radar tile layer opacity only (base map unaffected).

**Alert polygon overlays (LibreWxR only):**
- Fetched from LibreWxR `/v2/alerts` via Caddy (URL from capability response).
- Query by map viewport bounding box (`?bbox=`).
- Rendered as Leaflet GeoJSON polygons — severity-colored (stroke + fill per WMO CAP severity).
- Auto-refresh every 5 minutes.
- Toggle on/off in layer panel (default: on).
- Only available when provider is LibreWxR. Hidden for RainViewer.

**Wind arrows overlay (LibreWxR only):**
- LibreWxR provides wind arrow tiles as a separate layer.
- Rendered as an overlay on the radar map, z-order above radar tiles.
- Toggle on/off in layer panel (default: off).
- Only available when provider is LibreWxR.

**Zoom bounds enforcement:**
- Read geographic bounds from API capability response.
- Set Leaflet `maxBounds` to prevent zooming out past provider coverage.
- No bounds configured = allow global zoom (default behavior).

### WCAG 2.1 AA requirements for radar

- Expanded overlay: `role="dialog"`, `aria-modal="true"`, focus trap.
- All controls keyboard navigable (Tab, Enter, Space, Arrow keys).
- Time slider: Arrow keys move between frames, value announced via `aria-valuenow` / `aria-valuetext`.
- Frame changes: `aria-live="polite"` region announces current timestamp.
- `prefers-reduced-motion`: pause animation automatically, reduce transitions.
- All interactive elements: visible focus indicator, ≥44px tap targets on mobile.
- axe-core: 0 violations on both card and expanded view.

---

## §11 Anti-Patterns

Never do the following in dashboard code.

**Never compute Beaufort, comfort index, or unit conversion in the dashboard.**
The API is the single conversion and enrichment authority. The dashboard renders `value` and `label` from `ConvertedValue` shapes. Beaufort thresholds, unit conversion factors, and comfort index selection logic live in the API's enrichment pipeline.

**Never display local-time strings from the API.**
The API emits UTC ISO-8601 with `Z`. Use `Intl.DateTimeFormat` with the station IANA time zone identifier from `StationMetadata` to format all timestamps for display.

**Never call `toLocaleString()` without an explicit `timeZone` option.**
Calling `date.toLocaleString()` with no options uses the visitor's browser time zone, not the station time zone. Always pass `{ timeZone: stationTimezone }`.

**Never show skeletons during background refetches.**
Check `loading` (not `refreshing`) before rendering a skeleton. `loading` is `true` only on genuine first load. Once data exists, background refetches must show stale data, not blanked cards.

**Never create chart-type-specific API calls.**
Use the general-purpose `/archive` and `/archive/grouped` endpoints with config-driven parameters. Do not add API endpoints that exist solely to serve a particular chart type's data shape.

**Never hardcode unit strings.**
Render the `label` field from the `ConvertedValue` shape the API returns. Never write `"°F"`, `"mph"`, `"inHg"`, or any other unit string directly in component code.

**Never gate theme initialization on the default scene.**
`SCENE_DEFAULT` is a placeholder. The theme system must wait for `sceneLoaded=true` before calling `setDaytime`. Gating on the default causes a dark-flash-then-correct-theme sequence on every page load.

**Never use `onmessage` for SSE loop events.**
The SSE stream uses a named event type `"loop"`. Use `addEventListener("loop", handler)`. `onmessage` only fires for unnamed events and will silently miss all weather data updates.

**Never implement manual SSE retry logic.**
The browser `EventSource` API reconnects automatically. Manual retry logic duplicates reconnect behavior and can cause double-subscriptions.

**Never pass raw loop packet field names to components.**
Apply `WEEWX_TO_OBSERVATION` field mapping on merge. Components receive observation field names, not weewx internal names.

**Never share data fetches between cards via page-level props.**
Each card owns its data. A card that needs archive data calls `useArchive` internally with its own parameters (`fields`, `aggregate_interval`, time window). Pages do not fetch archive data and pass it down. This keeps cards self-contained — a developer working on one card does not need to understand or coordinate with the page's data plumbing. Cards that only need a sparkline should use `aggregate_interval` to downsample; cards that need accurate peaks/sums (e.g. today's hi/lo) fetch raw records. Shared hooks like `useRealtimeObservation` (SSE-backed, singleton connection) are the exception — those are inherently global.

**Never read page visibility from the API.**
Page visibility is a static config (`/pages.json`) served by Caddy. The API's `GET /pages` returns all 9 built-in pages unconditionally — it does not filter. The dashboard reads `/pages.json` at boot and filters navigation and routes locally. Do not add API logic for page hiding.

**Never bypass the card plugin contract on the Now page.**
All Now page cards must conform to the card plugin contract (§8). Do not add cards to the Now page by directly importing components and passing specific props — use the card registry and data bag pattern. The Now page container does not know what data each card needs.

**Never use `new Date()` to determine station-local date or time.**
`new Date()` returns the visitor's browser-local time, not the station's time. Use `stationClock.date` from the API response for all date-boundary logic. `Date.now()` is approved for UTC epoch elapsed-time math and display ticks (arc position updates, "last updated N seconds ago") — mark those uses with `// ADR-075: display tick, not data refresh`.

**Never use `.toISOString().split('T')[0]` to derive a station-local date.**
`toISOString()` returns UTC. Splitting it at `'T'` gives a UTC date, which differs from the station-local date near midnight. Use `stationClock.date` from the API response instead.

**Never use array index as a proxy for "today" in forecast or date-ordered lists.**
`index === 0` means "first in the array," not "today." When the provider has already rolled to tomorrow's forecast, the first entry is tomorrow, not today. Compare `entry.validDate === stationClock.date` using `isStationToday()` from `utils/station-clock.ts` instead.

**Never hardcode `setInterval` for data refresh without referencing freshness.**
Each API response carries `freshness.validUntil` (when to refetch) and `freshness.refreshInterval` (the data type's update cadence). Use these fields to drive refresh timing via `useApiQuery`. Magic numbers like `60_000` or `300_000` in a data-refresh `setInterval` are a violation.

**Never use `Date.now()` for "is it daytime?" checks outside station-clock utilities.**
Daytime status comes from the scene descriptor or `stationClock`, not browser-local time. Any daytime determination that does not use the station timezone or `stationClock` is a banned pattern.
