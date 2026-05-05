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
| Clear Skies project (planning, ADRs, contracts, research) | [rules/clearskies-process.md](rules/clearskies-process.md) — facts live in ADRs at [docs/decisions/](docs/decisions/) and contracts at [docs/contracts/](docs/contracts/) |
| Writing or modifying code in any language (Python, PHP, JS/TS, shell, Cheetah, SQL) | [rules/coding.md](rules/coding.md) |

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

### Self-audit before delivering

For non-trivial outputs (architecture recommendations, multi-step plans, ADR drafts, code beyond a one-line fix), don't ship the first draft. The pattern is **generate → audit → revise → deliver**, and surface the audit in your reply.

- **Generate** the initial recommendation.
- **Audit it yourself** against concrete categories: security risks, maintenance burden, dependency lock-in, edge cases, what forces rework later, what looks ugly to a future reader. Apply pressure to your own choices.
- **Revise** based on the audit — strengthen weak points, remove unnecessary complexity, document tradeoffs explicitly, propose mitigations for the risks that remain.
- **Deliver** the refined output **with the audit findings surfaced**. Show what you considered, what you ruled out, and what's still uncertain.

You have explicit permission to think critically about your own work and refine it. Goal: correct and durable, not fast and sloppy. Surfacing the audit lets the user push back on points you may have under-weighted.

**Scope:** non-trivial outputs only. For simple sync / match-state / one-line-fix tasks, the "Simple means simple" rule still wins — don't perform an audit just to look thorough.

**Anti-pattern:** announce a perfect-sounding plan, then scramble when the user surfaces an obvious risk. Better to surface the risk yourself first, with the proposed mitigation.

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

**Active project: Clear Skies** — building a from-scratch modern weather UI to replace the Belchertown skin. Five-component breakdown (api / realtime / dashboard / stack / design-tokens [deferred]) under the `weewx-clearskies-*` repo prefix. GPL v3.

- **Plan:** [docs/planning/CLEAR-SKIES-PLAN.md](docs/planning/CLEAR-SKIES-PLAN.md) — phase tracker, current state, task tables.
- **Decisions:** [docs/decisions/INDEX.md](docs/decisions/INDEX.md) — 40 ADRs, all Accepted as of 2026-05-05.
- **Process:** [rules/clearskies-process.md](rules/clearskies-process.md) — when ADRs are written, format, lifecycle, plan-vs-ADR discipline.

**Production Belchertown skin:** still running on the `cloud` container, untouched. Cutover happens at Phase 5 per the plan; until then, Belchertown stays as-is.
