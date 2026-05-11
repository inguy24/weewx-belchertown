# EMSC SeismicPortal — API Reference

**Source:** https://www.seismicportal.eu/webservices.html

**Last verified:** 2026-05-11 (live capture from `weather-dev`)

## Authentication

**No API key required.** Public service operated by the European-Mediterranean Seismological Centre. License: CC BY 4.0.

## Base URL

```
https://www.seismicportal.eu/fdsnws/event/1
```

EMSC implements the FDSN Event Web Service v1 spec with a JSON convenience flavor (in addition to the standard QuakeML XML). We use the JSON flavor.

## Endpoints

### Query

- **Path:** `/query`
- **Method:** GET
- **Useful parameters** (full FDSN-Event spec: https://www.fdsn.org/webservices/):

  | Name | Type | Notes |
  |---|---|---|
  | `format` | string | `json` (used here), `xml` (QuakeML), `text`. **`json` is what we use** — JSON is much lighter than QuakeML for small result sets. |
  | `starttime` / `endtime` | ISO 8601 | Time window. |
  | `minmag` / `maxmag` | number | Magnitude filter (note: `minmag`/`maxmag`, not USGS's `minmagnitude`/`maxmagnitude`). |
  | `lat` / `lon` / `maxradius` | number / number / number | Geographic radius filter (in degrees, not km). EMSC also accepts `maxradiuskm`. |
  | `minlat` / `maxlat` / `minlon` / `maxlon` | number | Bounding box. |
  | `limit` | int | Max results. |
  | `orderby` | string | `time` (default), `time-asc`, `magnitude`, `magnitude-asc`. |
  | `eventid` | string | Single-event lookup. |

- **Example request:**
  ```
  curl "https://www.seismicportal.eu/fdsnws/event/1/query?format=json&minmag=2.5&limit=10&orderby=time"
  ```

- **Example response (live capture 2026-05-11, 2 events):**
  ```json
  {
    "type": "FeatureCollection",
    "metadata": {"count": 2},
    "features": [
      {
        "type": "Feature",
        "geometry": {
          "type": "Point",
          "coordinates": [-123.7113, 39.945, -3.4]
        },
        "id": "20260511_0000271",
        "properties": {
          "source_id": "1993302",
          "source_catalog": "EMSC-RTS",
          "lastupdate": "2026-05-11T16:26:29.743232Z",
          "time": "2026-05-11T16:24:46.6Z",
          "flynn_region": "NORTHERN CALIFORNIA",
          "lat": 39.945,
          "lon": -123.7113,
          "depth": 3.4,
          "evtype": "ke",
          "auth": "NC",
          "mag": 2.7,
          "magtype": "md",
          "unid": "20260511_0000271"
        }
      }
    ]
  }
  ```

## Field shape (per Feature)

- `id` — top-level Feature ID (same as `properties.unid`). Either reads correctly.
- `geometry.coordinates` — `[lon, lat, -depth_km]` (depth uses GeoJSON convention: negative below surface). **Use `properties.depth` for the canonical positive km value, not `geometry.coordinates[2]`.**
- `properties.lat` / `properties.lon` — duplicates of geometry coordinates 1/0; either source works.
- `properties.time` — ISO 8601 UTC string. No conversion needed.
- `properties.depth` — kilometers below surface, **positive** (opposite sign from `geometry.coordinates[2]`).
- `properties.mag` — magnitude.
- `properties.magtype` — **lowercase**, e.g. `"md"`, `"ml"`, `"mb"`, `"mw"`, sometimes plain `"m"`. Differs from USGS `magType` (camelCase) and ReNaSS `magType` (camelCase).
- `properties.flynn_region` — Flinn-Engdahl seismic region name (e.g. `"NORTHERN CALIFORNIA"`, `"CERAM SEA, INDONESIA"`). Used as canonical `place`.
- `properties.evtype` — event-type code: `"ke"` (known earthquake), `"se"` (suspected explosion), etc.
- `properties.auth` — publishing agency code (`"NC"`, `"BMKG"`, etc.).
- `properties.unid` — EMSC unique ID (same as Feature `id`).
- `properties.source_id` / `properties.source_catalog` — upstream catalog provenance.
- `properties.lastupdate` — ISO 8601 UTC last-revised timestamp.

No `tsunami`, no `felt`, no `mmi`, no `alert`, no `status` field. (FDSN-standard `quakeml:status` is in the XML flavor; the JSON flavor drops it. Route the EMSC-specific fields through `extras`.)

No `url` field. Detail-page URLs are constructed from `unid` (`https://www.seismicportal.eu/eventdetails.html?unid={unid}`).

## Quirks / gotchas

- **Depth sign mismatch between `geometry.coordinates[2]` and `properties.depth`.** GeoJSON Z is up, so `coordinates[2] = -3.4` means 3.4 km below surface; `properties.depth = 3.4`. **Always use `properties.depth`.**
- **`magtype` is lowercase, USGS/ReNaSS use camelCase `magType`.** Cross-provider comparison code must canonicalize.
- **`magtype` can be plain `"m"`** when the upstream catalog hasn't tagged a specific magnitude scale. Treat `"m"` as "unknown scale; magnitude value still meaningful."
- **No `status` in the JSON flavor.** Route via `extras` if downstream needs review state — but the QuakeML XML flavor carries it, so an integration that needs status review-state should use the XML path (out of v0.1 scope).
- **`flynn_region` is uppercase** (Flinn-Engdahl convention). Display layer may want title-case.
- **Time precision varies.** The example shows `"2026-05-11T16:24:46.6Z"` — one decimal — and `"2026-05-11T16:26:29.743232Z"` — six decimals. Both are valid ISO 8601; parse with a flexible parser.

## Rate limits

No published rate limit. EMSC asks polite use. The realtime feed updates every few minutes. A 60–120 s cache is reasonable.

## License

CC BY 4.0 — attribution required: "Earthquake data from EMSC (European-Mediterranean Seismological Centre, https://www.emsc-csem.org/), CC BY 4.0".

## References

- [EMSC SeismicPortal services index](https://www.seismicportal.eu/webservices.html)
- [EMSC FDSN-Event docs](https://www.seismicportal.eu/fdsn-wsevent.html)
- [EMSC webservices101 tutorial (field schema)](https://github.com/EMSC-CSEM/webservices101/blob/master/emsc_services/emsc_services.md)
- [FDSN-Event Web Service spec](https://www.fdsn.org/webservices/)
