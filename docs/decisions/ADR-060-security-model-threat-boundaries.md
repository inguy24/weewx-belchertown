---
status: Accepted
date: 2026-06-13
deciders: shane
supersedes:
superseded-by:
---

# ADR-060: Security model and threat boundaries for the co-located API

## Context

ADR-056 through ADR-058 place the Clear Skies API on the weewx host with Python-level import access and absorb the realtime service. This consolidation is architecturally sound but raises the security stakes: the API is an HTTP service accessible on the operator's local network, running on a machine with direct access to the weewx database, weewx Python internals, station hardware (via weewx), and operator credentials for external providers. The API is NOT internet-facing — it binds to loopback by default (ADR-037), and the reverse proxy (Caddy) on the front-end host is the only internet-facing component. We neither recommend nor support exposing the API directly to the internet.

Phase 0 research (T0.5) verified that 9 existing security controls pass (rate limiting, ProxyAuth with constant-time compare, body size limit, security headers, mandatory TLS, read-only DB probe, input validation with `extra="forbid"`, logging redaction, same-origin CORS). However, it also found:
- Zero systemd hardening flags on the API service unit
- Service runs as `ubuntu` (general-purpose user, sudo group member) rather than a dedicated restricted user
- pip-audit not installed on the production host
- Redis rate-limit backend not implemented (in-process only)

The existing security baseline (`docs/contracts/security-baseline.md`) documents per-component controls but does not establish a threat model or trust boundary diagram for the co-located architecture.

## Options considered

| Option | Verdict |
|---|---|
| A. Formal threat model with trust boundaries and mandatory mitigations | **Selected.** Co-location demands explicit security reasoning. |
| B. Continue with the existing per-control checklist only | Rejected — checklist lacks threat model context; controls without a threat model are arbitrary. |

## Decision

The API is a gateway to data, not a door into the host. A vulnerability in the API must not give an attacker filesystem access, weewx modification capability, or lateral movement.

### Trust boundaries

```
Internet
  → Caddy on front-end host (TLS termination, security headers, rate limiting, path filtering)
    → [LAN]
      → API on weewx host (loopback or LAN bind, auth, input validation, query limits, read-only DB)
        → weewx (read-only metadata import only — never engine/drivers)
        → weewx DB (SELECT only — write probe enforced)
        → External providers (outbound HTTPS, keys held server-side)
```

The API is never directly internet-accessible. Caddy is the only internet-facing component. The API binds to loopback by default; cross-host deployments use LAN bind with proxy shared secret (ADR-008). Each layer enforces its own constraints — defense in depth.

### Per-component security model

This ADR establishes the threat model (why). The security baseline (`docs/contracts/security-baseline.md`) is the control checklist (what). Phase 5 is the implementation (how). The baseline needs updating post-merge: §4 (realtime) folds into §3 (API), and new SSE-specific controls are added.

**Caddy (front-end host — the only internet-facing component):**
- TLS termination (auto Let's Encrypt in compose, operator cert in native install)
- Security headers: HSTS, CSP, X-Frame-Options: DENY, X-Content-Type-Options: nosniff, Referrer-Policy, Server header suppressed
- Path filtering: only intended routes proxied (`/api/v1/*`, `/sse`, `/wizard*`, `/admin*`, `/login*`, static SPA). No wildcard proxy to backend.
- Request size limits enforced before requests reach the API
- Admin endpoints (`/wizard*`, `/admin*`, `/login*`) blocked at proxy level for internet-facing deployments (defense in depth — both Caddy and config UI enforce auth)
- SSE: correct buffering/timeout config for long-lived connections

**API (weewx host — LAN-accessible, loopback by default):**
- Rate limiting: 60/min per IP, bypass when proxy-trusted (security baseline §3.1)
- ProxyAuth: constant-time HMAC shared secret for cross-host proxy trust (ADR-008)
- Input validation: Pydantic `extra="forbid"` on all endpoints with `Depends()` wiring (§3.5)
- Body size limit: 1 MiB default (§3.1)
- Read-only DB: SQLAlchemy parameterized queries + startup write probe (ADR-012, §3.3)
- Secrets: `secrets.env` mode 0600, env-var injection, secret-leak guard on `.conf` files (ADR-027, §3.4)
- Logging: JSON to stdout, redaction filter strips auth headers/keys/SQL params (ADR-029, §3.6)
- Health: separate loopback port 8081, unauthenticated (§3.7)
- Error responses: RFC 9457, no stack traces or internal paths (§3.6)
- TLS: mandatory, Ed25519 self-signed default (§3.1)
- SSE (new post-merge): connection limits per IP, backpressure on slow consumers, idle timeout

**Config UI (front-end host — wizard + admin):**
- Admin username/password with Argon2id hash (ADR-027)
- Login rate limiting: 5 failed/min per IP
- Session: HTTP-only SameSite=Strict cookie, Secure flag when TLS active
- Bootstrap one-time token for initial setup

**Dashboard (static SPA — no server runtime):**
- No secrets in built bundle
- No `eval`/`innerHTML` with untrusted data
- `react-markdown` with sanitizers for user content
- CSP set by Caddy

**Inter-component communication:**
- Caddy → API: HTTPS (API's self-signed cert), proxy shared secret in `X-Clearskies-Proxy-Auth` header for cross-host deployments
- Caddy → Config UI: HTTP on Docker network or localhost
- API → Redis: loopback only, no auth (Redis bound to 127.0.0.1)
- API → External providers: outbound HTTPS, operator keys held server-side (never in browser)
- API → weewx DB: read-only connection (SELECT grants + write probe)
- API → weewx Python: `import weewx.units` only (ADR-056)

### Shared responsibility model

Security is split between what Clear Skies provides and what the operator must handle. This delineation must be documented in each repo's `SECURITY.md` and the stack repo's `INSTALL.md`.

**Clear Skies provides (our responsibility):**
- Application-level security: input validation, parameterized SQL, output escaping, secret-leak guards
- Process hardening: systemd flags, Docker cap_drop/read-only/non-root, dedicated service user
- Transport security: mandatory TLS on API, proxy shared secret for cross-host trust
- Container security: non-root USER, read-only root FS, no capabilities, explicit volume mounts only
- Port binding defaults: API binds loopback, health on loopback, Redis on loopback. Only Caddy binds 0.0.0.0 (ports 80/443).
- Docker network isolation: services communicate over internal Docker networks, not the host network. Only Caddy publishes ports to the host.
- Dependency auditing: pip-audit and npm audit in CI, pinned versions, lockfiles
- Secrets management: `secrets.env` mode 0600, env-var injection, no secrets in source or config files

**Operator responsibility (documented in INSTALL.md / SECURITY.md):**
- **Network/firewall:** Container host firewall (e.g., `ufw`, `iptables`, `nftables`), LAN segmentation (VLANs), restricting which hosts can reach service ports. We document which ports are exposed and why — the operator decides who can reach them. On the weewx host specifically, the firewall must allow the API to reach co-located services: weewx's MariaDB (port 3306 on localhost or container IP for DB queries), Redis (port 6379 on localhost for caching), and the Unix domain socket for loop packet delivery. In cross-host deployments, the front-end host's Caddy must be able to reach the weewx host's API (port 8765) — the operator's firewall between the two hosts must permit this. We document the required connectivity; the operator configures the rules.
- **TLS certificates:** Handled by the wizard (see TLS strategy below). API's self-signed cert is for internal Caddy→API trust only — browsers never see it.
- **DNS and domain security:** DNSSEC, CAA records, domain registration — operator's infrastructure.
- **OS-level hardening:** Container OS updates, kernel patches, SSH hardening, user management on the host. We harden our service processes; the operator hardens the host.
- **Backup and recovery:** Database backups, config backups, disaster recovery planning.
- **Monitoring and alerting:** Log aggregation, intrusion detection (IDS/IPS), uptime monitoring. We emit structured JSON logs; the operator decides where they go.
- **Physical security:** Physical access to the server running weewx and Clear Skies.
- **Upstream provider accounts:** API key rotation, account security, billing management for Aeris/OWM/IQAir/OpenMeteo.
- **End-user authentication:** If the operator wants password-protected access to the weather site, they add it at the proxy layer (Apache basic-auth, Authelia, Cloudflare Access). We don't provide end-user auth (ADR-008).

### Docker service and port protection

In the compose deployment, services are isolated by Docker networking:

| Service | Port | Binding | Accessible from |
|---|---|---|---|
| Caddy | 80, 443 | `0.0.0.0` (host-published) | Internet / LAN — **the only externally reachable service** |
| API | 8765 | Docker internal network or loopback | Caddy only (via Docker network name `api:8765`) |
| API health | 8081 | `127.0.0.1` inside container | Container-local only (probes) |
| Redis | 6379 | `127.0.0.1` | Container-local only |
| Config UI | 9876 | Docker internal network | Caddy only (via Docker network name `config:9876`) |

**No service except Caddy publishes ports to the host.** The API, Redis, and Config UI are reachable only through Docker's internal network — they are invisible to the LAN and internet. An operator would have to explicitly add `ports:` directives to expose them, which we document against.

**Docker networking considerations:**
- **Same-host compose:** All containers on the same Docker bridge network communicate by service name (e.g., `api:8765`, `redis:6379`). No host firewall rules needed for inter-container traffic — Docker's internal networking handles it.
- **Cross-host compose (two-host split):** The API container on the weewx host publishes port 8765 to the host so Caddy on the front-end host can reach it. The operator's network firewall between the two hosts must permit this traffic.
- **Docker bypasses host firewall:** On many Linux distributions, Docker's port publishing (`ports:` directive) uses iptables DNAT rules that bypass `ufw` and user-defined iptables chains. An operator who relies on `ufw deny` to protect ports may find Docker-published ports are still reachable from the network. This is a well-known Docker behavior — operators must either use Docker's own IP restriction (`ports: "127.0.0.1:8765:8765"` to bind loopback) or configure `DOCKER_IPTABLES=false` and manage rules manually. Our compose files use loopback binding on all ports except Caddy's 80/443 to mitigate this by default.
- **Container-to-host services:** If weewx's MariaDB runs on the host (not in Docker), the API container needs `host.docker.internal` or the host's Docker bridge IP to reach it. If MariaDB runs in its own container on the same compose stack, containers communicate by service name directly.

**Documentation requirement:** `INSTALL.md` must include a "Security considerations" section that:
1. Lists every port Clear Skies binds and why
2. States which ports should never be exposed to the internet
3. Recommends host firewall rules for native installs
4. Recommends against adding `ports:` directives to Docker services other than Caddy
5. Documents the required local connectivity on the weewx host: API → MariaDB (3306), API → Redis (6379), weewx extension → API (Unix socket at `/var/run/weewx-clearskies/loop.sock`)
6. Documents the required cross-host connectivity: front-end Caddy → weewx host API (8765/tcp)
7. Provides example firewall rules (ufw, iptables) for both same-host and cross-host topologies
8. Points to the operator responsibilities listed above

### Browser-facing TLS strategy

**No self-signed certificates for the browser-facing side.** Self-signed certs produce browser warnings that confuse operators and generate support burden. Caddy's internal self-signed cert for API communication (Caddy→API on port 8765) is fine — browsers never see it.

The wizard collects TLS configuration and generates the Caddyfile accordingly. Three supported paths:

| Path | When to use | Wizard collects | Caddy config generated |
|---|---|---|---|
| **ACME / Let's Encrypt (HTTP-01)** | Server is publicly reachable on ports 80/443 | Domain name, email for LE account | `tls {email}` — Caddy auto-issues and auto-renews |
| **DNS-01 challenge** | Server behind NAT, operator has a domain + DNS provider API access | Domain name, DNS provider (Cloudflare, Route53, etc.), provider API credentials | `tls { dns {provider} {credentials} }` — requires `caddy-dns/{provider}` image variant |
| **Behind existing reverse proxy** | Operator already has TLS termination (NPM, Traefik, HAProxy, etc.) | Confirmation that external proxy handles TLS | Caddy listens HTTP-only, no TLS config |

**No manual cert upload path.** With cert lifetimes moving to 47 days, manual renewal becomes impractical. ACME (HTTP-01 or DNS-01) handles renewal automatically. Operators who cannot use any of the three paths above must configure TLS outside the wizard.

**DNS-01 provider support:** Stock `caddy:2-alpine` does not include DNS provider plugins. For DNS-01, the compose stack uses a provider-specific Caddy image (e.g., `caddy-dns/cloudflare`). The wizard's DNS provider selection determines which image to reference. Common providers to support: Cloudflare, Route53, Google Cloud DNS, DigitalOcean, Namecheap.

### Attack surfaces and mandatory mitigations

| Surface | Threat | Mitigation | Status (T0.5) |
|---|---|---|---|
| Input validation / injection | SQL injection, path traversal, command injection | Parameterized SQL (SQLAlchemy), Pydantic `extra="forbid"`, file path allowlist | Passing |
| Authentication boundaries | Unauthorized access to admin/config endpoints | ProxyAuth HMAC for proxy trust, wizard session auth, setup token. Public data endpoints unauthenticated by design (ADR-008). | Passing |
| Process isolation | API compromise → host compromise | Dedicated `clearskies` user, systemd hardening (16 flags), Docker cap_drop ALL, read-only root FS | **Gap: no hardening** |
| Network exposure | Direct access bypassing proxy | API binds loopback by default (ADR-037), loud warning on non-loopback without proxy secret | Passing |
| Dependency supply chain | Vulnerable transitive dependency | pip-audit in CI, npm audit, pinned versions, lockfiles | **Gap: pip-audit not on host** |
| Data exposure | Sensitive data in responses or logs | Logging redaction filter, no stack traces in user-facing errors (RFC 9457), health on loopback port | Passing |
| DoS | Resource exhaustion via expensive queries or SSE flooding | Rate limiting (60/min), body size limit (1 MiB), query timeout, SSE connection limit, SSE backpressure | Partially passing (SSE limits pending Phase 3) |
| weewx-specific | API modifies weewx config, restarts weewx, imports engine modules | Only `weewx.units` imported (ADR-056), read-only DB (ADR-012), no subprocess calls, no weewx.conf writes | Passing (enforced by code review + rules) |
| Caddy misconfiguration | Proxy exposes unintended paths, missing security headers, weak TLS | Phase 5 Caddy audit (T5A.5), TLS 1.2+ minimum, HSTS, CSP, path allowlist | **Pending audit** |
| Inter-component trust | LAN attacker intercepts Caddy→API traffic | Self-signed TLS on API (always on), proxy shared secret for cross-host. Same-host: loopback is the trust boundary. | Passing |

### Mandatory controls for Phase 5 implementation

1. **Dedicated service user:** `clearskies` system user with no login shell. API runs as this user. Not in `sudo` group. Not the repo-owner user.
2. **Systemd hardening:** All 16 flags per security baseline §3.8 (NoNewPrivileges, ProtectSystem=strict, ProtectHome, PrivateTmp, etc.).
3. **Docker hardening:** Non-root USER, cap_drop ALL, read-only root FS, no-new-privileges, tmpfs /tmp.
4. **SSE connection limits:** Max concurrent SSE connections per IP. Backpressure on slow consumers. Idle timeout.
5. **Query cost limits:** Max time range per archive query. Query timeout at DB layer. Max result set size.
6. **pip-audit on host:** Install and run as part of deployment verification.
7. **Caddy audit:** Verify TLS 1.2+ minimum, HSTS, CSP, path filtering, admin endpoint blocking at proxy level.
8. **Security baseline update:** Fold §4 (realtime) into §3 (API). Add SSE-specific controls. Update port references.

## Consequences

- Phase 5 is mandatory before any production deployment. The gaps identified in T0.5 are not optional fixes.
- `rules/coding.md` gains a security section with enforceable rules derived from this ADR (T5B.6).
- Every new endpoint must declare whether it is public or admin-only.
- The weewx import boundary (`weewx.units` only) is enforced by code review and documented in `rules/coding.md`.

## Acceptance criteria

- [ ] Threat model documented with trust boundary diagram
- [ ] All T0.5 gaps remediated (systemd hardening, dedicated user, pip-audit)
- [ ] SSE connection limits implemented
- [ ] Query cost limits implemented (max time range, timeout)
- [ ] Caddy configuration audited against security headers checklist
- [ ] Security rules section added to `rules/coding.md`
- [ ] `systemd-analyze security weewx-clearskies-api` exposure score ≤ 3.0

## Implementation guidance

Phase 5 in the plan handles implementation:
- T5A.1–T5A.6: Audit (input validation sweep, auth boundary review, DoS assessment, weewx risk assessment, Caddy audit, dependency audit)
- T5B.1–T5B.5: Implementation (create user, set permissions, DB access, systemd hardening, Docker hardening)
- T5B.6: Distill rules into `rules/coding.md`

## Out of scope

- End-user authentication (ADR-008: not provided, operator adds at proxy layer)
- mTLS between proxy and API (ADR-008: disproportionate for home stations)
- WAF or IDS (operator's infrastructure choice)
- Penetration testing (no budget; security baseline + audit is the bar)

## References

- Related: [ADR-008](ADR-008-auth-model.md) (auth model), [ADR-012](ADR-012-database-access-pattern.md) (read-only DB), [ADR-037](ADR-037-inbound-traffic-architecture.md) (reverse proxy), [ADR-056](ADR-056-api-weewx-co-location.md) (co-location), [ADR-058](ADR-058-fold-realtime-into-api.md) (realtime merge)
- Contracts: [security-baseline.md](../contracts/security-baseline.md)
- Research: T0.5 findings (security verification), T0.6 findings (deployment state)
- Backlog: FIX-008
