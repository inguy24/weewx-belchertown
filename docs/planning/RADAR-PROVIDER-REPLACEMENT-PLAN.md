# Radar Provider Replacement — Execution Plan

**Status:** APPROVED
**Created:** 2026-06-23
**Brief:** [docs/briefs/RADAR-PROVIDER-REPLACEMENT.md](docs/briefs/RADAR-PROVIDER-REPLACEMENT.md)
**Amends:** ADR-015 (radar/map tiles strategy), PROVIDER-MANUAL.md §7, ARCHITECTURE.md, DASHBOARD-MANUAL.md, DESIGN-MANUAL.md, OPERATIONS-MANUAL.md

---

## Context

RainViewer gutted its free API tier on 2026-01-01: zoom capped at 7, no nowcast, single color scheme, PNG only. The radar card is nearly useless for local weather awareness. Aeris radar is unviable at the PWS contributor tier (3,000 map units/day, ToS gray area on caching).

This plan replaces the radar provider set with two complementary paths:
- **LibreWxR** — global default, RainViewer v2 API drop-in, 13 color schemes, zoom 12, WebP, 6-frame nowcast, configurable frame retention (`LIBREWXR_MAX_FRAMES`). Operator configures their LibreWxR endpoint (public API or self-hosted); the Clear Skies API fetches metadata, the browser fetches tiles directly — same model as current RainViewer.
- **NOAA unified** — US-only, IEM NEXRAD (CONUS) + NOAA MRMS (AK/HI/PR/Guam) as two seamless radar sub-layers, plus GOES satellite (5 bands), SPC severe weather overlays, and alert polygons. All free government WMS endpoints — browser fetches directly.

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

**T0.3 — Amend ADR-015**
- Owner: Coordinator (Opus)
- File: `docs/archive/decisions/ADR-015-radar-map-tiles-strategy.md`
- Do: Add amendment section (2026-06-23) covering:
  - LibreWxR added as global default fallback (replaces RainViewer)
  - Unified NOAA module added (replaces `iem_nexrad` + `noaa_mrms`, adds satellite/SPC/alerts layers)
  - RainViewer demoted (zoom 7 cap, no nowcast, single color scheme)
  - Aeris dropped from radar domain (rate limit unviable; remains for forecast/AQI/alerts)
  - Expand-to-fullscreen model for radar card (not a new page)
  - LibreWxR tiles proxied through the API (API is the gateway, not Caddy)
  - Updated wizard suggestion table
- Accept: ADR-015 amendment is complete, internally consistent, references the brief.

**T0.4 — Update PROVIDER-MANUAL.md §7 (Radar)**
- Owner: Coordinator (Opus)
- File: `docs/PROVIDER-MANUAL.md`
- Do: Rewrite §7 Radar to reflect new provider set. This is the primary reference for `clearskies-api-dev`:
  - **Day-1 provider table**: add `librewxr` and `noaa`, mark `rainviewer` as degraded, remove `aeris` from radar, remove `iem_nexrad` and `noaa_mrms` (replaced by unified `noaa`)
  - **LibreWxR module rules**: configurable upstream (`[radar] librewxr_endpoint`, default `https://api.librewxr.net`), CC-BY-4.0 attribution, weather-maps.json wire format (RainViewer v2 compatible), tile URL template (`{host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth_snow}.webp`), WebP content type, tile proxy through API (not browser-direct), 60s frame cache / 300s tile cache
  - **NOAA unified module rules**: replaces `iem_nexrad` + `noaa_mrms`. Two radar sub-layers (NEXRAD via IEM WMS-T for CONUS, MRMS via NOAA MapServer WMS-T for AK/HI/PR/Guam). Multi-layer capability declaration with additional layers: GOES satellite (5 bands via nowCOAST WMS-T), SPC outlooks (mapservices GeoJSON), alert polygons (from existing `/api/v1/alerts`). Browser-direct for WMS layers (free government endpoints). Per-layer frame metadata endpoint.
  - **Proxied provider set**: rename concept from "keyed providers" to "proxied providers". LibreWxR is proxied (API is the gateway to external services). NOAA WMS layers are browser-direct (free government endpoints with no rate limits). RainViewer remains browser-direct (keyless, public CDN).
  - **Updated wizard suggestion table**: US → `noaa`, Canada → `msc_geomet`, Germany → `dwd_radolan`, Europe → `librewxr`, Japan → `librewxr`, global → `librewxr`
  - **Attribution requirements** per provider
