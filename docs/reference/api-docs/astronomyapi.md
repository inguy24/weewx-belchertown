# AstronomyAPI.com — API Reference

**Source:** https://astronomyapi.com/
**Documentation:** https://docs.astronomyapi.com/
**Last verified:** 2026-06-03 (research + credential setup)

## Authentication

HTTP Basic Auth on all endpoints.
- Header: `Authorization: Basic base64(app_id:app_secret)`
- Free tier: 3 requests/second, no documented daily limit
- Coverage: through 2050, max 366 days per query

## Endpoints

### 1. Bodies Events — `GET /api/v2/bodies/events/:body`

Eclipse data for sun or moon. **This is the primary endpoint for Clear Skies almanac.**

**Supported bodies:** `sun`, `moon`

**Query parameters (ALL required):**

| Param | Format | Example |
|---|---|---|
| `latitude` | float | `38.775867` |
| `longitude` | float | `-84.39733` |
| `elevation` | int (meters) | `0` |
| `from_date` | YYYY-MM-DD | `2026-01-01` |
| `to_date` | YYYY-MM-DD | `2026-12-31` |
| `time` | HH:MM:SS | `00:00:00` |

**Optional query parameters:**

| Param | Default | Options | Notes |
|---|---|---|---|
| `output` | `table` | `rows`, `table` | Controls response structure (see below) |

**Response format:** Two formats available via `output` param:

- `output=rows` → `data.rows[].body` + `data.rows[].events[]` — flat list, easier to parse
- `output=table` (default) → `data.table.rows[].entry` + `data.table.rows[].cells[]` — tabular format

**Clear Skies uses `output=rows`** for simpler parsing.

**IMPORTANT: The API only returns eclipses visible from the observer's location.** If an eclipse is not visible from the given latitude/longitude (e.g., a solar eclipse whose partial shadow doesn't reach the observer), it will not appear in the response. There is no way to query for all global eclipses — the location parameters are required and the API filters by them. (Verified 2026-06-04: Aug 12, 2026 total solar eclipse not returned for Huntington Beach, CA (33.66°N, -117.98°W) but returned as partial for NYC (40.7°N, -74.0°W).)

**Response (output=rows, body=moon — lunar eclipses):**
```json
{
  "data": {
    "dates": {
      "from": "2026-01-01T00:00:00.000-05:00",
      "to": "2026-12-31T00:00:00.000-05:00"
    },
    "observer": {
      "location": { "longitude": -84.39733, "latitude": 38.775867, "elevation": 0 }
    },
    "rows": [{
      "body": { "id": "moon", "name": "Moon" },
      "events": [{
        "type": "total_lunar_eclipse",
        "eventHighlights": {
          "penumbralStart": { "date": "2026-03-03T01:45:00.000-05:00", "altitude": 42.3 },
          "partialStart":   { "date": "2026-03-03T02:50:00.000-05:00", "altitude": 35.1 },
          "fullStart":      { "date": "2026-03-03T03:55:00.000-05:00", "altitude": 25.8 },
          "peak":           { "date": "2026-03-03T04:33:00.000-05:00", "altitude": 20.2 },
          "fullEnd":        { "date": "2026-03-03T05:10:00.000-05:00", "altitude": 14.7 },
          "partialEnd":     { "date": "2026-03-03T06:15:00.000-05:00", "altitude": 5.3 },
          "penumbralEnd":   { "date": "2026-03-03T07:20:00.000-05:00", "altitude": -3.1 }
        },
        "extraInfo": { "obscuration": 1.0 }
      }]
    }]
  }
}
```

**Event types:**
- Lunar: `penumbral_lunar_eclipse`, `partial_lunar_eclipse`, `total_lunar_eclipse`
- Solar: `partial_solar_eclipse`, `annular_solar_eclipse`, `total_solar_eclipse`

**Solar eclipse eventHighlights fields:**
`partialStart`, `totalStart` (null if not total/annular), `peak`, `totalEnd` (null), `partialEnd`

**Lunar eclipse eventHighlights fields:**
`penumbralStart`, `partialStart`, `fullStart` (null if not total), `peak`, `fullEnd` (null), `partialEnd`, `penumbralEnd`

**Each highlight:** `{ "date": "ISO8601-with-offset", "altitude": float }` or `null`

**extraInfo:** `{ "obscuration": float }` — 0.0 to 1.0 scale

**CRITICAL: Location-filtered results.** The API ONLY returns eclipses visible from the observer's location. If an eclipse's shadow does not reach the observer, it is omitted entirely from the response. There is no global/unfiltered mode. (Corrected 2026-06-04 — previous version incorrectly stated "returns ALL global eclipses".)

