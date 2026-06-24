# Radar Provider Replacement: LibreWxR + NOAA Native Layers

**Status:** PROPOSED
**Created:** 2026-06-23
**Affects:** ADR-015 (radar/map tiles strategy), PROVIDER-MANUAL.md §7 (radar)
**Components:** API (`weewx-clearskies-api` provider modules), Dashboard (radar card, future maps page)

---

## Problem Statement

RainViewer, our current global default radar provider (ADR-015), gutted its free API tier on January 1, 2026:

- Maximum zoom capped at **7** (~1.2 km/pixel at equator — city-level only, no street detail)
- Nowcast (future prediction frames) discontinued
- Satellite IR data discontinued
- All color schemes removed except "Universal Blue"
- PNG only (no WebP)
- Rate limited to 100 requests/IP/minute

Zoom 7 makes the radar card nearly useless for local weather awareness. This is a permanent change — RainViewer is pivoting to their mobile apps and the free API is in maintenance/sunset mode.

Separately, ADR-015 lists Aeris (Xweather) as a keyed global radar provider. Research into Aeris's practical limits reveals:

- **3,000 map units/day** on the PWS contributor plan — a few neighbors leaving the radar page open would exhaust this
- Aeris ToS Section 2.3(i) prohibits "copying" API data; server-side tile caching (which our proxy architecture requires) is a gray area — not explicitly prohibited by name, but arguably covered by the anti-copying clause
- The product-specific Service Description that might relax this restriction is not publicly available

**Conclusion:** Aeris is not viable as a radar provider at the PWS contributor tier. The rate limit alone makes it impractical regardless of ToS interpretation. (Aeris remains viable for forecast, AQI, and alerts where API call volumes are much lower.)

---

## Research Findings

### Alternatives evaluated

| Provider | Format | Coverage | Cost | Verdict |
|----------|--------|----------|------|---------|
| **LibreWxR** | XYZ tiles (RainViewer v2 API compatible) | US, CA, EU (24 countries), JP, TW, MY + NWP model global | Free (public API or self-host) | **Selected — global default** |
| **NOAA direct** (MRMS, IEM NEXRAD, nowCOAST, SPC) | WMS-T + GeoJSON | US only | Free, no key, no rate limit | **Selected — US-native provider** |
| Rainbow.ai | XYZ tiles | Global (except China) | 30K tiles/mo free; opaque pricing beyond | **Rejected** — product is AI nowcast model output, not radar imagery; `/radars` layer capped at zoom 7; pricing unclear |
| Tomorrow.io | XYZ tiles | Global | ~500 calls/day free | **Rejected** — free tier too limited for auto-refreshing dashboard |
| Open-Meteo | Custom (OMfiles) | Global | Free non-commercial | **Rejected** — NWP model data, not radar; MapLibre-only format |
| Mapbox | N/A | N/A | N/A | **Rejected** — no radar tile product; base map provider only |
| HERE Weather | Custom | Global | Premium-only (contact sales) | **Rejected** — not publicly priced, not Leaflet-native |
| MapTiler | Custom SDK | Global | Free tier requires their base maps | **Rejected** — requires MapTiler SDK, not standard Leaflet tiles |
| Xweather standalone | XYZ tiles | Global | EUR 300/mo+ | **Rejected** — enterprise pricing |
| Meteoblue | Custom | Global | Contact sales | **Rejected** — not publicly priced |

### LibreWxR detail

