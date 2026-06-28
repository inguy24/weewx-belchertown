# Sky Condition Engine — GHI Mirroring, SZA Guard, Documentation & Operator Calibration

**Status:** COMPLETE (superseded) — The sunrise/sunset misclassification issues this plan addressed were resolved by: (1) SOLAR-MODEL-REPLACEMENT-PLAN (replaced weewx Ryan-Stolzenbach maxSolarRad with pvlib Simplified Solis + CAMS AOD, eliminating the root cause of edge-case Kcs inflation), (2) SKY-CLASSIFICATION-KV-FIRST-PLAN (ADR-073, reworked the decision tree to use Kv as primary discriminator), and (3) HAZE-THRESHOLD-CORRECTIONS-PLAN (fixed calibration sample filtering). GHI mirroring itself was not implemented — the underlying problems it was designed to compensate for were fixed at the source. Archived 2026-06-27.
**Created:** 2026-06-21
**Component:** API (`weewx-clearskies-api`)

---

## Context

On 2026-06-21, the conditions engine showed "Sunny, Scattered Clouds" at sunrise and "Partly Cloudy" at mid-morning while the webcam showed heavy overcast. Two root causes:

1. **Missing GHI mirroring.** CAELUS (our reference system) mirrors post-sunrise GHI measurements backward across the sunrise boundary using cos(zenith) interpolation to stabilize the Km rolling mean. Our implementation omits this — it's a missing piece of the model, not an enhancement. At sunrise, the trailing window has no pre-sunrise data, inflating Km under overcast.

2. **Undocumented threshold research.** The SCATTER_CLOUDS Km sub-splits, OVERCAST Kv sub-splits, Cloud Enhancement labeling, and "Scattered Clouds" vocabulary rules were researched and approved by the user (conversation `6e1a3c4c`, 2026-06-19) but never documented in ADR-044 or the API Manual. The ADR is stale. The Kasten-Czeplak formula (peer-reviewed, Km-to-NWS-okta mapping) provides scientific context for what Km values mean, but sensor accuracy on consumer equipment (Davis ±3-5%, Ambient ±15% spec) means tight thresholds are unreliable. Thresholds should be operator-adjustable via the admin UI.

**Live measurement confirming the problem (2026-06-21 09:26 AM, solar elevation ~35°):**
- GHI: 338.6 W/m², maxSolarRad: 665.2 W/m² → Km = 0.509
- Provider cloud cover: 81% (BKN / Mostly Cloudy by NWS ASOS)
- Webcam: heavy overcast
- Engine output: "Partly Cloudy" — wrong, should be "Mostly Cloudy" at minimum

---

## 0. Orientation — Execution Context

**Read these files before starting any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — coding standards, security, manual compliance
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding, QC gates
- `docs/manuals/API-MANUAL.md` §8 — conditions text engine specification
- `docs/ARCHITECTURE.md` lines 262–283 — conditions text engine module map

**Repo:** `repos/weewx-clearskies-api` — FastAPI + SQLAlchemy. Branch: `main`. Lint: `ruff check`, `mypy`.

**Deploy:**
- API: `ssh -F .local/ssh/config weewx "sudo systemctl restart weewx-clearskies-api"` (~2 min warm cache)

**Key governing manuals (agents read before implementing):**
- `docs/ARCHITECTURE.md` — system topology, conditions engine module map
- `docs/manuals/API-MANUAL.md` — §8 conditions text engine (the spec agents implement from)

**ADR referenced:**
- ADR-044 — Sky condition classification (archived in `docs/archive/decisions/`)

**Git safety:** Agents may ONLY `git add`, `git commit`, `git status`, `git log`, `git diff`. NO pull/push/fetch/rebase/merge/remote/worktree. Coordinator pushes after QC.

**Roles:**
- **Coordinator (Opus):** Owns Phase 0 (science doc + ADR + manuals), QC after every phase, Phase 3 (deploy + verify). Reads all governing docs and codebase personally. Writes agent prompts. QC is never delegated.
- **QA Auditor (`clearskies-auditor`):** Independent oversight. Reviews coordinator QC evidence against acceptance criteria. Flags gaps. Does NOT implement.
- **Implementation agents (Sonnet):** `clearskies-api-dev` for code, `clearskies-test-author` for tests. Execute per coordinator prompts. Read governing manuals before implementing.

