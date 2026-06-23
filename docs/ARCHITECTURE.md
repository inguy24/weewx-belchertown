# Clear Skies — System Architecture

Single source of truth for what each service is, where it runs, what it exposes, and how traffic flows. **Read this before any architecture work. Update it after any architecture change.**

Authoritative for current system state. ADRs are authoritative for *why* decisions were made. If this document conflicts with an ADR, investigate — one of them is stale.

Last verified: 2026-06-23 (ADR-072: added weewx-clearskies-truesun extension, McClear bootstrap, pvlib dependency; ADR-073: Kv-first sky classification replaces CAELUS Km-first tree).

---

## Vocabulary — canonical component names

One name per component. Code class names (`DirectAdapter`, `UnitTransformer`, `ClearSkiesLoopRelay`) appear only in code and code-adjacent docs. Everywhere else, use the canonical name. Banned terms may appear in historical context (archived docs, "Historical note" callouts) but must not be used as if the component still exists or still goes by that name.

| Canonical name | What it is | Repo | Banned terms |
|---|---|---|---|
| **API** | Backend service — REST endpoints, SSE stream, unit conversion, enrichment pipeline, derived values. The single backend for the dashboard. | `weewx-clearskies-api` | ~~BFF~~, ~~Backend-for-Frontend~~, ~~realtime service~~, ~~realtime/BFF~~, ~~BFF gateway~~, ~~backend gateway~~, ~~dashboard gateway~~ |
| **Dashboard** | React SPA — the weather UI that site visitors see. | `weewx-clearskies-dashboard` | ~~frontend~~ (ambiguous with front-end host) |
| **Loop relay** | weewx extension that relays loop packets to a Unix socket for the API to read. Code class: `ClearSkiesLoopRelay`. | `weewx-clearskies-extension` | ~~the extension~~ (too vague when other extensions exist) |
| **Socket reader** | Component inside the API that connects to the loop relay's Unix socket and reads packets. Code class: `DirectAdapter`. | (part of API) | ~~DirectAdapter~~ as a component name, ~~API DirectAdapter~~ |
| **Config UI** | Setup wizard + ongoing admin interface. Contains the **wizard** (multi-step first-run flow; steps defined by `templates/wizard/step_*.html` in the stack repo) and the **admin** (ongoing config management). | `weewx-clearskies-stack` | ~~config wizard~~, ~~wizard~~ when meaning the whole config UI |
| **Caddy** | Reverse proxy, TLS termination, static file server — entry point for all browser traffic. | upstream `caddy:2-alpine` | ~~web server~~ as a proper name |
| **Enrichment pipeline** | Processors inside the API that add derived values (Beaufort, comfort index, conditions text, barometer trend, wind averages) to data before it reaches the dashboard. | (part of API) | ~~enrichment modules~~, ~~BFF enrichment~~ |
| **Unit converter** | Component inside the API that transforms raw observation values to operator display units. Code class: `UnitTransformer`. | (part of API) | ~~conversion layer~~, ~~BFF conversion~~ |
| **weewx host** | Server running the weewx engine, the API, and Redis. | — | ~~API host~~ |
| **Front-end host** | Server running Caddy, dashboard static files, and optionally the config UI. Always hyphenated. | — | ~~frontend host~~ (no hyphen) |
| **TrueSun XType** | weewx extension that overrides `maxSolarRad` with pvlib Simplified Solis + CAMS AOD + station humidity-derived precipitable water. Registered as an XType before `StdWXXTypes`. Code class: `ClearSkiesTruesunXType`. | `weewx-clearskies-truesun` | ~~the truesun extension~~ (use the canonical name) |
| **Operator** | Person who installs, configures, and maintains Clear Skies. | — | ~~site owner~~ |
| **Visitor** | Person viewing the weather dashboard in a browser. | — | ~~user~~ alone (ambiguous), ~~end user~~ when meaning visitor |

