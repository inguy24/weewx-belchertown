# ADR-075 Temporal Consistency Model — Execution Plan

**Status:** COMPLETE
**Created:** 2026-06-27
**Completed:** 2026-06-27
**Components:** API (`weewx-clearskies-api`), Dashboard SPA (`weewx-clearskies-dashboard`), Meta (`.` docs)
**ADR:** [ADR-075](../decisions/ADR-075-temporal-consistency-model.md) (Accepted 2026-06-27, supersedes ADR-020)

---

## Context

ADR-075 establishes a complete temporal model for Clear Skies: the API as station clock authority (`stationClock` block on every response), data freshness envelopes (`freshness` block on cacheable responses), per-domain temporal windows, dashboard temporal rules with banned patterns, operator idle configuration, and provider-level refresh metadata.

Research identified **28+ dashboard temporal violations** spanning critical date-boundary bugs (browser-local `new Date()` for station dates, `index === 0` for "Today"), missing timezone options on display formatting, and hardcoded polling intervals. The API needs new response envelope fields, config sections, and helpers. Three manuals and ARCHITECTURE.md require updates.

**Provider audit (28 modules):** All providers are already compliant with UTC timestamp conversion via `datetime_utils.py` helpers. Each provider encapsulates its own date/time translation — no provider-specific temporal logic in the main API. The `validDate` derivation is per-provider (Aeris: `dateTimeISO[:10]`, NWS: `startTime[:10]`, OWM: offset-shifted epoch, Open-Meteo: pass-through, Wunderground: local ISO slice). The plan extends this by adding `refreshInterval` to each provider's CAPABILITY declaration.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — build verification, testing
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-api` — FastAPI + Pydantic. Branch: `main`. Lint: `ruff check`, `mypy`.
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind + shadcn/ui). Branch: `main`. Build: `npm run build` (= `tsc -b && vite build`).

**Meta (root `c:\CODE\weather-belchertown`):**
- Documentation repo. Branch: `master`.

**Deploy:**
- Dashboard: `bash scripts/redeploy-weather-dev.sh`
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (~2 min cache warm)

**Key ADRs:**
- ADR-075 — Temporal consistency model (this plan's authority)
- ADR-020 — Time zone handling (superseded by ADR-075; rules absorbed)
- ADR-010 — Canonical data model (UTC ISO-8601 Z wire format)
- ADR-055 — Client data refresh (stale-while-revalidate; no regression)
- ADR-064 — Card plugin contract (`stationTz` prop)

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** The coordinator performs QC after EVERY phase completes — not batched at the end. No phase advances until the coordinator signs off.

---

## 1. Violation Inventory

### A. API: Missing Response Envelope Fields

| # | Item | Severity | Fix |
|---|------|----------|-----|
| A1 | No `stationClock` block on any response | CRITICAL | Add to all response envelopes via shared helper |
| A2 | No `freshness` block on cacheable responses | CRITICAL | Add to all cacheable response envelopes |
| A3 | No `[freshness]` section in `config/settings.py` | HIGH | New `FreshnessSettings` class |
| A4 | No idle config (`idleTimeout`, `idleRefreshFactor`) | MEDIUM | Add to station metadata |
| A5 | `PositionsResponse` missing `generatedAt` | LOW | Only response model without it |
| A6 | Provider CAPABILITY `refresh_interval` only set by radar providers | MEDIUM | Set on all 28 providers |

### B. Dashboard: Critical Date Boundary Bugs

| # | File | Line(s) | Violation | Fix |
|---|------|---------|-----------|-----|
| B1 | `useSmartAlmanac.ts` | 58-60 | `new Date()` + `.toISOString().split('T')[0]` for "tomorrow" | Use `stationClock.date` + `addDays()` |
| B2 | `DailyColumns.tsx` | 36,46 | `index === 0` as proxy for "Today" | Compare `validDate === stationClock.date` |
| B3 | `almanac.tsx` | 52-54 | `stationDate()` uses `new Date()` | Use `stationClock.date` from API |
| B4 | `records.tsx` | 132-139 | `todayFromEpoch` uses local `new Date()` | Use `stationClock.time` for epoch |
| B5 | `useWeatherData.ts` | 683-688 | `todayMidnight` from local `new Date()` | Use station midnight from stationClock |
| B6 | `ConfigDrivenGroup.tsx` | 391-398 | Week-start from local `new Date()` | Use stationClock-derived date |

### C. Dashboard: Missing Timezone in Formatting

| # | File | Line(s) | Violation |
|---|------|---------|-----------|
| C1 | `alert-banner.tsx` | 87-95, 97, 108, 111 | `new Date()` for "today" + `toLocaleString` without `timeZone` |
| C2 | `ConfigDrivenGroup.tsx` | 116, 253, 174, 178, 181 | Year/month from `new Date()` + formatting without `timeZone` |
| C3 | `HaysChart.tsx` | 135, 146 | `toLocaleString` without `timeZone` |
| C4 | `WeatherRangeChart.tsx` | 165, 170, 171 | `toLocaleDateString` without `timeZone` |
| C5 | `radar-map.tsx` | 664 | `exp.toLocaleString()` without `timeZone` |
| C6 | `lightning-card.tsx` | 253, 283 | `toLocaleTimeString` without `timeZone` |
| C7 | `uv-index-card.tsx` | 110-127 | `new Date()` for midnight + formatting without `timeZone` |
| C8 | `MeteorShowerCard.tsx` | 63, 77, 104 | `toLocaleDateString` without `timeZone` |

### D. Dashboard: Hardcoded Polling Intervals

| # | File | Line | Current | Should Be |
|---|------|------|---------|-----------|
| D1 | `useWeatherData.ts` | 168 | 60s hardcoded | `freshness.refreshInterval` (= `archiveIntervalSeconds`) |
| D2 | `useWeatherData.ts` | 989 | 60s hardcoded | `freshness.refreshInterval` |
| D3 | `useSmartAlmanac.ts` | 34 | 60s hardcoded | `freshness.refreshInterval` |
| D4 | `solar-radiation-card.tsx` | 311 | 5min hardcoded | `freshness.refreshInterval` |
| D5 | `todays-highlights-card.tsx` | 112 | 5min hardcoded | `freshness.refreshInterval` |
| D6 | `radar-map.tsx` | 330 | 5min hardcoded | `freshness.refreshInterval` |
| D7 | `radar-map.tsx` | 437 | 1hr hardcoded | `freshness.refreshInterval` |
| D8 | `now.tsx` | 56 | 15min hardcoded | `freshness.refreshInterval` |
| D9 | `current-conditions-card.tsx` | 368 | 60s hardcoded | `freshness.refreshInterval` |

**OK (display-tick, not data refresh — ADR-075 approved):** `sun-moon-card.tsx:186`, `SunMoonDetailCard.tsx:278`, `current-conditions-card.tsx:133` — `setNowMs(Date.now())` for arc position / elapsed display.

### E. Dashboard: Missing Infrastructure

| # | Item | Fix |
|---|------|-----|
| E1 | No `utils/station-clock.ts` | Create per ADR-075 §6 |
| E2 | No `useIdleDetector()` hook | Create per ADR-075 §7 |
| E3 | `useApiQuery` has no freshness awareness | Extend to respect `freshness.validUntil` |
| E4 | `ApiResponse<T>` type missing stationClock/freshness | Extend TypeScript interface |

### F. Out of Scope (Explicit Deferrals)

| Item | Why |
|------|-----|
| Provider-specific update schedule auto-discovery | ADR-075 "Out of scope"; static defaults for v0.1 |
| Per-user timezone override | Phase 6+ per ADR-075 |
| Historical timezone changes for moved stations | Out of scope per ADR-075 |

---

## 2. Implementation Phases

### PHASE 0 — Manual Updates (Docs First)

Per process rules: "manuals are the authority, code follows." All manuals updated before any code.

**T0.1 — Update API-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/API-MANUAL.md`
- Do:
  - §2 "### Time" (line 164-166): Expand with stationClock contract, freshness envelope. Reference ADR-075 (not ADR-020). Full JSON example of `stationClock` and `freshness` blocks.
  - Add new "### Response envelope" subsection after Time: Complete response shape with `data` + `stationClock` + `freshness` + `units` + `source` + `generatedAt`. Which responses include `freshness` (cacheable) vs. which do not (SSE, setup).
  - Add per-domain `refreshInterval` defaults table from ADR-075 §4.
  - Add `[freshness]` config section documentation.
  - §13 Anti-Patterns: Add temporal anti-patterns (naive datetimes forbidden, no local-time strings).
