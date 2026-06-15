# EXTENSION-HARDENING-PLAN — ClearSkiesLoopRelay security hardening, deployment, and integration

**Goal:** Fix all security audit findings for the ClearSkiesLoopRelay weewx extension, deploy it on the production weewx container, verify end-to-end loop packet flow through to the API's SSE emitter, and update all documentation.

**Status:** Phase 1 complete. Phase 4 complete. Phases 2-3 blocked on SSH access to weewx container.

**Source:** Security audit findings (11 items), FIXIT-BACKLOG-2 items FIX2-001, FIX2-003, FIX2-005.

**Repos involved:**
- `weewx-clearskies-extension` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-extension`) — extension code hardening
- `weather-belchertown` (local: `c:\CODE\weather-belchertown`) — ADRs, ARCHITECTURE.md, security baseline, procedures
- `weewx-clearskies-api` (local: `c:\CODE\weather-belchertown\repos\weewx-clearskies-api`) — reference for DirectAdapter integration

**Dev/test environment:** `weewx` LXD container (192.168.7.20). NOT weather-dev (192.168.7.21). The extension runs inside the weewx process — it must be tested where weewx runs. SSH: `ssh weewx` (or `ssh ubuntu@192.168.7.20`). weewx service: `weewx.service`. API service: `weewx-clearskies-api.service`.

---

## Execution context for new sessions

**What happened before this plan:**
1. The FIXIT-ARCHITECTURE-PLAN merged the realtime service into the API (ADR-058). All 5 phases completed.
2. During post-merge integration testing, we discovered the ClearSkiesLoopRelay weewx extension (which serves loop packets to the API via a Unix socket) was never deployed. It existed as `weewx_ext.py` in the deprecated realtime repo but had no deployment path.
3. A new standalone repo `weewx-clearskies-extension` was created at `repos/weewx-clearskies-extension/` with the extension code ported from the realtime repo. GitHub remote: `https://github.com/inguy24/weewx-clearskies-extension`.
4. A security audit of the extension code found 11 issues (see findings table below).
5. A new backlog (`docs/planning/FIXIT-BACKLOG-2.md`) tracks 11 post-merge gaps including the extension issues.
6. The extension code currently has partial edits from this session — `_max_clients` and `_socket_group` were added to `__init__` but the enforcement code was NOT written. The code is NOT production-ready.

**What this plan does:**
- Phase 1: Harden the extension code (9 tasks — fix all code-level audit findings)
- Phase 2: Deploy on the weewx container (install extension, set permissions, verify socket)
- Phase 3: Integration testing (error isolation, reconnection, connection limits, shutdown)
- Phase 4: Update documentation (ADR-061 amendment, ARCHITECTURE.md, security baseline, procedures)

