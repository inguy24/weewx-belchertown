# Dashboard Fix-It Tracker

Tracks discrete UI/layout bugs and design-manual-compliance gaps discovered during development. Each item references the governing design manual section and the file(s) to change.

Last updated: 2026-06-16

---

## Context — Read Before Starting Any Fix

The coordinator reads these files before researching or dispatching any fix. Agents receive only the relevant excerpts — not the full files.

### Required reading (coordinator)

| Document | What it provides | When to read |
|---|---|---|
| `docs/DESIGN-MANUAL.md` | Single authority for all UI design rules — tokens, typography, color, card anatomy, components, accessibility, anti-patterns | Before every fix |
| `docs/ARCHITECTURE.md` | Service topology, endpoint registry, dashboard page routes, container inventory | Before fixes that touch routing, data flow, or page composition |
| `rules/coding.md` | §5 accessibility (WCAG 2.1 AA), §6 Recharts reference discipline, §8 build verification (zero TS errors), §9 design system compliance | Before every fix |
| `rules/clearskies-process.md` | Agent orchestration, scope binding, QC gates, round-close verification | Before dispatching any agent |
| `docs/reference/recharts-axis-reference.md` | Recharts axis/margin/tick behavior — non-obvious layout rules | Before any chart fix (FIX-019 chart ticks, FIX-013 chart cards) |
| `repos/weewx-clearskies-dashboard/src/index.css` | Actual token definitions — compare against design manual values | Before token fixes (FIX-005, FIX-006, FIX-021) |
| `repos/weewx-clearskies-dashboard/src/components/ui/card.tsx` | Card/CardHeader/CardTitle primitives — the foundation every card builds on | Before card primitive fixes (FIX-006, FIX-012/013) |

### Per-fix research (coordinator does this, not the agent)

Before dispatching an agent for any FIX item:
1. **Read the design manual section** the fix references — understand the target state
2. **Read the current code** for every file listed in the fix — understand the current state
3. **Identify cascading impacts** — what other components use the same token, class, or pattern? Will changing it break them?
4. **Write the agent brief** with exact values, exact files, exact lines, and grep-checkable acceptance criteria
5. **Include the content box math** — if the fix changes any dimension (font size, padding, height), calculate whether content still fits: card height - header height - 2×padding = content box. Verify at both desktop and mobile token values.

### QC after every fix (coordinator does this, not the agent)

1. `npx tsc --noEmit` — zero errors
2. `npx vite build` — succeeds
3. Visual check: render every affected page at 1024px (desktop) and 375px (mobile) — screenshot and inspect
4. **Cascade check:** grep for the changed token/class/value across all files. Any file that references it must still work correctly. If not, file a new FIX item before proceeding.
5. If the fix introduced new FIX items (cascade), slot them into the execution order below before continuing.

---

## Execution Order

**These FIX items have cascading dependencies.** Changing font sizes, font weights, padding, and card header heights all affect how content fits inside cards. Fixing typography (FIX-019) without first establishing the content box contract (FIX-006) will cause content to overflow or clip. Fixing row heights (FIX-005) without fixing card padding (FIX-006) changes the available space every card relies on.

### Phase 1 — Foundation tokens (set the containers)

| Order | FIX | What changes | Cascade risk |
|---|---|---|---|
| 1a | FIX-005 | Row height tokens in `index.css` → Option B values | Every card's grid-track height changes; content may overflow |
| 1b | FIX-006 | New tokens: `--card-pad`, `--card-header-h`, `--card-content-h`; Card uses `--card-pad` | Every card's internal spacing changes |
| 1c | FIX-021 | `--card` dark, `--alert-fg` dark value corrections | Color-only; low cascade risk |

**QC gate:** After Phase 1, every page must render without clipping or overflow. The token arithmetic must hold (verify in both breakpoints). Content may look wrong (old font sizes in new containers) — that's expected; Phase 3 fixes it.

### Phase 2 — Card primitives (build correct containers)

| Order | FIX | What changes | Cascade risk |
|---|---|---|---|
| 2a | FIX-012 | CardHeader structured contract: fixed height, flex layout, underline, controls slot | Every card that touches CardHeader is affected |
| 2b | FIX-013 Phase 2 | Create `HeaderTabs`, `HeaderToggle`, `HeaderSelect`, `HeaderButton` components | New components; no cascade until cards migrate to them |
| 2c | FIX-001 | PageHeaderCard/NowHeroCard — remove `!py` overrides, enforce min-h | Page headers resize; verify icon/title still fit |
| 2d | FIX-013 Phase 3 | Migrate all ~20 cards from Pattern A to CardTitle; remove all ad-hoc overrides | Every card changes; highest-risk phase |

**QC gate:** After Phase 2, every card uses CardTitle, no Pattern A `<h2>` elements remain, no `!py`/`!px`/`!important` overrides remain. Verify all 9 pages at both breakpoints.

### Phase 3 — Content fixes (fix what's inside the containers)

