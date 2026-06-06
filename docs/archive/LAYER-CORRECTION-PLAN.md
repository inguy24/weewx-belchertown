# API Data Flexibility + Layer Correction Plan

**Status:** ✅ COMPLETE 2026-06-05 — all phases delivered, pushed, deployed, verified live.
**Predecessor:** [CONFIGURABLE-CHARTS-PLAN.md](CONFIGURABLE-CHARTS-PLAN.md) Phase 4
**Parent roadmap:** [CLEAR-SKIES-PLAN.md](../CLEAR-SKIES-PLAN.md)

---

## 0. Orientation for a fresh session (read first)

- Project rules routing: [CLAUDE.md](../../../CLAUDE.md). **Load before acting:**
  [rules/coding.md](../../../rules/coding.md) (especially §1 security, §5 WCAG, §6 Recharts, §7 build verification),
  [rules/clearskies-process.md](../../../rules/clearskies-process.md),
  [rules/github.md](../../../rules/github.md).
- **Memory system is OFF** ([CLAUDE.md](../../../CLAUDE.md)); plans live in `docs/planning/`.
- **Three sub-repos** under `repos/`:
  - `weewx-clearskies-api` — FastAPI + SQLAlchemy backend. Agent: `clearskies-api-dev`.
  - `weewx-clearskies-realtime` — BFF (Python). Agent: `clearskies-realtime-dev`. **No code changes in this plan — BFF already does the right thing.**
  - `weewx-clearskies-dashboard` — React 19 + Vite + Tailwind v4 + shadcn/ui + Recharts v3.8.1 SPA. Agent: `clearskies-dashboard-dev`.
- **Deploy targets:**
  - **API** on **weewx** LXD container (192.168.7.20), port 8765 (HTTPS). Editable install — source changes take effect on restart.
  - **Dashboard** on **weather-dev** LXD container (192.168.2.113). Source at `/home/ubuntu/repos/weewx-clearskies-dashboard`. Deploy: pull, `npm run build`, rsync `dist/` to `/var/www/clearskies/` (EXCLUDING `webcam/` AND `webcam.json`).
  - **Use the deploy script** `scripts/redeploy-weather-dev.sh` for dashboard deploys — it protects webcam files. Do NOT manual rsync.
  - **Redis cache on weewx:** Flush after API code changes: `ssh ratbert "lxc exec weewx -- redis-cli FLUSHDB"`.

### Git safety (ALL agents, ALL repos — non-negotiable)
Implementation agents may ONLY `git add`, `git commit` (local), `git status`, `git log`, `git diff`. **NO `git pull/push/fetch/rebase/merge/remote`, NO checkout of remote branches, NO worktree isolation.** If unexpected repo state → STOP and report. Coordinator pushes only when operator types "push."

### Architecture documents (MUST read before any work)
- [docs/ARCHITECTURE.md](../../ARCHITECTURE.md) — system architecture, services, ports, endpoints, topology
- [ADR-041](../../decisions/ADR-041-realtime-bff.md) — BFF role: proxy + unit conversion + enrichment
- [ADR-042](../../decisions/ADR-042-unit-system.md) — unit system: BFF is single conversion authority, computes Beaufort + comfortIndex
- [ADR-010](../../decisions/ADR-010-canonical-data-model.md) — canonical data model: API serves generic canonical data

---

## 1. Context — what happened and what's wrong

### The layer violation

Phase 4 of the configurable charts system (June 2026) built a wind rose endpoint (`GET /api/v1/charts/wind-rose`) in the API that:
- Queries raw `windSpeed`/`windDir` from the archive
- Converts units (mph/km/h/m/s → m/s)
- Classifies each record into Beaufort categories (0-6)
- Bins by 16 compass directions × 7 Beaufort categories
- Returns a pre-computed 16×7 percentage matrix

