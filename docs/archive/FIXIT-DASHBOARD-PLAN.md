# FIXIT-DASHBOARD-PLAN — NOW page layout, card fixes, bug fixes

**Goal:** Fix 10 UI issues on the dashboard NOW page: layout restructuring (card sizing, ordering, mobile impact), component-level visual fixes, and two bugs (UV chart disappearing, barometer trend indicator missing).

**Status:** Not started.

**Repos involved:**
- `weewx-clearskies-dashboard` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`) — all UI changes
- `weewx-clearskies-api` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-api`) — barometer trend investigation only

---

## Orientation — read before executing any task

**Load these before every session:**
1. [CLAUDE.md](../../CLAUDE.md) — domain routing, operating rules
2. [rules/coding.md](../../rules/coding.md) — code standards, accessibility
3. [rules/clearskies-process.md](../../rules/clearskies-process.md) — process rules
4. This plan — current task status and context

**Dev/test environment:** `weather-dev` LXD container. Dashboard source at `/home/ubuntu/repos/weewx-clearskies-dashboard`. API source at `/home/ubuntu/repos/weewx-clearskies-api`. Deploy via `scripts/redeploy-weather-dev.sh`.

**Git safety:** Agents do NOT push. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No worktree isolation for implementation — all work in the primary local checkout. Coordinator commits after QC.

