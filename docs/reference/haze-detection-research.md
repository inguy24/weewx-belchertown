# Haze Detection PM Threshold Research

**Purpose:** Research backing for the PM2.5 and PM10 confirmation thresholds used in `haze_condition.py`. These thresholds are cited in `docs/manuals/API-MANUAL.md` §8 "Haze detection" and implemented in `weewx_clearskies_api/sse/haze_condition.py`.

**Created:** 2026-06-24

---

## 1. The Problem with the Previous Thresholds

The original implementation used PM2.5 > 12 µg/m³ as the dry-haze confirmation threshold. This value is the EPA AQI "Good/Moderate" breakpoint — a **health standard**, not a meteorological observation threshold.

No national meteorological service worldwide uses 12 µg/m³ as a haze observation criterion. The problem: at PM2.5 = 11–12 µg/m³ (EPA "Good" air quality), visibility is typically 20–50 km with no perceptible haze. Using a health standard as a haze detector caused false positives under clear conditions whenever air quality was merely "Moderate."

The previous PM10 > 50 µg/m³ threshold was also treated as a fallback (tried only when PM2.5 was unavailable), rather than an independent first-class indicator. This was architecturally incorrect — PM2.5 and PM10 measure different aerosol populations and either species alone can produce visible haze.

---

## 2. IMPROVE Extinction Physics

The IMPROVE (Interagency Monitoring of Protected Visual Environments) reconstructed extinction equation provides the physics-based framework for relating PM concentrations to visibility impairment.

**Revised IMPROVE equation (Pitchford & Malm 2007):**

```
bext ≈ 3×f(RH)×[Ammonium Sulfate]
     + 3×f(RH)×[Ammonium Nitrate]
     + 4×[Organic Mass]
     + 10×[Elemental Carbon]
     + 1×[Fine Soil]
     + 0.6×[Coarse Mass]
```

where bext is the total extinction coefficient (Mm⁻¹), f(RH) is the hygroscopic growth factor, and concentrations are in µg/m³.

**Mass extinction efficiencies:**

| Aerosol species | Extinction efficiency |
|-----------------|-----------------------|
| Fine particles (PM2.5 components: sulfate, nitrate, OC, EC) | 3–10 m²/g depending on species |
| Coarse particles (PM10 minus PM2.5: mineral dust, sea salt, pollen) | 0.6 m²/g |

The coarse-to-fine extinction efficiency ratio (~1:5 to 1:17) is why PM10 thresholds in the haze detector are set roughly 2x higher than PM2.5 thresholds: coarse particles need substantially more mass to produce equivalent light extinction. The exact scaling used (PM10 threshold ≈ 2× PM2.5 threshold) is conservative — the full IMPROVE ratio would support even higher PM10 thresholds, but 2x provides a safety margin and is consistent with WMO operational guidance.

**Key insight — both species are independent channels:** PM2.5 is dominated by combustion byproducts, photochemical smog, and secondary organic aerosol (high extinction efficiency). PM10 coarse fraction is dominated by mineral dust, sea salt, pollen, and wildfire ash (lower extinction efficiency but can reach very high mass concentrations in dust/smoke events). These are physically distinct aerosol populations. Either alone is sufficient to produce visible haze when present at sufficient concentration, and neither is a proxy for the other.

**Visibility relationship:** The Koschmieder equation relates bext to meteorological visibility:

```
V = 3.912 / bext
```

At bext ≈ 0.39 km⁻¹ (~390 Mm⁻¹), visibility = 10 km — the international definition of haze onset (WMO, CMA, NWS). Working backward via IMPROVE, fine PM2.5 at 50 µg/m³ in dry conditions produces bext in this range.

---

## 3. Multi-Tradition Threshold Survey

### 3.1 United States — NWS/ASOS

ASOS (Automated Surface Observing System) reports haze (METAR code HZ) when visibility < 7 statute miles (~11.3 km) and relative humidity is below the fog threshold. No PM concentration threshold is used — ASOS uses a visibility sensor (forward-scatter or transmissometer) directly.

NWS distinguishes haze from fog and mist primarily by RH: haze occurs at lower RH where water-droplet condensation has not occurred. The PM detection system in Clear Skies fills the gap for stations without a visibility sensor, using PM concentration as an aerosol-loading proxy.

- Threshold: vis < 7 mi (~11.3 km), no PM threshold
- Source: NWS Observing Handbook No. 8 (WSOH8)

### 3.2 China — CMA Operational Guidance

