# Radar Provider Replacement — Execution Plan

**Status:** COMPLETE — All phases done, deployed and verified 2026-06-26
**Created:** 2026-06-23 | **Revised:** 2026-06-26
**Brief:** [docs/briefs/RADAR-PROVIDER-REPLACEMENT.md](docs/briefs/RADAR-PROVIDER-REPLACEMENT.md)
**Governs:** PROVIDER-MANUAL.md §7, API-MANUAL.md, DASHBOARD-MANUAL.md, DESIGN-MANUAL.md, OPERATIONS-MANUAL.md, ARCHITECTURE.md
**Research:** WMS-T research complete — see [RADAR-WMS-RESEARCH-PLAN.md](RADAR-WMS-RESEARCH-PLAN.md). Findings informed the provider architecture decision below.

---

## Context

RainViewer gutted its free API tier on 2026-01-01: zoom capped at 7, no nowcast, single color scheme, PNG only. The radar card is nearly useless for local weather awareness. Aeris radar is unviable at the PWS contributor tier (3,000 map units/day, ToS gray area on caching).

This plan adds **LibreWxR** as an optional radar provider alongside the existing (degraded) RainViewer. LibreWxR is a self-hostable, open-source weather data platform that provides processed radar (smoothing, denoising, despeckle), 13 color schemes, zoom 12, WebP tiles, 60-minute nowcast, satellite imagery, and weather alerts — all via a RainViewer v2 API-compatible interface.

**RainViewer stays as the default** radar provider. It works out of the box for any operator with zero infrastructure. LibreWxR is offered as an optional upgrade for operators who want better radar quality and are willing to either use the public API (no SLA) or self-host.

The plan also adds an **expanded radar view** — visitors tap an expand button on the Now page radar card to open a full-viewport overlay with animation controls, layer configuration, color scheme picker, alert overlays, and opacity control. The expanded view opens at the same zoom level and center as the card — it provides room for controls and readable detail, not a different map. Visitors can zoom out up to the provider's configured coverage bounds, but no further. The overlay pushes `/radar` to browser history for bookmarkability.

### What changed from the previous plan version (2026-06-25)

The original plan had two radar paths: LibreWxR (global) and NOAA unified (US-only, raw WMS-T). WMS-T rendering research (D1-D3 of the research plan) proved the rendering pattern works but surfaced that raw NOAA WMS-T imagery is visually noisy — it would require building post-processing (smoothing, denoising, interpolation) that LibreWxR already provides. The NOAA direct path was dropped.

**Dropped from previous plan:**
- NOAA unified provider module (WMS-T radar, satellite, SPC overlays)
- Multi-layer capability model (no longer needed — both providers are single-layer XYZ)
- WMS-T rendering (leaflet-timedimension) — retained as reference via ADR-074
- SPC convective outlooks
- API tile proxying for LibreWxR (Caddy proxies instead)

**Added/changed:**
- Caddy proxies LibreWxR traffic (tiles, alerts) — API provides metadata only
- Alert overlays from LibreWxR `/v2/alerts` (routed through Caddy)
- Geographic bounds enforcement (`maxBounds` from provider capabilities)
- Wizard writes both `api.conf` and Caddyfile for LibreWxR
- Personal LibreWxR fork (BBOX cropping for SoCal) is explicitly out of scope — separate project, coordination only (see §7 Handoff)

**Scope boundary:** This plan adds one new provider (librewxr) and adjusts the existing set (RainViewer stays default with a limitations note, Aeris dropped from radar). It does NOT add existing regional providers (dwd_radolan, msc_geomet) to the wizard. Personal LibreWxR modifications (BBOX cropping) are a separate project.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — §5 WCAG accessibility, §6 Recharts, §7 build verification
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/briefs/RADAR-PROVIDER-REPLACEMENT.md` — full research, provider evaluation, integration model

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`. Lint: `ruff check`, `mypy`.
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind + shadcn/ui). Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).
- `weewx-clearskies-stack` — Config wizard (Jinja2 + HTMX + Pico CSS). No build step. Branch: `main`.

**Deploy (from any machine with replicated project files):**
- Dashboard: `bash scripts/redeploy-weather-dev.sh`
- Wizard: `ssh -F .local/ssh/config weather-dev "sudo systemctl restart weewx-clearskies-config"`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (takes ~2 min to warm cache)

**Key existing files:**
- API radar endpoint: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/radar.py`
- API radar providers: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/radar/` (8 modules)
- API capability model: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/_common/capability.py`
- API dispatch: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/_common/dispatch.py`
- API config: `repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py` (RadarSettings)
- Dashboard radar card: `repos/weewx-clearskies-dashboard/src/components/shared/radar-card.tsx`
- Dashboard radar map: `repos/weewx-clearskies-dashboard/src/components/shared/radar-map.tsx`
- Dashboard card registry: `repos/weewx-clearskies-dashboard/src/lib/card-registry.ts`
- Wizard provider registry: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/providers.py`
- Wizard provider step: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_providers.html`
- Wizard admin provider section: `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/config/provider_section.html`

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** QC after EVERY phase. No phase advances until sign-off.

