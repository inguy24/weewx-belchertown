# Almanac Planet & Meteor Timing Bug Fix Plan (F2-PLANETS)

**Status:** COMPLETE — All three timing bugs fixed and deployed. The temporal consistency plan (ADR-075) subsequently re-introduced 2 of the 3 bugs, which have since been corrected. Archived 2026-06-27.  
**Created:** 2026-06-23  
**Component:** API (`weewx-clearskies-api`)

---

## Context

The almanac's `compute_planets()` function drops planets that are genuinely visible. TimeAndDate.com shows 5+ planets for the station (America/Los_Angeles, lat 33.66, lon -117.98) but the API returns only 3. The root cause is three timing bugs that were previously found and fixed in the sun/moon code (the "F2 fix") but never corrected in the planet and meteor shower functions — they were written separately.

The fix is computation-only. The API response shape does not change. No dashboard changes are needed. The enrichment layer (`planet_viewing.py`) and endpoint handler (`endpoints/almanac.py`) consume the corrected data without modification.

---

## 0. Orientation — Execution Context

**Read before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — security constraints, build verification
- `rules/clearskies-process.md` — agent orchestration, scope binding, QC gates

**Repo:** `repos/weewx-clearskies-api` — Branch: `main`. Lint: `ruff check`, `mypy`.

**Deploy:** `ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && git pull --ff-only && sudo systemctl restart weewx-clearskies-api"` (takes ~2 min to warm cache)

**Station facts:**
- Timezone: `America/Los_Angeles` (PDT = UTC-7 in summer, PST = UTC-8 in winter)
- Location: lat=33.65683, lon=-117.98267 (Orange County, CA)
- System TZ on weewx host: `PST8PDT` (confirmed via `timedatectl`)

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

---

## 1. Bug Inventory

| # | Bug | Location | What's wrong | Impact |
|---|-----|----------|-------------|--------|
| **B1** | `midnight_tt` is local noon | `almanac.py` L977, L1351 | `(t0.tt + t1.tt) / 2.0` is the midpoint of midnight-to-midnight = **noon**. Named `midnight_tt` and used as midnight throughout. | Classification comparisons at L1076/1085/1090/1093 use noon. Planets fail all conditions → dropped via `continue` L1098. Meteor radiant altitude computed at noon → wrong viewing quality. |
| **B2** | UTC reference times | `almanac.py` L989-990 | `ts.utc(..., 21, 0, 0)` creates 21:00 UTC = **2:00 PM PDT**. `ts.utc(..., 5, 0, 0)` creates 05:00 UTC = **10:00 PM PDT previous evening**. | Altitude/direction reported for evening planets is for mid-afternoon. Morning reference is actually late evening. |
| **B3** | Calendar-day sunrise for tonight | `almanac.py` L958-974 | `sunrise_tt` found in midnight-to-midnight window is THIS MORNING's 5:30 AM, not tomorrow's sunrise that ends tonight's dark period. | `above_at_sunrise` checks an 18-hour-stale sunrise. Combined with B1, planets visible through pre-dawn get dropped. |
| **B3b** | Cache warmer UTC date | `cache_warmer.py` L311, L387 | `_warm_planets()` uses `datetime.now(timezone.utc).date()` instead of station-local date. `_warm_meteor_showers()` uses `date.today()`. | Near UTC midnight, cache key diverges from endpoint date → cache miss (performance, not correctness — endpoint computes fresh with the right date). |

### Files affected

| File | Changes |
|------|---------|
| `weewx_clearskies_api/services/almanac.py` | New helper, fix `compute_planets()`, fix `compute_meteor_showers()` |
| `weewx_clearskies_api/services/cache_warmer.py` | Station-local dates for planets + meteor showers |
| `tests/test_almanac_unit.py` | New test classes for planet/meteor timezone regression |

### Files NOT affected (confirmed)

