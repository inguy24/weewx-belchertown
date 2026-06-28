# Clear Skies Design Manual

**Authority:** This document is the single authority for all Clear Skies UI design rules.  
**Consumers:** AI coding agents and human reviewers.  
**Conflict rule:** When this document conflicts with any other source, this document wins.

---

## 1. Purpose, Scope & Glossary

This document is the single authority for all Clear Skies UI design rules. It governs the dashboard SPA (`weewx-clearskies-dashboard`), the setup wizard (`weewx-clearskies-stack`), and any future UI surface. Consumers: AI coding agents and human reviewers. When this document conflicts with any other source (archived ADRs, code comments, conversation history), this document wins.

### Glossary

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

## 2. Design Principles

1. **Balanced density.** Weather dashboards exist to show data — every element should earn its space. But density without visual hierarchy is noise. Use whitespace, contrast, and grouping to make dense data scannable. The Now page fits 12+ data cards on one screen; don't add padding that pushes cards below the fold, but don't crush content together either.

2. **Tokens over hardcoded values.** Every size, color, spacing, and font value comes from a CSS custom property. Zero hardcoded `px`, `rem`, `em`, or hex values in component code. Example: use `fontSize: 'var(--text-body)'` not `fontSize: '0.9rem'`.

3. **Every screen size is the product.** The grid reflows from 1→2→4 columns; no feature is mobile-only or desktop-only. Design for phone and desktop simultaneously — neither is an afterthought. Tap targets ≥44×44px, no hover-only affordances, adequate space for both touch and pointer interaction.

4. **Accessible by default.** WCAG 2.1 AA is the floor, not a stretch goal. Accessibility issues are release-blocking — same severity as a security vulnerability. Example: every `<img>` has `alt`, every icon-only button has `aria-label`, every color pairing meets 4.5:1 contrast in both themes.

5. **Curated options, guaranteed quality.** Free-form customization creates combinations no one has tested — a custom color that fails WCAG, a custom header that breaks card structure. Operators choose from pre-verified options (6 accents, 4 theme modes); developers choose from pre-styled components (4 control types). Every combination ships tested. If an option can't be quality-guaranteed, it isn't offered.

---

## 3. Color System

### Semantic Foreground Tokens

| Token | Light (oklch) | Dark (oklch) | Role |
|---|---|---|---|
| `--foreground` | `0.145 0 0` (near-black) | `0.985 0 0` (near-white) | Primary body text |
| `--card-foreground` | `0.145 0 0` | `0.985 0 0` | Text inside cards |
| `--muted-foreground` | `0.556 0 0` (mid-grey) | `0.708 0 0` | Secondary/subdued text, labels |
| `--primary-foreground` | `0.985 0 0` (near-white) | `0.15 0 0` (near-black) | Text on primary-colored backgrounds |
| `--secondary-foreground` | `0.205 0 0` | — | Text on secondary surfaces |
| `--accent-foreground` | `0.205 0 0` | — | Text on accent surfaces |
| `--destructive` | `0.577 0.245 27.325` | — | Destructive actions |

### Semantic Background Tokens

| Token | Light | Dark | Role |
|---|---|---|---|
| `--background` | `oklch(1 0 0)` (white) | `oklch(0.145 0 0)` | Page background |
| `--card` | `oklch(1 0 0)` | `oklch(0.145 0 0)` | Card base (before glass) |
| `--muted` | `oklch(0.97 0 0)` | — | Muted surface |
| `--accent` | `oklch(0.97 0 0)` | — | Accent surface |

### Card Glass Surface

| Property | Light | Dark |
|---|---|---|
| `--card-glass` | `255 255 255 / 0.88` | `30 35 55 / 0.85` |
| `backdrop-filter` | `blur(8px) saturate(1.1)` | same |
| Ring | `ring-1 ring-foreground/10` | same |

### Alert Glass Surface

| Property | Light | Dark |
|---|---|---|
| `--alert-glass` | `rgba(255, 210, 100, 0.55)` | `rgba(120, 85, 10, 0.55)` |
| `--alert-border` | `rgba(200, 140, 0, 0.30)` | `rgba(255, 200, 60, 0.25)` |
| `--alert-fg` | `#78350f` | `#fef3c7` |
| `backdrop-filter` | `blur(12px)` | same |

### Operator Accent Palette

Six curated accents, AA-verified in both themes. No free-form picker. Operator selects from these 6 only.

| Name | Light | Dark | Light FG | Dark FG |
|---|---|---|---|---|
| blue | `oklch(0.48 0.22 260)` | `oklch(0.70 0.15 260)` | white | near-black |
| teal | `oklch(0.46 0.10 185)` | `oklch(0.72 0.09 185)` | white | near-black |
| indigo | `oklch(0.42 0.22 280)` | `oklch(0.68 0.15 280)` | white | near-black |
| purple | `oklch(0.45 0.20 305)` | `oklch(0.70 0.14 305)` | white | near-black |
| green | `oklch(0.46 0.14 150)` | `oklch(0.72 0.12 150)` | white | near-black |
| amber | `oklch(0.50 0.14 75)` | `oklch(0.78 0.12 75)` | white | near-black |

### Domain-Specific Colors

| Token | Light | Dark | Usage |
|---|---|---|---|
| `--temp-hi` | `#c81e1e` | `#f87171` | High temperature values |
| `--temp-lo` | `#1d4ed8` | `#93c5fd` | Low temperature values |
| `--gauge-fill` | `#3b82f6` | — | Gauge filled arc |
| `--gauge-unfill` | `rgba(0,0,0,0.22)` | — | Gauge unfilled arc |
| `--gauge-indicator` | `#1e40af` | — | Gauge needle/indicator |

### Semantic Color Assignments

These assignments are locked across themes:

- Red = alerts/errors/destructive
- Amber = warnings
- Green = success
- Blue = info/primary
- AQI palette: EPA standard (green/yellow/orange/red/purple/maroon) — domain convention, not brandable

### Contrast Requirements

- Normal text: ≥4.5:1 against background
- Large text (≥18pt regular or ≥14pt bold): ≥3:1
- Non-text UI components, focus indicators, meaningful icons: ≥3:1
- Verify both light AND dark themes independently with tooling — do not eyeball
- Color is never the only signal — pair with icon, label, or position

### Chart Palette

- `--chart-1` through `--chart-5` (currently neutral grayscale; multi-hue deferred)
- Chart colors must remain distinguishable under color-vision deficiency simulation

---

## 4. Typography

### Font Families

| Token | Stack | Role |
|---|---|---|
| `--font-sans` | Manrope, Inter Variable, system-ui, sans-serif | Body, labels, headings, card titles, station name |
| `--font-display` | Outfit (self-hosted @fontsource woff2) | Large stat numerals only (temperature, wind speed, pressure values) |
| `--font-chart` | Lexend (self-hosted @fontsource woff2) | Chart axis, tick, and data labels only |
| `--font-heading` | alias to `--font-sans` | Heading elements |

All three typefaces are self-hosted via @fontsource woff2. No CDN loading.

### Type Scale

