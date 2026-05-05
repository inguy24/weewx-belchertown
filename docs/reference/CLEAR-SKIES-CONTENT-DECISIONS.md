# Clear Skies — Content Decisions

Decisions captured during the 1-by-1 walk through the Belchertown content inventory ([BELCHERTOWN-CONTENT-INVENTORY.md](BELCHERTOWN-CONTENT-INVENTORY.md)). Walk is organized by **content category** (not by current page placement) so the new page taxonomy can be synthesized fresh. Page-placement decisions are written here as the user makes them.

Process: for each category, Claude states (a) what exists today on `weather.shaneburkhardt.com`, (b) proposed treatment, (c) open questions. User answers; this file is updated with the call.

These decisions feed:
- [ADR-009 — Design direction](../decisions/INDEX.md) (overall feel, density, hero imagery, palette)
- [ADR-024 — Page taxonomy](../decisions/INDEX.md) (which pages exist, what lives on each)
- Several other Pinned ADRs (ADR-013 AQI, ADR-014 almanac, ADR-015 radar, ADR-016 alerts, ADR-021 i18n, ADR-022 theming, ADR-023 light/dark, ADR-026 a11y) as they touch the relevant categories.

Status legend per category: ⬜ pending · 🔄 in discussion · ✅ decided · ⏸ deferred to a later ADR

## Session log

| Session | Date | Categories addressed | Notes |
|---|---|---|---|
| 1 | 2026-05-01 | 1 ✅ · 2 ✅ · 3 ✅ · 4 ✅ · 5 ✅ · 6 ✅ · 7 🔄 (questions out, no answers yet) | Categories 8–12 still pending. Category 7 questions captured below; next session resumes there. |
| 2 | 2026-05-02 | 7 ⏸ DEFERRED · 8 ✅ · 9 ✅ | Marine deferred (provider gap). Cat 8 radar landed after three research passes — provider matrix, PWS-contributor-tier scope, and gap-region pass — to correct successive parochialism errors. Cross-cutting decisions: PWS-track-as-default-lens, internal plug-in-style provider modules, no commercial defaults, install mechanism flagged as open thread feeding ADR-028/039. Two new Pinned ADR slots: ADR-038 (provider modules), ADR-039 (distribution). Cat 9 charts: ECharts engine, tabbed Charts page (drop "All" stacked view), built-in chart groups = pre-configured operator-modifiable config files, two-tier custom chart model, custom SQL with adaptive sampling (no row caps — Claude fearmongering walked back), polar wind rose + radial weatherRange both confirmed feasible on ECharts. Next session resumes at category 10. |
| 3 | 2026-05-02 | 10 ✅ | Cat 10 closed. Decisions: Records and Reports as two separate built-in pages; Records adds a year selector, an AQI section gated on AQI columns, and an operator-configurable user-defined records mechanism distinct from custom charts; inside-temp records default off; year/month dropdowns show only what's available; NOAA reports rendered as HTML-parsed tables with `.txt` download for export; Clear Skies SHIPS an enhanced NOAA Cheetah template (folder name "NOAA" preserved with in-template "not an official NOAA product" annotation) adding 9 fields the default omits (pressure, humidity, dew point, rain rate, peak gust separate, solar mean+peak, UV peak, snow if measured, records broken). HARD CONSTRAINT — render-time sensor-availability adaptation: every rendered surface checks per-period whether each candidate column has data and renders only the columns with values. Promoted to cross-cutting thread. Two new artifacts captured: `docs/reference/NOAA-COOP-CWOP-REPORTING-RESEARCH.md` (full research with sources after Claude's training-data error on COOP/CWOP relevance was corrected). |
| 4 | 2026-05-02 | 11 ✅ | Cat 11 closed. Theme: keep all three modes (light/dark/auto-by-sunrise-sunset). Branding: light+dark logo upload via setup UI, auto-invert dark from light if not provided + warn user. i18n: 13 locales for v0.1 from numisync.com (en/de/es/fil/fr/it/ja/nl/pt-PT/pt-BR/ru/zh-CN/zh-TW); no RTL in scope; framework choice deferred. PWA: installable manifest yes, offline service-worker deferred to Phase 6+. Custom CSS + per-page narrative slots: yes; Cheetah `*.inc` hooks dropped. Footer: slim one-line on every page (© / Legal / Powered by Clear Skies, attribution hideable). Social share: pure href share-intent links (X/Facebook/Reddit/Mastodon/Bluesky/Email/Copy-Link), no SDK, no consent surface — mirrors coinrollhunting.org theme implementation (verified by reading the source). Analytics: GA4 + Plausible + Umami + none, consent banner shipped at v0.1, operator toggles whether banner is required for their jurisdiction. Legal/Privacy: boilerplate pre-customized for the user, future operators modify; setup wizard requires acknowledgment checkboxes for legal text + analytics + social compliance. Schema.org / Open Graph: keep auto-generated. ADA/WCAG 2.1 AA: load-bearing thread; per-write audit + pre-ship full audit; rules written to `rules/coding.md` Section 5. New cross-cutting threads: i18n first-class for v0.1, accessibility load-bearing project-wide. |
| 5 | 2026-05-02 | 12 ✅ | Cat 12 closed. Lightning gets own Now-page tile with storm-phase status badge (approaching/overhead/departing/clear) borrowed from Tempest community concept; new chart shape (count bars + nearest-distance line, configurable alert-distance reference line) replaces Belchertown's distance scatter; chart placement flexible per cat 9. Belchertown's lightning chart aggregation flagged as Phase 2 investigation (likely needs SUM count + MIN distance, not AVG). Barometer 3-hr trend kept as-is. Multi-probe (extraTemp/extraHumid) and esoteric sensors (soil/leaf) folded into existing custom-column-mapping cross-cutting treatment; no separate cat 12 work needed. About page corrected from earlier auto-generation proposal: operator-authored markdown with setup-wizard pre-populated starter content (matches Belchertown's user-authored-HTML model — verified by reading skins/Belchertown/about.inc directly). Posted-to list and credits list = operator-authored markdown within About page; no preset platform list shipped. Walk through 12 categories complete; ready for ADR-009 (design direction) and ADR-024 (page taxonomy) drafts. |

## Cross-cutting design patterns / threads accumulated through the walk

These emerged during the per-category decisions and apply project-wide:

- **All tiles hide-able by operator** — universal config toggle; lands in [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) and [ADR-024](../decisions/INDEX.md). Every tile gets a stable ID + visibility toggle.
- **Click-to-expand "more details" UI pattern** — used in categories 1, 2, 4, 5, 6. Standardized treatment to be designed in Phase 3.
- **Operator-customizable chart layout** — Belchertown's `graphs.conf` flexibility is the bar. Owned by category 9 (still pending).
- **Provider-pick at setup** — recurring pattern. Forecast (cat 3), earthquakes (cat 6) — both pick one provider per deploy. Configuration UI must support a "pick one of N providers for X data feed" pattern.
- **Provider-adaptive UI** — when a provider doesn't return a field, the UI degrades gracefully. Aligned with [ADR-010](../decisions/ADR-010-canonical-data-model.md)'s all-fields-optional design. Forecast cards specifically have to handle different fields per provider.
- **User-driven column mapping at setup** — operators map their own weewx archive column names to canonical fields. Subsumes [ADR-035](../decisions/INDEX.md) (Pinned). AQI is the worked example (column names not standardized; operator maps).
- **New built-in optional pages confirmed:** Almanac/Astronomy (cat 5), Earthquakes (cat 6). Both hide-able. Both feed [ADR-024](../decisions/INDEX.md).
- **Map stack pulled forward** — Earthquakes page wants an embedded map; this is the first map surface in v0.1. Touches [ADR-015](../decisions/INDEX.md) (currently Pinned). Likely answer: Leaflet or MapLibre with OSM tiles.
- **MQTT auto-disconnect → SSE visibility-pause** — Clear Skies' realtime should pause via `document.visibilityState`, not wall-clock timeout. No "Continue Live Updates" button.
- **Stale-data alert ON by default** — threshold = 2× archive interval, configurable.
- **Today's Highlights sub-card** — confirmed design element on the main page (today's hi/lo, observed peak wind, rain so far, etc.).
- **Clear Skies bundles a maintained AQI extension** as a recommended-but-optional install — adoption / fork of `inguy24/weewx-airvisual` pending Phase 2 decision.
- **Provider capability registry (emerging pattern)** — both the cat 3 forecast surface and the deferred cat 7 marine surface require the dashboard to know *which configured provider supplies which data category*. This registry concept is reusable: any future "should this tile render?" question routes through it. Materializes as Phase 2/3 spec work; called out here so categories 8–12 can lean on it without re-deriving.
- **PWS-contributor tracks are the default lens for "free", not the exception.** Captured 2026-05-02 after Claude repeatedly dismissed Aeris (and treated paid pricing pages as gating) without applying this lens. **Every weewx operator is by definition a PWS operator** — that is what weewx does. So when a provider offers a free tier in exchange for PWS data submission (AerisWeather Contributor Plan via PWSWeather; Weather Underground PWS API), the realistic Clear Skies default is **"the operator is on the contributor track"**, not "the operator pays." Apply this lens to every provider research pass. Specifically: AerisWeather Contributor Plan (1,000 Weather API/day + 3,000 Map units/day) is the realistic free Aeris path for ~all Clear Skies operators. ADR-007 already incorporates this for Wunderground; re-evaluate other categories' "paid" findings under this lens before recommending. Affects cat 7 (marine — may lift the deferral) and cat 8 (radar — Aeris becomes the realistic global default, not RainViewer).
- **Data-provider code is organized as internal plug-in-style modules** (decided 2026-05-02). One file/directory per provider in our own codebase. The point is *our* maintenance ease — adding a new provider doesn't mean surgery on a monolithic file; removing a deprecated one doesn't mean grep-and-cut. **Not** a third-party plugin ecosystem: no external entry-points discovery, no marketplace, no semver-locked contract, no trust-model documentation for outsiders. Outside contributors who want to add a provider open a PR; we review and merge into the bundled set or we don't. Scope is **data providers only** — UI components, themes, etc. are not plug-in-able. Needs an ADR (Pinned slot to be added: provider-module organization). Implementation guidance: keep the inter-module contract small and internal; capability declaration per module (what data types it provides) feeds the provider capability registry thread above.
- **Installation / distribution mechanism is an open question** (surfaced 2026-05-02). User pushback: `pip install` is hostile to non-Python Windows users; "people understand downloadable installers." Default Python packaging assumptions (pip + venv + systemd unit) may not be the right end-user UX for the Windows-installer-expectations audience. Open thread; needs its own decision and likely feeds **ADR-028** (update mechanism, currently Pinned) plus possibly a sibling deployment-distribution ADR. Not blocking the content walk; flagged so it's not lost.
- **User-defined records (cat 10, surfaced 2026-05-02)** — parallel to but distinct from user-defined charts (cat 9). A *record* is a single-value-with-context (e.g., "Highest AQI = 187 on 2025-08-12"); a *chart* is a time series. Operators want to track records on observations beyond the canonical set Clear Skies ships (e.g., highest pollen count from a sensor not in our default list). Surface: configuration UI lets the operator pick an observation column + a record type (max / min / sum-over-period / count-over-period / consecutive-days-with-positive / consecutive-days-without) + a label; the Records page renders the resulting row in a "Custom Records" section. Distinct mechanism from the custom-chart system — no shared code beyond reading from the same archive. Replaces Belchertown's `records-table.inc` Cheetah include slot with a config-driven equivalent.
- **Render-time sensor-availability detection (cat 10, locked 2026-05-02)** — every rendered surface (NOAA template, Records page, charts, dashboard tiles) MUST detect per-period whether data exists for each candidate field and adapt the layout accordingly. Distinct from setup-time column mapping (which is the prior thread / ADR-035): mapping says "this archive column is barometer," availability detection says "for the period being rendered, does the barometer column have any non-null aggregate? If not, omit the barometer column entirely from this render." User directive 2026-05-02: "make sure that our system understands what EACH individuals' station may or may not provide and format accordingly." Worked examples: Belchertown already does this implicitly (Sun Records only render if radiation/UV exist; "Largest Daily Temperature Range" only if `appTemp` data exists). Cat 10 NOAA template formalizes the pattern. Implementation guidance: aggregate-NULL check per column per period at render time; auto-omit columns with no data; operator config can force-include (renders with explicit N/A) or force-exclude. Affects the canonical data model contract (`docs/contracts/canonical-data-model.md`) and likely lands in ADR-010's implementation guidance amplification.
- **i18n is first-class for v0.1, NOT deferred (cat 11, locked 2026-05-02)** — User directive: "We need to be multi-language friendly. It is not like we have that much we have to translate as we build." Reverses Claude's earlier proposal to ship en-only at v0.1. **Scope of this decision: the LANGUAGE LIST only.** v0.1 supported languages = the set from numisync.com (the user's other site), confirmed via screenshot 2026-05-02:
  - English (en) — default
  - Deutsch (de) — German
  - Español (es) — Spanish
  - Filipino (fil)
  - Français (fr) — French
  - Italiano (it) — Italian
  - 日本語 (ja) — Japanese
  - Nederlands (nl) — Dutch
  - Português (pt-PT) — Portuguese (Portugal)
  - Português Brasil (pt-BR) — Portuguese (Brazil)
  - Русский (ru) — Russian
  - 中文 简体 (zh-CN) — Chinese (Simplified)
  - 中文 繁體 (zh-TW) — Chinese (Traditional)

  13 locales total. No RTL languages in the set; RTL layout work not required for v0.1. Implementation choices (framework, file format, string-extraction pattern) are NOT decided here — Phase 2/3 questions. Affects [ADR-021](../decisions/INDEX.md) (Pinned → Proposed/Accepted when drafted): the locked language list goes there.
- **Accessibility (WCAG 2.1 AA) is load-bearing from now on (cat 11, locked 2026-05-02)** — User directive: "ADA compliance is something we HAVE to make sure we are always keeping an eye on." Treated as a project-wide constraint, not just a Phase 4 polish item. **Approach (per user 2026-05-02): audit all code after it is written for compliance, plus a full audit before shipping.** Per-write audit + pre-ship full audit. Rules written into [rules/coding.md](../../rules/coding.md) Section 5 — done 2026-05-02, not deferred. Scope:
  - **Color palette has WCAG contrast constraints** — affects [ADR-009](../decisions/INDEX.md) (design direction, currently in active draft); palette work picks colors that pass AA (4.5:1 normal text, 3:1 large text/UI components) before any aesthetic optimization.
  - **Operator-uploaded graphics: alt text REQUIRED** at upload time — setup UI prompts the operator and won't accept the image without it (logo, hero photo, custom backgrounds, custom tile images).
  - **Built-in graphics: alt text mandatory in source** — every weather icon, chart, button icon, decorative graphic ships with `alt=""` (decorative) or descriptive alt text.
  - **Semantic HTML, keyboard nav, focus indicators, ARIA labels** — landed in [rules/coding.md](../../rules/coding.md) Section 5.
  - **Charts (ECharts):** `aria-label` on chart container; data-table fallback rendered for screen reader; keyboard-navigable tooltips per the chart engine's accessibility features.
  - Affects [ADR-026](../decisions/INDEX.md) (commitments): moves from Pinned to Proposed at WCAG 2.1 AA. Affects [ADR-009](../decisions/INDEX.md): palette constraint is a hard input.

