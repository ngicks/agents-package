# hk hooks wired by beads-init

Detail for the hooks that `scripts/hk-init.sh` installs: the agent commit
trailer and the Dolt sync on `git push` and `git pull`.

The scripts were run against bd 1.3.4 and hk 2.14.0 on Git 2.56.

`scripts/hk-init.sh` needs a worktree. Outside one, such as the root of a
bare-root layout, it prints a note and exits 0 without wiring anything.

## Mark agent commits

Commits made by a coding agent carry an `Executed-By: <agent>` trailer so
they can be told apart from human commits in `git log`. The trailer is
stamped by the `prepare-commit-msg` step in `reference/beads.hk.pkl`, an
`hk` config bundled in this skill, running as the repository's
`prepare-commit-msg` git hook. That file is the single source of the hook
logic; there is no separate script.

- The config is wired in by `scripts/hk-init.sh`, which `bd-init.sh` runs
  for you (see **Wiring with hk** below). Never install git hooks by any
  other route: no `bd hooks install`, no hand-written `.git/hooks` files,
  no raw `hk install` outside the script.
- The step detects the agent on its own — never set an environment
  variable or add the trailer by hand. It walks the process ancestry for
  `claude`, `codex`, or `opencode` (nearest wins, so an agent nested inside
  another is the one recorded), and falls back to the `CODEX_THREAD_ID`,
  `OPENCODE`, and `CLAUDECODE` environment variables in that order because
  the Codex sandbox hides the process tree.
- A human committing from a plain shell gets no trailer. Amend and reword
  keep a single trailer; merge and squash messages are left untouched.
- Commit normally. Do not strip or edit the trailer if you rewrite a
  message.

### Wiring with hk

`reference/beads.hk.pkl` is a complete `hk` config for a repository that
keeps its issues in beads. `scripts/hk-init.sh` installs it; `bd-init.sh`
runs that script on every path, so running `bd-init.sh` is enough and
there is no separate step to remember. The name is deliberately not one
`hk` looks for, so the copy inside the skill directory is inert wherever
the skill is installed; skills are not installed at a stable path, so the
repository keeps its own copy under `.hk/` and `hk.pkl` references that.

What the script does, in order, all of it idempotent:

- Copies `reference/beads.hk.pkl` to `.hk/beads.pkl` at the worktree root
  whenever the two differ. The copy's `amends` line is pinned to the hk
  version `hk.pkl` already pins, else the version the previous copy
  pinned, else the installed `hk`; a pin from another major is replaced
  by the installed version because the Pkl schema is not compatible
  across majors (a 1.x copy fails to evaluate under hk 2.0 with `union
  property 'command' has no selected default`).
- Makes `hk.pkl` amend the copy. With no `hk.pkl` it writes the one-liner
  `amends ".hk/beads.pkl"`. When `hk.pkl` already amends hk's `Config.pkl`
  package, that single line is rewritten to `amends ".hk/beads.pkl"` and
  the rest is untouched: Pkl's amend chain merges the project's `hooks`
  and `steps` with the beads hooks, so an existing `pre-push` keeps its
  steps and gains `beads-push`, and top-level `steps` still produce the
  implicit `check`, `fix`, and `pre-commit` hooks. A `hk.pkl` that amends
  anything else is left alone; the script prints the manual wiring
  (`import ".hk/beads.pkl" as beads` and `hooks = (beads.hooks) { … }`)
  and exits 1 — do that edit, then rerun.
- Runs `hk install`. On Git 2.54+ hk writes config-based hooks
  (`hook.hk-<event>.command`) into the shared repository config, so one
  install covers every worktree and `.git/hooks/` stays untouched; older
  Git gets script shims. When hooks are installed globally
  (`hk install --global`) hk skips the per-repo install by itself, so the
  script is safe in either setup.
- With `hk` not installed it prints a note and exits 0: planning goes on,
  agent commits just carry no trailer. Tell the user.

`hk.pkl` and `.hk/beads.pkl` are committed files. A worktree that does not
have them runs no hooks at all — the installed hook exits silently when it
finds no `hk.pkl` — so when the script reports that it wrote them, include
them in the next commit.

- `prepare-commit-msg`: the `Executed-By` trailer. The shell body is
  embedded in the config as a Pkl raw string, so the hook depends on nothing
  outside `.hk/beads.pkl`. For a hook manager other than `hk`, lift that
  string into a script and pass the message file and source as `$1`, `$2`.
  hk echoes the step's command while it runs, so a non-interactive commit
  prints the whole body once; that is progress output, not an error.
- `pre-push`: `bd dolt push -q`, so `git push` ships the Dolt history
  (`refs/dolt/data`) with the code. This is how the user's "syncing is my
  job" rule is met without anyone typing `bd dolt push`: an agent's
  `git push` pushes the plan implicitly.
- `post-merge`: `bd dolt pull -q`, so `git pull` refreshes the local plan.
- Both Dolt steps have `allow_failure = true`: no network or a diverged
  remote prints a warning and does not block the code push or merge. Drop it
  to be forced to resolve Dolt first.
- `bd dolt push` assumes `dolt.auto-commit` is `on` (bd's default). With
  `batch`, prefix the step with `bd dolt commit -q;`.
- The database lives at the repository root, so `bd` finds it from any
  worktree; the hooks live in the shared repository config, so one install
  covers every worktree.
- Add project steps in `hk.pkl`, never in `.hk/beads.pkl`: the script
  overwrites the copy whenever the skill's version differs, so hand edits
  there are lost on the next run.

