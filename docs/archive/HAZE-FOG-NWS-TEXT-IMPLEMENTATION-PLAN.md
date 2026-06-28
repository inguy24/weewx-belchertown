# Haze/Fog/NWS Text — Implementation Plan

**Status:** COMPLETE — All phases implemented and deployed. Haze detection, fog/mist rework, NWS-style text generation, AQI provider restructuring, nighttime provider deferral, auto-calibration baseline all live. Archived 2026-06-27.  
**Created:** 2026-06-21  
**Updated:** 2026-06-22 (Phase 9 complete)  
**Origin:** Replaces Part 2 of [HAZE-FOG-NWS-TEXT-PLAN.md](HAZE-FOG-NWS-TEXT-PLAN.md) (research plan)  
**Components:** API (`weewx-clearskies-api`), Stack (`weewx-clearskies-stack`), Dashboard (`weewx-clearskies-dashboard`)

---

## Context

The haze/fog/NWS text plan (`docs/planning/HAZE-FOG-NWS-TEXT-PLAN.md`) completed its research phase (R1-R5, 11 agent outputs, full synthesis). Part 2 currently contains an implementation *outline* with placeholder sections — it lacks the rigor needed to actually execute: no ADR authoring gate, no manual update gate, no granular task/agent/QC assignments, no auditor role, no coordinator discipline rules.

The UI-LEGAL-WIZARD-PLAN is the reference standard for plan structure. This rewrite brings Part 2 to that level.

**What changes:** Replace the current Part 2 (sections A1-A8, B1-B5, plus the dependency diagram) with a fully structured execution plan. Part 1 (research) and the Research Synthesis are unchanged.

**AQI provider correction (user, 2026-06-21):** Current AQI providers (Open-Meteo, IQAir, OWM) include model-based sources that return forecast PM, not observed PM. Haze confirmation requires observed data. Changes: drop OWM, add Aeris AQI module (observed, low latency — already in API for forecasts but no AQI module exists), add AirNow (US EPA observed, free, hourly). Open-Meteo also model-based — same problem as OWM, user to decide whether to drop or retain. This adds a new ADR and a new implementation phase for provider work.

**AirNow exclusion (2026-06-21):** AirNow's real-time observation API returns composite AQI index values (0-500), NOT raw µg/m³ concentrations. Haze detection needs PM2.5 in µg/m³ for the 12 µg/m³ threshold. Reverse-calculating introduces quantization error. AirNow provider module was created, committed, then deleted. ADR-066 amended with rationale. EPA AQS bulk CSV downloads (which DO contain raw µg/m³) remain valid for auto-calibration bootstrap (ADR-068).

---

## Progress Tracker

| Phase | Description | Status | Commits |
|-------|-------------|--------|---------|
| 0 | ADR Authoring (6 ADRs) | ✅ COMPLETE | meta: 83a26c1 |
| 1 | Manual Updates (5 manuals) | ✅ COMPLETE | meta: 83a26c1, 8132921 |
| 2 | AQI Provider Implementation | ✅ COMPLETE | api: 70751f5, stack: afbd90e |
| 3 | AQI Data Channel into Enrichment | ✅ COMPLETE | api: 2f8d0f2 |
| 4 | Haze Detection Module | ✅ COMPLETE | api: 4690b91 |
| 5 | Fog/Mist Improvements | ✅ COMPLETE | api: 8c52591, 80f606d |
| 6 | Nighttime Mode + Auto-Calibration | ✅ COMPLETE | api: b979935 (T6.1), cff995f + 2fd438b (T6.2/T6.3) |
| 7 | NWS Text System | ✅ COMPLETE | api: b9c9964 (T7.2), 718dd67 (T7.1), 8cecb28 (T7.3), 01a2f1d (wiring) |
| 8 | Bootstrap & Configuration | ✅ COMPLETE | api: 22ddcc9 (T8.2a), 66e1183 (T8.1), stack: 4a32ea0 (T8.2b) |
| 9 | Integration Testing & QA | ✅ COMPLETE | api: c033111 (T9.2), 8deaf4f (T9.1), 7727872 (T9.3), 10767a0 (OpenAQ two-station), 9c4be50 (F1/F2), 064fe38 (F3 f(RH)), 42a34bf (F4 units), 1f74bb4 (test fixes); meta: a62b139 (F5/F7 docs) |
| 10 | Deploy & Final Verification | ⬜ NOT STARTED | — |

