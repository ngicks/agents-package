---
name: claude-statusline
description: Explains the `statusline` mod that draws "model @ effort | n% used | cwd | worktree" on a line below the hint line under the prompt. Use when the user asks why the status line shows something, or wants to change or debug it.
disable-model-invocation: true
---

# claude-statusline

This skill folder is also a Claude Code plugin named `statusline`.
Claude Code adopts every folder under `~/.claude/skills/` that holds `.claude-plugin/plugin.json`,
and loads its hooks module (`hooks/register.tsx`) as a mod.

## Where the status goes

The mod draws its status through a `ui.render` hook on `PromptHint`, the hint line under the prompt:

```
  ⏵⏵ auto mode on (shift+tab to cycle)
  Opus 5.5 (1M context) @ medium |   7% used | /home/u/src/agents-package/main | main
```

- The status always takes a new line below the hint line, in a column `Box`.
- The mod leaves the hint line itself, and its `tail`, untouched.

## What the status shows

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

- The values are read at session start, after each turn, and every 2 seconds.
  - They are kept in `$.state` (`statusline.parts`), and a change redraws the hint line.
- A terminal resize redraws the hint line, which cuts cwd to the new width.

## Files

- `hooks/register.tsx`: the hooks; reads session state and draws `PromptHint`.
- `hooks/format.ts`: pure formatting and width budgeting.
- `types/index.d.ts`: the `$.state` contract.
- `tests/`: run with `claude plugin test <this folder>`.

## Debugging

- `claude plugin validate <this folder>` lists what the module hooks and calls.
- `claude --debug` logs a line for every hook that failed.
- `claude plugin disable statusline@skills-dir` turns the line off.
