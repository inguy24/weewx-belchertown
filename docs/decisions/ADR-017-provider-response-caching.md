---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-017: Provider-response caching strategy

## Context

clearskies-api calls external provider APIs (forecast, AQI current values, alerts, radar metadata) per [ADR-038](ADR-038-data-provider-module-organization.md). Without caching, every dashboard request triggers an upstream call — burns operator API quotas (per [ADR-006](ADR-006-compliance-model.md), the operator pays for those calls in their plan) and adds latency. This ADR locks how provider responses are cached.

## Decision

### Pluggable cache backend; in-memory by default, Redis-optional

A small cache abstraction in clearskies-api with two backends:

- **`memory`** (default) — in-process LRU+TTL via `cachetools.TTLCache` or equivalent. Zero external deps.
- **`redis`** (optional) — operator points at a Redis server via config (e.g., `CLEARSKIES_CACHE_URL=redis://localhost:6379/0`). Uses `redis-py` with TTL support.

Operator picks via config. Default is `memory`. The abstraction is a thin interface — provider modules don't know which backend is active.

### Worker-count guidance (load-bearing — load-bearing)

uvicorn defaults to a **single worker** in our shipped systemd unit and Docker image. Single worker + in-memory cache is the v0.1 happy path; sufficient for typical personal-weather-station traffic.

Operators who run multiple uvicorn workers for throughput **must** switch to the Redis backend, otherwise each worker maintains a separate in-memory cache and operator API quotas get burned proportionally. INSTALL.md documents this explicitly.

### Per-provider TTL declaration

Each provider module declares a default TTL via its capability declaration ([ADR-038](ADR-038-data-provider-module-organization.md) rule 4); operators override per-provider via config.

Defaults (operator-overridable):

| Domain | Default TTL |
|---|---|
| Forecast (current + hourly + daily) | 30 min |
| Alerts | 5 min |
| AQI current reading | 15 min |
| Radar tile metadata (frame timestamps) | 5 min |
| Radar tile bytes (proxied keyed providers) | match upstream `Cache-Control`; otherwise 5 min |

### Cache key

Deterministic hash of `(provider_id, endpoint, normalized_params)`. Param normalization sorts query keys alphabetically; lat/lon rounded to 4 decimal places.

### Cache invalidation

TTL-only. No manual purge endpoint at v0.1. Operators bounce the service (memory backend) or `redis-cli FLUSHDB` (redis backend) to clear.

## Options considered

| Option | Verdict |
|---|---|
| A. Pluggable backend; `memory` default + `redis` optional (this ADR) | **Selected** — keeps v0.1 dep-free for typical single-worker deploys; gives multi-worker / high-traffic operators a clean upgrade path without rewriting code. |
| B. In-memory only, no Redis option | Rejected — multi-worker deploys silently 4× their provider API calls; cold-start after restart hits upstream hard. Real concerns the abstraction solves cheaply. |
| C. Redis required everywhere | Rejected — operational dep for the typical single-station deploy where it adds nothing. Increases install friction. |
| D. SQLite-backed cache | Rejected — disk IO on every request; doesn't solve multi-worker (file locking is contention-heavy at this access pattern). |
| E. No caching | Rejected — burns operator quotas; bad provider citizenship. |

## Consequences

- Phase 2 work: cache abstraction interface + two backend implementations (memory, redis); provider modules check cache before upstream call and populate on miss.
- INSTALL.md documents single-worker default and the multi-worker → Redis requirement explicitly.
- Memory backend: bounded by LRU `maxsize` (default ~1000 entries).
- Redis backend: uses Redis's native TTL; eviction policy is Redis's `allkeys-lru` recommendation (operator's Redis config).
- Cache hit/miss counters surface in logs ([ADR-029](ADR-029-logging-format-destinations.md)) and observability ([ADR-031](INDEX.md), Pinned).
- Single-station scope ([ADR-011](ADR-011-multi-station-scope.md)) — cache key has no tenant dimension.

## Out of scope

- SQLite-backed cache as a third backend — Phase 6+ if a use case surfaces.
- Manual invalidation endpoint — Phase 6+.
- Browser-side HTTP cache headers on api responses — Phase 2 sub-decision.
- AQI observation persistence — [ADR-013](ADR-013-aqi-handling.md) (different problem: persistent observation history, not request-response caching).
- Cache stampede / dogpile mitigation — Phase 2 implementation if hot keys are identified.

## References

- `cachetools.TTLCache`: https://cachetools.readthedocs.io/
- `redis-py`: https://redis.readthedocs.io/
- Related: [ADR-006](ADR-006-compliance-model.md), [ADR-013](ADR-013-aqi-handling.md), [ADR-029](ADR-029-logging-format-destinations.md), [ADR-038](ADR-038-data-provider-module-organization.md).
