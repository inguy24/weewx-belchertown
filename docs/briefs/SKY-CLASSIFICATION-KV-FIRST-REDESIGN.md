# Sky Condition Decision Tree Redesign: Kv-First Architecture

**Status:** PROPOSED
**Created:** 2026-06-23
**Supersedes:** The CAELUS decision tree in `SKY-CLASSIFICATION-VI-PLAN.md` Phase 1, Task T1.3
**Component:** API (`weewx-clearskies-api`), file `sky_condition.py`
**Research basis:** `docs/research/sky-classification/` (01–04)

---

## Problem Statement

The current sky condition classifier uses CAELUS's Km-first decision tree. CAELUS was designed for solar energy forecasting (GISPLIT irradiance component separation), not meteorological sky condition reporting. Its class labels are "only orientative" (the authors' words) and its OVERCAST anchor requires Km < 0.3 — a threshold calibrated for thick nimbostratus, not for the NWS definition of "overcast" (8/8 sky coverage regardless of cloud thickness).

**Result:** A uniform marine layer covering 100% of the sky at Km ≈ 0.6 falls through to the SCATTER_CLOUDS catch-all and displays as "Mostly Cloudy" or "Partly Cloudy." The engine confuses cloud optical depth (how much light gets through) with sky coverage fraction (how much sky is covered). These are different measurements.

**Root cause:** The decision tree uses Km (transmittance) as the primary discriminator, with Kv (variability) as a secondary filter in some branches and absent entirely in the catch-all. The NWS defines sky conditions by coverage fraction, not transmittance. Kv is our best proxy for coverage pattern — low Kv means uniform sky (either clear or fully overcast), high Kv means broken sky (gaps, transitions). The tree should be restructured accordingly.

---

## Scientific Basis

Six independent studies confirm the **inverted-U relationship** between cloud fraction and irradiance variability (full citations in `docs/research/sky-classification/03-kv-variability-cloud-science.md` and `04-km-kv-regimes-and-alternatives.md`):

- Variability peaks at ~50% cloud fraction (maximum sun-cloud transitions)
- Variability drops to near-zero at both 0% (clear) and 100% (overcast)
- Physical cause: at 100% coverage, no cloud edges exist to create transitions

This means:
- **Low Kv → either clear OR overcast** (both produce smooth GHI curves)
- **High Kv → intermediate coverage** (broken/scattered clouds creating transitions)
- **Km distinguishes within the low-Kv regime:** high Km = clear, moderate/low Km = overcast

Key papers establishing this framework:
- Duchon & O'Malley (1999): cloud type from pyranometer, stratus = low σ + moderate clearness
- Stein, Hansen & Reno (2012, Sandia): VI = 1 for both clear AND uniform overcast
- Mol & van Heerwaarden (2023): "low variability indicates either clear OR overcast... mean transmittance values then distinguish"
- Xie & Sengupta (2021): "both variability metrics are the highest around 50% sky cover"
- Manninen et al. (2020, Hyytiälä): patchiness (= Kv) as primary discriminator alongside transmittance

---

## What Changes

Only the `_classify_caelus()` function body and its threshold constants change. Everything else in sky_condition.py is retained:

| Component | Status |
|-----------|--------|
| Ring buffer (30-min, 1-min bins) | **Unchanged** |
| Sub-minute accumulator | **Unchanged** |
| Index computation (Kcs, Km, Kv, Kvf) | **EXTENDED** — adds Kmf (10-min mean transmittance) |
| Kv detrending (subtract maxSolarRad delta) | **Unchanged** |
| Sunrise GHI mirroring for Km | **Unchanged** |
| Night/twilight guard | **Unchanged** |
| SZA guard (elevation < 5°) | **Unchanged** |
| Temporal coherence filter | **CHANGED** — 15 min → 5 min |
| Backfill from archive | **Unchanged** |
| `update()`, `classify()`, `is_daytime()`, `reset()` signatures | **Unchanged** |
| `_classify_caelus()` decision tree | **REPLACED** |
| Threshold constants | **REPLACED** |
| Return label set | **EXTENDED** (see §Label Set below) |

---

## The Kv-First Decision Tree

### Step 0: Pre-checks (unchanged)

```
if night/twilight (max(radiation, maxSolarRad) < 20 W/m²):
    → clear ring buffer, return None

if solar_elevation < 5°:
    → return last stable label

if ring buffer < 3 entries:
    → return None (insufficient data)
```

### Step 1: Cloud Enhancement (unchanged, evaluated first)

```
if Kcs > 1.06
   AND Kv > 0.20
   AND Kvf > 0.20
   AND maxSolarRad > 100 W/m²:
    → "Partly Cloudy"
```

Cloud enhancement means GHI exceeds clear-sky — the sun IS visible with nearby cloud edges scattering extra light. This is unambiguously a broken-cloud scenario. Kcs > 1.06 is a unique signal that doesn't fit the Kv-first flow.

### Step 2: Primary Axis — Asymmetric Kv/Kvf Gate (uniform vs. variable sky)

```
if Kv >= KV_UNIFORM (0.05) OR Kvf >= KV_UNIFORM (0.05):
    → VARIABLE SKY → Step 4
else:
    → UNIFORM SKY → Step 3
```

The gate uses **asymmetric sensitivity**: entering the variable branch requires variability in *either* the 30-minute (Kv) or 10-minute (Kvf) window, while entering the uniform branch requires *both* windows to show low variability.

**Why asymmetric:** Declaring "uniform sky" (no breaks) is a strong structural claim — if wrong, a broken sky gets misclassified as "Overcast." That requires sustained evidence across both windows. But detecting variability is immediate — if the last 10 minutes show cloud transits, the sky is broken *now* regardless of what happened 20 minutes ago. A single cloud transit is immediately visible to anyone looking up; "the sky has been completely clear/overcast for a while" needs more evidence.

**KV_UNIFORM = 0.05** — the boundary between "genuinely uniform sky" and "sky showing cloud transitions."

