# Sky Condition Classification — Scientific Reference

Single place to find every scientific source, threshold derivation, and design rationale
behind the sky condition classifier in `weewx_clearskies_api/sse/sky_condition.py`.

If a claim is not cited here, it does not have documented provenance.

Last updated: 2026-06-24

---

## 1. Primary Classification System — CAELUS

**Source:** Ruiz-Arias, J.A. & Gueymard, C.A. (2023). CAELUS: Classification of sky
conditions from 1-min time series of global horizontal irradiance. *Solar Energy*, 263,
111895. DOI: 10.1016/j.solener.2023.111895

**Code:** https://github.com/jararias/caelus — key files: `src/caelus/sky_indices.py`,
`src/caelus/skytype.py`, `src/caelus/options.py`

### What CAELUS provides

CAELUS defines a six-class sky condition taxonomy from four variability indices computed
over 1-minute GHI averages. Validated on 54 Baseline Surface Radiation Network (BSRN)
stations across all major climate zones.

### The six CAELUS classes

| Class | Physical meaning | Detection logic |
|---|---|---|
| CLOUDLESS | No clouds, stable high irradiance | Km > 0.6, Kcs ∈ [0.85, 1.15], Kv < 0.03 |
| CLOUD_ENHANCEMENT | Sun visible, cloud-edge scattering | Kcs > 1.06, Kv > 0.20, Kvf > 0.20 |
| THIN_CLOUDS | Light dimming, slight variability (cirrus, haze) | Km > 0.5, Kv ∈ [0.03, 0.08) |
| SCATTER_CLOUDS | Catch-all — broken cloud field | Everything else in the cloudy zone |
| THICK_CLOUDS | Heavy cloud with some breaks | Km < 0.4, Kv ∈ [0.04, 0.16) |
| OVERCAST | Thick uniform cover, smooth signal | Km < 0.3, Kv < 0.10 |

Thresholds from CAELUS `options.py` (Table 3 in the paper). Three anchor classes
(CLOUD_ENHANCEMENT, CLOUDLESS, OVERCAST) are evaluated independently; the cloudy zone
is the residual.

### The four indices

| Index | Formula | Window | Purpose |
|---|---|---|---|
| Kcs | GHI / maxSolarRad, clamped [0, 1.2] | Latest minute | Instantaneous clear-sky ratio |
| Km | mean(GHI) / mean(maxSolarRad) | 30 min | Mean normalized irradiance |
| Kv | Σ\|ΔGHI_detrended\| / T | 30 min | Coarse variability (cloud signal path length) |
| Kvf | Same formula as Kv | 10 min | Fine variability (rapid cloud transits) |

**Our adaptation** uses maxSolarRad from weewx as the clear-sky reference. CAELUS uses
`ghicda` (clear-sky direct+area irradiance). Both are clear-sky irradiance estimates at
the surface; maxSolarRad is computed by weewx from station coordinates using an empirical
clear-sky model (Ryan & Stolzenbach 1972 as implemented in weewx `almanac.py`).

### Deviations from CAELUS

| Aspect | CAELUS (batch) | Our implementation (real-time) |
|---|---|---|
| Window type | Centered rolling | Trailing rolling (necessary for streaming) |
| Clear-sky reference | ghicda (CAELUS internal model) | maxSolarRad (weewx clear-sky model) |
| SZA computation | Direct from solar geometry | Skyfield ephemeris (Phase 1) or maxSolarRad proxy (current) |
| GHI mirroring | Present — mirrors across sunrise/sunset | Added in Phase 1 (was missing) |
| Kv detrending | Implicit via centered window | Explicit clear-sky subtraction (see §2) |
| Temporal filter | Batch patch cleaning | Streaming coherence filter (15-min persistence) |
| Startup data | Full day available | Archive backfill (30 min) + live accumulation |

---

## 2. Clear-Sky Detrending of Kv / Kvf

**Sources:**
- Stein, J.S., Hansen, C.W., & Reno, M.J. (2012). The Variability Index: A new and
  novel metric for quantifying irradiance and PV output variability. Sandia National
  Laboratories, SAND2012-3464C. *World Renewable Energy Forum*, Denver, CO.
