---
name: claude-statusline
description: Explains the `statusline` mod that draws "model @ effort | n% used | cwd | worktree" under the prompt. Use when the user asks why the status line shows something, or wants to change or debug it.
disable-model-invocation: true
---

# claude-statusline

This skill folder is also a Claude Code plugin named `statusline`.
Claude Code adopts every folder under `~/.claude/skills/` that holds `.claude-plugin/plugin.json`,
and loads its hooks module (`hooks/register.ts`) as a mod.

## What the line shows

The mod pins one status line under the prompt:

```
⚠ statusline: Opus 5.5 (1M context) @ medium |   7% used | …/agents-package/main | main
```

- Model: the session's model id turned into its display name.
  - An id the mod does not recognize is shown as is.
- Effort: whichever changed last of
  - `effortLevel` in settings (what `/effort` saves),
  - the effort sent with the latest main-loop model request.
  - Omitted while neither is known.
- Context used: `$.session.usage().context.percent`; `0` until the first response.
- cwd: the session's directory.
  - Cut from the left with `…` so the whole line fits the terminal width.
  - Dropped when nothing of it fits.
- Worktree: the git worktree id (basename of `git rev-parse --absolute-git-dir` under `worktrees/`).
  - Omitted outside a linked worktree.

## Refresh

- At session start, after each turn, and every 2 seconds.
- On a terminal resize, through a `ui.render` hook on `PromptHint`.

## Files

- `hooks/register.ts`: the hooks; reads session state and calls `$.ui.status`.
- `hooks/format.ts`: pure formatting and width budgeting.
- `tests/format.test.ts`: run with `claude plugin test <this folder>`.

## Debugging

- `claude plugin validate <this folder>` lists what the module hooks and calls.
- `claude --debug` logs a line for every hook that failed.
- `claude plugin disable statusline@skills-dir` turns the line off.
