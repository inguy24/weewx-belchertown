# FIXIT-ARCHITECTURE-PLAN — API co-location, realtime folding, AQI multi-jurisdiction, security audit

**Goal:** Execute the major architectural changes identified during manual testing and design review: co-locate the API with weewx for Python-level metadata access, fold the separate realtime/BFF service into the API (eliminating MQTT), add multi-jurisdiction AQI support with multi-source pollutant merging, and conduct a comprehensive security audit with a formal filesystem permissions model.

**Status:** Not started.

**Source:** [FIXIT-BACKLOG.md](FIXIT-BACKLOG.md) items FIX-003, FIX-004, FIX-005, FIX-006, FIX-007, FIX-008, FIX-011.

**Repos involved:**
- `weewx-clearskies-api` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-api`) — receives all realtime code, AQI changes, security hardening
- `weewx-clearskies-realtime` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-realtime`) — code migrates OUT of here; repo deprecated at plan completion
- `weewx-clearskies-stack` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-stack`) — wizard AQI scale step, docker-compose updates, Caddyfile updates
- `weewx-clearskies-dashboard` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard`) — AQI card scale-aware rendering

**Dev/test environment:** `weather-dev` LXD container. API source at `/home/ubuntu/repos/weewx-clearskies-api`. Realtime source at `/home/ubuntu/repos/weewx-clearskies-realtime`. Deploy via `scripts/redeploy-weather-dev.sh`. API managed by `weewx-clearskies-api.service` (systemd). Realtime managed by `weewx-clearskies-realtime.service` (systemd).

---

## Orientation — read before executing any task

**Load these before every session:**
1. [CLAUDE.md](../../CLAUDE.md) — domain routing, operating rules
2. [rules/coding.md](../../rules/coding.md) — code standards, security rules, accessibility
3. [rules/clearskies-process.md](../../rules/clearskies-process.md) — ADR discipline, agent orchestration, process rules
4. [docs/ARCHITECTURE.md](../ARCHITECTURE.md) — current system architecture (**read first, before any ADRs**)
5. This plan — current task status and context

**Critical ADRs (read before relevant phases):**
- ADR-005 — realtime architecture (will be superseded by Phase 3)
- ADR-008 — auth model
- ADR-012 — database access pattern (read-only enforcement)
- ADR-013 — AQI handling (will be amended by Phase 4)
- ADR-027 — config and setup wizard
- ADR-034 — deployment topology (will be amended by Phase 3)
- ADR-035 — user-driven column mapping
- ADR-037 — inbound traffic architecture
- ADR-038 — data provider module organization
- ADR-041 — realtime as BFF, computation boundaries (will be superseded by Phase 3)
- ADR-042 — unit system

**Git safety:** Agents do NOT push. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No worktree isolation for implementation — all work in the primary local checkout. Coordinator commits after QC.

