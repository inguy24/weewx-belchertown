---
status: Accepted
date: 2026-04-30
deciders: shane
---

# ADR-005: Realtime supports both direct-read and MQTT subscriber modes

## Context

The dashboard needs live (~5s) updates of weewx loop packets. Two existing patterns in the wild:

1. **MQTT subscriber.** Many weewx skins (including Belchertown) subscribe to an MQTT broker over WebSocket Secure. Requires the user to run a broker (EMQX, Mosquitto). HA users typically have one already.
2. **Direct read.** Read loop packets directly from weewx's engine bus — no broker needed.

Some users (HA-integrated, advanced) prefer the broker model; some (simple home stations, novices) prefer no-broker. Forcing one excludes the other.

User intent (verbatim): "we were allowing both options for realtime architecture so that way if a more novice user wanted to use the direct-read they could, and more advanced users (that would require more independent configuration such as setting up an MQTT server) can utilize that."

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Direct-read only | Simplest install, no broker needed | Doesn't fit users already running MQTT for HA/automations; redundant pipe to maintain |
| MQTT subscriber only | Reuses existing broker for HA/advanced users | Forces broker install on novices; more moving parts |
| Both modes via config | Serves both audiences | Two code paths; more testing |

## Decision

`weewx-clearskies-realtime` supports both modes via configuration. Default mode is **`direct`** (clean install for new users). MQTT subscriber mode (**`mqtt`**) is opt-in for users with existing brokers.

**MQTT support ships as an optional install extra.** `paho-mqtt` is NOT a hard dependency — direct-mode users do not install it. Users who want MQTT subscriber mode install with the extras tag: `pip install weewx-clearskies-realtime[mqtt]`. This avoids the dep-size and license-housekeeping tax for the majority of users who only need direct mode.

Both modes feed the same internal SSE emitter, so the dashboard sees an identical event stream regardless of mode.

## Consequences

- Two input adapters in the realtime service. Selectable via config knob.
- Test matrix: both modes against a representative set of weewx versions.
- Docs explain both: "if you don't have an MQTT broker, ignore the MQTT section; if you have HA already, use the MQTT mode."
- HA users keep the existing weewx-mqtt → broker pipe untouched. The realtime service slots in as a new MQTT *subscriber* rather than displacing the existing publish chain.
  - Existing chain on the user's prod server: weewx-mqtt extension publishes every ~5s to EMQX broker on `cloud` container; documented in [reference/weather-skin.md](../../reference/weather-skin.md).
- Per [ADR-006](ADR-006-compliance-model.md), the user manages broker credentials themselves; the realtime service does not ship a default broker.

## Implementation guidance

### Config

```ini
[input]
mode = direct  # direct | mqtt

[input.direct]
# (no config needed — bound to the weewx engine process)

[input.mqtt]
broker_host = mqtt.example.local
broker_port = 8883
topic = weewx/loop
client_id = weewx-clearskies-realtime
username = weewx-web
password_env = WEEWX_CLEARSKIES_MQTT_PASSWORD  # from env, not the config file
tls = true
ca_file =                                       # optional
qos = 0
keepalive = 60
```

### Direct mode

- Imports weewx; registers a service hooking the engine's `NEW_LOOP_PACKET` event.
- Pushes each packet to an internal queue.
- Bound to the weewx process lifecycle — if weewx is down, this service can't deliver.

### MQTT mode

- Available only when the `[mqtt]` install extra is present. The MQTT input adapter imports `paho-mqtt` lazily; if the lib is absent and the user sets `mode = mqtt` in config, the service emits a clear error at startup pointing them to the correct install command.
- paho-mqtt client with auto-reconnect. Used under the EDL-1.0 license election per [ADR-003](ADR-003-license.md).
- Configurable broker URL, topic, QoS, TLS settings, credentials (credentials from env var only, never the config file).
- Subscribes to the configured topic. Pushes received messages to internal queue.
- Failure mode: broker down → log + retry with exponential backoff; the `/sse` endpoint stays up but emits no events until reconnection.

### SSE emitter

- Single internal queue → SSE endpoint (Starlette `EventSourceResponse`).
- One emitter; both inputs feed it through a common interface.
- Authentication on the SSE endpoint follows [ADR-008](ADR-008-auth-model.md) (auth model — Pinned).

### Test coverage

- Unit: each input adapter produces canonical events from sample inputs.
- Integration: end-to-end direct mode against a mock weewx engine; MQTT mode against a Mosquitto in CI.
- Resilience: broker disconnect/reconnect; weewx restart in direct mode.

## References

- Related ADRs: [ADR-001](ADR-001-component-breakdown.md) (component breakdown), [ADR-002](ADR-002-tech-stack.md) (tech stack), [ADR-006](ADR-006-compliance-model.md) (compliance), ADR-008 (auth — pinned)
- Server reference: [reference/weather-skin.md](../../reference/weather-skin.md) — existing MQTT chain (EMQX + weewx-mqtt + Apache WS-upgrade)
- Plan: [Coexistence section in CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md)
