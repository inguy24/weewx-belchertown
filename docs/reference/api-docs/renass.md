# ReNaSS / EPOS-France — API Reference

**Source:** https://api.franceseisme.fr/

**Last verified:** 2026-05-11 (live capture from `weather-dev`)

## Authentication

**No API key required.** Public service operated by BCSF-Rénass (Bureau Central Sismologique Français) at the Université de Strasbourg, exposed under the EPOS-France national infrastructure. License: CC BY 4.0.

## Base URL

```
https://api.franceseisme.fr/fdsnws/event/1
```

**The legacy endpoint at `https://renass.unistra.fr/fdsnws/event/1/query` returns HTTP 404** since the EPOS-France migration. Use the `api.franceseisme.fr` host. The Belchertown integration (issue #561, 2024) cited the legacy URL — outdated.

ReNaSS implements the FDSN Event Web Service v1 spec with a JSON convenience flavor (FDSN GeoJSON shape). We use the JSON flavor.

## Endpoints

### Query

- **Path:** `/query`
- **Method:** GET
- **Useful parameters** (full FDSN-Event spec: https://www.fdsn.org/webservices/):

  | Name | Type | Notes |
  |---|---|---|
  | `format` | string | `json` (used here), `xml` (QuakeML), `text`. **`json` is what we use.** |
  | `starttime` / `endtime` | ISO 8601 | Time window. |
  | `minmag` / `maxmag` | number | Magnitude filter. |
  | `latitude` / `longitude` / `maxradius` | number / number / number | Geographic radius filter (degrees). Also accepts `maxradiuskm`. |
  | `minlatitude` / `maxlatitude` / `minlongitude` / `maxlongitude` | number | Bounding box. |
  | `limit` | int | Max results. |
  | `orderby` | string | `time` (default), `time-asc`, `magnitude`, `magnitude-asc`. |

- **Example request:**
  ```
  curl "https://api.franceseisme.fr/fdsnws/event/1/query?format=json&limit=10&orderby=time&latitude=48.5&longitude=7.7&maxradius=5"
  ```

- **Example response (live capture 2026-05-11, 2 events):**
  ```json
  {
    "type": "FeatureCollection",
    "features": [
      {
        "id": "fr2026trxulp",
        "type": "Feature",
        "properties": {
          "type": null,
          "time": "2026-05-11T15:01:24.620000Z",
          "description": {
            "fr": "Évènement de magnitude 1.4, proche de Mamoudzou",
            "en": "Event of magnitude 1.4, near Mamoudzou"
          },
          "depth": 41.23,
          "url": {
            "fr": "https://renass.unistra.fr/fr/evenements/fr2026trxulp",
            "en": "https://renass.unistra.fr/en/events/fr2026trxulp"
          },
          "latitude": -12.8563,
          "longitude": 45.5093,
          "automatic": true,
          "mag": 1.429053809,
          "magType": "ML"
        },
        "geometry": {
          "type": "Point",
          "coordinates": [45.5093, -12.8563, -41.23]
        }
      },
      {
        "id": "fr2026trxhpm",
        "type": "Feature",
        "properties": {
          "type": "quarry blast",
          "time": "2026-05-11T12:36:37.713492Z",
          "description": {
            "fr": "Tir de carrière de magnitude 1.5, proche de Brive-la-Gaillarde",
            "en": "Quarry blast of magnitude 1.5, near Brive-la-Gaillarde"
          },
          "depth": 0.0,
          "url": {
            "fr": "https://renass.unistra.fr/fr/evenements/fr2026trxhpm",
            "en": "https://renass.unistra.fr/en/events/fr2026trxhpm"
          },
          "latitude": 45.10512924,
          "longitude": 1.452506304,
          "automatic": false,
          "mag": 1.54834994,
          "magType": "MLv"
        },
        "geometry": {
          "type": "Point",
          "coordinates": [1.452506304, 45.10512924, -0.0]
        }
      }
    ]
  }
  ```

## Field shape (per Feature)

- `id` — top-level Feature ID (e.g. `"fr2026trxulp"`). **Only id source — no `properties.publicID` / `properties.unid`.**
- `geometry.coordinates` — `[lon, lat, -depth_km]` (depth uses GeoJSON convention: negative below surface).
- `properties.latitude` / `properties.longitude` — duplicates of geometry coordinates 1/0; either source works.
- `properties.depth` — kilometers below surface, **positive** (opposite sign from `geometry.coordinates[2]`).
- `properties.time` — ISO 8601 UTC string. No conversion needed.
- `properties.mag` — magnitude.
- `properties.magType` — **camelCase**, e.g. `"ML"`, `"MLv"`. Differs from EMSC `magtype` (lowercase).
- `properties.description` — **bilingual object** `{fr: str, en: str}`. Canonical `place` reads `.en`; `.fr` routes through `extras`.
- `properties.url` — **bilingual object** `{fr: str, en: str}` of detail-page URLs. Canonical `url` reads `.en`; `.fr` routes through `extras`.
- `properties.automatic` — boolean: `true` = unreviewed/automatic origin, `false` = reviewed by an analyst. Canonical `status` derives: `true → "automatic"`, `false → "reviewed"`.
- `properties.type` — string or `null`: `null` / `"earthquake"` / `"quarry blast"` / `"explosion"`. Routes through `extras`. **Note:** the `/earthquakes` endpoint passes through quarry blasts and explosions just like USGS does (USGS `properties.type` is also a passthrough); operators who want only earthquakes filter at the dashboard layer.

No `tsunami`, no `felt`, no `mmi`, no `alert` — France isn't subject to large tsunami-generating events the way USGS-coverage areas are; PAGER-equivalent intensity assessments aren't published.

## Quirks / gotchas

- **Endpoint host changed.** `renass.unistra.fr/fdsnws/...` returns 404; new host is `api.franceseisme.fr`. Pre-existing references in older docs are stale.
- **`description` and `url` are objects, not strings.** Pick the locale at canonical-ingest time. We use `.en` for canonical fields and route `.fr` to `extras`.
- **`type` includes non-earthquake events.** Quarry blasts and explosions are tagged in `properties.type`; they appear in the same feed as earthquakes. Filter at the consumer if needed.
- **Depth sign mismatch between `geometry.coordinates[2]` and `properties.depth`.** Same pattern as EMSC — use `properties.depth` for canonical.
- **Detail-page URLs still point at `renass.unistra.fr`** (not `api.franceseisme.fr`). The website stayed on the `renass.unistra.fr` host even though the API moved.
- **Time precision varies.** Examples show 6-decimal microseconds (`"2026-05-11T15:01:24.620000Z"`) and microsecond-precision events (`"2026-05-11T12:36:37.713492Z"`). Parse flexibly.

## Rate limits

No published rate limit. Polite-use ask. The realtime feed updates every few minutes. A 60–120 s cache is reasonable.

## License

CC BY 4.0 — attribution required: "Earthquake data from BCSF-Rénass / EPOS-France (https://api.franceseisme.fr/), CC BY 4.0".

## References

- [EPOS-France Seismological Data Portal](https://seismology.resif.fr/)
- [BCSF-Rénass website](https://renass.unistra.fr/)
- [FDSN-Event Web Service spec](https://www.fdsn.org/webservices/)
- [Belchertown ReNaSS integration discussion (legacy URL — outdated)](https://github.com/poblabs/weewx-belchertown/issues/561)
