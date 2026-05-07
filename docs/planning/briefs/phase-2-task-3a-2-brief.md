# Phase 2 task 3a-2 brief — clearskies-api meta + static + pure-compute endpoints

**Round identity.** Phase 2 task 3 sub-round 3a-2. Second of two 3a rounds; 3a-1 closed
2026-05-06 with 6 data-heavy DB endpoints (`/current`, `/archive`, `/records`,
`/reports`, `/reports/{year}/{month}`, `/reports/{year}`). 3b (per-provider plugin
domains) follows 3a-2.

**Lead = Opus.** Sonnet teammates: `clearskies-api-dev` (implementation),
`clearskies-test-author` (tests, parallel). Auditor (Opus) reviews after both submit
and pytest is green on `weather-dev`.

**Repo.** `repos/weewx-clearskies-api/` (clone of github.com/inguy24/weewx-clearskies-api).
Branch master per the no-feature-branches policy set 2026-05-06.

---

## Scope — 8 endpoints

All under `/api/v1/`. Implement per `docs/contracts/openapi-v1.yaml`; that spec is
authoritative.

| # | Method + path | OpenAPI line | Tag | Notes |
|---|---|---|---|---|
| 1 | `GET /almanac` | yaml:334 | Almanac | Sun + moon snapshot for one date. Skyfield compute per ADR-014. |
| 2 | `GET /almanac/sun-times` | yaml:354 | Almanac | Year-long per-day sunrise / sunset / daylight series. |
| 3 | `GET /almanac/moon-phases` | yaml:374 | Almanac | Per-day moon-phase grid; month or full-year. |
| 4 | `GET /station` | yaml:404 | Station | Replaces task 1's hardcoded placeholder with weewx-config-backed metadata + first/last archive timestamps. |
| 5 | `GET /capabilities` | yaml:417 | Capabilities | task 2's `ColumnRegistry` data + empty `providers` list (3b populates providers). |
| 6 | `GET /pages` | yaml:435 | Pages | The 9 built-in pages from ADR-024 in default nav order, minus operator-hidden slugs. |
| 7 | `GET /charts/groups` | yaml:451 | Charts | Built-in chart groups (`homepage`, `monthly`, `ANNUAL`, `averageclimate`); members pruned against `ColumnRegistry.mapped`. |
| 8 | `GET /content/about`, `GET /content/legal` | yaml:556, 569 | Content | Markdown file passthrough; sanitization happens dashboard-side per security-baseline §5. (Two paths sharing a near-identical handler — count as one impl unit, two route entries.) |

Out of scope this round (defer to 3b / Phase 3+ / Phase 4):

- All provider-domain endpoints (`/forecast`, `/alerts`, `/aqi/*`, `/earthquakes`,
  `/radar/*`) — that's 3b.
- Operator-defined custom pages and custom chart groups — surface those when the
  configuration UI ships in Phase 4 per ADR-027. 3a-2 returns built-ins only;
  the OpenAPI schemas allow custom entries to be present or absent.
- Operator column-mapping UI (Phase 4 per ADR-027 + ADR-035).
- Twilight-definition operator override (ADR-014 says default = civil; not
  operator-configurable at v0.1).
- TZ-from-lat-lon derivation via `timezonefinder` — that's Phase 4 setup-wizard
  scope per ADR-020 §Consequences. 3a-2 uses a 3-tier fallback (api.conf →
  weewx.conf → OS TZ → UTC + WARN); never silently calls a geo-TZ library.

---

## Lead+user-confirmed calls (resolved 2026-05-06 before spawn)

1. **`skyfield` dependency add — pre-approved.** ADR-014 names skyfield directly;
   add via `uv add skyfield`, pin in `pyproject.toml`, regenerate `uv.lock`.
   Same pre-approval shape as configobj for 3a-1.
2. **Ephemeris file — lazy-download with cache.** Skyfield's `Loader(<cache_dir>)`
   fetches DE421 (~17 MB) on first run; `[almanac] ephemeris_directory` config
   knob defaults to `/var/cache/weewx-clearskies/skyfield/`. Operator with no
   first-run internet pre-places `de421.bsp` in that dir; the loader uses it
   without downloading. Document the offline-install path in the closeout report.
3. **`station_id` default — slug of weewx.conf `[Station] location`.** Optional
   `[station] station_id = ...` knob in api.conf; absent → default to slugified
   weewx.conf location (e.g. `"Belchertown, MA"` → `"belchertown-ma"`).
4. **Content directory default — `/etc/weewx-clearskies/content/`.** `[content]
   directory` knob in api.conf. Expected filenames `about.md` and `legal.md`;
   missing → 404.
