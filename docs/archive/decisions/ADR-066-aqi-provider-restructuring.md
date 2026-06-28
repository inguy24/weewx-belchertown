---
status: Archived — consolidated into PROVIDER-MANUAL.md + API-MANUAL.md
date: 2026-06-21
deciders: shane
supersedes:
superseded-by:
---

# ADR-066: AQI Provider Restructuring for Observed Data

## Context

Haze confirmation (ADR-067) requires *observed* PM2.5/PM10 concentrations — actual measurements from monitoring stations, not model predictions. The current AQI provider set includes two model-based sources that return forecast PM, not observations:

- **OWM:** Uses the SILAM atmospheric dispersion model. Returns predicted PM, not measured. Research file `aqi-historical-data-survey.md` §Provider landscape confirms "SILAM forecast MODEL — predicted, not observed."
- **Open-Meteo:** Uses the CAMS global atmospheric composition model. Same limitation as OWM.

Neither can confirm that particulate matter is physically present at the station right now — they predict what *should* be present based on emissions inventories and atmospheric transport modeling. For haze detection, where the question is "are particles scattering light at this location *now*?", model output is not evidence.

One observed-data provider is available and already implemented:

- **Aeris/Xweather:** Already in the API for both forecasts and AQI (auth/client pattern exists). Returns observed AQI from blended real-time monitoring networks with raw PM2.5/PM10 in µg/m³. Low latency (minutes). Best real-time source per `aqi-historical-data-survey.md`.

AirNow was evaluated and excluded (2026-06-21): the AirNow real-time observation API (`/aq/observation/latLong/current/`) returns per-pollutant AQI index values (0-500 integer), NOT raw concentrations in µg/m³. Haze detection requires raw PM2.5 in µg/m³ for threshold comparison (PM2.5 > 12 µg/m³). Reverse-calculating concentrations from AQI breakpoints introduces quantization error that makes the threshold unreliable. AirNow's *bulk CSV downloads* (EPA AQS annual files from `aqs.epa.gov`) DO contain raw hourly µg/m³ and remain a viable data source for the auto-calibration bootstrap (ADR-068).

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Drop OWM, retain Open-Meteo as non-haze-eligible (chosen) | Preserves existing Open-Meteo for operators who use it for general AQI display; clear observed/model boundary; Aeris AQI already implemented | Open-Meteo remains despite being model-based; requires documenting the distinction |
| Drop both OWM and Open-Meteo | Cleaner — only observed sources remain | Removes a working feature from operators currently using Open-Meteo for AQI display |
| Add AirNow as real-time provider | US EPA regulatory data; free | **Excluded** — AirNow real-time API returns AQI index values (0-500), not raw µg/m³ concentrations. Cannot supply PM2.5 for haze threshold comparison. EPA AQS bulk CSVs retained for bootstrap only. |
| Keep all existing, add new | No breaking changes | Operators may unknowingly configure a model-based provider for haze, getting false confidence |

## Decision

Option 1. Drop OWM AQI (deprecate with warning, remove in next major). Retain Open-Meteo AQI but designate it as **not haze-eligible** — operators can use it for general AQI display, but the haze detection engine will not accept PM data from model-based providers as confirmation evidence. IQAir retained (hybrid: monitors + crowd-sourced; observed data). Aeris AQI already implemented and is the primary observed-data source.

AirNow excluded as a real-time provider — its observation API returns AQI index values, not raw µg/m³ concentrations needed for haze thresholds. EPA AQS bulk CSV downloads (which DO contain raw µg/m³) remain a valid data source for the auto-calibration bootstrap (ADR-068).

Every AQI provider module gains a boolean capability flag `is_observed_source` that the haze engine checks before accepting PM data for confirmation.

## Consequences

- **Existing module confirmed:** `providers/aqi/aeris.py` — already fully implemented, returns raw PM2.5/PM10 in µg/m³ from observed monitoring networks.
- **Deprecated:** `providers/aqi/openweathermap.py` — logs deprecation warning when configured, continues to function. Removed in next major version.
- **Provider capability extension:** `ProviderCapability` gains `is_observed_source: bool`. Aeris=True, IQAir=True, Open-Meteo=False, OWM=False.
- **Wizard/admin UI:** Provider selection dropdown shows Aeris, IQAir, Open-Meteo. OWM shows "(deprecated)". Haze-eligible providers marked.
- **PROVIDER-MANUAL.md:** Updated Aeris AQI section. Observed-vs-model classification table. OWM AQI marked deprecated.
- **No breaking change for existing operators** — Open-Meteo continues working for AQI display. OWM continues working with deprecation warning.

## Acceptance criteria

- [ ] Aeris AQI `fetch()` returns `AQIReading` with `pollutantPM25` and `pollutantPM10` in ug/m3 from observed data
- [ ] OWM AQI module logs deprecation warning at startup when configured; continues to function
- [ ] `ProviderCapability.is_observed_source` is True for Aeris, IQAir; False for Open-Meteo, OWM
- [ ] Haze detection engine (ADR-067) only accepts PM from providers where `is_observed_source=True`
- [ ] Wizard and admin UI show updated provider list with observed/model designation
- [ ] PROVIDER-MANUAL.md updated with observed-vs-model classification table, OWM deprecated

## Implementation guidance

- **Aeris AQI module:** Already fully implemented at `providers/aqi/aeris.py`. Returns raw PM2.5/PM10 in µg/m³ from blended real-time monitoring networks. Reuses existing Aeris client_id/client_secret credentials.
- **Deprecation pattern:** OWM module adds `warnings.warn("OWM AQI is deprecated...", DeprecationWarning)` at module load. Logger warning at startup. Provider remains functional.
- **`is_observed_source` flag:** Added to `ProviderCapability` dataclass. Default `True` — Open-Meteo and OWM explicitly set `False`. Checked by haze engine before accepting PM for confirmation.
- **AirNow excluded from real-time:** The AirNow observation API returns AQI index values (0-500), not raw µg/m³ concentrations. Reverse-calculating from breakpoints introduces quantization error unsuitable for the 12 µg/m³ haze threshold. EPA AQS bulk CSV downloads (which contain raw µg/m³) remain valid for bootstrap (ADR-068).
- **Out of scope:** Aeris historical archive endpoint (deferred to ADR-068). Bootstrap CSV import (ADR-068).

## References

- Research: `docs/reference/haze-physics/aqi-historical-data-survey.md` — provider landscape, endpoints, rate limits, data availability
- Research: plan §A.5 — AQI provider data quality for haze detection (Aeris = best real-time, OWM/Open-Meteo = model-based)
- Related ADRs: ADR-013 (archived, AQI handling), ADR-059 (archived, multi-jurisdiction AQI), ADR-067 (haze detection architecture)
- Existing code: `providers/aqi/openmeteo.py` (reference pattern), `providers/forecast/aeris.py` (Aeris auth pattern)
