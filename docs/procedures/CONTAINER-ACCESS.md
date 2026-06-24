# CONTAINER-ACCESS.md — SSH & Remote Execution Reference

## SSH config

All SSH keys and config live in the project directory at `.local/ssh/` (replicates via Nextcloud).
**Always use `-F .local/ssh/config`** when running SSH commands.

**Do NOT use `~/.ssh/` — keys do not replicate from there.**
**Do NOT go through ratbert with `lxc exec` to reach weewx or weather-dev.** Direct SSH is configured.

## Quick access from DILBERT

**Weewx container** (weather engine, DB, Clear Skies API):
```bash
ssh -F .local/ssh/config weewx
```

**Weather-dev container** (dashboard, config UI, Caddy):
```bash
ssh -F .local/ssh/config weather-dev
```

**Cloud container** (legacy Belchertown — NO direct SSH, must use lxc exec):
```bash
ssh -F .local/ssh/config ratbert "lxc exec cloud -- bash"
```

**Ratbert host** (LXD management only — NOT for accessing weewx or weather-dev):
```bash
ssh -F .local/ssh/config ratbert
```

## Common commands

**Check weewx engine status:**
```bash
ssh -F .local/ssh/config weewx "systemctl status weewx"
```

**View weewx logs:**
```bash
ssh -F .local/ssh/config weewx "journalctl -u weewx -f -n 50"
```

**Restart weewx (after config changes):**
```bash
ssh -F .local/ssh/config weewx "systemctl restart weewx"
```

**Query weewx database:**
```bash
ssh -F .local/ssh/config weewx "mysql -u weewx -p weewx -e 'SELECT * FROM archive LIMIT 5;'"
```

**Check Clear Skies API status:**
```bash
ssh -F .local/ssh/config weewx "systemctl status weewx-clearskies-api"
```

**Restart Clear Skies API (~2 min startup, cache warmer):**
```bash
ssh -F .local/ssh/config weewx "systemctl restart weewx-clearskies-api"
```

**Flush Redis cache on weewx:**
```bash
ssh -F .local/ssh/config weewx "redis-cli FLUSHDB"
```

**Check Clear Skies dashboard / Caddy on weather-dev:**
```bash
ssh -F .local/ssh/config weather-dev "systemctl is-active weewx-clearskies-config"
ssh -F .local/ssh/config weather-dev "curl -s -o /dev/null -w '%{http_code}\n' http://localhost/"
```

---

## Container locations

| Service | Container | Direct SSH | Purpose |
|---------|-----------|------------|---------|
| Weewx engine + DB + Clear Skies API + Redis | `weewx` | `ssh -F .local/ssh/config weewx` | Weather data, archiving, REST API (port 8765), SSE, Redis cache (6379 loopback) |
| Dashboard + config UI + Caddy | `weather-dev` | `ssh -F .local/ssh/config weather-dev` | Dashboard SPA (static files), config UI (port 9876), Caddy (ports 80/443 — proxies to API on weewx) |
| Legacy web server | `cloud` | via ratbert: `lxc exec cloud -- bash` | Nextcloud + weather.shaneburkhardt.com (Belchertown skin) |
| LXD host | `ratbert` | `ssh -F .local/ssh/config ratbert` | Container orchestration only |

**Two-host split (Clear Skies):** The API runs on `weewx` (port 8765), Caddy + dashboard + config UI run on `weather-dev`. Caddy proxies `/api/v1/*` and `/sse` to the API on weewx (`https://weewx.shaneburkhardt.com:8765`). See [../ARCHITECTURE.md](../ARCHITECTURE.md) for the full topology.

---

## File transfer

Copy files to weewx:
```bash
scp -F .local/ssh/config /local/path/file.txt weewx:/tmp/
```

Copy files to weather-dev:
```bash
scp -F .local/ssh/config /local/path/file.txt weather-dev:/tmp/
```

---

## Troubleshooting

**"Permission denied (publickey)":**
- Check key exists: `.local/ssh/claude_ratbert`
- Check config: `.local/ssh/config` defines host aliases
- Key permissions (on Linux): `chmod 600 .local/ssh/claude_ratbert`

**Container not responding:**
- Check container is running: `ssh -F .local/ssh/config ratbert "lxc list"`

---

## More info

See [../../reference/weather-skin.md](../../reference/weather-skin.md) for Belchertown architecture.
See [../../reference/clearskies-dev.md](../../reference/clearskies-dev.md) for Clear Skies dev environment.
See [../../reference/CREDENTIALS.md](../../reference/CREDENTIALS.md) for SSH keys, credentials, and host IPs.
