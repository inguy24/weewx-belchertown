# GRID-NORMALIZATION-PLAN — Page template, chart containers, quarter-row grid track

**Goal:** Eliminate per-page layout duplication, create shared containers for charts and controls, introduce a quarter-row grid track for control strips, and align the implementation with ADR-051 (amended for mobile responsiveness and quarter-row). Every page must use the same template. Every chart container must follow shared sizing rules. No ad-hoc padding hacks on cards.

**Status:** Complete (2026-06-13). All phases executed, deployed to weather-dev.

**Repo:** `weewx-clearskies-dashboard` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`)

**Dev/test environment:** `weather-dev` LXD container. Dashboard source at `/home/ubuntu/repos/weewx-clearskies-dashboard`. Deploy via `scripts/redeploy-weather-dev.sh` (full) or `scripts/sync-to-weather-dev.sh` (source-only).

---

## Orientation — read before executing any task

**Load these before every session:**
1. [CLAUDE.md](../../CLAUDE.md) — domain routing, operating rules
2. [rules/coding.md](../../rules/coding.md) — code standards, accessibility requirements
3. [rules/clearskies-process.md](../../rules/clearskies-process.md) — process discipline, agent orchestration
4. [docs/ARCHITECTURE.md](../ARCHITECTURE.md) — system architecture (read first, before ADRs)
5. [ADR-051](../decisions/ADR-051-card-footprint-model.md) — card footprint model (the spec this plan enforces)
6. This plan — current task status and context

**Git safety:** Agents do NOT push. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No worktree isolation for implementation — all work in the primary local checkout. Coordinator commits after QC.

**QC model:** Opus provides QC at every task. QC is NOT "is the code well-written" — it is:
- Does the change do what the task says it should do?
- Does it comply with this plan, ADR-051 (as amended), and ARCHITECTURE.md?
- Does it introduce regressions on other viewports or pages?
- Is the acceptance criteria met (verified by running the check, not trusting the agent's claim)?

**No deferrals.** Every task in this plan is mandatory. Agents do not get to say "deferred to a future round." If a task is blocked, the agent reports the blocker and the coordinator resolves it. The task does not close until acceptance criteria are met.

**No improvisation.** Agents implement exactly what the task specifies. If a task says "change X to Y," the agent changes X to Y. If the agent discovers something unexpected, it reports via SendMessage and waits — it does not "fix" it autonomously.

---

## Root cause analysis

### Problem 1: No page template

All 9 pages build the same layout pattern from scratch:

```
<div className="flex flex-col gap-4">        ← outer wrapper (identical on all 9)
  <h1 className="sr-only">{t('title')}</h1>  ← sr-only heading (identical on 8/9)
  <Grid className="...">                     ← Grid with per-page className overrides
    <PageHeaderCard ... />                    ← title card (8/9 use PageHeaderCard, Now uses NowHeroCard)
    {/* cards */}
  </Grid>