5. **Built-in chart-group default member field sets — bake as constant in
   `services/charts.py`:**
   - **homepage** — `outTemp`, `dewpoint`, `outHumidity`, `windSpeed`, `windGust`,
     `windDir`, `barometer`, `rain`, `rainRate`, `radiation`, `UV`,
     `lightning_strike_count`, `pollutantPM25`. Default range `1d`.
   - **monthly** — `outTemp`, `rain`, `windSpeed`, `barometer`. Default range
     `null` (group has its own month-dropdown selector model per ADR-024).
   - **ANNUAL** — `outTemp`, `rain`. Default range `null` (year dropdown).
   - **averageclimate** — `outTemp`, `rain`. Default range `null`.

   Members are pruned at request time against `ColumnRegistry`'s mapped set;
   groups with zero members after pruning self-hide (parallel to /records).
   Operator-defined custom groups are NOT in 3a-2 (Phase 4 work).
6. **Altitude units — ADR-019 wins; OpenAPI description gets a follow-up fix.**
   `/station` emits `altitude` in whatever unit weewx is configured to write
   (consistent with every other unit-bearing field); the units block carries the
   group_altitude string. The OpenAPI description "Meters above mean sea level"
   is a contract typo and gets corrected in a separate lead-owned commit post-
   3a-2.

---

## Hard reading list (once per session)

**Both api-dev and test-author:**

- `CLAUDE.md` — domain routing + always-applicable rules (operating posture,
  collaboration, self-audit, lessons-capture, memory disabled).
- `rules/clearskies-process.md` — full file. Carry-forward-from-3a-1: "Real schemas
  in unit tests where the schema shape matters," "Audit modes are complementary, not
  redundant," "Lead synthesizes auditor findings; doesn't forward," "Plain English
  when explaining decisions to the user," "No 'promotion candidates' or 'we'll add
  it later' framing in v0.1 contracts," "Round briefs land in the project, not in
  tmp."
- `rules/coding.md` — full file. §1 (security; carry-forward: backtick reserved
  words, Pydantic+Depends pattern, dual-stack networking), §2 (readability), §3
  (organization; carry-forward: catch specific exceptions, no dead code), §4
  (self-review). §5 (a11y) is non-applicable here — backend round.
- `docs/contracts/openapi-v1.yaml` — the 8 paths above plus the response-envelope
  conventions from 3a-1. Schemas you'll touch: `AlmanacSnapshot`, `SunTimesSeries`,
  `MoonPhaseCalendar`, `StationMetadata`, `CapabilityRegistry`,
  `CapabilityDeclaration`, `PageList`, `PageMetadata`, `ChartGroup`, `ChartGroupList`,
  `MarkdownContent`, plus all corresponding `*Response` envelopes.
- `docs/contracts/canonical-data-model.md` §2 (units/groups), §3.9 (StationMetadata).
- `docs/contracts/security-baseline.md` §3.3 (DB read-only), §3.5 (input validation;
  carry-forward Pydantic+Depends pattern), §5 (markdown sanitization is dashboard-
  side, not api-side — `/content/*` returns raw markdown unchanged).

**ADRs to load before implementing:**

- ADR-008 (auth model — no end-user auth; only the optional cross-host proxy secret)
- ADR-010 (canonical entities — StationMetadata is one of the 9)
- ADR-011 (single-station scope — no `?station=`; StationMetadata is a singleton)
- ADR-012 (DB access pattern — read-only enforced; per-request session via
  `get_db_session()`. /station hits MIN(dateTime), MAX(dateTime); /capabilities hits
  the column registry, no DB query at request time)
- ADR-014 (almanac — skyfield, JPL DE421, server-side; no internet at compute time)
- ADR-018 (URL-path versioning, RFC 9457 errors)
- ADR-019 (units handling — units block embedded; carry-forward from 3a-1; /station
  emits a units block with `altitude` keyed)
- ADR-020 (TZ — UTC ISO-8601 with `Z` on the wire; IANA identifier in StationMetadata;
  source priority operator-config > weewx.conf > OS TZ > UTC fallback)
- ADR-024 (page taxonomy — 9 built-ins listed with slug/icon/order; per-page hide;
  custom pages out-of-scope this round)