This violates:
- **ADR-041** (line 38): "The API still passes raw archive values to the BFF — the API itself does no conversion."
- **ADR-042** (line 71): "Beaufort scale: BFF computes from wind speed (any source unit) and emits the Beaufort number + label. Dashboard does not carry Beaufort thresholds."

The BFF's `UnitTransformer.transform_record()` (in `units/transformer.py` lines 127-133) **already injects `beaufort` into every record** during unit conversion. The API endpoint duplicates this work.

### The API rigidity

The `/archive` endpoint with `interval=day` hardcodes ONE aggregation per field via `DAY_AGGREGATOR` in `services/archive.py` (lines 62-147). Examples: `outTemp → "avg"`, `windSpeed → "max"`, `rain → "sum"`.

weewx daily summary tables (`archive_day_*`) have 9 columns each: `min`, `mintime`, `max`, `maxtime`, `sum`, `count`, `wsum`, `sumtime`, `avg`. The API only reads one. The dashboard can't request daily min/max temperatures — blocking the T4.4 weather range chart.

The `/archive` endpoint's `ArchiveQueryParams` (in `models/params.py` lines 54-86) has no `agg` parameter. The `/climatology/monthly` endpoint already HAS this pattern (`?fields=outTemp&agg=avg_max`), proving the design works — it just wasn't applied to `/archive`.

### The documentation gap

The architecture docs describe WHAT each service does but don't explicitly define WHERE computation belongs. Without that boundary, every new chart feature risks placing computation in the wrong layer.

### What the BFF already does right (confirmed by code review)

| What | Where | Lines |
|------|-------|-------|
| Beaufort classification | `units/derived.py` → `beaufort()` | 17-60 |
| Comfort index | `units/derived.py` → `comfort_index()` | 63-95 |
| Per-record injection | `units/transformer.py` → `transform_record()` | 127-143 |
| Archive response conversion | `proxy.py` → `_apply_conversion()` | 493-501 (iterates records) |
| Enrichment registry | `proxy.py` → `register_enrichment()` | 276-311 |

**Every archive record that passes through the BFF already has `beaufort` and `comfortIndex` fields.** The dashboard can read these directly — no domain knowledge needed.

---

## 2. Governing documents

### ADRs (MUST read before coding)
| ADR | Relevance |
|-----|-----------|
| ADR-041 (BFF) | Layer responsibilities: API raw data → BFF transforms → dashboard renders |
| ADR-042 (Units) | BFF is single conversion authority; Beaufort + comfortIndex computed by BFF |
| ADR-010 (Data Model) | API serves canonical data generically, not chart-specifically |
| ADR-009 (Design) | LTTB sampling is client-side (dashboard) |

### Key file references (API repo)
| What | File | Key lines |
|------|------|-----------|
| DAY_AGGREGATOR (hardcoded agg per field) | `services/archive.py` | 62-147 |
| `_fetch_daily()` | `services/archive.py` | 503-573 |
| `_fetch_day_aggregates()` | `services/archive.py` | 576-630 |
| `_fetch_hourly()` | `services/archive.py` | 411-470 |
| ArchiveQueryParams | `models/params.py` | 54-86 |
| Archive endpoint | `endpoints/observations.py` | 297-370 |
| Wind rose service (TO DELETE) | `services/wind_rose.py` | 1-231 |
| Wind rose endpoint (TO DELETE) | `endpoints/wind_rose.py` | 1-253 |
| Router wiring | `app.py` | 60-190 |

### Key file references (BFF repo — READ ONLY, no changes needed)
| What | File | Key lines |
|------|------|-----------|
| Beaufort + comfortIndex injection | `units/transformer.py` | 127-143 |
| Beaufort function | `units/derived.py` | 17-60 |
| Archive response conversion (iterates records) | `proxy.py` | 493-501 |
| Enrichment registry | `proxy.py` | 276-311 |

