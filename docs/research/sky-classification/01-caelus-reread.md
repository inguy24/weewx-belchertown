# CAELUS Re-read: What It Actually Classifies

**Date:** 2026-06-23
**Paper:** Ruiz-Arias, J.A. & Gueymard, C.A. (2023). "CAELUS: Classification of sky conditions from 1-min time series of global solar irradiance using variability indices and dynamic thresholds." *Solar Energy*, 263, 111895. DOI: 10.1016/j.solener.2023.111895
**Code:** https://github.com/jararias/caelus (Python package `caelus-solar`)
**Status:** Research dump -- direct quotes, source code analysis, and assessment of our usage.

---

## 1. What CAELUS Claims to Classify

### The Name Itself

CAELUS = **C**lassification **A**lgorithm for the **E**valuation of the c**L**o**U**diness **S**ituations.

Note: "cloudiness situations" -- not "cloud types," not "sky conditions for weather reporting," not "cloud coverage categories." The authors chose a term that describes *irradiance behavior patterns associated with cloudiness*, not cloud meteorology.

### Abstract (verbatim)

> "Precise sky classification as a function of cloudiness is desirable or necessary in a variety of applications. CAELUS, a novel classification algorithm that relies on various thresholds to separate all possible sky conditions into six classes, is presented here. It uses global horizontal irradiance (GHI) measurements at 1-min resolution, from which a set of four indices is derived to characterize the magnitude and temporal variability of GHI. The algorithm also requires precise estimates of 1-min GHI under hypothetical cloudless conditions, and the solar zenith angle (limited to a maximum of 85 deg). Using 1-min GHI measurements from 54 BSRN high-quality radiometric stations, which cover all five primary Koppen-Geiger climate classes, CAELUS is used here to classify their sky conditions. The classification results, including the distribution of sky classes and the transitions between consecutive sky classes, are found consistent with the known characteristics of each primary Koppen-Geiger climate. Moreover, in each climate class, the detection of 1-min cloudless situations is found comparable to that provided by two dedicated and state-of-the-art methods -- Reno-Hansen and Bright-Sun."

### Stated Purpose

The paper's stated purpose is classifying "sky conditions as a function of cloudiness" for applications like **solar irradiance forecasting** and **climate-related studies**. The follow-on paper GISPLIT (Ruiz-Arias & Gueymard, 2024, Solar Energy 269) makes the purpose explicit: CAELUS exists to provide "dynamically constrained sky conditions" as a preprocessing step for **solar irradiance component separation** (splitting GHI into direct and diffuse components). Each CAELUS sky class gets its own empirical submodel in GISPLIT.

**CAELUS is a solar energy tool.** It classifies irradiance behavior regimes, not weather conditions for public reporting.

---

## 2. The Critical Disclaimer the Authors Provide

From the GitHub README (verbatim):

> "The name of the different sky conditions is only orientative of the expected situations within each class. However, it does not mean that, for instance, all situations detected as `THICK_CLOUDS` are actually made up only by thick clouds."

The paper elaborates:

> "...what can be considered a 'thick' cloud is highly subjective, and there are many situations made up by those 'thick' clouds but also others. The same reasoning holds for all other sky conditions."

**This is the authors themselves saying: do not interpret our class labels as physical cloud descriptions.** The labels are convenience names for irradiance regimes, not cloud-type identifiers.

---

## 3. The Six Classes: What They Actually Represent

From the source code (`skytype.py`), the classes are:

```python
class SkyType(enum.IntEnum):
    UNKNOWN = 1
    OVERCAST = 2
    THICK_CLOUDS = 3
    SCATTER_CLOUDS = 4
    THIN_CLOUDS = 5
    CLOUDLESS = 6
    CLOUD_ENHANCEMENT = 7
```

Ordered from lowest to highest clear-sky index / transmittance. Here is what each class actually measures, based on the classification logic in `sky_indices.py`:

### CLOUD_ENHANCEMENT (7)
- **Condition:** Kcs > 1.06 AND Kv > 0.20 AND Kvf > 0.20 AND SZA < 80 deg
- **Meaning:** Measured GHI *exceeds* clear-sky model by at least 6%, with high temporal variability at both coarse (30-min) and fine (10-min) scales.
- **Physical situation:** Broken clouds near the sun causing refraction/reflection that briefly boosts surface irradiance above clear-sky values. Not a "cloud type" -- it is an irradiance anomaly.