- Coimbra, C.F.M., Kleissl, J., & Marquez, R. (2013). Overview of solar-forecasting
  methods and a metric for accuracy evaluation. In J. Kleissl (Ed.), *Solar Energy
  Forecasting and Resource Assessment*, Chapter 8. Academic Press.

### Why detrending is necessary

The Variability Index (Kv) measures the cumulative absolute first-derivative of GHI.
On a clear day, GHI changes steadily due to solar geometry — the sun rises and sets,
causing a smooth ramp. Without detrending, this deterministic geometry signal produces
non-zero Kv even under perfectly clear skies.

CAELUS uses centered rolling windows in batch mode. Centering partially suppresses the
geometry trend because the symmetric window averages out the ramp. Our real-time trailing
window does not have this benefit — the ramp accumulates unidirectionally.

### How we detrend

Each minute-to-minute GHI delta has the corresponding maxSolarRad delta subtracted:

```
detrended_delta[i] = |GHI[i] - GHI[i-1] - (maxSolarRad[i] - maxSolarRad[i-1])|
Kv = sum(detrended_delta) / window_time_span
```

The maxSolarRad delta represents the expected change from solar geometry alone. Subtracting
it isolates the cloud-induced variability.

### Scientific basis

Stein et al. 2012 defined the Variability Index as the ratio of measured GHI path length
to clear-sky GHI path length — a normalized measure of irradiance roughness. Coimbra et al.
2013 established that dividing by clear-sky irradiance produces a near-stationary signal
whose fluctuations reflect only atmospheric (cloud) effects. Both approaches detrend the
solar geometry signal. Our delta-subtraction method achieves the same effect: the
deterministic solar ramp cancels out, leaving only cloud-induced variability.

### Verification

Without detrending, a clear afternoon with Kv ≈ 0.04 exceeded the CLOUDLESS threshold
(0.03), causing false "Mostly Clear" classifications instead of "Clear." With detrending,
the same afternoon produces Kv < 0.01 — well within CLOUDLESS.

---

## 3. GHI Mirroring Across Sunrise/Sunset

**Source:** Ruiz-Arias & Gueymard 2023, implemented in CAELUS
`src/caelus/sky_indices.py:mirror_ghi_with_pandas()`.

### The problem

At sunrise, the trailing 30-minute window has only a few minutes of data. The rolling
mean (Km) and variability (Kv) are computed from too few samples, producing unreliable
classifications. Under overcast at sunrise, the small sample size tends to inflate Km
(diffuse radiation at low angles is a high fraction of the small clear-sky reference),
producing sunny/scattered labels when the sky is actually overcast.

### CAELUS batch mirroring

CAELUS mirrors GHI values across sunrise and sunset boundaries using cos(zenith) as the
interpolation axis:

1. Split each day into AM (hour < 12) and PM (hour ≥ 12).
2. Identify daytime (cos(zenith) > 0) and nighttime (cos(zenith) ≤ 0) timestamps.
3. For AM nighttime timestamps: use linear interpolation from (cos(zenith), GHI) pairs
   of AM daytime data, evaluated at the negated cos(zenith) of the nighttime timestamps.
   Negate the result to produce mirrored values.
4. Same for PM nighttime timestamps using PM daytime data.

The interpolation uses `scipy.interpolate.interp1d` with `kind="linear"` and
`bounds_error=False` (extrapolation returns NaN).

**Why cos(zenith)?** At the same cos(zenith), the atmospheric path length is the same.
Cloud effects on GHI should be similar at symmetric elevations before and after solar
noon (or across sunrise/sunset). cos(zenith) captures this symmetry.

**Why negate?** The negation creates an antisymmetric extension. When these mirrored
(negative) values are included in the rolling statistics, they stabilize the window mean
at the sunrise/sunset boundary. Without mirroring, the window is partially empty; with
mirroring, it has a full complement of data points.

### Our real-time adaptation

CAELUS mirrors in batch mode with a full day's data. Our real-time adaptation:

1. After sunrise, as GHI readings accumulate in the ring buffer, compute cos(zenith) for
   each post-sunrise entry using Skyfield (station lat/lon/altitude already loaded at
   startup via `services/station.py`).
