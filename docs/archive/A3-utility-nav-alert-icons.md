# Execution plan — A3 Utility / stat / nav / alert icons (ADR-050)

> This brief **references** ADR-050; it does not restate decisions. **ADR-050 wins on any conflict.**
> Read `docs/decisions/ADR-050-utility-stat-nav-icons.md` and the locked worksheet `docs/design/mockups/A3-final-icons.html` before coding.

## Round identity
- Track A, deliverable A3-utility. Lead: Opus. Implementer: 1 × Sonnet (dashboard).
- Repo: `weewx-clearskies-dashboard` (branch `main`). Date: 2026-05-30.
- **Sequencing:** runs AFTER A3-hero. This deliverable owns `package.json` changes for icons.

## Pre-round verification (lead did this before writing the brief)
- `@phosphor-icons/react` and Iconify are **NOT** installed. `lucide-react ^1.16.0` and `weather-icons ^1.3.2` ARE.
- Lucide usage surface (8 files, recon-confirmed):
  - `src/components/precipitation-barometer-card.tsx`: `CloudRain`, `Gauge`
  - `src/components/layout/theme-toggle.tsx`: `Monitor`, `Sun`, `Moon`
  - `src/components/solar-uv-card.tsx`: `Sun`
  - `src/routes/now.tsx`: `Sunrise`, `Sunset`, `Moon`, `Zap`, `Activity`
  - `src/components/layout/nav-rail.tsx`: `House`, `CloudSunRain`, `ChartLine`, `Moon`, `Activity`, `Trophy`, `FileText`, `Info`, `Scale`, `Ellipsis`
  - `src/routes/reports.tsx`: `Download`
  - `src/components/shared/alert-banner.tsx`: `TriangleAlert` (single generic icon for ALL alert types — no per-type map exists)
  - `src/components/shared/radar-map.tsx`: `Play`, `Pause`, `ChevronLeft`, `ChevronRight`
- `now.tsx` IS in scope for THIS brief (icon swaps only — NOT layout; layout is Track C). This is the one place A3-utility legitimately edits a route file, and only to swap icon imports/usages.

## Scope — in / out

### Files to create or modify (exhaustive)
1. **MODIFY** `package.json` + lockfile — add `@phosphor-icons/react` (pin an exact version; commit the lockfile).
2. **CREATE** `src/components/icons/` — three inline-SVG React components for the cross-pack glyphs (path data fetched from the named icon sources; `role`/`aria` per usage): `uv-index.tsx` (`tabler:uv-index`), `flood.tsx` (`material-symbols:flood-outline-rounded`), `tsunami.tsx` (`carbon:tsunami`; if it looks off against Phosphor weight, use the pre-vetted `mdi:tsunami` — your call, note which).
3. **CREATE** `src/components/icons/alert-icon-map.ts(x)` — the 13-type alert-icon map (alert event/type → icon component) per ADR-050.
4. **MODIFY** `src/components/shared/alert-banner.tsx` — use the 13-type map instead of the single `TriangleAlert`.
5. **MODIFY** the 7 other Lucide files above — replace migratable icons with Phosphor / cross-pack equivalents per the mapping table.
6. **CREATE** colocated tests: alert-map coverage (all 13 types resolve to an icon), and a render smoke test for the 3 cross-pack components.

### Files NOT to touch
- `src/index.css`, `src/components/ui/card.tsx` (A4 owns).
- `src/components/weather-icon.tsx` (A3-hero owns).
- Any `src/routes/*.tsx` **except `now.tsx`**, and in `now.tsx` **only icon imports/usages** — do NOT touch its layout/grid/JSX structure.
- `weewx-clearskies-realtime` or any non-dashboard repo.
- **Do NOT remove `lucide-react`** — deferred-family icons stay on it (see lead call below). Do NOT remove `weather-icons` (lead-direct cleanup later).

## Per-deliverable spec

### Rendering mechanism (lead call — locked)
`@phosphor-icons/react` (regular weight, the demure line weight) for the base set + **inline SVG** for the 3 cross-pack glyphs. **Do NOT add Iconify or per-pack npm packages** (`@tabler/icons-react`, etc.). The mockups used Iconify only as a preview.

### Lucide → Phosphor migration map (apply exactly)
Phosphor React components are PascalCase, regular weight (default import from `@phosphor-icons/react`).

