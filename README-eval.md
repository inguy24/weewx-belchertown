# Weather Site Evaluation & Belchertown Skin Development

A comprehensive framework for evaluating the current weather.shaneburkhardt.com Belchertown skin and determining whether to update it or migrate to an alternative skin.

## Quick Start

1. **Read first:** [CLAUDE.md](CLAUDE.md) — Operating rules & domain routing
2. **Plan:** [docs/planning/WEATHER-EVALUATION-PLAN.md](docs/planning/WEATHER-EVALUATION-PLAN.md) — Full project scope
3. **Access:** [docs/procedures/CONTAINER-ACCESS.md](docs/procedures/CONTAINER-ACCESS.md) — SSH commands
4. **Reference:** [docs/reference/weather-skin.md](docs/reference/weather-skin.md) — Architecture & config details

## What's here

- **[rules/](rules/)** — DO/DON'T behavioral rules for skin development
- **[reference/](reference/)** — System facts, credentials, architecture
- **[docs/](docs/)** — Planning, procedures, design specs, and change log
- **[.env](.env)** — Credentials copied from Windows Server project (do not commit)
- **.gitignore** — Excludes secrets, build artifacts, temp files

## Project goal

Evaluate Belchertown skin vs. alternatives (Seasons, Beautiful Dashboard, etc.) and recommend:
- **Path A:** Update & customize Belchertown to meet needs
- **Path B:** Migrate to a different skin that better fits requirements

## Operating model

- **No manual memory** — all context lives in `rules/`, `reference/`, and `docs/planning/`
- **Domain routing** — rules & reference files are loaded only when relevant
- **Autonomous execution** — once a task is clear, work proceeds without approval for each step
- **Shared infrastructure rules** — references to Ratbert, containers, etc. load from [../Windows Server/](../Windows%20Server/) as needed

## Contributing

When making changes:
1. Create a feature branch: `git checkout -b feature/<task-name>`
2. Update relevant `rules/` or `reference/` files if procedures/facts change
3. Document progress in `docs/planning/WEATHER-EVALUATION-PLAN.md`
4. Create a PR with clear commit messages
5. After approval, merge & update `docs/CHANGELOG.md`

## Key documents

| Document | Purpose |
|----------|---------|
| [CLAUDE.md](CLAUDE.md) | Domain routing & operating rules (read first) |
| [docs/planning/WEATHER-EVALUATION-PLAN.md](docs/planning/WEATHER-EVALUATION-PLAN.md) | Phase-by-phase project plan |
| [docs/reference/weather-skin.md](docs/reference/weather-skin.md) | Belchertown architecture, config, database |
| [docs/reference/CREDENTIALS.md](docs/reference/CREDENTIALS.md) | API keys, SSH, database passwords (not committed) |
| [docs/procedures/CONTAINER-ACCESS.md](docs/procedures/CONTAINER-ACCESS.md) | SSH commands for weewx & cloud containers |
| [docs/procedures/LOCAL-SKIN-TESTING.md](docs/procedures/LOCAL-SKIN-TESTING.md) | Dev path setup & testing workflow |
| [docs/procedures/DEPLOYMENT.md](docs/procedures/DEPLOYMENT.md) | Promoting changes to production |
| [docs/CHANGELOG.md](docs/CHANGELOG.md) | Version history & changes |

## Infrastructure context

This project integrates with:

- **weewx container** (192.168.2.121) — Weather data engine + MariaDB
- **cloud container** (192.168.7.2) — Web server running weather.shaneburkhardt.com
- **Ratbert** (ratbert.shaneburkhardt.com) — LXD host, reverse proxy, DNS
- **GitHub fork** — https://github.com/inguy24/weewx-belchertown

Full context: See [../Windows Server/CLAUDE.md](../Windows%20Server/CLAUDE.md) for cross-project rules.

## Need help?

1. Check [CLAUDE.md](CLAUDE.md) for domain routing
2. Load the relevant `rules/` + `reference/` files
3. Check [docs/procedures/](docs/procedures/) for step-by-step guidance
4. If blocked: ask — don't guess at unfamiliar procedures
