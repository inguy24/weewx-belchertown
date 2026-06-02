#!/usr/bin/env bash
# redeploy-weather-dev.sh — FULL redeploy of Clear Skies onto the weather-dev
# LXD container.
#
# Fired from DILBERT (this workstation) after pushing commits to GitHub.
# Performs, in order:
#   1. git pull --ff-only for all (or one) repo(s)        [delegates to sync-to-weather-dev.sh]
#   2. restart the three systemd services                 (realtime, api, config)
#   3. npm run build in the dashboard repo                 (Vite → dist/)
#   4. rsync built dist/ → web root /var/www/clearskies/   (EXCLUDING the read-only webcam/ mount)
#
# Transport: ssh to the LXD host, then `lxc exec weather-dev`.
#   - service restarts run as root (systemctl)
#   - git pull and npm build run as the `ubuntu` user (owns the repos)
#   - rsync runs as the `ubuntu` user (owns /var/www/clearskies)
#
# Verified weather-dev facts (2026-05-29):
#   - Units:    weewx-clearskies-realtime.service, weewx-clearskies-api.service,
#               weewx-clearskies-config.service  (all loaded/active)
#   - Dashboard repo:  /home/ubuntu/repos/weewx-clearskies-dashboard
#   - Build:    `npm run build` (tsc -b && vite build) → ./dist (default Vite outDir)
#   - Web root: /var/www/clearskies (Caddy `root *`; owned ubuntu:ubuntu 775)
#   - Webcam:   /var/www/clearskies/webcam is a READ-ONLY bind-mount
#               (LXD disk device → host /mnt/weewx/webcam). rsync MUST NOT touch it.
#
# Usage:
#   ./redeploy-weather-dev.sh                  # full redeploy (all repos + restart + build + publish)
#   ./redeploy-weather-dev.sh --skip-pull      # skip the git pull step
#   ./redeploy-weather-dev.sh --no-delete      # rsync without --delete (do not prune stale web-root files)
#
# Failures abort (set -euo pipefail). Each step prints a clear progress marker.

set -euo pipefail

SSH_HOST="ratbert"
LXC_CONTAINER="weather-dev"
CONTAINER_REPO_ROOT="/home/ubuntu/repos"
DASHBOARD_REPO="weewx-clearskies-dashboard"
DASHBOARD_PATH="${CONTAINER_REPO_ROOT}/${DASHBOARD_REPO}"
DIST_DIR="${DASHBOARD_PATH}/dist"
WEB_ROOT="/var/www/clearskies"
SERVICES=(
    "weewx-clearskies-realtime"
    "weewx-clearskies-config"
)
# NOTE: weewx-clearskies-api is NOT restarted here — the API runs on the
# weewx LXD container, not on weather-dev. See docs/procedures/deploy-clearskies.md
# "Deploying API changes to the weewx container" for the correct procedure.
# CRITICAL: the read-only webcam bind-mount lives directly under the web root.
# rsync must NEVER delete or write into it.
WEBCAM_EXCLUDE="webcam/"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

skip_pull="0"
use_delete="1"
for arg in "$@"; do
    case "$arg" in
        --skip-pull) skip_pull="1" ;;
        --no-delete) use_delete="0" ;;
        *)
            echo "Unknown argument: '${arg}'" >&2
            echo "Usage: $0 [--skip-pull] [--no-delete]" >&2
            exit 1
            ;;
    esac
done

# Helper: run a command inside the container as root.
run_root() {
    ssh "$SSH_HOST" "lxc exec ${LXC_CONTAINER} -- bash -lc '$1'"
}
# Helper: run a command inside the container as the ubuntu user.
run_ubuntu() {
    ssh "$SSH_HOST" "lxc exec ${LXC_CONTAINER} -- sudo -u ubuntu bash -lc '$1'"
}

echo "=== Clear Skies full redeploy → ${LXC_CONTAINER} ==="

# --- Step 1: git pull (delegated to sync-to-weather-dev.sh) ---
if [ "$skip_pull" = "1" ]; then
    echo "--- [1/4] git pull: SKIPPED (--skip-pull) ---"
else
    echo "--- [1/4] git pull (all repos) ---"
    "${SCRIPT_DIR}/sync-to-weather-dev.sh"
fi

# --- Step 2: restart systemd services ---
echo "--- [2/4] restart services ---"
for svc in "${SERVICES[@]}"; do
    echo "[svc] restarting ${svc} ..."
    run_root "systemctl restart ${svc}"
    # Confirm it came back up; abort if not.
    run_root "systemctl is-active --quiet ${svc}"
    echo "[svc] ${svc} active"
done

# --- Step 3: build the dashboard ---
echo "--- [3/4] dashboard build (npm run build) ---"
# --legacy-peer-deps is required until the typescript@6 vs openapi-typescript@7
# (wants typescript@^5) peer conflict is resolved; plain `npm ci` aborts on
# ERESOLVE. Tracked debt — drop the flag once the peer range is reconciled.
run_ubuntu "cd ${DASHBOARD_PATH} && npm ci --legacy-peer-deps && npm run build"
# Sanity-check the build produced an index.html before we publish it.
run_ubuntu "test -f ${DIST_DIR}/index.html"
echo "[build] dist/ produced"

# --- Step 4: publish dist/ → web root (protecting the webcam bind-mount) ---
echo "--- [4/4] publish dist/ → ${WEB_ROOT} (excluding ${WEBCAM_EXCLUDE}) ---"
# Trailing slash on the source copies dist/ CONTENTS into the web root.
# --exclude='webcam/' keeps rsync from ever entering or deleting the read-only
# bind-mount. With --delete this is doubly important: excluded paths are NOT
# candidates for deletion, so the webcam mount and its contents are protected.
rsync_opts=(-a --human-readable --exclude="${WEBCAM_EXCLUDE}")
if [ "$use_delete" = "1" ]; then
    rsync_opts+=(--delete)
fi
rsync_cmd="rsync ${rsync_opts[*]} ${DIST_DIR}/ ${WEB_ROOT}/"
run_ubuntu "${rsync_cmd}"
echo "[publish] web root updated"

echo "=== Redeploy complete ==="
echo "Verify:  curl -sI http://weather-dev/ | head -1   (expect 200)"
echo "         curl -s  http://weather-dev/webcam/weather_cam.jpg -o /dev/null -w '%{http_code}\\n'"
echo "         ssh ${SSH_HOST} \"lxc exec ${LXC_CONTAINER} -- systemctl is-active ${SERVICES[*]}\""
