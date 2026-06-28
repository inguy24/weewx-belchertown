---
status: Archived — consolidated into PROVIDER-MANUAL.md + API-MANUAL.md
date: 2026-06-21
deciders: shane
supersedes:
superseded-by:
---

# ADR-071: Nighttime Mode — Provider Deferral Pattern

## Context

At night (solar elevation <= 0 deg, or below the 10-15 deg haze detection gate from ADR-067), the pyranometer contributes nothing to haze detection. The question is whether to attempt nighttime haze detection from PM data alone, or defer to weather service providers.

Provider observation stations (ASOS/AWOS at airports, EPA reference monitors) have visibility sensors and present weather detectors that consumer PWSs lack. Their PM2.5 data comes from the same monitoring network our AQI providers query. Attempting to re-derive haze from PM alone duplicates the provider's work with less information — they have visibility sensors, we don't.

The exception is fog. Radiation fog forms at night — post-sunset, calm winds, temperature dropping toward dewpoint. Our station-level T-Td measurement (at the PWS location) is genuinely more local than the nearest airport's observation (potentially 10+ km away). Local fog detection adds real value that provider deferral would lose.

The existing engine already defers to providers for nighttime cloud cover. This ADR extends that pattern to haze/smoke while carving out fog/mist as a local-detection exception.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Provider deferral for haze/smoke, local for fog/mist (chosen) | Leverages provider visibility sensors we lack; retains hyper-local fog advantage; consistent with existing nighttime cloud cover pattern | Depends on provider having current conditions data; brief gap at sunrise handoff |
| PM-only nighttime haze | No provider dependency at night | Lower confidence (single channel); duplicates provider's work with less information; PM doesn't distinguish haze intensity |
| Full provider deferral for everything at night | Simplest implementation | Loses local fog advantage — station-level T-Td is more precise than airport observation for radiation fog |

## Decision

Option 1. At night, three distinct channel assignments:

- **Cloud cover:** Provider observation (existing behavior, unchanged).
- **Haze/smoke:** Provider current conditions present weather field. Providers have visibility sensors and present weather detectors — let them do what they're better equipped to do.
- **Fog/mist:** LOCAL multi-parameter detection (ADR-069). T-Td + wind + nighttime flag. This is the one condition we CAN detect locally at night without the pyranometer. Our sensors capture the radiation fog signal (post-sunset, calm, saturated) at the actual station location.

**Sunrise handoff:** When solar elevation crosses the haze detection gate (10-15 deg), the full local model resumes — two-channel haze detection, solar-based fog dissipation tracking, the complete engine. Provider haze/smoke observations stop being authoritative; local detection takes over.

**Why not PM-only haze at night:** Our PM2.5 data comes from the same monitoring network the providers use. The provider already has visibility + PM + present weather detectors to make the haze determination. Our value-add is the pyranometer (extinction measurement) — which only works in sunlight. Without it, we have no information advantage over the provider for haze.

## Consequences

- **Provider data requirement:** Provider current conditions must include a present weather field (e.g., "Haze", "Smoke", "Fog"). Aeris, NWS, and most providers include this. If provider lacks present weather data, nighttime haze detection is unavailable (graceful degradation).
- **Handoff logic:** Solar elevation check triggers mode switch. Brief overlap period (~15 min around gate crossing) where both modes may disagree — local detection takes precedence once gate is crossed.
- **Fog continuity:** Fog detected locally at night transitions smoothly to daytime fog detection. No handoff gap — fog detection doesn't change at sunrise, only adds the solar dissipation check (Kcs > 0.5 = fog clearing).
- **weatherText at night:** Haze/smoke from provider, fog/mist from local, cloud cover from provider. Text composition remains the same.
- **Dashboard:** No visible change — conditions text already handles nighttime. The data source changes but the display does not.

## Acceptance criteria

- [ ] At night (el below detection gate): haze/smoke read from provider current conditions
- [ ] At night: fog/mist detected locally using ADR-069 multi-parameter algorithm
- [ ] At sunrise (el crosses detection gate): full local model resumes for haze detection
- [ ] Fog detection has no handoff gap at sunrise — local detection active continuously
- [ ] Provider haze/smoke absent = no haze reported at night (graceful degradation, not "clear")
- [ ] weatherText correctly composes provider haze + local fog + provider cloud cover at night
- [ ] No duplicate haze reporting (provider + local don't both fire simultaneously during handoff)

## Implementation guidance

- **Solar elevation check:** Reuse `sky_condition.py` elevation calculation. The haze detection gate (10-15 deg) is already needed by ADR-067 — nighttime mode uses the same threshold.
- **Provider present weather:** Read from the forecast/observation provider's current conditions response. The current conditions endpoint already returns a conditions text field — parse for standard present weather keywords (Haze, Smoke, Fog, Mist) or use WMO present weather codes if the provider returns them.
- **Mode state:** Simple enum: `DAYTIME_LOCAL`, `NIGHTTIME_DEFERRED`. Transitions based on solar elevation crossing the gate. Hysteresis not needed — the 10-15 deg gate is already above the horizon, so rapid oscillation doesn't occur.
- **Fog continuity:** `detect_fog_mist()` (ADR-069) runs continuously regardless of mode. It only uses T-Td, wind, and solar (solar suppression is additive, not a gate). At night, solar is zero, so the solar suppression check simply doesn't trigger — fog detection proceeds on T-Td + wind alone.
- **Provider data freshness:** Same stale-data gate as PM (> 2 hours = suppress). If provider data is stale at night, nighttime haze is unavailable — not "no haze."
- **Out of scope:** GOES-16 Band 4 nighttime cirrus detection (future). Provider forecast-as-nowcast for nighttime conditions. PM-only haze estimation at night (explicitly rejected by this ADR).

## References

- Research: `docs/reference/haze-physics/fog-detection-literature.md` — nighttime radiation fog formation, T-Td + wind detection
- Research: `docs/reference/haze-physics/ryan-stolzenbach-model.md` — solar elevation gate rationale (R-S model unreliable below 10 deg)
- Research: `docs/reference/haze-physics/cirrus-vs-aerosol-discrimination.md` — surface PM inadequate for nighttime haze discrimination without pyranometer
- Related ADRs: ADR-067 (haze detection — daytime architecture), ADR-069 (fog/mist detection — local at all hours), ADR-066 (AQI providers — provider current conditions data)
- Existing code: `sse/enrichment/weather_text.py` (existing provider cloud cover fallback at night)
