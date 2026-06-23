---
status: Superseded by ADR-073
date: 2026-05-26
amended: 2026-06-21
deciders: shane
---

> **Superseded (2026-06-23).** This ADR is fully superseded by [ADR-073](../../decisions/ADR-073-sky-condition-kv-first-classification.md). ADR-073 carries forward the still-valid decisions (detrending, dual windows, mirroring, SZA guard, precipitation, temperature-comfort, day/night vocabulary, temporal coherence, provider fallback) and replaces the classification architecture (Kv-first tree replaces CAELUS Km-first tree). Consult ADR-073 for all conditions-text methodology.

# ADR-044: Current conditions text — methodology and sensor fusion

## Context

The dashboard displays a `weatherText` field describing current conditions (e.g., "Mostly Cloudy, Light Rain, and Humid"). This is a composite of independent components: sky condition, precipitation, wind, temperature-comfort, and a day/night qualifier. Each component requires a defensible methodology — what science backs the thresholds, why one approach over another, and what the limitations are.

The original implementation used a single-reading clearness index (Kt) for sky condition. Testing revealed it reports "Clear" under uniform overcast — Duchon & O'Malley (1999) established that a single-point clearness index cannot distinguish thin uniform overcast from partly cloudy because both can produce the same instantaneous kc value. The system needed a methodology that classifies the *pattern* of irradiance over time, not a snapshot.

**Prescriptive rules** (formulas, thresholds, code module paths) are in `docs/API-MANUAL.md` §8. This ADR records the scientific reasoning behind those rules.

**Detailed citations** are in `docs/reference/sky-classification-science.md`.

---

## Decisions

### 1. Sky classification: CAELUS as detection engine, K-C as translation layer

**Decision:** Use CAELUS (Ruiz-Arias & Gueymard 2023) as the **detection engine** — its four indices (Kcs, Km, Kv, Kvf) identify what type of cloud pattern the pyranometer sees. Use Kasten-Czeplak (1980) as the **translation layer** — its empirical formula maps Km values to NWS sky coverage categories for weather display labels.

**Why this separation matters:** CAELUS was designed for solar energy applications. Its six class names (CLOUDLESS, CLOUD_ENHANCEMENT, THIN_CLOUDS, SCATTER_CLOUDS, THICK_CLOUDS, OVERCAST) describe irradiance patterns relevant to solar panel production, not weather conditions. The CAELUS README explicitly warns: *"The name of the different sky conditions is only orientative of the expected situations within each class."* CAELUS CLOUDLESS means "stable high output, good for panels" — but you can have scattered clouds visible in the sky while the pyranometer sees CLOUDLESS because the sun is in a gap. CAELUS class names cannot be used directly as weather display labels.

K-C bridges this gap. The formula `Km = 1 - 0.75 × (N/8)^3.4` was derived from correlating ground-based radiation measurements with human-observed cloud cover (oktas). It maps the Km value — which CAELUS computes from pyranometer data — to the NWS sky coverage category that a person looking at the sky would report. The display label comes from K-C's mapping, not from CAELUS's class name.

**The chain:** Pyranometer → CAELUS indices (Kcs, Km, Kv, Kvf) → CAELUS class (identifies the pattern type) → Km value via K-C → NWS okta category → display label. CAELUS tells us the sky's *character* (scattered cumulus vs uniform layer). K-C tells us what that Km *means* in weather terms.

**Why CAELUS over σ(kc):** The original σ(kc) approach (standard deviation of clearness index over a window) conflated cloud *opacity* with cloud *coverage*. CAELUS's four indices capture the *shape* of the irradiance signal — the cumulative absolute first-derivative (Kv, Kvf) measures curve roughness, distinguishing a smooth overcast signal from a jagged broken-cloud signal. σ cannot make this distinction.

**Scientific foundation:** Ruiz-Arias & Gueymard validated CAELUS on 54 BSRN stations across all major climate zones. Threshold constants from CAELUS Table 3 (`options.py` in the reference implementation at github.com/jararias/caelus). K-C validated on decades of ground-based observations correlating radiation with human sky observations.

**Why rejected alternatives:**
- **Provider cloud cover only** (Option B): Not always available; some providers default to "Clear" when data is absent. Cannot serve as sole source.
- **Fixed GHI thresholds** (Option C): Ignores solar geometry — 400 W/m² means different things at 10 AM vs 2 PM.
- **Diffuse fraction (D/G)** (Option D): Requires a separate diffuse radiation sensor. Most home weather stations have only a global pyranometer.