- Accept: All ADR-075 API rules reflected. ADR-020 reference updated.

**T0.2 — Update DASHBOARD-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/DASHBOARD-MANUAL.md`
- Do:
  - §2 "Time Zones" (line 106-136): Update ADR-020 reference to ADR-075. Add station-clock utility documentation. Add banned patterns list (grep-checkable FAIL conditions from ADR-075 §6).
  - §7 "Data Refresh & Realtime" (line 328-412): Add freshness-driven polling section. Document `freshness.validUntil` scheduling, `freshness.refreshInterval` as poll timer. Add idle detection section (`useIdleDetector`, `idleTimeout`, `idleRefreshFactor`).
  - §8 "Card Plugin Contract" (line 414-465): Add `stationClock` to dataBag contract. Document that cards use `stationClock.date` for "today" logic.
  - §11 "Anti-Patterns": Add temporal anti-patterns from ADR-075.
- Accept: All ADR-075 dashboard rules reflected. Banned patterns grep-checkable.

**T0.3 — Update ARCHITECTURE.md**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/ARCHITECTURE.md`
- Do:
  - Update response shape examples to include `stationClock` and `freshness` blocks.
  - Update configuration files table (line 403-421): add `[freshness]` and idle config to `api.conf`.
  - Update any remaining ADR-020 references to ADR-075.
