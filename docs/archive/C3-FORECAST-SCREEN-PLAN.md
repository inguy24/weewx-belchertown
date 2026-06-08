# C3 — Forecast Screen Implementation Plan

**Status:** Code-complete 2026-06-01. Pending push + deploy + live verification (Gates 3–4).
**Approved by:** Operator (chat approval 2026-05-31; mockups iterated through v6 with operator feedback).
**Prerequisite:** C1 and C2 code-complete. Track A foundations deployed. Track B research gates closed.

### Execution summary
- **Phase 1 (mockups):** 6 iterations (v1→v6) with operator feedback. Key design changes from the original
  plan: 7-Day uses columns (not rows); Now Today tab uses 3-hour windows (not hourly); tabs inline with
  card title right-justified; BBC Weather-style wind symbols (img-09); combined "74°/58°" hi/lo temps;
  dual trend lines (hi red + lo blue); img-12-style full-width expandable detail panel (forecast page only).
  Locked at commit `3760918` (meta repo).
- **Phase 2 (code):** 5 commits on dashboard repo (`c633efe`→`efdc746`). 8 files created, 5 modified,
  1929 insertions. `tsc --noEmit` 0 errors, `vite build` clean.
- **Pending:** Gate 3 (visual verification on weather-dev, both themes, responsive) + Gate 4 (axe-core,
  keyboard walkthrough, screen reader spot-check).

## Context

C3 builds the forecast visualization across two surfaces: the **Now page** (a compact tabbed card) and the **dedicated `/forecast` page** (two full-width detail cards + a discussion card). C1 (Current Conditions + hero + temp curve) and C2 (Wind Compass) are code-complete. C3 is the next Track C component in the per-component workflow.

The design is grounded in seven inspiration images (img-02/07/09/12/15/24/26) that lock three signals: **icon-rich per-hour columns** (4 votes), **time-range tabs** (img-12), and **temperature trend lines** threading through columns (3 votes). The "too simple multi-day strip" is the anti-pattern to avoid.

All forecast data already exists — five providers (Open-Meteo, NWS, Aeris, OWM, Wunderground), the BFF, and the dashboard hooks are wired. This is a presentation-layer effort: we change how existing data is displayed, not how it's fetched or converted.

### Inspiration images studied (Step 0 gate passed)
- **img-02** (BBC Weather, Standish) — PRIMARY hourly column model: time/icon/temp/precip%/wind vertical stack per hour
- **img-07** (Hourly Forecast widget) — clean per-hour columns: time/icon/temp/wind circle
- **img-09** (BBC Weather, Romsey) — heavy iconography in forecast columns; data reads visually
- **img-12** (UNIAN, Poltava) — time-range TABS (Today/Tomorrow/Week) + expandable columns
- **img-15** (Dark bento dashboard) — temperature trend LINE through hourly forecast data
- **img-24** (Haifa app) — weekly forecast as connected dot-line trend (dots at daily temps)
- **img-26** (Google Weather, Rapid City) — subtle temp trend line through hourly columns + precip droplets

### Anti-patterns (do NOT do)
- "Simple multi-day extended forecast strip" — operator said "too simple" (NOTES.md line 161)
- Organic/blob tile shapes — prefers clean uniform tiles
- Inventing colors outside ADR-048 (no amber, no arbitrary hex)
- Using Inter or any font outside the locked Manrope/Outfit/Lexend set
- Per-card ADRs (rejected 2026-05-31)

---

## Scope — Four Surfaces

### Surface A: Now-page Tabbed Forecast Card

**Footprint:** `wide` (2 cols × 1 row) — locked in [A4-card-grid.html](../../design/mockups/A4-card-grid.html) line 491 as "Today's Forecast" `col-span-2 row-span-1`. Collapses to 1×1 on tablet, full-width stacked on phone.

**Replaces:** the existing text-only "Today's Forecast" tile card in `now.tsx` (lines 296–327: weatherText + hi/lo + precip% + narrative).

**Two tabs within one Card:**
- **Today** (default): Horizontally scrollable hourly strip, 24h from now. Each column stacks: time label → condition icon (ADR-049 hero, ~24px) → temperature → precip % (droplet + %, hidden if 0%) → wind (arrow + speed). SVG temp trend line connecting column temps (accent blue per ADR-048).
- **7-Day**: Daily summary rows. Each row: day name + date → condition icon (24px) → hi/lo temps (themed `--temp-hi`/`--temp-lo`) → precip % → wind speed max → UV badge (when available). Connected dot-line trend through daily high temps.

**Data depth (compact):** Core fields only. No expandable detail. No per-hour humidity/gust/cloud.

### Surface B: Forecast Page — Hourly Card (24h, tabbed Today/Tomorrow)

**Footprint:** `full` + `rowSpan={2}` = 4 cols × 2 conceptual rows (**4×2**).

**Two tabs within one Card:**
- **Today** (default): Today's remaining hours + overnight
- **Tomorrow**: Tomorrow's 24 hours

**Per-hour column (expanded vs Surface A):** time → condition icon (32px) → temperature (Outfit) → *temp trend line threads here* → precip % (droplet + %, hidden if 0%) → wind (arrow + speed) → **expandable detail toggle** that reveals: humidity, wind gust, cloud cover per-hour.

