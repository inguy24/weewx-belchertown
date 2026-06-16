# Design Manual — Drafting Plan

**Status:** ACTIVE
**Created:** 2026-06-16
**Components:** `docs/DESIGN-MANUAL.md` (new), all UI-related ADRs (reference, not modified), `CLAUDE.md` (routing update)

---

## Context

Design standards are scattered across 11 ADRs, 3 ADR amendments, `index.css` token definitions, `rules/coding.md` §5 and §9, and undocumented conventions embedded in the code. This sprawl is a root cause of ad-hoc UI coding — the rules exist but can't be operationally followed because nobody reads 8+ ADRs before making a UI change. Many good design patterns (glass treatment, tab pill styling, skeleton loading, form validation UX) have never been articulated as reusable standards.

A comprehensive audit was completed 2026-06-16 covering:
1. **Document audit** — 11 ADRs + coding rules (200+ extracted rules)
2. **Code audit** — 60+ tokens, 8 layout footprints, 15+ icon sizes, 4 glass treatments, 4 interaction patterns
3. **Wizard audit** — 15-step wizard with strong internal consistency, undocumented patterns worth capturing
4. **Best-practice research** — Material Design, Carbon, Atlassian, Polaris, USWDS structure analysis

Raw audit data: `docs/planning/briefs/DESIGN-MANUAL-AUDIT.md`

**Relationship to ADRs:** Once the design manual is complete, the UI-related ADRs are **retired and archived** — they are no longer authoritative. The design manual becomes the single living authority for UI design rules. Archived ADRs preserve the historical decision process (the *why*) but are not consulted for current rules.

**New ADR lifecycle for UI decisions:**
1. Decision needed → draft ADR (Proposed)
2. User approves → ADR becomes Accepted
3. Rules extracted → design manual amended with the new rules
4. ADR archived → moved to `docs/archive/decisions/`, status "Archived — consolidated into DESIGN-MANUAL.md"
5. Future reference → archived ADR explains *why*; manual is where you *follow* it

**ADRs to archive after consolidation:** ADR-009, ADR-022, ADR-023, ADR-024 (UI portions), ADR-026, ADR-047, ADR-048, ADR-049, ADR-050, ADR-051 (all amendments), ADR-062. Non-UI ADRs (API, deployment, data model, etc.) remain in `docs/decisions/` unchanged.

---

## 1. Current State & Issues

### A. What's Working Well

The dashboard and wizard have strong foundations that the design manual must capture and protect — not just fix what's broken.

| Area | What's Working | Evidence |
|---|---|---|
| Glass surface treatment | Consistent `.card-glass` utility across all cards, distinct alert glass, both themes | Single CSS class, shared everywhere |
| Sky background system | Condition-aware backgrounds, precipitation overlays, day/night logic, attribution | ADR-047 fully implemented, scene-background.tsx |
| Grid reflow | 4→2→1 column responsive collapse works correctly | Grid component, single definition |
| Font family selection | Manrope/Outfit/Lexend trio creates clear role separation (body/stats/charts) | Locked in tokens, consistent usage |
| Type scale tokens | 14 role-named tokens defined with semantic meaning | index.css, LOCKED 2026-05-31 |
| Theme system | No-flash `data-theme`, 4 modes, operator-configurable default | ADR-023 fully implemented |
| Operator branding | 6 curated accents (AA-verified), logo upload, site title, favicon | ADR-022, branding-provider.tsx |
| Wizard consistency | All 15 steps follow identical structure, strong a11y baseline, HTMX fragment architecture | Wizard audit confirmed high cohesion |
| Accessibility scaffold | Skip link, focus management, sr-only class, aria-live regions, per-change audit checklist | coding.md §5, wizard templates |
| Alert severity model | Geography-correct 4-tier severity, 13 icon mappings, proper ARIA | ADR-052, alert-banner.tsx |

### B. Systemic Issues — Why Ad-Hoc Coding Keeps Happening

| # | Issue | Root Cause | Impact |
|---|---|---|---|
| B1 | Design rules scattered across 11 ADRs + 3 amendments + coding.md | No single reference document | AI agent doesn't read 8 ADRs before every change, so it invents one-offs |
| B2 | ADRs amended repeatedly without consolidation | Amendment stacks on amendment; latest rule buried in §11 of a 300-line doc | Rules that exist on paper aren't found in practice |
| B3 | Code patterns never documented as standards | Good patterns (glass, tab pills, skeletons) exist only in code | No way to replicate them consistently; each new card re-invents |
| B4 | Two card header patterns coexist | Pattern A (custom `<h2>`) vs Pattern B (`CardTitle` component), each with different spacing | Underline width, title spacing, and control placement vary card to card |
| B5 | No defined card content box | Content dimensions are implicit ("whatever's left") | Every card guesses at available space differently; ad-hoc maxHeight/padding hacks |
| B6 | No pre-styled control components | Each card builds its own tab pills, toggles, dropdowns from scratch | Inconsistent sizing, font, color, border-radius across cards |
| B7 | Token values specified in ADRs but overridden in code | `!py-1`, `!important` padding hacks, hardcoded sizes bypass tokens | The token system exists but isn't enforced |
| B8 | No icon size scale | 15+ icon sizes scattered (8px through 115px) with no formal tokens | Icon sizing is ad-hoc per component |

### C. Specific Code Compliance Issues (from DASHBOARD-FIXIT.md)

| FIX # | Issue | ADR Violated | Severity |
|---|---|---|---|
| FIX-001 | PageHeaderCard/NowHeroCard ignore half-row height | ADR-051 | All pages affected |
| FIX-002 | Legal page text fade too aggressive | — (visual) | Legal page unreadable |
| FIX-003 | Legal page uses ad-hoc opacity colors (`/80`, `/70`) | ADR-048 | Likely fails WCAG AA |
| FIX-004 | Page header icon/title undersized; Legal page ignores type scale | ADR-051 type scale | Site-wide + Legal |
| FIX-005 | Row height tokens too tight, crushed card titles | ADR-051 (amended) | Site-wide |
| FIX-006 | No card content box contract exists in code | ADR-051 §11 (new) | Every card |
| FIX-007 | Branding provider drops stationPhotoUrl/Alt | — (bug) | About page |
| FIX-008 | No wizard field for "About This Station" content | — (gap) | Wizard + About page |
| FIX-009 | About page shows empty placeholder cards | — (UX) | About page |
| FIX-010 | About page text hierarchy flat/inverted | ADR-048 type scale | About page |
| FIX-011 | Reports table Time columns not linked to measurements | — (visual) | Reports page |
| FIX-012 | Two card header patterns, ad-hoc controls | ADR-062 (new) | Every card |
| FIX-013 | Full ADR-051/062 compliance pass needed | ADR-051, ADR-062 | ~20 components |

### D. Gaps — In Code But Not Documented

These patterns work well in the codebase but have never been written down as standards. At risk of being overwritten or inconsistently replicated.

| Pattern | Where It Lives | Risk If Not Documented |
|---|---|---|
| Card glass CSS (blur, saturate, opacity values) | `.card-glass` in index.css | New cards might use different blur/opacity values |
| Alert glass surface (separate treatment from card glass) | `.alert-glass` in index.css | Alert styling could drift from card styling |
| Modal overlay glass (blur 16px) | Eclipse card inline styles | Each new modal invents its own overlay |
| Skeleton loading (`animate-pulse rounded-lg bg-muted`) | Multiple cards, same pattern | Could diverge without a standard |
| Tab pill styling (inline styles with var() refs) | NowForecastCard, WebcamCard | Each new tabbed card copies and modifies |
| Container query in CardHeader | card.tsx `@container/card-header` | Advanced pattern could be removed as "unnecessary" |
| SVG arc visualization constants | sun-moon-card.tsx hardcoded | No way to replicate or resize consistently |
| Forecast cell height calculations | JavaScript pixel math in HourlyStrip, DailyColumns | Brittle, precision layout knowledge trapped in one file |
| Wizard progress bar CSS | layout.html `<style>` block | Wizard redesign could lose the pattern |
| Wizard password toggle pattern | Reusable function, accessible | Could be re-implemented poorly |
| Wizard HTMX OOB update pattern | Step templates + `_progress_bar.html` | Architecture knowledge trapped in template comments |

