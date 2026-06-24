# Sky Condition Definitions: NWS, WMO, FAA, and Perceptual Analysis

Research dump — compiled 2026-06-23 from official NWS documentation, WMO guides,
FAA aviation weather resources, AMS glossary, and published meteorological literature.

---

## 1. Official Sky Condition Hierarchy

Sky condition describes the fraction of the celestial dome covered by **opaque** (not
transparent) clouds, as estimated by a human observer or computed by an automated
system. The key word is "opaque" — thin, transparent clouds (e.g., wispy cirrus you
can see blue sky through) do not count toward sky condition in NWS public forecasts.

Source: NWS Glossary defines sky condition as "the predominant/average sky condition
based upon octants (eighths) of the sky covered by **opaque (not transparent)** clouds."
[NWS Glossary — Sky Condition](https://forecast.weather.gov/glossary.php?word=sky+condition)

### 1.1 METAR/Aviation Categories (Oktas)

These are the international aviation weather categories used in METAR and SPECI reports,
measured in oktas (eighths of the sky dome):

| Code | Name      | Oktas | Approx. % | Ceiling? |
|------|-----------|-------|-----------|----------|
| SKC  | Sky Clear | 0/8   | 0%        | No       |
| CLR  | Clear     | 0/8   | 0%        | No (automated stations, no cloud below 12,000 ft) |
| FEW  | Few       | 1-2/8 | 1-25%     | No       |
| SCT  | Scattered | 3-4/8 | 26-50%    | No       |
| BKN  | Broken    | 5-7/8 | 51-87%    | **Yes** — lowest BKN or OVC layer defines ceiling |
| OVC  | Overcast  | 8/8   | 88-100%   | **Yes**  |
| VV   | Vertical Visibility | Sky obscured | N/A | **Yes** — reported as VVhhh |

Sources:
- [METAR Help — College of DuPage](https://weather.cod.edu/notes/metar.html)
- [UBC ATSC 113 — Cloud Coverage](https://www.eoas.ubc.ca/courses/atsc113/flying/met_concepts/01-met_concepts/01c-cloud_coverage/index.html)

**Important:** SKC is used by human observers to mean "sky clear, no clouds observed."
CLR is used by automated stations (ASOS/AWOS) to mean "no clouds detected at or below
12,000 feet" — there might be clouds above that the ceilometer cannot detect.

### 1.2 NWS Public Forecast Categories

The NWS maps the okta-based observations to plain-language terms for public forecasts.
However, there are **discrepancies between different NWS offices** on the exact
thresholds. This is itself a notable finding — the boundaries are not as crisp as
they appear.

#### Variant A: NWS Glossary (authoritative)

From the official NWS glossary at forecast.weather.gov:

| Public Term                          | Oktas |
|--------------------------------------|-------|
| Clear / Sunny                        | 0/8   |
| Mostly Clear / Mostly Sunny          | 1/8 to 2/8 |
| Partly Cloudy / Partly Sunny         | 3/8 to 4/8 |
| Mostly Cloudy / Considerable Cloudiness | 5/8 to 7/8 |
| Cloudy                               | 8/8   |

Source: [NWS Glossary — Sky Condition](https://forecast.weather.gov/glossary.php?word=sky+condition)

#### Variant B: NWS Binghamton / Pittsburgh offices

| Public Term                          | Oktas |
|--------------------------------------|-------|
| Clear / Sunny                        | ≤ 1/8 |
| Mostly Clear / Mostly Sunny          | 1/8 to 3/8 |
| Partly Cloudy / Partly Sunny         | 3/8 to 5/8 |
| Mostly Cloudy                        | 5/8 to 7/8 |
| Cloudy                               | 7/8 to 8/8 |

Sources:
- [NWS Binghamton — Forecast Terms](https://www.weather.gov/bgm/forecast_terms)
- [NWS Pittsburgh — Forecast Terms](https://www.weather.gov/ppg/forecast_terms)

#### Variant C: NWS Huntsville

| Public Term                          | Oktas |
|--------------------------------------|-------|
| Clear / Sunny                        | 0/8   |
| Mostly Clear / Mostly Sunny          | 1/8 to 2/8 |
| Partly Cloudy / Partly Sunny         | 3/8 to 5/8 |
| Mostly Cloudy                        | 6/8 to 7/8 |
| Cloudy                               | 8/8   |

Source: [NWS Huntsville — ZFP Terminology](https://www.weather.gov/hun/zfp_terminology)

#### Variant D: NWS Phoenix ("Did You Know?" — uses tenths)

| Public Term       | Tenths |
|-------------------|--------|
| Clear             | 0-1/10 |
| Partly Cloudy     | 3-6/10 |
| Cloudy            | 9-10/10 |

Source: [NWS Phoenix — Did You Know?](https://www.weather.gov/psr/didyouknow)

#### Variant E: UW–Madison Weather Guys (AMS-affiliated)

| Public Term                          | Oktas |
|--------------------------------------|-------|
| Mostly Clear / Mostly Sunny          | 1-3 oktas |
| Partly Cloudy / Partly Sunny         | 3-5 oktas |
| Mostly Cloudy                        | 5-7 oktas |

Source: [The Weather Guys — Is there any difference between 'partly cloudy' and 'partly sunny'?](https://wxguys.ssec.wisc.edu/2024/01/08/cloud-cover/)

#### Reconciliation

The boundaries at 3/8 and 5/8 are fuzzy across sources. The NWS does not appear to
enforce a single rigid mapping; individual forecast offices have slight variations.
The *general* pattern that is consistent across all sources:

| Rough consensus                      | Oktas  | Approx. % |
|--------------------------------------|--------|-----------|
| Clear / Sunny                        | 0      | 0%        |
| Mostly Clear / Mostly Sunny          | ~1-2   | ~1-25%    |
| Partly Cloudy / Partly Sunny         | ~3-4   | ~26-50%   |
| Mostly Cloudy                        | ~5-7   | ~51-87%   |
| Cloudy                               | ~7-8   | ~87-100%  |

The disagreement is mainly at the transition points (does 1/8 count as "clear" or
"mostly clear"? Does 5/8 count as "partly cloudy" or "mostly cloudy"?). The interiors
of the ranges are consistent.

### 1.3 Day vs. Night Terminology

- "Sunny" and "Mostly Sunny" and "Partly Sunny" are **daytime-only** terms.
- At night, the equivalents are "Clear," "Mostly Clear," and "Partly Cloudy."
- "Mostly Cloudy" and "Cloudy" are used for both day and night.

"Partly sunny cannot be used in reporting nighttime conditions." — [Weather Guys](https://wxguys.ssec.wisc.edu/2024/01/08/cloud-cover/)

### 1.4 "Fair"

The NWS glossary defines "Fair" (mainly used at night) as: less than 4/10 opaque
cloud coverage, no precipitation, no extreme visibility/temperature/wind conditions.
It is a composite descriptor — not just a sky condition but a general weather state.

---

## 2. "Cloudy" vs. "Overcast" — Meteorological and Perceptual Distinction

This is the central question: are "cloudy" (87-100% in public forecasts) and "overcast"
(8/8 oktas in METAR) the same thing?

### 2.1 Terminological Distinction

**"Overcast" is an aviation/observation term.** It means exactly 8/8 oktas — every
eighth of the sky dome is covered by cloud. No gaps. No blue sky visible. This is
what a METAR reports as OVC.

**"Cloudy" is a public forecast term.** It covers approximately 7/8 to 8/8 oktas
(87-100%). This means "cloudy" includes BOTH 7/8 (broken, with small gaps) AND 8/8
(truly overcast, no gaps). The NWS glossary lists "Cloudy" at exactly 8/8, but other
NWS offices define it as 7/8 to 8/8 — acknowledging that from the public's perspective,
a sky that is 7/8 covered looks "cloudy."

**Key finding:** "Overcast" is a subset of "cloudy." All overcast conditions are cloudy,
but not all cloudy conditions are overcast. A sky at 7/8 coverage (broken) can still
be called "cloudy" in a public forecast but would be reported as BKN (broken) in a
METAR, not OVC (overcast).

### 2.2 What Does a Person Actually See?

**At 7/8 (broken / "cloudy"):** The sky is predominantly cloud-covered. Occasional
small gaps reveal blue sky or stars. The sun may briefly appear through gaps but is
mostly obscured. Shadows are mostly absent or diffuse, with brief sharp shadows when
the sun peeks through. The overall visual impression is "covered" but with noticeable
variation — you can tell that there are gaps even if they're small.

**At 8/8 (overcast):** Zero gaps. Uniform cloud cover. No blue sky visible anywhere.
The visual character depends heavily on cloud type:

- **Low stratus/nimbostratus (typical "gray day"):** Uniform, featureless gray.
  No texture, no sun position discernible. Flat, diffuse light from all directions.
  This is what most people picture when they think "overcast."

- **High altostratus/cirrostratus:** More textured, somewhat brighter. The sun's
  position may be discernible as a bright spot (especially through altostratus
  translucidus). Light is softer and more diffuse than clear sky but clearly
  brighter than low stratus overcast.

- **Stratocumulus:** Textured, with visible cellular structure. Still 8/8 coverage
  but with perceptible variation in thickness. Some patches lighter than others.
  The "quilt" or "cobblestone" appearance.

Source on luminance distribution: "The overcast sky has a general luminance
distribution that is about three times brighter at the zenith than at the horizon."
This is the CIE standard overcast sky model used in daylighting calculations.

### 2.3 Perceptual Difference Between 88% and 100%

**Yes, there is a meaningful visual difference**, but it is subtle and weather-dependent:

- At 88% (7/8, broken): fleeting patches of blue are visible; the sun may briefly
  appear; there is a sense of "almost covered but not quite." Shadows occasionally
  appear and vanish.

- At 100% (8/8, overcast): complete uniformity. No blue patches. No direct sun.
  The light is entirely diffuse. The psychological impression is distinctly different
  — the sky feels like a "lid."

The distinction matters more in some cloud regimes than others. A high thin
altostratus at 8/8 may look and feel quite different from a low thick stratus at 8/8,
even though both are "overcast" by definition. The coverage fraction tells you about
spatial extent; it tells you nothing about optical depth, brightness, or the
character of the light reaching the ground.

---

## 3. How Meteorologists Determine Sky Coverage

### 3.1 Human Observers

**Method:** The observer stands outdoors and mentally divides the visible sky dome into
eight equal sectors (oktas). They estimate how many of those sectors contain cloud.
The observation is of the **entire visible dome**, not just overhead.

**Key rules (from FMH-1 and FAA Order 7900.5E):**

1. **All cloud layers are treated as opaque for reporting purposes.** Even if you can
   see through a thin cirrus layer, when evaluating sky cover for METAR, that layer
   is counted at its coverage amount (FEW, SCT, BKN, OVC) as if it were opaque.

2. **Summation principle:** The sky cover for each layer is the sum of that layer's
   coverage plus all lower layers' coverage, but the total cannot exceed 8/8.
   "Portions of layers aloft detected through lower layers aloft [do] not increase
   the summation amount of the higher layer."

3. **Conservative approach:** Observers assume that any visible mid- or high-altitude
   clouds exist even behind lower cloud layers they cannot see through. This
   systematically overestimates coverage.

4. **How to distinguish 6/8 from 8/8:** At 6/8 (broken), the observer can clearly
   identify 2/8 worth of clear sky gaps. At 7/8, only 1/8 of clear sky is visible.
   At 8/8, no clear sky is visible at all. The practical judgment call is at the
   7/8 vs 8/8 boundary — is there ANY visible gap? Even a sliver? If yes: 7/8
   (BKN). If no: 8/8 (OVC).

Source: [UBC ATSC 113](https://www.eoas.ubc.ca/courses/atsc113/flying/met_concepts/01-met_concepts/01c-cloud_coverage/index.html) — "Weather observers use a conservative approach to avoid underestimating coverage."

**Observation skill:** Trained human observers are surprisingly accurate. Research
shows that "irradiation values corresponding to human observations of 'cloudless'
skies tend to agree better with theoretical clear-sky values than irradiation values
corresponding to automated observations." Humans outperform ceilometers for
instantaneous sky-dome assessment because they see the entire dome at once.

### 3.2 Ceilometers (ASOS/AWOS)

**How it works:** A vertically-pointed laser (typical range: up to 12,000 ft for ASOS)
fires pulses upward. Cloud base height is determined from the return time of the
reflected pulse. The sensor samples every 30 seconds.

**Coverage computation:** The ASOS software accumulates 30-second samples over a
time-weighted 30-minute window (the last 10 minutes weighted 2x). Coverage is
computed as the ratio of "cloud hits" to "possible hits" for each detected layer.
Up to three cloud layers are reported per observation.

**Fundamental limitation:** A ceilometer sees only the narrow column directly above it.
It relies on **wind carrying different parts of the cloud field over the sensor** to
build a picture of the sky. This is a temporal-to-spatial conversion — it works well
when the wind is steady and the cloud field is moving, but poorly for:

- Stationary clouds (the same patch stays overhead)
- Very low wind speeds
- Rapidly evolving cloud fields

**Accuracy:** The ampycloud algorithm (2024 study) achieved 87.7% ceiling detection
agreement with human-validated METARs, with "systematic underestimation of coverage
in stationary cloud situations."

**Night advantage:** "Cloud layers in the 1-2 okta range are systematically more
difficult to observe at night for human observers, which is not the case for
ceilometers." Ceilometers do not depend on visible light and perform equally well
day and night.

Sources:
- [NWS ASOS Ceilometer](https://www.weather.gov/asos/Ceilometer.html)
- [ampycloud algorithm paper — AMT, 2024](https://amt.copernicus.org/articles/17/4891/2024/)
- [EPA analysis of ASOS effects on climate record](https://www.epa.gov/sites/default/files/2020-10/documents/asos.pdf)

### 3.3 Satellite

Satellites observe cloud cover from above, measuring cloud-top reflectance and
temperature. This is a "narrow field of view" measurement per pixel, composited
over area. It sees the entire horizontal extent but cannot easily distinguish
multiple layers or determine coverage from the ground observer's perspective.
The conversion between satellite-observed cloud fraction and surface-observed
oktas is non-trivial — "while idealized procedures exist to convert between these
perspectives, empirical estimates are typically lacking." (Wikipedia, Cloud Cover)

### 3.4 All-Sky Imagers

Ground-based cameras with fisheye lenses capture the entire sky dome. Software
classifies pixels as cloud/clear. These can distinguish opaque from thin clouds
and compute both total and opaque coverage separately. They are primarily research
instruments, not standard observation infrastructure.

---

## 4. Marine Layer / Stratus Classification

### 4.1 What Is a Marine Layer?

Marine layer clouds are low-altitude stratus clouds that form when cool, moist
ocean air advects inland under stable conditions. They typically:

- Extend horizontally over 10-100+ km
- Are relatively shallow: 500-2000 meters thick
- Have a horizontally uniform base and top
- Form below a subsidence inversion (a temperature inversion that acts as a "lid")
- Reach maximum extent near sunrise, dissipate during the day

Source: [NWS Houston — Marine Layer Clouds](https://www.weather.gov/source/zhu/ZHU_Training_Page/clouds/stratus_form_dissipate/Marine_Layer.html)

### 4.2 How Is a Marine Layer Classified for Sky Condition?

**By coverage fraction, not by optical depth or cloud type.** If a marine stratus
deck covers 8/8 of the sky dome with no gaps, it is classified as OVC (overcast)
in METAR and "Cloudy" in public forecasts, regardless of how thin the layer is.

**There is no distinction in sky condition reporting based on cloud transparency or
optical depth.** A thin stratus deck that covers 100% of the sky but allows
significant light through is classified exactly the same as a thick nimbostratus
deck that blocks nearly all light. Both are OVC / 8/8 / Cloudy.

This is because:

1. **METAR treats all layers as opaque for sky condition reporting.** FMH-1 states:
   "All cloud layers and obscurations shall be considered as opaque." There is no
   provision for reporting "thin overcast" in the sky condition field.

2. **NWS public forecasts are based on opaque cloud cover.** However, the definition
   of "opaque" in practice means "you can see that cloud is there" — even a thin
   cirrus sheet that covers the whole sky counts as 8/8 because you can see it,
   even if you can also see blue sky dimly through it.

3. **The WMO cloud type system handles the "how thick" question separately.** Cloud
   types are reported in SYNOP and METAR independently of sky cover amount. A
   trained observer or satellite product can identify the cloud as "stratus
   translucidus" (thin, semi-transparent stratus) vs "stratus opacus" (thick,
   opaque stratus). But this distinction does not change the sky cover amount
   from 8/8.

### 4.3 Practical Implication

A common coastal scenario: a thin marine stratus deck covers 100% of the sky at
sunrise. It is clearly bright — you can discern the sun's position through it, and
ground-level illumination is high. By any formal definition, this is "overcast"
(8/8 coverage) and would be reported as such. Yet the visual impression and solar
energy reaching the ground may be closer to "partly cloudy" conditions with thicker
clouds.

**This is the gap in the sky condition system:** coverage fraction is a spatial
measure (how much of the dome is covered), not a radiometric measure (how much
energy gets through). The two are correlated but not equivalent.

---

## 5. Sky Coverage Fraction vs. Solar Transmittance

### 5.1 The Fundamental Disconnect

Sky coverage fraction and solar transmittance (GHI reaching the ground as a fraction
of clear-sky GHI) are **different quantities that are only loosely correlated.**

- **Sky coverage** is geometric: what fraction of the sky dome has cloud in it?
- **Solar transmittance** is radiometric: what fraction of clear-sky solar energy
  reaches the ground?

A sky can be 8/8 overcast (complete coverage) and still have high transmittance if
the clouds are optically thin. Conversely, a sky can be 4/8 scattered and have very
low transmittance if a thick cumulonimbus covers the solar disk.

### 5.2 Cloud Modification Factor (CMF) Research

The Cloud Modification Factor (CMF) is the ratio of measured GHI to modeled clear-sky
GHI. Published research establishes:

| Cloud Condition | Mean CMF | Mean Transmittance |
|----------------|----------|-------------------|
| Clear sky      | 0.992    | ~0.99             |
| Thin clouds    | —        | ~0.76             |
| Scattered      | 0.896    | ~0.90             |
| Broken         | 0.728    | ~0.61             |
| Multi-layer    | —        | ~0.43             |
| Overcast (low) | 0.316    | ~0.28             |

CMF category thresholds used in research:
- CMF >= 0.9 → classified as "clear-sky conditions"
- 0.4 < CMF < 0.9 → "partially cloudy conditions"
- CMF <= 0.4 → "overcast conditions"

Sources:
- [Mol et al. 2024 — Observed patterns of surface solar irradiance](https://rmets.onlinelibrary.wiley.com/doi/10.1002/qj.4712)
- [The effect of clouds on surface solar irradiance — ResearchGate](https://www.researchgate.net/publication/301705653)

### 5.3 Can You Have High Transmittance AND Overcast?

**Yes.** This is a well-documented phenomenon:

1. **Thin cirrus overcast:** Cirrus clouds covering 8/8 of the sky can have optical
   depths as low as 0.03-0.3. At such low optical depths, solar transmittance can
   be 70-90% of clear-sky values. The sky is unambiguously overcast (no blue sky
   visible, everything has a milky/hazy quality) but most sunlight passes through.
   CMF > 0.7 is characteristic of cirrus-dominated skies.

2. **Thin marine stratus:** Marine stratus layers, especially during late-morning
   dissipation, can thin to the point where they transmit 50-70% of clear-sky GHI
   while still covering 100% of the sky dome. The sun's disk is clearly visible
   through the layer.

3. **Cloud enhancement:** In broken or partly cloudy conditions, GHI can actually
   EXCEED clear-sky values — by up to 10-13% on a monthly average. This occurs
   when the solar disk is unobscured and nearby clouds reflect additional diffuse
   radiation toward the sensor. Published research documents enhancement of up to
   25-30% for individual minutes.

Source: [Enhanced solar global irradiance during cloudy sky conditions — ResearchGate](https://www.researchgate.net/publication/233645140)

### 5.4 Cloud Optical Depth Is What Matters for Transmittance

The parameter that controls solar transmittance is **cloud optical depth** (tau),
not coverage fraction. Optical depth depends on:

- Cloud liquid/ice water content (thicker clouds block more)
- Cloud geometric thickness (deeper clouds block more)
- Cloud particle size distribution

CMF varies from ~1.0 for optically thin clouds (tau < 0.3) to ~0.05 for very thick
stratus and convective clouds (tau > 50). The NWS sky condition system does not
encode optical depth at all — it only encodes spatial coverage.

### 5.5 Implications for Weather Station Software

If a weather station reports both sky condition (from a provider) and solar radiation
(from a pyranometer), the two measurements can appear contradictory:

- "Overcast" condition + measured GHI at 70% of clear-sky model → thin cloud layer
- "Partly Cloudy" condition + measured GHI at 20% of clear-sky model → thick cloud
  covering the solar disk despite 4/8 coverage
- "Mostly Clear" condition + measured GHI at 110% of clear-sky model → cloud
  enhancement effect

None of these are measurement errors. They reflect the fundamental difference between
a geometric measurement (sky coverage) and a radiometric measurement (solar flux).

---

## 6. METAR and SYNOP Reporting Conventions

### 6.1 METAR Sky Condition Encoding

Format: `NsNsNs hshshs` (amount + height)

Examples:
- `FEW015` — Few clouds at 1,500 ft AGL
- `SCT035 BKN090 OVC140` — Scattered at 3,500, broken at 9,000, overcast at 14,000
- `VV005` — Sky obscured, vertical visibility 500 ft

**Key rules:**

1. **Summation principle applies.** Each reported layer includes the coverage of that
   layer plus all lower layers. A scattered layer at 3,000 ft (3/8) below a broken
   layer at 9,000 ft (covering 4/8 of the remaining sky) reports as `SCT030 BKN090`
   — the broken report at 9,000 is the SUMMATION (3/8 + some of the remaining 5/8),
   not the layer-only amount.

2. **All layers treated as opaque.** "For the purpose of determining sky cover of a
   layer aloft, it does not matter whether you can see through the layer." A thin
   cirrus layer covering 4/8 of the sky is reported as SCT, same as a thick
   cumulonimbus covering 4/8.

3. **No "thin" modifier exists in METAR.** Unlike some older reporting formats, METAR
   has no way to encode "thin broken" or "thin overcast." If the sky is covered,
   it's reported as covered, period. The FAA notes: "the term 'thin' is not used
   in METAR/SPECI observations."

4. **Cloud types:** Only CB (Cumulonimbus) and TCU (Towering Cumulus) are appended
   to sky condition groups. Other cloud types are not encoded in the sky condition
   field. Example: `BKN025CB` — broken cumulonimbus at 2,500 ft.

5. **Ceiling is the lowest BKN or OVC layer.** FEW and SCT layers do not constitute
   a ceiling. This is critical for aviation: ceiling determines whether VFR, MVFR,
   IFR, or LIFR flight rules apply.

6. **Automated stations report CLR instead of SKC** when no clouds are detected
   below 12,000 ft. CLR means "the ceilometer didn't see anything" — there could
   be clouds above its detection range.

### 6.2 SYNOP Cloud Encoding

SYNOP (FM-12) encodes cloud information differently and in more detail than METAR:

**Section 1 — General cloud info:**
- `N` — Total cloud cover in oktas (WMO code table 2700)
  - 0 = clear, 1 = 1/8, ... 8 = 8/8, 9 = sky obscured
- `Nh` — Amount of low cloud (or mid cloud if no low cloud), in oktas
- `CL` — Type of low cloud (code table 0513, 10 types)
- `CM` — Type of middle cloud (code table 0515, 10 types)
- `CH` — Type of high cloud (code table 0509, 10 types)

**Section 3 — Additional cloud layers:**
Up to four individual cloud layers can be reported with:
- Amount (oktas)
- Cloud type
- Height of base

**Critical difference from METAR:** SYNOP reports **total** cloud cover (N), which
includes ALL clouds — both opaque and transparent. The WMO definition of total cloud
amount is "the proportion of the celestial dome covered by any opaque or translucent
clouds, irrespective of layering or type." This means a thin cirrus sheet covering
8/8 of the sky IS counted as N=8 in SYNOP.

SYNOP also encodes cloud TYPE, which implicitly conveys opacity information. A trained
decoder can infer from `CH=1` (cirrus fibratus — thin, wispy) that the high cloud
layer is likely translucent, versus `CH=7` (cirrostratus covering the whole sky) or
`CL=6` (stratus nebulosus — thick, uniform stratus). But this is type information,
not a separate opacity measurement.

**No separate "opaque cloud cover" field exists in standard SYNOP.** Some national
meteorological services (notably Canada) report additional detail in remarks sections,
including cloud opacity. But the standard WMO SYNOP format does not have a dedicated
field for "amount of sky covered by opaque clouds only."

### 6.3 The METAR vs. Public Forecast Gap

| Aspect | METAR (Aviation) | Public Forecast (NWS) |
|--------|-----------------|----------------------|
| Unit | Oktas (eighths) | Oktas or tenths (varies by office) |
| Measure | Total sky coverage (all layers as opaque) | Opaque cloud coverage |
| "Cloudy" threshold | OVC = exactly 8/8 | ~7/8 to 8/8 |
| Transparency | Not distinguished | Transparent clouds excluded |
| Cloud type | Only CB/TCU noted | Not specified |
| Temporal scope | Instantaneous observation | Forecast period average |
| "Ceiling" concept | Yes (lowest BKN/OVC) | Not used in public terms |

The key difference: **METAR treats all clouds as opaque for coverage purposes.**
Public forecasts explicitly exclude transparent clouds from coverage. In practice,
this means a thin cirrus sheet covering the whole sky could be reported as OVC in
METAR but might not qualify as "Cloudy" in a public forecast if the forecaster
judges the cirrus as transparent.

---

## 7. Summary of Key Findings

### 7.1 The hierarchy is well-defined but the boundaries are fuzzy

The general mapping (Clear → Few → Scattered → Broken → Overcast /
Clear → Mostly Clear → Partly Cloudy → Mostly Cloudy → Cloudy) is universally
agreed upon. The exact okta thresholds at each boundary vary by ±1 okta across
different NWS offices.

### 7.2 "Cloudy" and "Overcast" are NOT the same thing

"Overcast" is an observation/aviation term meaning exactly 8/8 coverage (no gaps).
"Cloudy" is a public forecast term covering approximately 7/8-8/8. A BKN (7/8) sky
can be called "Cloudy" in a forecast but is NOT "Overcast" in a METAR.

### 7.3 Coverage fraction says nothing about brightness or transmittance

An overcast sky of thin cirrus transmits most sunlight (CMF > 0.7). An overcast
sky of thick nimbostratus blocks most sunlight (CMF ~ 0.05-0.3). Both are "8/8
overcast." Sky condition is a geometric measurement, not a radiometric one.

### 7.4 METAR has no transparency distinction

All clouds are treated as opaque for METAR sky coverage. SYNOP counts both opaque
and transparent clouds in total cover. NWS public forecasts are defined in terms
of opaque cloud cover — excluding thin transparent clouds. These three systems
can give different answers for the same sky.

### 7.5 Marine stratus is classified by coverage, not thickness

A thin but uniform marine stratus layer covering 100% of the sky is unambiguously
"overcast" regardless of how much light it transmits. There is no meteorological
sky condition category that means "covered but thin."

### 7.6 Human observers are better at instantaneous assessment

Human observers see the entire sky dome simultaneously and make a single judgment.
Ceilometers sample one point repeatedly and infer spatial coverage from temporal
sampling via wind transport. Humans are better for instantaneous assessment;
ceilometers are better for consistent, objective, 24/7 monitoring and perform
better at night for low-coverage detection.

---

## Sources

### Primary / Authoritative
- [NWS Glossary — Sky Condition](https://forecast.weather.gov/glossary.php?word=sky+condition)
- [NWS Binghamton — Forecast Terms](https://www.weather.gov/bgm/forecast_terms)
- [NWS Pittsburgh — Forecast Terms](https://www.weather.gov/ppg/forecast_terms)
- [NWS Huntsville — ZFP Terminology](https://www.weather.gov/hun/zfp_terminology)
- [NWS Phoenix — Did You Know?](https://www.weather.gov/psr/didyouknow)
- [NWS Cloud Classification](https://www.weather.gov/lmk/cloud_classification)
- [NWS Houston — Marine Layer Clouds](https://www.weather.gov/source/zhu/ZHU_Training_Page/clouds/stratus_form_dissipate/Marine_Layer.html)
- [NWS ASOS Ceilometer](https://www.weather.gov/asos/Ceilometer.html)
- [NWS METAR Decode Key (PDF)](https://www.weather.gov/media/wrh/mesowest/metar_decode_key.pdf)
- [FAA Order 7900.5E — Surface Weather Observations](https://www.faa.gov/documentlibrary/media/order/order_jo_7900.5e.pdf) (PDF, access restricted)
- [Federal Meteorological Handbook No. 1](https://www.icams-portal.gov/resources/ofcm/fmh/FMH1/fmh1_2019.pdf) (PDF, access restricted)
- [WMO Code Table 2700](https://www.nodc.noaa.gov/archive/arc0021/0000907/1.1/data/0-data/HTML/WMO-CODE/WMO2700.HTM)
- [WMO Manual on the Observation of Clouds (WMO-407)](https://cloudatlas.wmo.int/docs/wmo_407_en-v1.pdf)

### Academic / Educational
- [UBC ATSC 113 — Cloud Coverage](https://www.eoas.ubc.ca/courses/atsc113/flying/met_concepts/01-met_concepts/01c-cloud_coverage/index.html)
- [The Weather Guys (UW–Madison) — Partly Cloudy vs Partly Sunny](https://wxguys.ssec.wisc.edu/2024/01/08/cloud-cover/)
- [METAR Help — College of DuPage](https://weather.cod.edu/notes/metar.html)
- [ampycloud algorithm — AMT, 2024](https://amt.copernicus.org/articles/17/4891/2024/)
- [EPA — Analysis of ASOS Derived Data](https://www.epa.gov/sites/default/files/2020-10/documents/asos.pdf)

### Research Papers
- [Mol et al. 2024 — Observed patterns of surface solar irradiance under cloudy and clear-sky conditions](https://rmets.onlinelibrary.wiley.com/doi/10.1002/qj.4712)
- [Enhanced solar global irradiance during cloudy sky conditions](https://www.researchgate.net/publication/233645140)
- [The effect of clouds on surface solar irradiance (all-sky imaging)](https://www.researchgate.net/publication/301705653)
- [Cloud cover effect of clear-sky index distributions](https://www.sciencedirect.com/science/article/abs/pii/S0038092X16306624)
- [Error characteristics of ceilometer-based cloud amount observations](https://journals.ametsoc.org/view/journals/atot/33/7/jtech-d-15-0258_1.xml)
- [CAELUS: Classification of sky conditions from GHI time series](https://www.sciencedirect.com/science/article/pii/S0038092X23005285)
- [Marine stratus cloud optical depth and temperature relationships](https://journals.ametsoc.org/view/journals/clim/20/10/jcli4115.1.xml)
- [Thin cirrus effects on solar radiation, Camaguey Cuba](https://www.researchgate.net/publication/252465688)
- [NASA Earth Observatory — Clouds and Radiation](https://earthobservatory.nasa.gov/features/Clouds)

### General Reference
- [Wikipedia — Cloud Cover](https://en.wikipedia.org/wiki/Cloud_cover)
- [Wikipedia — SYNOP](https://en.wikipedia.org/wiki/SYNOP)
- [WeatherStem — Sky Cover](https://learn.weatherstem.com/modules/learn/lessons/190/20.html)
- [Okta — CalcSimpler](https://www.calcsimpler.com/units-and-measures/okta-cloud-cover-eighths-scale)