The China Meteorological Administration (CMA) provides the most extensively documented PM-to-haze threshold research, driven by China's severe haze episodes. CMA criteria are widely cited in peer-reviewed atmospheric science literature.

- **Haze definition:** visibility < 10 km AND relative humidity < 90%
- **PM2.5 threshold for vis < 10 km (dry, RH < 60%):** approximately 54 µg/m³ (hourly minimum, recommended by research on north China data; CMA operational guidance uses this range)
- **PM2.5 threshold at RH 70–80%:** drops to approximately 40 µg/m³ due to hygroscopic aerosol swelling
- **China secondary air quality standard:** 35 µg/m³ PM2.5 (used as a haze breakpoint in many CMA-aligned studies — at this level, visibility impairment is statistically significant in Chinese cities)
- **PM10 dusty air:** 50–200 µg/m³

The RH-graduated PM2.5 threshold (higher when dry, lower when humid) reflects the hygroscopic growth physics in the IMPROVE f(RH) term: at higher RH, aerosol particles absorb water vapor, increasing their effective size and light-scattering cross-section. Less dry-mass is needed to produce the same extinction.

### 3.3 Korea — KMA

The Korea Meteorological Administration defines haze as:

- Visibility < 10 km AND RH < 75%
- No specific PM concentration threshold in KMA operational criteria

KMA uses a stricter RH cutoff (75%) than CMA (90%), reflecting the Korean Peninsula's climate patterns.

### 3.4 Europe — EEA

The European Environment Agency does not define a meteorological haze observation threshold by PM concentration. EEA standards are health-based air quality limits:

- PM10 daily standard: 50 µg/m³ (EU Directive 2008/50/EC)
- PM2.5 annual standard: 25 µg/m³ (health standard, not haze observation)

The PM2.5 annual standard of 25 µg/m³ is used in Clear Skies as the lower bound for the humid-RH tier (80–90%) because hygroscopic swelling at high humidity means this mass concentration produces extinction comparable to 50 µg/m³ in dry air.

### 3.5 Australia — BOM

The Australian Bureau of Meteorology follows WMO protocols for haze observation. Australian air quality research uses:

- PM10 24-hour standard: 50 µg/m³ (NEPM ambient air quality standard)
- Dust haze: visibility < 10 km

Australian dust storm research (e.g., the September 2009 eastern Australia event, PM10 > 1000 µg/m³ in Sydney) provides extreme-case validation that PM10 is an independent, first-class haze indicator.

### 3.6 India — CPCB

The Central Pollution Control Board of India sets ambient air quality standards:

- PM10 24-hour standard: 100 µg/m³
- PM2.5 24-hour standard: 60 µg/m³

India's higher standards reflect the higher baseline aerosol loading in South Asian urban environments. These values inform the upper bound of the dry-tier thresholds.

### 3.7 WMO — International

The World Meteorological Organization defines:

- **Haze (present weather code 05):** visibility reduction due to suspended dry particles; visibility reduced but > 1 km
- **Dust haze:** visibility < 10 km with "dusty air," PM10 typically 50–200 µg/m³
- **Smoke haze:** similar visibility reduction, PM2.5 dominated

WMO distinguishes haze from fog by RH (haze occurs when RH is below saturation, fog requires near-saturation). WMO code 05 (haze) is the code emitted by the Clear Skies conditions text engine.

---

## 4. PM2.5 vs PM10 Independence

A critical architectural point: PM2.5 and PM10 are not interchangeable, and PM10 is not a fallback for when PM2.5 data is absent. They measure different aerosol populations:

| Species | Dominated by | Extinction efficiency | Typical haze context |
|---------|--------------|-----------------------|----------------------|
| PM2.5 (fine) | Combustion products, secondary organic aerosol, ammonium sulfate/nitrate | 3–10 m²/g | Urban smog, wildfire smoke, regional haze |
| PM10 coarse fraction (PM10 − PM2.5) | Mineral dust, sea salt, pollen, construction dust, volcanic ash | 0.6 m²/g | Dust storms, Saharan intrusions, construction events |

In the IMPROVE extinction equation, coarse mass has its own term (0.6 × [Coarse Mass]) independent of the fine-particle terms. The pyranometer Kcs deficit integrates total extinction from all aerosol species — when a station under a dust event has PM10 = 150 µg/m³ but PM2.5 = 20 µg/m³, the Kcs deficit channel fires on total aerosol extinction while PM10 alone confirms the aerosol loading. Requiring PM2.5 to exceed threshold in this case would produce a false negative.