### E. Gaps — Documented But Not In Code

Rules that exist in ADRs but the code hasn't caught up.

| Rule | Source ADR | Current Code State |
|---|---|---|
| Card padding = 1rem uniform (`--card-pad`) | ADR-051 amendment 2026-06-16 | Code uses `py-2.5` (0.625rem) / `px-4` (1rem) — asymmetric |
| Card header height = 2.5rem (`--card-header-h`) | ADR-062 | No token exists; header height varies per card |
| Card content box with defined dimensions | ADR-051 §11 | No `--card-content-h` token; content area is implicit |
| Card title = 1.1rem | ADR-051 amendment 2026-06-16 | Code still has 0.82rem |
| Row heights = Option B values | ADR-051 amendment 2026-06-16 | Code still has old values |
| HeaderTabs/Toggle/Select/Button components | ADR-062 | Components don't exist yet |
| ControlsStrip uses approved controls only | ADR-062 | Strip accepts raw children |
| Zero custom `<h2>` in card headers | ADR-062 | 10 cards still use Pattern A |
| All cards use `--card-pad` for padding | ADR-051 §11 | Cards use hardcoded Tailwind classes |
| min-h enforced on non-Now page headers | ADR-051 | `md:min-h-0` zeroes it out |

### F. How the Design Manual Resolves These Issues

| Issue Category | Current State | Design Manual Fix |
|---|---|---|
| Scattered rules (B1, B2) | 8+ ADRs, amendments on amendments | One document, flat structure, imperative rules, ADRs archived |
| Undocumented patterns (D) | Good patterns trapped in code | Extracted, named, and standardized in component catalog |
| Code non-compliance (C, E) | ADR rules exist but code ignores them | Manual is the single reference loaded before any UI work; pending fixes tracked with FIX-### references |
| Ad-hoc one-offs (B3-B8) | Each card invents its own styling | Pre-styled components and token-backed dimensions leave nothing to invent |
| AI agent doesn't follow rules (B1) | Rules exist but agent doesn't read 8 ADRs | One file in CLAUDE.md routing; agent reads one document, not eight |

---

## 2. Orientation

**Read before starting any task:**
- `CLAUDE.md` — domain routing, operating rules
- `rules/coding.md` — §5 accessibility, §9 design system compliance
- `docs/planning/briefs/DESIGN-MANUAL-AUDIT.md` — raw audit data

**Deliverable:** `docs/DESIGN-MANUAL.md` — single file, ~1500-2000 lines, machine-parseable structure.

**Git safety:** Standard rules. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No pull/push/fetch/rebase/merge.

**QC role: Coordinator (Opus).** QC after every phase — not batched.

---

## 3. Document Structure & Content Specifications

**Structural rules (mandatory for every section):**
- Flat heading hierarchy: two levels max (`##` section, `###` subsection)
- Imperative voice: "Use `--text-body`" not "should generally use"
- Token names inline and grep-able
- Tables for token inventories (machine-readable)
- Do/Don't pairs for ambiguous cases
- Pending implementation items marked with `⚠ PENDING FIX-###`

Below: the exact content each section must contain. Agents assemble and format; they do not research.

---

### Section 1: Purpose, Scope & Glossary

**Content:**

This document is the single authority for all Clear Skies UI design rules. It governs the dashboard SPA (`weewx-clearskies-dashboard`), the setup wizard (`weewx-clearskies-stack`), and any future UI surface. Consumers: AI coding agents and human reviewers. When this document conflicts with any other source (archived ADRs, code comments, conversation history), this document wins.

**Glossary (these exact terms):**

| Term | Definition |
|---|---|
| Operator | Person who installs, configures, and maintains Clear Skies |
| Visitor | Person viewing the weather dashboard in a browser |
| Card | The sole layout primitive — every visible element is a card |
| Tile | A 1-column card (`footprint="tile"`) |
| Hero | The Now-page page-header card (station logo + name) |
| Glass | Translucent card surface with backdrop-filter blur over the background |
| Footprint | A card's column-span declaration (tile/wide/panel/full) |
| Row span | A card's row-track declaration (quarter/half/1/2/2.5) |
| Rigid mode | Now-page grid: fixed card heights from grid tracks, overflow hidden |
| Fluid mode | Non-Now pages: content-adaptive card heights, min-h prevents collapse |
| Header slot | The fixed-height top portion of a card (title + optional controls) |
| Content slot | The defined rectangular area below the header slot |
| Controls strip | A full-width quarter-row card for "many controls" below the page header |

---

### Section 2: Design Principles

**Content — exactly 5 principles:**

1. **Data density over decoration.** Weather dashboards exist to show data. Every pixel spent on decoration is a pixel not showing an observation. When density and aesthetics conflict, density wins. Example: the Now page fits 12+ data cards on one screen without scrolling — don't add whitespace "for breathing room" that pushes cards below the fold.

2. **Tokens over hardcoded values.** Every size, color, spacing, and font value comes from a CSS custom property. Zero hardcoded `px`, `rem`, `em`, or hex values in component code. Example: use `fontSize: 'var(--text-body)'` not `fontSize: '0.9rem'`.

3. **Mobile-first, desktop-extended.** Design for phone first. Desktop is more space, not a different product. The grid reflows from 1→2→4 columns; no feature is desktop-only. Example: tap targets ≥44×44px, no hover-only affordances.

4. **Accessible by default.** WCAG 2.1 AA is the floor, not a stretch goal. Accessibility issues are release-blocking — same severity as a security vulnerability. Example: every `<img>` has `alt`, every icon-only button has `aria-label`, every color pairing meets 4.5:1 contrast in both themes.

5. **Constrained choices, consistent output.** Operators pick from curated options (6 accents, 4 theme modes), not free-form inputs. Developers pick from pre-styled components (4 control types), not raw HTML. Constraint produces consistency. Example: no free-form color picker (would break WCAG); no custom `<h2>` in cards (use `CardTitle`).

---

### Section 3: Color System

**Content:**

#### Semantic Foreground Tokens

| Token | Light (oklch) | Dark (oklch) | Role |
|---|---|---|---|
| `--foreground` | `0.145 0 0` (near-black) | `0.985 0 0` (near-white) | Primary body text |
| `--card-foreground` | `0.145 0 0` | `0.985 0 0` | Text inside cards |
| `--muted-foreground` | `0.556 0 0` (mid-grey) | `0.708 0 0` | Secondary/subdued text, labels |
| `--primary-foreground` | `0.985 0 0` (near-white) | `0.15 0 0` (near-black) | Text on primary-colored backgrounds |
| `--secondary-foreground` | `0.205 0 0` | — | Text on secondary surfaces |
| `--accent-foreground` | `0.205 0 0` | — | Text on accent surfaces |
| `--destructive` | `0.577 0.245 27.325` | — | Destructive actions |

#### Semantic Background Tokens

| Token | Light | Dark | Role |
|---|---|---|---|
| `--background` | `oklch(1 0 0)` (white) | `oklch(0.145 0 0)` | Page background |
| `--card` | `oklch(1 0 0)` | `oklch(0.145 0 0)` | Card base (before glass) |
| `--muted` | `oklch(0.97 0 0)` | — | Muted surface |
| `--accent` | `oklch(0.97 0 0)` | — | Accent surface |

#### Card Glass Surface

