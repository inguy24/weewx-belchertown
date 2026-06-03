# Brief: C4 Stat Tile Mockup Compliance Fixes

**Date:** 2026-06-02
**Lead:** Opus (coordinator)
**Teammate:** Sonnet (clearskies-dashboard-dev)
**Source of truth:** `docs/design/mockups/C4-stat-tiles.html`

---

## Scope (in)

Fix CSS values in 5 dashboard component files to match the C4 stat tiles mockup exactly. All changes are mechanical number replacements — no layout restructuring, no new features.

### Files to modify

1. `src/components/barometer-card.tsx` — **3 changes (already applied by lead, verify correctness)**
2. `src/components/aqi-card.tsx` — **2 changes (already applied by lead, verify correctness)**
3. `src/components/uv-index-card.tsx` — 1 change
4. `src/components/sun-moon-card.tsx` — 7 changes
5. `src/components/earthquake-card.tsx` — 3 changes

### Files NOT to touch

- `src/components/solar-radiation-card.tsx` — already matches mockup
- `src/components/lightning-card.tsx` — already matches mockup
- `src/components/precipitation-card.tsx` — already confirmed by user
- `src/components/ui/semi-circular-gauge.tsx` — no changes needed (viewBox 200×112 matches)
- Any test files — test-author owns those
- Any files outside `src/components/`

## Scope (out)

- Radar, webcam, alert banner, forecast cards — not in this round
- Layout/grid changes — not in this round
- New features or refactoring — not in this round

---

## Reading list

1. Open `docs/design/mockups/C4-stat-tiles.html` — this is the source of truth. Extract every CSS value before touching code.
2. Open each of the 5 component files listed above.
3. Compare mockup values against code values for each property listed below.

---

## Pre-round verification

- Dashboard repo at `cdd32fd` on main, clean working tree (verified by lead).
- **Exception:** Lead applied 5 edits directly to barometer-card.tsx and aqi-card.tsx before being stopped. The working tree now has uncommitted changes in those 2 files. The values are believed correct per mockup but MUST be independently verified by the agent against the mockup file.

---

## Per-file spec

### 1. barometer-card.tsx (VERIFY lead's existing edits)

Lead already changed these 3 values. Open the mockup, verify these are correct:

| Property | Mockup value | Should be in code |
|----------|-------------|-------------------|
| Gauge value font-size (line ~266) | 20px | `fontSize: '1.25rem'` |
| Unit text font-size (line ~280) | 10px | `fontSize: '0.625rem'` |
| Trend text font-size (line ~305) | 10px | `fontSize: '0.625rem'` |

If any of these are wrong, fix them. If they're correct, move on.

### 2. aqi-card.tsx (VERIFY lead's existing edits)

Lead already changed these 2 values. Open the mockup, verify:

| Property | Mockup value | Should be in code |
|----------|-------------|-------------------|
| AQI value font-size (line ~187) | 20px | `fontSize: '1.25rem'` |
| Main pollutant font-size (line ~218) | 10px | `fontSize: '0.625rem'` |

### 3. uv-index-card.tsx (1 change)

| Property | Mockup value | Current code | Fix |
|----------|-------------|-------------|-----|
| ReferenceDot radius (line ~438) | r=5 | `r={4}` | Change to `r={5}` |

### 4. sun-moon-card.tsx (7 changes)

| Property | Mockup value | Current code | Line | Fix |
|----------|-------------|-------------|------|-----|
| Moon arc strokeWidth | 3 | `strokeWidth={2.5}` | ~258 | → `strokeWidth={3}` |
| Phase name fontSize | 7.5px | `fontSize={8}` | ~326 | → `fontSize={7.5}` |
| Illumination fontSize | 7px | `fontSize={7.5}` | ~339 | → `fontSize={7}` |
| Sun rise label fontSize | 8px | `fontSize={9}` | ~352 | → `fontSize={8}` |
| Moon rise label fontSize | 8px | `fontSize={9}` | ~363 | → `fontSize={8}` |
| Sun set label fontSize | 8px | `fontSize={9}` | ~376 | → `fontSize={8}` |
| Moon set label fontSize | 8px | `fontSize={9}` | ~388 | → `fontSize={8}` |

### 5. earthquake-card.tsx (3 changes)

| Property | Mockup value | Current code | Line | Fix |
|----------|-------------|-------------|------|-----|
| Badge borderRadius | 5px | `borderRadius: 6` | ~135 | → `borderRadius: 5` |
| Row internal gap | 8px | `gap: '0.625rem'` | ~124 | → `gap: '0.5rem'` |
| Divider margin | ~2px each side | `margin: '0.5rem 0'` | ~300 | → `margin: '0.125rem 0'` |

---

## FAIL conditions (grep-checkable)

After all changes, these should NOT appear in the modified files:

- `fontSize: '1.125rem'` in barometer-card.tsx or aqi-card.tsx → WRONG (should be 1.25rem)
- `fontSize: '0.75rem'` in barometer-card.tsx unit text → WRONG (should be 0.625rem)
- `fontSize: '0.72rem'` in barometer-card.tsx trend → WRONG (should be 0.625rem)
- `fontSize: '0.5625rem'` in aqi-card.tsx pollutant → WRONG (should be 0.625rem)
- `r={4}` in uv-index-card.tsx ReferenceDot → WRONG (should be r={5})
- `strokeWidth={2.5}` in sun-moon-card.tsx moon arc → WRONG (should be 3)
- `fontSize={9}` in sun-moon-card.tsx rise/set labels → WRONG (should be 8)
- `borderRadius: 6` in earthquake-card.tsx badge → WRONG (should be 5)
- `gap: '0.625rem'` in earthquake-card.tsx row → WRONG (should be 0.5rem)
- `margin: '0.5rem 0'` in earthquake-card.tsx divider → WRONG (should be 0.125rem 0)

---

## Verification command

```
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard && npx tsc --noEmit
```

Expected: 0 errors.

---

## Deliverable

- All 5 files modified per spec above
- `tsc --noEmit` passes with 0 errors
- Single commit with message: `fix: align stat tile CSS values to C4 mockup spec`

---

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report via SendMessage. Do not resolve it yourself.