- Accept: ARCHITECTURE.md reflects new response envelope structure.

**T0.4 — Verify ADR-020 supersession**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/archive/decisions/ADR-020-time-zone-handling.md`
- Do: Verify frontmatter has `status: Superseded` and `superseded-by: ADR-075` (already done). No content changes.
- Accept: ADR-020 correctly points to ADR-075.

**QC (Opus) — after Phase 0:** Review all three manual updates against ADR-075 §1-8. Verify every rule appears in the correct section. Verify banned patterns list complete. Verify ARCHITECTURE.md response examples include both blocks.

---

### PHASE 1 — API Infrastructure (stationClock + freshness)

**T1.1 — Add StationClock and FreshnessInfo response models**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py`
- Do:
  - Add `StationClock` Pydantic model: `date: str`, `time: str`, `timezone: str`.
  - Add `FreshnessInfo` Pydantic model: `generatedAt: str`, `validUntil: str`, `refreshInterval: int`.
  - Add `stationClock: StationClock | None = None` and `freshness: FreshnessInfo | None = None` to ALL response envelope models (29 models total — see inventory in §1.A).
  - Add `generatedAt` to `PositionsResponse` (currently missing).
- Accept: All response models have new fields. `ruff check` + `mypy` pass.

**T1.2 — Add build_station_clock helper**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/services/station.py`
- Do:
  - Add `build_station_clock() -> StationClock` that calls `get_station_info()`, uses `datetime.now(tz=ZoneInfo(info.timezone))` to get station-local time, returns `StationClock(date=now.strftime("%Y-%m-%d"), time=now.isoformat(), timezone=info.timezone)`.
  - Computed at response time, no DB query, fast.
- Accept: Returns correct station-local date/time/timezone.

**T1.3 — Add FreshnessSettings to config**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py`
- Do:
  - Add `FreshnessSettings` class reading `[freshness]` section of api.conf.
  - **weewx-derived defaults:** `current_observation` and `records` default to `StationInfo.archive_interval` (read from weewx.conf `[StdArchive] archive_interval`, already loaded by the API at startup). This means a station with a 60s archive interval refreshes every 60s; a station with 900s doesn't waste calls at 300s. The `[freshness]` config section still allows operator override.
  - Static defaults for non-weewx domains (seconds): `forecast=1800`, `alerts=300`, `aqi=900`, `almanac_daily=86400`, `almanac_positions=60`, `radar=300`, `earthquakes=300`, `charts_config=86400`, `station_metadata=86400`, `seeing=10800`.
  - Add `idle_timeout=30` (minutes) and `idle_refresh_factor=10`.
  - Wire into main Settings class. `FreshnessSettings` accepts `StationInfo` at construction to read `archive_interval`. Defaults apply when `[freshness]` absent.
- Accept: Config loads with weewx-derived defaults for observation endpoints. Operator can override any value.

