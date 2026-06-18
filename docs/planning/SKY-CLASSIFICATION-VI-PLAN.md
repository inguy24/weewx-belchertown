# Plan: Replace σ(kc) Sky Classification with Variability Index System

**Status:** APPROVED
**Created:** 2026-06-18
**Component:** API (`weewx-clearskies-api`)

---

## Context

ADR-044's sky condition classification uses σ(kc) — standard deviation of the clear-sky index — as its sole variability measure. This is scientifically inadequate and produces frequent misclassification. The system cannot reliably distinguish "Cloudy" from "Mostly Cloudy" from "Partly Cloudy" because σ collapses all temporal information into a single scalar — it cannot capture the *shape* of the irradiance curve.

The CAELUS system (Ruiz-Arias & Gueymard, 2023 — peer-reviewed, validated on 54 BSRN stations worldwide across all 5 major Köppen-Geiger climate classes, open-source at github.com/jararias/caelus) replaces σ with a **Variability Index (VI)** — the cumulative absolute first-derivative of GHI's deviation from its rolling mean, normalized by time. This is the calculus-based "shape of the curve" approach: it counts how many irradiance transitions occur and how sharp they are, not just how spread the values are.

Additionally, ADR-044 and the sky_condition.py code contain a hallucinated sensor reference ("Davis 6450 pyranometer ±5% accuracy") that a previous Claude session fabricated without verification. Clear Skies is a product that runs on whatever hardware the operator has — we have zero knowledge of what pyranometer they're using. All sensor-specific assumptions must be removed and replaced with sensor-agnostic design. CAELUS is well-suited for this: it was validated across diverse stations and equipment worldwide, not calibrated to any single sensor model.

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — coding standards
- `rules/clearskies-process.md` — ADR discipline, scope binding, QC gates
- `docs/API-MANUAL.md` §8 — conditions text engine specification
- `docs/ARCHITECTURE.md` lines 262–283 — conditions text engine module map

**Repo:** `repos/weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`. Lint: `ruff check`, `mypy`.

**Key files (current implementation):**

| File | Role |
|------|------|
| `weewx_clearskies_api/sse/sky_condition.py` | Stateful classifier — 30-min rolling kc-buffer, σ-based classification, hysteresis |
| `weewx_clearskies_api/sse/conditions_text.py` | Stateless composer — assembles `weatherText` string from sky + comfort + wind + precip |
| `weewx_clearskies_api/sse/enrichment/weather_text.py` | Enrichment adapter — reads smoothed inputs + sky class, calls `build_weather_text()` |
| `weewx_clearskies_api/sse/enrichment/sky_tap.py` | Packet tap — feeds `radiation` + `maxSolarRad` from every loop packet into sky_condition.update() |
| `weewx_clearskies_api/sse/scene.py` | Scene builder — maps sky labels to background buckets ("clear"/"cloudy"/"storm") |
| `weewx_clearskies_api/sse/enrichment/scene_enrichment.py` | Scene enrichment — calls sky_condition.classify() for scene descriptor |

**Integration surface (what calls sky_condition):**
- `sky_tap.py` calls `sky_condition.update(radiation, max_solar_rad)` on every loop packet
- `weather_text.py` calls `sky_condition.classify()` and `sky_condition.is_daytime()` on every GET /current
- `scene_enrichment.py` calls `sky_condition.classify()` for scene descriptor
- `scene_packet_tap.py` calls `sky_condition.classify()` for SSE scene injection
- `conditions_text.py` receives sky label as a parameter — does not call sky_condition directly

**Critical constraint: the public API of sky_condition.py must not change.** All callers use `update(radiation, max_solar_rad, timestamp)`, `classify() -> str | None`, `is_daytime() -> bool`, and `reset()`. The return values are the same NWS labels: "Clear", "Mostly Clear", "Partly Cloudy", "Mostly Cloudy", "Cloudy". Scene module's `_SKY_LABEL_TO_BUCKET` dict already maps all of these. No downstream code needs to change.

**New public function:** `backfill(records)` is added for startup archive seeding — this is additive, not a breaking change.

**Existing tests:** `repos/weewx-clearskies-realtime/tests/test_sky_condition.py` (27 tests covering the old realtime module). No sky_condition tests exist in the API repo — the realtime repo's tests cover the identical copy.

**weewx data architecture (from `docs/reference/weewx-5.3/custom/introduction.md`):**
- **LOOP packets:** Raw driver data every ~2–5 seconds. May be partial (not all fields in every packet). NOT stored in the database. This is what feeds the live sky_condition rolling buffer via `sky_tap.py`.
- **Archive records:** Aggregated from LOOP packets at configurable intervals (default 300s / 5 min, must be divisible by 60). All observation types present. For most types (including `radiation`): the **average** over the interval. Stored in the `archive` SQL table. The API already queries this table via SQLAlchemy (`services/archive.py`).
- **Implication for sky classification:** Real-time classification uses LOOP packets (high frequency). But on API restart, the rolling buffer is empty. The archive table contains the last 30 minutes of averaged `radiation` and `maxSolarRad` data — this can backfill the ring buffer on startup, giving an immediate (if coarser) classification instead of returning None.
- **Archive interval is operator-configurable** — could be 60s, 300s, 600s, 900s, or 1800s. The backfill logic must handle whatever interval the operator has set. Operators who want optimal sky classification accuracy should set `archive_interval = 60` in `weewx.conf` under `[StdArchive]`.

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree.

