# WEATHER-EVALUATION-PLAN — Belchertown Skin Assessment & Alternatives

**Project Goal:** Evaluate the current Belchertown skin for weather.shaneburkhardt.com and determine whether to update/modify it to better meet needs, or migrate to an entirely different skin.

**Status:** Phase 1 — assessment complete (2026-04-29) | Next: Phase 1.5 — capture server drift | Target: TBD

---

## User-stated problems

1. **Site is too busy** — looks like an early-2000s design. Layout/info-density needs a redesign.
2. **MQTT pass-through is broken** — regular users (no LAN/MQTT-broker access) don't see live data on the website.
3. **Custom chart-sampling dropdown** was added to the live site at some point. May not be in git.
4. **Unknown what lives on which container** — server vs repo divergence.
5. **Open question:** is Belchertown still the right skin, or evaluate alternatives?

---

## Phase 1 findings (assessment, completed 2026-04-29)

See [docs/reference/SERVER-INVENTORY.md](../reference/SERVER-INVENTORY.md) and [docs/reference/REPO-VS-SERVER-DIFF-2026-04-29.md](../reference/REPO-VS-SERVER-DIFF-2026-04-29.md) for full detail.

### Architecture (as actually deployed)

- **WeeWX 5.3.1** runs on `weewx` LXD container (`192.168.2.121`).
- Skin source lives at `/etc/weewx/skins/Belchertown/` (not `/home/weewx/skins/...` as the old reference doc said).
- Static HTML is generated at weewx:`/var/www/weewx/`, which is **the same filesystem** as cloud:`/var/www/weewx/` via an LXD shared disk (`/mnt/weewx` on Ratbert host). No rsync, no cron, no deploy step — files appear on cloud instantly.
- TLS termination is on **Apache (cloud:443)**, not nginx-proxy-manager. Apache vhost `/etc/apache2/sites-enabled/weather-ssl.conf`.
- MQTT broker is **EMQX** on cloud (Erlang `beam.smp`, ports 1883/8083/18083).
- The Apache vhost already proxies `wss://weather.../mqtt` → `ws://localhost:8083/mqtt` correctly.

### MQTT problem — root cause identified

`/etc/weewx/weewx.conf` `[StdRESTful][[MQTT]]` line reads:
```
server_url = mgtt://weewx:<REDACTED>@cloud.shaneburkhardt.com:1883
```
**`mgtt://` is a typo for `mqtt://`.** The matthewwall weewx-mqtt extension cannot parse the bad scheme, so weewx is publishing nothing to EMQX. The wss subscriber chain is fine; there's just no data flowing in. **One-character fix.**

### Server-vs-repo divergence

The server is running mostly the `dropdowns` branch's customizations BUT has further uncommitted modifications. Seven critical files differ from every branch in the repo and exist nowhere in git:

1. `skins/Belchertown/graphs.conf` ← chart definitions (drives the dropdown work)
2. `skins/Belchertown/js/belchertown.js.tmpl` ← frontend JS, including dropdown logic
3. `skins/Belchertown/style.css` ← custom CSS
4. `skins/Belchertown/skin.conf` ← skin-level config
5. `skins/Belchertown/about.inc`
6. `skins/Belchertown/reports/index.html.tmpl`
7. `skins/Belchertown/lang/de.conf`

Plus the Python backend `bin/user/belchertown.py` has a `.bak` on the server (proof of hand-edits) — a 3-way diff vs `master`/`dropdowns`/`inguy24-changes` is needed.

The `inguy24-changes` branch is broken (web-UI uploads to wrong paths). Treat as a snapshot only; **do not merge**.

### Stale things on the server (informational)

- `/var/www/weather/` and `/var/www/bak1/` on cloud are unused legacy paths.
- `/etc/weewx/bin/user/belchertown.py.bak` is older content that the live `belchertown.py` no longer has.

---

## Phase 1: Current State Assessment

Understand what the Belchertown skin currently offers, identify gaps, and document baseline behavior.

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Document current Belchertown version & config | claude | ✅ Done | weewx 5.3.1; skin at `/etc/weewx/skins/Belchertown/`; `/etc/weewx/weewx.conf` audited |
| Map server vs repo file-by-file | claude | ✅ Done | [REPO-VS-SERVER-DIFF-2026-04-29.md](../reference/REPO-VS-SERVER-DIFF-2026-04-29.md) |
| Document hosting architecture | claude | ✅ Done | [SERVER-INVENTORY.md](../reference/SERVER-INVENTORY.md) |
| Identify root cause of MQTT issue | claude | ✅ Done | `mgtt://` typo in weewx.conf |
| Pull WeeWX 5.3 docs locally | claude | ✅ Done | [docs/reference/weewx-5.3/](../reference/weewx-5.3/) (98 md files) |
| Test on mobile & desktop | — | ⬜ Not Started | Defer to Phase 2 (post-capture) |
| Document UI/UX limitations vs busy-design problem | — | ⬜ Not Started | Defer to Phase 2 |
| Gather user feedback on must-keep features | — | ⬜ Not Started | Needed before alternative-skin evaluation |