- Accept: §7 is internally consistent, matches ADR-015 amendment, covers all provider modules. An api-dev agent reading only this section would know exactly what to build.

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
- Do: Add/update sections that guide `clearskies-dashboard-dev`:
  - **Radar card (Now page)**: update existing description. Add: expand-to-fullscreen button (Phosphor `ArrowsOut` icon, top-right), navigates to `/radar`. Adaptive animation speed (target ~15-20s loop regardless of frame count; cap card view at ~24 most recent frames for high-frame-count providers like NOAA). Nowcast frames visually distinguished on timeline. Provider-adaptive legend (color matches active scheme). Attribution from capability response. LibreWxR tiles fetched via API proxy; NOAA WMS tiles fetched browser-direct.
  - **NOAA dual-layer rendering**: when provider is `noaa`, render two WMS-T tile layers simultaneously (NEXRAD CONUS + MRMS non-CONUS). Both animate in sync. No overlap.
  - **Expanded radar view (`/radar`)**: full-viewport overlay (`role="dialog"`, `aria-modal`, focus trap, Escape closes). Reuses same Leaflet map + provider data. Components:
    - Time slider (horizontal, bottom, scrubable, play/pause, 0.5x/1x/2x speed, full history range, nowcast visually distinct)
    - Layer panel (collapsible sidebar desktop / bottom sheet mobile, populated from capability `layers`, grouped by type, checkbox toggles, persisted in localStorage)
    - Color scheme picker (LibreWxR only, 13 schemes, updates tiles + legend, persisted)
    - Opacity slider (0-100%, default 70%)
    - Close button (X, top-right) + Escape key
  - **Layer z-order**: base map → satellite → radar → SPC overlays → alert polygons
  - **Provider-adaptive features**: NOAA gets satellite bands + SPC + alerts in layer panel. LibreWxR gets color schemes + nowcast. RainViewer gets basic radar only (degraded).
  - **NOAA satellite**: WMS-T layers, time-animated alongside radar, grayscale acceptable for v0.1
  - **NOAA SPC overlays**: GeoJSON from mapservices, stroke/fill from properties, click for risk details, auto-refresh 5 min, NOT time-animated
  - **NOAA alert polygons**: from existing `/api/v1/alerts`, severity-colored, click for details, auto-refresh 5 min
  - **Accessibility**: all WCAG 2.1 AA requirements (focus trap, keyboard nav, `aria-live` for layer changes, `prefers-reduced-motion` pauses animation)
  - **Route**: `/radar` is a dashboard SPA route (no Caddy change). Direct navigation opens expanded view. Browser back returns to previous page.
- Accept: A dashboard-dev agent reading this section would know exactly what to build for both the card upgrades and the expanded view.

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
1. ADR-015 amendment is consistent with the brief
2. PROVIDER-MANUAL §7 — an api-dev agent could build both provider modules from this section alone
3. API-MANUAL — endpoint shapes, capability model, config fields all specified
4. DASHBOARD-MANUAL — card upgrades + expanded view fully described
5. DESIGN-MANUAL — visual layout, component anatomy, responsive behavior specified
6. ARCHITECTURE.md — proxy model correct, no stale Caddy/container references
7. OPERATIONS-MANUAL — LibreWxR config documented
8. Reference docs (T0.1, T0.2) have capture-date headers
9. Cross-check: no manual contradicts another manual or the ADR

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
  - Canada → `msc_geomet` (unchanged)
  - Germany → `dwd_radolan` (unchanged)
  - Europe (non-DE, lat 35-72, lon -25 to 45) → `librewxr`
  - Japan (lat 24-46, lon 122-146) → `librewxr`
  - All other → `librewxr`
- Accept: US locations get `noaa` suggested. European locations get `librewxr`. Global fallback is `librewxr`.

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