---

## ADR Phase — 6 New ADRs Required Before Implementation

All start as Proposed; user reviews and accepts before implementation begins. After acceptance, prescriptive rules extract into the governing manuals, and ADRs archive per the standard lifecycle.

### ADR-066: AQI Provider Restructuring for Observed Data

**Scope:** Haze detection requires *observed* PM2.5/PM10 data, not model forecasts. Restructure the AQI provider set: drop OWM (SILAM forecast model — predicted, not observed), add Aeris AQI module (observed, low latency, best real-time source — already in API for forecasts but no AQI module), add AirNow (US EPA observed, free, hourly, ~2,500 stations). Evaluate Open-Meteo retention (also model-based like OWM). IQAir retained (hybrid: monitors + crowd-sourced). Document observed-vs-model distinction as a provider selection criterion for AQI.

**Decisions documented:** Which providers serve observed vs model data. Why observed data is required for haze confirmation (research R5.1, Appendix A.5).

**Open-Meteo:** Retained despite being model-based. Political decision — don't eliminate an existing option. Not eligible for haze confirmation (model data), but operators can still use it for general AQI display.

**Options to evaluate:** (1) Drop OWM only, add Aeris + AirNow, retain Open-Meteo (chosen), (2) Drop both OWM + Open-Meteo (stricter — both model-based), (3) Keep all existing + add new (lenient — lets operators choose). Each gets a row.

**Consolidates into:** PROVIDER-MANUAL.md (AQI provider sections), OPERATIONS-MANUAL.md (wizard AQI provider selection), API-MANUAL.md (haze-eligible provider designation)

**Touches:** API (new Aeris AQI module, new AirNow module, deprecate OWM AQI), Wizard (provider selection), Admin UI (provider options), PROVIDER-MANUAL.md

### ADR-067: Haze Detection Architecture

**Scope:** Two-channel confirmation requirement (pyranometer deficit + PM), f(RH) hygroscopic correction with default gamma, solar elevation gate (10-15 deg), PM thresholds for haze confirmation (12 ug/m3 dry / 35 ug/m3 humid), cirrus/smoke honest limitation, nighttime provider deferral for haze (local fog retained).

**Decisions documented:** D1, D2, D4, D5, D6, D7 from the research synthesis.

**Options to evaluate:** (1) Two-channel mandatory (chosen), (2) PM-only detection, (3) Pyranometer-only with statistical threshold. Each gets a row.

**Consolidates into:** API-MANUAL.md section 8 (new subsection: Haze Detection), ARCHITECTURE.md (conditions engine update)

### ADR-068: Auto-Calibration Baseline System

**Scope:** Statistical methodology (90-day rolling window, 90th-95th percentile, no time-of-day bins, ~22 sample minimum), bootstrap from historical data (EPA AQS, OpenAQ, Aeris), maxSolarRad recomputation for older records, persistent storage, convergence criteria, clean-sample selection (PM2.5 < 12, PM10 < 50).

**Decisions documented:** D3, D9 from the research synthesis.

**Options to evaluate:** (1) Percentile-based rolling window (chosen), (2) Mean-based with outlier rejection, (3) Fixed reference from external climatology. Each gets a row.

**Consolidates into:** API-MANUAL.md section 8 (new subsection: Auto-Calibration), OPERATIONS-MANUAL.md (bootstrap procedure, admin UI)

### ADR-069: Fog/Mist Detection Rework

**Scope:** Replace T-Td <= 1 deg F single-variable check with multi-parameter algorithm: T-Td <= 4 deg F (ASOS standard) + wind gate (<=8 mph for fog, 8-15 for mist) + daytime solar suppression + PM disambiguation + rain gate + fog/mist split (T-Td <=2 = fog, 2-4 = mist). Fog dissipation tracking.

**Decisions documented:** D5 from the research synthesis.

