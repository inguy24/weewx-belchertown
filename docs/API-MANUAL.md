# Clear Skies — API Manual

Single authority for all Clear Skies API implementation rules. Consumers: API dev agents and human reviewers.

When this document conflicts with any other source (ADRs, code comments, conversation history), **this document wins**. ADRs explain *why* decisions were made; this manual says *what to do*.

Companion documents:

- **ARCHITECTURE.md** — system topology, ports, containers (what the system IS)
- **PROVIDER-MANUAL.md** — provider module rules
- **contracts/canonical-data-model.md** — per-field data catalog (the field inventory)

Last updated: 2026-06-24

---

## Contents

1. [Purpose and Principles](#1-purpose-and-principles)
2. [Data Model](#2-data-model)
3. [Database Access](#3-database-access)
4. [Versioning](#4-versioning)
5. [Column Mapping](#5-column-mapping)
6. [Unit System](#6-unit-system)
7. [skin.conf Compliance](#7-skinconf-compliance)
8. [Conditions Text Engine](#8-conditions-text-engine)
9. [Charts System — API Side](#9-charts-system--api-side)
10. [weewx Integration](#10-weewx-integration)
11. [SSE and Realtime](#11-sse-and-realtime)
12. [Radar Endpoints and Capability Model](#12-radar-endpoints-and-capability-model)
13. [Anti-Patterns](#13-anti-patterns)

---

## §1 Purpose and Principles

### What the API is

The API (`weewx-clearskies-api`) is the weewx application layer — not merely a dashboard backend. It is the canonical programmatic interface to weewx station data. Any client (dashboard, Home Assistant, third-party scripts) that needs weather station data connects to the API. The API does not exist solely to serve the dashboard.

The API runs on the weewx host, co-located with the weewx process and its archive database (per ADR-056). This co-location is a deployment constraint, not a preference — the API reads `weewx.conf` locally and shares the filesystem with the weewx archive.

### Computation boundary

The API owns three distinct layers of responsibility:

1. **Data access.** Query the weewx archive database via SQLAlchemy. Return raw observation and aggregate values.
2. **Unit conversion and derived values.** Convert raw values to operator display units. Compute Beaufort scale, comfort index selector, barometer trend direction, and cardinal wind directions. This is the enrichment pipeline.
3. **Provider data.** Aggregate external data (forecast, AQI, alerts, earthquakes, radar) via internal provider plugin modules. Apply the same unit conversion pipeline to provider-sourced data.

The dashboard owns rendering and presentation-level computation: client-side binning for visualizations (wind rose direction-by-Beaufort matrix), LTTB downsampling, chart layout, theming. The dashboard reads API-provided derived fields but does not recompute them.

**The test:** If a proposed endpoint handler requires unit conversion, threshold classification, or produces output shaped for a specific chart type, it belongs in the enrichment pipeline or the dashboard — not in the endpoint handler.

### General-purpose data access

The API exposes general-purpose data access endpoints. It does not expose chart-specific or visualization-specific endpoints. The API serves `/archive` time-series, `/archive/grouped` categorical aggregates, `/current` observation snapshot, and `/charts/config` for operator-defined chart definitions. The dashboard determines what to fetch and how to render it.

Do not create endpoint paths named after a chart type (e.g., `/charts/wind-rose`, `/charts/temperature-range`). The single exception is `/charts/custom-query/{series_id}`, which executes operator-defined SQL from `charts.conf` — not a chart-type endpoint, a config-driven query executor.

### Setup mode

When `settings.configured = False`, the API starts in setup mode. In setup mode:

- Only setup endpoints under `/setup/*` are active.
- `/api/v1/status` returns `{"configured": false}` and is always active regardless of mode.
- All other `/api/v1/*` endpoints return HTTP 503 with an RFC 9457 problem body: `{"type": "urn:clearskies:not-configured", "title": "Station not configured", "status": 503}`.
- No database connection is established. No provider modules load. No data routers run.
- The SSE stream is not available.

After the operator completes the setup wizard and the API receives `POST /setup/apply`, the API writes its config files and restarts into normal mode.

### Startup sequence

The API startup executes in the following ordered steps. Steps marked **fatal** exit the process non-zero on failure. Steps marked **non-fatal** log a warning and continue.

| Step | Action | Error handling |
|------|--------|----------------|
| 1 | Load and validate `settings` from `api.conf` and `secrets.env` | Fatal |
| 2 | Initialize structured JSON logging (stdout, stdlib `logging`) | Fatal |
| 3 | Initialize TLS (load or generate Ed25519 self-signed certificate) | Fatal |
| 4 | Initialize trust manager (load pinned fingerprints and session store) | Fatal |
| 5 | Start FastAPI engine, mount middleware (CORS, security headers, request size limit) | Fatal |
| 6 | Run write probe against the database; exit non-zero if writes succeed | Fatal |
| 7 | Run schema reflection (`MetaData.reflect()` on archive table) → populate column registry | Fatal |
| 8 | Read `weewx.conf` for station metadata auto-detection | Non-fatal (warning) |
| 9 | Load unit system config (`api.conf [units]`); validate column units | Non-fatal (warnings per mismatch) |
| 10 | Load station metadata (lat, lon, altitude, timezone, station name) | Non-fatal |
| 11 | Initialize ephemeris (Skyfield for almanac). pvlib is used at bootstrap time for McClear clear-sky GHI (ADR-072), not at runtime. | Non-fatal |
| 12 | Load reports config (`api.conf [reports]`) | Non-fatal |
| 13 | Load content config (custom pages) | Non-fatal |
| 14 | Initialize cache backend (memory or Redis per `api.conf [cache]`) | Non-fatal (falls back to memory) |
| 15 | Start cache warmer daemon thread | Non-fatal |
| 16 | Load database metrics | Non-fatal |
| 17 | Initialize provider registry; load per-domain provider modules | Non-fatal per provider |
| 18 | Load per-domain provider settings (forecast, AQI, alerts, earthquakes, radar) | Non-fatal per domain |
| 19 | Run health probe (loopback `/health/ready` on port 8081) | Non-fatal |
| 20 | Initialize SSE infrastructure (emitter, 64-packet overflow buffer, 15-second keepalive) | Fatal |
| 21 | Initialize `UnitTransformer` with loaded unit config | Fatal |
| 22 | Register enrichment processors in order (see §8 for processor registration order) | Fatal |
| 23 | Wire endpoint enrichment (barometer trend, wind rolling average, conditions text, etc.) | Fatal |
| 24 | Serve (uvicorn begins accepting connections) | — |

This is a 24-step process. Each step has explicit error handling. Do not collapse steps or add silent fallbacks that mask startup failures.

---

## §2 Data Model

For the complete per-field inventory — field names, types, units by unit system, and provider-to-canonical mapping tables — see `contracts/canonical-data-model.md`.

### Naming

Use weewx-aligned camelCase in both Python and JSON. Python field names and JSON key names are identical — no alias mechanism, no snake_case-to-camelCase translation at serialization time. The Pydantic ruff rule N815 (mixed-case variables) is suppressed on model fields.

### Entity types

The canonical data model defines 9 core entity types and 2 container types:

| Entity | Description |
|--------|-------------|
| `Observation` | Single current-conditions snapshot (loop-packet-derived) |
| `ArchiveRecord` | One archive interval record (DB-derived) |
| `HourlyForecastPoint` | Hourly forecast from a provider module |
| `DailyForecastPoint` | Daily forecast summary from a provider module |
| `ForecastDiscussion` | Full NWS Area Forecast Discussion text |
| `AlertRecord` | Single severe-weather alert |
| `EarthquakeRecord` | Single earthquake event |
| `AQIReading` | Air quality index reading from a provider module |
| `StationMetadata` | Station identity (name, lat, lon, alt, timezone, archiveIntervalSeconds, weekStartDay) |
| `ForecastBundle` | Container: hourly + daily + discussion in one response |
| `AlertList` | Container: list of active alerts |

### Response shapes

**Observation endpoints** (`/current`, SSE stream) return `ConvertedValue` dicts for each observation field:

```json
{"value": 22.5, "label": "°C", "formatted": "22.5"}
```

**Archive endpoints** (`/archive`, `/archive/grouped`) return flat scalars except for `beaufort`, which retains its `ConvertedValue` dict to allow dashboard-side wind rose binning without recomputing Beaufort from wind speed.

Both endpoint classes carry a `units` envelope (see below).

### Units metadata

Every API response carries a `units` metadata block. Use display-friendly symbols (`°F`, `mph`, `inHg`) not weewx-internal identifiers (`degree_F`, `mile_per_hour`, `inHg`). Example:

```json
{
  "units": {
    "temperature": "°F",
    "speed": "mph",
    "pressure": "inHg",
    "rain": "in",
    "rainRate": "in/hr"
  }
}
```

Never return a response that omits the `units` block.

### Time

Use UTC ISO-8601 with a `Z` suffix on all time fields in API responses: `"2026-06-18T14:30:00Z"`. Never include local-time strings. Python `datetime` objects must carry `tzinfo=UTC` — naive datetimes are forbidden in API-layer code. Display-side timezone conversion happens in the dashboard using the station's IANA timezone from `StationMetadata`.

### Nullability

Every field is `Optional[T]`. The key is always present in the response; use `null` for missing values. Never omit a key because the value is absent.

Pydantic model config:

```python
model_config = ConfigDict(
    extra="forbid",
    populate_by_name=True,
)
```

Serialize with `model.model_dump_json(exclude_none=False)` — `null` values must appear in the output, not be stripped. Serialize `inf` and `NaN` as strings (`ser_json_inf_nan="strings"`) to produce valid JSON.

### Provenance

Every record carries a `source: str` field. Use `"weewx"` for archive-derived data. Use the provider module's identifier string (e.g., `"open_meteo"`, `"nws"`, `"openweathermap"`) for upstream-derived data.

### Custom columns

Non-core columns (columns the operator has mapped from their archive schema but that do not correspond to a canonical entity field) go into `extras: dict[str, Any]`. Stock weewx columns never appear in `extras` — they appear at their canonical field names.

The `/archive` endpoint serves all columns present in the archive schema with no whitelist gate. Any column in the database is queryable by passing its column name as `observation_type`.

### Earthquake fields

Earthquake fields are unit-system-invariant: depth in km, magnitude as a dimensionless number, coordinates as WGS84 decimal degrees. These fields do not appear in the `units` block and do not pass through the unit conversion layer.

### Prose layers

Three layers of text prose exist in the data model:

| Layer | Field | Source | Transport |
|-------|-------|--------|-----------|
| Conditions text | `weatherText` | Conditions engine (§8) | REST only (`/current`) |
| Daily forecast prose | `narrative` | Provider daily forecast | REST (`/forecast`) |
| Area forecast discussion | `ForecastDiscussion` | NWS AFD API | REST (`/forecast/discussion`) |

`weatherText` is not included in the SSE field map.

### Pydantic configuration summary

| Setting | Value |
|---------|-------|
| `extra` | `"forbid"` |
| `exclude_none` | `False` (always serialize null) |
| Field naming | camelCase (ruff N815 suppressed) |
| Serialization | `model.model_dump_json(exclude_none=False)` |
| Inf/NaN | `"strings"` |

---

## §3 Database Access

### Driver

Use SQLAlchemy 2.x with parameterized queries throughout. Never concatenate SQL strings with user-supplied or operator-supplied values. Use SQLAlchemy Core for read-heavy aggregation queries (not ORM). Refer to `rules/coding.md` §1 for the parameterized-query requirement.

### Backends

Support SQLite (weewx default) and MariaDB. Write no per-driver code paths in endpoint handlers — SQLAlchemy abstracts the dialect. The same endpoint code must work on both backends.

### Read-only enforcement

Apply defense in depth across two independent layers:

1. **Database-level grants.** For MariaDB: operator provisions `GRANT SELECT ON weewx.* TO 'clearskies'@'localhost'`. For SQLite: open the file with `?mode=ro&uri=true` plus filesystem read-only permissions. Document the exact SQL grant in `INSTALL.md`.
2. **Startup write probe.** At startup (step 6), attempt a write to a throwaway table. If the write succeeds, log an error and exit non-zero. The API refuses to start if it has write access. This probe runs before schema reflection and before any endpoint is registered.

The startup write probe is not optional. Do not remove it or make it conditional.

### Schema introspection

At startup (step 7), run `MetaData.reflect()` against the archive table. The reflected column list populates the column registry. Endpoints select columns from the operator's mapping (§5) derived from this registry — not from a hardcoded column list.

Re-introspection is triggered by the config UI when the operator re-runs the mapping flow (e.g., after adding a new weewx extension). The API never re-reflects mid-request.

### Connection lifecycle

Yield a SQLAlchemy session per request via FastAPI dependency injection. Close the session at request end. Do not hold long-lived sessions in endpoint code.

### Pool settings

| Backend | Pool type | pool_size | max_overflow |
|---------|-----------|-----------|--------------|
| SQLite | `NullPool` | — | — |
| MariaDB | `QueuePool` | 5 | 10 |

Use `NullPool` for SQLite because SQLite's `?mode=ro` URI does not support connection pooling safely.

### Security constraints

| Constraint | Value |
|------------|-------|
| Archive query time-range cap | 366 days maximum |
| DB query timeout | 30 seconds (both engines) |
| Custom SQL source | Config file only — never from HTTP request body or query params |
| Custom SQL validation | `EXPLAIN` pre-validation at startup, read-only transaction, 10-second timeout, DDL keyword blocklist |

---

## §4 Versioning

### URL path versioning

All API endpoints use the `/api/v1/` path prefix. The version segment is `v1`. Do not add `v2` segments until a breaking change is required.

### What constitutes a breaking change

A major version bump (`v1` → `v2`) is required when any of the following occur:

- An endpoint is removed or its path changes
- A required field is removed from a response schema
- A field's type or nullability changes in a backward-incompatible way
- A field is renamed
- Validation is tightened in a way that rejects previously valid requests
- A response's default behavior changes in a way that breaks existing clients

### What does not require a version bump

- Adding a new endpoint
- Adding a new optional field to a response
- Loosening validation (accepting more input shapes)
- Adding a new query parameter (optional, with documented defaults)
- Performance improvements with no wire-shape change

### No support-window promise

Clear Skies is GPL v3 software provided AS-IS. Do not include any support-window, security-backport, LTS, or end-of-life schedule language anywhere in API documentation or code comments.

### Error format

All error responses across all API versions use RFC 9457 `application/problem+json`. Never return a plain-text or HTML error body. The minimum error response shape:

```json
{
  "type": "urn:clearskies:<error-code>",
  "title": "Human-readable title",
  "status": 400
}
```

The `type` field is a URN, not a URL. Use `urn:clearskies:` as the prefix for all Clear Skies error types.

### OpenAPI

FastAPI auto-generates the OpenAPI specification. The spec is served at:

- `/api/v1/docs` — Swagger UI (interactive)
- `/api/v1/redoc` — ReDoc (readable)
- `/api/v1/openapi.json` — machine-readable spec

The canonical committed contract is `docs/contracts/openapi-v1.yaml`. When the implementation diverges from this contract, update the contract — do not suppress FastAPI's auto-generation to match a stale file.

---

## §5 Column Mapping

### Auto-mapping stock columns

Stock weewx columns (`outTemp`, `barometer`, `windSpeed`, etc.) auto-map silently at startup using a built-in lookup table. The operator does not interact with stock column mapping. The auto-map table ships as part of the API repo.

### Presenting non-stock columns

Non-stock columns discovered by schema reflection (step 7) are presented to the operator in the config UI wizard. For each non-stock column, the wizard offers a heuristic name-match suggestion (case-insensitive substring match against the canonical field catalog) and lets the operator pick a canonical field or select "not mapped."

### Persistence

The confirmed mapping persists in the operator's `api.conf` under `[column_mapping]`. The mapping takes effect on the next request — no service restart required when the operator updates a mapping through the config UI.

### Operator confirmation required

When all discovered columns are stock, the wizard presents the mapping table with pre-filled suggestions and requires operator confirmation before advancing. The operator always confirms — nothing auto-maps silently and the step never auto-advances (per ADR-056 amendment to ADR-035).

### Battery and diagnostic column exclusion

Columns matching any of the patterns `*Battery*`, `*Link*`, or `*Status*` are excluded from the mapping suggestion list. These columns carry sensor metadata, not weather observations. They are silently skipped — no warning to the operator.

### Validation at submit

The mapping table validates before advancing. Flag these errors inline with visual callouts:

- **Duplicate canonical mapping** — two archive columns mapped to the same canonical field
- **Invalid canonical name** — the operator entered a field name not in the canonical catalog

The step cannot advance while any inline error is present.

### weewx metadata import

Use `import weewx.units` to access `obs_group_dict` for unit group auto-detection. This maps each stock weewx field name to its `group_*` identifier, enabling the wizard to auto-populate the unit group for operator-confirmed custom columns where the group can be inferred from the field name pattern.

---

## §6 Unit System

### Scope

The API implements full weewx unit system compatibility across 14 unit groups. The dashboard has zero unit knowledge — it renders the `label` and `formatted` strings the API provides without performing any unit math.

### Unit groups

| Group | Valid units | Default (US) |
|-------|-------------|--------------|
| group_temperature | degree_F, degree_C, degree_K, degree_E | degree_F |
| group_speed | mile_per_hour, km_per_hour, knot, meter_per_second | mile_per_hour |
| group_speed2 | mile_per_hour2, km_per_hour2, knot2, meter_per_second2 | mile_per_hour2 |
| group_pressure | inHg, mbar, hPa, kPa | inHg |
| group_pressurerate | inHg_per_hour, mbar_per_hour, hPa_per_hour, kPa_per_hour | inHg_per_hour |
| group_rain | inch, cm, mm | inch |
| group_rainrate | inch_per_hour, cm_per_hour, mm_per_hour | inch_per_hour |
| group_altitude | foot, meter | foot |
| group_distance | mile, km | mile |
| group_direction | degree_compass | degree_compass |
| group_radiation | watt_per_meter_squared | watt_per_meter_squared |
| group_uv | uv_index | uv_index |
| group_percent | percent | percent |
| group_moisture | centibar | centibar |
| group_volt | volt | volt |

### The API is the single conversion authority

The API converts all values to operator display units before any response leaves the service. This applies to both REST responses and SSE events. The dashboard never receives raw weewx units — it receives converted values with labels attached.

### Target unit system inference

Derive the operator's target unit system (US / METRIC / METRICWX) from `api.conf [units][[groups]]`:

1. Check `group_temperature`.
2. If `degree_F` → target is US.
3. If `degree_C` → check `group_rain`: if `mm` → target is METRICWX; otherwise target is METRIC.

This inference is used internally for system-level documentation. The API converts per-field using the explicit per-group configuration — it does not apply a blanket unit system conversion.

### Column unit validation at startup

At startup (step 9), `_validate_column_units()` cross-checks the operator's confirmed unit settings against weewx metadata (`obs_group_dict`). On a mismatch, log a warning — do not exit. The operator-confirmed unit wins. Never silently revert to a different unit without the operator's explicit action.

### REST conversion path

1. Read archive record with `usUnits` field.
2. Look up each field's group via `obs_group_dict`.
3. Convert from archive source unit to operator display unit using `units/conversion.py`.
4. Attach `label` (from `units/labels.py`) and `formatted` string (from `api.conf [units][[string_formats]]`).
5. Return `{"value": ..., "label": "...", "formatted": "..."}`.

### SSE conversion path

1. Receive loop packet from socket reader (Unix socket from `ClearSkiesLoopRelay`).
2. Read `usUnits` field from the packet to identify the source unit system.
3. Convert each observation field to operator display unit.
4. Attach label.
5. Emit via SSE.

### Additional unit configuration

| Config subsection | Controls | v0.1 status |
|-------------------|----------|-------------|
| `[[string_formats]]` | Decimal places per unit (`degree_F = %.1f`) | Supported |
| `[[labels]]` | Display symbols per unit (`degree_F = " °F"`) | Supported |
| `[[ordinates]]` | Compass direction labels (N, NNE, NE, …) | Supported |
| `[[trend]]` | Barometer trend window and grace period | Supported |
| `[[time_formats]]` | strftime patterns for different contexts | Out of scope v0.1 |
| `[[degree_days]]` | Base temperatures for HDD/CDD/GDD | Out of scope v0.1 |

### Derived values

| Derived field | Computation | Location |
|---------------|-------------|----------|
| Beaufort number and label | Computed from wind speed in any source unit; converted to m/s internally before applying Beaufort thresholds | `units/derived.py` |
| `comfortIndex` | String selector: `"windChill"` (appTemp ≤ 50 °F), `"heatIndex"` (appTemp ≥ 80 °F), or `"none"` (moderate range). Dashboard reads this string to decide which comfort field to display. | `units/derived.py` |
| `barometerTrendDirection` | Direction string from `enrichment/barometer_trend.py` over the operator-configured trend window | Enrichment pipeline |
| `windDirCardinal`, `windGustDirCardinal` | 16-point compass codes computed by the API | Enrichment pipeline |

The dashboard does not recompute any of these from raw observations.

### Conversion factor accuracy

Conversion factors in `units/conversion.py` must exactly match weewx's own values. Source: weewx Python source code at `weewx/units.py`. Do not use approximations, Wikipedia values, or reference-book constants. Floating-point precision is handled by `string_formats` rounding at format time — do not round intermediate values.

### File layout

```
weewx_clearskies_api/
└── units/
    ├── __init__.py
    ├── groups.py        # Group definitions, valid units, field→group mapping
    ├── conversion.py    # Conversion factors (from weewx source)
    ├── labels.py        # Display symbols per unit
    ├── transformer.py   # Applies conversion + formatting to data dicts
    └── derived.py       # API-computed derived fields: beaufort(), comfort_index()
```

---

## §7 skin.conf Compliance

### Section disposition table

| skin.conf section | Disposition | Where it lands |
|-------------------|-------------|----------------|
| `[Units][[Groups]]` | KEEP | `api.conf [units][[groups]]` |
| `[Units][[StringFormats]]` | KEEP | `api.conf [units][[string_formats]]` |
| `[Units][[Labels]]` | KEEP | `api.conf [units][[labels]]` |
| `[Units][[Ordinates]]` | KEEP | `api.conf [units][[ordinates]]` |
| `[Units][[TimeFormats]]` | KEEP | `api.conf [units][[time_formats]]` |
| `[Units][[DegreeDays]]` | KEEP | `api.conf` |
| `[Units][[Trend]]` | KEEP | `api.conf` |
| `[Units][[TimeZone]]` | KEEP | Pre-fills wizard station step |
| `[Labels][[Generic]]` | KEEP | i18n override file |
| `[Texts]` | REPLACE | react-i18next (ingest translations) |
| `[Extras]` — branding | KEEP | Wizard branding step |
| `[Extras]` — feature toggles | INGEST, DEFER | Parsed and stored; display deferred |
| `[Extras]` — provider config | INGEST | Map API keys to provider config |
| `[Extras]` — social | KEEP | Wizard social config step |
| `[Extras]` — PWA/manifest | KEEP | Generate `manifest.json` |
| `[Extras]` — MQTT | IGNORE | MQTT eliminated (per ADR-058) |
| `[Almanac]` — moon_phases | KEEP | Feed 8 lunar phase labels into i18n |
| `[Generators]` | IGNORE | Cheetah-specific; silently skip |
| `[CheetahGenerator]` | IGNORE | Cheetah-specific; silently skip |
| `[ImageGenerator]` | IGNORE | Cheetah-specific; silently skip |
| `[CopyGenerator]` | IGNORE | Cheetah-specific; silently skip |

Silently skip IGNORE sections — no warnings to the operator for expected ignores. Log warnings for unknown `[Extras]` keys but do not treat them as fatal.

### Wizard import flow

The wizard offers two paths at step 0:

1. **Start fresh** — begin with defaults; no file import.
2. **Import from existing skin** — operator uploads a `skin.conf` file.

The parser uses `configobj` (same library weewx uses). Each subsequent wizard step displays imported values with a visual indicator ("imported from Belchertown") and allows the operator to edit before advancing.

### Image import resolution order

When a `skin.conf` import includes image paths (e.g., `logo_image`, `logo_image_dark`, `favicon`):

1. **Local filesystem** — if the wizard and weewx host are the same machine, resolve the path relative to the source skin directory and copy to Clear Skies static assets.
2. **API endpoint** — for split-host deployments, `GET /setup/skin-file?skin=Belchertown&path=images/logo.png` serves the file from the weewx host. Validate that the requested path stays within the skin directory (no directory traversal). Wizard downloads and stores locally.
3. **Neither accessible** — display an amber warning listing unreachable files with their original paths. Operator uploads replacements in the Branding wizard step or copies manually.

### Generated skin.conf

The wizard writes a `skin.conf` to `/etc/weewx/skins/ClearSkies/skin.conf` when the operator applies configuration. This file contains `[Units]` (all subsections), `[Labels][[Generic]]`, `[Extras]` (branding, social, feature toggles), and `[Almanac]`. Cheetah sections are omitted. The API reads unit preferences from `api.conf [units]` at runtime — the generated `skin.conf` is the portable canonical copy. Only the wizard writes these files; they cannot drift.

---

## §8 Conditions Text Engine

### Overview

The conditions text engine is a multi-module stateful system that produces the `weatherText` field in `/current` responses. It runs as part of the API's enrichment pipeline. `weatherText` is a REST-only field — it is not included in the SSE field map.

### Sky condition

**Primary source (daytime):** Kv-first decision tree in the Duchon & O'Malley (1999) tradition, using CAELUS-derived indices (Ruiz-Arias & Gueymard 2023). See ADR-073 for full scientific reasoning.

- Measure GHI (radiation from weewx) and clear-sky reference (maxSolarRad from weewx).
- Bin 5-second LOOP packets into 1-minute averages. Maintain a 30-minute ring buffer of MinuteRecord entries.
- Compute five indices from the ring buffer:

| Index | Formula | Window | Used in |
|-------|---------|--------|---------|
| Kcs | latest GHI / latest maxSolarRad, clamped [0, 1.2] | Latest minute | Cloud enhancement gate, uniform clear check |
| Km | (1/n) Σ(GHI_i / maxSolarRad_i) — mean of per-minute ratios | 30 min | Uniform branch (clear vs. overcast thickness) |
| Kmf | Same formula as Km | 10 min | Variable branch (coverage degree) |
| Kv | Σ\|ΔGHI - ΔmaxSolarRad\| / window_span | 30 min | Asymmetric gate (both must be calm for uniform) |
| Kvf | Same formula as Kv | 10 min | Asymmetric gate (either triggers variable), cloud enhancement |

Kv is the cumulative absolute first-derivative of **clear-sky-detrended** GHI. Each minute-to-minute GHI change has the corresponding maxSolarRad change subtracted before taking the absolute value and summing. This removes the deterministic solar geometry signal (the sun rising and setting changes GHI even under clear skies) and isolates cloud-induced variability. Without detrending, a clear afternoon's steady GHI decline produces elevated Kv, causing false "Mostly Clear" classifications.

**Scientific basis:** See ADR-073 §2 for why clear-sky detrending is necessary and the research (Stein et al. 2012, Coimbra et al. 2013) that establishes it as standard practice. Full citations in `docs/reference/sky-classification-science.md` §2.

**Classification — Kv-first decision tree:**

*Step 0: Pre-checks*

- Night/twilight (max(radiation, maxSolarRad) < 20 W/m²) → clear ring buffer, return None
- Solar elevation < 15° → return None (SZA guard; see below)
- Ring buffer < 3 entries → return None (insufficient data)

*Step 1: Cloud enhancement (evaluated before Kv split)*

| Conditions | Display label |
|-----------|---------------|
| Kcs > 1.06 AND Kv > 0.20 AND Kvf > 0.20 AND maxSolarRad > 100 W/m² | Partly Cloudy |

Cloud enhancement (GHI exceeding clear-sky) physically requires nearby cloud edges — a broken-cloud scenario. Maps to "Partly Cloudy" rather than "Clear" for physical accuracy. See ADR-073 §6.

*Step 2: Primary axis — asymmetric Kv/Kvf gate (uniform vs. variable sky)*

Six independent papers confirm the inverted-U relationship between cloud fraction and irradiance variability: variability peaks at ~50% cloud fraction and drops to near-zero at 0% (clear) and 100% (overcast). Low Kv means uniform sky (either clear or fully overcast). Elevated Kv means broken coverage. See ADR-073 §1.

The gate uses asymmetric sensitivity across the two variability windows:

| Condition | Branch | Rationale |
|-----------|--------|-----------|
| Kv ≥ 0.05 OR Kvf ≥ 0.05 | Variable sky → Step 4 | Responsive: any recent variability (even only in the 10-min window) means the sky is broken *now* |
| Kv < 0.05 AND Kvf < 0.05 | Uniform sky → Step 3 | Conservative: declaring "no breaks" requires sustained calm across both the 30-min and 10-min windows |

This asymmetry matches perception: a single cloud transit is immediately visible to anyone looking at the sky, but "the sky has been completely uniform for a while" is a stronger claim that needs more evidence. It also replaces explicit hysteresis — entering the variable branch is easy (fast response to cloud transits), returning to uniform is hard (prevents premature "Overcast" calls during brief lulls in a broken sky).

*Step 3: Uniform sky (both Kv AND Kvf < 0.05) — Km distinguishes clear vs. overcast*

| Conditions | Display label |
|-----------|---------------|
| Km > 0.85 AND Kcs > 0.80 | Clear |
| Km > 0.35 | Overcast |
| Km ≤ 0.35 | Heavy Overcast |

In the uniform branch, both variability windows confirm no cloud-edge transitions. Every non-clear outcome is overcast by definition (NWS OVC, 8/8, no gaps). Km distinguishes cloud thickness within the overcast family: thin to moderate uniform layer (Overcast) vs. thick layer with low transmittance, correlated with imminent precipitation (Heavy Overcast).

*Step 4: Variable sky (Kv OR Kvf ≥ 0.05) — Kmf distinguishes coverage degree*

| Conditions | Display label |
|-----------|---------------|
| Kmf > 0.85 | Mostly Clear |
| Kmf > 0.60 | Partly Cloudy |
| Kmf > 0.40 | Mostly Cloudy |
| Kmf ≤ 0.40 | Cloudy |

The variable branch uses **Kmf** (10-minute mean transmittance) instead of Km (30-minute). When the sky has breaks and conditions are actively changing, the last 10 minutes reflect what the visitor sees now — not what the sky looked like 20 minutes ago. The uniform branch retains Km (30-minute) because stable sky conditions warrant a longer average.

"Cloudy" here (NWS: 87–100%, includes 7/8 BKN) differs from "Overcast" (8/8 OVC) by the existence of breaks — variability confirms them even when infrequent.

**Dynamic threshold function:**

Km thresholds are not fixed constants. `get_dynamic_clear_threshold(α)` computes the boundary as a function of solar elevation α (degrees):

```
K_threshold(α) = K_min + (K_max - K_min) · (1 − e^(−b · α))
```

This exponential saturating function approaches K_max at high solar elevations and floors at K_min near the horizon. Scientific basis: Smith, Bright & Crook (2017) proved that clear-sky index distributions shift with solar elevation — fixed thresholds cannot work across all elevations. Full derivation in `docs/reference/sky-classification-science.md` §14.

**Default parameters:**

| Parameter | Default | Role |
|---|---|---|
| `dt_k_max_clear` | 0.80 | Asymptotic upper bound (K_max) for the clear/mostly-clear boundary |
| `dt_k_min` | 0.35 | Floor value (K_min) at zero elevation |
| `dt_b` | 0.1 | Scaling factor controlling how quickly the threshold rises with elevation |

**Threshold constants (non-dynamic):**

| Constant | Value | Role |
|---|---|---|
| `_KV_UNIFORM` | 0.05 | Primary split: uniform vs. variable sky |
| `_UNIFORM_CLEAR_MIN_KCS` | 0.80 | Uniform branch: clear sky Kcs sanity check |
| `_UNIFORM_HEAVY_MAX_KM` | 0.35 | Uniform branch: heavy overcast maximum Km (not elevation-adjusted) |

**How the dynamic threshold applies:**

Both the uniform and variable branches call `get_dynamic_clear_threshold(α)` with branch-specific K_max values:

| Branch | Boundary | K_max applied |
|--------|----------|---------------|
| Uniform | Clear vs. Overcast | 0.80 |
| Variable | Mostly Clear vs. Partly Cloudy | 0.80 |
| Variable | Partly Cloudy vs. Mostly Cloudy | 0.60 |
| Variable | Mostly Cloudy vs. Cloudy | 0.40 |

K_min (0.35) and b (0.1) are shared across all branches.

**Operator adjustability:** `configure()` accepts `dt_k_max_clear`, `dt_k_min`, `dt_b`, and `sza_guard_elevation` to override defaults. These will be exposed in `api.conf [sky_classification]` (not yet wired — future task).

**Temporal coherence filter:** A raw classification must persist for 5 consecutive minutes before becoming the stable label. On startup, 2-minute grace applies. (Reduced from 15/3 minutes — the 30-minute Kv/Km averaging and the asymmetric Kv/Kvf gate already provide substantial smoothing; stacking a 15-minute coherence filter on top created up to 45 minutes of lag, which is unacceptable for a weather display.)

**Startup backfill:** On API restart, `backfill()` seeds the ring buffer from archive records (last 30 minutes) for immediate classification. Full accuracy after ~30 minutes of live LOOP data.

**GHI mirroring across sunrise/sunset:** At sunrise, the trailing 30-minute window has only a few minutes of data. Under overcast, this inflates Km (diffuse radiation at low angles is a high fraction of the small clear-sky reference), producing incorrect sunny/scattered labels. The mirroring algorithm (adapted from CAELUS `sky_indices.py:mirror_ghi_with_pandas()`) generates synthetic pre-sunrise data points using cos(zenith) interpolation from post-sunrise measurements, stabilizing the rolling statistics. Station coordinates (lat/lon/altitude from `services/station.py`) and Skyfield ephemeris (from `services/almanac.py`) are used to compute cos(zenith) for both real and mirrored entries. Full scientific description in `docs/reference/sky-classification-science.md` §3. See ADR-073 §4.

**SZA < 75° classification guard:** When solar elevation < 15° (SZA > 75°), `classify()` returns None. The downstream consumer (`enrichment/weather_text.py`) falls back to provider cloud cover. Below 15° elevation, pyranometer readings are dominated by diffuse radiation and cosine error — the clear-sky index loses discriminatory power. Solar elevation is computed via Skyfield from station coordinates (same ephemeris used by the almanac service). The `_MIN_SOLAR_RAD = 20 W/m²` proxy is retained for ring buffer data acceptance — data still accumulates below the SZA threshold to be available when elevation crosses 15°. See ADR-073 §5.

**Haze/smoke detection:** Implemented — see §8 Haze detection subsection below (ADR-067).

**Secondary source (night / twilight / startup / no pyranometer):** Provider cloud cover percentage, via `_cloud_pct_to_sky()`. Thresholds: ≤10% Clear, ≤25% Mostly Clear, ≤50% Partly Cloudy, ≤85% Mostly Cloudy, ≤95% Cloudy, >95% Overcast. Note: these code thresholds are wider bins than NWS ASOS okta-based categories and are a pragmatic approximation. Operator adjustability planned via the admin UI.

**Scientific basis:** ADR-073 records the scientific reasoning behind every threshold and classification decision. Full citations in `docs/reference/sky-classification-science.md`.

### Day/night display vocabulary

Apply day/night vocabulary at display time via substring replacement ("Clear"→"Sunny", "Mostly Clear"→"Mostly Sunny"):

| Classification | Day display | Night display |
|----------------|-------------|---------------|
| Clear | Sunny | Clear |
| Mostly Clear | Mostly Sunny | Mostly Clear |
| Partly Cloudy | Partly Cloudy | Partly Cloudy |
| Mostly Cloudy | Mostly Cloudy | Mostly Cloudy |
| Cloudy | Cloudy | Cloudy |
| Overcast | Overcast | Overcast |
| Heavy Overcast | Heavy Overcast | Heavy Overcast |

Solar zenith > 96° = night; 75–96° = twilight/SZA guard zone (fall back to provider); < 75° = day (solar classification active). Solar elevation computed via Skyfield from station lat/lon/altitude (`services/almanac.py`). The SZA < 75° guard (elevation ≥ 15°) gates classification; below this threshold `classify()` returns None and the provider fallback supplies the sky label.

**Scientific basis:** ADR-073 (supersedes ADR-044). Full citations in `docs/reference/sky-classification-science.md`.

### Precipitation

**Primary source:** Local rain gauge (`rainRate`). Use WMO/AMS thresholds (in in/hr; convert from station units before comparing):

| rainRate | Category |
|----------|----------|
| 0 or null | No precipitation |
| > 0 and < 0.10 | Light Rain |
| ≥ 0.10 and < 0.30 | Moderate Rain |
| ≥ 0.30 | Heavy Rain |

**Frozen precipitation:** When `rainRate > 0` AND provider reports `precipType` of "snow", "freezing-rain", or "sleet", use the provider's type only if the Stull (2011) wet-bulb temperature is ≤ 35 °F. Above 35 °F, frozen precipitation is thermodynamically implausible — use "Rain" regardless of provider forecast.

Wet-bulb formula (Stull 2011, T in °C, RH in %):

```
Tw = T × atan(0.151977 × (RH + 8.313659)^0.5) + atan(T + RH)
   − atan(RH − 1.676331) + 0.00391838 × RH^1.5 × atan(0.023101 × RH)
   − 4.686035
```

### Wind

Beaufort scale thresholds (WMO standard; all comparisons use m/s internally — convert from station unit before comparing):

| Beaufort | m/s range | Label |
|----------|-----------|-------|
| 0 | < 0.5 | Calm |
| 1 | 0.5–1.5 | Very Light Breeze |
| 2 | 1.6–3.3 | Light breeze |
| 3 | 3.4–5.4 | Gentle breeze |
| 4 | 5.5–7.9 | Moderate breeze |
| 5 | 8.0–10.7 | Fresh breeze |
| 6 | 10.8–13.8 | Strong breeze |
| 7 | 13.9–17.1 | Near gale |
| 8 | 17.2–20.7 | Gale |
| 9 | 20.8–24.4 | Strong gale |
| 10 | 24.5–28.4 | Storm |
| 11 | 28.5–32.6 | Violent storm |
| 12 | ≥ 32.7 | Hurricane |

Labels use sentence case. Beaufort 0 ("Calm") appears in the composed text — calm is a real atmospheric state, not the absence of data.

**Gusty qualifier:** Append "and Gusty" when `windGust ≥ windSpeed + 12 mph` AND `windGust ≥ 18 mph`. Convert both speeds to mph before comparison regardless of station unit. The qualifier only fires when wind is not Calm (Beaufort > 0).

### Temperature-comfort (2D matrix)

**Temperature axis** — apparent temperature (`appTemp` in °F):

| Tier | appTemp range | Base label |
|------|---------------|------------|
| 1 | ≤ −10 °F | Dangerously Cold |
| 2 | −9 to 0 °F | Bitter Cold |
| 3 | 1 to 10 °F | Extreme Cold |
| 4 | 11 to 20 °F | Very Cold |
| 5 | 21 to 32 °F | Cold |
| 6 | 33 to 45 °F | Chilly |
| 7 | 46 to 60 °F | Cool |
| 8 | 61 to 75 °F | Pleasant |
| 9 | 76 to 85 °F | Warm |
| 10 | 86 to 95 °F | Hot |
| 11 | 96 to 104 °F | Very Hot |
| 12 | ≥ 105 °F | Dangerously Hot |

**Moisture axis** — dewpoint (°F):

| Tier | Dewpoint range | Moisture modifier |
|------|----------------|-------------------|
| A | < 45 °F | (omitted) |
| B | 45–54 °F | (omitted) |
| C | 55–59 °F | Slightly Humid |
| D | 60–64 °F | Humid |
| E | 65–69 °F | Very Humid |
| F | 70–74 °F | Oppressive |
| G | ≥ 75 °F | Miserable |

**Composition rules:**

1. Cold temperatures (appTemp ≤ 32 °F, tiers 1–5): always omit moisture modifier. Output = temperature label only.
2. Warm temperatures, dry moisture (tiers 6–12 × A–B): output = temperature label only.
3. Warm temperatures, humid moisture (tiers 6–12 × C–G): output = temperature label + "and" + moisture label.
4. **NWS Heat Index danger escalation** (overrides rules 1–3): HI ≥ 125 °F → "Extreme Danger Heat"; HI ≥ 104 °F → "Dangerous Heat".
5. **NWS Wind Chill danger escalation** (overrides rules 1–3): WC ≤ −45 °F → "Extreme Danger Cold"; WC ≤ −25 °F → "Dangerous Cold".
6. **Near-saturation override:** When dewpoint depression (outTemp − dewpoint) ≤ 5 °F, append "and Foggy" to any output from rules 1–5.

When `appTemp` is null or absent, omit the temperature-comfort component entirely.

### Input stability

Apply three stability mechanisms before any threshold comparison:

**Smoothing windows:**

| Input | Window |
|-------|--------|
| Solar radiation (GHI → 1-min bins) | 30 min |
| UV | 10 min |
| appTemp, dewpoint, outTemp | 10 min |
| windSpeed, windGust | 5 min |
| rainRate | 2 min |
| heatIndex, windChill | 10 min |

**Hysteresis bands:**

| Dimension | Band |
|-----------|------|
| Temperature thresholds | ±2 °F |
| Wind thresholds | ±2 mph |
| Dewpoint thresholds | ±2 °F |
| Rain rate thresholds | ±0.02 in/hr |

**Minimum hold time:** 5 minutes. After composition, hold the conditions text string for 5 minutes before allowing any change, even when smoothed + hysteresis inputs produce a different result.

**Sky condition stability:** The sky classifier uses a temporal coherence filter instead of hysteresis — a raw classification must persist for 15 consecutive minutes before replacing the stable label. This is independent of the 5-minute conditions text hold time, which still applies to the composed `weatherText` string.

### Composition order

Assemble components in this order: **[temperature-comfort, sky, wind, precipitation]**. Drop null or omitted components.

| Number of non-null parts | Format |
|--------------------------|--------|
| 1 | `"{part}"` |
| 2 | `"{a}, with {b}"` |
| 3+ | `"{a}, {b}, with {last}"` |

Examples: "Warm and Humid, Overcast, with Light Rain" / "Pleasant, Partly Cloudy, with Moderate Breeze" / "Chilly, with Light Rain".

### Startup

On API restart, `backfill()` seeds the sky classifier's ring buffer from archive records (last 30 minutes), enabling immediate classification. A 3-minute startup grace period applies to the temporal coherence filter. If no archive records are available (fresh install), fall back to provider cloud cover until the ring buffer accumulates ≥ 3 minutes of live LOOP data. If no provider data is available, report sky condition absent (wind and comfort components still compose).

### Transport

`weatherText` is REST-only. It appears in `/current` responses. It is not transmitted via SSE.

### Enrichment processor registration order

Register processors in this exact order — the smoother must run before classifiers:

1. `input_smoother`
2. `uv_smoother`
3. `sky_tap`
4. `wind_rolling_window`
5. `lightning_strike_buffer`
6. `scene_packet_tap`

### Endpoint enrichment registration

Two endpoint keys receive enrichment:

| Endpoint key | Enrichments registered |
|--------------|------------------------|
| `"current"` | barometer_trend, wind_rolling_average, lightning_history, weather_text, uv, scene (6 total) |
| `"almanac/planets"` | planet_viewing (1 total) |

### Haze detection

Two-channel confirmation is required before the engine labels conditions as hazy. Haze is only reported when BOTH channels confirm: (1) pyranometer Kcs deficit below the dynamic clear-sky threshold (Channel 1 uses `get_dynamic_clear_threshold(α)` from `sky_condition.py` — the same elevation-dependent threshold function used by the sky classifier) AND (2) PM2.5 or PM10 from an observed-data AQI provider (ADR-066) exceeds the confirmation threshold.

**Solar elevation gate:** el > 15° required. Below 15°, the clear-sky index is unreliable due to diffuse radiation dominance and cosine error. Haze detection is inactive when el ≤ 15°. This gate matches the sky classifier's SZA guard.

**PM confirmation thresholds:**

| RH range | PM2.5 threshold | PM10 threshold | Basis |
|----------|----------------|----------------|-------|
| < 60% (dry) | > 50 µg/m³ | > 100 µg/m³ | CMA dry haze threshold (~54 µg/m³ PM2.5 for vis < 10 km). Coarse mass scaled by IMPROVE extinction ratio. |
| 60–80% (moderate) | > 35 µg/m³ | > 75 µg/m³ | CMA moderate humidity, EPA 24-hr NAAQS, WMO dusty-air midpoint, China secondary standard. |
| 80–90% (humid) | > 25 µg/m³ | > 50 µg/m³ | Hygroscopic swelling — less mass produces same extinction. EEA annual standard, WMO/Australia lower bound. |

Both PM2.5 and PM10 are independent first-class indicators evaluated in parallel. Either species alone confirms Channel 2. PM10 is NOT a fallback. See `docs/reference/haze-detection-research.md` for the full research backing these thresholds.

**f(RH) hygroscopic correction:** Applied to the Kcs-deficit channel before threshold comparison:

```
f(RH) = [(1 - RH) / (1 - RH_ref)]^(-γ)
```

Default γ = 0.45 (moderate, composition-unknown). γ is a composition property (range 0.12 for mineral dust to 1.52 for sea salt per Hanel 1976 and Tang 1996) — it is NOT a particle-size property. Operator-configurable by region via admin UI.

**RH type discriminator:**

| RH range | Classification |
|----------|---------------|
| < 80% | Dry haze |
| 80–90% | Damp haze (hygroscopic swelling enhances scattering) |
| > 90% | Defer to fog/mist detection (ADR-069) — do NOT report haze |

**Gates and suppression:**

1. **Wet deposition gate:** Suppress haze during active precipitation and for 30 minutes after rain ends. Rain scavenges aerosols.
2. **Temporal coherence:** 5-minute persistence filter (matches sky classifier coherence window). Prevents haze label flicker.
3. **Clear-sky-only constraint:** Haze is a clear-sky modifier. Do NOT apply haze when sky is classified as Mostly Cloudy, Cloudy, Overcast, or Heavy Overcast. "Hazy and Overcast" is invalid.
4. **Stale PM data:** If last PM reading is > 2 hours old, treat as unavailable. Do not conclude "no haze" from stale data — absence of fresh evidence is not evidence of absence.

**Haze-eligible providers:** Only AQI providers where `ProviderCapability.is_observed_source = True` (ADR-066). Open-Meteo (CAMS model) and OWM (SILAM model) are not observed-data sources and their PM readings are never used for haze confirmation.

**Graceful degradation:** When no observed PM data is available, the haze channel is absent. The existing sky classifier continues operating unchanged. No haze label is emitted.

**Display format:**

| Verbosity | Format |
|-----------|--------|
| Standard / verbose | "Sunny. Hazy." — separate sentence (NWS convention) |
| Terse | "Sunny, Hazy" — compound form |

**WMO weather code:** 05 (Haze). Priority ordering: precipitation > fog > mist > haze > sky.

### Haze detection configuration (api.conf [conditions])

The following keys in the `[conditions]` section of `api.conf` control haze detection behavior (ADR-067/068). All keys are optional; defaults match the algorithm constants.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `haze_detection` | bool | `true` | Enable or disable haze detection entirely. When `false`, `detect_haze()` always returns `None`. |
| `haze_aqi_provider` | str or absent | (inherits from `[aqi]`) | Override the AQI provider used for haze PM data. If absent or empty, uses the provider configured in `[aqi]`. |
| `gamma` | float | `0.45` | Hygroscopic correction exponent γ (Hanel 1976 / Tang 1996). Controls how strongly relative humidity amplifies apparent aerosol extinction. Advanced operator override — the default 0.45 is the composition-unknown value suitable for most stations. Range: 0.1–1.0. |

Validation errors in any of these keys cause a fatal startup failure with a descriptive message.

**Graceful sensor failover:**

| Sensor absent | Failover |
|---------------|---------|
| `radiation` (no pyranometer) | Sky: provider cloud cover % (unchanged). Haze: provider present weather (HZ) 24/7. |
| `dewpoint` (no hygrometer) | Fog/mist: provider present weather (BR/FG). f(RH) correction: skipped (uncorrected Kcs deficit used). |

Dashboard never shows null data — absent sensors silently defer to provider present-weather codes.

---

### Fog/mist detection

Replaces the single-variable T-Td ≤ 1°F near-saturation override (Temperature-comfort rule 6). The multi-parameter algorithm below achieves >90% hit rate vs ~40% false-alarm rate from single-variable T-Td detection (Izett et al. 2018, PMC6208920). Note: the Temperature-comfort rule 6 text remains in place until a dedicated cleanup pass — this subsection is the operative rule.

**T-Td gate (ASOS standard):** Widened from 1°F to ≤ 4°F. Fog and mist are suppressed when T-Td > 4°F.

**Fog/mist split:**

| T-Td | Classification | WMO code |
|------|---------------|----------|
| ≤ 2°F | Foggy | 45 (Fog) |
| 2–4°F | Misty | 10 (Mist) |

**Wind gate:** Convert from the operator's configured unit system to m/s before comparison.

| Wind speed | Fog-eligible | Mist-eligible |
|------------|-------------|---------------|
| ≤ 3 m/s (~7 mph) | Yes | Yes |
| 3–7 m/s (~15 mph) | No | Yes |
| > 7 m/s | No — suppressed | No — suppressed |

**Daytime solar suppression:**

| Condition | Result |
|-----------|--------|
| Kcs > 0.3 AND T-Td 2–4°F | Suppress — humid air, not fog |
| Kcs > 0.3 AND T-Td ≤ 2°F | Do NOT suppress — dense fog persists through sunrise |

**PM2.5 disambiguation:** When T-Td ≤ 4°F AND PM2.5 > 35 µg/m³, report "Hazy" rather than "Foggy" or "Misty". Elevated PM in near-saturated conditions indicates particulate haze with moisture absorption, not water-droplet fog. Only applied when fresh PM data is available; if PM data is absent or stale, fog/mist classification proceeds without this check.

**Additional gates:**

1. **Rain gate:** Suppress fog/mist during active precipitation. Precipitation fog is a distinct phenomenon not reported here.
2. **Fog dissipation:** After sunrise, suppress fog label when Kcs > 0.5 AND T-Td is widening beyond 4°F. Prevents a stale fog label persisting into a sunny morning.
3. **Temporal coherence:** 15-minute persistence filter. Prevents rapid cycling when T-Td oscillates near threshold.

**Display format:** "Foggy." or "Misty." as a separate sentence (NWS convention).

**Irreducible limitation:** Without a visibility sensor, the engine reports conditions favorable for fog, not confirmed fog. The provider cross-check mitigates this by requiring a visibility-equipped station to corroborate, but the fundamental limitation remains for hyper-local fog events. This matches WMO Code 4680 automated-station constraints.

---

### Provider cross-check (fog/mist)

Local T-Td detection identifies conditions favorable for fog but cannot confirm ground-level visibility reduction without a visibility sensor. To reduce false positives — particularly in coastal environments where marine-layer humidity routinely drives T-Td below 2°F without producing fog — the engine requires provider corroboration before reporting fog or mist.

**Bidirectional confirmation table:**

| Local sensors | Provider observation | Result |
|---|---|---|
| Favorable (T-Td ≤ 2°F, calm) | Reports fog/mist | **Foggy/Misty** — both agree |
| Favorable | No fog/mist reported | **Suppress** — near-saturation but no visibility confirmation |
| Favorable | Provider data stale/unavailable | **Allow local** — absence of data is not evidence of absence |
| Not favorable (T-Td > 4°F or windy) | Reports fog/mist | **No adoption** — local conditions do not support fog at this station |

**Provider keyword matching:** Lowercase provider weather text, substring search for `"fog"` or `"mist"`. Matches: "Fog", "Dense Fog", "Patchy Fog", "Fog/Mist", "Mist", etc.

**Stale-data grace:** When provider data is unavailable (> 2 hours old or never set), the cross-check does not fire. Local detection stands on its own. This prevents the system from going silent about fog when the provider is down.

**Scientific justification:** ASOS/AWOS visibility sensors (WMO, ICAO) are the operational standard for fog detection. This station lacks a visibility sensor; the cross-check supplements local thermodynamic detection with a remote visibility observation from the nearest equipped station.

**Tradeoff:** Reduced false positives at the cost of delayed detection for genuinely hyper-local fog events. Real fog at the station may not be reported until the provider's station (~5-30 min lag) also detects it. For stations in marine-layer-prone coastal environments, this tradeoff favors accuracy over immediacy.

**Graceful degradation:** When no forecast provider is configured or the provider does not supply current weather text, the cross-check is inactive. Local fog detection operates standalone (original behavior).

---

### Nighttime mode

At night (solar elevation below the haze detection gate, el ≤ 10–15°), the pyranometer contributes nothing to haze detection. Three channels are assigned distinct data sources:

| Condition | Nighttime source |
|-----------|-----------------|
| Cloud cover | Provider observation (existing behavior, unchanged) |
| Haze / smoke | Provider current-conditions present weather field |
| Fog / mist | Local multi-parameter detection (ADR-069) — T-Td + wind |

**Rationale for split:** Provider stations (ASOS/AWOS at airports, EPA monitors) have visibility sensors and present weather detectors. For haze, their sensor suite outperforms PM-only local estimation. For fog, the station-level T-Td measurement is genuinely more local than the nearest airport observation (potentially 10+ km away) — hyper-local sensors add real value for radiation fog that forms post-sunset.

**Sunrise handoff:** When solar elevation crosses the haze detection gate (10–15°), the full local two-channel model resumes. Provider haze/smoke stops being authoritative; local detection takes over.

**Fog continuity:** `detect_fog_mist()` runs continuously regardless of mode. At night, solar radiation is zero, so daytime solar suppression does not trigger — fog detection proceeds on T-Td and wind alone. There is no handoff gap at sunrise; the solar dissipation check (Kcs > 0.5) simply becomes active as an additive condition.

**Provider data freshness:** If provider data is > 2 hours old at night, nighttime haze is unavailable — not "no haze." Apply the same stale-data suppression rule as daytime PM (absence of fresh data is not evidence of absence).

**Graceful degradation:** Provider absent or present-weather field missing = no haze reported at night. Fog/mist continues from local detection unaffected.

---

### Observation model

A METAR-like structured intermediate representation is populated from the enrichment pipeline on each observation cycle, before text generation. All fields are nullable.

**Local-source to METAR/WMO field mapping:**

| Local source | METAR/WMO field |
|-------------|----------------|
| `outTemp` | Temperature |
| `dewpoint` | Dewpoint |
| `windSpeed` + `windDir` + `windGust` | Wind group |
| CAELUS sky class | Sky condition (CLR / FEW / SCT / BKN / OVC) |
| Haze detection (ADR-067) | Present weather HZ |
| Fog/mist detection (ADR-069) | Present weather FG / BR |
| Precipitation type + rate | Present weather RA / SN / FZRA / etc. |
| `barometer` + trend | Pressure group |

**CAELUS-to-okta mapping:**

| CAELUS class | METAR sky code | Oktas |
|-------------|---------------|-------|
| CLOUDLESS | CLR | 0 |
| THIN_CLOUDS | FEW / SCT | 1–4 |
| SCATTERED | SCT | 3–4 |
| MOSTLY_CLOUDY | BKN | 5–7 |
| OVERCAST | OVC | 8 |

Specific okta assignment within each CAELUS class uses the Km thresholds defined in §8 Sky condition (Kv-first threshold constants table).

---

### Present weather codes

The `_derive_weather_code()` function emits WMO Code Table 4677/4680 codes. Priority ordering (highest to lowest):

1. Precipitation (RA / SN / FZRA / etc.)
2. Thunderstorm (96)
3. Fog (45)
4. Mist (10) — new, ADR-069
5. Haze (05) — new, ADR-067
6. Sky condition

**Active code set:**

| WMO code | Phenomenon | Status |
|----------|-----------|--------|
| 05 | Haze | Added — ADR-067 |
| 10 | Mist | Added — ADR-069 |
| 45 | Fog | Existing |
| 48 | Depositing rime fog (ice on surfaces + fog) | Added — ADR-070 |
| 60–69 | Rain variants | Existing |
| 70–79 | Snow variants | Existing |
| 79 | Ice pellets | Existing |
| 96 | Thunderstorm | Existing |

Anti-pattern: do NOT emit both a precipitation code and a fog/mist/haze code for the same observation cycle. Precipitation takes priority; fog/mist/haze codes are suppressed during active precipitation.

---

### Text generation engine

Three verbosity levels are available. `weatherText` carries the terse level (backward compatible). Two new fields are added to `/api/v1/current`.

**Verbosity levels:**

| Level | Field | Style |
|-------|-------|-------|
| Terse | `weatherText` | Current style — compound form OK: "Sunny, Hazy, Warm and Humid." |
| Standard | `weatherTextStandard` | NWS one-sentence per component: "Sunny. Hazy. Temperature near 85. South winds around 8 mph." |
| Verbose | `weatherTextVerbose` | Full narrative: "Currently 85°F under hazy sunshine. Dew point 72°F. South winds around 8 mph." |

**GFE threshold tables** (ported from AWIPS-II GFE text formatter, public domain):

Sky coverage buckets (6):

| Coverage | Label |
|----------|-------|
| 0–5% | Clear / Sunny |
| 5–25% | Mostly Clear / Mostly Sunny |
| 26–50% | Partly Cloudy / Partly Sunny |
| 50–69% | Mostly Cloudy |
| 70–87% | Cloudy |
| 87–100% | Overcast |

Wind descriptor thresholds (natively in mph; convert to operator unit system before rendering):

| Threshold | Descriptor |
|-----------|-----------|
| < 5 mph | Calm |
| 5–15 mph | Light |
| ~N mph (sustained) | Around N |
| N–M mph range | N to M |
| Gusts | "Gusts up to N" when gust > sustained + 10 mph |

Wind category breaks: 25 / 30 / 40 / 50 / 74 mph.

Temperature decade phrases (verbose level only): "upper 80s", "lower 20s". GFE thresholds are natively in °F; the text engine converts to the operator's configured unit system before rendering.

**NWS phrasing conventions:**

1. Haze and fog appear as separate sentences at standard and verbose levels: "Sunny. Hazy." not "Hazy and Sunny".
2. Precipitation modifies sky with "with": "Mostly Cloudy with Light Rain."
3. Day/night terminology: "Sunny" / "Clear" at night; "Partly Sunny" / "Partly Cloudy". Day/night determined by `is_daytime()` from the sky classifier (solar elevation based).

**Unit-aware rendering:** GFE threshold tables are defined in US units (mph, °F). The text engine converts thresholds to the operator's configured unit system (US / Metric / MetricWX) before composing output. The source thresholds in mph/°F are the reference for porting; rendered output uses operator units throughout.

**Backward compatibility:** `weatherText` continues to carry terse output. Existing dashboard code reading `weatherText` is unchanged. `weatherTextStandard` and `weatherTextVerbose` are additive fields.

---

## §9 Charts System — API Side

### Configuration format

Charts are configured in `charts.conf`, a ConfigObj/INI file with three-level nesting: group → chart → series. The format is intentionally identical to Belchertown's `graphs.conf` so that migrating operators can reuse their existing configuration.

Parse `charts.conf` at API startup in `services/charts_config.py`. Never re-parse mid-request.

### Self-hide pruning

At startup, after parsing `charts.conf`, prune any series whose `observation_type` is not in the column registry. Cascade the removal: if all series in a chart are removed, remove the chart. If all charts in a group are removed, remove the group. Serve the pruned config tree from `GET /api/v1/charts/config`.

Operators do not see charts for data their station does not collect.

### Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/api/v1/charts/config` | GET | Returns the full pruned config tree |
| `/api/v1/charts/custom-query/{series_id}` | GET | Executes a pre-validated operator-defined SQL query |
| `/api/v1/archive` | GET | Time-series archive data with optional aggregation |
| `/api/v1/archive/grouped` | GET | Categorical aggregation grouped by calendar period |

Do not add chart-type-specific endpoints. The API provides general-purpose data access; the dashboard determines what to fetch and how to render it.

### Custom SQL security

Accept custom SQL from `charts.conf` on disk only. Never accept SQL from HTTP request bodies or query parameters. Apply these controls in sequence:

1. **EXPLAIN pre-validation** at startup — run `EXPLAIN` on each custom query. Queries that fail `EXPLAIN` are logged as errors and excluded from the config tree.
2. **DDL keyword blocklist** — reject any query containing `CREATE`, `DROP`, `ALTER`, `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` (case-insensitive).
3. **Read-only transaction** — execute in a read-only SQLAlchemy transaction.
4. **10-second timeout** — abort queries exceeding 10 seconds.

### Archive query parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `observation_type` | string | Column name from the archive schema |
| `from` | integer | Start epoch timestamp (Unix seconds) |
| `to` | integer | End epoch timestamp (Unix seconds) |
| `aggregate_interval` | integer | Bucket size in seconds (≥ 60, no upper cap) |
| `agg_map` | string | Per-field aggregation: `field:agg_type` comma-separated |

The `aggregate_interval` parameter accepts any value ≥ 60 seconds — there is no upper bound.

### Supported aggregate types

| Type | Behavior |
|------|----------|
| `avg` | SQL AVG |
| `max` | SQL MAX |
| `min` | SQL MIN |
| `sum` | SQL SUM |
| `count` | SQL COUNT |
| `sumcumulative` | SQL SUM per bucket, then running total post-processed in Python |

The `sumcumulative` type replaces Belchertown's hardcoded `rainTotal` post-processing. Use it for cumulative rain totals.

### Archive grouped endpoint

`GET /api/v1/archive/grouped` provides categorical aggregation grouped by calendar period:

| Parameter | Type | Description |
|-----------|------|-------------|
| `group_by` | string | Grouping period: `month`, `day`, `hour`, or `year` |
| `fields` | string | Comma-separated field specs: `field:agg_type` or `field:agg_type:avg_type` |
| `from` | integer (optional) | Start epoch timestamp |
| `to` | integer (optional) | End epoch timestamp |
| `force_full_period` | boolean (optional) | Fill missing calendar slots with null when true |

There is no separate `/climatology/*` endpoint family. Use `/archive/grouped` for all calendar-grouped aggregation.

### Archive conversion

Apply `transform_record()` to all `/archive` responses. This injects `beaufort` and unit-converts all fields. Values are flattened to full-precision scalars. The exception: `beaufort` retains its `ConvertedValue` dict form so the dashboard wind rose can bin by Beaufort number without re-deriving from wind speed.

### Special series types

Four series names in `charts.conf` trigger automatic rendering behavior — the dashboard switches chart component and data-fetching strategy without additional operator config:

| Series name | Rendering | Key automatic behaviors |
|-------------|-----------|------------------------|
| `windRose` | Custom SVG polar chart (16 directions × 7 Beaufort speed bands) | Raw (unaggregated) separate archive fetch for `windSpeed`+`windDir`. Default Beaufort colors, overridable via `beaufort0`–`beaufort6` keys. Always polar. |
| `weatherRange` | Recharts arearange (default) or columnrange. Polar ONLY when `polar=true` explicitly set. | 15-band temperature color zones (°F and °C variants). Dual archive fetch `agg=min`+`agg=max`, `aggregate_interval=86400`. |
| `haysChart` | Recharts arearange, always polar | Circular 24-hour wind chart (Mount Washington Observatory style). Queries `windSpeed`+`windGust` max. `yAxis_softMax` controls radial scale. |
| `rainTotal` | Standard time-series | Migration tool auto-promotes to `aggregate_type = sumcumulative`. Queries `rain` column with `observation_type = rain`. |

All other series render as standard Recharts time-series charts (line/spline/area/column/scatter).

### All archive columns served

The `/archive` endpoint has no column whitelist gate. Any column present in the weewx archive schema is queryable by its database column name. The column registry (populated at startup by schema reflection) governs self-hide pruning — not endpoint access.

---

## §10 weewx Integration

### Co-location constraint

Deploy the API on the same host as weewx. This is an architecture constraint (per ADR-056 and ADR-034), not a recommendation. The API reads `weewx.conf` from the local filesystem; the weewx archive database is on the same host; the loop relay Unix socket is on the same host.

### weewx.units import

Use `import weewx.units` to access `obs_group_dict` for unit group auto-detection at startup. This is the authoritative mapping from weewx field name to unit group.

Import path: auto-detect by checking standard install paths, then read from `api.conf [weewx] python_path` if the operator has set a custom path. Store the resolved path in config on first successful import.

### Graceful degradation

If `import weewx.units` fails (weewx not installed at the detected path), log a warning and continue. The API still serves data. Unit group auto-detection is unavailable; the operator must specify unit groups manually in the wizard.

Never make the weewx import a fatal startup failure.

### Security boundary

The API imports only `weewx.units`. It never imports:

- `weewx.engine` — the weewx engine
- `weewx.drivers` — hardware driver modules
- `weewx.manager` — the database manager

Importing engine or driver modules could trigger hardware initialization, file locks, or database writes. Importing manager could provide accidental write access to the archive. These imports are forbidden.

---

## §11 SSE and Realtime

### Endpoint

The SSE stream is served at `GET /sse` on API port 8765. Caddy routes both `/api/v1/*` and `/sse` to port 8765. There is no separate realtime service (the former `weewx-clearskies-realtime` is deprecated per ADR-058).

### Event format

Each SSE event uses the named event type `"loop"`:

```
event: loop
data: {"outTemp": {"value": 72.3, "label": "°F", "formatted": "72.3"}, ..., "units": {...}}
```

The data field is a unit-converted JSON object in the same shape as `/current` responses, excluding `weatherText` (REST-only). Every SSE event carries the `units` metadata block.

### Input: Unix socket

The socket reader connects to the Unix socket at `/var/run/weewx-clearskies/loop.sock` published by the `ClearSkiesLoopRelay` weewx extension. The socket reader auto-reconnects with exponential backoff on weewx restart. MQTT is eliminated — direct mode via Unix socket is the only input path.

### Keepalive and buffer

- 15-second keepalive comment (`": keepalive"`) sent to all connected clients to prevent proxy timeout.
- 64-packet overflow buffer. When the buffer is full, the oldest packet is dropped.

### Module-level state

Twelve enrichment processors run in the API process. Several carry intentional process-level state:

- Ring buffers (solar radiation kc window, wind rolling window)
- Sky condition classifier (30-minute kc buffer, current classification)
- Scene descriptor (current background image state)
- Lightning strike buffer

This state is preserved correctly in a single-process deployment. Multi-worker deployment would require state sharing — this is out of scope for v0.1. The API runs as a single uvicorn worker.

### Caddy routing

Both `/api/v1/*` and `/sse` route to the API at port 8765. Example Caddyfile stanzas (single-host, dual-stack):

```
handle /api/v1/* {
    reverse_proxy localhost:8765
}
handle /sse {
    reverse_proxy localhost:8765
}
```

For dual-stack binding (IPv4 and IPv6), bind Caddy on both `0.0.0.0:443` and `[::]:443`. The API listens on `0.0.0.0:8765` (loopback or LAN depending on topology — see ARCHITECTURE.md for the authoritative port registry and topology rules).

---

## §12 Radar Endpoints and Capability Model

### Capability model extension for multi-layer providers

The `ProviderCapability` dataclass supports an optional `layers` list for providers that offer multiple data layers (e.g., the unified NOAA provider). Single-layer providers (LibreWxR, RainViewer, MSC, DWD, OWM) continue working unchanged — `layers` is optional and defaults to `None`.

Each layer in the list declares:

| Field | Type | Description |
|---|---|---|
| `layer_id` | string | Stable identifier (e.g., `"nexrad"`, `"mrms"`, `"goes_visible"`, `"spc_day1_cat"`) |
| `layer_name` | string | Display name for the UI layer panel |
| `layer_type` | string | One of: `"radar"`, `"satellite"`, `"overlay"`, `"alerts"` |
| `wms_endpoint_url` | string or None | Full WMS endpoint URL (for WMS layers the browser fetches directly) |
| `tile_url_template` | string or None | XYZ tile URL template (for tile-based layers) |
| `wms_layer_name` | string or None | WMS layer name parameter (e.g., `"nexrad-n0r-wmst"`) |
| `time_enabled` | bool | Whether this layer supports time-based animation (has frame metadata) |
| `geographic_coverage` | string | Coverage description (e.g., `"CONUS"`, `"US all territories"`) |
| `default_enabled` | bool | Whether the layer is enabled by default in the dashboard |
| `browser_direct` | bool | `True` = browser fetches tiles directly from the source. `False` = tiles proxied through the API. |

The `/api/v1/capabilities` response includes `layers` when present on a provider's capability declaration. The dashboard uses this to populate the layer panel in the expanded radar view.

### Radar endpoints

**Frame metadata:**
- `GET /api/v1/radar/providers/{id}/frames` — existing endpoint, returns frame timestamps for the primary radar layer.
- `GET /api/v1/radar/providers/{id}/layers/{layer_id}/frames` — **new** per-layer frame metadata for multi-layer providers. Returns time steps for a specific sub-layer (e.g., NOAA MRMS, NOAA satellite bands). The endpoint fetches WMS-T GetCapabilities and extracts the TIME dimension for the requested layer.

**Tile proxy:**
- `GET /api/v1/radar/providers/{provider_id}/tiles/{z}/{x}/{y}` — serves tile bytes for proxied providers. Query parameters: `?t=` (frame timestamp), `?color=` (color scheme ID, LibreWxR only).
- Internal constant renamed: `_KEYED_RADAR_PROVIDERS` → `_PROXIED_RADAR_PROVIDERS`. Contains `librewxr` and `openweathermap` (not `aeris` — removed from radar).

### LibreWxR configuration

Config field: `[radar] librewxr_endpoint` in `api.conf`.
Default: `https://api.librewxr.net`.
Self-hosted operators provide their own URL. The API fetches tile bytes from this endpoint and serves them to the browser via the tile proxy.

### Deprecated providers

`iem_nexrad` and `noaa_mrms` modules remain on disk. When configured, they log a migration warning at startup:
```
WARNING: Radar provider 'iem_nexrad' is deprecated. Migrate to 'noaa' for unified US radar coverage.
```
They continue to function as before — no breaking change for existing operators.

`aeris` is removed from `_PROXIED_RADAR_PROVIDERS` and from the radar domain's capability wiring. Aeris credentials are still wired for forecast/AQI/alerts.

---

## §13 Anti-Patterns

Never do any of the following.

| Anti-pattern | Correct approach |
|--------------|-----------------|
| **Create chart-specific API endpoints** (e.g., `/charts/wind-rose`, `/charts/temperature-range`). | The API is general-purpose data access. Serve `/archive` and let the dashboard determine rendering. Use `/charts/custom-query/{series_id}` only for operator-defined SQL queries from `charts.conf`. |
| **Duplicate Beaufort, comfort-index, or unit conversion thresholds in dashboard code.** | The API computes all derived values. The dashboard reads `beaufort.value`, `comfortIndex`, and `label` strings. It performs zero unit math. |
| **Hardcode weewx column names in endpoint handlers.** | Use the column registry populated by schema reflection at startup. Endpoints select columns from the operator's mapping — never from a hardcoded list. |
| **Serve local-time strings in API responses.** | All time fields use UTC ISO-8601 with a `Z` suffix. Display-side timezone conversion happens in the dashboard using the station's IANA timezone from `StationMetadata`. |
| **Write to the weewx database.** | The API is read-only by architecture. The startup write probe enforces this. The API never holds a writable DB connection. |
| **Import `weewx.engine`, `weewx.drivers`, or `weewx.manager`.** | Import only `weewx.units`. Engine and driver imports risk hardware initialization and file locks. Manager imports risk write access. |
| **Accept custom SQL from HTTP.** | Custom SQL comes from `charts.conf` on disk only. Config file is operator-controlled (same trust model as Belchertown). HTTP-supplied SQL is rejected unconditionally. |
| **Return a response without the `units` metadata block.** | Every API response — observation, archive, forecast, AQI, alert — carries the `units` block. Use `exclude_none=False` serialization. |
| **Place secrets in `.conf` files.** | Secrets (API keys, DB passwords, cache URL with credentials) go in `secrets.env` (mode 0600), injected as environment variables. Config files (`api.conf`, `charts.conf`) are operator-readable and must contain no credentials. |
| **Exceed the 366-day time-range cap on archive queries.** | Enforce a 366-day maximum on all archive time-range parameters. Return HTTP 400 with RFC 9457 body when the requested range exceeds the cap. |
| **Use a separate conversion layer between the API and dashboard.** | The former realtime BFF proxy is eliminated. The API converts directly. Caddy routes `/api/v1/*` and `/sse` both to the API at port 8765. There is no intermediate service. |
| **Use MQTT as the loop packet input.** | MQTT input mode is eliminated (per ADR-058). The only input path is the Unix socket at `/var/run/weewx-clearskies/loop.sock` from the `ClearSkiesLoopRelay`. |
