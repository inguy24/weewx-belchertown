# ADR Consolidation Plan — Four New Manuals

**Status:** COMPLETE — All 4 manuals delivered (API-MANUAL, PROVIDER-MANUAL, OPERATIONS-MANUAL, DASHBOARD-MANUAL), 48 ADRs archived, INDEX.md updated, CLAUDE.md routing updated, process rules updated. Archived 2026-06-27.
**Created:** 2026-06-17
**Approved:** 2026-06-17
**Scope:** Consolidate all remaining ADRs into authoritative manuals, following the DESIGN-MANUAL.md pattern
**Components:** 4 new manuals (`docs/manuals/API-MANUAL.md`, `docs/manuals/PROVIDER-MANUAL.md`, `docs/manuals/OPERATIONS-MANUAL.md`, `docs/manuals/DASHBOARD-MANUAL.md`), ARCHITECTURE.md restructure, CLAUDE.md routing, process rule updates, registry system, 48 ADR archives
**Repos affected:** `weather-belchertown` (meta/planning), `weewx-clearskies-api` (code audit reference), `weewx-clearskies-dashboard` (code audit reference), `weewx-clearskies-stack` (code audit reference)

---

## Session Context for Execution

**What happened in the planning session (2026-06-17):**
1. Analyzed all 44 remaining ADRs (read full content for substantive ones).
2. Proposed a 4-manual split: API, Provider, Operations, Dashboard.
3. Conducted a thorough code audit of all 3 repos (`weewx-clearskies-api`, `weewx-clearskies-dashboard`, `weewx-clearskies-stack`), reading actual source files (`__main__.py`, `app.py`, `config/settings.py`, `providers/_common/errors.py`, `providers/_common/http.py`, `providers/_common/capability.py`, `providers/_common/dispatch.py`, `hooks/useApiQuery.ts`, `hooks/useSSE.ts`, `hooks/useRealtimeObservation.ts`, `api/client.ts`).
4. Found 24 significant code patterns not captured in any ADR or doc. 3 are outright contradictions; 15 extend beyond ADRs; 6 correctly implement ADRs but have undocumented details.
5. Designed a registry system (OpenAPI spec for endpoints, `canonical-data-model.md` for fields, `dispatch.py` for providers, `settings.py` for config keys) so manuals document rules, not volatile inventories.
6. Added a doc-code sync discipline rule for CLAUDE.md to prevent the drift that caused the contradictions.
7. User confirmed: wizard steps should NOT be pinned in docs (they morph); ADR-045 and ADR-046 are both Accepted (INDEX.md is wrong); endpoints ARE serious and must be tracked.

**Key files the coordinator must read before Phase 0B:**
- `contracts/security-baseline.md` — needed for OPERATIONS-MANUAL §10
- `contracts/canonical-data-model.md` — the data field registry (stays standalone, manual cross-references it)
- The 14 ADRs listed in Phase 0 "Remaining coordinator reading" — full read needed for prescriptive rule extraction

**Key decision from the user:** Manuals are prescriptive rule books, not inventories. Volatile inventories (endpoints, fields, providers, wizard steps) point to code or auto-generated specs as the source of truth. Stable contracts operators depend on (ports, file paths, Caddy routes) are documented explicitly.

---

## Context

The DESIGN-MANUAL.md consolidation (completed 2026-06-16) proved that a single authoritative manual eliminates the "scattered ADRs" problem — agents actually follow the rules because they read one document, not eight. 10 UI ADRs were archived; the manual is now the single authority for UI design.

32 active ADRs remain, plus 2 superseded ADRs, plus 7 "meta" ADRs whose substance is already captured in ARCHITECTURE.md. The same problem exists for API development, provider modules, operations, and dashboard technical behavior: rules are scattered across 30+ ADRs that no agent reads in full before acting.

**Goal:** Create 4 new manuals that, together with DESIGN-MANUAL.md and ARCHITECTURE.md, eliminate all remaining ADRs as operational references. ADRs become historical "why" records; manuals say "what to do."

**Relationship to existing docs:**
- **ARCHITECTURE.md** = what the system IS (topology, ports, endpoints, containers). Stays as-is. Does NOT become a manual — it's a reference, not prescriptive rules.
- **DESIGN-MANUAL.md** = how to build UI (visual design rules). Already done.
- **New manuals** = how to build/modify each domain (prescriptive rules for implementation).
- **ADRs** = why decisions were made (historical, archived after consolidation).
- **contracts/security-baseline.md** = absorbed into OPERATIONS-MANUAL.md, then archived.

---

## 0. Code Audit Findings — Patterns NOT in ADRs

A thorough code audit of all three repos found **24 significant patterns** that exist in the code but are not documented in any ADR, ARCHITECTURE.md, or other reference. These MUST be captured in the manuals — otherwise the manuals would just be ADR transcriptions and miss what the code actually does.

### API Patterns (code-only, not in ADRs)

| # | Pattern | Location | Manual target |
|---|---------|----------|--------------|
| 1 | **Setup mode vs configured mode** — API starts with only setup endpoints + catch-all 503 (`urn:clearskies:not-configured`) when `settings.configured=False`. No DB, no providers. | `__main__.py` L576-586, `app.py` L125-152 | API §1 |
| 2 | **`/api/v1/status` endpoint** — returns `{configured: bool}` in both modes. Not in ARCHITECTURE.md endpoint tables. | `app.py` L127-129 | API §2 + ARCHITECTURE.md |
| 3 | **Cache warmer is implemented** — ADR-045 says "Proposed" but `BackgroundCacheWarmer` is wired into startup (step 6h½). Runs `initial_warm()` then background thread. | `__main__.py` L736-756 | PROVIDER §3 |
| 4 | **20+ step startup sequence** with explicit fatal vs non-fatal error handling per step. Far more detailed than any ADR. | `__main__.py` L477-904 (full `main()`) | API §1 |
| 5 | **Enrichment processor registration order** — `input_smoother → uv_smoother → sky_tap → wind_rolling_window → lightning_strike_buffer → scene_packet_tap`. Order matters; only in code. | `__main__.py` L869-875 | API §8 |
| 6 | **Endpoint enrichment registration** — 7 enrichments on 2 endpoint keys: `"current"` (6) and `"almanac/planets"` (1). | `__main__.py` L884-891 | API §8 |
| 7 | **Column unit validation at startup** — `_validate_column_units()` cross-checks confirmed units against weewx metadata. Mismatches = warning, not fatal. | `__main__.py` L109-151 | API §6 |
| 8 | **Target unit system inference** — Derives US/METRIC/METRICWX from api.conf `[units]` by checking group_temperature + group_rain values. | `__main__.py` L662-678 | API §6 |
| 9 | **Provider dispatch registry** — explicit `dict[(domain, provider_id) → ModuleType]` in `dispatch.py`. Adding a provider = import + one dict row. | `providers/_common/dispatch.py` | PROVIDER §1 |
| 10 | **ProviderHTTPClient** — one instance per provider at module-load. Retry: max 2 retries (3 total), base 0.5s, factor 2.0, cap 5.0s, ±25% jitter. `follow_redirects=False` by default (prevents token leak). | `providers/_common/http.py` | PROVIDER §1 |
| 11 | **Provider error → HTTP status mapping** — QuotaExhausted→503+Retry-After, Geo/Unsupported→503, KeyInvalid/FieldUnsupported/TransientNetwork/ProtocolError→502. | `providers/_common/errors.py` L8-15 | PROVIDER §10 |
| 12 | **Radar capability fields on base dataclass** — `tile_url_template`, `wms_endpoint_url`, `wms_layer_name`, `tile_content_type`, `iframe_url` as optional fields. Not a subclass. | `providers/_common/capability.py` | PROVIDER §7 |
| 13 | **Iframe radar `make_capability()` factory** — iframe provider uses a factory (not static `CAPABILITY`) because `iframe_url` is operator-configured. | `__main__.py` L455-456 | PROVIDER §7 |
| 14 | **Seeing provider wired outside dispatch registry** — direct import, not `get_provider_module()`. | `__main__.py` L462-465 | PROVIDER §6 |
| 15 | **Settings model: hand-rolled classes** (not Pydantic), parsed from ConfigObj. Each INI section → settings class. Secret-leak guard regex `_(KEY|SECRET|TOKEN|PASSWORD)$` at load time. | `config/settings.py` | OPS §4 |
| 16 | **Dual-stack IPv4/IPv6 bind** — `_resolve_bind_addresses()` via `socket.getaddrinfo()`, multiple uvicorn Server instances per resolved address. | `__main__.py` L188-208 | OPS §3 |

### Dashboard Patterns (code-only, not in ADRs)

| # | Pattern | Location | Manual target |
|---|---------|----------|--------------|
| 17 | **useApiQuery implementation details** — `hasDataRef` for stale-while-revalidate, `fetcherRef` pattern, AbortController cleanup, `refetchCounter` for manual refetch, `deps` spread. | `hooks/useApiQuery.ts` | DASHBOARD §7 |
| 18 | **useSSE named event "loop"** — MUST use `addEventListener("loop", ...)`, NOT `onmessage`. Browser auto-reconnects; skipped in mock mode. Three statuses. | `hooks/useSSE.ts` | DASHBOARD §7 |
| 19 | **useRealtimeObservation merge pattern** — REST baseline + SSE overlay shallow merge. WEEWX_TO_OBSERVATION explicit field map. dateTime→timestamp conversion. comfortIndex/windDirCardinal as special-case plain strings. `extras` NOT updated from SSE. Scene from REST only. `isConvertedValue()` type guard. | `hooks/useRealtimeObservation.ts` | DASHBOARD §7 |
| 20 | **API client: native fetch only** — no axios/ky/TanStack. `fetchApi<T>` generic. `getBranding()` from `/branding.json` static file. ApiError with ProblemDetail. | `api/client.ts` | DASHBOARD §7 |
| 21 | **9 almanac sub-endpoints not in ARCHITECTURE.md** — `/planets`, `/moon-names`, `/eclipses/lunar`, `/eclipses/solar`, `/meteor-showers`, `/positions` plus `/earthquakes/config`, `/earthquakes/faults`. | `api/client.ts` L343-397 | ARCHITECTURE.md update needed |

### Stack Patterns (code-only, not in ADRs)

