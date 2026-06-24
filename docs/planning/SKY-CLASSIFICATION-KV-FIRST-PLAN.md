# Sky Condition Kv-First Decision Tree — Execution Plan

**Status:** PROPOSED
**Created:** 2026-06-23
**Component:** API (`weewx-clearskies-api`), file `sky_condition.py` and downstream consumers
**Brief:** `docs/briefs/SKY-CLASSIFICATION-KV-FIRST-REDESIGN.md`
**Research:** `docs/research/sky-classification/` (01–04)

---

## Context

The current sky condition classifier uses CAELUS's Km-first decision tree, which was designed for solar energy forecasting, not weather reporting. A uniform marine layer covering 100% of the sky at Km ≈ 0.6 falls through to the SCATTER_CLOUDS catch-all and displays as "Mostly Cloudy" — incorrect by NWS definitions (should be "Overcast"). The root cause: the tree uses transmittance (Km) as the primary discriminator where coverage pattern (Kv) should be primary. Six independent studies confirm the inverted-U relationship between cloud fraction and variability, establishing Kv as the correct primary axis.

The brief at `docs/briefs/SKY-CLASSIFICATION-KV-FIRST-REDESIGN.md` documents the full scientific rationale, decision tree design, label set, threshold constants, obstruction composition rules, and system lineage. This plan implements it.

---

## 0. Orientation — Execution Context

**Read before any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety, doc-code sync
- `rules/clearskies-process.md` — ADR discipline, QC gates
- `rules/coding.md` — Python style, type annotations
- `docs/briefs/SKY-CLASSIFICATION-KV-FIRST-REDESIGN.md` — the brief (REQUIRED reading)

**Repo:** `repos/weewx-clearskies-api` — Branch: `main`. Lint: `ruff check`, `mypy`. Tests: `pytest`.

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree.

**QC role: Coordinator (Opus).** QC after EVERY phase. No phase advances without sign-off.

---

## 1. Gap Inventory

### A. Core Classifier

| # | Item | File | Lines | Change |
|---|------|------|-------|--------|
| A1 | `_classify_caelus()` body | `sky_condition.py` | 625–712 | Replace with Kv-first decision tree |
| A2 | CAELUS threshold constants | `sky_condition.py` | 81–98 | Remove 12 old, add 7 new |
| A3 | Module docstring | `sky_condition.py` | 1–58 | Describe Kv-first architecture |
| A4 | `classify()` return docstring | `sky_condition.py` | 192–198 | List 7 labels (no composites) |
| A5 | Cloud enhancement label | `sky_condition.py` | 668 | "Clear" → "Partly Cloudy" |

### B. Downstream Consumers

| # | Item | File | Lines | Change |
|---|------|------|-------|--------|
| B1 | `_SKY_LABEL_TO_BUCKET` | `scene.py` | 65–76 | Remove 2 composite label entries |
| B2 | Scene docstring | `scene.py` | 9–12 | Remove composite label references |
| B3 | `_HAZE_ELIGIBLE_SKY_SUBSTRINGS` | `haze_condition.py` | 95–101 | Remove "Scattered Clouds" |
| B4 | `_DAY_SKY_MAP` | `text_generator.py` | 94–102 | Remove 2 composite entries |
| B5 | `_SKY_LABEL_TO_METAR` | `observation_model.py` | 43–62 | Remove 4 composite entries |
| B6 | `_derive_weather_code()` comments | `weather_text.py` | 98–156 | Remove "Scattered Clouds" refs |
| B7 | `_to_display_label()` docstring | `conditions_text.py` | 134–146 | Remove composite example |

### C. Documentation

| # | Item | Change |
|---|------|--------|
| C1 | New ADR-073 | Kv-first architecture + full conditions methodology (fully supersedes ADR-044) |
| C2 | API-MANUAL.md §8 | Rewrite sky condition subsection (lines 521–614) |
| C3 | ARCHITECTURE.md | Update line 281 classifier description |
| C4 | ADR-044 | Retire entirely — status "Superseded by ADR-073" |
| C5 | DESIGN-MANUAL.md | Add "Heavy Overcast" to background mapping table |

