# Documentation Index

This repo started as a Belchertown skin evaluation and pivoted to the Clear Skies project — a from-scratch modern weather UI. Both bodies of work live here.

## Quick links

- [CLAUDE.md](../CLAUDE.md) — Operating rules & domain routing
- [CHANGELOG.md](CHANGELOG.md) — Version history & changes
- [planning/CLEAR-SKIES-PLAN.md](planning/CLEAR-SKIES-PLAN.md) — Active project plan (Phase 2 in progress; Phase 1 closed 2026-05-05; Phase 2 task 1 closed 2026-05-06)
- [decisions/INDEX.md](decisions/INDEX.md) — All 40 Architecture Decision Records (Accepted)

## Planning

- **[planning/CLEAR-SKIES-PLAN.md](planning/CLEAR-SKIES-PLAN.md)** — phase tracker for the Clear Skies build (api / realtime / dashboard / stack repos). Plan body is an index — decision content lives in ADRs per [rules/clearskies-process.md](../rules/clearskies-process.md).

## Decisions

- **[decisions/INDEX.md](decisions/INDEX.md)** — table of all ADRs with status (40 Accepted, 0 Proposed, 0 Pinned as of 2026-05-05).
- [decisions/_TEMPLATE.md](decisions/_TEMPLATE.md) — copy this for new ADRs.

## Contracts

All three Phase 1 contracts committed; co-authoritative with the source ADRs.

- **[contracts/openapi-v1.yaml](contracts/openapi-v1.yaml)** — API contract. OpenAPI 3.1, 23 paths, 53 schemas. Validates clean against `openapi-spec-validator`. Per [ADR-018](decisions/ADR-018-api-versioning-policy.md) (URL-path versioning, RFC 9457 errors), [ADR-010](decisions/ADR-010-canonical-data-model.md) (canonical entities), [ADR-024](decisions/ADR-024-page-taxonomy.md) (endpoint inventory derived from page taxonomy). Phase 1 deliverable, complete 2026-05-05.
- **[contracts/canonical-data-model.md](contracts/canonical-data-model.md)** — Per-field type/unit catalog feeding [ADR-010](decisions/ADR-010-canonical-data-model.md). Three load-bearing parts: full per-entity field enumeration with weewx-source columns and provider-source fields tagged; per-field unit mapping for each weewx `target_unit` system (US / METRIC / METRICWX); provider→canonical mapping tables for the day-1 forecast / AQI / alerts / earthquake / radar providers. Phase 1 deliverable, complete 2026-05-05.
- **[contracts/security-baseline.md](contracts/security-baseline.md)** — Per-component security checklist consolidating [ADR-008](decisions/ADR-008-auth-model.md), [ADR-012](decisions/ADR-012-database-access-pattern.md), [ADR-027](decisions/ADR-027-config-and-setup-wizard.md), [ADR-029](decisions/ADR-029-logging-format-destinations.md), [ADR-030](decisions/ADR-030-health-check-readiness-probes.md), [ADR-037](decisions/ADR-037-inbound-traffic-architecture.md), and [coding.md §1](../rules/coding.md). Section 3 is the per-row checklist Phase 2+ work checks against. Phase 1 deliverable, complete 2026-05-05; §8 known-gaps revised 2026-05-06 (DCO mechanism resolved, dep-audit workflow gap added).

## Reference (Clear Skies)