| # | Pattern | Location | Manual target |
|---|---------|----------|--------------|
| 22 | **Wizard has 14+ steps** (not 7-8 as ARCHITECTURE.md states) — api, tls, eula, db, schema, station, units, providers, appearance, feature_settings, privacy_legal, import, review, complete. | `templates/wizard/step_*.html` | OPS §4 |
| 23 | **CLI wizard mode exists** — `cli_wizard.py` alongside the web wizard. | `weewx_clearskies_config/cli_wizard.py` | OPS §4 |
| 24 | **AQI regional config in wizard** — `step_aqi_regional_fields.html` template for per-provider AQI scale selection. | `templates/wizard/` | PROVIDER §5 |

### ARCHITECTURE.md gaps found during audit

These endpoints exist in code (confirmed via `api/client.ts` typed functions) but are NOT in ARCHITECTURE.md's endpoint tables:

- `GET /api/v1/status` — configured state check
- `GET /api/v1/earthquakes/config` — provider configuration
- `GET /api/v1/earthquakes/faults` — GEM fault GeoJSON
- `GET /api/v1/almanac/planets` — planet visibility
- `GET /api/v1/almanac/moon-names` — monthly moon names
- `GET /api/v1/almanac/eclipses/lunar` — lunar eclipses
- `GET /api/v1/almanac/eclipses/solar` — solar eclipses
- `GET /api/v1/almanac/meteor-showers` — meteor showers
- `GET /api/v1/almanac/positions` — celestial positions

These must be added to ARCHITECTURE.md AND captured in the API manual.

---

## 1. Deliverables

### Four new manuals

| # | Manual | Primary consumer | ADRs absorbed | Estimated length |
|---|--------|-----------------|---------------|-----------------|
| 1 | `docs/manuals/API-MANUAL.md` | `clearskies-api-dev` agent | 12 ADRs | ~800-1200 lines |
| 2 | `docs/manuals/PROVIDER-MANUAL.md` | `clearskies-api-dev` agent | 14 ADRs | ~600-900 lines |
| 3 | `docs/manuals/OPERATIONS-MANUAL.md` | ops work, `clearskies-auditor`, config UI dev | 13 ADRs + security-baseline.md | ~700-1000 lines |
| 4 | `docs/manuals/DASHBOARD-MANUAL.md` | `clearskies-dashboard-dev` agent | 7 ADRs | ~400-600 lines |

### Supporting changes

- Archive 41 ADRs from `docs/decisions/` to `docs/archive/decisions/`
- Update `docs/decisions/INDEX.md` with archived entries
- Update `CLAUDE.md` domain routing table
- Update `docs/ARCHITECTURE.md` "Authoritative ADRs by component" section
- Update `rules/clearskies-process.md` with new manual lifecycle
- Archive `docs/contracts/security-baseline.md` (absorbed into OPERATIONS-MANUAL)

### ADR-to-manual mapping (complete)

**API-MANUAL.md (12 ADRs):**
- ADR-010: Canonical data model → §2 Data Model
- ADR-012: Database access pattern → §3 Database Access
- ADR-018: API versioning policy → §4 Versioning
- ADR-035: Column mapping → §5 Column Mapping
- ADR-041: Unit conversion authority → §6 Unit System
- ADR-042: Unit system → §6 Unit System
- ADR-043: skin.conf compliance → §7 skin.conf Compliance
- ADR-044: Sky condition classification → §8 Conditions Text Engine
- ADR-054: Configurable charts (API side) → §9 Charts System
- ADR-056: API co-location → §10 weewx Integration
- ADR-057: API = weewx application layer → §1 Purpose & Principles
- ADR-058: Fold realtime into API → §11 SSE & Realtime

**PROVIDER-MANUAL.md (14 ADRs):**
- ADR-006: Compliance model → §2 Compliance
- ADR-007: Forecast providers → §4 Forecast
- ADR-013: AQI handling → §5 Air Quality
- ADR-014: Almanac data source → §6 Almanac
- ADR-015: Radar/map tiles → §7 Radar
- ADR-016: Severe weather alerts → §8 Alerts
- ADR-017: Provider caching → §3 Caching
- ADR-038: Provider module organization → §1 Module Contract
- ADR-040: Earthquake providers → §9 Earthquakes
- ADR-045: Background cache warming → §3 Caching
- ADR-046: GEM active faults → §9 Earthquakes
- ADR-052: Alert severity model → §8 Alerts
- ADR-053: Almanac visibility rankings → §6 Almanac
- ADR-059: Multi-jurisdiction AQI → §5 Air Quality

**OPERATIONS-MANUAL.md (13 ADRs + security baseline):**
- ADR-008: Auth model → §2 Authentication
- ADR-027: Config format & wizard → §4 Configuration
- ADR-028: Update mechanism → §8 Updates
- ADR-029: Logging → §5 Logging
- ADR-030: Health checks → §6 Health & Readiness
- ADR-031: Observability → §7 Observability
- ADR-033: Performance budget (API targets) → §9 Performance Budget
- ADR-034: Deployment topology → §1 Deployment
- ADR-037: Inbound traffic → §3 Network Architecture
- ADR-038a: Wizard-API channel → §4 Configuration
- ADR-039: Distribution/installation → §1 Deployment
- ADR-060: Security model → §10 Security Model
- ADR-061: Filesystem permissions → §11 Filesystem Permissions
- contracts/security-baseline.md → §10 Security Model (absorbed)

**DASHBOARD-MANUAL.md (7 ADRs):**
- ADR-020: Time zone handling → §2 Time Zones
- ADR-021: i18n strategy → §3 Internationalization
- ADR-024: Page taxonomy (non-UI parts) → §1 Pages & Routes
- ADR-025: Browser support → §4 Browser Support
- ADR-033: Performance budget (dashboard targets) → §5 Performance Budget
- ADR-054: Charts (dashboard side) → §6 Charts System
- ADR-055: Client data refresh → §7 Data Refresh

**Archive to ARCHITECTURE.md (7 meta ADRs):**
- ADR-001: Component breakdown
- ADR-002: Tech stack
- ADR-003: License = GPL v3
- ADR-004: Repo naming
- ADR-011: Multi-station scope
- ADR-032: Versioning across repos
- ADR-036: Workspace layout

**Already superseded (archive immediately, 2 ADRs):**
- ADR-005: Superseded by ADR-058
- ADR-019: Superseded by ADR-041/042

---

## 2. Document Structures

### 2A. API-MANUAL.md — Section Specifications

**Authority statement (header):** This document is the single authority for all Clear Skies API implementation rules. Consumers: API dev agents and human reviewers. When this document conflicts with any other source, this document wins.