| Order | FIX | What changes | Cascade risk |
|---|---|---|---|
| 3a | FIX-019 | Typography sweep: weight 500 → 400/600, Tailwind text-sizes → tokens, hardcoded inline sizes → tokens, sub-minimum sizes → micro, chart ticks 11px → 14px | Font size changes affect line wrapping and content height; verify content still fits content box |
| 3b | FIX-020 | Remove opacity modifiers from text colors | Color-only; may need to choose different tokens for desired visual weight |
| 3c | FIX-022 | Forecast card headings — `<span>` → `<CardTitle>` | Heading now has font/weight from CardTitle; verify it fits header slot |
| 3d | FIX-024 | CollapsibleCard — div role="button" → native `<button>` | Structural change; verify keyboard activation and focus |
| 3e | FIX-023 | WindCompassCard `prefers-reduced-motion` guard | Motion-only; no layout impact |
| 3f | FIX-004 | Page header icon/title scale to fill half-row | Depends on Phase 1 (correct half-row height) and Phase 2 (correct header) |

**QC gate:** After Phase 3, `grep -r "font-medium\|fontWeight.*500\|text-xs\|text-sm\|text-muted-foreground/" src/` returns zero hits (excluding shadcn/ui primitives). All heading elements are semantic. All text ≥ `--text-micro`. Visually verify content fits containers on all 9 pages at both breakpoints.

### Phase 4 — Visual/surface fixes (non-dimensional)

| Order | FIX | What changes | Cascade risk |
|---|---|---|---|
| 4a | FIX-025 | Alert banner: card-glass → alert-glass surface | Visual only |
| 4b | FIX-016 | Alert chevron: full-region tap target, mobile sizing | Layout change within alert; verify alert fits |
| 4c | FIX-017 | Reports table restyle per data table standards | Table-internal; no card-level cascade |
| 4d | FIX-018 | Horizontal scroll nav standardization | Per-card; verify scroll buttons don't overlap content |
| 4e | FIX-027 | Free-floating content → card wrappers | Layout change; verify grid still flows correctly |

**QC gate:** Visual verification of all affected pages at both breakpoints.

### Phase 5 — Page-specific fixes

| Order | FIX | What changes | Cascade risk |
|---|---|---|---|
| 5a | FIX-002 | Legal page text fade gradient | Visual only |
| 5b | FIX-003 | Legal page text color tokens | Color only (after FIX-020 removes opacity modifiers) |
| 5c | FIX-007 | Branding provider station photo mapping | Data wiring; no UI cascade |
| 5d | FIX-008 | Wizard "About This Station" textarea | Wizard-only |
| 5e | FIX-009 | About page hide empty cards | Conditional render; no layout cascade |
| 5f | FIX-010 | About page text hierarchy | Typography; verify against Phase 3 token state |
| 5g | FIX-011 | Reports table column pairing | Table-internal (after FIX-017 restyle) |

### Phase 6 — Wizard fixes (separate repo, no dashboard cascade)

| Order | FIX | What changes | Cascade risk |
|---|---|---|---|
| 6a | FIX-026 | Wizard accessibility sweep (aria-describedby, labels, roles, key fields, emoji, OOB guard) | Wizard-only; no dashboard impact |
| 6b | FIX-015 | Wizard theme selection — radio buttons with visual previews | Wizard-only |

### After all phases — Final verification

- `npx tsc --noEmit` — zero errors
- `npx vite build` — succeeds
- Full visual walk of all 9 dashboard pages at desktop (1024px) and mobile (375px)
- Full keyboard-only navigation walk
- `npx @axe-core/cli` on every page — zero violations
- Any new issues found → new FIX items, slotted into the correct phase

---

## Open Items

### FIX-001: PageHeaderCard height does not comply with ADR-051

**ADR:** ADR-051 (card footprint model), acceptance criteria line 287, line 290, token table line 247.

**Problem:** Three compounding issues prevent page-header cards from reaching the half-row height the ADR specifies:

1. **Ad-hoc padding override (banned).** `page-header-card.tsx:78` applies `!py-1 md:!py-2.5`. ADR-051 acceptance criteria explicitly bans ad-hoc Card className overrides for sizing ("`py-2`, manual `min-h-[var(--card-half-row)]`").

2. **Desktop min-height zeroed out on non-Now pages.** `card.tsx:69` — `minHeightClass("half")` returns `min-h-[5.5rem] md:min-h-0`. The `md:min-h-0` wipes out the minimum height on desktop for all non-Now pages (which use `auto-rows-[auto]`). The ADR says non-Now pages use content-adaptive heights *with `min-h` from `rowSpan` preventing collapse* — the min-h should still apply.

3. **Wrong mobile min-height value.** `minHeightClass("half")` hardcodes `min-h-[5.5rem]` — the desktop value. The ADR token table says `--card-half-row` is 6.5rem on mobile, 5.5rem on desktop. Should use `min-h-[var(--card-half-row)]` to get the correct value at each breakpoint.

**Affected pages:** ALL pages — including Now.

**Now page hero card is worse:** `NowHeroCard` is rendered outside the grid, so grid tracks can't size it. Height is purely content-driven (4rem logo + `!py-1` padding). With `md:min-h-0`, there is zero minimum height on desktop. It also uses `!py-1` — the same banned override.