**Expandable detail:** A "More" toggle below the core strip adds extra rows (humidity %, wind gust, cloud %) to ALL visible columns simultaneously. Provider-gated: if a field is null for all hours, the row is omitted.

**Requires:** `?hours=48` API request (up from default 12).

### Surface C: Forecast Page — 7-Day Card

**Footprint:** `full` + `rowSpan={2}` = 4 cols × 2 conceptual rows (**4×2**).

**Per-day row:** day name + date → condition icon (32px) → hi/lo temps (Outfit, `--temp-hi`/`--temp-lo`) → connected dot-line trend through highs → precip % (droplet) → wind speed max → UV index badge.

**Expandable detail:** Clicking a day row expands it inline to show: wind gust max, narrative text (when provider supplies it). Provider-gated: null fields omitted.

**Data constraint:** `DailyForecastPoint` does NOT have `outHumidity` or `cloudCover` fields — those exist only on `HourlyForecastPoint`. Daily expandable detail is limited to: `windGustMax` (available from Open-Meteo/Aeris/OWM), `narrative` (available from NWS/OWM/WU), and `sunrise`/`sunset` (available from most). If daily humidity/cloud is desired, it would require an API contract change (out of Track C scope).

**7-day max.** No extended forecasts beyond 7 days.

### Surface D: Forecast Page — Discussion Card

**Footprint:** `full` (4 cols, auto height).

**Content:** NWS Area Forecast Discussion (AFD) prose or Aeris discussion text.
- Headline (Manrope 600, `--text-body`)
- Body text (Manrope 400, `--text-body`, `whitespace-pre-wrap` for AFD line breaks)
- Footer: "Issued {station-local time} · {senderName}" (Manrope 400, `--text-label`)

**Self-hides** when `discussion === null` (most providers). Operator-toggled OFF by default per ADR-024.

---

## Prior Decisions & Constraints (reading list for all agents)

### Grid & Layout
- **Grid:** 4-col (≥1024px), 2-col (≥768px), 1-col (<768px). `gap: var(--gap-grid)` = 1rem. `max-width: var(--container-max)` = 80rem.
- **Card primitive:** `src/components/ui/card.tsx`. Props: `footprint` ("tile"|"wide"|"panel"|"full"), `rowSpan` (1|2), `size` ("default"|"sm"). Glass surface: `card-glass` CSS class (72% white light / 55% dark-slate dark + blur(8px)).
- **Card sub-components:** CardHeader, CardTitle, CardContent, CardDescription, CardAction, CardFooter.
- **Grid component:** `src/components/layout/grid.tsx`. Responsive 4→2→1 columns.
- **ControlsStrip:** `src/components/layout/controls-strip.tsx`. Full-width card with flex row of controls.
- **PageHeaderCard:** `src/components/layout/page-header-card.tsx`. Props: `title`, `info?`, `as?`, `children?`.
- Row heights are content-driven (`grid-auto-rows: auto`), not fixed tracks.

### Typography (LOCKED — `docs/design/design-tokens-typography.md`)
- `--font-display: 'Outfit'` — stat numerals (Outfit 600 for wind speed size, NOT 4.75rem hero which is C1 temp only)
- `--font-sans: 'Manrope'` — body, labels, card titles
- `--font-chart: 'Lexend'` — chart SVG text only
- Card title: `--text-card-title: 0.82rem`, Manrope 600 (semibold, NOT bold)
- Body: `--text-body: 0.9rem`, Manrope 400
- Secondary: `--text-secondary: 0.85rem`, Manrope 400 or 600
- Label: `--text-label: 0.75rem`, Manrope 400
- Micro: `--text-micro: 0.7rem`, Manrope 400

### Colors (ADR-048)
- Accent blue: `oklch(0.48 0.22 260)` light / `oklch(0.70 0.15 260)` dark — use `var(--primary)` or the theme accent, NOT hardcoded.
- `--temp-hi: #c81e1e` (light) / `#f87171` (dark) — high temps
- `--temp-lo: #1d4ed8` (light) / `#93c5fd` (dark) — low temps
- `--muted-foreground` — secondary/dim text
- `--foreground` — primary text

### Icons
- **Hero weather icons:** ADR-049 Material Symbols gradient SVG via `<WeatherIcon code={...} size={N} />` (file: `src/components/weather-icon.tsx`). Maps WMO codes to glyphs with sr-only descriptions.
- **Utility icons:** Phosphor (`@phosphor-icons/react`) per ADR-050. Use `ph:wind` for wind, `ph:drop` for precip, `ph:sun` for UV, `ph:cloud` for cloud cover, `ph:thermometer` for humidity.

### Data
- **ADR-042:** BFF converts units; dashboard renders `{value, label, formatted}` verbatim. Zero client unit math.
- **ADR-020:** Timestamps in station-local timezone via `Intl.DateTimeFormat`.
- **ADR-021:** 13 locales; all text strings go through `useTranslation()`.
- **Forecast types:** `HourlyForecastPoint` (14 fields + extras), `DailyForecastPoint` (14 fields + extras), `ForecastDiscussion` (text, issuedAt), `ForecastBundle` (hourly[], daily[], discussion, source, generatedAt). Defined in `src/api/types.ts`.
- **useForecast hook:** `src/hooks/useWeatherData.ts:169–190`. Currently no params, defaults to 12h/7d. Calls `getForecast(signal)` in `src/api/client.ts`.
- **cardinalFromDegrees:** `src/utils/wind.ts:43–49`. Client-side cardinal from degrees (forecast has no BFF-supplied cardinal).
- **Daily has NO `windDir` field.** Wind speed only on daily cards — no wind direction circle.

