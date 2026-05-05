---
status: Accepted
date: 2026-05-04
deciders: shane
supersedes:
superseded-by:
---

# ADR-036: Workspace & meta-repo layout

## Context

[ADR-001](ADR-001-component-breakdown.md) commits to five separable repos (api / realtime / dashboard / stack, plus the deferred design-tokens). Each must remain independently cloneable and releasable. At the same time, the project depends on a shared body of context — `CLAUDE.md`, `rules/`, `reference/`, `docs/planning/`, `docs/decisions/`, `docs/contracts/` — that must apply to work in every repo. Duplicating into each child means drift within months; isolating in one means the others can't see them.

Two structural constraints frame the decision:

1. **Claude Code's `CLAUDE.md` discovery walks up the filesystem from cwd.** The meta directory holding `CLAUDE.md` must be an *ancestor* of each repo, not a sibling.
2. **Each Clear Skies repo must be a standalone git repository** — distribution requires `git clone https://github.com/inguy24/weewx-clearskies-api` to produce a complete project.

Working from `c:\CODE\weather-belchertown\` (already home of shared `CLAUDE.md`, `rules/`, `reference/`, `docs/`).

## Options considered

| Option | Verdict |
|---|---|
| A. Sibling directories (`c:\CODE\weather-belchertown\` + `c:\CODE\weewx-clearskies-api\` peers) | Rejected — breaks `CLAUDE.md` walk-up; would force per-repo duplication or hand-maintained pointers. |
| B. Nested under meta (`c:\CODE\weather-belchertown\repos\weewx-clearskies-*\`) | **Selected.** Walk-up works automatically; each child stays independent; VS Code multi-root workspace handles the tree cleanly. |
| C. Symlinks per repo | Rejected — brittle on Windows (NTFS symlinks need elevation/dev mode); pollutes git status. |
| D. Git submodules | Rejected — fragile; every contributor and CI step needs the dance. |
| E. Monorepo | Rejected — direct contradiction with [ADR-001](ADR-001-component-breakdown.md). |

## Decision

Adopt **nested layout**:

```
c:\CODE\weather-belchertown\                       <- meta dir, own git repo
├── CLAUDE.md
├── rules/        reference/        docs/           <- shared, NEVER duplicated
├── weather-clearskies.code-workspace
└── repos/
    ├── weewx-clearskies-api/                       <- independent git repo
    ├── weewx-clearskies-realtime/                  <- independent git repo
    ├── weewx-clearskies-dashboard/                 <- independent git repo
    └── weewx-clearskies-stack/                     <- independent git repo
    (weewx-clearskies-design-tokens/ added in Phase 6+ per ADR-001 deferral)
```

Meta directory keeps the name `weather-belchertown` for now. Rename deferred to a clean break point (likely end of Phase 1 or Phase 2) so we don't churn relative paths during active design work.

VS Code: a single `.code-workspace` at the meta root opens the meta + child repos as folders, with display labels masking the misleading `weather-belchertown` name.

## Consequences

- `CLAUDE.md`, `rules/`, `reference/` are authoritative in exactly one place.
- Agents launched from any depth find the same `CLAUDE.md` automatically.
- ADRs and the plan stay centralized in `docs/`.
- Each child remains a normal standalone git repo — `git clone` from GitHub produces a complete project with no hidden meta-dependency.
- VS Code multi-root gives single sidebar, single search, single terminal palette across all working trees.

### Trade-offs accepted
- Folder name `weather-belchertown` is misleading once non-Belchertown code lives under it. Mitigated by workspace label and future rename.
- Children sit one extra directory level deep. Cosmetic.
- Anyone cloning a child repo *outside* the meta tree (community contributor doing `git clone` to `~/projects/`) won't see rules / reference / docs. Correct and intended — public repos ship their own README/INSTALL/CONFIG/SECURITY per the plan's acceptance gate; the meta operations context is private to the maintainer.
- Tying rule-sharing to filesystem layout means "keep the layout." Documented here and reinforced by the workspace file.

## Implementation guidance

### Workspace file and `repos/` directory

1. Create `c:\CODE\weather-belchertown\repos\` (empty; `.gitkeep` if needed for tracking).
2. Create `weather-clearskies.code-workspace` with the meta folder only. Child folders are NOT pre-listed — appended only when each repo is actually created. Avoids missing-folder warnings.

```json
{
  "folders": [
    { "path": ".", "name": "📋 meta — ops, rules, docs" }
  ],
  "settings": {
    "files.exclude": {
      "**/.git": true,
      "**/node_modules": true,
      "**/__pycache__": true
    }
  }
}
```

3. Commit `.code-workspace` to the meta repo's git.

### When each child repo is created

For each Clear Skies repo:

1. Create the GitHub repo per [ADR-004](ADR-004-repo-naming.md) naming.
2. `git clone` into `c:\CODE\weather-belchertown\repos\<repo-name>\` — NOT into `c:\CODE\` directly.
3. Initial files per [CLEAR-SKIES-PLAN.md](../planning/CLEAR-SKIES-PLAN.md) Phase 1: `README.md`, `LICENSE` (GPL v3 per [ADR-003](ADR-003-license.md)), `SECURITY.md` placeholder.
4. **Do not** create a per-repo `CLAUDE.md`, `rules/`, or `reference/`. Auto-discovery from meta is sufficient.
5. **Do not** copy `docs/` into the child. ADRs and plan stay in meta only.
6. **Append the new repo to `weather-clearskies.code-workspace`** with a label matching convention (`🔌 api`, `📡 realtime`, `🖥 dashboard`, `📦 stack`). Commit the workspace-file change to the meta repo in the same task that creates the child repo.

### Edge cases

- **Contributor clones outside the meta tree:** expected and correct. Meta operations context is private.
- **CI runs:** GitHub Actions runs in the child checkout only and never sees meta. No CI step may depend on meta files. Anything CI needs (lint configs, security baseline checks) is duplicated *intentionally* per child as part of standing up that repo.

### Optional belt-and-suspenders per-repo `CLAUDE.md` stub

If sessions starting deep inside a child repo turn out not to find the meta `CLAUDE.md` reliably, each child can carry a 5-line stub pointing at `../../CLAUDE.md`. Default is to skip — add only if discovery proves unreliable in practice.

## Out of scope
- Rename of `weather-belchertown\` itself — separate decision (when, to what name, how to mass-update relative paths).
- Design-tokens repo — deferred to Phase 6+ per [ADR-001](ADR-001-component-breakdown.md).

## References
- Related: [ADR-001](ADR-001-component-breakdown.md), [ADR-003](ADR-003-license.md), [ADR-004](ADR-004-repo-naming.md).
- Process: [rules/clearskies-process.md](../../rules/clearskies-process.md).
