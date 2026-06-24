# Research: (Km, Kv) Regimes, Alternative Classification Schemes, and the Variability-First Hypothesis

**Date:** 2026-06-23
**Purpose:** Scientific backing for restructuring the sky condition decision tree with Kv (variability) as the PRIMARY discriminator for coverage pattern, and Km (mean transmittance) as the SECONDARY discriminator for cloud properties/thickness.

**Problem statement:** A marine layer covering 100% of sky but letting 60% of light through gets classified as "Partly Cloudy" or "Mostly Cloudy" instead of "Overcast" because the current engine over-relies on Km. The engine equates low transmittance with high coverage, which is wrong for thin uniform cloud layers.

---

## 1. The (Km, Kv) Regime Matrix — Physical Cloud Scenarios

This matrix maps combinations of mean transmittance (Km) and temporal variability (Kv) to the physical cloud scenarios that produce each regime. This is the core reference for understanding what the pyranometer "sees."

### 1.1 High Km (0.85–1.0) + Very Low Kv (< 0.03)

**Physical scenario:** Clear sky, no clouds. The pyranometer sees stable, high irradiance tracking the smooth solar geometry curve. GHI closely matches the clear-sky model output.

**CAELUS class:** CLOUDLESS (Km > 0.6, Kcs in [0.85, 1.15], Kv < 0.03).

**NWS equivalent:** Clear / Sunny (0 okta).

**Why Kv is near zero:** No clouds means no shadow transits. The only GHI variation is the deterministic solar geometry ramp (which we detrend away). After detrending, a clear sky produces Kv effectively at the noise floor of the sensor.

**Key insight:** This regime is UNIQUELY identified by high Km + low Kv. No other physical scenario produces this combination.

### 1.2 Moderate Km (0.5–0.85) + Very Low Kv (< 0.03)

**Physical scenario:** Thin uniform cloud layer covering 100% of sky — marine stratus, high fog, thin altostratus, or uniform cirrostratus. The cloud layer dims sunlight uniformly but does not break or vary. The pyranometer sees a smooth, reduced-intensity signal with no rapid fluctuations.

**THIS IS THE MARINE LAYER CASE.** A coastal marine layer typically transmits 50–70% of clear-sky GHI through a uniform deck of stratocumulus or stratus. Km reads 0.5–0.7. Kv reads near zero because the cloud layer is spatially homogeneous — there are no gaps, no breaks, no transiting cloud edges.

**Why the current engine fails here:** The current engine sees Km = 0.6 and classifies based primarily on Km ranges. K-C maps Km 0.6 to approximately 6 oktas (BKN), producing "Mostly Cloudy" or even "Partly Cloudy" depending on exact thresholds. But the physical sky is 8/8 overcast — the cloud fraction is 100%, it is just optically thin. The engine confuses optical thickness with sky coverage.

**What should happen:** The near-zero Kv indicates a UNIFORM sky — either clear or overcast. The moderate Km rules out clear sky. Therefore: this is a uniform overcast layer. The correct label is "Overcast" or "Cloudy" — a thin but complete cloud cover.

**Scientific basis:** Duchon & O'Malley (1999) identified stratus specifically as producing a low-variability, moderate-clearness signature: "the time series of irradiance from a pyranometer" under stratus shows smooth, reduced values compared to clear sky. Their classification placed stratus in a region of moderate mean clearness index and low standard deviation — distinct from cumulus (high variability) and distinct from clear sky (high clearness). Stratus's defining characteristic in the irradiance signal is its UNIFORMITY, not its opacity.

The Hyytiala classification algorithm (Manninen et al. 2020) uses "patchiness" (running standard deviation of scaled radiation) as a key discriminator alongside transmittance and cloud base height. Low patchiness indicates "uniformly overcast and clear-sky conditions," while patchiness "increases in partly cloudy conditions." The algorithm uses transmittance to distinguish between the two low-patchiness regimes (high transmittance = clear, low-to-moderate transmittance = uniform cloud).

### 1.3 Low Km (0.1–0.4) + Very Low Kv (< 0.03)

**Physical scenario:** Thick uniform overcast — nimbostratus, deep stratus, thick altostratus. Complete cloud cover with high optical depth. Very little solar radiation reaches the surface, and what does is purely diffuse. The signal is flat and dim.

**CAELUS class:** OVERCAST (Km < 0.3, Kv < 0.10).

**NWS equivalent:** Cloudy / Overcast / Heavy Overcast (8/8 okta).

**Why Kv is near zero:** Same physical reason as 1.2 — uniform coverage means no breaks or transits — but here the cloud is also optically thick. The combination of no gaps AND high opacity produces the lowest possible GHI with minimal variation.

**Key insight:** This regime and regime 1.2 share the property of very low Kv (uniform sky). They differ only in Km (how much light gets through). This is why Kv must be the primary discriminator: it tells you "uniform sky," and then Km tells you "how thick is the uniform layer."

### 1.4 High Km (0.85–1.0) + High Kv (> 0.08)

**Physical scenario:** Mostly clear sky with scattered cumulus clouds transiting the sun. The majority of the time, the sun is unobstructed (high mean clearness), but occasional cloud shadows produce sharp dips in GHI. These rapid transitions create high Kv.

When Kv and Kvf are both above 0.20 AND Kcs exceeds 1.06, CAELUS identifies this as CLOUD_ENHANCEMENT — cloud edges focus extra light toward the sensor, producing GHI spikes above clear-sky levels. This requires the sun to be visible with clouds nearby.

**CAELUS class:** SCATTER_CLOUDS (catch-all) or CLOUD_ENHANCEMENT.

**NWS equivalent:** Mostly Sunny / Scattered Clouds (1–3 okta) or Clear with nearby clouds (enhancement case).

