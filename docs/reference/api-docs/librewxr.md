# LibreWxR API Reference

Captured: 2026-06-24 from https://github.com/JoshuaKimsey/LibreWXR README + live API at api.librewxr.net

---

## Overview

LibreWxR is a self-hostable, drop-in replacement for RainViewer's v2 API. Created January 2026 by Joshua Kimsey in response to RainViewer's free-tier restrictions. Provides weather radar tiles, NWP model precipitation, satellite imagery, nowcast, and WMO CAP weather alerts.

License: AGPL-3.0-or-later (code), CC-BY-4.0 (data). Commercial license available.

Public API: `https://api.librewxr.net` (best-effort, no SLA).

---

## API Endpoints

### Metadata

```
GET /public/weather-maps.json
```

Returns the same structure as RainViewer v2 `weather-maps.json`. Drop-in compatible.

### Radar Tiles

```
GET /v2/radar/{timestamp}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.{ext}
```

Parameters:
- `timestamp` — Unix timestamp from the metadata response's `radar.past[].time` or `radar.nowcast[].time`
- `size` — `256` or `512` pixels
- `z`, `x`, `y` — Standard slippy-map tile coordinates (max zoom 12)
- `color` — Color scheme ID (0–11, or 255 for raw grayscale)
- `smooth` — `0` (sharp) or `1` (Gaussian blur)
- `snow` — `0` (uniform) or `1` (snow/rain color differentiation)
- `ext` — `png` or `webp`

Query parameters:
- `arrows=light` or `arrows=dark` — Motion vector overlay (optional)

### Satellite Tiles

```
GET /v2/satellite/{timestamp}/{size}/{z}/{x}/{y}/0/0_0.{ext}
```

NOAA GMGSI composite: daytime visible over longwave IR with natural terminator crossfade. Hourly cadence. Coverage: ±72.7° latitude.

### Weather Alerts

```
GET /v2/alerts
GET /v2/alerts?lat={lat}&lon={lon}
GET /v2/alerts?bbox=west,south,east,north
```

Returns GeoJSON FeatureCollection with WMO CAP metadata (severity, urgency, event, headline, expiry). Optional `simplify` parameter sets polygon simplification tolerance in meters (default 1000).

### Health

```
GET /health
```

Returns server status, frame counts, cache usage, NWP chain state, satellite cache state, alerts status, and per-component memory breakdown.

---

## weather-maps.json Response Format

Verified against live `api.librewxr.net` response (2026-06-24):

```json
{
  "version": "2.0",
  "generated": 1782335891,
  "host": "https://api.librewxr.net",
  "radar": {
    "past": [
      { "time": 1782329400, "path": "/v2/radar/1782329400" },
      ...
    ],
    "nowcast": [
      { "time": 1782336600, "path": "/v2/radar/1782336600" },
      ...
    ],
    "colorSchemes": [
      { "id": 0, "name": "Black and White" },
      ...
    ]
  },
  "satellite": {
    "infrared": [
      { "time": 1782332400, "path": "/v2/satellite/1782332400" },
      ...
    ]
  }
}
```

Key fields:
- `version` — API version string ("2.0")
- `generated` — Unix epoch seconds when the metadata was generated
- `host` — Base URL for tile requests (combine with frame `path` + tile coordinates)
- `radar.past` — Array of historical radar frames (count depends on `LIBREWXR_MAX_FRAMES`, default 12)
- `radar.nowcast` — Array of nowcast frames (count depends on `LIBREWXR_NOWCAST_FRAMES`, default 6)
- `radar.colorSchemes` — Array of available color schemes with ID and display name
- `satellite.infrared` — Array of satellite frames

Frame-kind mapping (RainViewer v2 compatible):
- The single `past` entry with `max(time)` → `"current"`
- All other `past` entries → `"past"`
- All `nowcast` entries → `"nowcast"`

Tile URL composition:
```
{host}{path}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.{ext}
```

Example:
```
https://api.librewxr.net/v2/radar/1782329400/512/6/18/25/2/1_0.webp
```

---

## Color Schemes

| ID | Name |
|----|------|
| 0 | Black and White |
| 1 | Rainviewer Original |
| 2 | Universal Blue |
| 3 | TITAN |
| 4 | The Weather Channel |
| 5 | Meteored |
| 6 | NEXRAD Level III |
| 7 | Rainbow |
| 8 | Dark Sky |
| 9 | Datameteo Valerio |
| 10 | Viper HD |
| 11 | MRMS CREF |
| 255 | Raw Grayscale |

---

## Configuration Environment Variables

### Core

| Variable | Default | Description |
|----------|---------|-------------|
| `LIBREWXR_PUBLIC_URL` | `http://localhost:8080` | Public URL in metadata responses |
| `LIBREWXR_PORT` | `8080` | Server listen port |
| `LIBREWXR_MAX_ZOOM` | `12` | Maximum tile zoom level |
| `COMPOSE_PROFILES` | `single` | Deployment mode: `single` or `multi` |
| `LIBREWXR_CACHE_DIR` | *(empty)* | Shared cache directory (required for multi mode) |
| `LIBREWXR_WORKERS` | *(mode-dependent)* | Uvicorn worker processes |

### Radar

