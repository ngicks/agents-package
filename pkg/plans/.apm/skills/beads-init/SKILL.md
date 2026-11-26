---
name: beads-init
description: Initialize beads (`bd`). Use only when another skill or the user asks for it.
---

# beads-init

Set up beads for this repository by running one script.

```bash
BEADS_ACTOR=<actor> scripts/bd-init.sh
```

- The script is bundled in this skill's `scripts/` directory.
- `<actor>` is `<agent>/<model>`: the agent harness in lowercase (`claude`, `codex`, `opencode`)
  and the model id it is running, e.g. `claude/claude-fable-5-1`.
  - Drop the `/<model>` part only when the model is genuinely unknown.
  - Never use the user's name.
- The script is idempotent. Rerun it whenever the git origin changes or the skill is updated.
- Never run raw `bd init`, `bd bootstrap`, or `bd hooks install`, and never pass a prefix of your own.

## Requirements

- `bd` on `PATH`. Missing `bd` is blocking: the script prints a note and initializes nothing. Tell the user and stop.
- `hk` on `PATH` for the git hooks. Missing `hk` is not blocking: the script says so and skips the hooks. Tell the user.
- A git repository in one of the two layouts below.

## Supported layouts

The database lives at the repository root, the parent of the git common directory.
Every worktree of the repository shares that one database.

| Layout | Git directory | Database | Run the script from |
|---|---|---|---|
| Plain clone | `<root>/.git/` | `<root>/.beads/` | the repository root or below |
| Bare root | `<root>/.bare/`, with `<root>/.git` a file pointing at it; worktrees are subdirectories of `<root>` | `<root>/.beads/` | a worktree |

- In a bare-root layout prefer a worktree over the bare root itself.
  - From the bare root the script initializes beads and skips the hk wiring, because `hk.pkl` belongs in a worktree.
  - It prints a note; rerun it from a worktree to finish.
- In a plain clone `bd init` commits `.beads/config.yaml`, `.beads/metadata.json`, `.beads/README.md`, `.beads/.gitignore`, and a root `.gitignore` entry onto the current branch.
  - A changed origin URL adds one more commit, `bd: update sync.remote`.
  - Tell the user about these commits.
- In a bare-root layout nothing is committed: `.beads/` sits outside every worktree.

## What the script does

- Turns off bd's anonymous usage metrics (`bd metrics off`).
- Derives the issue prefix from the repository root directory name. `BEADS_PREFIX=<prefix>` overrides it.
- On first init it checks whether the git `origin` already holds Dolt data (`refs/dolt/data`).
  - If so, it clones that history, so the existing issues and their prefix are adopted.
  - Otherwise it creates an empty database.
- Mirrors the git `origin` URL as the Dolt remote `origin` in `git+https://`, `git+ssh://`, or `git+file://` form.
  - It touches the remote only when the URL differs.
- Pushes nothing. `bd dolt push` and `bd dolt pull` are the user's job; never run them.
- Finishes by running `scripts/hk-init.sh`, which wires the hk hooks.

## After the script

- Verify with `bd --actor <actor> info -q`: exit status 0 means beads is initialized.
- When the script reports that it wrote `hk.pkl` or `.hk/beads.pkl`, tell the user to include them in the next commit.
  A worktree without them runs no hooks.
- When it exits 1 with wiring instructions, apply them to `hk.pkl` and rerun.
- Report to the user: the database location, the prefix, the Dolt remote (`bd dolt remote list`), and any commits or files the script produced.

Read [reference/hk.md](reference/hk.md) for what the hooks do, how the wiring merges with an existing `hk.pkl`, and where project steps belong.
