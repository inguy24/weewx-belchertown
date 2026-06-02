# C5 — Active Alert Banner + Today's Highlights Strip — execution plan

**Status:** IN PROGRESS.
- Track 1 Phase 0 (research) ✅ DONE. Phase 1 (ADR) ✅ DONE. Phase 2–3 NOT STARTED.
- Track 2 (Highlights) NOT STARTED.

**Component:** C5 of the UI redesign. Parent roadmap: [UI-REDESIGN-PLAN.md](../UI-REDESIGN-PLAN.md) Track C.
**Per-component workflow:** [UI-REDESIGN-PLAN.md](../UI-REDESIGN-PLAN.md) "Per-component workflow."

---

## 0. Orientation for a fresh session (read first)

- Project rules routing: [../../CLAUDE.md](../../CLAUDE.md). **Load before acting:**
  [../../rules/coding.md](../../rules/coding.md),
  [../../rules/clearskies-process.md](../../rules/clearskies-process.md),
  [../../rules/github.md](../../rules/github.md).
- **Memory system is OFF** ([../../CLAUDE.md](../../CLAUDE.md)); plans live here in `docs/planning/`.
- **Three sub-repos** under `../../repos/`:
  - `weewx-clearskies-realtime` — BFF (Python). Agent: `clearskies-realtime-dev`.
  - `weewx-clearskies-api` — FastAPI + SQLAlchemy backend. Agent: `clearskies-api-dev`.
  - `weewx-clearskies-dashboard` — React 19 + Vite + Tailwind v4 + shadcn/ui SPA. Agent: `clearskies-dashboard-dev`.
- **Data flow:** dashboard → BFF `/api/v1/current` (REST) + SSE (live) + `/api/v1/alerts` (alerts).
- **Deploy target:** `weather-dev`. Production Belchertown skin untouched.
- **Architecture source of truth:** [../ARCHITECTURE.md](../ARCHITECTURE.md). Contract: [../contracts/openapi-v1.yaml](../contracts/openapi-v1.yaml).

### Git safety (ALL agents, ALL repos — non-negotiable)
Implementation agents may ONLY `git add`, `git commit` (local), `git status`, `git log`,
`git diff`. **NO `git pull/push/fetch/rebase/merge/remote`, NO checkout of remote branches,
NO worktree isolation.** If unexpected repo state → STOP and report. Coordinator pushes only
when operator types "push."

---

## 1. Context — what exists and what is changing

C5 covers two Now-page strip-height surfaces:

| Surface | Footprint | Current Code | What Changes |
|---|---|---|---|
| A. Active Alert Banner | `full` 4×1 (strip, 5.5rem) | `src/components/shared/alert-banner.tsx` (47 lines) — raw div outside Grid, hardcoded amber Tailwind, shows `alerts[0]` only, severity = US-centric `advisory\|watch\|warning` | **ADR-052 rewrite:** fix canonical model (3 provider modules + contract + types), then re-skin card with geography-correct severity, move inside Grid |
| B. Today's Highlights | `wide` 2×1 (strip, 5.5rem) | Inline JSX in `src/routes/now.tsx` lines 182–246 — already `footprint="wide"`, `<dl>` grid of stats | **Extract** to standalone component, add per-stat Phosphor icons, apply typography tokens |

### Grid order on Now page (after C5)
```
[Active Alert 4×1]   ← moved inside Grid (self-hides when no alerts)
[Hero 4×1]
[Current Conditions 2×2] [Wind Compass 2×2]
[Today's Forecast 2×1]   [Today's Highlights 2×1]  ← extracted
[Precip] [Baro] [Solar] [UV]   (1×1 tiles)
[AQI] [Sun&Moon] [Lightning] [Earthquake]   (1×1 tiles)
[Radar 2×2] [Webcam 2×2]
```

---

## 2. Locked operator directives (2026-06-01)

1. **ADR-052 is the governing decision** for all alert work. Accepted 2026-06-01.
2. **OWM alerts are passthrough only.** No severity classification, generic icon, neutral glass.
   Operator documentation must make the quality tradeoff explicit.
3. **Aeris alerts get full rich treatment.** Native severity labels, hazard-specific icons,
   severity-keyed visual treatment.
4. **NWS bug must be fixed.** Map from event name tier, NOT CAP severity field.
5. **5 new Material Symbols alert icons** (earthquake, volcano, hail, landslide, air/dust).
6. **Highlights stats:** keep current set (High, Low, Peak Gust, Rain Today, Peak AQI, Records Broken).
7. **No per-card ADRs.** ADR-052 + governing docs are the source of truth.

---

