# C0 — Page Inventory (Track C work list)

**Status:** Research note (not a decision record). Produced 2026-05-28 for the UI redesign roadmap
([UI-REDESIGN-PLAN.md](../planning/UI-REDESIGN-PLAN.md) item **C0**). Inventory only — **no card design**.
**This document defines the full Track C work list.** Each page below becomes a per-component
mini-cycle (prior-decision check → data inventory → composition → mockup → ADR → exec plan).

**Inputs:** ADR-024 page taxonomy (+ 2026-05-27 amendment), the existing Phase-2 dashboard at
`repos/weewx-clearskies-dashboard/`, the live Belchertown skin (`skins/Belchertown/` + the
2026-04-29 server snapshot), `docs/ARCHITECTURE.md` API surface, and the inspiration synthesis
([inspiration/NOTES.md](inspiration/NOTES.md)).

**Method:** one research agent per surface across three sources — (a) what Belchertown does today,
(b) what the existing dashboard + ADRs already implement, (c) candidate cards — plus a Belchertown
feature census and a completeness cross-check against ADR-024 and every `/api/v1/*` endpoint.

---

## ⚠️ The single most important finding: the redesign is a *re-skin of an existing build*, not greenfield

**Every page in the taxonomy already exists and is implemented** in `weewx-clearskies-dashboard`
(Phase-2 work): 11 React routes + global chrome + ~14 Now-page cards + working Forecast/Charts/
Almanac/Seismic/Records/Reports/About/Legal pages. Per the roadmap's "don't throw the baby out with
the bathwater" discipline, Track C's job for almost every surface is to **consciously re-affirm or
depart from an existing implementation + ADR decision — never silently rebuild.** The card set and
data wiring are largely **locked by ADR-024**; ADR-024 explicitly defers **per-card visual layout to
Phase 3 design** — so *layout/treatment is the open part, the card inventory mostly is not.*

---

## Scope — UI-only, on a proven foundation

**The data flow and overall architecture are settled and proven.** Phases 1–4 + the Config-UI/deploy
phase are complete ([CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md)); the API, the realtime
BFF, the provider modules, unit conversion (ADR-042), SSE live updates, the `/api/v1/*` endpoint
surface, and the `/pages` config model all exist and passed a phase-boundary ADR-compliance sweep
(26 gaps, all resolved 2026-05-22). **This redesign is a presentation-layer effort only.**

Operating rules that follow from that:
- **Respect how data is obtained.** The redesign changes how existing data is *displayed, composed,
  and styled* — not how it is fetched, converted, or wired. The dashboard's data hooks
  (`useRealtimeObservation`, `useForecast`, `useAlmanac`, …), the ConvertedValue contract (ADR-042),
  and the BFF-computed fields (`weatherText`/`comfortIndex`/`beaufort`, ADR-044) are inputs to design,
  not things to re-architect. No new endpoints or data-flow changes inside Track C.
- **"Not built" ≠ "redesign builds it from new data."** Where a candidate card needs data that does
  not exist today (per-pollutant AQI depth, expandable-forecast-column detail, month-to-date
  aggregates), that is a **data/API question routed to the master plan**, not a UI-redesign change.
  The redesign designs *around the data that exists*; the plan decides whether to add data.
- **Correct the ADRs to match the as-built code.** The 2026-05-19/22 sweep checked *ADR → code*
  (is the ADR implemented?). The redesign adds the reverse: *code → ADR* (does the ADR still describe
  what was built?). See **"ADR / architecture reconciliation"** below — this is step 0 of every
  per-component cycle and a tracked master-plan task.

---

## Authoritative page list

ADR-024 defines **9 built-in pages + operator custom pages + 404**, plus a **reserved (not-shipped)
Marine slot**. Confirmed against `src/App.tsx` (route strings are live).

| # | Page | Live route | Built? | Belchertown analog | Governing ADR(s) |
|---|------|-----------|--------|--------------------|------------------|
| 1 | **Now / Home** | `/` | ✅ (~14 cards) | Home page (single scroll) | 024, 044, 041/042, 013, 015, 016, 014, 040, 022/023, 026 |
| 2 | **Forecast** | `/forecast` | ✅ | Forecast *section* on home | 024, 007, 042, 016, 020/021 |
| 3 | **Charts** | `/charts` | ✅ (temp only) | Graphs page (Highcharts) | 024, 009, 041/042, 002, 020/021, 026 |
| 4 | **Almanac** | `/almanac` | ✅ (7 cards) | `celestial.inc` widget | 024(+amend), 014, 009, 020, 042, 026 |
| 5 | **Seismic** | `/seismic` | ✅ | Home *widget* (most-recent quake) | 024(+amend), 040, 046*(Proposed)*, 010, 015 |
| 6 | **Records** | `/records` | ✅ | Records page (static table) | 024, 010, 042/041, 020, 026 |
| 7 | **Reports** | `/reports` | ✅ (rich) | Reports page (raw NOAA text) | 024, 042 |
| 8 | **About** | `/about` | ✅ (4 cards) | `about.inc` | 024 §8, 026, 027/038a, 020 |
| 9 | **Legal / Privacy** | `/legal` | ✅ | `legal.inc` | 024, 006, 003, 021, 026 |
| — | **Custom pages** | `/:slug` | ✅ (markdown-only) | *no equivalent* | 024, 027, 009, 026 |
| — | **404 / not-found** | `/*` | ✅ (bare) | *none (web-server 404)* | 024, 026 |
| — | **Global chrome** (shell/nav/footer/theme/alert/setup-guard) | all routes | ✅ | header/footer/nav + theme toggle | 024, 009, 022, 023, 021, 026, 016, 027, 044 |
| ⏸ | **Marine** (tides/surf) | *reserved slot* | ❌ deferred | `marine.inc` (Surf-Forecast + TidesPro) | 024 (cat 7 deferred) |

