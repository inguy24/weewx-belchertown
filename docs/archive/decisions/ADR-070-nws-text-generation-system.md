---
status: Archived — consolidated into API-MANUAL.md
date: 2026-06-21
deciders: shane
supersedes:
superseded-by:
---

# ADR-070: NWS-Style Text Generation System

## Context

The current `conditions_text.py` composes a single-verbosity weather text string by joining temperature-comfort, sky condition, wind, and precipitation labels. This works but produces only one text style ("Warm, Mostly Sunny, and Calm") with no structured observation model underneath.

The NWS uses formalized rules to convert observation data to text. Research confirmed (`gfe-text-formatter-assessment.md`) that AWIPS-II's GFE text formatter is open source Python with extractable phrase libraries — ScalarPhrases, WxPhrases, VectorRelatedPhrases are pure Python with no AWIPS imports. Threshold tables are compact (~8 lines for sky, ~30 for temperature, ~10 for wind).

The NWS observation-to-text rules (`observation-text-rules.md`) document specific conventions: "Hazy." as separate sentence, day/night terminology (Sunny/Clear, Partly Sunny/Partly Cloudy), and present weather as separate clause. WMO Code Tables 4677/4680 (`metar-present-weather-codes.md`) provide the standard weather code system for mapping observations to coded format.

Building a structured local observation model (METAR-like) creates a clean intermediate representation between sensors and text — enabling multiple output formats without rewriting the detection logic.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Rules-based with GFE vocabulary extraction (chosen) | Deterministic; NWS-standard phrasing; compact code (~300 lines); extractable from public-domain source | Must maintain rule tables manually; less flexible than generative approaches |
| Template-only system | Simpler implementation | Rigid templates can't handle condition combinations naturally; produces awkward text for edge cases |
| LLM-generated text | Most flexible; handles novel combinations | Non-deterministic (same conditions produce different text); latency (API call per observation); cost; dependency on external service |

## Decision

Rules-based text generation engine with three components:

**1. Structured Local Observation Model (METAR-like)**
Map every local sensor reading and derived value to standard meteorological fields:

| Local source | METAR/WMO field |
|---|---|
| outTemp | Temperature |
| dewpoint | Dewpoint |
| windSpeed + windDir + windGust | Wind group |
| CAELUS sky class | Sky condition (CLR/FEW/SCT/BKN/OVC) |
| Haze detection (ADR-067) | Present weather HZ |
| Fog/mist detection (ADR-069) | Present weather FG/BR |
| Precipitation type + rate | Present weather RA/SN/FZRA etc. |
| barometer + trend | Pressure group |

CAELUS-to-okta mapping: CLOUDLESS->CLR (0), THIN_CLOUDS->FEW/SCT (1-4), SCATTERED->SCT (3-4), MOSTLY_CLOUDY->BKN (5-7), OVERCAST->OVC (8). Specific okta assignment uses Km sub-ranges within each CAELUS class.

**2. Present Weather Code Expansion**
Expand `_derive_weather_code()` to cover the full range of observable phenomena using WMO Code Table 4677/4680:
- Add: 05 (Haze), 10 (Mist), 48 (Depositing rime fog — ice on surfaces + fog)
- Retain: 45 (Fog), 60-69 (rain variants), 70-79 (snow variants), 79 (ice pellets), 96 (thunderstorm)
- Priority: precipitation > thunderstorm > fog > mist > haze > sky

**3. Three Verbosity Levels**
- **Terse:** Current `weatherText` style — "Sunny, Hazy, Warm and Humid." May use compound form "Sunny, Hazy" for brevity.
- **Standard:** NWS one-sentence style — "Sunny. Hazy. Temperature near 85. South winds around 8 mph."
- **Verbose:** Full narrative — "Currently 85 deg F under hazy sunshine. Dew point 72 deg F. South winds around 8 mph."

GFE threshold tables to port:
- Sky coverage: 6 buckets (0-5%, 5-25%, 26-50%, 50-69%, 70-87%, 87-100%)
- Temperature decades: "upper 80s", "lower 20s" (for verbose level)
- Wind descriptors: calm / light / around N / N to M / gusts up to N
- Wind speed thresholds: 25/30/40/50/74 mph category breaks
- Gust qualification: gusts reported when > 10 mph above sustained

