---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-029: Logging format and destinations

## Context

Plan security baseline locks: "Structured JSON logs that never contain credentials or full SQL with values." This ADR locks the format details and where logs go.

## Decision

### Format: structured JSON, one record per line

Required fields on every record:

- `timestamp` — ISO 8601 UTC with `Z` suffix.
- `level` — one of `DEBUG` / `INFO` / `WARNING` / `ERROR` / `CRITICAL`.
- `logger` — Python logger name (e.g., `weewx_clearskies_api.providers.aqi.iqair`).
- `message` — human-readable.
- `request_id` — present when in HTTP-request context; absent otherwise.

Additional structured fields (`provider_id`, `endpoint`, `duration_ms`, etc.) attach as JSON keys on the same line — never embedded in the message string.

### Destination: stdout

clearskies-api and clearskies-realtime write to **stdout**. No log files written by our code. Operators capture via:

- **systemd**: `journalctl -u clearskies-api`.
- **Docker**: `docker logs ...` or the host's logging driver (operator's choice).

12-factor pattern. Log shipping (Loki/ELK/CloudWatch/etc.) is the operator's deploy concern.

### Sensitive-data filtering

A logging filter (stdlib `logging.Filter`) installed at root config strips:

- Authorization headers, API key values, contents of `secrets.env` keys.
- SQL parameter values — only the parameterized query template is logged.
- Full request bodies on auth-related endpoints.

Defense-in-depth, not a substitute for not-logging-secrets-in-the-first-place.

### Library

Python stdlib `logging` + a JSON formatter (project-internal or `python-json-logger`). No `structlog` / `loguru` for v0.1 — extra dependency unjustified. uvicorn's access log is reconfigured to use the same formatter at startup.

## Options considered

| Option | Verdict |
|---|---|
| A. JSON to stdout, stdlib `logging` + filter (this ADR) | **Selected.** |
| B. Plain-text logs to stdout | Rejected — defeats structured aggregation and field-level filtering. |
| C. JSON to file (e.g., `/var/log/clearskies-api/api.log`) | Rejected — fights 12-factor; pulls log-rotation work into our scope. |
| D. JSON to syslog | Rejected — adds socket complexity for what stdout + journald already covers. |

## Consequences

- INSTALL.md documents `journalctl` (systemd) and `docker logs` (Docker) as the default access patterns.
- Operators wanting log shipping configure their journal forwarder or Docker logging driver — no clearskies-api code change.
- Production default level is INFO. DEBUG is a firehose; operators enable per-incident.
- Log level configurable via env var (`CLEARSKIES_LOG_LEVEL`) and config file.

## Out of scope

- Log shipping configuration (Loki/ELK/CloudWatch) — operator's deploy concern.
- Audit-log retention — no separate audit log in v0.1.
- Distributed tracing — [ADR-031](INDEX.md) (observability, Pinned).

## References

- 12-factor logs: https://12factor.net/logs
- Python logging: https://docs.python.org/3/library/logging.html
- Related: [ADR-030](INDEX.md) (health checks — Pinned), [ADR-031](INDEX.md) (observability — Pinned).