## ADR locks proposed by this walk (not yet ratified)

These would move from Pinned → Accepted on the basis of decisions captured here. Each still needs an ADR draft + explicit user sign-off in the standard process.

- **[ADR-013](../decisions/INDEX.md) (AQI source):** weewx archive columns, written by an operator-installed extension. Clear Skies does not call any AQI API itself.
- **[ADR-014](../decisions/INDEX.md) (Almanac source):** `skyfield` (not `pyephem`). Modern, actively maintained, NASA JPL ephemerides; enables the new Almanac page's planet/eclipse content.

---

## 1. Live data + current observations · ✅ (decided 2026-05-01)

### Decisions

- **Live updates: hard requirement.** SSE per [ADR-005](../decisions/ADR-005-realtime-architecture.md), targeting the same ~5s cadence as today's MQTT stream. The user-visible behavior is "values change in place as they update" — same as Belchertown.
- **Auto-disconnect: replaced with visibility-based pause.** No wall-clock 30-min timeout. SSE pauses when `document.visibilityState === "hidden"` and resumes when visible. No "Continue Live Updates" button.
- **Status indicator: 2-state (not 3).** Silent UI when data is fresh; only show an indicator when data is stale or disconnected. No "online" pill in normal operation.
- **Stale-data alert: ON by default.** Subtle banner shown when no update has arrived in **2× the archive interval**. Threshold is configurable per deploy; a fixed default of 2× is the rule.
- **Default station observations on the "Now" hero card: keep the current 8 in their current order** — Barometer (with 3-hr trend), Dew point, Outside humidity, Rain (combined daily total + current rate), Heat index, Wind chill, Solar radiation, UV index.
- **Cloud cover: NOT a numeric field on the dashboard** — the condition icon already conveys cloud cover visually. No separate cloud-cover percent.
- **Cloud base, visibility, wind run: "more details" expansion only**, not in the default rendered set. The new design needs a "more details" UI pattern (expand-on-card, drill-in, or dedicated page) — exact treatment TBD when ADR-024 (page taxonomy) lands.
- **Indoor temp / humidity: optional, operator-toggled.** Off by default; operator config can enable to show on the dashboard. Not hidden permanently.
- **Today's hi/lo: moves off the hero card into a "Today's Highlights" sub-card on the main page**, alongside other today-summary numbers (rain so far today, peak wind today, etc.). The hero stays focused on current temp + condition + feels-like. (Pattern echoes refs 2 and 4.)

### Threads carried forward

- **"Today's forecast should be on the main page somewhere."** User raised this here while discussing today's hi/lo. Properly belongs to category 3 (Forecast + alerts); captured here so it isn't lost. The main page will have a forecast surface for *today* (not just current obs). Decision in category 3 will fix exactly what shape that takes.
- **"More details" UI pattern is required.** Several categories will produce a "show me more" tier of fields. The exact mechanism (modal, expand-card, drill-in page) is a Phase 3 design question; for now, capture that the pattern exists as a need.
- **"Today's Highlights" sub-card** is now a known design element on the main page. To be confirmed and shaped as more categories produce candidate stats for it.

## 2. Wind detail · ✅ (decided 2026-05-01)

### Decisions

- **Animated compass dial: keep, secondary to the temperature hero.** Visual hierarchy on the "Now" page puts the temperature number at top of the hierarchy; the compass sits subordinate (not co-equal). Compass animation tweens the arrow on every live update, same behavior as Belchertown.
- **Cardinal direction primary, degrees secondary.** Display large cardinal label ("WSW") with small degree value below ("274°") rather than Belchertown's equal-weight pairing.
- **Wind direction trail on compass: include.** Subtle arc showing where the arrow has been over the recent past (e.g., last 15 minutes). Small JS enhancement; adds movement context.
- **Beaufort scale label: hide when calm** (Beaufort 0 / under 1 mph). Show whenever wind is detectable. The 13-step scale label remains locale-translatable.
- **Speed + Gust:** keep paired with the compass on the "Now" page, with units. Same as today.
- **Wind run, peak gust today, average wind today, today's wind direction summary:** behind a **click-to-expand interaction**, not always-visible. These are today-aggregate stats that interest power users but clutter the default view.
- **Wind charts (wind rose + line chart of speed/gust): keep both, but NOT on the main page.** Both belong in the dedicated charts area (category 9 will fix exact placement). Wind rose is climatology ("what's the prevailing wind here"); line chart is "what's wind doing now" — different contexts, both valuable.

### Threads carried forward

- The **click-to-expand interaction pattern** is now confirmed as a design element (was first foreshadowed by the "more details" tier in category 1). Used here for today's wind aggregates. Treatment to be standardized — same click-to-expand mechanic should apply consistently across categories where it's used.

## 3. Forecast + NWS alerts · ✅ (decided 2026-05-01)

### Decisions

#### Forecast