## 3. Locked constraints (already decided — do NOT re-theorize)

### Universal document reading list (MUST read before any code/mockup)

**TIER 0 — C5-specific governing decision:**
- [docs/decisions/ADR-052-geography-correct-alert-model.md](../decisions/ADR-052-geography-correct-alert-model.md) — **THE** governing ADR for all alert work
- [docs/reference/GLOBAL-ALERT-SYSTEMS-RESEARCH.md](../reference/GLOBAL-ALERT-SYSTEMS-RESEARCH.md) — provider wire formats, national systems, cross-mapping table §6, icon mapping §11

**TIER 1 — Locking ADRs / token specs:**
- [docs/design/design-tokens-typography.md](../design/design-tokens-typography.md) — LOCKED font families, sizes, weights
- [docs/decisions/ADR-048-theme-color-tokens.md](../decisions/ADR-048-theme-color-tokens.md) — theme colors, accent palette
- [docs/decisions/ADR-050-utility-stat-nav-icons.md](../decisions/ADR-050-utility-stat-nav-icons.md) — Phosphor base + cross-pack; 13 existing alert glyphs + 5 new per ADR-052
- [docs/decisions/ADR-051-card-footprint-model.md](../decisions/ADR-051-card-footprint-model.md) — footprints, glass surface, universal card discipline

**TIER 2 — Process & coding rules:**
- [rules/clearskies-process.md](../../rules/clearskies-process.md)
- [rules/coding.md](../../rules/coding.md) — §5 WCAG 2.1 AA, "Render and LOOK"

**TIER 3 — Design references:**
- [docs/design/mockups/A4-card-grid.html](../design/mockups/A4-card-grid.html) — locked footprints, alert glass tokens (lines 44–48 light, 68–72 dark)
- [docs/design/inspiration/NOTES.md](../design/inspiration/NOTES.md) + `raw/img-21.jpg` (grid model) + `raw/img-10.png` (per-stat icons)

**TIER 4 — Data contracts:**
- [docs/contracts/openapi-v1.yaml](../contracts/openapi-v1.yaml) — AlertRecord schema (to be updated)
- `repos/weewx-clearskies-dashboard/src/api/types.ts` — TS type definitions (to be updated)

**TIER 5 — Reference implementations:**
- `repos/weewx-clearskies-dashboard/src/components/WindCompassCard.tsx` — C2 card pattern
- `repos/weewx-clearskies-dashboard/src/components/precipitation-card.tsx` — C4 tile pattern

### Footprints
- Alert Banner: `full` 4×1 — `col-span-1 md:col-span-2 lg:col-span-4`, strip height (1 half-row track = 5.5rem)
- Today's Highlights: `wide` 2×1 — `col-span-1 md:col-span-2`, strip height (already set)

### Typography tokens (LOCKED — `design-tokens-typography.md`)
- Card title: `--text-card-title` (0.82rem), Manrope 600
- Body/labels: `--text-body` (0.9rem) / `--text-label` (0.75rem) / `--text-micro` (0.7rem), Manrope 400
- Stat values: Outfit 600 (size per context — not `--text-stat-hero` which is C1 temperature only)

### Alert glass tokens (from A4-card-grid.html)
- Light: `--alert-glass: rgba(255, 210, 100, 0.55)`, `--alert-border: rgba(200, 140, 0, 0.30)`, `--alert-fg: #78350f`
- Dark: `--alert-glass: rgba(120, 85, 10, 0.55)`, `--alert-border: rgba(255, 200, 60, 0.25)`, `--alert-fg: #fbbf24`

### Headless render command (Windows)
```
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless=new --disable-gpu `
  --screenshot="C:\tmp\render.png" --window-size=1400,900 "file:///<absolute-path-to.html>"