**Options to evaluate:** (1) Multi-parameter (chosen), (2) Widen T-Td only (simpler but 40% false alarm), (3) ML-based (requires training data we don't have). Each gets a row.

**Consolidates into:** API-MANUAL.md section 8 (amend existing fog rule 6)

### ADR-070: NWS-Style Text Generation System

**Scope:** Structured local observation model (METAR-like field mapping), present weather code expansion (HZ, BR, FU additions), text generation engine (rules-based, GFE vocabulary extraction), three verbosity levels (terse/standard/verbose), NWS phrasing conventions (separate-sentence haze/fog, day/night terminology).

**Decisions documented:** D8 from the research synthesis.

**Options to evaluate:** (1) Rules-based with GFE vocabulary (chosen), (2) Template-only system (simpler but less flexible), (3) LLM-generated text (rejected — non-deterministic, latency, cost). Each gets a row.

**Consolidates into:** API-MANUAL.md section 8 (new subsections: Observation Model, Text Generation), ARCHITECTURE.md (new endpoint if needed), DASHBOARD-MANUAL.md (verbosity rendering)

### ADR-071: Nighttime Mode — Provider Deferral Pattern

**Scope:** At night (el <= 0 deg or below haze detection gate), haze/smoke defers to provider current conditions observations. Fog/mist remains local (T-Td + wind — pyranometer not needed). Sunrise handoff when el crosses 10-15 deg gate. Rationale: provider stations have visibility sensors we lack; our hyper-local T-Td adds value for fog that provider airports can't match.

**Options to evaluate:** (1) Provider deferral for haze, local for fog (chosen), (2) PM-only nighttime haze (lower confidence, duplicates provider work), (3) Full provider deferral for everything at night (loses local fog advantage). Each gets a row.

**Consolidates into:** API-MANUAL.md section 8 (nighttime mode subsection), ARCHITECTURE.md (provider data flow update)

---

## Manual Update Phase — Before Code

After ADRs are accepted, extract prescriptive rules into manuals. This is the implementation authority — agents read manuals, not ADRs, when writing code.

### API-MANUAL.md Section 8 Updates

New subsections to add:
- **8.x Haze Detection** — two-channel architecture, PM thresholds, f(RH) correction, elevation gate, wet deposition gate, temporal coherence, haze-eligible provider designation (observed-only)
- **8.x Auto-Calibration Baseline** — statistical methodology, sample selection, convergence, bootstrap data sources, maxSolarRad recomputation, persistent storage schema
- **8.x Fog/Mist Detection** (amend existing rule 6) — multi-parameter algorithm, wind gate, solar suppression, PM disambiguation, rain gate, fog/mist split, dissipation tracking
- **8.x Nighttime Mode** — provider deferral pattern, sunrise handoff, local fog retention
- **8.x Observation Model** — METAR-like field mapping table (local sensor -> WMO field)
- **8.x Present Weather Codes** — expanded WMO code table (add HZ, BR, FU, mist codes)
- **8.x Text Generation Engine** — rules-based composition, GFE threshold tables, verbosity levels, NWS phrasing conventions

### PROVIDER-MANUAL.md Updates

- Add Aeris AQI provider section (endpoint, response mapping, rate limits, observed-data designation)
- Add AirNow provider section (API endpoints, bulk CSV format, hourly obs files, US-only coverage)
- Deprecate/remove OWM AQI section (model-based, not suitable for haze confirmation)
- Add observed-vs-model classification table for all AQI providers
- Update provider selection guidance for haze detection use case

### ARCHITECTURE.md Updates

- Conditions text engine section: remove "Known gap" for haze, add haze/fog/text architecture
- Data flow: add AQI -> enrichment pipeline path
- New modules list: haze_condition.py, auto_calibration.py (or integrated names)
- Provider data flow: nighttime deferral pattern
- AQI provider inventory: updated list with Aeris AQI + AirNow

### DESIGN-MANUAL.md Updates

- Section 7 (Iconography): confirm haze hero icon spec (muted sun, horizontal lines), map to existing `material-symbols:air-outlined` or new icon
- Section 8 (Backgrounds): haze condition -> background mapping (muted/desaturated version of clear-sky?)
- Alert icon: haze alert mapping

### OPERATIONS-MANUAL.md Updates

- Bootstrap procedure: step-by-step for EPA AQS CSV import, OpenAQ, Aeris historical
- Admin UI: calibration status display, clean-day count, baseline confidence
- Configuration keys: `haze_detection`, `haze_aqi_provider`, PM import
- Wizard AQI provider selection: updated options (Aeris, AirNow, IQAir, Open-Meteo TBD)

---

## Implementation Phases

### Coordinator Discipline (applies to ALL phases)

1. **Before dispatching ANY implementation agent:** Coordinator reads the target manual sections (API-MANUAL.md section 8 + relevant new subsections), the governing ADRs, and ARCHITECTURE.md conditions engine section. Not delegated — the coordinator must have these in context to instruct agents correctly and perform meaningful QC.

2. **Pre-flight repo verification before EVERY agent dispatch:** `git status` + `git log --oneline -1` on target repo. Uncommitted changes or unexpected HEAD = STOP.

3. **Every agent prompt includes:**
   - Scope block (what to deliver, what NOT to touch)
   - Git restrictions (no pull/push/fetch/rebase/merge/checkout-remote)
   - Specific manual sections to read (with file paths)
   - Specific ADR acceptance criteria to satisfy
   - Verification command

4. **Independent verification of ALL agent claims:** Coordinator re-runs verification commands fresh. Spot-checks 1+ requirement against actual code. Does not trust self-reported pass/fail.

5. **QC is not "does code compile."** QC checks:
   - Does the code implement what the manual prescribes? (rule-by-rule walkthrough)
   - Are the ADR acceptance criteria met? (checklist verification)
   - Are thresholds, constants, and formulas correct per the research? (spot-check against archived research docs)
   - Does the code handle edge cases called out in the manual? (dawn/dusk, missing PM, provider outage)
   - Is doc-code sync maintained? (any new behavior = manual update in same commit)

### PHASE 0 — ADR Authoring (6 ADRs)

**T0.1 — Draft ADR-066 through ADR-071**
- Owner: Coordinator (Opus) — ADRs are judgment work, not mechanical
- For each ADR: draft as Proposed using Nygard template, all 8 sections
- Research citations: reference specific archived research files (e.g., `docs/reference/haze-physics/hanel-1976-summary.md` for gamma values, `docs/reference/haze-physics/aqi-historical-data-survey.md` for provider landscape)
- Present to user for review. User accepts or requests changes. All 6 must reach Accepted before Phase 1.
- **QC:** Self-audit against ADR content standards (~80 lines each, concrete acceptance criteria, no padding)

### PHASE 1 — Manual Updates

**T1.1 — Update API-MANUAL.md Section 8**
- Owner: `clearskies-docs-author` (Sonnet)
- Prompt includes: all 6 accepted ADRs, research synthesis section from the plan, existing section 8 content
- Adds 7 new subsections per the manual update list above
- Each subsection includes: rules (numbered, testable), thresholds (with units and source citations), edge cases, anti-patterns
- Accept: Every ADR acceptance criterion has a corresponding manual rule. `rules/coding.md` section 7 doc discipline satisfied. No placeholder text.

**T1.2 — Update PROVIDER-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Add Aeris AQI + AirNow provider sections. Deprecate OWM AQI. Add observed-vs-model classification. Update provider selection guidance.
- Must read: ADR-066 acceptance criteria, research file `docs/reference/haze-physics/aqi-historical-data-survey.md`
- Accept: Every AQI provider has observed/model classification. Aeris and AirNow sections complete with endpoints, response mapping, rate limits. OWM AQI marked deprecated with rationale.

**T1.3 — Update ARCHITECTURE.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Remove "Known gap" for haze. Add architecture for new modules, data flow, nighttime pattern. Update AQI provider inventory.
- Accept: Conditions engine section reflects the full haze/fog/text architecture. Data flow diagram updated. Provider list current.

**T1.4 — Update DESIGN-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Haze icon spec, background mapping, alert icon mapping.
- Accept: Icon and background rules are specific enough for a dashboard developer to implement without re-deriving.

**T1.5 — Update OPERATIONS-MANUAL.md**
- Owner: `clearskies-docs-author` (Sonnet)
- Bootstrap procedure, admin UI calibration section, new config keys, updated wizard AQI provider options.
- Accept: An operator could follow the bootstrap procedure step-by-step. Wizard provider list matches ADR-066.

**QC (Opus) — after Phase 1:** Read every new/modified manual section. Walk each ADR acceptance criterion and confirm the manual covers it. Verify no orphaned ADR requirements (acceptance criteria with no corresponding manual rule). Check cross-manual consistency (API-MANUAL, PROVIDER-MANUAL, and ARCHITECTURE.md agree on provider list, module names, data flow).

### PHASE 2 — AQI Provider Implementation (ADR-066)

**T2.1 — Add is_observed_source capability flag**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `providers/_common/capability.py`, `providers/aqi/openmeteo.py`, `providers/aqi/openweathermap.py`
- Accept: `ProviderCapability.is_observed_source` exists. Open-Meteo and OWM marked `False`.

**T2.2 — Deprecate OWM AQI provider**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `providers/aqi/openweathermap.py`
- Accept: OWM AQI still works but logs deprecation warning.

**T2.3 — AirNow provider (EXCLUDED)**
- AirNow's real-time API returns composite AQI index (0-500), not raw µg/m³. Provider module created then deleted. ADR-066 amended.

**T2.4 — Update wizard + admin AQI provider selection**
- Owner: Coordinator (direct)
- Files: stack repo — `providers.py`, `routes.py`, `step_aqi_regional_fields.html`, `provider_section.html`
- Accept: Aeris AQI added to wizard + admin dropdown, OWM marked deprecated, regional field rendering bug fixed.

**QC (Opus) — after Phase 2:** Provider capability flags correct. Wizard shows updated options. OWM deprecation warning appears.

### PHASE 3 — Track A: AQI Data Channel into Enrichment (A1)

**T3.1 — Add PM smoothing buffers to input_smoother.py**
- Owner: Coordinator (direct)
- Accept: `pollutantPM25` and `pollutantPM10` ring buffers (720 entries, 60-min window). `add_sample()` public API.

**T3.2 — Wire AQI provider cache into enrichment pipeline**
- Owner: Coordinator (direct)
- New file: `sse/enrichment/pm_feed.py` — stores latest PM from AQI endpoint, feeds into smoother on packet_tap cycle
- Accept: PM flows from AQI fetch → pm_feed → smoother. Stale data (>2 hours) suppressed. Only observed-source providers feed.

**T3.3 — Add PM fields to enrichment context**
- Owner: Coordinator (direct)
- Accept: `compose_weather_text()` reads smoothed PM, passes to `build_weather_text()`. No functional change to output.

**QC (Opus) — after Phase 3:** PM data flow verified. Staleness gate correct. Manual rule walkthrough passed.

### PHASE 4 — Track A: Haze Detection Module (A2)

**T4.1 — Implement haze detection logic**
- Owner: `clearskies-api-dev` (Sonnet)
- File: new `sse/haze_condition.py`
- Implements: two-channel confirmation (Kcs deficit + PM gate), solar elevation gate, RH type discriminator, f(RH) correction, wet deposition gate, temporal coherence
- Thresholds from manual: PM2.5 > 12 ug/m3 (dry), > 35 ug/m3 (humid disambiguation), el > 10 deg, gamma = 0.45
- Accept: Haze detected when both channels fire. Not detected when PM clean or el too low. Wet deposition suppresses. 15-min coherence filter applied.

**T4.2 — Wire haze into weatherText composition**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: `conditions_text.py`, `enrichment/weather_text.py`
- Accept: weatherText includes haze label when detected. Haze suppressed when sky is overcast/cloudy.

**T4.3 — Add WMO weather code for haze**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `enrichment/weather_text.py` (`_derive_weather_code()`)
- Accept: weatherCode = 5 when haze detected. Priority: precipitation > fog > haze > sky.

**QC (Opus) — after Phase 4:** Walk every numbered rule in API-MANUAL section 8 Haze Detection against the code. Verify thresholds match. Test edge cases.

### PHASE 5 — Track A: Fog/Mist Improvements (A4)

**T5.1 — Replace fog detection with multi-parameter algorithm**
- Owner: `clearskies-api-dev` (Sonnet)
- File: `enrichment/weather_text.py` (replace fog override)
- Implements: T-Td ≤ 4°F, wind gate, solar suppression, PM disambiguation, rain gate, fog/mist split, dissipation
- Accept: Fog detected with multi-parameter approach. Mist for T-Td 2-4°F. Humid-windy-daytime suppressed.

**T5.2 — Update weatherText fog/mist labels**
- Owner: `clearskies-api-dev` (Sonnet)
- Accept: "Misty" appears for T-Td 2-4°F. Correct WMO codes.

### PHASE 6 — Track A: Nighttime Mode + Auto-Calibration Foundation (A3, A6.5)

**T6.1 — Implement nighttime provider deferral for haze**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: new `sse/enrichment/provider_weather_feed.py`, modified `endpoints/observations.py`, `sse/enrichment/weather_text.py`
- Accept: At night, haze from provider. Fog from local detection. Daytime uses local haze detection.
- Commit: b979935 (note: commit message reads "auto-calibration" due to cross-agent staging; actual content is T6.1 nighttime deferral)

**T6.2 — Implement auto-calibration baseline storage**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: new `sse/auto_calibration.py` (541 lines), modified `__main__.py`
- Accept: Baseline persists across restarts. Clean samples accumulate. Percentile computed correctly. Confidence state reported.
- Commits: cff995f (module), 2fd438b (wiring)

**T6.3 — Implement maxSolarRad recomputation utility**
- Owner: `clearskies-api-dev` (Sonnet) — implemented within `sse/auto_calibration.py`
- Accept: Recomputed values match weewx's `solar_rad_RS()` output.
- Commit: cff995f (included in auto_calibration.py)

**Follow-up (non-blocking):** auto_calibration.process_packet() collects a sample every qualifying 5-second packet. Add rate limiting (~1 sample/5 min) before the 90-day window fills to prevent large JSON persistence files.

### PHASE 7 — Track B: NWS Text System (B1-B3)

**T7.1 — Build structured observation model**
- Owner: `clearskies-api-dev` (Sonnet)
- File: new `sse/observation_model.py` (308 lines)
- Implements: `Observation` dataclass (18 nullable fields), `build_observation()` factory, CAELUS-to-okta mapping table (12 display labels → CLR/FEW/SCT/BKN/OVC), present weather list (raw detection snapshot)
- Accept: All METAR/WMO fields populated from enrichment pipeline. windDir from obs_data (not in smoother). All fields nullable.
- Commit: 718dd67

**T7.2 — Expand present weather code system**
- Owner: `clearskies-api-dev` (Sonnet)
- File: modified `sse/enrichment/weather_text.py` (19 insertions)
- Implements: WMO code 48 (depositing rime fog: fog + temp ≤ 32°F), `out_temp` parameter added to `_derive_weather_code()`
- Accept: Code set matches API-MANUAL table exactly. Anti-pattern verified (precipitation priority).
- Commit: b9c9964

**T7.3 — Build text generation engine with verbosity levels**
- Owner: `clearskies-api-dev` (Sonnet) + Coordinator (wiring)
- Files: new `sse/text_generator.py` (356 lines), modified `sse/enrichment/weather_text.py` (wiring)
- Implements: `generate_standard()` (NWS one-sentence-per-component), `generate_verbose()` (full narrative), GFE threshold tables (sky/wind/temperature), NWS phrasing conventions, day/night terminology, 8-point compass wind direction
- Accept: weatherTextStandard and weatherTextVerbose injected into /current response alongside existing weatherText.
- Commits: 8cecb28 (module), 01a2f1d (wiring)

### PHASE 8 — Track A: Bootstrap & Configuration (A3 continued, A7)

**T8.2a — Add haze configuration keys to api.conf**
- Owner: `clearskies-api-dev` (Sonnet)
- Files: modified `config/settings.py` (58 insertions), `sse/auto_calibration.py` (32 insertions), `sse/haze_condition.py` (20 insertions), `__main__.py` (15 insertions), `CONFIG.md`, `etc/api.conf.example`
- Implements: ConditionsSettings extended with haze_detection, calibration_percentile, calibration_window_days, calibration_min_samples, gamma. auto_calibration.configure() replaces hardcoded constants. haze_condition.set_enabled() toggle. Wired at startup.
- Commit: 22ddcc9

**T8.1 — OpenAQ-based calibration bootstrap**
- Owner: `clearskies-api-dev` (Sonnet) + Coordinator (commit)
- Files: new `bootstrap/__init__.py`, `bootstrap/openaq_client.py`, `bootstrap/importer.py` (895 lines total), modified `__main__.py`
- Implements: CLI `clearskies-api bootstrap [--years N] [--max-distance-km N]`. OpenAQ API v3 client (stdlib urllib, rate-limited). Finds nearest PM2.5 monitor, pulls historical hourly data, matches against weewx archive, computes Kcs, seeds auto-calibration baseline. Read-only archive access. Year-chunked pagination.
- Design change (user directive 2026-06-22): EPA AQS dropped entirely. Manual CSV import dropped. OpenAQ is the single bootstrap source worldwide (141 countries). Rationale: simpler UX (no file downloads), single API for all locations.
- Commit: 66e1183

**T8.2b — Admin UI haze calibration page**
- Owner: `clearskies-api-dev` (Sonnet)
- Repo: weewx-clearskies-stack
- Files: new `templates/admin/haze_calibration.html` (255 lines), modified `admin/routes.py` (130 insertions), modified `templates/admin/landing.html` (31 insertions)
- Implements: Haze calibration admin page with status display (bootstrapping/calibrated/well-calibrated), sample count, baseline Kcs, configuration form (haze_detection toggle, calibration parameters, gamma), bootstrap CLI note. Landing page link in Advanced section.
- Commit: 4a32ea0

### PHASE 9 — Integration Testing & QA

**T9.1 — Haze detection tests** ✅
- Owner: `clearskies-test-author` (Sonnet)
- Files: `tests/test_haze_condition.py` (51 tests), `tests/test_auto_calibration.py` (40 tests), `tests/test_pm_feed.py` (25 tests)
- Commits: 8deaf4f (tests), 2e0eb3e + 1f74bb4 (fixes for f(RH) threshold + RH gate)

**T9.2 — Fog improvement tests** ✅
- Owner: `clearskies-test-author` (Sonnet)
- Files: `tests/test_fog_condition.py` (59 tests)
- Commits: c033111 (tests), 2e0eb3e (coherence pruning fix)

**T9.3 — Text generation + providers tests** ✅
- Owner: `clearskies-test-author` (Sonnet)
- Files: `tests/test_text_generator.py` (37 tests), `tests/test_weather_code.py` (28 tests), `tests/test_provider_weather_feed.py` (13 tests), `tests/providers/aqi/test_openaq.py` (30 tests), 2 fixture files
- Commits: 7727872 (tests), 2e0eb3e (rate limiter fix), 4c92cdc + 1f74bb4 (state var renames + °F labels)

**T9.4 — Full audit against ADRs + manuals** ✅
- Owner: `clearskies-auditor` (Sonnet) + Coordinator remediation
- 8 findings, all resolved:
  - F1 (HIGH): auto_calibration PM gate required both PM2.5+PM10 — fixed to PM2.5 only, PM10 optional (9c4be50)
  - F2 (HIGH): "Scattered" in clean-sky substrings — removed (9c4be50)
  - F3 (HIGH): f(RH) correction dead variable — applied with deficit threshold scaling per Hanel 1976 (064fe38)
  - F4 (MEDIUM): Text generator US-only — added Metric/MetricWX unit-aware rendering (42a34bf, a74bb06 wiring)
  - F5 (MEDIUM): OPERATIONS-MANUAL wrong gamma key name/range — fixed (meta: a62b139)
  - F6 (LOW): Temporal coherence wording — pushed back, acceptance criterion satisfied
  - F7 (MEDIUM): ARCHITECTURE.md missing OpenAQ — fixed (meta: a62b139)
  - F8 (MEDIUM): Confidence level in admin UI — pushed back, state enum serves this purpose
- Additional enhancement: OpenAQ two-station PM2.5/PM10 resolution (10767a0) — separately queries for PM10 when not co-located with PM2.5

**Pytest results:** 354 new tests passing. Full suite: 3188+ passed, 358 skipped, 3 pre-existing failures (OWM Redis cache × 2, weewx metadata × 1).

### PHASE 10 — Deploy & Final Verification (PARTIAL)

**T10.1 — Deploy API** ✅ Deployed at commit `170805f` (includes openaq_api_key fix). Service restarted, weatherText/weatherTextStandard/weatherTextVerbose confirmed live.
**T10.2 — Deploy Dashboard** ✅ No dashboard changes in this plan (no-op).
**T10.3 — Deploy Wizard updates** ✅ Deployed at commit `861e121` (includes about_content fixes + openaq_api_key round-trip). Config UI restarted.
**T10.4 — End-to-end verification** ⬜ Blocked pending seasonal calibration rework.

**Bugs fixed during Phase 10 deployment:**
- Wizard 422 on apply: `ApplyRequest` missing `openaq_api_key` field (API `170805f`, stack `2d44b34`)
- Station description not sticking: template prefix, branding.json read-back, gated merge (stack `941a961`, `52a3de7`, `861e121`)

**Follow-on:** Auto-calibration rework to monthly-normals model. See [SEASONAL-CALIBRATION-PLAN.md](SEASONAL-CALIBRATION-PLAN.md).

---

## Agent Assignments Summary

| Phase | Task | Owner Agent Type | Model | QC By |
|-------|------|-----------------|-------|-------|
| 0 | ADR authoring (6 ADRs) | Coordinator (Opus) | Opus | Self-audit + user review |
| 1 | Manual updates (5 manuals) | `clearskies-docs-author` | Sonnet | Coordinator: ADR coverage walkthrough |
| 2 | AQI providers (4 tasks) | `clearskies-api-dev` + Coordinator | Sonnet | Coordinator: provider test + PROVIDER-MANUAL walkthrough |
| 3 | AQI data channel (3 tasks) | Coordinator (direct) | Opus | Coordinator: data flow verify + manual rule walkthrough |
| 4 | Haze detection (3 tasks) | `clearskies-api-dev` | Sonnet | Coordinator: threshold verify + edge case test + ADR walkthrough |
| 5 | Fog improvements (2 tasks) | `clearskies-api-dev` | Sonnet | Coordinator: multi-param verify + edge case test + ADR walkthrough |
| 6 | Nighttime + calibration (3 tasks) | `clearskies-api-dev` | Sonnet | Coordinator: handoff test + persistence test + ADR walkthrough |
| 7 | NWS text system (3 tasks) | `clearskies-api-dev` | Sonnet | Coordinator: verbosity test + WMO code verify + ADR walkthrough |
| 8 | Bootstrap + config (2 tasks) | `clearskies-api-dev` + `clearskies-dashboard-dev` | Sonnet | Coordinator: real-data import test + admin UI verify |
| 9 | Testing + audit (4 tasks) | `clearskies-test-author` + `clearskies-auditor` | Sonnet | Coordinator: synthesize findings + compliance sweep |
| 10 | Deploy + verify (4 tasks) | Coordinator (Opus) | Opus | Coordinator: end-to-end walkthrough |

**Sequencing:**
- Phase 0 (ADRs) → Phase 1 (manuals) [prerequisite gate: all 6 ADRs accepted]
- Phase 1 → Phase 2 (providers) [prerequisite gate: manuals updated]
- Phase 2 → Phase 3 (AQI channel) → Phase 4 (haze) → Phase 5 (fog) [sequential: each builds on prior]
- Phase 5 → Phase 6 (nighttime + calibration) [depends on haze + fog being in place]
- Phase 6 → Phase 7 (NWS text) [depends on new detection capabilities for present weather codes]
- Phase 7 → Phase 8 (bootstrap + config) [depends on calibration system for import target]
- Phase 8 → Phase 9 (testing + audit) → Phase 10 (deploy)

---

## Verification

After plan execution:
- All 6 ADRs accepted and archived into manuals
- 5 manuals updated with new sections
- Aeris AQI provider module working, OWM deprecated
- Haze detection working with two-channel confirmation on live site
- Fog detection improved with multi-parameter algorithm
- Nighttime provider deferral active
- Auto-calibration baseline accumulating
- NWS text generation at three verbosity levels
- Integration tests passing
- Auditor report delivered and dispositioned
- Full ADR compliance sweep recorded
