---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-024: Dashboard page taxonomy and navigation

## Context

The 12-category content walk ([CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md)) was organized by *content* rather than Belchertown's existing page placement so the new taxonomy could be synthesized fresh. This ADR locks the page list, default content per page, and the navigation model. Companion to [ADR-009](ADR-009-design-direction.md) (the *how*); this ADR is the *what*.

## Options considered

| Option | Verdict |
|---|---|
| A. Belchertown's existing taxonomy (Home / Graphs / Marine / Records / Reports / About) | Rejected — misses Almanac and Earthquakes; doesn't reflect walk decisions. |
| B. Single dashboard with collapsible/tabbed sections | Rejected — conflicts with [ADR-009](ADR-009-design-direction.md) multi-page direction. |
| C. Built-in pages from walk synthesis + operator-defined custom pages, each built-in hide-able | **Selected.** |
| D. Same as C but with Marine | Rejected — cat 7 deferred (no provider in day-1 set covers enough of the marine surface). |

## Decision

**Nine built-in pages plus a custom-page mechanism.** Each built-in is hide-able per operator config. Pages, in default navigation order:

| # | Page | Route | Lucide icon |
|---|---|---|---|
| 1 | Now (home) | `/` | `house` |
| 2 | Forecast | `/forecast` | `cloud-sun-rain` |
| 3 | Charts | `/charts` | `chart-line` |
| 4 | Almanac | `/almanac` | `moon` |
| 5 | Earthquakes | `/earthquakes` | `activity` |
| 6 | Records | `/records` | `trophy` |
| 7 | Reports | `/reports` | `file-text` |
| 8 | About | `/about` | `info` |
| 9 | Legal | `/legal` (also linked from footer) | `scale` |

**Custom pages** appear after Reports, before About. Operator picks slug + name + Lucide icon (from a curated subset, ~50–80 icons; final set is Phase 3 design) + nav position + content blocks (canonical cards + operator-authored markdown narrative + custom charts/records/media).

**Marine** is NOT shipped at v0.1 (cat 7 deferred). Slot exists between Earthquakes and Records for future addition.

**Configuration UI** is NOT in this taxonomy — separate process per [ADR-027](ADR-027-config-and-setup-wizard.md).

### Per-page content (default)

Sensor-availability self-hide applies to every card (cat 10): cards self-hide when their backing data has no non-null aggregate over the visible period. When all cards on a page hide, the page itself self-hides from nav.

**1. Now (`/`)** — current-conditions hero (operator-uploadable photo, current outTemp primary, condition + feels-like secondary), active alert banner (when present), Today's Highlights (today's hi/lo + peak gust + rain so far + peak AQI + records-broken-today), Wind tile (animated compass + speed/gust + Beaufort), Station observations tile (locked default 8: barometer + 3-hr trend, dewpoint, outHumidity, rain combined, heatindex, windchill, radiation, UV; indoor temp/humidity off by default), Sun & Moon mini-tile, AQI tile (half-gauge + main pollutant), Lightning tile (1h/24h count + nearest distance + storm-phase badge + yellow accent if strike <5 min), Earthquake tile (most recent within radius), Today's forecast card (provider-adaptive narrative + hi/lo + precip% + condition icons through the day), Webcam/Timelapse/Radar tabs (only configured tabs render), homepage chart panel (default `homepage` group with 1d/3d/7d/30d/90d range selector + "View all charts →" link).

**2. Forecast (`/forecast`)** — active alert banner header strip, hourly forecast (scrollable strip; provider-adaptive 1h or 3h), daily forecast (7-day default, extending if provider supplies more; per-day icon + day-of-week + condition + hi/lo + precip% + wind), forecast discussion / narrative tile (operator-toggled, off by default; renders NWS AFD or equivalent prose when provider supplies it), forecast freshness indicator.

**3. Charts (`/charts`)** — tabbed; one tab per chart group. Default tabs: `homepage` (default selected: Temperature, Wind+Direction, Wind Rose, Rain, Barometer, Solar+UV, Lightning, AQI), `averageclimate`, `monthly`, `ANNUAL`, then operator-defined custom groups in operator-set order. `Tropical_Storm_Hilary` does NOT ship as built-in (cat 9 — example operators recreate via the custom-chart system). Per-tab features: time-range navigator, range-selector buttons (1d/3d/7d/30d/90d for `homepage`), year/month dropdowns for `monthly` + `ANNUAL`, hover tooltip + clickable legend, PNG + CSV export, `page_content` markdown narrative slot above charts.