### CLOUDLESS (6)
- **Condition:** Km > 0.6 AND 0.85 < Kcs < 1.15 AND Kv < 0.03 (relaxed bounds for SZA >= 75 deg)
- **Meaning:** High transmittance (Km, the smoothed ratio of GHI to hypothetical clean-dry-atmosphere GHI), clear-sky index near 1.0, and very low variability.
- **Physical situation:** Genuinely clear sky, or possibly very thin uniform high clouds with no variability signature.

### THIN_CLOUDS (5)
- **Condition:** (not cloudless, not overcast, not cloud-enhancement) AND Km > 0.5 AND 0.03 <= Kv < 0.08
- **Meaning:** Moderate-to-high transmittance with *slight* variability. The "cloudy" residual category that has high Km but some Kv signal.
- **Physical situation:** Could be thin cirrus, could be hazy conditions, could be edges of cloud fields. The label "thin clouds" is suggestive but not diagnostic.

### SCATTER_CLOUDS (4)
- **Condition:** (not cloudless, not overcast, not cloud-enhancement, not thin-clouds, not thick-clouds) -- i.e., the **catch-all residual** of the cloudy category.
- **Meaning:** Everything that is cloudy but does not fit the thin-clouds or thick-clouds Kv/Km windows.
- **Physical situation:** Highly variable broken cloud fields, cumulus, or any situation with moderate-to-high variability that does not fall into a tighter category. **This is the garbage-bin class.**

### THICK_CLOUDS (3)
- **Condition:** (not cloudless, not overcast, not cloud-enhancement) AND Km < 0.4 AND 0.04 <= Kv < 0.16
- **Meaning:** Low transmittance (Km < 0.4, meaning GHI is less than 40% of clean-dry-atmosphere model) with moderate variability.
- **Physical situation:** Heavy cloud cover with some breaks or internal variability. Not uniform enough to be overcast, not transmissive enough to be thin.

### OVERCAST (2)
- **Condition:** Km < 0.3 AND Kv < 0.10
- **Meaning:** Very low transmittance AND low variability. The sky is both dark and uniform.
- **Physical situation:** Thick, uniform cloud deck. Heavy stratus, nimbostratus, deep altostratus.

### UNKNOWN (1)
- **Condition:** Nighttime (SZA > 85 deg), or missing data.

---

## 4. Does CAELUS Distinguish Coverage vs. Transmittance?

### Short Answer: No, and It Cannot

CAELUS operates on a single input: **global horizontal irradiance (GHI)** compared to clear-sky model estimates. It has no way to distinguish between:

- **50% cloud coverage with opaque clouds** (half the sky covered, half clear) -- which produces ~50% of clear-sky GHI on average, with HIGH variability as clouds drift across the sun.
- **100% coverage with semi-transparent clouds** (entire sky covered by thin stratus/cirrus) -- which also produces ~50% of clear-sky GHI, but with LOW variability because the coverage is uniform.

These two physically different situations produce the same Km value (~0.5) but different Kv values. CAELUS would classify the first as SCATTER_CLOUDS (high Kv) and the second as THIN_CLOUDS (low Kv). So CAELUS *implicitly* distinguishes these cases through the variability index -- but it does so without knowing or caring that one is a coverage issue and the other is a transmittance issue.

### What the Indices Actually Measure

From the source code (`sky_indices.py`):

| Index | Formula (from code) | What it measures |
|-------|---------------------|------------------|
| **Kcs** | `ghi / ghics` | Instantaneous ratio of measured GHI to clear-sky GHI model. A transmittance ratio, NOT a coverage fraction. |
| **Km** | `rolling_mean(ghi) / ghicda` | Smoothed (30-min rolling mean) ratio of measured GHI to the "clean, dry atmosphere" model. A broad-band atmospheric transmittance including cloud effects, aerosols, and water vapor. |
| **Kv** | `rolling_sum(abs_diff(ghi)) / window_seconds` | Temporal variability of GHI over a 30-min window. Measures how *stable* the irradiance is, not how much sky is covered. |
| **Kvf** | Same as Kv, but over a 10-min window | Fine-scale temporal variability. |

**Key insight:** `ghicda` is the GHI under a hypothetical "clean, dry atmosphere" -- meaning no clouds, no aerosols, no water vapor. It is the theoretical maximum. So Km is a total-atmosphere transmittance metric, not a cloud-specific metric.

### The Paper's Own Acknowledgment

The authors acknowledge that CAELUS cannot be validated against physical cloud observations:

> "The sky classification results obtained with CAELUS cannot be validated because there is no suitable reference source for strict quantitative validation, even with fish-eye sky cameras."

And:

> "The differences between the results of these algorithms are likely smaller than their intrinsic uncertainty, which is a combination of the **fuzzy definition of sky classes**, the empirical methods used in the development of the algorithms, the reliance on imperfect clear-sky irradiance estimates, and the **lack of appropriate reference data sources** for more elaborate validation."

The phrase "fuzzy definition of sky classes" is the authors explicitly saying: these classes do not correspond to sharp physical boundaries. They are empirical clusters in irradiance-index space.

---

## 5. Table 3 Thresholds: Calibration and Ground Truth

### The Thresholds (from `options.py`)

```python
# Table 3 threshold values
CLOUDEN_MIN_KCS = 1.06      # Cloud enhancement: Kcs must exceed clear-sky by 6%
CLOUDLESS_MIN_KM = 0.6       # Cloudless: broad transmittance > 60%
CLOUDLESS_MIN_KCS = 0.85     # Cloudless: instantaneous ratio > 85% of clear-sky
CLOUDLESS_MAX_KCS = 1.15     # Cloudless: instantaneous ratio < 115% of clear-sky
THINCLOUDS_MIN_KM = 0.5      # Thin clouds: transmittance > 50%
THICKCLOUDS_MAX_KM = 0.4     # Thick clouds: transmittance < 40%
OVERCAST_MAX_KM = 0.3        # Overcast: transmittance < 30%
CLOUDEN_MIN_KV = 0.20        # Cloud enhancement: high coarse variability
CLOUDEN_MIN_KVF = 0.20       # Cloud enhancement: high fine variability
CLOUDLESS_MAX_KV = 0.03      # Cloudless: very low variability
THINCLOUDS_MIN_KV = 0.03     # Thin clouds: Kv between 0.03 and 0.08
THINCLOUDS_MAX_KV = 0.08
THICKCLOUDS_MIN_KV = 0.04    # Thick clouds: Kv between 0.04 and 0.16
THICKCLOUDS_MAX_KV = 0.16
OVERCAST_MAX_KV = 0.10       # Overcast: Kv < 0.10
```

### What Were They Calibrated Against?

**Not ground-truth sky observations.** Not satellite cloud fraction. Not METAR/SYNOP cloud reports. Not oktas.

The thresholds were calibrated empirically against:
1. **Internal consistency** across 54 BSRN stations spanning all five Koppen-Geiger climate classes.
2. **Comparison with two existing clear-sky detection algorithms** (Reno-Hansen and Bright-Sun) -- but only for the CLOUDLESS class. The other five classes have no external validation.
3. **Qualitative assessment** that the distribution of sky classes across climate zones matches expectations (e.g., tropical stations show more OVERCAST than desert stations).

The paper explicitly states that the classification results are validated "mostly at qualitative level, but also quantitatively" -- and the quantitative part refers only to the binary clear-sky/not-clear-sky split, not the six-class taxonomy.

**Table 3 thresholds are empirical pattern-clustering boundaries in irradiance-index space, not physical cloud property thresholds.**

---

## 6. How CAELUS Uses Variability Indices (Kv, Kvf)

### Kv as a Primary Discriminator

Kv is NOT a secondary filter -- it is a **primary discriminator** in the classification decision tree. Every class definition includes a Kv condition:

| Class | Km condition | Kv condition | Role of Kv |
|-------|-------------|-------------|------------|
| CLOUD_ENHANCEMENT | (uses Kcs) | Kv > 0.20, Kvf > 0.20 | **Primary:** must have high variability at both scales |
| CLOUDLESS | Km > 0.6 | Kv < 0.03 | **Primary:** must have very low variability |
| OVERCAST | Km < 0.3 | Kv < 0.10 | **Primary:** must have low variability (uniform) |
| THIN_CLOUDS | Km > 0.5 | 0.03 <= Kv < 0.08 | **Primary:** narrow variability band |
| THICK_CLOUDS | Km < 0.4 | 0.04 <= Kv < 0.16 | **Primary:** moderate variability band |
| SCATTER_CLOUDS | (residual) | (residual) | **Catch-all:** whatever Kv values are left |

### What Low Kv Means

Low Kv means the irradiance is **temporally stable** over the rolling window. This happens in two very different physical situations:

1. **Clear sky:** No clouds to cause variability. Kv near zero.
2. **Uniform overcast:** Complete cloud cover with no breaks. Irradiance is low but steady. Kv is low.

CAELUS separates these two cases by Km: clear sky has high Km (> 0.6), overcast has low Km (< 0.3). The range 0.3-0.6 with low Kv is the ambiguous zone -- it could be uniform thin overcast, heavy haze, or other uniform-attenuation scenarios.

### What Low Kv Does NOT Mean

