---
status: Accepted (amended 2026-06-14 — realtime service merged into API per ADR-058)
date: 2026-05-26
deciders: shane
amends: ADR-005
supersedes: ADR-019
amended-by: ADR-058
---

# ADR-041: Realtime service as unit conversion and enrichment authority (amended — merged into API per ADR-058)

## Context

The dashboard connects to two backends: the API (REST at `/api/v1/*` via Caddy) and the realtime service (SSE at `/sse`). Unit conversion needs to happen somewhere — splitting it between API and dashboard means two implementations and duplicated logic. MQTT field names arrived with unit suffixes (`outTemp_F`, `windSpeed_mph`) that needed stripping and conversion before the dashboard could use them.

The realtime service already sat on the front-end host and handled the SSE path. Adding REST proxying and unit conversion to it created a single gateway where all outbound data passed through one conversion layer.

ADR-034 places the API on the weewx host (internal network). At the time of this decision, Caddy proxied `/api/v1/*` directly to the API. Moving that proxy responsibility into the realtime service meant the API was no longer directly browser-accessible — the realtime service mediated all dashboard traffic.

> **Historical note:** The realtime service in this role was called "BFF" (Backend-for-Frontend) in earlier documentation. It has since been merged into the API per ADR-058. The sections below describe the original decision as written; amendment notes at the bottom record what changed.

## Options considered (original)

| Option | Verdict |
|---|---|
| A. Realtime as gateway — proxy + unit conversion + SSE | **Selected (originally).** One gateway, one conversion layer. |
| B. Unit conversion in API | Wrong service — API is already complex (30+ endpoints, providers). Doesn't solve MQTT suffix problem. |
| C. Unit conversion in dashboard (client-side) | Duplicates logic for REST and SSE. Every component needs unit knowledge. Can't compute Beaufort/comfort index without thresholds. |
| D. New standalone gateway service | New service to maintain. Realtime already occupies the right topology position. |

## Decision (original)

Originally, the realtime service (`weewx-clearskies-realtime`) was designated as the dashboard's single backend gateway. It:

1. **Proxied REST requests** to the upstream API on the weewx host (catch-all `/api/v1/*` forward, not route-by-route).
2. **Served SSE** from MQTT/direct input (unchanged from ADR-005).
3. **Applied unit conversion** to ALL outbound data — both proxied REST responses and SSE events passed through the same conversion layer.

**Amended ADR-005:** Added gateway responsibility (proxy + unit conversion). Input mode decision (direct vs MQTT) was unchanged.

**Superseded ADR-019:** "No server-side conversion" became "API converts to operator display units." The API itself originally passed raw archive values to the realtime service — the API did no conversion.

## Consequences (original)

- **Caddy routing changes:** `/api/v1/*` routed to the realtime service (`realtime:8766`) instead of directly
  to the API. `/sse` routing unchanged. **As-built (stack commit 4334475):** all three Caddyfiles
  (`frontend-host/Caddyfile`, `single-host/Caddyfile`, `examples/reverse-proxy/Caddyfile`) routed
  `/api/v1/*` to `realtime:8766` (or `localhost:8766` in the native/pip example). The dashboard
  had one connection point; no direct browser→API traffic. ADR-034 topology satisfied.
- **Service growth:** Realtime grew from ~1,200 LOC (pre-gateway) to **~5,000 LOC** of
  production code (src only, excluding tests). As-built included: proxy, units module
  (groups/conversion/labels/transformer/derived), MQTT fields, sky condition, conditions text,
  temperature comfort, enrichment pipeline (input smoother, ring buffer, barometer trend,
  weather text, sky tap), and direct/MQTT adapters. Still a single-purpose service
  (dashboard gateway), not a monolith.
- **New dependency:** `httpx` for upstream API communication.
- **Proxy was optional:** When `[api] upstream_url` was absent (or left empty), the realtime service started
  without a proxy client. Requests to `/api/v1/*` returned **HTTP 503** `{"error": "API proxy not
  configured"}`. SSE and health endpoints were unaffected.
- **Health probes:** Included upstream API connectivity check alongside existing MQTT/adapter status.
- **Latency:** One extra network hop for REST (realtime → API over LAN). Negligible for weather data.
- **Availability:** Realtime service down = both REST and SSE unavailable. Same risk profile as any reverse proxy.

## Implementation guidance (original)

### Config sections in `realtime.conf` (historical — superseded by `api.conf`)

```ini
[api]
upstream_url = https://weewx-host:8765
timeout = 30
tls_verify = false
```

### New files (as-built in the realtime repo, now merged into API)

