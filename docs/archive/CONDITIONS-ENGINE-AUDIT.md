# Conditions Text Engine — Current State Audit

**Date:** 2026-06-21
**Purpose:** Full documentation of the as-built conditions engine. This audit was created during the investigation that led to SKY-ENGINE-MIRRORING-PLAN.md. Key finding: the sub-splits (SCATTER_CLOUDS Km, OVERCAST Km×Kv, Cloud Enhancement label) were researched and approved by the user in conversation `6e1a3c4c` (2026-06-19) — they are NOT fabricated, they are undocumented research decisions. The "divergences" listed below are divergences from the STALE ADR, not from user intent.

**Related:** `docs/planning/SKY-ENGINE-MIRRORING-PLAN.md` — the execution plan to fix the issues found here.

---

## 1. System Overview

The conditions text engine produces the `weatherText` field on every `GET /api/v1/current` response. It composes a natural-language string from four independent components:

```
[temperature-comfort] , [sky condition] , with [wind] / [precipitation]

Example: "Pleasant and Humid, Partly Cloudy, with Very Light Breeze"
```

### Module map

| Module | File | Role |
|--------|------|------|
| Sky classifier | `sse/sky_condition.py` | Stateful — 30-min ring buffer of 1-min GHI averages, CAELUS VI classification |
| Composer | `sse/conditions_text.py` | Stateless — assembles weatherText from component labels |
| Enrichment adapter | `sse/enrichment/weather_text.py` | Reads smoothed inputs + sky class, calls composer, injects into /current response |
| Input smoother | `sse/enrichment/input_smoother.py` | Rolling-average ring buffers for stability |
| Temperature-comfort | `sse/temperature_comfort.py` | Stateful 2D matrix — maps (appTemp, dewpoint) to comfort label |

---

## 2. CAELUS Scientific Classification (What the Science Says)

Source: Ruiz-Arias & Gueymard (2023), Solar Energy 263, 111895. Validated on 54 BSRN stations.

CAELUS defines **six sky type classes** from four indices (Kcs, Km, Kv, Kvf). The classes describe the *type of cloud pattern* as detected by a pyranometer. CAELUS does NOT define weather display labels — it classifies irradiance patterns.

### CAELUS Km × Kv classification space

```
Kv
(variability)
 0.25 ┤
      │                                           ┌──────────────┐
 0.20 ┤ · · · · · · · · · · · · · · · · · · · · · │ CLOUD_ENHANC │
      │                                           │  Kcs > 1.06  │
      │              ┌──────────┐                  │  Kv > 0.20   │
 0.16 ┤              │          │                  │  Kvf > 0.20  │
      │              │  THICK   │                  └──────────────┘
      │              │  CLOUDS  │
      │              │ Km < 0.4 │    S C A T T E R _ C L O U D S
 0.10 ┤──────────┐   │ Kv 0.04  │
      │          │   │  -0.16   │    (everything else in the
 0.08 ┤ OVERCAST │   └──────────┘     "cloudy zone" — the catch-all
      │          │          ┌──────────────────┐    residual after anchors
      │ Km < 0.3 │          │   THIN_CLOUDS    │    and named classes)
 0.04 ┤ Kv < 0.10│          │   Km > 0.5       │
 0.03 ┤          │          │   Kv 0.03-0.08   │  ┌──────────────────┐
      │          │          └──────────────────┘  │    CLOUDLESS      │
      │          │                                │  Km > 0.6         │
 0.00 ┤──────────┘                                │  Kcs [0.85, 1.15] │
      └───┬──────┬──────┬──────┬──────┬──────┬──  │  Kv < 0.03        │
         0.0   0.2    0.3    0.4    0.5    0.6    └──────────────────┘
                              Km (mean clearness) ──────────────────►
```

**Key:** CAELUS classifies *irradiance patterns*, not NWS sky conditions. The six classes are:

| CAELUS class | What it means physically |
|---|---|
| CLOUDLESS | No clouds, stable high irradiance |
| CLOUD_ENHANCEMENT | Sun visible, cloud edges scattering extra light — nearby clouds present |
| THIN_CLOUDS | Light dimming, slight variability — cirrus, haze |
| SCATTER_CLOUDS | Catch-all residual — broken cloud field, moderate variability |
| THICK_CLOUDS | Heavy cloud with some breaks |
| OVERCAST | Thick uniform cover, smooth signal |

CAELUS does NOT define sub-splits within any class. Each class is one category.

---

## 3. ADR-044 Approved Mapping (What We Decided)

ADR-044 (amended 2026-06-18) defines the mapping from CAELUS classes to NWS display labels:

### Approved CAELUS → Display label mapping

| CAELUS class | ADR-044 display label |
|---|---|
| CLOUDLESS | Clear |
| CLOUD_ENHANCEMENT | Partly Cloudy |
| THIN_CLOUDS | Mostly Clear |
| SCATTER_CLOUDS | **Partly Cloudy** |
| THICK_CLOUDS | Mostly Cloudy |
| OVERCAST | **Cloudy** |

**Approved return value set (ADR-044 + VI Plan QC Gate 3):**
`"Clear"`, `"Mostly Clear"`, `"Partly Cloudy"`, `"Mostly Cloudy"`, `"Cloudy"`, `None`

Day/night vocabulary (ADR-044 §2):

| Classification | Day | Night |
|---|---|---|
| Clear | Sunny | Clear |
| Mostly Clear | Mostly Sunny | Mostly Clear |
| Partly Cloudy | Partly Cloudy | Partly Cloudy |
| Mostly Cloudy | Mostly Cloudy | Mostly Cloudy |
| Cloudy | Cloudy | Cloudy |

### Approved provider fallback thresholds (ADR-044 §1b)

NWS ASOS/METAR categories (FAA Order 7900.5D §12.4):

| Cloud cover % | ASOS code | ADR display label |
|---|---|---|
| 0–6% | CLR | Clear |
| 7–31% | FEW | Mostly Clear |
| 32–56% | SCT | Partly Cloudy |
| 57–87% | BKN | Mostly Cloudy |
| 88–100% | OVC | Cloudy |

---

## 4. Code Actual Behavior (What's Running)

### 4a. Sky classifier — fabricated SCATTER_CLOUDS sub-splits

`sky_condition.py` lines 452–460: The SCATTER_CLOUDS catch-all has **invented Km sub-splits** that are NOT in CAELUS, NOT in the ADR, and have NO scientific basis:

| Km range | Code returns | ADR says | Source |
|---|---|---|---|
| > 0.6 | "Clear, Scattered Clouds" | "Partly Cloudy" | **FABRICATED** |
| 0.5–0.6 | "Mostly Clear, Scattered Clouds" | "Partly Cloudy" | **FABRICATED** |
| 0.4–0.5 | "Partly Cloudy" | "Partly Cloudy" | Correct |
| < 0.4 | "Mostly Cloudy" | "Partly Cloudy" | **FABRICATED** |

### 4b. Sky classifier — fabricated OVERCAST sub-splits

`sky_condition.py` lines 424–431: The OVERCAST zone (Km < 0.3, Kv < 0.10) has **invented Km×Kv sub-splits**:

| Km | Kv | Code returns | ADR says | Source |
|---|---|---|---|---|
| 0.15–0.30 | ≥ 0.03 | "Cloudy" | "Cloudy" | Correct |
| 0.15–0.30 | < 0.03 | "Overcast" | "Cloudy" | **FABRICATED** |
| < 0.15 | ≥ 0.03 | "Overcast" | "Cloudy" | **FABRICATED** |
| < 0.15 | < 0.03 | "Heavy Overcast" | "Cloudy" | **FABRICATED** |

### 4c. Sky classifier — wrong CLOUD_ENHANCEMENT label

`sky_condition.py` line 418: CLOUD_ENHANCEMENT returns `"Clear"`.