Rationale:
- Above CAELUS's CLOUDLESS_MAX_KV (0.03) to capture thin uniform layers with very slight texture
- Below the point where obvious cloud transits would be visible
- Accounts for consumer-grade pyranometer noise floors (higher than BSRN-grade instruments)
- Validated conceptually against the literature (Kv transition zone 0.03-0.06)
- Needs empirical tuning against our station data

### Step 3: Uniform Sky — Km distinguishes clear vs. overcast

In the uniform branch, Kv has told us the sky is either completely clear or completely covered with a uniform layer. There are NO breaks — that's what low Kv means. Km tells us whether it's clear (high transmittance) or overcast (reduced transmittance), and if overcast, how thick the layer is.

Every non-clear outcome in this branch is **"Overcast"** — because overcast means 8/8 coverage with no gaps, which is exactly what low Kv indicates. Km tells us cloud thickness within the overcast regime, not a different coverage label.

```
Step 3a: CLEAR
    if Km > 0.85 AND Kcs > 0.80:
        → "Clear"

Step 3b: OVERCAST
    if Km > _UNIFORM_HEAVY_MAX_KM (0.35):
        → "Overcast"
        Physical: thin to moderate uniform cloud layer — marine stratus
                  (Km ~0.7), stratocumulus deck (Km ~0.5), altostratus (Km ~0.4)
        NWS: OVC (8/8), no gaps, no breaks
        Perception: gray sky, may be bright (thin) or flat (moderate),
                    but no imminent precipitation expected

Step 3c: HEAVY OVERCAST
    else (Km ≤ 0.35):
        → "Heavy Overcast"
        Physical: thick uniform cloud layer — nimbostratus, deep stratus
        NWS: OVC (8/8), no gaps, no breaks
        Perception: dark, oppressive gray. Strongly correlated with
                    imminent or active precipitation. Visitors interpret
                    this as "stay inside" weather.
```

**Why two overcast tiers:** The NWS uses a single "Cloudy" for all high-coverage conditions, communicating severity through separate forecast elements (precipitation probability, hazard text). We add a thickness split because:

1. The perceptual difference matters for the visitor's day — thin overcast (bright gray marine layer) vs. thick overcast (dark nimbostratus about to rain) affects outdoor plans differently
2. Thick overcast (low Km) correlates strongly with precipitation, while thin overcast (moderate Km) typically does not — this is useful information we have and should communicate
3. The split uses Km WITHIN the uniform branch, not as a coverage discriminator — Kv already established "no breaks" (overcast), Km tells us "how thick"

**Why the label is "Overcast" and not "Cloudy":** The distinction between "Cloudy" and "Overcast" is about whether breaks exist — not about cloud thickness. "Cloudy" (NWS: 87-100%, includes 7/8 BKN) allows for small breaks. "Overcast" (8/8 OVC) means no breaks. Since low Kv = no breaks, every non-clear outcome in the uniform branch is overcast by definition. Using Km to split "Cloudy" from "Overcast" in this branch would repeat the mistake we're fixing — using transmittance where coverage is the question. Km is used here only to split WITHIN the "Overcast" family (thin vs. heavy), not to change the coverage label.

### Step 4: Variable Sky — Kmf distinguishes coverage degree

In the variable branch, variability has told us the sky has breaks — clouds are transiting, creating sun-shadow oscillations. **Kmf** (10-minute mean transmittance) tells us the balance between sun and cloud. The variable branch uses Kmf instead of Km (30-minute) because when the sky has breaks and conditions are actively changing, the last 10 minutes reflect what the visitor sees *now*, not what the sky looked like 20 minutes ago.

```
Step 4a: SCATTERED CLOUDS
    if Kmf > 0.85:
        → "Mostly Clear"
        Physical: mostly sun, few cumulus transits
        NWS: FEW-SCT (1-3/8)

Step 4b: PARTLY CLOUDY
    if Kmf > 0.60:
        → "Partly Cloudy"
        Physical: significant mix of sun and cloud, broken field
        NWS: SCT-BKN (3-6/8)

Step 4c: MOSTLY CLOUDY
    if Kmf > 0.40:
        → "Mostly Cloudy"
        Physical: more cloud than sun, broken deck with infrequent breaks
        NWS: BKN (5-7/8)

Step 4d: CLOUDY
    else (Kmf ≤ 0.40):
        → "Cloudy"
        Physical: heavy cloud cover with small/rare breaks still producing
                  measurable variability. The sky is predominantly covered
                  but not uniform — there ARE gaps, they're just infrequent.
        NWS: BKN-OVC (7-8/8), breaks visible but rare
```

**Why Kmf in the variable branch, Km in the uniform branch:** Same principle as the asymmetric Kv/Kvf gate. The uniform branch declares "no breaks" — a stable structural claim where the 30-minute Km is appropriate. The variable branch has active cloud transits where conditions change minute to minute — the 10-minute Kmf is responsive to what the visitor sees right now.

**Why "Cloudy" appears in the VARIABLE branch:** "Cloudy" (NWS: 87-100%) includes 7/8 BKN — broken coverage where small gaps exist. The visitor looks up and sees cloud everywhere with maybe a sliver of sky at the horizon. There ARE breaks (Kv confirms this), but they're small and rare. This is distinct from "Overcast" (8/8, no breaks at all, low Kv) — the difference is not thickness but whether any gaps exist.

**Why "Mostly Cloudy" only appears in the VARIABLE branch:** "Mostly Cloudy" (NWS: BKN, broken) explicitly means there are gaps in the cloud cover. If Kv is low (uniform), there are no gaps — the label is "Overcast," not "Mostly Cloudy." This is the core fix for the marine layer misclassification.

---

## Complete Decision Flow

