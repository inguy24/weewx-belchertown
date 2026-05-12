# MSC GeoMet (Environment and Climate Change Canada) — radar provider notes

Source for Clear Skies `providers/radar/msc_geomet.py`. Captured 2026-05-11.

## Endpoint shape

WMS 1.3.0 (Environment Canada's GeoMet service):

- **WMS endpoint:** `https://geo.weather.gc.ca/geomet`
- Anonymous, no auth, no key.

## WMS request shape

- `SERVICE=WMS`, `VERSION=1.3.0`, `REQUEST=GetMap`
- `LAYERS=RADAR_1KM_RRAI` (rain — recommended default for live radar tab) or `RADAR_1KM_RSNO` (snow).
- **Correction 2026-05-11:** the original capture of this file claimed `RADAR_1KM_RDPR` (dual-pol QPE) was a "recommended default" — that layer is NOT present in live GeoMet capabilities; only RRAI + RSNO exist as radar layers. RDPR returns "Layer not available." Corrected in 3b-14 lead-direct `f2362ee`.
- `CRS=EPSG:3857`
- `BBOX=...`, `WIDTH=256`, `HEIGHT=256`
- `FORMAT=image/png`
- `TIME=YYYY-MM-DDTHH:MM:SSZ` (UTC ISO-8601)

GetCapabilities URL with layer filter: `https://geo.weather.gc.ca/geomet?service=WMS&version=1.3.0&request=GetCapabilities&layer=RADAR_1KM_RDPR`

## Frame index source

GetCapabilities `<Dimension name="time">` for the chosen layer. Cadence is 6 minutes (Canadian radar network standard). Rolling window varies by product; typically ~3 hours.

All frames `past`; latest `current`. No nowcast.

## Frame cadence

6 minutes (Canadian radar network).

## Geographic coverage

The national mosaic covers the entire Canadian landmass and overlaps southern Canada with the US border. Computed over the **North American domain** at 1 km horizontal resolution, including all Canadian and American radars in the network (up to 180 contributing radars). Use for Canadian station lat/lon.

## License / attribution

Open Government Licence – Canada. Free anonymous access; commercial use allowed with attribution. Required text: "Contains information licensed under the Open Government Licence – Canada / Contient des informations sous licence du gouvernement ouvert – Canada" (or shorter operator note: "Environment and Climate Change Canada — MSC GeoMet").

## Source

- MSC GeoMet readme: https://eccc-msc.github.io/open-data/msc-geomet/readme_en/
- WMS GetCapabilities (RDPR sample): https://geo.weather.gc.ca/geomet?service=WMS&version=1.3.0&request=GetCapabilities&layer=RADAR_1KM_RDPR
- ECCC-MSC on GitHub: https://github.com/ECCC-MSC
