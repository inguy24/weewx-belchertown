---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-033: Performance budget

## Context

[ADR-026](ADR-026-accessibility-commitments.md) commits to a Lighthouse Accessibility floor; this ADR sets the parallel performance budget. These are **internal targets**, not commitments — software is AS-IS under GPL v3 ([ADR-003](ADR-003-license.md)) per the no-support-window posture in [ADR-018](ADR-018-api-versioning-policy.md). The numbers define the quality bar Phase 3+ work measures itself against.

## Decision

### Lighthouse Performance ≥ 90 on primary pages

Measured against `clearskies-dashboard` build artifacts on Now / Forecast / Charts / Records. Below 90 on a release flags a pre-tag investigation.

### Core Web Vitals — "Good" thresholds

| Metric | Target |
|---|---|
| Largest Contentful Paint (LCP) | ≤ 2.5 s |
| Interaction to Next Paint (INP) | ≤ 200 ms |
| Cumulative Layout Shift (CLS) | ≤ 0.1 |

(Google's current CWV "Good" thresholds.)

### Bundle size

Initial JS bundle: target **≤ 200 KB gzipped** for the Now-page route. Monitored in CI via `vite-bundle-visualizer` (or equivalent). Going over flags a review — charting and i18n bundles can grow legitimately; we want awareness, not a hard fail.

### API latency targets (p95)

| Endpoint class | p95 target |
|---|---|
| Archive read (current/today/recent) | < 100 ms |
| Archive aggregation (charts; window over the archive) | < 500 ms |
| Provider response — cache hit | < 50 ms |
| Provider response — cache miss | bounded by upstream provider; module retry/timeout tuned per provider |

Measured against the local dev environment with realistic data. Production performance depends on operator hardware and network — we don't promise it.

### Measurement

- **Lighthouse CI** runs against the built dashboard on PR.
- **Accessibility scoring** lives separately per [ADR-026](ADR-026-accessibility-commitments.md).
- **API benchmarks**: pytest + `pytest-benchmark` (or equivalent) for the four endpoint classes above.
- **Pre-ship audit**: full Lighthouse run captured in `docs/audits/<release>.md` per [ADR-026](ADR-026-accessibility-commitments.md) §5.8 — Performance score recorded alongside Accessibility.

### Targets, not gates — what happens when we miss

These numbers are **aspirational quality targets, not release gates**. If a release misses any of them:

1. Record the actual measured numbers in `docs/audits/<release>.md`.
2. Note the cause briefly (e.g., "new chart type pushed bundle to 240 KB").
3. File a backlog issue if the miss is fixable.
4. Ship the release.

We do **not** block a release on a perf miss. Perf scores depend on operator hardware, browser version, network conditions, and chart density — gating releases on a single Lighthouse number would be theater, not quality.

**This is different from accessibility** — [ADR-026](ADR-026-accessibility-commitments.md) explicitly makes a11y failures release-blocking because a11y determines whether a class of users can use the dashboard at all. Perf is a quality signal, not a usability gate.

## Options considered

| Option | Verdict |
|---|---|
| A. Lighthouse ≥ 90 + CWV "Good" + bundle ≤ 200KB + p95 latency targets (this ADR) | **Selected** — covers the visible quality surfaces without over-committing. |
| B. Lighthouse ≥ 95 (parity with Accessibility) | Rejected — Performance score is more sensitive to chart-heavy pages and operator hardware; 90 is realistic for a data-dense dashboard, 95 punishes legitimate dashboard density. |
| C. No performance budget | Rejected — Phase 4 needs a number to optimize against. |

## Consequences

- Phase 3 work uses code-splitting and lazy loading to keep the Now-page initial bundle under target.
- Phase 4 audit task captures Lighthouse Performance + Accessibility numbers in `docs/audits/<release>.md`.
- Chart-heavy pages may legitimately drop below 90 on slow connections — documented as expected.
- API benchmark suite is a Phase 2 deliverable.

## Out of scope

- Specific Lighthouse environment configuration — Phase 4.
- CI auto-fail on perf regression — Phase 6+; manual review for v0.1.
- Real-user monitoring (RUM) — Phase 6+.
- Server-side observability detail — [ADR-031](INDEX.md), Pinned.

## References

- Lighthouse: https://developer.chrome.com/docs/lighthouse/overview/
- Core Web Vitals: https://web.dev/articles/vitals
- Related: [ADR-003](ADR-003-license.md), [ADR-018](ADR-018-api-versioning-policy.md), [ADR-026](ADR-026-accessibility-commitments.md), [ADR-031](INDEX.md).
