# Beads — setup, agent commit trailer, and the plan mechanics

Detail for ngplan's **Beads** section: how the beads (`bd`) database is
initialized and shared across worktrees, how agent commits are marked, and
the exact commands that store a plan. Read the setup parts at skill start;
read **Plans in beads** whenever creating, editing, or closing plan issues.

Every command below was run against bd 1.2.2. bd's output shapes are less
regular than its help suggests; where a shape matters it is stated.

## Initialize beads

Before touching the plan, make sure the repository's beads (`bd`) issue
database exists. Run `scripts/bd-init.sh`, bundled in this skill's
`scripts/` directory — never raw `bd init`.

- The script is idempotent: it exits 0 without doing anything when beads is
  already initialized, so run it on every invocation without checking first.
- It derives the issue prefix from the repository root directory, not the
  worktree directory, so parallel worktrees all share one prefix; set
  `BEADS_PREFIX` to override. Do not pass a prefix of your own — a mismatch
  with the existing database is a hard error.
- It writes nothing into the worktree: no `AGENTS.md`, no git hooks, no
  remote push. The database is created at the repository root, the parent
  of the git common directory, and is shared by every worktree of the
  repository. Run the script from any worktree; it finds the root itself.
- It turns off bd's anonymous usage metrics (`bd metrics off`).
- It mirrors the git `origin` remote as the Dolt remote `origin`
  (`git+https://` or `git+ssh://` form) on every run, so the user's
  `bd dolt push` has somewhere to go. Only the URL is recorded; nothing is
  fetched or pushed.
- It never pushes. `bd dolt push` is the user's job; do not run it.
- If `bd` is not installed the script says so and exits 0. Planning cannot
  proceed without it — a plan has nowhere to live — so tell the user and
  stop rather than writing plan files.

## Mark agent commits

Commits made by a coding agent carry an `Executed-By: <agent>` trailer so
they can be told apart from human commits in `git log`. The trailer is
stamped by `scripts/executed-by-trailer.sh`, bundled in this skill's
`scripts/` directory, running as the repository's `prepare-commit-msg` git
hook.

- Do not install git hooks yourself, and do not run `bd hooks install`. The
  user wires the script into their hook manager (e.g. `hk`) as the
  `prepare-commit-msg` step; the skill only ships the script.
- The script detects the agent on its own — never set an environment
  variable or add the trailer by hand. It walks the process ancestry for
  `claude`, `codex`, or `opencode` (nearest wins, so an agent nested inside
  another is the one recorded), and falls back to the `CODEX_THREAD_ID`,
  `OPENCODE`, and `CLAUDECODE` environment variables in that order because
  the Codex sandbox hides the process tree.
- A human committing from a plain shell gets no trailer. Amend and reword
  keep a single trailer; merge and squash messages are left untouched.
- Commit normally. Do not strip or edit the trailer if you rewrite a
  message.

To wire it in `hk`, add a `prepare-commit-msg` step in `hk.pkl` that
passes the commit message file and source through:

    hooks {
      ["prepare-commit-msg"] {
        steps {
          ["executed-by"] {
            check = "sh path/to/executed-by-trailer.sh {{commit_msg_file}} {{source}}"
          }
        }
      }
    }

## Plans in beads

A plan is one `epic` issue labelled `plan` plus its children. `epic` is
bd's own word for "a parent whose children are the work": `bd show` on the
epic lists the children with a progress count. "Plan" is a label, not a
type, so `bd list -l plan` and the viewer's `is:plan` query find plans
without special code.

### Creating the plan

Description from stdin; `--silent` prints only the new id.

    printf '%s\n' "<idea text>" | bd create "<plan name>" -t epic -l plan --body-file - --silent

- The id is the handle for everything that follows; report it to the user.
- Children get ids under the parent (`<epic>.1`, `<epic>.2`, …).

### Fields

Each field is set with `bd update`. Multi-line text goes through a file or
stdin, never a quoted argument.

    # design — replace the whole field
    printf '%s\n' "<design markdown>" | bd update <id> --design-file -

    # acceptance criteria — replace
    bd update <id> --acceptance "<checklist>"

    # notes — append only, one entry per call
    bd update <id> --append-notes "<what changed, what is next>"

    # description — replace (only before the gate, or with a reset — see below)
    printf '%s\n' "<idea text>" | bd update <id> --body-file -