---

## 1. Gap Inventory

### A. Missing CAELUS Components

| # | Item | Status | Gap |
|---|------|--------|-----|
| A1 | GHI mirroring | MISSING | CAELUS mirrors GHI across sunrise/sunset via cos(zenith) interpolation. Our implementation omits this entirely. |
| A2 | SZA < 85° classification guard | MISSING | CAELUS returns UNKNOWN for SZA ≥ 85°. Our code classifies down to `_MIN_SOLAR_RAD = 20 W/m²` (~SZA 87°). |
| A3 | Kcs capped at SZA < 87° | PARTIAL | Code uses `_SZA80_MSR_PROXY` and `_SZA75_MSR_PROXY` as maxSolarRad proxies, but no true SZA computation. |

### B. Documentation Gaps

| # | Item | Status | Gap |
|---|------|--------|-----|
| B1 | ADR-044 stale on sub-splits | STALE | ADR shows SCATTER_CLOUDS → "Partly Cloudy" (initial mapping). Code has Km sub-splits with "Scattered Clouds" vocabulary — researched and approved but not documented. |
| B2 | ADR-044 stale on OVERCAST sub-splits | STALE | ADR shows OVERCAST → "Cloudy". Code has Km×Kv sub-splits (Cloudy/Overcast/Heavy Overcast) — researched and approved but not documented. |
| B3 | ADR-044 stale on Cloud Enhancement label | STALE | ADR says "Partly Cloudy". Code returns "Clear". User research said "Mostly Sunny or Sunny" — not documented. |
| B4 | Scientific sources not documented | MISSING | No reference document. K-C formula, sensor tolerances, CAELUS mirroring rationale, Kv detrending citations all absent from docs. |
| B5 | Operator calibration guidance | MISSING | No guidance for operators on how sensor equipment affects classification or how to adjust thresholds. |
| B6 | Haze/smoke detection (ADR-044 §1c) | NOT IMPLEMENTED | ADR describes detection heuristic. Never coded. **Out of scope this plan** — needs further research on AQI thresholds. Documented as known gap. |

### C. Operator Adjustability

| # | Item | Status | Gap |
|---|------|--------|-----|
| C1 | Sky classification admin section | MISSING | No admin UI for threshold adjustment. To be added to ADMIN-CARD-ARCHITECTURE-PLAN.md Phase 3. |

---

## 2. Design Decisions

### GHI Mirroring — Real-Time Adaptation

