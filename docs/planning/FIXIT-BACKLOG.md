# Fixit Backlog

Running list of issues found during manual testing. Items marked with a plan reference have been rolled into a formal fixit plan.

**Plans:**
- [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) — mobile responsive fixes, UI polish, wizard UX (FIX-001, FIX-009, FIX-010, FIX-012–027)
- [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md) — architecture/API/BFF changes (FIX-003–008, FIX-011)

## Open

### FIX-001: Wizard checkbox and prompt text fails WCAG contrast

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T4.1
- **Found:** 2026-06-11
- **Location:** Setup wizard — checkbox labels and prompt text, especially the EULA step
- **Severity:** Accessibility (WCAG AA contrast)
- **Description:** The checkbox and surrounding prompt text in the wizard is hard to read — likely fails WCAG 2.1 AA minimum contrast ratio (4.5:1 for normal text, 3:1 for large text). The EULA step is the worst offender but the issue likely applies to all wizard checkboxes/prompts.
- **Expected:** All text and interactive controls meet WCAG AA contrast ratios against their background.

### FIX-002: Wizard header — add logo, right-justify remaining text

- **Found:** 2026-06-11
- **Location:** Setup wizard header ([layout.html](../../repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/layout.html))
- **Severity:** Cosmetic / branding
- **Description:** Header needed the Clear Skies white logo (not the "powered" variant) on the left, "Clear Skies" text removed, remaining "Setup Wizard" text right-justified, logo sized to match text height.
- **Status:** FIXED — white logo SVG created at `static/clearskies-logo-white.svg`, header updated with flex layout.

### FIX-003: AQI system assumes EPA scale only — needs multi-jurisdiction support

- **Plan:** [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md) tasks T1.4, T4A.1–T4A.6, T4B.1–T4B.2, T4C.1–T4C.2
- **Found:** 2026-06-11
- **Severity:** Functional / internationalization (HIGH)
- **Description:** The current AQI implementation hardcodes EPA (US) assumptions. LC16 dropped NO and NH3 because they have "no EPA AQI band," but other jurisdictions band those pollutants (EU CAQI includes NO, India NAQI bands NH3). The system needs to support multiple AQI scales and let the operator choose which one applies to their jurisdiction, with the ability to override the auto-suggested default. This is not just a missing pollutant — it's a structural gap.
- **Scope — touches multiple components:**
  - **ADRs:** LC16 needs amendment; may need a new ADR for multi-scale AQI architecture
  - **Canonical schema (API):** `AQIReading` must carry all pollutants providers supply (NO, NH3, etc.) regardless of which scale is active — don't drop data at ingestion, let the display layer decide relevance
  - **Provider translation:** Stop dropping NO/NH3 in OWM and other providers; pass through all available concentrations
  - **Wizard:** Operator selects their preferred AQI scale (EPA, CAQI, NAQI, AQHI, MEP, etc.); system suggests based on configured location; operator can override
  - **Dashboard AQI card:** Render AQI value and category using the operator's chosen scale and its breakpoints, show the pollutants relevant to that scale
  - **Wizard column mapping:** `ow_no` → canonical NO field should be valid once the schema carries it
- **AQI scales to support (minimum):**
  - EPA AQI (US) — PM2.5, PM10, O3, NO2, SO2, CO
  - CAQI (EU) — PM2.5, PM10, O3, NO2, NO, SO2, CO
  - NAQI (India) — PM2.5, PM10, O3, NO2, SO2, CO, NH3
  - AQHI (Canada) — different calculation method (rolling 3hr avg of O3, NO2, PM2.5)
  - MEP AQI (China) — PM2.5, PM10, O3, NO2, SO2, CO (different breakpoints from EPA)
- **Key principle:** The AQI scale governs *color banding and categorization*, not *visibility*. All pollutants the provider supplies are always available for display regardless of scale. A US EPA operator who wants to show NO sees the raw concentration — it just won't have color-coded AQI banding because EPA doesn't define breakpoints for it. Unbanded pollutants render as neutral/uncolored values, not hidden ones.
- **Expected:** Operator can select or confirm an AQI scale during setup; the API preserves all provider-supplied pollutant concentrations; the dashboard always shows available pollutants, applying color banding only to those covered by the operator's chosen scale.

### FIX-004: AQI card does not expand to show pollutant detail from mapped weewx columns

- **Plan:** [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md) tasks T4B.3, T4C.2
- **Found:** 2026-06-11
- **Severity:** Functional (HIGH)
- **Description:** The AQI card only shows expanded pollutant detail if the primary AQI provider supplies it. But the data can come from multiple sources — e.g. IQAir provides the headline AQI index but no per-pollutant breakdown, while the operator's weewx database has OWM air pollution data (NO2, O3, PM2.5, CO, etc.) via a weewx plugin with columns mapped in the wizard. The card should detect that pollutant concentration fields have values in the canonical response (regardless of which source populated them) and render the expanded view accordingly.
- **Key principle:** The UI and API are provider-agnostic. The AQI card should never ask "which provider gave me this" — it should ask "do I have pollutant concentration values?" If yes, show them. The data may come from the AQI provider, from weewx-mapped DB columns, or from a mix of both. Mapped columns are a first-class data source, not a fallback.
- **Scope:**
  - **API:** The canonical AQI response must merge pollutant data from all available sources (provider API response + weewx-mapped DB columns). If IQAir gives AQI=52 with no pollutants, but mapped columns have PM2.5=12.3 and O3=45.0, the response should include both the AQI and the pollutant values.
  - **Dashboard AQI card:** Expand/detail view should render whenever any pollutant concentration fields are non-null, not only when the primary AQI provider supplied them.
- **Expected:** An operator using IQAir for headline AQI + weewx OWM plugin for pollutant detail sees both the AQI summary and the expanded pollutant breakdown on the same card.

### FIX-005: API must co-locate with weewx — Python-to-Python access to weewx metadata