**Altitude at peak:** For eclipses that ARE returned, `peak.altitude` indicates how high in the sky the eclipse appears. Negative altitude means the eclipse phase occurs below the horizon (the event is partially visible but that specific phase is not).

**Determining totality path (solar):** If `totalStart` is non-null, the observer IS within the path of totality/annularity.

---

### 2. Bodies Positions — `GET /api/v2/bodies/positions/:body`

Position data for celestial bodies. Can query all bodies at once or specific ones.

**Supported bodies:** `sun`, `moon`, `mercury`, `venus`, `mars`, `jupiter`, `saturn`, `uranus`, `neptune`, `pluto`

**Query parameters:** Same as Events (all required).

**Response:**
```json
{
  "data": {
    "table": {
      "rows": [{
        "entry": { "id": "2026-06-03T00:00:00" },
        "cells": [{
          "date": "2026-06-03T00:00:00",
          "id": "venus",
          "name": "Venus",
          "distance": {
            "fromEarth": { "au": "0.71234", "km": "106560000" }
          },
          "position": {
            "horizontal": {
              "altitude": { "degrees": 35.2, "string": "35° 12' 0\"" },
              "azimuth": { "degrees": 220.5, "string": "220° 30' 0\"" }
            },
            "equatorial": {
              "rightAscension": { "hours": 8.42, "string": "8h 25m 12s" },
              "declination": { "degrees": 18.7, "string": "18° 42' 0\"" }
            },
            "constellation": { "id": "cnc", "short": "Cnc", "name": "Cancer" }
          },
          "extraInfo": {
            "elongation": "46.2",
            "magnitude": "-4.1",
            "phase": { "angle": "89.5", "fraction": "0.51" }
          }
        }]
      }]
    }
  }
}
```

**Key fields:**
- `position.horizontal.altitude/azimuth` — local sky coordinates
- `position.equatorial.rightAscension/declination` — celestial coordinates
- `position.constellation` — current constellation
- `extraInfo.magnitude` — apparent brightness (lower = brighter; Venus ~-4, Jupiter ~-2)
- `extraInfo.elongation` — angular separation from Sun
- `extraInfo.phase` — phase angle and illuminated fraction (Moon)

**LIMITATION:** Does NOT return rise/set times. Our existing Skyfield computation handles rise/set.

---

### 3. Moon Phase — `POST /api/v2/studio/moon-phase`

Generates a moon phase image.

**Request body:**
```json
{
  "format": "png",
  "style": {
    "moonStyle": "sketch",
    "backgroundStyle": "stars",
    "backgroundColor": "red",
    "headingColor": "white",
    "textColor": "red"
  },
  "observer": {
    "latitude": 38.775867,
    "longitude": -84.39733,
    "date": "2026-06-03"
  },
  "view": {
    "type": "portrait-simple",
    "orientation": "south-up"
  }
}
```

**Response:**
```json
{
  "data": {
    "imageUrl": "https://widgets.astronomyapi.com/moon-phase/generated/[id].png"
  }
}
```

**Note:** Returns a URL to a hosted image, not the image data itself. The URL is temporary. Format: PNG or SVG. Does NOT return phase name, illumination%, or age as data — image only.

**Clear Skies decision:** We keep our own SVG crescent rendering (controllable for light/dark themes) rather than using this endpoint.

---

### 4. Star Chart — `POST /api/v2/studio/star-chart`

Generates a star chart image. Not currently used by Clear Skies.

**Request body:**
```json
{
  "observer": {
    "latitude": 38.775867,
    "longitude": -84.39733,
    "date": "2026-06-03"
  },
  "view": {
    "type": "constellation",
    "parameters": { "constellation": "ori" }
  },
  "style": "default"
}
```

Styles: `default`, `inverted`, `navy`, `red`

---

### 5. Search — `GET /api/v2/search`

Search for stars and deep-space objects. Not currently used by Clear Skies.

Query params: `term`, `match_type` (fuzzy|exact), `limit`, `offset`

---

## Rate Limits & Pricing

| Tier | Cost | Limit |
|---|---|---|
| Free | $0, no credit card | 3 requests/second |
| Paid | Unknown | Higher limits |

No documented daily/monthly caps on the free tier — only per-second rate limiting.

## Clear Skies Usage

We make **2 API calls per cache refresh** (one for lunar eclipses, one for solar eclipses), cached for 7+ days server-side. At 2 calls per week, free tier is more than sufficient.

**Env vars (ADR-027):**
- `WEEWX_CLEARSKIES_ASTRONOMYAPI_APP_ID`
- `WEEWX_CLEARSKIES_ASTRONOMYAPI_APP_SECRET`

**Graceful degradation:** If credentials are not configured or API is unreachable, eclipse endpoints return Skyfield-detected dates and types only (no contact times, no visibility). Dashboard renders cards without time details.