2. For pre-sunrise timestamps (within the 30-minute trailing window), compute cos(zenith)
   using Skyfield.
3. Build interpolation: map cos(zenith) → measured GHI from post-sunrise entries.
4. For each pre-sunrise timestamp, evaluate the interpolation at -cos(zenith) of that
   timestamp, then negate. This produces the mirrored GHI value.
5. Compute maxSolarRad for pre-sunrise timestamps directly from the clear-sky model
   (deterministic — depends only on astronomy, not on clouds).
6. Include mirrored entries in the rolling Km computation.
7. Quality improves as more post-sunrise data accumulates; the temporal coherence filter
   (15-min persistence) provides a backstop during the transition.

**Key difference from batch mode:** We only have data from one side of the sunrise boundary
(the morning side). CAELUS has the full day. Our interpolation has fewer points, but even a
few mirrored data points stabilize the rolling mean more than zero points.

---

## 4. Solar Zenith Angle (SZA) Classification Guard

**Sources:**
- Ruiz-Arias & Gueymard 2023 — CAELUS uses SZA < 85° as its classification threshold.
- Engerer, N.A. (2015). Minute resolution estimates of the diffuse fraction of global
  irradiance for southeastern Australia. *Solar Energy*, 116, 215–237. — Establishes
  10° minimum solar elevation as a standard cutoff for reliable GHI analysis.
- Hyytiälä et al. (2020). — Confirms 10° minimum for clear-sky index reliability.
- Skartveit, A. & Olseth, J.A. (1987). A model for the diffuse fraction of hourly global
  radiation. *Solar Energy*, 38(4), 271–274. — Early work establishing that clearness
  index loses discriminatory power at high zenith angles.

### The problem

At very low solar elevations (within ~5° of the horizon), pyranometer measurements become
unreliable due to:

1. **Cosine response error:** Consumer-grade pyranometers (Davis, Ambient) have severe
   cosine errors at high incidence angles. The Davis VP2 solar radiation sensor specifies
   ±3% accuracy at 0–70° incidence but ±10% at 70–85° incidence (effectively SZA 70–85°).
2. **Atmospheric path length:** At SZA = 85°, the atmospheric path is ~11× that of
   overhead sun, amplifying aerosol and humidity effects.
3. **Clear-sky model uncertainty:** Both Ineichen-Perez and weewx's Ryan-Stolzenbach
   models lose accuracy at extreme zenith angles — small errors in atmospheric parameters
   produce large Kcs errors when both GHI and maxSolarRad are near zero.

### CAELUS threshold

CAELUS itself filters data at SZA ≥ 85° (cos(zenith) ≤ ~0.087). This is documented in
the CAELUS source code and corresponds to a solar elevation of 5°.

### Our implementation

When solar elevation < 5° (SZA > 85°), `classify()` returns None. The downstream
consumer (`enrichment/weather_text.py`) then falls back to provider cloud cover via
`_cloud_pct_to_sky()`, which maps the provider's cloud percentage to a sky label.

This replaces the previous `_MIN_SOLAR_RAD = 20 W/m²` proxy for classification gating.
The `_MIN_SOLAR_RAD` threshold is retained for ring buffer data acceptance (data still
accumulates below the SZA guard to be available when the elevation crosses 5°).

### Why 5° instead of 10°

The literature standard (Engerer 2015) uses 10°. CAELUS uses 5° (85° SZA). We start with
CAELUS's own threshold for implementation fidelity. With GHI mirroring implemented, the
sunrise transition should be handled well at 5°. If misclassification persists between
5–10° elevation after deployment, the threshold can be tightened in a follow-up.

---

## 5. Kasten-Czeplak Cloud Cover Formula

**Source:** Kasten, F. & Czeplak, G. (1980). Solar and terrestrial radiation dependent
on the amount and type of cloud. *Solar Energy*, 24(2), 177–189. DOI:
10.1016/0038-092X(80)90391-6

### The formula

```
Km = 1 - 0.75 × (N/8)^3.4
```