**QC model:** Opus provides QC at every task. QC is NOT "is the code well-written" — it is:
- Does the change do what the task says it should do?
- Does it comply with this plan, ARCHITECTURE.md, and relevant ADRs?
- Does it introduce regressions in existing functionality?
- Is the acceptance criteria met (verified by running the check, not trusting the agent's claim)?

**No deferrals.** Every task in this plan is mandatory. Agents do not get to say "deferred to a future round." If a task is blocked, the agent reports the blocker and the coordinator resolves it. The task does not close until acceptance criteria are met.

---

## Current architecture snapshot (from codebase exploration)

### API (`weewx-clearskies-api`)

- **Entry point:** `weewx_clearskies_api/__main__.py` (717 lines) — orchestrates startup: logging, settings, DB engine, schema reflection, weewx.conf loading, provider registry, middleware, TLS, uvicorn.
- **App factory:** `app.py` (273 lines) — FastAPI with 15+ routers, 7-layer middleware stack (SecurityHeaders → CORS → RateLimit → ProxyAuth → BodySizeLimit → RequestId → Metrics).
- **Providers:** 25 modules across 6 domains (forecast, alerts, AQI, earthquakes, radar, seeing). Registry at `providers/_common/dispatch.py` lines 51-76.
- **AQI:** 4 providers (OpenMeteo, Aeris, OWM, IQAir). Endpoint at `endpoints/aqi.py`. Schema `AQIReading` in `models/responses.py` lines 1059-1115 — 6 pollutants (PM2.5, PM10, O3, NO2, SO2, CO). EPA breakpoints only in `providers/aqi/_units.py` lines 160-317.
- **DB access:** SQLAlchemy 2.x, read-only enforcement via startup write-probe (`db/probe.py`). Schema reflection at startup (`db/reflection.py`).
- **Unit handling:** Reads weewx.conf for unit system (`services/units.py`). Passes raw values with `usUnits` — does NOT convert.
- **No weewx Python imports** currently. Reads weewx.conf as a ConfigObj file, does not import `weewx.units` or any weewx module.
- **Security:** TLS mandatory, rate limiting (60/min per IP), ProxyAuth HMAC, Pydantic input validation, parameterized SQL, health on loopback port.

### Realtime/BFF (`weewx-clearskies-realtime`)

- **Entry point:** `weewx_clearskies_realtime/__main__.py` (343 lines).
- **SSE emitter:** `sse/emitter.py` — fan-out queue broadcaster, sse-starlette library. One source queue, N subscriber queues, 15s keepalive, 64-packet overflow drop.
- **Input adapters (2, mutually exclusive):**
  - Direct: `adapters/direct.py` — Unix domain socket client, auto-reconnect with exponential backoff.
  - MQTT: `adapters/mqtt.py` — paho-mqtt subscriber, thread-safe queue push.
- **Enrichment pipeline:** `enrichment/packet_tap.py` registry + 12 processors:
  - `input_smoother.py` — ring buffers for temperature comfort
  - `uv_smoother.py` — rolling UV average
  - `sky_tap.py` / `sky_condition.py` — solar radiation → sky classification (ADR-044)
  - `wind_rolling_window.py` — 10-min rolling wind averages
  - `lightning_strike_buffer.py` — 24-hr strike log
  - `barometer_trend.py` — pressure change over time
  - `scene_enrichment.py` / `scene_packet_tap.py` — sky/daytime/overlay descriptor (ADR-047). **Makes HTTP calls back to API** (`/api/v1/almanac`, `/api/v1/forecast?interval=hourly`).
  - `weather_text.py` — conditions blending engine
  - `planet_viewing.py` — planet visibility from 7Timer
  - `ring_buffer.py` — shared ring buffer data structure
- **Unit conversion:** Full `units/` module — `conversion.py`, `derived.py` (Beaufort, comfort index), `groups.py`, `labels.py`, `transformer.py`. BFF is the single conversion authority (ADR-041/042).
- **BFF proxy:** `proxy.py` — catch-all `/api/v1/{path:path}` forward to upstream API. Applies unit conversion to all proxied responses. Registers per-endpoint enrichments (barometer trend, wind rolling avg, lightning history, weather text, UV smooth, scene, planet viewing).
- **Other:** `conditions_text.py`, `temperature_comfort.py`, `scene.py`, `mqtt_fields.py`, `weewx_ext.py` (ClearSkiesLoopRelay extension).
- **Total:** ~5,000 LOC.

### ADR constraints

- **ADR-041:** API = general-purpose data access (no unit conversion, no chart-specific endpoints). BFF = transformation authority (unit conversion, derived values). Dashboard = rendering.
- **ADR-042:** BFF is single unit-conversion authority. Full weewx unit group compatibility.
- **ADR-034:** Two-host default (API on weewx host, dashboard+realtime on front-end host). Single-host also supported.
- **ADR-005:** Direct + MQTT adapter modes. Will be superseded.
- **ADR-013:** AQI providers as modules. `aqiScale` discriminator ("epa" or "owm"). `aqiCategory` always null from providers (dashboard-computed).

---

## Phase 0 — Research

Verify current state and gather data needed for ADR drafting and implementation.

### T0.1 — Realtime service full inventory

- **Owner:** `Explore` agent (Sonnet)
- **Dep:** None
- **Do:**
  1. Read every file in `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/`. For each file, document: purpose, line count, imports (external deps and internal cross-imports), public API (functions/classes exported).
  2. Map the dependency graph between modules — which files import from which other files within the package.
  3. Identify all external dependencies that will need to be added to the API's `pyproject.toml` when migrating: `sse-starlette`, `paho-mqtt` (being deleted), any others.
  4. Identify any shared code patterns between the realtime service and the API (e.g., both read weewx.conf, both have health endpoints, both use JSON logging).
- **Accept:** Complete file inventory with purpose, line count, dependencies, and public API for every module. Dependency graph. External dependency list. Shared pattern list.
- **QC:** Opus spot-checks 5+ file descriptions against actual file content.

### T0.2 — API extensibility assessment

- **Owner:** `Explore` agent (Sonnet)
- **Dep:** None (parallel with T0.1)
- **Do:**
  1. Read `repos/weewx-clearskies-api/weewx_clearskies_api/__main__.py` fully. Document the startup sequence step by step. Identify where SSE, enrichment processors, and the adapter would plug into the startup.
  2. Read `app.py` fully. Identify where new routers (e.g., `/sse`) would be registered. Identify where the enrichment registry would integrate.
  3. Read the middleware stack. Identify any middleware that would need changes when the API starts serving SSE (e.g., rate limiting SSE connections differently from REST requests).
  4. Check: does the API already have `sse-starlette` as a dependency? Does it already have any SSE endpoint? Any asyncio event loop management?
  5. Read `pyproject.toml` for both repos — document all dependencies and version pins.
- **Accept:** Step-by-step startup sequence map with insertion points for SSE, enrichment, and adapter. Router registration point. Middleware concerns for SSE. Dependency comparison between the two repos.
- **QC:** Opus verifies the startup sequence against `__main__.py` by reading it directly.

### T0.3 — weewx Python import feasibility

- **Owner:** `Explore` agent (Sonnet)
- **Dep:** None (parallel with T0.1, T0.2)
- **Do:**
  1. SSH to weather-dev. Check if `weewx` is importable from the API's venv:
     ```
     /home/ubuntu/repos/weewx-clearskies-api/.venv/bin/python -c "import weewx.units; print(weewx.units.obs_group_dict)"
     ```
  2. If not importable: check where weewx is installed (`which weewxd`, `pip show weewx`, check `/usr/share/weewx/`, `/home/weewx/` etc.). Document the Python path needed.
  3. If importable: dump `weewx.units.obs_group_dict` to see what observation types are registered. Document any OWM plugin columns (ow_*) and their unit groups.
  4. Check the API's systemd unit file for environment variables, Python path settings, `ExecStart` command. Document what changes are needed to make weewx importable if it isn't already.
  5. Document the weewx version, Python version, and venv location.
- **Accept:** Confirmation of whether weewx is importable from the API venv. If not: exact steps to make it importable. If yes: dump of obs_group_dict showing registered observation types and unit groups. Systemd unit file contents.
- **QC:** Opus verifies the import test was actually run on weather-dev (not guessed).

### T0.4 — AQI provider multi-jurisdiction capability research

- **Owner:** Opus
- **Dep:** None (parallel)
- **Do:**
  1. Download and save comprehensive AQI API documentation for all 4 providers to `docs/reference/api-docs/`. The existing docs were captured with US-only assumptions and miss multi-jurisdiction support.
  2. For each provider, document: which AQI scales does the provider compute natively? What parameters control the scale? Does the scale auto-detect by location or require explicit configuration?
  3. For each provider, document: which pollutants are returned? Are NO and NH3 included? What are the wire field names?
  4. Key findings needed per provider:
     - **Aeris:** 8 `filter` values (`airnow`, `china`, `india`, `eaqi`, `caqi`, `uk`, `de`, `cai`). Does NOT auto-detect — defaults to `airnow`. AQHI returned in `health` object on every response regardless of filter. Response shape identical across filters; only `aqi`, `category`, `color`, `method` change. 7 pollutants (co, no2, o3, pm1, pm2.5, pm10, so2). No NH3, no NO in API response.
     - **IQAir:** Only `aqius` (US EPA) and `aqicn` (China MEP). No European, Indian, or Canadian scales. Paid tiers add per-pollutant concentrations with `{conc, aqius, aqicn}` structure.
     - **OpenMeteo:** Only `us_aqi` and `european_aqi`. Both work globally (not region-locked). No India/China/Canada indices. NH3 Europe-only. NO (`nitrogen_monoxide`) global.
     - **OWM:** Own 1-5 ordinal scale only. Regional scales (UK/Europe/USA/China) are documentation-only reference tables, NOT returned in the API. 8 components always returned including `no` and `nh3` (global). Currently dropped during canonical translation — must stop dropping.
- **Accept:** Updated api-docs files saved to project. Per-provider scale support matrix. Per-provider NO/NH3 availability with wire field names. Provider configuration requirements for multi-jurisdiction (Aeris filter, OpenMeteo variable name, IQAir field selection).
- **QC:** Opus reads the updated api-docs and verifies claims against the provider documentation.

### T0.5 — Security baseline verification

- **Owner:** Opus
- **Dep:** None (parallel)
- **Do:**
  1. Read `docs/contracts/security-baseline.md`. For each control listed, verify it is actually implemented by reading the relevant source file:
     - Rate limiting: `middleware/rate_limit.py` — is 60/min enforced?
     - ProxyAuth: `middleware/proxy_auth.py` — is constant-time compare used?
     - Body size limit: `middleware/body_size_limit.py` — is 1 MiB enforced?
     - Security headers: `middleware/security_headers.py` — which headers?
     - TLS: `tls.py` — is it mandatory or optional?
     - Read-only DB: `db/probe.py` — does the write probe actually exit on success?
     - Input validation: spot-check 3+ endpoint files for Pydantic model usage.
     - Logging redaction: check `logging/` for credential stripping.
  2. Run `pip-audit` on the API repo (in the venv on weather-dev). Document any findings.
  3. Check the existing systemd unit file against the hardening flags listed in the security baseline (NoNewPrivileges, ProtectSystem, etc.). Which flags are actually present?
  4. Check CORS configuration — what origins are allowed?
- **Accept:** Per-control verification matrix: control name | documented | implemented | file:line | gap (if any). pip-audit output. Systemd hardening flag comparison. CORS config.
- **QC:** Opus reviews the verification matrix and confirms 5+ controls were actually checked against source code (not just claimed).

### T0.6 — Current deployment state

- **Owner:** `Explore` agent (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. SSH to weather-dev. Run:
     - `ps aux | grep clearskies` — what processes are running, as which users?
     - `ls -la /etc/weewx-clearskies/` — directory ownership and permissions
     - `ls -la /etc/weewx-clearskies/*` — file-level ownership and permissions
     - `cat /etc/systemd/system/weewx-clearskies-api.service` — API unit file
     - `cat /etc/systemd/system/weewx-clearskies-realtime.service` — realtime unit file (if exists)
     - `ss -tlnp | grep -E '8765|8766|8081|8082|9876'` — port bindings
     - `cat /etc/weewx-clearskies/api.conf` (redact secrets) — current API config
  2. Document the "before" state: process users, file ownership, port bindings, TLS state.
- **Accept:** Complete deployment state snapshot with all command outputs documented. This is the baseline for Phase 5 (security) and the reference for all deployment changes in this plan.
- **QC:** Opus verifies the commands were run (outputs included, not summarized).

---

## Phase 1 — Foundation ADRs

Write all ADRs BEFORE any implementation. Each follows the Proposed → user review → Accepted lifecycle per `rules/clearskies-process.md`.

**Dep:** Phase 0 complete (research findings inform ADR content).

### T1.1 — ADR: API co-location with weewx (FIX-005)

- **Owner:** Opus
- **Dep:** T0.3 (import feasibility findings)
- **Backlog:** FIX-005
- **Do:**
  1. Draft a new ADR establishing the hard requirement that the Clear Skies API runs on the same host as weewx with Python-level import access to `weewx.units`.
  2. Document: why co-location is needed (metadata access for unit auto-detection, xtypes potential, obs_group_dict), what it enables (tiered unit resolution: auto-detect → heuristic → operator confirm → store), what it does NOT do (not rewriting weewx ingestion, not making weewx a dependency to eliminate).
  3. Document the tiered unit resolution strategy with concrete examples from T0.3 findings (e.g., `weewx.units.obs_group_dict['ow_pm25'] → 'group_concentration' → µg/m³`).
  4. Consequences: deployment constraint (API must be on weewx host), Python path requirement, graceful fallback if weewx not importable.
  5. Use Nygard format. ~80 lines. Status: Proposed.
- **Accept:** ADR file created at `docs/decisions/ADR-0XX-api-weewx-co-location.md`. Status: Proposed. Content covers: context, options, decision, consequences, implementation guidance. User has reviewed the full content.
- **QC:** Opus reads the ADR and verifies: Nygard format, ≤100 lines, no implementation mockups, decision stated in 1-2 sentences, references relevant existing ADRs (ADR-034, ADR-035, ADR-012).

### T1.2 — ADR: API as weewx application layer (FIX-006)

- **Owner:** Opus
- **Dep:** T0.4 (gap analysis context)
- **Backlog:** FIX-006
- **Do:**
  1. Draft a new ADR reframing the API's purpose from "Clear Skies backend" to "the weewx application-layer API." This is a scope and vision ADR, not an implementation spec.
  2. Document: the capability surface the API must eventually match (xtypes derived observations, aggregation system, time-bounded queries, unit conversion pipeline — all from FIX-006's description), what Clear Skies adds beyond weewx (provider aggregation, multi-source merging, SSE, REST interface, caching).
  3. Include a gap analysis appendix: which weewx capabilities the API already covers, which are partially covered, which are completely missing. This is planning input for future phases.
  4. Explicitly state what this is NOT: not rewriting weewx ingestion, not eliminating weewx as a dependency, not backwards-compatible with Cheetah tags.
  5. Status: Proposed.
- **Accept:** ADR file created. Status: Proposed. Content covers reframing, capability surface, gap analysis appendix, explicit non-goals. User has reviewed.
- **QC:** Opus reads the ADR and verifies: the gap analysis appendix is organized as a table (capability | status | notes), the non-goals are explicit, no implementation mockups.

### T1.3 — ADR: Fold realtime into API, eliminate MQTT (FIX-007)

- **Owner:** Opus
- **Dep:** T0.1 (realtime inventory), T0.2 (API extensibility)
- **Backlog:** FIX-007
- **Do:**
  1. Draft a new ADR that supersedes ADR-005 and amends ADR-041 and ADR-034.
  2. **Decision:** The realtime/BFF service merges into the API. The API becomes a push/pull service (REST for queries, SSE for real-time). MQTT support is eliminated.
  3. **What moves in:** SSE emitter, direct adapter, enrichment pipeline (12 processors), unit conversion module, derived value computation, conditions text engine. Use T0.1 inventory as the migration manifest.
  4. **What gets deleted:** MQTT adapter, paho-mqtt dependency, BFF proxy (API serves directly), ClearSkiesLoopRelay weewx extension (replaced by new extension or IPC mechanism), the weewx-clearskies-realtime repo (deprecated, not deleted).
  5. **Target architecture diagram:** API (single service, co-located with weewx) → REST + SSE. Caddy proxies everything to API.
  6. **Migration strategy:** port in sub-phases (infrastructure → enrichment → unit conversion → cleanup), maintain backward compat during migration, full integration test before cutting over.
  7. **ADR-041 amendment:** the computation boundary (API = raw data, BFF = conversion) collapses — API now does both.
  8. **ADR-034 amendment:** topology simplifies (no realtime container).
  9. Status: Proposed.
- **Accept:** ADR file created. Explicitly supersedes ADR-005, amends ADR-041 and ADR-034. Migration manifest references T0.1 findings. User has reviewed.
- **QC:** Opus reads the ADR and verifies: supersedes/amends references are explicit, the "what gets deleted" list is complete against T0.1 inventory, the target architecture diagram is present.

### T1.4 — ADR: Multi-jurisdiction AQI architecture (FIX-003)

- **Owner:** Opus
- **Dep:** T0.4 (AQI provider research)
- **Backlog:** FIX-003
- **Do:**
  1. Draft a new ADR amending ADR-013. Documents the multi-jurisdiction AQI architecture.
  2. **Decision:** The API does NOT compute AQI indices — providers compute them natively. Each provider supports different scales: Aeris has 8 regional filters (airnow/china/india/eaqi/caqi/uk/de/cai), OpenMeteo has US+European, IQAir has US+China, OWM has its own 1-5 ordinal. The `aqiScale` field carries whatever scale the provider returned.
  3. **Provider configuration:** Aeris requires explicit `filter` parameter (no auto-detect). This becomes a provider-specific setting in the wizard's provider selection step (step 6), auto-suggested by station location. OpenMeteo: operator picks `us_aqi` or `european_aqi`. IQAir: operator picks `aqius` or `aqicn`. OWM: always own 1-5 scale.
  4. **Schema changes:** Add `pollutantNO` and `pollutantNH3` to `AQIReading`. Pass through `aqiCategory` from provider instead of nulling it.
  5. **Key principle:** Stop dropping pollutant data. OWM returns NO and NH3 — currently dropped because "no EPA AQI band." Wrong. Pass through everything the provider supplies.
  6. **Dashboard rendering:** Render per `aqiScale`. Category names, colors, and banding come from the provider's response or are derived from the provider's documented scale. All available pollutants always shown.
  7. **Reference:** `docs/reference/api-docs/{aeris,iqair,openmeteo,openweathermap}.md` — AQI sections.
  8. Status: Proposed.
- **Accept:** ADR file created. Amends ADR-013. Pass-through architecture described. Provider scale support matrix included. Schema changes listed. "Don't drop data" principle stated. User has reviewed.
- **QC:** Opus reads the ADR and verifies: no breakpoint computation described, provider configuration per T0.4 findings, schema changes explicit, api-docs referenced.

### T1.5 — ADR: Security model and threat boundaries (FIX-008)

- **Owner:** Opus
- **Dep:** T0.5 (security baseline verification), T0.6 (deployment state)
- **Backlog:** FIX-008
- **Do:**
  1. Draft a new ADR establishing the threat model for the co-located API.
  2. **Trust boundaries:** Internet → Caddy (TLS termination, rate limiting, header injection) → API (auth, input validation, query limits) → weewx (read-only, metadata import only). Each layer enforces its own constraints.
  3. **Principle:** The API is a gateway to data, not a door into the host. A vulnerability in the API must not give an attacker filesystem access, weewx modification capability, or lateral movement.
  4. **Attack surfaces (from FIX-008):** Input validation/injection, authentication boundaries, process isolation, network exposure, dependency supply chain, data exposure, DoS, weewx-specific risks.
  5. **Mandatory mitigations:** Principle of least privilege, reverse proxy mandatory, admin boundary, input sanitization, query cost limits, SSE connection limits, error sanitization, read-only filesystem (Docker), network policy.
  6. Reference T0.5 verification matrix — note gaps between documented and implemented controls.
  7. Status: Proposed.
- **Accept:** ADR file created. Threat model documented. Trust boundaries diagrammed. Attack surfaces enumerated. Mitigations listed with priority. User has reviewed.
- **QC:** Opus reads the ADR and verifies: trust boundary diagram present, attack surfaces match FIX-008 backlog description, T0.5 gaps referenced.

### T1.6 — ADR: Filesystem permissions model (FIX-011)

- **Owner:** Opus
- **Dep:** T0.6 (current deployment state)
- **Backlog:** FIX-011
- **Do:**
  1. Draft a new ADR establishing the filesystem permissions model.
  2. **Process users table:** weewx → `weewx`, API → `clearskies`, Caddy → `caddy`. Each with rationale.
  3. **Directory permissions table** (from FIX-011): `/etc/weewx-clearskies/` ownership, mode, who reads, who writes for each file type (secrets.env, *.conf, branding.json, uploads/).
  4. **Clear Skies ↔ weewx boundary:** Read-only consumer of weewx. Only the weewx extension runs with weewx-level privileges. API never writes to weewx DB, never modifies weewx.conf, never imports weewx engine/driver modules.
  5. **Docker-specific:** Non-root USER, read-only root filesystem, tmpfs for /tmp, explicit volume mounts, read-only weewx DB mount.
  6. **Bare-metal:** Install script creates users/groups, sets permissions, systemd hardening flags.
  7. **Flow into rules:** Must distill into enforceable rules in `rules/coding.md`.
  8. Status: Proposed.
- **Accept:** ADR file created. Process users table, directory permissions table, trust boundary description, Docker and bare-metal sections. User has reviewed.
- **QC:** Opus reads the ADR and verifies: permissions table matches FIX-011 backlog, trust boundary principle stated ("read-only consumer of weewx"), Docker and bare-metal both covered.

---

## Phase 2 — API co-location with weewx (FIX-005)

Implement Python-level metadata access from the API to weewx's runtime.

**Dep:** T1.1 ADR Accepted.

### T2.1 — Make weewx importable from API venv

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T0.3 (feasibility findings)
- **Do:**
  1. Using T0.3 findings, configure the API's Python environment so `import weewx.units` succeeds.
  2. Options (use whichever T0.3 identified as correct): add weewx to the venv's `pth` file, install weewx as a dependency, or set `PYTHONPATH` in the systemd unit.
  3. Verify on weather-dev: `source .venv/bin/activate && python -c "import weewx.units; print(len(weewx.units.obs_group_dict))"` succeeds.
- **Accept:** `import weewx.units` succeeds in the API's venv on weather-dev. The method is documented (which file changed, what was added).
- **QC:** Opus runs the import test on weather-dev independently.

### T2.2 — weewx metadata reader service

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T2.1
- **Do:**
  1. Create `weewx_clearskies_api/services/weewx_metadata.py`. This module:
     - Imports `weewx.units` at module load time (wrapped in try/except for graceful fallback).
     - Provides `get_obs_group(column_name: str) -> str | None` — looks up `weewx.units.obs_group_dict.get(column_name)`.
     - Provides `get_unit_for_group(group: str, unit_system: int) -> str | None` — looks up the unit for a group in the given unit system (US=1, Metric=16, MetricWX=17).
     - Provides `is_available() -> bool` — returns whether weewx was successfully imported.
     - Caches `obs_group_dict` at startup (it doesn't change without restarting weewx).
  2. If weewx is not importable: log a warning at startup, `is_available()` returns False, all lookups return None. The API continues to function without unit auto-detection.
  3. Wire into `__main__.py` startup sequence — call after settings load, before schema reflection.
- **Accept:**
  - `get_obs_group('outTemp')` returns `'group_temperature'`.
  - `get_obs_group('ow_pm25')` returns `'group_concentration'` (if the OWM extension is installed).
  - `get_obs_group('nonexistent_column')` returns `None`.
  - If weewx not importable: no crash, warning logged, `is_available()` returns False.
  - Unit test for all cases (weewx available, weewx not available, known column, unknown column).
- **QC:** Opus runs the unit tests. Verifies the graceful fallback by temporarily breaking the import path and confirming the API starts without crash.

### T2.3 — Integrate unit auto-detection into column mapping

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T2.2
- **Do:**
  1. In `db/reflection.py`, after schema reflection discovers archive columns, call `weewx_metadata.get_obs_group(column_name)` for each column.
  2. If a group is found, resolve it to a concrete unit via `get_unit_for_group(group, unit_system)` where `unit_system` comes from the archive's `usUnits`.
  3. Store the auto-detected unit alongside the column in the `ColumnRegistry`.
  4. Expose this in the `/setup/schema` endpoint response — each column should include `autoDetectedUnit: string | null` and `autoDetectedGroup: string | null`.
- **Accept:**
  - `/setup/schema` response includes `autoDetectedUnit` and `autoDetectedGroup` for each column.
  - Stock columns (outTemp, windSpeed, etc.) show correct auto-detected units.
  - Custom/extension columns not in `obs_group_dict` show null (handled by column mapping, not auto-detection).
  - Existing schema endpoint functionality unbroken.
- **QC:** Opus calls `/setup/schema` on weather-dev and verifies auto-detected units appear for known columns.

### T2.4 — Heuristic mapping suggestions for custom columns

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T2.3
- **Do:**
  1. In the column mapping service, add opt-in heuristic suggestions for custom columns (columns not in the stock weewx lookup table) where `autoDetectedUnit` is null:
     - `pm25`, `pm10`, `pm1` patterns: suggest µg/m³.
     - `*_temp*`, `*Temp*` patterns: suggest group_temperature.
     - `*_humid*`, `*Humidity*` patterns: suggest group_percent.
     - Generic pollutant-like names: suggest µg/m³.
  2. Mark suggestions distinctly from weewx-detected values: `unitSource: "weewx" | "heuristic" | null`.
  3. These are SUGGESTIONS only — never applied without operator confirmation.
  4. Custom columns are extension-specific and operator-defined. We cannot assume any specific extensions are installed. No special-casing for any particular plugin's column names.
- **Accept:**
  - Column with a pattern match: `suggestedUnit` populated, `unitSource: "heuristic"`.
  - Unknown column with no pattern match: `suggestedUnit: null, unitSource: null`.
  - Suggestions never applied without operator confirmation.
- **QC:** Opus verifies heuristic suggestions appear for pattern-matched columns and null for unmatched.

### T2.5 — Wizard column mapping confirmation step

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2.3, T2.4
- **Do:**
  1. **Stock columns:** Always pre-filled with suggested mappings from the built-in stock-weewx lookup table. Operator reviews and confirms every mapping — nothing auto-maps silently. Operator can adjust any mapping before proceeding.
  2. **Custom columns:** Wizard asks the operator: "Would you like mapping assistance for custom columns?" (opt-in).
     - **Yes:** Show auto-detected (from `obs_group_dict` if weewx importable) and heuristic suggestions, each marked with source indicator. Operator confirms or overrides each.
     - **No:** Operator maps each custom column manually from the canonical field dropdown.
  3. Each column shows: column name, suggested mapping (if any), source indicator (stock/weewx/heuristic/manual), and override controls.
  4. Step validates: no column proceeds without operator-confirmed mapping. No silent auto-advance even when all columns are stock.
  5. **ADR-035 amendment note:** ADR-035 currently says "stock weewx columns auto-map silently" and "when all columns are stock, the wizard auto-advances." Both of those behaviors are superseded — operator confirmation is always required.
- **Accept:**
  - Stock columns appear pre-filled but require operator confirmation.
  - Custom column assistance is opt-in.
  - No column mapping proceeds without explicit operator confirmation.
  - No auto-advance — operator always sees the mapping step.
- **QC:** Opus walks through the wizard column mapping step and verifies: stock columns pre-filled, custom columns ask for opt-in, nothing auto-advances.

### T2.6 — Store confirmed units in config

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T2.5
- **Do:**
  1. Save the operator-confirmed unit metadata in the API's config (api.conf or a separate column-units.conf).
  2. Format: `[column_units]` section with `column_name = unit_string` entries.
  3. At startup, read confirmed units from config. Only re-query weewx if the config doesn't have a unit for a mapped column (new column added since last setup).
- **Accept:**
  - Confirmed units persist across API restarts without re-querying weewx.
  - New columns (added after initial setup) trigger re-detection on next startup.
  - Config file is human-readable (ConfigObj format).
- **QC:** Opus restarts the API and confirms confirmed units are loaded from config, not re-detected.

### T2.7 — Unit validation at read time

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T2.2, T2.6
- **Do:**
  1. When reading mapped columns from the DB, compare the stored confirmed unit against the current obs_group_dict value (if available).
  2. If they mismatch: log a warning with the column name, stored unit, and current obs_group_dict unit. Do NOT fail — serve the data with the stored (confirmed) unit.
  3. This catches cases where a weewx plugin update changes units without the operator re-running setup.
- **Accept:**
  - Mismatch produces a warning log, not an error.
  - Data is still served (stored unit used).
  - Matching units produce no log entry (happy path is silent).
- **QC:** Opus simulates a mismatch (temporarily edit config to have a wrong unit) and confirms the warning is logged but data is served.

### T2.8 — Co-location tests

- **Owner:** `test-author` (Sonnet)
- **Dep:** T2.2, T2.3, T2.4, T2.7
- **Do:**
  1. Unit tests for `weewx_metadata.py`: weewx available, weewx not available, known column, unknown column, unit group resolution.
  2. Unit tests for heuristic fallback: each pattern, no-match case.
  3. Unit tests for unit validation: match, mismatch, weewx unavailable.
  4. Integration test on weather-dev: start API, call `/setup/schema`, verify auto-detected units for known columns.
- **Accept:** All tests pass. Pytest output included in completion report.
- **QC:** Opus runs the test suite independently and confirms pass count.

---

## Phase 3 — Fold realtime into API (FIX-007)

The critical path. Port ~5,000 LOC from the realtime service into the API. Delete MQTT. Update routing.

**Dep:** T1.3 ADR Accepted. Phase 2 complete (co-location established).

### Sub-phase 3A — SSE infrastructure

### T3A.1 — Add sse-starlette to API and create SSE emitter

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T0.1 (realtime inventory), T0.2 (API extensibility)
- **Do:**
  1. Add `sse-starlette` to API's `pyproject.toml` dependencies.
  2. Port `sse/emitter.py` from realtime into API at `weewx_clearskies_api/sse/emitter.py`. Preserve: fan-out queue pattern, keepalive (15s), overflow handling (64-packet drop).
  3. Port `ring_buffer.py` utility into API at `weewx_clearskies_api/sse/ring_buffer.py`.
  4. Adapt for the API's startup pattern — the emitter should be created in `__main__.py` and passed to the app factory.
- **Accept:** SSE emitter module exists in API. Unit test: create emitter, subscribe, push a packet, verify subscriber receives it. Keepalive fires after 15s of silence.
- **QC:** Opus reads the ported emitter and confirms it matches the realtime version's behavior. Runs the unit test.

### T3A.2 — Create /sse endpoint in API

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3A.1
- **Do:**
  1. Create `weewx_clearskies_api/endpoints/sse.py` with a `GET /sse` endpoint using sse-starlette's `EventSourceResponse`.
  2. On connect: subscribe to emitter. On disconnect: unsubscribe.
  3. Event format: `{"event": "loop", "data": "{...json packet...}"}` — matching the existing realtime format so the dashboard needs no changes.
  4. Register the router in `app.py`.
- **Accept:** `GET /sse` returns an SSE stream. Dashboard can connect and receive events (verified by curl or browser EventSource). Event format matches the existing realtime `/sse` format exactly.
- **QC:** Opus connects to `/sse` with curl and verifies the event stream format.

### T3A.3 — Port direct adapter into API

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3A.1
- **Do:**
  1. Port `adapters/direct.py` (Unix socket client) into API at `weewx_clearskies_api/sse/direct_adapter.py`.
  2. Preserve: auto-reconnect with exponential backoff (1s → 120s max), JSON line parsing, health probe.
  3. Wire into `__main__.py`: start the adapter as a background asyncio task, feed received packets into the emitter's source queue.
  4. The existing `ClearSkiesLoopRelay` weewx extension (`weewx_ext.py` in the realtime repo) pushes to the Unix socket — this extension stays as-is for now. The API is just a new consumer of the same socket.
- **Accept:** API connects to the Unix socket on weather-dev and receives loop packets. Packets flow through to the SSE endpoint. Auto-reconnect works when weewx restarts.
- **QC:** Opus verifies on weather-dev: restart weewx, confirm the API reconnects and SSE resumes.

### T3A.4 — Delete MQTT adapter

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3A.3 (direct adapter works)
- **Do:**
  1. Do NOT port `adapters/mqtt.py` to the API. MQTT is eliminated per FIX-007 decision.
  2. Do NOT add `paho-mqtt` to API dependencies.
  3. Remove any MQTT-related settings from the API's settings model (if any were added during this phase).
  4. Remove `mqtt_fields.py` from the migration scope — MQTT field name conversion is no longer needed.
- **Accept:** No MQTT code exists in the API. No paho-mqtt dependency. No MQTT settings.
- **QC:** Opus greps the API codebase for "mqtt", "paho", "MQTT" and confirms zero hits.

### T3A.5 — SSE infrastructure tests

- **Owner:** `test-author` (Sonnet)
- **Dep:** T3A.1, T3A.2, T3A.3
- **Do:**
  1. Unit tests: emitter subscribe/unsubscribe, fan-out to multiple subscribers, overflow handling, keepalive.
  2. Unit tests: direct adapter JSON line parsing, reconnect behavior.
  3. Integration test on weather-dev: connect to `/sse`, verify loop packets arrive, verify event format.
- **Accept:** All tests pass. Pytest output included.
- **QC:** Opus runs tests independently.

### Sub-phase 3B — Enrichment pipeline

### T3B.1 — Port packet tap registry

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3A.1
- **Do:**
  1. Port `enrichment/packet_tap.py` (processor registry) into API at `weewx_clearskies_api/sse/packet_tap.py`.
  2. The registry pattern: processors register as callbacks, invoked for every loop packet before fan-out.
- **Accept:** Registry module exists. Can register and invoke callbacks. Unit test.
- **QC:** Opus reads the module and confirms it matches the realtime version's interface.

### T3B.2 — Port all enrichment processors

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3B.1
- **Do:**
  1. Port ALL 12 enrichment processors into API under `weewx_clearskies_api/sse/enrichment/`:
     - `wind_rolling_window.py`
     - `lightning_strike_buffer.py`
     - `barometer_trend.py`
     - `input_smoother.py`
     - `uv_smoother.py`
     - `sky_condition.py`
     - `sky_tap.py`
     - `scene_enrichment.py`
     - `scene_packet_tap.py`
     - `weather_text.py`
     - `planet_viewing.py`
     - `temperature_comfort.py`
  2. Each processor is a straight port — preserve all logic, thresholds, and output field names.
  3. **Special case — scene_enrichment.py:** Currently makes HTTP calls back to the API (`/api/v1/almanac`, `/api/v1/forecast`). In the merged service, replace these HTTP calls with direct function calls to the API's internal service layer. Import the almanac and forecast service functions directly instead of making HTTP round-trips.
  4. Also port: `conditions_text.py`, `scene.py`.
- **Accept:**
  - All 12 processors exist in the API.
  - Scene enrichment uses internal function calls, not HTTP.
  - Each processor's output matches the realtime version's output for the same input.
  - Unit tests for each processor (can reuse/adapt realtime repo's tests).
- **QC:** Opus diffs 3+ processor files against the realtime originals and confirms logic preservation. Verifies scene_enrichment no longer imports httpx or makes HTTP calls.

### T3B.3 — Wire enrichment into API startup

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3B.2, T3A.3
- **Do:**
  1. In `__main__.py`, register all enrichment processors in the packet tap registry, matching the registration order from the realtime's `__main__.py` lines 262-327.
  2. Wire endpoint-level enrichments (barometer trend, wind rolling avg, lightning history, weather text, UV smooth, scene, planet viewing) to apply to the relevant REST endpoint responses.
  3. The enrichment registration must happen after settings load but before the app starts serving.
- **Accept:** All enrichments fire when loop packets arrive (verified via SSE output — packets include wind rolling avg, scene descriptor, etc.). REST endpoint responses include enrichment data (e.g., `/api/v1/current` includes `windSpeedAvg10m`, `lightningStrikeHistory`, `scene`).
- **QC:** Opus connects to `/sse` on weather-dev and verifies enriched fields are present in loop packets. Calls `/api/v1/current` and verifies enrichment fields.

### Sub-phase 3C — Unit conversion and derived values

### T3C.1 — Port unit conversion module

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3A.1
- **Do:**
  1. Port the entire `units/` module from realtime into API at `weewx_clearskies_api/units/`:
     - `conversion.py` — conversion formulas between units
     - `derived.py` — Beaufort scale, comfort index
     - `groups.py` — unit group definitions
     - `labels.py` — unit labels and formatting
     - `transformer.py` — UnitTransformer class (the main conversion engine)
  2. Preserve all conversion formulas, thresholds, and unit group mappings.
- **Accept:** Unit conversion module exists in API. Unit tests pass for: temperature conversions (F↔C↔K), speed conversions (mph↔km/h↔m/s↔knots), pressure conversions, all unit groups.
- **QC:** Opus runs unit conversion tests and verifies correct results for known reference values.

### T3C.2 — Wire unit conversion into API response pipeline

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3C.1
- **Do:**
  1. Every REST response that contains observation data must pass through UnitTransformer before reaching the client. This means: the API now does what the BFF did — converts from archive units to operator display units.
  2. Every SSE event must also pass through UnitTransformer.
  3. The `units` dict in responses reflects the operator's display units, not the archive units.
  4. This is the ADR-041 boundary collapse: the API is now both data access AND conversion authority.
- **Accept:**
  - REST responses contain values in the operator's display units (e.g., °F if US system configured).
  - SSE events contain values in the operator's display units.
  - The `units` dict matches the display units.
  - Values match what the realtime BFF was producing pre-migration (same numbers for the same input).
- **QC:** Opus compares 3+ endpoint responses (pre-migration from BFF vs post-migration from API) and confirms numerical values match.

### T3C.3 — Port derived value computation

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3C.1
- **Do:**
  1. The BFF injected derived values into every record: `beaufort` (from wind speed), `comfortIndex` ("windChill"/"heatIndex"/"none"), cardinal wind directions, barometer trend direction.
  2. These are now computed by UnitTransformer.transform_record() in the API.
  3. Verify: dashboard does NOT carry Beaufort thresholds (ADR-042 line 71). The API must inject `beaufort` — if it's missing, the dashboard can't compute it.
- **Accept:**
  - `beaufort` field present in observation responses and SSE events.
  - `comfortIndex` field present.
  - Cardinal wind directions present.
  - Dashboard renders these fields correctly (no regressions in wind display, comfort index display).
- **QC:** Opus loads the dashboard on weather-dev and verifies Beaufort scale and comfort index display correctly.

### T3C.4 — Port conditions text engine

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3B.2 (enrichment processors ported, conditions text uses them)
- **Do:**
  1. Port `conditions_text.py` from realtime into API.
  2. Wire into the enrichment pipeline — conditions text applies to current observation responses and SSE events.
- **Accept:** `weatherText` field present in responses with the same blended conditions text as the realtime service produced.
- **QC:** Opus compares conditions text output pre/post migration.

### Sub-phase 3D — Cleanup and routing

### T3D.1 — Remove BFF proxy

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T3C.2 (API now does conversion directly)
- **Do:**
  1. The BFF proxy (`proxy.py`) forwarded `/api/v1/*` to the upstream API and applied conversion. This is no longer needed — the API serves and converts directly.
  2. Verify: no proxy-related code exists in the API. The API's routers serve endpoints directly.
- **Accept:** No proxy code in the API. All `/api/v1/*` endpoints are served by the API's own routers.
- **QC:** Opus greps for "proxy", "upstream", "forward" in the API codebase and confirms no proxy logic.

### T3D.2 — Update Caddy routing

- **Owner:** `stack-dev` (Sonnet)
- **Dep:** T3D.1
- **Do:**
  1. In `weewx-clearskies-stack`, update the Caddyfile(s):
     - `/api/v1/*` routes to API (port 8765) instead of realtime (port 8766).
     - `/sse` routes to API (port 8765) instead of realtime (port 8766).
     - Port 8766 is no longer referenced anywhere.
  2. Update any docker-compose proxy configs.
  3. On weather-dev: update the Caddy config and reload.
- **Accept:**
  - All Caddyfile references to port 8766 removed.
  - `/api/v1/*` and `/sse` both route to port 8765.
  - Dashboard loads correctly on weather-dev after the routing change.
- **QC:** Opus loads the dashboard on weather-dev and confirms all API calls and SSE connection succeed through the new routing.

### T3D.3 — Update ADRs and ARCHITECTURE.md

- **Owner:** `docs-author` (Sonnet)
- **Dep:** T3D.2
- **Do:**
  1. Update ADR-005 status to "Superseded by ADR-0XX" (the Phase 1 folding ADR).
  2. Amend ADR-041: the computation boundary is now internal to the API. API does data access AND conversion.
  3. Amend ADR-034: topology simplifies — no realtime container. Port registry loses port 8766 and 8082.
  4. Update `docs/ARCHITECTURE.md`: remove realtime service from the Services table, Container inventory, topology diagram. Update layer responsibilities (API now does conversion). Update port registry (remove 8766, 8082). Update "Last verified" date.
  5. Update the Clear Skies plan components table: 5 repos → 4 (realtime removed).
- **Accept:**
  - ADR-005 shows Superseded status.
  - ADR-041 reflects merged computation boundary.
  - ADR-034 topology has no realtime container.
  - ARCHITECTURE.md is fully updated and internally consistent.
  - No reference to port 8766 or 8082 anywhere in docs.
- **QC:** Opus greps all docs/ files for "8766", "8082", "realtime" and confirms no stale references (except historical decision-log entries).

### T3D.4 — Update docker-compose

- **Owner:** `stack-dev` (Sonnet)
- **Dep:** T3D.2
- **Do:**
  1. Remove the realtime container definition from docker-compose.
  2. Remove port 8766 and 8082 from all compose files.
  3. Update any health check references that pointed to realtime.
  4. Verify: `docker compose config` produces valid output with no realtime references.
- **Accept:** No realtime container in compose. No port 8766 or 8082. `docker compose config` valid.
- **QC:** Opus runs `docker compose config` and confirms.

### T3D.5 — Deprecate weewx-clearskies-realtime repo

- **Owner:** `docs-author` (Sonnet)
- **Dep:** T3D.3
- **Do:**
  1. Update the realtime repo's README to state: "DEPRECATED — this service has been merged into weewx-clearskies-api. See ADR-0XX."
  2. Archive the repo on GitHub (do NOT delete — there may be forks or references).
  3. Remove the realtime systemd service on weather-dev: `systemctl stop weewx-clearskies-realtime && systemctl disable weewx-clearskies-realtime`.
- **Accept:** Realtime repo README shows deprecation notice. Systemd service stopped and disabled on weather-dev. Realtime process no longer running.
- **QC:** Opus checks weather-dev: `ps aux | grep realtime` shows no process. `systemctl status weewx-clearskies-realtime` shows disabled.

### T3D.6 — Full integration test

- **Owner:** `test-author` (Sonnet)
- **Dep:** T3D.1 through T3D.5
- **Do:**
  1. On weather-dev with the merged API deployed:
     - Run the full pytest suite for the API repo. Document pass/fail counts.
     - Connect to `/sse` and verify loop packets arrive with enrichment fields (wind rolling avg, scene, beaufort, conditions text, lightning history, etc.).
     - Call all major REST endpoints (`/api/v1/current`, `/api/v1/observations`, `/api/v1/forecast`, `/api/v1/aqi/current`, `/api/v1/almanac`, `/api/v1/earthquakes`, etc.) and verify responses include unit-converted values.
     - Load the dashboard in a browser and verify: real-time updates work (SSE), all pages render, all data displays correctly, no console errors.
     - Compare 3+ endpoint responses against pre-migration baseline values (captured before Phase 3 started).
  2. Document any regressions found and fix them before closing this task.
- **Accept:**
  - Pytest: all tests pass (zero failures, zero errors).
  - SSE: loop packets arrive with all enrichment fields.
  - REST: all endpoints return unit-converted values.
  - Dashboard: loads, real-time updates work, all pages render.
  - Pre/post-migration values match for compared endpoints.
  - Zero regressions.
- **QC:** Opus independently runs pytest, connects to SSE, calls 3+ endpoints, and loads the dashboard. Confirms all pass.

---

## Phase 4 — AQI multi-jurisdiction + multi-source (FIX-003 + FIX-004)

**Dep:** T1.4 ADR Accepted. Phase 3 complete (AQI code is now in the merged API).

**Architecture:** Providers compute AQI natively — we do NOT compute AQI indices ourselves. Each provider supports different scales (Aeris: 8 regional filters; OpenMeteo: US+European; IQAir: US+China; OWM: own 1-5). The `aqiScale` field carries whatever scale the provider returned. See T0.4 findings and updated `docs/reference/api-docs/` for per-provider details.

### Sub-phase 4A — Schema changes

### T4A.1 — Add NO and NH3 to AQI schema

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T1.4 ADR Accepted
- **Backlog:** FIX-003
- **Do:**
  1. In `models/responses.py`, add to `AQIReading`:
     - `pollutantNO: float | None = None` — µg/m³ (group_concentration)
     - `pollutantNH3: float | None = None` — µg/m³ (group_concentration)
  2. Update the `units` dict in `AQIResponse` to include entries for the new fields when non-null.
  3. Update the canonical data model spec (`docs/contracts/canonical-data-model.md`) to include the new fields.
- **Accept:** AQIReading has 8 pollutant fields (PM2.5, PM10, O3, NO2, SO2, CO, NO, NH3). Existing tests pass (new fields are optional/nullable).
- **QC:** Opus reads the updated model and confirms both fields are present, nullable, with correct type annotations.

### Sub-phase 4B — Provider changes

### T4B.1 — Update providers to pass through all pollutants and native scale

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T4A.1, T0.4 (per-provider docs)
- **Backlog:** FIX-003
- **Do:**
  For each AQI provider, update the canonical translation to:
  1. **Stop dropping pollutant data.** Pass through everything the provider returns.
  2. **Pass through the provider's native `aqiCategory`** instead of nulling it. Each provider returns category names — use them.
  3. **Set `aqiScale` to the provider's actual scale** (not hardcoded "epa").
  4. Per-provider specifics (reference `docs/reference/api-docs/` for wire shapes):
     - **OWM:** Map `components.no` → `pollutantNO`, `components.nh3` → `pollutantNH3` (currently dropped). Pass `aqiScale: "owm"`. Derive category from OWM 1-5 value (Good/Fair/Moderate/Poor/Very Poor).
     - **OpenMeteo:** Map `nitrogen_monoxide` → `pollutantNO`. NH3 (`ammonia`) is Europe-only — map when non-null. Pass `aqiScale: "epa"` when using `us_aqi`, `"eaqi"` when using `european_aqi`.
     - **Aeris:** No NO or NH3 in wire response (7 pollutants only). Pass `aqiScale` matching the `method` field from the response (e.g., `"airnow"`, `"india"`, `"eaqi"`). Pass `category` directly.
     - **IQAir:** No NO or NH3 available. Pass `aqiScale: "epa"` for `aqius`, `"mep"` for `aqicn` (determined by provider config).
- **Accept:**
  - OWM responses include `pollutantNO` and `pollutantNH3`.
  - OpenMeteo responses include `pollutantNO` (and `pollutantNH3` when available).
  - `aqiCategory` is non-null from all providers.
  - `aqiScale` reflects the provider's actual scale.
  - No provider drops any pollutant data.
  - Existing provider tests updated and passing.
- **QC:** Opus reads each provider's mapping function and confirms NO/NH3 pass-through and correct `aqiScale` values.

### T4B.2 — Add provider-specific AQI regional configuration

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T4B.1
- **Backlog:** FIX-003
- **Do:**
  1. **Aeris:** Add `aqi_filter` setting to Aeris provider config. Type: string, one of `airnow|china|india|eaqi|caqi|uk|de|cai`. Default: `airnow`. Pass as `filter=` parameter on the API call. The Aeris `filter` does NOT auto-detect by location — it must be configured explicitly.
  2. **OpenMeteo:** Add `aqi_index` setting to OpenMeteo provider config. Type: string, one of `us_aqi|european_aqi`. Default: `us_aqi`. Determines which AQI variable to request.
  3. **IQAir:** Add `aqi_scale` setting to IQAir provider config. Type: string, one of `us|cn`. Default: `us`. Determines whether to read `aqius` or `aqicn` from the response (both are always returned).
  4. **OWM:** No regional configuration — OWM always returns its own 1-5 scale.
- **Accept:**
  - Aeris module passes the configured `filter` parameter. Changing filter changes the `aqi`, `category`, `color`, `method` in the response.
  - OpenMeteo module requests the configured AQI variable.
  - IQAir module reads the configured AQI field.
  - Each provider's regional config persists in `api.conf` under the provider's section.
- **QC:** Opus configures Aeris with `filter=india` and verifies the response carries Indian AQI categories.

### T4B.3 — Multi-source pollutant merge (FIX-004)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T4A.1
- **Backlog:** FIX-004
- **Do:**
  1. The AQI endpoint must merge pollutant data from the provider API response AND weewx-mapped DB columns.
  2. If IQAir returns AQI=52 with no per-pollutant data, but the operator has weewx columns mapped to PM2.5, O3, NO2, etc. — the response should include the AQI value from IQAir AND the pollutant concentrations from the mapped DB columns.
  3. Merge priority: provider value wins if both sources supply the same pollutant. DB-mapped value fills in gaps.
  4. Add `pollutantSources: dict[str, str]` field to AQIReading — e.g., `{"pollutantPM25": "weewx", "pollutantO3": "weewx", "aqi": "iqair"}`. This tells the dashboard (and the operator) where each value came from.
- **Accept:**
  - An operator using IQAir for headline AQI + weewx OWM plugin for pollutant detail sees both in the same response.
  - `pollutantSources` correctly identifies the source of each field.
  - If both provider and DB supply the same pollutant, provider wins.
  - Existing tests pass. New test for the merge case.
- **QC:** Opus calls `/api/v1/aqi/current` on weather-dev with IQAir configured and weewx pollutant columns mapped, verifies the merge.

### Sub-phase 4C — Wizard and Dashboard

### T4C.1 — Wizard AQI provider regional config

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T4B.2
- **Backlog:** FIX-003
- **Do:**
  1. In the wizard's provider selection step (step 6), when an AQI provider is selected, show the provider-specific regional configuration inline:
     - **Aeris:** Dropdown with 8 filter options (US EPA, China, India, EU EAQI, EU CAQI, UK, Germany, South Korea). Auto-suggest based on station lat/lon → country.
     - **OpenMeteo:** Toggle between US AQI and European AQI. Auto-suggest based on station location.
     - **IQAir:** Toggle between US EPA and China MEP. Auto-suggest based on station location.
     - **OWM:** No regional option (inform operator that OWM uses its own 1-5 scale).
  2. Save the provider-specific regional setting to `api.conf` via `/setup/apply`.
- **Accept:**
  - Aeris AQI filter selection visible when Aeris is chosen as AQI provider.
  - Auto-suggestion works based on station coordinates.
  - Operator can override the suggestion.
  - Selection persists in API config after Apply.
- **QC:** Opus walks through the wizard, selects Aeris with `india` filter, verifies persistence.

### T4C.2 — Dashboard AQI card multi-scale rendering

- **Owner:** `dashboard-dev` (Sonnet)
- **Dep:** T4B.1, T4B.3
- **Backlog:** FIX-003, FIX-004
- **Do:**
  1. The AQI card currently expects EPA-only categories. Update to render based on `aqiScale`:
     - Category text shows the provider's category names (passed through in `aqiCategory`).
     - Color bands use the provider's color scheme (Aeris returns `color` hex per category; other providers need a scale→color mapping in the dashboard).
  2. All available pollutants always shown — the scale governs which are "primary" (part of the AQI calculation) vs "supplementary" (displayed but not banded).
  3. If `pollutantSources` is present, show a subtle source indicator (e.g., small icon or tooltip distinguishing provider vs weewx data).
  4. Expand/detail view renders whenever any pollutant concentration is non-null, regardless of source.
  5. Handle scale-specific display: OWM 1-5 ordinal renders differently from EPA 0-500 or CAQI 0-100+. UK DAQI 1-10 and qualitative scales (EAQI, German LQI) need appropriate rendering.
- **Accept:**
  - AQI card renders correctly for EPA, European, OWM, Indian, Chinese scales.
  - Category names and colors match the provider's scale.
  - All available pollutants shown.
  - Expand view shows when any pollutant data exists.
  - No desktop regression.
- **QC:** Opus loads the dashboard with different provider configurations and verifies card rendering for each scale.

---

## Phase 5 — Security audit and permissions model (FIX-008 + FIX-011)

Comprehensive security review of the final (post-merge) architecture, followed by hardening implementation.

**Dep:** Phase 3 complete (final architecture established). T1.5 and T1.6 ADRs Accepted.

### Sub-phase 5A — Audit

### T5A.1 — Input validation sweep

- **Owner:** `auditor` (Sonnet)
- **Dep:** Phase 3 complete
- **Backlog:** FIX-008
- **Do:**
  1. Review every REST endpoint in the API for input validation:
     - Query params: are they typed via Pydantic? Is `extra="forbid"` set?
     - Path params: are they constrained (e.g., provider IDs validated against registry)?
     - Request bodies: are they validated?
  2. Check column mapping names (from wizard setup): are they parameterized in SQL queries or string-interpolated?
  3. Check file upload paths (logo upload in branding): is path traversal prevented?
  4. Check any endpoint that accepts time ranges or observation type names: can these construct injection attacks?
  5. Document: endpoint path, input type, validation method, finding (pass/fail/concern).
- **Accept:** Per-endpoint validation matrix. All SQL uses parameterized queries (zero string interpolation). All file paths validated. All findings documented with severity.
- **QC:** Opus reviews the matrix and spot-checks 5+ endpoints against source code. Confirms SQL parameterization claim.

### T5A.2 — Authentication boundary review

- **Owner:** `auditor` (Sonnet)
- **Dep:** Phase 3 complete
- **Backlog:** FIX-008
- **Do:**
  1. Catalog every endpoint as public or admin-requiring. Document which endpoints have no auth check.
  2. Verify: wizard/config/admin endpoints require authentication (ProxyAuth or setup token).
  3. Verify: API keys are never exposed in responses (check for credential leakage in error messages, debug output, etc.).
  4. Verify: SSE connections are rate-limited and have a max connection count.
- **Accept:** Endpoint auth classification matrix. No credential leakage found. SSE rate limiting documented.
- **QC:** Opus attempts to access admin endpoints without auth and confirms they're rejected.

### T5A.3 — DoS vector assessment

- **Owner:** `auditor` (Sonnet)
- **Dep:** Phase 3 complete
- **Backlog:** FIX-008
- **Do:**
  1. Test expensive queries: request aggregation over entire archive history. Measure response time and CPU usage. Is there a query timeout?
  2. Test SSE connection flooding: open 100+ concurrent SSE connections. Does the server enforce a limit? Is there backpressure?
  3. Test large response attacks: craft a request that produces the largest possible response. Is there a response size limit?
  4. Document: vector, current behavior, risk level, recommended mitigation.
- **Accept:** Per-vector assessment with current behavior documented. Recommendations for mitigations (query timeout, SSE connection limit, response size limit).
- **QC:** Opus reviews the assessment and confirms tests were actually run (not theoretical).

### T5A.4 — weewx-specific risk assessment

- **Owner:** `auditor` (Sonnet)
- **Dep:** Phase 2 (co-location), Phase 3 (merged service)
- **Backlog:** FIX-008
- **Do:**
  1. Verify: the API cannot modify weewx.conf (check file permissions on weather-dev + code review for any weewx.conf write operations).
  2. Verify: the API cannot restart or stop weewx (no subprocess calls, no systemd interactions).
  3. Verify: the API cannot execute arbitrary Python through the weewx import path (only `weewx.units` is imported; no `weewx.engine`, `weewx.drivers`, `weewx.manager`).
  4. Verify: the API has read-only DB access (write probe exits on write success).
  5. Document each verification with the evidence (command output, code reference).
- **Accept:** All 4 verifications pass with evidence. Any exceptions documented with risk assessment and mitigation.
- **QC:** Opus independently runs the verifications on weather-dev.

### T5A.5 — Caddy/proxy audit

- **Owner:** `auditor` (Sonnet)
- **Dep:** T3D.2 (Caddy routing updated)
- **Backlog:** FIX-008
- **Do:**
  1. Review Caddy configuration for: TLS version (1.2+ minimum), HSTS headers, CSP, X-Frame-Options, X-Content-Type-Options, Referrer-Policy.
  2. Verify: only intended API paths are proxied (no wildcard proxy to backend).
  3. Verify: request size limits enforced by Caddy before reaching API.
  4. Verify: admin endpoints blocked at the proxy level (defense in depth — both Caddy and API enforce auth).
  5. Document findings.
- **Accept:** Caddy configuration review with per-header/per-rule assessment. Any missing security headers documented.
- **QC:** Opus reads the Caddyfile and confirms the assessment.

### T5A.6 — Dependency audit

- **Owner:** `auditor` (Sonnet)
- **Dep:** Phase 3 complete
- **Backlog:** FIX-008
- **Do:**
  1. Run `pip-audit` on the merged API repo on weather-dev. Document all findings.
  2. Run `npm audit` on the dashboard repo. Document all findings.
  3. Check: are dependencies pinned with exact versions? Are there lockfiles?
  4. Check: is `gitleaks` running in CI for all repos?
- **Accept:** pip-audit and npm-audit output included. All HIGH/CRITICAL findings have remediation plans. Dependency pinning status documented.
- **QC:** Opus reviews the audit output and confirms all HIGH/CRITICAL findings are addressed.

### Sub-phase 5B — Permissions implementation

### T5B.1 — Create clearskies system user

- **Owner:** `stack-dev` (Sonnet)
- **Dep:** T1.6 ADR Accepted
- **Backlog:** FIX-011
- **Do:**
  1. On weather-dev: create system user `clearskies` with no login shell, dedicated home directory.
  2. Create group `clearskies`.
  3. Document the user/group creation commands for the install script.
  4. Update the API systemd unit: `User=clearskies`, `Group=clearskies`.
- **Accept:** `id clearskies` shows the user exists. API runs as `clearskies` user (verified via `ps aux`).
- **QC:** Opus verifies on weather-dev: `ps aux | grep clearskies-api` shows `clearskies` user.

### T5B.2 — Set directory permissions

- **Owner:** `stack-dev` (Sonnet)
- **Dep:** T5B.1
- **Backlog:** FIX-011
- **Do:**
  1. On weather-dev, set permissions per the T1.6 ADR's directory permissions table:
     - `/etc/weewx-clearskies/` → `clearskies:clearskies`, mode 0750
     - `secrets.env` → mode 0600
     - `*.conf` → mode 0640
     - `uploads/` → mode 0750, noexec (mount option or filesystem attribute)
  2. Verify the API can still read its config and secrets after the permission change.
  3. Verify the wizard can still write config files after the permission change.
- **Accept:** `ls -la /etc/weewx-clearskies/` shows correct ownership and modes. API starts successfully. Wizard Apply succeeds.
- **QC:** Opus runs `ls -la /etc/weewx-clearskies/` and verifies permissions match the ADR.

### T5B.3 — weewx DB read-only access

- **Owner:** `stack-dev` (Sonnet)
- **Dep:** T5B.1
- **Backlog:** FIX-011
- **Do:**
  1. If using SQLite: ensure the `clearskies` user has read-only access to the weewx `.sdb` file (group read, not write). The `clearskies` user should be in a read-only group, NOT the `weewx` group.
  2. If using MariaDB: verify the API's DB user has SELECT-only privileges on the weewx database. Document the GRANT statement.
  3. Verify: the startup write probe (db/probe.py) still correctly detects and rejects write access.
- **Accept:** `clearskies` user cannot write to the weewx DB (verified by attempting a write). Write probe still fires correctly.
- **QC:** Opus attempts a write operation as the clearskies user and confirms it's rejected.

### T5B.4 — Systemd hardening

- **Owner:** `stack-dev` (Sonnet)
- **Dep:** T5B.1
- **Backlog:** FIX-008, FIX-011
- **Do:**
  1. Add all hardening flags from the security baseline to the API's systemd unit file:
     - `NoNewPrivileges=yes`
     - `ProtectSystem=strict`
     - `ProtectHome=yes`
     - `PrivateTmp=yes`
     - `ProtectKernelTunables=yes`
     - `ProtectKernelModules=yes`
     - `ProtectControlGroups=yes`
     - `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX`
     - `RestrictNamespaces=yes`
     - `LockPersonality=yes`
     - `MemoryDenyWriteExecute=yes`
     - `CapabilityBoundingSet=` (empty)
     - `AmbientCapabilities=` (empty)
     - `SystemCallFilter=@system-service`
     - `SystemCallErrorNumber=EPERM`
     - `ReadWritePaths=/etc/weewx-clearskies /tmp` (only paths the API needs to write)
  2. Restart the API and verify it starts successfully with all flags.
  3. Verify: the API cannot access files outside its allowed paths (e.g., cannot read /etc/shadow).
- **Accept:** All hardening flags present in the unit file. API starts and runs normally. Filesystem access is restricted.
- **QC:** Opus reads the systemd unit file and confirms all flags are present. Restarts the API and verifies it works.

### T5B.5 — Docker hardening

- **Owner:** `stack-dev` (Sonnet)
- **Dep:** T5B.1
- **Backlog:** FIX-008, FIX-011
- **Do:**
  1. Update the API Dockerfile: add `USER clearskies` (non-root).
  2. Update docker-compose: add `cap_drop: [ALL]`, `read_only: true`, `security_opt: [no-new-privileges:true]`, `tmpfs: [/tmp]`.
  3. Volume mounts: `/etc/weewx-clearskies` read-write, weewx DB read-only.
  4. Verify: `docker compose up` starts successfully with all hardening.
- **Accept:** Docker container runs as non-root with all hardening flags. API functions correctly.
- **QC:** Opus runs `docker exec <container> whoami` and confirms non-root. Verifies read-only filesystem by attempting to write outside allowed paths.

### T5B.6 — Wizard TLS configuration step

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T5B.5 (Docker hardening — Caddy image variant depends on TLS path)
- **Backlog:** FIX-008
- **Do:**
  1. Add a TLS configuration step to the wizard. Operator selects one of three paths:
     - **ACME / Let's Encrypt (HTTP-01):** Collect domain name and email for LE account. Generate Caddyfile with `tls {email}`. For publicly reachable servers.
     - **DNS-01 challenge:** Collect domain name, DNS provider (Cloudflare, Route53, Google Cloud DNS, DigitalOcean, Namecheap), and provider API credentials. Generate Caddyfile with `tls { dns {provider} {credentials} }`. Update compose to use the provider-specific Caddy image (e.g., `caddy-dns/cloudflare`).
     - **Behind existing reverse proxy:** Operator confirms external proxy handles TLS. Generate Caddyfile with HTTP-only listener.
  2. **No self-signed option.** No manual cert upload option. Both produce browser warnings or become impractical with short-lived certs (47-day lifetimes).
  3. Store the TLS configuration in `stack.conf` under `[tls]` section. Persist the selected path and credentials so the wizard can pre-fill on re-run.
  4. DNS provider API credentials stored in `secrets.env` (never in `.conf`).
  5. For DNS-01 path: verify the selected DNS provider image is available, and document how to pull the correct Caddy variant.
- **Accept:**
  - Wizard presents three TLS paths with clear descriptions.
  - ACME path: Caddyfile generated with domain + email. Caddy auto-issues cert on first start.
  - DNS-01 path: Caddyfile generated with DNS provider config. Correct Caddy image referenced in compose.
  - Proxy path: Caddyfile generated HTTP-only.
  - No self-signed or manual cert upload options offered.
  - Credentials persisted in `secrets.env`, not `.conf`.
- **QC:** Opus walks through each TLS path in the wizard and verifies the generated Caddyfile is correct for each.

### T5B.7 — Distill security rules into coding.md

- **Owner:** `docs-author` (Sonnet)
- **Dep:** T5A.1 through T5A.6 (audit findings), T5B.1 through T5B.6 (implementation)
- **Backlog:** FIX-011
- **Do:**
  1. Add a security section to `rules/coding.md` with enforceable rules derived from the security ADR and audit findings:
     - "Never open a file for writing outside `/etc/weewx-clearskies/` or the configured upload directory"
     - "Never use the weewx DB connection for INSERT/UPDATE/DELETE on weewx-owned tables"
     - "Never import or call weewx engine/driver modules from API code — only `weewx.units` for metadata"
     - "All file paths from user input must be validated against an allowlist — no path traversal"
     - "All new endpoints must declare whether they are public or admin-only; admin endpoints require auth check"
     - "Uploaded files land in the uploads directory with noexec; never serve uploaded content with executable MIME types"
     - "All SQL queries use SQLAlchemy parameterized statements — no string interpolation of user input into SQL"
  2. These rules are what agents and developers read before writing code. The ADR is the rationale; the rules file is the enforcement.
- **Accept:** Security rules section exists in `rules/coding.md`. Each rule is one sentence, actionable, enforceable. Rules cover all major attack surfaces identified in the audit.
- **QC:** Opus reads the rules section and confirms each rule maps to a specific audit finding or ADR requirement.

### T5B.8 — Update security baseline contract

- **Owner:** `docs-author` (Sonnet)
- **Dep:** T5A.1 through T5A.6 (audit findings), T5B.1 through T5B.7 (implementation), ADR-058 (realtime merged), ADR-060 (security model)
- **Backlog:** FIX-008
- **Do:**
  1. Update `docs/contracts/security-baseline.md` to reflect the post-merge architecture:
     - Fold §4 (weewx-clearskies-realtime) into §3 (weewx-clearskies-api) — the realtime service no longer exists as a separate component.
     - Add SSE-specific controls to §3: connection limits per IP, backpressure, idle timeout, rate limiting on connection establishment (not per event).
     - Update port references: remove 8766 and 8082 (realtime ports). SSE is now on port 8765 with the API.
     - Add Caddy security controls: TLS 1.2+ minimum, HSTS, CSP, path allowlist, admin endpoint blocking.
     - Add inter-component trust section: Caddy→API (TLS + proxy secret), API→Redis (loopback), API→weewx (read-only import boundary).
     - Update the CI gating table (§7) to reflect merged repos.
     - Reference ADR-060 as the threat model source.
  2. Verify the updated baseline is internally consistent — no stale references to the realtime service, no orphaned port numbers, no controls that reference a deleted component.
- **Accept:** Security baseline updated. No references to realtime as a separate service. SSE controls present. Caddy controls present. Inter-component trust documented. Port registry consistent with ARCHITECTURE.md.
- **QC:** Opus reads the updated baseline and greps for stale references (8766, 8082, "realtime" as a separate service, §4 header).

---

## Dependency graph

```
Phase 0 (Research — all 6 tasks parallel)
T0.1 realtime inventory ─┐
T0.2 API extensibility ──┤
T0.3 weewx import ───────┤
T0.4 AQI research ───────┤
T0.5 security baseline ──┤
T0.6 deployment state ───┘
         │
         ▼
Phase 1 (ADRs — sequential, each needs user approval)
T1.1 co-location ADR (dep: T0.3) ─────────────────────────┐
T1.2 application layer ADR (dep: T0.4) ───────────────────┤
T1.3 realtime folding ADR (dep: T0.1, T0.2) ──────────────┤
T1.4 AQI multi-jurisdiction ADR (dep: T0.4) ──────────────┤
T1.5 security model ADR (dep: T0.5, T0.6) ────────────────┤
T1.6 permissions model ADR (dep: T0.6) ───────────────────┘
         │
         ├─────────────────────────────────────┐
         ▼                                     ▼
Phase 2 (Co-location)                   Phase 4A-4B (AQI schema+providers)
T2.1 → T2.2 → T2.3 → T2.4             T4A.1 → T4B.1 → T4B.2 → T4B.3
  → T2.5 → T2.6 → T2.7 → T2.8
         ▼                                     │
Phase 3 (Realtime folding)                     │
3A: T3A.1→T3A.2→T3A.3→T3A.4→T3A.5            │
3B: T3B.1→T3B.2→T3B.3                          │
3C: T3C.1→T3C.2→T3C.3→T3C.4                   │
3D: T3D.1→T3D.2→T3D.3→T3D.4→T3D.5→T3D.6      │
         │                                     │
         ├─────────────────────────────────────┘
         ▼
Phase 4C (AQI wizard+dashboard — needs merged API)
T4C.1 → T4C.2
         │
         ▼
Phase 5 (Security — audits final architecture, LAST)
5A: T5A.1, T5A.2, T5A.3, T5A.4, T5A.5, T5A.6 (parallel audit)
         │
         ▼
5B: T5B.1 → T5B.2 → T5B.3
    T5B.4, T5B.5 (parallel with T5B.2-3)
         │
         ▼
    T5B.6 (rules — last, after all audit + implementation)
```

**Note:** Phase 4A-4B (AQI schema + provider changes) can start after T1.4 ADR is approved, in parallel with Phase 3. AQI code is already in the API, so provider changes don't conflict with realtime folding. Phase 4C (wizard + dashboard AQI rendering) waits for Phase 3 completion because the wizard needs the merged API.

---

## Verification bar — plan-level "done" definition

The plan is complete when ALL of the following are true:

- **Co-location:** `import weewx.units` works from the API's Python environment. Column mapping includes auto-detected units from obs_group_dict. Units persist in config.
- **Realtime merged:** The `weewx-clearskies-realtime` service is stopped, disabled, and deprecated. The API serves both REST and SSE. All 12 enrichment processors run in the API. Unit conversion happens in the API. MQTT code is deleted.
- **AQI multi-jurisdiction:** Providers compute AQI natively — no breakpoint tables or computation engine. Aeris `filter` parameter configurable in wizard (8 regional options). OpenMeteo `us_aqi`/`european_aqi` selectable. IQAir `aqius`/`aqicn` selectable. `aqiScale` carries the provider's actual scale. `aqiCategory` passed through from provider. NO and NH3 pollutants no longer dropped. AQI card renders per `aqiScale`.
- **AQI multi-source:** Provider AQI + weewx DB pollutant data merged in the same response. `pollutantSources` field identifies where each value came from. AQI card expand view shows all available pollutants regardless of source.
- **Security:** Audit completed with per-endpoint validation matrix, auth boundary review, DoS assessment, weewx risk assessment, Caddy review, dependency audit. All HIGH/CRITICAL findings remediated.
- **Permissions:** `clearskies` system user exists. Directory permissions match ADR. weewx DB is read-only for the API. Systemd hardening flags applied. Docker hardening configured. Security rules in `rules/coding.md`.
- **ADRs:** 6 new ADRs Accepted. ADR-005 Superseded. ADR-013, ADR-034, ADR-041 Amended. ARCHITECTURE.md updated.
- **Tests:** Full pytest suite passes on weather-dev with zero failures. SSE verified. Dashboard loads with all features working.
- **No regressions:** Pre/post-migration endpoint responses match. Dashboard functionality unchanged from user perspective (except new AQI features).
