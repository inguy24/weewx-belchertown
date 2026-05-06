# Security baseline

**Status:** Draft (Phase 1 deliverable; companion to the source ADRs and [`rules/coding.md`](../../rules/coding.md))
**Last updated:** 2026-05-05

This document is the per-component security checklist the Clear Skies project commits to. It consolidates the security-relevant decisions scattered across 7 ADRs and `coding.md` §1, plus cross-cutting controls not pinned to any single ADR (security headers, request limits, systemd/Docker hardening, dependency auditing, per-repo `SECURITY.md`).

**Scope.** Every Clear Skies repo: `weewx-clearskies-api`, `weewx-clearskies-realtime`, `weewx-clearskies-dashboard`, `weewx-clearskies-stack`. Excludes `weewx-clearskies-design-tokens` (deferred to Phase 6+ per [ADR-001](../decisions/ADR-001-component-breakdown.md)).

**Posture.** Software is AS-IS under GPL v3 per [ADR-003](../decisions/ADR-003-license.md) — no warranty, no support window, no LTS. This document is the standard the maintainer holds the project to during development; deployments inherit the same controls. Per [ADR-018](../decisions/ADR-018-api-versioning-policy.md) there is no security-backport commitment for prior versions.

**How to use.** Phase 2+ dev agents check every applicable item before submitting work for review. The auditor agent verifies the same list. Releases are blocked on outstanding items unless the gap is documented and justified in the release notes.

---

## 1. Source map

Every control below traces to one of these sources.

| Source | What it contributes |
|---|---|
| [ADR-003](../decisions/ADR-003-license.md) | GPL v3 license; DCO sign-off on every commit |
| [ADR-008](../decisions/ADR-008-auth-model.md) | No end-user auth in v0.1; optional `X-Clearskies-Proxy-Auth` shared secret for cross-host proxy↔inner-service trust |
| [ADR-012](../decisions/ADR-012-database-access-pattern.md) | Read-only DB user enforced at the database AND a startup write-probe that refuses to start if write privileges exist |
| [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) | Secrets in `secrets.env` (mode 0600); env-var injection; configuration UI HTTPS by default + admin user/password auth |
| [ADR-029](../decisions/ADR-029-logging-format-destinations.md) | Structured JSON logs to stdout; `logging.Filter` strips auth headers, API keys, SQL parameter values |
| [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) | `/health/live` + `/health/ready` on a separate loopback-bound port; unauthenticated by virtue of loopback default |
| [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md) | One-door reverse proxy; inner services bind to loopback (or trusted-LAN cross-host); browser never reaches the inner service directly |
| [`rules/coding.md`](../../rules/coding.md) §1 | Code-level controls: no hardcoded secrets, validated inputs at trust boundaries, parameterized SQL, output escaping, dangerous-function bans, IPv4/IPv6 dual-stack, pinned dependencies |

---

## 2. Cross-cutting controls (every Clear Skies repo)

Apply identically to api, realtime, dashboard, stack.

| Control | Source | How | Verify |
|---|---|---|---|
| `SECURITY.md` at repo root | This doc | Disclosure address + AS-IS posture + supported-version statement (= "current `main` only") | Reviewer confirms file exists |
| GPL v3 `LICENSE` at repo root | [ADR-003](../decisions/ADR-003-license.md) | Copy from GNU canonical text | Reviewer confirms file exists |
| DCO sign-off on every commit | [ADR-003](../decisions/ADR-003-license.md) | `Signed-off-by:` line on every commit; GHA workflow rejects PR commits without it | CI fails the PR if any commit lacks sign-off |
| Pinned dependencies | [`coding.md`](../../rules/coding.md) §1 | Python: `==` pins + lockfile (`uv.lock` / `poetry.lock`). JS: `package-lock.json`, `npm ci` in CI. Docker base images: `@sha256:...` digests. GHA: third-party actions pinned by SHA, not tag. | CI uses the lockfile path; PR diff inspection on lockfile and digest changes |
| Dependency vulnerability audit | This doc | `pip-audit` (Python repos), `npm audit --audit-level=high` (JS repos) on every PR + nightly schedule | CI fails PR on new high-severity advisories; nightly result posted to repo |
| No hardcoded secrets in source / git history | [`coding.md`](../../rules/coding.md) §1 | `.env` (gitignored) or env-var injection; `gitleaks` pre-commit + CI scan on diff and full tree | CI fails on detected leaks; manual review for false-positive baseline |

