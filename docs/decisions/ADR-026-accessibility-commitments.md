---
status: Accepted
date: 2026-05-02
deciders: shane
supersedes:
superseded-by:
---

# ADR-026: Accessibility commitments

## Context

User direction 2026-05-02: "ADA compliance is something we HAVE to make sure we are always keeping an eye on. … audit all code after it is written for compliance and then have a full audit before shipping." Accessibility is load-bearing project-wide, not a Phase 4 polish item.

## Decision

**WCAG 2.1 Level AA conformance** is the project-wide accessibility floor. Failures are release-blocking — same severity as a security vulnerability or a broken build.

- **Per-change audit:** every UI change runs the per-change checklist in [rules/coding.md](../../rules/coding.md) §5.7 before "done."
- **Pre-ship audit:** every release runs the full audit per §5.8 (automated axe-core, manual keyboard run, screen reader spot check, Lighthouse ≥ 95, color-blindness simulation). Documented in `docs/audits/accessibility-vX.Y.md`.

Concrete rules (color/contrast, semantic HTML, keyboard nav, ARIA, images, charts, localization) live in [rules/coding.md](../../rules/coding.md) §5 — implementation details, not ADR content.

## Options considered

| Option | Verdict |
|---|---|
| A. WCAG 2.1 Level AA (this ADR) | **Selected.** Industry-standard floor; achievable for a data-rich dashboard. |
| B. WCAG 2.1 Level A | Rejected — leaves out contrast-ratio and visible-focus requirements that are baseline expectations. |
| C. WCAG 2.1 Level AAA | Rejected — impractical for visualization-heavy dashboards; some chart idioms intrinsically can't pass AAA. |
| D. No formal commitment / best-effort | Rejected — user direction is explicit. |

## Consequences

- Design ADR ([ADR-009](ADR-009-design-direction.md)) factors AA contrast into palette choices in both light and dark themes.
- Page taxonomy ([ADR-024](ADR-024-page-taxonomy.md)) and per-page card layouts have to be keyboard-reachable with visible focus indicators.
- Operator-uploaded images require alt text at upload time per [rules/coding.md](../../rules/coding.md) §5.5.
- Charts ship with screen-reader data-table fallbacks (§5.5).
- A new doc directory `docs/audits/` is created; one file per release tag.

## Out of scope

- RTL layout — no RTL languages in v0.1 locale set ([ADR-021](INDEX.md), Pinned). Don't write LTR-assuming CSS so RTL is a future-add, not a future-rewrite.
- Voice / switch control beyond what semantic HTML provides automatically.
- Conformance with regional rules beyond WCAG (Section 508, EN 301 549) — covered by AA conformance in practice; no separate certification.

## References

- WCAG 2.1: https://www.w3.org/WAI/WCAG21/quickref/?levels=aa
- Implementation rules: [rules/coding.md](../../rules/coding.md) §5.
- Walk artifact: cat 11 in [docs/reference/CLEAR-SKIES-CONTENT-DECISIONS.md](../reference/CLEAR-SKIES-CONTENT-DECISIONS.md).
- Related ADRs: [ADR-009](ADR-009-design-direction.md), [ADR-024](ADR-024-page-taxonomy.md), [ADR-021](INDEX.md) (i18n — Pinned).