CAELUS mirrors GHI in batch mode (full day's data). Our real-time adaptation:

1. After sunrise, as GHI readings accumulate in the ring buffer, compute cos(zenith) for pre-sunrise timestamps using Skyfield (`skyfield>=1.48`, already a dependency used in `services/almanac.py`)
2. Build interpolation mapping: cos(zenith) → measured GHI from post-sunrise ring entries
3. Generate mirrored (negative) GHI values at pre-sunrise cos(zenith) positions
4. Include mirrored entries in the rolling mean computation for Km
5. maxSolarRad for pre-sunrise timestamps is computed directly (deterministic — just astronomy)
6. Station lat/lon/altitude available via `get_station_info()` (loaded at startup in `services/station.py`)
7. Skyfield ephemeris already loaded at startup via `wire_ephemeris_directory()` in `__main__.py`

### SZA Guard

Compute solar elevation from Skyfield. When elevation < 5° (SZA > 85°), `classify()` returns None → provider fallback. Matches CAELUS's own filter. Literature standard is 10° (Engerer 2015, Hyytiälä 2020) — starting with 5° since we're implementing mirroring, tighten if needed.

### Km Sub-Split Thresholds — Keep Current, Document, Make Adjustable

Current thresholds (0.6/0.5/0.4 within SCATTER_CLOUDS) stay as the defaults. They were researched and approved by the user. The Kasten-Czeplak formula provides scientific context:

**K-C Formula:** `Km = 1 - 0.75 × (N/8)^3.4` (Kasten & Czeplak 1980)

| N (oktas) | NWS ASOS | NWS Forecast Label | Km (K-C) |
|---|---|---|---|
| 0 | CLR | Sunny | 1.000 |
| 1–2 | FEW | Mostly Sunny | 0.993–0.999 |
| 3–4 | SCT | Partly Cloudy | 0.929–0.973 |
| 5–6 | BKN | Mostly Cloudy | 0.718–0.849 |
| 7 | BKN | Mostly Cloudy | 0.524 |
| 8 | OVC | Cloudy | 0.250 |

K-C's upper boundaries (Clear > 0.99, Mostly Clear > 0.97) are inside consumer sensor noise (Davis ±3-5%, Ambient ~±15%). CAELUS handles "Clear" robustly via the CLOUDLESS anchor (Km > 0.6 + Kcs + Kv constraints) — Clear never goes through the SCATTER_CLOUDS sub-splits.

Thresholds are operator-adjustable via the admin UI (added to ADMIN-CARD-ARCHITECTURE-PLAN.md). Operators with better equipment can tighten; operators with noisier sensors can widen. K-C table and sensor guidance displayed in the admin UI.

### User's Researched Decisions (conversation `6e1a3c4c`, 2026-06-19)

| Decision | User's words | Line |
|---|---|---|
| OVERCAST needs sub-splits (Cloudy/Overcast/Heavy Overcast) | "we got rid of some classifications we needed like overcast and heavy overcast" | 133 |
| Sub-split by curve shape (Kv), not snapshot (Kc) | "the difference between cloudy and overcast has to do with the shape of the curve" / "i don't like using Kc as it is just a snapshot in time" | 142, 201 |
| Kv accepted as roughness metric | "if we think Kv is a decent measure of roughness, then lets use it" | 215 |
| "Scattered Clouds" pairs with Sunny/Clear/Mostly Sunny/Mostly Clear only | "for scattered clouds you would use 'sunny' or 'clear' or 'mostly sunny' or 'mostly clear' with scattered clouds" | 229 |
| "Scattered Clouds" stops at Partly Cloudy | "once you hit partly cloudy or mostly cloudy, you do not say scattered clouds or broken clouds anymore" | 240 |
| Cloud Enhancement → Clear/Sunny (sun IS visible) | User's external research: Class 6 → "Mostly Sunny or Sunny" | 153 |
| External research must be cross-checked | "no let's not assume what I found is source of truth" | 159 |

---

## 3. Implementation Phases

### PHASE 0 — Science Documentation + ADR + Manuals (Documentation First)

**Why first:** Agents implement from the manuals. The GHI mirroring, SZA guard, and threshold documentation are all changes to the conditions engine spec. If the manuals don't describe these before coding starts, agents have no authoritative guidance.

**T0.1 — Create science reference document**
- Owner: Coordinator (Opus)
- File: New `docs/reference/sky-classification-science.md`
- Do: Document all scientific sources with full citations, what each provides, and where each is used in the codebase. Include:

| Source | What it provides | Where used |
|---|---|---|
| Ruiz-Arias & Gueymard 2023 (CAELUS) | 6-class VI classification, thresholds (Table 3), GHI mirroring, SZA guards | sky_condition.py — classification system |
| Kasten & Czeplak 1980 | Cloud cover (oktas) to Km formula; NWS category mapping | Km sub-split scientific context |
| Stein et al. 2012 (Sandia VI, SAND2012-3464C) | Variability Index definition, clear-sky detrending | Kv/Kvf detrending |
| Coimbra et al. 2013 | Clear-sky index stationarity | Kv/Kvf detrending |
| ISO 9060:2018 | Pyranometer accuracy classes (A ≤1.8%, B ≤3%, C ≤5%) | Sensor tolerance context |
| Davis 6450 spec sheet | ±3% (0-70°), ±10% (70-85°) | Consumer sensor accuracy |
| Skartveit & Olseth 1987 | Clearness index + solar elevation model | SZA guard rationale |
| Engerer 2015 | 10° minimum solar elevation standard | SZA guard rationale |
| NWS ASOS (FAA Order 7900.5D §12.4) | CLR/FEW/SCT/BKN/OVC categories | Provider fallback + K-C mapping |
| NWS Directive 10-503 | Public forecast display vocabulary | Day/night display labels |
| Stull 2011 | Wet-bulb temperature formula | Frozen precipitation |

- Include the computed K-C Km-to-oktas table
- Include sensor accuracy comparison table (ISO classes, Davis, Ambient)
- Accept: Every scientific claim in the codebase has a corresponding entry with full citation.

**T0.2 — Amend ADR-044**
- Owner: Coordinator (Opus)
- File: `docs/archive/decisions/ADR-044-sky-condition-classification.md`
- Do: New amendment dated 2026-06-21. Updates §1a with:
  - GHI mirroring description and rationale (CAELUS source reference)
  - SZA < 85° guard (CAELUS source + literature standard)
  - SCATTER_CLOUDS Km sub-split table with "Scattered Clouds" descriptor rules (user's researched decisions with verbatim quotes and conversation reference)
  - OVERCAST Km×Kv sub-split table (user's decision: Kv for curve shape, Kc rejected)
  - Cloud Enhancement → Clear rationale (user's external research)
  - K-C formula and table as scientific context for threshold values
  - Sensor accuracy constraints table
  - Operator calibration guidance reference
  - Kv detrending rationale (Stein et al. 2012, Coimbra et al. 2013)
  - Note haze/smoke detection (§1c) as **known unimplemented gap** — needs further research
  - Full scientific references
- Accept: ADR accurately describes the as-built system plus the new GHI mirroring and SZA guard. Every threshold has documented provenance (CAELUS paper, user research, or K-C formula).

**T0.3 — Update API Manual §8**
- Owner: Coordinator (Opus)
- File: `docs/manuals/API-MANUAL.md`
- Do: Align §8 (Conditions Text Engine) with updated ADR-044:
  - Add GHI mirroring description and SZA guard
  - Document "Scattered Clouds" descriptor rules with user research citation
  - Document OVERCAST Kv sub-splits with user research citation
  - Add "Scientific basis" subsection referencing `docs/reference/sky-classification-science.md`
  - Add operator calibration guidance
  - Note haze/smoke detection as unimplemented gap
  - Reconcile provider fallback thresholds (code ≤10/25/50/85/95 vs ADR 0-6/7-31/32-56/57-87/88-100)
- Accept: Manual consistent with ADR-044 and code. Scientific sources subsection present.

**T0.4 — Update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- File: `docs/ARCHITECTURE.md`
- Do: Update conditions text engine section (lines 262–283) to reflect GHI mirroring, SZA guard, and sub-split documentation.
- Accept: Architecture doc matches code and manual.

**T0.5 — Update ADMIN-CARD-ARCHITECTURE-PLAN.md**
- Owner: Coordinator (Opus)
- File: `docs/planning/ADMIN-CARD-ARCHITECTURE-PLAN.md`
- Do: Add T3.5 to Phase 3: "Sky Classification" admin section where operators can adjust Km sub-split boundaries. Display K-C reference table, current thresholds, sensor guidance, "Reset to defaults" button. Save to `api.conf [sky_classification]` section.
- Accept: Admin plan includes sky classification calibration section.

**QC (Opus) — after Phase 0:** Verify science doc has complete citation for every claim. Verify ADR amendment covers all user research decisions with verbatim quotes. Verify API Manual §8 is consistent with ADR. Verify ARCHITECTURE.md matches. Verify admin plan updated.

**QA Audit (clearskies-auditor) — after Phase 0 QC:** Independently verify (a) every scientific claim in sky_condition.py has a matching citation in the science doc, (b) ADR-044 amendment covers all items from the user research table in §2, (c) API Manual §8 is consistent with the ADR, (d) no manual-to-manual contradictions, (e) admin plan includes the sky classification section. Report findings. Phase 1 does not begin until auditor clears.

### PHASE 1 — Code Changes (GHI Mirroring + SZA Guard)

**Depends on: Phase 0** (agents implement from updated manuals)

**T1.1 — Implement GHI mirroring**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/sse/sky_condition.py`
- Scope in:
  - Add mirroring logic adapted from CAELUS `sky_indices.py:mirror_ghi_with_pandas()`
  - Expand `configure()` to accept station coordinates (lat, lon, altitude)
  - Compute cos(zenith) for pre-sunrise timestamps via Skyfield (import from `services/almanac.py` ephemeris infrastructure, NOT pvlib)
  - Build interpolation: cos(zenith) → measured GHI from post-sunrise ring entries
  - Generate mirrored (negative) GHI values at pre-sunrise cos(zenith) positions
  - Include mirrored entries in rolling mean computation for Km
  - Compute maxSolarRad for pre-sunrise timestamps directly
- Scope out: Do NOT change Km sub-split thresholds, OVERCAST sub-splits, display labels, `conditions_text.py`, `weather_text.py`, scene module, or any downstream consumer of `classify()`.
- Files NOT to touch: `conditions_text.py`, `temperature_comfort.py`, `enrichment/weather_text.py`, `enrichment/input_smoother.py`, `scene.py`
- Accept: At sunrise under overcast, Km is lower than without mirroring. `classify()` return value set unchanged. `ruff check` + `mypy` clean.

**T1.2 — Implement SZA < 85° classification guard**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/sse/sky_condition.py`
- Scope in:
  - In `classify()`, compute current solar elevation from Skyfield
  - If elevation < 5° (SZA > 85°), return None → provider fallback
  - Replaces the `_MIN_SOLAR_RAD = 20` proxy for classification gating (keep `_MIN_SOLAR_RAD` for ring buffer acceptance — data still accumulates below the SZA threshold)
- Accept: At solar elevation < 5°, `classify()` returns None. Provider cloud cover supplies the sky label. At elevation ≥ 5°, classification runs normally.

**T1.3 — Wire station coordinates to sky_condition.configure()**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `weewx_clearskies_api/__main__.py`
- Scope in: Pass lat, lon, altitude from `get_station_info()` to `sky_condition.configure()` at startup (same location where `archive_interval` is already passed).
- Accept: `sky_condition.configure()` receives station coordinates. Skyfield can compute solar position from them.

**QC (Opus) — after Phase 1:**
- `ruff check` + `mypy` clean
- Deploy to weewx container, restart API
- Verify `classify()` returns None at solar elevation < 5° (check during pre-dawn if possible, or unit test)
- Verify Km values at sunrise are lower under overcast than before the change (compare logged values)
- Verify no downstream regressions: `weatherText` still populates, scene descriptor still works, SSE still emits

**QA Audit (clearskies-auditor) — after Phase 1 QC:** Verify (a) mirroring implementation matches CAELUS source logic (cos(zenith) interpolation, negative mirrored values), (b) SZA guard returns None below threshold, (c) `ruff check` + `mypy` evidence present, (d) station coordinates are passed at startup, (e) no files outside scope were modified. Report findings.

### PHASE 2 — Tests

**Depends on: Phase 1**

**T2.1 — Add/update sky_condition tests**
- Owner: `clearskies-test-author` (Sonnet)
- File: `tests/test_sky_condition.py`
- Tests required:

  **GHI mirroring tests:**
  - Mirrored buffer at sunrise produces symmetric GHI values across the sunrise boundary
  - Rolling mean with mirroring is smoother than without at sunrise
  - Km under overcast at sunrise is lower with mirroring than without
  - Mirroring does not affect classification at midday (buffer fully populated, no edge effects)
  - Station coordinates None → mirroring disabled, graceful fallback

  **SZA guard tests:**
  - Solar elevation < 5° → `classify()` returns None
  - Solar elevation ≥ 5° → `classify()` returns a label (not None, given sufficient buffer data)
  - SZA guard does not affect ring buffer data acceptance (data still accumulates below threshold)

  **Regression tests:**
  - All existing classification tests still pass
  - CLOUDLESS, OVERCAST, THIN_CLOUDS, THICK_CLOUDS, SCATTER_CLOUDS, CLOUD_ENHANCEMENT all produce correct labels
  - Temporal coherence filter still works
  - Backfill still works
  - Day/night transition still clears buffer

- Accept: All tests pass. `pytest tests/test_sky_condition.py` green. `ruff check` clean.

**QC (Opus) — after Phase 2:** `pytest` all green. Each test tests what it claims (not just `is not None`). GHI mirroring tests use realistic GHI/maxSolarRad values. SZA guard tests verify both sides of the threshold.

**QA Audit (clearskies-auditor) — after Phase 2 QC:** Verify (a) mirroring tests cover the sunrise edge case that caused the original bug, (b) SZA guard tests verify both below and above threshold, (c) regression tests cover all 6 CAELUS classes, (d) `pytest` evidence present. Report findings.

### PHASE 3 — Deploy + Final Verification

**T3.1 — Verify doc-code sync**
- Owner: Coordinator (Opus)
- Do: Walk API Manual §8, ARCHITECTURE.md, and ADR-044 against the implemented code. Fix any drift.
- Accept: Docs match code.

**T3.2 — Deploy**
- Owner: Coordinator (Opus)
- Do: Push to GitHub. SSH to weewx container, `git pull --ff-only`, restart API (~2 min warm).
- Accept: API starts, `/api/v1/current` returns `weatherText`.

**T3.3 — End-to-end verification**
- Owner: Coordinator (Opus)
- Verify:
  1. `weatherText` populates on `/current` response
  2. At sunrise under overcast: classification is NOT "Sunny, Scattered Clouds" (the bug that triggered this work)
  3. At solar elevation < 5°: classification falls back to provider cloud cover
  4. At midday under clear sky: classification is "Sunny" or "Clear" (no regression)
  5. Scene descriptor still works (backgrounds change with sky condition)
  6. SSE still emits loop events
  7. `pytest` all green on weewx container
  8. ADR-044 amendment matches code. API Manual §8 matches code.

**QA Audit (clearskies-auditor) — final:** Walk every numbered item in T3.3 against the coordinator's evidence. Verify every item has evidence (not assertion). This is the final gate.

---

## 4. Agent Assignments

| Phase | Task | Owner | QC Timing |
|-------|------|-------|-----------|
| 0 | T0.1 Science reference doc | Coordinator (Opus) | After Phase 0 |
| 0 | T0.2 ADR-044 amendment | Coordinator (Opus) | After Phase 0 |
| 0 | T0.3 API Manual update | Coordinator (Opus) | After Phase 0 |
| 0 | T0.4 ARCHITECTURE.md update | Coordinator (Opus) | After Phase 0 |
| 0 | T0.5 Admin plan update | Coordinator (Opus) | After Phase 0 |
| 1 | T1.1 GHI mirroring | `clearskies-api-dev` (Sonnet) | After Phase 1 |
| 1 | T1.2 SZA guard | `clearskies-api-dev` (Sonnet) | After Phase 1 |
| 1 | T1.3 Wire station coords | `clearskies-api-dev` (Sonnet) | After Phase 1 |
| 2 | T2.1 Tests | `clearskies-test-author` (Sonnet) | After Phase 2 |
| 3 | T3.1-T3.3 Deploy + verify | Coordinator (Opus) | After deploy |

**Sequencing:** Phase 0 (docs — MUST complete before coding) → Phase 1 (code — T1.1, T1.2, T1.3 in one agent, one file + `__main__.py`) → Phase 2 (tests) → Phase 3 (deploy + verify).

**No parallelism:** This is a single-file change with documentation. Sequential execution.

---

## 5. QC Gates

### Gate 1 — Code Quality (Phase 1 + 2)
- `ruff check` 0 errors on all modified files
- `mypy` 0 new errors
- `pytest` all tests pass

### Gate 2 — CAELUS Fidelity (Phase 1)
- GHI mirroring logic matches CAELUS `sky_indices.py:mirror_ghi_with_pandas()` (cos(zenith) interpolation, negative mirrored values, applied to rolling mean)
- SZA guard matches CAELUS's own SZA < 85° filter
- Deviations from CAELUS explicitly documented (trailing vs centered window, real-time vs batch mirroring)

### Gate 3 — Interface Compatibility (Phase 1)
- `update()`, `classify()`, `is_daytime()`, `reset()`, `backfill()` signatures unchanged
- `configure()` accepts new optional parameters (station coords) — backward compatible
- Return value set unchanged
- Zero downstream file changes required
- `scene.py` `_SKY_LABEL_TO_BUCKET` handles all returned labels

### Gate 4 — Doc-Code Sync (Phase 0 + 3)
- ADR-044 amendment covers all user research decisions with verbatim quotes
- API Manual §8 consistent with ADR
- ARCHITECTURE.md consistent with code
- Science reference doc covers every scientific claim in the codebase
- Every threshold has documented provenance

---

## 6. Self-Audit

**Risk: GHI mirroring with limited post-sunrise data.** CAELUS mirrors using a full morning's data (batch). Our real-time adaptation has only the data accumulated since sunrise. With 15 minutes of post-sunrise data, the interpolation has few points. Mitigation: Even a few mirrored points stabilize the rolling mean more than zero points. Quality improves as more data accumulates. CAELUS's own temporal coherence filter (15-min persistence) provides a backstop.

**Risk: Skyfield computation cost per classify() call.** Computing solar elevation on every `/current` request adds latency. Mitigation: Cache the computed elevation with a 60-second TTL — solar elevation changes slowly. Skyfield `observe().apparent().altaz()` is fast (~1ms) but caching avoids repeated ephemeris lookups.

**Risk: SZA guard at 5° may be too lenient.** Literature standard is 10°. Pyranometer cosine errors are ±10% at 70-85° incidence (Davis spec). Mitigation: Start with CAELUS's own 5° threshold. If misclassification persists between 5-10° elevation, tighten in a follow-up. The mirroring should handle most of the edge effect.

**Risk: Km sub-split thresholds still conservative.** Current thresholds (0.6/0.5/0.4) are lower than K-C science suggests. The live measurement (Km = 0.509 under heavy overcast → "Partly Cloudy") shows they produce wrong labels for marine layer conditions. Mitigation: Thresholds are kept as-is for now with operator adjustability via admin UI. K-C science is documented so operators (and future sessions) have the context to calibrate. Separate follow-up to evaluate threshold adjustment after observing behavior with mirroring implemented.

**What I ruled out:**
- Adjusting Km sub-split thresholds in this plan — user decision to keep current values and make adjustable
- Haze/smoke detection — needs further AQI threshold research
- pvlib integration — Skyfield is already in the stack, no need for a second ephemeris library

---

## 7. Existing Code Reference

**Key files (current implementation):**

| File | Role |
|------|------|
| `weewx_clearskies_api/sse/sky_condition.py` | Stateful classifier — 30-min ring buffer, CAELUS VI classification, temporal coherence filter. **Primary file to modify.** |
| `weewx_clearskies_api/sse/conditions_text.py` | Stateless composer — assembles weatherText. NOT modified. |
| `weewx_clearskies_api/sse/enrichment/weather_text.py` | Enrichment adapter — calls `classify()` and `is_daytime()`. NOT modified. |
| `weewx_clearskies_api/sse/enrichment/sky_tap.py` | Packet tap — feeds `update()`. NOT modified. |
| `weewx_clearskies_api/sse/scene.py` | Scene builder — maps sky labels to backgrounds. NOT modified. |
| `weewx_clearskies_api/__main__.py` | Startup wiring. Modified to pass station coords to `configure()`. |
| `weewx_clearskies_api/services/almanac.py` | Skyfield ephemeris — `wire_ephemeris_directory()`, `_ts`, `_eph`. Reuse for solar position. |
| `weewx_clearskies_api/services/station.py` | Station metadata — `get_station_info()` returns lat/lon/altitude. |
| `tests/test_sky_condition.py` | Existing tests. Extended in Phase 2. |

**Integration surface (what calls sky_condition):**
- `sky_tap.py` → `update(radiation, max_solar_rad, timestamp)`
- `weather_text.py` → `classify()`, `is_daytime()`
- `scene_enrichment.py` → `classify()`
- `scene_packet_tap.py` → `classify()`
- `conditions_text.py` receives sky label as parameter — does not call sky_condition

**Critical constraint:** The public API of sky_condition.py must not change. All callers use the same signatures. Return values are the same label set.

---

## 8. Known Gaps (Out of Scope)

| Gap | Why deferred | Tracking |
|-----|-------------|----------|
| Haze/smoke detection (ADR-044 §1c) | ADR heuristic written but science on AQI thresholds insufficient (PM2.5 > 35 µg/m³ too low for high-baseline-AQI regions). Wildfire smoke detection requires AQI cross-referencing — different data path. | Document as known gap in ADR-044 amendment |
| Km sub-split threshold tightening | Current values work but are conservative. K-C science suggests higher boundaries. Need observational data with mirroring implemented before adjusting. | Operator-adjustable via admin UI (ADMIN-CARD-ARCHITECTURE-PLAN T3.5) |
| SZA tightening to 10° | Literature standard is 10° minimum. Starting with CAELUS's 5°. | Observe behavior, tighten if needed |
| Provider fallback threshold reconciliation | Code (≤10/25/50/85/95) differs from ADR NWS ASOS (0-6/7-31/32-56/57-87/88-100). Need to determine which was the researched decision. | Reconcile during T0.3 API Manual update |