- `proxy.py` — httpx async client, catch-all `/api/v1/{path:path}` route, forwards request and applies unit conversion to JSON responses.
- `units/` module — see ADR-042.
- `mqtt_fields.py` — suffix detection and stripping, see ADR-042.

### Modified files

- `app.py` — mount proxy routes, wire unit conversion to both proxy responses and SSE events.
- `config/settings.py` — add `[api]` and `[units]` config sections.
- `health.py` — add upstream API connectivity probe to readiness check.

### Caddy routing — as-built (pre-ADR-058)

All three shipped Caddyfiles routed `/api/v1/*` to the realtime service at port 8766:

```
handle /api/v1/* {
    reverse_proxy realtime:8766   # frontend-host and single-host (Docker)
}
reverse_proxy /api/v1/* localhost:8766   # examples/reverse-proxy (native/pip)
```

The "Before (current)" stanza showing a direct API route no longer applies; it is
retained only as historical context in git history (pre-stack-4334475).

### Out of scope

- Wizard changes (Phase 5 of the plan). _(unchanged — the wizard does not yet surface
  `[api] upstream_url` in its config-writer flow.)_

## Amendment: computation boundaries (2026-06-05)

**Motivation:** Phase 4 of the configurable charts system (June 2026) added a `/charts/wind-rose` endpoint to the API that performed Beaufort classification and direction binning — duplicating the existing `beaufort` injection in `UnitTransformer.transform_record()` and violating this ADR's boundary ("the API itself does no conversion") and ADR-042 line 71 ("Beaufort scale: API computes from wind speed … Dashboard does not carry Beaufort thresholds").

**Computation boundary rules (updated for ADR-058 merger):**

Within the API, two distinct layers exist:

1. **API data endpoints (ADR-010).** Query the weewx archive and serve raw observation/aggregate values. No awareness of chart types, visualization layouts, or rendering concerns. No chart-specific endpoint belongs here.
2. **API enrichment pipeline (this ADR + ADR-042).** Unit conversion, derived-value computation (Beaufort, comfort index, barometer trend, cardinal directions), and enrichment (conditions text). This is where raw archive values become display-ready data. Runs as post-processing on endpoint responses, not inside the endpoint handlers themselves.
3. **Dashboard = rendering + presentation-level computation.** Client-side binning (e.g., direction × Beaufort matrix for wind rose), LTTB downsampling, chart layout, and theming. The dashboard reads API-provided derived fields (like `beaufort.value`) but does not recompute them from raw observations.

**Test:** If a proposed endpoint handler requires unit conversion, threshold classification, or produces output shaped for a specific chart type — it belongs in the enrichment pipeline or dashboard, not in the endpoint handler.

**Corrective action:** `/charts/wind-rose` deleted from the API. Direction × Beaufort binning moved to a dashboard utility (`wind-rose-binning.ts`) that reads the API-injected `beaufort` field from archive records. See [ARCHITECTURE.md Layer Responsibilities](../ARCHITECTURE.md#layer-responsibilities).

## Amendment: former realtime service merged into API (ADR-058, 2026-06-14)

Amended 2026-06-14: The former realtime service (which served as the unit conversion and enrichment gateway described in this ADR) has been merged into the API per [ADR-058](ADR-058-fold-realtime-into-api.md). The computation boundary (raw data vs. conversion) no longer exists as a service boundary — unit conversion, derived values, and enrichment now happen within the API. The principle still holds: observation data passes through the unit conversion pipeline before reaching the client.

The `weewx-clearskies-realtime` repo is deprecated (archived, not deleted). Port 8766 and 8082 are removed from the port registry. All Caddy routing that previously pointed to the former realtime service at port 8766 now routes directly to the API at port 8765. The `[api] upstream_url` config section in `realtime.conf` is superseded — there is no proxy and therefore no upstream URL to configure.

The test from the computation boundary amendment (2026-06-05) still applies in its updated form: if a proposed API endpoint requires domain-specific computation, it belongs in the enrichment pipeline within the API, not as a raw data endpoint.

## References

- Amends: [ADR-005](ADR-005-realtime-architecture.md) (realtime architecture)
- Supersedes: [ADR-019](ADR-019-units-handling.md) (units handling — no server-side conversion)
- Amended by: [ADR-058](ADR-058-fold-realtime-into-api.md) (fold realtime into API)
- Related: [ADR-034](ADR-034-deployment-topology-default.md) (deployment topology), [ADR-037](ADR-037-inbound-traffic-architecture.md) (inbound traffic)
- Research: [brief-realtime-audit.md](../planning/briefs/brief-realtime-audit.md), [brief-mqtt-field-names.md](../planning/briefs/brief-mqtt-field-names.md)
