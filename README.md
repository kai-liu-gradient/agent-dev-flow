# agent-dev-flow

**English** | [简体中文](README.zh-CN.md)

Development-workflow skills for Claude Code. One command takes a requirement of any size through the right process, every session can be closed safely, and a new repository gets its agent rules in one step.

## Install

### Ask your agent (one sentence)

Paste this into Claude Code:

```text
Install the agent-dev-flow skills: follow the "For agents" section of https://github.com/kai-liu-gradient/agent-dev-flow/blob/main/README.md
```

### Or run it yourself

```bash
gh repo clone kai-liu-gradient/agent-dev-flow ~/workspace/agent-dev-flow
cd ~/workspace/agent-dev-flow && ./install.sh --with-optional
```

| Option | Effect |
|---|---|
| *(none)* | Link this repo's skills and install the required dependencies |
| `--with-optional` | Also install the optional dependencies (browser checks) |
| `--copy` | Copy the skills instead of symlinking them |
| `--check` | Report what is installed and what is missing; change nothing |

- Skills are **symlinked** into `~/.claude/skills/`, so `git pull` in this repo updates them.
- A skill with the same name already there is moved to `~/.claude/skills/.backup-<time>/`, never deleted.
- Dependency skills are installed with `npx skills add`. Ones already present are skipped, so the script is safe to rerun.
- If GitHub is slow or unreachable, set a proxy first, e.g. `export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890`.

## What's inside

| Skill | Usage | What it does |
|---|---|---|
| `work` | `/work <requirement>`, `/work small\|medium\|large <requirement>` (or `小/中/大`), `/work #<issue>`, `/work coordinate #<epic>` | Sizes the requirement, then runs the whole flow: worktree → implementation → full test suite → `/code-review` → PR → merge by tier → wrap-up. Large work becomes an epic with sub-issues and a coordinator session |
| `wrap` | `/wrap`, or say "wrap up" / "收工" | Commits the session's own changes, writes progress on the PR or issue, lists background processes, then says whether the session can be closed and how to reopen it |
| `agent-kit` | `/agent-kit`, `/agent-kit refresh`, `/agent-kit sessions` | Writes `AGENTS.md`, `LESSONS.md`, `docs/agents/workflow.md`, `docs/agents/loops.md` and a PR template for a repository, filled in from the repo itself; or lists the Claude sessions running on this machine |

Read-only scripts in `skills/agent-kit/scripts/`:

- `sessions.sh [filter]` - open sessions grouped by directory, with advice: close / wrap first / find the owner.
- `session-index.sh [filter]` - each session's title, linked PRs and their state, your last message and the reopen command; also saved under `~/.claude/session-index/`.
- `wrap-panes.sh` - herdr only: send `/wrap` to chosen sessions and collect their answers.

## Start in a repository

1. Open Claude Code in the repo and run `/agent-kit` once. It reads the repo, asks you to confirm the merge tiers and the deploy policy, and opens a PR with the rules. Merge it.
2. For every requirement: `/work <one sentence>`.
3. Before closing a session: `/wrap`.

It works on any GitHub repository: commands, hot files, tiers and PR language are read from the repo's own `AGENTS.md`, not from this package.

## The flow

| Size | What runs | What you do |
|---|---|---|
| Small | worktree → implement → tests → review → PR → merge if Tier A → wrap | Say "merge" on Tier B PRs |
| Medium | One batch of questions → issue → the small flow | Answer the questions once; merge Tier B PRs |
| Large | Questions → proposed split → epic and sub-issues → a coordinator session that dispatches workers, reviews their PRs and keeps a status table on the epic | Answer questions, confirm the split, then read the coordinator's summary and merge Tier B PRs |

**Tier A** (the agent may merge): presentation-only UI, docs and tests, under a line limit, with tests and review passed. **Tier B** (a person merges): everything else. Each repo defines its own tiers in `AGENTS.md`. Deploying is always done by a person.

Three habits: name sessions when you start them (`claude -n "<name>"`), `/wrap` before closing, at most 4 working sessions at a time.

## With herdr (optional)

When running inside [herdr](https://herdr.dev/tui/), these happen automatically. Without it, every step falls back to something that still works.

| Moment | Inside herdr | Without herdr |
|---|---|---|
| `/work` starts | Tab renamed to the size and title | Hint to start with `claude -n "<name>"` next time |
| Large work | New tab "主控 #epic" with a named session already sent `/work coordinate #epic` | The commands are printed for you to run |
| Waiting on you | herdr notification | macOS notification, else a terminal bell |
| `/wrap` | Tab marked "✓ 可以关" or "⚠ 未完"; `/wrap 关` closes the pane after 5 seconds | Tells you whether to close the terminal |
| `session-index.sh` | Shows each session's workspace / tab | Shows the terminal device |
| Closing many sessions | `wrap-panes.sh --tab <id>` sends `/wrap` to the tab's idle sessions and summarises | Tells you to send `/wrap` in each |

If a new tab stops at Claude Code's "trust this folder?" prompt, the script does not answer it for you: it notifies you and prints the prompt to send after you confirm.

Every herdr call goes through `skills/work/scripts/hd.sh`, which can be used on its own:

```bash
hd.sh available | name <label> | notify <title> [body] | spawn <tab> <session-name> <first-prompt> [dir] | where <session-id> | close-self [seconds]
```

## Dependencies

The full list is [deps.json](deps.json); `install.sh` reads it.

| Dependency | Kind | Source | Used for |
|---|---|---|---|
| `grilling` | required skill | mattpocock/skills | Settle the decisions once before medium and large work |
| `code-review` | required skill | mattpocock/skills | Fresh-context review before a PR reaches a person |
| `agent-browser` | optional skill | vercel-labs/agent-browser | Screenshots and headless checks of UI changes |
| `chrome-use` | optional skill | leeguooooo/chrome-use | Check pages in your logged-in Chrome |
| `git`, `gh`, `jq`, `npx` | required tools | | Worktrees, issues and PRs, scripts, installing skills |
| `herdr`, `lsof` | optional tools | | herdr integration; locating session directories |

Requirements: the repository is on GitHub and `gh` is logged in.

To add a dependency: add it to `deps.json` and to the `Needs:` line at the top of each SKILL.md that uses it.

## For agents

Steps to install this package for the user. Run them in order, report the final output of `install.sh`, and do not change anything else.

1. Check the tools: `git`, `gh` (logged in: `gh auth status`), `jq`, `npx`. If one is missing, tell the user how to install it and stop.
2. Get the repo. If `~/workspace/agent-dev-flow` exists, run `git -C ~/workspace/agent-dev-flow pull --ff-only`. Otherwise run `gh repo clone kai-liu-gradient/agent-dev-flow ~/workspace/agent-dev-flow` (the repo may be private; `gh` uses the user's login). Use another directory only if the user names one.
3. Run `./install.sh --with-optional` in the repo.
4. If it reports "could not reach GitHub", ask the user for their proxy (or use the one they already use, e.g. a `proxy` shell alias), export `https_proxy` / `http_proxy` and run it again. It skips what is already installed.
5. If it reports other ✗ items, show them to the user; do not work around them.
6. Finish with `./install.sh --check` and tell the user: which skills are installed, which optional items are missing, and the next step: run `/agent-kit` once in each repository, then `/work <requirement>`.

The skills take effect in new Claude Code sessions.

## License

Private repository; no license granted yet.