| Token | Value | Role | Font | Weight |
|---|---|---|---|---|
| `--text-stat-hero` | 4.25rem | Current temperature numeral | Outfit | 700 |
| `--text-stat-unit` | 1.9rem | Unit beside hero stat (°F/°C) | Outfit | 400 |
| `--text-hero-name` | 1.35rem | Station name in hero card | Manrope | 700 |
| `--text-page-title` | 2rem | Page title in page-header cards (non-Now) | Manrope | 400 |
| `--text-stat-tile` | 1.25rem | Primary stat value on 1×1 tiles | Outfit | 600 |
| `--text-card-title` | 1.1rem | Card title (semibold, NOT bold) | Manrope | 600 |
| `--text-stat-label` | 1rem | Secondary stat value / large label | Outfit or Manrope | 400–600 |
| `--text-section` | 0.95rem | Section headings within cards | Manrope | 500–600 |
| `--text-body` | 0.9rem | Body text, sentences, descriptions | Manrope | 400 |
| `--text-chart-label` | 0.875rem | Chart axis, tick, data labels (standard) | Lexend | 400–600 |
| `--text-chart-label-sm` | 0.6875rem | Chart axis, tick labels in tile-footprint cards | Lexend | 400 |
| `--text-secondary` | 0.85rem | Feels-like, hi/lo, supporting text | Manrope | 400–600 |
| `--text-label` | 0.75rem | Small labels, control text, header control font | Manrope | 400–500 |
| `--text-micro` | 0.7rem | Uppercase micro-labels, minimum text size | Manrope | 400–600 |

Weight ranges in the table (e.g. 400–600) indicate contextual flexibility for a given role. The actual CSS `font-weight` value must be one of the three allowed weights: 400, 600, or 700. A range of "400–600" means use 400 or 600 depending on context; it does not permit 500.

### Typography Rules

- Use `var(--text-*)` tokens for all `fontSize` values. Zero hardcoded px, rem, or em.
- Minimum text size: `--text-micro` (0.7rem / ~11px). Nothing smaller.
- Allowed weights: 400, 600, 700 only. Do not use weight 500.
- Apply `font-feature-settings: "tnum"` on every live-updating numeric element (temp, humidity, rain, wind, pressure, etc.) for tabular figures.
- Card titles: Manrope 600 (semibold). Do not use 700 (bold).
- CJK fallback: ja/zh-CN/zh-TW use system CJK fonts. Do not ship a Noto-CJK bundle.
- SVG `<text>` inside a `viewBox` coordinate system (sun arc, compass cardinals): use viewBox-unit font sizes, not CSS rem. Tokens do not apply. Recharts `tick={{ fontSize }}` props use pixel values mapped to `--text-chart-label` equivalent (14px ≈ 0.875rem).
- **Tile-chart exception:** Charts inside tile-footprint (1-column) cards use `--text-chart-label-sm` (11px) for tick labels, `XAxis height={24}`, and tighter margins (`{ top: 2, right: 12, bottom: 0, left: 12 }`). This is a space constraint — tile content areas cannot accommodate 14px labels with standard margins. Standard-size cards (wide, panel, full) use the normal 14px / `--text-chart-label`.

### Text Color Usage

- Primary body text: `text-foreground`
- Secondary/subdued text, labels: `text-muted-foreground`
- Do not use opacity modifiers on text colors (no `text-muted-foreground/80`). Use the token as-is.
- Text on primary backgrounds: `text-primary-foreground`

---

## 5. Spacing & Layout

### Layout Tokens

| Token | Desktop (md ≥768px) | Mobile (<768px) | Meaning |
|---|---|---|---|
| `--gap-grid` | 1rem | 1rem | Column gutter between cards. Row gap is 0. |
| `--container-max` | 80rem | 80rem | Dashboard content width cap |
| `--card-quarter-row` | 3.25rem | 3.75rem | Base grid row track |
| `--card-half-row` | 6.5rem | 7.5rem | Page headers (2 quarter tracks) |
| `--card-row` | 13rem | 15rem | Standard data card (4 quarter tracks) |
| `--card-content-max` | 9rem | 11rem | Graphic container max-height |
| `--card-pad` | 1rem | 1rem | Standard card padding (all 4 sides) — data cards (rowSpan ≥1) |
| `--card-pad-compact` | 0.5rem | 0.5rem | Compact padding for short cards: quarter-row (strip), half-row (page header, hero) |
| `--card-content-h` | 8.5rem | 10.5rem | Content slot height (derived) |

Token arithmetic must hold: quarter × 2 = half, quarter × 4 = row, quarter × 8 = tall. Desktop: 3.25 × 2 = 6.5 ✓, 3.25 × 4 = 13 ✓, 3.25 × 8 = 26 ✓. Mobile: 3.75 × 2 = 7.5 ✓, 3.75 × 4 = 15 ✓, 3.75 × 8 = 30 ✓.

### Grid System

- **Columns:** 1 (mobile <768px) → 2 (md ≥768px) → 4 (lg ≥1024px)
- **Column gap:** `--gap-grid` (1rem)
- **Row gap:** 0. Vertical spacing comes from card `margin-bottom: var(--gap-grid)`.
- **Container:** `max-w-[var(--container-max)]` (80rem). Every page renders within this. Do not vary the width per page.

### Card Footprint Vocabulary

| Footprint | Columns | Tailwind |
|---|---|---|
| `tile` | 1 | `col-span-1` |
| `wide` | 2 | `col-span-1 md:col-span-2` |
| `panel` | 3 | `col-span-1 md:col-span-2 lg:col-span-3` |
| `full` | 4 | `col-span-1 md:col-span-2 lg:col-span-4` |

### Row Span Model

| Role | rowSpan | Track count (md+) | Desktop height | Mobile min-h |
|---|---|---|---|---|
| Control strip | `"quarter"` | 1 | 3.25rem | 3.75rem |
| Page header | `"half"` | 2 | 6.5rem | 7.5rem |
| Data card (default) | `1` | 4 | 13rem | 15rem |
| Tall card | `2` | 8 | 26rem | 30rem |
| Extra-tall card | `2.5` | 10 | 32.5rem | 37.5rem |

### Two Grid Modes

| Property | Rigid (Now page) | Fluid (other pages) |
|---|---|---|
| Grid `auto-rows` | `var(--card-quarter-row)` | `auto` |
| Card heights | Fixed from grid tracks | Content-adaptive, min-h prevents collapse |
| Content overflow | Hidden — must fit | Visible — content expands the card |
| Use case | Charts, gauges, compass, radar | Legal text, forecast tables, record lists |

A card on a fluid page may opt into fixed-height behavior by setting `overflow: hidden` and constraining to the content box height. This is an explicit opt-in, not the default.

---

## 6. Card Anatomy

### Card Structure

```
┌─────────────────────────────────────────────┐
│  padding (--card-pad: 1rem)                 │
│  ┌───────────────────────────────────────┐  │
│  │ HEADER (content-driven height)        │  │
│  │ ┌─────────────┐  ┌─────────────────┐ │  │
│  │ │ CardTitle   │  │ Controls (opt.) │ │  │
│  │ └─────────────┘  └─────────────────┘ │  │
│  │ ── pb-2 ── underline (full width) ── │  │
│  └───────────────────────────────────────┘  │
│  ┌───────────────────────────────────────┐  │
│  │ CONTENT SLOT (pt-3 spacing)           │  │
│  │ width: card interior - 2 × --card-pad │  │
│  │                                       │  │
│  │   [chart / gauge / text / list]       │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│  padding (--card-pad: 1rem)                 │
└─────────────────────────────────────────────┘
```

Half-row cards (page headers, control strips) do not follow the header + content slot split. They use `--card-pad-compact` (0.5rem), not `--card-pad`. Their full interior (card height minus 2×`--card-pad-compact`) is a single layout area — 5.5rem for half-row desktop, 6.5rem mobile — arranged however the card needs (icon, title, logo, controls, etc.).

### Card Surface Treatment

- Class: `.card-glass` (shared utility, all cards)
- Background: `rgb(var(--card-glass))`
- Backdrop: `blur(8px) saturate(1.1)` (with `-webkit-` prefix)
- Ring: `ring-1 ring-foreground/10`
- Radius: `rounded-xl` (0.875rem)
- Bottom margin: `mb-[var(--gap-grid)]` (1rem, provides vertical spacing between cards)

