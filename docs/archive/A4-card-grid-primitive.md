# Execution plan — A4 Card footprint model & grid primitive (ADR-051)

> This brief **references** ADR-051; it does not restate decisions. **ADR-051 wins on any conflict.**
> Read `docs/decisions/ADR-051-card-footprint-model.md` before coding.

## Round identity
- Track A, deliverable A4. Lead: Opus. Implementer: 1 × Sonnet (dashboard).
- Repo: `weewx-clearskies-dashboard` (branch `main`). Date: 2026-05-30.

## Pre-round verification (lead did this before writing the brief)
- dashboard repo `git status`: clean, up to date with `origin/main`. `git log -1`: `f40d641`.
- Confirmed via recon: none of the four A4 tokens exist in `src/index.css` `@theme`; `Card` has a `size` prop but **no** `footprint` prop; there is **no** `<Grid>`, page-header, or controls-strip component; pages use ad-hoc `max-w-*` containers and `md:grid-cols-2` grids.

## Scope — in / out

**This deliverable builds the PRIMITIVES + tokens only. It does NOT apply them to any page.** Per-page reconciliation (rewriting `now.tsx` etc., moving Records buttons in-card, removing the Reports explainer, the Now hero content) is **Track C — explicitly out of scope here** (kickoff brief + ADR-051 Consequences).

### Files to create or modify (exhaustive)
1. **MODIFY** `src/index.css` — add the four sizing tokens + provisional card-glass tokens (spec below).
2. **MODIFY** `src/components/ui/card.tsx` — add a `footprint` prop and apply the provisional glass surface.
3. **CREATE** `src/components/layout/grid.tsx` — the single grid primitive.
4. **CREATE** `src/components/layout/page-header-card.tsx` — the page-header card primitive.
5. **CREATE** `src/components/layout/controls-strip.tsx` — the controls-strip primitive.
6. **CREATE** colocated unit tests for the three new components and the footprint mapping (`*.test.tsx` next to each, matching repo vitest convention — tests live under `src/`).

### Files NOT to touch
- **Any** `src/routes/*.tsx` (per-page application = Track C).
- `src/components/weather-icon.tsx` (A3-hero owns it).
- Any file importing `lucide-react` (A3-utility owns those).
- `package.json` / lockfile — **A4 adds no dependencies.** If you think you need one, STOP and SendMessage the lead.
- `weewx-clearskies-realtime` or any non-dashboard repo.

## Per-deliverable spec

