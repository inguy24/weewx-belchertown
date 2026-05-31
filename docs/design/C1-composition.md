# C1 — Composition (step 2) + lead synthesis

**Track C, component C1.** Date 2026-05-31. Lead = Opus.
Inputs: [C1-prior-decisions.md](C1-prior-decisions.md) (step 0) · [C1-data-inventory.md](C1-data-inventory.md) (step 1 / B1).
**Status:** Proposed for user review at the composition STOP gate — NOT an ADR, NOT committed-as-decided.

---

## 1. Step-0 synthesis — re-affirm / depart

| ADR | What it locks for C1 | Call |
|---|---|---|
| ADR-009 | Three-tier hierarchy (temp/condition → feels-like → supporting); Recharts; hero imagery Now-only. Background role superseded by ADR-047. | **Affirm.** |
| ADR-022 | Hero logo + site title come from `useBranding()` at runtime; alt-text guaranteed non-empty. | **Affirm.** |
| ADR-024 | Now card set locked (layout is C1's job). Current-conditions hero = outTemp primary, condition + feels-like secondary. Hi/lo lives in Today's Highlights; the locked-8 obs live in the Station-observations tile. | **Affirm.** |
| ADR-047 | Global condition-keyed photo background behind every page; cards are translucent glass → legibility constraint (B3 floor). C1 does not build the background (already shipped, D2). | **Affirm.** |
| ADR-049 | Condition icon = Material Symbols + gradient fills (inline SVG). Depends on `weather-icon.tsx` rewrite (exec dependency, not yet done). | **Affirm.** |
| ADR-050 | Feels-like and dew-point render **text-only, no icon**. Wind iconography is C2, not C1. | **Affirm.** |
| ADR-051 | Now hero = `full`-width × half-row page-header card carrying station logo + name (this is the C1 deliverable). Current-conditions card min footprint 2×2. Glass opacity per B3 provisional defaults, not hard-coded. | **Affirm.** |

**Conscious departures / lead calls (resolving the step-0 open conflicts):**

- **Hero = logo + station name + location.** The page-header card carries **station logo + station name (`branding.siteTitle`) + the operator's configured location (`/station → data.name`)** — all three, confirmed sources (see Surface A). It does **not** carry temperature, the condition icon, or any freshness/online indicator. *(User-locked 2026-05-31.)*
- **No freshness / "last updated" / online state anywhere in C1** — dropped from the hero AND the conditions card. *(User-locked 2026-05-31.)*
- **Today's temp curve is integrated into the current-conditions card** (the img-23 model: big temp up top, day curve across the bottom of the *same* card) — **not** a separate card below. "Along the bottom" + img-23 both point at one card.
- **Event-trigger foreground hero (ADR-009) stays deferred.** It is separate future scope, not the ADR-051 page-header card. C1 does not build it. *(Resolves conflict 6.)*
- **Webcam/Radar "tabbed-tile vs separate-cards" (C0 flag) is out of C1 scope and resolves in favour of ADR-024 (separate cards, matching the build).** Not a C1 surface; no C0 edit made now. *(Resolves conflict 4.)*
- **Hero-drop history (conflict 3) is not investigated** — ADR-051 assigns the hero as a net-new C1 *design* regardless of how it was lost. We build fresh.

---

## 2. Composition — the three C1 surfaces

### Surface A — Now-page hero (page-header card)
- **Footprint:** `full` (4-col) × half-row (`--card-half-row` ≈ 5.5rem), per ADR-051. Sits at the top of the Now page, above the grid.
- **Content (LOCKED 2026-05-31):** station logo (`branding.logo.light` / `.dark`, CSS-invert fallback, alt from `branding.logo.alt`) + station name (`branding.siteTitle`) + a plain-text line showing **the operator's configured location** (dynamic, NOT hardcoded. Source: `GET /api/v1/station → data.name`. Configured by operator in `weewx.conf [Station] location`. Already consumed in `now.tsx` as `station?.name`.)
  - **Source mapping (confirmed):** logo = `useBranding()` logo; **station name** = `branding.siteTitle` (ADR-022, `/api/v1/branding`); **location line** = `GET /api/v1/station → data.name` (from `weewx.conf [Station] location`). NOTE: the as-built `current-conditions-card.tsx` renders only `/station data.name` (it labels it `stationName`, a misnomer — it is the location). The C1 hero must render BOTH the station name (`branding.siteTitle`) AND the location (`/station data.name`) as separate elements. **Caveat (verified in code):** `branding.siteTitle` is optional (`string | undefined`) and is currently NOT rendered as visible text anywhere (it only sets `document.title`) — the hero is its first on-screen use, so design a fallback for when it is unset (omit the name line, or fall back to `/station data.name`).
- **Treatment:** translucent glass; logo + text must clear B3 contrast in both themes. **No condition icon, no temp, no freshness/online state.**

### Surface B — Current-conditions card (with integrated temp curve)
- **Footprint:** 2-col `wide`, proposed **tall** (×4 half-rows ≈ 22rem) to hold temp block + integrated curve; **min 2×2 preserved** per ADR-051. Exact height finalised at mockup.
- **Grouping — what's ON the card:**
  - **Tier 1 (primary):** oversized **`outTemp`** + **condition icon** (ADR-049 Material gradient, from `weatherCode`) + condition **label**.
  - **Tier 2 (secondary):** **feels-like** — one of `windchill`/`heatindex`/`appTemp`/`humidex`, **text-only** (ADR-050); plus the **condition sentence** (`weatherText`) *when available* (null today → card designed for the blank state, sentence is later enhancement).
  - **No freshness/online/"last updated" indicator** (LOCKED 2026-05-31 — dropped everywhere in C1).
- **Today's hi/lo placement — UNDECIDED, mock BOTH ways (LOCKED 2026-05-31):** produce two variants — (i) hi/lo shown on the conditions card, (ii) hi/lo kept off the card (lives in Today's Highlights per ADR-024). User picks from the mockups.
- **Grouping — what's SPLIT OUT (not on this card):**
  - Peak gust, rain-so-far, peak AQI, records-today → **Today's Highlights** card (ADR-024).
  - The **locked-8 observations** grid (humidity, dewpoint, barometer, etc.) → **Station-observations tile** (ADR-024). The conditions card stays focused on temp + condition + feels-like.
  - **Wind** → C2 (may appear as data but its iconography is C2's).

### Surface C — Today's temperature curve (integrated into Surface B's lower region; img-23)
- **Plot:** `outTemp` over the current calendar day. **Past leg** (solid) = `GET /archive` `interval=raw` from today's local-midnight; **now-divider** anchored by `GET /current`'s latest `outTemp`/`timestamp`; **future leg** (dashed) = `GET /forecast` `hourly[].outTemp`.
- **H/L markers:** computed client-side (`Math.max`/`min`) over the archive series — no extra call.
- **Actual/Feels toggle:** `appTemp` is in the same `/archive` call (free). **Caveat:** the forecast `hourly[]` has **no** `appTemp`/`humidex`/`windchill`/`heatindex` → the Feels variant loses parity on the future dashed leg (degrade: actual-only past "now", or hide future leg in Feels mode).
- **No scene photo behind the curve (user-locked 2026-05-31 — "get it working first").** The curve renders plainly on the card's glass surface; nothing is drawn behind the plot area. The B2 `usePlotArea()` scene-image technique is NOT used for C1. *(The global ADR-047 page background behind all cards is untouched — separate matter.)*
- **Degrade — wunderground:** no hourly forecast → **no future dashed leg**; render past arc only.
- **Accessibility (carried into exec):** chart container `role="img"` + `aria-label` summary; `<table class="sr-only">` of hourly readings.

---

## 3. Data inventory — condensed (full detail in C1-data-inventory.md)

- **Source of every current-conditions field:** `GET /api/v1/current` → `Observation`. Providers do **not** feed `/current` directly; the weewx archive is the sole source, except `weatherText` (BFF blend).
- **Card-primary fields:** `outTemp` (primary), `weatherCode`→icon, `weatherText`→sentence, one feels-like (`windchill`/`heatindex`/`appTemp`/`humidex`).
- **`weatherText` update cadence:** `weatherText` updates at REST poll cadence only, not at SSE/loop-packet frequency. It is not in the `WEEWX_TO_OBSERVATION` field map and is not included in SSE loop packets. The conditions sentence may lag real-time sensor changes by up to the REST poll interval.
- **Always-present:** only `timestamp`, `source`, `extras`, and envelope (`units`/`generatedAt`). **Every numeric observation is nullable** → the card must handle nulls everywhere.
- **Temp series:** keyed on `timestamp` (X, UTC ISO-8601) + `outTemp` (Y, nullable); weewx `archive.outTemp` column; native interval typically 5 min (288 pts/day, one page). Future leg `forecast.hourly[].outTemp` (all providers except wunderground).

---

## 4. Mismatches & data-reality flags (need your awareness/decision)

1. **`weatherText` (the condition *sentence*) IS produced by the BFF conditions engine** and injected into every `/current` response. It may be null only during the ~3 minute startup window (insufficient solar kc data) or when the BFF is not running. Design for the null state as a brief/edge case. The icon (`weatherCode`) comes from the daily forecast provider's `DailyForecastPoint.weatherCode` — it is absent if no forecast provider is configured.
2. **`weatherText` is in the API's Pydantic model but absent from the published OpenAPI schema** — contract-hygiene gap in the API repo. **Not C1-blocking;** recommend tracking as a separate api-repo item, not fixing inside C1.
3. **`STOCK_COLUMN_MAP` lists extended-sensor columns (`dewpoint1`, `extraTemp4–8`, `extraHumid3–8`) the `Observation` model has no slots for → silently dropped at runtime** for stations that have them. **Out of C1 scope** (none are current-conditions fields); recommend tracking as a separate api-repo item.

---

## 5. Decisions I need at this gate (before mockup)

1. **Hero scope:** branding only (logo + station name [+ optional location line]) — agree? Or do you want freshness/SSE state *in the hero* after all?
2. **Temp curve placement:** integrated into the current-conditions card bottom (img-23), as proposed — agree? Or a separate card below?
3. **`weatherText` null-today reality:** OK to design the card to degrade gracefully (icon + label now; full sentence when the blending engine lands)? **And** — do you approve a **single live `/current` spot-check** on weather-dev to confirm what's actually populated on the station right now (`weatherText`, `weatherCode`, `appTemp`)? This is the demoted conditional-field confirmation, not rediscovery; your call per the corrected B1 rule.
4. **API-hygiene mismatches (#2, #3):** agree to track separately as api-repo items, out of C1?

## 6. Exec dependencies (for later, not this gate)
- `weather-icon.tsx` rewrite to ADR-049 Material-gradient icons (condition icon depends on it).
- Read `src/components/current-conditions-card.tsx` (as-built baseline) before mockup — will delegate to Sonnet.
