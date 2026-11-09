#!/usr/bin/env bash
# Run a heavy test command with at most TEST_LOCK_SLOTS of them on this machine
# at once (default 1). Every session and worktree shares the same slots, so ten
# sessions running full suites take turns instead of thrashing the machine.
#
#   test-lock.sh <command...>     wait for a slot, run, release (exit code passes through)
#   test-lock.sh --status         who holds the slots now
#
# Also exports a low worker count for runners that read it, and runs the command
# at a lower CPU priority. Pass --maxWorkers=2 to jest / vitest yourself; they
# do not read it from the environment.
set -uo pipefail
DIR="${TEST_LOCK_DIR:-$HOME/.cache/agent-dev-flow/test-lock}"
SLOTS="${TEST_LOCK_SLOTS:-1}"
mkdir -p "$DIR"

holder() { cat "$1/owner" 2>/dev/null; }
alive()  { local pid; pid=$(sed -n 's/^pid=//p' "$1/owner" 2>/dev/null); [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; }

if [ "${1:-}" = "--status" ]; then
  any=0
  for s in $(seq 1 "$SLOTS"); do
    d="$DIR/slot$s"
    if [ -d "$d" ] && alive "$d"; then any=1; echo "slot $s: $(holder "$d" | tr '\n' ' ')"; fi
  done
  [ $any = 1 ] || echo "all $SLOTS slot(s) free"
  exit 0
fi
[ $# -gt 0 ] || { sed -n '2,12p' "$0"; exit 2; }

slot=""; waited=0
while [ -z "$slot" ]; do
  for s in $(seq 1 "$SLOTS"); do
    d="$DIR/slot$s"
    # A slot whose holder died is free again.
    if [ -d "$d" ] && ! alive "$d"; then rm -rf "$d"; fi
    if mkdir "$d" 2>/dev/null; then slot="$d"; break; fi
  done
  if [ -z "$slot" ]; then
    if [ $((waited % 60)) = 0 ]; then
      echo "[test-lock] waiting for a test slot (${waited}s); busy: $(holder "$DIR/slot1" | sed -n 's/^cwd=//p')" >&2
    fi
    sleep 5; waited=$((waited + 5))
  fi
done
printf 'pid=%s\ncwd=%s\ncmd=%s\nstarted=%s\n' "$$" "$PWD" "$*" "$(date '+%F %T')" > "$slot/owner"
trap 'rm -rf "$slot"' EXIT INT TERM

export JEST_WORKERS="${JEST_WORKERS:-2}" VITEST_MAX_THREADS="${VITEST_MAX_THREADS:-2}" VITEST_MAX_FORKS="${VITEST_MAX_FORKS:-2}"
[ $waited -gt 0 ] && echo "[test-lock] got a slot after ${waited}s" >&2
nice -n 10 "$@"