**T3.1 — LibreWxR tile support (via API proxy)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/shared/radar-map.tsx`, `src/lib/client.ts` (types)
- Do:
  - LibreWxR tiles are fetched through the API tile proxy (`/api/v1/radar/providers/librewxr/tiles/{z}/{x}/{y}?t={time}`), same as keyed providers — the browser never calls LibreWxR directly
  - Update `buildTileUrl()` to route LibreWxR through the API proxy endpoint (detect from capability that LibreWxR is a proxied provider)
  - Nowcast frames rendered with visual distinction (e.g., reduced opacity or dashed timeline marker in frame counter)
  - Color scheme selection passed as query parameter to the proxy endpoint (API forwards to LibreWxR)
- Accept: LibreWxR tiles render on the radar card via API proxy. Nowcast frames animate after current frame. `tsc --noEmit` passes.

**T3.2 — NOAA dual-layer WMS-T rendering**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/shared/radar-map.tsx`
- Do:
  - When provider is `noaa`, render two WMS-T tile layers simultaneously (NEXRAD + MRMS)
  - Each layer uses its own WMS endpoint URL and layer name from the capability response's `layers` array
  - Both layers animate in sync (same time slider position)
  - Layers tile seamlessly — NEXRAD covers CONUS, MRMS covers AK/HI/PR/Guam, no overlap
  - WMS `GetMap` request with TIME parameter for animation
  - Frame metadata fetched per sub-layer from `/api/v1/radar/providers/noaa/layers/{layer_id}/frames`
  - Use the larger frame set (NEXRAD, typically 300 frames capped) for the animation timeline; MRMS frames align to the same time window
- Accept: US radar shows CONUS + non-CONUS coverage. Animation smooth at 5-min cadence. `tsc --noEmit` passes.

**T3.3 — Provider-adaptive legend + attribution**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/shared/radar-map.tsx`
- Do:
  - Legend gradient adapts to provider color scheme (current hard-coded RainViewer "Universal Blue" gradient → dynamic based on selected color scheme)
  - For NOAA: use standard NWS reflectivity color scale
  - Attribution line in Leaflet attribution control shows provider-specific text from capability response
  - CC-BY-4.0 attribution for LibreWxR
- Accept: Legend matches active color scheme. Attribution correct per provider. Accessible (sufficient contrast per WCAG AA).

**T3.4 — Expand-to-fullscreen button**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `src/components/shared/radar-card.tsx`, `src/components/shared/radar-map.tsx`
- Do:
  - Add expand button (Phosphor `ArrowsOut` icon) in the card header or top-right corner of the map
  - Click navigates to `/radar` route (pushes to browser history)
  - Button has `aria-label="Expand radar to full screen"`
  - Mobile: same button, same behavior
- Accept: Button renders. Click navigates to `/radar`. `tsc --noEmit` passes. axe-core 0 violations on button.

**T3.5 — Animation defaults for higher frame counts**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-map.tsx`
- Do:
  - Current animation settings (SUBSTEPS=5, TICK_MS=100) work for 13 frames but would be slow for 48+ NOAA frames
  - Add adaptive animation speed: when frame count > 20, reduce TICK_MS or SUBSTEPS to maintain ~15-20 second total loop duration
  - Card view: limit displayed frames to most recent ~2 hours (cap at 24 frames for NOAA). Expanded view shows full history.
  - Frame counter shows relative time ("45 min ago", "Now", "+10 min") instead of absolute timestamps when frame count is high
- Accept: NOAA radar animates smoothly through ~24 frames in card view. Loop duration feels natural (~15-20s). Frame counter readable.

**QC (Opus) — after Phase 3:** Visual verification of radar card with LibreWxR tiles (color, zoom 12, nowcast). Visual verification with NOAA tiles (dual-layer, 5-min animation). Expand button navigates to `/radar`. Legend matches color scheme. Attribution correct. `tsc --noEmit` + `vite build` clean. axe-core 0 violations.

---

### PHASE 4 — Dashboard: Expanded Radar View

**T4.1 — Full-viewport overlay component**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: New `src/components/shared/radar-expanded.tsx`, modify `src/routes/app.tsx` (add `/radar` route)
- Do:
  - Full-viewport overlay (100vw × 100vh, z-index above nav)
  - Leaflet map fills entire viewport
  - Close button (X, top-right, `aria-label="Close expanded radar"`) + Escape key → navigates back
  - `/radar` route renders the expanded view directly (bookmarkable)
  - Navigating to `/radar` from anywhere opens expanded view; navigating back returns to previous page
  - Reuses same base map logic (theme-aware OSM/CartoDB) and same provider data fetching as radar card
  - Focus trap while overlay is open (`role="dialog"`, `aria-modal="true"`)
