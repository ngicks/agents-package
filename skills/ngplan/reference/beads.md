# Beads — setup, agent commit trailer, and the plan mechanics

Detail for ngplan's **Beads** section: how the beads (`bd`) database is
initialized and shared across worktrees, how agent commits are marked, and
the exact commands that store a plan. Read the setup parts at skill start;
read **Plans in beads** whenever creating, editing, or closing plan issues.

Every command below was run against bd 1.2.2 and hk 2.0.0 on Git 2.55.
bd's output shapes are less regular than its help suggests; where a shape
matters it is stated.

## Name the actor

bd stamps every write with an actor for its audit trail. Left alone it
falls back to `$BEADS_ACTOR`, then git `user.name`, then `$USER` — the
human's name, which makes agent edits indistinguishable from the user's.
So every `bd` invocation in this skill carries `--actor <actor>`, reads
included, so the rule has no exceptions to remember.

- The actor is `<agent>/<model>`: the agent harness name in lowercase
  (`claude`, `codex`, `opencode`) and the model id it is running, joined
  by `/`. Examples: `claude/claude-fable-5-1`, `codex/gpt-5-codex`.
- Use the model id as the harness reports it (its system prompt or
  configuration), not a marketing name; drop the `/<model>` part only when
  the model is genuinely unknown.
- Never fall back to the user's name, and do not set `BEADS_ACTOR` for the
  session: shell state does not persist between tool calls, so the flag is
  the only reliable carrier. The one exception is `scripts/bd-init.sh`,
  which is run as `BEADS_ACTOR=<actor> scripts/bd-init.sh` because it
  calls `bd` on its own.
- `--actor` is a global flag; it is accepted before or after the
  subcommand. The commands below put it right after `bd`.

## Initialize beads

Before touching the plan, make sure the repository's beads (`bd`) issue
database exists. Run `BEADS_ACTOR=<actor> scripts/bd-init.sh`, bundled in
this skill's `scripts/` directory — never raw `bd init`.

- The script is idempotent: it exits 0 without doing anything when beads is
  already initialized, so run it on every invocation without checking first.
- `BEADS_ACTOR` carries the actor into the `bd` calls the script makes; see
  **Name the actor** above.
- It derives the issue prefix from the repository root directory, not the
  worktree directory, so parallel worktrees all share one prefix; set
  `BEADS_PREFIX` to override. Do not pass a prefix of your own — a mismatch
  with the existing database is a hard error.
- The beads part writes nothing into the worktree: no `AGENTS.md`, no bd
  git hooks, no remote push. The database is created at the repository
  root, the parent of the git common directory, and is shared by every
  worktree of the repository. Run the script from any worktree; it finds
  the root itself.
- It ends by running `scripts/hk-init.sh`, on every path, so the `hk`
  hooks in **Mark agent commits** below are wired in the same step. That
  is the one part that writes into the worktree (`hk.pkl`,
  `.hk/beads.pkl`); commit those files when they change.
- It turns off bd's anonymous usage metrics (`bd metrics off`).
- On first init it checks whether the git `origin` already holds Dolt data
  (pushed from another machine with `bd dolt push`). If so it clones that
  history instead of creating an empty database, so a fresh clone picks
  up the existing plan. Never run `bd bootstrap` yourself: it fails from a
  bare repository root and errors on an already initialized database.
- It mirrors the git `origin` remote as the Dolt remote `origin`
  (`git+https://` or `git+ssh://` form) on every run, so the user's
  `bd dolt push` has somewhere to go. Only the URL is recorded; apart from
  the first-init clone, nothing is fetched or pushed.
- It never pushes or pulls after that. `bd dolt push` and `bd dolt pull`
  are the user's job; do not run them.
- If `bd` is not installed the script says so and exits 0. Planning cannot
  proceed without it — a plan has nowhere to live — so tell the user and
  stop rather than writing plan files.

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
keeps its plan in beads. `scripts/hk-init.sh` installs it; `bd-init.sh`
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

## Plans in beads

A plan is one `epic` issue labelled `plan` plus its children. `epic` is
bd's own word for "a parent whose children are the work": `bd show` on the
epic lists the children with a progress count. "Plan" is a label, not a
type, so `bd list -l plan` and the viewer's `is:plan` query find plans
without special code.

### Creating the plan

Description from stdin; `--silent` prints only the new id.

    printf '%s\n' "<idea text>" | bd --actor <actor> create "<plan name>" -t epic -l plan --body-file - --silent

- The id is the handle for everything that follows; report it to the user.
- Children get ids under the parent (`<epic>.1`, `<epic>.2`, …).

### Fields

Each field is set with `bd update`. Multi-line text goes through a file or
stdin where a `-file` flag exists; `--append-notes` has none, so its short
entry is a quoted argument.

    # design — replace the whole field
    printf '%s\n' "<design markdown>" | bd --actor <actor> update <id> --design-file -

    # acceptance criteria — replace
    bd --actor <actor> update <id> --acceptance "<checklist>"

    # notes — append only, one dated bullet per call, structured sub-bullets
    bd --actor <actor> update <id> --append-notes "- $(date "+%Y-%m-%d")
      - changed: <what changed>
      - blocked: <what blocks, if anything>
      - next: <next action>"

    # description — replace (only before the gate, or with a reset — see below)
    printf '%s\n' "<idea text>" | bd --actor <actor> update <id> --body-file -