### Coordinator execution rules

1. **Coordinator reads all docs and code directly.** The coordinator must personally read the relevant manuals, ADRs, existing code files, and reference docs before assigning work to agents. This context is what enables the coordinator to write detailed agent prompts and perform effective QC. Do NOT delegate doc/code reading to sub-agents — the coordinator needs the full picture to catch cross-cutting issues.

2. **Agents cannot spawn other agents.** Dev agents (`clearskies-api-dev`, `clearskies-dashboard-dev`, `clearskies-stack-dev`) execute their assigned tasks and return results. They do NOT spawn sub-agents, delegate to other agents, or use the Agent tool. All orchestration flows through the coordinator.

3. **Coordinator writes detailed agent prompts.** Because the coordinator has read the docs and code, each agent prompt must include: the specific files to modify, the exact behavior to implement (from the manuals), the acceptance criteria, and references to the manual sections that govern the work. Agents should not need to search for context — it should be in the prompt.

4. **One agent per task (or per tightly-coupled task group).** Don't give one agent all of Phase 1. Give it T1.1, verify, then give T1.2. Exceptions: tightly-coupled tasks that share state can be assigned together.

---

## 1. Design Decisions (Settled)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Default provider | RainViewer (existing, degraded) | Path of least resistance — works out of the box, no infrastructure. Operators who want better quality upgrade to LibreWxR. |
| LibreWxR integration | Optional provider, Caddy-proxied | Operator configures endpoint (public API or self-hosted). Caddy reverse-proxies LibreWxR traffic. API provides metadata/capabilities only. |
| NOAA direct | Dropped | Raw WMS-T imagery is visually noisy. Would require building post-processing pipeline that LibreWxR already provides. |
| Tile routing | Caddy proxies LibreWxR tiles and alerts | Browser only talks to Caddy. Caddy routes `/librewxr/*` to the LibreWxR instance. API never touches tile traffic. |
| Alert overlays | LibreWxR `/v2/alerts` GeoJSON, via Caddy | Watch boxes, warnings, advisories rendered as Leaflet GeoJSON overlays on the radar map. |
| SPC convective outlooks | Dropped | Would require separate data pipeline (SPC mapservices). Out of scope — deferred to future custom system. |
| Expanded view | Same zoom/center as card, more controls | Not a bigger map — a better interface. Controls, layer config, alert overlays, color schemes. Closeable (button + Escape). |
| Zoom bounds | Bounded by provider's coverage area | `maxBounds` from capabilities metadata. Personal BBOX-cropped LibreWxR = SoCal only. Full CONUS instance = continental US. Public API = global. |
| Card appearance | Minimal — current controls + expand button | Keep Now page card clean; expanded view is the "dive deeper" path. |
| RainViewer status | Default but degraded. Wizard notes limitations. | Still functional at zoom 7 for operators who want zero setup. |
| Aeris radar status | Dropped from radar domain. Remains for forecast/AQI/alerts. | 3,000 map units/day is unviable for radar tiles. |
| Frame metadata | API normalizes for all providers | Dashboard gets frames from API in consistent format regardless of provider. Keeps dashboard decoupled from provider-specific wire formats. |
| Personal LibreWxR fork | Out of scope — separate project | BBOX cropping for SoCal is personal infrastructure, not Clear Skies project work. Coordination via handoff (§7). |

---

## 2. Implementation Phases

### PHASE 0 — Foundation (ADR + Reference Docs + ALL Manual Updates)

> **Manuals before code.** The manuals are what dev agents consult. If the manuals are silent on what the agent is building, the agent has no guidance. ALL manual updates happen in Phase 0, before any code phase starts.

**T0.1 — Fetch and save LibreWxR API docs** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- Do: Fetch from librewxr.net/docs and save to `docs/reference/api-docs/librewxr.md` with capture date header. Include: configuration reference (env vars, frame counts), weather-maps.json response format, `/v2/alerts` endpoint format, RainViewer migration guide, coverage documentation, tile URL patterns.
- Accept: File exists with "Captured: 2026-06-26" header. Key env vars documented. Alerts endpoint format documented.
- Result: Existing file (captured 2026-06-24) verified against live public API — structure unchanged. Capture date updated to 2026-06-26.

**T0.2 — Amend ADR-015 (decision record update)** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- File: `docs/archive/decisions/ADR-015-radar-map-tiles-strategy.md`
- Do: Add amendment section recording: LibreWxR added as optional provider (Caddy-proxied), RainViewer stays default (degraded), NOAA direct dropped, Aeris dropped from radar, expand-to-fullscreen model, Caddy proxy routing model.
- Accept: ADR-015 amendment reflects current decisions.