- **One forecast provider per deploy.** The operator picks one provider to install/configure; no multi-provider side-by-side comparison in the dashboard. (Codebase still supports the day-1 provider set per [ADR-007](../decisions/ADR-007-forecast-providers.md); this is a *deployment* model decision.)
- **Provider-adaptive UI.** The forecast UI must gracefully handle whatever fields the configured provider returns — render rich detail when available, render minimal-baseline when not. Aligned with [ADR-010](../decisions/ADR-010-canonical-data-model.md)'s all-fields-optional design. The dashboard never assumes a field is present.
- **Today's forecast on the main page** as a compact card (general shape: narrative + predicted hi/lo + precip% + condition icons through the day). **Exact card content is provider-dependent** — revisit this when each provider's actual response surface is known. Not a one-size-fits-all card.
- **Multi-day / multi-hour forecast on a dedicated Forecast page.** Hourly view (rolled into a scrollable strip or compact table) + daily view (7-day, extending if the provider gives us more). **Drop the 3-hour view** as a default — but providers that genuinely natively offer 3-hour blocks (and not 1-hour or 24-hour) should still be supported when configured.
- **Forecast discussion / narrative as a separate tile**, operator-toggled. NWS Area Forecast Discussions, Aeris weather summaries, etc. — when the configured provider offers prose, the operator can opt to include the discussion tile on the Forecast page. Off by default (since most providers don't offer prose), on for those who do (NWS, partial Aeris).
- **Forecast freshness indicator** ("updated N min ago") shown on the forecast surface — small, secondary, but always visible.

#### NWS alerts

- **Alert banner appears on all pages when an alert is active.**
  - **Most prominent on the home page** — full-width, color-coded by severity (red = warning, yellow = watch, blue = advisory).
  - **Header strip on other pages** — visible but condensed; a thin colored bar with a brief headline that links into the alerts detail.
- **Click-through to alert detail** — modal or dedicated alerts panel showing full text, severity / urgency / certainty, effective / expires, areas, sender. Multiple active alerts stack with a count.
- **Banner dismissable per-session** but reappears on next visit if the alert is still active. Expired alerts auto-clear.

### Threads carried forward

- **Provider-adaptive forecast card content** — exact field set per provider (Aeris, NWS, OpenMeteo, OpenWeatherMap, Wunderground) is to be enumerated during Phase 2 once the canonical data model spec (`docs/contracts/canonical-data-model.md`) lands. The card design has to gracefully degrade.
- **Provider packaging model** — user said "user picks one provider to install" which could imply pluggable provider extensions (each as a separate install) or a single bundle with one configured. ADR-007 doesn't lock this. Worth a note when ADR-007 implementation lands. Either model satisfies "operator picks one" from the user's perspective.
- **No site-wide "event mode."** The Belchertown `Tropical_Storm_Hilary` graphgroup is just a special-interest archived chart for one historic event, not a site behavior. In Clear Skies, archived event-specific charts go through the custom chart system (category 9). The site does not "go into event mode" during severe weather — the alert banner does the lifting.

## 4. AQI / air quality · ✅ (decided 2026-05-01)

### Decisions

- **AQI source: weewx archive columns, written by an operator-installed extension.** Clear Skies does NOT call any AQI API itself. **This locks [ADR-013](../decisions/INDEX.md) (Pinned → Accepted direction).**
- **NO standardized AQI column-name contract.** Different operators have different sensors / extensions writing different column names — physical AQI monitors that feed into the archive use whatever column names the sensor provides. **Column-to-canonical-AQI-field mapping is a setup-time user task** (per [ADR-035](../decisions/INDEX.md), the user-driven schema mapping flow). The setup UI prompts the operator to say "column X is the AQI value, column Y is the dominant pollutant, column Z is PM2.5..." etc.
- **clearskies-api ships and maintains a recommended AQI extension** as part of the Clear Skies package — an updated/forked equivalent of the current `weewx-airvisual` (`AirVisualService`). Operators who don't have an AQI sensor can install this to get IQAir-sourced AQI. Operators who have a physical sensor or another extension just map their existing columns.
- **AQI tile design on the "Now" page:**
  - **Half-gauge (semicircle) at the top** of the tile, color-graded across the AQI scale (green → yellow → orange → red → purple → maroon — Good through Hazardous).
  - **Big AQI number** centered below the gauge.
  - **Category label** ("Moderate") and **dominant pollutant** subtext ("PM2.5") below the number.
  - **Click-to-expand: full pollutant breakdown** (PM2.5, PM10, O3, NO2, SO2, CO concentrations — whatever the operator's extension wrote and they mapped).
- **AQI charts go INTO the homepage chart group**, not a separate "Air Quality" group. The current Belchertown `[airquality]` graphgroup gets folded into the `[homepage]` group (which today already covers Temperature / Wind / Rose / Rain / Barometer / Solar+UV / Lightning — adding AQI makes 8 charts in that group). **Default layout** is this; operator can customize via the chart-layout system (category 9).
- **All tiles must be hide-able by the operator** — universal pattern, not specific to AQI. Every tile on every page has an on/off toggle in the configuration UI.

### Threads carried forward

- **ADR-035 (column mapping) is load-bearing for AQI.** AQI is now the primary worked example for ADR-035's user-driven schema mapping flow. When ADR-035 is drafted, AQI must be in its examples.
- **Clear Skies bundles a maintained AQI extension** — project-scope addition. New repo or fork to manage: TBD when Phase 2 lands. Likely either adopting `inguy24/weewx-airvisual` into the Clear Skies repo set or forking it as `weewx-clearskies-airvisual`.
- **Universal "hide this tile" toggle** — design pattern that lands in [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) (configuration UI scope) and [ADR-024](../decisions/INDEX.md) (page taxonomy / tile model). Every category from here on adds tiles to a shared inventory; each tile gets a stable ID + visibility toggle.
- **Operator-customizable chart layout is reinforced.** The "operator can change which charts are in which group, on which page" capability from Belchertown's `graphs.conf` model is the bar. Category 9 owns the design for this.

## 5. Almanac / sun & moon · ✅ (decided 2026-05-01)

### Decisions

- **Almanac source library: `skyfield`** (not `pyephem`). Modern, actively maintained, NASA JPL ephemeris-based, drop-in for the same use cases. **This locks [ADR-014](../decisions/INDEX.md) (Pinned → Accepted direction).**
- **Sun & moon tile on the "Now" page** (hide-able per universal pattern). Tile content:
  - Sunrise icon + time
  - Sunset icon + time
  - CSS-rendered moon phase visualization
  - Moon phase name ("Full Moon", "Waning Crescent")
  - Moon fullness percent ("100% visible")
  - **Total daylight + delta vs yesterday** — kept on the compact tile (it's a small distinctive Belchertown touch worth retaining)
- **Click-to-expand details** (modal or drill-in TBD when ADR-024 lands):
  - Civil twilight start/end
  - Sun rise / transit / set
  - Moon rise / transit / set
  - **Sun + moon azimuth / altitude / RA / declination** — always visible in expanded (no separate astronomer-mode toggle; everyone gets the full ephemeris on expand)
  - **Equinox + solstice** (next of each)
  - **Full moon + new moon** (next of each)
  - Phase name + % full (already on compact, repeated for completeness)
- **Standalone Almanac / Astronomy page** as a built-in page in Clear Skies. **Approved as a feature.** Content TBD when the page taxonomy synthesizes (likely candidates: planets visible tonight, upcoming eclipses / meteor showers / conjunctions, year-long sunrise/sunset chart, year-long daylight chart, moon phase calendar, twilight times). Skyfield supports planets and eclipses natively — the library choice enables this page.

### Threads carried forward

- **New page added to the taxonomy: "Almanac" (or "Astronomy").** Standalone, built-in, optional-to-show (universal hide-able). When ADR-024 (page taxonomy) is drafted, this is one of the named pages.
- **Skyfield's broader capabilities** (planet positions, eclipses, satellite passes) open future tiles/pages beyond what we'd ship in v0.1. Worth a Phase 6+ note: as the almanac page matures, more astronomical content can be added cheaply because the library is already there.

## 6. Earthquakes · ✅ (decided 2026-05-01)

### Decisions

- **Earthquake tile on the "Now" page** — default ON, hide-able per universal pattern.
- **Tile content (compact):** most-recent earthquake within radius — magnitude (prominent), location, distance + bearing, time-ago.
- **"All quiet" state:** when feed is empty, show "No earthquakes within <radius> km in the last 7 days" rather than hiding the tile. That message is itself meaningful information.
- **Click-to-expand:** list of recent earthquakes (last 7 days, capped) with full info per row.
- **Dedicated "Earthquakes" page** as a built-in optional page (alongside the Almanac page just confirmed). The page hosts: full recent-earthquakes list with sortable columns, a small embedded map showing markers sized by magnitude (Leaflet or MapLibre with OSM tiles), and any provider-specific extras. Hide-able by operator.
- **Default radius: 400 km, adjustable in configuration.**
- **Provider options shipped in v0.1:**
  - **USGS (default)** — global coverage. The ANSS ComCat catalog is the worldwide authoritative source; XWeather's own earthquake feed sources from USGS. Free, no key.
  - **GeoNet (NZ)** — regional alternative for New Zealand operators (native posting, Mercalli intensities).
  - **ReNaSS (FR/EU)** — regional alternative for French/European operators (native language, France-specific detail).
  - **EMSC (Euro-Med + global)** — FDSN-standard open service, free, no key. Adds a Euro-Med-tuned option for users in that region. **Newly added** — not in current Belchertown.
- **NOT shipped:** XWeather earthquakes (re-distribution of USGS, paid); Terraquake (status uncertain).

### Threads carried forward

- **New page added to the taxonomy: "Earthquakes" (optional).** Joins the new Almanac page from category 5. Both are operator-toggleable (hide-able) — consistent with the pattern that started in category 4 (universal tile-hide).
- **Maps as a v0.1 feature surface.** The earthquake page's embedded map is the first place a real interactive map shows up in Clear Skies. [ADR-015](../decisions/INDEX.md) (radar / map tiles strategy) is currently Pinned — the earthquake page's map need pulls forward the question of "what's our map stack." Likely answer: Leaflet or MapLibre with OSM tiles (free, well-supported, no API key for OSM). Decision deferred to ADR-015.
- **Provider-pick at setup is a recurring pattern.** Forecast (category 3) had it; earthquakes have it now. The configuration UI must support a "pick one provider for X" pattern that several categories will reuse.

## 7. Marine / surf / tides · ⏸ DEFERRED (decided 2026-05-02)

### Decision

**No built-in Marine page in v0.1.** Provider research (matrix below) showed that none of the 5 ADR-007 providers, in any combination available at $0/mo to a typical operator, supplies enough marine surface to ship a non-misleading boater-grade marine page. Specifically:

- **Tides:** unsolvable inside ADR-007 — only paid Aeris (US-only) returns authoritative tide tables. OpenMeteo's `sea_level_height_msl` is a model time series, not a tide prediction; labeling it as tides would mislead.
- **Marine zone / boater forecast:** solvable for US users only (NWS, free) and global paid users (Aeris). Empty for OpenMeteo/OpenWeatherMap/Wunderground users.
- **Sea state + SST:** solvable globally on free OpenMeteo, but without the tide and boater-forecast pieces this is a partial page — exactly the "modernized but dumbed-down" outcome the user has been rejecting.

Shipping a partial marine page would deliver a worse experience than what the current Belchertown site offers. Better to defer until we can do it right.

### When this gets revisited

Marine returns to the table if and when one of these changes:

- A clean way to add **NOAA CO-OPS** (tides) appears — narrow scope, free, US-only, would close the tides gap for US operators on free providers.
- A clean way to add **NDBC** (buoy observations) appears — closes the actual-observed sea-state gap globally where buoys exist.
- Demand surfaces from operators who'd accept a partial page (e.g., "I just want the NWS marine zone forecast, that's enough for me").

Until then: no Marine page, no Marine nav entry, no marine tiles. Surf module remains Phase 6+ exploration as previously noted.

### Captured for the future-revisit ADR

When marine is reopened, the research below is reusable as-is — the matrix is current as of 2026-05-02 and the per-provider notes capture the nuance (free-tier limits, geographic constraints, paid-tier gates, PWS-contributor track unknowns).

### Research that produced this decision (preserved)

### What exists today

Dedicated `/marine/` page with three location-specific external embeds, all hard-coded to Huntington Beach / Newport Beach areas:

- **Surf Forecast Widget** (iframe from `surf-forecast.com/breaks/Huntington-Pier/...`) — free embed
- **TidesPro Tide Table** (script embed, hard-coded ID for `us/california/newport-beach-newport-bay-entrance-corona-del-mar`) — free embed
- **TidesPro Tide Chart** (second TidesPro script embed) — free embed
- **TidesPro Solunar Table Week** (third TidesPro script embed — fishing/hunting solunar predictions) — free embed

All three are third-party iframe / script embeds (zero subscription cost on the operator's side); Clear Skies does NOT process tide or surf data; it just hosts someone else's widget.

### Initial Claude proposal — REJECTED 2026-05-02

Claude's first pass proposed dropping the built-in Marine page and replacing it with a generic embed-widget tile primitive that operators would compose into a custom page. **User rejected this direction.** Claude also incorrectly assumed the third-party widgets might be paid — they are free.

### User directives (captured 2026-05-02 — these are inputs, not yet a decision)

Re-think the marine page from the ground up. Specifically:

- **Marine page is OPTIONAL** — many operators don't live near a marine environment. Page must be enable-able at setup, off by default. Consistent with the universal hide-able pattern from category 4.
- **Research what marine data each of our 5 day-1 forecast providers actually supplies** ([ADR-007](../decisions/ADR-007-forecast-providers.md): Aeris, NWS, OpenMeteo, OpenWeatherMap, Weather Underground). Decide what we can build from providers we already integrate with — don't reach for new providers until we know what we have.
- **Surf forecast = surfing environments only.** Probably not in any of our providers. Direction: future-expansion thread on how surf forecasts are developed (wave model + bathymetry + shoreline orientation), and whether Clear Skies could eventually build its own surf module. **Not a v0.1 feature.**
- **Tides = important in most marine environments**, with the exception of very-low-tide environments like the Great Lakes (where lunar tides are sub-foot and operationally irrelevant; meteorological seiches matter more there).
- **Boater forecasts** (NWS Coastal Waters Forecast, Offshore Waters Forecast, marine zone forecasts) are missing from the current Belchertown page despite being important. These should be on the table as a first-class feature where a provider supports them.

### Research findings (filled 2026-05-02)

What marine-relevant data each of our 5 day-1 providers offers. "Free" below means "available to a hobbyist deploy at $0/mo" — for paid providers, "free" denotes endpoints inside the free tier of that provider, not zero-cost overall.

| Provider | Tides | Marine zone / coastal forecast | Sea state (wave height, period, swell) | Water temp (SST) | Marine alerts | Surf-relevant |
|---|---|---|---|---|---|---|
| **Aeris (Xweather)** | yes — `/tides` + `/tides/stations`, **US + PR + Guam only**, paid (incl. 30-day free trial; PWS-contributor free tier may include) — [docs](https://www.xweather.com/docs/weather-api/endpoints/tides) | no structured marine zone forecast; closest is general `/forecasts` over a coastal lat/lon | yes — `/maritime` returns sig wave height, primary/wind/swell (1°+2°+3°) height/dir/period, currents, **global**, 6-hr update, +15 day, paid (Flex/trial) — [docs](https://www.xweather.com/docs/weather-api/endpoints/maritime) | yes — included in `/maritime` (SST out 7d, °C/°F), global, paid — [docs](https://www.xweather.com/docs/weather-api/endpoints/maritime) | yes — `/alerts` re-distributes NWS, EC, MeteoAlarm, UK Met, JMA, BoM (incl. SCA/Gale/Storm/Hurricane/Tsunami), paid — [docs](https://www.xweather.com/docs/weather-api/endpoints/alerts) | partial — multi-component swell (primary + secondary + tertiary) in `/maritime`, but no spectral/break-specific output |
| **NWS** | **no** — NWS does not publish tides; tides are NOAA CO-OPS, separate agency | yes — `/zones?type=marine`, `/zones/marine/{id}/forecast` for zone forecast; full text products via `/products/types/CWF` (Coastal Waters), `/products/types/OFF` (Offshore), `/products/types/HSF` (High Seas), free, US + adjacent waters — [openapi.json](https://api.weather.gov/openapi.json), [marine zones map](https://www.weather.gov/marine/AllZones) | partial — wave height appears in `/gridpoints/{wfo}/{x},{y}` for coastal grid cells (NWS notes "coastal marine grid forecasts only via forecastGridData"); no swell decomposition; no offshore wave model exposed via API — [docs](https://www.weather.gov/documentation/services-web-api) | partial — SST present in some coastal grid responses; no dedicated SST product | yes — `/alerts/active/area/{MarineAreaCode}` and area codes AM/AN/GM/LC/LE/LH/LM/LO/LS/PH/PK/PM/PS/PZ/SL cover SCA/Gale/Storm/Hurricane/Tsunami; free, US-only — [openapi.json](https://api.weather.gov/openapi.json) | no |
| **OpenMeteo** | yes (sort of) — `sea_level_height_msl` (incl. tides) is a Marine API variable, **global**, free non-commercial — [marine docs](https://open-meteo.com/en/docs/marine-weather-api) | no marine-zone text forecast | yes — separate endpoint `https://marine-api.open-meteo.com/v1/marine`: significant wave height, wave dir, period, peak period; wind-wave + swell (primary/secondary/tertiary) height/dir/period; currents; global; ~5 km res; +16d; free non-commercial — [marine docs](https://open-meteo.com/en/docs/marine-weather-api) | yes — `sea_surface_temperature` from same Marine endpoint, global, free non-commercial — [marine docs](https://open-meteo.com/en/docs/marine-weather-api) | no — OpenMeteo does not publish government alerts in any feed | partial — primary + secondary + tertiary swell decomposition, but no spectral data and no break-specific refraction |
| **OpenWeatherMap** | **no** — no tide endpoint in 2026 catalog — [api index](https://openweathermap.org/api) | **no** — no marine zone product | **no** — One Call 3.0 returns no wave data; no Ocean Weather API in current catalog — [One Call 3.0 docs](https://openweathermap.org/api/one-call-3) | **no** — no SST endpoint | partial — gov't weather alerts via One Call 3.0 (paid), but not marine-specific marine-zone alerts | no |
| **Weather Underground** | **no** | **no** | **no** | **no** | **no** | **no** — IBM/Weather Company PWS API surface is `stations/observations/current` + history for the user's own PWS only; no marine endpoints whatsoever — [PWS doc](https://www.ibm.com/docs/en/environmental-intel-suite?topic=apis-pws-observations-current-conditions) |

### Provider notes (nuances that don't fit cells)

**Aeris (Xweather)** — Marine offerings are spread across three endpoints: `/maritime` (global wave + SST + currents), `/tides` + `/tides/stations` (**US/PR/Guam only**), and `/alerts` (re-distributed NWS et al.). All sit behind the paid Weather API plan. Free 30-day trial gives "full access to all endpoints." A no-cost path exists via the **PWS-contributor program** (operator submits PWS data to PWSWeather → free Xweather API access including hourly forecasts, observations, AQ); maritime/tides inclusion in that tier is plausible but not explicitly confirmed in the contributor docs. End-user $0 viability for ADR-006 self-funding: **only via the contributor track**, otherwise paid.

**NWS** — Strongest marine surface of the five for **US users**: marine zones, structured zone forecasts, marine alerts by area code, and text products for CWF/OFF/HSF. **No tides** (tides live at NOAA CO-OPS, a sibling agency, separate API at `tidesandcurrents.noaa.gov`). Wave/SST exposure is uneven — only in `forecastGridData` for grid cells the NWS classifies as coastal marine, with no swell decomposition. Free, no key, US/territories only. The marine zone forecast is the headline product Clear Skies could ship "for free" to a US-coastal operator.

**OpenMeteo** — Marine API is a **separate URL** (`marine-api.open-meteo.com/v1/marine`), not part of the standard `api.open-meteo.com/v1/forecast` call. Operators have to wire it as a second provider call. **Best free global wave + SST surface of the five** — comparable variable list to paid providers, no key, no registration for non-commercial. Caveat: tides are exposed as `sea_level_height_msl` from a model, not as harmonic-station-derived high/low predictions; Clear Skies would need to derive high/low events from the time series (or treat as "rough tide curve" rather than authoritative tide table). No marine alerts whatsoever — OpenMeteo doesn't carry government alert feeds.

**OpenWeatherMap** — Marine offering has effectively been **discontinued / not present in the 2026 catalog**. The historical "Ocean Weather API" / "Tide API" no longer appear among their listed products (Current/Forecast, Solar, Historical, Maps, Air Pollution, Fire WI, Road Risk). One Call 3.0 returns nothing marine. For a Clear Skies operator on OpenWeatherMap, **the marine page would be empty unless paired with a second provider call**.

**Weather Underground** — Public API is the IBM/Weather Company PWS-contributor API (`api.weather.com`), gated to people uploading their own PWS. Surface is narrow: current observations from one's own station + station history. **Zero marine data** of any kind. Confirms category-3 reasoning that Wunderground is current-conditions-only for PWS users; same applies here.

### Free marine sources OUTSIDE these 5 providers (worth knowing if we ever fall short)

The user is firm that we don't add new providers casually. The note below is "if our 5 providers can't cover boater data and an operator demands it, here's what's free and well-supported."

- **NOAA CO-OPS (Tides & Currents)** — `https://tidesandcurrents.noaa.gov/web_services_info.html`. Authoritative US tides (water levels, harmonic predictions, datums, tide+current predictions, water temp at some stations). Free, no key. JSON/CSV/XML/NetCDF. US + territories only. **This is what NWS doesn't cover** and is the obvious gap-filler if a tide table is required and the operator is on a non-Aeris provider.
- **NDBC (National Data Buoy Center)** — `https://www.ndbc.noaa.gov/data/realtime2/{station}.txt`. Real-time buoy observations: wave height/period/dir, SST, wind, pressure, from NOAA buoys + partner platforms. Free, no key. Text format (third-party JSON wrappers exist). Global coverage of NOAA + partner buoys. **The boater-grade real-observation source** — what NWS forecasts predict, NDBC reports actual.
- **NOAA WaveWatch III via OpenDAP/THREDDS** — global wave model output (the same model OpenMeteo and others ingest). Free, no key. Heavy: NetCDF over OPeNDAP, requires a NetCDF client and lat/lon subsetting. Only worth the integration effort if we ever want to ship our own swell-to-break translator (the surf module noted in category-7 future-work).

### Open threads (separate from the provider research)

- **Great Lakes / inland-water operators** — what does the marine page look like for them? Tides ≈ irrelevant; lake-effect, seiche, wave height from Great Lakes buoy network are the relevant data. May warrant a "freshwater" mode of the marine page.
- **Surf forecast — future module exploration.** How do Surf-Forecast.com / Surfline build their forecasts? (Generally: global wave model output like NOAA WaveWatch III, refracted through local bathymetry and break orientation.) Is a "swell-to-break translator" something Clear Skies could ship as a first-class module in a later phase? Note this as Phase 6+ exploration, not v0.1.

## 8. Webcam + timelapse + radar · ✅ (decided 2026-05-02)

### What exists today

Home page right column is a **3-tab switcher** ("what does it look like outside") combining three distinct content types into one panel.

| Tab | Source | Refresh | Notes |
|---|---|---|---|
| **Radar** | `<iframe>` to **Windy.com** embed (via `radar_html` extra; `aeris_map=0` so Aeris radar service not used) | Page-load + optional `reload_images_radar` (default 300s) | Defaults to a Windy embed centered on station lat/lon; operator can swap to Aeris radar tiles or any other iframe. Light/dark variants supported. |
| **Webcam** | `<img src="webcam/weather_cam.jpg">` — local file written by an Amcrest IP camera (per About page) | 60s via JS `reloadWebcam()` | Click-through to full-size image. Single still, not a stream. |
| **Webcam Timelapse** | `<video>` loading `/webcam/weewx_timelapse.mp4` | Reload every 15 min | Pre-rendered MP4 stitched offline (presumably by an external cron job — not a weewx feature). |

User design notes (DESIGN-INSPIRATION-NOTES.md) endorse the 3-tab grouping ("what does it look like outside") as a keep-it pattern.

### Initial Claude proposal — REJECTED 2026-05-02

Claude's first pass proposed (a) keep the 3-tab model, (b) ship two radar modes (embed for any iframe + native Leaflet/MapLibre + RainViewer tiles), (c) generic webcam image-URL tile, (d) generic timelapse video-URL tile. **The radar piece was the problem:** Claude defaulted to Windy and RainViewer without verifying global coverage and without checking what radar surfaces our existing 5 ADR-007 providers ship. Same parochialism error as the cat 7 first pass.

The webcam + timelapse halves of the proposal were not rejected; just the radar half needs research.

### User directive (captured 2026-05-02)

**Research radar provider options for global coverage**, free only. Specifically:

- What radar / precipitation imagery do our 5 ADR-007 providers offer? (Aeris, NWS, OpenMeteo, OpenWeatherMap, Weather Underground.) Free-tier only — paid endpoints don't help end-users self-funding per ADR-006.
- What standalone radar providers exist that cover regions our 5 ADR-007 providers don't? (Goal: cover most of the world.)
- What's the technical format per source? — tile URLs (XYZ-tile, WMS, WMTS), iframe embed only, pre-rendered animated GIFs, etc. — because that determines whether we can render natively (Leaflet overlay we control) or are stuck with iframe embeds.

Output: a per-region radar-coverage picture so the v0.1 default isn't accidentally US/Europe-only.

### Research findings (radar — captured 2026-05-02)

**Part A: ADR-007 providers — radar offerings (free-tier perspective)**

| Provider | Radar offering | Format | Coverage | Free-tier? | Animation | Notes |
|---|---|---|---|---|---|---|
| **Aeris (Xweather)** | Radar tiles via Xweather Maps API (separate product line from Weather API), e.g. `https://maps.api.xweather.com/{client_id}_{secret}/radar/{z}/{x}/{y}/current.png` and `flat,radar,admin` static composites | XYZ tiles + static PNG composites; SDK + Leaflet/Mapbox plugins | Global (NEXRAD-strong in US; international radar mosaics elsewhere) | **Public pricing gated** — quote-based. **PWS contributor track is the realistic free path:** AerisWeather Contributor Plan via PWSWeather (1,000 Weather API/day + 3,000 Map units/day) when operator uploads PWS data 22+ hr/day for 4+ days. Permits commercial use, requires attribution. | Yes (past frames + Aeris's own short-range nowcast on paid tiers) | Strongest single global tile source we'd actually have a path to — but only for operators who ship their PWS data to PWSWeather. Not a default we can assume. |
| **NWS (api.weather.gov)** | None on the OpenAPI surface — `/radar/stations` returns metadata only, no imagery | n/a | n/a | n/a | n/a | NWS radar imagery lives on **separate** NOAA endpoints, not the api.weather.gov OpenAPI. See standalone row "NOAA MapServer / IEM" below. |
| **OpenMeteo** | **None.** Forecast model API only, no imagery service. | n/a | n/a | n/a | n/a | Verified: zero radar/tile surface in the docs. |
| **OpenWeatherMap** | Weather Maps 1.0 — `precipitation_new` layer at `https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid={key}`. Weather Maps 2.0 (`/maps/2.0/weather/{op}/{z}/{x}/{y}`) supports historical/forecast time-stepping. | XYZ tiles | Global model-derived precipitation (NOT true radar mosaic — it's the precipitation forecast field, smoothed) | **Maps 1.0 free** with the standard OWM API key; Maps 2.0 historical/forecast time-stepping is paid. Free tier rate-limited per the standard OWM caps. | Static current frame on free tier; time-stepping on Maps 2.0 paid only. | This is **model precip, not radar reflectivity** — useful as a global fallback when no real radar exists, but it lies through the cell gaps that real radar would show. Acknowledge it explicitly in UI. |
| **Weather Underground** | **None on the public PWS API.** | n/a | n/a | n/a | n/a | WU exposes a wundermap product on its own site, but no documented free third-party tile surface. |

**Verdict on Part A:** Of our five locked providers, only OWM offers a no-strings-attached XYZ tile any operator can use day-one — and it's model precip, not real radar. Aeris radar is real but gated behind the PWSWeather contributor track. The other three offer nothing. **The radar load cannot ride on ADR-007 providers; we will need at least one standalone radar provider as a first-class data source.**

**Part B: Standalone radar providers**

| Provider | Format | Coverage | Free-tier? | Animation | Attribution | Integration complexity |
|---|---|---|---|---|---|---|
| **RainViewer** (personal/educational) | XYZ tiles `{host}{path}/{size}/{z}/{x}/{y}/{color}/{options}.png` — paths fetched from `https://api.rainviewer.com/public/weather-maps.json` | Global mosaic (radar gaps shown black) | **Yes — but downgraded for personal use.** Past 2 hr (12 frames at 10-min intervals), **no nowcast on personal tier**, max zoom 7 (512 px tiles), Universal Blue palette only, PNG only. Commercial API discontinued Jan 2026. | Past frames yes; **no forecast/nowcast on free personal tier in 2026** | Required: link to https://www.rainviewer.com/ as data source | Easy — point Leaflet at the URL pattern. |
| **Windy.com Map Forecast (Leaflet plugin)** | Leaflet plugin you initialize with `windyInit({key, ...})`. Renders Windy's full layered map inside your page. Not raw tile URLs you compose with — the plugin owns its own map canvas. | Global | **Free** with API key, "unrestricted traffic" but advertising shown, GFS model + wind/rain/clouds/temp/pressure/currents/waves layers only. Paid (~720 USD/yr) unlocks more models/layers/branding. | Yes — animated forecast frames via the plugin | Windy logo/advertising visible on free tier | Medium — plugin-style, not a pure tile composability story. We don't fully control the look. |
| **Windy.com iframe embed** | `<iframe>` widget | Global | Free, no key | Yes | Windy branding | Trivial integration; we cannot theme it, can't compose with our other map layers. |
| **NOAA MapServer / IEM (US)** | (a) NOAA `mapservices.weather.noaa.gov/eventdriven/.../radar_base_reflectivity` ArcGIS MapServer + (b) Iowa Environmental Mesonet WMS-T at `https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r-t.cgi?` (layer `nexrad-n0r-wmst`) | **CONUS only** for IEM n0r mosaic; NOAA MRMS service additionally covers Alaska, Hawaii, Caribbean, Guam, parts of Canada | **Yes, freely available, no key** | 5-min refresh; WMS-T supports time-stepping | None explicitly required; courteous to credit NOAA / Iowa State | Medium — WMS not XYZ, but Leaflet has a WMS layer class. Well-documented. |
| **UK Met Office Weather DataHub** | API/file delivery; UK + NW European composite rainfall radar products | UK + Ireland + NW Europe | Free for low-volume users; charged at higher volumes; registration required | Yes (real-time products) | Required (Met Office attribution per terms) | Medium — DataHub products are file-based, not native tile URLs; would need a proxy to serve as tiles. |
| **Météo-France (portail-api / meteo.data.gouv)** | Open data portal APIs; precipitation + radar mosaics (Wideumont radar added to mosaic March 2026) | France + adjacent EU | **Free** with portal account; quotas doubled Jan 2026 | Yes | Required | Medium — registration required; format mostly file/object, not turnkey tiles. |
| **DWD (Germany) — RADOLAN** | (a) Open Data Server `https://opendata.dwd.de/weather/radar/radolan/rw/` (10-min adjusted product); (b) DWD GeoWebService (OGC WMS/WFS) | Germany | **Yes, free, no key** | Yes (10-min cadence) | Standard German federal open-data attribution | Medium-easy via the WMS endpoint; raw RADOLAN files need parsing. |
| **BoM Australia** | Anonymous FTP at `ftp://ftp.bom.gov.au/anon/gen/` — animated GIFs / pre-rendered radar images | Australia | Free for personal/internal-org use; **NOT for commercial use**; no public REST/WMS/tile API | GIF loops (pre-animated) | Required; non-commercial restriction is the binding term | Hard — FTP image polling, no native tile path. iframe to bom.gov.au radar pages is the practical route for hobbyists. |
| **Environment Canada — MSC GeoMet** | OGC WMS at `https://geo.weather.gc.ca/geomet` — radar mosaic layers (e.g. `RADAR_1KM_RSNO`, `RADAR_1KM_RRAI`, etc.) | Canada (national mosaic) | **Yes, free, open license, commercial use OK with attribution** | Yes — WMS-T time dimension | Required: identify Environment and Climate Change Canada as the source | Easy — clean WMS, well-documented. The cleanest national-met radar feed of the bunch. |
| **EUMETNET OPERA** | Pan-European composite, ODIM HDF5 every 15 min. EU High-Value Datasets regulation now mandates free open-license API access; ORD (Open Radar Data) API + MeteoGate UI in rollout. | Europe (most member states) | **Yes, free under HVD regulation** — but API rollout still in progress in 2026 | Yes (15-min cadence) | EUMETNET OPERA attribution | Hard short-term — HDF5 not tiles; would need a server-side renderer. Watch this — could become *the* European answer once tile services land. |
| **JMA Japan (via Mapbox Japan Weather Layers)** | Vector/raster tilesets at `mapbox.weather-jp-nowcast` (zoom 0–9, 250m–1km, 5-min cadence, 13 time bands = present + 60-min forecast) | Japan | **Mapbox-hosted — Mapbox free tier applies** (50K monthly tile loads on free Mapbox account, JMA data licensing pre-cleared). Native JMA open-data tile equivalent: nowcast pages exist on jma.go.jp but no documented public XYZ. | Yes — 5-min increments past + 60-min forecast | Both Mapbox attribution AND JMA source attribution | Medium — requires Mapbox account; not a pure no-key path. |
| **KNMI Netherlands** | KNMI Data Platform — WMS endpoints for radar reflectivity composites + 5-min nowcast up to 2hr (`radar-reflectivity-composites-2-0`, `radar-forecast-2-0`) | Netherlands + surrounding | **Free**, anonymous API key available through July 2026, registration after that | Yes — 5-min cadence, 2-hr nowcast | KNMI attribution | Easy — clean WMS, listed in the data platform tag-search for `WMS`. |
| **MeteoSwiss** | OGD (open data) since May 2025 — currently file download / STAC API. **Per-query API & WMS not available before Q2 2026.** | Switzerland | **Free** | Yes (file products) | Required | Hard short-term (file polling). Watch for Q2-2026 API rollout. |
| **MetService NZ** | Open Access Observational Data set (radar imagery included) — pre-rendered images | New Zealand | Free for personal/professional/commercial use per Open Access policy; not a tile/WMS service | GIF loops | Required (MetService attribution) | Medium — image polling. Iframe to metservice.com radar page is the practical fallback. |
| **INMET Brazil** | INMET network has limited radar; the actual Brazilian radar source is the Air Force aviation weather service (REDEMET — `www.redemet.aer.mil.br`). No documented public tile API. | Brazil (partial) | Public web visualization yes; no documented developer tile/WMS surface | Web viewer | n/a | Hard — no tile path. iframe to REDEMET is the practical fallback. |
| **SAWS South Africa** | No documented public radar tile/WMS API. Commercial AfriGIS API exposes thunderstorm/lightning, not radar tiles. | South Africa | Web viewer on weathersa.co.za only | Web viewer | n/a | Hard — iframe fallback only. |
| **Mexico (CONAGUA / SMN)** | Public radar visualizers at `smn.conagua.gob.mx/tools/GUI/visor_radares_v3/` — no documented public tile/WMS API | Mexico | Public web viewer | Web viewer | n/a | Hard — iframe fallback only. |
| **India (IMD Mausam)** | Radar imagery on `mausam.imd.gov.in` — no documented public tile/WMS API | India | Public web viewer | Web viewer | n/a | Hard — iframe fallback only. |

**Part C: Regional coverage synthesis**

For each region, the question is: **what's the best free native-tile (XYZ/WMS) path Leaflet can render directly?** Iframe fallback = we lose theming, dark/light, layer composition.

| Region | Best free native-tile option | Best free embed/iframe fallback | Recommended v0.1 default |
|---|---|---|---|
| **USA (CONUS)** | IEM NEXRAD WMS-T (`mesonet.agron.iastate.edu/.../n0r-t.cgi`) — true radar, 5-min, free, no key | radar.weather.gov | **IEM WMS-T** (with NOAA MRMS MapServer as alt option) |
| **USA (AK, HI, PR, Guam)** | NOAA MRMS MapServer (`mapservices.weather.noaa.gov`) extends to AK/HI/Caribbean/Guam | radar.weather.gov | NOAA MRMS MapServer |
| **Canada** | MSC GeoMet WMS (`geo.weather.gc.ca/geomet`) — clean, time-enabled, commercial-OK | weather.gc.ca | **MSC GeoMet WMS** — model citizen of national radar feeds |
| **Mexico** | None native | smn.conagua.gob.mx visor + RainViewer mosaic (gappy on Mexico) | RainViewer mosaic + iframe to SMN visor as alt |
| **UK** | Met Office Weather DataHub (file-based, needs a proxy) | metoffice.gov.uk radar page | RainViewer (covers UK) for v0.1; DataHub if/when we ship a proxy |
| **France** | Météo-France portail-api (file-based, needs registration + proxy) | meteofrance.com | RainViewer for v0.1; Météo-France via portal once we proxy |
| **Germany** | DWD GeoWebService WMS (RADOLAN) — free, no key, 10-min cadence | dwd.de radar page | **DWD WMS** — clean native path |
| **Italy** | None national; some regional ARPA services exist but fragmented | iframe to regional ARPA pages | RainViewer mosaic |
| **Spain** | AEMET OpenData exists but radar tile surface not standard; out of scope of this research pass | iframe to aemet.es | RainViewer mosaic |
| **Scandinavia (NO/SE/FI/DK)** | Pan-European: EUMETNET OPERA (HDF5, not yet a tile service); national met services have open-data programs of varying maturity | Local met-service iframes | RainViewer mosaic (Europe-strong); revisit when OPERA ORD API lands |
| **Eastern Europe** | EUMETNET OPERA (when tile API ships) | Local met-service iframes | RainViewer mosaic |
| **Russia** | None free that we found | n/a | RainViewer mosaic (very gappy across Russian interior); accept "no radar" outcome for many lat/lons |
| **China** | None public/free; CMA radar is state-controlled | n/a | RainViewer mosaic (very gappy); accept "no radar" |
| **Japan** | Mapbox Japan Weather Layers (Mapbox free tier; JMA data) — 5-min, present + 60-min forecast | jma.go.jp/bosai/en_nowc | **Mapbox JMA layers** (operator brings Mapbox key) — best-in-class for that region |
| **India** | None public/free for tiles | mausam.imd.gov.in iframe | RainViewer mosaic + iframe fallback |
| **Southeast Asia (TH, VN, ID, MY, PH, SG)** | None pan-regional free | National met-service iframes | RainViewer mosaic |
| **Australia** | None native (BoM is FTP non-commercial) | bom.gov.au radar pages | **iframe to bom.gov.au** (RainViewer is gappy across the Australian interior) |
| **New Zealand** | None native (MetService is image polling) | metservice.com radar | iframe to metservice.com |
| **Brazil** | None native | REDEMET aviation radar viewer | RainViewer mosaic + REDEMET iframe |
| **Argentina, rest of South America** | None native | Local met-service iframes if any | RainViewer mosaic (gaps significant) |
| **Sub-Saharan Africa** | None native | iframe to weathersa.co.za (covers South Africa only) | RainViewer mosaic (very limited African radar coverage); accept "no radar" for most of the continent |
| **North Africa / Middle East** | None native | n/a | RainViewer mosaic (sparse); accept "no radar" |

### Top-line take

**Native-tile coverage is good for: USA, Canada, Germany, Japan (with caveats), Netherlands, and partially the UK/France (with proxy work).** Native tiles are notably absent for Australia, NZ, Latin America, Africa, Russia, China, and most of Asia outside Japan.

**Recommended default architecture for Clear Skies v0.1:**

1. **Per-operator-region default at setup**, picked by lat/lon:
   - USA → IEM WMS-T (CONUS) or NOAA MRMS (AK/HI/PR)
   - Canada → MSC GeoMet WMS
   - Germany → DWD GeoWebService WMS
   - Netherlands → KNMI Data Platform WMS
   - Japan → Mapbox JMA layers (operator must add Mapbox key)
   - Australia / NZ → iframe to BoM / MetService (with explicit "iframe mode" warning in UI)
   - Everywhere else → **RainViewer global mosaic** (XYZ tiles, free personal use, attribution required, but downgraded vs. its 2024-era capability — past 2hr only, no nowcast, zoom ≤7, fixed palette)

2. **RainViewer becomes Clear Skies' default first-class radar provider** for any operator outside the named-WMS regions. This is a real architectural commitment — RainViewer's terms (personal-use only, attribution-required, hosted by a third party that just discontinued its commercial tier in Jan 2026) need to be vendored into our docs as a known dependency risk.

3. **Iframe-embed primitive must ship in v0.1** — Australia, NZ, BoM, mainland-China-adjacent regions, and most of Africa/South America have no native-tile path. The "embed-mode question" (open thread #1 above) is forced by this research. ADR-needed: do we ship `<iframe>` as a first-class radar mode, or do we tell those operators "no radar in v0.1"? Recommendation is **ship the iframe**, gate it behind a per-tile opt-in to keep the trust model honest (operators choose what to embed; we don't ship iframes by default).

4. **No ADR-007 provider carries the radar load by itself.** OWM `precipitation_new` is the only universal-key tile any operator already has — but it's model precip, not radar. Worth offering as a "global precip-forecast overlay" mode separate from "radar reflectivity" mode, with explicit UI labeling so an operator over the Pacific doesn't think OWM is showing real returns.

**Sources cited:** xweather.com/maps · openweathermap.org/api/weather-map-2 + /api/weathermaps · openweathermap.org/api/global-precipitation-map · radar.weather.gov · mesonet.agron.iastate.edu/docs/nexrad_mosaic · mapservices.weather.noaa.gov/eventdriven/.../radar_base_reflectivity · rainviewer.com/api.html + /api/weather-maps-api.html + /terms.html + /blog/weather-radar-apis-2025-overview.html · github.com/rainviewer/rainviewer-api-example · forum.flowx.io (RainViewer discontinue Jan 2026 thread) · api.windy.com + github.com/windycom/API · pwsweather.com/contributor-plan + signup.xweather.com/pws-contributor · datahub.metoffice.gov.uk · portail-api.meteofrance.fr + confluence-meteofrance.atlassian.net OpenData space · opendata.dwd.de + dwd.de/EN/ourservices/opendata · bom.gov.au/catalogue/data-feeds + reg.bom.gov.au/climate/data-services/radar-sat · canada.ca MSC GeoMet + geo.weather.gc.ca/geomet + eccc-msc.github.io/open-data · eumetnet.eu/observations/opera-radar-animation + RODEO project · jma.go.jp/bosai/en_nowc + docs.mapbox.com/data/tilesets/reference/japan-weather-layers · dataplatform.knmi.nl + developer.dataplatform.knmi.nl · meteoswiss.admin.ch/services-and-publications/service/open-data + opendatadocs.meteoswiss.ch · about.metservice.com/our-company/about-this-site/open-access-data · smn.conagua.gob.mx/tools/GUI/visor_radares_v3 · mausam.imd.gov.in · weathersa.co.za + developers.afrigis.co.za

### Webcam + timelapse half (Claude's proposal — pending user review, not rejected)

These are independent of the radar research and can move forward in parallel.

- **Webcam tab** — generic image-source tile. Operator configures a URL (HTTP-fetchable). Renders an `<img>`. Configurable refresh interval (default 60s). Click-to-expand. Optional caption/credit line.
- **Timelapse tab** — generic video-source tile. Operator points it at a `.mp4` URL. Renders a `<video>` with browser controls. Configurable reload interval. **No expectation Clear Skies generates the timelapse** — operator's responsibility (cron + ffmpeg). Optional Phase 6+ companion service `clearskies-timelapse` if demand surfaces.
- **Webcam URL HTTPS validation** — configuration UI warns on non-HTTPS URLs (mixed-content blocked by browser on HTTPS dashboard).
- **Timelapse staleness indicator** — tile shows `Last-Modified` header age (e.g., "timelapse from 2 hours ago") so a broken cron doesn't silently serve a week-old video.
- **Each tab independently hide-able** per universal pattern. If all three hidden, panel disappears.

### Decisions captured 2026-05-02

- **No satellite-derived precipitation layer.** User rejected adding NASA IMERG / EUMETSAT MPE as a fallback for regions without ground radar. Some regions (Russia, Chile, most of Africa outside the 8 RainViewer-covered countries, parts of the Middle East) will simply show "no radar available for your region" in v0.1. Honest absence beats labeled-but-misleading satellite-precip.
- **Provider code architecture: internal plug-in-style modules** (cross-cutting decision, see threads section above). Each radar provider (Aeris-PWS, RainViewer, IEM, MSC GeoMet, DWD, KNMI, etc.) is a self-contained module in our codebase. Adding/removing a provider doesn't require surgery on shared code.
- **No default radar provider.** Operator picks at setup. Setup wizard MAY filter the provider list to "those covering your station's location" as a hint, but never pre-selects. If no available provider covers the operator's region, the radar tab cannot be enabled. Rationale (user-stated): no provider gets default-placement without paying for it; even then no, this isn't a commercial product.
- **Alerts overlay opt-in.** Default render = single radar layer to conserve Aeris contributor map-units budget. Operator can enable a separate alerts overlay; UI surfaces that this doubles map-unit consumption.
- **Iframe rendering is encapsulated inside individual provider plugins** — the operator never pastes iframe HTML. They pick a provider from the list (e.g., "MetService NZ", "BoM Australia"), and if that provider works via iframe under the hood, the plugin handles it internally. No generic "iframe primitive" tile type. Replaces the prior proposal where operators would paste raw iframe code.
- **Lightning map: deferred.** Not in v0.1. Maybe Phase 6+ if demand surfaces (Blitzortung community network is the obvious free global source).

### Webcam + timelapse — final v0.1 model (decided 2026-05-02)

- **Webcam:** single image file. Operator config: show yes/no; path to the image; refresh interval; optional caption.
- **Timelapse:** single video file. Operator config: show yes/no; path to the video; reload interval; `Last-Modified` staleness indicator displayed on the tile so a broken cron doesn't silently serve stale content.
- **Multi-camera support: deferred** to Phase 6+ if anyone asks. v0.1 is one camera per station.
- Each tab independently hide-able per universal pattern; if all three (radar, webcam, timelapse) are hidden, the panel disappears.
- **Other "what does it look like outside" content** beyond the 3 tabs (satellite imagery, lightning map, all-sky camera) — open question; user input needed once radar is settled.

### AerisWeather Contributor Plan — verified scope (2026-05-02)

Research pass to settle (a) whether contributor-tier radar tiles can replace RainViewer as the global default in cat 8, and (b) whether contributor-tier marine endpoints can reopen cat 7. Sources: PWSWeather contributor-plan page, Xweather signup page, Xweather docs (endpoints, maps, accesses), Xweather maritime-launch blog post.

**Endpoint / Map layer inclusion table** (Y = listed on contributor-plan page; N = not listed / verified excluded; ? = could not verify):

| Endpoint family / Map layer | Included on Contributor tier? | Source |
|---|---|---|
| Weather API `/observations` | Y | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/observations/summary` | Y | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/observations/archive` | Y | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/forecasts` (7-day daily, 24-hr hourly) | Y | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/alerts` | Y | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/sunmoon` | Y (listed as "Sun & Moon") | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/places` | Y | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/airquality` | Y | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/conditions` | N (not listed on contributor-plan page) | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/maritime` | **N — Flex-only** | https://www.xweather.com/blog/article/introducing-the-new-maritime-api-endpoint ("available to all Flex subscribers") |
| Weather API `/tides`, `/tides/stations` | N (not listed on contributor-plan page) | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/lightning` | N (also carries 10x billing multiplier on paid plans; "Lightning data beyond past 5 minutes requires Lightning Enterprise add-on") | https://www.xweather.com/docs/weather-api/endpoints |
| Weather API `/earthquakes` | N (not listed on contributor-plan page) | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/normals`, `/records` | N (not listed) | https://www.pwsweather.com/contributor-plan/ |
| Weather API `/stormcells`, `/stormreports` | N (not listed) | https://www.pwsweather.com/contributor-plan/ |
| Maps: `radar` (regional/US NEXRAD, plus PR/Guam/CA/AU/JP/KR/DE/IE/UK/CH/BE/NL/Northern France) | Y (listed as "Radar") | https://www.pwsweather.com/contributor-plan/ + https://www.xweather.com/docs/maps/layers |
| Maps: `radar-global` (global radar/satellite-derived mosaic) | Y inferred — contributor-plan page lists "Radar" without distinguishing; layer code `radar-global` exists in the layer catalog with no tier restriction noted | https://www.xweather.com/docs/maps/layers (could not find explicit confirmation that `radar-global` is on contributor tier — treat as **likely yes, verify before relying on it**) |
| Maps: `satellite`, `satellite-geocolor`, `satellite-infrared-color` | Y (listed as "Satellite") | https://www.pwsweather.com/contributor-plan/ |
| Maps: `alerts` overlay | Y (listed as "Alerts") | https://www.pwsweather.com/contributor-plan/ |
| Maps: `observations` overlays (stations, temp, wind, etc.) | Y (listed as "Observations") | https://www.pwsweather.com/contributor-plan/ |

**Rate limits, commercial use, attribution, qualifying conditions, geography, auth**

The contributor-plan landing page states **1,000 Weather API accesses/day (100/min)** and **3,000 map units/day (100/min)**, separately metered ([source](https://www.pwsweather.com/contributor-plan/)). The PWS Contributor signup page summarizes this differently as "5,000 API and Maps accesses/day (100/minute max)" ([source](https://signup.xweather.com/pws-contributor)) — the two pages disagree; the contributor-plan page is more granular and is the conservative number to plan against. A "map unit" is well-defined: **one 256×256 raster tile × one layer = one map unit**; combining layers multiplies the cost (12 tiles × 2 layers = 24 units) ([source](https://www.xweather.com/docs/maps/getting-started/accesses)). Commercial use is permitted ("The AerisWeather Contributor Plan permits commercial usage" — [source](https://www.pwsweather.com/contributor-plan/)). Attribution is required for public-facing projects but the exact "Powered by …" wording is in the PWSWeather FAQs which weren't extractable via WebFetch — **treat exact wording as unverified**, plan to display a "Powered by Xweather" / "Data: Xweather" credit on every contributor-tier surface and confirm phrasing before launch. Qualifying conditions: **active PWSweather account contributing quality data ≥22 hr/day**, "one subscription per PWS Contributor", "automatically renews monthly, if conditions are met" ([source](https://signup.xweather.com/pws-contributor)) — this is an **ongoing requirement, not one-time**: a station that stops uploading loses the plan at the next monthly renewal. New stations also require up to 4 days of QA pass-through before access is granted ([source](https://www.pwsweather.com/contributor-plan/)). No geographic restriction on the contributor tier itself was stated; the underlying layer catalog has its own per-layer geography (e.g., `radar` regional list above; `satellite-visible` and `satellite-water-vapor` are NA/Central America/Pacific/Atlantic only) ([source](https://www.xweather.com/docs/maps/layers)). Auth: standard Xweather `client_id` + `client_secret` (a.k.a. access ID + secret key), same model as paid plans, both Weather API and Maps API use the same credential pair, obtained by associating the PWSWeather user ID at signup ([source](https://signup.xweather.com/pws-contributor) + [source](https://www.aerisweather.com/support/docs/api/getting-started/authentication/)). Old `api.aerisweather.com` keys continue to work against `data.api.xweather.com`.

**Bottom-line answers to the two decision questions**

- **Does the contributor tier include radar tiles via the Maps API?** **Yes — partial confirmed, partial inferred.** Regional radar (`radar` layer with US NEXRAD + the listed international regions) is explicitly included via the contributor-plan page's "Radar" line item. The dedicated `radar-global` layer (radar+satellite-derived mosaic for true worldwide coverage) is **not explicitly called out by code** on the contributor-plan page; the page just says "Radar." It's most likely included because it's part of the same imagery family, but the docs do not confirm this in writing. **Recommendation:** before swapping out RainViewer in cat 8, hit `radar-global` with a real contributor key and confirm a 200 + tile bytes (a 403 would force the question). At 3,000 map units/day with single-layer radar = 3,000 tiles/day, a 4×4 viewport refreshing every 5 min for 12 hours/day = ~2,300 tiles/day, which fits — barely. Multi-layer (radar + alerts overlay) doubles that and busts the budget.

- **Does the contributor tier include `/maritime` and `/tides` endpoints?** **No.** `/maritime` is explicitly Flex-only per the Xweather launch blog ("available to all Flex subscribers" — [source](https://www.xweather.com/blog/article/introducing-the-new-maritime-api-endpoint)). `/tides` and `/tides/stations` are not on the contributor-plan page's endpoint list. Cat 7 marine **cannot be reopened on the Aeris contributor track**; the deferral stands unless the user accepts a paid Flex subscription as a prerequisite, in which case the rule that "PWS-contributor tracks are the default lens for free" is broken for this category and the marine page becomes a paid-tier feature.

### Targeted radar research — gap regions (2026-05-02)

Follow-up pass to close gaps the prior survey grouped too coarsely (Philippines, China, Africa, plus several others). Each row researched fresh against the listed source URLs; "no good option" rows are kept rather than silently dropped. **Distinguish ground radar from satellite-derived precipitation estimates** — both are useful in the dashboard, but mislabeling satellite precip as "radar" repeats the OWM `precipitation_new` mistake. RainViewer country counts cited below come from a single source ([rainviewer.com/coverage.html](https://www.rainviewer.com/coverage.html)) snapshot 2026-05-02.

#### Country-by-country findings (radar / national-met sources)

| Country / Region | Source | Format | Free? | Animation | Integration complexity | Verdict |
|---|---|---|---|---|---|---|
| **Philippines** | PAGASA HFDR product page + PANaHON portal — [pagasa.dost.gov.ph/radar](https://www.pagasa.dost.gov.ph/radar), [panahon.gov.ph](https://www.panahon.gov.ph/) | No documented public PNG/tile/WMS endpoint exposed; PANaHON is a JS web app, no embed widget | Yes (informational use); no machine API documented | Yes inside the app, not extractable | Iframe-of-the-portal is the only realistic embed; no tiles | **Use RainViewer** (Philippines covered — multiple PAGASA radars in their network). Iframe of PANaHON acceptable as fallback. |
| **China (mainland)** | CMA — no public API; private services Caiyun, Moji | Caiyun has a documented Weather API including "forecasted weather radar images and data matrices" but **requires API key** and demo token is severely rate-limited ([open.caiyunapp.com](https://open.caiyunapp.com/ColorfulClouds_Weather_API)). No free tile-server tier verified. | No truly free public radar. RainViewer however covers China with **197 radars** ([rainviewer.com/coverage.html](https://www.rainviewer.com/coverage.html)). | RainViewer: yes | RainViewer: drop-in tile layer | **Use RainViewer.** Caiyun would only matter if a paid track is opened. |
| **Hong Kong** | HKO Open Data — [hko.gov.hk/en/abouthko/opendata_intro.htm](https://www.hko.gov.hk/en/abouthko/opendata_intro.htm), API doc PDF v1.13 [data.weather.gov.hk/weatherAPI/doc/HKO_Open_Data_API_Documentation.pdf](https://data.weather.gov.hk/weatherAPI/doc/HKO_Open_Data_API_Documentation.pdf) | Static PNG radar images (64/128/256 km ranges) at [hko.gov.hk/en/wxinfo/radars/radar256n.htm](https://www.hko.gov.hk/en/wxinfo/radars/radar256n.htm) etc.; KML export referenced. PDF API doc lists weather products — image URLs are reachable but doc extraction was lossy. | Yes — open data program, free for commercial + non-commercial use ([hko.gov.hk Open Data intro](https://www.hko.gov.hk/en/abouthko/opendata_intro.htm)) | 64 km updates every 6 min; 128/256 km every 12 min ([hko.gov.hk radar page](https://www.hko.gov.hk/en/wxinfo/radars/radar_range1.htm)) | Static-image polling (low) or iframe of the HKO radar page | **HKO direct PNG polling is viable** for an HK-localized view. For the dashboard's global lens, RainViewer is simpler. |
| **Taiwan** | CWA Open Data — [opendata.cwa.gov.tw](https://opendata.cwa.gov.tw/index) | Datasets exist (radar composites, satellite); registration required; public dataset codes documented | Free with member registration; commercial use governed by CWA terms | Yes for some products | Static-image / WMS-style download; **registration adds friction** vs anonymous tiles | **Use RainViewer** (Taiwan radars are in their global mosaic via aggregated sources); CWA Open Data is a fallback if a TW-specific page is built. |
| **Indonesia** | BMKG — [inderaja.bmkg.go.id](https://inderaja.bmkg.go.id/Radar/Indonesia_ReflectivityQCComposite.png) (national reflectivity composite PNG, found via [bmkg.go.id/cuaca/radar/Indonesia](https://www.bmkg.go.id/cuaca/radar/Indonesia)) | Single national PNG; no documented refresh cadence on the page | Page declares © 2026 BMKG; no explicit license. BMKG's Open Data terms (separate site [data.bmkg.go.id](https://data.bmkg.go.id/)) require attribution. **BMKG explicitly says radar is "only accessible through the Info BMKG application"** in the web UI — the inderaja PNG is reachable but not officially blessed for embed. | Single PNG, no animation | Image-poll a single URL — trivial | **Use RainViewer** (Indonesia: 43 radars). The BMKG PNG is unofficial-feeling; don't anchor on it. |
| **Thailand** | TMD — [weather.tmd.go.th](https://weather.tmd.go.th/), API portal [data.tmd.go.th/api/index1.php](https://data.tmd.go.th/api/index1.php) | Per-radar-station PHP pages; no documented composite tile API | Forecast/observation API requires registration; radar imagery undocumented for embed | Yes inside per-station pages | Iframe per station or scrape | **Use RainViewer** (Thailand: 41 radars). |
| **Vietnam** | VNMHA / NCHMF — [vnmha.gov.vn/nchmf-new/show-anh-radar](http://vnmha.gov.vn/nchmf-new/show-anh-radar) | Web page only; no public tile/WMS verified | No documented terms | Site-side animation | Iframe-only | **Use RainViewer** (Vietnam: 10 radars). |
| **Malaysia** | MET Malaysia — [met.gov.my/en/pencerapan/radar-malaysia/](https://www.met.gov.my/en/pencerapan/radar-malaysia/) | Single GIF: `/data/radar_malaysia.gif` | "All Rights Reserved" footer; no open-data license | No (single image) | Image-poll trivial but legally murky given ARR | **Use RainViewer** (Malaysia is in their Asia coverage list). |
| **Singapore** | NEA via [data.gov.sg](https://data.gov.sg/collections/1456/view) | Real-time station readings + 2hr/24hr/4day forecasts; **no radar tile/image API documented**. NEA's own SG radar product is app-only. | API free with attribution | n/a | n/a (no radar) | **Use RainViewer** for radar; NEA API for stations/forecast. |
| **India** | IMD Mausam — [mausam.imd.gov.in/responsive/radar.php](https://mausam.imd.gov.in/responsive/radar.php), animation [mausam.imd.gov.in/responsive/radar_animation.php](https://mausam.imd.gov.in/responsive/radar_animation.php) | Per-station GIFs, e.g. `Radar/animation/Converted/DELHI_MAXZ.gif` (and SRI variant); ~30 radar sites | "Government of India" page; no explicit reuse license; widely scraped | Yes — animated GIF per station | Image-poll per-station GIF (no national mosaic via this route) | **RainViewer is cleaner for a national view** (India: 27 radars). IMD GIFs are usable for a station-zoom view if added later. |
| **Russia** | Hydrometcenter — [meteoinfo.ru/en/radanim](https://meteoinfo.ru/en/radanim) | Single animated GIF: `/hmc-output/rmap/phenomena.gif`, last 3 hours, European Russia only | © 2026 Hydrometcenter; **no explicit reuse license**. CC-style policy not stated. | Yes — server-rendered GIF animation | Image-poll trivial; license risk for a public site | **Genuinely no good free option for redistributable Russia radar.** RainViewer **does not list Russia** ([coverage.html](https://www.rainviewer.com/coverage.html)). The meteoinfo GIF is technically reachable but legally ambiguous and Europe-only. Best Clear-Skies posture: fall back to **EUMETSAT MPE / NASA IMERG satellite-derived precipitation** (see prose section below) and label clearly as "satellite precipitation, not ground radar." |
| **South Africa** | SAWS — [weathersa.co.za](https://www.weathersa.co.za/), partner API via AfriGIS [developers.afrigis.co.za](https://developers.afrigis.co.za/portfolio/weather-api/) | SAWS site was unreachable from this research session (TLS/cert error); AfriGIS exposes SAWS feeds **commercially, not free** | Partner API requires AfriGIS account; pricing unverified | n/a | n/a | **No free direct radar option confirmed.** Fall back to satellite precip (IMERG/EUMETSAT MPE Southern Africa). RainViewer covers South Africa for a real-radar mosaic. |
| **Egypt** | EMA / NWP — [nwp.gov.eg](http://nwp.gov.eg/), [ema.gov.eg](https://ema.gov.eg/) | Both URLs returned ECONNREFUSED in this session; no documented public radar API | Unknown | Unknown | n/a | **No good option found.** Fall back to EUMETSAT MPE Northern Africa coverage / NASA IMERG. |
| **Morocco** | DMN — [marocmeteo.ma](https://www.marocmeteo.ma/) | No public radar tile/embed documented; SAT24 carries Morocco satellite via own license | None (DMN); SAT24 is third-party, embed terms apply | n/a | n/a | **No good free option from DMN.** Use IMERG/EUMETSAT for satellite precip. |
| **Kenya** | KMD — [meteo.go.ke](https://meteo.go.ke/) | Climate-info Maproom portal; no public radar tiles documented | n/a | n/a | n/a | **Use RainViewer** (Kenya is one of their 8 covered African countries). |
| **Nigeria** | NiMet Weather API — [nimet.gov.ng/weatherapi](https://nimet.gov.ng/weatherapi) | Forecast/seasonal data; **no public radar tile/image** documented (Nigeria is not RainViewer-covered either) | API access undocumented for free public use | n/a | n/a | **No ground-radar option.** Satellite precip (EUMETSAT MPE Western Africa / IMERG) is the only fill. |
| **Tunisia** | INM — [meteo.tn](https://www.meteo.tn/en/national-institute-meteorology) | No public radar tiles/embed documented from INM directly | n/a | n/a | n/a | **Use RainViewer** (Tunisia covered). |
| **Algeria, Ethiopia, Tanzania, Senegal, Ghana** | National mets — quick scan: no public radar API/tile/iframe documented for any of these in 2026 | n/a | n/a | n/a | n/a | **No national-met option.** None covered by RainViewer either (RV's African list = Kenya, Mali, Mauritius, Morocco, Namibia, Réunion, South Africa, Tunisia). Satellite precip is the only fill. |
| **Brazil** | REDEMET API — [api-redemet.decea.mil.br](https://ajuda.decea.mil.br/base-de-conhecimento/api-redemet-produtos-radar/) | REST API returning radar PNGs (`/produtos/radar/{tipo}`) — **requires registration + API key** | Free with registration | Per-radar imagery | API key + image polling; not WMS/XYZ tiles | **Earlier "iframe only" claim was wrong.** REDEMET has a real keyed REST API. RainViewer also covers Brazil with 50 radars. **Default to RainViewer; REDEMET as fallback if a key is registered.** |
| **Argentina** | SMN — [smn.gob.ar/radar](https://www.smn.gob.ar/radar), responsive iframe `/radar/responsiveFrame`, undocumented JSON API at `ws.smn.gob.ar` ([API notes thread](https://foro.gustfront.com.ar/viewtopic.php?t=5252)) | 24 radar stations, Argentina/Centro/Norte mosaics | **Creative Commons Attribution 2.5 Argentina** — explicitly permissive | Yes inside the page | Iframe of `/radar/responsiveFrame` — easy; or scrape unofficial JSON API | **SMN iframe is a legitimate primary**; RainViewer (14 Argentina radars) as fallback. CC-BY-2.5-AR is the cleanest license of any country in this table. |
| **Chile** | DMC — [meteochile.cl](https://www.meteochile.cl/PortalDMC-web/index.xhtml), GeoNode [geonode.meteochile.gob.cl](https://geonode.meteochile.gob.cl) | DMC has launched a GeoNode geospatial portal (catalog + WMS-capable) but radar imagery as a public layer not directly verified in this pass | "Publicly accessible" with citation requested per [DGAC announcement](https://www.dgac.gob.cl/direccion-meteorologica-lanza-plataforma-con-datos-geoespaciales-para-la-toma-de-decisiones/) | Unknown | GeoNode = WMS likely | **Genuinely no good free radar option for Chile.** RainViewer **does not cover Chile** ([coverage list](https://www.rainviewer.com/coverage.html)). DMC GeoNode is a maybe — needs hands-on verification before relying on it. Satellite precip is the safe fallback. |
| **Colombia** | IDEAM — [pronosticosyalertas.gov.co/en/archivos-radar](http://www.pronosticosyalertas.gov.co/en/archivos-radar), Experience Builder viewer at [visualizador.ideam.gov.co](https://visualizador.ideam.gov.co/portal/apps/experiencebuilder/experience/?id=c874489bc74a477c82cb2622a92c4cea), **AWS Open Data: [registry.opendata.aws/ideam-radares/](https://registry.opendata.aws/ideam-radares/)** | 4 C-band dual-pol radars, 5–10 min updates, raw data on AWS S3 | **Open Data on AWS = free, no auth required for raw radar files** | Raw files yes; viewer-side animation | Raw radar requires processing — **not a drop-in tile**. Iframe of the viewer is easier. | **IDEAM AWS open-data is a real find** — but raw radar isn't tile-ready. **Use RainViewer for the tile layer** (Colombia: 8 radars); IDEAM viewer iframe as a deep-dive option. |

#### Satellite-derived precipitation alternatives (cross-region fillers)

These are **not ground radar**. They estimate precipitation from satellite observations (IR + passive microwave). Spatial resolution is coarse (~10 km IMERG, ~3 km MPE) compared to radar (~250 m–1 km), and there's a latency penalty (IMERG Early/Late runs lag observations by 4 hr / 14 hr respectively per [GES DISC catalog](https://www.earthdata.nasa.gov/data/catalog/ges-disc-gpm-3imerghhl-07)). They are appropriate as a **labeled fallback for regions with no ground-radar option** (most of Africa, Russia, Chile, ocean basins) and inappropriate as a substitute for actual radar where radar exists.

- **EUMETSAT EUMETView WMS** — `https://view.eumetsat.int/geoserver/wms` exposes precipitation layers including `msg_fes:h60b` (Blended SEVIRI/LEO MW precipitation, 15-min cadence, lat ±77°, full Africa + Europe + Middle East coverage) and `msg_iodc:h63` (Indian Ocean region precipitation rate). The WMS GetCapabilities reports **"Fees: none"** and **"AccessConstraints: none"** — explicitly free, unrestricted ([source](https://view.eumetsat.int/geoserver/wms?service=WMS&version=1.3.0&request=GetCapabilities)). Standard WMS, Leaflet-friendly via `L.tileLayer.wms`. Pre-rendered animation galleries for Africa regions also exist at `https://eumetview.eumetsat.int/static-images/MSG/PRODUCTS/MPE/{EASTERN|WESTERN|CENTRAL|SOUTHERN}AFRICA/`.
- **NASA GIBS WMTS/WMS for IMERG** — endpoints: `https://gibs.earthdata.nasa.gov/wmts/epsg{4326|3857|3413|3031}/best/` and `https://gibs.earthdata.nasa.gov/wms/epsg{4326|3857}/best/wms.cgi` ([source](https://nasa-gibs.github.io/gibs-api-docs/access-basics/)). Worldview tutorial confirms **"Precipitation Rate (30-min) IMERG"** and a daily IMERG layer are available and discoverable via the layer picker ([source](https://www.earthdata.nasa.gov/learn/tutorials/view-imerg-precipitation-imagery-worldview)). Exact GIBS layer identifiers were not extractable from the (truncated) GetCapabilities pull during this research — **action item: run a fresh GetCapabilities and pin the identifier before integration**. NASA imagery is generally free and unrestricted; standard NASA attribution applies. Global coverage including oceans, Russia, China interior, Central Africa.
- **NASA GIBS catalog more broadly** — same endpoints carry hundreds of layers (MODIS true color, AMSR precipitation, etc.). For a "global precipitation" overlay, IMERG is the right pick. AMSR_Surface_Precipitation appears in GIBS docs as a colormap example ([source](https://nasa-gibs.github.io/gibs-api-docs/access-advanced-topics/)) but has narrower swath coverage than IMERG and isn't recommended as a primary.

**Take on satellite-precip for the dashboard:** these are good enough to honestly fill the "no radar" gap for Africa, Russia, Chile, and ocean views — **provided the UI labels them correctly** (e.g., "Satellite precipitation estimate (NASA IMERG, ~10 km, 30-min)" not "Radar"). EUMETSAT MPE is sharper for Africa/Middle East/Europe; IMERG is the truly global option. Both are free and WMS/WMTS-native — Leaflet integration is the same complexity as RainViewer tiles.

#### Revised v0.1 regional default — best free option per gap region

Rolling up the rows above into the actual recommendation for cat 8 (radar + satellite layer chooser):

| Region | v0.1 default (radar) | v0.1 default (satellite-precip fallback) | Notes |
|---|---|---|---|
| Philippines, Indonesia, Thailand, Vietnam, Malaysia | **RainViewer** (all in RV coverage) | EUMETSAT IODC MPE for islands east of 35°E | National-met direct embeds optional v0.2 |
| Hong Kong, Taiwan | RainViewer (Asia mosaic includes both) | — | HKO PNG polling viable for HK-only zoom view |
| China (mainland) | **RainViewer** (197 radars) | NASA IMERG (interior coverage) | Caiyun only if a paid tier is opened |
| India | RainViewer (27 radars) | NASA IMERG | IMD per-station GIFs available for station drill-down |
| Russia | **No ground-radar default — fall back to satellite precip** | **NASA IMERG** (preferred) or EUMETSAT for European Russia | RV does not cover Russia; meteoinfo GIF is licence-ambiguous |
| South Africa, Kenya, Tunisia, Morocco | RainViewer (RV's 8 covered African countries) | EUMETSAT MPE Africa (regional) | |
| Rest of Africa (Egypt, Nigeria, Algeria, Ethiopia, Tanzania, Senegal, Ghana, etc.) | **No ground-radar option** | **EUMETSAT MPE** regional (preferred for Africa) or NASA IMERG | Label clearly as satellite estimate |
| Brazil | RainViewer (50 radars) | NASA IMERG | REDEMET API as keyed fallback |
| Argentina | **SMN iframe** (CC-BY-2.5-AR) **or** RainViewer (14 radars) | NASA IMERG | SMN is the only national-met source with a permissive explicit licence |
| Chile | **No ground-radar default — fall back to satellite precip** | **NASA IMERG** | RV does not cover Chile; DMC GeoNode unverified |
| Colombia | RainViewer (8 radars) | NASA IMERG | IDEAM raw on AWS exists but not tile-ready |

**Honest "global radar coverage" claim for Clear Skies v0.1?** With **RainViewer as primary across 80+ countries** + **NASA IMERG / EUMETSAT MPE as labeled satellite-precip fallback for the remaining gaps**, yes — the dashboard can credibly claim global precipitation coverage. The honesty caveat is the radar/satellite distinction, which must surface in the UI (legend, layer name, tooltip), not just in code comments.

## 9. Charts (built-in + custom) · ✅ (decided 2026-05-02)

### What exists today

Belchertown ships **Highcharts Stock 10** with **5 built-in chart groups** plus 1 archived special-event group, all driven by `graphs.conf` (operator-editable). Per the inventory: `[averageclimate]`, `[homepage]` (7 charts: Temperature, Wind+Direction, Wind Rose, Rain, Barometer, Solar+UV, Lightning), `[monthly]`, `[ANNUAL]`, `[airquality]`, `[Tropical_Storm_Hilary]`. Special chart types in use: `windRose` (radial with 7 Beaufort color bands) and `weatherRange` (radial range plot, windbarb-style polar). Custom SQL via `use_custom_sql = true` is supported per-chart. Per-group `page_content` HTML narrative slot.

### Decisions captured 2026-05-02

- **Chart engine: ECharts** per [ADR-002](../decisions/ADR-002-tech-stack.md). Replaces Highcharts Stock.
- **Built-in chart groups for v0.1: `averageclimate`, `homepage`, `monthly`, `ANNUAL`.** AQI folds into `homepage` (per cat 4 decision). `Tropical_Storm_Hilary` drops as built-in — it's station-specific and operators can recreate it via the custom chart system below.
- **"Built-in" means a pre-configured config file we ship**, fully operator-modifiable. Same flexibility as Belchertown's `graphs.conf`. Operators can edit, add, remove, override built-in groups freely; we just provide a sensible starting set.
- **Two surfaces for charts:**
  - **Homepage chart panel** — equivalent to Belchertown's home-page Row 4. Renders one configured chart group (default = `homepage` group). Range selector at top. "View more →" link to full Charts page.
  - **Dedicated Charts page** — **tabbed**, one chart group per tab. Replaces Belchertown's "All" stacked-vertically view (which renders everything at once and is busy/heavy). Operator can still configure which group is the default tab. Each tab renders only when selected — less concurrent render work, cleaner UX.
- **Custom chart capability — two-tier model confirmed:**
  - **Tier 1 (config UI):** observations, time period, chart type (line/bar/area/scatter), color, axis bounds, aggregate type/interval, visibility default. The typical operator stays here.
  - **Tier 2 (config file, raw-config escape hatch):** multi-axis, custom SQL, conditional formatting, special chart types (radial weatherRange), `page_content` narrative, fixed-timespan pinned events (Hilary-style).
  - Cross-tier model: UI is an ergonomic editor for the same underlying file. Raw config is always editable. UI re-reads on next load. Avoids UI/file-divergence.
- **Custom SQL — preserved with sane sampling, NO arbitrary row caps.** Earlier proposal of "row cap + timeout" was Claude fearmongering — operators write the query, the query dictates result set size. The right pattern (and what Belchertown already does for its built-in charts):
  - **Client-side adaptive sampling on render.** ECharts has `series.sampling = 'lttb'` (Largest-Triangle-Three-Buckets) built-in — takes any size result set and downsamples to a render-appropriate count. Same applies to custom SQL results as to built-in observation queries.
  - **Server-side query timeout** for sanity only (default 5s, configurable). Not a cap on what the operator can do; just a guardrail against pathological queries.
  - **Read-only DB user** already enforced as cross-cutting baseline — this is independent of the row-cap question.
- **Tropical Storm Hilary** drops as a built-in; preserved as an example of what operators can build with the custom chart system (fixed timespan + page_content + the same 7 standard charts).
- **Viewer-side time-range changes (1d/3d/7d/30d/90d-style range selectors): enabled/disabled per chart group.** Operator decides at config time which groups expose viewer-side range switching. Mirrors Belchertown's `enable_date_ranges` per-group setting.
- **Wind rose chart: keep.** Standard meteorological chart, ECharts polar bar with Beaufort color bands.
- **Export menu: PNG + CSV minimum** (both ECharts native). PDF/SVG opt-in if cleanly available. XLS skipped — CSV opens in Excel.
- **`page_content` HTML narrative slot above chart groups: keep.** Useful for pinned events, station notes, climatology context.

### ECharts polar feasibility — verified 2026-05-02

Both polar chart types Belchertown uses are feasible on ECharts using only documented native features:

- **Wind rose** — native pattern: `series.bar` with `coordinateSystem: 'polar'`, one bar series per Beaufort speed band, all sharing a `stack` value. Angular axis = `type: 'category'` with N/NE/E/.../NNW labels; radial axis = frequency %. Demo: https://echarts.apache.org/examples/en/editor.html?c=bar-polar-stack
- **Radial weatherRange** (the harder Highcharts-windbarb-style plot Belchertown uses for "Temperature Ranges for Month") — stacked-transparent-bar trick: first bar series `0 → minTemp` with `itemStyle.color: 'transparent'`, second bar series `minTemp → maxTemp` with the visible color. Same stacked-polar-bar mechanics as the wind rose. ~10 lines of config. Cleaner alternative for advanced cases is `series.type: 'custom'` with `coordinateSystem: 'polar'` calling `api.coord([angle, radius])` to draw sectors directly (see https://echarts.apache.org/handbook/en/how-to/custom-series/), but the stacking trick is simpler and sufficient.

No fallback to non-radial layout needed. Both ship in v0.1 as part of the special-chart-types catalog available in tier 2 (config-file power-user features).

### Sources cited
- ECharts polar bar series option: https://echarts.apache.org/en/option.html#series-bar.coordinateSystem
- Stacked polar bar demo: https://echarts.apache.org/examples/en/editor.html?c=bar-polar-stack
- ECharts wind rose feasibility (community confirmation): https://github.com/apache/echarts/issues/13781
- ECharts custom series handbook (for the cleaner-alternative path): https://echarts.apache.org/handbook/en/how-to/custom-series/

## 10. Records + NOAA reports · ✅ (decided 2026-05-02)

### What exists today

**Records page** (`/records/`) — single striped table, sections grouped by metric family. Two columns: `<current year> | All Time` with date/timestamp on the all-time entry. Sections: Temperature (8 rows), Wind (2), Rain (6), Humidity (4), Barometer (2), Sun (2 — gated on radiation/UV existing), Inside Temp (gated on `records-table.inc` hook present). Operator slots `records.inc` (intro paragraph) and `records-table.inc` (extra rows) — both empty on live site.

**Reports page** (`/reports/`) — weewx ReportEngine NOAA `.txt` files rendered in a `<pre>` block. Year/month button grid (5 years × 12 months on live site). AJAX-loads `/NOAA/NOAA-YYYY[-MM].txt`. "View raw" link to the canonical `.txt`. Standard weewx NOAA columns (no solar/UV/AQI). Mini current-conditions strip in the page header.

### Decisions captured 2026-05-02 (six of eight Qs answered)

- **Records and Reports stay as two separate built-in pages.** Both default ON, hide-able per the universal pattern. Folding into a single tabbed "Statistics" page is rejected — the user wants them separate.
- **Records page year selector: ADD.** A year selector at the top of the page lets the operator browse records for any specific year. Default view = `YTD | All-Time` (matches Belchertown). Year selector populates from the years actually present in the archive (no empty years offered).
- **Records page AQI section: ADD**, gated on AQI columns existing per cat 4 column-mapping. Includes Highest AQI + Highest values for whatever pollutant columns the operator mapped (PM2.5, PM10, O3, etc.).
- **User-defined records: ADD as a first-class capability** — operator can configure additional records to track beyond the canonical set Clear Skies ships. Distinct from the custom chart system (charts = time series; records = single-value-with-context). Modernized replacement for Belchertown's `records-table.inc` Cheetah slot. Configuration UI surface: pick an observation column + record type (max / min / sum / count / consecutive-days-with / consecutive-days-without) + label. Renders in a "Custom Records" section on the page. See cross-cutting threads section above.
- **Inside-temp records: default off, operator-toggleable.** Not gated on a hook file's existence anymore (Belchertown's mechanism); a plain config toggle.
- **Year/month dropdowns** for the Reports page selector — replaces the button grid. Dropdowns populate from years/months that actually have a `NOAA-*.txt` file present (no empty options). Scales cleanly past 5 years.
- **Operator narrative slot above the records table:** kept (Belchertown's `records.inc`). Translates to a markdown/HTML field in the configuration UI rather than a `.inc` template file (consistent with the no-Cheetah Clear Skies posture).
- **Records computation:** clearskies-api `/records?period=ytd|alltime|year:YYYY` endpoint backed by weewx's daily summary tables (`archive_day_<obs>`) — cheap regardless of archive size. Cache TTL aligned with archive interval.
- **"Broken in last 30 days" badge** next to records freshly set. Cheap visual cue for the geek audience.
- **Records page hard-depends on weewx archive read access (already a project assumption).** Reports page hard-depends on weewx's NOAA generator producing `.txt` files into a known directory — flagged as a deployment-doc item: setup wizard checks for `/NOAA/*.txt` and prompts the operator to enable the weewx NOAA generator if absent (or hides the Reports page).

### NOAA report rendering — DECIDED 2026-05-02

- **Default view: HTML-parsed table.** Read `/NOAA/NOAA-YYYY[-MM].txt`, parse the fixed-width columns, render as a proper `<table>` (sortable, responsive, copy-paste-clean cells, highlight high/low rows). Modern UX, mobile-friendly.
- **Export: `.txt` download link** on the page — pulls the canonical weewx-generated `.txt` file byte-for-byte. (No regeneration; we serve the file that weewx already wrote.)

### NOAA reports — context correction (recorded 2026-05-02)

An earlier draft of this section claimed COOP forms (F6/NWS-1, B-91, CD-3025) were "not relevant to a PWS site." That was wrong. The user (`GW2292`) is an active **CWOP participant** — explicitly documented in [BELCHERTOWN-CONTENT-INVENTORY.md](BELCHERTOWN-CONTENT-INVENTORY.md) under "Posted to" external aggregators ("GW2292 on NWS NOAA/CWOP Program"). The CWOP program is itself a NOAA cooperative observer program for automated stations, and many weewx operators participate. weewx's NOAA reports descend directly from the NWS Local Climatological Data (LCD) reporting style that COOP/CWOP participants work with. **Reports are more relevant for COOP/CWOP-participating operators, not less** — and that audience is a non-trivial slice of the weewx user base. Anchor for the open question below.

### Open question remaining — concrete column delta

Full research with sources: [NOAA-COOP-CWOP-REPORTING-RESEARCH.md](NOAA-COOP-CWOP-REPORTING-RESEARCH.md). Anchoring facts:

**What weewx's default `NOAA-YYYY-MM.txt.tmpl` actually emits** (verified against `c:\CODE\weather-belchertown\skins\Belchertown\NOAA\NOAA-YYYY-MM.txt.tmpl`, byte-identical to weewx Standard):

13 columns per day: DAY · MEAN TEMP · HIGH · TIME · LOW · TIME · HDD · CDD · RAIN · AVG WIND · HIGH WIND · TIME · DOM DIR.

**What real NWS / NCEI products contain** (for comparison, not to mimic 1:1):

- **F-6 (Preliminary Local Climatological Data)** — issued by NWS WFOs for airport ASOS, *not* by COOP observers. 18 columns: Day · Max · Min · Avg · Dep. (departure from normal) · HDD · CDD · Water · Snow · Depth · Avg wind · Peak 2-min sustained · Dir · Mins sunshine · %PSBL · SR-SS sky cover · Weather codes · Peak gust · Gust dir. Source: [NWS GRR F-6 explanation](https://www.weather.gov/grr/climateF6explain).
- **LCDv2 (NCEI archived)** — daily summary additionally surfaces dew point, station pressure, sea-level pressure, wet-bulb, RH, weather-type codes, sunshine, peak-gust-separate-from-sustained. Coverage: ASOS/AWOS only — **PWS data does not feed LCD**. Source: [NCEI LCDv2 documentation](https://www.ncei.noaa.gov/oa/local-climatological-data/v2/doc/lcdv2_DOCUMENTATION.pdf).
- **WS Form B-91** — COOP observer's monthly paper/digital submission via WxCoder. Not relevant as a *report-back* — it's a submission form. CWOP participants do not submit via B-91. Source: [NWS COOP Forms](https://www.weather.gov/coop/Forms).

**What a CWOP-participating PWS submits via APRS packet** (the user's actual data flow, callsign GW2292): wind dir / wind speed / gust / temperature (required); rain (1h, 24h, midnight), humidity, pressure (tenths of mbar), solar (W/m²), snow (optional). Source: [Gladstonefamily CWOP Guide](https://weather.gladstonefamily.net/CWOP_Guide.pdf).

**The honest gap — fields the station collects (and submits to MADIS) that weewx's default report drops:**

| Field | Submitted via CWOP? | In weewx default NOAA report? |
|---|---|---|
| Pressure (avg/min/max) | yes | **no** |
| Humidity (avg/min/max) | yes | **no** |
| Dew point (computable from temp + RH) | derivable | **no** |
| Rain rate (peak) | derivable from archive | **no** |
| Peak gust (separate from sustained "high" wind) | yes (`gNNN`) | **no** — the one "HIGH" column conflates them |
| Solar radiation (mean, peak) | yes (`LNNN`/`lNNN`) | **no** |
| UV (peak) | on-station, not in CWOP packet | **no** |
| Snow / snow depth (where measured) | optional | **no** |
| Records broken on date | derivable | **no** |

So "enhanced" = adding columns for data the station already records but the default drops.

**Fields a PWS legitimately can NOT produce** (audit — surfaced so they don't sneak in):

- **Departure from normal (Dep.)** — requires 30-year climate normals dataset; weewx doesn't ship one and Clear Skies isn't going to. Skip the column entirely.
- **Sunshine minutes / %PSBL (F-6 cols 13–14)** — requires a dedicated sunshine sensor; not on a typical PWS.
- **Sky cover SR-SS (F-6 col 15)** — WFO human/auto observation; not measurable by a PWS.
- **Weather-type codes (F-6 col 16)** — requires a present-weather sensor; not on a typical PWS.
- **Ceiling / visibility (LCD)** — aviation-grade ceilometer / visibility sensor; not on a typical PWS.

**Naming honesty issue surfaced by research:** weewx's folder is named "NOAA" but the template is not an NWS form. F-6 is a WFO product, B-91 is a COOP submission form, LCD is an NCEI publication for ASOS/AWOS — none match weewx's "NOAA" template. Calling our enhanced version "NOAA Report" perpetuates a misnomer. Honest names: "Climatological Summary" or "Station Summary." Open question for user.

### Decision — B selected (locked 2026-05-02)

**Ship a Clear-Skies enhanced template.** Adds the 9 fields from the gap table (pressure avg/min/max, humidity avg/min/max, dew point, peak rain rate, peak gust separate from sustained, solar mean+peak, UV peak, snow if measured, records broken) on top of weewx's 13-column default.

**Hard constraint — per-station sensor-availability adaptation.** The template MUST detect per-station, per-period whether each candidate column has data and render only the columns with actual values. No N/A clutter, no empty columns. A station with no pyranometer doesn't see Solar columns; a station that didn't have AQI sensors until July 2025 sees AQI columns appear in August's report and onward, not before. Mechanism: aggregate-NULL check per column per period at render time; auto-omit when no non-null aggregate exists; operator config override can force-include (renders explicit N/A) or force-exclude. This pattern is now a project-wide cross-cutting thread (see threads section above) — applies to dashboard tiles, charts, Records page, and any future rendered surface.

**What we explicitly DO NOT add** (audit — surfaced so they don't sneak in):

- Departure from normal — needs 30-yr climate normals dataset Clear Skies isn't shipping.
- Sunshine minutes / %PSBL — requires a sunshine sensor most PWS don't have.
- Sky cover (SR-SS) — WFO observation, not measurable by a PWS.
- Weather-type codes — requires a present-weather sensor most PWS don't have.
- Ceiling / visibility — aviation-grade sensors only.

**Output formats per period** — three files: fixed-width `.txt` (legacy/archive), `.html` (rendered by Reports page), `.csv` (machine-readable export). Cheetah generator handles multiple template files per period natively.

**Lifecycle:** the templates are a **weewx-side artifact** (Cheetah files installed into the weewx skin directory), not a Clear Skies runtime concern. Clear Skies' Reports page reads whatever files weewx wrote. The Reports-page rendering decision (HTML-parsed default + `.txt` download) stands. Maintenance: small set of Cheetah templates in the meta-stack repo with INSTALL doc to drop them into a weewx setup.

### Naming — DECIDED 2026-05-02

Keep folder name "NOAA" (preserves familiarity for the weewx user base) and add an in-template annotation noting the report is locally generated and not an official NOAA / NWS / NCEI product. Ship as `weewx-clearskies/skins/.../NOAA/` so it drops into the existing weewx convention without operator surgery.

### Threads carried forward

- **User-defined records mechanism** — added to cross-cutting threads (parallel to but distinct from user-defined charts).
- **Render-time sensor-availability detection** — promoted to cross-cutting thread; applies to dashboard tiles, charts, Records page, and any future rendered surface, not just the NOAA template.
- **Setup wizard checks for `/NOAA/*.txt` files** and either prompts to enable the weewx NOAA generator or hides the Reports page. Belongs in setup-wizard scope (ADR-027 — Accepted) and INSTALL docs.
- **Reports page templates are a weewx-side artifact** (Cheetah `.tmpl` files, installed into the operator's weewx skin directory). Maintenance: small set of templates in the meta-stack repo; INSTALL doc explains the drop-in. Clear Skies' Reports page just reads whatever weewx wrote.

### Threads carried forward

- **User-defined records mechanism** — added to cross-cutting threads (parallel to but distinct from user-defined charts).
- **Setup wizard checks for `/NOAA/*.txt` files** and either prompts to enable the weewx NOAA generator or hides the Reports page. Belongs in setup-wizard scope (ADR-027 — Accepted) and INSTALL docs.

## 11. Site cross-cutting (theme, locale, PWA, social, privacy, power-user hooks) · ✅ (decided 2026-05-02)

### Decisions captured 2026-05-02

**A. Theme (light / dark / auto-by-sunrise-sunset):** keep all three modes. Operator picks default at setup; user can override via toggle in nav (persisted to `localStorage`). "Auto" follows sunrise/sunset (Belchertown's existing behavior — kept per user direction). OS-preference (`prefers-color-scheme`) is also respected as an "Auto by OS" mode.

**B. Branding (logo, site title):** light + dark logo upload via setup UI with format/size validation. If operator uploads only light, system auto-inverts for dark and tells the user "we'll use an auto-inverted variant; if you don't like it, upload your own." Site title text falls back if no image.

**C. i18n / locale:** v0.1 ships 13 locales (en, de, es, fil, fr, it, ja, nl, pt-PT, pt-BR, ru, zh-CN, zh-TW) per numisync.com's set, screenshot-confirmed 2026-05-02. No RTL languages in scope. See cross-cutting threads section above.

**D. PWA:** installable manifest with operator-configurable name/short_name and icons generated from logo. **No service worker / offline mode in v0.1** — Phase 6+ per master plan.

**E. Custom CSS / power-user injection:**
- **Custom CSS file slot** — operator drops `custom.css` into a known config dir; SPA loads it after the bundle.
- **Operator-defined narrative slots per page** — markdown/HTML field per page in config UI. Replaces Belchertown's `*.inc` Cheetah hooks.
- **Cheetah `index_hook_after_*.inc` slots: dropped** — don't translate to a SPA architecture; the narrative-slots-per-page approach + custom CSS + custom tiles (Phase 6+) cover the use cases.

**H. Analytics / privacy / consent banner:**
- v0.1 ships **GA4, Plausible, Umami, and "none"** as analytics options. Provider-pick at setup; "none" is the default.
- **Consent banner shipped as a v0.1 feature.** Operator toggles whether the banner is required for their jurisdiction (operator's call, operator's responsibility — acknowledgment checkbox at setup).
- If banner is enabled and visitor declines, all tracking (GA4, etc.) is disabled for the session.
- User direction 2026-05-02: "I do not see the consent banner as a problem … they are not that annoying, it is easy to click and it goes away."
- This unlocks GA4 at v0.1 (previously proposed for v0.2 deferral).

**I. Legal / Privacy page:**
- Built-in optional page (hide-able per universal pattern).
- **Boilerplate text shipped pre-customized for the user** (Shane Burkhardt, weather.shaneburkhardt.com) since this project is being written for them first.
- Documentation tells future operators to modify or replace the boilerplate based on their own legal framework.
- **Setup wizard requires explicit acknowledgment checkboxes** that the operator takes full responsibility for: (a) legal/privacy text content for their jurisdiction, (b) analytics tracking compliance, (c) social media / third-party embed compliance. Clear Skies and project authors disclaim all responsibility.

**J. Schema.org / Open Graph metadata:** auto-generated per page from station metadata + page content. Keep.

**ADA / WCAG 2.1 AA — APPROACH LOCKED:** "audit all code after it is written for compliance, plus a full audit before shipping." Per-write audit + pre-ship full audit. Rules written to [rules/coding.md](../../rules/coding.md) Section 5 — DONE 2026-05-02 (not deferred). See cross-cutting threads section above for the load-bearing implications across ADR-009 (palette) and ADR-026 (commitments).

### Open questions remaining

**F. Footer — DECIDED 2026-05-02:** slim one-line footer on every page: `© year station-name | Legal/Privacy | Powered by Clear Skies`. Low chrome, low attention. The "Powered by Clear Skies" attribution is hideable via operator config but on by default.

**G. Social share — DECIDED 2026-05-02:** pure `<a href>` share-intent links, no SDK, no third-party JS, no tracking. Mirrors the implementation on the user's other site coinrollhunting.org (theme file `wp-content/themes/coinrollhunting/inc/social.php`). Each share button is a plain link to the platform's public share-intent URL, opens in a new tab via `target="_blank" rel="noopener noreferrer"`, and has an `aria-label` for accessibility. Inline SVG icons (no external icon font). Copy-link button uses the browser clipboard API.

**Platforms shipped at v0.1:** the same set the CRH site uses, minus the niche-audience BBCode forum block — adapted for the weather audience:
- **X / Twitter** — `https://twitter.com/intent/tweet?url=…&text=…`
- **Facebook** — `https://www.facebook.com/sharer/sharer.php?u=…`
- **Reddit** — `https://www.reddit.com/submit?url=…&title=…`
- **Mastodon** — share-intent URL pattern requires picking the user's instance; we ship a simple compose dialog or "Share to Mastodon" with an instance-prompt UX
- **Bluesky** — `https://bsky.app/intent/compose?text=…&url=…` (verify live URL pattern at implementation time)
- **Email** — `mailto:?subject=…&body=…`
- **Copy Link** — clipboard API
- **Pinterest dropped** (low value for weather audience)

**Each platform individually hide-able by operator** per the universal hide-tile pattern. If all hidden, share row disappears.

**Privacy compliance:** none of these mechanisms set tracking cookies or load third-party JS. No consent banner triggered by the share buttons themselves. (The consent banner from decision H gates analytics, not these href-based shares.)

## 12. Hardware-coupled features · ✅ (decided 2026-05-02)

### Decisions captured 2026-05-02

**A. Lightning detection — own tile + improved chart, both placement-flexible.**

- **Lightning tile on the Now page** (default ON if `lightning_strike_count`/`lightning_distance` columns have any non-null aggregate; hidden via render-time sensor-availability detection per cat 10 cross-cutting rule). Tile content:
  - Strike count: last 1 hour + last 24 hours (matching Tempest's `strikeCount1h` / "last day" model — see [Tempest community storm-phase thread](https://community.tempest.earth/t/lightning-strike-trend-storm-is-approaching-or-departing/9697))
  - Nearest strike distance + time since last strike
  - **Storm-phase status badge:** "Clear" / "Approaching" / "Overhead" / "Departing" — computed from the distance trend over the last N minutes (the cool idea borrowed from Tempest community visualizations; not Belchertown)
  - Yellow accent / pulse animation when a strike has been detected in the last 5 minutes (Tempest precedent)
  - Click-to-expand: per-strike list (last 24h) with timestamps + distances
- **Lightning chart in chart groups** — replaces Belchertown's `homeLightningInfo` scatter. New default chart shape:
  - Bar chart: strike count per time bucket (primary axis, sum-aggregated)
  - Line: nearest strike distance per bucket (secondary axis, inverted so closer = higher visually — closer is "more alarming")
  - Configurable "alert distance" reference line (operator config; default 10 km / 6 mi) — once distance crosses this, visual hits a different color
- **Chart placement is flexible** per cat 9 chart-layout system: operator can place lightning chart in `homepage` group, build a dedicated lightning group, or include it in custom groups.
- **Data-processing concern raised by user:** the Belchertown `homeLightningInfo` chart "sucks" — likely because it scatters `lightning_distance` averaged across archive intervals, losing individual-strike granularity. Flagged as **Phase 2 investigation item**, NOT a cat 12 content decision. The right aggregation is probably: SUM for `lightning_strike_count`, MIN for `lightning_distance` (nearest strike in window), and individual-strike rendering from loop packets where available. Goes into the Phase 2 backlog.

**B. Barometer 3-hour trend — keep as-is.** Numeric value + ↑/↓/↔ arrow + 3-hour delta (e.g., "30.12 in ↑ +0.05"). Same period (3 hours) is the Belchertown default and stays; operator can configure different period if desired.

**C. Multi-probe support (extraTemp1, extraHumid1, etc.)** — folded into the **user-driven column mapping treatment** (already a cross-cutting thread, subsumes ADR-035). No separate cat 12 decision. Operator maps each extra column to a canonical type at setup, picks where it appears (Now-tile, charts, none). If the column matches an existing tile type (temperature, humidity), it slots in there. If not, the operator builds a chart for it via the cat 9 custom-chart system. No additional design work needed beyond what the column-mapping flow already covers.

**D. Soil moisture, leaf wetness, esoteric sensors** — same treatment as C. Custom column mapping handles it. No special cat 12 work.

**E. About page — operator-authored content, like Belchertown.**

Reading Belchertown's `skins/Belchertown/about.inc` directly (instead of guessing): the entire About page is hand-written HTML. The example file states "Full HTML, and weewx variables are accepted." Operator types the hardware list, sensor list, posted-to list, credits list, photos — all of it.

Clear Skies takes the same approach with a modern wrapper:

- About page is **operator-authored markdown** edited via the configuration UI (rich-text editor with markdown source toggle).
- **Setup wizard pre-populates a starter About page** seeded from data already collected: station name, lat/lon, altitude, hardware free-text field. This is the "auto-configure during setup" piece — operator opens the About page editor and finds a pre-filled starting point, then edits freely.
- **Image embeds:** every image gets an alt-text field at upload (per [rules/coding.md](../../rules/coding.md) Section 5).
- **No auto-generated sensors list** (corrected — earlier proposal was wrong). Operator writes the sensors list themselves in the About page if they want one. The system can offer a "paste my detected columns here" helper button that inserts the column list as a starting point, but the content stays operator-edited.
- **No auto-generated credits list** (corrected). Operator writes their own. We can offer a "paste my configured providers here" helper button as a convenience.

**F. Posted-to aggregator list — operator-authored content within the About page.**

Corrected from earlier proposal. Belchertown's "Posted to" list (Wunderground KCAHUNTI278, Ambient Weather GW2292, Vaisala XWeather, NWS NOAA/CWOP GW2292) is hand-typed HTML in `about.inc`. No preset list, no setup-wizard preset platforms.

Clear Skies treatment: the Posted-to list is just operator-authored markdown content within the About page. Operator types whatever platforms they participate in, with their station IDs and links. We do NOT ship a preset platform list with station-ID fields; we let the operator write what they want like Belchertown does. Same model for the NOAA/CWOP attribution paragraph and the Credits list.

**G. Nothing else hardware-coupled needs explicit treatment.** Confirmed.

### Threads carried forward

- **Lightning data processing investigation** — Phase 2 backlog item: revisit aggregation strategy for `lightning_strike_count` (sum) and `lightning_distance` (min nearest, not avg). Loop-packet-level rendering for the per-strike list. Verify weewx archive captures discrete strikes correctly vs. averaging them.
- **About page = operator-authored markdown** — joins the operator narrative slot pattern from cat 11 (per-page narrative slots) and cat 10 (Records page intro). All operator-authored content surfaces use the same editor + markdown convention.
