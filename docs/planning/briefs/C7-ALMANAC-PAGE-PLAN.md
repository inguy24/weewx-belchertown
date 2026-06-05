# C7 — Almanac Page Redesign — Execution Plan

**Status:** IN PROGRESS — Planet viewing quality sub-plan complete (2026-06-04). Remaining: Phase 0–3.
**Component:** C7 of the UI redesign. Parent roadmap: [UI-REDESIGN-PLAN.md](../../docs/planning/UI-REDESIGN-PLAN.md) Track C.
**Per-component workflow:** [UI-REDESIGN-PLAN.md](../../docs/planning/UI-REDESIGN-PLAN.md) "Per-component workflow."

**Completed sub-plans:**
- [PLANET-VIEWING-QUALITY-PLAN.md](../../archive/PLANET-VIEWING-QUALITY-PLAN.md) — IMPLEMENTED 2026-06-04. 7Timer seeing forecast integration, BFF planet viewing quality enrichment, expanded planet data (magnitude, RA/Dec, elongation, transit time, Uranus/Neptune). Supersedes T1.8 below.

---

## 0. Orientation for a fresh session (read first)

- Project rules routing: [CLAUDE.md](../../CLAUDE.md). **Load before acting:**
  [rules/coding.md](../../rules/coding.md),
  [rules/clearskies-process.md](../../rules/clearskies-process.md),
  [rules/github.md](../../rules/github.md).
- **Memory system is OFF** ([CLAUDE.md](../../CLAUDE.md)); plans live in `docs/planning/`.
- **Three sub-repos** under `repos/`:
  - `weewx-clearskies-realtime` — BFF (Python). Agent: `clearskies-realtime-dev`.
  - `weewx-clearskies-api` — FastAPI + SQLAlchemy backend. Agent: `clearskies-api-dev`.
  - `weewx-clearskies-dashboard` — React 19 + Vite + Tailwind v4 + shadcn/ui + Recharts SPA. Agent: `clearskies-dashboard-dev`.
- **Data flow:** dashboard → BFF `/api/v1/*` (REST + SSE) → API backend. Most almanac endpoints pass through the BFF proxy. As of 2026-06-04, the BFF enriches `/almanac/planets` responses with per-planet viewing quality from 7Timer seeing forecast data (see archived PLANET-VIEWING-QUALITY-PLAN.md).
- **Deploy targets:**
  - **API** runs on the **weewx** LXD container (192.168.7.20), NOT weather-dev. Deploy and test API changes there.
  - **Dashboard** dev server runs on **weather-dev** LXD container (192.168.2.113), accessible at `http://192.168.2.113:5173/`.
  - **Production Belchertown skin** untouched until Phase 5 cutover.
- **Architecture source of truth:** [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md). Contract: [docs/contracts/openapi-v1.yaml](../../docs/contracts/openapi-v1.yaml).

### Git safety (ALL agents, ALL repos — non-negotiable)
Implementation agents may ONLY `git add`, `git commit` (local), `git status`, `git log`,
`git diff`. **NO `git pull/push/fetch/rebase/merge/remote`, NO checkout of remote branches,
NO worktree isolation.** If unexpected repo state → STOP and report. Coordinator pushes only
when operator types "push."

---

## 1. Context — what exists and what is changing

The almanac page (`/almanac`, `repos/weewx-clearskies-dashboard/src/routes/almanac.tsx`, 795 lines) is a **vertical stack of 7 unstyled Phase-2 cards** outside the Grid system. This redesign:

1. **Migrates to the A4 Grid** (same pattern as C3 forecast page)
2. **Merges Sun + Moon + Positional into one rich 4×2 card** with arc visualization
3. **Adds 2 net-new surfaces** (Solar Eclipses, Planets Timeline)
4. **Transforms 3 existing surfaces** (Lunar Eclipses, Meteor Showers, Planets) from text lists to rich visual cards
5. **Re-skins Monthly Averages** with design tokens
6. **Integrates AstronomyAPI.com** for eclipse contact times + local visibility
7. **Converts meteor shower catalog to operator-editable JSON** config

### Current card structure in almanac.tsx

| Surface | Lines | Current state | C7 change |
|---|---|---|---|
| Sun card | 320–385 | `<Card>` with `<dl>` grid, no footprint | Merge into SunMoonDetailCard |
| Moon card | 387–448 | `<Card>` with moon name badges + `<dl>` | Merge into SunMoonDetailCard |
| Positional data | 450–486 | `<Card>` with azimuth/altitude | Fold into SunMoonDetailCard |
| Monthly Averages | 504–624 | `<Card>` with Recharts ComposedChart | Re-skin with design tokens |
| Planets Visible | 632–691 | `<Card>` with text list (Evening/Morning/AllNight) | Replace with visual timeline |
| Lunar Eclipses | 699–735 | `<Card>` with type badges + date list | Replace with hero photo columns |
| Meteor Showers | 743–789 | `<Card>` with responsive table | Replace with hero photo columns |

### Page wrapper (current)
```tsx
<div className="flex flex-col gap-6 max-w-2xl mx-auto">
```
This becomes the Grid pattern (see forecast.tsx line 61 for template):
```tsx
<div className="flex flex-col gap-4">
  <h1 className="sr-only">{t('pageTitle')}</h1>
  <Grid className="md:auto-rows-[auto]">
    <PageHeaderCard ... />
    {/* cards */}
  </Grid>
</div>
```

---

## 2. Locked operator directives (2026-06-03)

1. **Sun + Moon merged into one `full` 4×2 card.** Internal 1/2/1 CSS grid: sun stats (left) | arc graphic (center 2fr) | moon stats (right). Positional data folded in.
2. **Planets card = visual night timeline** (`full` 4×2). Modeled on `docs/design/inspiration/planet_viewing_window.png`. Planet thumbnails (NASA/JPL), Gantt-chart sunset→sunrise timeline, viewing quality badges.
3. **Solar Eclipses = net-new `full` 4×2 card.** Modeled on `docs/design/inspiration/solar_eclipse_schedule.png`. Hero photos, contact times from AstronomyAPI.com. Stackable + expandable on mobile.
4. **Lunar Eclipses = redesigned `full` 4×2 card.** Modeled on `docs/design/inspiration/lunar_eclipse_schedule.png`. Hero photos, contact times from AstronomyAPI.com. Stackable + expandable on mobile.
5. **Meteor Showers = redesigned `full` 4×2 card.** Modeled on `docs/design/inspiration/meteor_shower_schedule.png`. AI-generated streak images, viewing quality from Skyfield. Stackable + expandable on mobile.
6. **Meteor shower catalog must be operator-editable JSON**, not hardcoded in Python code.
7. **AstronomyAPI.com credentials** collected by the setup wizard (optional — almanac works without them, just without eclipse timing detail). Env vars per ADR-027.
8. **No per-card ADRs.** Governing docs (typography tokens, ADR-048/051, approved mockups) are source of truth.

---

## 3. Locked constraints (already decided — do NOT re-theorize)

### Universal document reading list (MUST read before any code/mockup)

**TIER 1 — Locking ADRs / token specs:**
- `docs/design/design-tokens-typography.md` — LOCKED font families, sizes, weights
- `docs/decisions/ADR-048-theme-color-tokens.md` — theme colors, accent palette
- `docs/decisions/ADR-049-hero-weather-icons.md` — hero weather icon system
- `docs/decisions/ADR-050-utility-stat-nav-icons.md` — Phosphor base + cross-pack
- `docs/decisions/ADR-051-card-footprint-model.md` — footprints, glass surface, universal card discipline
- `docs/decisions/ADR-047-background-system.md` — background system (cards sit over it)

**TIER 2 — Process & coding rules:**
- `rules/clearskies-process.md`
- `rules/coding.md` — §5 WCAG 2.1 AA, §6 Recharts discipline, §7 build verification, "Render and LOOK"

**TIER 3 — Design references:**
- `docs/design/mockups/A4-card-grid.html` — locked footprints
- `docs/design/mockups/A4-page-anatomy.html` — page structure, half-row track, grid CSS
- `docs/design/inspiration/NOTES.md` + specific images (see §3.6 below)