| File | Why unchanged |
|------|--------------|
| `endpoints/almanac.py` | Already passes `station_tz` correctly; response shape unchanged |
| `sse/enrichment/planet_viewing.py` | Consumes data from `compute_planets()`, no own time calculations |
| Dashboard (all files) | Renders what API sends; no time calculations |
| `_station_local_window()` | Already correct (F2 fix); reused as-is |
| `_compute_sun_for_date()` / `_compute_moon_for_date()` | Already correct (F2 fix) |
| `compute_lunar_eclipses()` | Date-only computation, no altitude/visibility |
| Solar eclipses | External AstronomyAPI.com, no local computation |

---

## 2. Implementation Phases

### PHASE 0 — Shared Helper

**T0.1 — Add `_local_time_to_skyfield()` helper**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/services/almanac.py`, insert after `_station_local_window()` (after L375)
- Do: Add a function that converts a station-local time (date + hour + minute + station_tz) to a Skyfield Time object. Pattern: build timezone-aware `datetime` via `ZoneInfo(station_tz)` → `.astimezone(UTC)` → unpack into `ts.utc()`. Same conversion pattern already used by `_station_local_window()` at L351-374. Handle `ZoneInfoNotFoundError` by falling back to UTC (same pattern as L353-354).
- Signature: `_local_time_to_skyfield(ts: object, d: date, hour: int, minute: int, station_tz: str) -> object`
- Accept: Function exists with docstring. For `d=2024-06-21, hour=21, minute=0, station_tz="America/Los_Angeles"`, result corresponds to 2024-06-22T04:00:00Z. For `station_tz="UTC"`, equivalent to `ts.utc(d.year, d.month, d.day, hour, minute, 0)`.

**QC (Opus):** Existing `pytest tests/test_almanac_unit.py` passes with no regressions. No functional changes to any compute function yet.

---

### PHASE 1 — Fix `compute_planets()` (Bugs B1 + B2 + B3)

**T1.1 — Fix B1: Real midnight**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `almanac.py`, function `compute_planets()` starting L917
- Do: Replace L977 `midnight_tt = (t0.tt + t1.tt) / 2.0` with `midnight_tt = t1.tt`. Rationale: `t1` from `_station_local_window()` IS local midnight of the next day (L358-374: `local_next_midnight = datetime(next_day.year, next_day.month, next_day.day, 0, 0, 0, tzinfo=zi)`). For 2024-06-21 in PDT, `t1` = 2024-06-22T07:00:00Z = midnight PDT. The old midpoint gave 2024-06-21T19:00:00Z = noon PDT.
- L991 `t_midnight_chk = ts.tt_jd(midnight_tt)` stays as-is — now holds the correct value.
- Update comment at L976 from "Midnight TT (midpoint of the window)" to "Midnight TT — t1 of station-local window = start of next local day."
- Accept: `midnight_tt` for PDT station on Jun 21 corresponds to ~07:00Z Jun 22 (midnight PDT), not ~19:00Z Jun 21 (noon PDT).

**T1.2 — Fix B3: Get tomorrow's sunrise**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `almanac.py`, function `compute_planets()`
- Do: After the existing sun event loop (after L974), add code to find the sunrise that ENDS tonight's dark period:
  1. Build a second window for the next calendar day: `next_day = date_val + timedelta(days=1)`, `t0_next, t1_next = _station_local_window(ts, next_day, station_tz)`
  2. Search for the first rising event in that window: `almanac.find_discrete(t0_next, t1_next, f_sun)` → `next_sunrise_tt`
  3. Build `t_next_sunrise_chk = ts.tt_jd(next_sunrise_tt)` for altitude checks
- Update the classification checks (L1074-1076):
  - Replace `above_at_sunrise` with `above_at_next_sunrise` using `t_next_sunrise_chk`
  - Keep the old `sunrise_tt` / `sunrise_iso` for the response data (planet rise/set times still come from today's window)
- Update the classification block (L1080-1098):
  - L1080: `if above_at_sunset and above_at_next_sunrise:` → allNight
  - L1088: `elif above_at_next_sunrise or (... planet_rise_tt < next_sunrise_tt ...):` → morning
  - Fallback at L1093 (`above_at_midnight`) stays — now checks actual midnight
- Update the polar guard (L1066-1068): add `and next_sunrise_tt is None` to the condition. If there's no sunrise in either window, it's polar day → skip.
- Edge case: if `next_sunrise_tt` is None but `sunrise_tt` exists (polar twilight), fall back to `sunrise_tt`.
- Accept: For a PDT station on Jun 21, `next_sunrise_tt` corresponds to ~12:14Z Jun 22 (5:14 AM PDT Jun 22). `above_at_next_sunrise` checks tomorrow's sunrise, not this morning's.

**T1.3 — Fix B2: Station-local reference times**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `almanac.py`, function `compute_planets()`
- Do: Replace L989-990:
  - Old: `t_9pm = ts.utc(date_val.year, date_val.month, date_val.day, 21, 0, 0)`
  - New: `t_9pm = _local_time_to_skyfield(ts, date_val, 21, 0, station_tz)`
  - Old: `t_5am = ts.utc(date_val.year, date_val.month, date_val.day, 5, 0, 0)`
  - New: `t_5am = _local_time_to_skyfield(ts, date_val + timedelta(days=1), 5, 0, station_tz)` — 5 AM belongs to the NEXT calendar day (tomorrow morning)
- Also fix L980 `t_noon`: replace with `_local_time_to_skyfield(ts, date_val, 12, 0, station_tz)`. Lower priority (magnitude/RA/Dec vary slowly) but trivial with the helper.
- Update comments at L985-988 to remove the incorrect "(21:00)" / "(05:00)" UTC annotations.
- Accept: For PDT station on Jun 21: `t_9pm` = 2024-06-22T04:00Z (9 PM PDT Jun 21). `t_5am` = 2024-06-22T12:00Z (5 AM PDT Jun 22). Previously `t_9pm` was 2024-06-21T21:00Z (2 PM PDT — mid-afternoon).

**T1.4 — Verify response shape unchanged**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Confirm the `entry` dict built at L1102-1115 is unchanged. The fix changes classification (which list) and altitude/direction values, NOT dict keys or types. The endpoint at `endpoints/almanac.py` L440-456 and L473-489 reads only: `name`, `altitude`, `direction`, `rise`, `set`, `constellation`, `magnitude`, `transitTime`, `rightAscension`, `declination`, `elongation`. `planet_viewing.py` enrichment adds fields to the same dict — no structural change.
- Accept: No key additions, removals, or type changes in the response dict.

**QC (Opus) after Phase 1:**
- [ ] `pytest tests/test_almanac_unit.py` — all existing tests pass
- [ ] Manual spot-check: call `compute_planets(date(2026, 6, 23), 33.66, -117.98, 30.0, "America/Los_Angeles")` and count planets across all three categories. Expect 5+ (compare with TimeAndDate.com for Jun 23 2026).
- [ ] Verify no planet has negative altitude in its classified category (was possible when reference time was mid-afternoon).

---

### PHASE 2 — Fix `compute_meteor_showers()` (Bug B1)

**T2.1 — Fix B1: Real midnight for radiant altitude**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `almanac.py`, function `compute_meteor_showers()` starting L1280
- Do: Replace L1351 `midnight_tt = (t0.tt + t1.tt) / 2.0` with `midnight_tt = t1.tt`. Identical fix to T1.1 — `t1` is local midnight.
- Update comment at L1351.
- Accept: Perseids (peak Aug 12) radiant altitude for a northern mid-latitude station is 50-70° at midnight (constellation Perseus is high). Previously computed at noon, the radiant was likely below the horizon or very low.

**T2.2 — Fix `t_noon` for moon illumination**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `almanac.py`, function `compute_meteor_showers()`
- Do: Replace L1371 `t_noon = ts.utc(peak_date.year, peak_date.month, peak_date.day, 12, 0, 0)` with `t_noon = _local_time_to_skyfield(ts, peak_date, 12, 0, station_tz)`.
- Accept: Moon illumination is computed at local noon instead of UTC noon. Low impact (illumination varies slowly) but correct.

**QC (Opus) after Phase 2:**
- [ ] `pytest tests/test_almanac_unit.py` + `pytest tests/test_visibility.py` + `pytest tests/test_meteor_catalog.py` — all pass
- [ ] Manual spot-check: call `compute_meteor_showers(33.66, -117.98, 30.0, "America/Los_Angeles", from_date=date(2026, 8, 10), to_date=date(2026, 8, 14))` — Perseids `radiantAltitudeDeg` > 30, `viewingQuality` ≠ "Not Visible"

---

### PHASE 3 — Fix `cache_warmer.py` (Bug B3b)

**T3.1 — Fix `_warm_planets()` date**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/services/cache_warmer.py`
- Do: Replace L311 `today = datetime.now(timezone.utc).date()` with the station-local pattern already used by `_warm_almanac_snapshot()` at L258-264:
  ```
  station_tz = self._station["station_tz"]
  try:
      zi = ZoneInfo(station_tz)
      today = datetime.now(tz=zi).date()
  except (ZoneInfoNotFoundError, KeyError):
      today = datetime.now(timezone.utc).date()
  ```
  Move `station_tz` assignment (currently L315) above the date computation.