---

## 3. weewx-clearskies-api

FastAPI + SQLAlchemy backend. Largest attack surface — most controls live here.

### 3.1 Network & HTTP listener

| Control | Source | How | Verify |
|---|---|---|---|
| Loopback bind by default | [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md) | uvicorn `--host 127.0.0.1`; documentation warns operators against changing this without a reverse proxy in front | Integration test asserts default config binds loopback only |
| IPv4 + IPv6 dual-stack when bound non-loopback | [`coding.md`](../../rules/coding.md) §1 | `socket.getaddrinfo` resolves the listening host into the full `(family, address)` set; bind each | Integration test connects from both `127.0.0.1` and `::1` |
| Request body size limit | This doc | Default 1 MiB via Starlette middleware; configurable per `[api] max_request_bytes` for paths with legitimately larger payloads | Integration test posts 2 MiB → 413 |
| Per-IP rate limit | This doc | Middleware-based; default 60 req/min per IP for unauthenticated paths; bypassed when `X-Clearskies-Proxy-Auth` is valid. Storage: Redis when `CLEARSKIES_CACHE_URL` is set per [ADR-017](../decisions/ADR-017-provider-response-caching.md), in-process otherwise (single-worker only). | Integration test exhausts quota → 429 with `Retry-After` |
| CORS locked to known origins | This doc | Default = same-origin (browser served by the same proxy as the api per [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md)); operator can add an additional dashboard origin via config | Integration test asserts unconfigured origin is rejected |
| Response security headers | This doc | `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`; `Server:` header suppressed. HSTS / CSP / `X-Frame-Options` are set by the reverse proxy, not here. | Integration test inspects response headers |

### 3.2 Authentication

| Control | Source | How | Verify |
|---|---|---|---|
| No end-user authentication | [ADR-008](../decisions/ADR-008-auth-model.md) | All public-facing API paths unauthenticated by design | OpenAPI security scheme reflects default `{}` |
| Optional `X-Clearskies-Proxy-Auth` shared secret | [ADR-008](../decisions/ADR-008-auth-model.md) | Constant-time compare; secret loaded from env (`CLEARSKIES_PROXY_SECRET`); when unset, header is silently ignored | Unit test for constant-time path; integration test for unset/set/wrong cases |
| Configuration UI admin auth | [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) | Admin user/password; bcrypt or argon2 hash stored in config; HTTPS-only listener with self-signed cert + printed fingerprint per ADR-027 | Integration test for unauth → 401 |

### 3.3 Database access

| Control | Source | How | Verify |
|---|---|---|---|
| Read-only DB user at the database | [ADR-012](../decisions/ADR-012-database-access-pattern.md) | INSTALL doc instructs operator to create a `SELECT`-only grant; SQLite uses `?mode=ro` URI | INSTALL doc reviewed; integration test uses a SELECT-only fixture user |
| Startup write-probe | [ADR-012](../decisions/ADR-012-database-access-pattern.md) | At startup, attempt an `INSERT` against a sentinel table; if it succeeds, log critical + exit non-zero. SQLite path checks the URI carries `?mode=ro`. | Integration test with a writable user → service refuses to start |
| Parameterized queries everywhere | [`coding.md`](../../rules/coding.md) §1 | SQLAlchemy 2.x typed `select()` / Core; no f-string SQL anywhere | Linter + grep CI gate forbidding `text("...{...}")` and f-strings inside `db/` |
| Per-request session lifecycle | [ADR-012](../decisions/ADR-012-database-access-pattern.md) | FastAPI dependency-injection scope; explicit `session.close()` on teardown | Integration test asserts no session leakage under load |

