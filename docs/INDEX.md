# Documentation Index

## Quick Links

- [CLAUDE.md](../CLAUDE.md) — Operating rules & domain routing
- [CHANGELOG.md](CHANGELOG.md) — Version history & changes
- [WEATHER-EVALUATION-PLAN.md](planning/WEATHER-EVALUATION-PLAN.md) — Main project plan

## Planning

- **[WEATHER-EVALUATION-PLAN.md](planning/WEATHER-EVALUATION-PLAN.md)** — Project scope, evaluation criteria, task tracking

## Procedures

- [Access cloud & weewx containers](procedures/CONTAINER-ACCESS.md) — SSH commands, remote execution
- [Testing skin changes locally](procedures/LOCAL-SKIN-TESTING.md) — Dev path setup, verification
- [Deploying to production](procedures/DEPLOYMENT.md) — Promotion checklist, rollback procedures

## Reference

- [SERVER-INVENTORY.md](reference/SERVER-INVENTORY.md) — **Authoritative map of what lives where** (containers, paths, MQTT chain, sync mechanism). Snapshot date 2026-04-29.
- [REPO-VS-SERVER-DIFF-2026-04-29.md](reference/REPO-VS-SERVER-DIFF-2026-04-29.md) — File-by-file comparison of live skin vs each branch on the fork
- [weewx-5.3/](reference/weewx-5.3/) — WeeWX 5.3.1 documentation (markdown source, 98 files). **Use this** — the server runs 5.3.1.
- [WEEWX-USERGUIDE-4.10.html](reference/WEEWX-USERGUIDE-4.10.html), [WEEWX-CUSTOMIZING-4.10.html](reference/WEEWX-CUSTOMIZING-4.10.html), [WEEWX-UPGRADING-4.10.html](reference/WEEWX-UPGRADING-4.10.html) — WeeWX 4.10 docs (legacy; partial overlap with 5.x)
- [../reference/weather-skin.md](../reference/weather-skin.md) — Belchertown architecture facts (corrected 2026-04-29)
- [../reference/CREDENTIALS.md](../reference/CREDENTIALS.md) — API keys, DB passwords, SSH details (gitignored)

## Archive

Completed planning docs moved here after project phases finish.

- **[AQI-CENTRALIZATION-PLAN.md](archive/AQI-CENTRALIZATION-PLAN.md)** — Route AQI through weewx as the single hub. ✅ Complete 2026-04-29.

---

**When to update this file:**
- After adding new procedures or planning docs
- When archiving completed plans
- When the project structure changes

Keep it current so team members can navigate quickly.