Low Kv does **not** mean "few clouds." It means "whatever is up there is not changing the irradiance pattern over 30 minutes." A sky that is 100% covered with thin uniform stratus has low Kv. A sky that is 0% covered (clear) has low Kv. These are opposite coverage situations with the same variability signature.

### Kvf (Fine-Scale Variability)

Kvf is only used in one place: the CLOUD_ENHANCEMENT detection. Both Kv (30-min) and Kvf (10-min) must exceed 0.20. This ensures that cloud enhancement is identified only when variability is high at multiple time scales, filtering out slow-changing conditions.

---

## 7. Marine Layer / Stratus / Uniform Thin Overcast

### Does CAELUS Handle This?

**Partially, but not as a distinct class.**

A classic marine layer (uniform stratus deck, ~300m altitude, typically transmitting 20-40% of clear-sky GHI) would be classified by CAELUS as:

- **OVERCAST** if Km < 0.3 and Kv < 0.10 (thick marine layer, very low transmittance, uniform)
- **THICK_CLOUDS** if 0.3 < Km < 0.4 and 0.04 < Kv < 0.16 (moderate marine layer with some variability, perhaps thinning at edges)
- **THIN_CLOUDS** if Km > 0.5 and 0.03 < Kv < 0.08 (thin marine layer / high fog with high transmittance)

The transition zone between 0.3 and 0.5 Km with low Kv is problematic. If Km is between 0.3 and 0.5 AND Kv is below 0.03 or 0.04, the minute falls into SCATTER_CLOUDS (the catch-all residual) -- which is a nonsensical label for uniform stratus. This is because the classification tree first excludes CLOUDLESS, OVERCAST, and CLOUD_ENHANCEMENT, then within the "cloudy" residual, applies Km/Kv windows for THIN and THICK, and dumps everything else into SCATTER.

### The Gap

There is no CAELUS class for **"uniform moderate attenuation"** -- i.e., a sky that is transmitting 30-50% of clear-sky GHI with very low variability. This is exactly what a thin uniform stratus/altostratus deck produces. Depending on exact Km and Kv values, such conditions could end up labeled OVERCAST (if Km < 0.3), THICK_CLOUDS (if Kv is in range), THIN_CLOUDS (if Km > 0.5), or SCATTER_CLOUDS (catch-all).

### Do the Authors Acknowledge This?

Not specifically for marine layer/stratus. The authors acknowledge the general limitation through the "orientative" disclaimer and the "fuzzy definition of sky classes" statement. They do not discuss specific failure modes for uniform semi-transparent cloud layers. The paper's validation is focused on the CLOUDLESS detection (comparison with Reno-Hansen and Bright-Sun) and the aggregate distribution of classes across climate zones -- not on per-minute accuracy of non-cloudless classes.

---

## 8. The Post-Classification Filters

From `filters.py`, CAELUS applies four cleaning filters (all enabled by default):

1. **Spurious sky patches:** Brief transitions (< 15 minutes) that are surrounded by longer patches of a different type get reclassified to match their surroundings. Runs iteratively up to 50 times until convergence.

2. **Scatter clouds flanked by thin clouds:** SCATTER_CLOUDS patches lasting 25-35 minutes between THIN_CLOUDS patches get downgraded to THIN_CLOUDS, unless specific Kv/SZA conditions suggest genuine scatter.

3. **Cloudless-to-thin transitions:** Brief CLOUDLESS patches surrounded by THIN_CLOUDS get reclassified as THIN_CLOUDS if their Kv quartile meets a threshold (0.01).

4. **Thin-to-scatter transitions:** THIN_CLOUDS patches surrounded by SCATTER_CLOUDS (> 20 steps) get upgraded to SCATTER_CLOUDS if their Kv quartile reaches 0.04.

These filters are **temporal smoothing heuristics** designed to reduce "noisy" classifications. They assume that the physical sky changes gradually, which is generally true but can mask real rapid transitions (e.g., a sea breeze front clearing a marine layer in 10 minutes).

---

## 9. Assessment: Have We Been Misusing CAELUS?

### Yes, Significantly

Based on this analysis, our usage of CAELUS has had at least three misinterpretations:

**Misinterpretation 1: Treating CAELUS classes as cloud coverage categories.**
CAELUS classes are **irradiance behavior regimes**, not cloud coverage categories. SCATTER_CLOUDS does not mean "scattered cloud coverage" in the NWS/WMO sense (3-4 oktas). It means "irradiance variability that does not fit the thin-clouds or thick-clouds Kv/Km windows." The authors explicitly say the class names are "only orientative."