```
                            ┌─────────────────┐
                            │  Pre-checks     │
                            │  Night? SZA? <3?│
                            └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │ Cloud Enhance?  │
                            │ Kcs>1.06 + high │──Yes──→ "Partly Cloudy"
                            │ Kv + high Kvf   │
                            └────────┬────────┘
                                     │ No
                            ┌────────▼────────┐
                            │ Kv≥0.05 OR     │
                            │ Kvf≥0.05?      │
                     ┌──No──┤ (Any recent     ├─Yes─┐
                     │      │  variability?)  │     │
                     │      └─────────────────┘     │
              UNIFORM│SKY                    VARIABLE│SKY
              (both windows calm)            (either window active)
                     │                               │
              ┌──────▼──────┐                 ┌──────▼──────┐
              │ Km (30-min) │                 │ Kmf (10-min)│
              │  Km > 0.85  │                 │ Kmf > 0.85  │
              │  + Kcs>0.80 │                 │ → "Mostly   │
              │  → "Clear"  │                 │    Clear"   │
              ├─────────────┤                 ├─────────────┤
              │  Km > 0.35  │                 │ Kmf > 0.60  │
              │→ "Overcast" │                 │ → "Partly   │
              │             │                 │    Cloudy"  │
              ├─────────────┤                 ├─────────────┤
              │  Km ≤ 0.35  │                 │ Kmf > 0.40  │
              │ → "Heavy    │                 │ → "Mostly   │
              │  Overcast"  │                 │    Cloudy"  │
              └─────────────┘                 ├─────────────┤
                                              │ Kmf ≤ 0.40  │
                                              │ → "Cloudy"  │
                                              └─────────────┘
```

---

## Label Set Change

### Current labels (5)
"Clear", "Mostly Clear", "Partly Cloudy", "Mostly Cloudy", "Cloudy"

### Proposed labels (7)
"Clear", "Mostly Clear", "Partly Cloudy", "Mostly Cloudy", "Cloudy", "Overcast", "Heavy Overcast"

### Label semantics

| Label | Coverage | Kv signal | Km range | Branch | Physical meaning |
|-------|----------|-----------|----------|--------|-----------------|
| **Clear** | 0/8 | Both Kv AND Kvf < 0.05 | > 0.85 | Uniform | No clouds |
| **Overcast** | 8/8 | Both Kv AND Kvf < 0.05 | 0.35–0.85 | Uniform | Uniform layer, thin to moderate (marine stratus, altostratus) |
| **Heavy Overcast** | 8/8 | Both Kv AND Kvf < 0.05 | ≤ 0.35 | Uniform | Thick uniform layer (nimbostratus), precipitation likely |
| **Mostly Clear** | 1-3/8 | Kv OR Kvf ≥ 0.05 | Kmf > 0.85 | Variable | Few cloud transits |
| **Partly Cloudy** | 3-6/8 | Kv OR Kvf ≥ 0.05 | Kmf 0.60–0.85 | Variable | Significant mix of sun and cloud, or cloud enhancement |
| **Mostly Cloudy** | 5-7/8 | Kv OR Kvf ≥ 0.05 | Kmf 0.40–0.60 | Variable | More cloud than sun, breaks visible |
| **Cloudy** | 7-8/8 | Kv OR Kvf ≥ 0.05 | Kmf ≤ 0.40 | Variable | Heavy coverage, variability from gaps or opacity variation |

Key design principles:

1. **"Overcast" only appears in the UNIFORM branch.** Overcast = 8/8 OVC = no breaks. Low Kv confirms no breaks. Km tells us thickness but does not change the label.

2. **"Cloudy" only appears in the VARIABLE branch.** Cloudy (NWS: 87-100%, includes 7/8 BKN) allows for small/rare breaks. High Kv confirms breaks exist, even if rare. This is the high-coverage end of the variable regime.

3. **"Mostly Cloudy" only appears in the VARIABLE branch.** Mostly Cloudy = BKN = broken = gaps visible. If Kv is low, there are no gaps → "Overcast," not "Mostly Cloudy."

4. **The distinction between "Cloudy" and "Overcast" is Kv (breaks), not Km (thickness).** This is the core correction from the CAELUS-based tree.

### Day/night variants

Same conventions as current implementation — handled in `conditions_text.py`:
- "Clear" → "Sunny" (day) / "Clear" (night)
- "Mostly Clear" → "Mostly Sunny" (day) / "Mostly Clear" (night)
- "Overcast" → "Overcast" (both day and night, per NWS convention)
- "Cloudy" → "Cloudy" (both day and night, per NWS convention)

### Downstream impact of new labels

| Consumer | Change needed |
|----------|--------------|
| `scene.py` `_SKY_LABEL_TO_BUCKET` | Add "Overcast" → "cloudy" bucket, "Heavy Overcast" → "storm" bucket |
| `conditions_text.py` `_DAY_LABELS` | Add day/night text for "Overcast" and "Heavy Overcast" (same for both day/night) |
| Dashboard sky label display | Handle new labels in rendering (should already handle arbitrary strings) |
| `DESIGN-MANUAL.md` sky-to-background mapping | Add "Overcast" and "Heavy Overcast" to the mapping table |

---

## Threshold Constants

### Removed (CAELUS Table 3)

All CAELUS-specific constants that gate the old decision tree:
```
_CLOUDLESS_MIN_KM, _CLOUDLESS_MIN_KCS, _CLOUDLESS_MAX_KCS, _CLOUDLESS_MAX_KV
_THINCLOUDS_MIN_KM, _THINCLOUDS_MIN_KV, _THINCLOUDS_MAX_KV
_THICKCLOUDS_MAX_KM, _THICKCLOUDS_MIN_KV, _THICKCLOUDS_MAX_KV
_OVERCAST_MAX_KM, _OVERCAST_MAX_KV
```

### Retained

```python
_KC_MAX = 1.2                   # Kcs ceiling (cloud enhancement clamp)
_MIN_SOLAR_RAD = 20.0           # Night/twilight threshold
_NOISE_FLOOR = 0.0              # Negative radiation rejection
_SZA_GUARD_ELEVATION = 5.0      # Low-sun guard
_SZA80_MSR_PROXY = 100.0        # Cloud enhancement SZA proxy
_CLOUDEN_MIN_KCS = 1.06         # Cloud enhancement Kcs gate
_CLOUDEN_MIN_KV = 0.20          # Cloud enhancement Kv gate
_CLOUDEN_MIN_KVF = 0.20         # Cloud enhancement Kvf gate
_WINDOW_SECONDS = 1800.0        # 30-min rolling window
```

### New