- **Plan:** [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md) tasks T1.1, T2.1–T2.8
- **Found:** 2026-06-11
- **Severity:** Architecture (HIGH — hard deployment constraint)
- **Description:** The Clear Skies API reads the weewx database directly for observation data, which is the right call — weewx has no REST API, no HTTP query interface, nothing to "talk to." It's a collector daemon that writes to a DB and generates static reports. The API exists precisely because weewx doesn't offer what we need (REST endpoints, real-time SSE, provider aggregation, multi-source merging).

  However, weewx holds critical **metadata** that never touches the database and only lives in its Python runtime:

  - **`weewx.units.obs_group_dict`** — maps every observation type (including extension-added ones) to a unit group (e.g. `group_concentration`, `group_fraction`, `group_temperature`). This is how weewx knows what unit a column's data is in.
  - **Unit system dictionaries** (`USUnits`, `MetricUnits`, `MetricWXUnits`) — map unit groups to specific units in each system.
  - **Extension-registered observation types** — well-behaved plugins register their custom columns in `obs_group_dict` at import time (e.g. `weewx.units.obs_group_dict['ow_pm25'] = 'group_concentration'`). This is convention, not enforced (see weewx issue #613), but most plugins do it.
  - **xtypes** — derived/calculated observation types that exist only in weewx's computation engine, never in the DB. If we ever want to expose these, we need weewx's Python.

  Currently the API has **zero access** to any of this. It reads raw DB values and hopes the units are what it expects. This works by coincidence for the OWM weewx plugin (stores µg/m³, which matches what OWM providers send), but it's not a guarantee.

- **The constraint:** The Clear Skies API MUST run on the same host as weewx and MUST have weewx importable in its Python environment. This is a hard architectural requirement, not a nice-to-have. It enables Python-to-Python access to weewx's runtime metadata.

- **What this enables:**
  - **Wizard column mapping with unit auto-detection:** At setup time, `import weewx.units; weewx.units.obs_group_dict.get('ow_pm25')` → `'group_concentration'` → we know it's µg/m³. Auto-suggest the unit, have the operator confirm.
  - **Unit validation for mapped columns:** If a plugin registered its column properly, we can verify the unit at read time, not just trust it blindly.
  - **Fallback for undeclared columns:** If a column isn't in `obs_group_dict` (sloppy plugin), the wizard prompts the operator to declare the unit manually. We help with a guess based on column name patterns.
  - **Future: xtypes support** — derived observations (windchill, heatindex, dewpoint, etc.) could be computed by calling into weewx's xtypes engine rather than re-implementing the math.

- **How Belchertown does it for comparison:** Belchertown doesn't have this problem because it runs *inside* weewx as a skin + SearchList extension (`bin/user/belchertown.py` extends `weewx.cheetahgenerator.SearchList`). It has full in-process access to `weewx.units`, `weewx.tags`, the DB manager — everything. Real-time data goes through MQTT (weewx publishes loop packets to a broker, browser connects via WebSockets). Clear Skies intentionally diverged from this model — we're an independent application, not a weewx skin — but the cost is we need to solve metadata access ourselves. Co-location + Python import is the bridge.

- **What weewx's unit system looks like (for reference when planning):**
  ```
  # How a well-behaved plugin registers units:
  weewx.units.obs_group_dict['ow_pm25'] = 'group_concentration'
  weewx.units.obs_group_dict['ow_no2'] = 'group_concentration'
  weewx.units.obs_group_dict['ow_aqi'] = 'group_count'  # unitless index

  # Unit groups → specific units per system:
  weewx.units.USUnits['group_concentration'] = 'microgram_per_meter_cubed'
  weewx.units.MetricUnits['group_concentration'] = 'microgram_per_meter_cubed'

  # Reading it at runtime:
  unit_group = weewx.units.obs_group_dict.get('ow_pm25')  # → 'group_concentration' or None
  ```

- **Tiered unit resolution strategy (proposed for wizard column mapping):**
  1. **Auto-detect from weewx:** Import `weewx.units`, read `obs_group_dict` for each mapped column. If declared, auto-fill the unit.
  2. **Heuristic fallback:** For undeclared columns, guess based on known extension patterns (e.g. `ow_*` columns from the OWM plugin are µg/m³ for pollutants).
  3. **Operator confirmation:** Present all auto-detected and guessed units for review. Operator confirms or overrides each one. Even auto-detected units get a confirmation step — we can't guarantee the plugin author got it right.
  4. **Store in our config:** Save the confirmed unit metadata in Clear Skies' own configuration, so we don't need to re-query weewx on every read — just at setup/reconfiguration time.

- **Relates to:** FIX-003 (multi-jurisdiction AQI — unit handling is part of the same problem), FIX-004 (multi-source AQI — mapped columns need correct units to merge with provider data)

- **ADR impact:** Needs a new ADR establishing the co-location constraint and the Python-to-Python metadata access pattern. May also need to amend existing ADRs that implicitly assume the API is a standalone service with no weewx dependency beyond DB access.

- **Current stack topology:** The docker-compose already puts weewx and the API in close proximity, but weewx importability in the API's Python environment is not guaranteed. This needs to be an explicit requirement in the stack design, not an accident.

### FIX-006: Architectural shift — the Clear Skies API IS the weewx application layer

- **Plan:** [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md) task T1.2
- **Found:** 2026-06-11
- **Severity:** Architecture (FUNDAMENTAL — reframes the entire API's purpose and scope)
- **Description:** Through the process of building Clear Skies, we've been adding API capabilities piecemeal — a derived calculation here, a unit conversion there, an aggregation when the dashboard needed it. But stepping back, the pattern is clear: **the Clear Skies API is becoming the application layer that weewx never built.**

  weewx is excellent at one thing: ingesting hardware data and writing it to a database. Everything above that — unit conversion, derived calculations, aggregations, real-time delivery, time-bounded queries, multi-source data merging — weewx only exposes to *skins running in its own process* via Python objects and Cheetah template tags. There is no external API. There is no HTTP interface. There is no way for an external application to access these capabilities.

  We've been treating our API as "the Clear Skies backend" — a BFF for our dashboard that also talks to weather providers. But what we're actually building is **the weewx API that weewx never shipped.** It's not a weewx skin. It's not a weewx extension. It's the API that the entire weewx ecosystem has been missing — one that any frontend, any integration, any automation could talk to.

  This reframing matters because it changes the API's scope and completeness bar. We're not just building "enough API for our dashboard." We're building the canonical programmatic interface to a weewx station's data and capabilities. That means it needs to encapsulate **everything weewx currently provides to skins**, PLUS the external provider aggregation and multi-source merging that weewx never did.

- **What weewx provides to skins (the capability surface we need to match):**

  **Derived observations (xtypes):**
  - windchill, heatindex, dewpoint, appTemp (apparent temperature), humidex
  - ET (evapotranspiration), pressure reductions (altimeter, barometer, SLP)
  - beaufort wind scale, wind run
  - weewx calculates these on the fly if they're not stored in the DB — a skin never has to wonder "is dewpoint in the archive?" because xtypes will compute it from temperature + humidity

  **Aggregation system:**
  - min / max / avg / sum / count / first / last over arbitrary timespans
  - weighted averages (for wind direction, etc.)
  - cumulative rain, rain rate peaks
  - growing degree days, heating/cooling degree days
  - mintime / maxtime (timestamps of extremes)
  - gustdir (direction at time of max gust)

  **Time-bounded queries (the "tag" system):**
  - `$current` — latest archive record
  - `$latest` — latest value (may be from LOOP packet, more recent than archive)
  - `$day` / `$week` / `$month` / `$year` — aggregations over calendar periods
  - `$span($time_delta=N)` — rolling window aggregations (e.g. last 3 hours)
  - `$yesterday`, `$day($days_ago=N)` — relative day queries
  - Trend calculations: `$trend.outTemp` (change over configured trend period)
  - All of these automatically handle archive boundaries, DST transitions, and timezone

  **Unit system:**
  - Full `obs_group_dict` → unit group → target unit pipeline
  - Automatic conversion at query time based on configured target unit system
  - Per-observation formatting (decimal places, labels)
  - Three built-in systems (US, Metric, MetricWX) plus extensibility
  - This is what FIX-005 partially addresses, but the scope is broader — we need the full conversion pipeline, not just reading obs_group_dict

  **Record generation:**
  - StdWXCalculate service: fills in derived obs that hardware didn't provide
  - Accumulator system: aggregates LOOP packets into archive records
  - Quality control: bounds checking, spike detection

  **Database utilities:**
  - Schema introspection
  - Backfill / recalculation
  - Daily summary tables (pre-aggregated min/max/sum/count per day for fast queries)

- **What Clear Skies adds BEYOND weewx (the "PLUS"):**
  - External provider aggregation (forecast, AQI, alerts, radar from multiple providers)
  - Multi-source data merging (provider API + weewx DB columns on the same canonical response)
  - Multi-jurisdiction AQI with operator-selected scales (FIX-003)
  - Real-time SSE without requiring operator to set up MQTT
  - RESTful HTTP interface (the thing weewx never built)
  - Proper OpenAPI contract with typed responses
  - Caching, rate limiting, credential management for external providers
  - Branding, legal/EULA, operator configuration via wizard

- **Gap analysis needed:** We need to systematically catalog which of the above weewx capabilities our API already covers, which are partially covered, and which are completely missing. The piecemeal approach has gotten us this far, but this reframing means we need completeness — not "add it when the dashboard needs it" but "the API should offer it because a weewx station's programmatic interface should offer it."

- **What this is NOT:**
  - We are NOT rewriting weewx's ingestion layer (hardware drivers, LOOP/archive collection). That stays weewx's job. The user has noted interest in eventually rewriting ingestion, but explicitly NOT in this project.
  - We are NOT making weewx a dependency we want to eliminate. weewx remains the data collector. We're building the application/query layer on top of it.
  - We are NOT trying to be backwards-compatible with weewx's Cheetah tag syntax. Our interface is REST/JSON, not template tags. But the *capabilities* should be equivalent or better.

- **ADR impact:**
  - Needs a new ADR that reframes the API's architectural role: not "Clear Skies backend" but "the weewx application-layer API"
  - Existing ADRs that scope the API narrowly to "what the dashboard needs" may need amendment
  - The gap analysis becomes a planning input for future phases
  - Relates to FIX-005 (co-location constraint — same reasoning, broader scope)

- **Relates to:** FIX-003 (AQI multi-jurisdiction — example of a capability gap), FIX-004 (multi-source merging — a "PLUS" capability), FIX-005 (co-location — the deployment constraint that enables this), FIX-007 (realtime folded into API)

### FIX-007: Fold realtime service into the API — eliminate MQTT, Unix socket, and separate process

- **Plan:** [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md) tasks T1.3, T3A.1–T3D.6
- **Found:** 2026-06-11
- **Severity:** Architecture (HIGH — simplifies topology, follows from FIX-005 and FIX-006)
- **Description:** Currently, real-time loop packet delivery is handled by a **separate service** (`weewx-clearskies-realtime`) with two adapter paths:

  1. **Direct mode:** A weewx extension (`ClearSkiesLoopRelay`) hooks `NEW_LOOP_PACKET`, serializes to JSON, and writes to a Unix domain socket. The realtime service connects to that socket, enriches the data, and serves SSE to the dashboard.
  2. **MQTT mode:** weewx publishes loop packets to an MQTT broker. The realtime service subscribes, enriches, and serves SSE.

  Given FIX-005 (API co-locates with weewx) and FIX-006 (API is the weewx application layer), there's no reason for any of this indirection. The API should hook `NEW_LOOP_PACKET` directly and serve real-time data itself. One process, one service, one HTTP endpoint for everything.

- **How weewx station data flows today (for context):**
  ```
  Weather station hardware (Davis, Tempest, Ecowitt, etc.)
        ↓
  weewx DRIVER (serial, USB, or network — hardware-specific)
        ↓
  LOOP PACKETS (raw observations, every 2-10 seconds)
        ↓
  weewx SERVICE CHAIN (StdConvert → StdCalibrate → StdQC → StdWXCalculate)
        ↓
  NEW_LOOP_PACKET event (this is the hook point — MQTT, our relay, etc. all tap here)
        ↓
  Every ~5 min: LOOP packets accumulated → ARCHIVE RECORD → written to DB
  ```

  MQTT is not special in this flow — it's just another weewx service extension that hooks `NEW_LOOP_PACKET` and publishes somewhere. Our `ClearSkiesLoopRelay` hooks the exact same event. They're peers. The only reason MQTT exists in the weewx ecosystem is that weewx never built an API, so MQTT became the de facto way to get real-time data out. We're building that API.

- **Target architecture:**
  ```
  Weather station hardware
        ↓ (driver)
      weewx (ingestion + service chain)
        ↓ (NEW_LOOP_PACKET → Clear Skies weewx extension, in-process)
    Clear Skies API (single service, co-located with weewx)
        ├── REST  (pull — historical queries, aggregations, provider data, unit conversion)
        └── SSE   (push — real-time loop packets, enriched)
        ↑
    Dashboard / any consumer (anywhere, talks to API over HTTP)
  ```

  The API is a **push/pull** service. REST for everything queryable (historical data, forecasts, AQI, config, branding). SSE for everything real-time (loop packets, alerts). One URL, one service, one thing to deploy next to weewx.

- **What goes away:**
  - `weewx-clearskies-realtime` as a separate deployable service
  - The Unix domain socket relay (`/var/run/weewx-clearskies/loop.sock`)
  - The `ClearSkiesLoopRelay` weewx extension (replaced by a new extension that feeds the API directly)
  - The MQTT adapter and `paho-mqtt` dependency
  - The DirectAdapter (Unix socket client)
  - The operator's need to set up an MQTT broker for real-time data

- **What moves into the API:**
  - SSE endpoint (already partially there? needs verification)
  - Loop packet enrichment (wind rolling window, sky condition, UV smoothing, lightning buffer, scene enrichment — all currently in the realtime service)
  - The weewx extension, rewritten to push directly into the API process rather than through a socket

- **MQTT is eliminated from Clear Skies.** This is a firm decision, not a maybe. There is no reason to maintain two communication paths when the API already exists. MQTT added complexity (broker setup, credentials, topic config, client libraries) to solve a problem that only existed because weewx never had an API. We built the API. The problem is solved.

  If an operator wants MQTT for other consumers (legacy Home Assistant setup, Node-RED, etc.), that's weewx's own MQTT extension — not our concern. But even then: why not just subscribe to our API? SSE is just an HTTP GET that stays open. Every language has an HTTP client. The barrier is lower than MQTT.

- **The API as the single authoritative data source:** This is the key architectural principle. Anything that wants weather data — the Clear Skies dashboard, Home Assistant, Node-RED, custom scripts, mobile apps, other skins — talks to the API. One source for everything:
  - Real-time station observations (SSE — push)
  - Historical station data (REST — pull)
  - Derived calculations (REST)
  - External provider data — forecasts, AQI, alerts, radar (REST)
  - Unit conversion, aggregations, time-bounded queries (REST)
  - Configuration, branding, station metadata (REST)

  This ensures **data integrity** — there's no scenario where Consumer A gets different data than Consumer B because one reads the DB directly and the other reads MQTT. Everything goes through the same pipeline, same enrichment, same unit conversion.

- **Future: Home Assistant integration.** An HA custom integration that queries the Clear Skies API is the obvious next project. It would give HA users access to all weather data (station + providers) from one integration instead of needing separate integrations for weewx, OWM, IQAir, etc. This is explicitly NOT in scope for the current project, but the API-as-single-source architecture makes it trivial when the time comes.

- **Open questions:**
  - How does the weewx extension communicate with the API process? If they're in the same Python environment (per FIX-005), could the API register as a weewx service directly? Or does there need to be a lightweight IPC mechanism (shared queue, pipe)?
  - The realtime service currently does significant enrichment (derived wind stats, sky condition classification, UV smoothing, scene selection). This logic needs to move into the API. Is it a clean lift, or does it have assumptions about being a standalone asyncio service?
  - Does the API's web framework (FastAPI/uvicorn) coexist cleanly with weewx's engine loop, or do they need to be separate processes with in-process communication?

- **Relates to:** FIX-005 (co-location — prerequisite), FIX-006 (API as application layer — this is the real-time half of that vision)

- **ADR impact:**
  - ADR-005 (realtime architecture) needs major amendment or superseding
  - The five-component breakdown (api / realtime / dashboard / stack / design-tokens) becomes four — realtime merges into api
  - Stack topology ADRs need amendment (fewer containers, simpler compose)
  - The "API-only" communication principle needs its own ADR — everything talks to the API, nothing bypasses it

### FIX-008: Security audit — API as gateway to weewx host, not a door into it

- **Plan:** [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md) tasks T1.5, T5A.1–T5A.6, T5B.4–T5B.5
- **Found:** 2026-06-11
- **Severity:** Security (CRITICAL — directly follows from FIX-005/006/007 co-location decision)
- **Description:** The architectural decisions in FIX-005 through FIX-007 place the Clear Skies API on the same host as weewx, with Python-level access to weewx internals and the station database. This is the right call for functionality, but it dramatically raises the security stakes. The API is now an internet-facing HTTP service running on a machine that also has:
  - Direct access to the weewx database (read/write)
  - Python-level import access to weewx (obs_group_dict, xtypes, engine internals)
  - The weewx process itself (which talks to station hardware)
  - Potentially other services on the same host (depending on operator's setup)
  - Operator credentials for external providers (OWM, IQAir, Aeris API keys)
  - The Clear Skies configuration (wizard state, branding, EULA acceptance)

  **The API must be a gateway to data, not a door into the host.** A vulnerability in the API should not give an attacker a shell, access to the filesystem, ability to modify weewx config, or pivot to other services on the machine.

- **Attack surfaces to audit and mitigate:**

  **Input validation / injection:**
  - All REST endpoints: query params, path params, request bodies — fuzz and verify
  - Column mapping names (operator-provided during wizard) — these become SQL column references; are they parameterized or string-interpolated?
  - SSE subscription params — can a malicious client craft a request that causes unbounded resource consumption?
  - File upload paths (logo upload in branding step) — path traversal, symlink attacks, MIME type validation
  - Any endpoint that accepts time ranges, observation type names, or filter expressions — can these be used to construct injection attacks against the DB layer?

  **Authentication and authorization:**
  - What endpoints are public vs. require auth? Weather data may be intentionally public, but wizard/config/admin endpoints must not be
  - Is there an admin boundary? The wizard can modify configuration, restart services — this needs strong auth
  - API key management for external providers — are credentials ever exposed through API responses?
  - SSE connections — is there rate limiting? Can an attacker open thousands of SSE connections and exhaust server resources?

  **Process isolation:**
  - If the API runs in the same Python process as weewx (or has import access), what prevents a code execution vulnerability from reaching weewx internals?
  - Should the API run as a separate OS user with minimal filesystem permissions?
  - Can we use OS-level controls (seccomp, AppArmor, filesystem ACLs) to limit what the API process can touch even if compromised?
  - Docker/container boundaries — if running in containers, is the API container properly isolated? No privileged mode, no host network unless required, read-only filesystem where possible?

  **Network exposure:**
  - Which ports are exposed to the internet vs. only localhost/LAN?
  - Is TLS terminated at the API, at a reverse proxy (Caddy), or not at all?
  - Should the API bind to 127.0.0.1 by default and require explicit configuration to bind to 0.0.0.0?
  - CORS policy — is it locked down to the dashboard origin, or wide open?

  **Dependency supply chain:**
  - FastAPI, uvicorn, Pydantic, SQLAlchemy, httpx, and all transitive deps — are we auditing for known CVEs?
  - Is there a `pip-audit` or similar in CI?
  - Are dependencies pinned with hashes?

  **Data exposure:**
  - API error responses — do stack traces, file paths, or internal state leak in error messages?
  - Debug mode — is there any risk of FastAPI's debug/reload mode being enabled in production?
  - Database path — is the SQLite file path exposed anywhere in responses?
  - Operator config — does any endpoint expose the full config including credentials?

  **Denial of service:**
  - Expensive queries — can a client request an aggregation over the entire archive history and pin the CPU?
  - SSE fan-out — what's the max concurrent SSE connection count? Is there backpressure?
  - Request rate limiting — is there any, or is the API wide open to abuse?
  - Large response attacks — can a crafted request produce a multi-GB response?

  **The weewx-specific risks (unique to our co-location):**
  - Can the API be used to modify weewx.conf or other weewx configuration files?
  - Can the API be used to restart or stop weewx?
  - Can the API be used to execute arbitrary Python through the weewx import path?
  - Can the API be used to interact with station hardware (through weewx drivers)?
  - If the API has write access to the weewx DB, can an attacker corrupt historical data?

- **Existing security measures to verify:**
  - We already have `dep-audit.yml` in CI (GitHub Actions) — verify it covers all repos
  - We already have `gitleaks.yml` for secret scanning — verify coverage
  - Check what the existing SECURITY.md files specify and whether reality matches

- **Proposed mitigations (to be refined during planning):**
  - **Principle of least privilege:** API process runs as a dedicated non-root user with read-only access to the weewx DB, read-only access to weewx Python packages, and write access only to its own config/state directory
  - **Reverse proxy mandatory:** API binds to localhost only; Caddy (or similar) handles TLS termination, rate limiting, and external exposure. The API is never directly internet-facing.
  - **Admin boundary:** Wizard and configuration endpoints require authentication (shared secret, token, or mTLS); weather data endpoints can be public per operator choice
  - **Input sanitization:** All DB queries parameterized (verify — no string interpolation anywhere); all file paths validated against allowlist; all user input bounded in length and character set
  - **Query cost limits:** Max time range per query, max result set size, query timeout at the DB layer
  - **SSE connection limits:** Max concurrent connections per client IP, backpressure on slow consumers, idle timeout
  - **Error sanitization:** Production error responses return generic messages; no stack traces, file paths, or internal state
  - **Read-only filesystem:** Container runs with read-only root filesystem, tmpfs for /tmp, explicit volume mounts only for required writable paths
  - **Network policy:** If in Docker, explicit network isolation — API container can reach weewx DB and the internet (for providers), nothing else

- **Relates to:** FIX-005 (co-location creates the risk), FIX-006 (API scope expansion increases attack surface), FIX-007 (SSE consolidation means one service to secure, not two)

- **Caddy / reverse proxy layer is part of this audit:**
  - Caddy sits between the public internet and the API — it's the actual front door. If Caddy is misconfigured, none of the API-level mitigations matter.
  - TLS configuration — are we enforcing modern TLS (1.2+ minimum)? HSTS headers?
  - Path-based routing — does Caddy expose only the intended API paths, or does it proxy everything blindly?
  - Admin endpoints — does Caddy block public access to wizard/config routes, or does it rely on the API to enforce auth? (Defense in depth: both should enforce it.)
  - Static asset serving — the dashboard is static files served by Caddy. Can path traversal in asset requests reach outside the served directory?
  - Request size limits — does Caddy enforce max request body size before it reaches the API?
  - WebSocket/SSE — does the proxy properly handle long-lived SSE connections? Timeout behavior, max connection count at the proxy level?
  - Headers — is Caddy adding security headers (X-Content-Type-Options, X-Frame-Options, CSP, Referrer-Policy)?
  - Logging — does Caddy log enough to detect and investigate attacks, but not so much that it captures sensitive data?

- **ADR impact:** Needs a security ADR that establishes the threat model, the trust boundaries (internet → Caddy → API → weewx, with each layer enforcing its own constraints), and the mandatory mitigations. Existing security-related ADRs need review against the new co-location architecture.

### FIX-009: Wizard "Appearance" step is overloaded — split into focused steps

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T4.2
- **Found:** 2026-06-11
- **Severity:** UX (MEDIUM)
- **Location:** [step_appearance.html](../../repos/weewx-clearskies-stack/weewx_clearskies_config/templates/wizard/step_appearance.html) — currently step 11 of 12
- **Description:** Step 11 ("Appearance") crams five unrelated concerns into one page:
  1. **Branding** — site title, copyright entity, logos (light + dark, each with file upload + URL), favicon (file upload + URL), logo alt text, accent color, theme mode, custom CSS URL
  2. **Social Media** — Facebook, Twitter/X, Instagram, YouTube URLs
  3. **Analytics** — Google Analytics measurement ID
  4. **Privacy & Legal** — visitor region checkboxes (7 options), custom Terms of Use (full markdown textarea), custom Privacy Policy (full markdown textarea)
  5. **Seismic Page Settings** — earthquake radius, min magnitude, time period

  The page is long, busy, and mixes very different decisions. An operator configuring their logo colors shouldn't have to scroll past markdown legal editors. The two large textareas for custom legal content dominate the page. The hierarchy is flat — every fieldset looks the same, there's no visual grouping that helps the operator understand "these are appearance decisions, these are legal decisions."

- **Proposed split (3 steps replacing 1):**

  **Step A: Appearance & Branding**
  - Site title, copyright entity
  - Logos (light/dark), favicon, logo alt text
  - Accent color, theme mode, custom CSS URL
  - Social media links
  - This is the "how your site looks" step

  **Step B: Privacy, Legal & Analytics**
  - Google Analytics measurement ID (because it triggers cookie consent — it's a privacy decision, not an appearance one)
  - Visitor region selection (determines which privacy laws apply)
  - Custom Terms of Use (markdown)
  - Custom Privacy Policy (markdown)
  - This is the "legal and data collection" step

  **Step C: Feature Settings**
  - Seismic page settings (earthquake radius, magnitude, time period)
  - This could also absorb other per-feature configuration as we add it
  - OR: seismic settings could fold into a future "Pages & Features" step where the operator enables/disables optional dashboard pages

- **Legal content override UX is problematic:**
  - **Unclear behavior:** The current label says "replaces the default content" but it's ambiguous whether it replaces the ENTIRE legal page or just the section (Terms / Privacy). The operator shouldn't have to guess.
  - **Markdown is a bad assumption:** Most operators running a weather station are not developers and don't know markdown. Asking them to write legal text in markdown is a high barrier.
  - **Proposed: file upload instead of textarea.** Replace the markdown textareas with a file upload that accepts multiple formats:
    - HTML (.html) — rendered as-is
    - Markdown (.md) — converted to HTML on our side
    - Plain text (.txt) — wrapped in appropriate HTML formatting
    - RTF (.rtf) — converted to HTML on our side
    - The wizard detects the format from the file extension and handles conversion
  - **Clarify the override semantics:** Make it explicit — "Upload your own Terms of Use to replace the default. If you don't upload anything, Clear Skies provides a standard template based on your visitor regions selected above." Same for Privacy Policy.
  - **Preview:** After upload, show a rendered preview of what the legal page will look like so the operator can verify before proceeding.

- **Within each step, improve hierarchy:**
  - Use `<h3>` sub-headings within fieldsets, not just `<legend>` (which all look identical)
  - Group related fields visually (logos together with spacing between logo group and color/theme group)
  - Use progressive disclosure where possible (e.g. legal content override could be behind an expandable section — most operators will use the defaults)
  - Reduce help text density — currently every field has a `<small>` description, which makes the page wall-of-text-y. Consider tooltip or collapsible help for the obvious fields.

- **Step numbering impact:** Currently 12 steps. Splitting step 11 into 2-3 steps changes the total to 13-14. The progress bar and step routing need updating.

- **Relates to:** FIX-001 (WCAG contrast — while we're restructuring, fix the contrast issues too)

### FIX-010: Wizard Apply fails — permission denied writing branding.json

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T4.3
- **Found:** 2026-06-11
- **Severity:** Bug (HIGH — blocks wizard completion)
- **Location:** Step 12 (Review & Apply) — local config write path
- **Error:** `Local config write failed: [Errno 13] Permission denied: '/etc/weewx-clearskies/branding.json'. Fix the permissions and click Apply again.`
- **Description:** The API configuration saves to the remote API successfully, but the wizard process cannot write `branding.json` (and presumably other config files like `realtime.conf`, `stack.conf`, `secrets.env`) to `/etc/weewx-clearskies/` because the process doesn't have write permissions to that directory.
- **Two issues here:**
  1. **Permissions bug on dev instance:** The wizard process needs write access to `/etc/weewx-clearskies/`. Either the directory permissions need fixing, or the process is running as the wrong user. Needs investigation on the `weather-test` host.
  2. **UX issue — partial success is confusing:** The error says "API configuration saved successfully" then "Local config write failed" — this is a partial success state. The operator doesn't know what worked and what didn't, or whether they're in a broken half-configured state. The wizard should either:
     - Validate write permissions BEFORE attempting the apply (fail fast with a clear message)
     - Roll back the API config if the local write fails (atomic apply — all or nothing)
     - Or at minimum, clearly explain which parts succeeded and which failed, and what the operator needs to do to recover
- **Expected:** Apply either succeeds completely or fails completely with a clear, actionable error before any state changes.

### FIX-012: Current conditions card clips bottom chart on mobile

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T1.1
- **Found:** 2026-06-12
- **Location:** Dashboard — current conditions card, mobile viewport
- **Severity:** UI / responsive layout (MEDIUM)
- **Description:** On mobile viewports the current conditions card clips the bottom chart — the chart is cut off and not fully visible. The dashboard follows a uniform grid adherence rule for card sizing, but this is a case where the mobile view needs an exception. The current conditions card contains more content than a standard card (conditions summary plus an embedded chart), and forcing it into the same grid height as other cards truncates the chart rather than displaying it fully.
- **Proposed fix:** Allow the current conditions card to break out of the uniform grid height constraint on mobile breakpoints. The card should expand to fit its full content (summary + chart) rather than clipping. This could be a mobile-only CSS override (`min-height: auto` or similar) or a responsive grid rule that gives this card more vertical space on small screens.
- **Key principle:** Uniform grid is the default, but content legibility wins over layout consistency when they conflict on constrained viewports. A clipped chart is worse than a taller card.
- **Expected:** The bottom chart in the current conditions card is fully visible on mobile without clipping.

### FIX-013: Mobile footer layout — copyright and logo on one line, social icons centered below

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T2.7
- **Found:** 2026-06-12
- **Location:** Dashboard — footer, mobile viewport
- **Severity:** UI / responsive layout (LOW)
- **Description:** The mobile footer layout needs adjustment. Currently the copyright text, Clear Skies logo, and social media icons don't have a clean visual hierarchy on small screens.
- **Proposed layout (mobile):**
  - **Line 1:** Copyright text left-justified, Clear Skies logo right-justified — same line, using flex with `justify-content: space-between`.
  - **Line 2:** Social media icons center-justified below.
- **Expected:** Footer reads cleanly on mobile with copyright and branding on one line and social links grouped beneath.

### FIX-014: Radar map renders above the navigation bar on scroll

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T1.3
- **Found:** 2026-06-12
- **Location:** Dashboard — radar card (likely Leaflet map container)
- **Severity:** UI / z-index bug (HIGH)
- **Description:** When scrolling down the page, the radar map slides over (renders on top of) the navigation/menu bar. The map's container has a `z-index` that exceeds the nav bar's stacking context, so it paints above the sticky/fixed nav instead of scrolling behind it.
- **Proposed fix:** Ensure the nav bar's `z-index` is higher than the radar map container's. Leaflet maps and their tile/overlay panes use specific z-index values internally; the fix should set the radar card's containing element to a stacking context (`position: relative; z-index: <lower>`) rather than fighting Leaflet's internal pane z-indices. The nav bar must always be the topmost fixed element.
- **Expected:** The radar map scrolls behind the navigation bar, never overlapping it.

### FIX-015: Navigation bar disappears on non-home pages with no way to recover

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) tasks T0.3, T1.2
- **Found:** 2026-06-12
- **Location:** Dashboard — navigation/menu bar, all pages except (possibly) the home page
- **Severity:** Functional (CRITICAL — blocks navigation)
- **Description:** On most pages other than the home page, the navigation bar disappears entirely. Once it's gone, the user has no way to navigate to other pages — they're stranded. This is a site-breaking bug on mobile (no URL bar editing is practical) and severely degrades desktop usability.
- **Likely causes to investigate:**
  - **Scroll-triggered hide with no reveal:** If the nav uses a "hide on scroll down, show on scroll up" pattern, the reveal logic may be broken or not firing on certain pages.
  - **Page-specific layout issue:** Some pages may not include the nav component, or a layout wrapper may be missing/different from the home page.
  - **Intersection observer or scroll listener scoped to wrong element:** If the show/hide logic listens to scroll events on a specific container rather than the viewport, pages with different DOM structures may never fire the reveal event.
  - **CSS overflow on page container:** If a page's content container has `overflow: hidden` or `overflow: auto`, the nav may scroll out of view with no mechanism to bring it back.
- **Expected:** The navigation bar is always accessible on every page. If it hides on scroll-down, scroll-up must reliably reveal it. The user must never be unable to navigate.

### FIX-016: Page title/hero cards are oversized on mobile — mostly empty whitespace

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T1.1
- **Found:** 2026-06-12
- **Location:** Dashboard — page title cards on non-home pages (e.g. Forecast page), mobile viewport
- **Severity:** UI / responsive layout (MEDIUM)
- **Description:** On most pages other than the home page, the title/hero card (the card that shows the page icon and page name, e.g. the sun icon + "Forecast") renders at an excessive height on mobile. The card is mostly empty whitespace — just the icon and title text with a large blank area below. This wastes valuable screen real estate on mobile, pushing actual content (hourly forecast, 7-day forecast) further down the viewport.
- **Likely cause:** The title card may be using the same fixed height or `min-height` as content cards (uniform grid), or it may be sized to accommodate desktop layout content (subtitle, description) that isn't present on all pages. On mobile, the card should collapse to fit its actual content — an icon and a heading need one line, not half a screen.
- **Proposed fix:** Title/hero cards should size to their content on mobile breakpoints. If the card has no body content beyond the heading, it should render as a compact banner, not a full grid cell. This is related to FIX-012 (grid exceptions on mobile) — both are cases where the uniform grid height hurts more than it helps on small screens.
- **Expected:** Title cards on mobile are compact — just enough height for the icon, heading, and any subtitle. No large blank areas.

### FIX-017: Hourly forecast card — no visible scroll affordance on mobile

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T3.2
- **Found:** 2026-06-12
- **Location:** Dashboard — hourly forecast card, mobile viewport (Forecast page)
- **Severity:** UX (MEDIUM — feature is invisible)
- **Description:** The hourly forecast card supports horizontal scrolling to reveal more hours, but there is no visual indicator of this on mobile. The scrollbar is hidden (likely `scrollbar-width: none` or `::-webkit-scrollbar { display: none }`), and there's no other affordance (fade edge, arrow hint, partial next-item peek) to signal that more content exists to the right. Users will not discover they can swipe.
- **Proposed fix:** Add a scroll affordance — at minimum a subtle fade/gradient on the trailing edge when more content is available, or a partial peek of the next hour slot to imply continuity. A thin custom scrollbar track is another option. The affordance should disappear when the user has scrolled to the end.
- **Expected:** A user seeing the hourly forecast card for the first time understands immediately that they can scroll horizontally to see more hours.

### FIX-018: 7-Day forecast day names overlap on mobile — use 3-letter abbreviations

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T2.1
- **Found:** 2026-06-12
- **Location:** Dashboard — 7-day forecast card, mobile viewport (Forecast page)
- **Severity:** UI (HIGH — text is unreadable)
- **Description:** The 7-day forecast card renders full day names ("Saturday", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday") at the same size as desktop. On mobile, these names run together and overlap, making them unreadable — the screenshot shows "TodaSaturdaSundaMondaTuesdWednesdThursday" as a smeared mess.
- **Proposed fix:** On mobile breakpoints, switch to 3-letter day abbreviations ("Today", "Sat", "Sun", "Mon", "Tue", "Wed", "Thu"). "Today" can stay as-is since it's short and contextually important. The date line below (Jun 12, Jun 13, etc.) already fits — it's the day names that need truncation.
- **Expected:** All day names are fully legible on mobile with clear separation between columns.

### FIX-019: Forecast cards (hourly + 7-day) — vertical sizing clips or overflows content on mobile

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) tasks T1.1, T2.2
- **Found:** 2026-06-12
- **Location:** Dashboard — hourly forecast card and 7-day forecast card, mobile viewport (Forecast page)
- **Severity:** UI (HIGH — content not fully visible)
- **Description:** Both forecast cards have incorrect vertical sizing on mobile. Depending on the card, either:
  - Content is **clipped** — the card's height cuts off data at the bottom (temperatures, chart lines, low temps not visible), or
  - Content **overflows** the card boundary — data renders outside the card's visual container (border/background), overlapping adjacent elements.
  Both symptoms point to the same root cause: the card height is fixed or constrained to a value that doesn't match the actual content height on mobile. The hourly card has a temperature trend line that may extend below the visible area; the 7-day card has high/low temperatures and weather icons that overflow.
- **Proposed fix:** On mobile breakpoints, these cards need `height: auto` or `min-height` instead of a fixed height, allowing the card to expand to fit its content. If a max-height with scroll is preferred for the 7-day card (to avoid an extremely tall card with 7 days of detail), it needs the same scroll affordance as FIX-017. This is another instance of the uniform grid exception established in FIX-012.
- **Relates to:** FIX-012 (grid height exception on mobile), FIX-017 (scroll affordance)
- **Expected:** All content in both forecast cards is fully visible within card boundaries on mobile — no clipping, no overflow.

### FIX-020: Charts page — mobile layout overhaul

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) tasks T2.3, T3.1
- **Found:** 2026-06-12
- **Location:** Dashboard — Charts page, mobile viewport
- **Severity:** UI / responsive layout (HIGH — multiple compounding issues)
- **Description:** The Charts page has not been adapted for mobile viewports. Multiple issues compound to make it largely unusable on a phone:

  **A. Chart cards clip behind the footer.** The last card on the page cannot be fully scrolled into view — its bottom content (x-axis labels, lower data points, bottom of bar series) is hidden behind the fixed footer/bottom nav. The page content area does not account for the height of fixed bottom elements.

  **B. Tab selector labels truncate.** The chart category tabs (e.g. "Average Climate", "Last 24 Hours/Week/Month") are too long for mobile width. The second tab truncates to "Last 24 Hours/Week/Mo..." with no way to read the full label.

  **C. Empty/oversized card under tabs.** The card area below the tab selector renders as a large empty space — either the chart content failed to render, or the container is sized for desktop and has no mobile adaptation.

  **D. Charts are not optimized for narrow viewports.** Dual-axis charts (e.g. Temperature + Rain) render at desktop proportions on mobile. Axis labels overlap or truncate ("Average Monthly Rain To..."), data points are dense and hard to distinguish, axis tick labels crowd each other, and chart margins consume a disproportionate share of the ~350px available width.

- **Design decisions:**
  - **Dual-axis charts stay combined.** They are designed as dual-axis and must not be split into separate stacked charts on mobile. The relationship between the two series (e.g. temperature trend vs. rainfall bars) is the point — splitting breaks the visual correlation.
  - **Tap-to-fullscreen for detail.** Each chart card should offer a tap/button affordance that opens the chart in a fullscreen landscape-oriented modal (or rotates to landscape). The card view is the summary; fullscreen is for operators who want to study the data. The fullscreen view gets the same chart at a usable resolution.

- **Proposed fixes:**
  - **Footer clearance:** Add `padding-bottom` or `margin-bottom` to the page content container equal to the fixed footer/bottom-nav height, so the last card scrolls fully into view.
  - **Tab label abbreviation:** Shorten tab labels on mobile breakpoints — e.g. "Avg Climate" / "Last 24h/Wk/Mo" — or switch to a scrollable tab strip if there are many tabs.
  - **Chart viewport optimization:** On mobile breakpoints, tighten chart internal margins/padding, use abbreviated axis labels (e.g. "J F M A M J..." for months, "60 65 70 75" without the unit on every tick), reduce font sizes for axis text, and ensure the chart `viewBox` or container dimensions produce a legible aspect ratio. The goal is to make the summary view informative at a glance, not pixel-perfect — the fullscreen view is where detail lives.
  - **Fullscreen affordance:** Add a visible tap target (expand icon in the card header, or tap-anywhere-on-chart) that opens the chart in a fullscreen overlay. The overlay should prefer landscape orientation if the device supports it, or at minimum render at full viewport width and height.
  - **Empty card fix:** Investigate why the card under the tab selector renders empty and fix the underlying render/data issue.

- **Relates to:** FIX-012 (grid exceptions on mobile), FIX-019 (card vertical sizing), FIX-013 (footer layout)
- **Expected:** Charts page is usable on mobile — all cards scroll clear of the footer, tab labels are legible, charts are readable in summary view, and a fullscreen option provides detail-level access.

### FIX-021: Footer floats mid-page on Charts page instead of anchoring to bottom

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T1.4
- **Found:** 2026-06-12
- **Location:** Dashboard — Charts page, mobile viewport (may affect other pages)
- **Severity:** UI (HIGH — footer obscures content and looks broken)
- **Description:** On the Charts page, the footer does not stay at the bottom of the page. It scrolls up and parks itself partway through the content area, overlapping chart cards. This is distinct from FIX-020-A (last card clipping behind the footer) — here the footer itself is in the wrong position entirely.
- **Likely cause:** The footer may be using `position: fixed` or `position: sticky` with a `bottom: 0` relative to a container that doesn't span the full page height. If the Charts page content container has a different height or overflow behavior than the home page, the footer's positioning context changes. Alternatively, the page layout may not use a flex/grid structure that pushes the footer to the end of the content flow.
- **Proposed fix:** The footer should be a flow element at the end of the page content (not fixed/sticky), pushed to the bottom by a flex layout (`flex-grow: 1` on the main content area) or `min-height: 100vh` on the page wrapper. The bottom navigation bar (Now/Forecast/Charts/Almanac/More) is the fixed element — the footer (copyright/logo/social) should scroll with content and appear after the last card.
- **Relates to:** FIX-013 (footer content layout), FIX-020 (Charts page mobile overhaul)
- **Expected:** Footer appears below the last chart card and is only visible when the user scrolls to the bottom of the page.

### FIX-022: Almanac page — mobile layout not designed per card

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T2.4
- **Found:** 2026-06-12
- **Location:** Dashboard — Almanac page, all cards, mobile viewport
- **Severity:** UI / responsive layout (HIGH — page-wide issue)
- **Description:** The Almanac page was built for desktop and has no mobile-specific card layouts. Cards render at desktop proportions and arrangement, leading to truncated axis labels, side-by-side content that doesn't fit, and cards that clip at the bottom. Each card on this page needs its own mobile layout treatment. The same title card oversizing issue from FIX-016 applies here too.

- **Per-card mobile layout decisions:**

  **Sun & Moon card:**
  - Desktop likely shows the sun arc graphic alongside the sunrise/sunset/civil twilight table, and moon data beside it.
  - **Mobile: stack vertically.** Arc graphic on top (full card width), then sun information table below it, then moon information table below that. One column, top to bottom. The arc graphic benefits from full width — it's a visual that loses meaning when shrunk to half a card.

  **Tonight's Planet Outlook card:**
  - Desktop likely shows planets side-by-side (Mercury, Jupiter, Saturn, etc.) with visibility windows and a combined timeline chart.
  - **Mobile: stack each planet vertically.** Each planet gets its own row/block with name, visibility status, and best viewing time. Below the individual planet blocks, the combined visibility timeline chart renders full-width with the tap-to-fullscreen affordance from FIX-020 (same pattern — summary in card, detail in fullscreen).

  **Average Climatological Values by Month card:**
  - Same issues as FIX-020-D — dual-axis chart not optimized for narrow viewport. Axis labels truncate ("mperature (°F)", "Avg Monthly ..."). Apply the same chart optimization approach: tighter margins, abbreviated labels, tap-to-fullscreen.

  **Solar Events / Lunar Events / Meteor Showers cards:**
  - If these show side-by-side columns or horizontal tables on desktop, **stack all content vertically on mobile.** Each event gets its own row — date, name, description stacked within the row. No horizontal scrolling for event tables.

- **General pattern for this page:** Every card that uses side-by-side layout on desktop switches to single-column stacked layout on mobile. The page becomes taller but every element is readable without horizontal scrolling or truncation. Charts get the FIX-020 fullscreen treatment.

- **Relates to:** FIX-016 (title card sizing), FIX-020 (chart optimization + fullscreen affordance), FIX-021 (footer positioning)
- **Expected:** Each Almanac card has a purpose-built mobile layout — stacked content, full-width charts, readable text, no truncation or clipping.

### FIX-023: Seismic page — padding issues and earthquake list obscured by footer on mobile

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) task T2.5
- **Found:** 2026-06-12
- **Location:** Dashboard — Seismic page, mobile viewport
- **Severity:** UI (MEDIUM)
- **Description:** The Seismic page overall layout is acceptable on mobile — the map card and stacked structure work. However, there are two issues:
  1. **Padding/spacing inconsistencies:** Card padding, margins between cards, and content insets don't match the rest of the mobile site. Needs a pass to align with the spacing system used on other pages.
  2. **Earthquake list card obscured by footer:** The Earthquakes card at the bottom of the page is partially hidden behind the fixed bottom nav bar — same root cause as FIX-020-A and FIX-021. The page content area doesn't account for the bottom nav height, so the last card can't be fully scrolled into view.
- **Also visible in screenshot:** The title card subtitle ("Provider: USGS | Radius: 200 km | Min ...") truncates. On mobile this metadata line should either wrap or use abbreviated labels.
- **Relates to:** FIX-020-A (footer clearance pattern), FIX-021 (footer positioning)
- **Expected:** Consistent padding across the Seismic page cards on mobile, and the earthquake list is fully scrollable past the bottom nav.

### FIX-024: Records page — title card oversized, nav bar missing, record cards force internal scrolling on mobile

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) tasks T1.1, T1.2, T2.8
- **Found:** 2026-06-12
- **Location:** Dashboard — Records page, mobile viewport
- **Severity:** UI (HIGH)
- **Description:** Three issues on the Records page mobile layout:
  1. **Title card oversized:** Same issue as FIX-016 — the title/hero card takes up excessive vertical space on mobile.
  2. **Navigation bar missing:** Same issue as FIX-015 — nav disappears on this page with no recovery.
  3. **Record cards use fixed height with internal scrolling instead of auto-sizing.** The individual record cards (temperature records, rain records, wind records, etc.) have good width on mobile — they fill the viewport appropriately. But they are constrained to a fixed height that doesn't match their content, forcing an internal scrollbar within each card to view all the data. This is a poor mobile pattern — the user has to scroll within a card that's within a page that also scrolls, creating nested scroll contexts. On mobile, these cards should auto-size their height to fit all content without internal scrolling. A card with 8 rows of records should be taller than a card with 4 rows.
- **Proposed fix:** On mobile breakpoints, record cards should use `height: auto` (or remove any fixed `height`/`max-height` constraint) so they expand to fit their content. The page becomes longer but each card is fully readable without nested scrolling. This is the same principle as FIX-012 and FIX-019 — on mobile, content legibility wins over uniform card sizing.
- **Relates to:** FIX-012 (grid exception on mobile), FIX-015 (missing nav bar), FIX-016 (title card sizing)
- **Expected:** Record cards auto-size to their content on mobile — all data rows visible without internal scrolling.

### FIX-025: Reports page — title card oversized, selection card truncates, report data not visible on mobile

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) tasks T1.1, T2.6, T3.3
- **Found:** 2026-06-12
- **Location:** Dashboard — Reports page, mobile viewport
- **Severity:** UI (HIGH)
- **Description:** Multiple issues on the Reports page mobile layout:
  1. **Title card oversized:** Same issue as FIX-016.
  2. **Selection/filter card truncates and forces internal scrolling:** The card with report selection options (date range, observation type, etc.) truncates its content and forces scrolling within the card instead of auto-sizing height. Same pattern as FIX-024 — should auto-size on mobile.
  3. **Report data does not display:** The download controls are visible but the actual report content (chart or data) does not render. Only the download option appears — no chart, no table.
  4. **Data table display is an open design question (see below).**

