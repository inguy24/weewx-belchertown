# reference/clearskies-dev.md — Clear Skies Development Environment

Load alongside [rules/clearskies-process.md](../rules/clearskies-process.md) when doing Clear Skies implementation work.

## Deployment architecture (ADR-034, ADR-027, ADR-038)

### Two topologies

| Topology | API runs… | Config UI + realtime + dashboard run… | Wizard detects via… |
|---|---|---|---|
| **Same-host** (default) | On the weewx host | On the weewx host | DB host is loopback |
| **Cross-host** | On the weewx host (where the DB is) | On a separate host | DB host is non-loopback |

**The API ALWAYS co-locates with weewx.** The API reads the weewx archive DB and `weewx.conf` locally. It does not belong on any other host. If the operator's dashboard is on a different machine, the API still stays with weewx.

### Wizard → API communication (ADR-038)

The wizard talks to the **API**, not the database. Flow:

1. Operator installs API on weewx host. API generates TLS cert + trust token on first start.
2. Operator opens wizard on the dashboard host. Step 1: enters API address + trust token + fingerprint.
3. Wizard connects to API over TLS. All DB operations go through the API.
4. On Apply: wizard POSTs config payload to `POST /setup/apply` → **API writes its own `api.conf` and `secrets.env`** (DB creds, provider keys). Wizard writes LOCAL files only (`realtime.conf`, `stack.conf`, local `secrets.env` with proxy secret + MQTT password).
5. Wizard triggers restarts: API via `POST /setup/restart`, realtime locally.

**The wizard does NOT write `api.conf`.** The API writes its own config after receiving the Apply payload. This is by design (ADR-038).

### What goes where

| File | Written by | Lives on | Contains |
|---|---|---|---|
| `api.conf` | API (via `/setup/apply`) | weewx host | DB connection, station metadata, providers, bind address |
| `realtime.conf` | Wizard config_writer | Dashboard host | SSE bind address, MQTT settings (password as env var ref) |
| `stack.conf` | Wizard config_writer | Dashboard host | UI settings, station display info, topology |
| `secrets.env` (API side) | API (via `/setup/apply`) | weewx host | DB password, provider API keys, proxy secret |
| `secrets.env` (local side) | Wizard config_writer | Dashboard host | Proxy secret, MQTT password |

### Topology auto-detection (routes.py lines 823–836)

```
DB host is loopback → same-host → api_bind_host = 127.0.0.1, realtime_bind_host = 127.0.0.1
DB host is remote   → cross-host → api_bind_host = 0.0.0.0, realtime_bind_host = 0.0.0.0, generate proxy_secret
```

**Bind-address note:** `::` is IPv6-only in both modern MariaDB (`my.cnf` `bind-address`) and uvicorn (sets `IPV6_V6ONLY=1`). Use `*` for MariaDB `bind-address` and `0.0.0.0` for service `bind_host` when you need all interfaces. The wizard was previously emitting `::` for cross-host topology; this was corrected in `87f8467`.

### Pipeline auto-detection (routes.py lines 951–988)

```
API address is loopback → direct mode (no MQTT needed, same machine)
API address is remote   → MQTT mode (broker bridges loop packets between hosts)
```

### Our test infrastructure = cross-host topology

| Host | IP | Role | Services |
|---|---|---|---|
| **weewx** (LXD container) | `weewx.shaneburkhardt.com` (VLAN2, dual-stack) | weewx + API | weewx, weewx-clearskies-api (port 8765 TLS), Redis (port 6379 loopback) |
| **weather-dev** (LXD container) | 192.168.2.113 | Dashboard + config host | weewx-clearskies-config (9876), dashboard static files, Caddy (ports 80/443) |

### One-door reverse proxy (ADR-037)

All public traffic goes through ONE web server. Browser uses relative URLs (`/api/v1/...`, `/sse`). Inner services bind to loopback, never publicly exposed. The proxy routes:

| Browser path | Proxied to |
|---|---|
| `/` (SPA) | Static dashboard files |
| `/api/v1/*` | clearskies-api on weewx host (port 8765 TLS) |
| `/sse` | clearskies-api on weewx host (port 8765 TLS) — SSE merged into API per ADR-058 |

For docker-compose: Caddy is the proxy (bundled, automatic, zero-config).
For native install: operator's existing web server (Apache/nginx/Caddy). Project ships example configs.

CORS is a non-issue by design — everything is same-origin through the proxy.

### Production docker-compose (ADR-034)

The production `docker-compose.yml` (Caddy + api + dashboard) is in the stack repo root. `docker compose up` yields a working stack with auto-LE TLS. The dev/test compose (MariaDB + seed data) remains at `dev/docker-compose.yml`. The realtime service was merged into the API per ADR-058.

**There should be NO clearskies-api running on weather-dev.** The API belongs on the weewx host (where the DB and weewx.conf live).

## Two-machine split

| Machine | Role | What runs here |
|---|---|---|
| **DILBERT** (Windows workstation) | Editing, git, planning, orchestration | VS Code, Claude Code, `git push`, brief-drafting |
| **weather-dev** (LXD container on ratbert) | Runtime, tests, builds | `pytest`, `uv`, `docker compose`, `npm`, `vite` |

Do NOT run pytest, uv, docker, or node toolchains on DILBERT. Do NOT edit source files on weather-dev (except test-author fixture captures, which are committed from weather-dev directly).

## Repo paths

### DILBERT (local clones)

All five repos live under the meta repo:

```
c:\CODE\weather-belchertown\repos\
  weewx-clearskies-api\          # default branch: main
  weewx-clearskies-realtime\     # default branch: main
  weewx-clearskies-dashboard\    # default branch: main
  weewx-clearskies-stack\        # default branch: main
  weewx-clearskies-design-tokens\# default branch: main
```