```python
# --- Primary axis: Kv uniform/variable boundary ---
_KV_UNIFORM = 0.05             # Below = uniform sky, above = variable sky

# --- Uniform branch: clear vs. overcast vs. heavy overcast ---
_UNIFORM_CLEAR_MIN_KM = 0.85   # Above = clear sky
_UNIFORM_CLEAR_MIN_KCS = 0.80  # Kcs sanity check for clear
_UNIFORM_HEAVY_MAX_KM = 0.35   # Below = "Heavy Overcast"; above = "Overcast"

# --- Variable branch: Km thresholds for coverage degree ---
_VARIABLE_CLEAR_MIN_KM = 0.85  # Above = "Mostly Clear"
_VARIABLE_PARTLY_MIN_KM = 0.60 # Above = "Partly Cloudy"
_VARIABLE_MOSTLY_MIN_KM = 0.40 # Above = "Mostly Cloudy"
                                 # Below = "Cloudy" (heavy coverage with breaks)
```

---

## Threshold Tuning

These thresholds are derived from physical reasoning and literature review. They are initial estimates — not per-station calibrated values. Per-station calibration is not practical and not the goal. The architecture (Kv-first) is physics-based and universal. The thresholds should work out of the box for most stations; if a threshold is wrong, it's a single constant to adjust after observing the live output.

| Threshold | Initial value | Confidence | Notes |
|-----------|--------------|-----------|-------|
| `_KV_UNIFORM` | 0.05 | Moderate | Most critical threshold. The gap between uniform and variable Kv should be physically wide (inverted-U), so moderate precision is sufficient. May need adjustment for unusually noisy sensors. |
| `_UNIFORM_CLEAR_MIN_KM` | 0.85 | High | Well-established — CAELUS CLOUDLESS uses 0.6 (too permissive for NWS "Clear"). 0.85 = minimal cloud attenuation. |
| `_UNIFORM_HEAVY_MAX_KM` | 0.35 | Moderate | Boundary between "overcast" and "heavy overcast." Below 0.35 correlates with nimbostratus and imminent precipitation. |
| `_VARIABLE_CLEAR_MIN_KM` | 0.85 | High | Same reasoning as uniform clear. |
| `_VARIABLE_PARTLY_MIN_KM` | 0.60 | Moderate | Rough boundary between "significant mix" and "mostly cloud." |
| `_VARIABLE_MOSTLY_MIN_KM` | 0.40 | Moderate | Boundary between "mostly cloudy with obvious breaks" and "cloudy with rare breaks." |

---

## Temporal Coherence Filter

**Changed from 15 minutes to 5 minutes.**

The coherence filter prevents label flicker — a single cloud transit shouldn't bounce the display between "Partly Cloudy" and "Mostly Clear" every minute. A raw classification must persist for the coherence window before becoming the stable (displayed) label.

**Why 15 minutes was too long:** The 30-minute Kv/Km averaging window already provides substantial smoothing. Stacking a 15-minute coherence filter on top creates a worst-case response time of ~45 minutes — a sky that visibly changed half an hour ago still shows the old label. No visitor will accept that; they'll look at the sky, look at the website, and conclude the website is wrong.

**Why 5 minutes:** Still prevents single-transit flicker (a lone cumulus crossing takes 1-3 minutes). But a real trend — clearing, clouding up, marine layer burning off — shows through within 5 minutes of the Kv/Km indices reflecting it. Combined with the asymmetric Kv/Kvf gate (which speeds up variable detection via the 10-minute window), worst-case response drops from ~45 minutes to ~15 minutes.

**Startup grace period:** Reduced proportionally from 3 minutes to 2 minutes.

---

## What We Keep from CAELUS

CAELUS remains the foundation for our system. We are not abandoning it — we are restructuring ONE function (`_classify_caelus`) while keeping the entire infrastructure CAELUS gave us:

1. **Four-index framework** (Kcs, Km, Kv, Kvf) — unchanged
2. **1-minute binning from 5-second LOOP packets** — unchanged
3. **30-minute rolling window** — unchanged
4. **Kv detrending** (subtract maxSolarRad delta to isolate cloud variability) — unchanged
5. **Sunrise GHI mirroring** for Km stability — unchanged
6. **Cloud enhancement detection** via Kcs + high Kv/Kvf — unchanged
7. **Temporal coherence filter** — **reduced from 15 min to 5 min** (see §Temporal Coherence below)
8. **Archive backfill** for startup — unchanged
9. **SZA guard** at low solar elevation — unchanged

What we replace: the CAELUS classification logic that maps (Kcs, Km, Kv, Kvf) → labels. CAELUS's logic was designed for solar energy regimes. Ours is designed for NWS-compatible sky condition reporting, using the same indices but with Kv as the primary discriminator for coverage pattern.

---

## Open Questions

### Q1: Should the uniform branch sub-qualify overcast by thickness?

**Resolved — yes.** Two tiers: "Overcast" (Km > 0.35) and "Heavy Overcast" (Km ≤ 0.35). The perceptual difference matters for visitor outdoor planning — thin overcast (marine layer) means no rain, thick overcast (nimbostratus) correlates with imminent precipitation. The NWS communicates this through separate forecast elements (precipitation probability); we can communicate it through the sky label since we have Km. See Step 3b/3c in the decision tree.

### Q2: Should the Kv threshold have hysteresis?

**Resolved — replaced by asymmetric Kv/Kvf gate.** Instead of explicit hysteresis on a single threshold, the gate uses two windows: entering the variable branch requires *either* Kv or Kvf ≥ 0.05 (responsive — any recent variability triggers it), while entering the uniform branch requires *both* Kv and Kvf < 0.05 (conservative — needs sustained calm). This provides directional asymmetry that serves the same purpose as hysteresis: easy to enter variable (fast response to cloud transits), hard to enter uniform (prevents premature "Overcast" calls). The reduced 5-minute coherence filter handles any remaining flicker.

### Q3: Operator threshold tuning

**Deferred.** Build with the initial threshold estimates, test in production, and see whether operator-configurable thresholds are needed. If so, expose the key constants (KV_UNIFORM, Km boundaries) through api.conf. Do not over-engineer configurability before we know which thresholds need it.

