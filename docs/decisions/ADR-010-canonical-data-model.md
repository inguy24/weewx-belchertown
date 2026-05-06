---
status: Accepted
date: 2026-05-05
deciders: shane
supersedes:
superseded-by:
---

# ADR-010: Canonical internal data model

## Context

`weewx-clearskies-api` reads weewx archive observations, calls upstream forecast / AQI / alert providers (each with its own field names, structures, units), and returns a uniform shape to the SPA. Without a canonical internal model, every endpoint re-thinks field naming and the SPA special-cases each upstream.

This ADR locks the **architecture** of that model: entity types, naming convention, unit policy, time representation, missing-data policy, multi-station scope, custom-column accommodation, prose handling. Full per-field catalog lives in `docs/contracts/canonical-data-model.md` (separate Phase 1 deliverable).

Out of scope: OpenAPI wire format (separate Phase 1 deliverable); changes to weewx archive schema (we are read-only consumers); display-side unit conversion ([ADR-019](ADR-019-units-handling.md)); multi-station support decision ([ADR-011](ADR-011-multi-station-scope.md)); time-zone source ([ADR-020](ADR-020-time-zone-handling.md)); custom-column UX ([ADR-035](ADR-035-user-driven-column-mapping.md)); AQI source ([ADR-013](ADR-013-aqi-handling.md)); alert source ([ADR-016](ADR-016-severe-weather-alerts.md)).

## Options considered

### Naming convention
| Option | Verdict |
|---|---|
| A. weewx-aligned camelCase JSON keys + snake_case Python fields, Pydantic `alias_generator` bridges them | Rejected — two-name overhead causes more confusion than the PEP 8 nicety is worth. The bridge is pure overhead with no consumer that benefits from the snake_case Python form. |
| B. snake_case everywhere | Rejected — breaks weewx alignment (weewx itself uses `outTemp`, not `out_temp`). |
| C. camelCase everywhere, identical in Python and JSON | **Selected.** PEP 8 is a style guide, not a language rule; ruff's `N815` lint is suppressed per-file for the canonical-model module. One name per field; matches weewx in both languages; eliminates the alias bridge. |
| D. Industry-aligned names (`temperature`, `pressure`) | Rejected — loses weewx alignment. |

### Units
| Option | Verdict |
|---|---|
| A. Canonical units = weewx's `target_unit`; every response embeds a `units` metadata block | **Selected.** Honest; saves conversion in the common case (weewx already in operator's preferred system); mirrors weewx's own pattern. |
| B. Fixed canonical (e.g., MetricWX) regardless of weewx config | Rejected — forces a conversion at every read for non-MetricWX deployments. |
| C. Unit-tagged values per field (`{"value": ..., "unit": ...}`) | Rejected — type system explodes. |
| D. Per-record `usUnits` marker | Rejected — splits API surface into US/Metric/MetricWX flavours per record. |

### Time
| Option | Verdict |
|---|---|
| A. UTC ISO-8601 strings with explicit `Z` suffix | **Selected.** Self-describing, JSON-native, no tz ambiguity. |
| B. Unix epoch seconds | Rejected — not self-describing; awkward in JSON. |
| C. Local-time strings without timezone | Rejected — ambiguity hurts cross-station / DST. |

### Nullability
| Option | Verdict |
|---|---|
| A. All fields `Optional[T]`; missing = `null`; key always present | **Selected.** Predictable shape; TypeScript types match. |
| B. Omit missing fields entirely | Rejected — consumer can't distinguish "not returned" from "doesn't exist on this station." |
| C. Sentinel values (`-999`) | Rejected — pre-IEEE-754 legacy. |

### Multi-station
| Option | Verdict |
|---|---|
| A. Single-station model; `StationMetadata` carries identity; records have no `stationId`. Adding optional `stationId` later is non-breaking. | **Selected.** Matches weewx reality (no major skin supports multi-station). |
| B. `stationId` on every record from day 1 | Rejected — pre-decides part of [ADR-011](ADR-011-multi-station-scope.md). |
| C. Station info on a wrapper object only | Subsumed into A. |

### Custom weewx columns
| Option | Verdict |
|---|---|
| A. Core fields first-class + `extras: dict[str, ...]` for non-core columns; [ADR-035](ADR-035-user-driven-column-mapping.md) defines promotion UX | **Selected.** Doesn't lose data; doesn't bloat core type. |
| B. Core only; custom columns silently dropped | Rejected — user-hostile. |
| C. Generic key-value bag for everything | Rejected — loses canonicalization value. |

### Provenance
| Option | Verdict |
|---|---|
| A. Every record carries `source: str` (`"weewx"`, `"openmeteo"`, etc.) | **Selected.** Debuggable; satisfies provider attribution ToS. |
| B. No provenance | Rejected. |

