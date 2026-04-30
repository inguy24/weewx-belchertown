# AQI-CENTRALIZATION-PLAN — Route AQI through weewx as the single hub

**Status:** ⬜ Not started | Drafted: 2026-04-29 | Owner: shane

---

## Goal in one sentence

Make the in-house `weewx-airvisual` extension the **only** thing calling IQAir; have the Belchertown website and (eventually) Home Assistant read AQI from the weewx archive database instead of each making their own API calls. As a side benefit, gain historical AQI graphs on the website.

---

## Why this is needed

**Current state (verified 2026-04-29):**

- The Belchertown skin displays AQI by making a **live HTTP call to Aeris** (`api.aerisapi.com/airquality/closest`) from inside `bin/user/belchertown.py` line 1207. Aeris returns its own bucketized 1–6 scale, so the page shows nonsense like "AQI: 2 (good)" instead of a meaningful EPA US AQI value.
- A separate in-house data-service extension, **`AirVisualService`** (repo: https://github.com/inguy24/weewx-airvisual), is *configured* to fetch AirVisual every 10 minutes and write `aqi`, `main_pollutant`, `aqi_level` columns into the weewx `archive` table. But the API key in `weewx.conf` was stale (HTTP 403 on every call), so those columns have been NULL for an unknown duration.
- **Home Assistant is hitting IQAir directly** — ~7000 of 10,000 monthly free-tier calls used. Two systems calling the same API for the same data is wasteful.

The right architecture is one fetcher (the weewx extension) and many readers. Once weewx persists AirVisual data in the archive, the website can read it via the database (and gets free historical data for graphs), and HA can later be reconfigured to query weewx instead of IQAir.

---

## Background — current architecture

For a full map of containers, paths, sync mechanism, and credentials see [docs/reference/SERVER-INVENTORY.md](../reference/SERVER-INVENTORY.md). For the per-file repo-vs-server diff see [docs/reference/REPO-VS-SERVER-DIFF-2026-04-29.md](../reference/REPO-VS-SERVER-DIFF-2026-04-29.md). For correctness facts see [reference/weather-skin.md](../../reference/weather-skin.md).

Key facts relevant to this plan:

- **WeeWX 5.3.1** runs on the `weewx` LXD container (`192.168.2.121` on Ratbert).
- **Skin source:** `/etc/weewx/skins/Belchertown/` (NOT `/home/weewx/...`).
- **Extension code:** `/etc/weewx/bin/user/airvisual.py` and `/etc/weewx/bin/user/belchertown.py` (both 252KB+).
- **Database:** MariaDB on the weewx container, db `weewx`, table `archive`.
- **Static-site sync:** `/var/www/weewx/` is an LXD shared disk between the `weewx` container (writer) and the `cloud` container (Apache reader). Output regenerates on every weewx archive interval; visible immediately at https://weather.shaneburkhardt.com.
- **Credentials:** see [reference/CREDENTIALS.md](../../reference/CREDENTIALS.md) (gitignored). The new working IQAir key was added there during the 2026-04-29 evaluation. Old key value `fa45aacf-6451-4b6d-969f-431bc989166c` is dead and should never come back.

### How AQI flows today

```
Browser ── HTTPS ──► Apache (cloud:443) ──► /var/www/weewx/index.html
                                                 ▲ (rendered with $aqi=2 from Aeris)
                                                 │
weewx (5.3.1) ── on archive event:
  1. forecast.json fetch loop (every ~hour) hits Aeris airquality, parses,
     stores in module globals aqi/aqi_category/aqi_time/aqi_location
  2. AirVisualService (background thread) hits AirVisual every 10 min, parses,
     writes record['aqi'], record['main_pollutant'], record['aqi_level']
     to next archive row → MariaDB archive table

Home Assistant ── separate IQAir polling (~7000/10000 monthly calls used)
```

### How AQI should flow after this plan

```
Browser ── HTTPS ──► Apache ──► /var/www/weewx/index.html
                                    ▲ ($aqi from latest archive row)
                                    │
weewx ── on archive event:
  AirVisualService fetches AirVisual every 10 min,
  writes aqi, main_pollutant, aqi_level, aqi_location to next archive row.

Belchertown skin ── reads latest archive row at template-render time
                   ── renders graphs from archive history

Home Assistant ── (future, out of scope) reads from weewx
                   instead of polling IQAir directly
```

---

## Repos involved (multi-root VS Code workspace)

Two GitHub repos owned by user `inguy24`:

| Repo | Local path | Role |
|---|---|---|
| https://github.com/inguy24/weewx-belchertown | `c:\CODE\weather-belchertown\` | Skin (display layer); already has framework docs |
| https://github.com/inguy24/weewx-airvisual | `c:\CODE\weewx-airvisual\` (NOT YET CLONED — Phase 0 task) | Extension (data layer); writes to `archive` table |

**One-time workspace setup:**

```bash
git clone https://github.com/inguy24/weewx-airvisual c:/CODE/weewx-airvisual
```

In VS Code: **File → Add Folder to Workspace** → select `c:\CODE\weewx-airvisual` → **File → Save Workspace As** → `c:\CODE\weewx.code-workspace`. From then on, open that workspace file; both repos visible in the explorer with independent git status.

---

## Pre-flight checks (do these BEFORE starting Phase 1)

1. **Verify the working IQAir key is documented** in `reference/CREDENTIALS.md`. The old key `fa45aacf-…` is dead.
2. **Verify the MQTT typo fix from 2026-04-29 is still in place.** `grep "server_url" /etc/weewx/weewx.conf` on the weewx container should show `mqtt://` (not `mgtt://`). If reverted, fix first.
3. **Verify weewx is running.** `ssh ratbert "lxc exec weewx -- systemctl is-active weewx"` returns `active`.
4. **Verify the `weewx-airvisual` GitHub repo is current.** Compare its `bin/user/airvisual.py` against `/etc/weewx/bin/user/airvisual.py` on the server. If they diverge, capture the server version into a feature branch on the repo BEFORE starting Phase 2 (same pattern we used for the Belchertown skin drift in 2026-04-29).
5. **Open the multi-root workspace** so edits to both repos are in one window.

---

## Phase 1 — Verify the extension is healthy after key swap

Goal: confirm `AirVisualService` actually fetches and persists data when given a working API key. **No code changes in this phase.**

| # | Action | Verify |
|---|---|---|
| 1.1 | `ssh ratbert "lxc exec weewx -- systemctl stop weewx"` | service is `inactive` |
| 1.2 | `ssh ratbert "lxc exec weewx -- cp /etc/weewx/weewx.conf /etc/weewx/weewx.conf.bak-$(date +%F)-airvisual"` | backup file exists |
| 1.3 | Substitute the old key with the working one (use `sed -i` with the literal old → new value, both kept in `reference/CREDENTIALS.md`). Verify only the `[AirVisualService]` section's `api_key` line changed. | `grep "api_key" /etc/weewx/weewx.conf` shows the new value |
| 1.4 | `ssh ratbert "lxc exec weewx -- systemctl start weewx"`; wait 15s | service is `active` |
| 1.5 | `journalctl -u weewx -n 100 \| grep -i airvisual` | shows `AirVisual service configured: lat=33.65683, lon=-117.98267` and within 10 min, a successful `Collected air quality data: AQI=…, pollutant=…, level=…` log line |
| 1.6 | Check schema: `SHOW COLUMNS FROM archive WHERE Field IN ('aqi','main_pollutant','aqi_level');` | returns 3 rows |
| 1.7 | Wait one archive interval (5 min after 1.5 success), then `SELECT dateTime, aqi, main_pollutant, aqi_level FROM archive ORDER BY dateTime DESC LIMIT 3;` | recent rows have non-NULL values matching what AirVisual is returning |

**Decision gate:** if 1.6 fails (schema columns missing), the previous extension install did not migrate the schema. Fix by running `weectl database add-column <field> [--type REAL]` for each missing column, restart weewx, retry 1.7. If 1.7 still NULL after the schema is correct, dig into logs before starting Phase 2.

---

## Phase 2 — Enhance the AirVisual extension to also write `aqi_location`

The website displays a city name under the AQI ("Huntington Beach"). The extension parses the city from the API response (line 413 of `airvisual.py`) but currently only logs it for debug. Add it as a 4th persisted field.

### Files to modify in `weewx-airvisual` repo

**1. `install.py`** — add to schema and unit registration:

In `__init__`, extend `self.required_fields`:
```python
self.required_fields = {
    'aqi': 'REAL',
    'main_pollutant': 'TEXT',
    'aqi_level': 'TEXT',
    'aqi_location': 'TEXT',
}
```

In `_setup_unit_system`, add:
```python
weewx.units.obs_group_dict['aqi_location'] = 'group_count'
```

**2. `bin/user/airvisual.py`** — promote city name out of the debug-only block:

In `_parse_api_response` (around line 411), replace:
```python
# Log location info for debugging (only on success)
if self.config['log_success']:
    city = current_data.get('city', 'Unknown')
    state = current_data.get('state', 'Unknown')
    country = current_data.get('country', 'Unknown')
    log.debug(f"Data from: {city}, {state}, {country}")
```
with:
```python
# Capture location regardless of log_success
city = current_data.get('city', '')
```
…and add it to the returned dict (around line 404):
```python
air_quality_data = {
    'aqi': int(aqius),
    'main_pollutant': convert_pollutant_code(mainus),
    'aqi_level': convert_aqi_to_level(aqius),
    'aqi_location': city,
    'timestamp': time.time()
}
```

In `new_archive_record` (around line 457), inject the new field in **all three branches** (success, too-old, no-data) alongside the existing three:
```python
event.record['aqi_location'] = air_data.get('aqi_location')   # success branch
event.record['aqi_location'] = None                           # too-old branch
event.record['aqi_location'] = None                           # no-data and exception branches
```

**3. `CHANGELOG.md`** — add a `## 1.1.0` section documenting `aqi_location` field.

**4. Bump `EXTENSION_VERSION = '1.1.0'`** in `install.py` line 23 and `VERSION = "1.1.0"` in `airvisual.py` line ~38.

### Server-side migration (one-time)

```bash
ssh ratbert "lxc exec weewx -- weectl database add-column aqi_location --config /etc/weewx/weewx.conf -y"
```

(No `--type` flag → defaults to TEXT-equivalent string column.)

### Deploy to server

```bash
ssh ratbert "lxc exec weewx -- systemctl stop weewx"
ssh ratbert "lxc exec weewx -- cp /etc/weewx/bin/user/airvisual.py /etc/weewx/bin/user/airvisual.py.bak-pre-1.1.0"
# Copy modified airvisual.py from c:\CODE\weewx-airvisual\bin\user\airvisual.py to server
# (use scp or `lxc file push` or pipe via tar)
ssh ratbert "lxc exec weewx -- systemctl start weewx"
```

Then tail logs for 10–15 minutes; confirm new archive rows have `aqi_location` populated:

```sql
SELECT dateTime, aqi, aqi_level, aqi_location FROM archive ORDER BY dateTime DESC LIMIT 3;
```

### Rollback for Phase 2

```bash
ssh ratbert "lxc exec weewx -- bash -c 'systemctl stop weewx && cp /etc/weewx/bin/user/airvisual.py.bak-pre-1.1.0 /etc/weewx/bin/user/airvisual.py && systemctl start weewx'"
```

The `aqi_location` column in DB stays — it's harmless if not written to.

---

## Phase 3 — Modify the Belchertown skin to read AQI from the database

Goal: stop calling Aeris for AQI; read the latest archive row instead. Templates don't change — we keep the same global names (`$aqi`, `$aqi_category`, `$aqi_location`, `$aqi_time`).

Work on a new branch off `capture-server-drift-2026-04-29` in the `weather-belchertown` repo:

```bash
git checkout capture-server-drift-2026-04-29
git checkout -b feature/aqi-from-archive
```

### Files to modify in `weather-belchertown` repo

**1. `bin/user/belchertown.py`** — three localized changes:

**a) Remove Aeris airquality URL construction** (around line 1207):
```python
# DELETE these lines:
aqi_url = (
    "https://api.aerisapi.com/airquality/closest?p=%s,%s&format=json&radius=50mi&limit=1&client_id=%s&client_secret=%s"
    % (latitude, longitude, forecast_api_id, forecast_api_secret)
)
```

