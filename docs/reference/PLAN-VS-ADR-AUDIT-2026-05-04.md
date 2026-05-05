# Plan body vs. ADR audit — 2026-05-04

**Trigger:** during the Phase 1 spike, ADR-002 was found to drop Tremor and ECharts in favor of shadcn + Recharts, but the plan body's "Tech stack decisions" table still listed Tremor + ECharts as locked. The spike was built against the stale plan content. User direction: "check the plan body against the ADRs and make sure they are congruent. It sounds like you were making decisions and not properly documenting them in the main plan document."

This file captures every drift found in `docs/planning/CLEAR-SKIES-PLAN.md` against the 39 Accepted ADRs in `docs/decisions/INDEX.md`, and the edits applied to fix them. This is the audit artifact, not a permanent decision record — the plan and the ADRs are the durable surfaces.

## Drift findings

### MAJOR — plan content conflicts with locked ADR content

| # | Plan location | Plan claim | ADR truth | Action |
|---|---|---|---|---|
| M1 | Architecture diagram (dashboard box) | "Tailwind + shadcn/ui + Tremor + ECharts + Lucide + Weather Icons" | ADR-002: Tremor dropped, Recharts is primary chart lib (ECharts dropped from primary) | Update diagram |
| M2 | Components table row 3 (dashboard) | "React + Tailwind + shadcn/ui + Tremor + ECharts" | ADR-002 same | Update row |
| M3 | Tech stack table — Component library | "shadcn/ui + Tremor" | ADR-002: "shadcn/ui (copy-paste model). Tremor dropped" | Drop Tremor |
| M4 | Tech stack table — Charting | "Apache ECharts (with Recharts as fallback)" | ADR-002: "Recharts (primary). ECharts dropped from primary" | Flip to Recharts primary |
| M5 | Phase 1 task — Validate tech-stack via spike | "Spin up Tremor + shadcn starter" | ADR-002 implementation guidance: "shadcn + Recharts starter on Tailwind v4 + React 19" | Update task description |
| M6 | Security baseline — auth model | "Optional API key (env-configurable). Required when public-facing flag is on" | ADR-008: shared secret in `X-Clearskies-Proxy-Auth` header (not API key); service starts anyway when bound non-loopback without secret (warns, does not refuse); browser SPA has no auth credentials | Rewrite to defer to ADR-008 |
| M7 | Security baseline — CORS | "Configurable CORS allowlist; default same-origin only" | ADR-008: "Same-origin proxying handles everything. CORS is a non-issue" | Drop CORS bullet |

### MINOR — plan is a subset / less specific than ADR

| # | Plan location | Plan claim | ADR truth | Action |
|---|---|---|---|---|
| m1 | Tech stack — API framework | "FastAPI (Python)" | ADR-002: "FastAPI (Python, sync route handlers)" | Add sync detail |
| m2 | Tech stack — DB layer | "SQLAlchemy 2.x (Python)" | ADR-002: "SQLAlchemy 2.x (sync mode)" | Add sync detail |
| m3 | Tech stack — SPA framework | "React (probably with Vite)" | ADR-002: "React 19 + Vite" (locked) | Lock the version |
| m4 | Tech stack — Styling | "Tailwind CSS" | ADR-002: "Tailwind CSS v4" | Pin v4 |
| m5 | Tech stack — header note | "(locked unless Phase 1 finds a better fit)" | ADRs are immutable except via supersession per `rules/clearskies-process.md` | Rewrite header |
| m6 | Tech stack table | (no row for paho-mqtt) | ADR-002: paho-mqtt as optional install extra | Add row |
| m7 | Tech stack — internal test environment | "weather-dev … for early UI iteration" | ADR-002 + 2026-05-04 rule: weather-dev is the primary dev/test environment; DILBERT is editing-only | Update phrasing |
| m8 | Security baseline | "Secrets only via environment variables" | ADR-027: secrets in `secrets.env` file (mode 0600) AND env vars | Note both paths |