### Prose
| Option | Verdict |
|---|---|
| A. Per-point short labels only | Rejected — loses NWS AFD and Aeris multi-paragraph summaries. |
| B. Three layers: `weatherText` per point, optional `narrative` per day, `ForecastDiscussion` entity per bundle | **Selected.** |
| C. Drop prose entirely | Rejected. |

## Decision

Eight sub-decisions resolve to:

1. **Naming:** weewx-aligned camelCase, identical in Python and JSON (`outTemp`, `windSpeed`, etc.). No alias mechanism. Per-file ruff `N815` suppression for `models/canonical.py` (PEP 8 is a style guide, not a hard rule). Forecast types reuse observation field names where the concept matches; forecast-only concepts (precipProbability, etc.) get camelCase names invented to fit.
2. **Units:** read `weewx.conf [StdConvert] target_unit` at startup (US / METRIC / METRICWX); apply to every value the API returns. Archive rows whose `usUnits` differs from target are converted at read time. Provider normalizers convert their wire units to target at ingest. **Every response embeds a `units` metadata block** naming the unit per unit-bearing field.
3. **Time:** UTC ISO-8601 with `Z` suffix; Pydantic `datetime` with `tzinfo=UTC`. weewx epoch timestamps converted at ingest. Local-time rendering happens at the display edge per [ADR-020](ADR-020-time-zone-handling.md).
4. **Nullability:** every observation/forecast field `Optional[T]`; missing = `None`/`null`; key always present (`exclude_none=False`).
5. **Multi-station:** `StationMetadata` (one per deploy) carries identity. Records have no `stationId`. Adding optional `stationId` later per [ADR-011](ADR-011-multi-station-scope.md) is non-breaking.
6. **Custom columns:** non-core weewx columns appear in `extras: dict[str, float | int | str | bool | None]` keyed by the weewx column name verbatim. [ADR-035](ADR-035-user-driven-column-mapping.md) defines the promotion flow.
7. **Provenance:** every record carries `source: str` — `"weewx"` for archive-derived, provider name for upstream-derived.
8. **Prose, three layers:**
   - **`weatherText`** on each `HourlyForecastPoint`/`DailyForecastPoint`: short label ("Mostly sunny", "Light rain"). Filled by every provider that offers it.
   - **`narrative`** (optional) on `DailyForecastPoint`: multi-sentence per-day summary. NWS fills this; some Aeris paid plans do.
   - **`ForecastDiscussion`** entity on `ForecastBundle.discussion` (optional): multi-paragraph synoptic narrative ("AREA FORECAST DISCUSSION"). NWS fills; Aeris "weather summary" can be normalized to it. Fields: `headline`, `body` (plain text or basic Markdown), `issuedAt`, `validFrom`/`validUntil` (optional), `senderName` (optional), `source`.

### Entity types

Nine core entities + two convenience containers. Pydantic v2 `BaseModel` subclasses in `weewx_clearskies_api/models/canonical.py`. Full per-field catalog in `docs/contracts/canonical-data-model.md`.

| Entity | Purpose | Source |
|---|---|---|
| `Observation` | Most recent point reading. `timestamp`, weewx core observation fields (outTemp, outHumidity, windSpeed, windDir, windGust, barometer, dewpoint, windChill, heatIndex, rainRate, radiation, UV, …), `extras`, `source`. | weewx archive last-N-minute window |
| `ArchiveRecord` | One archive interval row (used by `/api/v1/archive` for history). Same field set as Observation + `interval`. | weewx archive |
| `HourlyForecastPoint` | One hour. `validTime` (UTC) + outTemp/outHumidity/wind/precipProbability/precipAmount/precipType/cloudCover/weatherCode/weatherText/`source`. | Provider forecast endpoints |
| `DailyForecastPoint` | One day. `validDate` (UTC date) + tempMax/tempMin/precipAmount/precipProbabilityMax/windSpeedMax/windGustMax/sunrise/sunset/uvIndexMax/weatherCode/weatherText + optional `narrative`/`source`. | Provider forecast endpoints |
| `ForecastDiscussion` | Free-form prose forecast. `headline`, `body`, `issuedAt`, `validFrom`/`validUntil`, `senderName`, `source`. Null when provider doesn't offer one. | Provider narrative endpoints |
| `AlertRecord` | Severe-weather alert. `id`, `headline`, `description`, `severity` (advisory/watch/warning), `urgency`, `certainty`, `event`, `effective`, `expires`, `areas`, `senderName`, `source`. | Provider alert endpoints |
| `EarthquakeRecord` | Recent earthquake event. Required: `id`, `time`, `latitude`, `longitude`, `magnitude`, `source`. Optional: `depth` (km), `magnitudeType` (`mw`/`ml`/`md`/…), `place`, `url`, `tsunami` (bool), `felt` (int), `mmi`, `alert` (USGS PAGER green/yellow/orange/red), `status` (review state), `extras`. | Earthquake provider endpoints (USGS / GeoNet / EMSC / ReNaSS) per [ADR-024](ADR-024-page-taxonomy.md) cat 6 + [ADR-038](ADR-038-data-provider-module-organization.md). Research: [EARTHQUAKE-PROVIDER-RESEARCH.md](../reference/EARTHQUAKE-PROVIDER-RESEARCH.md). |
| `AQIReading` | AQI snapshot. `aqi`, `dominantPollutant`, `category`, `pollutants` (dict), `observedAt`, `source`. | weewx archive `aqi_*` columns OR live provider per [ADR-013](ADR-013-aqi-handling.md) |
| `StationMetadata` | Station identity. `stationId`, `name`, `latitude`, `longitude`, `altitude`, `timezone` (IANA), `unitSystem` (US/METRIC/METRICWX), `firstRecord`/`lastRecord` (UTC). | weewx config + archive metadata |

