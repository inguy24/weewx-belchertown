# Operator-Configurable Charts System — Execution Plan

**Status:** COMPLETE (2026-06-05). All 5 phases done — code (Phases 1–4) and documentation (Phase 5) shipped. Visual verification items (live browser testing of `/charts`) remain deferred — they require an interactive browser session.
**Component:** Charts system overhaul. Replaces hardcoded charts with operator-configurable `charts.conf`-driven system.
**Parent roadmap:** [CLEAR-SKIES-PLAN.md](../CLEAR-SKIES-PLAN.md), [UI-REDESIGN-PLAN.md](../UI-REDESIGN-PLAN.md)

---

## 0. Orientation for a fresh session (read first)

- Project rules routing: [CLAUDE.md](../../../CLAUDE.md). **Load before acting:**
  [rules/coding.md](../../../rules/coding.md) (especially §5 WCAG, §6 Recharts discipline, §7 build verification),
  [rules/clearskies-process.md](../../../rules/clearskies-process.md),
  [rules/github.md](../../../rules/github.md).
- **Memory system is OFF** ([CLAUDE.md](../../../CLAUDE.md)); plans live in `docs/planning/`.
- **Three sub-repos** under `repos/`:
  - `weewx-clearskies-api` — FastAPI + SQLAlchemy backend. Agent: `clearskies-api-dev`.
  - `weewx-clearskies-realtime` — BFF (Python). Agent: `clearskies-realtime-dev`.
  - `weewx-clearskies-dashboard` — React 19 + Vite + Tailwind v4 + shadcn/ui + Recharts v3.8.1 SPA. Agent: `clearskies-dashboard-dev`.
- **Deploy targets:**
  - **API** runs on the **weewx** LXD container (192.168.7.20), port 8765 (HTTPS) / 8081 (internal). Deploy: `ssh ratbert "lxc exec weewx -- bash -c 'cd /home/ubuntu/repos/weewx-clearskies-api && git pull origin main && systemctl restart weewx-clearskies-api'"`. Editable install — source changes take effect on restart.
  - **Dashboard** on **weather-dev** LXD container (192.168.2.113). Source at `/home/ubuntu/repos/weewx-clearskies-dashboard`. Deploy: pull, `npm run build`, copy `dist/*` to `/var/www/clearskies/`. Caddy serves static files + proxies `/api/v1/*` → BFF at `localhost:8766`.
  - **BFF** on **weather-dev**, proxies to API at `https://weewx.shaneburkhardt.com:8765`.
- **Belchertown skin** (reference implementation): `skins/Belchertown/graphs.conf` on the weewx container at `/etc/weewx/skins/Belchertown/graphs.conf`. Also in this repo at `skins/Belchertown/graphs.conf`.
- **Redis cache on weewx:** Flush after API code changes: `ssh ratbert "lxc exec weewx -- redis-cli FLUSHDB"`.

### Git safety (ALL agents, ALL repos — non-negotiable)
Implementation agents may ONLY `git add`, `git commit` (local), `git status`, `git log`, `git diff`. **NO `git pull/push/fetch/rebase/merge/remote`, NO checkout of remote branches, NO worktree isolation.** If unexpected repo state → STOP and report. Coordinator pushes only when operator types "push."

---

## 1. Context — what exists and what's broken

### The promise
Clear Skies was to modernize Belchertown's charting system — same operator configurability, better UX (interactive Recharts, dual theme, accessible, responsive, live data).

### What Belchertown has (graphs.conf)
A ConfigObj/INI file (687 lines) where operators define chart groups, charts, and data series. Features:
- **6 chart groups:** homepage, averageclimate, monthly, ANNUAL, Tropical_Storm_Hilary, airquality
- **29 charts** with line/spline/area/column/bar/scatter types, wind rose, radial temperature range
- **Per-series control:** colors, markers, z-index, y-axis assignment, aggregation type, custom SQL queries
- **Date range selectors:** rolling ranges (1d/3d/7d/30d/90d), year/month dropdowns, epoch-based event windows
- **Climatological grouping:** `xAxis_groupby = month` with `average_type = max/min` for avg of daily highs/lows
- **Custom SQL:** `use_custom_sql = true` with `custom_sql_query` for computed metrics
- **page_content:** Markdown/HTML narrative blocks above chart groups
- **Wind rose:** 16-direction × 7-Beaufort-speed polar chart with operator-defined colors