### 2. Clear-sky detrending of variability indices

**Decision:** Detrend Kv and Kvf by subtracting the clear-sky model's minute-to-minute change from the observed GHI change before computing the variability metric.

**Why detrending is necessary:** CAELUS uses centered rolling windows in batch mode, which partially suppress the deterministic solar geometry signal (the sun's arc causes GHI to change even under clear skies). Our real-time implementation uses a trailing window — the geometry ramp accumulates unidirectionally. Without explicit detrending, a perfectly clear afternoon produces Kv above the CLOUDLESS threshold, causing false "Mostly Clear" classifications.

**Scientific foundation:** Stein et al. (2012, Sandia SAND2012-3464C) defined the Variability Index as the ratio of measured GHI path length to clear-sky path length — normalizing against the expected signal to isolate cloud effects. Coimbra et al. (2013) established that dividing by clear-sky irradiance produces a near-stationary signal whose fluctuations reflect only atmospheric (cloud) changes. Our delta-subtraction approach achieves the same effect: the deterministic ramp cancels out, leaving only cloud-induced variability.

### 3. Two variability windows (30-min and 10-min)

**Decision:** Compute variability at two timescales — Kv over 30 minutes (coarse) and Kvf over 10 minutes (fine).

**Why two windows:** Kv over 30 minutes captures the overall cloud pattern but smooths out rapid transits. A single fast-moving cumulus cloud crossing the station in 2 minutes barely registers in a 30-minute integral. Kvf over 10 minutes catches these rapid transits. CAELUS uses both: the CLOUD_ENHANCEMENT class requires *both* Kv > 0.20 and Kvf > 0.20, ensuring that the high-frequency variability from cloud-edge scattering is confirmed at both timescales before declaring enhancement.

**Scientific foundation:** This dual-window approach is directly from CAELUS (Ruiz-Arias & Gueymard 2023, Table 3). The 30/10 split is not arbitrary — 30 minutes captures mesoscale cloud patterns (the time for a cloud field to transit a station), while 10 minutes captures individual cloud transits.

### 4. GHI mirroring across sunrise/sunset

**Decision:** Mirror post-sunrise GHI measurements backward across the sunrise boundary using cos(zenith) interpolation to stabilize the rolling statistics during the sunrise transition.

**Why mirroring is necessary:** At sunrise, the trailing 30-minute window has only a few minutes of real data. Under overcast, the sparse sample inflates Km (diffuse radiation at low solar elevation is a high fraction of the small clear-sky reference), producing sunny/scattered labels when the webcam shows heavy overcast. This was observed live on 2026-06-21: GHI 338.6, maxSolarRad 665.2, Km = 0.509 at elevation ~35° under 81% provider cloud cover — engine output "Partly Cloudy" when it should have been "Mostly Cloudy" at minimum.

**Scientific foundation:** CAELUS implements mirroring in `sky_indices.py:mirror_ghi_with_pandas()`. The algorithm uses cos(zenith) as the interpolation axis because at the same cos(zenith), the atmospheric path length is the same — cloud effects on GHI should be similar at symmetric elevations. Linear interpolation from the post-sunrise (cos_z, GHI) relationship estimates what GHI would be at the corresponding pre-sunrise cos(zenith), and the result is negated to create an antisymmetric extension. Our real-time adaptation uses Skyfield for cos(zenith) computation (same ephemeris already loaded for the almanac service).

### 5. SZA < 85° classification guard

**Decision:** When solar elevation is below 5° (solar zenith angle > 85°), the classifier returns no result and the engine falls back to provider cloud cover.

**Why a guard is needed:** At very low solar elevations, pyranometer measurements become unreliable from three compounding effects: (1) cosine response error — the Davis VP2 specifies ±10% at 70-85° incidence vs ±3% at normal incidence, (2) atmospheric path length — at SZA 85° the path is ~11× overhead, amplifying aerosol and humidity effects, (3) clear-sky model uncertainty — both the weewx model and Ineichen-Perez lose accuracy at extreme zenith angles where small atmospheric parameter errors produce large Kcs errors.

**Why 5° and not 10°:** The literature standard (Engerer 2015, Hyytiälä et al. 2020) uses 10° minimum elevation. CAELUS itself filters at SZA ≥ 85° (elevation < 5°). We start with CAELUS's own threshold for implementation fidelity. With GHI mirroring now handling the sunrise transition, the 5-10° range should be better served than before. If misclassification persists between 5-10° after deployment, the threshold can be tightened.

**Scientific foundation:** Skartveit & Olseth (1987) established early that the clearness index loses discriminatory power at high zenith angles. Engerer (2015) formalized 10° as the standard minimum. CAELUS uses 5° in its implementation.

### 6. SCATTER_CLOUDS sub-splits by Km

**Decision:** Sub-split the SCATTER_CLOUDS catch-all class by Km (mean clearness) to provide more descriptive NWS-vocabulary labels instead of a single "Partly Cloudy" for all scattered conditions.

**Why sub-split:** CAELUS defines SCATTER_CLOUDS as one class — everything that isn't CLOUDLESS, OVERCAST, THIN_CLOUDS, THICK_CLOUDS, or CLOUD_ENHANCEMENT. This single catch-all produces "Partly Cloudy" for conditions ranging from mostly-clear with a few transits (Km > 0.6) to nearly-overcast broken cloud (Km < 0.4). NWS public forecast vocabulary distinguishes these — "Mostly Sunny" and "Partly Cloudy" are different forecasts. Sub-splitting by Km maps Km ranges to the NWS vocabulary.

**User research decisions** (conversation `6e1a3c4c`, 2026-06-19):
- "Scattered Clouds" descriptor pairs with clear-sky labels only: "for scattered clouds you would use 'sunny' or 'clear' or 'mostly sunny' or 'mostly clear' with scattered clouds" (line 229)
- Stops at Partly Cloudy: "once you hit partly cloudy or mostly cloudy, you do not say scattered clouds or broken clouds anymore" (line 240)

**Why K-C sets the boundaries, not CAELUS:** CAELUS does not define sub-splits within SCATTER_CLOUDS — it is one catch-all class. CAELUS's own class boundaries (CLOUDLESS > 0.6, THIN_CLOUDS > 0.5, THICK_CLOUDS < 0.4) describe solar production categories, not weather display categories. Using those boundaries as display-label thresholds produced wrong results: Km 0.85 (which K-C maps to ~5 oktas, BKN, "Mostly Cloudy") was labeled "Sunny, Scattered Clouds" because 0.85 > 0.6. The CAELUS boundary at 0.6 means "good enough for solar production to call it cloudless" — it does NOT mean "the sky looks clear to a person."

K-C provides the correct mapping. The formula `Km = 1 - 0.75 × (N/8)^3.4` was derived from correlating measured radiation with human-observed cloud cover. It tells us what each Km value means in terms of sky coverage:

| K-C boundary | Km | Oktas | NWS category |
|---|---|---|---|
| CLR/FEW | 0.97 | ~2 | Clear → Mostly Clear |
| FEW/SCT | 0.85 | ~4 | Mostly Clear → Partly Cloudy |
| BKN/OVC | 0.52 | ~7 | Mostly Cloudy → Cloudy |

The sub-split thresholds use these K-C boundaries:

| Km range | K-C oktas | Display label |
|---|---|---|
| > 0.97 | 0-2 (CLR/FEW) | Clear, Scattered Clouds |
| 0.85–0.97 | 2-4 (FEW/SCT) | Mostly Clear, Scattered Clouds |
| 0.52–0.85 | 4-7 (SCT/BKN) | Partly Cloudy |
| < 0.52 | 7+ (BKN/OVC) | Mostly Cloudy |

**Sensor noise at the top:** K-C's Clear boundary (Km > 0.99) is inside consumer sensor noise (Davis ±3-5%). But within SCATTER_CLOUDS, Kv ≥ 0.03 — there IS variability, meaning clouds ARE present. The CLOUDLESS anchor (which requires Kv < 0.03) handles truly clear skies. The SCATTER_CLOUDS sub-splits only fire when the CAELUS engine has already confirmed cloud-induced variability exists. "Clear, Scattered Clouds" at Km > 0.97 means: very high clearness but with confirmed cloud transits — a mostly-blue sky with a few clouds drifting through.

**Operator adjustability:** Thresholds are adjustable via the admin UI. The K-C table is displayed so operators can see what each boundary means in sky coverage terms.

### 7. OVERCAST sub-splits by Km × Kv

**Decision:** Sub-split the OVERCAST anchor class by Kv (curve roughness) to distinguish uniform overcast from textured thick cloud.

**Why sub-split:** The initial one-label OVERCAST mapping lost needed granularity. User: "we got rid of some classifications we needed like overcast and heavy overcast" (conversation `6e1a3c4c`, line 133).

**Why Kv and not Kcs:** User: "the difference between cloudy and overcast has to do with the shape of the curve" (line 142) and "i don't like using Kc as it is just a snapshot in time" (line 201). Kv measures curve roughness over the full window — a flat curve (low Kv, uniform blanket) vs a bumpy curve (higher Kv, textured thick deck). User confirmed: "if we think Kv is a decent measure of roughness, then lets use it" (line 215).

### 8. CLOUD_ENHANCEMENT → "Clear"

**Decision:** Map the CLOUD_ENHANCEMENT class to "Clear" (day: "Sunny") instead of the original "Partly Cloudy."

**Why "Clear":** During cloud enhancement, GHI exceeds clear-sky levels (Kcs > 1.06). This means the sun IS definitively visible — cloud edges are scattering extra light toward the sensor. The sun being visible is the defining characteristic of "Sunny" in NWS vocabulary. Cloud enhancement physically requires clear line-of-sight to the sun plus nearby clouds; the sun dominates.

**User research:** User's external research found Class 6 → "Mostly Sunny or Sunny" (conversation `6e1a3c4c`, line 153). User caveat: "no let's not assume what I found is source of truth" (line 159). Cross-checked against NWS Directive 10-503: "Sunny" = dominant sun visibility. The cloud enhancement condition (Kcs > 1.06) is a stronger signal of sun visibility than any NWS category — it means the sun is not just visible but producing *more* light than a clear sky alone.

**Scientific foundation:** Tapakis & Charalambides (2014) documented cloud-edge enhancement producing GHI up to 1.4× clear-sky. CAELUS's Kcs > 1.06 threshold is conservative — 6% above clear-sky, well beyond sensor noise.

### 9. Provider cloud cover fallback

**Decision:** When solar classification is unavailable (night, twilight, SZA guard, no pyranometer), fall back to provider-reported cloud cover percentage mapped to NWS sky categories.

**Why NWS ASOS categories:** FAA Order 7900.5D §12.4 defines the standard mapping from cloud cover percentage to sky condition codes (CLR/FEW/SCT/BKN/OVC). These are the standard used by every METAR-reporting station worldwide. Using a non-standard mapping would produce labels inconsistent with what a nearby airport reports.

**Why provider text takes priority over cloud percentage:** Providers sometimes report conditions that cloud percentage alone cannot express: "Fog", "Freezing Fog", "Haze", "Smoke", "Blowing Snow." Cloud percentage gives "Overcast" for fog — technically correct but missing the critical "fog" information. When the provider supplies descriptive text, it is more informative than a percentage.

### 10. Precipitation: local gauge primary, wet-bulb filter for frozen type

**Decision:** Use the local rain gauge as the primary precipitation source. When a provider reports frozen precipitation type (snow, freezing rain, sleet), accept it only if the Stull (2011) wet-bulb temperature is ≤ 35°F (1.7°C).

**Why local over provider:** Rain gauges measure actual precipitation at the station. Provider data is a forecast/model output — it may report rain when conditions are dry, or vice versa.

**Why wet-bulb filter:** Rain gauges cannot distinguish rain from snow. The provider's precipitation type is the only source for this. But provider forecasts can be wrong — they may forecast snow when ground temperatures are too warm. The wet-bulb temperature (Stull 2011) is the thermodynamic limit: above 35°F wet-bulb, frozen precipitation is physically implausible regardless of what the forecast says. This prevents the engine from displaying "Snow" during a warm rain because a stale forecast said "snow."

**Scientific foundation:** Stull (2011) published an empirical wet-bulb formula requiring only dry-bulb temperature and relative humidity — no additional sensors needed. The 35°F threshold is the standard meteorological rain/snow boundary.

### 11. Temperature-comfort: 2D matrix (appTemp × dewpoint)

**Decision:** Use a two-dimensional matrix combining apparent temperature (wind chill / heat index) with dewpoint to produce a composite comfort descriptor.

**Why 2D instead of 1D:** The original design used dewpoint alone, which cannot express thermal comfort — 55°F dewpoint feels very different at 65°F air temperature vs 95°F. Apparent temperature (`appTemp`) accounts for both wind chill and heat index, giving a unified metric. Dewpoint is independent of air temperature and is the standard measure of atmospheric moisture loading (NWS, AMS). The two axes are independent and physically meaningful.

**Why NWS danger escalation overrides:** NWS Heat Index Chart and Wind Chill Chart define danger thresholds that are nationally recognized public safety standards. When heat index or wind chill reaches danger levels, the temperature-comfort label must reflect this regardless of what the matrix would produce.

### 12. Day/night display vocabulary

**Decision:** Use NWS Directive 10-503 day/night vocabulary: "Sunny"/"Mostly Sunny" during the day, "Clear"/"Mostly Clear" at night. "Partly Cloudy" and denser labels are the same day and night.

**Why NWS vocabulary:** Consistency with what every NWS forecast product uses. A visitor who checks weather.gov and then our dashboard should see the same vocabulary for the same conditions.

### 13. Temporal coherence filter (15-min persistence)

**Decision:** A raw classification must persist for 15 consecutive minutes before becoming the stable displayed label. 3-minute grace on startup.

**Why not per-threshold hysteresis:** The original σ(kc) system used per-threshold hysteresis bands. With the CAELUS system, the classification is a discrete label from a decision tree, not a continuous value crossing a threshold. Hysteresis doesn't map cleanly. CAELUS uses batch "patch cleaning" to remove isolated one-minute classifications. Our streaming adaptation holds the label stable for 15 minutes.

**Why 15 minutes:** Mesoscale cloud patterns (the overall character of the sky — scattered vs overcast) persist for 15+ minutes. Individual cumulus clouds transit a station in 2-5 minutes, but the sky character does not change that fast. 15 minutes filters out individual-cloud noise while tracking real transitions.

### 14. Haze/smoke detection — known unimplemented gap

**Decision:** The ADR originally described a detection heuristic (low kc + low σ + clear provider + high temp/low humidity → "Hazy"/"Smoky"). This has NOT been implemented.

**Why deferred:** The PM2.5 > 35 µg/m³ threshold cited in the heuristic is too low for regions with high baseline AQI. Wildfire smoke detection requires AQI cross-referencing — a fundamentally different data path (provider AQI endpoint, not the pyranometer). The heuristic needs further research on reliable thresholds across diverse geographies before implementation.

---

## Consequences

- No new Python dependencies for sky classification. `sky_condition.py` uses only stdlib (`collections`, `time`, `typing`, `math`, `bisect`). Skyfield (already a dependency for the almanac service) is used for solar position computation in the SZA guard and GHI mirroring.
- pvlib-python is NOT required — weewx's `maxSolarRad` serves as the clear-sky reference.
- Sensor-agnostic: CAELUS thresholds validated across 54 BSRN stations with diverse equipment.
- Startup backfill from archive records provides immediate classification on restart.
- Operator-adjustable sub-split thresholds accommodate diverse sensor accuracy.
- Provider fallback ensures sky labels are always available (night, twilight, no pyranometer).

---

## References

Full citations with DOIs in `docs/reference/sky-classification-science.md`. Key sources:

- Ruiz-Arias & Gueymard (2023) — CAELUS classification system. *Solar Energy* 263, 111895.
- Stein et al. (2012) — Variability Index, clear-sky detrending. Sandia SAND2012-3464C.
- Coimbra et al. (2013) — Clear-sky index stationarity. In *Solar Energy Forecasting and Resource Assessment*, Ch. 8.
- Kasten & Czeplak (1980) — Cloud cover to Km formula. *Solar Energy* 24(2), 177-189.
- Stull (2011) — Wet-bulb temperature formula. *J. Applied Meteorology and Climatology* 50(11).
- Tapakis & Charalambides (2014) — Cloud-edge enhancement. *Renewable Energy* 62.
- Engerer (2015) — Minimum solar elevation standard. *Solar Energy* 116.
- Skartveit & Olseth (1987) — Clearness index at high zenith. *Solar Energy* 38(4).
- Duchon & O'Malley (1999) — Single-point kc limitations. *J. Applied Meteorology* 38.
- NWS Directive 10-503 — Public forecast display vocabulary.
- FAA Order 7900.5D §12.4 — ASOS sky condition categories.
- NWS Heat Index Chart, Wind Chill Chart — Danger thresholds.
- AMS Glossary of Meteorology — Rain rate classification, Beaufort scale.
- WMO (2018) Guide No. 8, Chapter 15 — Meteorological instruments.
- ISO 9060:2018 — Pyranometer classification (sensor accuracy context).

## Out of scope

- Cloud type classification (cirrus vs. cumulus vs. stratus) — beyond weather display needs.
- Diffuse fraction analysis — requires hardware most home stations lack.
- Real-time turbidity measurement — requires sun photometer.
- Probabilistic sky condition (confidence intervals) — display needs a single label.
