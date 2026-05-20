# Plan: Build Config UI + Deploy Clear Skies for Live Testing

**Status:** Approved 2026-05-19. Phase 0 not yet started.
**Approved by:** shane
**Predecessor:** Phase 4 (clearskies-realtime + integration) completed 2026-05-19.

---

## Context

Phases 2-4 built the core backend (API with 24 provider modules across 5 domains, realtime SSE bridge, dashboard SPA with 9 route pages). A post-Phase-4 ADR compliance audit (2026-05-19) found 15+ ADR requirements that were decided but never implemented — most critically the configuration UI (ADR-027). Without it, operators cannot set up Clear Skies, and the product cannot be meaningfully tested.

**Key insight:** The per-round auditor checked code that *was* written but never checked whether all code that *should have been* written actually was. A new rule was added to `rules/clearskies-process.md` requiring a phase-boundary ADR compliance sweep before declaring any phase complete.

This plan builds the config UI, deploys everything on the user's network, and tests the full setup-to-dashboard flow against live weather data.

## Pre-reading for new sessions

Before starting any phase, load these files:

| File | Why |
|------|-----|
| `rules/clearskies-process.md` | Agent orchestration rules, audit rules, plan discipline |
| `rules/coding.md` | Security, accessibility (§5), IPv6 dual-stack (§1), style |
| `docs/decisions/ADR-027-config-and-setup-wizard.md` | The spec for the config UI — read in full |
| `docs/decisions/ADR-035-user-driven-column-mapping.md` | Column mapping wizard step spec |
| `docs/decisions/ADR-008-auth-model.md` | Shared secret for cross-host deploys |
| `docs/decisions/ADR-037-inbound-traffic-architecture.md` | Reverse proxy architecture |
| `reference/CREDENTIALS.md` | Passwords, API keys, access details |
| `reference/weather-skin.md` | weewx setup, database details |

For network/infrastructure context:
| File | Why |
|------|-----|
| `c:\CODE\Windows Server\reference\ratbert-lxd.md` | LXD container inventory, IPs, VLAN layout |
| `c:\CODE\Windows Server\reference\networking.md` | VLAN topology, DNS (DOGBERT), NPM config |
| `c:\CODE\Windows Server\rules\ratbert-lxd.md` | Safety rules for container operations |

## Design decisions made during planning (2026-05-19)

These are refinements to ADR-027 approved by the user. **ADR-027 must be updated in Phase 0a before coding begins.**

1. **Default bind: all interfaces (`[::]`), not loopback.** Target audience is weather hobbyists running headless servers (Raspberry Pi, NAS, containers). They access the wizard from a laptop/phone on the LAN. Localhost-only would require SSH tunneling — too much friction.

2. **HTTP by default for standalone mode.** Self-signed certs cause browser warnings that confuse operators and train them to ignore security warnings. The first-run wizard is a one-time setup on a private network. `--tls` flag available for opt-in self-signed HTTPS. `--localhost` flag restricts to loopback if desired.

3. **`/admin` path for ongoing access.** After the reverse proxy is configured, the config UI is accessible at `https://site.example.com/admin` — routed by Apache/Caddy/nginx to the config backend, inheriting the site's real TLS certificate. Same site, same URL, same cert. Like WordPress's `/wp-admin`. Standalone mode on port 9876 is for first-run bootstrap and emergency access only.

4. **Config tool is host-agnostic.** Does NOT assume it runs on the same machine as weewx or the database. Connects to the database over the network. Auto-detect from a local weewx.conf is a convenience shortcut, not the primary path. Natural install location is wherever the website will run.

5. **API installed on the weewx container.** The whole point of the API is that the database doesn't have to cross a firewall. MariaDB stays localhost-only for weather data. The API binds dual-stack `[::]` on port 8765, protected by a shared secret header.

6. **Frontend: Jinja2 + HTMX + lightweight CSS framework (e.g., Pico CSS).** The config tool is a Python package distributed via PyPI — adding a Node build step for React adds two-toolchain friction that isn't worth it for forms and tables. HTMX handles interactive wizard flow via HTML attributes (server renders fragments, browser swaps them in) — no complex JavaScript needed. Jinja2 produces semantic HTML that's inherently accessible. No build step; static files ship directly in the Python package.

## Network topology (for deployment phases)