**TIER 4 — Data contracts:**
- `docs/contracts/openapi-v1.yaml` — wire format authority
- `repos/weewx-clearskies-dashboard/src/api/types.ts` — TS type definitions
- `repos/weewx-clearskies-dashboard/src/hooks/useWeatherData.ts` — data hooks

**TIER 5 — Reference implementations:**
- `repos/weewx-clearskies-dashboard/src/components/WindCompassCard.tsx` — C2 card pattern
- `repos/weewx-clearskies-dashboard/src/components/forecast/NowForecastCard.tsx` — C3 tabbed card
- `repos/weewx-clearskies-dashboard/src/routes/forecast.tsx` — page layout template

### Typography tokens (LOCKED — design-tokens-typography.md)
- Card title: `--text-card-title` (0.82rem), `--font-sans` (Manrope), weight 600
- Section headings: `--text-section` (0.95rem), Manrope 600
- Body/labels: `--text-body` (0.9rem) / `--text-label` (0.75rem) / `--text-micro` (0.7rem), Manrope 400
- Chart SVG text: `--text-chart-label` (0.875rem), `--font-chart` (Lexend), weight 400
- Stat numerals (sun/moon card): Outfit 600, size contextual (NOT `--text-stat-hero` which is C1 temp only)

### Footprints (all cards)
All almanac cards use `full` (4 cols at lg, 2 at md, 1 at mobile). Grid uses `md:auto-rows-[auto]` override (same as forecast.tsx) because card content heights vary.

### Page layout (desktop, 4-col grid)
```
[  PageHeaderCard                    — full, strip height   ]
[  Sun & Moon combined (1/2/1)       — full, ~22rem         ]
[  Planets Timeline                  — full, ~22rem         ]
[  Monthly Averages Chart            — full, ~22rem         ]
[  Solar Eclipses                    — full, ~22rem         ]
[  Lunar Eclipses                    — full, ~22rem         ]
[  Meteor Showers                    — full, ~22rem         ]
```

### Inspiration images (MUST open AS IMAGES before designing)
- `docs/design/inspiration/raw/img-11.jpg` — Sun & Moon arcs (Huawei): nested dashed arcs, position markers, phase label
- `docs/design/inspiration/raw/img-14.jpg` — Sunrise/sunset arc + moon phase (Huawei)
- `docs/design/inspiration/planet_viewing_window.png` — Planet timeline card: planet photos, Gantt bars, sunset→sunrise axis, viewing quality badges
- `docs/design/inspiration/lunar_eclipse_schedule.png` — Lunar eclipse card: hero moon photos, contact times, visibility badges, type legend
- `docs/design/inspiration/solar_eclipse_schedule.png` — Solar eclipse card: hero eclipse photos, contact times, totality indicators, type legend
- `docs/design/inspiration/meteor_shower_schedule.png` — Meteor shower card: streak images, peak night, ZHR, viewing quality badges
- `docs/design/inspiration/meteor_streaks_imagery_Generated.png` — 6 AI-generated meteor streak night-sky images (source for per-shower hero images)

### Headless render command (Windows — mockup phase)
```
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu `
  --screenshot="C:\tmp\render.png" --window-size=1400,900 "file:///<absolute-path-to.html>"
```
Then Read the PNG and LOOK. Markup / axe pass ≠ visual verification.

---

## 4. Data sources & API integration

### 4.1 AstronomyAPI.com — eclipse contact times (NEW integration)

**Purpose:** The one gap Skyfield can't fill — eclipse contact times and local visibility.

**Authentication:** HTTP Basic Auth. Credentials from env vars per ADR-027:
- `WEEWX_CLEARSKIES_ASTRONOMYAPI_APP_ID` → app_id
- `WEEWX_CLEARSKIES_ASTRONOMYAPI_APP_SECRET` → app_secret
- Credentials already obtained (stored in `reference/CREDENTIALS.md` — Task T0.1)
- Origin: `https://weather.shaneburkhardt.com`

**Endpoints used:**

**1. Lunar Eclipse Events:** `GET https://api.astronomyapi.com/api/v2/bodies/events/moon`
- Query params (ALL required): `latitude`, `longitude`, `elevation`, `from_date` (YYYY-MM-DD), `to_date` (YYYY-MM-DD), `time` (HH:MM:SS)
- Max range: 366 days per request
- Returns ALL global eclipses (not location-filtered). Filter by altitude > 0 at peak.
- Response schema:
```json
{
  "data": {
    "rows": [{
      "body": { "id": "moon", "name": "Moon" },
      "events": [{
        "type": "total_lunar_eclipse",  // or partial_lunar_eclipse, penumbral_lunar_eclipse
        "eventHighlights": {
          "penumbralStart": { "date": "ISO8601", "altitude": -13.56 },
          "partialStart":   { "date": "ISO8601", "altitude": 5.2 },
          "fullStart":      { "date": "ISO8601", "altitude": 12.3 },  // null if not total
          "peak":           { "date": "ISO8601", "altitude": 25.8 },
          "fullEnd":        { "date": "ISO8601", "altitude": 30.1 },  // null if not total
          "partialEnd":     { "date": "ISO8601", "altitude": 18.7 },
          "penumbralEnd":   { "date": "ISO8601", "altitude": 8.2 }
        },
        "extraInfo": { "obscuration": 0.76 }
      }]
    }]
  }
}
```

**2. Solar Eclipse Events:** `GET https://api.astronomyapi.com/api/v2/bodies/events/sun`
- Same query params as lunar. Same response structure.
- Event types: `total_solar_eclipse`, `annular_solar_eclipse`, `partial_solar_eclipse`
- eventHighlights: `partialStart`, `totalStart` (null if not total/annular), `peak`, `totalEnd`, `partialEnd`
- `totalStart` non-null → observer IS in the totality/annularity path

**3. Moon Phase Image (optional):** `POST https://api.astronomyapi.com/api/v2/studio/moon-phase`
- Returns image URL (not raw data). We keep our own SVG — more controllable for theming.

