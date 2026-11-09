---
name: work
description: Take a requirement from one sentence to merged PRs with the right amount of process - sizes it (small / medium / large), then runs the matching flow end to end - worktree, implementation, tests, fresh-context review, PR, tiered merge, wrap-up; for large work it writes an epic and starts a named coordinator session in a new herdr tab. Use when the user types /work, /work <需求>, /work 小|中|大 <需求>, /work coordinate #<epic>, or says 新需求 / 开始做 / 帮我做这个需求.
---

# /work

Needs: the `grilling` and `code-review` skills, `scripts/test-lock.sh` and `scripts/test-baseline.sh` here, and `wrap` from this same package.
`gh`, `git`, `jq`. herdr is optional (used to open the coordinator tab).

One entry point for every requirement. The user should only have to answer
questions once, decide Tier B merges, and deploy. Everything else runs here.

Repo rules come first: read `AGENTS.md` and `docs/agents/workflow.md` (or the
repo's equivalents) before acting; where they differ from this file, they win.
Talk to the user in the language they write in. Write PR descriptions in the language
the repo's AGENTS.md asks for (default: the user's language); code and comments in English.

## Arguments

| Input | Meaning |
|---|---|
| `/work <需求>` | Size it yourself, say the size in one line, go |
| `/work 小 / 中 / 大 <需求>` | The user fixed the size; do not re-argue it |
| `/work #<issue>` | Start from an existing issue; size it from its scope |
| `/work fulltest [pkg]` | Run the full suite now, on this branch, through the lock (see "When tests and review run") |
| `/work merge-batch #a #b ...` | Merge several ready PRs with one full test run: read `merge-batch.md` next to this file and follow it |
| `/work baseline` | Refresh the default branch's failing-test baseline (see "Which tests a change needs") |
| `/work coordinate #<epic>` | Run as the coordinator of that epic: read `coordinator.md` next to this file and follow it instead of the sections below |
| `/work` alone | Ask for the requirement in one short question |

## 1. Size it

| Size | Signal |
|---|---|
| 小 small | One area, under ~1 hour, no open product question. A bug, copy, one component. |
| 中 medium | One feature with clear edges, half a day to a day, a few decisions to make. |
| 大 large | Several PRs, front and back end, days of work, or touches data model, infrastructure and UI together. |

Bump one size up when it touches a Tier B area (the repo's AGENTS.md lists them;
typically schema and migrations, infrastructure, billing, auth) and the user has
not decided the approach yet. Say the result
as one line, e.g. `判断为「中」：要改 API 和设置页，有 2 个需要你定的点。` and continue
without waiting, unless the user overrides.

## 2. Name the session

`scripts/hd.sh name "<小|中|大> <short title>"`. In herdr it renames the tab; elsewhere
it prints the `claude -n` hint, which you pass on once.

## herdr (optional)

`scripts/hd.sh` wraps every herdr call and falls back when herdr is absent, so
call it the same way either way:

| Command | In herdr | Without herdr |
|---|---|---|
| `hd.sh name <label>` | renames this tab | prints a `claude -n` hint |
| `hd.sh notify <title> <body>` | herdr notification with sound | macOS notification, else terminal bell |
| `hd.sh spawn <tab> <name> <prompt> [cwd]` | new tab, named claude session, first prompt sent | prints the commands to run |

Notify whenever a turn ends waiting on the user after more than a few minutes of
work (Tier B PR ready, split table to confirm, questions collected).

## 3a. Small

1. Enter a worktree (`EnterWorktree`, or `git worktree add .claude/worktrees/<slug> -b <type>/<slug> origin/<default>`).
2. Implement in short loops: change, run the tests next to the change, look at the
   result (layer 1 in "When tests and review run"). No full suite, no review here.
3. When done: lint, branch-related tests, one `/code-review` (layer 2). Fix what it
   finds without starting another review round.
4. Open the PR with the repo's template.
5. Merge if Tier A and every acceptance check passed; otherwise stop, say
   `PR #n 就绪，B 级，等你说合`, and `hd.sh notify "PR #n 等你合" "<title>"`.
6. Run `/wrap`.

No questions to the user unless something is genuinely ambiguous; then take the
conservative option and put it under 待确认.

## 3b. Medium

1. **Decisions first.** Run `/grilling` on the requirement, but batch the questions:
   at most 2 rounds of AskUserQuestion, each with up to 4 questions, every
   question with a recommended option first. Stop asking once the remaining
   unknowns have a safe default.
2. **Write the issue** (`gh issue create`): 背景, 已定决策 (the user's own words
   and the date), 默认处理 (what to do when the issue does not cover a case),
   验收标准 as checks that can be run, label `ready-for-agent`.
3. Continue with 3a steps 1-6 in this session, linking the PR to the issue
   (`Closes #n`). Tick the issue's checklist as you go.

## 3c. Large