### Key file references (Dashboard repo)
| What | File |
|------|------|
| WindRoseChart component (KEEP) | `src/components/charts/WindRoseChart.tsx` |
| ConfigDrivenGroup (MODIFY) | `src/components/charts/ConfigDrivenGroup.tsx` |
| API client (MODIFY) | `src/api/client.ts` |
| Types (KEEP) | `src/api/types.ts` |
| Hooks (MODIFY) | `src/hooks/useWeatherData.ts` |

### Documents to update (Phase 5)
| Document | Update needed |
|----------|--------------|
| `docs/ARCHITECTURE.md` | Add "Layer Responsibilities" section, remove wind-rose from endpoint table, add `agg` param |
| `docs/decisions/ADR-041-realtime-bff.md` | Add computation boundary amendment |
| `docs/contracts/openapi-v1.yaml` | Remove `/charts/wind-rose`, add `agg` param to `/archive` |
| `docs/planning/briefs/CONFIGURABLE-CHARTS-PLAN.md` | Update Phase 4 status: T4.2 refactored (layer correction), T4.4 delivered, note wind rose moved to dashboard |
| `docs/ARCHITECTURE.md` known gaps | Remove T4.4 from any tracking if present, add note about layer correction |

---

## 3. Phased task list

### PHASE 1 — Architecture Documentation (meta repo, do FIRST)

**T1.1 — Add "Layer Responsibilities" section to ARCHITECTURE.md**
- Owner: Opus coordinator (direct — doc-only, no code)
- Modify: `docs/ARCHITECTURE.md`
- NOT touch: any code repo
- Read first: `docs/decisions/ADR-041-realtime-bff.md` (lines 30-38), `docs/decisions/ADR-042-unit-system.md` (lines 70-77)
- Deliverable: New "Layer Responsibilities" section inserted after the Services table (~line 21) with the computation boundary table and the "no chart-specific endpoint in the API" rule.
- Accept: Section present, table has 3 rows (API/BFF/Dashboard), each with Responsibility and Does-NOT-do columns. Rule statement present.

**T1.2 — Amend ADR-041 with computation boundary section**
- Owner: Opus coordinator (direct — doc-only, no code)
- Modify: `docs/decisions/ADR-041-realtime-bff.md`
- NOT touch: any code repo
- Read first: `docs/decisions/ADR-042-unit-system.md` (lines 70-77 — Beaufort/comfortIndex in BFF)
- Deliverable: New "Amendment: computation boundaries (2026-06-05)" section at the end of ADR-041 codifying: API = general-purpose data access (ADR-010), no chart-type awareness; BFF = transformation (units, derived values, enrichment); Dashboard = rendering + presentation-level aggregation. No chart-specific endpoint in the API. Why: Phase 4 violation.
- Accept: Amendment section present. Cites ADR-042 line 71. References the Phase 4 wind rose incident as the motivating event.

---

### PHASE 2 — API Flexibility: `agg` parameter on `/archive` (API repo)

