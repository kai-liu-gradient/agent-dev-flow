# /work coordinate #<epic>

You coordinate one epic. You split, dispatch, review and report. You do not
write product code yourself.

## Start

1. Read `AGENTS.md`, `docs/agents/workflow.md`, the epic, every sub-issue and
   every comment on them, and the open PRs that reference them.
2. Put a 「当前状态」 table at the top of the epic body (edit, do not append):
   `子项 | issue | PR | 状态 | 下一步`. Status is one of 未开始 / 进行中 /
   待 review / 待合并（B 级）/ 已合并 / 阻塞：<reason>.
3. Tick the epic's checklist for anything already merged.

## Loop

Repeat until every slice is merged or blocked on the user:

1. Pick the next slices whose dependencies are merged. At most 3 workers at
   once (their full test runs still queue on the machine-wide test lock). Slices touching the same hot file never run at the same time.
2. Start each worker as a background subagent with worktree isolation. Its
   prompt: the sub-issue number, "read AGENTS.md, docs/agents/workflow.md and
   the sub-issue to its last comment; follow the workflow's acceptance rules;
   open the PR with the repo template; do not merge; reply with the PR link,
   what you ran and what is under 待确认".
   Add to every worker prompt: "follow 'When tests and review run' in the work skill:
   only tests next to the change while building; at hand-over lint plus branch-related
   tests; no full suite; do not run /code-review yourself, the coordinator reviews".
3. When a worker returns a PR, start a review subagent with no other context:
   only the sub-issue and `gh pr diff <n>`. Ask for blocking problems only, and tell it not to run any tests.
   Send blocking findings back to a worker for the same PR. Two failed reviews
   on one PR: stop that slice, mark it 阻塞, and put both reviews in the summary.
4. Tier A PR with acceptance and review passed and 待确认 empty: merge it.
   Tier B: mark 待合并（B 级）. When two or more PRs are ready at once, merge them
   with `/work merge-batch` (one full test run for the batch) rather than one by one;
   for Tier B the user approves the batch list once.
5. After merges land, run `/work baseline` so workers compare against the new head.
6. Update the status table after every change. Keep the epic as the only record
   of progress; do not rely on this conversation.

## Report

Report to the user only when there is something for them, in this shape:

```
#<epic> 进度：<n>/<total> 已合并
| PR | 子项 | 改了什么 | 验证 | 等级 | 需要你决定 |
...
等你：<one line: which PRs to merge, which questions to answer>
```

Questions from workers are collected into 需要你决定, never asked one by one.
After posting a report, run `~/.claude/skills/work/scripts/hd.sh notify "#<epic> 等你" "<the 等你 line>"`
(herdr notification, or a desktop notification without herdr).

## When the user is away

If nothing needs the user and slices remain, keep going. If everything left is
waiting on the user, post the report as a comment on the epic as well, so it
is there when they return.

## Closing

When every slice is merged: tick the epic, write a final comment (what shipped,
部署后要做的事 collected from all PRs, follow-ups opened as issues), then `/wrap`.
