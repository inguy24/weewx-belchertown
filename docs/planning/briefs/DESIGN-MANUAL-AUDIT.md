# Design Manual Audit — Raw Results

**Date:** 2026-06-16
**Purpose:** Raw audit data for drafting DESIGN-MANUAL-PLAN.md

---

## Audit 1: ADR Document Inventory

### Sources Audited
ADR-009, ADR-022, ADR-023, ADR-024, ADR-026, ADR-047, ADR-048, ADR-049, ADR-050, ADR-051 (+ 3 amendments), ADR-062, rules/coding.md §5 and §9.

### Rule Count by Category
- Layout tokens: 9 tokens (spacing, grid, card sizing)
- Typography tokens: 14 tokens (font sizes, families, weights)
- Color rules: ~25 constraints (palette, contrast, semantic colors, operator branding)
- Card rules: ~20 rules (footprints, headers, content box, surface treatment)
- Icon rules: ~30 specifications (hero family, utility family, sizing, cross-pack exceptions)
- Navigation: ~10 rules (desktop rail, mobile bottom bar, auto-hide behavior)
- Page taxonomy: 9 pages + custom pages with self-hide behavior
- Background system: ~15 rules (sky buckets, precipitation overlay, day/night, attribution)
- Motion: 4 rules (restrained, no parallax, 200ms tweens, prefers-reduced-motion)
- Accessibility: ~40 rules (WCAG AA floor, per-change checklist, pre-ship audit)
- Prohibition rules: ~25 explicit bans
- Theme system: ~12 rules (data-theme, 4 modes, no flash, toggle cycle)

### Key Gaps Found (documented but not in code)
- `--card-pad` token (1rem uniform) — ADR-051 amendment specifies, code still uses `py-2.5`/`px-4`
- `--card-header-h` token — ADR-062 specifies 2.5rem, code doesn't implement
- `--card-content-h` derived token — ADR-051 amendment specifies, code doesn't implement
- `--text-card-title` at 1.1rem — ADR-051 amendment specifies, code still has 0.82rem
- Row height tokens at Option B values — ADR-051 amendment specifies, code still has old values
- HeaderTabs/HeaderToggle/HeaderSelect/HeaderButton — ADR-062 specifies, components don't exist
- ControlsStrip using approved controls — ADR-062 specifies, code accepts raw children

### Key Gaps Found (in code but not documented)
- Glass surface CSS (`.card-glass` utility, backdrop-filter values) — no ADR specifies exact values
- Alert glass surface (`.alert-glass`) — separate treatment, not documented in any ADR
- Container query usage in CardHeader (`@container/card-header`) — working but undocumented
- SVG arc visualization constants (SUN_RX, MOON_RX, etc.) — hardcoded, not tokenized
- Forecast cell height/width JavaScript calculations — precision layout, undocumented
- Tab pill styling pattern (inline styles with var() refs) — effective pattern, no shared component
- Skeleton loading pattern (`.animate-pulse.rounded-lg.bg-muted`) — consistent but undocumented
- Modal overlay glass (blur 16px) — used in eclipse cards, not formalized

---

## Audit 2: Dashboard Codebase Patterns

