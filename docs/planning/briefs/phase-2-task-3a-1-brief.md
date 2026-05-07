# Phase 2 task 3a-1 brief — clearskies-api data-heavy DB endpoints

**Round identity.** Phase 2 task 3 sub-round 3a-1. First of two 3a rounds; 3a-2 (meta + static + pure-compute) follows once this lands. 3b (per-provider plugin domains) follows 3a-2.

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation), `clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after both submit and pytest is green on `weather-dev`.

**Repo.** `repos/weewx-clearskies-api/` (the github.com/inguy24/weewx-clearskies-api clone). Branch master per the no-feature-branches policy set 2026-05-06.

---

## Scope — 6 endpoints

All under `/api/v1/`. Implement per `docs/contracts/openapi-v1.yaml`; that spec is authoritative. The OpenAPI was updated 2026-05-06 to add `/reports/{year}` for yearly NOAA summaries — weewx writes both monthly and yearly files, and the contract was missing the yearly path.

| # | Method + path | OpenAPI | Tag | Notes |
|---|---|---|---|---|
| 1 | `GET /current` | yaml:102 | Observations | Latest archive row within a small look-back window. Returns `null` data when no rows; not 404. |
| 2 | `GET /archive` | yaml:119 | Observations | Time-range read + pagination (cursor AND page-number both supported). |
| 3 | `GET /records` | yaml:148 | Records | Section-grouped highs/lows. Periods: `ytd` (default), `all-time`, or 4-digit year. |
| 4 | `GET /reports` | yaml:473 | Reports | Index of weewx-generated NOAA files — both monthly (`NOAA-YYYY-MM.txt`) and yearly (`NOAA-YYYY.txt`). Each entry carries `kind: "monthly" | "yearly"`. |
| 5 | `GET /reports/{year}/{month}` | yaml:490 | Reports | One monthly report's raw text; missing → 404 `problem+json`. |
| 6 | `GET /reports/{year}` | yaml:521 | Reports | One yearly report's raw text; missing → 404 `problem+json`. |

Out of scope this round (defer to 3a-2 / 3b / Phase 3+):
- All other paths in `openapi-v1.yaml` (forecast, alerts, AQI, earthquakes, almanac, station, capabilities, pages, charts/groups, content, radar).
- Operator column-mapping UI (Phase 4 per ADR-027).
- Any provider plugin module per ADR-038.
- Schema migrations or any DB write path.

---

## Hard reading list (once per session)

**Both api-dev and test-author:**

- `CLAUDE.md` — domain routing + always-applicable rules (operating posture, collaboration, self-audit, lessons-capture, memory disabled).
- `rules/clearskies-process.md` — full file. The "Real schemas in unit tests where the schema shape matters," "Audit modes are complementary, not redundant," and "Lead synthesizes auditor findings" sections all govern this round.
- `rules/coding.md` — full file. §1 (security), §2 (readability), §3 (organization), §4 (self-review). §5 (a11y) is non-applicable here — backend round.
- `docs/contracts/openapi-v1.yaml` — 24 paths total (was 23 before the 2026-05-06 yearly-NOAA addition). This round implements 6; the surrounding ones are context for matching the response-envelope pattern. Schemas you'll touch: `Observation`, `ArchiveRecord`, `RecordEntry`, `RecordsBundle`, `ReportEntry`, `ReportIndex`, `NOAAReport`, `NOAAYearlyReport`, `ObservationResponse`, `ArchiveResponse`, `RecordsResponse`, `ReportIndexResponse`, `ReportResponse`, `YearlyReportResponse`, `UnitsBlock`, `PageInfo`, `Problem`, plus the reusable parameters `From/To/Interval/Fields/Limit/Cursor/Page`.
- `docs/contracts/canonical-data-model.md` — per-field unit tables for the units-block resolution. The `Observation` field set in §3.1 IS the canonical field set this round serves.
- `docs/contracts/security-baseline.md` §3.5 (input validation, this round's new ground) and §3.6 (logging — already laid down in task 1, just don't break it).

**ADRs to load before implementing:**

- ADR-010 (canonical entities — 9 cores + 2 containers)
- ADR-011 (single-station scope — single-station only at v0.1; no `?station=` filtering)
- ADR-012 (DB access pattern — read-only enforced, per-request session via `get_db_session()` already in place from task 2)
- ADR-018 (URL-path versioning, RFC 9457 errors, no support-window promise)
- ADR-019 (units handling — units block embedded per response, NO server-side conversion)
- ADR-020 (UTC ISO-8601 with `Z` on the wire; station-local TZ for display via dashboard, not here)
- ADR-029 (structured JSON logs + redaction filter — already wired)
- ADR-035 (column registry — task 2's `ColumnRegistry` is what `extras` and the units block both consume)

ADRs explicitly NOT in scope for this round: 007 (forecast providers), 013 (AQI), 014 (almanac), 015 (radar), 016 (alerts), 017 (caching), 022/023 (theming/dark mode), 024 (page taxonomy), 026 (a11y), 027 (config UI), 030 (health — landed in task 1), 037 (proxy — landed in task 1), 038 (provider modules — 3b).

---

## Existing code (do not rewrite)

Task 1 + task 2 landed:

- `weewx_clearskies_api/main.py` — FastAPI app + middleware (rate limit, security headers, request size, CORS) + routers wired.
- `weewx_clearskies_api/db/__init__.py` — public exports: `build_engine`, `get_db_session`, `run_write_probe`, `SchemaReflector`, `ColumnRegistry`, `db_probe`, `wire_db_health_probe`, `wire_engine`. **Use these. Do not bypass `get_db_session()` for ad-hoc engine grabs.**
- `weewx_clearskies_api/db/reflection.py` — `STOCK_COLUMN_MAP`, `SchemaReflector`, `ColumnRegistry`. The 86-entry stock-column lookup is canonical-model §3.1 + 3.2 verbatim.
- Health, logging, redaction filter, config loader, secret-leak guard at startup, proxy-auth — all in place. Don't reimplement.

Wire each new endpoint's router into `main.py` following the pattern task 1 set.

---

## Per-endpoint specs

### 1. `GET /current` — most-recent observation

- **Query.** `SELECT * FROM archive ORDER BY dateTime DESC LIMIT 1`. Use SQLAlchemy 2.x typed `select()`. No f-strings.
- **Response.** `ObservationResponse` envelope (data | units | source | generatedAt). `data` is the `Observation` schema OR `null` when no rows in archive.
- **Source field.** Always `"weewx"`.
- **`generatedAt`.** UTC ISO-8601 with `Z`. Server "now" at request time.
- **Look-back window.** None at v0.1 — return the latest row regardless of age. (If archive is stale by hours/days that's the operator's weewx instance, not ours; do not 404.)
- **Units block.** Resolved via the `usUnits` column on the returned row → weewx unit-system → per-canonical-field unit string per `canonical-data-model.md`. See "Units block resolution" below.
- **`extras`.** Operator-custom columns from `archive` that aren't in `STOCK_COLUMN_MAP`'s stock set — keyed by the weewx column name verbatim per ADR-035.

### 2. `GET /archive` — historical observations

- **Query parameters.** Validate ALL via Pydantic with `extra="forbid"` per security-baseline §3.5.
  - `from`, `to` — UTC ISO-8601 with `Z`. Inclusive lower, exclusive upper. Both optional. If absent: `to` defaults to "now," `from` defaults to "now − 24h."
  - `interval` — enum `raw | hour | day`, default `raw`. All three modes implemented this round.
    - `raw` — archive rows unchanged.
    - `day` — read from weewx's `archive_day_<obs>` daily summary tables (one per observation; weewx ships these with the standard schema). Each row aggregates min/max/sum/avg/count for one calendar day in station-local TZ. Use the operator-relevant aggregator per canonical field (e.g., `outTemp` returns daily mean by default; `rain` returns daily sum; `windGust` returns daily max). Per-field aggregator choice goes in a small lookup table in the same module — propose your default mapping in your closeout report; lead reviews.
    - `hour` — compute on-the-fly from `archive` (no weewx hourly summary tables in stock schema). Group by hour-truncated `dateTime`. SQLite uses `strftime('%Y-%m-%d %H:00:00', datetime(dateTime, 'unixepoch'))`; MariaDB uses `FROM_UNIXTIME(dateTime, '%Y-%m-%d %H:00:00')`. Wrap dialect-specific SQL behind a small dialect helper — do NOT branch on `dialect.name` inside the route handler.
  - `fields` — comma-separated canonical field names. Validate each is in `ColumnRegistry`'s mapped set; reject unknowns with 400. Empty/absent = all available.
  - `limit` — int 1..10000, default 1000.
  - `cursor` and `page` — mutually exclusive. Reject both-supplied with 400.
- **Pagination.** Two modes per OpenAPI:
  - Cursor: opaque base64-url-encoded JSON of `{"after_dateTime": <epoch>}` is fine; do not leak internal IDs in the cursor. Constant-time compare not needed (cursor is not auth).
  - Page: 1-based; compute `OFFSET (page-1)*limit`.
  - `PageInfo` populated for either mode (cursor null on last page; page/totalPages populated when page mode).
- **Source field.** Always `"weewx"`.
- **Response.** `ArchiveResponse` envelope (data | units | source | generatedAt | page).
- **Time-range performance.** Index on `dateTime` is assumed (weewx ships it). Don't add indexes; that's a schema-write path we don't have.

### 3. `GET /records` — highs and lows

- **Query parameters.**
  - `period` — `ytd` (default), `all-time`, or `YYYY` (4-digit year). Validate; reject malformed.
  - `section` — optional enum, restrict to one of the OpenAPI's 9 values. Omit = all sections.
- **Sections.** Per OpenAPI enum: `temperature, wind, rain, humidity, barometer, sun, aqi, inside-temp, custom`. `custom` is operator-mapped non-stock columns from `ColumnRegistry.unmapped` — but operator mapping isn't built yet (Phase 4), so `custom` returns `[]` this round.
- **Per-section field mapping (lead-confirmed; bake into `weewx_clearskies_api/services/records.py` as a constant).** Each entry: `(label, canonicalField, kind: high|low, aggregator: max|min|sum|avg)`. Within a section, omit any record whose `canonicalField` is not in `ColumnRegistry.mapped`; if the section ends up with zero records after pruning, omit the section key entirely (the "self-hide" rule below).
  - **temperature** (primary field `outTemp`):
    - `("High temperature", outTemp, high, max)`
    - `("Low temperature", outTemp, low, min)`
    - `("High dewpoint", dewpoint, high, max)`
    - `("Low dewpoint", dewpoint, low, min)`
    - `("High heat index", heatindex, high, max)`
    - `("Low wind chill", windchill, low, min)`
  - **wind** (primary field `windSpeed`):
    - `("High wind speed", windSpeed, high, max)`
    - `("High wind gust", windGust, high, max)`
  - **rain** (primary field `rain`). Records here are aggregations over time-buckets, not per-archive-row maxima:
    - `("High daily rainfall", rain, high, sum-by-day-then-max)` — for each calendar day in the period, sum `rain`; report the largest sum and the day it fell on.
    - `("High monthly rainfall", rain, high, sum-by-month-then-max)`
    - `("Most rain in 1 hour", rain, high, sum-by-hour-then-max)`
    - `("Highest rain rate", rainRate, high, max)`
  - **humidity** (primary field `outHumidity`):
    - `("High humidity", outHumidity, high, max)`
    - `("Low humidity", outHumidity, low, min)`
  - **barometer** (primary field `barometer`):
    - `("High barometer", barometer, high, max)`
    - `("Low barometer", barometer, low, min)`
  - **sun** (primary fields `radiation` and/or `UV`; section appears if either is mapped):
    - `("High solar radiation", radiation, high, max)`
    - `("High UV index", UV, high, max)`
  - **aqi** — self-hides this round. AQI in this project's weewx is provided by the `AirVisualService` extension, which writes operator-custom columns (`aqi`, `main_pollutant`, `aqi_level`, `aqi_location`) per `reference/weather-skin.md`. Operator-custom columns flow through the Phase 4 operator-mapping UI (per ADR-035 + ADR-013) before the api can surface them. The `aqi` section reappears in this endpoint when the mapping UI ships in Phase 4 OR when 3b's AQI provider plugin lands, whichever the operator configures. No special-case wiring this round.
  - **inside-temp** (primary fields `inTemp` and/or `inHumidity`):
    - `("High indoor temperature", inTemp, high, max)`
    - `("Low indoor temperature", inTemp, low, min)`
    - `("High indoor humidity", inHumidity, high, max)`
    - `("Low indoor humidity", inHumidity, low, min)`
  - **custom** — returns `[]` this round (operator-mapping UI is Phase 4 per ADR-027).
- **Period filtering.**
  - `ytd` — `WHERE dateTime >= jan_1_of_current_utc_year`.
  - `all-time` — no time filter.
  - `YYYY` — `WHERE dateTime BETWEEN jan_1 AND dec_31_of_year_inclusive`.
- **Self-hide.** Per OpenAPI description: "each section self-hides when its backing data is unavailable." If a section's canonical fields are not in `ColumnRegistry.mapped`, omit the section from the response (don't return an empty array — omit the key entirely).
- **`brokenInLast30Days`.** True when `observedAt` is within 30 days of "now." Per-record boolean.
- **Response.** `RecordsResponse` envelope.

### 4. `GET /reports` — list NOAA reports (monthly + yearly)

- **Source.** weewx writes BOTH `NOAA-YYYY-MM.txt` (monthly, via `[[SummaryByMonth]]`) and `NOAA-YYYY.txt` (yearly, via `[[SummaryByYear]]`) under the active skin's `HTML_ROOT/NOAA/`. Path comes from config — add a `[reports] directory = /path` config key. **Default value: `/var/www/html/weewx/NOAA`** (the path that matches a stock weewx Debian deb-package install with the SeasonsReport NOAA submodule generating both summary kinds). At startup, resolve the configured path; if it doesn't exist, warn-log "Reports directory not found at <path>; /reports endpoints will return empty/404 until configured." Do NOT fail-start. Document the override in your closeout report so docs-author task 8 picks it up. (For reference, this project's production weewx writes to `/var/www/weewx/NOAA` per `reference/weather-skin.md` — that's an example operator override, not the stock default.)
- **Listing.** Glob the directory for `NOAA-*.txt`. For each match, parse two filename patterns: `NOAA-YYYY-MM.txt` → `kind=monthly, year=YYYY, month=MM`; `NOAA-YYYY.txt` → `kind=yearly, year=YYYY, month=null`. Skip files that match neither pattern (e.g., a stray `NOAA-summary.txt` operator left there). Sort: yearly entries first within a year, then monthly DESC. Across years, year DESC.
- **`modifiedAt`.** From file mtime; UTC ISO-8601 with `Z`.
- **Path traversal.** Validate the configured directory at startup (resolve, ensure exists, ensure under no symlink-to-elsewhere). Per request, never accept the directory from query — config-only.
- **Response.** `ReportIndexResponse` envelope; entries use the updated `ReportEntry` schema with `kind` and nullable `month`.

### 5. `GET /reports/{year}/{month}` — one monthly report

- **Path params.**
  - `year` — int ≥ 1900 per OpenAPI. Validate.
  - `month` — int 1..12. Validate.
- **File read.** Construct `NOAA-{year:04d}-{month:02d}.txt` and join with the configured directory. **Use `os.path.join` then `os.path.realpath` and assert the result is still under the configured directory** — defense-in-depth against any path-traversal edge case.
- **Missing file.** 404 with `application/problem+json`. `title: "Report not found"`, `status: 404`, `detail: "No report exists for {year}-{month:02d}"`. Don't leak the file path.
- **`rawText`.** UTF-8 decode; reject non-UTF-8 with 500 + log critical (it's an operator-environment problem, not a client problem).
- **Response.** `ReportResponse` envelope (data: `NOAAReport`).

### 6. `GET /reports/{year}` — one yearly report

- **Path params.**
  - `year` — int ≥ 1900 per OpenAPI. Validate.
- **File read.** Construct `NOAA-{year:04d}.txt` and join with the configured directory. Same `os.path.realpath` containment check as endpoint 5.
- **FastAPI route ordering.** `/reports/{year}` is more specific than `/reports/{year}/{month}` ONLY if FastAPI matches the longer path first; verify by registering both and asserting `/reports/2025/01` doesn't accidentally match the yearly handler with `month` swallowed into `year`. Standard pattern is to declare `/reports/{year}/{month}` BEFORE `/reports/{year}` so the more-specific route wins on lookup.
- **Missing file.** 404 with `application/problem+json`. `title: "Report not found"`, `status: 404`, `detail: "No yearly report exists for {year}"`. Don't leak the file path.
- **`rawText`.** Same UTF-8 decode + critical-log path as endpoint 5.
- **Response.** `YearlyReportResponse` envelope (data: `NOAAYearlyReport`).

---

## Cross-cutting requirements

### Units block resolution (new helper for this round)

Per ADR-019 + canonical-data-model §2.2, every unit-bearing response embeds a `units` block — a map of canonical field name → unit string (`"°F"`, `"mph"`, `"inHg"`, etc.). The api **does not** convert values; it reports the unit weewx is configured to write each field in. Two layers determine that unit:

1. **System default per `target_unit`.** weewx's three presets (US / METRIC / METRICWX) map each field's group to a default unit per the §2.1 table in `docs/contracts/canonical-data-model.md`.
2. **Operator overrides** (load-bearing per ADR-019 §Decision: "per `target_unit` AND per-observation overrides"). weewx allows operators to override individual groups via `[StdConvert]` or per-skin `[Units] [[Groups]]` blocks. An operator on METRIC may force `group_pressure` to `hPa` instead of `mbar`, or `group_speed` to `knot`. If we report the system default when the operator overrode it, the units block lies and the dashboard renders the wrong label.

**Implementation.**

- **New module `weewx_clearskies_api/services/units.py`.** Module path matches the dot-path called out in canonical-data-model §2.3.
- **New config knob `[weewx] config_path`** in the existing settings model. Default `/etc/weewx/weewx.conf`. The module reads it at startup ONLY (no per-request reads).
- **At startup,** load weewx.conf using ConfigObj (already a transitive dep of weewx; if not in our `pyproject.toml` add it via uv — and STOP to ping the lead first since "no new dependencies" is otherwise in effect for this brief). Read `[StdConvert] target_unit` (one of `US | METRIC | METRICWX`) AND scan `[StdReport] [[<skin>]] [[[Units]]] [[[[Groups]]]]` for any per-group overrides. Build an immutable `dict[canonicalField, unitString]` once at startup; cache.
- **At request time,** look up each requested canonical field in the cached dict; emit the unit string. Fields with no entry (e.g., operator-custom `extras`) are absent from the units block per canonical-data-model §2.3.
- **Source-of-truth for the system→group→unit table.** Hand-translate `docs/contracts/canonical-data-model.md` §2.1 to a Python constant in `services/units.py`. Don't parse markdown at runtime. Add a unit test that asserts the Python constant matches a representative sample of §2.1 entries (changes to either side surface in CI).
- **Re-load on weewx.conf change.** Out of scope for 3a-1. Restart-to-pick-up-config is acceptable at v0.1; document in the closeout report so it can become a follow-up task.
- **`usUnits` column on rows is informational only,** not authoritative. The cached startup-loaded dict is what the units block always reflects. Mismatched per-row `usUnits` (rare; happens when the operator changed `target_unit` mid-archive) gets a one-line WARN log per request; do not flip the units block to match the row.

**Failure modes.**

- weewx.conf not at the configured path → `CRITICAL` log + exit non-zero at startup. Same fail-closed pattern as the task 2 write-probe.
- weewx.conf parses but `[StdConvert]` is absent → use US defaults + WARN log. Don't crash; that section IS optional in weewx.
- An operator override references a unit string we don't recognize → WARN log + fall back to the system default for that group. The api shouldn't crash because of operator misconfiguration.

### Pydantic validation everywhere

- All path/query/body params modeled as Pydantic with `model_config = ConfigDict(extra="forbid")`.
- Reject unknown query keys with 400 `Problem`.
- Range-validate everything (limit bounds, page ≥ 1, year ≥ 1900, month 1..12, period regex/enum).

### RFC 9457 errors

All non-2xx responses carry `application/problem+json` per ADR-018. Reuse the error handler task 1 wired up. Validation errors from FastAPI/Pydantic must be intercepted and reshaped to the `Problem` schema (FastAPI's default `422 Unprocessable Entity` body is NOT problem+json) — the project may already have this; if not, add it under task 1's existing error-handler module.

### Logging

Every request: structured one-line JSON per ADR-029. The redaction filter task 1 wired up handles `Authorization` / SQL parameter values; don't disable it. Log levels: `INFO` per-request access log; `WARNING` for client errors (4xx); `ERROR` for server errors (5xx). DEBUG is fine for development.

### No new dependencies

Everything needed is already in `pyproject.toml` (FastAPI, SQLAlchemy 2.x, Pydantic 2.x, structlog or stdlib logging). If you think you need a new dep, STOP and message the lead.

---

## Test-author parallel scope

Run `pytest` on `weather-dev` (192.168.2.113); never on DILBERT.

**Unit tests** (no DB, no network):
- Units-block helper. For each `target_unit` value (US, METRIC, METRICWX), assert each canonical field gets the expected unit string per the §2.1 table. Cover the full Observation field set, not just a sample.
- Units-block override application. Given a hand-built weewx.conf fixture with `[StdConvert] target_unit = METRIC` plus a `[StdReport][[Belchertown]][[[Units]]][[[[Groups]]]] group_pressure = hPa` override, assert `barometer` resolves to `hPa` and `outTemp` resolves to `°C`.
- Units-block startup failure. weewx.conf path missing → loader raises a specific exception class; main.py exits non-zero. weewx.conf missing `[StdConvert]` section → loader returns the US defaults + emits a WARN log.
- Pydantic param models. Reject unknown keys (`extra="forbid"`); reject out-of-range values; accept valid ones. Mutual exclusion of `cursor`+`page`. Period parsing (`ytd`, `all-time`, `2025`; reject `25`, `abc`, `1899`, future years if you choose to bound them).
- Records section assignment. Given a `ColumnRegistry` mock with a known mapped-field set, assert the right sections include / self-hide per the lead-confirmed mapping in this brief.
- Cursor encode/decode round-trips. Tampered cursor → reject with 400.
- Path-traversal guard for `/reports/{year}/{month}`. Symlink under reports dir to outside → reject with 404 (not 500).
- Aggregation aggregator-per-canonical-field defaults. Assert your proposed `outTemp → mean`, `rain → sum`, `windGust → max` (etc.) mapping is what `services/aggregation.py` exposes.

**Integration tests** (against the docker-compose dev/test stack — both backends per the schema-shape rule):
- All 5 endpoints, 200-path: real seeded production schema in `repos/weewx-clearskies-stack/dev/`. Use the `clearskies_ro` SELECT-only user from task 2.
- `/current` against an empty archive → returns `data: null`, not 404 or 500.
- `/archive` with `from`/`to` window, `interval=raw` → record set matches direct-SQL count.
- `/archive interval=hour` → row count = (window-hours × series-density-fraction); spot-check the hourly aggregate value against direct-SQL `AVG(...) GROUP BY hour-bucket`.
- `/archive interval=day` → reads from `archive_day_outTemp` etc. (verify the right summary table is hit, not `archive`); spot-check value against `archive_day_*` row directly.
- `/archive` cursor pagination → walking forward yields every row exactly once. Page mode → `totalPages * limit ≥ totalRecords`.
- `/records ytd` against a seeded year → known highs/lows match. Self-hide test: drop the `aqi` column from the test schema → `aqi` section absent from response.
- `/records?period=YYYY` for a year with no archive → response body has empty sections (not 404).
- `/reports` against a directory containing `NOAA-2025-01.txt`, `NOAA-2025-02.txt`, `NOAA-2024.txt`, and a non-NOAA file → returns 3 entries (kind=monthly × 2 + kind=yearly × 1), ignores the fourth. Sort: 2025-02 monthly, 2025-01 monthly, 2024 yearly (yearly within each year sorts first; year DESC across years).
- `/reports` against a configured-but-missing directory → returns empty `reports: []` (not 500); WARN log emitted at startup.
- `/reports/{year}/{month}` for a present file → returns `NOAAReport` rawText. For an absent file → 404 `problem+json` with no path leak.
- `/reports/{year}` for a present file → returns `NOAAYearlyReport` rawText. For an absent file → 404. Verify FastAPI route ordering: `/reports/2025/01` MUST hit the monthly handler, not the yearly one with `month=01` swallowed.
- Both backends green: dialect-helper for hourly aggregation works on SQLite (`strftime`) AND MariaDB (`FROM_UNIXTIME`). One identical integration-test asserting an hourly bucket count from a known seed produces the same result on both.

**Schema-shape rule** (rules/clearskies-process.md). Don't synthesize a one-column archive table. Use the dev/test stack's seeded production schema. Tests that depend on column count, NOT NULL constraints, or `usUnits` semantics MUST run against the real schema, not a stand-in.

**Tests run on `weather-dev` BEFORE the dev submits for audit.** Per rules/clearskies-process.md "Audit modes are complementary, not redundant" — pytest-on-real-stack catches a different bug class than the auditor's source review. Both gates fire.

**Marker.** All integration tests carry `@pytest.mark.integration` so the existing `pytest -m integration` selector picks them up. Unit tests run by default.

---

## Process gates

1. **ADR conflicts → STOP.** If anything in `openapi-v1.yaml` disagrees with an ADR or with the canonical-data-model spec, do not proceed-and-flag at closeout. Stop at the first conflict, message the lead, wait for a call. (Task 1 cost a 16-site rename round because two name conflicts surfaced at closeout.)
2. **`configobj` dep addition is PRE-APPROVED by the lead 2026-05-06.** Add it via `uv add configobj`, pin in `pyproject.toml`, ensure `uv.lock` is regenerated. No STOP needed. (configobj is the same INI-with-nested-sections parser weewx itself uses; hand-rolling a parser for our small slice was rejected as uglier than the dep add.)
3. **Diff size budget.** Target ~900–1500 line diff for the implementation (not counting tests). The aggregation work pushed the upper bound from 1200 to 1500. If it crosses 1800, ping the lead before submitting for audit; we may split the round retroactively.
4. **Run pytest on weather-dev before submitting for audit.** Both backends green via `pytest -m integration` against MariaDB and SQLite profiles.
5. **Auditor reviews after both api-dev and test-author submit + green pytest.** Lead synthesizes findings and routes back to the relevant agent. Don't auto-loop.

---

## Anti-patterns (don't)

- Don't write provider plugin modules (3b).
- Don't add operator column-mapping UI (Phase 4 per ADR-027).
- Don't wire up forecast/AQI/alerts/earthquake/almanac/station endpoints (3a-2 / 3b).
- Don't add new dependencies beyond `configobj` (pre-approved 2026-05-06 for weewx.conf parsing). Anything else → STOP and ask.
- Don't bump pinned versions.
- Don't reformat unrelated code — separate commit if it must happen.
- Don't add caching (3b lays down per-provider caching per ADR-017; nothing here needs it).
- Don't bypass `get_db_session()` for ad-hoc `engine.connect()`.
- Don't infer "reports directory" from a request param — config-only.
- Don't read weewx.conf per-request — startup-only, cached in process memory.
- Don't catch `Exception:`. Catch the specific class. (rules/coding.md §3)
- Don't add features beyond this brief. "Simple means simple."

---

## Reporting back

When you're done, report to the lead:

- Files touched (relative paths + LOC).
- ADRs and rules that governed each substantive choice.
- Pytest counts: total / unit / integration / passes / failures, both backends.
- Any ADR conflicts surfaced (and the call you made / question you raised).
- Any deviation from this brief (and why).
- Anything that surprised you in the existing task 1 / task 2 code.
- Records section-assignment proposal (if not already pre-confirmed by the lead).

---

## Out of scope, parking lot for follow-ups

- Records section assignment is currently a hard-coded constant in `services/records.py`; if the mapping turns out to be operator-customizable later, that becomes its own ADR (or a config knob). Not in 3a-1.
- weewx.conf re-load on change — restart-to-pick-up is acceptable at v0.1; document the limitation in CHANGELOG.md when docs-author task 8 ships.
- INSTALL.md / CONFIG.md updates land in task 8 (docs-author), not here. The probe.py / engine.py inline messages pointing at the not-yet-existent INSTALL.md per task 2's closeout get updated when INSTALL.md lands.
