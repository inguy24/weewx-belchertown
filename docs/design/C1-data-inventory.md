# C1 — Data Inventory (B1 step)

**Component:** C1 — Current-conditions hero + today's temperature curve (Now / Home page)
**Round:** C1 step 1 (B1 data inventory)
**Date:** 2026-05-31
**Lead:** Opus | **Teammate:** Sonnet (this document)

**Sources (in authority order):**
1. `weewx_clearskies_api/models/responses.py` — Pydantic `Observation` / `ArchiveRecord` classes (as-built)
2. `weewx_clearskies_api/db/reflection.py` — `STOCK_COLUMN_MAP` (archive column → canonical name)
3. `weewx_clearskies_api/services/archive.py` — `get_current()`, `get_archive()`, `DAY_AGGREGATOR`
4. `docs/contracts/openapi-v1.yaml` — `Observation`, `ArchiveRecord`, `ObservationResponse`, `ArchiveResponse` schemas
5. `docs/contracts/canonical-data-model.md` — §3.1 Observation field catalog, §2.1 unit-system table, §4.1 forecast provider mapping
6. `weewx_clearskies_api/providers/forecast/{openmeteo,aeris,nws,openweathermap,wunderground}.py` — `CAPABILITY.supplied_canonical_fields`
7. `docs/design/C0-PAGE-INVENTORY.md` — C1 component scope definition + candidate cards
8. `docs/contracts/canonical-data-model.md` §4.1.1 — current-observation provider mapping table

**What is not covered here:** AQI (C6), wind compass (C2), alerts banner, Sun & Moon (C5),
lightning, radar, precipitation/barometer, solar/UV, forecast cards (C3). Those are out of C1 scope
per the tasking.

---

## Current-conditions fields

The C1 current-conditions surface is fed exclusively by `GET /api/v1/current` (→ `ObservationResponse`
wrapping an `Observation`). The `Observation` model is the full stock weewx archive row plus a
`weatherText` field populated by the BFF blending engine (ADR-041, ADR-044). Provider modules do NOT
supply fields directly into `/current` — the weewx archive is the sole source. Provider data appears
in the `weatherText` field only (blending engine output).

Fields below are the subset relevant to the current-conditions card per C0's candidate card inventory:
"Oversized temp + condition sentence + feels-like + icon." The full `Observation` schema has 69+
first-class fields; only the card-relevant subset is called out as "primary display" vs "available."

| Canonical field | Type | Unit (US / METRIC / METRICWX) | Always-present? | Source endpoint | Notes |
|---|---|---|---|---|---|
| `timestamp` | string (ISO-8601 UTC, Z suffix) | — | **Always** | `/current` | Epoch `dateTime` from archive; converted at ingest. Never null — key is required. |
| `outTemp` | number \| null | °F / °C / °C | Conditional | `/current` | **Primary display.** Null if station lacks outTemp sensor or no archive row yet. |
| `dewpoint` | number \| null | °F / °C / °C | Conditional | `/current` | Used for cloudbase calc; can display as secondary. |
| `windchill` | number \| null | °F / °C / °C | Conditional | `/current` | **Feels-like (cold).** Null when temp ≥ threshold or no wind sensor. |
| `heatindex` | number \| null | °F / °C / °C | Conditional | `/current` | **Feels-like (hot).** Null when conditions not met. |
| `appTemp` | number \| null | °F / °C / °C | Conditional | `/current` | Apparent temperature (wview_extended). Alternative feels-like. |
| `humidex` | number \| null | °F / °C / °C | Conditional | `/current` | Canadian humidex (wview_extended). Another feels-like variant. |
| `outHumidity` | number \| null | % / % / % | Conditional | `/current` | Relative humidity 0–100. |
| `weatherText` | string \| null | — | Conditional | `/current` | **Condition sentence.** BFF conditions engine output (ADR-041/044). Always null in the API response (by design, ADR-041). The BFF enrichment pipeline injects the composed conditions string before serving the dashboard. Not from weewx archive — produced by the BFF conditions engine (`conditions_text.py`). Non-null when the BFF is running and has at least ~3 minutes of loop packet data. A forecast provider is only needed for night-time sky classification; daytime classification and all other components (precip, wind, comfort) are local-sensor-only. |
| `cloudcover` | number \| null | % / % / % | Conditional | `/current` | 0–100. wview_extended; sensor or extension dependent. |
| `cloudbase` | number \| null | foot / meter / meter | Conditional | `/current` | Calculated from temp/dewpoint/altitude (wview_extended). |
| `radiation` | number \| null | W/m² / W/m² / W/m² | Conditional | `/current` | Solar irradiance. Sensor-gated. |
| `UV` | number \| null | uv_index / uv_index / uv_index | Conditional | `/current` | UV index. Sensor-gated. |
| `barometer` | number \| null | inHg / mbar / mbar | Conditional | `/current` | Sea-level pressure. |
| `pressure` | number \| null | inHg / mbar / mbar | Conditional | `/current` | Station pressure. |
| `rainRate` | number \| null | in/h / cm/h / mm/h | Conditional | `/current` | Current rain rate per interval. |
| `rain` | number \| null | in / cm / mm | Conditional | `/current` | Per-interval accumulation (not daily total). |
| `windSpeed` | number \| null | mph / km/h / m/s | Conditional | `/current` | **Used by C2 wind compass** — listed here for completeness; primary home is C2. |
| `windDir` | number \| null | ° / ° / ° | Conditional | `/current` | 0–360 from true north. |
| `windGust` | number \| null | mph / km/h / m/s | Conditional | `/current` | |
| `windGustDir` | number \| null | ° / ° / ° | Conditional | `/current` | |
| `inTemp` | number \| null | °F / °C / °C | Conditional | `/current` | Indoor temp (inside the station enclosure). |
| `inHumidity` | number \| null | % / % / % | Conditional | `/current` | Indoor relative humidity. |
| `extras` | object | — | **Always** (may be empty) | `/current` | Operator-custom columns. May carry AQI or other extension values. Keys are weewx column names verbatim. |
| `source` | string | — | **Always** | `/current` | Always `"weewx"` for archive-derived records. |