**Stats / data (migrate):**
| Lucide | → | Phosphor / cross-pack | ADR-050 name |
|---|---|---|---|
| `CloudRain` | → | `CloudRain` | `ph:cloud-rain` (rainfall) |
| `Gauge` | → | `Gauge` | `ph:gauge` (pressure) |
| `Sun` (solar-uv-card, solar) | → | `Sun` | `ph:sun` (solar) |
| `Zap` (now, lightning) | → | `Lightning` | `ph:lightning` |

**UV index:** if `solar-uv-card.tsx` renders a UV glyph, use the cross-pack `UvIndex` inline component (`tabler:uv-index`). If UV is currently text-only, leave it text-only (do not add an icon).

**Trend arrows (use the single reusable set wherever a metric trend renders — e.g. barometer trend):** rising `ArrowUp` (`ph:arrow-up`), falling `ArrowDown` (`ph:arrow-down`), steady `ArrowRight` (`ph:arrow-right`). Search for existing trend rendering (barometer trend direction) and route it through this set.

**Text-only — NO icon (ADR-050):** feels-like, dew-point render with no icon. Wind speed/direction/gust have no utility icon (C2 owns them) — do not add one.

**Nav / chrome (migrate):**
| Lucide | → | Phosphor | ADR-050 name / note |
|---|---|---|---|
| `Monitor` (theme: system) | → | `Desktop` | not enumerated; system-theme option, nearest Phosphor — flag |
| `Sun` (theme: light) | → | `Sun` | `ph:sun` theme-light |
| `Moon` (theme-toggle: dark) | → | `Moon` | `ph:moon` theme-dark |
| `House` | → | `House` | `ph:house` |
| `ChartLine` | → | `ChartLine` | charts nav |
| `Trophy` | → | `Trophy` | `ph:trophy` records |
| `FileText` | → | `FileText` | reports nav |
| `Info` | → | `Info` | about nav |
| `Scale` | → | `Scales` | legal nav |
| `Ellipsis` | → | `DotsThree` | "more" menu |
| `CloudSunRain` (nav: weather/Now page) | → | `CloudSun` | not enumerated; nearest — flag |
| `Download` (reports) | → | `DownloadSimple` | not enumerated; nearest — flag |
| `Play` | → | `Play` | radar control |
| `Pause` | → | `Pause` | radar control |
| `ChevronLeft` | → | `CaretLeft` | `ph:caret-left` |
| `ChevronRight` | → | `CaretRight` | `ph:caret-right` |

