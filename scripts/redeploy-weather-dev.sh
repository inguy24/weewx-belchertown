#!/usr/bin/env bash
# redeploy-weather-dev.sh — FULL redeploy of Clear Skies onto the weather-dev
# LXD container.
#
# Fired from any workstation (DILBERT, CATBERT, etc.) after pushing commits
# to GitHub. SSHes directly to weather-dev (not via ratbert lxc exec).
#
# Performs, in order:
#   1. git pull --ff-only for all (or one) repo(s)        [delegates to sync-to-weather-dev.sh]
#   2. restart the systemd services                       (config)
#   3. npm run build in the dashboard repo                 (Vite → dist/)
#   4. rsync built dist/ → web root /var/www/clearskies/   (EXCLUDING the read-only webcam/ mount)
#
# SSH config: uses the project-local config at .local/ssh/config so it works
# from any machine that has the replicated project files.
#
# Transport: direct SSH to weather-dev as `claude` user.
#   - service restarts use sudo (claude has NOPASSWD sudo)
#   - git pull and npm build run as the `ubuntu` user (owns the repos)
#   - rsync runs as the `ubuntu` user (owns /var/www/clearskies)
#
# Verified weather-dev facts (2026-06-10):
#   - Units:    weewx-clearskies-config.service
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

CONTAINER_REPO_ROOT="/home/ubuntu/repos"
DASHBOARD_REPO="weewx-clearskies-dashboard"
DASHBOARD_PATH="${CONTAINER_REPO_ROOT}/${DASHBOARD_REPO}"
DIST_DIR="${DASHBOARD_PATH}/dist"
WEB_ROOT="/var/www/clearskies"
SERVICES=(
    "weewx-clearskies-config"
)
# NOTE: weewx-clearskies-api is NOT restarted here — the API runs on the
# weewx LXD container, not on weather-dev. See docs/procedures/deploy-clearskies.md
# "Deploying API changes to the weewx container" for the correct procedure.
# CRITICAL: the read-only webcam bind-mount lives directly under the web root.
# rsync must NEVER delete or write into it. webcam.json is a manually-managed
# config file at the web root level — not part of the Vite build output — so it
# must also be excluded from --delete pruning.
WEBCAM_EXCLUDES=("webcam/" "webcam.json")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSH_CONFIG="${PROJECT_ROOT}/.local/ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
    echo "SSH config not found at ${SSH_CONFIG}" >&2
    echo "Ensure .local/ssh/config exists (replicated via Nextcloud)." >&2
    exit 1
fi

SSH_CMD="ssh -F ${SSH_CONFIG}"

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

# Helper: run a command on weather-dev via sudo (for systemctl, etc.).
run_root() {
    $SSH_CMD weather-dev "sudo bash -lc '$1'"
}
# Helper: run a command on weather-dev as the ubuntu user (owns repos + web root).
run_ubuntu() {
    $SSH_CMD weather-dev "sudo -u ubuntu bash -lc '$1'"
}

echo "=== Clear Skies full redeploy → weather-dev ==="

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
echo "--- [4/4] publish dist/ → ${WEB_ROOT} (excluding ${WEBCAM_EXCLUDES[*]}) ---"
# Trailing slash on the source copies dist/ CONTENTS into the web root.
# --exclude keeps rsync from entering/deleting the excluded paths. With --delete
# this is doubly important: excluded paths are NOT candidates for deletion, so
# the webcam mount, its contents, and webcam.json are all protected.
rsync_opts=(-a --human-readable)
for excl in "${WEBCAM_EXCLUDES[@]}"; do
    rsync_opts+=(--exclude="${excl}")
done
if [ "$use_delete" = "1" ]; then
    rsync_opts+=(--delete)
fi
rsync_cmd="rsync ${rsync_opts[*]} ${DIST_DIR}/ ${WEB_ROOT}/"
run_ubuntu "${rsync_cmd}"
echo "[publish] web root updated"

echo "=== Redeploy complete ==="
echo "Verify:  curl -sI http://weather-dev/ | head -1   (expect 200)"
echo "         curl -s  http://weather-dev/webcam/weather_cam.jpg -o /dev/null -w '%{http_code}\\n'"
echo "         curl -s  http://weather-dev/webcam.json -o /dev/null -w '%{http_code}\\n'   (expect 200)"
echo "         $SSH_CMD weather-dev 'sudo systemctl is-active ${SERVICES[*]}'"