### What Clear Skies shipped
- 4 hardcoded chart groups as Python constants in `services/charts.py` (just field name lists, no chart/series detail)
- 1144-line `charts.tsx` with 4 bespoke tab components (Homepage, Monthly, Annual, AverageClimate)
- A `/climatology/monthly` endpoint hardcoded to 4 metrics (recently fixed: rainfall was broken due to MySQL `CAST AS INTEGER` bug)
- Zero operator configuration. Zero.

### What this plan delivers
A `charts.conf`-driven system where operators define everything — chart groups, charts, series, aggregation, time ranges, colors, axes, wind roses, custom SQL — without touching code. Migration tool converts existing `graphs.conf` to `charts.conf`.

---

## 2. Governing documents

### ADRs (MUST read before coding)
| ADR | Relevance |
|-----|-----------|
| ADR-024 (Page Taxonomy) | Chart page structure, tab groups, custom groups, export |
| ADR-009 (Design Direction) | Recharts engine, LTTB sampling, chart palette |
| ADR-042 (Unit System) | Dashboard does ZERO unit math — BFF converts everything |
| ADR-048 (Theme Color Tokens) | `--chart-*` tokens for series colors |
| ADR-027 (Config/Setup Wizard) | ConfigObj/INI format, env vars for secrets, search paths |

### Binding rules
| Rule | Key constraints |
|------|----------------|
| coding.md §5 | WCAG 2.1 AA: sr-only data tables, aria-labels, contrast AA both themes |
| coding.md §6 | Recharts discipline: NO negative margins, NO `hide` on YAxis, NO `margin.bottom` for labels, cite axis props |
| coding.md §7 | Zero TS errors before deploy |
| clearskies-process.md | Opus QC on ALL work, visual inspection required, agent scope binding |

### Key file references (API repo)
| What | File | Key lines |
|------|------|-----------|
| Config settings pattern | `config/settings.py` | AlmanacSettings: 300-337, load_settings: 1150-1239 |
| Chart groups (current hardcoded) | `services/charts.py` | _BUILTIN_GROUPS: 34-77, get_chart_groups: 85-118 |
| Charts endpoint | `endpoints/charts.py` | GET /charts/groups: 31-55 |
| Climatology service | `services/climatology.py` | get_monthly_climatology: 246-296, _query_avg_rainfall: 187-220 |
| ColumnRegistry | `db/reflection.py` | ColumnRegistry: 182-207, STOCK_COLUMN_MAP: 62-167 |
| Registry DI | `db/registry.py` | wire_registry/get_registry: 14-25 |
| Response models | `models/responses.py` | ChartGroup: 725-746, utc_isoformat: 25-28 |
| Archive service | `services/archive.py` | DAY_AGGREGATOR dict, _fetch_daily, interval modes |
| Startup sequence | `__main__.py` | wire_registry at line 530, app creation |
| App router mounting | `app.py` | charts_router at line 166 |

### Key file references (Dashboard repo)
| What | File | Key lines |
|------|------|-----------|
| Charts page (REWRITE target) | `src/routes/charts.tsx` | TABS: 22-27, RANGES: 31, tabs: 903-943, keyboard nav: 877-892 |
| Data hooks | `src/hooks/useWeatherData.ts` | useArchive: 373-397, useChartGroups: 403-419, useClimatologyMonthly: 744-760 |
| API client | `src/api/client.ts` | fetchApi: 68-106, getArchive: 125-136, getChartGroups: 194-196 |
| TypeScript types | `src/api/types.ts` | ArchiveRecord: 234-245, ChartGroup: 548-559, ClimatologyMonthly: 624-631 |
| ComposedChart pattern | `src/components/almanac/MonthlyAveragesCard.tsx` | Chart: 226-311, custom dots: 104-129 |
| Card component | `src/components/ui/card.tsx` | footprint map: 23-28, CardTitle: 86-102 |
| i18n keys | `public/locales/en/charts.json` | All existing chart translation keys |

### Belchertown reference
| What | File |
|------|------|
| Operator's active chart config | `/etc/weewx/skins/Belchertown/graphs.conf` on weewx container |
| Local copy | `skins/Belchertown/graphs.conf` |
| Chart rendering engine | `bin/user/belchertown.py` |

---

## 3. Architecture

