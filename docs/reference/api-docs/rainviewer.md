# RainViewer — radar provider notes

Source for Clear Skies `providers/radar/rainviewer.py`. Captured 2026-05-11 (live verification against `https://api.rainviewer.com/public/weather-maps.json`).

## Endpoint shape

- **Frame index (JSON):** `https://api.rainviewer.com/public/weather-maps.json`
- **Tile URL template:** `{host}{path}/{size}/{z}/{x}/{y}/{color}/{options}.png`
  - `{host}` from JSON `host` field (currently `https://tilecache.rainviewer.com`).
  - `{path}` from JSON `radar.past[i].path` (e.g. `/v2/radar/1778547631`).
  - `{size}`: `256` or `512`.
  - `{z}/{x}/{y}`: slippy-map XYZ.
  - `{color}`: integer color-scheme id (0-8 documented; 2 = "Universal Blue" is rainviewer-standard).
  - `{options}`: `{smooth}_{snow}` — both 0/1. Operator-facing default: `1_1` (smooth + snow).
  - Extension: `.png`. (No WebP variant documented for `weather-maps.json` flow.)

## JSON shape (verified live capture 2026-05-11 — `weather-maps.json`)

```json
{
  "version": "2.0",
  "generated": 1778547631,
  "host": "https://tilecache.rainviewer.com",
  "radar": {
    "past": [
      {"time": 1778540400, "path": "/v2/radar/1778540400"},
      … 12 more …
    ],
    "nowcast": []
  },
  "satellite": {
    "infrared": []
  }
}
```

- `radar.past`: 13 frames, ~10-min interval, ~2-hour total coverage.
- `radar.nowcast`: documented to carry forecast frames (typically 3 × 10-min ahead) but **was empty in 2026-05-11 capture** — provider may have temporarily disabled. Module should tolerate empty array.
- `satellite.infrared`: out of scope for radar provider; ignore.

## Frame-kind mapping → canonical `RadarFrame.kind`

- The single `radar.past[i]` with `max(time)` → `current` (always exactly one in a non-empty past list)
- All other `radar.past[i]` → `past`
- `radar.nowcast[i]` → `nowcast`

`time` is Unix epoch seconds; `RadarFrame.time` is UTC ISO-8601 — convert via `epoch_to_utc_iso8601()` (existing helper at `providers/_common/datetime_utils.py:70`).

> **Correction 2026-05-11:** original capture of this file said "`time >= generated` → current, else past" with "(the latest past frame is current)" as a parenthetical. The parenthetical is the correct semantic; the literal rule was wrong because RainViewer responses have all `past[].time` strictly BEFORE `generated` (~5 min). Live capture shown above: `generated=1778548535`, `max(past[].time)=1778548200` — 335s before generated. The literal rule produced zero current frames. Corrected in 3b-14 lead-direct `f2362ee`.

## Geographic coverage

Global mosaic (composited from many national sources). Default fallback for regions without a native provider per ADR-015.

## License / attribution

> "The API is free for personal or educational use."
> Attribution required: link to https://www.rainviewer.com/ on the consuming site.

Operator note: free for non-commercial. Commercial use needs paid plan (out of scope for clearskies).

## Rate limits / auth

No auth, no documented rate limit. RainViewer's docs phrase is "be reasonable." Treat as no-auth-no-limit at our cache cadence (1 frame-index fetch per ~10 min).

## Source

- API docs: https://www.rainviewer.com/api/weather-maps-api.html
- Public JSON: https://api.rainviewer.com/public/weather-maps.json