### D-A4.1 — Tokens (`src/index.css`)
Add to the `@theme` block (so they're available as Tailwind theme values) — exact names/values from ADR-051:
```
--gap-grid: 1rem;
--container-max: 80rem;
--card-half-row: 5.5rem;
--card-row: 11rem;
```
Do **not** add a new radius token — reuse the existing `--radius-xl` (`rounded-xl`, 0.875rem).

Provisional card-glass tokens (B3 gate not done — these are interim, mark with a comment `/* PROVISIONAL — B3 contrast gate sets final value */`). Put the light value in `:root` and dark in `.dark`:
```
/* :root */  --card-glass: 255 255 255 / 0.72;   /* used as background; blur(8px) saturate(1.1) */
/* .dark */  --card-glass: 30 35 55 / 0.55;
```
(Use whatever channel format matches the file's existing color-var convention; the **values** above are locked from the mockup `A4-card-grid.html`.)

### D-A4.2 — `Card` footprint prop (`src/components/ui/card.tsx`)
- Add an optional prop `footprint?: "tile" | "wide" | "panel" | "full"`. Keep the existing `size` prop and all sub-components unchanged.
- Map footprint → responsive column-span classes (columns are **enforced**; the grid is 1→2→4 cols, see D-A4.3):
  | footprint | classes |
  |---|---|
  | `tile` (1 col) | `col-span-1` |
  | `wide` (2 col) | `col-span-1 md:col-span-2` |
  | `panel` (3 col) | `col-span-1 md:col-span-2 lg:col-span-3` |
  | `full` (4 col) | `col-span-1 md:col-span-2 lg:col-span-4` |
- Add an optional `rowSpan?: 1 | 2` that is recorded as a **`data-row-span` attribute only** — it must NOT emit a CSS `row-span` class and must NOT impose a fixed height. **Card height stays content-driven** (ADR-051 "Column rule now vs. later": row-span is documented for the future grid engine; nothing may clip now).
- Apply the provisional glass: card background uses `--card-glass` with `backdrop-filter: blur(8px) saturate(1.1)`. Keep the existing `ring-1 ring-foreground/10` and `rounded-xl`. (A Tailwind arbitrary value or a small CSS class is fine; pick the lighter-touch option and keep it consistent with the file.)
- `footprint` classes must merge correctly with caller `className` (preserve the existing `cn()`/merge pattern).

### D-A4.3 — `Grid` primitive (`src/components/layout/grid.tsx`)
- The **single source** of the grid definition (so the future grid engine can swap it without touching cards — ADR-051 implementation guidance).
- Renders a container that: caps width at `--container-max` and centers (`mx-auto`); applies the responsive grid: **1 column <768px, 2 columns ≥768px (`md`), 4 columns ≥1024px (`lg`)**; gap = `--gap-grid` (1rem) both axes.
- `grid-auto-rows` stays content-driven (`auto`) this session — do **not** set a fixed `--card-half-row` track (that's the future grid engine; a fixed track would clip content).
- Accept `className` + `children`, render as a semantic element appropriate for a layout wrapper (a `<div>` is fine; do not invent ARIA roles).

### D-A4.4 — `PageHeaderCard` (`src/components/layout/page-header-card.tsx`)
- A `full`-footprint card, visually a **half-row** (tighter vertical padding than a data card — mirror the mockup `.card--half` density).
- Props: `title` (string), `info?` (string, one-line), `as?` heading level for the title (default `h1`), and `children` (optional, right-aligned inline controls slot for the "few controls" pattern).
- Title renders as a real heading (`<h1>`…`<h6>`) — A11y: document-order heading, no skipped levels (the consumer decides level; default `h1`). Right-aligned controls sit in a flex row opposite the title.
- This is the primitive only. **On the Now page this card will become the hero (station logo + name) — that content is C1/Track C, NOT built here.**

### D-A4.5 — `ControlsStrip` (`src/components/layout/controls-strip.tsx`)
- A `full`-footprint half-row card for the "many controls" pattern — holds tabs/selectors/buttons passed as `children`.
- Props: `children`, optional `aria-label` for the region, `className`. Renders controls in a flex row (wrap allowed).
- Primitive only; not wired to any page.

## QC gates (ADR-051 acceptance criteria → in-scope this session)
PASS required:
- [ ] Tokens `--gap-grid` (1rem), `--container-max` (80rem), `--card-row` (11rem), `--card-half-row` (5.5rem) exist in the theme; container cap is 80rem.
- [ ] Footprint vocabulary (`tile`/`wide`/`panel`/`full`) defined as a usable `Card` prop mapping to col-span.
- [ ] `Grid` reflows **4→2→1** at ≥1024 / ≥768 / <768px; no card renders narrower than one column.
- [ ] Card height is content-driven — `rowSpan` does not clip (no fixed row-track height shipped).
- [ ] Card surface uses the provisional translucent glass; value is commented PROVISIONAL pending B3.
- [ ] No grid engine / drag-resize / persistence shipped.
- [ ] `PageHeaderCard` and `ControlsStrip` primitives exist and render with correct semantics (heading element; controls inside a card).
- [ ] Build, lint, tests green (command below).

**Deferred to Track C (NOT gated here — do not attempt):** every page rendering within `--container-max`; no control rendering outside a card; no explainer prose on data pages; every page opening with a page-header card; half-row-track zero-orphan packing (needs the fixed-track grid engine).

## Verification command (run before reporting done; lead re-runs independently)
```
cd C:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard
npm run build        # tsc -b && vite build — must exit 0
npm run lint         # eslint . — no new errors
npm run test         # vitest run — all green
```
Report the exact tail of each command.

## Definition of done
- All six files created/modified per spec; 4..6 commits on `main` (one logical change per commit is fine) with clear messages; working tree clean.
- Verification command output pasted to the lead via SendMessage.
- No files outside the scope list touched (lead will diff the commit list against this scope block).

## Resolved decisions (lead calls — follow, do not re-derive)
- Footprint = `Card` prop + single `Grid` primitive (ADR-051 allowed either; lead picked this for swappability).
- Columns enforced now; row-span documented only (heights content-driven).
- Provisional glass values locked from mockup; B3 will finalize — do not tune for aesthetics.
- A4 adds **no** npm dependency.

## Open questions (SendMessage the lead; do NOT resolve unilaterally)
- If any existing global CSS (e.g. a Tailwind `@theme` constraint) makes the `lg:` 4-col breakpoint collide with an existing breakpoint convention, surface it before working around it.
- If the existing color-var format in `index.css` can't cleanly express the glass alpha, propose the format to the lead.

## Agent constraints (MANDATORY — applies to this agent)
- **Scope ack first:** before writing any code, SendMessage the lead a one-paragraph scope acknowledgment (what you'll deliver, what you will NOT touch, the verification command you'll run). No code before the lead confirms.
- **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead/behind or anything is unexpected, STOP and report via SendMessage. Do not resolve it yourself.
- **Branch:** dashboard repo default branch is `main`. Commit there. Do not create branches.
- **Accessibility (load-bearing):** new interactive/semantic elements follow `rules/coding.md` §5 — real heading elements, focus-visible, no `<div onClick>`. Run the §5.7 per-change checklist before reporting done.
- **No scope creep:** routes/, weather-icon.tsx, lucide files, package.json are off-limits. If tempted, STOP and ask.
