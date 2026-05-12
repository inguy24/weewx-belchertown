# NOAA MRMS (Multi-Radar/Multi-Sensor) — radar provider notes

Source for Clear Skies `providers/radar/noaa_mrms.py`. Captured 2026-05-11.

## Endpoint shape

WMS 1.3.0 service backed by ArcGIS Server ImageServer:

- **Base reflectivity (time-enabled):** `https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer`
- REST equivalent (for non-WMS clients): `https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer`

The WMS endpoint is the Clear Skies path (Leaflet `L.tileLayer.wms()`).

## WMS request shape

- `SERVICE=WMS`, `VERSION=1.3.0`, `REQUEST=GetMap`
- `LAYERS=radar_base_reflectivity_time` (verified verbatim from live GetCapabilities 2026-05-12; original guess of `0` from "ArcGIS image services typically expose layer id 0" was wrong — corrected in 3b-14 lead-direct `f2362ee`)
- `CRS=EPSG:3857`
- `BBOX=...`, `WIDTH=256`, `HEIGHT=256`
- `FORMAT=image/png`
- `TIME=YYYY-MM-DDTHH:MM:SSZ` (UTC ISO-8601)

GetCapabilities URL: `…/WMSServer?service=WMS&version=1.3.0&request=GetCapabilities`

## Frame index source

WMS GetCapabilities returns the layer's TIME dimension:
- Window: 4 hours rolling.
- Cadence: every 5 minutes (data updates every ~10 min upstream).
- Format: ISO-8601 UTC.

Parse the `<Dimension name="time">` element same as `iem_nexrad`. All frames are `past`; latest is `current`. No nowcast.

## Frame cadence

5-min interval; 4-hour rolling window → 48 frames available.

## Geographic coverage

CONUS + Alaska + Hawaii + Puerto Rico + Guam + Caribbean. Use this provider when the operator station lat/lon falls outside `iem_nexrad`'s CONUS-only footprint.

## License / attribution

NOAA / National Weather Service. Public domain (US federal data). Attribution recommended: "NOAA/NWS — Multi-Radar/Multi-Sensor (MRMS)."

## Source

- WMS GetCapabilities: https://mapservices.weather.noaa.gov/eventdriven/services/radar/radar_base_reflectivity_time/ImageServer/WMSServer?request=GetCapabilities&service=WMS
- MRMS project: https://www.nssl.noaa.gov/projects/mrms/
- Service iteminfo: https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer
