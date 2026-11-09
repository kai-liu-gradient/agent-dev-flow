#!/usr/bin/env bash
# Ask several Claude sessions to wrap up, wait for them, and print how each ended.
# herdr only: it types /wrap into each pane and waits. Outside herdr it prints
# what to paste into each session instead.
#
# Usage:
#   wrap-panes.sh --tab <tab-id>          every idle claude pane in that tab
#   wrap-panes.sh <pane-id> [pane-id...]  those panes
#   wrap-panes.sh --list                  claude panes with their tab, title and state
#   options: --timeout <minutes> (default 30)
set -uo pipefail
HD="$(cd "$(dirname "$0")/../../work/scripts" 2>/dev/null && pwd)/hd.sh"
[ -x "$HD" ] || HD="$HOME/.claude/skills/work/scripts/hd.sh"

if ! "$HD" available; then
  echo "not in herdr. In each session you want to close, send:  /wrap"
  echo "then close it once it answers 可以关了. Find them with: $(dirname "$0")/session-index.sh"
  exit 0
fi

agents() { herdr agent list | jq -r '.result.agents[] | select(.agent=="claude") | [.pane_id, .tab_id, .agent_status, .terminal_title_stripped] | @tsv'; }

timeout_min=30; panes=(); tab=""
while [ $# -gt 0 ]; do
  case "$1" in
    --list) agents | while IFS=$'\t' read -r p t s title; do
              tl=$(herdr tab list | jq -r --arg t "$t" '.result.tabs[] | select(.tab_id==$t) | .label')
              printf '%-8s %-24.24s %-8s %s\n' "$p" "$tl" "$s" "$title"; done; exit 0 ;;
    --tab) tab="$2"; shift ;;
    --timeout) timeout_min="$2"; shift ;;
    *) panes+=("$1") ;;
  esac; shift
done
if [ -n "$tab" ]; then
  while IFS=$'\t' read -r p t s _; do [ "$t" = "$tab" ] && [ "$s" != working ] && panes+=("$p"); done < <(agents)
fi
self="${HERDR_PANE_ID:-}"
[ ${#panes[@]} -gt 0 ] || { echo "no panes selected (see --list)"; exit 1; }

for p in "${panes[@]}"; do
  [ "$p" = "$self" ] && { echo "skip $p: this session"; continue; }
  herdr agent prompt "$p" "/wrap" >/dev/null && echo "sent /wrap -> $p"
done
for p in "${panes[@]}"; do
  [ "$p" = "$self" ] && continue
  herdr agent wait "$p" --timeout $((timeout_min * 60000)) >/dev/null 2>&1 || echo "$p: still working after ${timeout_min}m"
done
echo
for p in "${panes[@]}"; do
  [ "$p" = "$self" ] && continue
  last=$(herdr agent read "$p" --source recent-unwrapped --lines 40 2>/dev/null \
    | grep -E '可以关了|还不能关|safe to close|not safe|claude -r|--from-pr' | tail -2 | tr -s ' ' | tr '\n' ' ')
  echo "$p: ${last:-（没找到结论，去那个 pane 看一眼）}"
done
"$HD" notify "收工完成" "${#panes[@]} 个会话已处理，回到终端看结果"
