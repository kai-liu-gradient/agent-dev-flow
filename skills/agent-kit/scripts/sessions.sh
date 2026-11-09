#!/usr/bin/env bash
# List every running Claude Code session with what is needed to decide whether
# it can be closed. Read-only: it never kills a process or touches a repo.
#
# Usage: sessions.sh [path-filter]
#   path-filter  only show sessions whose working directory contains this text
set -u
filter="${1:-}"

now=$(date +%s)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

pids=$(pgrep -x claude || true)
[ -z "$pids" ] && { echo "No running claude sessions."; exit 0; }

# One line per session: pid, tty, age in days, cwd
for p in $pids; do
  cwd=$(lsof -a -p "$p" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')
  [ -z "$cwd" ] && continue
  case "$cwd" in *"$filter"*) ;; *) continue ;; esac
  tty=$(ps -o tty= -p "$p" | tr -d ' ')
  start=$(ps -o lstart= -p "$p")
  start_s=$(date -j -f "%a %b %d %T %Y" "$start" +%s 2>/dev/null || echo "$now")
  days=$(( (now - start_s) / 86400 ))
  printf '%s\t%s\t%s\t%s\n' "$p" "$tty" "$days" "$cwd" >> "$tmp/sessions"
done
[ -s "$tmp/sessions" ] || { echo "No sessions match '$filter'."; exit 0; }

# How many sessions share each directory
cut -f4 "$tmp/sessions" | sort | uniq -c | awk '{c=$1; $1=""; sub(/^ /,""); print c "\t" $0}' > "$tmp/shared"

# Facts per directory, computed once
cut -f4 "$tmp/sessions" | sort -u | while IFS= read -r dir; do
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    br=$(git -C "$dir" branch --show-current 2>/dev/null)
    [ -z "$br" ] && br="(detached)"
    # Paths listed in <git-dir>/info/agent-kit-local are intentional local
    # edits (e.g. a dev-stack script rewriting config) and do not count.
    ignore="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)/info/agent-kit-local"
    case "$ignore" in /*) ;; *) ignore="$dir/$ignore" ;; esac
    if [ -s "$ignore" ]; then
      dirty=$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null | cut -c4- | grep -vxF -f "$ignore" | wc -l | tr -d ' ')
    else
      dirty=$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
    fi
    pr="-"
    case "$br" in
      main|master|"(detached)") ;;
      *)
        if command -v gh >/dev/null 2>&1; then
          pr=$(cd "$dir" && gh pr list --head "$br" --state all --limit 1 \
               --json number,state -q 'if length > 0 then (.[0] | "#\(.number) \(.state)") else "" end' 2>/dev/null)
          [ -z "$pr" ] && pr="no PR"
        fi ;;
    esac
  else
    br="(not git)"; dirty=0; pr="-"
  fi
  printf '%s\t%s\t%s\t%s\n' "$dir" "$br" "$dirty" "$pr" >> "$tmp/dirs"
done

# One block per directory: its facts, the advice, then the sessions in it
sort -t$'\t' -k1,1 "$tmp/dirs" | while IFS=$'\t' read -r dir br dirty pr; do
  n=$(awk -F'\t' -v d="$dir" '$4==d' "$tmp/sessions" | wc -l | tr -d ' ')
  if [ "$dirty" -gt 0 ] && [ "$n" -gt 1 ]; then
    advice="ASK  $dirty uncommitted changes, $n sessions share this dir: find which one made them before closing any"
  elif [ "$dirty" -gt 0 ]; then
    advice="WRAP $dirty uncommitted changes: run /wrap in it, then close"
  else
    case "$pr" in
      *MERGED*|*CLOSED*) advice="CLOSE  PR is done and nothing is uncommitted" ;;
      *OPEN*)            advice="CLOSE OK  work is on the PR; reopen with: claude --from-pr ${pr%% *}" ;;
      *)                 advice="CLOSE OK  nothing uncommitted; reopen with: claude -r" ;;
    esac
  fi
  echo "== $dir"
  echo "   branch: $br   uncommitted: $dirty   PR: $pr   sessions: $n"
  echo "   -> $advice"
  awk -F'\t' -v d="$dir" '$4==d {printf "      pid %-7s %-9s open %sd\n", $1, $2, $3}' "$tmp/sessions" | sort -k5,5nr -t' '
  echo
done

total=$(wc -l < "$tmp/sessions" | tr -d ' ')
old=$(awk -F'\t' '$3>=3' "$tmp/sessions" | wc -l | tr -d ' ')
echo
echo "$total sessions, $old open for 3+ days. Closing a session keeps its transcript: claude -r <name|id> or claude --from-pr <n> brings it back."
echo "Background processes a session started (port-forward, dev server, /loop) stop when it closes; /wrap lists them first."