**Why Kv is high:** Individual cumulus clouds crossing the sun produce rapid 30–60% drops in GHI lasting 2–5 minutes, followed by full restoration. Each transit generates a large absolute first-difference in the GHI signal, and these accumulate in the Kv integral.

### 1.5 Moderate Km (0.4–0.85) + High Kv (> 0.08)

**Physical scenario:** Broken cloud field — classic partly cloudy conditions. Significant periods of both sun and shadow, with frequent transitions. This is the regime of maximum variability (see Section 6).

Cloud types: fair-weather cumulus fields, broken stratocumulus, altocumulus with gaps.

**CAELUS classes:** SCATTER_CLOUDS (primary catch-all), THIN_CLOUDS (Km > 0.5, Kv 0.03–0.08), or THICK_CLOUDS (Km < 0.4, Kv 0.04–0.16).

**NWS equivalent:** Partly Cloudy to Mostly Cloudy (3–7 okta), depending on Km.

**Why Kv is high:** Roughly half the sky is covered, meaning roughly half of each 30-minute window has sun and half has shadow. This produces the maximum number of transitions (and therefore the maximum Kv) — see Section 6 for the inverted-U evidence.

### 1.6 Low Km (0.1–0.4) + High Kv (> 0.08)

**Physical scenario:** Heavy cloud cover with some breaks — thick broken cloud deck. Most of the time the pyranometer is under cloud shadow, but occasional breaks or thin spots allow brief bursts of higher irradiance. These bursts produce high variability against the low mean baseline.

Cloud types: breaking nimbostratus, post-frontal cumulus congestus, cumulonimbus with anvil gaps.

**CAELUS class:** THICK_CLOUDS (Km < 0.4, Kv 0.04–0.16) or SCATTER_CLOUDS.

**NWS equivalent:** Mostly Cloudy to Cloudy with breaks (6–7 okta).

**Key insight:** This regime is the mirror image of 1.4. In 1.4, mostly sun with occasional cloud shadows. In 1.6, mostly cloud with occasional sun breaks. Both produce high Kv, but Km distinguishes them. This is precisely the scenario where "Cloudy" (uniform thick) must be distinguished from "Mostly Cloudy" (thick but with breaks) — and Kv makes that distinction, not Km alone.

### 1.7 Summary Matrix

```
                           Kv (Variability)
                    Very Low (< 0.03)         High (> 0.08)
                 ┌─────────────────────────┬─────────────────────────┐
 High Km         │ 1.1 CLEAR SKY           │ 1.4 SCATTERED CUMULUS   │
 (0.85–1.0)      │ No clouds, smooth signal │ Mostly sun, cloud       │
                 │ → Clear / Sunny          │ transits, enhancement   │
                 │                          │ → Mostly Sunny,         │
                 │                          │   Scattered Clouds      │
                 ├─────────────────────────┼─────────────────────────┤
 Moderate Km     │ 1.2 THIN UNIFORM LAYER  │ 1.5 BROKEN CLOUD FIELD  │
 (0.5–0.85)      │ Marine stratus, thin     │ Classic partly cloudy   │
                 │ altostratus, cirrostratus│ Max variability regime  │
                 │ 100% coverage, thin      │ → Partly Cloudy         │
                 │ → OVERCAST (thin)        │                         │
                 ├─────────────────────────┼─────────────────────────┤
 Moderate-Low Km │ 1.2b MODERATE UNIFORM   │ 1.5b THICK BROKEN       │
 (0.4–0.5)       │ Thicker stratus,         │ Heavy cloud with gaps   │
                 │ stratocumulus deck       │ → Mostly Cloudy         │
                 │ → Overcast / Cloudy      │                         │
                 ├─────────────────────────┼─────────────────────────┤
 Low Km          │ 1.3 THICK UNIFORM LAYER │ 1.6 THICK BROKEN DECK   │
 (0.1–0.4)       │ Nimbostratus, deep       │ Heavy cloud, rare       │
                 │ stratus, thick overcast  │ breaks letting through  │
                 │ → Cloudy / Heavy         │ sun bursts              │
                 │   Overcast               │ → Mostly Cloudy         │
                 └─────────────────────────┴─────────────────────────┘
```

**The matrix reveals the fundamental principle:** The LEFT column (low Kv) contains UNIFORM skies — either clear or overcast. The RIGHT column (high Kv) contains BROKEN/VARIABLE skies — partly cloudy in various degrees. Kv is the primary discriminator for coverage PATTERN (uniform vs. broken). Km is the secondary discriminator for cloud PROPERTIES (thin vs. thick, or clear vs. cloudy within the uniform regime).

---

## 2. Existing Classification Schemes Using Both Transmittance and Variability

### 2.1 Duchon & O'Malley (1999) — The Original (Mean, σ) Classification

**Full citation:** Duchon, C.E. & O'Malley, M.S. (1999). Estimating cloud type from pyranometer observations. *Journal of Applied Meteorology*, 38(1), 132–141. DOI: 10.1175/1520-0450(1999)038<0132:ECTFPO>2.0.CO;2

**Method:** Uses a 21-minute running window over 1-minute GHI data. Computes two parameters:
1. Mean clearness index (ratio of observed irradiance to clear-sky irradiance)
2. Standard deviation of irradiance (after scaling to remove solar geometry trend)

**Seven cloud classes:** cirrus, cumulus, cirrus + cumulus, stratus, precipitation/fog, no clouds (clear), other clouds.

**Key findings relevant to our problem:**
- **Stratus is identified by moderate clearness + LOW standard deviation.** This is the critical finding. Duchon & O'Malley recognized that stratus produces a smooth, uniformly reduced irradiance signal. The standard deviation (their variability metric) separates stratus from cumulus — both can have similar mean clearness, but cumulus has high σ while stratus has low σ.
- The method uses BOTH parameters simultaneously to classify cloud types. Neither parameter alone is sufficient — a given mean clearness value can correspond to multiple cloud types depending on the variability.
- Agreement with human observations was about 45%, primarily because the pyranometer is weighted toward clouds crossing the sun's path while human observers see the whole sky dome.

