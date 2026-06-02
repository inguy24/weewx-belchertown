# Typography tokens — LOCKED 2026-05-31

Typography sibling to ADR-048 (color tokens). Filed as a token spec (not an ADR) per the
design-record approach agreed this session.

**Status:** LOCKED — operator-approved 2026-05-31. Values are final. Do not change without
operator sign-off and a corresponding update to this file.

**Visual specimen:** [mockups/C2pre-type-system.html](mockups/C2pre-type-system.html)
(PNG: `C:\tmp\C2pre-type-system.png`) — this render is the operator-approved reference for
all typography decisions recorded here.

---

## Supersedes notice

These tokens supersede the Inter font and bold (700) card titles used in the earlier
`C1-now-hero-conditions.html` mockup. When C1 is coded, its title weight becomes 600 and
fonts follow these tokens. The C1 mockup file is not being retro-edited; **the tokens win on
conflict.**

---

## Self-hosting note

Three families are self-hosted via Fontsource woff2 files already present in
`docs/design/mockups/fonts/`. Weights 400 / 600 / 700 are available for each family.

The `@font-face` pattern used in the mockups (reproduced here so it can be copied verbatim
into the dashboard's CSS build):

```css
/* Manrope */
@font-face { font-family: 'Manrope'; font-weight: 400; font-style: normal;
  src: url('fonts/manrope-latin-400-normal.woff2') format('woff2'); }
@font-face { font-family: 'Manrope'; font-weight: 600; font-style: normal;
  src: url('fonts/manrope-latin-600-normal.woff2') format('woff2'); }
@font-face { font-family: 'Manrope'; font-weight: 700; font-style: normal;
  src: url('fonts/manrope-latin-700-normal.woff2') format('woff2'); }

/* Outfit */
@font-face { font-family: 'Outfit'; font-weight: 400; font-style: normal;
  src: url('fonts/outfit-latin-400-normal.woff2') format('woff2'); }
@font-face { font-family: 'Outfit'; font-weight: 600; font-style: normal;
  src: url('fonts/outfit-latin-600-normal.woff2') format('woff2'); }
@font-face { font-family: 'Outfit'; font-weight: 700; font-style: normal;
  src: url('fonts/outfit-latin-700-normal.woff2') format('woff2'); }

/* Lexend */
@font-face { font-family: 'Lexend'; font-weight: 400; font-style: normal;
  src: url('fonts/lexend-latin-400-normal.woff2') format('woff2'); }
@font-face { font-family: 'Lexend'; font-weight: 600; font-style: normal;
  src: url('fonts/lexend-latin-600-normal.woff2') format('woff2'); }
@font-face { font-family: 'Lexend'; font-weight: 700; font-style: normal;
  src: url('fonts/lexend-latin-700-normal.woff2') format('woff2'); }
```

In production, the `url()` paths will resolve relative to wherever `index.css` is built.
Adjust the path prefix to match the build output (e.g., `./fonts/` or `/assets/fonts/`).

---

## Paste-ready @theme block

Drop this block into the dashboard's `src/index.css` inside the `@theme` layer (alongside the
color tokens from ADR-048) when Track C coding begins.

```css
@theme {
  /* ── Font families ──────────────────────────────────────────────────────── */
  --font-sans:    'Manrope', system-ui, sans-serif;    /* body, labels, card titles, station name — DEFAULT */
  --font-display: 'Outfit',  system-ui, sans-serif;    /* ROLE: every card's large primary stat numeral (temp, wind speed, etc.) */
  --font-chart:   'Lexend',  system-ui, sans-serif;    /* chart text only: SVG axis / tick / data labels */

  /* ── Font weights ───────────────────────────────────────────────────────── */
  --font-normal:   400;
  --font-semibold: 600;
  --font-bold:     700;

  /* ── Type size scale (role-named, rem) ──────────────────────────────────── */
  --text-stat-hero:  4.75rem; /* C1 Current-Conditions temperature ONLY — uses --font-display, weight 700. Other cards use card-appropriate sizes (e.g. wind speed ≈ 3rem). Operator-authorized 2026-05-31. */
  --text-stat-unit:  1.9rem;  /* unit beside it (°F)              — --font-display */
  --text-hero-name:  1.35rem; /* station name                      — --font-sans, weight 700 */
  --text-section:    0.95rem; /* section heading                   — --font-sans */
  --text-body:       0.9rem;  /* sentences / body                  — --font-sans */
  --text-secondary:  0.85rem; /* feels-like, hi/lo                 — --font-sans (hi/lo weight 600) */
  --text-card-title: 0.82rem; /* card title                        — --font-sans, weight 600 (semibold, NOT bold) */
  --text-label:      0.75rem; /* small labels                      — --font-sans */
  --text-micro:      0.7rem;  /* uppercase micro-labels            — --font-sans */
  --text-chart-label: 0.875rem; /* chart axis / tick / data labels — --font-chart (Lexend), as approved (14px) */
}
```

---

## Role map

| UI element | Size token | Family token | Weight token | Notes |
|---|---|---|---|---|
| Large stat numeral ("72") | `--text-stat-hero` | `--font-display` (Outfit) | `--font-bold` (700) | **C1 Current-Conditions temperature only.** Other cards use card-appropriate sizes (e.g. wind speed ≈ 3rem Outfit 400). Operator-authorized 2026-05-31. |
| Stat unit ("°F") | `--text-stat-unit` | `--font-display` (Outfit) | `--font-normal` (400) | Sits beside the numeral, muted color |
| Station name | `--text-hero-name` | `--font-sans` (Manrope) | `--font-bold` (700) | Hero bar only |
| Section heading | `--text-section` | `--font-sans` (Manrope) | `--font-semibold` (600) | — |
| Body / sentences | `--text-body` | `--font-sans` (Manrope) | `--font-normal` (400) | General prose |
| Feels-like / secondary | `--text-secondary` | `--font-sans` (Manrope) | `--font-normal` (400) | Muted color |
| Hi / Lo values | `--text-secondary` | `--font-sans` (Manrope) | `--font-semibold` (600) | Same size as secondary, heavier weight |
| Card title | `--text-card-title` | `--font-sans` (Manrope) | `--font-semibold` (600) | Semibold (600), NOT bold (700) |
| Small labels | `--text-label` | `--font-sans` (Manrope) | `--font-normal` (400) | — |
| Uppercase micro-labels | `--text-micro` | `--font-sans` (Manrope) | `--font-normal` (400) | Set in uppercase via `text-transform` |
| Chart SVG text (axis, tick, data labels) | `--text-chart-label` (0.875rem) | `--font-chart` (Lexend) | `--font-normal` (400) | Lexend used exclusively for SVG chart text; size = approved 14px |

---

## References

- Color sibling: [decisions/ADR-048-theme-color-tokens.md](../decisions/ADR-048-theme-color-tokens.md)
- Visual specimen (mockup HTML): [mockups/C2pre-type-system.html](mockups/C2pre-type-system.html)
- Visual specimen (PNG, operator-approved): `C:\tmp\C2pre-type-system.png`
- Font files: `docs/design/mockups/fonts/` — manrope, outfit, lexend; weights 400 / 600 / 700
- Superseded by: nothing (this is the current canonical spec)
- Supersedes: Inter font usage and bold (700) card titles in `mockups/C1-now-hero-conditions.html`
