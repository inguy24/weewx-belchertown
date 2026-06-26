# NOAA WMS Layer Reference (Unified NOAA Provider)

Captured: 2026-06-24 via live WMS GetCapabilities requests.

---

## Radar Layers

### IEM NEXRAD (CONUS)

| Property | Value |
|----------|-------|
| WMS endpoint | `https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r-t.cgi` |
| Layer name | `nexrad-n0r-wmst` |
| Description | IEM-generated CONUS composite of NWS WSR-88D level III base reflectivity |
| TIME dimension | ISO8601, extent `1995-01-01/2026-12-31/PT5M` (5-minute steps) |
| Geographic coverage | CONUS: 24°N–50°N, 126°W–66°W |
| Supported CRS | EPSG:4326, EPSG:3857, EPSG:900913, EPSG:102100 |
| Output formats | PNG, PNG8, JPEG, PDF, SVG, TIFF |
| Rate limit | None documented (polite use expected) |
| Auth | None required |

### NOAA MRMS (AK/HI/PR/Guam)

| Property | Value |
|----------|-------|
| WMS endpoint | `https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer` |
| Layer name | `radar_base_reflectivity_time` |
| Description | MRMS composite from all WSR-88D radars |
| TIME dimension | ISO8601, 4-hour rolling window, updated every 5 minutes |
| Geographic coverage | Full US territories: 9°N–72°N, 176°W–150°E (includes AK, HI, PR, Guam) |
| Supported CRS | CRS:84, EPSG:4326, EPSG:3857 |
| Output formats | TIFF, PNG, PNG24, PNG32, BMP, GIF, JPEG, SVG |
| Rate limit | None documented |
| Auth | None required |

Note: MRMS TIME parameter accepts epoch milliseconds. The 4-hour rolling window means ~48 frames at 5-minute cadence.

---

## Satellite Layers (GOES via nowCOAST)

WMS endpoint: `https://nowcoast.noaa.gov/geoserver/satellite/wms`

### GOES Regional Layers (US coverage)

| Layer name | Title | Band | Resolution | Time cadence |
|------------|-------|------|------------|--------------|
| `goes_visible_imagery` | GOES East & West Visible | Band 2 (0.64 µm) | 0.5 km | 5 min |
| `goes_longwave_imagery` | GOES East & West Longwave IR | Band 14 (11.2 µm) | 2 km | 5 min |
| `goes_water_vapor_imagery` | GOES East & West Water Vapor | Band 8 (6.2 µm) | 2 km | 5 min |
| `goes_snow_ice_imagery` | GOES East & West Snow/Ice | Band 5 (1.61 µm) | 1 km | 5 min |

TIME dimension: ISO8601 timestamps, ~8-hour rolling window at 5-minute intervals.
Geographic coverage: 10.9°N–50.6°N, 179.5°W–50.7°W (US region).
Supported CRS: EPSG:3857, EPSG:4326, CRS:84.

### Global Mosaic Layers (GMGSI)

| Layer name | Title | Time cadence |
|------------|-------|--------------|
| `global_visible_imagery_mosaic` | Global Visible | Hourly |
| `global_longwave_imagery_mosaic` | Global Longwave IR | Hourly |
| `global_shortwave_imagery_mosaic` | Global Shortwave IR | Hourly |
| `global_water_vapor_imagery_mosaic` | Global Water Vapor | Hourly |

TIME dimension: Hourly timestamps. Geographic coverage: 72.7°S–72.7°N, 180°W–180°E.

Note: All satellite imagery from these endpoints is grayscale. Client-side colorization would be needed for enhanced IR display (deferred for v0.1 per the brief's open question #2).

---

## SPC Severe Weather Overlays

### SPC Weather Outlooks

Endpoint: `https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/SPC_wx_outlks/MapServer`

Format: WMS or GeoJSON query.

| Layer IDs | Content |
|-----------|---------|
| 0–1 | Day 1 categorical outlook |
| 2–7 | Day 1 tornado / hail / wind probabilities |
| 8–9 | Day 2 categorical outlook |
| 10–15 | Day 2 tornado / hail / wind probabilities |
| 16–17 | Day 3 categorical outlook |
| 18–19 | Day 3 tornado / hail / wind probabilities |
| 21–25 | Day 4–8 probabilistic outlooks |

GeoJSON responses include stroke/fill colors, risk labels, and valid/expire timestamps.
NOT time-enabled (current snapshot only; updates when SPC issues new products).

### SPC Mesoscale Discussions

Endpoint: `https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/spc_mesoscale_discussion/MapServer`

Format: WMS or GeoJSON query.
NOT time-enabled.

### SPC Fire Weather Outlooks

Endpoint: `https://mapservices.weather.noaa.gov/vector/rest/services/outlooks/SPC_firewx/MapServer`

Format: WMS or GeoJSON query.
NOT time-enabled.

---

## Alert Polygon Sources

### NWS API

| Property | Value |
|----------|-------|
| Endpoint | `https://api.weather.gov/alerts/active` |
| Format | GeoJSON FeatureCollection |
| Rate limit | 1 request per 30 seconds |
| Auth | User-Agent header required |
| Notes | Rich metadata (descriptions, instructions). Some alerts have null geometry (zone-based). |

### Watches/Warnings/Advisories MapServer

| Property | Value |
|----------|-------|
| Endpoint | `https://mapservices.weather.noaa.gov/eventdriven/rest/services/WWA/watch_warn_adv/MapServer` |
| Format | WMS or GeoJSON query |
| Refresh | ~5 minutes |
| Notes | Simpler metadata than NWS API. All features have polygon geometry. |

### nowCOAST Time-Enabled WWA

| Property | Value |
|----------|-------|
| Endpoint | `https://nowcoast.noaa.gov/arcgis/rest/services/nowcoast/wwa_*_time/MapServer` |
| Format | WMS |
| Notes | Supports historical playback (time-enabled). |

---

## Usage Notes

1. All NOAA endpoints are free, no API keys required (except `api.weather.gov` requires a User-Agent header).
2. No documented rate limits on WMS tile endpoints. Polite use expected.
3. `api.weather.gov` has a documented rate limit of 1 request per 30 seconds.
4. All times are UTC.
5. WMS GetMap requests use standard OGC parameters: `SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=...&CRS=EPSG:3857&BBOX=...&WIDTH=256&HEIGHT=256&FORMAT=image/png&TIME=...`
6. For time-enabled layers, the `TIME` parameter accepts ISO8601 format (e.g., `2026-06-24T21:00:00Z`).
7. MRMS also accepts epoch milliseconds for the TIME parameter.
