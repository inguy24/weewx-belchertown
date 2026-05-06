#!/usr/bin/env bash
# sync-to-weather-dev.sh — pull latest from GitHub into the weather-dev
# container's working trees.
#
# Fired from DILBERT (this workstation) after pushing commits to GitHub.
# For each Clear Skies repo, runs `git pull --ff-only` inside the
# weather-dev LXD container as the `ubuntu` user.
#
# Transport: ssh to the LXD host, then `lxc exec weather-dev -- sudo -u ubuntu`.
#
# Prereq (one-time, at repo standup): all five repos cloned at
# /home/ubuntu/repos/<name> inside the container.
#
# Usage:
#   ./sync-to-weather-dev.sh                              # pulls all five
#   ./sync-to-weather-dev.sh weewx-clearskies-api         # pulls one repo

set -eu

ALL_REPOS=(
    weewx-clearskies-api
    weewx-clearskies-realtime
    weewx-clearskies-dashboard
    weewx-clearskies-stack
    weewx-clearskies-design-tokens
)

CONTAINER_REPO_ROOT=/home/ubuntu/repos
SSH_HOST=ratbert
LXC_CONTAINER=weather-dev

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
    if ssh "$SSH_HOST" "lxc exec $LXC_CONTAINER -- sudo -u ubuntu bash -lc '$remote_cmd'"; then
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