**4. Almanac (`/almanac`)** — Sun details (civil twilight, rise/transit/set, azimuth/altitude/RA/declination, total daylight + delta vs yesterday, next equinox, next solstice — Skyfield-computed per [ADR-014](ADR-014-almanac-data-source.md)), Moon details (rise/transit/set, azimuth/altitude/RA/declination, phase name + % full, next full moon, next new moon), year-long sunrise/sunset chart, year-long daylight chart, moon-phase calendar (month grid). Phase 6+: planets visible tonight, eclipses, meteor showers, conjunctions, twilight times table.

**5. Earthquakes (`/earthquakes`)** — recent earthquakes list (last 7 days within configured radius, sortable by time/magnitude/distance), embedded map (Leaflet + OSM per [ADR-015](ADR-015-radar-map-tiles-strategy.md), markers sized by magnitude), provider-specific extras when supplied (e.g., GeoNet Mercalli intensity, ReNaSS regional detail), settings summary.

**6. Records (`/records`)** — sortable HTML data table grouped by section (Temperature 8 rows, Wind 2, Rain 6, Humidity 4, Barometer 2, Sun 2 gated on radiation/UV, AQI gated on AQI columns, Inside Temp gated on operator config default-off, Custom records via cat 10 mechanism). Default columns YTD | All-Time + year selector. "Broken in last 30 days" badge on freshly set records. Operator markdown narrative slot above the table.

**7. Reports (`/reports`)** — year/month dropdowns populated from `NOAA-*.txt` files actually present (no empty options), HTML-parsed table as default rendered view (parses fixed-width text → sortable responsive table; high/low rows highlighted), "Download .txt" link for canonical file. **Setup-time precondition:** dashboard checks for `/NOAA/*.txt` at startup; if absent, page self-hides + configuration UI prompts operator to enable the weewx NOAA generator. Enhanced template ships in stack repo with annotation "Generated locally; not an official NOAA / NWS / NCEI product"; 9 added fields beyond weewx default; auto-omits sensor-absent columns.

