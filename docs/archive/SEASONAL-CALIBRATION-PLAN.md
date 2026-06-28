# Seasonal Monthly-Normals Calibration Model — Implementation Plan

**Status:** COMPLETE (abandoned) — Phases 0-8 were implemented and deployed, but the seasonal calibration system created more issues than it solved and was removed from the codebase. The approach was determined to be counterproductive in practice. Archived 2026-06-27.  
**Created:** 2026-06-22  
**Origin:** Rework of Phase 8 auto-calibration (flat 90-day window) to science-backed monthly normals  
**Components:** API (`weewx-clearskies-api`), Stack (`weewx-clearskies-stack`), Meta (`weather-belchertown`)

---

## Session Context (for cold-start)

### What prompted this

During Phase 10 (deploy + verify) of the Haze/Fog/NWS Text implementation plan (`docs/planning/HAZE-FOG-NWS-TEXT-IMPLEMENTATION-PLAN.md`), the user identified that the auto-calibration system ignored the project's own research on seasonal variation. The research (Correa 2022, Renner 2019, Stein et al. 2012) established that clear-sky transmittance varies by month, but the implementation used a flat 90-day rolling percentile with no seasonal awareness. The user called this out as "throwing the research out the window."

### What's deployed (as of 2026-06-22)

Phases 0-9 of the Haze/Fog/NWS Text plan are complete and deployed. Phase 10 deployment is partially done:

- **API on weewx** (`weewx.shaneburkhardt.com`): at commit `170805f` (includes openaq_api_key fix for wizard 422). Service running, all Phase 9 audit remediations active. 354 new tests passing. `weatherText`, `weatherTextStandard`, `weatherTextVerbose` fields live.
- **Stack on weather-dev** (`192.168.2.113`): at commit `861e121` (includes about_content wizard fixes + openaq_api_key round-trip). Config UI running on port 9876.
- **Meta repo**: at commit `02a49d0` (Phase 9 plan closeout).
- **Aeris AQI** is now the active AQI provider (user applied wizard settings this session).
- **OpenAQ API key** entered by user in wizard, written to `secrets.env` on weewx.

### Key infrastructure notes

- **DILBERT is down.** Working from CATBERT. Repos replicate via Nextcloud.
- Tests run on **weewx** container (not weather-dev): `ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -lc 'export PATH=/home/ubuntu/.local/bin:$PATH && cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest ...'"` 
- API sync: `ssh -F .local/ssh/config weewx "sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-api && git pull --ff-only'"` then `sudo systemctl restart weewx-clearskies-api` (2-min startup).
- Stack sync: `ssh -F .local/ssh/config weather-dev "sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-stack && git pull --ff-only'"` then pip reinstall + `sudo systemctl restart weewx-clearskies-config`.
- The sync script (`scripts/sync-to-weather-dev.sh`) does NOT include the API repo.
- Pytest baseline: 3188+ passed, 358 skipped, 3 pre-existing failures (OWM Redis cache x 2, weewx metadata x 1).

### Design decisions from user conversation

These are settled — do not re-derive or re-propose alternatives:

1. **Monthly normals, not rolling window.** 12 per-month Kcs baselines. Compare today against what clear sky looks like *this month*, not a flat average.
2. **3-year rolling window per month.** Samples older than 3 years age out (sensor drift). 2 years minimum for bootstrap.
3. **Fixed parameters, not operator-tunable.** 92nd percentile, 30 samples/month minimum, 3-year window. Science sets these. Remove `calibration_percentile`, `calibration_window_days`, `calibration_min_samples` from config and admin UI.
4. **Automatic bootstrap.** API detects OpenAQ key + insufficient data at startup → bootstraps in background. No CLI, no admin button, no SSH.
5. **Progressive activation.** Start with flat baseline (current behavior). Each month independently transitions to its learned normal at >= 30 samples. Admin shows "N of 12 months calibrated."
6. **Operator can disable during learning, auto-enable at 12/12.** Admin toggle for haze detection. System auto-enables once fully calibrated.
7. **Hardware change:** Manual reset button in admin + automatic drift detection + station_type change warning on restart.
8. **Graceful sensor failover.** Missing pyranometer → provider haze 24/7 (extends nighttime deferral). Missing hygrometer → provider fog/mist. Silent failover, no operator messaging. Dashboard never shows nulls.
9. **Cross-host topology.** Admin reads calibration state from API endpoints (`/setup/calibration-state`, `/setup/calibration-reset`), NOT from local filesystem. calibration.json is on weewx, admin is on weather-dev.
10. **calibration.json stays at `/etc/weewx-clearskies/calibration.json`.** Same location, v2 format with month-keyed structure. v1 migration on load.

### Bugs fixed during this session (already deployed, not part of this plan)