- **What it is:** Self-hostable, drop-in RainViewer API replacement. Created January 2026 by Joshua Kimsey in direct response to RainViewer's free tier restrictions.
- **API compatibility:** RainViewer v2 API format. Metadata endpoint at `/public/weather-maps.json` returns the same shape. Migration from RainViewer is a URL swap.
- **Radar data sources:** NOAA MRMS (US), MSC (Canada), EUMETNET OPERA (24 EU countries), DPC (Italy), JMA HRPN (Japan), CWA QPESUMS (Taiwan), MET Malaysia + Singapore, MARN/SNET (El Salvador). Global gap-fill via ECMWF IFS + regional NWP models (HRRR, ICON-EU, AROME variants, etc.).
- **Tile specs:** 512px source tiles, WebP format, max zoom 12, 13 selectable color schemes (NEXRAD Level III, TWC, Dark Sky, MRMS CREF, etc.), optional wind arrows.
- **Additional data:** Satellite IR (12 frames, 1-hour intervals), 6-frame nowcast (optical flow extrapolation), global WMO CAP weather alerts (GeoJSON).
- **License:** AGPL-3.0 (code), CC-BY-4.0 (data). Commercial license available.
- **Hosting options:**
  - **Public API** at `api.librewxr.net` — live, working, verified. Terms: best-effort, no SLA, no uptime guarantee, "reasonable request rates" only. Intended as a starting point; operators should transition to self-hosting for production reliability.
  - **Self-hosted** via Docker. RAM: ~3-4 GB (US + ECMWF only), ~9-10 GB (full regional config).
- **Maturity:** ~6 months old, 191 commits, 34 GitHub stars, single primary developer. Adopted by Merry Sky app. No formal releases — continuous deployment via auto-update script.
- **Terms of use (public API):** No bulk downloading or systematic mirroring. Cannot resell the hosted endpoint as your own service. Data itself is CC-BY-4.0 — commercial use fine with attribution. Self-hosting has no usage restrictions.
- **Code assessment (2026-06-23):** Source reviewed for security posture. No injection surfaces — no SQL, no shell commands, no `eval()`, no template interpolation of user input. All tile path parameters validated via FastAPI `Path()` constraints (zoom, x, y bounds-checked against `2**z`). No user data stored, no telemetry, TLS verification on all outbound connections. Hardening gaps are typical for a young project (container runs as root, no built-in rate limiting, `/health` endpoint exposes operational detail without auth) — all addressed by running behind a reverse proxy, which is how we integrate it (see Integration model below). Code quality is reasonable: 38 test files, proper error handling (no stack traces leaked to clients), modern dependency choices (FastAPI, httpx, numpy 2.x). The AGPL license ensures source access if the project is abandoned.
- **Source:** https://librewxr.net/, https://github.com/JoshuaKimsey/LibreWXR

### NOAA native layer inventory (US only)

All free, no API keys (except api.weather.gov requires User-Agent header), no zoom caps, no rate limits (api.weather.gov: 1 req/30s), Leaflet-compatible.

**Radar:**

| Layer | Endpoint | Format | Time-enabled |
|-------|----------|--------|--------------|
| Base reflectivity (CONUS) | `mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r-t.cgi` | WMS-T | Yes (5-min steps) |
| Base reflectivity (US + AK/HI/PR/Guam) | `mapservices.weather.noaa.gov/.../radar_base_reflectivity_time/ImageServer/WMSServer` | WMS-T | Yes (5-min steps, 4-hr rolling) |
| Radar (nowCOAST) | `nowcoast.noaa.gov/arcgis/.../radar_meteo_imagery_nexrad_time/MapServer/WMSServer` | WMS-T | Yes |

**Satellite (GOES):**

| Layer | Endpoint | Format | Time-enabled |
|-------|----------|--------|--------------|
| Visible (Band 2, 0.5 km) | `nowcoast.noaa.gov/geoserver/satellite/wms` layer `goes_visible_imagery` | WMS-T | Yes (5-min steps, ~8hr history) |
| Longwave IR (Band 14, 2 km) | Same WMS, layer `goes_longwave_imagery` | WMS-T | Yes |
| Shortwave IR (Band 7, 2 km) | Same WMS, layer `goes_shortwave_imagery` | WMS-T | Yes |
| Water Vapor (Band 8, 2 km) | Same WMS, layer `goes_water_vapor_imagery` | WMS-T | Yes |
| Snow/Ice (Band 5, 1 km) | Same WMS, layer `goes_snow_ice_imagery` | WMS-T | Yes |