### Card Header Contract

- Height: content-driven (no fixed height). Header sizes to its tallest child (title text or controls).
- Layout: flex row, `align-items: center`
- Padding: `0 var(--card-pad) 0.5rem var(--card-pad)` (horizontal from token, `pb-2` before the underline)
- Title slot (left): semantic heading (`<h2>` default, configurable level), font `--text-card-title` (1.1rem), Manrope 600, `flex: 1`
- Controls slot (right, optional): `flex-shrink-0`, vertically centered
- Underline: `border-bottom` on `CardHeader`, spans full card interior width (padding edge to padding edge), always present

### Approved Header Control Components

| Component | Use Case | Font | Colors | Touch Target |
|---|---|---|---|---|
| `HeaderTabs` | Switch views (Today/7-Day, Live/Timelapse) | `--text-label` (0.75rem) | inactive: `muted-foreground` bg + `muted-foreground` text; active: accent bg + `primary-foreground` text | ≥44px mobile |
| `HeaderToggle` | Binary on/off | `--text-label` | same | ≥44px mobile |
| `HeaderSelect` | Choose from list | `--text-label` | same | ≥44px mobile |
| `HeaderButton` | Trigger action (download, refresh) | `--text-label` | same | ≥44px mobile |

All share: border-radius consistent with card scale, visible focus ring per accessibility rules.

### Card Rules

- Every element on every page is a card. No free-floating content.
- Standard data cards (rowSpan ≥1): use `--card-pad` (1rem) for all four sides.
- Short cards (quarter-row strips, half-row page headers and hero): use `--card-pad-compact` (0.5rem) for all four sides. These cards have limited vertical space; standard padding wastes too much of it.
- Do not add ad-hoc className overrides for sizing (`!py-1`, `min-h-[...]`, `maxHeight`).
- Every card declares `footprint` and (on Now page) `rowSpan`.
- Cards self-hide when backing data has no non-null aggregate.
- Page self-hides when all its cards hide (except Now — always present).

---

## 7. Iconography

### Hero Weather Icons

Rendered as inline SVG with `<linearGradient>` fills, Meteocons-style palette. Source library: Material Symbols (filled). Coverage: all 29 WMO condition codes. Static — no animation. Partly-cloudy fix: sun uses absolute `M14.975 17.2`, `fill-rule="nonzero"` on both paths. License: Apache-2.0.

| Element | Gradient Top → Bottom |
|---|---|
| Sun | `#FFD24D` → `#F5A623` (gold) |
| Clouds | `#F3F5F8` → `#C7CDD6` (light grey, lighter at top for depth) |
| Lightning | `#FFD24D` → `#F5A623` (gold, same as Sun) |
| Moon | `#86C3DB` → `#72B9D5` (periwinkle) |
| Rain | soft blue (tunable) |
| Snow | pale icy white (tunable) |
| Haze layer (day) | `#C4B99A` → `#A89878` (dusty tan) |
| Haze layer (night) | `#8A8A7A` → `#6A6A5A` (smoky gray) |

**Haze hero icon (ADR-067):** Day variant: muted/pale sun disk with reduced ray intensity, overlaid with horizontal lines in smoky gray/dusty tan gradient. Night variant: obscured/dimmed stars with dirty haze layer. Follows the existing Meteocons-style inline SVG with `<linearGradient>` fills. Exact SVG geometry TBD — separate design task.

### Utility/Stat/Nav Icons

Base library: Phosphor (regular weight). Cross-pack exceptions noted per row.

| Category | Icon |
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
| Wind | `ph:wind` (used on Wind Compass card title and readout block) |
| UV Index | `tabler:uv-index` (cross-pack, Tabler MIT) |
| AQI content icon | `ph:leaf` |
| Precipitation content | `ph:drop` |
| Lightning content | `ph:lightning` |

### Alert Icons

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
| Flood | `material-symbols:flood-outline-rounded` (cross-pack, inline SVG at `icons/flood.tsx`) |
| Tsunami | `mdi:tsunami` (cross-pack, inline SVG at `icons/tsunami.tsx`) |
| Earthquake | `material-symbols:earthquake-outlined` (cross-pack, inline SVG at `icons/earthquake.tsx`) |
| Volcano | `material-symbols:volcano-outlined` (cross-pack, inline SVG at `icons/volcano.tsx`) |
| Landslide | `material-symbols:landslide-outlined` (cross-pack, inline SVG at `icons/landslide.tsx`) |
| Hail | `material-symbols:weather_hail-outlined` (cross-pack, inline SVG at `icons/weather-hail.tsx`) |
| Air quality / dust / smoke | `material-symbols:air-outlined` (cross-pack, inline SVG at `icons/air.tsx`) |

**Haze/smoke condition:** Uses the existing `material-symbols:air-outlined` icon (same as Air quality / dust / smoke alert). No separate haze alert icon — haze is an air quality condition and shares the same visual treatment.

### Nav/Chrome Icons (Phosphor, regular weight)

| Category | Icon |
|---|---|
| Menu | `ph:list` |
| Close | `ph:x` |
| Settings | `ph:gear` |
| Search | `ph:magnifying-glass` |
| Chevrons | `ph:caret-up`, `ph:caret-down`, `ph:caret-left`, `ph:caret-right` |
| Refresh | `ph:arrows-clockwise` |
| External link | `ph:arrow-square-out` |
| Webcam | `ph:camera` |
| Pin (nav rail) | `ph:push-pin` / `ph:push-pin-slash` |

ADR-050 accepted 2026-06-16. Icon assignments above and in the utility/alert tables are locked.

### Icon Rules

- Decorative icons: `aria-hidden="true"`, `focusable="false"`
- Informational SVGs: `<svg role="img"><title>Description</title>…</svg>` or `aria-labelledby`
- Icon-only buttons: must have `aria-label`
- Do not add a title icon to every stat — some metrics are text-only (feels-like, dewpoint)
- Wind exception: use `ph:wind` on Wind Compass card title and readout block; individual wind stat rows are text-only
- C4 stat tiles: no title icons (text-only headers); visual identity comes from content-area elements

---

## 8. Backgrounds & Surfaces

### Sky Background System

- Day/night determination: follows sun position (almanac sunrise/sunset) in auto themes; follows theme toggle in manual light/dark modes. This override is applied client-side in AppLayout — the API's `scene.daytime` field remains almanac-based regardless of the user's theme selection.
- Precipitation overlay: rain (`blend-mode: overlay`, 75% day / 25% night opacity) OR snow (`blend-mode: screen`, 75% day / 25% night opacity)
- Precipitation linger: 15 minutes after last detection
- On-glass overlays: `rain_on_glass.jpg` + `snow_on_glass_transparent.png` (no animation)
- Base layer blur: 3px when precipitation is active

| Condition | Day Asset | Night Asset |
|---|---|---|
| Clear / Mostly Clear / Partly Cloudy | `clear` | `clear_night` |
| Mostly Cloudy / Cloudy / Overcast / Heavy Overcast | `cloudy_day` | `cloudy_night` |
| Thunderstorm | `storm_day` | `storm_night` |
| Foggy | maps to cloudy | maps to cloudy (no dedicated fog photo) |
| Hazy (clear sky + haze) | `hazy_day` (desaturated clear with warm overlay) | `hazy_night` (dimmed clear night with warm overlay) |
| Misty | maps to cloudy | maps to cloudy (same as Foggy) |
| Unknown / startup | maps to clear | maps to clear |

