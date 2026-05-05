# Clear Skies — Decision Index

Every locked architecture or process decision for the Clear Skies project lives here as an ADR. Format defined in [_TEMPLATE.md](_TEMPLATE.md). Process discipline in [rules/clearskies-process.md](../../rules/clearskies-process.md).

## ADRs

| ADR | Title | Status | Date |
|---|---|---|---|
| [ADR-001](ADR-001-component-breakdown.md) | 5-component breakdown | Accepted | 2026-04-30 |
| [ADR-002](ADR-002-tech-stack.md) | Tech stack | Accepted | 2026-04-30 |
| [ADR-003](ADR-003-license.md) | License = GPL v3 | Accepted | 2026-04-30 |
| [ADR-004](ADR-004-repo-naming.md) | Repo naming convention | Accepted | 2026-04-30 |
| [ADR-005](ADR-005-realtime-architecture.md) | Realtime supports direct + MQTT modes | Accepted | 2026-04-30 |
| [ADR-006](ADR-006-compliance-model.md) | End-user-managed compliance for third-party APIs | Accepted | 2026-04-30 |
| [ADR-007](ADR-007-forecast-providers.md) | Forecast providers — day-1 set | Accepted | 2026-04-30 |
| [ADR-008](ADR-008-auth-model.md) | Auth model | Accepted | 2026-05-04 |
| [ADR-009](ADR-009-design-direction.md) | Design direction | Accepted | 2026-05-04 |
| [ADR-010](ADR-010-canonical-data-model.md) | Canonical internal data model (fields, types, units) | Accepted | 2026-05-05 |
| [ADR-011](ADR-011-multi-station-scope.md) | Multi-station support (single or multi-station scope) | Accepted | 2026-05-04 |
| [ADR-012](ADR-012-database-access-pattern.md) | Database access pattern — SQLAlchemy 2.x; read-only DB user + startup write-probe; runtime schema reflection feeds ADR-035 mapping; per-request session | Accepted | 2026-05-02 |
| [ADR-013](ADR-013-aqi-handling.md) | AQI handling (clearskies-api plugin modules per ADR-038; two operator paths — own weewx extension via ADR-035 OR clearskies-api plugin) | Accepted | 2026-05-02 |
| [ADR-014](ADR-014-almanac-data-source.md) | Almanac data source (`skyfield`, server-side, NASA JPL ephemerides) | Accepted | 2026-05-02 |
| [ADR-015](ADR-015-radar-map-tiles-strategy.md) | Radar / map tiles strategy — Leaflet + 8 day-1 provider modules + iframe fallback; OSM base; clearskies-api proxies keyed providers | Accepted | 2026-05-02 |
| [ADR-016](ADR-016-severe-weather-alerts.md) | Severe weather alerts source — clearskies-api plugin modules per ADR-038; day-1 set: nws/aeris/openweathermap; single source per deploy; setup wizard suggests by region | Accepted | 2026-05-02 |
| [ADR-017](ADR-017-provider-response-caching.md) | Provider-response caching — pluggable backend (`memory` default, `redis` optional); per-provider TTL declarations; multi-worker requires Redis | Accepted | 2026-05-02 |
| [ADR-018](ADR-018-api-versioning-policy.md) | API versioning policy — URL path; major bump only on breaking changes; no support-window promise (GPL v3 AS-IS); RFC 9457 errors | Accepted | 2026-05-02 |
| [ADR-019](ADR-019-units-handling.md) | Units handling — server passes weewx target_unit through with metadata; no server-side conversion; no per-user override at v0.1 | Accepted | 2026-05-02 |
| [ADR-020](ADR-020-time-zone-handling.md) | Time zone handling — UTC on wire; station-local display via IANA TZ in StationMetadata; `Intl.DateTimeFormat`; no per-user override at v0.1 | Accepted | 2026-05-02 |
| [ADR-021](ADR-021-i18n-strategy.md) | i18n strategy — 13 locales for v0.1 (en/de/es/fil/fr/it/ja/nl/pt-PT/pt-BR/ru/zh-CN/zh-TW); no RTL | Accepted | 2026-05-02 |
| [ADR-022](ADR-022-theming-branding-mechanism.md) | Theming / branding mechanism — CSS variables + runtime config; curated accent palette (6 entries); operator logo upload; custom.css escape hatch | Accepted | 2026-05-02 |
| [ADR-023](ADR-023-light-dark-mode-mechanism.md) | Light/dark mode mechanism — `data-theme` attribute on `<html>`; React theme provider; user override beats operator default; supports light/dark/auto-sunrise-sunset/auto-OS | Accepted | 2026-05-02 |
| [ADR-024](ADR-024-page-taxonomy.md) | Dashboard page taxonomy & navigation | Accepted | 2026-05-04 |
| [ADR-025](ADR-025-browser-support-matrix.md) | Browser support matrix — modern evergreen, last 2 years; iOS Safari 16.4+; no IE / no <ES2022 baseline; Browserslist `>0.5%, last 2 years, not dead` | Accepted | 2026-05-02 |
| [ADR-026](ADR-026-accessibility-commitments.md) | Accessibility commitments — WCAG 2.1 Level AA, per-change audit + pre-ship audit; release-blocking | Accepted | 2026-05-02 |
| [ADR-027](ADR-027-config-and-setup-wizard.md) | Configuration format, secret handling, and configuration UI | Accepted | 2026-05-04 |
| [ADR-028](ADR-028-update-mechanism.md) | Update mechanism for end users — `pip install -U` for native, `docker compose pull` for Docker; no in-app self-update at v0.1; CHANGELOG.md is the upgrade-guidance source; AS-IS per ADR-018 (no LTS, no support windows); config preservation: `/etc/weewx-clearskies/` is outside the package (pip) or bind-mounted (Docker); schema drift always CHANGELOG-flagged | Accepted | 2026-05-04 |
| [ADR-029](ADR-029-logging-format-destinations.md) | Logging format & destinations — JSON one-line-per-record to stdout; stdlib `logging` + filter; journalctl/docker logs for capture | Accepted | 2026-05-02 |
| [ADR-030](ADR-030-health-check-readiness-probes.md) | Health check & readiness probes — `/health/live` + `/health/ready` on separate loopback port; degraded → 200; unauthenticated | Accepted | 2026-05-02 |
| [ADR-031](ADR-031-observability-metrics.md) | Observability / metrics — logs by default; optional Prometheus `/metrics` on the health port (loopback) when `CLEARSKIES_METRICS_ENABLED=true`; OTel deferred | Accepted | 2026-05-02 |
| [ADR-032](ADR-032-versioning-across-repos.md) | Versioning across repos — independent SemVer per repo; no lockstep; pre-1.0 minor bumps may break; compat matrix in stack repo | Accepted | 2026-05-02 |
| [ADR-033](ADR-033-performance-budget.md) | Performance budget — Lighthouse ≥ 90; CWV "Good" thresholds; bundle ≤ 200KB gzipped; p95 API latency targets; targets-not-gates | Accepted | 2026-05-02 |
| [ADR-034](ADR-034-deployment-topology-default.md) | Deployment topology default — single-host co-located with weewx; native install OR docker-compose (Caddy-bundled); multi-host reference-only | Accepted | 2026-05-02 |
| [ADR-035](ADR-035-user-driven-column-mapping.md) | User-driven column mapping (schema introspection + auto-map stock weewx columns + operator maps non-stock at setup) | Accepted | 2026-05-02 |
| [ADR-036](ADR-036-workspace-layout.md) | Workspace & meta-repo layout (nested `repos/` under meta; multi-root VS Code workspace) | Accepted | 2026-05-04 |
| [ADR-037](ADR-037-inbound-traffic-architecture.md) | Inbound traffic flow / one-door reverse-proxy architecture | Accepted | 2026-05-04 |
| [ADR-038](ADR-038-data-provider-module-organization.md) | Data-provider module organization (one file/dir per provider, internal contract; not a third-party plugin ecosystem) | Accepted | 2026-05-04 |
| [ADR-039](ADR-039-distribution-installation-mechanism.md) | Distribution / installation — PyPI + container registry + GitHub Releases; Linux native or Docker; macOS native or Docker; Windows = Docker Desktop; no bespoke OS installers | Accepted | 2026-05-04 |
| [ADR-040](ADR-040-earthquake-providers.md) | Earthquake providers — day-1 set: usgs/geonet/emsc/renass; single source per deploy; setup wizard suggests by region; USGS provides global fallback | Accepted | 2026-05-05 |

> **Note:** This list is not assumed complete. The user has explicitly flagged that decisions get missed. New Pinned slots are added as they're identified, before the corresponding work begins.

## Status legend

- **Proposed** — drafted, under user review. Implementation MUST NOT proceed.
- **Accepted** — locked. Governs implementation. Immutable except via supersession.
- **Superseded by ADR-NNN** — old decision; the linked ADR is now authoritative.
- **Pinned** — known-needed decision, not yet drafted. Tracked here so it isn't forgotten.

## Adding a new ADR

1. Copy [_TEMPLATE.md](_TEMPLATE.md) to `ADR-NNN-{slug}.md` using the next free number.
2. Fill in the sections. Status starts as `Proposed`.
3. Add a row to the table above.
4. Discuss with the user; on approval, change status to `Accepted` and update the date.
5. If the ADR governs a Phase 1 task in the master plan, add the link from the plan's task entry.
