---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-012: Database access pattern

## Context

clearskies-api reads from the weewx archive — never writes. weewx owns the schema; we adapt to whatever's there. This ADR locks the access pattern: driver, read-only enforcement, schema introspection, connection lifecycle.

## Decision

### Driver: SQLAlchemy 2.x ([ADR-002](ADR-002-tech-stack.md))

- Parameterized queries by default (per [rules/coding.md](../../rules/coding.md) §1).
- One config knob for the database URL — SQLite (default weewx) and MariaDB supported transparently. No per-driver code paths in api endpoints.
- Connection pool: SQLAlchemy default `pool_size=5`, `max_overflow=10`. Configurable via env / config file.

### Read-only enforcement: defense in depth

Two layers:

1. **DB user at the database**: operator provisions a user granted only `SELECT` on the archive. INSTALL.md documents the SQL grants per backend.
2. **Verified at startup**: clearskies-api runs a write-attempt probe and **refuses to start** if the user has any of `INSERT` / `UPDATE` / `DELETE` / `DROP` on the archive. Per plan security baseline.

Failure mode: log loudly, exit non-zero. Operators see the systemd / Docker restart loop and check INSTALL.md.

For SQLite (no DB user concept): use the URI `?mode=ro` parameter (`sqlite:///path/weewx.sdb?mode=ro&uri=true`) plus filesystem permissions. The startup probe still runs — write attempts on `mode=ro` URIs return errors.

### Schema introspection at startup → column registry

- At startup, `MetaData.reflect()` runs against the `archive` table.
- The reflected column list feeds the canonical-mapping system per [ADR-035](ADR-035-user-driven-column-mapping.md).
- Custom columns (operator's AQI extension columns, etc.) are discovered automatically — no hard-coded allow-list.
- Re-introspection is operator-triggered via the configuration UI (e.g., after the operator adds a new weewx extension and re-runs the mapping flow).

### Connection lifecycle: per-request session

FastAPI dependency injection yields a SQLAlchemy session per request. Session closed at request end. No long-lived sessions in api code.

### Custom-column handling

clearskies-api never assumes a specific weewx schema beyond what's actually present. Endpoints select columns from the operator's mapping ([ADR-035](ADR-035-user-driven-column-mapping.md)), not a hard-coded list.

## Options considered

| Option | Verdict |
|---|---|
| A. SQLAlchemy 2.x + read-only DB user + startup probe + reflection (this ADR) | **Selected** — defense in depth, supports custom columns, minimal per-driver code. |
| B. Raw `sqlite3` / `mysql.connector` per backend | Rejected — duplicates code per driver; loses parameterized-query enforcement at type level. |
| C. Read-only enforcement via app-layer query filter only (no DB-user grant) | Rejected — bypassed by any SQL bug. Defense in depth needs the DB layer. |
| D. Hard-coded weewx column allow-list | Rejected — custom columns flow through ADR-035; fixed list defeats them. |

## Consequences

- Phase 2 work: SQLAlchemy engine + read-only probe + reflection module + per-request session dep.
- INSTALL.md documents the SQL grants for SQLite (file-permission-only) and MariaDB (`GRANT SELECT ON weewx.* TO 'clearskies'@'localhost'`).
- Schema reflection has a small startup cost — measured once, in seconds for a typical archive.
- Re-introspection during runtime is triggered by the configuration UI; api never re-reflects mid-request.
- ORM-vs-Core choice deferred to Phase 2; Core likely for read-heavy aggregations.

## Out of scope

- weewx schema documentation — already public; we link to it.
- Migration tooling — weewx owns the schema; we never migrate.
- Backends beyond SQLite + MariaDB (Postgres, etc.) — Phase 6+ if demand surfaces.
- Read-replica routing — out of scope; v0.1 single-instance.

## References

- weewx documentation: https://weewx.com/docs/
- SQLAlchemy 2.x reflection: https://docs.sqlalchemy.org/en/20/core/reflection.html
- SQLite read-only URI: https://www.sqlite.org/uri.html
- Related: [ADR-002](ADR-002-tech-stack.md), [ADR-035](ADR-035-user-driven-column-mapping.md), [rules/coding.md](../../rules/coding.md).
