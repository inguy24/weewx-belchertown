# UI-REDESIGN-PLAN — Clear Skies dashboard UI redesign (the "plan for the plan")

**Status:** Active. This is a roadmap/index, not a decision record — decisions live in ADRs.
**Track A foundations (A0–A4) are CODE-COMPLETE and deployed to weather-dev (2026-05-31); Track B research gates B2 + B3 are DONE (2026-05-31). Now page (C1–C6) CODE-COMPLETE + post-code-complete polish pass (2026-06-02) — pending batched push + deploy + live verification.** Polish includes: precipitation card redesigned to "Precipitation & Humidity" (added dewpoint + humidity), nav rail converted to auto-hide overlay, Solar/UV chart axis overhaul, gauge geometry fixes, dark mode tuning, forecast card visual fidelity fixes. Next: batched deploy of C1–C6, then C7–C10 (see Next action).

**Purpose:** Sequence the UI redesign as a series of **decision points**, each resolved into an
ADR, each ADR operationalized into a **granular, prescriptive execution plan** that drives coding
under tight agent control. Guides decision-making and order of operations; holds no decisions itself.

**Inputs:**
- Inspiration analysis: [docs/design/inspiration/NOTES.md](../design/inspiration/NOTES.md) — 28-pin walk + synthesis.
- Architecture source of truth: [docs/ARCHITECTURE.md](../ARCHITECTURE.md) — React 19 + Vite + Tailwind v4 +
  shadcn/ui + **Recharts** + **Lucide** + **Weather Icons**.
- Process discipline: [rules/clearskies-process.md](../../rules/clearskies-process.md).

---

## ⛔ BLOCKERS — fix before ANY further UI work

The A0 audit (2026-05-29) found build work that was reported done but is **half-finished**. These are
**hard blockers**: no Track A/B/C component work proceeds until they are fixed and verified. Evidence is
file:line so these can't be hand-waved as "probably fine."

