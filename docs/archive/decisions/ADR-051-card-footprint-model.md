---
status: Archived — consolidated into DESIGN-MANUAL.md
date: 2026-05-30
deciders: shane
supersedes:
superseded-by:
---

# ADR-051: Card footprint model & grid-compatible sizing

## Context

Track A4 is the final Track A foundation: decide how cards are **sized** so that fixed layouts built now
drop into a **future customizable grid** without redesign. The grid **engine** (operator move/resize, layout
persistence, drag) is explicitly a **separate future plan** — not built or designed here. This ADR decides
the **footprint vocabulary, sizing tokens, row model, page anatomy, and responsive collapse** only.

**Why this model exists (the *why*, not just the *what*).** The end goal is an **operator-customizable
dashboard** — the **operator** (not the visiting public) uses a drag-and-drop layout tool (Now page first)
to add, remove, and rearrange cards, building the page their visitors then see. Every decision here is the
**contract that future engine consumes**: footprints tell it how much space a card claims; minimum
footprints let it reject a drop that would clip a card; the half-row track + zero-waste packing let cards
retile cleanly on add/remove/move; the universal card discipline means there is nothing but cards to move.
Locking this now means **no card needs redesigning when the operator drag-and-drop grid is built.**

Locked directional input (NOTES.md, plan §"Out of scope"): the future home page is a **4-column grid**;
cards span **1/2/3/4 columns** and may be multiple rows tall; tiles are **uniform translucent glass**
(bento style), not organic blobs; card header = title + thin underline rule.

As-built starting point ([ADR-048](ADR-048-theme-color-tokens.md), dashboard `index.css`): radius tokens
exist (`--radius` 0.625rem + derived scale; cards use `rounded-xl` = 0.875rem); card surface is `bg-card`
with a subtle ring; shadcn Card is fluid-width and container-query aware. **Missing, and defined here:**
spacing/gutter tokens, column-width math, row-height convention, the 4→2→1 breakpoint strategy, container
max-width, and the translucent-glass surface treatment.

Operator-reviewed render: [mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) (footprints at
desktop/tablet/phone, glass over a stand-in background).

## Options considered

| Option | Verdict |
|---|---|
| Fixed-pixel cards, no grid awareness | **Reject** — forces a full redesign when the grid lands; defeats the compatibility constraint. |
| Build the customizable grid engine now | **Reject** — out of scope (separate future plan); premature before components exist. |
| Fixed row height, cards snap to row units now | **Reject for now** — would clip rich cards (the "too much info" density tension). |
| **Footprints now (col-span enforced, row-span declared), content-driven height** | **Chosen** — grid-forward without the engine; nothing clips today, every card already knows its footprint for later. |
| Column count 3 / 6 | **Reject** — 4 is the locked direction; 4→2→1 collapses cleanly without orphan rows. |
| Container 72rem (as-built) | **Reject** — bumped to 80rem so 4 columns have room. |
| Full-row track only (strips pinned to a fixed height) | **Reject** — a lone half-height strip orphans an empty half-row beneath it. |
| **Half-row base track; cards span in half-row multiples** | **Chosen** — strips (header/controls/alert) pack with zero waste; data cards span 2 tracks, tall cards 4. |
| Page chrome (title/controls) as free page elements | **Reject** — reintroduces free-floating content; everything is a card (page-header card + controls strip). |

## Decision

**Footprint vocabulary** (col-span × row-span):

- `tile` = 1 col · `wide` = 2 col · `panel` = 3 col · `full` = 4 col
- Tall cards add **row-span** (e.g. the Wind Compass = `wide` + 2 rows = **2×2**).

**Minimum footprint per card.** A card may declare a *minimum* span below which its content clips. Surfaced
by the webcam (a 2×1 timelapse clips → **minimum 2×2**). Locked minimums for the signature/large cards:
Current Conditions, Wind Compass, Radar, Webcam = **2×2**; Active Alert and Today's Highlights = **full
(4×1)**; stat tiles = **1×1**.

**Column rule now vs. later.** Column-span is **enforced today** (cards lay out in a CSS grid). Row-span is
**declared/documented** per card for the future grid, but card **height stays content-driven** until the
grid engine exists — so nothing is clipped by a forced row height.

