# Clear Skies — Decision Index

All ADRs have been consolidated into authoritative manuals. ADRs preserve the historical decision process (the *why*) but are not consulted for current rules. The manuals say *what to do*.

| Manual | Authority for |
|--------|--------------|
| [API-MANUAL.md](../API-MANUAL.md) | API implementation rules |
| [PROVIDER-MANUAL.md](../PROVIDER-MANUAL.md) | Provider module rules |
| [OPERATIONS-MANUAL.md](../OPERATIONS-MANUAL.md) | Deployment, security, config, monitoring |
| [DASHBOARD-MANUAL.md](../DASHBOARD-MANUAL.md) | Dashboard technical behavior |
| [DESIGN-MANUAL.md](../DESIGN-MANUAL.md) | UI design rules |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | System topology, ports, containers |

Format defined in [_TEMPLATE.md](_TEMPLATE.md). Process discipline in [rules/clearskies-process.md](../../rules/clearskies-process.md).

---

## Archived — consolidated into API-MANUAL.md

| ADR | Title | Archived | Original Date |
|---|---|---|---|
| [ADR-010](../archive/decisions/ADR-010-canonical-data-model.md) | Canonical internal data model | 2026-06-18 | 2026-05-05 |
| [ADR-012](../archive/decisions/ADR-012-database-access-pattern.md) | Database access pattern | 2026-06-18 | 2026-05-02 |
| [ADR-018](../archive/decisions/ADR-018-api-versioning-policy.md) | API versioning policy | 2026-06-18 | 2026-05-02 |
| [ADR-035](../archive/decisions/ADR-035-user-driven-column-mapping.md) | User-driven column mapping | 2026-06-18 | 2026-05-02 |
| [ADR-041](../archive/decisions/ADR-041-realtime-bff.md) | Unit conversion and enrichment authority | 2026-06-18 | 2026-05-26 |
| [ADR-042](../archive/decisions/ADR-042-unit-system.md) | Unit system | 2026-06-18 | 2026-05-26 |
| [ADR-043](../archive/decisions/ADR-043-skinconf-compliance.md) | skin.conf compliance | 2026-06-18 | 2026-05-26 |
| [ADR-054](../archive/decisions/ADR-054-configurable-charts.md) | Operator-configurable charts system | 2026-06-18 | 2026-06-07 |
| [ADR-056](../archive/decisions/ADR-056-api-weewx-co-location.md) | API co-location with weewx | 2026-06-18 | 2026-06-13 |
| [ADR-057](../archive/decisions/ADR-057-api-weewx-application-layer.md) | API = weewx application layer | 2026-06-18 | 2026-06-13 |
| [ADR-058](../archive/decisions/ADR-058-fold-realtime-into-api.md) | Fold realtime into API | 2026-06-18 | 2026-06-14 |

## Archived — consolidated into PROVIDER-MANUAL.md

| ADR | Title | Archived | Original Date |
|---|---|---|---|
| [ADR-006](../archive/decisions/ADR-006-compliance-model.md) | End-user-managed compliance | 2026-06-18 | 2026-04-30 |
| [ADR-007](../archive/decisions/ADR-007-forecast-providers.md) | Forecast providers — day-1 set | 2026-06-18 | 2026-04-30 |
| [ADR-013](../archive/decisions/ADR-013-aqi-handling.md) | AQI handling | 2026-06-18 | 2026-05-02 |
| [ADR-014](../archive/decisions/ADR-014-almanac-data-source.md) | Almanac data source (Skyfield) | 2026-06-18 | 2026-05-02 |
| [ADR-015](../archive/decisions/ADR-015-radar-map-tiles-strategy.md) | Radar / map tiles strategy | 2026-06-18 | 2026-05-02 |
| [ADR-016](../archive/decisions/ADR-016-severe-weather-alerts.md) | Severe weather alerts | 2026-06-18 | 2026-05-02 |
| [ADR-017](../archive/decisions/ADR-017-provider-response-caching.md) | Provider-response caching | 2026-06-18 | 2026-05-02 |
| [ADR-038](../archive/decisions/ADR-038-data-provider-module-organization.md) | Data-provider module organization | 2026-06-18 | 2026-05-04 |
| [ADR-040](../archive/decisions/ADR-040-earthquake-providers.md) | Earthquake providers | 2026-06-18 | 2026-05-05 |
| [ADR-045](../archive/decisions/ADR-045-background-cache-warming.md) | Background cache warming | 2026-06-18 | 2026-05-27 |
| [ADR-046](../archive/decisions/ADR-046-gem-active-faults.md) | GEM active faults overlay | 2026-06-18 | 2026-05-27 |
| [ADR-052](../archive/decisions/ADR-052-geography-correct-alert-model.md) | Geography-correct alert severity model | 2026-06-18 | 2026-06-01 |
| [ADR-053](../archive/decisions/ADR-053-almanac-visibility-rankings.md) | Almanac visibility rankings | 2026-06-18 | 2026-06-04 |
| [ADR-059](../archive/decisions/ADR-059-multi-jurisdiction-aqi.md) | Multi-jurisdiction AQI | 2026-06-18 | 2026-06-14 |