Satellite imagery is grayscale only from NOAA. Client-side colorization (Canvas pixel remapping) is needed for enhanced IR display.

**SPC severe weather overlays:**

| Layer | Endpoint | Format |
|-------|----------|--------|
| Day 1-3 categorical outlooks | `mapservices.weather.noaa.gov/vector/.../SPC_wx_outlks/MapServer` | WMS or GeoJSON query |
| Day 1-3 tornado/hail/wind probabilities | Same service, layers 2-7 (day 1), 10-15 (day 2), 18-19 (day 3) | WMS or GeoJSON query |
| Day 4-8 probabilistic outlooks | Same service, layers 21-25 | WMS or GeoJSON query |
| Mesoscale discussions | `mapservices.weather.noaa.gov/vector/.../spc_mesoscale_discussion/MapServer` | WMS or GeoJSON query |
| Fire weather outlooks | `mapservices.weather.noaa.gov/vector/.../SPC_firewx/MapServer` | WMS or GeoJSON query |

SPC layers return GeoJSON with stroke/fill colors, risk labels, and valid/expire timestamps. Not time-enabled (current snapshot, updates when SPC issues new products).

**Alert polygons:**

| Source | Endpoint | Format | Notes |
|--------|----------|--------|-------|
| NWS API | `api.weather.gov/alerts/active` | GeoJSON FeatureCollection | Rich metadata (descriptions, instructions). Requires User-Agent header. 1 req/30s limit. Some alerts have null geometry (zone-based). |
| mapservices WWA | `mapservices.weather.noaa.gov/eventdriven/.../WWA/watch_warn_adv/MapServer` | WMS or GeoJSON query | Simpler metadata. 5-min refresh. All features have polygon geometry. |
| nowCOAST (time-enabled) | `nowcoast.noaa.gov/arcgis/.../wwa_*_time/MapServer` | WMS | Supports historical playback. |

---

## Proposed Direction

### Two complementary provider paths

**LibreWxR provider module** — global coverage, replaces RainViewer as the default fallback:
- API provider module serves frame metadata (timestamps, available layers, color scheme, tile URL template) through normal `/api/v1/` endpoints
- Tile URL template points at the Caddy proxy path (e.g. `/radar/tiles/...`), not directly at LibreWxR — see Integration model below
- Configurable upstream: self-hosted LibreWxR on Docker network (default), or public `api.librewxr.net` for operators who choose not to self-host
- XYZ tile format, RainViewer v2 API compatible
- Capabilities: radar tiles, satellite IR tiles, nowcast frames, frame metadata
- Operator notes in wizard: public API has no SLA; self-hosting recommended for production reliability
- Attribution: CC-BY-4.0 requires credit to LibreWxR

**NOAA native provider module** — US-only, richer than any single commercial provider:
- No API key, no rate limits (except api.weather.gov User-Agent), no infrastructure to run
- Multi-layer capabilities declared in the module:
  - Radar (MRMS/NEXRAD WMS-T)
  - Satellite (5 GOES bands via nowCOAST WMS-T)
  - SPC overlays (convective outlooks, tornado/hail/wind probs, mesoscale discussions via GeoJSON)
  - Alert polygons (NWS API GeoJSON or mapservices WMS)
- The module exposes layer metadata to the dashboard; the dashboard decides what to render and how

### Provider set changes (amending ADR-015)

