# rules/weather-skin.md — Weather Site & Belchertown Skin Development

Load when working on the weather website, Belchertown skin customization, weewx configuration, or evaluating alternative skins.
Pair with [reference/weather-skin.md](../reference/weather-skin.md) for facts (URLs, paths, config details).

## Never modify production weather data

The weewx container on Ratbert is the authoritative source for weather data. Do not:
- Delete or corrupt database records (especially `archive` table in MariaDB)
- Modify live weewx configuration while the engine is running (stop it first with `systemctl stop weewx`)
- Run SQL `TRUNCATE` or `DROP` commands without explicit user approval

**If you need to test database changes:** use a backup or development copy of the database, never the live `weewx` database.

## Skin source is a git fork, not a copy

The Belchertown skin source is cloned from https://github.com/inguy24/weewx-belchertown (your fork). This means:
- Always work on a feature branch (not main/master)
- Test locally before pushing
- Document changes in `docs/CHANGELOG.md` and the deployment plan
- When satisfied, create a PR for review before merging to a deploy branch

**Deploy process (if applicable):**
- Push to a feature branch → test on staging (`cloud` container development path)
- Create PR with evaluation results
- After approval, merge to production deploy branch
- Redeploy weewx skin on `cloud` container

## Belchertown skin lives in `/home/weewx/skins/Belchertown/`

On the `weewx` container:
- Main skin template: `/home/weewx/skins/Belchertown/skin.conf`
- HTML/CSS templates: `/home/weewx/skins/Belchertown/html/` and `/home/weewx/skins/Belchertown/css/`
- Generated output: `/var/www/html/` (symlinked or copied from weewx output)

**Access:** `ssh ratbert "lxc exec weewx -- <command>"` (no direct SSH to weewx container)

## Separate dev skin path from production

When testing customizations:
1. Clone the skin to a `Belchertown-dev` directory (don't modify the live `Belchertown/` folder)
2. Update weewx config to point at the dev skin temporarily
3. Run `weewxd --config=/etc/weewx/weewx.conf --skin=Belchertown-dev` or similar (see reference for exact process)
4. Verify output before deploying to production

If you don't know the exact weewx invocation for dev testing, check `docs/procedures/` or ask before guessing.

## Alternative skins must meet evaluation criteria

When evaluating replacement skins, document findings against these criteria:
- **Data display:** Does it show current conditions, forecast, historical trends?
- **Customization:** Can you modify colors, layout, branding without patching weewx source?
- **Performance:** Does it generate output fast enough for weewx's publish interval?
- **Mobile-responsive:** Does it work on phone/tablet out of the box?
- **Maintenance burden:** How often does the upstream release updates? Active community?
- **Integration:** Does it support Belchertown's current features (gauges, radar, alerts)?

Save evaluation results in `docs/planning/WEATHER-EVALUATION-PLAN.md` with a recommendation summary.

## No hardcoded paths or credentials in skin templates

If you modify the Belchertown skin to pull data from an external API (e.g., alerts, radar tiles):
- Externalize URLs, API keys, and configuration to weewx config (`skin.conf`), not HTML templates
- Use environment variables or `.env` for secrets, never commit credentials
- Document the new config keys in `reference/weather-skin.md` so future maintainers know what to set

## GitHub branch rules

- **main** — stable Belchertown upstream (if tracking it) or your baseline
- **feature/...** — skin customizations, alternative skin evaluations, bug fixes
- **staging** — version tested on dev path, ready for production promotion

Create a PR for any non-trivial change. The evaluation project itself may not have merge rules yet — clarify with the user if a PR is needed for this phase.