**Files:**
- `repos/weewx-clearskies-dashboard/src/components/layout/page-header-card.tsx` — remove `!py-1 md:!py-2.5` override
- `repos/weewx-clearskies-dashboard/src/components/layout/now-hero-card.tsx` — remove `!py-1` override, ensure min-h enforced outside grid
- `repos/weewx-clearskies-dashboard/src/components/ui/card.tsx` — fix `minHeightClass("half")` to use the CSS variable and retain min-h at md+

---

### FIX-002: Legal page CollapsibleCard text fade too aggressive

**Problem:** When a CollapsibleCard is collapsed, the CSS mask fades text starting at 40% of the visible area (`linear-gradient(to bottom, black 40%, transparent 100%)`). This makes roughly half the preview text unreadable. The fade should only affect the very bottom of the card to give a subtle "there's more content" hint.

**File:** `repos/weewx-clearskies-dashboard/src/routes/legal.tsx:59` — the `maskImage` / `WebkitMaskImage` gradient in the `CollapsibleCard` component.

**Fix:** Increase the opaque portion of the gradient so the fade only covers the last ~20% of the visible area (e.g. `black 80%, transparent 100%`).

---

### FIX-003: Legal page body text uses wrong color tokens

**ADR:** ADR-048 (theme color tokens), coding.md §5.1 (WCAG AA contrast ≥ 4.5:1).

**Problem:** Legal page body text uses ad-hoc opacity modifiers on `muted-foreground` instead of the standard text tokens:

- `Body` component: `text-muted-foreground/80` — should be `text-foreground`
- `BodySmall` component: `text-muted-foreground/70` — should be `text-muted-foreground` (no opacity modifier)
- `BulletList`: `text-muted-foreground` — acceptable for secondary content but body text of legal documents should be primary text color

The `/80` and `/70` opacity modifiers are ad-hoc one-offs not from any token. Over the translucent glass card + sky background, they likely fail WCAG AA contrast (4.5:1).

**File:** `repos/weewx-clearskies-dashboard/src/routes/legal.tsx` — `Body` (line 101), `BodySmall` (line 109), `BulletList` (line 117).

---

### FIX-004: Page header icon and title font too small for half-row card; Legal page fonts far below type scale tokens

**ADR:** ADR-051 (page-header card = half-row, 5.5rem desktop), ADR-048/index.css type scale tokens.

**Problem — page header card (site-wide):** Once FIX-001 restores the correct half-row height (5.5rem), the current icon (2rem) and title (`text-xl` = 1.25rem) will be undersized and lost in the card. Both need to scale up proportionally to fill the half-row height.

**Problem — Legal page font sizes:** All text uses `text-xs` (0.75rem) or smaller (`0.65rem`), ignoring the type scale tokens defined in `index.css`:

| Element | Current | Token | Token value |
|---|---|---|---|
| Section headings | `text-xs` (0.75rem) | `--text-section` | 0.95rem |
| Body text | `text-xs` (0.75rem) | `--text-body` | 0.9rem |
| Small text | `text-[0.65rem]` | `--text-label` | 0.75rem |
| Bullet lists | `text-xs` (0.75rem) | `--text-body` | 0.9rem |

Body text is 17% smaller than the design system specifies. This is likely a site-wide problem — need to audit all pages for type scale token compliance.

**Files:**
- `repos/weewx-clearskies-dashboard/src/components/layout/page-header-card.tsx` — icon size and title font
- `repos/weewx-clearskies-dashboard/src/routes/legal.tsx` — all text components
- Audit needed: all route files for type scale compliance

---

### FIX-005: Row height tokens too small — Option B approved

**ADR:** ADR-051 (card footprint model) — requires amendment.

**Decision:** Option B selected (see `docs/planning/briefs/ROW-HEIGHT-OPTIONS.md`).

**Changes — tokens in `index.css`:**

| Token | Current (desktop / mobile) | New (desktop / mobile) |
|---|---|---|
| `--card-quarter-row` | 2.75rem / 3.25rem | 3.25rem / 3.75rem |
| `--card-half-row` | 5.5rem / 6.5rem | 6.5rem / 7.5rem |
| `--card-row` | 11rem / 13rem | 13rem / 15rem |
| `--card-content-max` | 7rem / 9rem | 9rem / 11rem |
| `--text-card-title` | 0.82rem | 1.1rem |

**Scope:** Site-wide, including Now page cards.

**Files:**
- `repos/weewx-clearskies-dashboard/src/index.css` — update token values
- `docs/decisions/ADR-051-card-footprint-model.md` — amend token table (done — 2026-06-16 amendment)
- Page header icon/title sizes (FIX-004) should be scaled proportionally after this change

---

### FIX-006: Implement card content box contract (ADR-051 amendment 2026-06-16)

**ADR:** ADR-051, amendment §11 (card content box contract).

**Problem:** Card content dimensions are implicit — every component guesses at available space differently, producing ad-hoc sizing. No defined contract for card designers.

**What to build:**