**T2.1 — Add `agg` param + thread through archive service**
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Read first: `weewx_clearskies_api/services/archive.py` lines 62-147 (DAY_AGGREGATOR), lines 503-630 (`_fetch_daily`, `_fetch_day_aggregates`), lines 411-470 (`_fetch_hourly`). `weewx_clearskies_api/models/params.py` lines 54-86 (ArchiveQueryParams). `weewx_clearskies_api/endpoints/observations.py` lines 297-370 (archive endpoint).
- Modify: `weewx_clearskies_api/models/params.py` (add `agg` field + validator), `weewx_clearskies_api/services/archive.py` (thread `agg` through `get_archive()` → `_fetch_daily()` → `_fetch_day_aggregates()`, and `_fetch_hourly()`), `weewx_clearskies_api/endpoints/observations.py` (pass `params.agg` to service)
- NOT touch: tests/, endpoints/charts.py, endpoints/wind_rose.py (Phase 3 handles deletion), services/wind_rose.py, services/climatology.py, services/charts_config.py, models/chart_config.py, __main__.py
- Deliverable: `GET /api/v1/archive?interval=day&fields=outTemp&agg=min` returns daily minimum outTemp values. `agg` supports `min`, `max`, `avg`, `sum`, `count`. Omitting `agg` preserves current DAY_AGGREGATOR behavior (backward compatible). Hourly interval also supports `agg` override (currently hardcodes AVG).
- Key implementation: In `_fetch_day_aggregates()` (~line 597): `agg_col = agg_override or DAY_AGGREGATOR.get(field_name)`. One-line core change; rest is parameter threading.
- Verification command: `cd repos/weewx-clearskies-api && python -m ruff check weewx_clearskies_api/services/archive.py weewx_clearskies_api/models/params.py weewx_clearskies_api/endpoints/observations.py && python -m mypy weewx_clearskies_api/services/archive.py weewx_clearskies_api/models/params.py --ignore-missing-imports`
- Accept: ruff + mypy clean. `GET /archive?interval=day&fields=outTemp&agg=min` returns daily minimums (verified on weewx container after deploy). `GET /archive?interval=day&fields=outTemp` (no agg) returns same as today. `GET /archive?interval=day&fields=outTemp&agg=invalid` returns 422.

**T2.2 — Unit tests for `agg` parameter**
- Owner: `clearskies-test-author` · QC: Opus coordinator
- Create: `tests/test_archive_agg.py`
- NOT touch: any non-test file
- Deliverable: Tests covering: valid agg values accepted (`min`, `max`, `avg`, `sum`, `count`), invalid rejected (422), `agg=None` backward compatible (returns DAY_AGGREGATOR default), `agg=min` on `interval=day` returns daily minimums, `agg=max` returns daily maximums, `agg` ignored for `interval=raw` (raw has no aggregation), `agg=min` on `interval=hour` returns hourly minimums.
- Verification command: `cd repos/weewx-clearskies-api && python -m pytest tests/test_archive_agg.py -v`
- Accept: All tests pass. SQLite in-memory fixtures.

**T2.3 — Phase 2 audit**
- Owner: `clearskies-auditor` (Sonnet) · Final QC: Opus coordinator
- Audit scope: `models/params.py` changes, `services/archive.py` changes, `endpoints/observations.py` changes
- Audit against: coding.md §1 (Pydantic extra="forbid" still enforced after adding field), ADR-012 (read-only), backward compatibility
- Accept: 0 high findings. Medium/low remediated or deferred with justification.

---

### PHASE 3 — Layer Correction: Wind Rose (API repo + Dashboard repo, parallel)

**T3.1 — Remove wind rose endpoint from API**
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- DELETE: `weewx_clearskies_api/services/wind_rose.py` (231 lines), `weewx_clearskies_api/endpoints/wind_rose.py` (253 lines)
- Modify: `weewx_clearskies_api/app.py` — remove `wind_rose_router` import (line 62) and `include_router` call (line 186)
- NOT touch: services/archive.py, services/custom_query.py, endpoints/observations.py, endpoints/custom_query.py, tests/, __main__.py
- Verification command: `cd repos/weewx-clearskies-api && python -m ruff check weewx_clearskies_api/app.py && python -c "from weewx_clearskies_api.app import create_app; print('import OK')"`
- Accept: `wind_rose.py` files deleted. `app.py` has no wind_rose references. ruff clean. API starts without error. `GET /charts/wind-rose` returns 404.

