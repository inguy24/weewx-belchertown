---
status: Proposed
date: 2026-05-30
deciders: shane
supersedes:
superseded-by:
---

# ADR-050: Utility / stat / nav / alert icons — Phosphor base, curated mix

## Context

Track A3 needs two icon families. [ADR-049](ADR-049-hero-weather-icons.md) decided the **hero weather
glyphs** (bold, filled, gradient — current-conditions + forecast condition icons). This ADR decides the
**second family**: the demure, thin **line** icons for stats, navigation, page chrome, and per-type
**weather-alert** glyphs. (Hero family is not restated here — see ADR-049.)

The operator walked the full site-wide candidate inventory in
[mockups/A3-icon-options.html](../design/mockups/A3-icon-options.html) — ~70 icons rendered across four
line packs (Lucide / Phosphor / Tabler / Solar) — and curated it pick-by-pick, with mixing allowed.

Two reframings surfaced during the walk and shape the scope:

1. **Several inventory rows are not utility icons at all.** Wind speed / direction / gust belong to the
   **C2 Wind Compass** signature component (current = compass dial with speed+gust *inside*; forecast =
   wind-circle-with-arrow+speed — both already locked in NOTES.md), not to a label-icon family.
2. **Not every stat gets an icon.** A generic glyph in front of every number "looks generic and stupid"
   (operator). Feels-like, dew-point, and similar render as **text only**.

## Options considered

| Option | Verdict |
|---|---|
| **Lucide** (current stack default) | **Reject as base** — neutral and covers all icons, but operator preferred Phosphor's character. Retained nowhere. |
| **Phosphor (regular weight)** | **Chosen base** — consistent line weight, covers nearly the whole set, friendlier curve the operator liked. |
| Tabler | **Reject as base** — kept for exactly one glyph (`uv-index`) where Phosphor has no clean match. |
| Solar (linear) | **Reject** — decorative; coverage gaps (no dew-point, no UV). |
| "An icon on every stat" | **Reject** — operator: a generic glyph per number adds noise; some metrics are text-only. |

## Decision

**Base pack = Phosphor (regular).** Curated set below, with deliberate cross-pack exceptions only where
Phosphor lacks a good match. Iconify names (`prefix:name`):

**Stats** (Phosphor, except UV): temperature `ph:thermometer` · humidity `ph:drop-simple` ·
precip chance `ph:umbrella` · visibility `ph:eye` · solar radiation `ph:sun` · rainfall `ph:cloud-rain` ·
snowfall `ph:snowflake` · barometric pressure `ph:gauge` · **UV index `tabler:uv-index`** (cross-pack).

**Trend** (one reusable set for *any* metric, not pressure-specific): rising `ph:arrow-up` ·
falling `ph:arrow-down` · steady `ph:arrow-right`.

**Text-only — no icon:** feels-like, dew-point. (Wind speed/direction/gust are excluded entirely —
owned by C2.)

**Weather alerts** (13 types; Phosphor + 2 cross-pack): fire `ph:fire` · tropical/hurricane `ph:hurricane`
(covers all tropical) · thunderstorm `ph:lightning` · tornado `ph:tornado` · generic warning `ph:warning` ·
generic watch `ph:warning-circle` · wind `ph:wind` · marine `ph:sailboat` · snow/winter `ph:snowflake` ·
heat & cold `ph:thermometer` · fog `ph:cloud-fog` · **flood `material-symbols:flood-outline-rounded`**
(cross-pack) · **tsunami `carbon:tsunami`** (cross-pack; `mdi:tsunami` is the noted fallback).

**Nav / chrome / misc** (Phosphor): menu `ph:list` · home `ph:house` · settings `ph:gear` ·
search `ph:magnifying-glass` · close `ph:x` · chevrons `ph:caret-{up,down,left,right}` ·
refresh `ph:arrows-clockwise` · external `ph:arrow-square-out` · theme-light `ph:sun` · theme-dark `ph:moon` ·
records `ph:trophy` · webcam `ph:camera`.

Locked render (faithful worksheet): [mockups/A3-final-icons.html](../design/mockups/A3-final-icons.html).

## Consequences

- The dashboard gains a **predominantly single-pack** icon set (Phosphor), keeping the line family cohesive.
  Two alert glyphs (Material flood, Carbon tsunami) and one stat (Tabler UV) are the only cross-pack glyphs;
  all are rarely-rendered, so the consistency cost is bounded.
- **Rendering mechanism is a build-phase choice** (e.g. `@phosphor-icons/react` for the base + inline SVG
  for the 3 cross-pack glyphs, OR Iconify at runtime). Not decided here. The mockups use Iconify only as a
  preview tool.