1. New tokens in `index.css`: `--card-pad` (1rem uniform), `--card-header-h`, `--card-content-h`
2. `Card` component uses `--card-pad` for all four sides instead of hardcoded `py-2.5` / `px-4`
3. `CardHeader` height constrained to `--card-header-h`
4. `CardContent` exposes the content box with known width and height/min-height
5. Two modes inherited from grid context:
   - **Rigid (Now page):** content box is fixed height, overflow hidden
   - **Fluid (other pages):** content box has min-height from same token, grows to fit content

**Files:**
- `repos/weewx-clearskies-dashboard/src/index.css` — new tokens
- `repos/weewx-clearskies-dashboard/src/components/ui/card.tsx` — Card, CardHeader, CardContent use tokens
- All card components — remove ad-hoc padding/height overrides, build against content box

---

### FIX-007: Station photo missing on About page — branding provider drops fields

**Problem:** `BrandingProvider` maps the API response to `BrandingConfig` but never maps `stationPhotoUrl` or `stationPhotoAlt`. The fields exist on the type and the About page reads them, but the provider silently drops them. The photo always shows the dashed placeholder.

**Fix:** Add two lines to the `useMemo` mapping in `branding-provider.tsx`:
```
stationPhotoUrl: apiData.stationPhotoUrl,
stationPhotoAlt: apiData.stationPhotoAlt,
```

**File:** `repos/weewx-clearskies-dashboard/src/lib/branding-provider.tsx` — lines 42-58

---

### FIX-008: No wizard field for "About This Station" content

