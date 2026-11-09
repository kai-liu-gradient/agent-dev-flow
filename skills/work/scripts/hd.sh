#!/usr/bin/env bash
# herdr helpers with a fallback for every command. Inside herdr they act on the
# workspace; outside they print what the user can do instead. Never fails the
# caller just because herdr is missing.
#
#   hd.sh available                       exit 0 when running inside herdr
#   hd.sh name <label>                    rename this session's tab
#   hd.sh notify <title> [body]           desktop notification (herdr, else macOS, else bell)
#   hd.sh spawn <tab-label> <session-name> <first-prompt> [cwd]
#                                         new tab + named claude session + first prompt
#   hd.sh where <session-id>              "workspace / tab" holding that claude session
#   hd.sh close-self [delay-seconds]      close this pane after a delay (default 5)
set -uo pipefail

in_herdr() {
  [ -n "${HERDR_PANE_ID:-}" ] && command -v herdr >/dev/null 2>&1 \
    && herdr status server 2>/dev/null | grep -q 'status: running'
}

cmd="${1:-}"; shift || true
case "$cmd" in
  available)
    in_herdr ;;

  name)
    label="${1:?label}"
    if in_herdr && [ -n "${HERDR_TAB_ID:-}" ]; then
      herdr tab rename "$HERDR_TAB_ID" "$label" >/dev/null && echo "tab renamed: $label"
    else
      echo "not in herdr: next time start the session with  claude -n \"$label\""
    fi ;;

  notify)
    title="${1:?title}"; body="${2:-}"
    if in_herdr; then
      herdr notification show "$title" ${body:+--body "$body"} --sound request >/dev/null
    elif command -v osascript >/dev/null 2>&1; then
      osascript -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\" sound name \"Glass\"" >/dev/null 2>&1
    else
      printf '\a'
    fi ;;

  spawn)
    label="${1:?tab label}"; name="${2:?session name}"; prompt="${3:?first prompt}"; cwd="${4:-$PWD}"
    if ! in_herdr || [ -z "${HERDR_WORKSPACE_ID:-}" ]; then
      printf 'not in herdr. In a new terminal run:\n  cd "%s"\n  claude -n "%s"\nthen send:\n  %s\n' "$cwd" "$name" "$prompt"
      exit 0
    fi
    tab=$(herdr tab create --workspace "$HERDR_WORKSPACE_ID" --cwd "$cwd" --label "$label" | jq -r '.result.tab.tab_id // .result.tab_id // empty')
    [ -n "$tab" ] || { echo "herdr tab create failed" >&2; exit 1; }
    pane=$(herdr pane list | jq -r --arg t "$tab" '.result.panes[] | select(.tab_id==$t) | .pane_id' | head -1)
    [ -n "$pane" ] || { echo "no pane in new tab $tab" >&2; exit 1; }
    # herdr agent names: lowercase letters, digits, - and _, 1-32 chars.
    aname=$(printf '%s' "$name" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9_-' '-' | sed 's/^[^a-z]*//; s/-\{2,\}/-/g' | cut -c1-32)
    [ -n "$aname" ] || aname="agent-$$"
    herdr agent start "$aname" --kind claude --pane "$pane" --timeout 120000 -- -n "$name" >/dev/null || { echo "claude did not start in $pane" >&2; exit 1; }
    # A folder claude has not been told to trust opens with a trust prompt. Typing the
    # first prompt there would pick "No, exit". Trusting is the user's call: stop here.
    sleep 1
    if herdr pane read "$pane" --source visible 2>/dev/null | grep -qiE 'trust this folder|Do you trust'; then
      "$0" notify "新 tab 需要你确认" "在「${label}」里确认信任目录，然后发送：$prompt"
      printf 'claude is asking whether to trust %s in tab "%s" (%s).
Confirm it there, then send:
  %s
' "$cwd" "$label" "$pane" "$prompt"
      exit 3
    fi
    herdr agent prompt "$pane" "$prompt" >/dev/null
    # The session id is reported a moment after claude starts.
    sid=""; for _ in $(seq 1 20); do
      sid=$(herdr agent list | jq -r --arg p "$pane" '.result.agents[] | select(.pane_id==$p) | .agent_session.value // empty')
      [ -n "$sid" ] && break; sleep 0.5
    done
    [ -n "$sid" ] || sid="(id not reported yet; use the name)"
    printf 'started in herdr\n  tab:     %s (%s)\n  pane:    %s\n  reopen:  claude -r "%s"   or   claude -r %s\n' "$label" "$tab" "$pane" "$name" "$sid" ;;

  where)
    sid="${1:?session id}"
    if in_herdr; then
      herdr agent list 2>/dev/null | jq -r --arg s "$sid" '.result.agents[] | select(.agent_session.value==$s) | "\(.workspace_id) \(.tab_id) \(.pane_id)"' | head -1 | while read -r ws tab pane; do
        wl=$(herdr workspace list | jq -r --arg w "$ws" '.result.workspaces[] | select(.workspace_id==$w) | .label')
        tl=$(herdr tab list | jq -r --arg t "$tab" '.result.tabs[] | select(.tab_id==$t) | .label')
        echo "$wl / $tl ($pane)"
      done
    fi ;;

  close-self)
    delay="${1:-5}"
    if in_herdr; then
      # Detached so this session can finish its reply before the pane goes away.
      nohup sh -c "sleep $delay; herdr pane close '$HERDR_PANE_ID'" >/dev/null 2>&1 &
      echo "this pane closes in ${delay}s"
    else
      echo "not in herdr: close this terminal yourself"
    fi ;;

  *)
    sed -n '2,13p' "$0"; exit 2 ;;
esac
