---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-027: Configuration format, secret handling, and configuration UI

## Context

Three runtime services (`weewx-clearskies-api`, `weewx-clearskies-realtime`, `weewx-clearskies-stack`) need configuration: bind addresses/ports, DB connection, log destinations, CORS, rate limits, forecast-provider credentials per [ADR-006](ADR-006-compliance-model.md), and the optional cross-host shared secret per [ADR-008](ADR-008-auth-model.md) and [ADR-037](ADR-037-inbound-traffic-architecture.md).

Locked constraints: secrets never in committed config files; GUI preferred over manual editing for end users (target audience = weather hobbyists, not network engineers); manual config-file editing remains available for power users; no admin UI baked into the dashboard; modern home networks include IPv6-only setups with GUAs and may span multiple VLANs (a bind-range filter would refuse legitimate setups); power users can disable the UI entirely.

## Options considered

### Sub-decision 1 — Config format
| Option | Verdict |
|---|---|
| A. ConfigObj/INI (`.conf`) | **Selected.** Matches `weewx.conf`; ConfigObj is already a transitive weewx dep; native comment preservation supports the managed-region pattern; `validate` companion library mirrors weewx. |
| B. TOML | Rejected — diverges from weewx convention; comment preservation library-dependent. |
| C. YAML | Rejected — whitespace-sensitive; hostile to managed-region pattern. |
| D. Multiple formats | Rejected — round-trip needs one canonical form. |

### Sub-decision 2 — Config location
| Option | Verdict |
|---|---|
| A. `/etc/weewx-clearskies/<component>.conf` (matches `/etc/weewx/`) | **Selected**, with XDG fallback and env-var override. |
| B. XDG only | Rejected — diverges from weewx convention. |
| C. Both with precedence | Subsumed into A's search order. |

### Sub-decision 3 — Secret mechanics
| Option | Verdict |
|---|---|
| A. Single env file mode `0600`, loaded by systemd `EnvironmentFile=` and docker-compose `env_file:` | **Selected.** |
| B. Systemd unit drop-in | Rejected — splits design between systemd and Docker. |
| C. Inline in main config | Rejected — violates the no-secrets-in-config baseline. |
| D. External secrets manager | Rejected — overkill for home stations. |

### Sub-decision 4 — Configuration UI lifecycle, binding, auth
| Option | Verdict |
|---|---|
| A. CLI only | Rejected — not a GUI. |
| B. One-shot first-run wizard, dies on success | Rejected — forces manual editing for ongoing changes. |
| C. On-demand standalone UI with bind-range filter (loopback + RFC1918 + RFC4193 + link-local) and one-time token auth | Rejected — refuses to bind on IPv6 GUAs; breaks legitimate IPv6-only / multi-VLAN setups. |
| D. On-demand standalone UI in `weewx-clearskies-stack`, no bind filter, friendly defaults, admin-credential auth, TLS by default (self-signed), disable-able | **Selected.** |
| E. Admin UI in the dashboard | Rejected — conflates public read-only surface with privileged config. |
| F. Separate `weewx-clearskies-config` repo | Rejected — extra repo. |

### Sub-decision 5 — Re-run / ongoing edits
| Option | Verdict |
|---|---|
| A. UI is first-launch only | Rejected — contradicts on-demand-UI choice. |
| B. UI re-runnable as non-destructive update tool; managed-region marker delimits UI-owned config | **Selected.** |
| C. Long-lived daemon admin surface | Rejected — deferred. |

## Decision

The five sub-decisions resolve to:

### 1. Format: ConfigObj/INI

`.conf` extension. Read/written via `configobj`. Validation via `validate`. Section syntax `[section]`, nested `[[subsection]]` per weewx convention.

### 2. Location: `/etc/weewx-clearskies/`

Search order:
1. `WEEWX_CLEARSKIES_CONFIG_DIR` env var (if set).
2. `/etc/weewx-clearskies/<component>.conf`.
3. `$XDG_CONFIG_HOME/weewx-clearskies/<component>.conf` (defaults to `~/.config/weewx-clearskies/`).

First match wins. Service refuses to start with no config and no `--init`.

### 3. Secrets: single env file

`/etc/weewx-clearskies/secrets.env`, mode `0600`, owner = service user. systemd `EnvironmentFile=`, docker-compose `env_file:`. Configuration UI creates it; manual edits supported.

**Service start-up secret-leak guard:** API and realtime walk the parsed `.conf`; if any leaf key matches `(?i)_(KEY|SECRET|TOKEN|PASSWORD)$`, log FATAL and exit non-zero. Pasting an API key or password hash into a `.conf` is a startup error, not a silent leak.

Naming: `WEEWX_CLEARSKIES_<DOMAIN>_<FIELD>` and `WEEWX_CLEARSKIES_<DOMAIN>_<PROVIDER>_<FIELD>`.

