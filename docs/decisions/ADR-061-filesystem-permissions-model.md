---
status: Accepted
date: 2026-06-13
deciders: shane
supersedes:
superseded-by:
---

# ADR-061: Filesystem permissions model — comprehensive zero-trust

## Context

Phase 0 research (T0.6) found all Clear Skies services running as the `ubuntu` user — the same user that owns the git repos, has sudo access, and is a member of the weewx group. File permissions have been a recurring source of bugs during testing: services writing files as the wrong user, deploy scripts failing because ownership doesn't match, config files with overly permissive modes.

Moving to Docker production makes this critical — permission misconfiguration in containers causes silent failures or security holes. This ADR establishes the complete filesystem permissions model for every process, every directory, and every file across the entire Clear Skies system.

**Principle: zero trust, minimum privilege.** No runtime process has more access than it needs. `ubuntu` is a deploy-time user only — no runtime service runs as `ubuntu`. Every file has an explicit owner and mode with documented rationale.

## Options considered

| Option | Verdict |
|---|---|
| A. Dedicated service users per process with explicit per-file permissions | **Selected.** Zero-trust, auditable, prevents privilege escalation between components. |
| B. Single `clearskies` user for everything | Rejected — conflates API, Caddy, and Config UI privileges. API shouldn't write TLS certs; Caddy shouldn't read secrets.env. |
| C. Run as `www-data` | Rejected — conflates with web server, wrong trust model. |
| D. Continue running as `ubuntu` | Rejected — sudo access, weewx group member, massively over-privileged. |

## Decision

### Runtime process model — who runs what

Every runtime process has a dedicated user with no login shell, no sudo, and only the filesystem access it needs.

| Process | User | Group | Supplementary groups | Needs | Does NOT need |
|---|---|---|---|---|---|
| **API** | `clearskies` | `clearskies` | `weewx-ro` (DB read), `weewx` (socket access) | Read config, read weewx DB, read weewx.conf, read weewx.units, read/write Unix socket, write to config dir (setup endpoints) | sudo, web root write, Caddy cert access |
| **Config UI** | `clearskies` | `clearskies` | — | Read/write config dir, read/write secrets.env, connect to API | sudo, weewx DB access, web root write |
| **Caddy** | `caddy` | `caddy` | — | Read Caddyfile, read web root, read branding.json/webcam.json, write TLS certs (ACME), connect to API/Config UI | Config dir write, secrets.env read, weewx DB, weewx.conf |
| **Redis** | `redis` | `redis` | — | Read/write its own data dir | Everything else |
| **Dashboard build** | (deploy user) | — | — | Write to `dist/`, rsync to web root. Runs at deploy time only, not at runtime. | Runtime access to anything |
| **weewx** | `weewx` | `weewx` | — | Unchanged. We do not modify weewx's process model. | — |

**`ubuntu` at runtime: NO.** `ubuntu` is used for deploy operations only (git pull, npm build, rsync, systemctl restart via sudo). No runtime service runs as `ubuntu`. In Docker, deploy operations don't exist — the container image IS the deployment.

### Complete filesystem permissions table

#### Config directory (`/etc/weewx-clearskies/`)

| File | Owner | Mode | Read by | Written by | Notes |
|---|---|---|---|---|---|
| `/etc/weewx-clearskies/` (dir) | `clearskies:clearskies` | 0750 | API, Config UI | Config UI | Directory root. Caddy reads specific files via group or world-read on those files. |
| `api.conf` | `clearskies:clearskies` | 0640 | API, Config UI | Config UI (wizard apply) | API config. No secrets (secret-leak guard enforced). |
| `charts.conf` | `clearskies:clearskies` | 0640 | API | Config UI, migration tool | Chart configuration. |
| `stack.conf` | `clearskies:clearskies` | 0640 | Config UI | Config UI | Wizard/UI state. |
| `secrets.env` | `clearskies:clearskies` | 0600 | API (via `EnvironmentFile=`), Config UI | Config UI (wizard apply) | **Most restricted file.** DB passwords, API keys, proxy secret. Mode 0600 = owner-only. Caddy never reads this. |
| `branding.json` | `clearskies:clearskies` | 0644 | Caddy (serves to browser), API | Config UI (wizard apply) | World-readable because Caddy serves it. No secrets in this file. |
| `webcam.json` | `clearskies:clearskies` | 0644 | Caddy (serves to browser) | Config UI (wizard apply) | World-readable. No secrets. |
| `api-cert.pem` | `clearskies:clearskies` | 0644 | Caddy (for upstream TLS verification) | API (auto-generated on first start) | API's self-signed TLS cert for internal Caddy→API trust. |
| `api-key.pem` | `clearskies:clearskies` | 0600 | API only | API (auto-generated) | API's TLS private key. Owner-read only. |
| `ui-cert.pem` | `clearskies:clearskies` | 0644 | Config UI | Config UI (auto-generated) | Config UI's self-signed cert. |
| `ui-key.pem` | `clearskies:clearskies` | 0600 | Config UI only | Config UI (auto-generated) | Config UI's TLS private key. |

