# Execution plan — A3 Hero weather icons (ADR-049)

> This brief **references** ADR-049; it does not restate decisions. **ADR-049 wins on any conflict.**
> Read `docs/decisions/ADR-049-hero-weather-icons.md` and the locked render `docs/design/mockups/A3-material-gradient.html` before coding. The mockup's `<defs>` and per-condition SVG path data are the **implementation source of truth**.

## Round identity
- Track A, deliverable A3-hero. Lead: Opus. Implementer: 1 × Sonnet (dashboard).
- Repo: `weewx-clearskies-dashboard` (branch `main`). Date: 2026-05-30.
- **Sequencing:** runs AFTER A4 lands (A4 owns `index.css` + `card.tsx`; no overlap with this file, but serialize to keep one agent in the working tree).

## Pre-round verification (lead did this before writing the brief)
- Current `src/components/weather-icon.tsx` renders the Erik-Flowers **CSS-font** approach: `<i className="wi {wi-class}">` + `<span className="sr-only">` label via `useTranslation('weather')`. `WMO_MAP` has 29 code entries (0,1,2,3,45,48,51,53,55,56,57,61,63,65,66,67,71,73,75,77,80,81,82,85,86,95,96,99) with day/night variants for 0,1,2,80,81,82; fallback `wi-na`.
- This is a **full rewrite** of the icon rendering; the public component API and the WMO code coverage are preserved.

## Scope — in / out

### Files to create or modify (exhaustive)
1. **MODIFY (full rewrite)** `src/components/weather-icon.tsx` — replace CSS-font rendering with inline Material-Symbols SVG using the locked gradient defs; map every WMO code to a glyph.
2. **CREATE (optional, if it keeps the file under ~500 lines)** `src/components/weather-icon-glyphs.tsx` (or a `weather-icon/` folder) holding the 8 SVG glyph builders + shared `<defs>`. Prefer extraction over a mega-file (`rules/coding.md` §3 "No mega-files").
3. **CREATE** colocated unit test `weather-icon.test.tsx` — assert each WMO code maps to a glyph (no `wi-na`/empty render) and that the sr-only label is present.

### Files NOT to touch
- `src/index.css`, `src/components/ui/card.tsx` (A4 owns).
- Any file importing `lucide-react` (A3-utility owns those).
- `package.json` / lockfile — **A3-hero adds NO dependency** (pure inline SVG; do not install Material Symbols or Iconify). If you believe a dep is needed, STOP and SendMessage the lead.
- The `weather-icons` npm dep and its CSS import — **leave them in place.** Removing the now-unused font is a lead-direct cleanup later (it touches `index.css`/`package.json`, owned elsewhere). Do not remove.
- Any `src/routes/*.tsx`, the realtime repo.

## Per-deliverable spec

### Gradient defs (exact — from `A3-material-gradient.html`, vertical top→bottom)
Render these once as shared SVG `<defs>` (give each `<svg>` access — either inline per icon or a single shared defs block; ensure unique IDs survive multiple instances on one page, e.g. SSR-safe by keeping IDs stable and global is acceptable since values are identical):
| id | stop 0% | stop 100% | used by |
|---|---|---|---|
| `goldGrad` | `#FFD24D` | `#F5A623` | sun, rays, lightning bolts |
| `greyGrad` | `#F3F5F8` | `#C7CDD6` | clouds, fog |
| `rainGrad` | `#9CCEF5` | `#5BA3DC` | rain streaks |
| `snowGrad` | `#E8F4FF` | `#B8D8F5` | snow particles |
| `moonGrad` | `#86C3DB` | `#72B9D5` | moon |

### Glyph builders (8 — copy path data verbatim from the mockup; `viewBox="0 0 24 24"`)
`sunny` (gold) · `partlyCloudy` (split: cloud=grey, sun+rays=gold) · `cloud` (grey) · `foggy` (grey) · `rainy` (split: cloud=grey, streaks=rain) · `snowy` (split: cloud=grey, particles=snow) · `thunderstorm` (split: cloud=grey, bolts=gold) · `bedtime` (moon).