- [reference/EARTHQUAKE-PROVIDER-RESEARCH.md](reference/EARTHQUAKE-PROVIDER-RESEARCH.md) — USGS / GeoNet / EMSC / ReNaSS API field shapes feeding [ADR-040](decisions/ADR-040-earthquake-providers.md) and the `EarthquakeRecord` addition to [ADR-010](decisions/ADR-010-canonical-data-model.md).
- [reference/SPIKE-FINDINGS.md](reference/SPIKE-FINDINGS.md) — Phase 1 task 1 (tech-stack spike) findings; bundle measurement vs. ADR-033, footguns documented for the dashboard scaffold.
- [reference/PLAN-VS-ADR-AUDIT-2026-05-04.md](reference/PLAN-VS-ADR-AUDIT-2026-05-04.md) — every drift between plan body and ADRs found and fixed on 2026-05-04.
- [reference/FORECAST-PROVIDER-RESEARCH.md](reference/FORECAST-PROVIDER-RESEARCH.md) — provider comparison feeding [ADR-007](decisions/ADR-007-forecast-providers.md).
- [reference/api-docs/](reference/api-docs/) — captured per-provider API docs (NWS, Aeris, OpenWeather, OpenMeteo, Tomorrow.io, AccuWeather, Visual Crossing, Weather Underground).
- [reference/CLEAR-SKIES-CONTENT-DECISIONS.md](reference/CLEAR-SKIES-CONTENT-DECISIONS.md) — 12-category content walk; cross-cutting threads identified.
- [reference/BELCHERTOWN-CONTENT-INVENTORY.md](reference/BELCHERTOWN-CONTENT-INVENTORY.md) — what the existing site shows; informs [ADR-024](decisions/ADR-024-page-taxonomy.md).
- [reference/DESIGN-INSPIRATION-NOTES.md](reference/DESIGN-INSPIRATION-NOTES.md) — visual references feeding [ADR-009](decisions/ADR-009-design-direction.md).
- [reference/NOAA-COOP-CWOP-REPORTING-RESEARCH.md](reference/NOAA-COOP-CWOP-REPORTING-RESEARCH.md) — PWS-contributor track research.
- [reference/DEPENDENCY-LICENSE-AUDIT.md](reference/DEPENDENCY-LICENSE-AUDIT.md) — GPL-3.0-or-later compatibility verification (2026-04-30) feeding [ADR-002](decisions/ADR-002-tech-stack.md) + [ADR-003](decisions/ADR-003-license.md).

## Reference (Belchertown evaluation, retained as predecessor context)

- [reference/SERVER-INVENTORY.md](reference/SERVER-INVENTORY.md) — Authoritative map of containers, MQTT chain, sync mechanism. Snapshot 2026-04-29.
- [reference/REPO-VS-SERVER-DIFF-2026-04-29.md](reference/REPO-VS-SERVER-DIFF-2026-04-29.md) — File-by-file comparison of live skin vs each branch on the fork.
- [reference/weewx-5.3/](reference/weewx-5.3/) — WeeWX 5.3.1 documentation (markdown source). **Use this** — the server runs 5.3.1.
- [reference/WEEWX-USERGUIDE-4.10.html](reference/WEEWX-USERGUIDE-4.10.html), [reference/WEEWX-CUSTOMIZING-4.10.html](reference/WEEWX-CUSTOMIZING-4.10.html), [reference/WEEWX-UPGRADING-4.10.html](reference/WEEWX-UPGRADING-4.10.html) — WeeWX 4.10 docs (legacy).
- [../reference/weather-skin.md](../reference/weather-skin.md) — Belchertown architecture facts.
- [../reference/CREDENTIALS.md](../reference/CREDENTIALS.md) — API keys, DB passwords, SSH details (gitignored).

## Procedures

Belchertown-era operational howtos:
- [procedures/CONTAINER-ACCESS.md](procedures/CONTAINER-ACCESS.md) — SSH commands, remote execution.
- [procedures/LOCAL-SKIN-TESTING.md](procedures/LOCAL-SKIN-TESTING.md) — Dev path setup, verification.
- [procedures/DEPLOYMENT.md](procedures/DEPLOYMENT.md) — Promotion checklist, rollback procedures.

## Archive

- [archive/AQI-CENTRALIZATION-PLAN.md](archive/AQI-CENTRALIZATION-PLAN.md) — Route AQI through weewx as the single hub. ✅ Complete 2026-04-29.
- [archive/MQTT-TYPO-FIX-PLAN.md](archive/MQTT-TYPO-FIX-PLAN.md) — `mgtt://` → `mqtt://` fix. ✅ Complete 2026-04-29.
- [archive/WEATHER-EVALUATION-PLAN.md](archive/WEATHER-EVALUATION-PLAN.md) — predecessor plan to Clear Skies. ✅ Closed 2026-04-29 when project pivoted from "evaluate alternative weewx skins" to "build new modern stack."

---

**When to update this file:**
- After adding new procedures, planning docs, ADRs, contracts, or reference material.
- When archiving completed plans.
- When the project structure changes.

Keep concise — one line per entry. Plan body and decision-log entries live in their own files.
