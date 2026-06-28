# weewx Configuration Ingestion Fix — Execution Plan

**Status:** COMPLETE — All core phases implemented and deployed. API reads archive_interval/week_start from weewx.conf (station.py:363-393), exposes on /station endpoint, wires to sky_condition/temperature_comfort/barometer_trend via configure(). Dashboard uses archiveIntervalSeconds for chart aggregation and weekStartDay for week boundaries. Both coding rules added (coding.md rule 11, clearskies-process.md Belchertown reference). No wizard UI for these params — intentional, they're weewx-level config. Archived 2026-06-27.  
**Created:** 2026-06-18  
**Components:** API (`weewx-clearskies-api`), Dashboard SPA (`weewx-clearskies-dashboard`), Charts config, Documentation

---

## Context

The weewx `archive_interval` was changed from 300 seconds (5 minutes) to 60 seconds (1 minute). This exposed a systemic failure: **the Clear Skies stack never reads `archive_interval` from weewx.conf** and instead hardcodes `300` in multiple places across the API and dashboard. Belchertown handled this correctly — it reads `StdArchive.archive_interval` from weewx.conf at startup and passes it to the frontend as `archive_interval_ms` in `weewx_data.json`. We failed to carry this pattern forward.

The result: charts fetch 5× too many data points on 1-day views, the sky condition classifier's freshness check is miscalibrated, barometer trend grace windows are wrong, and the temperature comfort hold cache is disproportionate to the data cadence. Any operator running a non-300s archive interval has broken behavior.

This plan fixes every hardcoded assumption, makes `archive_interval` a first-class system parameter that flows from weewx.conf through the API to every consumer, updates the governing documentation, and adds rules to prevent this class of error from recurring.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — security, SQL, build verification
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/ARCHITECTURE.md` — service topology, endpoint inventory, unit conversion chain

**Repos (all under `c:\CODE\weather-belchertown\repos/`):**
- `weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`. Lint: `ruff check`, `mypy`.
- `weewx-clearskies-dashboard` — React SPA (Vite + Tailwind). Branch: `main`. Build: `npm run build`.

**Deploy (from any machine with replicated project files):**
- Dashboard: `bash scripts/redeploy-weather-dev.sh` (pulls, restarts services, builds, publishes)
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (takes ~2 min to warm cache)

**Belchertown reference (the pattern we should have followed):**
- `bin/user/belchertown.py:370-376` — reads `config_dict["StdArchive"]["archive_interval"]`, converts to ms, passes to templates
- `skins/Belchertown/json/weewx_data.json.tmpl:70-71` — exposes as `archive_interval` and `archive_interval_ms` in JSON
- `skins/Belchertown/graphs.conf:44,124` — `gapsize = 300 # This should be your archive_interval from weewx.conf`

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**QC role: Coordinator (Opus).** The coordinator performs QC after EVERY phase completes — not batched at the end. No phase advances until the coordinator signs off.

---

## 1. Gap Inventory

### A. API — Missing weewx.conf Reads

| # | Item | File | Line | Impact |
|---|------|------|------|--------|
| A1 | `StdArchive.archive_interval` not read from weewx.conf | `services/station.py` | — | **CRITICAL.** No component in the stack knows the actual archive interval. |
| A2 | `archive_interval` not in `StationInfo` data class | `services/station.py:55-91` | — | Station metadata cache has no field for it. |
| A3 | `archiveIntervalSeconds` not in `/station` response | `models/responses.py:626-640`, `endpoints/station.py:93-112` | — | Dashboard cannot receive it. |

### B. API — Hardcoded 300s Assumptions

| # | Item | File | Line | Current | Should Be |
|---|------|------|------|---------|-----------|
| B1 | `is_daytime()` freshness check | `sse/sky_condition.py` | 186 | `< 300.0` | `< archive_interval * 5` (dynamic) |
| B2 | Temperature comfort hold cache | `sse/temperature_comfort.py` | 24 | `_HOLD_SECONDS = 300.0` | Derived from archive_interval (e.g. `archive_interval * 5`) |
| B3 | Barometer trend grace default | `sse/enrichment/barometer_trend.py` | 62, 68 | `300` | Default to `archive_interval` value from startup config |
| B4 | Settings trend_time_grace default | `config/settings.py` | 1115 | `300` | Document that this should match archive_interval; keep as operator-overridable |