**DEFERRED families — DO NOT migrate; leave on Lucide, add a `// TODO(ADR-050 deferred: <family>)` comment:**
| Lucide | context | deferred to |
|---|---|---|
| `Sunrise`, `Sunset` (now.tsx, Sun & Moon) | astro/almanac | **C5** |
| `Moon` (now.tsx astro context, AND nav-rail almanac-page nav) | astro/almanac | **C5** — but the **theme-toggle** `Moon` IS migrated (it's chrome, not astro). Judge by context: theme/chrome Moon → Phosphor; astro/almanac Moon → leave Lucide. |
| `Activity` (now.tsx earthquake + nav-rail seismic nav) | earthquake/seismic glyph (operator rejected this look; real glyph TBD) | **seismic ADR** |
| any AQI icon | air-quality | **C6** |

Because deferred icons remain, **`lucide-react` stays a dependency this session.** Do not remove it. (Tracked: lucide removal happens when C5/C6/seismic land.)

### 13-type alert-icon map (ADR-050 Decision — apply exactly)
Map each alert type → icon. Phosphor unless noted cross-pack:
fire `Fire` · tropical/hurricane `Hurricane` (ALL tropical) · thunderstorm `Lightning` · tornado `Tornado` · generic warning `Warning` · generic watch `WarningCircle` · wind `Wind` · marine `Sailboat` · snow/winter `Snowflake` · heat & cold `Thermometer` · fog `CloudFog` · **flood** → inline `Flood` (`material-symbols:flood-outline-rounded`) · **tsunami** → inline `Tsunami` (`carbon:tsunami`/`mdi:tsunami`).
- Reuse, don't duplicate: `Snowflake` serves snowfall stat AND snow/winter alert; `Thermometer` serves temperature stat AND heat/cold alert (ADR-050 implementation guidance).
- The map must have a **sensible default** for unmatched alert types — default to generic warning `Warning` (so `alert-banner.tsx` never renders no icon). Keep the banner's existing severity→ARIA-role logic.
- **Color is not the only signal:** the alert pill keeps its text/label alongside the icon (`rules/coding.md` §5.1).
- a11y: alert icons are informational → accessible name = the alert type/event; follow §5.5.

### Stat icon coverage (ADR-050 — apply where the stat renders with an icon)
temperature `Thermometer` · humidity `DropSimple` (single drop — distinct from precip) · precip-chance `Umbrella` · visibility `Eye` · solar `Sun` · rainfall `CloudRain` · snowfall `Snowflake` · pressure `Gauge` · UV `UvIndex` (cross-pack). Humidity and precip-chance MUST stay visually distinct (a drop never means two things).

## QC gates (ADR-050 acceptance criteria → pass/fail)
- [ ] Every migrated stat renders its named Phosphor glyph at regular weight; UV uses the `tabler:uv-index` inline component; matches `A3-final-icons.html`.
- [ ] Trend indicators use the single reusable set (`ArrowUp`/`ArrowDown`/`ArrowRight`).
- [ ] All 13 alert types map to their glyph; flood + tsunami render correctly as inline cross-pack SVG; unmatched → generic warning.
- [ ] Feels-like and dew-point render with NO icon; no utility wind icon exists.
- [ ] No astro / AQI / earthquake glyph shipped under this ADR (those stay on Lucide, flagged).
- [ ] `@phosphor-icons/react` pinned in package.json; lockfile committed.
- [ ] a11y §5.7 checklist run (icon-only buttons keep `aria-label`; informational icons named; decorative `aria-hidden`).
- [ ] Build, lint, tests green.

## Verification command (run before reporting done; lead re-runs independently)
```
cd C:\CODE\weather-belchertown\repos\weewx-clearskies-dashboard
npm install          # only if needed to resolve the new dep locally; use the project's install convention
npm run build
npm run lint
npm run test
```
Report the exact tail of each, plus the pinned `@phosphor-icons/react` version.

## Definition of done
- New dep pinned + lockfile committed; cross-pack inline components + alert map created; 8 files migrated (deferred icons left + flagged); tests added; commits on `main`; working tree clean.
- A short list of the icons you mapped to a **non-enumerated** nearest match (Desktop, CloudSun, DownloadSimple, DotsThree, Scales) sent to the lead for sign-off.
- Verification output sent to lead via SendMessage.

## Resolved decisions (lead calls — follow, do not re-derive)
- Render = `@phosphor-icons/react` + inline SVG for the 3 cross-pack glyphs. No Iconify.
- Deferred families stay on Lucide; `lucide-react` is NOT removed.
- `now.tsx` edited for icon swaps ONLY — no layout changes.
- tsunami glyph: `carbon:tsunami`, fallback `mdi:tsunami` allowed — note which you used.

## Open questions (SendMessage the lead; do NOT resolve unilaterally)
- The exact alert-type taxonomy the app uses (what string/field `alert-banner.tsx` switches on): confirm the set of event types before finalizing the 13-key map keys, so keys match real data (`alert.event` values). Surface the real field/values to the lead.
- If `@phosphor-icons/react` regular-weight import names differ from the table (e.g. `Scales` vs `Scale`), report the real export names before substituting.

## Agent constraints (MANDATORY — applies to this agent)
- **Scope ack first:** SendMessage the lead a one-paragraph scope acknowledgment before any code. No code before the lead confirms.
- **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`, `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`, `git status`, `git log`, `git diff`. If the remote is ahead/behind or anything is unexpected, STOP and report via SendMessage.
- **Branch:** dashboard default branch is `main`. Commit there. No new branches.
- **Dependency hygiene:** pin the exact version (`rules/coding.md` §1 "Pin dependency versions"); commit the lockfile; use `npm ci`-compatible install.
- **Accessibility (load-bearing):** §5.5 for SVG/icon-only buttons; run §5.7 checklist before done.
- **No scope creep:** index.css, card.tsx, weather-icon.tsx, all routes except now.tsx (icons only), realtime repo are off-limits.