| Variable | Default | Description |
|----------|---------|-------------|
| `LIBREWXR_RADAR_ENABLED` | `true` | Master switch for radar layer |
| `LIBREWXR_ENABLED_REGIONS` | `ALL` | Region codes to enable |
| `LIBREWXR_NA_SOURCE` | `mrms_fallback` | US source: `mrms_fallback`, `mrms`, or `iem` |
| `LIBREWXR_CA_SOURCE` | `mrms_with_msc_blend` | Canada source: `mrms_with_msc_blend`, `mrms`, or `msc` |
| `LIBREWXR_FETCH_INTERVAL` | `600` | Seconds between radar fetches (clock-aligned) |
| `LIBREWXR_MAX_FRAMES` | `12` | Radar frames to retain (2 hours at 10-min cadence; recommend 24+ for self-hosted) |
| `LIBREWXR_NOISE_FLOOR_DBZ` | `10.0` | Minimum dBZ to display (-32 disables) |
| `LIBREWXR_DESPECKLE_MIN_NEIGHBORS` | `3` | Speckle filter strength (0 disables) |

### Nowcast

| Variable | Default | Description |
|----------|---------|-------------|
| `LIBREWXR_NOWCAST_ENABLED` | `true` | Enable precipitation nowcast |
| `LIBREWXR_NOWCAST_FRAMES` | `6` | Frames in 60-min forecast |
| `LIBREWXR_NOWCAST_BLEND_MODE` | `blended` | `radar`, `blended`, or `model` |

### Satellite

| Variable | Default | Description |
|----------|---------|-------------|
| `LIBREWXR_SATELLITE_ENABLED` | `true` | GMGSI VIS+IR composite |
| `LIBREWXR_SATELLITE_MAX_FRAMES` | `12` | Satellite frames to retain |

### Tile Rendering

| Variable | Default | Description |
|----------|---------|-------------|
| `LIBREWXR_TILE_CACHE_MB` | `200` | Max tile cache per worker (MB) |
| `LIBREWXR_SMOOTH_RADIUS` | `2.0` | Gaussian blur radius (0 disables) |
| `LIBREWXR_WEBP_QUALITY` | `65` | WebP quality (100 = lossless) |

### Alerts

| Variable | Default | Description |
|----------|---------|-------------|
| `LIBREWXR_ALERTS_ENABLED` | `true` | WMO CAP weather alerts |

---

## Coverage

### Native Radar Data Sources

| Region | Source | Notes |
|--------|--------|-------|
| US (CONUS, AK, HI, PR, Guam) | NOAA MRMS | Full coverage |
| Canada | MSC GeoMet (with MRMS fallback) | |
| El Salvador + neighbors | MARN/SNET | |
| Europe (24 countries) | EUMETNET OPERA | Continental composite |
| Italy | DPC | National radar network |
| Taiwan | CWA QPESUMS | |
| Japan | JMA HRPN | 20 radars + gauge correction |
| SE Asia | MET Malaysia | Peninsular Malaysia, Borneo, Brunei, Singapore, N. Sumatra |

### Regional NWP Chain (model precipitation gap-fill)

| Region | Model | Toggle |
|--------|-------|--------|
| Continental US + Alaska | NOAA HRRR | `LIBREWXR_NA_NWP_SOURCE=hrrr` |
| Canada | ECCC HRDPS | `LIBREWXR_HRDPS_ENABLED` |
| Europe | DMI DINI + DWD ICON-EU | `LIBREWXR_EU_NWP_PROFILE` |
| Caribbean | Météo-France AROME Antilles | `LIBREWXR_AROME_ANTILLES_ENABLED` |
| South America (Southern Cone) | SMN WRF-DET | `LIBREWXR_WRF_SMN_ENABLED` |
| Japan / E. Asia | JMA MSM | `LIBREWXR_JMA_MSM_ENABLED` |
| Global fallback | ECMWF IFS | `LIBREWXR_ECMWF_ENABLED` |

### Satellite

NOAA GMGSI composite (GOES, Meteosat, Himawari). Daytime visible over longwave IR with natural terminator crossfade. Hourly cadence. Coverage: ±72.7° latitude.

---

## RainViewer v2 API Compatibility

LibreWxR is a drop-in replacement for RainViewer v2:

- `/public/weather-maps.json` returns the same structure
- Tile URL path format is identical: `/v2/radar/{timestamp}/{size}/{z}/{x}/{y}/{color}/{smooth}_{snow}.{ext}`
- `color`, `smooth`, `snow` path parameters follow the same conventions
- JSON metadata format is identical (version, generated, host, radar.past/nowcast arrays)
- Migration is a URL swap: replace `api.rainviewer.com` with `api.librewxr.net` (or self-hosted URL)

Key improvements over degraded RainViewer free tier:
- Max zoom 12 (vs. 7)
- 13 color schemes (vs. 1 — Universal Blue only)
- Nowcast frames (discontinued by RainViewer)
- Satellite imagery (discontinued by RainViewer)
- WebP format support (RainViewer: PNG only)
- No rate limit on self-hosted instances (RainViewer: 100 req/IP/min)

---

## Attribution

Required: `"LibreWxR (https://librewxr.net/) — Data: CC-BY-4.0"`

CC-BY-4.0 requires credit to LibreWxR for the data. The AGPL-3.0 license applies to the software source code.

---

## Deployment Modes

**Single mode** (default): One process handles all fetching, rendering, and HTTP serving. Suitable for small deployments.

**Multi mode**: Separates data pipeline from tile renderers via memmap files on a shared volume. Enables multi-core parallelism. Set `COMPOSE_PROFILES=multi` and configure `LIBREWXR_CACHE_DIR`.

RAM requirements:
- ~3-4 GB (US + ECMWF only)
- ~9-10 GB (full regional config)