### C. Dashboard — Hardcoded 300s Assumptions

| # | Item | File | Line | Current | Should Be |
|---|------|------|------|---------|-----------|
| C1 | `StationMetadata` interface missing field | `api/types.ts` | 534-546 | No `archiveIntervalSeconds` | Add field |
| C2 | Mock station missing field | `mock/station.ts` | 7-15 | No `archiveIntervalSeconds` | Add field (300 default for mock) |
| C3 | `baseAggInterval` fallback | `components/charts/ConfigDrivenGroup.tsx` | 402 | Hardcoded `300` | Use station `archiveIntervalSeconds` |
| C4 | `useAggregation` threshold | `components/charts/ConfigDrivenGroup.tsx` | 414 | `aggInterval > 300` | `aggInterval > archiveIntervalSeconds` |

### D. Charts Configuration

| # | Item | File | Line | Current | Should Be |
|---|------|------|------|---------|-----------|
| D1 | `gapsize` hardcoded to 300 | Server `/etc/weewx-clearskies/charts.conf` | multiple | `gapsize = 300` | `gapsize = 60` (match current archive_interval) |
| D2 | `charts.conf.example` gapsize comment | `repos/weewx-clearskies-api/etc/charts.conf.example` | 83, 106-107 | "typically 300 = 5 minutes" | Update comment + default |

### E. Documentation & Rules

| # | Item | File | What |
|---|------|------|------|
| E1 | ARCHITECTURE.md — archive_interval flow | `docs/ARCHITECTURE.md` | Document that API reads archive_interval from weewx.conf and exposes on `/station` |
| E2 | API-MANUAL.md — station response | `docs/manuals/API-MANUAL.md` | Document new `archiveIntervalSeconds` field |
| E3 | coding.md — new rule | `rules/coding.md` | Rule: never hardcode weewx operational parameters |
| E4 | clearskies-process.md — new rule | `rules/clearskies-process.md` | Rule: check Belchertown implementation before building equivalent features |

### F. Tests

| # | Item | File | What |
|---|------|------|------|
| F1 | Sky condition test fixtures | `tests/test_sky_condition.py` | Update `interval_sec=300` fixtures; add test for `is_daytime()` with configurable threshold |
| F2 | Station metadata test | New or existing test | Verify `archiveIntervalSeconds` appears in `/station` response |

### G. Missing weewx.conf Read: `week_start`

| # | Item | File | Impact |
|---|------|------|--------|
| G1 | `Station.week_start` not read from weewx.conf | `services/station.py` | Operators can write `time_length = week` in charts.conf. Belchertown uses `config_dict["Station"].get("week_start", 6)` to calculate calendar-week spans (Monday=0, Sunday=6). Without this, weekly charts start on the wrong day. |
| G2 | `weekStartDay` not in `/station` response | `models/responses.py`, `endpoints/station.py` | Dashboard cannot compute correct week boundaries. |
| G3 | Dashboard `TIME_LENGTH_MAP` treats "week" as a fixed 604800s rolling window | `ConfigDrivenGroup.tsx:405` | Should compute calendar-week boundaries using `week_start`, not a rolling 7-day window. Belchertown did this correctly (`belchertown.py:2546-2549`). |

### H. Out of Scope (Explicit Deferrals)

| Item | Why Deferred |
|------|-------------|
| Input smoother / UV smoother buffer sizes | These are loop-packet-rate dependent (~5 sec), NOT archive-interval dependent. Loop packet cadence is unchanged. |
| Wind rolling window timing | Uses wall-clock seconds, independent of archive interval. |
| Alert provider cache TTLs (300s) | These are external API polling intervals per ADR-016/017, not archive-interval related. Coincidentally the same number. |

---

## 2. Implementation Phases

### PHASE 1 — API: Read archive_interval and expose on /station