### 4. Configuration UI: on-demand standalone in `weewx-clearskies-stack`

Single tool, two front-doors: **guided flow** when no config exists; **direct-edit** when config exists. Same tool first install + later changes. Not a daemon — operator launches `weewx-clearskies-config`, uses it, exits.

**Network binding:**
- **Default bind: dual-stack loopback** (`127.0.0.1` + `::1` simultaneously). Out-of-the-box flow needs no flags.
- `--bind <addr>` accepts any address. **No range filter.** Operator's network, operator's responsibility.
- **Startup banner** shows the bound URL and cert fingerprint. If the bound address is not loopback / RFC1918 / RFC4193 / link-local, banner appends a friendly informational note about firewall responsibility — but proceeds. Note exists to catch fat-finger accidents (`--bind 0.0.0.0`), not to gate legitimate IPv6-GUA / multi-VLAN setups.
- Hostname binds resolve via `socket.getaddrinfo` and bind the full address-family set per [coding rules §1](../../rules/coding.md).
- Headless servers: `--bind <lan-or-gua-address>`, access printed URL from a laptop browser. SSH-tunneling from loopback documented as alternative.

**Transport (TLS):**
- **HTTPS always**, regardless of bind address — uniform, no mode-switch.
- **Self-signed cert by default**, auto-generated at first launch, stored at `/etc/weewx-clearskies/ui-cert.pem` (mode 0644) + `ui-key.pem` (mode 0600). SAN includes bound address(es) + `localhost`. 365-day validity. Auto-regenerated on expiry or when bound address set changes.
- **Cert SHA-256 fingerprint printed in startup banner** and shown in the bootstrap setup page header. Operator verifies against the browser's cert dialog. Trust-on-first-use, same pattern as SSH host keys.
- **Operator-supplied cert override:** `[ui] tls_cert_path` and `[ui] tls_key_path` in `stack.conf`. When set, the tool skips self-signed generation. Path for mkcert / internal CA / LE certs.
- **No bundled Let's Encrypt / CA infrastructure.** UI is a local admin tool; LE needs public reachability, wrong scope.

**Authentication:**
- **Admin username + password.** Stored as Argon2id hash in `secrets.env` — `WEEWX_CLEARSKIES_ADMIN_USERNAME` and `WEEWX_CLEARSKIES_ADMIN_PASSWORD_HASH`.
- **First-launch bootstrap:** when no admin hash exists, tool prints a one-time URL with a 32-byte hex token. First action in the UI is set username + password. Token invalidated on use. Bootstrap traffic is over TLS.
- **Subsequent launches:** standard login form. Constant-time hash compare.
- **Session:** HTTP-only, SameSite=Strict, Secure cookie scoped to bound origin; expires on process exit (no on-disk session store).
- **Rate limiting:** 5 failed logins per IP per minute, then 60 s throttle. No permanent lockout (DoS avoidance).
- **Recovery:** `--reset-admin-password` clears the hash; next launch is bootstrap mode.

**Disable-UI option:** `[ui] enabled = false` in `stack.conf`. Tool refuses to launch the web UI; only `--cli` and direct `.conf` editing work. Not a security mode (binary still ships) — it's for power users who don't want the UI on disk at runtime.

**Lifecycle:** stays running until operator exits (Ctrl-C, signal, or "exit" button). Does NOT auto-die on first save — supports edit/save/re-edit workflow.

### 5. Re-run: non-destructive merge

Generated `.conf` files carry `# MANAGED REGION BEGIN` / `# MANAGED REGION END` marker comments delimiting the UI-managed region. The UI reads existing config via ConfigObj (which preserves comments and key order on round-trip), updates only the managed region, re-emits without touching free-form regions beneath. `--reset` overwrites everything.

## Consequences

- **One canonical format** matching weewx — minimal docs friction.
- **One canonical secret-file mechanism** uniform across native and Docker.
- **GUI requirement met across the entire lifecycle** without a long-lived admin daemon.
- **Power users** can disable the UI entirely or edit `.conf` directly; the managed-region marker tells them which sections are safe to extend.
- **The shared-secret distribution problem from [ADR-008](ADR-008-auth-model.md)** gets a concrete owner: UI generates the secret, writes to the local host's `secrets.env`, prints for cross-host copy. `--show-secrets` re-prints; `--headless --proxy-secret <value>` populates the second host.
- **Headless-server use case** is first-class.
- **Modern IPv6-only / multi-VLAN networks** supported — no bind-range filter to fight.

