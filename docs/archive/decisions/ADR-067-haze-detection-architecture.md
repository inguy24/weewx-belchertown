---
status: Archived — consolidated into API-MANUAL.md + PROVIDER-MANUAL.md
date: 2026-06-21
deciders: shane
supersedes:
superseded-by:
---

# ADR-067: Haze Detection Architecture

## Context

The CAELUS sky classifier distinguishes cloud cover levels from pyranometer data but cannot distinguish haze from clear sky. Long & Ackerman (2000) validated that smooth GHI signals (low Kv) identify cloud-free periods, but hazy-but-stable conditions pass all four L&A tests identically to clean clear sky (`long-ackerman-2000-summary.md`). Duchon & O'Malley (1999) showed ~45% agreement when using pyranometer data alone to classify aerosol vs cirrus (`cirrus-vs-aerosol-discrimination.md`).

Broadband pyranometer GHI deficit IS a scientifically valid measure of aerosol extinction — Lindfors et al. (2013) validated pyranometer-derived AOD at r=0.90 vs AERONET, ±20% uncertainty (`mie-scattering-summary.md`). But deficit alone cannot confirm that the cause is particulate matter vs thin cirrus. PM2.5/PM10 concentration provides the second channel needed for confirmation.

The competitor document contained four confirmed errors: gamma values conflating size with composition, RH boundaries misattributed to Hanel/Tang, incorrect display labels, and incorrect claim that pyranometry cannot detect haze.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Two-channel mandatory: pyranometer deficit + PM confirmation (chosen) | Scientifically defensible; eliminates cirrus false positives; both channels independently validated | Requires AQI provider with observed data (ADR-066); no haze detection when PM unavailable |
| PM-only detection | Simpler; works at night | No spatial precision (nearest monitor may be 25+ km away); cannot quantify local extinction |
| Pyranometer-only with statistical threshold | No external dependency | ~45% false positive rate for haze vs cirrus (Duchon & O'Malley 1999); not defensible |

## Decision

Two-channel confirmation required. Daytime haze is reported ONLY when both (1) pyranometer Kcs deficit below the auto-calibrated clean-sky baseline (ADR-068) AND (2) PM2.5 or PM10 exceeds the confirmation threshold from an observed-data provider (ADR-066). Specific parameters:

- **Solar elevation gate:** el > 10° (air mass < 5.8). Ryan-Stolzenbach model underestimates maxSolarRad by ~20% below this, producing unreliable Kcs (`ryan-stolzenbach-model.md`).
- **PM thresholds:** PM2.5 > 12 ug/m3 for dry haze (RH < 80%, EPA "Moderate" breakpoint). PM2.5 > 35 ug/m3 for fog/haze disambiguation when T-Td <= 4 deg F. PM10 > 50 ug/m3 for coarse-mode events (dust/sand).
- **f(RH) hygroscopic correction:** `f(RH) = [(1-RH)/(1-RH_ref)]^(-gamma)`, default gamma=0.45 (moderate, composition-unknown). Gamma is a composition property, NOT a size property — ranges 0.12 (mineral dust) to 1.52 (sea salt) per `hanel-1976-summary.md` and `tang-1996-summary.md`. Operator-configurable by region.
- **RH type discriminator:** RH < 80% = dry haze; RH 80-90% = damp haze (enhanced scattering from hygroscopic swelling). RH > 90% defers to fog/mist logic (ADR-069).
- **Wet deposition gate:** Suppress haze during and for 30 min after rain (rain scavenges aerosols).
- **Temporal coherence:** 15-minute persistence filter (matches existing sky classifier).
- **Cirrus/smoke limitation:** When Kcs deficit present but PM clean, report "unknown uniform layer" — honest uncertainty, not a guess. Optional GOES-16 Band 4 ancillary for moderate-confidence discrimination (deferred).

## Consequences

- **New module:** `sse/haze_condition.py` or integrated into `weather_text.py` — implements the two-channel decision tree.
- **Enrichment pipeline change:** PM2.5/PM10 from AQI provider cache must flow into the enrichment context (new smoothed input buffers in `input_smoother.py`).
- **Display labels:** "Hazy." as separate sentence (NWS convention per `observation-text-rules.md`). Haze is a clear-sky modifier only — "Hazy and Overcast" is invalid.
- **WMO weather codes:** Add code 05 (Haze). Priority: precipitation > fog > haze > sky.
- **No haze when PM unavailable:** System degrades gracefully — existing sky classifier continues as-is, optionally reports Kcs deficit for operator information.
- **Nighttime:** Defers to provider (ADR-071).

## Acceptance criteria

- [ ] Haze detected when BOTH Kcs deficit AND PM2.5 > 12 ug/m3 (or PM10 > 50 ug/m3) present
- [ ] Haze NOT detected when PM clean, regardless of Kcs deficit
- [ ] Haze NOT detected when el <= 10 deg
- [ ] Haze suppressed during and 30 min after rain
- [ ] f(RH) correction applied with configurable gamma (default 0.45)
- [ ] Temporal coherence filter prevents haze label flicker (15-min persistence)
- [ ] weatherText shows "Sunny. Hazy." format (separate sentence), not "Hazy and Sunny"
- [ ] Haze label suppressed when sky is cloudy/overcast (clear-sky modifier only)
- [ ] WMO weather code 05 emitted when haze detected
- [ ] Graceful degradation: no PM data = no haze label, existing classifier continues

## Implementation guidance

- **Extension point:** `weather_text.py` line ~166 (current fog override location). Add haze check after fog check. Haze and fog are mutually exclusive (RH boundary separates them).
- **PM data access:** Via `get_smoothed("pollutantPM25")` and `get_smoothed("pollutantPM10")` — new buffers in `input_smoother.py` (60-min window, 720 entries at 5-sec intervals).
- **Kcs deficit:** `current_kcs - baseline_kcs` where baseline comes from auto-calibration (ADR-068). Until calibrated, haze detection is inactive (no false positives from uncalibrated baseline).
- **Decision tree order:** (1) el > 10°? (2) Rain in last 30 min? (3) PM elevated? (4) RH < 90%? (5) Kcs deficit below baseline? All yes = haze. Steps 3+5 are the two-channel gate.
- **Stale PM data:** If last PM reading is > 2 hours old, treat as unavailable. Do not report "no haze" from stale data (absence of evidence != evidence of absence).
- **Out of scope:** Auto-calibration baseline (ADR-068). Fog improvements (ADR-069). Nighttime mode (ADR-071). GOES-16 Band 4 integration (future). Visibility estimation from extinction (future).

## References

- Research: `docs/reference/haze-physics/long-ackerman-2000-summary.md` — L&A cannot distinguish haze from clear; PM gate necessary
- Research: `docs/reference/haze-physics/mie-scattering-summary.md` — broadband GHI deficit valid haze proxy (Lindfors 2013, r=0.90)
- Research: `docs/reference/haze-physics/hanel-1976-summary.md` — f(RH) formula, gamma by composition (0.12-1.52)
- Research: `docs/reference/haze-physics/tang-1996-summary.md` — hygroscopic enhancement, gamma is composition not size
- Research: `docs/reference/haze-physics/ryan-stolzenbach-model.md` — el > 10° gate (20% model error below)
- Research: `docs/reference/haze-physics/cirrus-vs-aerosol-discrimination.md` — 45% agreement pyranometer-only (Duchon & O'Malley 1999)
- Research: `docs/reference/nws-text-system/observation-text-rules.md` — "Hazy." separate sentence convention
- Related ADRs: ADR-044 (archived, sky condition classification), ADR-066 (AQI provider restructuring), ADR-068, ADR-069, ADR-071
- Existing code: `sse/sky_condition.py` (CAELUS classifier), `sse/enrichment/weather_text.py` (current fog override, weather code derivation)