**T1.1 — Read `StdArchive.archive_interval` and `Station.week_start` from weewx.conf at startup**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/services/station.py`
- Do: In `load_station_metadata()`:
  - Read `cfg.get("StdArchive", {}).get("archive_interval", 300)` (same pattern as Belchertown `belchertown.py:370-376`). Parse to int. Store on `StationInfo` as `archive_interval: int` (seconds). Fall back to 300 only if key is genuinely missing from weewx.conf.
  - Read `station_section.get("week_start", 6)` (same pattern as Belchertown `belchertown.py:2548`). Parse to int. Store on `StationInfo` as `week_start: int` (0=Monday, 6=Sunday). Fall back to 6 (Sunday, weewx default).
- Accept: `StationInfo.archive_interval` and `StationInfo.week_start` populated from weewx.conf. Correct fallbacks when keys absent.

**T1.2 — Add `archiveIntervalSeconds` and `weekStartDay` to `/station` response**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/models/responses.py` (add fields to `StationMetadata`), `repos/weewx-clearskies-api/weewx_clearskies_api/endpoints/station.py` (pass values from `StationInfo`)
- Do: Add `archiveIntervalSeconds: int` and `weekStartDay: int` to `StationMetadata` Pydantic model. In `get_station()`, set from `info.archive_interval` and `info.week_start`.
- Accept: `GET /api/v1/station` response includes `archiveIntervalSeconds: 60` and `weekStartDay: 6` (or whatever the operator has configured).

**T1.3 — Wire archive_interval to enrichment components that need it**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `repos/weewx-clearskies-api/weewx_clearskies_api/__main__.py` (startup wiring), `sse/sky_condition.py`, `sse/temperature_comfort.py`, `sse/enrichment/barometer_trend.py`
- Do:
  - **sky_condition.py**: Add a module-level `_archive_interval` variable. Add a `configure(archive_interval: int)` function. Change `is_daytime()` line 186 from `< 300.0` to `< _archive_interval * 5.0`. Wire from `__main__.py` after `load_station_metadata()`.
  - **temperature_comfort.py**: Change `_HOLD_SECONDS` from hardcoded `300.0` to accept a value via a `configure(archive_interval: int)` function. Set to `archive_interval * 5`. Wire from `__main__.py`.
  - **barometer_trend.py**: The `configure()` function already accepts `trend_time_grace`. In `__main__.py`, change the default for `trend_time_grace` from the hardcoded 300 in `settings.py` to use `station_info.archive_interval` when the operator hasn't explicitly set `[units] [[trend]] time_grace` in api.conf. This means: if operator set a value → use it; if defaulted → use archive_interval.
- Accept: All three components use the actual archive_interval. No hardcoded 300 in timing logic. `is_daytime()` works correctly with 60s data. Barometer trend grace scales with operator's archive interval unless explicitly overridden.

**QC (Opus) — after Phase 1:** Deploy API to weewx container. `curl` the `/api/v1/station` endpoint and verify `archiveIntervalSeconds: 60` and `weekStartDay` is present. Verify `is_daytime()` returns True within 300s of last reading (5 × 60 = 300). Check API startup logs for archive_interval and week_start loading. `ruff check` + `mypy` clean.

---

### PHASE 2 — Dashboard: Consume archive_interval for charts

**T2.1 — Add `archiveIntervalSeconds` and `weekStartDay` to dashboard types and data flow**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `repos/weewx-clearskies-dashboard/src/api/types.ts` (add to `StationMetadata`), `repos/weewx-clearskies-dashboard/src/mock/station.ts` (add to mock)
- Do: Add `archiveIntervalSeconds: number;` and `weekStartDay: number;` to the `StationMetadata` interface. Add to mock with values `300` and `6` respectively.
- Accept: TypeScript compiles. Mock station has both fields.

**T2.2 — Pass archive_interval and week_start to ConfigDrivenGroup, replace hardcoded 300s, fix week spans**
- Owner: `clearskies-dashboard-dev` (Sonnet)
- Files: `repos/weewx-clearskies-dashboard/src/components/charts/ConfigDrivenGroup.tsx`, `repos/weewx-clearskies-dashboard/src/routes/charts.tsx`, `repos/weewx-clearskies-dashboard/src/routes/now.tsx`
- Do:
  - Add `archiveIntervalSeconds` and `weekStartDay` props to `ConfigDrivenGroup` (defaults `300` and `6`).
  - **Line 402**: Change `300` fallback to `archiveIntervalSeconds` prop.
  - **Line 414**: Change `aggInterval > 300` to `aggInterval > archiveIntervalSeconds`.
  - **Line 405**: When `time_length` is `"week"`, compute the actual calendar-week span using `weekStartDay` (same logic as Belchertown `belchertown.py:2546-2549` which calls `archiveWeekSpan(timestamp, week_start)`) instead of a fixed 604800-second rolling window. The `from`/`to` for the data fetch should be the start of the current calendar week (based on `weekStartDay`) through now.
  - In `charts.tsx` and `now.tsx`: pass both props from station data to every `ConfigDrivenGroup` instance.