**Envelope fields** (ObservationResponse wrapper — always present):

| Field | Type | Notes |
|---|---|---|
| `units` | `{field: unitString}` | Flat map of canonical field → unit string. Reflects actual weewx `target_unit` (with operator overrides). |
| `source` | string | Always `"weewx"`. |
| `generatedAt` | string (ISO-8601 UTC, Z) | When the API assembled the response. |
| `data` | Observation \| null | Null only when the archive is empty (fresh install before weewx has run). |

**Provider supply into `/current`:** Forecast providers do NOT supply fields directly into the
`/current` endpoint. The `weatherText` field is the only provider-touched field — it is populated
by the BFF blending engine (ADR-041, ADR-044) using the configured forecast provider's current
conditions data. This is a post-processing step, not a direct provider field mapping. None of the
forecast provider `CAPABILITY.supplied_canonical_fields` declarations reference `/current`-specific
field names — they enumerate fields for `/forecast` (HourlyForecastPoint / DailyForecastPoint).

**Forecast provider mapping for current-conditions observation** (canonical §4.1.1 table — informational,
for the blending engine): the five day-1 forecast providers (openmeteo, aeris, nws, openweathermap,
wunderground) each expose a current-observation endpoint whose fields the blending engine uses to
derive `weatherText`. The blending engine synthesizes a `weatherText` string from `weatherCode` +
`weatherText` + `cloudCover` + `isDay` (via `ProviderConditions` DTO — see `responses.py`); it does
not pass through raw provider numeric fields into the archive-derived `Observation` object.

---

## Today's temperature series

The today's-temperature curve (img-23 model per C0) plots `outTemp` over the current calendar day,
with a dashed-past/solid-future split at "now" and H/L markers. The data comes from two sources
combined in the dashboard:

### A. Historical leg (past portion of today) — `GET /api/v1/archive`

| Field | weewx archive column | Type | Unit (US / METRIC / METRICWX) | Notes |
|---|---|---|---|---|
| `timestamp` | `dateTime` (epoch s → ISO UTC) | string | — | X-axis anchor. Archive stores epoch seconds; api converts to ISO-8601 UTC with Z. |
| `outTemp` | `outTemp` | number \| null | °F / °C / °C | The Y-axis value. `null` rows exist (sensor dropout); chart must handle nulls (gaps or interpolate). |
| `interval` | `interval` | integer | minute | Archive interval in minutes (typically 5). Needed to understand point density and gap detection. |
| `appTemp` | `appTemp` | number \| null | °F / °C / °C | For the "Actual/Feels toggle" (C0 candidate). Same column, same interval. |
| `humidex` | `humidex` | number \| null | °F / °C / °C | Alternate feels-like (Canadian). Same interval. |
| `windchill` | `windchill` | number \| null | °F / °C / °C | Feels-like (cold conditions). Same interval. |
| `heatindex` | `heatindex` | number \| null | °F / °C / °C | Feels-like (hot conditions). Same interval. |