- Accept: Cache key for planets uses station-local date, matching the endpoint's `_today_in_station_tz()`.

**T3.2 — Fix `_warm_meteor_showers()` date**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `cache_warmer.py`
- Do: Replace L387 `today = date.today()` with same station-local pattern. The `station_tz` is already read at L392.
- Accept: Cache key for meteor showers uses station-local date.

**T3.3 — Consolidate ZoneInfo import**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `cache_warmer.py`
- Do: If `ZoneInfo` / `ZoneInfoNotFoundError` are not already top-level imports, add them. `_warm_almanac_snapshot` currently imports locally at L254 — promote to top-level to avoid duplication across three warmers.
- Accept: No duplicate imports. All three warmers use the same pattern.

**QC (Opus) after Phase 3:**
- [ ] `_warm_almanac_snapshot` NOT changed (already correct)
- [ ] Existing test suite passes
- [ ] Cache key format unchanged (still `warmer:almanac:planets:{YYYY-MM-DD}`)

---

### PHASE 4 — Tests

**T4.1 — Test class `TestLocalTimeToSkyfield`**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_almanac_unit.py`
- Uses: existing `wired_ephemeris` fixture, `skip_if_no_skyfield` marker
- Test cases:
  1. `test_9pm_pdt_is_next_day_utc` — `_local_time_to_skyfield(ts, date(2024,6,21), 21, 0, "America/Los_Angeles")` ≈ 2024-06-22T04:00Z (±1 sec)
  2. `test_5am_pdt_is_same_day_utc` — `_local_time_to_skyfield(ts, date(2024,6,22), 5, 0, "America/Los_Angeles")` ≈ 2024-06-22T12:00Z
  3. `test_utc_passthrough` — `_local_time_to_skyfield(ts, date(2024,6,21), 21, 0, "UTC")` ≈ 2024-06-21T21:00Z
  4. `test_invalid_tz_falls_back_to_utc` — invalid timezone string falls back to UTC behavior

**T4.2 — Test class `TestPlanetClassificationTimezone`**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_almanac_unit.py`
- Test cases (the critical regression tests that would have caught this bug):
  1. `test_no_planet_dropped_pdt_summer` — `compute_planets(date(2024,6,21), 33.66, -117.98, 30.0, "America/Los_Angeles")` returns ≥5 planets across evening+morning+allNight. Primary symptom regression test.
  2. `test_no_planet_dropped_edt_summer` — Same for `42.375, -72.519, "America/New_York"` (existing test fixture station). Returns ≥5 planets.
  3. `test_all_seven_classified_or_conjunction` — For each of the 7 planet names (Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune), assert it appears in evening/morning/allNight OR has elongation < 15° (solar conjunction). No silent drops.
  4. `test_evening_planet_altitude_positive` — Every planet in the "evening" list has `altitude > 0`. With the old bug, reference time was UTC afternoon, so some had negative altitude.
  5. `test_utc_station_no_regression` — `compute_planets(..., station_tz="UTC")` still works correctly. Planet count ≥5.