1. **Decisions first**, as in 3b step 1 (up to 3 rounds for large work).
2. **Propose the split** before creating anything: a table of vertical slices
   (title | what it delivers | depends on | touches hot files? | tier). Slices
   that touch the same hot files (listed in AGENTS.md) are ordered, not parallel.
   Wait for the user to confirm or edit this table. This is the one place in
   the large flow where you wait.
3. **Create** the epic issue (decisions, defaults, acceptance, the slice table as a
   task list) and one sub-issue per slice, each labelled `ready-for-agent`. Write
   an ADR in `docs/adr/` if an architectural choice was made.
4. **Start the coordinator**:
   `scripts/launch-coordinator.sh <epic-number> "<short title>"` (the `scripts/` folder next to this file;
   usually `~/.claude/skills/work/scripts/`)
   It goes through `hd.sh spawn`: in herdr a tab `主控 #<n> <title>` opens with
   `claude -n "epic #<n> <title>"` already sent `/work coordinate #<n>`; outside herdr
   it prints the commands, and you show them to the user. Exit code 3 means the new
   tab is waiting for the user to trust the folder: tell them to confirm it there
   and send the printed prompt. Never answer a trust prompt for them.
5. Tell the user, in at most 5 lines: the epic link, the coordinator tab name,
   what they will be asked for (Tier B merges and the decisions in the
   coordinator's summary), and that this session will now wrap up.
6. Run `/wrap` here. This session's context is full of discussion; the
   coordinator starts clean from the epic.

## When tests and review run

Three layers. Each has a fixed moment; nothing runs outside it.

| Layer | When | What | Never |
|---|---|---|---|
| 1. Iterating | After every change while building | Only the tests next to the change: the test files for the modules you edited, plus `jest --findRelatedTests <files>` / `vitest related --run <files>` | No full suite, no review, no lint of the whole repo |
| 2. Handing over | Once, when the work is done and the PR is about to open | Lint; tests related to the whole branch (`jest --changedSince=origin/<default>`, `vitest related` on the branch's files); one `/code-review` | No full suite |
| 3. Full suite | Only when asked: `/work fulltest [pkg]`, and once per `/work merge-batch` | The package's full suite under the lock, compared with the baseline | Not per PR, not per change |

**Review:** once, at layer 2, on the PR's diff, without running tests. Fixing its
findings does not start another full review; only fixes for findings marked
blocking get a second look, limited to the lines that changed. Skip the separate
review for docs-only changes and for Tier A changes under ~50 lines: read your own
diff once instead.

**Shared foundations** (listed in AGENTS.md: modules most of the code imports,
schema, test config): touching one does not trigger the full suite. Write
`改了公共底座 <file>，建议合并前 /work fulltest` in the PR's 待确认 and in your reply;
the user decides. The batch merge still runs the full suite before anything lands.

**`/work fulltest [pkg]`:** in the current worktree, for each package the branch
touches (or the one named), run the full suite through `scripts/test-lock.sh` with
`--maxWorkers=2 --json --outputFile=<file>`, then `scripts/test-baseline.sh new <pkg>
<file>`. Report new failures only, as a list of test files with the first error line.

**`/work baseline`:** in a worktree at the latest default branch, run each package's
full suite under the lock with `--json --outputFile`, then
`scripts/test-baseline.sh put <pkg> <file>`. Run it after a batch merge, or when
`test-baseline.sh get` says the baseline is from an older commit.

## Running tests on a shared machine

Several sessions share one laptop. Full suites are the heaviest thing they do,
so these rules hold for every session, worker and reviewer:

1. **While coding, run only related tests**: `jest --findRelatedTests <files>`,
   `vitest related <files> --run`, or the test files you touched.
2. **A full suite (`/work fulltest`, a batch, or the baseline) runs through the lock:**
   `scripts/test-lock.sh <command>` (next to this file). It lets one full suite
   run on the machine at a time; others wait their turn. Never bypass it.
3. **Two workers at most**: add `--maxWorkers=2` to jest and vitest.
4. **One run at a time per worktree.** If a run is in progress, wait for it;
   never start a second one, and never rerun just to grep the output differently.
   Write results to a file (`--json --outputFile=...`) and read that.
5. **Do not run the default branch's suite yourself.** Compare against the shared
   baseline: `scripts/test-baseline.sh new <pkg> <result.json>` lists only new
   failures. If no baseline exists yet, one session runs the default branch under
   the lock and records it with `test-baseline.sh put`; everyone else reuses it.
6. **Reviewers never run tests.** They read the diff and the test results the PR
   reports.

## Rules that apply to every size

- Never work in the main checkout; one task, one worktree.
- Before every commit in a long session: `gh pr view --json state`. Never push to
  a merged PR's branch.
- Never change state on shared or production machines without an explicit go.
  Never deploy.
- Never ask "要我继续吗？" for the next step of the agreed flow. Do it.
- Mid-task uncertainty: conservative default, keep going, record it under 待确认.
- End every turn that needs the user with one short line saying exactly what
  they need to do, e.g. `等你：合 #1012（B 级）`.