- **The data table problem:** Weather report data is inherently tabular — many columns (date, time, temperature, humidity, wind, rain, pressure, etc.) across many rows. On desktop this works as a wide table. On mobile (~350px), a table with 8+ columns cannot render legibly at any font size.

  **Options considered:**
  - **A. Horizontal scroll on the table:** Keep the full table, let the user scroll horizontally. Simple to implement, but the user loses row context (can't see the date column while reading wind data). Sticky first column helps but adds complexity.
  - **B. Card-per-row (responsive table):** Each data row becomes a vertical card — "Date: Jun 12 | Temp: 72°F | Humidity: 65% | Wind: 8 mph | ..." stacked vertically. Works for a few fields but becomes extremely tall with many observations. Also loses the scanability of a table — harder to spot trends.
  - **C. Column picker + simplified table:** Let the user choose which 3-4 columns to display on mobile. Show a compact table with only those columns. A "customize columns" control lets them swap fields in and out. Keeps the table format readable but requires the user to make a choice.
  - **D. Download-only on mobile, no inline display:** Acknowledge that tabular weather reports are a desktop experience. On mobile, show a summary (date range, record count) and prominent download buttons (CSV, PDF). The user opens the file in a spreadsheet app if they need the detail. Honest about the limitation rather than pretending a 12-column table fits on a phone.
  - **Decision: Option A (horizontal scroll) with download as the prominent emphasis.** The full NOAA table renders with horizontal scrolling and a sticky first column (date/time) so the user always knows which row they're reading. However, the download controls (CSV, PDF, plain text) are the primary call-to-action — positioned above the table, visually prominent, with messaging that the full table is best viewed in a spreadsheet or on desktop. The inline table is a convenience for a quick glance, not the intended consumption path on mobile.

- **Relates to:** FIX-016 (title card sizing), FIX-024 (card auto-sizing)
- **Expected:** Selection card auto-sizes, report data renders in some usable form on mobile (per the chosen approach above), download controls remain accessible.

### FIX-026: About page — all cards fixed height, content truncated or forced internal scroll on mobile

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) tasks T1.1, T2.8
- **Found:** 2026-06-12
- **Location:** Dashboard — About page, all cards, mobile viewport
- **Severity:** UI (MEDIUM)
- **Description:** Every card on the About page uses a fixed height on mobile. Cards with more content than the fixed height allows either truncate their text or force internal scrolling within the card. Same pattern as FIX-024 (Records) and FIX-025 (Reports) — nested scroll-within-scroll on a page that already scrolls.
- **Proposed fix:** All About page cards should use `height: auto` on mobile breakpoints, expanding to fit their content. The About page is text-heavy (station info, hardware details, software versions, acknowledgements, etc.) and each card's content length varies — fixed heights guarantee some cards clip. This is the same auto-size principle from FIX-012, FIX-024, and FIX-025.
- **Relates to:** FIX-012 (grid exception on mobile), FIX-024 (same pattern on Records), FIX-025 (same pattern on Reports)
- **Expected:** All About page cards auto-size to their content on mobile — no truncation, no internal scrolling.

