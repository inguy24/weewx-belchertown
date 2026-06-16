# FIXIT-BACKLOG-2 — Post-merge gaps, extension deployment, wizard cleanup

Items discovered after completing [FIXIT-ARCHITECTURE-PLAN.md](FIXIT-ARCHITECTURE-PLAN.md). That plan merged the realtime service into the API, added multi-jurisdiction AQI, and completed a security audit — but left gaps in the deployment pipeline for the weewx extension, stale wizard steps, and unaudited extension code.

**Created:** 2026-06-14

---

## FIX2-001 — Security audit of ClearSkiesLoopRelay extension

**Priority:** High
**Component:** `weewx-clearskies-extension`

The extension was never security-audited. It runs inside the weewx process with full weewx-level privileges. The FIXIT-ARCHITECTURE-PLAN security audit (Phase 5A) covered the API and Caddy but never reviewed the code running inside weewx.

**Known concerns:**
- Unix socket opened with no authentication — any local process can connect and receive all loop packet data
- No socket file permissions set after bind (defaults to umask, likely world-readable)
- No connection limit — `listen(8)` sets backlog, but no cap on total accepted clients
- No rate limiting on accept loop
- Runs in the weewx engine thread context — a bug here could crash the weather station
- Socket directory created with `os.makedirs(exist_ok=True)` — no ownership or mode enforcement

**Required:**
- Full code review against the security baseline
- Socket file permissions hardened (e.g., `os.chmod(self._socket_path, 0o660)` after bind, owned by `weewx:clearskies` group)
- Connection limit implemented
- Error isolation verified — extension crash must not take down weewx
- Add extension-specific controls to `docs/contracts/security-baseline.md`
- Add extension-specific rules to `rules/coding.md`

---

## FIX2-002 — Wizard step 5 overhaul (input mode)

**Priority:** High
**Component:** `weewx-clearskies-stack` (wizard)

Wizard step 5 is completely stale. It still offers MQTT vs direct mode selection, still writes `realtime.conf` (deprecated), and does not configure the API's `[input]` section.

**Current state (broken):**
- Offers MQTT option (eliminated per ADR-058)
- Writes `realtime.conf` (deprecated — realtime service no longer exists)
- Does NOT write `[input]` section to `api.conf`
- Does NOT install the weewx extension
- Does NOT create the socket directory

**Required:**
- Remove MQTT option entirely
- Remove `realtime.conf` generation from `config_writer.py`
- Write `[input]` section to `api.conf` (enabled, socket_path)
- Either install the extension automatically or guide the operator through manual installation
- Create the socket directory with correct permissions
- Update step UI to reflect that direct mode is the only mode

---

## FIX2-003 — Extension deployment procedure

**Priority:** High
**Component:** `weewx-clearskies-extension`, docs

No documented procedure exists for installing the extension into weewx. An operator following the documented deployment process gets an API with working REST but no live SSE data.

**Required:**
- Write `docs/procedures/install-weewx-extension.md` — step-by-step procedure covering:
  - `weectl extension install <path>` command
  - Verifying the `[ClearSkiesLoopRelay]` section was added to `weewx.conf`
  - Socket path alignment between `weewx.conf` and `api.conf [input]`
  - Restarting weewx
  - Verifying the socket file appears at the configured path
  - Verifying the API connects (check API logs for "DirectAdapter connected")
- Reference this procedure from the main deployment docs and README

---

## FIX2-004 — Wizard extension installation guidance

**Priority:** Medium
**Component:** `weewx-clearskies-stack` (wizard)

The wizard should either automate extension installation or clearly guide the operator. This is the "how does it get deployed" question.

**Options (needs ADR):**
1. Wizard automates installation via SSH to the weewx host (complex, requires credentials)
2. Wizard generates a shell script the operator runs on the weewx host
3. Wizard displays step-by-step instructions the operator follows manually
4. Extension is pre-installed as part of the Clear Skies install script

**Constraint:** The wizard runs on the front-end host (or wherever the config UI is). The weewx extension must be installed on the weewx host. These may be different machines (two-host topology per ADR-034).