**Relevance to our architecture:** Duchon & O'Malley's insight — that stratus and cumulus can produce similar mean clearness but are distinguished by variability — is the scientific foundation for using Kv as the primary discriminator. Their work predates CAELUS by 24 years and independently established that the (mean, variability) 2D space separates cloud types that cannot be separated by mean clearness alone.

### 2.2 Calbó, González & Pagès (2001) — Sky Condition Classification from Radiation

**Full citation:** Calbó, J., González, J-A., & Pagès, D. (2001). A method for sky-condition classification from ground-based solar radiation measurements. *Journal of Applied Meteorology and Climatology*, 40(12), 2193–2200. DOI: 10.1175/1520-0450(2001)040<2193:AMFSCC>2.0.CO;2

**Method:** Uses clearness index, diffuse fraction, and the short-term variability of GHI and diffuse radiation to classify sky conditions using supervised classification techniques. When the number of cloud classes was reduced from nine to five, the classifier reached 58% agreement with human-observed cloud classes.

**Five sky condition classes:** Overcast, fog/very thick, cloudy, partly cloudy, clear. The system uses variability parameters alongside the clearness index.

**Key finding:** The variability parameter "accounts for variations in the normalized clearness index within a time interval, taking minimum values when the clearness index is constant and maximum values when the clearness index shows large variability." This explicitly captures the uniform-vs-variable distinction that is the basis for the Kv-first approach.

**Relevance:** Calbó et al. (2001) independently confirmed Duchon & O'Malley's insight that variability is required alongside mean clearness for cloud classification. Their 5-class scheme maps closely to the NWS public forecast vocabulary, suggesting that a Kv-first classification naturally produces NWS-compatible output.

### 2.3 Pagès, Calbó & González (2003)

**Full citation:** Pagès, D., Calbó, J., & González, J-A. (2003). Using routine meteorological data to derive sky conditions. *Annales Geophysicae*, 21, 649–654. DOI: 10.5194/angeo-21-649-2003

This follow-up to Calbó et al. (2001) extended the methodology to use routine meteorological data for sky condition classification. The same clearness-index-plus-variability framework was applied, confirming the robustness of the two-parameter approach.

### 2.4 Heinle, Macke & Srivastav (2010) — All-Sky Imager Cloud Classification

**Full citation:** Heinle, A., Macke, A., & Srivastav, A. (2010). Automatic cloud classification of whole sky images. *Atmospheric Measurement Techniques*, 3, 557–567. DOI: 10.5194/amt-3-557-2010

**Method:** Uses a k-Nearest-Neighbor (kNN) classifier with 12 spectral and textural features extracted from whole-sky camera images. Classifies seven cloud types: cumulus, cirrus/cirrostratus, cirrocumulus/altocumulus, clear sky, stratocumulus, stratus/altostratus, cumulonimbus/nimbostratus.

**Relevance to our problem:** While this uses camera images rather than pyranometer data, it classifies the same physical cloud types we need to distinguish. The best-recognized classes were clear sky and cirrus. Stratus/altostratus were identified by their uniform texture (low image variance) — the visual analogue of low Kv. This confirms that uniformity/variability is a primary discriminator across measurement modalities (camera texture vs. irradiance variability).

### 2.5 Manninen et al. (2020) — Hyytiälä Cloud Classification (Radiation + CBH)

**Full citation:** Manninen, A.J., Marke, T., Tuononen, M., & O'Connor, E.J. (2020). Clouds over Hyytiälä, Finland: an algorithm to classify clouds based on solar radiation and cloud base height measurements. *Atmospheric Measurement Techniques*, 13, 5595–5619. DOI: 10.5194/amt-13-5595-2020

**Method:** Uses three parameters:
1. **Transmittance (TR):** ratio of measured GHI to modeled clear-sky GHI (equivalent to our Km)
2. **Patchiness (PA):** running standard deviation of scaled, measured GHI (equivalent to our Kv)
3. **Cloud Base Height (CBH):** from ceilometer

Classifies into nine primary cloud classes plus multilayered variants, including three multilayer sub-classes defined by uniformity:
- **Multilayer Uniform (MuUni):** uniform and thick cloud layers (stratus, nimbostratus)
- **Multilayer Transparent (MuTr):** uniform and transparent cloud layers (cirrostratus)
- **Multilayer Patchy (MuPa):** patchy clouds with varying transmittance (altocumulus)

**Critical finding for our problem:** Patchiness (variability) functions as a discriminator alongside transmittance. Low patchiness indicates "uniformly overcast and clear-sky conditions," while patchiness "increases in partly cloudy conditions." The algorithm uses transmittance to distinguish between the two low-patchiness regimes. This is EXACTLY the Kv-first architecture we are proposing.

**Performance:** 68.4% agreement with visual observations overall; 100% for nimbostratus (uniform thick cloud), 50% for cirriform clouds.

**SZA limitation:** Data filtered at solar zenith angle < 70 degrees for reliable pyranometer readings.

### 2.6 Lusi et al. (2024) — Machine Learning GHI Cloud Classification

**Full citation:** Lusi, M., et al. (2024). Cloud classification through machine learning and global horizontal irradiance data analysis. *Quarterly Journal of the Royal Meteorological Society*. DOI: 10.1002/qj.4880

**Method:** Uses machine learning (likely ensemble methods) applied to GHI-derived features for cloud classification. The features include clearness-index-based metrics and variability parameters.

**Relevance:** Modern ML approaches trained on GHI data independently discover that variability features are among the most important for distinguishing cloud types — confirming the physics-based intuition from Duchon & O'Malley (1999).