```
Internet → CCR2004 router (192.168.2.254)
  → VLAN 7 (cloudDMZ, 192.168.7.0/24):
      NPM (192.168.7.5)         — Nginx Proxy Manager, wildcard *.shaneburkhardt.com cert
      nextcloud (192.168.7.2)    — Nextcloud + EMQX MQTT broker (ports 1883 TCP, 8083 WS)
      weewx (192.168.7.20)      — weewx + MariaDB 10.11, port 3306 bound to [::]
      test container (TBD IP)    — repurposed weather-deploy-rehearsal, moved from VLAN 2

DOGBERT (192.168.2.1) — Windows Server DC, Microsoft DNS
  → Register-IPv6DNS.ps1 runs every 5 min, auto-registers A+AAAA from router NDP table
  → No manual DNS records needed — set container hostname, wait ≤5 min

NPM admin: http://npm.shaneburkhardt.com:81 (LAN only)
NPM already has wildcard cert for *.shaneburkhardt.com (Cloudflare DNS-01)
NPM "LAN Only" access list (ID 1) — restricts to VLANs 1/2/3
```

## Deployment architecture

```
Browser → NPM (192.168.7.5, wildcard cert, TLS termination)
  → Test container (Apache, VLAN 7)
      ├── /            → dashboard static files
      ├── /api/v1/*    → proxy to weewx.shaneburkhardt.com:8765 (with X-Clearskies-Proxy-Auth header)
      ├── /sse         → proxy to localhost:8766 (realtime, SSE-specific: no buffering, long timeout)
      └── /admin/*     → proxy to localhost:9876 (config UI, Argon2id-protected)

weewx container (192.168.7.20):  weewx + MariaDB + clearskies-api (port 8765)
Test container (VLAN 7):         Apache (port 80) + dashboard + realtime (port 8766) + config tool (port 9876)
```

## Credentials needed (retrieve at Phase B time)

- **weewx MariaDB password:** In `/etc/weewx/weewx.conf` at `[DatabaseTypes][[archive_mysql]]` on the weewx container. NOT yet in `reference/CREDENTIALS.md`.
- **New read-only DB user:** Create `clearskies` with `GRANT SELECT ON weewx.*` — the API's startup write-probe refuses to start if it has write access.
- **MQTT broker (for realtime):** EMQX on nextcloud container (192.168.7.2). Subscriber: `weewx-web` / `KikiCourtland127`, TCP port 1883.
- **Provider API keys (already known):**
  - Aeris: client_id `uu1BzHkZXRrtz0tMc6HfQ`, client_secret `MiXYXLbPliJWyB1LRi60ZJYCmMwgyO3FcjLJp8Wp`
  - IQAir: `4c593433-c2f1-4c77-9395-65b1594b2641`
  - OpenWeatherMap: `64b86d9a5331419d98bed6a2a6c46d59`
  - NWS: keyless (user-agent string only)
  - OpenMeteo: keyless (free tier)
  - RainViewer: keyless
  - USGS: keyless

## Resolved: subdomain name

**`clearskies.shaneburkhardt.com`** — internal-only via NPM "LAN Only" access list. DNS auto-registered by DOGBERT's `Register-IPv6DNS.ps1` from the router NDP table (container hostname must be set to `clearskies`).

---

## What to build

### Configuration UI — implement ADR-027 as specified

**Full spec:** [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) (read in full before starting). What follows is the development task breakdown.

The config UI is a standalone Python web application in `weewx-clearskies-stack` (entry point: `weewx-clearskies-config`). Two modes: **wizard** (first-run guided flow) and **master configuration page** (re-run for ongoing edits). Not a daemon.

**Two access modes:**
- **First-run standalone:** `weewx-clearskies-config` on `[::]:9876`, HTTP, all interfaces. For initial setup before the reverse proxy exists.
- **Normal operation (`/admin`):** Through the site's reverse proxy with real TLS. Like `/wp-admin`.

**Wizard flow (remote-DB-first):**
1. **Database connection** — host, port, username, password. "Detect from local weewx.conf" shortcut if on same machine. "Test Connection" button.
2. **Schema introspection + column mapping** — connects remotely. Stock columns auto-map (60-entry `STOCK_COLUMN_MAP`), non-stock columns presented with heuristic suggestions per ADR-035.
3. **Station identity** — from DB or manual. Timezone via `timezonefinder` or manual.
4. **Provider selection** — per domain (forecast, alerts, AQI, earthquakes, radar) with region-based recommendations from lat/lon.
5. **API key entry** — masked input, "Test" button per provider.
6. **Deployment topology** — same-host or cross-host. Shared-secret generation for cross-host.
7. **Service bind addresses** — dual-stack defaults.
8. **Admin credentials** — Argon2id hashed, stored in secrets.env.
9. **Review + apply** — writes local configs. For remote services: downloadable configs or `--headless` command.

**Existing code to reuse** (already in the API repo):

