# EXTENSION-HARDENING-PLAN-2 — Site restoration, extension debugging, vocabulary & ADR consolidation

**Goal:** (1) Restore the broken Clear Skies site by fixing the Caddyfile routing gap left by the ADR-058 implementation and removing the erroneous API instance on weather-dev, (2) debug and verify the hardened ClearSkiesLoopRelay extension's socket data flow, (3) complete Phase 2-3 integration tests from the original EXTENSION-HARDENING-PLAN, (4) standardize vocabulary across all project documentation, and (5) consolidate 62 individual ADRs into a small set of logical documents with flowcharts.

**Status:** Phases 1-3 complete. Phase 4 complete. Phases 5-6 remaining.

**Source:** EXTENSION-HARDENING-PLAN Phases 2-3 (incomplete), post-ADR-058 deployment gap (Caddyfile still routes to port 8766), vocabulary inconsistency incident (2026-06-14).

**Repos involved:**
- `weewx-clearskies-extension` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-extension`) — hardened extension code (Phase 1 complete, uncommitted)
- `weewx-clearskies-api` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-api`) — reference for socket client code, SSE pipeline
- `weewx-clearskies-stack` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-stack`) — Caddyfile source of truth
- `weather-belchertown` (local: `c:\CODE\weather-belchertown`) — ADRs, ARCHITECTURE.md, security baseline, procedures, plans

**Dev/test environment:** Two containers on the Ratbert LXD host:
- `weewx` container (192.168.7.20) — weewx engine, production API (port 8765, TLS), Redis, Unix socket. SSH: `ssh -F .local/ssh/config weewx "<cmd>"`. Services: `weewx.service`, `weewx-clearskies-api.service`.
- `weather-dev` container (192.168.2.113) — Caddy (port 80), dashboard (static SPA), config UI (port 9876). SSH: `ssh -F .local/ssh/config weather-dev "<cmd>"`. Services: `caddy.service`, `weewx-clearskies-config.service`.

**NOTE: weather-dev must NOT run `weewx-clearskies-api.service`.** An API instance was erroneously deployed there during a prior session. It must be stopped, disabled, and removed. The only API instance is on the weewx container.

---

## Execution context for new sessions

**What happened before this plan:**

1. **ADR-058 implementation (FIXIT-ARCHITECTURE-PLAN, completed prior sessions):** The separate realtime service's code was merged into the API. The API now handles everything the old realtime service did: reading loop packets from the Unix socket, running 12 enrichment processors, applying unit conversion, serving SSE events, and proxying REST responses with converted units. MQTT support was eliminated. The old `weewx-clearskies-realtime` repo was archived. The realtime systemd service on weather-dev was stopped and disabled.

2. **Deployment errors from ADR-058 implementation (prior sessions):** Two mistakes were made:
   - The Caddyfile on weather-dev was left pointing to `localhost:8766` (the old realtime port) instead of being updated to route to the production API on the weewx container at `https://192.168.7.20:8765`. The API was NEVER on weather-dev — it has always been on the weewx container. Routing to localhost was always wrong.
   - An API instance (`weewx-clearskies-api.service`) was erroneously deployed on weather-dev at port 8765 with `[input] enabled = false`. This was never supposed to exist. The only API instance belongs on the weewx container.
   - Combined result: Caddy routes to localhost:8766 (nothing there), site is broken. The erroneous API on localhost:8765 sits unused because Caddy doesn't even route to it.

3. **Extension hardening Phase 1 (this session, completed):** All 9 code-level audit findings were fixed in `clearskies_relay.py`. The hardened code was deployed to the weewx container via SCP, replacing the old 142-line version with the new 207-line version. weewx was restarted. The extension loads successfully (weewx logs show the new INFO message: `ClearSkiesLoopRelay listening on /var/run/weewx-clearskies/loop.sock (mode=0660, group=weewx)`). The API's socket reader connected to the socket (API log: `Connected to weewx relay socket`).

4. **Socket data flow issue:** Despite the extension loading and the API connecting, a raw socket test (Python `connect()` + 15-second `recv()`) received NO data. The SSE endpoint on the API shows keepalive pings but no loop events. MQTT publishing proves weewx IS generating loop packets every 5 seconds. The hardened extension may have a bug that prevents it from broadcasting data to connected socket clients. This must be debugged — no reversion to the old code.

5. **Extension hardening Phase 4 (this session, completed):** All 5 documentation tasks completed. ADR-061 amended (contradiction fixed — `clearskies` needs `weewx` group for socket access). ARCHITECTURE.md updated with extension repo. Security baseline §3.10 added. Deployment procedure written. Extension README and changelog updated. All changes are uncommitted.

6. **Vocabulary incident (this session):** Inconsistent terminology across all documentation caused the user to approve ADR-058 without understanding that the service the dashboard depends on (referred to variously as "BFF", "realtime service", "realtime/BFF") was being stopped. Terms like "API DirectAdapter" (a class name used as a component name) further obscured what was actually happening. The user has directed a full vocabulary audit and ADR consolidation.

**Current state of each container:**

| Container | Service | Status | Port | Notes |
|-----------|---------|--------|------|-------|
| weewx | `weewx.service` | active | — | Generating loop packets every 5s |
| weewx | `weewx-clearskies-api.service` | active | 8765 (TLS) | Production API with full BFF functionality. `[input] enabled = true, mode = direct`. Connected to socket. SSE shows keepalives but no events. |
| weewx | ClearSkiesLoopRelay (extension) | loaded | socket at `/var/run/weewx-clearskies/loop.sock` | Hardened v1.1.0. Accepts connections but may not be sending data. |
| weather-dev | `caddy.service` | active | 80 | Routes `/api/v1/*` and `/sse` to `localhost:8766` — **WRONG, nothing there**. Must route to `https://192.168.7.20:8765`. |
| weather-dev | `weewx-clearskies-api.service` | active | 8765 | **ERRONEOUS — must be stopped, disabled, and removed.** |
| weather-dev | `weewx-clearskies-realtime.service` | inactive (disabled) | — | Correctly stopped per ADR-058. |
| weather-dev | `weewx-clearskies-config.service` | active | 9876 | Config UI / wizard. |

**Uncommitted changes from this session:**

Extension repo (`repos/weewx-clearskies-extension/`):
- `bin/user/clearskies_relay.py` — hardened (9 findings fixed, 207 lines)
- `install.py` — config stanza updated, version 1.1.0
- `README.md` — Security, Permissions, Configuration sections added
- `changelog` — 1.1.0 entry

