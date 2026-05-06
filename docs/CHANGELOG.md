# CHANGELOG

All notable changes to the weather-belchertown project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### 2026-05-06 — Clear Skies Phase 2 task 1: FastAPI scaffold complete

- **Phase 2 task 1 (FastAPI scaffold) complete.** Eight commits on `main` at github.com/inguy24/weewx-clearskies-api: initial scaffold (39 files, 3095 insertions; project layout per [ADR-036](decisions/ADR-036-workspace-layout.md), middleware stack per [security-baseline §3.1](contracts/security-baseline.md), proxy-auth shared secret per [ADR-008](decisions/ADR-008-auth-model.md), RFC 9457 problem+json error handler per [ADR-018](decisions/ADR-018-api-versioning-policy.md), separate-port health on loopback per [ADR-030](decisions/ADR-030-health-check-readiness-probes.md), JSON logging + redaction filter per [ADR-029](decisions/ADR-029-logging-format-destinations.md), ConfigObj/INI loader for `api.conf` per [ADR-027](decisions/ADR-027-config-and-setup-wizard.md), IPv4/IPv6 dual-stack listener per [coding.md §1](../rules/coding.md), pytest scaffold with FastAPI `TestClient`), three pytest-surfaced fix commits (regex group reference in redaction filter; missing path-existence check in `load_settings`; Authorization regex stopping at first whitespace), `uv.lock` follow-up, two dep-audit workflow fixes (scope `pip-audit` to project deps via `uv export --format requirements-txt --no-emit-project`), and a fastapi 0.115.12 → 0.136.1 / starlette 0.46.2 → 1.0.0 bump clearing two real CVEs (CVE-2025-54121, CVE-2025-62727). 73/73 pytest pass on `weather-dev`; both CI workflows (`gitleaks`, `dep-audit`) green. Implements security-baseline §3.1 (network listener), §3.2 (auth), §3.4 (secrets handling), §3.6 (logging + redaction), §3.7 (health). §3.3 (DB) deferred to task 2; §3.5 (full input validation) deferred to task 3 when real Pydantic models land; §3.8 (process hardening) deferred to task 7. Multi-agent execution: api-dev (Sonnet) + auditor (Opus) ×2 + lead (Opus) synthesis.
- **Process rule strengthened.** [rules/clearskies-process.md](../rules/clearskies-process.md) "Plain English when explaining decisions to the user" now requires every technical term, library name, RFC number, file convention, and project-internal acronym be defined the first time it appears in a conversation; later uses can lean on the earlier definition. Counter resets per new conversation. [CLAUDE.md](../CLAUDE.md) "Collaboration style" gained a matching cross-cutting bullet. Trigger: synthesis after the first round of audit findings used a wall of unexplained terms ("RFC 9457 problem+json", "FastAPI TestClient", "loopback port 8081", "trusted-bypass path", "hmac.compare_digest"). User verbatim: *"you have been bombarding me with so much jargon, I cannot see straight."*
- **Branching policy decided.** No feature branches pre-1.0; commit straight to `main`/`master` on all repos. Pre-1.0 with no users, branches add overhead without value. Policy revisits when v0.1 ships and there are real consumers to protect from broken intermediate states.
- **dep-audit workflow refinement** (api repo only). Phase 1's `pip-audit --strict` with no manifest argument audited the entire CI runner Python environment, not project deps — the runner's own pip carried CVEs unrelated to this project so the workflow failed on every push once a manifest existed. Fixed via `uv export --format requirements-txt --no-emit-project` then `pip-audit -r` against that file. Other four repos (realtime, dashboard, stack, design-tokens) still have the original workflow shape; it skips cleanly while their content is placeholder, will need the same one-line fix when each lands its first real code.

### 2026-05-05 — Clear Skies Phase 1: API contract + earthquake provider ADR