#### Web root and static assets

| Path | Owner | Mode | Read by | Written by | Notes |
|---|---|---|---|---|---|
| `/var/www/clearskies/` (dir) | `caddy:caddy` | 0755 | Caddy | Deploy script (rsync as deploy user, then chown) | Dashboard SPA. Wiped by `rsync --delete` on every deploy. |
| `/var/www/clearskies/*` (files) | `caddy:caddy` | 0644 | Caddy, browsers | Deploy script | Static HTML/CSS/JS. World-readable (served to browsers). |
| `/var/www/clearskies/webcam/` | read-only mount | — | Caddy | External capture process (on weewx host) | LXD/bind mount. Read-only inside the container. Never written by Clear Skies. |

#### Runtime directories

| Path | Owner | Mode | Read by | Written by | Notes |
|---|---|---|---|---|---|
| `/var/run/weewx-clearskies/` | `clearskies:weewx` | 0770 | API | weewx extension (creates Unix socket) | Group `weewx` with group-write so the weewx extension can create the socket file. API reads from the socket. |
| `/var/run/weewx-clearskies/loop.sock` | `weewx:weewx` | 0660 | API (connects as client) | weewx extension (socket server) | Created by the weewx extension at weewx startup. API connects as a client. |
| `/tmp` (in container) | — | tmpfs | API | API | Mounted as tmpfs in Docker. Systemd `PrivateTmp=yes` on bare-metal. |

#### Caddy-specific files

| Path | Owner | Mode | Read by | Written by | Notes |
|---|---|---|---|---|---|
| Caddyfile | `caddy:caddy` | 0644 | Caddy | Deploy/install script, wizard (TLS config) | Generated by wizard TLS step (T5B.6). |
| ACME cert storage | `caddy:caddy` | 0700 | Caddy | Caddy (auto-renewal) | Caddy's internal cert storage (`.caddy/` or `/data/caddy/`). Never accessed by other processes. |

#### weewx files (Clear Skies reads, never writes)

| Path | Access by `clearskies` | How | Notes |
|---|---|---|---|
| weewx DB (SQLite `.sdb`) | Read-only | `clearskies` in `weewx-ro` group; file group-readable | Separate read-only group, NOT the `weewx` group. `weewx-ro` has read-only access to the DB file. |
| weewx DB (MariaDB) | Read-only | `SELECT`-only grants on weewx database | `GRANT SELECT ON weewx.* TO 'clearskies'@'localhost'` |
| `weewx.conf` | Read-only | World-readable (0644) or `clearskies` in read group | Parsed as ConfigObj for station metadata. |
| weewx Python packages | Read-only | `sys.path` addition via `.pth` file (ADR-056) | Only `weewx.units` imported. Packages are world-readable by default. |

### Docker container model

Each container enforces its own privilege boundary:

| Container | User | Read-only FS | Capabilities | Volumes |
|---|---|---|---|---|
| `api` | `clearskies` (explicit UID) | Yes | None (`cap_drop: ALL`) | `/etc/weewx-clearskies` (rw), weewx DB (ro), `/var/run/weewx-clearskies` (rw), `/tmp` (tmpfs) |
| `caddy` | `caddy` (image default) | Yes | None | Caddyfile (ro), web root (ro), ACME storage (rw), `/etc/weewx-clearskies/branding.json` (ro), `/etc/weewx-clearskies/webcam.json` (ro) |
| `dashboard` (init) | non-root | — (exits after build) | None | Web root volume (write `dist/` then exit) |
| `redis` | `redis` (image default) | Yes | None | Redis data dir (rw) |
| `config` | `clearskies` (same UID as API) | Yes | None | `/etc/weewx-clearskies` (rw), `/tmp` (tmpfs) |

All containers: `security_opt: [no-new-privileges:true]`, no host network, no privileged mode.

**Inter-container volume sharing:** The web root volume is written by the dashboard init container and read by Caddy. The config directory is shared between the API and Config UI containers (same `clearskies` UID). No other volumes are shared between containers.

### Bare-metal install script

```
# Create service user and groups
useradd --system --no-create-home --shell /usr/sbin/nologin clearskies
groupadd --system weewx-ro

# Add clearskies to the read-only DB group and the weewx group (socket access)
usermod -aG weewx-ro clearskies
usermod -aG weewx clearskies

# Create config directory
mkdir -p /etc/weewx-clearskies
chown clearskies:clearskies /etc/weewx-clearskies
chmod 750 /etc/weewx-clearskies

# Create runtime directory for Unix socket
mkdir -p /var/run/weewx-clearskies
chown clearskies:weewx /var/run/weewx-clearskies
chmod 770 /var/run/weewx-clearskies

# Set weewx DB file readable by weewx-ro group (SQLite only)
chgrp weewx-ro /var/lib/weewx/weewx.sdb
chmod g+r /var/lib/weewx/weewx.sdb

# Web root owned by caddy
mkdir -p /var/www/clearskies
chown caddy:caddy /var/www/clearskies
chmod 755 /var/www/clearskies
```

