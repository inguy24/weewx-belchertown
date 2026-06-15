# C1 — Prior-Decision Digest

**Track C, component C1.** Round: C1 step 0 (prior-decision check).
**Date produced:** 2026-05-31. **Author:** Sonnet investigation agent.
**Status:** Research note (NOT a decision record). Uncommitted — for lead review before any design work.

Covers two surfaces:
- (a) **Current-conditions card** (existing `CurrentConditionsCard` + the static temp-curve placeholder)
- (b) **Now-page hero** (page-header card = station logo + station name; per ADR-051, was dropped and never redesigned)

---

## ADR decisions bearing on C1

### ADR-009 — Design direction (Accepted, 2026-05-04; reconciled 2026-05-30)

**Decision:** Multi-page card-based dashboard; hero imagery on the Now page only (default = in-house SVG, operator-uploadable, event-triggered). Three-tier information hierarchy. Recharts (not ECharts — corrected in the body of ADR-009 §Charts). Inter font. WCAG AA throughout.

**Hero-treatment section (§"Hero treatment (Now page only)"):** As of the 2026-05-30 reconciliation note added inline to ADR-009, the background/backdrop role has been superseded by ADR-047. The original text specified a shipped SVG default + operator-uploadable photo + event triggers. The reconciliation note reads:

> "The page **background** is now a global, condition-keyed *photographic* system (ADR-047: clear/cloudy/storm × day-night scene photos + on-glass rain/snow overlays, behind every page). For the **background/backdrop role**, ADR-047 supersedes this section's Now-page-only in-house-SVG default. The operator-upload + event-trigger model described below is **retained as future scope** for an optional foreground hero and for operator-replaceable backgrounds, not as the default backdrop."

**Consequence for C1:**
- The Now-page background behind cards is the ADR-047 condition-keyed photo layer — already resolved, not a C1 question.
- Event-trigger-rich operator backgrounds (season/date-range/alert overrides) are explicitly deferred to future scope.
- The page-header card (station logo + station name) is a separate element from the background — ADR-009 does not address it directly; that falls to ADR-051 + ADR-022.
- The current-conditions card's information hierarchy (tier 1 = headline temp/condition, tier 2 = feels-like / hi-lo / supporting metrics) is locked by ADR-009.

---

### ADR-022 — Theming and branding mechanism (Accepted, 2026-05-02)

**Decision:** All operator branding flows at runtime via CSS variables and the `/api/v1/branding` endpoint — no rebuild. Operator inputs: accent color (curated 6-name palette), logo (light + optional dark; CSS-invert fallback), site title, favicon URL, custom CSS slot, default theme mode.

**Logo specifics:** `useBranding()` hook exposes `branding.logo.light`, `branding.logo.dark`, `branding.logo.alt`. When only a light logo is uploaded, the dashboard applies CSS `invert` for dark theme. The API enforces a non-empty `logo_alt` guarantee (falls back to `"<site_title> logo"` if operator leaves it blank). Built and shipped: `BrandingProvider` writes `siteTitle` to `document.title` and updates `<link rel="icon">` at runtime.

**Consequence for C1:**
- The page-header card (hero) must consume the `useBranding()` hook — the logo `<img>` src and alt text come from there, not hardcoded.
- The accent color is already applied site-wide via CSS vars; the hero card does not need to inject its own.
- The single-logo CSS inversion warning is built into the wizard — C1 does not need to reproduce it, just render the image the hook provides.
- Site title displayed in the hero must read from `branding.siteTitle`, not a static string.

---

### ADR-024 — Dashboard page taxonomy and navigation (Accepted, 2026-05-04; amended 2026-05-27)

**Decision:** Nine built-in pages. Now (`/`) is page 1. Per-page content for Now includes:

> "current-conditions hero (operator-uploadable photo, current outTemp primary, condition + feels-like secondary), active alert banner (when present), Today's Highlights (today's hi/lo + peak gust + rain so far + peak AQI + records-broken-today), Wind tile…, Station observations tile (locked default 8)…, Sun & Moon mini-tile, AQI tile (half-gauge + main pollutant), Lightning tile…, Earthquake tile…, Today's forecast card…, Radar card…, Webcam card…, homepage chart panel (default `homepage` group with 1d/3d/7d/30d/90d range selector + 'View all charts →' link)."

ADR-024 **does not mention a station-logo/station-name page-header card** for Now. The current-conditions hero is described in data terms (outTemp primary, condition + feels-like secondary), not layout/chrome terms.