### Existing Code to Evolve
- **`forecast.tsx`:** Currently renders: hourly scrollable strip (72px items: hour/icon/temp/precip%/wind) + 7-day daily grid (individual Cards in responsive grid) + freshness indicator. Discussion NOT rendered. No tabs, no trend lines, no expandable detail.
- **`now.tsx` forecast card:** Lines 296–327. A `tile` Card showing: weatherText, hi/lo, precip%, narrative (text only, no hourly columns).

### Accessibility (rules/coding.md §5)
- WAI-ARIA tabs pattern for tab controls (role="tablist"/tab/tabpanel, Arrow keys)
- All icons: `aria-hidden="true"` when paired with visible text; `aria-label` on icon-only buttons
- Hourly scroll strip: `role="list"` with `role="listitem"`, `tabIndex={0}`, scroll-snap
- Color is never the sole signal (pair with icon/text)
- Heading levels in document order, no skipped levels
- `aria-live="polite"` on dynamically updated content

### Reference Implementation
- **WindCompassCard** (`src/components/WindCompassCard.tsx`): The C2 reference for how a card is structured — Card + CardHeader + CardContent, Phosphor icon in header, Outfit for stat numerals, tabular-nums, muted/foreground color contrast, sr-only descriptions, aria-live.

---

## Data Changes Required

### 1. `useForecast` hook parameterization

The hook currently takes no arguments and defaults to 12 hours. The forecast page needs 48 hours (Today+Tomorrow tabs).

**Change:** Make `useForecast` accept an optional `{ hours?: number }` config. Pass `?hours=N` in the `getForecast` call to `/api/v1/forecast`. The API already supports this parameter (default 12, max 384).

**Files:**
- `src/hooks/useWeatherData.ts` — add optional param to `useForecast()`
- `src/api/client.ts` — add `hours` query param to `getForecast()`

### 2. i18n keys

New translation keys in `en/forecast.json` (and other locales):
- Tab labels: `forecast.tabToday`, `forecast.tabTomorrow`, `forecast.tab7Day`
- Expandable: `forecast.moreDetail`, `forecast.lessDetail`
- Discussion: `forecast.discussion`, `forecast.discussionIssuedAt`, `forecast.discussionOff`
- Column labels: `forecast.humidity`, `forecast.windGust`, `forecast.cloudCover`
- Accessibility: `forecast.ariaTabList`, `forecast.ariaDailyTrend`, `forecast.ariaExpandRow`

---

## Phase 1: Mockups (Step 3)

### Deliverable 1a: Now-page forecast card mockup
**File:** `docs/design/mockups/C3-now-forecast-card.html`

Shows the tabbed forecast card at its locked 2×1 footprint on the Now-page grid (reuse A4 grid CSS). Two states visible (or side-by-side): Today tab (hourly strip with trend line) and 7-Day tab (daily rows with dot-line trend). Uses real typography tokens (Manrope/Outfit/Lexend @fontsource woff2 from `docs/design/mockups/fonts/`). Uses real glass surface tokens and dusk-gradient backdrop from A4 mockup.

**Render and LOOK** before sending to lead. Headless Edge screenshot, inspect PNG, fix issues, re-render.

### Deliverable 1b: Forecast page mockup
**File:** `docs/design/mockups/C3-forecast-page.html`

Shows the full `/forecast` page layout: PageHeaderCard + Hourly Card (4×2, Today tab shown, with expanded detail rows visible) + 7-Day Card (4×2, with one day expanded) + Discussion Card. Uses the same A4 grid system. Same typography and glass tokens.

**Render and LOOK** before sending to lead.

### Mockup Agent Prompt

