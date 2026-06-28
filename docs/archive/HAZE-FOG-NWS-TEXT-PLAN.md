# Conditions Engine Expansion: Haze/Fog Detection + NWS Text System

**Status:** COMPLETE — Research phases (R1–R5) delivered, synthesis complete. Part 2 (implementation) replaced by standalone HAZE-FOG-NWS-TEXT-IMPLEMENTATION-PLAN.md (still in progress). Archived 2026-06-27.  
**Created:** 2026-06-21  
**Updated:** 2026-06-21 (research synthesis complete)  
**Components:** API (`weewx-clearskies-api`), Dashboard (`weewx-clearskies-dashboard`), Stack (`weewx-clearskies-stack`)

---

## Context

The conditions text engine (CAELUS-based sky classifier + weather text composer) produces the `weatherText` field on every `/api/v1/current` response. It classifies sky conditions from pyranometer data and assembles a natural-language conditions string.

Two expansion opportunities identified:

1. **Haze and fog detection** — The engine can distinguish clouds from clear sky but cannot distinguish haze from thin cirrus, nor improve on the simplistic fog override (T-Td ≤ 1°F). Adding PM2.5/PM10 data from existing AQI providers, combined with RH gating and a learned clean-sky baseline, would enable hyper-local haze observations using instruments already present on most PWSs. A competitor-generated analysis document (unverified) proposed an approach; this plan verifies the science, then implements what's defensible.

2. **NWS-style text generation** — The NWS uses formalized rules (FMH-1, Directive 10-503, GFE text formatter) to convert observation codes into written text and forecast narratives. Studying this system could improve our current conditions text quality, enable longer written observations (for Home Assistant integration, etc.), and eventually generate forecast narrative text. The first step is building a structured local observation model (METAR-like) as the bridge between our sensors and the text rules.

Both tracks require research before implementation. This plan is structured in two parts:
- **PART 1 (Detailed):** Research phases with agent assignments, QC gates, and archival requirements
- **PART 2 (Outline):** Implementation structure with placeholders, to be refined after research completes

---

## 0. Orientation — Execution Context

**Read before any task:**
- `CLAUDE.md` — domain routing, operating rules, git safety
- `rules/coding.md` — security constraints, documentation discipline (§7)
- `rules/clearskies-process.md` — ADR discipline, agent orchestration, scope binding
- `docs/reference/sky-classification-science.md` — existing science reference (13 sections, all cited)
- **Appendix A** of this document — full discussion context and decision rationale from the planning session

**Existing engine code (read-only reference for research agents):**
- `repos/weewx-clearskies-api/weewx_clearskies_api/sse/sky_condition.py` — CAELUS classifier
- `repos/weewx-clearskies-api/weewx_clearskies_api/sse/conditions_text.py` — text composer
- `repos/weewx-clearskies-api/weewx_clearskies_api/sse/enrichment/weather_text.py` — enrichment adapter
- `repos/weewx-clearskies-api/weewx_clearskies_api/sse/enrichment/input_smoother.py` — smoothed inputs
- `repos/weewx-clearskies-api/weewx_clearskies_api/providers/aqi/` — AQI provider modules

**Key verified facts (from Appendix A):**
- maxSolarRad comes from weewx (Ryan-Stolzenbach, atc=0.8 fixed). Do NOT modify weewx constants.
- Kcs = Beer-Lambert/σ (extinction magnitude). Kv = differential calculus (signal variability). Different frameworks, both needed.
- AQI providers already return PM2.5 + PM10 in canonical model (`pollutantPM25`, `pollutantPM10` in µg/m³). Not wired into enrichment pipeline.
- Aeris is best real-time AQI source (observed, low latency). OWM/OpenMeteo are forecast models, not observations.
- Auto-calibration operates at layer 2 (learned clean-day Kcs baseline), not by modifying model constants.
- Bootstrap from weewx archive + historical AQI is feasible; needs rate-limit guardrails and operator approval.
- Haze is definitionally particulate — PM is the PRIMARY confirmation gate, RH modulates type/severity.
- weewx did not always archive maxSolarRad; older records may need recomputation.

**Agent constraints (ALL phases):**
- Agents must NOT spawn sub-agents (`Agent` tool is prohibited in agent prompts)
- Agents must NOT use training data as a source — all claims must be sourced from fetched documents
- Agents must archive fetched content to `docs/reference/` BEFORE summarizing from it
- Agents must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches
- Coordinator (Opus) reviews all agent output before accepting

---

# PART 1: RESEARCH PLAN (Detailed)

## Research Phase R1 — Core Haze Physics Papers

**Goal:** Fetch, archive, and extract key data from the papers that are load-bearing for the haze detection math.

### R1.1 — Hänel Growth Equation & Hygroscopic Aerosol Properties

- **Owner:** Sonnet (`general-purpose`)
- **Papers to find and archive:**
  - Hänel, G. (1976). *The properties of atmospheric aerosol particles as functions of the relative humidity at thermodynamic equilibrium with the surrounding moist air.* Advances in Geophysics, 19, 73-188.
  - Tang, I.N. (1996). *Chemical and size effects of hygroscopic aerosols on light scattering coefficients.* J. Geophysical Research, 101(D14), 19245-19250.
- **Extract and record:**
  - The exact f(RH) formula and its derivation
  - γ values for specific aerosol types: sulfate, nitrate, sea salt, organic carbon, mineral dust, mixed urban
  - Ranges of γ (not just single values) — the competitor document claims γ ≈ 0.25 (PM2.5) and γ ≈ 0.40 (PM10). Verify.
  - Deliquescence thresholds for common aerosol species (the RH at which particles undergo phase transition and swell rapidly)
  - Any discussion of the 70% and 85% RH boundaries the competitor document uses
- **Archive to:** `docs/reference/haze-physics/hanel-1976-summary.md`, `docs/reference/haze-physics/tang-1996-summary.md`
- **Accept:** Each summary includes: full citation, DOI/URL, key formulas with variable definitions, extracted data tables, and explicit notes on what could vs could NOT be verified from the source.

### R1.2 — Long & Ackerman Clear-Sky Detection Algorithm

- **Owner:** Sonnet (`general-purpose`)
- **Paper:** Long, C.N. & Ackerman, T.P. (2000). *Identification of clear skies from broadband pyranometer measurements and calculation of downwelling shortwave cloud effects.* J. Geophysical Research, 105(D12), 15609-15626.
- **Extract and record:**
  - The algorithm for identifying cloud-free periods from GHI time series
  - What "smooth curve" means quantitatively — is it variance-based? First-derivative? Something else?
  - Whether the paper addresses haze as a distinct case from clear sky
  - Whether the paper discusses aerosol vs cloud discrimination
  - Relevance to our Kv-based smoothness measure
- **Archive to:** `docs/reference/haze-physics/long-ackerman-2000-summary.md`
- **Accept:** Summary answers: does this paper validate using GHI curve smoothness to identify cloud-free skies? Does it address haze?

### R1.3 — Mie Scattering and Wavelength Dependence

- **Owner:** Sonnet (`general-purpose`)
- **Goal:** Verify the competitor document's claim that "Mie scattering acts uniformly across visible wavelengths." This matters because our pyranometers are broadband — if Mie scattering were strongly wavelength-dependent, broadband GHI deficit wouldn't be a reliable haze proxy.
- **Approach:** Search for authoritative sources on Mie scattering wavelength dependence for haze-sized particles (0.1–10 µm). No need to fetch the full Bohren & Huffman (1983) textbook — find a concise review or handbook chapter.
- **Extract and record:**
  - Wavelength dependence of Mie scattering for particles in the 0.1–10 µm range
  - Whether broadband (300–3000 nm) pyranometer GHI deficit is a valid proxy for haze extinction
  - Comparison: Rayleigh (strongly λ-dependent, λ⁻⁴) vs Mie (weakly λ-dependent for large particles) — quantify "weakly"
- **Archive to:** `docs/reference/haze-physics/mie-scattering-summary.md`
- **Accept:** Clear answer to: is broadband GHI deficit a scientifically valid measure of haze extinction? With citation.

