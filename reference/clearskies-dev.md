# reference/clearskies-dev.md — Clear Skies Development Environment

Load alongside [rules/clearskies-process.md](../rules/clearskies-process.md) when doing Clear Skies implementation work.

## Two-machine split

| Machine | Role | What runs here |
|---|---|---|
| **DILBERT** (Windows workstation) | Editing, git, planning, orchestration | VS Code, Claude Code, `git push`, brief-drafting |
| **weather-dev** (LXD container on ratbert) | Runtime, tests, builds | `pytest`, `uv`, `docker compose`, `npm`, `vite` |

Do NOT run pytest, uv, docker, or node toolchains on DILBERT. Do NOT edit source files on weather-dev (except test-author fixture captures, which are committed from weather-dev directly).

## Repo paths

### DILBERT (local clones)

All five repos live under the meta repo:

```
c:\CODE\weather-belchertown\repos\
  weewx-clearskies-api\          # default branch: main
  weewx-clearskies-realtime\     # default branch: main
  weewx-clearskies-dashboard\    # default branch: main
  weewx-clearskies-stack\        # default branch: main
  weewx-clearskies-design-tokens\# default branch: main
```

Meta repo (`c:\CODE\weather-belchertown\`) default branch: **master**.

### weather-dev (runtime clones)

```
/home/ubuntu/repos/
  weewx-clearskies-api/
  weewx-clearskies-realtime/
  weewx-clearskies-dashboard/
  weewx-clearskies-stack/
  weewx-clearskies-design-tokens/
```

Owner: `ubuntu`. Container IP: `192.168.2.113` (DHCP/SLAAC on `br-vlan2`).

## SSH access

Shell into weather-dev from DILBERT:

```bash
ssh ratbert "lxc exec weather-dev -- bash -lc '<command>'"
```

Run as the `ubuntu` user (avoids git "dubious ownership" errors):

```bash
ssh ratbert "lxc exec weather-dev -- sudo -u ubuntu bash -lc '<command>'"
```

## Sync: DILBERT to weather-dev

1. Commit and push to GitHub from DILBERT.
2. Run the sync script (pulls all five repos on weather-dev via `git pull --ff-only`):

```bash
# From the meta repo on DILBERT (bash tool):
scripts/sync-to-weather-dev.sh

# Or pull a single repo:
scripts/sync-to-weather-dev.sh weewx-clearskies-api
```

## Toolchain on weather-dev

- **Python:** 3.12
- **Package manager:** uv
- **Test runner:** pytest (via uv)
- **Node:** 22 LTS
- **Docker:** Engine 29.4 + Compose v5

## Common commands

### Run pytest (api repo)

```bash
ssh ratbert "lxc exec weather-dev -- sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=short -q'"
```

Quick summary only (pass/skip/fail counts):

```bash
ssh ratbert "lxc exec weather-dev -- sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest --tb=no -q 2>&1 | tail -3'"
```

### Run a specific test file or marker

```bash
# One file:
ssh ratbert "lxc exec weather-dev -- sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest tests/test_radar_rainviewer.py -v'"

# By marker (e.g., integration tests):
ssh ratbert "lxc exec weather-dev -- sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-api && uv run pytest -m integration --tb=short'"
```

### Browser testing

Dashboard or API dev server on weather-dev is accessible from DILBERT at:

```
http://192.168.2.113:<port>
```

## Pytest baselines

Track the pass/skip/fail count at each round close to detect regressions.

| Round | Commit | Passed | Skipped | Failed |
|---|---|---|---|---|
| 3b-13 close | ecd7e75 | 1954 | 364 | 0 |
| 3b-14 close | f2362ee | 2123 | 364 | 0 |
| 3b-15 close | ad1fe37 | 2283 | 364 | 0 |
| 3b-16 close | ae4a86d | 2302 | 364 | 0 |

## GitHub remotes

All repos under `github.com/inguy24/`:

- `weewx-clearskies-api`
- `weewx-clearskies-realtime`
- `weewx-clearskies-dashboard`
- `weewx-clearskies-stack`
- `weewx-clearskies-design-tokens`

Branching policy (pre-1.0): no feature branches. Commit straight to `main` (api repos) / `master` (meta repo).