## Phase 1.5: Capture server drift into git (PROPOSED NEXT)

**Goal:** before evaluating alternative skins or making any UI changes, get the server's current state into the repo so we have a recoverable, diff-able baseline. **No code changes to the server during this phase.**

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Create branch `feature/capture-server-drift-2026-04-29` from `dropdowns` | — | ⬜ Not Started | Branch from dropdowns since that's closest to server |
| Copy 7 drifted files from server into branch | — | ⬜ Not Started | `graphs.conf`, `js/belchertown.js.tmpl`, `style.css`, `skin.conf`, `about.inc`, `reports/index.html.tmpl`, `lang/de.conf` |
| Copy `bin/user/belchertown.py` and `belchertown.py.bak` (renamed) into branch | — | ⬜ Not Started | Diff each against master/dropdowns to understand changes |
| Redact any embedded creds in `skin.conf` before commit | — | ⬜ Not Started | Externalize API keys to weewx.conf if present |
| Per-file commit with message describing the diff | — | ⬜ Not Started | One logical change per commit |
| Open PR for review | — | ⬜ Not Started | Title: "Capture server-side drift not previously committed" |
| Decide: are uncommitted changes worth keeping, or should we revert to a known branch? | — | ⬜ Not Started | This is the design decision after we can SEE the diffs |

### Quick fix: MQTT typo

Separately from the capture work, the MQTT pass-through can be unblocked with a one-character edit:

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| Fix `mgtt://` → `mqtt://` in weewx.conf | — | ⬜ Not Started | One-line edit on weewx container; restart weewx; verify wss browser subscribers receive packets |
| Verify EMQX has user `weewx` with that password | — | ⬜ Not Started | Check EMQX dashboard at `http://cloud:18083` |
| Verify EMQX has user `weewx-web` with that password | — | ⬜ Not Started | This is the browser subscriber |
| Confirm topic routing (publisher `weewx` → subscriber `weewx/loop`) | — | ⬜ Not Started | weewx-mqtt appends `/loop` for loop packets — verify against extension code |

This fix is low-risk and addresses one of the user's two main complaints. Recommend doing it BEFORE Phase 1.5 capture so we can also test the live data flow once the customizations are properly tracked.

---

## Phase 2: Alternative Skin Evaluation

Survey candidate skins and benchmark them against evaluation criteria.

### Evaluation Criteria

Each skin will be assessed on:

- **Data Display**
  - [ ] Current conditions (temp, humidity, wind, pressure)
  - [ ] Historical trends (charts for 24h, 7d, 30d)
  - [ ] Forecast display (if integrated)
  - [ ] Alerts / warnings (if supported)

- **Customization**
  - [ ] Colors & branding (without patching source)
  - [ ] Layout flexibility (sidebar, full-width, mobile variants)
  - [ ] Text labels & localization
  - [ ] Icon/image replacement

- **Performance**
  - [ ] Page load time (< 3s on LAN)
  - [ ] Resource consumption (HTML/CSS/JS size)
  - [ ] Weewx publish interval compatibility
  - [ ] Mobile data usage

- **Responsiveness**
  - [ ] Mobile phone (320px - 480px)
  - [ ] Tablet (768px - 1024px)
  - [ ] Desktop (1200px+)
  - [ ] Orientation changes (portrait ↔ landscape)

- **Maintenance**
  - [ ] Upstream activity (commits in last 12 months?)
  - [ ] Community size & support
  - [ ] Dependencies (weewx version, plugins, external APIs)
  - [ ] Update frequency & breaking changes

- **Integration**
  - [ ] Weewx data access (database, API, files)
  - [ ] Third-party APIs (radar, forecast, alerts)
  - [ ] Caching / CDN compatibility
  - [ ] SEO & social meta tags

### Candidate Skins

| Skin | Repo | Phase 2 Task | Status | Notes |
|------|------|-------------|--------|-------|
| **Seasons** | https://github.com/weewx/weewx-seasons | [ ] Evaluate Seasons | ⬜ Not Started | Official weewx project, simpler than Belchertown |
| **Beautiful Dashboard** | https://github.com/weewx-user/weewx-beautiful-dashboard | [ ] Evaluate Beautiful Dashboard | ⬜ Not Started | Modern, responsive, responsive, actively maintained |
| **Responsive** | https://github.com/weewx/weewx-responsive | [ ] Evaluate Responsive | ⬜ Not Started | Lightweight, older |
| **Saratoga** | https://github.com/ktownsend-personal/Saratoga-Weather | [ ] Evaluate Saratoga | ⬜ Not Started | Feature-rich, complex, PHP-based |