---

## 1. Why σ(kc) Fails — Concrete Scenarios

Standard deviation collapses temporal structure. These scenarios produce identical or near-identical (mean, σ) pairs but represent physically different sky conditions:

**Scenario 1: Thin uniform overcast vs. broken clouds with sun breaks**
- Both: mean(kc) ≈ 0.55, σ(kc) ≈ 0.04 → ADR-044 classifies both as "Partly Cloudy"
- Variability Index distinguishes: uniform overcast Kv ≈ 0.01 (smooth signal), broken clouds Kv ≈ 0.06 (many ramps)

**Scenario 2: Thick overcast vs. heavy clouds with occasional sun breaks**
- Both: mean(kc) ≈ 0.25, σ(kc) ≈ 0.06 → ADR-044 classifies both as "Cloudy"
- VI distinguishes: thick overcast Kv ≈ 0.02, heavy broken Kv ≈ 0.10

**Scenario 3: Slow clearing trend vs. rapid oscillation**
- A 30-min drift from kc=0.3→0.9 and rapid 2-min oscillations between 0.3–0.9 produce similar σ
- VI is dramatically different: drift has few large ramps, oscillation has many

The root cause: σ treats all deviations equally regardless of temporal order. It's a measure of *spread*, not *shape*. Two completely different irradiance time series can produce the same σ. The Variability Index measures the total "path length" of the deviation signal — it captures how many transitions occur and how sharp each one is.

---

## 2. The Fix — Four Indices, Six Classes (CAELUS)

### 2a. Four indices (replacing mean(kc) + σ(kc))

CAELUS source: `github.com/jararias/caelus`, file `src/caelus/sky_indices.py`.

1. **Kcs** = GHI / GHI_cs — instantaneous clear-sky index. Same concept as current kc. Used for cloud-enhancement detection (Kcs > 1.0 means measured GHI exceeds clear-sky model — cloud-edge focusing).

2. **Km** = rolling_mean(GHI) / GHI_cda — mean normalized irradiance over 30-min window. Replaces mean(kc). In our implementation: `mean(GHI) / mean(maxSolarRad)` since maxSolarRad is our clear-sky reference.

3. **Kv** = Σ|Δ(GHI - mean_GHI)| / T_coarse — **coarse variability index** (30-min window). **This is the key new metric — the calculus-based "shape of the curve."** Computes the absolute first-difference (discrete derivative) of the deviation from the rolling mean, accumulated over the window, divided by window duration in seconds.

4. **Kvf** = Σ|Δ(GHI - mean_GHI)| / T_fine — **fine variability index** (10-min window). Same formula, shorter window. Catches rapid cloud transits that wash out in the 30-min window.

### 2b. How Kv works (the calculus)

At each 1-minute timestep:
```
deviation(t) = GHI(t) - mean_GHI(t)        # how far from the smooth mean
delta(t) = |deviation(t) - deviation(t-1)|  # absolute rate of change of deviation
Kv = sum(delta over window) / window_seconds
```

This is the discrete approximation of ∫|d/dt(GHI - mean_GHI)|dt / T — the total "path length" of the deviation signal, normalized by time. A smooth signal (uniform overcast, clear sky) produces near-zero Kv. A jagged signal (broken clouds, rapid transits) produces high Kv.

Standard deviation *cannot* capture this information. Two signals with identical variance can have completely different Kv values.

### 2c. Six classes with CAELUS thresholds

Thresholds from the peer-reviewed paper, validated on 54 stations across all major climate zones. Source: `src/caelus/options.py`.

**Decision order (evaluated top to bottom, first match wins):**

| # | Class | Conditions | NWS Display | Physical Meaning |
|---|-------|-----------|-------------|-----------------|
| 1 | CLOUD_ENHANCEMENT | Kcs > 1.06 AND Kv > 0.20 AND Kvf > 0.20 AND SZA < 80° | Partly Cloudy | Cloud-edge focusing — GHI exceeds clear-sky, evidence of nearby clouds |
| 2 | CLOUDLESS | Km > 0.6 AND Kcs ∈ [0.85, 1.15] AND Kv < 0.03 (SZA < 75°); or Kcs ∈ [0.80, 1.20] (SZA ≥ 75°) | Clear / Sunny | No clouds, stable high irradiance |
| 3 | OVERCAST | Km < 0.3 AND Kv < 0.10 | Cloudy | Thick uniform cover, smooth signal |
| 4–6 | Remaining = "cloudy zone" (not cloudless, not overcast, not cloud-enhancement): | | | |
| 4 | THIN_CLOUDS | Km > 0.5 AND Kv ∈ [0.03, 0.08) | Mostly Clear / Mostly Sunny | Light cloud, slight variability |
| 5 | THICK_CLOUDS | Km < 0.4 AND Kv ∈ [0.04, 0.16) | Mostly Cloudy | Heavy cloud with some breaks |
| 6 | SCATTER_CLOUDS | Everything else in cloudy zone | Partly Cloudy | Broken cloud field, moderate variability |