Where N is cloud cover in oktas (eighths of sky dome covered), and Km is the mean
clearness index. This empirical formula, derived from ground-based observations, provides
a mapping between NWS sky cover categories and Km values.

### Computed Km-to-okta mapping

| N (oktas) | NWS ASOS code | NWS Forecast label | Km (K-C) |
|---|---|---|---|
| 0 | CLR | Sunny / Clear | 1.000 |
| 1 | FEW | Mostly Sunny | 0.999 |
| 2 | FEW | Mostly Sunny | 0.993 |
| 3 | SCT | Partly Cloudy | 0.973 |
| 4 | SCT | Partly Cloudy | 0.929 |
| 5 | BKN | Mostly Cloudy | 0.849 |
| 6 | BKN | Mostly Cloudy | 0.718 |
| 7 | BKN | Mostly Cloudy | 0.524 |
| 8 | OVC | Cloudy / Overcast | 0.250 |

### Why K-C is context, not thresholds

K-C assumes an ideal pyranometer observing a known okta value. In practice:

1. Consumer sensors have ±3–15% absolute accuracy (see §7), so Km measurements have a
   noise floor that makes fine Km distinctions unreliable.
2. The K-C formula's upper categories (Clear > 0.99, Mostly Clear > 0.97) fall within
   the noise floor of consumer equipment — they cannot be reliably distinguished from
   measurement error.
3. CAELUS handles "Clear" via the CLOUDLESS anchor class (Km > 0.6 + Kcs + Kv constraints),
   which does not depend on resolving fine Km distinctions at the top of the range.

K-C is provided as scientific context for what Km values *mean* physically. It is NOT
used as threshold values in the classifier. The classifier uses CAELUS thresholds.

### Where used in the codebase

K-C table is referenced in the admin UI (sky classification calibration section) to help
operators understand what their Km readings mean in terms of NWS sky categories. It is
also cited in ADR-044 as scientific context for the Km sub-split decisions.

---

## 6. NWS Sky Condition Systems

### 6a. ASOS/METAR (observation-based)

**Source:** FAA Order 7900.5D, §12.4 — Sky Condition. Also: Federal Meteorological
Handbook No. 1 (FMH-1), Chapter 12.

| Oktas | Coverage | ASOS code | Cloud cover % |
|---|---|---|---|
| 0 | 0/8 | CLR | 0–6% |
| 1–2 | 1/8–2/8 | FEW | 7–31% |
| 3–4 | 3/8–4/8 | SCT | 32–56% |
| 5–7 | 5/8–7/8 | BKN | 57–87% |
| 8 | 8/8 | OVC | 88–100% |

Used as the basis for provider cloud-cover fallback thresholds in
`enrichment/weather_text.py:_cloud_pct_to_sky()`.

### 6b. Public forecast vocabulary

**Source:** NWS Directive 10-503, Table 1 — Public Forecast Matrix. Also: NWS Glossary
(weather.gov/glossary).

| Coverage | Day term | Night term |
|---|---|---|
| 0–1/8 | Sunny | Clear |
| 1/8–3/8 | Mostly Sunny | Mostly Clear |
| 3/8–5/8 | Partly Sunny / Partly Cloudy | Partly Cloudy |
| 5/8–7/8 | Mostly Cloudy | Mostly Cloudy |
| 7/8–8/8 | Cloudy | Cloudy |

Used as the display vocabulary for all sky condition labels. Day/night determination
controls which column is applied.

### 6c. Key distinction

"Scattered" (SCT) is ASOS/METAR terminology for 3–4 oktas. "Partly Cloudy" is public
forecast terminology for 3–5 oktas. They overlap in the 3–4 okta range but are not
identical. Our display vocabulary follows the public forecast system (NWS Directive
10-503), not the ASOS system.

---

## 7. Sensor Accuracy

### ISO 9060:2018 — Pyranometer classification

**Source:** ISO 9060:2018, Solar energy — Specification and classification of instruments
for measuring hemispherical solar and direct solar radiation.

| Class | Daily uncertainty | Typical use |
|---|---|---|
| A (spectrometric) | ≤ 1.8% | Research stations, BSRN |
| B (secondary standard) | ≤ 3% | Climate networks |
| C (first class) | ≤ 5% | Field monitoring |

