# Agent workflow

How a piece of work goes from an issue to a merged PR in this repository, and
how a session ends so it can be closed without losing anything.

## Sessions

- One task, one session, one worktree. Name the session after the issue or
  PR it serves: `claude -n "#123 short-name"`.
- The main checkout belongs to one coordinating session and is read-only for
  everyone else. Before editing files, move into a worktree. Two sessions
  committing from one checkout ship each other's files.
- At most 4 working sessions at once. To start a fifth, wrap one up and close
  it first.
- Progress lives in the issue (a task checklist) and the PR, not in the
  conversation. When asked "where are we", read the issue first.
- A second, unrelated topic means a new session. Say so instead of
  continuing.
- Closing a session keeps its transcript. `claude -r "<name>"` or
  `claude --from-pr <n>` brings it back, so a session that has run /wrap can
  always be closed.

## Do without asking

- Commit, push and open a PR once the work is done.
- The next item of an agreed plan or of the issue's checklist.
- Run tests, lint, builds and read-only checks.
- Address review comments; rebase when the PR conflicts.

## Ask first

- Any change of state on shared or production machines (restart, reload,
  write, delete), including when the user only asked how to do it.
- Merging a Tier B PR (see AGENTS.md).
- Leaving the agreed plan, or reversing a recorded decision.
- Changing a default that alters how the running system behaves.
- Anything that spends money or deletes data.
{{EXTRA_ASK_FIRST}}

When something is unclear mid-task, take the most conservative option, keep
going, and write the question under "To confirm" in the PR.

## Before starting

- Read the issue to its last comment. If the last word is "hold" or "not
  yet", stop and say so.
- Read LESSONS.md and the design notes for the area you are changing.

## Acceptance

Every check is reported in the PR with what was run and what it printed. A
check that was not run is listed as not run, never left out.

1. A test that fails without the change. Put the old code back, run the new
   test, see it fail for the right reason, restore the change.
2. For a bug, the test data comes from the report itself (the real payload,
   log line, screenshot text), not a similar sample made up for the test.
3. Every sibling of the bug gets the fix: grep for the same pattern in other
   callers, entry points and variants.
4. The full suite and lint for the changed package pass, apart from failures the
   shared baseline already has (`test-baseline.sh new`). A test already red on the
   default branch gets an issue naming its cause; it is not called "flaky" and
   shipped past.
5. UI changes include a screenshot. Schema changes include the migration or
   push step and the command that applies it on deploy.
6. Browser checks only look and open dialogs. Never press a button that acts
   on real data or real machines.

## Which tests a change needs

| Tier | The PR changes | Run before the PR |
|---|---|---|
| T0 | Docs only | Nothing |
| T1 | Front end only | Related tests, lint, build |
| T2 | Back end, normal code | Tests related to the change against the default branch (`jest --changedSince=origin/<default>`), lint |
| T3 | A shared foundation (AGENTS.md), schema or migrations, test config, or 1000+ changed lines | T2, then the full suite once under the lock |

Several ready PRs merge together with one full run (`/work merge-batch`); the
default branch's baseline is refreshed after merges (`/work baseline`). Say the
tier in the PR's 验证 section.

## Running tests

Several sessions share one laptop. Full suites are the heaviest thing they do,
so these rules hold for every session, worker and reviewer:

1. **While coding, run only related tests**: `jest --findRelatedTests <files>`,
   `vitest related <files> --run`, or the test files you touched.
2. **The full suite runs once, before opening the PR**, and through the lock:
   `~/.claude/skills/work/scripts/test-lock.sh <command>`. It lets one full suite
   run on the machine at a time; others wait their turn. Never bypass it.
3. **Two workers at most**: add `--maxWorkers=2` to jest and vitest.
4. **One run at a time per worktree.** If a run is in progress, wait for it;
   never start a second one, and never rerun just to grep the output differently.
   Write results to a file (`--json --outputFile=...`) and read that.
5. **Do not run the default branch's suite yourself.** Compare against the shared
   baseline: `~/.claude/skills/work/scripts/test-baseline.sh new <pkg> <result.json>` lists only new
   failures. If no baseline exists yet, one session runs the default branch under
   the lock and records it with `test-baseline.sh put`; everyone else reuses it.
6. **Reviewers never run tests.** They read the diff and the test results the PR
   reports.

## Review

Before a PR is handed to a human, run `/code-review` (or another review that
starts from a fresh context with only the issue and the diff). Fix what it
finds in the same session. Review is not a new session the human opens.

## Merge and deploy

Tier A: the agent merges once acceptance and review pass and "To confirm" is
empty, then reports what it merged. Tier B: the agent stops at "ready for
review" and waits. Deploy: see AGENTS.md.

After a PR is merged, never push to its branch again. Check
`gh pr view --json state` before every commit in a long session; new work
goes on a new branch from the latest default branch.

## Wrap-up

Before a session is closed, run `/wrap`:

1. Commit and push the session's own changes (never files it did not make).
2. Write a progress comment on the PR or issue: done, next, to confirm.
3. List background processes the session started (port-forwards, dev
   servers, loops) and stop them or say why they stay.
4. Say "safe to close" and how to reopen it.

## Writing to the user

- Conclusion first, then a few lines, then any question that needs a
  decision, on its own.
- When several items map to each other (gaps to steps, PRs to problems), use
  a table.
- The first time a message mentions an issue or PR number, add a few words
  saying what it is: "#953 (archive migration for agentless nodes)".
