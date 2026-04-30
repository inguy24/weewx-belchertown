# CHANGELOG

All notable changes to the weather-belchertown project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### 2026-04-29 — Phase 1 assessment

- Merged origin/master (Belchertown skin code) into local working tree via `--allow-unrelated-histories`. Renamed local README.md → README-eval.md to avoid collision.
- Created local tracking branches `dropdowns` and `inguy24-changes` from origin.
- Pulled WeeWX 5.3.1 docs (98 markdown files from GitHub `weewx/weewx` tag `v5.3.1`) into `docs/reference/weewx-5.3/`. Server runs 5.3.1, not 4.10.
- Pulled WeeWX 4.10 user guide / customizing / upgrading HTML into `docs/reference/` for legacy reference.
- Wrote `docs/reference/SERVER-INVENTORY.md` — authoritative map of containers, MQTT chain, static-site sync via LXD shared disk, etc.
- Wrote `docs/reference/REPO-VS-SERVER-DIFF-2026-04-29.md` — file-by-file diff of live skin vs `master`/`dropdowns`/`inguy24-changes`. Identified 7 files on the server that exist in NO branch.
- Corrected `reference/weather-skin.md` — old paths (`/home/weewx/skins/...`), unknown weewx version, and incorrect TLS-termination claim.
- **Identified MQTT root cause:** `mgtt://` typo in `weewx.conf` `[StdRESTful][[MQTT]]` server_url scheme. Cause of regular users not seeing live data.
- No code changes deployed. No commits pushed to GitHub.

### Earlier

- Project initialized with evaluation framework
- Created documentation structure (rules, reference, planning)
- Set up credentials and access configuration

## [1.0.0-evaluation] — 2026-04-29

- Initial project setup with Belchertown fork
- Documentation & evaluation criteria defined
