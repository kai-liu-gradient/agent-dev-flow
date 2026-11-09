# Loops

Standing `/loop` sessions that pick up work by themselves. Each runs in its
own named terminal (`claude -n "loop: issues"`) and stops when that terminal
closes. They take work as far as "PR ready"; merging follows the tiers in
AGENTS.md. Start with loop 1 and 3; add loop 2 once the first two run
cleanly for a few days.

## Loop 1 - issues

```
/loop You are the issue loop for {{REPO}}. Each round:
1. Find open issues labelled ready-for-agent without in-progress. Take the oldest.
   If 2 workers are already running, take nothing this round.
2. Read the whole issue to its last comment. If the last word is "hold" or
   "not yet", skip it and note it in your summary.
3. Label it in-progress. Start a background subagent in its own worktree with
   docs/agents/workflow.md as its contract. Work touching a hot file (AGENTS.md)
   waits for any other worker on that file.
4. When the worker hands back a PR, start a fresh-context review subagent on the
   issue and the diff. Send findings back to the worker until it passes.
5. Then: Tier A -> merge and comment what was merged. Tier B -> label
   needs-human and comment the PR link on the issue.

Exceptions:
- Too vague to write a checkable acceptance test: don't start; list the
  questions on the issue and label needs-info.
- Needs production data, machines or secrets: don't start; label needs-human
  and say why.
- Fails review twice: stop, label needs-human, paste both reviews on the PR.
- Unsure whether to do it: don't; put it in the summary.
```

## Loop 2 - pull requests

```
/loop You are the PR loop for {{REPO}}. Each round, for every open PR by {{OWNER}}:
1. New review comments: fix them in that PR's worktree and reply how.
2. Failing CI: first check whether the job never started (billing or runner
   problem); if so, note it on the PR and change nothing. Otherwise fix it.
3. Conflicts with {{DEFAULT_BRANCH}}: rebase and rerun the suite.
Only existing PRs; never start new work.

Exceptions:
- Comments contradict each other or reverse a recorded decision: change
  nothing, label needs-human.
- The same CI failure twice after a fix: stop, label needs-human.
```

## Loop 3 - nightly lessons

```
/loop Run once after 23:00 local time; skip every other round. You are the lessons loop for {{REPO}}:
1. Read every merge after the reviewed-through commit at the top of LESSONS.md.
2. Find what was fixed again later, reverted, sent back by review twice, or
   merged with thin verification in its PR.
3. For each kind of mistake, add or update a lesson in LESSONS.md in its format,
   with evidence and the Seen count.
4. A lesson seen on 3 separate days: draft the standing rule into AGENTS.md or
   docs/agents/workflow.md and mark it Moved.
5. Move the reviewed-through marker; open a PR titled "LESSONS: <date>".
Never change product code in this loop.
```