The two-channel architecture (Channel 1: Kcs deficit, Channel 2: PM confirmation) requires either PM species to confirm the aerosol cause of the Kcs deficit. Either PM2.5 or PM10 alone is sufficient to confirm Channel 2.

---

## 5. Selected Thresholds — RH-Graduated Design

### Rationale for RH graduation

Channel 1 (Kcs deficit) and Channel 2 (PM confirmation) both involve humidity corrections, but for different physics:

- **Channel 1 f(RH):** Adjusts the Kcs-deficit threshold because humidity inflates the apparent Kcs gap even in clean air — the optical effect on the pyranometer.
- **Channel 2 RH graduation:** Adjusts how much particulate mass is needed to cause visible haze. At high humidity, aerosol particles absorb water vapor and swell (hygroscopic growth), scattering more light per gram of dry mass. Less dry PM mass is needed to achieve extinction equivalent to the dry-air case.

These are independent corrections for independent physical phenomena.

### Threshold table

| RH range | PM2.5 threshold | PM10 threshold | Research basis |
|----------|----------------|----------------|----------------|
| < 60% (dry) | > 50 µg/m³ | > 100 µg/m³ | CMA dry haze research (~54 µg/m³ PM2.5 for vis < 10 km in north China studies). PM10 scaled at ~2× PM2.5 per IMPROVE coarse/fine extinction ratio. |
| 60–80% (moderate) | > 35 µg/m³ | > 75 µg/m³ | CMA moderate-humidity threshold (~40 µg/m³), EPA 24-hr NAAQS (35 µg/m³), WMO dusty-air midpoint, China secondary air quality standard (35 µg/m³). |
| 80–90% (humid) | > 25 µg/m³ | > 50 µg/m³ | Hygroscopic swelling reduces the dry-mass threshold. EEA PM2.5 annual standard (25 µg/m³), WMO/Australia PM10 24-hr standard (50 µg/m³). |

**Note on the 80–90% upper bound:** RH > 90% defers entirely to fog/mist detection (ADR-069). The 80–90% tier handles the transition zone where hygroscopic enhancement is significant but condensation fog has not formed.

### What was removed: humid disambiguation (T-Td ≤ 4°F)

The previous design included a "humid disambiguation" check: PM2.5 > 35 µg/m³ when T-Td ≤ 4°F. This logic belongs in `fog_condition.py`, not `haze_condition.py`. The fog module already implements Gate 5: when T-Td ≤ 4°F AND PM2.5 > 35 µg/m³, it reports "Hazy" rather than "Foggy." Duplicating this gate in the haze module created redundancy and potential conflicts. The haze module handles RH < 90%; the fog module handles RH ≥ near-saturation.

---

## 6. Coherence Window

The temporal coherence filter was corrected from 15 minutes (900 s) to 5 minutes (300 s). This matches the sky classifier coherence window. The sky classifier already applies 30-minute Kv/Km averaging and an asymmetric Kv/Kvf gate that provide substantial smoothing; a 15-minute haze coherence filter stacked on top of that created up to 45 minutes of lag, which is unacceptable for a weather display. The 5-minute filter prevents label flicker without introducing excessive lag.

---

## 7. Source Citations

- **IMPROVE algorithm — extinction reconstruction:**
  https://vista.cira.colostate.edu/Improve/the-improve-algorithm/

- **Pitchford & Malm (2007) — Revised IMPROVE equation:**
  https://www.tandfonline.com/doi/full/10.1080/10962247.2016.1178187

- **PM2.5 threshold 54 µg/m³ for vis < 10 km — north China studies:**
  https://www.sciencedirect.com/science/article/abs/pii/S0169809520303574

- **Consistency between visibility and PM2.5 measurements:**
  https://pmc.ncbi.nlm.nih.gov/articles/PMC9861879/

- **Aerosol extinction reconstruction and haze identification — China:**
  https://aaqr.org/articles/aaqr-20-07-oa-0386

- **Sensitivity of visibility to PM2.5 and RH by aerosol type:**
  https://www.mdpi.com/2073-4433/13/3/471

- **NWS Observing Handbook No. 8 — ASOS haze criteria:**
  https://www.weather.gov/media/surface/WSOH8.pdf

- **EPA IMPROVE visibility analysis:**
  https://www.epa.gov/sites/default/files/2015-05/documents/chap01.pdf