| Module | ADR-015 status | New status |
|--------|---------------|------------|
| `rainviewer` | Global default fallback | **Demoted** — available but degraded (zoom 7 max). Wizard notes limitations. |
| `aeris` | Keyed global radar | **Dropped** from radar. Remains in forecast/AQI/alerts where API volumes are lower. |
| `librewxr` | Not in ADR-015 | **Added** — new global default fallback. Configurable endpoint. |
| `noaa` | Split across `iem_nexrad` + `noaa_mrms` (radar only) | **Expanded** — unified NOAA module with radar + satellite + SPC + alerts as declared layer capabilities. US only. |
| `openweathermap` | Keyed, "Model precipitation" | **Unchanged** |
| `msc_geomet` | Canada WMS-T | **Unchanged** |
| `dwd_radolan` | Germany WMS-T | **Unchanged** |
| `iframe` | Operator-supplied URL | **Unchanged** |

### Integration model: tile routing through Caddy

Clear Skies uses a single-ingress architecture: operators expose Caddy on ports 80/443, and all other services bind to the Docker network only. Radar tile serving follows the same model — no new ports, no direct browser-to-backend connections.

**Self-hosted LibreWxR (recommended):**

```
Browser → Caddy (443) → /radar/tiles/* → librewxr:8080 (Docker network only)
Browser → Caddy (443) → /api/v1/radar/* → api:8765 (frame metadata, layer list)
```

- LibreWxR runs as a container on the Docker network, same as the Config UI (port 9876) — never exposed to the host or internet
- Caddy routes tile requests (e.g. `/radar/tiles/{size}/{z}/{x}/{y}/{color}/{smooth_snow}.{ext}`) to the LibreWxR container internally
- The API's `librewxr` provider module serves frame metadata and the tile URL template pointing at the Caddy path — the dashboard fetches tiles from the same origin as everything else
- No CORS configuration needed (same-origin requests), TLS handled by Caddy, rate limiting available via Caddy if desired
- The operator never opens a port for LibreWxR; Caddy is the only public surface

**Public API fallback (no self-hosting):**

If the operator chooses not to self-host, the tile URL template points at `api.librewxr.net` directly. The browser fetches tiles cross-origin from LibreWxR's public API (CORS is already permissive there). This is the same model as RainViewer today — the operator accepts that visitors' browsers connect to a third-party service. The wizard notes the tradeoff: no infrastructure to run, but no SLA and no control.

**NOAA native layers:** These are public US government WMS endpoints. The browser fetches WMS tiles directly from `nowcoast.noaa.gov`, `mapservices.weather.noaa.gov`, etc. No proxy needed — these are designed for public consumption with no rate limits or API keys. The API provider module serves layer metadata and endpoint URLs; the dashboard's Leaflet map makes the WMS requests.

**Why this model:** The alternative — exposing LibreWxR directly to the internet — would require the operator to open another port, configure TLS separately, and manage rate limiting on a service that has no built-in authentication. Routing through Caddy keeps the security model identical to the rest of Clear Skies: one ingress point, one TLS certificate, one place to configure access controls.

### Dashboard consumption (separate scope, noted here for context)

The API provider modules are general-purpose data access — they declare available layers and serve metadata/endpoints. How the dashboard uses them is a separate design concern:

- **Now page radar card:** Renders the operator's selected radar layer (LibreWxR, NOAA, RainViewer, etc.) with basic animation controls. Same as current ADR-015 intent, just with better provider options.
- **Full-screen Radar/Maps page (new scope):** Interactive Leaflet map with a layer panel. Operator/visitor toggles layers on and off — radar, satellite bands, SPC outlooks, alert polygons. Time slider for animation. Full zoom capability. This is a new page that the NOAA module's rich layer set makes possible, but it consumes the same provider data through the same API.

The maps page design is out of scope for this brief — it will need its own ADR addressing page taxonomy (amending ADR-024), layer toggle UX, mobile behavior, and performance (multiple WMS layers animating simultaneously).

### Wizard suggestion table (updated)

