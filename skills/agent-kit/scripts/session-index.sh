#!/usr/bin/env bash
# What is each running Claude session doing, and how to get it back after closing.
# Read-only. Prints a table and saves the same list as Markdown so it can be
# found again after the sessions are closed.
#
# Usage: session-index.sh [path-filter]
set -u
filter="${1:-}"
out_dir="$HOME/.claude/session-index"
mkdir -p "$out_dir"
out="$out_dir/$(date +%Y-%m-%d-%H%M).md"

slug() { printf '%s' "$1" | sed 's#[^A-Za-z0-9]#-#g'; }
oneline() { tr '\n\r\t' '   ' | sed 's/  */ /g' | cut -c1-"$1"; }

{
  echo "# Open Claude sessions, $(date '+%Y-%m-%d %H:%M')"
  echo
  echo "Reopen any of them after closing with \`claude -r <session id>\` (or \`claude --from-pr <n>\`)."
  echo
} > "$out"

rows=0
cache=$(mktemp -d); trap 'rm -rf "$cache"' EXIT
# State of a PR, "repo#n" -> MERGED/OPEN/CLOSED, one gh call per repo
pr_state() {
  local full="$1" n="$2" key
  key=$(printf '%s' "$full" | tr '/' '_')
  if [ ! -f "$cache/$key" ]; then
    gh pr list -R "$full" --state all --limit 400 --json number,state \
      -q '.[] | "\(.number) \(.state)"' > "$cache/$key" 2>/dev/null || : > "$cache/$key"
  fi
  awk -v n="$n" '$1==n{print $2}' "$cache/$key"
}
for meta in "$HOME"/.claude/sessions/*.json; do
  pid=$(basename "$meta" .json)
  kill -0 "$pid" 2>/dev/null || continue
  [ "$(ps -o comm= -p "$pid" 2>/dev/null | xargs basename 2>/dev/null)" = "claude" ] || continue
  sid=$(jq -r '.sessionId // empty' "$meta")
  cwd=$(jq -r '.cwd // empty' "$meta")
  case "$cwd" in *"$filter"*) ;; *) continue ;; esac
  name=$(jq -r '.name // ""' "$meta")
  status=$(jq -r '.status // "?"' "$meta")
  upd=$(jq -r '.updatedAt // 0' "$meta")
  last=$(date -r $((upd / 1000)) '+%m-%d %H:%M' 2>/dev/null || echo "?")
  tty=$(ps -o tty= -p "$pid" | tr -d ' ')

  tr_file="$HOME/.claude/projects/$(slug "$cwd")/$sid.jsonl"
  title=""; prompt=""; prs=""
  if [ -f "$tr_file" ]; then
    title=$(grep '"type":"ai-title"' "$tr_file" | tail -1 | jq -r '.aiTitle // empty' 2>/dev/null)
    prompt=$(grep '"type":"last-prompt"' "$tr_file" | jq -r '.lastPrompt // empty' 2>/dev/null \
             | grep -v '^/' | tail -1 | oneline 90)
    prs=""
    while read -r full n; do
      [ -z "$full" ] && continue
      st=$(pr_state "$full" "$n")
      prs="$prs ${full##*/}#$n${st:+($st)}"
    done < <(grep '"type":"pr-link"' "$tr_file" | jq -r '"\(.prRepository) \(.prNumber)"' 2>/dev/null | awk '!seen[$0]++' | tail -4)
    prs="${prs# }"
  fi
  [ -z "$title" ] && title="(no title)"
  where=$(printf '%s' "$cwd" | sed "s#^$HOME#~#")

  printf '%s\n' "------------------------------------------------------------"
  printf '%-6s %-8s %-5s last %s   %s\n' "$pid" "$tty" "$status" "$last" "$where"
  printf '  title : %s\n' "$title"
  [ -n "$prs" ] && printf '  PRs   : %s\n' "$prs"
  [ -n "$prompt" ] && printf '  you   : %s\n' "$prompt"
  printf '  reopen: claude -r %s\n' "$sid"
  [ "$status" = "busy" ] && printf '  !! still working - do not close yet\n'

  {
    echo "## $title"
    echo
    echo "- Directory: \`$where\`  (pid $pid, $tty, last active $last, $status)"
    [ -n "$prs" ] && echo "- PRs: $prs"
    [ -n "$prompt" ] && echo "- Your last message: $prompt"
    echo "- Reopen: \`claude -r $sid\`"
    echo
  } >> "$out"
  rows=$((rows + 1))
done

echo "------------------------------------------------------------"
echo "$rows sessions. Saved to $out"
echo "Closing a session never deletes it; the reopen command above brings back the full conversation."