### What `ubuntu` is used for (deploy-time only)

On bare-metal, `ubuntu` (or any deploy user with sudo) handles:
- `git pull` on repos
- `npm run build` for the dashboard
- `rsync dist/ → /var/www/clearskies/` (then `chown caddy:caddy`)
- `systemctl restart` (via sudo)
- Running the install script itself

`ubuntu` is never the runtime user for any service. In Docker, deploy operations don't exist — the image build process handles everything.

## Consequences

- **Install script required:** User creation, group setup, directory permissions, DB grants. Documented in `INSTALL.md` with copy-paste commands for SQLite and MariaDB.
- **`weewx-ro` group:** New group for read-only weewx DB access. Separate from `weewx` so DB read access is independent of socket write access.
- **`weewx` group membership for `clearskies`:** Required for the API to connect to the loop relay Unix socket (`weewx:weewx` 0660). This is read access only — `clearskies` connects as a client, not as the socket server.
- **Web root ownership change:** Currently `ubuntu:ubuntu`, moves to `caddy:caddy`. Deploy script must `chown` after rsync.
- **Config file migration:** All files in `/etc/weewx-clearskies/` change from `ubuntu:ubuntu` to `clearskies:clearskies`. One-time migration during Phase 5.
- **`charts.conf` root ownership fix:** T0.6 found `charts.conf` owned by `root:root` — must be corrected to `clearskies:clearskies`.
- **Rules enforcement:** `rules/coding.md` gains: never write outside `/etc/weewx-clearskies/` or `/tmp`, never chmod/chown at runtime, never run as root, never add sudo.
- **Deploy scripts need updating:** `scripts/redeploy-weather-dev.sh` and `scripts/sync-to-weather-dev.sh` currently run everything as `ubuntu`. They need to: rsync as the deploy user then `chown caddy:caddy` the web root, restart services that now run as `clearskies`, handle the `weewx-ro` group for DB access. The deploy scripts are the bridge between the `ubuntu` deploy world and the `clearskies` runtime world.
- **Test environment migration:** weather-dev currently has all files owned by `ubuntu`. Transitioning to the new permission model requires a one-time migration: create users/groups, chown all config and runtime directories, update systemd units, verify services start under the new users. Tests that assume `ubuntu` ownership (SSH commands running as `ubuntu` to read config, restart services) need updating to use `sudo` or the correct service user.

## Acceptance criteria

- [ ] `clearskies` system user exists, no login shell, no sudo (`id clearskies`, `getent passwd clearskies`)
- [ ] `weewx-ro` group exists, `clearskies` is a member
- [ ] `clearskies` is a member of `weewx` group (socket access)
- [ ] API runs as `clearskies` (`ps aux` shows correct user)
- [ ] `/etc/weewx-clearskies/` ownership and modes match the table above (verified with `ls -la`)
- [ ] `secrets.env` is mode 0600, owner `clearskies` (verified: `stat`)
- [ ] `clearskies` cannot write to weewx DB (verified: write attempt rejected)
- [ ] `clearskies` cannot read `/etc/shadow` (verified: access denied)
- [ ] `caddy` cannot read `secrets.env` (verified: access denied)
- [ ] Web root owned by `caddy:caddy` (verified: `ls -la /var/www/clearskies/`)
- [ ] Docker containers run non-root (`docker exec <container> whoami`)
- [ ] Docker root filesystems are read-only (write outside volumes fails)
- [ ] Wizard apply works as `clearskies` (config writes succeed)
- [ ] Loop packet socket accessible: weewx writes, API reads (verified end-to-end)
- [ ] `charts.conf` ownership corrected from `root:root` to `clearskies:clearskies`
- [ ] No runtime process runs as `ubuntu` (verified: `ps aux | grep ubuntu` shows no Clear Skies processes)

## Implementation guidance

Phase 5 tasks:
- T5B.1: Create `clearskies` user + `weewx-ro` group, update systemd units
- T5B.2: Set all directory/file permissions per tables above, fix `charts.conf` ownership
- T5B.3: Configure weewx DB read-only access (`weewx-ro` group for SQLite, SELECT grants for MariaDB)
- T5B.4: Systemd hardening flags (16 flags per ADR-060)
- T5B.5: Docker hardening (per container model table above)

## Out of scope

- weewx's own user/group model (unchanged — we adapt to it)
- SELinux / AppArmor policies (operator infrastructure choice)
- Deploy user restrictions (operator decides their deploy workflow)
- Redis authentication (loopback-only, no auth — per current architecture)

## References

- Related: [ADR-012](ADR-012-database-access-pattern.md) (read-only DB), [ADR-027](ADR-027-config-and-setup-wizard.md) (config files), [ADR-056](ADR-056-api-weewx-co-location.md) (co-location), [ADR-060](ADR-060-security-model-threat-boundaries.md) (security model)
- Research: T0.6 findings (deployment state — current `ubuntu` ownership, `charts.conf` root-owned)
- Backlog: FIX-011