| Property | Light | Dark |
|---|---|---|
| `--card-glass` | `255 255 255 / 0.88` | `30 35 55 / 0.85` |
| `backdrop-filter` | `blur(8px) saturate(1.1)` | same |
| Ring | `ring-1 ring-foreground/10` | same |

#### Alert Glass Surface

| Property | Light | Dark |
|---|---|---|
| `--alert-glass` | `rgba(255, 210, 100, 0.55)` | `rgba(120, 85, 10, 0.55)` |
| `--alert-border` | `rgba(200, 140, 0, 0.30)` | `rgba(255, 200, 60, 0.25)` |
| `--alert-fg` | `#78350f` | `#fef3c7` |
| `backdrop-filter` | `blur(12px)` | same |

#### Operator Accent Palette (6 curated, AA-verified in both themes)

| Name | Light | Dark | Light FG | Dark FG |
|---|---|---|---|---|
| blue | `oklch(0.48 0.22 260)` | `oklch(0.70 0.15 260)` | white | near-black |
| teal | `oklch(0.46 0.10 185)` | `oklch(0.72 0.09 185)` | white | near-black |
| indigo | `oklch(0.42 0.22 280)` | `oklch(0.68 0.15 280)` | white | near-black |
| purple | `oklch(0.45 0.20 305)` | `oklch(0.70 0.14 305)` | white | near-black |
| green | `oklch(0.46 0.14 150)` | `oklch(0.72 0.12 150)` | white | near-black |
| amber | `oklch(0.50 0.14 75)` | `oklch(0.78 0.12 75)` | white | near-black |

No free-form picker. Operator selects from these 6 only.

#### Domain-Specific Colors

| Token | Light | Dark | Usage |
|---|---|---|---|
| `--temp-hi` | `#c81e1e` | `#f87171` | High temperature values |
| `--temp-lo` | `#1d4ed8` | `#93c5fd` | Low temperature values |
| `--gauge-fill` | `#3b82f6` | — | Gauge filled arc |
| `--gauge-unfill` | `rgba(0,0,0,0.22)` | — | Gauge unfilled arc |
| `--gauge-indicator` | `#1e40af` | — | Gauge needle/indicator |

#### Semantic Color Assignments (locked across themes)

- Red = alerts/errors/destructive
- Amber = warnings
- Green = success
- Blue = info/primary
- AQI palette: EPA standard (green/yellow/orange/red/purple/maroon) — domain convention, not brandable

#### Contrast Requirements

- Normal text: ≥4.5:1 against background
- Large text (≥18pt regular or ≥14pt bold): ≥3:1
- Non-text UI components, focus indicators, meaningful icons: ≥3:1
- Both light AND dark themes independently verified (tool-checked, not eyeballed)
- Color is never the only signal — pair with icon, label, or position

#### Chart Palette

- `--chart-1` through `--chart-5` (currently neutral grayscale; multi-hue deferred)
- Must remain distinguishable under color-vision deficiency simulation

---

### Section 4: Typography

**Content:**

#### Font Families

| Token | Stack | Role |
|---|---|---|
| `--font-sans` | Manrope, Inter Variable, system-ui, sans-serif | Body, labels, headings, card titles, station name |
| `--font-display` | Outfit (self-hosted @fontsource woff2) | Large stat numerals only (temperature, wind speed, pressure values) |
| `--font-chart` | Lexend (self-hosted @fontsource woff2) | Chart axis, tick, and data labels only |
| `--font-heading` | alias to `--font-sans` | Heading elements |

All three typefaces self-hosted via @fontsource woff2. No CDN loading.

#### Type Scale (role-named, rem)

| Token | Value | Role | Font | Weight |
|---|---|---|---|---|
| `--text-stat-hero` | 4.25rem | Current temperature numeral | Outfit | 700 |
| `--text-stat-unit` | 1.9rem | Unit beside hero stat (°F/°C) | Outfit | 400 |
| `--text-hero-name` | 1.35rem | Station name in hero card | Manrope | 700 |
| `--text-stat-tile` | 1.25rem | Primary stat value on 1×1 tiles | Outfit | 600 |
| `--text-card-title` | 1.1rem | Card title (semibold, NOT bold) | Manrope | 600 |
| `--text-stat-label` | 1rem | Secondary stat value / large label | Outfit or Manrope | 400–600 |
| `--text-section` | 0.95rem | Section headings within cards | Manrope | 500–600 |
| `--text-body` | 0.9rem | Body text, sentences, descriptions | Manrope | 400 |
| `--text-chart-label` | 0.875rem | Chart axis, tick, data labels | Lexend | 400–600 |
| `--text-secondary` | 0.85rem | Feels-like, hi/lo, supporting text | Manrope | 400–600 |
| `--text-label` | 0.75rem | Small labels, control text, header control font | Manrope | 400–500 |
| `--text-micro` | 0.7rem | Uppercase micro-labels, minimum text size | Manrope | 400–600 |

⚠ PENDING FIX-005: `--text-card-title` currently 0.82rem in code; must be updated to 1.1rem.

#### Typography Rules

- Use `var(--text-*)` tokens for all `fontSize` values. Zero hardcoded px, rem, or em.
- Minimum text size: `--text-micro` (0.7rem / ~11px). Nothing smaller.
- Allowed weights: 400, 600, 700 only. No weight 500.
- Tabular figures: `font-feature-settings: "tnum"` on every live-updating numeric element (temp, humidity, rain, wind, pressure, etc.)
- Card titles: Manrope 600 (semibold). NOT 700 (bold).
- CJK fallback: ja/zh-CN/zh-TW use system CJK fonts. No Noto-CJK bundle shipped.
- SVG `<text>` inside a `viewBox` coordinate system (sun arc, compass cardinals): viewBox-unit font sizes, not CSS rem. Tokens do not apply. Recharts `tick={{ fontSize }}` props use pixel values mapped to `--text-chart-label` equivalent (14px ≈ 0.875rem).

#### Text Color Usage

- Primary body text: `text-foreground`
- Secondary/subdued text, labels: `text-muted-foreground`
- No opacity modifiers on text colors (no `text-muted-foreground/80`). Use the token as-is.
- Text on primary backgrounds: `text-primary-foreground`

---

### Section 5: Spacing & Layout

**Content:**

#### Layout Tokens

| Token | Desktop (md ≥768px) | Mobile (<768px) | Meaning |
|---|---|---|---|
| `--gap-grid` | 1rem | 1rem | Column gutter between cards. Row gap is 0. |
| `--container-max` | 80rem | 80rem | Dashboard content width cap |
| `--card-quarter-row` | 3.25rem | 3.75rem | Base grid row track |
| `--card-half-row` | 6.5rem | 7.5rem | Page headers (2 quarter tracks) |
| `--card-row` | 13rem | 15rem | Standard data card (4 quarter tracks) |
| `--card-content-max` | 9rem | 11rem | Graphic container max-height |
| `--card-pad` | 1rem | 1rem | Uniform card padding (all 4 sides) |
| `--card-header-h` | 2.5rem | 2.5rem | Header slot height |
| `--card-content-h` | 8.5rem | 10rem | Content slot height (derived: row - header - 2×pad) |

⚠ PENDING FIX-005: Row height tokens in code still have old values. FIX-006: `--card-pad`, `--card-header-h`, `--card-content-h` don't exist in code yet.

Token arithmetic must hold: quarter × 2 = half, quarter × 4 = row, quarter × 8 = tall. Desktop: 3.25 × 2 = 6.5 ✓, 3.25 × 4 = 13 ✓, 3.25 × 8 = 26 ✓. Mobile: 3.75 × 2 = 7.5 ✓, 3.75 × 4 = 15 ✓, 3.75 × 8 = 30 ✓.

#### Grid System

