---
status: Accepted (amended 2026-06-14 — topology simplified per ADR-058)
date: 2026-05-02
revised: 2026-05-23
deciders: shane
supersedes:
superseded-by:
amended-by: ADR-058
---

# ADR-034: Deployment topology default

## Context

Clear Skies' five components ([ADR-001](ADR-001-component-breakdown.md)) can be deployed on one host or several. This ADR locks the **recommended default** that documentation and `clearskies-stack` orchestration target. Operators can deviate; we recommend.

## Decision

### Per-repo container images

Each Clear Skies repo ships its own Dockerfile and builds its own container image. This keeps builds independent — a dashboard CSS tweak does not rebuild the API image.

| Container | Repo | Role | Host (default) |
|---|---|---|---|
| `clearskies-api` | weewx-clearskies-api | REST API for weewx archive data | weewx host |
| `clearskies-realtime` | weewx-clearskies-realtime | SSE server for live loop packets | front-end host |
| `clearskies-dashboard` | weewx-clearskies-dashboard | Static SPA served by Caddy | front-end host |
| `clearskies-caddy` | weewx-clearskies-stack | Reverse proxy, TLS, serves dashboard static files, proxies `/api/*` to API and `/sse` to realtime | front-end host |

### Default topology: two-host split

- **weewx host:** API container only — co-located with the weewx archive DB for fast local reads.
- **Front-end host:** dashboard + realtime + Caddy containers. Caddy proxies API requests over the network to the weewx host.

Single-host deployment remains possible — operator runs all four containers on one machine.

### Two install paths

1. **Container install** (recommended for new operators): each repo builds its own image via its Dockerfile. `clearskies-stack` provides per-host orchestration config (compose files, env examples, Caddyfile) showing how to wire the containers together. Caddy auto-issues Let's Encrypt certs. **weewx itself is NOT bundled** — operator points the API at their existing weewx archive (volume mount or DB URL).
2. **Native install** (recommended for existing weewx operators): `pip install` + systemd units for clearskies-api and clearskies-realtime; clearskies-dashboard built as static files served by the operator's existing web server (Apache / nginx / Caddy). TLS via the operator's existing cert pipeline.

Operator picks at install time. INSTALL.md documents both side-by-side.

### What clearskies-stack ships

- Per-host orchestration config (compose files, env examples, Caddyfile) for wiring the independent containers together.
- Reference config for single-host deployment.
- No monolithic docker-compose that bundles all services into one image or one stack.

### Multi-host variations: supported but not tested

Operators who want a topology beyond the two-host default (e.g., dashboard on a CDN, realtime on a third host) can adapt the orchestration config. clearskies-api binds to loopback by default ([ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-037](ADR-037-inbound-traffic-architecture.md)); cross-host exposure requires the operator's reverse-proxy + TLS work. Optional shared-secret header per [ADR-008](ADR-008-auth-model.md) is the recommended cross-host auth seam.

## Options considered

| Option | Verdict |
|---|---|
| A. Per-repo containers, two-host default, both container and native paths (this ADR) | **Selected** — independent builds per repo, clean CI/CD, matches repo boundaries. |
| B. Single docker-compose bundles all services | Rejected — couples unrelated services, one repo change rebuilds everything, assumes single-host. |
| C. Two containers (dashboard baked into Caddy, realtime separate) | Rejected — pragmatically simpler but couples dashboard and Caddy repos, loses independent rebuild. |
| D. One container (everything except API bundled) | Rejected — can't restart realtime without dropping dashboard traffic, violates single-responsibility. |
| E. docker-compose only, no native path | Rejected — many existing weewx operators run native; forcing Docker is hostile. |
| F. Native only | Rejected — new operators benefit from the container easy-button. |

## Consequences

- Each of `clearskies-api`, `clearskies-realtime`, and `clearskies-dashboard` ships a Dockerfile in its repo root.
- `clearskies-stack` provides orchestration config, not a monolithic compose file.
- INSTALL.md documents both container and native flows.
- Cross-host config beyond the two-host default is reference-only; no promised tested compatibility for arbitrary distributed configs (consistent with AS-IS per [ADR-018](ADR-018-api-versioning-policy.md)).
- Caddy is the bundled TLS terminator in the container path; native installs use the operator's existing web server and certs.

## Out of scope

- Kubernetes manifests — Phase 6+ if demand surfaces.
- Multi-tenant deployment — out per [ADR-011](ADR-011-multi-station-scope.md).
- Bundling weewx itself in a container — out of scope (separate project).

## Amendment: topology simplified (ADR-058, 2026-06-14)

Amended 2026-06-14: Per [ADR-058](ADR-058-fold-realtime-into-api.md), the realtime service has been merged into the API. The container inventory loses `clearskies-realtime`. Port 8766 and 8082 are removed from the port registry. The two-host default topology simplifies to: API on the weewx host (port 8765), dashboard + Caddy on the front-end host (no realtime container). Caddy routes `/api/v1/*` and `/sse` both directly to the API at port 8765.

The `clearskies-realtime` Dockerfile, systemd unit (`weewx-clearskies-realtime.service`), and `realtime.conf` are deprecated. Realtime settings (input mode, SSE, unit conversion) fold into `api.conf`. The two install paths (container and native) remain; native install now covers API only (no separate realtime service).

## References

- Related: [ADR-001](ADR-001-component-breakdown.md), [ADR-005](ADR-005-realtime-architecture.md), [ADR-008](ADR-008-auth-model.md), [ADR-011](ADR-011-multi-station-scope.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-037](ADR-037-inbound-traffic-architecture.md), [ADR-039](INDEX.md) (distribution — Pinned).
- Amended by: [ADR-058](ADR-058-fold-realtime-into-api.md) (fold realtime into API).
