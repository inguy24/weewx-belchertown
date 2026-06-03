# Brief: Semi-Circular Gauge Geometry Fix (Barometer + AQI)

**Date:** 2026-06-02
**Lead:** Opus (coordinator)
**Teammate:** Sonnet (clearskies-dashboard-dev)
**Source of truth:** `docs/design/mockups/C4-stat-tiles.html` — the `semiGauge()` function (search for "function semiGauge")

---

## Problem

The barometer gauge is clipped at the bottom of the card and the "Low"/"High" endpoint labels are invisible. Root cause: the React SemiCircularGauge component uses different arc geometry than the mockup.

## Scope (in)

Fix gauge geometry in 2 files:

1. `src/components/ui/semi-circular-gauge.tsx` — arc center, radius, endpoint label positioning
2. `src/components/barometer-card.tsx` — wrapper alignItems

### Files NOT to touch

- `src/components/aqi-card.tsx` — uses the same gauge; the geometry fix propagates automatically
- Any test files
- Any other components

## Reading list

1. Open `docs/design/mockups/C4-stat-tiles.html` — search for `function semiGauge`. Extract: cx, cy, r, endpoint label x/y formulas, value/unit/trend text y positions.
2. Open `src/components/ui/semi-circular-gauge.tsx` — locate CX, CY, R, LABEL_R constants and the endpoint label positioning code.
3. Open `src/components/barometer-card.tsx` — locate the wrapper div around SemiCircularGauge.

## Pre-round verification

- Dashboard repo at `15c22bf` on main, clean working tree (verified by lead QC).

---

## Per-file spec

### 1. semi-circular-gauge.tsx

**Constants to change (near top of file, lines ~84-88):**

| Constant | Current | Mockup | Change to |
|----------|---------|--------|-----------|
| CY | 100 | 92 | **92** |
| R | 88 | 85 | **85** |
| LABEL_R | 98 | n/a (different approach) | Leave as-is or remove if unused after label fix |

**Endpoint label positioning (lines ~253-254):**

Current code uses `polarToXY(fractionToAngleDeg(0/1), LABEL_R + 8)` which produces coordinates outside the viewBox.

The mockup uses a direct geometric offset:
```
left label:  x = cx - r + 8,  y = cy + 14
right label: x = cx + r - 8,  y = cy + 14
```

With the new CY=92, R=85:
- Left "Low":  x = 100 - 85 + 8 = 23,  y = 92 + 14 = 106
- Right "High": x = 100 + 85 - 8 = 177, y = 92 + 14 = 106

Replace the `polarToXY` calls for endpoint labels with this simpler formula. The labels at y=106 fit within the 112px viewBox (6px from bottom).

**Also check:** The inner tick radius, outer tick radius, and any other derived values that use CY or R. They should use the updated constants. The ticks will naturally shift up 8px and inward 3px, which is correct.

**Children overlay div (lines ~331-351):**

Currently `position: 'absolute', top: '20%', left: '10%', right: '10%', bottom: '5%'`. With CY moving from 100 to 92 (shifting the arc center up from 89% to 82% of the viewBox), the children overlay may need adjustment. Check that the barometer's value/unit/trend text still centers correctly within the arc after the geometry change. If it looks off, adjust `top` percentage.

### 2. barometer-card.tsx

**Wrapper div (line ~231):**

Current: `alignItems: 'flex-start'`
Mockup uses: `align-items: center`

Change to: `alignItems: 'center'`

This centers the gauge vertically in the available space instead of pinning it to the top.

---

## FAIL conditions

After changes:
- `CY = 100` in semi-circular-gauge.tsx → WRONG (should be 92)
- `R = 88` in semi-circular-gauge.tsx → WRONG (should be 85)
- `alignItems: 'flex-start'` in barometer-card.tsx gauge wrapper → WRONG (should be center)
- Endpoint labels should render at approximately x=23 and x=177, y=106 — NOT at x<0 or x>200

---

## Verification command

```
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard && npx tsc --noEmit
```

Expected: 0 errors.

---

## Deliverable

- 2 files modified per spec
- `tsc --noEmit` passes with 0 errors  
- Single commit: `fix: correct gauge arc geometry and endpoint labels to match C4 mockup`

---

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report. Do not resolve it yourself.