### Token Usage Summary
- 60+ CSS custom properties defined in index.css
- Typography: mostly token-based (`var(--text-*)`) but almanac cards use hardcoded `text-[0.9rem]`, `text-[0.75rem]`
- Colors: consistently token-driven except hardcoded SVG colors (#f59e0b sun, #94a3b8 moon)
- Spacing: highly consistent via Tailwind utilities except card vertical padding asymmetry

### Card Header Inconsistency (confirmed)
- Pattern A: 10 Now-page cards use custom `<h2>` with hand-copied classes
- Pattern B: Almanac/Forecast/Webcam/Charts use `CardTitle` component
- Different spacing: `pb-0.5` (Pattern A) vs `pb-1.5 mb-3` (Pattern B)

### Icon Size Inventory
- Scattered: 8px, 12px, 13px, 14px, 16px, 18px, 20px, 22px, 24px, 34px, 36px, 96px, 112px, 115px
- No formal icon size scale or tokens

### Glass Surface Treatment
- Card: `blur(8px) saturate(1.1)` with `rgb(var(--card-glass))`
- Alert: `blur(12px)` with custom amber tint
- Modal overlay: `blur(4px)` backdrop + `blur(16px)` on detail card
- Radar controls: `backdrop-blur-sm` (Tailwind utility)

### Interaction Patterns (no shared components)
- Tab pills: inline styles in NowForecastCard and WebcamCard
- Theme toggle: custom three-state cycle button
- Chart/Table toggle: custom aria-pressed button
- Dropdowns: native `<select>` elements
- Collapsible: custom height transition per component

---

## Audit 3: Wizard Patterns

### Strengths
- Highly cohesive structure: all 15 steps follow article > header > form > button-group
- Consistent form patterns: fieldset/legend, label+input, aria-describedby hints
- Strong accessibility: focus management after HTMX swap, sr-only class, skip link
- Progress bar: CSS counters, clickable completed steps, responsive label hiding
- HTMX fragment architecture: clean step templates, OOB progress updates, 422 handling

### Typography
- Pico CSS base: 87.5% root font-size, 1.4 line-height
- Compact spacing: 0.5rem vertical form element spacing
- Monospace for secrets/EULA: Cascadia Code, Source Code Pro stack

### Color Palette
- Blue header gradient: #1a5276 → #2980b9
- Pico CSS defaults for primary/muted/success/error
- Dark mode via prefers-color-scheme media query
- Container background: rgba(white, 0.93) / rgba(dark gray, 0.93)

### What Works Well (undocumented standards)
1. Progress bar design (numbers + labels + color states)
2. Password show/hide toggle (SVG overlay, accessible)
3. Form validation UX (field-level errors, async test buttons)
4. Responsive design (36rem breakpoint for mobile labels)
5. Conditional UI patterns (single keyless provider, logo preview, variant warnings)
6. Review/confirmation tables (scope="row" headers, edit links, masked keys)

---

## Audit 4: Best-Practice Design System Structure

### Recommended Table of Contents (from Material Design, Carbon, Atlassian, Polaris, USWDS research)

1. **Purpose and Scope** — what the doc governs, who consumes it, glossary
2. **Design Principles** — 3-5 tie-breaker principles with examples
3. **Design Tokens: Color** — primitive → semantic → component tokens, contrast requirements
4. **Design Tokens: Typography** — type scale, font families, semantic roles, truncation
5. **Design Tokens: Spacing and Layout** — spacing scale, grid system, component padding vs gaps
6. **Design Tokens: Elevation and Borders** — shadows, radii, dividers, z-index
7. **Iconography and Data Visualization** — icon set, sizing, weather-specific conventions, chart colors
8. **Responsive Behavior** — named breakpoints, grid columns per breakpoint, nav pattern per breakpoint
9. **Component Catalog** — fixed template per component: description, anatomy, variants, props, states, a11y, responsive, do/don't
10. **Layout Patterns** — page compositions, fixed vs scrollable regions, reflow order
11. **Motion and Transitions** — duration tokens, easing, purpose categories, prefers-reduced-motion
12. **Accessibility Requirements** — touch targets, focus rings, color-independence, landmarks, live regions
13. **Content and Data Formatting** — unit formatting, number precision, date/time, no-data states
14. **Theming and Customization** — theme-able tokens, switching mechanism, what's NOT customizable
15. **Anti-Patterns and Common Mistakes** — explicit "never do this" list

### AI Parseability Notes
- Flat hierarchy (2 levels max)
- Imperative voice ("Use X" not "X should generally be used")
- Token names inline (grep-able)
- Fixed component templates (learn pattern once, extract any field)
- Do/Don't pairs (pattern-matchable)
- Machine-readable token tables