### D. Tests

| # | Item | Change |
|---|------|--------|
| D1 | Classification tests | Rewrite for 7 Kv-first branches + cloud enhancement |
| D2 | `valid_labels` sets (5 locations) | Remove composite labels |
| D3 | Marine layer regression test | NEW — the motivating bug |
| D4 | Haze test composite refs | Remove from `test_haze_condition.py` |

### E. Out of Scope

| Feature | Why |
|---------|-----|
| Kv hysteresis | Deferred to production observation |
| Operator threshold tuning | Deferred to production observation |
| Obstruction hero icons (fog/mist/haze) | Design task, not classifier task |
| Terse display haze-replaces-sky | Dashboard task, needs hero icons first |
| Smoke detection module | Cannot detect with PWS equipment |

---

## 2. Implementation Phases

### PHASE 0 — Documentation FIRST

Documentation updates land before code changes. The manual describes the target architecture; code changes bring implementation into alignment.

**T0.1 — Draft ADR-073: Sky condition Kv-first classification (fully supersedes ADR-044)**
- Owner: `clearskies-docs-author` (Sonnet)
- File: New `docs/decisions/ADR-073-sky-condition-kv-first-classification.md`
- Format: Nygard template at `docs/decisions/_TEMPLATE.md`. Status: **Proposed**.
- **Fully supersedes ADR-044.** ADR-073 is the single authority for conditions-text methodology. It contains:
  - **New content (replaces ADR-044 §1, §6, §7, §8):** Kv-first decision tree, 7-label set, threshold table, cloud enhancement → "Partly Cloudy" change, system lineage.
  - **Carried forward from ADR-044 (unchanged):** §2 clear-sky detrending, §3 dual variability windows, §4 GHI mirroring, §5 SZA guard, §9 provider cloud cover fallback, §10 precipitation (local gauge + wet-bulb filter), §11 temperature-comfort 2D matrix, §12 day/night display vocabulary, §13 temporal coherence filter, §14 haze/smoke detection gap.
- Content: Context (CAELUS misuse, marine layer bug, why ADR-044 is being replaced wholesale), all decision sections covering every topic from ADR-044 (replaced or carried forward verbatim) plus the new Kv-first architecture. References from both the brief and ADR-044.
- Accept: Nygard format. All 7 labels defined. Threshold table present. Every ADR-044 section accounted for (replaced or carried forward). Status = Proposed.

**T0.2 — Rewrite API-MANUAL.md §8 sky condition subsection**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/API-MANUAL.md` lines 521–614
- Do: Replace CAELUS anchor/residual description with Kv-first tree. Remove CAELUS class table, SCATTER_CLOUDS sub-splits, OVERCAST sub-splits. Add new threshold table (7 constants). Update label set (remove composites, add "Overcast"/"Heavy Overcast"). Update day/night vocabulary table. Reference ADR-073 for all classification and methodology decisions (ADR-044 is fully retired).
- Accept: No CAELUS class names in classification section. 7-label set documented. Thresholds match brief.

**T0.3 — Update ARCHITECTURE.md**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/ARCHITECTURE.md` line 281
- Do: Change "VI-based (CAELUS)" to match brief's system lineage description.
- Accept: Description matches the brief's "System Lineage" section.