Haze backgrounds are desaturated versions of the clear-sky backgrounds with a warm-toned overlay filter (`sepia(0.15) brightness(0.92) contrast(0.95)`). The haze condition always pairs with a clear/mostly-clear sky classification — never with cloudy/overcast (ADR-067: haze is a clear-sky modifier only). Mist uses the same background as Foggy (cloudy mapping). If dedicated haze photo assets are not available, fall back to clear-sky backgrounds with the CSS overlay filter applied.

On-glass overlays layer on top of the base condition background:

| Trigger | Overlay Asset | Blend Mode | Day Opacity | Night Opacity |
|---|---|---|---|---|
| Rain rate > 0 (or within 15-min linger) | `rain_on_glass.jpg` | `overlay` | 75% | 25% |
| Snow detected (wet-bulb / provider) | `snow_on_glass_transparent.png` | `screen` | 75% | 25% |

When precipitation is active, the base background layer applies a 3px blur.

### Asset Specs

- Maximum file size: ≤300 KB per asset
- Dimensions: ~2560px longest edge
- Format: WebP

### Attribution

Optional string, unobtrusive corner placement. Shipped scenes credit photographers. Default/uncredited scenes show nothing.

### Surface Treatment Inventory

| Surface | Background | Backdrop Filter | Border | Use |
|---|---|---|---|---|
| Card glass | `rgb(var(--card-glass))` | `blur(8px) saturate(1.1)` | `ring-1 ring-foreground/10` | All cards |
| Alert glass | `var(--alert-glass)` | `blur(12px)` | `var(--alert-border)` | Alert banners |
| Modal overlay | `rgba(0,0,0,0.60)` | `blur(4px)` | none | Behind modal dialogs |
| Modal content | `.card-glass` | `blur(16px)` | `ring-1 ring-foreground/10` | Modal card itself |
| Radar controls | `bg-background/80` | `backdrop-blur-sm` | none | Map overlay controls |
| CardFooter | `bg-muted/50` | none | `border-t` | Card footer region |

---

## 9. Navigation

### Desktop Navigation Rail

- Position: fixed left, floating overlay
- Surface: card-glass, `shadow-lg`, `rounded-xl`, `z-20`
- Auto-hide: after 30s idle or `mouseleave`
- Show: on `mouseenter` or grab-bar click
- Pin toggle: pinned by default; user can unpin to enable auto-hide. Persists to `localStorage`.
- Grab bar: visible when rail is hidden; clickable to show rail
- Transition: 200ms ease (opacity + transform)
- Content: station logo/name at top, page icons arranged vertically, theme toggle at bottom
- Icon labels: visible on hover/focus; always-labeled layout is also acceptable
- Active page indicator: background shift + accent line, ≥3:1 contrast
- Theme toggle: `DesktopThemeButton` sits at the bottom of the rail
- ARIA: `aria-label` on nav element, `aria-expanded` managed on show/hide

### Mobile Bottom Navigation

- Position: fixed bottom, full-width
- Maximum slots: 5 (5th slot = "More" overflow)
- "More" overflow sheet: slides up, shows remaining pages
- Icon labels: always visible (compact)
- Active indicator: same treatment as desktop rail
- Theme toggle: `ThemeRowButton` inside the "More" sheet only — not in the bottom bar itself

### Footer

- Legal/Privacy link: always present
- Copyright: `© {year} {station-name}`
- "Powered by Clear Skies" line: visible by default, hideable by operator
- No standalone settings page — theme toggle lives in the nav, not the footer

### Skip Link

- First focusable element in the document
- `class="sr-only"` until focused, then visible
- Target: `#main-content`

---

## 10. Page Structure

### Universal Page Composition

Every page except Now uses `PageLayout`. The composition order is:

1. `<h1 class="sr-only">` — page title for screen readers
2. `Grid` with `md:!auto-rows-[auto]` (fluid mode)
3. `PageHeaderCard` — full-width, half-row, icon + title
4. `ControlsStrip` (optional) — full-width, quarter-row, for pages with many controls
5. Content cards

### Page-Header Card

- Footprint: `full`, rowSpan: `"half"`
- Padding: `--card-pad-compact` (0.5rem), not `--card-pad`
- Icon: left-aligned, 2.25rem (36px) — proportional to the 5.5rem interior height
- Title: visible heading at `<h1>` level, font `--text-page-title` (2rem), Manrope 400
- Controls slot: right-aligned (for pages with few controls)
- Icon and title fill the half-row height visually — they must not look small relative to the card. Previous sizes were 50% too small; the values above are the corrected targets.

### Now Hero Card

The hero is the Now-page page-header card (station logo + station name). It is a half-row card but has distinct rules from the non-Now page-header cards.

- Footprint: `full`, rowSpan: `"half"`
- Padding: `--card-pad-compact` (0.5rem) — the hero is a short card; standard `--card-pad` wastes too much vertical space
- Logo: rendered with `object-fit: contain` and `max-height` constrained to the card interior height (card height minus 2×`--card-pad-compact` = 5.5rem desktop, 6.5rem mobile). The logo must maintain its aspect ratio — never stretch or crop. If the logo is landscape-oriented, it fills the width available; if portrait, it fills the height.
- Station name: `--text-hero-name` (1.35rem), Manrope 700, right of or below the logo depending on layout
- Station ID / location: `--text-secondary` (0.85rem), Manrope 400, secondary text placement

### Controls Strip

- Full-width quarter-row card placed directly below the page header
- Padding: `--card-pad-compact` (0.5rem), not `--card-pad`
- Use approved control components only (`HeaderTabs`, `HeaderSelect`, `HeaderToggle`, `HeaderButton`)
- Do not place raw `<button>` or `<select>` elements inside the strip
- ARIA: `<section aria-label="[Page] controls">`

### Self-Hide Behavior

- **Not configured:** A card hides when its feature is not enabled or its provider is not configured by the operator. A page hides from navigation when all its cards are hidden. The Now page never hides.
- **Configured but no data:** A configured card stays visible with a graceful empty state (e.g., "—" values, skeleton, or "no data available"). Do not hide a configured card due to transient data absence (API timeout, sensor offline, empty response).
- **Data-driven hide (opt-in):** A card may choose to hide based on data state when it makes semantic sense — e.g., the alert card hides when there are no active alerts, not because it's unconfigured but because showing "no alerts" adds no value. This is an intentional per-card design decision, not the default behavior.

---

## 11. Component Patterns

### Card (base primitive)

- **Description:** The sole layout primitive. Every visible element is a card.
- **Anatomy:** glass surface → padding (`--card-pad`) → header slot → content slot
- **Props:** `footprint` (tile/wide/panel/full), `rowSpan` (quarter/half/1/2/2.5), `size` (default/sm), `className`
- **States:** default, loading (skeleton), empty (self-hide), error (graceful degrade)
- **Accessibility:** Card renders as `<div>` (no implicit landmark role). Content within provides semantics.
- **Do:** Use `footprint` and `rowSpan` props. Let the card own its padding.
- **Don't:** Add `!py-*`, `!px-*`, `min-h-[...]`, or `maxHeight` overrides in `className`.

### Card Thumbnails (Admin Layout Editor)