### 2.7 Kim et al. (2019) — Identifying Overcast, Partly Cloudy, and Clear Skies by Illuminance Fluctuations

**Full citation:** Kim, J.T., et al. (2019). Identifying overcast, partly cloudy and clear skies by illuminance fluctuations. *Renewable Energy*, 136, 1046–1054. DOI: 10.1016/j.renene.2019.01.076

**Method:** Classifies sky conditions by horizontal illuminance fluctuation frequency. The fundamental principle is that illuminance fluctuates at high frequency under broken clouds and varies smoothly under uniform conditions (clear or overcast).

**Key finding:** Using the fluctuation frequency factor alongside the clearness index reduces misclassification rates by 5.7% (daily) and 11.5% (half-day) compared to classifications using the clearness index only. This directly quantifies the improvement from adding variability to a transmittance-only classifier.

**Threshold approach:** Uses IDR (diffuse-to-direct irradiance ratio) thresholds of <= 0.35 for clear skies and >= 0.70 for overcast conditions, achieving 95% and 92% agreement respectively. However, the study notes that traditional metrics like standard deviation "fail to isolate stochastic fluctuations from deterministic trends in solar irradiance" — echoing our detrending requirement for Kv.

### 2.8 CAELUS (Ruiz-Arias & Gueymard 2023) — Our Current System

**Full citation:** Ruiz-Arias, J.A. & Gueymard, C.A. (2023). CAELUS: Classification of sky conditions from 1-min time series of global horizontal irradiance. *Solar Energy*, 263, 111895. DOI: 10.1016/j.solener.2023.111895

CAELUS uses BOTH Km and Kv (plus Kcs and Kvf) but does NOT structure the decision tree with Kv as the primary axis. The CAELUS decision order is:

1. Check for CLOUD_ENHANCEMENT (Kcs > 1.06, Kv > 0.20, Kvf > 0.20)
2. Check for CLOUDLESS (Km > 0.6, Kcs in [0.85, 1.15], Kv < 0.03)
3. Check for OVERCAST (Km < 0.3, Kv < 0.10)
4. Remaining → cloudy zone → THIN/THICK/SCATTER by Km and Kv ranges

**The problem:** CAELUS's OVERCAST anchor requires Km < 0.3. A thin uniform marine layer with Km = 0.6 does NOT match OVERCAST. It falls through to the "cloudy zone" where it becomes SCATTER_CLOUDS or THIN_CLOUDS — both mapped to partly cloudy labels. The marine layer case (moderate Km + very low Kv) is a gap in the CAELUS classification.

**Why this gap exists:** CAELUS was designed for solar energy applications (photovoltaic production estimation), not weather display. For solar production, a thin uniform layer at Km = 0.6 behaves more like "scattered clouds" than "overcast" because production is still 60% of clear-sky. CAELUS correctly classifies the PRODUCTION impact. But for weather DISPLAY, the human observer sees an overcast sky — they do not care that 60% of sunlight is getting through; they care that clouds cover the entire sky dome.

**This is the fundamental disconnect we need to resolve:** CAELUS's Km-first approach correctly classifies solar production impact but misclassifies sky coverage for weather display.

---

## 3. The Thin Uniform Stratus / Marine Layer Problem

### 3.1 Physical Characteristics of Marine Stratus

Marine stratus and stratocumulus are characterized by:
- **High cloud fraction:** typically 90–100% sky coverage
- **Moderate optical depth:** τ typically 5–20 (thinner than nimbostratus, thicker than cirrus)
- **Moderate transmittance:** Km typically 0.4–0.7 depending on optical depth
- **Very low variability:** Kv near zero because the cloud layer is spatially homogeneous
- **Low cloud base height:** typically 200–600 meters
- **Large horizontal extent:** marine stratus decks can extend for hundreds of kilometers

The key paradox for radiation-based classifiers: marine stratus produces MODERATE Km (not low enough to trigger overcast thresholds designed for nimbostratus) with VERY LOW Kv (no variability because coverage is 100%). Any classifier that equates "overcast" with "low Km" will misclassify marine stratus.

### 3.2 How Other Systems Handle This

**Duchon & O'Malley (1999):** Explicitly defined stratus as a separate cloud type with its own region in (mean, σ) space — moderate clearness, low standard deviation. They recognized the problem 27 years ago.

**Manninen et al. (2020):** Their "Multilayer Uniform" (MuUni) and "Multilayer Transparent" (MuTr) sub-classes explicitly address the thin-uniform-layer problem. MuUni captures thick uniform layers (stratus, nimbostratus) while MuTr captures thin uniform layers (cirrostratus). The key discriminator is patchiness (variability), not transmittance alone.

**NWS ASOS:** The Automated Surface Observing System uses ceilometer data (cloud base height and coverage) rather than radiation measurements. ASOS detects cloud layers by laser backscatter, so it correctly identifies a marine stratus layer regardless of optical depth. This is a fundamentally different measurement that does not suffer from the transmittance-coverage confusion.

**Human observers:** Trained weather observers look at the sky and assess coverage by what fraction of the sky dome is covered, regardless of how much light is getting through. A thin layer covering the entire sky is 8/8 overcast to a human observer. This is the standard we should match for weather display.

### 3.3 The Root Cause of the Misclassification

The root cause is that Km (transmittance) conflates two independent physical properties:
1. **Cloud coverage fraction:** what fraction of the sky has clouds
2. **Cloud optical depth:** how thick the clouds are

A Km value of 0.6 can result from:
- 100% coverage by a thin layer (τ ≈ 5) — OVERCAST
- 40% coverage by an opaque layer (τ > 50) — PARTLY CLOUDY
- 60% coverage by a moderate layer (τ ≈ 15) — MOSTLY CLOUDY