| Component | Location | What it provides |
|-----------|----------|------------------|
| ConfigObj loading + search order | `weewx_clearskies_api/config/settings.py` | Config read/write pattern |
| Secret-leak guard | `weewx_clearskies_api/config/settings.py` | `_check_for_secrets_in_conf()` |
| Schema reflection | `weewx_clearskies_api/db/reflection.py` | `SchemaReflector` |
| Column registry + stock map | `weewx_clearskies_api/db/registry.py` | `STOCK_COLUMN_MAP` (60 entries) |
| Provider capability registry | `weewx_clearskies_api/providers/_common/capability.py` | Geographic coverage data |
| Provider HTTP client | `weewx_clearskies_api/providers/_common/http.py` | Connectivity testing |
| weewx.conf parser | `weewx_clearskies_api/services/weewx_conf.py` | Auto-detect DB config, station info |

**New code:**

| Component | Description |
|-----------|-------------|
| `weewx_clearskies_config/` package | FastAPI app, CLI, all backend endpoints |
| Auth module | Argon2id (`argon2-cffi`), bootstrap token, sessions, rate limiting |
| TLS module (opt-in) | Self-signed cert gen (`cryptography`), behind `--tls` flag |
| Wizard backend | DB detection, test, introspection, mapping, providers, finalize |
| Config CRUD backend | Per-section read/update, MANAGED REGION merge |
| Wizard frontend | Step-by-step flow (9 steps) |
| Master config frontend | Settings dashboard with section nav, edit, test buttons |
| CLI mode | `questionary` or `rich.prompt` terminal flow |
| Frontend assets | Jinja2 templates + HTMX + Pico CSS (or similar). No Node build step. |

**CLI commands:**
```
weewx-clearskies-config                        # all interfaces, port 9876, HTTP
weewx-clearskies-config --localhost             # loopback only
weewx-clearskies-config --bind <addr>           # specific address
weewx-clearskies-config --port <n>              # custom port
weewx-clearskies-config --tls                   # self-signed HTTPS
weewx-clearskies-config --cli                   # terminal flow
weewx-clearskies-config --reset                 # overwrite config
weewx-clearskies-config --reset-admin-password  # clear admin hash
weewx-clearskies-config --show-secrets          # reprint for cross-host copy
weewx-clearskies-config --headless              # non-interactive flags-only
```

### Acceptance criteria

- [ ] Launches on `[::]:9876` HTTP, prints bootstrap URL with token
- [ ] Bootstrap: set admin username + password, token invalidated
- [ ] Wizard: tests remote DB connection
- [ ] Wizard: schema introspection, stock + unmapped columns shown
- [ ] Wizard: operator confirms column mapping
- [ ] Wizard: provider options per domain with region recommendations
- [ ] Wizard: "Test" per provider verifies connectivity
- [ ] Wizard: API key entry, masked input
- [ ] Wizard: network config (bind, proxy topology, shared-secret gen)
- [ ] Wizard: review + apply writes configs + secrets.env (mode 0600)
- [ ] Config files have MANAGED REGION markers, pass secret-leak guard
- [ ] Master config page: loads settings, allows edits, test buttons
- [ ] Master config page: column re-mapping without restart
- [ ] `--cli`, `--headless`, `--reset-admin-password`, `--show-secrets` all work
- [ ] All bind addresses dual-stack
- [ ] WCAG AA / axe-core 0 violations on all config UI pages
- [ ] `/admin` path works through Apache reverse proxy

---

## Execution order

### Phase 0: Update ADR-027 + amend Clear Skies plan

**0a. Update ADR-027** in place with design refinements (see "Design decisions" section above). Status stays Accepted.

**0b. Amend CLEAR-SKIES-PLAN.md** — add tracked tasks for every known ADR compliance gap:

| Gap | ADR(s) | Task description |
|-----|--------|-----------------|
| Internationalization scaffold | ADR-021 | Choose i18n framework, extract hardcoded strings, create 13 locale stubs |
| Observability / metrics | ADR-031 | Prometheus `/metrics` on health port, instrument requests/providers/cache/DB |
| Realtime direct mode | ADR-005 | `adapters/direct.py` — weewx in-process hook for operators without MQTT |
| Earthquakes Leaflet map | ADR-024 | Install Leaflet + react-leaflet, interactive map with magnitude markers |
| NOAA report table parser | ADR-024 | Parse fixed-width text into sortable HTML table |
| Charts page completion | ADR-024 | Average Climate, Monthly, Annual tabs (3 of 4 are stubs) |
| Legal page jurisdiction toggles | ADR-024 | CCPA, GDPR, Quebec Law 25 sections, auto-detect, toggleable |
| Custom page system | ADR-024 | Operator-configurable pages with slug, icon, card composition |
| Hero image system | ADR-009 | Upload, event triggers (condition, season, time-of-day, alerts) |
| Branding API fetch | ADR-022 | Dashboard fetches accent/logo/theme from API (currently hardcoded) |
| Auto-sunrise-sunset theme | ADR-023 | Theme switches at sunrise/sunset (currently falls back to OS) |
| Production docker-compose | ADR-034 | Caddy + API + realtime + dashboard in stack repo |
| Systemd unit files | ADR-034 | Service files for native Linux |
| macOS launchd plist | ADR-034 | Service template for macOS |
| Reverse proxy config files | ADR-037 | Committed Apache, Caddy, nginx examples |
| TypeScript codegen | ADR-018 | Generate dashboard types from OpenAPI spec |
| API benchmark suite | ADR-033 | pytest-benchmark for endpoint performance |
| CI release pipelines | ADR-039 | PyPI + container registry + GitHub Releases workflows |

