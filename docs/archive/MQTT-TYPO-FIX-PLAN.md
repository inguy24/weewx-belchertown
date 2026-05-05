# MQTT-TYPO-FIX-PLAN — Restore live data on weather.shaneburkhardt.com

**Goal:** restore live data flow from weewx → EMQX → browser by fixing a one-character typo in `/etc/weewx/weewx.conf` on the `weewx` container. Estimated time: 15 minutes.

**Status:** Not Started — ready to execute.

**Owner:** shane (tonight).

---

## Background

Identified during Phase 1 assessment (2026-04-29): `[StdRESTful][[MQTT]]` `server_url` reads `mgtt://` instead of `mqtt://`. The `matthewwall/weewx-mqtt` extension can't parse the bad scheme, so weewx publishes nothing to EMQX. Browser subscribers (the Belchertown live tile) receive no packets. Apache→EMQX→browser side of the chain is wired correctly; only the publisher is broken.

See [WEATHER-EVALUATION-PLAN.md](WEATHER-EVALUATION-PLAN.md) Phase 1 findings for details.

---

## Pre-flight

| # | Step | Command | Expected |
|---|------|---------|----------|
| 1 | Verify the typo is still present | `ssh ratbert "lxc exec weewx -- grep -n 'server_url' /etc/weewx/weewx.conf"` | Output contains `mgtt://...` |
| 2 | Backup weewx.conf | `ssh ratbert "lxc exec weewx -- cp /etc/weewx/weewx.conf /etc/weewx/weewx.conf.bak.\$(date +%Y%m%d-%H%M%S)"` | Backup file created |
| 3 | Confirm EMQX is running on cloud | `ssh ratbert "lxc exec cloud -- systemctl status emqx \|\| pgrep -fa beam.smp"` | EMQX/beam.smp process present |
| 4 | Confirm EMQX has user `weewx` (publisher) | EMQX dashboard at `http://cloud.shaneburkhardt.com:18083` → Authentication → Built-in DB → look for username `weewx`. Or CLI: `ssh ratbert "lxc exec cloud -- emqx ctl admins list"` | User exists |
| 5 | Confirm EMQX has user `weewx-web` (browser subscriber) | Same dashboard | User exists |
| 6 | Note the password for `weewx` user from weewx.conf | (grep server_url line, password is between `weewx:` and `@`) | Have it for later validation |

If any pre-flight check fails, **stop** and resolve before editing.

---

## Fix

| # | Step | Command | Expected |
|---|------|---------|----------|
| 7 | Apply the typo fix | `ssh ratbert "lxc exec weewx -- sed -i 's\|mgtt://\|mqtt://\|g' /etc/weewx/weewx.conf"` | No output (success) |
| 8 | Verify the edit | `ssh ratbert "lxc exec weewx -- grep -n 'server_url' /etc/weewx/weewx.conf"` | Output now contains `mqtt://...`, no `mgtt://` anywhere |
| 9 | Restart weewx | `ssh ratbert "lxc exec weewx -- systemctl restart weewx"` | No errors |
| 10 | Tail weewx logs for MQTT publish activity | `ssh ratbert "lxc exec weewx -- journalctl -u weewx -f -n 50"` | After ~1 minute see lines like `restx: MQTT: published ...` and **no** `restx: MQTT: connection refused` or `cannot parse` errors |

If logs show connection-refused: validate the password against EMQX and check EMQX listener config (`/etc/emqx/emqx.conf` `listener.tcp.external = 0.0.0.0:1883`).

---

## Validation

| # | Step | How to check | Expected |
|---|------|-------------|----------|
| 11 | EMQX sees the publisher | EMQX dashboard → Clients → look for client `weewx` connected | Connected, with recent activity |
| 12 | EMQX sees the topic with messages | Dashboard → Topics → look for `weewx/loop` (or whatever topic the extension uses) | Topic exists, message count climbing |
| 13 | Browser receives live updates | Open https://weather.shaneburkhardt.com in a private window. Open DevTools → Network → WS tab. Watch for `wss://weather.shaneburkhardt.com/mqtt` | Frames arriving every ~2.5s with sensor data |
| 14 | Live tile updates visually | Watch the temperature on the home page for ~1 minute | Value updates without page refresh |

---

## Rollback (if anything breaks)

```
ssh ratbert "lxc exec weewx -- ls -la /etc/weewx/weewx.conf.bak.*"
ssh ratbert "lxc exec weewx -- cp /etc/weewx/weewx.conf.bak.<TIMESTAMP> /etc/weewx/weewx.conf"
ssh ratbert "lxc exec weewx -- systemctl restart weewx"
```

The `.bak` from step 2 is the safety net.

---

## Post-fix housekeeping

- [ ] Update [WEATHER-EVALUATION-PLAN.md](WEATHER-EVALUATION-PLAN.md) "Quick fix: MQTT typo" tasks to ✅ Done
- [ ] Update [reference/weather-skin.md](../../reference/weather-skin.md) — remove the `🚨 KNOWN BUG` callout, replace with a note that the typo was fixed on YYYY-MM-DD
- [ ] Move this plan to `docs/archive/` once validated

---

## Out of scope

- Replacing EMQX with a lighter solution → that's a Phase 4 conversation in the main plan, not tonight.
- Touching the Belchertown skin's MQTT client config → already correct, don't change.
- Anything else. This is a one-character fix.