**§1 Purpose & Principles**
- The API is the weewx application layer (ADR-057 framing). Not just "dashboard backend" — the canonical programmatic interface to weewx station data.
- Computation boundary: API does data access + unit conversion + enrichment. Dashboard does rendering + presentation-level computation (binning, downsampling, chart layout). If an endpoint requires domain-specific computation (Beaufort, comfort index), it belongs in the enrichment pipeline, not as a raw data endpoint.
- General-purpose data access — no chart-specific or visualization-specific endpoints.
- **Setup mode (from code audit #1):** When `settings.configured=False`, the API starts with only setup endpoints + a catch-all 503 returning RFC 9457 `urn:clearskies:not-configured`. No DB, no providers, no data routers. The `/api/v1/status` endpoint works in both modes, returning `{configured: bool}`.
- **Startup sequence (from code audit #4):** Document the 20+ step sequence with explicit fatal vs non-fatal handling: settings → logging → TLS → trust manager → engine → write probe → schema reflection → weewx.conf → units → station metadata → ephemeris → reports → content → hidden pages → cache → cache warmer → DB metrics → provider registry → per-domain settings → health probe → SSE infrastructure → UnitTransformer → enrichment registration → endpoint enrichment → serve.

**§2 Data Model (ADR-010)**
- Naming: weewx-aligned camelCase, identical in Python and JSON. No alias mechanism.
- Entity types: 9 core + 2 containers (Observation, ArchiveRecord, HourlyForecastPoint, DailyForecastPoint, ForecastDiscussion, AlertRecord, EarthquakeRecord, AQIReading, StationMetadata + ForecastBundle, AlertList).
- Response shapes: observation endpoints return ConvertedValue dicts `{value, label, formatted}`. Archive endpoints return flat scalars (except `beaufort`). Both carry `units` envelope.
- Units: read `usUnits` at source, convert to operator display unit. Every response carries a `units` metadata block.
- Time: UTC ISO-8601 with `Z` suffix everywhere. No local-time strings in API responses.
- Nullability: all fields `Optional[T]`, key always present, `null` for missing.
- Provenance: every record carries `source: str`.
- Custom columns: non-core in `extras: dict`. `/archive` serves ALL columns (no whitelist gate).
- Prose: three layers (weatherText, narrative, ForecastDiscussion).
- Pydantic config: `extra="forbid"`, `exclude_none=False`, camelCase fields (ruff N815 suppressed).

**§3 Database Access (ADR-012)**
- Driver: SQLAlchemy 2.x, parameterized queries.
- Backends: SQLite (default) and MariaDB. No per-driver code paths.
- Read-only enforcement: DB-level SELECT-only grants + startup write probe. Service refuses to start if writes succeed.
- SQLite: `?mode=ro&uri=true` + filesystem permissions.
- Schema introspection at startup: `MetaData.reflect()` on archive table → column registry.
- Connection lifecycle: per-request session via FastAPI dependency injection.
- Custom columns: endpoints select from operator mapping, not hardcoded list.

**§4 Versioning (ADR-018)**
- URL path versioning: `/api/v1/...`.
- Major bump only on breaking changes (removes endpoint/field, changes type/nullability, renames, tightens validation, changes default).
- Non-breaking changes ship within current major (adds endpoint/field, loosens validation).
- No support-window promise (GPL v3 AS-IS).
- Error format: RFC 9457 `application/problem+json` across all versions.
- OpenAPI auto-generated by FastAPI at `/api/v1/docs`, `/api/v1/redoc`, `/api/v1/openapi.json`.

**§5 Column Mapping (ADR-035)**
- Stock columns auto-map via built-in lookup table. Non-stock presented to operator.
- Mapping persists in config file. Re-mapping without restart.
- Auto-advance when all stock (skip mapping table).
- Battery/diagnostic columns excluded from suggestions.
- Validation: duplicate canonical mappings flagged inline.
- weewx metadata import: `obs_group_dict` via `import weewx.units` (ADR-056) for unit group auto-detection.

**§6 Unit System (ADR-041, ADR-042)**
- Full weewx compatibility: 14 unit groups, all valid units.
- API is the single conversion authority. Dashboard has zero unit knowledge.
- **Target unit system inference (from code audit #8):** API derives US/METRIC/METRICWX from api.conf `[units][[groups]]` by checking `group_temperature` (degree_F → US, degree_C → check group_rain: mm → METRICWX, else METRIC).
- **Column unit validation at startup (from code audit #7):** `_validate_column_units()` cross-checks operator-confirmed units against weewx metadata. Mismatches produce warnings, not fatal errors — the confirmed unit wins.
- REST path: archive values with `usUnits` → lookup field group → convert to display unit → attach label and formatted string.
- SSE path: loop packets via socket reader → identify source unit → convert → attach label.
- Output format: `{value, label, formatted}`.
- Additional config: `[[string_formats]]`, `[[labels]]`, `[[ordinates]]`, `[[trend]]` in `api.conf [units]`.
- Derived values: Beaufort (API computes, dashboard reads), comfort index selector (`comfortIndex` string), barometer trend direction, cardinal wind directions.
- Conversion factors: must exactly match weewx's own values from `weewx/units.py`.
- File layout: `weewx_clearskies_api/units/{groups,conversion,labels,transformer,derived}.py`.

**§7 skin.conf Compliance (ADR-043)**
- Section-by-section disposition table: KEEP/REPLACE/IGNORE for each skin.conf section.
- Wizard import flow: "Start fresh" or "Import from existing skin."
- Image import resolution order: local filesystem → API endpoint → amber warning.
- Generated skin.conf at `/etc/weewx/skins/ClearSkies/skin.conf` on wizard apply.

**§8 Conditions Text Engine (ADR-044)**
- Multi-module stateful engine producing `weatherText` on `/current`.
- Sky condition: kc + σ(kc) 2D classification over 30-min sliding window (primary: pyranometer daytime; fallback: provider cloud cover night/startup).
- Thresholds: σ threshold 0.08, hysteresis ±0.03. Low/high sigma tables with 5 and 3 tiers respectively.
- Precipitation: rain gauge primary, Beaufort/WMO thresholds. Frozen precip: Stull wet-bulb filter.
- Wind: Beaufort scale 0-12. Gusty qualifier: gust ≥ speed + 12 mph AND gust ≥ 18 mph.
- Temperature-comfort: 2D matrix (12 appTemp tiers × 7 dewpoint tiers). NWS danger escalations.
- Day/night vocabulary: "Sunny"/"Mostly Sunny" day, "Clear"/"Mostly Clear" night.
- Input stability: smoothing windows (2-30 min per input), hysteresis bands (±2°F/±2mph/±0.02in/hr), 5-min hold time.
- Composition: `[temp-comfort, sky, wind, precip]`, "with" connector for last element.
- Startup: ~3 min warmup (36 samples), fallback to provider during warmup.
- Transport: REST only. `weatherText` NOT in SSE field map.
- **Enrichment processor registration order (from code audit #5):** `input_smoother → uv_smoother → sky_tap → wind_rolling_window → lightning_strike_buffer → scene_packet_tap`. Order matters — smoother must run before classifiers.
- **Endpoint enrichment registration (from code audit #6):** 7 enrichments on 2 endpoint keys: `"current"` gets barometer_trend, wind_rolling_average, lightning_history, weather_text, uv, scene. `"almanac/planets"` gets planet_viewing.

**§9 Charts System — API Side (ADR-054)**
- `charts.conf`: ConfigObj/INI, 3-level nesting (group → chart → series).
- Parsed at startup by `services/charts_config.py`.
- Self-hide pruning: series not in `ColumnRegistry` removed; empty charts/groups cascade-removed.
- Endpoints: `GET /api/v1/charts/config`, `GET /api/v1/charts/custom-query/{series_id}`.
- Custom SQL security: disk-only source, EXPLAIN pre-validation, read-only transaction, 10s timeout, DDL blocklist.
- `aggregate_interval` and `agg_map` parameters on `/archive`.
- `sumcumulative` aggregate type: SUM per bucket then running total.
- `/archive/grouped` for `xAxis_groupby` charts. No `/climatology/*` endpoint.
- All archive columns served — no whitelist gate.
- Archive conversion: `transform_record()` applied, beaufort injected, values flattened to scalars (except beaufort → ConvertedValue dict).

**§10 weewx Integration (ADR-056)**
- API co-located with weewx. Deployment constraint.
- `import weewx.units` for `obs_group_dict` — authoritative unit group auto-detection.
- Graceful degradation: if import fails, warning + no auto-detection. API still serves data.
- Path resolution: auto-detect → store in config. Override: `[weewx] python_path`.
- Security boundary: only `weewx.units` imported. Never `weewx.engine`, `weewx.drivers`, `weewx.manager`.

**§11 SSE & Realtime (ADR-058)**
- SSE at `GET /sse` on port 8765. Event format: `{"event": "loop", "data": "..."}`.
- Direct mode only: Unix socket at `/var/run/weewx-clearskies/loop.sock` from `ClearSkiesLoopRelay`. MQTT eliminated.
- 15-second keepalive comments. 64-packet overflow buffer.
- 12 enrichment processors merged from former realtime service.
- Module-level state (ring buffers, sky classifier, scene descriptor) — single-process preserves this.
- Caddy routes both `/api/v1/*` and `/sse` to API port 8765.

**§12 Anti-Patterns**
- Never create chart-specific API endpoints — API is general-purpose data access.
- Never duplicate Beaufort/comfort-index/unit thresholds in dashboard code.
- Never hardcode weewx column names — use column registry from schema reflection.
- Never serve local-time strings in API responses — UTC with `Z` only.
- Never write to the weewx database — read-only by architecture.
- Never import `weewx.engine`, `weewx.drivers`, or `weewx.manager`.
- Never accept custom SQL from HTTP — config-file-only trust model.
- Never return a response without the `units` metadata block.

---

### 2B. PROVIDER-MANUAL.md — Section Specifications

**Authority statement (header):** Single authority for building and modifying provider modules in the Clear Skies API. ADRs explain why; this manual says what to do.

**§1 Module Contract (ADR-038)**
- One module per provider. One module = one domain.
- Five responsibilities: outbound call, response parsing, canonical translation, capability declaration, error handling.
- Shared infrastructure in `providers/_common/`: HTTP client, retry/backoff, error taxonomy, capability registry, rate limiter.
- Per-module: provider URL/auth/parsing, translation, own rate limiter, domain-specific helpers.
- Module file layout: `providers/{forecast,aqi,alerts,earthquakes,radar,seeing}/`.
- Capability declaration fields: `provider_id`, `domain`, `supplied_canonical_fields`, `geographic_coverage`, `auth_required`, `default_poll_interval_seconds`, `operator_notes`.
- Internal contract only — no third-party plugin ecosystem. Outside contributors PR into bundled set.
- Provider versioning: stay within existing module unless version-branching dominates.
- **Dispatch registry (from code audit #9):** `PROVIDER_MODULES` in `dispatch.py` is an explicit `dict[(domain, provider_id) → ModuleType]`. Adding a provider = import the module + add one dict row. No entry-points, no runtime loading.
- **ProviderHTTPClient (from code audit #10):** Each provider instantiates ONE `ProviderHTTPClient` at module-load time (not per-request). Retry: max 2 retries (3 total attempts), base 0.5s, factor 2.0, cap 5.0s, ±25% jitter. `follow_redirects=False` by default to prevent token leak via accidental 30x redirect.
- **Iframe provider exception (from code audit #13):** Uses a `make_capability()` factory instead of static `CAPABILITY` because the `iframe_url` is operator-configured.
- **Seeing provider exception (from code audit #14):** Wired via direct import, not through the dispatch registry.

**§2 Compliance (ADR-006)**
- End users register and manage their own keys. Project ships code only.
- No bundled keys. No proxied calls through project-run service.
- Per-provider docs: ToS link, free-tier limits, signup process, commercial-use restrictions.
- Missing key disables that provider only — rest of service starts normally.
- No telemetry that could leak usage patterns.

**§3 Caching (ADR-017, ADR-045)**
- Pluggable backend: `memory` (default, single worker) or `redis` (multi-worker).
- Per-provider TTLs: forecast 30 min, alerts 5 min, AQI 15 min, radar metadata 5 min, seeing forecast 3 hours.
- Redis config: `CLEARSKIES_CACHE_URL=redis://localhost:6379/0` in `secrets.env`.
- Background cache warming (ADR-045, Proposed): daemon thread pre-computes slow endpoints on configurable intervals. Reuses CacheBackend.

**§4 Forecast Providers (ADR-007)**
- Day-1 set: Aeris, NWS, OpenMeteo, OpenWeatherMap, Weather Underground.
- Each independently enable/disable. Missing keys disable that provider's pieces only.
- Geographic/feature limitations are per-provider (NWS USA-only, OpenMeteo no alerts, Wunderground no hourly/no alerts + PWS-gated).
- Hidden data types: no on-dashboard "no provider configured" message — just absence.
- Normalizer contract: `normalize_current()`, `normalize_hourly()`, `normalize_daily()`, `normalize_discussion()`, `normalize_alerts()`.

**§5 Air Quality (ADR-013, ADR-059)**
- Two operator paths: own weewx extension (archive columns via ADR-035 mapping) OR API provider module.
- Day-1 providers: Aeris, OpenMeteo, OpenWeatherMap, IQAir.
- Multi-jurisdiction: pass through provider-native AQI scales (not EPA-only).
- `aqiScale` carries provider's actual scale identifier. `aqiCategory` passes through.
- NO and NH3 pollutants: NOT dropped. `pollutantNO`, `pollutantNH3` fields added.
- Provider-specific regional config: Aeris `aqi_filter`, OpenMeteo `aqi_index`, IQAir `aqi_scale`.
- Dashboard renders per `aqiScale`. Category names and colors from provider response.

**§6 Almanac (ADR-014, ADR-053)**
- Data source: Skyfield (Python, server-side, NASA JPL ephemerides).
- Endpoints: `/almanac` (snapshot), `/almanac/sun-times` (year series), `/almanac/moon-phases` (grid), `/almanac/seeing-forecast`.
- Visibility ranking: unified 5-tier color scale (green/lime/yellow/orange/red) for solar eclipses (obscuration), lunar eclipses (altitude), meteor showers (radiant+moon), planet viewing (7Timer seeing).
- Data provenance: AstronomyAPI.com, Skyfield, 7Timer, IMO/AMS.

**§7 Radar (ADR-015)**
- Leaflet + OSM base + 8 day-1 provider modules + iframe fallback.
- Keyed providers proxied server-side (keys never reach browser).
- Provider modules: rainviewer, openweathermap, aeris, iem_nexrad, noaa_mrms, msc_geomet, dwd_radolan, iframe.
- Capability declaration adds `tile_format` field for radar domain.
- Endpoints: `/radar/providers/{id}/frames`, `/radar/providers/{id}/tiles/{z}/{x}/{y}`.

**§8 Alerts (ADR-016, ADR-052)**
- Day-1 providers: NWS, Aeris, OpenWeatherMap. Single source per deploy.
- Geography-correct severity model: `severityLevel` (1-4 int) + `severityLabel` (native system name). Old `advisory|watch|warning` enum removed.
- Severity level mapping table: 10 national systems mapped to 4 tiers.
- Additional fields: `alertSystem`, `hazardType`, `nativeName`, `color`.
- Two rendering modes: Rich (Aeris, NWS) vs OWM default (level 2, "Alert").
- NWS provider fix: map from event name tier, not CAP severity.
- Aeris: capture `dataSource`, `localLanguages`, `details.color`, `details.cat`.

**§9 Earthquakes (ADR-040, ADR-046)**
- Day-1 providers: USGS (global fallback), GeoNet (NZ/Pacific), EMSC (Europe), RENASS (France).
- Single source per deploy. Wizard suggests by region.
- GEM Global Active Faults overlay: CC-BY-SA 4.0, bundled GeoJSON, radius-clipped serving.
- `EarthquakeRecord` fields: id, time, lat, lon, magnitude, source + optional depth, magnitudeType, place, url, tsunami, felt, mmi, alert, status, extras.

**§10 Error Taxonomy**
- Canonical errors: `QuotaExhausted`, `KeyInvalid`, `GeographicallyUnsupported`, `FieldUnsupported`, `TransientNetworkError`, `ProviderProtocolError`.
- No leaking upstream provider error types.
- **Error → HTTP status mapping (from code audit #11):** QuotaExhausted → 503 + Retry-After header. GeographicallyUnsupported → 503. KeyInvalid → 502. FieldUnsupported → 502. TransientNetworkError → 502. ProviderProtocolError → 502 (logged at ERROR for triage).
- **Base class carries** `provider_id`, `domain`, `retry_after_seconds`, `status_code` (for HTTP-boundary dispatch).

**§11 Testing Pattern**
- Recorded fixture per provider under `tests/fixtures/providers/{provider}/`.
- Parser unit tests: load fixture, assert canonical translation.
- Mock-network tests: `respx` or equivalent, verify auth/rate-limit/error mapping.
- NO live-network tests in CI.

**§12 Anti-Patterns**
- Never bundle API keys or proxy through a project service.
- Never leak upstream provider error types — use canonical taxonomy.
- Never run live-network tests in CI.
- Never hardcode domain-specific helpers (EPA AQI lookup, Beaufort scale) in provider modules — they belong in the canonical model package.
- Never add a provider module that covers multiple domains — one module = one domain.

---

### 2C. OPERATIONS-MANUAL.md — Section Specifications

**Authority statement (header):** Single authority for deployment, security, auth, monitoring, configuration, and installation rules. Absorbs and replaces `contracts/security-baseline.md`.

**§1 Deployment (ADR-034, ADR-039)**
- Two-host default: API on weewx host, dashboard + Caddy on front-end host.
- Single-host alternative: all services on one machine.
- Per-repo container images: independent builds.
- Container inventory table (from ARCHITECTURE.md).
- Two install paths: container (docker-compose + Caddy) or native (pip + systemd + operator web server).
- Distribution channels: PyPI, container registry, GitHub Releases.
- Linux native or Docker. macOS native or Docker. Windows = Docker Desktop.

**§2 Authentication (ADR-008)**
- No end-user auth. Public weather site model (consistent with weewx skin ecosystem).
- Cross-host: shared secret in `X-Clearskies-Proxy-Auth` header. Constant-time HMAC compare.
- Same-host: no secret needed (loopback = trust boundary).
- Non-loopback without secret: starts but logs loud warning every 60s.
- Secret generated by wizard, stored in env vars. Power users: `openssl rand -hex 32`.
- Future privileged surfaces (config UI) define own auth separately.

**§3 Network Architecture (ADR-037)**
- One-door reverse proxy mandatory. All public traffic through single web server.
- Inner services bind to `127.0.0.1` by default. Never publicly exposed.
- External provider calls originate from API, not browser. Keys never in JS bundle.
- Port registry (from ARCHITECTURE.md).
- Caddy routing table (from ARCHITECTURE.md).
- Security headers on all responses.
- SSE: correct buffering/timeout config for long-lived connections.

**§4 Configuration (ADR-027, ADR-038a)**
- Config format: ConfigObj `.conf` files (matching weewx convention).
- **Settings model (from code audit #15):** Hand-rolled Python classes (not Pydantic), parsed from ConfigObj. Each INI section maps to a settings class (ApiSettings, HealthSettings, DatabaseSettings, etc.). Env vars for secrets only — INI sections for everything else.
- Config directory: `/etc/weewx-clearskies/` (search order: env var → /etc → ~/.config).
- File inventory: api.conf, charts.conf, stack.conf, secrets.env, branding.json, webcam.json, TLS certs.
- Secret naming: `WEEWX_CLEARSKIES_<DOMAIN>_<FIELD>`.
- Secret-leak guard: API scans `.conf` at startup; key matching `_(KEY|SECRET|TOKEN|PASSWORD)$` is fatal.
- Wizard-API channel: TLS always, Ed25519 self-signed default, trust token + fingerprint handshake.
- Setup endpoints: `/setup/*` (no `/api/v1` prefix), trust token or session auth.
- Config UI: standalone FastAPI app on port 9876. Pip-installable.
- Wizard: step inventory is defined by the code in `wizard/routes.py` and `templates/wizard/step_*.html` — do not hardcode a step count in the manual. Document the step *pattern* (HTML structure, HTMX fragment swap, form field contract, progress bar) not the step *list*.
- **CLI wizard (from code audit #23):** `cli_wizard.py` provides a headless/SSH-only wizard alongside the web wizard. Document its existence and relationship to the web wizard.

**§5 Logging (ADR-029)**
- Format: JSON one-line-per-record to stdout.
- Library: stdlib `logging` with filter.
- Capture: journalctl (native) or docker logs (container).
- Redaction filter: strips auth headers, API keys, SQL params.
- No stack traces or internal paths in error responses.

**§6 Health & Readiness (ADR-030)**
- Separate loopback port 8081: `/health/live`, `/health/ready`, `/metrics`.
- Liveness: always 200 if process alive.
- Readiness: 200 ok/degraded, 503 unhealthy. Includes provider connectivity, DB connectivity.
- Unauthenticated (loopback-only).
- Main port (8765): `GET /health` returns `{"status": "ok"}`.

**§7 Observability (ADR-031)**
- Logs by default (always available, zero config).
- Prometheus `/metrics` opt-in via `CLEARSKIES_METRICS_ENABLED=true` on health port.
- OTel deferred to future phase.
- Middleware stack: MetricsMiddleware → RequestIdMiddleware → BodySizeLimitMiddleware → ProxyAuthMiddleware → RateLimitMiddleware → CORSMiddleware → SecurityHeadersMiddleware.

**§8 Updates (ADR-028)**
- Same channel as install: `pip install -U` (native), `docker compose pull` (Docker).
- No in-app self-update at v0.1.
- CHANGELOG.md is the upgrade guidance source.
- No LTS, no support windows (GPL v3 AS-IS).
- Config preservation: `/etc/weewx-clearskies/` outside package (pip) or bind-mounted (Docker).
- Schema drift: always CHANGELOG-flagged.

**§9 Performance Budget (ADR-033 — API targets)**
- p95 API latency targets (from ADR-033).
- Targets-not-gates: missed targets are bugs to investigate, not release-blockers.

**§10 Security Model (ADR-060 + security-baseline.md)**
- Threat model: API is a gateway to data, not a door into the host.
- Trust boundary diagram (from ADR-060).
- Per-component security controls (Caddy, API, Config UI, Dashboard).
- Rate limiting: 60/min per IP, bypass when proxy-trusted.
- Input validation: Pydantic `extra="forbid"` with `Depends()`.
- Body size limit: 1 MiB.
- Read-only DB: parameterized queries + startup write probe.
- TLS: mandatory on API, Ed25519 self-signed default.
- SSE security: connection limits per IP, backpressure, idle timeout.
- Systemd hardening flags (mandatory for production).
- Dedicated service user (not `ubuntu` or `www-data`).

**§11 Filesystem Permissions (ADR-061)**
- Runtime process model table: who runs what (clearskies, caddy, redis, weewx users).
- `ubuntu` at runtime: NO. Deploy-time only.
- Complete filesystem permissions table: config dir, web root, runtime dirs, Caddy files.
- Per-file owner, mode, read-by, written-by with rationale.
- `secrets.env` mode 0600 — most restricted file.
- Unix socket: `/var/run/weewx-clearskies/loop.sock`, weewx:weewx 0660.

**§12 Anti-Patterns**
- Never expose API directly to the internet — always behind reverse proxy.
- Never run services as `ubuntu` or any sudo-capable user.
- Never store secrets in `.conf` files — `secrets.env` only.
- Never skip the startup write probe on the database.
- Never bind to non-loopback without the proxy shared secret.
- Never use `--no-verify` or bypass TLS verification in production.
- Never place `branding.json` or `webcam.json` in the web root (rsync --delete would destroy them).

---

### 2D. DASHBOARD-MANUAL.md — Section Specifications

**Authority statement (header):** Single authority for Clear Skies dashboard technical behavior rules. Companion to DESIGN-MANUAL.md (visual design). When this document conflicts with any other source, this document wins.

**§1 Pages & Routes (ADR-024 — non-UI parts)**
- 9 built-in pages + custom page mechanism. Route table.
- Per-page default content inventory (Now, Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal).
- Custom pages: appear after Reports, before About. Operator picks slug + name + icon + position + content blocks.
- Self-hide behavior: card hides when all backing data null; page hides when all cards hide; Now never hides.
- Configured-but-no-data: card stays visible with graceful empty state ("—" values). Do not hide for transient data absence.
- React Router v7, all pages lazy-loaded.
- API client: relative `/api/v1` by default. Override: `VITE_API_BASE_URL`. SSE: `VITE_SSE_URL` or `/sse`.
- Global error boundary wraps entire app tree.

**§2 Time Zones (ADR-020)**
- Wire format: UTC ISO-8601 with `Z` suffix. No local-time strings from API.
- Display: station-local by default (not visitor browser-local). Station TZ from `StationMetadata` as IANA identifier.
- TZ source priority: operator config → weewx config → OS timezone → UTC + WARN.
- Browser-side: `Intl.DateTimeFormat` with station TZ + active locale. No JS date library required.
- Never call `toLocaleString()` without explicit `timeZone` option.
- No per-user TZ override at v0.1.

**§3 Internationalization (ADR-021)**
- 13 locales for v0.1: en, de, es, fil, fr, it, ja, nl, pt-PT, pt-BR, ru, zh-CN, zh-TW.
- Framework: react-i18next.
- No RTL languages in v0.1. Write LTR-neutral CSS (`margin-inline-start` over `margin-left`).
- `<html lang="...">` set per active locale.
- CJK fallback: system CJK fonts. No Noto-CJK bundle shipped.

**§4 Browser Support (ADR-025)**
- Modern evergreen, last 2 years. iOS Safari 16.4+.
- Browserslist: `>0.5%, last 2 years, not dead, not op_mini all`.
- ES2022 baseline. No IE, no Opera Mini, no `<2%` niche.
- No-JS rendering / progressive enhancement: out of scope.

**§5 Performance Budget (ADR-033 — dashboard targets)**
- Lighthouse: ≥ 90 (all four categories).
- Core Web Vitals: "Good" thresholds (LCP ≤ 2.5s, FID ≤ 100ms, CLS ≤ 0.1).
- Bundle size: ≤ 200KB gzipped (initial load).
- Targets-not-gates: missed targets are bugs to investigate.

**§6 Charts System — Dashboard Side (ADR-054)**
- `ConfigDrivenGroup` + `ConfigDrivenChart` render from `GET /api/v1/charts/config`.
- Recharts for standard time-series. Custom SVG for wind rose.
- Proportional scaling: `aggregate_interval = base_interval × max(1, range / base_time)`.
- Per-field aggregation: read `aggregate_type` from chart config, pass as `agg_map`.
- Special series auto-detection: `windRose`, `weatherRange`, `haysChart` trigger component switching.
- Wind rose: separate raw archive fetch (no `aggregate_interval`) for correct Beaufort classification. Reads `beaufort.value` from API-injected field. Dashboard does NOT compute Beaufort.
- Weather range: dual archive fetch (`agg=min` + `agg=max`), `aggregate_interval=86400`. Default Cartesian, polar only when `polar=true`. 15-band temperature color zones.
- Hays chart: always polar, 24-hour wind chart.
- LTTB downsampling for large datasets.
- Export: PNG + CSV per chart.
- `xAxis_groupby` charts: use `/archive/grouped` instead of `/archive`.

**§7 Data Refresh & Realtime (ADR-055 + code audit findings)**
- Stale-while-revalidate is the default. `useApiQuery` distinguishes initial load (skeleton) from background refetch (stale data stays).
- `loading=true` only when data has never been populated.
- `refreshing=true` during any in-flight request.
- Refetch error: stale data stays; no blanking.
- Theme initialization: gated on `sceneLoaded=true`. No dark-flash-then-correct sequence.
- Wall-display use case: no 60-second blanking cycle.
- **useApiQuery implementation (from code audit #17):** `hasDataRef` (useRef) tracks first-data state. `fetcherRef` pattern avoids stale closures. AbortController cleanup on unmount. `refetchCounter` for manual refetch. `deps` spread into useEffect dependency array.
- **useSSE hook (from code audit #18):** Named event type `"loop"` — MUST use `addEventListener("loop", ...)`, NOT `onmessage`. Browser EventSource auto-reconnects (no manual retry). Skipped in mock mode. Three statuses: connecting, connected, disconnected.
- **useRealtimeObservation merge (from code audit #19):** REST baseline + SSE overlay via shallow merge. Explicit `WEEWX_TO_OBSERVATION` field map. `dateTime` (epoch int) → `timestamp` (ISO string) conversion. `comfortIndex`, `windDirCardinal`, `windGustDirCardinal` handled as special-case plain strings (not ConvertedValue). `extras` NOT updated from SSE — stays at REST baseline. Scene from REST only (changes on minute timescale, not packet timescale). `isConvertedValue()` type guard distinguishes BFF-converted fields from raw values.
- **API client (from code audit #20):** Native fetch only — no axios, ky, or TanStack Query. `fetchApi<T>` generic with `application/problem+json` error parsing. `getBranding()` fetches `/branding.json` (static file via Caddy), not `/api/v1/branding`. `SCENE_DEFAULT = { sky: 'clear', daytime: true, overlay: null }`.

**§8 Anti-Patterns**
- Never compute Beaufort, comfort index, or unit conversion in dashboard code — API is the authority.
- Never display local-time strings from the API — use `Intl.DateTimeFormat` with station TZ.
- Never call `toLocaleString()` without explicit `timeZone` option.
- Never show skeletons during background refetches — use stale-while-revalidate.
- Never create chart-type-specific API calls — use general-purpose `/archive` with config-driven params.
- Never hardcode unit strings — render `label` from API ConvertedValue.
- Never gate theme initialization on default scene data — wait for real API response.

---

## 3. Implementation Phases

### PHASE 0 — Pre-work: Coordinator reads all source material (THIS IS DONE)

The coordinator has read:
- All 44 ADR files (full content for substantive ADRs, summaries for simple ones)
- ARCHITECTURE.md (full)
- DESIGN-MANUAL.md (full, as the template)
- DESIGN-MANUAL-PLAN.md (full, as the plan template)
- INDEX.md (full)
- contracts/security-baseline.md (exists, needs reading before Phase 2C)

**Remaining coordinator reading before execution:**
- `contracts/security-baseline.md` — must read in full before writing OPERATIONS-MANUAL §10
- `contracts/canonical-data-model.md` — must read before writing API-MANUAL §2. This file is the **data field registry** (see §6.2) — a per-field catalog of every field the API returns. It stays as a standalone controlled document; the API-MANUAL covers the rules (naming, nullability, response shapes) and cross-references the contract for the field inventory.
- ADR-013, ADR-014, ADR-015, ADR-016, ADR-017, ADR-027, ADR-029, ADR-030, ADR-031, ADR-033, ADR-040, ADR-045, ADR-046, ADR-053 — read in full (first 30-50 lines read, full content needed for prescriptive rule extraction)

**Why the coordinator must read everything:** The coordinator writes the agent prompts. If the coordinator hasn't read the ADR, the agent prompt will be vague ("consolidate ADR-017 into the caching section") instead of specific ("document the pluggable backend model: `memory` default, `redis` optional; per-provider TTLs: forecast 30 min, alerts 5 min, AQI 15 min, radar 5 min, seeing 3 hours"). Agents assemble and format — they do not research.

---

### PHASE 0B — Resolve Document-Code Disparities

Before any manual can be drafted, the source documents must accurately reflect the code. Otherwise the manuals inherit stale information from day one. This phase corrects the 3 contradictions and fills the documentation gaps found during the code audit.

**T0B.1 — Restructure ARCHITECTURE.md endpoint section to use OpenAPI as registry**
- Owner: Coordinator (Opus)
- Do: Replace the hand-maintained exhaustive endpoint table with:
  1. A **category summary** table (data endpoints, setup endpoints, health endpoints, SSE) describing the purpose of each group, the URL prefix pattern, and which port they live on.
  2. A **link to the OpenAPI spec** (`/api/v1/openapi.json` and Swagger UI at `/api/v1/docs`) as the authoritative endpoint inventory.
  3. A **representative examples** section showing a few key endpoints per category (enough for orientation, not exhaustive).
  4. The setup, health, and SSE endpoints documented explicitly (these are outside the OpenAPI spec and operators need them for deployment config).
  - The current hand-maintained table is the root cause of the 9 missing endpoints. The OpenAPI spec is auto-generated and always complete. ARCHITECTURE.md should leverage it instead of competing with it.
- Accept when: ARCHITECTURE.md references OpenAPI as the endpoint registry, explicitly documents non-OpenAPI surfaces (setup, health, SSE), and no longer maintains an exhaustive data-endpoint table that will drift

**T0B.2 — Fix ARCHITECTURE.md wizard references**
- Owner: Coordinator (Opus)
- Do: Remove hardcoded wizard step counts from ARCHITECTURE.md. The wizard steps morph over time — the docs should NOT pin a count. Instead, reference the code as authoritative: "Wizard steps are defined by the templates in `weewx_clearskies_config/templates/wizard/step_*.html`. See the stack repo for the current step inventory." Update the Config UI route table to be a pattern reference (showing the URL scheme and a few examples) rather than an exhaustive enumeration.
- Accept when: no hardcoded wizard step count in ARCHITECTURE.md; code is cited as the source of truth for step inventory

**T0B.3 — Fix ADR-045 and ADR-046 status**
- Owner: Coordinator (Opus)
- Do: Both ADRs are Accepted (user confirmed) but INDEX.md shows "Proposed" — this is doc drift from a past amendment cycle. Update both ADR-045 (cache warming) and ADR-046 (GEM active faults) status to "Accepted" in both the ADR files and INDEX.md. Both are implemented: cache warmer wired at `__main__.py` step 6h½, GEM faults served via `services/faults.py` + `/earthquakes/faults` endpoint.
- Accept when: INDEX.md shows both as Accepted

**T0B.4 — Fix ARCHITECTURE.md Config UI route table**
- Owner: Coordinator (Opus)
- Do: Replace the exhaustive wizard route table with a pattern reference. Show the URL scheme (`/wizard/step/{N}`, `/wizard/step/{N}/test`, `/wizard/apply`, etc.) and a note that the step inventory is defined by the code in `wizard/routes.py` and `templates/wizard/step_*.html`. Keep the auth and admin route tables (those are stable), but the wizard step list must point to code rather than enumerate steps that will drift.
- Accept when: Config UI section references code for wizard steps, doesn't enumerate a step count that will go stale

**T0B.5 — Document CLI wizard**
- Owner: Coordinator (Opus)
- Do: Read `cli_wizard.py` to understand its scope. Add a note to ARCHITECTURE.md Config UI section acknowledging the CLI wizard's existence, its purpose (headless/SSH-only installs), and its relationship to the web wizard. If it's a stub or incomplete, note that too.
- Accept when: CLI wizard is mentioned in ARCHITECTURE.md with accurate status

**T0B.6 — Verify and document undocumented API behaviors**
- Owner: Coordinator (Opus)
- Do: Read the following code files to confirm the 15 "extends beyond ADRs" patterns from the code audit are accurately described. For each, write a brief note confirming or correcting the audit finding:
  - `__main__.py` — startup sequence, setup mode, enrichment registration order, column unit validation, target unit inference
  - `providers/_common/http.py` — retry parameters, follow_redirects default
  - `providers/_common/dispatch.py` — registry mechanism
  - `providers/_common/capability.py` — radar fields on base dataclass
  - `config/settings.py` — hand-rolled settings model, secret-leak guard
  - `hooks/useRealtimeObservation.ts` — merge pattern details
  - `hooks/useSSE.ts` — named event type
- These confirmations feed directly into the manual content specifications.
- Accept when: each of the 15 patterns has a confirmed/corrected one-line note that the manual author can use as source material

**QC Gate 0B (Coordinator):**
- Verify all ARCHITECTURE.md changes are consistent with the code (not just plausible)
- Verify ADR-045 status change is warranted by reading the actual implementation
- Verify wizard section references code as source of truth for step inventory (no hardcoded counts)
- Verify all 9 missing endpoints now appear in ARCHITECTURE.md with correct method/purpose
- Verify the 15 undocumented-pattern confirmations are backed by actual code reads, not assumptions

---

### PHASE 1 — Draft API-MANUAL.md + PROVIDER-MANUAL.md

These two are the densest manuals and share the API codebase context. Draft them together.

**T1.1 — Draft API-MANUAL.md (§1-§12)**
- Owner: `clearskies-docs-author`
- Inputs: coordinator-provided content specifications (§2A above), ADR source files for cross-reference
- Deliverable: Complete `docs/manuals/API-MANUAL.md`
- Accept when:
  - [ ] All 12 sections present with content matching specifications
  - [ ] Every entity type from ADR-010 appears in §2
  - [ ] Unit system covers all 14 groups from ADR-042
  - [ ] Conditions text thresholds match ADR-044 tables exactly
  - [ ] Charts system covers all special series types
  - [ ] Anti-patterns section has ≥8 entries
  - [ ] Zero hardcoded values — all use token/config references

**T1.2 — Draft PROVIDER-MANUAL.md (§1-§12)**
- Owner: `clearskies-docs-author`
- Inputs: coordinator-provided content specifications (§2B above)
- Deliverable: Complete `docs/manuals/PROVIDER-MANUAL.md`
- Accept when:
  - [ ] All 12 sections present
  - [ ] Module contract has all 5 responsibilities listed
  - [ ] All 6 capability declaration fields documented
  - [ ] All 6 error taxonomy entries documented
  - [ ] Every day-1 provider listed per domain (forecast: 5, AQI: 4, alerts: 3, earthquakes: 4, radar: 8)
  - [ ] Alert severity level mapping table covers 10 national systems
  - [ ] AQI multi-jurisdiction covers 4 providers with their regional configs
  - [ ] Testing pattern has all 3 test types documented

**QC Gate 1 (Coordinator):**
- Read both drafts end-to-end
- Diff every section against its ADR source: every prescriptive rule from the ADR must appear in the manual
- Verify ADR cross-references are correct (ADR numbers, amendment dates)
- Verify no rules contradict ARCHITECTURE.md
- Check imperative voice throughout (no "should generally", "might want to")
- Check table formats are consistent (same column structure within each manual)

---

### PHASE 2 — Draft OPERATIONS-MANUAL.md + DASHBOARD-MANUAL.md

**T2.1 — Coordinator reads remaining source material**
- Owner: Coordinator (Opus)
- Read in full: `contracts/security-baseline.md`, `contracts/canonical-data-model.md`, remaining ADR files not yet fully read (ADR-013, 014, 015, 016, 017, 027, 029, 030, 031, 033, 040, 045, 046, 053)
- Deliverable: Refined content specifications for OPERATIONS-MANUAL §10 (security model) incorporating security-baseline.md controls
- Accept when: coordinator can cite specific control numbers and section references from the security baseline

**T2.2 — Draft OPERATIONS-MANUAL.md (§1-§12)**
- Owner: `clearskies-docs-author`
- Inputs: coordinator-provided content specifications (§2C above, refined by T2.1)
- Deliverable: Complete `docs/manuals/OPERATIONS-MANUAL.md`
- Accept when:
  - [ ] All 12 sections present
  - [ ] Port registry matches ARCHITECTURE.md exactly
  - [ ] Filesystem permissions table covers every file path from ADR-061
  - [ ] Security model includes trust boundary diagram from ADR-060
  - [ ] All middleware layers documented in correct order
  - [ ] Config file inventory matches ARCHITECTURE.md
  - [ ] Secret-leak guard regex documented
  - [ ] Wizard-API trust handshake flow documented step-by-step

**T2.3 — Draft DASHBOARD-MANUAL.md (§1-§8)**
- Owner: `clearskies-docs-author`
- Inputs: coordinator-provided content specifications (§2D above)
- Deliverable: Complete `docs/manuals/DASHBOARD-MANUAL.md`
- Accept when:
  - [ ] All 8 sections present
  - [ ] Page inventory matches ADR-024 exactly (9 pages + custom)
  - [ ] Per-page content inventory present for all 9 pages
  - [ ] All 13 locales listed
  - [ ] Browser support table complete
  - [ ] Performance budget numbers match ADR-033
  - [ ] Charts system covers all 3 special series types with data strategies
  - [ ] Stale-while-revalidate behavior documented with all 3 states (initial/background/error)

**QC Gate 2 (Coordinator):**
- Same process as QC Gate 1 for both manuals
- Additionally for OPERATIONS-MANUAL: verify every control from security-baseline.md is captured or explicitly noted as absorbed
- Additionally for DASHBOARD-MANUAL: verify no overlap with DESIGN-MANUAL.md (visual rules stay there; technical behavior rules here)

---

### PHASE 3 — Audit

**T3.1 — Cross-manual consistency audit**
- Owner: `clearskies-auditor`
- Do: Read all 4 new manuals + DESIGN-MANUAL.md + ARCHITECTURE.md. Flag:
  - Rules that contradict between manuals
  - Rules that duplicate between manuals (should be in one place with cross-reference)
  - ADR rules not captured in any manual
  - Manual rules that don't trace to any ADR (invented rules)
  - Port numbers, file paths, config keys that differ between manuals and ARCHITECTURE.md
- Accept when: zero contradictions, zero orphaned ADR rules, all duplicates resolved to single-source

**T3.2 — ADR completeness audit**
- Owner: `clearskies-auditor`
- Do: For each of the 39 ADRs being archived (12+14+13+7=46 minus 7 meta = 39 substantive), verify every prescriptive rule appears in its target manual. Report gaps as a list with ADR number, section, and the missing rule.
- Accept when: zero gaps, or all gaps resolved

**T3.3 — Code-to-manual cross-reference**
- Owner: `clearskies-auditor`
- Do: For API-MANUAL and PROVIDER-MANUAL, grep the API codebase for key patterns referenced in the manuals (entity class names, error taxonomy classes, provider module files, config section names). Flag manual references to code that doesn't exist and code patterns not captured in any manual.
- Accept when: every manual rule maps to existing code or is explicitly marked as pending implementation

**QC Gate 3 (Coordinator):**
- Review all auditor findings
- Integrate gap fixes into manuals
- Verify no rule lost during integration
- Confirm zero contradictions remain

**QA Gate (Coordinator — verifies QC was done properly):**
- Re-read a random sample of 5 ADRs from different manuals
- For each, manually verify that every prescriptive rule from that ADR appears in its target manual section
- If any gap found in the sample, the QC failed — send back to T3.2
- Verify the auditor actually read all 4 manuals (check for findings that span multiple manuals — a superficial audit won't find cross-manual issues)

---

### PHASE 4 — Archive & Integrate

**T4.1 — Archive ADRs**
- Owner: Coordinator (Opus)
- Do: Move 39 substantive ADRs + 2 superseded + 7 meta = 48 ADR files from `docs/decisions/` to `docs/archive/decisions/`. Set status on each to "Archived — consolidated into {MANUAL-NAME}.md". Update archive date.
- For the 2 superseded (ADR-005, ADR-019): status stays "Superseded" but moved to archive.
- For the 7 meta (ADR-001/002/003/004/011/032/036): status "Archived — substance captured in ARCHITECTURE.md".
- Accept when: only `_TEMPLATE.md` and `INDEX.md` remain in `docs/decisions/` (all ADRs archived)

**T4.2 — Update INDEX.md**
- Owner: Coordinator (Opus)
- Do: Move all entries to an "Archived" section organized by target manual. Keep the table format. Add a header note: "All ADRs have been consolidated into authoritative manuals. ADRs preserve the historical decision process (the *why*) but are not consulted for current rules."
- Accept when: INDEX.md reflects current state, no broken links

**T4.3 — Update CLAUDE.md domain routing**
- Owner: Coordinator (Opus)
- Do: Update the domain routing table to add rows for each new manual. Remove ADR-specific routing.
- New routing rows:
  - API development, data model, units, enrichment → `docs/manuals/API-MANUAL.md`
  - Provider modules, caching, external APIs → `docs/manuals/PROVIDER-MANUAL.md`
  - Deployment, security, auth, monitoring, config → `docs/manuals/OPERATIONS-MANUAL.md`
  - Dashboard technical behavior, i18n, timezone, performance → `docs/manuals/DASHBOARD-MANUAL.md`
- Accept when: any task touching these domains loads the correct manual

**T4.4 — Update ARCHITECTURE.md**
- Owner: Coordinator (Opus)
- Do: Update "Authoritative ADRs by component" section to reference manuals instead of ADRs. Add a one-line note for each meta ADR absorbed (license, multi-station scope, versioning). Remove references to archived ADRs in the body where they appear as cross-references.
- Accept when: ARCHITECTURE.md has no broken ADR references

**T4.5 — Update process rules**
- Owner: Coordinator (Opus)
- File: `rules/clearskies-process.md`
- Do: Add the new ADR lifecycle for all domains (draft ADR → accept → extract into manual → archive ADR). Same pattern as the DESIGN-MANUAL lifecycle but applied to all 4 new manuals.
- Accept when: process rules reflect the new lifecycle for all domains

**T4.6 — Archive security-baseline.md**
- Owner: Coordinator (Opus)
- Do: Move `docs/contracts/security-baseline.md` to `docs/archive/contracts/security-baseline.md`. Add a header note: "Absorbed into OPERATIONS-MANUAL.md §10. This file is no longer authoritative."
- Accept when: file moved, OPERATIONS-MANUAL is the single security authority

**QC Gate 4 (Coordinator):**
- Verify all archived files are in `docs/archive/decisions/`
- Verify `docs/decisions/` contains only `_TEMPLATE.md` and `INDEX.md`
- Verify CLAUDE.md routing works for each domain (trace a hypothetical task through the routing table)
- Verify ARCHITECTURE.md has no broken cross-references
- Verify no other file in the repo references an archived ADR as if it were still authoritative (grep for `docs/decisions/ADR-` in non-archive paths)

**QA Gate (Coordinator — verifies QC was done properly):**
- Pick 3 random ADRs from the archived set
- Verify each file physically exists in `docs/archive/decisions/`
- Verify each has the correct "Archived" status
- Verify INDEX.md has the correct entry
- Grep the codebase for references to these 3 ADRs — verify none reference them as authoritative

---

## 4. Agent Assignments

| Phase | Task | Owner | Input from Coordinator |
|-------|------|-------|----------------------|
| 1 | T1.1 API-MANUAL draft | `clearskies-docs-author` | Complete §2A specifications + ADR files to cross-ref |
| 1 | T1.2 PROVIDER-MANUAL draft | `clearskies-docs-author` | Complete §2B specifications + ADR files to cross-ref |
| 2 | T2.1 Read remaining sources | Coordinator | — |
| 2 | T2.2 OPERATIONS-MANUAL draft | `clearskies-docs-author` | Complete §2C specifications (refined) |
| 2 | T2.3 DASHBOARD-MANUAL draft | `clearskies-docs-author` | Complete §2D specifications |
| 3 | T3.1 Cross-manual consistency | `clearskies-auditor` | All 6 manual/reference docs |
| 3 | T3.2 ADR completeness | `clearskies-auditor` | 39 ADR files + 4 new manuals |
| 3 | T3.3 Code cross-reference | `clearskies-auditor` | API codebase + 2 API-facing manuals |
| 4 | T4.1-T4.6 Archive & integrate | Coordinator (Opus) | Audit results from Phase 3 |

**Sequencing:**
- T1.1 and T1.2 can run in parallel (independent manuals)
- T2.2 and T2.3 can run in parallel after T2.1
- Phase 3 requires all 4 drafts complete
- T3.1, T3.2, T3.3 run sequentially (each informs the next)
- Phase 4 requires clean audit

**Git safety:** Standard rules. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No pull/push/fetch/rebase/merge.

---

## 5. QC Framework

### QC Dimensions (applied at every gate)

| Dimension | What it checks | How |
|-----------|---------------|-----|
| **Completeness** | Every prescriptive ADR rule appears in its target manual | Diff ADR content against manual sections |
| **Accuracy** | Manual rules match current code/architecture state | Cross-ref against ARCHITECTURE.md and codebase |
| **Consistency** | No contradictions within or between manuals | Cross-manual read comparing shared concepts (ports, paths, config keys) |
| **Parsability** | Machine-readable structure, imperative voice, tokens grep-able | Style check: ≤2 heading levels, tables for inventories, do/don't pairs |
| **Non-duplication** | Each rule appears in exactly one manual | Flag duplicates; resolve to single-source + cross-reference |
| **ADR Fidelity** | Manual doesn't invent rules that don't trace to an ADR or established code | Trace each manual rule to its source |

### QA Protocol (verifies QC was done)

After each QC gate, the coordinator performs a **spot-check QA pass**:
1. Select 3-5 random ADRs from the set covered by that phase
2. Manually verify every prescriptive rule from those ADRs appears in the target manual
3. If any gap found: QC failed, return to the auditor
4. Log which ADRs were spot-checked and the result

The QA pass catches the failure mode where QC is reported as "complete" but was superficial (e.g., auditor checked section headers without reading content).

---

## 6. Registry System — Single Source of Truth for the API Surface

The code audit found 9 missing endpoints because ARCHITECTURE.md maintained a hand-written endpoint table that competed with the actual code. No enforcement. No cross-check. The same drift risk applies to data fields, providers, and config keys. This section establishes a registry system where every category of API surface has ONE authoritative source, and the manuals reference it rather than maintaining competing inventories.

### 6.1 Endpoint Registry

**Registry:** The OpenAPI spec at `/api/v1/openapi.json`, auto-generated by FastAPI from route decorators. Always accurate by construction.

**What changes:**
- ARCHITECTURE.md stops maintaining an exhaustive hand-written endpoint table. Replace with: a category summary (data endpoints, setup endpoints, health endpoints, SSE) that describes the purpose of each group + a link to the live OpenAPI spec + the Swagger UI at `/api/v1/docs`.
- API-MANUAL references the OpenAPI spec as the endpoint authority. Documents the *rules* for endpoints (versioning policy, error format, computation boundary) not the inventory.
- OPERATIONS-MANUAL documents the health endpoints (separate port, loopback-only) and setup endpoints (no `/api/v1` prefix) since those are outside the OpenAPI spec.

**Enforcement:**
- Any code change that adds/removes/renames a route is automatically reflected in the OpenAPI spec (FastAPI does this).
- The auditor includes an OpenAPI completeness check: run the API, fetch `/api/v1/openapi.json`, and verify the manual's category descriptions are still accurate.
- ARCHITECTURE.md's summary must stay current with the categories, but individual endpoint drift is impossible because the spec is generated from code.

### 6.2 Data Field Registry

**Registry:** `docs/contracts/canonical-data-model.md` — the per-field catalog of every field the API can return. Types, unit groups, sources, descriptions. This is a controlled document, not a one-time deliverable.

**What changes:**
- API-MANUAL §2 covers the *rules* (naming convention, nullability, response shapes, ConvertedValue format). It cross-references the field registry for the actual inventory.
- The canonical-data-model contract is explicitly called out as a living registry. When a field is added to the API, it must be added to this file in the same commit.
- Runtime registries (ColumnRegistry from schema reflection, provider CAPABILITY declarations) are the code-level truth. The contract file is the human-readable counterpart that must match.

**Enforcement:**
- Doc-code sync rule (§6Z below) applies: adding a field to the API without updating the contract is an incomplete task.
- Auditor cross-checks: the fields listed in the contract should match the Pydantic model definitions in `models/` and the OpenAPI response schemas.

### 6.3 Provider Registry

**Registry:** `PROVIDER_MODULES` dict in `providers/_common/dispatch.py`. Every `(domain, provider_id)` pair that the API supports is a row in this dict. Adding a provider = adding a row.

**What changes:**
- PROVIDER-MANUAL §1 documents the contract and points to `dispatch.py` as the authoritative provider inventory.
- PROVIDER-MANUAL §4-§9 (per-domain sections) document the rules and capabilities for each domain, but the list of which providers are wired is owned by the code.
- ARCHITECTURE.md's provider module layout tree stays as a structural reference but the actual provider list comes from `dispatch.py`.

**Enforcement:**
- The dispatch dict is code — it's always accurate.
- The auditor verifies that every provider in dispatch.py has a matching entry in the PROVIDER-MANUAL's domain section (at minimum: provider_id, geographic coverage, auth requirements).

### 6.4 Config Key Registry

**Registry:** The Settings classes in `config/settings.py`. Every config section and key the API reads is defined here.

**What changes:**
- OPERATIONS-MANUAL §4 documents the config *rules* (file format, search order, secret handling, secret-leak guard) and cross-references the Settings classes as the authoritative key inventory.
- The example config file (`config/api.conf.example`) must match the Settings classes. When a new config key is added, the example file is updated in the same commit.

**Enforcement:**
- Doc-code sync rule applies.
- Auditor cross-checks: keys in the example config should match the Settings class `__init__` defaults.

### 6.5 What This Means for the Manuals

The manuals are **prescriptive rule books**, not inventories. They document:
- HOW to add an endpoint (rules, computation boundary, versioning policy)
- HOW to add a provider (module contract, 5 responsibilities, error taxonomy)
- HOW to add a config key (where it goes, naming convention, secret handling)
- HOW to add a data field (naming, nullability, unit group assignment)

They do NOT try to enumerate every endpoint, every field, every provider, every config key. That's what the registries are for. The manuals link to the registries. This separation means the manuals don't go stale when new items are added — only when the *rules* change.

**Exception: external contract items that operators depend on** (ports, file paths, Caddy routes) ARE documented explicitly in ARCHITECTURE.md and OPERATIONS-MANUAL because operators configure their systems around them. These are stable and change rarely; when they do change, it's a breaking change that requires CHANGELOG documentation anyway.

---

## 7. Workflow & Process Integration

The manuals are only effective if the development process forces agents and humans to read and follow them. This section specifies the changes to rules, agent definitions, and process documents that make the manuals load-bearing.

### 6Z. Doc-Code Sync Discipline (new rule — addresses systemic drift)

**The problem:** The code audit found 3 outright contradictions and 9 missing endpoints in ARCHITECTURE.md. These didn't happen overnight — they accumulated because code changes shipped without corresponding doc updates. There is no enforcement mechanism. ADR-045 was implemented but its status was never updated from "Proposed." Endpoints were added but never reflected in the endpoint tables. The wizard grew from 7 steps to 14+ but the docs still say 7.

**Root cause:** No rule requires doc updates alongside code changes. The existing "update discipline" note in the DESIGN-MANUAL-PLAN.md self-audit section is advisory and buried — it's not in the operational rules files that agents read before every task.

**Fix: Add the following rule to `CLAUDE.md` under "Always-applicable rules":**

> **Doc-code sync: governing documents update with the code that changes them.**
>
> When a code change adds, removes, or modifies behavior that is described in a governing document (ARCHITECTURE.md, any manual in `docs/`, `rules/*.md`), the same commit (or PR) must update the governing document to match. "I'll update the docs later" is not acceptable — later never comes, and the next agent reads the stale doc and builds on it.
>
> **What counts as a governing document change:**
> - Adding/removing/renaming an API endpoint → update ARCHITECTURE.md endpoint tables + API-MANUAL.md
> - Changing port numbers, config keys, file paths → update ARCHITECTURE.md + OPERATIONS-MANUAL.md
> - Adding/modifying a provider module → update PROVIDER-MANUAL.md
> - Changing unit conversion, enrichment pipeline, or data model behavior → update API-MANUAL.md
> - Changing dashboard hooks, data flow, or technical behavior → update DASHBOARD-MANUAL.md
> - Changing UI design patterns, tokens, or components → update DESIGN-MANUAL.md
>
> **What does NOT require a doc update:**
> - Internal refactoring that doesn't change external behavior
> - Bug fixes that restore documented behavior (the doc was already right)
> - Test-only changes
>
> **For items that morph over time** (wizard steps, provider list, endpoint inventory): the governing document should reference the code as the source of truth for the volatile parts, and document only the stable patterns. Example: "Wizard steps are defined by `templates/wizard/step_*.html`" — not "The wizard has 14 steps: api, tls, eula, ..."
>
> **Enforcement:** The coordinator must verify doc-code sync before reporting any task complete. Auditor agents must flag doc-code drift as a finding. When an agent discovers a doc-code mismatch during work, it must fix the doc as part of the current task — not defer it.

**Also add to `rules/clearskies-process.md`:**

> **Doc-code sync is part of task completion.** A task is not done until governing documents reflect the code changes. The coordinator checks this at every QC gate. An agent that ships code without updating the affected manual or ARCHITECTURE.md has not completed the task — same as shipping code without tests.

**Also add to each agent definition (`.claude/agents/*.md`):**

> Before reporting a task complete, verify that any governing documents affected by your code changes have been updated in the same commit. If you added an endpoint, it must appear in ARCHITECTURE.md. If you changed enrichment behavior, API-MANUAL.md must reflect it. Doc-code drift is a defect, not a cleanup task.

This rule addresses the systemic problem directly: it makes doc updates a hard requirement of task completion, not an afterthought that nobody enforces.

### 6A. CLAUDE.md Domain Routing Table Update

Replace the current ADR-centric routing with manual-centric routing:

| Task involves... | Load |
|---|---|
| API development, data model, units, enrichment, DB access, SSE | `docs/manuals/API-MANUAL.md` + `docs/ARCHITECTURE.md` |
| Provider modules, external APIs, caching, compliance | `docs/manuals/PROVIDER-MANUAL.md` |
| Deployment, security, auth, monitoring, config, wizard | `docs/manuals/OPERATIONS-MANUAL.md` |
| Dashboard technical behavior, i18n, timezone, performance, data refresh | `docs/manuals/DASHBOARD-MANUAL.md` |
| UI design, visual patterns, tokens, component styling | `docs/manuals/DESIGN-MANUAL.md` |
| System topology, ports, endpoints, containers | `docs/ARCHITECTURE.md` |
| Clear Skies process, ADR lifecycle | `rules/clearskies-process.md` |

Remove all individual ADR routing entries. The routing must guarantee that an agent touching any domain loads the right manual BEFORE acting.

### 6B. Agent Definition Updates

Each agent type (`.claude/agents/*.md`) that does implementation work must include a mandatory read step:

**`clearskies-api-dev`:** "Before any code change, read `docs/manuals/API-MANUAL.md` and `docs/manuals/PROVIDER-MANUAL.md`. These are the single authority for API implementation rules."

**`clearskies-dashboard-dev`:** "Before any code change, read `docs/manuals/DESIGN-MANUAL.md` and `docs/manuals/DASHBOARD-MANUAL.md`. DESIGN-MANUAL covers visual rules; DASHBOARD-MANUAL covers technical behavior."

**`clearskies-auditor`:** "Read ALL manuals (`API-MANUAL.md`, `PROVIDER-MANUAL.md`, `OPERATIONS-MANUAL.md`, `DASHBOARD-MANUAL.md`, `DESIGN-MANUAL.md`) plus `ARCHITECTURE.md` before auditing."

**`clearskies-test-author`:** "Read the manual(s) for the component under test before writing tests. Tests validate manual compliance, not just code correctness."

### 6C. rules/clearskies-process.md Updates

Add the following rules:

**Manual lifecycle for ALL domains (not just UI):**
1. Decision needed → draft ADR (Proposed)
2. User approves → ADR becomes Accepted
3. Rules extracted → target manual amended with the new rules
4. ADR archived → moved to `docs/archive/decisions/`, status "Archived — consolidated into {MANUAL-NAME}"
5. Future reference → archived ADR explains *why*; manual is where you *follow* it

**Manual-update discipline:**
- Any code change that affects manual rules must update the manual in the same commit.
- The commit message must reference the manual section updated (e.g., "update API-MANUAL §6 unit system — add group_volt support").
- A code change that adds behavior not covered by any manual must either (a) update the manual or (b) draft an ADR for user approval first if the behavior is a new architectural decision.

**Manual authority hierarchy:**
- Manuals > ADRs > code comments > conversation history.
- ARCHITECTURE.md = what IS (reference). Manuals = what TO DO (prescriptive). These are complementary, not competing.
- When a manual and ARCHITECTURE.md conflict, investigate — one is stale. Fix the stale one.

### 6D. rules/coding.md Updates

Add to §9 (Design System Compliance) or create a new §10 (Manual Compliance):

- Before modifying API code: read `docs/manuals/API-MANUAL.md`.
- Before modifying provider modules: read `docs/manuals/PROVIDER-MANUAL.md`.
- Before modifying deployment, config, or security: read `docs/manuals/OPERATIONS-MANUAL.md`.
- Before modifying dashboard technical behavior: read `docs/manuals/DASHBOARD-MANUAL.md`.
- Before modifying UI/visual code: read `docs/manuals/DESIGN-MANUAL.md` (existing rule, already in §9).
- Manual rules are prescriptive. If the code doesn't match the manual, the code is wrong unless the manual is explicitly marked as pending implementation.

### 6E. ARCHITECTURE.md Cross-Reference Update

Update the "Authoritative ADRs by component" table to reference manuals:

| Component | Authority |
|-----------|----------|
| API | `docs/manuals/API-MANUAL.md` |
| Provider modules | `docs/manuals/PROVIDER-MANUAL.md` |
| Dashboard (technical) | `docs/manuals/DASHBOARD-MANUAL.md` |
| Dashboard (visual) | `docs/manuals/DESIGN-MANUAL.md` |
| Deployment / Security / Config | `docs/manuals/OPERATIONS-MANUAL.md` |

Remove all ADR references from this section. Add a note: "ADRs are archived in `docs/archive/decisions/`. They explain *why* decisions were made but are not the operational authority."

### 6F. ARCHITECTURE.md & ADR Status Fixes

These are handled in Phase 0B tasks (T0B.1 through T0B.5). See Phase 0B for details:
- T0B.1: Restructure endpoint section to use OpenAPI as registry (fixes the 9 missing endpoints)
- T0B.2: Remove hardcoded wizard step counts (reference code instead)
- T0B.3: Fix ADR-045 and ADR-046 status to Accepted (user confirmed, INDEX.md is wrong)
- T0B.4: Fix Config UI route table (pattern reference, not exhaustive list)
- T0B.5: Document CLI wizard existence

---

## 8. Verification

After all phases complete:

1. **CLAUDE.md routing test:** For each of the 6 domains in the routing table, trace a hypothetical task and verify it loads the correct manual(s).
2. **Grep test:** `grep -r "docs/decisions/ADR-" --include="*.md"` in non-archive paths should return only INDEX.md references (which now point to archive) and this plan file.
3. **Agent simulation:** Ask each agent type ("What rules govern X?") and verify it would find the answer in its loaded manual, not in an ADR.
4. **Manual count:** `docs/decisions/` should contain only `_TEMPLATE.md` and `INDEX.md`. All ADR content should be in `docs/archive/decisions/`.
5. **Cross-reference integrity:** No file in the repo should reference an archived ADR as if it were authoritative. Historical references (decision logs, plan files) are fine.

---

## 9. Self-Audit

**Risk: Four manuals is too many.** Mitigated by CLAUDE.md routing — each agent loads only the manual(s) for its domain. API dev loads API-MANUAL + PROVIDER-MANUAL. Dashboard dev loads DESIGN-MANUAL + DASHBOARD-MANUAL. No agent reads all 6 docs.

**Risk: ARCHITECTURE.md and manuals drift.** Mitigated by three mechanisms: (1) clear scope split — ARCHITECTURE.md = what IS, manuals = what TO DO; (2) doc-code sync rule in CLAUDE.md — same commit updates governing docs; (3) registry system — volatile inventories (endpoints, fields, providers) live in code-generated or code-owned registries, not hand-maintained tables. The 9-missing-endpoints problem cannot recur because ARCHITECTURE.md no longer competes with the OpenAPI spec.

**Risk: Manuals become stale.** Same mitigation as DESIGN-MANUAL: CLAUDE.md routing loads the manual before any work, so staleness is caught when a rule doesn't match reality. The doc-code sync rule (§7Z) makes doc updates a hard requirement of task completion, not an afterthought. Agents that ship code without updating affected manuals have not completed the task.

**Risk: Registries go stale.** Low risk for code-generated registries (OpenAPI spec, dispatch dict, Settings classes) — they're always accurate by construction. Higher risk for `contracts/canonical-data-model.md` which is hand-maintained. Mitigated by the doc-code sync rule: adding a field to the API requires updating the contract in the same commit. The auditor cross-checks the contract against Pydantic model definitions.

**Risk: Meta ADRs have substance not captured in ARCHITECTURE.md.** Low risk — these ADRs (component breakdown, tech stack, license, repo naming, multi-station, versioning, workspace layout) are small and their substance is already in ARCHITECTURE.md. The coordinator will verify during T4.4.

**Risk: contracts/security-baseline.md has controls not in any ADR.** The security baseline pre-dates some ADRs and may have controls that were never formalized in an ADR. T2.1 catches this — the coordinator reads the baseline in full before writing the OPERATIONS-MANUAL specifications. Any orphaned controls are added to §10.

**Risk: Code patterns found in audit are mischaracterized.** Phase 0B task T0B.6 addresses this — the coordinator confirms each of the 24 code audit findings against the actual source files before manual authors use them as input. False findings are corrected before they propagate into manuals.