- **Columns:** 1 (mobile <768px) → 2 (md ≥768px) → 4 (lg ≥1024px)
- **Column gap:** `--gap-grid` (1rem)
- **Row gap:** 0. Vertical spacing from card `margin-bottom: var(--gap-grid)`.
- **Container:** `max-w-[var(--container-max)]` (80rem). Every page renders within this. No page varies the width.

#### Card Footprint Vocabulary

| Footprint | Columns | Tailwind |
|---|---|---|
| `tile` | 1 | `col-span-1` |
| `wide` | 2 | `col-span-1 md:col-span-2` |
| `panel` | 3 | `col-span-1 md:col-span-2 lg:col-span-3` |
| `full` | 4 | `col-span-1 md:col-span-2 lg:col-span-4` |

#### Row Span Model

| Role | rowSpan | Track count (md+) | Desktop height | Mobile min-h |
|---|---|---|---|---|
| Control strip | `"quarter"` | 1 | 3.25rem | 3.75rem |
| Page header | `"half"` | 2 | 6.5rem | 7.5rem |
| Data card (default) | `1` | 4 | 13rem | 15rem |
| Tall card | `2` | 8 | 26rem | 30rem |
| Extra-tall card | `2.5` | 10 | 32.5rem | 37.5rem |

#### Minimum Card Footprints (no clipping allowed)

| Card | Min Footprint |
|---|---|
| Current Conditions | wide × 2 (2×2) |
| Wind Compass | wide × 2 (2×2) |
| Radar | wide × 2 (2×2) |
| Webcam | wide × 2 (2×2) |
| Active Alert | full × 1 (4×1) |
| Today's Highlights | full × 1 (4×1) |
| Stat tiles | tile × 1 (1×1) |

#### Two Grid Modes

| Property | Rigid (Now page) | Fluid (other pages) |
|---|---|---|
| Grid `auto-rows` | `var(--card-quarter-row)` | `auto` |
| Card heights | Fixed from grid tracks | Content-adaptive, min-h prevents collapse |
| Content overflow | Hidden — must fit | Visible — content expands the card |
| Use case | Charts, gauges, compass, radar | Legal text, forecast tables, record lists |

---

### Section 6: Card Anatomy

**Content:**

#### Card Structure (ASCII diagram)

```
┌─────────────────────────────────────────────┐
│  padding (--card-pad: 1rem)                 │
│  ┌───────────────────────────────────────┐  │
│  │ HEADER SLOT (--card-header-h: 2.5rem) │  │
│  │ ┌─────────────┐  ┌─────────────────┐ │  │
│  │ │ CardTitle   │  │ Controls (opt.) │ │  │
│  │ └─────────────┘  └─────────────────┘ │  │
│  │ ─────────── underline (full width) ── │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │ CONTENT SLOT                          │  │
│  │ height: --card-content-h              │  │
│  │   rigid mode: 8.5rem (fixed, clips)   │  │
│  │   fluid mode: 8.5rem min, grows       │  │
│  │ width: card interior - 2 × --card-pad │  │
│  │                                       │  │
│  │   [chart / gauge / text / list]       │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│  padding (--card-pad: 1rem)                 │
└─────────────────────────────────────────────┘
```

#### Content Box Dimensions (derived)

| Card role | Card height | Header | Padding (×2) | Content box |
|---|---|---|---|---|
| Half-row (page header) | 6.5rem | 2.5rem | 2rem | 2rem |
| Data card (1-row) | 13rem | 2.5rem | 2rem | 8.5rem |
| Tall card (2-row) | 26rem | 2.5rem | 2rem | 21.5rem |
| Extra-tall (2.5-row) | 32.5rem | 2.5rem | 2rem | 28rem |

#### Card Surface Treatment

- Class: `.card-glass` (shared utility, all cards)
- Background: `rgb(var(--card-glass))`
- Backdrop: `blur(8px) saturate(1.1)` (with `-webkit-` prefix)
- Ring: `ring-1 ring-foreground/10`
- Radius: `rounded-xl` (0.875rem)
- Bottom margin: `mb-[var(--gap-grid)]` (1rem, provides vertical spacing between cards)

#### Card Header Contract

- Height: fixed `--card-header-h` (2.5rem)
- Layout: flex row, `align-items: center`, `justify-content: space-between`
- Padding: `0 var(--card-pad)` (horizontal only — vertical from card padding)
- Title slot (left): semantic heading (`<h2>` default, configurable level), font `--text-card-title` (1.1rem), Manrope 600, `flex: 1`
- Controls slot (right, optional): `flex-shrink-0`, vertically centered
- Underline: `border-bottom` on `CardHeader`, spans full card interior width (padding edge to padding edge), always

#### Approved Header Control Components

| Component | Use Case | Font | Colors | Touch Target |
|---|---|---|---|---|
| `HeaderTabs` | Switch views (Today/7-Day, Live/Timelapse) | `--text-label` (0.75rem) | inactive: `muted-foreground` bg + `muted-foreground` text; active: accent bg + `primary-foreground` text | ≥44px mobile |
| `HeaderToggle` | Binary on/off | `--text-label` | same | ≥44px mobile |
| `HeaderSelect` | Choose from list | `--text-label` | same | ≥44px mobile |
| `HeaderButton` | Trigger action (download, refresh) | `--text-label` | same | ≥44px mobile |

All share: border-radius consistent with card scale, visible focus ring per a11y rules. ⚠ PENDING FIX-012/013: These components don't exist yet.

#### Card Rules

- Every element on every page is a card. No free-floating content.
- Card uses `--card-pad` for all four sides. No hardcoded `py-2.5` / `px-4`.
- No ad-hoc className overrides for sizing (`!py-1`, `min-h-[...]`, `maxHeight`).
- Every card declares `footprint` and (on Now page) `rowSpan`.
- Cards self-hide when backing data has no non-null aggregate.
- Page self-hides when all its cards hide (except Now — always present).

---

### Section 7: Iconography

**Content:**

#### Hero Weather Icons (Material Symbols, filled)

Rendered as inline SVG with `<linearGradient>` fills, Meteocons-style palette.

| Element | Gradient Top → Bottom |
|---|---|
| Sun | `#FFD24D` → `#F5A623` (gold) |
| Clouds | `#F3F5F8` → `#C7CDD6` (light grey, lighter at top for depth) |
| Lightning | same as sun (gold) |
| Moon | `#86C3DB` → `#72B9D5` (periwinkle) |
| Rain | soft blue (tunable) |
| Snow | pale icy white (tunable) |

Coverage: all 29 WMO condition codes. Static (no animation). partly-cloudy fix: sun uses absolute `M14.975 17.2`, `fill-rule="nonzero"` on both paths. License: Apache-2.0.

#### Utility/Stat/Nav Icons (Phosphor base, regular weight)

| Category | Icons |
|---|---|
| Trend arrows | `ph:arrow-up`, `ph:arrow-down`, `ph:arrow-right` (reusable for any metric) |
| Temperature | `ph:thermometer` |
| Humidity | `ph:drop-simple` |
| Precip chance | `ph:umbrella` |
| Visibility | `ph:eye` |
| Solar radiation | `ph:sun` |
| Rainfall | `ph:cloud-rain` |
| Snowfall | `ph:snowflake` |
| Pressure | `ph:gauge` |
| UV Index | `tabler:uv-index` (cross-pack, Tabler MIT) |
| AQI content icon | `ph:leaf` |
| Precipitation content | `ph:drop` |
| Lightning content | `ph:lightning` |

#### Alert Icons (13 types)

