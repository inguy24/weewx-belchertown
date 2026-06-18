# Sky Condition Classification Fix — Execution Plan

**Status:** FINAL
**Component:** `weewx-clearskies-realtime` sky condition classifier + conditions text composer
**ADRs:** ADR-044 (sky condition classification)
**Architecture:** ARCHITECTURE.md (conditions text engine section, Known gap #8)

---

## Context

On 2026-06-06, four rapid commits rewrote sky_condition.py thresholds. The final commit (13f8f26) tightened "Clear" from kc ≥ 0.85 to kc ≥ 0.95 because the old value reportedly called 4-okta partly cloudy skies "Clear." But 0.95 overcorrected — typical pyranometer accuracy and clear-sky model error means a perfectly clear sky can produce kc ~0.93 from systematic bias alone. The threshold is inside the sensor's noise floor.

On 2026-06-08, a visibly clear blue sky (963.3 W/m², webcam confirms) is classified "Mostly Clear." The ADR was never updated after any of the four commits.

**Root cause:** The 4-okta misclassification should have been caught by the sigma axis (broken clouds produce high variability → high-sigma branch → no "Clear" option), not by tightening the kc threshold in the low-sigma branch. The sigma IS the cloud detector — that's the whole point of the 30-minute sliding window.

**Additional gap:** NWS uses "Sunny"/"Mostly Sunny" during the day and "Clear"/"Mostly Clear" at night. The code uses night vocabulary around the clock.

---

## Repo locations & key files

| Repo | Local path | Branch |
|------|-----------|--------|
| Realtime (API) | `repos/weewx-clearskies-realtime` | main |
| Meta (plans, ADRs) | `.` (root) | master |

**Read before acting:** `CLAUDE.md`, `rules/coding.md`, `rules/clearskies-process.md`, `docs/decisions/ADR-044-sky-condition-classification.md`, `docs/ARCHITECTURE.md`

---

## Classification thresholds (new)

### Low sigma (< 0.08) — uniform sky, no cloud transits detected

| mean(kc) | Day label | Night label | Physical meaning |
|----------|-----------|-------------|------------------|
| ≥ 0.85 | Sunny | Clear | Uniform irradiance near clear-sky level |
| 0.70–0.85 | Mostly Sunny | Mostly Clear | Thin uniform dimming (cirrus, haze, marine layer) |
| 0.50–0.70 | Partly Cloudy | Partly Cloudy | Thin uniform overcast |
| 0.30–0.50 | Mostly Cloudy | Mostly Cloudy | Moderate uniform overcast |
| < 0.30 | Cloudy | Cloudy | Thick uniform cover |

### High sigma (≥ 0.08) — variable sky, cloud transits detected

| mean(kc) | Day label | Night label | Physical meaning |
|----------|-----------|-------------|------------------|
| ≥ 0.85 | Mostly Sunny | Mostly Clear | Infrequent cloud passages, mostly sun |
| 0.60–0.85 | Partly Cloudy | Partly Cloudy | Frequent cloud passages |
| < 0.60 | Mostly Cloudy | Mostly Cloudy | Mostly cloud with sun breaks |

### What changes vs current code

| Parameter | Current | New | Why |
|-----------|---------|-----|-----|
| `_KC_CLEAR` | 0.95 | 0.85 | Inside sensor noise floor; sigma already catches clouds |
| `_KC_MOSTLY_CLEAR` | 0.90 | 0.70 | Widens band for thin cirrus/haze |
| `_KC_PARTLY_CLOUDY` | 0.75 | 0.50 | Aligns with uniform overcast physics |
| `_KC_MOSTLY_CLOUDY` | 0.45 | 0.30 | Aligns with moderate overcast |
| `_KC_VAR_MOSTLY_CLEAR` | 0.85 | 0.85 | No change |
| `_KC_VAR_PARTLY_CLOUDY` | 0.65 | 0.60 | Slight adjustment |
| `_KC_VAR_MOSTLY_CLOUDY` | 0.45 | removed | < 0.60 = Mostly Cloudy, no separate constant |
| "Overcast" label | used | "Cloudy" | NWS display vocabulary |
| Day/night vocabulary | not implemented | Sunny/Mostly Sunny (day) | NWS standard |
| Sigma threshold | 0.08 | 0.08 | No change |
| Hysteresis | ±0.03 | ±0.03 | No change |
| ASOS weighting | yes | yes | No change |

---

## Implementation phases

### PHASE A — Code changes (Realtime repo)

**T-A1 — Update kc thresholds in sky_condition.py**
- Owner: `clearskies-realtime-dev` · QC: coordinator (pytest green)
- File: `weewx_clearskies_realtime/sky_condition.py`
- Scope in: Threshold constants (lines 56–67), `_classify_raw()` (lines 180–201), `_classify_with_hysteresis()` (lines 204–240)
- Scope out: Do NOT change buffer management, `update()`, ASOS weighting, `is_daytime()`, or `_SIGMA_THRESHOLD`/`_HYSTERESIS`
- Do:
  - Set: `_KC_CLEAR = 0.85`, `_KC_MOSTLY_CLEAR = 0.70`, `_KC_PARTLY_CLOUDY = 0.50`, `_KC_MOSTLY_CLOUDY = 0.30`
  - Set: `_KC_VAR_MOSTLY_CLEAR = 0.85`, `_KC_VAR_PARTLY_CLOUDY = 0.60`
  - Remove `_KC_VAR_MOSTLY_CLOUDY` (high sigma + kc < 0.60 = "Mostly Cloudy")
  - Replace all `"Overcast"` string literals with `"Cloudy"`
  - Update `_classify_raw()` and `_classify_with_hysteresis()` to match new thresholds
  - Update module docstring comment block to reflect new threshold derivation
- Accept: kc=0.92 low sigma → "Clear". kc=0.78 low sigma → "Mostly Clear". kc=0.50 low sigma → "Partly Cloudy". kc=0.80 high sigma → "Partly Cloudy". kc=0.90 high sigma → "Mostly Clear".

**T-A2 — Add day/night vocabulary mapping**
- Owner: `clearskies-realtime-dev` · QC: coordinator (pytest green)
- Files: `conditions_text.py`, `enrichment/weather_text.py`
- Scope in: Vocabulary mapping only. Do NOT change classification logic in `sky_condition.py`.
- Do:
  - In `conditions_text.py`: add `_to_display_label(sky_label: str, is_daytime: bool) -> str` that maps "Clear" → "Sunny" and "Mostly Clear" → "Mostly Sunny" when `is_daytime=True`, passes all other labels through unchanged
  - In `build_weather_text()`: apply `_to_display_label()` to `effective_sky` before appending to parts. Use `_sky_condition_module.is_daytime()` for the flag
  - In `enrichment/weather_text.py`: update `_cloud_pct_to_sky()` to accept `is_day: bool` and return day vocabulary when True
  - In `enrichment/weather_text.py`: update `_derive_weather_code()` to handle "Sunny"/"Mostly Sunny" as aliases for "Clear"/"Mostly Clear" in the WMO code mapping
- Accept: Daytime weatherText reads "Sunny" or "Mostly Sunny". Night weatherText reads "Clear" or "Mostly Clear". weatherCode derivation works with both vocabularies.

### PHASE B — Test updates (Realtime repo)

**T-B1 — Update classifier tests**
- Owner: `clearskies-test-author` · QC: coordinator (pytest green)
- File: `tests/test_sky_condition.py`
- Do:
  - Update `test_clear_sky()` docstring (threshold is now 0.85, kc=0.92 still passes)
  - Add `test_clear_sky_at_boundary()`: kc=0.85 low sigma → "Clear"
  - Add `test_mostly_clear_low_sigma()`: kc=0.78 low sigma → "Mostly Clear"
  - Update `test_overcast()`: kc=0.50 low sigma → now "Partly Cloudy" (not "Overcast"); rename test
  - Add `test_cloudy_low_sigma()`: kc=0.25 low sigma → "Cloudy"
  - Update `test_partly_cloudy()` + `test_mostly_cloudy()` for new high-sigma thresholds
  - Update all docstrings to reference correct threshold values
  - Verify hysteresis tests work with new boundaries
- Accept: All tests green. Every threshold boundary has an explicit test.

**T-B2 — Add day/night vocabulary tests**
- Owner: `clearskies-test-author` · QC: coordinator (pytest green)
- Files: `tests/test_conditions_text.py`, `tests/test_weather_text_enrichment.py`
- Do:
  - Add test: daytime + sky="Clear" → weatherText contains "Sunny" (not "Clear")
  - Add test: night + sky=None + provider_sky="Clear" → weatherText contains "Clear"
  - Add test: daytime + sky="Mostly Clear" → weatherText contains "Mostly Sunny"
  - Add test: "Partly Cloudy" unchanged day and night
  - Add test: _cloud_pct_to_sky with is_day=True returns "Sunny"/"Mostly Sunny"
  - Add test: weatherCode maps "Sunny" → 0 and "Mostly Sunny" → 1 (same as Clear/Mostly Clear)
- Accept: All tests green.

### PHASE C — Documentation (Meta repo)

**T-C1 — Amend ADR-044**
- Owner: `clearskies-docs-author` · QC: `clearskies-auditor`
- File: `docs/decisions/ADR-044-sky-condition-classification.md`
- Do:
  - Add amendment header (date 2026-06-08)
  - Replace §1a classification table with new 2-table format (low sigma / high sigma) matching code
  - Document: sigma threshold = 0.08, ASOS double-weighting, hysteresis ±0.03
  - Amend §2: add day/night vocabulary mapping table (Sunny/Mostly Sunny vs Clear/Mostly Clear)
  - Note: "Overcast" replaced with "Cloudy" (NWS display vocabulary)
  - Note: June 5 sigma-first simplification (low-sigma = only Clear/Overcast) revised — intermediate tiers legitimate for cirrus/haze
  - Note: research basis — typical pyranometer accuracy + maxSolarRad model error makes kc ≥ 0.95 unreliable (sensor-agnostic)
- Accept: ADR table matches code. No undocumented behaviors.

**T-C2 — Update ARCHITECTURE.md**
- Owner: `clearskies-docs-author` · QC: `clearskies-auditor`
- File: `docs/ARCHITECTURE.md`
- Do:
  - Close Known gap #8 → move to Resolved gaps table (provider_sky IS wired via `_cloud_pct_to_sky()`)
  - Update "Conditions text engine" section: mention day/night vocabulary, note updated thresholds
  - Update "Last verified" date
- Accept: Gap #8 resolved. Section matches deployed code.

---

## QC gates

### Gate 1 — Code quality (every phase)
- `ruff check` + `mypy` → 0 introduced errors
- No dead code, unused imports, commented-out blocks

### Gate 2 — Feature correctness
- `pytest tests/test_sky_condition.py` → all green
- `pytest tests/test_conditions_text.py` → all green
- `pytest tests/test_weather_text_enrichment.py` → all green

### Gate 3 — ADR compliance
- ADR-044 §1a table matches `sky_condition.py` thresholds exactly
- ADR-044 §2 matches `conditions_text.py` vocabulary mapping
- ARCHITECTURE.md Known gap #8 marked resolved

---

## Agent assignments

| Phase | Task | Owner | QC |
|-------|------|-------|----|
| A | T-A1 Thresholds | `clearskies-realtime-dev` | Coordinator: pytest green |
| A | T-A2 Day/night vocab | `clearskies-realtime-dev` | Coordinator: pytest green |
| B | T-B1 Classifier tests | `clearskies-test-author` | Coordinator: pytest green |
| B | T-B2 Vocab tests | `clearskies-test-author` | Coordinator: pytest green |
| C | T-C1 ADR-044 | `clearskies-docs-author` | `clearskies-auditor` |
| C | T-C2 ARCHITECTURE.md | `clearskies-docs-author` | `clearskies-auditor` |

**Phasing:** A first (code). B after A (tests need new thresholds). C parallel with B (docs independent of tests).

**Agent dispatch:** ONE agent per phase (A: realtime-dev, B: test-author, C: docs-author). Three agents total.

---

## Files to modify

### Realtime repo
| File | Tasks |
|------|-------|
| `weewx_clearskies_realtime/sky_condition.py` | A1 |
| `weewx_clearskies_realtime/conditions_text.py` | A2 |
| `weewx_clearskies_realtime/enrichment/weather_text.py` | A2 |
| `tests/test_sky_condition.py` | B1 |
| `tests/test_conditions_text.py` | B2 |
| `tests/test_weather_text_enrichment.py` | B2 |

### Meta repo
| File | Tasks |
|------|-------|
| `docs/decisions/ADR-044-sky-condition-classification.md` | C1 |
| `docs/ARCHITECTURE.md` | C2 |

### Files NOT to touch
- Any API or dashboard code
- `sky_condition.py` buffer management, `update()`, `is_daytime()`
- `enrichment/input_smoother.py`, `enrichment/ring_buffer.py`

---

## Scope exclusions

| Feature | Why excluded |
|---------|-------------|
| pvlib-python integration | weewx maxSolarRad working fine as reference |
| Anomalous turbidity heuristic | Separate feature, not part of this fix |
| Civil twilight handling | Deferred — binary is_daytime() sufficient for now |
