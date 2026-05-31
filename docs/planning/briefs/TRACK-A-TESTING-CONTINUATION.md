# Track A — on-device testing continuation prompt

**Paste the block below into a fresh session to continue.** Track A code is built, QC'd,
committed, pushed, and deployed to `weather-dev`. This next session is **visual + accessibility
+ keyboard testing on the live device**, plus three small deferred cleanups.

---

## What landed (already on `origin` + deployed to weather-dev as of 2026-05-31)

All five Track A code deliverables are ACCEPTED (build + unit tests green, lead-verified, scope-clean):

| Deliverable | ADR | Repo / commits |
|---|---|---|
| A4 card footprint primitives (tokens, `Card.footprint`, `Grid`, `PageHeaderCard`, `ControlsStrip`) | 051 | dashboard `main`: `1e6c7db d632bba 3fd072a cbdb24d 82e67e6` |
| A3 hero weather icons (inline Material-Symbols SVG, 5 gradient defs, all 29 WMO codes) | 049 | dashboard `main`: `0140e2f` |
| A3 utility/nav/alert icons (Phosphor 2.1.10 + 3 inline cross-pack glyphs + 13-type alert map) | 050 | dashboard `main`: `8143377 90ed053` |
| A2 dashboard background layer + compressed assets (8 WebP ≤300 KB) | 047 | dashboard `main`: `4e8c896 846fc6c` |
| A2 realtime scene builder + precip linger | 047 | realtime `main`: `c2d7f57` |

Meta repo `master` `a1b2c3d`: 3 execution briefs in `docs/planning/briefs/` (A3-hero, A3-utility, A4).

**Deploy verified on weather-dev:** dashboard HTTP 200; realtime `/current` emits
`scene={sky,daytime,overlay,scene_tag}` live; 8/8 background assets in `/var/www/clearskies/assets/`.

**NOT yet done (this is your job):** visual confirmation, automated accessibility scan on the
hydrated SPA, keyboard-only walkthrough, color-blindness pass. Plus 3 small deferred cleanups below.

---

## PASTE THIS INTO THE NEW SESSION