These three scenarios produce identical Km but very different Kv:
- The 100% coverage thin layer produces Kv ≈ 0 (uniform)
- The 40% coverage opaque layer produces high Kv (many sun-cloud transitions)
- The 60% coverage moderate layer produces high Kv (many transitions)

**Therefore: Kv disambiguates what Km cannot.** Low Kv + moderate Km = thin uniform overcast. High Kv + moderate Km = broken clouds (partly cloudy). This is the physical basis for the Kv-first architecture.

---

## 4. Practical Kv Thresholds for "Uniform" vs. "Variable" Sky

### 4.1 CAELUS Thresholds (Validated on 54 BSRN Stations)

From CAELUS `options.py`:
- **CLOUDLESS_MAX_KV = 0.03:** Kv below this threshold (with high Km and appropriate Kcs) indicates a clear sky. This is the most stringent uniformity threshold.
- **OVERCAST_MAX_KV = 0.10:** Kv below this threshold (with Km < 0.3) indicates thick uniform overcast. This is a relaxed threshold because thick overcast can have slight internal variation.
- **THIN_CLOUDS Kv range: 0.03–0.08:** Slight variability indicating thin cloud presence with some spatial inhomogeneity.
- **THICK_CLOUDS Kv range: 0.04–0.16:** Moderate variability from a thick cloud deck with breaks.
- **CLOUD_ENHANCEMENT_MIN_KV = 0.20:** High variability from rapid sun-cloud transitions near cloud edges.

### 4.2 Proposed Uniform/Variable Boundary

Based on the literature and CAELUS thresholds, the boundary between "genuinely uniform sky" and "variable sky showing cloud breaks" falls in the range **Kv = 0.03–0.05:**

- **Kv < 0.03:** Very uniform. After detrending, this level of variability is consistent with sensor noise on a clear day or a truly uniform cloud layer with no spatial variation. CAELUS uses this as the CLOUDLESS upper bound.
- **Kv 0.03–0.05:** Transition zone. Some slight variability may be present — could be thin cirrus, very slight cloud-edge effects, or a nearly-uniform layer with minor texture.
- **Kv > 0.05:** Clearly variable. Multiple cloud transits are occurring in the 30-minute window. The sky is NOT uniform.

**For our restructured decision tree, a Kv threshold of approximately 0.04–0.05 should separate "uniform sky" (overcast or clear, distinguished by Km) from "variable sky" (partly cloudy in various degrees, refined by Km).**

This is slightly above CAELUS's CLOUDLESS boundary (0.03) because we want to capture thin uniform layers that may have very slight texture without being truly "broken." It is below CAELUS's OVERCAST_MAX_KV (0.10) because we want the uniform/variable boundary to be tighter — 0.10 is too permissive and would include skies with obvious variability.

### 4.3 Supporting Evidence for the 0.03–0.05 Range

**Stein, Hansen & Reno (2012, Sandia SAND2012-3464C):** Defined the Variability Index as the ratio of measured GHI path length to clear-sky GHI path length. For clear-sky periods, this ratio approaches 1.0 (corresponding to Kv near zero). The authors found that clear-sky periods could be reliably identified when the variability index was below a threshold (exact value depends on time resolution and sensor noise characteristics, but was in the range of a few percent of the mean signal).

**Reno & Hansen (2016, Sandia):** In their clear-sky detection algorithm, they used variability (line length) as one of several criteria to identify clear-sky periods. Clear periods are characterized by smooth (low-variability) irradiance curves that closely track the clear-sky model. The algorithm uses the ratio of GHI "line length" (sum of absolute first-differences) to the clear-sky model line length, with values close to 1.0 indicating clear sky and higher values indicating cloud variability.

**Kim et al. (2019):** Found that adding fluctuation frequency to clearness-index-only classification reduced misclassification by 5.7–11.5%. The fluctuation analysis specifically distinguishes overcast from partly cloudy — both can have similar mean clearness, but overcast has low fluctuation frequency while partly cloudy has high frequency.

---

## 5. Cloud Fraction and GHI Variability — The Inverted-U Relationship

### 5.1 The Core Finding

**Multiple independent studies confirm that solar irradiance variability has a non-monotonic, inverted-U (or parabolic) relationship with cloud fraction:** variability is LOW at both extremes (clear sky and fully overcast) and reaches its MAXIMUM at intermediate cloud fractions around 50% sky coverage.

This is the single most important finding for justifying the Kv-first architecture. If variability is low at both 0% and 100% cloud cover, then:
- Low Kv → either clear or overcast (Km distinguishes)
- High Kv → intermediate cloud coverage (partly cloudy), with Km refining the exact degree

### 5.2 Evidence from Xie, Sengupta et al. (2021)

**Full citation:** Xie, Y., Sengupta, M., et al. (2021). Improving prediction of surface solar irradiance variability by integrating observed cloud characteristics and machine learning. *Solar Energy*, 226, 442–449. DOI: 10.1016/j.solener.2021.08.050

This study used a 5-year, 1-minute resolution observational dataset from the DOE ARM Southern Great Plains site. Two variability metrics were computed and related to cloud type and fractional sky cover (FSC).

**Key finding:** The nonlinear and non-monotonic relationship between solar variability and sky cover reveals that **both variability metrics are the highest around 50% sky cover** and lowest when the sky is almost clear or completely covered. This is direct quantitative evidence of the inverted-U relationship.

The study achieved R-squared = 0.42 using ensemble tree-based methods (Random Forest, Gradient Boosting) to predict variability from cloud type and FSC, confirming that cloud properties explain a significant fraction of irradiance variability.

### 5.3 Evidence from Mol et al. (2023, 2024)

**Full citation:** Mol, W.B., et al. (2023). Reconciling observations of solar irradiance variability with cloud size distributions. *Journal of Geophysical Research: Atmospheres*, 128, e2022JD037894. DOI: 10.1029/2022JD037894