**8. About (`/about`)** — operator-authored markdown (matches Belchertown's user-authored model). Setup wizard pre-populates a starter from collected fields (station name, lat/lon, altitude, hardware free-text). Operator edits freely via configuration UI editor. Image embeds require alt text at upload per [coding rules §5.5](../../rules/coding.md). Posted-to-aggregator list and Credits list are operator-authored markdown (no preset platforms, no auto-generation; setup wizard offers a "paste my configured providers" helper).

**9. Legal (`/legal`)** — boilerplate legal/privacy text shipped pre-customized for Shane Burkhardt / weather.shaneburkhardt.com (this project is being written for them first); future operators modify or replace based on their jurisdiction. Setup wizard requires explicit acknowledgment checkboxes for: legal/privacy text content, analytics tracking compliance, social/third-party embed compliance. Per-jurisdiction toggleable sections (California / GDPR / Quebec Law 25). Privacy Policy text auto-updates to match the configured analytics provider.

### Custom pages (operator-defined)

- Configuration UI offers "Add Custom Page" action.
- Operator picks: route slug (validated unique), display name (localizable), Lucide icon (curated subset), nav-bar position.
- Operator composes from: any canonical built-in cards (drag-and-drop or pick-list), markdown narrative blocks, custom charts (cat 9), custom records (cat 10), embedded media.
- Reorderable, renamable, hide-able, deletable.
- Persists in operator config per [ADR-027](ADR-027-config-and-setup-wizard.md).

### Navigation

Per [ADR-009](ADR-009-design-direction.md) — icon-rail on desktop (left), bottom-nav on mobile. Active page = background shift + accent line. Skip-to-main-content at top.

**Default desktop rail order:** `Now` · `Forecast` · `Charts` · `Almanac` · `Earthquakes` · `Records` · `Reports` · *custom pages* · `About`.

**Footer:** `Legal/Privacy` (always), `© year station-name`, `Powered by Clear Skies` (hideable).

**Mobile bottom-nav:** ≤ 5 slots; if more pages exist, 5th slot = `More` opening an overflow sheet.

**Hide-able per operator:** every built-in page can be turned off via configuration UI. Off-pages don't appear in nav and their routes return 404. Custom pages similarly. `Now` cannot be unchecked (home is always present).

## Consequences

- Phase 3 routing scaffold has a concrete page list to wire.
- Configuration UI scope ([ADR-027](ADR-027-config-and-setup-wizard.md)) gains: per-built-in-page hide toggles, custom-page management UI (add/reorder/rename/hide/delete), per-tile hide toggles within pages.
- Sensor-availability rendering (cat 10) operates at card level; page self-hides when all its cards hide.
- Custom-page system ships in v0.1 (real Phase 3 work — drag-and-drop card composition or structured pick-list).
- Custom chart groups appear as Charts-page tabs; custom records appear as Records-page section; custom pages are top-level routes — three surfaces, one consistent operator-extension pattern.
- Marine page can be added later without disturbing the taxonomy — slot reserved.

### Trade-offs accepted
- Nine routes is more than Belchertown's six. Mitigated by hide-able pages.
- No Marine at v0.1 disappoints coastal-station operators. Per cat 7; revisit when provider gap closes.
- Configuration UI is NOT in public nav — operators looking for a settings cog won't find one. Documentation must be clear it's a separate URL/process.

## Implementation guidance

### Routes (`weewx-clearskies-dashboard/src/routes/`)

`now.tsx` (`/`), `forecast.tsx` (`/forecast`), `charts.tsx` (`/charts` tabbed), `almanac.tsx`, `earthquakes.tsx`, `records.tsx`, `reports.tsx`, `about.tsx`, `legal.tsx`, `custom-page.tsx` (`/:slug` — handles operator-defined pages dynamically), `not-found.tsx` (404 for hidden/nonexistent routes).

Routes registered at runtime from operator config so hidden pages return 404, not just "not in nav but still reachable."

### Custom-page config schema shape

Operator config (per [ADR-027](ADR-027-config-and-setup-wizard.md)) names: `slug`, `name`, `icon`, `nav_position`, `hidden`, plus content-block subsections (markdown narrative, canonical cards by `type`, custom charts/records). On-disk syntax is a Phase 2 contract; this ADR fixes the *shape* (operator picks slug + name + icon + nav position + content blocks).

### Reports page setup-time check

At dashboard startup, the api service checks: does `/NOAA/` directory exist on the configured weewx report directory, and contain ≥ 1 `NOAA-*.txt` file? If both true, Reports page enabled and dropdowns populate. If false, page hides and the configuration UI displays a "Reports page is hidden because the weewx NOAA generator is not enabled" message with doc link.

## Out of scope
- Per-page card layout (which card goes where in the visual grid) — Phase 3 design.
- Curated Lucide subset for custom-page picks — Phase 3 design.
- Drag-and-drop UX for custom-page composition — Phase 3.
- Mobile bottom-nav overflow design beyond "≤ 5 slots, More for the rest" — Phase 3.
- Configuration UI page-management UX — [ADR-027](ADR-027-config-and-setup-wizard.md) scope.

## References
- Related: [ADR-002](ADR-002-tech-stack.md), [ADR-009](ADR-009-design-direction.md), [ADR-010](ADR-010-canonical-data-model.md), [ADR-011](ADR-011-multi-station-scope.md), [ADR-014](ADR-014-almanac-data-source.md), [ADR-015](ADR-015-radar-map-tiles-strategy.md), [ADR-022](ADR-022-theming-branding-mechanism.md), [ADR-023](ADR-023-light-dark-mode-mechanism.md), [ADR-026](ADR-026-accessibility-commitments.md), [ADR-027](ADR-027-config-and-setup-wizard.md).
- Walk: [CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md), [DESIGN-INSPIRATION-NOTES.md](../reference/DESIGN-INSPIRATION-NOTES.md), [BELCHERTOWN-CONTENT-INVENTORY.md](../reference/BELCHERTOWN-CONTENT-INVENTORY.md).