- **Wizard 422 on apply:** `ApplyRequest` model missing `openaq_api_key` field (API commit `170805f`, stack commit `2d44b34`).
- **Station description not sticking:** Three bugs — template `about_content` missing `state.` prefix, `populate_from_branding_json` not reading `aboutContent` back, and branding read gated behind `station_name is None` (stack commits `941a961`, `52a3de7`, `861e121`).

### Session 1 progress (2026-06-22)

**Phases completed:** 0, 1, 2, 3, 4 (ADR amendment, manual updates, core model rewrite, bootstrap rework, wiring).

**Meta repo** (weather-belchertown, branch `master`): 4 commits ahead of origin.
- ADR-068 amended and accepted (monthly-normals model)
- API-MANUAL.md §8, OPERATIONS-MANUAL.md §4, ARCHITECTURE.md updated — removed 90-day model references, added monthly-normals, added calibration endpoints

**API repo** (weewx-clearskies-api on weewx container, branch `main`): 1 commit ahead of origin.
- `auto_calibration.py` — complete rewrite: 12 per-month baselines, 3-year window, fixed 92nd percentile, v1→v2 migration, drift detection, station type tracking, set_timezone/set_station_type/set_has_radiation
- `importer.py` — monthly bins, per-month baseline computation after import
- `__main__.py` — auto-bootstrap at startup, configure() removed, --years/--max-distance-km removed, set_timezone/set_station_type/set_has_radiation/check_station_type_change wired
- `settings.py` — calibration_percentile/window_days/min_samples removed from ConditionsSettings
- `endpoints/setup.py` — GET /setup/calibration-state + POST /setup/calibration-reset added
- `enrichment/weather_text.py` — missing pyranometer/hygrometer deferral to provider in both terse and code paths
- `haze_condition.py` — docstring updates (phase references resolved)

**Stack repo** (weewx-clearskies-stack on weather-dev): NOT YET TOUCHED. Phase 5 is next.

**Known issue:** The weewx container has an automated process (likely Nextcloud sync cron) that runs `git pull` and occasionally `git reset --hard origin/main`. This caused a Phase 4 commit to be lost mid-session (recovered via `git cherry-pick` from reflog). Before pushing API commits, verify reflog state. Consider pushing immediately after committing to prevent sync-related data loss.

**What's next:** Phase 5 (admin UI rework in stack repo), Phase 6 (tests), Phase 7 (audit), Phase 8 (deploy).

### Session 2 progress (2026-06-22)

**Phases completed:** 5, 6 (admin UI rework, testing).

**Meta repo** (weather-belchertown, branch `master`): pushed to origin at `32c0b62`. 1 new local commit pending (process rule addition to clearskies-process.md — not yet committed).

**API repo** (weewx-clearskies-api, branch `main`): pushed to origin at `2bc9c9d`.
- `tests/test_auto_calibration.py` — complete rewrite: 72 tests across 10 groups (percentile helper, monthly baseline, state transitions, drift, station type, flat fallback, process_packet gates, v2 persistence, v1 migration, timezone binning). All 72 passing. Full suite: 3210 passed, 358 skipped, 3 pre-existing failures.

**Stack repo** (weewx-clearskies-stack, branch `main`): pushed to origin at `47cd514`.
- `haze_calibration.html` — removed calibration param form + CLI bootstrap aside + 90-day status. Added 12-month grid, drift warnings, reset button, API-unreachable handling.
- `admin/routes.py` — `_HAZE_DEFAULTS` trimmed to 2 keys. `_read_calibration_state()` replaced with API call via `_get_api_client()` helper. POST saves only `haze_detection` + `gamma`. New `POST /admin/haze-calibration/reset` route. `import time` removed.
- `landing.html` — haze card shows `overall_state` + "N/12 months calibrated" instead of "Samples (90-day)". API-unreachable handling.

**Stack NOT YET deployed** to weather-dev. API NOT YET restarted with new tests (tests were run but service not restarted — no code changes to the service itself in this session).

**Lesson captured:** Added rule to `rules/clearskies-process.md` — "Agents commit locally, never on production containers." Prior session committed directly on weewx; recovery required git-bundle extraction. The rule file edit is uncommitted.

**What's next:** Phase 7 (audit + QA), Phase 8 (deploy + verify).

### Session 3 progress (2026-06-22)

**Phases completed:** 7 (audit + QA). Phase 8 (deploy + verify) in progress.

**Meta repo** (weather-belchertown, branch `master`): pushed to origin at `e59a146`.
- Session 2 uncommitted changes committed (`f23c3f7`): process rule + plan update.
- Phase 7 doc-code sync fixes (`e59a146`): reset endpoint description corrected in ARCHITECTURE.md, API-MANUAL.md, ADR-068 — "re-bootstrap on next restart" not "trigger re-bootstrap."