Previous: 2026-06-08 (sky condition thresholds corrected for sensor accuracy, day/night display vocabulary added, Known gap #8 resolved).

---

## Services

| Service | Repo | What it does | Technology | Main port | Health port |
|---------|------|-------------|------------|-----------|-------------|
| **API** | weewx-clearskies-api | REST API + SSE for real-time data, unit conversion, enrichment pipeline, derived values. Queries weewx archive, aggregates provider data, serves setup endpoints. (ADR-058) | FastAPI (Python 3.12+), sync handlers, SQLAlchemy 2.x sync, sse-starlette, uvicorn | 8765 | 8081 |
| **Dashboard** | weewx-clearskies-dashboard | Weather UI (static SPA, 9 pages + custom pages) | React 19, Vite 8, Tailwind CSS v4, shadcn/ui, Recharts, Leaflet, **Phosphor** (utility/nav/alert) + **inline Material Symbols SVG** (hero weather, ADR-049/050); Lucide retained for deferred glyph families only, i18next | None (init container) | — |
| **Config UI** | weewx-clearskies-stack | Setup wizard + ongoing config admin | FastAPI, Jinja2, HTMX, Pico CSS (Python-only, no Node build step) | 9876 | — |
| **Caddy** | upstream (caddy:2-alpine) | Reverse proxy, TLS termination (auto Let's Encrypt), static file server | Caddy | 80, 443 | — |
| **Redis** | upstream (redis:7-alpine) | Cache for provider API responses (TTLs: forecast 30 min, alerts 5 min, AQI 15 min) | Redis 7.0.15 | 6379 | — |
| **Design Tokens** | weewx-clearskies-design-tokens | Tailwind config + design variables npm package | Phase 6+ placeholder — no code yet. Tokens currently live in dashboard repo. | — | — |

## Layer Responsibilities

Computation boundaries between the three application layers. **No chart-specific or visualization-specific endpoint in the API.** The API is a general-purpose data access layer (ADR-010); chart-type awareness belongs in the dashboard.

| Layer | Responsibility | Does NOT do |
|-------|---------------|-------------|
| **API** | General-purpose data access AND transformation: query the weewx archive, serve raw observation/aggregate values, host provider modules, expose setup endpoints. Unit conversion, derived-value computation (Beaufort scale, comfort index, barometer trend direction, cardinal wind directions). Enrichment pipeline (conditions text, weather text, barometer trend, wind rolling window averages, scene descriptor). SSE streaming at `GET /sse`. Single conversion authority (ADR-042, ADR-058). | Chart-specific binning or aggregation, presentation formatting, chart-type awareness, UI control plane (page visibility, card layout — these are static config served by Caddy, not API concerns). |
| **Dashboard** | Rendering + presentation-level computation: display converted values, client-side binning for visualizations (e.g., wind rose direction×Beaufort matrix from API-provided fields), LTTB downsampling, chart layout, theming, accessibility. Page visibility filtering from `pages.json`. Dynamic Now page card rendering from `now-layout.json` and the card plugin registry (ADR-064). | Unit conversion, Beaufort/comfort-index threshold logic, raw SQL queries, provider API calls. (ADR-042: "Dashboard does not carry Beaufort thresholds.") |

**Why the computation boundary matters (ADR-041 amendment 2026-06-05, updated for ADR-058):** The API is the single conversion and enrichment authority. Chart-type-specific logic (binning, aggregation for a specific visualization) belongs in the dashboard. A proposed API endpoint that requires domain-specific computation — Beaufort classification, comfort index, conditions text — belongs in the API's enrichment pipeline, not as a raw data endpoint. The dashboard reads API-provided derived fields (like `beaufort.value`) but does not recompute them from raw observations.

## Authoritative port registry

**These ports are locked. Do not use different ports without explicit user approval and an update to this table.**

| Port | Protocol | Service | Host | Binding | Notes |
|------|----------|---------|------|---------|-------|
| **80** | TCP | Caddy | front-end host | `0.0.0.0` | HTTP → public. Docker publishes as `80:80`. |
| **443** | TCP+UDP | Caddy | front-end host | `0.0.0.0` | HTTPS + HTTP/3 → public. Docker publishes as `443:443` and `443:443/udp`. |
| **8765** | TCP | API | weewx host | `0.0.0.0` | TLS always. Serves `/api/v1/*` and `/sse` (SSE stream). Caddy proxies both paths here. |
| **8081** | TCP | API health | weewx host | `127.0.0.1` | `/health/live`, `/health/ready`, `/metrics`. Loopback only. |
| **9876** | TCP | Config UI | front-end host | Docker network | Wizard + admin. Caddy proxies `/wizard`, `/bootstrap`, `/login`, `/admin`, `/static` here. Not exposed to host. |
| **6379** | TCP | Redis | weewx host | `127.0.0.1` | Cache (active). Loopback only. CLEARSKIES_CACHE_URL=redis://localhost:6379/0 in secrets.env. |

> **Removed ports (ADR-058, 2026-06-14):** Port 8766 (Realtime BFF main) and 8082 (Realtime BFF health) are eliminated. The realtime service has been merged into the API. Port 1883 (MQTT broker) is removed — MQTT input mode is eliminated per ADR-058.

## Container inventory

Each repo builds its own container image independently (ADR-034). A dashboard CSS tweak does not rebuild the API.

| Container | Image source | Lifecycle | Runs on (two-host default) |
|-----------|-------------|-----------|---------------------------|
| `api` | `weewx-clearskies-api/Dockerfile` | Long-running. TLS always enabled (Ed25519 self-signed by default). Serves `/api/v1/*` and `/sse`. | weewx host |
| `dashboard` | `weewx-clearskies-dashboard/Dockerfile` | **Init container** — multi-stage Node 22 build, copies `dist/` to `/dist` volume, exits | front-end host |
| `caddy` | `caddy:2-alpine` | Long-running | front-end host |
| `redis` | `redis:7-alpine` | Long-running | weewx host |

> **Removed container (ADR-058, 2026-06-14):** `clearskies-realtime` is deprecated. The realtime service has been merged into the API (`clearskies-api`). The `weewx-clearskies-realtime` repo is archived.

> **ClearSkiesLoopRelay weewx extension** (`weewx-clearskies-extension`) is NOT a container. It is a weewx service extension that runs inside the weewx process, installed via `weectl extension install`. It creates the Unix socket at `/var/run/weewx-clearskies/loop.sock` that the API's DirectAdapter connects to. See [ADR-058](decisions/ADR-058-fold-realtime-into-api.md) and [ADR-061](decisions/ADR-061-filesystem-permissions-model.md).
>
> **ClearSkiesTruesunXType weewx extension** (`weewx-clearskies-truesun`) is NOT a container. It is a weewx XType extension that runs inside the weewx process, installed via `weectl extension install`. It overrides `maxSolarRad` with pvlib's Simplified Solis model using CAMS AOD satellite data and station humidity-derived precipitable water. A background thread fetches CAMS AOD once daily; the main loop does only pure math with cached values. When this extension is not installed, weewx falls back to its built-in Ryan-Stolzenbach model (no regression). See [ADR-072](decisions/ADR-072-solar-radiation-model-replacement.md). Dependencies: `pvlib`, `cdsapi`, `h5netcdf` (installed into the weewx Python environment).

> **Config UI is NOT containerized.** It has no Dockerfile and is not in any compose file. It is distributed as a pip package (`weewx-clearskies-config`) and run manually by the operator. ADR-027 says "bundled compose adds a `config` service" — this is an unimplemented requirement. See Known gaps.

> **API native install (2026-05-24):** The API is currently installed natively on the `weewx` LXD container (not in Docker) via pip into a Python 3.12 venv at `/home/ubuntu/repos/weewx-clearskies-api/.venv`, managed by systemd unit `weewx-clearskies-api.service`. Config at `/etc/weewx-clearskies/api.conf`. Health port (8081) also serves TLS. This is the production deployment path on bare-metal / LXD; the Dockerfile exists for Docker compose deployments.
>
> **API startup time: ~2 minutes.** After `systemctl restart weewx-clearskies-api`, the service runs a cache warmer that makes outbound API calls to configured providers (Aeris, NWS, etc.) before uvicorn binds to port 8765. The service is not ready to serve requests until the cache warm completes. When scripting restarts, wait at least 120 seconds before hitting endpoints — `sleep 10` is not enough.

> **Native dashboard / dev deploy (2026-05-29):** On the `weather-dev` LXD container the dashboard is NOT run as a Docker init container. Instead the source is pulled to `/home/ubuntu/repos/weewx-clearskies-dashboard`, built natively with `npm run build` (Vite → `dist/`), and the built `dist/` is rsync'd into the Caddy web root `/var/www/clearskies/` (excluding the read-only `webcam/` bind-mount and the `cards/` directory). API and Config UI run as systemd units (`weewx-clearskies-{api,config}.service`). The full redeploy is automated by `scripts/redeploy-weather-dev.sh`; source-only refresh by `scripts/sync-to-weather-dev.sh`. Procedure: [procedures/deploy-clearskies.md](procedures/deploy-clearskies.md). The Docker init-container model above is the compose deployment path.
>
> **Cards directory (v2 prep, ADR-064):** `/var/www/clearskies/cards/` is reserved for third-party card assets (v2 scope). The redeploy script excludes this directory from rsync (`--exclude cards/`), same isolation pattern as `webcam/`. Empty until v2 adds the card import mechanism. Caddy serves `/cards/*` from this directory.

## Default topology: two-host split (ADR-034, amended ADR-058)

```
weewx host                          front-end host
+-----------------------+           +----------------------------------+
| api :8765 (TLS)       |           | caddy :80/:443                   |
|   health :8081 (lo)   |  network  |   serves dashboard static files  |
|   reads weewx.conf    |<--------->|   proxies /api/v1/* to API :8765 |
|   reads weewx archive |           |   proxies /sse to API :8765      |
|   serves /api/v1/*    |           |                                  |
|   serves /sse (SSE)   |           | dashboard (init)                 |
|   serves /setup/*     |           |   builds SPA, copies to volume   |
|   unit conversion     |           +----------------------------------+
|   enrichment pipeline |
|   derived values      |
|                       |
| redis :6379 (optional)|
|   loopback only       |
+-----------------------+
```

**Single-host alternative:** All services on one machine. Caddy proxies to local Docker network name `api:8765` for both `/api/v1/*` and `/sse`. API uses direct mode (Unix socket to weewx engine).

## Caddy routing

All three Caddyfile variants (frontend-host, single-host, examples/reverse-proxy) route both `/api/v1/*` and `/sse` directly to the API at port 8765. There is no intermediate proxy — the API serves both REST and SSE directly (ADR-058).

| Path pattern | Destination | What it serves |
|-------------|-------------|----------------|
| `/api/v1/*` | `api:8765` — API serves directly, applies unit conversion | Weather data JSON endpoints (unit-converted by API) |
| `/sse` | `api:8765` — API serves SSE stream directly | Server-Sent Events stream (unit-converted by API) |
| `/wizard*` | `config:9876` (local Docker network) | Setup wizard |
| `/bootstrap*` | `config:9876` | First-run admin credential setup |
| `/login*`, `/logout*` | `config:9876` | Admin auth |
| `/admin*` | `config:9876` | Ongoing config management |
| `/branding.json` | `file_server` from `/etc/weewx-clearskies/` | Operator branding config (accent, logos, theme, social, analytics) |
| `/webcam.json` | `file_server` from `/etc/weewx-clearskies/` | Webcam config JSON (safe from rsync --delete; lives outside web root) |
| `/pages.json` | `file_server` from `/etc/weewx-clearskies/` | Page visibility config. `Cache-Control: no-cache`. Dashboard reads at boot to filter nav + routes. (ADR-024 amendment 2026-06-21) |
| `/now-layout.json` | `file_server` from `/etc/weewx-clearskies/` | Now page card layout config. `Cache-Control: no-cache`. Dashboard reads at boot; falls back to compiled-in default on 404. (ADR-065) |
| `/card-manifest.json` | `file_server` from `/srv/dashboard` (build output) | Build-time card metadata manifest. Read by the admin card layout editor. Not operator-editable. |
| `/webcam/*` | `file_server` from `/var/www/clearskies/webcam/` | Live webcam still + timelapse. No `try_files` — returns 404 for missing files. |
| `/cards/*` | `file_server` from `/var/www/clearskies/cards/` | v2: third-party card assets. Directory excluded from redeploy rsync. Empty until v2. |
| `/static/*` | `config:9876` | Config UI static assets (CSS, JS) |
| `/*` (fallback) | `/srv/dashboard` static files (shared volume from init container) | React SPA with `try_files` fallback to `index.html` |

Security headers on all responses: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Server` header removed.

**API address per topology** (set in Caddyfile — points to port 8765):

| Topology | API address in Caddyfile | Notes |
|----------|--------------------------|-------|
| frontend-host (compose) | `https://<weewx-host-address>:8765` | API is on the remote weewx host |
| single-host (compose) | `https://api:8765` | Docker network service name |
| native / reverse-proxy | `https://localhost:8765` | Both services are on the same host |

`tls_verify = false` applies in the single-host and native/reverse-proxy cases when the API uses its default self-signed certificate. For the two-host frontend-host topology, use `tls { ca_pool /etc/weewx-clearskies/api-cert.pem }` instead — disabling TLS verification is not acceptable when Caddy and the API communicate over a non-loopback network. See OPERATIONS-MANUAL.md §12.

> **Removed (ADR-058, 2026-06-14):** The `[api] upstream_url` config section in `realtime.conf` is eliminated. There is no intermediate proxy — the API serves all endpoints directly. Caddy routes to the API; no intermediate service.

## Webcam

The webcam feature is a UI concern. The API has no webcam knowledge.

### File serving

An external capture process writes two files to the weewx LXD container at `/var/www/weewx/webcam/`:

- `weather_cam.jpg` — live still image
- `weewx_timelapse.mp4` — timelapse video

An LXD disk device mounts the host path `/mnt/weewx/webcam` read-only into the `weather-dev` container at `/var/www/clearskies/webcam/`. Caddy serves the `/webcam/*` path via `file_server` from that directory with no `try_files` fallback — a request for a missing file returns 404 immediately.

### Configuration flow

The setup wizard (stack repo) collects webcam settings: enabled flag, image URL, video URL, and refresh interval. On apply (`/wizard/apply`), the wizard writes two outputs:

| Output | Path | Purpose |
|--------|------|---------|
| `webcam.json` | `/etc/weewx-clearskies/webcam.json` | Static JSON fetched directly by the dashboard; contains `enabled`, `imageUrl`, `videoUrl`, `refreshInterval`. Served by Caddy at `/webcam.json` from `/etc/weewx-clearskies/` — outside the web root so dashboard rsync --delete cannot remove it. |
| `[webcam]` section | `stack.conf` | Persists settings so the wizard can pre-fill them on re-run |

The dashboard fetches `/webcam.json` on the Now page. If `enabled` is true, it renders the webcam card. If the fetch fails or `enabled` is false, the card is hidden gracefully — no error state surfaced to the user.

### Data flow

```
External capture process
  → /mnt/weewx/webcam/ (host path on weewx container)
  → LXD disk device (read-only mount)
  → /var/www/clearskies/webcam/ (weather-dev container)
  → Caddy file_server (/webcam/*)
  → browser

Wizard step 7 (apply)
  → /etc/weewx-clearskies/webcam.json  (dashboard config; safe from rsync)
  → stack.conf [webcam]                (wizard re-run pre-fill)
  → Caddy /webcam.json route → file_server from /etc/weewx-clearskies/
  → Dashboard fetches /webcam.json on Now page load
  → renders webcam card if enabled, hides gracefully on error
```

## API endpoints

### Endpoint categories

The API exposes endpoints across four categories, each on a different port or URL prefix. The **OpenAPI spec** at `/api/v1/openapi.json` (Swagger UI at `/api/v1/docs`, ReDoc at `/api/v1/redoc`) is the authoritative inventory for data endpoints — it is auto-generated by FastAPI from route decorators and always complete by construction. This document describes the categories and stable operational surfaces; it does not maintain a competing hand-written endpoint list.

| Category | Port | Prefix | Authoritative source | Purpose |
|----------|------|--------|---------------------|---------|
| **Data endpoints** | 8765 | `/api/v1/*` | OpenAPI spec (`/api/v1/openapi.json`) | Weather data, forecasts, alerts, AQI, earthquakes, almanac, charts, radar, reports, pages, branding, capabilities |
| **SSE endpoint** | 8765 | `/sse` | This document | Real-time loop-packet stream (named event type `"loop"`) |
| **Setup endpoints** | 8765 | `/setup/*` | This document | Config UI wizard-to-API channel (no `/api/v1` prefix) |
| **Health endpoints** | 8081 | `/health/*`, `/metrics` | This document | Liveness, readiness, Prometheus metrics (loopback only) |

### Data endpoints — representative examples

The OpenAPI spec lists 35+ data endpoints. Key groups for orientation:

| Group | Representative endpoints | Notes |
|-------|------------------------|-------|
| Core observation | `/api/v1/current`, `/api/v1/archive`, `/api/v1/archive/grouped`, `/api/v1/station` | `/current` includes enrichment pipeline output (`weatherText`, `beaufort`, `comfortIndex`). `/archive` supports `aggregate_interval`, `agg_map`, `sumcumulative`. `/archive/grouped` replaces the former `/climatology/monthly` endpoint. |
| Forecast & alerts | `/api/v1/forecast`, `/api/v1/alerts`, `/api/v1/aqi/current`, `/api/v1/aqi/history` | Provider-backed; single source per deploy per domain. |
| Almanac | `/api/v1/almanac`, `/api/v1/almanac/sun-times`, `/api/v1/almanac/moon-phases`, `/api/v1/almanac/seeing-forecast`, `/api/v1/almanac/planets`, `/api/v1/almanac/moon-names`, `/api/v1/almanac/eclipses/lunar`, `/api/v1/almanac/eclipses/solar`, `/api/v1/almanac/meteor-showers`, `/api/v1/almanac/positions` | Skyfield-based; background cache warming for expensive computations. |
| Earthquakes | `/api/v1/earthquakes`, `/api/v1/earthquakes/config`, `/api/v1/earthquakes/faults` | `/faults` serves GEM Active Faults GeoJSON radius-clipped. `/config` returns provider configuration. |
| Charts | `/api/v1/charts/config`, `/api/v1/charts/groups`, `/api/v1/charts/custom-query/{series_id}` | Config-driven; custom SQL from `charts.conf` only (disk-only trust model). |
| Radar | `/api/v1/radar/providers/{id}/frames`, `/api/v1/radar/providers/{id}/tiles/{z}/{x}/{y}` | Keyed providers proxied server-side; keys never reach browser. |
| Content & nav | `/api/v1/pages`, `/api/v1/pages/{slug}/content`, `/api/v1/reports`, `/api/v1/content/about`, `/api/v1/content/legal` | `/pages` returns all 9 built-in pages unconditionally — page visibility filtering is the dashboard's responsibility via `pages.json` (ADR-024 amendment 2026-06-21). |
| Infrastructure | `/api/v1/status`, `/api/v1/capabilities`, `/api/v1/records` | `/status` returns `{configured: bool}` — works in both setup and configured modes. |

### SSE endpoint (merged from realtime service per ADR-058)

| Port | Path | Purpose |
|------|------|---------|
| 8765 | `GET /sse` | Server-Sent Events stream — events with `type: "loop"`, data = unit-converted JSON. 15-second keepalive comments. Caddy proxies `/sse` to this endpoint. |

### Setup endpoints (under `/setup`, NO `/api/v1` prefix)

Used by the config UI wizard per ADR-038. Not proxied through Caddy — config UI connects directly to API.

| Path | Method | Purpose | Auth |
|------|--------|---------|------|
| `/setup/handshake` | POST | Exchange trust token for session | Trust token |
| `/setup/db-defaults` | GET | DB connection from `weewx.conf` | Session |
| `/setup/db-test` | POST | Test DB connection | Session |
| `/setup/schema` | GET | Column schema from DB | Session |
| `/setup/station` | GET | Station identity from `weewx.conf` | Session |
| `/setup/apply` | POST | Write final config, API restarts | Session |
| `/setup/current-config` | GET | Full config for re-run | Proxy secret |
| `/setup/restart` | POST | Trigger graceful service restart | Proxy secret |
| `/setup/calibration-state` | GET | Per-month calibration data for admin UI | Proxy secret |
| `/setup/calibration-reset` | POST | Clear calibration data (re-bootstrap on next restart) | Proxy secret |
| `/setup/openaq-sensors` | GET | List nearby reference PM2.5 sensors for admin UI | Proxy secret |

### Health & metrics (separate loopback port 8081)

| Path | Method | Purpose |
|------|--------|---------|
| `/health/live` | GET | Liveness probe (always 200 if process alive) |
| `/health/ready` | GET | Readiness probe (200 ok/degraded, 503 unhealthy) |
| `/metrics` | GET | Prometheus metrics (opt-in via `CLEARSKIES_METRICS_ENABLED=true`) |

Additionally, `GET /health` exists on the main port (8765) returning `{"status": "ok"}`.

### API middleware stack (outermost → innermost)

1. MetricsMiddleware — request timing
2. RequestIdMiddleware — establishes `request_id` for structured logging
3. BodySizeLimitMiddleware — rejects bodies > 1 MiB
4. ProxyAuthMiddleware — validates `X-Clearskies-Proxy-Auth` shared secret
5. RateLimitMiddleware — per-IP rate limiting (bypassed if proxy-trusted)
6. CORSMiddleware — configurable origins (default same-origin)
7. SecurityHeadersMiddleware — injects security headers

All errors returned as RFC 9457 `application/problem+json`.

### Conditions text engine (ADR-073)

The API hosts a multi-module, stateful conditions-text engine that produces the `weatherText` field on every `GET /api/v1/current` response. (Formerly in the realtime service; merged into the API per ADR-058.)

| Module | Role |
|--------|------|
| `weewx_clearskies_api/sse/conditions_text.py` | Stateless composer — assembles the `weatherText` string from per-component labels |
| `weewx_clearskies_api/sse/sky_condition.py` | Stateful classifier — Kv-first (Duchon-O'Malley architecture with CAELUS indices), 30-min ring buffer of 1-min GHI averages, produces the sky label |
| `weewx_clearskies_api/sse/temperature_comfort.py` | Stateless 2D matrix — maps (appTemp, dewpoint) to comfort label |
| `weewx_clearskies_api/sse/enrichment/weather_text.py` | Enrichment adapter — reads smoothed inputs + sky class, calls `build_weather_text()`, injects result into the `/current` response dict. Provider cross-check for fog/mist confirmation. |
| `weewx_clearskies_api/sse/haze_condition.py` | Haze detection — two-channel (Kcs deficit + PM), solar elevation gate, f(RH) correction |
| `weewx_clearskies_api/sse/auto_calibration.py` | Clean-sky baseline — monthly-normals model, 12 per-month Kcs baselines, 3-year rolling window, automatic bootstrap with smart sensor selection, sensor info persistence. Bootstrap uses McClear clear-sky GHI (ADR-072). |
| `weewx_clearskies_api/bootstrap/mcclear_client.py` | McClear data fetcher — retrieves historical clear-sky GHI via `pvlib.iotools.get_cams()` for bootstrap Kcs computation (ADR-072) |
| `weewx_clearskies_api/sse/text_generation.py` | NWS-style text engine — terse/standard/verbose verbosity, GFE threshold tables |
| `weewx_clearskies_api/sse/observation_model.py` | Structured local observation model — METAR-like field mapping |

**AQI data flow:** PM2.5/PM10 from observed-data AQI providers (Aeris, IQAir) flow through the enrichment pipeline via new 60-minute smoothing buffers in `input_smoother.py`. Smoothed PM values feed the haze detection module and fog/mist disambiguation. Model-based AQI providers (Open-Meteo) are excluded from haze confirmation. At night (solar elevation below the 10-15° detection gate), haze/smoke defers to provider current conditions observations; fog/mist remains local.

**New response fields on `/api/v1/current`:** `weatherTextStandard` (NWS one-sentence format) and `weatherTextVerbose` (full narrative). `weatherText` continues to carry terse format (backward compatible).

**Inputs:** smoothed loop-packet fields via `enrichment/input_smoother.py` — `rainRate` (2 min), `windSpeed`/`windGust` (5 min), `appTemp`/`dewpoint`/`outTemp`/`heatindex`/`windchill` (10 min), `radiation`+`maxSolarRad` (30 min kc rolling window). No database access.

**Output:** `data["data"]["weatherText"]` on the `/current` JSON response — a composed natural-language string (e.g., `"Warm and Humid, Partly Cloudy, with Light Rain"`) or `null` when no components are available.

**Transport:** REST only. `weatherText` is NOT included in the SSE loop-packet field map (`WEEWX_TO_OBSERVATION`) and is NOT updated via SSE. The conditions sentence updates at the REST poll interval, not at loop-packet frequency.

**Registration:** The API's `__main__.py` registers `enrich_weather_text` against the `"current"` endpoint key. Every `GET /api/v1/current` response is enriched before being returned to the browser.

**Sky classification (ADR-073):** Kv-first decision tree in the Duchon & O'Malley (1999) tradition — variability-primary, clearness-secondary — using CAELUS-derived indices (Ruiz-Arias & Gueymard 2023). Four indices (Kcs, Km, Kv, Kvf) computed from 1-minute GHI averages over a 30-minute ring buffer. Kv and Kvf are **clear-sky-detrended**: each minute-to-minute GHI change has the corresponding maxSolarRad change subtracted, isolating cloud-induced variability from deterministic solar geometry (Stein et al. 2012, Sandia Variability Index). Primary axis: Kv distinguishes uniform sky (Kv < 0.05: clear or overcast) from variable sky (Kv ≥ 0.05: broken coverage) — the inverted-U relationship between cloud fraction and irradiance variability (Xie & Sengupta 2021, Mol et al. 2023). Within uniform: Km distinguishes Clear (high) from Overcast (moderate) from Heavy Overcast (low transmittance). Within variable: Km distinguishes Mostly Clear / Partly Cloudy / Mostly Cloudy / Cloudy. Cloud enhancement (Kcs > 1.06 + high Kv + high Kvf) → "Partly Cloudy" (broken-cloud scenario, not clear-sky). Seven labels total: Clear, Mostly Clear, Partly Cloudy, Mostly Cloudy, Cloudy, Overcast, Heavy Overcast. Temporal coherence filter (15-min persistence). Startup backfill from archive records. **GHI mirroring** across sunrise/sunset boundaries via cos(zenith) interpolation (adapted from CAELUS `sky_indices.py`), stabilizing Km at low solar elevations. **SZA < 85° guard**: `classify()` returns None when solar elevation < 5°, falling back to provider cloud cover. Solar elevation computed via Skyfield from station coordinates. Full scientific citations in `docs/reference/sky-classification-science.md`.

**Startup behavior:** On API restart, `backfill()` seeds the sky classifier's ring buffer from archive records (last 30 minutes), enabling immediate classification. The temporal coherence filter applies a 3-minute startup grace. Full CAELUS-quality classification after ~30 minutes of live LOOP data. When solar analysis is unavailable (night, twilight, no pyranometer, or SZA guard engaged at elevation < 5°), the engine falls back to provider cloud cover via `_cloud_pct_to_sky()` in `enrichment/weather_text.py`, which maps cloud cover percentage to the sky label with day/night vocabulary awareness.

## Input mode (ADR-058)

The API connects to weewx via direct mode only. MQTT input is eliminated per ADR-058.

| Mode | Config | When | Transport | Broker needed |
|------|--------|------|-----------|--------------|
| **Direct** | `[input] mode = direct` (the only mode) | weewx co-located on same host (ADR-056) | Unix socket at `[input.direct] socket_path` (default `/var/run/weewx-clearskies/loop.sock`), served by `weewx-clearskies-extension` | No |

The API is the only component that touches the database. The direct adapter reads loop packets from weewx; it does not read the database.

> **Historical note (ADR-005, superseded):** MQTT subscriber mode (`mode = mqtt`, `paho-mqtt` optional install extra) was supported in the former realtime service. MQTT is eliminated per ADR-058. Operators using MQTT for other consumers (Home Assistant, Node-RED) are unaffected — weewx's own MQTT extension is separate from the deleted MQTT adapter. Those operators can also subscribe to the API's SSE endpoint at `GET /sse`.

## Unit conversion (ADR-042, updated for ADR-058)

The API converts all outbound data (both REST responses and SSE events) from the source unit system to the operator's configured display units. The dashboard receives `{value, label, formatted}` objects and has zero unit knowledge.

**REST path:** API queries archive values with `usUnits` declaring the unit system → looks up each field's group → converts to operator display unit → attaches label and formatted string.

**SSE path:** Direct adapter delivers loop packets with weewx unit system → API strips any unit suffixes → identifies source unit → converts to display unit → attaches label.

**Derived values:** Beaufort scale and comfort index (wind chill vs heat index) computed by the API's enrichment pipeline. Dashboard does not carry thresholds.

**Config:** `api.conf` `[units]` section (formerly `realtime.conf`) — `[[groups]]` (display unit per group), `[[string_formats]]` (decimal places), `[[labels]]` (display symbols), `[[ordinates]]` (compass directions), `[[time_formats]]`, `[[degree_days]]`, `[[trend]]`. Mirrors weewx skin.conf `[Units]` subsection names. Supports all 14 weewx unit groups.

## Config UI routes (verified from code)

Config UI is a standalone FastAPI app, run via `weewx-clearskies-config` CLI on port 9876.

### Auth & bootstrap

| Route | Method | Purpose |
|-------|--------|---------|
| `/` | GET | Redirect: no credentials → `/bootstrap`; no api.conf → `/wizard`; else → `/login` |
| `/bootstrap` | GET/POST | First-run: set admin credentials (one-time token) |
| `/login` | GET/POST | Admin login form |
| `/logout` | POST | End session |
| `/health` | GET | Returns `{"status": "ok"}` |

### Wizard (multi-step setup flow)

Wizard steps are defined by `wizard/routes.py` and `templates/wizard/step_*.html` in the stack repo. The step inventory evolves as the wizard gains features — see the code for the current step list.

**URL patterns:**

| Pattern | Method | Purpose |
|---------|--------|---------|
| `/wizard` | GET | Full wizard page (starts at step 1) |
| `/wizard/step/{N}` | GET/POST | Step-specific form render and submission |
| `/wizard/step/{N}/test` | POST | Inline connectivity test for a step (DB, provider, etc.) |
| `/wizard/step/{N}/key-fields/{domain}/{id}` | GET | HTMX fragment for provider key entry fields |
| `/wizard/step/{N}/test-key/{id}` | POST | HTMX fragment for provider key test result |
| `/wizard/{name}` | GET/POST | Named steps (e.g. `/wizard/import`, `/wizard/eula`, `/wizard/units`, `/wizard/privacy`, `/wizard/features`, `/wizard/tls`) |
| `/wizard/apply` | POST | Finalize config + write files (writes `api.conf`, `webcam.json` to `/etc/weewx-clearskies/`, `stack.conf`) |
| `/wizard/restart-status` | GET | Service restart status |

**Step categories** (not exhaustive — see code for full list): API connection, skin import, EULA, database, schema/column mapping, station identity, display units, provider selection + API keys, webcam, appearance/branding, privacy/legal, feature settings, TLS configuration, review + apply.

### CLI wizard

`weewx_clearskies_config/cli_wizard.py` provides an interactive terminal wizard and a headless (non-interactive, flag-driven) configuration path for SSH-only or automated installs. Both paths reuse the same wizard backend modules as the web UI (WizardState, apply_wizard). The CLI wizard covers a subset of the web wizard's steps: database, schema, station, providers, API keys, topology, bind addresses, review + apply. Headless mode accepts all settings as CLI flags for unattended deploys.

### Admin (ongoing config)

| Route | Method | Purpose |
|-------|--------|---------|
| `/admin/config` | GET | Config dashboard (all sections) |
| `/admin/config/{component}/{section}` | GET/POST | Section edit form (component = api/stack — realtime removed per ADR-058; wizard update pending) |
| `/admin/config/column-mapping` | GET/POST | Column mapping editor |
| `/admin/config/test-provider` | POST | Test provider connectivity |

## Dashboard pages (React Router v7)

| Route | Page | Lazy-loaded |
|-------|------|-------------|
| `/` | Now (home) | Yes |
| `/forecast` | Forecast | Yes |
| `/charts` | Charts | Yes |
| `/almanac` | Almanac | Yes |
| `/seismic` | Seismic | Yes |
| `/records` | Records | Yes |
| `/reports` | Reports | Yes |
| `/about` | About | Yes |
| `/legal` | Legal/Privacy | Yes |
| `/:slug` | Custom pages | Yes |
| `/*` | 404 Not Found | Yes |

API client defaults to `/api/v1` (relative, works with Caddy proxy). Override: `VITE_API_BASE_URL` env var. SSE URL: `VITE_SSE_URL` env var (or `/sse` via proxy). Mock mode: `VITE_USE_MOCK=true`.

Global error boundary (`src/components/error-boundary.tsx`) wraps the entire app tree in `main.tsx`. Catches any uncaught render error (including Leaflet `TileLayer` throws on unresolved tile URL variables) and shows a "Something went wrong / Reload page" recovery UI instead of a blank page. Each component still independently shows per-tile error states for API failures. **No first-run/unconfigured detection** (ARCHITECTURE.md Known gap #3, partially addressed — error boundary exists, first-run redirect still pending).

## Configuration files

All config in `/etc/weewx-clearskies/` (search order: `CLEARSKIES_CONFIG` env var → `/etc/weewx-clearskies/` → `~/.config/weewx-clearskies/`).

| File | Used by | Contains | Exists in examples? |
|------|---------|----------|-------------------|
| `api.conf` | API | Server bind, DB connection, providers, logging, TLS, input mode, socket path, SSE bind, unit conversion config (absorbs former `realtime.conf` settings per ADR-058) | Yes (`config/api.conf.example`) |
| `realtime.conf` | **DEPRECATED** — realtime service merged into API per ADR-058 | Input mode, MQTT settings, socket path, SSE bind, health bind, upstream API URL, unit conversion config | Yes (`config/realtime.conf.example`) — deprecated |
| `stack.conf` | Config UI | UI bind/port, TLS, `[ui] enabled` flag | **No — does not exist** |
| `secrets.env` | All (mode 0600) | DB password, API keys, admin credentials, proxy secret | No (generated by wizard) |
| `charts.conf` | API | Chart groups, charts, series (ConfigObj/INI, migrated from Belchertown `graphs.conf`) | No (generated by `clearskies-migrate-charts`) |
| `branding.json` | Dashboard (via Caddy) | Site branding: accent color, logos, theme mode, social URLs, GA tracking ID, privacy regions. Served by Caddy `handle /branding.json` route — **never in the web root** (rsync --delete would destroy it). | No (written by wizard) |
| `webcam.json` | Dashboard (via Caddy) | Webcam enabled flag, image/video URLs, refresh interval. Served by Caddy `handle /webcam.json` route — **never in the web root** (rsync --delete would destroy it). | No (written by wizard step 7) |
| `pages.json` | Dashboard (via Caddy) | Page visibility: `{ "hidden": ["seismic", "reports"] }`. Dashboard reads at boot to filter nav + routes. "Now" cannot be hidden. Served by Caddy `handle /pages.json` — **never in the web root.** Absent file = all pages visible. (ADR-024 amendment 2026-06-21) | No (written by admin UI) |
| `now-layout.json` | Dashboard (via Caddy) | Now page card layout: `{ "version": 1, "cards": [{ "type", "footprint", "rowSpan" }] }`. Dashboard reads at boot; absent file = compiled-in default layout. Served by Caddy `handle /now-layout.json` — **never in the web root.** (ADR-065) | No (written by admin card layout editor) |
| `ui-cert.pem` | Config UI | Self-signed TLS cert (mode 0644) | No (auto-generated with `--tls`) |
| `ui-key.pem` | Config UI | TLS private key (mode 0600) | No (auto-generated with `--tls`) |

**Secret naming:** `WEEWX_CLEARSKIES_<DOMAIN>_<FIELD>` (e.g., `WEEWX_CLEARSKIES_DB_PASSWORD`, `WEEWX_CLEARSKIES_AERIS_CLIENT_ID`).

**Secret-leak guard:** The API scans `.conf` at startup; any key matching `(?i)_(KEY|SECRET|TOKEN|PASSWORD)$` is a fatal startup error. Secrets belong in `secrets.env` only.

**Startup behavior when config missing:** The API raises `FileNotFoundError` and exits non-zero if `api.conf` is absent. It does not start in an "unconfigured" mode.

## weewx configuration ingestion

The API reads operator-specific parameters from weewx.conf at startup and exposes them to all consumers. These values are NOT hardcoded — they vary per installation.

| weewx.conf section | Key | `StationInfo` field | `/station` field | Default | Purpose |
|---|---|---|---|---|---|
| `[StdArchive]` | `archive_interval` | `archive_interval` | `archiveIntervalSeconds` | 300 | Archive record cadence in seconds. Drives chart proportional scaling, sky classifier freshness (`is_daytime()` threshold = 5× interval), temperature comfort hold time (5× interval), and barometer trend grace. |
| `[Station]` | `week_start` | `week_start` | `weekStartDay` | 6 (Sunday) | First day of calendar week (0=Monday, 6=Sunday). Dashboard uses it for `time_length = week` chart groups to compute calendar-week boundaries instead of a rolling 7-day window. |

**Data flow:** `load_station_metadata()` in `services/station.py` reads both values from the parsed weewx.conf `ConfigObj` → stores on `StationInfo` → exposed via `GET /api/v1/station` as `archiveIntervalSeconds` and `weekStartDay` → consumed by the dashboard's `ConfigDrivenGroup` component for chart data fetching and proportional aggregate scaling.

**Enrichment wiring:** At startup, `__main__.py` passes `archive_interval` to `sky_condition.configure()`, `temperature_comfort.configure()`, and (as the default `trend_time_grace`) to `barometer_trend.configure()`.

**Reference implementation:** Belchertown's `belchertown.py:370-376` reads `config_dict["StdArchive"]["archive_interval"]` and converts to milliseconds for the frontend. `belchertown.py:2548` reads `config_dict["Station"].get("week_start", 6)` for calendar-week span computation.

## Charts configuration

The charts system is operator-configurable via `charts.conf`, a ConfigObj/INI file (same format as weewx `skin.conf` — operator familiarity, per ADR-027). Three-level nesting: group → chart → series, matching Belchertown's `graphs.conf` structure.

**Data flow:** `charts.conf` is parsed by `services/charts_config.py` at API startup. Each series is pruned against the `ColumnRegistry` — series whose `observation_type` is not present in the database are removed, and empty charts/groups cascade-removed. The pruned config tree is served via `GET /api/v1/charts/config`. The dashboard's `ConfigDrivenGroup` and `ConfigDrivenChart` components fetch this config and render charts dynamically using Recharts (standard time-series) or custom SVG (wind rose, weather range).

**Proportional scaling (2026-06-07):** For rolling-range chart groups (1d/3d/7d/30d/90d), the dashboard computes a proportional `aggregate_interval` matching Belchertown's data-density approach: `ratio = max(1, range_seconds / base_time_seconds)`, `aggregate_interval = base_aggregate_interval × ratio`. This keeps ~170–288 data points per chart regardless of time range. The `aggregate_interval` (seconds) is passed to `GET /api/v1/archive` which groups records into `FLOOR(dateTime / N) * N` buckets.

**Per-field aggregation:** Each series in `charts.conf` may specify an `aggregate_type` (e.g., `sumcumulative` for cumulative rain, `max` for rainRate). The dashboard reads these from the chart config and passes them to the API as `agg_map=rain:sumcumulative,rainRate:max,...`. The API applies the specified SQL function per field within each proportional bucket; fields without an explicit type default to `AVG` (matching Belchertown's rolling-range default). The `sumcumulative` type applies `SUM` per bucket then accumulates the results into a running total — each record's value is the sum of all previous records. This replaces Belchertown's hardcoded `rainTotal` post-processing with an explicit, operator-configurable option that works for any observation.

**Grouped aggregation (`xAxis_groupby` charts):** Charts that group data by calendar period — such as Average Climate (monthly averages) — set `xAxis_groupby` in `charts.conf` and do NOT use `GET /api/v1/archive`. Instead the dashboard calls `GET /api/v1/archive/grouped` with `group_by=month|day|hour|year`. Series that need two-level aggregation (e.g., average of daily highs) specify both `aggregate_type` and `average_type` in `charts.conf`; the dashboard encodes these as `field:agg_type:avg_type` in the `fields` parameter (e.g., `outTemp:avg:max`). There is no `/climatology/*` endpoint; the former `/climatology/monthly` endpoint was removed and its use cases are fully covered by `/archive/grouped`.

**API archive conversion (2026-06-07, updated for ADR-058):** The API applies `UnitTransformer.transform_record()` to `/archive` responses. It infers `usUnits` from the response envelope's `units` label block (same as `/current`), converts each record, injects derived fields (`beaufort`, `comfortIndex`), and flattens ConvertedValue dicts to full-precision scalars. The `beaufort` field is kept as a `{value, label, formatted}` dict (not flattened) so the wind rose binning can read it via `extractNumber()`.

**Wind rose:** uses client-side binning from the API-injected `beaufort` field (per ADR-041 computation boundary amendment, ADR-042, ADR-058). The dashboard makes a **separate raw archive fetch** (no `aggregate_interval`) for wind rose data, with `fields=windSpeed,windDir` and a high limit. This preserves the actual wind speed distribution for correct Beaufort classification — aggregated (AVG'd) wind speeds would smooth out higher categories. The dashboard reads `beaufort.value` from these raw records and bins into a 16-direction × 7-Beaufort-speed matrix. No Beaufort computation in the dashboard — the API is the single Beaufort authority.

**Special series types:** The charts system recognizes three series names that trigger automatic rendering behavior — the dashboard switches chart component and data-fetching strategy without any additional operator config:

| Series name | Rendering | Data strategy | Automatic behaviors |
|-------------|-----------|---------------|---------------------|
| `windRose` | Custom SVG polar chart (16 directions × 7 Beaufort speed bands) | Separate raw (unaggregated) archive fetch for `windSpeed`+`windDir`; no `aggregate_interval` | Uses API-injected `beaufort` field for speed classification. Default Beaufort colors: `#7cb5ec, #b2df8a, #f7a35c, #8c6bb1, #dd3497, #e4d354, #268bd2`. Operator can override via `beauford0`–`beauford6` keys in `charts.conf`. |
| `weatherRange` | Recharts arearange (when `area_display = 1`) or columnrange (default). Polar only when `polar = true` is explicitly set. | Dual archive fetches: `agg=min` and `agg=max` with `aggregate_interval=86400` (daily) | JS applies 15-band temperature color zones (deep blue ≤0°F → red-orange ≤90°F → pink-red >110°F; Celsius equivalents for metric stations). Per Belchertown wiki: default is columnrange, NOT polar. |
| `haysChart` | Recharts arearange, `polar=true` (always — this is a circular 24-hour wind chart by design) | Queries `windSpeed` (max) and `windGust` (max) with auto-calculated `aggregate_interval` | Emulates Mount Washington Observatory circular wind chart: hour of day on circle, wind speed as radius. `yAxis_softMax` config controls radial scale. |

The system is fully config-driven: operators configure series names in `charts.conf`; the dashboard detects special names and switches chart components automatically. All other series render as standard Recharts time-series charts (line/spline/area/column/scatter).

**Weather range chart:** Recharts arearange or columnrange showing daily temperature range with 15-band color zones. Uses dual archive fetches (`agg=min` and `agg=max`) to get daily extremes. Renders as Cartesian chart by default; polar only when `polar = true` is explicitly set in `charts.conf`.

**Custom SQL queries:** operators define SQL in `charts.conf` (disk-only, same trust model as Belchertown). Queries are pre-validated at startup via `EXPLAIN`, executed in read-only transactions with a 10-second timeout and DDL keyword blocklist. Served via `GET /api/v1/charts/custom-query/{series_id}`.

**Migration:** `clearskies-migrate-charts` CLI converts Belchertown `graphs.conf` → Clear Skies `charts.conf`. Most INI keys are identical by design; the tool annotates unsupported keys with `# NOTE:` comments. The migration tool injects rendering defaults: `markerEnabled=false` on line/spline/area series, `type=scatter` promotion for `lineWidth=0` series (windDir), `yAxisTickDecimals=2` for barometer, `yAxis_min=0` for rain series.

## API TLS

The API always serves TLS (ADR-038 amendment to ADR-008):
- **Default:** Auto-generates Ed25519 keypair + self-signed X.509 cert on first start. Stored in config directory. Fingerprint (SHA-256) printed to terminal.
- **Override:** Operator supplies cert/key via `[tls] cert_path` / `key_path` in `api.conf` or `--tls-cert` / `--tls-key` CLI flags.
- **Trust handshake:** First-time setup: API prints address + trust token + fingerprint → operator enters in wizard step 1 → config UI verifies fingerprint + sends token → API validates, issues session → token consumed (single-use) → fingerprint pinned (SSH-style).

## Database access (ADR-012)

| Engine | Config | Connection string | Pool |
|--------|--------|------------------|------|
| **SQLite** (default) | `[database] kind = sqlite`, `path = /var/lib/weewx/weewx.sdb` | `sqlite:///{path}?mode=ro&uri=true` | NullPool |
| **MySQL/MariaDB** | `[database] kind = mysql`, `host`, `port`, `name` | `mysql+pymysql://{user}:{pass}@{host}:{port}/{name}?charset=utf8mb4` | QueuePool (pool_size=5, max_overflow=10) |

Credentials via env vars only: `WEEWX_CLEARSKIES_DB_USER`, `WEEWX_CLEARSKIES_DB_PASSWORD`.

Read-only enforcement (defense-in-depth): DB user with `SELECT`-only grants + startup write-probe (fails if writes succeed) + SQLite `?mode=ro`.

## Provider module layout (ADR-038)

```
weewx_clearskies_api/providers/
├── _common/          # HTTP client, retry/backoff, error taxonomy, capability registry
├── forecast/         # aeris, nws, openmeteo, openweathermap, wunderground
├── aqi/              # aeris, iqair, openaq, openmeteo, openweathermap (deprecated)
├── alerts/           # nws, aeris, openweathermap
├── earthquakes/      # usgs, geonet, emsc, renass
├── seeing/           # seven_timer (keyless, 7Timer ASTRO product)
└── radar/            # rainviewer, openweathermap, aeris, iem_nexrad, noaa_mrms, msc_geomet, dwd_radolan, iframe
```

Each module: outbound API call → response parsing → canonical field translation → capability declaration → error handling. Keyed providers proxied server-side (keys never reach browser).

## Caching (ADR-017)

| Backend | Config | When to use |
|---------|--------|------------|
| `memory` (default) | No config needed | Single worker (v0.1 default) |
| `redis` (**active on weewx host**) | `CLEARSKIES_CACHE_URL=redis://localhost:6379/0` (set in `/etc/weewx-clearskies/secrets.env`) | Multi-worker deploys |

Per-provider TTLs: forecast 30 min, alerts 5 min, AQI 15 min, radar metadata 5 min, seeing forecast 3 hours.

## Repo layout

| Repo | Local path | Branch | Language | Has Dockerfile |
|------|-----------|--------|----------|----------------|
| weewx-clearskies-api | `repos/weewx-clearskies-api` | main | Python 3.12+ | Yes |
| weewx-clearskies-realtime | `repos/weewx-clearskies-realtime` | main | Python | Yes — **DEPRECATED — merged into API per ADR-058. Repo archived.** |
| weewx-clearskies-dashboard | `repos/weewx-clearskies-dashboard` | main | TypeScript/React | Yes (init container) |
| weewx-clearskies-stack | `repos/weewx-clearskies-stack` | main | Python (config UI) + YAML/Caddyfile (orchestration) | **No** |
| weewx-clearskies-extension | `repos/weewx-clearskies-extension` | master | Python | No (installs into weewx via `weectl extension install`) |
| weewx-clearskies-truesun | `repos/weewx-clearskies-truesun` | main | Python | No (installs into weewx via `weectl extension install`). Deps: pvlib, cdsapi, h5netcdf. |
| weewx-clearskies-design-tokens | `repos/weewx-clearskies-design-tokens` | main | — | No (Phase 6+ placeholder) |
| weather-belchertown (meta) | `.` (root) | master | — (ADRs, plans, rules, contracts) | — |

## Stack repo structure (verified)

```
weewx-clearskies-stack/
├── weewx-host/
│   ├── docker-compose.yml      # api + redis
│   └── .env.example
├── frontend-host/
│   ├── docker-compose.yml      # caddy + dashboard (init) — realtime removed (ADR-058)
│   ├── Caddyfile
│   └── .env.example
├── single-host/
│   ├── docker-compose.yml      # all services combined
│   ├── Caddyfile
│   └── .env.example
├── config/
│   ├── api.conf.example
│   └── realtime.conf.example   # DEPRECATED — realtime merged into API (ADR-058); settings now in api.conf
├── examples/
│   └── reverse-proxy/Caddyfile # bare-metal Caddy example
├── archive/                    # pre-split monolithic files (historical)
├── dev/
│   ├── docker-compose.yml      # MariaDB + seed + Redis for local dev
│   └── .env.example
├── weewx_clearskies_config/    # Config UI Python package (pip-installable)
│   ├── app.py                  # FastAPI app factory
│   ├── cli.py                  # CLI entry point (port 9876 default)
│   ├── auth.py                 # Admin auth, sessions, rate limiting
│   ├── tls.py                  # Self-signed cert generation
│   ├── wizard/                 # Wizard routes, state, config writer
│   ├── config/                 # Config reader/updater, admin routes
│   ├── templates/              # Jinja2 templates (wizard steps, admin, login, bootstrap)
│   └── static/                 # CSS, JS
└── tests/                      # Wizard tests
```

## Authoritative manuals by component

All ADRs have been consolidated into authoritative manuals. ADRs are archived in `docs/archive/decisions/` — they explain *why* decisions were made but are not the operational authority.

| Component | Authority |
|-----------|----------|
| API (data model, units, enrichment, DB, SSE) | [`docs/API-MANUAL.md`](API-MANUAL.md) |
| Provider modules (caching, external APIs, compliance) | [`docs/PROVIDER-MANUAL.md`](PROVIDER-MANUAL.md) |
| Deployment, security, auth, config, monitoring | [`docs/OPERATIONS-MANUAL.md`](OPERATIONS-MANUAL.md) |
| Dashboard (technical behavior, i18n, routes, performance) | [`docs/DASHBOARD-MANUAL.md`](DASHBOARD-MANUAL.md) |
| Dashboard (visual design, tokens, icons, cards) | [`docs/DESIGN-MANUAL.md`](DESIGN-MANUAL.md) |
| System topology, ports, containers, routing | This document (ARCHITECTURE.md) |

Historical note: meta ADRs (component breakdown ADR-001, tech stack ADR-002, license ADR-003, repo naming ADR-004, multi-station scope ADR-011, versioning ADR-032, workspace layout ADR-036) are archived — their substance is captured in this document.

> **Note:** ADR-038a (`ADR-038a-wizard-api-channel.md`) was originally numbered ADR-038, sharing the number with the data-provider module organization ADR. Renumbered to 038a on 2026-05-23.

## Known gaps (current state vs. intended architecture)

> Update this section as gaps are closed. Remove entries when resolved.

| # | Gap | Intended | Current state | Decision (2026-05-23) | Blocking |
|---|-----|----------|---------------|----------------------|----------|
| 1 | Config UI not in compose/Caddy | ADR-027: "bundled compose adds a `config` service", "accessible at `/admin` through the reverse proxy" | No Dockerfile, not in any compose file, not proxied by Caddy | **Fix required.** Config UI is part of the site UI (like WordPress `/wp-admin`), not a standalone service. Add to compose, add Caddy proxy rules for `/wizard`, `/bootstrap`, `/login`, `/admin`. Operator should never think about it as separate. | First-run UX |
| 2 | API crashes without api.conf | API must be running for wizard (ADR-038a: wizard calls `/setup/*`) | `FileNotFoundError` at startup | **Fix required.** API needs a "life-support mode" — start without config, serve health port with `{"configured": false}` status, serve `/setup/*` endpoints. Dashboard and wizard use health port to detect unconfigured state. | Wizard flow |
| 3 | Dashboard shows error wall when unconfigured | Should detect unconfigured state and redirect to `/wizard` | Shows "Unable to load" on every tile; first-run redirect still missing | **Partially fixed.** Global `ErrorBoundary` added (`src/components/error-boundary.tsx`) — blank-page crash on render errors resolved. Remaining: dashboard checks API health port on load; if `configured: false`, redirect to `/wizard`. | First-run UX |
| 4 | ~~Realtime crashes without realtime.conf~~ | **Resolved by ADR-058 (2026-06-14).** The realtime service is eliminated — there is no `realtime.conf` and no realtime process. Gap #4 no longer applies. | — | — | — |
| 5 | No stack.conf example | ADR-027 references `stack.conf` | Does not exist | Deferred — CLI flags sufficient for v0.1. | Low |
| 6 | ADR-034 container table incomplete | ADR-027 adds config service | ADR-034 lists only 4 containers | Amend ADR-034 to add config UI row after gap #1 is implemented. | ADR consistency |
| 7 | Config UI imports API code directly | ADR-038a: wizard talks to API via HTTP | `wizard/schema.py` and `wizard/routes.py` import `STOCK_COLUMN_MAP` from `weewx_clearskies_api.db.reflection` — forces API source into config UI Docker build | Eliminate after first-run UX ships. Get stock column map from `/setup/schema` endpoint instead. | Code coupling |
| 9 | Wizard does not deliver station logo + station name to config | Operator-configured station logo + station name (`branding.siteTitle`, surfaced via `/api/v1/branding`) should be captured by the setup wizard and persisted so the dashboard hero can render them | The Now-page hero renders with no logo and no station name because that data is absent from the config — the wizard did not capture/deliver it. (Surfaced during C1 hero mockup review, 2026-05-31.) | **Fix required** (separate deliverable, not C1). Verify the wizard has steps that capture the logo + site title and persist them to the branding config; add/repair as needed. C1 designs the hero to render them once supplied, with a "My Weather Station" fallback for the unset case. | First-run UX / branding |
| 10 | Card-glass opacity too translucent | Cards must be readable over the global background; B3 made opacity an operator-configurable default | The B3 shipped defaults (light `rgba(255,255,255,0.72)`, dark `rgba(30,35,55,0.55)`) are too translucent against the global background — text is hard to read and contrast likely fails WCAG AA. (Surfaced during C1 mockup review, 2026-05-31.) | **Fix required** (cross-cutting, not C1-specific). Revisit the B3 default opacity (increase) and verify body-text contrast over the card-blended-over-background meets AA in both themes. Reopens the B3 opacity default. | A11y / WCAG |
| 11 | Global background does not change with day/night | ADR-047 background is condition- AND day/night-keyed (`scene.daytime`); the background should visibly change between day and night | Observed in the C1 mockup: the background did not change when toggling light/dark (day/night). Needs end-to-end verification that the ADR-047 day/night scene keying actually swaps the rendered background in the real dashboard. (Surfaced 2026-05-31.) | **Verify, then fix if broken** (cross-cutting, not C1). Confirm the dashboard maps `scene.daytime` to day vs night assets and the background updates; if the mockup-observed staleness reflects a real wiring gap, repair it. | ADR-047 / background |

### Resolved gaps (2026-05-23)

| # | Was | Resolution |
|---|-----|-----------|
| 7 | ADR-038 index entry incomplete | Renumbered to ADR-038a; added to INDEX.md |
| 8 (current) | Conditions text: night-sky fallback not wired | `provider_sky` IS passed to `build_weather_text()` via `compose_weather_text()`; `_cloud_pct_to_sky()` now day/night-aware (2026-06-08) |
| 8 (original) | Security baseline port numbers stale (8000/8001) | Fixed to 8765/8766 at time; port 8766 subsequently removed per ADR-058 (2026-06-14) |
| 9 | ADR-030 port reference (8080) | Fixed to 8765 |