**QC model:** Opus (coordinator) provides QC at every task. QC is NOT "is the code well-written" — it is:
- Does the change do what the task says it should do?
- Does it comply with this plan, coding rules, and accessibility standards?
- Does it introduce regressions in existing functionality?
- Is the acceptance criteria met (verified by running the check, not trusting the agent's claim)?

**No deferrals.** Every task in this plan is mandatory. Agents do not get to say "deferred to a future round." If a task is blocked, the agent reports the blocker and the coordinator resolves it. The task does not close until acceptance criteria are met.

**Agent assignments:**
- `dashboard-dev` → `clearskies-dashboard-dev` agent (Sonnet) — all React/Tailwind/component implementation
- `api-dev` → `clearskies-api-dev` agent (Sonnet) — barometer trend API investigation and fix
- `test-author` → `clearskies-test-author` agent (Sonnet) — test updates
- Opus (coordinator) → orchestration, research, QC, final verification

---

## Dimension notation

All dimensions in this plan are **COL × ROW** (width × height). Example: "2×2" = 2 columns wide, 2 rows tall.

## Current NOW page layout (desktop, 4-col grid)

```
Row 1-2: [Current Conditions (wide 2×2)]  [Wind Compass (wide 2×2)]
Row 3:   [Forecast (wide 2×1)]            [Radar (wide 2×2) ──┐
Row 4:   [Highlights (wide 2×1)]                               │
Row 5:   [Precip] [Barometer] [Solar] [UV]                    ─┘
Row 6:   [AQI] [Sun&Moon] [Lightning] [Earthquake]
Row 7+:  [Webcam (wide 2×2)]
```

## Target NOW page layout (desktop, after this plan)

```
Row 1-2: [CC (wide 2×2)]                     [Forecast (wide 2×2)]
Row 3-4: [Wind (tile 1×2)] [Highlights (tile 1×2)] [Precip] [Barometer]  ← row 3
                                                     [Solar]  [UV]        ← row 4
Row 5:   [AQI] [Sun&Moon] [Lightning] [Earthquake]
Row 6+:  [Radar (wide 2×2.5)]                [Webcam (wide 2×2.5)]
```

---

## Grid system reference

- **File:** `src/components/layout/grid.tsx` — 4-col (lg >=1024px), 2-col (md >=768px), 1-col (mobile)
- **File:** `src/components/ui/card.tsx` — `footprint` (tile/wide/panel/full), `rowSpan` ("quarter"/"half"/1/2)
- **Row track:** `--card-quarter-row` = 2.75rem at md+. rowSpan 1 = 4 tracks (11rem), rowSpan 2 = 8 tracks (22rem)
- **Mobile:** All rows auto-height, cards stack 1 per row. rowSpan has no effect on mobile.
- **Typography tokens:** `--text-micro` (0.7rem/11.2px), `--text-label` (0.75rem/12px), `--text-card-title` (0.82rem/13.1px)

---

## Phase 0 — Quick wins

Trivial fixes that can ship independently.

### T0.1 — Alert strip title ALL CAPS

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None
- **Scope:** MOBILE + DESKTOP
- **File:** `src/components/shared/alert-banner.tsx` line 290
- **Do:** Add `uppercase` Tailwind class to the alert title `<p>` element. Current: `className="truncate font-heading text-[length:var(--text-card-title)] font-semibold leading-snug text-card-foreground"`. Add `uppercase` to the class list.
- **Accept:** Alert titles render in ALL CAPS (e.g., "BEACH HAZARDS STATEMENT"). No change to the underlying data — CSS transform only.
- **QC:** Load dashboard with active alerts, verify title is uppercase in both light and dark themes, desktop and mobile viewport.

---

## Phase 1 — Grid system extension + layout restructure

These items are interrelated (3, 4, 5, 6, 8) and must be coordinated. The grid system needs a new rowSpan value, then cards are resized and reordered.

### T1.1 — Add rowSpan 2.5 to card system

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None
- **Scope:** DESKTOP (mobile is auto-height, unaffected)
- **File:** `src/components/ui/card.tsx`
- **Do:**
  1. Add `2.5` to the `rowSpan` type union: `"quarter" | "half" | 1 | 2 | 2.5`
  2. In `rowSpanClass()`, add case for `2.5` returning `"md:row-span-10"` (10 tracks × 2.75rem = 27.5rem)
  3. In `minHeightClass()`, add case for `2.5` — mobile min-height should be something like `min-h-[calc(var(--card-row)*2.5)]` with `md:min-h-0`
  4. Update the JSDoc comments on the `rowSpan` prop and the `rowSpanClass` function to document the new value.
- **Accept:** `rowSpan={2.5}` produces `md:row-span-10` on desktop. No regression for existing rowSpan values. TypeScript compiles without error.
- **QC:** Render a test card with `rowSpan={2.5}` and verify it occupies 10 grid tracks (27.5rem) at md+.

### T1.2 — Resize Wind card to 1×2 (tile, tall) and adjust content

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Scope:** DESKTOP (mobile auto-height unchanged)
- **Files:** `src/components/WindCompassCard.tsx`, `src/routes/now.tsx`
- **Do:**
  1. In `WindCompassCard.tsx`: Change the Card from `footprint="wide"` to `footprint="tile"`. Keep `rowSpan={2}` (stays 2 rows tall, but now 1 column wide instead of 2).
  2. The SVG dial (420×420 viewBox, maxWidth 20rem) will need to scale down to fit a single-column card width (~270px at lg). The SVG is responsive via viewBox so it will scale, but verify the compass dial and center overlay text (bearing, cardinal, speed, 10m avg, max gust) are still readable at the narrower width.
  3. May need to reduce `maxWidth` on the dial or reorganize the center content layout to work in a narrower card.
  4. In `now.tsx`: Move `<WindCompassCard>` to appear after `<NowForecastCard>` in source order so it flows into col 1 of rows 3-4.
- **Accept:** Wind card renders at 1×2 (tile, 22rem height, 1 column). Compass dial and all text/values are visible and readable. Card appears below CC on the far left (col 1). Mobile layout unaffected (stacks full-width).
- **QC:** Load the NOW page at desktop width. Verify wind card is positioned in col 1 below CC, all content fits without overflow/clipping.

### T1.3 — Resize Forecast card to 2×2, restore temperature graphs

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Scope:** DESKTOP
- **Files:** `src/components/forecast/NowForecastCard.tsx`, `src/routes/now.tsx`
- **Do:**
  1. In `NowForecastCard.tsx`: Change `<Card footprint="wide" size="sm">` to `<Card footprint="wide" rowSpan={2} size="sm">`. This doubles the card height from 11rem to 22rem.
  2. Keep the `size="sm"` prop — add a comment noting that removing `size="sm"` restores the non-compact layout (for future switchback).
  3. On the Today tab: Change `hideTrend` to `false` on `<HourlyStrip>` (line 186). This restores the `TempTrendLine` temperature graph that was previously hidden.
  4. On the 7-Day tab: `DailyColumns` already shows the trend line on desktop. No change needed.
  5. Scale padding/spacing to use the available 22rem height — the card was cramped at 11rem, now has room. Consider removing `size="sm"` or adjusting padding since we have more vertical space.
  6. Adjust font sizes to match other 2×2 cards (Current Conditions uses `--text-card-title` for header, standard tokens for content). The forecast card already uses token-based sizing, but verify consistency.
  7. In `now.tsx`: Move `<NowForecastCard>` to appear right after `<CurrentConditionsCard>` so it sits next to CC in the grid (both wide, both rowSpan=2, filling rows 1-2 across all 4 columns).
- **Accept:** Forecast card renders at 2×2 next to Current Conditions. Temperature trend graph visible on both Today and 7-Day tabs. Content fills the card proportionally. Font sizes consistent with other cards. Mobile layout unaffected (card stacks full-width, auto-height).
- **QC:** Load NOW page at desktop width. Verify forecast card is adjacent to CC. Switch between Today and 7-Day tabs — both show temperature trend lines. Verify no content overflow.

### T1.4 — Resize Highlights to 1×2, reorder all cards

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.2, T1.3, T1.5
- **Scope:** DESKTOP (mobile auto-height, stacks vertically)
- **Files:** `src/components/todays-highlights-card.tsx`, `src/routes/now.tsx`
- **Do:**
  1. In `todays-highlights-card.tsx`: Change from `footprint="wide"` (2 cols) to `footprint="tile"` (1 col). Add `rowSpan={2}` (2 rows tall). The card goes from a short wide strip to a tall single-column tile. Restructure the content layout to work vertically — the 6 stat items currently in a horizontal flex strip will need to stack vertically or rearrange into a 2×3 or 3×2 grid within the card.
  2. In `now.tsx`: Reorder the JSX children within `<Grid>` to achieve the target layout. The new order:
     - CurrentConditionsCard (wide 2×2)
     - NowForecastCard (wide 2×2)
     - WindCompassCard (tile 1×2)
     - TodaysHighlightsCard (tile 1×2)
     - PrecipitationCard (tile 1×1)
     - BarometerCard (tile 1×1)
     - SolarRadiationCard (tile 1×1)
     - UvIndexCard (tile 1×1)
     - AqiCard (tile 1×1)
     - SunMoonCard (tile 1×1)
     - LightningCard (tile 1×1)
     - EarthquakeCard (tile 1×1)
     - Radar (wide 2×2.5)
     - Webcam (wide 2×2.5)
  3. This ordering produces the target layout via CSS grid auto-placement (left-to-right, top-to-bottom):
     - Row 1-2 (8 tracks): CC (wide 2×2, cols 1-2) + Forecast (wide 2×2, cols 3-4)
     - Row 3-4 (8 tracks): Wind (tile 1×2, col 1) + Highlights (tile 1×2, col 2) + Precip (tile, col 3 row 3) + Barometer (tile, col 4 row 3) + Solar (tile, col 3 row 4) + UV (tile, col 4 row 4)
     - Row 5 (4 tracks): AQI + Sun&Moon + Lightning + Earthquake (4 tiles)
     - Row 6+ (10 tracks): Radar (wide 2×2.5, cols 1-2) + Webcam (wide 2×2.5, cols 3-4)
  4. Update the JSX comments to reflect the new layout positions.
- **Accept:** Desktop layout matches the target diagram. Highlights content readable in the tall-tile format. All cards render in the correct grid positions. Mobile layout unchanged (cards stack vertically in source order — verify mobile order still makes logical sense).
- **QC:** Load NOW page at desktop, tablet (md), and mobile widths. Verify layout matches target at desktop. Verify Highlights content fits the 1×2 tile. Verify mobile stacking order is logical.

### T1.5 — Resize Radar and Webcam to 2×2.5

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Scope:** DESKTOP
- **Files:** `src/routes/now.tsx` (Radar card inline), `src/components/webcam-card.tsx`
- **Do:**
  1. Radar card (inline in now.tsx lines 259-273): Change `rowSpan={2}` to `rowSpan={2.5}`. Keep `footprint="wide"`. Adjust the inline `min-h` and `h` calculations for the new height: `h-[calc(var(--card-row)*2.5+var(--gap-grid)*1.5)]` (or remove the hardcoded h if `md:row-span-10` handles it).
  2. Webcam card (`webcam-card.tsx`): Change `rowSpan={2}` to `rowSpan={2.5}`. Keep `footprint="wide"`. Verify the media content (img/video) scales to fill the taller card.
  3. Verify the Leaflet radar map expands to fill the taller container. The map uses `flex-1` so it should grow automatically.
- **Accept:** Radar and Webcam cards render at 2×2.5 (wide, 27.5rem height). Map and webcam content fill the available space. No blank areas or overflow. Mobile auto-height unaffected.
- **QC:** Load NOW page at desktop. Verify both cards are visually taller than before. Radar map fills the space. Webcam image/video fills the space.

---

## Phase 2 — Component-level fixes

### T2.1 — Current Conditions chart: x-axis label clipping + NOW indicator

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None
- **Scope:** DESKTOP
- **File:** `src/components/current-conditions-card.tsx`
- **Do:**
  1. **X-axis clipping:** The chart container margin is `{ top: 6, right: 16, bottom: 16, left: 0 }`. The rightmost tick label ("6p" at 18:00 or "12a" at midnight) may be clipped. Increase `left` margin slightly (e.g., `left: 4` or `left: 8`) and verify the rightmost label is no longer clipped. May also need to add `padding` prop on the XAxis.
  2. **NOW label near midnight:** The ReferenceLine label uses `position: 'insideTopLeft'`. Near midnight (when `now` ≈ x-axis left edge), this positions the "Now" text off the left side of the chart. Fix: use a custom label render function that checks the x-position and shifts the label right when it's within ~10% of the left edge. Alternatively, switch to `position: 'top'` which centers the label above the reference line (won't clip at edges).
  3. Test at various times of day (especially near midnight and near the right edge at 23:00+).
