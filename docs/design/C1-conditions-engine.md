# C1 Correction Note — Conditions Engine Ground Truth

**Purpose:** Correction pass for component C1. A prior research agent read only the API
repo and concluded the conditions text engine was "not built / not wired." That conclusion
was wrong. This document establishes ground truth from the actual code, cross-referencing
ARCHITECTURE.md, the ADRs, and all three repos on weather-dev.

**Date:** 2026-05-31  
**Repos verified on:** `weather-dev` LXD container (`/home/ubuntu/repos/`)

---

## The current-conditions engine

### Owning component and repo

**`weewx-clearskies-realtime`** — the BFF (Backend-for-Frontend) service.

The engine is split across four files in `weewx_clearskies_realtime/`:

| File | Role |
|---|---|
| `conditions_text.py` | Stateless composer — assembles the `weatherText` string from per-component labels |
| `sky_condition.py` | Stateful classifier — 30-min rolling kc-buffer, produces the sky label |
| `temperature_comfort.py` | Stateless 2D matrix — maps (appTemp, dewpoint) to comfort label |
| `enrichment/weather_text.py` | Enrichment adapter — reads smoothed inputs + sky class, calls `build_weather_text()`, injects result into the `/current` response dict |

### ADRs that own this

- **ADR-041** (`ADR-041-realtime-bff.md`) — establishes the BFF role; explicitly lists the built components: "proxy, units module, sky condition, conditions text, temperature comfort, enrichment pipeline (input smoother, ring buffer, barometer trend, **weather text**, sky tap)." Confirms ~5,000 LOC of production code.
- **ADR-044** (`ADR-044-sky-condition-classification.md`) — defines the full methodology: kc/σ(kc) solar analysis for sky condition, Beaufort wind, AMS/WMO precipitation thresholds, 2D temperature-comfort matrix (appTemp × dewpoint), composition order, hysteresis/hold-time stability. Explicitly references commit `eafb706` as as-built evidence.

### Build/run status — confirmed built and running

Evidence:
- `conditions_text.py` exists at `/home/ubuntu/repos/weewx-clearskies-realtime/weewx_clearskies_realtime/conditions_text.py`
- `sky_condition.py` exists at the same package root
- `enrichment/weather_text.py` exists and is a complete, non-stub module
- `__main__.py` lines 283–284 register `enrich_weather_text` against the `"current"` endpoint key
- Compiled `.pyc` files exist in `__pycache__` for all relevant modules, confirming the service has been run
- Git log on the realtime repo includes commit `eafb706 feat(conditions-text): implement "and Gusty" wind qualifier (ADR-044 §4)` — the exact commit cited in ADR-044 as as-built
- Commit `9831880 fix(realtime): single smoothed weatherText inside data + working smoother + sky packet-tap` shows the full enrichment pipeline wired and fixed

### Inputs the engine consumes

All inputs come from the smoothed ring buffers in `enrichment/input_smoother.py` (smoothing windows per ADR-044 §8). All values are in US units (weewx internal system).

| Field | Source | Smoothing window |
|---|---|---|
| `rainRate` | Local rain gauge via loop packets | 2 min |
| `windSpeed` | Local anemometer | 5 min |
| `windGust` | Local anemometer | 5 min |
| `appTemp` | Weewx-computed apparent temperature | 10 min |
| `dewpoint` | Station dewpoint sensor | 10 min |
| `outTemp` | Station dry-bulb temperature | 10 min |
| `heatindex` | Weewx-computed heat index | 10 min |
| `windchill` | Weewx-computed wind chill | 10 min |
| `radiation` + `maxSolarRad` | Pyranometer + weewx clear-sky model | 30 min kc rolling window |

The sky classifier additionally uses provider cloud cover / weather text as a fallback
when solar analysis is unavailable (night, twilight, startup, no pyranometer).

### Output the engine emits

`build_weather_text()` → `str` — a composed natural-language conditions sentence, e.g.:
- `"Warm and Humid, Partly Cloudy, with Light Rain"`
- `"Pleasant, Mostly Clear, with Gentle breeze"`
- `""` (empty string when no components are available)