**T4.3 — Test class `TestMeteorRadiantMidnight`**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_almanac_unit.py`
- Test cases:
  1. `test_perseids_radiant_high_at_midnight` — `compute_meteor_showers(42.375, -72.519, 0.0, "America/New_York", from_date=date(2024,8,10), to_date=date(2024,8,14))` returns Perseids with `radiantAltitudeDeg > 30`. Perseids radiant (in Perseus) is high at midnight in August for mid-northern latitudes. At noon it would be low or below horizon.
  2. `test_perseids_not_not_visible` — Same call, Perseids `viewingQuality` ≠ "Not Visible".
  3. `test_geminids_radiant_reasonable` — Similar for Geminids (Dec 14): `radiantAltitudeDeg > 20` at midnight.

**T4.4 — Test class `TestPlanetMidnightIdentity`**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_almanac_unit.py`
- Test cases:
  1. `test_t1_is_midnight_not_noon_pdt` — Call `_station_local_window(ts, date(2024,6,21), "America/Los_Angeles")`. Verify `t1.utc_datetime().hour == 7` (midnight PDT = 07:00Z). The old midpoint gave `(t0.tt + t1.tt)/2.0` → ~19:00Z = noon PDT.
  2. `test_t1_is_midnight_not_noon_edt` — Same for "America/New_York": `t1.utc_datetime().hour == 4` (midnight EDT = 04:00Z).