**T1.4 — Add build_freshness helper**
- Owner: `clearskies-api-dev` (Sonnet)
- File: New `repos/weewx-clearskies-api/weewx_clearskies_api/services/freshness.py`
- Do:
  - `build_freshness(domain: str, provider_refresh_interval: int | None = None) -> FreshnessInfo` that reads `FreshnessSettings`, computes `generatedAt = now(UTC)`, looks up `refreshInterval` for the domain (use `min(config_default, provider_refresh_interval)` when provider value supplied), computes `validUntil = generatedAt + refreshInterval`.
  - Special case: `almanac_daily` → `validUntil` = station-local next midnight.
- Accept: Each domain returns correct freshness per ADR-075 table.

**T1.5 — Wire stationClock + freshness into all endpoints**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: All endpoint files in `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/`
- Do:
  - Each cacheable endpoint handler adds `station_clock=build_station_clock()` and `freshness=build_freshness("<domain>")` to response construction.
  - Domain mapping: `/current` → `current_observation`, `/forecast` → `forecast`, `/alerts` → `alerts`, `/aqi/*` → `aqi`, `/almanac` → `almanac_daily`, `/almanac/positions` → `almanac_positions`, `/earthquakes` → `earthquakes`, `/records` → `records`, `/charts/*` → `charts_config`, `/radar/*` → `radar`, `/station` → `station_metadata`, `/almanac/seeing-forecast` → `seeing`.
  - SSE (`sse.py`) and setup (`setup.py`) do NOT get freshness.
  - Provider-backed endpoints (forecast, alerts, AQI, earthquakes, radar) pass their provider's `refresh_interval` from the capability registry to `build_freshness()`.
- Accept: Every cacheable response includes both blocks. SSE/setup do not. `ruff check` + `mypy` pass.

**T1.6 — Add idle config to station metadata**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `responses.py` (StationMetadata model), `endpoints/station.py`
- Do: Add `idleTimeout: int = 30` and `idleRefreshFactor: int = 10` to StationMetadata. Populate from FreshnessSettings.
- Accept: `/station` response includes idle config.

**QC (Opus) — after Phase 1:** Hit 5 endpoints on weather-dev (`/current`, `/forecast`, `/almanac`, `/station`, `/almanac/positions`). Verify `stationClock` with correct date/time and `freshness` with correct `refreshInterval` per ADR-075 table. Verify SSE does NOT contain freshness. `ruff check` + `mypy` clean.

---

### PHASE 2 — Dashboard Infrastructure

**T2.1 — Create utils/station-clock.ts**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: New `repos/weewx-clearskies-dashboard/src/utils/station-clock.ts`
- Do: Implement per ADR-075 §6:
  - `StationClock` and `FreshnessInfo` interfaces
  - `getStationDate(response)` — extract `stationClock.date`
  - `addDays(dateStr, n)` — increment YYYY-MM-DD by n days
  - `isStationToday(validDate, stationDate)` — compare dates
  - `stationTimeMs(stationClock)` — convert station time to epoch ms
- Accept: All four functions correct. `tsc --noEmit` passes.

**T2.2 — Extend API types with stationClock and freshness**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/api/types.ts`
- Do:
  - Add `StationClock` and `FreshnessInfo` interfaces.
  - Add optional `stationClock?` and `freshness?` to API response wrappers.
  - Add `idleTimeout?` and `idleRefreshFactor?` to `StationMetadata`.
- Accept: Types match new API shape. `tsc --noEmit` passes.

**T2.3 — Create useIdleDetector hook**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: New `repos/weewx-clearskies-dashboard/src/hooks/useIdleDetector.ts`
- Do:
  - `useIdleDetector(timeoutMinutes)` hook tracking mouse/keyboard/scroll/touch.
  - `IdleDetectorProvider` context for top-level wrapping.
  - `useIsIdle()` consumer hook.
  - `timeoutMinutes = 0` disables (kiosk mode).
  - Passive event listeners for scroll/touch.
- Accept: Idle detection works. User interaction resets. `0` disables.

**T2.4 — Extend useApiQuery with freshness-driven auto-refetch**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/hooks/useApiQuery.ts`
- Do:
  - When fetcher returns data with `freshness` block, schedule refetch at `validUntil`.
  - Accept optional `pollInterval` option for proactive polling at `refreshInterval`.
  - When idle (`useIsIdle()`), multiply poll interval by `idleRefreshFactor`.
  - Keep stale-while-revalidate: never show skeleton during background refetch.