**Caching:** Server-side, cache for 7+ days (eclipse schedules don't change). Two calls total per cache refresh (lunar + solar).

**Free tier:** 3 req/sec, no documented daily limit, covers through 2050.

**Graceful degradation:** If credentials missing or API unreachable, eclipse endpoints return dates + types from Skyfield only (current behavior) without contact times. Dashboard renders cards without time details — still useful.

### 4.2 Skyfield enhancements (existing dependency)

All computed in `repos/weewx-clearskies-api/weewx_clearskies_api/services/almanac.py`.

**Existing (no changes needed):**
- Eclipse dates + types: `compute_lunar_eclipses()` (line 1142)
- Planet visibility: `compute_planets()` (line 872)
- Sun/moon snapshot: `compute_almanac()` (line 650)
- Moon illumination for meteor interference: inside `compute_meteor_showers()` (line 1270–1282)
- Radiant altitude: inside `compute_meteor_showers()` (line 1256–1268)

**Already completed (PLANET-VIEWING-QUALITY-PLAN, 2026-06-04):**
- **Planet apparent magnitude:** computed via `skyfield.magnitudelib.planetary_magnitude()` at local noon. Added to `compute_planets()` return dict.
- **Planet transit time, RA/Dec, elongation:** computed via Skyfield. Added to `compute_planets()` and `PlanetEntry` response model.
- **All 7 planets (Mercury–Neptune):** Uranus and Neptune added (previously capped at Saturn).
- **Per-planet viewing quality:** computed in the BFF (`weewx_clearskies_realtime/enrichment/planet_viewing.py`) using 7Timer seeing forecast (80% weight), planet altitude (15%), transparency (5%), with cloud gate, Mercury elongation gate + score cap, and Uranus/Neptune moon penalty.
- **7Timer seeing forecast endpoint:** `GET /almanac/seeing-forecast` with 3-hour cache warming.

**Still needed for C7:**
- **Meteor viewing quality rating:** Derive from existing moon illumination + radiant altitude. Formula: if `radiant_alt < 10°` → "Poor"; if `moon_illum > 75%` → degrade one level; if `radiant_alt > 40° AND moon_illum < 25%` → "Excellent"; else "Good". Add as `viewingQuality` field.
- **Meteor active date range:** Compute from `peak_month/peak_day ± duration_days/2`. Add `activeStart` and `activeEnd` fields.
- **Solar eclipses via Skyfield:** `skyfield.eclipselib` does NOT compute solar eclipses. Solar eclipse data comes entirely from AstronomyAPI.com. No Skyfield fallback for solar.

### 4.3 Meteor shower catalog (operator-editable)

**Current:** Hardcoded in `repos/weewx-clearskies-api/weewx_clearskies_api/data/meteor_showers.py` (42 lines). 12 showers as frozen dataclass instances in a Python list. Operators cannot edit without modifying source code.

**New:** Externalize to `meteor_showers.json` config file.
- **Default location:** `/etc/weewx-clearskies/meteor_showers.json` (alongside other config files)
- **Shipped with:** ~25 major showers seeded from IMO data
- **Fields per shower (fixed, operator-editable):**
  - `id` (string, kebab-case), `name`, `parent_body`, `description` (1-2 sentence characteristics)
  - `peak_month`, `peak_day`, `duration_days` (approximate active window around peak)
  - `solar_longitude_max` (for future precision computation)
  - `radiant_ra_deg`, `radiant_dec_deg` (J2000.0)
  - `velocity_kms`, `typical_zhr`
  - `image` (filename, references WebP in dashboard assets)
- **Computed per request (NOT in catalog):** exact peak date, active date range, moon illumination%, radiant altitude, viewing quality

**Migration path:** Keep `data/meteor_showers.py` as the seed source. On first run (or when config file missing), generate JSON from the Python catalog. After that, JSON is the source of truth.

### 4.4 Existing endpoints (no changes needed)
- `GET /almanac` — AlmanacSnapshot (sun + moon data for combined card)
- `GET /climatology/monthly` — ClimatologyMonthly (monthly averages chart)
- `GET /almanac/moon-names` — MoonNamesCalendar (moon name badges)

### 4.5 Endpoint changes

| Endpoint | Change | Details |
|---|---|---|
| `GET /almanac/eclipses` | Split into `/almanac/eclipses/lunar` and `/almanac/eclipses/solar` | Enriched with contact times + visibility from AstronomyAPI.com |
| `GET /almanac/meteor-showers` | Enriched response | Add `activeStart`, `activeEnd`, `description`, `viewingQuality`, `image` fields. Read from JSON catalog. |
| `GET /almanac/planets` | ✅ DONE (2026-06-04) | Magnitude, transitTime, RA/Dec, elongation added to API. BFF enriches with viewingQuality, viewingScore, bestViewingTime, clearWindow, conjunction, viewingNote. See archived PLANET-VIEWING-QUALITY-PLAN. |
| `GET /almanac/seeing-forecast` | ✅ DONE (2026-06-04) | New endpoint. 7Timer ASTRO product, 3-hour intervals, cached by warmer. |

### 4.6 Static assets

| Asset | Count | Source | Dashboard path |
|---|---|---|---|
| Planet thumbnails (Mercury–Neptune) | 7 | NASA/JPL public domain | `public/images/planets/` |
| Solar eclipse photos (total corona, annular ring, partial) | 3 | NASA public domain | `public/images/eclipses/` |
| Lunar eclipse moon photos (total blood moon, partial, penumbral) | 3 | NASA public domain | `public/images/eclipses/` |
| Meteor streak hero images | 6 | AI-generated (provided at `docs/design/inspiration/meteor_streaks_imagery_Generated.png`) | `public/images/meteors/` |
| **Total** | **19** | | ~100-120 KB compressed WebP |

---

## 5. Per-surface spec

### Surface A — PageHeaderCard (`full`, strip height)
Standard page header per `PageHeaderCard` (line 67 of `page-header-card.tsx`).
- Title: `t('pageTitle')` = "Almanac"
- Icon: Phosphor `ph:star-four` or similar astronomical icon
- Info: station name or "Astronomical data for [location]"
- `as="h1"` for semantic heading

### Surface B — Sun & Moon Combined (`full`, auto height ~22rem)

**Internal layout:** CSS grid `grid-template-columns: 1fr 2fr 1fr` at md+; single column at mobile.

**Center (2fr):** Enlarged `ArcVisualization` from `sun-moon-card.tsx` (lines 172–368).
- Reuse `arcPoint()`, `ellipsePath()`, `arcProgress()` functions
- Scale up: larger SVG viewBox (e.g., 440×220 vs current 220×110), proportionally scaled radii
- Larger time labels (12px vs current 10px), larger phase label
- Same colors: sun `#f59e0b`, moon `#94a3b8`, dash pattern `7 4`
- Moon phase label with crescent marker (lines 292–324)

**Left panel (1fr) — Sun data:**

| Field | Source | Treatment |
|---|---|---|
| Sunrise | `almanac.sun.rise` | formatLocalTime (station TZ) |
| Sunset | `almanac.sun.set` | formatLocalTime |
| Civil Dawn | `almanac.sun.civilTwilightDawn` | formatLocalTime |
| Civil Dusk | `almanac.sun.civilTwilightDusk` | formatLocalTime |
| Total Daylight | `almanac.sun.daylightMinutes` | "Xh Ym" + delta vs yesterday |
| Solar Noon | `almanac.sun.transit` | formatLocalTime |
| Next Solstice | `almanac.sun.nextSolstice` | formatDate |
| Next Equinox | `almanac.sun.nextEquinox` | formatDate |
| Sun Azimuth | `almanac.sun.azimuth` | "X.X°" |
| Sun Altitude | `almanac.sun.altitude` | "X.X°" |

**Right panel (1fr) — Moon data:**

| Field | Source | Treatment |
|---|---|---|
| Phase | `almanac.moon.phaseName` | Emoji + title case |
| Illumination | `almanac.moon.illuminationPercent` | "XX%" |
| Moonrise | `almanac.moon.rise` | formatLocalTime |
| Moonset | `almanac.moon.set` | formatLocalTime |
| Next Full Moon | `almanac.moon.nextFullMoon` | formatDate |
| Next New Moon | `almanac.moon.nextNewMoon` | formatDate |
| Moon Names | `moonNames.name` + `specialDesignations` | Badges (existing pattern) |
| Moon Azimuth | `almanac.moon.azimuth` | "X.X°" |
| Moon Altitude | `almanac.moon.altitude` | "X.X°" |

**Mobile collapse:** Arc graphic full-width at top, then left panel (sun) stacks below, then right panel (moon).

**Data hooks:** `useAlmanac()` (line 253 of useWeatherData.ts) + `useAlmanacMoonNames()` (line 807).

**A11y:** SVG has `role="img"` + `<title>`. `aria-live="polite"` on content. All time labels as visible text (not color-only).

### Surface C — Planets Timeline (`full`, auto height ~22rem)

**Modeled on:** `docs/design/inspiration/planet_viewing_window.png`

**Top section:** Planet columns ordered by viewing time (earliest visible → latest), each showing:
- NASA thumbnail (~48px WebP from `public/images/planets/`)
- Viewing quality badge: ✅ already in API response as `viewingQuality` (Excellent/Good/Fair/Poor/Not Visible) — computed by BFF from 7Timer seeing forecast + altitude + transparency. Dashboard reads it directly, no client-side computation needed.
- Best viewing time + clear window: `bestViewingTime` and `clearWindowStart`/`clearWindowEnd` from BFF enrichment
- Sky position: direction + altitude ("High in the south", "In the east")
- Conjunction callout: `conjunction` field from BFF when planet is within 5° of Moon

**Bottom section:** SVG Gantt-chart timeline:
- X-axis: sunset → sunrise (from `almanac.sun.set` → next `almanac.sun.rise`)
- Three labeled sections: EVENING / NIGHT / MORNING (with moon icon at NIGHT)
- Per-planet horizontal bar spanning its visible window, color-matched to natural planet hue
- Time markers at 2-hour intervals

**Mobile:** Planet row scrollable horizontally; timeline compressed or stays horizontal with scroll.

**Data:** `useAlmanacPlanets()` (line 762 of useWeatherData.ts) + `useAlmanac()` for sun rise/set.
PlanetEntry already has: `magnitude`, `transitTime`, `rightAscension`, `declination`, `elongation` (API), plus `viewingQuality`, `viewingScore`, `bestViewingTime`, `clearWindowStart`, `clearWindowEnd`, `conjunction`, `viewingNote` (BFF enrichment). ✅ All data fields done — dashboard just needs to render them.

### Surface D — Monthly Averages (`full`, auto height ~22rem)

Re-skin of existing Recharts ComposedChart (almanac.tsx lines 504–624).
- Extract to standalone `MonthlyAveragesCard` component
- Wrap in `<Card footprint="full">` + `<CardHeader>` + `<CardContent>`
- Apply typography tokens: Lexend for axis/tick labels, Manrope for title
- Keep sr-only data table (already exists, lines 514–535)
- Apply chart palette from ADR-048 when multi-series

**Data:** `useClimatologyMonthly()` (line 740 of useWeatherData.ts). No changes.

### Surface E — Solar Eclipses (`full`, auto height ~22rem) — NET-NEW

**Modeled on:** `docs/design/inspiration/solar_eclipse_schedule.png`

**Layout:** Horizontal columns (2–4 eclipses visible in the next ~2 years), each showing:
- Date + day of week (derivable from ISO date)
- Type badge with color coding: Total (red), Annular (amber), Partial (grey)
- NASA hero photo per type (~3 WebP assets in `public/images/eclipses/`)
- Contact times: Begin (partialStart), Maximum (peak), End (partialEnd) — from AstronomyAPI.com
- Local visibility: derived from altitude values
  - `peak.altitude < 0` → "Not visible from your location"
  - `totalStart !== null` → "Within the path of totality/annularity"
  - `peak.altitude > 30` → "Excellent visibility"
  - else → "Visible" with altitude note
- Brief description (static per type, e.g., "Total solar eclipse. The Sun will be completely covered by the Moon.")
- Bottom legend: 3 type icons with definitions
- "All times local" indicator top-right

**Mobile:** Columns stack vertically. Each column is collapsed (date + type badge + photo visible), expandable to show contact times + description.

**Data:** New `useSolarEclipses()` hook → new `GET /almanac/eclipses/solar` endpoint.

**Graceful degradation:** If AstronomyAPI.com credentials not configured, card shows "Configure AstronomyAPI.com in the setup wizard to see eclipse timing details" or simply hides contact times and shows Skyfield-detected dates only.

### Surface F — Lunar Eclipses (`full`, auto height ~22rem)

**Modeled on:** `docs/design/inspiration/lunar_eclipse_schedule.png`

Same column layout as Solar Eclipses. Per-eclipse column:
- Date + day of week
- Type badge: Total (red), Partial (amber), Penumbral (grey)
- Eclipse moon photo per type (~3 WebP assets)
- Contact times from AstronomyAPI.com eventHighlights
- Viewing window: penumbralStart → penumbralEnd (or partialStart → partialEnd for partial)
- Visibility: "Visible All Night" (all contacts altitude > 0), "Mostly Visible" (peak altitude > 0, some contacts below horizon), "Low in Sky" (peak altitude 0–15°), "Not visible" (peak altitude < 0)
- Description (static per type)
- Bottom legend with 3 types

**Mobile:** Same as Solar — stackable, expandable.

**Data:** New `useLunarEclipses()` hook → new `GET /almanac/eclipses/lunar` endpoint.
Skyfield fallback: existing `useAlmanacEclipses()` (line 831) returns dates + types without times.

### Surface G — Meteor Showers (`full`, auto height ~22rem)

**Modeled on:** `docs/design/inspiration/meteor_shower_schedule.png`

**Layout:** Horizontal columns (5–7 upcoming showers), each showing:
- Shower name + active date range (e.g., "Dec 28 – Jan 12")
- AI-generated meteor streak hero image (from `public/images/meteors/`, ~6 images rotated)
- "Peak Night" with specific dates (e.g., "Jan 3 – 4, 2026")
- ZHR ("Up to 110 meteors/hr")
- Viewing quality badge: "Excellent" / "Good" / "Fair" (computed from moon interference + radiant altitude)
- Brief description (from catalog: "Fast and bright meteors, known for persistent trails")
- Bottom legend: viewing quality definitions
  - Excellent: "Clear, dark skies with minimal moonlight interference"
  - Good: "Mostly clear skies with minimal moonlight"
  - Fair: "Some moonlight interference may reduce visibility"

**Mobile:** Stackable columns, expandable. Collapsed: name + peak + quality badge. Expanded: full detail.

**Data:** Enhanced `useAlmanacMeteorShowers()` (line 853) → enhanced `GET /almanac/meteor-showers` with new fields.

---

## 6. Granular task list

### PHASE 0 — Documentation & Assets (blocks ALL code)

**T0.1 — Save AstronomyAPI.com credentials**
- Owner: **coordinator** · Dep: none
- Files: `reference/CREDENTIALS.md`
- Do: Add AstronomyAPI.com section with app_id, app_secret, origin URL, signup link, free tier info
- Accept: Credentials saved, not committed to git
- QC: coordinator verifies file is in .gitignore or equivalent

**T0.2 — Save AstronomyAPI.com endpoint documentation**
- Owner: **coordinator** · Dep: none
- Files: `docs/reference/api-docs/astronomyapi.md` (new file)
- Do: Document all endpoints (Events/moon, Events/sun, Moon Phase, Positions, Star Chart, Search), request/response schemas, auth method, rate limits, query param requirements. Include exact response JSON examples from §4.1 above.
- Accept: Complete reference doc matching the format of existing api-docs (e.g., `nws.md`, `aeris.md`)
- QC: coordinator reviews completeness against §4.1

**T0.3 — Source and compress static image assets**
- Owner: **coordinator** · Dep: none
- Files: `repos/weewx-clearskies-dashboard/public/images/planets/` (7 files), `public/images/eclipses/` (6 files), `public/images/meteors/` (6 files)
- Do: Source NASA/JPL planet thumbnails (Mercury–Neptune), solar eclipse photos (total corona, annular ring of fire, partial), lunar eclipse moon photos (total blood moon, partial shadow, penumbral dimming). Crop and compress all to WebP, max 15 KB each. Crop 6 individual meteor streak images from `docs/design/inspiration/meteor_streaks_imagery_Generated.png`.
- Accept: 19 WebP files, all < 15 KB, visually clear at 48–80px display size. Planets recognizable. Eclipse types visually distinct.
- QC: coordinator opens each image and verifies quality

**T0.4 — Build HTML mockup of full almanac page**
- Owner: **coordinator** · Dep: T0.3 (needs images)
- Files: `docs/design/mockups/C7-almanac-page.html` (new)
- Do: Self-contained HTML mockup showing all 7 cards at locked footprints in the A4 grid CSS (copy from `A4-page-anatomy.html`). Use real @fontsource woff2 fonts, real glass tokens, real images from T0.3. Both light and dark theme variants. Cards at `full` width with `md:auto-rows-[auto]`. Internal 1/2/1 grid for Sun & Moon card. Gantt timeline for Planets. Column layouts for eclipses and meteors. Mobile-collapsed variants.
- Accept: Headless render produces clean PNG at 1400×900. Both themes render correctly. Typography matches locked tokens. All cards within grid.
- QC: coordinator renders headless PNG, opens and LOOKS. Operator approves mockup before Phase 1 proceeds.

### PHASE 1 — API Work (clearskies-api repo)

**T1.1 — Add AstronomyAPI.com settings to config**
- Owner: `clearskies-api-dev` · Dep: T0.1
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py` (add to AlmanacSettings class, line 300)
- Do: Add `astronomyapi_app_id: str | None` and `astronomyapi_app_secret: str | None` fields to `AlmanacSettings.__init__()`. Read from env vars `WEEWX_CLEARSKIES_ASTRONOMYAPI_APP_ID` and `WEEWX_CLEARSKIES_ASTRONOMYAPI_APP_SECRET` per the same pattern as Aeris credentials (line 397–401). Null when not set.
- Accept: `AlmanacSettings` has 2 new fields. `ruff` + `mypy` clean. Missing env vars → fields are None (not crash).
- QC: coordinator diff review

**T1.2 — Add AstronomyAPI.com credentials to setup wizard**
- Owner: `clearskies-api-dev` · Dep: T1.1
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/setup.py`, related wizard state/models
- Do: Add optional step for AstronomyAPI.com credentials (app_id + app_secret). Include explanation text: "AstronomyAPI.com provides eclipse contact times and local visibility. Free signup at https://astronomyapi.com/auth/signup". Mark as optional — wizard completes without them. Credentials saved to secrets.env per ADR-027.
- Accept: Wizard step renders. Submitting valid credentials → saved to env. Skipping → null fields. `ruff` + `mypy` clean.
- QC: coordinator reviews wizard flow, verifies credentials are stored per ADR-027 (env vars, not INI)

**T1.3 — Create AstronomyAPI.com HTTP client**
- Owner: `clearskies-api-dev` · Dep: T1.1
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/services/astronomyapi_client.py` (new)
- Do: Create HTTP client class `AstronomyApiClient` with:
  - Constructor takes `app_id`, `app_secret` (from settings). Raises if either is None (caller checks first).
  - HTTP Basic Auth header: base64(`app_id:app_secret`)
  - `get_lunar_eclipses(lat, lon, elevation, from_date, to_date)` → calls Events endpoint body=moon
  - `get_solar_eclipses(lat, lon, elevation, from_date, to_date)` → calls Events endpoint body=sun
  - Response parsing: extract event type, eventHighlights (contact times + altitudes), obscuration
  - Error handling: timeout (10s), HTTP errors → log warning + return empty list (graceful degradation)
  - Uses `httpx` (already in deps) or `requests`
  - **No caching in client** — caching handled by the cache_warmer layer (existing pattern)
- Accept: Client makes correct HTTP Basic auth calls. Parses response schema correctly. Returns typed dicts. Handles errors gracefully (empty list, not crash). `ruff` + `mypy` clean.
- QC: coordinator reviews auth implementation (no credential leaks in logs), error handling, response parsing against §4.1 schema

**T1.4 — Create solar eclipse endpoint**
- Owner: `clearskies-api-dev` · Dep: T1.3
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/almanac.py` (add new handler after line 541), `models/responses.py` (new models), `models/params.py` (new params)
- Do:
  - New response model `SolarEclipseEntry` with fields: `date`, `type` ("total"|"annular"|"partial"), `contactTimes` (object with `partialStart`, `totalStart`, `peak`, `totalEnd`, `partialEnd` — each `{date, altitude}` or null), `obscuration` (float|null), `visibility` (string|null — "Visible"/"Not visible"/"Within path of totality/annularity")
  - New endpoint `GET /almanac/eclipses/solar` with same params pattern as existing eclipses (from_, to)
  - Handler calls `AstronomyApiClient.get_solar_eclipses()` if credentials configured; returns empty list if not
  - Compute visibility string from altitude values (§5 Surface E logic)
- Accept: Endpoint returns correct JSON. Solar eclipses have contact times when AstronomyAPI.com configured. Returns empty list (not error) when credentials missing. `ruff` + `mypy` clean.
- QC: coordinator tests endpoint on weewx container with real credentials, verifies response matches contract

**T1.5 — Enrich lunar eclipse endpoint**
- Owner: `clearskies-api-dev` · Dep: T1.3
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/almanac.py` (modify `get_eclipses()` at line 484), `models/responses.py` (update `LunarEclipseEntry` at line 457)
- Do:
  - Rename endpoint route from `/almanac/eclipses` to `/almanac/eclipses/lunar`
  - Add `contactTimes` object (same structure as solar: penumbralStart, partialStart, fullStart, peak, fullEnd, partialEnd, penumbralEnd — each `{date, altitude}` or null)
  - Add `obscuration` (float|null), `visibility` (string: "Visible All Night"/"Mostly Visible"/"Low in Sky"/"Not visible")
  - Merge Skyfield-detected eclipses (existing) with AstronomyAPI.com contact times (new)
  - Compute visibility: all contacts altitude > 0 → "Visible All Night"; peak > 0 but some < 0 → "Mostly Visible"; peak 0–15° → "Low in Sky"; peak < 0 → "Not visible"
  - Keep backward compatibility: old `/almanac/eclipses` route redirects or is aliased
- Accept: Enriched response with contact times. Skyfield dates + AstronomyAPI times merged correctly. Visibility computed correctly. Graceful when AstronomyAPI missing. `ruff` + `mypy` clean.
- QC: coordinator tests on weewx container, verifies contact times match AstronomyAPI.com, verifies visibility logic

**T1.6 — Externalize meteor shower catalog to JSON**
- Owner: `clearskies-api-dev` · Dep: none
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/data/meteor_showers.py` (modify), new `/etc/weewx-clearskies/meteor_showers.json` (template at `repos/weewx-clearskies-api/data/meteor_showers.json`), `config/settings.py` (add path setting)
- Do:
  - Add `meteor_showers_catalog` path to `AlmanacSettings` (default: `/etc/weewx-clearskies/meteor_showers.json`)
  - Create JSON catalog with ~25 showers (expand from current 12). Add fields: `id`, `description`, `solar_longitude_max`, `image` (filename). Keep existing fields.
  - Modify `compute_meteor_showers()` (line 1199) to read from JSON catalog instead of `METEOR_SHOWERS` Python list
  - Add JSON schema validation on load (warn on malformed entries, skip them, don't crash)
  - Fallback: if JSON file missing, use embedded Python catalog (existing `METEOR_SHOWERS` list)
  - Ship default JSON alongside the API package
- Accept: API reads from JSON. Adding/removing a shower in JSON changes endpoint output (no code change needed). Missing JSON → fallback to Python list with warning log. Malformed entries skipped with warning. `ruff` + `mypy` clean.
- QC: coordinator edits JSON on weewx container, verifies change appears in API response. Verifies malformed entry is skipped. Verifies missing file fallback.

**T1.7 — Enrich meteor shower endpoint**
- Owner: `clearskies-api-dev` · Dep: T1.6
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/almanac.py` (modify `get_meteor_showers()` at line 541), `models/responses.py` (update `MeteorShowerEntry` at line 479), `services/almanac.py` (modify `compute_meteor_showers()` at line 1199)
- Do:
  - Add new response fields to `MeteorShowerEntry`: `activeStart` (ISO date), `activeEnd` (ISO date), `description` (string), `viewingQuality` ("Excellent"|"Good"|"Fair"|"Poor"), `image` (string, filename)
  - Compute `activeStart`/`activeEnd` from `peak_date ± duration_days/2`
  - Compute `viewingQuality` from existing moon illumination + radiant altitude:
    - radiant_alt < 10° → "Poor"
    - moon_illum > 75% AND radiant_alt < 30° → "Fair"
    - moon_illum < 25% AND radiant_alt > 40° → "Excellent"
    - else → "Good"
  - Pass `description` and `image` from JSON catalog through to response
- Accept: Response includes all new fields. Viewing quality computed correctly for edge cases (high moon + low radiant = Fair; low moon + high radiant = Excellent). `ruff` + `mypy` clean.
- QC: coordinator verifies viewing quality for known cases (e.g., Perseids with crescent moon → Excellent; Quadrantids with full moon → Fair)

**T1.8 — ~~Add planet magnitude to planets endpoint~~ ✅ SUPERSEDED**
- **Status:** DONE — superseded by [PLANET-VIEWING-QUALITY-PLAN](../../archive/PLANET-VIEWING-QUALITY-PLAN.md) (2026-06-04).
- Magnitude, RA/Dec, elongation, transit time added to API. Per-planet viewing quality (Excellent/Good/Fair/Poor/Not Visible) computed in BFF via 7Timer seeing forecast + altitude + transparency + cloud gate + Mercury/Uranus/Neptune special cases. Far more sophisticated than the original altitude+magnitude formula.
- Commits: API `001b2cc`, `67e5cba`, `49c1bb2`, `0caa067`; BFF `6fba919`, `1d6868a`; Dashboard `d47aa72`, `28596ed`, `96c126c`.

**T1.9 — Update OpenAPI contract**
- Owner: `clearskies-api-dev` · Dep: T1.4, T1.5, T1.7, ~~T1.8~~
- Files: `docs/contracts/openapi-v1.yaml` (authoritative) + `repos/weewx-clearskies-dashboard/src/api/openapi-v1.yaml` (sync copy)
- Do: Update/add schemas for: `SolarEclipseEntry`, enriched `LunarEclipseEntry`, enriched `MeteorShowerEntry`. Add new endpoint `/almanac/eclipses/solar`. Update `/almanac/eclipses` → `/almanac/eclipses/lunar`. Sync both copies.
- **Partially done (2026-06-04):** `PlanetEntry` schema (with viewing quality fields), `/almanac/seeing-forecast` endpoint, and `SeeingForecastResponse` schema already added to contract (commits `3130077`, `28596ed`). Remaining: eclipse + meteor schemas.
- Accept: YAML valid. Both copies identical. New schemas match actual API response.
- QC: coordinator diff review, validates YAML syntax

**T1.10 — API tests**
- Owner: `clearskies-api-dev` · Dep: T1.3, T1.4, T1.5, T1.6, T1.7, T1.8
- Files: `repos/weewx-clearskies-api/tests/` (new + modified test files)
- Do:
  - Unit tests for `AstronomyApiClient`: mock HTTP responses, verify parsing, verify auth header, verify error handling (timeout, 500, malformed JSON)
  - Unit tests for viewing quality computation (meteor + planet): edge cases per the formulas in T1.7/T1.8
  - Unit tests for JSON catalog loading: valid file, missing file (fallback), malformed entries (skip)
  - Unit tests for visibility classification (lunar + solar): all altitude combinations
  - Integration test: verify enriched endpoints return correct response shapes
- Accept: **pytest output: all new tests pass, 0 failures.** Test names clearly describe what they verify.
- QC: coordinator re-runs full test suite independently on weewx container

**T1.11 — Update cache warmer**
- Owner: `clearskies-api-dev` · Dep: T1.4, T1.5
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/services/cache_warmer.py` (modify `_warm_eclipses()` at line 319)
- Do: Update eclipse warming to call both lunar and solar endpoints. Add solar eclipse cache key pattern.
- Accept: Cache warmer pre-computes both eclipse types. `ruff` + `mypy` clean.
- QC: coordinator diff review

### PHASE 2 — Dashboard Work (clearskies-dashboard repo)

**T2.1 — Update TypeScript types**
- Owner: `clearskies-dashboard-dev` · Dep: T1.9
- Files: `repos/weewx-clearskies-dashboard/src/api/types.ts`
- Do:
  - Add `SolarEclipseEntry` type with contactTimes, obscuration, visibility, type
  - Add `SolarEclipseData` type with eclipses array
  - Update `LunarEclipseEntry` (line 684): add contactTimes, obscuration, visibility
  - Update `MeteorShowerEntry` (line 698): add activeStart, activeEnd, description, viewingQuality, image
  - ~~Update `PlanetEntry` (line 637): add magnitude, viewingQuality~~ ✅ DONE — PlanetEntry already has magnitude, transitTime, RA/Dec, elongation, viewingQuality, viewingScore, bestViewingTime, clearWindow, conjunction, viewingNote (commits `d47aa72`, `28596ed`)
- Accept: `tsc --noEmit` → 0 errors. Types match OpenAPI contract from T1.9.
- QC: coordinator diff review

**T2.2 — Add/update data hooks**
- Owner: `clearskies-dashboard-dev` · Dep: T2.1
- Files: `repos/weewx-clearskies-dashboard/src/hooks/useWeatherData.ts`
- Do:
  - Add `useSolarEclipses()` hook → fetches from `/almanac/eclipses/solar`
  - Update `useAlmanacEclipses()` (line 831) to fetch from `/almanac/eclipses/lunar` (updated route)
  - Existing hooks (useAlmanac, useAlmanacPlanets, useAlmanacMeteorShowers, useClimatologyMonthly, useAlmanacMoonNames) unchanged
- Accept: New hook returns `HookResult<SolarEclipseData>`. Updated hook fetches from new route. `tsc` clean.
- QC: coordinator diff review

**T2.3 — Create SunMoonDetailCard component**
- Owner: `clearskies-dashboard-dev` · Dep: T2.1
- Files: `repos/weewx-clearskies-dashboard/src/components/almanac/SunMoonDetailCard.tsx` (new)
- Do:
  - Import and reuse `arcPoint()`, `ellipsePath()`, `arcProgress()` from `sun-moon-card.tsx` (extract to shared util if needed)
  - Internal 1/2/1 CSS grid: `grid-template-columns: 1fr 2fr 1fr` at md+, single column at mobile
  - Center: enlarged ArcVisualization (scaled-up SVG, same visual language as Now-page tile)
  - Left panel: Sun data as compact `<dl>` grid (2 items per row, `--text-body` size)
  - Right panel: Moon data + badges as compact `<dl>` grid
  - Card wrapped in `<Card footprint="full">` with `<CardHeader>` title "Sun & Moon"
  - Props: `almanac: AlmanacSnapshot | null`, `moonNames: MoonNameData | null`, `stationTz: string`, `loading`, `error`, `onRetry`
  - i18n: reuse existing `almanac.sun.*`, `almanac.moon.*`, `almanac.positional.*` keys + add any missing
  - A11y: SVG `role="img"` + `<title>`, `aria-live="polite"`, `dl` structure for screen readers
- Accept: Card renders in both themes. Arc visualization scales correctly. Mobile collapses to single column. `tsc` clean. `axe-core` 0 new violations.
- QC: **coordinator renders both themes, verifies arc proportions, verifies mobile collapse, verifies all 19 data fields render correctly with real data from weather-dev**

**T2.4 — Create PlanetTimelineCard component**
- Owner: `clearskies-dashboard-dev` · Dep: T2.1, T0.3
- Files: `repos/weewx-clearskies-dashboard/src/components/almanac/PlanetTimelineCard.tsx` (new)
- Do:
  - Top section: planet columns (flex row, horizontally scrollable on overflow)
  - Each column: `<img>` planet thumbnail (WebP from `public/images/planets/`), viewing quality badge (color-coded pill), time window, position text
  - Bottom section: SVG Gantt chart. X-axis = sunset→sunrise (sun times from almanac prop). Y-axis = planets. Colored horizontal bars. Time markers at 2hr intervals. Section labels (Evening/Night/Morning).
  - Props: `planets: PlanetsVisible | null`, `almanac: AlmanacSnapshot | null`, `stationTz: string`, `loading`, `error`
  - Sort planets by rise time (earliest first) to match mockup left→right order
  - Mobile: planet row scrollable, timeline stays horizontal with scroll
- Accept: Timeline bars correctly positioned relative to sunset/sunrise. Planet photos load. Quality badges render. `tsc` clean.
- QC: **coordinator verifies timeline positioning is astronomically correct (planet bars span actual rise→set within the night window), verifies planet photos are identifiable, verifies quality badge logic matches T1.8 formula**

**T2.5 — Create SolarEclipseCard component**
- Owner: `clearskies-dashboard-dev` · Dep: T2.2, T0.3
- Files: `repos/weewx-clearskies-dashboard/src/components/almanac/SolarEclipseCard.tsx` (new)
- Do:
  - Column layout (flex row, horizontal scroll on overflow for > 3 eclipses)
  - Per column: date + day, type badge, eclipse photo (`<img>` from `public/images/eclipses/`), contact times (if available), visibility text, description
  - Bottom legend: 3 types with color dots + definitions
  - "All times local" indicator top-right
  - Mobile: columns stack vertically. Initially collapsed (date + badge + photo). Expandable on tap (detail panel with times + description).
  - Graceful: if no eclipses → "No solar eclipses visible in the next year" message
  - Props: `eclipses: SolarEclipseData | null`, `stationTz: string`, `loading`, `error`
  - i18n: new keys under `almanac.solarEclipses.*`
- Accept: Columns render correctly. Contact times format to local TZ. Type badges color-coded. Photos load. Mobile expand/collapse works. `tsc` clean.
- QC: **coordinator verifies contact times are formatted correctly, type badge colors match mockup (Total=red, Annular=amber, Partial=grey), visibility text is correct, mobile expand/collapse is functional**

**T2.6 — Create LunarEclipseCard component**
- Owner: `clearskies-dashboard-dev` · Dep: T2.2, T0.3
- Files: `repos/weewx-clearskies-dashboard/src/components/almanac/LunarEclipseCard.tsx` (new)
- Do: Same pattern as SolarEclipseCard but with lunar eclipse types (Total/Partial/Penumbral), lunar-specific photos, lunar contact time fields (penumbralStart through penumbralEnd), lunar visibility logic.
  - Props: `eclipses: EclipseData | null` (enriched), `stationTz: string`, `loading`, `error`
  - i18n: new keys under `almanac.lunarEclipses.*`
- Accept: Same standards as T2.5. `tsc` clean.
- QC: **coordinator verifies type badges (Total=red, Partial=amber, Penumbral=grey), verifies viewing window shows penumbral-to-penumbral range (not just partial), verifies "Not visible" eclipses are dimmed or marked**

**T2.7 — Create MeteorShowerCard component**
- Owner: `clearskies-dashboard-dev` · Dep: T2.2, T0.3
- Files: `repos/weewx-clearskies-dashboard/src/components/almanac/MeteorShowerCard.tsx` (new)
- Do:
  - Column layout (flex row, horizontal scroll for > 5 showers)
  - Per column: name + active date range, meteor streak hero image, "Peak Night" dates, ZHR, viewing quality badge, description
  - Bottom legend: viewing quality definitions
  - Mobile: columns stack vertically, expandable (collapsed = name + peak + badge)
  - Props: `showers: MeteorShowerData | null` (enriched), `stationTz: string`, `loading`, `error`
  - i18n: new keys under `almanac.meteorShowers.*`
- Accept: Columns render. Streak images load. Quality badges color-coded. ZHR formatted. Mobile expand/collapse works. `tsc` clean.
- QC: **coordinator verifies shower data matches API response, viewing quality badges are correct, active date ranges are accurate, descriptions render**

**T2.8 — Extract MonthlyAveragesCard component**
- Owner: `clearskies-dashboard-dev` · Dep: none
- Files: `repos/weewx-clearskies-dashboard/src/components/almanac/MonthlyAveragesCard.tsx` (new, extracted from almanac.tsx lines 504–624)
- Do:
  - Move Recharts ComposedChart from almanac.tsx to standalone component
  - Wrap in `<Card footprint="full">` + proper CardHeader/CardContent
  - Apply typography tokens: Lexend for axis labels (`--font-chart`), Manrope for title
  - Keep sr-only data table
  - Props: `climatology: ClimatologyMonthly | null`, `loading`, `error`
- Accept: Chart renders identically to current. Typography tokens applied. sr-only table preserved. `tsc` clean.
- QC: coordinator diff review

**T2.9 — Rewrite almanac.tsx route**
- Owner: `clearskies-dashboard-dev` · Dep: T2.3, T2.4, T2.5, T2.6, T2.7, T2.8
- Files: `repos/weewx-clearskies-dashboard/src/routes/almanac.tsx` (rewrite)
- Do:
  - Replace entire page with Grid template pattern (forecast.tsx as reference)
  - Outer wrapper: `<div className="flex flex-col gap-4">` + sr-only `<h1>`
  - `<Grid className="md:auto-rows-[auto]">` containing:
    1. `<PageHeaderCard title={t('pageTitle')} icon={...} as="h1" />`
    2. `<SunMoonDetailCard ... />`
    3. `<PlanetTimelineCard ... />`
    4. `<MonthlyAveragesCard ... />`
    5. `<SolarEclipseCard ... />`
    6. `<LunarEclipseCard ... />`
    7. `<MeteorShowerCard ... />`
  - Wire all data hooks (useAlmanac, useAlmanacMoonNames, useAlmanacPlanets, useClimatologyMonthly, useSolarEclipses, useAlmanacEclipses, useAlmanacMeteorShowers)
  - Remove all inline card JSX (Sun card, Moon card, Positional, etc.)
  - Remove inline helper functions that are now in components (formatLocalTime, formatDaylight, formatDate, etc. — move to shared util if reused)
- Accept: Page renders all 7 cards in Grid. No inline card JSX remaining. All data wired correctly. `tsc --noEmit` → 0 errors. `vite build` → clean.
- QC: **coordinator verifies page renders in both themes, all 7 cards visible, responsive 4→2→1 collapse works, no console errors**

**T2.10 — Update i18n translations**
- Owner: `clearskies-dashboard-dev` · Dep: T2.3–T2.7
- Files: `repos/weewx-clearskies-dashboard/public/locales/en/almanac.json`
- Do: Add new keys for all surfaces:
  - `solarEclipses.*` (title, types, visibility labels, descriptions, legend)
  - `lunarEclipses.*` (title, types, visibility labels, descriptions, legend)
  - `meteorShowers.*` (title, viewingQuality labels, legend)
  - `planets.*` (title, viewingQuality labels, timeline labels)
  - `sunAndMoon.*` (combined card title, section headers if needed)
  - Keep existing keys (`sun.*`, `moon.*`, `positional.*`)
- Accept: All user-visible strings use i18n keys. No hardcoded English in components. `tsc` clean.
- QC: coordinator grep for hardcoded strings in new components

**T2.11 — Update mock data**
- Owner: `clearskies-dashboard-dev` · Dep: T2.1
- Files: `repos/weewx-clearskies-dashboard/src/mock/eclipses.ts`, `src/mock/meteorShowers.ts`, `src/mock/planets.ts` (update existing), `src/mock/solarEclipses.ts` (new)
- Do: Update mock data to include new fields (contactTimes, visibility, viewingQuality, magnitude, activeStart, activeEnd, description, image). Add solar eclipse mock data.
- **Partially done (2026-06-04):** `planets.ts` mock updated with all new PlanetEntry fields (commit `96c126c`). Remaining: eclipses, meteorShowers, solarEclipses mocks.
- Accept: Mock data matches updated TypeScript types. App renders correctly in mock mode.
- QC: coordinator diff review

### PHASE 3 — Audit & Verification

**T3.1 — Type check + build verification**
- Owner: **coordinator** · Dep: T2.9
- Do: Run `tsc --noEmit` and `vite build` in dashboard repo. Zero errors.
- Accept: `tsc --noEmit` → 0 errors. `vite build` → clean build output, no warnings.
- QC: coordinator runs independently

**T3.2 — Visual verification (both themes)**
- Owner: **coordinator** · Dep: T3.1
- Do: Start dev server on weather-dev. Open in browser at `http://192.168.2.113:5173/almanac`. Verify all 7 cards in both light and dark themes. Check responsive collapse (resize to 768px, then 480px). Screenshot evidence.
- Accept: All cards render correctly. No visual regressions. Responsive collapse works (4→2→1). Both themes readable.
- QC: coordinator does this personally (not delegated)

**T3.3 — Accessibility audit**
- Owner: **coordinator** · Dep: T3.1
- Do: Run `axe-core` on `/almanac`. Keyboard Tab walkthrough (all interactive elements reachable). Screen reader spot-check on Sun & Moon card + expand/collapse on meteor card.
- Accept: 0 new axe violations. All expandable sections keyboard-accessible. SVGs have `role="img"` + `<title>`.
- QC: coordinator does this personally

**T3.4 — Live data verification**
- Owner: **coordinator** · Dep: T3.2
- Do: Verify with real data on weather-dev:
  - Sun & Moon card shows correct sunrise/sunset for station TZ (cross-check with USNO)
  - Planet timeline shows planets visible tonight (cross-check with stellarium or timeanddate.com)
  - Eclipse contact times match AstronomyAPI.com (manual API call comparison)
  - Meteor shower viewing quality is reasonable (check moon phase on peak night)
  - Monthly averages chart shows 12 months of data
- Accept: All data verifiable against external sources. No obviously wrong values.
- QC: coordinator does this personally

**T3.5 — API test suite on weewx container**
- Owner: **coordinator** · Dep: T1.10
- Do: SSH to weewx container, run full API test suite. Verify all new tests pass. Verify no regressions in existing almanac tests.
- Accept: **pytest output: N passed / 0 failures** for almanac test module.
- QC: coordinator runs and reads output

---

## 7. Dependency graph

```
T0.1 (credentials) ──┬─→ T1.1 (config) ──→ T1.2 (wizard)
                      │                  └─→ T1.3 (HTTP client) ──┬─→ T1.4 (solar endpoint)
                      │                                           └─→ T1.5 (lunar endpoint)
T0.2 (docs)           │
                      │
T0.3 (images) ────────┼─→ T0.4 (mockup) ─── GATE: operator approval
                      │
                      │   T1.6 (JSON catalog) ──→ T1.7 (meteor enrich)
                      │   T1.8 (planet magnitude)
                      │
                      │   T1.4 + T1.5 + T1.7 + T1.8 ──→ T1.9 (OpenAPI) ──→ T1.10 (tests)
                      │                                                  └─→ T1.11 (cache warmer)
                      │
                      └─→ T1.9 ──→ T2.1 (types) ──→ T2.2 (hooks)
                                                  └─→ T2.11 (mocks)
                           T0.3 + T2.2 ──→ T2.3 (SunMoon)
                                       ──→ T2.4 (Planets)
                                       ──→ T2.5 (SolarEclipse)
                                       ──→ T2.6 (LunarEclipse)
                                       ──→ T2.7 (MeteorShower)
                           T2.8 (MonthlyAverages) — no deps
                           
                           T2.3–T2.8 ──→ T2.9 (route rewrite) ──→ T2.10 (i18n)
                           
                           T2.9 ──→ T3.1 (tsc+build) ──→ T3.2 (visual) ──→ T3.3 (a11y)
                                                                         ──→ T3.4 (live data)
                           T1.10 ──→ T3.5 (API tests on weewx)

Parallelizable:
  - T1.6, T1.8 can run parallel with T1.3→T1.4→T1.5
  - T2.3, T2.4, T2.5, T2.6, T2.7, T2.8 can ALL run parallel (independent components)
  - T0.1, T0.2, T0.3 can all run parallel (Phase 0)
```

---

## 8. QC ownership

| Gate | What | Who |
|---|---|---|
| **Mockup approval** | Headless PNG render, both themes, locked footprints, typography | Coordinator renders + LOOKS. Operator sign-off. |
| **API code review** | Every API task (T1.1–T1.11): diff review, `ruff`+`mypy` clean, security (no credential leaks) | Coordinator reviews every diff |
| **API functional verification** | Eclipse contact times correct, viewing quality formulas correct, JSON catalog editable | Coordinator tests on weewx container with real credentials + real station data |
| **Dashboard code review** | Every dashboard task (T2.1–T2.11): diff review, `tsc` clean | Coordinator reviews every diff |
| **Dashboard functional verification** | All 7 cards render correctly, data is accurate, responsive works, a11y clean | Coordinator tests on weather-dev in browser, both themes, all breakpoints |
| **Prompt faithfulness** | All 7 surfaces delivered per §5 spec. All data fields from spec present. | Coordinator walks §5 against live page |

**Coordinator = the lead (me). Agents execute; coordinator verifies. No agent self-attests completion.**

---

## 9. Verification bar (definition of "done")

- [ ] `tsc --noEmit` → 0 errors (dashboard)
- [ ] `vite build` → clean (dashboard)
- [ ] `ruff` + `mypy` clean (API)
- [ ] `pytest` → all new tests pass, 0 failures (API, on weewx container)
- [ ] `axe-core` → 0 new violations on `/almanac`
- [ ] Visual verification: both themes render correctly (screenshot evidence)
- [ ] Responsive: 4→2→1 column collapse verified (screenshot at 1400px, 768px, 480px)
- [ ] Live data: Sun/Moon times match USNO, planet positions reasonable, eclipse times match AstronomyAPI.com
- [ ] Mobile: expand/collapse works on eclipse + meteor cards
- [ ] Keyboard: Tab walkthrough reaches all interactive elements
- [ ] All 7 surfaces from §5 present and rendering
- [ ] All inspiration mockups referenced and visually matched
- [ ] Meteor shower JSON catalog editable without code changes (verified on weewx)
- [ ] Eclipse endpoints gracefully degrade without AstronomyAPI.com credentials

---

## 10. Implementation reference (verified file:line)

### API repo (`repos/weewx-clearskies-api/`)

| What | File | Line(s) |
|---|---|---|
| Almanac endpoints | `weewx_clearskies_api/endpoints/almanac.py` | get_eclipses: 484, get_meteor_showers: 541, get_planets: 410 |
| Almanac service | `weewx_clearskies_api/services/almanac.py` | compute_lunar_eclipses: 1142, compute_meteor_showers: 1199, compute_planets: 872 |
| Meteor shower catalog | `weewx_clearskies_api/data/meteor_showers.py` | METEOR_SHOWERS list: 26, MeteorShowerData: 14 |
| AlmanacSettings | `weewx_clearskies_api/config/settings.py` | class: 300, ephemeris_directory: 307 |
| Provider credential pattern | `weewx_clearskies_api/config/settings.py` | Aeris env vars: 397–401, OWM env vars: 403–407, Wunderground: 777–778 |
| Cache warmer (almanac) | `weewx_clearskies_api/services/cache_warmer.py` | _warm_eclipses: 319, _warm_meteor_showers: 339, _warm_planets: 297 |
| Response models | `weewx_clearskies_api/models/responses.py` | LunarEclipseEntry: 457, MeteorShowerEntry: 479, PlanetEntry: 431 |
| Query param models | `weewx_clearskies_api/models/params.py` | EclipsesQueryParams: 275, MeteorShowersQueryParams: 307 |
| Setup/wizard | `weewx_clearskies_api/endpoints/setup.py` | Router: 49 |
| Existing tests | `tests/test_almanac_unit.py` | Ephemeris fixture: 69, phase tests: 102 |

### Dashboard repo (`repos/weewx-clearskies-dashboard/`)

| What | File | Line(s) |
|---|---|---|
| Almanac route (REWRITE target) | `src/routes/almanac.tsx` | Sun card: 320–385, Moon: 387–448, Positional: 450–486, Chart: 504–624, Planets: 632–691, Eclipses: 699–735, Meteors: 743–789 |
| Sun & Moon Now tile (REUSE arc) | `src/components/sun-moon-card.tsx` | ArcVisualization: 172–368, arcPoint: 78–91, ellipsePath: 98–102, constants: 41–54 |
| TypeScript types | `src/api/types.ts` | AlmanacSnapshot: 347, PlanetEntry: 637, EclipseEntry: 684, MeteorShowerEntry: 698, ClimatologyMonthly: 624 |
| Data hooks | `src/hooks/useWeatherData.ts` | useAlmanac: 253, useAlmanacPlanets: 762, useAlmanacEclipses: 831, useAlmanacMeteorShowers: 853, useClimatologyMonthly: 740 |
| Card primitive | `src/components/ui/card.tsx` | Card: 41, footprint map: 23–28, CardHeader: 69, CardContent: 127 |
| Grid primitive | `src/components/layout/grid.tsx` | Grid: 38 |
| PageHeaderCard | `src/components/layout/page-header-card.tsx` | Component: 67 |
| Forecast page (TEMPLATE) | `src/routes/forecast.tsx` | Grid usage: 61, PageHeaderCard: 63 |
| i18n (almanac) | `public/locales/en/almanac.json` | Full file (existing keys for sun/moon/positional/daylightDelta) |
| Mock data | `src/mock/almanac.ts`, `planets.ts`, `eclipses.ts`, `meteorShowers.ts`, `moonNames.ts`, `climatology.ts` | Various |

---

## 11. Out of scope

- **Year-long sunrise/sunset chart** — requires `/almanac/sun-times` endpoint (exists but no card designed)
- **Year-long daylight chart** — same
- **Moon phase calendar** — requires `/almanac/moon-phases` endpoint (exists but no card designed)
- **Operator drag-and-drop grid** — separate future plan
- **Non-English translations** — en-only for new i18n keys; translation pass is separate
- **Recharts background-image integration** — B2 research done but not applied to almanac charts
- **AstronomyAPI.com Star Chart or Search endpoints** — not needed for almanac
- **Planet orbital animations** — static timeline only
- **Eclipse path maps** — would require geographic path data not in AstronomyAPI.com
- **Meteor shower radiant star charts** — cool but out of scope