| Alert Type | Icon |
|---|---|
| Fire | `ph:fire` |
| Tropical | `ph:hurricane` |
| Thunderstorm | `ph:lightning` |
| Tornado | `ph:tornado` |
| Generic warning | `ph:warning` |
| Watch | `ph:warning-circle` |
| Wind | `ph:wind` |
| Marine | `ph:sailboat` |
| Snow/winter | `ph:snowflake` |
| Heat/cold | `ph:thermometer` |
| Fog | `ph:cloud-fog` |
| Flood | `material-symbols:flood-outline-rounded` (cross-pack) |
| Tsunami | `carbon:tsunami` (cross-pack) |

#### Icon Sizing (proposed scale — ⚠ not yet tokenized)

| Size | Value | Use |
|---|---|---|
| xs | 12px | Trend arrows (barometer, AQI) |
| sm | 16px | Inline label icons |
| md | 20-24px | Stat content icons, forecast condition |
| lg | 36px | Standalone content-area icons (UV, precip) |
| xl | 96-115px | Hero weather icon (current conditions) |

#### Icon Rules

- Decorative icons: `aria-hidden="true"`, `focusable="false"`
- Informational SVGs: `<svg role="img"><title>Description</title>…</svg>` or `aria-labelledby`
- Icon-only buttons: must have `aria-label`
- No icon per number — some metrics are text-only (feels-like, dewpoint)
- Wind exception: `ph:wind` on Wind Compass card title + readout block; individual wind stats text-only
- C4 stat tiles: NO title icons (text-only headers); visual identity from content-area elements

---

### Section 8: Backgrounds & Surfaces

**Content:**

#### Sky Background System

| Condition | Day Asset | Night Asset |
|---|---|---|
| Clear / Mostly Clear / Partly Cloudy | `clear` | `clear_night` |
| Mostly Cloudy / Overcast | `cloudy_day` | `cloudy_night` |
| Thunderstorm | `storm_day` | `storm_night` |
| Foggy | maps to cloudy | maps to cloudy (no dedicated fog photo) |
| Unknown / startup | maps to clear | maps to clear |

- Day/night: follows sun position (almanac sunrise/sunset) in auto themes; follows theme toggle in manual light/dark
- Precipitation overlay: rain (`blend-mode: overlay`, 75% day / 25% night opacity) OR snow (`blend-mode: screen`, 75% day / 25% night opacity)
- Precipitation linger: 15 minutes after last detection
- On-glass overlays: `rain_on_glass.jpg` + `snow_on_glass_transparent.png` (no animation)
- Base layer blur: 3px when precipitation active
- Asset specs: ≤300 KB each, ~2560px longest edge, WebP
- Attribution: optional string, unobtrusive corner placement. Shipped scenes credit photographers; default/uncredited show nothing.

#### Surface Treatment Inventory

| Surface | Background | Backdrop Filter | Border | Use |
|---|---|---|---|---|
| Card glass | `rgb(var(--card-glass))` | `blur(8px) saturate(1.1)` | `ring-1 ring-foreground/10` | All cards |
| Alert glass | `var(--alert-glass)` | `blur(12px)` | `var(--alert-border)` | Alert banners |
| Modal overlay | `rgba(0,0,0,0.60)` | `blur(4px)` | none | Behind modal dialogs |
| Modal content | `.card-glass` | `blur(16px)` | `ring-1 ring-foreground/10` | Modal card itself |
| Radar controls | `bg-background/80` | `backdrop-blur-sm` | none | Map overlay controls |
| CardFooter | `bg-muted/50` | none | `border-t` | Card footer region |

---

### Section 9: Navigation

**Content:**

#### Desktop Navigation Rail

- Position: fixed left, floating overlay, card-glass surface, shadow-lg, rounded-xl, z-20
- Auto-hide: after 30s idle or mouseleave
- Show: on mouseenter or grab-bar click
- Pin toggle: persists to `localStorage`, prevents auto-hide
- Grab bar: visible when rail is hidden, clickable to show
- Transition: 200ms ease (opacity + transform)
- Content: station logo/name at top, page icons vertically, theme toggle at bottom
- Icon labels: visible on hover/focus; always-labeled also acceptable
- Active page indicator: background shift + accent line, ≥3:1 contrast
- ARIA: `aria-label`, `aria-expanded` managed on show/hide

#### Mobile Bottom Navigation

- Position: fixed bottom, full-width
- Max slots: 5 (5th = "More" overflow)
- "More" sheet: slides up, shows remaining pages
- Icon labels: always visible (compact)
- Active: same indicator as desktop

#### Skip Link

- First focusable element in document
- `class="sr-only"` until focused, then visible
- Target: `#main-content`

---

### Section 10: Page Structure

**Content:**

#### Universal Page Composition

Every page (except Now) uses `PageLayout`:
1. `<h1 class="sr-only">` — page title for screen readers
2. `Grid` with `md:!auto-rows-[auto]` (fluid mode)
3. `PageHeaderCard` — full-width, half-row, icon + title
4. `ControlsStrip` (optional) — full-width, quarter-row, for "many controls"
5. Content cards

#### Page-Header Card

- Footprint: `full`, rowSpan: `"half"`
- Icon: left-aligned, sized proportionally to half-row height
- Title: `<h1>` equivalent (visible heading), font `--text-hero-name` or larger
- Controls slot: right-aligned (for "few controls" pattern)
- ⚠ PENDING FIX-001/004: Current icon (2rem) and title (`text-xl`) undersized. Must scale to fill 6.5rem card.

#### Controls Strip

- Full-width quarter-row card directly below page header
- Uses approved control components only (`HeaderTabs`, `HeaderSelect`, etc.)
- No raw `<button>` or `<select>` inside strip
- ARIA: `<section aria-label="[Page] controls">`

#### Page Inventory

| Page | Route | Icon | Key Cards |
|---|---|---|---|
| Now | `/` | house | Hero, CC, forecast, wind, precip, highlights, AQI, sun/moon, lightning, earthquake, radar, webcam, chart panel |
| Forecast | `/forecast` | cloud-sun | Hourly strip, 7-day daily, discussion |
| Charts | `/charts` | chart-line | Tabbed chart groups, time-range nav |
| Almanac | `/almanac` | moon | Sun/moon detail, planet visibility, eclipses, meteor showers, monthly averages |
| Seismic | `/seismic` | activity | Map + scrollable list, GEM faults toggle |
| Records | `/records` | trophy | Per-section record tables, YTD/All-Time toggle |
| Reports | `/reports` | file-text | Year/month NOAA report table, download links |
| About | `/about` | info | Station metadata, photo, about text, software, providers, credits, attribution |
| Legal | `/legal` | scales | Terms of Use, Privacy Policy, Accessibility Statement, Open Source Licenses |

#### Self-Hide Behavior

- **Card level:** card self-hides when backing data has no non-null aggregate over visible period
- **Page level:** page self-hides from nav when all its cards hide
- **Now page:** never hides (home always present)

---

### Section 11: Component Patterns

**Content — fixed template for each component:**

#### Card (base primitive)

- **Description:** The sole layout primitive. Every visible element is a card.
- **Anatomy:** glass surface → padding (`--card-pad`) → header slot → content slot
- **Props:** `footprint` (tile/wide/panel/full), `rowSpan` (quarter/half/1/2/2.5), `size` (default/sm), `className`
- **States:** default, loading (skeleton), empty (self-hide), error (graceful degrade)
- **Accessibility:** Card is a `<div>` (no implicit landmark role). Content within provides semantics.
- **Do:** Use `footprint` and `rowSpan` props. Let the card own its padding.
- **Don't:** Add `!py-*`, `!px-*`, `min-h-[...]`, or `maxHeight` overrides in className.

#### CardHeader + CardTitle

- **Description:** Structured header slot with title and optional controls.
- **Anatomy:** flex container (`--card-header-h` height) → title heading (left, flex-1) → controls (right, flex-shrink-0) → full-width underline
- **Title props:** `title` (string), `as` (h1–h6, default h2), `icon` (optional)
- **Controls:** pass approved control components as `children`
- **Accessibility:** Title renders as real heading element. Controls must be keyboard-reachable.
- **Do:** Use `CardTitle` for the heading. Pass controls as children of `CardHeader`.
- **Don't:** Write custom `<h2>` with hand-copied classes. Style controls inline.