**b) Remove the aqi key from the forecast.json fetch/cache structure** (around lines 1314-1326 and 1357-1368). The skin caches forecast data in `$html_root/json/forecast.json`; remove the `"aqi"` entries from both write blocks. Also delete the corresponding HTTP fetch of `aqi_url` and any `aqi_page` parsing.

**c) Replace the parse block** (around lines 1429-1468) with a database read. Insert this just before the existing `aqi_category`-to-label-key mapping at line 1455:

```python
try:
    manager = db_lookup()
    last = manager.getSql(
        "SELECT dateTime, aqi, aqi_level, aqi_location "
        "FROM archive WHERE aqi IS NOT NULL "
        "ORDER BY dateTime DESC LIMIT 1"
    )
    if last:
        aqi = last[1]
        # aqi_level comes from extension as title-case ("Good"); skin's
        # label_dict expects lowercase keys (e.g., aqi_good)
        aqi_category = (last[2] or "").lower()
        aqi_time = last[0]
        aqi_location = last[3] or ""
    else:
        aqi = ""
        aqi_category = ""
        aqi_time = 0
        aqi_location = ""
except Exception as error:
    logerr(f"Belchertown: error reading AQI from archive: {error}")
    aqi = ""
    aqi_category = ""
    aqi_time = 0
    aqi_location = ""
```

