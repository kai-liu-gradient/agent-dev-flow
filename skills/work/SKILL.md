---
name: work
description: Take a requirement from one sentence to merged PRs with the right amount of process - sizes it (small / medium / large), then runs the matching flow end to end - worktree, implementation, tests, fresh-context review, PR, tiered merge, wrap-up; for large work it writes an epic and starts a named coordinator session in a new herdr tab. Use when the user types /work, /work <需求>, /work 小|中|大 <需求>, /work coordinate #<epic>, or says 新需求 / 开始做 / 帮我做这个需求.
---

# /work

Needs: the `grilling` and `code-review` skills, and `wrap` from this same package.
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
| `/work coordinate #<epic>` | Run as the coordinator of that epic: read `coordinator.md` next to this file and follow it instead of the sections below |
| `/work` alone | Ask for the requirement in one short question |

## 1. Size it

| Size | Signal |
|---|---|
| 小 small | One area, under ~1 hour, no open product question. A bug, copy, one component. |
| 中 medium | One feature with clear edges, half a day to a day, a few decisions to make. |
| 大 large | Several PRs, front and back end, days of work, or touches schema plus pods plus UI. |

Bump one size up when it touches a Tier B area (schema, pods/bootstrap, k8s,
billing, auth) and the user has not decided the approach yet. Say the result
as one line, e.g. `判断为「中」：要改 API 和设置页，有 2 个需要你定的点。` and continue
without waiting, unless the user overrides.

## 2. Name the session

- In herdr (`$HERDR_TAB_ID` is set): `herdr tab rename "$HERDR_TAB_ID" "<小|中|大> <short title>"`.
- Otherwise tell the user once: for next time, start with `claude -n "<title>"`.

## 3a. Small

1. Enter a worktree (`EnterWorktree`, or `git worktree add .claude/worktrees/<slug> -b <type>/<slug> origin/<default>`).
2. Implement. Run the full suite of the changed package and lint. Compare failures
   against the default branch; only new failures count.
3. Run `/code-review` on the diff; fix what it finds.
4. Open the PR with the repo's template.
5. Merge if Tier A and every acceptance check passed; otherwise stop and say
   `PR #n 就绪，B 级，等你说合`.
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
   In herdr it opens a tab `主控 #<n> <title>`, starts `claude -n "epic #<n> <title>"`
   and sends it `/work coordinate #<n>`. Outside herdr it prints the two commands
   for the user to run.
5. Tell the user, in at most 5 lines: the epic link, the coordinator tab name,
   what they will be asked for (Tier B merges and the decisions in the
   coordinator's summary), and that this session will now wrap up.
6. Run `/wrap` here. This session's context is full of discussion; the
   coordinator starts clean from the epic.

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