**API repo** (weewx-clearskies-api, branch `main`): pushed to origin at `6194bb5`.
- Bootstrap bug fix (`6194bb5`): OpenAQ API v3 returns `meta.found` as a string in some responses. The ceil-division idiom `-(-total_found // limit)` raised TypeError on strings. Cast to int defensively.
- API restarted on weewx to pick up new endpoints (calibration-state, calibration-reset) and bootstrap fix.

**Stack repo** (weewx-clearskies-stack, branch `main`): deployed to weather-dev at `47cd514`.
- `git pull --ff-only` + `pip install --no-deps -e .` + `systemctl restart weewx-clearskies-config`.
- Admin haze calibration page confirmed rendering: no old param form, 12-month grid area present, reset button present.

**Phase 7 audit results:**
- Code audit (Sonnet auditor): 9 of 11 items PASS. 2 items (stack template + routes) verified at deploy. F1/F2 (old deployed stack code) confirmed fixed by `47cd514`. F3 (reset endpoint doc mismatch) fixed by coordinator. F4 (intentional backward-compat doc) — no action.
- Doc-code sync (coordinator): 1 finding fixed (reset endpoint description). Config keys, state names, endpoint inventory, calibration state response schema all match between docs and code.
- API test baseline: 3210 passed, 358 skipped, 3 pre-existing failures. Zero introduced.

**Bug found during deploy:** API returned 404 on `/setup/calibration-state` because the service hadn't been restarted since the endpoint code was committed (service started at 15:30, endpoint commit at 15:33). Restarted API. Then bootstrap failed with "bad operand type for unary -: 'str'" — OpenAQ `meta.found` returned as string. Fixed in `6194bb5`.

**What's next:** Verify bootstrap completes after fix, verify admin page shows calibration data, final end-to-end checks.

---

## What Changes

Replace the flat rolling-window model with 12 per-month Kcs baselines (climatological monthly normals) backed by a 3-year rolling window. Bootstrap automatically on startup. Remove operator-tunable calibration parameters. Add hardware change detection. Add API endpoints for calibration state/reset. Extend provider deferral for missing sensors.

**What doesn't change:** The clean-sky gate criteria (rain holdoff, solar elevation, sky classifier, PM threshold), the hygroscopic correction (gamma), the haze detection logic in haze_condition.py (it still receives a single baseline float), the Kcs computation itself.

**Graceful sensor failover:** When sensor data is absent, the affected module silently falls back to provider present weather codes — same mechanism as nighttime deferral (ADR-071). No operator-facing warnings. Dashboard never shows null data.

| Sensor data absent | Failover |
|---|---|
| `radiation` (no pyranometer) | Sky: provider cloud cover % (already works). Haze: provider present weather (HZ) 24/7. Calibration: skip. |
| `dewpoint` (no hygrometer) | Fog/mist: provider present weather (BR/FG). f(RH) correction: skip (use uncorrected deficit). Comfort: omit. |

---

## Phase 0 — ADR-068 Amendment

ADR-068 (Auto-Calibration Baseline System) must be amended to reflect the monthly-normals model. Status flips to Proposed, user approves, then re-archived.

**T0.1 — Amend ADR-068**
- Owner: Coordinator (Opus) — judgment work
- Changes: Replace 90-day rolling window with monthly-normals model. Remove operator-tunable calibration parameters. Add auto-bootstrap requirement. Add hardware change handling. Add degraded-mode progressive activation.
- Accept: ADR reflects all design decisions from the user conversation. User approves.

---

## Phase 1 — Manual Updates (Before Code)

**T1.1 — Update API-MANUAL.md section 8 (auto-calibration)**
- Owner: `clearskies-docs-author`
- Rewrite auto-calibration subsection: 12 per-month buckets, 3-year rolling window, fixed 92nd percentile (not tunable), progressive activation (each month independently transitions from flat fallback to learned normal at >= 30 samples), auto-bootstrap, hardware change handling.
- Remove `calibration_percentile`, `calibration_window_days`, `calibration_min_samples` from config table. Keep `haze_detection`, `gamma`, `haze_aqi_provider`.
- Add: storage format (month-keyed calibration.json), degraded-mode behavior, drift detection, reset semantics.
- Accept: No references to flat 90-day window. No references to removed config keys as tunable.

**T1.2 — Update OPERATIONS-MANUAL.md**
- Owner: `clearskies-docs-author`
- Remove calibration params from `[conditions]` config table. Remove CLI bootstrap instructions. Rewrite admin haze calibration section: per-month status grid, reset button, drift warnings. Describe auto-bootstrap (startup detection, background execution).
- Accept: No manual CLI references. Config table has exactly `haze_detection`, `haze_aqi_provider`, `gamma`.

**T1.3 — Update ARCHITECTURE.md**
- Owner: `clearskies-docs-author`
- Update `auto_calibration.py` description: "monthly-normals model, 12 per-month Kcs baselines, 3-year rolling window, automatic bootstrap, persistent storage." Add new API endpoints (`/setup/calibration-state`, `/setup/calibration-reset`) to setup endpoints table.
- Accept: Architecture description says "monthly-normals" not "90-day rolling percentile."