**T0.4 — Retire ADR-044 (fully superseded by ADR-073)**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/archive/decisions/ADR-044-sky-condition-classification.md`
- Do: Change status to `Superseded by ADR-073`. Add note at top of body: "This ADR is fully superseded by ADR-073, which carries forward the still-valid decisions and replaces the classification architecture." No partial supersession — the entire ADR is retired.
- Accept: Status = Superseded. Clear note that ADR-073 is the sole authority. No reader needs to cross-reference ADR-044 for any active decision.

**T0.5 — Update DESIGN-MANUAL.md background table**
- Owner: `clearskies-docs-author` (Sonnet)
- File: `docs/DESIGN-MANUAL.md` (~line 416–424)
- Do: Add "Heavy Overcast" to the cloudy-background row. Verify all 7 labels appear in the table.
- Accept: All 7 labels present in the table.

**T0.6 — User review and approval of ADR-073**
- Owner: Coordinator (Opus)
- Do: Present ADR-073 to user for review. Status Proposed → Accepted only after explicit user approval. **No code work (Phases 1-3) begins until ADR-073 is Accepted.**
- Accept: User explicitly approves ADR-073.

**QC (Opus) — Phase 0:** Cross-check every label, threshold, and constant in all 5 deliverables against the brief. ADR-073 is Proposed. Manual describes target architecture. **Phase 0 is not complete until T0.6 (user approval) is done.**

---

### PHASE 1 — Code: Decision Tree Replacement

Only `sky_condition.py` is modified. Index computation unchanged.

**T1.1 — Replace threshold constants**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sky_condition.py` lines 81–98
- Do: Remove 12 CAELUS constants (`_CLOUDLESS_MIN_KM`, `_CLOUDLESS_MIN_KCS`, `_CLOUDLESS_MAX_KCS`, `_CLOUDLESS_MAX_KV`, `_THINCLOUDS_*`, `_THICKCLOUDS_*`, `_OVERCAST_MAX_KM`, `_OVERCAST_MAX_KV`). Add 7 new constants per API-MANUAL §8 threshold table. Retain all other constants. Remove `_SZA75_MSR_PROXY` (only consumer is the old CLOUDLESS anchor being replaced — grep confirms).
- Accept: Old constants absent. New constants match API-MANUAL §8. `ruff check` passes.

**T1.2 — Replace `_classify_caelus()` function**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sky_condition.py` lines 625–712
- Do: Replace body with Kv-first tree per API-MANUAL §8. Rename to `_classify_sky()`. Update call site in `classify()`. Cloud enhancement returns "Partly Cloudy" (not "Clear"). Decision flow: cloud enhancement → asymmetric Kv/Kvf gate (variable if Kv ≥ 0.05 OR Kvf ≥ 0.05; uniform if both < 0.05) → uniform (Clear / Overcast / Heavy Overcast) or variable (Mostly Clear / Partly Cloudy / Mostly Cloudy / Cloudy).
- Accept: Exact tree from API-MANUAL §8. Asymmetric gate uses OR for variable, AND for uniform. No composite labels. `ruff check` + `mypy` pass.

**T1.2a — Reduce coherence filter from 15 min to 5 min**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sky_condition.py` `_apply_coherence_filter()`
- Do: Change `consecutive_span >= 900.0` to `consecutive_span >= 300.0`. Change startup grace from `180.0` (3 min) to `120.0` (2 min).
- Accept: Coherence window = 300 s. Startup grace = 120 s.