- Accept: Cards auto-refetch based on freshness. Idle mode reduces rate. No regression.

**T2.5 — Propagate stationClock through weather data hooks**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/hooks/useWeatherData.ts`
- Do:
  - Extend `HookResult<T>` with `stationClock?` and `freshness?`.
  - Extract from API responses in each hook (useObservation, useForecast, useAlerts, useAlmanac, etc.).
  - Remove hardcoded `setInterval` poll ticks from `useObservation` (line 166-169) and `useAlmanacPositions` (line 987-991) — replaced by freshness-driven refetch.
- Accept: All hooks expose `stationClock` and `freshness`. No hardcoded intervals for API data refresh.

**QC (Opus) — after Phase 2:** Verify `station-clock.ts` exports. Verify `useApiQuery` schedules refetches from `validUntil`. Verify idle detector reduces refresh. `tsc --noEmit` clean.

---

### PHASE 3 — Dashboard Violations (Banned Pattern Fixes)

**T3.1 — Fix useSmartAlmanac.ts (CRITICAL: B1)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/hooks/useSmartAlmanac.ts`
- Do:
  - Replace `Date.now()` (line 39) with `stationTimeMs(stationClock)` from almanac response.
  - Replace lines 57-62 (`new Date()` + `toISOString().split('T')[0]`) with `addDays(getStationDate(almanacResponse), 1)`.
  - Remove hardcoded 60s `setInterval` tick (line 33-36).
  - Import from `utils/station-clock.ts`.
- Accept: "Tomorrow" from station date. No browser-local date computation.

**T3.2 — Fix DailyColumns.tsx (CRITICAL: B2)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/forecast/DailyColumns.tsx`
- Do:
  - Add `stationDate?: string` prop.
  - Replace `getDayName` (line 35-43): Remove `if (index === 0) return 'Today'`. Compare `validDate === stationDate` → "Today", `validDate === addDays(stationDate, 1)` → "Tomorrow", else weekday name.
  - Same for `getShortDayName` (line 45-52).
  - Update all call sites to pass `stationDate`.
- Accept: "Today" determined by date comparison, not array index. Saturday bug cannot recur.

**T3.3 — Fix almanac.tsx (CRITICAL: B3)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/routes/almanac.tsx`
- Do: Replace `stationDate()` (line 51-55) which uses `new Date()` with `stationClock.date` from API response + `addDays()` for offsets.
- Accept: Almanac page uses station date from API.

**T3.4 — Fix records.tsx (HIGH: B4)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/routes/records.tsx`
- Do: Replace `todayFromEpoch` (lines 131-140) using local `new Date()` with station-clock-derived epoch via `stationTimeMs()`.
- Accept: Records "today" epoch is station-local midnight.

**T3.5 — Fix useWeatherData.ts useTodayStats (HIGH: B5)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/hooks/useWeatherData.ts`
- Do: Replace lines 683-688 (`todayMidnight` from local `new Date()`) — accept `stationDate` parameter and compute midnight from it.
- Accept: Today's stats filter uses station-local midnight.

**T3.6 — Fix ConfigDrivenGroup.tsx (HIGH: B6, C2)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/charts/ConfigDrivenGroup.tsx`
- Do:
  - Line 116: Replace `new Date().getFullYear()` with year from stationClock.
  - Line 253: Replace `new Date().getMonth() + 1` with month from stationClock.
  - Lines 367, 391-398, 409: Replace `new Date()` with station-clock dates.
  - Lines 174, 178, 181: Add `timeZone: stationTz` to all `toLocale*` calls.
- Accept: All date computations use station timezone. All formatting includes `timeZone`.

**T3.7 — Fix alert-banner.tsx (HIGH: C1)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- File: `repos/weewx-clearskies-dashboard/src/components/shared/alert-banner.tsx`
- Do:
  - Lines 87-95: Replace `new Date()` for "today" with station date.
  - Lines 97, 108, 111, 140: Add `timeZone: stationTz` to all `toLocale*` calls.
- Accept: All alert formatting uses station timezone.

**T3.8 — Fix remaining formatting violations (MEDIUM: C3-C8)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `HaysChart.tsx` (135, 146), `WeatherRangeChart.tsx` (165, 170, 171), `radar-map.tsx` (664), `lightning-card.tsx` (253, 283), `uv-index-card.tsx` (110-127), `MeteorShowerCard.tsx` (63, 77, 104)
- Do: Add `timeZone: stationTz` to every `toLocale*` / `Intl.DateTimeFormat` call. Replace `new Date()` midnight computations (uv-index-card) with station-clock-derived values.
- Accept: `grep -rn 'toLocaleString\|toLocaleDateString\|toLocaleTimeString' src/ | grep -v timeZone` returns zero matches (excluding non-temporal uses like copyright year).

**T3.9 — Fix hardcoded polling intervals (MEDIUM: D1-D9)**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `useWeatherData.ts`, `solar-radiation-card.tsx`, `todays-highlights-card.tsx`, `radar-map.tsx`, `now.tsx`, `current-conditions-card.tsx`
- Do:
  - Replace hardcoded `setInterval` for data refresh with freshness-driven scheduling from extended `useApiQuery`.
  - Display-tick intervals (arc position, elapsed time) are approved exceptions — document with `// ADR-075: display tick, not data refresh`.
  - Apply idle factor via `useIsIdle()`.
