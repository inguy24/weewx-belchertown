---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-015: Radar / map tiles strategy

## Context

The Now-page webcam/timelapse/radar 3-tab panel ([ADR-024](ADR-024-page-taxonomy.md) cat 8) and the Earthquakes-page embedded map (cat 6) both need an interactive map with tile overlays. The cat 8 walk research established the per-region radar provider matrix and the PWS-contributor track as the default lens for "free" Aeris.

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
- **`mapbox_jma`** — Japan via Mapbox-hosted JMA layers (5-min present + 60-min nowcast). Mapbox key required (free tier OK).
- **`iframe`** — operator-supplied URL for regions without a tile-API path (BoM Australia, MetService NZ, regional met-service viewers). Loses theming/composition; documented tradeoff.

Full per-region matrix and per-provider terms live in cat 8 of [CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md). Each module's capability declaration ([ADR-038](ADR-038-data-provider-module-organization.md) rule 4) carries its geographic coverage so the setup wizard can recommend per operator lat/lon.

### Operator setup flow

1. Configuration UI reads operator lat/lon.
2. Suggests a radar module based on region (e.g., Canada → `msc_geomet`).
3. Operator confirms or picks a different module.
4. For keyed modules (Aeris, OpenWeatherMap, Mapbox JMA): operator enters their API key. Keys stored per [ADR-027](ADR-027-config-and-setup-wizard.md).
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

- Phase 2 builds 8 provider modules + the iframe config slot. Capability declarations populate the setup wizard's recommendation engine.
- Earthquakes page reuses Leaflet — same dependency, two consumers.
- OpenWeatherMap radar UI label is "Model precipitation," not "Radar."
- Keyed providers add proxy endpoints in clearskies-api (one route per keyed module).
- Attribution rendered per source's terms (OSM, RainViewer, NOAA, IEM, MSC, DWD, JMA, Mapbox, Aeris) on the radar tab.

## Out of scope

- Per-provider tile URL templates and WMS layer names — Phase 2.
- Phase 6+ providers (Météo-France, KNMI, MeteoSwiss, EUMETNET OPERA, UK Met Office DataHub) — added as new modules when demand surfaces.
- Marine wave / sea-state overlays — out of v0.1 per cat 7.

## References

- Cat 8 research: [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Leaflet: https://leafletjs.com/
- OSM tile usage policy: https://operations.osmfoundation.org/policies/tiles/
- Related: [ADR-006](ADR-006-compliance-model.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-037](ADR-037-inbound-traffic-architecture.md), [ADR-038](ADR-038-data-provider-module-organization.md).