**T1.3 — Update module docstring**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sky_condition.py` lines 1–58
- Do: Describe Kv-first architecture. Keep index framework description. Replace CAELUS class list with 7-label list. Reference API-MANUAL §8 for methodology. Keep CAELUS reference for index computation heritage only.
- Accept: Docstring matches implemented architecture.

**T1.4 — Update `classify()` return docstring**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `sky_condition.py` lines 192–198
- Do: List 7 labels + None. Remove composite labels.
- Accept: Docstring lists exactly 7 labels + None.

**QC (Opus) — Phase 1:** Walk decision tree against API-MANUAL §8. Verify cloud enhancement → "Partly Cloudy". Verify `_SZA75_MSR_PROXY` removal is safe (grep). `ruff check` + `mypy`. Do NOT run tests yet (Phase 3 updates them).

---

### PHASE 2 — Code: Downstream Consumer Cleanup

Remove dead composite label handling. Small changes across 6 files.

**T2.1 — Clean up `scene.py`**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Remove "Clear, Scattered Clouds" and "Mostly Clear, Scattered Clouds" from `_SKY_LABEL_TO_BUCKET` (lines 67, 69). Update docstring (lines 9–12). Keep "Heavy Overcast": "cloudy" (existing, correct).
- Accept: No composite labels. All 7 new labels have a bucket.

**T2.2 — Clean up `haze_condition.py`**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Remove "Scattered Clouds" from `_HAZE_ELIGIBLE_SKY_SUBSTRINGS` (line 100). `_BLOCKED_SKY_LABELS` needs no change (already correct).
- Accept: No "Scattered Clouds" in haze module.

**T2.3 — Clean up `text_generator.py`**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Remove "Clear, Scattered Clouds" and "Mostly Clear, Scattered Clouds" entries from `_DAY_SKY_MAP` (lines 97–98).
- Accept: No composite labels in day sky map.

**T2.4 — Clean up `observation_model.py`**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Remove 4 composite label entries from `_SKY_LABEL_TO_METAR` (lines 50–53).
- Accept: No composite labels in METAR mapping.

**T2.5 — Clean up `weather_text.py` comments**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Update comments at lines 31, 102–103 to remove "Scattered Clouds" references. Code logic unchanged (substring matching already handles new labels).
- Accept: Comments reference 7-label set.

**T2.6 — Clean up `conditions_text.py` docstring**
- Owner: `clearskies-api-dev` (Sonnet)
- Do: Update `_to_display_label()` docstring (line 138) to remove composite label example. Function logic needs no change — `replace("Clear", "Sunny")` works on new labels.
- Accept: No composite label references in docstring.

**QC (Opus) — Phase 2:** `grep -r "Scattered Clouds" weewx_clearskies_api/sse/` → zero hits. `ruff check` + `mypy` pass.

---

### PHASE 3 — Tests

Rewrite classification tests. Infrastructure tests (binning, backfill, coherence, SZA guard, mirroring) are largely unchanged — they test index computation, not classification labels.

**Runtime environment:** The API lives on the `weewx` container (192.168.7.20), not weather-dev. All pytest runs happen on weewx: `ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && .venv/bin/pytest tests/ -v"`. Do NOT run tests on weather-dev.

**T3.1 — Update valid_labels sets and docstrings**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_sky_condition.py`
- Do: Replace all `valid_labels` sets (5 locations: lines 242, 689, 971, 1003, 1276) with `{"Clear", "Mostly Clear", "Partly Cloudy", "Mostly Cloudy", "Cloudy", "Overcast", "Heavy Overcast"}`. Update module docstring. Remove all composite label strings from entire file.
- Accept: No composite labels in test file. All valid_labels sets have 7 labels.

**T3.2 — Rewrite classification tests (Group 2)**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_sky_condition.py`
- Do: Replace Group 2 (lines 248–348) with 8 tests covering each branch:
  - `test_uniform_clear` — constant GHI=800, msr=900, both Kv AND Kvf < 0.05 → "Clear"
  - `test_uniform_overcast` — constant GHI=500, msr=900, both Kv AND Kvf < 0.05 → "Overcast"
  - `test_uniform_heavy_overcast` — constant GHI=100, msr=900, both Kv AND Kvf < 0.05 → "Heavy Overcast"
  - `test_variable_mostly_clear` — alternating GHI, Kv OR Kvf ≥ 0.05, Km > 0.85 → "Mostly Clear"
  - `test_variable_partly_cloudy` — alternating GHI, Kv OR Kvf ≥ 0.05, 0.60 < Km < 0.85 → "Partly Cloudy"
  - `test_variable_mostly_cloudy` — alternating GHI, Kv OR Kvf ≥ 0.05, 0.40 < Km < 0.60 → "Mostly Cloudy"
  - `test_variable_cloudy` — alternating GHI, Kv OR Kvf ≥ 0.05, Km < 0.40 → "Cloudy"
  - `test_cloud_enhancement` — GHI oscillating above msr → "Partly Cloudy"
  - `test_asymmetric_gate_kvf_triggers_variable` — 30-min Kv < 0.05 but 10-min Kvf ≥ 0.05 (recent cloud transit) → enters variable branch, not uniform
  - `test_asymmetric_gate_both_calm_for_uniform` — both Kv AND Kvf < 0.05 → enters uniform branch
  - Each test docstring traces expected indices through the decision tree.