```
charts.conf (INI/ConfigObj, operator-editable)
    ↓ parsed at API startup by services/charts_config.py
ChartsConfig dataclass tree (validated, pruned against ColumnRegistry)
    ↓ served as JSON
GET /charts/config → { groups: [ { charts: [ { series: [...] } ] } ] }
    ↓ fetched by dashboard via useChartsConfig() hook
ConfigDrivenGroup + ConfigDrivenChart components
    ↓ rendered dynamically
Recharts LineChart / BarChart / ComposedChart / RadialBarChart (wind rose)
```

**Data flow unchanged:** Dashboard calls existing `/archive` (time-series) or `/climatology/monthly` (12-month averages) for chart data. The config tells the dashboard WHAT to fetch and HOW to render. Wind rose gets a new dedicated endpoint.

---

## 4. Phased task list

### PHASE 1 — Config File + Parser + API Endpoint ✅ COMPLETE (2026-06-05)

**T1.1 — Define chart config dataclasses** ✅ `f917ece`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Create: `weewx_clearskies_api/models/chart_config.py`
- NOT touch: endpoints/, services/, tests/
- Deliverable: `SeriesConfig`, `ChartConfig`, `ChartGroupConfig`, `ChartsConfig` dataclasses matching Belchertown's 3-level nesting. Every field maps 1:1 to a `graphs.conf` key. Snake_case fields; JSON serialization uses camelCase.
- Accept: `ruff` + `mypy` clean. Cross-reference every field against `graphs.conf`.

**T1.2 — Create charts.conf parser** ✅ `3d5cc77`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Create: `weewx_clearskies_api/services/charts_config.py`, `weewx_clearskies_api/data/charts.conf.default`
- Read first: `config/settings.py` lines 1111-1239, `skins/Belchertown/graphs.conf`
- NOT touch: endpoints/, models/responses.py, tests/
- Deliverable: `load_charts_config()` — finds config via search path (env var → `/etc/weewx-clearskies/charts.conf` → `~/.config/...`), parses with ConfigObj, builds dataclass tree, cascades defaults (group→chart→series), falls back to built-in defaults when no file exists. Validates types/values.
- Accept: Parses operator's actual `graphs.conf` structure. Missing file → built-in defaults. Malformed entries → warning + skip. `ruff` + `mypy` clean.

**T1.3 — Add self-hide pruning** ✅ `3c7cbc8`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Modify: `services/charts_config.py`
- Read first: `db/reflection.py` 170-237, `db/registry.py` 14-25
- Deliverable: `prune_charts_config(config, registry)` — removes series where observation_type not in ColumnRegistry, removes empty charts, removes empty groups. Same pattern as `services/charts.py` lines 96-118.
- Accept: Field not in registry → series pruned. All series pruned → chart removed. All charts pruned → group removed.

**T1.4 — Wire config + add endpoint** ✅ `48e9a0b`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Modify: `config/settings.py` (add `ChartsSettings`), `__main__.py` (load after line 530), `endpoints/charts.py` (add `GET /charts/config`), `services/charts.py` (derive from ChartsConfig), `models/responses.py` (add config response models)
- NOT touch: archive.py, climatology.py, tests/
- Accept: `GET /charts/config` returns full JSON. `GET /charts/groups` still works. No `charts.conf` → built-in defaults. API starts cleanly with and without config. `ruff` + `mypy` clean.

**T1.5 — Generalize climatology endpoint** ✅ `50d7d24`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Modify: `services/climatology.py`, `endpoints/climatology.py`
- Deliverable: Optional `fields` + `agg` query params on `/climatology/monthly`. Supports `avg_max`, `avg_min`, `avg`, `avg_monthly_total`, `sum` for any field. No params → identical to current response (backwards compat).
- Accept: `?fields=outTemp&agg=avg_max` matches current `avgHighTemp`. `?fields=rain&agg=avg_monthly_total` matches current `avgRainfall`. `ruff` + `mypy` clean.

**T1.6 — API unit tests** ✅ `504eed4`
- Owner: `clearskies-test-author` · QC: Opus coordinator
- Create: `tests/test_charts_config.py`, `tests/test_charts_config_integration.py`
- 28 test cases covering parser (valid/missing/empty/malformed/beaufort/custom-sql/timespan), pruning (series/chart/group removal, custom SQL survival, windRose), endpoints (config 200/envelope/shape/type/generatedAt/pruning, groups 200/envelope/generatedAt), climatology (no-params/months/fields+agg/missing-agg-422/missing-fields-422/invalid-agg-422/generatedAt).
- Accept: All 28 pass, 0 failures, 0.78s. SQLite in-memory fixtures.

