---
status: Archived — consolidated into API-MANUAL.md
date: 2026-06-21
deciders: shane
supersedes:
superseded-by:
---

# ADR-069: Fog/Mist Detection Rework

## Context

The current fog detection in `weather_text.py` (lines 166-175) uses a single check: T-Td <= 1 deg F. This is 4x too conservative — the ASOS operational standard uses T-Td <= 4 deg F (`fog-detection-literature.md`). The aviation rule-of-thumb is 5 deg F. Single-variable T-Td detection yields ~40% false alarm rate (Izett et al. 2018, PMC6208920).

The fog detection literature (`fog-detection-literature.md`) documents a multi-parameter approach (M14 algorithm from Izett et al. 2018) achieving >90% hit rate with 13% false alarm rate. Key additional parameters: wind speed, net radiation (solar proxy), and temperature trend. All are available from existing weewx sensors and the enrichment pipeline's smoothed inputs.

WMO Code Table 4680 (automated stations) confirms that automated stations use T-Td as the haze/mist/haze discriminator. The ASOS algorithm (`metar-present-weather-codes.md`) discriminates: FG (fog) when visibility < 5/8 SM + T-Td <= 4 deg F; BR (mist) when visibility 5/8-7 SM + T-Td <= 4 deg F; HZ (haze) when visibility < 7 SM + T-Td > 4 deg F.

Without a visibility sensor, we report "conditions favorable for fog" — not confirmed fog. This matches WMO 4680 automated station constraints.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Multi-parameter algorithm (chosen) | >90% hit rate, 13% false alarm; uses sensors we already have; distinguishes fog from mist | More complex than current check; requires wind and solar data in enrichment context |
| Widen T-Td only (to 4 deg F) | Simple change | 40% false alarm rate with single variable; humid-windy-daytime incorrectly classified as fog |
| ML-based fog detection | Could learn station-specific patterns | Requires training data we don't have; non-deterministic; maintenance burden |

## Decision

Replace single-variable T-Td <= 1 deg F with multi-parameter algorithm:

1. **T-Td gate:** Widen to <= 4 deg F (ASOS standard). Reject fog/mist when T-Td > 4 deg F.
2. **Fog/mist split:** T-Td <= 2 deg F = "Foggy"; T-Td 2-4 deg F = "Misty" (aligns with FMH-1 FG/BR distinction).
3. **Wind gate:** "Foggy" only when wind <= 3 m/s (~7 mph / ~11 km/h) (radiation fog forms in calm conditions). "Misty" for 3-7 m/s. Suppress fog/mist above 7 m/s (~15 mph / ~25 km/h) (too turbulent for fog persistence). Detection logic must convert from the operator's configured unit system to m/s before comparison.
4. **Daytime solar suppression:** When solar radiation is significant (Kcs > 0.3) AND T-Td is 2-4 deg F, suppress fog — that's humid air, not fog. T-Td <= 2 deg F can override solar suppression (dense fog persists into daytime).
5. **PM2.5 disambiguation:** When T-Td <= 4 deg F AND PM2.5 > 35 ug/m3, prefer "Hazy" over "Foggy/Misty" — elevated PM in humid conditions indicates particulate haze with moisture, not water-droplet fog.
6. **Rain gate:** Suppress fog/mist during active precipitation (rain already reported; fog label is redundant and potentially incorrect — precipitation fog is a distinct phenomenon).
7. **Fog dissipation tracking:** Suppress fog label after sunrise when Kcs > 0.5 AND T-Td widening beyond 4 deg F. Prevents stale fog label persisting into sunny morning.

## Consequences

- **Replaces:** Lines 166-175 and 244-249 in `weather_text.py` (duplicated fog logic — consolidate into single function).
- **New label:** "Misty" — currently only "Foggy" exists in `conditions_text.py`.
- **WMO code 10 (Mist):** Added to `_derive_weather_code()`. Priority order: precipitation > fog (45) > mist (10) > haze (05) > sky.
- **Wind dependency:** `get_smoothed("windSpeed")` already available in enrichment context (5-min buffer).
- **Solar dependency:** Kcs available from sky classifier. Requires passing Kcs into fog detection or checking `is_daytime()` + radiation threshold.
- **Nighttime advantage:** Fog detection works at night — T-Td, wind, and "no solar radiation" are all available. Nighttime is when radiation fog forms; our hyper-local sensors (station-level T-Td, not airport 10 km away) add genuine value.
- **Irreducible limitation documented:** Without visibility sensor, fog detection reports favorable conditions, not confirmed fog.

## Acceptance criteria

- [ ] T-Td <= 2 deg F + wind <= 3 m/s = "Foggy" (WMO 45)
- [ ] T-Td 2-4 deg F + wind <= 3 m/s = "Misty" (WMO 10)
- [ ] T-Td <= 4 deg F + wind > 7 m/s = neither fog nor mist (suppressed)
- [ ] Daytime + significant solar (Kcs > 0.3) + T-Td 2-4 deg F = NOT fog/mist
- [ ] T-Td <= 4 deg F + PM2.5 > 35 ug/m3 = "Hazy" preferred over "Foggy/Misty"
- [ ] Rain = fog/mist suppressed
- [ ] Fog dissipation: label clears after sunrise when Kcs > 0.5 and T-Td widening
- [ ] Duplicated fog logic in weather_text.py consolidated into single function
- [ ] WMO code 10 (Mist) emitted for mist conditions
- [ ] weatherText shows "Foggy." or "Misty." as separate sentence

## Implementation guidance

- **Consolidate fog logic:** Extract the T-Td check at lines 166-175 and 244-249 of `weather_text.py` into a single `detect_fog_mist(temp, dewpoint, wind_speed, kcs, pm25, rain_rate) -> str | None` function returning "Foggy", "Misty", or None.
- **Wind speed units:** `get_smoothed("windSpeed")` returns values in the operator's configured unit system (US, Metric, or MetricWX). Thresholds must be converted to the active unit system before comparison, or wind speed must be normalized to a common unit (m/s) internally. Reference thresholds from Izett et al. 2018: calm <= 3 m/s (~7 mph / ~11 km/h), moderate <= 7 m/s (~15 mph / ~25 km/h).
- **Solar suppression:** Check `is_daytime()` from sky classifier AND Kcs > 0.3. Don't suppress for T-Td <= 2 deg F (dense fog persists through sunrise).
- **PM disambiguation:** Only apply when PM data is available (not None/stale). If no PM data, fog/mist classification proceeds without this check.
- **Temporal coherence:** Apply existing 15-min persistence filter to fog/mist labels (same as sky classifier). Prevents rapid fog-on/fog-off cycling from T-Td oscillating near threshold.
- **Out of scope:** Fog type classification (radiation vs advection vs precipitation fog — would need upper-air data). Visibility estimation from T-Td + wind (deferred). Fog prediction/forecasting.

## References

- Research: `docs/reference/haze-physics/fog-detection-literature.md` — Izett et al. 2018 (M14 algorithm, >90% hit / 13% FA), WMO criteria, ASOS T-Td <=4 deg F standard
- Research: `docs/reference/nws-text-system/metar-present-weather-codes.md` — ASOS FG/BR/HZ discrimination algorithm, WMO 4677/4680 codes
- Related ADRs: ADR-044 (archived, sky condition classification — current fog override), ADR-067 (haze detection — PM disambiguation), ADR-071 (nighttime mode — local fog retained)
- Existing code: `sse/enrichment/weather_text.py` lines 166-175, 244-249 (current fog logic)
