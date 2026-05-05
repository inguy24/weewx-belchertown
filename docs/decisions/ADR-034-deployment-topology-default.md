---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-034: Deployment topology default

## Context

Clear Skies' five components ([ADR-001](ADR-001-component-breakdown.md)) can be deployed on one host or several. This ADR locks the **recommended default** that documentation and `clearskies-stack` orchestration target. Operators can deviate; we recommend.

## Decision

### Default: single-host, co-located with weewx

The recommended topology is **all clearskies-* services on the same host as weewx**:

- weewx writes to the local archive DB; clearskies-api's read access is fastest co-located.
- clearskies-realtime subscribes to weewx's loop packets; co-location avoids broker complexity.
- One host = simpler TLS, simpler reverse-proxy config, simpler troubleshooting.
- A typical personal weather station runs on one Linux host (LXD container, VM, Raspberry Pi, NAS) — that host is sufficient.

### Two install paths, both single-host

1. **Native install** (recommended for existing weewx operators): `pip install` + systemd units for clearskies-api and clearskies-realtime; clearskies-dashboard built as static files served by the operator's existing web server (Apache / nginx / Caddy). TLS via the operator's existing cert pipeline.
2. **docker-compose** (recommended for new operators): a single `docker-compose.yml` in `clearskies-stack` runs api + realtime + dashboard + Caddy. Caddy auto-issues Let's Encrypt certs. **weewx itself is NOT bundled** — operator points the api at their existing weewx archive (volume mount or DB URL).

Operator picks at install time. INSTALL.md documents both side-by-side.

### Multi-host: supported but not the default

Operators who want api/realtime on the weewx host and dashboard served separately (e.g., a static-host service or CDN) can. clearskies-api binds to loopback by default ([ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-037](ADR-037-inbound-traffic-architecture.md)); cross-host exposure requires the operator's reverse-proxy + TLS work. Optional shared-secret header per [ADR-008](ADR-008-auth-model.md) is the recommended cross-host auth seam.

### What clearskies-stack ships

- A maintained `docker-compose.yml` for the single-host bundled case (the default).
- A reference example for multi-host (operator adapts to their topology — we don't test arbitrary distributed configs).

## Options considered

| Option | Verdict |
|---|---|
| A. Single-host default; both native and docker-compose paths; multi-host documented (this ADR) | **Selected** — fits the typical personal-weather-station deploy; both install modes covered. |
| B. Multi-host default | Rejected — most operators run a single host; multi-host is unnecessary operational complexity for the default. |
| C. docker-compose only | Rejected — many existing weewx operators run native; forcing Docker is hostile. |
| D. Native only | Rejected — new operators benefit from the easy-button compose flow. |

## Consequences

- `clearskies-stack` ships and maintains the single-host `docker-compose.yml`.
- INSTALL.md documents both flows.
- Cross-host config is reference-only; no promised tested compatibility for arbitrary distributed configs (consistent with AS-IS per [ADR-018](ADR-018-api-versioning-policy.md)).
- Caddy is the bundled TLS terminator in docker-compose; native installs use the operator's existing web server and certs.

## Out of scope

- Kubernetes manifests — Phase 6+ if demand surfaces.
- Multi-tenant deployment — out per [ADR-011](ADR-011-multi-station-scope.md).
- Bundling weewx itself in compose — out of scope (separate project).

## References

- Related: [ADR-001](ADR-001-component-breakdown.md), [ADR-005](ADR-005-realtime-architecture.md), [ADR-008](ADR-008-auth-model.md), [ADR-011](ADR-011-multi-station-scope.md), [ADR-027](ADR-027-config-and-setup-wizard.md), [ADR-037](ADR-037-inbound-traffic-architecture.md), [ADR-039](INDEX.md) (distribution — Pinned).
