---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-009: Design direction

## Context

Phase 3 (the dashboard SPA) needs a locked design direction so the SPA work has a contract and the companion ADRs ([ADR-022](ADR-022-theming-branding-mechanism.md), [ADR-023](ADR-023-light-dark-mode-mechanism.md), [ADR-024](ADR-024-page-taxonomy.md)) have a frame. User reactions to four design references and the Belchertown anti-reference are at [DESIGN-INSPIRATION-NOTES.md](../reference/DESIGN-INSPIRATION-NOTES.md).

Strategic posture: **the weewx audience comes first.** weewx users run their own stations to get rich data and want it surfaced — "modern minimalist" / Apple-Weather aesthetics are dumbed down for the masses and miss the mark. Belchertown's failure is cramming everything onto one page, not the data richness itself. Direction: retain all data, give it better homes, multi-page split.

## Options considered

| Option | Verdict |
|---|---|
| A. Modern minimalist (single-page, low data density) | Rejected — dumbs down the data weewx users come for. |
| B. Belchertown 2.0 (single-page wall-of-data, modernized typography) | Rejected — doesn't fix the "super busy" critique. |
| C. Multi-page card-based dashboard with icon-rail nav, hero imagery, high data density per page | **Selected.** |
| D. Tabbed single-page with collapsible sections | Rejected — loses deep-linking, browser history, mobile UX benefits. |
| E. Apple-Weather hero with small widgets below | Rejected — same dumbed-down critique as A. |

## Decision

Multi-page, card-based dashboard with icon-rail navigation, operator-uploadable hero imagery on the home page (with shipped default), high data density per page, three-tier information hierarchy, all three theme modes, restrained motion, mobile-first, WCAG 2.1 AA throughout.

### Navigation
- Icon-rail (left desktop, bottom mobile). Lucide icons. Labels visible on hover/focus; always-labeled also acceptable, configurable at setup.
- Active page indicated by background shift + accent line, ≥ 3:1 contrast.
- Skip-to-main-content link per [coding rules §5.3](../../rules/coding.md).

### Hero treatment (Now page only)
> **Reconciled 2026-05-30 — see [ADR-047](ADR-047-background-system.md).** The page **background** is
> now a global, condition-keyed *photographic* system (ADR-047: clear/cloudy/storm × day-night scene
> photos + on-glass rain/snow overlays, behind every page). For the **background/backdrop role**,
> ADR-047 supersedes this section's Now-page-only in-house-SVG default. The operator-upload + event-
> trigger model described below is **retained as future scope** for an optional foreground hero and
> for operator-replaceable backgrounds, not as the default backdrop. (This note keeps ADR-009 Accepted;
> the background decision lives in ADR-047.)
- **Default = a single in-house-authored SVG/vector graphic shipped with Clear Skies.** NOT photography. NOT locale-specific. Pre-tuned for WCAG AA against the overlay. Authored under the project license ([ADR-003](ADR-003-license.md)).
- **Operator-uploadable images replace the default.** Licensing-ownership acknowledgment required at upload (operator's risk, not the project's). Alt text required ([coding rules §5.5](../../rules/coding.md)). Format JPEG/PNG/WebP, ≤ 2 MB default ceiling, aspect ≥ 16:9.
- **Event-tied images.** Operator binds each upload to one or more triggers; the system picks the highest-priority match at render time. v0.1 trigger types: `default`, `active severe-weather alert (any|category)`, `weather condition (snow|rain|thunderstorm|clear|cloudy|fog)`, `date range`, `season (hemisphere-aware)`, `time-of-day`. Triggers AND-able; operator sets priority on overlap.
- **Fallback chain:** matched trigger → operator's `default`-tagged image → shipped hero-default.svg. Never blank.
- **Overlay legibility:** upload UI shows live preview with overlay rendered; AA contrast checked; darken-overlay slider offered if AA fails.
- Other pages have no hero by default. Operator opt-in elsewhere is Phase 6+.

### Page architecture
- Multi-page (browser history, deep-linkable). Not tabs.
- Cards are the composition unit. Each card maps to an entity from [ADR-010](ADR-010-canonical-data-model.md).
- Card behaviors: hide-able per operator; click-to-expand for tier-3 details; render-time self-hide when backing data has no non-null aggregate over the visible period.
- Full page list in [ADR-024](ADR-024-page-taxonomy.md).

### Information hierarchy (three tiers)
1. **Primary (always-visible, large, high-contrast):** headline number/state.
2. **Secondary (always-visible, moderate):** supporting data in tile bodies.
3. **Tertiary (click-to-expand or drill-in):** power-user details.