- `design` and `acceptance_criteria` are replaced whole; read the current
  value first (`bd show <id>`) and write back the full text.
- `notes` is append-only; there is no legal way to rewrite it.
- `bd show` renders fenced code without the fence markers; that is display
  only, the stored text keeps them.

### The idea gate

    bd update <id> --set-metadata idea_gate_passed=$(date "+%Y-%m-%d")
    bd update <id> --unset-metadata idea_gate_passed

- `bd show <id>` prints a `METADATA` block with the key; `bd show <id>
  --json` returns an **array** of one issue whose `metadata` object holds it
  (and omits `metadata` entirely when nothing is set).
- Absent key means not confirmed. Nothing else counts.

### Steps

One child `task` per implementation step, labelled `step`, chained in
execution order.

    S1=$(printf '%s\n' "<what to change; verify: <end-to-end observation>>" \
      | bd create "<step title>" -t task -l step --parent <epic> --no-inherit-labels --body-file - --silent)
    S2=$(... same ...)
    bd dep $S1 --blocks $S2

- `--no-inherit-labels` is mandatory: children inherit the parent's labels
  by default, and a step carrying `plan` would show up as a plan.
- `bd dep <blocker> --blocks <blocked>` reads in execution order; it is the
  same edge as `bd dep add <blocked> <blocker>`.
- `bd ready --exclude-type epic` is the executor's queue: the open steps
  whose blockers are closed. Without the exclusion the epic itself appears.
- The step description ends with a **verify** line naming the end-to-end
  observation (a request through the daemon, a rendered page, a CLI run),
  not the unit tests. A step that moves a surface ends with a grep for the
  old shape across every language in the repository, because the side that
  prints a URL is not the side that routes it.

### Sub-plans

A sub-plan is a child `epic`, which inherits the `plan` label on its own:

    printf '%s\n' "<idea text>" | bd create "<sub-plan name>" -t epic --parent <epic> --body-file - --silent

It has its own gate, fields, steps, and comments; see
[sub-plans.md](sub-plans.md).

### Decisions and open questions

Comments are append-only and carry the decision log.

    bd comment <id> "Decision: <topic> — <choice>. Because <rationale>. Rejected: <alternatives>. Delivered by <step ids, or: non-goal>."
    bd comment <id> "Discussion: <topic> — <decision needed>. Options: <...>. Default: <...>."

- A `Discussion:` is open until a later `Decision:` names its topic.
- An amendment is a new `Decision:` naming the one it replaces. Never edit
  or delete a comment.
- Decisions made without the user are tagged: `Decision: <topic>
  [automatic] — …`.
- Long comments: `printf '%s\n' "<text>" | bd comment <id> --stdin`.
- The viewer badges `Decision:` and `Discussion:` comments; keep the prefix
  exact, at the start of the comment.

### Handoff items

Born at discovery, as their own issue, then deferred until the user
triages them.

    H=$(printf '%s\n' "<what, why not here, follow-up>" \
      | bd create "<item title>" -t task --deps discovered-from:<step or epic id> --body-file - --silent)
    bd defer $H --reason "awaiting triage"

- `bd defer` sets status `deferred`: hidden from `bd ready`, listed by
  `bd list -s deferred`.
- The user promotes with `bd undefer <id>` (status back to `open`) or drops
  with `bd close <id> --reason "<why>"`. Never do either yourself.
- Labels are the item's topics; check `bd label list-all` and reuse
  existing labels rather than coining near-duplicates.
- A handoff item stands alone: real paths and symbols, the reasoning in
  plain words. Naming the originating plan or step by bead id is fine —
  the edge already does — but never paraphrase-free tokens like "step 3".

### Reading a plan

    bd list -l plan -t epic --status all       # every plan, open and closed
    bd search "<words>" --status all           # by title
    bd show <id>                               # fields, labels, metadata, children, comments
    bd show <id> --children                    # children only
    bd list -s deferred                        # handoff items awaiting triage
    bd dep list <id>                           # dependencies of one issue

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

    bd close <step id> --reason "<verified how>"
    bd close <epic> --reason "<completion summary>"

- Closing the last child does **not** close the epic in bd 1.2.2; close the
  epic explicitly once every step is closed and the user has accepted the
  result.
- Never run `bd dolt push`; syncing the database off the machine is the
  user's job.