> **`docs/ARCHITECTURE.md` is stale:** its "Dashboard pages" table lists `/earthquakes`. The live
> route is `/seismic` (ADR-024 amendment 2026-05-27); the **API path** stays `/api/v1/earthquakes`.
> Recommend a one-line fix to ARCHITECTURE.md (separate from this note).

---

## Cross-cutting findings the redesign must resolve up front

These cut across multiple pages and should be settled (mostly in Track A ADRs or quick amendments)
before the per-page Track C cycles lean on them.

1. **Condition×theme background — NOTES vs ADR-009 conflict.** NOTES locks a full-bleed
   condition-keyed photographic background **behind everything (global)**; **ADR-009 currently scopes
   hero imagery to the Now page only.** This is a live contradiction. → Track A2 (background system)
   must resolve global-vs-Now and likely amend ADR-009. *Not yet wired anywhere today.*
2. **Charting library drift: Recharts, not ECharts.** NOTES deferred item #3b and some ADR prose
   reference **ECharts + Tremor**; the shipped dashboard uses **Recharts**. The "scenic image behind
   charts" idea (img-27, gate **B2**) must be verified against **Recharts**, and ADR text corrected.
3. **Now: two signature cards are NOT built.** The **today's-temperature curve** (img-23 model) is a
   *static decorative SVG placeholder* (no real chart), and the **ADR-024 homepage chart panel**
   (1d/3d/7d/30d/90d) is only a link to `/charts`. These are **net-new**, not regressions — C1 builds
   them. The **wind compass** *does* exist (custom SVG) — img-17 is an *enhancement* of it, not a
   from-scratch build (C2).
4. **Now: Webcam/Timelapse/Radar — model mismatch.** ADR-024 specifies **one tabbed tile**
   (only-configured-tabs render); the build ships a **separate Radar card + separate Webcam card**.
   Reconcile in C1/C6.
5. **Records: structural mismatch.** ADR-024 wants **one sortable table, YTD | All-Time side-by-side
   columns + year selector**; the build renders **one Card per section, single period at a time
   (selector), not sortable**, plus a **"Today" column** that ADR-024 does not mention. The
   inside-temp / custom-records removal (recent records work) **appears to contradict ADR-024**
   (which lists Inside Temp default-off + Custom via cat-10). → reconcile before C4-adjacent work.
6. **ADR-046 (fault overlay) is Proposed but already implemented** — and the build includes fault
   **popups + slip-type styling** which ADR-046 explicitly scopes *out*. Implementation has run ahead
   of an unaccepted ADR. → confirm ADR-046 status before treating the Seismic fault layer as locked.
7. **Nav is a hardcoded array, not `/pages`-driven.** ADR-024 mandates **runtime-registered routes
   from operator config** (hidden pages → 404, custom pages dynamic, provider-gated self-hide).
   `NavRail` uses a static 9-item array and does **not** consume `GET /pages`. Affects custom pages,
   page-hide, and self-hide across the whole shell.
8. **Markdown is rendered as plain text** on About + Legal (`whitespace-pre-wrap`), while custom-pages
   use a real markdown renderer (ReactMarkdown + remark-gfm). Belchertown's About/Legal rely on links,
   lists, and images → a rendering-policy + sanitization/alt-text decision is needed.

---

## ADR / architecture reconciliation to as-built code

The data/architecture foundation is settled — but some ADRs and `ARCHITECTURE.md` describe an
*intended* state that the implementation diverged from. **Any ADR that can impact the UI must be made
complete and accurate against the current code first.** Per `rules/clearskies-process.md`, ordinary
corrections **edit in place → status flips to Proposed → user re-approves** (only a *fundamentally
distinct* decision gets a superseding ADR).

This is owned by **Track A0 — the ADR reconciliation gate** (see
[UI-REDESIGN-PLAN.md](../planning/UI-REDESIGN-PLAN.md)): a foundational task that **precedes A1 and
all component design**. A0 fixes the known divergences below *and* verifies the wider UI-impacting ADR
set (013/014/015/016/020/021/022/023/026/040/041/042/044) is accurate vs code. Each per-component
cycle then re-checks its own component's ADR as step 0 (the prior-decision check), but the systemic
accuracy pass happens up front in A0 — not deferred.

| Divergence (code vs record) | Record to reconcile | Likely resolution |
|---|---|---|
| Dashboard charts use **Recharts**; ADR/NOTES prose says **ECharts + Tremor** | ADR-002 tech stack + NOTES.md #3b | Correct prose to **Recharts**; re-check img-27 (chart background) against Recharts (B2) |
| Live route is **`/seismic`**; route table says `/earthquakes` (API path unchanged) | `docs/ARCHITECTURE.md` dashboard-routes table | One-line fix to `/seismic` |
| Fault overlay **built** (incl. fault popups + slip-type styling) | ADR-046 (**Proposed**, and scopes those popups *out*) | Accept ADR-046 + amend scope to match build, **or** trim code to ADR |
| Records: one-period selector + **"Today" column**; ADR says YTD\|All-Time columns + year selector | ADR-024 §6 | Reconcile column model; decide "Today" column keep/drop |
| Webcam/Timelapse/Radar shipped as **split cards**; ADR says one **tabbed** tile | ADR-024 §1 | Reconcile tabbed-vs-split |
| Inside-temp + custom-records **apparently removed**; ADR lists both (Inside Temp default-off, Custom cat-10) | ADR-024 §6 | Confirm intent; correct ADR if removal is final |
| Hero/background **Now-only** (ADR-009) vs NOTES **global** background | ADR-009 (forward-looking, via A2) | Resolve in Track A2; amend ADR-009 |

> The first three are pure as-built corrections (do them regardless of redesign outcome). The Records,
> Webcam, and background rows are reconciliations whose answer is *part of* the relevant Track C
> decision — resolve them inside that component's ADR, not separately.

---

## Per-page inventory

For each page: **B** = current Belchertown · **CS** = existing Clear Skies build + ADR intent ·
**Candidate cards** (name + purpose + data; *no design*) · **Re-affirm/Depart flags** · **Open Qs**.
"⬚" marks a candidate card that is **not yet built** (net-new or a known gap).

