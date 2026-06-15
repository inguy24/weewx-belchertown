---
status: Accepted
date: 2026-05-26
amended: 2026-06-08
deciders: shane
---

# ADR-044: Current conditions text — methodology and sensor fusion

## Context

The dashboard displays a `weatherText` field describing current conditions (e.g., "Mostly Cloudy, Light Rain, and Humid"). This is a composite of up to five independent components: sky condition, precipitation, wind, comfort, and a day/night qualifier. Each component has its own sensor inputs, thresholds, and fallback chain.

The existing implementation (`local_conditions.py` in the API repo) uses naive single-reading thresholds for sky condition and lacks night/day handling. Testing revealed it reports "Clear" when conditions are overcast — the clearness index Kt cannot distinguish thin uniform overcast from partly cloudy skies on a single reading (Duchon & O'Malley 1999). This ADR documents the scientifically backed methodology for the entire conditions statement.

**Current location of logic:** API repo (`services/local_conditions.py`). Per ADR-041 (amended by ADR-058), display-facing transformations belong in the API's enrichment pipeline. This ADR governs the methodology regardless of which service hosts it.

## Decision

> **Amendment (2026-05-28):** Sections 5–8 added. §5 comfort/humidity descriptor replaced with 2D temperature-comfort matrix (§5–7). §8 input stability specification added. §4 Beaufort 1 renamed "Very Light Breeze". §9 composition order reversed (temperature-comfort leads, "with" connector). Original §6–7 renumbered to §9–10.

### 1. Sky condition

#### 1a. Primary source: solar radiation analysis (daytime)

During daytime, the station's pyranometer is the authoritative source. Provider cloud cover is a model/forecast output; the pyranometer measures actual conditions at the station. Derive sky condition from the **clear sky index** (kc) with temporal variability analysis.

**Clear-sky model:** Ineichen-Perez (Ineichen & Perez 2002) via pvlib-python. Inputs: latitude, longitude, altitude (station config), timestamp, Linke turbidity (pvlib's built-in SoDa/MINES ParisTech 1°×1° monthly climatological table). No atmospheric measurements required. Alternative: use weewx's `maxSolarRad` directly as the clear-sky reference when available (weewx computes this from its own clear-sky model using station coordinates).

**Clear sky index:** kc = GHI_measured / GHI_clearsky, clamped to [0, 1.2]. Values >1.0 occur from cloud-edge enhancement (Tapakis & Charalambides 2014).

**Sigma-first two-dimensional classification** over a **30-minute sliding window** of loop data (~5-second MQTT intervals, ~360 samples):

> **Amendment (2026-06-05):** Classification axes swapped — σ(kc) is now the primary axis, mean(kc) secondary. The original table used mean(kc) as primary, which conflated cloud opacity with cloud coverage.

> **Amendment (2026-06-08):** Thresholds revised for sensor accuracy. Davis 6450 pyranometer ±5% accuracy + weewx maxSolarRad model ±4% error means a perfectly clear sky can produce kc ~0.93 from systematic bias alone — the previous Clear threshold of 0.95 was inside the noise floor. σ threshold corrected from 0.10 to 0.08 (matching deployed code). Intermediate low-sigma tiers restored (the June 5 simplification conflated opacity with coverage, but thin cirrus/haze legitimately produces low-sigma intermediate kc). "Overcast"/"Heavily Overcast" replaced with "Cloudy" per NWS display vocabulary. Day/night display vocabulary added (§2).

**Low sigma (< 0.08) — uniform sky, no cloud transits detected:**

| σ(kc) | mean(kc) | Classification | Physical meaning |
|---|---|---|---|
| < 0.08 | ≥ 0.85 | Clear | Uniform irradiance near clear-sky level |
| < 0.08 | 0.70–0.85 | Mostly Clear | Thin uniform dimming (cirrus, haze, marine layer) |
| < 0.08 | 0.50–0.70 | Partly Cloudy | Thin uniform overcast |
| < 0.08 | 0.30–0.50 | Mostly Cloudy | Moderate uniform overcast |
| < 0.08 | < 0.30 | Cloudy | Thick uniform cover |

**High sigma (≥ 0.08) — variable sky, cloud transits detected:**

| σ(kc) | mean(kc) | Classification | Physical meaning |
|---|---|---|---|
| ≥ 0.08 | ≥ 0.85 | Mostly Clear | Infrequent cloud passages, mostly sun |
| ≥ 0.08 | 0.60–0.85 | Partly Cloudy | Frequent cloud passages |
| ≥ 0.08 | < 0.60 | Mostly Cloudy | Mostly cloud with sun breaks |

σ(kc) threshold of 0.08 separates uniform skies from broken/variable skies. The 30-minute window provides ~360 samples at 5-second intervals — sufficient statistical power for variance estimation.

**Startup:** Until **~3 minutes** of data accumulates (**36 samples** at ~5-second intervals),
fall back to provider cloud cover. If no provider either, report no sky condition
(wind/comfort only). The minimum-samples guard (`_MIN_SAMPLES = 36`) provides enough
statistical power for a first classification without requiring the full 30-minute window.
The full 30-minute window is the steady-state buffer size for variance estimation, not the
startup threshold.

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
| Overcast | Cloudy |
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
| 88–100 | Cloudy (OVC) |

3. **Neither available** — omit sky descriptor entirely.

#### 1c. Edge cases and anomalous atmosphere

- **Night** (solar zenith > 90°): No solar classification possible. Use provider cloud cover or omit sky descriptor.
- **Civil twilight** (zenith 80–90°): Solar classification unreliable. Fall back to provider cloud cover; if unavailable, omit sky descriptor.
- **GHI noise floor:** The code sets `_NOISE_FLOOR = 0.0` W/m² — readings at or above 0 are
  accepted into the kc buffer. A separate guard (`maxSolarRad < 50 W/m²`) already excludes
  night and deep-twilight periods before any GHI value is evaluated; in practice this makes
  the 10 W/m² floor redundant. The effective operational threshold is the `maxSolarRad < 50`
  guard: below it, no readings are added regardless of GHI. The `_NOISE_FLOOR = 0.0`
  constant catches only physically invalid negative sensor readings.
- **Cloud-edge enhancement** (kc > 1.0): Evidence of nearby clouds. Sustained enhancement within the window contributes to elevated σ(kc), naturally classifying as Partly Cloudy.
- **Anomalous turbidity — smoke, dust, haze:** Climatological Linke turbidity underestimates actual atmospheric extinction during wildfire smoke, dust storms, or heavy haze. This produces artificially low kc (sky appears "cloudier" than it is). **Detection heuristic:** when kc is persistently low (mean < 0.70) AND σ(kc) is very low (< 0.03) AND provider reports clear or few clouds AND local temperature/humidity are inconsistent with thick cloud cover (e.g., high temp, low humidity), flag as "Hazy" or "Smoky" instead of "Mostly Cloudy." This heuristic is imperfect but catches the most common false classification. When AQI data is available and elevated (PM2.5 > 35 µg/m³ or AQI > 100), the confidence in a smoke/haze diagnosis increases.
- **Snow on pyranometer:** Produces kc ≈ 0, indistinguishable from overcast. Cannot be detected from radiation data alone. If temperature is well below freezing and provider reports clear, consider adding a data-quality warning.

### 2. Day/night determination

Solar zenith angle computed from station coordinates and timestamp (pvlib `solarposition` or equivalent):

| Solar zenith | Period |
|---|---|
| < 90° | Day — use sky condition as-is |
| 90–96° | Civil twilight — prefix conditions with no qualifier |
| > 96° | Night — use night display vocabulary (see below) |

> **Amendment (2026-06-08):** Day/night display vocabulary added. NWS uses "Sunny"/"Mostly Sunny" during the day and "Clear"/"Mostly Clear" at night. The mapping is applied at display time by `_to_display_label()` in `conditions_text.py` and by `_cloud_pct_to_sky(is_day=True)` in `enrichment/weather_text.py`.

**Display vocabulary mapping (NWS standard):**

| Classification label | Day display | Night display |
|---|---|---|
| Clear | Sunny | Clear |
| Mostly Clear | Mostly Sunny | Mostly Clear |
| Partly Cloudy | Partly Cloudy | Partly Cloudy |
| Mostly Cloudy | Mostly Cloudy | Mostly Cloudy |
| Cloudy | Cloudy | Cloudy |

Night/day affects (1) whether solar-radiation-based sky classification is attempted (§1b) and (2) the display vocabulary used for the sky label.

### 3. Precipitation

**Primary source: local rain gauge** (`rainRate`). Rain gauges measure actual liquid precipitation; providers forecast it. Local measurement takes priority.

Rain rate thresholds (AMS Glossary of Meteorology; WMO classification):

| Rain rate | Category |
|---|---|
| 0 or null | No precipitation |
| > 0 and < 0.10 in/hr (2.5 mm/hr) | Light Rain |
| ≥ 0.10 and < 0.30 in/hr (2.5–7.6 mm/hr) | Moderate Rain |
| ≥ 0.30 in/hr (7.6 mm/hr) | Heavy Rain |

**Frozen precipitation:** Rain gauges cannot distinguish rain from snow. When `rainRate > 0` AND provider reports `precipType` of "snow", "freezing-rain", or "sleet", use the provider's type — but only if the Stull (2011) wet-bulb temperature is ≤ 35°F (1.7°C). Above this threshold, frozen precipitation is thermodynamically implausible regardless of provider forecast. Wet-bulb temperature is computed from `outTemp` and `outHumidity` using the Stull (2011) empirical formula.

**No rain gauge, provider only:** If no local `rainRate` and provider reports precipitation, use provider text but mark as "forecast-derived" in the data source field.

### 4. Wind description

**Beaufort scale** (WMO standard, thresholds in m/s, converted internally from station's wind unit):

| Beaufort | m/s | Label |
|---|---|---|
| 0 | < 0.5 | Calm |
| 1 | 0.5–1.5 | Very Light Breeze |
| 2 | 1.6–3.3 | Light breeze |
| 3 | 3.4–5.4 | Gentle breeze |
| 4 | 5.5–7.9 | Moderate breeze |
| 5 | 8.0–10.7 | Fresh breeze |
| 6 | 10.8–13.8 | Strong breeze |
| 7 | 13.9–17.1 | Near gale |
| 8 | 17.2–20.7 | Gale |
| 9 | 20.8–24.4 | Strong gale |
| 10 | 24.5–28.4 | Storm |
| 11 | 28.5–32.6 | Violent storm |
| 12 | ≥ 32.7 | Hurricane |

> **Amendment (2026-05-28):** Beaufort 1 renamed from "Light Air" to "Very Light Breeze". All other labels unchanged.

> **Casing note:** All multi-word labels use sentence case (only the first word capitalised),
> except "Calm" (single word) and "Very Light Breeze" (B1, initial-capitalised by convention).
> B12 is "Hurricane" (not "Hurricane Force") — the "Force" suffix is omitted for display
> brevity. The code in `units/derived.py` is authoritative; this table documents the as-built
> strings.

**Gusty qualifier:** Append "and Gusty" when `windGust ≥ windSpeed + 12 mph` AND `windGust ≥ 18 mph`. This follows NWS ASOS practice where "gusty" means sustained-to-gust spread exceeds a meaningful threshold.

> **As-built (commit eafb706, amended 2026-06-05):** Implemented in `conditions_text.py:build_weather_text()`.
> Both speeds are converted to mph before comparison regardless of station unit, so knot/m/s
> stations evaluate the same thresholds. The qualifier only fires for non-Calm wind
> (Beaufort > 0) — "Calm and Gusty" is nonsensical.

> **Amendment (2026-06-05):** Calm is no longer suppressed. Beaufort 0 ("Calm") appears in the
> composed text like any other wind condition — calm is a real atmospheric state, not the absence
> of data. Example: "Pleasant and Humid, Overcast, with Calm".

### 5. Temperature axis

> **Amendment (2026-05-28):** This section replaces the original §5 (Comfort / humidity descriptor), which used a 1D dewpoint-only axis. The new design is a 2D matrix combining an apparent-temperature axis (this section) with a moisture axis (§6).

The temperature dimension is derived from **apparent temperature** (`appTemp`, in °F). Apparent temperature (also called "feels like" temperature) accounts for both wind chill and heat index effects, giving a unified thermal comfort metric across all seasons.

| Tier | appTemp range | Base label |
|---|---|---|
| 1 | ≤ −10°F (≤ −23.3°C) | Dangerously Cold |
| 2 | −9 to 0°F (−22.8 to −17.8°C) | Bitter Cold |
| 3 | 1 to 10°F (−17.2 to −12.2°C) | Extreme Cold |
| 4 | 11 to 20°F (−11.7 to −6.7°C) | Very Cold |
| 5 | 21 to 32°F (−6.1 to 0°C) | Cold |
| 6 | 33 to 45°F (0.6 to 7.2°C) | Chilly |
| 7 | 46 to 60°F (7.8 to 15.6°C) | Cool |
| 8 | 61 to 75°F (16.1 to 23.9°C) | Pleasant |
| 9 | 76 to 85°F (24.4 to 29.4°C) | Warm |
| 10 | 86 to 95°F (30 to 35°C) | Hot |
| 11 | 96 to 104°F (35.6 to 40°C) | Very Hot |
| 12 | ≥ 105°F (≥ 40.6°C) | Dangerously Hot |

**Source:** `appTemp` is a weewx-computed field available in loop packets and archive records. When `appTemp` is null or absent, the temperature label is omitted.

### 6. Moisture axis

> **Amendment (2026-05-28):** New section. Dewpoint-based moisture tiers for the 2D matrix.

The moisture dimension uses **dewpoint** (°F). Dewpoint is independent of air temperature and is the standard NWS and AMS measure of atmospheric moisture loading.

| Tier | Dewpoint range | Moisture modifier |
|---|---|---|
| A | < 45°F (< 7.2°C) | (none — omitted) |
| B | 45–54°F (7.2–12.2°C) | (none — omitted) |
| C | 55–59°F (12.8–15°C) | Slightly Humid |
| D | 60–64°F (15.6–17.8°C) | Humid |
| E | 65–69°F (18.3–20.6°C) | Very Humid |
| F | 70–74°F (21.1–23.3°C) | Oppressive |
| G | ≥ 75°F (≥ 23.9°C) | Miserable |

Tiers A–B (dewpoint below 55°F) produce no humidity modifier — the temperature label stands alone.

**Near-saturation override:** When **dewpoint depression** (outTemp − dewpoint) ≤ 5°F, regardless of the absolute dewpoint value, append "and Foggy" to the conditions text. This indicates near-saturation conditions likely producing fog, heavy dew, or frost. The override applies at any temperature tier and takes precedence over the normal moisture modifier for that tier.

### 7. Full 2D matrix

> **Amendment (2026-05-28):** New section. Defines the composite descriptor for every temperature-tier × moisture-tier combination.

**Composition rules for the matrix:**

1. **Warm temperatures, dry moisture (tiers 6–12 × A–B):** output = temperature label only (e.g., "Pleasant", "Warm", "Cool").
2. **Warm temperatures, humid moisture (tiers 6–12 × C–G):** output = temperature label + "and" + moisture label (e.g., "Warm and Humid", "Hot and Oppressive").
3. **Cold temperatures (tiers 1–5, appTemp ≤ 32°F):** moisture modifier is always omitted, regardless of dewpoint tier. Cold air cannot hold enough moisture for humidity descriptors to be physically meaningful. Output = temperature label only.
4. **NWS Heat Index danger escalation** (takes precedence over temperature+moisture label):
   - Heat Index ≥ 104°F (40°C): output = "Dangerous Heat"
   - Heat Index ≥ 125°F (51.7°C): output = "Extreme Danger Heat"
5. **NWS Wind Chill danger escalation** (takes precedence over temperature label):
   - Wind Chill ≤ −25°F (−31.7°C): output = "Dangerous Cold"
   - Wind Chill ≤ −45°F (−42.8°C): output = "Extreme Danger Cold"
6. **Near-saturation override** (§6): when dewpoint depression ≤ 5°F, append "and Foggy" to the output of any rule above (including danger escalations).

NWS danger thresholds source: NWS Heat Index Chart (HI ≥ 103°F Danger / ≥ 125°F Extreme Danger) and NWS Wind Chill Chart (WC ≤ −25°F Danger / ≤ −45°F Extreme Danger). The HI boundary of 104°F used here corresponds to the lower bound of the NWS "Danger" zone (103–124°F, conservatively rounded to 104°F to avoid false triggers at 103°F sensor noise).

**Matrix — rows = temperature tier, columns = moisture tier:**

Cells marked "—" are physically implausible (e.g., dewpoint ≥ 55°F when appTemp ≤ 32°F requires unusual atmospheric conditions such as advection fog; the cold-temperature suppression rule in item 3 handles them uniformly regardless).

| appTemp tier | A (dp < 45°F) | B (dp 45–54°F) | C (dp 55–59°F) | D (dp 60–64°F) | E (dp 65–69°F) | F (dp 70–74°F) | G (dp ≥ 75°F) |
|---|---|---|---|---|---|---|---|
| **1** ≤ −10°F Dangerously Cold | Dangerously Cold | Dangerously Cold | Dangerously Cold | Dangerously Cold | Dangerously Cold | Dangerously Cold | Dangerously Cold |
| **2** −9 to 0°F Bitter Cold | Bitter Cold | Bitter Cold | Bitter Cold | Bitter Cold | Bitter Cold | Bitter Cold | Bitter Cold |
| **3** 1–10°F Extreme Cold | Extreme Cold | Extreme Cold | Extreme Cold | Extreme Cold | Extreme Cold | Extreme Cold | Extreme Cold |
| **4** 11–20°F Very Cold | Very Cold | Very Cold | Very Cold | Very Cold | Very Cold | Very Cold | Very Cold |
| **5** 21–32°F Cold | Cold | Cold | Cold | Cold | Cold | Cold | Cold |
| **6** 33–45°F Chilly | Chilly | Chilly | Chilly and Slightly Humid | Chilly and Humid | Chilly and Very Humid | Chilly and Oppressive | Chilly and Miserable |
| **7** 46–60°F Cool | Cool | Cool | Cool and Slightly Humid | Cool and Humid | Cool and Very Humid | Cool and Oppressive | Cool and Miserable |
| **8** 61–75°F Pleasant | Pleasant | Pleasant | Pleasant and Slightly Humid | Pleasant and Humid | Pleasant and Very Humid | Pleasant and Oppressive | Pleasant and Miserable |
| **9** 76–85°F Warm | Warm | Warm | Warm and Slightly Humid | Warm and Humid | Warm and Very Humid | Warm and Oppressive | Warm and Miserable |
| **10** 86–95°F Hot | Hot | Hot | Hot and Slightly Humid | Hot and Humid | Hot and Very Humid | Hot and Oppressive | Hot and Miserable |
| **11** 96–104°F Very Hot | Very Hot | Very Hot | Very Hot and Slightly Humid | Very Hot and Humid | Very Hot and Very Humid | Very Hot and Oppressive | Very Hot and Miserable |
| **12** ≥ 105°F Dangerously Hot | Dangerously Hot | Dangerously Hot | Dangerously Hot and Slightly Humid | Dangerously Hot and Humid | Dangerously Hot and Very Humid | Dangerously Hot and Oppressive | Dangerously Hot and Miserable |

**Danger overrides (applied after table lookup):**

| Condition | Output |
|---|---|
| Heat Index ≥ 125°F | "Extreme Danger Heat" |
| Heat Index ≥ 104°F | "Dangerous Heat" |
| Wind Chill ≤ −45°F | "Extreme Danger Cold" |
| Wind Chill ≤ −25°F | "Dangerous Cold" |

Danger overrides supersede the table cell. Near-saturation "and Foggy" appended after any output, including danger overrides (e.g., "Dangerous Cold and Foggy").

### 8. Input stability

> **Amendment (2026-05-28):** New section. Documents smoothing, hysteresis, and hold-time design to prevent conditions text from bouncing across tier boundaries as raw loop packets oscillate.

Three stability mechanisms are applied in sequence before any threshold comparison:

1. **Smoothed inputs** — ring-buffer averages over the windows below.
2. **Hysteresis** — once a tier is established, require crossing 2°F / 2 mph past the opposite boundary before switching.
3. **Minimum hold time** — the composed conditions text string is held for 5 minutes minimum before any change is allowed (backup mechanism if smoothing and hysteresis do not fully eliminate oscillation).

**Smoothing windows:**

| Input | Buffer window | Samples (~5s interval) | Rationale |
|---|---|---|---|
| Solar radiation (kc) | 30 min | ~360 | ADR-044 §1 spec — sky conditions change slowly |
| UV | 10 min | 120 | Cloud-pass noise |
| appTemp | 10 min | 120 | Temperature does not legitimately change 5°F in seconds |
| dewpoint | 10 min | 120 | Same |
| outTemp (depression calc) | 10 min | 120 | Paired with dewpoint for near-saturation check |
| windSpeed | 5 min | 60 | Wind is legitimately gusty — shorter window |
| windGust | 5 min | 60 | Same |
| rainRate | 2 min | 24 | Rain onset/cessation must register quickly |
| heatindex | 10 min | 120 | Follows temperature |
| windchill | 10 min | 120 | Follows temperature + wind |

**Hysteresis values:**

| Dimension | Hysteresis band |
|---|---|
| All temperature thresholds (appTemp, heatindex, windchill) | ±2°F |
| All wind thresholds (windSpeed, windGust) | ±2 mph |
| All dewpoint thresholds | ±2°F |
| Rain rate thresholds | ±0.02 in/hr |

**Minimum hold time:** 5 minutes. The conditions text string is cached after each composition. If smoothed+hysteresis inputs produce a different result, the new text replaces the cached value only after the 5-minute hold expires. This prevents rapid flipping even when smoothing and hysteresis do not fully suppress boundary oscillation.

### 9. Composition rules

> **Amendment (2026-05-28):** Composition order reversed — temperature-comfort leads, weather phenomena follow with "with" connector. Prevents double-"and" when the temperature-comfort label is compound (e.g., "Warm and Humid").

Components are assembled in priority order: **[temperature-comfort, sky, wind, precipitation]**. Null/omitted components are dropped.

| Parts | Format |
|---|---|
| 1 | "{part}" |
| 2 | "{a}, with {b}" |
| 3+ | "{a}, {b}, with {last}" |

Examples:
- "Warm and Humid, Overcast, with Light Rain"
- "Pleasant, Partly Cloudy, with Moderate Breeze"
- "Hot and Oppressive, Mostly Cloudy, Fresh Breeze and Gusty, with Heavy Rain"
- "Moderate Breeze" (night, no provider cloud cover, no precipitation, no temperature data)
- "Chilly, with Light Rain" (night, no sky data, no wind)

### 10. Data source priority

Each component independently selects its source:

| Component | Primary | Fallback |
|---|---|---|
| Sky condition | Solar radiation kc + σ(kc) analysis (day) | Provider cloud cover % (night, twilight, startup, no pyranometer) |
| Precipitation | Local rain gauge | Provider precipType (with wet-bulb filter) |
| Wind | Local anemometer | (no fallback — omit if absent) |
| Temperature-comfort | Local appTemp + dewpoint + outTemp | (no fallback — omit if absent) |

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