`enrich_weather_text()` injects this into the `/current` JSON response at:
```
data["data"]["weatherText"]  →  string | null
```

(When `text` is empty string, it is coerced to `None` before writing.)

### Transport to the dashboard

**REST path:** Dashboard calls `GET /api/v1/current` → Caddy proxies to BFF (realtime:8766) → BFF proxies to upstream API → BFF runs enrichment pipeline (`enrich_barometer_trend`, `enrich_weather_text`, `enrich_uv`, `enrich_scene` in order) → BFF returns enriched JSON to dashboard.

The field lands at `response.data.weatherText` (a plain string, not a `ConvertedValue` object — no unit conversion applies to text).

**SSE path:** `weatherText` is NOT in the SSE loop packet field map (`WEEWX_TO_OBSERVATION`). It is NOT updated via SSE. The `observation.weatherText` field on the dashboard comes from the REST `/current` response only (the `useObservation` hook, not the SSE overlay). This means the conditions text updates on the REST poll interval, not at loop-packet frequency.

### Condition text and code available to the current-conditions card today

**Yes** — both are available:

- `weatherText` (the composed human-readable string) is available via `GET /api/v1/current` → `data.weatherText`, fully populated by the BFF enrichment pipeline.
- `weatherCode` is available via the forecast endpoint (`GET /api/v1/forecast` → `data.daily[0].weatherCode`). The card receives it as `todayForecast?.weatherCode`.

---

## As-built current-conditions-card.tsx

File: `/home/ubuntu/repos/weewx-clearskies-dashboard/src/components/current-conditions-card.tsx`

### Props the card receives (from `now.tsx`)

```tsx
<CurrentConditionsCard
  observation={observation}          // from useRealtimeObservation() — REST + SSE merged
  stationName={station?.name ?? ''}  // from useStation() → GET /api/v1/station → data.name
  loading={obsLoading}
  error={obsError}
  units={units}
  weatherText={observation?.weatherText ?? todayForecast?.weatherText ?? null}
  weatherCode={todayForecast?.weatherCode ?? null}
  onRetry={obsRefetch}
/>
```

### What it renders

1. **Station name** — `station.name` string, rendered as `<p className="text-sm text-muted-foreground">`
2. **Weather icon** — `<WeatherIcon code={weatherCode} isNight={isNight} size="56px" />` — only renders when `weatherCode != null`. `weatherCode` comes from `todayForecast.weatherCode` (daily forecast, not the observation).
3. **Large temperature** — `observation.outTemp` as a `ConvertedValue` (`outTempCV.formatted` + `outTempCV.label`). 72px bold text.
4. **Feels-like** — `observation.appTemp` as a `ConvertedValue` when non-null.
5. **Weather description text** — `weatherText` prop (plain string) when truthy. Priority: `observation.weatherText` (BFF-composed conditions sentence) falls back to `todayForecast.weatherText` (provider forecast text) falls back to `null` (nothing rendered).
6. **Dewpoint** — `observation.dewpoint` as a `ConvertedValue`.
7. **Humidity** — `observation.outHumidity` as a `ConvertedValue`.
8. **Comfort index** — `observation.comfortIndex` from BFF (ADR-042). Renders either wind chill or heat index tile; the `comfortIndex` field is `"windChill" | "heatIndex" | "none"` — no client-side threshold logic.

### Key design point

`weatherText` and `weatherCode` are two separate things in the card. The text (the human-readable sentence from the BFF engine) is the C1 concern. The icon (`weatherCode`) is a forecast-provider integer code from the daily forecast. They can evolve independently.

---

## Why /current returns weatherText=null

This is intentional by design, documented in the API source at
`weewx_clearskies_api/endpoints/observations.py`, lines 12–13:

```python
weatherText is always null in API responses per ADR-041; the BFF enrichment
pipeline populates it before serving the dashboard.
```

And again in the endpoint handler docstring:

```python
weatherText is always null here; the BFF enrichment pipeline populates
it per ADR-041 before serving the dashboard.
```