### CONVENTION — full repo names per ADR-004

| # | Plan location | Plan claim | ADR truth | Action |
|---|---|---|---|---|
| c1 | Architecture diagram | "clearskies-api", "clearskies-realtime", "clearskies-dashboard" | ADR-004: full names are `weewx-clearskies-*` on first mention | Use full names in diagram + first mention |
| c2 | Components table | Headers say "clearskies-api" etc. | Same | Use full names |

### STRUCTURAL — plan body holds decision content the rule says belongs in ADRs

Per `rules/clearskies-process.md`: "Plan stays an index, not the content. Do not put decision content there — link to the ADR."

These plan sections currently duplicate decision content from ADRs and should be replaced with brief summary + pointer:

| # | Plan section | Defers to |
|---|---|---|
| S1 | Tech stack decisions table | ADR-002 |
| S2 | Cross-cutting concerns / Security baseline | ADR-008 + ADR-012 + ADR-027 + ADR-029 + ADR-030 + ADR-037, plus the in-progress `docs/contracts/security-baseline.md` |
| S3 | Versioning | ADR-018 (API wire contract) + ADR-032 (per-repo SemVer) |
| S4 | Coexistence with existing infrastructure | ADR-001 + ADR-005 + ADR-038 (largely a recap of decisions made elsewhere) |

The plan's "Documentation acceptance criteria" section is project process, not architecture decision, and has no corresponding ADR. It can stay in plan body OR move to `rules/clearskies-process.md`. Leaving in plan body for now — separate decision.

## Root cause of the drift

I treated the plan body as a primary source while the ADRs were the actual primary source. Three concrete failures from this session:

1. Phase 1 task 1 (the spike) — read the plan's stale tech stack table instead of ADR-002. Built spike against Tremor + ECharts when ADR-002 had already locked shadcn + Recharts.
2. SPIKE-FINDINGS.md "Finding 1" recommended dropping Tremor — re-discovering a decision already made and locked, with a Proposed-status edit that would have undone it.
3. Did not catch the drift earlier in the session despite reading the plan multiple times.

The rule "Plan stays an index, not the content" already exists in `rules/clearskies-process.md`. The new sub-rule lands as part of this audit: when validating a decision, read the ADR first, not the plan body.

## Edits applied

1. `docs/planning/CLEAR-SKIES-PLAN.md`:
   - Architecture diagram dashboard box: dropped Tremor + ECharts; added Recharts.
   - Components table: full `weewx-clearskies-*` names; row 3 reflects ADR-002 stack.
   - Tech stack decisions table: every row matches ADR-002 verbatim; header note revised; paho-mqtt row added.
   - Security baseline: replaced detailed bullet list with brief paragraph deferring to the relevant ADRs + the in-progress `docs/contracts/security-baseline.md`.
   - Versioning section: brief pointer to ADR-018 + ADR-032.
   - Coexistence with existing infrastructure: shortened to brief recap + ADR pointers.
   - Phase 1 task 1: "Spin up shadcn + Recharts starter on Tailwind v4 + React 19, render mock data, confirm DX."
2. `rules/clearskies-process.md`:
   - Added "Read the ADR before the plan" sub-rule under "Plan stays an index, not the content."
3. `docs/reference/SPIKE-FINDINGS.md`:
   - Acknowledges the spike validated the wrong stack on the first pass; needs re-running with Recharts; original ECharts findings preserved as "what was tested" but flagged as off-spec.

## What was NOT changed

- The 39 ADRs themselves. None of the audit findings imply an ADR is wrong; the plan was wrong.
- The decision-log entries in the plan. They are historical records, not live decisions, and don't need to track ADR refinements.
- The phase task tables (Phases 1-6 status rows). Each cell either correctly references an ADR or describes a non-decision task (build CI, run audit, etc.).
- The "Documentation acceptance criteria" section. Project process; no corresponding ADR; staying put.