**Query pattern for today's historical arc:**
- `from=` = station-local midnight (UTC equivalent) for today
- `to=` = current time (or omit; defaults to "now")
- `interval=raw` — archive rows at native interval (typically 5 min)
- `fields=outTemp,appTemp,timestamp` — or omit to get all (filter client-side)
- `limit=1440` (5-min interval × 288 points/day; 1-min interval × 1440 → use limit=1440 max or page)

The `ArchiveRecord` shape is `Observation + interval` (integer, minutes). The `/archive` response is
paginated (cursor + page-number both supported). For a single today-window at 5-min interval, one page
of ≤288 points fits within the default `limit=1000`.

**Aggregation in archive.py for `interval=raw`:** raw mode (`_fetch_raw`) returns archive rows
verbatim — no averaging. `outTemp` values are the raw sensor readings as recorded by weewx's
archiving engine. This is the correct mode for a day-curve (preserve the shape, not aggregate it).

**`interval=hour` mode** uses `AVG(outTemp)` per hour bucket (SQLite: `strftime`; MariaDB:
`FROM_UNIXTIME`). This would give 24 data points for today but loses the intra-hour shape.
Not recommended for the today-curve; raw is correct.

**`interval=day` mode** reads `archive_day_outTemp` daily summary table. Not applicable to today's
curve (one-day window = one row only, no useful series).

### B. Instantaneous "now" value — `GET /api/v1/current`

The `/current` endpoint supplies the most recent archive row as a single `Observation`. The
`outTemp` field on this response is the rightmost plotted point (the "now" marker on the curve).
The `timestamp` field is the X-axis position of that point.

**Why both are needed:** the chart needs the historical series from `/archive` to draw the
past-portion curve, and the single live reading from `/current` to anchor the "now" divider and
keep the live value updating via SSE (the realtime service shares the `Observation` shape).

### C. Future leg (optional, from forecast) — `GET /api/v1/forecast`

C0's img-23 model shows a "dashed future" leg extending past "now" through end of day. This leg
would come from the configured forecast provider's `hourly[]` array, specifically:

| Canonical field | Source | Type | Notes |
|---|---|---|---|
| `validTime` | `/forecast` → `hourly[].validTime` | string (ISO UTC) | X-axis position for future points. |
| `outTemp` | `/forecast` → `hourly[].outTemp` | number \| null | Y-axis value for future points. |
| `appTemp` | Not in HourlyForecastPoint | — | **Not available in the forecast contract.** HourlyForecastPoint has no `appTemp`/`humidex`/`windchill`/`heatindex` fields. Feels-like toggle would lose parity past "now." |

**Provider supply of hourly outTemp:**
- openmeteo: supplies `outTemp` (via `hourly.temperature_2m[i]`) — always present on paid tier
- aeris: supplies `outTemp` (`periods[].tempF`/`C`) — always present
- nws: supplies `outTemp` (`periods[].temperature`) — always present
- openweathermap: supplies `outTemp` (`hourly[].temp`) — present on One Call 3.0 subscription
- wunderground: **no hourly forecast** — `supplied_canonical_fields` contains no `validTime`/`outTemp` hourly entries; daily only

**Implication for wunderground operators:** the future leg is not available when wunderground is the
configured forecast provider. The chart should degrade gracefully (past arc only, no future dashed leg).

### D. Interval, density, and gap handling

| Parameter | Value | Source |
|---|---|---|
| Archive interval | typically 5 min (station-dependent) | `ArchiveRecord.interval` (integer, minutes) |
| Points per day at 5 min | 288 | computed |
| Points per day at 1 min | 1440 | computed |
| `/archive` default limit | 1000 per page | `ArchiveQueryParams.limit` default |
| `/archive` max limit | 10000 per page | `ArchiveQueryParams.limit` max |
| Null handling | `outTemp` may be null for any row (sensor dropout) | Observation contract |