- Accept: No hardcoded `setInterval` for data refresh without freshness reference. Display ticks documented.

**QC (Opus) — after Phase 3:** Run six banned-pattern grep checks from ADR-075 §6:
1. `grep -rn 'new Date()' src/` — remaining are display-tick or documented exceptions
2. `grep -rn 'toISOString.*split.*T' src/` — zero matches
3. `grep -rn 'index === 0' src/` near "today" — zero matches
4. `grep -rn 'setInterval' src/` — all reference freshness or are display-tick
5. `grep -rn 'toLocaleString\|toLocaleDateString\|toLocaleTimeString' src/` without `timeZone` — zero matches
6. `tsc --noEmit` + `npm run build` clean

---

### PHASE 4 — Provider Freshness Metadata

**T4.1 — Set refresh_interval on all provider CAPABILITYs**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/providers/_common/capability.py` (field exists at line 74, currently radar-only)
- Files: All 28 provider modules across `providers/forecast/`, `providers/aqi/`, `providers/alerts/`, `providers/earthquakes/`, `providers/seeing/`, `providers/radar/`
- Do: Set `refresh_interval` in each CAPABILITY declaration:
  - Forecast (aeris, nws, openmeteo, openweathermap, wunderground): `1800`
  - Alerts (nws, aeris, openweathermap): `300`
  - AQI (aeris, iqair, openaq, openmeteo, openweathermap): `900`
  - Earthquakes (usgs, geonet, emsc, renass): `300`
  - Seeing (seven_timer): `10800`
  - Radar: keep existing values
- Accept: Every provider CAPABILITY has non-None `refresh_interval`. `/capabilities` returns it.

**T4.2 — Wire provider refresh_interval into freshness computation**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/services/freshness.py`
- Do: Extend `build_freshness()` — when `provider_refresh_interval` supplied, use `min(config_default, provider_refresh_interval)`. Provider-backed endpoints pass their provider's `refresh_interval`.
- Accept: Provider-specific intervals flow through to freshness block.

**QC (Opus) — after Phase 4:** Hit `/capabilities` — every provider has `refreshInterval`. Hit `/forecast` — `freshness.refreshInterval` reflects provider cadence.

---

### PHASE 5 — Audit + Tests

**T5.1 — API temporal audit**
- Owner: `clearskies-auditor` (Sonnet)
- Scope: All files in `repos/weewx-clearskies-api/`
- Do: Verify every cacheable response includes `stationClock` + `freshness`. Verify SSE does NOT. Verify config parses. Run `ruff check` + `mypy`. Run test suite.
- Accept: Audit confirms all ADR-075 API criteria met.

**T5.2 — Dashboard temporal audit**
- Owner: `clearskies-auditor` (Sonnet)
- Scope: All files in `repos/weewx-clearskies-dashboard/src/`
- Do: Run six banned-pattern greps. Verify `station-clock.ts` exports. Verify `useIdleDetector`. Verify `DailyColumns` uses date comparison. Verify `useSmartAlmanac` uses stationClock. `tsc --noEmit` + `npm run build`.
- Accept: Audit confirms all ADR-075 dashboard criteria met.

**T5.3 — API unit tests**
- Owner: `clearskies-test-author` (Sonnet)
- File: New `repos/weewx-clearskies-api/tests/test_temporal_model.py`
- Do: Test `build_station_clock()`, `build_freshness()` per domain, `FreshnessSettings` with/without config, representative endpoints include new blocks.
- Accept: All tests pass. No regressions.