The existing label-mapping block at lines 1455-1468 (`if aqi_category == "good":` etc.) continues to work unchanged.

**2. `skins/Belchertown/graphs.conf`** — add an AQI graph group:

Pattern-match an existing simple chart group in the file. Add something like:

```ini
[airquality]
    title = "Air Quality Index"
    [[chart1]]
        title = "AQI - 24 Hours"
        time_length = 86400
        [[[aqi]]]
            name = AQI
    [[chart2]]
        title = "AQI - 7 Days"
        time_length = 604800
        [[[aqi]]]
            name = AQI
```

(Verify exact syntax against neighboring chart groups in the same file — Belchertown's `graphs.conf` has its own conventions. Use a 24h chart and a 7d chart as the minimum.)

**3. Verify no template changes are needed.** `skins/Belchertown/index.html.tmpl` already uses `$aqi`, `$aqi_category`, `$aqi_location` — those globals will now be sourced from the DB, but the template doesn't care. `aqi_enabled = 1` in `[Belchertown][[Extras]]` of weewx.conf continues to gate the AQI block.

### Deploy to server

```bash
# backup the live skin and python helper
ssh ratbert "lxc exec weewx -- bash -c '
cp -r /etc/weewx/skins/Belchertown /etc/weewx/skins/Belchertown.bak-pre-aqi-rewire
cp /etc/weewx/bin/user/belchertown.py /etc/weewx/bin/user/belchertown.py.bak-pre-aqi-rewire
'"

# push the modified files (use lxc file push, or scp + lxc file push, or tar pipe)
# For each modified file, replace its server counterpart.

# delete forecast.json cache so the new code is exercised on next render
ssh ratbert "lxc exec weewx -- rm -f /var/www/weewx/json/forecast.json"

# restart weewx to pick up belchertown.py changes
ssh ratbert "lxc exec weewx -- systemctl restart weewx"
```

Refresh https://weather.shaneburkhardt.com after ~30 seconds. Verify the AQI block shows AirVisual's number (e.g. 22) and category text. Open `/graphs/` page; confirm the new AQI chart group renders.

### Rollback for Phase 3

```bash
ssh ratbert "lxc exec weewx -- bash -c '
systemctl stop weewx
rm -rf /etc/weewx/skins/Belchertown
mv /etc/weewx/skins/Belchertown.bak-pre-aqi-rewire /etc/weewx/skins/Belchertown
cp /etc/weewx/bin/user/belchertown.py.bak-pre-aqi-rewire /etc/weewx/bin/user/belchertown.py
systemctl start weewx
'"
```

Total rollback time: <30 seconds.

---

## Phase 4 — End-to-end verification

| Check | Expected result |
|---|---|
| `journalctl -u weewx --since "5 minutes ago" \| grep -i airvisual` | Successful `Collected air quality data` entry; no errors |
| `SELECT dateTime, aqi, aqi_level, aqi_location FROM archive ORDER BY dateTime DESC LIMIT 5;` | Latest 5 rows have non-NULL values matching AirVisual's response |
| https://weather.shaneburkhardt.com — current AQI block | Shows AirVisual's value (e.g. 22 with category "good", location "Huntington Beach"). NOT Aeris's "2 (good)". |
| https://weather.shaneburkhardt.com/graphs/ | New AQI chart group visible; 24h trend renders |
| Aeris API quota | Drops by ~24 calls/day (1/hr) since the airquality endpoint is no longer called |
| MQTT subscribers (browser real-time stream) | Unchanged — we did not touch loop-packet plumbing |

If any check fails, follow the Phase 3 rollback first (skin reverts to Aeris call), then Phase 2 rollback (extension reverts to 1.0.0 schema). API key swap from Phase 1 stays — it doesn't hurt anything to have a working key even if the rest is rolled back.

---

## Critical files reference

| File | Repo | Modified in phase |
|---|---|---|
| `bin/user/airvisual.py` | `weewx-airvisual` | Phase 2 |
| `install.py` | `weewx-airvisual` | Phase 2 |
| `CHANGELOG.md` | `weewx-airvisual` | Phase 2 |
| `bin/user/belchertown.py` | `weather-belchertown` | Phase 3 |
| `skins/Belchertown/graphs.conf` | `weather-belchertown` | Phase 3 |
| `/etc/weewx/weewx.conf` | (server, not in any repo) | Phase 1 (key swap only) |
| `/etc/weewx/bin/user/airvisual.py` | (server) | Phase 2 deploy target |
| `/etc/weewx/bin/user/belchertown.py` | (server) | Phase 3 deploy target |
| `/etc/weewx/skins/Belchertown/` | (server) | Phase 3 deploy target |
| `archive` table in MariaDB `weewx` db | (server) | Phase 2 schema add: `aqi_location` |

---

## Out of scope (future work)

- **Home Assistant migration to read from weewx.** Two paths to evaluate later:
  - HA's `mysql:` integration querying MariaDB directly (simple, but couples HA to weewx schema).
  - Extending `airvisual.py` to also bind to `NEW_LOOP_PACKET` and inject AQI into MQTT loop frames; HA subscribes to the same MQTT broker the Belchertown skin already uses. (Requires schema change to ensure aqi propagates through loop packets.)
- **Cleaning up the dead `forecast_provider = "aeris"` config.** The setting is referenced by no code in either upstream Belchertown or this fork. Harmless. Can be deleted from `[Extras]` whenever convenient.
- **Rebuilding the AirVisual extension `.zip` distribution** via `scripts/create_package.sh` after the 1.1.0 changes. Needed only if anyone ever runs `weectl extension install` again — for this deployment we hand-copy the `airvisual.py` file.
- **Capturing `airvisual.py` into the `weather-belchertown` repo.** Not doing it; the extension lives in its own repo (`weewx-airvisual`).
- **Aeris airquality call cleanup in `belchertown.py`.** This plan removes only the call. The block of code that maps Aeris category strings to skin label-dict keys (lines ~1455-1468) is reused for the new AirVisual-sourced category. If we ever want to fully purge Aeris references from the file, that's a later cleanup.

---

## Decision log

- **2026-04-29:** Plan drafted after evaluation phase identified that (a) Aeris's AQI scale isn't EPA US AQI, (b) the AirVisual extension is in-house and was returning 403 due to a stale key, (c) HA is making its own AirVisual calls, and (d) the user wants centralization through weewx. Architecture chosen: extension is single fetcher, archive DB is single source of truth, skin/HA are readers.
- **Read-from-DB chosen over re-fetch-from-API in skin.** Reason: avoids duplicate calls (API quota), enables historical graphs, aligns with the centralization goal.
- **`aqi_location` added as a new column** rather than derived/looked-up at render time. Reason: simpler than reverse-geocoding from station coords; the API already returns it; one extra TEXT column is cheap.
- **No `aqi_provider` switch.** Reason: with this design, "provider" is always the AirVisualService extension — no need for a runtime selector. If a future Aeris fallback is ever wanted, that's a small add (just don't add it preemptively).