```
## C3 Forecast — Mockup Agent Brief

**Round:** C3 mockup
**Date:** 2026-05-31
**Lead:** Opus (orchestration)
**Agent:** Sonnet (mockup)

### Task
Build two HTML mockup files for the C3 forecast cards. Render each headless, LOOK at the PNG, fix visual issues, re-render until correct. Do NOT declare done until you have viewed the rendered image and confirmed it matches intent.

### Git restrictions
You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report. Do not resolve it yourself.

### Reading list (read BEFORE building)
1. `docs/design/mockups/A4-card-grid.html` — copy the CSS verbatim for: `:root` tokens, `.card`, `.card-title`, `.fp-badge`, `.grid-4col`, `.col-span-*`, `.row-span-*`, `.frame--4col` backdrop gradient. Do NOT invent your own card/grid CSS.
2. `docs/design/design-tokens-typography.md` — the LOCKED type tokens. Use the exact font families, sizes, and weights specified. Card title = Manrope 600 0.82rem. Body = Manrope 400 0.9rem. Labels = Manrope 400 0.75rem. Stat numerals = Outfit.
3. `docs/design/mockups/C2-current-wind.html` — reference for how a card mockup is structured on the real grid. Match the pattern.
4. `docs/design/inspiration/NOTES.md` — locked design direction. Key forecast signals:
   - img-02: PRIMARY hourly column model (time/icon/temp/precip%/wind vertical stack)
   - img-12: time-range tabs (Today/Tomorrow/Week)
   - img-15/24/26: temp trend line connecting forecast temps
5. The seven inspiration images (img-02.jpg, img-07.jpg, img-09.jpg, img-12.jpg, img-15.webp, img-24.jpg, img-26.jpg) — open each as an IMAGE and study the forecast layouts before designing.

### Scope IN
- `docs/design/mockups/C3-now-forecast-card.html` — Now-page forecast card
- `docs/design/mockups/C3-forecast-page.html` — Forecast page layout

### Scope OUT — do NOT touch
- Any file in `repos/` (no code changes)
- Any file outside `docs/design/mockups/`
- Do NOT add toggles, ghost cards, galleries, annotation panels, or any UI element not specified below

### Deliverable 1a: C3-now-forecast-card.html

Build a mockup showing the Now-page forecast card at its locked 2×1 footprint.

**Layout:** Use the A4 `.grid-4col` with the `.frame--4col` dusk-gradient backdrop (copy from A4-card-grid.html). Place the forecast card at `col-span-2 row-span-1`. Surround it with 2-3 placeholder neighbor cards (Current Conditions 2×2, Wind Compass 2×2) to show context — these are plain boxes with just a title, NOT detailed.

**Card structure:**
- CardTitle: calendar icon + "Today's Forecast" (Manrope 600, 0.82rem, thin underline rule)
- Tab strip: two pill buttons — "Today" (active, accent) | "7-Day" — below the title, above content. Style: small pills (0.75rem Manrope 600), active = accent bg + white text, inactive = muted bg + muted text.

**Today tab content (hourly strip):**
- Horizontally scrollable flex row, scroll-snap-x
- 8-10 sample columns visible (use times like 2 PM, 3 PM, 4 PM...)
- Each column (~60px wide, flex-shrink-0):
  - Time: "2 PM" (Manrope 400, 0.75rem, muted)
  - Weather icon: 24px placeholder (use a simple SVG sun/cloud circle, colored gold/grey — NOT the real Material SVG, just a recognizable shape)
  - Temperature: "72°" (Outfit 600, 0.85rem, foreground)
  - Precip: droplet icon + "15%" (0.7rem, muted) — hide if 0%
  - Wind: small arrow ↑ rotated + "8" (0.7rem, muted)
- SVG temp trend line: a polyline connecting the temperature values across columns. Accent blue stroke (2px), no fill. The line threads between the temperature row and the precip row.
- Right-edge fade gradient (pointer-events-none) to indicate scrollability

**7-Day tab content (daily rows):**
- Show both tabs side-by-side on the mockup (two frames, labeled "Today tab" and "7-Day tab") so both states are visible for review. Each frame is a copy of the card at 2×1 footprint.
- 7 rows, each row is a flex row:
  - Day: "Wed" or "Today" (Manrope 600, 0.85rem)
  - Icon: 24px weather placeholder
  - Hi: "78°" (Outfit 600, 0.85rem, color var(--temp-hi) = #c81e1e)
  - Lo: "62°" (Outfit 600, 0.85rem, color var(--temp-lo) = #1d4ed8)
  - Precip: droplet + "20%" (0.7rem, muted)
  - Wind: "12 mph" (0.7rem, muted)
- Connected dot-line trend through daily high temps (accent blue, 2px stroke, dots at each day)
- The trend line runs horizontally through the hi-temp column area

**Fonts:** Self-host Manrope 400/600/700 and Outfit 400/600 woff2 from `docs/design/mockups/fonts/` (they already exist from C2pre mockup). Load via @font-face.

**Colors:** Use CSS custom properties from A4-card-grid.html. Support both light and dark via `prefers-color-scheme`. Use `--temp-hi: #c81e1e` and `--temp-lo: #1d4ed8` for light; `#f87171` and `#93c5fd` for dark. Accent blue for trend lines: use `oklch(0.48 0.22 260)` light / `oklch(0.70 0.15 260)` dark.

### Deliverable 1b: C3-forecast-page.html

Build a mockup showing the full `/forecast` page layout.

**Layout:** Use the `.grid-4col` + `.frame--4col` from A4. The page contains (in order):
1. PageHeaderCard (full, 1 row): "Forecast" title + "Updated 3 hours ago · Open-Meteo" info text
2. Hourly Card (4×2): `col-span-4 row-span-2`
3. 7-Day Card (4×2): `col-span-4 row-span-2`
4. Discussion Card (4×auto): `col-span-4`, auto height

**Hourly Card (Surface B):**
- CardTitle: clock icon + "Hourly Forecast"
- Tab strip: "Today" (active) | "Tomorrow" pills
- Scrollable hourly columns (same structure as Surface A but LARGER):
  - Column width: ~72px
  - Icon: 32px
  - Temperature: Outfit 600, 0.9rem
  - All other fields same as Surface A but slightly larger text
- SVG temp trend line
- Below the main strip: "More detail" text button (Manrope 600, 0.75rem, accent color)
- EXPANDED state shown: when expanded, extra rows appear below the wind row:
  - Humidity: droplet icon + "65%" (0.7rem, muted)
  - Gust: wind icon + "18" (0.7rem, muted)
  - Cloud: cloud icon + "40%" (0.7rem, muted)