## Archived — consolidated into OPERATIONS-MANUAL.md

| ADR | Title | Archived | Original Date |
|---|---|---|---|
| [ADR-008](../archive/decisions/ADR-008-auth-model.md) | Auth model | 2026-06-18 | 2026-05-04 |
| [ADR-027](../archive/decisions/ADR-027-config-and-setup-wizard.md) | Configuration format and setup wizard | 2026-06-18 | 2026-05-04 |
| [ADR-028](../archive/decisions/ADR-028-update-mechanism.md) | Update mechanism | 2026-06-18 | 2026-05-04 |
| [ADR-029](../archive/decisions/ADR-029-logging-format-destinations.md) | Logging format & destinations | 2026-06-18 | 2026-05-02 |
| [ADR-030](../archive/decisions/ADR-030-health-check-readiness-probes.md) | Health check & readiness probes | 2026-06-18 | 2026-05-02 |
| [ADR-031](../archive/decisions/ADR-031-observability-metrics.md) | Observability / metrics | 2026-06-18 | 2026-05-02 |
| [ADR-033](../archive/decisions/ADR-033-performance-budget.md) | Performance budget | 2026-06-18 | 2026-05-02 |
| [ADR-034](../archive/decisions/ADR-034-deployment-topology-default.md) | Deployment topology | 2026-06-18 | 2026-05-02 |
| [ADR-037](../archive/decisions/ADR-037-inbound-traffic-architecture.md) | Inbound traffic architecture | 2026-06-18 | 2026-05-04 |
| [ADR-038a](../archive/decisions/ADR-038a-wizard-api-channel.md) | Wizard-to-API secure channel | 2026-06-18 | 2026-05-20 |
| [ADR-039](../archive/decisions/ADR-039-distribution-installation-mechanism.md) | Distribution / installation | 2026-06-18 | 2026-05-04 |
| [ADR-060](../archive/decisions/ADR-060-security-model-threat-boundaries.md) | Security model & threat boundaries | 2026-06-18 | 2026-06-14 |
| [ADR-061](../archive/decisions/ADR-061-filesystem-permissions-model.md) | Filesystem permissions model | 2026-06-18 | 2026-06-14 |

## Archived — consolidated into DASHBOARD-MANUAL.md

| ADR | Title | Archived | Original Date |
|---|---|---|---|
| [ADR-020](../archive/decisions/ADR-020-time-zone-handling.md) | Time zone handling | 2026-06-18 | 2026-05-02 |
| [ADR-021](../archive/decisions/ADR-021-i18n-strategy.md) | i18n strategy | 2026-06-18 | 2026-05-02 |
| [ADR-024](../archive/decisions/ADR-024-page-taxonomy.md) | Dashboard page taxonomy | 2026-06-18 | 2026-05-04 |
| [ADR-025](../archive/decisions/ADR-025-browser-support-matrix.md) | Browser support matrix | 2026-06-18 | 2026-05-02 |
| [ADR-055](../archive/decisions/ADR-055-client-data-refresh-policy.md) | Client data refresh policy | 2026-06-18 | 2026-06-10 |

## Archived — consolidated into DESIGN-MANUAL.md

| ADR | Title | Archived | Original Date |
|---|---|---|---|
| [ADR-009](../archive/decisions/ADR-009-design-direction.md) | Design direction | 2026-06-16 | 2026-05-04 |
| [ADR-022](../archive/decisions/ADR-022-theming-branding-mechanism.md) | Theming / branding mechanism | 2026-06-16 | 2026-05-02 |
| [ADR-023](../archive/decisions/ADR-023-light-dark-mode-mechanism.md) | Light/dark mode mechanism | 2026-06-16 | 2026-05-02 |
| [ADR-026](../archive/decisions/ADR-026-accessibility-commitments.md) | Accessibility commitments | 2026-06-16 | 2026-05-02 |
| [ADR-047](../archive/decisions/ADR-047-background-system.md) | Background system | 2026-06-16 | 2026-05-30 |
| [ADR-048](../archive/decisions/ADR-048-theme-color-tokens.md) | Theme & color tokens | 2026-06-16 | 2026-05-30 |
| [ADR-049](../archive/decisions/ADR-049-hero-weather-icons.md) | Hero weather icons | 2026-06-16 | 2026-05-30 |
| [ADR-050](../archive/decisions/ADR-050-utility-stat-nav-icons.md) | Utility/stat/nav/alert icons | 2026-06-16 | 2026-05-30 |
| [ADR-051](../archive/decisions/ADR-051-card-footprint-model.md) | Card footprint model | 2026-06-16 | 2026-05-30 |
| [ADR-062](../archive/decisions/ADR-062-card-header-contract.md) | Card header contract | 2026-06-16 | 2026-06-16 |

## Archived — substance captured in ARCHITECTURE.md

