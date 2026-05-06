# CLEAR-SKIES-PLAN — A modern, modular weather UI for weewx

**Project name:** Clear Skies (working title; verified no conflicts in the weewx ecosystem 2026-04-29)

**Goal:** Build a modern, design-led weather website for `weather.shaneburkhardt.com` to replace the current Belchertown skin, structured as a small set of independently-installable, well-documented components that any weewx user can pick up and run on their own station.

**Status:** **Phase 1 complete (2026-05-05).** All 40 ADRs Accepted; tech-stack spike complete; weather-dev LXD container stood up; docker-compose dev/test stack scaffolded + validated; OpenAPI contract + canonical-data-model spec + security baseline all committed; five GitHub repos public under `github.com/inguy24/` with placeholder content + Phase 1 CI scaffolding (DCO + gitleaks + dep-audit, third-party actions SHA-pinned). Phase 2 (clearskies-api MVP) ready to begin.

**Predecessor:** [archive/WEATHER-EVALUATION-PLAN.md](../archive/WEATHER-EVALUATION-PLAN.md). That plan completed its assessment work, then was superseded by this one when the project shifted from "evaluate alternative weewx skins" to "build a new modern stack from scratch." The drift-capture and MQTT-typo work it described are already complete.

---

## What this is, and what it isn't

**This project is:**
- A from-scratch modern weather UI: design-led, component-based, mobile-first, focus-driven (not data-cram).
- A small, modular, reusable set of building blocks any weewx user can install on their own station.
- GPL v3 licensed to mirror weewx itself.
- Documentation-first — each component is shippable to the community on day 1 of release.

**This project is not:**
- A fork of an existing weewx skin. Every weewx-ecosystem skin was rejected as visually amateurish (see [rules/weather-skin.md](../../rules/weather-skin.md)).
- Belchertown 2.0. Belchertown's tech model (Cheetah templates) is archaic; we're stepping outside it.
- A commercial product. No revenue ambition. Pure open-source contribution.

---

## Architecture overview

```
External provider APIs              weewx (existing)
(forecast, AQI, alerts,                 │
 earthquakes, radar)                    │ writes archive records to MariaDB
        │                               │ also publishes to weewx-mqtt → EMQX
        │ HTTPS                         │   (existing, for HA & power users)
        │                               │
        ▼                               ▼
┌────────────────────────────┐    ┌──────────────────────────┐
│  weewx-clearskies-api      │    │  weewx-clearskies-       │
│  (FastAPI/Py, sync)        │    │  realtime                │
│                            │    │  (Py, SSE bridge)        │
│  - reads MariaDB           │    │  weewx loop → SSE        │
│  - calls external APIs     │    │                          │
│    via PROVIDER PLUGIN     │    │                          │
│    MODULES internal        │    │                          │
│    to this repo (ADR-038)  │    │                          │
└──────────┬─────────────────┘    └──────────┬───────────────┘
           │  JSON over HTTPS                │  SSE over HTTPS
           ▼                                 ▼
        ┌──────────────────────────────────────────┐
        │   weewx-clearskies-dashboard             │
        │   (React 19 + Vite SPA — "Clear Skies")  │
        │   Tailwind v4 + shadcn/ui + Recharts +   │
        │   Lucide + Weather Icons                 │
        └──────────────────────────────────────────┘

      weewx-clearskies-stack (meta repo)
      ──────────────────────────────────
      docker-compose for the easy-button install,
      deploy guide, architecture diagrams,
      example HA configs (REST sensors + MQTT YAML)
```

**Clear Skies ships ZERO weewx extensions.** Every external data source — forecast, AQI, severe-weather alerts, earthquakes, radar — lives as a **plugin module inside clearskies-api** (per [ADR-038](../decisions/ADR-038-data-provider-module-organization.md)). New providers are added by writing a new module in clearskies-api, not by shipping a separate weewx extension. This is load-bearing — do not propose, design, or document weewx extensions for any data source.

---

## Components (5 separable repos under `github.com/inguy24/`)

Repo names per [ADR-004](../decisions/ADR-004-repo-naming.md). 5-component breakdown rationale per [ADR-001](../decisions/ADR-001-component-breakdown.md). Tech-stack choices per [ADR-002](../decisions/ADR-002-tech-stack.md). Distribution per [ADR-039](../decisions/ADR-039-distribution-installation-mechanism.md).

| # | Repo | Responsibility | Distribution | Required? |
|---|------|---------------|--------------|-----------|
| 1 | **weewx-clearskies-api** | HTTP/JSON API serving (a) read-only access to weewx's archive DB, and (b) external provider data via per-provider **plugin modules internal to this repo** (per [ADR-038](../decisions/ADR-038-data-provider-module-organization.md)). Python / FastAPI (sync) / SQLAlchemy 2.x. Versioned (`/api/v1/...`). | `pip install` + systemd unit, optional Docker image | Yes |
| 2 | **weewx-clearskies-realtime** | Small Python service that bridges weewx loop packets to Server-Sent Events. paho-mqtt is an optional install extra for the MQTT-subscriber mode per [ADR-005](../decisions/ADR-005-realtime-architecture.md). | `pip install` + systemd unit, optional Docker image | Yes |
| 3 | **weewx-clearskies-dashboard** | The SPA. React 19 + Vite + Tailwind v4 + shadcn/ui + Recharts + Lucide + Weather Icons. Config-driven (station name, units, palette, API URL). Built artifact is static HTML/CSS/JS. | Pre-built static bundle, git source, optional containerized `caddy + dist` | Yes |
| 4 | **weewx-clearskies-stack** | Meta repo: docker-compose for the easy-button install, deployment guide, architecture diagrams, example HA configs (`examples/home-assistant/sensors-rest.yaml` and `examples/home-assistant/sensors-mqtt.yaml`). | Just docs + compose file. The "front door" for new users. | Optional but recommended |
| 5 | **weewx-clearskies-design-tokens** | Tailwind config + named design variables (palette, spacing, typography), published as a standalone npm package so others can build their own dashboards using the same visual language. | npm package | **Deferred — Phase 6+.** Tokens still exist *inside* `weewx-clearskies-dashboard` from day 1; they just aren't extracted to a separate package until there's demand. |

### Coexistence with existing infrastructure

EMQX stays running on the `cloud` container (Home Assistant + power-user MQTT consumers keep working unchanged); `weewx-clearskies-realtime` is independent of it per [ADR-005](../decisions/ADR-005-realtime-architecture.md). New users get a working site without an MQTT broker — broker is only needed for HA integration. Operator weewx extensions that write custom archive columns flow through the column-mapping path at setup per [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md). **Clear Skies ships zero weewx extensions** — every external data source is a `weewx-clearskies-api` plugin module per [ADR-038](../decisions/ADR-038-data-provider-module-organization.md).

---

## Tech stack decisions

Locked per [ADR-002](../decisions/ADR-002-tech-stack.md). Summary below; ADR-002 is the authoritative source — when it changes, this summary follows. Do not amend this summary in place; update ADR-002 first.

| Component | Stack |
|---|---|
| API + realtime (Python) | FastAPI **sync** route handlers, SQLAlchemy 2.x **sync mode**, uvicorn behind reverse proxy. paho-mqtt as optional install extra for the realtime MQTT-subscriber mode per [ADR-005](../decisions/ADR-005-realtime-architecture.md). |
| Dashboard (JS) | React 19 + Vite, Tailwind CSS v4 (CSS-first config), shadcn/ui (copy-paste discipline), Recharts as primary chart lib, Lucide + Weather Icons. **Tremor dropped, ECharts dropped from primary** per ADR-002. |
| Real-time transport | Server-Sent Events (browser-side); MQTT optionally on the realtime-service input side per [ADR-005](../decisions/ADR-005-realtime-architecture.md). |
| TLS | Apache + certbot for native installs; Caddy (auto-LE) for the docker-compose path. |
| License | GPL v3 per [ADR-003](../decisions/ADR-003-license.md). |
| Distribution / installation | PyPI + container registries + GitHub Releases per [ADR-039](../decisions/ADR-039-distribution-installation-mechanism.md). |
| Internal dev/test environment | `weather-dev` LXD container on Ratbert (primary; per [rules/clearskies-process.md](../../rules/clearskies-process.md) "Dev/test runs in `weather-dev`"). DILBERT is editing-only. |

---