</div>
```

**Inconsistencies found:**

| Page | Grid className override | Notes |
|------|------------------------|-------|
| Now | None (default) | Only page using default grid tracks. NowHeroCard outside grid. |
| Forecast | `md:auto-rows-[auto]` | Bypasses track system |
| Charts | `md:auto-rows-[auto]` | Bypasses track system |
| Almanac | `md:auto-rows-[auto]` | Bypasses track system |
| Seismic | `lg:flex-1 min-h-0 content-start lg:grid-rows-[auto_1fr]` | Unique viewport-filling layout |
| Records | `md:auto-rows-[auto]` | Bypasses track system |
| Reports | `md:auto-rows-[auto]` | Bypasses track system |
| About | `md:auto-rows-[auto]` | Bypasses track system |
| Legal | `md:auto-rows-[auto]` | Bypasses track system |

7 of 9 pages override Grid to `md:auto-rows-[auto]`, bypassing the track system ADR-051 specifies.

### Problem 2: Control strips hacked, ControlsStrip unused

A `ControlsStrip` component exists at `src/components/layout/controls-strip.tsx` (lines 53-78) but **zero pages use it**. Instead:

- **Charts** (charts.tsx:153): `<Card footprint="full" className="py-2 px-4 min-h-[var(--card-half-row)]">` — ad-hoc card with padding hack
- **Records** (records.tsx:152): `<Card footprint="full" className="py-2 min-h-[var(--card-half-row)]">` — ad-hoc card with padding hack
- **Reports** (reports.tsx:700): `<Card footprint="full">` — full-height card, no compact styling at all
- **Seismic** (seismic.tsx:219): `info` prop on PageHeaderCard bloats the header beyond half-row

### Problem 3: No quarter-row in ADR-051

ADR-051 defines half-row (5.5rem) as the smallest grid unit. Control strips (buttons, dropdowns) are functionally thinner than 5.5rem. There is no `--card-quarter-row` token. Control strips were hacked with `py-2` to appear compact inside half-row cards.

### Problem 4: No shared chart container

Charts exist in 3 contexts with independent sizing:

| Context | System | Height | Files |
|---------|--------|--------|-------|
| Charts page | ConfigDrivenGroup/Chart | 300px normal, 400px fullscreen | `src/components/charts/ConfigDrivenGroup.tsx`, `ConfigDrivenChart.tsx` |
| Almanac monthly averages | Inline Recharts ComposedChart | 300px | `src/routes/almanac.tsx` (MonthlyAveragesCard) |
| Now-page tile cards | Inline Recharts per card | `maxHeight: var(--card-content-max)` | solar-radiation-card, uv-index-card, lightning-card, current-conditions-card |

The Almanac chart duplicates the ConfigDriven sizing logic independently. Charts page and Almanac should share a container.

Now-page tile-card charts are a different use case (mini-charts in 1x1 cards constrained by `--card-content-max`). They stay separate — they are NOT full-page charts.

### Problem 5: Mobile tokens undocumented

Today's FIXIT-UI session added responsive token values:
- `--card-row`: 13rem mobile, 11rem desktop (md+)
- `--card-half-row`: 6.5rem mobile, 5.5rem desktop
- `--card-content-max`: `calc(var(--card-row) - 4rem)` = 9rem mobile, 7rem desktop

These are not documented in ADR-051.

---

## Design decisions

### D1. Grid base track = quarter-row, row-gap = 0

The grid base track becomes `--card-quarter-row`. Row gap is removed from the grid; vertical card spacing comes from card bottom margins instead. This eliminates gap-inflated row arithmetic.

**Track arithmetic (desktop md+):**
- `--card-quarter-row`: 2.75rem
- 1 track (quarter-row strip): 2.75rem
- 2 tracks (half-row header): 5.5rem
- 4 tracks (data card): 11rem
- 8 tracks (tall card): 22rem

**Mobile (<768px):** Grid stays `auto-rows-[auto]` (content-driven). Cards enforce min-h via tokens.

**Mobile token values:**
| Token | Mobile (<768px) | Desktop (md+) |
|-------|----------------|---------------|
| `--card-quarter-row` | 3.25rem | 2.75rem |
| `--card-half-row` | 6.5rem | 5.5rem |
| `--card-row` | 13rem | 11rem |
| `--card-content-max` | 9rem | 7rem |

### D2. PageLayout template

New component `src/components/layout/page-layout.tsx`. Every page except Now uses it.

**Props:** `title`, `icon`, `controls?`, `gridClassName?`, `children`

**Renders:**
```tsx
<div className="flex flex-col gap-4">
  <h1 className="sr-only">{title}</h1>
  <Grid className={gridClassName}>
    <PageHeaderCard title={title} icon={icon} />
    {controls && <ControlsStrip>{controls}</ControlsStrip>}
    {children}
  </Grid>
