# Install ClearSkiesLoopRelay weewx extension

Step-by-step procedure for installing the ClearSkiesLoopRelay weewx extension on the weewx host and verifying end-to-end loop packet flow.

**Target host:** weewx LXD container (`weewx.shaneburkhardt.com`) — SSH: `ssh weewx`.

**Prerequisites:**
- weewx 5.x installed and running
- Clear Skies API installed (weewx-clearskies-api)
- `clearskies` system user exists (per ADR-061 bare-metal install script)
- `weewx` group exists (created by weewx installer)

---

## 1. Set up groups

The `clearskies` user (API process) needs `weewx` group membership to connect to the socket (0660 `weewx:weewx`).

```bash
sudo usermod -aG weewx clearskies
```

Verify:

```bash
id clearskies
# Should show: groups=... weewx-ro, weewx
```

Note: The group change takes effect on the next login/service restart. If the API is already running, restart it after step 5.

## 2. Create the socket directory

```bash
sudo mkdir -p /var/run/weewx-clearskies
sudo chown clearskies:weewx /var/run/weewx-clearskies
sudo chmod 770 /var/run/weewx-clearskies
```

Verify:

```bash
stat /var/run/weewx-clearskies
# Should show: Access: (0770/drwxrwx---) Uid: (clearskies) Gid: (weewx)
```

## 3. Create tmpfiles.d entry (boot persistence)

`/var/run` is a tmpfs on most systems — the directory is lost on reboot. Create a tmpfiles.d entry:

```bash
sudo tee /etc/tmpfiles.d/weewx-clearskies.conf <<'EOF'
d /var/run/weewx-clearskies 0770 clearskies weewx -
EOF
```

Verify the entry is valid:

```bash
sudo systemd-tmpfiles --create /etc/tmpfiles.d/weewx-clearskies.conf
ls -la /var/run/weewx-clearskies/
```

## 4. Install the extension

Clone or copy the extension repo to the weewx host, then install:

```bash
# Option A: Clone from GitHub
cd /tmp
git clone https://github.com/inguy24/weewx-clearskies-extension.git
sudo weectl extension install /tmp/weewx-clearskies-extension

# Option B: Copy from local machine
# scp -r /path/to/weewx-clearskies-extension weewx:/tmp/
# sudo weectl extension install /tmp/weewx-clearskies-extension
```

Verify installation:

```bash
weectl extension list | grep clearskies
# Should show: clearskies_relay

grep -A5 'ClearSkiesLoopRelay' /etc/weewx/weewx.conf
# Should show [ClearSkiesLoopRelay] section with socket_path
```

## 5. Verify weewx.conf alignment with API config

The socket path must match between the extension and the API.

Extension side (`weewx.conf`):

```ini
[ClearSkiesLoopRelay]
    socket_path = /var/run/weewx-clearskies/loop.sock
```

API side (`/etc/weewx-clearskies/api.conf`):

```ini
[input]
    mode = direct

[input.direct]
    socket_path = /var/run/weewx-clearskies/loop.sock
```

If the paths differ, update one to match the other. The default `/var/run/weewx-clearskies/loop.sock` is correct for both.

## 6. Restart weewx

```bash
sudo systemctl restart weewx
sleep 10
```

Verify socket created with correct permissions:

```bash
ls -la /var/run/weewx-clearskies/loop.sock
# Should show: srw-rw---- 1 weewx weewx ... loop.sock

stat /var/run/weewx-clearskies/loop.sock
# Access: (0660/srw-rw----) Uid: (weewx) Gid: (weewx)
```

Verify weewx is running and extension started:

```bash
systemctl status weewx
journalctl -u weewx --since "2 min ago" | grep -i clearskies
# Should show: "ClearSkiesLoopRelay listening on /var/run/weewx-clearskies/loop.sock (mode=0660, group=weewx)"
```

## 7. Restart API and verify connection

```bash
sudo systemctl restart weewx-clearskies-api
sleep 120  # API startup takes ~2 minutes (cache warm)
```

Verify API connected to socket:

```bash
journalctl -u weewx-clearskies-api --since "3 min ago" | grep -i "connected to weewx relay"
# Should show: "Connected to weewx relay socket /var/run/weewx-clearskies/loop.sock"
```

## 8. Verify end-to-end SSE

```bash
curl -N -H "Accept: text/event-stream" https://localhost:8765/sse --insecure 2>/dev/null | head -20
# Should show SSE events with type: "loop" containing weather data fields
# Events arrive every ~2.5 seconds (weewx loop interval)
```

Press Ctrl-C to stop curl after confirming events flow.

---

## Troubleshooting

### Permission denied on socket

**Symptom:** API logs show `Permission denied` connecting to the socket.

**Fix:** Verify `clearskies` is in the `weewx` group:

```bash
id clearskies | grep weewx
```

If not present: `sudo usermod -aG weewx clearskies`, then restart the API.

### Socket not found

**Symptom:** API logs show `Relay socket /var/run/weewx-clearskies/loop.sock not found`.

**Fix:** Check weewx is running and the extension started:

```bash
systemctl status weewx
journalctl -u weewx --since "5 min ago" | grep clearskies
```

If the extension logged a startup failure, check the error message — common causes: socket directory doesn't exist (run step 2), directory permissions wrong (run step 2 again).

### Socket directory missing after reboot

**Symptom:** `/var/run/weewx-clearskies/` doesn't exist after reboot.

**Fix:** Verify the tmpfiles.d entry exists (step 3):

```bash
cat /etc/tmpfiles.d/weewx-clearskies.conf
sudo systemd-tmpfiles --create /etc/tmpfiles.d/weewx-clearskies.conf
```

### weewx won't start

**Symptom:** weewx service fails to start after extension install.

**Check:** The extension is designed to degrade gracefully — it should NOT prevent weewx from starting. If weewx fails to start:

```bash
journalctl -u weewx --since "2 min ago" | tail -50
```

Look for Python import errors (missing `grp` module — unlikely on Linux) or config parsing errors. The extension logs `ClearSkiesLoopRelay failed to start ... relay is disabled; weewx will continue` if the socket can't be created.

### Group membership not taking effect

**Symptom:** `id clearskies` shows the new group but the API still gets permission denied.

**Fix:** Services pick up group changes on restart:

```bash
sudo systemctl restart weewx-clearskies-api
```

---

## Reference

- Extension repo: `weewx-clearskies-extension`
- ADR-058: Extension architecture (fold realtime into API)
- ADR-061: Filesystem permissions model (socket permissions, group membership)
- Security baseline §3.10: Extension security controls