**T0.3 — Update PROVIDER-MANUAL.md §7 (Radar)** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- File: `docs/manuals/PROVIDER-MANUAL.md`
- Do: Rewrite §7 Radar to reflect new provider set.
- Accept: §7 is internally consistent. An api-dev agent reading only this section would know exactly what to build.
- Result: Full rewrite of §7. Added LibreWxR module rules, Caddy proxy model, tile routing model table, geographic bounds, updated attribution table, wizard suggestion table, RainViewer degradation note. Also updated §1 (stale Aeris proxy reference) and §12 (new anti-patterns for LibreWxR).

**T0.4 — Update ARCHITECTURE.md** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`
- Do: Document Caddy proxy route, topology diagram, `/radar` route, provider module layout, radar endpoint description.
- Accept: Architecture doc reflects Caddy proxy model. No stale references.
- Result: Added `/librewxr/*` to Caddy routing table, updated topology diagram with LibreWxR box, added `/radar` to dashboard pages, updated provider module layout (librewxr added, aeris removed, iem_nexrad/noaa_mrms deprecated), updated radar endpoint description.

**T0.5 — Update API-MANUAL.md (radar capabilities)** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`
- Do: Rewrite §12 (Radar Endpoints and Capability Model) — remove stale multi-layer model, document Caddy proxy boundary, add capability metadata fields, config fields table, deprecation warnings.
- Accept: An api-dev agent reading the API-MANUAL would know the exact endpoint shapes and config fields.

**T0.6 — Update DASHBOARD-MANUAL.md (radar card + expanded view)** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- File: `docs/manuals/DASHBOARD-MANUAL.md`
- Do: Add new §10 (Radar Card & Expanded View) covering card, live refresh, idle timeout, expanded view, WCAG requirements. Renumbered §10 Anti-Patterns to §11.
- Accept: Dashboard-dev agent knows what features to build, what components exist, how tiles are fetched, and what the a11y requirements are.

**T0.7 — Update DESIGN-MANUAL.md (radar card + expanded view design spec)** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- File: `docs/manuals/DESIGN-MANUAL.md`
- Do: Add new §19 (Radar Card & Expanded View Design) covering card anatomy, expanded overlay layouts (desktop/mobile ASCII diagrams), time slider, layer/config panel, color scheme picker, alert polygon styling (severity colors), z-order stack, responsive breakpoints.
- Accept: Dashboard-dev agent reading the design manual knows the visual layout, component anatomy, and responsive behavior.

**T0.8 — Update OPERATIONS-MANUAL.md (LibreWxR configuration)** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- File: `docs/manuals/OPERATIONS-MANUAL.md`
- Do: Add RadarSettings key table, LibreWxR deployment modes (public API vs self-hosted), Caddy proxy route snippet, RainViewer degradation note. Inserted in §4 Configuration.
- Accept: Ops manual covers both modes. Caddy proxy model documented.

**T0.9 — Update ADR-074 status** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- File: `docs/decisions/ADR-074-wms-t-rendering-strategy.md`
- Status updated to "Superseded — provider direction chose LibreWxR (XYZ tiles); WMS-T not on critical path." Note references the research plan resolution.

**QC (Opus) — after Phase 0:** Comprehensive manual review:
1. PROVIDER-MANUAL §7 — api-dev agent could build the LibreWxR module from this section alone
2. API-MANUAL — endpoint shapes, capability metadata, config fields specified
3. DASHBOARD-MANUAL — card + expanded view + alert overlays described, XYZ tile animation only
4. DESIGN-MANUAL — visual layout, component anatomy, responsive behavior specified
5. ARCHITECTURE.md — Caddy proxy model correct, no stale references
6. OPERATIONS-MANUAL — LibreWxR config documented, Caddy routing noted
7. Reference docs (T0.1) have capture-date header
8. Cross-check: no manual contradicts another manual

---

### PHASE 1 — API: LibreWxR Provider Module + Config Changes

**T1.1 — LibreWxR provider module (metadata + capabilities)**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/radar/librewxr.py`
- Do: Build provider module for frame metadata and capability declaration. Key points:
  - `BASE_URL` configurable: defaults to `https://api.librewxr.net`, overridable via `[radar] librewxr_endpoint` in `api.conf`
  - **`get_frames()`** — fetches `{endpoint}/public/weather-maps.json`, returns canonical `RadarFrameList`. Same wire model and frame-kind mapping as RainViewer (max past → current, nowcast preserved). Cache TTL: 60s.
  - **Capability declaration** — includes:
    - Provider name, attribution (`"LibreWxR (https://librewxr.net/) — Data: CC-BY-4.0"`)
    - Geographic bounds (bounding box — from config, defaults to global)
    - Caddy proxy path prefix (`/librewxr`) for tiles and alerts
    - Available features: nowcast (bool), color_schemes (list), alerts (bool)
    - Tile URL template (relative to Caddy: `/librewxr/{path}/{size}/{z}/{x}/{y}/{color}/{options}.webp`)
    - Alert URL (`/librewxr/v2/alerts`)
  - **NO `get_tile()` method** — Caddy proxies tiles directly to LibreWxR. The API never handles tile bytes.
  - Rate limiter: polite-use guard (5 req/s) for weather-maps.json fetches
- Accept: Module passes `ruff check` + `mypy`. Frame metadata fetch works against `api.librewxr.net`. Capability includes bounds and Caddy path. No tile proxy code.

**T1.2 — Provider set changes (config, dispatch, limitations note, Aeris drop)**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `config/settings.py` (RadarSettings), `providers/_common/dispatch.py`, `endpoints/radar.py`, `__main__.py`
- Do:
  - Add `librewxr` to `RadarSettings` valid provider choices
  - Add `librewxr_endpoint` optional config field (default `https://api.librewxr.net`)
  - Add `librewxr_bounds` optional config field (bounding box, default empty = global)
  - Add `librewxr` to `PROVIDER_MODULES` dispatch table
  - Add degradation note to `rainviewer` CAPABILITY `operator_notes`
  - Remove `aeris` from radar domain (keep for forecast/AQI/alerts)
  - Keep `iem_nexrad` and `noaa_mrms` modules on disk but mark as deprecated (log migration warning)
  - Update `api.conf.example` with new provider options
- Accept: `api.conf` accepts `provider = librewxr`. Deprecated providers log migration warning. Aeris absent from radar. `ruff check` + `mypy` pass.

**QC (Opus) — after Phase 1:** Verify LibreWxR module fetches frames from public API. Capability response includes bounds and Caddy path. Config accepts new provider. Aeris removed from radar. All linting passes.

---

### PHASE 2 — Config UI: Wizard + Admin

**T2.1 — Add LibreWxR to provider registry**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/providers.py`
- Do: Add `ProviderInfo` entry:
  - `librewxr`: domain "radar", coverage "Global", no auth fields, keyless, test URL `https://api.librewxr.net/public/weather-maps.json`
  - Display note: "Global radar, satellite, nowcast, weather alerts. Self-host recommended for production."
- Accept: LibreWxR appears in wizard step 6.

**T2.2 — Update recommendation logic**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/providers.py`
- Do: Update `recommend_providers(latitude, longitude)` for radar domain:
  - Default recommendation: `rainviewer` (works everywhere, zero setup)
  - Alternative recommendation: `librewxr` (note: "Better quality — requires public API or self-hosting")
- Accept: All locations get `rainviewer` as primary recommendation with `librewxr` as alternative.

**T2.3 — LibreWxR endpoint + Caddy configuration**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `wizard/state.py`, `templates/wizard/step_providers.html`, `wizard/routes.py`
- Do: When operator selects `librewxr`, show additional fields:
  - "LibreWxR endpoint" radio: "Public API (api.librewxr.net)" vs "Self-hosted (enter URL)"
  - If self-hosted: URL input field (operator must provide their reachable URL)
  - Optional: geographic bounds fields (south, west, north, east) — for operators with BBOX-cropped instances
  - Note text: "Public API: no infrastructure needed, no SLA. Self-hosted: you deploy and maintain your own LibreWxR instance. It must be reachable by Caddy (your front-end host). See LibreWxR docs for setup."
  - Store endpoint in `state.providers_config["librewxr_endpoint"]`, write to `api.conf [radar] librewxr_endpoint`
  - Store bounds (if provided) in `state.providers_config["librewxr_bounds"]`, write to `api.conf [radar] librewxr_bounds`
  - **Write Caddy proxy route**: add `/librewxr/*` reverse proxy to Caddyfile pointing at the configured endpoint (strip `/librewxr` prefix)
- Accept: Endpoint config renders, saves to state, writes to api.conf AND Caddyfile. Round-trip works on re-run.

**T2.4 — Aeris radar removal + RainViewer degradation note**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `wizard/providers.py`, `templates/wizard/step_providers.html`, `templates/config/provider_section.html`
- Do:
  - Remove `aeris` from radar provider options (keep for forecast/AQI/alerts)
  - Add degradation note to `rainviewer`: "Limited: zoom 7 max, no nowcast, single color scheme (since Jan 2026)"
  - Update admin provider section template
- Accept: Aeris absent from radar. RainViewer shows degradation note. Admin matches wizard.

**T2.5 — Review page + apply handler**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `wizard/routes.py`, `templates/wizard/step_review.html`
- Do: Review page shows radar provider + endpoint + bounds config (if LibreWxR). Apply handler writes to both api.conf and Caddyfile.
- Accept: Full wizard round-trip works for LibreWxR and RainViewer.

**QC (Opus) — after Phase 2:** Walk full wizard flow: select LibreWxR self-hosted → configure endpoint + bounds → review → apply → verify api.conf has `librewxr_endpoint` and Caddyfile has `/librewxr/*` route. Re-run: select RainViewer → verify clean config. RainViewer shows degradation note. Aeris absent from radar.

---

### PHASE 3 — Dashboard: Radar Card Upgrades

**T3.1 — LibreWxR tile support (via Caddy)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Fetch frame metadata from API (`/api/v1/radar/providers/librewxr/frames`)
  - Fetch tiles via Caddy (`/librewxr/{path}/{size}/{z}/{x}/{y}/{color}/{options}.webp`)
  - Tile URL template comes from API capability response — dashboard does not hardcode paths
  - XYZ tile animation — same pattern as existing RainViewer (no WMS-T involved)
  - Nowcast frames visually distinguished
  - Color scheme parameter from config (default scheme, changeable in expanded view)
- Accept: LibreWxR tiles render and animate correctly. Nowcast visually distinct. No hardcoded tile paths.

**T3.2 — Provider-adaptive legend + attribution**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Legend adapts to active provider's color scheme
  - Attribution text from capability response
- Accept: Legend reflects current provider. Attribution displays correctly.

**T3.3 — Expand-to-fullscreen button**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Phosphor `ArrowsOut` icon on radar card
  - Navigates to `/radar` (pushes to browser history)
  - Opens expanded view at same zoom level and center as card
- Accept: Button renders, navigates to expanded view. Back button returns to previous page.

**T3.4 — Animation defaults + idle timeout**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Adaptive animation speed: target ~15-20s loop for card view regardless of frame count
  - Card view caps at ~24 most recent frames (LibreWxR with `MAX_FRAMES=24+`)
  - RainViewer frame count (~13) animates at existing speed
  - **Live refresh**: periodically re-fetch frame metadata to pick up new frames as they become available. Drop oldest frames to maintain the cap. The animation loop always shows the latest data, not a stale snapshot from page load. Refresh interval is operator-configurable (`[radar] librewxr_refresh_interval`, default 600s / 10 minutes) — operator matches this to their LibreWxR instance's `LIBREWXR_FETCH_INTERVAL`. The API includes the configured interval in the capability response so the dashboard knows how often to poll.
  - **Idle timeout**: stop animation, tile fetching, and live refresh after 60 minutes of no user interaction (mouse/touch/keyboard/scroll). Resume on interaction. Also pause immediately when the browser tab is hidden (Page Visibility API) and refresh data when the tab becomes visible again. Applies to both card view and expanded view. Prevents idle/hidden tabs from generating continuous load against the provider.
- Accept: Animation speed feels consistent. New frames appear without page reload. Animation pauses after idle timeout. Resumes on interaction.

**QC (Opus) — after Phase 3:** Visual verification with LibreWxR (color, zoom 12, nowcast). Expand button navigates. Legend adapts. Attribution displays. `tsc --noEmit` + `vite build` clean. axe-core 0 violations.

---

### PHASE 4 — Dashboard: Expanded Radar View

**T4.1 — Full-viewport overlay component**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Full-viewport overlay (100vw × 100vh)
  - `/radar` SPA route (Caddy `try_files` handles it)
  - Close button (top-right) + Escape key closes
  - Focus trap (a11y)
  - Opens at same zoom/center as card view
- Accept: Overlay renders full viewport. Close works via button and Escape. Focus trapped. `/radar` direct navigation works.

**T4.2 — Time slider + animation controls**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Horizontal scrubable slider (bottom bar)
  - Play/pause button, speed control
  - Current timestamp display
  - Nowcast frames visually distinguished on slider
  - Drives XYZ tile animation (same mechanism as card)
- Accept: Slider scrubs through frames. Play/pause works. Speed adjustable. Nowcast visually distinct.

**T4.3 — Layer/config panel**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Sidebar on desktop, bottom sheet on mobile (drag handle, half-height default)
  - Provider-adaptive: shows controls relevant to the active provider
  - Collapsible/expandable
  - localStorage persistence for panel state
- Accept: Panel renders and adapts to provider. Mobile bottom sheet works. State persists.

**T4.4 — Color scheme picker (LibreWxR only)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - 13 LibreWxR color schemes displayed as grid with swatch preview
  - Selection updates tile URL `color` parameter + legend
  - Hidden when provider is RainViewer
- Accept: All 13 schemes selectable. Tiles re-render with new scheme. Legend updates. Hidden for RainViewer.

**T4.5 — Opacity control**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - 0-100% slider, default 70%
  - Affects radar tile layer opacity
- Accept: Slider adjusts tile opacity smoothly.

**T4.6 — Alert polygon overlays (LibreWxR only)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Fetch from LibreWxR `/v2/alerts` via Caddy (URL from capability response)
  - Query by map viewport bounding box
  - Render as Leaflet GeoJSON polygons — severity-colored (stroke + fill)
  - Auto-refresh every 5 minutes
  - Toggle on/off in layer panel
  - Only available when provider is LibreWxR
- Accept: Alert polygons render with correct severity styling. Auto-refresh works. Toggle works. Hidden for RainViewer.

**T4.7 — Wind arrows overlay (LibreWxR only)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - LibreWxR provides wind arrow tiles as a separate layer
  - Render as an overlay on the radar map, z-order above radar
  - Toggle on/off in layer panel (default off)
  - Only available when provider is LibreWxR
- Accept: Wind arrows render over radar. Toggle works. Hidden for RainViewer.

**T4.8 — Zoom bounds enforcement**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Read geographic bounds from API capability response
  - Set Leaflet `maxBounds` to prevent zooming out past provider coverage
  - If no bounds specified (public API), allow global zoom
- Accept: Zoom-out stops at configured bounds. No empty tile areas visible at max zoom-out.

**T4.9 — WCAG accessibility audit**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Do:
  - Focus trap on expanded overlay
  - All controls keyboard navigable
  - Time slider: arrow keys, value announcements
  - aria-live for frame changes
  - `prefers-reduced-motion` respected (pause animation, reduce transitions)
  - axe-core 0 violations
- Accept: Full keyboard navigation. Screen reader announces frame changes. Motion preference respected. axe-core clean.

**QC (Opus) — after Phase 4:** Full expanded view walkthrough:
1. Overlay opens at correct zoom/center
2. Close button and Escape work
3. Time slider scrubs, play/pause, speed control
4. Color scheme picker changes tiles + legend (LibreWxR)
5. Opacity slider adjusts tiles
6. Alert polygons render and auto-refresh (LibreWxR)
7. Wind arrows toggle and render (LibreWxR)
8. Zoom bounded by provider coverage
9. Layer panel responsive (sidebar → bottom sheet)
10. Keyboard navigation complete
11. `/radar` direct navigation works
12. axe-core 0 violations

---

### PHASE 5 — Deploy + Final Verification

**T5.1 — Deploy API** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- Do: `ruff check` + `mypy` clean. Restart API on weewx. Verify `/api/v1/capabilities` shows LibreWxR provider with bounds and Caddy path. Verify `/api/v1/radar/providers/librewxr/frames` returns frame list.
- Accept: API serves LibreWxR provider data. No errors in logs.
- Result: API commit `e2ff74c` pushed (was NOT on remote despite prior belief), pulled on weewx, restarted. With LibreWxR config: capabilities shows `providerId: librewxr`, `caddyPrefix: /librewxr`, `alertUrl: /librewxr/v2/alerts`, `nowcastAvailable: true`, `alertsAvailable: true`, `refreshInterval: 600`, 13 `colorSchemes`. Frames endpoint returns 18 frames (11 past + 1 current + 6 nowcast). With RainViewer config: 13 frames (12 past + 1 current). Clean API logs (no errors beyond expected write-probe denial).

**T5.2 — Deploy dashboard** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- Do: `tsc --noEmit` + `npm run build` clean. Deploy via `scripts/redeploy-weather-dev.sh`.
- Accept: Radar card renders with configured provider. Expand button works. Expanded view functional.
- Result: 4 dashboard commits pushed, pulled on weather-dev. `tsc -b && vite build` clean (0 TS errors). Rsync'd to `/var/www/clearskies/`. New lazy-loaded chunks: `radar-kCcyaw2x.js` (3.01 KB gz), `radar-map-CvIt_ntX.js` (4.96 KB gz). Expanded view renders at `/radar` with correct map, tiles, controls.

**T5.3 — Deploy wizard** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- Do: Restart config service. Walk full wizard flow.
- Accept: LibreWxR appears in radar provider selection. Apply writes both api.conf and Caddyfile.
- Result: 2 stack commits pushed, pulled on weather-dev. Config service restarted. Health endpoint returns `{"status":"ok"}`.

**T5.4 — End-to-end verification** ✅ DONE (2026-06-26)
- Owner: Coordinator (Opus)
- Verification evidence:
  - **LibreWxR path:** Configured LibreWxR in api.conf → restarted API → capabilities shows LibreWxR with all metadata. Added Caddy `/librewxr/*` reverse proxy route → tiles serve 200 from `api.librewxr.net`. Playwright screenshot confirms LibreWxR tiles render on expanded view with correct SoCal center, attribution, time slider (18 frames), and nowcast.
  - **RainViewer path:** Switched back to RainViewer → capabilities shows RainViewer. Playwright screenshot confirms expanded view renders with RainViewer tiles, 13 frames, correct attribution. No LibreWxR-only features visible (correct degraded behavior).
  - **`/radar` bookmark:** Direct navigation to `/radar` returns 200 (SPA `try_files`). Expanded view loads correctly from direct URL.
  - **Mobile:** Playwright screenshot at 390×844 viewport: full-viewport map, zoom controls, settings icon, time slider ("Frame 5 of 13", "1x" speed, "2:20PM"), navigation controls all visible and properly laid out.
  - **No regressions:** Homepage renders all Now page cards correctly (71.8°F current conditions, forecast, wind, highlights, precipitation, barometer, solar radiation, UV index).
- Config state after verification: RainViewer as default (api.conf). Caddy `/librewxr/*` route left in place (harmless, ready for LibreWxR switch).

**Final QC (Opus):** All manuals were written in Phase 0 before code. No manual drift detected — implementation matches manual descriptions. All code deployed from local → GitHub → target hosts. Zero TS errors, clean API logs.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing | Status |
|-------|------|-------|-------|-----------|--------|
| 0 | T0.1 Reference doc capture | Coordinator | Opus | After Phase 0 | ✅ Done |
| 0 | T0.2-T0.9 ADR + ALL manual updates | Coordinator | Opus | After Phase 0 | ✅ Done |
| 1 | T1.1 LibreWxR module (metadata + capabilities) | `clearskies-api-dev` | Sonnet | After Phase 1 | ✅ Done (e2ff74c) |
| 1 | T1.2 Provider set changes | `clearskies-api-dev` | Sonnet | After Phase 1 | ✅ Done (e2ff74c) |
| 2 | T2.1-T2.5 Wizard + admin | `clearskies-stack-dev` | Sonnet | After Phase 2 | ✅ Done (130495b, 5ce1a05) |
| 3 | T3.1-T3.4 Radar card upgrades | `clearskies-dashboard-dev` | Sonnet | After Phase 3 | ✅ Done (f3bde67) |
| 4 | T4.1-T4.9 Expanded radar view | `clearskies-dashboard-dev` | Sonnet | After Phase 4 | ✅ Done (ddc9e95, f1b5d29, 1585c68) |
| 5 | Deploy + verify | Coordinator | Opus | After Phase 5 | ✅ Done (2026-06-26) |

**Sequencing:**
- Phase 0 (ADR + ALL manuals + reference docs) → blocks everything
- Phase 1 (API module) → blocks Phase 2 (wizard) and Phase 3 (dashboard card)
- Phase 2 (wizard) → depends on Phase 1 (needs provider ID and config fields)
- Phase 3 (dashboard card) → depends on Phase 1 (needs capability response)
- Phase 4 (expanded view) → depends on Phase 3 (card provides the expand entry point)
- Phase 5 (deploy) → depends on all prior phases

**Parallelism:** Phase 2 + Phase 3 can run in parallel after Phase 1 completes.

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- API: `ruff check` + `mypy` no introduced errors.
- Dashboard: `tsc --noEmit` 0 errors. `vite build` clean.
- Wizard: `python -m py_compile <file>` passes. Templates render without Jinja2 errors.

### Gate 2 — Feature Correctness (per phase)
- Phase 1: API capability response includes LibreWxR with bounds and Caddy path. Frame metadata returns valid data.
- Phase 2: Wizard round-trip for LibreWxR (select → configure → review → apply → verify api.conf + Caddyfile).
- Phase 3: Radar card renders with both provider types. Expand button navigates. Animation smooth.
- Phase 4: Expanded view functional test (11-point checklist above).

### Gate 3 — Manual Compliance (after Phase 5)
- All manuals written in Phase 0 before code; verify no drift during implementation.
- PROVIDER-MANUAL §7, API-MANUAL, ARCHITECTURE.md, DASHBOARD-MANUAL, DESIGN-MANUAL, OPERATIONS-MANUAL all current.

### Gate 4 — Accessibility (after Phase 4)
- Expanded view: `role="dialog"`, `aria-modal`, focus trap, Escape closes.
- All new controls: keyboard navigable, labeled, sufficient contrast.
- Time slider: arrow keys, value announcements.
- `prefers-reduced-motion` respected.
- axe-core 0 violations on radar card + expanded view.

---

## 5. Out of Scope (Explicit Deferrals)

| Feature | Why Deferred |
|---------|-------------|
| NOAA direct provider (WMS-T) | Raw imagery too noisy; would require custom post-processing. LibreWxR already processes MRMS data. ADR-074 retained as reference. |
| SPC convective outlooks | Separate data pipeline required (SPC mapservices). Deferred to future custom system. |
| Personal LibreWxR fork (BBOX cropping) | Personal infrastructure, not Clear Skies project. See §7 Handoff. |
| Client-side satellite colorization | Grayscale acceptable for v0.1 |
| LibreWxR Docker image build from source | Operators pull the upstream image |
| Aeris compliance audit (non-radar) | Separate task |
| Marine weather overlays | ADR-024 deferred |
| Custom page embedding of expanded radar | v2 card plugin scope |

---

## 6. Self-Audit

**Risk: LibreWxR API compatibility.** LibreWxR claims RainViewer v2 API compatibility. The provider module is built on this assumption. If the wire format diverges, the module needs adjustment. Mitigation: T0.1 captures the actual API docs; T1.1 tests against the live public API.

**Risk: LibreWxR availability.** The public API (`api.librewxr.net`) has no SLA or usage guarantees. Mitigation: self-hosting is documented as the production recommendation. RainViewer remains the default for zero-setup operators.

**Risk: Caddy proxy configuration.** The wizard must write correct Caddy reverse proxy config for LibreWxR. If the Caddyfile format changes or the operator's Caddy setup is non-standard, the route may not work. Mitigation: wizard writes a minimal `handle /librewxr/*` block using standard Caddy directives. Operators with custom Caddy configs can adjust manually.

**Risk: Geographic bounds accuracy.** The `maxBounds` enforcement depends on the operator configuring correct bounds in the wizard. If bounds are wrong or missing, the map may show empty tiles at zoom-out. Mitigation: default is no bounds (global zoom). Operators with BBOX-cropped instances are expected to configure bounds during setup.

**Risk: Alert overlay performance.** LibreWxR `/v2/alerts` may return many polygons in active severe weather. Mitigation: query by viewport bounding box limits the response. 5-min refresh avoids constant fetching. Toggle allows disabling.

**Architecture boundary: API never touches tile traffic.** Caddy proxies LibreWxR tiles and alerts directly. The API provides metadata (capabilities, frame lists) only. If this boundary is violated (e.g., a dev agent routes tiles through the API), it should be caught in QC.

**Simplification vs. previous plan.** The revised plan has significantly fewer tasks, no multi-layer capability model, no WMS-T rendering, and no NOAA-specific code. This is intentional — the scope reduction eliminates the complexity that caused the first implementation to fail.

---

## 7. Handoff: Personal LibreWxR Fork

> **This section provides context for Opus running in the personal infrastructure project.** The work described here is NOT part of Clear Skies. It is personal infrastructure that Clear Skies will consume via the Caddy proxy model once deployed.

### What

Fork LibreWxR to add a `LIBREWXR_BBOX` configuration option that crops MRMS radar data to a geographic bounding box at ingest time. This reduces resource requirements from ~3 GB RAM (full CONUS) to ~1 GB (SoCal only).

### Why

LibreWxR's smallest geographic unit is `CONUS` (full continental US via `LIBREWXR_ENABLED_REGIONS`). There is no sub-region support. The full CONUS MRMS grid is 3,500 × 7,000 pixels at 0.01° resolution. Each frame is ~63 MB in the memory-mapped FrameStore. For a personal weather dashboard covering only Southern California, this wastes ~99% of the data.

### Modification scope

1. **Fetcher** — after GRIB2 decode to numpy array, slice to BBOX indices before passing to FrameStore. The full CONUS GRIB2 must still be downloaded (NOAA doesn't serve sub-regions), but the decoded array can be cropped immediately. Transient peak: ~63 MB during decode, released after slicing.
2. **FrameStore** — stores the cropped array. No structural change, just smaller data.
3. **Tile renderer** — adjust coordinate mapping so tile z/x/y → lat/lon → grid indices accounts for the cropped origin and extent. **This is the most delicate part.** Incorrect mapping means tiles render at wrong positions.
4. **Nowcast** — optical flow runs on the cropped grid (smaller = faster). Should work without modification if the grid is consistent.

### Configuration

```env
COMPOSE_PROFILES=single
LIBREWXR_ENABLED_REGIONS=CONUS
LIBREWXR_BBOX=32.0,-120.5,35.5,-114.5    # SoCal: south,west,north,east
LIBREWXR_REGIONAL_NWP_ENABLED=false       # drops HRRR (big RAM saver)
LIBREWXR_ECMWF_ENABLED=false              # drops IFS global model
LIBREWXR_SATELLITE_ENABLED=false          # drops GMGSI satellite
LIBREWXR_NOWCAST_ENABLED=true             # keep 60-min nowcast
LIBREWXR_ALERTS_ENABLED=true              # keep weather alerts
LIBREWXR_MAX_FRAMES=24                    # 4 hours at 10-min cadence
LIBREWXR_WORKERS=1
```

### SoCal bounding box

- South: 32.0°N, West: 120.5°W, North: 35.5°N, East: 114.5°W
- Grid slice: ~350 × 600 pixels (0.86% of CONUS)
- Per-frame: ~0.8 MB vs ~63 MB

### Hardware estimate (LXD container)

| Resource | Estimate | Notes |
|----------|----------|-------|
| RAM | 1-1.5 GB | Python + uvicorn (~300 MB), cropped radar (~10 MB for 12 frames), nowcast (~5 MB), tile cache (100 MB), headroom for GRIB2 decode spike |
| CPU | 1 core | Processing runs on ~0.86% of CONUS grid. Negligible. |
| Disk | 2 GB | mmap'd frame files + tile cache + GRIB2 staging |
| Bandwidth | ~1-1.5 GB/day | Full CONUS GRIB2 downloaded every 10 min (~5-10 MB each). Cannot reduce — NOAA serves full CONUS only. |

### Integration with Clear Skies

Once deployed, the LibreWxR instance is consumed by Clear Skies via the Caddy proxy model:
- Caddy routes `/librewxr/*` to the LibreWxR LXD container
- API provides metadata (capabilities with SoCal bounds, frame lists)
- Dashboard fetches tiles and alerts via Caddy
- Geographic bounds (32.0, -120.5, 35.5, -114.5) configured in wizard → API capabilities → dashboard `maxBounds`

### References

- LibreWxR source: https://github.com/JoshuaKimsey/LibreWXR
- LibreWxR docs: https://librewxr.net/docs/
- License: AGPL-3.0 (personal use only — no distribution of modifications)
- WMS-T research (background): `docs/reference/wms-t-rendering-research.md` §8