### 3.4 Secrets & configuration

| Control | Source | How | Verify |
|---|---|---|---|
| Secrets in `secrets.env` mode 0600 | [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) | INSTALL doc + `chmod 600` post-install step in systemd unit's `ExecStartPre` | Reviewer confirms post-install permission |
| Env-var injection at runtime | [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) | systemd `EnvironmentFile=` directive; Docker `env_file:` | Documented; integration test confirms no secret in process environment dump captured by health endpoint |
| No secret in source / git history | [`coding.md`](../../rules/coding.md) §1 | Pre-commit `gitleaks`; CI scan on every PR | CI fails on detected leak |
| No secret in logs | [ADR-029](../decisions/ADR-029-logging-format-destinations.md) | `logging.Filter` strips `Authorization`, `X-Clearskies-Proxy-Auth`, `appid`, `client_secret`, SQL parameter values | Unit test injects each known secret pattern; assert filtered output |

### 3.5 Input validation & output handling

| Control | Source | How | Verify |
|---|---|---|---|
| Validate every HTTP query/path/body | [`coding.md`](../../rules/coding.md) §1 | Pydantic models with `extra="forbid"`; FastAPI auto-validates | OpenAPI spec is authoritative; PR review checks every new endpoint |
| Validate provider responses | [`coding.md`](../../rules/coding.md) §1 | Pydantic models for each provider's wire shape inside the normalizer | Unit test feeds malformed/unexpected provider response → normalizer raises `ProviderProtocolError` per [ADR-038](../decisions/ADR-038-data-provider-module-organization.md) |
| Validate weewx archive rows | [`coding.md`](../../rules/coding.md) §1 | Range checks on rain/lightning/wind extremes before serving; out-of-range → field set to `null`, log warning | Unit test with synthetic outlier rows |
| Output escaping | [`coding.md`](../../rules/coding.md) §1 | api returns JSON only; no HTML rendering. Markdown content for `/content/about` and `/content/legal` is passed raw to the dashboard, which sanitizes on render (see §5) | Documented N/A |
| Dangerous-function ban | [`coding.md`](../../rules/coding.md) §1 | No `eval`, `exec`, `pickle.loads` on untrusted, `subprocess(shell=True)` with user input, `yaml.load` (use `yaml.safe_load`) | `bandit` or ruff `S` ruleset enabled; CI gate |

### 3.6 Logging & observability

| Control | Source | How | Verify |
|---|---|---|---|
| JSON one-line-per-record to stdout | [ADR-029](../decisions/ADR-029-logging-format-destinations.md) | Stdlib `logging` + custom JSON formatter; required fields `timestamp`/`level`/`logger`/`message`/`request_id` | Integration test captures stdout + parses each line as JSON |
| Redaction filter on auth + SQL params | [ADR-029](../decisions/ADR-029-logging-format-destinations.md) | `logging.Filter` registered globally | Unit test (see §3.4) |
| User-facing errors carry no stack/internal paths | [`coding.md`](../../rules/coding.md) §3 | RFC 9457 `application/problem+json` per [ADR-018](../decisions/ADR-018-api-versioning-policy.md); `detail` is operator-safe; full context lives in logs only | Integration test inspects 500-response body for absence of stack/path |

### 3.7 Health & readiness

| Control | Source | How | Verify |
|---|---|---|---|
| `/health/live` + `/health/ready` on separate loopback port | [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) | Default port 8081 loopback; configurable via `[health] bind = 127.0.0.1:8081` | Integration test confirms 8081 reachable from loopback, NOT from external interface |
| Health endpoints unauthenticated | [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) | OpenAPI marks `security: []`; loopback default makes external auth moot | Integration test confirms no auth required from loopback |
| Degraded → 200, unhealthy → 503 | [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) | `HealthStatus.status` enum drives response code; transient provider failure does NOT trip 503 | Unit test for each enum branch |