**T3.2 — Client-side wind rose binning + ConfigDrivenGroup rewire**
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Read first: `src/components/charts/ConfigDrivenGroup.tsx` (wind rose detection ~line 192, `useWindRose` call ~line 291, rendering ~line 617-640). `src/components/charts/WindRoseChart.tsx` (props interface — `data: WindRoseData`). `src/api/types.ts` (`WindRoseData`, `BeaufortCategory` interfaces ~line 565). `src/hooks/useWeatherData.ts` (`useWindRose` ~line 1017-1063). `src/api/client.ts` (`getWindRose` at end of file).
- Create: `src/utils/wind-rose-binning.ts`
  - Export `buildWindRoseMatrix(records: Record<string, unknown>[]): WindRoseData`
  - Takes archive records (with `beaufort` field from BFF — a `{value, label, formatted}` object), bins by direction × beaufort
  - Direction binning: `Math.floor((windDir + 11.25) % 360 / 22.5)` → 16 bins (same formula as the deleted API code)
  - Beaufort binning: read `beaufort.value` (number 0-12), cap at 6+ for 7-category display
  - Returns `WindRoseData` (same shape `WindRoseChart` already expects: `directions`, `categories`, `bins`, `totalRecords`, `calmPercentage`)
  - Handle null windSpeed/windDir/beaufort → skip record
  - Default Beaufort colors: same as `services/wind_rose.py` constants (match Belchertown defaults)
- Modify: `src/components/charts/ConfigDrivenGroup.tsx`
  - Remove `useWindRose()` import and hook call
  - Import `buildWindRoseMatrix` from `../../utils/wind-rose-binning`
  - For wind rose charts: `const windRoseData = useMemo(() => buildWindRoseMatrix(archiveData), [archiveData])`
  - Pass `windRoseData` to existing `WindRoseChart` component
- Modify: `src/api/client.ts` — remove `getWindRose()` function, `WindRoseParams` interface, `WindRoseData` import
- Modify: `src/hooks/useWeatherData.ts` — remove entire `useWindRose()` function and its imports
- KEEP: `src/api/types.ts` — `WindRoseData` and `BeaufortCategory` stay (consumed by chart component + binning utility)
- KEEP: `src/components/charts/WindRoseChart.tsx` — no changes (same data shape, different source)
- NOT touch: `src/routes/charts.tsx`, `src/utils/lttb.ts`, `src/utils/chart-export.ts`, `package.json`, `public/locales/*`
- Verification command: `cd repos/weewx-clearskies-dashboard && npx tsc --noEmit`
- Accept: `tsc --noEmit` 0 errors. Wind rose chart renders on `/charts` page using archive data + client-side binning (same visual result as before). No `getWindRose` or `useWindRose` in the codebase (grep verification). `WindRoseChart.tsx` unchanged.

**T3.3 — Phase 3 audit**
- Owner: `clearskies-auditor` (Sonnet) · Final QC: Opus coordinator
- Audit scope: `wind-rose-binning.ts` (logic correctness, null handling), `ConfigDrivenGroup.tsx` changes (data flow, no regressions), deleted files confirmed gone
- Audit against: coding.md §5 (WCAG — sr-only table still works), §7 (tsc clean), ADR-042 (no domain thresholds in dashboard — beaufort comes from BFF)
- Accept: 0 high findings. Wind rose binning reads `beaufort` from records, does NOT compute Beaufort itself.

---

### PHASE 4 — Weather Range Chart (T4.4, Dashboard repo)

**T4.1 — Add `agg` to dashboard ArchiveParams**
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Modify: `src/api/client.ts` — add `agg?: string` to `ArchiveParams` interface, pass through in `getArchive()`
- NOT touch: any other file
- Verification command: `npx tsc --noEmit`
- Accept: `tsc` clean. `getArchive({interval: 'day', fields: 'outTemp', agg: 'min'})` compiles.