---

## FIX2-005 — Update ARCHITECTURE.md for extension repo

**Priority:** Medium
**Component:** meta repo (docs)

ARCHITECTURE.md repo layout table has 6 repos. Needs a 7th row for `weewx-clearskies-extension`. The "Container inventory" section should note that this repo has no container — it installs directly into weewx.

**Required:**
- Add repo to the "Repo layout" table
- Add note to "Container inventory" explaining this component runs inside weewx, not as a container
- Update the "Input mode" section to reference the extension repo (currently references the deprecated realtime repo)
- Update "Authoritative ADRs by component" table

---

## FIX2-006 — Stale realtime references in docs

**Priority:** Low
**Component:** meta repo (docs)

5 documentation files still reference the realtime service as if it's a separate running component:

1. `docs/procedures/deploy-clearskies.md` — references realtime deployment
2. `docs/procedures/CONTAINER-ACCESS.md` — references realtime container
3. `docs/design/C1-conditions-engine.md` — references realtime service
4. `docs/planning/CLEAR-SKIES-PLAN.md` — references realtime as active component
5. `docs/decisions/ADR-037*` — may have stale realtime references

**Required:** Update each file to reflect the post-merge architecture (API serves everything, realtime is deprecated).

---

## FIX2-007 — Wizard still generates realtime.conf

**Priority:** Medium
**Component:** `weewx-clearskies-stack` (wizard)

`config_writer.py` still calls `write_realtime_conf()` which writes `/etc/weewx-clearskies/realtime.conf`. This file is not read by anything — the realtime service is gone and the API reads `api.conf`.

**Required:**
- Remove `write_realtime_conf()` from `config_writer.py`
- Remove `realtime.conf` generation from `wizard/apply`
- Remove `realtime` from the admin config section list
- Clean up any `realtime.conf` references in wizard state, routes, templates

---

## FIX2-008 — Wizard still references port 8766

**Priority:** Medium
**Component:** `weewx-clearskies-stack` (wizard)

`wizard/state.py`, `wizard/routes.py`, and `wizard/topology.py` still reference port 8766 (the former realtime service port). This port no longer exists.

**Required:**
- Remove all 8766 references from wizard code
- Update topology detection to not look for a realtime service
- Ensure wizard health checks and connectivity tests only target port 8765 (API) and 9876 (config UI)

---

## FIX2-009 — API `[input]` section not written by setup apply

**Priority:** High
**Component:** `weewx-clearskies-api` (setup endpoint)

The API's `/setup/apply` endpoint writes `api.conf` but does not include an `[input]` section. The `InputSettings` class in `settings.py` has defaults (`enabled=true`, `socket_path=/var/run/weewx-clearskies/loop.sock`), so the API works by falling back to defaults — but the operator has no visibility into or control over these settings through the setup flow.

**Required:**
- `/setup/apply` should write the `[input]` section to `api.conf`
- `/setup/current-config` should return input settings
- Wizard step 5 (after FIX2-002 overhaul) should collect and submit these values

---

## FIX2-010 — Pre-existing test failures

**Priority:** Medium
**Component:** `weewx-clearskies-api`, `weewx-clearskies-dashboard`

The FIXIT plan's verification bar requires "full pytest suite passes with zero failures." Current state: API has ~74 pre-existing failures (alerts, forecast, station modules), dashboard has ~25. All predate the FIXIT plan — none were introduced by it.

**Required:**
- Triage each failure: fixture staleness, provider API changes, or real bugs
- Fix or update tests
- Establish a CI gate so new failures don't accumulate

---

## FIX2-011 — GitHub repo creation for weewx-clearskies-extension

**Priority:** High
**Component:** `weewx-clearskies-extension`

The repo exists locally at `repos/weewx-clearskies-extension` but has no GitHub remote. Needs a GitHub repo created under the same org/account as the other `weewx-clearskies-*` repos.

**Required:**
- Create GitHub repo
- Push initial commit
- Add to the Clear Skies plan components table