| ADR | Title | Archived | Original Date |
|---|---|---|---|
| [ADR-001](../archive/decisions/ADR-001-component-breakdown.md) | 5-component breakdown | 2026-06-18 | 2026-04-30 |
| [ADR-002](../archive/decisions/ADR-002-tech-stack.md) | Tech stack | 2026-06-18 | 2026-04-30 |
| [ADR-003](../archive/decisions/ADR-003-license.md) | License = GPL v3 | 2026-06-18 | 2026-04-30 |
| [ADR-004](../archive/decisions/ADR-004-repo-naming.md) | Repo naming convention | 2026-06-18 | 2026-04-30 |
| [ADR-011](../archive/decisions/ADR-011-multi-station-scope.md) | Multi-station scope | 2026-06-18 | 2026-05-04 |
| [ADR-032](../archive/decisions/ADR-032-versioning-across-repos.md) | Versioning across repos | 2026-06-18 | 2026-05-02 |
| [ADR-036](../archive/decisions/ADR-036-workspace-layout.md) | Workspace layout | 2026-06-18 | 2026-05-04 |

## Superseded (archived)

| ADR | Title | Superseded by | Original Date |
|---|---|---|---|
| [ADR-005](../archive/decisions/ADR-005-realtime-architecture.md) | Realtime architecture | ADR-058 | 2026-04-30 |
| [ADR-019](../archive/decisions/ADR-019-units-handling.md) | Units handling (original) | ADR-041, ADR-042 | 2026-05-02 |
| [ADR-044](../archive/decisions/ADR-044-sky-condition-classification.md) | Current conditions text / sky condition classification | ADR-073 | 2026-05-26 |

## Proposed

| ADR | Title | Date |
|---|---|---|
| [ADR-073](ADR-073-sky-condition-kv-first-classification.md) | Sky condition Kv-first classification (supersedes ADR-044) | 2026-06-23 |

## Accepted — pending consolidation into PROVIDER-MANUAL.md

| ADR | Title | Date |
|---|---|---|
| [ADR-063](ADR-063-aeris-xcast-model-selection.md) | Aeris forecast model selection (Standard vs Xcast) | 2026-06-20 |

## Accepted — pending consolidation into DASHBOARD-MANUAL.md + ARCHITECTURE.md + OPERATIONS-MANUAL.md + DESIGN-MANUAL.md

| ADR | Title | Date |
|---|---|---|
| [ADR-064](ADR-064-card-plugin-contract.md) | Card plugin contract | 2026-06-21 |
| [ADR-065](ADR-065-now-page-layout-configuration.md) | Now page layout configuration | 2026-06-21 |

## Accepted — pending consolidation into API-MANUAL.md + PROVIDER-MANUAL.md + OPERATIONS-MANUAL.md + ARCHITECTURE.md + DESIGN-MANUAL.md

| ADR | Title | Date |
|---|---|---|
| [ADR-066](ADR-066-aqi-provider-restructuring.md) | AQI provider restructuring for observed data (amended: AirNow excluded) | 2026-06-21 |
| [ADR-067](ADR-067-haze-detection-architecture.md) | Haze detection architecture | 2026-06-21 |
| [ADR-068](ADR-068-auto-calibration-baseline.md) | Auto-calibration baseline system | 2026-06-21 |
| [ADR-069](ADR-069-fog-mist-detection-rework.md) | Fog/mist detection rework | 2026-06-21 |
| [ADR-070](ADR-070-nws-text-generation-system.md) | NWS-style text generation system | 2026-06-21 |
| [ADR-071](ADR-071-nighttime-provider-deferral.md) | Nighttime mode — provider deferral pattern | 2026-06-21 |

## Archived — consolidated into API-MANUAL.md + OPERATIONS-MANUAL.md + ARCHITECTURE.md

| ADR | Title | Archived | Original Date |
|---|---|---|---|
| [ADR-072](../archive/decisions/ADR-072-solar-radiation-model-replacement.md) | Solar radiation model replacement (R-S → McClear / Solis) | 2026-06-23 | 2026-06-23 |

## Amendments (2026-06-21)

| ADR | Amendment | Location |
|---|---|---|
| ADR-024 | Page visibility moves from API to static config (`pages.json`) | [ADR-024 amendment 2026-06-21](../archive/decisions/ADR-024-page-taxonomy.md) |
| ADR-027 | Admin landing page at `/admin` with domain-organized sections | [ADR-027 amendment 2026-06-21](../archive/decisions/ADR-027-config-and-setup-wizard.md) |

---

## Status legend

- **Archived** — consolidated into an authoritative manual. Historical decision rationale preserved in `docs/archive/decisions/`.
- **Superseded by ADR-NNN** — old decision replaced by a newer ADR (both now archived).

## Adding a new ADR

1. Copy [_TEMPLATE.md](_TEMPLATE.md) to `ADR-NNN-{slug}.md` using the next free number.
2. Fill in the sections. Status starts as `Proposed`.
3. Add a row to the table above.
4. Discuss with the user; on approval, change status to `Accepted` and update the date.
5. After acceptance, extract prescriptive rules into the target manual (API-MANUAL, PROVIDER-MANUAL, OPERATIONS-MANUAL, DASHBOARD-MANUAL, or DESIGN-MANUAL).
6. Archive the ADR to `docs/archive/decisions/` with status "Archived — consolidated into {MANUAL-NAME}.md".
