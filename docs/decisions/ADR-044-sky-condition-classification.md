---
status: Accepted (2026-05-26)
date: 2026-05-26
deciders: shane
---

# ADR-044: Current conditions text — methodology and sensor fusion

## Context

The dashboard displays a `weatherText` field describing current conditions (e.g., "Mostly Cloudy, Light Rain, and Humid"). This is a composite of up to five independent components: sky condition, precipitation, wind, comfort, and a day/night qualifier. Each component has its own sensor inputs, thresholds, and fallback chain.

The existing implementation (`local_conditions.py` in the API repo) uses naive single-reading thresholds for sky condition and lacks night/day handling. Testing revealed it reports "Clear" when conditions are overcast — the clearness index Kt cannot distinguish thin uniform overcast from partly cloudy skies on a single reading (Duchon & O'Malley 1999). This ADR documents the scientifically backed methodology for the entire conditions statement.

**Current location of logic:** API repo (`services/local_conditions.py`). Per ADR-041, display-facing transformations belong in the BFF. This ADR governs the methodology regardless of which service hosts it.

## Decision

### 1. Sky condition

#### 1a. Primary source: solar radiation analysis (daytime)

During daytime, the station's pyranometer is the authoritative source. Provider cloud cover is a model/forecast output; the pyranometer measures actual conditions at the station. Derive sky condition from the **clear sky index** (kc) with temporal variability analysis.

**Clear-sky model:** Ineichen-Perez (Ineichen & Perez 2002) via pvlib-python. Inputs: latitude, longitude, altitude (station config), timestamp, Linke turbidity (pvlib's built-in SoDa/MINES ParisTech 1°×1° monthly climatological table). No atmospheric measurements required. Alternative: use weewx's `maxSolarRad` directly as the clear-sky reference when available (weewx computes this from its own clear-sky model using station coordinates).

**Clear sky index:** kc = GHI_measured / GHI_clearsky, clamped to [0, 1.2]. Values >1.0 occur from cloud-edge enhancement (Tapakis & Charalambides 2014).

**Two-dimensional classification** over a **30-minute sliding window** of loop data (~5-second MQTT intervals, ~360 samples):

| mean(kc) | σ(kc) | Classification |
|---|---|---|
| ≥ 0.85 | < 0.10 | Clear |
| ≥ 0.85 | ≥ 0.10 | Mostly Clear (cloud-edge events) |
| 0.40–0.85 | ≥ 0.10 | Partly Cloudy (broken cumulus) |
| 0.40–0.85 | < 0.10 | Mostly Cloudy (uniform stratus) |
| < 0.40 | any | Overcast |

σ(kc) threshold of 0.10 separates stable skies from intermittent clouds (Dürr & Philipona 2001). The 30-minute window provides ~360 samples at 5-second intervals — sufficient statistical power for variance estimation.

**Startup:** Until 30 minutes of data accumulates, fall back to provider cloud cover. If no provider either, report no sky condition (wind/comfort only).

#### 1b. Secondary source: provider conditions (night / twilight / no pyranometer)

Provider data is used only when solar radiation analysis is unavailable: at night, during twilight, during startup, or when the station has no pyranometer.

**Priority within provider data:**

1. **Provider weather text** (e.g., `weatherText` from forecast API) — use directly when available. Providers often include conditions that cloud cover percentage alone cannot express: "Fog", "Patchy Fog", "Freezing Fog", "Mist", "Haze", "Blowing Snow", "Ice Crystals", "Smoke", "Thunderstorms." Normalize to Clear Skies display vocabulary via keyword matching (longest match wins):

| Provider text contains | Display as |
|---|---|
| Thunderstorm | Thunderstorms |
| Freezing Fog | Freezing Fog |
| Fog, Mist | Foggy |
| Haze, Smoke | Hazy |
| Blowing Snow | Blowing Snow |
| Overcast | Overcast |
| Mostly Cloudy, Considerable Cloudiness | Mostly Cloudy |
| Partly Cloudy, Partly Sunny | Partly Cloudy |
| Mostly Clear, Mostly Sunny | Mostly Clear |
| Clear, Sunny, Fair | Clear |

2. **Provider cloud cover %** — fallback when no weather text is available. NWS standard sky cover categories (ASOS/METAR, FAA Order 7900.5D §12.4):

| Cloud cover % | Category |
|---|---|
| 0–6 | Clear (CLR) |
| 7–31 | Few (FEW) — display as "Mostly Clear" |
| 32–56 | Scattered (SCT) — display as "Partly Cloudy" |
| 57–87 | Broken (BKN) — display as "Mostly Cloudy" |
| 88–100 | Overcast (OVC) |

3. **Neither available** — omit sky descriptor entirely.

#### 1c. Edge cases and anomalous atmosphere

- **Night** (solar zenith > 90°): No solar classification possible. Use provider cloud cover or omit sky descriptor.
- **Civil twilight** (zenith 80–90°): Solar classification unreliable. Fall back to provider cloud cover; if unavailable, omit sky descriptor.
- **GHI < 10 W/m²**: Below pyranometer noise floor. Skip solar classification, use provider.
- **Cloud-edge enhancement** (kc > 1.0): Evidence of nearby clouds. Sustained enhancement within the window contributes to elevated σ(kc), naturally classifying as Partly Cloudy.
- **Anomalous turbidity — smoke, dust, haze:** Climatological Linke turbidity underestimates actual atmospheric extinction during wildfire smoke, dust storms, or heavy haze. This produces artificially low kc (sky appears "cloudier" than it is). **Detection heuristic:** when kc is persistently low (mean < 0.70) AND σ(kc) is very low (< 0.03) AND provider reports clear or few clouds AND local temperature/humidity are inconsistent with thick cloud cover (e.g., high temp, low humidity), flag as "Hazy" or "Smoky" instead of "Mostly Cloudy." This heuristic is imperfect but catches the most common false classification. When AQI data is available and elevated (PM2.5 > 35 µg/m³ or AQI > 100), the confidence in a smoke/haze diagnosis increases.
- **Snow on pyranometer:** Produces kc ≈ 0, indistinguishable from overcast. Cannot be detected from radiation data alone. If temperature is well below freezing and provider reports clear, consider adding a data-quality warning.

### 2. Day/night determination

Solar zenith angle computed from station coordinates and timestamp (pvlib `solarposition` or equivalent):

| Solar zenith | Period |
|---|---|
| < 90° | Day — use sky condition as-is |
| 90–96° | Civil twilight — prefix conditions with no qualifier |
| > 96° | Night — substitute sky label: "Clear" → "Clear", "Partly Cloudy" → "Partly Cloudy", etc. (NWS uses identical terms day and night) |

Night/day affects only whether solar-radiation-based sky classification is attempted (§1b). Provider cloud cover and all other components are unaffected by time of day.

### 3. Precipitation

**Primary source: local rain gauge** (`rainRate`). Rain gauges measure actual liquid precipitation; providers forecast it. Local measurement takes priority.

Rain rate thresholds (AMS Glossary of Meteorology; WMO classification):

| Rain rate | Category |
|---|---|
| 0 or null | No precipitation |
| > 0 and < 0.10 in/hr (2.5 mm/hr) | Light Rain |
| 0.10–0.30 in/hr (2.5–7.6 mm/hr) | Moderate Rain |
| > 0.30 in/hr (7.6 mm/hr) | Heavy Rain |

**Frozen precipitation:** Rain gauges cannot distinguish rain from snow. When `rainRate > 0` AND provider reports `precipType` of "snow", "freezing-rain", or "sleet", use the provider's type — but only if the Stull (2011) wet-bulb temperature is ≤ 35°F (1.7°C). Above this threshold, frozen precipitation is thermodynamically implausible regardless of provider forecast. Wet-bulb temperature is computed from `outTemp` and `outHumidity` using the Stull (2011) empirical formula.

**No rain gauge, provider only:** If no local `rainRate` and provider reports precipitation, use provider text but mark as "forecast-derived" in the data source field.

### 4. Wind description

**Beaufort scale** (WMO standard, thresholds in m/s, converted internally from station's wind unit):

| Beaufort | m/s | Label |
|---|---|---|
| 0 | < 0.5 | Calm |
| 1 | 0.5–1.5 | Light Air |
| 2 | 1.6–3.3 | Light Breeze |
| 3 | 3.4–5.4 | Gentle Breeze |
| 4 | 5.5–7.9 | Moderate Breeze |
| 5 | 8.0–10.7 | Fresh Breeze |
| 6 | 10.8–13.8 | Strong Breeze |
| 7 | 13.9–17.1 | Near Gale |
| 8 | 17.2–20.7 | Gale |
| 9 | 20.8–24.4 | Strong Gale |
| 10 | 24.5–28.4 | Storm |
| 11 | 28.5–32.6 | Violent Storm |
| 12 | ≥ 32.7 | Hurricane Force |

**Gusty qualifier:** Append "and Gusty" when `windGust ≥ windSpeed + 12 mph` AND `windGust ≥ 18 mph`. This follows NWS ASOS practice where "gusty" means sustained-to-gust spread exceeds a meaningful threshold.

**Calm suppression:** Beaufort 0 (Calm) is omitted from the composed text — "Overcast" reads better than "Overcast and Calm."

### 5. Comfort / humidity descriptor

**Dewpoint-based** (NWS and AMS practice — dewpoint is a better humidity indicator than relative humidity because it is independent of temperature):

| Dewpoint | Descriptor |
|---|---|
| < 55°F (12.8°C) | (comfortable — omitted) |
| 55–59°F (12.8–15°C) | (comfortable — omitted) |
| 60–64°F (15.6–17.8°C) | Humid |
| 65–69°F (18.3–20.6°C) | Very Humid |
| 70–74°F (21.1–23.3°C) | Oppressive |
| ≥ 75°F (23.9°C) | Miserable |

Thresholds aligned with NWS dewpoint comfort scale. The descriptor is omitted when conditions are comfortable (dewpoint < 60°F) to avoid cluttering the text.

### 6. Composition rules

Components are assembled in priority order: **[sky, precipitation, wind, comfort]**. Null/omitted components are dropped.

| Parts | Format |
|---|---|
| 1 | "{part}" |
| 2 | "{a} and {b}" |
| 3+ | "{a}, {b}, ... and {last}" (Oxford comma style) |

Examples:
- "Partly Cloudy and Moderate Breeze"
- "Overcast, Light Rain, and Humid"
- "Mostly Cloudy, Heavy Rain, Fresh Breeze and Gusty, and Oppressive"
- "Moderate Breeze" (night, no provider cloud cover, no precipitation)

### 7. Data source priority

Each component independently selects its source:

| Component | Primary | Fallback |
|---|---|---|
| Sky condition | Solar radiation kc + σ(kc) analysis (day) | Provider cloud cover % (night, twilight, startup, no pyranometer) |
| Precipitation | Local rain gauge | Provider precipType (with wet-bulb filter) |
| Wind | Local anemometer | (no fallback — omit if absent) |
| Comfort | Local dewpoint | (no fallback — omit if absent) |

Local sensor data is always authoritative over provider forecasts. Provider data is used only when local sensors cannot answer the question (sky condition at night, frozen precipitation type).

## Options considered (sky condition method)

| Option | Verdict |
|---|---|
| A. Clear sky index (kc) + temporal variability (2D) | **Selected.** Scientifically grounded, pyranometer-only. |
| B. Provider cloud cover only | Insufficient — not always available, defaults to "Clear." |
| C. Fixed GHI thresholds | Rejected. Ignores solar geometry. |
| D. Diffuse fraction (D/G) | Requires hardware most home stations lack. |
| E. CAELUS 6-class (Ruiz-Arias & Gueymard 2023) | Overkill for weather display. |

## Consequences

- New dependency: `pvlib-python` in whichever repo hosts the sky condition logic (MIT license, well-maintained).
- 30-minute startup delay for solar-radiation-based classification. Provider cloud cover fills the gap.
- Rolling buffer of ~360 kc values (~3 KB memory). Negligible.
- Linke turbidity climatology introduces small errors during anomalous atmospheric events. Accepted.
- Existing `local_conditions.py` thresholds need updating to match this ADR. The naive single-reading Kt thresholds are replaced by the 2D (mean + σ) classification.

## Implementation guidance

- New module for sky condition: computes solar position, clear-sky GHI, maintains rolling kc buffer, classifies using the 2D table.
- Station coordinates from config (wizard writes latitude, longitude, altitude).
- Called on each loop packet containing a `radiation` field. On each REST proxy request, use the latest classification from the rolling buffer.
- All threshold comparisons use canonical units internally (m/s for wind, °F for dewpoint, in/hr for rain rate) — convert from source unit before comparing.
- The Stull (2011) wet-bulb formula: Tw = T × atan(0.151977 × (RH + 8.313659)^0.5) + atan(T + RH) − atan(RH − 1.676331) + 0.00391838 × RH^1.5 × atan(0.023101 × RH) − 4.686035 (T in °C, RH in %).

## References

- Ineichen, P. & Perez, R. (2002). A new airmass independent formulation for the Linke turbidity coefficient. *Solar Energy*, 73(3), 151–157.
- Duchon, C.E. & O'Malley, M.S. (1999). Estimating cloud type from pyranometer observations. *J. Applied Meteorology*, 38, 132–141.
- Dürr, B. & Philipona, R. (2001). Automatic cloud amount detection by surface longwave downward radiation measurements. *J. Geophysical Research*, 109, D05201.
- Reno, M.J. & Hansen, C.W. (2016). Identification of periods of clear sky irradiance in time series of GHI measurements. *Renewable Energy*, 90, 520–531.
- Ruiz-Arias, J.A. & Gueymard, C.A. (2023). CAELUS: Classification of sky conditions from 1-min time series. *Solar Energy*, 262, 111824.
- Correa, C.D. et al. (2022). A method for clear-sky identification and long-term trends assessment. *AGU Earth and Space Science*, 9(3).
- Stull, R. (2011). Wet-bulb temperature from relative humidity and air temperature. *J. Applied Meteorology and Climatology*, 50(11), 2267–2269.
- Kasten, F. & Czeplak, G. (1980). Solar and terrestrial radiation dependent on the amount and type of cloud. *Solar Energy*, 24(2), 177–189.
- Tapakis, R. & Charalambides, A.G. (2014). Enhanced values of global irradiance due to the presence of clouds. *Renewable Energy*, 62, 459–467.
- WMO (2018). Guide to Meteorological Instruments and Methods of Observation. WMO-No. 8, Chapter 15.
- NWS ASOS User's Guide. Federal Meteorological Handbook No. 1 (FMH-1), Chapter 12 — Sky Condition.
- AMS Glossary of Meteorology — entries for "rain", "Beaufort scale", "dew point."
- pvlib-python: https://pvlib-python.readthedocs.io/

## Out of scope

- Cloud type classification (cirrus vs. cumulus vs. stratus) — beyond weather display needs.
- Diffuse fraction analysis — requires hardware most home stations lack.
- Real-time turbidity measurement — requires sun photometer.
- Probabilistic sky condition (confidence intervals) — display needs a single label, not a distribution.