**T1.7 — Phase 1 audit** ✅ `66c1ba4`
- Owner: `clearskies-auditor` (Sonnet) · Final QC: Opus coordinator
- Audit: 5 findings (2 medium, 3 low). All remediated in commit `66c1ba4`:
  - F1 (medium): yAxis_tickInterval case mismatch — parser now checks both casings
  - F2 (medium → fixed): Dead inner `_strip_comment` removed
  - F3 (low → fixed): `generate` field added to dataclass + parser + response + endpoint
  - F4 (low → fixed): `page_content` no longer truncated by `_strip_comment` on URL hash fragments
  - F14 (low, deferred): `_VALID_AGG_TYPES` private symbol exported — naming convention only
- Opus verification: pytest 28/0 at `66c1ba4`, real graphs.conf parsed (6 groups, 30 charts, all detail verified), ruff clean, mypy clean (0 new errors)

---

### PHASE 2 — Dashboard Dynamic Chart Renderer ✅ COMPLETE (2026-06-05)

**T2.1 — TypeScript types + hook** ✅ `b645eae`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Modify: `src/api/types.ts`, `src/api/client.ts`, `src/hooks/useWeatherData.ts`
- Create: `src/mock/chartsConfig.ts`
- Deliverable: 4 interfaces (SeriesConfig, ChartConfig, ChartGroupConfig, ChartsConfigData), `getChartsConfig()` client fn, `useChartsConfig()` hook, mock data. Also updated `getClimatologyMonthly` to accept optional `fields`/`agg` params.
- Accept: `tsc --noEmit` → 0 errors. Types match API response from T1.4.

**T2.2 — ConfigDrivenChart component** ✅ `60e8433`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Create: `src/components/charts/ConfigDrivenChart.tsx` (453 lines)
- Handles: ComposedChart for all types, per-series rendering (color/yAxis/markers/connectNulls), dual Y-axis with phantom pattern (no `hide` bug), accessibility (role="img", sr-only table, reduced-motion), Lexend font for axes, Recharts discipline compliant.
- Accept: `tsc` clean. 13-point QC checklist all PASS.

**T2.3 — ConfigDrivenGroup component** ✅ `9c9b98d`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Create: `src/components/charts/ConfigDrivenGroup.tsx` (583 lines)
- Handles: date range selectors (radiogroup), year/month dropdowns, archive/climatology data routing, seriesId-keyed data transformation, chart/table toggle, loading/error states.
- Accept: `tsc` clean. 17-point QC checklist all PASS.

**T2.4 — Rewrite charts.tsx** ✅ `349f0f4`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Modify: `src/routes/charts.tsx` (full rewrite, 1,144 → 206 lines)
- Preserved: WAI-ARIA tabs, keyboard nav (ArrowRight/Left/Home/End), tab overflow scroll + fade, `usePrefersReducedMotion`, all i18n keys.
- Deleted: TABS/RANGES constants, all hardcoded tab content components, all direct Recharts imports.
- Accept: `tsc` + `vite build` clean. 19-point QC checklist all PASS.

**T2.5 — Update i18n** ✅ `f3705ec`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Modify: `public/locales/en/charts.json`, `src/components/charts/ConfigDrivenGroup.tsx`
- Deliverable: 5 new keys (retry, tableDataCaption, tableColumnTime, tableColumnMonth, allMonths). 4 hardcoded English strings replaced with `t()` calls. All existing keys preserved.

**T2.6 — Phase 2 audit** ✅ `fa18fcd` (remediation) + `685933d` (deploy fix)
- Owner: `clearskies-auditor` (Sonnet) · Final QC: Opus coordinator
- Audit: 5 findings (0 high, 2 medium, 3 low). 4 remediated:
  - F1 (low): Dead `tickCount` prop removed
  - F2 (low): Redundant `aria-hidden="false"` removed
  - F3 (medium): Hardcoded `MONTH_LABELS` replaced with `Intl.DateTimeFormat`
  - F4 (medium): Spurious archive fetch in climatology mode fixed (added `skip` option to `useArchive`)
  - F5 (low): Pushed back — pre-existing unstaged webcam-card.tsx change, not Phase 2 scope