#### Alert Banner

- **Description:** Active weather alert card with severity-colored left stripe.
- **Anatomy:** glass surface (alert-specific) → icon (severity) → headline + description + metadata → expand/collapse chevron
- **States:** collapsed (headline only), expanded (full description + metadata)
- **Accessibility:** `aria-live="polite"` for new alerts, `aria-expanded` on toggle, severity announced
- **Do:** Use the alert severity model (4-tier `severityLevel` + `severityLabel`).
- **Don't:** Use color alone to indicate severity — pair with icon and text label.

#### Skeleton Loading

- **Description:** Placeholder shown while data loads.
- **Pattern:** `<div className="animate-pulse rounded-lg bg-muted" style={{ height: '...' }} aria-hidden="true" />`
- **Rule:** Skeleton height should approximate the loaded content height. Use `aria-hidden="true"` on skeleton, `role="status"` with sr-only text for loading announcement.

#### CollapsibleCard (Legal page pattern)

- **Description:** Card with header that toggles content visibility.
- **Anatomy:** `CardHeader` with `role="button"`, `aria-expanded`, `tabIndex={0}` → content div with `maxHeight` transition
- **Collapsed state:** shows preview with bottom fade gradient (`black 80%, transparent 100%`)
- **Accessibility:** Enter/Space toggle, `aria-expanded` state managed
- ⚠ PENDING FIX-002: Current fade gradient too aggressive (`black 40%`). Must be `black 80%`.

#### SemiCircularGauge

- **Description:** Half-circle arc gauge (barometer, AQI).
- **Anatomy:** SVG arc (filled/unfilled segments) → center overlay (value + unit + trend)
- **Sizing:** fills content slot via `flex: 1, minHeight: 0, maxHeight: var(--card-content-max)`
- **Colors:** `--gauge-fill`, `--gauge-unfill`, `--gauge-indicator`

---

### Section 12: Data Formatting

**Content:**

#### Unit Display

- Use operator-preferred units from station config (US/Metric/MetricWX)
- Temperature: always show unit suffix (°F or °C)
- Wind: value + unit (e.g. "12 mph", "5.4 m/s")
- Pressure: value + unit (e.g. "30.02 inHg", "1015.3 mbar")
- Rain: value + unit (e.g. "0.45 in", "11.4 mm")
- All values: `font-feature-settings: "tnum"` for tabular figures

#### Number Precision

- Temperature: 1 decimal place (72.4°F)
- Pressure: 2 decimal places (30.02 inHg)
- Wind speed: 1 decimal place (4.9 mph)
- Rain: 2 decimal places (0.00 in)
- Humidity: integer (84%)
- UV Index: integer (7)

#### Date/Time Formatting

- Use `Intl.DateTimeFormat` with operator timezone and visitor locale
- Relative time: `Intl.RelativeTimeFormat` (e.g. "1 minute ago")
- No hardcoded date format strings

#### No-Data States

- Graceful empty, not error. Show "—" for missing values, not "N/A" or "Error".
- Card-level: card self-hides when all data is null
- Never show stale data without a staleness indicator

---

### Section 13: Responsive Behavior

**Content:**

#### Breakpoints

| Name | Width | Grid Columns | Nav Pattern | Card Heights |
|---|---|---|---|---|
| Mobile | <768px | 1 | Bottom bar (fixed) | Content-adaptive (auto) |
| Desktop (md) | ≥768px | 2 | Left rail (auto-hide) | Rigid tracks on Now; auto elsewhere |
| Wide (lg) | ≥1024px | 4 | Left rail (auto-hide) | Same as md |

#### Responsive Rules

- Mobile-first: design for phone, extend for desktop
- Grid reflow: cards stack in reading order on mobile
- Tap targets: ≥44×44px on all interactive elements
- No hover-only affordances
- Touch-friendly: adequate spacing between interactive elements
- `full`/`panel` cards span full width of current column count
- `wide` (2×2) cards stay 2-wide at md; stack at mobile
- `tile` cards: 1 column at all breakpoints

---

### Section 14: Motion & Transitions

**Content:**

- Live data updates: ~200ms tween (temperature, wind compass, lightning state)
- Nav rail show/hide: 200ms ease (opacity + transform)
- Page transitions: none (instant route swaps)
- Card expand/collapse: 300ms ease-in-out (max-height transition)
- No parallax, no scroll-driven animations
- `prefers-reduced-motion: reduce`: all tweens disabled, instant updates
- Alert banner expand: smooth height transition
- Skeleton → content: instant swap (no fade)

---

### Section 15: Theming & Operator Customization

**Content:**

#### Theme System

- Mechanism: `data-theme` attribute on `<html>` (values: `light` | `dark`)
- No-flash: inline `<script>` in `index.html` runs synchronously before CSS, sets `data-theme` from localStorage
- Toggle cycle: system → light → dark → system
- Storage: `localStorage('clearskies.theme.user-override')` as `light` / `dark` / `system`
- Tailwind v4: `@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *))` in index.css
- No theme-transition animation (instant swap respects motion budget)

#### Four Theme Modes

| Mode | Behavior |
|---|---|
| Light | Always light |
| Dark | Always dark |
| Auto (OS) | Follows `prefers-color-scheme` media query |
| Auto (sunrise/sunset) | Fetches almanac times, switches at sunrise/sunset. Midnight re-fetch. Polar clamp (>24h event → midnight). Falls back to OS preference if null rise/set. |

#### Operator Branding

| Field | Source | Dashboard Behavior |
|---|---|---|
| Accent color | `branding.json` → 6 curated options | Sets `--brand-primary-*` CSS variables at runtime |
| Logo (light) | Upload via wizard | Rendered in hero card, nav rail |
| Logo (dark) | Optional upload | Used in dark theme; if absent, light logo CSS-inverted with warning |
| Logo alt | Wizard input | Required for a11y. Fallback: `"<siteTitle> logo"` |
| Site title | `branding.json` | Set as `document.title` |
| Favicon | `branding.json` | Applied to `<link rel="icon">` |
| Custom CSS | URL in `branding.json` | Linked last (operator owns override; CSS variable names NOT promised stable) |
| GA ID | `branding.json` | Shows cookie consent banner when set; GA blocked until opt-in |
| Privacy regions | `branding.json` | Controls jurisdiction filtering on Legal page |
| Default theme mode | `branding.json` | Applied on first load if no user override |

#### What Is NOT Customizable

- Structural layout (grid columns, card anatomy, content box dimensions)
- Component anatomy (header slot structure, control components)
- Type scale (token values, font families)
- Accessibility requirements (contrast, focus indicators, semantic HTML)
- Card radius (always `rounded-xl`)

---

### Section 16: Accessibility

**Content:**

#### WCAG 2.1 Level AA — release-blocking floor

- Accessibility issues = same severity as security vulnerability or broken build
- "Fix after launch" is wrong posture — audit per change, not per release

#### Contrast

- Normal text: ≥4.5:1
- Large text (≥18pt regular or ≥14pt bold): ≥3:1
- Non-text components, focus indicators, meaningful icons: ≥3:1
- Both themes independently verified with tooling (not eyeballed)
- Color never the only signal — pair with icon, label, or position

#### Semantic HTML

- `<button>` for buttons, `<a>` for links, `<nav>` for nav, `<main>` for content
- Heading hierarchy h1–h6 in document order, no skipped levels
- No `<div onClick>` when `<button>` fits
- Forms: every input has `<label>` (visible or sr-only). `placeholder` is not a label.
- Error inputs: `aria-describedby` + `aria-invalid="true"`
- Lists are `<ul>`/`<ol>`/`<li>`, not stacked `<div>`s
- Tables: `<table>` with `<thead>`/`<tbody>`/`<th scope="col"|"row">`

