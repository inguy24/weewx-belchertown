---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-030: Health check and readiness probes

## Context

Plan security baseline locks: "Health/readiness on a separate port, not internet-exposed." This ADR locks the endpoint contract, response shapes, and port behavior. Applies to both clearskies-api and clearskies-realtime.

## Decision

### Endpoints (each service)

- **`/health/live`** — liveness. Returns 200 if the process is responsive. No external dependencies checked. Used by orchestrators for "is the process dead?" decisions (k8s liveness probe, systemd `WatchdogSec`).
- **`/health/ready`** — readiness. Returns 200 if the process is ready to serve. Checks: database connection (api), weewx loop subscription (realtime), capability registry initialized (api), etc. Used by load balancers and orchestrators for "is this instance ready to receive traffic?" decisions.

### Response codes

- `200 OK` — healthy or degraded (one or more non-critical dependencies failing, but the service can still serve most requests).
- `503 Service Unavailable` — unhealthy; service cannot serve.

The "degraded → still 200" rule prevents orchestrators from killing the process when a single provider's API is temporarily down.

### Response body

JSON with top-level `status` and a `checks` object enumerating each dependency:

```json
{
  "status": "degraded",
  "checks": {
    "database": {"status": "ok"},
    "providers": {"status": "warning", "messages": ["forecast.aeris: key invalid"]}
  }
}
```

Body is for human / dashboard diagnostics; the orchestrator decision keys on the status code.

### Port

Health endpoints bind to a **separate port** from the main service (default `8081` for api when api is on `8080`; realtime defaults TBD per [ADR-005](ADR-005-realtime-architecture.md)). Health port binds to loopback by default — operators expose remotely via reverse proxy only when external monitoring requires it.

This satisfies "not internet-exposed" and prevents probe traffic from polluting access logs.

### Auth

Health endpoints are **unauthenticated** (loopback-only by default makes auth redundant). If an operator binds the health port to a non-loopback interface, they front it with proxy auth — same pattern as [ADR-008](ADR-008-auth-model.md).

### Binding

Health-port socket follows [rules/coding.md](../../rules/coding.md) §1 — IPv4/IPv6 dual-stack.

## Options considered

| Option | Verdict |
|---|---|
| A. Separate port; `/health/live` + `/health/ready`; degraded → 200; loopback default (this ADR) | **Selected.** |
| B. Single `/health` endpoint mixing liveness and readiness | Rejected — orchestrators want different signals; conflating causes restart loops. |
| C. Health on the main api port | Rejected — leaks probe traffic into access logs and exposes status to public internet by default. |
| D. Degraded → 503 | Rejected — orchestrators kill the process; one failing provider takes down the whole api. |

## Consequences

- Phase 2 work: small health module per service that runs the dependency checks and exposes both endpoints on the configured health port.
- INSTALL.md documents the default health port, how to change it, and example k8s / systemd probe configs.
- Provider modules added under [ADR-038](ADR-038-data-provider-module-organization.md) register their readiness signal via the capability registry — no per-provider health-endpoint code.

## Out of scope

- Detailed metrics (request counts, latency histograms) — [ADR-031](INDEX.md) (observability, Pinned).
- External synthetic monitoring — operator's deploy concern.
- Per-endpoint deep checks — Phase 6+ if needed.

## References

- Kubernetes probes: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- systemd watchdog: https://www.freedesktop.org/software/systemd/man/systemd.service.html#WatchdogSec=
- Related: [ADR-005](ADR-005-realtime-architecture.md), [ADR-008](ADR-008-auth-model.md), [ADR-029](ADR-029-logging-format-destinations.md), [ADR-031](INDEX.md), [ADR-037](ADR-037-inbound-traffic-architecture.md), [ADR-038](ADR-038-data-provider-module-organization.md).