### 2d. Sensor-agnostic design

CAELUS was validated across 54 BSRN stations with diverse equipment and climates. The thresholds are general, not calibrated to any specific sensor model. This is essential for Clear Skies — operators use whatever pyranometer they have, and we have zero knowledge of their hardware.

**Why this works without knowing the sensor:**
- **Kv/Kvf measure relative changes (first differences), not absolute values.** Systematic sensor bias cancels out in the derivative.
- **Km normalizes against the clear-sky reference.** Systematic offset in the sensor is partially cancelled by the normalization.
- **1-minute averaging reduces random noise.** Binning 12 five-second readings into 1-minute means reduces random noise by √12 ≈ 3.5×, regardless of sensor quality.
- **The thresholds have margin.** CLOUDLESS_MAX_KV = 0.03 is well above the noise floor of most pyranometers after 1-minute averaging.

**What must be removed from the codebase:** All references to "Davis 6450" — these were hallucinated by a previous Claude session and baked into ADR-044 (line 36) and sky_condition.py (lines 25–27). The threshold rationale that depends on "±5% accuracy" must be replaced with sensor-agnostic language explaining why the CAELUS thresholds are general.

### 2e. Post-classification stability (replacing hysteresis)

Instead of ADR-044's per-threshold ±0.03 hysteresis bands, CAELUS uses temporal coherence filters (source: `src/caelus/filters.py`):

- **Spurious patch cleaning:** Any sky class lasting < 15 minutes is absorbed into its neighbors (iterative, up to 50 passes)
- **Transition smoothing:** Cleans implausible transitions (scatter clouds flanked by thin clouds, cloudless→thin cloud jumps, thin→scatter jumps)

This is more physically meaningful than hysteresis — it says "a sky condition must persist for at least 15 minutes to be real." The existing 5-minute minimum hold time in ADR-044 §8 is a weaker version of the same idea.

### 2f. Data resolution: 5-second → 1-minute binning + archive backfill

CAELUS thresholds were derived for 1-minute data. Our system has two data sources with different resolutions:

**Real-time (LOOP packets, ~5-second intervals):**
- Raw 5-second readings accumulate in a sub-minute buffer (≤12 readings per minute)
- Every minute, compute 1-minute mean GHI and mean maxSolarRad
- Store in a 30-minute ring buffer (≤30 slots)
- Compute the four indices from the 1-minute series
- Classify

**Startup backfill (archive records, operator-configurable interval — typically 5 min):**
- On API startup, query the last 30 minutes of archive records from the weewx database
- Each archive record already contains the average `radiation` and `maxSolarRad` over its interval
- Load directly into the ring buffer — no further binning needed
- Provides an immediate (if coarser) classification instead of returning None for 3+ minutes
- As live LOOP packets arrive, 1-minute bins are appended and old archive entries age out naturally
- Within ~30 minutes of startup, the buffer is entirely live 1-minute data

**Why this works:** CAELUS was designed for and validated at 1-minute resolution. For live data, 5-second LOOP packets bin to 1-minute — peer-reviewed thresholds apply directly. For backfill, archive records at 5-minute resolution produce coarser Kv (rapid sub-5-minute cloud transits are averaged out), but the classification is still meaningful and far better than no classification. The system gracefully transitions from archive-quality to full-quality as live data accumulates.

---

## 3. Implementation Phases

### PHASE 0 — Remove hallucinated sensor references

**T0.1 — Strip "Davis 6450" from ADR-044 and code**
- Owner: `clearskies-api-dev` (Sonnet)
- Files:
  - `docs/archive/decisions/ADR-044-sky-condition-classification.md` line 36 — remove "Davis 6450 pyranometer ±5% accuracy + weewx maxSolarRad model ±4% error" and replace with sensor-agnostic language
  - `repos/weewx-clearskies-api/weewx_clearskies_api/sse/sky_condition.py` lines 25–27 — remove "Davis 6450 ±5%" comment block
  - `docs/API-MANUAL.md` line 549 — remove "Davis 6450 pyranometer ±5%" sentence
- Do: Replace all three with: "Threshold accounts for typical pyranometer accuracy and clear-sky model error. Operators use diverse sensor hardware; thresholds must be sensor-agnostic."
- Accept: No mention of "Davis 6450" or "±5%" anywhere in the codebase. `grep -r "Davis 6450"` and `grep -r "6450"` return zero hits in docs/ and repos/.

**QC (Opus) — after T0.1:** Verify grep returns zero hits. Read the replacement text for accuracy.

### PHASE 1 — Rewrite sky_condition.py internals

