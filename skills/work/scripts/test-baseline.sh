#!/usr/bin/env bash
# Which tests already fail on the default branch, recorded once per commit and
# shared by every session, so no PR has to rerun the default branch's full suite.
#
#   test-baseline.sh get <pkg>                 print the cached failures for origin's
#                                              default-branch head (exit 1 if none cached)
#   test-baseline.sh put <pkg> <result.json>   record failures from a jest/vitest --json
#                                              run made at that head
#   test-baseline.sh new <pkg> <result.json>   failures in a branch run that the baseline
#                                              does not have (exit 1 when there are any)
#   test-baseline.sh failed <pkg> <result.json>  just list a run's failed test files
#
# <pkg> is the package directory name (e.g. launchpad-api). Run from inside the repo.
# jest: --json --outputFile=x.json   vitest: --reporter=json --outputFile=x.json
# Cache: ~/.cache/agent-dev-flow/baseline/<repo>/<commit>/<pkg>.failed
set -uo pipefail
cmd="${1:-}"; pkg="${2:-}"
[ -n "$cmd" ] && [ -n "$pkg" ] || { sed -n '2,15p' "$0"; exit 2; }

top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git repo" >&2; exit 2; }
repo=$(git -C "$top" remote get-url origin 2>/dev/null | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#; s#/#_#')
[ -n "$repo" ] || repo=$(basename "$(cd "$(git -C "$top" rev-parse --git-common-dir)/.." && pwd)")
base=$(git -C "$top" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
git -C "$top" fetch -q origin "${base#origin/}" 2>/dev/null || true
sha=$(git -C "$top" rev-parse "$base" 2>/dev/null) || { echo "cannot resolve $base" >&2; exit 2; }
root="$HOME/.cache/agent-dev-flow/baseline/$repo"
file="$root/$sha/$pkg.failed"

failed() { # result.json -> failed test files, relative to the package
  jq -r '.testResults[] | select(.status=="failed") | .name' "$1" \
    | sed "s#.*/$pkg/##" | sort -u
}

case "$cmd" in
  failed) failed "${3:?result.json}" ;;
  put)
    json="${3:?result.json}"; mkdir -p "$(dirname "$file")"
    failed "$json" > "$file.tmp" && mv "$file.tmp" "$file"
    echo "baseline for $pkg at ${sha:0:8}: $(wc -l < "$file" | tr -d ' ') failing files -> $file" ;;
  get)
    if [ -f "$file" ]; then cat "$file"; exit 0; fi
    # An older baseline is still useful; say which commit it is from.
    prev=$(ls -t "$root"/*/"$pkg.failed" 2>/dev/null | head -1)
    if [ -n "$prev" ]; then
      echo "[test-baseline] no baseline at ${sha:0:8}; using $(basename "$(dirname "$prev")" | cut -c1-8)" >&2
      cat "$prev"; exit 0
    fi
    echo "[test-baseline] no baseline for $pkg yet. Run the suite once at $base under test-lock.sh and 'put' it." >&2
    exit 1 ;;
  new)
    json="${3:?result.json}"
    b=$("$0" get "$pkg") || exit 2
    n=$(comm -13 <(printf '%s\n' "$b" | sort -u) <(failed "$json"))
    if [ -n "$n" ]; then echo "$n"; exit 1; fi
    echo "no new failures (baseline has $(printf '%s\n' "$b" | grep -c .))" ;;
  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