- **Description:** Static preview images used by the admin card layout editor to represent cards in the drag-and-drop palette.
- **Dimensions:** ~200×150px. Consistent aspect ratio across all thumbnails.
- **Format:** PNG. Transparent background is acceptable.
- **Location:** `public/card-thumbnails/{card-type}.png` in the dashboard repo. Built into `dist/card-thumbnails/` by Vite.
- **Content:** Stylized representation of the card's content area — enough to recognize the card at glance. Placeholder images with card name + Phosphor icon are acceptable for initial implementation; pixel-perfect screenshots are not required.
- **Naming:** File name matches the card's `type` field from `card-metadata.ts` (e.g., `aqi.png`, `wind-compass.png`, `radar.png`).
- **Manifest reference:** Each card's `thumbnail` field in `card-manifest.json` points to the thumbnail path relative to the build root (e.g., `"/card-thumbnails/aqi.png"`).
- **Accessibility:** Thumbnails are decorative in the admin context (the card `displayName` provides the text alternative). The admin editor renders them with `alt=""`.
- **Do:** Keep all 14 thumbnails visually consistent (same dimensions, same style).
- **Don't:** Use screenshots of the live dashboard — these would break on theme/data changes and are unnecessarily heavy.

### CardHeader + CardTitle

- **Description:** Structured header slot with title and optional controls.
- **Anatomy:** flex container (`--card-header-h` height) → title heading (left, `flex: 1`) → controls (right, `flex-shrink-0`) → full-width underline
- **Title props:** `title` (string), `as` (h1–h6, default h2), `icon` (optional)
- **Controls:** pass approved control components as `children` of `CardHeader`
- **States:** title always present; controls slot absent when no children passed
- **Accessibility:** Title renders as a real heading element. Controls must be keyboard-reachable.
- **Do:** Use `CardTitle` for the heading. Pass controls as children of `CardHeader`.
- **Don't:** Write a custom `<h2>` with hand-copied classes. Style controls inline per card.

### Alert Banner

- **Description:** Active weather alert card with severity-colored left stripe.
- **Anatomy:** glass surface (alert-specific) → icon (severity) → headline + description + metadata → severity badge (desktop only) → expand/collapse chevron region
- **Props/variants:** `severityLevel` (1–4), `severityLabel` (string), `alertType` (maps to icon)
- **Severity badge:** Desktop only, right-center justified (away from the title to avoid redundancy). Displays the severity label in a compact colored badge. Hidden on mobile — not enough horizontal space.
- **Expand/collapse chevron:** The entire chevron region is the tap target (not just the icon). Desktop: current region size. Mobile: smaller region width to preserve headline space, but still ≥44×44px touch target. The chevron icon itself scales down on mobile proportionally.
- **States:** collapsed (headline only), expanded (full description + metadata)
- **Accessibility:** `aria-live="polite"` for new alerts, `aria-expanded` on the chevron `<button>`, severity announced via text label. Badge is supplementary — severity is already conveyed by the icon and text, so the badge can be `aria-hidden="true"`.
- **Do:** Use the alert severity model (4-tier `severityLevel` + `severityLabel`).
- **Don't:** Use color alone to indicate severity — pair with icon and text label.

### Skeleton Loading

- **Description:** Placeholder shown while data loads.
- **Anatomy:** single `<div>` with pulse animation, sized to approximate loaded content
- **Pattern:** `<div className="animate-pulse rounded-lg bg-muted" style={{ height: '...' }} aria-hidden="true" />`
- **States:** visible during load, replaced by content on resolve
- **Accessibility:** `aria-hidden="true"` on the skeleton element; `role="status"` with sr-only text provides the loading announcement.
- **Do:** Match skeleton height to the expected loaded content height.
- **Don't:** Show a skeleton indefinitely — implement an error/empty state for failed loads.

### CollapsibleCard (Legal page pattern)

- **Description:** Card with a header that toggles content visibility.
- **Anatomy:** `CardHeader` with `role="button"`, `aria-expanded`, `tabIndex={0}` → content div with `maxHeight` transition → bottom fade gradient when collapsed
- **Props/variants:** `defaultOpen` (boolean), section title
- **States:** collapsed (preview with fade gradient), expanded (full content)
- **Accessibility:** Enter/Space toggle, `aria-expanded` state managed on header element
- **Do:** Use `black 80%, transparent 100%` for the collapsed fade gradient.
- **Don't:** Use `black 40%, transparent 100%` — too aggressive, content becomes unreadable.

### SemiCircularGauge

- **Description:** Half-circle arc gauge used for barometer and AQI readings.
- **Anatomy:** SVG arc (filled segment + unfilled segment) → center overlay (value + unit + trend arrow)
- **Props/variants:** `value` (number), `min`, `max`, `unit` (string), `trend` (up/down/steady)
- **States:** default (live value), loading (skeleton), no-data (hidden)
- **Accessibility:** `<svg role="img"><title>` with readable description; center value also in DOM text for AT
- **Do:** Fill the content slot via `flex: 1, minHeight: 0, maxHeight: var(--card-content-max)`.
- **Don't:** Hardcode pixel dimensions — the gauge must resize with the card.

Colors: `--gauge-fill` (filled arc), `--gauge-unfill` (unfilled arc), `--gauge-indicator` (needle/indicator).

### Horizontal Scroll Navigation

- **Description:** Consistent scroll mechanism for cards with horizontally scrolling content (hourly forecast, 7-day forecast, meteor showers, eclipse timeline, etc.).
- **Anatomy:** Round chevron buttons (`◀` / `▶`) positioned on the left and right edges of the card. Buttons may project beyond the card boundary into the grid margin/gutter space — they are not constrained to the card interior.
- **Button styling:** Round (`rounded-full`), card-glass surface, shadow for depth, vertically centered against the scrollable content area. Chevron icon inside (Phosphor `ph:caret-left` / `ph:caret-right`).
- **Behavior:** Click/tap scrolls the content by one "page" (the visible width of the scroll area). Buttons hide when there is no further content in that direction (at the start, hide left; at the end, hide right).
- **Touch:** Swipe scrolling is also supported alongside the buttons — the buttons supplement swipe, they do not replace it.
- **Accessibility:** Each button has `aria-label="Scroll left"` / `aria-label="Scroll right"`. The scrollable container has `role="region"`, `aria-label` describing the content, and `tabindex="0"` for keyboard scrolling.
- **Do:** Use this pattern on every card with horizontal overflow. Let buttons project into the margin. Hide buttons at scroll boundaries.
- **Don't:** Use inconsistent scroll mechanisms across cards (some with buttons, some swipe-only, some with scroll bars). Place buttons inside the content area where they obscure data.

### Charts (Recharts)

- **Description:** Time-series and specialized data visualizations rendered with Recharts inside card content slots.
- **Layout:** Charts fill the card content slot using `ResponsiveContainer` with `width="99%"` and `height="100%"`. The wrapper div needs explicit sizing (`minWidth: 0, minHeight: 0, width: '100%', height: '100%'`) to prevent flex containers from reporting 0 to ResizeObserver.
- **Typography:** Axis labels, ticks, and data labels use Lexend (`--font-chart`) at `--text-chart-label` size. Recharts `tick={{ fontSize }}` props take pixel values — use 14px (the pixel equivalent of 0.875rem). Do not use rem values in Recharts tick props. **Tile-chart exception:** charts inside tile-footprint cards use 11px (`--text-chart-label-sm`), `XAxis height={24}`, and tighter margins (`{ top: 2, right: 12, bottom: 0, left: 12 }`) — the standard 14px labels are too large for the constrained content area of a 1-column tile.
- **Colors:** Use `--chart-1` through `--chart-5` for series colors. Domain-specific colors (`--temp-hi`, `--temp-lo`, `--gauge-fill`) where semantically appropriate.
- **Tooltips:** Card-glass surface treatment, `--text-body` font, `--font-sans`. Show value + unit + timestamp. Match the card's border-radius.
- **Expandable view:** Charts should support an expanded/full-screen view for detailed inspection. The expanded view uses the same chart configuration at a larger size — not a different chart.
- **Responsive:** Charts reflow with their card. On mobile (1-column), charts get full viewport width minus card padding. Axis labels that would overlap at narrow widths should be culled or rotated — not clipped.
- **Special chart types:** Wind rose (custom SVG polar), weather range (Recharts arearange/columnrange), and hays chart (circular wind) are detected automatically by series name in `charts.conf`. All other series render as standard Recharts time-series.
- **Accessibility:** Every chart container has `aria-label` summarizing what the chart shows. A `sr-only` data table with matching values renders alongside every chart.
- **Reference:** Read `docs/reference/recharts-axis-reference.md` before any chart layout change. Recharts has non-obvious axis/margin behavior that causes silent rendering failures.
- **Do:** Use `ResponsiveContainer`, semantic chart colors, Lexend for labels. Let the chart fill its content slot.
- **Don't:** Use negative margins (clips data). Set `margin.bottom` for label space (XAxis `height` handles it). Set `width={0}` on visible YAxis. Use the `hide` prop on YAxis (Recharts bug #428).

