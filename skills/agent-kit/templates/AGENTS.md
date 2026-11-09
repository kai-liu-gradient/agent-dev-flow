# Notes for coding agents

Read these before changing code:

1. [LESSONS.md](LESSONS.md) - what recent work here got wrong, and the rule
   that would have caught it.
2. [docs/agents/workflow.md](docs/agents/workflow.md) - how work flows:
   sessions, worktrees, what to do without asking, review, merge tiers,
   wrap-up.
3. {{ADR_DIR}} - decisions already made. Do not reverse one in a PR; raise it
   under "To confirm" instead.

## Commands

| Purpose | Command |
|---|---|
| Test (full) | `{{TEST_CMD}}` |
| Lint | `{{LINT_CMD}}` |
| Typecheck | `{{TYPECHECK_CMD}}` |
| Build | `{{BUILD_CMD}}` |

Before the PR, run the full suite for the package you changed, not only the tests
you think are related: guard tests live in places a change does not touch. Run it
once, through the machine-wide lock, with two workers. See "Running tests" in
docs/agents/workflow.md.

## Shared foundations

Modules most of the code imports. A PR touching one runs the full suite (tier T3 in
docs/agents/workflow.md); other back-end PRs run only related tests.

{{FOUNDATIONS}}

## Hot files

Changed most often in the last 60 days (as of {{HOT_DATE}}). Two sessions
editing one of these at the same time will conflict, or merge into code that
passes alone and fails together. Work that touches them is done one after
another, never in parallel.

{{HOT_FILES}}

## Merge tiers

- **Tier A - the agent may merge** once every acceptance check in
  workflow.md has passed: {{TIER_A}}. At most {{TIER_A_MAX_LINES}} changed
  lines.
- **Tier B - a human merges**: {{TIER_B}}. Anything not listed in Tier A is
  Tier B.
- **Deploy**: {{DEPLOY_POLICY}}