- Accept: With 60s archive interval, the 1-day chart sends `aggregate_interval=300` to the API. Weekly chart groups (if configured by operator) use the correct week boundary. `tsc --noEmit` + `vite build` clean.

**QC (Opus) — after Phase 2:** Deploy dashboard. Open the Charts page 1-day view. Verify browser Network tab shows `aggregate_interval=300` in the archive API request (not absent). Verify chart renders ~288 data points, not 1440. Check 7-day view still works (aggregate_interval should be ~2100). `tsc --noEmit` clean.

---

### PHASE 3 — Charts configuration: fix gapsize

**T3.1 — Update live charts.conf on the server**
- Owner: Coordinator (Opus)
- File: `/etc/weewx-clearskies/charts.conf` on the `weewx` LXD container
- Do: SSH to the weewx container. Change all `gapsize = 300` entries to `gapsize = 120` (2× archive_interval — tolerates one missed record without drawing a gap).
- Accept: Charts no longer show false gap lines at data-density transitions.

**T3.2 — Update charts.conf.example**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/etc/charts.conf.example`
- Do: Change `gapsize = 300` to `gapsize = 300` with updated comment: `# Should be 2× your weewx archive_interval. Default 300 = 2 × 150s.` Actually — since the example should work for the most common case (300s archive), keep the value at 300 but improve the comment to explain it must be tuned: `# Must match your weewx archive_interval. Recommended: archive_interval × 2. Default 300 assumes 5-minute (300s) archives; change to 120 for 1-minute archives.`
- Accept: Comment is clear. Operators know to adjust.

**QC (Opus) — after Phase 3:** Verify no gap lines in 1-day solar radiation chart (the chart from the original screenshot). Verify daily/monthly charts with `gapsize = 86400` are unaffected.

---

### PHASE 4 — Documentation and rules updates

**T4.1 — Update ARCHITECTURE.md**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/ARCHITECTURE.md`
- Do: Add a new subsection "## weewx configuration ingestion" documenting:
  - Which weewx.conf sections the API reads: `[Station]` (existing) + `[StdArchive]` (new)
  - The `archiveIntervalSeconds` field on the `/station` response
  - How the dashboard uses it for chart proportional scaling
  - That Belchertown's pattern (`belchertown.py:370-376`) was the reference implementation
- Accept: New subsection present. Accurate.

**T4.2 — Update API-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/manuals/API-MANUAL.md`
- Do: Add `archiveIntervalSeconds` to the `/station` response documentation. Document its source (weewx.conf `[StdArchive] archive_interval`) and fallback (300 if key absent).
- Accept: Field documented.