**QC (Opus) — after R1:** ✅ COMPLETE. Findings:
- **(a) γ values: COMPETITOR CLAIMS REFUTED.** γ is a *composition* property, not a *size* property. Assigning γ ≈ 0.25 to PM2.5 and γ ≈ 0.40 to PM10 conflates size with composition. Actual γ ranges: 0.12 (mineral dust) to 1.52 (sea salt). For our system without composition data, use a **moderate default γ ≈ 0.4–0.5** with documented approximation. The 70%/85% RH boundaries are IMPROVE/monitoring network operational conventions, not from Hänel/Tang.
- **(b) Long & Ackerman: VALIDATES Kv for cloud-free detection.** L&A Test 4 (11-min window std dev of NDR) is structurally equivalent to our Kv. **However, L&A CANNOT distinguish haze from clear sky** — hazy-but-stable conditions pass all four tests. PM confirmation gate is scientifically necessary.
- **(c) Mie scattering: UNAMBIGUOUS YES.** Broadband GHI deficit is a scientifically established (since 1922) and peer-validated (r = 0.90 vs AERONET, Lindfors 2013) measure of haze extinction. ±20% uncertainty is appropriate for classification, not precise AOD. Ångström exponent for typical haze: α ≈ 1.0–1.5.
- **All three papers paywalled** — key data recovered and cross-validated from multiple independent open-access citing papers.

---

## Research Phase R2 — Clear-Sky Baseline & Calibration Science

**Goal:** Establish scientific basis for the auto-calibration approach (learned clean-day Kcs baseline). Find out what ground-based radiometric networks use and what statistical sampling is defensible.

### R2.1 — BSRN / SURFRAD Clear-Sky Methodology

- **Owner:** Sonnet (`general-purpose`)
- **Search for:**
  - How the Baseline Surface Radiation Network (BSRN) and NOAA's Surface Radiation Budget Network (SURFRAD) determine clear-sky baselines
  - Long & Ackerman (2000) is part of this — but also look for SURFRAD operational documentation and BSRN technical reports
  - Specifically: do they stratify by time of day? By season? How many samples per bin? What convergence criteria do they use?
- **Also search for:**
  - Reno, M.J., Hansen, C.W., & Stein, J.S. (2012). *Global Horizontal Irradiance Clear Sky Models: Implementation and Analysis.* Sandia SAND2012-2389. — This Sandia report compares multiple clear-sky models and discusses validation methodology.
- **Extract and record:**
  - Statistical methodology for clear-sky baseline determination
  - Sample size requirements
  - Stratification approach (diurnal, seasonal, or both)
  - How they handle sites with persistent haze vs clean-air sites
- **Archive to:** `docs/reference/haze-physics/clear-sky-baseline-methodology.md`
- **Accept:** Summary provides defensible answers to: how many clean-sky samples do we need? Must we stratify by time-of-day and season? What does the literature say?

### R2.2 — Ryan-Stolzenbach Clear-Sky Model Verification

- **Owner:** Sonnet (`general-purpose`)
- **Goal:** Verify how weewx computes maxSolarRad and whether it properly accounts for air mass.
- **Approach:**
  - Read the weewx source code for maxSolarRad computation (search in weewx Python source for the Ryan-Stolzenbach implementation — likely in `weewx/wxformulas.py` or similar)
  - Find the original Ryan & Stolzenbach (1972) paper or a description of the algorithm
  - Check: does the formula include air mass (sec(θz))? Does it account for Rayleigh scattering increase at high air mass? What exactly does `atc` (atmospheric transmission coefficient) represent physically?
- **Archive to:** `docs/reference/haze-physics/ryan-stolzenbach-model.md`
- **Accept:** Clear description of: (a) the formula weewx uses, (b) what atc physically represents, (c) whether Kcs is already normalized for path length, (d) any known limitations at low solar elevation.

