# Earthquake provider research

**Date:** 2026-05-05
**Purpose:** field-shape research for the four earthquake providers named in [ADR-024](../decisions/ADR-024-page-taxonomy.md) cat 6 + [ADR-038](../decisions/ADR-038-data-provider-module-organization.md). Feeds the `EarthquakeRecord` canonical entity proposal for [ADR-010](../decisions/ADR-010-canonical-data-model.md).

## Provider summary

| Provider | Coverage | Endpoint | Format | Auth | License |
|---|---|---|---|---|---|
| **USGS** | Global (US-comprehensive, global lower threshold) | `https://earthquake.usgs.gov/fdsnws/event/1/query` | FDSN GeoJSON | None | Public domain |
| **GeoNet** | New Zealand | `https://api.geonet.org.nz/quake` | GeoJSON (`application/vnd.geo+json;version=2`) | None | CC BY 4.0 |
| **EMSC** | Europe-Mediterranean + global | `https://www.seismicportal.eu/fdsnws/event/1/query` | FDSN JSON / XML | None | CC BY 4.0 |
| **ReNaSS** | Mainland France + neighbours | `https://api.franceseisme.fr/fdsnws/event/1/query` | FDSN GeoJSON | None | CC BY 4.0 |

All four are free with no key required. ReNaSS, EMSC, USGS implement the FDSN-Event spec; GeoNet uses its own GeoJSON variant.

## Per-provider field catalogue

### USGS (FDSN GeoJSON)

`properties` object: `mag` (decimal), `place` (string), `time` (long ms), `updated` (long ms), `tz` (int min, deprecated 2021+ — usually null), `url` (string), `detail` (string), `felt` (int|null), `cdi` (decimal|null), `mmi` (decimal|null), `alert` (string|null — green/yellow/orange/red), `status` (string — automatic/reviewed/deleted), `tsunami` (int 0|1), `sig` (int — 0..1000 significance score), `net` (string), `code` (string), `ids` (string — comma list), `sources` (string), `types` (string), `nst` (int|null — station count), `dmin` (decimal|null), `rms` (decimal|null), `gap` (decimal|null — azimuthal gap), `magType` (string — mw/ml/md/etc.), `type` (string — earthquake/explosion/quarry).

`geometry.coordinates`: `[lon, lat, depth_km]` array.

### GeoNet (NZ)

`publicID` (string), `time` (ISO 8601), `depth` (number km), `magnitude` (number), `locality` (string — "X km direction of locality"), `MMI` (number — calculated NZ MMI), `quality` (enum: best / preliminary / automatic / deleted).

Geometry: standard GeoJSON Point [lon, lat].

### EMSC (FDSN JSON)

`unid` (string — unique ID), `lastupdate` (ISO 8601), `time` (ISO 8601 UTC), `lat` (float), `lon` (float), `depth` (float km), `mag` (float), `magtype` (string), `evtype` (string — `ke` earthquake / `se` explosion / etc.), `auth` (string — publishing agency), `source_id` (int), `source_catalog` (string), `flynn_region` (string — Flinn-Engdahl region name).

### ReNaSS (FDSN GeoJSON via api.franceseisme.fr — verified 2026-05-11)

The legacy `https://renass.unistra.fr/fdsnws/event/1/query` cited in Belchertown integration issue #561 (2024) now returns HTTP 404. The new EPOS-France endpoint at `https://api.franceseisme.fr/fdsnws/event/1/query` returns FDSN GeoJSON with this property set (confirmed across 10 captured events): `time` (ISO 8601 UTC), `description` (object `{fr: str, en: str}` — location text in both languages), `url` (object `{fr: str, en: str}` — detail-page URLs in both languages), `mag` (number), `magType` (string camelCase, e.g. `ML`, `MLv`), `depth` (number km, positive below surface), `latitude` (number — also in `geometry.coordinates[1]`), `longitude` (number — also in `geometry.coordinates[0]`), `automatic` (bool — `true`=unreviewed/automatic, `false`=reviewed), `type` (string|null — `"earthquake"`/`"quarry blast"`/`"explosion"`/null).

Geometry: standard GeoJSON Point `[lon, lat, -depth_km]` (depth uses GeoJSON convention with the Z axis pointing up, so depth-below-surface is negative in `geometry.coordinates[2]` — `properties.depth` is the positive km canonical value).

Top-level `Feature.id` carries the canonical event id (e.g. `"fr2026trxulp"`). No `properties.publicID` / `properties.unid` — `Feature.id` is the only id.

## Canonical-field union (proposed)

The four providers share: unique ID, origin time, lat/lon, depth, magnitude, magnitude type, place description, source authority. These are the canonical-required fields.

Useful but provider-specific (must be optional / nullable in canonical): tsunami flag (USGS), felt-report count (USGS), MMI (USGS calculated estimate, GeoNet measured), alert level (USGS PAGER), event-quality status (USGS / GeoNet), URL to detail page (USGS / ReNaSS / GeoNet).

## Citations

- [USGS FDSN-Event API root](https://earthquake.usgs.gov/fdsnws/event/1/)
- [USGS GeoJSON Summary Format spec](https://earthquake.usgs.gov/earthquakes/feed/v1.0/geojson.php)
- [GeoNet API root](https://api.geonet.org.nz/)
- [EMSC SeismicPortal services](https://www.seismicportal.eu/webservices.html)
- [EMSC webservices101 tutorial (field schema)](https://github.com/EMSC-CSEM/webservices101/blob/master/emsc_services/emsc_services.md)
- [ReNaSS FDSN endpoint (per Belchertown issue #561)](https://github.com/poblabs/weewx-belchertown/issues/561)
- [ReNaSS site](https://renass.unistra.fr/)