### Q4: Aerosol/haze confusion

Resolved — see §Obstructions to Vision above. The sky condition classifier is strictly about cloud coverage. Haze is handled by the existing `haze_condition.py` module with its own signals (PM concentration + Kcs deficit). Fog is handled by `fog_condition.py` with its own signals (T-Td, wind, PM) and bidirectional provider gate. All compose at the conditions text layer. No aerosol calibration is needed in the sky condition tree.

### Q5: Smoke detection

Resolved — smoke cannot be reliably detected with PWS equipment. Local detection is limited to general haze (PM + Kcs deficit). For smoke specifically, defer to provider weather text. The nighttime deferral in `weather_text.py` already checks for "smoke"/"smoky" keywords in provider text and maps to "Hazy." No dedicated smoke module is needed.

---

## Obstructions to Vision: Fog, Mist, Haze, Smoke

Sky condition (cloud cover) and obstructions to vision (fog, mist, haze, smoke) are **distinct structural components** in the NWS system. Our architecture already treats them this way — `sky_condition.py`, `fog_condition.py`, and `haze_condition.py` are independent modules with independent signals. This section documents how they compose in the display layer.

### Existing modules

| Module | Detects | Signals used | Provider integration |
|--------|---------|-------------|---------------------|
| `sky_condition.py` | Cloud coverage pattern | Kv, Km, Kcs from pyranometer | None — purely local sensor |
| `fog_condition.py` | Fog ("Foggy") and mist ("Misty") | T-Td, wind speed, Kcs, PM2.5 | **Provider cross-check gate**: local T-Td detection must be corroborated by provider weather text mentioning "fog" or "mist." Suppresses marine-layer humidity false positives where T-Td is tight but ground visibility is fine. When provider data is stale/unavailable, local detection stands. When station lacks hygrometer (no dewpoint), defers entirely to provider text. |
| `haze_condition.py` | Haze ("Hazy") | Kcs deficit + PM2.5/PM10 concentration, f(RH) hygroscopic correction | Nighttime deferral to provider text (local Kcs unavailable). Missing-pyranometer deferral to provider text. |

**Priority order** (already established in `weather_text.py` line 68): `precipitation > fog (rime or plain) > mist > haze > sky`

When fog is active, it **replaces the sky label entirely** in `conditions_text.py` (line 264). Haze is also suppressed when fog is active — fog and haze are mutually exclusive (the PM disambiguation gate in `fog_condition.py` already returns "Hazy" for the particulate-haze-masquerading-as-fog case).

### The NWS two-level approach

The NWS structures sky condition (cloud cover) and obstructions to vision (haze, smoke, smog) as **distinct structural components** that combine differently depending on display context:

**Full text forecasts** use a sentence formula that preserves both:
- `[Sky Condition] + with + [Obstruction Coverage] + [Obstruction Type]`
- Example: "Mostly sunny this afternoon with widespread haze."
- Example: "Partly cloudy tonight with patchy smoke."
- Sky condition and obstruction modifiers come from strictly separated vocabulary lists
- Transition phrases use temporal splits: "Sunny then areas of smoke after midnight."

**Terse / icon summaries** (NDFD weather-summary) pick a single dominant descriptor:
- When haze/smoke is the significant weather feature, it **replaces** the sky condition in the summary
- The NDFD summary becomes "Haze" or "Areas Haze" — not "Sunny"
- The sky cover data is still present in the grid but not shown in the terse display