| Container | Contents |
|---|---|
| `ForecastBundle` | `hourly: list[HourlyForecastPoint]`, `daily: list[DailyForecastPoint]`, `discussion: ForecastDiscussion \| None`, `source`, `generatedAt`. Shape `/api/v1/forecast` returns. |
| `AlertList` | `alerts: list[AlertRecord]`, `retrievedAt`, `source`. Shape `/api/v1/alerts` returns. |

### Example response shape

```json
{
  "data": {
    "timestamp": "2026-05-01T14:32:00Z",
    "outTemp": 68.5,
    "windSpeed": 5.2,
    "barometer": 29.95
  },
  "units": { "outTemp": "°F", "windSpeed": "mph", "barometer": "inHg" },
  "source": "weewx"
}
```

## Consequences

- **One uniform shape** the SPA consumes regardless of weewx version, provider, or topology.
- **weewx alignment** in field names — minimal docs friction.
- **Provider normalizers are the only place with provider-specific code** — once a record is canonical, downstream consumers treat it uniformly.
- **Custom weewx columns are not silently dropped** — `extras` preserves them; [ADR-035](ADR-035-user-driven-column-mapping.md) defines the promotion path.
- **Provenance is structural** — `source` field per record satisfies attribution and gives debugging a hook.
- **Time is unambiguous** — UTC + ISO-8601 + `Z` everywhere.
- **Units are honest** — every response says what it's in; no hardcoded assumptions; no extra conversion when weewx is already in the operator's preferred system.
- **Prose is captured at three layers** — meteorologist-written content makes it through to the SPA.

### Trade-offs accepted
- **All-fields-optional means TypeScript types are `T | null` for nearly every field.** Real and unavoidable — weather data is genuinely missing sometimes.
- **`extras` values lose unit metadata** until [ADR-035](ADR-035-user-driven-column-mapping.md) promotes them. SPA renders them in a generic "Other observations" panel labeled by column name.
- **Forecast field names diverge from provider names.** Mapping tables per provider in `docs/contracts/canonical-data-model.md`.
- **Wire format is not portable across deployments with different weewx unit systems** — but the SPA is deployed with the API; cross-deployment portability isn't a real use case. The `units` block makes the per-deployment unit explicit.
- **`ForecastDiscussion.body` is plain text or basic Markdown.** Provider-specific HTML lost. Acceptable — most discussions are plain text already (NWS AFD is fixed-width plain text).

### Repos affected
- **api:** `models/canonical.py` (9 entities + 2 containers), `models/serialization.py` (alias generator + serialization config), `providers/<name>/normalizer.py` per upstream, `services/units.py` (reads target_unit, populates units metadata block).
- **realtime:** publishes SSE events whose JSON shape is the `Observation` entity.
- **dashboard:** generates a TypeScript client from the OpenAPI spec; types match canonical model. Display-side conversion per [ADR-019](ADR-019-units-handling.md).
- **docs/contracts/canonical-data-model.md:** new spec; full per-field enumeration, unit-per-field mapping per weewx system, provider→canonical mapping tables, serialization rules. Phase 1 deliverable.

## Implementation guidance

### Pydantic config

```python
from pydantic import BaseModel, ConfigDict

# ruff: noqa: N815  (canonical fields use weewx camelCase: outTemp, windSpeed, etc.)

class CanonicalModel(BaseModel):
    model_config = ConfigDict(
        extra="forbid",                     # core fields only; extras go in `extras`
        ser_json_inf_nan="strings",
    )
```

