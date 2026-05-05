---
status: Accepted
date: 2026-04-30
deciders: shane
---

# ADR-003: License = GPL v3

## Context

Project will be released publicly. Need to choose a license consistent with the weewx ecosystem and the project's goals (community-driven, end-user-managed compliance per [ADR-006](ADR-006-compliance-model.md), commercial status not pre-locked).

## Options considered

| Option | Pros | Cons |
|---|---|---|
| MIT/BSD (permissive) | Maximum reuse | Allows proprietary forks; misaligned with weewx (GPL v3) |
| Apache 2.0 (permissive + patent grant) | Patent protection | Still permits closed-source forks; misaligned with weewx |
| GPL v3 | Mirrors weewx ecosystem; copyleft preserves open-source | Some commercial actors avoid GPL; can deter contributions |
| AGPL v3 | Forces network-deployed forks to also be open | Too restrictive for a hobbyist project; deters most contributors |

## Decision

**GPL v3** across all five repos. Mirrors the weewx project's own license; aligns the project with the ecosystem it lives in.

## Consequences

- All derivative work must be GPL v3 or compatible.
- Some commercial actors will not contribute due to GPL v3's anti-tivoization clause. Acceptable trade for weewx ecosystem alignment.
- Per [ADR-006](ADR-006-compliance-model.md), license choice does not pre-lock project commercial status; donations and sponsorship are compatible with GPL v3.
- **SaaS loophole acknowledged.** GPL v3 (unlike AGPL v3) does not require third parties running Clear Skies as a hosted service to release source. We accept this — our project remains open; downstream services can build on top without contributing back. AGPL was considered and rejected: overkill for self-hosted weather dashboards.
- **Dependency-license compatibility verified at adoption time.** All deps in [ADR-002](ADR-002-tech-stack.md) verified GPL-3.0-or-later compatible per audit at [docs/reference/DEPENDENCY-LICENSE-AUDIT.md](../reference/DEPENDENCY-LICENSE-AUDIT.md) (2026-04-30). One conditional: paho-mqtt is dual-licensed (EPL-2.0 / EDL-1.0); we elect EDL-1.0 (equivalent to BSD-3-Clause, GPL-compatible) — see Implementation guidance. New deps added in Phase 2+ require manual license verification at PR time, with the audit table updated accordingly.
- **Patent grants are a positive feature.** GPL v3 includes explicit patent grants from contributors, protecting downstream users from patent claims by upstream contributors.
- Document rationale in each repo's `LICENSE-RATIONALE.md` so users understand the choice rather than treat it as arbitrary.

## Implementation guidance

### Per-repo files

- `LICENSE` — full GPL v3 text from gnu.org (verbatim).
- `LICENSE-RATIONALE.md` — one paragraph: mirrors weewx, copyleft preserves OSS status.
- README header: license badge + one-line "GPL v3 — same as weewx" statement.
- Code file headers: optional. If used, the standard GPL v3 short header.

### License-version specifier

Use **`GPL-3.0-or-later`** (not `GPL-3.0-only`) in SPDX identifiers, `pyproject.toml` license fields, `package.json` license fields, and any other metadata.

**Rationale:** future-version compatibility. If GPL v4 ships and the community moves to it, downstream users get flexibility without our intervention. `GPL-3.0-only` would lock us to v3 forever — we'd have to relicense every repo to follow.

SPDX identifier in source files (recommended but optional): `SPDX-License-Identifier: GPL-3.0-or-later` as a second-line comment.

### Contributor licensing

Use **DCO (Developer Certificate of Origin), not a CLA.**

- Each commit signed off via `git commit -s`, adding a `Signed-off-by: Name <email>` trailer.
- Per-repo `CONTRIBUTING.md` explains the DCO policy and the `git commit -s` pattern.
- Lighter-weight than a CLA; sufficient for OSS projects of this scale; doesn't require contributors to sign legal agreements before their first commit.

### License verification

The current dependency set in [ADR-002](ADR-002-tech-stack.md) was verified GPL-3.0-or-later compatible at decision time. Verification table and sources: [docs/reference/DEPENDENCY-LICENSE-AUDIT.md](../reference/DEPENDENCY-LICENSE-AUDIT.md).

**For new dependencies added in Phase 2 or later:** the PR adding the dep must include a manual license verification — check the lib's upstream LICENSE file, confirm GPL-3.0-or-later compatibility, and update the audit table with the new row before merge.

Automated CI scanning was considered and dropped: simple SPDX-field scanners would not have caught nuanced cases like paho-mqtt's dual-license election, so they would give false confidence. Manual review at PR time is the policy.

**paho-mqtt election (conditional, applies only if paho-mqtt remains in scope per [ADR-005](ADR-005-realtime-architecture.md)):** declare EDL-1.0 (not EPL-2.0) as the operative license in the realtime service's `LICENSE-RATIONALE.md` and any `NOTICE` file. Preserve the EDL-1.0 / BSD-3-Clause copyright notice with the distribution.

## References

- Related ADRs: [ADR-006](ADR-006-compliance-model.md)
- weewx license: https://github.com/weewx/weewx (GPL v3)