- Show the card in expanded state so the operator can see the full detail

**7-Day Card (Surface C):**
- CardTitle: calendar icon + "7-Day Forecast"
- 7 daily rows (wider than Surface A — more room for data):
  - Day + date: "Wednesday, Jun 4" (Manrope 600/400, 0.9rem)
  - Icon: 32px
  - Hi/Lo: Outfit 600, 0.9rem, themed colors
  - Connected dot-line trend
  - Precip: droplet + "%"
  - Wind: "15 mph"
  - UV: colored dot + "High" (EPA category)
- One row shown expanded (e.g., Wednesday): additional detail below:
  - Wind gust: "22 mph"
  - Sunrise/Sunset times
  - Narrative: "Partly cloudy with a chance of afternoon showers..." (if available, Manrope 400, 0.85rem, muted)
  - NOTE: DailyForecastPoint has NO humidity/cloudCover fields — daily expansion shows windGustMax, sunrise/sunset, narrative only

**Discussion Card (Surface D):**
- CardTitle: newspaper icon + "Forecast Discussion"
- Headline: "Area Forecast Discussion" (Manrope 600, 0.9rem)
- Body: 2-3 sentences of sample AFD text (Manrope 400, 0.9rem, foreground)
- Footer: "Issued 2:30 PM EDT · NWS Boston MA" (Manrope 400, 0.75rem, muted)

### Render-and-LOOK process (MANDATORY)
After building each mockup:
1. Render headless: `& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu --screenshot="C:\tmp\C3-now.png" --window-size=1400,900 "file:///path/to/mockup.html"`
2. Read the PNG with the Read tool and LOOK at it
3. Check: Are fonts correct (Manrope for titles/labels, Outfit for temps)? Are sizes proportional? Is the card within its 2×1 or 4×2 footprint? Are colors correct (accent blue trend line, themed hi/lo temps)? Is the glass surface visible over the dusk gradient?
4. Fix any visual issues and re-render
5. Only report done after the final render looks correct

### Verification command
Render both mockups headless and confirm: (a) card sits within its locked footprint, (b) typography matches tokens, (c) trend lines visible, (d) tab states clear, (e) expandable detail visible on forecast page mockup.

### Deliverable definition
Two HTML files in `docs/design/mockups/` + two rendered PNGs in `C:\tmp\`. Lead will inspect the PNGs (not the HTML) before approving.
```

---

## Phase 2: Code Implementation (Step 4)

### Pre-flight verification (lead does before dispatching)
- `git status` on `repos/weewx-clearskies-dashboard/`
- `git log --oneline -1` on the dashboard repo
- Confirm no uncommitted changes that would conflict

### Files to CREATE
1. `src/components/forecast/HourlyStrip.tsx` — Shared hourly column strip (scrollable, accepts compact/expanded mode)
2. `src/components/forecast/DailyList.tsx` — Shared daily row list (accepts compact/expanded mode)
3. `src/components/forecast/TempTrendLine.tsx` — SVG polyline trend line component
4. `src/components/forecast/NowForecastCard.tsx` — Tabbed card for Now page (Surface A)
5. `src/components/forecast/ForecastHourlyCard.tsx` — Full hourly card for forecast page (Surface B)
6. `src/components/forecast/ForecastDailyCard.tsx` — Full 7-day card for forecast page (Surface C)
7. `src/components/forecast/ForecastDiscussionCard.tsx` — Discussion card (Surface D)

### Files to MODIFY
1. `src/routes/now.tsx` — Replace the text-only forecast card with `<NowForecastCard>`
2. `src/routes/forecast.tsx` — Rewrite to use new card components + PageHeaderCard
3. `src/hooks/useWeatherData.ts` — Add optional `{ hours?: number }` param to `useForecast()`
4. `src/api/client.ts` — Pass `?hours=N` to `/api/v1/forecast`
5. `public/locales/en/forecast.json` — Add new i18n keys
6. `public/locales/en/common.json` — Add shared labels if needed

### Files NOT to touch
- `src/components/ui/card.tsx` — Card primitive is stable
- `src/components/layout/grid.tsx` — Grid is stable
- `src/components/weather-icon.tsx` — Icon mapping is stable
- `src/components/WindCompassCard.tsx` — C2 is done
- `src/index.css` — Typography/color tokens are LOCKED
- Any file in `src/routes/` other than `now.tsx` and `forecast.tsx`
- Any file outside the dashboard repo

### Code Agent Prompt