**T1.1 — Implement two-tier buffer architecture**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/sse/sky_condition.py`
- Do: Replace the existing `deque[(timestamp, kc)]` buffer with:
  - Tier 1: `_minute_acc: list[tuple[float, float, float]]` — sub-minute accumulator for raw (timestamp, GHI, maxSolarRad) readings within the current minute
  - Tier 2: `_ring: deque[MinuteRecord]` — 30-slot ring buffer of 1-minute averaged (minute_ts, mean_GHI, mean_maxSolarRad) records
  - `MinuteRecord` as a `NamedTuple` with fields `ts`, `ghi`, `max_solar_rad`
  - Minute rollover detection: when `int(timestamp / 60) != int(last_timestamp / 60)` or accumulator has ≥12 readings
- Keep: `_was_daytime`, `_MIN_SOLAR_RAD` night guard, `_NOISE_FLOOR` guard, `_KC_MAX` clamp (1.2), `reset()`, `is_daytime()`
- Remove: `_SIGMA_THRESHOLD`, `_HYSTERESIS`, all `_KC_*` threshold constants, ASOS double-weighting logic
- Accept: `update()` signature unchanged. `reset()` clears both tiers. Night guard still works. Buffer correctly bins 5-sec data to 1-min averages.

**T1.2 — Implement four-index computation**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/sse/sky_condition.py`
- Do: New internal function `_compute_indices(ring) -> tuple[float, float, float, float] | None` that computes (Kcs, Km, Kv, Kvf) from the ring buffer:
  - `Kcs` = most recent minute's GHI / maxSolarRad, clamped to [0, 1.2]
  - `Km` = mean(all GHI in ring) / mean(all maxSolarRad in ring), clamped ≥ 0
  - Compute deviation series: for each minute record, `dev[i] = ghi[i] - mean_ghi_over_ring`
  - Compute `diff_abs[i] = |dev[i] - dev[i-1]|` for i ≥ 1
  - `Kv` = sum(all diff_abs) / (len(ring) * 60) — 30-min window
  - `Kvf` = sum(diff_abs for last 10 minutes of ring) / (min(10, len_ring_last_10) * 60) — 10-min window
  - Returns None when ring has < 3 entries (startup guard, ~3 min of data)
- Accept: Known constant signals produce expected index values. Known oscillating signals produce elevated Kv/Kvf.

