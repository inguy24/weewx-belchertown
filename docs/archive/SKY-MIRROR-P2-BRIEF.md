# Phase 2 Brief — Sky Condition Tests (GHI Mirroring + SZA Guard)

**Round:** SKY-MIRROR Phase 2
**Date:** 2026-06-21
**Lead:** Coordinator (Opus)
**Teammate:** `clearskies-test-author` (Sonnet)
**Auditor:** `clearskies-auditor` (Sonnet, post-QC)

---

## 1. Scope (In / Out)

### Files to create or modify

| File | Change |
|------|--------|
| `tests/test_sky_condition.py` | Add new test functions for GHI mirroring, SZA guard, and regression coverage |

### Files NOT to touch

- `weewx_clearskies_api/sse/sky_condition.py` — implementation is complete from Phase 1
- `weewx_clearskies_api/__main__.py` — wiring is complete from Phase 1
- Any other source files

### Verification command

```
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-api
python -m pytest tests/test_sky_condition.py -v
ruff check tests/test_sky_condition.py
```

### Deliverable definition

1 commit on `main` in the API repo adding tests. `pytest tests/test_sky_condition.py` all green. `ruff check` clean.

---

## 2. Reading list

1. `tests/test_sky_condition.py` — existing tests. Understand the helpers (`_feed_constant_ghi`, `_feed_alternating_ghi`, `_make_backfill_records`), the autouse reset fixture, and the test naming conventions.
2. `weewx_clearskies_api/sse/sky_condition.py` — the implementation you're testing. Understand the new `configure()` signature (lat, lon, altitude params), the mirroring logic, and the SZA guard.
3. `docs/reference/sky-classification-science.md` §3 and §4 — scientific rationale for mirroring and SZA guard.

---

## 3. Tests required

### GHI mirroring tests

**test_mirroring_produces_lower_km_at_sunrise_under_overcast:**
- Configure with station coords (any valid lat/lon/altitude, e.g., 40.0, -74.0, 50.0)
- Feed a small number of overcast readings (GHI=100, msr=300, 5 minutes) at timestamps just after a computed sunrise
- Compare Km with mirroring (station coords configured) vs without mirroring (station coords = None)
- Assert: Km with mirroring is lower than Km without

**test_mirroring_does_not_affect_midday_classification:**
- Configure with station coords
- Feed 30 minutes of data at midday timestamps (full buffer, no edge effects)
- Assert: classification is the same as without mirroring

**test_mirroring_disabled_when_no_station_coords:**
- Call `configure(archive_interval=300)` without lat/lon/altitude
- Feed data, classify
- Assert: classification works (no error), produces a label
- This tests backward compatibility

**test_mirroring_graceful_with_insufficient_post_sunrise_data:**
- Configure with station coords
- Feed only 1-2 minutes of post-sunrise data
- Assert: classify() does not crash, returns a label or None (startup grace)

### SZA guard tests

**test_sza_guard_returns_none_below_threshold:**
- Configure with station coords
- Feed data at timestamps where solar elevation < 5° (early pre-dawn)
- Assert: classify() returns None (or _last_stable_label if previously set)

**test_sza_guard_allows_classification_above_threshold:**
- Configure with station coords
- Feed 30 minutes of data at timestamps where solar elevation > 10°
- Assert: classify() returns a non-None label

**test_sza_guard_does_not_block_data_acceptance:**
- Configure with station coords
- Feed data at timestamps where solar elevation < 5°
- Assert: ring buffer accepts the data (check via internal state or by later classifying at higher elevation using the accumulated data)

**test_sza_guard_skipped_when_no_station_coords:**
- Call `configure(archive_interval=300)` without lat/lon/altitude
- Feed data, classify
- Assert: classification runs normally (no SZA check)

### Regression tests

All existing classification tests must continue to pass. Additionally:

**test_all_six_caelus_classes_produce_labels:**
- CLOUDLESS → "Clear"
- CLOUD_ENHANCEMENT → "Clear"
- THIN_CLOUDS → "Mostly Clear"
- THICK_CLOUDS → "Mostly Cloudy"
- SCATTER_CLOUDS → one of the Km sub-split labels
- OVERCAST → one of the Km×Kv sub-split labels
- Assert each produces a non-None result

**test_temporal_coherence_filter_still_works:**
- Feed data that would change classification mid-stream
- Assert: label doesn't change until 15-minute persistence threshold

**test_backfill_still_works:**
- Call backfill() with archive records
- Assert: classify() returns a label immediately

**test_day_night_transition_still_clears_buffer:**
- Feed daytime data, then nighttime data
- Assert: ring buffer is cleared on transition

---

## 4. Test helpers

Extend the existing helpers as needed. Key pattern for SZA/mirroring tests: you need timestamps that correspond to specific solar elevations. Use Skyfield to compute what timestamps produce what elevations for the test station coordinates.

Example approach:
```python
from weewx_clearskies_api.services.almanac import get_ts_eph
from skyfield.api import wgs84
import math

def _find_timestamp_at_elevation(lat, lon, alt_m, target_elevation, search_date):
    """Find a timestamp where solar elevation is approximately target_elevation."""
    ts_sf, eph = get_ts_eph()
    # ... binary search or iterate through the day
```

Or simpler: use known timestamps for a known location where solar elevation is predictable (e.g., solar noon at equator = 90° elevation).

---

## 5. Lead calls

1. Use realistic GHI/maxSolarRad values, not arbitrary numbers. Under overcast at sunrise: GHI ≈ 50-150, maxSolarRad ≈ 100-400. Under clear sky at midday: GHI ≈ 800-1000, maxSolarRad ≈ 900-1100.
2. SZA guard tests need timestamps where the ephemeris returns predictable solar elevations. Pick a known location and date.
3. Don't mock Skyfield — the ephemeris is available in tests (via `CLEARSKIES_EPHEMERIS_DIR` env var or lazy loading in `get_ts_eph()`).
4. Each test must test ONE thing. A test named "test_sza_guard_returns_none_below_threshold" must ONLY assert that behavior, not also check mirroring.

---

## 6. Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report. Do not resolve it yourself.