**QC (Opus) after Phase 4:**
- [ ] All new tests pass with the fixes applied
- [ ] Spot-check: temporarily revert `midnight_tt` to `(t0.tt + t1.tt) / 2.0` and confirm `test_no_planet_dropped_pdt_summer` FAILS (proves the test detects the bug)
- [ ] All existing tests continue to pass
- [ ] New test count: ≥14 test functions added

---

### PHASE 5 — Deploy + Verify

**T5.1 — Push to GitHub and deploy**
- Owner: Coordinator (Opus) — only after user authorization to push
- Do: Standard deploy flow: push to GitHub → `git pull --ff-only` on weewx → `sudo systemctl restart weewx-clearskies-api` → wait 2 min for cache warm.

**T5.2 — Production verification against TimeAndDate.com**
- Owner: Coordinator (Opus)
- Do: After deploy, `curl https://weewx.shaneburkhardt.com:8765/api/v1/almanac/planets` and verify:
  1. Planet count across all three categories matches TimeAndDate.com within ±1
  2. Evening planets have altitude > 0 and compass direction consistent with western sky
  3. Morning planets have altitude > 0 and compass direction consistent with eastern sky
  4. No planet with elongation > 15° is missing from all categories
- Also verify meteor showers: `curl .../api/v1/almanac/meteor-showers` — check that upcoming showers have plausible viewing quality ratings (no shower with radiant above the horizon at midnight rated "Not Visible").

**T5.3 — Doc-code sync check**
- Owner: Coordinator (Opus)
- Do: The fix doesn't change the API response shape or any documented behavior. Verify ARCHITECTURE.md's almanac endpoint descriptions are still accurate. The only doc change needed: update `rules/coding.md` §1 ("Weather data is safety-critical") to add a note about the planet/meteor timing bugs as a historical example under the existing "Why (2026-06-23)" note if not already covered.
- Accept: No manual updates needed (behavior is corrected to match what was already documented as intended).

