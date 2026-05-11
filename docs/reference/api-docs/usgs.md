# USGS Earthquake Catalog — API Reference

**Source:** https://earthquake.usgs.gov/fdsnws/event/1/

**Last verified:** 2026-05-11 (live capture from `weather-dev`)

## Authentication

**No API key required.** Public service, no auth, no quota signup. USGS asks polite use only — no published rate limit, but excessive load may be blocked at the edge.

## Base URL

```
https://earthquake.usgs.gov/fdsnws/event/1
```

This implements the FDSN Event Web Service v1 spec (https://www.fdsn.org/webservices/) plus USGS-specific extensions (the `?format=geojson` shape used by the public earthquake feed).

## Endpoints

### Query

- **Path:** `/query`
- **Method:** GET
- **Useful parameters** (full set: https://earthquake.usgs.gov/fdsnws/event/1/):

  | Name | Type | Notes |
  |---|---|---|
  | `format` | string | `geojson` (used here), `xml`, `text`, `csv`, `kml`. **`geojson` is what we use** — the FDSN-standard `xml` flavor is QuakeML, heavier to parse. |
  | `starttime` / `endtime` | ISO 8601 | Time window. Defaults to the last 30 days if omitted. |
  | `minmagnitude` / `maxmagnitude` | number | Magnitude filter. |
  | `latitude` / `longitude` / `maxradiuskm` | number / number / number | Geographic radius filter. **Required together** if any present. |
  | `minlatitude` / `maxlatitude` / `minlongitude` / `maxlongitude` | number | Bounding-box filter (alternative to radius). |
  | `limit` | int | Max results (default 20000, max 20000). |
  | `orderby` | string | `time` (default), `time-asc`, `magnitude`, `magnitude-asc`. |
  | `eventid` | string | Fetch a single event by ID. |

- **Example request:**
  ```
  curl "https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&latitude=47.6&longitude=-122.3&maxradiuskm=500&minmagnitude=2.5&limit=10&orderby=time"
  ```

- **Example response (live capture 2026-05-11, 2 events):**
  ```json
  {
    "type": "FeatureCollection",
    "metadata": {
      "generated": 1778517011000,
      "url": "https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&minmagnitude=4.5&limit=2&orderby=time",
      "title": "USGS Earthquakes",
      "status": 200,
      "api": "2.4.0",
      "limit": 2,
      "offset": 1
    },
    "features": [
      {
        "type": "Feature",
        "properties": {
          "mag": 5.2,
          "place": "72 km NW of Malango, Solomon Islands",
          "time": 1778492931604,
          "updated": 1778495736750,
          "tz": null,
          "url": "https://earthquake.usgs.gov/earthquakes/eventpage/us6000swvm",
          "detail": "https://earthquake.usgs.gov/fdsnws/event/1/query?eventid=us6000swvm&format=geojson",
          "felt": 4,
          "cdi": 2.7,
          "mmi": null,
          "alert": null,
          "status": "reviewed",
          "tsunami": 0,
          "sig": 417,
          "net": "us",
          "code": "6000swvm",
          "ids": ",us6000swvm,usauto6000swvm,",
          "sources": ",us,usauto,",
          "types": ",dyfi,internal-moment-tensor,moment-tensor,origin,phase-data,",
          "nst": 84,
          "dmin": 0.759,
          "rms": 0.6,
          "gap": 49,
          "magType": "mww",
          "type": "earthquake",
          "title": "M 5.2 - 72 km NW of Malango, Solomon Islands"
        },
        "geometry": {
          "type": "Point",
          "coordinates": [159.1915, -9.2967, 10]
        },
        "id": "us6000swvm"
      }
    ],
    "bbox": [-68.633, -23.046, 10, 159.1915, -9.2967, 112.298]
  }
  ```

## Field shape (per Feature)

- `id` — top-level Feature ID (e.g. `"us6000swvm"`). Stable across re-publishes.
- `geometry.coordinates` — `[lon, lat, depth_km]`. Depth is positive km below surface (no GeoJSON-convention sign flip).
- `properties.time` / `properties.updated` — **epoch milliseconds** (not ISO 8601). Convert at ingest.
- `properties.tsunami` — `0` or `1` (integer, not boolean). Convert at ingest.
- `properties.alert` — `null` or one of `"green"`, `"yellow"`, `"orange"`, `"red"` (USGS PAGER level).
- `properties.status` — `"automatic"`, `"reviewed"`, or `"deleted"`.
- `properties.magType` — magnitude type code (e.g. `"mww"`, `"mb"`, `"ml"`, `"md"`).
- `properties.type` — event type — usually `"earthquake"`; can be `"explosion"`, `"quarry blast"`, etc.

## Quirks / gotchas

- **Time is epoch ms, not ISO.** The `format=geojson` flavor uses milliseconds-since-epoch for `time` and `updated`. The `format=xml` (QuakeML) flavor uses ISO 8601. We use GeoJSON, so convert: `datetime.fromtimestamp(ms / 1000, tz=UTC)`.
- **`tsunami` is `0`/`1`, not `false`/`true`.** Cast at ingest.
- **`tz` is deprecated.** Always `null` since 2021. Ignore.
- **`alert` is null when no PAGER assessment exists** (small or shallow events). Most events have `null` alert.
- **`mmi` is the USGS *estimate* of shaking intensity** (Modified Mercalli Intensity, derived from felt reports + ShakeMap), not a measured value. Often `null` for small events.
- **`cdi` is "Community Decimal Intensity"** — the user-reported version of MMI. Not in our canonical entity; routes through `extras` if at all.
- **Large default windows.** Without `starttime`, you get the last 30 days — possibly many thousands of events. Always set a window or filter.

## Rate limits

No published rate limit. USGS infrastructure is generous; the canonical politeness ask is "don't poll faster than the data updates" (USGS feeds update every few minutes). Cache per [ADR-017](../../decisions/ADR-017-provider-response-caching.md); an 60–120 s TTL is reasonable.

## License

Public domain (US federal government work).

## References

- [USGS FDSN-Event API root](https://earthquake.usgs.gov/fdsnws/event/1/)
- [USGS GeoJSON Summary Format spec](https://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson.php)
- [FDSN-Event Web Service spec](https://www.fdsn.org/webservices/)
