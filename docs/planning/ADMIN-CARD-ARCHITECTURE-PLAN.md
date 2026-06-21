# Admin Page & Card Plugin Architecture — Execution Plan

**Status:** APPROVED
**Created:** 2026-06-21
**Components:** Dashboard SPA (`weewx-clearskies-dashboard`), Config UI (`weewx-clearskies-stack`), API (`weewx-clearskies-api`)

---

## Context

The setup wizard is complete. The next step is an admin page — the standard interface operators visit after initial setup. While operators can re-run the wizard, the admin page provides non-sequential access to all configuration areas, plus two capabilities the wizard does not have: page visibility management (show/hide dashboard pages) and a Now page card layout editor (drag-and-drop card arrangement).

The card layout editor requires a deeper architectural change: cards must become self-contained, independently distributable plugin components. Each card carries its own metadata, API endpoint declarations, allowed layout configurations, and thumbnail image. The Now page becomes a container that dynamically renders cards based on an operator-configured layout. This architecture is designed so that a future v2 can add third-party card import/deletion without rewriting existing cards — our 14 built-in cards will already conform to the plugin contract.

**Architecture violation to fix:** Page hiding currently lives in the API (`api.conf [pages] hidden`, `wire_hidden_pages()`, `/pages` endpoint filtering). The API is the data layer between weewx/providers/dashboard — it is not a UI control plane. Page visibility is a presentation concern that belongs in the static config layer.