**T1.3 — Implement CAELUS classification decision tree**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/sse/sky_condition.py`
- Do: Replace `_classify_raw()` and `_classify_with_hysteresis()` with `_classify_caelus(kcs, km, kv, kvf) -> str`:
  - Threshold constants from CAELUS `options.py` (Table 3 in the paper):
    ```
    CLOUDEN_MIN_KCS = 1.06
    CLOUDLESS_MIN_KM = 0.6
    CLOUDLESS_MIN_KCS = 0.85
    CLOUDLESS_MAX_KCS = 1.15
    CLOUDLESS_MAX_KV = 0.03
    THINCLOUDS_MIN_KM = 0.5
    THINCLOUDS_MIN_KV = 0.03
    THINCLOUDS_MAX_KV = 0.08
    THICKCLOUDS_MAX_KM = 0.4
    THICKCLOUDS_MIN_KV = 0.04
    THICKCLOUDS_MAX_KV = 0.16
    OVERCAST_MAX_KM = 0.3
    OVERCAST_MAX_KV = 0.10
    CLOUDEN_MIN_KV = 0.20
    CLOUDEN_MIN_KVF = 0.20
    ```
  - Decision order: CLOUD_ENHANCEMENT → CLOUDLESS → OVERCAST → (remaining) THIN_CLOUDS → THICK_CLOUDS → SCATTER_CLOUDS
  - Map to NWS labels: CLOUDLESS→"Clear", THIN_CLOUDS→"Mostly Clear", SCATTER_CLOUDS→"Partly Cloudy", THICK_CLOUDS→"Mostly Cloudy", OVERCAST→"Cloudy", CLOUD_ENHANCEMENT→"Partly Cloudy"
  - Note: CLOUD_ENHANCEMENT maps to "Partly Cloudy" because cloud-edge enhancement means nearby clouds with sun — that IS partly cloudy
- Remove: `_classify_raw()`, `_classify_with_hysteresis()`, all old threshold constants
- Accept: `classify()` return type unchanged (`str | None`). Returns same NWS label set. No downstream code changes needed.

**T1.4 — Implement temporal coherence filter (replacing hysteresis)**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/sse/sky_condition.py`
- Do: New module-level state:
  - `_classification_history: deque[tuple[float, str]]` — timestamped classification history (last 30 min)
  - `_last_stable_label: str | None` — the last classification that survived the coherence filter
  - On each `classify()` call: compute raw classification, append to history, then apply filter:
    - If the raw label has been the same for ≥ 15 consecutive minutes in history → adopt it as stable
    - If < 15 minutes → return `_last_stable_label` (hold previous)
    - Startup: first classification that reaches 3 minutes becomes the initial stable label (don't wait 15 min on startup)
  - `reset()` clears classification history and stable label
- Remove: Old hysteresis logic, `_HYSTERESIS` constant, 5-minute hold time
- Accept: Rapid classification flicker is suppressed. Stable conditions hold. Startup produces a result within ~3 minutes.

**T1.5 — Implement startup backfill from archive records**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/sse/sky_condition.py`
- Do: New public function `backfill(records: list[tuple[float, float, float]]) -> None` that accepts a list of (timestamp, radiation, maxSolarRad) tuples from archive records and seeds the ring buffer:
  - Each archive record becomes one ring entry (it's already an average over the archive interval — no further binning needed)
  - Handle variable archive intervals (60s, 300s, 600s, etc.) — the ring buffer stores records as-is, timestamps determine window bounds
  - Trim to last 30 minutes of records
  - Apply same night guard (_MIN_SOLAR_RAD) and noise floor checks as `update()`
  - After backfill, the ring buffer contains archive-resolution data. As live LOOP packets arrive, new 1-minute bins are appended and old archive entries age out naturally
  - Must be idempotent — calling backfill() twice with same data doesn't duplicate entries
- Integration point: The caller (likely `__main__.py` or an init hook) queries `SELECT dateTime, radiation, maxSolarRad FROM archive WHERE dateTime > :cutoff ORDER BY dateTime` via the existing SQLAlchemy session, then passes the results to `backfill()`
- Accept: After backfill, `classify()` returns a classification immediately (not None). Ring buffer contains archive records. Live LOOP packets gradually replace archive data as they accumulate.

**T1.6 — Update module docstring and constants documentation**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `repos/weewx-clearskies-api/weewx_clearskies_api/sse/sky_condition.py`
- Do: Rewrite module docstring to describe the VI-based system. Remove all σ references. Remove all "Davis 6450" references. Document the four indices, the six CAELUS classes, the NWS mapping, the temporal coherence filter, and the 1-minute binning approach. Reference the CAELUS paper.
- Accept: Docstring accurately describes the as-built system. No mention of σ, Davis 6450, or hysteresis.

**QC (Opus) — after Phase 1:**
- Read the complete rewritten `sky_condition.py` against the CAELUS source code (`options.py`, `sky_indices.py`, `classifier.py`) to verify: (a) index computation matches CAELUS formulas, (b) threshold values match `options.py` Table 3, (c) decision tree order matches `classify_with_pandas()`.
- Verify public API unchanged: `update()`, `classify()`, `is_daytime()`, `reset()` signatures identical.
- Verify return values are the same NWS label set used by `conditions_text.py`, `scene.py`, `weather_text.py`.
- `ruff check` and `mypy` pass.
- No "Davis 6450", no "sigma", no "σ(kc)" in the file.

### PHASE 2 — Tests

**T2.1 — Write sky_condition unit tests for the API repo**
- Owner: `clearskies-test-author` (Sonnet)
- File: New `repos/weewx-clearskies-api/tests/test_sky_condition.py`
- Tests required:

  **Index computation tests:**
  - Constant GHI signal → Kv ≈ 0, Kvf ≈ 0, Km ≈ GHI/maxSolarRad
  - Rapidly oscillating GHI (alternating high/low every minute) → high Kv, high Kvf
  - Slow ramp (GHI increases linearly over 30 min) → moderate Kv, low Kvf
  - GHI > maxSolarRad (cloud enhancement) → Kcs > 1.0

  **Classification tests (one per CAELUS class):**
  - CLOUDLESS: constant high GHI, Kv near zero → "Clear"
  - OVERCAST: constant low GHI, Kv near zero → "Cloudy"
  - THIN_CLOUDS: moderate-high GHI, slight variability → "Mostly Clear"
  - THICK_CLOUDS: low GHI, moderate variability → "Mostly Cloudy"
  - SCATTER_CLOUDS: medium GHI, high variability → "Partly Cloudy"
  - CLOUD_ENHANCEMENT: GHI > maxSolarRad with high variability → "Partly Cloudy"

  **1-minute binning tests:**
  - 12 readings at 5-sec intervals produce 1 ring entry
  - Minute rollover triggers bin correctly
  - Averaging is correct within a bin

  **Backfill tests:**
  - Backfill with 6 archive records at 5-min intervals → `classify()` returns a result (not None)
  - Backfill with 30 archive records at 1-min intervals → full-quality classification
  - Backfill with records older than 30 minutes → trimmed, only last 30 min kept
  - Backfill with night records (maxSolarRad < _MIN_SOLAR_RAD) → skipped
  - Backfill followed by live LOOP packets → live data appends, old archive ages out
  - Backfill idempotency → calling twice with same data doesn't duplicate
  - Empty backfill (no records) → `classify()` returns None, no crash

  **Temporal coherence filter tests:**
  - Rapid flicker between two classes → holds previous stable class
  - Class persisting > 15 min → adopted as new stable class
  - Startup: first classification available within ~3 minutes

  **Edge case tests (ported from realtime repo):**
  - `classify()` returns None when < 3 minutes of data
  - Night guard: maxSolarRad below threshold → reading skipped
  - radiation=None → reading skipped
  - Negative radiation → reading skipped
  - Kcs clamped at 1.2
  - Buffer cleared at sunset transition
  - `reset()` clears all state
  - `is_daytime()` returns True/False correctly

- Accept: All tests pass. Coverage of all six CAELUS classes. Coverage of index computation edge cases. Coverage of temporal coherence filter. Coverage of backfill. `pytest tests/test_sky_condition.py` passes.

**QC (Opus) — after Phase 2:**
- Read each test and verify it tests what it claims (not just asserting `is not None`).
- Verify the test helper feeds realistic GHI/maxSolarRad values (not kc values — the old interface).
- Verify tests cover the specific failure scenarios from §1 (the concrete scenarios where σ fails).
- `pytest tests/test_sky_condition.py` passes with 0 failures.
- `ruff check tests/test_sky_condition.py` passes.

### PHASE 3 — Documentation

**T3.1 — Amend ADR-044 §1a**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `docs/archive/decisions/ADR-044-sky-condition-classification.md`
- Do:
  - Add amendment header: `> **Amendment (2026-06-18):** §1a rewritten. σ(kc)-based classification replaced with Variability Index (VI) system adapted from CAELUS (Ruiz-Arias & Gueymard 2023). Four indices (Kcs, Km, Kv, Kvf) replace mean(kc) + σ(kc). Six-class decision tree replaces 2D (σ, mean) table. Temporal coherence filter replaces per-threshold hysteresis. 5-second data binned to 1-minute averages before index computation. Archive records used for startup backfill. All sensor-specific references (Davis 6450) removed — system is sensor-agnostic.`
  - Replace the σ-first classification tables with the CAELUS four-index definitions and six-class decision tree
  - Replace hysteresis section (§8) with temporal coherence filter description
  - Add startup backfill section documenting archive record seeding
  - Replace Options Considered table: Option E (CAELUS) changed from "Rejected — Overkill" to "**Selected** — adapted for weather display"
  - Add CAELUS reference to References section
  - Remove all "Davis 6450" text
- Accept: ADR-044 accurately describes the as-built VI system. No mention of σ-based classification except in amendment history. CAELUS cited. No sensor-specific references.

**T3.2 — Update API-MANUAL.md §8 (conditions text engine)**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `docs/API-MANUAL.md`
- Do: Replace lines 523–549 (sky condition subsection) with:
  - Four-index description (Kcs, Km, Kv, Kvf) with formulas
  - Six-class decision tree table
  - 1-minute binning explanation
  - Startup backfill from archive records
  - Temporal coherence filter (15-min minimum patch)
  - Startup behavior (immediate via backfill, full accuracy after ~30 min of live data)
  - Remove σ classification tables
  - Remove "Davis 6450" sentence (line 549)
  - Remove hysteresis bands from Input stability section (lines 671–680) — replace with temporal coherence filter description
  - Remove 5-minute hold time (line 682) — replaced by 15-min coherence filter
- Accept: API-MANUAL accurately describes the as-built system. Consistent with ADR-044 amendment.

**T3.3 — Update ARCHITECTURE.md conditions text section**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `docs/ARCHITECTURE.md`
- Do: Update line 281 to replace σ/hysteresis description with VI-based description. Keep module table unchanged (same files, same roles).
- Accept: One-line description accurately says "VI-based" instead of "σ-based".

**T3.4 — Verify other manuals need no changes**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Grep all manuals for sky condition / σ / Davis 6450 references:
  - `docs/DESIGN-MANUAL.md` — sky background mapping (lines 409–410) uses NWS labels ("Clear", "Mostly Cloudy", etc.) which are unchanged. No changes needed.
  - `docs/DASHBOARD-MANUAL.md` — scene descriptor references only. No classification methodology. No changes needed.
  - `docs/OPERATIONS-MANUAL.md` — no sky classification references. No changes needed.
  - `docs/PROVIDER-MANUAL.md` — cloud cover mentioned only in astronomy context. No changes needed.
- Accept: Confirmed no stale σ, Davis 6450, or incorrect sky classification references in any manual.

**QC (Opus) — after Phase 3:**
- Cross-check ADR-044 amendment against the code in sky_condition.py — every threshold, every class, every formula must match.
- Cross-check API-MANUAL against ADR-044 — must be consistent.
- Cross-check ARCHITECTURE.md summary line against API-MANUAL.
- Verify no stale σ references remain in any doc across the entire `docs/` directory.
- Verify no "Davis 6450" references remain anywhere in `docs/` or `repos/`.
- Verify DESIGN-MANUAL background mapping still uses correct NWS labels.

### PHASE 4 — Integration Verification

**T4.1 — Verify no downstream code changes needed**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Grep the API repo for all callers of sky_condition functions. Verify each still works:
  - `sky_tap.py`: calls `update(radiation, max_solar_rad)` — unchanged
  - `weather_text.py`: calls `classify()` and `is_daytime()` — unchanged return types
  - `scene_enrichment.py`: calls `classify()` — unchanged return values
  - `scene_packet_tap.py`: calls `classify()` — unchanged
  - `scene.py` `_SKY_LABEL_TO_BUCKET`: maps "Clear", "Mostly Clear", "Partly Cloudy", "Mostly Cloudy", "Cloudy" — all still returned
  - `conditions_text.py` `_DAY_LABELS`: maps "Clear"→"Sunny", "Mostly Clear"→"Mostly Sunny" — still valid
- Accept: Zero downstream file changes. All callers verified compatible.

**T4.2 — Verify realtime repo sky_condition.py is dead code**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Confirm `repos/weewx-clearskies-realtime/` is archived per ADR-058. The sky_condition.py in that repo is a stale copy. Leave it untouched — it's dead code in an archived repo.
- Accept: Confirmed dead code. No changes to realtime repo.

**T4.3 — Run full test suite**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Run `pytest` on the API repo. Verify no regressions.
- Accept: All tests pass. Zero failures. `ruff check` and `mypy` clean.

**QC (Opus) — after Phase 4:**
- Read grep results confirming all callers.
- Verify test results.
- Verify `ruff check` and `mypy` output.

---

## 4. Agent Assignments

| Phase | Task | Owner | Model | QC (Opus) | QC Timing |
|-------|------|-------|-------|-----------|-----------|
| 0 | T0.1 Strip hallucinated sensor refs | `clearskies-api-dev` | Sonnet | grep verify | After T0.1 |
| 1 | T1.1 Two-tier buffer | `clearskies-api-dev` | Sonnet | Code review vs CAELUS | After Phase 1 |
| 1 | T1.2 Four-index computation | `clearskies-api-dev` | Sonnet | Formula verify vs CAELUS source | After Phase 1 |
| 1 | T1.3 CAELUS decision tree | `clearskies-api-dev` | Sonnet | Threshold verify vs options.py | After Phase 1 |
| 1 | T1.4 Temporal coherence filter | `clearskies-api-dev` | Sonnet | Logic review | After Phase 1 |
| 1 | T1.5 Startup backfill | `clearskies-api-dev` | Sonnet | Integration review | After Phase 1 |
| 1 | T1.6 Docstring update | `clearskies-api-dev` | Sonnet | Content review | After Phase 1 |
| 2 | T2.1 Unit tests | `clearskies-test-author` | Sonnet | Test quality review + pytest | After Phase 2 |
| 3 | T3.1 ADR-044 amendment | `clearskies-api-dev` | Sonnet | Cross-check vs code | After Phase 3 |
| 3 | T3.2 API-MANUAL update | `clearskies-api-dev` | Sonnet | Cross-check vs ADR | After Phase 3 |
| 3 | T3.3 ARCHITECTURE.md update | `clearskies-api-dev` | Sonnet | Cross-check vs manual | After Phase 3 |
| 3 | T3.4 Verify other manuals | `clearskies-api-dev` | Sonnet | Grep audit | After Phase 3 |
| 4 | T4.1 Downstream verification | `clearskies-api-dev` | Sonnet | Grep audit | After Phase 4 |
| 4 | T4.2 Realtime repo dead code | `clearskies-api-dev` | Sonnet | Confirm archived | After Phase 4 |
| 4 | T4.3 Full test suite | `clearskies-api-dev` | Sonnet | Test results | After Phase 4 |

**Sequencing:** Phase 0 → Phase 1 (all T1.x in one agent, one file) → Phase 2 (tests) → Phase 3 (docs, all manuals) → Phase 4 (verification)

---

## 5. QC Gates

### Gate 1 — Code Quality (Phase 1 + 2)
- `ruff check` 0 errors on all modified files
- `mypy` 0 new errors
- `pytest` all tests pass

### Gate 2 — CAELUS Fidelity (Phase 1)
- All 14 threshold constants match CAELUS `options.py` exactly
- Index computation formulas match CAELUS `sky_indices.py` logic
- Decision tree order matches CAELUS `classify_with_pandas()` logic
- Deviations from CAELUS are explicitly documented with rationale (e.g., NWS label mapping, 5-sec→1-min binning, maxSolarRad vs ghicda)

### Gate 3 — Interface Compatibility (Phase 4)
- `update()`, `classify()`, `is_daytime()`, `reset()` signatures unchanged
- `backfill()` is additive (new public function, not a breaking change)
- Return value set unchanged: "Clear", "Mostly Clear", "Partly Cloudy", "Mostly Cloudy", "Cloudy", None
- Zero downstream file changes required
- `scene.py` `_SKY_LABEL_TO_BUCKET` handles all returned labels

### Gate 4 — Doc-Code Sync (Phase 3)
- ADR-044, API-MANUAL.md, ARCHITECTURE.md all describe the same system
- Every threshold in the docs matches the code
- No stale σ or Davis 6450 references remain anywhere in docs/ or repos/
- All five manuals verified (API, ARCHITECTURE, DESIGN, DASHBOARD, OPERATIONS, PROVIDER)

### Gate 5 — Sensor Agnosticism
- No sensor model names anywhere in code or docs
- No sensor accuracy specs hardcoded anywhere
- Threshold rationale does not depend on any specific sensor's error characteristics

---

## 6. Self-Audit

**Risks:**
- **1-minute binning discards sub-minute variability.** Rapid cloud transits within a single minute are averaged out. Acceptable: CAELUS was designed for and validated at 1-minute resolution. Sub-minute variability is noise for sky classification.
- **GHI mirroring omitted.** CAELUS mirrors GHI at dawn/dusk using cos(zenith) interpolation for rolling-mean stability. We omit this because our `_MIN_SOLAR_RAD` guard already excludes low-sun periods. If dawn/dusk instability appears in practice, mirroring can be added later without changing the public API.
- **15-minute coherence filter may feel sluggish.** A real sky change takes up to 15 minutes to register. But 15 minutes is CAELUS's validated value, and it prevents the flicker that plagues the current σ system. Acceptable tradeoff.
- **No SZA computation.** CAELUS uses solar zenith angle for CLOUD_ENHANCEMENT (SZA < 80°) and CLOUDLESS (SZA < 75° vs ≥ 75°). Current code doesn't compute SZA — it uses `_MIN_SOLAR_RAD` as a proxy. For Phase 1, use maxSolarRad thresholds as SZA proxy (high maxSolarRad ≈ low SZA). If precision is needed later, pvlib's `solarposition` can be added.
- **Backfill quality depends on archive interval.** Operators with 5-minute archive intervals get coarser startup classification than operators with 1-minute intervals. The system handles both, but accuracy differs. Document this in OPERATIONS-MANUAL or INSTALL notes.

**What I ruled out:**
- Working at 5-second resolution with adjusted thresholds: recalibration risk, loses peer-review validation
- Stein (2012) variability index alone (line-length ratio): less discriminating than CAELUS's four-index approach, no published classification decision tree
- Keeping σ alongside VI: σ is strictly less informative than VI; no reason to keep both
- Hardcoding any sensor model: architectural mistake — Clear Skies is a product for diverse hardware

**What's still uncertain:**
- Whether CLOUD_ENHANCEMENT should display as "Partly Cloudy" or deserves its own label — defaulting to "Partly Cloudy" since cloud enhancement means sun + nearby clouds
- Whether the SZA proxy (maxSolarRad thresholds) is sufficient or we need pvlib — starting without pvlib, adding if needed
- Whether ASOS double-weighting should be retained for any purpose — removing it since CAELUS doesn't use it and the temporal coherence filter serves the same stability purpose

---

## 7. References

- Ruiz-Arias, J.A. & Gueymard, C.A. (2023). CAELUS: Classification of sky conditions from 1-min time series of global solar irradiance using variability indices and dynamic thresholds. *Solar Energy*, 263, 111895. [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0038092X23005285) | [GitHub](https://github.com/jararias/caelus)
- Stein, J.S., Hansen, C.W., & Reno, M.J. (2012). The Variability Index: A New and Novel Metric for Quantifying Irradiance and PV Output Variability. Sandia National Laboratories. [OSTI](https://www.osti.gov/servlets/purl/1078490)
- Duchon, C.E. & O'Malley, M.S. (1999). Estimating cloud type from pyranometer observations. *J. Applied Meteorology*, 38, 132–141. [AMS](https://journals.ametsoc.org/view/journals/apme/38/1/1520-0450_1999_038_0132_ectfpo_2.0.co_2.xml)

---

## 8. CAELUS Source Code Reference (for implementation fidelity)

The executing session MUST fetch and read these files from the CAELUS GitHub repo to verify implementation fidelity. Do not implement from this plan's summary alone — read the source.

| File | URL | Contains |
|------|-----|----------|
| `src/caelus/options.py` | `https://raw.githubusercontent.com/jararias/caelus/main/src/caelus/options.py` | All 14 threshold constants (Table 3), window sizes (DT=30min, DT_F=10min), filter options |
| `src/caelus/sky_indices.py` | `https://raw.githubusercontent.com/jararias/caelus/main/src/caelus/sky_indices.py` | Index computation (Kcs, Km, Kv, Kvf), classification decision tree (`classify_with_pandas()`), GHI mirroring logic |
| `src/caelus/skytype.py` | `https://raw.githubusercontent.com/jararias/caelus/main/src/caelus/skytype.py` | SkyType IntEnum: UNKNOWN=1, OVERCAST=2, THICK_CLOUDS=3, SCATTER_CLOUDS=4, THIN_CLOUDS=5, CLOUDLESS=6, CLOUD_ENHANCEMENT=7 |
| `src/caelus/filters.py` | `https://raw.githubusercontent.com/jararias/caelus/main/src/caelus/filters.py` | Post-classification temporal coherence filters (spurious patch cleaning, transition smoothing) |

**Key CAELUS implementation details the executing session must verify:**

1. **Kv formula:** `diff_abs = |diff(ghi_mirrored - mean_ghi)|` then `Kv = rolling_sum(diff_abs, 30min) / 1800`. The `diff` is the first-difference between consecutive 1-minute records, NOT the deviation from the mean itself.

2. **Km denominator:** CAELUS uses `ghicda` (clear-sky direct-normal approximation), not `ghics` (clear-sky GHI). Our system uses `maxSolarRad` which is a clear-sky GHI model. This is a known deviation — document it.

3. **Classification order matters:** CLOUD_ENHANCEMENT and CLOUDLESS are evaluated BEFORE the cloudy-zone subdivision. The "cloudy" boolean in CAELUS is defined as `daytime & ~cloudless & ~overcast & ~clouden` — it's the remainder.

4. **SZA thresholds in CAELUS:** CLOUD_ENHANCEMENT requires SZA < 80°. CLOUDLESS has two branches: SZA < 75° (tighter Kcs bounds) and SZA ≥ 75° (relaxed Kcs bounds). Our implementation uses maxSolarRad as a SZA proxy — document this deviation.

---

## 9. Operational Note

The operator's weewx station should be configured with `archive_interval = 60` (1-minute archives) for optimal sky classification accuracy on startup. This is set in `weewx.conf` under `[StdArchive]`. The default is 300 (5 minutes). With 1-minute archives, startup backfill provides full CAELUS-quality data immediately. The code handles any archive interval, but 1-minute gives the best results.