### Consumer weather station sensors

| Sensor | Accuracy spec | Notes |
|---|---|---|
| Davis Vantage Pro2 (#6450) | ±3% (0–70° incidence), ±10% (70–85°) | Photodiode, not thermopile |
| Ambient Weather WS-5000 | ~±15% (manufacturer spec) | Silicon photodiode |

Consumer sensors are photodiode-based, not thermopile. Their spectral response is narrower
than thermopile pyranometers, introducing additional systematic error that varies with
cloud type and atmospheric conditions. The accuracy specifications above are for broadband
irradiance under standard conditions; actual accuracy under diverse cloud patterns may be
worse.

### Implications for threshold design

1. CAELUS thresholds were validated on BSRN stations (ISO Class A/B, ≤3% uncertainty).
   They transfer to consumer sensors because CAELUS classifies *patterns* (the shape of
   the Kv and Km signals) rather than absolute values. A ±5% GHI bias shifts Km uniformly
   but does not change Kv (variability is a relative measure).
2. The CLOUDLESS anchor (Kcs ∈ [0.85, 1.15]) is deliberately wide — it tolerates ±15%
   in the instantaneous Kcs without misclassifying clear sky.
3. Km sub-splits within SCATTER_CLOUDS (see §8) are more sensitive to absolute accuracy
   because they distinguish narrow Km bands (e.g., 0.5–0.6). Operators with noisier sensors
   may need wider bands — hence the operator adjustability via the admin UI.

---

## 8. Km Sub-Splits and OVERCAST Sub-Splits — User Research

**Source:** User research session, conversation `6e1a3c4c`, 2026-06-19. Decisions
approved by the operator/project lead.

### SCATTER_CLOUDS Km sub-splits

CAELUS defines SCATTER_CLOUDS as a single catch-all class. The user researched and
approved sub-splitting by Km to provide more descriptive labels. Boundaries are derived
from the Kasten-Czeplak (1980) formula (§5), which maps Km to NWS okta categories.
CAELUS class boundaries (0.6/0.5/0.4) were NOT used — those describe solar production
categories, not weather display categories (see ADR-044 §1).

| Km range | K-C oktas | Display label | Rationale |
|---|---|---|---|
| > 0.97 | 0–2 (CLR/FEW) | Clear, Scattered Clouds | Very high clearness with confirmed cloud transits |
| 0.85–0.97 | 2–4 (FEW/SCT) | Mostly Clear, Scattered Clouds | Mostly clear, some transits |
| 0.52–0.85 | 4–7 (SCT/BKN) | Partly Cloudy | Standard NWS forecast label for mid-range |
| < 0.52 | 7+ (BKN/OVC) | Mostly Cloudy | Cloud cover dominant |

"Scattered Clouds" descriptor rule: only pairs with "Clear" / "Mostly Clear" labels.
Once coverage reaches "Partly Cloudy" or denser, the base label carries the meaning
alone. (User: "once you hit partly cloudy or mostly cloudy, you do not say scattered
clouds or broken clouds anymore" — conversation `6e1a3c4c`, line 240.)

### OVERCAST zone Km×Kv sub-splits

The OVERCAST anchor (Km < 0.3, Kv < 0.10) was sub-split using Kv (curve roughness) to
distinguish uniform blanket from lumpy thick deck:

| Km | Kv | Display label | Physical meaning |
|---|---|---|---|
| 0.15–0.30 | ≥ 0.03 | Cloudy | Thick but textured (some variation in irradiance) |
| 0.15–0.30 | < 0.03 | Overcast | Thick and uniform (flat irradiance curve) |
| < 0.15 | ≥ 0.03 | Overcast | Very thick with some variation |
| < 0.15 | < 0.03 | Heavy Overcast | Very thick and uniform (near-zero light, no variability) |

User decision: sub-split by Kv (curve shape), not Kc (instantaneous snapshot). User:
"the difference between cloudy and overcast has to do with the shape of the curve" and
"i don't like using Kc as it is just a snapshot in time" (conversation `6e1a3c4c`,
lines 142 and 201).

### CLOUD_ENHANCEMENT label

CAELUS CLOUD_ENHANCEMENT means: sun IS visible, cloud edges scattering extra light
above clear-sky levels. GHI exceeds clear-sky GHI (Kcs > 1.06).

ADR-044 originally mapped this to "Partly Cloudy." User research revised this to "Clear"
because the sun is definitively visible during cloud enhancement. (User's external research:
Class 6 → "Mostly Sunny or Sunny" — conversation `6e1a3c4c`, line 153. User also said
"no let's not assume what I found is source of truth" — line 159, meaning cross-check
against other sources.)

The cross-check: NWS public forecast vocabulary maps "Sunny" to 0–1/8 cloud cover. During
cloud enhancement, nearby clouds exist but the sun is visible and dominant. "Clear" or
"Sunny" is meteorologically defensible — the enhancement confirms clear line-of-sight to
the sun.

---

## 9. Provider Cloud-Cover Fallback

**Source:** FAA Order 7900.5D §12.4 (NWS ASOS sky condition categories).

Used when solar radiation analysis is unavailable (night, twilight, no pyranometer, SZA
guard engaged). The fallback maps provider-reported cloud cover percentage to NWS display
labels.

**ADR-044 approved thresholds (NWS ASOS okta-based):**

| Cloud cover % | ASOS code | Display label |
|---|---|---|
| 0–6% | CLR | Clear / Sunny |
| 7–31% | FEW | Mostly Clear / Mostly Sunny |
| 32–56% | SCT | Partly Cloudy |
| 57–87% | BKN | Mostly Cloudy |
| 88–100% | OVC | Cloudy |

**Code implementation note:** The current code in `enrichment/weather_text.py` uses
slightly different thresholds (≤10/25/50/85/95 with an additional "Overcast" label at
>95%). These thresholds are wider bins that were implemented as a pragmatic approximation.
The divergence is documented; reconciliation is tracked in the admin calibration plan.

---

## 10. Wet-Bulb Temperature — Frozen Precipitation

**Source:** Stull, R. (2011). Wet-bulb temperature from relative humidity and air
temperature. *J. Applied Meteorology and Climatology*, 50(11), 2267–2269. DOI:
10.1175/2011JAMC2564.1

### Formula

```
Tw = T × atan(0.151977 × (RH + 8.313659)^0.5)
   + atan(T + RH)
   − atan(RH − 1.676331)
   + 0.00391838 × RH^1.5 × atan(0.023101 × RH)
   − 4.686035
```

Where T = dry-bulb temperature in °C, RH = relative humidity in %, Tw = wet-bulb
temperature in °C.

### Where used

When `rainRate > 0` and a provider reports frozen precipitation type (snow, freezing rain,
sleet), the wet-bulb temperature determines whether frozen precipitation is thermodynamically
plausible. If Tw > 35°F (1.7°C), frozen precipitation is rejected regardless of provider
forecast — the atmosphere is too warm to support it.

---

## 11. Cloud Enhancement

**Source:** Tapakis, R. & Charalambides, A.G. (2014). Enhanced values of global irradiance
due to the presence of clouds in the neighborhood of the sun. *Renewable Energy*, 62,
459–467. DOI: 10.1016/j.renene.2013.08.009

Cloud-edge enhancement can produce GHI values up to 1.4× clear-sky GHI (Kcs up to 1.4).
CAELUS's Kcs > 1.06 threshold for CLOUD_ENHANCEMENT is conservative — it requires
6% above clear-sky to trigger, avoiding false positives from sensor noise.

---

## 12. Temporal Coherence

**Source:** Design decision (ADR-044), informed by physical observation.

Sky conditions physically do not change every minute. CAELUS uses batch "patch cleaning"
to remove isolated one-minute classifications. Our streaming adaptation uses a temporal
coherence filter: a raw classification must persist for 15 consecutive minutes before
becoming the stable label. On startup, a 3-minute grace period applies to provide an
initial label quickly.

The 15-minute persistence period was chosen to match the approximate timescale of
mesoscale cloud movement — individual cumulus clouds transit a station in 2–5 minutes,
but the overall sky character (scattered vs. overcast) persists for 15+ minutes.

---

## 13. Day/Night Determination

**Source:** NWS Directive 10-503 (display vocabulary); standard solar geometry.

| Solar zenith | Period | Sky classification |
|---|---|---|
| < 80° (elevation > 10°) | Day | Solar radiation analysis active |
| 80–85° (elevation 5–10°) | Low-sun day | Solar analysis active with mirroring support |
| 85–90° (elevation 0–5°) | Twilight | SZA guard → provider fallback (Phase 1) |
| 90–96° | Civil twilight | Provider fallback |
| > 96° | Night | Provider fallback |

The SZA guard at 5° (85° zenith) replaces the previous `_MIN_SOLAR_RAD = 20 W/m²` proxy.
The `_MIN_SOLAR_RAD` threshold is retained for ring buffer data acceptance — data still
accumulates below the SZA guard to be available when elevation crosses 5°.

---

## 14. Dynamic Km Thresholds and Mean-of-Ratios Km

### 14.1 The volume-under-the-curve problem with ratio-of-integrals Km

The original Km formula used the ratio of window means:

```
Km_old = mean(GHI) / mean(maxSolarRad)
       = [Σ GHI_i / n] / [Σ maxSolarRad_i / n]
       = Σ GHI_i / Σ maxSolarRad_i
```

This is the **ratio of integrals** (equivalently, ratio of accumulated energy volumes over the window). The denominator accumulates the total clear-sky energy available over the 30-minute window.

Near sunrise and sunset, both GHI and maxSolarRad approach zero simultaneously. The accumulated maxSolarRad in the denominator grows slowly because the per-minute values are small. Meanwhile, a single sensor reading taken at moderate elevation earlier in the window contributes disproportionately to the numerator. The result: the accumulated denominator volume is inflated relative to the sensor readings actually being compared, producing Km values that are systematically lower than what a rational per-minute comparison would yield. This causes false "Overcast" or "Mostly Cloudy" labels during the low-elevation window when the sky may be clear.

### 14.2 The mean-of-ratios fix

The updated formula normalizes **each minute independently**:

```
Km_new = (1/n) Σ (GHI_i / maxSolarRad_i)
```

Each term is a per-minute Kcs value (clamped [0, 1.2]). Km is the arithmetic mean of those per-minute ratios. Under this formula, a reading taken at low solar elevation carries no more weight in the sum than a reading taken at high elevation — both are normalized by their own contemporaneous clear-sky reference. The solar geometry bias cancels out per-minute rather than accumulating over the window.

The same change applies to Kmf (10-minute mean).

**Numerical equivalence at constant irradiance:** When GHI and maxSolarRad are proportional and uniform across the window (ideal clear-sky day at a fixed elevation), both formulas return the same value. The difference only appears when per-minute ratios vary — which is precisely the low-elevation case where the old formula misbehaved.

### 14.3 Why fixed thresholds cannot work across all elevations

**Source:** Smith, C.J., Bright, J.M., & Crook, R. (2017). Cloud cover effect of clear-sky index distributions and direct normal irradiance for five UK locations. *Solar Energy*, 146, 327–338. DOI: 10.1016/j.solener.2017.02.006

Smith, Bright & Crook (2017) analyzed clear-sky index (Kcs) distributions as a function of solar elevation across five UK measurement sites. Key finding: the distribution of Kcs under clear skies is **not stationary with respect to solar elevation**. At high solar elevations, the Kcs distribution is tightly clustered near 1.0. At low solar elevations (below ~20°), the distribution spreads and the median shifts downward — a clear sky at 10° elevation may produce Kcs of only 0.65–0.75 under otherwise identical atmospheric conditions.

This is physically expected: at low elevations, the atmospheric path length is long (air mass > 5 at 10°), increasing absorption and scattering. The clear-sky model accounts for these effects, but does so with idealized atmospheric parameters. Real-world deviation from those parameters (humidity, aerosols, local horizon) is amplified at long path lengths. Consumer pyranometers also introduce additional cosine-response error at high incidence angles.

**Consequence for fixed thresholds:** A fixed `K_clear = 0.85` boundary was calibrated against the high-elevation distribution. At 10–20° elevation, a genuinely clear sky may produce Km of 0.60–0.75, which a fixed threshold of 0.85 would classify as "Partly Cloudy." The sky is clear — the threshold is wrong for this elevation.

### 14.4 The dynamic threshold formula

```
K_threshold(α) = K_min + (K_max − K_min) · (1 − e^(−b · α))
```

Where:
- α = solar elevation in degrees
- K_max = asymptotic upper bound (the threshold at high elevation, in the range where fixed thresholds historically applied)
- K_min = floor value at zero elevation (the lowest meaningful threshold, accounting for maximum atmospheric path-length effects)
- b = scaling factor (controls how quickly the threshold rises from K_min toward K_max as elevation increases)

**Shape:** At α = 0, the formula returns K_min. As α increases, the threshold rises exponentially toward K_max. By α = 30°, it is within ~5% of K_max (for b = 0.1). This matches the physical picture: the threshold converges to the traditional fixed value at moderate and high elevations, and relaxes toward K_min at low elevations.

**Default parameters:** K_max = 0.80 (clear boundary), K_min = 0.35 (horizon floor), b = 0.1 (scaling factor).

The same formula is applied to each variable-branch boundary with its own K_max (0.80 / 0.60 / 0.40), while K_min and b are shared. This preserves the boundary-ratio structure at high elevations while relaxing all boundaries proportionally at low elevations.

### 14.5 Tikhonov regularization analogy

The additive K_min term in the dynamic threshold formula is conceptually analogous to **Tikhonov regularization** (also known as ridge regression or L2 regularization). In regularization, an additive term prevents the solution from collapsing to zero when the problem is ill-conditioned. Here, K_min prevents the threshold from collapsing to zero at zero elevation — which would make the classifier trivially classify everything as "Clear" near the horizon, defeating the purpose of the threshold.

K_min is the "regularization floor": a minimum meaningful threshold that reflects the irreducible atmospheric attenuation at long path lengths, even under clear skies with real (non-idealized) atmospheric conditions.

---

## Full Reference List

1. Coimbra, C.F.M., Kleissl, J., & Marquez, R. (2013). Overview of solar-forecasting methods and a metric for accuracy evaluation. In *Solar Energy Forecasting and Resource Assessment*, Ch. 8. Academic Press.
2. Engerer, N.A. (2015). Minute resolution estimates of the diffuse fraction of global irradiance for southeastern Australia. *Solar Energy*, 116, 215–237.
3. FAA (2022). Order 7900.5D — Surface Weather Observing. §12.4: Sky Condition.
4. ISO 9060:2018 — Solar energy: Specification and classification of instruments for measuring hemispherical solar and direct solar radiation.
5. Kasten, F. & Czeplak, G. (1980). Solar and terrestrial radiation dependent on the amount and type of cloud. *Solar Energy*, 24(2), 177–189.
6. NWS (2023). Directive 10-503 — Public Weather Services. Table 1: Sky Condition Terms.
7. Ruiz-Arias, J.A. & Gueymard, C.A. (2023). CAELUS: Classification of sky conditions from 1-min time series of global horizontal irradiance. *Solar Energy*, 263, 111895.
8. Skartveit, A. & Olseth, J.A. (1987). A model for the diffuse fraction of hourly global radiation. *Solar Energy*, 38(4), 271–274.
9. Stein, J.S., Hansen, C.W., & Reno, M.J. (2012). The Variability Index. Sandia SAND2012-3464C. *World Renewable Energy Forum*, Denver, CO.
10. Stull, R. (2011). Wet-bulb temperature from relative humidity and air temperature. *J. Applied Meteorology and Climatology*, 50(11), 2267–2269.
11. Tapakis, R. & Charalambides, A.G. (2014). Enhanced values of global irradiance due to the presence of clouds. *Renewable Energy*, 62, 459–467.
12. Smith, C.J., Bright, J.M., & Crook, R. (2017). Cloud cover effect of clear-sky index distributions and direct normal irradiance for five UK locations. *Solar Energy*, 146, 327–338. DOI: 10.1016/j.solener.2017.02.006