## Cross-cutting concerns (apply to every phase, every component)

### Security baseline (from day 1 — not bolted on later)

The security baseline is the union of decisions in:

- [ADR-008](../decisions/ADR-008-auth-model.md) — auth model (no end-user auth; optional `X-Clearskies-Proxy-Auth` shared secret for cross-host deploys).
- [ADR-012](../decisions/ADR-012-database-access-pattern.md) — read-only DB user enforced at the database AND a startup write-probe.
- [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) — secrets in `secrets.env` (mode 0600), env-var injection, configuration UI auth.
- [ADR-029](../decisions/ADR-029-logging-format-destinations.md) — structured JSON logs with auth/SQL-param-value redaction.
- [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) — health/ready on a separate loopback-bound port.
- [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md) — one-door reverse proxy; inner services bind to loopback (or trusted-LAN cross-host).
- [`rules/coding.md`](../../rules/coding.md) §1 — parameterized queries, input validation at trust boundaries, dangerous-function bans, IPv4/IPv6 dual-stack, dependency pinning.

The Phase 1 deliverable [`docs/contracts/security-baseline.md`](../contracts/) (not yet written) consolidates these into a per-component checklist with the cross-cutting controls not pinned to any single ADR (security headers, request size limits, systemd hardening flags, Docker hardening, `pip-audit` / `npm audit` CI, `SECURITY.md` per repo). When that document lands, this section becomes a one-line pointer to it.

### Documentation acceptance criteria (a phase isn't "done" without these)

Every component repo:
- `README.md` — one-paragraph description, screenshots, 5-line quick start, link to full docs.
- `INSTALL.md` — step-by-step for `pip`/Debian/Docker, including reverse proxy config and verification steps.
- `CONFIG.md` — every config option, defaults, examples.
- `DEVELOPMENT.md` — local dev setup, tests, contribution guide.
- `CHANGELOG.md` — release notes per tag.
- `LICENSE` — GPL v3.
- `SECURITY.md` — disclosure process, threat model.

API extras:
- Auto-generated OpenAPI spec served at `/docs`.
- `curl` example for every endpoint.
- Schema reference for the data shapes returned.

Dashboard extras:
- Theming/branding guide ("how to make it look like your station").
- Screenshot gallery.
- Component inventory: which components used and where they came from.

Stack repo extras:
- Architecture diagram (one good SVG).
- Multiple deployment topology examples (single-host, separate-host, Docker, bare-metal).
- Upgrade guide.
- Example HA configs (REST and MQTT variants).

### Versioning

- API wire contract: URL-path versioning (`/api/v1/...`), RFC 9457 errors, no support-window promise per [ADR-018](../decisions/ADR-018-api-versioning-policy.md).
- Per-repo release lifecycle: independent SemVer; pre-1.0 minor bumps may break per [ADR-032](../decisions/ADR-032-versioning-across-repos.md).
- OpenAPI spec ([`docs/contracts/openapi-v1.yaml`](../contracts/), Phase 1 deliverable) is authoritative; the dashboard code-generates a typed API client from it.

---

## Decision records

Architecture and process decisions are tracked as ADRs in [docs/decisions/](../decisions/). See the [Decision Index](../decisions/INDEX.md) for the full list. The plan references ADRs from its task tables — when a decision changes, update the relevant ADR (or supersede with a new one), not this plan body.

Project process discipline (when ADRs are written, format, lifecycle): [rules/clearskies-process.md](../../rules/clearskies-process.md).

---

## Phase plan

### Phase 1 — Architecture & contracts

Establish foundations that every later phase depends on. No production code yet — the deliverables are decisions, contracts, and scaffolds.