**QC (Opus):** Read every updated section. Walk each removed config key — confirm no orphan references. Cross-check API-MANUAL, OPS-MANUAL, and ARCHITECTURE agree on config keys, state names, and endpoint inventory.

---

## Phase 2 — auto_calibration.py Rework (Core Model)

**T2.1 — Rewrite auto_calibration.py**
- Owner: `clearskies-api-dev`
- This is the largest task. Key changes:

**Data structure:**
- Replace `_samples: list[tuple[float, float]]` with `_monthly_samples: dict[int, list[tuple[float, float]]]` keyed by month 1-12 (station local time, not UTC — a sample at 11pm Jan 31 local is January's bin).
- Add `_monthly_baselines: dict[int, float | None]` and `_flat_baseline: float | None` (fallback from all months pooled).
- Add `_station_type_at_load: str | None` for hardware change tracking.

**Constants (fixed, not configurable):**
- `_WINDOW_YEARS = 3`, `_MIN_SAMPLES_PER_MONTH = 30`, `_PERCENTILE = 92`, `_MIN_MONTHS_AUTO_ENABLE = 12`, `_DRIFT_THRESHOLD = 0.05`
- Remove all mutable globals (`_WINDOW_DAYS_PRIMARY`, `_PERCENTILE_LOW`, etc.)

**Functions:**
- Remove `configure()` entirely.
- `process_packet()`: same gate sequence, appends to `_monthly_samples[local_month]`, prunes >3yr samples across all months, recomputes current month's baseline, calls `haze_condition.set_baseline()` with current month's value (or flat fallback).
- New `compute_monthly_baseline(month) -> float | None`: 92nd percentile of that month's samples, requires >= 30.
- New `get_current_baseline() -> float | None`: returns current month's baseline, falls back to flat, returns None if neither available.
- Reworked `get_calibration_state() -> dict`: returns `months_calibrated` (0-12), `per_month` (12-element list with name/count/baseline/is_calibrated), `flat_baseline`, `overall_state` ("no-data" | "bootstrapping" | "partial" | "fully-calibrated"), `drift_warnings`, `station_type`.
- New `_check_drift(month) -> dict | None`: if mean of last 10 samples diverges from baseline by > 0.05, return warning.
- New `set_station_type(type)` and `check_station_type_change(current) -> bool`.

**Persistence (calibration.json v2):**
```json
{
  "version": 2,
  "station_type": "Vantage",
  "monthly_samples": {"1": [[ts, kcs], ...], ... "12": [...]},
  "monthly_baselines": {"1": 0.912, "2": null, ...},
  "flat_baseline": 0.908
}
```
- `load_persisted()` handles v1 migration: distributes flat `samples` list into month buckets by timestamp (using station timezone).
- `persist()` writes v2 only.

**Station timezone:** Module needs the station timezone (from StationInfo) to bin samples by local month. New `set_timezone(tz_name: str)` called at startup.

**Pyranometer check:** New `_has_radiation: bool` module-level flag. Set at startup via `set_has_radiation(has: bool)` — caller checks column registry for `radiation`. When False: `process_packet()` returns immediately. The flag is also re-evaluated inside `process_packet()` — if `sky_condition.get_current_kcs()` returns a non-None value, flip `_has_radiation = True` (sensor was added). This handles the "added a pyranometer later" case without requiring a restart.

- Accept: Module compiles. `configure()` gone. `_samples` gone. `get_calibration_state()` returns new schema. v1 migration works. v2 persistence round-trips.

**QC:** Coordinator imports module, calls `get_calibration_state()`, verifies schema. Greps for `configure(` — zero hits. Greps for `_samples` as a standalone name — zero hits (only `_monthly_samples`).

---

## Phase 3 — Bootstrap Rework

**T3.1 — Update importer.py for monthly bins**
- Owner: `clearskies-api-dev`
- `run_bootstrap()` appends to `auto_calibration._monthly_samples[month]` (using station local time). Computes per-month baselines after import. Summary reports per-month counts.
- Remove references to `auto_calibration._samples` and `auto_calibration.compute_baseline()`.
- Accept: No references to `_samples`. Summary includes per-month breakdown.

**T3.2 — Add auto-bootstrap to __main__.py**
- Owner: `clearskies-api-dev`
- After `load_persisted()`, check: OpenAQ key present + `months_calibrated < 12` → run bootstrap synchronously after `load_persisted()` but before packet_tap registration (avoids thread safety issues, same order as cache warmer, takes 2-5 minutes).
- Remove `configure()` call. Replace with `haze_condition.set_gamma(conditions.gamma)`.
- Add `auto_calibration.set_timezone(station_info.timezone)`, `auto_calibration.set_station_type(station_info.hardware)`, and `auto_calibration.set_has_radiation("radiation" in column_registry)` after station metadata and schema load.
- Auto-bootstrap gated on `_has_radiation` — skip if no radiation column.
- Station type change check: log WARNING if changed since persisted data.
- Remove `--years` and `--max-distance-km` from bootstrap CLI argparse. Always pull 3 years max available.
- Accept: `configure()` call gone. Auto-bootstrap runs at startup. Station type check logged.

**QC:** Coordinator greps `__main__.py` for `configure(` — zero hits. Greps for `--years` in argparse — zero hits. Checks startup log for auto-bootstrap message.

---

## Phase 4 — Wiring (haze_condition + settings + API endpoints)

**T4.1 — Extend provider deferral for missing sensors**
- Owner: `clearskies-api-dev`
- Extend the nighttime deferral check in `enrichment/weather_text.py` and `provider_weather_feed.py`: the existing check is `solar_elevation <= gate` → defer to provider. Add checks for missing sensor data: if `get_current_kcs()` returns None (no radiation data), defer haze to provider. If dewpoint/humidity smoothed values are None, defer fog/mist to provider. Same deferral code path — just additional None checks on the data the modules already read, not a separate capability system.
- In `haze_condition.py`: `set_baseline()` signature unchanged. Update module docstring. Remove "Phase 6" references. When humidity is None, skip f(RH) correction (use uncorrected Kcs deficit).
- Wire `_has_radiation` flag into `auto_calibration` to gate bootstrap and sample collection (no radiation → skip, re-evaluate on each packet).
- Accept: No pyranometer → provider haze 24/7 + calibration skipped. No hygrometer → provider fog/mist + no f(RH). Both present → existing behavior unchanged. No operator-visible messaging about sensors — just silent failover.

**T4.2 — Update settings.py ConditionsSettings**
- Owner: `clearskies-api-dev`
- Remove `calibration_percentile`, `calibration_window_days`, `calibration_min_samples` from class (attributes, __init__, validate). Keep `haze_detection`, `haze_aqi_provider`, `gamma`. Update docstring.
- Old api.conf files with removed keys won't crash — configobj returns them but __init__ never reads them.
- Accept: `ConditionsSettings` has no calibration params. Loads cleanly with old configs.

**T4.3 — Add API endpoints for calibration state and reset**
- Owner: `clearskies-api-dev`
- New in `endpoints/setup.py`:
  - `GET /setup/calibration-state` — returns `auto_calibration.get_calibration_state()`. Auth: proxy secret (same as `/setup/current-config`).
  - `POST /setup/calibration-reset` — calls `auto_calibration.reset()`, deletes calibration.json, triggers re-bootstrap in background. Auth: proxy secret. Returns `{"success": true, "message": "Calibration reset. Re-bootstrap started."}`.
- These endpoints are needed because in cross-host topology the admin UI runs on weather-dev but calibration data is on weewx. The admin cannot read calibration.json directly.
- Accept: Both endpoints respond. State endpoint returns per-month data. Reset endpoint clears data.

**QC:** Coordinator curls both endpoints on weewx. Verifies state response has `months_calibrated` and `per_month`. Verifies reset clears and re-bootstraps.

---

## Phase 5 — Admin UI Rework (Stack Repo)

**T5.1 — Rework haze_calibration.html**
- Owner: `clearskies-api-dev`
- Remove: calibration parameter form (percentile, window, min_samples inputs). Remove CLI bootstrap aside.
- Add: 12-month status grid (month name, sample count, baseline Kcs, status dot: green/amber/gray). Overall "N of 12 months calibrated." Flat fallback baseline display. Drift warning banner. Station type change warning. "Reset Calibration" button with confirmation.
- Keep: haze_detection toggle, gamma input, Save/Cancel.
- Accept: No parameter inputs. 12-month grid renders. Reset button present.

**T5.2 — Rework admin/routes.py haze calibration routes**
- Owner: `clearskies-api-dev`
- `_read_calibration_state()` → replaced: call API endpoint `GET /setup/calibration-state` via ApiClient (not local file read). Handle connection failure gracefully.
- POST handler: only saves `haze_detection` and `gamma`.
- New route `POST /admin/haze-calibration/reset`: calls API `POST /setup/calibration-reset` via ApiClient. Returns success/failure fragment.
- Remove `_HAZE_DEFAULTS` entries for removed params.
- Accept: No local calibration.json reads. POST saves only 2 fields. Reset calls API.

**T5.3 — Update landing.html haze card**
- Owner: `clearskies-api-dev`
- Replace "Samples (90-day)" with "Months calibrated: N/12." Keep detection toggle and baseline display.
- Accept: No "90-day" references.

**QC:** Coordinator loads admin page, verifies 12-month grid renders, no parameter inputs visible, reset button present.

---

## Phase 6 — Testing

**T6.1 — Rewrite test_auto_calibration.py**
- Owner: `clearskies-test-author`
- Complete rewrite for monthly model:
  - Monthly baseline computation (empty, below min, sufficient, wrong month excluded, 3-year pruning)
  - State transitions (no-data → bootstrapping → partial → fully-calibrated)
  - Per-month progressive activation
  - v1→v2 migration in load_persisted()
  - v2 persistence round-trip
  - Drift detection (divergent samples trigger warning, normal samples don't)
  - Station type tracking (change detection, None handling)
  - Flat fallback when current month has no baseline
  - Timezone-aware month binning
- Remove tests for `configure()`, `_percentile_midpoint()`, flat `compute_baseline()`.
- Accept: All pass. No references to removed functions.

**T6.2 — Verify test_haze_condition.py still passes**
- Owner: `clearskies-test-author`
- Minimal changes — `set_baseline()` interface unchanged. Remove any references to `configure()`.
- Accept: All existing tests pass.

**QC:** Coordinator runs full test suite on weewx. Confirms zero introduced failures.

---

## Phase 7 — Audit + QA

**T7.1 — Code audit**
- Owner: `clearskies-auditor`
- Checklist: no `_samples` references remain, no `configure()` calls remain, removed config keys gone from all files, v1 migration correct (timezone-aware), drift threshold reasonable, persistence atomicity preserved, no circular imports, `reset()` clears all state, thread safety (bootstrap before packet_tap).
- Accept: Zero blocking findings.

**T7.2 — Doc-code sync audit**
- Owner: `clearskies-auditor`
- Every config key in docs exists in code and vice versa. State names match. Endpoint inventory matches. Admin UI description matches template.
- Accept: Zero mismatches.

**QC:** Coordinator reviews findings. Blocking findings → fix dispatch. Non-blocking → documented for follow-up.

---

## Phase 8 — Deploy + Verify

**T8.1 — Deploy API (weewx)**
- Push API repo, pull on weewx, restart service.
- Verify: startup log shows v1 migration (if existing data), station type check, auto-bootstrap start.
- Verify: `GET /api/v1/current` still returns weatherText (no regression).

**T8.2 — Deploy Admin (weather-dev)**
- Push stack repo, pull on weather-dev, reinstall pip package, restart config UI.
- Verify: admin haze calibration page renders 12-month grid, no parameter form, reset button works.

**T8.3 — End-to-end**
- Verify auto-bootstrap populated monthly bins (check `/setup/calibration-state` via curl).
- Verify admin shows correct per-month counts.
- Verify haze_detection toggle works from admin.
- Run full pytest suite — confirm baseline count maintained.

---

## Phase 9 — Smart Sensor Selection + Operator Override

**Origin:** Phase 8 deploy revealed bootstrap selected South Long Beach (sensor 1502, port-adjacent, 16 km away) which produced 0 qualifying clean-sky samples. The sensor selection is too naive — picks nearest reference monitor without checking data quality, doesn't try alternatives, gives no operator visibility or control.

**Design decisions (settled in conversation 2026-06-22):**

1. **Try-until-it-works loop.** Automatic mode tries reference sensors nearest-first. If a sensor produces 0 qualifying samples, log the rejection reason and move to the next candidate. Stop at first success or exhaust the list.
2. **Check data age before fetching.** Use OpenAQ `datetimeFirst`/`datetimeLast` from the `/locations` response to skip sensors with < 12 months of history. No extra API call needed — the data is already in the locations response.
3. **Reference sensors only in automatic mode and dropdown.** AQMD/reference-grade stations are the default pool. Non-reference (PurpleAir, private) are not listed in the dropdown — data quality is too variable.
4. **Three tiers of operator control:**
   - **Automatic** (default): try reference stations nearest-first, reject-and-advance
   - **Dropdown override**: pick from list of nearby reference stations in admin UI
   - **Manual ID entry**: type any OpenAQ sensor ID (including non-reference). Escape hatch for operators who know their local sensor network. We don't endorse low-cost sensors by listing them, but we don't block an informed operator.
5. **Show what was selected.** Admin haze calibration page displays the active sensor: name, distance from station, coordinates, and sensor type (reference vs. non-reference).
6. **Persist selection in calibration.json.** The selected sensor ID, name, distance, and coordinates are stored alongside the calibration data so the admin UI can display them without re-querying OpenAQ.
7. **New config key: `openaq_sensor_id`.** Optional in `[conditions]`. When set, bypass automatic search entirely. Accepts any valid OpenAQ sensor ID.
8. **New API endpoint: `GET /setup/openaq-sensors`.** Returns list of nearby reference PM2.5 sensors (name, distance, coordinates, data date range). Used by admin UI dropdown. Auth: proxy secret.

### T9.1 — Rework sensor selection in `openaq_client.py`

- Owner: `clearskies-api-dev`
- Rename `find_nearest_pm25_sensor()` → `find_best_pm25_sensor()`. Returns a **ranked list** of candidate sensors, not just one.
- Each candidate: `(sensor_id, lat, lon, name, distance_km, datetime_first, datetime_last)`.
- Filter: `isMonitor=true` on the `/locations` query (reference/regulatory only). PM2.5 parameter. Data spanning >= 12 months (`datetimeLast - datetimeFirst >= 365 days`).
- Sort by distance ascending.
- New `get_nearby_sensors(lat, lon) -> list[dict]`: returns all reference PM2.5 sensors within range, formatted for the admin UI dropdown. Includes name, distance, coordinates, data date range, sensor ID.
- Keep `fetch_historical_pm25()` unchanged — it works per-sensor.
- Accept: `find_best_pm25_sensor()` returns a list. Sensors with < 12 months of data are excluded. Non-reference sensors are excluded.

### T9.2 — Rework bootstrap flow in `__main__.py`

- Owner: `clearskies-api-dev`
- **Override path:** If `settings.conditions.openaq_sensor_id` is set, use that sensor ID directly. Skip the candidate search. Log: "Using operator-specified OpenAQ sensor {id}."
- **Automatic path:** Call `find_best_pm25_sensor()` to get ranked candidates. Loop through each:
  1. Fetch PM data for the candidate.
  2. Run `run_bootstrap()` with that data.
  3. If `clean_sky_samples > 0`: success — log selected sensor details, persist sensor info in calibration.json, break.
  4. If `clean_sky_samples == 0`: log rejection reason with counters (e.g., "Sensor 1502 'South Long Beach' (16.2 km): 3000 records, 2847 PM2.5 >= 12, 153 no archive match, 0 qualifying — skipping"), continue to next candidate.
- If all candidates exhausted: log "No suitable OpenAQ sensor found within {radius} km. Calibration will proceed organically from real-time observations." No error — this is a valid outcome.
- Persist selected sensor info in calibration.json v2 (new fields: `openaq_sensor_id`, `openaq_sensor_name`, `openaq_sensor_distance_km`, `openaq_sensor_lat`, `openaq_sensor_lon`).
- Accept: Bootstrap tries multiple sensors. Rejection reasons logged with counters. Override respected. Sensor info persisted.

### T9.3 — Add `openaq_sensor_id` to `ConditionsSettings`

- Owner: `clearskies-api-dev`
- New optional key in `ConditionsSettings.__init__`: `self.openaq_sensor_id = section.get("openaq_sensor_id") or None`. Type: `int | None`. No validation beyond int parse — any OpenAQ sensor ID is accepted (operator's responsibility for manual IDs).
- Accept: Old api.conf without the key loads cleanly. Key round-trips through admin save.

### T9.4 — Add `GET /setup/openaq-sensors` endpoint

- Owner: `clearskies-api-dev`
- New endpoint in `endpoints/setup.py`.
- Calls `openaq_client.get_nearby_sensors(station_lat, station_lon)`.
- Returns: `{"sensors": [{"sensor_id": 1502, "name": "South Long Beach", "distance_km": 16.2, "lat": 33.79, "lon": -118.18, "datetime_first": "2020-01-15", "datetime_last": "2026-06-22"}, ...]}`.
- Auth: proxy secret.
- Accept: Endpoint returns sensor list. Empty list if no monitors nearby.

### T9.5 — Admin UI: sensor display + override

- Owner: `clearskies-api-dev`
- **haze_calibration.html changes:**
  - New "Bootstrap Sensor" section below the calibration status grid.
  - Displays current sensor: name, distance, coordinates, type. Reads from calibration state (persisted in calibration.json).
  - Dropdown: populated via HTMX call to a route that calls `GET /setup/openaq-sensors`. Shows reference sensors only.
  - "Enter Station ID" option at the bottom of the dropdown — reveals a text input for manual ID entry.
  - Save writes `openaq_sensor_id` to api.conf `[conditions]` via the existing POST handler.
  - "Clear override" button resets to automatic mode.
- **routes.py changes:**
  - New route `GET /admin/openaq-sensors-fragment`: calls API `/setup/openaq-sensors`, returns HTMX fragment with dropdown options.
  - POST handler saves `openaq_sensor_id` alongside `haze_detection` and `gamma`.
- Accept: Admin page shows current sensor info. Dropdown lists reference stations. Manual ID entry works. Override persists across restarts.

### T9.6 — Update calibration state for sensor info

- Owner: `clearskies-api-dev`
- Extend `get_calibration_state()` return dict with `openaq_sensor` sub-dict: `{"sensor_id": int, "name": str, "distance_km": float, "lat": float, "lon": float}` or `null` if no sensor used yet.
- Extend calibration.json v2 with the sensor fields (backward compatible — old files just won't have them).
- `landing.html` haze card: show sensor name + distance if available.
- Accept: Calibration state includes sensor info. Old calibration.json loads without sensor fields (null).

### T9.7 — Docs update

- Owner: `clearskies-docs-author`
- **API-MANUAL.md §8:** Add sensor selection algorithm (try-until-it-works, data age check, rejection logging). Document `openaq_sensor_id` config key. Document `GET /setup/openaq-sensors` endpoint.
- **OPERATIONS-MANUAL.md:** Add `openaq_sensor_id` to `[conditions]` config table. Update admin haze calibration section with sensor display and override UI.
- **ARCHITECTURE.md:** Add `GET /setup/openaq-sensors` to endpoint table.
- **ADR-068:** Amend with sensor selection section (Proposed → user approves → Accepted).
- Accept: No references to single-shot sensor selection. New config key documented. New endpoint in inventory.

### T9.8 — Testing

- Owner: `clearskies-test-author`
- New tests in `tests/test_openaq_client.py` (or extend existing):
  - `find_best_pm25_sensor` returns ranked list
  - Sensors with < 12 months history excluded
  - Non-reference sensors excluded from automatic results
  - `get_nearby_sensors` returns dropdown-formatted data
- Extend `tests/test_auto_calibration.py`:
  - Sensor info persisted in calibration.json
  - `get_calibration_state()` includes `openaq_sensor` field
- Accept: All pass. Zero introduced failures in full suite.

### T9.9 — Deploy + Verify

- Deploy API to weewx, stack to weather-dev.
- Verify: bootstrap tries multiple sensors (check startup log for rejection messages).
- Verify: admin haze calibration shows sensor info and dropdown.
- Verify: manual sensor ID entry works.
- Verify: full pytest baseline maintained.

**QC gates (coordinator):**
- After T9.1-T9.2: grep for `find_nearest_pm25_sensor` — zero hits (renamed). Verify bootstrap log shows multi-sensor attempt.
- After T9.5: load admin page, verify sensor display and dropdown render.
- After T9.8: full suite run, zero introduced failures.

---

## Verification

After all phases:
- ADR-068 amended and re-accepted (monthly normals + sensor selection)
- 3 manuals updated (API-MANUAL, OPS-MANUAL, ARCHITECTURE)
- auto_calibration.py uses monthly-normals model with 3-year window
- Bootstrap runs automatically at startup (no CLI, no admin button)
- Bootstrap sensor selection: try-until-it-works with rejection logging, data age check (>= 12 months), reference sensors only in automatic mode
- Operator sensor override: dropdown of reference stations + manual ID entry for non-reference escape hatch
- Admin shows 12-month calibration grid, reset button, drift warnings, active sensor info
- Operator-tunable: haze_detection, gamma, haze_aqi_provider, openaq_sensor_id (optional override)
- Cross-host calibration state works via API endpoints
- v1→v2 migration preserves existing data
- Hardware change detection (reset + drift + station_type)
- Graceful sensor failover (missing pyranometer/hygrometer → provider deferral)
- All tests pass, zero introduced failures

---

## Key Files

### API repo (`repos/weewx-clearskies-api`)
- `weewx_clearskies_api/sse/auto_calibration.py` — major rewrite (core model) + sensor info in state/persistence
- `weewx_clearskies_api/bootstrap/openaq_client.py` — smart sensor selection (multi-candidate, data age check, nearby list)
- `weewx_clearskies_api/bootstrap/importer.py` — monthly bins, remove --years
- `weewx_clearskies_api/__main__.py` — auto-bootstrap with try-until-it-works loop, sensor override
- `weewx_clearskies_api/config/settings.py` — remove calibration params, add openaq_sensor_id
- `weewx_clearskies_api/sse/haze_condition.py` — docstring update, f(RH) None handling
- `weewx_clearskies_api/sse/enrichment/weather_text.py` — extend deferral for missing sensors
- `weewx_clearskies_api/sse/enrichment/provider_weather_feed.py` — extend deferral
- `weewx_clearskies_api/endpoints/setup.py` — calibration-state, calibration-reset, openaq-sensors endpoints
- `tests/test_auto_calibration.py` — complete rewrite + sensor info tests
- `tests/test_openaq_client.py` — multi-candidate, data age filter, nearby sensors tests
- `tests/test_haze_condition.py` — minimal updates

### Stack repo (`repos/weewx-clearskies-stack`)
- `weewx_clearskies_config/templates/admin/haze_calibration.html` — rework UI + sensor display/override
- `weewx_clearskies_config/templates/admin/landing.html` — update haze card + sensor info
- `weewx_clearskies_config/admin/routes.py` — API-based state reads, reset route, sensor dropdown fragment

### Meta repo (root)
- `docs/manuals/API-MANUAL.md` — section 8 auto-calibration rewrite + sensor selection
- `docs/manuals/OPERATIONS-MANUAL.md` — conditions config table, admin section, bootstrap, sensor override
- `docs/ARCHITECTURE.md` — auto_calibration description, new endpoints
- `docs/archive/decisions/ADR-068-*` — amend for monthly normals + sensor selection