### 3.8 Process hardening (systemd & Docker)

| Control | Source | How | Verify |
|---|---|---|---|
| systemd unit hardening | This doc | `NoNewPrivileges=yes`, `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes`, `ProtectKernelTunables=yes`, `ProtectKernelModules=yes`, `ProtectControlGroups=yes`, `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX`, `RestrictNamespaces=yes`, `LockPersonality=yes`, `MemoryDenyWriteExecute=yes`, `CapabilityBoundingSet=` (empty), `AmbientCapabilities=` (empty), `SystemCallFilter=@system-service`, `SystemCallErrorNumber=EPERM`, `ReadWritePaths=` listing only the config + data dirs (no log dir — logs go to stdout per [ADR-029](../decisions/ADR-029-logging-format-destinations.md)) | Reviewer confirms unit file; `systemd-analyze security weewx-clearskies-api` exposure score ≤ 3.0 ("OK" or better) |
| Docker non-root user | This doc | `USER api` in Dockerfile; uid mapped explicitly | `docker inspect` shows non-root |
| Docker drop-all-caps | This doc | `cap_drop: [ALL]` in compose; `cap_add` empty | `docker inspect` shows no caps |
| Docker read-only root fs | This doc | `read_only: true` in compose; explicit `tmpfs` for `/tmp`; data + log volumes are bind-mounts | `docker inspect` shows `ReadonlyRootfs: true` |
| Docker `no-new-privileges` | This doc | `security_opt: [no-new-privileges:true]` in compose | `docker inspect` shows the flag |
| Docker `HEALTHCHECK` directive | [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) | curl loopback `/health/ready`; interval/timeout aligned with default poll cadence | `docker inspect` shows healthcheck config |

---

## 4. weewx-clearskies-realtime

Smaller surface — same principles, narrower scope. Service is read-only on the weewx loop pipeline (subscribes to MQTT or watches loop packet socket per [ADR-005](../decisions/ADR-005-realtime-architecture.md)) and serves SSE clients.