| Task | Status | Notes |
|------|--------|-------|
| Lock the 5-component breakdown | ✅ | [ADR-001](../decisions/ADR-001-component-breakdown.md) — Accepted |
| Tech-stack choices | ✅ | [ADR-002](../decisions/ADR-002-tech-stack.md) — Accepted |
| License = GPL v3 | ✅ | [ADR-003](../decisions/ADR-003-license.md) — Accepted |
| Repo naming finalized | ✅ | `weewx-clearskies-*` per [ADR-004](../decisions/ADR-004-repo-naming.md) — Accepted |
| Realtime architecture (direct + MQTT modes) | ✅ | [ADR-005](../decisions/ADR-005-realtime-architecture.md) — Accepted; MQTT shipped as optional install extra |
| Compliance model (end-user-managed keys) | ✅ | [ADR-006](../decisions/ADR-006-compliance-model.md) — Accepted |
| Forecast provider strategy | ✅ | [ADR-007](../decisions/ADR-007-forecast-providers.md) — Accepted. Research at [docs/reference/FORECAST-PROVIDER-RESEARCH.md](../reference/FORECAST-PROVIDER-RESEARCH.md); per-provider API docs at [docs/reference/api-docs/](../reference/api-docs/) |
| Auth model | ✅ | [ADR-008](../decisions/ADR-008-auth-model.md) — Accepted |
| Inbound traffic flow / one-door reverse-proxy architecture | ✅ | [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md) — Accepted |
| Configuration format, secret handling, configuration UI | ✅ | [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) — Accepted. ConfigObj/INI; on-demand standalone config UI (HTTPS by default with self-signed); admin user/password auth |
| Canonical internal data model | ✅ | [ADR-010](../decisions/ADR-010-canonical-data-model.md) — Accepted. 9 entity types + 2 containers; weewx-aligned camelCase JSON / snake_case Python; units = weewx target_unit with metadata block; single-station model; prose at three layers (weatherText, narrative, ForecastDiscussion). Companion full-catalog spec [`docs/contracts/canonical-data-model.md`](../contracts/canonical-data-model.md) committed 2026-05-05 — per-field enumeration, per-target_unit-system unit tables, provider→canonical mapping tables for the day-1 forecast/AQI/alerts/earthquake/radar providers. |
| Multi-station scope for v0.1 | ✅ | [ADR-011](../decisions/ADR-011-multi-station-scope.md) — Accepted. Single-station only; multi-station explicitly out-of-scope (revisit if demand surfaces); forward-compat path = non-breaking optional `stationId` field + `?station=` query param per ADR-010 |
| Design direction document | ✅ | [ADR-009](../decisions/ADR-009-design-direction.md) — Accepted 2026-05-02. Multi-page card-based dashboard with icon-rail nav, three-tier information hierarchy, operator-uploadable hero images with event-trigger system + shipped generic graphic default, Inter font with tabular figures, neutral-foundation palette + operator-picked accent + EPA AQI scale + semantic colors, all three theme modes (light/dark/auto-by-sunrise-sunset/auto-by-OS), restrained motion respecting `prefers-reduced-motion`, mobile-first non-negotiable, WCAG 2.1 AA throughout. Companion [ADR-024](../decisions/ADR-024-page-taxonomy.md) (page taxonomy) Accepted 2026-05-02 — 9 built-in pages (Now/Forecast/Charts/Almanac/Earthquakes/Records/Reports/About/Legal) with locked Lucide icons, custom-page mechanism, slim one-line footer with Legal link. Walk artifacts: [DESIGN-INSPIRATION-NOTES.md](../reference/DESIGN-INSPIRATION-NOTES.md), [BELCHERTOWN-CONTENT-INVENTORY.md](../reference/BELCHERTOWN-CONTENT-INVENTORY.md), [CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md). |
| Validate tech-stack choices via small spike | ✅ | Completed 2026-05-04 in `weather-dev:/home/ubuntu/spike/`. ADR-002 stack validated (Vite 8 + React 19 + TS 6 + Tailwind v4 + shadcn v4 + Recharts 3.8 + Lucide). Bundle 164.52 KB gzipped — under [ADR-033](../decisions/ADR-033-performance-budget.md)'s 200 KB budget by ~35 KB. Two scaffold-time footguns documented for the dashboard repo: `"overrides": { "react-is": "^19.2.0" }` in `package.json` before `npm install recharts`, and `"ignoreDeprecations": "6.0"` in `tsconfig.app.json` until TS7. Findings + re-run command: [docs/reference/SPIKE-FINDINGS.md](../reference/SPIKE-FINDINGS.md). First pass off-spec (used ECharts) per [PLAN-VS-ADR-AUDIT-2026-05-04.md](../reference/PLAN-VS-ADR-AUDIT-2026-05-04.md); second pass against the correct stack confirmed every ADR-002 choice. |
| Stand up `weather-dev` LXD container on ratbert | ✅ | Stood up 2026-05-04 at `192.168.2.113` (DHCP/SLAAC on `br-vlan2`). Ubuntu 24.04, `security.nesting=true` (Docker-in-LXC), 6 GB memory cap. Provisioned: Docker Engine 29.4 + Compose v5, Node 22 LTS, Python 3.12, uv, git, build-essential. Brought forward from the original Phase 4 entry — Windows host (DILBERT) is for editing only; all `docker compose`, `pytest`, `npm`, `vite`, etc. runs inside the container per [rules/clearskies-process.md](../../rules/clearskies-process.md) "Dev/test runs in `weather-dev`". Roster entry in [reference/ratbert-lxd.md](../../../Windows%20Server/reference/ratbert-lxd.md). |
| Build docker-compose dev/test stack | ✅ | Scaffolded 2026-05-04 at [`repos/weewx-clearskies-stack/dev/`](../../repos/weewx-clearskies-stack/dev/). MariaDB 10.11 service + Python seed loader. Snapshot capture script (`snapshot/capture.py`) is host-side, SQLAlchemy-reflection-based — whatever schema is live in production (stock + extension columns per [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md)) flows through. Loader (`seed/seed_loader.py`) is backend-agnostic via a small generic-type map; same snapshot loads into MariaDB or SQLite per [ADR-012](../decisions/ADR-012-database-access-pattern.md). Compose profiles `mariadb` / `sqlite` / `all` select target backend; CI matrix runs both as parallel jobs. Validated end-to-end inside `weather-dev` 2026-05-04: both profiles built, MariaDB came up healthy, both seed runs loaded synthetic fixture and verified row counts. Validation surfaced and fixed two defects the prior Windows smoke test couldn't reach — invalid `pip install --require-hashes=false` Dockerfile syntax, and SQLite-volume permission collision with non-root container `USER`. |
| Write the API contract (OpenAPI spec) | ✅ | Committed 2026-05-05 at [`docs/contracts/openapi-v1.yaml`](../contracts/openapi-v1.yaml). OpenAPI 3.1, 23 paths, 53 schemas; validates clean against `openapi-spec-validator`. Endpoint inventory derived from [ADR-024](../decisions/ADR-024-page-taxonomy.md) page taxonomy + [ADR-010](../decisions/ADR-010-canonical-data-model.md) canonical entities. URL-path versioning + RFC 9457 errors per [ADR-018](../decisions/ADR-018-api-versioning-policy.md). Drove [ADR-040](../decisions/ADR-040-earthquake-providers.md) and an `EarthquakeRecord` addition to [ADR-010](../decisions/ADR-010-canonical-data-model.md). |
| Stand up the 5 GitHub repos | ✅ | Created 2026-05-05 under `github.com/inguy24/`. All five public, named per [ADR-004](../decisions/ADR-004-repo-naming.md), licensed GPL v3 per [ADR-003](../decisions/ADR-003-license.md): [api](https://github.com/inguy24/weewx-clearskies-api), [realtime](https://github.com/inguy24/weewx-clearskies-realtime), [dashboard](https://github.com/inguy24/weewx-clearskies-dashboard), [stack](https://github.com/inguy24/weewx-clearskies-stack) (already carries Phase 1 docker-compose dev content under `dev/`), [design-tokens](https://github.com/inguy24/weewx-clearskies-design-tokens) (Phase 1 name-reservation placeholder per ADR-001 — populated in Phase 6+). Each has `README.md` (placeholder), `LICENSE` (GPL v3), `SECURITY.md` (placeholder), language-appropriate `.gitignore`. Layout follows [ADR-036](../decisions/ADR-036-workspace-layout.md): each child is an independent git repo nested under `repos/`; meta `.gitignore` excludes `repos/*` to avoid double-tracking; [`weather-clearskies.code-workspace`](../../weather-clearskies.code-workspace) created with the meta folder + all five children. DILBERT→weather-dev sync is via [`scripts/sync-to-weather-dev.sh`](../../scripts/sync-to-weather-dev.sh) (manual fire after pushing). |
| Wire CI scaffolding | ✅ | Phase 1 minimal CI landed 2026-05-05 across all five repos. Three workflows per repo: `dco.yml` (verifies Signed-off-by trailer on every PR commit per [ADR-003](../decisions/ADR-003-license.md)), `gitleaks.yml` (secret scan on PR/push to main + nightly cron), `dep-audit.yml` (`pip-audit` for Python repos / `npm audit --audit-level=high` for JS repos / both for stack's `dev/` infrastructure; placeholder-tolerant — skips quietly until a manifest lands). Third-party actions pinned by SHA per [`coding.md`](../../rules/coding.md) §1: `actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5` (v4), `actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065` (v5), `actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020` (v4); gitleaks installed by tarball download (avoids the gitleaks-action license requirement on org repos). Lint/test/release-on-tag workflows + the [ADR-012](../decisions/ADR-012-database-access-pattern.md) DB matrix for api are deferred to Phase 2/3/4 when each repo has actual code to exercise. |
| Security baseline document | ✅ | Committed 2026-05-05 at [`docs/contracts/security-baseline.md`](../contracts/security-baseline.md). Per-component checklist consolidating [ADR-003](../decisions/ADR-003-license.md) + [ADR-008](../decisions/ADR-008-auth-model.md) + [ADR-012](../decisions/ADR-012-database-access-pattern.md) + [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) + [ADR-029](../decisions/ADR-029-logging-format-destinations.md) + [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) + [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md) + [`coding.md`](../../rules/coding.md) §1, plus cross-cutting controls (security headers, request limits, rate limit, systemd/Docker hardening, `pip-audit`/`npm audit`/`gitleaks` CI gates, `SECURITY.md` per repo). Four components covered (api / realtime / dashboard / stack); design-tokens deferred per ADR-001. §8 documents six known gaps & opinionated defaults — three with real teeth (multi-worker rate-limit storage, 1 MiB request body default, markdown sanitization regression risk) and three TODOs (realtime health port, DCO mechanism, dashboard CSP iteration). Self-audit pressure-tested ADR-030's split-port architecture; user confirmed keep-as-is. |
| Optimize older ADRs for conciseness | ✅ | Completed 2026-05-04. Nine bloated ADRs cut in place per item-7 lifecycle (ADR-008, ADR-009, ADR-010, ADR-011, ADR-024, ADR-027, ADR-036, ADR-037, ADR-038). Remaining 28 ADRs audited paragraph-by-paragraph for content density and confirmed tight — no filler, every paragraph load-bearing. Conciseness rule in [rules/clearskies-process.md](../../rules/clearskies-process.md) clarified: bloat is content density, not line count. Orphan `ADR-035-observation-entity-model.md` deleted. |

### Phase 2 — clearskies-api MVP

The data layer. Boring, secure, fast.

**Multi-agent execution:** Phase 2 onward uses Claude Code Agent Teams (experimental, gated by `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Lead = Opus (this session). Sonnet teammates implement; Opus `clearskies-auditor` teammate reviews all output before lead synthesis. Custom agent definitions in [.claude/agents/](../../.claude/agents/). Recommended team size 3–5; auditor counts toward the limit.

| Task | Status | Teammate(s) | Notes |
|------|--------|-------------|-------|
| FastAPI scaffold | ⬜ | `api-dev` | With auth middleware, CORS config, security headers, rate limiting from day 1 |
| Read-only DB user enforcement at startup | ⬜ | `api-dev` | Service refuses to start if user has write privileges |
| Endpoints: `/api/v1/current`, `/archive`, `/aqi`, `/units`, `/station`, `/health` | ⬜ | `api-dev` + `test-author` parallel | Match the OpenAPI contract from Phase 1 |
| SQLite + MariaDB support behind one config knob | ⬜ | `api-dev` + `test-author` | Default to whichever the local weewx uses; CI runs both backends per [ADR-012](../decisions/ADR-012-database-access-pattern.md) |
| Auto-generated OpenAPI spec at `/api/v1/docs` | ⬜ | `api-dev` | FastAPI does this for free |
| Test suite with realistic mock data | ⬜ | `test-author` (parallel with `api-dev`) | Unit + integration; integration runs against the docker-compose dev/test stack |
| systemd unit + Docker image | ⬜ | `api-dev` | Both shipped |
| Documentation (`README`, `INSTALL`, `CONFIG`, `SECURITY`, `DEVELOPMENT`) | ⬜ | `docs-author` | Acceptance gate |
| Tagged release v0.1 | ⬜ | lead (Opus) | First public artifact |

Dev environment: docker-compose dev/test stack from Phase 1 (`clearskies-stack/dev/`) — real MariaDB seeded with production weewx archive data. Same backend as production; defense in depth via `SELECT`-only grant per [ADR-012](../decisions/ADR-012-database-access-pattern.md).

### Phase 3 — clearskies-dashboard MVP

The visible artifact. Where design discipline gets exercised. Multi-agent execution per Phase 2 prelude — `dashboard-dev` (Sonnet) implements, `test-author` (Sonnet) writes Playwright + axe-core suites in parallel, `auditor` (Opus) reviews against design + a11y ADRs.

| Task | Status | Teammate(s) | Notes |
|------|--------|-------------|-------|
| Scaffold from chosen starter template | ⬜ | `dashboard-dev` | Likely a Tremor/shadcn dashboard template; clone, strip to skeleton, replace with our design |
| Wire to **mock data first** | ⬜ | `dashboard-dev` | UI develops independently of weewx; fast feedback loop |
| Implement priority pages (Now, Forecast, Charts) | ⬜ | `dashboard-dev` (one task per page; lead may run 2–3 page-builder teammates in parallel rounds) | Pages are mostly independent per [ADR-024](../decisions/ADR-024-page-taxonomy.md) — strong fit for parallel teammates |
| Implement remaining built-in pages (Almanac, Earthquakes, Records, Reports, About, Legal) | ⬜ | `dashboard-dev` (parallel rounds) | 9 built-in pages total per [ADR-024](../decisions/ADR-024-page-taxonomy.md); operator-hideable |
| Wire to real `clearskies-api` | ⬜ | `dashboard-dev` (coordinates with `api-dev` if contract questions surface) | Replace the mock with the typed API client generated from `docs/contracts/openapi-v1.yaml` |
| Mobile-first verification | ⬜ | `dashboard-dev` + `auditor` | Real device + Chrome DevTools |
| Light/dark mode + auto-by-sunrise/sunset + auto-by-OS | ⬜ | `dashboard-dev` | Per [ADR-023](../decisions/ADR-023-light-dark-mode-mechanism.md) |
| Theming/branding config | ⬜ | `dashboard-dev` | CSS variables + curated accent palette + operator logo upload per [ADR-022](../decisions/ADR-022-theming-branding-mechanism.md) |
| Documentation | ⬜ | `docs-author` | Including the theming guide and screenshot gallery |
| Tagged release v0.1 | ⬜ | lead (Opus) | Second public artifact |

### Phase 4 — clearskies-realtime + integration test environment

Multi-agent for the SSE bridge work; deploy rehearsal is single-track (lead-driven).

| Task | Status | Teammate(s) | Notes |
|------|--------|-------------|-------|
| `clearskies-realtime` service: SSE bridge from weewx loop packets | ⬜ | `realtime-dev` + `test-author` | Minimal, focused, ~few hundred lines of Python |
| Wire dashboard to live SSE updates | ⬜ | `dashboard-dev` | Replace polling with `EventSource` |
| Spin up an ephemeral `weather-deploy-rehearsal` LXD container on Ratbert | ⬜ | lead (Opus) | Separate from the long-lived `weather-dev` container (stood up in Phase 1). Pristine container that gets the public docs treatment — mirrors what a new user would do, cross-machine, manual gates. Tear down + rebuild for each rehearsal pass. |
| Full end-to-end deploy rehearsal there using the public docs only | ⬜ | lead (Opus) + `auditor` | If the public docs don't work, the public docs are wrong — fix them |
| Polish, accessibility audit, perf audit | ⬜ | `dashboard-dev` + `auditor` | Lighthouse, axe |
| Documentation completeness review | ⬜ | `docs-author` + `auditor` | All `README`/`INSTALL`/`CONFIG` polished |

### Phase 5 — UAT & cutover

| Task | Status | Notes |
|------|--------|-------|
| Open `next.weather.shaneburkhardt.com` for UAT | ⬜ | Apache vhost on cloud + Let's Encrypt cert; basic-auth or API-key gated while beta |
| Verify against production-equivalent data for a full week | ⬜ | Catch periodic-job bugs (daily/weekly aggregations) |
| DNS/Apache cutover: `weather.shaneburkhardt.com` → new stack | ⬜ | Atomic-ish; old Belchertown setup archived but not deleted |
| Retire the `next.` subdomain | ⬜ | After cutover successful for a week |
| Public release: GitHub repos go public, weewx forum announcement | ⬜ | Coordinate with the documentation-completeness pass below |
| Documentation-completeness pass | ⬜ | Final polish before public eyes see it |

### Phase 6 — Iterate (optional/ongoing)

| Task | Status | Notes |
|------|--------|-------|
| Community feedback triage | ⬜ | Issue templates, discussion forum |
| Optional: extract `clearskies-design-tokens` to its own npm package | ⬜ | Only if anyone asks |
| Optional: PWA (installable, offline-capable) | ⬜ | Service worker, manifest |
| Optional: mobile companion app on the same API | ⬜ | React Native or Capacitor wrap of the SPA |
| Optional: HA custom integration repo | ⬜ | Only if YAML-via-docs proves insufficient |

---

## Open decisions

Authoritative status of every ADR (Pinned / Proposed / Accepted) lives in [docs/decisions/INDEX.md](../decisions/INDEX.md). This plan does not duplicate that list.

One non-ADR doc task: INSTALL docs must include a matrix of supported weewx environments (native Debian/Ubuntu, LXD container, Docker, Proxmox VM, Raspberry Pi) with the recommended install path for clearskies-api and clearskies-realtime in each.

---

## Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Scope creep — "Apple Weather aesthetic" is hard | Phase 1 design-direction document is the contract; Phase 3 reviews against it |
| Long build, no visible progress | Phase 3 uses mock data so the UI is browser-visible from Day 1; user can react early |
| Documentation rot | Documentation is a per-phase acceptance gate, not a backlog item |
| Breaking weewx compatibility | API targets the *stable* weewx schema; covered by tests against multiple weewx versions in CI |
| Letting GPL v3 deter contributions | Counter-balanced by ecosystem alignment with weewx; document the rationale in `LICENSE-RATIONALE.md` |
| Solo maintenance burden after launch | `weewx-stack` docs explicitly invite forks; no commercial dependence on growth |

---

## Decision log

- **2026-04-29** — predecessor `WEATHER-EVALUATION-PLAN.md` archived. Project pivoted from "evaluate alternative weewx skins" to "build new modern stack." Driver: every weewx-ecosystem skin reads as visually amateurish; lateral move would not solve the redesign goal. Rule captured at [rules/weather-skin.md](../../rules/weather-skin.md).
- **2026-04-29** — five-component breakdown adopted. EMQX retained for HA/MQTT power-user channel; `clearskies-realtime` introduced as separate browser-only SSE channel.
- **2026-04-29** — license set to GPL v3 to mirror weewx.
- **2026-04-29** — name "Clear Skies" verified clear in weewx ecosystem (no skin/repo conflicts).
- **2026-04-29** — `clearskies-design-tokens` deferred to Phase 6+; tokens exist internally from day 1 but aren't published as a standalone package until demand exists.
- **2026-04-29** — MQTT typo (`mgtt://` → `mqtt://`) confirmed already fixed on live server. Server-side data publication verified healthy. Browser-side live delivery verified by user. Original "regular users don't see live data" symptom fully resolved. [docs/archive/MQTT-TYPO-FIX-PLAN.md](../archive/MQTT-TYPO-FIX-PLAN.md) archived as superseded.
- **2026-05-01** — [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md) Accepted. One-door reverse-proxy architecture: all public traffic through a single web server; inner services bind to localhost by default; upstream provider calls originate server-side. Caddy bundled in the docker-compose distribution; user-supplied web server (Apache, nginx, Caddy) for native installs.
- **2026-05-01** — [ADR-008](../decisions/ADR-008-auth-model.md) Accepted. No end-user authentication built in (consistent with weewx skin ecosystem); users add proxy auth as a deployment choice. Optional shared-secret header for cross-host proxy↔inner-service deploys. Service warns but does not refuse to start when bound to non-loopback without a secret.
- **2026-05-01** — [ADR-027](../decisions/ADR-027-config-and-setup-wizard.md) Accepted. ConfigObj/INI `.conf` files at `/etc/weewx-clearskies/`; secrets in `secrets.env` (mode 0600); on-demand standalone web configuration UI in `weewx-clearskies-stack` (HTTPS by default with self-signed cert and printed fingerprint, admin user/password auth); no bind-range filter (operator's network, operator's call); IPv4/IPv6 dual-stack; disable-able for power users via `[ui] enabled = false`.
- **2026-05-01** — Project-wide IPv4/IPv6-agnostic coding rule landed in [rules/coding.md](../../rules/coding.md) Section 1: governs the configuration UI's listener, the api/realtime listeners, outbound provider calls, and any future networking code. Concrete dos/don'ts: dual-stack defaults, `getaddrinfo` instead of `gethostbyname`, `ipaddress` library instead of regex IP validation, brackets around IPv6 in URLs, `INET`/`VARBINARY(16)` for storage.
- **2026-05-01** — [ADR-010](../decisions/ADR-010-canonical-data-model.md) Accepted. 8 entity types (Observation, ArchiveRecord, HourlyForecastPoint, DailyForecastPoint, ForecastDiscussion, AlertRecord, AQIReading, StationMetadata) + 2 containers (ForecastBundle, AlertList); weewx-aligned camelCase JSON keys / snake_case Python field names via Pydantic alias_generator; canonical units = weewx's configured `target_unit` system with units metadata block in every response; UTC ISO-8601 with `Z` suffix; all-fields-optional with explicit nulls; single-station type model; custom weewx columns flow through `extras` slot; prose captured at three layers (weatherText per point, narrative per day, ForecastDiscussion per bundle). Full per-field catalog deferred to `docs/contracts/canonical-data-model.md` (Phase 1 deliverable alongside OpenAPI spec).
- **2026-05-01** — [ADR-011](../decisions/ADR-011-multi-station-scope.md) Accepted. v0.1 ships single-station only; multi-station explicitly out-of-scope ("not planned, revisit if concrete demand surfaces"). One API ↔ one weewx archive DB ↔ one StationMetadata ↔ one realtime stream ↔ one dashboard. Forward-compat path is non-breaking per ADR-010: optional `stationId` per record, optional `?station=<id>` query param, list `StationMetadata`. No tenant model in auth ([ADR-008](../decisions/ADR-008-auth-model.md)) or configuration UI ([ADR-027](../decisions/ADR-027-config-and-setup-wizard.md)).
- **2026-05-02** — 12-category content walk complete. Output: [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md). New cross-cutting threads locked: PWS-contributor track as default lens for "free" providers, internal plug-in-style provider modules ([ADR-038](../decisions/INDEX.md) Pinned), distribution mechanism open thread ([ADR-039](../decisions/INDEX.md) Pinned), render-time sensor-availability detection (per-station-adaptive rendering), user-defined records distinct from custom charts, i18n first-class for v0.1 (13 locales from numisync.com), accessibility WCAG 2.1 AA load-bearing project-wide (rules at [rules/coding.md](../../rules/coding.md) §5). Two new artifacts: [NOAA-COOP-CWOP-REPORTING-RESEARCH.md](../reference/NOAA-COOP-CWOP-REPORTING-RESEARCH.md), [CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- **2026-05-02** — [ADR-009](../decisions/ADR-009-design-direction.md) Accepted. Multi-page card-based dashboard with icon-rail nav; three-tier information hierarchy (always-visible / tile-body / click-to-expand); operator-uploadable hero images with event-trigger system (default / active alert / weather condition / date range / season / time-of-day) + shipped generic in-house-authored graphic default (NOT photography, license-clean); Inter font with tabular figures for live data; neutral-foundation palette + one operator-picked accent + EPA AQI scale + semantic alert/warning/success/info colors; all three theme modes (light / dark / auto-by-sunrise-sunset / auto-by-OS); restrained motion respecting `prefers-reduced-motion`; mobile-first non-negotiable; WCAG 2.1 AA throughout. Operator licensing acknowledgment required at every image upload.
- **2026-05-02** — [ADR-024](../decisions/ADR-024-page-taxonomy.md) Accepted. Nine built-in pages — Now (`house`), Forecast (`cloud-sun-rain`), Charts (`chart-line`), Almanac (`moon`), Earthquakes (`activity`), Records (`trophy`), Reports (`file-text`), About (`info`), Legal (`scale`) — each individually hide-able by operator. Custom-page mechanism: operator picks slug + name + Lucide icon (from a curated subset, Phase 3) + nav position + content blocks (canonical cards + markdown narrative + custom charts/records/media). Marine deferred per cat 7. Configuration UI is NOT in the public dashboard nav (separate per ADR-027). Default per-page card composition synthesized from the 12-category content walk. Reports page setup-time precondition: dashboard checks for `/NOAA/*.txt` files at startup; absent → page hidden + operator prompted to enable weewx NOAA generator.
- **2026-05-02** — [ADR-038](../decisions/ADR-038-data-provider-module-organization.md) Accepted. Project-wide pattern: every external data source (forecast / AQI / alerts / earthquakes / radar) is a plugin module in clearskies-api at `weewx_clearskies_api/providers/{domain}/{provider}.py`. Five module responsibilities, capability registry, error taxonomy. **Clear Skies ships ZERO weewx extensions.**
- **2026-05-02** — [ADR-013](../decisions/ADR-013-aqi-handling.md) Accepted. AQI providers as clearskies-api plugin modules per ADR-038. Day-1 set: Aeris / OpenMeteo / OpenWeatherMap / IQAir. Two operator paths: (A) own weewx extension writing custom columns mapped via [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md), (B) clearskies-api AQI plugin. Historical AQI persisted by clearskies-api (mechanism = Phase 2). AQI alerts via NWS pipeline (AQA / AS_Y).
- **2026-05-02** — [ADR-035](../decisions/ADR-035-user-driven-column-mapping.md) Accepted. Schema introspection + auto-map stock weewx columns + operator maps non-stock at setup. AQI is the worked example. Persists in operator config; re-mappable via configuration UI.
- **2026-05-02** — [ADR-014](../decisions/ADR-014-almanac-data-source.md) Accepted. Skyfield (not pyephem) for all almanac calculations; server-side; NASA JPL DE421 ephemerides.
- **2026-05-02** — [ADR-026](../decisions/ADR-026-accessibility-commitments.md) Accepted. WCAG 2.1 Level AA project-wide; per-change audit + pre-ship audit; release-blocking. Implementation rules in [rules/coding.md](../../rules/coding.md) §5.
- **2026-05-02** — [ADR-021](../decisions/ADR-021-i18n-strategy.md) Accepted. 13 locales for v0.1 (en/de/es/fil/fr/it/ja/nl/pt-PT/pt-BR/ru/zh-CN/zh-TW); no RTL. Framework / extraction tooling deferred to Phase 2–3.
- **2026-05-02** — [ADR-023](../decisions/ADR-023-light-dark-mode-mechanism.md) Accepted. `data-theme` attribute on `<html>`; React theme provider resolves operator default + user override; auto-sunrise-sunset uses api-supplied sunrise/sunset; auto-OS uses `prefers-color-scheme`.
- **2026-05-02** — [ADR-022](../decisions/ADR-022-theming-branding-mechanism.md) Accepted. CSS variables on `:root` / `[data-theme="dark"]`; curated 6-entry accent palette (no free-form picker — protects WCAG AA); operator logo upload (light + optional dark, auto-invert with warning); `custom.css` escape hatch documented as best-effort. No Cheetah hooks.
- **2026-05-02** — [ADR-015](../decisions/ADR-015-radar-map-tiles-strategy.md) Accepted. Leaflet + OSM base. 8 day-1 radar provider modules in `weewx_clearskies_api/providers/radar/` (rainviewer/openweathermap/aeris/iem_nexrad/noaa_mrms/msc_geomet/dwd_radolan/mapbox_jma) + `iframe` config slot. Setup wizard suggests by lat/lon. clearskies-api proxies keyed providers server-side per ADR-037. OWM labeled "Model precipitation," not real radar.
- **2026-05-02** — [ADR-018](../decisions/ADR-018-api-versioning-policy.md) Accepted. URL-path versioning (`/api/v1/...`); major bump only on breaking changes; **no support-window promise** — software is AS-IS under GPL v3 ([ADR-003](../decisions/ADR-003-license.md)); `Deprecation`/`Sunset` headers (RFC 8594) are advisory technical signals, not commitments. All errors use RFC 9457 `application/problem+json`.
- **2026-05-02** — [ADR-019](../decisions/ADR-019-units-handling.md) Accepted. Server passes weewx `target_unit` through with units metadata block per ADR-010; no server-side conversion; no per-user override at v0.1 (Phase 6+ enhancement via localStorage + metadata block). Operator picks units in `weewx.conf` before installing.
- **2026-05-02** — [ADR-020](../decisions/ADR-020-time-zone-handling.md) Accepted. UTC on wire; station-local TZ for display (visitors see the station's clock, not their browser's); IANA TZ identifier in StationMetadata; source priority = operator config → weewx config → derived from lat/lon. Browser uses `Intl.DateTimeFormat`. No per-user override at v0.1.
- **2026-05-02** — [ADR-029](../decisions/ADR-029-logging-format-destinations.md) Accepted. Structured JSON one-line-per-record to stdout (12-factor); required fields `timestamp`/`level`/`logger`/`message`/`request_id`; stdlib `logging` + small JSON formatter (no `structlog` dep); `logging.Filter` strips auth headers, API keys, SQL parameter values; capture via `journalctl` or `docker logs`; log shipping is operator deploy concern.
- **2026-05-02** — [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) Accepted. `/health/live` + `/health/ready` on a separate loopback port (default 8081 for api); degraded → 200 (no orchestrator restart loops on transient provider failures); 503 only when service genuinely cannot serve; unauthenticated by virtue of loopback default. Provider readiness signals route through ADR-038 capability registry.
- **2026-05-02** — [ADR-012](../decisions/ADR-012-database-access-pattern.md) Accepted. SQLAlchemy 2.x; read-only DB user enforced both at the database (`SELECT`-only grant) AND a startup write-probe that refuses to start the service if write permissions exist; SQLite uses `?mode=ro` URI; runtime schema reflection populates the column registry that ADR-035 mapping consumes; per-request session via FastAPI DI.
- **2026-05-02** — [ADR-017](../decisions/ADR-017-provider-response-caching.md) Accepted. Pluggable cache backend: `memory` default (zero deps; LRU+TTL via `cachetools`), `redis` optional (configurable via `CLEARSKIES_CACHE_URL`). uvicorn ships single-worker by default; multi-worker deploys MUST use Redis or burn API quotas N×. Per-provider TTL declared in module capability per ADR-038.
- **2026-05-02** — [ADR-016](../decisions/ADR-016-severe-weather-alerts.md) Accepted. Alerts as their own clearskies-api domain (`weewx_clearskies_api/providers/alerts/`). Day-1 set: `nws` (US, free), `aeris` (US/CA/EU, PWS-contributor track), `openweathermap` (global, paid One Call 3.0). Single source per deploy; setup wizard suggests by lat/lon. Operators in uncovered regions see no banner (cat 10 sensor-availability). NWS AQA/AS_Y AQI alerts ride this pipeline.
- **2026-05-02** — Phase 2 ADR backlog closed. All Phase 2 blocking ADRs (007, 010, 011, 012, 013, 016, 017, 018, 019, 020, 027, 029, 030, 035, 037, 038) are Accepted.
- **2026-05-02** — [ADR-025](../decisions/ADR-025-browser-support-matrix.md) Accepted. Modern evergreen browsers, last 2 years (~Chrome 110+, Firefox 110+, Safari 16.4+, iOS Safari 16.4+, Android Chrome). Browserslist `>0.5%, last 2 years, not dead, not op_mini all`. No IE, no pre-ES2022 baseline.
- **2026-05-02** — [ADR-033](../decisions/ADR-033-performance-budget.md) Accepted. Targets (NOT release gates): Lighthouse Performance ≥ 90 on primary pages; CWV "Good" thresholds (LCP ≤ 2.5s / INP ≤ 200ms / CLS ≤ 0.1); Now-page initial JS bundle ≤ 200 KB gzipped; p95 API latency per endpoint class. Misses are documented in `docs/audits/<release>.md` and the release ships anyway. Contrast with ADR-026 a11y, which IS release-blocking.
- **2026-05-02** — [ADR-031](../decisions/ADR-031-observability-metrics.md) Accepted. Logs ([ADR-029](../decisions/ADR-029-logging-format-destinations.md)) are the default observability surface; Prometheus `/metrics` is opt-in via `CLEARSKIES_METRICS_ENABLED=true`, served on the health port (loopback default per ADR-030). HTTP/provider/cache/DB metrics with bounded cardinality. OpenTelemetry deferred to Phase 6+.
- **2026-05-02** — [ADR-032](../decisions/ADR-032-versioning-across-repos.md) Accepted. Independent SemVer per repo (no lockstep); pre-1.0 minor bumps may ship breaking changes; major-bump triggers named per repo (api breaking change → api major; SSE event format change → realtime major; config schema break → dashboard major; matrix bump → stack major). Cross-repo compatibility matrix in `clearskies-stack` README. ADR-018 (api wire contract) and ADR-032 (repo release lifecycle) deliberately separate concerns.
- **2026-05-02** — [ADR-034](../decisions/ADR-034-deployment-topology-default.md) Accepted. Default topology: single-host, co-located with weewx. Two install paths both single-host — native (`pip install` + systemd, operator's existing web server) for existing weewx operators, or `clearskies-stack` docker-compose (Caddy-bundled, auto-LE) for new operators. weewx itself NOT bundled in compose. Multi-host supported but reference-only.
- **2026-05-02** — Process rule updates ([rules/clearskies-process.md](../../rules/clearskies-process.md)): item 7 — corrections to Accepted ADRs edit in place (no supersession clutter). Conciseness rule added — standard ADRs ~80 lines, parent-pattern ADRs ~150 lines. Cleanup pass on bloated existing ADRs (ADR-009, ADR-038) added to Phase 1 task table.
- **2026-05-04** — [ADR-039](../decisions/ADR-039-distribution-installation-mechanism.md) Accepted. Three distribution channels: PyPI (`pip install weewx-clearskies-api`/`-realtime`), GHCR/Docker Hub container images (api/realtime/dashboard, used by `clearskies-stack` docker-compose), and GitHub Releases source tarballs. Per-OS: Linux native or Docker; macOS native or Docker; Windows = Docker Desktop, full stop. No MSI / .pkg / AppImage / Snap / Flatpak at v0.1 — bespoke OS installers are a maintenance black hole for a single-maintainer GPL project. Sibling [ADR-028](../decisions/ADR-028-update-mechanism.md) (update mechanism) still Pinned at this point.
- **2026-05-04** — [ADR-028](../decisions/ADR-028-update-mechanism.md) Accepted. Updates use the same channel as install: `pip install -U weewx-clearskies-api`/`-realtime` for native (restart unit), `docker compose pull && docker compose up -d` for Docker, source-tarball reinstall for source builds. No in-app self-update, no auto-update daemon (Watchtower etc.) at v0.1. CHANGELOG.md per repo is the single source of upgrade-relevant info; cross-repo compatibility matrix lives in `clearskies-stack/README.md` per ADR-032. AS-IS posture inherited from ADR-018: no LTS, no security backports, no EOL schedule. Configuration preservation locked in: native pip doesn't touch `/etc/weewx-clearskies/`; Docker compose bind-mounts the config dir; config-file schema changes are always CHANGELOG-flagged, never silent. **Phase 1 ADR backlog closed** — every Pinned slot in INDEX.md is now Accepted. Next Phase 1 task: cleanup pass on bloated ADRs per the conciseness rule.
- **2026-05-04** — Multi-agent setup landed for Phase 2+ coding work. Pattern: Claude Code Agent Teams (experimental, gated by `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Lead = Opus session. Roster of 6 custom agents in `.claude/agents/`: `clearskies-api-dev` (Sonnet, FastAPI/SQLAlchemy backend), `clearskies-dashboard-dev` (Sonnet, React/Tailwind/shadcn/Tremor SPA), `clearskies-realtime-dev` (Sonnet, SSE bridge), `clearskies-test-author` (Sonnet, pytest/Playwright/axe-core; integration tests run against the docker-compose dev/test stack with both runtime backends per [ADR-012](../decisions/ADR-012-database-access-pattern.md)), `clearskies-docs-author` (Sonnet, README/INSTALL/CONFIG/SECURITY/DEVELOPMENT/CHANGELOG), and `clearskies-auditor` (Opus — dedicated review-only role; cites ADR-NNN per finding; never implements). Env var enabled in `~/.claude/settings.json`. Phase 2/3/4 task tables annotated with teammate assignments. Known limitations accepted: no `/resume` with active in-process teammates, one team per session, no nested teams, Windows = in-process mode only (split-pane needs tmux/iTerm2). Fallback if pattern doesn't work in practice: revert to subagent orchestration (Pattern A). Auditor role added at user request to cover the case where peer-to-peer teammate coordination doesn't always route through the lead — the auditor is a "check the work" guarantor regardless of how teammates communicate among themselves.
- **2026-05-04** — Phase 1 task added: docker-compose dev/test stack with MariaDB + backend-agnostic Python seed loader, sourced from a 30–60 day production weewx archive snapshot. Same dataset loads into both runtime backends per [ADR-012](../decisions/ADR-012-database-access-pattern.md); CI matrix runs every integration test against both. Output lands in `clearskies-stack/dev/`. Driver: testing against a different backend than we deploy on is testing-the-wrong-thing; keeping SQLite + MariaDB at runtime means we have to actually validate both. Weather observation data is public-by-design (temp/humidity/wind/rain on weather.shaneburkhardt.com, lat/lon broadcast to CWOP) so no sanitization required. Sequencing: parallel with the spike, both before the OpenAPI contract task.
- **2026-05-04** — Phase 1 task 1 (tech-stack spike) **complete**. ADR-002 stack validated end-to-end inside `weather-dev`: Vite 8 + React 19 + TS 6 + Tailwind v4 + shadcn v4 + Recharts 3.8 + Lucide. Production bundle 164.52 KB gzipped — fits [ADR-033](../decisions/ADR-033-performance-budget.md)'s 200 KB budget with ~35 KB headroom on a Now-page mock with one chart on screen. Two scaffold-time footguns confirmed and documented for the eventual dashboard repo: (1) `"overrides": { "react-is": "^19.2.0" }` in `package.json` before installing Recharts (without it, install fails with ERESOLVE on React 19); (2) `"ignoreDeprecations": "6.0"` in `tsconfig.app.json` to silence the TS6 `baseUrl` deprecation warning that shadcn's CLI scaffold emits. Recharts wrapper components must include a screen-reader-only `<table>` fallback to satisfy [ADR-026](../decisions/ADR-026-accessibility-commitments.md) / `rules/coding.md` §5.5. No ADR amendments needed — every ADR-002 choice was confirmed correct. Findings: [docs/reference/SPIKE-FINDINGS.md](../reference/SPIKE-FINDINGS.md).
- **2026-05-04** — Plan-vs-ADR audit completed. Drift fixed in plan body: architecture diagram, components table, tech stack table, security baseline section, versioning section, coexistence section, and Phase 1 task 1 description all updated to match the 39 Accepted ADRs verbatim or to defer to them as authoritative pointers. Trigger: Phase 1 spike (task 1) was built against the plan body's stale tech-stack table (Tremor + ECharts) when ADR-002 had already locked shadcn + Recharts. Audit findings + every drift fixed: [docs/reference/PLAN-VS-ADR-AUDIT-2026-05-04.md](../reference/PLAN-VS-ADR-AUDIT-2026-05-04.md). New process sub-rule landed in [rules/clearskies-process.md](../../rules/clearskies-process.md) "Read the ADR before the plan." Spike artifact + first-pass findings preserved in [docs/reference/SPIKE-FINDINGS.md](../reference/SPIKE-FINDINGS.md); second pass against the ADR-002-correct stack (Recharts) is the next Phase 1 task.
- **2026-05-04** — `weather-dev` LXD container stood up on ratbert at `192.168.2.113` (DHCP/SLAAC on `br-vlan2`). Ubuntu 24.04, `security.nesting=true` (Docker-in-LXC), 6 GB memory cap. Provisioned with Docker Engine + Compose, Node 22 LTS, Python 3.12, uv, git, build-essential. **Brought forward from Phase 4 to Phase 1** because the Windows workstation (DILBERT) is a misfit for the project's runtime stack — Docker Desktop heavyweight, no native Linux containers, Playwright/axe-core Linux-first, integration tests want a real systemd-style environment. Rule landed in [rules/clearskies-process.md](../../rules/clearskies-process.md) "Dev/test runs in `weather-dev`": DILBERT is for editing/git/orchestration only; all `docker compose`, `pytest`, `npm`, `vite`, etc. runs inside the container. Phase 4 entry refactored — that container is a separate ephemeral `weather-deploy-rehearsal` instance for the deploy-against-public-docs pass.
- **2026-05-04** — Phase 1 task complete: docker-compose dev/test stack scaffolded at [`repos/weewx-clearskies-stack/dev/`](../../repos/weewx-clearskies-stack/dev/). MariaDB 10.11 service + reflection-based snapshot capture (`snapshot/capture.py`, host-side) + backend-agnostic Python seed loader (`seed/seed_loader.py`, containerized). Same captured dataset loads into MariaDB or SQLite per ADR-012 via compose profiles. Smoke-tested loader against SQLite with synthetic fixture (3-row archive, null-coercion + short-row trailing-empty handling); MariaDB path will be exercised end-to-end first CI run. Drove a real defect found during smoke test: `_coerce_row` was silently truncating short rows via `zip` — fixed in place with defensive padding. Repo not yet `git init`'d (Phase 1 task 5 covers that). Layout matches [ADR-036](../decisions/ADR-036-workspace-layout.md) — files sit ready under `repos/` for the eventual repo-stand-up. **Follow-up validation pass inside `weather-dev`** drove two further defects fixed in place: invalid `pip install --require-hashes=false` Dockerfile syntax (`--require-hashes` is a flag, not value-taking), and SQLite-volume permission collision with the non-root `USER seed` directive (the seeder is transient dev/test data-loading infra, so root-in-container is appropriate; the non-root pattern stays mandatory for the runtime API/realtime services). Both backend profiles now load + verify against synthetic fixture end-to-end.
- **2026-05-05** — Phase 1 task: **API contract committed.** [`docs/contracts/openapi-v1.yaml`](../contracts/openapi-v1.yaml). OpenAPI 3.1, 23 paths, 53 schemas; validates clean. Drove two decision artifacts: (a) [ADR-040](../decisions/ADR-040-earthquake-providers.md) Accepted — earthquake providers as plugin modules per [ADR-038](../decisions/ADR-038-data-provider-module-organization.md); day-1 set usgs/geonet/emsc/renass; single source per deploy; setup wizard suggests by region; USGS = global fallback. Mirrors [ADR-016](../decisions/ADR-016-severe-weather-alerts.md). Research: [EARTHQUAKE-PROVIDER-RESEARCH.md](../reference/EARTHQUAKE-PROVIDER-RESEARCH.md). (b) [ADR-010](../decisions/ADR-010-canonical-data-model.md) re-Accepted with `EarthquakeRecord` added (per item-7 in-place correction). Required: `id`, `time`, `latitude`, `longitude`, `magnitude`, `source`. Optional: `depth`, `magnitudeType`, `place`, `url`, `tsunami`, `felt`, `mmi`, `alert` (USGS PAGER), `status`, `extras`. Entity count now 9 cores + 2 containers. Process notes: realtime SSE deliberately not in this OpenAPI — separate `weewx-clearskies-realtime` contract; `/reports/{year}/{month}` returns raw weewx text (dashboard parses client-side); pagination supports both cursor and page-number forms; standalone `/units` endpoint dropped (units block embedded per response).
- **2026-05-05** — Phase 1 task: **CI scaffolding landed across all five repos.** Phase 1 minimal set per agreed scope: DCO sign-off check + gitleaks secret scan + dependency audit, three workflows per repo. Third-party actions SHA-pinned per [`coding.md`](../../rules/coding.md) §1; gitleaks installed via tarball download to avoid the gitleaks-action org-license requirement. Dependency-audit workflows are placeholder-tolerant (skip quietly when no manifest exists yet) so they're useful from day one without rotting. Lint, test, release-on-tag, and the [ADR-012](../decisions/ADR-012-database-access-pattern.md) DB-backend matrix for api are explicitly deferred to Phase 2/3/4 — there's no code yet to exercise them, and writing rotting placeholder steps that "echo no tests yet" creates noise without value. **Sync-script reshape:** `scripts/sync-to-weather-dev.ps1` rewritten as `scripts/sync-to-weather-dev.sh`. PowerShell-native ssh.exe was hitting a stale IdentityFile pointer in the user's Windows OpenSSH config (left over from another project); bash-side ssh works fine and is what the Bash tool / git-bash use. Same pass added `sudo -u ubuntu` to the in-container `git pull` to avoid git's "dubious ownership" check (repos are ubuntu-owned, but `lxc exec` defaults to root). Verified end-to-end against all five working trees in weather-dev.
- **2026-05-05** — Phase 1 task: **5 GitHub repos stood up.** All five Clear Skies repos created public under `github.com/inguy24/` per [ADR-004](../decisions/ADR-004-repo-naming.md) and [ADR-036](../decisions/ADR-036-workspace-layout.md): `weewx-clearskies-api`, `weewx-clearskies-realtime`, `weewx-clearskies-dashboard`, `weewx-clearskies-stack`, `weewx-clearskies-design-tokens`. Each repo: `README.md` placeholder (real content lands at the relevant Phase per [ADR-001](../decisions/ADR-001-component-breakdown.md)), `LICENSE` (GPL v3), `SECURITY.md` placeholder pointing back to the meta-repo security baseline, language-appropriate `.gitignore`. Stack repo carries the existing `dev/` docker-compose content from the prior Phase 1 task. Design-tokens is a name-reservation placeholder (does not violate ADR-001's Phase 6+ deferral — placeholder ≠ implementation work). Meta-repo `.gitignore` updated to exclude `repos/*` (with `!repos/.gitkeep` exception) to avoid double-tracking nested git repos; `repos/weewx-clearskies-stack/` content untracked from meta via `git rm --cached -r`. [`weather-clearskies.code-workspace`](../../weather-clearskies.code-workspace) created at meta root with all six folders (meta + 5 children). DILBERT→weather-dev sync mechanism: manual fire of [`scripts/sync-to-weather-dev.sh`](../../scripts/sync-to-weather-dev.sh) over `ssh ratbert "lxc exec weather-dev ..."`. Stale "pick git-clone or bind-mount" language in [rules/clearskies-process.md](../../rules/clearskies-process.md) — never discussed with user — corrected to record the actual mechanism. Webhook auto-sync ruled out (no public-facing inbound on the LXD host). One-time follow-up: clone the five repos into `weather-dev:/home/ubuntu/repos/`.
- **2026-05-05** — Phase 1 task: **Security baseline document committed.** [`docs/contracts/security-baseline.md`](../contracts/security-baseline.md). Per-component checklist (api / realtime / dashboard / stack) consolidating 7 source ADRs + `coding.md` §1 + cross-cutting controls not pinned to any single ADR. CI gating matrix per repo. §8 surfaces six known gaps; three with real teeth (multi-worker rate-limit storage requirement, request-body limit default, markdown-sanitization regression risk via `react/no-danger` allowlist). User pressure-tested [ADR-030](../decisions/ADR-030-health-check-readiness-probes.md) split-port architecture during review — confirmed keep-as-is; the loopback-by-default of [ADR-037](../decisions/ADR-037-inbound-traffic-architecture.md) makes the security argument equal either way, and the operational friction is small enough to revisit during Phase 2 if real implementation makes it visible. No ADR cascade triggered.
- **2026-05-05** — [ADR-010](../decisions/ADR-010-canonical-data-model.md) Naming sub-decision corrected in place per item-7 lifecycle. Switched from snake_case Python + camelCase JSON (with Pydantic `alias_generator` bridge) to **camelCase everywhere — single name per field, identical in Python attribute and JSON key.** Reason: two-name overhead caused real friction during user review with no consumer benefiting from the snake_case form; weewx itself uses camelCase, so this is more weewx-aligned, not less. Pydantic config simplified (drops `alias_generator` / `populate_by_name` / `by_alias`). Per-file ruff `N815` suppression for `weewx_clearskies_api/models/canonical.py`. Spec [`docs/contracts/canonical-data-model.md`](../contracts/canonical-data-model.md) §1 and §5 updated to match. Same pass added internal-only header callouts to §2 (weewx unit-system reference) and §4 (provider→canonical mapping tables) — both are normalizer-internal lookups, never exposed on the wire — to reduce reader confusion between wire-format concepts and implementation internals. Wire format itself unchanged.
- **2026-05-05** — Phase 1 task: **Canonical-data-model spec committed.** [`docs/contracts/canonical-data-model.md`](../contracts/canonical-data-model.md). Companion to [ADR-010](../decisions/ADR-010-canonical-data-model.md) and the OpenAPI contract — fills the per-field unit table OpenAPI deliberately defers. Three load-bearing parts: (1) full per-field enumeration for every canonical entity (with weewx-source columns and provider-source fields tagged); (2) per-field unit mapping for each weewx `target_unit` system (US / METRIC / METRICWX), driven by [`docs/reference/weewx-5.3/reference/units.md`](../reference/weewx-5.3/reference/units.md); (3) provider→canonical mapping tables for the day-1 forecast (aeris/nws/openmeteo/openweathermap/wunderground per [ADR-007](../decisions/ADR-007-forecast-providers.md)), AQI (aeris/openmeteo/openweathermap/iqair per [ADR-013](../decisions/ADR-013-aqi-handling.md)), alerts (nws/aeris/openweathermap per [ADR-016](../decisions/ADR-016-severe-weather-alerts.md)), and earthquake (usgs/geonet/emsc/renass per [ADR-040](../decisions/ADR-040-earthquake-providers.md)) providers. Radar [ADR-015](../decisions/ADR-015-radar-map-tiles-strategy.md) coverage notes that tile data has no canonical-field mapping — capability declarations carry the per-provider URL templates. Self-audit findings surfaced in-reply, three fixed in place: `appTemp` removed from first-class observation table (kept as promotion candidate, currently in `extras` until OpenAPI v1.x bump); µg/m³ → ppm conversion formula corrected (`ppm = µg/m³ × 24.45 / molecular_weight`); §2.2 added flagging that operator overrides via `[StdConvert]` change the per-field unit and the api startup must read the actual configured unit per group, not just the system label.
- **2026-05-04** — Cleanup pass on bloated ADRs **complete**. Conciseness rule clarified in [rules/clearskies-process.md](../../rules/clearskies-process.md): bloat is measured by content density, not line count. Orphan `ADR-035-observation-entity-model.md` deleted (was a Pinned placeholder superseded by `user-driven-column-mapping.md` but never cleaned up). Nine ADRs trimmed in place per ADR-process item 7 (status flipped Proposed → re-approved → Accepted with date 2026-05-04): ADR-008 (auth-model), ADR-009 (design-direction), ADR-010 (canonical-data-model), ADR-011 (multi-station-scope), ADR-024 (page-taxonomy), ADR-027 (config-and-setup-wizard), ADR-036 (workspace-layout), ADR-037 (inbound-traffic-architecture), ADR-038 (data-provider-module-organization). Cuts removed: redundant prior-ADR recap sections, multi-paragraph option-defense prose, "what this ADR is NOT" enumerations, audit findings that restated obvious tradeoffs, Phase 2/3 implementation code blocks. Decisions, options preserved with one-line verdicts, load-bearing implementation facts, and out-of-scope guards retained verbatim. Remaining 28 ADRs audited paragraph-by-paragraph for content density and confirmed tight — no filler, every paragraph load-bearing. All 39 ADRs in INDEX.md now meet the conciseness rule.

---

## Appendix: Inherited from predecessor plan

These items remain valid context but are no longer driving tasks:

- **Server inventory:** [docs/reference/SERVER-INVENTORY.md](../reference/SERVER-INVENTORY.md)
- **Repo-vs-server diff (2026-04-29 snapshot):** [docs/reference/REPO-VS-SERVER-DIFF-2026-04-29.md](../reference/REPO-VS-SERVER-DIFF-2026-04-29.md)
- **WeeWX 5.3 docs (local mirror):** [docs/reference/weewx-5.3/](../reference/weewx-5.3/)
- **Belchertown skin source (current production fork):** https://github.com/inguy24/weewx-belchertown — kept as-is on the live server until Phase 5 cutover.