**For each skin:**
1. Clone to local test path
2. Stand up a test instance (or configure for current weewx data)
3. Score against evaluation criteria
4. Screenshot key pages
5. Document findings in `docs/reference/SKIN-EVALUATION-<name>.md`

## Phase 3: Decision & Recommendation

Consolidate findings and recommend path forward.

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| [ ] Compare evaluation results | — | ⬜ Not Started | Scoring matrix |
| [ ] Weight priorities (what matters most?) | — | ⬜ Not Started | Gather user input on criteria importance |
| [ ] Draft recommendation (update Belchertown vs. migrate) | — | ⬜ Not Started | Pros/cons of each path |
| [ ] Present to user for decision | — | ⬜ Not Started | — |

## Phase 4: Implementation (conditional on recommendation)

**Only execute if skin migration or major updates are approved.**

### Path A: Update Belchertown

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| [ ] Create feature branch | — | ⬜ Not Started | `feature/belchertown-improvements` |
| [ ] Implement requested customizations | — | ⬜ Not Started | Per user requirements |
| [ ] Test on staging | — | ⬜ Not Started | Dev path on cloud container |
| [ ] Create PR with changes | — | ⬜ Not Started | Document what changed & why |
| [ ] Deploy to production | — | ⬜ Not Started | Backup old skin, promote, monitor |

### Path B: Migrate to New Skin

| Task | Owner | Status | Notes |
|------|-------|--------|-------|
| [ ] Clone new skin repo to weewx container | — | ⬜ Not Started | `/home/weewx/skins/<SkinName>` |
| [ ] Migrate weewx config for new skin | — | ⬜ Not Started | Convert Belchertown settings → new skin settings |
| [ ] Test with live data | — | ⬜ Not Started | Generate output, verify all data flows |
| [ ] Customize branding & layout | — | ⬜ Not Started | Per user preferences |
| [ ] Create PR documenting migration | — | ⬜ Not Started | Explain why, what changed, rollback plan |
| [ ] Schedule promotion to production | — | ⬜ Not Started | Coordinate with user, backup Belchertown |
| [ ] Monitor for issues post-deployment | — | ⬜ Not Started | Check logs, user feedback, alerts |

---

## Decision Log

**[To be filled as evaluation progresses]**

### Current Status

- **Phase:** Phase 1 (assessment) complete 2026-04-29. Awaiting user direction on Phase 1.5 (capture) and the MQTT typo fix.
- **Next Step (proposed):** (a) fix the `mgtt://` → `mqtt://` typo on weewx, (b) capture the 7 drifted files + Python backend into a feature branch, (c) only then move to Phase 2 (skin evaluation).
- **Blockers:**
  - User decision on whether to: (i) capture-then-evaluate or (ii) evaluate-alternatives-first
  - User input on which Belchertown features must be preserved if we migrate
  - Verification of NPM's role in the proxy chain (informational, not blocking)

---

## Appendix: Resources

- **WeeWX 5.3 docs (local, primary):** [../reference/weewx-5.3/](../reference/weewx-5.3/)
  - Skin/customization: [custom/](../reference/weewx-5.3/custom/) — Cheetah generator, custom reports, image generator, units, localization
  - Reference (skin options): [reference/skin-options/](../reference/weewx-5.3/reference/skin-options/)
  - Reference (weewx.conf options): [reference/weewx-options/](../reference/weewx-5.3/reference/weewx-options/)
  - User's guide: [usersguide/](../reference/weewx-5.3/usersguide/)
- **WeeWX 4.10 docs (local, legacy reference only):** [../reference/WEEWX-USERGUIDE-4.10.html](../reference/WEEWX-USERGUIDE-4.10.html), [WEEWX-CUSTOMIZING-4.10.html](../reference/WEEWX-CUSTOMIZING-4.10.html), [WEEWX-UPGRADING-4.10.html](../reference/WEEWX-UPGRADING-4.10.html)
- **Online WeeWX docs:** https://weewx.com/docs/5.3/ (note: Cloudflare blocks default curl UA — use a browser or fetch from GitHub `weewx/weewx` tag `v5.3.1`)
- **Weewx-Belchertown upstream:** https://github.com/poblabs/weewx-belchertown
- **Your fork:** https://github.com/inguy24/weewx-belchertown
- **Weewx-MQTT extension upstream:** https://github.com/matthewwall/weewx-mqtt
- **EMQX docs:** https://www.emqx.io/docs/en/latest/
- **Weewx skins directory:** https://github.com/weewx/weewx/wiki/Skins-list