```
Then Read the PNG and LOOK.

---

## 4. Per-surface spec

### Surface A — Active Alert Banner (ADR-052 implementation + card re-skin)

**Two rendering modes per ADR-052:**

**Rich mode (Aeris, NWS direct):** `severityLevel` and `severityLabel` populated.
- Alert glass surface with severity-appropriate treatment
- Native severity label displayed (e.g., "Amber", "Vigilance jaune", "Warning")
- Hazard-specific icon from expanded AlertIcon map (18 categories)
- `severityLevel` 4 → `role="alert"` (ARIA assertive), 1–3 → `role="status"` (polite)
- Multi-alert: highest `severityLevel` shown as primary + "+N more" count badge

**Passthrough mode (OWM):** `severityLevel` and `severityLabel` are null.
- Neutral alert glass (standard `--alert-glass` tokens)
- Generic `ph:warning` icon
- Event text displayed as-is
- `role="status"` ARIA (polite)
- No severity label, no severity-specific color

**Layout (both modes):** Flex row inside `<Card footprint="full">`, vertically centered:
- Left: AlertIcon (20px, `--alert-fg` color)
- Center: event name (Manrope 600, `--text-card-title`) + headline (Manrope 400, `--text-label`, truncated)
- Right: "+N more" badge when `alerts.length > 1`

### Surface B — Today's Highlights

| Field | Source | Treatment |
|---|---|---|
| Today's High | `todayStats.high` + `observation.outTemp` unit | StatItem: `ph:thermometer-hot` + value (Outfit 600) + "HIGH" micro-label |
| Today's Low | `todayStats.low` + `observation.outTemp` unit | StatItem: `ph:thermometer-cold` + value + "LOW" |
| Peak Gust | `todayStats.peakGust` + `observation.windGust` unit | StatItem: `ph:wind` + value + "GUST" |
| Rain Today | `todayStats.rainSoFar` + `observation.rain` unit | StatItem: `ph:drop` + value + "RAIN" |
| Peak AQI | `todayStats.peakAQI` + category label (conditional, >0) | StatItem: `ph:leaf` + value + "AQI" |
| Records Broken | `todayStats.recordsBrokenToday` (conditional, non-empty) | StatItem: `ph:trophy` + comma-joined labels + "RECORDS" |

**Layout:** `<Card footprint="wide">` + CardHeader ("Today's Highlights") + CardContent with
`<dl className="flex items-center justify-around gap-2 flex-wrap">`. Each StatItem: icon (16px,
aria-hidden) + value (Outfit 600, 14px, `font-feature-settings: "tnum"`) + micro-label
(Manrope 400, `--text-micro`, uppercase). Skeleton during loading; null state when no data.

---

## 5. Granular task list

### PHASE 0 — Research + ADR (COMPLETE)

| Task | Status | Owner | Deliverable |
|---|---|---|---|
| T0.1 Research provider wire formats | ✅ DONE | coordinator | [GLOBAL-ALERT-SYSTEMS-RESEARCH.md](../reference/GLOBAL-ALERT-SYSTEMS-RESEARCH.md) |
| T0.2 Research national alert systems (11 countries) | ✅ DONE | coordinator | Research doc §5 |
| T0.3 Cross-mapping table | ✅ DONE | coordinator | Research doc §6 |
| T0.4 Icon gap analysis | ✅ DONE | coordinator | Research doc §11 |
| T0.5 Live API verification (Aeris) | ✅ DONE | coordinator | Research doc §10 (Paris, Tokyo, Sydney) |
| T0.6 Draft ADR-052 | ✅ DONE | coordinator | [ADR-052](../decisions/ADR-052-geography-correct-alert-model.md) |
| T0.7 Operator approval | ✅ DONE | operator | ADR-052 Accepted 2026-06-01 |

### PHASE 1 — API provider fixes (Dep: T0.7; all API-repo tasks)

**T1.1 — Update AlertRecord model**
- Owner: `clearskies-api-dev` · Dep: T0.7
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py` (line 773–816)
- Do: Remove `severity: str` (line 786). Add fields: `severityLevel: int | None = None`,
  `severityLabel: str | None = None`, `alertSystem: str | None = None`,
  `hazardType: str | None = None`, `nativeName: str | None = None`, `color: str | None = None`.
- Accept: `ruff` + `mypy` clean; model has 6 new fields, `severity` removed.
- QC: coordinator diff.

**T1.2 — Update query params**
- Owner: `clearskies-api-dev` · Dep: T1.1
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/models/params.py` (lines 370–407)
- Do: Replace `_SEVERITY_CHOICES` and `SEVERITY_ORDER` with `_MIN_LEVEL_CHOICES = {1,2,3,4}`
  and level-based ordering. Rename `severity` param to `minLevel: int | None`. Update validator.
- Accept: `ruff` + `mypy` clean; old severity param gone.
- QC: coordinator diff.

**T1.3 — Update alerts endpoint filter**
- Owner: `clearskies-api-dev` · Dep: T1.1, T1.2
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/alerts.py` (lines 169–182, 275–276)
- Do: Update `_filter_by_severity` → `_filter_by_min_level`. Filter:
  `record.severityLevel is not None and record.severityLevel >= min_level`. Records with
  `severityLevel = None` (OWM passthrough) are included when no filter specified, excluded
  when `minLevel` is specified.
- Accept: filter works with int levels; null-severity records handled correctly.
- QC: coordinator diff.

