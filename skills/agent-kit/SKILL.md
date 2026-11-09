---
name: agent-kit
description: Set up a repository for agent-driven development - AGENTS.md, LESSONS.md, a workflow contract (sessions, worktrees, review, merge tiers, wrap-up), a PR template and loop prompts - filled in from the repo itself. Use when the user says /agent-kit, asks to initialize a project for agents, to "set up the dev rules/开发规范" in a repo, or to refresh the hot-file list. Also lists running Claude sessions with close/wrap advice (`scripts/sessions.sh`) when the user asks which sessions they can close.
---

# agent-kit

Gives a repository the files that let any agent session start cold, finish
cleanly and be closed without losing anything. Templates are in `templates/`
next to this file. Everything project-specific is read from the repo, then
confirmed by the user once.

Modes: `/agent-kit` (init, default), `/agent-kit refresh` (recompute hot files
and commands only), `/agent-kit sessions [filter]` (run the session report).

## Sessions mode

When the user wants to know what each open session was doing (or fears losing
one), run `scripts/session-index.sh [filter]` (next to this file)
first: per session it prints the title, linked PRs with their state, the
user's last message and `claude -r <id>`, and saves the list as Markdown under
`~/.claude/session-index/`.

In herdr, `session-index.sh` also shows each session's workspace / tab, and
`scripts/wrap-panes.sh --list` / `--tab <id>` / `<pane-id>...` sends `/wrap` to those
sessions, waits, and prints how each ended (outside herdr it prints what to paste).
Only send /wrap to sessions the user chose.

Run `scripts/sessions.sh [filter]` and relay its
summary: how many can be closed now, how many need /wrap first, which shared
directories hold uncommitted changes whose owner is unknown. Never kill a
process; the user closes sessions.

## Init

### 1. Read the repo (no writes)

Collect, in one pass:

- Default branch, remote, and whether `gh` can see the repo (issue tracker).
- Existing agent files: `CLAUDE.md`, `AGENTS.md`, `LESSONS.md`,
  `docs/agents/`, `docs/adr/`, `.github/pull_request_template.md`. These are
  merged into, never overwritten.
- Test, lint, typecheck and build commands, from package.json scripts,
  Makefile, go.mod, pyproject, Cargo.toml, CI workflows. Prefer what CI runs.
- Hot files: the 10 most-changed files in the last 60 days, excluding tests,
  docs, lockfiles and generated files:
  `git log --since=60.days --name-only --pretty=format: | grep -v '^$' | sort | uniq -c | sort -rn`
- Shared foundations: the 8-15 source files imported by the most other files (count
  `require(` / `import ... from` targets), plus the app entry, config and the DB
  client modules. These decide when a PR needs the full suite.
- Related-test commands for each package (`jest --changedSince=origin/<default>`,
  `vitest related --run`), and the full-suite command with `--maxWorkers=2`.
- Tier B candidates (paths where a mistake is expensive): schema and
  migrations, Dockerfiles and image build, CI workflows, infra (k8s, helm,
  terraform), auth and permissions, billing and payments, data-fix scripts,
  deploy configuration, anything that runs on production machines. Name the
  real paths found, not categories.
- Tier A candidates: presentation-only UI, docs, tests.

### 2. Confirm once

Show one table: commands, hot files, Tier A paths, Tier B paths, PR language
(default: the language the user writes in for descriptions, English for code and comments), deploy policy
(default: humans deploy), Tier A line limit (default 800). Ask with
AskUserQuestion only about tiers and deploy policy; take the rest as shown
unless the user corrects it. Anything not listed in Tier A is Tier B.

### 3. Write

On a new branch `chore/agent-kit`, from the templates:

| Template | Target | When the target exists |
|---|---|---|
| `AGENTS.md` | `AGENTS.md` | Add the missing sections under an `## Agent workflow` heading |
| `CLAUDE.md` | `CLAUDE.md` | Add `@AGENTS.md` and `@LESSONS.md` lines if missing |
| `LESSONS.md` | `LESSONS.md` | Leave it; add the header rules only if it has none |
| `workflow.md` | `docs/agents/workflow.md` | Show a diff and ask before replacing |
| `loops.md` | `docs/agents/loops.md` | Same |
| `pull_request_template.md` | `.github/pull_request_template.md` | Add missing sections only |

Replace every `{{...}}` placeholder. A placeholder with no value becomes
`(not set - fill in)`, never an invented value.

If the user's personal memory holds pitfalls about this repo, offer to move
the code-related ones into `LESSONS.md` in its format; machine- and
server-specific ones stay in memory.

### 4. Hand over

Commit, push, open a PR, do not merge it. Reply with: the PR link, the files
written, any placeholder left unset, and the three habits from
`docs/agents/workflow.md` the user does themselves (name sessions, /wrap
before closing, at most 4 working sessions).

## Refresh

Recompute commands and hot files, update the two sections in `AGENTS.md`,
open a PR. Leave tiers alone unless the user asks.