- ADR-027 (config — INI / configobj; api.conf paths)
- ADR-029 (structured JSON logs — already wired; don't disable redaction filter)
- ADR-035 (column registry — task 2's `ColumnRegistry` is what /capabilities consumes)
- ADR-038 (provider modules — `/capabilities` returns an empty `providers: []` until
  3b populates per-provider modules; the schema is already locked)

ADRs explicitly NOT in scope for this round: 007 (forecast — 3b), 013 (AQI — 3b),
015 (radar — 3b), 016 (alerts — 3b), 017 (caching — 3b), 022/023 (theming/dark mode
— Phase 3 dashboard), 026 (a11y — Phase 3 dashboard), 030 (health — landed in task
1), 037 (proxy — landed in task 1), 040 (earthquakes — 3b).

---

## Existing code (do not rewrite)

Tasks 1 + 2 + 3a-1 landed:

- `weewx_clearskies_api/app.py` — FastAPI app + middleware + routers (station,
  observations, records, reports). Add the new routers (almanac, capabilities,
  pages, charts, content) following the existing pattern.
- `weewx_clearskies_api/db/registry.py` — `wire_registry()` / `get_registry()`.
  /capabilities consumes via `get_registry()`.
- `weewx_clearskies_api/db/reflection.py` — `STOCK_COLUMN_MAP` (86 entries),
  `ColumnRegistry`. Read but don't edit.
- `weewx_clearskies_api/services/units.py` — already loads weewx.conf at startup
  via configobj. **/station and /almanac need to extract additional sections from
  the same parsed config** (`[Station]` for station identity); refactor units.py to
  expose the parsed `ConfigObj` once and have a sibling `services/station.py`
  consume the same parse, OR extract a small `services/weewx_conf.py` that owns the
  parse and both station + units consume it. Lead-recommended approach: a thin
  `services/weewx_conf.py` module that holds the cached `ConfigObj`, with `units.py`
  refactored to consume it. Don't re-parse weewx.conf twice.
- `weewx_clearskies_api/services/reports.py` — `wire_reports_directory()` is the
  pattern to copy for `wire_content_directory()` and `wire_ephemeris_directory()`.
- `weewx_clearskies_api/__main__.py` — startup sequence is in place. Add: skyfield
  ephemeris init + content-directory wiring + station-section load. Follow the
  existing fail-closed-or-warn-only pattern (see "Failure modes" below per
  endpoint).
- `weewx_clearskies_api/errors.py` — RFC 9457 handler is wired; reuse it.
- `weewx_clearskies_api/models/params.py` and `models/responses.py` — Pydantic+Depends
  pattern from 3a-1. Add new param/response models alongside the existing ones.
- `weewx_clearskies_api/endpoints/station.py` — currently a hardcoded placeholder.
  This round REPLACES the body; keep the file path and router name.

Wire each new endpoint's router into `app.py` following the pattern task 1 set.

---

## Per-endpoint specs

### 1. `GET /almanac` — sun + moon snapshot for one date

- **Query.** `date` — optional, ISO date `YYYY-MM-DD`. Default = station-local today
  (compute via station TZ from `services/station.py`). Pydantic-validate via
  `Depends(_get_almanac_params)` (extra="forbid"); reject malformed dates with 400
  RFC 9457.
- **Compute.** Skyfield `Loader(<ephemeris_directory>)` + `de421.bsp`, station
  lat/lon/altitude. All times computed at the station location, returned UTC ISO-8601
  with `Z`.
- **Sun fields per OpenAPI (lines 1232-1247).** rise / set / transit; civilTwilight
  dawn + dusk (sun at -6° below horizon — civil per ADR-014 out-of-scope §);
  azimuth / altitude (degrees, at noon-local for "where will the sun be at solar
  noon"); rightAscension (hours), declination (degrees);
  daylightMinutes (set − rise, integer); daylightDeltaVsYesterdayMinutes (today's
  daylight − yesterday's, integer; positive = lengthening, negative = shortening);
  nextEquinox / nextSolstice (next chronologically after the requested date).
- **Moon fields per OpenAPI (lines 1248-1264).** rise / set / transit; azimuth /
  altitude / rightAscension / declination (same conventions as sun);
  phaseName (one of `new | waxing-crescent | first-quarter | waxing-gibbous | full
  | waning-gibbous | last-quarter | waning-crescent`); illuminationPercent (0..100);
  nextFullMoon / nextNewMoon (next chronologically after the requested date).
- **Polar-edge handling.** At high latitudes / certain dates the sun may not rise
  or not set ("polar day" / "polar night"). Skyfield's `find_discrete` returns no
  events on those days. Emit `null` for the affected fields (rise/set/transit/
  twilight); `daylightMinutes = 0` on a polar night, `1440` on a polar day. Don't
  raise. Same handling for moon-not-rising days.
- **Phase-name mapping.** Use the standard 8-bin scheme from skyfield's
  `almanac.MOON_PHASES` lookup OR compute from illumination percent + waxing/waning
  flag. Lead-confirmed default mapping in the brief: bin width 45° around each
  named phase (≤ 22.5° from new = `new`, 22.5..67.5° = `waxing-crescent`, etc.).
  ASCII-safe enum strings exactly as OpenAPI specifies.
- **Response.** `AlmanacResponse` envelope (data: `AlmanacSnapshot`, generatedAt).
- **No DB hit.** Pure compute.

### 2. `GET /almanac/sun-times` — year-long sunrise / sunset / daylight series

- **Query.** `year` — optional integer ≥ 1900. Default = current calendar year in
  station TZ.
- **Compute.** Loop `date` from Jan 1 to Dec 31 (Feb 29 included on leap years).
  For each date, compute sunrise / sunset / daylightMinutes the same way as
  endpoint 1's sun block. Per-day cost is small (skyfield is millisecond-fast after
  ephemeris load); 365–366 iterations is well under one request budget.
- **Response.** `SunTimesResponse` envelope (data: `SunTimesSeries`, generatedAt).
  `SunTimesSeries.year` echoed; `days` array contains one entry per day with
  date / sunrise / sunset / daylightMinutes.
- **Polar handling.** Same null-and-zero-or-1440 handling as endpoint 1.
- **Performance note.** Cache the Skyfield `ts` (timescale) and the loaded ephemeris
  globally — re-creating per request is wasteful. The Loader-cached approach is
  the standard skyfield pattern. Don't add a request-result cache (ADR-017 caching
  applies to provider responses, not to local compute; this round adds zero
  caching layers).
- **No DB hit.**

### 3. `GET /almanac/moon-phases` — per-day moon-phase calendar

- **Query.** `year` — optional integer ≥ 1900. `month` — optional integer 1..12.
  When `month` omitted, response covers the full year. When both omitted, default
  year = current calendar year in station TZ.
- **Compute.** Loop each date in the requested span. Per date: compute
  `phaseName` (8-bin per endpoint 1's mapping) and `illuminationPercent` (0..100).
  No rise/set in this endpoint — that's per-day-detail in endpoint 1.
- **Response.** `MoonPhaseResponse` envelope (data: `MoonPhaseCalendar`,
  generatedAt). `year` echoed; `month` echoed (null on full-year). `days` array
  with date / phaseName / illuminationPercent (all required per OpenAPI line 1299).
- **No DB hit.**

### 4. `GET /station` — station identity and metadata

- **Replace the placeholder** at `endpoints/station.py`. Keep file + router.
- **No query params.** Endpoint takes no input; the response is a singleton per
  ADR-011.
- **Compose the response from these sources:**
  - `stationId` — `[station] station_id` from api.conf, OR slugified weewx.conf
    `[Station] location` if absent (per resolved call #3).
  - `name` — weewx.conf `[Station] location`. Required by weewx; if missing emit
    a CRITICAL log + exit non-zero at startup (treat as misconfigured weewx).
  - `latitude`, `longitude` — weewx.conf `[Station] latitude` / `longitude`
    (decimal degrees, signed). Required.
  - `altitude` — weewx.conf `[Station] altitude` (format: `value, unit` per the
    weewx 5.3 docs). **Pass through as-is, in whatever unit weewx wrote it** (per
    ADR-019; the units block carries the unit string). Don't pre-convert. Don't
    import a unit-conversion library. The unit (`foot` or `meter`) flows into
    the units block via the existing `services/units.py` group_altitude lookup.
  - `timezone` (IANA) — `[station] timezone` from api.conf, then weewx.conf
    `[Station] timezone` if present, then OS TZ from `time.tzname`+`zoneinfo` lookup,
    then UTC + WARN log. Per ADR-020 source priority. Operator override via
    api.conf is the documented escape hatch.
  - `timezoneOffsetMinutes` — current offset for the resolved IANA TZ, computed
    via `zoneinfo.ZoneInfo(timezone).utcoffset(datetime.now(tz=UTC))`.
  - `unitSystem` — call `services.units.get_target_unit()`. Already cached at
    startup.
  - `firstRecord`, `lastRecord` — `SELECT MIN(dateTime), MAX(dateTime) FROM archive`
    via `get_db_session()`. Both indexed; query is sub-millisecond. Convert epoch
    seconds to UTC ISO-8601. Empty archive (zero rows) → both null; do not 404.
  - `hardware` — weewx.conf `[Station] station_type` (string; nullable per OpenAPI
    line 1222).
- **Units block.** `StationResponse` envelope embeds `UnitsBlock` (OpenAPI line
  1539). Reuse `services.units.get_units_block()`; `altitude` maps to
  group_altitude → "foot" or "meter" depending on target_unit. ADR-019 is
  authoritative: the units block reflects what weewx writes; the value flows
  through unchanged. The OpenAPI line 1207 description "Meters above mean sea
  level" is a contract typo (lead-owned follow-up commit post-3a-2). Flag it in
  the closeout report so the lead schedules the docstring fix; don't fix it
  yourself in 3a-2.
- **Failure modes.**
  - weewx.conf [Station] missing required fields (`location` / `latitude` /
    `longitude`) → CRITICAL + exit non-zero at startup. `services/station.py` runs
    its load before uvicorn starts, same pattern as `load_units_block`.
  - timezone resolution fails (operator config absent + weewx.conf absent + OS TZ
    unparseable) → fall back to UTC + WARN.
  - DB error on MIN/MAX query → 500 + RFC 9457; do not 200 with stale or null
    values.
- **Response.** `StationResponse` envelope (data: `StationMetadata`, units,
  generatedAt).

### 5. `GET /capabilities` — runtime capability registry

- **No query params.**
- **Compose from `ColumnRegistry` (task 2):**
  - `weewxColumns` (OpenAPI line 1456) — array of `{canonicalField, archiveColumn}`
    objects, one per stock column the operator's archive actually has. Source:
    `registry.stock.values()` → `{canonicalField: info.canonical_name,
    archiveColumn: info.db_name}`.
  - `canonicalFieldsAvailable` — union of canonical fields from any source. For
    3a-2 (no providers wired), this equals the set of `canonical_name` values
    from `registry.stock`.
  - `providers` — empty array `[]`. 3b populates per-provider declarations.
- **Operator-mapped custom columns.** `registry.unmapped` is the operator-extension
  surface; until the column-mapping UI ships in Phase 4, those columns aren't on
  the canonical surface yet, so they don't appear in `weewxColumns` or
  `canonicalFieldsAvailable`. Document as out-of-scope in the closeout report.
- **No DB hit at request time.** Registry is in-memory.
- **Response.** `CapabilityResponse` envelope.

### 6. `GET /pages` — dashboard navigation list

- **No query params.**
- **Source.** Hardcoded list of the 9 built-in pages from ADR-024 baked as a
  constant in `services/pages.py`:

  | navPosition | slug | name | icon | builtIn |
  |---|---|---|---|---|
  | 1 | `now` | `Now` | `house` | true |
  | 2 | `forecast` | `Forecast` | `cloud-sun-rain` | true |
  | 3 | `charts` | `Charts` | `chart-line` | true |
  | 4 | `almanac` | `Almanac` | `moon` | true |
  | 5 | `earthquakes` | `Earthquakes` | `activity` | true |
  | 6 | `records` | `Records` | `trophy` | true |
  | 7 | `reports` | `Reports` | `file-text` | true |
  | 8 | `about` | `About` | `info` | true |
  | 9 | `legal` | `Legal` | `scale` | true |

- **Operator-hidden built-ins.** Read `[pages] hidden` (comma-separated slugs OR
  INI list) from api.conf. Default empty. Hidden built-ins are EXCLUDED from the
  response — per ADR-024 "Off-pages don't appear in nav and their routes return
  404." (3a-2 owns the nav-list filter; the route-404 piece is the dashboard's
  router job per ADR-024.) Operator can't hide `now` (ADR-024 "`Now` cannot be
  unchecked"); validate at config-load time + log WARNING + ignore the entry if
  the operator added `now` to the hidden list.
- **Custom pages.** Empty in 3a-2; Phase 4 config UI populates.
- **Response.** `PageListResponse` envelope.

### 7. `GET /charts/groups` — chart-group structure

- **No query params.**
- **Source.** Hardcoded list of the 4 built-in groups from ADR-024 + Q5's
  member defaults, baked as a constant in `services/charts.py`:

  | id | name | builtIn | members | defaultRange |
  |---|---|---|---|---|
  | `homepage` | `Homepage` | true | `outTemp, dewpoint, outHumidity, windSpeed, windGust, windDir, barometer, rain, rainRate, radiation, UV, lightning_strike_count, pollutantPM25` | `1d` |
  | `monthly` | `Monthly` | true | `outTemp, rain, windSpeed, barometer` | null |
  | `ANNUAL` | `Annual` | true | `outTemp, rain` | null |
  | `averageclimate` | `Average climate` | true | `outTemp, rain` | null |

- **Self-prune.** At request time, intersect each group's `members` with
  `ColumnRegistry`'s mapped canonical-field set. Members that aren't mapped get
  dropped. If a group ends up with `members: []` after pruning, OMIT the group
  from the response (parallel to /records section self-hide). Operator's archive
  doesn't have a column → that field disappears from the chart; if the whole
  homepage's worth of fields disappears, the group disappears. Don't return empty
  groups.
- **Custom groups.** Empty in 3a-2; Phase 4 config UI populates.
- **Response.** `ChartGroupResponse` envelope.

### 8. `GET /content/about`, `GET /content/legal` — operator markdown

Two endpoints with one shared handler (different file path).

- **No query params.**
- **Source.** Read `<content_directory>/about.md` (or `legal.md`). Default
  content_directory per resolved call #4: `/etc/weewx-clearskies/content/`. Read at request time
  (operator may edit between requests; markdown files are small).
- **Path traversal.** Same defense as 3a-1's /reports/{year}/{month}: `os.path.join`
  + `os.path.realpath` + assert the result is still under
  `os.path.realpath(content_directory)`. The filename is hardcoded
  (`about.md` / `legal.md`); no user input flows in. Belt-and-suspenders even so.
- **File missing.** 404 RFC 9457. `title: "Content not found"`,
  `detail: "No about.md (or legal.md) found in the configured content directory"`.
  Don't leak the absolute path.
- **`updatedAt`.** From file mtime, UTC ISO-8601 with `Z`. Nullable per OpenAPI
  line 1477; emit as null only if mtime is unreadable for some reason.
- **`markdown`.** UTF-8 file content, raw. **Do not sanitize** server-side —
  security-baseline §5 places sanitization in the dashboard's react-markdown
  pipeline. The api returns whatever bytes are in the file. (Misuse from a
  non-sanitizing dashboard is the dashboard's bug per the §5 ESLint pin.)
- **File too large.** If file size > 1 MiB, return 500 + log critical with the
  file path. The 1 MiB threshold is informational here; security-baseline §8 notes
  the body-limit may need bumping for legitimately-large markdown blobs (this is
  outbound, so it's a different concern, but a malformed file shouldn't OOM the
  process). Don't read into memory beyond 1 MiB; use `Path.stat()` first.
- **Response.** `MarkdownResponse` envelope (data: `MarkdownContent`, generatedAt).
- **Startup wire.** `wire_content_directory()` in `services/content.py` mirrors
  `wire_reports_directory()`. Missing directory → WARN at startup; both endpoints
  return 404 until the operator places files.

---

## Cross-cutting requirements

### Skyfield init (one-time, at startup)

Add to `services/almanac.py`:

- `wire_ephemeris_directory(path: str) -> None` — validates the directory exists
  (or creates it with mode 0755 if not — same as standard XDG-cache pattern), then
  constructs `skyfield.api.Loader(path)` and triggers ephemeris load via
  `Loader('de421.bsp')`. First-run downloads ~17 MB from JPL; subsequent runs read
  from disk. **Failure modes:**
  - Cache directory not writable AND ephemeris file not present → CRITICAL + exit
    non-zero (we can't compute almanac without it; this is a fail-closed startup
    condition, same pattern as `load_units_block`).
  - Cache directory writable but no internet on first run → skyfield raises
    `URLError` or similar; CRITICAL + exit. Document the offline-install path
    in the closeout (operator pre-places `de421.bsp` in the cache dir).
  - Ephemeris already present → load and continue.
- Cache the `ts` (timescale) and the loaded ephemeris (`eph`) at module level for
  per-request reuse. Don't load per request.
- Hook into `__main__.py` between the units-block load and the report-directory
  wire. Same fail-closed exit pattern.

### Station-metadata wire (one-time, at startup)

Add to `services/station.py`:

- `load_station_metadata(weewx_conf_path, api_station_id, api_timezone) -> StationMetadata`
  — parses weewx.conf [Station] (reusing the cached ConfigObj if `services/units.py`
  is refactored to expose it; otherwise re-parse — see the existing-code section
  about extracting `services/weewx_conf.py`). Validates required fields, applies
  the TZ source priority, slugifies location to default station_id, returns the
  partially-populated metadata. The `firstRecord` / `lastRecord` fields stay null
  in the cached object; the endpoint fills them per request via DB query.
- **Don't import any TZ-derivation library.** The 3-tier fallback (api.conf →
  weewx.conf → OS TZ → UTC + WARN) is the v0.1 mechanism per ADR-020 §Consequences.
  `timezonefinder` is Phase 4 setup-wizard scope.

### Pydantic + `Depends(_get_*_params)` pattern (carry-forward from 3a-1)

Every endpoint that takes query params uses the wrapper pattern documented in
`rules/coding.md` §1. `extra="forbid"` only fires when the whole query string flows
through Pydantic via `Depends(_get_*_params)`; declaring fields individually with
`Query()` silently breaks the security-baseline §3.5 control. **Endpoints in 3a-2
that take query params:** `/almanac` (date), `/almanac/sun-times` (year),
`/almanac/moon-phases` (year, month). The other 5 endpoints are zero-param and
need no Depends-wrapper but should still set `extra="forbid"` on any Pydantic
response models for symmetry.

### RFC 9457 errors (carry-forward from task 1)

All non-2xx responses carry `application/problem+json`. The error handler in
`errors.py` is wired; reuse it. New error cases this round: 400 on bad date / year
/ month; 404 on missing content file; 500 on UTF-8 decode error / DB error / file
> 1 MiB.

### Logging (carry-forward from task 1)

Structured one-line JSON per ADR-029. The redaction filter is wired; don't disable.
Levels: `INFO` per-request access log; `WARNING` for client errors (4xx); `ERROR`
for server errors (5xx). DEBUG fine for development. Log skyfield ephemeris load
at INFO (size, path, time-to-load).

### No new dependencies except `skyfield`

`skyfield` is pre-approved per resolved call #1 (analog to configobj for 3a-1). Add via
`uv add skyfield`, pin in `pyproject.toml`, regenerate `uv.lock`. Anything else
→ STOP and ping the lead. Specifically: NO `timezonefinder`, NO `pytz` (use stdlib
`zoneinfo`), NO `dateutil` (stdlib `datetime` + `zoneinfo` cover the surface
needed), NO markdown library (api passes through raw text).

### Catch specific exceptions

`rules/coding.md` §3 — no `except Exception:`. Skyfield raises specific exception
classes; catch those. File I/O raises `FileNotFoundError`, `PermissionError`,
`UnicodeDecodeError`. SQLAlchemy raises `SQLAlchemyError` subclasses for the
MIN/MAX query.

### Plain-text/UTF-8 file decode

All file reads use `Path.read_text(encoding="utf-8")` — a `UnicodeDecodeError`
mid-read is operator-environment, not client; treat as 500 + critical-log per the
3a-1 pattern.

---

## Test-author parallel scope

Run `pytest` on `weather-dev` (192.168.2.113); never on DILBERT.

**Unit tests** (no DB, no network):

- Skyfield wrapper. Given a known lat/lon/date, assert returned sunrise / sunset
  match a known-good reference (use a published table, e.g., USNO's online
  almanac, for two reference dates — one mid-latitude, one polar). Allow ±1 minute
  tolerance for skyfield-vs-USNO algorithm differences.
- Polar-edge cases. Lat 89° on June 21 → polar day → daylightMinutes=1440 + null
  rise/set. Lat 89° on December 21 → polar night → daylightMinutes=0 + null.
- Phase-name 8-bin classification. Given a sequence of illumination percents and
  waxing/waning flags, assert the produced phaseName matches the bin definition
  in the brief.
- Sun-times year loop. 2024 = leap year → 366 entries. 2023 = non-leap → 365.
- Moon-phases month vs full-year switching. With month omitted → days array spans
  the full year. With month set → days span just that month.
- Pydantic param models. Reject unknown query keys (`extra="forbid"`); reject
  out-of-range year (< 1900); reject month outside 1..12; reject malformed date
  string.
- Station-metadata loader. Given a hand-built weewx.conf fixture with [Station]
  location/latitude/longitude/altitude/station_type, assert StationMetadata fields
  populate correctly. Altitude pass-through: `altitude = 700, foot` → emit value
  700 with units block group_altitude="foot"; same value flows out under
  METRICWX with units block "meter" (per ADR-019, no server-side conversion).
- Station-metadata TZ source priority. api.conf TZ wins; missing → weewx.conf TZ
  wins; missing both → OS TZ wins; missing all → UTC + WARN.
- station_id default. Given weewx.conf location = "Belchertown, MA", assert
  default station_id slugifies to "belchertown-ma". Operator override always
  wins.
- Capabilities response. Given a hand-built `ColumnRegistry` with 5 stock columns
  and 2 unmapped, assert `weewxColumns` has 5 entries and `canonicalFieldsAvailable`
  has 5 names; `providers` is `[]`.
- Pages list. With `[pages] hidden = forecast,records`, assert response omits
  those two and includes the other 7. With `[pages] hidden = now`, assert WARN
  emitted + `now` still present in the response.
- Charts groups self-prune. Given a `ColumnRegistry` mapped-set that doesn't
  contain `lightning_strike_count` and `pollutantPM25`, assert homepage members
  shrink accordingly. Given an empty mapped set (degenerate case), assert all
  groups self-hide and `groups: []` is returned.
- Content endpoint path traversal. Symlink under content_directory pointing
  outside → reject with 404 (not 500).
- Content endpoint missing file → 404 with `application/problem+json`, no path
  leak in `detail`.

**Integration tests** (against the docker-compose dev/test stack — both backends
per the schema-shape rule):

- All 8 endpoints, 200-path: real seeded production schema in
  `repos/weewx-clearskies-stack/dev/`. Use the `clearskies_ro` SELECT-only user
  from task 2.
- /almanac. Returns valid AlmanacSnapshot. JSON shape matches OpenAPI
  AlmanacResponse exactly.
- /almanac/sun-times for current year → 365 or 366 entries; first entry is Jan 1,
  last is Dec 31.
- /almanac/moon-phases without month → full year span; with month=6 → days for
  June only.
- /station against a seeded archive → firstRecord = oldest seed timestamp,
  lastRecord = newest. Empty archive (drop seed rows) → both null, no 500.
- /station with [station] station_id absent → response stationId = slug of
  weewx.conf location. With override set → response stationId = override.
- /capabilities → weewxColumns count matches `len(registry.stock)`;
  canonicalFieldsAvailable has the same length (no provider domains in 3a-2).
  `providers: []`.
- /pages with `[pages] hidden = legal` → 8 entries; `legal` absent.
- /charts/groups against a seed schema lacking `lightning_strike_count` →
  homepage.members excludes that field but still includes the rest. Drop all
  homepage candidate columns from the schema → homepage group absent from response.
- /content/about with about.md present → returns its markdown content + a non-null
  updatedAt. Without the file → 404 problem+json.
- Both backends green: any DB-touching endpoint (/station MIN/MAX query) runs
  identically on SQLite and MariaDB.

**Schema-shape rule (`rules/clearskies-process.md`).** Don't synthesize a
one-column archive table for /station's MIN/MAX test — use the dev/test stack's
seeded production schema. The production schema is what surfaces backtick-needed
reserved-word issues.

**Tests run on `weather-dev` BEFORE the dev submits for audit.** Per
`rules/clearskies-process.md` "Audit modes are complementary, not redundant" —
pytest-on-real-stack catches a different bug class than the auditor's source
review. Both gates fire.

**Marker.** All integration tests carry `@pytest.mark.integration` so the existing
`pytest -m integration` selector picks them up. Unit tests run by default.

---

## Process gates

1. **ADR conflicts → STOP.** If anything in `openapi-v1.yaml` disagrees with an
   ADR or with canonical-data-model, do not proceed-and-flag at closeout. Stop at
   the first conflict, message the lead, wait for a call. The /station altitude
   units conflict is already lead-flagged in this brief — no STOP needed for
   that one.
2. **`skyfield` dep addition is PRE-APPROVED by the lead 2026-05-06.**
   Add via `uv add skyfield`, pin in `pyproject.toml`, ensure `uv.lock` is
   regenerated. No STOP needed. Anything else → STOP.
3. **Diff size budget.** Target ~1500–2500 line diff for the implementation (not
   counting tests). Almanac is heaviest; the other 5 are smaller. If it crosses
   2800, ping the lead before submitting for audit; we may split the round
   retroactively.
4. **Run pytest on weather-dev before submitting for audit.** Both backends green
   via `pytest -m integration` against MariaDB and SQLite profiles. Pre-existing
   skipped test (`test_mariadb_writable_seed_user_probe_exits_nonzero`) stays
   skipped; not a regression.
5. **Parallel-pull-then-pytest.** Carry-forward from 3a-1 round 1's lesson:
   `git fetch origin master && git merge --ff-only origin/master` BEFORE the
   pre-submit pytest run, so api-dev's suite covers test-author's latest. Hard
   gate, not courtesy.
6. **Auditor reviews after both api-dev and test-author submit + green pytest.**
   Lead synthesizes findings and routes back to the relevant agent. Don't
   auto-loop. Lead picks remediation per finding (don't forward the auditor's
   raw list).

---

## Anti-patterns (don't)

- Don't add new provider plugin modules (3b owns those).
- Don't reach for `timezonefinder`, `pytz`, `dateutil`, or any markdown library —
  STOP and ping the lead if you think you need one. Stdlib `zoneinfo` + `datetime`
  + `re` cover what 3a-2 needs.
- Don't sanitize markdown server-side — that's dashboard's job per
  security-baseline §5.
- Don't pre-convert altitude to meters silently. The units block IS authoritative
  per ADR-019; the OpenAPI description is contract-typo and gets a follow-up fix.
- Don't introduce per-endpoint caching (ADR-017 covers provider responses, not
  local compute).
- Don't bypass `get_db_session()` for the /station MIN/MAX query.
- Don't read content files per request beyond the 1 MiB stat-then-read pattern
  (defense against malformed-large files).
- Don't infer ephemeris paths from a request param — config-only.
- Don't catch `Exception:`. Catch the specific class. (`rules/coding.md` §3)
- Don't hold across turns. Write to a file as you go (`rules/clearskies-process.md`).
- Don't write provider-domain code (no /forecast, /alerts, /aqi/*, /earthquakes,
  /radar/* in this round).
- Don't add operator column-mapping UI (Phase 4 per ADR-027).
- Don't add features beyond this brief. "Simple means simple."

---

## Reporting back

When you're done, report to the lead:

- Files touched (relative paths + LOC).
- ADRs and rules that governed each substantive choice.
- Pytest counts: total / unit / integration / passes / failures, both backends.
- Any ADR or contract conflicts surfaced (and the call you made / question you
  raised). The /station altitude units conflict is already lead-flagged — note
  that you treated it per the brief rather than re-deriving.
- Skyfield ephemeris-load behavior on `weather-dev` (size on disk, time-to-load,
  whether the `de421.bsp` was already cached or downloaded fresh).
- Any deviation from this brief (and why).
- Anything that surprised you in the existing task 1 / 2 / 3a-1 code.
- Phase-name 8-bin mapping you actually shipped (so it can be sanity-checked
  against published moon-phase tables in audit).

---

## Out of scope, parking lot for follow-ups

- **Altitude-units contract typo** — OpenAPI line 1207 says altitude is "Meters
  above mean sea level" but ADR-019 + canonical-data-model §3.9 make the units
  block authoritative (group_altitude). Fix the OpenAPI description in a separate
  follow-up commit (lead-owned, post-3a-2 close).
- **Operator-defined custom pages** — Phase 4 owns the config UI; api.conf shape
  for custom pages is undecided. 3a-2 returns built-ins only.
- **Operator-defined custom chart groups** — same deferral. Phase 4 owns the
  config UI.
- **Per-built-in-page hide UI** — 3a-2 uses a manual `[pages] hidden = ...` config
  line; the configuration UI in Phase 4 will turn this into checkboxes.
- **TZ derivation from lat/lon** — `timezonefinder` is Phase 4 setup-wizard
  scope per ADR-020 §Consequences. 3a-2 uses the 3-tier fallback (api.conf →
  weewx.conf → OS TZ → UTC + WARN).
- **Twilight-definition operator override** — ADR-014 out-of-scope says civil is
  the default; not operator-configurable at v0.1.
- **Skyfield ephemeris pre-bundling vs lazy-download** — Q2 lead-resolves to lazy-
  download with cache. If install-time UX feedback later pushes for bundled, that's
  a follow-up.
- **`_GROUP_MEMBERS` parity test against canonical-data-model §2.1** — still open
  from 3a-1; not scoped into 3a-2 unless the implementer hits it organically.
- **Reload-on-config-change for weewx.conf** — restart-to-pick-up is acceptable
  at v0.1 (3a-1 lesson); same applies to /station's weewx.conf reads.
