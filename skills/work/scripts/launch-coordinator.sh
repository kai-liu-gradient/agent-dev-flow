#!/usr/bin/env bash
# Start the coordinator session for an epic: a named claude session that is sent
# `/work coordinate #<epic>`. In herdr it gets its own tab; elsewhere the commands
# are printed for the user.
#
# Usage: launch-coordinator.sh <epic-number> "<short title>" [repo-dir]
set -euo pipefail
epic="${1:?epic number}"; title="${2:?short title}"; dir="${3:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
# The coordinator works from the main checkout, never from a worktree.
common="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null || true)"
case "$common" in /*) dir="$(cd "$common/.." && pwd)" ;; esac

exec "$(dirname "$0")/hd.sh" spawn "主控 #$epic $title" "epic #$epic $title" "/work coordinate #$epic" "$dir"