**Problem:** The About page renders an "About This Station" card via `useContent('about')`, which fetches `GET /content/about` from the API (a markdown file from the operator's config directory). But the wizard's step 6 (Station Identity) has no textarea or upload for this content. An operator going through the wizard has no way to populate it — the card always shows the placeholder text.

**Fix:** Add an optional textarea to wizard step 6 for the operator to write an "about this station" description. The wizard backend saves it as the markdown file the API serves at `/content/about`.

**Files:**
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_station.html` — add textarea field
- `repos/weewx-clearskies-stack/weewx_clearskies_config/wizard/routes.py` — handle saving the content
- Verify API's `/content/about` endpoint reads from the expected file path

---

### FIX-009: About page shows empty placeholder cards when operator hasn't configured content

**Problem:** The Station Photo and About This Station cards render dashed-border placeholders when no content is configured. These should be hidden entirely — operators who didn't supply a photo or description shouldn't have empty cards visible to visitors.

**Fix:** Conditionally render both cards only when data exists:
- Station Photo card: only render when `branding.stationPhotoUrl` is non-empty
- About This Station card: only render when `useContent('about')` returns non-null data

**File:** `repos/weewx-clearskies-dashboard/src/routes/about.tsx` — lines 162-205

---

### FIX-010: About page station metadata card — flat hierarchy and inverted label emphasis

**Problem:** The station metadata `<dl>` grid has no text hierarchy:
- Labels (`<dt>`): `text-sm text-muted-foreground` — lighter, de-emphasized
- Values (`<dd>`): `text-sm font-medium text-foreground` — darker, prominent

Both are the same size (`text-sm`). The labels that tell you what each field *is* are visually weaker than the values. There's no size contrast to create hierarchy.

**Fix:** Use the type scale tokens to create hierarchy:
- Labels: `--text-label` (0.75rem), `text-muted-foreground`, uppercase or semibold — small, structural
- Values: `--text-body` (0.9rem), `text-foreground`, normal weight — readable, prominent

This matches the pattern used on the Now page data cards where labels are micro-sized and values are the focal element. The label stays subordinate by size, but the color inversion is fixed because the value is now clearly larger.

**File:** `repos/weewx-clearskies-dashboard/src/routes/about.tsx` — lines 103-154

---

### FIX-011: Reports table — Time columns not visually linked to their parent measurement

**Problem:** The reports table has three "Time" columns (for High temp, Low temp, and Peak Gust), but there's no visual grouping to show which Time belongs to which measurement. All columns are evenly spaced and identically styled — a reader has to count columns to figure out that the first "Time" goes with "High", the second with "Low", and the third with "Peak Gust".

**Fix:** Visual pairing — tighten spacing between a measurement and its time column, add a subtle visual separator (background band or left-border) between groups so paired columns read as a unit.

**File:** `repos/weewx-clearskies-dashboard/src/routes/reports.tsx` (or the component rendering the NOAA table)

---

### FIX-012: Card header inconsistency — two patterns, ad-hoc control placement

**ADR:** [ADR-062](../decisions/ADR-062-card-header-contract.md) (Accepted)

**Problem:** Card headers are implemented two completely different ways:

**Pattern A (10 Now-page cards):** Custom inline `<h2>` with hand-copied classes:
```
<h2 className="font-heading leading-snug font-semibold pb-0.5 border-b border-border"
    style={{ fontSize: 'var(--text-card-title, 0.82rem)' }}>
```
Uses `pb-0.5`, underline via `border-b`, no `mb-*` below the title.

**Pattern B (Almanac, Forecast, Webcam, Charts):** `<CardTitle>` component with `pb-1.5 mb-3 border-b`. Different spacing, different underline width behavior.

Cards with controls (NowForecastCard, WebcamCard, PlanetTimelineCard, ForecastDailyCard) each build their own flex layout inside `<CardHeader>` for tabs/toggles/pills — different alignment, different spacing, different button styles.

**Result:** Underline spacing varies card to card. Some underlines span the full card, others don't. Control placement is ad-hoc. No pre-defined slots for header controls.

**Fix:** This is the header slot from the content box contract (FIX-006 / ADR-051 §11). The `CardHeader` component needs to:
1. Own all header styling — title font, underline, spacing — in one place
2. Provide a defined **controls slot** (right-aligned) with pre-styled patterns for common control types (button, dropdown, toggle, tab pills)
3. All cards use `CardHeader` + `CardTitle` — zero custom `<h2>` elements with hand-copied classes
4. Controls slot has pre-defined sizes/colors so card authors only specify *what* control, not *how* it looks

**Scope:** All card components — eliminate Pattern A entirely, standardize Pattern B, add controls slot.

---

### FIX-013: Bring all existing code into ADR-051/ADR-062 compliance

**ADRs:** ADR-051 (card footprint model, all amendments), ADR-062 (card header contract)

**Problem:** ADR-051 amendments (row heights, content box contract, uniform padding) and ADR-062 (card header contract) are accepted but no existing code complies. This item tracks the full migration pass.

**Execution order (dependency-driven):**

**Phase 1 — Foundation tokens**
- [ ] FIX-005: Update row height tokens in `index.css` (Option B values)
- [ ] FIX-006: Add content box tokens (`--card-pad`, `--card-header-h`, `--card-content-h`)

**Phase 2 — Card primitives**
- [ ] `Card`: uniform `--card-pad` padding, remove hardcoded `py-2.5`/`px-4`
- [ ] `CardHeader`: structured flex container at `--card-header-h`, underline spans full width
- [ ] `CardTitle`: simplified to heading text only (no border, no margin)
- [ ] `CardContent`: expose content box with height/min-height from `--card-content-h`
- [ ] Create `HeaderTabs`, `HeaderToggle`, `HeaderSelect`, `HeaderButton` in `components/ui/header-controls.tsx`
- [ ] `ControlsStrip`: uses same approved control components

**Phase 3 — Migrate all cards (~20 components)**
- [ ] Eliminate all Pattern A custom `<h2>` elements (BarometerCard, SolarRadiationCard, UvIndexCard, AqiCard, PrecipitationCard, LightningCard, EarthquakeCard, WindCompassCard, TodaysHighlightsCard, SunMoonCard)
- [ ] Migrate custom control layouts to approved components (NowForecastCard, WebcamCard, PlanetTimelineCard, ForecastDailyCard, ForecastHourlyCard, ForecastDiscussionCard)
- [ ] Remove all `!py`, `!important`, ad-hoc padding/height overrides from all cards
- [ ] FIX-001: Fix PageHeaderCard and NowHeroCard (remove overrides, enforce min-h)
- [ ] FIX-004: Scale page header icon and title proportionally to new half-row

**Phase 4 — Page-specific fixes**
- [ ] FIX-002: Legal page text fade (gradient `black 80%`)
- [ ] FIX-003: Legal page text color tokens
- [ ] FIX-004: Legal page type scale token compliance
- [ ] FIX-007: Branding provider station photo mapping
- [ ] FIX-009: About page hide empty cards
- [ ] FIX-010: About page text hierarchy
- [ ] FIX-011: Reports table column pairing

**Phase 5 — Verify**
- [ ] `npx tsc --noEmit` — zero errors
- [ ] Visual inspection of every page (Now, Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal)
- [ ] ADR-051 acceptance criteria all checked
- [ ] ADR-062 acceptance criteria all checked

---

### FIX-018: Inconsistent horizontal scroll navigation across cards

**Problem:** Cards with horizontally scrolling content (hourly forecast, 7-day forecast, meteor showers, eclipse timeline) use different scroll mechanisms — some have a small chevron on one side, some rely on swipe-only, some have different button styles. The design manual §11 (Horizontal Scroll Navigation) now defines a single pattern: round chevron buttons on both sides of the card, projecting into the margin space, hiding at scroll boundaries.

**Fix:** Standardize all horizontally scrolling cards to use the Horizontal Scroll Navigation pattern:
- Round chevron buttons (left + right) using `ph:caret-left` / `ph:caret-right`
- Buttons may project into the grid margin/gutter
- Card-glass surface, shadow, vertically centered
- Hide at scroll boundaries (no left button at start, no right button at end)
- Swipe still supported alongside buttons
- `aria-label` on each button, `role="region"` on scroll container

**Cards to update:**
- Hourly forecast strip (Forecast page)
- 7-day forecast strip (Forecast page)
- Meteor showers carousel (Almanac page)
- Eclipse timeline (Almanac page)
- Any other horizontally scrolling card

**Files:** Components rendering these cards in `repos/weewx-clearskies-dashboard/src/`

---

### FIX-017: Reports table does not comply with design manual data table standards

**Problem:** The Reports page NOAA table violates several data table standards from the design manual §11:

1. **Headers de-emphasized below data.** Column headers (Day, Mean Temp, High, Time, Low, etc.) are visually lighter/weaker than the data cells. Headers should be the dominant wayfinding element — semibold, uppercase or small-caps, using `--text-label`.
2. **No column grouping.** Related columns (High + Time, Low + Time, Peak Gust + Time + Dir) have no visual grouping — a reader must count columns to associate a "Time" with its parent measurement. Need tighter internal spacing within groups and subtle separators between groups, or spanning `<th colspan>` group headers.
3. **No alternating row backgrounds.** 14 columns of same-weight data with no row striping makes it difficult to scan horizontally across a row.
4. **No sticky first column on mobile.** The Day column scrolls off-screen on mobile, losing row context.
5. **Cell spacing feels cramped** for a table this dense.

**Fix:** Restyle the Reports table to comply with the design manual's Data Tables component pattern:
- Headers: `--text-label`, `font-weight: 600`, uppercase, visually dominant
- Data cells: `--text-body` or `--text-secondary`, `font-weight: 400`, right-aligned numbers with `tnum`
- Alternating row backgrounds (`bg-muted/30`)
- Column grouping for measurement + time pairs
- Sticky first column on mobile
- Adequate cell padding (≥0.5rem horizontal, ≥0.375rem vertical)

**File:** `repos/weewx-clearskies-dashboard/src/routes/reports.tsx` (or the NOAA table component)

---

### FIX-016: Alert banner expand/collapse chevron — touch target and mobile sizing

**Problem:** Two issues with the alert banner's expand/collapse chevron:

1. **Tap target too small.** Only the chevron icon itself is clickable. The entire right-side area (the visual "button" square) should be the tap target — users expect the whole region to respond, not just the small icon within it.

2. **Mobile chevron area too large.** The chevron region takes up too much horizontal space on mobile, eating into the alert headline text. Desktop size is fine. Mobile needs a smaller chevron area that still meets the 44×44px minimum touch target.

**Fix:**
- Make the entire chevron region the click/tap target (wrap in `<button>` if not already, or expand the button's padding to fill the region)
- Reduce the chevron region width on mobile (while keeping ≥44×44px touch target)
- Desktop chevron region stays current size

**File:** `repos/weewx-clearskies-dashboard/src/components/alerts/alert-banner.tsx` (or wherever the alert expand/collapse is implemented)

---

### FIX-015: Wizard theme selection needs visual radio selectors instead of dropdown

**Problem:** The wizard's "Colors & Theme" section (step 1, branding) uses a plain `<select>` dropdown for "Default Theme Mode" (Light / Dark / Match device / Match sunrise/sunset). This is a poor UX for a visual choice — the operator can't see what they're picking. The same applies to the accent color selector.

**Current state:** A single dropdown with text labels. The operator has to select each option, leave the wizard, and check the dashboard to understand what the option looks like.

**Fix:**
1. Replace the theme mode `<select>` with radio button selectors, each accompanied by a small visual thumbnail/preview showing what that theme looks like (light screenshot, dark screenshot, auto badge with sun/moon icon, sunrise/sunset badge with time-of-day icon).
2. Replace the accent color `<select>` with a visual color swatch radio group — 6 colored circles or pills showing the actual accent color, with the selected one highlighted.
3. Both should use `<fieldset>` + `<legend>` for accessibility, with each radio having a visible label alongside its visual preview.

**Files:**
- `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_branding.html` — replace dropdowns with radio groups + preview thumbnails
- `repos/weewx-clearskies-stack/weewx_clearskies_config/static/` — add preview thumbnail assets if needed
- Wizard CSS may need additions for the radio card layout

---

### FIX-019: Site-wide typography token compliance sweep

**Manual:** Design Manual §4 Typography, §18 Anti-Patterns (Typography)

**Problem:** Pervasive violations of the typography token system across the dashboard:

1. **font-weight 500 (banned):** `current-conditions-card.tsx` (4 inline uses), `font-medium` Tailwind class in `about.tsx` (~15), `seismic.tsx`, `reports.tsx`, `charts.tsx`, `records.tsx`, `nav-rail.tsx`, `alert-banner.tsx`, `skip-link.tsx`, `ConfigDrivenGroup.tsx`. Note: `font-medium` in shadcn/ui primitives (`badge.tsx`, `button.tsx`) is exempt.

2. **Tailwind text-size utilities instead of tokens:** `text-xs`, `text-sm`, `text-base`, `text-lg`, `text-xl` used for content across `about.tsx`, `seismic.tsx`, `legal.tsx`, `reports.tsx`, `charts.tsx`, `error-boundary.tsx`, `ConfigDrivenChart.tsx`, `WindRoseChart.tsx`, `HaysChart.tsx`, `LunarEclipseCard.tsx`, `cookie-consent-banner.tsx`, and consistently on retry buttons in error states (`barometer-card`, `aqi-card`, `earthquake-card`, `precipitation-card`, `ConfigDrivenGroup`).

3. **Hardcoded inline fontSize values:** `MeteorShowerCard.tsx` (14 instances of `text-[0.Nrem]`), `PlanetTimelineCard.tsx` (9 instances), `ForecastHourlyCard.tsx`, `webcam-card.tsx`, `page-header-card.tsx`, `ConfigDrivenChart.tsx`, `MonthlyAveragesCard.tsx`, `ChartGauge.tsx`.

4. **Below --text-micro minimum (0.7rem):** `aqi-card.tsx:537` (8px badge), `PlanetTimelineCard.tsx:984` (0.55rem), `ChartGauge.tsx` clamp lower bound (0.65rem), `nav-rail.tsx:62` (`md:text-[0.6rem]`).

5. **Chart tick fontSize:** Standard cards (`current-conditions-card.tsx`, `ConfigDrivenChart.tsx`, `MonthlyAveragesCard.tsx`, `WeatherRangeChart.tsx`) use 14px per `--text-chart-label`. **Tile-footprint cards** (`solar-radiation-card.tsx`, `uv-index-card.tsx`, `lightning-card.tsx`) use 11px per `--text-chart-label-sm` with `XAxis height={24}` and tighter margins `{ top: 2, right: 12, bottom: 0, left: 12 }` — 14px labels are too large for tile content areas. (Design manual updated 2026-06-17.)

6. **CardTitle fallback value:** `card.tsx:135` uses `0.82rem` fallback but manual specifies `1.1rem`.

**Fix:** Single sweep across all dashboard TSX files:
- Replace all `font-medium` with `font-normal` (400) or `font-semibold` (600) as contextually appropriate
- Replace all `text-xs`/`text-sm`/etc. with appropriate `var(--text-*)` token references
- Replace all hardcoded inline `fontSize` values with tokens
- Fix all sub-minimum sizes to at least `--text-micro`
- Standardize chart tick fontSize to 14px for standard cards, 11px for tile-footprint cards (per design manual tile-chart exception)
- Update CardTitle fallback to 1.1rem

---

### FIX-020: Site-wide text color opacity modifier removal

**Manual:** Design Manual §4 Text Color Usage, §18 Anti-Patterns (Typography)

**Problem:** Opacity modifiers on text color tokens create computed colors not in the audited design palette, potentially failing WCAG contrast requirements.

**Violations:**
- `legal.tsx:101` — `text-muted-foreground/80`
- `legal.tsx:109,321` — `text-muted-foreground/70`
- `MeteorShowerCard.tsx:244,409,417,502` — `text-muted-foreground/60`, `/70`
- `PlanetTimelineCard.tsx:422` — `text-muted-foreground/70`
- `PlanetTimelineCard.tsx:988` — `text-foreground/80`
- `alert-banner.tsx:301` — `text-card-foreground/75`
- `alert-banner.tsx:401` — `text-card-foreground/90`

**Fix:** Remove all opacity modifiers. Use the base token as-is, or switch to a different token (`text-muted-foreground` vs `text-foreground`) for the desired visual weight.

---

### FIX-021: Token value corrections in index.css

**Manual:** Design Manual §3 Color System, §5 Spacing & Layout

**Problem:** Several token values in `index.css` don't match the design manual:

| Token | Manual | Code | Issue |
|---|---|---|---|
| `--card` (dark) | `oklch(0.145 0 0)` | `oklch(0.205 0 0)` | Value mismatch |
| `--alert-fg` (dark) | `#fef3c7` | `#fbbf24` | Value mismatch |
| `--card-quarter-row` (desktop) | `3.25rem` | `2.75rem` | Media query has pre-amendment value |
| `--card-half-row` (desktop) | `6.5rem` | `5.5rem` | Same — old values |
| `--card-row` (desktop) | `13rem` | `11rem` | Same — old values |
| `card.tsx` base padding | `--card-pad` (1rem) | `py-2.5` (0.625rem) | Wrong value, wrong mechanism |

Note: FIX-005 already tracks the row height token updates and FIX-006 tracks the missing content box tokens. This item covers the color mismatches and the card.tsx base padding that FIX-005/006 don't cover.

**Fix:** Update `--card` dark and `--alert-fg` dark in `index.css` to match the manual. The row height and content box tokens are tracked by FIX-005/006.

---

### FIX-022: Forecast card headings — missing semantic heading elements

**Manual:** Design Manual §11 CardHeader+CardTitle, §16 Accessibility (Semantic HTML)

**Problem:** `ForecastHourlyCard.tsx` and `ForecastDailyCard.tsx` render card titles as `<span>` elements inside custom `<div>` layouts — no `<h2>` or any heading element. Screen readers cannot discover these cards by heading navigation. Violates WCAG 1.3.1 (Info and Relationships).

Also: both cards style controls inline with a custom `tabStyle()` function instead of using the approved `HeaderTabs` component.

**Fix:**
- Replace custom `<span>` titles with `<CardTitle as="h2">`
- Replace custom tab buttons with `HeaderTabs` (once FIX-012/013 creates it)

**Files:** `repos/weewx-clearskies-dashboard/src/components/forecast/ForecastHourlyCard.tsx`, `ForecastDailyCard.tsx`

---

### FIX-023: prefers-reduced-motion compliance

**Manual:** Design Manual §14 Motion ("prefers-reduced-motion: reduce: disable all tweens")

**Problem:** `WindCompassCard.tsx` applies CSS transitions (`stroke 0.4s ease`, `stroke-width 0.4s ease`, `opacity 0.4s ease`) on SVG tick elements and runs a 1-second `requestAnimationFrame` bearing animation — neither has a `prefers-reduced-motion` guard. Users who set this OS preference still receive animated elements. Violates WCAG 2.3.3.

**Fix:** Check `prefers-reduced-motion` and skip all transitions/animations when set. The `usePrefersReducedMotion` hook already exists in `almanac.tsx` / `charts.tsx` — extract to a shared hook and use in WindCompassCard.

**File:** `repos/weewx-clearskies-dashboard/src/components/WindCompassCard.tsx`

---

### FIX-024: CollapsibleCard — native button instead of div role="button"

**Manual:** Design Manual §16 Accessibility, §18 Anti-Patterns ("Never use div onClick when button is correct")

**Problem:** `legal.tsx` CollapsibleCard applies `role="button"`, `tabIndex={0}`, `onClick`, and `onKeyDown` to `CardHeader`, which renders as a `<div>`. This is the exact div-with-role-button anti-pattern the manual prohibits. Some screen reader / browser combinations may not activate `role="button"` divs reliably.

**Fix:** Replace with a native `<button>` inside or wrapping CardHeader for the toggle action.

**File:** `repos/weewx-clearskies-dashboard/src/routes/legal.tsx`

---

### FIX-025: Alert banner — use alert-glass surface instead of card-glass

**Manual:** Design Manual §3 Alert Glass Surface, §8 Surface Treatment Inventory, §11 Alert Banner

**Problem:** Alert banner body region (`alert-banner.tsx:287`) uses `.card-glass` — the standard card surface. The manual specifies a distinct alert surface (`--alert-glass`, `--alert-border`, `backdrop-filter: blur(12px)`) for alert banners.

**Fix:** Apply alert-specific surface treatment to the alert banner body.

**File:** `repos/weewx-clearskies-dashboard/src/components/shared/alert-banner.tsx`

---

### FIX-026: Wizard accessibility fixes

**Manual:** Design Manual §16 Accessibility, §17 Wizard Design Standards

**Problem:** Multiple accessibility gaps across wizard step templates:

1. **Missing aria-describedby on inputs with hints:** `step_db.html` (db_host), `step_webcam.html` (3 inputs), `step_tls.html` (5 inputs), `step_feature_settings.html` (earthquake_default_days). Hints exist as `<small>` elements but aren't linked.

2. **webcam_enabled checkbox:** No `id` on input, no `for` on label — programmatic association impossible.

3. **step_api.html:** Pico nested-label pattern wraps `<small>` inside `<label>`, making hint text part of the label announcement rather than a separate description.

4. **Test result fragments:** `step_db_test_result.html`, `step_mqtt_test_result.html`, `step_provider_test_result.html` — injected `.alert-success`/`.alert-error` divs lack `role="status"`/`role="alert"`.

5. **Provider key fields:** `step_provider_key_fields.html` — secret inputs start as `type="text"` (exposed), toggle starts as "Hide" (wrong initial state). Should start as `type="password"` with "Show" label.

6. **step_station.html:** Emoji 📍 not wrapped in `aria-hidden="true"`.

7. **step_eula.html:** Missing `{% if not _in_layout %}` guard — duplicate progress bar nav on initial render.

8. **step_complete.html:** Error-path "Back to Review" uses `<a href="#">` instead of `<button type="button">`.

9. **step_tls.html:** `tls_dns_api_token` password field has no toggle button (all other secret fields do).

**Fix:** Address each item. The aria-describedby and label association issues are the same class — a single sweep of all wizard templates.

**Files:** All templates in `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/`

---

### FIX-027: Free-floating content without card wrapper

**Manual:** Design Manual §6 Card Rules ("Every element on every page is a card. No free-floating content.")

**Problem:** Two pages render content directly in the grid without a card wrapper:
- `almanac.tsx:94` — Monthly Averages `ConfigDrivenGroup` wrapper `<div>` sits in the grid as a non-card container
- `charts.tsx:204-222` — `role="tabpanel"` divs rendered as direct grid children without card surface

**Fix:** Either wrap in a Card primitive or verify that ConfigDrivenGroup/tabpanel renders Card children internally (in which case the wrapper div needs to be a transparent layout element, not a grid item).

**Files:** `repos/weewx-clearskies-dashboard/src/routes/almanac.tsx`, `charts.tsx`

---

## Completed Items

### FIX-014: Consolidate all UI design standards into a single design manual — COMPLETE

**Completed:** 2026-06-16

**Deliverable:** `docs/DESIGN-MANUAL.md` (955 lines, 18 sections). Covers tokens, typography, color, spacing, card anatomy, icons, backgrounds, navigation, page structure, component patterns, data formatting, responsive behavior, motion, theming, accessibility, wizard standards, and anti-patterns.

**Integration:**
- `CLAUDE.md` domain routing updated — UI tasks now load the design manual
- `rules/coding.md` §9 updated — references design manual as single authority
- `rules/clearskies-process.md` updated — new ADR lifecycle for UI decisions
- Pending implementation items (FIX-001 through FIX-013) are referenced inline in the manual where relevant with `⚠ PENDING FIX-###` markers
