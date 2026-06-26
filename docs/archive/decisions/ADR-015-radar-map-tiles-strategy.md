---
status: Accepted
date: 2026-05-11
deciders: shane
supersedes:
superseded-by:
---

# ADR-015: Radar / map tiles strategy

> **Amended 2026-05-11** during Phase 2 task 3b-15 brief-draft research. `mapbox_jma` dropped from the day-1 provider set — Mapbox's JMA tilesets are `raster-array` shape (multi-band, GL-JS-only) and the Mapbox Raster Tiles API doesn't expose band selection for raster-array tilesets, so they cannot be consumed by Leaflet with the 5-min nowcast animation that justified picking them. Japan radar at v0.1 falls back to RainViewer; re-adding Japan as a first-class provider requires either an alternative JMA-sourced XYZ-tile feed (e.g. jma.go.jp/bosai/nowc) or a separate ADR allowing Mapbox GL JS for the JMA case alongside Leaflet. Both deferred.

> **Amended 2026-06-24** — Radar provider replacement. Full research in [docs/briefs/RADAR-PROVIDER-REPLACEMENT.md](../../briefs/RADAR-PROVIDER-REPLACEMENT.md). Execution plan in [docs/planning/RADAR-PROVIDER-REPLACEMENT-PLAN.md](../../planning/RADAR-PROVIDER-REPLACEMENT-PLAN.md). Changes:
>
> 1. **LibreWxR added as global default fallback** (replaces RainViewer). Drop-in RainViewer v2 API compatible. 13 color schemes, zoom 12, WebP, 6-frame nowcast. Operator configures endpoint (public `api.librewxr.net` or self-hosted). Tiles proxied through the API (API is the gateway, not Caddy — corrected from brief's original proposal to maintain the existing security model where Caddy only talks to the API).
> 2. **Unified NOAA module added** (`noaa`). Replaces separate `iem_nexrad` + `noaa_mrms` modules. Two radar sub-layers (IEM NEXRAD for CONUS, MRMS for AK/HI/PR/Guam) plus satellite (5 GOES bands via nowCOAST WMS-T), SPC severe weather overlays (GeoJSON), and alert polygons. All WMS layers browser-direct (free government endpoints). Multi-layer capability model extension.
> 3. **RainViewer demoted**. Still available but degraded: zoom capped at 7, no nowcast, single color scheme (Universal Blue), PNG only. Wizard notes limitations.
> 4. **Aeris dropped from radar domain**. 3,000 map units/day is unviable for radar tiles. Remains for forecast/AQI/alerts where API call volumes are lower.
> 5. **Expand-to-fullscreen model for radar card** (not a new page). Visitors tap expand button on the Now page radar card to open a full-viewport overlay with layer toggles, time slider, color scheme picker, and provider-adaptive controls. Overlay pushes `/radar` to browser history for bookmarkability. No ADR-024 amendment needed (no new page).
> 6. **Proxied provider set renamed**. `_KEYED_RADAR_PROVIDERS` → `_PROXIED_RADAR_PROVIDERS`. Concept broadened from "keyed providers" to "proxied providers" — the API is the gateway to external services regardless of whether an API key is involved. LibreWxR is proxied (API fetches tiles from upstream, serves to browser). NOAA WMS layers are browser-direct (free government endpoints). RainViewer remains browser-direct (keyless, public CDN).
> 7. **Updated wizard suggestion table**: US → `noaa`, Canada → `msc_geomet`, Germany → `dwd_radolan`, Europe → `librewxr`, Japan → `librewxr`, global → `librewxr`.

## Context

The Now-page radar card and webcam card ([ADR-024](ADR-024-page-taxonomy.md) cat 8) and the Earthquakes-page embedded map (cat 6) both need an interactive map with tile overlays. **As built:** radar and webcam ship as two separate side-by-side cards in Row 7 of the Now page (not a single 3-tab panel). The webcam card is conditionally rendered only when `webcamEnabled && webcamAvailable`; the radar card expands to full width when the webcam card is absent. The cat 8 walk research established the per-region radar provider matrix and the PWS-contributor track as the default lens for "free" Aeris.

This ADR locks the map library and the day-1 radar provider set. Per-provider modules conform to [ADR-038](ADR-038-data-provider-module-organization.md).

## Decision

### Map library

**Leaflet** (https://leafletjs.com/) — MIT-licensed, supports XYZ tiles + WMS (with time dimension) + iframe overlays + GeoJSON markers. Used for both the radar tab and the earthquakes-page map. Base map tiles: **OpenStreetMap** (free, attribution required). MapLibre rejected — heavier WebGL stack, no advantage for our needs.

### Day-1 radar provider modules

In `weewx_clearskies_api/providers/radar/`, conforming to [ADR-038](ADR-038-data-provider-module-organization.md):

- **`rainviewer`** — global mosaic, no key, free. Default fallback for regions without a native option.
- **`openweathermap`** — global model precipitation (not true radar reflectivity). OWM key required. Labeled in UI as "Model precipitation" so operators understand it isn't real radar.
- **`aeris`** — global real radar mosaic. AerisWeather Maps API. Realistic free path = AerisWeather Contributor Plan via PWSWeather.
- **`iem_nexrad`** — US CONUS NEXRAD via Iowa Environmental Mesonet WMS-T. Free, no key, 5-min cadence.
- **`noaa_mrms`** — US AK / HI / PR / Guam via NOAA MapServer. Free, no key.
- **`msc_geomet`** — Canada national mosaic via Environment Canada WMS-T. Free, attribution required.
- **`dwd_radolan`** — Germany RADOLAN via DWD GeoWebService WMS. Free, 10-min cadence.
- **`iframe`** — operator-supplied URL for regions without a tile-API path (BoM Australia, MetService NZ, regional met-service viewers). Loses theming/composition; documented tradeoff.

Japan at v0.1 uses the RainViewer global mosaic (RainViewer's composite includes JMA returns; the 5-min nowcast feature is unavailable). See the 2026-05-11 amendment note above.

Full per-region matrix and per-provider terms live in cat 8 of [CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md). Each module's capability declaration ([ADR-038](ADR-038-data-provider-module-organization.md) rule 4) carries its geographic coverage so the setup wizard can recommend per operator lat/lon.

### Operator setup flow

1. Configuration UI reads operator lat/lon.
2. Suggests a radar module based on region (e.g., Canada → `msc_geomet`).
3. Operator confirms or picks a different module.
4. For keyed modules (Aeris, OpenWeatherMap): operator enters their API key. Keys stored per [ADR-027](ADR-027-config-and-setup-wizard.md).
5. For `iframe`: operator pastes the URL.

### Key handling

For keyed providers, **clearskies-api proxies tile requests** server-side per [ADR-037](ADR-037-inbound-traffic-architecture.md) — keys never reach the browser. Free keyless providers may be fetched directly by the browser. Proxy endpoint shape lives with the OpenAPI contract / [ADR-018](INDEX.md).

### Animation

Tile sources with time-stepped frames drive a frame-replay control on the radar tab. Frame count and step bounded by source-available history.

## Options considered

| Option | Verdict |
|---|---|
| A. Leaflet + per-provider modules per ADR-038 (this ADR) | **Selected.** |
| B. MapLibre instead of Leaflet | Rejected — WebGL-first, heavier, no plugin coverage advantage for our use. |
| C. Iframe-only (Windy embed, etc.) | Rejected — loses theming, dark mode, composability. Acceptable as per-region fallback only. |
| D. Single-provider lock-in | Rejected — no single free-tier provider works globally. |

## Consequences

- Phase 2 builds 7 provider modules + the iframe config slot. Capability declarations populate the setup wizard's recommendation engine.
- Earthquakes page reuses Leaflet — same dependency, two consumers.
- OpenWeatherMap radar UI label is "Model precipitation," not "Radar."
- Keyed providers are proxied through a single parameterized tile-proxy endpoint: `GET /radar/providers/{provider_id}/tiles/{z}/{x}/{y}`. Provider identity is the `{provider_id}` path parameter. Only keyed providers (`aeris`, `openweathermap`) are served through this proxy; keyless providers are fetched directly by the browser per ADR-037.
- Attribution rendered per source's terms (OSM, RainViewer, NOAA, IEM, MSC, DWD, Aeris, OpenWeatherMap) on the radar tab. JMA and Mapbox are excluded — `mapbox_jma` was dropped from the day-1 provider set per the 2026-05-11 amendment (Mapbox JMA tilesets are raster-array shape, GL-JS-only, incompatible with Leaflet). No `mapbox_jma.py` provider module exists.

## Out of scope

- Per-provider tile URL templates and WMS layer names — Phase 2.
- Phase 6+ providers (Météo-France, KNMI, MeteoSwiss, EUMETNET OPERA, UK Met Office DataHub) — added as new modules when demand surfaces.
- Japan as a first-class radar provider — deferred 2026-05-11. Either a Leaflet-compatible JMA-sourced feed (e.g. jma.go.jp/bosai/nowc) or an ADR allowing Mapbox GL JS for the JMA case is needed first.
- Marine wave / sea-state overlays — out of v0.1 per cat 7.

## References

- Cat 8 research: [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Leaflet: https://leafletjs.com/
- OSM tile usage policy: https://operations.osmfoundation.org/policies/tiles/
- Related: [ADR-006](ADR-006-compliance-model.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-037](ADR-037-inbound-traffic-architecture.md), [ADR-038](ADR-038-data-provider-module-organization.md).