For a 5-min station, one page (limit=1000) covers >24h of data. Today's window (midnight to now,
up to 288 points) fits comfortably in one request. For a 1-min station, limit=1440 or pagination
is needed.

The `interval` field on `ArchiveRecord` tells the dashboard the recording cadence — useful for
drawing gap indicators when consecutive timestamps differ by more than `2 × interval`.

### E. High/Low markers

The H/L markers on the today-curve come from the same `/archive` series: the dashboard computes
`Math.max` / `Math.min` over the returned `outTemp` values client-side. No separate API call is
needed. The `/records` endpoint would serve all-time or YTD highs, not today's high — the chart
should compute today's H/L from the archive series directly.

---

## Conditional fields worth a live spot-check (NOT yet run)

The following fields appear in the `Observation` contract as nullable (conditional on the station's
sensor configuration), and their presence on the actual production weewx station is unknown from
contracts alone. A live `/current` spot-check on weather-dev would confirm which are populated.

**Do not hit any endpoint without lead approval.** This list is for the lead to approve before any
live check.

| Canonical field | Why conditional | Spot-check question |
|---|---|---|
| `appTemp` | wview_extended column; requires a station/extension that computes apparent temperature | Is `appTemp` non-null on our station's `/current` response? |
| `humidex` | wview_extended column; Canadian humidex calculation (not all stations) | Is `humidex` non-null? |
| `cloudcover` | wview_extended; sensor or extension-supplied | Is `cloudcover` non-null? |
| `cloudbase` | wview_extended; computed from temp/dewpoint/altitude | Is `cloudbase` non-null? |
| `weatherText` | BFF blending engine — requires a forecast provider configured | Is blending engine "on" and `weatherText` non-null? If yes, what string does it return? |
| `windchill` | Computed by weewx from windSpeed + outTemp; null when temp ≥ 60°F or windSpeed < 3 mph (threshold-dependent) | Is `windchill` populated seasonally, or null in warm months? |
| `heatindex` | Computed by weewx; null when conditions not met | Same question seasonally. |

For the today's-temperature curve, the key conditional question is whether `outTemp` is non-null
consistently (expected yes for a functioning outdoor temp sensor) and whether `appTemp`/`humidex`
are available for the "Feels" toggle variant.

---

## Cross-check notes

### 1. `weatherText` in `Observation` — contract vs OpenAPI

**Finding:** The `Observation` Pydantic model in `weewx_clearskies_api/models/responses.py` contains
a `weatherText: str | None = None` field (added for the BFF blending engine, ADR-041). However, the
OpenAPI `openapi-v1.yaml` `Observation` schema does **not** include `weatherText` as a listed property.

The `responses.py` docstring notes: *"Current conditions text from the blending engine (ADR-0B Phase 0B). None when conditions engine is 'off' or no provider is configured."* The endpoint docstring
confirms: *"weatherText is always null in API responses per ADR-041; the BFF enrichment pipeline
populates it before serving the dashboard."*