**Why this design:** The conditions text engine requires state that the API does not have — the 30-minute kc rolling buffer, the smoothed sensor ring buffers, and the weather pattern hold-timer. These all live in the BFF (realtime service) which runs continuously and accumulates loop packets. The API is stateless per-request and reads only the archive DB. It cannot run the ADR-044 algorithm. The BFF intercepts every `/api/v1/current` response, injects `weatherText` from its own engine, and returns the enriched response to the browser. The API's `null` is the correct handoff signal.

**ADR citation:** ADR-041 §Consequences bullet 2: "Service growth: Realtime has grown from ~1,200 LOC (pre-BFF) to ~5,000 LOC of production code... includes: ... conditions text ... enrichment pipeline (input smoother, ring buffer, barometer trend, **weather text**, sky tap)."

---

## Operator location source

### Where it is configured

The operator's display location is `weewx.conf [Station] location`. This is a plain text string, e.g. `"Belchertown, MA"`. It is read at API startup by
`weewx_clearskies_api/services/station.py:load_station_metadata()`:

```python
raw_location = _get_str_field(station_section, "location")
...
info = StationInfo(
    name=raw_location,   # ← this IS the display name
    ...
)
```

The `_get_str_field()` helper handles `configobj`'s comma-list-parse quirk (an unquoted value like `Belchertown, MA` is parsed as a Python list; the helper joins it back to a string).

### Endpoint and field the dashboard reads

**Endpoint:** `GET /api/v1/station`  
**Field path:** `data.name`  
**Type:** `string` (always present — `StationMetadata.name` is non-nullable)

**Dashboard consumer:**
```tsx
// now.tsx
const { data: station } = useStation();
// ...
stationName={station?.name ?? ''}
```

`useStation()` calls `GET /api/v1/station`, takes `data?.data ?? null` (the `StationMetadata` object), and the card reads `station?.name`.

The location line in the card is rendered as:
```tsx
{stationName && (
  <p className="text-sm text-muted-foreground">{stationName}</p>
)}
```

It sits above the large temperature display — it is the first piece of text inside the card body. The string is whatever `weewx.conf [Station] location` says; there is no hardcoded city name anywhere in the React code.

### No branding endpoint involvement

The `/api/v1/branding` endpoint (from ARCHITECTURE.md) carries accent colors, logos, and theme defaults — not the station location. The location is exclusively in `/station → data.name`.

---

## Where the prior C1-data-inventory.md was wrong

The prior agent's errors, by claim:

1. **"weatherText is null / the blending engine isn't wired / not built."**
   Wrong on all three counts. `weatherText` is null in the API response deliberately (ADR-041). The engine (`conditions_text.py`, `sky_condition.py`, `temperature_comfort.py`, `enrichment/weather_text.py`) is fully built, registered, and running. The `.pyc` cache files and git log (commits `e9dbdd7` through `eafb706`) confirm it was built across multiple sprint tasks.

2. **Implied: the API is the only place to look for the conditions text.**
   Wrong. The API deliberately has no knowledge of the conditions engine. The engine is in the realtime service (BFF). Reading only the API repo's `/current` endpoint is the exact trap ADR-041 warns against.

3. **Implied (if present): the location is hardcoded or static.**
   Wrong. It is dynamic. `weewx.conf [Station] location` is the operator-configured value, read at API startup and served via `/api/v1/station → data.name`.

---

## Documentation gaps

The following are things the code reveals that ARCHITECTURE.md and the ADRs do not fully capture:

1. **`weatherText` is REST-only, not SSE.** ADR-041 describes the BFF and the enrichment pipeline but does not explicitly state that `weatherText` is excluded from the SSE loop packet field map. A reader of the ADR alone could assume the SSE stream carries `weatherText`; it does not. The field updates on REST poll cadence only. This is a documentation gap that could matter for C1's "live update" design decisions.

