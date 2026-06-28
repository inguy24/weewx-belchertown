# Clear Skies GitHub Organization Migration Plan

**Status:** APPROVED
**Created:** 2026-06-27
**Components:** All repos, GitHub org, local directory, container deployments

---

## Context

The Clear Skies project started as tweaks to the Belchertown weewx skin, so all project management (docs, manuals, rules, ADRs, scripts) lives in `c:\CODE\weather-belchertown\` -- a fork of `poblabs/weewx-belchertown`. The actual Clear Skies code lives in 5 separate repos under `github.com/inguy24/`. This creates three problems: (1) the project hub is a fork of someone else's skin with their commit history, README, and license; (2) the repos are scattered under a personal account, not a project identity; (3) there's no centralized place for support. The migration creates a GitHub organization (`clearskies-wx`), a dedicated project repo, and transfers the component repos -- while keeping the local directory at `c:\CODE\weather-belchertown\` unchanged to preserve Nextcloud sync, SSH config, and scripts.

**History preservation:** The full commit history (1,800+ commits) is pushed to the new project repo. Wiping history would make the project look like AI slop or a freshly generated repo. The Belchertown-era commits show the real evolution from skin evaluation to full system build -- that's social proof, not noise. The approach: push the existing history to a new (non-fork) repo on GitHub, then add a "divorce" commit that removes the Belchertown skin files.

**Fork detachment:** GitHub won't let you transfer a fork as a standalone repo. Instead, we create `weewx-clearskies-project` as a new repo and push the full history there. The Belchertown fork stays under `inguy24/` untouched.

**Support model:** Issues and Discussions enabled ONLY on the project repo. Component repos have Issues disabled. Users file everything in one place; we triage internally. Each component repo README links to the project repo for support.

**Centralized CHANGELOG:** In the project repo, covering the whole stack.

## Org name

Confirm `clearskies-wx` is available on GitHub before starting. Alternatives if taken: `clearskies-weather`, `weewx-clearskies`.

## Target repo structure

| Repo | Purpose | Issues | Discussions |
|------|---------|--------|-------------|
| `weewx-clearskies-project` | Docs, manuals, rules, planning, support hub, CHANGELOG | Yes | Yes |
| `.github` | Org profile README (landing page) | No | No |
| `weewx-clearskies-api` | Python backend API | Disabled | No |
| `weewx-clearskies-dashboard` | React SPA | Disabled | No |
| `weewx-clearskies-stack` | Docker-compose, Caddyfile, config UI | Disabled | No |
| `weewx-clearskies-extension` | Loop relay weewx extension (required) | Disabled | No |
| `weewx-clearskies-truesun` | Simplified Solis XType extension (recommended) | Disabled | No |

NOT transferred: `weewx-clearskies-realtime` (archived per ADR-058), `weewx-clearskies-design-tokens` (Phase 6+ placeholder), `weewx-belchertown` (stays as fork under `inguy24/`).

---

## Phase 0 -- Pre-flight

**Goal:** Verify everything is clean, create the org.

1. **Verify clean state locally:** `git status` on the meta repo and all child repos in `repos/`. No uncommitted changes anywhere. Record HEAD SHAs.
2. **Verify clean state on containers:** SSH to `weewx` and `weather-dev`, `git status` and `git remote -v` in each repo under `/home/ubuntu/repos/`.
3. **Create the GitHub org:** `clearskies-wx` at github.com/organizations/plan (Free tier). Add `inguy24` as sole owner. Set display name "Clear Skies", bio referencing weewx.
4. **Create `.github` repo in the org:** Add `profile/README.md` as the org landing page (project name, one-paragraph description, architecture diagram, links to component repos, link to project repo for support).

---

## Phase 1 -- Create the project repo with full history

**Goal:** `clearskies-wx/weewx-clearskies-project` exists on GitHub with the full commit history from the Belchertown fork, then a "divorce" commit removes the skin files.

1. **Create `weewx-clearskies-project`** on GitHub under `clearskies-wx/` (empty, no README/license).
2. **Enable Issues and Discussions** on this repo. This is the only repo with Issues enabled.
3. **Push full history from local repo:**
   ```
   cd c:\CODE\weather-belchertown
   git remote add clearskies https://github.com/clearskies-wx/weewx-clearskies-project.git
   git push clearskies master:main    # push master branch as main
   ```
   This preserves all 1,800+ commits. The Belchertown-era commits show the project's real evolution.
4. **Remove Belchertown files** (the "divorce" commit):
   - Delete: `skins/`, `bin/`, `install.py`, `readme.txt`, `changelog`
   - Delete: `.github/` (Belchertown's issue templates/funding)
   - Replace: `README.md` with new project README (project name, description, architecture, component repo links, support model, GPL v3)
   - Replace: `LICENSE` with a clean GPL v3 file
   - Clean up: `.gitignore` -- remove `weewx-output/` and `Belchertown-dev/` entries
5. **Write new `.github/ISSUE_TEMPLATE/`** templates (bug report, feature request, installation help).
6. **Update all `inguy24` references** to `clearskies-wx`. Key files:
   - `setup-local.ps1` -- clone URLs (add extension + truesun, remove realtime)
   - `reference/clearskies-dev.md` -- GitHub remotes section
   - `docs/contracts/openapi-v1.yaml` -- contact URL
   - `docs/procedures/deploy-clearskies.md` -- clone URLs in examples
   - Archived docs (`docs/archive/`) -- update since the Belchertown fork URL won't redirect to the project repo
7. **Update the workspace file** to reflect current repos (drop realtime + design-tokens, add extension + truesun).
8. **Commit and push:** "Separate Clear Skies project from Belchertown fork" commit to `clearskies-wx/weewx-clearskies-project`.

---

## Phase 2 -- Transfer component repos to the org

**Goal:** Component repos move from `inguy24/` to `clearskies-wx/`.

1. **Transfer via GitHub Settings** (Settings > Danger Zone > Transfer):
   - `inguy24/weewx-clearskies-api` -> `clearskies-wx/`
   - `inguy24/weewx-clearskies-dashboard` -> `clearskies-wx/`
   - `inguy24/weewx-clearskies-stack` -> `clearskies-wx/`
   - `inguy24/weewx-clearskies-truesun` -> `clearskies-wx/`
   - `inguy24/weewx-clearskies-extension` -> `clearskies-wx/` (if it exists; else create directly in org)

   GitHub creates permanent redirects from the old URLs. All existing `git pull` operations continue to work through redirects.

2. **Do NOT transfer:** `weewx-clearskies-realtime` (archived), `weewx-clearskies-design-tokens` (placeholder), `weewx-belchertown` (stays as fork).
3. **Disable Issues** on each transferred component repo (Settings > Features).
4. **Add support pointer** to each component repo's README:
   ```
   ## Support
   Issues and discussions: [weewx-clearskies-project](https://github.com/clearskies-wx/weewx-clearskies-project)
   ```

**Can run in parallel with Phase 1** (both only need the org to exist).

---

## Phase 3 -- Update component repo references

**Goal:** All `inguy24` references in component repos change to `clearskies-wx`.

The audit found references in these categories across component repos:
- README, INSTALL, CONFIG, SECURITY, CHANGELOG, DEVELOPMENT, THEMING docs
- `ghcr.io/inguy24/` Docker image references in docker-compose files (stack repo)
- EULA.txt (stack repo)
- `src/routes/legal.tsx` -- **hardcoded GitHub URL in source code** (dashboard repo, requires rebuild)
- `src/api/openapi-v1.yaml` -- contact URL (dashboard repo)
- Extension repo README links back to meta repo ADRs (URL pattern changes: `inguy24/weather-belchertown/blob/master/docs/` -> `clearskies-wx/weewx-clearskies-project/blob/main/docs/archive/`)

**Pattern:** In each component repo, `grep -r "inguy24"` and replace with `clearskies-wx`. Commit and push.

**CI note:** Release workflows use `${{ github.repository }}` for GHCR image names -- auto-resolves after transfer, no workflow changes needed.

---

## Phase 4 -- Repoint the local directory

**Goal:** `c:\CODE\weather-belchertown\` becomes the working tree for `weewx-clearskies-project` without changing the directory path.

Since Phase 1 pushed the full history to the new repo, the local directory already has the right commits. We just swap remotes and switch branches.

1. **Swap the remote:**
   ```
   git remote rename origin belchertown-fork
   git remote rename clearskies origin          # clearskies remote was added in Phase 1
   ```
   This preserves the fork remote as a named backup (can be removed later) and makes the project repo the default `origin`.
2. **Switch to main branch:**
   ```
   git checkout main                            # tracks origin/main (the project repo)
   ```
   The Belchertown files were already removed in Phase 1's divorce commit, so the working tree should be clean after checkout.
3. **Update child repo remotes** (in each `repos/` subdirectory):
   ```
   git remote set-url origin https://github.com/clearskies-wx/<repo-name>.git
   ```
   Do this for: api, dashboard, stack, extension, truesun. Remove stale repos (realtime, design-tokens) if desired.
4. **Verify:** `git status` clean, `git pull` works, `git push` works (test with trivial change), VS Code workspace opens correctly, `.local/` symlinks intact, `.env` symlink intact.

---

## Phase 5 -- Update container git remotes

**Goal:** Container-side clones point to the new org.

1. **weather-dev container:** Update remotes for dashboard, stack, design-tokens (and any others present):
   ```
   ssh -F .local/ssh/config weather-dev "sudo -u ubuntu bash -lc '
     cd /home/ubuntu/repos/weewx-clearskies-dashboard && git remote set-url origin https://github.com/clearskies-wx/weewx-clearskies-dashboard.git
     cd /home/ubuntu/repos/weewx-clearskies-stack && git remote set-url origin https://github.com/clearskies-wx/weewx-clearskies-stack.git
   '"
   ```
2. **weewx container:** Update remote for the API repo (and extension/truesun if cloned there).
3. **Verify sync:** Run `scripts/sync-to-weather-dev.sh` -- pulls should succeed.
4. **Verify full redeploy:** Run `scripts/redeploy-weather-dev.sh` -- dashboard builds and deploys.

---

## Phase 6 -- Cleanup and verification

1. **Update Belchertown fork:** Add superseded note to `inguy24/weewx-belchertown` README/description.
2. **Rebuild dashboard:** The `legal.tsx` source code change (Phase 3) requires a dashboard rebuild + redeploy for the production site.
3. **Write ADR-076:** Document the migration decision (why org, why centralized support, what moved where).
4. **Verify GitHub redirects:** Confirm `github.com/inguy24/weewx-clearskies-api` redirects to `clearskies-wx/`.
5. **Final grep sweep:** `grep -r "inguy24"` across all repos to catch any missed references.
6. **Pin repos on the org profile:** Pin project, api, dashboard, stack on the org page.
7. **Remove `belchertown-fork` remote** once everything is confirmed working: `git remote remove belchertown-fork`.

---

## Dependency graph

```
Phase 0 (pre-flight + create org)
  |
  +-- Phase 1 (create project repo)  \
  |                                    +-- Phase 4 (repoint local dir)
  +-- Phase 2 (transfer repos)       /         |
        |                                      +-- Phase 5 (container remotes)
        +-- Phase 3 (update component refs)            |
                                                       +-- Phase 6 (cleanup)
```

Phases 1 and 2 are parallel. Phase 4 needs Phase 1 done (remote to swap). Phase 5 needs 2 and 3 done. Phase 6 is last.

---

## What does NOT change

- Local directory path: `c:\CODE\weather-belchertown\` stays
- Nextcloud sync: `.local/` directory untouched
- SSH config and keys: `.local/ssh/` untouched
- Container paths: `/home/ubuntu/repos/weewx-clearskies-*` stay (only git remotes change)
- Repo names: `weewx-clearskies-api` etc. keep their names (only the org prefix changes)
- Deploy scripts: Same scripts, same paths (`sync-to-weather-dev.sh` references repo directory names on the container, not GitHub URLs)

## Files with `inguy24` references (audit results)

**Project repo (this repo):**
- `setup-local.ps1` -- 5 clone URLs
- `reference/clearskies-dev.md` -- GitHub remotes section, local paths
- `docs/contracts/openapi-v1.yaml` -- contact URL
- `docs/procedures/deploy-clearskies.md` -- clone URLs in examples
- `docs/archive/` -- ~15 archived files with GitHub URLs
- `rules/weather-skin.md` -- fork URL
- `reference/weather-skin.md` -- GitHub repo URL

**Component repos:**
- API: README, INSTALL, CHANGELOG, SECURITY (~17 refs)
- Dashboard: README, INSTALL, CONFIG, SECURITY, DEVELOPMENT, CHANGELOG, THEMING, `legal.tsx` (source code!), `openapi-v1.yaml` (~22 refs)
- Stack: README, INSTALL, CONFIG, CHANGELOG, SECURITY, EULA.txt, 4 docker-compose files with `ghcr.io/inguy24/` (~30 refs)
- Extension: README (~3 refs, includes cross-repo ADR link to meta repo)
- Truesun: README (~1 ref)

## Verification checklist

- [ ] `git remote -v` in every repo (local + containers) shows `clearskies-wx/`
- [ ] `git pull` works in every repo
- [ ] `scripts/sync-to-weather-dev.sh` succeeds
- [ ] `scripts/redeploy-weather-dev.sh` succeeds (dashboard builds, deploys, renders)
- [ ] VS Code workspace opens with all folders
- [ ] `.env` and `.local/` symlinks work
- [ ] GitHub org page shows pinned repos
- [ ] Issues disabled on component repos, enabled on project repo
- [ ] Old `inguy24/` URLs redirect correctly
- [ ] `grep -r "inguy24"` returns zero hits across all repos
- [ ] Dashboard `legal.tsx` shows new org URL in production