### 1. Now / Home — `/`
- **B:** single scrolling page — station/freshness header, big temp + condition sentence + inline AQI +
  feels-like + today hi/lo, wind block, station-obs table, Sun & Moon mini, Radar/Webcam/Timelapse
  tabbed widget, provider forecast (1h/3h/24h), Today + **This Month** snapshot stats, earthquake
  widget, homepage Highcharts block, operator HTML hook points.
- **CS:** `now.tsx` two-column grid with AlertBanner + ~14 cards: CurrentConditions hero, Today's
  Forecast, Today's Highlights, Wind compass (SVG), Solar/UV, Precip/Barometer, AQI half-gauge, Sun &
  Moon mini, Lightning, Recent Earthquake, **static** Temp-Trend placeholder, Radar (Leaflet, **no
  legend**), conditional Webcam. ADR-024 locks this card set; layout deferred to Phase 3.

| Candidate card | Purpose | Primary data |
|---|---|---|
| Current Conditions hero | Oversized temp + condition sentence + feels-like + icon | `/current`, `/forecast` code, `/station` |
| ⬚ Today's temperature curve | Day curve, gradient, dashed-past/solid-future, now-divider, H/L, Actual/Feels toggle (img-23) | `archive` (today) + `/current` (+forecast future leg) |
| Active Alert banner | Severe-weather strip (global element) | `/alerts` |
| Today's Highlights | hi/lo, peak gust, rain-so-far, peak AQI, records-broken-today | `useTodayStats` over `/current`+today archive |
| Wind compass | Signature dial; dir/deg + speed + gust + Beaufort *inside* the dial (img-17) | `/current` wind fields |
| Station observations tile | Per-stat grid (ADR-024 locked default 8) + plain-language sentences | `/current` |
| Precipitation | Rain today + rain rate | `/current` |
| Barometer | Pressure + 3hr trend | `/current` |
| Solar Radiation | Solar radiation W/m² | `/current` |
| UV Index | UV index + EPA category + severity bar + forecast UV peak | `/current`, `/forecast` |
| AQI tile | Half-gauge + category + main pollutant (NOTES wants per-pollutant — gated) | `/aqi/current` |
| Sun & Moon mini | Sunrise/sunset + phase + illumination% (NOTES wants arcs) | `/almanac` |
| Lightning tile | 1h/24h count, nearest distance; ⬚ storm-phase badge + <5min accent | `useLightning(/current)` |
| Recent Earthquake tile | Most-recent within radius | `/earthquakes` |
| Today's Forecast | Narrative + hi/lo + precip% + condition through day | `/forecast` daily[0] |
| Radar tile | Animated radar + controls + **color legend** (C6, 2026-06-02) | `/radar/*`, `/capabilities`, `/station` |
| Webcam / Timelapse tile | Live still + timelapse (ADR-024: one tabbed tile *with* radar) | `/webcam.json` |
| ⬚ Homepage chart panel | Default homepage group + 1d/3d/7d/30d/90d + "View all charts" | homepage chart group |
| ⬚ Station header / freshness strip | Station identity + last-updated/online (Belchertown parity) | `/station`, `/branding`, SSE state |

- **Flags:** card set + data wiring locked by ADR-024 (layout open); `weatherText`/`comfortIndex`/
  `beaufort` are BFF-computed (044/041) — consume verbatim; values are ConvertedValue (042) — no
  client unit math; EPA/UV colors WCAG-adjusted (026) — preserve; wind = enhance existing SVG, not
  replace; condition-keyed/operator-photo background is direction, not wired.
- **Open Qs:** Webcam/Timelapse/Radar one-tabbed-tile vs split? Consolidate the locked-8 obs into one
  tile vs keep split across cards (ties to per-metric audit)? AQI per-pollutant depth (provider-gated)?
  Real chart vs placeholder for today-curve + homepage panel? Where does "This Month" snapshot go
  (Records/Charts/Now)? Freshness strip = chrome or Now card? Sun/moon *arc* on Now or only Almanac?

### 2. Forecast — `/forecast`
- **B:** no dedicated page — forecast is a home-page section: 1h/3h/24h interval tabs (Aeris), current
  condition icon + summary, optional alert strip. No AFD discussion, no freshness element.
- **CS:** `forecast.tsx` fully built — AlertBanner, horizontally-scrollable **hourly strip**
  (icon/temp/precip%/wind), **7-day daily grid** (icon/hi-lo/precip%/wind/UV-max), freshness line.
  Wind unit label borrowed from live observation (042). **Discussion/AFD tile NOT built** despite
  ADR-024 + API `discussion`.

| Candidate card | Purpose | Primary data |
|---|---|---|
| Active Alert banner (strip) | Reuse shared AlertBanner at top | `/alerts` |
| Hourly Forecast strip | Icon-rich per-hour columns | `forecast.hourly[]` |
| 7-Day Daily Forecast | Per-day outlook cards (extends if provider supplies more) | `forecast.daily[]` |
| ⬚ Forecast Discussion / Narrative | NWS AFD prose; operator-toggled, **off by default** | `forecast.discussion` |
| Forecast freshness indicator | "updated {relative}" | `forecast.generatedAt` |
| ⬚ Time-range tabs (Today/Tomorrow/Week) | NOTES img-12 reorg (candidate; not in taxonomy/build) | re-sliced hourly+daily |
| ⬚ Temp trend line through columns | NOTES img-15/24/26 (hourly + weekly) | `hourly.outTemp` / `daily.tempMax/Min` |
| ⬚ Expandable columns | Click → humidity/gust/cloud/precip detail (provider-gated, img-12) | `hourly`/`daily` extras |

- **Flags:** strip+grid+freshness already built — evolve, don't rebuild; daily cards show wind **speed
  only** (no `windDir` in DailyForecastPoint) — no daily wind-circle without new data; discussion is a
  known gap, not new invention; cards self-hide on all-null (cat 10).