Meta repo (`.`):
- `docs/decisions/ADR-061-filesystem-permissions-model.md` — contradiction fixed
- `docs/ARCHITECTURE.md` — extension repo added to tables
- `docs/contracts/security-baseline.md` — §3.10 extension controls added
- `docs/procedures/install-weewx-extension.md` — new deployment procedure
- `docs/procedures/deploy-clearskies.md` — cross-reference added
- `docs/planning/EXTENSION-HARDENING-PLAN.md` — status updated

**Session 2 (2026-06-14) — what was completed:**

1. **Phase 1 complete.** Erroneous API on weather-dev stopped/disabled. Caddyfile corrected to route `/api/v1/*` and `/sse` to `https://192.168.7.20:8765`. Caddy user added to clearskies group (fixed 403 on branding.json/webcam.json). Deploy procedure updated. Stack repo Caddyfiles already correct.

2. **Phase 2 complete (socket data flow).** Root cause: stale `.pyc` bytecode cache caused the accept loop thread to die silently. Clearing pyc and restarting weewx restored data flow. The extension code itself was correct — `on_new_loop_packet` is called with clients connected, data broadcasts successfully. DIAG logging confirmed the flow. Accept loop hardened (partial — `except OSError: break` changed to only break on shutdown).

3. **Four additional bugs discovered during Phase 2 execution — Phase 2A added:**
   - Bug #1: Extension registered as `data_service` (fires before `StdWXCalculate`). Loop packet is missing derived values (barometer, dewpoint, appTemp, windchill). Old MQTT path was a `restful_service` and got the fully processed packet. Fix: move to `restful_services`.
   - Bug #2: Two competing unit authorities. `load_units_block()` reads weewx.conf at every API startup for REST labels. `UnitTransformer` reads `api.conf [units]` (which was EMPTY — wizard writes to `realtime.conf`). Fix: one transformer from `api.conf [units]`.
   - Bug #3: REST flattens ConvertedValue dicts to scalars. SSE sends ConvertedValue dicts. Dashboard components read labels from ConvertedValue objects via `asConverted()`. REST-sourced values have empty labels. Fix: unify shapes (requires ADR-010 amendment).
   - Bug #4: Accept loop `except OSError: break` too aggressive. Any transient error kills the thread permanently. Fix: only break on shutdown.