#### Keyboard

- Every interactive element reachable by Tab
- Tab order = visual order (no `tabindex > 0`)
- Visible focus indicator on every focusable element (no `outline: none` without replacement)
- Escape closes modals/menus/dropdowns
- Enter/Space activate buttons
- Arrow keys within widgets per WAI-ARIA APG
- Skip-to-main-content link at top of every page
- Focus traps in modals: Tab/Shift-Tab cycles within; close returns focus to opener

#### ARIA

- First rule: don't use ARIA — use the right HTML element
- Icon-only buttons: `aria-label`
- Decorative icons: `aria-hidden="true"`
- Dynamic regions: `aria-live="polite"` (updates) or `"assertive"` (emergencies)
- Don't lie: `role="button"` on `<div>` requires manual keyboard + focus wiring — use `<button>`

#### Images & Icons

- Every `<img>` has `alt` (informational: descriptive; decorative: empty `alt=""`; functional: describe action)
- Operator-uploaded images: alt text required at upload — no skip path
- SVG icons: informational uses `<svg role="img"><title>…</title></svg>`; decorative uses `aria-hidden="true"` + `focusable="false"`
- Charts: `aria-label` on container + sr-only data table fallback alongside

#### Localization

- `<html lang="…">` set per active locale (13 locales: en, de, es, fil, fr, it, ja, nl, pt-PT, pt-BR, ru, zh-CN, zh-TW)
- Use `margin-inline-start` not `margin-left` (RTL-ready, even though v0.1 has no RTL languages)

#### Per-Change Checklist

Run before declaring any UI change done:
- [ ] Every `<img>` has `alt`
- [ ] Every icon-only button has `aria-label`
- [ ] Every `<input>` has `<label>`
- [ ] Every color combo checked in both themes
- [ ] Every interactive element keyboard-reachable with visible focus
- [ ] Heading levels in order, no skipped
- [ ] No `<div onClick>` where `<button>` belongs
- [ ] Dynamic content has `aria-live`
- [ ] Chart data-table fallback matches
- [ ] `npx @axe-core/cli` zero violations or documented reason

---

### Section 17: Wizard Design Standards

**Content:**

The wizard (`weewx-clearskies-stack`) uses Pico CSS + HTMX + Jinja2. It intentionally diverges from the dashboard's Tailwind/React stack, but shares design language in these areas: typography rhythm, form field patterns, accessibility scaffold, color accent.

#### Step Structure (all 15 steps)

```
<article>
  <header>
    <h2>Step N of 15 — Title</h2>
    <p>Description</p>
  </header>
  {% if error %}
  <div role="alert" class="alert-error">...</div>
  {% endif %}
  <form hx-post="/wizard/step/N" hx-target="#wizard-content" hx-swap="innerHTML show:window:top">
    <fieldset>
      <legend>Section Name</legend>
      <!-- inputs -->
    </fieldset>
    <div role="group">
      <button type="button" hx-get="/wizard/step/N-1">← Previous</button>
      <button type="submit">Next →</button>
    </div>
  </form>
</article>
```

#### Form Field Pattern

```html
<label for="field_id">Label</label>
<input type="text" id="field_id" name="field_name" value="..." aria-describedby="field_hint">
<small id="field_hint">Helpful description</small>
```

- Every input has explicit `<label>` + `aria-describedby` hint
- Required fields: `<span aria-hidden="true">*</span>`
- Error display: `.input-error` border + `.error-text` below input + `.alert-error` div at step top with `role="alert"`

#### Progress Bar

- `<ol class="wizard-progress" role="list">` with 15 items
- CSS counters for step numbers in circular badges (1.75rem diameter)
- Three states: muted (incomplete), primary with outline (current), checkmark (complete)
- Completed steps are clickable links (HTMX GET for back-navigation)
- Responsive: labels hidden <36rem, numbers remain
- Updated via HTMX OOB swap (`hx-swap-oob="true"`) on every step response

#### Password Toggle

- SVG eye icon positioned inside input (absolute, right side)
- `togglePassword(btn)` swaps `type` between `password` and `text`
- `aria-label="Show/Hide [field name]"`, `aria-controls` links to input
- Borderless button, muted color → primary on hover/focus

#### Typography

- Root: `--pico-font-size: 87.5%`, `--pico-line-height: 1.4`
- Monospace (EULA, secrets): Cascadia Code, Source Code Pro, Menlo, Consolas
- Compact spacing: `--pico-form-element-spacing-vertical: 0.5rem`

#### HTMX Patterns

- Fragment architecture: steps are templates, not full pages. Swap into `#wizard-content`.
- OOB updates: progress bar updated via `hx-swap-oob="true"` without re-rendering the step
- 422 handling: validation errors return 422, HTMX configured to accept as valid swap
- Focus management: after HTMX settle, JS finds `h2`/`h3` in `#wizard-content`, sets `tabindex="-1"`, calls `.focus()`
- Scroll: `show:window:top` on every swap

---

### Section 18: Anti-Patterns

**Content — flat list, grouped by category:**

#### Layout

- Never add free-floating content outside a card
- Never render a card narrower than one column
- Never vary `--container-max` per page
- Never use rigid grid tracks on non-Now pages (use `auto-rows-[auto]`)
- Never add generic educational prose to data pages (relocate to manual)

#### Typography

- Never hardcode font sizes — use `--text-*` tokens only
- Never use text smaller than `--text-micro` (0.7rem)
- Never use font-weight 500
- Never use `text-muted-foreground/80` or any opacity modifier on text tokens
- Never use Tailwind `text-xs`/`text-sm` for content — use named tokens

#### Color

- Never rely on color alone to convey state — pair with icon/label/position
- Never use a free-form color picker for operator accent (curated palette only)
- Never darken/lighten to near-fail contrast — pick a different shade
- Never use hardcoded hex colors in component code for theme-dependent colors

#### Components

- Never write custom `<h2>` with hand-copied header classes — use `CardTitle`
- Never style controls inline per-card — use `HeaderTabs`/`HeaderToggle`/`HeaderSelect`/`HeaderButton`
- Never add `!py-*`, `!px-*`, `!important` padding overrides on cards
- Never set `min-h-[...]` or `maxHeight` manually on cards — use tokens
- Never place controls outside `CardHeader` or `ControlsStrip`
- Never pass raw `<button>` or `<select>` into `ControlsStrip`

#### Charts (Recharts)