| # | Blocker | Reality (verified) | Fix | Repos |
|---|---|---|---|---|
| **B-1** ✅ **DONE — verified live 2026-05-29** | **Traffic does not go through the BFF.** All `/api/v1/*` requests bypassed the realtime BFF and hit the API directly, so no server-side unit conversion happened. | `frontend-host/Caddyfile`, `single-host/Caddyfile`, `examples/reverse-proxy/Caddyfile` all routed `/api/v1/*` direct to API. | **Fixed:** all 3 Caddyfiles now route `/api/v1/*` → `realtime:8766` (commits stack `4334475`, realtime `5f52eac`, meta `02f4ada`). **Verified end-to-end on weather-dev:** BFF `:8766` returns `outTemp 68.2 °F` vs raw upstream `68.22576…°F` — BFF actively transforms (also fixes UAT #10 significant-figures). Lead re-ran realtime suite: 366 passed/10 skipped/0 failed. | stack, realtime, meta docs |
| ~~**B-1b**~~ ✅ **NOT A GAP (verified)** | ~~Wizard must write `[api] upstream_url`.~~ The B-1 agent claimed the wizard doesn't write `realtime.conf`; **that was wrong.** `config_writer.py:466` (`write_all`) calls `write_realtime_conf()` which writes `[api] upstream_url = state.api_address` in a MANAGED REGION. Confirmed by the live weather-dev `realtime.conf` matching that writer's exact format. No action needed. | — | — |
| **B-2** ✅ **DONE — verified 2026-05-29** | **"and Gusty" conditions qualifier never implemented** (ADR-044 §4 mandates it). | `conditions_text.py` had no `wind_gust` param and no gusty logic; `windGust` sat in a ring-buffer, never consumed. | **Fixed** (commit realtime `eafb706`): `wind_gust`/`wind_gust_unit` added to `build_weather_text()` + wired through `compose_weather_text()`; fires when `gust_mph ≥ speed_mph+12` AND `gust_mph ≥ 18` (both converted to mph from declared units); Calm-suppressed. **Verified:** lead re-ran suite (375 passed/10 skipped/0) + exercised the function directly (fires at 20/5 & exact 18/6; not at 15/5; knots path correct; calm+gust → empty). 8 new tests. | realtime |
| **B-3a** ✅ **DONE — verified 2026-05-29** | barometer trend classified client-side (±0.01 inHg in `barometer.ts`). | raw float + hardcoded threshold. | **Fixed** (realtime `cafb6b2`): BFF emits `barometerTrendDirection ∈ {rising,falling,steady,null}`, classified in inHg via authoritative configured unit (label-override safe, never crashes). Verified: 390 tests pass + diff reviewed. **Dashboard consumer = B-3b-baro (in dash batch).** | realtime |
| **B-3b-baro** ✅ **DONE — verified 2026-05-29** | dashboard must consume `barometerTrendDirection` + drop its ±0.01 threshold. | `barometer.ts:11-18`. | **Fixed** (dashboard `6161f2f`): `barometer.ts` now maps the BFF direction string; ±0.01 threshold deleted; threaded through `CurrentResponse` type + hooks. Verified: tsc 0 errors + build ✓ + diff. (Behavioral test didn't run — local test infra missing `@testing-library/dom`.) | dashboard |
| **B-3b-winddir** ✅ **DONE — verified 2026-05-29** | `windDirLabel()` recomputed compass client-side (English-hardcoded, formula disagreed with BFF). | `now.tsx`, `forecast.tsx`. | **Fixed** (realtime `3500659`, dashboard `7340408`): BFF emits canonical `windDirCardinal`/`windGustDirCardinal` (16 codes) on `/current` **and** the live SSE path (shared `_degrees_to_index`; operator `[[ordinates]]` override preserved separately). Dashboard renders via i18n `directions.*` (ADR-21, en-seeded + fallback); forecast uses a shared `cardinalFromDegrees` with the **same formula** (44 tests prove parity); `windDirLabel` deleted. Verified: realtime 419 tests, dashboard tsc+build+diff, grep clean. **Deferred:** non-en translation of `directions.*` → tracked translation pass. | realtime+dashboard |
| **B-4** ✅ **DONE — verified 2026-05-29** | **Timezone display bugs** (violate ADR-020 "always station TZ"). | seismic popup, records date (UTC), radar frame time all ignored station TZ. | **Fixed** (dashboard `6161f2f`): records `formatDate` takes `tz` plumbed from `useStation`; seismic popup uses `formatTime(...station tz)`; radar-map gains `stationTz` prop from now.tsx. All → station TZ. Verified: tsc + build + diff. | dashboard |
| **B-5** ✅ **DONE — verified 2026-05-29** | **a11y + i18n gaps** (violate ADR-026 / ADR-021). | sr-only chart cell omitted unit; `weather` ns unregistered; 5 hardcoded footer aria-labels. | **Fixed** (dashboard `6161f2f`): sr-only homepage chart cell now includes `tempUnit`; `weather` ns registered; footer aria-labels → i18n (`common.json` en). Verified: tsc + build + diff. **Deferred:** full non-en translation of `weather.json` + new `footer.*` keys (en fallback works) → separate translation-pass task. | dashboard |
| **B-6** ✅ **DONE — verified 2026-05-29** | **Logo alt text not enforced** (ADR-022 + coding §5.5 mandate required alt). | `LogoBranding.alt` defaulted to `''`; no `logo_alt` in wizard payload. | **Fixed** (api `3c04620`, meta `b182014` OpenAPI): `logo_alt` plumbed through BrandingSettings/BrandingApplyConfig/current-config round-trip; non-empty fallback (`"<site_title> logo"` / `"Weather station logo"`) so `alt=""` never emitted. **Verified:** 16 new tests pass; lead proved **0 regressions** (33 suite failures identical at parent `db177a6`). | api |

> **Dashboard gate:** the dashboard repo currently has an **uncommitted** `src/api/openapi-v1.yaml` edit +
> untracked `test-results/`. Resolve that before dispatching any dashboard fix (B-3b, B-4, B-5).

**Fix order:** B-1 first (it's the root cause — wiring the BFF makes B-3a/b the correct fix rather than
patching client hacks), then B-2 / B-3 / B-4 / B-5 / B-6 in parallel where repos don't collide.

> **Surfaced debt (NOT a UI blocker; tracked here so it isn't lost):** the **clearskies-api test suite
> has 33 failing tests** as of `db177a6` — pre-existing, unrelated to the UI work (verified: identical
> failures at the pre-B-6 parent). Clusters: `test_almanac_unit.py` (~21: sun-times/moon-phases/polar/
> USNO), `test_station_unit.py::TestTimezoneSourcePriority` (2 — likely test-vs-code drift matching the
> ADR-020 OS-tz change), `aqi` category-bands + integration (5), `test_path_traversal_guard.py` reports
> (2), aggregation/records (2). Plan claimed 0 failures at `617c185`; 33 crept in since. Needs its own
> triage round (test drift vs real code bugs).

---

## How this works — the four-layer flow

| Layer | Answers | Controls | Lives in |
| --- | --- | --- | --- |
| **1. Roadmap plan** (this doc) | what decisions, in what order | sequencing & dependencies | `docs/planning/` |
| **2. ADR** (per decision point) | what we decided & why + **acceptance criteria** | the decision record | `docs/decisions/` |
| **3. Execution plan** (per decision point) | exact files, QC gates, definition-of-done, scope fences | the **agent leash** | `docs/planning/briefs/` |
| **4. Code** | the implementation | — | the repos |

**Discipline (carried from `rules/clearskies-process.md`):**
- ADRs start **Proposed**, user reviews full content, user explicitly approves → **Accepted**. Directional
  chat is *input* to a Proposed ADR, not approval.
- Every ADR must carry **acceptance criteria** (an ADR without them can't be verified).
- The execution plan **references** the ADR; it never **restates** its decisions. **ADR wins on conflict.**
- The execution plan is **prescriptive, low-latitude**: scope in/out (exhaustive file list), per-deliverable
  spec, QC gates, definition-of-done, verification command, agent git restrictions. Agents *execute*, not interpret.
- **Honor prior decisions — don't throw the baby out with the bathwater.** Many UI/behavior decisions already
  exist (Accepted ADRs, the current Belchertown site, Phase-2 dashboard work). For each surface, FIRST surface
  any prior decision, then **explicitly re-affirm it or consciously depart** — edit-in-place for a correction,
  supersede only if fundamentally distinct. Never silently redo or discard what was already decided.

### Why the execution-plan layer exists (the problem it solves)
ADRs capture *what/why* but don't tell an agent its exact scope, QC gates, what "done" means, or where its
latitude ends. That gap is where this project has been burned: scope overrun, false completion claims,
re-invented architecture. The execution plan closes it by making completion and scope **machine-checkable
and explicit** before any agent is dispatched.

---

## Directional decisions made (to be formalized as Proposed ADRs)
These were decided in conversation (2026-05-28) and are **directional input** — each becomes a Proposed ADR
the user reviews before it's binding.
- **Theme:** support **light + dark**; backgrounds keyed by **condition × theme** (dark = Milky Way / night
  imagery, not blue-sky cumulus).
- **Backgrounds:** **photographic** (not illustrated); layered (soft base + crisp foreground effect);
  **operator-replaceable** over a generic default set (sense of place).
- **Per-metric treatment:** **mixed** — text vs. dial/gauge vs. curve decided per metric, not one answer.
- **Card sizing:** fixed cards for now, but **sized to be compatible with the future grid** (no grid engine yet).
- **Icons:** likely keep stack default — **Weather Icons** (hero) + **Lucide** (utility) — pending a bold-enough check.

---

## Decision-point roadmap (sequenced)

> Ordering rule: **Foundations** and **Research gates** both precede **Signature components** — you can't design
> a data-display component before you know the data exists and the design tokens are set.

### Track A — Foundations (design system; no provider-data dependency)
- **A0. ADR reconciliation gate (UI-impacting ADRs).** ✅ **DONE — 2026-05-29 (reconciled + re-approved + deployed).** Before any component design, make every
  UI-impacting ADR **complete and accurate against the current code**. This is NOT a new ADR — it edits
  existing ADRs **in place** (status → Proposed → user re-approves, per `rules/clearskies-process.md`).
  Known divergences to fix (see [C0-PAGE-INVENTORY.md](../design/C0-PAGE-INVENTORY.md) reconciliation
  table): **ADR-002** (charts = Recharts, not ECharts/Tremor), **ADR-046** (fault overlay Proposed-but-
  built, incl. out-of-scope fault popups), **ADR-024** (Records column model; Webcam/Radar tabbed-vs-
  split; inside-temp/custom-records), plus the `/seismic` route fix in `ARCHITECTURE.md`. ADR-009's
  hero-Now-only-vs-global-background tension is reconciled inside **A2**. Audit-for-accuracy scope
  (verify complete & accurate vs code, fix if drifted): ADR-013/014/015/016/020/021/022/023/026/040/
  041/042/044. → edits to existing ADRs (no new ADR). **This gate precedes A1.**
- **A1. Theme & color system** (light + dark, tokens) → **[ADR-048](../decisions/ADR-048-theme-color-tokens.md)
  (Accepted 2026-05-30).** ✅ **DONE.** Encapsulation ADR: adopts the **as-built** token set (shadcn/ui
  `neutral` base in OKLCH, light+dark, 6 curated AA-safe accents, default blue) — the value-definition
  ADR-009 deferred. References ADR-022/023 for branding/switch mechanisms. Faithful swatch render:
  [mockups/A1-theme-tokens.html](../design/mockups/A1-theme-tokens.html). Tracked gaps (not blockers):
  chart palette is 5-step neutral (revisit at first multi-series chart), EPA AQI palette not tokenized
  (add with C6). No code change. 
- **Typography tokens** (font roles + type scale) → **[design-tokens-typography.md](../design/design-tokens-typography.md)**
  (LOCKED 2026-05-31) — Manrope body / Outfit display-role / Lexend chart labels; card titles 600 semibold;
  role-named rem scale. Sibling to ADR-048. Visual proof:
  [mockups/C2pre-type-system.html](../design/mockups/C2pre-type-system.html).
- **A2. Background system** (condition × theme, layered, photographic, operator-replaceable) → ADR.
  ✅ **CODE-COMPLETE + deployed (2026-05-31).** Approach validated in a browser prototype the
  operator accepted ([mockups/background-prototype.html](../design/mockups/background-prototype.html)):
  static **blurred scene photo + real on-glass rain/snow overlay** (screen blend, 3px blur, 75% day /
  25% night opacity). Decisions in **[ADR-047](../decisions/ADR-047-background-system.md) (Accepted
  2026-05-30)**; build tasks in **[briefs/A2-background-system.md](briefs/A2-background-system.md)**
  (**D1 realtime scene builder + precip linger** = realtime `c2d7f57`; **D2 dashboard background layer +
  D3 8 compressed WebP assets ≤300 KB** = dashboard `4e8c896`/`846fc6c`). Live on weather-dev: `/current`
  emits `scene={sky,daytime,overlay}`;
  exact recipe + preserved code in
  [background-system-implementation-notes.md](../design/background-system-implementation-notes.md).
  Snow/storm scenes driven by **provider current conditions** (PWS can't gauge snow); day/night from
  **almanac sun** (not the theme toggle); scene computed server-side with a 15-min precip-linger.
  Operator upload/storage mechanism = **separate config ADR (deferred)**. Lightning-assisted storm
  detection parked in the [main plan backlog](CLEAR-SKIES-PLAN.md).
- **A3. Icon system** — ✅ **CODE-COMPLETE + deployed (2026-05-31)** (both families). **HERO family** → **[ADR-049](../decisions/ADR-049-hero-weather-icons.md)
  (Accepted 2026-05-30):** hero weather glyphs = **Material Symbols (filled), recolored Meteocons-style**
  (gold sun, grey volumetric clouds, gold lightning, periwinkle moon) as inline SVG with gradient fills.
  Weather Icons (too thin), Meteocons-direct (weak/animated-broken precip), and emoji sets (cartoony) all
  rejected. Locked recipe: [mockups/A3-material-gradient.html](../design/mockups/A3-material-gradient.html).
  **UTILITY/STAT/NAV/ALERT family** → **[ADR-050](../decisions/ADR-050-utility-stat-nav-icons.md)
  (Accepted 2026-05-30):** **Phosphor (regular) base** + curated cross-pack exceptions (Tabler `uv-index`;
  Material `flood`; Carbon `tsunami`); 13 weather-alert glyphs; text-only stats (feels-like, dew-point);
  wind icons excluded (→ C2 compass). Astro/AQI/earthquake glyphs **deferred** to C5/C6/seismic. Locked
  render: [mockups/A3-final-icons.html](../design/mockups/A3-final-icons.html). **Code:** hero rewrite =
  dashboard `0140e2f` (inline Material-Symbols SVG, 5 gradient defs, all 29 WMO codes); utility/alert =
  dashboard `8143377`/`90ed053` (`@phosphor-icons/react` 2.1.10 + 3 inline cross-pack glyphs + 13-type
  alert map). Deferred glyph sub-families (astro→C5, AQI→C6, earthquake→seismic) **intentionally left on
  Lucide and flagged in source** with `// TODO(ADR-050 deferred: …)`.
- **A4. Card model & grid-compatible sizing** → **[ADR-051](../decisions/ADR-051-card-footprint-model.md)
  (Accepted 2026-05-30).** ✅ **CODE-COMPLETE + deployed (2026-05-31).** 4-col footprints (`tile`/`wide`/`panel`/`full` + row-span);
  **min-footprint per card** (webcam/wind/radar/current-conditions = 2×2); **half-row grid track** (5.5rem)
  with **zero-waste packing** (strips span 1, data cards 2, tall 4); **universal card discipline** — every
  page is cards (page-header/hero card + controls strip; no free-floating text/buttons; no generic prose on
  data pages); tokens `--gap-grid` 1rem / `--container-max` 80rem / `--card-row` 11rem / `--card-half-row`
  5.5rem; 4→2→1 collapse; translucent glass (opacity at B3). Foundation for the **future operator
  drag-and-drop grid**. Renders: [A4-card-grid.html](../design/mockups/A4-card-grid.html) +
  [A4-page-anatomy.html](../design/mockups/A4-page-anatomy.html). **Code (PRIMITIVES only — not applied to
  pages; that's Track C):** dashboard `1e6c7db`/`d632bba`/`3fd072a`/`cbdb24d`/`82e67e6` — tokens,
  `Card.footprint` prop, `Grid`, `PageHeaderCard`, `ControlsStrip`. Card-glass values are **provisional
  pending B3** (flagged in `index.css`); row-span is documented-only (columns enforced, heights
  content-driven) per ADR-051 "column rule now vs. later."
  **Tracked follow-ons:** restore the Now hero (logo + station name) → **C1**; build an **operator manual**
  (setup/use of the customizable dashboard) → its own deliverable; visitor-facing help destination → open.

### Track B — Research gates
**B1 is decomposed into per-component data inventories** (folded into the Track C workflow below) — NOT one
monolithic audit. Each component opens with "here's exactly what the providers supply for this card." B2 + B3
remain global gates run once.
- **B1 (per-component, just-in-time). Provider-data inventory** — at the start of each Track C component,
  enumerate everything the providers can supply for that card's metric(s), so composition/design is grounded in
  real available data. This replaces the monolithic audit and makes the research bite-sized.
  **Source of truth = our own authored artifacts, read in this order — NOT a live-traffic rediscovery:**
  1. The API response models + canonical field mapping in `weewx-clearskies-api` (the `/current` and `/archive`
     contracts — this enumerates every field, type, units, and always-present-vs-conditional). This is the answer.
  2. Each provider module's `CAPABILITY` / `supplied_canonical_fields` declaration (per-provider supply set).
  3. Our captured `docs/reference/api-docs/<provider>.md` and `docs/contracts/`.
  4. The weewx 5.3 column reference at `docs/reference/weewx-5.3/` for archive columns feeding any series.
  We wrote the contract and the code; the inventory is a READ of those, not a re-derivation from the wire. A live
  `/current` + `/archive` hit on weather-dev is **demoted to an optional confirmation spot-check** — used ONLY to
  check whether a contract-marked *conditional* field is actually populated for this station/provider, and only
  when flagged to the lead first. Default B1 run touches no live endpoint.
- **B2. Recharts background-image support** (global) — ✅ **DONE 2026-05-31.** Recharts CAN render a scene image behind the plot area. Recommended technique: `usePlotArea()` hook (Recharts 3.x public API); `<Customized>` is deprecated. Charts (including background image) are configured through chart config files (`graphs.conf`-style), not the dashboard UI. Findings: [docs/design/B2-recharts-background-findings.md](../design/B2-recharts-background-findings.md).
- **B3. Accessibility-contrast + image-performance budget** (global) — ✅ **DONE 2026-05-31.** Card-glass opacity is an operator-configurable default; no hard-locked contrast value, no research gate. Shipped defaults: light `rgba(255,255,255,0.72)`, dark `rgba(30,35,55,0.55)`. PROVISIONAL flag removed. Findings: [docs/design/B3-contrast-performance-findings.md](../design/B3-contrast-performance-findings.md).

### Track C — Components, ALL pages (depend on A + B)
**Scope = every page, not just the "now"/home page** — forecast page, almanac, radar, earthquakes, alerts,
records, etc. each have cards. Track C opens with a page inventory, then walks components page by page.

**LOAD-BEARING — the INSPIRATION source (READ AND *LOOK* before designing ANY card — steps 0/2/3).**
The look of every card is grounded in the inspiration walk — it is NOT invented, NOT derived from the data
inventory, and NOT taken from a teammate's or doc's one-line summary. Before designing a card you **MUST open
the actual files and load the pixels**:
- [docs/design/inspiration/NOTES.md](../design/inspiration/NOTES.md) — the locked design direction + per-image
  notes (which image models which card, what was loved, what to steal/skip).
- [docs/design/inspiration/raw/img-NN.png](../design/inspiration/raw/) — **the specific inspiration image(s)
  the card is modeled on, opened AS IMAGES** (Wind = **img-17**, today's temp curve = img-23, GRID model =
  img-21, etc.). Reading the NOTES *line* is NOT enough — you must **LOOK at the image**.
A card built from a data inventory or a generic mental model instead of its inspiration image is **wrong by
construction** — the loved concept lives in the pixels. **(2026-05-31: the C2 Wind card was built twice as a
generic compass-rose-with-needle because the inspiration was skipped; img-17 is actually a tick-rim
*information container* with degree/cardinal/speed/gust all stacked INSIDE the circle. Do not repeat this.)**

**LOAD-BEARING — the locked layout/footprint sources (read EVERY component, steps 0/2/3).**
The card's **size and grid placement are already decided** in the A4 grid mockups — they are NOT a fresh
decision and must NOT be theorized from ADR-051 prose or from a teammate's summary:
- [docs/design/mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) — the 4-column grid + every
  card's footprint (col-span × row-span) at desktop/tablet/phone.
- [docs/design/mockups/A4-page-anatomy.html](../design/mockups/A4-page-anatomy.html) — the hero/page-header
  + controls-strip + the **half-row track** grid (`grid-auto-rows: var(--card-half-row)` = 5.5rem; strip = 1
  track, data card = 2, 2×2/tall = 4).

**LOAD-BEARING — the locked type source (read EVERY component, steps 0/2/3).**
The card's **font families, sizes, and weights are already decided** in
[docs/design/design-tokens-typography.md](../design/design-tokens-typography.md) (LOCKED 2026-05-31).
They are NOT a fresh decision and must NOT be invented per-card. Card mockups and all component code
MUST consume these type tokens (`--font-display`, `--font-sans`, `--font-chart`, `--text-*`,
`--font-semibold`, etc.) — they must NOT invent their own font sizes, font families, or font weights.
This constraint is parallel to the footprint constraint: just as a card's footprint must not be
re-theorized from ADR-051 prose, a card's typography must not be re-theorized outside this token spec.

The Now-page grid is **`repeat(4, 1fr)`, `gap: 1rem`, `grid-auto-rows: 5.5rem`, container 80rem.** A card's
footprint (e.g. Current Conditions = **2×2** = 2 cols × 4 half-row tracks ≈ 22rem) is a **fixed given** —
content fits the box (`overflow:hidden`), the box does not grow to the content.

**Per-component workflow (each component is a self-contained mini-cycle):**
0. **Read-and-LOOK at the INSPIRATION first (MANDATORY GATE — before any other step).** Open
   [docs/design/inspiration/NOTES.md](../design/inspiration/NOTES.md) **and the card's specific
   `raw/img-NN.png` as an IMAGE** (per the LOAD-BEARING inspiration source above). The loved concept lives in
   the pixels — a NOTES line, an ADR summary, or a teammate's description is NOT a substitute. Identify the
   modeling image(s) for this card and state what is loved about it. **Do not design, compose, or mock up
   anything until this is done.** THEN do the **prior-decision check** — surface every existing decision for
   this surface (ADRs, current site, Phase-2 work) AND **pull the card's LOCKED FOOTPRINT (col-span × row-span)
   verbatim from the A4 grid mockups above + the C0 inventory.** Record it explicitly (e.g. "Current
   Conditions = 2×2 per A4-card-grid"). Re-affirm or consciously depart; never theorize the size.
1. **Data inventory (B1 slice)** — "here is everything the providers / weewx give us for this card."
   Read our own authored artifacts (API `/current` + `/archive` contract → provider `CAPABILITY` decls →
   captured api-docs / contracts → weewx column reference), in that order. Do NOT rediscover from live wire
   responses; a live endpoint hit is an optional conditional-field spot-check only, flagged to the lead first.
2. **Composition** — what's grouped on the card vs. split out, **WITHIN the locked footprint from step 0**.
   The footprint is a constraint, not a variable; if the content can't fit the locked box, that is a
   composition problem to solve (shrink/re-group), surfaced to the lead — NOT a license to resize the card.
   Typography is equally constrained: use the locked type tokens from
   [design-tokens-typography.md](../design/design-tokens-typography.md) — `--font-display` (Outfit) for
   the large stat numeral, `--font-sans` (Manrope) for body/labels/card title, `--font-chart` (Lexend)
   for chart SVG text, card title at `--font-semibold` (600). Do NOT introduce new font sizes or families.
3. **Mockup** — **MUST be built on the actual Now-page grid: reuse the A4 grid CSS** (`grid-4col` +
   `grid-auto-rows: 5.5rem` + explicit, conflict-free col/row-span classes) and place the card at its
   **locked footprint** inside that grid. **NEVER** render the card as a standalone, full-width, or
   free/fixed-pixel-height box — that hides the true size and produced throw-away mockups.
   The mockup **must also use the locked type tokens** from
   [design-tokens-typography.md](../design/design-tokens-typography.md): `--font-display` (Outfit) for
   the large stat numeral, `--font-sans` (Manrope) for body/labels/card title at `--font-semibold` (600),
   `--font-chart` (Lexend) for any chart SVG text. Using the real fonts in the mockup is the only way
   the lead can verify typography at the composition stage.
   **Render it and LOOK before sending** (per [rules/coding.md](../../rules/coding.md) "Render and LOOK"):
   screenshot the HTML headless, open the PNG, inspect it; reading markup or an `axe` pass is NOT
   verification. The lead inspects the render, not the markup. **Keep the mockup minimal** — only the
   surface requested at its locked size; no unrequested toggles, neighbour/ghost cards, degrade galleries,
   or annotation panels.
4. **Code** — implement directly from the approved mockup + governing docs (typography tokens, color
   tokens, grid spec). **No per-card ADR.** Per-card ADRs were rejected (2026-05-31) — agents don't
   read them and they add process overhead without controlling quality. The governing documents
   (design-tokens-typography.md, ADR-048, ADR-051, the approved mockup) are the source of truth.
   Page-level or architectural ADRs still apply where needed.

- **C0. Page inventory** — ✅ **DONE 2026-05-29** (built as a by-product of the A0 ADR-reconciliation gate).
  Full card-level inventory: 11 routes, ~40 candidate cards, ~8 flagged net-new. Authoritative C1–C14 work
  list lives in **[docs/design/C0-PAGE-INVENTORY.md](../design/C0-PAGE-INVENTORY.md)**. The named C1–C6
  below are the signature components within that fuller list; the C0 file is authoritative for the full
  enumeration. No ratification step — per-card drift is caught by the per-component workflow's
  prior-decision check at each component.
- **C1. Current-conditions card** + **today's temperature curve** + **Now-page hero.** ✅ **CODE-COMPLETE
  (2026-05-31).** Approved mockup: [mockups/C1-now-hero-conditions.html](../design/mockups/C1-now-hero-conditions.html).
  Design docs: [C1-prior-decisions.md](../design/C1-prior-decisions.md), [C1-data-inventory.md](../design/C1-data-inventory.md),
  [C1-composition.md](../design/C1-composition.md). Three surfaces: **(A)** NowHeroCard — full-width half-row,
  logo left + station name (`branding.siteTitle`, fallback "My Weather Station") + location right; **(B)**
  CurrentConditionsCard redesign — icon-left (ADR-049 Material gradient, ~112px) + Outfit 4.75rem temperature +
  feels-like + condition sentence + Hi/Lo (red/blue with `--temp-hi`/`--temp-lo` theme-aware tokens) + **(C)**
  integrated Recharts temperature curve (past solid+area, future dashed, Now marker, Y-axis scale).
  **Now page migrated to A4 Grid primitive** (4-col, half-row tracks); all cards given footprint props.
  Typography tokens (Manrope/Outfit/Lexend @fontsource) added to `index.css`.
  **Commits:** dashboard `2fbc741` (full C1 redesign: NowHeroCard + CC card + TempCurve + Grid migration +
  typography tokens; tsc 0 errors, vite build clean, 282 tests passed / 0 failed).
- **C2. ⭐ Wind compass** (loved; signature; info-inside-the-dial). ✅ **CODE-COMPLETE (2026-05-31).**
  Approved mockup: [mockups/C2-current-wind.html](../design/mockups/C2-current-wind.html). Tick-rim
  info-container dial modeled on img-17; 72 ticks, accent-highlighted direction indicator, bearing+cardinal+
  speed+10-min-avg+max-gust all inside the circle; `ph:wind` in title and readout block; 1 decimal place on
  all wind values; Outfit 3rem speed (not 4.75rem — that's C1 temperature only). BFF-derived fields:
  `windSpeedAvg10m` / `windGustMax10m` (10-min true-wall-clock rolling window, 60s min coverage).
  **Commits:** realtime `38962a1` (wind_rolling_window.py + registrations + SSE/REST + 19 tests; suite
  497/0), contract `3770c44`+`d5e37d0` (OpenAPI both copies), dashboard `f86f6f3` (WindCompassCard.tsx +
  types + now.tsx wiring + i18n; tsc 0 errors, vite build clean, axe 0 new violations). Execution plan:
  [C2-WIND-COMPASS-PLAN.md](C2-WIND-COMPASS-PLAN.md). ADR-050 amended to allow `ph:wind` on C2.
  Typography doc corrected to scope `--text-stat-hero` to C1 temperature only.
- **C3. Forecast screen** — icon-rich columns + time-range tabs + expandable columns. ✅ **CODE-COMPLETE
  (2026-06-01).** Approved mockups: [mockups/C3-now-forecast-card.html](../design/mockups/C3-now-forecast-card.html),
  [mockups/C3-forecast-page.html](../design/mockups/C3-forecast-page.html),
  [mockups/C3-wind-symbol.html](../design/mockups/C3-wind-symbol.html). Four surfaces: **(A)** NowForecastCard —
  tabbed 2×1 card (Today 3-hour columns + 7-Day daily columns), tabs inline with title right-justified;
  **(B)** ForecastHourlyCard — 4×2, Today/Tomorrow tabs, 24h scrollable with visible scrollbar, no expandable
  detail; **(C)** ForecastDailyCard — 4×2, 7 daily columns with img-12-style full-width expandable detail
  panel (one cohesive shaded block for selected column + detail); **(D)** ForecastDiscussionCard — self-hides
  when null, AFD prose + issued footer. BBC Weather-style wind symbols (grey circle + directional tail,
  uniform 20px across all surfaces). Combined "74°/58°" hi/lo temps. Dual trend lines (hi red + lo blue)
  with generous vertical space. `useForecast` parameterized with `{ hours?: number }`. 13 i18n keys.
  **Commits:** mockups `3760918` (meta repo); dashboard `c633efe`/`19d7d7d`/`3eba666`/`64889ad`/`efdc746`
  (5 commits: WindSymbol + TempTrendLine, HourlyStrip + DailyColumns, NowForecastCard + now.tsx wiring,
  forecast page cards + forecast.tsx rewrite, i18n + useForecast params; tsc 0 errors, vite build clean).
  **Pending:** push + deploy to weather-dev (batched with C1–C6, see Next action).
  **Post-code-complete refinement (2026-06-02):** 16 dashboard commits fixing visual fidelity issues
  found during live review. Wind symbols: direction defaulting to North when unknown → shows no tail
  (`3801d7b`); Today vs. 7-Day sizing/font consistency (`a7060cf`/`239be60`/`bb2a3ac`/`8a59bd0`/
  `1ee2962`/`aad81f0`/`da549a4`); hi/lo trend lines share one Y-axis scale (`c3dc7ab`); 7-Day trend
  height + font sizing to fit 11rem row (`c83ca76`); precipitation font + gap fixes (`e761be6`/
  `3481565`/`396591f`/`56702ad`); weather icon sourced from conditions engine weatherCode, not scene
  object (`e0d357c`). All fixes are mechanical — no layout or data changes.
  **Forecast detail + snow enrichment (2026-06-03):** API + dashboard work to enrich the 7-day
  detail panel and add precipitation/snow support. Plan:
  [archive/FORECAST-DETAIL-SNOW-PLAN.md](../archive/FORECAST-DETAIL-SNOW-PLAN.md) (COMPLETE).
  **API (11 commits):** new DailyForecastPoint fields (dewpoint, humidity, visibility, snow, storm
  risk) with provider mappings for all 5 providers; Aeris convective outlook integration; snow/snowRate
  blended into /current; sunrise/sunset computed locally via Skyfield almanac; narrative mapped from
  Aeris weatherPrimary. **Dashboard (13 commits):** detail panel enriched with full chip grid; hourly
  card fixed to 24-hour windows per tab (was calendar-date partition); all labels i18n'd; unit suffixes
  driven by API units block; first column auto-selected; card title icons removed; CloudSun hero icon
  added to PageHeaderCard. **Deployed and verified live 2026-06-03.**
- **C4. Now-page stat tiles** (eight 1×1 tiles — presentation-layer re-skin of existing cards).
  ✅ **CODE-COMPLETE (2026-06-01).** Brief: [archive/C4-STAT-TILES-PLAN.md](../archive/C4-STAT-TILES-PLAN.md).

  **Grid change (2026-06-01):** Precipitation & Barometer split into two separate tiles; Solar & UV
  split into two separate tiles. Today's Highlights shrinks from `full` 4×1 to `wide` 2×1 and moves
  up to pair with Today's Forecast. The eight stat tiles fill two full rows of 4 below.

  | Surface | Footprint | Current code | Inspiration |
  |---|---|---|---|
  | A. Precipitation & Humidity | `tile` 1×1 (A4 line 506) | `precipitation-card.tsx` (extracted, split, redesigned 2026-06-02: added dewpoint + relative humidity) | img-21 (tile grid) |
  | B. Barometer | `tile` 1×1 (A4 line 515) | `precipitation-barometer-card.tsx` (extracted, split) | img-21, img-19 (pressure gauge) |
  | C. Solar Radiation | `tile` 1×1 (A4 line 524) | `solar-uv-card.tsx` (extracted, split) | img-21 |
  | D. UV Index | `tile` 1×1 (A4 line 533) | `solar-uv-card.tsx` (extracted, split) | img-21, img-18 (UV bell-curve — DEFERRED, too dense for 1×1) |
  | E. AQI | `tile` 1×1 (A4 line 543) | `now.tsx` inline (~lines 393–417, `AqiGauge`) | img-21, img-15 (AQI detail) |
  | F. Sun & Moon mini | `tile` 1×1 (A4 line 552) | `now.tsx` inline (~lines 418–456) | img-11, img-14 (compact dual arcs: sun + moon, per operator 2026-06-01; full arcs also on C7 Almanac) |
  | G. Lightning | `tile` 1×1 (A4 line 561) | `now.tsx` inline (~lines 458–489) | img-21, img-28 (time-vs-distance strike scatter — approach/recede V-shape) |
  | H. Recent Earthquake | `tile` 1×1 (A4 line 570) | `now.tsx` inline (~lines 491–521) | img-21 |

  **Work:** split `precipitation-barometer-card.tsx` into two files; split `solar-uv-card.tsx` into
  two files; extract 4 inline cards (E/F/G/H) to standalone component files; re-skin all 8 with
  design-system tokens (typography, colors, Phosphor icons, Card primitive with `footprint` prop).
  ADR-050 deferred icon sub-families all resolved (see ADR-050 amendment 2026-06-01).
  **Data layer change (corrects prior claim of "no new BFF fields"):** new `LightningStrikeBuffer`
  module in the BFF — 24h rolling window of per-strike `(timestamp, distance)` pairs, emitted as
  `lightningStrikeHistory` on `/current` REST and SSE. Same pattern as the C2 wind rolling window.
  **Data:** `/current` (rain/barometer/radiation/UV/lightning + `lightningStrikeHistory` NEW),
  `/aqi/current`, `/almanac` (sun/moon), `/earthquakes` (first TWO records), `/forecast` (UV peak).
  **Mockup approved 2026-06-01** ([C4-stat-tiles.html](../design/mockups/C4-stat-tiles.html)). Key
  design decisions from mockup iteration:
  - Three-tier type hierarchy: 18px primary / 13px secondary / 10px tertiary (all below hero temp).
  - Sun & Moon: dual nested arcs (Option A) on the Now mini tile — corrects prior "TEXT-ONLY" claim.
    Gold arcs for sun, silver for moon, with Sunrise/Sunset/Moonrise/Moonset labels.
  - Solar Radiation: rolling 24h chart (right edge = now), yellow area (theoretical), orange line (actual).
  - UV Index: fixed daily window 12a–12a, gradient bell curve (img-18 style, NOT deferred — fits 1×1).
  - AQI: gauge-left + pollutant column right (per-pollutant readings DO fit 1×1). `ph:leaf` icon.
  - Barometer: dynamic scaling (default 29.32–30.52, 29.92 centered; auto-scale on extremes).
    Threshold ticks at 29.80 (low boundary) and 30.20 (high boundary). Gauge indicator animates.
  - Earthquake: shows last TWO events. Time format: min (<1h) / hrs with decimal (>1h) / days (>1d).
  - All gauges: unfilled ticks grey in both themes, filled ticks colored, animate on data change.
  **Known gaps/deferrals:** EPA AQI palette not tokenized (ADR-048 gap — continue hardcoded
  `aqiColor()`). Per-pollutant AQI data availability from API needs verification.

  **Post-code-complete refinement (2026-06-02):** Extensive visual polish pass after live review
  (50+ dashboard commits). Key changes:

  - **Precipitation card redesigned → "Precipitation & Humidity"** (`7c599fd`/`1d1e743`/`b357d01`):
    retained all precipitation info (rate/today/icon); added dewpoint (primary, bold, with °F/°C
    suffix) + relative humidity (secondary). Dewpoint ordered above humidity as the more
    scientifically accurate measure per operator directive.
  - **Gauge indicator fixes** (`1a588ea`/`6357445`): tick width narrowed from 5 to 3 (just wider
    than regular ticks); duplicate indicator tick removed from tick array.
  - **Sun & Moon arc geometry** (9 commits `45ce028`–`c991cd5`): elliptical arcs (rx/ry), CY
    tuning, viewBox adjustments, font sizing, top-clipping prevention for sun glow.
  - **AQI card fixes** (`9f1239e`/`5b94de6`/`4af142c`): gauge wrapper alignItems, leaf icon sizing
    spanning full text block, leaf-to-text gap reduced.
  - **Solar Radiation + UV Index chart axis overhaul** (25+ commits `f12df8a`–`90d714f`): solar
    chart switched to 24h rolling archive window; UV chart converted from archive data to predicted
    bell curve (`sin²` formula from sunrise/sunset); Y-axis ticks corrected `[0,3,6,9,12]` →
    `[0,4,8,12]` per mockup; fixed Recharts `hide` bug (#428) workaround, UTC-vs-local tick
    boundaries, negative margin clipping, zero-guard axis. Lessons documented in
    [recharts-axis-reference.md](../reference/recharts-axis-reference.md) and
    [rules/coding.md §6](../../rules/coding.md).
  - **Build verification rule** added to [rules/coding.md §7](../../rules/coding.md) — `tsc`
    failures cause silent deploy failures because `tsc -b && vite build` means stale `dist/` if
    tsc errors exist. Rule: zero TS errors before every commit.
  - **Barometer gauge geometry** (`84b4a46`/`26309dd`): arc center CY 100→92, radius 88→85,
    endpoint labels repositioned, wrapper alignItems fix.
  - **Stat tile CSS alignment** (`15c22bf`): batch alignment of font sizes, border radii, gaps,
    and divider margins across all 8 tiles to match C4 mockup exactly.
  - **Briefs created:** [gauge-geometry-fix.md](briefs/gauge-geometry-fix.md),
    [now-page-c4-tile-fixes.md](briefs/now-page-c4-tile-fixes.md),
    [solar-uv-chart-fixes.md](briefs/solar-uv-chart-fixes.md).

- **C5. Active Alert banner + Today's Highlights strip** (two full-width Now-page elements).
  ✅ **CODE-COMPLETE (2026-06-02).** Brief: [briefs/C5-FULL-WIDTH-CARDS-PLAN.md](briefs/C5-FULL-WIDTH-CARDS-PLAN.md).

  | Surface | Footprint | Current code | Inspiration |
  |---|---|---|---|
  | A. Active Alert banner | `full` 4×1 (A4 line 459) | `alert-banner.tsx` | img-21 |
  | B. Today's Highlights | `wide` 2×1 (A4 line 496, moved 2026-06-01) | `todays-highlights-card.tsx` | img-21, img-10 (per-stat icons) |

  **Work done:** Alert banner redesigned — severity-colored glass tokens (`--alert-glass`/
  `--alert-border`/`--alert-fg`), expandable detail panel, multi-alert flip-through with prev/next
  navigation, ADR-052 severity-aware classification, 5 new Material Symbols alert icons, 13 Aeris
  hazard categories; moved inside Grid as first child (ADR-051 universal card discipline). Highlights
  extracted to standalone `TodaysHighlightsCard` — 6-stat strip with Phosphor icons, `wide` 2×1
  footprint. `aria-live` added for reliable SR announcements.
  **Commits:** dashboard `198ec34`–`37a3582` (11 commits: types, glass tokens, icon expansion,
  category classifier, alert banner rewrite, highlights extraction, i18n, a11y fix; tsc 0 errors,
  vite build clean).
  **Data:** `/alerts` (AlertRecord[]), `useTodayStats()` derived from `/current` + today's `/archive`.

- **C6. Radar + Webcam card revamp** (two 2×2 media cards).
  ✅ **CODE-COMPLETE (2026-06-02).** No brief needed — straightforward fix (footprint correction +
  component extraction + legend addition).

  | Surface | Footprint | Current code | Inspiration |
  |---|---|---|---|
  | A. Radar | `wide` + rowSpan=2, 2×2 | `now.tsx` Card + `radar-map.tsx` | img-15 (radar with legend) |
  | B. Webcam | `wide` + rowSpan=2, 2×2 | `webcam-card.tsx` (extracted) | — |

  **Work done:** (1) Radar card footprint fixed — removed ternary that toggled between `wide`/`tile`
  based on webcam presence (ADR-051 violation); now always `footprint="wide" rowSpan={2}`.
  (2) Radar color legend added — `RadarLegend` overlay inside `radar-map.tsx` showing RainViewer
  Universal Blue (scheme 2) precipitation intensity gradient with "Light"/"Heavy" labels; positioned
  bottom-right of map; `aria-hidden` (supplementary visual). Fixed code comment: scheme 2 is
  "Universal Blue", not "Original". (3) Webcam extracted to standalone `webcam-card.tsx` — props:
  `webcamConfig`, `refreshTs`, `videoRefreshTs`; internal state: tab selection, image/video
  availability; proper ARIA tab pattern (`role="tab"` + `aria-selected`, corrected from `aria-pressed`);
  `footprint="wide" rowSpan={2}`. (4) `now.tsx` cleaned up — removed 3 state variables + unused
  import; wired `<WebcamCard>`. (5) i18n keys added: `webcamTabLive`, `webcamTabTimelapse`,
  `noData.timelapse` in `now.json`; `legendLight`, `legendHeavy` in `radar.json`.
  **Verified:** `tsc --noEmit` 0 errors, `vite build` clean.
  **Data:** `/radar/frames`, `/capabilities`, `/webcam.json`.
  **Known gaps:** radar legend colors are RainViewer-scheme-specific; Radar/Webcam tabbed-vs-split
  reconciliation with ADR-024 still open.

  **→ After C4 + C5 + C6: the Now page is complete.**

  **Now-page polish pass (2026-06-02).** With C1–C6 code-complete, a visual review session
  produced cross-cutting polish work spanning the entire Now page:

  - **Nav rail overhaul** (`eeaf00b`/`616c548`): permanent 64px left sidebar replaced with an
    auto-hiding floating glass panel. Desktop rail: `position:fixed`, vertically centered,
    card-glass + shadow-lg + rounded-xl, slides in/out with 200ms ease transition. Grab bar
    (button pill, w-1 h-10) visible when rail hidden. Pin toggle (PushPin/PushPinSlash Phosphor
    icons) persists to `localStorage('clearskies.nav.pinned')`. 30-second auto-hide on mount/
    mouseleave; cleared on mouseenter/pin. Rail overlays content (not a flex sibling). A11y
    remediation: `aria-label`/`aria-expanded` on grab bar, tab management to avoid invisible
    tab stops. **Amends ADR-009 navigation section** — see ADR-009 amendment 2026-06-02.
  - **Dark mode card-glass opacity** (`2e9d99f`): increased from 0.72 → 0.85 for better
    readability over dark photo backgrounds.
  - **Dark mode basemap** (`8573386`/`0045cc4`): radar map switches to CartoDB dark tiles in
    dark theme; canonical CARTO attribution string.
  - **Theme sync via BFF** (`efa15ac`): dashboard dark/light mode syncs with background scene's
    `daytime` field from the BFF, not just the CSS media query.
  - **Visual polish:** photo credit moved to footer (`fdac474`), light mode `--border` to
    `rgba(0,0,0,0.12)` per mockup (`6e7b820`), webcam `object-contain` instead of `object-cover`
    (`9cccb53`), webcam tab pills match forecast style (`f3351de`), main temp + feels-like show
    1 decimal place (`18b2fee`).

- **C7. Almanac page** (7 existing cards re-skinned + 2 net-new arc visualizations).
  Brief: [briefs/C7-ALMANAC-PAGE-PLAN.md](briefs/C7-ALMANAC-PAGE-PLAN.md).

  | Surface | Footprint | Build state | Inspiration |
  |---|---|---|---|
  | A. PageHeaderCard | `full` 4×1 half-row | Net-new | — |
  | B. Sun details + Sun arc | `wide` 2×2 | Exists (text) + net-new (arc SVG) | img-11, img-14 |
  | C. Moon details + Moon arc | `wide` 2×2 | Exists (text) + net-new (arc SVG) | img-11, img-14 |
  | D. Positional data | `tile` 1×1 | Re-skin | — |
  | E. Monthly Averages (Recharts) | `full` rowSpan=2 (4×2) | Re-skin | — |
  | F. Planets visible | `wide` 2×1 | Re-skin | — |
  | G. Lunar Eclipses | `tile` 1×1 | Re-skin | — |
  | H. Meteor Showers | `full` 4×1 | Re-skin | — |

  **Work:** migrate `almanac.tsx` to Grid + PageHeaderCard; build Sun arc SVG (sunrise→sunset arc
  with current-position marker, per img-11) and Moon arc SVG (moonrise→moonset arch + phase glyph,
  per NOTES item 9 "moon gets its own arch"); re-skin all existing cards with design-system tokens.
  **Data:** `/almanac`, `/climatology/monthly`, `/almanac/planets`, `/almanac/moon-names`,
  `/almanac/eclipses`, `/almanac/meteor-showers`.
  **Deferred:** year-long sunrise/sunset chart, daylight chart, moon-phase calendar (require
  endpoints not yet built — `/almanac/sun-times`, `/almanac/moon-phases`; not in C7 scope).

- **C8. Seismic page** (2 existing cards re-skinned + map legend net-new + ADR-046 reconciliation).
  Brief: [briefs/C8-SEISMIC-PAGE-PLAN.md](briefs/C8-SEISMIC-PAGE-PLAN.md).

  | Surface | Footprint | Build state | Inspiration |
  |---|---|---|---|
  | A. PageHeaderCard | `full` 4×1 half-row | Net-new | — |
  | B. Seismic map | `wide` rowSpan=2 (2×2) | Re-skin + add legend | img-15 |
  | C. Earthquake list | `wide` rowSpan=2 (2×2) | Re-skin | — |
  | D. Map legend/key | Within map card or separate `tile` | Net-new | img-15 |

  **Work:** migrate `seismic.tsx` to Grid primitive (currently uses raw CSS grid `lg:grid-cols-2`);
  add map legend (explain age-color encoding + magnitude-size encoding + fault line symbology);
  apply design-system tokens.
  **Pre-requisite decision (BLOCKS mockup):** ADR-046 reconciliation — it is **Proposed** but already
  implemented, and fault popups + slip-type styling exceed its stated scope. Must accept + amend scope,
  or trim code to match the ADR, before treating faults as locked.
  **Data:** `/earthquakes`, `/earthquakes/config`, `/earthquakes/faults`, `/station`.

- **C9. Records page** (structural reconciliation + re-skin).
  Brief: [briefs/C9-RECORDS-PAGE-PLAN.md](briefs/C9-RECORDS-PAGE-PLAN.md).

  | Surface | Footprint | Build state |
  |---|---|---|
  | A. PageHeaderCard + period selector | `full` 4×1 half-row | Net-new |
  | B. Per-section record cards (Temp, Wind, Rain, Humidity, Baro, Sun) | `full` each | Re-skin + structural reconciliation |

  **Work:** reconcile structural mismatch with ADR-024 (ADR wants one sortable YTD|All-Time table +
  year selector; build has per-section cards, single period, not sortable). Decide "Today" column
  (keep/drop — beyond ADR-024). Reconcile inside-temp/custom-records removal. Migrate to Grid +
  design-system tokens.
  **Pre-requisite decision (BLOCKS mockup):** the structural model must be resolved before any
  design work begins — operator decides per-section cards (current) vs one unified sortable table
  (ADR-024).
  **Data:** `/records`, `/current` (Today column), `/station`.

- **C10. Reports, About, Legal pages** (grid migration batch — three simpler pages sharing a common
  pattern: wrap existing content in Grid + PageHeaderCard, apply typography tokens).
  Brief: [briefs/C10-PAGE-MIGRATION-PLAN.md](briefs/C10-PAGE-MIGRATION-PLAN.md).

  **Reports (`/reports`):** migrate selectors into ControlsStrip card; apply design-system tokens.
  Already richer than Belchertown (parsed sortable tables, download actions). Add provenance
  disclaimer ("Generated locally; not official NOAA" — C0 inventory, per ADR-024).

  **About (`/about`):** migrate 4 existing cards to Grid; fix markdown rendering (currently
  plain-text `whitespace-pre-wrap` — switch to ReactMarkdown + remark-gfm like custom pages use;
  this is C0 finding #8).

  **Legal (`/legal`):** migrate 5 existing cards to Grid; add Weather Data Disclaimer card
  (Belchertown feature identified as missing in C0 inventory — needs operator decision on format:
  drop, fold into Privacy, net-new card, or operator markdown).

  **Data:** Reports → `/reports/*`; About → `/station`, `/content/about`; Legal → `/content/legal`.

### Dependency sequencing (C4–C10)

```
C4 (stat tiles) → C5 (full-width) → C6 (media cards) = NOW PAGE COMPLETE
                                           │
C7 (almanac) ──────────────────────────────┤
C8 (seismic) ──────────────────────────────┤  parallel after Now page done
C9 (records) ──────────────────────────────┤  blocked on structural decision
C10 (reports/about/legal) ─────────────────┘  parallel with C7–C9
```

- **C4** is the immediate next step (6 uniform tiles, highest card count, establishes the tile pattern).
- **C5** depends on C4 only for resolved icon sub-families; otherwise independent.
- **C6** depends on C4/C5 so the Now page is holistically testable.
- **C7–C10** are independent of each other; can be parallelized after C6.
- **C9** is blocked on a structural reconciliation decision — must happen before mockup work.

### Out of scope here — separate future plan
- **Operator drag-and-drop customizable GRID** (operator add/remove/move tiles + layout persistence). The
  **operator** customizes the dashboard their visitors see; Now page first. Its own plan + ADR(s). The
  footprint contract it consumes is locked in **[ADR-051](../decisions/ADR-051-card-footprint-model.md)**
  (footprints, min-footprints, half-row zero-waste packing, universal card discipline). **Compatibility
  constraint:** everything in Track A/C uses grid-compatible footprints so nothing needs redesign when the
  grid lands. Do **not** build the grid engine here.
- **Operator manual** (how operators set up and use the customizable dashboard + the system generally). A
  confirmed needed deliverable (per ADR-051); its own build, not part of this UI plan. Operator-facing
  explainer prose pulled off data pages lands here.

---

## Execution-plan brief template (per C-item)

Each C-item gets a brief in `docs/planning/briefs/` **before any agent is dispatched**. Briefs follow the
standard established by [C2-WIND-COMPASS-PLAN.md](../archive/C2-WIND-COMPASS-PLAN.md) and
[C3-FORECAST-SCREEN-PLAN.md](briefs/C3-FORECAST-SCREEN-PLAN.md). **No per-card ADRs** (rejected 2026-05-31).
The governing documents (design-tokens-typography.md, ADR-048, ADR-051, the approved mockup) are the source
of truth; page-level or architectural ADRs still apply where needed.

**Required sections (10 — every brief, no exceptions):**

0. **Orientation for a fresh session** — project layout, three sub-repos + paths, data flow the card
   depends on, deploy target, architecture source of truth, git safety block (agents may ONLY
   `git add`/`commit`/`status`/`log`/`diff` — NO pull/push/fetch/rebase/merge/worktree).
1. **Context** — what the component does today (with specific file:line refs to existing code), what
   is changing, why. Explicit statement: re-skin of existing Phase 2 code (or net-new where applicable).
2. **Locked operator directives** — numbered, non-negotiable decisions from operator chat. Dated.
3. **Locked constraints** — every token, every CSS value, the headless render command. Cite the
   source doc and the specific line/section for each constraint.
4. **The spec** — exact data fields per element (source field → treatment table, like C2 §4.1);
   composition rules; accessibility requirements (WCAG §5 from `rules/coding.md`); contract field
   names if new fields are added.
5. **Granular task list** — every task with: **Owner** (agent type) · **Dep** (prerequisite task) ·
   **Files** (exact paths to create/modify) · **Do** (what to do) · **Accept** (pass/fail definition
   of done) · **QC** (a *different* party verifies — never owner self-attest). Grouped into phases:
   - PHASE 0 — Mockup (design gate; blocks ALL code)
   - PHASE 1 — Doc corrections (if any ADR amendments or token-doc fixes needed)
   - PHASE 2 — Implementation (parallel per-repo where field names are fixed; each task lists
     files to create, modify, and NOT touch)
   - PHASE 3 — Audit (independent re-run of test suites + ADR/rules/a11y conformance)
   - PHASE 4 — Deploy + live verify (on operator "push" word only)
6. **Dependency graph** — ASCII showing what blocks what, which tasks parallelize.
7. **QC ownership** — who verifies what (coordinator = render-and-LOOK + diff review + push;
   auditor = independent suite re-runs + conformance; operator = mockup approval + ADR approval + push auth).
8. **Verification bar** — end-to-end "done" definition: pytest output, tsc/build, axe-core, render-and-LOOK
   evidence (headless screenshots of BOTH mockup and built card, Read each PNG), live endpoint evidence.
9. **Implementation reference** — verified **file:line** for every piece of code agents will touch or
   need to understand, so they don't waste time re-discovering the codebase. Include: existing component
   locations, data hooks, TS types, CSS tokens, registration points, test patterns.
10. **Out of scope** — what NOT to do (explicit exclusions).

### Universal document reading list (MUST appear in every brief's §3)

Every brief's "Locked constraints" section must include these paths explicitly. Agents read them
**in this order** before writing any code or mockup.

**TIER 1 — Locking ADRs / token specs:**
- [docs/design/design-tokens-typography.md](../design/design-tokens-typography.md) — LOCKED font families, sizes, weights
- [docs/decisions/ADR-048-theme-color-tokens.md](../decisions/ADR-048-theme-color-tokens.md) — theme colors, accent palette, chart palette
- [docs/decisions/ADR-049-hero-weather-icons.md](../decisions/ADR-049-hero-weather-icons.md) — hero weather icon system (Material Symbols gradient SVG)
- [docs/decisions/ADR-050-utility-stat-nav-icons.md](../decisions/ADR-050-utility-stat-nav-icons.md) — Phosphor base + curated cross-pack; deferred sub-families
- [docs/decisions/ADR-051-card-footprint-model.md](../decisions/ADR-051-card-footprint-model.md) — footprints, min-footprints, half-row packing, universal card discipline, glass surface
- [docs/decisions/ADR-047-background-system.md](../decisions/ADR-047-background-system.md) — background system (cards sit over it)

**TIER 2 — Process & coding rules:**
- [rules/clearskies-process.md](../../rules/clearskies-process.md) — ADR lifecycle, scope binding, brief quality
- [rules/coding.md](../../rules/coding.md) — security, accessibility §5 (WCAG 2.1 AA, load-bearing), "Render and LOOK" mandate

**TIER 3 — Design references:**
- [docs/design/C0-PAGE-INVENTORY.md](../design/C0-PAGE-INVENTORY.md) — authoritative card inventory per page
- [docs/design/inspiration/NOTES.md](../design/inspiration/NOTES.md) + specific `docs/design/inspiration/raw/img-NN.*` **opened AS IMAGES**
- [docs/design/mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) — locked footprints (col-span × row-span), lines 458–598
- [docs/design/mockups/A4-page-anatomy.html](../design/mockups/A4-page-anatomy.html) — page structure, half-row track, controls strip, grid CSS to copy

**TIER 4 — Data contracts:**
- [docs/contracts/openapi-v1.yaml](../contracts/openapi-v1.yaml) — wire format authority
- [docs/contracts/canonical-data-model.md](../contracts/canonical-data-model.md) — entity catalog, field types, provider mappings
- `repos/weewx-clearskies-dashboard/src/api/types.ts` — TypeScript type definitions
- `repos/weewx-clearskies-dashboard/src/hooks/useWeatherData.ts` — data hooks

**TIER 5 — Reference implementations (how a finished card looks):**
- `repos/weewx-clearskies-dashboard/src/components/WindCompassCard.tsx` — C2 pattern (Card structure, Phosphor icon in header, Outfit numerals, tabular-nums, aria-live, ConvertedValue handling)
- `repos/weewx-clearskies-dashboard/src/components/forecast/NowForecastCard.tsx` — C3 pattern (tabbed card, footprint prop, CardTitle `as="h2"`)
- `repos/weewx-clearskies-dashboard/src/routes/now.tsx` — current Now page wiring (where cards are imported + rendered)

Each brief adds **per-component additions** to this list: the specific existing card files being
re-skinned, relevant page-specific ADRs, and the exact inspiration images for that card.

### QC gates (5 gates, every brief, no exceptions)

| Gate | What | Who |
|---|---|---|
| **1. Mockup approval** | Lead renders headless PNG, inspects visually: card within locked footprint, typography matches tokens, glass surface visible, both themes render correctly | Lead (coordinator) + operator sign-off |
| **2. Type-check + build** | `npx tsc --noEmit` → 0 errors; `npx vite build` → clean build | Code agent self-check, lead verifies |
| **3. Visual verification** | Live dev server, both light and dark themes, responsive 4→2→1 col collapse | Lead on weather-dev |
| **4. Accessibility audit** | `@axe-core` 0 new violations, keyboard Tab walkthrough (all interactive elements reachable), screen reader spot-check, ≥3:1 icon contrast both themes | Lead or auditor |
| **5. Prompt faithfulness** | Walk the original request; every surface delivered; every filed listed in scope-in is accounted for | Lead |

### Headless render command (Windows — used in mockup phase)
```
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu `
  --screenshot="C:\tmp\render.png" --window-size=1400,900 "file:///<absolute-path-to.html>"
```
Then Read `C:\tmp\render.png` and **LOOK** — reading markup or an `axe` pass is NOT visual verification.

### Mockups (artifact format)
Self-contained **HTML mockups** saved to `docs/design/mockups/`, openable in a browser, durable on disk.
**Track A is complete** — all mockups are high-fidelity: real Tailwind styling, real @fontsource
woff2 fonts from `docs/design/mockups/fonts/`, real glass surface tokens, real A4 grid CSS copied
from `A4-page-anatomy.html`. The card sits at its **locked footprint** inside the real grid —
NEVER rendered standalone, full-width, or at free pixel heights. Mockups are throwaway exploration
artifacts, NOT the React implementation.

## Next action
**Track A foundations (A0–A4) are CODE-COMPLETE and deployed to weather-dev (2026-05-31).** Design ✅ +
code ✅ for every foundation item:
- **A0** (ADR reconciliation gate) — DONE 2026-05-29 (reconciled, re-approved, deployed).
- **A1** (theme & color tokens) — [ADR-048](../decisions/ADR-048-theme-color-tokens.md), as-built verified
  (no code change).
- **A2** (background system) — [ADR-047](../decisions/ADR-047-background-system.md); realtime `c2d7f57` +
  dashboard `4e8c896`/`846fc6c`; live `/current` emits `scene`.
- **A3** (icon system) — [ADR-049](../decisions/ADR-049-hero-weather-icons.md) hero `0140e2f` +
  [ADR-050](../decisions/ADR-050-utility-stat-nav-icons.md) utility/alert `8143377`/`90ed053`.
- **A4** (card model & grid-compatible sizing) — [ADR-051](../decisions/ADR-051-card-footprint-model.md);
  dashboard `1e6c7db`/`d632bba`/`3fd072a`/`cbdb24d`/`82e67e6` (primitives only; page application = Track C).

Build session record + per-deliverable verification evidence: execution briefs in
[briefs/](briefs/); scratchpad `c:\tmp\track-a-impl-scratch.md`.

**The single open Track-A/B item is on-device TESTING** (the kickoff "definition of done" visual bar — needs
a browser): visual check vs. mockups in both themes, `@axe-core/playwright` on the hydrated SPA,
keyboard-only walkthrough, and color-blindness pass. Ready-to-paste prompt:
**[briefs/TRACK-A-TESTING-CONTINUATION.md](briefs/TRACK-A-TESTING-CONTINUATION.md)**.
B2 and B3 are closed (see Track B above). On-device Track-A testing remains open but does **not** block C1.

**C0 is done** — page inventory at [docs/design/C0-PAGE-INVENTORY.md](../design/C0-PAGE-INVENTORY.md)
(built 2026-05-29 during A0; 11 routes, ~40 candidate cards, authoritative C1–C14 work list). No
ratification step.

**C1 and C2 are code-complete** (2026-05-31) — see Track C above for commits and verification. Pending
push + deploy to weather-dev + live verification.

**C3 is code-complete** (2026-06-01) — see Track C above for commits and verification. Pending
push + deploy to weather-dev + live verification (Gate 3 visual + Gate 4 a11y).

**C4 — Now-page stat tiles: CODE-COMPLETE (2026-06-01).** Execution brief at
[briefs/C4-STAT-TILES-PLAN.md](briefs/C4-STAT-TILES-PLAN.md). Phase 0 mockup approved, Phase 1 doc
corrections done, Phase 2 implementation done (BFF lightning strike buffer 497 tests pass; contract
updated; 8 dashboard tile components created + wired into now.tsx; tsc 0 errors; vite build clean;
19 i18n keys added). Pending push + deploy + live verification (batched with C1–C6).

**C5 — Alert banner + Today's Highlights: CODE-COMPLETE (2026-06-02).** See Track C above for
commits. Alert banner redesigned (ADR-052 severity-aware, expandable, multi-alert); highlights
extracted to standalone component. Pending push + deploy.

**C6 — Radar + Webcam revamp: CODE-COMPLETE (2026-06-02).** Radar footprint fixed to always 2×2;
RainViewer color legend added; webcam extracted to standalone component. See Track C above. Pending
push + deploy.

**→ NOW PAGE IS COMPLETE (C1–C6 all code-complete + post-code-complete polish pass).** Ready for
batched push + deploy + verification.

**Post-code-complete refinement pass (2026-06-02).** After declaring C1–C6 code-complete, a live
visual review session produced ~80 additional dashboard commits covering: C3 forecast card visual
fixes (16 commits), C4 stat tile fixes (50+ commits including precipitation card redesign to
"Precipitation & Humidity", gauge geometry, Solar/UV chart axis overhaul, Sun & Moon arc tuning),
nav rail overhaul (auto-hide with grab bar), dark mode polish (opacity + basemap + theme sync),
and cross-cutting visual polish. Details recorded in the C3, C4, and C6 sections above. New
documentation created: `rules/coding.md` §6 (Recharts discipline) + §7 (build verification),
`reference/clearskies-dev.md` (browser testing URL), `docs/reference/recharts-axis-reference.md`,
and 3 execution briefs in `docs/planning/briefs/`.

**Remaining Track C work (see roadmap above for full detail):**
- **C7** Almanac page (7 re-skins + sun/moon arcs net-new)
- **C8** Seismic page (re-skin + map legend + ADR-046 reconciliation)
- **C9** Records page (structural reconciliation + re-skin — **blocked on operator decision**)
- **C10** Reports, About, Legal pages (grid migration batch)

**BATCHED DEPLOY + LIVE VERIFICATION (all repos, one pass — NOW PAGE COMPLETE).**
C1–C6 are all code-complete but unpushed (including the 2026-06-02 polish pass). All Now-page
work will be pushed + deployed + tested in one pass. The verification pass covers:
- Push all local commits across all 3 repos (realtime, dashboard, meta contracts)
- Deploy to weather-dev (all services)
- Gate 3: visual verification both themes + responsive (4→2→1 col) on every Now-page card
- Gate 4: axe-core on `/` and `/forecast`, keyboard Tab walkthrough, screen reader spot-check
- Gate 5: live data verification — BFF `/current` carries `lightningStrikeHistory`, all 8 stat
  tiles render with real data, Solar/UV charts show today's archive, gauges show real pressure/AQI,
  Sun & Moon arcs show correct station-TZ times, precipitation card shows dewpoint + humidity
- Color-blindness simulation pass (protanopia, deuteranopia, tritanopia, achromatopsia)
