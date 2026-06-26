# Radar Provider Replacement — Execution Plan

**Status:** REVISING — first attempt failed (code reverted 2026-06-25), plan under revision
**Created:** 2026-06-23 | **Revised:** 2026-06-25
**Brief:** [docs/briefs/RADAR-PROVIDER-REPLACEMENT.md](docs/briefs/RADAR-PROVIDER-REPLACEMENT.md)
**Governs:** PROVIDER-MANUAL.md §7, API-MANUAL.md, DASHBOARD-MANUAL.md, DESIGN-MANUAL.md, OPERATIONS-MANUAL.md, ARCHITECTURE.md
**Research dependency:** Dashboard Phases 3-4 are BLOCKED until the WMS-T rendering research is complete. See [RADAR-WMS-RESEARCH-PLAN.md](RADAR-WMS-RESEARCH-PLAN.md).

---

## Context

RainViewer gutted its free API tier on 2026-01-01: zoom capped at 7, no nowcast, single color scheme, PNG only. The radar card is nearly useless for local weather awareness. Aeris radar is unviable at the PWS contributor tier (3,000 map units/day, ToS gray area on caching).

This plan replaces the radar provider set with two complementary paths:
- **LibreWxR** — global default, RainViewer v2 API drop-in, 13 color schemes, zoom 12, WebP, 6-frame nowcast, configurable frame retention (`LIBREWXR_MAX_FRAMES`). Operator configures their LibreWxR endpoint (public API or self-hosted); tiles proxied through the Clear Skies API (API is the gateway, not browser-direct).
- **NOAA unified** — US-only, IEM NEXRAD (CONUS) + NOAA MRMS (AK/HI/PR/Guam) as two seamless radar sub-layers, plus GOES satellite (5 bands), SPC severe weather overlays, and alert polygons. All free government WMS-T endpoints — browser fetches WMS tiles directly.

**Scope boundary:** This plan adds two new providers (librewxr, noaa) and adjusts the existing provider set accordingly (demote RainViewer, drop Aeris from radar). It does NOT add existing regional providers (dwd_radolan, msc_geomet) to the wizard — those modules exist in the API from the original radar domain work but are not part of this plan's scope.

The plan also adds an expand-to-fullscreen mode for the radar card — visitors tap an expand button on the Now page card to open a full-viewport overlay with layer toggles, time slider, color scheme picker, and provider-adaptive controls. The overlay pushes `/radar` to browser history for bookmarkability.

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
- API WMS parser: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/_common/wms_capabilities.py`
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

4. **One agent per task (or per tightly-coupled task group).** Don't give one agent all of Phase 1. Give it T1.1, verify, then give T1.2. Exceptions: tightly-coupled tasks that share state (e.g., T1.2 + T1.4 both modify `noaa.py`) can be assigned together.

---

## 1. Design Decisions (Settled)

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Full-screen approach | Expand-to-fullscreen overlay from radar card | No ADR-024 amendment needed (no new page). Discoverable. `/radar` pushed to history for bookmarks. |
| NOAA module structure | Unified `noaa` module, IEM NEXRAD + MRMS as two radar sub-layers | Both are NOAA WMS-T sources with complementary geographic coverage (CONUS + AK/HI/PR/Guam). One wizard entry, not two. |
| LibreWxR frame count | Configurable via `LIBREWXR_MAX_FRAMES` env var (default 12, recommend 24+ for self-hosted) | Self-hosted operators can get 4+ hours of history for smooth animation. Public API users get ~2 hours. |
| Card appearance | Minimal — current controls + expand button. Rich features in expanded view only. | Keep Now page card clean; expanded view is the "dive deeper" path. |
| RainViewer status | Demoted — available but degraded. Wizard notes limitations. | Still functional at zoom 7 for operators who want it. |
| Aeris radar status | Dropped from radar domain. Remains for forecast/AQI/alerts. | 3,000 map units/day is unviable for radar tiles. |

---

## 2. Implementation Phases

### PHASE 0 — Foundation (ADR + Reference Docs + ALL Manual Updates)

> **Manuals before code.** The manuals are what dev agents consult. If the manuals are silent on what the agent is building, the agent has no guidance. ALL manual updates happen in Phase 0, before any code phase starts. Manuals may be amended later as implementation details surface, but the prescriptive rules must exist before the first line of code.

**T0.1 — Fetch and save LibreWxR API docs**
- Owner: Coordinator (Opus)
- Do: Fetch from librewxr.net/docs and save to `docs/reference/api-docs/librewxr.md` with capture date header. Include: configuration reference (env vars, frame counts), weather-maps.json response format, RainViewer migration guide, coverage documentation, tile URL patterns.
- Accept: File exists with "Captured: 2026-06-23" header. All env vars documented (`LIBREWXR_MAX_FRAMES`, `LIBREWXR_FETCH_INTERVAL`, `LIBREWXR_NOWCAST_FRAMES`, `LIBREWXR_SATELLITE_MAX_FRAMES`).

**T0.2 — Fetch and verify NOAA WMS endpoint capabilities**
- Owner: Coordinator (Opus)
- Do: Hit the three NOAA WMS GetCapabilities endpoints listed in the brief. Verify layer names, TIME dimension formats, and geographic extents. Save captured capabilities to `docs/reference/api-docs/noaa-wms-layers.md`. Verify IEM NEXRAD layer name (`nexrad-n0q-wmst`), nowCOAST satellite layer names, MRMS layer name.
- Accept: All WMS endpoints respond. Layer names confirmed. TIME dimension formats documented.

**T0.3 — Amend ADR-015 (decision record update)**
- Owner: Coordinator (Opus)
- File: `docs/archive/decisions/ADR-015-radar-map-tiles-strategy.md`
- Do: Add amendment section recording the changed decisions: LibreWxR replaces RainViewer as global default, unified NOAA module replaces separate iem_nexrad + noaa_mrms, RainViewer demoted, Aeris dropped from radar, expand-to-fullscreen model, LibreWxR tiles proxied through API.
- **Note:** This updates the ADR as a historical decision record. The ADR is NOT the source of truth for implementation — the manuals are. Agents follow manuals, not ADRs. The ADR records WHY decisions were made; the manuals say WHAT to build.
- Accept: ADR-015 amendment reflects the current decisions. No implementation work depends on this task.

**T0.4 — Update PROVIDER-MANUAL.md §7 (Radar)**
- Owner: Coordinator (Opus)
- File: `docs/PROVIDER-MANUAL.md`
- Do: Rewrite §7 Radar to reflect new provider set. This is the primary reference for `clearskies-api-dev`:
  - **Day-1 provider table**: add `librewxr` and `noaa`, mark `rainviewer` as degraded, remove `aeris` from radar, remove `iem_nexrad` and `noaa_mrms` (replaced by unified `noaa`)
  - **LibreWxR module rules**: configurable upstream (`[radar] librewxr_endpoint`, default `https://api.librewxr.net`), CC-BY-4.0 attribution, weather-maps.json wire format (RainViewer v2 compatible), tile URL template (`{host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth_snow}.webp`), WebP content type, tile proxy through API (not browser-direct), 60s frame cache / 300s tile cache
  - **NOAA unified module rules**: replaces `iem_nexrad` + `noaa_mrms`. Two radar sub-layers (NEXRAD via IEM WMS-T for CONUS, MRMS via NOAA MapServer WMS-T for AK/HI/PR/Guam). Multi-layer capability declaration with additional layers: GOES satellite (5 bands via nowCOAST WMS-T), SPC outlooks (mapservices GeoJSON), alert polygons (from existing `/api/v1/alerts`). Browser-direct for WMS layers (free government endpoints). Per-layer frame metadata endpoint.
  - **Proxied provider set**: rename concept from "keyed providers" to "proxied providers". LibreWxR is proxied (API is the gateway to external services). NOAA WMS layers are browser-direct (free government endpoints with no rate limits). RainViewer remains browser-direct (keyless, public CDN).
  - **Updated wizard suggestion table**: US → `noaa`, all other regions → `librewxr`
  - **Attribution requirements** per provider