- Never use negative margins (clips data/labels)
- Never set `margin.bottom` for label space (XAxis `height` handles it)
- Never set `width={0}` on visible YAxis (zero-guard makes it invisible)
- Never use `hide` on YAxis (Recharts bug #428 — XAxis labels vanish)
- Read `docs/reference/recharts-axis-reference.md` before any chart change

#### Accessibility

- Never use `<div onClick>` when `<button>` fits
- Never use `outline: none` without a visible replacement
- Never skip heading levels
- Never accept an image upload without alt text
- Never use `placeholder` as a label
- Never omit `aria-label` on icon-only buttons

#### Motion

- Never add parallax or scroll-driven animations
- Never add theme-transition animations (instant swap)
- Never ignore `prefers-reduced-motion`

---

## 4. Implementation Phases

### PHASE 1 — Draft Sections 1-6 (Foundation)

**T1.1 — Assemble Sections 1-6**
- Owner: `clearskies-docs-author`
- Do: Write sections 1 through 6 of `docs/DESIGN-MANUAL.md` using the content specifications above (§3, Sections 1-6). The content is fully specified — the agent formats it into the final document structure. Verify every token value, every table row, and the ASCII anatomy diagram are present.
- Accept: Sections 1-6 complete. Every token from the content spec appears. ASCII diagram renders correctly in markdown preview.

**QC (Opus) — after Phase 1:** Diff the written sections against the content specs above. Every token value, table row, rule, and do/don't must match. Flag omissions or modifications.

### PHASE 2 — Draft Sections 7-12 (Components & Patterns)

**T2.1 — Assemble Sections 7-12**
- Owner: `clearskies-docs-author`
- Do: Write sections 7 through 12 using the content specifications above. For Section 11 (Component Patterns), use the fixed template format (description, anatomy, props/variants, states, accessibility, do/don't) for each component. Every icon mapping, surface treatment value, page inventory row, and formatting rule from the content spec must appear.
- Accept: Sections 7-12 complete. Every icon in the inventory listed. All four surface treatments documented with exact values. Component catalog covers all listed components.

**QC (Opus) — after Phase 2:** Diff against content specs. Verify icon inventory is complete by grepping dashboard for Phosphor/Material imports and confirming coverage. Verify surface treatment CSS values match index.css.

### PHASE 3 — Draft Sections 13-18 (Cross-Cutting Concerns)

**T3.1 — Assemble Sections 13-18**
- Owner: `clearskies-docs-author`
- Do: Write sections 13 through 18 using the content specifications above. Section 16 (Accessibility) must include the complete per-change checklist. Section 17 (Wizard) must include the step structure template, form field pattern HTML, and progress bar description. Section 18 (Anti-Patterns) must include every prohibition — verify count matches the content spec.
- Accept: Sections 13-18 complete. Anti-pattern count matches spec. Accessibility checklist complete. Wizard templates included.

**QC (Opus) — after Phase 3:** Count anti-patterns against the content spec list. Verify accessibility checklist matches coding.md §5.7. Verify wizard step template HTML is syntactically correct. Full document is now draft-complete.

### PHASE 4 — Audit of the Audit

**T4.1 — Independent completeness review**
- Owner: `clearskies-auditor`
- Do: Read the complete draft `DESIGN-MANUAL.md`. For each UI-related ADR (009, 022, 023, 024, 026, 047, 048, 049, 050, 051+amendments, 062), verify every rule is captured. For each component in the dashboard, verify its patterns are documented. For each wizard step, verify its patterns are covered. Report gaps as a list.
- Accept: Zero gaps found, or all gaps resolved before proceeding.

**T4.2 — Code-to-manual cross-reference**
- Owner: `clearskies-auditor`
- Do: Grep the dashboard codebase for every token, pattern, and convention referenced in the manual. Flag any that don't exist in code (future-looking rules that should be marked as such) and any code patterns not captured in the manual.
- Accept: Every manual rule maps to existing code or is explicitly marked as "pending implementation" (referencing the fixit item).

**T4.3 — Visual verification**
- Owner: `clearskies-auditor`
- Do: Walk the live site (all 9 pages) and the wizard (all 15 steps). For each, verify the manual's description matches what's rendered. Flag discrepancies (code says X, site shows Y, manual says Z).
- Accept: Manual accurately describes current visual state, with pending changes clearly marked.

**QC (Opus) — after Phase 4:** Review auditor findings. Integrate all gap fixes into the manual. Verify no rule was lost during integration.

### PHASE 5 — Finalize & Integrate

**T5.1 — Final manual polish**
- Owner: Coordinator (Opus)
- Do: Final read of complete document. Verify structure consistency (all sections use same heading levels, table formats, imperative voice). Verify cross-references (every ADR citation is correct, every token name is exact). Remove any prose that doesn't serve an operational purpose.
- Accept: Document is clean, consistent, and actionable.

**T5.2 — Archive UI-related ADRs**
- Owner: Coordinator (Opus)
- Do: Move the following ADRs from `docs/decisions/` to `docs/archive/decisions/`:
  ADR-009, ADR-022, ADR-023, ADR-026, ADR-047, ADR-048, ADR-049, ADR-050, ADR-051, ADR-062.
  ADR-024 (page taxonomy) has UI and non-UI content — extract non-UI portions to a separate reference, archive the rest.
  Set status on each to "Archived — consolidated into DESIGN-MANUAL.md" with archive date.
  Update `docs/decisions/INDEX.md` — move archived entries to an "Archived" section with a note that the design manual is now authoritative for UI rules.
- Accept: Archived ADRs in `docs/archive/decisions/`. Index updated. No broken cross-references in remaining active ADRs.

**T5.3 — Update CLAUDE.md domain routing**
- Owner: Coordinator (Opus)
- File: `CLAUDE.md` — domain routing table
- Do: Add row: "UI design, visual patterns, tokens, component styling → `docs/DESIGN-MANUAL.md`". Update `rules/coding.md` §9 to reference the manual as the single authority for design rules. Remove ADR references from §9 — the manual replaces them.
- Accept: Any UI-related task loads the design manual, not individual ADRs.

**T5.4 — Update process rules**
- Owner: Coordinator (Opus)
- File: `rules/clearskies-process.md`
- Do: Add the new ADR lifecycle for UI decisions (draft → accept → amend manual → archive). Clarify that non-UI ADRs follow the existing lifecycle unchanged.
- Accept: Process rules reflect the new lifecycle.

**T5.5 — Update fixit doc**
- Owner: Coordinator (Opus)
- File: `docs/planning/DASHBOARD-FIXIT.md`
- Do: Mark FIX-014 complete. Note that pending implementation items (FIX-001 through FIX-013) are referenced in the manual where relevant.
- Accept: FIX-014 closed.

---

## 5. Agent Assignments

| Phase | Task | Owner | QC Timing |
|-------|------|-------|-----------|
| 1 | T1.1-T1.6 Foundation sections | `clearskies-docs-author` | After Phase 1 |
| 2 | T2.1-T2.6 Components & patterns | `clearskies-docs-author` | After Phase 2 |
| 3 | T3.1-T3.6 Cross-cutting concerns | `clearskies-docs-author` | After Phase 3 |
| 4 | T4.1-T4.3 Audit of the audit | `clearskies-auditor` | After Phase 4 |
| 5 | T5.1-T5.5 Finalize, archive & integrate | Coordinator (Opus) | After Phase 5 |

**Sequencing:** Phases 1-3 are sequential (each builds on the prior). Phase 4 requires complete draft. Phase 5 requires clean audit.

---

## 6. QC Gates

### Gate 1 — Completeness (after each phase)
- Every ADR rule from the audit appears in the manual
- Every token in index.css is documented
- Every component pattern is covered

### Gate 2 — Accuracy (Phase 4)
- Manual matches current code state
- Manual matches current visual state
- Pending changes clearly marked with fixit references

### Gate 3 — Parseability (Phase 5)
- Flat heading hierarchy (2 levels max)
- Imperative voice throughout
- Token names inline and exact
- Tables for inventories
- Do/Don't pairs for ambiguous cases

---

## 7. Self-Audit

**Risk: Document becomes stale.** Mitigated by `CLAUDE.md` routing — the manual is loaded before any UI work, so staleness is caught when a rule doesn't match reality. Update discipline: any ADR amendment or code change that affects design rules must update the manual in the same commit.

**Risk: Document too long to be useful.** Target 1500-2000 lines. Token tables are dense but grep-able. Prose minimized. If a section exceeds usefulness, split into subsections with clear headers.

**Risk: Duplicating ADR content.** The manual states *what to do*, not *why it was decided*. Decision rationale stays in ADRs. The manual references ADRs by number for anyone who needs the why.

**Risk: Wizard and dashboard divergence.** Section 17 explicitly covers where they share design language and where they intentionally diverge (Pico CSS foundation vs Tailwind). Shared patterns (form validation UX, accessibility scaffold) are documented once and cross-referenced.