- Deploy fix `685933d`: 2 TypeScript errors caught by remote `tsc -b` (labelFormatter type mismatch, ClimatologyMonthly cast)
- Opus verification: `tsc --noEmit` 0 errors, `vite build` success, both repos pushed, deployed to weewx + weather-dev

**⚠️ DEFERRED: Visual testing of live charts page.** Phase 2 code is deployed but operator has not yet visually verified the rendered charts page against live API data. This must be done before Phase 2 can be considered fully validated. Specifically:
- [ ] Navigate to `/charts` on the live site and verify tabs render from config
- [ ] Verify range selector buttons work (1d/3d/7d/30d/90d)
- [ ] Verify Average Climate tab shows 12-month climatological data
- [ ] Verify chart/table toggle works
- [ ] Verify both dark and light themes render correctly
- [ ] Verify keyboard navigation on tabs (ArrowRight/Left/Home/End)
- [ ] Run axe-core scan on `/charts` page

---

### PHASE 3 — Integration + Cleanup ✅ COMPLETE (2026-06-05)

**T3.1 — Ship charts.conf.example** ✅ `fbfdb1a`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Create: `etc/charts.conf.example` (252 lines). Well-commented ConfigObj/INI with global defaults, homepage (rolling ranges), averageclimate (xAxisGroupby=month), monthly (year/month dropdowns). Based on Belchertown graphs.conf format.

**T3.2 — Deploy and verify** ✅ (done during Phase 2 closeout)
- Both repos pushed, API deployed to weewx, dashboard deployed to weather-dev, Redis flushed.

**T3.3 — Update OpenAPI contract** ✅ `c1a46bd`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Modified: `docs/contracts/openapi-v1.yaml`. Added `GET /charts/config` endpoint + 5 response schemas (SeriesConfigResponse, ChartConfigResponse, ChartGroupConfigResponse, ChartsConfigData, ChartsConfigResponse). Updated `/climatology/monthly` with `fields` + `agg` query params. Valid YAML confirmed.

**T3.4 — Delete hardcoded chart logic** ✅ `fbfdb1a` + `d2bbb0d` (test fix) + `f2bac35` (audit remediation)
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Removed `_BUILTIN_GROUPS` constant and fallback branch from `services/charts.py`. Updated docstrings in `endpoints/charts.py`. Removed dead `registry` parameter from `get_chart_groups()`. Dashboard dead code already removed in T2.4. 16 chart tests rewritten for config-driven path (all pass).

**T3.5 — Phase 3 audit** ✅ `f2bac35` (remediation)
- Owner: `clearskies-auditor` (Sonnet) · Final QC: Opus coordinator
- Audit: 3 findings (all low). 2 remediated, 1 deferred:
  - F1 (low): Dead `registry` param removed from `get_chart_groups()` — REMEDIATED
  - F2 (low): No wind rose example in charts.conf — DEFERRED to T4.1
  - F3 (low): Stale year (2025) in example — REMEDIATED (added 2026)
- Deployed to weewx, Redis flushed.

---

### PHASE 4 — Wind Rose + Custom SQL + Remaining Features ✅ CODE-COMPLETE (2026-06-05)

**T4.1 — Wind rose chart component** ✅ `00ed236` + `e60eebb`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Create: `src/components/charts/WindRoseChart.tsx`
- Custom SVG polar chart (not Recharts RadialBarChart — better accessibility and control). 16 direction bins × 7 Beaufort speed categories, sr-only table, tooltip, both themes. Data source rewired from API endpoint to client-side binning in layer correction (see T4.2 below).
- Accept: Visually matches Belchertown wind rose. Tooltip, sr-only table, both themes. **Visual comparison by Opus.**

**T4.2 — Wind rose API endpoint — REFACTORED**
- ~~Owner: `clearskies-api-dev` · QC: Opus coordinator~~
- ~~Create: `services/wind_rose.py`, `endpoints/wind_rose.py`~~
- ~~Bins windSpeed × windDir → 16×7 matrix server-side.~~
- **Status: REFACTORED — wind rose endpoint removed from API; Beaufort binning moved to dashboard per ADR-041/042 layer correction.** The API endpoint duplicated BFF work (Beaufort classification). The BFF already injects `beaufort` into every archive record. Client-side binning in `src/utils/wind-rose-binning.ts` now reads the BFF field directly. See [LAYER-CORRECTION-PLAN.md](LAYER-CORRECTION-PLAN.md).

