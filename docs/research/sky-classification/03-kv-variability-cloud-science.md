# Kv Variability Index and Cloud Coverage Science

Research dump: scientific literature on using solar radiation variability indices
to classify cloud COVERAGE patterns (not just energy impact).

Date: 2026-06-23

---

## 1. The Stein et al. Variability Index (VI) -- Sandia SAND2012-3464C

### Citation

Stein, J. S., Hansen, C. W., & Reno, M. J. (2012). "The Variability Index:
A New and Novel Metric for Quantifying Irradiance and PV Output Variability."
Sandia National Laboratories, SAND2012-3464C. Presented May 14, 2012, Denver, CO.
OSTI: https://www.osti.gov/biblio/1078490

### What VI Measures

The Variability Index is defined as **the ratio of the "length" of the measured
irradiance curve plotted against time to the "length" of the clear-sky reference
irradiance curve plotted against time**.

Conceptually, imagine plotting GHI vs. time. On a clear day, the curve is smooth
and its "arc length" matches the clear-sky model. On a variable day with rapid
ups and downs, the measured curve zigzags, making its total path length much
longer. VI captures this.

### Calculation

VI = (sum of line-segment lengths along measured GHI curve) /
     (sum of line-segment lengths along clear-sky GHI curve)

For each consecutive pair of measurements at times t_i and t_{i+1}:
- Measured length segment = sqrt((t_{i+1} - t_i)^2 + (GHI_{i+1} - GHI_i)^2)
- Clear-sky length segment = sqrt((t_{i+1} - t_i)^2 + (GHIcs_{i+1} - GHIcs_i)^2)

Simplified (when time steps are uniform): VI is dominated by the sum of absolute
GHI differences (ramp rates) normalized by the same sum for the clear-sky model.

**For a perfectly clear day: VI = 1.0** (measured matches clear-sky).
**For a variable day: VI >> 1** (jagged signal has longer path length).
**For a uniformly overcast day: VI is close to 1** (smooth but attenuated signal
still has smooth path similar in character to the clear-sky reference).

### Key Insight for Our Use Case

**VI (and by extension our Kv) was designed to measure temporal variability of
the irradiance signal, not transmittance level.** It explicitly separates
"how jagged is the signal" from "how much energy came through."

This is EXACTLY the distinction we need: Kv tells us about the temporal PATTERN
of clouds (uniform vs. broken), while Km tells us about the overall
TRANSMITTANCE (how much light gets through on average).

### Limitations Noted in Literature

- VI is NOT a normalized index -- it shows dependency on day of year, geographic
  location, and time resolution (Marzouq et al., 2020).
- A "normalized variability index" (VI') was proposed to address these issues:
  Marzouq, M. et al. (2020). "A normalized variability index of daily solar
  radiation." AIP Conference Proceedings 2303.
- Our Kv avoids some of these issues because we compute over a rolling 30-min
  window (fixed timescale) and detrend against the clear-sky reference.


## 2. The Arrowhead Plot: Two-Dimensional (Km, Kv) Classification

### The Foundational Concept

Multiple research groups have converged on the same insight: **a single index
(either clearness/transmittance OR variability) is insufficient to classify sky
conditions. You need BOTH axes.**

When you plot daily clearness index (our Km) on the X-axis vs. variability index
(our Kv) on the Y-axis, the resulting scatter plot forms an **"arrowhead" shape**
that naturally separates into distinct sky-condition regimes.

### The Five Regimes

From: Cheng, Z., et al. (2024). "A Standardized Sky Condition Classification
Method for Multiple Timescales and Its Applications in the Solar Industry."
Energies, 17(18), 4616. https://www.mdpi.com/1996-1073/17/18/4616

The classification identifies these day types:

| Class             | Clearness Index (Km) | Variability (Kv) | Physical Meaning                |
|-------------------|----------------------|-------------------|---------------------------------|
| Clear-sky         | High (~0.7-1.0)      | Low               | Unobstructed sun, smooth curve  |
| Overcast          | Low (~0.0-0.3)       | Low               | Uniform thick cloud, smooth     |
| Low intermittent  | Moderate (~0.4-0.6)  | Moderate          | Thin uniform cloud OR haze      |
| High intermittent | Moderate (~0.3-0.6)  | High              | Broken/scattered clouds         |
| Highly variable   | Variable (any)       | Very high         | Rapidly alternating clear/cloud |

**KEY FINDING:** The classification uses "daily clear-sky index to estimate the
cloudiness in the sky, and ramp rates to account for variability introduced due
to sudden cloud movements." A ramp-rate metric alone "fails to distinguish
clear-sky and cloudy days, with both categorized as very stable days, which can
be misleading."

This validates our architecture: we need BOTH Km AND Kv to classify sky conditions.

### The Arrowhead Shape Explained

The arrowhead forms because:
- Clear days cluster at (high Km, low Kv) -- right side, bottom
- Overcast days cluster at (low Km, low Kv) -- left side, bottom
- Variable days spread upward from the middle -- the "arrowhead tip" pointing up
- The edges of the arrowhead correspond to physical limits: you can't have very
  high Km AND very high Kv (would require clear sky + wild fluctuations), and
  you can't have very low Km AND very high Kv (totally blocked sky can't fluctuate
  much either)