**Consequence for C1:**
- The card inventory for Now is locked by ADR-024 — C1 is not authorized to add new data cards without a plan-level decision. The now-page hero/page-header is a layout primitive (per ADR-051), not a new data card.
- The current-conditions hero's data contract: outTemp (primary), condition + feels-like (secondary). ADR-024 confirms this but leaves per-card visual layout explicitly to Phase 3 design — C1's job.
- The homepage chart panel is listed in ADR-024 but is currently only a static placeholder + link in the build; C7 (not C1) is scoped to build it out.

---

### ADR-047 — Background system (Accepted, 2026-05-30)

**Decision:** Global, condition-keyed photographic background behind every page. Two layers: blurred scene photo (clear/cloudy/storm × day/night) + optional on-glass precip overlay (rain = `overlay` blend at 75%/25% day/night; snow = `screen`). Server (API) emits `scene: { sky, daytime, overlay }` descriptor; dashboard maps it to assets. No client-side weather logic. Operator-replaceable over shipped defaults.

**Consequence for C1:**
- The current-conditions card and the page-header hero both sit over the ADR-047 background layer.
- Card surfaces are translucent glass (ADR-051), so the scene photo shows through. This means the current-conditions card's text and the hero's logo must be legible over photos in both themes — a constraint C1 must honour (B3 contrast gate sets the floor).
- The attribution element (corner photo credit) is a global layer, not inside any card — C1 does not own it.
- C1 does not need to implement the background itself (ADR-047 implementation is tracked separately as D2 in the dashboard repo — already committed as `feat(ui): D2 — ADR-047 global background layer`).

---

### ADR-049 — Hero weather icons (Accepted, 2026-05-30)

**Decision:** Hero weather glyphs = Google Material Symbols (filled), recolored with linear gradients in a Meteocons-inspired palette: gold sun (`#FFD24D`→`#F5A623`), light-grey volumetric clouds (`#F3F5F8`→`#C7CDD6`), periwinkle moon (`#86C3DB`→`#72B9D5`), gold lightning bolt, soft blue rain, pale icy snow. Combined glyphs (partly-cloudy-day) split sub-shapes: sun = gold, cloud = grey. Rendered as inline SVG with `<linearGradient>` fills. Build work deferred; locked visual reference at `docs/design/mockups/A3-material-gradient.html`.