- **Accept:** X-axis tick labels fully visible (no clipping). "Now" label stays within chart bounds at all times of day including near midnight. No regression in chart appearance during daytime hours.
- **QC:** Load the card and inspect x-axis labels at the edges. Manually set `now` to near-midnight timestamp and verify label positioning.

### T2.2 — Moon and Sun card: fonts, arc width, moon phase layout

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None
- **Scope:** MOBILE + DESKTOP
- **File:** `src/components/sun-moon-card.tsx`
- **Do:**
  1. **Fix undersized fonts:** Replace hardcoded font sizes that are below standard:
     - Rise/set time labels: currently `fontSize={10}` — change to use `--text-label` (12px) or at minimum `--text-micro` (11.2px via `var(--text-micro)`)
     - Rise/set label words ("Sunrise", "Moonrise", etc.): currently `fontSize={8}` — change to `--text-micro` (11.2px)
     - Moon phase label: currently `fontSize={9}` — change to `--text-micro` (11.2px)
     - All font sizes should reference CSS variables, not hardcoded pixel values
  2. **Extend arcs horizontally:** The SVG viewBox is 220×120. Sun arc rx=88 out of 220 (80% width). Increase rx values to fill more horizontal space:
     - Widen the viewBox (e.g., 250×120 or 260×120) OR increase rx values while adjusting CX center
     - Sun arc: increase rx from 88 to ~100-105 (fills ~85-90% of width)
     - Moon arc: increase rx from 52 to ~65-70 proportionally
     - This gives slightly more space between arc endpoints and card edges, improving readability of the bottom info
  3. **Enlarge moon phase icon and text, move to bottom:** Currently the moon phase label sits near the arc. Restructure the bottom section:
     - Place the moon phase icon (increase size from current) and phase name text at the very bottom of the card, centered
     - This may require restructuring the component to have: [SVG arcs area] above, [moon phase info] below as a separate div
  4. **Move arc up slightly:** Reduce the top padding/margin of the SVG area or adjust the SVG viewBox y-offset to shift arcs upward, creating more space at the bottom for the enlarged moon phase section.
  5. Test at both mobile and desktop widths — the SVG scales with `width="100%"` so changes affect both.