### FIX-028: Now page — uneven vertical spacing between hero card and data cards

- **Found:** 2026-06-13
- **Location:** Dashboard — Now page, both mobile and desktop viewports (confirmed on both)
- **Severity:** UI (MEDIUM)
- **Source:** Grid normalization (GRID-NORMALIZATION-PLAN) post-implementation feedback
- **Description:** After the grid normalization work, the Now page has uneven vertical spacing between the alert banner, hero card, and data cards. The root cause is double spacing: the page's outer wrapper uses `flex flex-col gap-4` (1rem gap between flex children), and each Card component also applies `mb-[var(--gap-grid)]` (another 1rem margin-bottom from T1.3). This results in ~2rem between the hero card and the grid container, but only ~1rem between cards within the grid — creating a visible inconsistency.
- **Root cause:** The grid normalization plan (T1.3) added `mb-[var(--gap-grid)]` to ALL cards for vertical spacing (to replace the removed `gap-y`). But the Now page's outer `flex flex-col gap-4` wrapper wasn't adjusted — it still adds its own gap on top of the card margins. Pages using PageLayout may have the same issue (the PageLayout template also uses `flex flex-col gap-4`).
- **Proposed fix:** Either remove `gap-4` from the outer flex wrapper (since cards now self-space via margin-bottom), or remove `mb-[var(--gap-grid)]` from cards that are direct flex children outside the grid (NowHeroCard, AlertBanner). The fix should be consistent across all pages.
- **Expected:** Uniform 1rem spacing between all cards on the Now page — alert banner, hero card, and all data cards should have equal vertical gaps.