### Data Tables

- **Description:** Tabular data display used on Records, Reports, and About pages.
- **Structure:** Always use semantic `<table>` with `<thead>`, `<tbody>`, and `<th scope="col"|"row">`. Do not fake tables with CSS grid or stacked divs.
- **Header hierarchy:** Table headers are the primary wayfinding element — they must be visually stronger than cell data. Headers: `--text-label` size, `font-weight: 600`, `text-muted-foreground` color, uppercase or small-caps. Do not de-emphasize headers below content — in a dense table, headers are the only way a reader orients.
- **Cell typography:** Data cells use `--text-body` or `--text-secondary`, `font-weight: 400`, `text-foreground`. Numeric values use `font-feature-settings: "tnum"` and right-align. Text values left-align. Units stay with their values (no separate unit column).
- **Row treatment:** Alternating row backgrounds (`bg-muted/30` on even rows) for scanability in dense tables. Highlighted rows (warmest/coolest day, record values) use a subtle background tint, never color alone — pair with a label or icon.
- **Spacing:** Adequate cell padding for readability — cells should not feel cramped. Horizontal padding ≥0.5rem, vertical ≥0.375rem.
- **Column grouping:** When multiple columns belong to the same measurement (e.g., High + Time, Peak Gust + Time + Dir), visually group them — tighter internal spacing, subtle separator between groups, or a spanning `<th colspan>` group header.
- **Responsive:** Tables with many columns use horizontal scroll on mobile (`overflow-x: auto` on a wrapper div) rather than reflowing into cards. The first column (date/label) should be sticky (`position: sticky, left: 0`) so the reader always knows which row they're looking at.
- **Accessibility:** `<caption>` or `aria-label` on the table element describing what data it contains. `<th scope>` on every header cell. Do not use `aria-hidden` on any data cell.
- **Do:** Use semantic table markup. Make headers visually dominant. Sticky first column on mobile. Group related columns.
- **Don't:** De-emphasize headers below data. Use CSS grid to fake a table. Let wide tables clip on mobile without scrolling.

---

## 12. Data Formatting

### Unit Display

- Use operator-preferred units from station config (US / Metric / MetricWX)
- Temperature: always show unit suffix (°F or °C)
- Wind: value + unit (e.g. "12 mph", "5.4 m/s")
- Pressure: value + unit (e.g. "30.02 inHg", "1015.3 mbar")
- Rain: value + unit (e.g. "0.45 in", "11.4 mm")
- Apply `font-feature-settings: "tnum"` to all numeric values for tabular figures

### Number Precision

| Metric | Precision | Example |
|---|---|---|
| Temperature | 1 decimal place | 72.4°F |
| Pressure | 2 decimal places | 30.02 inHg |
| Wind speed | 1 decimal place | 4.9 mph |
| Rain | 2 decimal places | 0.00 in |
| Humidity | Integer | 84% |
| UV Index | Integer | 7 |

### Date/Time Formatting

- Use `Intl.DateTimeFormat` with operator timezone and visitor locale
- Relative time: `Intl.RelativeTimeFormat` (e.g. "1 minute ago")
- Do not hardcode date format strings

### No-Data States

- Show "—" for missing individual values. Do not show "N/A" or "Error".
- Card level: card self-hides when all backing data is null
- Never show stale data without a staleness indicator

---

## 13. Responsive Behavior

### Breakpoints

| Name | Width | Grid Columns | Nav Pattern | Card Heights |
|---|---|---|---|---|
| Mobile | <768px | 1 | Bottom bar (fixed) | Content-adaptive (auto) |
| Desktop (md) | ≥768px | 2 | Left rail (auto-hide) | Rigid tracks on Now; auto elsewhere |
| Wide (lg) | ≥1024px | 4 | Left rail (auto-hide) | Same as md |

### Responsive Rules

- Design for mobile first; extend layout for desktop — do not build desktop-first and shrink down.
- Cards stack in document reading order on mobile (1-column).
- All interactive elements: minimum touch target ≥44×44px.
- No hover-only affordances — every interaction reachable by touch or keyboard.
- Maintain adequate spacing between adjacent interactive elements on touch screens.
- `full` and `panel` cards span the full width of the current column count at every breakpoint.
- `wide` cards occupy 2 columns at md and lg; collapse to 1 column on mobile.
- `tile` cards occupy 1 column at all breakpoints.

---

## 14. Motion & Transitions

- Live data updates (temperature numeral, wind compass rotation, lightning state): ~200ms tween.
- Nav rail show/hide: 200ms ease, opacity + transform.
- Page transitions: none — route swaps are instant.
- Card expand/collapse (CollapsibleCard): 300ms ease-in-out, max-height transition.
- No parallax effects. No scroll-driven animations.
- `prefers-reduced-motion: reduce`: disable all tweens; use instant updates and swaps.
- Alert banner expand/collapse: smooth height transition (same 300ms ease-in-out rule).
- Skeleton → content swap: instant — no fade or cross-dissolve.

---

## 15. Theming & Operator Customization

### Theme System

- Mechanism: `data-theme` attribute on `<html>` (values: `light` | `dark`).
- No-flash: inline `<script>` in `index.html` runs synchronously before CSS parses, reads localStorage and sets `data-theme` before first paint.
- Toggle cycle: system → light → dark → system (three-position).
- Storage: `localStorage('clearskies.theme.user-override')` — values `light`, `dark`, or `system`.
- Tailwind v4 dark variant: `@custom-variant dark (&:where([data-theme="dark"], [data-theme="dark"] *))` in `index.css`.
- No theme-transition animation — swap is instant (respects motion budget and avoids flash).

### Four Theme Modes

| Mode | Behavior |
|---|---|
| Light | Always light regardless of OS preference |
| Dark | Always dark regardless of OS preference |
| Auto (OS) | Follows `prefers-color-scheme` media query in real time |
| Auto (sunrise/sunset) | Fetches almanac rise/set times; switches at sunrise and sunset. Re-fetches at midnight. Polar clamp: if rise/set gap >24h, clamp to midnight boundary. Falls back to OS preference if rise/set times are null. |

### Operator Branding

| Field | Source | Dashboard Behavior |
|---|---|---|
| Accent color | `branding.json` → 6 curated options | Sets `--brand-primary-*` CSS variables at runtime. `branding.json` is served by Caddy at `/branding.json` (static file from `/etc/weewx-clearskies/`), not from the API. |
| Logo (light) | Upload via wizard | Rendered in hero card and nav rail |
| Logo (dark) | Optional upload via wizard | Used in dark theme; if absent, light logo is CSS-inverted with a console warning |
| Logo alt | Wizard input | Required for accessibility. Fallback: `"<siteTitle> logo"` |
| Site title | `branding.json` | Set as `document.title` |
| Favicon | `branding.json` | Applied to `<link rel="icon">` |
| Custom CSS | URL in `branding.json` | Linked last in `<head>`; operator owns override. CSS variable names are NOT promised stable across releases. |
| GA ID | `branding.json` | Shows cookie consent banner when set; GA blocked until visitor opts in |
| Privacy regions | `branding.json` | Controls jurisdiction filtering on Legal page |
| Default theme mode | `branding.json` | Applied on first load when no user override is stored |