NWS phrasing conventions: separate-sentence haze/fog at standard/verbose; "with" for precipitation modifying sky; day/night terminology (Sunny vs Clear, Partly Sunny vs Partly Cloudy).

## Consequences

- **New module:** Observation model struct/dataclass — populated from enrichment state on each observation cycle.
- **Expanded `_derive_weather_code()`:** More WMO codes, priority-ordered.
- **New text engine module:** Rules-based composer with verbosity parameter. Replaces (or wraps) current `build_weather_text()`.
- **API response:** `weatherText` continues to carry terse level (backward compatible). New fields `weatherTextStandard` and `weatherTextVerbose` added to `/api/v1/current` response.
- **Dashboard:** Can select verbosity level. Default: terse (current behavior). Standard/verbose available for cards, Home Assistant, notifications.
- **Observation model:** Intermediate representation enables future: METAR-format output, structured JSON observation, forecast narrative generation (deferred, Track B4).

## Acceptance criteria

- [ ] Structured observation model populated from enrichment state with all mapped fields
- [ ] CAELUS-to-okta mapping produces correct sky condition codes
- [ ] WMO codes 05, 10, 48 added to `_derive_weather_code()` with correct priority
- [ ] Terse level produces output equivalent to current `weatherText` (backward compatible)
- [ ] Standard level produces NWS-convention text with separate-sentence haze/fog
- [ ] Verbose level produces full narrative with temperature, wind, humidity, sky, present weather
- [ ] Day/night terminology correct: "Sunny"/"Clear", "Partly Sunny"/"Partly Cloudy"
- [ ] GFE wind thresholds match AWIPS-II source (25/30/40/50/74 mph)
- [ ] New fields `weatherTextStandard` and `weatherTextVerbose` present in `/api/v1/current`
- [ ] Gust reported when > 10 mph above sustained speed

## Implementation guidance

- **Observation model:** Python dataclass with all fields Optional (nullable). Populated in `weather_text.py` from smoothed inputs + sky classifier + haze/fog detection results. Passed to text engine.
- **Text engine:** New module `sse/text_generation.py` (or equivalent). Takes observation model + verbosity enum, returns text string. Pure function — no state, no side effects. Testable in isolation.
- **GFE vocabulary extraction:** Reference `gfe-text-formatter-assessment.md` for the specific AWIPS-II threshold tables. Port as Python dicts/lists — not as GFE framework integration. ~300 lines of new code estimated.
- **Backward compatibility:** `weatherText` field in API response continues to carry terse output. Existing dashboard code that reads `weatherText` is unchanged. Standard/verbose are additive fields.
- **Unit-aware text rendering:** GFE threshold tables are natively defined in US units (mph, deg F). The text engine must convert thresholds to the operator's configured unit system before rendering text. Wind descriptor thresholds (calm / light / N to M) and temperature decade phrases must adapt to metric equivalents when the operator uses Metric or MetricWX. The source GFE thresholds in mph/deg F are the reference for porting; the rendered output respects operator units.
- **Day/night determination:** Use existing `is_daytime()` from sky classifier. Boundary follows existing convention (solar elevation based).
- **Out of scope:** Forecast narrative generation (Track B4 — depends on forecast data model). Period-based text ("Tonight:", "Saturday:"). Localization/i18n of generated text (deferred — English only for v1).

## References

- Research: `docs/reference/nws-text-system/gfe-text-formatter-assessment.md` — AWIPS-II architecture, extractable phrase libraries, threshold tables
- Research: `docs/reference/nws-text-system/observation-text-rules.md` — NWS text conventions, sky-to-text mapping, day/night terminology
- Research: `docs/reference/nws-text-system/metar-present-weather-codes.md` — WMO Code Tables 4677/4680, present weather codes, ASOS algorithm
- Related ADRs: ADR-044 (archived, current sky classification + text), ADR-067 (haze detection — feeds present weather), ADR-069 (fog/mist — feeds present weather)
- Existing code: `sse/conditions_text.py` (current text composer), `sse/enrichment/weather_text.py` (`_derive_weather_code()`)
