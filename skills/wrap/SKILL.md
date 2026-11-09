---
name: wrap
description: End a working session so it can be closed without losing anything - commit and push this session's own changes, write a progress note on the PR or issue, stop or list background processes it started, then say it is safe to close and how to reopen it. Use when the user says /wrap, 收工, "wrap up", "can I close this", or is about to close a session.
---

# /wrap

The goal is a session that can be closed with nothing left only in its
conversation. Do the steps in order; report at the end in a few lines.

1. **Where am I.** Branch, worktree path, the PR for this branch if any, and
   its state (`gh pr view --json number,state,url`). If the PR is MERGED or
   CLOSED, new commits go on a new branch from the latest default branch,
   never on this one.

2. **Commit only my own changes.** `git status` and compare against what this
   session actually edited. If the directory holds changes this session did
   not make (a shared checkout), do not commit them: list them and tell the
   user. Commit the rest with a message that says what and why, push, and
   open a PR if the work is ready and has none. Do not merge.

3. **Write the progress note** as a comment on the PR, or on the issue when
   there is no PR, in the language the project uses for PRs:
   - Done: what is finished and verified (with what was run)
   - Next: the next concrete step, enough for a new session to start cold
   - To confirm: decisions waiting for the user, or "none"
   If the issue has a task checklist, tick what is done.

4. **Background processes.** List what this session started that is still
   running: port-forwards, dev servers, watchers, `/loop`, background
   commands, subagents. Stop the ones only this session needs. For any that
   must keep running, say what it is and why.

5. **Mark the tab.** `~/.claude/skills/work/scripts/hd.sh name "✓ 可以关 <short title>"`
   when safe to close, or `"⚠ 未完 <short title>"` when not, so the tab bar shows it.
   (Without herdr this prints a hint; skip relaying it.)

6. **Report**, then stop:
   - `safe to close` (or what is blocking it)
   - how to reopen: `claude -r "<session name>"` or `claude --from-pr <n>`
   - the one thing waiting for the user, if any

**`/wrap 关` (or 收工并关闭):** after the report, if safe to close, run
`~/.claude/skills/work/scripts/hd.sh close-self 5`. In herdr the pane closes 5 seconds
later; without herdr, tell the user to close the terminal.

Never delete branches, worktrees or files during /wrap, and never change state
on shared or production machines.