- Accept: Overlay renders full-viewport. Close returns to previous page. Direct navigation to `/radar` works. Keyboard accessible (Escape closes, focus trapped). axe-core 0 violations.

**T4.2 — Enhanced time slider + animation controls**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-expanded.tsx`
- Do:
  - Horizontal time slider at bottom of viewport (replaces card's simple prev/next)
  - Scrubable: drag to any point in time range
  - Play/pause button
  - Speed control (0.5x, 1x, 2x)
  - Time range shows full available history (not capped like card view)
  - Current frame timestamp displayed prominently (station timezone per ADR-020)
  - Nowcast frames visually distinguished on the timeline (different color segment or label)
  - For NOAA: time range can span 25+ hours — slider tick marks at 1-hour intervals
- Accept: Slider scrubs through full frame history. Play/pause/speed work. Nowcast visually distinct. Keyboard accessible (arrow keys scrub).

**T4.3 — Layer panel (collapsible, provider-adaptive)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-expanded.tsx`
- Do:
  - Collapsible sidebar (desktop) / bottom sheet (mobile)
  - Toggle button to show/hide panel (`aria-label="Toggle layer panel"`)
  - Layer list populated from provider capability's `layers` array
  - Each layer: checkbox toggle + name + type badge (Radar / Satellite / Overlay / Alerts)
  - Layers grouped by type
  - Default state: radar layers enabled, others off (respecting `default_enabled` from capability)
  - For single-layer providers (LibreWxR, RainViewer): panel still available but only shows one radar layer entry
  - For NOAA: shows full layer tree (radar, satellite bands, SPC, alerts)
  - Panel state persisted in localStorage (`clearskies.radar-layers`)
- Accept: Panel renders with correct layers per provider. Toggles enable/disable layers on map. Panel collapses/expands. Mobile bottom sheet works. localStorage persistence works.

**T4.4 — Color scheme picker (LibreWxR)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-expanded.tsx`
- Do:
  - Only shown when provider supports multiple color schemes (LibreWxR: 13 schemes)
  - Dropdown or grid picker in the layer panel or as a separate control
  - Schemes: NEXRAD Level III, TWC, Dark Sky, MRMS CREF, Original, Universal Blue, etc.
  - Selection changes the `{color}` parameter in tile URL template
  - Legend gradient updates to match selected scheme
  - Selection persisted in localStorage
  - For NOAA/RainViewer: picker hidden (fixed color scheme)
- Accept: Picker shows for LibreWxR. Selecting a scheme changes tiles and legend. Persists across sessions.

**T4.5 — Opacity control**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-expanded.tsx`
- Do:
  - Slider control for radar overlay opacity (0% to 100%, default 70% matching current MAX_OPACITY)
  - Located in layer panel or control bar
  - Affects all radar tile layers
  - `aria-label="Radar opacity"`, `aria-valuemin="0"`, `aria-valuemax="100"`
- Accept: Slider adjusts radar tile opacity in real time. Accessible.

**T4.6 — NOAA satellite layer rendering**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-expanded.tsx`
- Do:
  - When a NOAA satellite layer is enabled, add a WMS TileLayer to the Leaflet map
  - WMS endpoint URL and layer name from the layer capability declaration
  - Time-enabled: satellite layers animate alongside radar (synced to time slider)
  - Satellite frame metadata fetched from `/api/v1/radar/providers/noaa/layers/{layer_id}/frames`
  - Satellite layers render below radar layers (z-order: base map → satellite → radar)
  - Grayscale satellite is acceptable for v0.1 (client-side colorization deferred — noted in brief open question #2)
- Accept: Satellite layers render when toggled on. Time animation works. Layer z-order correct.

**T4.7 — NOAA SPC overlay rendering**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-expanded.tsx`
- Do:
  - When a NOAA SPC layer is enabled, fetch GeoJSON from the mapservices endpoint declared in the layer capability
  - Render as Leaflet GeoJSON layer with stroke/fill colors from the GeoJSON properties
  - NOT time-animated (current snapshot, updates when SPC issues new products)
  - Auto-refresh every 5 minutes when enabled
  - Risk level labels rendered as popups on click
  - Render above radar layers (z-order: base → satellite → radar → SPC → alerts)
- Accept: SPC outlooks render with correct colors. Click shows risk details. Auto-refreshes.