</div>
```

**PageHeaderCard changes:** Remove `info` prop entirely. Title + icon only. The seismic config summary moves to a ControlsStrip.

### D3. Card row-span model

| Card role | rowSpan prop | md+ class | Desktop height | Mobile min-h |
|-----------|-------------|-----------|----------------|-------------|
| Control strip | `"quarter"` | `md:row-span-1` | 2.75rem | 3.25rem |
| Page header | `"half"` | `md:row-span-2` | 5.5rem | 6.5rem |
| Data card (default) | `1` | `md:row-span-4` | 11rem | 13rem |
| Tall card | `2` | `md:row-span-8` | 22rem | 26rem |

Card bottom margin `mb-[var(--gap-grid)]` replaces grid row-gap.

### D4. Shared ChartContainer

New component `src/components/charts/chart-container.tsx` wrapping ResponsiveContainer with consistent height (300px default). Used by ConfigDrivenChart and Almanac MonthlyAveragesCard. Now-page tile-card charts stay separate.

### D5. ADR-051 amendment

Add quarter-row track, mobile responsive tokens, row-gap=0 model, `--card-content-max` token, graphic container self-constraint rule.

---

## Phase 0 — ADR amendment

Write the spec before any code changes.

### T0.1 — Amend ADR-051

- **Owner:** Coordinator (Opus)
- **Dep:** None
- **Do:**
  1. Edit `docs/decisions/ADR-051-card-footprint-model.md`. Add an amendment section dated 2026-06-13.
  2. Add `--card-quarter-row` to the token table: 2.75rem (desktop), 3.25rem (mobile <768px).
  3. Change "grid base row track is the half-row" to "grid base row track is the quarter-row."
  4. Update the row-span model: strips=1 track, headers=2 tracks, data cards=4 tracks, tall cards=8 tracks.
  5. Document the row-gap=0 + card-margin spacing model: grid uses `gap-x` only; vertical spacing comes from card `margin-bottom`.
  6. Document mobile responsive token values: `--card-row` 13rem mobile / 11rem desktop, `--card-half-row` 6.5rem / 5.5rem, `--card-quarter-row` 3.25rem / 2.75rem.
  7. Add `--card-content-max: calc(var(--card-row) - 4rem)` to the token table. Document that graphic containers (gauges, arcs, charts in tile cards) self-constrain via `maxHeight: var(--card-content-max)`.
  8. Update acceptance criteria to include: quarter-row strips, mobile token override, no ad-hoc padding hacks on cards.
  9. Set amendment status to Proposed.
- **Accept:** ADR-051 amendment is complete, internally consistent, and covers all changes from this plan. User reviews and approves (status → Accepted) before Phase 1 begins.
- **QC:** Coordinator verifies token arithmetic: 4 × quarter = card-row, 2 × quarter = half-row, 8 × quarter = tall. Mobile values are proportional.

---

## Phase 1 — Grid and token foundation

Update the grid, card, and CSS token system. This phase touches 7 files and changes the fundamental sizing model. Every subsequent phase depends on it.

**Dep:** Phase 0 complete (ADR-051 amendment Accepted).

### T1.1 — CSS tokens

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T0.1
- **Do:**
  1. In `src/index.css` `@theme inline` block (line 18), add the quarter-row token after `--card-half-row`:
     ```css
     --card-quarter-row: 3.25rem;
     ```
  2. Verify `--card-half-row: 6.5rem` and `--card-row: 13rem` are the mobile defaults (they should be from today's work).
  3. In the `@media (min-width: 768px)` block (currently around line 131), add the desktop quarter-row override:
     ```css
     --card-quarter-row: 2.75rem;
     ```
  4. Verify `--card-half-row: 5.5rem` and `--card-row: 11rem` are set in the same media query.
  5. Verify `--card-content-max: calc(var(--card-row) - 4rem)` exists and derives correctly (9rem mobile, 7rem desktop).
  6. Do NOT change any other tokens.
- **Accept:**
  - `--card-quarter-row` resolves to 3.25rem at <768px and 2.75rem at ≥768px.
  - Token arithmetic: `--card-quarter-row × 4 = --card-row` (2.75×4=11, 3.25×4=13). ✓
  - Token arithmetic: `--card-quarter-row × 2 = --card-half-row` (2.75×2=5.5, 3.25×2=6.5). ✓
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus verifies the token values in index.css match the D1 table. Computes arithmetic to confirm proportionality.

### T1.2 — Grid component

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.1
- **Do:**
  1. In `src/components/layout/grid.tsx` line 47, change the gap class from:
     ```
     gap-[var(--gap-grid)]
     ```
     to:
     ```
     gap-x-[var(--gap-grid)] gap-y-0
     ```
  2. In the same file line 49, change the auto-rows class from:
     ```
     auto-rows-[auto] md:auto-rows-[var(--card-row)]
     ```
     to:
     ```
     auto-rows-[auto] md:auto-rows-[var(--card-quarter-row)]
     ```
  3. Update the component's JSDoc comments (lines 8-11 and 28-33) to reflect: base track is `--card-quarter-row`, row-gap is 0, vertical spacing via card margins.
  4. Do NOT change column definitions, container max-width, or gap-x value.
- **Accept:**
  - Grid has `gap-x-[var(--gap-grid)] gap-y-0` (column gap 1rem, row gap 0).
  - Grid has `md:auto-rows-[var(--card-quarter-row)]` (2.75rem tracks at md+).
  - Mobile stays `auto-rows-[auto]`.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus reads grid.tsx and confirms the two class changes. Loads the Now page at 1280px to verify the grid renders (cards may be misaligned until T1.3 updates row-spans — that is expected).

### T1.3 — Card component row-span and margin

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.2
- **Do:**
  1. In `src/components/ui/card.tsx`, update the `CardProps` type (line 17). Change `rowSpan?: 1 | 2` to `rowSpan?: "quarter" | "half" | 1 | 2`.
  2. Replace the `rowSpanClass` function (lines 38-41) with:
     ```typescript
     function rowSpanClass(rowSpan: "quarter" | "half" | 1 | 2 | undefined): string {
       switch (rowSpan) {
         case "quarter": return "md:row-span-1";
         case "half":    return "md:row-span-2";
         case 2:         return "md:row-span-8";
         default:        return "md:row-span-4";
       }
     }
     ```
  3. In the Card className (line 61), add bottom margin for vertical spacing:
     ```
     mb-[var(--gap-grid)]
     ```
  4. Update the `min-h-[var(--card-row)]` (line 62) to be responsive to rowSpan. For quarter-row cards the min-h should be `--card-quarter-row`, for half-row `--card-half-row`, for standard `--card-row`. This requires the Card component to select the min-h based on rowSpan. Use a helper function:
     ```typescript
     function minHeightClass(rowSpan: "quarter" | "half" | 1 | 2 | undefined): string {
       switch (rowSpan) {
         case "quarter": return "min-h-[var(--card-quarter-row)]";
         case "half":    return "min-h-[var(--card-half-row)]";
         default:        return "min-h-[var(--card-row)]";
       }
     }
     ```
  5. Replace the hardcoded `"min-h-[var(--card-row)]"` on line 62 with `minHeightClass(rowSpan)`.
  6. Update the JSDoc comments for `rowSpan` and `rowSpanClass` to document the new values and their desktop track counts.
- **Accept:**
  - `rowSpan="quarter"` → `md:row-span-1`, `min-h-[var(--card-quarter-row)]`
  - `rowSpan="half"` → `md:row-span-2`, `min-h-[var(--card-half-row)]`
  - `rowSpan={1}` (default) → `md:row-span-4`, `min-h-[var(--card-row)]`
  - `rowSpan={2}` → `md:row-span-8`, `min-h-[var(--card-row)]`
  - All cards have `mb-[var(--gap-grid)]` for vertical spacing.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus reads card.tsx and confirms the rowSpanClass and minHeightClass functions match the D3 table. Verifies the mb class is applied.

### T1.4 — PageHeaderCard sizing

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.3
- **Do:**
  1. In `src/components/layout/page-header-card.tsx` line 77, the Card renders with `className="py-2"`. Remove the `py-2` class.
  2. Add `rowSpan="half"` to the Card props (line 77). This makes the card use `md:row-span-2` and `min-h-[var(--card-half-row)]`.
  3. Remove the `min-h-[var(--card-half-row)]` from the className (line 79) — it's now handled by the Card's `minHeightClass`.
  4. Verify the card's internal content (title + icon) vertically centers correctly without `py-2`. The Card base has `py-4` padding; with half-row height (5.5rem = 88px) and py-4 (32px), the content area is 56px — enough for a title line. If content doesn't center, add `justify-center` to the Card's flex column, scoped to half-row cards only.
  5. Do NOT change the `info` prop yet — that moves in Phase 2.
- **Accept:**
  - PageHeaderCard renders at half-row height (5.5rem desktop, 6.5rem mobile).
  - No `py-2` hack in the className.
  - Title + icon are vertically centered within the card.
  - Consistent appearance across all pages that use PageHeaderCard.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus loads 3+ pages at 375px and 1280px. Confirms page headers are uniform height, no `py-2` in the code.

### T1.5 — ControlsStrip sizing

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.3
- **Do:**
  1. In `src/components/layout/controls-strip.tsx` line 59, the Card renders with `className="py-2"`. Remove the `py-2` class.
  2. Add `rowSpan="quarter"` to the Card props. This makes the card use `md:row-span-1` and `min-h-[var(--card-quarter-row)]`.
  3. Verify the internal content (buttons, dropdowns) fits within quarter-row height. Quarter-row is 2.75rem (44px) on desktop — exactly the WCAG minimum touch target. If content overflows, report the issue; do NOT change the quarter-row token.
  4. Update the JSDoc to say "quarter-row" instead of "half-row."
- **Accept:**
  - ControlsStrip renders at quarter-row height (2.75rem desktop, 3.25rem mobile).
  - No `py-2` hack.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus reads controls-strip.tsx and confirms rowSpan="quarter" and no py-2.

### T1.6 — NowHeroCard and AlertBanner cleanup

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.3
- **Do:**
  1. In `src/components/layout/now-hero-card.tsx` line 98, remove `py-2` and `min-h-[var(--card-half-row)]` from the className. Add `rowSpan="half"` to the Card props.
  2. In `src/components/shared/alert-banner.tsx` line 258, verify `min-h-[var(--card-half-row)]` is present on the outer div. Add `mb-[var(--gap-grid)]` for vertical spacing (since the alert banner is outside the grid, it needs its own margin).
  3. Do NOT change any other styling on these components.
- **Accept:**
  - NowHeroCard: no `py-2`, no manual `min-h`, uses `rowSpan="half"`.
  - AlertBanner: has `min-h-[var(--card-half-row)]` and `mb-[var(--gap-grid)]`.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus reads both files and confirms the changes.

### T1.7 — Desktop regression check (Phase 1 gate)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.4, T1.5, T1.6
- **Do:**
  1. Run `npx tsc --noEmit` — must be zero errors.
  2. Run `npm run build` — must complete successfully.
  3. Deploy to weather-dev via `scripts/redeploy-weather-dev.sh`.
  4. Load every page (Now, Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal) at 1280px. Verify: cards align to the quarter-row track grid, page headers are half-row, no orphaned gaps, no content clipping.
  5. Load every page at 375px. Verify: mobile cards size to content with correct min-h, page headers are half-row, no clipping.
  6. Note: control strip pages (Charts, Records, Reports) will still have ad-hoc Card wrappers — those are fixed in Phase 3. The grid tracks may not align perfectly on those pages until then. Document any issues but do NOT block Phase 1 on them.
- **Accept:**
  - `tsc` and `build` pass with zero errors.
  - Desktop: cards render at correct track heights. Now page: data cards at 11rem, tall cards at 22rem, page header at 5.5rem.
  - Mobile: cards render at correct min-h values. No content clipping.
  - Any control-strip misalignment on Charts/Records/Reports is documented for Phase 3.
- **QC:** Opus loads 4+ pages at 1280px and 375px. Confirms card heights match the D3 table.

---

## Phase 2 — PageLayout template

Create the shared page template and refactor all pages to use it.

**Dep:** Phase 1 complete (T1.7 passes).

### T2.1 — Create PageLayout component

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.7
- **Do:**
  1. Create `src/components/layout/page-layout.tsx`.
  2. Props interface:
     ```typescript
     interface PageLayoutProps {
       title: string;
       icon: React.ReactNode;
       controls?: React.ReactNode;
       gridClassName?: string;
       children: React.ReactNode;
     }
     ```
  3. Renders:
     ```tsx
     <div className="flex flex-col gap-4">
       <h1 className="sr-only">{title}</h1>
       <Grid className={gridClassName}>
         <PageHeaderCard title={title} icon={icon} />
         {controls && <ControlsStrip aria-label={`${title} controls`}>{controls}</ControlsStrip>}
         {children}
       </Grid>
     </div>
     ```
  4. Import Grid, PageHeaderCard, ControlsStrip.
  5. Add JSDoc: "Shared page template per GRID-NORMALIZATION-PLAN. All pages except Now use this."
  6. Do NOT add any state, hooks, or side effects. This is a pure layout component.
- **Accept:**
  - Component exists, exports `PageLayout`.
  - Props match the interface above.
  - Renders the exact structure above.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus reads the file and confirms the structure matches the spec exactly.

### T2.2 — Remove `info` prop from PageHeaderCard

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T2.1
- **Do:**
  1. In `src/components/layout/page-header-card.tsx`, remove the `info` prop from the `PageHeaderCardProps` type.
  2. Remove the `info` rendering block (the `<p>` element with `text-muted-foreground`).
  3. Remove the conditional `mb-0.5` className on the heading that depends on `info`.
  4. Remove the icon font-size conditional `info ? '2rem' : '1.5rem'` — always use `1.5rem`.
  5. Update JSDoc examples to remove `info` usage.
  6. In `src/routes/seismic.tsx` line 219, remove the `info={...}` prop from the PageHeaderCard call. The config summary will move to a ControlsStrip in Phase 3.
  7. Run `grep -r "info=" src/` to confirm no other file passes `info` to PageHeaderCard. (Only seismic does, based on prior research.)
- **Accept:**
  - PageHeaderCard has no `info` prop in its type or rendering.
  - Seismic page compiles without `info`.
  - No other file references `info` on PageHeaderCard.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus greps for `info=` across routes to confirm removal is complete.

### T2.3 — Refactor pages to use PageLayout

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T2.1, T2.2
- **Do:** For each of the following 8 pages, replace the boilerplate with `<PageLayout>`:

  **Forecast** (`src/routes/forecast.tsx`):
  - Remove outer div, sr-only h1, Grid, PageHeaderCard.
  - Wrap in `<PageLayout title={t('title')} icon={<CloudSun weight="duotone" />}>`.
  - No controls prop (tabs are inside the forecast cards, not a page-level strip).

  **Charts** (`src/routes/charts.tsx`):
  - Remove outer div, sr-only h1, Grid, PageHeaderCard.
  - Wrap in `<PageLayout title={t('title')} icon={<ChartLine weight="duotone" />} controls={...}>`.
  - The tab bar/dropdown moves to the `controls` prop. (Full ControlsStrip adoption is Phase 3 — for now, pass the existing control JSX as `controls`.)

  **Almanac** (`src/routes/almanac.tsx`):
  - Remove outer div, sr-only h1, Grid, PageHeaderCard.
  - Wrap in `<PageLayout title={t('pageTitle')} icon={<MoonStars weight="duotone" />}>`.

  **Seismic** (`src/routes/seismic.tsx`):
  - Remove outer div, sr-only h1, Grid, PageHeaderCard.
  - Wrap in `<PageLayout title={t('title')} icon={<Earthquake size={28} />} gridClassName="lg:flex-1 min-h-0 content-start lg:grid-rows-[auto_1fr]">`.
  - Outer div needs `lg:h-full` — add to PageLayout via an optional `outerClassName` prop if needed, or handle Seismic's viewport-fill at the route level (wrap PageLayout in a `<div className="lg:h-full">`).

  **Records** (`src/routes/records.tsx`):
  - Remove outer div, sr-only h1, Grid, PageHeaderCard.
  - Wrap in `<PageLayout title={t('title')} icon={<Trophy weight="duotone" />} controls={...}>`.
  - Period selector buttons move to `controls` prop.

  **Reports** (`src/routes/reports.tsx`):
  - Remove outer div, sr-only h1, Grid, PageHeaderCard.
  - Wrap in `<PageLayout title={t('title')} icon={<FileText weight="duotone" />} controls={...}>`.
  - Year/month selectors move to `controls` prop.

  **About** (`src/routes/about.tsx`):
  - Remove outer div, sr-only h1, Grid, PageHeaderCard.
  - Wrap in `<PageLayout title={t('title')} icon={<Info weight="duotone" />}>`.

  **Legal** (`src/routes/legal.tsx`):
  - Remove outer div, sr-only h1, Grid, PageHeaderCard.
  - Wrap in `<PageLayout title={t('title')} icon={<Scales weight="duotone" />}>`.

  **Now page**: Do NOT touch. It keeps its custom layout with NowHeroCard outside the grid.

- **Accept:**
  - All 8 pages use `<PageLayout>`. No page has its own outer div + sr-only h1 + Grid + PageHeaderCard boilerplate.
  - Now page is unchanged.
  - Every page renders visually identical to before the refactor (same cards, same order, same content).
  - No page passes `md:auto-rows-[auto]` to Grid — the PageLayout's Grid uses the default quarter-row track system.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus loads all 9 pages at 375px and 1280px. Confirms visual parity with pre-refactor state. Greps for `<Grid` in route files to confirm only PageLayout (and now.tsx) render Grids directly.

---

## Phase 3 — ControlsStrip adoption

Refactor pages with control/selector cards to use ControlsStrip at quarter-row height.

**Dep:** Phase 2 complete.

### T3.1 — Charts page controls

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T2.3
- **Do:**
  1. In `src/routes/charts.tsx`, the tab navigation is currently an ad-hoc `<Card footprint="full" className="py-2 px-4 min-h-[var(--card-half-row)]">` (line 153).
  2. Remove this Card wrapper entirely. Move the tab content (mobile `<select>` dropdown + desktop `<div role="tablist">` buttons) into the `controls` prop of PageLayout. ControlsStrip renders them.
  3. The mobile dropdown (`<select>`) and desktop tab bar (`role="tablist"`) both remain — they just move into the ControlsStrip wrapper.
  4. Remove the scroll indicator gradient div if it was part of the Card — it should be part of the controls content if needed.
  5. Verify keyboard navigation: Tab key focuses controls, Arrow keys move between tabs, Enter/Space activates.
- **Accept:**
  - No ad-hoc Card wrapper with `py-2 px-4` exists in charts.tsx.
  - Tab controls render inside ControlsStrip at quarter-row height.
  - Tab switching works on both mobile (dropdown) and desktop (buttons).
  - ARIA: `role="tablist"`, `role="tab"`, `aria-selected`, `aria-controls` all intact.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus loads Charts page at 375px and 1280px. Confirms tab switching works, controls are at quarter-row height, charts render correctly.

### T3.2 — Records page controls

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T2.3
- **Do:**
  1. In `src/routes/records.tsx`, the period selector is an ad-hoc `<Card footprint="full" className="py-2 min-h-[var(--card-half-row)]">` (line 152).
  2. Remove this Card wrapper. Move the two `<button>` elements (All Time / Year to Date) into the `controls` prop of PageLayout.
  3. Preserve `role="group"` and `aria-label` on the button group.
  4. Preserve `aria-pressed` toggle behavior.
- **Accept:**
  - No ad-hoc Card wrapper with `py-2` exists in records.tsx.
  - Period buttons render inside ControlsStrip at quarter-row height.
  - Toggle behavior (aria-pressed, visual active state) works correctly.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus loads Records page at 375px and 1280px. Confirms buttons work, data switches between periods.

### T3.3 — Reports page controls

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T2.3
- **Do:**
  1. In `src/routes/reports.tsx`, the selector card is `<Card footprint="full">` (line 700) containing year and month dropdowns.
  2. Remove this Card wrapper. Move the year `<select>` and month/annual `<select>` into the `controls` prop of PageLayout.
  3. Preserve the flex row layout and `gap-4` spacing between the two dropdowns.
  4. Preserve labels and ARIA attributes on both selects.
- **Accept:**
  - No ad-hoc selector Card exists in reports.tsx.
  - Year/month selectors render inside ControlsStrip at quarter-row height.
  - Both dropdowns function correctly and load report data on change.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus loads Reports page at 375px and 1280px. Selects a year and month, confirms report loads.

### T3.4 — Seismic page info strip

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T2.3
- **Do:**
  1. The seismic config summary (provider, radius, min magnitude, days) was removed from PageHeaderCard in T2.2. It needs a new home.
  2. Add a `controls` prop to the seismic page's PageLayout usage. Pass the config summary text as a `<p>` element with `text-muted-foreground text-sm` styling.
  3. The ControlsStrip will render this info line at quarter-row height below the title.
  4. Preserve the conditional rendering (only show when `config` is available).
- **Accept:**
  - Config summary renders below the page header in a ControlsStrip.
  - Renders at quarter-row height.
  - Conditionally shown only when earthquake config is loaded.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus loads Seismic page at 375px and 1280px. Confirms config summary is visible below the header.

---

## Phase 4 — Chart container

Create the shared chart wrapper for ConfigDriven charts.

**Dep:** Phase 1 complete. Can run in parallel with Phases 2-3.

### T4.1 — Create ChartContainer component

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T1.7
- **Do:**
  1. Create `src/components/charts/chart-container.tsx`.
  2. Props:
     ```typescript
     interface ChartContainerProps {
       height?: number;          // default 300
       fullscreenHeight?: number; // default 400
       ariaLabel: string;
       children: React.ReactNode;
     }
     ```
  3. Renders a `<div>` with `role="img"` and `aria-label`, wrapping a `<ResponsiveContainer width="99%" height={height}>` around children.
  4. Export as named export `ChartContainer`.
  5. Do NOT implement fullscreen toggle — just accept the prop for future use.
  6. Add JSDoc: "Shared chart sizing wrapper. Used by ConfigDrivenChart and any full-page chart. NOT used by Now-page tile-card mini-charts (those use --card-content-max)."
- **Accept:**
  - Component exists at the specified path.
  - Renders ResponsiveContainer at the specified height.
  - Has `role="img"` and `aria-label` for accessibility.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus reads the file and confirms the interface and rendering match the spec.

### T4.2 — Adopt ChartContainer in ConfigDrivenChart

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T4.1
- **Do:**
  1. In `src/components/charts/ConfigDrivenChart.tsx`, find where `ResponsiveContainer` is rendered with the chart height.
  2. Replace the ResponsiveContainer wrapper with `<ChartContainer height={...} ariaLabel={...}>`.
  3. The existing chart content (ComposedChart, axes, series) remains unchanged — only the outer wrapper changes.
  4. Verify the chart height is passed through correctly (300px default, 400px in fullscreen mode).
- **Accept:**
  - ConfigDrivenChart uses ChartContainer for its outer wrapper.
  - Charts page renders all chart groups at consistent height.
  - Fullscreen overlay charts render at 400px.
  - No visual regression on Charts page.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus loads Charts page, switches between tabs, confirms all charts render at 300px. Opens one chart fullscreen, confirms 400px.

### T4.3 — Adopt ChartContainer in Almanac MonthlyAveragesCard

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T4.1
- **Do:**
  1. In the Almanac's MonthlyAveragesCard component (in `src/routes/almanac.tsx` or `src/components/almanac/`), find where the Recharts ComposedChart is rendered with a fixed 300px height.
  2. Replace the inline ResponsiveContainer with `<ChartContainer height={300} ariaLabel="Monthly averages chart">`.
  3. The chart content (ComposedChart, axes, series) remains unchanged.
- **Accept:**
  - MonthlyAveragesCard uses ChartContainer.
  - Chart renders at 300px, same as before.
  - No visual regression on Almanac page.
  - `npx tsc --noEmit` zero errors.
- **QC:** Opus loads Almanac page at 375px and 1280px. Confirms monthly averages chart renders correctly.

---

## Phase 5 — Full regression check

**Dep:** Phases 1-4 all complete.

### T5.1 — Build and type check

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** All prior tasks
- **Do:**
  1. Run `npx tsc --noEmit` — zero errors.
  2. Run `npm run build` — completes successfully.
  3. Deploy to weather-dev.
- **Accept:** Build succeeds. Deployed to weather-dev.
- **QC:** Opus verifies build output shows zero errors.

### T5.2 — Desktop regression (1280px)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T5.1
- **Do:** Load every page at 1280px (lg). For each page verify:
  1. Page header card is half-row height (5.5rem).
  2. Control strip (if present) is quarter-row height (2.75rem).
  3. Data cards are standard height (11rem track).
  4. Tall cards (wind, radar, webcam) are double height (22rem track).
  5. No orphaned gaps between cards.
  6. Card content is not clipped.
  7. Charts render at 300px height.
- **Accept:** All 9 pages pass the 7-point check above.
- **QC:** Opus loads 4+ pages at 1280px and confirms card heights match the D3 table.

### T5.3 — Mobile regression (375px)

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T5.1
- **Do:** Load every page at 375px. For each page verify:
  1. Page header card is at least 6.5rem (mobile half-row).
  2. Control strip is at least 3.25rem (mobile quarter-row).
  3. Data cards are at least 13rem (mobile card-row).
  4. No card content is clipped.
  5. Graphic containers (gauges, arcs) fit within `--card-content-max` (9rem).
  6. Gap between cards is 1rem (from card margins, not grid row-gap).
  7. Bottom nav is visible on every page.
- **Accept:** All 9 pages pass the 7-point check above.
- **QC:** Opus loads 4+ pages at 375px and confirms sizing.

### T5.4 — Code hygiene check

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T5.2, T5.3
- **Do:**
  1. Grep for `py-2` in Card usages across all route and layout files. Should be zero occurrences (all removed).
  2. Grep for `min-h-[var(--card-half-row)]` and `min-h-[var(--card-row)]` in route files. Should be zero (handled by Card component via rowSpan).
  3. Grep for `md:auto-rows-[auto]` in route files. Should be zero (removed by PageLayout adoption — the grid uses quarter-row tracks now).
  4. Grep for `<Grid` in route files. Should only appear in `now.tsx` (and PageLayout). All other pages use PageLayout.
  5. Grep for `info=` on PageHeaderCard. Should be zero.
- **Accept:** All 5 greps return zero matches (except `<Grid` in now.tsx and page-layout.tsx).
- **QC:** Opus runs each grep and confirms results.

---

## Dependency graph

```
Phase 0 (ADR amendment — T0.1)
    |
    v