| Category | Differences from api |
|---|---|
| Network & HTTP | Same loopback default, dual-stack, request limits. SSE connections are long-lived; rate-limiting is on connection ESTABLISHMENT, not per-event. |
| Authentication | Same `X-Clearskies-Proxy-Auth` optional secret. No end-user auth. |
| Data access | **No DB access in v0.1** — service consumes loop packets only. weewx archive is the api's domain. |
| Secrets | Same `secrets.env` 0600 + env-var injection. Realtime needs MQTT broker creds when in MQTT-subscriber mode per [ADR-005](../decisions/ADR-005-realtime-architecture.md). |
| Input validation | Validate every loop packet field via Pydantic before publishing as SSE event. Malformed packet → drop + warning log, do not propagate. |
| Logging | Same JSON + redaction. |
| Health | Same `/health/live` + `/health/ready` on loopback, default port 8082 (distinct from api's 8081). |
| Process hardening | Same systemd + Docker control set as api. |

---

## 5. weewx-clearskies-dashboard

Static React SPA — built artifact is HTML/CSS/JS served by the reverse proxy. **No server-side runtime; no secrets at runtime; no DB access.**

| Control | Source | How | Verify |
|---|---|---|---|
| No secrets in built bundle | [`coding.md`](../../rules/coding.md) §1 | `.env` referenced via `import.meta.env.VITE_*`; never `import.meta.env.SECRET_*`. API URL is the only build-time variable; proxy auth never reaches the browser per [ADR-008](../decisions/ADR-008-auth-model.md) | `gitleaks` on the built bundle in CI |
| No `eval` / `Function` / `innerHTML` with untrusted data | [`coding.md`](../../rules/coding.md) §1 | ESLint rules `no-eval`, `no-implied-eval`, `no-new-func`, `react/no-danger`; CI fails PR on any new occurrence | CI lint job |
| Subresource integrity for any external script | This doc | v0.1 ships zero external scripts (everything bundled by Vite). If this changes, every external `<script>` requires `integrity=` + `crossorigin=` | Reviewer confirms `index.html` after build |
| `npm audit --audit-level=high` clean | This doc | CI nightly + per-PR; high+ severity blocks merge | CI gate |
| Dependency lockfile in CI | [`coding.md`](../../rules/coding.md) §1 | `npm ci` (NOT `npm install`); `package-lock.json` committed | CI uses `npm ci` |
| Content Security Policy (set by proxy) | This doc | Dashboard documents the CSP the proxy should set: `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: <radar-tile-providers>; connect-src 'self' <radar-keyless-providers>` | Documented in `INSTALL.md`; Caddyfile in `clearskies-stack` includes the directive |
| Output escaping in JSX | [`coding.md`](../../rules/coding.md) §1 | React escapes by default; `dangerouslySetInnerHTML` banned outside the sanitized-markdown component | ESLint `react/no-danger` exceptions allowlisted to that one component |
| Markdown content sanitization | This doc | `/content/about` and `/content/legal` markdown rendered through `react-markdown` with default sanitizers; raw HTML pass-through disabled | Unit test feeds `<script>alert(1)</script>` → output rendered as text, not executed |

---

## 6. weewx-clearskies-stack

Meta repo with `docker-compose.yml`, `Caddyfile`, INSTALL guide, example HA configs. No runtime code.

| Control | Source | How | Verify |
|---|---|---|---|
| Compose pins image digests | [`coding.md`](../../rules/coding.md) §1 | Every `image:` reference is `@sha256:...` (or a versioned tag in dev-only profiles, clearly marked) | Reviewer scans `docker-compose.yml` |
| Caddy auto-LE TLS | [ADR-034](../decisions/ADR-034-deployment-topology-default.md) | Caddyfile uses `tls user@example.com` directive; auto-renewal is Caddy's default | Smoke test in deploy-rehearsal env confirms cert issued |
| Caddy enforces security headers | This doc | Caddyfile sets HSTS (`Strict-Transport-Security: max-age=31536000; includeSubDomains`), CSP (per dashboard §5), `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: <minimal>` | curl response inspection in deploy-rehearsal env |
| Caddy proxies to inner services on loopback | [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md) | `reverse_proxy 127.0.0.1:8000` for api; `reverse_proxy 127.0.0.1:8001` for realtime; dashboard served as static file root | Reviewer confirms Caddyfile |
| Bind-mount config dir | [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) + [ADR-028](../decisions/ADR-028-update-mechanism.md) | `/etc/weewx-clearskies/` mounted into containers; `secrets.env` permission preserved by setup script | INSTALL doc; smoke test in deploy-rehearsal env |

---

## 7. CI gating

What's automated, per repo. CI fails the PR (= blocks merge) on every check below.

| Gate | api | realtime | dashboard | stack |
|---|---|---|---|---|
| DCO sign-off on every commit | ✅ | ✅ | ✅ | ✅ |
| Lockfile present + used (`npm ci` / `uv sync --locked`) | ✅ | ✅ | ✅ | N/A (no app deps) |
| `pip-audit` (Python) / `npm audit --audit-level=high` (JS) | ✅ | ✅ | ✅ | N/A |
| `gitleaks` secret scan on diff + tree | ✅ | ✅ | ✅ | ✅ |
| Linter — ruff for Python (incl. `S` security rules), ESLint for JS | ✅ | ✅ | ✅ | N/A |
| Type check — mypy strict / pyright; tsc | ✅ | ✅ | ✅ | N/A |
| Test suite — pytest (both DB backends per [ADR-012](../decisions/ADR-012-database-access-pattern.md)) / vitest + Playwright | ✅ | ✅ | ✅ | N/A |
| `axe-core` accessibility scan on built dashboard | N/A | N/A | ✅ | N/A |
| Third-party GHA actions pinned by SHA | ✅ | ✅ | ✅ | ✅ |

Manual / pre-release verification is in [`coding.md`](../../rules/coding.md) §4 and §5.8 (per-change + pre-ship audits).

---

## 8. Known gaps & opinionated defaults

These choices are not pinned by any ADR and may be revised during Phase 2+ implementation. Revisions go into this document, not into a new ADR.

- **Request body limit defaults to 1 MiB.** Concrete risk: a legitimately-large markdown blob to `/content/about` or `/content/legal` could trip 413. Mitigation if it does: bump default OR exempt the `/content/*` paths via per-path config.
- **Per-IP rate-limit storage.** With `CLEARSKIES_CACHE_URL` set, rate-limit state lives in Redis (consistent with [ADR-017](../decisions/ADR-017-provider-response-caching.md)'s multi-worker requirement); without it, in-process storage is single-worker-only. A multi-worker deploy without Redis silently delivers N × the documented rate budget. Phase 2 work must enforce the Redis dependency at startup when worker count > 1.
- **Markdown rendering** uses `react-markdown` with sanitizing defaults. A future contributor swapping in a non-sanitizing alternative (raw `marked` + `dangerouslySetInnerHTML` outside the allowlisted component) silently removes XSS protection. Phase 3 ESLint config locks `react/no-danger` exceptions to the one component allowlisted in §5.
- **realtime health port = 8082** is invented in this document, not pinned by [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) (which only specifies 8081 for api). If another service later wants 8082, this document is the conflict point.
- **DCO enforcement mechanism** (GitHub's built-in DCO app vs a custom GHA workflow) is left to the Phase 1 GitHub-repo standup task. Either choice satisfies the control; the choice goes here once made.
- **Dashboard CSP is provisional.** The header above is a starting point; radar tile providers per [ADR-015](../decisions/ADR-015-radar-map-tiles-strategy.md) and any chart-library Web Worker scripts may require additions during Phase 3.

---

## 9. Update protocol

Triggers for revising this document:

1. **A new ADR introduces a security-relevant control.** Add a row in the appropriate section; cite the ADR.
2. **A control implementation changes** (e.g. switching the rate-limit middleware library). Update the "How" cell; the control itself stays.
3. **A new threat or vulnerability class is identified** that no existing control addresses. Add a row in the affected component's table; if it crosses components, in §2 (cross-cutting).
4. **A control is removed.** Requires the corresponding source ADR to be updated first (or a new ADR if no source exists). Removal here without source-ADR change is a process violation.

This document is co-authoritative with the source ADRs. Drift between this doc and a source ADR is a bug — fix the doc.

---

## 10. References

- ADRs: [ADR-003](../decisions/ADR-003-license.md), [ADR-005](../decisions/ADR-005-realtime-architecture.md), [ADR-008](../decisions/ADR-008-auth-model.md), [ADR-012](../decisions/ADR-012-database-access-pattern.md), [ADR-015](../decisions/ADR-015-radar-map-tiles-strategy.md), [ADR-017](../decisions/ADR-017-provider-response-caching.md), [ADR-018](../decisions/ADR-018-api-versioning-policy.md), [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md), [ADR-028](../decisions/ADR-028-update-mechanism.md), [ADR-029](../decisions/ADR-029-logging-format-destinations.md), [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md), [ADR-034](../decisions/ADR-034-deployment-topology-default.md), [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md), [ADR-038](../decisions/ADR-038-data-provider-module-organization.md).
- Code rules: [`rules/coding.md`](../../rules/coding.md) §1, §3, §4, §5.
- Companion contracts: [`openapi-v1.yaml`](openapi-v1.yaml), [`canonical-data-model.md`](canonical-data-model.md).