**Consequence for C1:**
- The current-conditions card's weather condition icon must use the ADR-049 Material Symbols + gradient treatment — NOT the current Weather Icons (Erik Flowers) font.
- The dashboard's `weather-icon.tsx` is to be rewritten (noted in ADR-049 as build work, Track A code batch). C1's exec plan must include or depend on this rewrite.
- Icons are static (no SMIL animation) → `prefers-reduced-motion` safe by construction.
- Known gotcha from ADR-049: partly-cloudy-day requires splitting the sun sub-path with an absolute anchor (`M14.975 17.2`); use `fill-rule="nonzero"`.
- The condition icon in the hero/page-header (if any appears there — that is C1's design decision) would also use ADR-049 treatment.

---

### ADR-050 — Utility / stat / nav icons (Accepted, 2026-05-30)

**Decision:** Base pack = Phosphor (regular weight). Curated set: temperature `ph:thermometer`, humidity `ph:drop-simple`, precip chance `ph:umbrella`, visibility `ph:eye`, solar radiation `ph:sun`, rainfall `ph:cloud-rain`, barometric pressure `ph:gauge`, UV index `tabler:uv-index` (cross-pack). Trend indicators: `ph:arrow-up/down/right`. **Text-only (no icon):** feels-like, dew-point. Wind speed/direction/gust excluded entirely — owned by C2.

Three sub-families **explicitly deferred** to component ADRs: astro/almanac glyphs → C5; AQI/air-quality set → C6; earthquake/seismic glyph → seismic component.

**Consequence for C1:**
- The current-conditions card's stat icons follow the ADR-050 set — `ph:thermometer` for temperature, etc.
- Feels-like renders **text only, no icon** — this is locked, not a C1 design question.
- Dew-point (if surfaced in the current-conditions card) also renders text only.
- Wind stats in the current-conditions card are in scope for C2, not C1 — C1 must not introduce a utility wind icon; those fields may appear in the conditions card but their iconography is C2's territory.
- The Lucide icons currently in `now.tsx` (Sunrise, Sunset, Moon, Activity) carry TODO comments noting they stay on Lucide until C5 (astro) and the seismic ADR land — C1 must not disturb those deferred TODOs.

---

### ADR-051 — Card footprint model (Accepted, 2026-05-30) — CRITICAL for C1

**Decision:** Universal card discipline: every page renders only cards inside `--container-max` (80rem). Footprint vocabulary: `tile` (1 col) · `wide` (2 col) · `panel` (3 col) · `full` (4 col). Row-span declared per card. Responsive collapse: 4→2→1 at ≥1024/≥768/<768px. Half-row base track (`--card-half-row` = 5.5rem); strips span 1 half-row, standard data cards span 2 (= 11rem), tall cards span 4 (= 22rem). Card surface = translucent glass (exact opacity at B3 gate). Minimum footprints locked: Current Conditions, Wind Compass, Radar, Webcam = 2×2; Active Alert and Today's Highlights = full (4×1); stat tiles = 1×1.

**Hero-drop rationale (key passage, verbatim):**

> "**Page-header card (a card, not free text).** Every page opens with a `full`-width **half-row** page-header card holding the page title + short info. **On the Now page this card *is* the hero** — it carries the station logo + station name (its full content/design is a Track C **C1** job; A4 only establishes it is a card). On other pages it is a title + one-line-info card replacing today's free-floating page text."

And in Consequences:

> "**Restore the Now-page hero (tracked, Track C / C1).** The page-header card on Now = the hero showing **station logo + station name**; it was dropped and never redesigned. A4 establishes it is a card; its content/design is a **C1** deliverable (ties to ADR-022 branding / ADR-049 logo alt)."

**Why the hero was dropped:** ADR-051 names the drop but does not explain the historical cause — it only asserts the forward state (it is a card, C1 designs it). The hero was apparently dropped during Phase 2 build without being redesigned; ADR-051 is the first record to formally name this as a gap and assign ownership to C1.

**Consequence for C1:**
- C1 must design AND implement the page-header card on Now: `full`-width, half-row height (`--card-half-row` = 5.5rem), carries station logo + station name.
- This is the hero — it is not optional and not decorative chrome. It is the same card primitive as all other cards.
- The logo comes from `useBranding()` (ADR-022); the station name comes from `/station` or `/branding` `siteTitle`.
- Current Conditions card minimum footprint is 2×2 (locked). The hero/page-header is a separate card at full × ½ row — it sits above the grid, not in place of the current-conditions card.
- Every Track C card must declare a footprint AND a minimum footprint as part of its spec. C1 must do this for both the page-header hero AND the current-conditions card.
- B3 contrast gate governs the final glass opacity — C1 must not hard-code an opacity value; instead reference the provisional shipped defaults (light: `rgba(255,255,255,0.72)`, dark: `rgba(30,35,55,0.55)`) and note they are subject to B3.

---

## C0 + plan: what C1 is scoped to cover

### From the C0 work list (C0-PAGE-INVENTORY.md, Track C work list table):

> "**C1** | Now: Current-conditions hero **+ today's temp curve** (img-23) | curve net-new (placeholder today) | A1/A2; **B2** (Recharts bg)"

### From the UI-REDESIGN-PLAN.md (lines ~205–206):

> "**C1. Current-conditions card** + **today's temperature curve** along the bottom (model: img-23) + **restore the Now-page hero** (page-header card = station logo + station name; per ADR-051, dropped & never redesigned; ties to ADR-022 branding / ADR-049 logo alt). → ADR + exec plan."

### C0 §1 "Now / Home" — candidate card table entries for C1 surfaces:

| Candidate card | Purpose | Primary data |
|---|---|---|
| Current Conditions hero | Oversized temp + condition sentence + feels-like + icon | `/current`, `/forecast` code, `/station` |
| ⬚ Today's temperature curve | Day curve, gradient, dashed-past/solid-future, now-divider, H/L, Actual/Feels toggle (img-23) | `archive` (today) + `/current` (+forecast future leg) |
| ⬚ Station header / freshness strip | Station identity + last-updated/online (Belchertown parity) | `/station`, `/branding`, SSE state |

The "Station header / freshness strip" candidate in C0 maps to ADR-051's page-header hero card. The "⬚" marker means it is not yet built.

### C0 flags and open questions for the Now page (relevant to C1):

**Flags:**
- Card set + data wiring locked by ADR-024 (layout open); layout open = C1's job.
- `weatherText`/`comfortIndex`/`beaufort` are API-computed (ADR-044/041) — consume verbatim.
- Values are ConvertedValue (ADR-042) — no client unit math.
- EPA/UV colors WCAG-adjusted (ADR-026) — preserve (already in `now.tsx` with verified contrast ratios).

**Open questions from C0 (relevant to C1):**
- Webcam/Timelapse/Radar one-tabbed-tile vs split? (reconcile in C1/C6 — also flagged in the reconciliation table)
- Consolidate the locked-8 obs into one tile vs keep split across cards?
- Real chart vs placeholder for today-curve + homepage panel?
- Freshness strip = chrome or Now card?

---

## As-built Phase-2 Now page

### Dashboard repo preflight

**Repository:** `/home/ubuntu/repos/weewx-clearskies-dashboard` on the `weather-dev` LXC container.
**Branch:** `main`
**Remote sync:** `Your branch is up to date with 'origin/main'.`

**git log --oneline -5:**
```
bfe6b91 chore(deps): remove dead weather-icons dependency (post-ADR-049)
846fc6c feat(ui): D2 — ADR-047 global background layer (scene-background component)
4e8c896 feat(assets): D3 — ADR-047 background images, all 8 scenes/overlays <= 300 KB WebP
90ed053 feat(icons): A3-utility Lucide→Phosphor migration (ADR-050)
8143377 feat(icons): A3-utility dep + cross-pack icons + alert map (ADR-050)
```

**git status:** Modified only: `test-results/.last-run.json` (test runner artifact) and two deleted smoke-test error context files. Untracked: `e2e/b3-axe-check.spec.ts`, `e2e/b3-verify-render.spec.ts`. No staged changes. No code conflicts. Repo is clean for C1 work.

### What the as-built `src/routes/now.tsx` renders

Cards / elements rendered by `NowPage()` in reading order:

1. `<h1 className="sr-only">Now</h1>` — screen-reader-only page heading (no visual heading, no hero card)
2. `<AlertBanner>` — conditional (rendered only when alerts exist and not loading)
3. `<CurrentConditionsCard>` — existing component (`src/components/current-conditions-card.tsx`); passed `observation`, `stationName`, `loading`, `error`, `units`, `weatherText`, `weatherCode`
4. Today's Forecast card — inline JSX in `now.tsx`, not a separate component
5. Today's Highlights card — full-width (`md:col-span-2`), inline JSX
6. Wind card — contains the `WindCompass` SVG component (defined inline in `now.tsx`)
7. Solar/UV card — `<SolarUvCard>` component
8. Precipitation/Barometer card — `<PrecipitationBarometerCard>` component
9. AQI card — contains inline `AqiGauge` SVG component
10. Sun & Moon card — inline JSX; icons still Lucide (`Sunrise`, `Sunset`, `Moon`) with TODO comments
11. Lightning card — uses `ph:Lightning` from Phosphor (already migrated per ADR-050 commit)
12. Recent Earthquake card — uses Lucide `Activity` with TODO comment (deferred to seismic ADR)
13. Temperature Trend card — **static decorative SVG placeholder** (`aria-hidden="true"`, hardcoded polyline points, gradient background CSS) + a "View Charts" link to `/charts`; **no Recharts import, no real data**
14. Radar card — `<RadarMap>` component (Leaflet); expands full-width when webcam disabled
15. Webcam card — conditional on `webcamEnabled && webcamAvailable`; has Live/Timelapse tab toggle within the card

### Hero / page-header confirmation

**There is no hero card, no page-header card, no station logo, and no station name visible on the page.** The `NowPage` component opens with `<h1 className="sr-only">Now</h1>` — the heading is hidden from sighted users. No `useBranding()` call exists in `now.tsx`. The `CurrentConditionsCard` receives `stationName={station?.name ?? ''}` as a prop, but whether that name is displayed inside the card is determined by `current-conditions-card.tsx` (not read here — that is the as-built starting point for C1's design work on that card).

There is **no page-header card of any kind on the Now page** in the current build. This confirms ADR-051's assertion that the hero "was dropped and never redesigned."

### Temperature curve / today's temp chart

The Temperature Trend card (item 13 above) is confirmed a **static decorative placeholder**: hardcoded `<polyline>` with fixed points, wrapped in `aria-hidden="true"`, with a CSS gradient background. It does not import or use Recharts. It does not connect to any data hook. The B2 gate (Recharts `usePlotArea()` technique) is available for C1 to use when building the real chart.

### Icon state at time of investigation

- `now.tsx` imports `{ Sunrise, Sunset, Moon, Activity }` from `lucide-react` with explicit TODO comments citing ADR-050 deferrals (astro → C5, seismic → seismic ADR).
- `now.tsx` imports `{ Lightning }` from `@phosphor-icons/react` — already migrated.
- `CurrentConditionsCard` (not read here) presumably still uses the old Weather Icons font mapping for the condition icon; `weather-icon.tsx` rewrite (ADR-049 build work) is the dependency.

---

## Live Belchertown reference

**Source:** https://weather.shaneburkhardt.com — fetched 2026-05-31.

### Station hero / header (Belchertown)

The production site opens with a **light-branded header** containing:
- A **logo image** linked to the home page
- Station identifier text: **"GW2292 Huntington Beach Weather Conditions"** (combines station ID + location + page type in one string)
- Horizontal navigation below: Home · Graphs · Marine Forecast · Records · Reports · About

The station identity is presented in the page header as both a logo and a title string. There is no separate "hero card" — it is a traditional HTML header element, not a card-based component.

### Current conditions (Belchertown)

Presented as a prominent block with clear visual hierarchy:
- **Primary:** Large temperature reading — "72.5 °F"
- **Secondary:** "Feels like: 75.7 °F" beneath the primary
- **Supporting:** Today's hi/lo (74.5 °F / 59.0 °F) in a summary row; wind data (WSW 245°, 3 mph speed, 10 mph gust)
- **Condition label:** "Clear" as a text descriptor
- **Weather icon:** Condition-keyed image (clear-day)
- **AQI:** "34.0 (good)" included inline in the weather summary section
- **Observation grid:** Barometer, dew point, humidity, rainfall totals, heat index, wind chill, UV index in a structured grid below the main temperature block

### Continuity notes for C1

The Belchertown pattern shows: station logo + name in a persistent header above conditions; conditions card shows temp (primary) → condition icon + text + feels-like (secondary) → supporting metrics grid. Clear Skies separates these into the page-header card (logo + name) and the current-conditions card (temp + condition), which is the correct architecture per ADR-051 + ADR-024. The "locked default 8" observation fields in ADR-024 correspond to the Belchertown observation grid.

---

## B2 findings: temp curve technique for C1

From `docs/design/B2-recharts-background-findings.md` (Final, 2026-05-31, Recharts 3.8.1):

**Recommended technique:** `usePlotArea()` + SVG `<image>` clipped to plot rect. Key facts:
- `usePlotArea()` is a public exported hook in Recharts ≥ 3.1, confirmed present at `es6/hooks.js` line ~382 in installed 3.8.1.
- Returns `{ x, y, width, height }` — the exact plot rectangle in SVG-pixel space.
- Components placed directly inside `<LineChart>` (as direct SVG children) receive `RechartsReduxContext` automatically — no prop-drilling needed.
- Returns `undefined` on the first render (before axes measure); handle with early `if (!plotArea) return null;`.
- `<Customized component={...}>` is **deprecated in Recharts 3.x** — do not use; use direct placement.
- The chart's SVG surface defaults to transparent; make sure the `<ResponsiveContainer>` wrapper div is also transparent so the card glass layer is the only opaque surface outside the chart.
- `clipId` must be unique per chart instance — use `React.useId()` and strip the `:` characters.

**For C1's today's temp curve specifically:**
- The scene image behind the plot area (`imageHref`) should be the same ADR-047 scene descriptor the page already receives via SSE — no separate fetch.
- The curve itself: dashed-past / solid-future line (split at current time), now-divider marker, H/L annotations, Actual/Feels-Like toggle (img-23 model). These are C1 design decisions, not resolved by B2.
- Accessibility requirements (not resolved by B2, flagged for C1): chart container must have `role="img"` + `aria-label` with summary text; a `<table class="sr-only">` with hourly readings must accompany the chart; scene photo is `aria-hidden="true"`.
- Chart config is file-based (graphs.conf tradition), not dashboard UI — operator edits config files to set which scene image appears behind the plot area.

---

## Open conflicts / questions for the lead

The following are points where two sources disagree, or where a gap creates a design decision the lead must make consciously. **Not resolved here — listed only.**

### 1. Hero content: what goes in the page-header card beyond logo + name?

ADR-051 says the page-header card on Now is `full`-width, half-row height, carries "station logo + station name." ADR-024 lists a separate "Station observations tile (locked default 8)" and a "current-conditions hero (outTemp primary, condition + feels-like secondary)" but says nothing about a station-logo-bearing header card. The C0 inventory lists "Station header / freshness strip" as a candidate with primary data `/station`, `/branding`, SSE state — which suggests adding a last-updated/online freshness indicator to the hero.

**Conflict:** ADR-051 says "logo + station name" only; C0 suggests "station identity + last-updated/online." Lead must decide: does the page-header card carry freshness/SSE-state info, or is it strictly branding?

### 2. Hero card: is a condition icon appropriate in the page-header half-row?

The Belchertown analog shows the logo and station name in the header with no condition icon. The current-conditions card carries the condition icon. ADR-051 defines the hero as a half-row strip (5.5rem tall) — that is compact. Fitting a logo + station name + condition icon + temperature in 5.5rem may conflict with the "current-conditions hero carries outTemp primary" intent of ADR-024.

**Gap:** No ADR resolves whether the condition icon or temperature appears in the page-header hero vs. staying exclusively in the current-conditions card below it. This is a composition question for C1 design.

### 3. ADR-051 hero drop: was it intentional during Phase 2 or an oversight?

ADR-051 says the hero "was dropped and never redesigned." The `now.tsx` code has `<h1 className="sr-only">Now</h1>` — the heading is hidden, not absent. There is no git log entry visible in the last 5 commits that removes a hero/page-header. The drop likely predates the commits in view (the 5 visible commits are all A3/D2/D3 build work). Lead may want to check whether the Phase-2 code ever had a station-logo page-header, or whether it was always deferred and never built.

**Not a conflict — a factual gap** that could inform C1's baseline (build from nothing vs. restore something that existed).

### 4. ADR-024 Webcam/Radar model vs. as-built split

ADR-024 §1 (Now page) specifies: "Radar card (separate — expands to full width when webcam is disabled); Webcam card (separate — shown only when `webcam.json` `enabled: true`…; has Live / Timelapse tab toggle within the card)." This matches the as-built code exactly (separate cards, tab toggle inside webcam card). However, C0 §"Cross-cutting findings" item 4 flags this as a "model mismatch" against "one tabbed tile" and assigns reconciliation to C1/C6.

**The actual ADR-024 text does not say "one tabbed tile" — it specifies separate cards.** C0 may have misread an earlier draft or the NOTES.md inspiration. This apparent conflict needs the lead to confirm: is the as-built separate-cards model the settled ADR-024 intent (in which case C0's flag is a false alarm), or is there a NOTES.md "one tabbed tile" direction that overrides ADR-024?

### 5. Today's temp curve data dependency: archive endpoint for today + forecast future leg

C0 lists "Today's temperature curve" as needing `archive` (today's past readings) + `/current` + forecast future leg. The as-built `now.tsx` already calls `useArchive({ from: todayStart.toISOString() })` (line 307) for `todayStats`. Whether the same hook return is sufficient for a 24h temperature curve (all hourly points from midnight to now + forecast hourly out to midnight) depends on the archive response shape — this is B1 territory. B2 answered "how to put a scene behind the chart"; B1 (data inventory) for the temp curve data shape has not been run for C1 yet. Lead must decide: run B1 for the temp curve before mockup, or proceed on the assumption that `useArchive` + `useForecast` hourly supply what is needed?

### 6. ADR-009 event-trigger hero (deferred) vs. page-header card (ADR-051 deliverable)

ADR-009's event-trigger model (operator binds uploads to triggers: severe-weather alert, weather condition, date range, season, time-of-day) is retained as "future scope for an optional foreground hero." ADR-051 defines the page-header card as carrying "station logo + station name." These are complementary but ADR-009's "foreground hero" concept suggests a richer image-bearing element that ADR-051's half-row strip cannot accommodate.

**Potential future tension:** if the event-trigger foreground hero is eventually built, it would need to be a separate, larger element — not the half-row page-header card. C1 should not conflate the two. The page-header card (ADR-051 deliverable) is the station branding strip; the event-trigger foreground hero is separate future scope.

### 7. `CurrentConditionsCard` internals not read

The as-built `src/components/current-conditions-card.tsx` was not read in this investigation (it is a separate component file). C1's design work will need to audit that file's current content to know what it already renders before deciding what to change. This is not a conflict — it is a scope note for the lead: the prior-decision check for the card's internal layout requires reading that component.

---

*End of C1 prior-decision digest. Deliverable created but NOT committed — awaiting lead review.*