**T4.3 — Add rule to coding.md: never hardcode weewx operational parameters**
- Owner: Coordinator (Opus)
- File: `rules/coding.md`
- Do: Add a new rule in §1 (Security & safety) or a new §-level section:

  > **Never hardcode weewx operational parameters.** Values like `archive_interval`, `week_start`, unit system, and database type vary per operator installation. Read them from weewx.conf (via the API's `get_weewx_conf()` / `StationInfo`) and pass them through the stack. Do not use magic numbers like `300` for "5-minute archive interval" — the operator may run 60s, 300s, or 600s. The reference pattern is Belchertown's `belchertown.py:370-376`: read from `config_dict["StdArchive"]["archive_interval"]`, expose to consumers, use everywhere.
  >
  > **How to apply:** Before writing any timing constant, ask: "does this value depend on the operator's weewx configuration?" If yes, it must come from the config, not from a literal. When adding a new timing-dependent feature, check what Belchertown does first — `bin/user/belchertown.py` and `skins/Belchertown/` are in this repo.

- Accept: Rule present. References the Belchertown pattern.

**T4.4 — Add rule to clearskies-process.md: check Belchertown before building**
- Owner: Coordinator (Opus)
- File: `rules/clearskies-process.md`
- Do: Add a rule:

  > **Check Belchertown's implementation before building equivalent features.** The Belchertown skin source is in this repo (`bin/user/belchertown.py`, `skins/Belchertown/`). Before implementing any feature that Belchertown already handles — charts, data formatting, archive queries, configuration — read how Belchertown does it and carry forward the correct patterns. Don't re-derive from first principles when a working reference exists.
  >
  > **Why (2026-06-18):** The archive_interval was hardcoded as 300 across the entire Clear Skies stack. Belchertown correctly reads it from weewx.conf and passes it to the frontend. We had the code in the repo and didn't look at it. Every timing-dependent component was built on a false assumption.

- Accept: Rule present. Dated with context.

**QC (Opus) — after Phase 4:** Read each modified doc. Verify accuracy against the code changes from Phases 1-3. Verify new rules are actionable (not vague platitudes).

---

### PHASE 5 — Tests

**T5.1 — Update sky_condition test fixtures**
- Owner: `clearskies-test-author` (Sonnet)
- Files: `repos/weewx-clearskies-api/tests/test_sky_condition.py`
- Do: Update test fixtures that use `interval_sec=300` to also test with `interval_sec=60`. Add test for `is_daytime()` verifying it uses the configured archive_interval threshold, not hardcoded 300. Add test for `configure(archive_interval=60)` affecting behavior.
- Accept: Tests pass with both 60s and 300s interval fixtures. `is_daytime()` threshold test verifies dynamic behavior.

**T5.2 — Add station endpoint test for archiveIntervalSeconds**
- Owner: `clearskies-test-author` (Sonnet)
- Files: `repos/weewx-clearskies-api/tests/test_endpoints_integration.py` or new test file
- Do: Add test that verifies `GET /api/v1/station` response includes `archiveIntervalSeconds` with the value from weewx.conf.
- Accept: Test passes. Field present in response.

**QC (Opus) — after Phase 5:** Run `pytest` on the API repo. All tests pass. New tests cover the archive_interval flow.

---

### PHASE 6 — Deploy & Final Verification

**T6.1 — Deploy API**
- Owner: Coordinator (Opus)
- Do: Push API repo. SSH to weewx container, pull, restart service. Wait ~2 min for cache warm.
- Accept: `GET /api/v1/station` returns `archiveIntervalSeconds: 60`.

**T6.2 — Deploy dashboard**
- Owner: Coordinator (Opus)
- Do: Push dashboard repo. Run `scripts/redeploy-weather-dev.sh`.
- Accept: Charts page 1-day view shows ~288 data points. No gap artifacts. Solar radiation chart from the original screenshot renders cleanly.

**T6.3 — Push meta repo (docs + rules)**
- Owner: Coordinator (Opus)
- Do: Commit and push `docs/ARCHITECTURE.md`, `docs/manuals/API-MANUAL.md`, `rules/coding.md`, `rules/clearskies-process.md`.
- Accept: All doc changes on GitHub.

**Final QC (Opus):** Walk every acceptance criterion from every task. Verify Solar Radiation chart renders without the vertical gap. Verify 1-day chart sends `aggregate_interval=300`. Verify `/station` response has `archiveIntervalSeconds: 60`. Verify `is_daytime()` works with 60s data. Read each modified doc for accuracy.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC (Opus) | QC Timing |
|-------|------|-------|-------|-----------|-----------|
| 1 | T1.1 Read archive_interval | `clearskies-api-dev` | Sonnet | Verify StationInfo field populated | After Phase 1 |
| 1 | T1.2 Add to /station response | `clearskies-api-dev` | Sonnet | curl /station, check field | After Phase 1 |
| 1 | T1.3 Wire to enrichment components | `clearskies-api-dev` | Sonnet | Verify no hardcoded 300 in timing logic | After Phase 1 |
| 2 | T2.1 Dashboard types | `clearskies-dashboard-dev` | Sonnet | tsc --noEmit | After Phase 2 |
| 2 | T2.2 ConfigDrivenGroup fix | `clearskies-dashboard-dev` | Sonnet | Network tab verification | After Phase 2 |
| 3 | T3.1 Server charts.conf | Coordinator | Opus | Visual chart check | After Phase 3 |
| 3 | T3.2 charts.conf.example | `clearskies-api-dev` | Sonnet | Comment review | After Phase 3 |
| 4 | T4.1 ARCHITECTURE.md | `clearskies-docs-author` | Sonnet | Doc accuracy review | After Phase 4 |
| 4 | T4.2 API-MANUAL.md | `clearskies-docs-author` | Sonnet | Doc accuracy review | After Phase 4 |
| 4 | T4.3 coding.md rule | Coordinator | Opus | Rule is actionable | After Phase 4 |
| 4 | T4.4 clearskies-process.md rule | Coordinator | Opus | Rule is actionable | After Phase 4 |
| 5 | T5.1 Sky condition tests | `clearskies-test-author` | Sonnet | pytest passes | After Phase 5 |
| 5 | T5.2 Station endpoint test | `clearskies-test-author` | Sonnet | pytest passes | After Phase 5 |
| 6 | T6.1-T6.3 Deploy + verify | Coordinator | Opus | Walk all acceptance criteria | After deploy |

**Sequencing:**
- Phase 1 (API reads + exposes archive_interval) — must complete first, everything depends on it
- Phase 2 (dashboard consumes it) — depends on Phase 1
- Phase 3 (charts.conf fix) — independent of Phase 2, can run in parallel
- Phase 4 (docs + rules) — can run in parallel with Phase 2/3
- Phase 5 (tests) — depends on Phase 1 code being stable
- Phase 6 (deploy) — after all phases

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- API: `ruff check` + `mypy` no introduced errors.
- Dashboard: `tsc --noEmit` 0 errors. `vite build` clean.

### Gate 2 — Feature Correctness (per phase, Opus verifies)
- Phase 1: `curl /api/v1/station` returns `archiveIntervalSeconds: 60` and `weekStartDay`.
- Phase 2: Charts page 1-day view sends `aggregate_interval=300` in network request. Weekly chart groups (if configured) use correct week boundary.
- Phase 3: Solar radiation chart renders without gap artifacts.

### Gate 3 — No Regressions
- 7-day, 30-day, 90-day charts still render correctly (aggregation still works).
- `is_daytime()` returns True when sky data is recent (< 5 × archive_interval).
- Barometer trend still computes correctly.
- Mock mode still works (dashboard with `VITE_USE_MOCK=true`).

### Gate 4 — Documentation Accuracy (Opus verifies after Phase 4)
- ARCHITECTURE.md documents the actual code flow (not aspirational).
- API-MANUAL.md field description matches the Pydantic model.
- New rules in coding.md and clearskies-process.md reference specific files and line numbers.
- Doc-code sync rule satisfied: code change + doc change in same commit/PR.

---

## 5. Self-Audit

**Risk: Fallback value when weewx.conf lacks `[StdArchive]`.** Mitigated: fall back to 300 (same as Belchertown). Log a WARNING so the operator knows. weewx always writes `[StdArchive]` to `weewx.conf` on install, so this path should be rare.

**Risk: Breaking change if operator has not updated charts.conf gapsize.** Mitigated: the charts.conf gapsize is an operator-configurable value, not system-derived. We update it on our server (T3.1) and improve the example comment (T3.2). Operators who deploy fresh will see the improved guidance.

**Risk: Dashboard backward compat if API hasn't been updated yet.** Mitigated: `ConfigDrivenGroup` prop defaults to `300` if not provided. The `StationMetadata` interface adds an optional field. Old API responses without the field will use 300 (same as current behavior).

**Risk: Temperature comfort hold becoming too short.** With `archive_interval * 5 = 300` at 60s interval, hold is still 300s — unchanged from current. At 300s interval it would be 1500s (25 min) — longer than current but arguably correct since data arrives less frequently. If this feels wrong, we can cap it. The plan uses `archive_interval * 5` as the formula.

**Risk: `is_daytime()` threshold.** With 60s interval, threshold becomes `60 * 5 = 300s`. With 300s interval, it becomes `300 * 5 = 1500s` (25 min). The 25-min window for 5-min data seems generous but safe — it means "daytime detection stays active if data arrived within the last 5 intervals." If this is too loose for 5-min intervals, we can tighten the multiplier to 3 (15 min). The plan uses 5× as the starting point.