**T4.2 — WeatherRangeChart component + integration**
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Read first: `src/components/charts/WindRoseChart.tsx` (reference for custom SVG polar chart pattern, ~624 lines — sr-only table, SVG arc drawing, tooltip, theme variables). `skins/Belchertown/graphs.conf` lines 291-294 and 459-463 (operator's `[[radialChartName]]` with `range_type = outTemp`). `src/components/charts/ConfigDrivenGroup.tsx` (data fetching flow, chart rendering loop).
- Create: `src/components/charts/WeatherRangeChart.tsx`
  - Custom SVG polar chart showing temperature ranges radially
  - For "Temperature Ranges for Month": 28-31 positions around circle (days), each with a range bar from daily min to max
  - For "Temperature Ranges for Year": 12 positions (months), each with a range bar
  - Props: `highData: Record<string, number>[]`, `lowData: Record<string, number>[]`, `labels: string[]`, `height?: number`, `reducedMotion?: boolean`
  - WCAG: `role="img"`, `aria-labelledby`, sr-only data table, keyboard-accessible segments (same pattern as WindRoseChart)
  - Both themes: use CSS variables (`var(--border)`, `var(--foreground)`, `var(--muted-foreground)`)
- Modify: `src/components/charts/ConfigDrivenGroup.tsx`
  - Detect `range_type` series: `chart.series.some(s => s.rangeType != null)`
  - For range charts: fetch two archive requests (agg=max + agg=min) using `useArchive` with different agg params
  - Combine and pass to WeatherRangeChart
- NOT touch: WindRoseChart.tsx, ConfigDrivenChart.tsx, charts.tsx, src/routes/*, package.json
- Verification command: `npx tsc --noEmit`
- Accept: `tsc` clean. Radial temperature chart renders for operator's monthly and annual groups. sr-only table present. Both themes work.

**T4.3 — Phase 4 audit**
- Owner: `clearskies-auditor` (Sonnet) · Final QC: Opus coordinator
- Audit scope: `WeatherRangeChart.tsx` (WCAG, keyboard nav, sr-only table), ConfigDrivenGroup changes (dual-fetch logic, no regressions)
- Audit against: coding.md §5 (WCAG 2.1 AA), §6 (Recharts discipline — N/A for custom SVG but check principles), §7 (tsc clean)
- Accept: 0 high findings.

---

### PHASE 5 — Document Cleanup + Deployment

**T5.1 — Update OpenAPI contract**
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Modify: `docs/contracts/openapi-v1.yaml`
- Changes: Remove `/charts/wind-rose` endpoint and its response schemas (`WindRoseData`, `BeaufortCategory`, `WindRoseResponse`). Add `agg` query parameter to `/archive` endpoint (type: string, enum: [min, max, avg, sum, count], required: false).
- NOT touch: any code file
- Accept: Valid YAML. No references to `wind-rose`. `agg` parameter present on `/archive`.

**T5.2 — Update ARCHITECTURE.md endpoint table + known gaps**
- Owner: Opus coordinator (direct)
- Modify: `docs/ARCHITECTURE.md`
- Changes: Remove `/api/v1/charts/wind-rose` row from API endpoints table. Add `agg` note to `/api/v1/archive` description. Verify "Layer Responsibilities" section from T1.1 is present. Remove T4.4 from known gaps if tracked there.
- Accept: No `wind-rose` in endpoint table. `agg` documented. Layer section present.

**T5.3 — Update CONFIGURABLE-CHARTS-PLAN.md**
- Owner: Opus coordinator (direct)
- Modify: `docs/planning/briefs/CONFIGURABLE-CHARTS-PLAN.md`
- Changes:
  - T4.2: "REFACTORED — wind rose endpoint removed from API; computation moved to dashboard per ADR-041/042 layer correction (see LAYER-CORRECTION-PLAN.md)"
  - T4.4: "COMPLETE" with commit hashes
  - Phase 4 note: "Phase 4 audit surfaced an architectural violation — wind rose Beaufort binning was in the API, duplicating BFF work. Corrected in LAYER-CORRECTION-PLAN.md."
  - Remove T4.4 from deferred items

**T5.4 — Update CLEAR-SKIES-PLAN.md**
- Owner: Opus coordinator (direct)
- Modify: `docs/planning/CLEAR-SKIES-PLAN.md`
- Changes: Reference this plan under charts component. Note layer correction.

**T5.5 — Update docs/INDEX.md**
- Owner: Opus coordinator (direct)
- Modify: `docs/INDEX.md`
- Changes: Add reference to LAYER-CORRECTION-PLAN.md

**T5.6 — Clean up scratchpad**
- DELETE: `c:\tmp\phase4-scratch.md` (ephemeral, replaced by this plan's status tracking)

**T5.7 — Push, deploy, verify**
- Owner: Opus coordinator
- Push both repos (API + dashboard). Coordinator only, after all code verified.
- Deploy API: `ssh ratbert "lxc exec weewx -- bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && git pull origin main && sudo systemctl restart weewx-clearskies-api'"`
- Flush Redis: `ssh ratbert "lxc exec weewx -- redis-cli FLUSHDB"`
- Deploy dashboard: `scripts/redeploy-weather-dev.sh` (**NOT manual rsync** — script protects `webcam/` and `webcam.json`)
- Verify on live:
  - `curl -sk https://localhost:8765/health` → `{"status":"ok"}`
  - `curl -sk 'https://localhost:8765/api/v1/charts/wind-rose'` → 404
  - `curl -sk 'https://localhost:8765/api/v1/archive?interval=day&fields=outTemp&agg=min&limit=5'` → daily minimums
  - `curl -sk 'https://localhost:8765/api/v1/archive?interval=day&fields=outTemp&limit=5'` → daily avg (backward compat)
  - Navigate to `/charts` on live site → wind rose renders, weather range renders

---

## 4. Sequencing

```
Phase 1 (docs)  ──────> locks rules before code changes
Phase 2 (agg)   ──────> API flexibility (API repo)
Phase 3 (wind rose) ──> can parallel with Phase 2 on different repos
                         Phase 3 API deletion on API repo (after Phase 2 commits)
                         Phase 3 dashboard rewrite on Dashboard repo (parallel with Phase 2)
Phase 4 (T4.4)  ──────> depends on Phase 2 (needs agg param) + Phase 3 dashboard (same repo)
Phase 5 (cleanup) ────> after all code lands
```

---

## 5. Verification bar

- [x] `ARCHITECTURE.md` has "Layer Responsibilities" section defining API/BFF/Dashboard boundaries
- [x] ADR-041 has computation boundary amendment
- [x] `GET /archive?interval=day&fields=outTemp&agg=min` → daily minimum temperatures (verified: 61.88°F)
- [x] `GET /archive?interval=day&fields=outTemp&agg=max` → daily maximum temperatures
- [x] `GET /archive?interval=day&fields=outTemp` (no agg) → daily avg (backward compatible)
- [x] `GET /charts/wind-rose` → 404 (endpoint removed — verified live)
- [x] Wind rose chart on `/charts` page renders identically (using archive data + client-side binning)
- [x] Weather range chart renders for operator's monthly + annual groups
- [x] OpenAPI contract updated (wind-rose schemas never existed; agg param added — commit `653c095`)
- [x] CONFIGURABLE-CHARTS-PLAN.md updated with layer correction notes
- [x] `tsc --noEmit` → 0 errors (dashboard)
- [x] `ruff` + `mypy` clean (API — 0 introduced errors across all commits)
- [x] BFF repo: ZERO code changes (confirms correct architecture)

### Deferred items (tracked in UI-REDESIGN-PLAN.md LC-1 through LC-5)

- LC-1 [MEDIUM]: WeatherRangeChart gradient colors hardcoded hex → CSS variables
- LC-2 [MEDIUM]: Range chart table/CSV export shows raw data instead of aggregated high/low
- LC-3 [LOW]: `agg` missing from `useArchive` deps array (latent)
- LC-4 [LOW]: No unit tests for `wind-rose-binning.ts`
- LC-5 [LOW]: Wasteful main archive fetch for range chart groups (couples with LC-2)
- [ ] BFF repo: ZERO code changes (confirms correct architecture)