- Accept: §7 is internally consistent, covers all provider modules. An api-dev agent reading only this section would know exactly what to build.

**T0.5 — Update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`
- Do:
  - Update radar endpoint description to note multi-layer capability for NOAA provider and per-layer frame metadata endpoint
  - Add LibreWxR to the tile proxy description (proxied through API, not browser-direct)
  - Note `/radar` route for expanded radar view (dashboard-side SPA route, no Caddy change — `try_files` fallback handles it)
  - Document that LibreWxR is an external service the API communicates with — no Caddy route, no container in our inventory
  - Clarify the proxy model: Caddy → API only. API → external services (LibreWxR, RainViewer, Aeris, etc.). Browser → government WMS endpoints directly (NOAA, IEM, MSC, DWD).
- Accept: Architecture doc reflects new endpoint capabilities and proxy model. No incorrect Caddy or container references.

**T0.6 — Update API-MANUAL.md (radar endpoints + capability model)**
- Owner: Coordinator (Opus)
- File: `docs/API-MANUAL.md`
- Do: Add/update sections that guide `clearskies-api-dev`:
  - **Capability model extension**: describe the `layers` list on `ProviderCapability` — fields per layer (`layer_id`, `layer_name`, `layer_type`, `wms_endpoint_url`/`tile_url_template`, `wms_layer_name`, `time_enabled`, `geographic_coverage`, `default_enabled`, `browser_direct`). Optional — single-layer providers unchanged.
  - **New endpoint**: `GET /api/v1/radar/providers/{id}/layers/{layer_id}/frames` — per-layer frame metadata for multi-layer providers (NOAA satellite, NOAA MRMS sub-layer)
  - **Tile proxy expansion**: `GET /radar/providers/{provider_id}/tiles/{z}/{x}/{y}` now serves LibreWxR in addition to keyed providers. Rename internal set from `_KEYED_RADAR_PROVIDERS` to `_PROXIED_RADAR_PROVIDERS`. Add query parameters: `?t=` (frame timestamp), `?color=` (color scheme, LibreWxR only).
  - **LibreWxR config**: `[radar] librewxr_endpoint` field in `api.conf`, default `https://api.librewxr.net`
  - **Deprecated providers**: `iem_nexrad` and `noaa_mrms` log migration warning suggesting `noaa`. `aeris` removed from radar domain.