### FIX-029: Page title cards — icon and text too small for card size, poor visual hierarchy

- **Found:** 2026-06-13
- **Location:** Dashboard — PageHeaderCard on all non-Now pages (e.g. Forecast), both viewports but especially visible on mobile
- **Severity:** UI / visual hierarchy (MEDIUM)
- **Source:** Grid normalization post-implementation feedback
- **Description:** The page title cards (PageHeaderCard) have a half-row height that creates a generous container, but the icon (1.5rem / 24px) and title text are disproportionately small relative to the card area. The result is a card that's mostly whitespace with a small icon and small text floating in the center — visible in the Forecast page screenshot where the sun icon and "Forecast" text look lost in the card.
- **Impact on hierarchy:** The page title should be the strongest visual anchor on the page — it tells the user where they are. Currently it's visually weaker than the card titles below it (e.g. "Hourly Forecast", "7-Day Forecast") because those have similar or larger text sizes within tighter containers. Increasing the icon and title text size would establish proper heading hierarchy: page title > section titles > card content.
- **Proposed fix:** In PageHeaderCard, increase the icon size from 1.5rem to ~2rem–2.5rem and increase the title text size (currently likely text-lg or text-xl) to text-2xl or text-3xl. The exact sizes should be tuned so the content fills the half-row card naturally without padding hacks. This change applies to the PageHeaderCard template, so all pages benefit.
- **Relates to:** FIX-016 (title card sizing on mobile — related but distinct: FIX-016 is about the card being too tall, this is about the content being too small within whatever height the card has)
- **Expected:** Page title icon and text are visually prominent, filling the card proportionally and establishing clear heading hierarchy over section titles below.