Meta repo (`c:\CODE\weather-belchertown\`) default branch: **master**.

### weather-dev (runtime clones)

```
/home/ubuntu/repos/
  weewx-clearskies-api/
  weewx-clearskies-realtime/
  weewx-clearskies-dashboard/
  weewx-clearskies-stack/
  weewx-clearskies-design-tokens/
```

Owner: `ubuntu`. Container IP: `192.168.2.113` (DHCP/SLAAC on `br-vlan2`).

## SSH access

Direct SSH from DILBERT using the project SSH config at `.local/ssh/config`. Always use `-F .local/ssh/config`.

```bash
# Direct SSH to weather-dev
ssh -F .local/ssh/config weather-dev "<command>"

# Direct SSH to weewx
ssh -F .local/ssh/config weewx "<command>"

# Ratbert host (LXD management only — NOT for accessing weewx or weather-dev)
ssh -F .local/ssh/config ratbert "<command>"
```

**Do NOT go through ratbert with `lxc exec` to reach weewx or weather-dev.** Direct SSH is configured and works. The only container that still requires `lxc exec` through ratbert is `cloud` (legacy Belchertown, no direct SSH).

Keys and config live in `.local/ssh/` (project directory, replicates via Nextcloud). NOT in `~/.ssh/`.

## Sync: DILBERT to weather-dev

1. Commit and push to GitHub from DILBERT.
2. Run the sync script (pulls all five repos on weather-dev via `git pull --ff-only`):

```bash
# From the meta repo on DILBERT (bash tool):
scripts/sync-to-weather-dev.sh

# Or pull a single repo:
scripts/sync-to-weather-dev.sh weewx-clearskies-api
```

## Toolchain on weather-dev

- **Python:** 3.12
- **Package manager:** uv
- **Test runner:** pytest (via uv)
- **Node:** 22 LTS
- **Docker:** Engine 29.4 + Compose v5

## Common commands

### Run pytest (api repo)

```bash
ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=short -q"
```

Quick summary only (pass/skip/fail counts):

```bash
ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 | tail -3"
```

### Run a specific test file or marker

```bash
# One file:
ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_radar_rainviewer.py -v"

# By marker (e.g., integration tests):
ssh weather-dev "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest -m integration --tb=short"
```

### Run condition module tests (on weewx, NOT weather-dev)

The API is installed natively on the weewx container. Condition module tests (haze, calibration, sky, fog) run there — weather-dev is for dashboard and config UI only.

```bash
# Haze + calibration tests only
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py --tb=short -q"

# All four condition modules
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_haze_condition.py tests/test_auto_calibration.py tests/test_sky_condition.py tests/test_fog_condition.py --tb=short -q"

# Full API suite (only when needed)
ssh -F .local/ssh/config weewx "cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=short -q"
```

### Browser testing

The public-facing dev dashboard is at:

```
https://weather-test.shaneburkhardt.com
```

This is the URL to use for visual verification, screenshots, and all browser-based testing. Do NOT use raw container IPs — use FQDNs for dual-stack compatibility.

For direct service ports via SSH (curl from weather-dev), use `ssh weather-dev "curl http://localhost:<port>/..."`.

## Pytest baselines

Track the pass/skip/fail count at each round close to detect regressions.

| Round | Commit | Passed | Skipped | Failed |
|---|---|---|---|---|
| 3b-13 close | ecd7e75 | 1954 | 364 | 0 |
| 3b-14 close | f2362ee | 2123 | 364 | 0 |
| 3b-15 close | ad1fe37 | 2283 | 364 | 0 |
| 3b-16 close | ae4a86d | 2302 | 364 | 0 |
| post-3b cleanup | 8e691f4 | 2305 | 364 | 0 |
| P4-R1 close | 66cb2e9 | 2311 | 365 | 0 |
| P4-R3 close | 2dcb6f6 | 2311 | 365 | 0 |

## Realtime pytest baselines

| Round | Commit | Passed | Skipped | Failed |
|---|---|---|---|---|
| P4-T1 initial | cf7b6ab | 72 | 0 | 0 |
| P4-R3 close | 640d2dc | 78 | 0 | 0 |

## Dashboard bundle baselines

Track gzipped JS bundle size at each round close against ADR-033's 200 KB target.

| Round | Commit | Gzipped JS | % of budget |
|---|---|---|---|
| P3-T1 scaffold | 52d2d9a | 60.14 KB | 30% |
| P3-T2 mock-data | 29692cd | 194.77 KB | 97% |
| P3-T3 priority-pages | 716873a | 96.78 KB | 48% |
| P3-T4 remaining-pages | 49c44a0 | 93.01 KB | 47% |
| P3-T5 API wiring | 2e385e7 | 100.0 KB | 50% |
| P3-T6 mobile-first | a3a70f9 | 95.11 KB | 48% |
| P3-T7 light-dark-mode | 14eeb95 | 95.68 KB | 48% |
| P3-T8 theming-branding | af1ff8e | 96.16 KB | 48% |
| P4-T2 SSE wiring | f2a30e4 | 96.16 KB | 48% |
| P4-R3 close | 6ee7b24 | 96.21 KB | 48% |

## Dashboard vitest baselines

| Round | Commit | Passed | Skipped | Failed |
|---|---|---|---|---|
| P4-T2 initial | f2a30e4 | 40 | 0 | 0 |
| P4-R3 close | 6ee7b24 | 40 | 0 | 0 |

## GitHub remotes

All repos under `github.com/inguy24/`:

- `weewx-clearskies-api`
- `weewx-clearskies-realtime`
- `weewx-clearskies-dashboard`
- `weewx-clearskies-stack`
- `weewx-clearskies-design-tokens`

Branching policy (pre-1.0): no feature branches. Commit straight to `main` (api repos) / `master` (meta repo).
