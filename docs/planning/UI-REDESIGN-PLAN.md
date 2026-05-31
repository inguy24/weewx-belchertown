# UI-REDESIGN-PLAN — Clear Skies dashboard UI redesign (the "plan for the plan")

**Status:** Active. This is a roadmap/index, not a decision record — decisions live in ADRs.
**Track A foundations (A0–A4) are CODE-COMPLETE and deployed to weather-dev (2026-05-31)** — on-device
visual/a11y/keyboard testing is the only open Track-A item (see Next action). Tracks B2/B3 + C downstream.

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
- **A3. Icon system** — two families, **BOTH CODE-COMPLETE + deployed (2026-05-31).** **HERO family** → **[ADR-049](../decisions/ADR-049-hero-weather-icons.md)
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
- **B2. Recharts background-image support** (global) — can Recharts render a scenic image behind the plot area? Gates C1 temp-curve styling.
- **B3. Accessibility-contrast + image-performance budget** (global) — text-contrast floors over photos; image
  weight/loading budget. Gates A2 and all photo-backed components. → research note / ADR.

### Track C — Components, ALL pages (depend on A + B)
**Scope = every page, not just the "now"/home page** — forecast page, almanac, radar, earthquakes, alerts,
records, etc. each have cards. Track C opens with a page inventory, then walks components page by page.

**Per-component workflow (each component is a self-contained mini-cycle):**
0. **Prior-decision check** — surface any existing decision for this surface (ADRs, current site, Phase-2 work);
   re-affirm or consciously depart (don't silently redo).
1. **Data inventory (B1 slice)** — "here is everything the providers / weewx give us for this card."
2. **Composition** — what's grouped on one card vs. split into separate cards.
3. **Mockup** — quick artifact mockup(s) to react to (see Mockups below).
4. **ADR** — lock composition + what's shown + treatment → Proposed → Accepted.
5. **Execution plan → code.**

- **C0. Page inventory** — enumerate every page/screen and the cards each holds (now/home, forecast, almanac,
  radar, earthquakes, alerts, records, …). Establishes the full Track C work list. → research note.
- **C1. Current-conditions card** + **today's temperature curve** along the bottom (model: img-23) +
  **restore the Now-page hero** (page-header card = station logo + station name; per ADR-051, dropped & never
  redesigned; ties to ADR-022 branding / ADR-049 logo alt). → ADR + exec plan.
- **C2. ⭐ Wind compass** (loved; signature; info-inside-the-dial). → ADR + exec plan.
- **C3. Forecast screen** — icon-rich columns + time-range tabs + (B1-permitting) expandable columns. → ADR + exec plan.
- **C4. Per-metric stat treatment + detail grid** — the text/dial/gauge/curve table; uniform tiles; per-stat icons;
  plain-language context line. → ADR + exec plan.
- **C5. Sun & Moon arcs** (moon gets its own arch) + moon phase → almanac/front page. → ADR + exec plan.
- **C6. AQI card** (B1-permitting; per-pollutant breakdown) + **radar legend/key**. → ADR + exec plan.

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

## Execution-plan template (Layer 3 — per decision point)
Each Accepted ADR gets one of these in `docs/planning/briefs/` before any agent is dispatched. Required sections
(per `rules/clearskies-process.md` "Agent prompt requirements" + "Scope binding"):
1. **ADR reference** — which ADR(s) this implements. (Reference, do not restate decisions.)
2. **Scope in / out** — exhaustive file list to create/modify; explicit "do NOT touch" exclusions.
3. **Per-deliverable spec** — each component/endpoint's behavior, states, responsive behavior, edge cases.
4. **QC gates** — the ADR's acceptance criteria turned into pass/fail checks (tests, axe-core a11y, visual states).
5. **Definition of done** — what the lead will see in git log; pass thresholds; verification command.
6. **Agent constraints** — git restrictions block (no pull/push/fetch/rebase/merge); scope-ack required before code.

---

## Mockups (artifact format)
Quick, self-contained **HTML mockups** saved to `docs/design/mockups/`, openable in a browser, durable on disk
(same principle as the inspiration board — not floating in chat). Fidelity rises in step with Track A:
- **Low-fidelity first** — grayscale layout/composition wireframe (boxes + labels) to settle "what's on the card."
  Foundation-independent, so it can start before Track A is done.
- **Higher-fidelity later** — real Tailwind styling, colors, icons, background — once theme/background/icon
  foundations (Track A) are decided to style against.
Mockups are throwaway exploration artifacts, NOT the React implementation.

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

**The single open Track-A item is on-device TESTING** (the kickoff "definition of done" visual bar — needs
a browser): visual check vs. mockups in both themes, `@axe-core/playwright` on the hydrated SPA,
keyboard-only walkthrough, color-blindness pass, and the **B3 card-glass contrast measurement** (sets the
final `--card-glass` opacity; provisional values shipped). Ready-to-paste prompt:
**[briefs/TRACK-A-TESTING-CONTINUATION.md](briefs/TRACK-A-TESTING-CONTINUATION.md)**.
- **B2 + B3 global research gates** — Recharts background support + a11y-contrast/perf budget (B3 also sets
  the final card-glass opacity for ADR-051). Can run in parallel; **B2/B3 + on-device testing are the open
  Track-A/B items** before Track C.

Then walk Track C component by component (C1…C6, plus any additional cards from the full C0 work list) using the per-component workflow
(prior-decision check → data inventory → composition → mockup → ADR → exec plan). Per-component data
inventory (B1) happens just-in-time inside each.