- **Accept:** All font sizes meet minimum standards (>=11.2px using design tokens). Arcs fill more horizontal space. Moon phase icon is larger and prominently positioned at bottom. No content crowding. Works on both mobile and desktop.
- **QC:** Load the card at desktop and mobile widths. Inspect all font sizes with dev tools — none below 11px. Verify arcs extend further horizontally. Verify moon phase info is at the bottom and readable.

### T2.3 — UV card chart disappears after refresh

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** None
- **Scope:** MOBILE + DESKTOP
- **File:** `src/components/uv-index-card.tsx`
- **Root cause:** `buildUvBellCurve()` returns `[]` when `uvIndexMax` is null or <=0 (lines 93-97). After a page refresh, `todayForecast` can be null while it loads, making `forecastUv` null, which defaults to peak=0, returning empty data. The UvChart component then renders "No data" text instead of the chart (lines 405-414).
- **Do:**
  1. In the `UvChart` component: when `data.length === 0` BUT `currentUv` is not null, don't show the "No data" message. Instead, render the chart axes and the ReferenceDot showing the current UV observation. The bell curve can be absent (no area fill) while still showing the current reading.
  2. Only show "No data" when BOTH the bell curve data is empty AND `currentUv` is null.
  3. Alternative simpler approach: in `buildUvBellCurve`, when `peak <= 0` but we're being called (meaning the component is mounted), return a flat-zero curve instead of empty array. This keeps the chart frame visible. Then the ReferenceDot for current UV still renders on the chart. Add a check: if we have observation UV data, always render the chart frame.
  4. Either approach: the user should always see the chart structure and current UV reading when observation data exists, even if forecast hasn't loaded yet.