**Misinterpretation 2: Assuming CAELUS distinguishes coverage from transmittance.**
CAELUS has no mechanism to distinguish cloud coverage fraction from cloud optical depth / transmittance. Its indices (Kcs, Km) measure total atmospheric transmittance -- a single number that conflates coverage, optical depth, and aerosol effects. Its variability indices (Kv, Kvf) measure temporal stability, which correlates with spatial uniformity but is not the same thing. A sky with 50% coverage by opaque cumulus and a sky with 100% coverage by semi-transparent stratus can produce identical Km values.

**Misinterpretation 3: Expecting CAELUS class labels to map to NWS/WMO sky condition categories.**
There is no correspondence. NWS sky conditions (CLR, FEW, SCT, BKN, OVC) are defined by cloud coverage fraction in oktas. CAELUS classes are defined by irradiance-index thresholds. The mapping between them is many-to-many:

| NWS Category | CAELUS class(es) that could appear | Why |
|---|---|---|
| CLR (0 oktas) | CLOUDLESS | Direct match |
| FEW (1-2 oktas) | CLOUDLESS, THIN_CLOUDS, SCATTER_CLOUDS | A few thin cirrus may not change Kv enough to exit CLOUDLESS |
| SCT (3-4 oktas) | SCATTER_CLOUDS, THIN_CLOUDS, THICK_CLOUDS | Depends on cloud type and variability |
| BKN (5-7 oktas) | SCATTER_CLOUDS, THICK_CLOUDS, THIN_CLOUDS | High coverage can still have high Km if clouds are thin |
| OVC (8 oktas) | OVERCAST, THICK_CLOUDS, THIN_CLOUDS | Thin uniform overcast (cirrostratus) has high Km, low Kv |

---

## 10. What CAELUS IS Good For (In Our Context)

Despite the misinterpretations, CAELUS provides genuinely useful information:

1. **Clear-sky detection:** The CLOUDLESS class is well-validated against Reno-Hansen and Bright-Sun. This is the one class with solid external validation.

2. **Irradiance variability regime:** Even though the classes are not cloud-type labels, they do reliably indicate how the irradiance is behaving -- stable-high, stable-low, variable, or enhanced. This is useful for:
   - Solar energy production estimates
   - Choosing interpolation strategies for missing data
   - Identifying cloud-enhancement events

3. **Temporal structure:** The transitions between CAELUS classes (and the post-classification filters) reveal the temporal evolution of irradiance patterns, which correlates with weather system dynamics even if it does not directly identify cloud types.

---

## 11. Key Quotes for Reference

**On the nature of the classes:**
> "The name of the different sky conditions is only orientative of the expected situations within each class. However, it does not mean that, for instance, all situations detected as THICK_CLOUDS are actually made up only by thick clouds."

**On validation impossibility:**
> "The sky classification results obtained with CAELUS cannot be validated because there is no suitable reference source for strict quantitative validation, even with fish-eye sky cameras."

**On intrinsic uncertainty:**
> "The differences between the results of these algorithms are likely smaller than their intrinsic uncertainty, which is a combination of the fuzzy definition of sky classes, the empirical methods used in the development of the algorithms, the reliance on imperfect clear-sky irradiance estimates, and the lack of appropriate reference data sources for more elaborate validation."

**On the purpose (from the abstract):**
> "Precise sky classification as a function of cloudiness is desirable or necessary in a variety of applications."

**On GISPLIT integration (from the follow-on paper):**
> "...the model takes advantage of a preliminary classification of the sky conditions into six sky types, with an empirical submodel assigned to each sky class to split GHI into its components."

---

## 12. Sources

- **Paper:** Ruiz-Arias, J.A. & Gueymard, C.A. (2023). Solar Energy, 263, 111895. https://www.sciencedirect.com/science/article/pii/S0038092X23005285
- **GitHub:** https://github.com/jararias/caelus
- **Source files analyzed:** `skytype.py`, `sky_indices.py`, `classifier.py`, `filters.py`, `options.py` (all at `src/caelus/` in the GitHub repo)
- **GISPLIT follow-on:** Ruiz-Arias & Gueymard (2024). Solar Energy, 269. https://www.sciencedirect.com/science/article/pii/S0038092X24000574
- **BSRN benchmark data:** Zenodo record 7897639, 54 stations, all Koppen-Geiger climate classes
- **ADS entry:** https://ui.adsabs.harvard.edu/abs/2023SoEn..26311895R/abstract
- **Cloud cover / clear-sky index relationship:** Bright et al. (2017). "Cloud cover effect of clear-sky index distributions." Solar Energy. https://www.sciencedirect.com/science/article/abs/pii/S0038092X16306624
