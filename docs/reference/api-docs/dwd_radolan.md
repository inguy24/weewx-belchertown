# DWD RADOLAN (Deutscher Wetterdienst — German Weather Service) — radar provider notes

Source for Clear Skies `providers/radar/dwd_radolan.py`. Captured 2026-05-11.

## Endpoint shape

WMS via DWD's GeoServer:

- **WMS endpoint:** `https://maps.dwd.de/geoserver/dwd/wms`
- Anonymous, no auth, no key.

## WMS request shape

- `SERVICE=WMS`, `VERSION=1.3.0`, `REQUEST=GetMap`
- `LAYERS=Niederschlagsradar` (5-min reflectivity composite — recommended default for live radar tab; verified from live GetCapabilities 2026-05-12)
  - Sibling: `RADOLAN-RW` (hourly calibrated precipitation accumulation), also present in live capabilities.
- **Correction 2026-05-11:** the original capture of this file claimed `dwd:RX-Produkt` as the layer; that name is NOT present in live GeoServer capabilities. The real 5-min reflectivity layer is named `Niederschlagsradar` ("precipitation radar" in German). Corrected in 3b-14 lead-direct `f2362ee`.
- `CRS=EPSG:3857`
- `BBOX=...`, `WIDTH=256`, `HEIGHT=256`
- `FORMAT=image/png`
- `TIME=YYYY-MM-DDTHH:MM:SSZ` (UTC ISO-8601)

GetCapabilities URL: `https://maps.dwd.de/geoserver/dwd/wms?service=WMS&version=1.3.0&request=GetCapabilities`

## Frame index source

GetCapabilities `<Dimension name="time">` on the chosen layer (RX-Produkt for 5-min cadence). Rolling window varies; typically several hours.

All frames `past`; latest `current`. The WN-Produkt (composite with prediction) layer offers nowcast frames separately — out of scope this round; use plain RX for v0.1.

## Frame cadence

- RX-Produkt: 5 min (live reflectivity)
- RW-Produkt: 1 hour (accumulated precipitation)
- RY-Produkt: 5 min (quality-controlled reflectivity)

Default: RX (5-min) for the live radar tab.

## Geographic coverage

Germany. The DWD RADOLAN composite covers German territory only — operator must be in DE for meaningful results.

## License / attribution

DWD Open Data. Free with attribution. Required text: "Quelle: Deutscher Wetterdienst" / "Source: Deutscher Wetterdienst (DWD)".

## Source

- DWD GeoServer WMS: https://maps.dwd.de/geoserver/dwd/wms
- WN (prediction) metadata: https://gisc.dwd.de/wisportal/showMetadata.jsp?xml=de.dwd.routine.radar.composit.rw.1
- Spatineo listing: https://directory.spatineo.com/service/1117/
- Open data terms: https://www.dwd.de/EN/service/copyright/copyright_node.html
