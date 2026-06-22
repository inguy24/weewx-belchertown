# Clear Skies — Operations Manual

Single authority for deployment, security, authentication, monitoring, configuration, and installation rules. Absorbs and replaces `contracts/security-baseline.md`.

When this document conflicts with any other source, **this document wins**.

Companion documents:
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — system topology, ports, containers, routing
- **[API-MANUAL.md](API-MANUAL.md)** — API implementation rules
- **[PROVIDER-MANUAL.md](PROVIDER-MANUAL.md)** — provider module rules

Last updated: 2026-06-21

---

## Table of Contents

1. [Deployment](#1-deployment)
2. [Authentication](#2-authentication)
3. [Network Architecture](#3-network-architecture)
4. [Configuration](#4-configuration)
5. [Logging](#5-logging)
6. [Health and Readiness](#6-health-and-readiness)
7. [Observability](#7-observability)
8. [Updates](#8-updates)
9. [Performance Budget](#9-performance-budget)
10. [Security Model](#10-security-model)
11. [Filesystem Permissions](#11-filesystem-permissions)
12. [Anti-Patterns](#12-anti-patterns)

---

## §1 Deployment

### Topology

**Two-host default.** The API runs on the weewx host alongside the weewx engine and Redis. The dashboard, Caddy, and the config UI run on a separate front-end host. Caddy on the front-end host proxies `/api/v1/*` and `/sse` over the network to the weewx host's API on port 8765.

**Single-host alternative.** All services on one machine. Caddy proxies to local Docker network service names (`api:8765`) or `localhost:8765`. The API uses direct mode (Unix socket to the weewx loop relay) with no broker required.

Do not use a topology beyond these two defaults without understanding the cross-host auth and firewall requirements in §2 and §10. See [ARCHITECTURE.md](ARCHITECTURE.md) for the authoritative topology diagram, port registry, and container inventory — do not duplicate that information here.

### Container images

Each repo builds its own container image independently. A dashboard CSS change does not rebuild the API image. Images are built and pushed in CI on every tagged release. See [ARCHITECTURE.md](ARCHITECTURE.md) for the container inventory, image sources, and lifecycle (init container vs. long-running).

### Install paths

There are exactly two supported install paths:

**Container path (docker-compose + Caddy).** Pull the stack repo. Configure `secrets.env`. Run `docker compose up -d`. Caddy handles TLS automatically via Let's Encrypt (ACME HTTP-01) or DNS-01 challenge for NAT-behind installs. The dashboard is an init container: a multi-stage Node 22 build copies `dist/` to a shared volume, then exits. Caddy serves that volume as static files.

**Native path (pip + systemd + operator web server).** Install each component with `pip install weewx-clearskies-api` into a Python 3.12+ virtual environment. Configure systemd units. Configure an existing web server (Apache, Caddy, or nginx) as the reverse proxy. Example configs for all three web servers are in each component's `INSTALL.md`. TLS via the operator's existing certificate pipeline (certbot, internal CA, or existing wildcard cert).

Do not mix install paths for a single component. If the API is native, its config lives in `/etc/weewx-clearskies/api.conf`; if it is a container, the same path is bind-mounted into the container. The configuration format is identical in both cases.

### Distribution channels

| Channel | What ships there | Who should use it |
|---------|-----------------|------------------|
| PyPI | `weewx-clearskies-api`, `weewx-clearskies-config` Python packages | Native-path Linux/macOS operators |
| Container registry (GHCR) | `weewx-clearskies-api`, `weewx-clearskies-dashboard` images | Docker-path operators |
| GitHub Releases | Tagged source archives, pre-built dashboard bundles, signed checksums | Build-from-source operators |

### Platform support matrix

| Platform | Native install | Docker install | Notes |
|----------|---------------|---------------|-------|
| Debian / Ubuntu (amd64) | Yes — primary supported path | Yes | Recommended for most operators |
| Ubuntu (ARM64 / Raspberry Pi 4+) | Yes — pip + systemd | Yes — use ARM64 image tags | Pi 4 and later recommended; Pi 3 is marginal |
| Raspberry Pi OS (32-bit ARMv7) | Yes — pip only; systemd template differs | Yes — use armv7 image tags | Confirm Python 3.12 available before installing |
| LXD container (Debian/Ubuntu guest) | Yes — same as bare metal | Yes — with nesting enabled | Recommended topology for advanced home-server operators |
| Proxmox VM (Debian/Ubuntu guest) | Yes — same as bare metal | Yes | Standard VM; no special configuration required |
| Docker Desktop (Windows 11) | No — native not supported | Yes — Docker Desktop only | Requires WSL2 backend enabled |
| macOS (Apple Silicon / Intel) | Yes — development use; no launchd template at v0.1 | Yes — Docker Desktop or Colima | Native macOS not tested for production deployments |

Windows native install is not supported. Operators on Windows use Docker Desktop with WSL2.

### Bare-metal install script (native path)

The following script creates the required users, groups, and directories for a native Linux install. Run as root or with sudo before installing the Python packages.

```bash
# Create the service user (no login shell, no home dir, no sudo)
useradd --system --no-create-home --shell /usr/sbin/nologin clearskies

# Create the read-only weewx DB group (separate from the weewx group)
groupadd --system weewx-ro

# Add clearskies to the read-only DB group and the weewx socket group
usermod -aG weewx-ro clearskies
usermod -aG weewx clearskies

# Config directory
mkdir -p /etc/weewx-clearskies
chown clearskies:clearskies /etc/weewx-clearskies
chmod 750 /etc/weewx-clearskies

# Runtime directory for the Unix domain socket
mkdir -p /var/run/weewx-clearskies
chown clearskies:weewx /var/run/weewx-clearskies
chmod 770 /var/run/weewx-clearskies

# Web root owned by Caddy (Caddy must already be installed)
mkdir -p /var/www/clearskies
chown caddy:caddy /var/www/clearskies
chmod 755 /var/www/clearskies

# SQLite: make the weewx database file readable by the weewx-ro group
# (MariaDB: use GRANT SELECT instead — see INSTALL.md)
chgrp weewx-ro /var/lib/weewx/weewx.sdb
chmod g+r /var/lib/weewx/weewx.sdb
```

After running this script, install the Python package, run the wizard to generate config, then enable and start the systemd unit. Full step-by-step procedure is in `INSTALL.md` for each component.

### Config UI distribution

The config UI is distributed separately as `weewx-clearskies-config` on PyPI. It is not containerized. Install it with `pip install weewx-clearskies-config` on the host where it will be accessed from the LAN, then launch with `weewx-clearskies-config`. It is not a daemon — start it to make configuration changes, stop it when done.

---

## §2 Authentication

### No end-user authentication

Clear Skies is a public weather site. There are no visitor accounts, no login forms for site visitors, no session tokens issued to browsers. This matches the entire weewx skin ecosystem — weather data is public information.

Operators who need access control for their site add it at the reverse-proxy layer. Examples: Apache basic-auth (5-line config, documented in `clearskies-stack/INSTALL.md`), Authelia, Cloudflare Access. Clear Skies provides no end-user auth code and has no opinion on which proxy-layer solution operators choose.

### Cross-host shared secret

When the API runs on a different host from the reverse proxy, a shared secret in `X-Clearskies-Proxy-Auth` prevents LAN hosts from bypassing Caddy and hitting the API directly.

**How it works:**

1. Proxy injects the header on every request to the API: `X-Clearskies-Proxy-Auth: <secret>`.
2. API middleware reads the header and compares against `WEEWX_CLEARSKIES_PROXY_SECRET` using constant-time compare (`hmac.compare_digest`). Timing side-channels are not possible.
3. Mismatch: HTTP 401, request rejected before any handler runs.
4. Secret not set: header is silently ignored (same-host safe mode).

**Generating the secret.** The configuration wizard generates the secret, writes it to `secrets.env` on the API host, and prints it for manual copy to the proxy host. Power users: `openssl rand -hex 32`.

**Setting the secret in `secrets.env`:**
```
WEEWX_CLEARSKIES_PROXY_SECRET=<64-char hex string>
```

**Proxy-side header injection:**

| Proxy | Directive |
|-------|-----------|
| Caddy | `header_up X-Clearskies-Proxy-Auth {env.WEEWX_CLEARSKIES_PROXY_SECRET}` in the `reverse_proxy` block |
| Apache | `RequestHeader set X-Clearskies-Proxy-Auth "${WEEWX_CLEARSKIES_PROXY_SECRET}"` |
| nginx | `proxy_set_header X-Clearskies-Proxy-Auth $clearskies_proxy_secret;` |

**Secret rotation.** Generate a new value with `openssl rand -hex 32`. Update `secrets.env` on both the API host and the proxy host. Restart both services. There is no key-expiry mechanism — rotation is manual, triggered by operator policy or a suspected exposure.

### Same-host deployments

When the API binds to `127.0.0.1` or `::1`, no shared secret is needed. The loopback interface is the trust boundary. A local process that can connect to `127.0.0.1:8765` already has shell-level access to the host, at which point the database is also directly readable. The shared secret adds no meaningful protection in this topology.

### Non-loopback without a secret — warning behaviour

When the API is bound to a non-loopback address and `WEEWX_CLEARSKIES_PROXY_SECRET` is not set, the service starts but logs the following warning at startup and every 60 seconds thereafter:

```
WARNING clearskies.middleware: API is bound to a non-loopback address
without WEEWX_CLEARSKIES_PROXY_SECRET set. Any host that can reach
this address can read this service directly, bypassing your reverse
proxy. Set the secret or restrict to loopback. See SECURITY.md.
```

Do not silence this warning. Either set the secret or move the bind address back to loopback.

### Config UI authentication

The config UI (`/wizard`, `/admin`) uses a separate admin username + password, stored as an Argon2id hash in `secrets.env`:
- `WEEWX_CLEARSKIES_ADMIN_USERNAME`
- `WEEWX_CLEARSKIES_ADMIN_PASSWORD_HASH`

**First-run bootstrap.** When no admin hash exists, the config UI prints a one-time 32-byte hex trust token to stdout. Visit the URL shown in the startup banner. Set username and password. Token is invalidated on use and cannot be re-used.

**Login rate limiting.** 5 failed login attempts per IP per minute triggers a 60-second throttle. No permanent lockout (avoids self-DoS).

**Session mechanics.** HTTP-only, `SameSite=Strict` cookie scoped to the bound origin. `Secure` flag set when TLS is active. Sessions expire on process exit when the tool is stopped.

**Recovery.** If the admin password is lost: `weewx-clearskies-config --reset-admin-password`. Clears the hash. Next launch enters bootstrap mode.

Future privileged surfaces (API-level admin endpoints, if added) define their own authentication separately. This is a deliberate constraint — mixing auth schemes across surfaces creates conflation bugs.

---

## §3 Network Architecture

### One-door reverse proxy — mandatory

All public traffic must pass through a single reverse proxy. The proxy is the only internet-facing component. It terminates TLS, sets security headers, enforces path routing, and controls what inner services are reachable.

Never expose any inner service directly to the internet. Never add `ports:` directives to Docker services other than Caddy (ports 80 and 443). See [ARCHITECTURE.md](ARCHITECTURE.md) for the authoritative port registry and Caddy routing table.

**This is not a recommendation — it is a hard architectural constraint.** The security header layer, CSP, HSTS, path filtering, and rate-limiting choke point all live at Caddy. Bypassing Caddy removes all of them simultaneously.

### Inner service binding defaults

All inner services bind to loopback by default. Only Caddy binds to `0.0.0.0`.

| Service | Default bind | Public? |
|---------|-------------|---------|
| API main | `127.0.0.1:8765` | No — Caddy proxies to it |
| API health | `127.0.0.1:8081` | No — loopback probe only |
| Redis | `127.0.0.1:6379` | No — API-local only |
| Config UI | Docker internal network / `localhost:9876` | No — Caddy proxies `/wizard`, `/admin` |
| Caddy | `0.0.0.0:80` and `0.0.0.0:443` | Yes — the single public entry point |

Override the API bind for cross-host deploys: set `[server] bind_host` in `api.conf`. When doing so, set `WEEWX_CLEARSKIES_PROXY_SECRET` on both sides (§2).

### Docker networking note

Docker's port-publishing (`ports:` directives) uses iptables DNAT rules that can bypass `ufw` and user-defined iptables chains on many Linux distributions. Operators who rely on `ufw deny` to protect non-Caddy ports may find those ports are still reachable from the LAN. To mitigate this by default, the stack compose files bind all non-Caddy published ports to loopback: `"127.0.0.1:8765:8765"`, not `"8765:8765"`. Do not change this to `"8765:8765"` unless the API host is on an isolated network segment.

### External provider calls

All outbound calls to external provider APIs (NWS, Open-Meteo, Aeris, OWM, IQAir, USGS, GeoNet, EMSC, RainViewer, etc.) originate from the API, not from the browser. Provider API keys are held in `secrets.env` on the API host. They are never exposed in HTTP responses, never included in JavaScript bundle build-time variables, and never logged (redaction filter enforces this — see §5).

### Security headers — all responses

Caddy sets the following headers on every response via a global `header` block. Do not remove any of them.

| Header | Value |
|--------|-------|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `Content-Security-Policy` | `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'none'` |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` |
| `Server` | (removed — `header -Server` in Caddyfile) |

The API itself sets `X-Content-Type-Options: nosniff` and `Referrer-Policy: no-referrer` on its own responses, and suppresses the `Server` header. HSTS, CSP, and `X-Frame-Options` are Caddy's responsibility — the API does not duplicate them.

### SSE buffering configuration

Configure the reverse proxy to disable response buffering on the `/sse` path and set an adequate idle timeout (minimum 3600 seconds). SSE requires a persistent connection; a proxy that buffers responses will hold events until the buffer fills, causing visible lag or broken reconnects.

| Proxy | Required configuration |
|-------|----------------------|
| Caddy | `flush_interval -1` in the `/sse` reverse_proxy block (Caddy default handles this) |
| Apache | `flushpackets=on timeout=3600` on the `/sse` ProxyPass directive |
| nginx | `proxy_buffering off; proxy_read_timeout 3600s;` in the `/sse` location block |

### Reference Caddyfile

A complete reference Caddyfile for the single-host compose path. The two-host path differs in the `reverse_proxy` upstream address (use the weewx host address instead of the Docker service name `api`) **and** in TLS verification: replace `tls_insecure_skip_verify` with `tls { ca_pool /etc/weewx-clearskies/api-cert.pem }` — disabling TLS verification is not acceptable when Caddy and the API are on different hosts over a non-loopback network (see §12 anti-pattern).

```caddyfile
weather.example.com {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
        X-Content-Type-Options    "nosniff"
        X-Frame-Options           "DENY"
        Referrer-Policy           "strict-origin-when-cross-origin"
        Content-Security-Policy   "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; connect-src 'self'; frame-ancestors 'none'"
        Permissions-Policy        "geolocation=(), microphone=(), camera=()"
        -Server
    }

    handle /api/v1/* {
        reverse_proxy https://api:8765 {
            header_up X-Clearskies-Proxy-Auth {env.WEEWX_CLEARSKIES_PROXY_SECRET}
            tls_insecure_skip_verify
        }
    }

    handle /sse {
        reverse_proxy https://api:8765 {
            header_up X-Clearskies-Proxy-Auth {env.WEEWX_CLEARSKIES_PROXY_SECRET}
            tls_insecure_skip_verify
            flush_interval -1
        }
    }

    handle /branding.json {
        root * /etc/weewx-clearskies
        file_server
    }

    handle /webcam.json {
        root * /etc/weewx-clearskies
        file_server
    }

    handle /pages.json {
        header Cache-Control no-cache
        root * /etc/weewx-clearskies
        file_server
    }

    handle /now-layout.json {
        header Cache-Control no-cache
        root * /etc/weewx-clearskies
        file_server
    }

    handle /card-manifest.json {
        root * /srv/dashboard
        file_server
    }

    handle /webcam/* {
        root * /var/www/clearskies
        file_server
    }

    handle /cards/* {
        root * /var/www/clearskies
        file_server
    }

    handle /wizard*    { reverse_proxy config:9876 }
    handle /bootstrap* { reverse_proxy config:9876 }
    handle /login*     { reverse_proxy config:9876 }
    handle /logout*    { reverse_proxy config:9876 }
    handle /admin*     { reverse_proxy config:9876 }
    handle /static/*   { reverse_proxy config:9876 }

    handle {
        root * /srv/dashboard
        try_files {path} /index.html
        file_server
    }

    request_body {
        max_size 2MB
    }
}
```

For IPv6-only or dual-stack deployments, use bracket notation for IPv6 upstream addresses: `https://[2001:db8::1]:8765`. Caddy resolves hostnames to both address families automatically.

Do not configure CORS, HSTS, CSP, or `X-Frame-Options` in the API. These headers belong in Caddy's global `header` block so they apply identically to every response from every route — static files, API proxy, config UI proxy, and error pages — without per-route exceptions.

---

## §4 Configuration

### Format

ConfigObj `.conf` files with INI syntax. This matches `weewx.conf` convention. ConfigObj is already a transitive weewx dependency — no new install requirement. Sections use `[section]` and `[[subsection]]` notation. ConfigObj's comment-preservation on round-trip is required — the managed-region pattern in the wizard depends on it.

Do not use TOML, YAML, or JSON for service configuration. The canonical format is ConfigObj/INI.

### Settings model

Hand-rolled Python settings classes, parsed from ConfigObj. Do not use Pydantic for configuration parsing. One INI section maps to one settings class. Env vars carry secrets only; all non-secret configuration uses INI sections.

**Settings classes by INI section:**

| INI section | Settings class |
|------------|---------------|
| `[api]` | `ApiSettings` |
| `[health]` | `HealthSettings` |
| `[database]` | `DatabaseSettings` |
| `[station]` | `StationSettings` |
| `[alerts]` | `AlertsSettings` |
| `[aqi]` | `AQISettings` |
| `[earthquakes]` | `EarthquakesSettings` |
| `[seeing]` | `SeeingSettings` |
| `[radar]` | `RadarSettings` |
| `[forecast]` | `ForecastSettings` |
| `[tls]` | `TlsSettings` |
| `[branding]` | `BrandingSettings` |
| `[social]` | `SocialSettings` |
| `[conditions]` | `ConditionsSettings` |
| `[cache_warmer]` | `CacheWarmerSettings` |
| `[charts]` | `ChartsSettings` |
| `[input]` | `InputSettings` |
| `[units]` | `UnitsSettings` |

#### ConditionsSettings keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `haze_detection` | bool | `true` | Enable or disable the haze detection engine. When `false`, sky classification runs without haze confirmation and haze-related calibration is inactive. |
| `gamma` | float | `0.45` | Hygroscopic correction gamma parameter in the f(RH) correction factor. Controls how strongly relative humidity scales apparent extinction. Valid range: 0.1–1.0. Default 0.45 is appropriate for mixed continental aerosol. |
| `haze_aqi_provider` | string | (inherits from `[aqi]`) | AQI provider used for haze PM data. Must be an observed-data provider (Aeris or IQAir). Falls back to the `[aqi]` section provider if not set. Model-based providers (Open-Meteo) are not accepted here — the haze engine will log an error and disable haze confirmation if a non-observed provider is configured. |
| `calibration_percentile` | float | `0.92` | Percentile for clean-sky baseline computation. The baseline Kcs is taken at this percentile of accumulated clean-sky samples in the rolling window. Valid range: 0.90–0.95. |
| `calibration_window_days` | int | `90` | Rolling window size in days for seasonal baseline computation. Samples older than this window are excluded from the current percentile. A 180-day fallback window activates automatically when the 90-day window has fewer than 15 samples. |
| `calibration_min_samples` | int | `22` | Minimum number of clean-sky samples required in the current window before the baseline activates. Until this threshold is reached, haze detection is inactive. Calibration state reports "bootstrapping" below this value, "calibrated" from 22 to 50, and "well-calibrated" above 50. |

### Config directory

Default location: `/etc/weewx-clearskies/`

**Search order (first match wins):**
1. `WEEWX_CLEARSKIES_CONFIG_DIR` environment variable, if set.
2. `/etc/weewx-clearskies/<component>.conf`
3. `~/.config/weewx-clearskies/<component>.conf` (XDG default)

The service refuses to start with no config file and no `--init` flag. A missing config is a startup error, not a silent fallback to defaults.

### File inventory

| File | Purpose | Secrets? | Mode |
|------|---------|---------|------|
| `api.conf` | API component configuration | No | 0640 |
| `charts.conf` | Chart group, chart, and series definitions | No | 0640 |
| `stack.conf` | Stack and config UI state | No | 0640 |
| `secrets.env` | All secrets: DB passwords, API keys, proxy secret, admin credential hash | **Yes** | **0600** |
| `branding.json` | Operator branding: accent colour, logos, theme, social links, analytics identifiers | No | 0644 |
| `webcam.json` | Webcam config: enabled flag, image URL, video URL, refresh interval | No | 0644 |
| `pages.json` | Page visibility: `{ "hidden": [...] }`. Dashboard reads at boot. Written by admin UI. | No | 0644 |
| `now-layout.json` | Now page card layout: `{ "version": 1, "cards": [...] }`. Dashboard reads at boot. Written by admin card layout editor. | No | 0644 |
| `api-cert.pem` | API TLS certificate (Ed25519 self-signed, auto-generated) | No | 0644 |
| `api-key.pem` | API TLS private key | **Yes** | **0600** |
| `ui-cert.pem` | Config UI TLS certificate (auto-generated when `--tls` active) | No | 0644 |
| `ui-key.pem` | Config UI TLS private key | **Yes** | **0600** |

**`secrets.env` is the most restricted file in the entire installation.** Mode 0600, owner `clearskies:clearskies`. Caddy never reads it. The deploy user reads it only to write it. No other file's permissions may be as permissive as this file is restrictive — no other file carries secrets, but this one carries all of them.

Keep `branding.json`, `webcam.json`, `pages.json`, and `now-layout.json` in `/etc/weewx-clearskies/`, never in the web root. Dashboard deploys use `rsync --delete` which wipes `/var/www/clearskies/` on every run. Caddy serves all four files via dedicated routes pointing at `/etc/weewx-clearskies/`.

### Secret naming convention

All environment variable secrets follow this pattern: `WEEWX_CLEARSKIES_<DOMAIN>_<FIELD>`

Examples:
```
WEEWX_CLEARSKIES_FORECAST_AERIS_CLIENT_ID=...
WEEWX_CLEARSKIES_FORECAST_AERIS_CLIENT_SECRET=...
WEEWX_CLEARSKIES_AQI_IQAIR_KEY=...
WEEWX_CLEARSKIES_PROXY_SECRET=...
WEEWX_CLEARSKIES_ADMIN_USERNAME=...
WEEWX_CLEARSKIES_ADMIN_PASSWORD_HASH=...
```

### Secret-leak guard

At startup, the API and config UI walk every parsed `.conf` file. Any leaf key whose name matches the regex `(?i)_(KEY|SECRET|TOKEN|PASSWORD)$` causes a fatal startup error and non-zero process exit. A developer who pastes an API key into `api.conf` gets a clear error and the service does not start — a silent credential leak into logs is prevented.

This is defence-in-depth, not a substitute for putting secrets in `secrets.env` from the start.

### Wizard-API channel (setup endpoints)

The wizard communicates with the API over TLS during setup. TLS is mandatory on this channel — do not allow the wizard to connect to the API without TLS verification.

The API uses an Ed25519 self-signed certificate by default, auto-generated at first start. On first connection, the wizard prints the certificate's SHA-256 fingerprint and requires the operator to confirm it matches what the API printed in its startup banner. This is a trust-on-first-use (TOFU) handshake. After confirmation, the wizard stores the fingerprint and verifies it on subsequent connections.

Setup endpoints use the prefix `/setup/*` (not `/api/v1/*`). These endpoints require either a trust token (first-run wizard) or a valid session cookie (admin re-run). They are never public data endpoints.

### Config UI

The config UI is a standalone FastAPI application on port 9876. It is distributed as `weewx-clearskies-config` on PyPI. It has no Dockerfile — it is not containerized. Start it for configuration changes, stop it when done.

During normal operation, access it at `https://your-site.example.com/admin` via the reverse proxy, which routes `/wizard*`, `/bootstrap*`, `/login*`, `/admin*`, and `/static/*` to `localhost:9876`. This means the config UI benefits from the site's real TLS certificate and does not require a separate browser certificate exception.

For first-run bootstrap before the reverse proxy is configured, run `weewx-clearskies-config` directly and access it at the URL shown in the startup banner (defaults to `[::]:9876`).

### Admin landing page

The config UI serves an admin landing page at `/admin`. This is the default post-login destination.

**Redirect logic:** If `api.conf` does not exist (setup has not been run), `/admin` redirects to `/wizard`.

**Domain-organized sections:** The landing page organizes all configuration areas by domain, not by config file:

| Section | Config source | What it manages |
|---------|--------------|-----------------|
| Station Identity | `stack.conf [ui]` | Station name, location, altitude |
| Database | `api.conf [database]` | DB type, connection |
| Providers | `api.conf [forecast/alerts/aqi/earthquakes/radar/seeing]` | Provider selection + API keys |
| Appearance | `branding.json` | Accent color, logos, site title, favicon, theme mode, custom CSS |
| Social | `branding.json` | Facebook, Twitter/X, Instagram, YouTube URLs |
| Analytics & Privacy | `branding.json` | GA ID, privacy region toggles |
| Webcam | `stack.conf [webcam]` | Enabled, image/video URLs, refresh interval |
| Pages | `pages.json` | Per-page visibility checkboxes |
| Now Page Layout | `now-layout.json` | Card layout editor (drag-and-drop) |
| Column Mapping | `api.conf [column_mapping]` | Observation column mapping |
| TLS | `stack.conf [tls]` | Mode, domain, email, provider |
| Sky Classification | `api.conf [sky_classification]` | CAELUS threshold calibration |
| Haze Calibration | `api.conf [conditions]` + calibration storage | Baseline status, clean-day count, confidence level, PM data import, gamma override |

The Haze Calibration section shows the current calibration state (bootstrapping / calibrated / well-calibrated), the number of clean-sky samples accumulated in the current 90-day window, the current baseline Kcs percentile value, and an import interface for historical PM data. It also provides a toggle to enable or disable haze detection without removing the calibration data.

Each section shows a summary of current values with an "Edit" link that loads the edit form via HTMX fragment swap.

**"Re-run Setup Wizard" link:** At the bottom of the landing page for operators who prefer the guided sequential flow.

### Page visibility management

The Pages section of the admin landing page provides checkboxes for all 9 built-in pages. The "Now" checkbox is always checked and disabled — Now cannot be hidden. Saving writes `/etc/weewx-clearskies/pages.json`. The dashboard reads this file at boot and filters its navigation and routes.

Page visibility is NOT managed through the API. The API's `GET /pages` returns all 9 built-in pages unconditionally. Filtering is the dashboard's responsibility.

### Card layout editor

The Now Page Layout section of the admin landing page provides a drag-and-drop card layout editor:

- **Card palette:** Available cards not currently in the layout, populated from `card-manifest.json` (a build-time JSON file in the dashboard's `dist/` output). Each card shows its thumbnail, display name, and allowed footprint options.
- **Active grid:** Current layout, populated from `now-layout.json` (or the compiled-in default). Cards can be reordered by drag-and-drop (Sortable.js, vendored, MIT license).
- **Keyboard accessibility:** Move-up / move-down / add / remove buttons alongside drag-and-drop. Drag-and-drop is not the only interaction method.
- **Footprint selector:** Each card in the active grid shows a dropdown of its `allowedLayouts` — only configurations the card supports.
- **Save:** POST writes `/etc/weewx-clearskies/now-layout.json`. Card types are validated against the manifest to prevent unknown types.

### Sky classification calibration

The Sky Classification section allows operators to adjust the CAELUS-based sky condition classifier thresholds. The section displays:

- Current threshold values for SCATTER_CLOUDS Km sub-splits and OVERCAST Km×Kv sub-splits.
- The Kasten-Czeplak reference table mapping Km values to okta equivalents and NWS labels.
- Sensor accuracy guidance (Davis ±3–5%, Ambient ~±15%).
- A "Reset to defaults" button.

Thresholds are saved to `api.conf [sky_classification]` and read by the API at startup. Changes require an API restart to take effect.

### Wizard pattern

The wizard is a multi-step first-run flow. Steps are defined by route handlers in `wizard/routes.py` and step templates at `templates/wizard/step_*.html` in the stack repo. Do not document a hardcoded step count — the count changes as steps are added or merged.

Each wizard step follows this contract:
- The server renders a complete HTML fragment for the step body.
- HTMX swaps the fragment into the page container using `hx-target` and `hx-swap`.
- Form submission goes to the next step's POST handler.
- A progress bar element reflects current position (driven by a data attribute, not a hardcoded width).
- Partial progress is persisted to disk when each step's form is submitted — a partial wizard run produces a valid partial config, not an empty or corrupt file.
- Re-running the wizard pre-populates all fields from the existing config.

#### AQI provider selection

The wizard presents the following AQI provider options. The wizard suggests observed-data providers when haze detection is enabled.

| Provider | Data type | Coverage | API key required | Haze-eligible |
|----------|-----------|----------|-----------------|---------------|
| Aeris (Xweather) | Observed — blended real-time monitoring networks | Global | Yes (PWSWeather Contributor Plan provides free access) | Yes — recommended for haze detection |
| IQAir | Observed — hybrid monitoring + crowd-sourced | Global | Yes | Yes |
| Open-Meteo | Model-based — CAMS atmospheric composition model | Global | No | No |
| OpenWeatherMap | Model-based — SILAM atmospheric dispersion model (deprecated) | Global | Yes | No |

Providers marked as "Observed" return measured PM2.5/PM10 concentrations from monitoring stations. Providers marked as "Model-based" return atmospheric model predictions. Only observed-data providers are eligible for haze confirmation — the haze detection engine checks the `is_observed_source` capability flag on the configured provider and disables haze confirmation if the provider is model-based.

OpenWeatherMap AQI is deprecated. It continues to function with a deprecation warning logged at each call. It will be removed in the next major version.

The wizard annotates each provider's option label to show observed vs. model-based and haze eligibility. When haze detection is enabled (`[conditions] haze_detection = true`), the wizard recommends Aeris and warns if the operator selects a model-based provider.

### CLI wizard

`cli_wizard.py` provides an interactive terminal wizard (for operators who cannot open a browser) and a headless flag-driven mode (for scripted provisioning). Both share the `WizardState` backend with the web wizard — they produce the same config output.

Use the CLI wizard for SSH-only installs where opening a browser on the LAN is not feasible.

### Haze calibration bootstrap

The haze detection baseline requires a minimum of 22 clean-sky samples in a 90-day window before it activates. Without historical PM data, building this baseline from real-time observations takes 4–6 months depending on local weather and air quality. Bootstrapping from historical PM data activates the baseline immediately.

**Prerequisites:**
- OpenAQ API key. Register for free at https://explore.openaq.org/register. Set the key in `secrets.env` as `WEEWX_CLEARSKIES_OPENAQ_API_KEY=<your-key>`.
- A PM2.5 reference monitor within 25 km of the station. Check coverage at https://explore.openaq.org/.

**Step 1 — Run the bootstrap command.**

```bash
clearskies-api bootstrap
```

The command automatically:
1. Reads station coordinates (latitude, longitude, altitude) from `weewx.conf`.
2. Queries the OpenAQ API to find the nearest PM2.5 reference monitor within 25 km.
3. Pulls 2 years of hourly PM2.5 data from that monitor.
4. Matches each PM record against the weewx archive (±30-minute window).
5. Computes Kcs (clearness index) for each matched record where radiation data is available.
6. Filters for clean-sky samples: PM2.5 < 12 µg/m³, sun above 10°, no rain, Kcs > 0.3.
7. Seeds the auto-calibration baseline and saves to `/etc/weewx-clearskies/calibration.json`.

Optional flags:
- `--years N` — years of history to pull (default: 2)
- `--max-distance-km N` — search radius for nearest monitor in km (default: 25)

**Step 2 — Review the output.**

The command prints a summary:

```
OpenAQ bootstrap
  Nearest PM2.5 monitor: "Station Name" (3.2 km away)
  Pulling 2 year(s) of history...
  Retrieved 17,520 PM2.5 records
  Matching against weewx archive...
  Results:
    Archive matched:          14,200
    Clean-sky samples:         1,847
    Skipped (no archive):      3,320
    ...
  Calibration state: calibrated (1,847 samples, baseline Kcs = 0.872)
  Saved to /etc/weewx-clearskies/calibration.json
```

**Step 3 — maxSolarRad recomputation (pre-weewx 4.0 archives).**

weewx 4.0.0 began natively archiving `maxSolarRad`. Stations running older weewx versions have NULL in this column for historical records, which prevents Kcs computation. The bootstrap process automatically recomputes `maxSolarRad` for these records using the Ryan-Stolzenbach formula, given the station's latitude, longitude, and altitude from `weewx.conf`. Recomputed values are computationally identical to what weewx would have stored.

**Step 4 — Calibration activates.**

Once ≥ 22 clean-sky samples are accumulated in a 90-day window, the calibration state transitions from "bootstrapping" to "calibrated" and haze detection becomes active. The admin UI Haze Calibration section reflects the current state. If the sample count drops below 15 (extended haze episode, seasonal transition), the baseline widens to a 180-day fallback window. If still insufficient, haze detection deactivates gracefully — no false positives are emitted from an uncalibrated baseline.

---

## §5 Logging

### Format

JSON, one record per line, written to stdout. The API writes no log files. Capture via:
- **Native (systemd):** `journalctl -u weewx-clearskies-api`
- **Container:** `docker logs clearskies-api` or the host's configured Docker logging driver

Log shipping to Loki, ELK, CloudWatch, or any other aggregation system is the operator's concern. Clear Skies does not ship log-shipping configuration.

### Required fields

Every log record must include these fields as top-level JSON keys:

| Field | Format | Required when |
|-------|--------|--------------|
| `timestamp` | ISO 8601 UTC with `Z` suffix — e.g., `2026-06-18T14:23:01.452Z` | Always |
| `level` | One of `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` | Always |
| `logger` | Module-path logger name — e.g., `weewx_clearskies_api.providers.aqi.iqair` | Always |
| `message` | Human-readable string | Always |
| `request_id` | UUID string | All HTTP-request-context records |

Additional structured fields (`provider_id`, `endpoint`, `duration_ms`, `status_code`, etc.) attach as additional top-level JSON keys on the same line. They are never embedded inside the `message` string. Machine-parseable fields must be top-level keys, not freeform text.

### Implementation

Use Python stdlib `logging` with a project-internal JSON formatter. Do not use structlog or loguru — additional logging dependencies are not warranted at v0.1. Configure uvicorn's access log to use the same JSON formatter at startup so all stdout output has a consistent format.

Register the redaction filter at root logger level (not per-handler) so it applies regardless of which handler is active.

### Redaction filter

The filter is a `logging.Filter` subclass installed on the root logger. It rewrites the `LogRecord` before any handler emits it.

Fields it must redact:
- `Authorization` header — any value
- `X-Clearskies-Proxy-Auth` header — any value
- Values of any env var matching `WEEWX_CLEARSKIES_*` (catches provider keys, proxy secret, admin hash)
- Known API key parameter names: `appid`, `client_id`, `client_secret`, `key`, `api_key`
- SQL bind-variable values — log the parameterized query template only, never the bound values
- Full request bodies on authentication endpoints (`/bootstrap`, `/login`, `/admin/*`, `/setup/*`)

The filter is defence-in-depth. Do not log sensitive values and then rely on the filter to catch them — write code that does not produce them in the first place.

### Error responses

Error responses follow RFC 9457 `application/problem+json`. The `detail` field contains only information safe for the operator to see — no stack traces, no internal file paths, no database schema details. Full error context (stack trace, query, request ID) lives in the structured log record. Operators cross-reference the `request_id` in the error response with the log stream.

### Log level

Production default: `INFO`. Override with the `CLEARSKIES_LOG_LEVEL` environment variable. Acceptable values: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`.

Set `DEBUG` only during active incident investigation. At DEBUG level, the service logs at high volume and may include request details that pass through the redaction filter before the filter's regex patterns match.

---

## §6 Health and Readiness

### Health port — separate, loopback-only

The API exposes health, readiness, and metrics endpoints on a dedicated port bound to `127.0.0.1` only. This port is never routed through Caddy to the public internet. Configure with `[health] bind = 127.0.0.1:8081` in `api.conf`.

Default port: 8081. This port is unauthenticated — the loopback binding is the access control. Do not bind it to a public interface without adding proxy authentication in front.

The health port socket follows `rules/coding.md` §1 IPv4/IPv6 dual-stack rules. When configured with `::1` (IPv6 loopback), the socket is IPv6-only. When configured with `127.0.0.1`, it is IPv4-only. For dual-stack loopback, use the hostname `localhost` and let the system resolve both `127.0.0.1` and `::1`.

| Endpoint | Method | Port | Purpose |
|----------|--------|------|---------|
| `/health/live` | GET | 8081 | Liveness probe |
| `/health/ready` | GET | 8081 | Readiness probe |
| `/metrics` | GET | 8081 | Prometheus metrics (opt-in) |
| `/health` | GET | 8765 | Simple main-port canary |

### Liveness

`GET /health/live` returns HTTP 200 whenever the process is alive and responding to HTTP. It performs no external dependency checks. Orchestrators (Docker health checks, systemd `WatchdogSec`) use this to decide whether to restart the container. A liveness failure that persists results in a container restart.

Always returns 200 while the process is up. The process will not return 503 from liveness — if it is alive enough to respond, it returns 200.

### Readiness

`GET /health/ready` checks whether the service is ready to serve real requests. It checks:
- Database connectivity (can establish a connection and run a trivial query)
- Loop subscription state (direct adapter connected to Unix socket, or MQTT adapter connected to broker)
- Capability registry (at least one provider module registered for each enabled domain)

**Response codes and body:**

| `status` value | HTTP code | Meaning |
|---------------|----------|---------|
| `ok` | 200 | All checks pass |
| `degraded` | 200 | One or more non-critical checks failing; core data endpoints functional |
| `unhealthy` | 503 | A critical check failed; service cannot serve requests |

**Response body example (degraded):**
```json
{
  "status": "degraded",
  "checks": {
    "database": {"status": "ok"},
    "loop_subscription": {"status": "ok"},
    "providers": {
      "status": "warning",
      "messages": ["forecast.aeris: quota exhausted"]
    }
  }
}
```

**Degraded returns HTTP 200, not 503.** A single provider failure — quota exhausted, upstream down, key invalid — puts the service in degraded state, not unhealthy. Returning 503 on degraded would cause orchestrators to kill and restart the container, terminating all active SSE connections for all subscribers, for a problem that resolves itself on the next cache refresh. Degraded services still serve weewx archive data and all other providers that are healthy.

### Health probe response body

The `/health/ready` response body provides per-check detail. Orchestrators key on the HTTP status code; the body is for human diagnostics and operator monitoring scripts.

```json
{
  "status": "degraded",
  "checks": {
    "database": {
      "status": "ok",
      "latency_ms": 2
    },
    "loop_subscription": {
      "status": "ok",
      "mode": "direct",
      "socket": "/var/run/weewx-clearskies/loop.sock"
    },
    "providers": {
      "status": "warning",
      "messages": [
        "forecast.aeris: quota exhausted — retry after 2026-06-18T15:00:00Z",
        "aqi.iqair: key invalid — check WEEWX_CLEARSKIES_AQI_IQAIR_KEY"
      ]
    }
  }
}
```

The `checks` object enumerates each dependency by name. Provider failures appear as `warning` within the `providers` check, not as a top-level unhealthy status, because individual provider failures do not prevent the service from serving archive data or other healthy providers.

### Main port canary

`GET /health` on port 8765 returns `{"status": "ok"}` when the service is running and can respond. This is for operators who want a simple reachability check through Caddy without exposing the full readiness state.

---

## §7 Observability

### Logs — always on, zero config

Structured JSON logs (§5) are always available. They require no configuration and no additional infrastructure. Begin all operational investigation here.

### Prometheus metrics — opt-in

Enable with `CLEARSKIES_METRICS_ENABLED=true` in `secrets.env` or the systemd unit's `Environment=` directive. When enabled, `/metrics` is served on the health port (8081, loopback). Format: Prometheus plain-text exposition format.

An example Prometheus scrape configuration for the API:
```yaml
scrape_configs:
  - job_name: clearskies_api
    static_configs:
      - targets: ['127.0.0.1:8081']
    metrics_path: /metrics
```

This scrapes from loopback. For remote Prometheus instances, use a Prometheus push gateway or SSH tunnel — do not expose port 8081 to the network.

### Required metrics

All of the following must be present when metrics are enabled:

| Metric name | Type | Labels | Description |
|-------------|------|--------|-------------|
| `http_requests_total` | Counter | `method`, `endpoint`, `status` | Total HTTP requests by method, route template, status code |
| `http_request_duration_seconds` | Histogram | `method`, `endpoint` | Request duration; buckets at standard latency points |
| `provider_calls_total` | Counter | `provider_id`, `domain`, `outcome` | Provider calls with outcome: `cache_hit`, `cache_miss_success`, `cache_miss_failure` |
| `provider_call_duration_seconds` | Histogram | `provider_id`, `domain` | Duration of cache-miss provider calls only (excludes cache hits) |
| `cache_hits_total` | Counter | `backend` | Cache hits by backend type (`redis`, `memory`) |
| `cache_misses_total` | Counter | `backend` | Cache misses by backend type |
| `db_query_duration_seconds` | Histogram | `endpoint` | Database query duration per API endpoint |

### Cardinality constraints

Metric labels must never include:
- Request or response bodies
- Operator configuration values
- Client IP addresses or any PII
- Full URLs with query parameters — use route templates only (e.g., `/api/v1/archive`, not `/api/v1/archive?start=2026-01-01&end=2026-06-18`)
- User-agent strings

The `endpoint` label uses the FastAPI route template, not the concrete request path. High-cardinality labels make Prometheus memory usage unbounded and degrade query performance.

### OTel and distributed tracing

OpenTelemetry is deferred to a future phase. v0.1 is a single-process service; distributed tracing provides no value without multiple trace producers.

### CI gating per repo

CI fails the PR (blocks merge) on every check below. No exceptions.

| Gate | api | dashboard | stack |
|------|-----|-----------|-------|
| DCO `Signed-off-by:` on every commit | Yes | Yes | Yes |
| Lockfile present and used (`uv sync --locked` / `npm ci`) | Yes | Yes | N/A |
| `pip-audit` (Python) / `npm audit --audit-level=high` (JS) | Yes | Yes | N/A |
| `gitleaks` secret scan on diff and full tree | Yes | Yes | Yes |
| Ruff linter including `S` (Bandit) security rules | Yes | N/A | N/A |
| ESLint with `no-eval`, `react/no-danger` rules | N/A | Yes | N/A |
| mypy strict / pyright type check | Yes | N/A | N/A |
| TypeScript type check (`tsc --noEmit`) | N/A | Yes | N/A |
| pytest (both MariaDB and SQLite backends) | Yes | N/A | N/A |
| vitest unit tests | N/A | Yes | N/A |
| Playwright end-to-end tests | N/A | Yes | N/A |
| axe-core accessibility scan on built dashboard | N/A | Yes | N/A |
| Third-party GHA actions pinned by SHA | Yes | Yes | Yes |

Manual pre-release verification is in `rules/coding.md` §4 and §5.8.

### Middleware stack

Middleware wraps every API request in this order, outermost to innermost:

| Order | Middleware | Purpose |
|-------|-----------|---------|
| 1 (outermost) | `MetricsMiddleware` | Record request counts and durations before any other processing |
| 2 | `RequestIdMiddleware` | Generate `X-Request-ID` UUID and attach it to request state for structured log records |
| 3 | `BodySizeLimitMiddleware` | Enforce 1 MiB body limit before the body is read into memory |
| 4 | `ProxyAuthMiddleware` | Validate `X-Clearskies-Proxy-Auth` when `WEEWX_CLEARSKIES_PROXY_SECRET` is set |
| 5 | `RateLimitMiddleware` | Enforce 60 req/min per IP; bypassed for proxy-authenticated requests |
| 6 | `CORSMiddleware` | Enforce same-origin or operator-configured-origin CORS policy |
| 7 (innermost) | `SecurityHeadersMiddleware` | Set `X-Content-Type-Options`, `Referrer-Policy`, suppress `Server` header |

The order is not negotiable. `MetricsMiddleware` must be outermost so that metrics capture the full request lifecycle including auth failures. `RequestIdMiddleware` must precede any handler that logs, so all log records carry the request ID.

---

## §8 Updates

### Update command by install path

| Install path | Update command | Post-update step |
|-------------|---------------|-----------------|
| Native pip (API) | `pip install -U weewx-clearskies-api` | `systemctl restart weewx-clearskies-api` |
| Native pip (config UI) | `pip install -U weewx-clearskies-config` | Restart config UI if it is running |
| Docker compose (any component) | `docker compose pull && docker compose up -d` | None — compose handles container replacement |
| Source tarball | Download new archive, unpack, reinstall per `INSTALL.md` | `systemctl restart weewx-clearskies-api` |

Update the same way you installed. If you installed with pip, update with pip. If you installed with compose, update with compose.

No in-app self-update mechanism exists at v0.1. The dashboard does not check for new versions. The API does not poll for updates. There is no auto-update daemon. Operators who want automatic updates configure them at the OS/container level (e.g., Watchtower) — this is documented as the operator's choice, not a recommended default.

### Reading the CHANGELOG before upgrading

Read each component's `CHANGELOG.md` before upgrading. CHANGELOG is the single authoritative source of upgrade-relevant information per release:
- Breaking configuration changes
- New required config fields
- Manual migration steps (if any)
- Schema changes to the weewx archive queries
- Security fixes (noted as information, not a support commitment)

Pre-1.0 minor version bumps (`0.5.x → 0.6.x`) may include breaking changes. CHANGELOG will flag them. Post-1.0, breaking changes are major-version bumps only.

### Cross-repo compatibility

Before mixing component versions — for example, upgrading the API but not the dashboard — check the cross-repo compatibility matrix in `clearskies-stack/README.md`. Not all version combinations are tested. The matrix states which (api version, dashboard version) pairs are known-compatible.

### No support windows

Clear Skies is distributed AS-IS under GPL v3. There are no LTS branches, no security-backport commitments for prior releases, no end-of-life schedules, and no support-window promises of any kind. A CHANGELOG entry that says "this release contains a security fix" is information, not a commitment that the prior release will also be patched.

Stay current or accept the risk of running an older release. This posture is non-negotiable — it is built into the license and architectural design.

### Config preservation across upgrades

**Native (pip) path.** Config lives at `/etc/weewx-clearskies/`, outside the Python package directory tree. `pip install -U` writes only to `site-packages/`. Config is untouched automatically.

**Docker compose path.** The stack compose file bind-mounts the host's `/etc/weewx-clearskies/` directory into each container. `docker compose pull` swaps the image layer; the bind-mounted config directory is unchanged. Operators who build custom compose files without the bind-mount will lose config when the container is recreated — this is documented as a loud warning in `clearskies-stack/INSTALL.md`.

**Schema drift.** When a new release requires a new config field, the code defaults the missing field gracefully where feasible, allowing older configs to load. When graceful defaulting is not possible, CHANGELOG states the manual edit required before upgrading. Config-file schema changes are always CHANGELOG-flagged — never silent.

---

## §9 Performance Budget

### API latency targets (p95)

These targets apply to the local development environment with realistic data volumes. Production performance depends on operator hardware, database size, and network conditions — we do not promise these numbers in production deployments.

| Endpoint class | p95 target | Measurement method |
|---------------|-----------|-------------------|
| Archive read (current / today / recent observations) | < 100 ms | pytest-benchmark against SQLite fixture |
| Archive aggregation (chart queries, windowed aggregates) | < 500 ms | pytest-benchmark against representative archive |
| Provider response — cache hit | < 50 ms | pytest-benchmark with mocked cache backend |
| Provider response — cache miss | Bounded by upstream provider response time + retry policy | Not benchmarked locally; monitor in production via metrics |

### Dashboard performance targets

| Metric | Target |
|--------|--------|
| Lighthouse Performance score (Now / Forecast / Charts / Records pages) | ≥ 90 |
| Largest Contentful Paint (LCP) | ≤ 2.5 s |
| Interaction to Next Paint (INP) | ≤ 200 ms |
| Cumulative Layout Shift (CLS) | ≤ 0.1 |
| Initial JS bundle — Now-page route (gzipped) | ≤ 200 KB |

### Targets, not gates

Missed targets are bugs to investigate and backlog items to file — they do not block a release.

When a release misses a target:
1. Record the actual measured values in `docs/audits/<release>.md`.
2. Note the cause (e.g., "new chart type added to Now page pushed bundle to 230 KB gzipped").
3. File a backlog issue if the cause is addressable.
4. Ship the release.

Accessibility failures are different — they are release-blocking per their own ADR because they determine whether a class of visitors can use the dashboard at all. Performance misses are quality signals, not usability gates.

---

## §10 Security Model

### Threat model

The API is a gateway to data, not a door into the host. A vulnerability exploited through the API must not grant an attacker filesystem access, the ability to modify weewx configuration, or lateral movement to other services on the host.

Trust boundaries:
```
Internet
  → Caddy on front-end host
      TLS termination, security headers, rate limiting, path filtering
    → [LAN or Docker internal network]
      → API on weewx host
          loopback or LAN bind, ProxyAuth, input validation, query limits, read-only DB
        → weewx (read-only: weewx.units import only — never engine, never drivers)
        → weewx DB (SELECT grants only — startup write probe enforced)
        → External providers (outbound HTTPS — keys held server-side)
```

Caddy is the only internet-facing component. The API is never directly internet-accessible. Each layer enforces its own constraints — defence in depth.

### Rate limiting

Default: 60 requests per minute per client IP on all API paths. Requests exceeding this limit receive HTTP 429 with a `Retry-After` header. Rate-limit state is stored in Redis when `CLEARSKIES_CACHE_URL` is set; in-process otherwise.

**Multi-worker warning.** In-process rate-limit state is per-worker. A multi-worker deployment without Redis delivers N times the documented rate limit across N workers. Multi-worker deployments must configure Redis.

Rate limiting is bypassed for requests that carry a valid `X-Clearskies-Proxy-Auth` header. This allows Caddy to make high-frequency internal health and SSE requests without hitting the limit.

Rate limiting applies to `GET /sse` connections like any other path. An IP that opens 60+ SSE connections in a minute is rate-limited.

### CORS policy

Default: same-origin. The operator may add one additional dashboard origin via `[api] cors_origins` in `api.conf` (comma-separated list). Never use wildcard `*` — it defeats the same-origin policy enforced by Caddy's security headers and exposes the API to cross-site request abuse. CORSMiddleware is in the middleware stack (see §7) and processes every request.

### Input validation

Every HTTP endpoint uses Pydantic models with `extra="forbid"` wired via FastAPI `Depends()`. Undeclared query parameters are rejected with HTTP 422. Undeclared body fields are rejected with HTTP 422. There are no unvalidated inputs to the API. Provider wire responses are also validated by per-provider Pydantic models — malformed provider responses raise `ProviderProtocolError`, not silent data corruption.

### Body size limit

Maximum request body: 1 MiB. Requests exceeding this are rejected with HTTP 413 before the body is read into memory. Configurable via `[api] max_request_bytes` for paths with legitimately larger payloads.

### Database access

The API connects with a read-only database user:
- SQLite: connection URI includes `?mode=ro`
- MariaDB: `GRANT SELECT ON weewx.* TO 'clearskies'@'localhost'` — no INSERT, UPDATE, DELETE, or DDL

At startup, the API attempts a sentinel `INSERT` against the database. If the insert succeeds (meaning the connection has write access), the service logs CRITICAL and exits non-zero. A writable database connection is a fatal startup error — the service refuses to run.

All queries use SQLAlchemy 2.x parameterized statements: typed `select()` expressions and Core constructs only. F-string SQL and string concatenation in query construction are banned by `rules/coding.md` §1 and enforced by ruff linting in CI.

### Archive query cap

Raw archive queries are capped at 366 days. A time range exceeding this returns HTTP 400 with a clear error message. This prevents expensive full-archive scans from being triggered by a single request.

Database query timeout: 30 seconds on all backends.
- SQLite: `connect_args={"timeout": 30}`
- MariaDB: `read_timeout=30, write_timeout=30` on engine creation

### TLS

TLS is mandatory on the API main port (8765). Default: Ed25519 self-signed certificate, auto-generated at first start. Stored at `/etc/weewx-clearskies/api-cert.pem` and `api-key.pem` (mode 0600).

Caddy uses this certificate for the Caddy→API internal TLS connection. Browsers never see this certificate — the Caddy→browser TLS uses Caddy's auto-issued Let's Encrypt certificate.

In Caddyfile, use `tls_verify = false` or `tls { ca_pool <path-to-api-cert.pem> }` for the API upstream. Do not disable TLS on the API port. Do not configure the API for HTTP-only in production.

### SSE security controls

| Control | Value | Enforcement |
|---------|-------|------------|
| Max concurrent SSE subscribers | 500 | `SSEEmitter._MAX_SUBSCRIBERS` — returns 503 when exceeded |
| Per-subscriber queue maxsize | 64 messages | Slow consumers are ejected when their queue overflows |
| SSE keepalive | Every 15 seconds, SSE comment line | Prevents proxy/firewall idle timeout killing long-lived connections |
| Rate limit on SSE connection establishment | 60/min/IP (same as all paths) | `RateLimitMiddleware` applies to `GET /sse` |

### X-Forwarded-For trusted proxy restriction

`X-Forwarded-For` is honoured only when the direct TCP peer is listed in `_TRUSTED_PROXIES`. Default trusted proxies: `127.0.0.1`, `::1`. XFF headers from non-trusted peers are ignored — the direct peer IP is used as the client address for rate limiting and logging. This prevents rate-limit bypass by spoofing XFF from an untrusted IP.

### systemd hardening (mandatory for production native installs)

All of the following flags must be present in the `weewx-clearskies-api.service` unit file. The command `systemd-analyze security weewx-clearskies-api` must return an exposure score ≤ 3.0.

| Flag | Value | Rationale |
|------|-------|-----------|
| `User` | `clearskies` | Dedicated service user, no sudo |
| `NoNewPrivileges` | `yes` | Prevents privilege escalation via setuid |
| `ProtectSystem` | `strict` | OS and package dirs read-only |
| `ProtectHome` | `yes` | Home directories inaccessible |
| `PrivateTmp` | `yes` | Private `/tmp` namespace |
| `ProtectKernelTunables` | `yes` | `/proc/sys` and sysfs kernel parameters inaccessible |
| `ProtectKernelModules` | `yes` | Module loading blocked |
| `ProtectControlGroups` | `yes` | cgroups hierarchy read-only |
| `RestrictAddressFamilies` | `AF_INET AF_INET6 AF_UNIX` | Only TCP/IP and Unix sockets |
| `RestrictNamespaces` | `yes` | Namespace operations blocked |
| `LockPersonality` | `yes` | Execution domain locked |
| `CapabilityBoundingSet` | (empty string) | All capabilities dropped |
| `AmbientCapabilities` | (empty string) | No ambient capabilities |
| `SystemCallFilter` | `@system-service` | Restricts to normal service syscalls |
| `SystemCallErrorNumber` | `EPERM` | Filtered syscalls return EPERM, not SIGKILL |
| `ReadWritePaths` | Config dir and data dirs only | No log dir — logs go to stdout |

Note: `MemoryDenyWriteExecute` is excluded. Python requires writable + executable memory pages for its JIT and code compilation.

### Docker hardening

| Control | Compose directive | Required value |
|---------|-----------------|---------------|
| Runtime user | `user:` | `clearskies` (explicit UID, non-root) |
| Capability drop | `cap_drop:` | `[ALL]` |
| Capability add | `cap_add:` | (empty — no capabilities added back) |
| Root filesystem | `read_only:` | `true` |
| `/tmp` | `tmpfs:` | Mount as tmpfs |
| no-new-privileges | `security_opt:` | `[no-new-privileges:true]` |
| Privileged mode | `privileged:` | `false` (never set true) |
| Host network | `network_mode:` | Never `host` |

All containers run these controls. The dashboard init container is exempt from `read_only` (it writes `dist/` to a volume) but still runs non-root with no capabilities.

### Dedicated service user

All runtime services run under the `clearskies` system user. This user has:
- No login shell (`/usr/sbin/nologin`)
- No home directory
- No sudo access
- No membership in any privileged group except `weewx-ro` (DB read) and `weewx` (socket access)
- No access to `/etc/shadow` or other privileged system files — verify access denied on direct read attempt after install

Create with: `useradd --system --no-create-home --shell /usr/sbin/nologin clearskies`

### Dependency scanning

| Repo | Command | Frequency |
|------|---------|----------|
| Python repos (api, stack) | `pip-audit` against `uv export --format requirements-txt` output | Every PR + nightly schedule |
| JavaScript (dashboard) | `npm audit --audit-level=high` | Every PR + nightly schedule |
| All repos | `gitleaks` on diff + full tree | Every PR + pre-commit hook |
| All repos | Third-party GHA actions pinned by SHA (not tag) | Reviewed on every dependency update PR |

CI fails the PR on any new high-severity advisory or detected secret leak.

### Dashboard security controls

| Control | Enforcement |
|---------|------------|
| No `eval` / `Function` / `innerHTML` with untrusted data | ESLint `no-eval`, `no-implied-eval`, `no-new-func`, `react/no-danger` — CI fails on violation |
| Zero external scripts in built bundle | `index.html` post-build inspection in CI |
| SRI required if external script ever added | Reviewer enforces `integrity=` + `crossorigin=` on any future external `<script>` |
| Markdown content sanitization | `react-markdown` with default sanitizers; raw HTML pass-through disabled; unit test proves `<script>` tags are rendered as text |
| Output escaping in JSX | React default escaping; `dangerouslySetInnerHTML` banned except in the one allowlisted sanitized-markdown component |
| CSP | Set by Caddy (§3), not the dashboard |
| `npm audit --audit-level=high` clean | CI gate, every PR |
| `package-lock.json` in CI | `npm ci` (not `npm install`); lockfile committed to repo |

---

## §11 Filesystem Permissions

### Runtime process model

Every runtime process runs under a dedicated system user with no login shell, no sudo access, and exactly the filesystem access it needs.

| Process | User | Group | Supplementary groups | Purpose |
|---------|------|-------|---------------------|---------|
| API | `clearskies` | `clearskies` | `weewx-ro` (DB read), `weewx` (socket access) | REST endpoints, SSE, provider calls, unit conversion |
| Config UI | `clearskies` | `clearskies` | — | Setup wizard and admin config management |
| Caddy | `caddy` | `caddy` | — | Reverse proxy, TLS, static file server |
| Redis | `redis` | `redis` | — | Provider response cache |
| Dashboard build | deploy user | — | — | Build-time only — not a runtime process |
| weewx + loop relay | `weewx` | `weewx` | — | Unchanged — Clear Skies does not modify weewx's process model |

**`ubuntu` at runtime: NO.** The `ubuntu` user (or any general deploy user) handles deploy-time operations only: `git pull`, `npm run build`, `rsync`, `systemctl restart` via sudo. No runtime service runs as `ubuntu`. In Docker, deploy operations are handled by image build — no deploy user is present at runtime.

### Config directory permissions

| Path | Owner | Mode | Read by | Written by | Notes |
|------|-------|------|---------|-----------|-------|
| `/etc/weewx-clearskies/` (dir) | `clearskies:clearskies` | 0750 | API, Config UI | Config UI | Directory root. Caddy reads specific files via 0644 world-read on those files. |
| `api.conf` | `clearskies:clearskies` | 0640 | API, Config UI | Config UI (wizard apply) | No secrets — secret-leak guard enforced at startup. |
| `charts.conf` | `clearskies:clearskies` | 0640 | API | Config UI, migration tool | Chart definitions. |
| `stack.conf` | `clearskies:clearskies` | 0640 | Config UI | Config UI | Wizard/UI state. |
| `secrets.env` | `clearskies:clearskies` | **0600** | API (`EnvironmentFile=`), Config UI | Config UI (wizard apply) | **Most restricted file.** DB passwords, API keys, proxy secret. Caddy never reads this. |
| `branding.json` | `clearskies:clearskies` | 0644 | Caddy (serves to browser), API | Config UI (wizard apply) | World-readable — Caddy serves it directly. No secrets. |
| `webcam.json` | `clearskies:clearskies` | 0644 | Caddy (serves to browser) | Config UI (wizard apply) | World-readable. No secrets. |
| `api-cert.pem` | `clearskies:clearskies` | 0644 | Caddy (upstream TLS verification) | API (auto-generated at first start) | API self-signed TLS cert. Caddy trusts this cert for the internal Caddy→API connection. |
| `api-key.pem` | `clearskies:clearskies` | **0600** | API only | API (auto-generated) | API TLS private key. Owner-read only. |
| `ui-cert.pem` | `clearskies:clearskies` | 0644 | Config UI | Config UI (auto-generated when `--tls` active) | Config UI self-signed cert. |
| `ui-key.pem` | `clearskies:clearskies` | **0600** | Config UI only | Config UI (auto-generated) | Config UI TLS private key. |

### Web root permissions

| Path | Owner | Mode | Read by | Written by | Notes |
|------|-------|------|---------|-----------|-------|
| `/var/www/clearskies/` (dir) | `caddy:caddy` | 0755 | Caddy | Deploy script (rsync, then chown) | SPA root. Wiped by `rsync --delete` on every dashboard deploy. |
| `/var/www/clearskies/*` (files) | `caddy:caddy` | 0644 | Caddy, browsers | Deploy script | Static HTML/CSS/JS. World-readable (served directly to browsers). |
| `/var/www/clearskies/webcam/` | read-only mount | — | Caddy | External capture process on weewx host | LXD disk device or bind mount. Read-only inside the serving container. Never written by Clear Skies itself. |

### Runtime directory permissions

| Path | Owner | Mode | Read by | Written by | Notes |
|------|-------|------|---------|-----------|-------|
| `/var/run/weewx-clearskies/` | `clearskies:weewx` | **0770** | API | weewx extension (loop relay) | Group `weewx` with group-write so the weewx extension can create the socket file inside. |
| `/var/run/weewx-clearskies/loop.sock` | `weewx:weewx` | **0660** | API (connects as client) | weewx extension (runs socket server) | Created by the loop relay at weewx startup. API connects as client via `weewx` group membership. |
| `/tmp` (in container) | — | tmpfs | API | API | Mounted as tmpfs in Docker. `PrivateTmp=yes` on bare-metal native installs. |

**Socket directory is 0770, not 0777.** Only `clearskies` and `weewx` group members may enter the directory. This prevents other local processes from enumerating or connecting to the socket.

### Caddy-specific permissions

| Path | Owner | Mode | Notes |
|------|-------|------|-------|
| Caddyfile | `caddy:caddy` | 0644 | Generated by the wizard TLS configuration step. |
| ACME cert storage (`/data/caddy/` or `.caddy/`) | `caddy:caddy` | 0700 | Caddy's internal certificate storage for Let's Encrypt certs. No other process reads this directory. |

### Loop relay (weewx extension) connection limit

The loop relay (`ClearSkiesLoopRelay`, part of `weewx-clearskies-extension`) runs inside the weewx process as the `weewx` user. It enforces a maximum of **8 concurrent client connections** in its accept loop. A 9th connection is rejected immediately with a log warning. This limit prevents the relay from becoming a denial-of-service amplifier against the weewx engine process.

No application-level authentication on the socket. Filesystem permissions (0660, `weewx:weewx`) are the access control. Non-group processes receive `EACCES`. The `clearskies` user accesses the socket by virtue of its `weewx` group membership.

### weewx files — read access only

| Path | Access by `clearskies` | How |
|------|----------------------|-----|
| weewx DB (SQLite `.sdb`) | Read-only | `clearskies` in `weewx-ro` group; file is group-readable |
| weewx DB (MariaDB) | Read-only | `GRANT SELECT ON weewx.* TO 'clearskies'@'localhost'` |
| `weewx.conf` | Read-only | World-readable (0644); parsed for station metadata |
| weewx Python packages | Read-only | `sys.path` addition via `.pth` file; only `weewx.units` imported |

Clear Skies never writes to any weewx file. Clear Skies never modifies `weewx.conf`. The weewx engine runs exactly as it did before Clear Skies was installed.

---

## §12 Anti-Patterns

**Never expose the API directly to the internet.** The API must sit behind the reverse proxy. Port 8765 bound to `0.0.0.0` and published to the internet removes the security headers layer, the path-filtering layer, the HSTS and CSP layer, and the single TLS termination point that Caddy provides. This is a deployment error, not a supported configuration.

**Never run any service as `ubuntu` or any sudo-capable user.** Runtime services run as `clearskies`, `caddy`, `redis`, and `weewx`. Using a general-purpose user with sudo at runtime means a single exploited service can write to arbitrary files, execute arbitrary commands, and read `secrets.env` — destroying the entire trust model.

**Never store secrets in `.conf` files.** API keys, database passwords, the proxy shared secret, and admin credential hashes all belong in `secrets.env` (mode 0600). The secret-leak guard at startup catches the common case (`_KEY`, `_SECRET`, `_TOKEN`, `_PASSWORD` key suffixes), but do not rely on the guard as a substitute for correct placement from the start. The guard is defence-in-depth against accidents, not a policy tool.

**Never skip the startup write probe on the database.** The write probe is the enforcement mechanism that guarantees the API cannot modify weewx data. If the probe succeeds (write access exists), the service exits non-zero. Bypassing or disabling the probe removes this guarantee with no compensating control — a bug in the API could silently corrupt the weewx archive.

**Never bind the API to a non-loopback address without setting the proxy shared secret.** Cross-host deployments must set `WEEWX_CLEARSKIES_PROXY_SECRET` on both hosts. Binding to a LAN address without the secret means any host that can reach port 8765 can call provider-enriched endpoints, enumerate station capabilities, and trigger outbound provider API calls — bypassing all Caddy-layer controls.

**Never use `--no-verify` or bypass TLS verification for the Caddy→API connection in production.** In the Caddyfile, use `tls { ca_pool /etc/weewx-clearskies/api-cert.pem }` to trust the API's self-signed certificate specifically. Setting `tls_verify = false` is acceptable for the same-host case where Caddy and the API are on the same Docker network or loopback, but is not acceptable for cross-host deployments where the network between Caddy and the API is not fully trusted.

**Never place `branding.json` or `webcam.json` in the web root (`/var/www/clearskies/`).** Dashboard deploys use `rsync --delete`, which removes every file in the web root that is not present in the `dist/` build output. Both files belong in `/etc/weewx-clearskies/` and are served by a dedicated Caddy `handle` block. Any operator who moves them to the web root will lose them on the next dashboard deploy.

**Never use `eval`, `exec`, `pickle.loads` on untrusted input, `subprocess(shell=True)` with user-controlled data, or `yaml.load` without the `SafeLoader`.** These are banned in `rules/coding.md` §1 and enforced by ruff's `S` (Bandit) ruleset in CI. A PR that introduces any of these fails CI regardless of test coverage.

**Never commit secrets to source or git history.** Use `.env` files (gitignored) or environment variable injection. `gitleaks` runs as a pre-commit hook and in CI on every PR. A detected secret in the diff or full tree fails CI immediately. If a secret is committed accidentally, treat the secret as compromised — rotate it, do not merely rewrite history.

**Never run the config UI as a long-lived daemon.** The config UI is an on-demand tool. Start it to make configuration changes. Stop it when done. Leaving it running permanently on port 9876 expands the attack surface of the configuration management interface unnecessarily. Normal ongoing access is via the reverse proxy at `/admin` — the standalone port 9876 listener is for first-run bootstrap and emergency access only.

---

## Appendix: Source ADR Index

The controls in this manual trace to the following ADRs. When this manual and an ADR conflict on the same point, investigate — one of them is stale, and this manual is updated first.

| Section | Source ADRs |
|---------|------------|
| §1 Deployment | ADR-001, ADR-034, ADR-039, ADR-058 |
| §2 Authentication | ADR-008, ADR-027 |
| §3 Network Architecture | ADR-037, ADR-060 |
| §4 Configuration | ADR-027, ADR-038a, ADR-066, ADR-068 |
| §5 Logging | ADR-029 |
| §6 Health and Readiness | ADR-030 |
| §7 Observability | ADR-031 |
| §8 Updates | ADR-003, ADR-018, ADR-028, ADR-032 |
| §9 Performance Budget | ADR-033 |
| §10 Security Model | ADR-008, ADR-012, ADR-027, ADR-029, ADR-030, ADR-037, ADR-060; `rules/coding.md` §1 |
| §11 Filesystem Permissions | ADR-061 |
| §12 Anti-Patterns | ADR-008, ADR-012, ADR-027, ADR-037, ADR-061; `rules/coding.md` §1 |

ADR index: [docs/decisions/INDEX.md](decisions/INDEX.md)