This is the answer to "all the data" + "not cluttered" — Belchertown crams every tier onto the home; Clear Skies tier-1 always-visible, tier-2 in tile bodies, tier-3 behind expansion.

### Typography
> **Superseded 2026-05-31** by the locked typography token spec at
> [design-tokens-typography.md](../design/design-tokens-typography.md). The original Inter
> direction below is preserved for history; the token spec is authoritative.

- ~~**Body + display: Inter** (https://rsms.me/inter/, OFL). Single family, weight variation only.~~
  **Three role-based families (LOCKED 2026-05-31):** **Manrope** (body, labels, card titles,
  station name — `--font-sans`), **Outfit** (large stat numerals — `--font-display`), **Lexend**
  (chart SVG axis/tick/data labels — `--font-chart`). All self-hosted via @fontsource woff2;
  weights 400/600/700. Card titles use semibold (600), NOT bold (700). Full role map + rem scale
  in the token spec.
- **Tabular figures (`font-feature-settings: "tnum"`)** on every live-updating numeric element so digits don't jump width.
- **CJK locales (ja, zh-CN, zh-TW)** fall back to system CJK fonts. No Noto-CJK bundle (~30 MB unjustifiable).
- ~~Tailwind default type scale and line heights unless a measured contrast/hierarchy problem requires deviation.~~ Replaced by role-named rem scale (`--text-stat-hero` through `--text-micro`) in the token spec.

### Color
- **Neutral foundation** (e.g. Tailwind `slate` or `zinc`, 9–11-step) in both light and dark themes.
- **One operator-picked accent** from a curated palette of 6 ([ADR-022](ADR-022-theming-branding-mechanism.md)) — no free-form picker (protects WCAG AA).
- **Semantic colors locked across themes:** red = alerts, amber = warnings, green = success, blue = info.
- **Color is never the only signal** ([coding rules §5.1](../../rules/coding.md)): pair with icon, label, position.
- **AQI scale uses the standard EPA palette** (green/yellow/orange/red/purple/maroon) — domain convention, not brandable.
- **8–12-color categorical chart-series palette** designed for legibility on both backgrounds; replaces ECharts defaults.
- **All three theme modes** ([ADR-023](ADR-023-light-dark-mode-mechanism.md)): light, dark, auto-by-sunrise-sunset, auto-by-OS-preference.
- **WCAG AA verified** for every palette pairing in both themes before the palette ships.
- Final hex values are a Phase 3 design task; this ADR locks direction only.

### Iconography
> **Superseded 2026-05-30** by [ADR-049](ADR-049-hero-weather-icons.md) (hero weather icons) and
> [ADR-050](ADR-050-utility-stat-nav-icons.md) (utility/stat/nav icons). Original direction below
> preserved for history; the two icon ADRs are authoritative.

- ~~**General UI:** Lucide ([ADR-002](ADR-002-tech-stack.md)). 2px stroke. 16/20/24 px.~~
  **Utility / stat / nav / alert:** Phosphor (regular) base + curated cross-pack exceptions
  (Tabler `uv-index`, Material `flood`, Carbon `tsunami`); 13 weather-alert glyphs. See
  [ADR-050](ADR-050-utility-stat-nav-icons.md).
- ~~**Weather:** Weather Icons by Erik Flowers (222-icon set, [ADR-002](ADR-002-tech-stack.md)).~~
  **Hero weather glyphs:** Material Symbols (filled), recolored Meteocons-style (gold sun, grey
  volumetric clouds, gold lightning, periwinkle moon) as inline SVG with gradient fills, all 29
  WMO codes. See [ADR-049](ADR-049-hero-weather-icons.md).
- ~~**Custom hardware/sensor icons** authored in Lucide style; no third icon library.~~
- Accessibility per [coding rules §5.5](../../rules/coding.md): `aria-label` on icon-only buttons, `aria-hidden="true"` on decorative icons paired with text.

### Charts
- **Engine: Recharts** ([ADR-002](ADR-002-tech-stack.md)). Originally ECharts; switched to Recharts during tech-stack finalization.
- **Sampling:** client-side LTTB data reduction for charts with > 1000 source points.
- **Accessibility:** `aria-label` on every chart container; screen-reader-only data-table fallback alongside. Recharts does not have ECharts' native `aria` keyboard navigation — keyboard tooltip access is a tracked Phase 3 task.
- Chart series palette matches the categorical palette above.

### Motion
- Restrained. No parallax, no scroll-driven animations.
- **Live data updates:** ~200 ms tween between old/new value (temperatures, wind compass, lightning state).
- **Page transitions:** none — instant route swaps.
- **`prefers-reduced-motion: reduce`:** all tweens disabled, instant updates.

### Mobile-first
- Non-negotiable. Designed mobile-first; desktop is the larger-screen extension.
- Layout reflow: multi-column desktop → single-column mobile.
- Tap targets ≥ 44 × 44 px (WCAG SC 2.5.5).
- No hover-only affordances.
- Bottom-nav on mobile vs. left-rail on desktop — single adaptive component.
- Verified on real iOS + Android devices, not just DevTools.

## Consequences

- Phase 3 dashboard scaffold can begin: routes, layout, navigation, card primitive, theme infrastructure are unblocked.
- Companion ADRs ([ADR-022](ADR-022-theming-branding-mechanism.md), [ADR-023](ADR-023-light-dark-mode-mechanism.md), [ADR-024](ADR-024-page-taxonomy.md)) consume this direction.
- Setup wizard scope ([ADR-027](ADR-027-config-and-setup-wizard.md)) collects: accent color choice, logo upload (light + optional dark), hero uploads with optional triggers, default theme mode, station name, lat/lon, altitude, hardware free-text. Each upload validates per [coding rules §5](../../rules/coding.md); licensing acknowledgment checkbox required.
- **Generic hero graphic** is a Phase 3 acceptance gate: single SVG (or light/dark pair), ~10–50 KB, in-house-authored, WCAG-AA-pre-tuned, non-locale-specific.
- **Event-trigger evaluation** is Phase 3 work; on-disk schema lands in `docs/contracts/hero-trigger-schema.md`.
- ~~Inter font self-hosted (no Google Fonts CDN; privacy preference, ~200 KB cost).~~ Superseded: Manrope + Outfit + Lexend self-hosted via @fontsource woff2 (see [design-tokens-typography.md](../design/design-tokens-typography.md)).
- Operator branding latitude: logo + hero + accent + theme mode + `custom.css` escape hatch ([ADR-022](ADR-022-theming-branding-mechanism.md)).

## Out of scope
- Final hex values; component-level spacing/radii — Phase 3 design pass.
- On-disk hero-trigger schema syntax — Phase 3 contract.
- The actual SVG of the generic hero graphic — Phase 3.
- Specific Lucide icons per route — picked when [ADR-024](ADR-024-page-taxonomy.md) routes are implemented.

## Amendment: 2026-06-02

### Desktop nav rail → auto-hide overlay

The permanent 64px left sidebar described in the Navigation section above is replaced with a
**floating auto-hide glass panel** that overlays content instead of consuming layout space.

**Behavior:**
- `position:fixed`, vertically centered, card-glass surface + `shadow-lg` + `rounded-xl`, `z-20`.
- Slides in/out with `opacity` + `transform` 200ms ease transition.
- **Auto-hides** after 30 seconds on mount or mouseleave; timer cleared on mouseenter or pin.
- **Grab bar** (`<button>` pill, `w-1 h-10`) fixed at `left:0`, visible only when rail is hidden;
  `aria-label`/`aria-expanded` managed.
- **Pin toggle** (Phosphor PushPin / PushPinSlash) at rail top; persists to
  `localStorage('clearskies.nav.pinned')`; `aria-label` changes with state.
- `app-layout.tsx`: NavRail moved outside the flex row so the content column is full-width; rail
  overlays rather than displacing content.

**Mobile bottom-nav is unchanged.** The ≤5-slot bottom nav and More overflow sheet remain as
described in [ADR-024](ADR-024-page-taxonomy.md).

**Why:** The permanent sidebar consumed 64px of horizontal space on every page, reducing the
usable grid width. Operator review (2026-06-02) decided the navigation is infrequently used after
initial page selection and should not permanently occupy screen real estate. The auto-hide +
pin pattern preserves discoverability (grab bar always visible) while reclaiming full content
width.

**Commits:** dashboard `eeaf00b` (feat), `616c548` (a11y remediation F1–F3).

## References
- Related: [ADR-002](ADR-002-tech-stack.md), [ADR-003](ADR-003-license.md), [ADR-010](ADR-010-canonical-data-model.md), [ADR-011](ADR-011-multi-station-scope.md), [ADR-022](ADR-022-theming-branding-mechanism.md), [ADR-023](ADR-023-light-dark-mode-mechanism.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-026](ADR-026-accessibility-commitments.md), [ADR-027](ADR-027-config-and-setup-wizard.md).
- Walk: [DESIGN-INSPIRATION-NOTES.md](../reference/DESIGN-INSPIRATION-NOTES.md), [BELCHERTOWN-CONTENT-INVENTORY.md](../reference/BELCHERTOWN-CONTENT-INVENTORY.md), [CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Coding rules accessibility: [rules/coding.md §5](../../rules/coding.md).