```
## C3 Forecast — Code Agent Brief

**Round:** C3 code
**Date:** 2026-05-31
**Lead:** Opus (orchestration)
**Agent:** Sonnet (implementation)

### Task
Implement the C3 forecast cards from the approved mockups. Four surfaces: (A) Now-page tabbed forecast card, (B) forecast page hourly card, (C) forecast page 7-day card, (D) forecast page discussion card.

### Git restrictions
You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report. Do not resolve it yourself.

### Scope acknowledgment
BEFORE writing any code, report to the lead via SendMessage with:
1. What you will deliver (list of files to create/modify)
2. What you will NOT touch
3. The verification command you will run before reporting done

Wait for lead confirmation before proceeding.

### Reading list (read in this order BEFORE coding)
1. The APPROVED mockups:
   - `docs/design/mockups/C3-now-forecast-card.html`
   - `docs/design/mockups/C3-forecast-page.html`
2. `src/components/WindCompassCard.tsx` — reference implementation pattern (Card structure, Outfit numerals, Phosphor icons, aria patterns, ConvertedValue handling)
3. `src/routes/now.tsx` — understand current forecast card location (lines 296-327) and how data hooks are called
4. `src/routes/forecast.tsx` — understand current hourly strip and daily grid structure
5. `src/api/types.ts` — ForecastBundle, HourlyForecastPoint, DailyForecastPoint, ForecastDiscussion type definitions
6. `src/hooks/useWeatherData.ts` — useForecast hook (lines 169-190)
7. `src/api/client.ts` — getForecast function
8. `src/utils/wind.ts` — cardinalFromDegrees function
9. `src/components/weather-icon.tsx` — WeatherIcon component API
10. `docs/design/design-tokens-typography.md` — LOCKED typography tokens (do NOT invent font sizes)
11. `src/index.css` — CSS custom properties (verify token names)

### Implementation spec

#### 1. Data layer changes

**`src/api/client.ts`:** Modify `getForecast` to accept optional `hours` param:
```ts
export async function getForecast(signal: AbortSignal, opts?: { hours?: number }): Promise<...> {
  const params = new URLSearchParams();
  if (opts?.hours) params.set('hours', String(opts.hours));
  // existing fetch with params appended to URL
}
```

**`src/hooks/useWeatherData.ts`:** Modify `useForecast` to accept config:
```ts
export function useForecast(config?: { hours?: number }): HookResult<ForecastBundle> {
  const hours = config?.hours;
  const { data, ... } = useApiQuery(
    (signal) => getForecast(signal, { hours }),
    { skip: isMockMode(), deps: [hours] },
  );
  // rest unchanged
}
```

#### 2. Shared components (`src/components/forecast/`)

**`TempTrendLine.tsx`:**
- Props: `temps: (number | null)[]`, `width: number`, `height: number`, `className?: string`
- Renders an SVG with a polyline connecting non-null temp values
- Stroke: `var(--primary)` (accent blue), 2px, no fill
- Dots: small circles (r=3) at each data point
- Skip null values (don't draw segment to/from null)
- Responsive: viewBox-based, scales to container

**`HourlyStrip.tsx`:**
- Props: `hours: HourlyForecastPoint[]`, `compact?: boolean` (default false), `expanded?: boolean` (default false)
- Renders a horizontally scrollable flex container with scroll-snap
- Container: `role="list"`, `aria-label={t('ariaHourlyList')}`, `tabIndex={0}`
- Each column: `role="listitem"`, `min-w-[60px]` (compact) or `min-w-[72px]` (full), `scroll-snap-align-start`
- Column content (top to bottom):
  1. Time: `Intl.DateTimeFormat` with station timezone, 12h format (Manrope 400, `--text-label`)
  2. `<WeatherIcon code={hour.weatherCode} size={compact ? 24 : 32} />`
  3. Temperature: `hour.outTemp` + unit (Outfit 600, compact ? `--text-secondary` : `--text-body`)
  4. Precip: if `hour.precipProbability > 0`: Phosphor `<Drop>` + percent (Manrope 400, `--text-micro`)
  5. Wind: if `hour.windDir !== null`: rotated arrow SVG + `hour.windSpeed` + unit (Manrope 400, `--text-micro`). Cardinal via `cardinalFromDegrees` for aria-label only.
  6. EXPANDED ONLY (when `expanded && !compact`): humidity (`hour.outHumidity`), gust (`hour.windGust`), cloud (`hour.cloudCover`) — each with Phosphor icon + value. Provider-gated: skip row if ALL hours have null for that field.
- `TempTrendLine` component overlaid between temp and precip rows via absolute positioning within the scroll container
- Right-edge fade gradient (CSS mask or linear-gradient overlay)

**`DailyList.tsx`:**
- Props: `days: DailyForecastPoint[]`, `compact?: boolean`, `expandedDay?: string | null`, `onToggleDay?: (validDate: string) => void`, `showTrend?: boolean`
- Renders a vertical list of day rows
- Each row: flex row, click handler (when `onToggleDay` provided) toggles expansion
- Row content:
  1. Day: "Today" or locale weekday (Manrope 600, compact ? `--text-secondary` : `--text-body`)
  2. Date: short date if not compact (Manrope 400, `--text-label`, muted)
  3. `<WeatherIcon code={day.weatherCode} size={compact ? 24 : 32} />`
  4. Hi: `day.tempMax` (Outfit 600, `color: var(--temp-hi)`)
  5. Lo: `day.tempMin` (Outfit 600, `color: var(--temp-lo)`)
  6. Precip: if > 0, `<Drop>` + percent
  7. Wind: `day.windSpeedMax` + unit (no direction — daily has no windDir)
  8. UV: if `day.uvIndexMax !== null` and not compact: color dot + EPA category label
- Expanded detail (when `expandedDay === day.validDate`):
  - Below the row, indented panel with: windGustMax (if present), sunrise/sunset times, narrative text. NOTE: DailyForecastPoint has NO humidity or cloudCover fields — daily expansion is limited to what the contract provides.
  - `aria-expanded` on the row, detail panel has `role="region"`
- TempTrendLine: if `showTrend`, render `TempTrendLine` with daily high temps, positioned alongside the hi-temp column

#### 3. Surface A: NowForecastCard

**`NowForecastCard.tsx`:**
- Props: `forecast: ForecastBundle | null`, `loading: boolean`, `error: Error | null`, `stationTz?: string`
- Uses `<Card footprint="wide">` (NOT rowSpan 2 — the A4 mockup shows 2×1)
- CardHeader: `<h2>` with calendar icon + `t('todaysForecast')`
- Tab strip: two buttons (role="tablist" / "tab") — "Today" and "7-Day"
- Uses React state: `activeTab: 'today' | '7day'`
- Today tab: `<HourlyStrip hours={todayHours} compact />`
  - `todayHours`: filter `forecast.hourly` to next 24 hours from now
- 7-Day tab: `<DailyList days={forecast.daily} compact showTrend />`
- Loading: TileSkeleton
- Error: TileError with retry
- No data: fallback text

#### 4. Surface B: ForecastHourlyCard

**`ForecastHourlyCard.tsx`:**
- Props: `forecast: ForecastBundle | null`, `loading: boolean`, `error: Error | null`, `stationTz?: string`
- Uses `<Card footprint="full" rowSpan={2}>`
- CardHeader: clock icon + `t('forecast.hourlyForecast')`
- Tab strip: "Today" | "Tomorrow" (same WAI-ARIA tab pattern)
- State: `activeTab: 'today' | 'tomorrow'`, `expanded: boolean`
- Today: filter hourly to today's hours. Tomorrow: filter to tomorrow's hours.
- `<HourlyStrip hours={filteredHours} expanded={expanded} />`
- Below strip: "More detail" / "Less detail" toggle button
- Loading/error/empty states

#### 5. Surface C: ForecastDailyCard

**`ForecastDailyCard.tsx`:**
- Props: `forecast: ForecastBundle | null`, `loading: boolean`, `error: Error | null`, `stationTz?: string`
- Uses `<Card footprint="full" rowSpan={2}>`
- CardHeader: calendar icon + `t('forecast.sevenDayForecast')`
- State: `expandedDay: string | null`
- `<DailyList days={forecast.daily.slice(0, 7)} expandedDay={expandedDay} onToggleDay={setExpandedDay} showTrend />`
- Loading/error/empty states

#### 6. Surface D: ForecastDiscussionCard

**`ForecastDiscussionCard.tsx`:**
- Props: `discussion: string | ForecastDiscussion | null`, `stationTz?: string`
- Self-hides (returns null) when discussion is null or empty
- Uses `<Card footprint="full">`
- CardHeader: newspaper icon + `t('forecast.discussion')`
- If discussion is string: render as body text
- If discussion is ForecastDiscussion object: headline + body + footer ("Issued {time} · {senderName}")
- Body: `whitespace-pre-wrap` for AFD line breaks (Manrope 400, `--text-body`)
- Footer: Manrope 400, `--text-label`, muted

#### 7. Page wiring

**`now.tsx`:** Replace lines 296–327 (the text-only forecast card) with:
```tsx
<NowForecastCard
  forecast={forecast}
  loading={fcLoading}
  error={fcError}
  stationTz={station?.timezone}
