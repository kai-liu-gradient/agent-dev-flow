#!/usr/bin/env bash
# Start the coordinator session for an epic.
# In herdr: new tab in the current workspace, named claude session, first prompt sent.
# Elsewhere: print the commands for the user.
#
# Usage: launch-coordinator.sh <epic-number> "<short title>" [repo-dir]
set -euo pipefail
epic="${1:?epic number}"; title="${2:?short title}"; dir="${3:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
# The coordinator works from the main checkout, never from a worktree.
common="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null || true)"
case "$common" in /*) dir="$(cd "$common/.." && pwd)" ;; esac
name="epic #$epic $title"
label="主控 #$epic $title"
agent="epic-$epic"
prompt="/work coordinate #$epic"

if [ -z "${HERDR_WORKSPACE_ID:-}" ] || ! command -v herdr >/dev/null 2>&1; then
  printf 'Not in herdr. Run these in a new terminal:\n  cd "%s"\n  claude -n "%s"\nthen send: %s\n' "$dir" "$name" "$prompt"
  exit 0
fi

tab=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$dir" --label "$label" | jq -r '.result.tab.tab_id // .result.tab_id // empty')
[ -n "$tab" ] || { echo "herdr tab create failed" >&2; exit 1; }
pane=$(herdr pane list | jq -r --arg t "$tab" '.result.panes[] | select(.tab_id==$t) | .pane_id' | head -1)
[ -n "$pane" ] || { echo "no pane in new tab $tab" >&2; exit 1; }

herdr agent start "$agent" --kind claude --pane "$pane" --timeout 120000 -- -n "$name" >/dev/null
herdr agent prompt "$pane" "$prompt" >/dev/null
sid=$(herdr agent list | jq -r --arg p "$pane" '.result.agents[] | select(.pane_id==$p) | .agent_session.value')

echo "coordinator started"
echo "  tab:     $label ($tab)"
echo "  pane:    $pane"
echo "  session: $name"
echo "  reopen:  claude -r \"$name\"   or   claude -r $sid"