**T1.4 — Fix NWS provider**
- Owner: `clearskies-api-dev` · Dep: T1.1
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/nws.py` (lines 119–125 delete, 291–306 rewrite, 324–338 update)
- Do: Delete `_NWS_SEVERITY_MAP` (lines 119–125). Rewrite `_normalize_severity` to extract
  tier from the `event` string: check for " Warning" suffix → 4, " Watch" → 3, " Advisory" → 2,
  " Statement" → 1, unknown → 1 with WARNING log. Update `_to_canonical` (line 324) to
  populate: `severityLevel` from new function, `severityLabel` = tier name ("Warning"/etc.),
  `alertSystem = "nws"`, `hazardType = None` (NWS doesn't provide a category),
  `nativeName = None`, `color = None`.
- Accept: "Tornado Warning" → severityLevel=4, severityLabel="Warning". "Flash Flood Watch" →
  severityLevel=3, severityLabel="Watch". "Wind Advisory" → severityLevel=2, severityLabel="Advisory".
  `_NWS_SEVERITY_MAP` deleted. `ruff` + `mypy` clean.
- QC: **auditor** re-runs NWS test suite.

**T1.5 — Fix Aeris provider**
- Owner: `clearskies-api-dev` · Dep: T1.1
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/aeris.py` (lines 150, 190–206, 440–510)
- Do:
  (a) Update CAPABILITY `geographic_coverage` (line 150) to include all documented regions.
  (b) Update severity dispatch tables (lines 190–206) to return int levels: `.W`→4, `.A`→3,
  `.Y`→2, `.S`→1 for VTEC; `.EX`→4, `.SV`→3, `.MD`→2, `.MN`→1 for international.
  (c) Update `_to_canonical` (line 440) to populate new fields:
  - `severityLevel` from updated dispatch
  - `severityLabel` = build from `(dataSource, place.country, suffix)` using cross-mapping
    table (research doc §6). E.g., `dataSource="ukmet"` + `.SV` → "Amber";
    `dataSource="meteoalarm"` + `.MD` → "Yellow". For US/CA, use event name tier.
  - `alertSystem = record.dataSource` (new: capture from top-level `dataSource` field — currently not in wire model)
  - `nativeName = localLanguages[0].name` if present (new: capture from `localLanguages` array — currently not in wire model)
  - `color = details.color` (currently discarded)
  - `hazardType = details.cat` (already captured as `category`, now also → `hazardType`)
  (d) Update wire Pydantic models to capture `dataSource` (top-level) and `localLanguages`
  (array of `{language, name, body}`).
- Accept: French MeteoAlarm alert → `severityLevel=2, severityLabel="Yellow", alertSystem="meteoalarm",
  nativeName="Vigilance jaune orages", hazardType="thunderstorm"`. US fire weather watch →
  `severityLevel=3, severityLabel="Watch", alertSystem="noaa_nws"`. `ruff` + `mypy` clean.
- QC: **auditor** re-runs Aeris test suite.

