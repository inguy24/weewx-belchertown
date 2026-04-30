# CLAUDE.md — Weather Site Evaluation & Skin Development

This project focuses on evaluating and potentially updating the weather website (weather.shaneburkhardt.com) running on the `cloud` container via the Belchertown weewx skin, with possible migration to an alternative skin.

Domain-specific rules and reference facts live in separate files and are **only loaded when relevant**:

- **`rules/<domain>.md`** — DO/DON'T behavioral rules (what to do, what to avoid). Keep these short and prominent.
- **`reference/<domain>.md`** — facts (URLs, IPs, paths, access methods, architecture). Can be longer; informational only.

## Domain routing

At the start of a task, identify which domain(s) apply and read the matching files with the Read tool before acting. **Load BOTH the rules file and the reference file** for each relevant domain.

| Task involves… | Load |
| --- | --- |
| Belchertown skin development, weewx config, weather data, skin alternatives | [rules/weather-skin.md](rules/weather-skin.md) + [reference/weather-skin.md](reference/weather-skin.md) |
| Accessing cloud container, Nextcloud, weather.shaneburkhardt.com | [rules/ratbert-lxd.md](rules/ratbert-lxd.md) + [reference/ratbert-lxd.md](reference/ratbert-lxd.md) (from Windows Server project) |
| Ratbert VM, LXD containers, freepbx, adguard | [rules/ratbert-lxd.md](../Windows%20Server/rules/ratbert-lxd.md) + [reference/ratbert-lxd.md](../Windows%20Server/reference/ratbert-lxd.md) |
| Home Assistant, automations | [rules/homeassistant.md](../Windows%20Server/rules/homeassistant.md) + [reference/homeassistant.md](../Windows%20Server/reference/homeassistant.md) |
| GitHub operations (branches, PRs, releases) | [rules/github.md](rules/github.md) |

## Always-applicable rules

These apply regardless of domain.

### Operating posture

- **NEVER assume state — verify first.** Check current state before running any command.
- **If a solution fails twice, STOP.** Report the failure and ask for clarification. Do not repeatedly attempt the same fix.
- **NO LOOPS.** Do not repeatedly attempt the same fix or command hoping for a different result.
- **When you don't know, search the web.** Don't guess at procedures from training data. Search official docs and reputable community sources before running anything destructive or unfamiliar.

### Collaboration style

- **Simple means simple.** For sync / match-state / "fix this one mismatch" tasks, do the minimum delta and stop. Don't expand scope unless asked.
- **Don't parrot the user's framing as fact.** Treat requests as hypotheses to verify, not premises to act on.
- **Narrate the diagnostic plan before commands.** When investigating a problem, name the hypothesis and what each command tests *before* firing tool calls.
- **For root-cause questions, never propose creating/editing records until the *why* is established.**

### Memory system — DO NOT USE

Auto-memory (the `memory/` directory) is **disabled by policy**. Do not write new memory entries. 

**Where things go instead:**
- Behavioral rules / feedback / corrections → the relevant `rules/<domain>.md`
- Facts about systems (URLs, IPs, paths, access methods) → the relevant `reference/<domain>.md`
- Project plans → `docs/planning/<plan-name>.md`. Completed plans move to `docs/archive/`.

## File organization

```
weather-belchertown/
├── CLAUDE.md                          # This file — domain routing & operating rules
├── .env                               # Credentials (from Windows Server)
├── .claude/                           # VS Code agent customizations (if needed)
├── rules/
│   ├── weather-skin.md               # Belchertown skin dev rules & practices
│   ├── github.md                     # GitHub workflow rules
│   └── [shared rules load from Windows Server/rules/]
├── reference/
│   ├── weather-skin.md               # Belchertown architecture & config facts
│   ├── CREDENTIALS.md                # Passwords, API keys, access details
│   └── [shared reference load from Windows Server/reference/]
├── docs/
│   ├── INDEX.md                      # Documentation index
│   ├── CHANGELOG.md                  # Version history & changes
│   ├── planning/
│   │   └── WEATHER-EVALUATION-PLAN.md # Main project plan & tasks
│   ├── archive/                      # Completed planning docs
│   ├── procedures/                   # Step-by-step howtos
│   └── reference/                    # Design specs, architecture diagrams
├── scripts/
│   └── [deployment & automation scripts]
└── [skin source code will be cloned here]
```

## Environment access

All credentials and connection info are in `reference/CREDENTIALS.md`:
- **cloud container** SSH access, port mappings, Nextcloud auth
- **weewx container** MariaDB creds, API endpoints
- **.env file** contains tokens for Home Assistant, CheckMK, MikroTik, AdGuard

Never hardcode credentials — always load from reference files or .env.

## Project scope

**Evaluation phase objectives:**
- [ ] Survey current Belchertown skin capabilities & limitations
- [ ] Evaluate alternative weewx skins (Seasons, Beautiful Dashboard, etc.)
- [ ] Determine if updates to Belchertown meet needs or if migration is necessary
- [ ] Document recommendations and implementation path

**If modification is chosen:** implement selected skin & features in a feature branch, test on staging, merge to production.

**If migration is chosen:** evaluate new skin, prepare migration plan, coordinate with weewx data continuity.