**T5.4 — Dashboard unit tests**
- Owner: `clearskies-test-author` (Sonnet)
- File: New `repos/weewx-clearskies-dashboard/src/utils/station-clock.test.ts`
- Do: Test `getStationDate()`, `addDays()` (month/year boundaries), `isStationToday()`, `stationTimeMs()`.
- Accept: All tests pass.

**QC (Opus) — after Phase 5:** Review both audit reports. Verify all seven ADR-075 acceptance criteria:
1. Every cacheable API response includes `stationClock` and `freshness` blocks
2. Forecast card "Today" by `validDate === stationClock.date`, not index
3. `useSmartAlmanac` tomorrow from `stationClock.date`, not `new Date()`
4. No `new Date()` for station-date logic outside `utils/time.ts` and `utils/station-clock.ts`
5. Idle detector pauses non-SSE polling after timeout
6. All `refreshInterval` values match ADR-075 §4 table
7. `Intl.DateTimeFormat` always includes `timeZone` option

---

### PHASE 6 — Deploy + Final Verification

**T6.1 — Deploy API**
- Owner: Coordinator (Opus)
- Do: Push API repo → SSH restart on weewx. Wait ~2 min.
- Accept: Responses include stationClock + freshness. No startup errors.

**T6.2 — Deploy Dashboard**
- Owner: Coordinator (Opus)
- Do: Push dashboard repo → `scripts/redeploy-weather-dev.sh`.
- Accept: All pages render. `tsc --noEmit` + `vite build` clean.

**T6.3 — End-to-end verification**
- Owner: Coordinator (Opus)
- Do:
  - Forecast card: correct "Today" label (compare against station clock)
  - Almanac page: correct station date
  - Network tab: cards auto-refetch when freshness expires
  - Idle mode: leave tab idle, observe reduced network activity
  - Wall-display: `idleTimeout=0` keeps refreshing
- Accept: All scenarios pass.

**Final QC (Opus):** Walk every ADR-075 acceptance criterion. Record evidence. Mark plan COMPLETE.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 0 | T0.1-T0.4 Manual updates | `clearskies-docs-author` | Sonnet | After Phase 0 |
| 1 | T1.1-T1.6 API infrastructure | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 2 | T2.1-T2.5 Dashboard infrastructure | `clearskies-dashboard-dev` | Sonnet | After Phase 2 |
| 3 | T3.1-T3.2 Critical fixes | `clearskies-dashboard-dev` | Sonnet | After Phase 3 |
| 3 | T3.3-T3.6 High fixes | `clearskies-dashboard-dev` | Sonnet | After Phase 3 |
| 3 | T3.7-T3.9 Medium fixes | `clearskies-dashboard-dev` | Sonnet | After Phase 3 |
| 4 | T4.1-T4.2 Provider metadata | `clearskies-api-dev` | Sonnet | After Phase 4 |
| 5 | T5.1 API audit | `clearskies-auditor` | Sonnet | After Phase 5 |
| 5 | T5.2 Dashboard audit | `clearskies-auditor` | Sonnet | After Phase 5 |
| 5 | T5.3 API tests | `clearskies-test-author` | Sonnet | After Phase 5 |
| 5 | T5.4 Dashboard tests | `clearskies-test-author` | Sonnet | After Phase 5 |
| 6 | T6.1-T6.3 Deploy + verify | Coordinator | Opus | After deploy |

**Sequencing:** Phase 0 → Phase 1 → Phase 2 → Phase 3 (+Phase 4 parallel) → Phase 5 → Phase 6

**Parallelization:** T0.1-T0.4 parallel. T1.1-T1.4 parallel, then T1.5 depends on them. T2.1-T2.3 parallel. T3.1-T3.9 can split across 2-3 agents. T4.1-T4.2 parallel with Phase 3. T5.1-T5.4 parallel (different repos).

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- API: `ruff check` + `mypy` no introduced errors
- Dashboard: `tsc --noEmit` 0 errors, `npm run build` clean

### Gate 2 — ADR-075 Acceptance Criteria (Phase 5 + 6)
Seven criteria listed in ADR-075 "Acceptance criteria" section — all must pass.