- Wind speed/direction/gust stats remain **text-only** (no utility icon on individual stat readouts).
  **Exception:** `ph:wind` is used on the **C2 Wind Compass card title** and as a readout-block icon inside the
  dial — operator-authorized 2026-05-31.
- **Three sub-families — RESOLVED by C4 (2026-06-01).** All three deferred sub-families were resolved during
  the C4 stat-tile mockup, operator-approved 2026-06-01:
  - **AQI:** `ph:leaf` (Phosphor leaf, regular weight) as the content-area icon next to the AQI value. Not
    deferred to C6 — resolved here.
  - **Astro/almanac:** SVG arc position markers (sun glyph on gold arc, moon crescent on silver arc). These are
    graphical elements on the arc visualization, not icon-family glyphs. No Phosphor astro icon needed.
  - **Earthquake/seismic:** magnitude color badge (48×48 square, "M" + value, background color by magnitude
    class). Not an icon-family glyph — the badge IS the visual identity.
  - **UV Index (content-area):** custom inline SVG (Phosphor sun shape with "UV" text knocked out of the center
    circle). Replaces `tabler:uv-index` for the C4 tile content area; `tabler:uv-index` remains available for
    other stat-label contexts.
  - **C4 stat tiles use NO title icons** (P9 pattern). Card titles are text-only (Manrope 600). Visual identity
    comes from content-area elements: icons next to values, gauges, charts, badges, or arc markers.
- Licensing: Phosphor **MIT**, Tabler **MIT**, Material Symbols **Apache-2.0**, Carbon **Apache-2.0** — all
  GPL-v3 compatible.

## Acceptance criteria

- [ ] Every stat in the Decision renders its named glyph at the demure line weight; UV uses `tabler:uv-index`,
      all others `ph:*`. Worksheet [A3-final-icons.html](../design/mockups/A3-final-icons.html) matches.
- [ ] Trend indicators everywhere use the single reusable set (`ph:arrow-up`/`arrow-down`/`arrow-right`).
- [ ] All 13 alert types map to their named glyph; flood (`material-symbols:flood-outline-rounded`) and
      tsunami (`carbon:tsunami`) render correctly as cross-pack glyphs.
- [ ] Feels-like and dew-point render with **no icon** (text only).
- [ ] No utility wind icon on individual stat readouts (speed/direction/gust are text-only), **except** `ph:wind` on the C2 Wind Compass card title and readout block (operator-authorized 2026-05-31).
- [ ] C4 content-area icons render per the resolution table: `ph:leaf` (AQI), `ph:drop` (Precip), `ph:sun`
      (Solar Rad), custom sun+UV (UV Index), `ph:lightning` (Lightning), SVG arc markers (Sun & Moon),
      magnitude badge (Earthquake). No title icons on any C4 tile (P9).
- [ ] Icons legible in both themes and over photo backgrounds (shared with the **B3 contrast/perf gate**).

## Implementation guidance

- `ph:snowflake` serves **double duty** — snowfall stat *and* snow/winter alert. `ph:thermometer` likewise
  serves the temperature stat *and* the heat/cold alert. Don't introduce duplicates.
- Humidity (`ph:drop-simple`, single drop) and precip-chance (`ph:umbrella`) are deliberately distinct so a
  drop never means two things.
- `ph:hurricane` is the single glyph for *all* tropical watches/warnings.
- If `carbon:tsunami` looks off against the Phosphor weight in context, swap to `mdi:tsunami` (pre-vetted).
- Candidate provenance / gap pickers: [A3-icon-options.html](../design/mockups/A3-icon-options.html) (survey),
  [A3-alert-gaps.html](../design/mockups/A3-alert-gaps.html) (flood/tsunami), and
  [A3-pressure-options.html](../design/mockups/A3-pressure-options.html) (pressure).

## References

- Related ADRs: ADR-049 (hero family — sibling, not restated), ADR-048 (color tokens), ADR-047 (backgrounds —
  icons sit over photos), ADR-026 (a11y/contrast). **C2 (wind compass), C5 (sun/moon), C6 (AQI), seismic** —
  pending ADRs that own the deferred glyphs.
- Mockups: `docs/design/mockups/A3-final-icons.html` (locked set), `A3-icon-options.html` (survey),
  `A3-alert-gaps.html`, `A3-pressure-options.html`
- External: Phosphor https://phosphoricons.com/ (MIT), Tabler https://tabler.io/icons (MIT),
  Material Symbols https://fonts.google.com/icons (Apache-2.0), Carbon https://carbondesignsystem.com/ (Apache-2.0)
- Plan: `docs/planning/UI-REDESIGN-PLAN.md` Track A3
