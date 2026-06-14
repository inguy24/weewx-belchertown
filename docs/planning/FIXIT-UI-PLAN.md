# FIXIT-UI-PLAN — Mobile responsive fixes and UI polish

**Goal:** Fix all mobile layout, responsive design, and UI polish issues identified during manual testing of the Clear Skies dashboard and wizard. Every page must be usable on a phone-sized viewport (~350-400px) without content clipping, overflow, or broken navigation.

**Status:** Not started.

**Source:** [FIXIT-BACKLOG.md](FIXIT-BACKLOG.md) items FIX-001, FIX-009, FIX-010, FIX-012–027.

**Repos involved:**
- `weewx-clearskies-dashboard` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`) — all mobile responsive fixes
- `weewx-clearskies-stack` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-stack`) — wizard fixes (FIX-001, FIX-009, FIX-010)

**Dev/test environment:** `weather-dev` LXD container. Dashboard source at `/home/ubuntu/repos/weewx-clearskies-dashboard`. Wizard source at `/home/ubuntu/repos/weewx-clearskies-stack`. Deploy via `scripts/redeploy-weather-dev.sh` (full) or `scripts/sync-to-weather-dev.sh` (source-only).

---

## Orientation — read before executing any task

**Load these before every session:**
1. [CLAUDE.md](../../CLAUDE.md) — domain routing, operating rules
2. [rules/coding.md](../../rules/coding.md) — code standards, accessibility requirements
3. [rules/clearskies-process.md](../../rules/clearskies-process.md) — process discipline, agent orchestration
4. [docs/ARCHITECTURE.md](../ARCHITECTURE.md) — system architecture (read first, before ADRs)
5. This plan — current task status and context

**Git safety:** Agents do NOT push. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No worktree isolation for implementation — all work in the primary local checkout. Coordinator commits after QC.

