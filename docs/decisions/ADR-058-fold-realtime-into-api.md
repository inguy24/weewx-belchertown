---
status: Accepted
date: 2026-06-13
deciders: shane
supersedes: ADR-005
amends: ADR-041, ADR-034
---

# ADR-058: Fold realtime service into API — eliminate MQTT and separate process

## Context

The realtime service (`weewx-clearskies-realtime`) started as a lightweight SSE bridge (ADR-005) but grew into a 5,924-LOC BFF gateway (ADR-041) that proxies REST to the API, applies unit conversion (ADR-042), runs 12 enrichment processors, and computes derived values. It is now a substantial service that duplicates startup patterns, logging, health checks, and configuration loading with the API.

With co-location established (ADR-056) and the API reframed as the weewx application layer (ADR-057), there is no architectural reason for two separate processes. The realtime service sits between Caddy and the API, adding latency and operational complexity (two systemd units, two config files, two processes to monitor) for a role the API can absorb directly.

MQTT support exists because weewx never had an API — MQTT was the de facto way to get real-time data out. We're building that API. MQTT becomes redundant.

Phase 0 research confirmed feasibility:
- T0.1: Complete inventory of 41 files / 5,924 LOC. 12 enrichment processors, SSE emitter, direct adapter, unit conversion module, conditions text engine. 3 enrichments make HTTP calls back to the API (scene→almanac/forecast, barometer→archive, planet→seeing) that become internal function calls after merge.
- T0.2: API's 14-step startup has 5 natural insertion points. All 7 middleware layers are SSE-compatible. Only new dependency: `sse-starlette`.

## Options considered

| Option | Verdict |
|---|---|
| A. Merge realtime into API, eliminate MQTT | **Selected.** One process, one config, simpler topology. |
| B. Keep realtime as separate service | Rejected — two processes for one conceptual service; operational overhead. |
| C. Merge API into realtime | Rejected — API is the larger, more complex service; realtime merges into it. |

## Decision

The former realtime/BFF service is merged into the API. The API becomes a push/pull service: REST for queries, SSE for real-time. MQTT support is eliminated.

**What moves into the API (migration manifest from T0.1):**

| Module | LOC | Notes |
|---|---|---|
| SSE emitter (`sse/emitter.py`) | 131 | Fan-out queue broadcaster, 15s keepalive, 64-packet overflow |
| Direct adapter (`adapters/direct.py`) | 139 | Unix socket client, auto-reconnect with exponential backoff |
| Enrichment registry (`enrichment/packet_tap.py`) | 41 | Processor registration and invocation |
| 12 enrichment processors | ~1,500 | wind rolling window, lightning buffer, barometer trend, input smoother, UV smoother, sky tap/condition, scene enrichment, weather text, planet viewing, temperature comfort |
| Unit conversion (`units/`) | 785 | transformer, conversion, derived, groups, labels |
| Conditions text (`conditions_text.py`) | 185 | Weather text composer |
| Scene/sky/comfort modules | 715 | Module-level stateful classifiers |

**What gets deleted:**

| Item | Reason |
|---|---|
| MQTT adapter (`adapters/mqtt.py`) | MQTT eliminated |
| `paho-mqtt` dependency | MQTT eliminated |
| BFF proxy (`proxy.py`) | API serves directly, no proxy hop |
| MQTT field name stripper (`mqtt_fields.py`) | No MQTT field names to strip |
| `weewx-clearskies-realtime` repo | Deprecated (archived, not deleted) |
| `weewx-clearskies-realtime.service` | Systemd unit stopped and disabled |
| Port 8766, 8082 | Removed from port registry |

**What changes:**

- Scene enrichment's HTTP calls to `/api/v1/almanac` and `/api/v1/forecast` become internal function calls to the API's own service layer.
- Barometer trend's HTTP call to `/api/v1/archive` becomes an internal query.
- Planet viewing's HTTP calls become internal function calls.
- The `ClearSkiesLoopRelay` weewx extension (Unix socket server) stays as-is — the API is a new consumer of the same socket.
- ADR-041 computation boundary collapses: the API now does data access AND unit conversion. No separate conversion layer.

## Consequences