Reference: Variability index of solar resource based on data from surface and
satellite (2022). Renewable Energy, https://doi.org/10.1016/j.renene.2022.10.084


## 3. Physical Interpretation of (Km, Kv) Combinations

This is the core question: what do different combinations MEAN for cloud coverage?

### High Km + Low Kv: CLEAR SKY

- Km near 1.0, Kv near 0 (or near baseline)
- Almost no cloud cover
- Smooth GHI curve closely following the clear-sky model
- Physically: no clouds, or perhaps very thin high cirrus that doesn't
  significantly attenuate or create shadows

### Moderate Km + Low Kv: UNIFORM THIN OVERCAST (Stratus / Marine Layer)

**THIS IS THE KEY FINDING FOR OUR USE CASE.**

- Km in range ~0.3-0.7, Kv near baseline
- Consistent attenuation but NO temporal fluctuation
- Physically: uniform cloud layer that reduces but does not interrupt irradiance
- Cloud types: thin stratus, altostratus, marine layer, fog/mist overhead
- The signal is SMOOTH but DEPRESSED -- the cloud acts as a uniform filter

This is precisely the regime we were looking for. Low Kv with moderate Km
is a strong signal for "uniform overcast with partial transmittance" -- i.e.,
the sky IS covered but the cloud is thin enough to let some light through.

Supporting evidence:
- Duchon & O'Malley (1999) classified stratus as having LOW standard deviation
  of clearness index combined with REDUCED mean clearness ratio
- Mol & van Heerwaarden (2024, 2025) showed that stratus/stratocumulus produce
  "minimal variability unless dissolving or with distinct gaps"
- The CAELUS algorithm (Ruiz-Arias et al., 2023) classifies this regime as
  "overcast" or "cloud-attenuated" based on high clear-sky index stability

### Moderate Km + High Kv: BROKEN/SCATTERED CLOUD COVER

- Km in range ~0.3-0.7, Kv significantly elevated
- The AVERAGE transmittance is moderate, but the signal is JAGGED
- Physically: alternating cloud shadows and clear gaps; clouds are discrete
  entities moving across the sensor's field of view
- Cloud types: cumulus, broken stratocumulus, trade-wind cumulus fields
- GHI signal shows rapid transitions between near-clear and cloud-shadowed states

Supporting evidence:
- Mol & van Heerwaarden (2025): "Surface solar irradiance variability is present
  under all broken clouds, but the patterns, magnitude of variability, and driving
  mechanisms vary greatly with cloud type." Cumulus clouds show "fast and frequent
  transitions between shade and sunshine."
- Duchon & O'Malley (1999): HIGH standard deviation of clearness index with
  moderate mean ratio = cumulus or broken stratocumulus
- Stein et al. (2012): VI >> 1 when measured GHI curve zigzags, indicating
  cloud edges repeatedly crossing the sensor

### Low Km + Low Kv: THICK UNIFORM OVERCAST

- Km below ~0.3, Kv near baseline
- Heavy attenuation AND smooth signal
- Physically: thick stratus, nimbostratus (rain clouds), deep overcast
- Very little light gets through, and what does get through is uniform diffuse
- Signal is smooth because there are no gaps in the cloud for sun to peek through

### Low Km + High Kv: THICK BROKEN CLOUD WITH ENHANCEMENT

- Km below ~0.3 average, but Kv is elevated
- This is a rarer regime but does occur
- Physically: thick clouds with occasional breaks that cause brief spikes
  (cloud enhancement events), followed by return to heavy attenuation
- Can also indicate precipitation with intermittent clearings
- Mol & van Heerwaarden (2025) found stratocumulus with small gaps can cause
  "particularly strong and short cloud enhancements, generating the shortest
  lasting cloud enhancement events, averaging roughly one minute"