- **Accept:** After page refresh, the UV card shows the current UV reading immediately (via ReferenceDot or similar indicator). The bell curve appears once forecast data loads. No flash of "No data" when observation data is available. Card still shows "No data" gracefully when genuinely no UV data exists (nighttime, no sensor, etc.).
- **QC:** Hard refresh the page. Watch the UV card — it should show the current UV value immediately, then fill in the bell curve when forecast loads. Test at nighttime (UV=0) to verify it still shows the chart frame or a reasonable fallback.

---

## Phase 3 — API investigation + fix

### T3.1 — Investigate barometer trend direction on weather-dev

- **Owner:** `api-dev` (Sonnet), with Opus coordinating the investigation
- **Dep:** None
- **Scope:** MOBILE + DESKTOP
- **Files:** Dashboard `src/components/barometer-card.tsx`, API `weewx_clearskies_api/sse/enrichment/barometer_trend.py`
- **Background:** The dashboard renders the rising/falling indicator when `barometerTrendDirection` is not null (line 291 of barometer-card.tsx). This value comes from the REST `/current` endpoint envelope, computed by the API's barometer trend enrichment processor. SSE packets carry `barometerTrend` (numeric delta) but NOT `barometerTrendDirection`. The enrichment has multiple failure paths that return null: no observation data, DB query failure, historical record outside grace period, or unit resolution failure (source unit unknown → direction null with a DEBUG log).
- **Do:**
  1. SSH to weather-dev. Call `/api/v1/current` and check the response envelope for `barometerTrendDirection`. Is it null or populated?
  2. If null: check the API logs for `barometer_trend` messages. Look for:
     - `"barometer_trend: DB query failed"` — historical data lookup is failing
     - `"barometer_trend: pressure unit unknown — barometerTrendDirection null"` — unit resolution failure
     - No log messages at all — the enrichment may not be registered or the barometer observation may be missing
  3. Check `barometer_trend.configure()` call in `__main__.py` (line 862) — verify `trend_time_delta` is set correctly.
  4. Check if `observation.barometer` is present in the `/current` response `data` object.
  5. Based on findings, fix the root cause:
     - If unit resolution failure: fix the unit lookup in the enrichment code
     - If DB query failure: fix the query or connection
     - If data missing: trace why barometer observation isn't reaching the enrichment
     - If the enrichment isn't running: verify registration in `__main__.py`
