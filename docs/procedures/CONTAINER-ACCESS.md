# CONTAINER-ACCESS.md — SSH & Remote Execution Reference

## Quick access to weather infrastructure

### SSH into containers from DILBERT

**Weewx container (weather data engine):**
```bash
ssh ratbert "lxc exec weewx -- bash"
```

**Cloud container (web server):**
```bash
ssh ratbert "lxc exec cloud -- bash"
```

### Common commands (execute without entering shell)

**Check weewx engine status:**
```bash
ssh ratbert "lxc exec weewx -- systemctl status weewx"
```

**View weewx log tail:**
```bash
ssh ratbert "lxc exec weewx -- tail -f /var/log/weewx/weewx.log"
```

**Restart weewx (after config changes):**
```bash
ssh ratbert "lxc exec weewx -- systemctl restart weewx"
```

**Query weewx database:**
```bash
ssh ratbert "lxc exec weewx -- mysql -u weewx -p weewx -e 'SELECT * FROM archive LIMIT 5;'"
```

**Check weather.shaneburkhardt.com web root:**
```bash
ssh ratbert "lxc exec cloud -- ls -la /var/www/html/"
```

**View Apache access log:**
```bash
ssh ratbert "lxc exec cloud -- tail -f /var/log/apache2/access.log"
```

---

## Container locations

| Service | Container | Access | Purpose |
|---------|-----------|--------|---------|
| Weewx engine + DB | `weewx` | `ssh ratbert "lxc exec weewx -- bash"` | Weather data collection, storage, archiving |
| Web server | `cloud` | `ssh ratbert "lxc exec cloud -- bash"` | Nextcloud + weather.shaneburkhardt.com |
| Ratbert host (LXD) | N/A (host) | `ssh ratbert` | Container orchestration, reverse proxy, firewall |

## SSH key setup (if not already configured)

Your SSH config should have an entry for `ratbert`:

```bash
# ~/.ssh/config entry (should already exist)
Host ratbert
    HostName ratbert.shaneburkhardt.com
    User claude
    IdentityFile ~/.ssh/id_ed25519_ratbert
    StrictHostKeyChecking no
```

If `ssh ratbert` doesn't work, verify:
1. Private key exists: `~/.ssh/id_ed25519_ratbert`
2. SSH config entry exists in `~/.ssh/config`
3. Key permissions: `chmod 600 ~/.ssh/id_ed25519_ratbert`

---

## File transfer to containers

Copy files from DILBERT to weewx container:
```bash
scp /local/path/file.txt ratbert:/tmp/
ssh ratbert "lxc file push /tmp/file.txt weewx/home/weewx/"
```

Copy files from weewx container to DILBERT:
```bash
ssh ratbert "lxc file pull weewx/home/weewx/skins/Belchertown/index.html ./index.html"
```

---

## Troubleshooting SSH issues

**"Permission denied (publickey)":**
- Check key permissions: `chmod 600 ~/.ssh/id_ed25519_ratbert`
- Verify key is registered on Ratbert: `ssh ratbert "cat ~/.ssh/authorized_keys"`

**"Connection refused" on `lxc exec`:**
- Verify container is running: `ssh ratbert "lxc list"`
- Check container name spelling: `weewx` not `weather`

**Slow connection:**
- LXD may be busy; try again in a moment
- Check Ratbert host load: `ssh ratbert "uptime"`

---

## More info

See [../reference/weather-skin.md](../reference/weather-skin.md) for full container architecture and details.