Also: Mol, W.B., et al. (2024). Observed patterns of surface solar irradiance under cloudy and clear-sky conditions. *Quarterly Journal of the Royal Meteorological Society*, 150, 731. DOI: 10.1002/qj.4712

From the 2023 paper, deploying a spatial network of low-cost radiometers at field campaigns in Germany and Spain:
- **Clear skies** produce low variability due to consistent direct solar radiation
- **Overcast skies** also exhibit low variability because clouds create stable, uniform dimming
- **Partial cloud cover** generates high variability as clouds move and create rapid light-to-shadow transitions

The key conceptual finding: **low variability indicates either clear OR overcast conditions, not intermediate situations. Mean transmittance values then distinguish between these two scenarios** — high transmittance indicates clear skies, while low transmittance indicates overcast conditions.

Both peaks and shadows, and thus intra-day irradiance variability, are generated predominantly by boundary layer cloud fields of varying cloud fraction. Different cloud types (cumulus, altocumulus, cirrus) generate variability through different mechanisms and at different spatial scales (50 m to 30 km).

### 5.4 Evidence from Woyte, Belmans & Nijs (2007)

**Full citation:** Woyte, A., Belmans, R., & Nijs, J. (2007). Fluctuations in instantaneous clearness index: Analysis and statistics. *Solar Energy*, 81(2), 195–206. DOI: 10.1016/j.solener.2006.03.001

Analyzed the amplitude, persistence, and frequency of fluctuations in the clearness index using Haar wavelet decomposition. Defined a "fluctuation power index" (fpi) quantifying variability at specified timescales.

**Key finding:** The probability distribution of the instantaneous clearness index for a given mean clearness index is approximately independent of season and partly independent of site. This means the (mean, variability) relationship is a robust physical feature, not an artifact of any specific location or time of year.

The work confirms that mean clearness index alone has an inherent ambiguity — the same mean value can arise from very different clearness index probability distributions (e.g., bimodal distribution from sun-cloud oscillation vs. unimodal distribution from uniform thin cloud). The variability metric resolves this ambiguity.

### 5.5 Evidence from Perez et al. (2016)

**Full citation:** Perez, R., David, M., Hoff, T.E., Jamaly, M., Kivalov, S., Kleissl, J., Lauret, P., & Perez, M. (2016). Spatial and temporal variability of solar energy. *Foundations and Trends in Renewable Energy*, 1(1), 1–44. DOI: 10.1561/2700000006

Comprehensive review of spatial and temporal characteristics of solar resource variability. The work establishes that "mixed sky conditions exhibit significantly smaller spatial scales compared to overcast periods, resulting in frequent alternation between cloudy and clear-sky intervals and notably higher temporal variability in the clear sky index, opposed to more stable patterns under clear skies or overcast scenarios."

This confirms: clear = stable, overcast = stable, partly cloudy = highly variable. The variability signature directly maps to sky coverage pattern.

### 5.6 Evidence from Surface Irradiance Variability Under Broken Clouds (Mol et al. 2025)

**Full citation:** Mol, W.B., et al. (2025). Mechanisms of surface solar irradiance variability under broken clouds. *Atmospheric Chemistry and Physics*, 25, 4419–4437. DOI: 10.5194/acp-25-4419-2025

This study identified four distinct mechanisms driving surface solar irradiance variability under broken clouds:
1. **Forward escape:** Direct irradiance scattered forward by optically thin clouds (τ < 6)
2. **Downward escape:** Diffuse transmission through optically thick clouds (τ > 6)
3. **Side escape:** Radiation escaping from cloud sides in vertically structured clouds
4. **Albedo enhancement:** Multiple scattering between surface and cloud base (10–60% contribution)

**Key finding for our problem:** These mechanisms all require BREAKS in the cloud layer. At 100% cloud coverage, the mechanisms that produce variability (cloud-edge forward escape, side escape) cannot operate because there are no edges. This is the physical explanation for why variability drops to zero at 100% cloud fraction — there are no breaks for radiation enhancement or shadow-to-sun transitions to occur.

At 0% cloud fraction, no clouds exist, so no variability from cloud processes occurs.

At intermediate fractions, all four mechanisms operate simultaneously, producing maximum variability.

### 5.7 Synthesis: The Physical Basis for Kv-First Classification

The inverted-U relationship between cloud fraction and variability provides direct physical justification for using Kv as the PRIMARY discriminator:

```
Irradiance
Variability
  (Kv)
    │
    │                    ╱╲
    │                   ╱  ╲
    │                  ╱    ╲
    │                 ╱      ╲
    │                ╱        ╲
    │               ╱          ╲
    │              ╱            ╲
    │             ╱              ╲
    │            ╱                ╲
    │           ╱                  ╲
    │──────────╱                    ╲──────────
    └─────────────────────────────────────────→
    0%        25%       50%       75%      100%
              Cloud Fraction (Coverage)

    CLEAR     PARTLY     MAX       PARTLY   OVERCAST
              CLOUDY   VARIAB.    CLOUDY
```

- **Low Kv** corresponds to the LEFT side (clear, 0–15% cloud fraction) OR the RIGHT side (overcast, 85–100% cloud fraction) of the inverted U.
- **High Kv** corresponds to the MIDDLE of the curve (partly cloudy, 30–70% cloud fraction).
- **Km** then distinguishes LEFT from RIGHT within the low-Kv regime: high Km = clear, low/moderate Km = overcast.

This is not merely a design choice — it is a direct consequence of the physics of cloud-radiation interaction. The variability signal contains the coverage pattern information that the mean transmittance signal does not.

---

## 6. The Bimodal Clear-Sky Index Distribution

### 6.1 The Finding

