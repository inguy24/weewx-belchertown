# deploy-clearskies.md — Full Clear Skies redeploy to weather-dev

How to redeploy the Clear Skies stack onto the **weather-dev** LXD container after pushing
commits to GitHub. This is the modern Clear Skies path; the legacy Belchertown skin promotion
lives in [DEPLOYMENT.md](DEPLOYMENT.md) and is unrelated.

Two scripts in `scripts/`:

| Script | What it does | When |
|--------|--------------|------|
| `sync-to-weather-dev.sh` | `git pull --ff-only` only (all repos or one) | Source-only refresh, no rebuild/restart |
| `redeploy-weather-dev.sh` | Full redeploy: pull → restart services → dashboard build → publish `dist/` | After any change that affects running services or the dashboard UI |

---

## Prerequisites

- Commits already **pushed to GitHub** (the container pulls from GitHub, not from DILBERT).
- SSH access to the LXD host: `ssh ratbert` works.
- One-time standup done: all five repos cloned at `/home/ubuntu/repos/<name>` inside the
  `weather-dev` container, and the container set up (Caddy, systemd units, web root, webcam mount).
- Run from a bash-capable shell on DILBERT (Git Bash / WSL).

## Verified weather-dev facts (2026-05-29)

These are what the script targets. Re-verify if the container is rebuilt.

| Thing | Value |
|-------|-------|
| systemd units | `weewx-clearskies-realtime.service`, `weewx-clearskies-api.service`, `weewx-clearskies-config.service` |
| Dashboard repo | `/home/ubuntu/repos/weewx-clearskies-dashboard` |
| Build command | `npm run build` → `tsc -b && vite build` |
| Build output | `./dist` (default Vite `outDir`; no override in `vite.config.ts`) |
| Web root | `/var/www/clearskies` (Caddy `root *`; owned `ubuntu:ubuntu`, mode 775) |
| Webcam mount | `/var/www/clearskies/webcam` — **read-only LXD bind-mount** (host `/mnt/weewx/webcam`) |
| Reverse proxy | Caddy on `:80`; serves web root, proxies `/api/v1/*` + `/sse` → `:8766`, config UI paths → `:9876` |

## The webcam exclusion (why it matters)

`/var/www/clearskies/webcam` is **not** part of the dashboard build. It is a separate, **read-only**
bind-mount where an external capture process drops `weather_cam.jpg` and `weewx_timelapse.mp4`
(see ARCHITECTURE.md → Webcam). The redeploy publishes the freshly built `dist/` into the web root,
which means rsync's destination tree *contains* the webcam mount.

`redeploy-weather-dev.sh` uses `rsync -a --delete --exclude='webcam/'`:

- `--exclude='webcam/'` removes `webcam/` from rsync's file list entirely, so rsync never enters
  it and never lists it as a deletion candidate. With `--delete`, **excluded paths are not deleted** —
  this is exactly the protection we want for the bind-mount.
- The mount being **read-only** is a second, independent backstop: even if rsync attempted a write
  there, the kernel would reject it.
- `--delete` is therefore **safe here** and is used so stale dashboard assets (old hashed JS/CSS
  bundles) are pruned. Pass `--no-delete` if you ever want a non-pruning sync.

---

## Full redeploy — steps

From DILBERT:

```bash
./scripts/redeploy-weather-dev.sh
```

What it does, in order (each step aborts on failure — `set -euo pipefail`):

1. **Pull** — delegates to `sync-to-weather-dev.sh` (all five repos, `git pull --ff-only` as `ubuntu`).
   Skip with `--skip-pull`.
2. **Restart services** — `systemctl restart` (as root) for realtime, api, config; each is then
   checked with `systemctl is-active --quiet` and the deploy aborts if a unit didn't come back up.