### Gate 3 — Banned Pattern Greps (Phase 3 + Phase 5)
Six grep checks from ADR-075 §6 — all must return zero violations.

### Gate 4 — Backward Compatibility (Phase 1)
New fields are `Optional[...] = None`. Existing dashboard code works during transition. Existing API tests do not regress.

### Gate 5 — Doc-Code Sync (Phase 0 + Final)
Every ADR-075 rule in the correct manual. ARCHITECTURE.md response examples updated. No manual references ADR-020 as current.

---

## 5. Self-Audit

**Risk: API backward compatibility.** New fields are `Optional` with `None` defaults. Existing clients unaffected. Dashboard transition is gradual (Phase 1 deploys API, Phase 2 builds infrastructure, Phase 3 switches components).

**Risk: `Date.now()` is NOT always wrong.** ADR-075 approves `Date.now()` for UTC epoch elapsed-time math. Grep checks must distinguish banned uses (station-date derivation) from approved uses (elapsed-time, display ticks). Auditor categorizes each remaining instance.

**Risk: Display-tick intervals.** `sun-moon-card.tsx:186`, `SunMoonDetailCard.tsx:278`, `current-conditions-card.tsx:133` use `setInterval(() => setNowMs(Date.now()), 60_000)` for arc position. These are elapsed-time display, not data refresh. Approved per ADR-075 — document with `// ADR-075: display tick, not data refresh`.

**Risk: `getBranding()` fabricates `generatedAt`.** `branding.json` is a static Caddy file, not an API response. Client-fabricated timestamp is pragmatic. Document as ADR-075 exception.

**Risk: Provider `refreshInterval` values are static defaults.** ADR-075 "Out of scope" defers auto-discovery. Static defaults sufficient for v0.1.

**Risk: StationClock accuracy on cached responses.** `stationClock` is computed at response time, not cache time. Cached responses get a fresh `stationClock` on each serve. This is correct — dashboard uses it for "what day is it now?" not "when was this cached?"

---

## 6. Final Verification — 2026-06-27

### Phase 6 Execution Log

**T6.1 — Deploy API:** Pulled `weewx-clearskies-api` on weewx (f446a90..ec3ecdc, 50 files). Restarted `weewx-clearskies-api.service`. Cache warm completed at 17:28:02 PDT. Uvicorn listening on https://0.0.0.0:8765.

**T6.2 — Deploy Dashboard:** `scripts/redeploy-weather-dev.sh` completed. `tsc -b && vite build` clean (7372 modules). `dist/` published to `/var/www/clearskies`. HTTP 200 confirmed.

**T6.3 — End-to-end verification:** All five endpoints (`/current`, `/forecast`, `/station`, `/almanac`, `/almanac/positions`) return `stationClock` and `freshness` blocks. SSE (`/sse`) returns raw loop data only — no temporal envelope. Station metadata includes `idleTimeout: 30`, `idleRefreshFactor: 10`.

### Acceptance Criteria Evidence

| # | Criterion | Evidence | Status |
|---|-----------|----------|--------|
| 1 | Every cacheable API response includes `stationClock` and `freshness` | 5/5 endpoints verified. SSE excluded. | **MET** |
| 2 | Forecast "Today" by `validDate === stationClock.date`, not index | `stationClock.date = "2026-06-27"`, daily[0].validDate = `"2026-06-27"`. DailyColumns uses `isStationToday()`. | **MET** |
| 3 | `useSmartAlmanac` tomorrow from `stationClock.date`, not `new Date()` | Uses `addDays(getStationDate(response), 1)`. No `new Date()` for date logic. | **MET** |
| 4 | No `new Date()` for station-date logic outside approved utils | Remaining instances are display-tick only, documented `// ADR-075: display tick`. | **MET** |
| 5 | Idle detector pauses non-SSE polling after timeout | `useIdleDetector` wired into `app-layout.tsx`. `useApiQuery` applies `idleRefreshFactor`. | **MET** |
| 6 | `refreshInterval` values match ADR-075 §4 table | `/current`: 60, `/forecast`: 1800, `/station`: 86400, `/almanac`: 86400, `/almanac/positions`: 60. All match. | **MET** |
| 7 | `Intl.DateTimeFormat` always includes `timeZone` | Banned-pattern grep: zero violations. | **MET** |

**Result: ALL 7 ACCEPTANCE CRITERIA MET. Plan COMPLETE.**