**T4.3 — Custom SQL query support** ✅ `3ce1c0c`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Security: queries from `charts.conf` on disk (operator-controlled, same trust as Belchertown). NOT from HTTP. Pre-validated at startup (`EXPLAIN`). Read-only transaction. 10s timeout. DDL keyword blocklist.
- New endpoint: `GET /charts/custom-query/{series_id}` — executes cached query, returns `[{x, y}]`.
- Accept: Operator's actual custom SQL from `graphs.conf` works. `INSERT` rejected. Invalid SQL → skip. Timeout enforced.

**T4.4 — Weather range / radial temperature chart — COMPLETE**
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Create: `src/components/charts/WeatherRangeChart.tsx`
- Custom SVG polar chart (not Recharts — same pattern as WindRoseChart). Uses new `agg` param on `/archive` to fetch daily min + max in parallel. See [LAYER-CORRECTION-PLAN.md](LAYER-CORRECTION-PLAN.md) Phase 4.

**T4.5 — page_content support** ✅ `d5f1494`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Renders sanitized Markdown above chart groups. No script injection.

**T4.6 — PNG/CSV chart export** ✅ `61a65ab`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- PNG via Recharts `toDataURL()`. CSV from sr-only data table. Both keyboard accessible.

**T4.7 — LTTB data sampling** ✅ `0d36b6a`
- Owner: `clearskies-dashboard-dev` · QC: Opus coordinator
- Client-side LTTB for >1000 points → downsample to 500. Per ADR-009.

**T4.8 — timespan_specific support** ✅ (parser: `charts_config.py` lines 342-375; dashboard: `ConfigDrivenGroup.tsx`)
- Owner: `clearskies-api-dev` + `clearskies-dashboard-dev` · QC: Opus coordinator
- Parser reads `timespan_start`/`timespan_stop` epoch ints. Dashboard renders fixed-window group (no selectors).

**T4.9 — Belchertown graphs.conf migration tool** ✅ `0512c86`
- Owner: `clearskies-api-dev` · QC: Opus coordinator
- Create: `weewx_clearskies_api/tools/migrate_charts.py`, pyproject.toml entry point
- CLI: `clearskies-migrate-charts /path/to/graphs.conf -o /path/to/charts.conf`
- Reads ConfigObj, maps keys (most 1:1), preserves all customizations, adds `# NOTE:` comments for non-trivial translations.
- Accept: Operator's actual `graphs.conf` → valid `charts.conf` → all 6 groups, 29 charts render correctly.

**T4.10 — Phase 4 audit** ✅ `f4c06aa`
- Owner: `clearskies-auditor` (Sonnet) · Final QC: Opus coordinator
- Full audit: wind rose, custom SQL, weather range, timespan_specific, page_content, PNG/CSV, LTTB, migration tool, sr-only tables, reduced-motion, `tsc`, `ruff`/`mypy`, axe-core, keyboard nav, both themes.

> **Phase 4 note (2026-06-05):** The Phase 4 audit surfaced an architectural violation — the wind rose endpoint (T4.2) placed Beaufort classification and direction binning in the API, duplicating the BFF's existing `beaufort` injection per ADR-041/042. Corrected in [LAYER-CORRECTION-PLAN.md](LAYER-CORRECTION-PLAN.md): API endpoint deleted, computation moved to dashboard client-side binning utility. T4.4 (weather range chart) also delivered via the layer correction plan, using a new `agg` query parameter on `/archive` instead of a chart-specific endpoint.

---

### PHASE 5 — Documentation Updates (partially complete)

**T5.1 — Update ARCHITECTURE.md** ✅ COMPLETE
- Owner: Opus coordinator (direct)
- ✅ Done (layer correction): "Layer Responsibilities" section added, `/archive` `agg` param documented, wind-rose removed from endpoint table (was never there)
- ✅ Done (2026-06-05): `/charts/config` and `/charts/custom-query/{series_id}` endpoint rows added to data endpoints table. "Charts configuration" subsection added after "Configuration files" section.