- **Phase 1 task: API contract committed** at [contracts/openapi-v1.yaml](contracts/openapi-v1.yaml). OpenAPI 3.1, 23 paths, 53 schemas, validates clean against `openapi-spec-validator`. Endpoint inventory derived from [ADR-024](decisions/ADR-024-page-taxonomy.md) page taxonomy + [ADR-010](decisions/ADR-010-canonical-data-model.md) canonical entities; URL-path versioning + RFC 9457 errors per [ADR-018](decisions/ADR-018-api-versioning-policy.md); auth security scheme is the optional shared secret from [ADR-008](decisions/ADR-008-auth-model.md); pagination on `/archive` and `/aqi/history` supports both cursor and page-number forms; `/reports/{year}/{month}` returns raw weewx-generated text (dashboard parses fixed-width client-side — operator decision); realtime SSE deliberately not in this spec (separate `weewx-clearskies-realtime` contract).
- **[ADR-040](decisions/ADR-040-earthquake-providers.md) Accepted.** Earthquake providers as clearskies-api plugin modules per [ADR-038](decisions/ADR-038-data-provider-module-organization.md). Day-1 set: usgs / geonet / emsc / renass — all FDSN-Event-compliant, free, no key. Single source per deploy; setup wizard suggests by region; USGS provides global fallback so no operator is uncovered. Mirrors [ADR-016](decisions/ADR-016-severe-weather-alerts.md) shape. Research: [reference/EARTHQUAKE-PROVIDER-RESEARCH.md](reference/EARTHQUAKE-PROVIDER-RESEARCH.md).
- **[ADR-010](decisions/ADR-010-canonical-data-model.md) re-Accepted** with `EarthquakeRecord` entity added (per item-7 in-place correction). Required fields: `id`, `time`, `latitude`, `longitude`, `magnitude`, `source`. Optional: `depth`, `magnitudeType`, `place`, `url`, `tsunami`, `felt`, `mmi`, `alert` (USGS PAGER), `status`, `extras`. Brings entity count to 9 cores + 2 containers. Drove a `normalize_earthquakes` addition to the provider normalizer contract.

### 2026-05-04 — Clear Skies Phase 1: tech-stack spike + plan-vs-ADR audit

- **Phase 1 task 1 (tech-stack spike) complete.** Vite 8 + React 19 + TypeScript 6 + Tailwind v4 + shadcn v4 + Recharts 3.8 + Lucide validated end-to-end inside `weather-dev`. Production bundle 164.52 KB gzipped — under [ADR-033](decisions/ADR-033-performance-budget.md)'s 200 KB budget by ~35 KB. Two scaffold-time footguns documented: `react-is` override for Recharts on React 19, and `ignoreDeprecations: "6.0"` for the TS6 `baseUrl` deprecation. Findings: [reference/SPIKE-FINDINGS.md](reference/SPIKE-FINDINGS.md).
- **Plan-vs-ADR audit completed and applied.** Drift fixed in plan body: architecture diagram, components table, tech stack table, security baseline, versioning, coexistence, Phase 1 task descriptions all updated to match the 39 Accepted ADRs verbatim or to defer to them as authoritative pointers. Trigger: spike was built against the plan body's stale tech-stack table (Tremor + ECharts) when ADR-002 had already locked shadcn + Recharts. New process sub-rule landed in [rules/clearskies-process.md](../rules/clearskies-process.md) "Read the ADR before the plan." Audit findings: [reference/PLAN-VS-ADR-AUDIT-2026-05-04.md](reference/PLAN-VS-ADR-AUDIT-2026-05-04.md).
- **Phase 1 task: weather-dev LXD container** stood up on ratbert at `192.168.2.113` (DHCP/SLAAC on br-vlan2). Ubuntu 24.04, Docker-in-LXC nesting, 6 GB memory cap. Provisioned: Docker Engine 29.4 + Compose v5, Node 22 LTS, Python 3.12, uv. Brought forward from Phase 4 because Windows host is a misfit for Linux-first toolchains. Roster entry in `Windows Server/reference/ratbert-lxd.md`.
- **Phase 1 task: docker-compose dev/test stack** scaffolded at [`repos/weewx-clearskies-stack/dev/`](../repos/weewx-clearskies-stack/dev/). MariaDB 10.11 + backend-agnostic Python seed loader. Snapshot capture script (host-side, SQLAlchemy reflection) + seed loader (containerized) — same captured dataset loads into MariaDB or SQLite per [ADR-012](decisions/ADR-012-database-access-pattern.md). Validated end-to-end inside `weather-dev`; both backend profiles load + verify against synthetic fixture. Three real defects surfaced and fixed during validation (silent CSV-row truncation in loader, invalid `pip install --require-hashes=false` Dockerfile syntax, SQLite volume permission collision with non-root container `USER`).

### 2026-05-02 — Clear Skies Phase 1 ADR backlog closed