Sources: [NWS Forecast Terms](https://www.weather.gov/ppg/forecast_terms), [NDFD Weather Conditions](https://graphical.weather.gov/xml/xml_fields_icon_weather_conditions.php), [NWS Point Forecast Text Phrases](https://www.weather.gov/eax/pointforecasttextphrase)

### How this maps to our system

Our display has two contexts that match the NWS two-level structure:

| Our context | NWS equivalent | Composition rule |
|-------------|---------------|-----------------|
| **Current conditions card** (hero icon + terse label) | NDFD icon/summary | Obstruction wins when active — "Haze" replaces "Sunny" |
| **Weather text** (full conditions description) | Zone Forecast Product text | Both preserved: "Sunny with haze" |

### Architecture (existing modules, composition logic)

Three independent detection modules feed into the composition layer:

- `sky_condition.classify()` → cloud coverage label ("Clear", "Cloudy", etc.)
- `fog_condition.detect_fog_mist()` → "Foggy", "Misty", "Hazy", or None
- `haze_condition.detect_haze()` → "Hazy" or None

The composition happens in `conditions_text.py` / `weather_text.py`, which already receives all three signals and applies the priority order. The key behaviors:

**Fog/mist already replaces the sky label** in the current code (`conditions_text.py` line 264). When fog is detected and provider-confirmed, "Foggy" or "Misty" becomes the effective sky condition. This is correct NDFD terse behavior — fog is the dominant weather feature and takes over the display.

**Haze currently adds to the sky label** as a modifier but does not replace it in the terse display. This needs updating to match NDFD behavior for the current conditions card.

**Terse display dominance rules** (current conditions card — hero icon + short label):

```
Priority: precipitation > fog > mist > haze > sky condition

For the current conditions card (terse label + hero icon):
  if fog is active (provider-confirmed):
      terse label = "Foggy"
      hero icon  = fog icon (NEW — see below)
  elif mist is active (provider-confirmed):
      terse label = "Misty"
      hero icon  = mist icon (NEW — see below)
  elif haze is active AND sky is clear-ish:
      terse label = "Haze"
      hero icon  = haze icon (NEW — see below)
  else:
      terse label = sky condition label
      hero icon  = sky condition icon (existing)
```

**Full weather text** (detailed display — NWS sentence structure):

```
  if fog/mist is active:
      text = "Foggy" or "Misty" (standalone — replaces sky, already implemented)
  elif haze is active AND sky is clear-ish:
      text = "[Sky condition] with [haze coverage descriptor]"
      e.g., "Sunny with widespread haze"
  else:
      text = sky condition only (existing behavior)
```

### Fog provider gate — bidirectional confirmation

The fog module's provider gate works **both directions** — neither local detection alone nor provider text alone is sufficient. Both must agree:

**Direction 1 — Local fires, provider doesn't:** Marine-layer mornings routinely produce T-Td ≤ 2°F (tight temperature-dewpoint spread), which the local fog algorithm would classify as "Foggy." But the ground-level visibility may be fine; the moisture is in the stratus deck overhead, not at the surface. The provider cross-check suppresses: if the NWS/provider weather text doesn't mention fog or mist, local detection is suppressed (`weather_text.py` lines 231-239).

**Direction 2 — Provider says fog, local doesn't:** The provider may report fog for the broader area, but our station's local sensors (T-Td > 4°F, wind > 7 m/s, or other gates failing) indicate conditions don't support fog at our location. In this case, local detection returns None, and the provider is never consulted — the provider text is only checked as a cross-check when local detection fires, or as a deferral when the station lacks a hygrometer entirely (`weather_text.py` lines 291-301). When local sensors are available and don't support fog, the provider's fog claim is silently ignored.

**Only when local sensors are missing** (no dewpoint / no hygrometer) does the provider become the sole source — the system defers to provider text rather than going blind.

This bidirectional confirmation is critical for coastal stations where the marine layer creates a tight T-Td spread that would false-positive as fog if only local sensors were used, and where a regional provider fog report may not apply to the specific microclimate of the station.

**Interaction with the Kv-first sky classifier:**
- **Marine layer overhead, no surface fog:** Sky = "Cloudy" (low Kv, moderate Km). Fog module fires locally (T-Td tight) but provider doesn't mention fog → fog suppressed → display shows "Cloudy." Correct.
- **Provider says fog, local says no:** Sky = "Cloudy" (low Kv, moderate Km). Local fog detection returns None (T-Td > 4°F) → provider not consulted → display shows "Cloudy." Correct.
- **Actual surface fog:** Sky = unclear (Kcs very low, solar suppressed). Fog module fires locally AND provider mentions fog → fog confirmed → display shows "Foggy." Correct.
- **Marine layer burning off, wisps of fog:** Transitional. Provider may or may not mention fog. Temporal coherence filters on both sides prevent flicker.

### Gap: Obstruction hero icons

**We do not currently have hero icons for fog, mist, or haze conditions.** The current conditions card needs visual representations when obstructions take over the terse display.

| Obstruction | Icon needed | Notes |
|-------------|------------|-------|
| **Fog** | Yes — NEW | Dense fog graphic. Day/night variants likely needed (sun-in-fog vs. moon-in-fog, or a generic fog icon). NWS uses horizontal lines suggesting low visibility. |
| **Mist** | Yes — NEW | Lighter than fog. Could be a thinner variant of the fog icon, or fog icon with more transparency. |
| **Haze** | Yes — NEW | Stylized smog/haze graphic. Horizontal wavy lines or a sun dimmed by atmospheric murk. Day/night variants. |
| **Smoke** | TBD | Not currently detected by a separate module. If smoke detection is added (e.g., from AQI provider "Unhealthy" + specific PM ratios), it would need its own icon. |

The DESIGN-MANUAL's icon family (Phosphor utility + inline Material Symbols SVG hero, per ADR-049/050) needs these variants added. This is a design task for `clearskies-dashboard-dev` and should be tracked as a prerequisite before the terse display dominance logic can ship for haze. Fog/mist already replace the sky label in the text — they just need the icon to match.

### Obstruction coverage descriptors

The NWS uses geographic coverage qualifiers for obstructions to vision that are distinct from cloud cover qualifiers:

| Cloud cover modifier | Obstruction modifier |
|---------------------|---------------------|
| Clear, Mostly Clear, Partly Cloudy, Mostly Cloudy, Cloudy | Patchy, Areas of, Widespread |

Our modules currently return binary labels ("Foggy", "Misty", "Hazy" or None). For full NWS-style text composition, we would need coverage qualifiers. Potential sources:

- **Fog/mist:** Temporal coherence percentage could map to coverage (e.g., < 70% = "Patchy fog", ≥ 70% = "Dense fog" or "Widespread fog")
- **Haze:** PM concentration magnitude or Kcs deficit magnitude could map to coverage (moderate deficit = "Areas of haze", large deficit = "Widespread haze")

This is a future enhancement — for now, unqualified labels ("Foggy", "Hazy") are acceptable for terse display. The full-text composition can use a fixed qualifier (e.g., "with haze") until coverage derivation is implemented.

---

## Verification Plan

### Against current conditions

After implementation, verify against the marine layer case that prompted this redesign:
- Uniform marine layer, Km ≈ 0.55-0.65, Kv ≈ near zero
- Current engine: "Mostly Cloudy" (wrong)
- New engine: "Overcast" (correct — uniform coverage, no breaks)

### Against known-good conditions

Record actual sky conditions alongside engine output for a variety of weather patterns:
- Clear summer afternoon → expect "Clear"
- June gloom marine layer → expect "Overcast"
- Afternoon cumulus buildup → expect progression from "Mostly Clear" to "Partly Cloudy"
- Winter storm thick overcast → expect "Heavy Overcast"
- Post-frontal clearing → expect "Mostly Cloudy" transitioning to "Partly Cloudy"
- Textured stratocumulus (lumpy 8/8) → expect "Cloudy" or "Overcast" depending on Kv

### Against NWS forecast

Compare engine output with NWS public forecast for the station's grid point. While the two won't match perfectly (NWS forecasts are for periods, our classification is real-time), systematic disagreement would indicate threshold problems.

---

## System Lineage — How to Describe the Conditions Engine

For marketing, documentation, and professional credibility. A meteorologist reading these descriptions should immediately recognize the scientific foundations.

### Sky Condition Classifier

**Short:** Modified CAELUS model using Duchon-O'Malley classification architecture, mapped to NWS sky condition vocabulary.

**Full:** A two-parameter pyranometer-based sky condition classifier in the Duchon & O'Malley (1999) tradition — variability-primary, clearness-secondary — using CAELUS-derived indices (Ruiz-Arias & Gueymard 2023) at 1-minute resolution. Four indices (Kcs, Km, Kv, Kvf) computed from a 30-minute rolling window of clear-sky-detrended GHI. Classification uses the inverted-U relationship between cloud fraction and irradiance variability (Xie & Sengupta 2021, Mol et al. 2023) as the primary discriminator: low variability indicates uniform sky (clear or overcast), elevated variability indicates broken coverage. Output labels conform to NWS public forecast vocabulary (Clear through Overcast). Temporal coherence filter prevents label flicker.

### Haze Detection

**Short:** Two-channel aerosol confirmation — broadband AOD estimation with Hänel-Tang hygroscopic correction, confirmed by EPA AQI-threshold PM concentration.

**Full:** Dual-channel sensor fusion requiring both optical and particulate confirmation. Channel 1: Kcs deficit against an auto-calibrated clean-sky baseline measures broadband aerosol optical depth (Ångström tradition, validated against AERONET per Lindfors et al. 2013), with an f(RH) hygroscopic correction (Hänel 1976, Tang 1996, γ = 0.45 composition-unknown default) that adjusts the detection threshold for humidity-driven aerosol swelling. Channel 2: PM2.5/PM10 concentration must exceed EPA AQI breakpoints (12 µg/m³ Moderate for dry haze, 35 µg/m³ for humid disambiguation). Both channels must fire simultaneously. 15-minute temporal coherence filter.

### Fog/Mist Detection

**Short:** Modified ASOS algorithm with PM disambiguation, solar suppression, and bidirectional provider cross-check.

**Full:** Multi-parameter fog/mist detection based on the ASOS T-Td ≤ 4°F standard, extended with: wind gating (> 7 m/s suppresses, 3–7 m/s downgrades fog to mist), PM2.5 disambiguation (near-saturated air with elevated PM2.5 > 35 µg/m³ reclassified as particulate haze rather than water-droplet fog), daytime solar suppression (Kcs > 0.3 suppresses mist candidates — insolation dissolves thin moisture), and bidirectional provider cross-check (local detection must be corroborated by provider weather text; provider claims are ignored when local sensors contradict). 15-minute temporal coherence with majority-vote label selection.

### Obstruction Display Composition

**Short:** NWS NDFD-style terse/full-text dual composition with priority-based dominance.

**Full:** Obstructions to vision (fog, mist, haze) compose with sky condition following NWS conventions. Terse display (current conditions card, hero icon): obstruction replaces sky condition when active, following NDFD weather-summary behavior. Full weather text: both preserved using the NWS Zone Forecast Product sentence formula — "[Sky condition] with [obstruction coverage] [obstruction type]." Priority order: precipitation > fog > mist > haze > sky condition.

---

## References

Research dumps with extended excerpts and analysis at `docs/research/sky-classification/` (01–04).

### Kv-first architecture — the inverted-U relationship

These papers establish that irradiance variability peaks at ~50% cloud fraction and drops to near-zero at both 0% (clear) and 100% (overcast), providing the physical basis for using Kv as the primary discriminator.

- **Xie, Y., Sengupta, M., et al. (2021).** "Improving prediction of surface solar irradiance variability by integrating observed cloud characteristics and machine learning." *Solar Energy*, 226, 442–449. DOI: 10.1016/j.solener.2021.08.050 — "Both variability metrics are the highest around 50% sky cover."

- **Mol, W.B., et al. (2023).** "Reconciling observations of solar irradiance variability with cloud size distributions." *J. Geophys. Res.: Atmospheres*, 128, e2022JD037894. DOI: 10.1029/2022JD037894 — "Low variability indicates either clear OR overcast conditions... mean transmittance values then distinguish between these two scenarios."

- **Mol, W.B., et al. (2025).** "Mechanisms of surface solar irradiance variability under broken clouds." *Atmos. Chem. Phys.*, 25, 4419–4441. DOI: 10.5194/acp-25-4419-2025 — Identifies four physical mechanisms of SSI variability (forward escape, downward escape, side escape, albedo enhancement), all of which require cloud breaks to operate. Explains why variability drops to zero at 100% coverage.

- **Bright, J.M., et al. (2017).** "Cloud cover effect of clear-sky index distributions." *Solar Energy*, 143, 110–117. DOI: 10.1016/j.solener.2016.12.046 — Bimodal clear-sky index distribution at intermediate cloud fractions is the direct cause of high Kv; unimodal at 0% and 100%.

- **Woyte, A., Belmans, R., & Nijs, J. (2007).** "Fluctuations in instantaneous clearness index: Analysis and statistics." *Solar Energy*, 81(2), 195–206. DOI: 10.1016/j.solener.2006.03.001 — Wavelet analysis confirms different cloud types produce energy at different temporal frequency bands; Kv is a time-domain proxy for high-frequency cloud-driven fluctuation.

- **Perez, R., et al. (2016).** "Spatial and Temporal Variability of Solar Energy." *Found. Trends Renew. Energy*, 1(1), 1–44. DOI: 10.1561/2700000006 — "Mixed sky conditions exhibit... notably higher temporal variability... opposed to more stable patterns under clear skies or overcast scenarios."

### Two-axis (Km + Kv) cloud classification

These papers establish that mean transmittance + variability is the standard two-parameter approach for classifying cloud type and coverage from surface radiation measurements.

- **Duchon, C.E. & O'Malley, M.S. (1999).** "Estimating cloud type from pyranometer observations." *J. Appl. Meteor.*, 38(1), 132–141. DOI: 10.1175/1520-0450(1999)038<0132:ECTFPO>2.0.CO;2 — Foundational paper. Seven cloud types from (mean clearness, standard deviation). **Stratus = low σ + moderate clearness; cumulus = high σ + moderate clearness.** 45% agreement with human observers (inherent single-sensor limitation).

- **Calbó, J., González, J-A., & Pagès, D. (2001).** "A method for sky-condition classification from ground-based solar radiation measurements." *J. Appl. Meteor. Clim.*, 40(12), 2193–2200. DOI: 10.1175/1520-0450(2001)040<2193:AMFSCC>2.0.CO;2 — Five-class scheme (overcast, fog/very thick, cloudy, partly cloudy, clear) using clearness index + variability. 58% agreement with human observers.

- **Manninen, A.J., et al. (2020).** "Clouds over Hyytiälä, Finland: an algorithm to classify clouds based on solar radiation and cloud base height measurements." *Atmos. Meas. Tech.*, 13, 5595–5619. DOI: 10.5194/amt-13-5595-2020 — Uses patchiness (= Kv) as primary discriminator alongside transmittance. Low patchiness = "uniformly overcast and clear-sky conditions"; patchiness "increases in partly cloudy conditions." **Directly validates the Kv-first architecture.**

- **Kim, J.T., et al. (2019).** "Identifying overcast, partly cloudy and clear skies by illuminance fluctuations." *Renewable Energy*, 136, 1046–1054. DOI: 10.1016/j.renene.2019.01.076 — Adding fluctuation to clearness-only classification reduces misclassification by 5.7–11.5%.

- **Cheng, Z., et al. (2024).** "A Standardized Sky Condition Classification Method for Multiple Timescales." *Energies*, 17(18), 4616. — The "arrowhead plot" of (clearness index, variability index) naturally separates five classes. A ramp-rate metric alone "fails to distinguish clear-sky and cloudy days."

### Variability index foundations

- **Stein, J.S., Hansen, C.W., & Reno, M.J. (2012).** "The Variability Index: A New and Novel Metric for Quantifying Irradiance and PV Output Variability." Sandia National Laboratories, SAND2012-3464C. OSTI: 1078490 — Defines VI as ratio of measured GHI path length to clear-sky path length. **VI ≈ 1 for both clear AND uniform overcast** (both smooth); VI >> 1 for broken cloud.

- **Inman, R.H., Pedro, H.T.C., & Coimbra, C.F.M. (2013).** "Solar Forecasting Methods for Renewable Energy Integration." *Prog. Energy Combust. Sci.*, 39, 535–576. — Establishes that dividing GHI by clear-sky reference removes deterministic solar geometry, leaving only stochastic cloud-driven signal. Foundation for our Kv detrending.

- **Reno, M.J. & Hansen, C.W. (2016).** "Identification of periods of clear sky irradiance in time series of GHI measurements." *Renewable Energy*, 90, 520–531. DOI: 10.1016/j.renene.2015.12.031 — Line length and standard deviation of rate-of-change (Kv analogs) among the most discriminating features for clear-sky detection.

### Cloud type signatures in GHI

- **Mol, W.B., et al. (2024).** "Observed patterns of surface solar irradiance under cloudy and clear-sky conditions." *Q.J.R. Meteorol. Soc.*, 150(761), 2338–2363. DOI: 10.1002/qj.4712 — Stratus produces "minimal variability unless dissolving"; cumulus shows "fast and frequent transitions between shade and sunshine."

- **Heinle, A., Macke, A., & Srivastav, A. (2010).** "Automatic cloud classification of whole sky images." *Atmos. Meas. Tech.*, 3, 557–567. DOI: 10.5194/amt-3-557-2010 — Stratus identified by low image texture variance — the visual analogue of low Kv.

- **Lusi, A.R., et al. (2024).** "Cloud classification through machine learning and global horizontal irradiance data analysis." *Q.J.R. Meteorol. Soc.* DOI: 10.1002/qj.4880 — ML independently discovers variability features as most important for cloud type classification from GHI.

- **Lave, M. & Kleissl, J. (2013).** "Cloud speed impact on solar variability scaling." *Solar Energy*, 91, 11–21. — Cloud speed modulates Kv magnitude (faster = higher Kv for same coverage), but does not break the binary uniform/variable classification.

### CAELUS — what it is and is not

- **Ruiz-Arias, J.A. & Gueymard, C.A. (2023).** "CAELUS: Classification of sky conditions from 1-min time series of global solar irradiance using variability indices and dynamic thresholds." *Solar Energy*, 263, 111895. DOI: 10.1016/j.solener.2023.111895 — Source of our four-index framework (Kcs, Km, Kv, Kvf) and 1-minute resolution validation across 54 BSRN stations. **Class labels are "only orientative"; classification "cannot be validated" against physical cloud observations.** Designed for GISPLIT irradiance component separation, not weather reporting. GitHub: github.com/jararias/caelus

### NWS sky condition definitions

- **NWS Glossary — Sky Condition.** [forecast.weather.gov/glossary.php?word=sky+condition](https://forecast.weather.gov/glossary.php?word=sky+condition) — "The predominant/average sky condition based upon octants of the sky covered by opaque (not transparent) clouds."

- **NWS Forecast Terms.** [weather.gov/ppg/forecast_terms](https://www.weather.gov/ppg/forecast_terms) — Public forecast label definitions (Clear through Cloudy).

- **NWS Huntsville — ZFP Terminology.** [weather.gov/hun/zfp_terminology](https://www.weather.gov/hun/zfp_terminology) — Zone Forecast Product term definitions.

- **NWS Point Forecast Text Phrases.** [weather.gov/eax/pointforecasttextphrase](https://www.weather.gov/eax/pointforecasttextphrase) — Sentence formula for combining sky condition with obstructions to vision.

- **NDFD Weather Conditions — Icon/Summary Definitions.** [graphical.weather.gov/xml/xml_fields_icon_weather_conditions.php](https://graphical.weather.gov/xml/xml_fields_icon_weather_conditions.php) — Terse weather-summary values; haze/smoke/fog as standalone summaries replacing sky condition in icon display.

### Cloud modification factor and coverage vs. transmittance

- **Mol, W.B., et al. (2024).** (see above) — CMF values by cloud condition: clear 0.992, scattered 0.896, broken 0.728, overcast 0.316. Demonstrates that Km (≈ CMF) spans a wide range under overcast depending on cloud type.

- **NWS Houston — Marine Layer Clouds.** [weather.gov/source/zhu/ZHU_Training_Page/clouds/stratus_form_dissipate/Marine_Layer.html](https://www.weather.gov/source/zhu/ZHU_Training_Page/clouds/stratus_form_dissipate/Marine_Layer.html) — Marine stratus characteristics: high coverage, moderate optical depth, large horizontal extent.