```
Track A (Clear Skies UI redesign) is built, pushed, and deployed to weather-dev. I need you to
run the on-device TESTING + accessibility pass that the build session deferred, then handle 3 small
cleanups. You are the Opus lead — delegate reading/grep/SSH/browser-driving to Sonnet; you synthesize
and decide. Follow rules/clearskies-process.md + rules/coding.md (esp. §5 accessibility — load-bearing).

Read first:
- docs/planning/briefs/TRACK-A-TESTING-CONTINUATION.md  (full context; what landed where)
- docs/planning/briefs/TRACK-A-IMPLEMENTATION-KICKOFF.md (the original session's definition of done)
- ADR-047/049/050/051 acceptance criteria (the visual/a11y bars to check against)

Runtime: weather-dev LXD container, Caddy :80. Reach it via `ssh ratbert "lxc exec weather-dev -- ..."`.
Dashboard already deployed at http://localhost/ inside the container; realtime API at /api/v1/*.
If you change code: commit locally, then push (authorized) and redeploy via
scripts/redeploy-weather-dev.sh (it pulls from GitHub, npm ci --legacy-peer-deps, build, rsync dist).
Git: meta repo = master; all weewx-clearskies-* repos = main. Implementer agents never push; lead does.

TESTING TASKS (the primary ask):
1. Visual check against the locked mockups, BOTH light + dark themes:
   - A4: cards render as translucent glass over the A2 background; Grid reflows 4→2→1 at
     ≥1024/≥768/<768px; nothing clips. (Primitives are built but NOT yet applied to pages — that's
     Track C — so verify them via a scratch render or Storybook-style harness if needed, OR confirm
     they at least don't regress current pages.)
   - A3 hero icons: every weather condition shows the gradient Material-Symbols glyph; partly-cloudy
     = gold sun + grey cloud, no exploded geometry; icons static.
   - A3 utility/alerts: stat/nav glyphs are Phosphor; trigger/inspect the alert banner for the 13
     alert types (flood + tsunami cross-pack render correctly); feels-like/dew-point have NO icon.
   - A2 background: scene photo shows, day/night switches with scene.daytime, rain/snow overlay
     appears, attribution corner readable, text stays legible over every background.
2. Automated accessibility: run @axe-core/playwright against the HYDRATED SPA (the dashboard repo
   already has it as a devDependency — use it, not @axe-core/cli against static HTML, which only sees
   the pre-React shell and gives 3 false positives: landmark-one-main, page-has-heading-one, region).
   Target zero violations; document any exceptions. Check BOTH themes.
3. Keyboard-only walkthrough: tab through the app, confirm visible focus on every control, Escape
   closes menus, no mouse-only widgets.
4. Color-blindness simulation pass (Chrome DevTools vision-deficiency emulation): confirm no state is
   conveyed by color alone (the alert banner pairs icon + text — verify).
5. Card-glass contrast over photos: this is the B3 gate the build session left PROVISIONAL
   (--card-glass: light rgba(255,255,255,0.72), dark rgba(30,35,55,0.55)). Measure real contrast of
   card text over each of the 6 scene backgrounds, both themes, with a real tool. If any combo fails
   WCAG AA, that sets the final opacity — surface the measured numbers to me before changing the token.

DEFERRED CLEANUPS (small; do after testing or in parallel via a Sonnet agent):
A. [DONE this session — commit 2f1e8a4] Dead `weather-icons` dependency removed (index.css @import,
   package.json dep, weather-icon.tsx stale comment); 14 transitive packages dropped; build + 282 tests
   green; redeployed. No action needed.
B. Close the OpenAPI contract gap: `scene` is emitted by realtime but is NOT in the dashboard's
   src/api/openapi-v1.yaml, so SceneDescriptor is hand-maintained in src/api/types.ts and can drift.
   Add `scene` to the contract and regenerate types (npm run generate:types), reconcile.
C. (Optional simplification) The dashboard re-derives the scene asset key client-side from
   sky+daytime+overlay even though realtime already emits a composed `scene_tag`. Consider consuming
   scene_tag directly to remove the duplicated composition logic.

SOURCE-ART NOTE (no longer a blocker): the two untracked files
(Graphics/Backgrounds/snow_on_glass_cutout.png 8.5MB, snow_on_glass_flat.jpg 3.4MB) are NOT used by
anything — the snow overlay asset is built from snow_on_glass_transparent.png (already tracked). They
are unused alternate source art and are not required for build or runtime. Tracking them is purely an
archival preference for the user; the prior session left them untracked (matching their state at
session start). Correction precedent vs the earlier claim: there ARE 8 tracked source images in that
dir, so "zero precedent for tracking source art" was wrong — but there is no Git LFS, so committing
12MB of binaries is a user call, not a default.

Out of scope (Track C, do NOT do here): applying the A4 primitives to actual pages, reconciling
per-page card discipline, the Now-page hero content (C1), chart/AQI palette gaps, the wind icons (C2),
astro/AQI/seismic icons (C5/C6/seismic — deliberately left on Lucide and flagged).

Start by pre-flighting all repos (git status + log on dashboard/realtime/meta), then propose your
test plan before driving the browser.
```

---

## Notes for whoever runs the continuation

- The build session's live scratchpad is at `c:\tmp\track-a-impl-scratch.md` — full verification
  evidence per deliverable, the false-alarm investigation (a stale autocrlf stat flag + tool-output
  corruption that looked like a scene.py bug but wasn't — scene.py is byte-identical to the committed,
  tested version), and the parking lot.
- Pre-existing dashboard lint debt: 13 errors (mostly `Date.now()` in `useState` initializers in
  `now.tsx`, plus a few react-refresh warnings) predate Track A and were left untouched. Not Track A's
  to fix, but tracked here so they're not mistaken for new breakage.
- `npm install` in the dashboard requires `--legacy-peer-deps` (pre-existing typescript vs
  openapi-typescript peer conflict; matches the deploy script).