- **Open Qs:** time-range tabs = reorg or additive? per-provider hourly depth for expansion
  (WU has no hourly; B1 gate)? temp trend line in-scope for /forecast, Now, or both? vertical
  temp-range gradient bar (img-04) conflicts with the current card-grid layout.

### 3. Charts — `/charts`
- **B:** Graphs page + inline homepage block; Highcharts groups in `graphs.conf` — `homepage`,
  `averageclimate`, `monthly`, `ANNUAL`, `Tropical_Storm_Hilary`, `airquality`; custom-SQL series;
  tooltips + clickable legend + date ranges.
- **CS:** `charts.tsx` WAI-ARIA tabbed page, **4 hardcoded tabs, all charting ONLY `outTemp`** (temp).
  Range buttons 1d/3d/7d/30d/90d, data-table toggle + sr-only mirror, **Recharts**. Tabs are static
  arrays, **not** driven by `/charts/groups`. No PNG/CSV export, no `page_content` slot, no custom groups.

| Candidate card | Purpose | Primary data |
|---|---|---|
| Chart-group tab strip | One tab per group, homepage default (ADR: data-driven from `/charts/groups`) | `/charts/groups` |
| Homepage chart group | Rolling-range multi-metric charts + range selector | `/archive` |
| Temperature chart | outTemp (+comfort series per ADR set) | `/archive` |
| ⬚ Temp day-curve w/ gradient | img-23 direction on homepage tab | `/archive` 1d + feels-like |
| Wind speed/gust + direction | windSpeed/windGust/windDir | `/archive` |
| Wind Rose | Directional frequency/intensity | `/archive` windDir+windSpeed |
| Rain | Rate + accumulated | `/archive` |
| Barometer | Pressure trend | `/archive` |
| Solar + UV | Radiation vs max + UV (sensor-gated) | `/archive` |
| Lightning | Strike count + distance (sensor-gated) | `/archive` |
| ⬚ AQI chart | AQI over period (ADR homepage default; not built) | `/archive` aqi |
| Average Climate | 12-month climatological averages | `/archive` bucketed (→ `/climatology/monthly`) |
| Monthly / Annual | Day-interval series for selected month/year | `/archive` + `station.firstRecord` |
| Data-table toggle | Accessible table per chart | same `/archive` |
| ⬚ PNG + CSV export | ADR-024 mandate; not built | current series |
| ⬚ `page_content` narrative slot | Operator markdown above charts; not built | operator config (027) |
| ⬚ Scenic chart-background | img-27, **gated on Recharts feasibility (B2)** | operator image |