### Serialization rules
- `model_dump_json(exclude_none=False)` — keeps null values; field names are already camelCase, no alias step needed.
- Datetime → `isoformat()` with `Z` suffix (override Pydantic's `+00:00`).
- Float fields ordinary IEEE-754; NaN/Inf serialize to JSON strings.

### Units handling
At startup, `services/units.py` reads `weewx.conf [StdConvert] target_unit` and constructs a `unit_system` dict (the canonical-field → unit mapping for the configured system). Three preset dicts (US / METRIC / METRICWX) live in code, generated from weewx's documented unit-group definitions. Every endpoint attaches the `unit_system` dict as `units` at the response root. Archive rows whose `usUnits` differs are converted at read time using weewx's documented conversion functions.

### Provider normalizer contract
```python
def normalize_current(provider_response: dict, target_unit: str) -> Observation: ...
def normalize_hourly(provider_response: dict, target_unit: str) -> list[HourlyForecastPoint]: ...
def normalize_daily(provider_response: dict, target_unit: str) -> list[DailyForecastPoint]: ...
def normalize_discussion(provider_response: dict) -> ForecastDiscussion | None: ...
def normalize_alerts(provider_response: dict) -> list[AlertRecord]: ...   # may raise NotSupportedError
def normalize_aqi(provider_response: dict, target_unit: str) -> AQIReading: ...
def normalize_earthquakes(provider_response: dict) -> list[EarthquakeRecord]: ...
```
`normalize_discussion` returns `None` for providers without one (Open-Meteo, OWM, Wunderground PWS). `normalize_alerts` raises `NotSupportedError` for providers without alerts. `normalize_earthquakes` takes no `target_unit` — earthquake fields are agency-canonical (degrees lat/lon, km depth, dimensionless magnitude, UTC time).

### Extras handling
At startup the API introspects the archive table's actual columns; core columns map to first-class fields, everything else routes to `extras` keyed by the weewx column name verbatim — so [ADR-035](ADR-035-user-driven-column-mapping.md) promotion can identify them deterministically.

### weewx field-name alignment
Where weewx names a concept, the canonical model uses that name (camelCase per weewx convention: `outTemp`, `outHumidity`, `windSpeed`, `windDir`, `windGust`, `barometer`, `pressure`, `altimeter`, `dewpoint`, `windchill`, `heatindex`, `rainRate`, `rain`, `radiation`, `UV`, `inTemp`, `inHumidity`, `extraTemp1`/`extraHumid1`, `soilTemp1`, `soilMoist1`, `leafTemp1`, `leafWet1`, `ET`, `hail`, `hailRate`). Where weewx has none, invent camelCase (`precipProbability`, `precipType`, `cloudCover`, `weatherCode`, `weatherText`, `tempMax`/`tempMin`, `gustMax`, `validTime`, `validDate`, `sunrise`/`sunset`).

## Out of scope
- Full per-field enumeration → `docs/contracts/canonical-data-model.md`.
- OpenAPI wire format → separate Phase 1 deliverable.
- Display-side unit conversion → [ADR-019](ADR-019-units-handling.md).
- Multi-station support → [ADR-011](ADR-011-multi-station-scope.md).
- IANA timezone source → [ADR-020](ADR-020-time-zone-handling.md).
- `extras` promotion UX → [ADR-035](ADR-035-user-driven-column-mapping.md).
- AQI source → [ADR-013](ADR-013-aqi-handling.md).
- Alert source → [ADR-016](ADR-016-severe-weather-alerts.md).

## References
- Related: [ADR-001](ADR-001-component-breakdown.md), [ADR-002](ADR-002-tech-stack.md), [ADR-006](ADR-006-compliance-model.md), [ADR-007](ADR-007-forecast-providers.md), [ADR-011](ADR-011-multi-station-scope.md), [ADR-013](ADR-013-aqi-handling.md), [ADR-016](ADR-016-severe-weather-alerts.md), [ADR-017](ADR-017-provider-response-caching.md), [ADR-019](ADR-019-units-handling.md), [ADR-020](ADR-020-time-zone-handling.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-035](ADR-035-user-driven-column-mapping.md), [ADR-037](ADR-037-inbound-traffic-architecture.md).
- Research: [FORECAST-PROVIDER-RESEARCH.md](../reference/FORECAST-PROVIDER-RESEARCH.md), [api-docs/](../reference/api-docs/).
- Spec: `docs/contracts/canonical-data-model.md` (Phase 1 deliverable).
- weewx schema: [weewx-5.3/](../reference/weewx-5.3/).
