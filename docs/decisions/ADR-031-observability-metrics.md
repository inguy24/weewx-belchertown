---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-031: Observability and metrics exposure

## Context

[ADR-029](ADR-029-logging-format-destinations.md) locks structured JSON logs as the baseline observability surface. [ADR-030](ADR-030-health-check-readiness-probes.md) locks health/readiness endpoints. This ADR locks the metrics surface — what counters and histograms clearskies-api exposes for operators who want richer monitoring than logs alone.

## Decision

### Default: logs only; metrics off by default

Out of the box, clearskies-api emits structured JSON logs and serves health endpoints. **No metrics endpoint by default.** Logs are sufficient for the typical single-station operator.

### Optional: Prometheus `/metrics` endpoint

Operators who run Prometheus (or any scraper that speaks the Prometheus exposition format) opt in via config (`CLEARSKIES_METRICS_ENABLED=true`). When enabled:

- `/metrics` exposed on the **health port** (per [ADR-030](ADR-030-health-check-readiness-probes.md), loopback by default — same posture as `/health`).
- Plain-text Prometheus exposition format.
- Library: `prometheus-client` + `prometheus-fastapi-instrumentator` (or equivalent) for auto-instrumentation.

### What gets exposed

Auto-instrumented HTTP metrics:

- `http_requests_total{method, endpoint, status}` — counter.
- `http_request_duration_seconds{method, endpoint}` — histogram.

Provider-domain metrics (per [ADR-038](ADR-038-data-provider-module-organization.md)):

- `provider_calls_total{provider_id, domain, outcome}` — counter (`outcome` = `cache_hit` / `cache_miss_success` / `cache_miss_failure`).
- `provider_call_duration_seconds{provider_id, domain}` — histogram (cache misses only).

Cache metrics ([ADR-017](ADR-017-provider-response-caching.md)):

- `cache_hits_total{backend}` and `cache_misses_total{backend}`.

Database metrics ([ADR-012](ADR-012-database-access-pattern.md)):

- `db_query_duration_seconds{endpoint}` — histogram.

### What's NOT in metrics

- No request bodies or response bodies in labels.
- No operator config values.
- No PII (no IPs in labels — operators want aggregate data, not per-visitor tracking).

### Cardinality bounded

No high-cardinality labels (no per-user, no per-IP, no full URL with query params). Endpoint label uses route templates (e.g., `/api/v1/archive`), not concrete URLs.

## Options considered

| Option | Verdict |
|---|---|
| A. Logs by default; optional Prometheus exporter; OTel deferred (this ADR) | **Selected** — fits typical single-station ops; richer path for operators who want it. |
| B. OpenTelemetry by default | Rejected — heavy SDK; most operators don't run an OTel collector. |
| C. Logs only, no metrics endpoint at all | Rejected — operators with Prometheus already deployed get nothing. |
| D. Custom metrics format | Rejected — Prometheus exposition is the de-facto standard. |

## Consequences

- Phase 2 work: instrument FastAPI behind the `CLEARSKIES_METRICS_ENABLED` flag.
- Provider modules emit counter/histogram metrics via a small helper in `_common/`.
- `/metrics` is unauthenticated by virtue of loopback default — same as `/health`.
- INSTALL.md documents how to enable metrics + an example Prometheus scrape config.

## Out of scope

- OpenTelemetry — Phase 6+ if multiple operators request it.
- Distributed tracing — Phase 6+; v0.1 is single-process.
- Pre-built Grafana dashboards — operator's deploy concern; example dashboards in `clearskies-stack` are a Phase 6+ candidate.
- Real-user monitoring (RUM) — Phase 6+ per [ADR-033](ADR-033-performance-budget.md).

## References

- Prometheus exposition format: https://prometheus.io/docs/instrumenting/exposition_formats/
- `prometheus-client`: https://github.com/prometheus/client_python
- Related: [ADR-012](ADR-012-database-access-pattern.md), [ADR-017](ADR-017-provider-response-caching.md), [ADR-029](ADR-029-logging-format-destinations.md), [ADR-030](ADR-030-health-check-readiness-probes.md), [ADR-033](ADR-033-performance-budget.md), [ADR-038](ADR-038-data-provider-module-organization.md).
