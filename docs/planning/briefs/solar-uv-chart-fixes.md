# Brief: Solar Radiation + UV Index Chart Fixes

**Date:** 2026-06-02
**Lead:** Opus (coordinator)
**Teammate:** Sonnet (clearskies-dashboard-dev)

---

## Scope (in)

### Files to modify

1. `src/routes/now.tsx` — change archive fetch `from` to 24h ago
2. `src/components/uv-index-card.tsx` — UV prediction curve, Y-axis ticks, chart spacing

### Files NOT to touch

- `src/components/solar-radiation-card.tsx` — no changes needed (rolling window logic is correct)
- Any test files
- Any API files

---

## Reading list

1. `src/routes/now.tsx` — lines 66-68 (archive fetch), line 99 (todayForecast), and wherever almanac data is fetched
2. `src/components/uv-index-card.tsx` — the full file
3. `docs/design/mockups/C4-stat-tiles.html` — UV Index section for Y-axis ticks and spacing

---

## Fix 1: Solar Radiation — 24h archive window

**File:** `src/routes/now.tsx`, lines 66-68

Current code:
```ts
const todayStart = new Date();
todayStart.setHours(0, 0, 0, 0);
const { data: todayArchive } = useArchive({ from: todayStart.toISOString() });
```

This fetches archive from midnight. The Solar Radiation chart uses a 24h rolling window, so it needs data going back 24h, not just since midnight.

**Change to:**
```ts
const archiveStart = new Date(Date.now() - 24 * 60 * 60 * 1000);
const { data: todayArchive } = useArchive({ from: archiveStart.toISOString() });
```

This fetches 24h of archive data. The UV chart's midnight-to-midnight filter still works correctly because it filters within the component.

**IMPORTANT:** Check if `todayStart` is used anywhere else in the file (e.g., for midnight reference). If so, keep it and create a SEPARATE variable for the archive fetch. Only change the `from` parameter for the archive query.

---

## Fix 2: UV Index — predicted UV bell curve

**File:** `src/components/uv-index-card.tsx`

Currently the chart plots archive UV data (`rec.UV` from `todayArchive`). The user wants predicted/forecast UV — a smooth bell curve showing expected UV for the day.

**Approach:** Synthesize the UV curve from available data:
- `todayForecast.uvIndexMax` — the forecast peak UV value
- Sunrise and sunset times — needed to shape the curve

**Data needed:** The component currently receives `observation`, `todayArchive`, and `todayForecast`. It also needs sunrise/sunset times. Check if the Now page already has almanac data available. If so, pass `sunrise` and `sunset` as additional props. If not, the component may need to derive approximate sunrise/sunset from the archive data (first/last nonzero UV readings).

**Bell curve formula:**
For each hour between sunrise and sunset, compute:
```
UV(t) = uvIndexMax * sin²(π * (t - sunrise) / (sunset - sunrise))
```
This produces a smooth parabolic curve that:
- Is 0 at sunrise
- Peaks at solar noon (midpoint of sunrise and sunset) with value = uvIndexMax
- Returns to 0 at sunset

Generate points every 15-30 minutes from midnight to midnight. Points outside sunrise-sunset are 0.

**Chart data source change:**
Replace the archive-based chart data with the synthesized prediction curve. The chart should show:
- Area fill: the predicted UV bell curve (same EPA gradient fill)
- ReferenceDot: current observed UV from the SSE observation (unchanged)

**Keep the archive data for the "Now" value.** The "Now" display below the chart still uses the current SSE observation (`observation?.UV`). The "Peak" value still uses `todayForecast.uvIndexMax`.

**If sunrise/sunset isn't available:** Fall back to a reasonable default (6am-8pm) or derive from archive data.

---

## Fix 3: UV Index — Y-axis ticks

**File:** `src/components/uv-index-card.tsx`

Current (line ~56-59):
```ts
const UV_Y_MAX = 12;
const UV_Y_TICKS = [0, 3, 6, 9, 12];
```

Mockup shows ticks at 0, 4, 8, 12.

**Change to:**
```ts
const UV_Y_MAX = 12;
const UV_Y_TICKS = [0, 4, 8, 12];
```

---

## Fix 4: UV Index — chart spacing

The chart is too squished against the title. Add ~10-15px of top margin/padding to the chart area.

Look at the CardContent or the chart container div. Add `marginTop: '0.625rem'` (10px) or `paddingTop: '0.75rem'` (12px) to push the chart down from the title.

Check the mockup for the exact spacing spec. The tile-p7 or equivalent class may specify gap or padding.

---

## FAIL conditions

- `todayStart.setHours(0, 0, 0, 0)` used as `from` for archive in now.tsx → WRONG (should be 24h ago)
- `UV_Y_TICKS = [0, 3, 6, 9, 12]` → WRONG (should be [0, 4, 8, 12])
- Chart still plotting archive UV data instead of prediction curve → WRONG

---

## Verification command

```
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard && npx tsc --noEmit
```

---

## Deliverable

All fixes in one commit: `fix: solar 24h archive window, UV predicted curve + Y-axis ticks + chart spacing`

---

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`.