- **Supersedes ADR-005:** Direct + MQTT input modes replaced by direct-only within the API. MQTT is no longer supported.
- **Amends ADR-041:** The former BFF role is merged into the API. The computation boundary (API = raw data, former BFF = conversion) collapses — the API does both. The "test" from the ADR-041 amendment still applies: if a proposed endpoint requires domain-specific computation, it belongs in the enrichment pipeline, not as a raw data endpoint.
- **Amends ADR-034:** Topology simplifies. Container inventory loses `clearskies-realtime`. Port registry loses 8766 and 8082. Two-host default becomes: API on weewx host, dashboard + Caddy on front-end host.
- **Caddy routing changes:** `/api/v1/*` and `/sse` both route to the API (port 8765) instead of realtime (port 8766).
- **Single config file:** `realtime.conf` settings (unit conversion, SSE, direct adapter) fold into `api.conf`. One config file for one service.
- **SSE endpoint:** `GET /sse` on the API, same event format as before (`{"event": "loop", "data": "..."}`) — dashboard needs no changes.
- **Module-level state preserved:** 11 modules carry intentional process-level state (ring buffers, sky classifier, scene descriptor). Single-process API preserves this. Multi-worker deployment would need state sharing — out of scope for v0.1.
- **Operators using MQTT for other consumers** (HA, Node-RED) are unaffected — weewx's own MQTT extension is separate from our deleted MQTT adapter. Those operators can also subscribe to the API's SSE endpoint instead.

## Acceptance criteria

- [ ] API serves SSE at `GET /sse` with the same event format as the former realtime service
- [ ] All 12 enrichment processors run in the API (verified: SSE packets include wind rolling avg, scene, beaufort, conditions text, lightning history, etc.)
- [ ] Unit conversion applied to all REST responses and SSE events
- [ ] Direct adapter connects to Unix socket and auto-reconnects on weewx restart
- [ ] No MQTT code, no `paho-mqtt` dependency, no MQTT settings in the API
- [ ] No proxy code — API serves endpoints directly
- [ ] Caddy routes `/api/v1/*` and `/sse` to port 8765
- [ ] `realtime.service` stopped and disabled on weather-dev
- [ ] Dashboard loads with real-time updates working (SSE), all pages render
- [ ] Pre/post-migration endpoint responses match (same values for same input)
- [ ] ARCHITECTURE.md updated: no realtime service, no port 8766/8082
- [ ] ADR-005 status set to Superseded

## Implementation guidance

Phase 3 in the plan breaks the migration into 4 sub-phases:
- **3A — SSE infrastructure:** Port emitter, create `/sse` endpoint, port direct adapter, delete MQTT
- **3B — Enrichment pipeline:** Port packet tap registry, all 12 processors, wire into startup. Scene enrichment HTTP calls become internal function calls.
- **3C — Unit conversion:** Port unit conversion module, wire into response pipeline, port derived values (beaufort, comfort index)
- **3D — Cleanup:** Remove BFF proxy, update Caddy routing, update ADRs/ARCHITECTURE.md, update docker-compose, deprecate realtime repo, full integration test

Key files in the API to modify:
- `__main__.py` — SSE emitter creation (step 3e), direct adapter startup (step 8), enrichment registration (step 6c)
- `app.py` — new `/sse` router, enrichment registry wiring
- `pyproject.toml` — add `sse-starlette`
- `api.conf` — absorb `[input]`, `[units]`, `[sse]` sections from `realtime.conf`

## Out of scope

- Multi-worker SSE state sharing (v0.1 is single-worker)
- MQTT support for any consumer (weewx's own MQTT extension covers that)
- Replacing the `ClearSkiesLoopRelay` weewx extension with a different IPC mechanism (the Unix socket pattern works)

## References

- Supersedes: [ADR-005](ADR-005-realtime-architecture.md) (realtime direct + MQTT modes)
- Amends: [ADR-041](ADR-041-realtime-bff.md) (unit conversion and enrichment authority), [ADR-034](ADR-034-deployment-topology-default.md) (deployment topology)
- Related: [ADR-042](ADR-042-unit-system.md) (unit system), [ADR-056](ADR-056-api-weewx-co-location.md) (co-location), [ADR-057](ADR-057-api-weewx-application-layer.md) (application layer)
- Research: T0.1 findings (realtime inventory), T0.2 findings (API extensibility)
- Backlog: FIX-007