- **Accept:** `/api/v1/current` returns `barometerTrendDirection` as "rising", "falling", or "steady" (not null) when barometer data is available. The dashboard barometer card shows the trend indicator (arrow + text).
- **QC:** Call `/api/v1/current` on weather-dev, confirm `barometerTrendDirection` is non-null. Load the dashboard and visually confirm the rising/falling indicator appears on the barometer card.

---

## Dependency graph

```
Phase 0 (quick wins — independent)
  T0.1 alert uppercase ── can ship immediately

Phase 1 (layout restructure — sequential)
  T1.1 add rowSpan 2.5 to card system
    │
    ├──→ T1.2 resize Wind to 1×2 (tile, tall)
    ├──→ T1.3 resize Forecast to 2×2 + restore temp graphs
    │
    └──→ T1.5 resize Radar/Webcam to 2×2.5
         │
    T1.4 resize Highlights to 1×2 + reorder all cards (depends on T1.2, T1.3, T1.5)

Phase 2 (component fixes — independent of each other, can parallel)
  T2.1 CC chart x-axis + NOW label
  T2.2 Moon/Sun card fonts + arcs + layout
  T2.3 UV chart disappears after refresh

Phase 3 (API investigation)
  T3.1 barometer trend direction (independent, needs weather-dev access)
```

**Parallelism:** Phase 0 can ship immediately. Phase 1 tasks T1.1 must go first, then T1.2/T1.3/T1.5 can be done in any order, with T1.4 last (the reorder). Phase 2 tasks are independent and can run in parallel with Phase 1. Phase 3 is independent and requires SSH to weather-dev.

---

## Verification — plan-level done definition

The plan is complete when ALL of the following are true:

- **Alert strip:** Titles render in ALL CAPS on desktop and mobile
- **CC chart:** X-axis labels not clipped. "Now" indicator stays within chart bounds at all times including near midnight
- **Layout:** Desktop NOW page matches the target layout diagram. Wind is 1×2 tile below CC far left. Forecast is 2×2 next to CC with temperature graphs. Highlights is 1×2 tile right of Wind. Precip+Barometer fill cols 3-4 row 3. Solar+UV fill cols 3-4 row 4. Radar+Webcam are 2×2.5.
- **Moon/Sun card:** All fonts >=11px using design tokens. Arcs extend further horizontally. Moon phase icon enlarged and at bottom. No crowding.
- **Radar/Webcam:** Both render at 2×2.5 with content filling the space
- **UV card:** Chart does not disappear after refresh when observation data exists
- **Barometer indicator:** Rising/falling trend arrow + text visible when barometer data available
- **Mobile:** No regressions. Items 1, 7, 9, 10 work on mobile. Layout items (2-6, 8) don't break mobile stacking.
- **Accessibility:** No new WCAG violations. Font sizes meet minimums. Color is never the sole signal.
