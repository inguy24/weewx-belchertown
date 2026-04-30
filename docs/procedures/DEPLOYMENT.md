# DEPLOYMENT.md — Promoting Changes to Production

## Promotion workflow

When a skin change has been tested on the dev path and approved via PR:

### Step 1: Backup current production skin

```bash
ssh ratbert "lxc exec weewx -- bash"

# Inside weewx container:
cd /home/weewx/skins/
cp -r Belchertown Belchertown.backup.2026-04-29  # Use current date
```

### Step 2: Deploy new skin

Option A — Replace in place (if changes are in production Belchertown):

```bash
# Copy tested changes from git to production skin
# (Assumes you've cloned the git repo to the weewx container or DILBERT)

cp -r ~/belchertown-repo/Belchertown/* /home/weewx/skins/Belchertown/
```

Option B — Switch if the whole skin was swapped:

```bash
# If migrating to a different skin (e.g., Seasons):
cd /home/weewx/skins/
cp -r NewSkin-dev/* NewSkin/  # Or rename if moving skins entirely
```

### Step 3: Update weewx.conf (if needed)

```bash
nano /etc/weewx/weewx.conf

# Ensure the [Belchertown] or [NewSkin] section points to the right location
# and any new config keys are set
```

### Step 4: Restart weewx

```bash
systemctl restart weewx
```

### Step 5: Verify production output

From DILBERT:

```bash
curl https://weather.shaneburkhardt.com/ | head -30
```

Or check from inside cloud container:

```bash
ssh ratbert "lxc exec cloud -- curl http://localhost/weather/ | head -30"
```

**Checks:**
- [ ] Page loads without 5xx errors
- [ ] Current conditions are visible
- [ ] No JavaScript errors in logs: `ssh ratbert "lxc exec cloud -- tail /var/log/apache2/error.log"`
- [ ] Page rendered in < 2 seconds

### Step 6: Monitor for issues

- Watch weewx logs for 30 minutes: `ssh ratbert "lxc exec weewx -- tail -f /var/log/weewx/weewx.log"`
- Check Apache errors: `ssh ratbert "lxc exec cloud -- tail -f /var/log/apache2/error.log"`
- Test from a phone / different network if possible

### Step 7: Commit & document

Back on DILBERT, update docs:

```bash
# Update CHANGELOG.md
# Add entry: "| 2026-04-29 | Feature | weewx-belchertown | Deploy updated skin — [feature description]"

# Mark task complete in planning doc
# Update docs/planning/WEATHER-EVALUATION-PLAN.md

git add docs/CHANGELOG.md docs/planning/WEATHER-EVALUATION-PLAN.md
git commit -m "Deploy skin update: <description>"
git push origin main
```

## Rollback procedure (if something breaks)

If production breaks after deployment:

### Quick rollback (< 15 min)

```bash
ssh ratbert "lxc exec weewx -- bash"

# Inside weewx container:
cd /home/weewx/skins/
rm -rf Belchertown
cp -r Belchertown.backup.2026-04-29 Belchertown

# Restart weewx
systemctl restart weewx
```

Then investigate the broken change (ask for help if needed).

### If rollback doesn't work

```bash
# Restore from Nextcloud or git if the backup is corrupted:
cd /home/weewx/skins/
git clone https://github.com/inguy24/weewx-belchertown.git Belchertown-recovery
cp -r Belchertown-recovery/Belchertown/* Belchertown/

systemctl restart weewx
```

---

## Deployment checklist

- [ ] Changes tested on dev path with live weewx data
- [ ] CSS/JS minified (if changes include assets)
- [ ] Mobile layout verified (DevTools 375px width)
- [ ] Backup created: `Belchertown.backup.YYYY-MM-DD`
- [ ] weewx.conf updated (if new keys added)
- [ ] Weewx restarted successfully
- [ ] Production output verified (no 500 errors)
- [ ] Apache error log checked
- [ ] CHANGELOG.md updated
- [ ] Planning doc marked complete
- [ ] Monitoring for 30+ minutes (check logs)

---

See [CONTAINER-ACCESS.md](CONTAINER-ACCESS.md) and [LOCAL-SKIN-TESTING.md](LOCAL-SKIN-TESTING.md) for related procedures.
