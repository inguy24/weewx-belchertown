# GeoNet (NZ) — API Reference

**Source:** https://api.geonet.org.nz/

**Last verified:** 2026-05-11 (live capture from `weather-dev`)

## Authentication

**No API key required.** Public service operated by GNS Science (NZ government). No quota signup. License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

## Base URL

```
https://api.geonet.org.nz
```

GeoNet exposes its own GeoJSON variant — *not* a strict FDSN-Event implementation. The shape is GeoJSON FeatureCollection, but field names and parameters differ from USGS/EMSC/ReNaSS.

## Endpoints

### Recent quakes

- **Path:** `/quake`
- **Method:** GET
- **Accept header (optional):** `application/vnd.geo+json;version=2`
- **Parameters:**

  | Name | Type | Notes |
  |---|---|---|
  | `MMI` | int | **Required.** Filter to events at or above this Modified Mercalli Intensity (NZ-calculated). Range: `-1` (all events including unmeasured), `0`–`8`. Most operators want `MMI=3` (just-perceptible) or `MMI=4` (clearly felt). |

- **Returns:** Recent quakes from the last 7 days at or above the requested MMI.

- **Example request:**
  ```
  curl "https://api.geonet.org.nz/quake?MMI=3"
  ```

- **Example response (live capture 2026-05-11):**
  ```json
  {
    "type": "FeatureCollection",
    "features": [
      {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [175.256698608, -38.977085114]
        },
        "properties": {
          "publicID": "2026p353000",
          "time": "2026-05-11T14:38:39.296Z",
          "depth": 20.33428955078125,
          "magnitude": 2.4993398757078116,
          "mmi": 3,
          "locality": "10 km south of Taumarunui",
          "quality": "best"
        }
      }
    ]
  }
  ```

### Single quake

- **Path:** `/quake/{publicID}`
- **Method:** GET
- **Returns:** A single Feature for the named event ID.

### History (aftershocks etc.)

- **Path:** `/quake/history/{publicID}`
- **Method:** GET
- **Returns:** A FeatureCollection of every revision of the named event (parameter changes as the event is reviewed).

## Field shape (per Feature)

- **No top-level `id`** on the Feature. The canonical event ID is `properties.publicID`.
- `geometry.coordinates` — **`[lon, lat]` only — no depth element**. Depth is at `properties.depth`.
- `properties.time` — ISO 8601 UTC string (e.g. `"2026-05-11T14:38:39.296Z"`). No conversion needed.
- `properties.depth` — kilometers below surface, positive.
- `properties.magnitude` — number; magnitude type is implicitly `ml` (local magnitude — GeoNet's house default; not a separately-named field).
- `properties.mmi` — **lowercase**. NZ-calculated Modified Mercalli Intensity. Integer value.
- `properties.locality` — human-readable place description (e.g. `"10 km south of Taumarunui"`).
- `properties.quality` — `"best"`, `"preliminary"`, `"automatic"`, or `"deleted"`.

No `tsunami`, no `felt`, no `alert`, no `magnitudeType` field, no `url` field. Detail-page URLs are constructed from `publicID` (`https://www.geonet.org.nz/earthquake/{publicID}`).

## Quirks / gotchas

- **`mmi` is lowercase.** Not `MMI` like the query parameter. Earlier docs (and our own canonical-data-model pre-2026-05-11) had this wrong as `MMI`.
- **No depth in `geometry.coordinates`.** Two-element coordinates only. Depth lives in `properties.depth`.
- **No `magnitudeType` field.** Treat as `"ml"` (NZ default). Do not invent the field.
- **No detail URL in response.** Construct from `publicID`.
- **MMI is required.** The `/quake` endpoint rejects requests without `MMI`. Pass `MMI=-1` for all events.
- **7-day rolling window.** No `starttime`/`endtime` parameters; the endpoint returns the last 7 days at or above the requested MMI.

## Rate limits

No published rate limit; GeoNet asks polite use. The data is published with seconds-to-minutes latency. A 60 s cache is reasonable.

## License

CC BY 4.0 — attribution required: "Data from GeoNet (https://www.geonet.org.nz/), CC BY 4.0".

## References

- [GeoNet API root](https://api.geonet.org.nz/)
- [GeoNet quake endpoint docs](https://api.geonet.org.nz/#quake)
- [GeoNet attribution guidance](https://www.geonet.org.nz/about/disclaimer)
