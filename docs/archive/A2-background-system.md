# Execution plan — A2 Background system

**Implements:** [ADR-047](../../decisions/ADR-047-background-system.md) (**Accepted 2026-05-30** — gate
cleared, ready to dispatch). This plan references the ADR; it does not restate decisions —
**ADR wins on conflict.** Concrete CSS values, asset map, and asset-prep scripts are in
[background-system-implementation-notes.md](../../design/background-system-implementation-notes.md).

## Round identity
- Decision point: UI-redesign Track **A2**. Lead: Opus (orchestration). Teammates: Sonnet.
- Three agent-sized deliverables: **D1 realtime scene**, **D2 dashboard background layer**,
  **D3 asset prep**. D3 has no code dependency and can run first/parallel; D2 depends on D1's
  `scene` field; the dashboard can mock the field until D1 lands.

## Pre-round verification (lead does this BEFORE writing the per-agent prompts)
1. Confirm exact file paths in each repo (do not trust this brief's guesses — verify and correct):
   realtime conditions/enrichment modules (`weewx_clearskies_realtime/…` — `sky_condition.py`,
   `enrichment/weather_text.py`, the `/current` + SSE serializers), API response model
   (`weewx_clearskies_api/models/responses.py`), dashboard layout + theme/almanac code
   (`src/lib/theme-provider.tsx`, the app shell where a global background layer mounts).
2. **Verify the provider current-conditions feed actually populates** `precipType` and the
   thunderstorm conditions text at runtime on weather-dev — not just that the fields exist in the
   model. If they are not populated, STOP and surface to the lead/user (storm+snow have no trigger
   otherwise). This is ADR-047's first acceptance risk.
3. `git status` + `git log --oneline -1` clean on each target repo.

## Scope — in / out

**D1 — Realtime scene builder + precip linger (realtime repo only)**
- IN: a scene module that computes `scene.sky ∈ {clear,cloudy,storm}` and `scene.overlay ∈
  {rain,snow,null}` per ADR-047 §2–§4; the **15-minute precip-linger timer** (server state, last-
  detection timestamp, survives reloads); wire `scene` onto the `/current` payload **and** the SSE
  stream.
- OUT: do NOT touch the dashboard, do NOT add unit tests outside the realtime test tree
  (test-author owns nested locations), do NOT change the existing `weatherText` composition.

**D2 — Dashboard global background layer (dashboard repo only)**
- IN: a static global background layer behind the app content (blurred base + `screen`-blended
  on-glass overlay + bottom scrim) per the implementation-notes recipe; an asset map (scene tag →
  image + optional attribution); the corner attribution element; consume `scene` from the live
  data hook; derive day/night.
- OUT: no animation; do NOT modify the theme-provider's light/dark logic; do NOT touch card
  components beyond mounting the background behind them; do NOT invent new colors (A1 owns tokens).

**D3 — Asset prep (assets only; no app code)**
- IN: downscale + compress all 6 scene photos + 2 overlays to the documented per-image budget
  (~2400px longest edge; WebP/AVIF for scenes, PNG only where alpha needed); place in the dashboard's
  asset pipeline. Reuse `scripts/asset-prep/` where helpful.
- OUT: do NOT alter the source files in `Graphics/Backgrounds/`; output to the dashboard asset dir.

## Per-deliverable spec
- **Mapping (D1):** exactly the ADR-047 §2 table — all 5 sky labels + Foggy→cloudy + none/unknown→
  clear; storm from provider thunderstorm text; snow from provider `precipType ∈
  {snow,sleet,freezing-rain}`; snow wins over rain.
- **Linger (D1):** overlay set on detection; cleared 15 min after the **last** detection; verifiable
  at 14:59 (present) and 15:01 (absent); state lives server-side.
- **Background select (D2):** `sky × daytime → file`; `overlay → file|none`; opacity 0.75 day /
  0.25 night; 3px base blur only when overlay active; attribution shown only when the chosen asset
  has a credit string.
- **Day/night (D2):** real sun position from the almanac the dashboard already fetches — NOT the
  theme toggle.

## QC gates (ADR-047 acceptance criteria → pass/fail)
- Mapping covers every sky label + Foggy + none/unknown; no blank background. (unit test, D1)
- `precipType`/thunderstorm populated at runtime; storm+snow scenes actually fire. (integration, D1)
- Linger boundary test 14:59 present / 15:01 absent; persists across a simulated reload. (D1)
- `scene` present on `/current` + SSE; dashboard selects assets without parsing conditions text. (D1+D2)
- Visual params match locked values (3px / `screen` / 0.75|0.25). (D2 visual + code review)
- **WCAG AA text contrast over every background, both themes**, axe-core + manual; scrim added where
  needed. (D2, ADR-026 / B3 gate)
- Each shipped asset ≤ the documented weight budget. (D3)
- `tsc` + `npm run build` clean; realtime + dashboard test suites green (no regressions vs baseline).

## Definition of done
- Lead sees: realtime commits adding the scene builder + linger + `scene` serialization with passing
  realtime tests; dashboard commits adding the background layer + asset map + attribution with clean
  tsc/build and AA results; D3 commits with compressed assets under budget. Verification commands +
  pass counts recorded in the round scratchpad before any plan-status-close.

## Resolved decisions (settled by user 2026-05-30 — were open questions)
1. **`daytime` is server-side.** The server emits `scene = {sky, daytime, overlay}`. `daytime` is
   computed server-side from **almanac sunrise/sunset** (consistent with the theme's day/night, per
   ADR-047 §5), not the `maxSolarRad` proxy. The dashboard reads it; it does not recompute it for the
   background. (D1 owns this; realtime sources sun times from the almanac.)
2. **No attribution for the two on-glass photos.** Glass overlays carry no credit. The attribution
   element still renders credits for the 5 scene photos (which do credit photographers).
3. **Per-image weight budget = ≤ 300 KB** each, resized to ~2560px longest edge, **WebP** (keeps
   alpha for the frost overlay). Worst-case per view ≈ 600 KB (one background + one overlay). (D3)

## Open questions
None outstanding. Surface anything new to the lead via SendMessage; do not resolve unilaterally.

## Agent constraints (MANDATORY in every D1/D2/D3 agent prompt)
> **Git restrictions:** You must NOT run `git pull`, `git push`, `git fetch`, `git rebase`,
> `git merge`, or `git checkout` of remote branches. You may only `git add`, `git commit`,
> `git status`, `git log`, `git diff`. If the remote is ahead/behind, STOP and report via
> SendMessage. Do not resolve it yourself.

Every agent must SendMessage a one-paragraph **scope acknowledgment** (what it will deliver, what it
will NOT touch, the exact verification command it will run) and get lead confirmation **before
writing any code**.