- `design` and `acceptance_criteria` are replaced whole; read the current
  value first (`bd show <id>`) and write back the full text.
- `notes` is append-only; there is no legal way to rewrite it.
- `bd show` renders fenced code without the fence markers; that is display
  only, the stored text keeps them.

### The idea gate

    bd --actor <actor> update <id> --set-metadata idea_gate_passed=$(date "+%Y-%m-%d")
    bd --actor <actor> update <id> --unset-metadata idea_gate_passed

- `bd show <id>` prints a `METADATA` block with the key; `bd show <id>
  --json` returns an **array** of one issue whose `metadata` object holds it
  (and omits `metadata` entirely when nothing is set).
- Absent key means not confirmed. Nothing else counts.

### Steps

One child `task` per implementation step, labelled `step`, chained in
execution order.

    S1=$(printf '%s\n' "<what to change; verify: <end-to-end observation>>" \
      | bd --actor <actor> create "<step title>" -t task -l step --parent <epic> --no-inherit-labels --body-file - --silent)
    S2=$(... same ...)
    bd --actor <actor> dep $S1 --blocks $S2

- `--no-inherit-labels` is mandatory: children inherit the parent's labels
  by default, and a step carrying `plan` would show up as a plan.
- `bd dep <blocker> --blocks <blocked>` reads in execution order; it is the
  same edge as `bd dep add <blocked> <blocker>`.
- `bd --actor <actor> ready --exclude-type epic` is the executor's queue:
  the open steps whose blockers are closed. Without the exclusion the epic
  itself appears.
- The step description ends with a **verify** line naming the end-to-end
  observation (a request through the daemon, a rendered page, a CLI run),
  not the unit tests. A step that moves a surface ends with a grep for the
  old shape across every language in the repository, because the side that
  prints a URL is not the side that routes it.

### Sub-plans

A sub-plan is a child `epic`, which inherits the `plan` label on its own:

    printf '%s\n' "<idea text>" | bd --actor <actor> create "<sub-plan name>" -t epic --parent <epic> --body-file - --silent

It has its own gate, fields, steps, and comments; see
[sub-plans.md](sub-plans.md).

### Decisions and open questions

Comments are append-only and carry the decision log.

    bd --actor <actor> comment <id> "Decision: <topic> — <choice>. Because <rationale>. Rejected: <alternatives>. Delivered by <step ids, or: non-goal>."
    bd --actor <actor> comment <id> "Discussion: <topic> — <decision needed>. Options: <...>. Default: <...>."

- A `Discussion:` is open until a later `Decision:` names its topic.
- An amendment is a new `Decision:` naming the one it replaces. Never edit
  or delete a comment.
- Decisions made without the user are tagged: `Decision: <topic>
  [automatic] — …`.
- Long comments:
  `printf '%s\n' "<text>" | bd --actor <actor> comment <id> --stdin`.
- The viewer badges `Decision:` and `Discussion:` comments; keep the prefix
  exact, at the start of the comment.

### Handoff items

Born at discovery, as their own issue, then deferred until the user
triages them.

    H=$(printf '%s\n' "<what, why not here, follow-up>" \
      | bd --actor <actor> create "<item title>" -t task --deps discovered-from:<step or epic id> --body-file - --silent)
    bd --actor <actor> defer $H --reason "awaiting triage"

- `bd defer` sets status `deferred`: hidden from `bd ready`, listed by
  `bd list -s deferred`.
- The user promotes with `bd undefer <id>` (status back to `open`) or drops
  with `bd close <id> --reason "<why>"`. Never do either yourself.
- Labels are the item's topics; check `bd --actor <actor> label list-all`
  and reuse existing labels rather than coining near-duplicates.
- A handoff item stands alone: real paths and symbols, the reasoning in
  plain words. Naming the originating plan or step by bead id is fine —
  the edge already does — but never paraphrase-free tokens like "step 3".

### Reading a plan

    bd --actor <actor> list -l plan -t epic --status all       # every plan, open and closed
    bd --actor <actor> search "<words>" --status all           # by title
    bd --actor <actor> show <id>                               # fields, labels, metadata, children, comments
    bd --actor <actor> show <id> --children                    # children only
    bd --actor <actor> list -s deferred                        # handoff items awaiting triage
    bd --actor <actor> dep list <id>                           # dependencies of one issue

- `bd show --json` returns an array even for one id.
- `bd list --json` includes the text fields (`description`, `design`,
  `notes`, `acceptance_criteria`) and each issue's edges.
- `bd dep list --json` changes shape with how many ids resolve: one id
  gives an array of issues with a `dependency_type` field, two or more
  give an array of edges (`issue_id`, `depends_on_id`, `type`), and a
  missing id gives a JSON `error` object with exit code 0.
- Prefer the human output unless a script needs JSON, and when it does,
  record a real sample as a fixture rather than describing the shape.

### Closing

Closing a step writes what was observed; closing the plan writes the
completion summary.

    bd --actor <actor> close <step id> --reason "<verified how>"
    bd --actor <actor> close <epic> --reason "<completion summary>"

- Closing the last child does **not** close the epic in bd 1.2.2; close the
  epic explicitly once every step is closed and the user has accepted the
  result.
- Never run `bd dolt push`; syncing the database off the machine is the
  user's job.