**Final QC (Opus):**
- [ ] API returns 5+ planets for the station on current date
- [ ] Planet count matches TimeAndDate.com within ±1
- [ ] Meteor shower ratings are plausible
- [ ] All tests pass on weewx: `ssh weewx "cd /home/ubuntu/repos/weewx-clearskies-api && .venv/bin/pytest tests/test_almanac_unit.py -v"`
- [ ] Dashboard almanac page renders correctly with the new data

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC (Opus) | QC Timing |
|-------|------|-------|-------|-----------|-----------|
| 0 | T0.1 Helper | `clearskies-api-dev` | Sonnet | Existing tests pass | After Phase 0 |
| 1 | T1.1-T1.4 Planet fix | `clearskies-api-dev` | Sonnet | Planet count + altitude check | After Phase 1 |
| 2 | T2.1-T2.2 Meteor fix | `clearskies-api-dev` | Sonnet | Radiant altitude check | After Phase 2 |
| 3 | T3.1-T3.3 Cache warmer | `clearskies-api-dev` | Sonnet | Pattern match + existing tests | After Phase 3 |
| 4 | T4.1-T4.4 Tests | `clearskies-test-author` | Sonnet | New tests pass + revert-verify | After Phase 4 |
| 5 | T5.1-T5.3 Deploy | Coordinator | Opus | TimeAndDate comparison + doc sync | After deploy |

**Sequencing:**
- Phase 0 → Phase 1 → Phase 2 → Phase 3 (all sequential — each builds on the helper)
- Phase 4 (tests) depends on Phases 0-3 being complete
- Phase 5 (deploy) depends on Phase 4 QC passing

**Phases 0-3 can be a single agent dispatch** since they're all in the same file(s) with clear scope. The coordinator should still QC after each phase's work before the agent proceeds.

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- `ruff check weewx_clearskies_api/services/almanac.py` — no new violations
- `mypy weewx_clearskies_api/services/almanac.py` — no new errors
- `pytest tests/test_almanac_unit.py` — existing tests pass

### Gate 2 — Correctness (Phase 1)
- `compute_planets()` for PDT station on Jun 21 2024 returns ≥5 planets
- No planet in any category has negative altitude
- `midnight_tt` value for PDT station corresponds to ~07:00Z (midnight PDT), not ~19:00Z (noon PDT)
- `t_9pm` corresponds to ~04:00Z next day (9 PM PDT), not 21:00Z (2 PM PDT)

### Gate 3 — Meteor Correctness (Phase 2)
- Perseids radiant altitude at midnight > 30° for mid-northern latitude
- No shower with radiant above horizon rated "Not Visible"

### Gate 4 — Test Coverage (Phase 4)
- ≥14 new test functions
- All new tests pass
- Revert-verify: temporarily reverting `midnight_tt` causes planet classification test to fail

### Gate 5 — Production (Phase 5)
- Planet count matches TimeAndDate.com ±1
- Meteor shower ratings plausible
- Dashboard renders correctly
- No API response shape changes

---

## 5. Self-Audit

| Risk | Mitigation |
|------|-----------|
| Second `_station_local_window()` call for next-day sunrise adds compute time | One additional `find_discrete` for sunrise is negligible vs. the per-planet loop (7 planets × multiple calls each). |
| Polar regions: `next_sunrise_tt` may be None (24-hour daylight) | T1.2 updates the polar guard. Falls back to existing behavior. Existing polar tests in `TestPolarEdgeCases` verify. |
| Cache warmer date change causes brief cache miss on deploy | One-time cost. The miss triggers a fresh compute with correct data. |
| DST edge: 2 AM spring-forward doesn't exist as local time | Python's `ZoneInfo` folds to the next valid time. Reference times (9 PM, 5 AM) never fall on DST boundaries. |
| `_compute_sun_for_date()` L450 / L490 and `_compute_moon_for_date()` L591 have `t_noon` in UTC (Bug B2 pattern) | These are fallbacks for polar regions or when transit isn't found. They affect position display, not visibility classification. Low priority. NOT in scope for this plan — they can be fixed in a separate pass if desired. |