## 4. Duchon & O'Malley (1999): Cloud Type from Pyranometer Observations

### Citation

Duchon, C. E., & O'Malley, M. S. (1999). "Estimating Cloud Type from
Pyranometer Observations." Journal of Applied Meteorology, 38(1), 132-141.
https://journals.ametsoc.org/view/journals/apme/38/1/1520-0450_1999_038_0132_ectfpo_2.0.co_2.xml

### Method

Uses **50-minute running mean values** of two metrics:
1. **Standard deviation of scaled irradiance** (our Kv analog)
2. **Ratio of mean observed to clear-sky irradiance** (our Km analog)

These two metrics are plotted in a 2D space to classify into seven cloud types:
- Clear sky
- Cirrus
- Cumulus
- Cumulus + Cirrus
- Stratus
- Precipitation + Fog
- Other

### Key Findings for Our Use Case

- **Stratus** occupies the LOW standard deviation + MODERATE-TO-LOW clearness
  ratio region -- exactly our "moderate Km + low Kv" regime
- **Cumulus** occupies the HIGH standard deviation + MODERATE clearness ratio
  region -- exactly our "moderate Km + high Kv" regime
- Agreement with human sky observers: ~45% (limited because pyranometer "sees"
  only clouds crossing the sun's path, while observers see the whole sky)
- Aerosols can cause the method to overestimate cirrus and cirrus+cumulus
  occurrence

### Relevance

**This is the foundational paper proving that cloud TYPE can be inferred from
the combination of mean transmittance and temporal variability of ground-based
irradiance measurements.** Published in 1999, it established the two-axis
classification approach that our Km+Kv system follows.


## 5. CAELUS: Six-Class Sky Classification from 1-Minute GHI

### Citation

Ruiz-Arias, J. A., Gueymard, C. A., & Fernandez-Peruchena, C. M. (2023).
"CAELUS: Classification of sky conditions from 1-min time series of global
solar irradiance using variability indices and dynamic thresholds."
Solar Energy, 263, 111895.
https://doi.org/10.1016/j.solener.2023.111895

### Method

CAELUS uses **four indices** derived from 1-minute GHI measurements to classify
sky conditions into **six classes**. It requires:
- 1-min GHI measurements
- Clear-sky GHI estimates (from a model like REST2 or McClear)
- Solar zenith angle (limited to max 85 deg)

### Validation

Tested on data from **54 BSRN (Baseline Surface Radiation Network)
high-quality radiometric stations** covering all five primary Koppen-Geiger
climate classes. The classification results were found consistent with
known climate characteristics of each zone.

### Significance for Our Project

CAELUS demonstrates that 1-minute GHI time series combined with clear-sky
reference models and variability indices can robustly classify sky conditions
at the single-station level -- which is exactly our setup (one weather station
with 1-minute GHI readings and maxSolarRad as the clear-sky reference).


## 6. Clear-Sky Index Stationarity and Detrending

### The Concept (Coimbra, Pedro, Inman et al.)

Inman, R. H., Pedro, H. T. C., & Coimbra, C. F. M. (2013). "Solar Forecasting
Methods for Renewable Energy Integration." Progress in Energy and Combustion
Science, 39, 535-576.

### Key Insight: Why Detrending Matters

Raw GHI is NOT stationary -- it has daily and annual cycles driven by solar
geometry. To isolate the cloud-driven component, you must detrend by dividing
by the clear-sky expectation:

    kcs(t) = GHI(t) / GHIcs(t)

This clear-sky index kcs is (approximately) stationary, meaning:
- **The deterministic component** (sun's position) is removed
- **Only the stochastic component** (cloud-driven variation) remains

"Normalization by a clear sky profile removes the deterministic component of the
irradiation due to the sun path, so only the stochastic part linked to clouds
motion remains." (Multiple sources, review in PMC/8531863)

### Application to Our Kv

Our Kv is computed as the cumulative absolute first-derivative of DETRENDED GHI
(i.e., GHI/maxSolarRad). This is correct practice per the literature:
- Computing variability on raw GHI would mix solar geometry changes with cloud
  variability (e.g., sunrise/sunset ramps would register as "variability")
- Computing variability on the clear-sky index (kcs = GHI/GHIcs) isolates the
  cloud signal
- The first-derivative of kcs captures cloud-induced CHANGES, not the level

### Stationarity and Classification

The clear-sky index has been shown to have a **bimodal distribution** across
most climates:
- One mode near kcs = 1.0 (clear sky)
- One mode near kcs = 0.2-0.4 (cloudy)
- Fewer intermediate values

(Mol & van Heerwaarden, 2024; cloud cover effect studies)

This bimodality means that moderate mean kcs values (~0.5-0.7) can arise from
either:
1. Uniform thin overcast (unimodal distribution centered at ~0.6) -- low Kv
2. Alternating clear and cloudy periods (bimodal, averaging to ~0.6) -- high Kv

**Kv is what distinguishes these two cases.** This is the central scientific
argument for using variability as a cloud coverage discriminator.


## 7. Mol & van Heerwaarden (2024, 2025): Cloud Type Signatures in GHI

### Citations

Mol, W., Heusinkveld, B., et al. (2024). "Observed patterns of surface solar
irradiance under cloudy and clear-sky conditions." Quarterly Journal of the Royal
Meteorological Society, 150(761), 2338-2363.
https://doi.org/10.1002/qj.4712

Mol, W., & van Heerwaarden, C. (2025). "Mechanisms of surface solar irradiance
variability under broken clouds." Atmospheric Chemistry and Physics, 25, 4419-4441.
https://doi.org/10.5194/acp-25-4419-2025

### Four Mechanisms of SSI Variability

The 2025 paper identifies four physical mechanisms controlling surface solar
irradiance (SSI) variability:

1. **Forward escape** -- optically thin clouds (tau < 6): scattered radiation
   follows the direct beam path. Creates 30-60% irradiance enhancement in gaps.

2. **Downward escape** -- optically thick clouds (tau > 6): diffuse radiation
   scattered downward. Peak enhancement directly beneath cloud edges.

3. **Side escape** -- vertically developed clouds (cumulus/cumulonimbus):
   scattered radiation escapes from cloud sides. Asymmetric surface patterns.

4. **Albedo enhancement** -- multiple scattering between surface and cloud base.
   10-60% contribution depending on surface reflectivity.

### Cloud-Type-Specific GHI Signatures

**Shallow cumulus**: Fast transitions between shade and sunshine. Bimodal SSI
distribution. Shadows 50-80% darker than clear-sky values. Transitions across
tens of meters. **HIGH Kv expected.**

**Altocumulus**: Extreme irradiance peaks (30-50% above clear sky) through
forward escape. Relatively constant diffuse irradiance. Enhancement peaks in
gaps between patches. **HIGH Kv expected.**

**Cumulonimbus**: Long-lasting enhancement on sunlit side. ~35% peak enhancement.
**MODERATE Kv** (longer shadow duration, less rapid switching).

**Stratus/stratocumulus (solid)**: Minimal variability unless dissolving or with
gaps. Enhancement occurs primarily during transitions or at gap edges.
**LOW Kv expected.**

**Stratocumulus (broken)**: Small gaps cause "particularly strong and short cloud
enhancements." Shortest enhancement events (~1 minute vs ~3 minutes for cumulus).
**HIGH Kv expected** despite high overall coverage.

### Cloud Optical Depth Threshold

tau = 6 is the critical threshold: below this, forward escape dominates (thin
semi-transparent clouds); above this, downward escape dominates (thick opaque
clouds). This maps to our Km: thin clouds (tau < 6) produce moderate Km,
thick clouds (tau > 6) produce low Km.


## 8. Lave & Kleissl: Ramp Rates and Cloud Speed

### Citations

Lave, M., & Kleissl, J. (2013). "Cloud speed impact on solar variability
scaling -- Application to the wavelet variability model." Solar Energy, 91,
11-21.

Lave, M., Reno, M. J., & Broderick, R. J. (2015). "Characterizing local
high-frequency solar variability and its impact to distribution studies."
Solar Energy, 118, 327-337.

### Key Findings

**Cloud speed determines ramp rate magnitude:**
- Faster cloud movement = steeper ramps = higher Kv for the same cloud coverage
- The WVM (Wavelet Variability Model) scaling coefficient is linearly
  proportional to cloud speed
- At a single station, fast-moving broken clouds produce higher Kv than
  slow-moving broken clouds at the same coverage fraction

**Implication for our Kv interpretation:**
Kv is influenced by BOTH cloud coverage pattern AND cloud speed. Two identical
cloud fields moving at different speeds will produce different Kv values. This
means:
- Very high Kv could be moderate broken cloud moving fast, OR dense broken
  cloud moving slowly
- Moderate Kv could be sparse broken cloud, OR moderate broken cloud moving slowly
- Kv alone cannot fully disambiguate coverage from speed

**However, for CLASSIFICATION purposes (not quantification), the speed effect
is secondary.** Uniform overcast at ANY speed produces low Kv. Clear sky at ANY
speed produces low Kv. Only broken/scattered cloud produces high Kv regardless
of speed (though speed modulates HOW high).

### Ramp Rate Analysis

Lave et al. (2015) proposed that sub-minute ramp rate distributions characterize
local solar variability. Up to 300% difference in distribution grid impact was
found between locations with different variability profiles, even with similar
average irradiance -- underscoring that VARIABILITY is an independent dimension
from mean LEVEL.


## 9. Perez et al.: Parameterization of Short-Term Variability

### Citation

Perez, R., Kivalov, S., Schlemmer, J., Hemker, K., & Hoff, T. (2011).
"Parameterization of site-specific short-term irradiance variability."
Solar Energy, 85(7), 1343-1353.

Perez, R., David, M., Hoff, T. E., et al. (2016). "Spatial and Temporal
Variability of Solar Energy." Foundations and Trends in Renewable Energy, 1(1).

### Four Variability Metrics

Perez et al. identified four metrics from 92,000+ hourly data points at 24 US
sites:
1. Standard deviation of the global irradiance clear-sky index (sigma_k)
2. Mean change in clear-sky index between consecutive intervals (delta_k)
3. Maximum change in clear-sky index
4. Standard deviation of the change in clear-sky index

### Classification Threshold

Solar variability is defined as "the standard deviation of the change in the
clear-sky index at a 1-hour time step, with values above 0.2 considered to
experience variable sky conditions."

### Relationship to Cloud Conditions

- "The standard deviation increases with the range of cloud categories"
- Greater variation in cloud types = higher irradiance variability
- Sites where cloud regimes are weather-driven tend to show less variability
- Sites influenced by local orography tend to show more variability

### Relevance

Perez's work validates that sigma_k (analogous to our Kv) is a robust
discriminator of sky conditions across diverse climates. The 0.2 threshold
for hourly data provides a reference point (though our 1-minute resolution
and 30-minute window will have different absolute values).


## 10. Lusi et al. (2024): Machine Learning Cloud Classification from GHI

### Citation

Lusi, A. R., et al. (2024). "Cloud classification through machine learning and
global horizontal irradiance data analysis." Quarterly Journal of the Royal
Meteorological Society.
https://doi.org/10.1002/qj.4880

### Key Finding

**Different cloud types have their own GHI signatures.** The study trained
supervised learning algorithms using GHI data manually labeled from synchronized
all-sky images, demonstrating that cloud TYPE can be classified from GHI temporal
patterns alone.

### Implications

This is the most direct validation that the SHAPE of the GHI signal (which our
Kv captures) contains information about cloud TYPE, not just cloud presence.
The fact that ML algorithms can learn to classify cloud types from GHI data
proves that the temporal pattern carries discriminating information.


## 11. Chatterjee, Raabe, & Crewell (2026): Four Cloud Regimes

### Citation

Chatterjee, D., Raabe, N., & Crewell, S. (2026). "Four low-level cloud regimes
revealed by latent space analysis and their impact on solar energy variability."
Machine Learning: Earth, 2(1).
https://doi.org/10.1088/3049-4753/ae4e30

### Four Regimes and Their Solar Impact

Using self-supervised neural network analysis of cloud optical depth satellite
imagery, four low-cloud regimes were identified:

1. **Class 1**: Weakest shallow convection, lowest COD and cloud fraction.
   Solar impact: moderate variability.

2. **Class 2**: More mature development, higher cloud amount and COD.
   Solar impact: **highest mean ramp rates** (high Kv), indicating strong
   fluctuation likely due to broken or fast-moving cloud structures.

3. **Class 3**: Deeper clouds with enhanced convective activity.
   Solar impact: **highest mean ramp rates** (high Kv), similar to Class 2.

4. **Class 4**: Most optically thick and widespread cloud fields.
   Solar impact: **lowest mean ramp rates** (low Kv), suggesting more stable,
   less variable cloud cover.

**This directly maps to our framework:** Class 4 (thick widespread) = low Kv,
Classes 2-3 (broken/convective) = high Kv.


## 12. Bright (2020): BrightSun Clear-Sky Detection

### Citation

Bright, J. M., Babacan, O., Kleissl, J., Taylor, P. G., & Crook, R. (2020).
"Bright-Sun: A globally applicable 1-min irradiance clear-sky detection model."
Renewable and Sustainable Energy Reviews, 121, 109706.

### Relevance

BrightSun extends the Reno-Hansen clear-sky detection algorithm to 1-minute
resolution. It uses GHI AND diffuse horizontal irradiance (DIF) for three-stage
analysis:
1. Clear-sky irradiance optimization
2. Tri-component CSD analysis (Modified-Reno method)
3. Cascading durational filters

The key insight: "due to the significant influence of bright or dark clouds on
DIF, which have much lower impact on GHI, the model exhibits extra discretionary
power by including analysis on DIF."

**For our system:** We only have GHI (no separate DIF sensor), so we rely
entirely on GHI-based classification. The literature confirms this is viable
but less discriminating than GHI+DIF approaches.


## 13. Woyte, Belmans, & Nijs (2007): Wavelet Analysis of Clearness Index

### Citation

Woyte, A., Belmans, R., & Nijs, J. (2007). "Fluctuations in instantaneous
clearness index: Analysis and statistics." Solar Energy, 81(2), 195-206.

### Method

Used wavelet transform to analyze clearness index fluctuations at ALL timescales,
from seconds to hours. The clearness index CI = GHI / extraterrestrial irradiance.

### Key Findings

- Large CI values = clear sky (less reduction)
- Small CI values = overcast
- Fluctuations at short timescales (seconds to minutes) are driven by cloud
  passage events
- The wavelet approach reveals that different cloud types produce energy at
  different temporal frequency bands
- Cumulus: energy at 1-10 minute frequencies (rapid switching)
- Stratus: energy at longer frequencies or near-zero (smooth/slowly varying)

### Relevance

Confirms that the FREQUENCY CONTENT of the irradiance signal carries cloud-type
information. Our Kv (cumulative absolute first-derivative over 30 minutes) is
essentially a time-domain proxy for the high-frequency energy content of the
signal -- high Kv = lots of high-frequency fluctuation = broken/scattered cloud.


## 14. Reno & Hansen (2016): Clear-Sky Period Identification

### Citation

Reno, M. J., & Hansen, C. W. (2016). "Identification of Periods of Clear Sky
Irradiance in Time Series of GHI Measurements." Renewable Energy, 90, 520-531.

### Method

Algorithm compares five statistics of the GHI time series against a clear-sky
model output:
1. Mean GHI value
2. Maximum GHI value
3. Line length (sum of point-to-point distances -- the VI concept)
4. Standard deviation of GHI rate of change
5. Maximum deviation from clear-sky model

### Relevance

Statistics 3 and 4 are direct analogs to our Kv concept. The Reno-Hansen
algorithm demonstrates that line length and standard deviation of rate-of-change
are among the most discriminating features for separating clear-sky from
cloudy periods. Combined with statistics 1-2 (mean/max, analogous to Km), the
full set provides robust classification.


## 15. Synthesis: What the Literature Tells Us About Km + Kv Classification

### The Science Is Clear

The two-axis (mean transmittance + temporal variability) approach to sky
classification is well-established in the solar energy and atmospheric science
literature, with roots going back to Duchon & O'Malley (1999) and extensive
development through the 2010s-2020s.

### Summary Table: Physical Meaning of (Km, Kv) Regimes

| Km Range  | Kv Level | Sky Condition             | Cloud Type               | GHI Signal Shape            |
|-----------|----------|---------------------------|--------------------------|------------------------------|
| > 0.85    | Low      | Clear sky                 | None / thin cirrus       | Smooth, follows clear-sky    |
| 0.5-0.85  | Low      | Thin uniform overcast     | Thin stratus, alto-St    | Smooth but depressed         |
| 0.5-0.85  | High     | Broken/scattered cloud    | Cumulus, broken Sc       | Jagged, rapid oscillations   |
| 0.3-0.5   | Low      | Moderate uniform overcast | Stratus, altostratus     | Smooth, significantly reduced|
| 0.3-0.5   | High     | Dense broken cloud        | Thick Cu, broken Cb      | Wild swings, deep shadows    |
| < 0.3     | Low      | Thick overcast / precip   | Nimbostratus, thick St   | Smooth, heavily attenuated   |
| < 0.3     | High     | Thick cloud with breaks   | Breaking storm, Sc gaps  | Mostly dark with bright spikes|

### Key Caveats from the Literature

1. **Cloud speed matters.** Same cloud field at different speeds produces
   different Kv. Fast-moving broken clouds create higher Kv than slow-moving
   broken clouds at identical coverage. For classification (not quantification),
   this is a second-order effect.

2. **Cloud enhancement can confuse Km.** Under certain broken-cloud conditions,
   Kcs can briefly EXCEED 1.0 (more irradiance than clear sky) due to cloud-edge
   enhancement. Our 30-minute mean (Km) smooths most of these, but they can
   still push Km slightly above expected values.

3. **Aerosols affect Km but not Kv.** Haze, smoke, and aerosols reduce Km
   smoothly (like thin stratus) but don't create variability. This means
   moderate Km + low Kv could be either thin overcast OR aerosol/haze. For
   weather station purposes, both produce similar "hazy/overcast" conditions,
   so this conflation may be acceptable.

4. **Solar zenith angle effects.** At low sun angles, cloud optical path is
   longer, changing the relationship between Km and cloud optical depth. Our
   clear-sky normalization partially compensates, but edge cases at dawn/dusk
   remain challenging.

5. **Single-sensor limitation.** Pyranometer-based classification "sees" only
   clouds crossing the sun's path, not the whole sky. A cloud to the north on
   a summer day may never cross the sensor's relevant field of view. Duchon &
   O'Malley found only 45% agreement with human whole-sky observations.

### What the Literature Does NOT Provide

- **No universal Kv thresholds.** The absolute values of variability indices
  depend on measurement interval, window length, normalization method, and
  clear-sky model quality. Each system must calibrate its own thresholds.

- **No validated cloud FRACTION from variability.** While variability reliably
  distinguishes UNIFORM from BROKEN coverage, converting Kv to a specific
  cloud fraction (e.g., "60% coverage") is not established. The relationship
  is non-linear and depends on cloud size, speed, and geometry.

- **Limited validation for sub-30-minute windows.** Most published work uses
  daily or hourly aggregation. Our 30-minute rolling window at 1-minute
  resolution is at the shorter end of validated timescales, though CAELUS
  (Ruiz-Arias et al., 2023) operates at 1-minute resolution.


## 16. Ramp Rate Analysis and Cloud Shadow Speed

### Cloud Shadow Speed and Ramp Magnitude

From multiple sources (Lave & Kleissl 2013, Marcos et al. 2011, Nouri et al. 2024):

- Cloud shadow transit time across a pyranometer = cloud dimension / cloud speed
- Ramp rate (W/m^2/sec) = delta_GHI / transit_time
- Faster clouds = steeper ramps = higher Kv per cloud passage event
- More cloud passages per window = more ramps = higher cumulative Kv

### Marcos et al. (2011)

Marcos, J., Marroyo, L., Lorenzo, E., Alvira, D., & Izco, E. (2011). "From
irradiance to output power fluctuations: the PV plant as a low pass filter."
Progress in Photovoltaics, 19(5), 505-510.

Used 1-second data from six PV plants (18 MWp) over a full year. Each plant
acts as a first-order low-pass filter on irradiance fluctuations due to spatial
averaging. For a point sensor (our weather station), ALL fluctuations are
captured -- this is both a feature (maximum sensitivity to cloud transitions)
and a challenge (no spatial smoothing).

### Nouri et al. (2024)

Nouri, B., et al. (2024). "Ramp Rate Metric Suitable for Solar Forecasting."
Solar RRL.

Proposed an adapted ramp rate metric based on the derivative of normalized
irradiance values (i.e., clear-sky-index derivative, which is essentially
what our Kv computes).

### Key Insight for Our Implementation

Our Kv = sum of |d(kcs)/dt| over 30 minutes, where kcs = GHI/maxSolarRad.
This is a direct implementation of the cumulative normalized ramp rate concept.
The literature confirms this is a sound metric for capturing cloud-field
temporal characteristics.

Each ramp in the signal corresponds to a cloud edge crossing the sun-sensor
line of sight. The number of ramps in 30 minutes reflects how many cloud edges
pass. The magnitude of each ramp reflects cloud optical depth contrast (thin
edge = small ramp, thick edge = large ramp).

Total Kv = (number of cloud edges) x (average ramp magnitude)

This product naturally distinguishes:
- Uniform overcast (0 edges x anything = low Kv)
- Clear sky (0 edges x anything = low Kv)
- Broken cloud (many edges x moderate ramp = high Kv)
- Scattered thin cloud (some edges x small ramp = moderate Kv)


## 17. Complete Reference List

### Primary Sources (Directly Relevant)

1. Stein, J. S., Hansen, C. W., & Reno, M. J. (2012). The Variability Index. Sandia SAND2012-3464C.
2. Duchon, C. E., & O'Malley, M. S. (1999). Estimating Cloud Type from Pyranometer Observations. J. Appl. Meteor., 38(1), 132-141.
3. Ruiz-Arias, J. A., Gueymard, C. A., & Fernandez-Peruchena, C. M. (2023). CAELUS. Solar Energy, 263, 111895.
4. Mol, W., & van Heerwaarden, C. (2025). Mechanisms of SSI variability under broken clouds. ACP, 25, 4419-4441.
5. Mol, W., et al. (2024). Observed patterns of SSI under cloudy and clear-sky conditions. QJRMS, 150(761), 2338-2363.
6. Cheng, Z., et al. (2024). A Standardized Sky Condition Classification Method. Energies, 17(18), 4616.
7. Perez, R., et al. (2011). Parameterization of site-specific short-term irradiance variability. Solar Energy, 85(7), 1343-1353.
8. Lave, M., & Kleissl, J. (2013). Cloud speed impact on solar variability scaling. Solar Energy, 91, 11-21.
9. Lave, M., Reno, M. J., & Broderick, R. J. (2015). Characterizing local high-frequency solar variability. Solar Energy, 118, 327-337.
10. Inman, R. H., Pedro, H. T. C., & Coimbra, C. F. M. (2013). Solar Forecasting Methods. PECS, 39, 535-576.

### Secondary Sources (Supporting/Contextual)

11. Reno, M. J., & Hansen, C. W. (2016). Identification of clear sky periods. Renewable Energy, 90, 520-531.
12. Reno, M. J., Hansen, C. W., & Stein, J. S. (2012). GHI Clear Sky Models. Sandia SAND2012-2389.
13. Bright, J. M., et al. (2020). Bright-Sun clear-sky detection. RSER, 121, 109706.
14. Woyte, A., Belmans, R., & Nijs, J. (2007). Fluctuations in instantaneous clearness index. Solar Energy, 81(2), 195-206.
15. Marcos, J., et al. (2011). From irradiance to output power fluctuations. Prog. Photovolt., 19(5), 505-510.
16. Perez, R., et al. (2016). Spatial and Temporal Variability of Solar Energy. Found. Trends Renew. Energy, 1(1).
17. Marzouq, M., et al. (2020). A normalized variability index of daily solar radiation. AIP Conf. Proc., 2303.
18. Skartveit, A., & Olseth, J. A. (1992). Probability density and autocorrelation of short-term irradiance. Solar Energy, 49(6), 477-487.
19. Lusi, A. R., et al. (2024). Cloud classification through ML and GHI data analysis. QJRMS.
20. Chatterjee, D., Raabe, N., & Crewell, S. (2026). Four low-level cloud regimes. ML: Earth, 2(1).
21. Nouri, B., et al. (2024). Ramp Rate Metric Suitable for Solar Forecasting. Solar RRL.
22. Engerer2 separation model -- Bright, J. M., & Engerer, N. A. (2019). Global re-parameterisation. JRSE.


## 18. Bottom Line for Our Implementation

### What the Science Supports

1. **Using Kv (variability) to distinguish uniform from broken cloud cover is
   well-supported** by 25+ years of research, from Duchon & O'Malley (1999)
   through CAELUS (2023) and Mol & van Heerwaarden (2025).

2. **The combination of Km + Kv is the standard approach** in the field.
   Single-axis classification fails; two-axis classification works.

3. **Low Kv + moderate Km reliably indicates uniform thin overcast** (stratus,
   marine layer). This is the regime we were specifically looking for and it
   IS scientifically established.

4. **High Kv + moderate Km reliably indicates broken/scattered cloud.** This
   is the other key regime and is even more robustly established.

5. **Detrending by clear-sky reference (our maxSolarRad) is essential** and
   is standard practice (Coimbra et al., 2013; universal in the field).

### What We Should Be Cautious About

1. **Absolute Kv thresholds are not transferable** between systems. We need to
   calibrate against our own station's data (sensor characteristics, maxSolarRad
   model accuracy, measurement interval, window length).

2. **Cloud speed is a confounding variable** for Kv magnitude, though not for
   the binary "uniform vs. broken" classification.

3. **Low sun angle periods** (dawn/dusk, winter) may need different thresholds
   or should be excluded from classification.

4. **Our 30-minute window is appropriate** but at the shorter end of validated
   timescales. CAELUS validates 1-minute classification, which supports our
   approach.

5. **Single-sensor GHI classification sees only the sun's path**, not the
   whole sky dome. Agreement with visual whole-sky assessment is limited to
   ~45% (Duchon & O'Malley). This is an inherent limitation we must
   communicate in our sky condition display.