- Accept: An api-dev agent reading the API-MANUAL would know the exact endpoint shapes, config fields, and capability model changes to implement.

**T0.7 — Update DASHBOARD-MANUAL.md (radar card + expanded view)**
- Owner: Coordinator (Opus)
- File: `docs/DASHBOARD-MANUAL.md`
- Do: Add/update sections that guide `clearskies-dashboard-dev` on WHAT the dashboard does (features, UI behavior, a11y). This is a two-pass task:
  - **Pass 1 (Phase 0):** Document the feature set — expand button, expanded view overlay, time slider, layer panel, color scheme picker, opacity, provider-adaptive behavior, SPC/alert overlays, accessibility. Document everything EXCEPT the WMS-T rendering approach.
  - **Pass 2 (after research):** Once the WMS-T rendering ADR is accepted, add the rendering rules — library to use, animation pattern, component architecture, dual-layer sync. This is deliverable D4 from the research plan.
- Feature set to document in Pass 1:
  - Radar card: expand button (Phosphor `ArrowsOut`), adaptive animation speed, nowcast distinction, provider-adaptive legend, attribution
  - Expanded view (`/radar`): full-viewport overlay, close button + Escape, focus trap, `/radar` route
  - Time slider: scrubable, play/pause, speed control, nowcast visual distinction
  - Layer panel: sidebar desktop / bottom sheet mobile, populated from capability `layers`, localStorage persistence
  - Color scheme picker: LibreWxR only (13 schemes), hidden for NOAA/RainViewer
  - Opacity slider: 0-100%, default 70%
  - Layer z-order: base map → satellite → radar → SPC → alerts
  - SPC overlays: GeoJSON, auto-refresh 5 min, NOT time-animated
  - Alert polygons: from existing `/api/v1/alerts`, severity-colored, auto-refresh 5 min
  - WCAG 2.1 AA: focus trap, keyboard nav, aria-live, prefers-reduced-motion
- Do NOT prescribe the WMS-T rendering approach in Pass 1. That comes from the research.
- Accept (Pass 1): Dashboard-dev agent knows what features to build, what UI components exist, and what the a11y requirements are. WMS-T rendering approach is explicitly marked TBD.
- Accept (Pass 2): Dashboard-dev agent also knows HOW to render WMS-T layers — library, pattern, component architecture. All blocked tasks can proceed.

**T0.8 — Update DESIGN-MANUAL.md (radar card + expanded view design spec)**
- Owner: Coordinator (Opus)
- File: `docs/DESIGN-MANUAL.md`
- Do: Add radar design specifications:
  - **Radar card**: expand button placement (card header or map top-right corner), legend gradient anatomy (adapts to provider color scheme), attribution line placement, nowcast indicator on frame counter
  - **Expanded radar overlay**: layout spec (full viewport, controls overlay the map). Time slider anatomy (bottom bar, scrub track, play button left, speed control right, current timestamp center). Layer panel anatomy (sidebar width, section headers by layer type, checkbox + label + badge per layer, collapse/expand toggle). Color scheme picker anatomy (grid or dropdown, swatch preview). Opacity slider anatomy. Close button placement (top-right, above layer panel).
  - **Mobile breakpoints**: layer panel as bottom sheet (drag handle, half-height default, full-height on drag up). Time slider simplified (play/pause + scrub, no speed control on small screens). All touch-friendly tap targets (≥44px).
  - **Dark/light theme**: base map switches (OSM ↔ CartoDB dark). Controls use theme tokens. Layer panel background matches theme.
  - **Z-order tokens**: define stacking order for overlay controls over the Leaflet map.
- Accept: A dashboard-dev agent reading the design manual would know the visual layout, component anatomy, and responsive behavior.