**v2 deferred scope (architecture-ready, not implemented):** Third-party card import via admin UI, card deletion, Card Manual documentation. Cards will be stored inside the dashboard web root at `/var/www/clearskies/cards/` (excluded from redeploy rsync). The plugin contract built in this plan ensures no rewrite is needed when v2 adds the import mechanism.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — §5 WCAG accessibility, §6 Recharts, §7 build verification
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-dashboard` — React 19 SPA (Vite + Tailwind + shadcn/ui). Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).
- `weewx-clearskies-stack` — Config UI (FastAPI + Jinja2 + HTMX + Pico CSS). No build step. Branch: `main`.
- `weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`. Lint: `ruff check`, `mypy`.

**Deploy (from any machine with replicated project files):**
- Dashboard: `bash scripts/redeploy-weather-dev.sh` (pulls, builds, publishes to web root)
- Config UI: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (~2 min warm cache)

**Key governing manuals (agents read these before implementing):**
- `docs/ARCHITECTURE.md` — system topology, static config files, Caddy routing, service boundaries
- `docs/DASHBOARD-MANUAL.md` — pages, routes, data refresh, card behavior, component contracts
- `docs/DESIGN-MANUAL.md` — card anatomy, grid system, tokens, visual patterns, thumbnails
- `docs/OPERATIONS-MANUAL.md` — config files, admin UI, deployment, operator workflows
- `docs/API-MANUAL.md` — published endpoints (the contract card authors reference)

ADRs referenced for historical context (decisions are consolidated into manuals):
- ADR-022 — Theming/branding (archived into DESIGN-MANUAL + ARCHITECTURE)
- ADR-024 — Page taxonomy (archived into DASHBOARD-MANUAL + ARCHITECTURE)
- ADR-027 — Config wizard (archived into OPERATIONS-MANUAL + ARCHITECTURE)
- ADR-051 — Grid primitive and footprint vocabulary (archived into DESIGN-MANUAL)

**New ADRs required by this plan (Phase 0A):**
- ADR-064 — Card plugin contract (new decision: cards as self-contained plugins with metadata, endpoint declarations, allowed layouts, thumbnails, DataBag self-extraction)
- ADR-065 — Now page layout configuration (new decision: configurable card composition via now-layout.json, Now page as container)
- Amendment to ADR-024 — Page visibility moves from API to static config (pages.json served by Caddy)
- Amendment to ADR-027 — Admin landing page at `/admin` with domain-organized sections

**Manual update sequencing:** ADRs are written and accepted first. Then prescriptive rules are extracted into the governing manuals. Then coding begins. Agents implement from the manuals, not from the ADRs or the plan.

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**Roles:**
- **Coordinator (Opus):** Owns Phase 0A (ADRs + manuals), QC after every phase, Phase 6 (deploy + verify). The coordinator reads all governing docs and the full codebase context personally — QC is never delegated to a sub-agent. The coordinator writes the prompts for implementation agents based on its own research of the manuals and current code state.
- **QA Auditor (`clearskies-auditor`):** Independent oversight of the coordinator's QC. After each phase, the auditor reviews the coordinator's QC evidence against the plan's acceptance criteria and QC gates. The auditor flags any QC gap the coordinator missed. The auditor does NOT implement — it only reviews. The auditor's findings must be resolved before the next phase advances.
- **Implementation agents (Sonnet):** `clearskies-dashboard-dev`, `clearskies-stack-dev`, `clearskies-api-dev`. Execute tasks per the coordinator's prompts. Read governing manuals before implementing. Report results to coordinator.

---

## 1. Gap Inventory

### A. Admin Landing Page

| # | Item | Status | Gap |
|---|------|--------|-----|
| A1 | `/admin` route handler | MISSING | Only `/admin/config` exists. Bare `/admin` returns 404. |
| A2 | Admin landing page template | MISSING | `templates/config/dashboard.html` is the config section list, not a proper landing page. |
| A3 | Non-sequential access to all wizard areas | PARTIAL | Existing admin covers: server, database, 5 providers, UI settings, webcam, column mapping. Missing: branding, social, analytics, privacy, TLS, feature settings, EULA. |
| A4 | Branding/social/analytics editing in admin | MISSING | These write to `branding.json` but no admin section exists for them. |
| A5 | Redirect to wizard if not yet set up | PARTIAL | `app.py` line 148 checks for `api.conf` and redirects to wizard, but only from root `/`, not from `/admin`. |

### B. Page Visibility

| # | Item | Status | Gap |
|---|------|--------|-----|
| B1 | Page hiding in API | EXISTS (violation) | `settings.py` `PagesSettings.hidden`, `pages.py` `wire_hidden_pages()`, `__main__.py` line 785. Must be removed. |
| B2 | Page visibility static config | MISSING | No `pages.json` or equivalent in `/etc/weewx-clearskies/`. |
| B3 | Dashboard reads visibility from static config | MISSING | `nav-rail.tsx` hardcodes 9 `NAV_ITEMS`. `App.tsx` hardcodes all routes. |
| B4 | Admin UI for page visibility | MISSING | No checkbox interface. |
| B5 | Branded 404 page | MISSING | `not-found.tsx` is generic. Needs operator logo + weather pun. |

### C. Card Plugin Architecture

| # | Item | Status | Gap |
|---|------|--------|-----|
| C1 | Card metadata (type, name, endpoints, layouts, thumbnail) | MISSING | No card metadata. Cards are bare React components imported in `now.tsx`. |
| C2 | Card self-extraction (each card extracts its own data from a data bag) | MISSING | Cards receive specific props from page-level code. Data mapping logic is in `now.tsx`, not in the cards. |
| C3 | Allowed layout configurations per card | MISSING | Each card has one hardcoded footprint/rowSpan. No multi-layout support. |
| C4 | Card registry (metadata + components combined) | MISSING | No registry. Direct imports in `now.tsx`. |
| C5 | Build-time card manifest (metadata-only JSON for admin) | MISSING | No manifest. |
| C6 | Dynamic Now page rendering from layout config | MISSING | Card composition is hardcoded JSX. |
| C7 | `now-layout.json` config file | MISSING | No layout config. |
| C8 | Card thumbnails for admin editor | MISSING | No preview images. |

### D. Card Layout Editor (Admin)

| # | Item | Status | Gap |
|---|------|--------|-----|
| D1 | Sortable.js drag-and-drop | MISSING | No JS library in the stack repo. |
| D2 | Card palette + active grid editor | MISSING | No layout editor UI. |
| D3 | Layout save endpoint | MISSING | No route to write `now-layout.json`. |

### E. Out of Scope (v2 — Plugin Import System)

| Feature | Why Deferred | Architecture Readiness |
|---------|-------------|----------------------|
| Card import via admin UI | Significant scope; admin + layout editor are already substantial | Card contract and metadata format will be in place. Built-in cards already conform. Adding import = upload + validate + write to web root. |
| Card deletion via admin UI | Depends on import system | Cards directory and manifest are in place. Deletion = remove file + remove from manifest. |
| Card Manual documentation | Depends on card contract being stable | Contract is defined in this plan. Manual documents it. |
| Third-party card distribution | Depends on import system | Card artifact format is defined. Distribution is just sharing the file. |

---

## 2. Design Decisions

### Card Plugin Contract

A card is a self-contained module that exports:

- **`type`** — unique string ID (e.g., `"aqi"`, `"wind-compass"`)
- **`displayName`** — human-readable name for the admin editor
- **`apiEndpoints`** — array of API endpoint paths the card needs (e.g., `["/api/v1/observation/current", "/api/v1/almanac"]`). Card authors determine this by reading the published OpenAPI spec. The container deduplicates across all active cards and fetches each endpoint once.
- **`allowedLayouts`** — array of `{ footprint, rowSpan }` configurations the card supports. The card may render differently for each. The operator selects from this list in the layout editor. Example: `[{ footprint: "tile", rowSpan: 1 }, { footprint: "wide", rowSpan: 1 }]`
- **`thumbnail`** — static preview image path for the admin editor
- **`component`** — the React component. Receives a data bag (keyed by endpoint path) and its current layout configuration. The card extracts the specific fields it needs internally.

Built-in cards (our 14) conform to this contract from day one. When v2 adds third-party card import, imported cards use the same contract — no rewrite needed.

### Card Metadata Separation

Card metadata (type, name, endpoints, layouts, thumbnail path) lives in a plain data file (`card-metadata.ts`) with no React imports. The card registry (`card-registry.ts`) combines metadata with component references. A build-time script reads only the metadata file and writes `card-manifest.json` — the JSON artifact that the admin editor reads to populate the Sortable.js palette. This separation means the admin (Python/HTMX) never needs React.

### Self-Extracting Cards

Each card component receives a `DataBag` (a map from API endpoint path to response data) and its `ActiveLayout` (footprint + rowSpan). The card internally extracts the fields it needs. This moves data mapping logic into the card (where it belongs as a plugin) and out of the Now page container.

### Now Page as Container

The Now page:
1. Reads `now-layout.json` (falls back to default layout if absent)
2. Looks up each card in the registry
3. Collects all `apiEndpoints` from active cards, deduplicates
4. Fetches each unique endpoint once, builds the `DataBag`
5. Renders cards in layout order, passing each its slice of the data bag + active layout
6. NowHeroCard is a layout element, not a card — it renders outside the grid unconditionally

### Page Visibility — Static Config

Page visibility moves from `api.conf` to `/etc/weewx-clearskies/pages.json`, served by Caddy as a static file. Dashboard reads it at boot. Format: `{ "hidden": ["seismic", "reports"] }`. "Now" cannot be hidden (enforced by admin UI and dashboard).

### Custom Cards Storage (v2 Architecture Prep)

Custom cards (v2) will be stored inside the dashboard web root at `/var/www/clearskies/cards/`. The redeploy script will exclude this directory from rsync (same pattern as `webcam/`). Built-in cards ship in the bundle; custom cards are loaded dynamically from the cards directory. The card registry merges both sources at runtime. This plan prepares for this by using a registry that supports dynamic registration, even though v2 adds the actual import mechanism.

---

## 3. Implementation Phases

### PHASE 0A — ADRs + Manual Updates (Documentation First)

**Why first:** Agents read the governing manuals before implementing. The card plugin architecture, layout configuration, page visibility move, and admin landing page are all new architectural decisions. If the manuals don't describe these before coding starts, agents have no authoritative guidance. ADRs document the decisions; manuals become the implementation rules.

**T0A.1 — Draft ADR-064: Card Plugin Contract**
- Owner: Coordinator (Opus)
- File: New `docs/decisions/ADR-064-card-plugin-contract.md`
- Decision: Cards are self-contained plugin components. Each card exports: type (unique ID), displayName, apiEndpoints (array of API endpoint paths the card needs — authors read the published OpenAPI spec), allowedLayouts (array of footprint/rowSpan configurations the card supports, potentially with different rendering per layout), thumbnail (static preview image), and component (the React component). The component receives a DataBag (keyed by endpoint path) and its active layout — it extracts its own data internally. The Now page is a container that reads a layout config, deduplicates endpoint calls across active cards, and renders cards in order. Built-in cards ship in the bundle; v2 will add third-party card import into the web root's `cards/` directory (excluded from redeploy rsync).
- Status: Proposed → user reviews → Accepted

**T0A.2 — Draft ADR-065: Now Page Layout Configuration**
- Owner: Coordinator (Opus)
- File: New `docs/decisions/ADR-065-now-page-layout-configuration.md`
- Decision: The Now page card composition is configurable via `/etc/weewx-clearskies/now-layout.json`, served by Caddy as a static file. Format: `{ version: 1, cards: [{ type, footprint, rowSpan }] }`. Card order in the array determines rendering order; CSS Grid auto-placement fills the 4-column grid. Cards not in the list don't render. Dashboard falls back to a built-in default layout (matching the current hardcoded arrangement) when the file is absent. The admin provides a drag-and-drop editor (Sortable.js) to manage this layout. The NowHeroCard is a layout element, not a configurable card.
- Status: Proposed → user reviews → Accepted

**T0A.3 — Amend ADR-024: Page Visibility Moves to Static Config**
- Owner: Coordinator (Opus)
- File: `docs/archive/decisions/ADR-024-page-taxonomy.md` (amendment section)
- Amendment: Page visibility configuration moves from `api.conf [pages] hidden` (API responsibility) to `/etc/weewx-clearskies/pages.json` (static file served by Caddy). The API is the data layer — it does not control which UI pages are visible. Dashboard reads `/pages.json` at boot and filters navigation + routes. Format: `{ "hidden": ["seismic", "reports"] }`. "Now" cannot be hidden (enforced by admin UI and dashboard). The API's `/pages` endpoint returns all 9 built-in pages unconditionally — filtering is the dashboard's responsibility.
- Status: Accepted (amendment to existing Accepted ADR)

**T0A.4 — Amend ADR-027: Admin Landing Page**
- Owner: Coordinator (Opus)
- File: `docs/archive/decisions/ADR-027-config-and-setup-wizard.md` (amendment section)
- Amendment: The Config UI adds an admin landing page at `/admin`. If setup has not been run (no `api.conf`), `/admin` redirects to the wizard. After setup, `/admin` is the default post-login destination. The landing page organizes all configuration areas by domain (Station Identity, Database, Providers, Appearance, Analytics & Privacy, Webcam, Pages, Now Page Layout, Column Mapping, TLS) — not by config file. Each section shows current values with inline edit links. The existing `/admin/config` section-level CRUD is preserved and expanded with branding, social, analytics, privacy, feature settings, and TLS sections.
- Status: Accepted (amendment to existing Accepted ADR)

**T0A.5 — Update governing manuals**
- Owner: Coordinator (Opus)
- Files: `docs/ARCHITECTURE.md`, `docs/DASHBOARD-MANUAL.md`, `docs/DESIGN-MANUAL.md`, `docs/OPERATIONS-MANUAL.md`
- Do: Extract prescriptive rules from ADR-064, ADR-065, ADR-024 amendment, and ADR-027 amendment into the governing manuals. Specifically:
  - **ARCHITECTURE.md**: Add `pages.json` and `now-layout.json` to static config file inventory. Add Caddy routes. Add `cards/` directory convention. Add `/admin` route to Caddy routing table. Remove page hiding from API responsibility section.
  - **DASHBOARD-MANUAL.md**: Add card plugin contract section (CardMetadata, CardComponentProps, DataBag, self-extraction pattern). Add dynamic Now page rendering rules. Add page visibility filtering rules (nav + routes). Add custom 404 behavior. Add `allowedLayouts` multi-configuration rules.
  - **DESIGN-MANUAL.md**: Add card thumbnail requirements (dimensions, format, path convention). Add card plugin visual contract (how cards render at different allowed layouts). Update card anatomy section with DataBag pattern.
  - **OPERATIONS-MANUAL.md**: Add admin landing page documentation. Add page visibility management. Add card layout editor usage. Add new config files (`pages.json`, `now-layout.json`) to config file inventory.
- Accept: All four manuals updated. An agent reading only the manuals (not the ADRs or this plan) has complete, actionable guidance for every implementation task in Phases 0B–6.

**QC (Opus) — after Phase 0A:** Verify all four ADRs/amendments are written and accepted. Verify each manual contains the prescriptive rules extracted from the ADRs. Verify no conflicting information between manuals. Verify an agent reading DASHBOARD-MANUAL.md can implement the card plugin contract without referencing ADR-064 directly.

**QA Audit (clearskies-auditor) — after Phase 0A QC:** Independently verify that (a) each ADR's prescriptive content appears in the correct manual, (b) no manual-to-manual contradictions exist, (c) the ARCHITECTURE.md static file inventory and Caddy routing table are complete, (d) the coordinator did not skip any manual listed in T0A.5. Report findings to user. Phase 0B does not begin until auditor clears.

### PHASE 0B — Card Plugin Architecture (Dashboard)

**Why next:** The card registry is a prerequisite for both the dynamic Now page (Phase 1) and the admin layout editor (Phase 4). Cards must be self-describing before either can work. Agents implement from the updated DASHBOARD-MANUAL.md and DESIGN-MANUAL.md.

**T0B.1 — Define card metadata and registry**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `src/lib/card-metadata.ts`, new `src/lib/card-registry.ts`
- `card-metadata.ts` (no React imports):
  - `CardType` — string literal union for all 14 built-in card types
  - `CardLayout` — `{ footprint: CardFootprint; rowSpan: 1 | 2 | 2.5 }`
  - `CardMetadata` — `{ type: CardType; displayName: string; apiEndpoints: string[]; allowedLayouts: CardLayout[]; thumbnail: string }`
  - `CARD_METADATA: Record<CardType, CardMetadata>` — all 14 cards with their endpoint declarations and single allowed layout each (matching current hardcoded sizes)
  - Endpoint declarations derived from current `now.tsx` data hooks:
    - `current-conditions`: `["/api/v1/observation/current", "/api/v1/forecast", "/api/v1/almanac"]`
    - `now-forecast`: `["/api/v1/forecast"]`
    - `wind-compass`: `["/api/v1/observation/current"]`
    - `todays-highlights`: `["/api/v1/observation/current"]`
    - `precipitation`: `["/api/v1/observation/current"]`
    - `barometer`: `["/api/v1/observation/current"]`
    - `solar-radiation`: `["/api/v1/observation/current"]`
    - `uv-index`: `["/api/v1/observation/current", "/api/v1/forecast", "/api/v1/almanac"]`
    - `aqi`: `["/api/v1/aqi"]`
    - `sun-moon`: `["/api/v1/almanac"]`
    - `lightning`: `["/api/v1/observation/current"]`
    - `earthquake`: `["/api/v1/earthquakes"]`
    - `radar`: `["/api/v1/station"]`
    - `webcam`: (no API endpoint — reads `/webcam.json` static file)
  - Export `getEndpointsForCards(types: CardType[]): string[]` — deduplicates across all requested cards
- `card-registry.ts` (has React imports):
  - `CardRegistration` — extends `CardMetadata` with `component: React.ComponentType<CardComponentProps>`
  - `CardComponentProps` — `{ dataBag: DataBag; layout: CardLayout; stationTz: string }`
  - `DataBag` — `Record<string, any>` keyed by API endpoint path
  - `CARD_REGISTRY: Map<CardType, CardRegistration>` — combines metadata with lazy component imports
  - Export `getCard()`, `getAllCards()`, `getBuiltinCards()`
- Accept: All 14 cards registered. `getEndpointsForCards(["aqi", "radar"])` returns `["/api/v1/aqi", "/api/v1/station"]` (deduplicated). Types compile with `tsc --noEmit`.

**T0B.2 — Refactor card components to self-extract from DataBag**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: All 14 card components in `src/components/`
- Do: Each card component's props interface changes from specific props (e.g., `observation`, `loading`, `error`, `onRetry`) to `CardComponentProps` (`dataBag`, `layout`, `stationTz`). Each card internally extracts the data it needs from the data bag using its declared endpoint paths. Each card handles its own loading/error states based on whether its required data is present in the bag.
- Important: This is the largest refactor in the plan. Each card must produce identical rendering output after the refactor. The extraction logic is straightforward — it's moving existing prop-reading code into the component and changing the prop source from named props to data bag lookup.
- Accept: Each card renders identically to before when given the same data. No visual regression. `tsc --noEmit` passes. `vite build` clean.

**T0B.3 — Define layout config type and default layout**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `src/lib/now-layout.ts`
- Do:
  - `NowLayoutEntry` — `{ type: CardType; footprint: CardFootprint; rowSpan: 1 | 2 | 2.5 }`
  - `NowLayoutConfig` — `{ version: 1; cards: NowLayoutEntry[] }`
  - `DEFAULT_NOW_LAYOUT` — mirrors current `now.tsx` card order (14 cards, exact current sizes)
  - `fetchNowLayout(): Promise<NowLayoutConfig>` — fetches `/now-layout.json`, falls back to `DEFAULT_NOW_LAYOUT` on 404 or parse error
- Accept: `DEFAULT_NOW_LAYOUT.cards.length === 14`. Order matches current `now.tsx`. Types compile.

**T0B.4 — Generate card manifest at build time**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `scripts/generate-card-manifest.ts`, modify `package.json`
- Do: Script imports only from `card-metadata.ts` (no React). Writes `public/card-manifest.json` with all card metadata (type, displayName, apiEndpoints, allowedLayouts, thumbnail path). Add `"prebuild"` script to `package.json`.
- Accept: `npm run build` produces `dist/card-manifest.json`. JSON is valid, contains all 14 cards.

**QC (Opus) — after Phase 0B:** Verify `tsc --noEmit` and `vite build` pass. Verify all 14 cards render identically to before (visual comparison on weather-dev). Verify card-manifest.json is present and correct. Verify endpoint deduplication logic. Verify each card's data bag extraction produces the same output as the previous prop-based rendering.

**QA Audit (clearskies-auditor) — after Phase 0B QC:** Verify (a) all 14 cards are in the registry with correct endpoint declarations (cross-reference against current `now.tsx` data hooks), (b) card-manifest.json matches the registry, (c) `tsc --noEmit` and `vite build` evidence is present in QC notes, (d) no card was missed or had its data requirements changed vs the current implementation. Report findings.

### PHASE 1 — Dynamic Now Page (Dashboard)

**Depends on: Phase 0B**

**T1.1 — Refactor now.tsx to use registry + layout config**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/routes/now.tsx`
- Do:
  1. Fetch layout config via `fetchNowLayout()` on mount
  2. Look up each card in `CARD_REGISTRY`
  3. Collect all unique API endpoints from active cards via `getEndpointsForCards()`
  4. Fetch each unique endpoint once, build `DataBag`
  5. Render cards in layout order: `<Grid>` → for each entry, render `card.component` with `{ dataBag, layout, stationTz }`
  6. NowHeroCard remains outside the grid (not a card — it's a layout element)
  7. React hooks constraint: all hooks must be called unconditionally. Use skip/enabled flags on hooks for endpoints not needed by the active card set.
- Accept: Rendering is pixel-identical to current when no `now-layout.json` exists (falls back to default). Creating a test `now-layout.json` with a subset of cards renders only those cards. `tsc --noEmit` and `vite build` clean.

**T1.2 — Add now-layout.json to Caddy static serving**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: Three Caddyfiles (examples/reverse-proxy, frontend-host, single-host)
- Do: Add `handle /now-layout.json { root * /etc/weewx-clearskies; file_server }` with `Cache-Control: no-cache` header.
- Accept: `/now-layout.json` served when file exists, 404 when absent.

**T1.3 — Prepare cards directory for v2**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `scripts/redeploy-weather-dev.sh`, Caddyfiles
- Do: Add `--exclude cards/` to the rsync command in the redeploy script. Add `handle /cards/* { root * /var/www/clearskies; file_server }` to Caddyfiles. No functional change now — prepares the path convention for v2 custom card import.
- Accept: Redeploy preserves any `cards/` directory in the web root.

**QC (Opus) — after Phase 1:** Deploy to weather-dev. Verify Now page renders identically with no `now-layout.json`. Create a test layout with 6 cards, verify only those render. Verify unused API endpoints are not called (check network tab). Verify `cards/` directory survives a redeploy.

**QA Audit (clearskies-auditor) — after Phase 1 QC:** Verify (a) visual identity evidence exists (before/after comparison), (b) subset layout test was actually performed with evidence, (c) Caddy routes are in all three Caddyfile variants, (d) rsync exclude is in the redeploy script. Report findings.

### PHASE 2 — Page Visibility: Static Config + Dashboard (Independent of Phase 0B/1)

**T2.1 — Create pages.json static config and Caddy route**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: Three Caddyfiles, `wizard/config_writer.py`
- Do: Add Caddy route for `/pages.json` from `/etc/weewx-clearskies/` with `Cache-Control: no-cache`. Add `write_pages_json(state, config_dir)` to config writer — writes `{ "hidden": [] }`. Call from `apply_wizard()`.
- Accept: `/pages.json` served after wizard apply. Contains `{ "hidden": [] }`.

**T2.2 — Dashboard reads page visibility from static config**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `src/lib/page-visibility.ts`, modify `src/components/layout/nav-rail.tsx`, modify `src/App.tsx`
- Do:
  - `page-visibility.ts`: `fetchPagesConfig()` → fetches `/pages.json`, returns `{ hidden: [] }` on 404. `usePageVisibility()` hook.
  - `nav-rail.tsx`: filter `NAV_ITEMS` by visibility. "Now" is never filtered.
  - `App.tsx`: hidden page routes redirect to NotFound page.
- Accept: `"hidden": ["seismic"]` removes Seismic from nav and `/seismic` shows 404. "Now" always visible. Empty hidden = all visible.

**T2.3 — Branded 404 page with weather pun**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/routes/not-found.tsx`
- Do: Import `useBranding` for operator logo. Display logo (theme-aware). Array of 8-10 weather puns, randomly selected. "Back to Now" link. WCAG AA compliant.
- Accept: 404 shows operator logo + pun + home link. Works in light and dark themes. `tsc --noEmit` passes.

**QC (Opus) — after Phase 2:** Test page visibility with various configs. Verify nav filtering on desktop and mobile. Verify hidden URLs show branded 404. Verify 404 in both themes. `tsc --noEmit` + `vite build` clean.

**QA Audit (clearskies-auditor) — after Phase 2 QC:** Verify (a) "Now" protection was tested (attempted hide, confirmed always visible), (b) both desktop rail and mobile bottom nav were tested, (c) 404 page meets WCAG AA (contrast, heading hierarchy, focus), (d) page visibility is NOT read from the API. Report findings.

### PHASE 3 — Admin Landing Page + Expanded Sections (Stack)

**Depends on: Phase 2** (pages.json must exist for page visibility admin)

**T3.1 — Add /admin route and landing page**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `app.py`, new `admin/routes.py`, new `templates/admin/landing.html`
- Do:
  - `/admin` handler: if `api.conf` doesn't exist → redirect to `/wizard`. Otherwise → render landing page (authenticated).
  - Landing page organized by domain (not by config file):
    - Station Identity (from `stack.conf [ui]`)
    - Database (from `api.conf [database]`)
    - Providers (from `api.conf [forecast/alerts/aqi/earthquakes/radar]`)
    - Appearance (from `branding.json`)
    - Analytics & Privacy (from `branding.json`)
    - Webcam (from `stack.conf [webcam]`)
    - Pages (from `pages.json`)
    - Now Page Layout (from `now-layout.json`)
    - Column Mapping (from `api.conf [column_mapping]`)
    - TLS (from `stack.conf [tls]`)
  - Each section card: summary of current values + "Edit" link → HTMX loads edit form
  - "Re-run Setup Wizard" link at bottom
- Accept: `/admin` renders with all sections. Current values shown. Redirect to wizard when `api.conf` absent.

**T3.2 — Page visibility admin section**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `admin/routes.py`, new `templates/admin/pages_visibility.html`, `config/reader.py`, `config/updater.py`
- Do: GET/POST handlers. Checkboxes for 9 built-in pages. "Now" checkbox disabled/always-checked. POST writes `pages.json`. HTMX fragment pattern.
- Accept: Toggle + save updates `pages.json`. Dashboard reflects change on next load. "Now" cannot be unchecked.

**T3.3 — Branding/social/analytics/privacy admin sections**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `admin/routes.py`, new templates, `config/reader.py`, `config/updater.py`
- Do: HTMX edit forms for branding (site title, logos, accent, theme, custom CSS, favicon), social (4 URLs), analytics (GA ID), privacy (continent checkboxes). All read from and write to `branding.json`.
- Accept: Each section shows current values. Save updates `branding.json`. Dashboard picks up changes.

**T3.4 — Feature settings + TLS admin sections**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `admin/routes.py`, new templates
- Do: Earthquake settings (radius, magnitude, days) → writes to `stack.conf [earthquakes]`. TLS settings (mode, domain, email, provider) → writes to `stack.conf [tls]`.
- Accept: Settings round-trip through admin.

**T3.5 — Sky Classification calibration admin section**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `admin/routes.py`, new template `templates/admin/sky_classification.html`
- Do: Admin section where operators adjust sky condition classifier thresholds:
  - SCATTER_CLOUDS Km sub-split boundaries (default: 0.6 / 0.5 / 0.4)
  - OVERCAST Km×Kv sub-split boundaries (default: Km 0.15, Kv 0.03)
  - SZA guard threshold (default: 5° elevation)
  - Display: K-C reference table (Km ↔ okta ↔ NWS label), current threshold values, sensor accuracy guidance ("Davis ±3-5%, Ambient ~±15% — tight thresholds may be unreliable on consumer equipment"), "Reset to defaults" button.
  - Save to `api.conf [sky_classification]` section. API reads at startup.
- Accept: Thresholds round-trip through admin. K-C table and sensor guidance displayed. Reset restores defaults.
- Source: `docs/reference/sky-classification-science.md` §5 (K-C formula), §7 (sensor accuracy), §8 (sub-split rationale).

**QC (Opus) — after Phase 3:** Navigate to `/admin`, verify all sections. Edit branding, verify `branding.json` updates. Toggle page visibility, verify `pages.json`. Sky classification section shows K-C table and allows threshold adjustment. All forms have `<label>` and `aria-describedby`. No regression in existing `/admin/config` sections.

**QA Audit (clearskies-auditor) — after Phase 3 QC:** Verify (a) all 10 admin sections listed in T3.1 are present, (b) branding round-trip was tested end-to-end (admin edit → branding.json change → dashboard reflects), (c) page visibility round-trip tested, (d) wizard redirect tested when api.conf absent, (e) form accessibility (labels, aria) verified. Report findings.

### PHASE 4 — Now Page Card Layout Editor (Stack)

**Depends on: Phase 0B** (card manifest must exist) **+ Phase 1** (dynamic Now page must render from layout config)

**T4.1 — Sortable.js integration**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: New `static/vendor/sortable.min.js` (vendored, MIT), new `static/card-layout-editor.js`
- Do: Two Sortable.js instances: card palette (available cards not in layout) and active grid (current layout). Drag between palette and grid. Reorder within grid. On change, serialize layout to JSON in a hidden textarea for HTMX submit. Keyboard-accessible move-up/move-down/add/remove buttons alongside drag-and-drop.
- Accept: Drag-and-drop works in Chrome and Firefox. Keyboard alternatives functional.

**T4.2 — Card layout editor admin section**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `admin/routes.py`, new `templates/admin/card_layout.html`, `config/reader.py`, `config/updater.py`
- Do:
  - GET: Read `card-manifest.json` from dashboard web root. Read current `now-layout.json` from config dir (or default). Render editor with cards split between palette and active grid. Each card shows thumbnail, display name, current footprint, and footprint selector dropdown (only options from `allowedLayouts`).
  - POST: Receive layout JSON. Validate card types against manifest. Write `now-layout.json`. Return success fragment.
- Accept: Editor renders with all cards. Drag/drop/reorder/remove works. Save writes valid `now-layout.json`. Dashboard renders new layout on next load.

**T4.3 — Card thumbnail images**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `public/card-thumbnails/` with 14 PNG files (one per card type)
- Do: ~200x150px stylized previews of each card. Placeholder images with card name + icon are acceptable for initial implementation — the path convention matters more than pixel-perfect screenshots.
- Accept: All 14 thumbnails load. Manifest references correct paths.

**QC (Opus) — after Phase 4:** Open layout editor. Drag cards between palette and grid. Reorder. Change a card's footprint (for any card that has multiple allowed layouts — currently none, but verify the dropdown renders correctly with a single option). Save. Verify `now-layout.json`. Load dashboard, verify layout matches. Test edge cases: empty grid (should show something sensible), all cards in grid, duplicate prevention.

**QA Audit (clearskies-auditor) — after Phase 4 QC:** Verify (a) Sortable.js is vendored (not CDN), MIT license present, (b) keyboard alternatives work (not just drag-and-drop), (c) layout editor → now-layout.json → dashboard render was tested end-to-end, (d) card manifest validation prevents unknown card types, (e) all 14 thumbnails exist and load. Report findings.

### PHASE 5 — API Architecture Cleanup

**Independent — can run after Phase 2** (dashboard no longer reads page visibility from API)

**T5.1 — Remove page hiding from the API**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `config/settings.py` — remove `PagesSettings` class, `hidden_pages` from `StationSettings`, `pages` from `AppSettings`
  - `endpoints/pages.py` — remove `wire_hidden_pages()`, change `get_pages()` to return all built-in pages unconditionally
  - `services/pages.py` — remove `get_visible_pages()`, keep `get_all_pages()`
  - `__main__.py` — remove `wire_hidden_pages()` import and call
  - Tests — update/remove tests referencing `wire_hidden_pages`
- Accept: `GET /pages` returns all 9 pages unconditionally. `ruff check` + `mypy` pass. All tests pass. API starts without `[pages]` section in `api.conf`.

**QC (Opus) — after Phase 5:** `ruff check`, `mypy`, `pytest` all clean. API starts and `/pages` returns 9 pages.

**QA Audit (clearskies-auditor) — after Phase 5 QC:** Verify (a) no residual references to `wire_hidden_pages` or `PagesSettings` in the API codebase, (b) `ruff check`, `mypy`, `pytest` evidence present, (c) API starts cleanly without `[pages]` in api.conf. Report findings.

### PHASE 6 — Deploy + Final Verification

**Note:** Governing document updates were completed in Phase 0A (before coding began). Phase 6 verifies docs still match the final code. Any drift introduced during implementation is fixed here.

**T6.1 — Verify doc-code sync**
- Owner: Coordinator (Opus)
- Do: Walk all four manuals and ARCHITECTURE.md against the implemented code. Fix any drift introduced during implementation phases. Verify API-MANUAL.md reflects that `/pages` no longer filters.
- Accept: Docs match code. No stale references to API page hiding.

**T6.2 — Deploy all three repos**
- Owner: Coordinator (Opus)
- Do: Dashboard: `tsc --noEmit` + `npm run build` + redeploy. Config UI: restart service. API: restart service.
- Accept: All services start. Admin renders. Page visibility works. Layout editor works. Now page renders from config.

**T6.3 — End-to-end verification**
- Owner: Coordinator (Opus)
- Walk every acceptance criterion from every task. Specifically:
  1. `/admin` renders landing page with all sections
  2. Edit branding → dashboard reflects changes
  3. Toggle page visibility → nav filters + 404 works
  4. Custom card layout → dashboard renders correctly
  5. API `/pages` returns all 9 unconditionally
  6. 404 page shows logo + pun
  7. All config files written correctly
  8. No visual regression on any dashboard page

**QA Audit (clearskies-auditor) — final:** Walk the complete plan acceptance criteria against the coordinator's Phase 6 evidence. Verify every numbered item in T6.3 has evidence (not just assertion). Flag any item where the coordinator claimed success without verifiable proof. This is the final gate before the plan is marked complete.

---

## 4. Agent Assignments

| Phase | Task | Owner | QC Timing |
|-------|------|-------|-----------|
| 0A | T0A.1-T0A.4 ADRs + amendments | Coordinator (Opus) | After all ADRs accepted |
| 0A | T0A.5 Manual updates | Coordinator (Opus) | After Phase 0A |
| 0B | T0B.1 Card metadata + registry | `clearskies-dashboard-dev` | After Phase 0B |
| 0B | T0B.2 Card self-extraction refactor | `clearskies-dashboard-dev` | After Phase 0B |
| 0B | T0B.3 Layout config type | `clearskies-dashboard-dev` | After Phase 0B |
| 0B | T0B.4 Build-time manifest | `clearskies-dashboard-dev` | After Phase 0B |
| 1 | T1.1 Dynamic Now page | `clearskies-dashboard-dev` | After Phase 1 |
| 1 | T1.2 Caddy layout route | `clearskies-stack-dev` | After Phase 1 |
| 1 | T1.3 Cards directory prep | `clearskies-stack-dev` | After Phase 1 |
| 2 | T2.1 pages.json + Caddy | `clearskies-stack-dev` | After Phase 2 |
| 2 | T2.2 Dashboard page filtering | `clearskies-dashboard-dev` | After Phase 2 |
| 2 | T2.3 Branded 404 | `clearskies-dashboard-dev` | After Phase 2 |
| 3 | T3.1 Admin landing page | `clearskies-stack-dev` | After Phase 3 |
| 3 | T3.2 Page visibility admin | `clearskies-stack-dev` | After Phase 3 |
| 3 | T3.3 Branding/social admin sections | `clearskies-stack-dev` | After Phase 3 |
| 3 | T3.4 Feature/TLS admin sections | `clearskies-stack-dev` | After Phase 3 |
| 4 | T4.1 Sortable.js integration | `clearskies-stack-dev` | After Phase 4 |
| 4 | T4.2 Card layout editor | `clearskies-stack-dev` | After Phase 4 |
| 4 | T4.3 Card thumbnails | `clearskies-dashboard-dev` | After Phase 4 |
| 5 | T5.1 API page hiding removal | `clearskies-api-dev` | After Phase 5 |
| 6 | T6.1-T6.3 Deploy + verify | Coordinator (Opus) | After deploy |

**Sequencing:**
- Phase 0A (ADRs + manuals — MUST complete before any coding) → Phase 0B (card architecture) → Phase 1 (dynamic Now page) → Phase 4 (layout editor)
- Phase 0A → Phase 2 (page visibility — independent of Phase 0B/1, can run parallel) → Phase 3 (admin landing + sections)
- Phase 0A → Phase 5 (API cleanup — independent, after Phase 2)
- Phase 6 (deploy — after all phases)

**Parallelism:** Phase 0B and Phase 2 can run simultaneously (different repos, no dependencies). Phase 5 can run with Phase 3 or Phase 4. All coding phases depend on Phase 0A completing first.

---

## 5. QC Gates

### Gate 1 — Code Quality (every phase)
- Dashboard: `tsc --noEmit` 0 errors. `vite build` clean.
- Stack: `python -m py_compile <file>` passes. Templates render without Jinja2 errors.
- API: `ruff check` + `mypy` no introduced errors.

### Gate 2 — Feature Correctness (per phase)
- Phase 0A: All ADRs accepted. All four manuals updated with prescriptive rules. An agent can implement from manuals alone.
- Phase 0B: 14 cards registered. Self-extraction produces identical rendering. Manifest JSON valid.
- Phase 1: Now page renders identically with default layout. Subset layout renders only active cards. Unused endpoints not fetched.
- Phase 2: Page visibility filtering in nav + routes. "Now" protection. Branded 404 with logo.
- Phase 3: Admin landing shows all sections. Per-section editing works. branding.json/pages.json round-trip.
- Phase 4: Drag-and-drop works. Layout saves. Dashboard renders from saved layout.
- Phase 5: `/pages` returns all 9 unconditionally. No startup errors.

### Gate 3 — Architecture Compliance
- Page hiding is NOT in the API.
- Card metadata lives in the card, not duplicated elsewhere.
- Static config files (pages.json, now-layout.json, branding.json) are the source of truth for UI config.
- All 14 built-in cards conform to the plugin contract (ready for v2 import system).
- Cards directory in web root survives redeploy.

### Gate 4 — Accessibility (WCAG AA)
- Card layout editor: keyboard-accessible (move-up/down/add/remove buttons alongside drag-and-drop).
- Admin forms: `<label>` + `aria-describedby` on all inputs.
- 404 page: heading hierarchy, contrast, focus management.
- Page visibility checkboxes: labeled, "Now" disabled state explained.

---

## 6. Self-Audit

**Risk: Card self-extraction refactor scope (T0B.2).** This is the largest single task — refactoring 14 card components from specific props to DataBag extraction. Each card must produce identical output. Mitigation: This is a mechanical refactor (moving prop-reading code into the component). QC verifies visual identity before/after. Can be split across multiple commits (one card per commit) for easier review.

**Risk: React rules of hooks in dynamic Now page (T1.1).** All hooks must be called unconditionally at the top of the component. The dynamic behavior (skipping unused endpoints) must be achieved via skip/enabled flags on hooks, not conditional hook calls. Mitigation: Existing hooks already support skip patterns. Acceptance criteria require `tsc --noEmit` which catches hook ordering violations.

**Risk: Sortable.js keyboard accessibility.** Sortable.js drag-and-drop is mouse-optimized. Mitigation: Add explicit keyboard-accessible buttons (move-up/down/add/remove) alongside the drag interface. Admin is an operator tool, but basic keyboard operation should work.

**Risk: Static file caching.** `pages.json` and `now-layout.json` served by Caddy may be cached by browsers. Mitigation: Caddy `handle` blocks include `Cache-Control: no-cache` headers.

**Risk: Backward compatibility.** Missing `pages.json` or `now-layout.json` must degrade gracefully. Mitigation: Both fetch functions return safe defaults on 404 (all pages visible, default card layout).

**Risk: Build-time manifest generation (T0B.4).** The prebuild script imports from `card-metadata.ts`. If it imports React code by accident, the build fails. Mitigation: Metadata is in a separate file with no React imports. The script imports only that file.

**Risk: Card endpoint mapping accuracy.** The endpoint declarations in card metadata must match the actual API endpoints. A typo means the card gets no data. Mitigation: The endpoint paths reference the existing OpenAPI spec. QC verifies each card's endpoints against the current `now.tsx` data hook mapping.

**Risk: v2 readiness.** The architecture must support future third-party card import without rewriting built-in cards. Mitigation: Built-in cards use the same `CardComponentProps` interface that imported cards will use. The registry supports dynamic registration. The cards directory and rsync exclude are in place.

---

## 7. Existing Code Reference (for new session context)

Key files the coordinator must read before writing agent prompts:

**Dashboard repo (`repos/weewx-clearskies-dashboard/`):**
- `src/routes/now.tsx` — current hardcoded card composition (14 cards, data hooks, prop passing)
- `src/components/ui/card.tsx` — Card primitive, `CardFootprint` type, `rowSpan` props
- `src/components/layout/grid.tsx` — CSS Grid container, responsive columns, row tracks
- `src/components/layout/nav-rail.tsx` — navigation component, hardcoded `NAV_ITEMS` (lines 37-47)
- `src/App.tsx` — router configuration, lazy-loaded page routes
- `src/lib/branding-provider.tsx` — branding config fetch from `/branding.json`
- `src/hooks/useWeatherData.ts` — data fetching hooks (observation, forecast, aqi, earthquakes, etc.)
- `src/routes/not-found.tsx` — current generic 404 page
- `src/api/openapi-v1.yaml` — published API contract (what card authors reference)

**Stack repo (`repos/weewx-clearskies-stack/weewx_clearskies_config/`):**
- `app.py` — FastAPI app, auth, root routing, login/logout/bootstrap
- `config/routes.py` — existing admin config router at `/admin/config`, `_SECTION_META`, per-section CRUD
- `config/reader.py` — reads .conf files, managed region extraction
- `config/updater.py` — writes to managed regions, secrets.env updates
- `wizard/config_writer.py` — writes stack.conf, branding.json, secrets.env, webcam.json on wizard apply
- `wizard/state.py` — WizardState dataclass (~50 fields)
- `wizard/routes.py` — 14 wizard steps, apply flow
- `templates/config/dashboard.html` — existing admin config overview page
- `auth.py` — Argon2id password hashing, session management, rate limiting

**API repo (`repos/weewx-clearskies-api/`):**
- `config/settings.py` — `PagesSettings` class (lines 340-353), `hidden_pages` in `StationSettings` (line 255)
- `endpoints/pages.py` — `wire_hidden_pages()`, `get_pages()` endpoint
- `services/pages.py` — `get_visible_pages()`, `get_all_pages()`
- `__main__.py` — startup wiring, line 785 calls `wire_hidden_pages()`

**Config files on server (`/etc/weewx-clearskies/`):**
- `api.conf` — API config (database, providers, server, column mapping). Written by API via POST /setup/apply.
- `stack.conf` — UI settings, webcam, branding cache, earthquakes, TLS. Written by wizard.
- `branding.json` — authoritative branding config. Written by wizard. Served by Caddy at `/branding.json`.
- `secrets.env` — API keys, admin credentials, proxy secret. Mode 0600.
- `webcam.json` — webcam config. Written by wizard. Served by Caddy at `/webcam.json`.

**Caddy routing (three Caddyfile variants in stack repo):**
- `/admin*` → config UI port 9876
- `/wizard*` → config UI port 9876
- `/branding.json` → static file from `/etc/weewx-clearskies/`
- `/webcam.json` → static file from `/etc/weewx-clearskies/`
- New routes needed: `/pages.json`, `/now-layout.json` → static from `/etc/weewx-clearskies/`