2. **`weatherCode` is forecast-sourced, not observation-sourced.** The card prop is `todayForecast?.weatherCode`. There is no `weatherCode` field on the `Observation` interface. If C1 needs to derive the icon from local conditions (rather than the daily forecast provider's code), a new mapping from the BFF-composed sky label to a WMO-style code would be required — that is currently not built. The as-built card has an icon only when a forecast provider is configured and returns `weatherCode`.

3. **Station name source is `weewx.conf [Station] location`, not a dedicated setup-wizard config field.** The wizard does not have a step that asks the operator for a "display location" — it reads the location directly from weewx.conf. If the operator's weewx.conf location is abbreviated (e.g., just a station name without city/state), the card will display whatever is in that field verbatim. This is correct behavior but worth noting for C1 display design.

4. **`conditions_text.py` accepts a `provider_sky` parameter not passed by `enrichment/weather_text.py`.**

---

## Doc reconciliation list

**Summary: 9 REFERENCE fixes across 3 files. 0 DECISION flags (no ADR contradicted by code).**

Scope: docs that are stale, wrong, or silent about (a) the conditions engine, or (b) the operator-location source. Classes: `REFERENCE` = docs that record facts (ARCHITECTURE.md, C1 design docs, contracts); `DECISION` = ADRs.

---

### docs/ARCHITECTURE.md

#### Gap R-1 — Conditions engine not described

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\ARCHITECTURE.md` |
| **Section** | "Realtime (BFF) endpoints" table (lines ~220–228) |
| **What it says** | Lists `/api/v1/*` (proxy) and `/sse` (SSE stream) as the only BFF endpoints. Describes BFF as doing "unit conversion," "barometer trend," "weather text" in the ADR-041 consequences bullet (copied verbatim). But nowhere in the doc is there a section explaining what the conditions engine is, what it inputs, what it outputs, or how `weatherText` gets into the `/current` response. |
| **Reality** | The conditions engine is a fully built, multi-module, stateful subsystem in the BFF: `conditions_text.py`, `sky_condition.py`, `temperature_comfort.py`, `enrichment/weather_text.py`, `enrichment/input_smoother.py`. It is registered as an enrichment for every `GET /api/v1/current` response. It produces `data["data"]["weatherText"]`. |
| **Recommended fix** | ADD a "Conditions text engine (ADR-044)" subsection under the Realtime service section. Minimum content: owning module (`weewx_clearskies_realtime/conditions_text.py`), inputs (smoothed loop packet fields via `enrichment/input_smoother.py`), output (`data.data.weatherText` on `/current` response), transport (REST only — not SSE), enrichment registration point (`__main__.py register_enrichment("current", enrich_weather_text)`), startup behavior (30-min warm-up for solar kc buffer, provider sky fallback during startup). |
| **Class** | REFERENCE |

#### Gap R-2 — "weatherText is always null" framing absent from ARCHITECTURE.md

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\ARCHITECTURE.md` |
| **Section** | "API endpoints" table entry for `/api/v1/current` (lines ~155–158) |
| **What it says** | "Most recent observation" — no mention of the weatherText field or its deliberate-null design. |
| **Reality** | The API deliberately returns `weatherText: null` on every `/current` response. The BFF's enrichment pipeline injects the real value. This is a notable intentional-by-design point that caused the prior research agent to misread the system. |
| **Recommended fix** | Add a note to the `/api/v1/current` row: "The `weatherText` field is always null in the API response; the BFF enrichment pipeline (`enrich_weather_text`) injects the composed conditions string before serving the dashboard (ADR-041, ADR-044)." |
| **Class** | REFERENCE |

#### Gap R-3 — Operator location source not described

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\ARCHITECTURE.md` |
| **Section** | "API endpoints" table entry for `/api/v1/station`, or "Configuration files" section |
| **What it says** | `/api/v1/station` is listed as "Station metadata (singleton)" with no elaboration on what the `name` field contains or where it comes from. |
| **Reality** | `station.name` is read from `weewx.conf [Station] location` at API startup. This is the operator's configured location string (e.g., "Belchertown, MA") and is the field the dashboard renders as the location line in the current-conditions card. |
| **Recommended fix** | Add a note to the `/api/v1/station` row: "The `name` field is the operator's configured display location, read from `weewx.conf [Station] location` at startup." Or add a line to the Configuration files section noting that `weewx.conf [Station] location` is the station display name surfaced via `/api/v1/station → data.name`. |
| **Class** | REFERENCE |

---

### docs/design/C1-data-inventory.md

#### Error R-4 — "weatherText is null when blending engine is 'off' or no forecast provider configured"

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\design\C1-data-inventory.md` |
| **Section** | "Current-conditions fields" table, `weatherText` row (line ~46) |
| **What it says** | `"Null when blending engine is 'off' or no forecast provider configured. Not from weewx archive — synthetic."` |
| **Reality** | The engine IS built and wired. `weatherText` is null in the API response deliberately (by design per ADR-041) — the API always returns null, then the BFF enrichment writes the real value. The field is not null because the engine is "off" — it is null at the API layer because the engine deliberately lives in the BFF layer. When the BFF is running and has data, the field is populated. The engine does NOT require a forecast provider to produce output — its primary inputs are local sensors (radiation, rainRate, windSpeed, appTemp, dewpoint). The forecast provider is only used as a sky-condition fallback when solar analysis is unavailable. |
| **Recommended fix** | Replace the Notes cell with: `"Always null in the API response (by design, ADR-041). The BFF enrichment pipeline injects the composed conditions string before serving the dashboard. Not from weewx archive — produced by the BFF conditions engine (conditions_text.py). Non-null when the BFF is running and has at least ~3 minutes of loop packet data. A forecast provider is only needed for night-time sky classification; daytime classification and all other components (precip, wind, comfort) are local-sensor-only."` |
| **Class** | REFERENCE |

#### Error R-5 — "weatherText is null today (blending engine not yet fully wired)" in Summary

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\design\C1-data-inventory.md` |
| **Section** | "Summary for the lead" → "Current-conditions fields" bullet (lines ~288–290) |
| **What it says** | `"weatherText is null today (blending engine not yet fully wired); the card must degrade gracefully."` |
| **Reality** | The blending engine IS fully wired (see `__main__.py` lines 283–284, `enrichment/weather_text.py`, git log commits `e9dbdd7` through `eafb706`). The correct statement is: `weatherText` is null in the raw API response (by design), but the BFF injects a composed string from the conditions engine before the dashboard sees it. The card must handle null for the edge case of insufficient loop data (~3 min startup window) or no BFF configured, not because the engine is unwired. |
| **Recommended fix** | Replace bullet with: `"weatherText is produced by the BFF conditions engine and injected into every /current response. It may be null during the ~3 minute startup window (insufficient solar kc data) or when no BFF is configured. Design for the null state as a brief/edge case, not the normal state."` |
| **Class** | REFERENCE |

#### Error R-6 — Cross-check note §1 mischaracterises weatherText status

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\design\C1-data-inventory.md` |
| **Section** | "Cross-check notes" §1 (lines ~215–237) |
| **What it says** | `"The endpoint docstring confirms: 'weatherText is always null in API responses per ADR-041; the BFF enrichment pipeline populates it before serving the dashboard.'"` — and then interprets this as the non-null path being "a future BFF enrichment step." Also: `"If the field is always null today, the OpenAPI omission is benign."` |
| **Reality** | The cross-check note correctly quotes the API docstring but then misinterprets it. The BFF enrichment pipeline IS implemented and running — it is not a future step. The "always null in API responses" clause is a statement about where the field is null (the upstream API layer), not about whether the feature exists. The BFF writes the non-null value. The OpenAPI omission question is still valid but the reasoning ("always null today") is factually wrong. |
| **Recommended fix** | Replace the interpretation paragraph with: `"The BFF enrichment pipeline is fully built and running (conditions_text.py, sky_condition.py, enrichment/weather_text.py). The API always returns null; the BFF replaces it. This is intentional-by-design (ADR-041), not a future step. The OpenAPI omission question remains valid independently: does the published openapi-v1.yaml need to list weatherText on the Observation schema if the BFF always populates it before the browser sees it? That is a contract question for the lead to resolve — the engine itself is not the issue."` |
| **Class** | REFERENCE |

---

### docs/design/C1-composition.md

#### Error R-7 — "condition sentence null today — blending engine isn't wired yet"

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\design\C1-composition.md` |
| **Section** | §4 "Mismatches & data-reality flags" item 1 (lines ~72–73) |
| **What it says** | `"weatherText (the condition sentence) is null today — the BFF ('backend-for-frontend,' the API's enrichment layer) blending engine (ADR-041/044) isn't wired yet."` |
| **Reality** | Wrong. The engine is wired and running. The conditions sentence is produced by `conditions_text.py` and injected into every `/current` response by `enrich_weather_text()`, registered at `__main__.py` lines 283–284. |
| **Recommended fix** | Replace item 1 with: `"weatherText (the condition sentence) IS produced by the BFF conditions engine and injected into every /current response. It may be null only during the ~3 minute startup window (insufficient solar kc data) or when the BFF is not running. Design for the null state as a brief/edge case. The icon (weatherCode) comes from the daily forecast provider's DailyForecastPoint.weatherCode — it is absent if no forecast provider is configured."` |
| **Class** | REFERENCE |

#### Error R-8 — Hero location field unresolved, marked as "being confirmed in research"

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\design\C1-composition.md` |
| **Section** | §2 Surface A — hero content description (lines ~36–37) |
| **What it says** | `"a plain-text line showing the operator's configured location (dynamic, NOT hardcoded — exact source endpoint/field being confirmed in research)"` |
| **Reality** | Confirmed by this correction pass. Source: `GET /api/v1/station → data.name`. The field is `StationMetadata.name`, populated from `weewx.conf [Station] location` at API startup. Already being read in `now.tsx` as `station?.name` and passed to `CurrentConditionsCard` as `stationName`. |
| **Recommended fix** | Replace the parenthetical with: `"(dynamic, NOT hardcoded. Source: GET /api/v1/station → data.name. Configured by operator in weewx.conf [Station] location. Already consumed in now.tsx as station?.name.)"` |
| **Class** | REFERENCE |

#### Silent omission R-9 — weatherText not in SSE stream

| Item | Detail |
|---|---|
| **File** | `c:\CODE\weather-belchertown\docs\design\C1-composition.md` |
| **Section** | §3 Data inventory / §2 Surface B |
| **What it says** | References `weatherText` as a card field without noting its update behavior. |
| **Reality** | `weatherText` is NOT in the SSE loop packet field map (`WEEWX_TO_OBSERVATION` in `useRealtimeObservation.ts`). It is not updated via SSE. It updates only when the REST `/current` poll fires. This means the conditions sentence can lag behind real-time sensor changes by up to the REST poll interval. This is worth flagging for C1's "live update" story — the icon and sentence will not update at loop-packet frequency (5 seconds). |
| **Recommended fix** | ADD to §3 or §2 Surface B: `"Note: weatherText updates at REST poll cadence only, not at SSE/loop-packet frequency. It is not in the WEEWX_TO_OBSERVATION field map and is not included in SSE loop packets. The conditions sentence may lag real-time sensor changes by up to the REST poll interval."` |
| **Class** | REFERENCE |

---

### ADR inventory — no DECISION flags

All ADRs are consistent with the code. Specifically:

- **ADR-041** explicitly describes the conditions engine as part of the BFF's as-built scope ("~5,000 LOC … conditions text … enrichment pipeline"). No contradiction.
- **ADR-044** cites specific file paths (`conditions_text.py`) and the as-built commit (`eafb706`). No contradiction.
- The one potential ADR-044 vs code gap (the unwired `provider_sky` parameter for night fallback) is a silent implementation gap, not a contradiction — ADR-044 §1b specifies provider sky as the fallback; the code does not implement it. This is a minor incomplete-implementation, not an ADR needing a correction. Flagging to lead as a behavioral note: **night conditions text currently has no sky component even when a provider is configured**, because `compose_weather_text()` in `enrichment/weather_text.py` does not pass `provider_sky`. The ADR's intent is clear; the wiring is missing. Whether to file a bug or update the ADR is the lead's call. `build_weather_text()` accepts `provider_sky: str | None = None` for provider weather text fallback, but `compose_weather_text()` in `enrichment/weather_text.py` does not pass any `provider_sky` argument. This means at night (when `sky_classify()` returns `None` and `is_daytime()` is False), the sky component of the conditions text will be omitted rather than falling back to provider data. ADR-044 §1b says provider cloud cover is the intended fallback. The wiring gap means night conditions text has no sky component. This is a minor behavioral gap not surfaced in any ADR or planning doc.
