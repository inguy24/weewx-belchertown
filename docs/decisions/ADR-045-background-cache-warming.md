---
status: Proposed
date: 2026-05-27
deciders: shane
supersedes:
superseded-by:
---

# ADR-045: Background cache warming

## Context

Records endpoint takes ~11 seconds for all-time queries against the weewx archive. Almanac sun-times and moon-phases are CPU-bound Skyfield computations. Belchertown pre-computed these via the weewx report engine on a scheduled interval; Clear Skies needs an equivalent mechanism.

Provider caching (ADR-017) handles external API responses with short TTLs (seconds to minutes). This is a different tier — pre-computing expensive *internal* queries (DB aggregates, Skyfield) on longer intervals (30 min to 24 hours).

## Options considered

| Option | Verdict |
|---|---|
| A. Background daemon thread (this ADR) | Selected — simple, single-process, reuses existing cache protocol |
| B. Celery / task queue | Rejected — heavy dependency for a single-station personal weather site |
| C. Cron job hitting endpoints externally | Rejected — requires auth bypass, no cache protocol reuse, fragile |
| D. Pre-compute at weewx report time (Belchertown model) | Rejected — couples to weewx engine; Clear Skies API is independent |

## Decision

A background daemon thread pre-computes slow endpoints on configurable intervals. Reuses ADR-017's `CacheBackend` protocol (memory or Redis). First refresh runs at startup. A cache miss falls through to a live query — graceful degradation, not a hard dependency.

### Caching policy

| Endpoint | Default interval | Key |
|---|---|---|
| Records (all-time) | 30 min | `records:all-time` |
| Records (YTD) | 30 min | `records:ytd` |
| Almanac sun-times (current year) | 6 hours | `almanac:sun-times:{year}` |
| Almanac moon-phases (current year) | 6 hours | `almanac:moon-phases:{year}` |
| AQI history | 30 min | `aqi:history` |
| Climatology monthly | 6 hours | `climatology:monthly` |
| Planets | 6 hours | `almanac:planets:{date}` |
| Eclipses | 24 hours | `almanac:eclipses` |
| Meteor showers | 24 hours | `almanac:meteor-showers:{year}` |

### Configuration

`[cache_warmer]` section in `api.conf`:

```ini
[cache_warmer]
enabled = true
records_interval_minutes = 30
almanac_interval_minutes = 360
aqi_interval_minutes = 30
climatology_interval_minutes = 360
astronomy_interval_minutes = 360
eclipses_interval_minutes = 1440
```

## Consequences

- Startup adds a few seconds for the first warm pass.
- Slow endpoints become instant for cached periods.
- Memory or Redis backend chosen by operator (same as ADR-017).
- Graceful degradation: cache miss falls through to live query — no user-visible error.

## Implementation guidance

- `services/cache_warmer.py` — daemon thread, configurable intervals per endpoint group.
- Reuse `CacheBackend` from `providers/_common/cache.py`.
- Thread starts in `app.py` lifespan; shutdown via `threading.Event` + `join`.
- Out of scope: cache invalidation API, partial refresh, per-section warming.

## References

- [ADR-017](ADR-017-provider-response-caching.md) — CacheBackend protocol and pluggable backends.
- [ADR-012](ADR-012-database-access-pattern.md) — DB access pattern (SQLAlchemy 2.x, read-only user).