**T0.9 — Update OPERATIONS-MANUAL.md (LibreWxR configuration)**
- Owner: Coordinator (Opus)
- File: `docs/OPERATIONS-MANUAL.md`
- Do: Add LibreWxR configuration section:
  - Explain the two modes: public API (`api.librewxr.net`, no infrastructure) vs self-hosted (operator's responsibility)
  - Document the `[radar] librewxr_endpoint` config field
  - Note that self-hosted operators must ensure their LibreWxR instance is reachable by the Clear Skies API. Visitors' browsers never contact LibreWxR directly — tiles are proxied through the API.
  - Recommend `LIBREWXR_MAX_FRAMES=24+` for smoother animation (operator sets this on their own instance)
  - Link to LibreWxR's own documentation for self-hosting setup
  - Do NOT provide Docker compose snippets, Caddyfile routes, or any other LibreWxR infrastructure config
- Accept: Ops manual covers both modes without providing LibreWxR infrastructure.

**QC (Opus) — after Phase 0:** Comprehensive manual review:
1. PROVIDER-MANUAL §7 — an api-dev agent could build both provider modules from this section alone
2. API-MANUAL — endpoint shapes, capability model, config fields all specified
3. DASHBOARD-MANUAL — card upgrades + expanded view described (rendering approach TBD pending research)
4. DESIGN-MANUAL — visual layout, component anatomy, responsive behavior specified
5. ARCHITECTURE.md — proxy model correct, no stale Caddy/container references
6. OPERATIONS-MANUAL — LibreWxR config documented
7. Reference docs (T0.1, T0.2) have capture-date headers
8. Cross-check: no manual contradicts another manual

---

### PHASE 1 — API: Provider Modules + Capability Model

**T1.1 — LibreWxR provider module (metadata + tile proxy)**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/radar/librewxr.py`
- Do: Build provider module following the `rainviewer.py` pattern (API-compatible wire format) with **tile proxying** — the API is the gateway to LibreWxR, same as all external services. Key points:
  - `BASE_URL` configurable: defaults to `https://api.librewxr.net`, overridable via `[radar] librewxr_endpoint` in `api.conf`
  - **`get_frames()`** — fetches `{endpoint}/public/weather-maps.json`, returns canonical `RadarFrameList`. Same wire model and frame-kind mapping as RainViewer (max past → current, nowcast preserved).
  - **`get_tile(z, x, y, *, t=None)`** — fetches tile bytes from LibreWxR upstream, returns `(bytes, content_type)`. URL composed from `tileHost` + frame `path` + tile coordinates + color scheme + options. Tile cache: base64-encoded envelope, TTL 300s (same pattern as Aeris/OWM tile proxy).
  - Tile URL uses WebP format (`.webp` extension, `image/webp` content type)
  - Color scheme parameter stored in config (default: NEXRAD Level III scheme "2")
  - Attribution: `"LibreWxR (https://librewxr.net/) — Data: CC-BY-4.0"`
  - Rate limiter: polite-use guard (5 req/s)
  - Cache TTL: 60s for frame metadata, 300s for tiles
- Accept: Module passes `ruff check` + `mypy`. Frame metadata fetch works against `api.librewxr.net`. Tile proxy returns WebP bytes. CAPABILITY declared correctly.

**T1.2 — Unified NOAA provider module (radar layers)**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/providers/radar/noaa.py`
- Do: Build unified provider module that combines IEM NEXRAD + NOAA MRMS functionality:
  - Two radar sub-layers: `nexrad` (IEM WMS-T, CONUS) and `mrms` (NOAA MapServer WMS-T, AK/HI/PR/Guam)
  - `get_frames()` returns frames from IEM NEXRAD (primary, CONUS)
  - `get_frames(layer="mrms")` returns frames from NOAA MRMS
  - Reuse existing `parse_wms_time_dimension()` for both
  - Declare multi-layer capability (see T1.3)
  - Attribution: `"NEXRAD imagery courtesy of Iowa Environmental Mesonet. MRMS data courtesy of NOAA."`
  - No API key required
  - Rate limiter: polite-use guard
  - Cache TTL: 60s per sub-layer
- Accept: Module passes `ruff check` + `mypy`. Frame metadata works for both IEM and MRMS endpoints. Both sub-layers declared in capability.

**T1.3 — Extend capability model for multi-layer providers**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `providers/_common/capability.py`, `models/responses.py`, `endpoints/radar.py`
- Do: Extend `ProviderCapability` to support a `layers` list for providers that offer multiple data layers. Each layer declares:
  - `layer_id` (string, e.g., "nexrad", "mrms", "goes_ir", "spc_outlooks")
  - `layer_name` (display name)
  - `layer_type` (enum: "radar", "satellite", "overlay", "alerts")
  - `wms_endpoint_url` or `tile_url_template`
  - `wms_layer_name` (for WMS layers)
  - `time_enabled` (bool — controls whether frame metadata is available)
  - `geographic_coverage` (string)
  - `default_enabled` (bool — whether this layer is on by default)
  - `browser_direct` (bool — whether the browser fetches tiles directly vs API proxy)
  
  Update `/api/v1/capabilities` response to include layers when present. Single-layer providers (LibreWxR, RainViewer, etc.) continue working unchanged — `layers` is optional.
  
  Add endpoint: `GET /api/v1/radar/providers/{id}/layers/{layer_id}/frames` for fetching frame metadata per sub-layer.
- Accept: Existing single-layer providers still work. NOAA provider declares multiple layers in capabilities response. New frames endpoint works per sub-layer. `ruff check` + `mypy` pass.

**T1.4 — NOAA satellite + SPC + alert layer declarations**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `providers/radar/noaa.py` (extend from T1.2)
- Do: Add layer declarations for non-radar NOAA data:
  - **Satellite layers** (5 GOES bands from nowCOAST WMS-T): Visible, Longwave IR, Shortwave IR, Water Vapor, Snow/Ice. All browser-direct, time-enabled.
  - **SPC layers** (from mapservices): Day 1-3 categorical outlooks, tornado/hail/wind probabilities, mesoscale discussions, fire weather. Browser-direct, NOT time-enabled (current snapshot only).
  - **Alert polygons**: Use existing `/api/v1/alerts` data (no new endpoint needed). Layer declaration points dashboard to render alert polygons from existing alerts response.
  - All satellite/SPC/alert layers are browser-direct (free government endpoints, no proxy needed). The API only declares their availability and endpoint URLs.
  - For satellite layers: add frame metadata endpoint that fetches nowCOAST WMS-T GetCapabilities and extracts TIME dimension.
- Accept: All layers declared in capability. Satellite frame metadata endpoint returns valid time steps. SPC layer declarations include correct mapservices URLs. `ruff check` + `mypy` pass.

**T1.5 — Provider set changes (config, dispatch, demote/drop)**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `config/settings.py` (RadarSettings), `providers/_common/dispatch.py`, `endpoints/radar.py`, `__main__.py`
- Do:
  - Add `librewxr` and `noaa` to `RadarSettings` valid provider choices
  - Add `librewxr_endpoint` optional config field (default `https://api.librewxr.net`)
  - Add `librewxr` and `noaa` to `PROVIDER_MODULES` dispatch table
  - Update `_KNOWN_RADAR_PROVIDERS` in radar endpoint. Rename `_KEYED_RADAR_PROVIDERS` → `_PROXIED_RADAR_PROVIDERS` and add `librewxr` (proxy is now about API-as-gateway, not just key protection). LibreWxR tiles are proxied through `GET /radar/providers/librewxr/tiles/{z}/{x}/{y}` just like Aeris/OWM.
  - Add degradation note to `rainviewer` CAPABILITY `operator_notes` ("Zoom capped at 7, no nowcast, single color scheme since 2026-01-01")
  - Remove `aeris` from `_KEYED_RADAR_PROVIDERS` for radar domain (keep for forecast/AQI/alerts). Remove Aeris radar capability wiring from `_wire_providers_from_config`. Remove Aeris credential wiring from `wire_radar_settings` (Aeris credentials still wired for forecast).
  - Keep `iem_nexrad` and `noaa_mrms` modules on disk but mark as deprecated in their docstrings (operators with existing config referencing them should get a log warning suggesting migration to `noaa`)
  - Update `api.conf.example` with new provider options and comments
- Accept: `api.conf` accepts `provider = librewxr` and `provider = noaa`. Deprecated providers log migration warning. Aeris no longer appears as a radar provider. `ruff check` + `mypy` pass.

**QC (Opus) — after Phase 1:** Verify LibreWxR module fetches frames from public API. Verify NOAA module fetches frames from both IEM and MRMS endpoints. Capability response includes layers for NOAA. Config accepts new providers. Aeris removed from radar. Deprecated modules log warnings. All linting passes.

---

### PHASE 2 — Config UI: Wizard + Admin

**T2.1 — Add LibreWxR + NOAA to provider registry**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/providers.py`
- Do: Add `ProviderInfo` entries:
  - `librewxr`: domain "radar", coverage "Global", no auth fields, keyless, test URL `https://api.librewxr.net/public/weather-maps.json`
  - `noaa`: domain "radar", coverage "US (all territories)", no auth fields, keyless, test URL IEM NEXRAD GetCapabilities
  - Add display notes: LibreWxR = "Global radar, satellite, nowcast. Self-host recommended for production." NOAA = "US only. Full experience: radar + satellite + SPC severe weather + alerts."
- Accept: Both providers appear in wizard step 6. Provider info renders correctly.

**T2.2 — Update recommendation logic**
- Owner: `clearskies-stack-dev` (Sonnet)
- File: `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/providers.py`
- Do: Update `recommend_providers(latitude, longitude)` for radar domain:
  - US (lat 24-50, lon -125 to -66) → `noaa`
  - All other → `librewxr`
- Do NOT add region-specific entries for Canada, Germany, Japan, or Europe. Existing providers (msc_geomet, dwd_radolan) remain available in the API for operators who configure them manually, but this plan does not promote them in the wizard.
- Accept: US locations get `noaa` suggested. All other locations get `librewxr`. No other radar providers appear in recommendations.

**T2.3 — LibreWxR endpoint configuration**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `wizard/state.py`, `templates/wizard/step_providers.html`, `wizard/routes.py`
- Do: When operator selects `librewxr`, show an additional field:
  - "LibreWxR endpoint" radio: "Public API (api.librewxr.net)" vs "Self-hosted (enter URL)"
  - If self-hosted: URL input field (no default — operator must provide their own reachable URL)
  - Note text: "Public API: no infrastructure needed, no SLA. Self-hosted: you are responsible for deploying and maintaining your own LibreWxR instance. The endpoint must be reachable by the Clear Skies API. See LibreWxR docs for self-hosting setup. Recommend LIBREWXR_MAX_FRAMES=24+ for smoother animation."
  - Store in `state.providers_config["librewxr_endpoint"]`, write to `api.conf [radar] librewxr_endpoint`
- Accept: Endpoint config renders, saves to state, writes to api.conf. Round-trip works on re-run.

**T2.4 — Update Aeris radar removal + RainViewer degradation note**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `wizard/providers.py`, `templates/wizard/step_providers.html`, `templates/config/provider_section.html`
- Do:
  - Remove `aeris` from radar provider options in both wizard and admin (keep for forecast/AQI/alerts)
  - Add degradation note to `rainviewer` display: "Limited: zoom 7 max, no nowcast, single color scheme (since Jan 2026)"
  - Update admin provider section template's hardcoded radar provider list
- Accept: Aeris not shown for radar. RainViewer shows degradation note. Admin matches wizard.

**T2.5 — Review page + apply handler updates**
- Owner: `clearskies-stack-dev` (Sonnet)
- Files: `wizard/routes.py`, `templates/wizard/step_review.html`
- Do: Review page shows radar provider + endpoint config (if LibreWxR). Apply handler writes `librewxr_endpoint` to api.conf when applicable. Merge logic reads it back on re-run.
- Accept: Full wizard round-trip works for all new radar providers.

**QC (Opus) — after Phase 2:** Walk full wizard flow: select NOAA for US → review → apply → verify api.conf. Re-run: select LibreWxR self-hosted → configure endpoint → review → apply → verify api.conf has `librewxr_endpoint`. RainViewer shows degradation note. Aeris absent from radar. Admin provider section updated.

---

### PHASE 3 — Dashboard: Radar Card Upgrades

> **BLOCKED — pending WMS-T rendering research.** The first attempt at this phase failed because the implementation agent did not understand WMS-T animation in Leaflet. Phases 3-4 cannot proceed until the research session (see [RADAR-WMS-RESEARCH-PLAN.md](RADAR-WMS-RESEARCH-PLAN.md)) establishes the correct rendering approach. The research output will provide the specific implementation guidance (library choice, animation pattern, component architecture) that these task descriptions currently lack.
>
> **What went wrong (2026-06-25):** The agent treated WMS tiles like CDN XYZ tiles — pre-rendering every frame as a separate TileLayer (300 frames × 2 layers = 600 simultaneous WMS server-side render requests). 10 consecutive fix commits failed to correct the fundamental architecture. The correct WMS-T animation pattern (single layer, TIME parameter swap per frame) was never attempted. See commit history `91a5524..79b82f6` in the dashboard repo for the full failure sequence.

**T3.1 — LibreWxR tile support (via API proxy)**
- LibreWxR tiles fetched through the API proxy (browser never calls LibreWxR directly)
- Nowcast frames visually distinguished
- Color scheme passed as query parameter
- **Implementation approach:** LibreWxR uses XYZ tiles (same as RainViewer) — existing animation pattern applies. No WMS-T involvement. This task is NOT blocked by research.

**T3.2 — NOAA dual-layer WMS-T rendering**
- Two WMS-T layers (NEXRAD CONUS + MRMS non-CONUS) animated in sync
- Frame metadata per sub-layer from API
- **Implementation approach:** TBD — pending research. The research session must establish: which library/pattern to use for WMS-T TIME animation in react-leaflet, how to handle dual-layer sync, preload strategy, and frame count management.

**T3.3 — Provider-adaptive legend + attribution**
- Legend adapts to active color scheme (not hardcoded to RainViewer Universal Blue)
- Attribution from capability response
- This task is NOT blocked by research.

**T3.4 — Expand-to-fullscreen button**
- Phosphor `ArrowsOut` icon, navigates to `/radar`
- This task is NOT blocked by research.

**T3.5 — Animation defaults for higher frame counts**
- Adaptive animation speed for NOAA's 300-frame set (target ~15-20s loop in card view)
- Card view caps at ~24 most recent frames
- **Implementation approach:** Partially blocked — adaptive speed for XYZ providers is straightforward, but WMS-T animation timing depends on the rendering pattern chosen in research.

**QC (Opus) — after Phase 3:** Visual verification with LibreWxR (color, zoom 12, nowcast). Visual verification with NOAA (dual-layer WMS-T). Expand button. Legend. Attribution. `tsc --noEmit` + `vite build` clean. axe-core 0 violations.

---

### PHASE 4 — Dashboard: Expanded Radar View

> **BLOCKED — same research dependency as Phase 3.** The expanded view adds controls (time slider, layer panel) that drive the WMS-T animation established in Phase 3. The UI components themselves (overlay, slider, panel) are not blocked, but wiring them to WMS-T layer animation is.

**T4.1 — Full-viewport overlay component**
- Full-viewport overlay (100vw × 100vh), `/radar` route, close button + Escape, focus trap
- NOT blocked by research — this is standard React/a11y work.

**T4.2 — Enhanced time slider + animation controls**
- Horizontal scrubable slider, play/pause, speed control, nowcast distinction
- **Partially blocked:** slider UI is standard, but driving WMS-T frame changes depends on the rendering pattern from research.

**T4.3 — Layer panel (collapsible, provider-adaptive)**
- Sidebar (desktop) / bottom sheet (mobile), populated from capability `layers`, localStorage persistence
- NOT blocked by research — this is UI driven by capability data.

**T4.4 — Color scheme picker (LibreWxR only)**
- 13 schemes, updates tile URL `color` parameter + legend. Hidden for NOAA/RainViewer.
- NOT blocked by research.

**T4.5 — Opacity control**
- 0-100% slider, default 70%, affects all radar tile layers.
- NOT blocked by research.

**T4.6 — NOAA satellite layer rendering**
- WMS-T satellite layers animated alongside radar, z-order below radar
- **BLOCKED by research** — same WMS-T rendering pattern as radar.

**T4.7 — NOAA SPC overlay rendering**
- GeoJSON from mapservices, stroke/fill from properties, auto-refresh 5 min, NOT time-animated
- NOT blocked by research — standard Leaflet GeoJSON.

**T4.8 — NOAA alert polygon overlay**
- From existing `/api/v1/alerts`, severity-colored, auto-refresh 5 min
- NOT blocked by research — standard Leaflet GeoJSON.

**T4.9 — WCAG accessibility audit**
- Focus trap, keyboard nav, aria-live, prefers-reduced-motion, axe-core 0 violations
- NOT blocked by research.

**QC (Opus) — after Phase 4:** Full expanded view walkthrough (same 11-point checklist as before, detailed acceptance criteria to be finalized after research establishes the rendering approach).

---

### PHASE 5 — Deploy + Final Verification

**T5.1 — Deploy API**
- Owner: Coordinator (Opus)
- Do: `ruff check` + `mypy` clean. Restart API on weewx. Verify `/api/v1/capabilities` shows new providers. Verify `/api/v1/radar/providers/noaa/frames` returns IEM NEXRAD frame list. Verify `/api/v1/radar/providers/librewxr/frames` returns LibreWxR frame list.
- Accept: API serves new provider data. Cache warm completes. No errors in logs.

**T5.2 — Deploy dashboard**
- Owner: Coordinator (Opus)
- Do: `tsc --noEmit` + `npm run build` clean. Deploy via `scripts/redeploy-weather-dev.sh`.
- Accept: Radar card renders with configured provider. Expand button works. Expanded view renders.

**T5.3 — Deploy wizard**
- Owner: Coordinator (Opus)
- Do: Restart config service. Walk full wizard flow.
- Accept: NOAA and LibreWxR appear in radar provider selection. Recommendation logic correct. Apply writes correct config.

**T5.4 — End-to-end verification**
- Owner: Coordinator (Opus)
- Do:
  - Switch to NOAA provider via wizard → verify dual-layer radar, satellite toggle, SPC overlay, alert polygons in expanded view
  - Switch to LibreWxR → verify color scheme picker, nowcast frames, zoom 12
  - Switch to RainViewer → verify degraded experience with limitation note
  - Verify `/radar` bookmark works (direct navigation)
  - Mobile: all controls accessible, bottom sheet layer panel
  - Performance: no jank with 48+ frame NOAA animation
- Accept: All providers render correctly. Expanded view fully functional. No regressions on other pages.

**Final QC (Opus):** Walk every acceptance criterion. Verify code against all manuals (written in Phase 0):
- PROVIDER-MANUAL §7 (module rules, proxy rules, attribution)
- API-MANUAL (endpoint shapes, capability model, tile proxy)
- ARCHITECTURE.md (proxy model, endpoint descriptions)
- DASHBOARD-MANUAL (radar card, expanded view, layer panel, animation)
- DESIGN-MANUAL (component specs, layout, responsive behavior)
- OPERATIONS-MANUAL (LibreWxR configuration)
- WCAG AA compliance on all new UI
- Flag any manual drift (implementation deviated from what Phase 0 prescribed) → amend manual before closing.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing | Status |
|-------|------|-------|-------|-----------|--------|
| 0 | T0.1-T0.2 Reference doc capture | Coordinator | Opus | After Phase 0 | Not started |
| 0 | T0.3 ADR-015 amendment (decision record) | Coordinator | Opus | After Phase 0 | Not started |
| 0 | T0.4-T0.9 ALL manual updates | Coordinator | Opus | After Phase 0 | Not started |
| 1 | T1.1 LibreWxR module (metadata + tiles) | `clearskies-api-dev` | Sonnet | After Phase 1 | Not started |
| 1 | T1.2 NOAA unified module | `clearskies-api-dev` | Sonnet | After Phase 1 | Not started |
| 1 | T1.3 Capability model extension | `clearskies-api-dev` | Sonnet | After Phase 1 | Not started |
| 1 | T1.4 NOAA satellite/SPC/alert layers | `clearskies-api-dev` | Sonnet | After Phase 1 | Not started |
| 1 | T1.5 Provider set changes | `clearskies-api-dev` | Sonnet | After Phase 1 | Not started |
| 2 | T2.1-T2.5 Wizard + admin (librewxr + noaa ONLY) | `clearskies-stack-dev` | Sonnet | After Phase 2 | Not started |
| R | WMS-T rendering research | Separate session | — | Before Phase 3 | **BLOCKING** |
| 3 | T3.1-T3.5 Radar card upgrades | `clearskies-dashboard-dev` | Sonnet | After Phase 3 | Blocked by R |
| 4 | T4.1-T4.9 Expanded radar view | `clearskies-dashboard-dev` | Sonnet | After Phase 4 | Blocked by R |
| 5 | Deploy + verify | Coordinator | Opus | After Phase 5 | Not started |

**Sequencing:**
- Phase 0 (ADR + ALL manuals + reference docs) → blocks everything. Agents cannot start code without updated manuals.
- Phase 1 (API modules) → blocks Phase 2 (wizard) and Phase 3 (dashboard card)
- Phase 2 (wizard) → depends on Phase 1 (needs provider IDs and config fields)
- Phase 3 (dashboard card) → depends on Phase 1 (needs capability model + frame endpoints)
- Phase 4 (expanded view) → depends on Phase 3 (card provides the expand entry point)
- Phase 5 (deploy) → depends on all prior phases

**Parallelism opportunities:**
- Phase 2 + Phase 3 can run in parallel after Phase 1 completes (wizard and dashboard are independent repos)

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- API: `ruff check` + `mypy` no introduced errors.
- Dashboard: `tsc --noEmit` 0 errors. `vite build` clean.
- Wizard: `python -m py_compile <file>` passes. Templates render without Jinja2 errors.

### Gate 2 — Feature Correctness (per phase)
- Phase 1: API endpoints return valid frame data for LibreWxR + NOAA. Capability model includes layers. Tile proxy returns LibreWxR WebP bytes.
- Phase 2: Wizard round-trip for all new providers (select → review → apply → re-run → verify pre-fill).
- Phase 3: Radar card renders with all provider types. Expand button navigates. Animation smooth.
- Phase 4: Expanded view functional test (10-point checklist in Phase 4 QC above).

### Gate 3 — Manual Compliance (after Phase 5)
- PROVIDER-MANUAL §7: All module rules followed. Attribution correct.
- ARCHITECTURE.md: Endpoint descriptions current. No incorrect Caddy/container references for LibreWxR.
- DASHBOARD-MANUAL: Radar card + expanded view described.
- DESIGN-MANUAL: Component specs present.
- OPERATIONS-MANUAL: LibreWxR deployment documented.
- All manuals were written in Phase 0 before code; verify no drift during implementation.

### Gate 4 — Accessibility (after Phase 4 + Phase 5)
- Expanded view: `role="dialog"`, `aria-modal`, focus trap, Escape closes.
- All new controls: keyboard navigable, labeled, sufficient contrast.
- Time slider: arrow keys, value announcements.
- `prefers-reduced-motion` respected.
- axe-core 0 violations on radar card + expanded view.

---

## 5. Out of Scope (Explicit Deferrals)

| Feature | Why Deferred |
|---------|-------------|
| Client-side satellite colorization (enhanced IR) | Brief open question #2 — grayscale acceptable for v0.1 |
| LibreWxR Docker image build from source | Operators pull the upstream image; we don't maintain our own |
| Aeris compliance audit (branding/attribution for non-radar) | Brief §Aeris compliance note — separate task |
| Marine weather overlays | ADR-024 deferred (no provider in day-1 set) |
| Wind arrows overlay (LibreWxR) | Lower priority; can be added as a layer in a follow-up |
| Custom page embedding of expanded radar | v2 card plugin scope |

---

## 6. Self-Audit

**Risk: LibreWxR API compatibility.** LibreWxR claims RainViewer v2 API compatibility. The provider module is built on this assumption. If the wire format diverges, the module needs adjustment. Mitigation: T0.1 captures the actual API docs; T1.1 tests against the live public API.

**Risk: NOAA WMS endpoint stability.** Government WMS endpoints change layer names occasionally. Mitigation: T0.2 captures current capabilities; the WMS parser handles namespace variations; the module logs clear errors on layer-not-found.

**Risk: Multi-layer capability model complexity.** Extending `ProviderCapability` with a `layers` list is an API contract change. Mitigation: `layers` is optional — existing single-layer providers are unaffected. Dashboard gracefully handles providers with or without layers.

**Risk: Expanded view performance with many layers.** Multiple WMS layers + time animation + GeoJSON overlays on one Leaflet map. Mitigation: layers are toggled independently (not all active simultaneously); GeoJSON auto-refresh is 5-min (not continuous); frame count limited in card view.

**Risk: Frame count disparity between providers.** NOAA gives 300 frames, LibreWxR gives ~12, RainViewer gives ~13. The animation system needs adaptive speed to feel consistent. Mitigation: T3.5 implements adaptive animation (target ~15-20s loop regardless of frame count).

**Risk: Self-hosted LibreWxR reachability.** The operator's LibreWxR instance only needs to be reachable by the Clear Skies API (not by visitors' browsers), since tiles are proxied through the API. This simplifies self-hosting — the operator can run LibreWxR on an internal network as long as the API can reach it. The tradeoff is that tile traffic flows through the API, adding load. Mitigation: tile cache (300s TTL) reduces upstream calls; the API already handles tile proxying for Aeris/OWM at similar scale.

**Architecture boundary: Caddy never calls external services.** Caddy only talks to the Clear Skies API. LibreWxR (like all external services) is accessed by the API for metadata; tiles are proxied through the API to the browser. No Caddy routes, no Docker compose services, no infrastructure config for LibreWxR in our codebase.

**RISK (REALIZED): WMS-T rendering in Leaflet.** The first implementation attempt (2026-06-24) failed because the dashboard agent did not understand how WMS-T animation works. It treated WMS tiles like CDN XYZ tiles (pre-rendering every frame as a separate TileLayer — 300 frames × 2 layers = 600 simultaneous server-side render requests). 10 consecutive fix commits failed to correct the fundamental architecture. The correct WMS-T pattern (single layer, TIME parameter swap per frame) was never implemented. **Mitigation:** A dedicated research session ([RADAR-WMS-RESEARCH-PLAN.md](RADAR-WMS-RESEARCH-PLAN.md)) must establish the correct rendering approach — including library choice (e.g., leaflet-timedimension), animation pattern, and a working proof-of-concept — before Phases 3-4 resume. The research output plugs directly into the dashboard task specifications.
