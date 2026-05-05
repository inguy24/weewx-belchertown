---
status: Accepted
date: 2026-04-30
deciders: shane
---

# ADR-002: Tech stack

## Context

Need to lock the major library/framework choices for the three primary components (api, realtime, dashboard) so Phase 2+ can proceed without re-evaluating fundamentals. Choices affect long-term maintenance burden, ecosystem alignment, and design ceiling.

## Decisions

### `weewx-clearskies-api`

| Concern | Choice | Why |
|---|---|---|
| Framework | FastAPI (Python, **sync route handlers**) | Native OpenAPI generation, strong security middleware. Use sync route handlers (`def`, not `async def`) — appropriate for our scale and avoids the async/sync mixing trap with weewx and SQLAlchemy. |
| DB layer | SQLAlchemy 2.x **(sync mode)** | Parameterized queries by default; supports SQLite (default weewx) and MariaDB transparently. **Sync mode chosen to match weewx itself**; do not introduce async patterns for DB calls. |
| Server | uvicorn behind reverse proxy | Standard FastAPI deployment |

### `weewx-clearskies-realtime`

| Concern | Choice | Why |
|---|---|---|
| Language | Python | Matches `api` for skill reuse and shared dependencies |
| MQTT client | paho-mqtt (**optional install extra**) | Standard Python MQTT library; covers the MQTT subscriber mode per [ADR-005](ADR-005-realtime-architecture.md). Shipped as `pip install weewx-clearskies-realtime[mqtt]`, not a hard dep. Used under EDL-1.0 election per [ADR-003](ADR-003-license.md). |
| SSE delivery | Starlette `EventSourceResponse` (FastAPI-compatible) | Aligns with API stack |

### `weewx-clearskies-dashboard`

| Concern | Choice | Why |
|---|---|---|
| Framework | React 19 + Vite | Largest ecosystem of components and starter templates; Vite for fast dev DX |
| Styling | **Tailwind CSS v4** | CSS-first config (`@theme` directive), OKLCH color space, dominant choice for modern dashboards |
| Component library | **shadcn/ui** (copy-paste model) | De-facto Tailwind-aligned primitive library. Components copied into our repo; we own the source. Discipline policy in implementation guidance. **Tremor dropped** — its value overlapped with shadcn + Recharts directly. |
| Charting | **Recharts** (primary) | Tailwind/React-friendly, sufficient for the chart types Clear Skies needs. Heavier libs (visx, Nivo, ECharts) considered only on case-by-case basis if a specific need arises. **ECharts dropped from primary** — 700KB bundle cost, sync API mismatch with React, less actively maintained React wrapper. |
| Icons | Lucide + Weather Icons | Lucide for general UI, Weather Icons for the 222-icon weather-specific set |

### Real-time transport