/>
```
Remove the `todayForecast` derivation if it was only used by the old card. Keep `hourlyForecast` prop to CurrentConditionsCard (it's used there for the temp curve).

**`forecast.tsx`:** Rewrite the page to use:
```tsx
<Grid>
  <PageHeaderCard title={t('forecast.title')} info={freshnessText} />
  <ForecastHourlyCard forecast={forecast} loading={fcLoading} error={fcError} stationTz={station?.timezone} />
  <ForecastDailyCard forecast={forecast} loading={fcLoading} error={fcError} stationTz={station?.timezone} />
  <ForecastDiscussionCard discussion={forecast?.discussion ?? null} stationTz={station?.timezone} />
</Grid>
```
Call `useForecast({ hours: 48 })` for the forecast page.
Preserve the existing AlertBanner at the top.
Remove the old hourly strip and daily grid rendering.

#### 8. i18n keys

Add to `public/locales/en/forecast.json`:
```json
{
  "title": "Forecast",
  "tabToday": "Today",
  "tabTomorrow": "Tomorrow",
  "tab7Day": "7-Day",
  "hourlyForecast": "Hourly Forecast",
  "sevenDayForecast": "7-Day Forecast",
  "moreDetail": "More detail",
  "lessDetail": "Less detail",
  "discussion": "Forecast Discussion",
  "discussionIssuedAt": "Issued {{time}} · {{sender}}",
  "humidity": "Humidity",
  "windGust": "Gust",
  "cloudCover": "Cloud",
  "ariaTabList": "Forecast time range",
  "ariaExpandRow": "Show details for {{day}}",
  "ariaDailyTrend": "Temperature trend for the week"
}
```
Keep all existing keys that other pages may use.

### Verification command
From the dashboard repo root:
```
npx tsc --noEmit && npx vite build
```
Expected: 0 TypeScript errors, clean Vite build.

### Deliverable definition
Lead will see in `git log`:
- N commits on the dashboard repo implementing C3
- `npx tsc --noEmit` → 0 errors
- `npx vite build` → clean build
- All four surfaces implemented per the approved mockups
- No regressions to existing pages (now.tsx still renders all other cards, forecast.tsx preserves AlertBanner)
```