| Code returns | ADR says | Source |
|---|---|---|
| "Clear" | "Partly Cloudy" | **WRONG** — cloud enhancement means nearby clouds with sun |

### 4d. Code classification in Km × Kv space (what's actually running)

```
Kv
 0.25 ┤
      │                                            "Clear" (WRONG)
 0.20 ┤ · · · · · · · · · · · · · · · · · · · · ·  CLOUD_ENHANCEMENT
      │                                             (ADR says Partly Cloudy)
      │              ┌──────────┐
 0.16 ┤              │"Mostly   │
      │              │ Cloudy"  │  Km>0.6: "Clear, Scattered Clouds" (FABRICATED)
      │              │          │  Km 0.5-0.6: "Mostly Clear, Scat.." (FABRICATED)
      │              │ THICK    │  Km 0.4-0.5: "Partly Cloudy"
 0.10 ┤──────────┐   │ CLOUDS   │  Km <0.4: "Mostly Cloudy" (FABRICATED)
      │ Km×Kv    │   │          │
 0.08 ┤ sub-split│   └──────────┘
      │ (FABR.)  │          ┌──────────────────┐
      │          │          │  "Mostly Clear"   │
 0.04 ┤ See 4b   │          │   THIN_CLOUDS     │
 0.03 ┤ table    │          └──────────────────┘  ┌─────────────────┐
      │          │                                │   "Clear"        │
      │          │                                │   CLOUDLESS      │
 0.00 ┤──────────┘                                └─────────────────┘
      └───┬──────┬──────┬──────┬──────┬──────┬──
         0.0   0.2    0.3    0.4    0.5    0.6
                              Km ──────────────────────────────────►
```

### 4e. Provider fallback — wrong thresholds

`weather_text.py` `_cloud_pct_to_sky()` lines 41–51 uses **different thresholds** than ADR-044 §1b:

| Cloud % range | Code returns | ADR says | Divergence |
|---|---|---|---|
| 0–10% | Clear/Sunny | 0–6% Clear | Threshold shifted +4% |
| 11–25% | Mostly Clear/Sunny | 7–31% Mostly Clear | Both boundaries wrong |
| 26–50% | Partly Cloudy | 32–56% Partly Cloudy | Both boundaries wrong |
| 51–85% | Mostly Cloudy | 57–87% Mostly Cloudy | Both boundaries wrong |
| 86–95% | Cloudy | 88–100% Cloudy | Upper boundary split |
| 96–100% | **Overcast** | 88–100% Cloudy | **"Overcast" label fabricated** |

```
Cloud cover percentage axis:

ADR-044 (NWS ASOS):
 0%     6%    31%         56%          87%        100%
 ├──CLR──┼─FEW──┼──SCT─────┼────BKN─────┼───OVC────┤
 │ Clear │M.Clr │Part.Cldy │ Most.Cldy  │  Cloudy  │

Code (as-built):
 0%    10%   25%     50%          85%    95%  100%
 ├─Clr──┼─MCl──┼─PCld──┼──MCloudy──┼─Cldy─┼─OVC─┤
 │Clear │M.Clr│P.Cldy │ Most.Cldy │Cloudy│Ovcst│
                                           ▲
                                    FABRICATED label
```

### 4f. Actual return value set (code)

The code can return these labels from `sky_condition.classify()`:

- `"Clear"` — CLOUDLESS and CLOUD_ENHANCEMENT (CE is wrong per ADR)
- `"Clear, Scattered Clouds"` — **FABRICATED**, not in ADR
- `"Mostly Clear"` — THIN_CLOUDS
- `"Mostly Clear, Scattered Clouds"` — **FABRICATED**, not in ADR
- `"Partly Cloudy"` — SCATTER_CLOUDS (Km 0.4–0.5 only)
- `"Mostly Cloudy"` — THICK_CLOUDS and SCATTER_CLOUDS (Km < 0.4)
- `"Cloudy"` — OVERCAST sub-split
- `"Overcast"` — **FABRICATED**, not in ADR
- `"Heavy Overcast"` — **FABRICATED**, not in ADR

After day/night vocabulary transform, the fabricated labels become:
- `"Sunny, Scattered Clouds"` — **FABRICATED**
- `"Mostly Sunny, Scattered Clouds"` — **FABRICATED**

---

## 5. NWS Sky Condition Reference

Two NWS classification systems exist. They use different terminology for overlapping coverage ranges.

### 5a. ASOS/METAR (aviation, observation-based)

Source: FAA Order 7900.5D §12.4, FMH-1 Chapter 12.

| Oktas | Coverage | ASOS code | Description |
|---|---|---|---|
| 0 | 0/8 | CLR | Clear |
| 1–2 | 1/8–2/8 | FEW | Few clouds |
| 3–4 | 3/8–4/8 | SCT | Scattered |
| 5–7 | 5/8–7/8 | BKN | Broken |
| 8 | 8/8 | OVC | Overcast |

### 5b. Public forecast (NWS forecast products)

Source: NWS Directive 10-503, NWS Glossary.

| Coverage | Day term | Night term |
|---|---|---|
| 0–1/8 | Sunny | Clear |
| 1/8–3/8 | Mostly Sunny | Mostly Clear |
| 3/8–5/8 | Partly Sunny / Partly Cloudy | Partly Cloudy |
| 5/8–7/8 | Mostly Cloudy | Mostly Cloudy |
| 7/8–8/8 | Cloudy | Cloudy |

### 5c. Overlap chart — ASOS vs Public Forecast

```
Oktas:  0    1    2    3    4    5    6    7    8
        ├────┼────┼────┼────┼────┼────┼────┼────┤

ASOS:   │CLR │  FEW   │  SCT   │    BKN     │OVC│

Public: │Sunny│ Mostly │ Partly │  Mostly    │Cloudy
(Day)   │     │ Sunny  │ Cloudy │  Cloudy    │
```

**Key distinction:** "Scattered" (SCT) is ASOS/METAR terminology for 3–4 oktas. "Partly Cloudy" is public forecast terminology for 3–5 oktas. They overlap in the 3–4 okta range but are NOT identical — "Partly Cloudy" extends to 5 oktas while "Scattered" stops at 4.

"Scattered Clouds" as a standalone display term comes from ASOS observation reports. "Partly Cloudy" comes from NWS public forecasts. They are **different classification systems** and should not be conflated.

---

## 6. Complete Divergence Inventory

Every place the running code differs from the approved ADR-044:

| # | Location | ADR-044 says | Code does | Severity |
|---|---|---|---|---|
| D1 | sky_condition.py:454 | SCATTER_CLOUDS Km>0.6 → "Partly Cloudy" | Returns "Clear, Scattered Clouds" | **Critical** — fabricated label, no science |
| D2 | sky_condition.py:456 | SCATTER_CLOUDS Km 0.5-0.6 → "Partly Cloudy" | Returns "Mostly Clear, Scattered Clouds" | **Critical** — fabricated label, no science |
| D3 | sky_condition.py:460 | SCATTER_CLOUDS Km<0.4 → "Partly Cloudy" | Returns "Mostly Cloudy" | **Major** — Km sub-split not in CAELUS |
| D4 | sky_condition.py:429 | OVERCAST → "Cloudy" | Returns "Overcast" (sub-split) | **Major** — fabricated sub-split |
| D5 | sky_condition.py:425-426 | OVERCAST → "Cloudy" | Returns "Heavy Overcast" (sub-split) | **Major** — fabricated label |
| D6 | sky_condition.py:418 | CLOUD_ENHANCEMENT → "Partly Cloudy" | Returns "Clear" | **Major** — wrong label |
| D7 | weather_text.py:41 | 0–6% → Clear | ≤10% → Clear | Threshold wrong |
| D8 | weather_text.py:43 | 7–31% → Mostly Clear | 11–25% → Mostly Clear | Both boundaries wrong |
| D9 | weather_text.py:45 | 32–56% → Partly Cloudy | 26–50% → Partly Cloudy | Both boundaries wrong |
| D10 | weather_text.py:47 | 57–87% → Mostly Cloudy | 51–85% → Mostly Cloudy | Both boundaries wrong |
| D11 | weather_text.py:49 | 88–100% → Cloudy | 86–95% → Cloudy | Split into two |
| D12 | weather_text.py:51 | (no label) | >95% → "Overcast" | **Fabricated label** |

