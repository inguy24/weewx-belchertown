# Track A — Implementation (coding) session kickoff

**Purpose:** Track A *design/decision* work is DONE (all foundations Accepted as ADRs). This session turns
those decisions into **code** across the Clear Skies repos. This is a build session, not a design session.

---

## Operating posture (read first)

- **Lead = Opus, orchestration + judgment ONLY.** You do not write code, run tests, or do reviews — you
  break down work, write prescriptive briefs, spawn **Sonnet** implementers, monitor, verify, and commit.
- **Delegate ALL reading/grep/state-verification to Sonnet** (Explore / general-purpose). Opus tokens are
  for synthesis and judgment, not file reads.
- **Follow `rules/clearskies-process.md` and `rules/coding.md` exactly** — agent orchestration, scope
  binding, pre-flight repo verification, independent verification of all teammate claims, false-claim
  protocol, round-close gate.
- **Git:** never push without the user typing "push." Every implementer prompt carries the git-restriction
  block (no pull/push/fetch/rebase/merge; only add/commit/status/log/diff). Pre-flight `git status` +
  `git log -1` on EVERY target repo before dispatch; unexpected state → STOP and report.
- **Runtime = `weather-dev` LXD container**, not Windows. Sync: push to GitHub from DILBERT, then
  `scripts/sync-to-weather-dev.sh`. Browser test at `http://192.168.2.113:<port>`. DILBERT = edit/git/plan only.

## Reading list (delegate to Sonnet; extract relevant sections)

- `CLAUDE.md`, `rules/clearskies-process.md`, `rules/coding.md`, `rules/github.md`
- `docs/ARCHITECTURE.md` — **source of truth** for repos/services/topology/paths (do not re-derive)
- The Accepted ADRs that define the work + their locked mockups:
  - **ADR-048** (A1 tokens) — adopts as-built; verify-only
  - **ADR-047** (A2 background) + its build brief `docs/planning/briefs/A2-background-system.md`
  - **ADR-049** (A3 hero icons) + recipe `docs/design/mockups/A3-material-gradient.html`
  - **ADR-050** (A3 utility/nav/alert icons) + render `docs/design/mockups/A3-final-icons.html`
  - **ADR-051** (A4 card model) + `docs/design/mockups/A4-card-grid.html`, `A4-page-anatomy.html`
- `docs/design/C0-PAGE-INVENTORY.md` — page/card inventory

## The work, by ADR

| ADR | Scope (code) | Key files / repos |
|---|---|---|
| **A1 / ADR-048** | **Verify-only** — confirm the as-built token set matches the ADR. No code change expected. Chart-palette + AQI-palette gaps are **deferred — NOT this session.** | dashboard `src/index.css` (read-only check) |
| **A2 / ADR-047** | Execute the **existing build brief** (3 deliverables). | per the A2 brief (realtime scene tag, dashboard background layer, …) |
| **A3 / ADR-049** | Rewrite the hero weather-icon component → **inline Material Symbols SVG with the locked gradient defs**; map every WMO code. | dashboard `src/components/weather-icon.tsx` (+ `WMO_MAP`) |
| **A3 / ADR-050** | Implement the **Phosphor-base** icon set: pick rendering mechanism (`@phosphor-icons/react` + inline SVG for the 3 cross-pack glyphs, **or** Iconify); replace Lucide usages per the curated map; add the 13-type **alert-icon** map; text-only stats get **no** icon; wind icons excluded (C2 owns them). | dashboard — icon usages across components |
| **A4 / ADR-051** | Add tokens (`--gap-grid` 1rem, `--container-max` 80rem, `--card-row` 11rem, `--card-half-row` 5.5rem) to `@theme`; build the **grid primitive** (half-row track; footprint col/row-span convention or a Card `footprint` prop; strips span 1 / data 2 / tall 4); build **page-header card** + **controls-strip** components. **Scope note:** build the PRIMITIVES + tokens. Full per-page application of the universal card discipline (reconciling every page, moving Records buttons in-card, removing the Reports explainer) is **Track C**, not this session. | dashboard `src/index.css`, a grid/layout primitive, `card.tsx`, new page-header/controls-strip components |

## Process gate — write execution briefs FIRST

Per Layer-3 discipline, **A3 (hero), A3 (utility), and A4 each need an execution brief in
`docs/planning/briefs/` before any implementer is dispatched** (A2 already has one). Each brief:
scope in/out (exhaustive file list + explicit "do NOT touch"), per-deliverable spec, QC gates derived from
the ADR's acceptance criteria, definition of done, the exact verification command (on weather-dev), and the
agent git-restriction block. **Briefs reference the ADRs; they never restate decisions. ADR wins on conflict.**

## Sequencing & dependencies

- Suggested order: **A4 tokens+grid primitive (foundation) → A3 icons (both) → A2 background → verify.**
  Parallelize only where repos don't collide.
- **B3 contrast/perf gate is NOT done** and sets the **final card-glass opacity** for ADR-051. Use a sensible
  interim opacity now, flag it as provisional, and don't block on B3.
- Out of scope this session: A1 chart/AQI palette gaps; visitor-help destination; the operator drag-and-drop
  grid engine; full Track-C per-page reconciliation.

## Carry-forward (track, don't build here)

- **Restore the Now hero** (station logo + name) = Track C / **C1**, not A4 coding.
- **Operator manual** (setup/use of the customizable dashboard) = its own deliverable.

## Definition of done (this session)

- A2 / A3 / A4 ADR **acceptance criteria met in code**, verified independently on weather-dev (build passes,
  any tests pass, visual states checked).
- Execution briefs for A3/A4 committed to `docs/planning/briefs/`.
- Each ADR's changes committed to the correct repo(s); lead-verified (re-run verification, spot-check a
  requirement, compare commits to scope); plan updated to reflect code-complete.
- **No push without the user's explicit "push."**
