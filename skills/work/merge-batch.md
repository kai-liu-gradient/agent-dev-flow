# /work merge-batch #a #b #c ...

Merge several ready PRs with **one** full test run for the whole batch instead of
one per PR. Use it whenever two or more PRs are waiting to merge.

## Steps

1. **Confirm the batch with the user** in one message: the PRs in merge order, the
   tier of each, and that Tier B ones will be merged as part of the batch. Their
   answer is the merge approval for every PR on the list. Skip PRs the user drops.
2. **Build:** `scripts/merge-batch.sh build <pr>...`. It stacks each PR's head onto
   the latest default branch in a new worktree and skips drafts, closed PRs, PRs
   targeting another branch (stacked PRs: merge their base first) and PRs that
   conflict with earlier ones. Read the last line, `BATCH <worktree> <prs>`.
3. **Test once,** in that worktree, for every package the batch touches, through the
   lock: `scripts/test-lock.sh <full suite command> --maxWorkers=2 --json
   --outputFile=<file>`; then `scripts/test-baseline.sh new <pkg> <file>`. Also lint
   and build whatever the batch touches.
4. **No new failures:** merge the PRs one by one in the given order
   (`gh pr merge <n> --squash`), checking each is still mergeable. If one stops
   being mergeable midway, stop and report.
5. **New failures:** `scripts/merge-batch.sh blame <worktree> <pkg> <failed.txt> <prs>`
   maps each failing test to the PRs it depends on. Drop those PRs from the batch,
   comment the failure on each of them, and go back to step 2 with the rest. If a
   failure maps to no single PR, it comes from the combination: report it and
   merge nothing.
6. **Clean up:** `scripts/merge-batch.sh clean <worktree>`, then refresh the
   baseline (`/work baseline`) since the default branch moved.

Report as a table: PR | tier | merged / dropped (why) | test result, then one
line of 等你 if anything is left.