- **Flags:** **Recharts not ECharts** (re-check img-27 against Recharts); only `outTemp` charted today
  (full metric set is net-new — don't present current state as target); tabs must become
  `/charts/groups`-driven (departure); `Tropical_Storm_Hilary` deliberately **not** built-in per
  ADR-024 (operators recreate via cat-9); range selector/data-table/ARIA/i18n already built — preserve.
- **Open Qs:** time-range nav per-tab vs global? one card per metric vs multi-series chart? migrate
  Average-Climate to `/climatology/monthly` server endpoint? does cat-9 cover Belchertown's
  custom-SQL expressiveness (`weatherRange`, custom rains)? `page_content` source/edit path?

### 4. Almanac — `/almanac`
- **B:** single `celestial.inc` widget — Sun + Moon tables (twilight, rise/transit/set, az/alt/RA/dec,
  daylight + delta, equinox/solstice, phase). Pure text; no arcs/charts/calendar/planets. pyephem.
- **CS:** `almanac.tsx` fully built — **7 cards**: Sun, Moon (+special moon names), Positional, Monthly
  Averages (Recharts), Planets, Lunar Eclipses, Meteor Showers. ADR-024 2026-05-27 amendment
  **promoted planets/eclipses/meteor/special-names from Phase 6+ to shipping**. Computed via Skyfield (014).

| Candidate card | Purpose | Primary data |
|---|---|---|
| Sun details | Twilight, rise/transit/set, daylight + delta, equinox/solstice | `/almanac` sun |
| ⬚ Sun arc | Sunrise→sunset arc + position marker (img-11/14) | `/almanac` sun |
| Moon details | Phase + illumination%, rise/set, next full/new, moon-name badges | `/almanac` + moon-names |
| ⬚ Moon arc | Moonrise→moonset **own arch** + glyph (NOTES item 9) | `/almanac` moon |
| Positional data | Sun+moon az/alt (⬚ RA/dec not surfaced) | `/almanac` |
| ⬚ Year-long sunrise/sunset chart | Annual rise/set curve (ADR default; not built) | `/almanac/sun-times` |
| ⬚ Year-long daylight chart | Annual daylight length (ADR default; not built) | `/almanac/sun-times` |
| ⬚ Moon-phase calendar | Month grid (ADR default; not built) | `/almanac/moon-phases` |
| Monthly climatological averages | 12-mo avg hi/lo/dewpoint/rainfall | `/climatology/monthly` |
| Planets visible tonight | Evening/morning/all-night | `almanac/planets` |
| Lunar eclipses | Date + type (color+text per 1.4.1) | `almanac/eclipses` |
| Meteor showers | Name/peak/ZHR/moon-illum | `almanac/meteor-showers` |

- **Flags:** 7 cards already built (enhance, not greenfield); current layout = vertical stack
  (departs from grid-footprint direction — decide); moon already separate card but **no arch** yet;
  3 ADR-default cards (sun/set chart, daylight chart, phase calendar) **not built**; eclipse color+text
  and moon-emoji aria patterns locked (026); Solar/UV stays on **Now**, not Almanac.
- **Open Qs:** arcs = addition / replacement / hero, and Now-vs-Almanac placement? relationship of
  Now Sun&Moon mini to Almanac cards (avoid divergent dup)? RA/dec surface + does `/almanac` return
  them? planet az/alt null in mock — Skyfield-gated; climatology behavior with <12 months history;
  polar no-rise/no-set messaging.

### 5. Seismic — `/seismic`  *(renamed from Earthquakes; API path unchanged)*
- **B:** home-page **widget** only (single most-recent local quake: time/place/magnitude/distance+
  bearing, USGS). No map, no list, no faults.
- **CS:** `seismic.tsx` fully built — two-card surface: Leaflet/OSM **map** (magnitude-sized,
  age-colored markers, station marker, **GEM fault overlay + fault popups**, fly-to) + scrollable
  **list** (mag badge, place, time, depth, source, felt, tsunami, PAGER). Bidirectional list↔map
  selection. Config info bar. **No sort controls, no per-row distance, no legend.**

| Candidate card | Purpose | Primary data |
|---|---|---|
| Seismic map | Geographic view, magnitude-sized markers | `/earthquakes`, `/station`, `/earthquakes/config` |
| Fault-line overlay (sub-layer) | GEM faults, toggle (ADR-046 **Proposed**) | `/earthquakes/faults` |
| ⬚ Map legend / key | Explain age-color + magnitude-size + faults (img-15 gap) | derived encoding |
| Recent earthquakes list | Selectable per-event list (⬚ sortable + distance per ADR) | `/earthquakes` |
| Settings / config summary | Provider/radius/min-mag/window | `/earthquakes/config` |
| Provider-specific extras | GeoNet MMI, EMSC flynn_region, USGS cdi/sig/gap (gated) | `/earthquakes` extras |
| GEM attribution line | Required CC-BY-SA credit | `/earthquakes/faults` |

- **Flags:** **use "Seismic" not "Earthquakes"**; two-card layout locked by amendment; bidirectional
  selection built; **ADR-046 Proposed but implemented — and fault popups exceed ADR-046's stated
  scope** (reconcile); markers sized-by-magnitude (ADR) / colored-by-age (impl choice); ADR-040
  single-source, no aggregation/alerts/push at v0.1; Belchertown's home most-recent-quake maps to the
  **Now Earthquake tile**, not this page.
- **Open Qs:** confirm ADR-046 status / fault-popup scope; **add legend** (card vs in-map control);
  sortable list + distance column still required for v0.1? which provider extras get a UI home;
  map sizing resolved? distance+bearing carry-over.

### 6. Records — `/records`
- **B:** single static striped table, sections Temperature/Wind/Rain/Humidity/Barometer/Sun(gated),
  **YTD | date | All-Time | date** columns; `records.inc` narrative above + `records-table.inc`
  custom rows (e.g. Inside Temp example).
- **CS:** `records.tsx` — **period selector (All-Time | YTD), one Card per section**, columns
  **Record | Today | Value | Date Observed**, "New" badge for broken-in-last-30-days. Data-driven
  sections. **Not sortable; no year selector; no narrative slot.**

| Candidate card | Purpose | Primary data |
|---|---|---|
| Period / range selector | YTD ↔ All-Time (⬚ ADR also: year selector) | client state |
| ⬚ Operator narrative slot | Markdown above table (records.inc parity) | operator config (027) |
| Temperature section | Temp-family hi/lo + ranges | `/records` Temperature |
| Wind section | Strongest gust, wind run | `/records` Wind |
| Rain section | Extremes + dry/wet streaks | `/records` Rain |
| Humidity section | Humidity + dewpoint extremes | `/records` Humidity |
| Barometer section | Pressure extremes | `/records` Barometer |
| Sun section (gated) | Radiation + UV peaks | `/records` Sun |
| ⬚ AQI section (gated) | AQI extreme (ADR; absent from API types) | `/records` AQI |
| Inside Temp section (gated, default-off) | Indoor hi/lo | `/records` Inside Temp |
| Custom records section(s) | cat-10 operator rows | `/records` operator |
| "New" badge | Broken-in-last-30-days | `RecordEntry.brokenInLast30Days` |
| Today column | Live value per record | `/observation` by canonicalField |

- **Flags:** **structural mismatch** — ADR wants one sortable YTD|All-Time table + year selector;
  build has per-section cards, single period, not sortable, single Value column; **"Today" column is
  beyond ADR-024** — keep or drop?; sections data-driven (server gates); **inside-temp/custom-records
  removal appears to contradict ADR-024** — reconcile; per-stat-icon direction is design-phase, not C0.
- **Open Qs:** one unified sortable table vs per-section cards (drives the page)? year selector + API
  support? AQI section emitted by API? inside-temp/custom intentional + final? keep a mostly-empty
  Today column? how are derived records (temp ranges, rainiest month, consecutive-rain streaks)
  represented in single `observedAt`? does API omit empty sections or must dashboard self-hide?

### 7. Reports (NOAA) — `/reports`
- **B:** dedicated page, minimal — server-rendered year/month selector + `<pre>` raw NOAA text over
  XHR. No parsing/table/sort/CSV.
- **CS:** `reports.tsx` **richer than Belchertown** — parsed **sortable** monthly table (13 cols,
  hi/lo row highlight + summary) + yearly split into Temp/Precip/Wind sub-tables; raw-text toggle;
  **.txt + .csv** download; dropdowns populated only from files present.

| Candidate card | Purpose | Primary data |
|---|---|---|
| Report period selector | Pick year + month/Annual (present files only) | `/reports` index |
| Monthly report table | Parsed sortable day-by-day + summary | `/reports/{year}/{month}` |
| Yearly report tables | Temp/Precip/Wind sub-tables | `/reports/{year}` |
| Raw text view toggle | Verbatim NOAA + parser-failure fallback | rawText |
| Download actions | `.txt` (canonical) + `.csv` (client-built) | rawText / parsed rows |
| ⬚ Local-data provenance note | "Generated locally; not official NOAA/NWS/NCEI" (ADR; not built) | static (ADR-024) |

- **Flags:** parsed sortable tables + toggle + downloads already built — re-affirm; parsed-table is
  the ADR default view (don't revert to raw-only); **CSV export has no ADR/Belchertown backing**
  (scope-keep decision); provenance disclaimer **not built**; parser coupled to stack-repo enhanced
  template (9 added fields + sensor-absent auto-omit) — track sync.
- **Open Qs:** single-card page vs split tiles? home for provenance note; self-hide when no NOAA files
  (routing/config layer); enhanced-template extra fields + sensor-absent column hiding; CSV keep vs
  scope-creep; default-report-on-no-selection behavior change intentional?

### 8. About — `/about`
- **B:** `about.inc` — webcam + station photo + hardware table; hand-authored prose (description,
  sensor list, QC note, "posted to" aggregators, credits); embedded chart.
- **CS:** `about.tsx` — 4 cards: **Station metadata (auto from `/station`)**, Operator markdown
  (`/content/about`, **plain-text** pre-wrap), Software info (static), Station-photo **placeholder**
  (no `<img>` yet).

| Candidate card | Purpose | Primary data |
|---|---|---|
| Station metadata card | Identity/location/hardware/timezone/recording-since | `/station` |
| Operator About narrative | Free-form operator prose (core of page) | `/content/about` |
| Software / powered-by card | weewx + Clear Skies + engine | static i18n |
| Station photo / webcam card | Operator photo (⬚ image source TBD) | operator asset |
| Sensor readings list | Observations the station reports | *inside* markdown (ADR §8) or `/capabilities` |
| Posted-to / data-sharing list | Aggregators published to | *inside* markdown (ADR §8) |
| Credits / attributions list | Third-party data sources | *inside* markdown (ADR §8) |

- **Flags:** 4 cards built; ADR §8 locks About as **operator-authored markdown** (sensor/posted-to/
  credits are markdown sub-sections, *not* data-driven cards); station-metadata auto-card is an
  addition beyond Belchertown; photo is placeholder (alt-text required at upload, 027); **markdown is
  plain-text rendered** — Belchertown relies on links/lists/images.
- **Open Qs:** real markdown renderer + sanitization/alt-text policy? keep sensor/posted/credits as
  prose vs structured? photo source + live-webcam-on-About scope? sensor list from `/capabilities`
  (departure)? Belchertown's About chart + live webcam dropped or relocated? provider-enumeration API
  for the wizard "paste my providers" helper.

### 9. Legal / Privacy — `/legal`
- **B:** static `legal.inc` — Weather Data Disclaimer + CCPA/CPRA-only Privacy Policy (Google
  Analytics, cookies, IP, CA rights). No GDPR/Quebec, no attribution-by-provider, no OSS license.
- **CS:** `legal.tsx` — operator-markdown override (`/content/legal`, plain-text) **else** default
  4-card stack: Privacy Policy, **Jurisdiction notices (CCPA/GDPR/Quebec, disclosure toggles)**, Data
  Attribution, Open-Source Licenses. All copy in i18n (13 locales).

| Candidate card | Purpose | Primary data |
|---|---|---|
| Operator Legal (markdown override) | Operator text replaces default stack | `/content/legal` |
| Privacy Policy (default) | Baseline statement (⬚ should reflect configured analytics provider) | i18n |
| Jurisdiction notices | CCPA/CPRA + GDPR + Quebec Law 25 disclosures | i18n |
| Data Attribution | Credit data sources (⬚ should be provider-driven, ADR-006) | i18n |
| Open-Source Licenses | GPL v3 + bundled OSS | i18n |
| ⬚ Weather Data Disclaimer | "Informational only / consult NWS / no warranties" (Belchertown; absent) | i18n/static or operator md |

- **Flags:** override-vs-default-stack branching built — keep; 3 jurisdiction sections locked by
  ADR-024; all copy in 13 locales (021) — update all, don't hardcode; Attribution + OSS cards are
  additions beyond Belchertown — don't drop; markdown plain-text; footer Legal link always present (global).
- **Open Qs:** wire analytics-provider auto-update (which field)? provider-driven attribution
  (which endpoint)? **Weather Data Disclaimer** home (drop/fold/new card/operator-md)? plain-text vs
  rendered (consistent with About)? when operator markdown set, do Attribution/OSS persist or get
  suppressed? wizard acknowledgment checkboxes confirmed out of scope (027).

### Custom pages — `/:slug` · 404 — `/*`
- **B:** no equivalent (fixed Cheetah pages; web-server 404). Closest analog: operator-authored About.
- **CS:** `custom-page.tsx` — `:slug` → `/pages/{slug}/content` markdown via **ReactMarkdown +
  remark-gfm** in one Card; title is **slug-derived**; falls back to 404 on any error.
  `not-found.tsx` — bare "404", **no recovery links**.

| Candidate card | Purpose | Primary data |
|---|---|---|
| Operator markdown block | Render custom-page body | `/pages/{slug}/content` |
| Page title / header | Display name (⬚ ADR: from `/pages` metadata, not slug) | `/pages` |
| ⬚ Embedded canonical card (pick-list) | Drop a built-in card onto a custom page (ADR cat) | canonical endpoints |
| ⬚ Custom chart block | Operator chart group (cat 9) | `/charts/groups` |
| ⬚ Custom records block | Operator records section (cat 10) | `/records`-derived |
| ⬚ Embedded media block | Image/media (alt text required) | operator asset |
| Page-not-found (404) | Hidden/nonexistent slug message | static i18n |
| ⬚ 404 recovery navigation | Home link / available-pages list (NOTES signal) | `/pages` or static |

- **Flags:** custom-page is **markdown-only**; ADR-024's multi-block composition (canonical cards +
  charts + records + media) is **not built** ("real Phase 3 work" — decide v0.1 scope); title
  slug-derived not `/pages`-metadata; 404 has no recovery; **all errors collapse to 404** (mislabels
  500/network); runtime route registration not implemented (reactive 404 only).
- **Open Qs:** v0.1 markdown-only vs multi-block composition (gates most cards)? **contract gap** —
  `/pages/{slug}/content` not in OpenAPI v1; consume `/pages` for title/icon/true-404? 404 recovery
  affordance? distinct error state vs 404?

### Global chrome (app shell) — all routes  *(Track C is cross-cutting — this is in scope)*
- **B:** horizontal header (logo/title + nav: Home/Graphs/Marine/Records/Reports/About) + 2-state
  light/dark slider; `page-header.inc` (temp + condition + H1 + powered-by + social share); 3-col
  footer; back-to-top; Google Analytics; PWA manifest; kiosk/pi variants; last-updated alert.
- **CS:** **fully built shell** — `AppLayout` (SkipLink + NavRail + Outlet + Footer); `NavRail`
  (**hardcoded 9-item** array, Lucide icons, desktop rail + mobile 4-slots + "More" sheet);
  `Footer` (Legal + ©year + Powered-by + share row Reddit/X/FB/Pinterest/copy); `theme-toggle`
  (**3-state** system→light→dark); `theme-provider` (4 modes incl. auto-sunrise-sunset/auto-os);
  `branding-provider` (`/branding` → CSS vars/title/favicon); `SetupGuard` (`/status`→`/wizard`);
  `error-boundary`; `alert-banner`. **No condition background layer; no locale switcher; no `/pages`-
  driven nav.**

| Candidate element | Purpose | Primary data |
|---|---|---|
| Navigation rail / bottom-nav | Persistent nav, active indication (⬚ ADR: `/pages`-driven) | `/pages` (static today) |
| App shell / layout | Skip-link + nav + main + footer; responsive reflow | structural |
| Brand logo slot | Operator logo (light/dark + invert fallback) | `/branding` |
| Theme control (3-state) | Visitor override of operator default | ThemeProvider + localStorage |
| Global alert banner | Highest-priority alert, severity aria-live | `/alerts` |
| Footer | Legal + © + Powered-by (⬚ hideable) + share row | `/branding`, `/station` |
| Skip-to-main link | WCAG 2.4.1 | i18n |
| Setup guard | Redirect to `/wizard` when unconfigured | `/status` |
| Global error boundary | Reload-recovery UI on render crash | caught error |
| Branding/theme providers | Apply accent vars/title/favicon + resolve theme | `/branding`, `/almanac` |
| ⬚ Condition×theme background layer | Full-bleed photographic, operator-replaceable (NOTES) | ADR-044 condition + theme + asset |
| ⬚ Locale switcher | Change UI language (13 locales) — no UI today | i18next |
| Mobile "More" sheet | Overflow nav + theme row | overflow items |

- **Flags:** **nav hardcoded, not `/pages`-driven** (ADR mandates runtime registration); Seismic
  rename reflected; 3-state theme + auto modes locked (023) — don't regress to 2-state; share set
  hardcoded (Belchertown social config not carried); **Powered-by not hideable yet** (ADR says
  hideable); accent = curated 6-name palette (022) — no free-form color; SetupGuard/ErrorBoundary
  load-bearing; **hero/background Now-only per ADR-009 vs NOTES global — conflict**.
- **Open Qs:** background global vs Now-only? `/pages`-driven nav + custom-page + self-hide wiring?
  locale switcher in scope + where? Powered-by hide toggle source? configurable nav-label visibility
  still intended? back-to-top / GA / PWA manifest / kiosk / page-stale-banner in new shell? alert
  banner rendered once globally or per-page (avoid double-render)? dynamic custom-page icons.

---

## Orphan Belchertown features — triaged (UI vs plan)

Belchertown features with no settled Clear Skies home. Each is routed per your instruction: **UI-only
items stay in this redesign's work list; anything not UI-specific moves to the master plan**
([CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md)), and items the plan already tracks are noted
so we don't duplicate.

**A — stays in the UI redesign** (pure presentation; no new data/architecture):

| Feature | Where it lands in Track C |
|---|---|
| Social share buttons | Global chrome (C12) — footer already has a fixed share row; decide configurable vs fixed |
| Back-to-top button | Global chrome (C12) — minor scroll affordance |
| Weather Data Disclaimer (Legal) | Legal page (C14) — content/copy decision (drop / fold into Privacy / new card / operator md) |
| Page-stale **indicator** (the UI banner) | Global chrome (C12) — *surfaces* staleness; the detection mechanism is a plan item (below) |
| "This Month" snapshot **placement** | Now / Records / Charts UI — *where* it shows; the aggregate data is a plan item (below) |

**B — moved to the master plan** (not UI-specific — data/architecture/capability/feature decisions):

| Feature | Why it's not UI | → tracked in plan as |
|---|---|---|
| Customizable card **GRID** / layout engine | Layout persistence + responsive engine + per-operator state | Backlog: grid engine (own plan + ADR) |
| Pi / `kiosk.html` display modes | Separate MQTT host, deploy/display mode, not presentation design | Backlog: kiosk decision (drop/defer) |
| Marine page (tides/surf) | Needs a marine data provider before any UI | Backlog: deferred page (ADR-024 reserved slot) |
| Page-stale detection **mechanism** | Data-freshness / SSE-fallback / refresh policy (realtime/data layer) | Backlog: staleness mechanism |
| "This Month" month-to-date **aggregates** | New endpoint shape vs query param — an API/data question | Backlog: MTD aggregate data |
| Operator home-page content injection | Content-block composition + HTML sanitization/security capability | Backlog: Now-page content-slot capability |

**C — already tracked in the plan** (no action here):

| Feature | Plan location |
|---|---|
| PWA manifest / installable | Phase 6 (optional) |
| Belchertown → Clear Skies production cutover | Phase 5 |
| `/pages` hide/show + custom-page API | Phase 2/3 (built) — *wiring NavRail to it is the UI gap, C12* |

**Endpoint coverage:** all 24 `/api/v1/*` data endpoints map to at least one card (incl. the
2026-05-27 additions: `/climatology/monthly`, almanac planets/eclipses/meteor-showers).
`/api/v1/capabilities` is correctly **plumbing** (drives cat-10 self-hide), not a page card.
`/api/v1/branding` is consumed by the shell providers. No ADR-024 page is missing.

---

## Track C work list (sequenced)

Maps the roadmap's C1–C6 to the inventory, and surfaces work the roadmap had not yet named.
**Each item runs the per-component cycle** (prior-decision check → B1 data inventory → composition →
mockup → ADR → exec plan). Most are **re-skin/enhance an existing build**, not greenfield.

| Track C item | Surface(s) | Build state | Key dependency |
|---|---|---|---|
| **A0** | **ADR reconciliation gate — make UI-impacting ADRs complete & accurate vs code** (precedes A1) | records lag code | see reconciliation table above |
| **C1** | Now: Current-conditions hero **+ today's temp curve** (img-23) | curve net-new (placeholder today) | A1/A2; **B2** (Recharts bg) |
| **C2** | ⭐ Wind compass (img-17) | exists (SVG) — enhance | A1 |
| **C3** | Forecast screen (icon columns, tabs, trend line, expandable) | exists — evolve; discussion + tabs net-new | A1; **B1** provider depth |
| **C4** | Per-metric stat treatment + detail grid | exists (split across cards) — per-metric audit pending | A1; per-metric audit (NOTES #5) |
| **C5** | Sun & Moon arcs + moon phase | text today — arcs net-new | A1; Now-vs-Almanac placement |
| **C6** | AQI card (per-pollutant) + radar legend | AQI exists; legend net-new (gap) | **B1** AQI depth; B3 |
| **C7 (new)** | Homepage chart panel on Now | placeholder only — net-new | A1; charts work |
| **C8 (new)** | Records page model (sortable table vs cards; year selector) | exists — structural reconcile vs ADR-024 | reconcile inside-temp/custom |
| **C9 (new)** | Charts page: full metric set + `/charts/groups`-driven tabs + export | only outTemp today | **B2**; cat-9 |
| **C10 (new)** | Almanac: year-long charts + moon-phase calendar | not built (ADR defaults) | A1 |
| **C11 (new)** | Seismic: legend + sortable list + distance; confirm ADR-046 | exists — gaps + ADR status | ADR-046 acceptance |
| **C12 (new)** | Global chrome: condition background, `/pages`-driven nav, locale switcher, footer hideable | shell exists — several gaps | **A2**; ADR-009 conflict |
| **C13 (new)** | Custom-page composition scope (markdown-only vs multi-block) + 404 recovery | markdown-only today | contract gap |
| **C14 (new)** | Content rendering policy (markdown vs plain-text) for About/Legal | plain-text today | sanitization/alt-text |

**Data-gated rows — designed around existing data, not built from new data.** Where a row needs data
that does not exist today, the *UI* designs around what the providers/API supply now; adding the data
is a **master-plan** decision, not a Track C change: C6 (per-pollutant AQI depth), C3 (expandable
forecast-column detail), and the "This Month" aggregates all carry this gate (see the plan backlog).

**Cross-cutting decisions to land early (Track A):** the UI-impacting ADR reconciliation (Recharts-not-
ECharts prose fix, ADR-046 acceptance, `/seismic` route, Records/Webcam in ADR-024) lands in **A0**;
the condition×theme background scope (NOTES vs ADR-009) is resolved in **A2**; `/pages`-driven nav and
the Records structural model are resolved inside their components (C12 / C8) once A0 makes the ADRs accurate.
Belchertown-feature decisions that are **not UI-specific** (grid engine, kiosk, marine, staleness
mechanism, MTD aggregate data, home-page content slots) have been **moved to
[CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md)** so they are not lost in the UI track.

---

## Self-audit (per CLAUDE.md "generate → audit → revise → deliver")

**What this note is / isn't.** It's a research note and work list — **not** a decision record and
**not** card design. No layout, styling, sizing, or visual treatment is specified; candidate cards are
named with purpose + data only. That honors C0's "inventory only" scope.

**Strengths:** every ADR-024 page + the existing build + Belchertown analog are surfaced together, so
each Track C cycle starts from prior decisions rather than redoing them; all 24 data endpoints are
accounted for; orphan features and *missing* decisions are made explicit rather than buried.

**Risks / things I may have under-weighted, surfaced for pushback:**
- **Source freshness:** the per-page detail came from agents reading the current repo + ADR-024 + the
  Belchertown snapshot. ADR *numbers/mandates* (e.g., 044's comfort matrix, 046's exact scope) were
  read from the ADRs but I did not independently re-verify every ADR clause line-by-line — treat ADR
  citations as pointers to verify at ADR-writing time, not gospel.
- **The "Recharts vs ECharts" and "Seismic route" drifts** are verified (App.tsx + the dashboard
  imports Recharts), but **ARCHITECTURE.md and some ADR prose are stale** — this note flags them; I
  did not edit those files (separate, user-authorized change).
- **Scope creep risk in the work list:** I added C7–C14 beyond the roadmap's C1–C6. These are real
  gaps the inventory exposed (homepage chart panel, charts metric set, records model, etc.), but
  several are arguably *bug-fix / completion* work rather than *redesign* — you may want to route some
  to a "finish Phase-2 gaps" track instead of the redesign track. I split them out rather than hide
  them inside C1–C6.
- **The biggest unresolved tension is #1 (global background vs ADR-009 Now-only).** It affects the
  whole visual direction and should be decided in A2 *before* much Track C styling, or C-work will be
  built against an unsettled foundation.

**Verification evidence:** route strings confirmed via `Grep` on `src/App.tsx` (lines 85–158:
`forecast/charts/almanac/seismic/records/reports/about/legal/:slug/*`; **no `/earthquakes` route**).
Existing component/route files confirmed via `Glob` on `repos/weewx-clearskies-dashboard/src/**`.
ADR-024 page taxonomy + 2026-05-27 amendment read by the census agent.

---

## Next actions (per the roadmap)

C0 is complete. The roadmap's next parallel steps:
- **A1 — Theme & color system** (Proposed ADR): root dependency for dark-mode backgrounds + all visuals.
- **A2 — Background system**: must resolve finding #1 (global vs Now-only) — possibly amends ADR-009.
- **B2 — Recharts background-image support** + **B3 — a11y-contrast / image-perf budget**: global gates.

Then walk Track C component by component using the per-component workflow.
