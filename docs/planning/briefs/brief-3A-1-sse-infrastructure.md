# Brief: Round 3A-1 — SSE Infrastructure

**Date:** 2026-06-13
**Lead:** Opus (coordinator)
**Teammate:** api-dev (Sonnet)
**Phase:** 3A (SSE Infrastructure), tasks T3A.1 + T3A.2 + T3A.3

## Objective

Port the SSE emitter, direct adapter, packet tap registry, and ring buffer from `weewx-clearskies-realtime` into `weewx-clearskies-api`. Create a new `/sse` endpoint. Wire everything into the API's startup/shutdown sequence. Add `sse-starlette` dependency.

After this round, the API will:
- Accept Unix socket connections from weewx's ClearSkiesLoopRelay extension
- Receive loop packets via the direct adapter
- Fan them out to connected SSE clients via `GET /sse`
- Support keepalive (15s), subscriber overflow handling, auto-reconnect

## Scope

### Files to create

| Path | Source | Notes |
|------|--------|-------|
| `weewx_clearskies_api/sse/__init__.py` | New | Package init |
| `weewx_clearskies_api/sse/emitter.py` | Port from realtime `sse/emitter.py` (159 lines) | Adapt imports only |
| `weewx_clearskies_api/sse/direct_adapter.py` | Port from realtime `adapters/direct.py` (171 lines) | Adapt settings class reference |
| `weewx_clearskies_api/sse/ring_buffer.py` | Port from realtime `enrichment/ring_buffer.py` (102 lines) | Straight port, no changes |
| `weewx_clearskies_api/sse/packet_tap.py` | Port from realtime `enrichment/packet_tap.py` (60 lines) | Straight port, no changes |
| `weewx_clearskies_api/endpoints/sse.py` | New | SSE endpoint using sse-starlette |

### Files to modify

| Path | What changes |
|------|-------------|
| `pyproject.toml` | Add `sse-starlette>=2.0.0` to dependencies |
| `weewx_clearskies_api/config/settings.py` | Add `InputSettings` class and `input` field on `Settings` |
| `weewx_clearskies_api/__main__.py` | Create packet queue, emitter, adapter; wire into startup/shutdown |
| `weewx_clearskies_api/app.py` | Register SSE router |

### Files NOT to touch

- `tests/` — test-author owns these (Round 3A-5)
- Any enrichment processor (`enrichment/`) — Phase 3B
- Unit conversion module (`units/`) — Phase 3C
- Proxy code — Phase 3D
- Any existing endpoint file
- Health module — use existing health probe pattern, don't restructure

## Reading list

Read these files from the realtime repo before coding:

1. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/sse/emitter.py` — the source to port
2. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/adapters/direct.py` — the source to port
3. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/enrichment/packet_tap.py` — the source to port
4. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/enrichment/ring_buffer.py` — the source to port
5. `repos/weewx-clearskies-realtime/weewx_clearskies_realtime/__main__.py` — understand wiring order
6. `repos/weewx-clearskies-api/weewx_clearskies_api/__main__.py` — understand API startup sequence
7. `repos/weewx-clearskies-api/weewx_clearskies_api/app.py` — understand router registration
8. `repos/weewx-clearskies-api/weewx_clearskies_api/config/settings.py` — understand settings pattern
9. `repos/weewx-clearskies-api/pyproject.toml` — current dependencies

## Pre-round verification

- API repo: Clean, HEAD=`1840abb`, branch=`main`
- Realtime repo: Clean, HEAD=`a3f10f9`, branch=`main`
- No uncommitted changes in either repo

## Per-deliverable spec

### 1. SSE emitter (`sse/emitter.py`)

Port the `SSEEmitter` class from realtime. Key behavior to preserve:

- **Constructor:** `SSEEmitter(source: asyncio.Queue, *, on_packet: Callable | None = None)`
- **Fan-out pattern:** One source queue → N subscriber queues. The `_fanout()` background task reads from source, invokes `on_packet` callback (for enrichment pipeline, wired in Phase 3B), then copies packet to all subscriber queues.
- **Keepalive:** 15 seconds. The `event_generator()` yields keepalive comments (`:keepalive\n\n`) when no data arrives within the interval.
- **Overflow:** Subscriber queue max = 64 packets. On `QueueFull`, subscriber is silently dropped from the set (stalled client eviction).
- **Event format:** `event: loop`, `data: <JSON-serialized packet dict>`. This must match the existing realtime format exactly so the dashboard needs no changes.
- **Lifecycle:** `start()` schedules the fan-out task. `stop()` cancels the task and signals all subscribers with a `None` sentinel.