**Classification:** The OpenAPI schema is the authoritative wire-shape source (per the data model
doc's priority order: "when this document and openapi-v1.yaml disagree, the OpenAPI wins for
wire-shape questions"). `weatherText` is a field that the as-built code adds to the response JSON
but is not declared in the published OpenAPI schema. This is either:
- An intentional omission (the field is "internal BFF" and not meant to be in the public contract), or
- A gap in the OpenAPI spec that should be filled.

The BFF enrichment pipeline is fully built and running (`conditions_text.py`, `sky_condition.py`, `enrichment/weather_text.py`). The API always returns null; the BFF replaces it. This is intentional-by-design (ADR-041), not a future step. The OpenAPI omission question remains valid independently: does the published `openapi-v1.yaml` need to list `weatherText` on the Observation schema if the BFF always populates it before the browser sees it? That is a contract question for the lead to resolve — the engine itself is not the issue.

### 2. `aqiScale` in `AQIReading` — code vs OpenAPI

**Finding (informational, C6 scope but noted):** `AQIReading` Pydantic model has an `aqiScale: str | None`
field not present in the OpenAPI `AQIReading` schema. This is C6 scope, not C1. Noted here for
completeness since the same pattern (code has extra field, OpenAPI doesn't) appeared in both endpoints
read for this inventory.

### 3. `STOCK_COLUMN_MAP` vs `Observation` model — minor divergence

**Finding:** `STOCK_COLUMN_MAP` in `db/reflection.py` includes `dewpoint1`, `extraTemp4` through
`extraTemp8`, `extraHumid3` through `extraHumid8` (beyond the two/three listed in the OpenAPI schema).
The `Observation` Pydantic model does NOT include `dewpoint1`, `extraTemp4–8`, or `extraHumid3–8` as
named fields. These stock columns would land in the `extras` dict at runtime (via the `_row_to_observation`
function's fallback path) despite being in `STOCK_COLUMN_MAP` — because `STOCK_COLUMN_MAP` has them but
the `Observation` model does not have corresponding named attributes.

**Wait — checking the routing logic:** `_row_to_observation` routes via `registry.stock.get(db_col)` and
then sets `obs_fields[col_info.canonical_name] = val`. Since `Observation` uses `extra="ignore"`, fields
not declared on the model are silently dropped, not placed in `extras`. So `dewpoint1`, `extraTemp4–8`,
`extraHumid3–8` would be **silently dropped** from responses if the station has those archive columns.

**Classification:** This is a code-level inconsistency between `STOCK_COLUMN_MAP` (which claims these
are stock/canonical) and the `Observation` Pydantic model (which doesn't have slots for them). For C1
purposes this is not an issue (none of these are current-conditions card fields), but it is worth
flagging to the lead as a potential silent data-loss issue for stations with extended sensor arrays.

### 4. No mismatch between `/archive` contract and today's-temp use case

The archive service, Pydantic models, and OpenAPI spec are internally consistent for the today's-temp
curve use case: `outTemp` is a nullable number on `ArchiveRecord`, the query parameters (`from`, `to`,
`interval`, `fields`, `limit`) are all implemented as documented, and the pagination shape (`PageInfo`)
is stable. No contract/code mismatch found for the temp-curve path.

### 5. `aeris` CAPABILITY — `narrative` not in declaration

**Finding (informational):** The `aeris` forecast provider `CAPABILITY.supplied_canonical_fields` was
read but the output was truncated in the SSH command (last line was the comment `# ForecastDiscussion —
max-surface; populated only on paid-tier responses`). The full aeris CAPABILITY tuple likely includes
`narrative`, `headline`, `body`, `issuedAt`, `senderName` — consistent with canonical §4.1.4. This is
C3 scope (forecast discussion). Not a gap for C1.

---

## Summary for the lead

**Current-conditions fields (for the hero card):**
- 25 first-class fields enumerated above; the card-primary ones are `outTemp`, `weatherText`
  (BFF-computed), and one of `windchill` / `heatindex` / `appTemp` / `humidex` as the feels-like value.
- All come from `GET /api/v1/current` → `Observation`.
- `weatherText` is produced by the BFF conditions engine and injected into every `/current` response. It may be null during the ~3 minute startup window (insufficient solar kc data) or when no BFF is configured. Design for the null state as a brief/edge case, not the normal state.
- "Always present" fields: only `timestamp`, `source`, `extras`, and the `units`/`generatedAt`/`source`
  envelope fields. Everything else is nullable (conditional on station sensors).

**Today's temperature series:**
- Historical leg: `GET /api/v1/archive` with `interval=raw`, `from=today-midnight-UTC`, `outTemp` field.
- Keyed on: `timestamp` (X-axis, UTC ISO-8601) + `outTemp` (Y-axis, nullable).
- Underlying weewx column: `outTemp` in the `archive` table.
- Archive interval: typically 5 min (read from `ArchiveRecord.interval`).
- For the "Feels" toggle: `appTemp` is available in the same `/archive` call (same columns); `windchill`
  and `heatindex` are also available but may be null more often (threshold-gated).
- The future leg needs `hourly[].outTemp` from `/forecast`; not available for wunderground operators.
- High/Low markers: computed client-side from the archive series (no separate API call).

**Conditional fields recommended for live spot-check (lead approval required before hitting any endpoint):**
`appTemp`, `humidex`, `cloudcover`, `weatherText` population status.

**Contract/code mismatches to surface:**
1. `weatherText` on `Observation` — in Pydantic model, absent from OpenAPI schema. Lead decides whether to add to OpenAPI.
2. `STOCK_COLUMN_MAP` includes extended sensor columns not present on `Observation` model — silent drop at runtime for those stations. Not C1-blocking but worth noting.