### Phase A: Build the configuration UI

Multi-agent development in `weewx-clearskies-stack`:

| Round | Agent(s) | Deliverable |
|-------|----------|-------------|
| A1 | api-dev | Package scaffold: pyproject.toml, FastAPI app, CLI with all flags, auth module (Argon2id + bootstrap + session + rate limit), opt-in TLS module |
| A2 | api-dev | Wizard backend: all setup endpoints. Imports existing API modules for schema reflection, capability registry, weewx.conf parsing. |
| A3 | api-dev | Config CRUD backend: per-section read/update, MANAGED REGION merge, provider test |
| A4 | dashboard-dev or api-dev | Wizard frontend (9 steps) |
| A5 | dashboard-dev or api-dev | Master config page frontend |
| A6 | api-dev | CLI mode (`--cli`, `--headless`) |
| A7 | test-author | Tests for all endpoints, flows, auth, MANAGED REGION round-trip |
| A8 | auditor | ADR-027 compliance, security, accessibility |

### Phase B: Infrastructure setup

| Step | Action |
|------|--------|
| B1 | Verify `weather-deploy-rehearsal` on ratbert; start if stopped |
| B2 | Move container: stop → NIC from br-vlan2 to br-vlan7 → start → verify IPv4 + IPv6 |
| B3 | Set hostname → wait for DOGBERT auto-registration → verify DNS |
| B4 | Deploy networkd-dispatcher DDNS script |
| B5 | Read weewx.conf on weewx container for MariaDB password |
| B6 | Create read-only `clearskies` MariaDB user |
| B7 | Record credentials in `reference/CREDENTIALS.md` |

### Phase C: Deploy services

| Step | Action |
|------|--------|
| C1 | weewx container: install clearskies-api (uv + venv + deps + skyfield ephemeris) |
| C2 | Test container: install Apache, clearskies-realtime (with mqtt extra), build + deploy dashboard |
| C3 | Test container: install clearskies-config from stack repo |

### Phase D: Configure using the wizard

| Step | Action |
|------|--------|
| D1 | Run `weewx-clearskies-config` on test container (all interfaces, port 9876, HTTP) |
| D2 | Access `http://<container-ip>:9876` from DILBERT browser |
| D3 | Set admin credentials via bootstrap token |
| D4 | Wizard: DB connection (remote `weewx.shaneburkhardt.com:3306`) → test → introspect → column mapping → station → providers → API keys → cross-host topology → shared secret → review → apply |
| D5 | Local configs written. Remote API config: download or `--headless` on weewx container |
| D6 | Configure Apache vhost (static files + /api/v1 proxy + /sse proxy + /admin proxy) |
| D7 | Add NPM proxy host: subdomain, wildcard cert, "LAN Only", SSE nginx config |

### Phase E: Test

| Step | Action |
|------|--------|
| E1 | Start API on weewx, verify `/health/ready` |
| E2 | Start realtime on test container, verify SSE streams |
| E3 | Open `https://clearskies.shaneburkhardt.com` |
| E4 | Verify all pages with real data |
| E5 | Verify SSE live updates |
| E6 | Test on mobile |
| E7 | User evaluates UI, provides feedback |

---

## Delegation model

- **Lead (Opus):** orchestration, agent prompts, judgment calls, git commits
- **Sonnet agents:** ALL implementation, testing, auditing, SSH commands
- Per `rules/clearskies-process.md`: lead writes prompts, agents write code

## Repos affected

| Repo | Changes |
|------|---------|
| `weewx-clearskies-stack` | New `weewx_clearskies_config/` package (config UI) |
| `weewx-clearskies-api` | Possible minor changes if config UI imports modules directly |
| `weewx-clearskies-dashboard` | No code changes (testing existing build) |
| `weewx-clearskies-realtime` | No code changes (testing existing build) |
| Meta repo (`weather-belchertown`) | ADR-027 update, CLEAR-SKIES-PLAN.md amendment, rule additions |