- **Server-Sent Events (SSE)** — browser-native, no broker required for the browser-side path, simpler than MQTT-over-WebSocket. (Note: this is the *transport from realtime service to browser*. The realtime service's *input* can still be MQTT in MQTT-subscriber mode per [ADR-005](ADR-005-realtime-architecture.md).)

### TLS

| Install path | Choice | Why |
|---|---|---|
| Native install on existing infra | Apache + certbot | Don't disrupt the `cloud` container's existing setup |
| Docker-compose install (new users) | Caddy | Auto-LE, zero-config |

### Internal test environment

- **Local Docker compose on DILBERT** for early UI iteration
- **`weather-dev` LXD container on Ratbert** for end-to-end install rehearsal (mirrors what a fresh user would do, doesn't risk production)

## Consequences

- Locks Python on the backend, Tailwind/React on the frontend. Future libraries chosen for compatibility.
- Phase 1 includes a small spike (shadcn + Recharts starter on Tailwind v4 + React 19) to validate DX before Phase 3 commits to the design.
- Shared Python skill across `api` + `realtime` simplifies CI tooling and dependency management — same lint/test/type-check toolchain.
- Both services can share a small `weewx-clearskies-common` library if useful, but that's a Phase 2 call — don't pre-extract.
- **Sync-only Python stack** simplifies reasoning, matches weewx itself. Trade-off: gives up theoretical async throughput; acceptable at our scale (one weewx station, dozens of concurrent dashboard users at peak).
- **Maintenance burden is real and ongoing.** Every dependency carries a major-version churn cycle. As a single-maintainer project, this is a recurring cost. Mitigations: Renovate/Dependabot enabled per repo, version pinning with explicit major-bump review, prefer libs with multi-maintainer teams. Full mitigation isn't possible — accept and manage.
- **shadcn's copy-paste model** means upstream improvements don't auto-flow. Mitigation: weekly CI job runs `npx shadcn diff` across used components, opens an automated PR if upstream changed. Detection automated; application stays human-reviewed.
- **Dependency licenses verified GPL-3.0-or-later compatible** (2026-04-30). Verification table and sources at [docs/reference/DEPENDENCY-LICENSE-AUDIT.md](../reference/DEPENDENCY-LICENSE-AUDIT.md). New deps added in Phase 2+ require manual license verification at PR time per [ADR-003](ADR-003-license.md).

## Implementation guidance

### API & realtime (Python)

- `pyproject.toml`, ruff (lint), pytest (test), mypy (type check). Python 3.11+ minimum.
- **Sync only.** Sync route handlers (`def`, not `async def`). SQLAlchemy 2.x in sync mode. Do not mix async/sync — silently degrades to sync-blocking-the-event-loop and obscures profiling.
- Reverse proxy WS-upgrade rule (already proven for Belchertown's MQTT chain) is **not needed** for SSE — SSE is plain HTTPS GET with `text/event-stream`.
- **SSE heartbeat required.** Emit a periodic comment-line keepalive (suggested: every 15 seconds, `:keepalive\n\n`). Survives corporate proxies and mobile-network idle disconnects. End users in cellular environments depend on this.
- **Forwarded-headers parity.** API behavior must be identical whether TLS terminates at Apache (native install) or Caddy (Docker install). Trust `X-Forwarded-Proto` and `X-Forwarded-For` only when the request comes from a configured trusted proxy. Document the trusted-proxy IPs/networks in `CONFIG.md`.

### Dashboard (JS)

- Package manager: pnpm (chosen in Phase 1 spike if it works; otherwise npm). Stick with whichever across all subsequent JS work.
- **Tailwind v4 specifics:** CSS-first config (`@theme` in `globals.css`, no `tailwind.config.js`). HSL → OKLCH color migration. `tailwindcss-animate` plugin replaced with `tw-animate-css`. Targets modern browsers (per [ADR-025](INDEX.md), pinned).
- **Recharts + React 19 footgun:** Recharts (current major) requires a `react-is` dependency override when used with React 19. Capture in `package.json` `overrides` field at scaffold time. Search keyword for future maintainers: "react-is override Recharts React 19."
- **shadcn discipline policy (locked):**
  - Components installed via `npx shadcn add <name>`. Never edit the copied source files directly.
  - All customizations happen in **wrapper components** in `src/components/` (one level above the shadcn-copied `src/components/ui/`).
  - Weekly CI job runs `npx shadcn diff` across used components and opens an automated PR with deltas. Human reviews and merges.

### Belchertown reuse

- Study Belchertown's existing patterns where they apply: Aeris API call structure, weather-code translation, alert-code translation, icon mapping logic, AQI archive-column read pattern. **Adopt what works; don't reinvent.**
- Don't blindly port — Belchertown's Cheetah/Python world is structurally different from our FastAPI + React world. Where Belchertown's pattern doesn't fit, do it right rather than dragging the legacy structure forward.

## References

- Related ADRs: [ADR-001](ADR-001-component-breakdown.md), [ADR-005](ADR-005-realtime-architecture.md)
- Plan: [Tech stack decisions section in CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md)
