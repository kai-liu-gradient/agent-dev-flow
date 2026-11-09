#!/usr/bin/env bash
# Test a batch of PRs together once, instead of a full suite per PR.
#
#   merge-batch.sh build <pr> [pr...]
#       New worktree from the latest default branch; merges each PR's head into it
#       in the order given. A PR that conflicts, is closed, is a draft, or targets
#       another branch is skipped and reported. Prints the worktree path and the
#       PRs it contains (the last line is machine-readable: BATCH <path> <prs...>).
#   merge-batch.sh blame <worktree> <pkg> <failed-files.txt> <pr...>
#       For each failing test file, which PRs in the batch it depends on
#       (jest --findRelatedTests over each PR's changed files in <pkg>).
#   merge-batch.sh clean <worktree>
#       Remove the batch worktree and its branch.
#
# It never merges anything; merging stays with the caller.
set -uo pipefail
cmd="${1:-}"; shift || true
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "run inside the repo" >&2; exit 2; }
main=$(cd "$(git -C "$top" rev-parse --git-common-dir)/.." && pwd)
base=$(git -C "$main" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
default=${base#origin/}

case "$cmd" in
  build)
    [ $# -gt 0 ] || { echo "usage: merge-batch.sh build <pr>..." >&2; exit 2; }
    git -C "$main" fetch -q origin "$default"
    name="merge-batch-$(date +%Y%m%d-%H%M%S)"
    wt="$main/.claude/worktrees/$name"
    git -C "$main" worktree add -q -b "$name" "$wt" "$base" || exit 1
    # Share installed dependencies with the main checkout when the worktree has none.
    for d in "$main"/*/node_modules; do
      [ -d "$d" ] || continue; rel=${d#"$main"/}
      [ -e "$wt/$rel" ] || ln -s "$d" "$wt/$rel"
    done
    included=(); skipped=()   # bash 3.2: guard empty-array expansions under set -u
    for pr in "$@"; do
      pr=${pr#\#}
      info=$(gh pr view "$pr" --json state,isDraft,baseRefName,title -q '"\(.state)\t\(.isDraft)\t\(.baseRefName)\t\(.title)"' 2>/dev/null) \
        || { skipped+=("#$pr (not found)"); continue; }
      IFS=$'\t' read -r state draft prbase title <<<"$info"
      if [ "$state" != OPEN ]; then skipped+=("#$pr ($state)"); continue; fi
      if [ "$draft" = true ]; then skipped+=("#$pr (draft)"); continue; fi
      if [ "$prbase" != "$default" ]; then skipped+=("#$pr (targets $prbase; merge its base first)"); continue; fi
      git -C "$wt" fetch -q origin "pull/$pr/head:refs/batch/pr-$pr" || { skipped+=("#$pr (fetch failed)"); continue; }
      if git -C "$wt" merge -q --no-ff --no-edit -m "batch: #$pr $title" "refs/batch/pr-$pr" >/dev/null 2>&1; then
        included+=("$pr")
      else
        files=$(git -C "$wt" diff --name-only --diff-filter=U | tr '\n' ' ')
        git -C "$wt" merge --abort
        skipped+=("#$pr (conflicts with earlier PRs in the batch: $files)")
      fi
    done
    echo "batch worktree: $wt"
    if [ ${#included[@]} -gt 0 ]; then echo "included: $(printf '#%s ' "${included[@]}")"; else echo "included: none"; fi
    [ ${#skipped[@]} -gt 0 ] && printf 'skipped: %s\n' "${skipped[@]}"
    [ ${#included[@]} -gt 0 ] || echo "nothing to test: no PR could be added"
    echo "BATCH $wt ${included[*]+"${included[*]}"}" ;;

  blame)
    wt="${1:?worktree}"; pkg="${2:?package dir}"; failed="${3:?failed-files.txt}"; shift 3
    [ $# -gt 0 ] || { echo "list the PRs in the batch" >&2; exit 2; }
    map=$(mktemp)   # lines: <test file>\t#<pr>   (bash 3.2 has no associative arrays)
    for pr in "$@"; do
      pr=${pr#\#}
      files=$(gh pr diff "$pr" --name-only 2>/dev/null | grep "^$pkg/" | sed "s#^$pkg/##")
      [ -n "$files" ] || continue
      (cd "$wt/$pkg" && npx jest --listTests --findRelatedTests $files 2>/dev/null) \
        | sed "s#.*/$pkg/##" | grep -xF -f "$failed" | sed "s/\$/\t#$pr/" >> "$map"
    done
    while IFS= read -r t; do
      [ -n "$t" ] || continue
      who=$(awk -F'\t' -v t="$t" '$1==t{print $2}' "$map" | sort -u | tr '\n' ' ')
      echo "$t <- ${who:-no PR in the batch touches its dependencies; check the batch as a whole}"
    done < "$failed"
    rm -f "$map" ;;

  clean)
    wt="${1:?worktree}"; br=$(git -C "$wt" branch --show-current 2>/dev/null)
    git -C "$main" worktree remove --force "$wt" && echo "removed $wt"
    [ -n "$br" ] && git -C "$main" branch -D "$br" >/dev/null 2>&1
    git -C "$main" for-each-ref --format='%(refname)' refs/batch/ | while read -r r; do git -C "$main" update-ref -d "$r"; done ;;

  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
