# Clear Skies — System Architecture

Single source of truth for what each service is, where it runs, what it exposes, and how traffic flows. **Read this before any architecture work. Update it after any architecture change.**

Authoritative for current system state. ADRs are authoritative for *why* decisions were made. If this document conflicts with an ADR, investigate — one of them is stale.

Last verified: 2026-06-07 (webcam.json moved from web root to /etc/weewx-clearskies/ so dashboard rsync --delete cannot remove it; Caddy /webcam.json route added to serve from config dir).

Previous: 2026-05-29 (B-1 fix: all three Caddyfiles now route /api/v1/* to realtime:8766 BFF instead of directly to the API; stack config/realtime.conf.example updated with [api] upstream_url section).

---

## Services

| Service | Repo | What it does | Technology | Main port | Health port |
|---------|------|-------------|------------|-----------|-------------|
| **API** | weewx-clearskies-api | REST API for weewx archive data, provider aggregation, setup endpoints | FastAPI (Python 3.12+), sync handlers, SQLAlchemy 2.x sync, uvicorn | 8765 | 8081 |
| **Realtime (BFF)** | weewx-clearskies-realtime | BFF gateway — proxies API requests, serves SSE, applies unit conversion (ADR-041, ADR-042) | FastAPI (Python), sse-starlette, httpx, uvicorn | 8766 | 8082 |
| **Dashboard** | weewx-clearskies-dashboard | Weather UI (static SPA, 9 pages + custom pages) | React 19, Vite 8, Tailwind CSS v4, shadcn/ui, Recharts, Leaflet, **Phosphor** (utility/nav/alert) + **inline Material Symbols SVG** (hero weather, ADR-049/050); Lucide retained for deferred glyph families only, i18next | None (init container) | — |
| **Config UI** | weewx-clearskies-stack | Setup wizard (8 steps) + ongoing config admin | FastAPI, Jinja2, HTMX, Pico CSS (Python-only, no Node build step) | 9876 | — |
| **Caddy** | upstream (caddy:2-alpine) | Reverse proxy, TLS termination (auto Let's Encrypt), static file server | Caddy | 80, 443 | — |
| **Redis** | upstream (redis:7-alpine) | Cache for provider API responses (TTLs: forecast 30 min, alerts 5 min, AQI 15 min) | Redis 7.0.15 | 6379 | — |
| **Design Tokens** | weewx-clearskies-design-tokens | Tailwind config + design variables npm package | Phase 6+ placeholder — no code yet. Tokens currently live in dashboard repo. | — | — |

## Layer Responsibilities

Computation boundaries between the three application layers. **No chart-specific or visualization-specific endpoint in the API.** The API is a general-purpose data access layer (ADR-010); chart-type awareness belongs in the dashboard.

| Layer | Responsibility | Does NOT do |
|-------|---------------|-------------|
| **API** | General-purpose data access: query the weewx archive, serve raw observation/aggregate values, host provider modules, expose setup endpoints. Returns raw values with `usUnits` declaring the unit system. | Unit conversion, derived-value computation (Beaufort, comfort index), chart-specific binning or aggregation, presentation formatting. (ADR-041 line 38: "The API still passes raw archive values to the BFF — the API itself does no conversion.") |
| **BFF (Realtime)** | Transformation gateway: proxy API responses, apply unit conversion to all outbound data (REST + SSE), compute derived values (Beaufort scale, comfort index, barometer trend direction, cardinal wind directions), run the conditions-text engine, serve SSE stream. Single conversion authority (ADR-042). | Database access, provider API calls, chart-type awareness, presentation layout. |
| **Dashboard** | Rendering + presentation-level computation: display converted values, client-side binning for visualizations (e.g., wind rose direction×Beaufort matrix from BFF-provided fields), LTTB downsampling, chart layout, theming, accessibility. | Unit conversion, Beaufort/comfort-index threshold logic, raw SQL queries, provider API calls. (ADR-042 line 71: "Dashboard does not carry Beaufort thresholds.") |

**Why this boundary exists (2026-06-05):** Phase 4 of the configurable charts system placed a wind rose endpoint (`/charts/wind-rose`) in the API that duplicated the BFF's Beaufort classification — violating ADR-041 and ADR-042. The BFF's `UnitTransformer.transform_record()` already injects `beaufort` into every archive record. The API endpoint was redundant domain logic in the wrong layer. Corrected by deleting the API endpoint and moving binning to the dashboard (which reads the BFF-injected `beaufort` field). See ADR-041 amendment.

## Authoritative port registry

**These ports are locked. Do not use different ports without explicit user approval and an update to this table.**

| Port | Protocol | Service | Host | Binding | Notes |
|------|----------|---------|------|---------|-------|
| **80** | TCP | Caddy | front-end host | `0.0.0.0` | HTTP → public. Docker publishes as `80:80`. |
| **443** | TCP+UDP | Caddy | front-end host | `0.0.0.0` | HTTPS + HTTP/3 → public. Docker publishes as `443:443` and `443:443/udp`. |
| **8765** | TCP | API | weewx host | `0.0.0.0` | TLS always. BFF proxies here; not directly browser-accessible (ADR-041). |
| **8081** | TCP | API health | weewx host | `127.0.0.1` | `/health/live`, `/health/ready`, `/metrics`. Loopback only. |
| **8766** | TCP | Realtime (BFF) | front-end host | Docker network | BFF gateway. Caddy proxies `/api/v1/*` and `/sse` here (ADR-041). Not exposed to host. |
| **8082** | TCP | Realtime health | front-end host | `127.0.0.1` | Loopback only. |
| **9876** | TCP | Config UI | front-end host | Docker network | Wizard + admin. Caddy proxies `/wizard`, `/bootstrap`, `/login`, `/admin`, `/static` here. Not exposed to host. |
| **6379** | TCP | Redis | weewx host | `127.0.0.1` | Cache (active). Loopback only. CLEARSKIES_CACHE_URL=redis://localhost:6379/0 in secrets.env. |
| **1883** | TCP | MQTT broker | weewx host | varies | Only if MQTT mode. Realtime subscribes here. |

## Container inventory

Each repo builds its own container image independently (ADR-034). A dashboard CSS tweak does not rebuild the API.

| Container | Image source | Lifecycle | Runs on (two-host default) |
|-----------|-------------|-----------|---------------------------|
| `api` | `weewx-clearskies-api/Dockerfile` | Long-running. TLS always enabled (Ed25519 self-signed by default). | weewx host |
| `realtime` | `weewx-clearskies-realtime/Dockerfile` | Long-running | front-end host |
| `dashboard` | `weewx-clearskies-dashboard/Dockerfile` | **Init container** — multi-stage Node 22 build, copies `dist/` to `/dist` volume, exits | front-end host |
| `caddy` | `caddy:2-alpine` | Long-running | front-end host |
| `redis` | `redis:7-alpine` | Long-running | weewx host |

> **Config UI is NOT containerized.** It has no Dockerfile and is not in any compose file. It is distributed as a pip package (`weewx-clearskies-config`) and run manually by the operator. ADR-027 says "bundled compose adds a `config` service" — this is an unimplemented requirement. See Known gaps.

> **API native install (2026-05-24):** The API is currently installed natively on the `weewx` LXD container (not in Docker) via pip into a Python 3.12 venv at `/home/ubuntu/repos/weewx-clearskies-api/.venv`, managed by systemd unit `weewx-clearskies-api.service`. Config at `/etc/weewx-clearskies/api.conf`. Health port (8081) also serves TLS. This is the production deployment path on bare-metal / LXD; the Dockerfile exists for Docker compose deployments.
>
> **API startup time: ~2 minutes.** After `systemctl restart weewx-clearskies-api`, the service runs a cache warmer that makes outbound API calls to configured providers (Aeris, NWS, etc.) before uvicorn binds to port 8765. The service is not ready to serve requests until the cache warm completes. When scripting restarts, wait at least 120 seconds before hitting endpoints — `sleep 10` is not enough.

> **Native dashboard / dev deploy (2026-05-29):** On the `weather-dev` LXD container the dashboard is NOT run as a Docker init container. Instead the source is pulled to `/home/ubuntu/repos/weewx-clearskies-dashboard`, built natively with `npm run build` (Vite → `dist/`), and the built `dist/` is rsync'd into the Caddy web root `/var/www/clearskies/` (excluding the read-only `webcam/` bind-mount). Realtime, API, and Config UI run as systemd units (`weewx-clearskies-{realtime,api,config}.service`). The full redeploy is automated by `scripts/redeploy-weather-dev.sh`; source-only refresh by `scripts/sync-to-weather-dev.sh`. Procedure: [procedures/deploy-clearskies.md](procedures/deploy-clearskies.md). The Docker init-container model above is the compose deployment path.

## Default topology: two-host split (ADR-034)

```
weewx host                          front-end host
+-----------------------+           +----------------------------------+
| api :8765 (TLS)       |           | caddy :80/:443                   |
|   health :8081 (lo)   |  network  |   serves dashboard static files  |
|   reads weewx.conf    |<--------->|   proxies /api/v1/* to BFF       |
|   reads weewx archive |           |   proxies /sse to BFF            |
|   serves /api/v1/*    |           |                                  |
|   serves /setup/*     |           | realtime (BFF) :8766             |
|   NOT browser-facing  |           |   proxies /api/v1/* to API       |
|                       |           |   serves /sse (MQTT→SSE)         |
| redis :6379 (optional)|           |   applies unit conversion        |
|   loopback only       |           |   health :8082 (lo)              |
+-----------------------+           |                                  |
                                    | dashboard (init)                 |
                                    |   builds SPA, copies to volume   |
                                    +----------------------------------+
```

**Single-host alternative:** All services on one machine. Caddy proxies to local Docker network names (`realtime:8766` for both `/api/v1/*` and `/sse`). Realtime BFF proxies to `api:8765`. Realtime uses direct mode (Unix socket to weewx engine, no MQTT broker needed).

## Caddy routing

All three Caddyfile variants (frontend-host, single-host, examples/reverse-proxy) route both `/api/v1/*` and `/sse` to the realtime BFF. The BFF proxies `/api/v1/*` onward to the upstream API and applies unit conversion before returning responses. `realtime.conf [api] upstream_url` must be set to the upstream API address — see topology notes below the table.

| Path pattern | Destination | What it serves |
|-------------|-------------|----------------|
| `/api/v1/*` | `realtime:8766` BFF — BFF proxies to upstream API and applies unit conversion | Weather data JSON endpoints (unit-converted by BFF) |
| `/sse` | `realtime:8766` BFF | Server-Sent Events stream (unit-converted by BFF) |
| `/wizard*` | `config:9876` (local Docker network) | Setup wizard (7-step flow) |
| `/bootstrap*` | `config:9876` | First-run admin credential setup |
| `/login*`, `/logout*` | `config:9876` | Admin auth |
| `/admin*` | `config:9876` | Ongoing config management |
| `/webcam.json` | `file_server` from `/etc/weewx-clearskies/` | Webcam config JSON (safe from rsync --delete; lives outside web root) |
| `/webcam/*` | `file_server` from `/var/www/clearskies/webcam/` | Live webcam still + timelapse. No `try_files` — returns 404 for missing files. |
| `/static/*` | `config:9876` | Config UI static assets (CSS, JS) |
| `/*` (fallback) | `/srv/dashboard` static files (shared volume from init container) | React SPA with `try_files` fallback to `index.html` |

Security headers on all responses: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, `Server` header removed.

**`[api] upstream_url` per topology** (set in `realtime.conf` — REQUIRED; omitting it makes every `/api/v1/*` request return 503):

| Topology | `upstream_url` value | Notes |
|----------|---------------------|-------|
| frontend-host (compose) | `https://<weewx-host-address>:8765` | API is on the remote weewx host; `$CLEARSKIES_API_URL` from the old Caddyfile belongs here instead |
| single-host (compose) | `https://api:8765` | Both services are compose services; use the Docker network service name |
| native / reverse-proxy | `https://localhost:8765` | Both services are systemd units on the same host |

`tls_verify = false` applies in all three cases when the API uses its default self-signed certificate.

## Webcam

The webcam feature is a UI concern. The API has no webcam knowledge.

### File serving

An external capture process writes two files to the weewx LXD container at `/var/www/weewx/webcam/`:

- `weather_cam.jpg` — live still image
- `weewx_timelapse.mp4` — timelapse video

An LXD disk device mounts the host path `/mnt/weewx/webcam` read-only into the `weather-dev` container at `/var/www/clearskies/webcam/`. Caddy serves the `/webcam/*` path via `file_server` from that directory with no `try_files` fallback — a request for a missing file returns 404 immediately.

### Configuration flow

The setup wizard (stack repo, step 7 of 8) collects webcam settings: enabled flag, image URL, video URL, and refresh interval. On apply (`/wizard/apply`), the wizard writes two outputs:

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

## API endpoints (30+ total, verified from code)

### Data endpoints (under `/api/v1`, 15 routers)

| Path | Method | Purpose |
|------|--------|---------|
| `/api/v1/station` | GET | Station metadata (singleton). The `name` field is the operator's configured display location, read from `weewx.conf [Station] location` at startup. |
| `/api/v1/current` | GET | Most recent observation. The `weatherText` field is always null in the API response; the BFF enrichment pipeline (`enrich_weather_text`) injects the composed conditions string before serving the dashboard (ADR-041, ADR-044). |
| `/api/v1/archive` | GET | Historical archive records with pagination/filtering. Optional `agg` param (`min`/`max`/`avg`/`sum`/`count`) overrides per-field default aggregation for `interval=day` and `interval=hour`. |
| `/api/v1/records` | GET | Section-grouped highs and lows |
| `/api/v1/forecast` | GET | Forecast bundle (hourly + daily + discussion) |
| `/api/v1/alerts` | GET | Active severe-weather alerts |
| `/api/v1/aqi/current` | GET | Current air quality index |
| `/api/v1/aqi/history` | GET | Historical AQI from archive |
| `/api/v1/earthquakes` | GET | Recent earthquakes within configured radius |
| `/api/v1/almanac` | GET | Sun + moon snapshot for one date |
| `/api/v1/almanac/sun-times` | GET | Year-long sunrise/sunset/daylight series |
| `/api/v1/almanac/moon-phases` | GET | Per-day moon-phase grid (month or year) |
| `/api/v1/almanac/seeing-forecast` | GET | 72-hour astronomical seeing forecast (7Timer ASTRO, 3-hour intervals) |
| `/api/v1/charts/groups` | GET | Chart-group structure |
| `/api/v1/charts/config` | GET | Full chart configuration tree (groups, charts, series) parsed from `charts.conf` |
| `/api/v1/charts/custom-query/{series_id}` | GET | Execute operator-defined SQL query from `charts.conf` (read-only, pre-validated at startup) |
| `/api/v1/reports` | GET | Available NOAA report files |
| `/api/v1/reports/{year}/{month}` | GET | Monthly NOAA report (raw text) |
| `/api/v1/reports/{year}` | GET | Yearly NOAA report (raw text) |
| `/api/v1/pages` | GET | Dashboard navigation list |
| `/api/v1/pages/{slug}/content` | GET | Page markdown content |
| `/api/v1/content/about` | GET | About page markdown content |
| `/api/v1/content/legal` | GET | Legal/privacy page markdown content |
| `/api/v1/capabilities` | GET | Runtime capability registry |
| `/api/v1/branding` | GET | Operator branding (accent, logos, theme defaults) |
| `/api/v1/radar/providers/{id}/frames` | GET | Radar frame index |
| `/api/v1/radar/providers/{id}/tiles/{z}/{x}/{y}` | GET | Binary tile proxy (keyed providers) |

OpenAPI docs: `/api/v1/docs` (Swagger), `/api/v1/redoc`, `/api/v1/openapi.json`.

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

## Realtime (BFF) endpoints

| Port | Path | Purpose |
|------|------|---------|
| 8766 | `/api/v1/*` | Catch-all proxy to upstream API. Applies unit conversion to JSON responses (ADR-041, ADR-042). |
| 8766 | `/sse` | SSE stream — events with `type: "loop"`, data = unit-converted JSON. 15-second keepalive comments. |
| 8082 (lo) | `/health/live` | Liveness probe |
| 8082 (lo) | `/health/ready` | Readiness probe (checks adapter connection + upstream API connectivity) |

OpenAPI disabled on realtime (no docs/redoc endpoints).

### Conditions text engine (ADR-044)

The realtime service hosts a multi-module, stateful conditions-text engine that produces the `weatherText` field on every `GET /api/v1/current` response.

| Module | Role |
|--------|------|
| `weewx_clearskies_realtime/conditions_text.py` | Stateless composer — assembles the `weatherText` string from per-component labels |
| `weewx_clearskies_realtime/sky_condition.py` | Stateful classifier — 30-min rolling kc-buffer, produces the sky label |
| `weewx_clearskies_realtime/temperature_comfort.py` | Stateless 2D matrix — maps (appTemp, dewpoint) to comfort label |
| `weewx_clearskies_realtime/enrichment/weather_text.py` | Enrichment adapter — reads smoothed inputs + sky class, calls `build_weather_text()`, injects result into the `/current` response dict |

**Inputs:** smoothed loop-packet fields via `enrichment/input_smoother.py` — `rainRate` (2 min), `windSpeed`/`windGust` (5 min), `appTemp`/`dewpoint`/`outTemp`/`heatindex`/`windchill` (10 min), `radiation`+`maxSolarRad` (30 min kc rolling window). No database access.

**Output:** `data["data"]["weatherText"]` on the `/current` JSON response — a composed natural-language string (e.g., `"Warm and Humid, Partly Cloudy, with Light Rain"`) or `null` when no components are available.

**Transport:** REST only. `weatherText` is NOT included in the SSE loop-packet field map (`WEEWX_TO_OBSERVATION`) and is NOT updated via SSE. The conditions sentence updates at the REST poll interval, not at loop-packet frequency.

**Registration:** `__main__.py` registers `enrich_weather_text` against the `"current"` endpoint key. Every `GET /api/v1/current` response is enriched before being returned to the browser.

**Startup behavior:** The solar kc-buffer requires approximately 3 minutes of loop packets before the sky classifier can produce a result. During this warm-up window, `weatherText` may be `null`. Once data accumulates, the engine produces output continuously. When solar analysis is unavailable (night, twilight, no pyranometer), the engine is *intended* to fall back to provider cloud cover / weather text for sky classification — but that fallback is currently **not wired** (see Known gaps #8), so at night the sentence omits its sky component.

## Realtime modes (ADR-005)

| Mode | Config | When | Transport | Broker needed |
|------|--------|------|-----------|--------------|
| **Direct** | `[input] mode = direct` (default) | weewx on same host | Unix socket at `[input.direct] socket_path` (default `/var/run/weewx-clearskies/loop.sock`) | No |
| **MQTT** | `[input] mode = mqtt` | weewx on different host | paho-mqtt subscriber (optional install extra) | Yes |

MQTT settings: `broker_host`, `broker_port` (1883), `topic` (weewx/loop), `client_id`, `username`, `password_env` (env var reference), `tls`, `qos` (0), `keepalive` (60).

Neither mode reads the database. The API is the only component that touches the database.

## Unit conversion (ADR-042)

The BFF converts all outbound data (both proxied REST responses and SSE events) from the source unit system to the operator's configured display units. The dashboard receives `{value, label, formatted}` objects and has zero unit knowledge.

**REST path:** API returns raw archive values with `usUnits` declaring the unit system → BFF looks up each field's group → converts to operator display unit → attaches label and formatted string.

**SSE path:** MQTT field names carry unit suffixes (e.g., `outTemp_F`) → BFF strips suffix using known-suffix map from weewx's `UNIT_REDUCTIONS` → identifies source unit → converts to display unit → attaches label.

**Derived values:** Beaufort scale and comfort index (wind chill vs heat index) computed by BFF. Dashboard does not carry thresholds.

**Config:** `realtime.conf` `[units]` section — `[[groups]]` (display unit per group), `[[string_formats]]` (decimal places), `[[labels]]` (display symbols), `[[ordinates]]` (compass directions), `[[time_formats]]`, `[[degree_days]]`, `[[trend]]`. Mirrors weewx skin.conf `[Units]` subsection names. Supports all 14 weewx unit groups.

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

### Wizard (7-step setup flow)

| Route | Method | Purpose |
|-------|--------|---------|
| `/wizard` | GET | Full wizard page (starts at step 1) |
| `/wizard/step/1` | POST | API connection verification |
| `/wizard/step/2` | POST | Database configuration |
| `/wizard/step/2/test` | POST | Test DB connection |
| `/wizard/step/3` | POST | Column mapping |
| `/wizard/step/4` | GET/POST | Station identity |
| `/wizard/step/4/timezone` | POST | Timezone lookup |
| `/wizard/step/5` | GET | MQTT / input mode |
| `/wizard/step/5/test` | POST | Test MQTT connection |
| `/wizard/step/6` | POST | Provider selection + API keys |
| `/wizard/step/6/key-fields/{domain}/{id}` | GET | Inline key entry fields |
| `/wizard/step/6/test-key/{id}` | POST | Test provider connectivity |
| `/wizard/step/7` | GET/POST | Webcam settings (enabled, image URL, video URL, refresh interval) |
| `/wizard/step/8` | GET | Review summary |
| `/wizard/apply` | POST | Finalize config + write files (writes `api.conf`, `webcam.json` to `/etc/weewx-clearskies/`, `stack.conf`) |
| `/wizard/restart-status` | GET | Service restart status |

### Admin (ongoing config)

| Route | Method | Purpose |
|-------|--------|---------|
| `/admin/config` | GET | Config dashboard (all sections) |
| `/admin/config/{component}/{section}` | GET/POST | Section edit form (component = api/realtime/stack) |
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
| `api.conf` | API | Server bind, DB connection, providers, logging, TLS, branding | Yes (`config/api.conf.example`) |
| `realtime.conf` | Realtime (BFF) | Input mode, MQTT settings, socket path, SSE bind, health bind, upstream API URL, unit conversion config | Yes (`config/realtime.conf.example`) |
| `stack.conf` | Config UI | UI bind/port, TLS, `[ui] enabled` flag | **No — does not exist** |
| `secrets.env` | All (mode 0600) | DB password, API keys, admin credentials, proxy secret | No (generated by wizard) |
| `charts.conf` | API | Chart groups, charts, series (ConfigObj/INI, migrated from Belchertown `graphs.conf`) | No (generated by `clearskies-migrate-charts`) |
| `webcam.json` | Dashboard (via Caddy) | Webcam enabled flag, image/video URLs, refresh interval. Served by Caddy `handle /webcam.json` route — **never in the web root** (rsync --delete would destroy it). | No (written by wizard step 7) |
| `ui-cert.pem` | Config UI | Self-signed TLS cert (mode 0644) | No (auto-generated with `--tls`) |
| `ui-key.pem` | Config UI | TLS private key (mode 0600) | No (auto-generated with `--tls`) |

**Secret naming:** `WEEWX_CLEARSKIES_<DOMAIN>_<FIELD>` (e.g., `WEEWX_CLEARSKIES_DB_PASSWORD`, `WEEWX_CLEARSKIES_AERIS_CLIENT_ID`).

**Secret-leak guard:** API and realtime scan `.conf` at startup; any key matching `(?i)_(KEY|SECRET|TOKEN|PASSWORD)$` is a fatal startup error. Secrets belong in `secrets.env` only.

**Startup behavior when config missing:** Both API and realtime raise `FileNotFoundError` and exit non-zero. Neither starts in an "unconfigured" mode.

## Charts configuration

The charts system is operator-configurable via `charts.conf`, a ConfigObj/INI file (same format as weewx `skin.conf` — operator familiarity, per ADR-027). Three-level nesting: group → chart → series, matching Belchertown's `graphs.conf` structure.

**Data flow:** `charts.conf` is parsed by `services/charts_config.py` at API startup. Each series is pruned against the `ColumnRegistry` — series whose `observation_type` is not present in the database are removed, and empty charts/groups cascade-removed. The pruned config tree is served via `GET /api/v1/charts/config`. The dashboard's `ConfigDrivenGroup` and `ConfigDrivenChart` components fetch this config and render charts dynamically using Recharts (standard time-series) or custom SVG (wind rose, weather range).

**Wind rose:** uses client-side binning from the BFF-injected `beaufort` field (per ADR-041 computation boundary amendment, ADR-042). The dashboard reads `beaufort.value` from archive records and bins into a 16-direction × 7-Beaufort-speed matrix. No Beaufort computation in the dashboard — the BFF is the single Beaufort authority.

**Weather range chart:** custom SVG polar chart showing daily temperature range. Uses the `agg` query parameter on `/archive` with dual fetches (`agg=min` and `agg=max`) to get daily extremes.

**Custom SQL queries:** operators define SQL in `charts.conf` (disk-only, same trust model as Belchertown). Queries are pre-validated at startup via `EXPLAIN`, executed in read-only transactions with a 10-second timeout and DDL keyword blocklist. Served via `GET /api/v1/charts/custom-query/{series_id}`.

**Migration:** `clearskies-migrate-charts` CLI converts Belchertown `graphs.conf` → Clear Skies `charts.conf`. Most INI keys are identical by design; the tool annotates unsupported keys with `# NOTE:` comments.

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
├── aqi/              # aeris, openmeteo, openweathermap, iqair
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
| weewx-clearskies-realtime | `repos/weewx-clearskies-realtime` | main | Python | Yes |
| weewx-clearskies-dashboard | `repos/weewx-clearskies-dashboard` | main | TypeScript/React | Yes (init container) |
| weewx-clearskies-stack | `repos/weewx-clearskies-stack` | main | Python (config UI) + YAML/Caddyfile (orchestration) | **No** |
| weewx-clearskies-design-tokens | `repos/weewx-clearskies-design-tokens` | main | — | No (Phase 6+ placeholder) |
| weather-belchertown (meta) | `.` (root) | master | — (ADRs, plans, rules, contracts) | — |

## Stack repo structure (verified)

```
weewx-clearskies-stack/
├── weewx-host/
│   ├── docker-compose.yml      # api + redis
│   └── .env.example
├── frontend-host/
│   ├── docker-compose.yml      # caddy + dashboard (init) + realtime
│   ├── Caddyfile
│   └── .env.example
├── single-host/
│   ├── docker-compose.yml      # all services combined
│   ├── Caddyfile
│   └── .env.example
├── config/
│   ├── api.conf.example
│   └── realtime.conf.example
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

## Authoritative ADRs by component

| Component | Primary ADRs |
|-----------|-------------|
| Component breakdown | ADR-001 |
| Tech stack | ADR-002 |
| Deployment topology | ADR-034 |
| API | ADR-010 (data model), ADR-012 (DB access), ADR-018 (versioning) |
| Realtime (BFF) | ADR-005, ADR-041 (BFF), ADR-042 (units) |
| Dashboard | ADR-002, ADR-009 (design), ADR-024 (page taxonomy) |
| Config UI / Wizard | ADR-027 (wizard), ADR-038a-wizard-api-channel (wizard-to-API channel) |
| Auth | ADR-008, ADR-037 (inbound traffic) |
| Providers | ADR-006 (compliance), ADR-007 (forecast), ADR-038-data-provider-module-organization |
| Caching | ADR-017 |
| Theming / Branding | ADR-022, ADR-023 (light/dark mode) |
| i18n | ADR-021 |
| Health / Readiness | ADR-030 |
| Observability / Metrics | ADR-031 |
| Logging | ADR-029 |
| Security | contracts/security-baseline.md |

> **Note:** ADR-038a (`ADR-038a-wizard-api-channel.md`) was originally numbered ADR-038, sharing the number with the data-provider module organization ADR. Renumbered to 038a on 2026-05-23.

## Known gaps (current state vs. intended architecture)

> Update this section as gaps are closed. Remove entries when resolved.

| # | Gap | Intended | Current state | Decision (2026-05-23) | Blocking |
|---|-----|----------|---------------|----------------------|----------|
| 1 | Config UI not in compose/Caddy | ADR-027: "bundled compose adds a `config` service", "accessible at `/admin` through the reverse proxy" | No Dockerfile, not in any compose file, not proxied by Caddy | **Fix required.** Config UI is part of the site UI (like WordPress `/wp-admin`), not a standalone service. Add to compose, add Caddy proxy rules for `/wizard`, `/bootstrap`, `/login`, `/admin`. Operator should never think about it as separate. | First-run UX |
| 2 | API crashes without api.conf | API must be running for wizard (ADR-038a: wizard calls `/setup/*`) | `FileNotFoundError` at startup | **Fix required.** API needs a "life-support mode" — start without config, serve health port with `{"configured": false}` status, serve `/setup/*` endpoints. Dashboard and wizard use health port to detect unconfigured state. | Wizard flow |
| 3 | Dashboard shows error wall when unconfigured | Should detect unconfigured state and redirect to `/wizard` | Shows "Unable to load" on every tile; first-run redirect still missing | **Partially fixed.** Global `ErrorBoundary` added (`src/components/error-boundary.tsx`) — blank-page crash on render errors resolved. Remaining: dashboard checks API health port on load; if `configured: false`, redirect to `/wizard`. | First-run UX |
| 4 | Realtime crashes without realtime.conf | Same pattern as API | `FileNotFoundError` at startup | Lower priority — wizard configures API first; realtime config written during wizard apply step. Consider same life-support pattern. | Wizard flow |
| 5 | No stack.conf example | ADR-027 references `stack.conf` | Does not exist | Deferred — CLI flags sufficient for v0.1. | Low |
| 6 | ADR-034 container table incomplete | ADR-027 adds config service | ADR-034 lists only 4 containers | Amend ADR-034 to add config UI row after gap #1 is implemented. | ADR consistency |
| 7 | Config UI imports API code directly | ADR-038a: wizard talks to API via HTTP | `wizard/schema.py` and `wizard/routes.py` import `STOCK_COLUMN_MAP` from `weewx_clearskies_api.db.reflection` — forces API source into config UI Docker build | Eliminate after first-run UX ships. Get stock column map from `/setup/schema` endpoint instead. | Code coupling |
| 8 | Conditions text: night-sky fallback not wired | ADR-044 §1b specifies provider cloud cover as the intended fallback when solar analysis is unavailable at night | `compose_weather_text()` in realtime `enrichment/weather_text.py` does not pass `provider_sky` to `build_weather_text()`, so the conditions sentence omits its sky component at night even when a forecast provider is configured. `build_weather_text()` accepts `provider_sky: str \| None = None` but the argument is never supplied. | Tracked code gap, not an ADR contradiction. | Conditions text |
| 9 | Wizard does not deliver station logo + station name to config | Operator-configured station logo + station name (`branding.siteTitle`, surfaced via `/api/v1/branding`) should be captured by the setup wizard and persisted so the dashboard hero can render them | The Now-page hero renders with no logo and no station name because that data is absent from the config — the wizard did not capture/deliver it. (Surfaced during C1 hero mockup review, 2026-05-31.) | **Fix required** (separate deliverable, not C1). Verify the wizard has steps that capture the logo + site title and persist them to the branding config; add/repair as needed. C1 designs the hero to render them once supplied, with a "My Weather Station" fallback for the unset case. | First-run UX / branding |
| 10 | Card-glass opacity too translucent | Cards must be readable over the global background; B3 made opacity an operator-configurable default | The B3 shipped defaults (light `rgba(255,255,255,0.72)`, dark `rgba(30,35,55,0.55)`) are too translucent against the global background — text is hard to read and contrast likely fails WCAG AA. (Surfaced during C1 mockup review, 2026-05-31.) | **Fix required** (cross-cutting, not C1-specific). Revisit the B3 default opacity (increase) and verify body-text contrast over the card-blended-over-background meets AA in both themes. Reopens the B3 opacity default. | A11y / WCAG |
| 11 | Global background does not change with day/night | ADR-047 background is condition- AND day/night-keyed (`scene.daytime`); the background should visibly change between day and night | Observed in the C1 mockup: the background did not change when toggling light/dark (day/night). Needs end-to-end verification that the ADR-047 day/night scene keying actually swaps the rendered background in the real dashboard. (Surfaced 2026-05-31.) | **Verify, then fix if broken** (cross-cutting, not C1). Confirm the dashboard maps `scene.daytime` to day vs night assets and the background updates; if the mockup-observed staleness reflects a real wiring gap, repair it. | ADR-047 / background |

### Resolved gaps (2026-05-23)

| # | Was | Resolution |
|---|-----|-----------|
| 7 | ADR-038 index entry incomplete | Renumbered to ADR-038a; added to INDEX.md |
| 8 | Security baseline port numbers stale (8000/8001) | Fixed to 8765/8766 |
| 9 | ADR-030 port reference (8080) | Fixed to 8765 |