---

## QC Gates

### Gate 1: Mockup approval (lead visual review)
- Lead renders both mockups headless, opens PNGs, confirms:
  - [ ] Card sits within locked footprint (2×1 for Now, 4×2 for page cards)
  - [ ] Typography matches tokens (Manrope for titles/labels, Outfit for temps, correct sizes)
  - [ ] Trend lines visible and use accent blue
  - [ ] Tab states clearly distinguishable
  - [ ] Expandable detail visible on forecast page mockup
  - [ ] Glass surface + dusk gradient backdrop visible
  - [ ] Hi/Lo temps use `--temp-hi`/`--temp-lo` colors
  - [ ] Dark mode renders correctly (via prefers-color-scheme)
- Lead approves or requests changes before code phase begins

### Gate 2: Code type-check and build
- `npx tsc --noEmit` → 0 errors
- `npx vite build` → clean build, no warnings

### Gate 3: Visual verification (lead renders the live app)
- Start dev server on weather-dev
- Open `/` (Now page): confirm tabbed forecast card renders, both tabs work, trend lines visible
- Open `/forecast`: confirm hourly card (Today/Tomorrow tabs), 7-day card (expandable rows), discussion card (when data exists)
- Check both light and dark themes
- Check responsive: resize to tablet (2-col) and phone (1-col)

### Gate 4: Accessibility audit
- Run `npx @axe-core/cli http://localhost:PORT/forecast` → 0 new violations
- Keyboard walkthrough: Tab reaches all interactive elements, Arrow keys work in tab controls, Escape closes expanded detail
- Screen reader check: tab labels announced, expanded state announced, trend line has aria description

### Gate 5: Prompt faithfulness check
Walk the original user request and confirm every surface is delivered:
- [ ] Surface A: Now-page tabbed forecast card (Today hourly + 7-Day daily)
- [ ] Surface B: Forecast page hourly card (4×2, Today/Tomorrow tabs, expandable detail)
- [ ] Surface C: Forecast page 7-day card (4×2, expandable rows, trend line)
- [ ] Surface D: Forecast page discussion card (self-hides when null)
- [ ] Trend lines on all surfaces (hourly + daily)
- [ ] Expandable detail on forecast page only
- [ ] useForecast accepts hours param
- [ ] i18n keys added

---

## Completeness Checklist

| # | Deliverable | Surface | Status |
|---|---|---|---|
| 1a | C3-now-forecast-card.html mockup | A | ✅ `3760918` (v6, 6 iterations) |
| 1b | C3-forecast-page.html mockup | B+C+D | ✅ `3760918` (v6, 6 iterations) |
| 2 | Mockup PNGs rendered and approved | all | ✅ Gate 1 passed (light + dark) |
| 3 | TempTrendLine.tsx | shared | ✅ `c633efe` |
| 4 | HourlyStrip.tsx | shared | ✅ `19d7d7d` |
| 5 | DailyColumns.tsx (was DailyList) | shared | ✅ `19d7d7d` |
| 5b | WindSymbol.tsx (added during mockup iteration) | shared | ✅ `c633efe` |
| 6 | NowForecastCard.tsx | A | ✅ `3eba666` |
| 7 | ForecastHourlyCard.tsx | B | ✅ `64889ad` |
| 8 | ForecastDailyCard.tsx | C | ✅ `64889ad` |
| 9 | ForecastDiscussionCard.tsx | D | ✅ `64889ad` |
| 10 | now.tsx updated (old card replaced) | A | ✅ `3eba666` |
| 11 | forecast.tsx rewritten (new cards + PageHeaderCard) | B+C+D | ✅ `64889ad` |
| 12 | useForecast + getForecast parameterized (hours) | data | ✅ `efdc746` |
| 13 | i18n keys added (en/forecast.json) | all | ✅ `efdc746` (13 keys) |
| 14 | tsc 0 errors | QC | ✅ Lead-verified |
| 15 | vite build clean | QC | ✅ Lead-verified (611ms) |
| 16 | Visual verification (both themes, responsive) | QC | ⏳ Pending deploy to weather-dev |
| 17 | axe-core 0 new violations | QC | ⏳ Pending deploy to weather-dev |
| 18 | Keyboard/a11y walkthrough | QC | ⏳ Pending deploy to weather-dev |

---

## Agent Roles Summary

| Role | Model | Responsibilities |
|---|---|---|
| **Lead** | Opus | Orchestration, mockup approval (visual review of PNGs), code review, QC gates, git commit, judgment calls |
| **Mockup agent** | Sonnet | Build HTML mockups per spec, render headless, inspect renders, iterate until correct |
| **Code agent** | Sonnet | Implement React components per approved mockups, add i18n keys, modify hooks/routes, run tsc+build |

The lead does NOT write code, build mockups, or run tsc. The lead inspects rendered PNGs and reviews git diffs. Agents do NOT push to remote.
