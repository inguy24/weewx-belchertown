# Background system — implementation notes (companion to ADR-047)

**Status:** working recipe, validated in the browser prototype and accepted by the operator
(2026-05-30). The *decisions* live in [ADR-047](../decisions/ADR-047-background-system.md); this doc
preserves the **concrete working code and exact values** so the React implementation reuses them
rather than re-deriving. ADR wins on any conflict.

## Source artifacts (do not throw away)

- **Prototype (the reference implementation of the visual technique):**
  [mockups/background-prototype.html](mockups/background-prototype.html). Single file, no
  dependencies. Open in a browser; the control panel is exploration scaffolding, not part of the
  shipped UI.
- **Asset-prep scripts:** [scripts/asset-prep/](../../scripts/asset-prep/) — `flatten_glass.py`,
  `extract_frost_alpha.py` (Python + Pillow + numpy). See "Asset prep" below.

## The layering technique (validated values)

Three stacked, full-viewport layers behind the app content; **all static, no animation**:

1. **Scene photo (base).** `background-size: cover; background-position: center`. When a precipitation
   overlay is active, apply `filter: blur(3px)` (≈`brightness(0.93)` optional) — enough to read as
   "through glass" while the scene stays recognizable. No blur when there's no overlay.
2. **Precipitation overlay.** The real on-glass photo, `background-size: cover`, composited with
   **`mix-blend-mode: screen`**. Opacity is **time-of-day driven: 0.75 day / 0.25 night**. Empty
   (`opacity: 0` / not rendered) when `overlay === null`.
3. **Bottom scrim** (legibility): `linear-gradient(to bottom, transparent 60%, rgba(0,0,0,0.32))`.
   A darken-scrim like this is the AA-contrast mechanism over busy photos (ADR-026 / B3 gate).

Cards over the background use a translucent glass treatment (validated): roughly
`background: rgba(255,255,255,0.14); border: 1px solid rgba(255,255,255,0.28); backdrop-filter:
blur(14px) saturate(1.2)`. Card text color flips light/dark by scene (dark text on bright daytime
scenes, light text on night/storm) — final values come from the A1 token work.

> The CSS in `background-prototype.html` is the canonical expression of the above. Lift from there.

## Asset → slot map

Backgrounds live in `Graphics/Backgrounds/` (source) + the wizard's `static/sky.jpg`. Buckets and
day/night per ADR-047 §Decision.

| Scene tag (`sky` × `daytime`) | File | Attribution |
|---|---|---|
| clear / day | `sky.jpg` | — (none) |
| clear / night | `clear_night_nathan_anderson.jpg` | Nathan Anderson |
| cloudy / day | `cloudy_day_Davies_Design_Studio.jpg` | Davies Design Studio |
| cloudy / night | `cloudy_night_ben-mathis-seibel.jpg` | Ben Mathis-Seibel |
| storm / day | `storm_day_Raychel_Sanner.jpg` | Raychel Sanner |
| storm / night | `storm_night_felix-mittermeier.jpg` | Felix Mittermeier |

| Overlay tag | File | Notes |
|---|---|---|
| rain | `rain_on_glass.jpg` | flat-ish field; `screen` blend drops the dark field, keeps drops |
| snow | `snow_on_glass_transparent.png` | operator's hand-made transparent frost cutout (preferred) |

The two on-glass overlays carry **no attribution** (confirmed 2026-05-30). The renderer shows a credit
only for assets that have one — i.e. the 5 scene photos credit their photographers; the blue-sky
default and both glass overlays show nothing.

## Asset prep

PWS note: run scripts from a directory **without** a stray `inspect.py` on the path (a `c:\tmp\inspect.py`
shadowed stdlib during dev — run from `scripts/asset-prep/` or the repo root).

- **`extract_frost_alpha.py <src> <dst.png> [gain=3.0]`** — automated fallback for turning an
  on-glass photo into a transparent cutout: keys alpha off *local* contrast (frost = high local
  contrast; smooth dark center + blown corners = low) so only the crystals stay opaque. Downscales to
  ≤2400px. Used to produce `snow_on_glass_cutout.png`. **The shipped snow overlay is the operator's
  own hand-made cutout (`snow_on_glass_transparent.png`), which beat the automated one** — keep the
  script as the documented fallback / for future assets.
- **`flatten_glass.py <src> <dst> [gain=1.3]`** — high-pass flatten that removes a photo's lighting
  gradient (re-centers the field on mid-gray) for `overlay`/`soft-light` blending. Produced
  `snow_on_glass_flat.jpg`. Superseded by the transparent-cutout approach for snow, but the technique
  is the right tool if a future overlay has a strong lighting gradient and a true cutout isn't
  available.

### Production step still owed
Downscale + compress every shipped background and overlay to **≤ 300 KB each, ~2560px longest edge,
WebP** (WebP keeps alpha, so the frost overlay needs no separate PNG). The operator's transparent PNG
is 16 MB at 4032×3024 — this is the single biggest perf risk (the background is typically the
largest-contentful-paint element). Worst case per view ≈ 600 KB (one background + one overlay). Build
task in the execution plan ([D3](../planning/briefs/A2-background-system.md)), not done yet.