Phase 1 (Grid + token foundation — T1.1 → T1.2 → T1.3 → T1.4, T1.5, T1.6 parallel → T1.7)
    |
    +---> Phase 2 (PageLayout — T2.1 → T2.2 → T2.3)
    |         |
    |         v
    |     Phase 3 (ControlsStrip — T3.1, T3.2, T3.3, T3.4 parallel)
    |
    +---> Phase 4 (Chart container — T4.1 → T4.2, T4.3 parallel)
              |
              v
         Phase 5 (Regression — T5.1 → T5.2, T5.3 parallel → T5.4)
```

---

## Verification bar — plan-level "done"

- [x] ADR-051 amended and Accepted with quarter-row track, mobile tokens, row-gap=0, `--card-content-max`. (commit 15a6b85 meta repo)
- [x] Grid base track is `--card-quarter-row` at md+ with `gap-y-0`. (commit d31663f)
- [x] Every page (except Now) uses PageLayout template — zero boilerplate duplication. (commit 6986e03)
- [x] No ad-hoc Card wrappers with `py-2` overrides anywhere. (grep verified: zero hits)
- [x] Control strips render at quarter-row height via ControlsStrip (Charts, Records, Reports, Seismic). (commit 0597436)
- [x] Page headers render at half-row height via PageHeaderCard (title + icon only, no `info` prop). (commit 6986e03)
- [x] PageHeaderCard does not accept an `info` prop. (commit 6986e03)
- [x] ConfigDriven charts and Almanac monthly chart use ChartContainer for consistent sizing. (commit d41e3a5)
- [x] Now-page tile-card charts self-constrain via `--card-content-max` (unchanged).
- [x] `npm run build` zero errors, `npx tsc --noEmit` zero errors. (verified 2026-06-13)
- [ ] Desktop (1280px) and mobile (375px) visual regression check passes on all 9 pages. (deploy pending — user to verify)
- [x] Zero grep hits for: `py-2` on Cards in routes, `md:auto-rows-[auto]` in routes, `info=` on PageHeaderCard. (verified 2026-06-13)