No changes to logic. Only adapt import paths.

### 2. Direct adapter (`sse/direct_adapter.py`)

Port the `DirectAdapter` class from realtime. Key behavior to preserve:

- **Constructor:** `DirectAdapter(settings: InputSettings, queue: asyncio.Queue)`
  - Change from realtime: accepts `InputSettings` (API's settings class) instead of `DirectSettings`
- **Unix socket client:** Connects to the socket at `settings.socket_path`, reads newline-terminated JSON lines, pushes parsed dicts to the queue.
- **Reconnection:** Exponential backoff from 1s to 120s max. Handles `FileNotFoundError` (weewx not running), `ConnectionResetError`, `ConnectionRefusedError`, `OSError`.
- **Health probe:** `health_probe() -> ProbeResult` — returns "ok" when connected, "warning" when disconnected. Import `ProbeResult` from the API's health module (check what the API uses — adapt if the API's probe interface differs).
- **Lifecycle:** `start(loop)` schedules the `_run()` background task. `stop()` signals stop_event and cancels task.
- **`connected` property:** Returns current connection status (bool).

Adapt: settings class reference, health probe import. Preserve all reconnection logic.

### 3. Ring buffer (`sse/ring_buffer.py`)

Straight port from realtime `enrichment/ring_buffer.py`. No changes needed. This is a self-contained utility used by enrichment processors (Phase 3B).

### 4. Packet tap registry (`sse/packet_tap.py`)

Straight port from realtime `enrichment/packet_tap.py`. No changes needed. Module-level `_processors` list. `register_processor()`, `clear_processors()`, `process_packet()`.

The enrichment processors will be registered in Phase 3B. For now, the registry exists but is empty — `process_packet()` is a no-op that does nothing when no processors are registered.

### 5. SSE endpoint (`endpoints/sse.py`)

Create a new FastAPI router with a `GET /sse` endpoint. Key requirements:

```python
from fastapi import APIRouter, Request
from sse_starlette.sse import EventSourceResponse

router = APIRouter()

@router.get("/sse")
async def sse_stream(request: Request):
    emitter: SSEEmitter = request.app.state.sse_emitter
    q = emitter.subscribe()
    try:
        return EventSourceResponse(emitter.event_generator(q))
    except Exception:
        emitter.unsubscribe(q)
        raise
```

- **Path:** `/sse` — NO `/api/v1` prefix. The dashboard connects to `/sse` via Caddy proxy.
- **SSE library:** Use `sse-starlette`'s `EventSourceResponse`.
- **The emitter's `event_generator()` already yields the correct SSE format** (`{"event": "loop", "data": "..."}`). The endpoint just wraps it in an EventSourceResponse.
- **Cleanup:** When the client disconnects, the EventSourceResponse's cleanup should unsubscribe the queue. Check if sse-starlette handles this via `on_close` callback, or if explicit cleanup is needed in a `finally` block.
- **No auth required** on `/sse` — this is a public endpoint (same as it was in the realtime service). Rate limiting applies at connection time (one HTTP request per SSE connection).

### 6. Settings addition (`config/settings.py`)

Add an `InputSettings` class following the existing pattern:

```python
class InputSettings:
    def __init__(self, section: dict[str, Any]) -> None:
        self.socket_path: str = str(section.get("socket_path", "/var/run/weewx-clearskies/loop.sock"))
        self.enabled: bool = _bool(section.get("enabled", "true"))

    def validate(self) -> None:
        pass  # socket_path is validated at connection time, not startup
```

- `enabled`: When `false`, the direct adapter and SSE emitter are not started. The API runs in REST-only mode. Default: `true`.
- `socket_path`: Path to the Unix domain socket where `ClearSkiesLoopRelay` pushes loop packets. Default: `/var/run/weewx-clearskies/loop.sock`.