3. **Build dashboard** — `npm ci --legacy-peer-deps && npm run build` (as `ubuntu`) in the dashboard
   repo; verifies `dist/index.html` exists. (`--legacy-peer-deps` is required until the
   `typescript@6` vs `openapi-typescript` peer conflict is reconciled — plain `npm ci` aborts on
   ERESOLVE. Drop the flag once that's fixed.)
4. **Publish** — `rsync -a --delete --exclude='webcam/'` from `dist/` into `/var/www/clearskies/`
   (as `ubuntu`), protecting the webcam bind-mount as described above.

### Options

| Flag | Effect |
|------|--------|
| `--skip-pull` | Skip step 1 (use the source already on the container) |
| `--no-delete` | rsync without `--delete` (don't prune stale web-root files) |

### Source-only refresh (no rebuild/restart)

```bash
./scripts/sync-to-weather-dev.sh                       # all repos
./scripts/sync-to-weather-dev.sh weewx-clearskies-api  # one repo
```

---

## Deploying API changes to the weewx container

**The API does NOT run on weather-dev.** It runs on the `weewx` LXD container (see [ARCHITECTURE.md](../ARCHITECTURE.md) §Services, §Container inventory). The redeploy script above only deploys frontend code (dashboard, BFF, config UI) to weather-dev.

When you change code in `weewx-clearskies-api`, you must deploy it to the weewx container separately:

```bash
# 1. Pull the latest code on the weewx container
ssh ratbert "lxc exec weewx -- sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-api && git pull --ff-only'"

# 2. Restart the API service
ssh ratbert "lxc exec weewx -- systemctl restart weewx-clearskies-api"

# 3. Verify it started correctly (should NOT say "setup mode")
ssh ratbert "lxc exec weewx -- journalctl -u weewx-clearskies-api --since '10 sec ago' --no-pager | head -5"

# 4. Verify the API responds through the BFF on weather-dev
ssh ratbert "lxc exec weather-dev -- curl -s -o /dev/null -w '%{http_code}\n' http://localhost/api/v1/current"
```

**Common mistake:** The `redeploy-weather-dev.sh` script restarts `weewx-clearskies-api.service` on weather-dev, but that is NOT the production API instance. The production API runs on the `weewx` container. Restarting the weather-dev copy does nothing useful and may start in "setup mode" (no config file on that host).

**Cache note:** The API uses an in-memory cache (30-min TTL for forecast, 5-min for AQI). Restarting the API service clears the cache. The first request after restart will fetch fresh data from the upstream provider (Aeris, OWM, etc.).

---

## Verify the deploy succeeded

```bash
# 1. Dashboard serves (expect HTTP/1.1 200)
ssh ratbert "lxc exec weather-dev -- curl -sI http://localhost/ | head -1"

# 2. Webcam still served (the bind-mount survived the rsync) — expect 200 if a capture exists
ssh ratbert "lxc exec weather-dev -- curl -s -o /dev/null -w '%{http_code}\n' http://localhost/webcam/weather_cam.jpg"

# 3. API through the BFF (expect 200 + unit-converted JSON)
ssh ratbert "lxc exec weather-dev -- curl -s -o /dev/null -w '%{http_code}\n' http://localhost/api/v1/current"

# 4. All three services active
ssh ratbert "lxc exec weather-dev -- systemctl is-active weewx-clearskies-realtime weewx-clearskies-api weewx-clearskies-config"

# 5. Confirm webcam is still a mounted, read-only bind (NOT a plain dir rsync recreated)
ssh ratbert "lxc exec weather-dev -- findmnt /var/www/clearskies/webcam"
```

Checks:

- [ ] `/` returns 200 and the React SPA loads
- [ ] `/webcam/...` still served from the read-only mount (findmnt shows it as `ro` bind)
- [ ] `/api/v1/current` returns 200 through the BFF
- [ ] all three services report `active`

## Rollback

The dashboard build is reproducible from git, so rollback = check out the prior commit on the
container and rebuild:

```bash
# On the container, as ubuntu, in the affected repo(s):
ssh ratbert "lxc exec weather-dev -- sudo -u ubuntu bash -lc 'cd /home/ubuntu/repos/weewx-clearskies-dashboard && git log --oneline -5'"
# Then (coordinator/operator decision — agents do NOT git checkout): check out the known-good
# commit and re-run ./scripts/redeploy-weather-dev.sh --skip-pull to rebuild + republish.
```

For services, a restart of the prior code (after checking out the prior commit and re-pulling deps)
restores the previous behavior. The webcam mount is independent of any deploy and is never affected.

---

See [CONTAINER-ACCESS.md](CONTAINER-ACCESS.md) for transport details and
[../ARCHITECTURE.md](../ARCHITECTURE.md) for the authoritative service/topology/webcam reference.