**Responsive collapse:** 4 columns (desktop ≥1024px) → 2 columns (tablet ≥768px) → 1 column (phone
<768px). `full`/`panel` cards become full-width of the current column count; `2×2` cards stay 2-wide and
tall at tablet; everything stacks in reading order on phone.

**Row model — half-row track, zero-waste packing.** The grid's base **row track is the half-row** (`--card-
half-row`, 5.5rem). Cards span row tracks in half-row multiples: a **strip** (page-header, controls, alert
banner) = **1 track**; a **standard data card** = **2 tracks** (= `--card-row` 11rem); a **2×2 / tall card**
= **4 tracks** (22rem). This guarantees half-height cards **pack with no orphaned half-row**: two stacked
strips (e.g. page-header + controls) occupy two consecutive half-tracks = exactly one data-row of height,
no gap. Footprint **badges/vocabulary stay in full-row terms** (1×1, 2×2, 4×½) — only the underlying CSS
track is the half-row, for packing. (Operator-reviewed render:
[mockups/A4-page-anatomy.html](../design/mockups/A4-page-anatomy.html).)

**Sizing tokens** (new, to live in dashboard `index.css` `@theme`):

| Token | Value | Meaning |
|---|---|---|
| `--gap-grid` | `1rem` | gutter between cards (both axes) |
| `--container-max` | `80rem` | dashboard content cap (was 72rem) |
| `--card-half-row` | `5.5rem` | **base grid row track**; strips span 1, data cards 2, tall cards 4 |
| `--card-row` | `11rem` | a standard data row = 2 half-row tracks (conceptual full-row pitch) |
| radius | reuse `rounded-xl` (0.875rem) | from ADR-048 |

**Card surface = translucent glass.** Cards are semi-opaque over the A2 photo background with a subtle
`backdrop-filter` blur (uniform tiles, not blobs). The **exact opacity/contrast value is set at the B3
contrast/perf gate**, not fixed here.

**Universal card discipline (ALL pages).** The card model is the *only* layout primitive — there is no
free-floating page-level content anywhere on the site.

- **One container, one width.** Every page renders inside the same `--container-max`, whether it's a
  multi-card grid (Now) or a single-purpose page (Records, Reports, About, Legal). A "simple" page is not
  free-form — it is **one or more `full`-width cards** (content-height, not row-constrained). This keeps
  page widths uniform across the whole site; no page varies its own width.
- **Page-header card (a card, not free text).** Every page opens with a `full`-width **half-row** page-header
  card holding the page title + short info. **On the Now page this card *is* the hero** — it carries the
  station logo + station name (its full content/design is a Track C **C1** job; A4 only establishes it is a
  card). On other pages it is a title + one-line-info card replacing today's free-floating page text.
- **Controls belong to a card.** Tabs, period selectors, sort controls, and buttons (e.g. Records period
  selector, Forecast time-range tabs, Reports download/toggle) live **inside a card** — never floating on the
  page background. Two patterns by volume: **few controls → inline** in the page-header card (right-aligned);
  **many controls → a dedicated `full`-width half-row controls strip** directly below the header.
- **No generic explanatory prose on data pages.** Educational/explainer text (e.g. the Reports page's
  generic intro) does not belong on the page; it belongs in the **user manual/help**. Pages show data +
  controls only. **Distinction:** *data-contextual microcopy* — units, empty/"no data" states, legends, a
  one-line card subtitle — is legitimate and stays **inside its card**; only *generic educational prose*
  relocates to the manual.

## Consequences

- Dashboard `index.css` gains the spacing/container tokens; a **footprint convention** (col-span/row-span
  utility classes, or a Card `footprint` prop mapping to them) is introduced. This is **build work in a
  Track A/C code batch — not done by this ADR.**
- Every Track C component declares a **footprint + minimum footprint** as part of its card spec.
- The translucent surface couples to **ADR-047 (A2 background)** and the **B3 contrast gate** — cards must
  stay WCAG-legible over photos in both themes.
- The Almanac page currently renders as a vertical stack (departs from footprints) — reconciled to the
  footprint model during its Track C pass, not here.
- **Restore the Now-page hero (tracked, Track C / C1).** The page-header card on Now = the hero showing
  **station logo + station name**; it was dropped and never redesigned. A4 establishes it is a card; its
  content/design is a **C1** deliverable (ties to ADR-022 branding / ADR-049 logo alt).
- **Uniform page width site-wide** — no page renders wider/narrower than `--container-max`.
- **Existing pages must be reconciled to the universal card discipline** in their Track C passes:
  Records' free-floating buttons → moved into a card; Reports' generic explainer → relocated to the manual;
  any other page-level chrome → wrapped in a card. These are per-page reconciliation items, not done here.
- **Operator manual is a confirmed future deliverable.** The operator-customizable dashboard will need an
  **operator manual** so operators know how to set up and use the layout tool (and the system generally).
  This is its own build, tracked outside A4 — flagged here because the customizable-grid feature depends on
  it. Generic explainer prose pulled off data pages (e.g. the Reports intro) that is *operator-facing* lands
  here. (Any *visitor-facing* help destination — About page / a Help route — remains a smaller open item.)
- No grid engine, drag-resize, or layout persistence ships — any such work is the separate future grid plan.

## Acceptance criteria

- [ ] Footprint vocabulary (`tile`/`wide`/`panel`/`full` + row-span) is defined and every Track C card
      declares both a footprint and a minimum footprint.
- [ ] Tokens `--gap-grid` (1rem), `--container-max` (80rem), and the conceptual `--card-row` (11rem) exist
      in the dashboard theme; container cap is 80rem.
- [ ] Cards reflow **4→2→1** at ≥1024 / ≥768 / <768px; no card renders narrower than one column.
- [ ] Cards with a minimum row-span (Webcam, Current Conditions, Wind Compass, Radar = 2×2) never render at
      a clipping height.
- [ ] Card surface is translucent glass over the A2 background; final opacity meets the **B3 contrast floor**
      in both themes.
- [ ] No grid engine / drag-resize / persistence is shipped (out of scope — future grid plan).
- [ ] Every page renders within `--container-max`; no page varies the shared site width.
- [ ] No control (tab / button / selector) renders outside a card; all live in a card header or controls card.
- [ ] No generic explainer prose renders on a data page; only data-contextual microcopy remains, in-card.
- [ ] Grid base track = `--card-half-row` (5.5rem); strips span 1, data cards 2, tall cards 4 — two stacked
      half-row strips equal one data-row with **no orphaned half-row** anywhere.
- [ ] Every page opens with a page-header card (the hero on Now); controls render inline in it when few, or
      in a dedicated half-row controls strip when many.

## Implementation guidance

- Represent footprints with Tailwind v4 `col-span-{1..4}` + `row-span-{1..3}` (or a Card `footprint` prop
  that maps to those classes). The shadcn Card is already container-query aware — good for laying out a
  card's *internals* responsively within its footprint.
- Reuse the ADR-048 radius scale; do not introduce a new radius token.
- Keep the grid definition in one place so the future grid engine can replace the static `grid-template`
  without touching individual cards.
- Locked visual reference: [mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) (representative
  Now-page footprints; the exact Now layout is finalized per-component in Track C, not by this ADR).

## References

- Related ADRs: ADR-048 (radius/card-surface tokens — built on here), ADR-047 (A2 background — cards sit over
  it), ADR-026 (a11y/contrast) + the **B3 contrast/perf gate** (sets final card opacity), ADR-049 / ADR-050
  (A3 icons — sibling foundations).
- Inventory: `docs/design/C0-PAGE-INVENTORY.md` (per-page card list the footprints apply to).
- Mockups: `docs/design/mockups/A4-card-grid.html` (footprints + responsive collapse),
  `docs/design/mockups/A4-page-anatomy.html` (page-header/hero card, controls strip, half-row zero-waste packing)
- Out of scope: the **customizable card grid** (engine, move/resize, persistence) — separate future plan per
  `docs/planning/UI-REDESIGN-PLAN.md` §"Out of scope here".
- Plan: `docs/planning/UI-REDESIGN-PLAN.md` Track A4

---

## Amendment — 2026-06-13: Quarter-row track, mobile tokens, row-gap elimination

**Status:** Accepted

**Context:** The original ADR defines the half-row (5.5rem) as the base grid track. Implementation
revealed three issues: (1) control strips (buttons, dropdowns) are functionally thinner than 5.5rem —
they were hacked with `py-2` padding overrides to appear compact inside half-row cards; (2) the rigid
grid track system is only appropriate for the Now page (operator-customizable grid with known card
footprints) — all other pages need content-adaptive card heights (`auto-rows-[auto]`) because their
cards contain variable-length content (forecast tables, charts, record lists, legal text); (3) mobile
responsive token values were added (card-row 13rem mobile / 11rem desktop) but never documented in
the ADR. This amendment introduces a quarter-row base track, eliminates row-gap in favor of card
margins, documents mobile token values, adds the `--card-content-max` token, and clarifies that rigid
grid tracks apply only to the Now page.

### Changes to the Decision

**1. Grid base track becomes the quarter-row.**

The grid's base row track changes from `--card-half-row` to `--card-quarter-row`. Row-span multiples
adjust accordingly: strips span 1 track (quarter-row), headers span 2 tracks (half-row), data cards
span 4 tracks (full row), tall cards span 8 tracks (double row).

**2. Row-gap eliminated; vertical spacing via card margins.**

The grid uses `gap-x` only (column gap = `--gap-grid`). Row gap is 0. Vertical spacing between cards
comes from each card's `margin-bottom: var(--gap-grid)`. This eliminates gap-inflated row arithmetic
where grid row-gap doubled the effective height of multi-track spans.

**3. Quarter-row token added.**

| Token | Mobile (<768px) | Desktop (md ≥768px) | Meaning |
|---|---|---|---|
| `--card-quarter-row` | `3.25rem` | `2.75rem` | **base grid row track**; control strips span 1 |

**4. Mobile responsive token values documented.**

All sizing tokens are responsive. Mobile values are proportionally larger to accommodate touch targets.

| Token | Mobile (<768px) | Desktop (md ≥768px) |
|---|---|---|
| `--card-quarter-row` | `3.25rem` | `2.75rem` |
| `--card-half-row` | `6.5rem` | `5.5rem` |
| `--card-row` | `13rem` | `11rem` |
| `--card-content-max` | `9rem` | `7rem` |

Token arithmetic (desktop): `--card-quarter-row` × 2 = `--card-half-row` (2.75 × 2 = 5.5). `--card-quarter-row` × 4 = `--card-row` (2.75 × 4 = 11). `--card-quarter-row` × 8 = tall card (2.75 × 8 = 22).

Token arithmetic (mobile): 3.25 × 2 = 6.5 ✓. 3.25 × 4 = 13 ✓. 3.25 × 8 = 26 ✓.

**5. `--card-content-max` token added.**

`--card-content-max: calc(var(--card-row) - 4rem)` — the maximum height for graphic containers (gauges,
arcs, mini-charts) inside tile cards. Derives to 9rem mobile, 7rem desktop. Graphic containers
self-constrain via `maxHeight: var(--card-content-max)` so they never overflow their card.

**6. Updated row-span model.**

| Card role | rowSpan | Track count (md+) | Desktop height | Mobile min-h |
|---|---|---|---|---|
| Control strip | `"quarter"` | 1 | 2.75rem | 3.25rem |
| Page header | `"half"` | 2 | 5.5rem | 6.5rem |
| Data card (default) | `1` | 4 | 11rem | 13rem |
| Tall card | `2` | 8 | 22rem | 26rem |

**7. Rigid grid tracks apply to the Now page only; all other pages use content-adaptive heights.**

The quarter-row track system (`md:auto-rows-[var(--card-quarter-row)]`) enforces rigid card heights
that are correct for the Now page — the operator-customizable grid where cards have known footprints
and will eventually support drag-and-drop layout. On all other pages (Forecast, Charts, Almanac,
Seismic, Records, Reports, About, Legal), cards must be **content-adaptive**: they use `auto-rows-[auto]`
so cards grow to fit their content, with `min-h` from `rowSpan` tokens preventing collapse.

The original implementation had 7 of 9 pages setting `md:auto-rows-[auto]` — this was misidentified
as "bypassing the track system" and removed. In fact, those pages needed content-driven heights because
their cards contain variable-length content (forecast tables, charts, record lists, report data, legal
text) that cannot be predicted at grid-definition time.

**Implementation:** The `PageLayout` template (used by all non-Now pages) passes `auto-rows-[auto]`
as the grid's `md:auto-rows` value. The Now page's grid retains `md:auto-rows-[var(--card-quarter-row)]`.
Cards still declare `rowSpan` for `min-h` sizing, but the grid does not constrain their maximum height
on non-Now pages.

### Updated sizing tokens table (replaces original)

| Token | Mobile (<768px) | Desktop (md ≥768px) | Meaning |
|---|---|---|---|
| `--gap-grid` | `1rem` | `1rem` | gutter between cards (column axis only; row gap = 0) |
| `--container-max` | `80rem` | `80rem` | dashboard content cap |
| `--card-quarter-row` | `3.25rem` | `2.75rem` | **base grid row track**; strips span 1 |
| `--card-half-row` | `6.5rem` | `5.5rem` | page headers span 2 tracks |
| `--card-row` | `13rem` | `11rem` | standard data row = 4 tracks |
| `--card-content-max` | `9rem` | `7rem` | graphic container max-height = `calc(var(--card-row) - 4rem)` |
| radius | `rounded-xl` (0.875rem) | `rounded-xl` (0.875rem) | from ADR-048 |

### Updated acceptance criteria (additive)

- [ ] `--card-quarter-row` token exists: 3.25rem mobile, 2.75rem desktop.
- [ ] Grid base track is `--card-quarter-row` at md+; mobile stays `auto-rows-[auto]`.
- [ ] Grid has `gap-y-0`; vertical card spacing comes from card `margin-bottom: var(--gap-grid)`.
- [ ] Control strips render at quarter-row height via `rowSpan="quarter"` — no `py-2` padding hacks.
- [ ] Page headers render at half-row height via `rowSpan="half"`.
- [ ] `--card-content-max` token exists: `calc(var(--card-row) - 4rem)`.
- [ ] Graphic containers (gauges, arcs, tile-card charts) self-constrain via `maxHeight: var(--card-content-max)`.
- [ ] No ad-hoc Card className overrides for sizing (`py-2`, manual `min-h-[var(--card-half-row)]`) in route files.
- [ ] Token arithmetic holds: quarter × 2 = half, quarter × 4 = row, quarter × 8 = tall (both viewports).
- [ ] Now page grid uses `md:auto-rows-[var(--card-quarter-row)]` (rigid tracks for operator-customizable layout).
- [ ] All non-Now pages (via PageLayout) use `auto-rows-[auto]` — cards grow to fit content, with `min-h` from `rowSpan` preventing collapse.

**8. Typography tokens are mandatory — no hardcoded font sizes in card components.**

All `fontSize` values in card component inline styles MUST use `var(--text-*)` design tokens.
No hardcoded pixel, rem, or em font sizes. No exceptions. No per-card overrides.

The full typography token scale:

| Token | Value | Role | Font |
|---|---|---|---|
| `--text-stat-hero` | 4.25rem | CC card temperature numeral | Outfit 700 |
| `--text-stat-unit` | 1.9rem | unit beside hero stat / wind compass speed | Outfit |
| `--text-hero-name` | 1.35rem | station name | Manrope 700 |
| `--text-stat-tile` | 1.25rem | primary stat value on 1×1 tile cards | Outfit 600 |
| `--text-stat-label` | 1rem | secondary stat value / large label on tiles | Outfit/Manrope |
| `--text-section` | 0.95rem | section heading | Manrope |
| `--text-body` | 0.9rem | body sentences | Manrope |
| `--text-secondary` | 0.85rem | feels-like, hi/lo, supporting text | Manrope |
| `--text-card-title` | 0.82rem | card title (semibold, NOT bold) | Manrope 600 |
| `--text-chart-label` | 0.875rem | chart axis/tick/data labels | Lexend |
| `--text-label` | 0.75rem | small labels | Manrope |
| `--text-micro` | 0.7rem | uppercase micro-labels, minimum text size | Manrope |

**Exception:** SVG `<text>` elements inside a `viewBox` coordinate system (sun arc, compass
cardinal labels) use viewBox-unit font sizes, not CSS rem. These are a different coordinate
system and tokens do not apply. Recharts `tick={{ fontSize }}` props use pixel values mapped
to the `--text-chart-label` equivalent (14px ≈ 0.875rem).

### Updated acceptance criteria (additive — typography)

- [ ] Every `fontSize` in card component inline styles uses `var(--text-*)` — zero hardcoded values.
- [ ] `--text-stat-tile` (1.25rem) and `--text-stat-label` (1rem) tokens exist in `index.css`.
- [ ] No font size in any card component is smaller than `--text-micro` (0.7rem / ~11px).

---

## Amendment — 2026-06-16: Row height increase (Option B) and card content box contract

**Status:** Accepted

**Context:** Two problems surfaced during Legal page and Now page review:

1. **Row heights too tight.** The `--card-quarter-row` at 2.75rem desktop produced an 11rem data card row. To fit content, card titles were shrunk to 0.82rem — smaller than body text (0.9rem), destroying visual hierarchy. Option B (+0.5rem quarter) was selected to restore proportional title sizing.

2. **No defined content area.** Card content dimensions are implicit — "whatever's left after the title and padding." Every card component guesses at available space differently, producing ad-hoc sizing (hardcoded heights, `!important` padding overrides, `maxHeight` hacks). Future card designers have no contract to build against.

### Changes to the Decision

**9. Row height tokens increased (Option B).**

All row tokens increase by the same ratio. Token arithmetic is preserved (quarter × 2 = half, quarter × 4 = row, quarter × 8 = tall).

| Token | Previous desktop | **New desktop** | Previous mobile | **New mobile** |
|---|---|---|---|---|
| `--card-quarter-row` | 2.75rem | **3.25rem** | 3.25rem | **3.75rem** |
| `--card-half-row` | 5.5rem | **6.5rem** | 6.5rem | **7.5rem** |
| `--card-row` | 11rem | **13rem** | 13rem | **15rem** |
| `--card-content-max` | 7rem | **9rem** | 9rem | **11rem** |

Updated row-span model:

| Card role | rowSpan | Track count (md+) | Desktop height | Mobile min-h |
|---|---|---|---|---|
| Control strip | `"quarter"` | 1 | 3.25rem | 3.75rem |
| Page header | `"half"` | 2 | 6.5rem | 7.5rem |
| Data card (default) | `1` | 4 | 13rem | 15rem |
| Tall card | `2` | 8 | 26rem | 30rem |

Token arithmetic (desktop): 3.25 × 2 = 6.5 ✓. 3.25 × 4 = 13 ✓. 3.25 × 8 = 26 ✓.

Token arithmetic (mobile): 3.75 × 2 = 7.5 ✓. 3.75 × 4 = 15 ✓. 3.75 × 8 = 30 ✓.

**10. Card title token increased.**

| Token | Previous | **New** |
|---|---|---|
| `--text-card-title` | 0.82rem | **1.1rem** |

Title (1.1rem) is now clearly larger than body text (0.9rem), restoring visual hierarchy.

**11. Card content box contract.**

Every card has two defined slots with token-backed dimensions. The Card component owns all chrome (padding, title area, gap, radius). Card designers build against the content box — not raw card dimensions.

**Header slot:**
- Fixed height: `--card-header-h` (new token).
- Contains: card title (at `--text-card-title`), underline rule, and padding.
- The card component renders this. The designer passes a title string.

**Content slot:**
- A defined rectangular area below the header with known dimensions.
- Width: card interior minus horizontal padding → `--card-content-w: calc(100% - 2 * var(--card-pad-x))`.
- Height depends on grid mode (see below).
- Exposed as a container element that content fills.

**Two grid modes, same content box:**

| Property | Rigid mode (Now page) | Fluid mode (other pages) |
|---|---|---|
| Grid `auto-rows` | `var(--card-quarter-row)` | `auto` |
| Content box **width** | Fixed (from card footprint - padding) | Same |
| Content box **height** | Fixed: `--card-row - --card-header-h - (2 × --card-pad-y)` — content clips at boundary | **Min-height** from same formula; grows to fit content |
| Overflow | Hidden — content must fit | Visible — content expands the card |
| Use case | Charts, gauges, compass, radar — fixed visual fills the box | Legal text, forecast tables, record lists — variable-length content |

A card on a fluid page can opt into fixed-height behavior by setting `overflow: hidden` and constraining to the content box height. The mode is inherited from the grid context (Now grid vs PageLayout grid), not declared per-card.

**New tokens:**

| Token | Desktop | Mobile | Meaning |
|---|---|---|---|
| `--card-pad` | 1rem | 1rem | Card padding — uniform on all four sides |
| `--card-header-h` | 2.5rem | 2.5rem | Header slot height (title + underline + spacing) |
| `--card-content-h` | `calc(var(--card-row) - var(--card-header-h) - 2 * var(--card-pad))` | same formula | Content slot height (rigid mode); min-height (fluid mode) |

Padding is proportional: left, right, top, and bottom are all `--card-pad` (1rem). Previous `py-2.5` (0.625rem) was disproportionately tight vs `px-4` (1rem), causing cards to look squeezed vertically. Uniform padding eliminates that asymmetry.

Derived content box heights (desktop):

| Card role | Card height | Header | Padding (×2) | Content box |
|---|---|---|---|---|
| Half-row (page header) | 6.5rem | 2.5rem | 2rem | 2rem |
| Data card (1-row) | 13rem | 2.5rem | 2rem | 8.5rem |
| Tall card (2-row) | 26rem | 2.5rem | 2rem | 21.5rem |

Validated against current content: tallest 1-row content is 7rem (gauges/charts), which fits within 8.5rem with 1.5rem headroom. Tallest 2-row content is ~20rem (wind compass / current conditions), which fits within 21.5rem.

**Designer mental model:** "I get a title string and a content box. On the Now page, the box is 8.5rem × (card width - 2rem). I design inside it. On other pages, same width, same minimum height, but it grows if I need more room."

### Updated acceptance criteria (additive — content box)

- [ ] `--card-pad`, `--card-header-h`, `--card-content-h` tokens exist in `index.css`.
- [ ] `Card` component uses `--card-pad` for padding on all four sides — no hardcoded `py-2.5` / `px-4`.
- [ ] `CardHeader` height is constrained to `--card-header-h`.
- [ ] `CardContent` exposes the content box: width from `--card-pad`, height/min-height from `--card-content-h`.
- [ ] On the Now page grid, content box clips overflow (rigid mode).
- [ ] On non-Now pages (PageLayout), content box grows to fit content (fluid mode) with `--card-content-h` as min-height.
- [ ] No card component sets its own padding, header height, or content area dimensions — all derive from tokens.
- [ ] Token arithmetic holds with new values: 3.25 × 2 = 6.5, 3.25 × 4 = 13, 3.25 × 8 = 26 (desktop).

---

## Amendment 2026-06-16 — Extra-tall row span (2.5)

**Accepted:** 2026-06-16

Adds `rowSpan="2.5"` (10 quarter-tracks) to the row-span vocabulary. Desktop height: 32.5rem (3.25 × 10). Mobile min-h: 37.5rem (3.75 × 10). Content box: 28rem desktop (32.5 - 2.5 - 2).

Use case: charts or content cards that need more vertical space than 2× but less than a full page scroll. Token arithmetic: 3.25 × 10 = 32.5 ✓ (desktop), 3.75 × 10 = 37.5 ✓ (mobile).

Updated row-span model:

| Role | rowSpan | Track count | Desktop height | Mobile min-h |
|---|---|---|---|---|
| Control strip | `"quarter"` | 1 | 3.25rem | 3.75rem |
| Page header | `"half"` | 2 | 6.5rem | 7.5rem |
| Data card | `1` | 4 | 13rem | 15rem |
| Tall card | `2` | 8 | 26rem | 30rem |
| Extra-tall card | `2.5` | 10 | 32.5rem | 37.5rem |
