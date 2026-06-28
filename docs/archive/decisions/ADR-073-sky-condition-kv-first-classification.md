---
status: Archived — consolidated into API-MANUAL.md
date: 2026-06-23
deciders: shane
supersedes: ADR-044
---

# ADR-073: Sky condition — Kv-first classification (supersedes ADR-044)

## Context

The dashboard `weatherText` field includes a sky condition component (e.g., "Partly Cloudy"). ADR-044 built this on CAELUS's Km-first decision tree, which was designed for solar energy forecasting (irradiance component separation), not meteorological sky condition reporting.

**The marine layer problem:** A uniform marine layer covering 100% of the sky at Km ≈ 0.55–0.65 falls through to the CAELUS SCATTER_CLOUDS catch-all and displays as "Mostly Cloudy" or "Partly Cloudy." The engine confuses cloud optical depth (how much light gets through) with sky coverage fraction (how much sky is covered). NWS defines sky conditions by coverage fraction, not transmittance.

**Root cause:** The CAELUS OVERCAST anchor requires Km < 0.3 — a threshold calibrated for thick nimbostratus, not the NWS definition of overcast (8/8 sky coverage, uniform). A uniform marine layer at Km 0.6 looks nothing like the CAELUS OVERCAST class. Km-first is wrong for weather reporting.

**The fix:** Six independent papers confirm the inverted-U relationship between cloud fraction and irradiance variability: variability peaks at ~50% cloud fraction and drops to near-zero at both 0% (clear) and 100% (overcast). This means Kv is the correct primary discriminator — low Kv means uniform sky (clear or overcast); elevated Kv means broken coverage. Km then distinguishes within each branch. This is ADR-044's classification architecture replaced wholesale.

**Why full supersession:** Partial supersession of ADR-044 (§1, §6, §7 only) would leave agents tracking which sections are live vs dead across two ADRs. Full replacement in ADR-073 is cleaner — one authoritative ADR for all conditions-text methodology.

**Prescriptive rules** (formulas, thresholds, code module paths) are in `docs/manuals/API-MANUAL.md` §8. This ADR records the scientific reasoning.

**Detailed citations** are in `docs/reference/sky-classification-science.md`.

---

## Options considered

| Option | Verdict |
|--------|---------|
| Partially supersede ADR-044 (§1/6/7 only) | Rejected — leaves a partially-superseded ADR where agents must track which sections are live vs. dead. Cross-ADR inconsistency is a recurring failure mode. |
| **Fully replace ADR-044 with ADR-073** | **Chosen** — single authoritative ADR, no cross-reference confusion. ADR-044 is retired to historical record. |
| Tune existing CAELUS thresholds without restructuring | Rejected — the tree structure is wrong (Km-first), not just the threshold values. Tuning thresholds cannot fix a marine layer that has Km 0.6 and falls into SCATTER_CLOUDS. The architecture must change. |

---

## Decisions

### 1. Sky classification: Kv-first decision tree (REPLACES ADR-044 §1, §6, §7)

**Decision:** Restructure the classification tree to use Kv as the primary discriminator and Km as the secondary discriminator within each branch. This replaces the CAELUS Km-first tree (CLOUDLESS / CLOUD_ENHANCEMENT / OVERCAST anchors + SCATTER_CLOUDS catch-all).

**The inverted-U relationship (6 papers confirm):** Irradiance variability peaks at ~50% cloud fraction and drops to near-zero at 0% (clear) and 100% (overcast). Physical cause: at 100% coverage, no cloud edges exist to create transitions. This means:
- Low Kv → either clear OR overcast (both produce smooth GHI curves)
- High Kv → intermediate broken coverage (cloud transits creating oscillations)
- Km then distinguishes within the low-Kv regime: high Km = clear, lower Km = overcast (thin or heavy)

Key papers: Duchon & O'Malley (1999), Mol et al. (2023), Xie & Sengupta (2021), Manninen et al. (2020), Stein et al. (2012), Bright et al. (2017).