- Accept: All 10 tests assert exact labels and pass.

**T3.3 — Add marine layer regression test**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_sky_condition.py`
- Do: New `test_marine_layer_classifies_overcast()` — constant GHI≈550, msr=900 (Km≈0.61, Kv≈0). Docstring explains: "Motivating scenario for Kv-first redesign. Marine layer at Km~0.6, Kv~0 should be 'Overcast', not 'Mostly Cloudy'."
- Accept: Asserts result == "Overcast". Passes.

**T3.4 — Replace `test_all_six_caelus_classes`**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_sky_condition.py` line 1255
- Do: Replace with `test_all_kv_first_branches_produce_labels()` covering all 8 outcomes.
- Accept: Passes.

**T3.5 — Clean up haze test composite references**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_haze_condition.py` lines 722–725
- Do: Remove "Scattered Clouds", "Clear, Scattered Clouds", "Mostly Clear, Scattered Clouds" from haze-eligible test list.
- Accept: No composite labels in haze test file.

**T3.6 — Run full test suite on weewx**
- Owner: `clearskies-test-author` (Sonnet)
- Do: `ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && .venv/bin/pytest tests/ -v"`. Report pass/fail/skip counts.
- Accept: All tests pass. Zero failures.

**QC (Opus) — Phase 3:** Read classification tests — verify each traces through correct branch. Verify marine layer regression test present. `grep "Scattered Clouds" tests/` → zero hits. `pytest` all pass (run on weewx). `ruff check` on test files.

---

### PHASE 4 — Integration Verification + Deploy

**T4.1 — Full lint + type + test verification on weewx**
- Owner: Coordinator (Opus)
- Do: SSH to weewx, run `ruff check`, `mypy`, `pytest tests/ -v` in the API repo venv.
- Accept: All clean.

**T4.2 — Deploy (user-authorized)**
- Owner: Coordinator (Opus)
- Prerequisite: User explicitly instructs push.
- Do: Push, restart API, wait ~2 min warm-up.
- Accept: API serves responses with new labels.

**T4.3 — Live verification**
- Owner: Coordinator (Opus)
- Do: Monitor during next marine layer event. Verify "Overcast" (not "Mostly Cloudy").
- Accept: Marine layer correctly classified at least once. Ongoing — not blocking.

---

## 3. Agent Assignments

| Phase | Task | Owner | Model | QC Timing |
|-------|------|-------|-------|-----------|
| 0 | T0.1–T0.5 Documentation | `clearskies-docs-author` | Sonnet | After T0.5 |
| 0 | T0.6 User approval of ADR-073 | Coordinator | Opus | **GATE — blocks Phases 1–3** |
| 1 | T1.1–T1.4 Decision tree | `clearskies-api-dev` | Sonnet | After Phase 1 |
| 2 | T2.1–T2.6 Downstream cleanup | `clearskies-api-dev` | Sonnet | After Phase 2 |
| 3 | T3.1–T3.5 Test rewrite | `clearskies-test-author` | Sonnet | After Phase 3 |
| 3 | T3.6 Full suite run (on weewx) | `clearskies-test-author` | Sonnet | After Phase 3 |
| 4 | T4.1–T4.3 Verify + deploy | Coordinator | Opus | After Phase 3 |

**Sequencing:** Phase 0 (docs + ADR approval) → Phase 1 (tree) → Phase 2 (cleanup) → Phase 3 (tests, on weewx) → Phase 4 (verify + deploy). Strictly sequential — each phase depends on the previous. **Phase 0 gates on user approval of ADR-073 before any code work begins.**