### Trade-offs accepted
- **Admin password is the security boundary.** Mitigated: Argon2id hashing, login rate-limiting, banner reminds operator firewall control is theirs, password form enforces minimum length with strength feedback (no required mixed-class rules — produce predictable patterns and worsen UX).
- **Self-signed cert produces browser warning on first connection.** Mitigated: fingerprint printed in banner + bootstrap page header for verification; per-browser click-through documented in `INSTALL.md` and `SECURITY.md`; operator-supplied cert override and "install cert as trusted in your OS/browser store" both documented as no-warning alternatives. Same pattern as Cockpit / Synology DSM / Proxmox / Jupyter.
- **Re-run merge depends on ConfigObj's round-trip comment preservation.** Tests cover round-trip on representative + manually-extended configs. configobj is already a transitive weewx dep — no new lock-in.
- **Cross-host secret distribution is manual copy.** Documented; not silent.
- **Secret-leak guard regex catches the common mistake, not adversarial misuse.** A user inventing `apikey` (no separator) bypasses it. Acceptable — UI never produces such names; `CONFIG.md` documents that secrets belong in `secrets.env`.

### Repos affected
- **api / realtime:** load ConfigObj `.conf` from search order; load secrets from env; secret-leak guard at startup; bind per `[server]`.
- **dashboard:** unaffected at runtime — gets display config from API JSON endpoint.
- **stack:** grows from "docs + compose" to "docs + compose + configuration UI." Ships `weewx-clearskies-config` entry point; bundled compose adds a `config` service. INSTALL.md covers per-browser first-connection click-through + fingerprint verification + no-warning alternatives. SECURITY.md covers threat model.

## Implementation guidance

### File layout

```
/etc/weewx-clearskies/
├── api.conf              # api config, no secrets
├── realtime.conf         # realtime config, no secrets
├── stack.conf            # stack + [ui] config
├── secrets.env           # mode 0600, owner = service user
├── ui-cert.pem           # self-signed cert (mode 0644)
├── ui-key.pem            # private key (mode 0600)
└── bootstrap-summary.md  # written by UI; records what was generated, what to copy cross-host
```

### Config file shape (managed-region marker)

```
# Managed by weewx-clearskies-config on YYYY-MM-DD.
# MANAGED REGION BEGIN
# Re-running the configuration UI preserves any content below MANAGED REGION END.

[server]
bind_host = 127.0.0.1
bind_port = 8765

[database]
kind = sqlite
path = /var/lib/weewx/weewx.sdb

[forecast]
provider = openmeteo

# MANAGED REGION END
# Free-form region below — the configuration UI does not touch this.
```

A companion `<component>.conf.spec` defines types and defaults for `validate`, mirroring weewx's pattern. Provider credentials referenced by `[forecast].provider` come from `secrets.env`.

### CLI surface

```
weewx-clearskies-config                       # default: web UI on dual-stack loopback
weewx-clearskies-config --bind <addr>         # bind any address; banner notes if not local/private
weewx-clearskies-config --port <n>            # default 9876
weewx-clearskies-config --cli                 # interactive terminal flow (works with [ui] enabled = false)
weewx-clearskies-config --reset               # overwrite existing config (confirms)
weewx-clearskies-config --reset-admin-password # clears admin hash; next launch = bootstrap
weewx-clearskies-config --show-secrets        # re-prints current secrets for cross-host copy
weewx-clearskies-config --headless            # non-interactive flags-only mode
```

### Configuration UI collected fields

DB type + connection (auto-detected from `weewx.conf` when present); forecast provider + credentials per [ADR-007](ADR-007-forecast-providers.md); bind addresses for api/realtime; reverse-proxy topology (same-host default vs. cross-host with generated `WEEWX_CLEARSKIES_PROXY_SECRET` per [ADR-008](ADR-008-auth-model.md)); TLS hostname for the docker-compose Caddy path; logging destination; UI's own bind/port + TLS paths + `[ui] enabled` flag (latter not flippable from the UI — would lock the operator out).

NOT collected: theme/branding ([ADR-022](ADR-022-theming-branding-mechanism.md)), i18n locale ([ADR-021](ADR-021-i18n-strategy.md)), end-user accounts (none — see [ADR-008](ADR-008-auth-model.md)).

## Out of scope
- Dashboard runtime config (theme, palette, station-name display) — served by API ([ADR-022](ADR-022-theming-branding-mechanism.md)).
- Long-lived daemon admin UI — deferred.
- End-user accounts (multi-user roles, ACLs) — single admin credential at v0.1.

## References
- Related: [ADR-001](ADR-001-component-breakdown.md), [ADR-002](ADR-002-tech-stack.md), [ADR-006](ADR-006-compliance-model.md), [ADR-007](ADR-007-forecast-providers.md), [ADR-008](ADR-008-auth-model.md), [ADR-021](ADR-021-i18n-strategy.md), [ADR-022](ADR-022-theming-branding-mechanism.md), [ADR-029](ADR-029-logging-format-destinations.md), [ADR-030](ADR-030-health-check-readiness-probes.md), [ADR-037](ADR-037-inbound-traffic-architecture.md).
- Coding rules: [coding.md §1](../../rules/coding.md) (IPv4/IPv6-agnostic listener).
