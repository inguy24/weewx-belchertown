#!/usr/bin/env bash
# sync-to-weather-dev.sh — pull latest from GitHub into the weather-dev
# container's working trees.
#
# Fired from any workstation (DILBERT, CATBERT, etc.) after pushing commits
# to GitHub. SSHes directly to weather-dev and runs `git pull --ff-only`
# as the `ubuntu` user (who owns the repos).
#
# SSH config: uses the project-local config at .local/ssh/config so it works
# from any machine that has the replicated project files.
#
# Prereq (one-time, at repo standup): all five repos cloned at
# /home/ubuntu/repos/<name> inside the container.
#
# Usage:
#   ./sync-to-weather-dev.sh                              # pulls all five
#   ./sync-to-weather-dev.sh weewx-clearskies-api         # pulls one repo
#
# NOTE: This script ONLY pulls source. It does NOT rebuild the dashboard,
# restart services, or refresh the web root. For a full redeploy (pull +
# restart services + dashboard build + publish dist/), use the companion
# script `redeploy-weather-dev.sh`. See docs/procedures/deploy-clearskies.md.

set -eu

ALL_REPOS=(
    weewx-clearskies-api
    weewx-clearskies-realtime
    weewx-clearskies-dashboard
    weewx-clearskies-stack
    weewx-clearskies-design-tokens
)

CONTAINER_REPO_ROOT=/home/ubuntu/repos
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SSH_CONFIG="${PROJECT_ROOT}/.local/ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
    echo "SSH config not found at ${SSH_CONFIG}" >&2
    echo "Ensure .local/ssh/config exists (replicated via Nextcloud)." >&2
    exit 1
fi

SSH_CMD="ssh -F ${SSH_CONFIG}"

if [ "$#" -gt 0 ]; then
    requested=$1
    found=0
    for r in "${ALL_REPOS[@]}"; do
        [ "$r" = "$requested" ] && found=1 && break
    done
    if [ "$found" = "0" ]; then
        echo "Unknown repo '$requested'. Known: ${ALL_REPOS[*]}" >&2
        exit 1
    fi
    to_pull=("$requested")
else
    to_pull=("${ALL_REPOS[@]}")
fi

failed=()
for repo in "${to_pull[@]}"; do
    echo "[$repo] git pull --ff-only ..."
    remote_cmd="cd $CONTAINER_REPO_ROOT/$repo && git pull --ff-only"
    if $SSH_CMD weather-dev "sudo -u ubuntu bash -lc '$remote_cmd'"; then
        echo "[$repo] ok"
    else
        echo "[$repo] FAILED" >&2
        failed+=("$repo")
    fi
done

if [ "${#failed[@]}" -gt 0 ]; then
    echo "Pulls failed for: ${failed[*]}" >&2
    exit 1
fi

echo "All pulls succeeded."