### What Is NOT Customizable

- Structural layout: grid columns, card anatomy, content box dimensions.
- Component anatomy: header slot structure, approved control components.
- Type scale: token values and font families.
- Accessibility requirements: contrast ratios, focus indicators, semantic HTML rules.
- Card radius: always `rounded-xl` (0.875rem).

---

## 16. Accessibility

### WCAG 2.1 Level AA — Release-Blocking Floor

- Treat accessibility issues with the same severity as a security vulnerability or a broken build.
- Audit per change — not per release. Do not defer accessibility fixes to a "cleanup" sprint.

### Contrast

- Normal text: ≥4.5:1 against its background.
- Large text (≥18pt regular or ≥14pt bold): ≥3:1.
- Non-text UI components, focus indicators, and meaningful icons: ≥3:1.
- Verify both light and dark themes independently using tooling — do not eyeball contrast.
- Never use color as the only signal — pair with an icon, label, or positional cue.

### Semantic HTML

- Use `<button>` for buttons, `<a>` for links, `<nav>` for navigation, `<main>` for page content.
- Maintain heading hierarchy h1–h6 in document order with no skipped levels.
- Do not use `<div onClick>` when `<button>` is the correct element.
- Every `<input>` has an explicit `<label>` (visible or `sr-only`). `placeholder` is not a label.
- Error inputs: add `aria-describedby` pointing to the error message and `aria-invalid="true"`.
- Lists are `<ul>`/`<ol>`/`<li>` — not stacked `<div>` elements.
- Tables are `<table>` with `<thead>`/`<tbody>`/`<th scope="col"|"row">` — do not fake tabular data with CSS grid alone.

### Keyboard

- Every interactive element is reachable by Tab in visual order.
- Tab order equals visual order — do not use `tabindex` values greater than 0.
- Every focusable element has a visible focus indicator. Do not use `outline: none` without a visible replacement.
- Escape closes modals, menus, and dropdowns.
- Enter and Space activate buttons.
- Arrow keys navigate within composite widgets per WAI-ARIA Authoring Practices.
- A skip-to-main-content link is the first focusable element on every page.
- Focus traps in modals: Tab/Shift-Tab cycles within the modal; closing the modal returns focus to the element that opened it.

### ARIA

- First rule: use the correct HTML element before reaching for ARIA.
- Icon-only buttons: `aria-label` is required.
- Decorative icons: `aria-hidden="true"` and `focusable="false"`.
- Dynamic regions that update without a page load: `aria-live="polite"` (non-urgent) or `aria-live="assertive"` (emergencies only).
- Do not lie with ARIA — `role="button"` on a `<div>` requires manual keyboard handling and focus management; use `<button>` instead.

### Images & Icons

- Every `<img>` has `alt`. Informational images: descriptive alt text. Decorative images: empty `alt=""`. Functional images: describe the action.
- Operator-uploaded images require alt text at upload — there is no skip path.
- Informational SVG icons: `<svg role="img"><title>Description</title>…</svg>` or `aria-labelledby`.
- Decorative SVG icons: `aria-hidden="true"` and `focusable="false"`.
- Charts: add `aria-label` on the chart container and provide a `sr-only` data table alongside.

### Localization

- Set `<html lang="…">` to the active locale. Supported locales: en, de, es, fil, fr, it, ja, nl, pt-PT, pt-BR, ru, zh-CN, zh-TW.
- Use `margin-inline-start` not `margin-left` for logical property RTL-readiness, even though v0.1 ships no RTL languages.

### Per-Change Checklist

Run before declaring any UI change done:

- [ ] Every `<img>` has `alt`
- [ ] Every icon-only button has `aria-label`
- [ ] Every `<input>` has `<label>`
- [ ] Every color combination checked in both light and dark themes
- [ ] Every interactive element is keyboard-reachable with a visible focus indicator
- [ ] Heading levels are in order with no skipped levels
- [ ] No `<div onClick>` where `<button>` belongs
- [ ] Dynamic content has `aria-live`
- [ ] Chart data-table fallback present and matches chart data
- [ ] `npx @axe-core/cli` returns zero violations, or each violation has a documented reason

---

## 17. Wizard Design Standards

The setup wizard (`weewx-clearskies-stack`) uses Pico CSS + HTMX + Jinja2. It intentionally diverges from the dashboard's Tailwind/React stack, but shares design language in these areas: typography rhythm, form field patterns, accessibility scaffold, and color accent.

### Step Structure (all 15 steps)

Every wizard step uses this exact HTML structure:

```html
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

### Form Field Pattern

Every form field in the wizard uses this exact structure:

```html
<label for="field_id">Label</label>
<input type="text" id="field_id" name="field_name" value="..." aria-describedby="field_hint">
<small id="field_hint">Helpful description</small>
```

- Every input has an explicit `<label>` and an `aria-describedby` hint `<small>`.
- Required fields: include `<span aria-hidden="true">*</span>` inside the label after the label text.
- Error display: apply `.input-error` border class to the input + `.error-text` element below the input + a `.alert-error` div at the top of the step with `role="alert"`.

### Progress Bar

- Markup: `<ol class="wizard-progress" role="list">` with 15 items.
- Step numbers rendered via CSS counters in circular badges (1.75rem diameter).
- Three states per step: muted (incomplete), primary background with outline (current), checkmark glyph (complete).
- Completed steps are clickable `<a>` links using HTMX GET for back-navigation.
- Responsive: step labels are hidden below 36rem viewport width; step number badges remain visible.
- Updated via HTMX out-of-band swap (`hx-swap-oob="true"`) on every step response — no full-page reload.

### Password Toggle

- SVG eye icon positioned inside the input field (absolute, right side).
- `togglePassword(btn)` function swaps `type` attribute between `password` and `text`.
- `aria-label="Show/Hide [field name]"` on the toggle button; `aria-controls` points to the input `id`.
- Toggle button is borderless, muted color at rest, primary color on hover and focus.

### Typography

- Root font size: `--pico-font-size: 87.5%`; line height: `--pico-line-height: 1.4`.
- Monospace stack (EULA text, secret values): Cascadia Code, Source Code Pro, Menlo, Consolas.
- Compact vertical spacing: `--pico-form-element-spacing-vertical: 0.5rem`.

### HTMX Patterns

- Fragment architecture: wizard steps are Jinja2 templates, not full pages. Every response swaps into `#wizard-content` — the nav, progress bar, and page shell are never re-sent.
- OOB updates: progress bar is updated via `hx-swap-oob="true"` on every step response without re-rendering the step content.
- 422 handling: validation errors return HTTP 422; HTMX is configured to treat 422 as a valid swap response so error markup renders in place.
- Focus management: after every HTMX settle event, JavaScript finds the first `h2` or `h3` inside `#wizard-content`, sets `tabindex="-1"`, and calls `.focus()` to move screen reader focus to the new step.
- Scroll: every `hx-swap` attribute includes `show:window:top` to scroll the viewport to the top on each step transition.

---

## 18. Anti-Patterns

### Layout

- Never add free-floating content outside a card.
- Never render a card narrower than one grid column.
- Never vary `--container-max` per page.
- Never use rigid grid tracks on non-Now pages — use `auto-rows-[auto]`.
- Never add generic educational prose to data pages — relocate explanatory content to documentation.

### Typography