---

## 4. QC Gates

### Gate 1 — Code Quality (every phase)
- `ruff check` 0 errors
- `mypy` 0 introduced errors
- `pytest` all pass (from Phase 3)

### Gate 2 — Feature Correctness
- Phase 1: Decision tree walk matches API-MANUAL §8
- Phase 2: `grep "Scattered Clouds" sse/` → 0 hits
- Phase 3: 8 classification tests + marine layer regression test pass

### Gate 3 — Manual Compliance (code is written against manuals, not ADRs)
- API-MANUAL §8: Code implements the 7-label set, threshold table, decision tree, and all methodology rules as documented in the manual
- API-MANUAL §8: Scene mapping (`_SKY_LABEL_TO_BUCKET`) covers all 7 labels
- API-MANUAL §8: Haze eligibility (`_HAZE_ELIGIBLE_SKY_SUBSTRINGS`, `_BLOCKED_SKY_LABELS`) correct for 7-label set
- DESIGN-MANUAL: Background mapping table includes all 7 labels
- ARCHITECTURE.md: Classifier description matches implemented architecture

### Gate 4 — ADR Housekeeping
- ADR-073: Proposed (Phase 0) → Accepted after user approval (T0.6). Documents the science and rationale. Served its purpose once manuals are updated.
- ADR-044: Fully retired (status = Superseded by ADR-073). No active references remain in manuals.

---

## 5. Self-Audit

**Risk: `_SZA75_MSR_PROXY` removal.** Old CLOUDLESS anchor had SZA-dependent Kcs bounds. New tree uses `kcs > 0.80` unconditionally. SZA guard at 5° elevation (unchanged) prevents extreme low-sun classification. Grep confirms `_SZA75_MSR_PROXY` has no other consumers — safe to remove.

**Risk: Cloud enhancement label change ("Clear" → "Partly Cloudy").** Changes observable behavior. Old: "Sunny" during enhancement. New: "Partly Cloudy." More accurate — enhancement requires nearby clouds. Scene mapping: "Partly Cloudy" → "clear" bucket (existing, line 70) — background unchanged. WMO code: 0 → 2 (more accurate).

**Risk: Kv threshold sensitivity.** `_KV_UNIFORM = 0.05` is moderate confidence. If sensor noise floor > 0.05 under uniform sky, overcast misclassifies into variable branch. The asymmetric gate makes this slightly more likely (Kvf alone can trigger variable), but the 5-minute coherence filter still prevents flicker. Single constant to adjust if needed.

**Risk: Coherence filter at 5 minutes.** Shorter than the original 15 minutes. A passing cloud transit takes 1-3 minutes, so 5 minutes still prevents single-transit flicker. If in practice we see rapid bouncing, the threshold can be raised. The asymmetric Kv/Kvf gate already provides directional stability (hard to enter uniform), so the coherence filter's job is lighter.

**Risk: Asymmetric gate false variable entry.** If Kvf briefly spikes above 0.05 from sensor noise (not actual cloud transits), the gate enters the variable branch when the sky is uniform. Worst case: a uniform overcast sky at Km ≈ 0.5 would classify as "Mostly Cloudy" (variable, Km > 0.40) instead of "Overcast" (uniform). This is a degraded but not catastrophic label — still indicates heavy cloud. The 5-minute coherence filter prevents momentary spikes from reaching the display.

**Risk: Test Kv calculation.** Variable-branch tests need GHI patterns producing Kv > 0.05. For alternating GHI 800/200 with constant msr over 30 minutes: Kv = 29 × 600 / 1800 ≈ 9.67 — well above threshold. Asymmetric gate tests need patterns where Kv < 0.05 but Kvf ≥ 0.05 (recent variability only in last 10 min). Test author must calculate specific values.

**Pre-existing gap (out of scope):** "Partly Sunny" not in `_SKY_LABEL_TO_METAR`. Text generator produces it but observation model doesn't map it. Flagged, not fixed.