Add `input: InputSettings` to the `Settings` class. Initialize from `cfg.get("input", {})`.

### 7. Startup wiring (`__main__.py`)

Add SSE infrastructure creation and lifecycle management. The wiring must happen in the "configured" code path (after the unconfigured early return at ~line 568).

**In `main()`:**
After app creation (line 551) and before `_run_server()` (line 774):

```python
# SSE infrastructure (ADR-058)
from weewx_clearskies_api.sse.packet_tap import process_packet
from weewx_clearskies_api.sse.emitter import SSEEmitter
from weewx_clearskies_api.sse.direct_adapter import DirectAdapter

packet_queue: asyncio.Queue = asyncio.Queue()
sse_emitter = SSEEmitter(packet_queue, on_packet=process_packet)
app.state.sse_emitter = sse_emitter

if settings.input.enabled:
    adapter = DirectAdapter(settings.input, packet_queue)
else:
    adapter = None
```

**Pass adapter and emitter to `_run_server()` and `_serve_all()`.**

**In `_serve_all()`:**
Before starting uvicorn servers:
```python
if adapter is not None:
    adapter.start(asyncio.get_running_loop())
sse_emitter.start()
```

In the shutdown sequence (after signaling servers to exit):
```python
sse_emitter.stop()
if adapter is not None:
    adapter.stop()
```

### 8. Router registration (`app.py`)

Register the SSE router in `create_app()`, in the configured-mode block alongside other routers:

```python
from weewx_clearskies_api.endpoints.sse import router as sse_router
app.include_router(sse_router)  # No prefix — endpoint is at /sse, not /api/v1/sse
```

**Important:** The SSE router must be registered WITHOUT the `/api/v1` prefix. The dashboard expects `/sse` at the root.

### 9. Dependency addition (`pyproject.toml`)

Add `sse-starlette>=2.0.0` to the dependencies list.

## Lead calls

1. **No MQTT code.** Do not port `adapters/mqtt.py`, `mqtt_fields.py`, or add `paho-mqtt`. MQTT is eliminated per ADR-058.
2. **Packet tap wired but empty.** The `on_packet=process_packet` callback is wired to the emitter, but no processors are registered yet. Phase 3B registers processors. This means SSE packets will be raw loop packets with no enrichment until 3B is complete.
3. **No enrichment registration in this round.** Do not port any enrichment processors. Do not import from `enrichment/`. Only the `packet_tap` registry (empty) and `ring_buffer` utility are ported.
4. **No unit conversion in this round.** SSE events will contain raw values (no conversion). Unit conversion is Phase 3C.
5. **Health probe integration:** Adapt the direct adapter's health probe to the API's health system. Check what `ProbeResult` class or pattern the API uses (look at `health.py` or the DB health probe for the interface). If the interface differs, adapt the adapter's probe to match.
6. **IPv4/IPv6:** The direct adapter connects to a Unix socket, so IP version is irrelevant. But if there's any bind logic, follow the API's existing dual-stack pattern.
7. **Endpoint path:** `/sse` at root, NOT `/api/v1/sse`.

## Open questions

None — all decisions are settled by ADR-058 and the plan.

## Verification

After implementation, the agent should:

1. `cd repos/weewx-clearskies-api && python -c "from weewx_clearskies_api.sse.emitter import SSEEmitter; print('emitter OK')"` — import check
2. `cd repos/weewx-clearskies-api && python -c "from weewx_clearskies_api.sse.direct_adapter import DirectAdapter; print('adapter OK')"` — import check
3. `cd repos/weewx-clearskies-api && python -c "from weewx_clearskies_api.sse.packet_tap import register_processor, process_packet; print('packet_tap OK')"` — import check
4. `cd repos/weewx-clearskies-api && python -c "from weewx_clearskies_api.sse.ring_buffer import RingBuffer; print('ring_buffer OK')"` — import check
5. `cd repos/weewx-clearskies-api && python -c "from weewx_clearskies_api.endpoints.sse import router; print('sse endpoint OK')"` — import check
6. Grep for "mqtt", "paho", "MQTT" in the API codebase — zero hits in new files
7. Commit all changes with a descriptive message

## Git restrictions

You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead or behind, STOP and report. Do not resolve it yourself.