### FIX-030: Almanac page — climatological chart duplicates Charts page chart, should reuse it

- **Found:** 2026-06-13
- **Location:** Dashboard — Almanac page, Monthly Averages / climatological chart (in `src/routes/almanac.tsx` or `src/components/almanac/`)
- **Severity:** Code quality / DRY (MEDIUM)
- **Source:** Grid normalization post-implementation feedback
- **Description:** The Almanac page has a custom-coded climatological chart (Monthly Averages) that renders the same data and chart type as the climatological chart at the top of the Charts page. The Almanac version was built independently with inline Recharts ComposedChart code, duplicating the data fetching, axis configuration, series definitions, and sizing logic that already exists in the Charts page's ConfigDriven chart system.
- **Proposed fix:** Remove the custom chart code from the Almanac page and reuse the Charts page's climatological chart component directly. The Almanac should reference/embed the same chart (same data source, same rendering) rather than maintaining a parallel implementation. This also means the ChartContainer adoption from T4.3 (GRID-NORMALIZATION-PLAN) becomes unnecessary for the Almanac — the reused chart already goes through ConfigDrivenChart → ChartContainer.
- **Benefits:** Single source of truth for the climatological chart. Bug fixes, styling changes, and mobile optimizations (FIX-020-D, FIX-022) apply to both pages automatically. Less code to maintain.
- **Expected:** Almanac page renders the climatological chart by reusing the Charts page chart component. No custom Recharts code for this chart in the Almanac route.