**QC model:** Opus provides QC at every task. QC is NOT "is the code well-written" — it is:
- Does the fix do what the task says it should do?
- Does it comply with this plan, ARCHITECTURE.md, and relevant ADRs?
- Does it introduce regressions on other viewports or pages?
- Is the acceptance criteria met (verified by running the check, not trusting the agent's claim)?

**No deferrals.** Every task in this plan is mandatory. Agents do not get to say "deferred to a future round." If a task is blocked, the agent reports the blocker and the coordinator resolves it. The task does not close until acceptance criteria are met.

---

## Root cause analysis

Codebase exploration identified the single root cause behind the majority of mobile card issues:

**The grid forces a fixed 176px row height at ALL breakpoints, including mobile.**

In `src/components/layout/grid.tsx` line 49:
```
auto-rows-[var(--card-row)]
```
where `--card-row: 11rem` (176px, defined in `src/index.css` line 18).

The grid is responsive in column count (`grid-cols-1 md:grid-cols-2 lg:grid-cols-4` at grid.tsx:45) but NOT in row height. On mobile, every card gets one column (good) but is still forced to 176px tall (bad). Combined with `overflow-hidden flex-1 min-h-0` on CardContent (`src/components/ui/card.tsx` line 131), any content taller than 176px is silently clipped.

**The fix:** Make auto-rows responsive: `auto-rows-[auto] md:auto-rows-[var(--card-row)]` — content-driven height on mobile, fixed 176px on md+ desktop.

**Complication:** Chart cards need a minimum height for the canvas element to render. Charts inside auto-height cards would collapse to zero. Solution: chart cards get an explicit `min-h-[var(--card-row)]` class so they maintain a usable minimum on mobile while still being able to grow taller than 176px if content demands it.

**What this single fix resolves:** FIX-012 (current conditions card clips chart), FIX-016 (title cards oversized — they'll shrink to content), FIX-019 (forecast card sizing), FIX-024 (records cards force scroll), FIX-025 (reports selection card), FIX-026 (about page cards), FIX-027 (legal page cards).

### Other structural findings

**Mobile bottom nav (nav-rail.tsx:573-623):** Fixed at viewport bottom, `z-30`, 56px height, always present on mobile (`md:hidden` hides it on desktop only). FIX-015 (nav disappearing) is unexpected given this code — needs on-device verification to identify the actual cause.

**Footer (footer.tsx:143-202):** Already a flow element (not fixed/sticky), uses `mt-auto` in flex parent. Has `pb-20` (80px) on mobile for bottom nav clearance. FIX-021 (footer mid-page on Charts) is likely page-specific, not a global footer bug.

**Desktop nav rail (nav-rail.tsx:498-517):** Fixed left panel, `z-20`, auto-hides after 4 seconds when unpinned. Desktop only — not relevant to mobile fixes.

**Forecast page:** Already overrides grid rows with `md:auto-rows-[auto]` on the Grid element (forecast.tsx:34), but this only applies at md+ — mobile still gets the global 176px. DailyColumns.tsx already has `getShortDayName()` logic — needs verification that it activates on mobile.

**Sun & Moon card:** Already has mobile stacking layout (3-column desktop → single-column mobile). FIX-022 may be partially addressed already.

**Hourly strip:** Has custom webkit-scrollbar styling (HourlyStrip.tsx:266-286) but mobile browsers often hide custom scrollbars. The scroll affordance (FIX-017) is still needed.

**Chart library:** Recharts. No existing fullscreen/expand pattern — chart fullscreen (FIX-020) is a new component.

**Card footprint system (card.tsx:23-39):** tile (1-col), wide (2-col at md+), panel (3-col at lg+), full (4-col at lg+). Row span support: rowSpan=1 (11rem), rowSpan=2 (22rem+gap). Row spans reference `--card-row` — the mobile auto-rows change makes row spans meaningless on mobile (auto height), which is fine since mobile is single-column anyway.

---

## Phase 0 — Research and verification

Verify the reported issues on actual hardware/browser before implementing. Confirm root causes. Prevent fixing things that aren't broken and missing things that are.

### T0.1 — Screenshot every page on weather-dev at mobile width

- **Owner:** `Explore` agent (Sonnet)
- **Dep:** None
- **Do:**
  1. Load the Clear Skies dashboard on `weather-dev` (weather-test.shaneburkhardt.com or equivalent URL) at 375px viewport width in a browser or headless Chrome.
  2. Screenshot every page: Home (Now), Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal.
  3. For each page, document: (a) Is the bottom nav visible? (b) Is any card content clipped? (c) Does the footer appear in the correct position? (d) Are there any overflow or overlap issues?
  4. For the Forecast page specifically: Are 7-day day names abbreviated or full? Is the hourly strip scrollbar visible?
  5. For the Charts page specifically: Where does the footer appear? Are chart axis labels readable?
  6. For the Almanac page: Is the Sun & Moon card stacked or side-by-side?
- **Accept:** Screenshot set with per-page annotations confirming or denying each reported issue. Each annotation references the relevant FIX-NNN item. Issues confirmed as real are marked "CONFIRMED." Issues that appear already fixed are marked "ALREADY HANDLED — [reason]."
- **QC:** Opus reviews the screenshot annotations and confirms the assessment is accurate. Spot-checks 3+ pages by loading them independently.

### T0.2 — Verify auto-rows root cause in DevTools

- **Owner:** `Explore` agent (Sonnet)
- **Dep:** T0.1
- **Do:**
  1. On weather-dev at 375px width, open DevTools on a page with clipped cards (e.g., Records or About).
  2. On the grid container element, override the CSS: change `grid-auto-rows: 11rem` to `grid-auto-rows: auto`.
  3. Document: Do clipped cards now expand to show their full content? Do chart cards collapse to zero height? Does the page layout remain usable?
  4. Also test: add `min-height: 11rem` to a chart-containing card — does the chart still render at a usable size?
  5. Repeat on 3+ pages to confirm the fix is consistent.
- **Accept:** Written confirmation that the auto-rows override resolves card clipping on mobile, with documentation of any side effects (chart collapse, layout breakage). Identifies which cards need `min-height` protection.
- **QC:** Opus verifies the DevTools override was tested on at least 3 pages and that side effects are documented.

### T0.3 — Investigate nav bar disappearance (FIX-015)

- **Owner:** `Explore` agent (Sonnet)
- **Dep:** T0.1
- **Do:**
  1. Using T0.1 screenshots, identify which pages have the bottom nav missing.
  2. If missing on any page: inspect the DOM on that page at mobile width. Is the `<nav>` element present in the DOM? Is it visible (not `display:none` or `opacity:0`)? What z-index does it have? Is anything rendering above it?
  3. Check: does the page use the standard `AppLayout` wrapper? Or does it have a custom layout that omits the nav?
  4. Check: is there a CSS rule on any page that overrides the bottom nav's `fixed` positioning or `z-30`?
  5. If the bottom nav IS visible on all pages: document this as "NOT REPRODUCIBLE" and note the test conditions. The issue may be device-specific, browser-specific, or intermittent.
- **Accept:** Root cause identified (specific CSS rule, missing component, or z-index conflict) with file:line reference, OR documented as not reproducible with test conditions noted.
- **QC:** Opus reviews the diagnosis. If root cause found, verifies the file:line reference is accurate. If not reproducible, accepts but keeps FIX-015 open for monitoring.

### T0.4 — Audit wizard CSS and template structure

- **Owner:** `Explore` agent (Sonnet)
- **Dep:** None (parallel with T0.1-T0.3)
- **Do:**
  1. Read the wizard's `layout.html` base template and CSS files in `repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/`. Identify the CSS rules for checkbox labels and prompt text — what color values, what background, what font size.
  2. Compute the contrast ratios for checkbox label text against its background, and prompt text against its background. Use the WCAG formula: `(L1 + 0.05) / (L2 + 0.05)` where L1 is the lighter relative luminance.
  3. Read `step_appearance.html`. List every fieldset and every field in order, grouped by concern (branding, social, analytics, privacy/legal, seismic).
  4. Read the step routing mechanism — how are steps numbered, how does next/back navigation work, where is the step count defined?
  5. Read the apply step — what files does it write, what's the write path, how are errors surfaced?
  6. SSH to weather-dev and check: what user does the wizard process run as? What are the permissions on `/etc/weewx-clearskies/`? Run `ls -la /etc/weewx-clearskies/` and `ps aux | grep clearskies`.
- **Accept:** Written summary with: (a) checkbox/prompt text color hex values and computed contrast ratios vs WCAG AA thresholds, (b) complete field inventory for step_appearance.html grouped by concern, (c) step routing mechanism with file:line, (d) apply step write path and error handling with file:line, (e) wizard process user and directory permissions from weather-dev.
- **QC:** Opus verifies contrast ratio math (re-computes from the reported hex values) and spot-checks 2+ template findings against the actual files.

---

## Phase 1 — Global mobile foundation

High-leverage CSS changes that fix multiple backlog items at once. Each task targets one change point in the component system.

**Dep:** Phase 0 complete. T0.1 confirms which issues are real. T0.2 confirms the auto-rows fix works. T0.3 provides the nav bar diagnosis.

### T1.1 — Grid auto-rows mobile override

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T0.2 (confirms the fix works)
- **Backlog:** FIX-012, FIX-016, FIX-019, FIX-024, FIX-025 (selection card), FIX-026, FIX-027
- **Do:**
  1. In `src/components/layout/grid.tsx` line 49, change the auto-rows class from:
     ```
     auto-rows-[var(--card-row)]
     ```
     to:
     ```
     auto-rows-[auto] md:auto-rows-[var(--card-row)]
     ```
     This makes rows content-driven on mobile (<768px) and fixed 176px on desktop (≥768px).
  2. In `src/components/ui/card.tsx`, add a `min-h-[var(--card-row)]` class to cards that contain charts (identified by T0.2 as needing minimum height protection). This prevents chart canvases from collapsing to zero on mobile. The `min-h` allows growth beyond 176px but prevents collapse below it.
  3. In `src/components/ui/card.tsx` line 131, evaluate whether `overflow-hidden` on CardContent should change to `overflow-visible` on mobile. If auto-rows is now `auto`, overflow-hidden may no longer clip content (because the row grows to fit). Test this — if content is still clipped despite auto-rows, change to `md:overflow-hidden overflow-visible`. If auto-rows alone resolves clipping, leave overflow-hidden (it still serves a purpose on desktop).
  4. Verify that `rowSpan` behavior is acceptable on mobile. With auto-rows, `row-span-2` is meaningless (auto × 2 = auto). This is fine — mobile is single-column, and all content is visible via auto-height. Desktop rowSpan behavior is unchanged because `auto-rows-[var(--card-row)]` still applies at md+.
- **Accept:**
  - On mobile (375px width): cards expand to fit their content. No card clips text, tables, or charts. No card has internal scrollbars for its primary content.
  - On desktop (1280px width): cards maintain fixed 176px row height. Uniform grid appearance is preserved. No visual regression.
  - Chart-containing cards render their charts at a usable minimum size on mobile (not collapsed).
  - Verified on at least 6 pages: Home, Forecast, Records, Reports, About, Legal.
- **QC:** Opus loads 4+ pages at both 375px and 1280px width. Confirms: mobile cards auto-size, desktop cards are uniform, chart cards render correctly. Screenshots as evidence.

### T1.2 — Fix navigation bar (FIX-015)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T0.3 (root cause diagnosis)
- **Backlog:** FIX-015
- **Priority:** CRITICAL
- **Do:**
  1. Implement the fix identified by T0.3. If z-index conflict: set the conflicting element's z-index below z-30. If component not rendering: fix the routing/layout to include the nav. If CSS override: remove or scope the override. If not reproducible: add a defensive `z-30` assertion test and document the investigation.
  2. Regardless of root cause: verify the bottom nav is present and interactive on every page at 375px width — Home, Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal.
  3. Verify the "More" sheet (dots menu) opens and closes correctly on every page.
- **Accept:**
  - Bottom nav is visible and interactive on every page at 375px width.
  - Tapping each nav item navigates to the correct page.
  - "More" sheet opens, shows overflow items (Seismic, Records, Reports, About, Legal), and closes.
  - Verified on all 9 pages.
- **QC:** Opus loads every page at 375px and confirms the bottom nav is present, tappable, and functional. Tests the "More" sheet on 2+ pages.

### T1.3 — Radar map z-index containment (FIX-014)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.2 (nav bar fix confirms the z-index stack is correct)
- **Backlog:** FIX-014
- **Do:**
  1. Find the radar card component in the dashboard (likely in `src/components/` or `src/routes/`). Identify the Leaflet map container element.
  2. On the radar card's outermost wrapper (not inside the Leaflet container), add `position: relative` and a z-index lower than the nav's z-30. Example: `className="relative z-0"`. This creates a stacking context that contains Leaflet's internal z-indices (which can be z-400+) within the card.
  3. Do NOT modify Leaflet's internal CSS or pane z-indices. The containment approach means Leaflet can use whatever z-indices it wants internally — they're all scoped to the card's stacking context.
  4. Verify: map tiles, zoom controls (+/- buttons), attribution, and any overlays (weather radar layers) still render correctly within the card.
- **Accept:**
  - Scrolling the page on mobile: the radar map stays behind the bottom nav and behind any sticky/fixed header elements. It never overlaps navigation.
  - The map is fully functional within the card: tiles load, zoom controls work, overlays render.
  - No z-index regressions on other cards or components on the same page.
- **QC:** Opus loads the home page (or whichever page has the radar card) at 375px, scrolls past the radar card, and confirms it does not overlap the bottom nav. Verifies map is interactive.

### T1.4 — Footer positioning verification and fix (FIX-021)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T0.1 (screenshots confirm which pages have footer issues)
- **Backlog:** FIX-021
- **Do:**
  1. Using T0.1 findings, identify which pages have the footer in the wrong position (floating mid-page, overlapping content, etc.).
  2. The footer is a flow element (`mt-auto` in flex parent, `pb-20` on mobile) — it should scroll with content and appear after the last card. If it's floating mid-page on the Charts page, the Charts page's layout is likely breaking the flex parent relationship. Investigate: does the Charts page use a different layout wrapper? Does it have an intermediate `overflow: hidden` or `height: 100%` container that prevents the flex parent from working?
  3. Fix the Charts page (and any other affected pages) so the footer's `mt-auto` works correctly: the footer pushes to the end of content, below all cards.
  4. Verify: the main content area has `pb-24` (96px) bottom padding to clear the 56px bottom nav, so the footer and last card are fully scrollable into view.
- **Accept:**
  - Footer appears below the last card on every page and is only visible when scrolled to the bottom.
  - The last card on every page is fully visible when scrolled to the bottom (not hidden behind the bottom nav).
  - Verified on all 9 pages, with special attention to Charts (the reported worst offender).
- **QC:** Opus loads Charts page and 2 other pages at 375px, scrolls to bottom, confirms footer is below content and last card is fully visible.

### T1.5 — Desktop regression check

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1, T1.2, T1.3, T1.4
- **Do:**
  1. Load every page at 1280px (lg breakpoint) and 768px (md breakpoint).
  2. Verify: uniform card grid is intact (176px row height), cards align in 2-col (md) and 4-col (lg) grids, no overflow or clipping, nav rail functions correctly, footer is at the bottom.
  3. Run `npm run build` (Vite production build) and confirm zero errors.
  4. Run the existing test suite (if any: `npm test` or `npx vitest`) and confirm no regressions.
- **Accept:**
  - Desktop layout at md and lg breakpoints is visually identical to pre-Phase-1 state.
  - `npm run build` completes with zero errors.
  - Test suite passes (or test suite doesn't exist, documented as such).
- **QC:** Opus loads 3+ pages at 1280px and confirms uniform grid. Verifies build output.

---

## Phase 2 — Per-page mobile fixes

Page-specific issues not resolved by the Phase 1 global fixes. Each task targets one page.

**Dep:** Phase 1 complete and verified.

### T2.1 — Forecast page: 7-day day name abbreviations (FIX-018)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Backlog:** FIX-018
- **Do:**
  1. Read `src/components/forecast/DailyColumns.tsx` lines 155-210. The component already has `getDayName()` and `getShortDayName()` functions. Determine: is `getShortDayName()` used on mobile? If yes and day names still overlap, the abbreviations aren't short enough. If no, add a responsive breakpoint check.
  2. If `getShortDayName()` returns full names like "Saturday": change to 3-letter abbreviations ("Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"). Keep "Today" as-is.
  3. If `getShortDayName()` already returns 3-letter abbreviations but isn't being called on mobile: add a responsive check — use `getShortDayName()` below md breakpoint, `getDayName()` at md+. This can be done via a `useMediaQuery` hook, a responsive CSS class (`hidden md:block` / `block md:hidden`), or the component's existing `expandable` prop.
  4. Verify: all 7 day columns are legible at 375px with clear separation between names. No text overlap.
- **Accept:**
  - At 375px: day names show as 3-letter abbreviations ("Today", "Sat", "Sun", etc.) with visible spacing between each column.
  - At 768px+: full day names displayed as before.
  - Date labels (Jun 12, Jun 13, etc.) are unaffected.
- **QC:** Opus loads Forecast page at 375px and confirms all 7 day labels are fully readable with no overlap.

### T2.2 — Forecast page: hourly card content verification (FIX-019 remnant)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Backlog:** FIX-019
- **Do:**
  1. After T1.1 (auto-rows fix), load the Forecast page at 375px. Verify both forecast cards (hourly and 7-day) show all content within card boundaries — no clipping, no overflow past the card background/border.
  2. The hourly card has a temperature trend line chart at the bottom. Verify it's fully visible, not clipped.
  3. The 7-day card has high/low temperatures and weather icons per day. Verify all visible.
  4. If any content still overflows the card edge (renders outside the card background), fix the specific card's overflow or padding.
- **Accept:**
  - Both forecast cards at 375px: all content visible within card boundaries. Temperature trend line fully visible. High/low temps and icons fully visible.
  - No content bleeds past the card's visual border.
- **QC:** Opus loads Forecast page at 375px and confirms both cards are fully contained.

### T2.3 — Charts page: tab labels, empty card, axis optimization (FIX-020)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1, T1.4
- **Backlog:** FIX-020 (partial — A, B, C, D; fullscreen is T3.1)
- **Do:**
  1. **Tab labels:** Find the chart tab component. At 375px, labels like "Average Climate" and "Last 24 Hours/Week/Month" truncate. Fix by either: (a) shortening labels on mobile ("Avg Climate", "Last 24h/Wk/Mo"), or (b) making the tab strip horizontally scrollable with the scroll affordance from T3.2. Option (a) is simpler and preferred if labels fit.
  2. **Empty card:** At 375px, a card under the tab selector renders as empty whitespace. Investigate: is the chart not rendering? Is the card container too small for the chart to initialize? Is there a data loading issue? Fix the underlying cause.
  3. **Chart axis optimization:** For charts that render on mobile (after fixing the empty card), optimize for narrow viewport: reduce axis font sizes to `--text-micro` (0.7rem) or `--text-label` (0.75rem), use abbreviated axis labels (single-letter months "J F M A M J J A S O N D", compact number ticks "60 70 80" without units on every tick), tighten chart margins/padding. Recharts supports `tick={{ fontSize: 10 }}` and custom tick formatters.
  4. Dual-axis charts stay combined — do NOT split them. Both y-axes render in the same chart. Right-axis label ("Average Monthly Rain Total") should abbreviate on mobile ("Avg Rain (in)").
- **Accept:**
  - Tab labels fully readable at 375px, no truncation.
  - No empty/blank cards — all charts render content.
  - Chart axis labels readable at 375px — no overlap, no truncation of critical information.
  - Dual-axis charts remain combined.
  - No desktop regression.
- **QC:** Opus loads Charts page at 375px, switches between tabs, confirms all charts render with readable axes. Loads at 1280px and confirms no desktop changes.

### T2.4 — Almanac page: per-card mobile layout verification (FIX-022)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Backlog:** FIX-022
- **Do:**
  1. Load Almanac page at 375px. Verify each card:
     - **Sun & Moon card:** Exploration found this already has mobile stacking (3-col → 1-col). Verify: arc graphic is on top at full width, sun info table below, moon info table below that. If the layout is correct, mark as "ALREADY HANDLED." If not (e.g., still side-by-side, or in wrong order), fix the responsive breakpoint.
     - **Planet Outlook card:** Check layout. Per user direction: each planet should stack vertically (own row/block) on mobile. If currently side-by-side or horizontally scrolling, change to vertical stack at mobile breakpoint. The visibility timeline chart should render full-width below the planet list.
     - **Solar Events / Lunar Events / Meteor Shower cards:** Per user direction: all content stacked vertically on mobile. If currently using horizontal scroll or side-by-side layout, change to vertical stack. Exploration found MeteorShowerCard.tsx:433 uses `overflow-x-auto` — this horizontal scroll should become vertical stacking on mobile.
  2. The climatological values chart gets the same axis optimization treatment as T2.3.
- **Accept:**
  - Sun & Moon: arc → sun → moon stacked vertically on mobile. All readable.
  - Planet Outlook: planets stacked vertically, timeline chart full-width below.
  - Event cards: all events stacked vertically, no horizontal scrolling needed on mobile.
  - Climatological chart: axes readable at 375px.
  - Desktop layout unchanged.
- **QC:** Opus loads Almanac page at 375px and verifies each card matches the layout spec above.

### T2.5 — Seismic page: padding and subtitle wrapping (FIX-023)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1, T1.4
- **Backlog:** FIX-023
- **Do:**
  1. Load Seismic page at 375px. After T1.1 (auto-rows) and T1.4 (footer fix), verify the earthquake list card is fully scrollable.
  2. Check card padding and margins — compare spacing between cards on the Seismic page vs other pages (e.g., Home, Forecast). If inconsistent, align to the same `gap-[var(--gap-grid)]` (1rem) used globally.
  3. The title card subtitle ("Provider: USGS | Radius: 200 km | Min ...") truncates via `truncate` class on the `<p>` element in PageHeaderCard (page-header-card.tsx line 106). On mobile, this metadata should wrap instead of truncate. Add a responsive override: `truncate md:truncate` → `md:truncate` (remove truncate on mobile, allowing natural text wrapping). Or use `line-clamp-2` on mobile to allow 2 lines.
- **Accept:**
  - Earthquake list fully visible when scrolled to bottom.
  - Card spacing matches other pages.
  - Subtitle wraps on mobile (2 lines if needed) instead of truncating.
- **QC:** Opus loads Seismic page at 375px and verifies all three fixes.

### T2.6 — Reports page: NOAA table rendering and download emphasis (FIX-025)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1, T3.3 (sticky-column table component)
- **Backlog:** FIX-025
- **Do:**
  1. Investigate why report data doesn't render on mobile — only download controls are visible. Read `src/routes/reports.tsx` lines 150-400. Is the table conditionally rendered based on viewport? Is it hidden behind a component that doesn't display on mobile? Is it a data loading issue?
  2. Fix the rendering so the NOAA table is visible on mobile.
  3. Wrap the NOAA table in the sticky-column table component from T3.3 — first column (date/time) stays fixed while the rest scrolls horizontally.
  4. Move download controls ABOVE the table. Make them visually prominent — larger buttons, descriptive labels ("Download CSV", "Download PDF"). Add a subtle note: "Full table best viewed in spreadsheet or on desktop."
  5. Selection/filter card: verify T1.1 resolved auto-sizing (should have — it's a standard card). If not, fix specifically.
- **Accept:**
  - NOAA table renders and is visible on mobile.
  - Table scrolls horizontally with sticky first column.
  - Download buttons are above the table, visually prominent.
  - Selection card auto-sizes (no internal scroll).
- **QC:** Opus loads Reports page at 375px, selects a report, confirms table renders with horizontal scroll and sticky first column.

### T2.7 — Footer content layout (FIX-013)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.4 (footer positioning fixed first)
- **Backlog:** FIX-013
- **Do:**
  1. In `src/components/layout/footer.tsx`, the footer content layout on mobile is currently `flex flex-col gap-2` (footer.tsx:155). Change the mobile layout to:
     - **Line 1:** Copyright text left-justified, Clear Skies logo right-justified — same line. Use `flex flex-row justify-between items-center` for the first row.
     - **Line 2:** Social media icons center-justified below. Use `flex flex-row justify-center` for the second row.
  2. This may require restructuring the footer's DOM: group copyright + logo into a flex row div, group social icons into a separate centered div.
  3. Desktop layout (`md:flex-row md:flex-wrap md:justify-between`) should remain unchanged.
  4. Verify the footer renders correctly on all pages.
- **Accept:**
  - At 375px: copyright left, Clear Skies logo right on line 1. Social icons centered on line 2.
  - At 768px+: desktop layout unchanged.
  - Consistent across all pages.
- **QC:** Opus loads 3+ pages at 375px and confirms footer layout matches the spec.

### T2.8 — Remaining page verification (FIX-024, FIX-026, FIX-027 remnants)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Backlog:** FIX-024, FIX-026, FIX-027
- **Do:**
  1. After T1.1, load Records, About, and Legal pages at 375px.
  2. Verify: no card has internal scrolling. All text fully visible. All content within card boundaries.
  3. If any card still has internal scroll or clipping that T1.1 didn't resolve, fix it specifically (likely an individual card with its own `max-height` or `overflow` override that overrides the global fix).
- **Accept:**
  - Records: no internal scrolling on any record card. Cards sized to content.
  - About: no internal scrolling. All text visible.
  - Legal: no internal scrolling. Full legal text readable.
- **QC:** Opus loads all three pages at 375px and confirms no internal scrollbars on any card.

---

## Phase 3 — New components

Features that don't exist yet and require design + implementation. These are reusable components applied across multiple pages.

**Dep:** Phase 1 complete. Some Phase 2 tasks depend on Phase 3 components (T2.6 depends on T3.3).

### T3.1 — Chart fullscreen component (FIX-020 fullscreen)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1 (charts rendering on mobile first)
- **Backlog:** FIX-020 (fullscreen portion)
- **Do:**
  1. Create a new reusable component `src/components/ui/chart-fullscreen.tsx` (or similar path following existing conventions). This component wraps any chart card content and provides a tap-to-fullscreen affordance.
  2. **Affordance:** Add an expand icon (Phosphor `ArrowsOut` or similar) in the card header area. Subtle but visible. On tap, opens the fullscreen overlay.
  3. **Overlay:** Fixed-position overlay covering the entire viewport (`fixed inset-0 z-50 bg-background`). Renders the chart at full viewport width and height (minus padding for the close button). Close button (Phosphor `X`) in the top-right corner. Tap outside the chart or press Escape also closes.
  4. **The chart itself:** The same Recharts component renders in both the card (summary) and the fullscreen (detail). The fullscreen version gets more generous margins, larger font sizes, and no abbreviation on axis labels — the full "Average Monthly Rain Total (in)" label fits at viewport width.
  5. **Animation:** Simple fade-in/fade-out (200ms opacity transition). No complex transforms.
  6. **Body scroll lock:** When fullscreen is open, prevent background scroll (set `overflow: hidden` on `<body>` or use a portal).
  7. Apply the fullscreen affordance to all chart cards on: Charts page (all tabs), Almanac page (climatological values chart, planet timeline).
- **Accept:**
  - Expand icon visible on every chart card at 375px.
  - Tapping expand opens fullscreen overlay with chart at full viewport size.
  - Close button, tap-outside, and Escape all dismiss the overlay.
  - Background does not scroll while overlay is open.
  - Chart renders correctly in both card (summary) and fullscreen (detail) contexts.
  - Verified on Charts page and Almanac page.
  - No desktop regression.
- **QC:** Opus loads Charts page at 375px, taps the expand icon, verifies fullscreen chart renders, closes via each method (button, tap-outside, Escape). Repeats on Almanac.

### T3.2 — Horizontal scroll affordance component (FIX-017)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Backlog:** FIX-017
- **Do:**
  1. Create a reusable CSS-only scroll affordance. This can be a utility component `src/components/ui/scroll-fade.tsx` or a CSS class applied to scrollable containers.
  2. **Mechanism:** A gradient overlay on the trailing (right) edge of a horizontally-scrollable container. Uses a pseudo-element or an absolutely-positioned div with `pointer-events: none` and a linear-gradient from `transparent` to the card's background color.
  3. **Show/hide logic:** The fade is visible when there's content to scroll to the right. When the user scrolls to the end, the fade disappears. Implement via: (a) CSS-only using `scroll-snap` + `:last-child` intersection, or (b) a lightweight JS scroll event listener that checks `scrollLeft + clientWidth >= scrollWidth - threshold` and toggles a class.
  4. Apply to: hourly forecast strip (HourlyStrip.tsx), planet timeline (PlanetTimelineCard.tsx), meteor shower list (MeteorShowerCard.tsx), and any other horizontally-scrollable container identified in Phase 0.
  5. The existing webkit-scrollbar styling in HourlyStrip.tsx (lines 266-286) can remain — the fade affordance supplements it, it doesn't replace it. On mobile browsers that hide custom scrollbars, the fade is the primary affordance.
- **Accept:**
  - On first load at 375px: a subtle gradient fade is visible on the right edge of scrollable containers, indicating more content.
  - After scrolling to the end: the fade disappears.
  - The fade does not interfere with touch scrolling (pointer-events: none).
  - Verified on: hourly forecast, planet timeline, meteor showers.
- **QC:** Opus loads Forecast page at 375px, confirms fade is visible on hourly strip, scrolls to end, confirms fade disappears. Checks Almanac page planet timeline.

### T3.3 — Sticky-column table component (FIX-025 table)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None (can parallel with other Phase 3 tasks)
- **Backlog:** FIX-025 (table portion)
- **Do:**
  1. Create a reusable component `src/components/ui/sticky-table.tsx` that wraps an HTML `<table>` and provides horizontal scrolling with a sticky first column.
  2. **Container:** `overflow-x: auto` wrapper div with the scroll affordance from T3.2.
  3. **Sticky first column:** Apply `position: sticky; left: 0; z-index: 1; background: inherit` to all `<th>` and `<td>` in the first column. The background must be opaque (not transparent) so scrolling content doesn't show through.
  4. **Table styling:** Inherit the card's text styles. Compact padding for mobile (`px-2 py-1`). Alternating row backgrounds for readability.
  5. This component is used by T2.6 (Reports page) to wrap the NOAA table.
- **Accept:**
  - A table with 8+ columns scrolls horizontally on mobile.
  - The first column stays fixed on the left while other columns scroll.
  - The fixed column has an opaque background (no bleed-through).
  - The scroll affordance (fade) indicates more content to the right.
- **QC:** Opus renders a test table with 10 columns at 375px and verifies sticky column behavior.

---

## Phase 4 — Wizard fixes

Separate codebase (`weewx-clearskies-stack`), independent of dashboard phases. Can run in parallel with dashboard Phases 2-3.

**Dep:** T0.4 complete (wizard audit findings).

### T4.1 — WCAG contrast fix (FIX-001)

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T0.4 (contrast ratio findings)
- **Backlog:** FIX-001
- **Do:**
  1. Using T0.4 findings, identify all checkbox label and prompt text CSS rules that fail WCAG 2.1 AA contrast ratios (4.5:1 for normal text ≤18px, 3:1 for large text >18px or bold >14px).
  2. Update the color values to meet AA minimums. Use the existing background color as the anchor — adjust text/foreground colors to achieve sufficient contrast. Prefer darker text on light backgrounds rather than changing backgrounds (which could break the wizard's visual design).
  3. Apply to ALL wizard steps, not just the EULA step. The EULA step is the worst offender but the fix should be global (update the CSS class, not individual elements).
  4. Compute the new contrast ratios and include them in the commit message as evidence.
- **Accept:**
  - All checkbox labels and prompt text across all wizard steps meet WCAG AA contrast: ≥4.5:1 for normal text, ≥3:1 for large text.
  - Contrast ratios computed and documented (hex values + computed ratio for each affected text class).
  - Visual appearance remains consistent with the wizard's design language (no jarring color changes).
- **QC:** Opus re-computes contrast ratios from the updated hex values using the WCAG relative luminance formula. Confirms all ratios meet AA thresholds.

### T4.2 — Split wizard Appearance step into focused steps (FIX-009)

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T0.4 (field inventory, step routing mechanism)
- **Backlog:** FIX-009
- **Do:**
  1. Using T0.4's field inventory and step routing findings, split step 11 ("Appearance") into 3 new steps:

     **Step A — Appearance & Branding:**
     - Site title, copyright entity
     - Logos (light + dark, each with file upload + URL), favicon (file upload + URL), logo alt text
     - Accent color, theme mode, custom CSS URL
     - Social media links (Facebook, Twitter/X, Instagram, YouTube)
     - This is the "how your site looks" step.

     **Step B — Privacy, Legal & Analytics:**
     - Google Analytics measurement ID (this is a privacy decision — it triggers cookie consent)
     - Visitor region selection (determines which privacy laws apply)
     - Custom Terms of Use — **replace the markdown textarea with a file upload** accepting .html, .md, .txt, .rtf. Detect format from file extension. Convert to HTML server-side (markdown via Python-Markdown or similar, RTF via a converter, plain text wrapped in `<pre>`, HTML as-is).
     - Custom Privacy Policy — same file upload pattern.
     - Clear override semantics: "Upload your own Terms of Use to replace the default. If you don't upload anything, Clear Skies provides a standard template based on your visitor regions selected above."
     - After upload, show a rendered HTML preview of the legal content so the operator can verify before proceeding.
     - This is the "legal and data collection" step.

     **Step C — Feature Settings:**
     - Seismic page settings (earthquake radius, min magnitude, time period)
     - This step absorbs per-feature configuration as features are added.

  2. Create 2 new template files: `step_privacy_legal.html` and `step_feature_settings.html`. Rename or repurpose the existing `step_appearance.html` for Step A (Branding only).
  3. Update the step routing mechanism (identified in T0.4) to accommodate the new step count. Update the progress bar to show the correct total. Update next/back navigation through all new steps.
  4. Within each step, improve visual hierarchy: use `<h3>` sub-headings to group related fields (e.g., "Logos" group separate from "Colors & Theme" group within Step A). Add visual spacing between groups.
  5. Implement the file upload for legal content:
     - Accept `.html`, `.md`, `.txt`, `.rtf` extensions.
     - Server-side format detection by extension.
     - Server-side conversion to HTML.
     - Render preview in an iframe or styled div after upload.
     - Store the converted HTML in the config directory.

- **Accept:**
  - Three separate steps replace the old single Appearance step.
  - Progress bar shows correct total step count.
  - Next/back navigation works through all new steps in correct order.
  - All fields from the original step are present in exactly one of the new steps.
  - File upload for legal content accepts all 4 formats, converts correctly, shows rendered preview.
  - Override semantics clearly stated on the page.
  - Visual hierarchy improved with sub-headings and field grouping.
  - Existing wizard functionality (save progress, pre-populate from config) works through the new steps.
- **QC:** Opus walks through the wizard from the step before Step A through Step C, verifying: all fields present, routing works (next/back), file upload accepts a .md file and shows preview, progress bar accurate.

### T4.3 — Fix wizard Apply permission denied (FIX-010)

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T0.4 (permission findings from weather-dev)
- **Backlog:** FIX-010
- **Do:**
  1. On weather-dev, fix the directory permissions so the wizard process can write to `/etc/weewx-clearskies/`. Using T0.4 findings: if the wizard runs as user `ubuntu` but the directory is owned by `root`, change ownership to match. If the wizard should run as `clearskies`, update the systemd unit.
  2. Add a pre-flight permission check in the Apply step handler: before attempting to write ANY file, check `os.access(path, os.W_OK)` for every target file/directory. If any check fails, return an error response BEFORE any state changes (no partial writes).
  3. Improve the error message for permission failures. Currently shows a raw "[Errno 13] Permission denied" traceback. Replace with a clear, actionable message:
     ```
     Cannot write to /etc/weewx-clearskies/branding.json — permission denied.
     
     Fix: Run the following command on the server, then click Apply again:
       sudo chown -R clearskies:clearskies /etc/weewx-clearskies/
       sudo chmod 750 /etc/weewx-clearskies/
     ```
  4. If the API config save succeeds but local write fails (partial success), the error must clearly explain: "API configuration saved successfully. Local file write failed for: [list of files]. The API is configured but local files are out of sync. Fix permissions and click Apply again to write local files."
- **Accept:**
  - Apply succeeds end-to-end on weather-dev with no permission errors.
  - Pre-flight check catches permission issues before any state changes.
  - Error messages include the specific fix commands (chmod/chown).
  - Partial success is clearly communicated with a list of what succeeded and what failed.
- **QC:** Opus runs the wizard Apply on weather-dev and confirms it succeeds. Temporarily breaks permissions (e.g., `sudo chmod 000 /etc/weewx-clearskies/branding.json`) and confirms the pre-flight check catches it with an actionable error message. Restores permissions afterward.

---

## Dependency graph

```
Phase 0 (Research — all 4 tasks parallel)
├── T0.1 screenshots ─── T0.2 auto-rows verify ─── T0.3 nav investigation
└── T0.4 wizard audit
    │                                                    │
    ▼                                                    ▼
Phase 1 (Global fixes — sequential)              Phase 4 (Wizard — parallel with Phases 1-3)
T1.1 auto-rows ──────────────────┐                T4.1 WCAG contrast
T1.2 nav bar (dep: T0.3)        │                T4.2 step split
T1.3 radar z-index (dep: T1.2)  │                T4.3 apply permissions
T1.4 footer (dep: T0.1)         │
T1.5 desktop regression ────────┘
    │
    ▼
Phase 2 (Per-page — mostly parallel)     Phase 3 (New components — parallel with Phase 2)
T2.1 forecast day names                  T3.1 chart fullscreen
T2.2 forecast card verification          T3.2 scroll affordance
T2.3 charts page                         T3.3 sticky-column table
T2.4 almanac page                             │
T2.5 seismic page                             │
T2.6 reports page (dep: T3.3) ◄───────────────┘
T2.7 footer content layout
T2.8 remaining page verification
```

---

## Verification bar — plan-level "done" definition

The plan is complete when ALL of the following are true:

- **Every page** (Home, Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal) loads and is fully usable at 375px viewport width.
- **Navigation** is accessible on every page — bottom nav always visible on mobile.
- **No card** has internal scrolling on mobile (except the Reports NOAA table, which uses horizontal scroll by design with sticky first column).
- **No content** is clipped by card boundaries, the footer, or the bottom nav.
- **Footer** is below all content on every page, with copyright left / logo right / social centered layout on mobile.
- **Charts** have a tap-to-fullscreen affordance that opens a full-viewport overlay.
- **Horizontally scrollable** containers have a visible scroll affordance (gradient fade).
- **Wizard** passes WCAG AA contrast, has 3 focused steps replacing the old Appearance step (with file upload for legal content), and Apply works without permission errors.
- **Desktop** has zero regressions at md (768px) and lg (1280px) breakpoints.
- `npm run build` (Vite production build) completes with zero errors.
- All existing tests pass with no regressions.
