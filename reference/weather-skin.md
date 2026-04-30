# reference/weather-skin.md — Weather Site Architecture & Belchertown Configuration

Load alongside [rules/weather-skin.md](../rules/weather-skin.md) when working on the weather site or skin customization.

## Current Weather Site

- **Public hostname:** `weather.shaneburkhardt.com`
- **Container:** `cloud` (on Ratbert LXD host)
- **Container IP:** 192.168.7.2
- **Reverse proxy:** nginx-proxy-manager (NPM) on Ratbert
- **HTTPS:** Let's Encrypt cert via certbot (issued 2026-04-25, shared with `cloud.shaneburkhardt.com`)
- **Access:** `ssh ratbert "lxc exec cloud -- <command>"`

## Weewx engine

- **Host container:** `weewx` on Ratbert
- **Container IP:** 192.168.2.121
- **Database:** MariaDB 10.11 (shared with Kodi)
- **Database host:** Same weewx container (localhost or 192.168.2.121 from remote)
- **Data tables:** `archive` (historical data), `current_observation` (live conditions)
- **Weewx version:** [check docs/reference/WEEWX-VERSION.md or run `weewxd --version` in container]

### Database credentials

See `reference/CREDENTIALS.md` for:
- MariaDB root password
- weewx database user & password
- weewx application user

### Skin location (weewx container)

- **Active skin:** `/home/weewx/skins/Belchertown/`
- **Skin config:** `/home/weewx/skins/Belchertown/skin.conf`
- **Templates:** `/home/weewx/skins/Belchertown/html/`
- **Static assets:** `/home/weewx/skins/Belchertown/css/`, `/home/weewx/skins/Belchertown/js/`
- **Generated output:** Published to web root (exact path: check weewx.conf station section)

### Weewx main config

- **Config file:** `/etc/weewx/weewx.conf` on weewx container
- **Key sections:**
  - `[Station]` — location, latitude, longitude, altitude
  - `[Database]` — MariaDB connection (database_type, host, user, password)
  - `[Engine]` → `[[Services]]` — data publishing, upload intervals
  - `[Belchertown]` — skin-specific settings (colors, radar tiles, alerts integration)

## Current Belchertown Fork

- **GitHub repo:** https://github.com/inguy24/weewx-belchertown
- **Fork from:** https://github.com/poblabs/weewx-belchertown (upstream)
- **Local workspace:** `c:\CODE\weather-belchertown\` (this directory)

### Belchertown features (current)

- **Current conditions display:** Temperature, humidity, wind, pressure
- **Historical graphs:** 24h, 7d, 30d trends (requires plotlib integration)
- **Forecast integration:** [Check skin.conf for weather API keys in use]
- **Responsive design:** Mobile-friendly layout
- **Customizable gauges:** Wind speed, temperature, barometer widgets

### Belchertown configuration

In `/etc/weewx/weewx.conf` (or skin.conf):
- Radar tile provider (e.g., Rainviewer API key)
- Weather alerts integration (e.g., NWS API endpoint)
- Chart colors and label text
- Logo and branding images
- Station name and description

## Alternative skins (candidates for evaluation)

| Skin | Repository | Notes |
|------|------------|-------|
| **Seasons** | https://github.com/weewx/weewx-seasons | Official, mature, simpler than Belchertown |
| **Beautiful Dashboard** | https://github.com/weewx-user/weewx-beautiful-dashboard | Modern, responsive, actively maintained |
| **Responsive** | https://github.com/weewx/weewx-responsive | Older but lightweight |
| **Saratoga** | https://github.com/ktownsend-personal/Saratoga-Weather | Complex, feature-rich, requires PHP |

**Evaluation task:** Clone each candidate, test locally, document findings in `docs/planning/WEATHER-EVALUATION-PLAN.md`.

## Accessing the weather site for testing

### From DILBERT

```bash
# SSH into weewx container
ssh ratbert "lxc exec weewx -- bash"

# Or run commands directly
ssh ratbert "lxc exec weewx -- systemctl status weewx"

# View generated output
ssh ratbert "lxc exec cloud -- ls -la /var/www/html/"

# Check live data
ssh ratbert "lxc exec weewx -- curl http://localhost:8000/api/current-conditions"
```

### Database access

```bash
# From DILBERT, query weewx database
ssh ratbert "lxc exec weewx -- mysql -u weewx -p<password> weewx -e 'SELECT * FROM archive LIMIT 5;'"

# Or get a shell into weewx and use mysql CLI
ssh ratbert "lxc exec weewx -- mysql -u weewx -p weewx"
```

## Staging / development paths

Before modifying production skin:
1. Clone the Belchertown repo to a local `Belchertown-dev` directory on the weewx container
2. Point weewx config to `Belchertown-dev` temporarily
3. Test output in a dev location (e.g., `/tmp/weewx-output/`)
4. Once verified, switch production config back and restart weewx

**Weewx restart:**
```bash
ssh ratbert "lxc exec weewx -- systemctl restart weewx"
```

## Deployment checklist

When ready to deploy a skin update to production:

- [ ] Tested on dev path with live weewx data
- [ ] Changes documented in `docs/CHANGELOG.md`
- [ ] CSS/JS minified (if applicable)
- [ ] Mobile layout verified (Chrome DevTools)
- [ ] HTTPS load tested (check for mixed-content warnings)
- [ ] Backup of current skin created (`cp -r Belchertown Belchertown.backup.YYYY-MM-DD`)
- [ ] `weewx.conf` updated (if new config keys added)
- [ ] Weewx restarted and logs checked for errors
- [ ] Public weather.shaneburkhardt.com verifies in browser

## Known issues & workarounds

[To be filled as evaluation progresses]

- **Issue:** [description]
  - **Workaround:** [if applicable]
  - **Status:** [Open / In Progress / Resolved]