### FIX-031: Almanac page — moon rendered twice (sun arc graphic and separate moon phase)

- **Found:** 2026-06-13
- **Location:** Dashboard — Almanac page, Sun & Moon card area
- **Severity:** Bug (MEDIUM)
- **Description:** The Almanac page shows the moon in two places: once on the sun arc graphic (the small gray moon icon sitting on/near the sun's arc path at ~10.9° elevation), and again as a separate large moon phase illustration below (Waning Crescent, 4% illuminated). The moon on the sun arc doesn't belong — the sun arc should only show the sun's position. The moon's current sky position is either a rendering error (wrong data mapped to the arc) or a feature that shouldn't coexist with the separate moon phase display below.
- **Expected:** The sun arc graphic shows only the sun. The moon phase is shown once, in its own section below the sun data.

### FIX-032: Moon phase graphic has visible white square background

- **Found:** 2026-06-13
- **Location:** Dashboard — Almanac page (moon phase display) and likely Now page (if moon phase is shown there too)
- **Severity:** UI (LOW)
- **Description:** The moon phase illustration (e.g. the Waning Crescent graphic on the Almanac page) renders with a visible white square background behind it. The moon graphic should have a transparent background so it blends with the card/page background seamlessly. The white box is especially noticeable against the sky/cloud background image.
- **Likely cause:** The moon phase image or SVG/canvas element has a white background fill or is rendered on a container with a white background color. Could be an `<img>` with a non-transparent PNG, an SVG with a white `<rect>` fill, or a CSS background on the container element.
- **Proposed fix:** Remove the background — set the container to `background: transparent` or fix the source graphic to use transparency. If it's a PNG, re-export with transparent background. If it's SVG/canvas-rendered, remove the background fill.
- **Expected:** Moon phase graphic renders with no visible background shape — just the moon illustration floating naturally within the card.

### FIX-033: Reports page — orphaned text below cards, hard to read against background

- **Found:** 2026-06-13
- **Location:** Dashboard — Reports page, mobile viewport
- **Severity:** UI (MEDIUM)
- **Description:** Below the Year/Month selector card, there is text ("Select a year and month to view a report.") that appears to be either orphaned from a card (rendered outside any card container) or bled off the bottom of the selector card. The text sits directly on the sky/cloud background image with no card or backdrop behind it, making it very hard to read — low contrast against the busy photographic background.
- **Proposed fix:** This instructional text should either be inside the selector card (below the dropdowns, within the card's background) or removed entirely if the dropdowns are self-explanatory. If kept, it must be on a card background for readability. Text directly on the background image without a container violates the site's card-based layout model and fails contrast against variable photographic backgrounds.
- **Expected:** No text renders directly on the background image. Instructional text, if needed, lives inside a card with proper contrast.

### FIX-034: NowHeroCard — reduce padding and enlarge logo container to fill card space

- **Found:** 2026-06-13
- **Location:** Dashboard — Now page, NowHeroCard (both viewports)
- **Severity:** UI (MEDIUM)
- **Source:** Grid normalization post-implementation feedback
- **Description:** The NowHeroCard (the hero card on the Now page showing station logo, station ID, and location) has excessive internal padding and the logo container is undersized relative to the card area. The logo and station info look small and lost within the half-row card. Similar visual issue to FIX-029 (PageHeaderCard) but different component.
- **Proposed fix:** Reduce padding within the NowHeroCard and increase the logo container's allocated size so the logo fills more of the available card space. The station info (ID, location) on the right should also feel proportional to the card height.
- **Relates to:** FIX-029 (same class of issue — content undersized for card container — but different component)
- **Expected:** Logo and station info fill the hero card proportionally with minimal wasted whitespace.

### FIX-035: Non-Now pages — cards must be content-adaptive height, not grid-track-enforced

- **Found:** 2026-06-13
- **Location:** Dashboard — all pages EXCEPT Now, desktop viewport (confirmed on Forecast, likely affects all PageLayout pages)
- **Severity:** UI / layout (HIGH — content truncation)
- **Source:** Grid normalization post-implementation feedback
- **Description:** The grid normalization plan applied the quarter-row grid track system uniformly to all pages. This works well on the Now page, which has a predictable card layout with known content sizes. But on all other pages (Forecast, Charts, Almanac, Seismic, Records, Reports, About, Legal), the rigid row-span heights are cutting off card content. The Forecast page is a clear example — the hourly and 7-day forecast cards are truncated vertically because they're constrained to a fixed number of grid tracks.
- **Root cause:** The grid normalization changed `auto-rows` from `auto` to `var(--card-quarter-row)` at md+ breakpoints, and cards declare fixed `rowSpan` values that map to track counts. This forces every card into a predetermined height. Content-heavy cards (forecast tables, charts, record lists, report data, legal text) don't fit within their assigned tracks.
- **Design decision:** The Now page is the ONLY page that should use rigid grid track heights — it's the operator-customizable grid page (per ADR-051) where cards have known footprints and will eventually support drag-and-drop. All other pages should use content-adaptive card heights where cards grow to fit their content.
- **Proposed fix:** In PageLayout (used by all non-Now pages), override the grid to use `auto-rows-[auto]` instead of `auto-rows-[var(--card-quarter-row)]`. This restores content-driven heights for non-Now pages while preserving the rigid grid on the Now page. The `gridClassName` prop on PageLayout already supports this — either change the default or pass the override. Cards still use `min-h` from their `rowSpan` to prevent collapsing, but they grow beyond that minimum when content demands it.
- **Also fixes:** This is the upstream fix for FIX-012, FIX-019, FIX-024, FIX-025, FIX-026, FIX-027 (all "cards truncated/forced internal scroll" issues on non-Now pages). Those per-page mobile fixes may still need attention, but the desktop content truncation is resolved by making height adaptive.
- **Expected:** Cards on all non-Now pages expand to fit their content. No truncation, no forced internal scrolling. The Now page retains its rigid grid track system.

### FIX-027: Legal page — all cards fixed height, content truncated or forced internal scroll on mobile

- **Plan:** [FIXIT-UI-PLAN.md](FIXIT-UI-PLAN.md) tasks T1.1, T2.8
- **Found:** 2026-06-12
- **Location:** Dashboard — Legal page, all cards, mobile viewport
- **Severity:** UI (MEDIUM)
- **Description:** Same issue as FIX-026. All cards on the Legal page use fixed height on mobile, truncating legal text or forcing internal scrolling. Legal content is especially problematic to truncate — an operator's Terms of Use or Privacy Policy must be fully readable without hunting for a scroll handle inside a card.
- **Proposed fix:** Auto-size height on mobile breakpoints, same as FIX-026.
- **Relates to:** FIX-012, FIX-024, FIX-025, FIX-026 (same pattern across multiple pages)
- **Expected:** All Legal page cards auto-size to their content on mobile — full legal text visible without internal scrolling.

## Resolved

### FIX-011: No ADR or documentation for filesystem permissions model

- **Plan:** [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md) tasks T1.6, T5B.1–T5B.6
- **Found:** 2026-06-11
- **Severity:** Security + Operational (HIGH — FIX-010 is a direct symptom)
- **Description:** There is no ADR, no documentation, and no systematic design for how filesystem permissions work across the Clear Skies stack. ADR-027 mentions `secrets.env` is `mode 0600` and TLS keys are `mode 0600`, but these are isolated one-liners, not a coherent model. FIX-010 (permission denied writing `branding.json`) is a direct result of this gap.

  Permissions serve two purposes that are equally important:

  **1. Operational — things working together:**
  - Which process user does the wizard run as?
  - Which process user does the API run as?
  - Which process user does weewx run as?
  - What directories does each process need read access to? Write access to?
  - How does this differ between Docker and bare-metal installs?
  - When the wizard writes `branding.json`, `stack.conf`, `secrets.env` — what user does it write as, and can the API read those files?

  **2. Security — limiting blast radius of a compromise:**
  - If the API process is compromised, what can the attacker touch? Permissions are the answer.
  - The API should NOT be able to write to `weewx.conf` or any weewx configuration
  - The API should NOT be able to write to its own code/binary directory
  - The API should have read-only access to the weewx database (if possible — or at minimum, write access only to its own tables)
  - `secrets.env` should be readable only by the processes that need it, not world-readable
  - Uploaded files (logos, favicons, legal docs) should land in a dedicated directory with no-execute permissions
  - Log files should be append-only from the API's perspective
  - The principle of least privilege: each process gets the minimum permissions it needs, nothing more

- **What needs to be documented (as an ADR):**

  **Process users:**
  | Process | Suggested user | Rationale |
  |---------|---------------|-----------|
  | weewx | `weewx` | Standard weewx convention |
  | Clear Skies API | `clearskies` | Dedicated non-root user, separate from weewx |
  | Wizard/Stack (setup UI) | `clearskies` | Same as API (it's the same process in FIX-007 world) |
  | Caddy (reverse proxy) | `caddy` | Standard Caddy convention |

  **Directory permissions:**
  | Path | Owner | Group | Mode | Who reads | Who writes |
  |------|-------|-------|------|-----------|------------|
  | `/etc/weewx-clearskies/` | `clearskies` | `clearskies` | `0750` | API, wizard | wizard (setup time) |
  | `/etc/weewx-clearskies/secrets.env` | `clearskies` | `clearskies` | `0600` | API | wizard |
  | `/etc/weewx-clearskies/branding.json` | `clearskies` | `clearskies` | `0644` | Caddy (serves to browser) | wizard |
  | `/etc/weewx-clearskies/*.conf` | `clearskies` | `clearskies` | `0640` | API | wizard |
  | `/etc/weewx-clearskies/uploads/` | `clearskies` | `clearskies` | `0750, noexec` | Caddy (serves files) | wizard (file uploads) |
  | `/etc/weewx/weewx.conf` | `weewx` | `weewx` | `0640` | API (read-only via weewx import) | NOT API — weewx only |
  | weewx database (SQLite or MariaDB) | `weewx` | `weewx` | varies | API (read, ideally read-only DB user) | weewx only |
  | API code directory | `root` | `root` | `0755` | API | NOT API — deploy process only |
  | Log directory | `clearskies` | `clearskies` | `0750` | log viewer | API (append) |

  **Clear Skies ↔ weewx boundary (the critical trust boundary):**

  The API co-locates with weewx (FIX-005) and needs access to weewx's data and metadata. But we are a guest on the operator's host. A compromised or buggy Clear Skies process must not be able to damage weewx or the host. This means:

  | What we need | How we get it | What we must NOT have |
  |---|---|---|
  | Read weewx database (archive, daily summaries) | Read-only DB user (MariaDB) or read-only file access (SQLite) | Write access to the weewx database — we never modify station data |
  | Read `weewx.units.obs_group_dict` and extension metadata | Python import of `weewx.units` (read-only by nature) | Ability to modify weewx Python packages or monkey-patch at runtime |
  | Receive loop packets from weewx engine | weewx extension (runs in weewx process, pushes to API via IPC) | Direct access to weewx's engine, drivers, or hardware interfaces |
  | Read `weewx.conf` for station metadata (location, altitude, station type) | Read-only file access to `/etc/weewx/weewx.conf` | Write access to `weewx.conf` — we never modify weewx's configuration |
  | Know when weewx restarts or changes state | The weewx extension signals the API; or API detects via health check | Ability to start, stop, or restart weewx — that's the operator's job |
  | Access weewx's daily summary tables for fast aggregation | Same read-only DB access as archive data | Ability to create, drop, or modify weewx's tables or schema |

  **Key principle: we are read-only consumers of weewx, not administrators of it.** The only component that writes into weewx's process is the loop packet relay extension — and that runs as weewx's own user inside weewx's own process, pushing data OUT to us. We never reach IN.

  If using SQLite: the API process needs read access to the `.sdb` file but should NOT have write access. SQLite's locking model means a rogue write could corrupt weewx's database. The `clearskies` user should be in a group that has read-only access to the file, not the `weewx` group with write access.

  If using MariaDB/MySQL: create a dedicated `clearskies` DB user with `SELECT` privileges only on the weewx database. The wizard/config process may need a separate DB user with limited write privileges for its own config tables (if we store config in the DB), but never write access to weewx's archive or daily summary tables.

  **The weewx extension is the only code that runs with weewx-level privileges.** It must be minimal, audited, and do exactly one thing: serialize loop packets and push them to the API. It should not read Clear Skies config, not write to Clear Skies files, not import Clear Skies code. It's a one-way data valve.

  **Docker-specific considerations:**
  - Container runs as non-root user (USER directive in Dockerfile)
  - Volume mounts for `/etc/weewx-clearskies/` with correct UID/GID mapping
  - Read-only root filesystem (`--read-only`) with tmpfs for `/tmp`
  - The weewx DB may be a volume mount — ensure the API container mounts it read-only if using SQLite
  - If using MariaDB, the API should connect with a read-only DB user for data queries, separate from the wizard user that needs write access to config tables

  **Bare-metal considerations:**
  - Install script should create the `clearskies` user and group
  - Install script should set directory/file permissions as specified
  - Systemd unit files should specify `User=clearskies`, `Group=clearskies`
  - Consider `ProtectSystem=strict`, `ProtectHome=yes`, `ReadWritePaths=` in systemd units for additional sandboxing

- **Relates to:** FIX-008 (security audit — permissions are a key mitigation), FIX-010 (direct symptom of missing permissions model), FIX-005 (co-location means shared filesystem — permissions are the boundary)

- **ADR impact:** Needs a dedicated ADR for the filesystem permissions model. This is not something to scatter across other ADRs in one-liners — it's a first-class security and operational concern.

- **Must flow into development rules:** The security and permissions ADRs are useless if they're only read at review time. They need to be distilled into enforceable rules in `rules/coding.md` and agent definitions so that every implementation session follows them automatically. Examples:
  - "Never open a file for writing outside `/etc/weewx-clearskies/` or the configured upload directory"
  - "Never use the weewx DB connection for INSERT/UPDATE/DELETE on weewx-owned tables"
  - "Never import or call weewx engine/driver modules from API code — only `weewx.units` for metadata"
  - "All file paths from user input must be validated against an allowlist — no path traversal"
  - "All new endpoints must declare whether they are public or admin-only; admin endpoints require auth check"
  - "Uploaded files land in the uploads directory with `noexec`; never serve uploaded content with executable MIME types"
  - The rules file is what agents and developers actually read before writing code. The ADR is the rationale; the rules file is the enforcement.

_(none yet)_