### Labels in code that have NO basis in ADR or science

- `"Clear, Scattered Clouds"` — invented
- `"Mostly Clear, Scattered Clouds"` — invented
- `"Overcast"` — not an approved display label (ASOS uses it as a category code, not a display term)
- `"Heavy Overcast"` — invented, not in any NWS vocabulary

---

## 7. The Bug That Triggered This Audit

**Observed 2026-06-21:** Webcam shows heavy thick overcast. Conditions text reads "Pleasant and Humid, Sunny, Scattered Clouds, with Very Light Breeze."

**Trace:** At low solar elevation (shortly after sunrise), GHI and maxSolarRad are both small. Km = GHI/maxSolarRad can be ≈ 0.6 because diffuse radiation at low angles is a high fraction of the small clear-sky reference. The code enters SCATTER_CLOUDS catch-all with Km > 0.6 → returns the fabricated label "Clear, Scattered Clouds" → day vocabulary transforms to "Sunny, Scattered Clouds."

If the code followed the ADR, SCATTER_CLOUDS would return "Partly Cloudy" regardless of Km. But the deeper issue remains: the CAELUS classification itself may be unreliable at very low solar elevations, and the Km sub-splits amplify that unreliability by mapping borderline Km values to sunny labels.

---

## 8. API Manual vs ADR-044 vs Code

The API Manual (`docs/manuals/API-MANUAL.md` §8) documents the FABRICATED sub-splits as if they were approved:

| Item | API Manual | ADR-044 | Code | Which is right? |
|---|---|---|---|---|
| SCATTER_CLOUDS sub-splits | Documents Km sub-splits | No sub-splits | Has sub-splits | **ADR-044** |
| OVERCAST sub-splits | Documents Km×Kv sub-splits | No sub-splits | Has sub-splits | **ADR-044** |
| CLOUD_ENHANCEMENT label | "Clear" | "Partly Cloudy" | "Clear" | **ADR-044** |
| Provider ≤10% → Clear | Documents this | 0–6% → Clear | ≤10% | **ADR-044** |
| Provider >95% → "Overcast" | Documents this | No "Overcast" label | >95% → "Overcast" | **ADR-044** |

The API Manual was updated to match the fabricated code instead of the approved ADR. Both the code AND the manual need to be corrected to match ADR-044.

---

## 9. ARCHITECTURE.md vs ADR-044 vs Code

ARCHITECTURE.md lines 280–282 also document the fabricated sub-splits. Same problem — the architecture doc was synced to the wrong code, not to the ADR.

---

## 10. Summary of Required Corrections

1. **sky_condition.py** — Remove all SCATTER_CLOUDS Km sub-splits. Return "Partly Cloudy" for the entire catch-all. Remove all OVERCAST Km×Kv sub-splits. Return "Cloudy" for the entire OVERCAST zone. Fix CLOUD_ENHANCEMENT to return "Partly Cloudy" instead of "Clear".
2. **weather_text.py** — Fix `_cloud_pct_to_sky()` thresholds to match ADR-044 §1b NWS ASOS categories. Remove "Overcast" label.
3. **API-MANUAL.md §8** — Remove documentation of fabricated sub-splits. Align with ADR-044.
4. **ARCHITECTURE.md** — Remove documentation of fabricated sub-splits. Align with ADR-044.
5. **Investigate low solar elevation reliability** — Separate concern from the fabricated labels. The CAELUS classification may still be unreliable at dawn/dusk regardless of label mapping. This needs its own analysis.