**Full citation:** Bright, J.M., et al. (2017). Cloud cover effect of clear-sky index distributions and differences between human and automatic cloud observations. *Solar Energy*, 143, 110–117. DOI: 10.1016/j.solener.2016.12.046

This study established that the aggregated distribution of the clear-sky index is **bimodal**, with strong contributions from mostly-cloudy and mostly-clear hours (peaks near 0 and 1), and fewer intermediate-value hours. The distribution shape depends on okta (cloud cover amount) and solar elevation angle.

**At 0 okta (clear):** The distribution is unimodal with a sharp peak near clear-sky index = 1.0.
**At 8 okta (overcast):** The distribution is unimodal with a peak near clear-sky index values corresponding to the cloud's transmittance.
**At 4 okta (partly cloudy):** The distribution becomes bimodal — values oscillate between "in sun" (high clear-sky index) and "in shadow" (low clear-sky index).

### 6.2 Relevance to Our Problem

The bimodal distribution at intermediate cloud fractions is the CAUSE of high Kv. When the clear-sky index alternates between high and low values (bimodal distribution), the first-differences are large and frequent, producing high cumulative absolute deviation (high Kv).

At 0 okta and 8 okta, the distribution is unimodal — values cluster around a single mode. First-differences are small, producing low Kv.

**This is why Kv is a proxy for cloud fraction pattern:** it directly measures whether the irradiance distribution is unimodal (uniform sky) or bimodal (broken sky). The bimodal distribution is the signature of broken clouds creating sun-shadow oscillation.

A thin uniform marine layer at 8 okta with moderate optical depth produces a UNIMODAL distribution centered at a moderate clear-sky index value (say 0.6). Kv is low because there is only one mode — no oscillation. This is physically indistinguishable from a clear sky in terms of distribution SHAPE (both are unimodal), but distinguishable in terms of distribution LOCATION (where the mode sits on the clear-sky index axis, i.e., Km).

---

## 7. Proposed Decision Tree Architecture — Kv-First

Based on the research above, the scientifically justified decision tree structure is:

### Step 1: Kv — Is the sky UNIFORM or VARIABLE?

```
if Kv < UNIFORM_THRESHOLD (≈ 0.04):
    → UNIFORM SKY → go to Step 2a
else:
    → VARIABLE SKY → go to Step 2b
```

### Step 2a: Km — Is the uniform sky CLEAR or CLOUDY?

```
if Km > CLEAR_THRESHOLD (≈ 0.85) AND Kcs in [0.85, 1.15]:
    → CLEAR (cloudless)
    → Label: "Clear" / "Sunny"
elif Km > 0.65:
    → THIN UNIFORM OVERCAST (marine stratus, thin altostratus)
    → Label: "Overcast" (with qualifier "Thin" in data, not display)
elif Km > 0.40:
    → MODERATE UNIFORM OVERCAST (stratus, stratocumulus deck)
    → Label: "Overcast" or "Cloudy"
else:
    → THICK UNIFORM OVERCAST (nimbostratus, deep stratus)
    → Label: "Cloudy" or "Heavy Overcast"
```

### Step 2b: Km — How CLOUDY is the variable (broken) sky?

```
if Km > 0.85:
    → SCATTERED CUMULUS (mostly sun, few transits)
    → Label: "Mostly Sunny, Scattered Clouds"
elif Km > 0.52:
    → PARTLY CLOUDY (classic broken cloud field)
    → Label: "Partly Cloudy"
elif Km > 0.30:
    → MOSTLY CLOUDY (thick broken deck)
    → Label: "Mostly Cloudy"
else:
    → THICK BROKEN OVERCAST (heavy cloud, rare breaks)
    → Label: "Mostly Cloudy" or "Cloudy with breaks"
```

### Why This Structure Is Scientifically Justified

1. **Kv as primary:** The inverted-U relationship (Section 5) proves that Kv directly encodes the coverage pattern. Low Kv = extreme cloud fractions (0% or 100%). High Kv = intermediate fractions.

2. **Km as secondary in the uniform regime:** Within the low-Kv regime, Km distinguishes clear (high Km) from overcast (moderate/low Km). This is unambiguous because there are no breaks to confuse the mean signal.

3. **Km as secondary in the variable regime:** Within the high-Kv regime, Km indicates how cloudy the broken sky is. Higher Km = mostly sun with some cloud transits. Lower Km = mostly cloud with some breaks.

4. **Marine layer resolution:** A marine layer with Km = 0.6 and Kv ≈ 0.01 correctly falls into Step 2a → thin uniform overcast → "Overcast." Under the current Km-first system, it would fall into "Partly Cloudy" or "Mostly Cloudy."

### Differences from Current CAELUS Implementation

| Aspect | CAELUS (current) | Proposed Kv-first |
|---|---|---|
| Primary axis | Km (with Kcs anchors) | Kv (uniform vs. variable) |
| Marine layer (Km=0.6, Kv≈0) | SCATTER_CLOUDS → "Partly Cloudy" | Uniform → moderate Km → "Overcast" |
| Thin altostratus (Km=0.7, Kv≈0) | THIN_CLOUDS → "Mostly Clear" | Uniform → moderate-high Km → "Overcast" |
| CLOUD_ENHANCEMENT | Checked first (anchor) | Still checked first (Kcs > 1.06 is unambiguous) |
| CLOUDLESS | Km > 0.6 + Kcs + Kv | Kv < threshold + Km > 0.85 + Kcs |
| OVERCAST | Km < 0.3 only | Kv < threshold + Km < 0.65 (any thickness) |

---

## 8. Limitations and Open Questions

### 8.1 CAELUS Validation

CAELUS was validated on 54 BSRN stations. The proposed Kv-first restructuring has NOT been validated on the same scale. The thresholds proposed here (UNIFORM_THRESHOLD ≈ 0.04, Km boundaries within the uniform regime) are based on physical reasoning and the literature but need empirical tuning.