4. **Wizard stale references discovered — Phase 2B added:**
   - Wizard `config_writer.py` writes to `realtime.conf` (dead). `write_api_conf()` is `NotImplementedError("BUG A7")`.
   - Wizard step 5 still presents MQTT as input option (eliminated per ADR-058).
   - Wizard apply restarts `weewx-clearskies-realtime` service (doesn't exist).
   - Admin config UI reads/edits `realtime.conf` sections.
   - State model carries `realtime_bind_*`, `mqtt_*` fields.
   - Templates show stale "Restarting realtime service..." text.

5. **`rules/clearskies-process.md` corrected.** "Lead does NOT do research grunt work" rule rewritten: lead reads and researches when judgment depends on it, delegates mechanical/bulk work, asks user when unsure.

**Current state of containers after session 2:**

| Container | Service | Status | Notes |
|-----------|---------|--------|-------|
| weewx | `weewx.service` | active | Extension has DIAG logging + accept loop fix. Registered as `data_service` (needs move to `restful_services` in Phase 2A). |
| weewx | `weewx-clearskies-api.service` | active | `sse.py` deployed with ConvertedValue fix. `api.conf` manually edited with `[units]` section (temporary). |
| weather-dev | `caddy.service` | active | Routes to `https://192.168.7.20:8765`. caddy user in clearskies group. |
| weather-dev | `weewx-clearskies-api.service` | inactive (disabled) | Erroneous instance removed. |
| weather-dev | `weewx-clearskies-config.service` | active | Wizard still writes to `realtime.conf`. |

**Uncommitted changes from session 2 (preserve all):**

Extension repo (`repos/weewx-clearskies-extension/`):
- `bin/user/clearskies_relay.py` — accept loop hardening + DIAG logging (remove DIAG before commit)

API repo (`repos/weewx-clearskies-api/`):
- `weewx_clearskies_api/endpoints/sse.py` — ConvertedValue preservation + raw numeric wrapping

Meta repo (`.`):
- `docs/procedures/deploy-clearskies.md` — post-ADR-058 updates
- `rules/clearskies-process.md` — delegation rule corrected
- `docs/planning/EXTENSION-HARDENING-PLAN-2.md` — Phase 2A/2B added

**Session 3 (2026-06-14) — what was completed:**

1. **Phase 2A complete (all 5 tasks).** Extension moved to `restful_services` (derived fields confirmed: barometer, dewpoint, appTemp, windchill, heatindex, humidex — 47 fields). Accept loop hardened (1s timeout, silent TimeoutError, clean shutdown verified). ADR-010 amended and Accepted (ConvertedValue dicts for `/current`, flat scalars for `/archive`). REST `/current` now returns ConvertedValue dicts (JSONResponse bypass for Pydantic validation). Single unit authority from `api.conf [units]` via transformer — `load_units_block()` from weewx.conf removed from runtime path.

2. **Phase 2B complete (all sub-phases).** T2B-A: `/setup/apply` accepts units config, wizard sends units to API on apply, pre-fills from API on re-run. T2B-B: `write_realtime_conf()` deleted (123 lines), step 5 MQTT routes removed, `_restart_local_realtime` removed, `realtime_bind_*` removed from topology (539 total deletions across 3 files). T2B-C: State model cleaned (mqtt_*, realtime_bind_*, input_mode removed), admin config UI "realtime" component removed, test code cleaned (224 deletions across 4 test files).

3. **Phase 3 complete (all 4 integration tests PASS).** T3.1 error isolation: weewx survived socket deletion, clean restart. T3.2 API reconnection: disconnect → 4s backoff → reconnect → SSE resumed. T3.3 connection limit: 9th rejected, warning logged. T3.4 graceful shutdown: clean stop, no timeout warning, socket removed.

4. **All changes committed and pushed** to GitHub across all 4 repos. Deployed to containers.

5. **Dashboard regression discovered.** After deployment, precipitation card lost unit labels, AQI card shows null category, forecast page missing unit designations, reports page missing all units, lightning and seismic hardcode "km". Root cause: (a) prior agent rewrite stripped precipitation card labels, (b) BFF enrichment not wired on non-/current endpoints, (c) `epa_category()` never called. **Separate plan created: [DASHBOARD-API-FIX-PLAN.md](DASHBOARD-API-FIX-PLAN.md).**

**Current state of containers after session 3:**

| Container | Service | Status | Notes |
|-----------|---------|--------|-------|
| weewx | `weewx.service` | active | Extension v1.1.0 in restful_services, 47 fields, derived values present |
| weewx | `weewx-clearskies-api.service` | active | ConvertedValue dicts on /current, single unit authority, units envelope with 47 fields |
| weather-dev | `caddy.service` | active | Routes to `https://192.168.7.20:8765` |
| weather-dev | `weewx-clearskies-config.service` | active | Wizard cleaned of all realtime/MQTT dead code |

**All repos clean — everything committed and pushed (through session 3).**

**Session 4 (2026-06-15) — what was completed:**

1. **Phase 4 complete (Vocabulary standardization).** T4.1: Canonical vocabulary table approved by user — 12 component names, banned terms defined, rules for historical context. Table added to ARCHITECTURE.md. T4.2: 32 files updated across ADRs, plans, briefs, design docs, procedures, reference, contracts. Three parallel agents did mechanical replacement; coordinator then fixed 7 semantic breaks where mechanical BFF→API replacement created architecturally wrong passages (ADR-041 computation boundaries, ADR-042 MQTT references, ADR-054 file references, C1-conditions-engine.md enrichment descriptions, CONTAINER-ACCESS.md topology). All committed locally (not pushed).

**Current state after session 4:**

All repos clean locally. Phase 4 vocabulary commit (`15f1eb2`) plus one follow-up fix are committed but not pushed.

**Remaining work:**
- Phase 5 (ADR consolidation) — not started
- Phase 6 (Commit all changes) — Phase 4 committed locally. Phase 5 pending. Push pending user instruction.
- [DASHBOARD-API-FIX-PLAN.md](DASHBOARD-API-FIX-PLAN.md) — separate plan for dashboard/API unit label fixes

**Key files to read first (coordinator reads these directly — not delegated):**
- This plan
- [CLAUDE.md](../../CLAUDE.md) — operating rules, git safety
- [rules/clearskies-process.md](../../rules/clearskies-process.md) — process discipline, agent orchestration, scope binding
- [rules/coding.md](../../rules/coding.md) — coding standards, security constraints
- [docs/ARCHITECTURE.md](../ARCHITECTURE.md) — current system architecture
- [docs/decisions/ADR-058-fold-realtime-into-api.md](../decisions/ADR-058-fold-realtime-into-api.md) — what was merged and why
- [docs/decisions/ADR-061-filesystem-permissions-model.md](../decisions/ADR-061-filesystem-permissions-model.md) — socket permissions
- `repos/weewx-clearskies-extension/bin/user/clearskies_relay.py` — the extension code being debugged
- `repos/weewx-clearskies-api/weewx_clearskies_api/sse/direct_adapter.py` — the socket reader in the API

---

## Orientation — read before executing any task

**Coordinator reads ALL project documents directly.** The coordinator (Opus) must read and understand every file referenced in this plan before writing agent prompts. Agents receive focused extracts with exact context — not "go read the rules file." If the coordinator doesn't understand the code, the architecture, and the permission model, it cannot write correct prompts, QC agent output, or make sound judgment calls. Delegating reading to agents is forbidden for the coordinator role.

**Load these before every session:**
1. [CLAUDE.md](../../CLAUDE.md) — domain routing, operating rules
2. [rules/coding.md](../../rules/coding.md) — code standards, security rules
3. [rules/clearskies-process.md](../../rules/clearskies-process.md) — process discipline, agent orchestration
4. [docs/ARCHITECTURE.md](../ARCHITECTURE.md) — current system architecture (**read first, before any ADRs**)
5. This plan — current task status and context

**Git safety:** Agents do NOT push. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No worktree isolation — all work in the primary local checkout. Coordinator commits after QC. Coordinator never pushes without explicit user instruction.

**SSH access:** All SSH from DILBERT uses the project key: `ssh -F c:/CODE/weather-belchertown/.local/ssh/config <host> "<cmd>"`. Hosts: `weewx`, `weather-dev`, `ratbert`.

**QC model:** Opus provides QC at every task:
- Does the change do what the task says?
- Does it comply with ARCHITECTURE.md and relevant ADRs?
- Does it introduce regressions?
- Is acceptance criteria met (verified by running the check, not trusting the agent's claim)?

**No deferrals.** Every task is mandatory. If blocked, report the blocker. The task does not close until acceptance criteria are met.

**No reversion.** The hardened extension code is the path forward. Debug it until it works.


---

## Phase 1 — Restore the site

Fix the deployment gap from ADR-058 and remove the erroneous API on weather-dev. This is the highest priority — the site is down.

### T1.1 — Remove erroneous API instance from weather-dev

- **Owner:** User-executed (coordinator provides instructions)
- **Dep:** None
- **Do:** Present these commands to the user for execution on weather-dev:
  ```bash
  sudo systemctl stop weewx-clearskies-api
  sudo systemctl disable weewx-clearskies-api
  # Verify:
  ss -tlnp | grep 8765   # should return empty
  ```
- **Accept:** User confirms the service is stopped and disabled. Port 8765 not listening on weather-dev.
- **QC:** Coordinator asks user to run `systemctl status weewx-clearskies-api` and confirm inactive/disabled.

### T1.2 — Update Caddyfile to route to production API

- **Owner:** User-executed (coordinator provides the exact Caddyfile content)
- **Dep:** T1.1
- **Do:** Present the corrected Caddyfile content to the user. The two changes needed in `/etc/caddy/Caddyfile` on weather-dev:
  ```
  # OLD (broken — nothing on 8766):
  handle /api/v1/* {
      reverse_proxy localhost:8766
  }
  handle /sse {
      reverse_proxy localhost:8766
  }

  # NEW (routes to production API on weewx container):
  handle /api/v1/* {
      reverse_proxy https://192.168.7.20:8765 {
          transport http {
              tls_insecure_skip_verify
          }
      }
  }
  handle /sse {
      reverse_proxy https://192.168.7.20:8765 {
          transport http {
              tls_insecure_skip_verify
          }
      }
  }
  ```
  After editing: `sudo systemctl reload caddy`
  Verify: `curl -s http://localhost/api/v1/station | head -5`
- **Accept:** User confirms Caddy reloaded and REST endpoint returns data. User confirms dashboard loads in browser.
- **QC:** Coordinator asks user to confirm site works.

### T1.3 — Update Caddyfile in stack repo

- **Owner:** Coordinator (direct)
- **Dep:** T1.2
- **Do:**
  1. Update the Caddyfile templates in `repos/weewx-clearskies-stack/` to match the corrected routing. All three variants (frontend-host, single-host, examples/reverse-proxy) must route `/api/v1/*` and `/sse` to the API at port 8765, not 8766.
  2. Verify no references to port 8766 remain in any Caddyfile.
- **Accept:** All Caddyfiles in the stack repo route to port 8765. Zero references to 8766.
- **QC:** `grep -r 8766 repos/weewx-clearskies-stack/` returns nothing.

### T1.4 — Update deploy procedure

- **Owner:** Coordinator (direct)
- **Dep:** T1.2
- **Do:**
  1. Update `docs/procedures/deploy-clearskies.md`:
     - Remove `weewx-clearskies-realtime.service` from the systemd units list.
     - Remove `weewx-clearskies-api.service` from weather-dev's service list (it only runs on the weewx container).
     - Update the verification section: check Caddy → API (weewx:8765), not Caddy → BFF (localhost:8766).
     - Remove any references to port 8766.
  2. Update the "Deploying API changes" section to reflect that the API is on the weewx container only.
- **Accept:** Deploy procedure reflects the post-ADR-058 architecture. No references to 8766, no realtime service, no API on weather-dev.
- **QC:** Coordinator reads the updated procedure end-to-end.

---

## Phase 2 — Debug extension socket data flow

The hardened extension loads and accepts connections but may not be sending data. This must be diagnosed and fixed without reverting.

### T2.1 — Verify deployed file matches local source

- **Owner:** Coordinator (direct — read-only verification)
- **Dep:** Phase 1 complete
- **Do:**
  1. Read the deployed file from the weewx container: `ssh weewx "cat /etc/weewx/bin/user/clearskies_relay.py"`.
  2. Compare against the local file at `repos/weewx-clearskies-extension/bin/user/clearskies_relay.py`.
  3. Check for: encoding issues, truncation, byte differences, CRLF corruption.
  4. Run syntax check: `ssh weewx "python3 -c \"import ast; ast.parse(open('/etc/weewx/bin/user/clearskies_relay.py').read()); print('OK')\""`.
- **Accept:** Deployed file matches local source. Syntax check passes.
- **QC:** Coordinator performs the comparison directly.

### T2.2 — Add diagnostic logging to extension

- **Owner:** Coordinator (direct — single-line change)
- **Dep:** T2.1
- **Do:**
  1. Add a temporary INFO log at the top of `on_new_loop_packet`: `logger.info("DIAG: on_new_loop_packet called, clients=%d, disabled=%s", len(self._clients), self._disabled)`.
  2. SCP the updated file to the weewx container.
  3. Restart weewx: `sudo systemctl restart weewx`.
  4. Wait 30 seconds for several loop packets to fire.
  5. Check weewx logs: `sudo journalctl -u weewx --since "1 min ago" | grep DIAG`.
  6. Connect a test client: `python3 -c "import socket; s=socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect('/var/run/weewx-clearskies/loop.sock'); s.settimeout(15); print(s.recv(4096))"`.
  7. Check logs again for DIAG messages with `clients=1`.
- **Accept:** Diagnostic log confirms whether `on_new_loop_packet` is being called and how many clients are connected. Either: (a) handler IS called with clients > 0 → code works, earlier test was timing issue, or (b) handler NOT called → bind issue, or (c) handler called with clients = 0 → accept loop issue.
- **QC:** Coordinator reads the log output directly and traces the bug.

### T2.3 — Fix the identified bug

- **Owner:** Coordinator or `api-dev` (depends on complexity)
- **Dep:** T2.2 (diagnosis result)
- **Do:**
  1. Based on T2.2 findings, fix the bug in the hardened extension code.
  2. Update the local file at `repos/weewx-clearskies-extension/bin/user/clearskies_relay.py`.
  3. Remove the DIAG log line.
  4. SCP the fixed file to weewx container.
  5. Restart weewx.
  6. Verify: raw socket test receives JSON loop packet data within 10 seconds.
  7. Verify: `curl -s -N https://localhost:8765/sse --insecure` on the weewx container shows loop events (not just keepalives).
- **Accept:** Socket test receives data. SSE endpoint shows loop events with weather data fields. End-to-end flow confirmed: weewx → extension → socket → API → SSE.
- **QC:** Coordinator runs both verification commands and confirms data flows.

### T2.4 — Verify SSE through Caddy

- **Owner:** Coordinator (direct)
- **Dep:** T2.3, T1.2
- **Do:**
  1. On weather-dev: `timeout 15 curl -s -N http://localhost/sse | head -10`.
  2. Verify events contain weather data fields (outTemp, windSpeed, etc.), not just keepalives.
  3. Ask the user to confirm real-time updates work in the dashboard.
- **Accept:** SSE events flow end-to-end: weewx → extension → socket → API → Caddy → browser.
- **QC:** Coordinator confirms event content.

---

## Phase 2A — API data pipeline fixes

Four bugs discovered during Phase 1–2 execution. The ADR-058 merge was incomplete: the extension is in the wrong weewx service group, two competing unit authorities exist, REST and SSE use different data shapes, and the accept loop is fragile. All four must be fixed before integration tests.

### T2A.1 — Move extension from `data_services` to `restful_services`

- **Owner:** Coordinator (direct — single config change + code change)
- **Dep:** Phase 2 complete
- **Do:**
  1. In `repos/weewx-clearskies-extension/install.py` line 40: change `data_services=` to `restful_services=`.
  2. Update `repos/weewx-clearskies-extension/README.md`: update documentation to reflect `restful_services`.
  3. On the weewx container: edit `/etc/weewx/weewx.conf` — move `user.clearskies_relay.ClearSkiesLoopRelay` from `data_services` to `restful_services`.
  4. Clear pyc cache, restart weewx.
  5. Connect a test client to the socket and verify the packet includes derived fields: `barometer`, `dewpoint`, `appTemp`, `windchill`, `heatindex`.
  6. **Why:** The extension was registered as a `data_service`, which fires BEFORE `StdConvert`, `StdCalibrate`, `StdQC`, and `StdWXCalculate`. The loop packet at that point is raw driver output — no derived values. The old MQTT path was a `restful_service` (fires after all processing) and got the fully enriched packet. Moving to `restful_services` gives the extension the same fully-processed packet MQTT had.
- **Accept:** Loop packet includes `barometer`, `dewpoint`, `appTemp` (derived values from `StdWXCalculate`). SSE events show these fields with ConvertedValue dicts.
- **QC:** Coordinator captures SSE output and confirms derived fields present.

### T2A.2 — Harden extension accept loop

- **Owner:** Coordinator (direct — partially fixed this session)
- **Dep:** None (parallel with T2A.1)
- **Do:**
  1. In `repos/weewx-clearskies-extension/bin/user/clearskies_relay.py`, the `_accept_loop` method's `except OSError` handler: only `break` when `self._running` is False (shutdown path). Otherwise log warning with `exc_info=True` and `continue`.
  2. Remove the DIAG logging line added during this session.
  3. Deploy to weewx container, clear pyc, restart weewx.
  4. Verify accept thread survives multiple API reconnections.
  5. **Why:** The original `except OSError: break` killed the accept thread on ANY OSError, not just shutdown. Combined with stale `.pyc` bytecode, the thread died silently and no clients could connect. The API logged "Connected" but the extension never accepted the connection.
- **Accept:** Accept thread survives API restarts. `ss -xlnp | grep loop.sock` shows `LISTEN 0 8` (zero backlog) after each reconnection.
- **QC:** Coordinator restarts API 3 times and confirms client count recovers each time.

### T2A.3 — Amend ADR-010: Unified ConvertedValue response shape

- **Owner:** Coordinator (direct — ADR amendment)
- **Dep:** None (parallel)
- **Do:**
  1. Amend ADR-010 to authorize ConvertedValue dicts `{value, label, formatted}` in REST response `data` blocks for observation endpoints (`/current`, individual record responses).
  2. The `units` envelope block remains as a convenience summary (backward-compatible).
  3. Archive endpoints (`/archive`) remain flat scalars with full-precision `value` extraction — charts need raw numbers, not formatted strings. Exception: `beaufort` stays as ConvertedValue dict (wind rose reads via `extractNumber()`).
  4. **Why:** ADR-010 shows REST `data` as flat scalars. ADR-042 shows SSE as ConvertedValue dicts. One data source (weewx) producing two different data shapes is a footgun for dashboard components and future third-party consumers. The user directed: "the data packets from both the SSE and REST need to look similar — we should not have two different data structures."
  5. Status: Proposed → user reviews → Accepted.
- **Accept:** ADR-010 amended. ConvertedValue shape authorized for REST observation data. Archive exception documented. User has approved.
- **QC:** Coordinator reads the amendment and confirms no conflict with ADR-042 or ADR-058.

### T2A.4 — Unify REST `/current` response shape with SSE

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T2A.3 (ADR amendment approved)
- **Do:**
  1. In `weewx_clearskies_api/units/response_conversion.py`, modify `apply_conversion()` Shape 2 handler (lines 184-237): stop flattening ConvertedValue dicts for the `/current` envelope. Pass through `{value, label, formatted}` dicts from `transform_record()` into the `data` block. Keep the `units` envelope as a convenience summary derived from the ConvertedValue labels.
  2. Cardinal direction injection: extract degrees from `wind_dir["value"]` (not flat scalar).
  3. Enrichment fields (`weatherText`, `windSpeedAvg10m`, `windGustMax10m`, etc.): ensure ConvertedValue dicts where applicable, matching SSE shape.
  4. After transform, wrap any remaining raw numeric fields in `{"value": v, "label": "", "formatted": str(v)}` — matching the old BFF's `convert_mqtt_packet()` behavior where EVERY field was a ConvertedValue dict.
  5. **Do NOT change Shape 2b** (archive envelope) — charts need full-precision flat values.
- **Accept:** REST `/current` `data` block contains ConvertedValue dicts for all observation fields. Dashboard renders units from initial REST load (before SSE kicks in). Archive endpoint unchanged.
- **QC:** Coordinator calls `/api/v1/current` and verifies `data.outTemp` is `{value, label, formatted}`. Loads dashboard, confirms unit labels display immediately.

### T2A.5 — Single unit authority from `api.conf [units]`

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T2A.4
- **Do:**
  1. In `weewx_clearskies_api/services/units.py`: remove `load_units_block()` as a runtime unit authority. It may remain as a setup-time import helper for the wizard, but the API MUST NOT use it at runtime.
  2. In `__main__.py`: ensure the `units` envelope in REST responses is derived from the transformer's target units, not from a parallel weewx.conf read.
  3. If `api.conf [units]` is empty/missing: log a clear warning at startup. Values pass through unconverted with source-unit labels (degraded but functional).
  4. **Why:** Two competing unit authorities (weewx.conf read + api.conf transformer) caused REST to show °F labels while SSE showed °C values. The old BFF had one authority (realtime.conf). The merged API must also have one authority (api.conf [units]).
- **Accept:** One unit authority: `api.conf [units]`. No runtime weewx.conf read for units. Clear warning when units not configured.
- **QC:** Coordinator removes weewx.conf temporarily, restarts API, verifies it starts with warning and serves units from api.conf alone.

---

## Phase 2B — Wizard ADR-058 migration

The wizard writes config to the wrong files, presents MQTT as an option, restarts a deleted service, and has dozens of stale references across config_writer.py, routes.py, state.py, state_persistence.py, topology.py, templates, admin config UI, and tests.

### Phase 2B-A: Unit config via `/setup/apply`

### T2B-A.1 — Add unit groups to `/setup/apply` API payload

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T2A.5
- **Do:**
  1. The API's `/setup/apply` handler must accept a `units` dict in the payload and write it to `api.conf [units] [[groups]]`.
  2. Include `[[string_formats]]`, `[[labels]]`, `[[ordinates]]` subsections if provided.
- **Accept:** POST `/setup/apply` with `{"units": {"groups": {"group_temperature": "degree_F", ...}}}` persists to `api.conf`. API restart picks up the configured units.
- **QC:** Coordinator calls `/setup/apply` with mixed units and verifies `api.conf` content.

### T2B-A.2 — Wizard unit step writes to API via `/setup/apply`

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2B-A.1
- **Do:**
  1. The wizard's unit step presents units from weewx.conf as per-group suggestions. Operator can modify ANY individual group (e.g., °F for temp, km/h for wind). Presets (US/Metric/MetricWX) are starting points, not locked choices.
  2. On apply, per-group selections included in `/setup/apply` payload. No writing to `realtime.conf`.
- **Accept:** Mixed unit configuration persists to `api.conf [units] [[groups]]`. SSE and REST deliver values with the operator's per-group labels.
- **QC:** Coordinator runs wizard with mixed units, verifies api.conf and SSE output.

### T2B-A.3 — Wizard re-run pre-fills from API

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2B-A.1
- **Do:**
  1. On re-run, wizard reads unit config from API's `/setup/current-config`, not from `realtime.conf`.
  2. Pre-fills the unit step with previously confirmed per-group selections.
- **Accept:** Wizard re-run shows previously configured units. Operator can modify and re-apply.
- **QC:** Coordinator runs wizard, applies, re-runs wizard, verifies pre-fill.

### Phase 2B-B: Config writer migration

### T2B-B.1 — Remove `write_realtime_conf()` and MQTT config writing

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2B-A.2
- **Do:**
  1. Delete `write_realtime_conf()` from `config_writer.py`.
  2. Remove all MQTT config writing.
  3. Remove `realtime.conf` from `apply_wizard()` orchestration.
- **Accept:** Zero references to `realtime.conf` in config_writer.py.
- **QC:** `grep -n realtime config_writer.py` returns nothing.

### T2B-B.2 — Remove wizard step 5 (MQTT/input mode)

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2B-B.1
- **Do:**
  1. Remove step 5 routes in `routes.py`. Remove `step_mqtt.html` template. Update `_progress_bar.html`.
  2. Input mode is always "direct" (hardcoded, not operator-selectable).
- **Accept:** Wizard skips from station to providers. No MQTT configuration UI.
- **QC:** Coordinator walks the wizard and confirms no MQTT step.

### T2B-B.3 — Remove realtime service restart from apply

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2B-B.1
- **Do:**
  1. Remove `_restart_local_realtime()`, `_realtime_service_status()`, `_REALTIME_SERVICE` constant.
  2. Update `restart_status_fragment.html`, `step_complete.html` — remove realtime references.
- **Accept:** Wizard apply only restarts the API. No `weewx-clearskies-realtime` references.
- **QC:** Coordinator runs wizard apply and confirms only API restart in completion page.

### T2B-B.4 — Update topology detection for post-ADR-058

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2B-B.1
- **Do:**
  1. Topology considers API host location (from `api_address` in step 1) + DB host.
  2. Remove `realtime_bind_*` from `topology.py` defaults.
  3. Key question: "Is the API on the same host as the wizard UI?" — determines Caddy internal vs external routing.
- **Accept:** Same-host when both API and DB are loopback. Cross-host when API is remote. `realtime_bind_*` removed.
- **QC:** Coordinator tests both topologies.

### Phase 2B-C: State and UI cleanup

### T2B-C.1 — Clean wizard state model

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2B-B complete
- **Do:**
  1. Remove `realtime_bind_host`, `realtime_bind_port`, all `mqtt_*` fields from `WizardState` in `state.py`.
  2. Set `input_mode = "direct"` as constant.
  3. Remove `realtime.conf` reading from `state_persistence.py`.
- **Accept:** Zero realtime/MQTT fields in WizardState.
- **QC:** `grep -n "realtime\|mqtt" state.py` returns nothing (except comments about removal).

### T2B-C.2 — Clean admin config UI

- **Owner:** `config-ui-dev` (Sonnet)
- **Dep:** T2B-B complete
- **Do:**
  1. Remove `"realtime"` from `COMPONENTS` in `config/reader.py`.
  2. Remove realtime admin sections from `config/routes.py`.
  3. Update `config/dashboard.html` template.
- **Accept:** Admin UI shows only API and stack sections.
- **QC:** Coordinator loads admin UI and confirms no realtime sections.

### T2B-C.3 — Update wizard tests

- **Owner:** `test-author` (Sonnet)
- **Dep:** T2B-B complete
- **Do:**
  1. `test_wizard_config_writer.py`: remove `write_realtime_conf` tests (20 functions), un-xfail BUG A7 tests.
  2. `test_wizard_topology.py`: remove `realtime_bind_*` assertions.
  3. `test_config_reader.py`: remove `"realtime"` from COMPONENTS assertion.
  4. `test_wizard_import.py`: remove MQTT step references.
- **Accept:** All tests pass. Zero references to `realtime_bind_*`, `write_realtime_conf`, MQTT step, port 8766.
- **QC:** Coordinator runs full test suite.

---

## Phase 3 — Integration tests (EXTENSION-HARDENING-PLAN T3.1–T3.4)

All tests on the weewx container via SSH.

### T3.1 — Error isolation test

- **Owner:** Coordinator (direct)
- **Dep:** T2.3
- **Do:**
  1. Delete socket while weewx is running: `sudo rm /var/run/weewx-clearskies/loop.sock`.
  2. Wait for 2+ loop packets. Check weewx logs — no crash, extension logs errors.
  3. Restart weewx. Verify socket recreated with correct permissions (`weewx:weewx` 0660).
- **Accept:** weewx survives socket deletion. Extension logs errors. Restart recovers.
- **QC:** Coordinator confirms no traceback killing weewx, error messages present.

### T3.2 — API reconnection test

- **Owner:** Coordinator (direct)
- **Dep:** T2.4
- **Do:**
  1. Confirm SSE flowing via curl on weather-dev.
  2. Restart weewx (destroys and recreates socket).
  3. Watch API logs for disconnect → backoff → reconnect sequence.
  4. Verify SSE resumes within 60 seconds.
- **Accept:** API detects disconnect, reconnects automatically, SSE resumes.
- **QC:** Coordinator reviews journal timeline.

### T3.3 — Connection limit test

- **Owner:** Coordinator (direct)
- **Dep:** T2.3
- **Do:**
  1. Open 8 concurrent socket connections (max_clients default).
  2. Attempt 9th — should be rejected immediately.
  3. Check weewx logs for connection limit warning.
  4. Clean up test connections.
- **Accept:** 9th connection rejected. Warning logged.
- **QC:** Coordinator confirms rejection and warning in logs.

### T3.4 — Graceful shutdown test

- **Owner:** Coordinator (direct)
- **Dep:** T2.3
- **Do:**
  1. `sudo systemctl stop weewx`.
  2. Check logs for "ClearSkiesLoopRelay stopped" message.
  3. Verify socket file removed.
  4. No "accept thread did not exit" warning.
  5. Restart weewx, verify clean startup.
- **Accept:** Clean shutdown message. Socket removed. No timeout warnings. Clean restart.
- **QC:** Coordinator reviews shutdown and restart logs.

---

## Phase 4 — Vocabulary standardization

Audit every document for inconsistent component names. Establish ONE canonical name per component. Fix every document.

### T4.1 — Define canonical vocabulary table

- **Owner:** Coordinator (direct — requires full project context)
- **Dep:** None (parallel with Phases 1-3)
- **Do:**
  1. Read all ADRs, ARCHITECTURE.md, plans, procedures, security baseline, rules files, and repo READMEs.
  2. Catalog every term used to refer to each component. Identify all inconsistencies.
  3. Propose a vocabulary table: component → canonical name → one-sentence definition → terms that are WRONG and must not be used.
  4. Present the table to the user for approval before applying.
  5. Rules for the vocabulary:
     - Each component gets ONE name. Not two. Not a class name AND a role name.
     - Names describe what the thing DOES, not what code class implements it.
     - No compound terms invented by combining a service name with a class name (e.g., "API DirectAdapter" is banned — call it what it does).
     - The vocabulary table becomes a section in ARCHITECTURE.md.
- **Accept:** User approves the vocabulary table. Table added to ARCHITECTURE.md.
- **QC:** Coordinator re-reads 10 documents and confirms zero vocabulary violations remain after the table is established.

### T4.2 — Apply vocabulary fixes across all documents

- **Owner:** `docs-author` (Sonnet) — one agent per batch of files
- **Dep:** T4.1 (approved vocabulary)
- **Do:**
  1. The coordinator provides the approved vocabulary table and a list of files to fix.
  2. For each file: replace every non-canonical term with the canonical term. Do not change meaning — only terminology.
  3. Files to audit and fix:
     - All 62 ADRs in `docs/decisions/`
     - `docs/ARCHITECTURE.md`
     - `docs/contracts/security-baseline.md`
     - All plans in `docs/planning/`
     - All procedures in `docs/procedures/`
     - `rules/coding.md`, `rules/clearskies-process.md`
     - Extension repo README
     - API repo README (if vocabulary terms appear)
     - Stack repo README and Caddyfile comments
     - `CLAUDE.md`
- **Accept:** Every document uses the canonical vocabulary. Zero instances of banned terms remain.
- **QC:** Coordinator greps for each banned term across all docs and confirms zero hits.

---

## Phase 5 — ADR consolidation

Restructure 62 individual ADR documents into a small set of logical documents organized by project area. Back up originals first. Add flowcharts.

### T5.1 — Back up current ADRs

- **Owner:** Coordinator (direct)
- **Dep:** T4.2 (vocabulary fixes applied first — consolidate AFTER vocabulary is standardized)
- **Do:**
  1. Copy `docs/decisions/` to `docs/archive/decisions-pre-consolidation/`.
  2. Commit the backup.
- **Accept:** Backup directory exists with all 62 ADRs. Git commit preserves the snapshot.
- **QC:** `ls docs/archive/decisions-pre-consolidation/ | wc -l` matches original count.

### T5.2 — Catalog and group ADRs

- **Owner:** Coordinator (direct — requires reading every ADR)
- **Dep:** T5.1
- **Do:**
  1. Read every ADR. For each one, record: number, title, status, what logical section of the project it covers.
  2. Define logical groupings. Proposed starting point (will be refined based on actual content):
     - **Deployment & topology** — ADR-034, 036, 039, etc.
     - **Security & permissions** — ADR-008, 037, 060, 061, etc.
     - **Data pipeline** — ADR-005 (superseded), 041, 042, 044, 054, 058, etc.
     - **API design** — ADR-010, 012, 018, 030, 031, 035, etc.
     - **Dashboard & UI** — ADR-009, 022, 023, 024, 025, 026, 033, 047, 048, 049, 050, 051, 055, etc.
     - **Configuration & setup** — ADR-027, 028, 038a, 043, etc.
     - **Providers** — ADR-006, 007, 013, 015, 016, 017, 038, 040, 046, 052, 053, 059, etc.
     - **Project meta** — ADR-001, 002, 003, 004, 011, 021, 032, etc.
  3. Present the groupings to the user for approval.
- **Accept:** Every ADR assigned to exactly one group. User approves the groupings.
- **QC:** Coordinator verifies no ADR is orphaned or double-assigned.

### T5.3 — Consolidate ADRs into logical documents

- **Owner:** `docs-author` (Sonnet) — one agent per logical group
- **Dep:** T5.2 (approved groupings)
- **Do:**
  1. For each logical group, merge the relevant ADRs into a single cohesive document.
  2. Structure per document:
     - Title and scope (what area of the project this covers)
     - Current state (how it works NOW, post-all-amendments)
     - Key decisions (the important choices, with rationale — not the full Nygard ceremony)
     - Constraints and rules (what code must follow)
     - References (links to code, other consolidated docs)
  3. Drop: Nygard format boilerplate, options-considered tables for long-settled decisions, historical context that doesn't inform current work.
  4. Keep: decision rationale, constraints, consequences, acceptance criteria that are still relevant.
  5. Superseded ADRs (ADR-005, ADR-019) are absorbed into the relevant document's "Historical" section — they don't get their own subsection unless the history matters.
  6. Each document lives at `docs/decisions/<group-slug>.md` (e.g., `docs/decisions/deployment-topology.md`).
- **Accept:** Each logical group has one consolidated document. Content is accurate and current. No information lost (backup exists at `docs/archive/`).
- **QC:** Coordinator reads each consolidated document and spot-checks 3+ decisions per document against the original ADRs for accuracy.

### T5.4 — Add flowcharts to each consolidated document

- **Owner:** `docs-author` (Sonnet) — one agent per document
- **Dep:** T5.3
- **Do:**
  1. Each consolidated document gets at least one visual flowchart (Mermaid syntax for renderability) showing how the pieces in that section connect.
  2. Examples:
     - **Data pipeline:** weewx engine → loop relay extension → Unix socket → API socket reader → enrichment pipeline (12 processors) → unit conversion → SSE emitter / REST responses → Caddy → browser
     - **Security:** trust boundaries (Internet → Caddy → API → weewx), who can access what, filesystem permissions
     - **Deployment:** container topology, port map, service dependencies, config file locations
     - **Provider:** provider registry → outbound API call → response parsing → canonical translation → cache → endpoint
  3. Flowcharts must use the canonical vocabulary from T4.1.
- **Accept:** Every consolidated document has at least one flowchart. Flowcharts use canonical vocabulary. Flowcharts are technically accurate.
- **QC:** Coordinator traces each flowchart against the actual code/architecture.

### T5.5 — Update ARCHITECTURE.md and all cross-references

- **Owner:** `docs-author` (Sonnet)
- **Dep:** T5.3, T5.4
- **Do:**
  1. Replace the "Authoritative ADRs by component" table in ARCHITECTURE.md with references to the new consolidated documents.
  2. Update `docs/decisions/INDEX.md` — either replace with an index of the consolidated docs, or add a prominent note that individual ADRs are archived and the consolidated docs are authoritative.
  3. Update every file that references individual ADRs (plans, rules, procedures, security baseline, CLAUDE.md) to reference the consolidated docs instead. Grep for `ADR-0` across the entire project.
- **Accept:** All cross-references point to consolidated docs. No broken links. ARCHITECTURE.md references the new structure.
- **QC:** Coordinator greps for `ADR-0` across all non-archived files and confirms references are updated or explicitly historical.

---

## Phase 6 — Commit all changes

### T6.1 — Commit extension repo changes

- **Owner:** Coordinator
- **Dep:** Phase 3 complete
- **Do:** Commit all extension repo changes: hardened `clearskies_relay.py`, `install.py`, README, changelog. One commit covering the hardening work.
- **Accept:** Clean commit in extension repo. `git status` shows clean.

### T6.2 — Commit meta repo changes

- **Owner:** Coordinator
- **Dep:** Phases 1-5 complete
- **Do:** Commit meta repo changes in logical commits:
  1. Site restoration (Caddyfile fix, deploy procedure update, erroneous API removal)
  2. Extension hardening docs (ADR-061 fix, ARCHITECTURE.md, security baseline, deployment procedure)
  3. Vocabulary standardization (vocabulary table + all doc fixes)
  4. ADR consolidation (backup, consolidated docs, updated cross-references)
- **Accept:** Clean commits. `git status` shows clean in both repos.

### T6.3 — Commit stack repo Caddyfile changes

- **Owner:** Coordinator
- **Dep:** T1.3
- **Do:** Commit Caddyfile routing fix in the stack repo.
- **Accept:** Clean commit. No references to port 8766.

---

## Dependency graph

```
Phase 1 (Site restoration) — DONE (2026-06-14 session)
T1.1 remove erroneous API ─ DONE
T1.2 fix Caddyfile routing ─ DONE
T1.3 stack repo Caddyfiles ─ DONE (already correct)
T1.4 update deploy procedure ─ DONE
         │
         ▼
Phase 2 (Extension socket debugging) — DONE (2026-06-14 session)
T2.1 verify deployed file ─ DONE (matches)
T2.2 diagnostic logging ─ DONE (handler called, clients connected)
T2.3 fix the bug ─ DONE (stale pyc was root cause, accept loop hardened)
T2.4 verify SSE through Caddy ─ DONE (data flows end-to-end)
         │
         ▼
Phase 2A (API data pipeline fixes) — DONE (2026-06-14 session 3)
T2A.1 extension service group ─ DONE (moved to restful_services, derived fields confirmed)
T2A.2 accept loop hardening ─ DONE (1s timeout, silent TimeoutError, clean shutdown)
T2A.3 amend ADR-010 (unified shape) ─ DONE (Accepted)
T2A.4 unify REST shape ─ DONE (ConvertedValue dicts in /current, JSONResponse bypass)
T2A.5 single unit authority ─ DONE (api.conf [units] via transformer, weewx.conf removed)
         │
         ▼
Phase 2B (Wizard ADR-058 migration) — DONE (2026-06-14 session 3)
2B-A: T2B-A.1 ─ DONE, T2B-A.2 ─ DONE, T2B-A.3 ─ DONE
2B-B: T2B-B.1-B.4 ─ DONE (539 lines deleted)
2B-C: T2B-C.1-C.3 ─ DONE (state, admin UI, tests cleaned)
         │
         ▼
Phase 3 (Integration tests) — DONE (2026-06-14 session 3)
T3.1 error isolation ─ PASS
T3.2 API reconnection ─ PASS
T3.3 connection limit ─ PASS
T3.4 graceful shutdown ─ PASS
         │
         ▼
Phase 4 (Vocabulary) — DONE (2026-06-15 session 4)
T4.1 define canonical vocabulary table ─ DONE (approved by user)
T4.2 apply vocabulary fixes ─ DONE (32 files, 227 ins / 198 del + semantic fixes)
         │
         ▼
Phase 5 (ADR consolidation — dep: T4.2)
T5.1 back up current ADRs ──────────────────┐
T5.2 catalog and group (dep: T5.1) ─────────┤
T5.3 consolidate into logical docs (dep: T5.2)
T5.4 add flowcharts (dep: T5.3) ────────────┤
T5.5 update cross-references (dep: T5.4) ───┘
         │
         ▼
Phase 6 (Commit — dep: all phases)
T6.1 commit extension repo ─┐
T6.2 commit meta repo ──────┤
T6.3 commit stack repo ─────┘
```

---

## Verification bar — plan-level "done"

All of the following must be true:

- **Site works:** Dashboard loads in the user's browser. REST data displays. SSE real-time updates flow.
- **No erroneous services:** weather-dev runs only Caddy, config UI, and dashboard static files. No API, no realtime service.
- **Caddy routing correct:** `/api/v1/*` and `/sse` route to `https://192.168.7.20:8765`. Port 8766 referenced nowhere.
- **Extension socket works:** Raw socket test receives JSON data. SSE events contain weather fields. No reversion — hardened code is production.
- **Integration tests pass:** T3.1-T3.4 all pass (error isolation, reconnection, connection limit, shutdown).
- **Vocabulary standardized:** One canonical name per component. Vocabulary table in ARCHITECTURE.md. Zero banned terms in any document.
- **ADRs consolidated:** 62 individual ADRs archived. Small set of logical documents with flowcharts replaces them. All cross-references updated.
- **All changes committed:** Extension repo, meta repo, stack repo — clean git status in all three.
