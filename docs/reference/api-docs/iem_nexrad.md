# Iowa Environmental Mesonet (IEM) NEXRAD — radar provider notes

Source for Clear Skies `providers/radar/iem_nexrad.py`. Captured 2026-05-11.

## Endpoint shape

WMS-T (Web Map Service with Time dimension):

- **N0Q (8-bit base reflectivity, 0.5 dBZ resolution):** `https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0q-t.cgi?`
- **N0R (4-bit pseudo-composite, 5 dBZ resolution):** `https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0r-t.cgi?`

**Use N0Q** as the default. N0R is legacy.

## WMS request shape

WMS 1.1.1 and 1.3.0 supported. Standard query params:

- `SERVICE=WMS`
- `VERSION=1.3.0`
- `REQUEST=GetMap`
- `LAYERS=nexrad-n0q-wmst` (verify via GetCapabilities — likely `nexrad-n0q-wmst` per the IEM mapfile)
- `STYLES=`
- `CRS=EPSG:3857` (Web Mercator; also accepts EPSG:4326, EPSG:900913, EPSG:102100)
- `BBOX={west,south,east,north}` (in CRS units)
- `WIDTH=256`, `HEIGHT=256`
- `FORMAT=image/png`
- `TIME=YYYY-MM-DDTHH:MM:SSZ` (UTC ISO-8601, 5-min aligned)

For Leaflet's `L.tileLayer.wms()` the URL template is the cgi endpoint base; Leaflet composes the query.

## Frame index source

- WMS GetCapabilities returns a `<Dimension name="time">` listing the available TIME instants (5-min cadence).
- URL: `https://mesonet.agron.iastate.edu/cgi-bin/wms/nexrad/n0q-t.cgi?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities`
- Parse the Dimension value (comma-separated ISO timestamps, or start/end/period notation per WMS spec) to populate `RadarFrame` list.
- All frames map to `kind: past` except the latest which is `current`. No nowcast frames available.

## Frame cadence

Every 5 minutes, UTC-aligned. N0Q archive starts 2010-11-13 16:25 UTC; rolling window of recent frames available via GetCapabilities.

## Geographic coverage

CONUS (Continental United States) only. Excludes Alaska, Hawaii, Puerto Rico, Guam — use `noaa_mrms` for those regions.

## License / attribution

No explicit license stated. Iowa State University copyright in page footer. **Attribution recommended:** "NEXRAD imagery courtesy of Iowa Environmental Mesonet."

## Source

- Service index: https://mesonet.agron.iastate.edu/ogc/
- Mosaic docs: https://mesonet.agron.iastate.edu/docs/nexrad_mosaic/
- IEM mapfile (mapserver layer definition): https://github.com/akrherz/iem/blob/main/data/wms/nexrad/n0q-t.map
