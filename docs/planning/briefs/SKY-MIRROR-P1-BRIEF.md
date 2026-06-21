# Phase 1 Brief — GHI Mirroring + SZA Guard

**Round:** SKY-MIRROR Phase 1
**Date:** 2026-06-21
**Lead:** Coordinator (Opus)
**Teammate:** `clearskies-api-dev` (Sonnet)
**Auditor:** `clearskies-auditor` (Sonnet, post-QC)

---

## 1. Scope (In / Out)

### Files to create or modify

| File | Change |
|------|--------|
| `weewx_clearskies_api/sse/sky_condition.py` | Add GHI mirroring logic, SZA guard, expand `configure()` to accept station coords |
| `weewx_clearskies_api/__main__.py` | Pass lat, lon, altitude from `get_station_info()` to `sky_condition.configure()` |

### Files NOT to touch

- `sse/conditions_text.py` — stateless composer, no changes needed
- `sse/temperature_comfort.py` — unrelated module
- `sse/enrichment/weather_text.py` — downstream consumer; its `_cloud_pct_to_sky()` thresholds are a SEPARATE concern, not part of this task
- `sse/enrichment/input_smoother.py` — unrelated
- `sse/scene.py` — reads labels from classify(), no interface change
- `tests/test_sky_condition.py` — test-author owns this (Phase 2)
- Any documentation files — coordinator owns those (Phase 0)

### Verification command

```
cd c:\CODE\weather-belchertown\repos\weewx-clearskies-api
ruff check weewx_clearskies_api/sse/sky_condition.py weewx_clearskies_api/__main__.py
mypy weewx_clearskies_api/sse/sky_condition.py --ignore-missing-imports
```

### Deliverable definition

2 commits on `main` in the API repo:
1. GHI mirroring + SZA guard in sky_condition.py
2. Station coords wiring in __main__.py

`ruff check` + `mypy` clean. No test failures in existing tests.

---

## 2. Reading list (before coding)

Read these files in this order:

1. `weewx_clearskies_api/sse/sky_condition.py` — the file you're modifying. Understand the ring buffer, `_compute_indices()`, `_classify_caelus()`, `classify()`, `configure()`, `update()`, `backfill()`, `reset()`.

2. `weewx_clearskies_api/services/almanac.py` lines 704-726 — the `compute_current_sun_altitude(lat, lon, alt_m)` function. This already computes solar elevation via Skyfield. You will reuse `get_ts_eph()` from this module for cos(zenith) computation.

3. `weewx_clearskies_api/services/station.py` — `get_station_info()` returns a `StationInfo` with `.latitude`, `.longitude`, `.altitude`.

4. `weewx_clearskies_api/__main__.py` lines 925-943 — current wiring of `sky_condition.configure()`. You'll add lat/lon/altitude here.

5. Fetch and read the CAELUS mirroring source: `https://raw.githubusercontent.com/jararias/caelus/main/src/caelus/sky_indices.py` — the `mirror_ghi_with_pandas()` function. This is the reference implementation you're adapting.

---

## 3. Pre-round verification

- API repo HEAD: `e7f860a` (verified clean, `main`, up to date)
- No uncommitted changes
- Existing tests: 659 lines in `tests/test_sky_condition.py` (not touched by you)

---

## 4. Per-deliverable spec

### 4A. GHI Mirroring (T1.1)

**What it does:** At sunrise, the trailing 30-minute window has few data points. Under overcast, this produces incorrect Km values (too high), leading to "Sunny, Scattered Clouds" instead of "Overcast." Mirroring generates synthetic pre-sunrise data in the window.

**CAELUS reference algorithm** (`mirror_ghi_with_pandas`):
1. Daytime/nighttime threshold: `cos(zenith) > 0` = daytime, `cos(zenith) <= 0` = nighttime
2. AM/PM split: hour < 12 = AM, hour >= 12 = PM
3. For AM nighttime timestamps: interpolate from (cos_z_daytime, GHI_daytime) at `-cos_z_nighttime`, negate result
4. Same for PM nighttime timestamps
5. Interpolation: `scipy.interp1d` with `kind="linear"`, `bounds_error=False`

**Our real-time adaptation:**

Add a `_mirror_for_km()` function that is called inside `_compute_indices()` before computing Km. It:

1. Accepts the current `_ring` entries and station coordinates (stored at module level by `configure()`).
2. For each ring entry, computes cos(zenith) using Skyfield — import `get_ts_eph` from `services.almanac` and use `wgs84.latlon()` + observer pattern (same as `compute_current_sun_altitude`).
3. Identifies post-sunrise entries (cos_z > 0) and the pre-sunrise gap (timestamps in the 30-min window before the first post-sunrise entry).
4. For each pre-sunrise timestamp slot: computes cos(zenith), looks up GHI at `-cos_z` via linear interpolation from post-sunrise data, negates the result.
5. Returns the extended list of (ghi, max_solar_rad) pairs for Km computation.
6. maxSolarRad for pre-sunrise is 0 (sun below horizon).

**Important constraints:**
- Do NOT use scipy. Use simple linear interpolation from stdlib (`bisect` or manual).
- Do NOT use numpy or pandas. The module currently uses only stdlib (`collections`, `time`, `typing`).
- Cache the Skyfield observer position at `configure()` time — don't rebuild it per call.
- If station coordinates are None (not configured), skip mirroring entirely — graceful fallback.
- Mirroring only affects the Km computation. Kv/Kvf are computed from the ring as-is (they measure variability of real data, not mirrored data).

**Skyfield solar position pattern** (from `almanac.py`):
```python
from weewx_clearskies_api.services.almanac import get_ts_eph
from skyfield.api import wgs84

ts, eph = get_ts_eph()
location = wgs84.latlon(lat, lon, elevation_m=alt_m)
earth = eph["earth"]
sun = eph["sun"]
observer = earth + location

# For a given unix timestamp:
from datetime import datetime, UTC
dt = datetime.fromtimestamp(unix_ts, tz=UTC)
t = ts.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second)
astrometric = observer.at(t).observe(sun)
apparent = astrometric.apparent()
alt_obj, az_obj, dist = apparent.altaz()
elevation_degrees = float(alt_obj.degrees)
# cos(zenith) = sin(elevation) = cos(90 - elevation)
import math
cos_zenith = math.sin(math.radians(elevation_degrees))
```

### 4B. SZA < 85° Classification Guard (T1.2)

**What it does:** When solar elevation < 5° (SZA > 85°), `classify()` returns None instead of attempting classification. This causes the downstream `weather_text.py` to use provider cloud cover as the sky label.

**Implementation:**

In `classify()`, after computing indices but before calling `_classify_caelus()`:
1. Compute current solar elevation using the cached Skyfield observer (same as mirroring).
2. If elevation < 5.0, return `_last_stable_label` (same as the current behavior when `_compute_indices()` returns None). This means: don't update classification, keep the last known label until it times out via the coherence filter.
3. If station coords are None (not configured), skip the SZA guard — fall through to existing behavior.

**Key:** The `_MIN_SOLAR_RAD = 20 W/m²` check in `update()` is KEPT for ring buffer data acceptance. Data still accumulates below the SZA guard — it just doesn't trigger classification.

### 4C. Wire Station Coordinates (T1.3)

**What it does:** Pass lat, lon, altitude from `get_station_info()` to `sky_condition.configure()` at startup.

**Implementation:**

In `__main__.py`, at the line that currently reads:
```python
sky_condition.configure(archive_interval=_station_for_enrichment.archive_interval)
```

Change to:
```python
sky_condition.configure(
    archive_interval=_station_for_enrichment.archive_interval,
    latitude=_station_for_enrichment.latitude,
    longitude=_station_for_enrichment.longitude,
    altitude=_station_for_enrichment.altitude,
)
```

In `sky_condition.py`, expand `configure()` to accept optional `latitude`, `longitude`, `altitude` params. Store them at module level. If all three are provided, pre-build the Skyfield observer position.

---

## 5. Lead calls

1. **No scipy/numpy/pandas.** The module uses only stdlib. Keep it that way. Linear interpolation is trivial to implement with bisect or a simple loop.
2. **Mirroring affects Km only.** Kv/Kvf measure variability of real measurements. Including mirrored (synthetic) values in variability metrics would be scientifically wrong.
3. **Skyfield import from almanac.** Use `get_ts_eph()` — it handles lazy loading and caching. Do NOT duplicate the ephemeris loading logic.
4. **Cache the observer at configure() time.** `wgs84.latlon()` + `earth + location` is cheap but there's no reason to rebuild it per classify() call.
5. **`configure()` stays backward compatible.** New params are optional with default None. Existing tests that call `configure(archive_interval=300)` must continue to work.
6. **Return value set unchanged.** `classify()` returns the same set of labels. The SZA guard returns `_last_stable_label` (same as insufficient-data behavior).

---

## 6. Open questions

None. All decisions are pre-made by the coordinator per the plan.

---

## 7. Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report. Do not resolve it yourself.
