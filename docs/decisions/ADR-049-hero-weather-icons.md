---
status: Accepted
date: 2026-05-30
deciders: shane
supersedes:
superseded-by:
---

# ADR-049: Hero weather icons — Material Symbols, Meteocons-style gradients

## Context

Track A3 needs two icon families: **hero weather glyphs** (current-conditions + forecast condition
icons) and **utility/stat icons**. This ADR decides the **hero family only**; the utility/stat/nav
family is **deferred to a follow-up ADR** (see Out of scope).

Session feedback (NOTES.md synthesis): hero glyphs must be **bold / filled / illustrative with shading
and volume**, not thin line-art. The operator reviewed candidate sets in
[mockups/A3-icon-options.html](../design/mockups/A3-icon-options.html) and converged on a specific look:
**Meteocons-quality gradient-shaded clouds (gold sun, light-grey volumetric clouds) but with stronger
precipitation than Meteocons ships.** Meteocons itself was rejected as the shipped set for two reasons
discovered during review: (1) its rain/snow glyphs are weak ("lame"); (2) the Iconify port is the
*animated* set whose precipitation starts at `opacity:0` and never renders statically (broken).

## Options considered

| Option | Verdict |
|---|---|
| Weather Icons (Erik Flowers) — current stack default | **Reject** — thin line font, fails the bold/illustrative preference. |
| Meteocons direct (animated, via Iconify) | **Reject as shipped set** — precip animation broken in Iconify; weak rain/snow. Kept as the **color/style reference** (clouds + moon palette). |
| Emoji sets (Noto / Fluent / OpenMoji) | **Reject** — colorful but cartoony; coarse weather vocabulary. |
| Solar Bold / Phosphor, condition-tinted | **Reject** — viable but heavier/less refined than the chosen look. |
| **Material Symbols (filled), recolored Meteocons-style** | **Chosen** — complete static weather vocabulary, single clean shapes we recolor with gradients to get the Meteocons look without its precip/animation problems. |

## Decision

Hero weather icons = **Google Material Symbols (filled)**, rendered as **inline SVG** and recolored with
`<linearGradient>` fills in a Meteocons-inspired palette:

- **Sun** → gold gradient `#FFD24D` (top) → `#F5A623` (bottom).
- **Clouds** → light-grey volumetric gradient `#F3F5F8` (top) → `#C7CDD6` (bottom) — lighter at top for depth.
- **Lightning bolt** → gold (same as sun).
- **Moon** → Meteocons periwinkle gradient `#86C3DB` → `#72B9D5`.
- **Rain drops** → soft blue; **snow** → pale icy white (judgment-call accents; tunable).
- **Combined glyphs** (e.g. partly-cloudy-day): split sub-shapes so the **sun is gold** and the **cloud is grey**.

Locked visual reference (faithful render): [mockups/A3-material-gradient.html](../design/mockups/A3-material-gradient.html).

## Consequences

- The dashboard's `weather-icon.tsx` (currently maps WMO codes → Weather Icons CSS classes) is **rewritten**
  to emit inline Material Symbols SVG with the gradient treatment. This is **build work in the Track A code
  batch — not done by this ADR.**
- Gradients live in the SVG `<defs>`; icons are static (no animation) → reduced-motion safe by construction.
- Licensing: Material Symbols = **Apache-2.0** (modification/recolor explicitly allowed); Meteocons = MIT
  (used only as palette reference). Both GPL-v3 compatible.
- Trade-off accepted: Material Symbols are single-layer, so multi-tone within one glyph requires splitting
  sub-paths (the partly-cloudy approach). Documented so the implementer doesn't re-derive it.
- Per-condition accent colors (rain blue, snow pale) are judgment calls, easy to tune later.

## Acceptance criteria

- [ ] Every WMO condition the app maps (see `weather-icon.tsx` `WMO_MAP`, ~20 entries) has a hero glyph
      rendered as inline Material Symbols with the locked gradient treatment.
- [ ] `partly-cloudy-day` renders **gold sun + grey cloud** with no off-canvas/"exploded" geometry.
- [ ] Icons are **static** (no SMIL/animation); render fully without motion.
- [ ] Gold/grey/moon gradient stops match the locked values above.
- [ ] WCAG-legible over photo backgrounds, both themes (shared with the **B3 contrast/perf gate**).

## Implementation guidance

- Source glyphs (Material Symbols, Iconify names): `sunny`, `partly-cloudy-day`, `cloud`, `foggy`, `rainy`,
  `weather-snowy`, `thunderstorm`, `bedtime` (moon) — map each WMO code to the nearest.
- **partly-cloudy fix (known gotcha):** the sun body subpath uses a *relative* move (`m8.975-2.8`) that
  re-anchors to (0,0) if naively split — anchor it to absolute `M14.975 17.2`; set `fill-rule="nonzero"`
  explicitly on both split paths. (Captured from the mockup build.)
- Reuse the exact gradient defs + per-condition assignment from `A3-material-gradient.html`.
- **Out of scope (deferred to a follow-up ADR — next session):** the **utility / stat / nav icon family**
  (wind, humidity, pressure, menu, settings, etc.). Candidate packs + a full site-wide inventory are being
  assembled in `A3-icon-options.html`; the operator may **mix packs**. No utility-family decision is made here.

## References

- Related ADRs: ADR-009 (design direction), ADR-002 (WMO→icon mapping origin), ADR-026 (a11y/contrast),
  ADR-047 (backgrounds — icons sit over photos), ADR-048 (color tokens)
- Mockups: `docs/design/mockups/A3-material-gradient.html` (locked hero recipe),
  `docs/design/mockups/A3-icon-options.html` (candidate survey + pending utility inventory)
- Code (to be rewritten in build phase): dashboard `src/components/weather-icon.tsx`
- External: Material Symbols https://fonts.google.com/icons (Apache-2.0); Meteocons https://meteocons.com/ (MIT)
- Plan: `docs/planning/UI-REDESIGN-PLAN.md` Track A3