**QC (Opus) — after R2:** ✅ COMPLETE. Findings:
- **R2.1:** ARM/BSRN/SURFRAD all converge on Long & Ackerman as the common algorithm. **No time-of-day bins needed** — cos(Z) normalization handles the diurnal cycle. **Seasonal stratification IS needed** — 90-day rolling window recommended. Minimum: ~22 samples per calibration period (scaled from ARM's 110-minute threshold). Quantile approach validated: Renner et al. (2019) uses 85th percentile at 42 BSRN stations; for *haze detection* target **90th–95th percentile** to exclude routine hazy-clear days.
- **R2.2:** Ryan-Stolzenbach formula confirmed from weewx source code (commit `5169d6380d83`). `atc` is a **single lumped parameter** bundling ALL extinction (Rayleigh + aerosol + water vapor + ozone). Kcs is partially path-length-normalized but **unreliable at el < 10–15°** (~20% underestimation at dawn/dusk, Kcs > 1.0 under clear conditions). Haze detection must gate on **el > 10–15°**.
- **Minimum defensible calibration:** el > 10–15° gate, cos(Z) normalization (already done), 90-day rolling window, 90th–95th percentile, ~22 samples minimum, no time-of-day bins.

---

## Research Phase R3 — NWS Text Generation System

**Goal:** Understand how the NWS converts observation data to text, and assess what we can reuse.

### R3.1 — METAR-to-Text and Present Weather Codes

- **Owner:** Sonnet (`general-purpose`)
- **Search for:**
  - FMH-1 (Federal Meteorological Handbook No. 1) — specifically the present weather code tables and text conversion rules
  - NWS Instruction 10-503 — the full directive, not just the sky terminology table we already cite
  - WMO Code Table 4677 (manned stations) and 4680 (automated stations) — present weather codes
  - Focus on: how HZ (haze), FG (fog), BR (mist), FU (smoke) are coded and converted to text
- **Extract and record:**
  - Complete present weather code table relevant to our observations (HZ, FG, BR, FU, RA, SN, FZRA, etc.)
  - The rules for composing observation text from METAR fields (temperature + dewpoint + wind + sky + present weather + pressure → text)
  - Phrasing conventions: "Hazy and Sunny", "Fog", "Mist" — what are the exact NWS rules for when each term is used?
  - Visibility thresholds that trigger each present weather code (HZ = vis < 7 SM, etc.)
- **Archive to:** `docs/reference/nws-text-system/metar-present-weather-codes.md`, `docs/reference/nws-text-system/observation-text-rules.md`
- **Accept:** Complete enough that we could map our local observations to the METAR/WMO code system.

### R3.2 — GFE Text Formatter / AWIPS-II

- **Owner:** Sonnet (`general-purpose`)
- **Search for:**
  - Is the AWIPS-II GFE text formatter open source? (It should be — NOAA open-sourced AWIPS-II)
  - If open source: what language? Where is the repo? What are the key modules for text generation?
  - How does the GFE convert gridded forecast data into narrative text (e.g., "Mostly sunny, with a high near 85. South wind 5 to 10 mph.")
  - What text templates / grammar rules does it use?
- **Extract and record:**
  - Location of source code (if available)
  - High-level architecture of the text generation pipeline
  - Key grammar rules and templates
  - Assessment: is this something we can adapt, or is it too tightly coupled to AWIPS infrastructure?
- **Archive to:** `docs/reference/nws-text-system/gfe-text-formatter-assessment.md`
- **Accept:** Clear assessment of: can we reuse NWS text generation logic, and if so, what specifically?

**QC (Opus) — after R3:** ✅ COMPLETE. Findings:
- **(a) METAR-like model: YES.** Complete WMO code tables (4677 manned 00–99, 4680 automated), ASOS HZ/BR/FG discrimination algorithm, present weather codes with visibility thresholds, sky condition → text mappings all documented. FMH-1 primary source archived (FCM-H1-2005).
- **(b) GFE text formatter: YES, extract don't transplant.** AWIPS-II is open source (Python, public domain). Phrase libraries (ScalarPhrases, WxPhrases, VectorRelatedPhrases) are pure Python with no AWIPS imports. Threshold tables are compact (~8 lines for sky, ~30 lines for temperature decades, ~10 lines for wind). Estimated 1–3 days implementation.
- **(c) NWS ↔ our needs gap:** (1) NWS uses "Hazy." as a *separate sentence*, NOT "Sunny with Haze" — plan section A6 corrected. (2) NWS requires visibility sensor for HZ (vis < 7 SM) — we estimate from σ + PM. (3) ASOS discriminates HZ/BR/FG at T-Td ≤ 4°F — this is an ASOS algorithm rule, not FMH-1 standard; FMH-1 defines by physical composition (dry particles vs water droplets). (4) Need CAELUS → NWS okta mapping.

---

## Research Phase R4 — Cirrus vs Smoke Discrimination & Fog Science

**Goal:** Determine whether ground-based broadband pyranometry can distinguish aerosol layers from cirrus, and establish proper fog detection criteria.

### R4.1 — Literature Search: Ground-Based Aerosol vs Cirrus

- **Owner:** Sonnet (`general-purpose`)
- **Search for:**
  - Papers on discriminating aerosol optical depth from cirrus using surface pyranometry
  - Papers on time-series signature differences between cirrus and aerosol layers in GHI data
  - Gueymard, C.A. (2004). *The sun's total and spectral irradiance for solar energy applications and solar radiation models.* — relevant to cloud-screening and aerosol detection
  - Any papers from ARM (Atmospheric Radiation Measurement) program on this topic
- **Extract and record:**
  - Whether broadband pyranometry CAN distinguish cirrus from aerosol (and under what conditions)
  - Specific differential signatures (d²I/dt², autocorrelation, persistence patterns)
  - Whether PM surface measurements are necessary for discrimination, or if pyranometer-only methods exist
  - Limitations of any proposed methods
- **Archive to:** `docs/reference/haze-physics/cirrus-vs-aerosol-discrimination.md`
- **Accept:** Honest assessment — even if the answer is "this can't be done reliably with consumer equipment."

### R4.2 — Fog Detection Literature

- **Owner:** Sonnet (`general-purpose`)
- **Search for:**
  - Papers on automated fog detection from surface weather station data
  - NWS/WMO criteria for fog vs mist vs haze (the visibility + RH thresholds)
  - Papers on radiation fog detection and prediction from temperature/humidity/wind data
  - Focus on: what sensors are needed? Can fog types (radiation, advection, precipitation) be distinguished from surface data?
- **Extract and record:**
  - Standard meteorological criteria for fog (visibility < 1 km, RH > 95-100%) vs mist (1-5 km, RH 80-95%) vs haze (visibility < 11 km, RH < 80%, particulate)
  - Whether our current fog detection (T-Td ≤ 1°F) is scientifically sound or too simplistic
  - Improvements possible with our available sensors (temperature, dewpoint, wind speed, radiation, PM)
  - Fog dissipation patterns (relevant to temporal gating)
- **Archive to:** `docs/reference/haze-physics/fog-detection-literature.md`
- **Accept:** Summary provides: (a) standard WMO/NWS fog criteria, (b) assessment of our current method, (c) recommended improvements.

**QC (Opus) — after R4:** ✅ COMPLETE. Findings:
- **(a) Cirrus vs smoke: CANNOT RELIABLY DISTINGUISH — physics constraint.** Duchon & O'Malley (1999) documented ~45% agreement under mixed conditions. Both produce identical broadband GHI signatures. Surface PM2.5 doesn't help — transported smoke above the boundary layer is invisible to surface sensors (PM-AOD correlation 0.03–0.60). **Best free discriminator: GOES-16 Band 4 (1.38 µm)** on AWS S3 (free, 10-min latency) — cirrus is bright in this channel, low-level haze is invisible. For certainty: spectral radiometer ($5K+) or lidar — beyond consumer reach.
- **(b) Fog detection: MAJOR REWORK NEEDED.** T-Td ≤ 1°F is 4× too conservative (ASOS uses 4°F). Multi-parameter approach (Izett et al. 2018): RH + wind ≤ 8 mph + nighttime solar + temp trend achieves >90% hit rate, 13% false alarm. Five improvements: (1) widen to 4°F, (2) wind gate, (3) daytime solar suppression, (4) PM2.5 disambiguation, (5) differentiate fog (T-Td ≤ 2°F) from mist (2–4°F).
- **(c) Full discrimination matrix:**
  - T-Td ≤ 2°F + calm + no solar → **Foggy** (high confidence)
  - T-Td 2–4°F + calm-moderate → **Misty** (moderate-high)
  - T-Td > 4°F + elevated PM + smooth deficit → **Hazy** (high)
  - T-Td > 4°F + clean PM + smooth deficit → **Unknown uniform layer** (cirrus/smoke ambiguity)

---

## Research Phase R5 — AQI Provider Historical Data Feasibility

**Goal:** Determine what historical AQI data is available for the auto-calibration bootstrap.

### R5.1 — Provider Historical Endpoint Survey

- **Owner:** Sonnet (`general-purpose`)
- **For each provider, research and document:**
  - **Aeris/Xweather:** Does a historical AQI endpoint exist? Lookback window? Rate limits per developer tier? Cost per call?
  - **AirNow:** Historical data download format (annual CSVs). Coverage, fields, how to ingest programmatically.
  - **OpenAQ:** Historical archive API. Lookback depth, rate limits, global coverage.
  - **IQAir:** Historical data availability on free vs paid tiers.
- **Also check:**
  - What is the typical temporal resolution of historical AQI data? (hourly? daily?)
  - Are PM2.5 and PM10 both available historically, or just AQI index?
- **Archive to:** `docs/reference/haze-physics/aqi-historical-data-survey.md`
- **Accept:** For each provider: availability (yes/no), lookback window, resolution, rate limits, cost, PM field availability. Clear enough to estimate API call budget for bootstrap.

### R5.2 — weewx maxSolarRad Archive History

- **Owner:** Sonnet (`general-purpose`)
- **Research:**
  - When did weewx start archiving maxSolarRad to the database? Check weewx changelogs, release notes, GitHub issues.
  - In older weewx versions, was maxSolarRad computed for loop packets but NOT stored in archive?
  - What weewx version introduced archiving of maxSolarRad?
  - Can we recompute maxSolarRad for historical records using station lat/lon/altitude + the Ryan-Stolzenbach formula?
- **Archive to:** `docs/reference/haze-physics/weewx-maxsolarrad-history.md`
- **Accept:** Clear answer: from what weewx version is maxSolarRad in the archive? What do we do for older records?

**QC (Opus) — after R5:** ✅ COMPLETE. Findings:
- **(a) Bootstrap feasibility: YES — practical and free for most operators.**
  - **US stations:** EPA AQS bulk download is the recommended path. Free, no rate limits, hourly PM2.5/PM10 in µg/m³, data back to late 1990s for PM2.5 (parameter code 88101). ~2,500 monitoring stations. Fill the recent 6-month AQS publication lag with AirNow hourly obs files (also free). Annual zipped CSVs, per-pollutant, per-year.
  - **Non-US stations:** OpenAQ AWS S3 archive (`s3://openaq-data-archive`). Free, no credentials, no rate limits. 141 countries, 15,300+ locations, data from ~2016. Gzip CSV organized by location/year/month.
  - **Aeris/Xweather:** Viable supplement for already-subscribed operators. Historical archive endpoint exists but limited to **January 2024–present**. 5× call multiplier against subscription allotment. PWSWeather Contributor Plan provides free access (1,000 calls/day → ~200 effective archive calls/day).
  - **IQAir:** Not viable for bootstrap — 48-hour API lookback maximum, even on Enterprise tier.
- **(b) All viable providers return raw PM2.5 AND PM10 in µg/m³, not just composite AQI.** Hourly resolution is standard across all providers.
- **(c) maxSolarRad in archive: weewx 4.0.0+ only (April 2020).** Fresh installs from v4.0.0 with `wview_extended` schema + `ephem` package → maxSolarRad archived from day 1. Pre-4.0 stations and in-place upgrades: column absent unless manually added (`weectl database add-column maxSolarRad`). weewx does NOT auto-migrate schemas on upgrade. v3.2.0–3.9.x computed maxSolarRad but silently discarded it (no column in `wview` schema).
- **(d) Recomputation: fully feasible, identical to live values.** Ryan-Stolzenbach formula (`solar_rad_RS()`) needs only: station lat/lon/altitude (static config), timestamp (always in archive), and atc=0.80 (constant). All available for every historical record. `weectl database calc-missing` does exactly this. External Python script using `ephem` produces identical results. Recomputed values are not inferior — they are computationally equivalent.
- **(e) Realistic scenarios:**
  - **Best case** (weewx ≥4.0 + ephem + near US EPA monitor): maxSolarRad already in archive. Download 2 EPA AQS annual CSVs. Bootstrap in hours.
  - **Moderate case** (weewx 3.x + non-US station): Recompute maxSolarRad via calc-missing. Download PM data from OpenAQ S3. Bootstrap in a day with preprocessing.
  - **Worst case** (no nearby PM monitoring station): maxSolarRad recomputable, but no historical PM data available. Must wait for real-time AQI provider accumulation. Baseline takes ~4–6 months to reach 22-sample minimum per 90-day window.

---

## Research Agent Assignments

| Phase | Task | Agent Model | Justification |
|-------|------|-------------|---------------|
| R1.1 | Hänel + Tang papers | Sonnet | Mechanical: search, fetch, extract data tables |
| R1.2 | Long & Ackerman paper | Sonnet | Mechanical: search, fetch, extract algorithm |
| R1.3 | Mie scattering verification | Sonnet | Mechanical: search for authoritative source, extract answer |
| R2.1 | BSRN/SURFRAD methodology | Sonnet | Moderate: search + synthesize from multiple sources |
| R2.2 | Ryan-Stolzenbach model | Sonnet | Mechanical: read weewx source + find original paper |
| R3.1 | METAR/FMH-1/WMO codes | Sonnet | Mechanical: search for public documents, extract tables |
| R3.2 | GFE text formatter | Sonnet | Moderate: search for open-source repo, assess architecture |
| R4.1 | Cirrus vs aerosol literature | Sonnet | Moderate: literature search, honest null result is valid |
| R4.2 | Fog detection literature | Sonnet | Moderate: search + extract standard criteria |
| R5.1 | AQI provider historical survey | Sonnet | Mechanical: check provider API docs |
| R5.2 | weewx maxSolarRad history | Sonnet | Mechanical: search weewx changelogs |
| ALL QC | Synthesis after each phase | **Coordinator (Opus)** | Judgment: evaluate defensibility, identify gaps, synthesize |

**Budget management:**
- Total: ~11 Sonnet agent dispatches across all phases. Run max 2-3 in parallel at a time.
- Coordinator QC between each phase pair — don't launch the next batch until the previous is reviewed.
- **Hard stop:** If session budget drops below 30%, pause and report status to user.

**Phasing sequence:**
```
Batch 1: R1 (3 agents) + R3 (2 agents) → QC   ✅ COMPLETE
Batch 2: R2 (2 agents) + R4 (2 agents) → QC   ✅ COMPLETE
Batch 3: R5 (2 agents) → QC → SYNTHESIS → Refine Part 2   ✅ COMPLETE
```

---

## Research QC Gates

### Gate RQ1 — Source Quality
- Every claim in an archived summary must cite a specific source (paper, URL, code file)
- "Based on general knowledge" or unsourced assertions are REJECTED
- If a paper is paywalled and only the abstract is available, the summary must say so and flag which claims are abstract-only vs full-text-verified

### Gate RQ2 — Mathematical Verification
- Every formula extracted must include variable definitions and units
- Coordinator spot-checks one formula per paper against dimensional analysis
- If the competitor document's claimed values (γ = 0.25/0.40, RH thresholds 70%/85%) match the source: record as VERIFIED
- If they don't match: record the ACTUAL values from the source and note the discrepancy

### Gate RQ3 — Completeness
- Each archived summary must explicitly state what was found AND what was NOT found
- A null result ("no papers found on X") is a valid and valuable finding — do not backfill with speculation

### Gate RQ4 — Archival Integrity
- Fetched content must be saved to `docs/reference/` BEFORE the summary is written
- The summary must reference the archived file
- If a web page disappears, the archived copy is the record

---

# PART 2: IMPLEMENTATION OUTLINE (Placeholders — refine after research)

## Track A: Conditions Engine Expansion — Haze, Fog, Mist, Smoke

### A1. AQI Data Channel into Enrichment Pipeline
- Wire PM2.5 and PM10 from the existing AQI provider cache into the enrichment pipeline
- New smoothed input buffers for PM data (window TBD — depends on provider update frequency)
- Handle provider latency: Aeris (minutes) vs AirNow (60+ min) vs model-based (N/A)
- Config: `[enrichment] aqi_provider = aeris|airnow|owm|openmeteo|iqair|none`
- **Smoothing window:** 60-minute rolling average for PM data (PM changes slowly; AQI providers update hourly at best). Shorter window for Aeris (minutes latency); longer for AirNow (60+ min lag).
- **Fallback behavior:** If AQI provider returns no data or stale data (>2 hours old), suppress haze detection — do not report "no haze" (absence of evidence ≠ evidence of absence). Existing sky classifier continues as-is. If provider permanently unavailable, haze detection degrades to pyranometer-only deficit reporting without PM confirmation.
- **Provider priority for real-time:** Aeris (best: observed, low latency) → AirNow (good: observed, high latency) → OpenAQ (acceptable: variable lag) → IQAir (limited: free tier lacks raw PM). OWM and OpenMeteo return model forecasts, not observations — do NOT use for haze confirmation.

### A2. Haze Detection Module
- New module: `weewx_clearskies_api/sse/haze_condition.py` (or integrated into sky_condition.py — TBD)
- Two-layer architecture:
  - Layer 1 (existing): CAELUS classifier → cloud vs clear
  - Layer 2 (new): clean-day Kcs baseline vs current Kcs → aerosol extinction
- **Solar elevation gate: el > 10–15°** — Kcs unreliable below this (R2.2: ~20% R-S model error at dawn/dusk)
- PM2.5 + PM10 as primary confirmation gate
- RH as haze type discriminator (dry haze < 70% RH vs damp haze 70–85% RH)
- f(RH) Hänel correction: `f(RH) = [(1 − RH) / (1 − RH_ref)]^(−γ)` — **use default γ ≈ 0.4–0.5** (moderate, composition-unknown). γ is a composition property, NOT a size property (R1.1). Allow operator config by region if desired.
- Wet deposition gate: suppress haze during/after rain
- *Placeholder: exact deficit ranges, PM thresholds TBD after research synthesis*

### A3. Auto-Calibration Baseline System
- Statistical sampling of clean-day Kcs profiles over time
- Bootstrap from weewx archive + historical AQI data (rate-limited, operator-approved, resumable)
- Mix-and-match historical sources: Aeris API, AirNow CSVs (free), OpenAQ (free), operator file upload
- **No time-of-day bins** — cos(Z) normalization via maxSolarRad handles the diurnal cycle (R2.1: no reviewed network uses time-of-day stratification)
- **90-day rolling seasonal window** — seasonal stratification IS needed; 90-day is seasonal-adjacent without requiring 12× the data (R2.1)
- **90th–95th percentile baseline** — the "clean ceiling." 85th percentile (Renner 2019) is for climate research where hazy-clear is "normal"; haze detection needs higher to exclude routine hazy-clear days (R2.1)
- **~22 clean-sky samples minimum** per calibration period before baseline activates (scaled from ARM's 110-minute/1-min-data threshold, R2.1)
- Persistent storage across API restarts
- Recompute maxSolarRad for older archive records where NULL
- **"Clean" sample PM threshold:** PM2.5 < 12 µg/m³ AND PM10 < 50 µg/m³ (EPA "Good" AQI breakpoints). A day with PM above these values is excluded from clean-sky baseline regardless of Kcs value.
- **Convergence criteria:** Baseline activates when ≥22 clean-sky samples accumulated in the current 90-day window (from R2.1). Once active, continues to update with each new clean sample. If sample count drops below 15 (seasonal transition, extended haze period), degrade to wider-window fallback (180-day). Report calibration confidence in admin UI: "bootstrapping" (<22), "calibrated" (22–50), "well-calibrated" (>50).
- **Bootstrap data sources (from R5.1):** US: EPA AQS annual CSV (free, hourly, PM2.5 param 88101). Non-US: OpenAQ S3 archive. Aeris: supplement if subscribed (Jan 2024+). All return raw PM2.5/PM10 µg/m³.
- **maxSolarRad for older records (from R5.2):** If absent/NULL in weewx archive, recompute using Ryan-Stolzenbach formula from station lat/lon/altitude + record timestamp + atc=0.80. Values identical to what weewx would have stored. Use `weectl database calc-missing` or external script.

### A4. Fog Detection Improvements
- Current: T-Td ≤ 1°F → "Foggy" — **4× too conservative** (ASOS uses T-Td ≤ 4°F, R4.2)
- Multi-parameter approach (Izett et al. 2018: >90% hit rate, 13% false alarm):
  1. **Widen T-Td threshold to 4°F** — matching ASOS operational standard
  2. **Wind gate:** "Foggy" only when wind ≤ 8 mph; "Misty" for 8–15 mph; suppress fog above 15 mph
  3. **Daytime solar suppression:** suppress "Foggy" when solar radiation significant + T-Td 2–4°F (that's humid air, not fog)
  4. **PM2.5 disambiguation:** T-Td ≤ 4°F + elevated PM2.5 (> 35 µg/m³) → prefer "Hazy" over "Foggy"
  5. **Rain gate:** suppress fog during active precipitation
  6. **Fog/mist split:** T-Td ≤ 2°F → "Foggy"; T-Td 2–4°F → "Misty" (aligns with FMH-1 FG/BR distinction)
- Fog dissipation: suppress fog label after sunrise when solar radiation exceeds threshold (Kcs > 0.5)
- **Irreducible limitation:** without visibility sensor, we report "conditions favorable for fog," not confirmed fog. This matches WMO 4680 automated station constraints.

### A5. Cirrus vs Smoke Discrimination
- **CONFIRMED: cannot reliably distinguish with broadband pyranometer + surface PM** (R4.1 — physics constraint, not algorithm gap). Duchon & O'Malley (1999): ~45% agreement under mixed conditions.
- **Approach: report uncertainty, not guesses.**
  - Surface PM elevated → "Haze" (high confidence)
  - Surface PM clean + smooth deficit → "Unknown uniform layer" (honest uncertainty)
- **Optional ancillary discriminator: GOES-16 Band 4 (1.38 µm)** — free on AWS S3, 10-min CONUS latency. Cirrus is bright in this water-vapor-absorption channel; low-altitude haze is invisible. Converts the binary ambiguity into a three-branch decision tree.
  - PM clean + Band 4 bright → "Thin Cirrus" (moderate confidence)
  - PM clean + Band 4 dim → "High-Altitude Haze/Smoke" (moderate confidence)
- GOES-16 integration is optional/future — the system works without it by reporting honest uncertainty
- For certainty: spectral radiometer ($5K–$15K, MFRSR-class) or backscatter lidar — outside consumer reach

### A6. Display Labels and Composition
- **CORRECTED (R3.1):** NWS convention is "Hazy." as a *separate sentence*, NOT a compound modifier. Not "Sunny with Haze" or "Hazy and Sunny."
- NWS text pattern: `"{Sky Condition}. Hazy."` — e.g., "Sunny. Hazy." / "Mostly Clear. Hazy."
- Fog labels: "Foggy" (T-Td ≤ 2°F), "Misty" (T-Td 2–4°F)
- Fog as separate sentence too: "Foggy." / "Patchy Fog." / "Patchy Fog before 11am. Otherwise, mostly sunny."
- WMO weather code additions: 05 (Haze), 10 (Mist), 45 (Fog), 48 (Depositing rime fog)
- Temporal coherence filter for haze (match existing 15-min persistence)
- **Terse verbosity:** May use compound form for brevity — "Sunny, Hazy" — diverging from strict NWS convention for the terse level. Standard and verbose levels follow NWS separate-sentence convention.

### A6.5. Nighttime Mode — Provider Deferral + Local Fog
- At night (el ≤ 0° or below the 10–15° haze detection gate), the pyranometer contributes nothing. Rather than attempting PM-only haze detection (single-channel, lower confidence), defer to the provider's current conditions observations — the same pattern already used for nighttime cloud cover.
- **Nighttime channel assignments:**
  - **Cloud cover:** provider observation (existing behavior, unchanged)
  - **Haze/smoke:** provider current conditions present weather field. Provider observation stations have visibility sensors and present weather detectors that we lack — let them do what they're better equipped to do.
  - **Fog/mist:** LOCAL multi-parameter detection (T-Td + wind + nighttime flag). This is the one condition we CAN detect locally at night without the pyranometer. Nighttime is when radiation fog forms; T-Td + calm wind + post-sunset is the strongest signal, and our sensors capture all of it.
- **Sunrise handoff:** When solar elevation crosses the 10–15° gate, the full local model resumes — two-channel haze detection, solar-based fog dissipation tracking, the complete engine. Provider haze/smoke observations stop being authoritative; local detection takes over.
- **Why not PM-only haze at night:** Provider observation stations (ASOS/AWOS at airports, reference monitors) have visibility sensors and can directly observe haze. Our PM2.5 data comes from the same monitoring network the providers use. Attempting to re-derive haze from PM alone is duplicating the provider's work with less information. The one exception — fog — is where our hyper-local sensors (station-level T-Td, not airport 10 km away) genuinely add value.

### A7. Configuration
- `[enrichment] haze_detection = true|false` (default: true)
- `[enrichment] haze_aqi_provider = ...` (may differ from forecast AQI provider)
- Admin UI: haze calibration section showing baseline status, clean-day count, current σ estimate
- **Bootstrap config:** Admin UI page for historical PM data import. Accept EPA AQS CSV, generic CSV, OpenAQ format. Show nearest-monitor distance, import progress, date range coverage. CLI equivalent: `clearskies-api bootstrap --pm-source file.csv --format epa-aqs`.
- **Full config schema:** defined during implementation design phase.

### A8. Hero Icon for Haze
- Day variant: Muted/pale sun disk (no sharp rays), horizontal lines in smoky gray/dusty tan
- Night variant: Obscured stars + dirty haze layer
- Follows icon system rules in DESIGN-MANUAL.md
- *Placeholder: exact icon design TBD — separate design task*

---

## Track B: NWS/WMO Text Generation System

### B1. Structured Local Observation Model
- Map every local sensor reading and derived value to METAR/WMO fields
- Fields: temperature, dewpoint, wind (speed + direction + gusts), sky condition (CLR/FEW/SCT/BKN/OVC), present weather (HZ/FG/BR/RA/SN/etc.), pressure, visibility estimate
- This is the bridge between our sensors and the text rules
- **R3.1 provided:** Complete WMO code tables (4677/4680), ASOS discrimination algorithm, present weather codes with visibility thresholds. Sufficient to build the observation model.
- **Key mapping needed:** CAELUS sky classes → NWS okta equivalents (CLOUDLESS→CLR, THIN_CLOUDS→FEW/SCT, etc.) — to be designed during implementation

### B2. Present Weather Code System
- Expand existing `_derive_weather_code()` to cover full WMO 4677/4680 code tables
- Add HZ (haze), BR (mist), FU (smoke) codes — depends on Track A detection
- Map provider precipitation types to WMO codes
- *Placeholder: full code mapping TBD after R3.1*

### B3. Text Generation Engine
- Rules-based (lookup table + grammar), NOT LLM-generated
- **Extract GFE vocabulary, don't transplant framework** (R3.2). Port threshold tables from AWIPS-II phrase libraries (ScalarPhrases, WxPhrases, VectorRelatedPhrases) — pure Python, no AWIPS dependency.
- Key GFE thresholds to port: sky coverage (6 buckets, ~8 lines), temperature decades (~30 lines), wind descriptors (25/30/40/50/74 mph thresholds), gust qualification (>10 mph above sustained), conjunction grammar
- Multiple verbosity levels:
  - **Terse:** Current `weatherText` style — "Sunny, Hazy, Warm and Humid"
  - **Standard:** "Sunny. Hazy. Temperature near 85°F. South winds around 8 mph."
  - **Verbose:** Full narrative for HA/displays — "Currently 85°F under hazy sunshine. Dew point 72°F..."
- NWS phrasing conventions: separate-sentence haze/fog, "with" for precipitation modifying sky, day/night terminology (Sunny/Clear, Partly Sunny/Partly Cloudy)

### B4. Forecast Narrative Generation (Future)
- Convert provider forecast data into written narrative text
- **R3.2 confirmed feasible:** GFE text formatter is open source Python, phrase libraries are extractable. TimeDescriptor.py maps periods → "Tonight", "Saturday", etc.
- Period-based: "Tonight:", "Saturday:", "Saturday Night:", etc.
- **Separate plan** — depends on forecast provider data model maturity. Deferred until Track A + B1–B3 are implemented.

### B5. Provider-to-Common-Model Mapping
- Map each forecast/observation provider's output to the common observation model
- Ensure global coverage — not all providers use METAR conventions
- *Placeholder: per-provider mapping tables TBD*

---

## Dependencies Between Tracks

```
Research R1-R5
      ↓
Track A (Haze/Fog)  ←→  Track B (Text System)
      ↓                        ↓
A1 (AQI channel)         B1 (Observation model)
      ↓                        ↓
A2 (Haze detection)       B2 (Weather codes)  ← A2 feeds new codes to B2
      ↓                        ↓
A3 (Auto-calibration)    B3 (Text engine)     ← A6 labels feed B3 text composition
      ↓                        ↓
A4 (Fog improvement)     B4 (Forecast text)   ← future, may split off
      ↓
A5 (Cirrus/smoke)
      ↓
A6 (Labels) → B2 (codes) → B3 (text)
```

Track A and Track B are interdependent at A6↔B2↔B3 — new detection capabilities (haze, improved fog) produce new labels and weather codes that feed into the text system. But the research for each is independent and can proceed in parallel.

---

## Open Items (Parked for Post-Research)

1. ~~What PM2.5/PM10 thresholds constitute "elevated" for haze confirmation?~~ — **ANSWERED (R4.2 + synthesis):** Two-tier system. **Haze confirmation (dry, RH < 70%):** PM2.5 > 12 µg/m³ (EPA "Moderate" AQI breakpoint, also the annual NAAQS standard). **Fog/haze disambiguation (humid, T-Td ≤ 4°F):** PM2.5 > 35 µg/m³ → prefer "Hazy" over "Foggy" (from PMC8361198 research). PM10 thresholds: > 50 µg/m³ for dust/sand haze (coarse-mode-dominated events, coastal/desert). Empirical tuning expected during implementation.
2. ~~Exactly how many clean-sky samples per bin for a defensible baseline?~~ — **ANSWERED (R2.1):** ~22 samples per calibration period, 90-day rolling window, 90th–95th percentile, no time-of-day bins.
3. ~~Can we distinguish cirrus from smoke, or is this an honest limitation?~~ — **ANSWERED (R4.1):** Honest limitation. Cannot distinguish with consumer instruments. GOES-16 Band 4 is best free ancillary.
4. ~~Is the GFE text formatter practical to adapt, or do we build our own?~~ — **ANSWERED (R3.2):** Extract vocabulary/thresholds from GFE phrase libraries (pure Python, public domain). Don't transplant the framework.
5. ~~What is the interaction between haze detection and nighttime conditions?~~ — **ANSWERED (synthesis + user decision).** Nighttime haze/smoke defers to provider current conditions observations — same pattern as existing nighttime cloud cover deferral. Provider stations have visibility sensors and present weather detectors we lack. Fog/mist remains LOCAL at night (T-Td + wind + nighttime flag — pyranometer not needed, and our hyper-local sensors add genuine value over airport observations 10 km away). Full local model resumes at sunrise when el crosses the 10–15° gate.
6. ~~Should high-altitude smoke get its own distinct display label?~~ — **ANSWERED (R4.1):** No — we cannot reliably identify it. Report as "Unknown uniform layer" or use GOES-16 Band 4 ancillary data for moderate-confidence "High-Altitude Haze/Smoke."
7. ~~Visibility estimation from σ_haze — is this feasible and defensible?~~ — **ANSWERED (synthesis).** Feasible for qualitative estimates, not for precise values. Koschmieder's law (V = 3.912 / σ_ext) converts extinction to visibility, but requires mixing layer depth assumption (~1–2 km). Lindfors (2013) validated pyranometer AOD at r=0.90 vs AERONET (R1.3), giving ±20% AOD uncertainty. Combined with mixing layer assumption, visibility estimate accuracy is ±30–50%. **Recommendation:** Provide qualitative visibility categories ("Good" / "Moderate" / "Poor") rather than numeric statute miles. Use PM2.5 concentration as the primary indicator (well-established PM2.5 → visibility empirical relationships exist, and PM is what we actually measure — PMC8361198). If METAR-like numeric visibility needed for the observation model (B1), use Koschmieder with standard 1.5 km mixing height and flag the uncertainty explicitly.
8. ~~File upload mechanism for operator-provided historical PM data~~ — **ANSWERED (R5.1).** R5.1 mapped the provider landscape. Primary formats to accept: (a) EPA AQS annual CSV format (well-defined, per-parameter-code, per-year zipped CSV). (b) Generic CSV with columns: timestamp, PM2.5 (µg/m³), PM10 (µg/m³). (c) OpenAQ export format (location-organized gzip CSV). Implementation: standard file upload in admin UI + CLI import command. Validate: timestamp format, numeric PM values, reasonable range (0–999 µg/m³). Deduplicate by timestamp on import. Map nearest-station proximity (warn if monitor is >25 km from PWS).

---

# RESEARCH SYNTHESIS (2026-06-21)

All 11 research agents completed across 5 phases (R1–R5). This section consolidates the design-impacting findings, their scientific basis, and remaining gaps.

## Design-Impacting Decisions — Scientific Basis

### D1. Haze Detection: Two-Channel Confirmation Required

**Decision:** Daytime haze is reported ONLY when both pyranometer deficit AND elevated PM are present. Neither channel alone is sufficient. Nighttime haze defers to provider current conditions observations (provider stations have visibility sensors we lack). Fog/mist uses local sensors day and night.

**Scientific basis:**
- R1.2 (Long & Ackerman): L&A clear-sky detection algorithm validates Kv for cloud-free identification, but explicitly CANNOT distinguish haze from clear sky — hazy-but-stable conditions pass all four tests. PM is scientifically necessary for discrimination.
- R4.1 (Cirrus vs aerosol): Duchon & O'Malley (1999) showed ~45% agreement under mixed conditions — pyranometer deficit without PM confirmation has a coin-flip false positive rate for haze vs cirrus.
- R4.2 (Fog detection): PMC8361198 showed PM2.5 effect on visibility is negligible at RH > 89% (phenomenon is fog) but dominant at RH < 80% (phenomenon is haze). PM is the discriminator.

### D2. f(RH) Hygroscopic Correction: Use Moderate Default γ

**Decision:** Use γ ≈ 0.4–0.5 (moderate, composition-unknown). Do NOT assign γ by particle size.

**Scientific basis:**
- R1.1 (Hänel/Tang): γ is a COMPOSITION property, not a SIZE property. The competitor document's claim of γ ≈ 0.25 for PM2.5 and γ ≈ 0.40 for PM10 conflates size with composition. Actual literature values span 0.12 (mineral dust) to 1.52 (sea salt). Without composition data from speciated monitors, a moderate default is the only defensible choice. Allow operator regional override.

### D3. Auto-Calibration: No Time-of-Day Bins

**Decision:** cos(Z) normalization (via Kcs = GHI/maxSolarRad) handles the diurnal cycle. No time-of-day binning. Use 90-day rolling seasonal windows.

**Scientific basis:**
- R2.1 (BSRN/SURFRAD): ARM, BSRN, and SURFRAD all converge on Long & Ackerman's methodology — no reviewed radiation network uses time-of-day stratification. cos(Z) normalization is standard. Seasonal stratification IS needed; 90-day windows are the operational norm.
- R2.1 (Renner et al. 2019): 85th percentile used across 42 BSRN stations for climate baseline. For haze detection (higher bar — exclude routine hazy-clear days), target 90th–95th percentile.
- R2.1 (Sample size): ~22 samples minimum per period, scaled from ARM's 110-minute/1-min-data threshold.

### D4. Solar Elevation Gate: el > 10–15°

**Decision:** Suppress all haze detection below 10–15° solar elevation. Kcs is unreliable at low sun angles.

**Scientific basis:**
- R2.2 (Ryan-Stolzenbach): Confirmed from weewx source code. `atc` is a single lumped parameter bundling ALL extinction. At low elevation, the R-S model underestimates maxSolarRad by ~20%, producing Kcs > 1.0 under clear conditions. The 85° SZA guard in the existing classifier (equivalent to el > 5°) is insufficient for haze detection, which requires a tighter gate.

### D5. Fog: Widen to 4°F, Add Multi-Parameter Filtering

**Decision:** Replace T-Td ≤ 1°F with multi-parameter approach: T-Td ≤ 4°F + wind ≤ 8 mph + nighttime/solar suppression + PM disambiguation + rain gate.

**Scientific basis:**
- R4.2 (Fog literature): Current 1°F threshold is 4× too conservative vs ASOS operational standard (4°F). Single-variable T-Td detection yields ~40% false alarm rate (Izett et al. 2018). Multi-parameter approach (RH + wind + radiation) achieves >90% hit rate, 13% false alarm. WMO 4680 for automated stations sanctions T-Td as the haze/mist discriminator.
- Fog/mist split: T-Td ≤ 2°F → "Foggy"; T-Td 2–4°F → "Misty" (aligns with FMH-1 FG/BR distinction).

### D6. Cirrus vs Smoke: Honest Uncertainty

**Decision:** Cannot distinguish with consumer instruments. Report "Unknown uniform layer" for smooth deficit + clean PM. Optional GOES-16 Band 4 ancillary for moderate-confidence discrimination.

**Scientific basis:**
- R4.1 (Cirrus vs aerosol): Physics constraint confirmed across multiple studies. Surface PM2.5 does not correlate with column aerosol optical depth for transported smoke (R² = 0.03–0.60). Best free discriminator: GOES-16 Band 4 (1.38 µm, water vapor absorption channel) — cirrus bright, low-altitude haze invisible. 10-min CONUS latency, free on AWS S3.

### D7. Broadband GHI Is a Valid Haze Proxy

**Decision:** Pyranometer GHI deficit is a scientifically established measure of aerosol extinction.

**Scientific basis:**
- R1.3 (Mie scattering): Mie scattering for haze particles (0.1–10 µm) is weakly wavelength-dependent (Ångström exponent α ≈ 1.0–1.5 for typical haze, vs α = 4 for Rayleigh). Lindfors et al. (2013) validated pyranometer-derived AOD at r = 0.90 vs AERONET, ±20% uncertainty. Broadband Linke turbidity methods have been operational since 1922.

### D8. NWS Text System: Extract, Don't Transplant

**Decision:** Port GFE threshold tables and phrase libraries from AWIPS-II (pure Python, public domain). Build our own text engine using NWS grammar conventions.

**Scientific basis:**
- R3.1 (METAR/FMH-1): Complete WMO code tables documented. ASOS HZ/BR/FG discrimination algorithm confirmed. Present weather codes with visibility thresholds captured. Sufficient for observation model.
- R3.2 (GFE formatter): AWIPS-II is open source. ScalarPhrases, WxPhrases, VectorRelatedPhrases are pure Python with no AWIPS imports. Threshold tables are compact (~8 lines for sky, ~30 lines for temperature, ~10 lines for wind). Estimated 1–3 days implementation.
- R3.1 (Correction): NWS convention is "Hazy." as a separate sentence, not "Hazy and Sunny" or "Sunny with Haze."

### D9. Bootstrap Is Practical for Most Operators

**Decision:** Historical data bootstrap is feasible using free public data sources. Mix-and-match approach covers most station configurations.

**Scientific basis:**
- R5.1 (AQI survey): EPA AQS bulk CSV (free, 1980-present, hourly PM2.5/PM10) covers US. OpenAQ S3 archive (free, 2016-present, 141 countries) covers non-US. All return raw µg/m³ values, not just composite AQI.
- R5.2 (maxSolarRad): Recomputable from lat/lon/altitude/timestamp using R-S formula. `weectl database calc-missing` or external script. Computationally identical to live-recorded values. Available for weewx 4.0.0+ natively; recomputable for any older version.

## Competitor Document Assessment (Final)

The unverified competitor-generated analysis document that prompted this research contained several errors now confirmed:

| Claim | Verdict | Correct Value |
|-------|---------|---------------|
| γ ≈ 0.25 for PM2.5, γ ≈ 0.40 for PM10 | **WRONG** — conflates size with composition | γ ranges 0.12–1.52 by composition; use 0.4–0.5 default |
| 70%/85% RH boundaries from Hänel/Tang | **WRONG** — these are IMPROVE/monitoring network operational conventions | Not from the cited papers; 80% RH is the scientifically supported haze/fog crossover |
| "Hazy and Sunny" display label | **WRONG** — not NWS convention | NWS uses "Sunny. Hazy." (separate sentences) |
| Broadband pyranometry cannot detect haze | **WRONG** — opposite is true | Established since 1922; validated at r=0.90 vs AERONET |

The competitor document was useful as a starting point but required verification on every quantitative claim. The research program confirmed this was the right call.

## Remaining Gaps Before Implementation

All 8 open items are now resolved to the level needed for implementation design. One area will require empirical tuning during implementation:

1. **PM2.5 threshold for haze confirmation (12 µg/m³):** Based on EPA AQI breakpoints, scientifically grounded, but optimal value for PWS-scale detection may differ. First implementation should log deficit + PM pairs to enable threshold optimization.

Nighttime haze is no longer a gap — provider deferral (same pattern as nighttime cloud cover) eliminates the need for PM-only haze detection and its associated confidence concerns. Fog/mist continues locally at night using T-Td + wind, which doesn't need the pyranometer.

No additional research is needed before implementation begins. The science is settled on all load-bearing questions.

## Research Archive Inventory

| File | Phase | Content |
|------|-------|---------|
| `docs/reference/haze-physics/hanel-1976-summary.md` | R1.1 | Hänel growth equation, γ values by composition |
| `docs/reference/haze-physics/tang-1996-summary.md` | R1.1 | Tang hygroscopic aerosol properties, deliquescence |
| `docs/reference/haze-physics/long-ackerman-2000-summary.md` | R1.2 | L&A clear-sky detection algorithm, Kv validation |
| `docs/reference/haze-physics/mie-scattering-summary.md` | R1.3 | Mie scattering wavelength dependence, broadband validity |
| `docs/reference/haze-physics/clear-sky-baseline-methodology.md` | R2.1 | BSRN/SURFRAD/ARM methodology, sample sizes, percentiles |
| `docs/reference/haze-physics/ryan-stolzenbach-model.md` | R2.2 | weewx R-S formula, atc parameter, low-elevation limitations |
| `docs/reference/haze-physics/cirrus-vs-aerosol-discrimination.md` | R4.1 | Physics constraint on discrimination, GOES-16 Band 4 option |
| `docs/reference/haze-physics/fog-detection-literature.md` | R4.2 | Fog/mist/haze criteria, multi-parameter algorithm, Izett et al. |
| `docs/reference/haze-physics/aqi-historical-data-survey.md` | R5.1 | Provider historical data: EPA AQS, OpenAQ, Aeris, IQAir |
| `docs/reference/haze-physics/weewx-maxsolarrad-history.md` | R5.2 | maxSolarRad schema history, recomputation feasibility |
| `docs/reference/nws-text-system/metar-present-weather-codes.md` | R3.1 | WMO code tables, ASOS algorithm, present weather codes |
| `docs/reference/nws-text-system/observation-text-rules.md` | R3.1 | NWS observation text composition rules |
| `docs/reference/nws-text-system/gfe-text-formatter-assessment.md` | R3.2 | AWIPS-II GFE architecture, extractable phrase libraries |

---

# APPENDIX A: Planning Session Scratchpad (2026-06-21)

Full discussion context, decision rationale, and verified findings from the planning session that produced this plan.

---

## A.1. Core Concept

Expand the existing CAELUS-based conditions text engine to detect haze when the sky classifier reports clear or mostly-clear conditions. Haze is definitionally a particulate phenomenon — not a humidity phenomenon. Detection requires BOTH pyranometer signal analysis AND particulate data confirmation.

## A.2. What We Already Have (Engine Capabilities)

- CAELUS sky classifier: Kcs (instantaneous clear-sky ratio), Km (mean clearness), Kv/Kvf (variability indices)
- THIN_CLOUDS class (Km > 0.5, Kv ∈ [0.03, 0.08)) → maps to "Mostly Clear" — catches thin uniform layers but can't distinguish cirrus from haze
- CLOUDLESS class (Km > 0.6, Kcs ∈ [0.85, 1.15], Kv < 0.03) → "Clear"
- SZA < 85° guard + clear-sky detrending (Stein et al. 2012)
- Smoothed inputs: outTemp, dewpoint, appTemp (10 min), windSpeed/windGust (5 min), rainRate (2 min)
- AQI providers built (Aeris, OWM, OpenMeteo, IQAir) — BUT NOT wired into enrichment pipeline
- Fog override: T - Td ≤ 1°F → "Foggy"
- 15-minute temporal coherence filter
- Provider cloud-cover fallback (night/twilight)

## A.3. Decision Tree for Haze Detection (Draft)

When sky classifier returns CLOUDLESS or THIN_CLOUDS (smooth signal, clear/mostly-clear):

```
[Smooth pyranometer signal + moderate deficit detected]
         |
    Check PM2.5 AND PM10
    /            |              \
 High PM    Low PM surface    No PM data available
    |       + deficit present      |
    |            |           [Cannot confirm haze;
    |       High-altitude    report sky class only,
    |       smoke/haze       optionally note deficit]
    |       (column disconnect)
    |
  Check RH
  /        \
RH < ~70%   RH 70-85%
   |            |
True Haze    Damp Haze
(dry          (hygroscopic
particulate)  swelling —
              particles absorb
              water vapor,
              swell, scatter
              more light)
```

Key insight from user: "If we have high humidity, but an AQI of 7 with low PM 2.5/10 then we are not dealing with haze." PM is the PRIMARY gate, not RH. RH modulates the TYPE/severity of haze, PM confirms its existence.

### Fog vs Haze Discrimination
- Fog: RH ≥ 95%, T-Td ≤ 1°C, smooth severely suppressed curve — already handled
- Haze: RH < ~70-85%, elevated PM, smooth curve with moderate (not severe) deficit
- Damp haze: RH 70-85%, elevated PM, enhanced scattering due to hygroscopic swelling

### Cirrus vs Smoke (Open Problem)
Both produce smooth signals with no surface PM impact:
- Thin cirrus: ice crystals at 20,000+ ft, no surface PM, temporally stable, jet-stream-driven
- High-altitude smoke: aerosol layer at 5,000-15,000 ft, no surface PM, often seasonal (wildfire)
- Discrimination approaches to research:
  - NWS forecast data (does forecast mention cirrus / high clouds?)
  - Seasonal wildfire data (NOAA HMS smoke maps?)
  - Temporal pattern (cirrus tends to move steadily; smoke tends to linger and layer)
  - Deficit magnitude (smoke layers tend to cause deeper, more uniform attenuation)

## A.4. PM2.5 vs PM10 — Both Matter

- PM2.5: Fine combustion particles (wildfire smoke, industrial, vehicle exhaust)
- PM10: Coarse particles (dust, sand, sea salt, pollen)
- Desert stations: PM10-dominant during dust events
- Coastal stations: Sea salt → PM10
- Urban: PM2.5-dominant from combustion
- Wildfire: PM2.5-dominant from smoke

The f(RH) Hänel growth correction uses different γ values:
- γ ≈ 0.25 for PM2.5 (fine combustion)
- γ ≈ 0.40 for PM10 (coarse dust/sea salt)
→ VERIFY THESE against Hänel 1976 and Tang 1996

## A.5. AQI Provider Data Quality for Haze Detection

| Provider | Data type | Latency | Suitability for haze |
|---|---|---|---|
| AirNow (US EPA) | Regulatory monitors | 60+ min lag | Poor for real-time; good for daily baseline |
| Aeris/Xweather | Blended real-time | Fast (minutes) | Best fit for real-time haze confirmation |
| OWM | SILAM forecast MODEL | N/A — not observation | Poor — gives predicted, not observed PM |
| OpenMeteo | Model-based | N/A — not observation | Poor — same issue as OWM |
| IQAir | Hybrid (monitors + crowd) | Moderate | Usable but free tier omits raw PM values |
| OpenAQ | Government monitors | Varies by station | Good quality, variable lag |

## A.6. Auto-Calibration (Statistical Sampling Over Time)

### Concept:
1. When conditions are: CLOUDLESS + PM < threshold + stable low RH → record Kcs profile as a "clean-day sample"
2. Accumulate samples over time in binned storage
3. The station's "clean sky baseline" emerges statistically from many samples
4. Haze deficit = clean-day Kcs baseline − current Kcs

### Statistical design principles:
- **Time-of-day binning:** Bin by solar elevation angle or hour-of-day.
- **Seasonal windows:** Rolling seasonal bins (e.g., 90-day windows or quarterly).
- **Quantile-based, not mean:** Use the 90th or 95th percentile of clean-day Kcs samples as the "clean ceiling."
- **Minimum sample count per bin:** Require N clean-day samples before calibrated baseline activates.
- **Ongoing refinement:** Baseline continues to update.

### Bootstrap from archive
Instead of waiting months/years, bootstrap from weewx archive cross-referenced against historical AQI.

**Provider API rate limit concerns:**
- Operator-specific rate limits and guardrails
- Small batch processing — throttled, resumable
- Cost transparency — estimate calls, operator approves before starting
- Mix-and-match sources: Aeris (paid), AirNow CSVs (free), OpenAQ (free), file upload

**maxSolarRad archive availability:**
weewx did NOT always archive maxSolarRad. Older records may need recomputation from station lat/lon/altitude + Ryan-Stolzenbach.

**Sampling period and design — needs scientific defense** (research items R2.1, R2.2).

### Storage:
- Persistent across API restarts (file or DB-backed)
- Structure: { season/month × hour/elevation_bin → [Kcs samples + confidence weight] → computed baseline percentile }

## A.7. Configuration: Haze Detection Toggle

- `[enrichment] haze_detection = true|false` in api.conf (default: true)
- Admin UI: checkbox in sky classification calibration section

## A.8. Atmospheric Thickness / Air Mass at Low Zenith — VERIFIED

**maxSolarRad comes entirely from weewx, NOT from Skyfield or the API.**

Data flow: weewx engine → loop packet → loop relay (Unix socket) → API sky_tap.py → sky classifier ring buffer.

**Ryan-Stolzenbach model parameters (from weewx StdWXCalculate docs):**
- `atc` (atmospheric transmission coefficient): default **0.8**, range 0.7–0.91. FIXED static.
- Alternative: Bras algorithm, `nfac` (atmospheric turbidity): default **2** (clear), range 2–5 (smoggy). Also FIXED static.

**CRITICAL: Do NOT modify atc, nfac, or any weewx clear-sky model constants.**

The gap between theoretical maxSolarRad and observed GHI IS the signal. Modifying the model to match reality would collapse the measurement. Auto-calibration operates at a HIGHER layer (learned clean-day Kcs baseline vs current Kcs), not by modifying model constants.

**Two-layer architecture:**
- **Layer 1 (existing, unchanged):** maxSolarRad (theoretical) vs GHI (observed) → Kcs → CAELUS classification
- **Layer 2 (new — haze detection):** clean-day Kcs (learned) vs current Kcs → aerosol extinction deficit

## A.9. Ozone and White Haze

Tropospheric ozone contributes to photochemical smog/haze but doesn't cause significant GHI attenuation at consumer sensor accuracy (absorption mostly in UV). Elevated ozone correlates with elevated PM2.5 (both photochemistry products). PM2.5 remains the correct proxy.

## A.10. NWS Data-to-Text Model

### Integration concept — two-part:

**Part 1: Build a structured local observation model (METAR-like)**

| Local source | METAR/WMO field | Status |
|---|---|---|
| outTemp | Temperature group | Available (smoothed) |
| dewpoint | Dewpoint group | Available (smoothed) |
| windSpeed + windDir | Wind group (with gusts) | Available (smoothed, Beaufort derived) |
| Sky classifier output | Sky condition (CLR/FEW/SCT/BKN/OVC) | Available (CAELUS + Km sub-splits) |
| Haze detection | Present weather HZ | NEW — requires this haze work |
| Fog detection (T-Td ≤ 1°) | Present weather FG | Available (existing override) |
| Precipitation type + rate | Present weather RA/SN/FZRA/etc | Available (WMO codes already derived) |
| barometer + trend | Pressure group (altimeter setting) | Available |
| Visibility estimate | Visibility group | NEW — could derive from haze σ + PM data |

**Part 2: Apply NWS-style text generation rules at multiple verbosity levels**
- Terse: Current `weatherText` style
- Standard: One-sentence observation
- Verbose: Full narrative for HA/displays

## A.11. Display / UX Considerations

### Haze Labels (NWS Convention)
Haze is a clear-sky modifier ONLY. "Hazy and Overcast" is INVALID.

### Hero Icon for Haze
- Muted/pale sun disk (no sharp rays), horizontal lines in smoky gray/dusty tan
- Day AND night variants needed

### Wet Deposition (Rain Scavenging)
Rain physically removes aerosols. After rainfall, haze should not be reported.

## A.12. Mathematical Framework Clarification

| Framework | Index | What it measures |
|---|---|---|
| **Beer-Lambert (σ, extinction)** | Kcs, Km | **Magnitude** of light extinction |
| **Differential calculus** | Kv, Kvf | **Variability pattern** — smooth vs jagged |

Both needed: Kv (differential) filters clouds, Kcs (σ-based) quantifies deficit, PM data confirms particulates.

## A.13. Verified: AQI Provider PM Data Availability

All four AQI providers return PM2.5 and PM10 in the canonical `AQIReading` model (`pollutantPM25`, `pollutantPM10`, both µg/m³). Aeris also returns O3, NO2, SO2, CO. Data exists but is NOT wired into the enrichment pipeline — served as separate endpoint only.

## A.14. Smog vs Cirrus — Research Needed

Potential discriminators: time-derivative profiles (d²I/dt²), temporal persistence (cirrus transits in 30 min–2 hours; smoke persists for days), PM as tiebreaker. Spectral signature is a dead end with broadband photodiode pyranometers. See research phase R4.1.