**T4.8 — NOAA alert polygon overlay**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-expanded.tsx`
- Do:
  - When alerts layer is enabled, fetch alert data from existing `/api/v1/alerts` endpoint
  - Render alert polygons as Leaflet GeoJSON layer
  - Color-coded by severity level (existing alert severity model)
  - Click shows alert details popup (event name, description, instructions)
  - Topmost z-order layer
  - Auto-refresh every 5 minutes when enabled
- Accept: Alert polygons render with severity colors. Click shows details. Z-order correct.

**T4.9 — WCAG accessibility audit**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `src/components/shared/radar-expanded.tsx`
- Do: Verify all expanded view controls meet WCAG 2.1 AA:
  - Focus trap in overlay (`role="dialog"`, `aria-modal="true"`)
  - Escape key closes overlay
  - All controls keyboard navigable (Tab order, Enter/Space activate)
  - Time slider: arrow keys scrub, accessible value announcements
  - Layer checkboxes: proper labels, state announced
  - Color contrast on all controls (4.5:1 text, 3:1 UI components)
  - Screen reader: layer changes announced via `aria-live` region
  - Reduced motion: respect `prefers-reduced-motion` (pause animation by default)
- Accept: axe-core 0 violations. Keyboard-only navigation works end-to-end. `prefers-reduced-motion` respected.

**QC (Opus) — after Phase 4:** Full expanded view walkthrough on weather-dev:
1. Navigate to `/radar` directly — expanded view renders
2. Click expand on Now page radar card — overlay opens, URL changes to `/radar`
3. Close (X and Escape) — returns to Now page
4. Layer panel: toggle satellite, SPC, alerts layers (NOAA provider)
5. Time slider: scrub through full history, play/pause, speed control
6. Color scheme picker: change LibreWxR color scheme, verify tiles + legend update
7. Opacity slider: adjust radar transparency
8. Mobile: bottom sheet layer panel, all controls accessible
9. Keyboard: Tab through all controls, Escape closes, arrow keys scrub
10. axe-core: 0 violations on expanded view
11. `tsc --noEmit` + `vite build` clean

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
- ADR-015 amendment (provider set, expand-to-fullscreen model)
- PROVIDER-MANUAL §7 (module rules, proxy rules, attribution)
- API-MANUAL (endpoint shapes, capability model, tile proxy)
- ARCHITECTURE.md (proxy model, endpoint descriptions)
- DASHBOARD-MANUAL (radar card, expanded view, layer panel, animation)
- DESIGN-MANUAL (component specs, layout, responsive behavior)
- OPERATIONS-MANUAL (LibreWxR configuration)
- ADR-026 (WCAG AA on all new UI)
- Flag any manual drift (implementation deviated from what Phase 0 prescribed) → amend manual before closing.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 0 | T0.1-T0.2 Reference doc capture | Coordinator | Opus | After Phase 0 |
| 0 | T0.3 ADR-015 amendment | Coordinator | Opus | After Phase 0 |
| 0 | T0.4-T0.9 ALL manual updates | Coordinator | Opus | After Phase 0 |
| 1 | T1.1 LibreWxR module (metadata + tiles) | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 1 | T1.2 NOAA unified module | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 1 | T1.3 Capability model extension | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 1 | T1.4 NOAA satellite/SPC/alert layers | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 1 | T1.5 Provider set changes | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 2 | T2.1-T2.5 Wizard + admin | `clearskies-stack-dev` | Sonnet | After Phase 2 |
| 3 | T3.1-T3.5 Radar card upgrades | `clearskies-dashboard-dev` | Sonnet | After Phase 3 |
| 4 | T4.1-T4.9 Expanded radar view | `clearskies-dashboard-dev` | Sonnet | After Phase 4 |
| 5 | Deploy + verify | Coordinator | Opus | After Phase 5 |

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

### Gate 3 — ADR + Manual Compliance (after Phase 5)
- ADR-015: Provider set matches amendment. Expand model matches.
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

**Architecture boundary: Caddy never calls external services.** Caddy only talks to the Clear Skies API. LibreWxR (like all external services) is accessed by the API for metadata and by the browser for tiles. No Caddy routes, no Docker compose services, no infrastructure config for LibreWxR in our codebase. This was corrected during plan review — the brief's "Caddy proxies to LibreWxR" proposal violated the security model.