**Key files to read first:**
- This plan (you're reading it)
- `repos/weewx-clearskies-extension/bin/user/clearskies_relay.py` — the extension code (142 lines)
- `repos/weewx-clearskies-extension/install.py` — the weewx extension installer
- `repos/weewx-clearskies-api/weewx_clearskies_api/sse/direct_adapter.py` — the API's socket client
- `repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py` lines 1073-1097 — InputSettings
- `docs/decisions/ADR-061-filesystem-permissions-model.md` — socket permissions model
- `docs/decisions/ADR-058-fold-realtime-into-api.md` — extension architecture decision
- `docs/contracts/security-baseline.md` — needs extension section added

---

## Orientation — read before executing any task

**Load these before every session:**
1. [CLAUDE.md](../../CLAUDE.md) — domain routing, operating rules
2. [rules/coding.md](../../rules/coding.md) — code standards, security requirements
3. [rules/clearskies-process.md](../../rules/clearskies-process.md) — process discipline, agent orchestration
4. [docs/ARCHITECTURE.md](../ARCHITECTURE.md) — system architecture (read first, before ADRs)
5. This plan — current task status and context

**Critical ADRs:**
- ADR-058 — realtime folding (extension "stays as-is," Unix socket approved)
- ADR-060 — security model (trust boundaries, mandatory mitigations)
- ADR-061 — filesystem permissions (process users, socket directory/file permissions)
- ADR-056 — API co-location (same host as weewx)

**Git safety:** Agents do NOT push. Agents may only `git add`, `git commit`, `git status`, `git log`, `git diff`. No worktree isolation — all work in the primary local checkout. Coordinator commits after QC.

**QC model:** Opus provides QC at every task. QC verifies:
- Does the fix address the specific audit finding?
- Does it comply with ADR-058, ADR-060, and ADR-061?
- Does it introduce any risk to weewx engine stability?
- Is acceptance criteria met (verified, not trusted)?

**Paramount constraint — weewx engine safety.** The extension runs synchronously in weewx's main loop thread. An unhandled exception in `on_new_loop_packet` crashes the weather station. An exception during `__init__` prevents weewx from starting. Error isolation is the single most important requirement.

---

## weewx extension compliance (from official docs)

The extension must comply with weewx's official extension guidelines (`docs/reference/weewx-5.3/custom/extensions.md`). Key rules:

1. **"Extensions that require configuration should not be enabled by default. Otherwise, they will crash the system on startup."** — Our extension has sensible defaults (socket path, max clients) and must degrade gracefully if the socket can't be created. Findings #1 and #2 violate this rule — an exception in `__init__` or the packet handler currently crashes weewx.

2. **"Extensions should have their own stanza in `weewx.conf`. List all possible options, albeit commented out."** — Our `[ClearSkiesLoopRelay]` stanza exists but only lists `socket_path`. Must add `max_clients` and `socket_group` as commented-out options so operators know what's available.

3. **"Write the extension so that it fails gracefully."** — The core requirement. Socket creation failure, permission issues, and unexpected errors must all degrade to "relay disabled" rather than crashing weewx.

4. **Extensions run inside the weewx process as the `weewx` user.** There is no separate permission model for extensions — they inherit weewx's process identity. The socket file will be owned by `weewx:weewx` (the process user/group). Our chmod/chown hardening is additional security on top of weewx's model, not a weewx requirement.

5. **Packaging:** `install.py` with `loader()`, `ExtensionInstaller` subclass, `bin/user/` directory, `changelog`, `readme.md`. Our structure is compliant.

---

## Security audit findings (completed)

| # | Finding | Severity | Location |
|---|---------|----------|----------|
| 1 | `on_new_loop_packet` has no top-level try/except — exception crashes weewx | **Critical** | clearskies_relay.py:100-121 |
| 2 | `_start_server()` failure in `__init__` prevents weewx from starting | **Critical** | clearskies_relay.py:57-58 |
| 3 | Socket file permissions not set after bind (inherits umask) | High | clearskies_relay.py:74 |
| 4 | Socket directory permissions not enforced | High | clearskies_relay.py:67 |
| 5 | `_max_clients` defined but never enforced in accept loop | High | clearskies_relay.py:84-94 |
| 6 | Missing thread join on shutdown | Medium | clearskies_relay.py:127-147 |
| 7 | `_accept_loop` doesn't handle unexpected exceptions — thread dies silently | Medium | clearskies_relay.py:84-94 |
| 8 | Socket group ownership not set; `_DEFAULT_SOCKET_GROUP` is `"clearskies"` but ADR-061 requires `"weewx"` | High | clearskies_relay.py:33 |
| 9 | ADR-061 says `clearskies` "Does NOT need weewx group membership" but socket is `weewx:weewx` 0660 — contradiction | High | ADR-061 line 36 vs line 76 |
| 10 | Security baseline has zero coverage of the extension | Medium | security-baseline.md |
| 11 | ARCHITECTURE.md missing extension repo | Low | ARCHITECTURE.md |

---

## Phase 1 — Extension code hardening

Fix all code-level findings. All changes in `repos/weewx-clearskies-extension/bin/user/clearskies_relay.py` (142 lines) and `repos/weewx-clearskies-extension/install.py`.

### T1.1 — Wrap `on_new_loop_packet` in top-level try/except (Finding #1)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** None
- **Do:**
  1. Wrap the entire body of `on_new_loop_packet` (lines 101-121) in `try: ... except Exception as exc: logger.error(...)`. Must catch `Exception` (not `BaseException` — don't suppress `SystemExit`/`KeyboardInterrupt`). Must not re-raise.
  2. Keep the existing inner try/except for JSON serialization (lines 102-106) inside the outer try.
- **Accept:** No exception path in the method can escape to the caller. Except catches `Exception`, logs ERROR, returns silently.
- **QC:** Opus traces every code path and confirms no exception escapes.

### T1.2 — Graceful degradation on socket startup failure (Finding #2)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** None (parallel with T1.1)
- **Do:**
  1. Wrap `_start_server()` call in `__init__` (line 57) in try/except. On failure: log ERROR, set `self._disabled = True`, do NOT bind the event handler.
  2. Add early return in `on_new_loop_packet` if `self._disabled`.
  3. In `shutDown()`, skip socket/thread cleanup if disabled.
  4. Log message must be actionable: include socket path and exception detail.
- **Accept:** weewx starts successfully even when socket path is invalid or permissions prevent binding. Extension simply does nothing when disabled.
- **QC:** Opus confirms `self.bind(weewx.NEW_LOOP_PACKET, ...)` is inside the try block (only called on success), `_disabled` initialized before the try.

### T1.3 — Set socket file permissions after bind (Finding #3)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T1.2
- **Do:**
  1. After `server.bind()`, add `os.chmod(self._socket_path, 0o660)`. Wrap in try/except with WARNING log on failure.
- **Accept:** `os.chmod(0o660)` called after bind. Failure doesn't prevent server from starting.
- **QC:** Opus confirms chmod uses `0o660`, is after bind, has try/except.

### T1.4 — Set socket directory permissions (Finding #4)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T1.2
- **Do:**
  1. Change `os.makedirs` to use `mode=0o770`.
  2. Add best-effort `os.chmod(sock_dir, 0o770)` after makedirs (enforces mode even if dir pre-existed). Wrap in try/except.
  3. No `os.chown()` — extension runs as `weewx`, can't change ownership. Install script handles that.
- **Accept:** makedirs uses `mode=0o770`, chmod applied after, no chown.
- **QC:** Opus confirms mode values and exception handling.

### T1.5 — Enforce connection limit in accept loop (Finding #5)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. In `_accept_loop`, after `accept()`, check `len(self._clients) >= self._max_clients` under the lock.
  2. If limit reached: log WARNING, close the connection, continue loop.
  3. Check must be inside `with self._lock` to avoid races.
- **Accept:** Excess connections rejected immediately. Warning logged. Check is atomic with append.
- **QC:** Opus confirms check is under lock, connection is closed before continue.

### T1.6 — Join accept thread on shutdown (Finding #6)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. In `shutDown()`, after closing server socket and before client cleanup: `self._accept_thread.join(timeout=5.0)`.
  2. Log WARNING if join times out.
- **Accept:** Join called with 5s timeout, positioned after server close and before client cleanup. Shutdown completes even on timeout.
- **QC:** Opus confirms join ordering and timeout handling.

### T1.7 — Broad exception handling in `_accept_loop` (Finding #7)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T1.5 (modifies same method)
- **Do:**
  1. `OSError` from accept() still breaks loop (normal shutdown).
  2. Other exceptions from `accept()`: log ERROR, continue loop.
  3. Connection-handling block (lock, append, limit check): wrap in try/except to prevent single bad accept from killing thread.
- **Accept:** Accept thread can only die from `OSError` (shutdown) or deliberate break. All other exceptions logged and continued.
- **QC:** Opus traces every exception path in `_accept_loop`.

### T1.8 — Update install.py config stanza (weewx guideline compliance)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** None (parallel)
- **Do:**
  1. Per weewx guideline: "List all possible options in [the config stanza], albeit commented out."
  2. Update `CLEARSKIES_RELAY_CONFIG` in `install.py` to include all configurable options:
     ```ini
     [ClearSkiesLoopRelay]
         # Unix socket path for loop packet relay.
         # The Clear Skies API's direct adapter connects here.
         socket_path = /var/run/weewx-clearskies/loop.sock
         # Maximum concurrent client connections (default 8)
         # max_clients = 8
         # Group ownership for the socket file (default: weewx)
         # Must match a group the API user belongs to.
         # socket_group = weewx
     ```
  3. Active option (`socket_path`) is uncommented with the default value. Optional overrides (`max_clients`, `socket_group`) are commented out with their defaults shown.
- **Accept:** All 3 config keys listed in the stanza. `max_clients` and `socket_group` commented out with defaults. `socket_path` active.
- **QC:** Opus reads install.py and confirms all options present per weewx convention.

### T1.9 — Fix socket group ownership (Finding #8)

- **Owner:** `api-dev` (Sonnet)
- **Dep:** T1.3 (modifies same section of _start_server)
- **Do:**
  1. Change `_DEFAULT_SOCKET_GROUP` from `"clearskies"` to `"weewx"` to match ADR-061 (socket `weewx:weewx` 0660).
  2. After chmod in `_start_server`, add `os.chown(self._socket_path, -1, grp.getgrnam(self._socket_group).gr_gid)`. Wrap in try/except with WARNING (extension runs as `weewx`, may not be able to chgrp on all systems).
  3. Log at INFO level: socket path, mode, group.
- **Accept:** Default socket group is `"weewx"`. chown attempted after chmod. Both wrapped in try/except. `grp` import exists.
- **QC:** Opus confirms default group value, chown uses `-1` for uid, `grp.getgrnam` exception (group not found) is caught.

---

## Phase 2 — Deployment on weewx container

All commands on weewx LXD container (192.168.7.20). SSH: `ssh weewx`.

**Dep:** Phase 1 complete.

### T2.1 — Install the extension

- **Owner:** `deploy` (Sonnet)
- **Dep:** Phase 1
- **Do:**
  1. Sync extension repo to weewx container (push to GitHub first if needed, then clone on weewx; or scp the directory).
  2. `sudo weectl extension install <path>`.
  3. Verify: `weectl extension list` shows `clearskies_relay`. weewx.conf has `[ClearSkiesLoopRelay]` section and `data_services` entry.
  4. Do NOT restart weewx yet.
- **Accept:** Extension installed. weewx.conf updated. weewx not restarted.
- **QC:** Opus reviews grep output from weewx.conf.

### T2.2 — Set up socket directory, permissions, and groups (Findings #4, #8, #9)

- **Owner:** `deploy` (Sonnet)
- **Dep:** T2.1
- **Do:**
  1. Create socket directory: `sudo mkdir -p /var/run/weewx-clearskies && sudo chown clearskies:weewx /var/run/weewx-clearskies && sudo chmod 770 /var/run/weewx-clearskies`.
  2. Add `clearskies` to `weewx` group: `sudo usermod -aG weewx clearskies`. **This resolves the ADR-061 contradiction** — `clearskies` needs `weewx` group for socket access (0660 `weewx:weewx`).
  3. Verify: `id clearskies` shows `weewx` in groups.
  4. Create tmpfiles.d entry for boot persistence: `/etc/tmpfiles.d/weewx-clearskies.conf` with `d /var/run/weewx-clearskies 0770 clearskies weewx -`.
- **Accept:** Directory `clearskies:weewx` 0770. `clearskies` in `weewx` group. tmpfiles.d entry exists.
- **QC:** Opus reviews `ls -la`, `id`, and tmpfiles.d file.

### T2.3 — Restart weewx and verify socket creation

- **Owner:** `deploy` (Sonnet)
- **Dep:** T2.1, T2.2
- **Do:**
  1. `sudo systemctl restart weewx`. Wait 10 seconds.
  2. Verify socket: `ls -la /var/run/weewx-clearskies/loop.sock` — should be `weewx:weewx` 0660.
  3. Verify weewx running: `systemctl status weewx`.
  4. Verify logs: `journalctl -u weewx --since "2 min ago" | grep -i clearskies` — should show "listening on" message. No errors.
- **Accept:** Socket exists with correct permissions. weewx running. Startup log present. No errors.
- **QC:** Opus reviews all output, checks for any permission-related WARNINGs from the chmod/chown code.

### T2.4 — Verify API connects to socket

- **Owner:** `deploy` (Sonnet)
- **Dep:** T2.3
- **Do:**
  1. `sudo systemctl restart weewx-clearskies-api`. Wait ~120 seconds (cache warm per ARCHITECTURE.md).
  2. Check API logs: `journalctl -u weewx-clearskies-api --since "3 min ago" | grep -i "connected to weewx relay"`.
  3. Verify SSE: `curl -N -H "Accept: text/event-stream" https://localhost:8765/sse --insecure` — events should flow within 2-3 seconds.
- **Accept:** API logs show connection. `curl /sse` shows loop packet events. End-to-end: weewx → extension → socket → DirectAdapter → SSE → curl.
- **QC:** Opus reviews journal and curl output. Confirms events contain weather data fields.

---

## Phase 3 — Integration verification

**Dep:** Phase 2 complete.

### T3.1 — Error isolation test

- **Owner:** `verify` (Sonnet)
- **Dep:** T2.4
- **Do:**
  1. Delete socket while weewx is running: `sudo rm /var/run/weewx-clearskies/loop.sock`.
  2. Wait for 2+ loop packets to fire. Check weewx logs — no crash, extension logs errors.
  3. Restart weewx. Verify socket recreated with correct permissions.
- **Accept:** weewx survives socket deletion. Extension logs errors. Restart recovers.
- **QC:** Opus confirms no Python traceback killing weewx, extension error messages present.

### T3.2 — API reconnection test

- **Owner:** `verify` (Sonnet)
- **Dep:** T2.4
- **Do:**
  1. Confirm SSE flowing via curl.
  2. Restart weewx (destroys and recreates socket).
  3. Watch API logs for disconnect → backoff → reconnect sequence.
  4. Verify SSE resumes.
- **Accept:** API detects disconnect, reconnects automatically, SSE resumes. Total reconnection under 60 seconds.
- **QC:** Opus reviews journal timeline: disconnect, backoff attempts, reconnection, SSE resumed.

### T3.3 — Connection limit test

- **Owner:** `verify` (Sonnet)
- **Dep:** T2.3
- **Do:**
  1. Open 8 concurrent socket connections (max_clients default).
  2. Attempt 9th — should be rejected immediately.
  3. Check weewx logs for connection limit warning.
  4. Clean up test connections. Verify API reconnects.
- **Accept:** 9th connection rejected. Warning logged. Socket recovers.
- **QC:** Opus confirms rejection and warning in logs.

### T3.4 — Graceful shutdown test

- **Owner:** `verify` (Sonnet)
- **Dep:** T2.3
- **Do:**
  1. `sudo systemctl stop weewx`.
  2. Check logs for "ClearSkiesLoopRelay stopped" message.
  3. Verify socket file removed: `ls /var/run/weewx-clearskies/loop.sock` fails.
  4. No "accept thread did not exit" warning.
  5. Restart weewx, verify clean startup.
- **Accept:** Clean shutdown message. Socket removed. No timeout warnings. Clean restart.
- **QC:** Opus reviews shutdown and restart logs.

---

## Phase 4 — Documentation

**Dep:** Phases 1-3 complete.

### T4.1 — Amend ADR-061 (Finding #9)

- **Owner:** `docs-author` (Sonnet)
- **Dep:** T2.2
- **Do:**
  1. In the process table (line 36), change "Does NOT need: weewx group membership" — move `weewx` group to the "Supplementary groups" column: `weewx-ro (DB read), weewx (socket access)`.
  2. Add `usermod -aG weewx clearskies` to the bare-metal install script with comment explaining it's for socket access.
  3. ADR status stays Accepted — this is a correction, not a new decision.
- **Accept:** Process table shows both groups. Install script updated. Comment explains purpose.
- **QC:** Opus confirms internal consistency: socket `weewx:weewx` 0660, `clearskies` in `weewx` group, access works.

### T4.2 — Update ARCHITECTURE.md (Finding #11)

- **Owner:** `docs-author` (Sonnet)
- **Dep:** Phase 3
- **Do:**
  1. Add `weewx-clearskies-extension` to the repo layout table (no Dockerfile — installs into weewx via `weectl extension install`).
  2. Add note to container inventory: extension is not a container, runs inside weewx process.
  3. Add to ADR reference table: ADR-058, ADR-060, ADR-061.
  4. Update "Input mode" section to reference the extension repo by name.
- **Accept:** All four additions present and accurate.
- **QC:** Opus cross-checks repo table values against actual repo.

### T4.3 — Add extension section to security baseline (Finding #10)

- **Owner:** `docs-author` (Sonnet)
- **Dep:** Phase 1, T4.1
- **Do:**
  1. Add new section **§3.10 ClearSkiesLoopRelay (weewx extension)** with controls:
     - Error isolation (top-level try/except, graceful degradation)
     - Socket file permissions (0660 `weewx:weewx`)
     - Socket directory permissions (0770 `clearskies:weewx`)
     - Connection limit (default 8)
     - No app-level auth on socket (filesystem permissions only)
     - Thread join on shutdown
     - Accept loop resilience
     - No secrets in loop packets
  2. Update scope paragraph to include extension repo.
- **Accept:** Section 3.10 exists with 8 controls, each with source and verification method.
- **QC:** Opus confirms controls match Phase 1 code changes.

### T4.4 — Write deployment procedure

- **Owner:** `docs-author` (Sonnet)
- **Dep:** Phase 2
- **Do:**
  1. Create `docs/procedures/install-weewx-extension.md` covering: prerequisites, directory setup, group membership, tmpfiles.d, extension install, weewx.conf verification, socket path alignment with api.conf, restart, verification, troubleshooting (permission denied, socket not found, group not applied).
  2. Cross-reference from `docs/procedures/deploy-clearskies.md`.
- **Accept:** Complete step-by-step procedure. An operator following it from scratch reaches a working state.
- **QC:** Opus follows procedure mentally step-by-step, confirms completeness.

### T4.5 — Update extension README and changelog

- **Owner:** `docs-author` (Sonnet)
- **Dep:** Phase 1, T4.4
- **Do:**
  1. Add Security section (socket permissions, connection limit, error isolation).
  2. Add Permissions section (ADR-061 reference, directory/socket setup).
  3. Document `socket_group` and `max_clients` config keys with defaults.
  4. Update changelog for hardening release.
- **Accept:** README has Security, Permissions, updated Configuration sections. Changelog updated.
- **QC:** Opus confirms all sections present and accurate.

---

## Dependency graph

```
Phase 1 (Code hardening — extension repo)
T1.1 on_new_loop_packet try/except ──────────────┐
T1.2 graceful degradation on startup ──┐          │
  ├── T1.3 socket file permissions ────┤          │
  │     └── T1.9 socket group owner ───┤          │
  └── T1.4 socket dir permissions ─────┘          │
T1.5 connection limit ─────────────────┐          │
  └── T1.7 accept loop exceptions ─────┤          │
T1.6 thread join on shutdown ──────────┤          │
T1.8 install.py config stanza ─────────┘          │
                                                  │
Phase 2 (Deploy — weewx container 192.168.7.20)   │
T2.1 install extension (dep: Phase 1) ◄───────────┘
T2.2 directory + permissions + groups (dep: T2.1)
T2.3 restart weewx + verify socket (dep: T2.2)
T2.4 verify API connects (dep: T2.3)
         │
         ▼
Phase 3 (Integration — weewx container)
T3.1 error isolation (dep: T2.4)    ─┐
T3.2 API reconnection (dep: T2.4)   ├─ parallel
T3.3 connection limit (dep: T2.3)   │
T3.4 graceful shutdown (dep: T2.3) ─┘
         │
         ▼
Phase 4 (Documentation — meta + extension repos)
T4.1 ADR-061 amendment (dep: T2.2)
T4.2 ARCHITECTURE.md (dep: Phase 3)
T4.3 security baseline (dep: Phase 1, T4.1)
T4.4 deployment procedure (dep: Phase 2)
T4.5 extension README (dep: Phase 1, T4.4)
```

---

## Verification bar — plan-level "done"

All of the following must be true:

- **weewx compliance:** Extension follows all weewx extension guidelines. Fails gracefully. Config stanza lists all options. Packaging format correct.
- **Code:** All 9 code findings fixed. No exception can crash weewx. Socket permissions enforced. Connection limit enforced. Clean shutdown.
- **Socket:** `/var/run/weewx-clearskies/` is `clearskies:weewx` 0770. `loop.sock` is `weewx:weewx` 0660. Verified with `stat`.
- **Groups:** `clearskies` in both `weewx-ro` (DB) and `weewx` (socket). Verified with `id`.
- **End-to-end:** weewx loop → extension → socket → DirectAdapter → SSE → curl client. Verified.
- **Error isolation:** weewx survives socket corruption. Verified (T3.1).
- **Reconnection:** API auto-reconnects after weewx restart. Verified (T3.2).
- **Connection limit:** Excess connections rejected. Verified (T3.3).
- **Clean shutdown:** Thread joined, socket removed, no warnings. Verified (T3.4).
- **ADR-061:** Amended — `clearskies` in `weewx` group with rationale.
- **ARCHITECTURE.md:** Extension repo in all relevant tables.
- **Security baseline:** §3.10 documents 8 controls.
- **Procedure:** `install-weewx-extension.md` exists with complete instructions.
- **README:** Security, Permissions, Configuration sections updated.