**T5.2 — Write ADR for configurable charts** ✅ COMPLETE
- Owner: Opus coordinator (direct)
- Created: `docs/decisions/ADR-054-configurable-charts.md` (Proposed). Added to INDEX.md.
- Covers: ConfigObj/INI format, 3-level nesting, self-hide pruning, custom SQL security model, wind rose as client-side SVG, weather range chart, migration tool, deferred UI editor.

**T5.3 — Update CLEAR-SKIES-PLAN.md** ✅ (layer correction session)
- Track D section added referencing this plan + layer correction plan.

**T5.4 — Update UI-REDESIGN-PLAN.md** ✅ COMPLETE
- Owner: Opus coordinator (direct)
- Added "Charts page — fully rebuilt as config-driven system" paragraph in Track C section, referencing this plan.

**T5.5 — Update OpenAPI contract** ✅ COMPLETE
- Owner: Opus coordinator (direct)
- ✅ Done: `GET /charts/config` full schema (commit `c1a46bd`), `/climatology/monthly` `fields` + `agg` params (same commit), `/archive` `agg` param (commit `653c095`)
- ✅ Done (2026-06-05): `GET /charts/custom-query/{series_id}` added with `CustomQueryPoint` + `CustomQueryResponse` schemas. Wind-rose schema N/A (endpoint deleted).

**T5.6 — Update docs/INDEX.md** ✅ (layer correction session)
- Reference to this plan added.

**T5.7 — Create migration guide** ✅ COMPLETE
- Owner: Opus coordinator (direct)
- Created: `docs/procedures/MIGRATE-BELCHERTOWN-CHARTS.md`
- Covers: prerequisites, 5-step procedure, full key mapping table (30+ keys), 7 known differences/limitations.

**T5.8 — Update rules/coding.md** ✅ (UI redesign session, 2026-06-02)
- §6 (Recharts discipline) and §7 (build verification) added during the C4 stat-tile work.

---

## 5. Verification bar (definition of "done")

### Code verification (all pass)
- [x] No code changes needed to add/remove/modify chart groups, charts, or series
- [x] `/charts` page renders tabs dynamically from config
- [x] Wind rose renders with 16 direction bins × 7 Beaufort speed categories (client-side binning from BFF `beaufort` field)
- [x] Weather range / radial temperature chart renders (custom SVG, dual `agg` fetch)
- [x] page_content Markdown renders above chart groups
- [x] PNG export downloads a clean chart image
- [x] CSV export downloads chart data
- [x] LTTB sampling active for datasets >1000 points
- [x] Self-hide: groups/charts/series with missing observations are pruned
- [x] `tsc --noEmit` → 0 errors
- [x] `ruff` + `mypy` clean (0 introduced errors)
- [x] All existing chart i18n keys preserved
- [x] Migration tool exists: `clearskies-migrate-charts`

### Visual verification (deferred — needs live browser session)
- [ ] Operator can recreate their ENTIRE Belchertown `graphs.conf` in Clear Skies `charts.conf`
- [ ] Homepage tab with date-range selector works (1d through 90d)
- [ ] Average Climate tab shows 12-month climatological averages (bars + lines)
- [ ] Monthly tab with year/month dropdowns works
- [ ] Annual tab with year dropdown works
- [ ] Custom SQL queries from config execute and render correctly
- [ ] Custom operator group (e.g., "Air Quality") appears as new tab when added to config
- [ ] Tropical Storm event groups (timespan_specific) render with epoch date bounds
- [ ] Both dark and light themes render correctly
- [ ] axe-core: 0 violations on `/charts`
- [ ] Side-by-side visual comparison: every Belchertown chart has a Clear Skies equivalent

### Documentation verification
- [x] CLEAR-SKIES-PLAN.md references charts plan (Track D)
- [x] INDEX.md references this plan
- [x] rules/coding.md §6 + §7 added
- [x] OpenAPI: `/charts/config`, `/climatology/monthly` params, `/archive` `agg` param
- [x] ARCHITECTURE.md updated with charts config system + endpoint rows
- [x] ADR written (ADR-054, Proposed) for configurable charts decision
- [x] OpenAPI: `/charts/custom-query/{series_id}` schema added
- [x] UI-REDESIGN-PLAN.md charts completion noted
- [x] Migration guide published (`docs/procedures/MIGRATE-BELCHERTOWN-CHARTS.md`)