**partly-cloudy gotcha (ADR-049 implementation guidance — do exactly this):** the sun body subpath uses a *relative* move that re-anchors to (0,0) if naively split. Anchor it to absolute `M14.975 17.2`, and set `fill-rule="nonzero"` explicitly on **both** split paths. Verify the rendered partly-cloudy shows gold sun + grey cloud with **no off-canvas / "exploded" geometry**.

### Icons are static
No SMIL, no CSS animation, no JS motion. They render fully without movement (ADR-049 acceptance).

### WMO → glyph mapping (lead call — apply exactly)
Day (or night-agnostic):
- `0` → `sunny`
- `1`, `2` → `partlyCloudy`
- `3` → `cloud`
- `45`, `48` → `foggy`
- `51`,`53`,`55`,`56`,`57`,`61`,`63`,`65`,`66`,`67`,`80`,`81`,`82` → `rainy`
- `71`,`73`,`75`,`77`,`85`,`86` → `snowy`
- `95`,`96`,`99` → `thunderstorm`

Night handling (lead call — keep simple & faithful to the locked set, which has only one night glyph):
- `0` at night → `bedtime` (moon).
- **All other codes use the same glyph day or night** — clouds/rain/snow/storm read correctly without a sun/moon, and the locked set has no moon-behind-cloud glyph. (This is a deliberate simplification vs. the old `wi-night-*` variants; richer night glyphs are a possible future follow-up — note it in the commit body, do not build it.)
- No fallback to an empty/`na` state: every code above resolves to a real glyph.

### Public API + a11y (preserve)
- Keep the component's existing props (the WMO `code`, the night flag, `size`, `className`, etc. — match the current signature; do not rename props consumers rely on).
- Keep the screen-reader label: informational icon → `role="img"` with an accessible name from `useTranslation('weather')` (the existing `wmo.*` keys), OR keep the existing `<span className="sr-only">` pattern. Decorative duplicate icons get `aria-hidden`. Follow `rules/coding.md` §5.5 (SVG icons).
- Size prop continues to control rendered px (the mockup default hero size is 96px; respect the caller's size).

## QC gates (ADR-049 acceptance criteria → pass/fail)
- [ ] Every WMO code in `WMO_MAP` (all 29) renders a hero glyph as inline Material-Symbols SVG with the locked gradient treatment (no `wi-na`, no empty render).
- [ ] `partly-cloudy` (codes 1/2) renders **gold sun + grey cloud**, no off-canvas geometry.
- [ ] Icons are **static** (no animation).
- [ ] Gold / grey / rain / snow / moon gradient stops match the locked values above exactly.
- [ ] a11y: informational icons have an accessible name; decorative ones `aria-hidden`; §5.7 checklist run.
- [ ] Build, lint, tests green.

(WCAG legibility over photo backgrounds is shared with the B3 gate — not finalized here; do not tune colors for it.)

## Verification command (run before reporting done; lead re-runs independently)
```
cd C:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard
npm run build
npm run lint
npm run test
```
Report the exact tail of each.

## Definition of done
- `weather-icon.tsx` rewritten (+ optional glyphs file) + test; commits on `main`; working tree clean.
- Verification output sent to lead via SendMessage.
- No out-of-scope files touched.

## Resolved decisions (lead calls — follow, do not re-derive)
- Pure inline SVG, no new dependency.
- WMO→glyph + night mapping above is fixed.
- `weather-icons` dep stays for now (lead removes later).

## Open questions (SendMessage the lead; do NOT resolve unilaterally)
- If the current component's prop signature differs from what consumers pass (grep usages), surface the exact signature before changing it.
- If duplicate gradient IDs across multiple on-page instances cause a rendering/validation issue, propose the de-dup approach (shared defs vs. per-instance) before implementing.

## Agent constraints (MANDATORY — applies to this agent)
- **Scope ack first:** SendMessage the lead a one-paragraph scope acknowledgment before any code. No code before the lead confirms.
- **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead/behind or anything is unexpected, STOP and report via SendMessage.
- **Branch:** dashboard default branch is `main`. Commit there. No new branches.
- **Accessibility (load-bearing):** follow `rules/coding.md` §5.5 for SVG icons; run §5.7 checklist before done.
- **No scope creep:** index.css, card.tsx, lucide files, package.json, routes/ are off-limits.