- Never hardcode font sizes — use `--text-*` tokens only.
- Never use text smaller than `--text-micro` (0.7rem).
- Never use font-weight 500.
- Never apply opacity modifiers to text color tokens (no `text-muted-foreground/80`).
- Never use Tailwind utility classes `text-xs` or `text-sm` for content — use named tokens.

### Color

- Never rely on color alone to convey state — pair with icon, label, or position.
- Never use a free-form color picker for operator accent — use the 6 curated options only.
- Never adjust a color shade to be so close to the contrast limit that small changes break WCAG — choose a different shade with margin.
- Never hardcode hex color values in component code for theme-dependent colors.

### Components

- Never write a custom `<h2>` with hand-copied header classes — use `CardTitle`.
- Never style card controls inline per-card — use `HeaderTabs`, `HeaderToggle`, `HeaderSelect`, or `HeaderButton`.
- Never add `!py-*`, `!px-*`, or any `!important` padding overrides on cards.
- Never set `min-h-[...]` or `maxHeight` manually on cards — use tokens.
- Never place controls outside `CardHeader` or `ControlsStrip`.
- Never pass a raw `<button>` or `<select>` directly into `ControlsStrip`.

### Charts

- Never use negative margins on Recharts components — they clip data and labels.
- Never set `margin.bottom` on a Recharts chart to create label space — use `XAxis height` instead.
- Never set `width={0}` on a visible `YAxis` — a zero-width YAxis becomes invisible.
- Never use the `hide` prop on a Recharts `YAxis` — it triggers a known Recharts bug (#428) that causes XAxis labels to vanish.
- Read `docs/reference/recharts-axis-reference.md` before making any chart layout change.
- Never use Recharts `tick={{ fontSize }}` props with rem values — map to the pixel equivalent of `--text-chart-label` (14px ≈ 0.875rem) for standard cards, or `--text-chart-label-sm` (11px) for tile-footprint cards.

### Accessibility

- Never use `<div onClick>` when `<button>` is the correct element.
- Never remove `outline` without providing a visible focus replacement.
- Never skip heading levels in a document or component.
- Never accept an operator image upload without requiring alt text.
- Never use `placeholder` as a substitute for a `<label>`.
- Never omit `aria-label` on icon-only buttons.

### Motion

- Never add parallax or scroll-driven animations.
- Never add a transition animation when switching themes — the swap must be instant.
- Never ignore `prefers-reduced-motion: reduce` — disable all tweens when the user has set this preference.

---

## 19. Radar Card & Expanded View Design

### Radar card (Now page)

The radar card uses the standard card anatomy (§6) with a Leaflet map filling the content area.

**Card header:**
- `CardTitle`: "Radar" (standard card title styling — `var(--text-card-title)`, semibold, border-bottom).
- `HeaderButton`: Phosphor `ArrowsOut` icon (expand to fullscreen). Position: right side of header, using the standard `ControlsStrip` pattern.

**Card content:**
- Leaflet map fills 100% of the card content area.
- No padding between card border and map edge.
- Legend gradient: horizontal bar below the map, inside the card. Height: 8px. Full width. Gradient colors from the active provider's color scheme.
- Attribution line: small text below the legend (`var(--text-micro)`, `var(--muted-foreground)`).
- Nowcast indicator: when animation crosses from past to nowcast frames, a subtle label or opacity change indicates "Forecast" data.

**Dark/light theme:**
- Base map tiles switch between light and dark variants (OSM Carto light/dark or equivalent).
- Card glass, header, legend use standard theme tokens.

### Expanded radar overlay

Full-viewport overlay. Not a new page layout — an overlay that takes over the viewport.

**Layout (desktop ≥1024px):**
```
+-----------------------------------------------+
| [X Close]                          (top-right) |
|                                                 |
|            Leaflet map (fills viewport)         |
|                                                 |
|                           +-------------------+ |
|                           | Layer/config panel | |
|                           | (right sidebar)    | |
|                           | 320px width        | |
|                           +-------------------+ |
|                                                 |
| [|<<  <  ▶  >  >>|] ---- time slider ---- [2x] |
+-------------------------------------------------+
```

**Layout (mobile <1024px):**
```
+---------------------------+
| [X Close]                 |
|                           |
|    Leaflet map            |
|    (fills remaining)      |
|                           |
+---------------------------+
| Bottom sheet (drag handle)|
| Layer/config panel        |
| Half-height default       |
+---------------------------+
| Time slider + controls    |
+---------------------------+
```

**Close button:**
- Position: top-right, floating over the map.
- Phosphor `X` icon, `aria-label="Close radar view"`.
- `z-index: var(--z-overlay-controls)` (above map, below modals).
- Size: 44×44px minimum tap target.
- Background: semi-transparent card glass token.

**Time slider (bottom bar):**
- Full-width bar at bottom of viewport.
- Height: 56px desktop, 64px mobile (≥44px tap targets).
- Background: semi-transparent card glass token.
- Controls (left to right): skip-to-start, step-back, play/pause, step-forward, skip-to-end, time slider track, speed selector, timestamp display.
- Slider track: filled segment for past frames, distinct color segment for nowcast frames.
- Timestamp: formatted in station timezone, `var(--text-card-value)` size.

**Layer/config panel:**
- **Desktop:** Right sidebar, 320px width, collapsible (toggle button on left edge). Semi-transparent card glass background.
- **Mobile:** Bottom sheet with drag handle. Half-height default, full-height on drag. ≥44px tap targets on all controls.
- **Contents (in order):**
  1. Color scheme picker (LibreWxR only): grid of 13 swatches, 4 columns. Each swatch: 48×48px, rounded, shows gradient preview. Selected swatch has ring border (`var(--ring)`).
  2. Opacity slider: label "Radar opacity", range 0-100%, default 70%. Standard slider control.
  3. Alert toggle (LibreWxR only): labeled switch "Weather alerts", default on.
  4. Wind arrows toggle (LibreWxR only): labeled switch "Wind arrows", default off.
- Controls hidden when not applicable to the active provider (e.g., color schemes hidden for RainViewer).

**Alert polygon styling:**
- Severity-colored using WMO CAP severity mapping:
  - Extreme: red stroke (`#dc2626`), red fill at 20% opacity.
  - Severe: orange stroke (`#ea580c`), orange fill at 20% opacity.
  - Moderate: yellow stroke (`#ca8a04`), yellow fill at 15% opacity.
  - Minor: green stroke (`#16a34a`), green fill at 10% opacity.
  - Unknown: gray stroke (`#6b7280`), gray fill at 10% opacity.
- Stroke width: 2px.
- On hover/focus: popup with alert headline and event type.

**Z-order (bottom to top):**
1. Base map tiles (OpenStreetMap)
2. Radar tiles (XYZ animated layer)
3. Wind arrow tiles (optional, LibreWxR only)
4. Alert polygons (GeoJSON overlay, LibreWxR only)
5. Map controls (zoom, attribution)
6. Time slider bar
7. Layer/config panel
8. Close button

**Dark/light theme:**
- Base map: light theme uses light OSM tiles, dark theme uses dark OSM tiles.
- Controls (time slider, panel, close button): use card glass tokens, adapting to theme.
- Alert polygon colors are fixed (severity-semantic, not theme-dependent).

### Responsive breakpoints

| Breakpoint | Panel behavior | Time slider | Controls |
|---|---|---|---|
| ≥1024px (desktop) | Right sidebar, 320px | Full bottom bar | All visible |
| <1024px (mobile) | Bottom sheet, drag handle | Simplified bottom bar | Stack vertically in bottom sheet |

All interactive elements: ≥44px tap targets on mobile (WCAG 2.5.8).