### 8.2 The Transition Zone (Kv 0.03–0.06)

The boundary between "uniform" and "variable" is not sharp. Thin cirrus, for example, can produce very slight variability (Kv 0.03–0.05) that is not clearly "broken" or "uniform." The transition zone needs careful handling — possibly with a hysteresis or persistence requirement.

### 8.3 Cloud Enhancement

CLOUD_ENHANCEMENT (Kcs > 1.06) should remain as a pre-check before the Kv-first logic, since it is identified by a unique signal (GHI exceeding clear-sky) that is independent of the uniform/variable axis.

### 8.4 SZA Effects

At high solar zenith angles (low elevation), Kv may be suppressed even under broken clouds because the absolute magnitude of GHI changes is small. The SZA guard at 85 degrees (5 degrees elevation) mitigates this, but the transition zone (5–15 degrees elevation) may need attention.

### 8.5 Consumer Sensor Noise

Consumer-grade pyranometers (Davis VP2, Ambient WS-5000) have higher noise floors than BSRN-grade instruments. The UNIFORM_THRESHOLD may need to be set higher (0.04–0.06 instead of 0.03) to account for sensor noise that could masquerade as cloud variability.

---

## Full Reference List

1. Bright, J.M., et al. (2017). Cloud cover effect of clear-sky index distributions and differences between human and automatic cloud observations. *Solar Energy*, 143, 110–117. DOI: 10.1016/j.solener.2016.12.046

2. Calbó, J., González, J-A., & Pagès, D. (2001). A method for sky-condition classification from ground-based solar radiation measurements. *Journal of Applied Meteorology and Climatology*, 40(12), 2193–2200. DOI: 10.1175/1520-0450(2001)040<2193:AMFSCC>2.0.CO;2

3. Duchon, C.E. & O'Malley, M.S. (1999). Estimating cloud type from pyranometer observations. *Journal of Applied Meteorology*, 38(1), 132–141. DOI: 10.1175/1520-0450(1999)038<0132:ECTFPO>2.0.CO;2

4. Heinle, A., Macke, A., & Srivastav, A. (2010). Automatic cloud classification of whole sky images. *Atmospheric Measurement Techniques*, 3, 557–567. DOI: 10.5194/amt-3-557-2010

5. Kim, J.T., et al. (2019). Identifying overcast, partly cloudy and clear skies by illuminance fluctuations. *Renewable Energy*, 136, 1046–1054. DOI: 10.1016/j.renene.2019.01.076

6. Lusi, M., et al. (2024). Cloud classification through machine learning and global horizontal irradiance data analysis. *Quarterly Journal of the Royal Meteorological Society*. DOI: 10.1002/qj.4880

7. Manninen, A.J., Marke, T., Tuononen, M., & O'Connor, E.J. (2020). Clouds over Hyytiälä, Finland: an algorithm to classify clouds based on solar radiation and cloud base height measurements. *Atmospheric Measurement Techniques*, 13, 5595–5619. DOI: 10.5194/amt-13-5595-2020

8. Mol, W.B., et al. (2023). Reconciling observations of solar irradiance variability with cloud size distributions. *Journal of Geophysical Research: Atmospheres*, 128, e2022JD037894. DOI: 10.1029/2022JD037894

9. Mol, W.B., et al. (2024). Observed patterns of surface solar irradiance under cloudy and clear-sky conditions. *Quarterly Journal of the Royal Meteorological Society*, 150, 731. DOI: 10.1002/qj.4712

10. Mol, W.B., et al. (2025). Mechanisms of surface solar irradiance variability under broken clouds. *Atmospheric Chemistry and Physics*, 25, 4419–4437. DOI: 10.5194/acp-25-4419-2025

11. Pagès, D., Calbó, J., & González, J-A. (2003). Using routine meteorological data to derive sky conditions. *Annales Geophysicae*, 21, 649–654. DOI: 10.5194/angeo-21-649-2003

12. Perez, R., David, M., Hoff, T.E., et al. (2016). Spatial and temporal variability of solar energy. *Foundations and Trends in Renewable Energy*, 1(1), 1–44. DOI: 10.1561/2700000006

13. Perez, R., Ineichen, P., Seals, R., & Zelenka, A. (1990). Making full use of the clearness index for parameterizing hourly insolation conditions. *Solar Energy*, 45(2), 111–114. DOI: 10.1016/0038-092X(90)90036-C

14. Reno, M.J. & Hansen, C.W. (2016). Identification of periods of clear sky irradiance in time series of GHI measurements. *Renewable Energy*, 90, 520–531. DOI: 10.1016/j.renene.2015.12.031

15. Reno, M.J., Hansen, C.W., & Stein, J.S. (2012). Global horizontal irradiance clear sky models: Implementation and analysis. Sandia National Laboratories, SAND2012-2389.

16. Ruiz-Arias, J.A. & Gueymard, C.A. (2023). CAELUS: Classification of sky conditions from 1-min time series of global horizontal irradiance. *Solar Energy*, 263, 111895. DOI: 10.1016/j.solener.2023.111895

17. Stein, J.S., Hansen, C.W., & Reno, M.J. (2012). The Variability Index: A new and novel metric for quantifying irradiance and PV output variability. Sandia National Laboratories, SAND2012-3464C. *World Renewable Energy Forum*, Denver, CO.

18. Woyte, A., Belmans, R., & Nijs, J. (2007). Fluctuations in instantaneous clearness index: Analysis and statistics. *Solar Energy*, 81(2), 195–206. DOI: 10.1016/j.solener.2006.03.001

19. Xie, Y., Sengupta, M., et al. (2021). Improving prediction of surface solar irradiance variability by integrating observed cloud characteristics and machine learning. *Solar Energy*, 226, 442–449. DOI: 10.1016/j.solener.2021.08.050