**Why CAELUS Km-first was wrong for weather reporting:** CAELUS was designed for solar energy applications (GISPLIT irradiance component separation). Its OVERCAST anchor (Km < 0.3) targets nimbostratus. Its class labels are "only orientative" (authors' words). A uniform marine layer at Km 0.6 falls into the SCATTER_CLOUDS catch-all and misclassifies as partly cloudy. The NWS defines overcast by coverage (8/8, no gaps), not transmittance.

**The complete decision tree:**

*Step 0: Pre-checks (unchanged from ADR-044)*
```
if night/twilight (max(radiation, maxSolarRad) < 20 W/m²):
    clear ring buffer, return None

if solar_elevation < 5°:
    return last stable label

if ring buffer < 3 entries:
    return None (insufficient data)
```

*Step 1: Cloud enhancement (evaluated before Kv split)*
```
if Kcs > 1.06 AND Kv > 0.20 AND Kvf > 0.20 AND maxSolarRad > 100 W/m²:
    → "Partly Cloudy"
```
Cloud enhancement means GHI exceeds clear-sky — the sun is visible with nearby cloud edges scattering extra light. This is a broken-cloud scenario that does not fit the Kv-first flow cleanly (Kcs > 1.06 is a unique signal). See §6 for why it maps to "Partly Cloudy" rather than the prior "Clear."

*Step 2: Primary axis — Kv (uniform vs. variable sky)*
```
if Kv < KV_UNIFORM (0.05):
    → UNIFORM SKY → Step 3
else:
    → VARIABLE SKY → Step 4
```
KV_UNIFORM = 0.05: above the CAELUS CLOUDLESS_MAX_KV (0.03) to capture thin uniform layers with slight texture; below the point where obvious cloud transits register; accounts for consumer-grade pyranometer noise floors.

*Step 3: Uniform sky — Km distinguishes clear vs. overcast (no breaks in this branch)*
```
Step 3a: if Km > 0.85 AND Kcs > 0.80  → "Clear"
Step 3b: if Km > 0.35                  → "Overcast"
Step 3c: else (Km ≤ 0.35)             → "Heavy Overcast"
```
In the uniform branch, Kv has confirmed no cloud-edge transitions. Every non-clear outcome is overcast by definition — NWS OVC (8/8, no gaps). Km tells us cloud thickness within the overcast family, not a different coverage label. Two overcast tiers because thin overcast (marine stratus, Km ~0.5–0.8) vs. thick overcast (nimbostratus, Km ≤ 0.35) have meaningfully different visitor implications: thin = bright gray, no rain; heavy = dark, precipitation likely.

*Step 4: Variable sky — Km distinguishes coverage degree (breaks confirmed by Kv)*
```
Step 4a: if Km > 0.85  → "Mostly Clear"
Step 4b: if Km > 0.60  → "Partly Cloudy"
Step 4c: if Km > 0.40  → "Mostly Cloudy"
Step 4d: else           → "Cloudy"
```
In the variable branch, Kv has confirmed cloud-edge transitions exist. "Cloudy" in this branch (NWS: 87–100%, includes 7/8 BKN) differs from "Overcast" (8/8 OVC) by the existence of breaks — Kv confirms them even when rare.

**Threshold constants table:**

| Constant | Value | Role |
|---|---|---|
| `_KV_UNIFORM` | 0.05 | Primary split: uniform vs. variable sky |
| `_UNIFORM_CLEAR_MIN_KM` | 0.85 | Uniform branch: clear sky minimum Km |
| `_UNIFORM_CLEAR_MIN_KCS` | 0.80 | Uniform branch: clear sky Kcs sanity check |
| `_UNIFORM_HEAVY_MAX_KM` | 0.35 | Uniform branch: heavy overcast maximum Km |
| `_VARIABLE_CLEAR_MIN_KM` | 0.85 | Variable branch: mostly clear minimum Km |
| `_VARIABLE_PARTLY_MIN_KM` | 0.60 | Variable branch: partly cloudy minimum Km |
| `_VARIABLE_MOSTLY_MIN_KM` | 0.40 | Variable branch: mostly cloudy minimum Km |

Retained constants (unchanged): `_KC_MAX` (1.2), `_MIN_SOLAR_RAD` (20.0), `_NOISE_FLOOR` (0.0), `_SZA_GUARD_ELEVATION` (5.0), `_SZA80_MSR_PROXY` (100.0), `_CLOUDEN_MIN_KCS` (1.06), `_CLOUDEN_MIN_KV` (0.20), `_CLOUDEN_MIN_KVF` (0.20), `_WINDOW_SECONDS` (1800.0).

**7-label set:**

| Label | Coverage | Kv signal | Km range | Branch |
|---|---|---|---|---|
| Clear | 0/8 | Smooth | > 0.85 | Uniform |
| Overcast | 8/8 | Smooth | 0.35–0.85 | Uniform |
| Heavy Overcast | 8/8 | Smooth | ≤ 0.35 | Uniform |
| Mostly Clear | 1–3/8 | Elevated | > 0.85 | Variable |
| Partly Cloudy | 3–6/8 | Elevated | 0.60–0.85 | Variable |
| Mostly Cloudy | 5–7/8 | Elevated | 0.40–0.60 | Variable |
| Cloudy | 7–8/8 | Elevated | ≤ 0.40 | Variable |

**System lineage:** Modified CAELUS model using Duchon-O'Malley classification architecture, mapped to NWS sky condition vocabulary. A two-parameter pyranometer-based classifier in the Duchon & O'Malley (1999) tradition — variability-primary, clearness-secondary — using CAELUS-derived indices (Ruiz-Arias & Gueymard 2023) at 1-minute resolution.

### 2. Clear-sky detrending of variability indices (CARRIED FORWARD from ADR-044 §2)

**Decision:** Detrend Kv and Kvf by subtracting the clear-sky model's minute-to-minute change from the observed GHI change before computing the variability metric.

**Why:** CAELUS uses centered rolling windows in batch mode, partially suppressing the deterministic solar geometry signal. Our real-time trailing window accumulates the geometry ramp unidirectionally. Without detrending, a perfectly clear afternoon produces Kv above the CLOUDLESS threshold, causing false "Mostly Clear" classifications.

**Scientific foundation:** Stein et al. (2012, Sandia SAND2012-3464C) defined the Variability Index as the ratio of measured GHI path length to clear-sky path length — normalizing against the expected signal. Coimbra et al. (2013) established that dividing by clear-sky irradiance produces a near-stationary signal isolating cloud changes. Our delta-subtraction achieves the same effect.

### 3. Two variability windows (30-min and 10-min) (CARRIED FORWARD from ADR-044 §3)

**Decision:** Compute variability at two timescales — Kv over 30 minutes (coarse) and Kvf over 10 minutes (fine).

**Why:** 30 minutes captures mesoscale cloud patterns but smooths rapid transits. A single fast cumulus crossing in 2 minutes barely registers in a 30-minute integral. Kvf over 10 minutes catches these. The dual-window requirement in CAELUS (Table 3) ensures rapid transits are confirmed at both timescales before declaring cloud enhancement.

**Scientific foundation:** Ruiz-Arias & Gueymard (2023, Table 3). The 30/10 split reflects mesoscale cloud pattern transit time vs. individual cloud transit time.

### 4. GHI mirroring across sunrise/sunset (CARRIED FORWARD from ADR-044 §4)

**Decision:** Mirror post-sunrise GHI measurements backward across the sunrise boundary using cos(zenith) interpolation to stabilize the rolling statistics during the sunrise transition.

**Why:** At sunrise, the trailing 30-minute window has only a few minutes of real data. Under overcast, sparse samples inflate Km (diffuse radiation at low solar elevation is a high fraction of the small clear-sky reference), producing incorrect sunny/scattered labels. Observed live 2026-06-21: GHI 338.6, maxSolarRad 665.2, Km = 0.509 at elevation ~35° under 81% provider cloud cover — engine output "Partly Cloudy" when conditions were clearly overcast.

**Scientific foundation:** CAELUS implements mirroring in `sky_indices.py:mirror_ghi_with_pandas()`. The cos(zenith) axis is used because at the same cos(zenith), atmospheric path length is the same — cloud effects on GHI should be similar at symmetric elevations.

### 5. SZA < 85° classification guard (CARRIED FORWARD from ADR-044 §5)

**Decision:** When solar elevation is below 5° (SZA > 85°), the classifier returns None and the engine falls back to provider cloud cover.

**Why:** At very low solar elevations, pyranometer measurements are unreliable: (1) cosine response error — Davis VP2 ±10% at 70-85° vs. ±3% at normal incidence; (2) atmospheric path length — at SZA 85° the path is ~11× overhead; (3) clear-sky model uncertainty at extreme zenith. The 5° threshold matches CAELUS's own SZA filter; the 5–10° range is better served with GHI mirroring now active.

**Scientific foundation:** CAELUS uses SZA ≥ 85° (elevation < 5°) in its implementation. Skartveit & Olseth (1987) established that clearness index loses discriminatory power at high zenith angles. Engerer (2015) formalized 10° as standard minimum.

### 6. Cloud enhancement → "Partly Cloudy" (REPLACES ADR-044 §8)

**Decision:** Map the CLOUD_ENHANCEMENT class to "Partly Cloudy" instead of "Clear" (day: "Sunny").

**Why the change:** Cloud enhancement (Kcs > 1.06 + high Kv + high Kvf) physically requires nearby clouds scattering extra light toward the sensor. This is a broken-cloud scenario — not a clear-sky scenario. ADR-044 §8 mapped it to "Clear" because the sun is definitively visible. But "Partly Cloudy" is more accurate: cloud enhancement requires both sun visibility AND nearby cloud edges. WMO present weather code 2 (partial cloud) is more appropriate than code 0 (clear) for this physical situation.

**Scene mapping unchanged:** "Partly Cloudy" maps to the "clear" background asset bucket in `scene.py` `_SKY_LABEL_TO_BUCKET` — same visual result as the prior "Clear" mapping for cloud enhancement events. The change is in the label, not the background bucket.

**Why not "Mostly Clear":** Enhancement requires cloud edges close enough to the sensor to scatter extra light. The cloud fraction is not minimal — it's a broken-cloud sky. "Partly Cloudy" more accurately describes this.

### 7. Provider cloud cover fallback (CARRIED FORWARD from ADR-044 §9)

**Decision:** When solar classification is unavailable (night, twilight, SZA guard, no pyranometer), fall back to provider-reported cloud cover percentage mapped to NWS sky categories via `_cloud_pct_to_sky()`.

**Why NWS ASOS categories:** FAA Order 7900.5D §12.4 defines the standard mapping from cloud cover percentage to sky condition codes (CLR/FEW/SCT/BKN/OVC). Standard across all METAR-reporting stations worldwide.

**Why provider text takes priority over cloud percentage:** Providers sometimes report conditions cloud percentage alone cannot express: fog, freezing fog, haze, smoke, blowing snow. When the provider supplies descriptive text, it is more informative than a percentage.

### 8. Precipitation: local gauge primary, wet-bulb filter (CARRIED FORWARD from ADR-044 §10)

**Decision:** Use the local rain gauge as the primary precipitation source. When a provider reports frozen precipitation type (snow, freezing rain, sleet), accept it only if the Stull (2011) wet-bulb temperature is ≤ 35°F (1.7°C).

**Why local over provider:** Rain gauges measure actual precipitation at the station. Provider data is forecast/model output.

**Why wet-bulb filter:** Above 35°F wet-bulb, frozen precipitation is physically implausible regardless of forecast. Prevents "Snow" display during warm rain from a stale forecast.

**Scientific foundation:** Stull (2011) empirical wet-bulb formula requires only dry-bulb temperature and relative humidity.

### 9. Temperature-comfort: 2D matrix (CARRIED FORWARD from ADR-044 §11)

**Decision:** Use a two-dimensional matrix combining apparent temperature (wind chill / heat index) with dewpoint to produce a composite comfort descriptor.

**Why 2D:** Dewpoint alone cannot express thermal comfort — 55°F dewpoint feels different at 65°F vs. 95°F. AppTemp accounts for both wind chill and heat index (unified metric). NWS danger-level overrides apply when heat index or wind chill reaches nationally recognized thresholds.

### 10. Day/night display vocabulary (CARRIED FORWARD from ADR-044 §12)

**Decision:** Use NWS Directive 10-503 day/night vocabulary: "Sunny"/"Mostly Sunny" during the day, "Clear"/"Mostly Clear" at night. "Partly Cloudy" and denser labels are the same day and night.

**Why NWS vocabulary:** Consistency with NWS public forecast products. The 7-label set maps as follows:

| Classification | Day display | Night display |
|---|---|---|
| Clear | Sunny | Clear |
| Mostly Clear | Mostly Sunny | Mostly Clear |
| Partly Cloudy | Partly Cloudy | Partly Cloudy |
| Mostly Cloudy | Mostly Cloudy | Mostly Cloudy |
| Cloudy | Cloudy | Cloudy |
| Overcast | Overcast | Overcast |
| Heavy Overcast | Heavy Overcast | Heavy Overcast |

### 11. Temporal coherence filter (CARRIED FORWARD from ADR-044 §13)

**Decision:** A raw classification must persist for 15 consecutive minutes before becoming the stable displayed label. 3-minute grace on startup.

**Why 15 minutes:** Mesoscale cloud patterns persist for 15+ minutes. Individual cumulus clouds transit in 2–5 minutes. 15 minutes filters individual-cloud noise while tracking real sky-character transitions.

**Why not per-threshold hysteresis:** With a discrete label decision tree (not a continuous threshold), hysteresis doesn't map cleanly. The coherence filter serves the same stability function.

### 12. Haze/smoke detection (CARRIED FORWARD from ADR-044 §14, updated)

The detection heuristic described in ADR-044 §14 has been implemented via ADR-067. Haze detection is now a live module (`haze_condition.py`) using two-channel sensor fusion: Kcs deficit against an auto-calibrated clean-sky baseline (broadband aerosol optical depth estimation) and PM2.5/PM10 concentration exceeding EPA AQI breakpoints. Both channels must fire simultaneously. This is distinct from the sky condition classifier — haze is an obstruction to vision, not a cloud coverage label. See ADR-067 and API-MANUAL.md §8 Haze detection for prescriptive rules.

---

## Consequences

- 7-label set: Clear, Mostly Clear, Partly Cloudy, Mostly Cloudy, Cloudy, Overcast, Heavy Overcast. Removes the "Scattered Clouds" composite labels and the SCATTER_CLOUDS/OVERCAST sub-split structure from ADR-044.
- ADR-044 fully retired. Consult ADR-073 for all conditions-text methodology decisions.
- No new Python dependencies. `sky_condition.py` uses only stdlib; Skyfield already loaded for the almanac service.
- Threshold tuning deferred to production observation — thresholds are initial estimates from physical reasoning, not per-station calibrations.
- Operator-adjustable thresholds (KV_UNIFORM, Km boundaries via admin UI) deferred pending post-deployment observation of which constants need it.

---

## Acceptance criteria

- [ ] 7 labels defined with physical meaning and branch assignment
- [ ] Threshold constants table matches the brief (7 new constants)
- [ ] Every ADR-044 section accounted for: §1/6/7/8 replaced; §2/3/4/5/9/10/11/12/13/14 carried forward
- [ ] System lineage section present (Duchon-O'Malley architecture, CAELUS indices, NWS vocabulary)
- [ ] Cloud enhancement → "Partly Cloudy" documented with reasoning (§6 above)
- [ ] Status = Proposed

---

## Implementation guidance

**Single file change:** Only `sky_condition.py` (`_classify_caelus()` function body and threshold constants) changes. All other modules, signatures, buffers, and infrastructure are unchanged per the brief.

**7 new constants to add:**
```python
_KV_UNIFORM = 0.05
_UNIFORM_CLEAR_MIN_KM = 0.85
_UNIFORM_CLEAR_MIN_KCS = 0.80
_UNIFORM_HEAVY_MAX_KM = 0.35
_VARIABLE_CLEAR_MIN_KM = 0.85
_VARIABLE_PARTLY_MIN_KM = 0.60
_VARIABLE_MOSTLY_MIN_KM = 0.40
```

**Remove:** All CAELUS Table 3 constants that gated the old tree: `_CLOUDLESS_MIN_KM`, `_CLOUDLESS_MIN_KCS`, `_CLOUDLESS_MAX_KCS`, `_CLOUDLESS_MAX_KV`, `_THINCLOUDS_MIN_KM`, `_THINCLOUDS_MIN_KV`, `_THINCLOUDS_MAX_KV`, `_THICKCLOUDS_MAX_KM`, `_THICKCLOUDS_MIN_KV`, `_THICKCLOUDS_MAX_KV`, `_OVERCAST_MAX_KM`, `_OVERCAST_MAX_KV`.

**Unchanged:** ring buffer, sub-minute accumulator, index computation (Kcs/Km/Kv/Kvf), Kv detrending, GHI mirroring, night/twilight guard, SZA guard, temporal coherence filter, backfill from archive, `update()`/`classify()`/`is_daytime()`/`reset()` signatures.

**Downstream changes needed** (in addition to `sky_condition.py`):
- `scene.py` `_SKY_LABEL_TO_BUCKET`: add "Overcast" → "cloudy" bucket, "Heavy Overcast" → "storm" bucket (or cloudy — confirm with user)
- `conditions_text.py` `_DAY_LABELS`: add day/night text for "Overcast" and "Heavy Overcast" (same for both)
- `DESIGN-MANUAL.md` sky-to-background table: add "Heavy Overcast" to the cloudy row

---

## References

Full citations in `docs/reference/sky-classification-science.md`. Key sources:

- Duchon, C.E. & O'Malley, M.S. (1999). "Estimating cloud type from pyranometer observations." *J. Appl. Meteor.*, 38(1), 132–141.
- Ruiz-Arias, J.A. & Gueymard, C.A. (2023). "CAELUS." *Solar Energy* 263, 111895.
- Stein, J.S., Hansen, C.W., & Reno, M.J. (2012). Variability Index. Sandia SAND2012-3464C.
- Xie, Y. & Sengupta, M. (2021). *Solar Energy*, 226, 442–449.
- Mol, W.B., et al. (2023). *J. Geophys. Res.: Atmospheres*, 128, e2022JD037894.
- Mol, W.B., et al. (2025). *Atmos. Chem. Phys.*, 25, 4419–4441.
- Kasten, F. & Czeplak, G. (1980). *Solar Energy* 24(2), 177–189.
- Stull, R. (2011). *J. Appl. Meteorol. Climatol.* 50(11).
- Tapakis, R. & Charalambides, A.G. (2014). *Renewable Energy* 62.
- Manninen, A.J., et al. (2020). *Atmos. Meas. Tech.*, 13, 5595–5619.
- Skartveit, A. & Olseth, J.A. (1987). *Solar Energy* 38(4).
- Engerer, N.A. (2015). *Solar Energy* 116.
- NWS Directive 10-503 — Public forecast display vocabulary.
- FAA Order 7900.5D §12.4 — ASOS sky condition categories.
- Research basis: `docs/briefs/SKY-CLASSIFICATION-KV-FIRST-REDESIGN.md`, `docs/research/sky-classification/` (01–04).
- Related ADRs: ADR-044 (superseded), ADR-067 (haze detection), ADR-068 (auto-calibration baseline).