| Operator region | Suggested radar provider | Notes |
|-----------------|------------------------|-------|
| US (any) | `noaa` | Full experience: radar + satellite + SPC + alerts |
| Canada | `msc_geomet` | Or LibreWxR (uses MSC data) |
| Germany | `dwd_radolan` | Or LibreWxR (uses OPERA data) |
| Europe (non-DE) | `librewxr` | Uses EUMETNET OPERA composite |
| Japan | `librewxr` | Uses JMA HRPN |
| All other regions | `librewxr` | NWP model global fallback where no native radar |

RainViewer available as an explicit operator choice in all regions, with a note: "Limited to zoom level 7, no nowcast, single color scheme."

---

## Aeris compliance note (non-radar)

Aeris remains in the Clear Skies provider set for forecast, AQI, and alerts. Before release, an audit task should verify compliance with Aeris branding and attribution requirements (Vaisala logo, attribution text per Section 11.1 of the General Conditions). This is separate from the radar decision but surfaced during this research.

---

## Open questions

1. **NOAA module scope:** Should the unified NOAA module replace the separate `iem_nexrad` and `noaa_mrms` modules from ADR-015, or should it be a new module alongside them? A single `noaa` module that declares all NOAA layers (radar + satellite + SPC) is cleaner, but it's a larger scope than two radar-only modules.
2. **Satellite colorization:** NOAA serves grayscale satellite imagery. Client-side Canvas colorization is the standard approach for enhanced IR display. Should the dashboard ship built-in color lookup tables, or is grayscale acceptable for v0.1?
3. **LibreWxR maturity risk:** ~~The project is 6 months old with a single maintainer. If it disappears, operators fall back to degraded RainViewer or self-host from their own fork (AGPL ensures source access). Is this acceptable, or do we need a more conservative default?~~ **Resolved (2026-06-23):** Code review found clean security posture, reasonable test coverage, and no red flags. The AGPL license guarantees source access. If the project is abandoned, operators continue running their self-hosted instance or fork. The Caddy proxy integration means LibreWxR is never exposed directly — it's just another internal service. Acceptable risk.
4. **Maps page priority:** The full-screen maps page with layer toggles is a significant dashboard feature. Does it belong in the current phase or is it deferred?

---

## Sources

- [RainViewer API Transition FAQ](https://www.rainviewer.com/api/transition-faq.html)
- [LibreWxR site](https://librewxr.net/) / [GitHub](https://github.com/JoshuaKimsey/LibreWXR) / [Terms](https://librewxr.net/terms) / [Coverage](https://librewxr.net/docs/doc-viewer?doc=coverage)
- [LibreWxR RainViewer Migration Guide](https://librewxr.net/docs/doc-viewer?doc=rainviewer-migration-guide)
- [Vaisala General Conditions DOC250754-B](https://docs.vaisala.com/v/u/DOC250754-B/en-US)
- [Xweather Terms](https://www.xweather.com/terms) / [Legal Portal](https://www.xweather.com/legal)
- [PWSWeather Contributor Plan](https://www.pwsweather.com/contributor-plan/)
- [Xweather Maps Accesses Documentation](https://www.xweather.com/docs/maps/getting-started/accesses)
- [NWS GIS Web Services](https://www.weather.gov/gis/WebServices)
- [nowCOAST Satellite WMS](https://nowcoast.noaa.gov/geoserver/satellite/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities)
- [NOAA MRMS WMS](https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer)
- [IEM NEXRAD WMS-T](https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r-t.cgi)
- [SPC Outlooks MapServer](https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/SPC_wx_outlks/MapServer)
- [SPC Mesoscale Discussion MapServer](https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/spc_mesoscale_discussion/MapServer)
- [NWS Alerts API](https://www.weather.gov/documentation/services-web-alerts)
- [WWA MapServer](https://mapservices.weather.noaa.gov/eventdriven/rest/services/WWA/watch_warn_adv/MapServer)
- [RainViewer: Weather Radar APIs in 2025](https://www.rainviewer.com/blog/weather-radar-apis-2025-overview.html)