- **All 39 ADRs Accepted.** Phase 1's architecture-decision surface fully resolved: 5-component breakdown, tech stack, license (GPL v3), repo naming (`weewx-clearskies-*`), realtime architecture (direct + MQTT), compliance model, forecast providers, auth (no end-user, optional shared-secret header), inbound-traffic architecture (one-door reverse proxy), config + setup wizard, canonical data model, multi-station scope (single-station only at v0.1), DB access pattern (SQLAlchemy 2.x sync, read-only enforcement), AQI handling, almanac source (Skyfield), radar/map tiles, severe-weather alerts, provider response caching, API versioning policy (RFC 9457 errors), units handling, time zone handling, i18n (13 locales, no RTL), theming/branding, light/dark mode mechanism, page taxonomy (9 built-in pages), browser support matrix, accessibility commitments (WCAG 2.1 AA, release-blocking), update mechanism, logging format, health-check probes, observability/metrics, versioning across repos, performance budget, deployment topology default, user-driven column mapping, workspace layout, data-provider module organization, distribution/installation. ADR INDEX: [decisions/INDEX.md](decisions/INDEX.md).
- Subsequent cleanup pass (2026-05-04) trimmed nine bloated ADRs in place per the conciseness rule; the remaining 28 audited paragraph-by-paragraph and confirmed tight.

### 2026-04-29 — Project pivot to Clear Skies

- **Pivoted** from "evaluate alternative weewx skins" to "build new modern stack from scratch." Driver: every weewx-ecosystem skin (Belchertown, Seasons, Beautiful Dashboard, Smartphone, Weather Eye) read as visually amateurish; lateral move would not solve the redesign goal. Predecessor plan archived: [archive/WEATHER-EVALUATION-PLAN.md](archive/WEATHER-EVALUATION-PLAN.md). New plan: [planning/CLEAR-SKIES-PLAN.md](planning/CLEAR-SKIES-PLAN.md).
- Five-component breakdown adopted; project name "Clear Skies" verified clear in weewx ecosystem; license set to GPL v3 to mirror weewx.

### 2026-04-29 — AQI centralization (complete)

- **Removed Aeris airquality dependency** from `belchertown.py`: dropped `aqi_url` construction, HTTP fetch, and `"aqi"` key from all 4 `forecast.json` write blocks.
- **AQI now reads from archive DB** via `getSql()` query — single source of truth, no duplicate API calls.
- **Added `aqi_pollutant` template variable** — exposes `main_pollutant` from archive; displayed in AQI block instead of location (location is always Huntington Beach).
- **Added `[airquality]` chart group** to `graphs.conf` — 24h and 7-day AQI history charts.
- Deployed and verified: site shows AQI=21.0 (good), PM2.5 from AirVisual. Aeris airquality endpoint no longer called (~24 fewer calls/day).
- See archived plan: [docs/archive/AQI-CENTRALIZATION-PLAN.md](archive/AQI-CENTRALIZATION-PLAN.md)

### 2026-04-29 — Phase 1 assessment

- Merged origin/master (Belchertown skin code) into local working tree via `--allow-unrelated-histories`. Renamed local README.md → README-eval.md to avoid collision.
- Created local tracking branches `dropdowns` and `inguy24-changes` from origin.
- Pulled WeeWX 5.3.1 docs (98 markdown files from GitHub `weewx/weewx` tag `v5.3.1`) into `docs/reference/weewx-5.3/`. Server runs 5.3.1, not 4.10.
- Pulled WeeWX 4.10 user guide / customizing / upgrading HTML into `docs/reference/` for legacy reference.
- Wrote `docs/reference/SERVER-INVENTORY.md` — authoritative map of containers, MQTT chain, static-site sync via LXD shared disk, etc.
- Wrote `docs/reference/REPO-VS-SERVER-DIFF-2026-04-29.md` — file-by-file diff of live skin vs `master`/`dropdowns`/`inguy24-changes`. Identified 7 files on the server that exist in NO branch.
- Corrected `reference/weather-skin.md` — old paths (`/home/weewx/skins/...`), unknown weewx version, and incorrect TLS-termination claim.
- **Identified MQTT root cause:** `mgtt://` typo in `weewx.conf` `[StdRESTful][[MQTT]]` server_url scheme. Cause of regular users not seeing live data.
- No code changes deployed. No commits pushed to GitHub.

### Earlier

- Project initialized with evaluation framework
- Created documentation structure (rules, reference, planning)
- Set up credentials and access configuration

## [1.0.0-evaluation] — 2026-04-29

- Initial project setup with Belchertown fork
- Documentation & evaluation criteria defined