**T1.6 — Fix OWM provider**
- Owner: `clearskies-api-dev` · Dep: T1.1
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/alerts/openweathermap.py` (lines 118–122, 334–381)
- Do: Delete `_SEVERITY_KEYWORD_PRIORITY` (lines 118–122) and `_owm_severity_from_event`
  (lines 275–302). Update `_owm_alert_to_canonical` to set `severityLevel = None`,
  `severityLabel = None` (passthrough). Capture `tags[0]` → `hazardType` (update wire model
  to NOT drop `tags`). Parse `sender_name` for known agency IDs → `alertSystem` (e.g.,
  "NWS" → "nws", "Met Office" → "ukmet"), else None. `nativeName = None`, `color = None`.
- Accept: OWM alert → `severityLevel=None, severityLabel=None, hazardType` from tags.
  `_SEVERITY_KEYWORD_PRIORITY` deleted. `ruff` + `mypy` clean.
- QC: **auditor** re-runs OWM test suite.

**T1.7 — Update provider tests**
- Owner: `clearskies-api-dev` · Dep: T1.4, T1.5, T1.6
- Files: `repos/weewx-clearskies-api/tests/test_providers_alerts_nws_unit.py`,
  `tests/test_providers_alerts_aeris_unit.py`, `tests/test_providers_alerts_openweathermap_unit.py`
- Do: Update all tests for new field names and values. Add test cases:
  - NWS: "Tornado Warning" → level 4; "Flash Flood Watch" → level 3; "Wind Advisory" → level 2
  - Aeris: MeteoAlarm `.MD` → level 2 + label "Yellow"; VTEC `.W` → level 4 + label "Warning";
    `dataSource` captured; `localLanguages` captured; `details.color` captured
  - OWM: severityLevel is null; tags captured as hazardType; old keyword matching removed
- Accept: **pytest output: N passed / 0 failed** for all 3 test suites.
- QC: **auditor** re-runs independently.

### PHASE 2 — Contract + dashboard types (Dep: T1.1; can run parallel with T1.4–T1.7)

**T2.1 — Update OpenAPI contract**
- Owner: `clearskies-api-dev` · Dep: T1.1
- Files: `docs/contracts/openapi-v1.yaml` (authoritative, AlertRecord at ~line 1324) +
  `repos/weewx-clearskies-dashboard/src/api/openapi-v1.yaml` (sync copy)
- Do: Update AlertRecord schema — remove `severity` enum, add `severityLevel` (integer,
  nullable, enum 1–4), `severityLabel` (string, nullable), `alertSystem` (string, nullable),
  `hazardType` (string, nullable), `nativeName` (string, nullable), `color` (string, nullable).
  Update `?severity` query param to `?minLevel` (integer, enum 1–4). Sync both copies.
- Accept: YAML valid; both copies identical.
- QC: coordinator diff.

**T2.2 — Update dashboard TypeScript types**
- Owner: `clearskies-dashboard-dev` · Dep: T2.1
- Files: `repos/weewx-clearskies-dashboard/src/api/types.ts` (lines 289–309)
- Do: Update `AlertRecord` interface — remove `severity: 'advisory' | 'watch' | 'warning'`,
  add `severityLevel: number | null`, `severityLabel: string | null`,
  `alertSystem: string | null`, `hazardType: string | null`, `nativeName: string | null`,
  `color: string | null`. Update `useAlerts` hook if it references `severity`.
- Accept: `tsc --noEmit` 0 errors.
- QC: coordinator diff.

### PHASE 3 — Dashboard alert icons (Dep: T2.2)

**T3.1 — Add 5 new Material Symbols alert icons**
- Owner: `clearskies-dashboard-dev` · Dep: T2.2
- Files: `repos/weewx-clearskies-dashboard/src/components/icons/` (new files for each inline SVG,
  same pattern as existing `flood.tsx` and `tsunami.tsx`)
- Do: Create inline SVG components for: `Earthquake` (`material-symbols:earthquake`, codepoint
  f64f), `Volcano` (`material-symbols:volcano`, ebda), `WeatherHail` (`material-symbols:weather-hail`,
  f67f), `Landslide` (`material-symbols:landslide`, ebd7), `Air` (`material-symbols:air`, efd8).
  Follow existing cross-pack pattern in `flood.tsx` / `tsunami.tsx`.
- Accept: 5 new `.tsx` files; each exports a React component with `aria-hidden="true"` + className prop.
- QC: coordinator diff.

**T3.2 — Expand alert category classifier**
- Owner: `clearskies-dashboard-dev` · Dep: T3.1
- Files: `repos/weewx-clearskies-dashboard/src/components/icons/alert-category.ts` (108 lines)
- Do: Expand `getAlertCategory()` to handle Aeris international hazard codes. The function
  currently matches NWS event name keywords. Add matching for `hazardType` field (from
  `details.cat` / OWM `tags`): `"thunderstorm"→thunderstorm`, `"fire"→fire`,
  `"earthquake"→earthquake`, `"volcano"→volcano`, `"hail"→hail`, `"avalanche"→avalanche`,
  `"dust"→dust`, etc. Map all 33 Aeris hazard codes to icon categories.
- Accept: all 33 codes map to a category; `tsc` clean.
- QC: coordinator diff.

**T3.3 — Expand AlertIcon component**
- Owner: `clearskies-dashboard-dev` · Dep: T3.1, T3.2
- Files: `repos/weewx-clearskies-dashboard/src/components/icons/alert-icon-map.tsx` (67 lines)
- Do: Add imports for 5 new icon components. Add switch cases: `'earthquake'→<Earthquake>`,
  `'volcano'→<Volcano>`, `'hail'→<WeatherHail>`, `'avalanche'→<Landslide>`, `'dust'→<Air>`.
- Accept: switch covers 18 categories (13 existing + 5 new); `tsc` clean.
- QC: coordinator diff.

### PHASE 4 — Alert card re-skin (Dep: T2.2, T3.3)

**T4.1 — Add alert glass tokens to index.css**
- Owner: `clearskies-dashboard-dev` · Dep: none
- Files: `repos/weewx-clearskies-dashboard/src/index.css`
- Do: Add `--alert-glass`, `--alert-border`, `--alert-fg` to both light and dark theme blocks
  (values from A4-card-grid.html lines 44–48, 68–72). Add `.alert-glass` utility class after
  `.card-glass` (background + border-color + backdrop-filter).
- Accept: tokens present in both themes; utility class defined.
- QC: coordinator diff.

**T4.2 — Refactor alert-banner.tsx**
- Owner: `clearskies-dashboard-dev` · Dep: T2.2, T3.3, T4.1
- Files: `repos/weewx-clearskies-dashboard/src/components/shared/alert-banner.tsx` (47 lines → rewrite)
- Do: Import `Card`, `CardContent` from `../ui/card`. Sort alerts by `severityLevel` descending
  (null last). Wrap in `<Card footprint="full" className="alert-glass ...">`. Layout: flex row
  with AlertIcon (use `hazardType` or `event` for icon lookup), event name + headline (truncated),
  "+N more" badge when multiple. ARIA: `severityLevel >= 4` → `role="alert"`, else `role="status"`.
  When `severityLevel` is null (OWM passthrough): generic `ph:warning`, `role="status"`.
  Add `useTranslation('now')` for i18n.
- Accept: Card with `footprint="full"`; no hardcoded amber classes; severity-based ARIA preserved;
  multi-alert display; `tsc` clean.
- QC: coordinator diff + T4.5 render-and-LOOK.

**T4.3 — Move AlertBanner inside Grid (now.tsx)**
- Owner: `clearskies-dashboard-dev` · Dep: T4.2
- Files: `repos/weewx-clearskies-dashboard/src/routes/now.tsx` (line 140)
- Do: Move `{!alertLoading && alerts && <AlertBanner alerts={alerts} />}` from line 140
  (outside Grid) to inside `<Grid>` as the FIRST child (before NowHeroCard). When alerts is
  empty/null, AlertBanner returns null and Grid auto-placement skips it.
- Accept: AlertBanner renders inside Grid; no gap when no alerts; grid order matches §1 diagram.
- QC: coordinator diff.

**T4.4 — Alert i18n keys**
- Owner: `clearskies-dashboard-dev` · Dep: T4.2
- Files: `repos/weewx-clearskies-dashboard/public/locales/en/now.json`
- Do: Add `"alertBanner": {"andMore": "+{{count}} more"}`. En seeded; fallback safe.
- Accept: key present; no hardcoded strings in alert-banner.tsx.
- QC: coordinator diff.

**T4.5 — Alert render-and-LOOK + axe**
- Owner: `clearskies-dashboard-dev` · Dep: T4.2, T4.3, T4.4
- Do: Build, start dev server, verify alert banner in both themes. Run `@axe-core`.
- Accept: alert renders inside grid; glass surface visible; both themes readable; axe 0 new violations.
- QC: **coordinator** inspects PNGs (not markup).

### PHASE 5 — Today's Highlights (Dep: none — fully independent of Phases 1–4)

**T5.1 — Highlights mockup**
- Owner: `clearskies-dashboard-dev` · Dep: none
- Files: `docs/design/mockups/C5-todays-highlights.html` (new)
- Do: Build HTML mockup showing Highlights strip at `wide` 2×1 inside the real A4 grid
  (`grid-4col` + `grid-auto-rows:5.5rem`). Use locked @font-face (Manrope/Outfit from
  `fonts/*.woff2`), type tokens, grid + glass tokens from A4. Show 4 core stats + 2
  conditional. Include Today's Forecast 2×1 as context card. Both themes.
- Accept: card at exactly 2×1 in grid; fonts match tokens; both themes render; minimal (no extras).
- QC: **coordinator** renders headless → Reads PNG → LOOKs.

**T5.2 — Operator mockup approval**
- Owner: coordinator · Dep: T5.1
- Do: Present rendered PNG to operator.
- Accept: **operator explicitly approves.** No T5.3+ until recorded.

**T5.3 — Extract TodaysHighlightsCard component**
- Owner: `clearskies-dashboard-dev` · Dep: T5.2
- Files: `repos/weewx-clearskies-dashboard/src/components/todays-highlights-card.tsx` (new)
- Do: Extract from `now.tsx` lines 182–246. Props: `todayStats: TodayStats | null`,
  `observation: Observation | null`, `loading?: boolean`. Structure: `<Card footprint="wide">`
  + CardHeader + CardContent with `<dl>` flex row of StatItem sub-components. Each StatItem:
  Phosphor icon (aria-hidden) + value (Outfit 600, `font-feature-settings: "tnum"`) + micro-label
  (Manrope 400, uppercase, `--text-micro`). Icons: `ThermometerHot`, `ThermometerCold`, `Wind`,
  `Drop`, `Leaf`, `Trophy` from `@phosphor-icons/react`. Preserve existing ConvertedValue
  formatting pattern (values from todayStats, unit labels from observation ConvertedValues).
  Skeleton + null states.
- Accept: `tsc` 0 errors; component renders all 6 stats; conditional stats hide correctly.
- QC: coordinator diff + T5.5.

**T5.4 — Wire into now.tsx + cleanup**
- Owner: `clearskies-dashboard-dev` · Dep: T5.3
- Files: `repos/weewx-clearskies-dashboard/src/routes/now.tsx`
- Do: Import `TodaysHighlightsCard`. Replace lines 182–246 with
  `<TodaysHighlightsCard todayStats={todayStats} observation={observation} loading={obsLoading} />`.
  Remove now-unused imports (`asConverted`, `formatValue` — verify no other consumers first).
  Grid position unchanged (paired with NowForecastCard).
- Accept: `tsc` 0 errors; `vite build` clean; inline highlights JSX removed; no dead imports.
- QC: coordinator diff.

**T5.5 — Highlights render-and-LOOK + axe**
- Owner: `clearskies-dashboard-dev` · Dep: T5.4
- Do: Build, dev server, screenshot highlights in both themes. Run `@axe-core`.
- Accept: renders match mockup; icons visible; typography matches tokens; responsive (wrap on phone);
  axe 0 new violations both themes.
- QC: **coordinator** inspects PNGs.

### PHASE 6 — Audit (Dep: all Phase 1–5)

**T6.1 — Independent audit**
- Owner: `clearskies-auditor` · Dep: all above
- Do: Review every diff against ADR-052, locked token docs, `rules/coding.md` §5 a11y +
  security baseline. Confirm: NWS bug fixed (event tier, not CAP), Aeris captures new fields,
  OWM is passthrough, 5 new icons present, alert banner inside Grid, highlights extracted.
  **Independently re-run** all test suites (API all 3 providers + dashboard tsc+build).
  Report findings via mailbox. **No implementation, no push.**
- Accept: written report; **0 unresolved high/critical**; attaches test outputs.
- QC: **coordinator** reads report, routes findings back.

### PHASE 7 — Deploy + live verify (Dep: T6.1; requires operator "push")

**T7.1 — Commit review, push, deploy, verify**
- Owner: coordinator · Dep: T6.1
- Do: Review local commits across repos; **push only when operator types "push"**; deploy to
  weather-dev; verify: `/alerts` returns new field shape; alert banner renders with correct
  treatment; highlights card renders with icons; both themes; responsive.
- Accept: **live evidence pasted** (curl `/alerts` excerpt, card screenshots both themes).

---

## 6. Dependency graph

```
PHASE 0 (research + ADR)  ✅ DONE

PHASE 1 (API provider fixes — sequential within, parallel with Phase 5):
  T1.1 (model) → { T1.2 (params), T1.4 (NWS), T1.5 (Aeris), T1.6 (OWM) } → T1.3 (endpoint) → T1.7 (tests)

PHASE 2 (contract + types — parallel with Phase 1 once T1.1 field names fixed):
  T2.1 (OpenAPI) → T2.2 (TS types)

PHASE 3 (icons — after T2.2):
  T3.1 (5 SVGs) → T3.2 (category) → T3.3 (AlertIcon)

PHASE 4 (alert card — after T2.2 + T3.3):
  T4.1 (CSS tokens, no dep) ─┐
  T4.2 (refactor banner)     ─┤→ T4.3 (wire now.tsx) → T4.4 (i18n) → T4.5 (render)
  T3.3 (icons complete)      ─┘

PHASE 5 (highlights — FULLY INDEPENDENT, start immediately):
  T5.1 (mockup) → T5.2 (approval) → T5.3 (extract) → T5.4 (wire) → T5.5 (render)

PHASE 6 (audit — after ALL above):
  T6.1

PHASE 7 (deploy — after audit, on operator "push"):
  T7.1
```

---

## 7. QC ownership

| Party | Responsibilities |
|---|---|
| **Coordinator** | Mockup render-and-LOOK, diff reviews, operator liaison, the only party who pushes. Inspects PNGs not markup. |
| **clearskies-auditor** | Independent re-run of all test suites + ADR-052/rules/a11y conformance (T6.1). |
| **Operator** | Approves highlights mockup (T5.2), authorizes push (T7.1). ADR-052 already approved. |

---

## 8. Verification bar (end-to-end "done" definition)

- **API:** `pytest` across all 3 alert provider test suites — new field shapes, NWS tier
  mapping, Aeris field capture, OWM passthrough. Full suite no regressions.
- **Dashboard:** `tsc --noEmit` 0 errors + `vite build` clean + `@axe-core` 0 new violations
  in **both** themes.
- **Render-and-LOOK:** headless screenshots of mockup AND built cards; Read each PNG:
  - Alert banner inside Grid at `full` 4×1
  - Alert glass surface visible (not hardcoded amber)
  - Highlights at `wide` 2×1 with per-stat icons
  - Typography: Outfit numerals, Manrope labels
  - Both themes readable
- **Live (weather-dev):** after deploy, `/alerts` returns `severityLevel` + `severityLabel` +
  `alertSystem` + new fields. Alert banner renders. Highlights card renders with real data.

---

## 9. Implementation reference — verified file:line

**API repo (`repos/weewx-clearskies-api/weewx_clearskies_api/`):**
- AlertRecord model: `models/responses.py:773–816` — `severity: str` at line 786
- Query params: `models/params.py:370–407` — `_SEVERITY_CHOICES` line 370, `SEVERITY_ORDER` line 375, `severity` param line 391
- Alerts endpoint: `endpoints/alerts.py:169–182` — `_filter_by_severity`, line 275–276 applies filter
- NWS provider: `providers/alerts/nws.py` — `_NWS_SEVERITY_MAP` lines 119–125, `_normalize_severity` lines 291–306, `_to_canonical` lines 314–338
- Aeris provider: `providers/alerts/aeris.py` — CAPABILITY `geographic_coverage` line 150, VTEC dispatch lines 192–197, Aeris dispatch lines 201–206, `_parse_severity_from_type` lines 387–432, `_to_canonical` lines 440–510
- OWM provider: `providers/alerts/openweathermap.py` — `_SEVERITY_KEYWORD_PRIORITY` lines 118–122, `_owm_severity_from_event` lines 275–302, `_owm_alert_to_canonical` lines 334–381
- NWS tests: `tests/test_providers_alerts_nws_unit.py`
- Aeris tests: `tests/test_providers_alerts_aeris_unit.py`
- OWM tests: `tests/test_providers_alerts_openweathermap_unit.py`

**Dashboard repo (`repos/weewx-clearskies-dashboard/src/`):**
- AlertRecord TS type: `api/types.ts:289–309` — `severity` at line 293
- Alert banner: `components/shared/alert-banner.tsx` (47 lines) — `liveProps` line 12, component line 19, primary = alerts[0] line 22
- Alert category: `components/icons/alert-category.ts` (108 lines) — `getAlertCategory` line 99
- Alert icon map: `components/icons/alert-icon-map.tsx` (67 lines) — switch line 51
- Cross-pack icons: `components/icons/flood.tsx`, `components/icons/tsunami.tsx` (pattern for new icons)
- now.tsx: `routes/now.tsx` — AlertBanner outside Grid line 140; highlights inline lines 182–246; `useAlerts` line 76; `useTodayStats` line 88
- CSS tokens: `index.css` — card-glass lines 133–135 (light), 215 (dark); no alert tokens yet
- Card primitive: `components/ui/card.tsx` — footprint type line 6, column mappings lines 23–28
- useAlerts hook: `hooks/useWeatherData.ts:202–219`
- useTodayStats hook: `hooks/useWeatherData.ts:609–664`
- TodayStats type: `api/types.ts:690–701`
- i18n keys: `public/locales/en/now.json` — `todaysHighlights` + `highlights.*` already present
- C4 tile pattern: `components/precipitation-card.tsx` (reference implementation)

**Contracts:**
- OpenAPI authoritative: `docs/contracts/openapi-v1.yaml` — AlertRecord at ~line 1324, severity enum at ~line 1330
- OpenAPI dashboard copy: `repos/weewx-clearskies-dashboard/src/api/openapi-v1.yaml`

---

## 10. Out of scope

- No changes to BFF/realtime repo (alerts pass through from API to dashboard unchanged).
- No alerts page (future, beyond the Now-page banner).
- No push notifications (ADR-016 defers to Phase 6+).
- No multi-source alert aggregation (ADR-016 defers to Phase 6+).
- No operator drag-grid engine.
- No direct national provider modules (Met Office, JMA, BoM, etc.) — future PRs per ADR-038.
- No OWM Push Weather Alerts API (opaque pricing, manual signup).
- No severity-keyed glass colors per level (amber is the single alert glass for v0.1; per-level
  colors are a future enhancement).
- No changes to C1–C4 components.

---

*Brief started 2026-06-01. Phase 0 (research + ADR-052) completed same session. Phases 1–7 ready for execution.*
