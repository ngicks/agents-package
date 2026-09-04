# Beads — setup, agent commit trailer, and the issue backlog

Detail for ngplan's **Beads** section: how the beads (`bd`) database is
initialized and shared across worktrees, how agent commits are marked, and
how HANDOFF.md entries fold into the beads backlog. Read the setup parts
at skill start; read **The beads backlog** at the fold moment and whenever
opening, searching, or closing backlog items.

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
  remote push. The database lives in the git common directory and is
  shared by every worktree of the repository.
- It mirrors the git `origin` remote as the Dolt remote `origin`
  (`git+https://` or `git+ssh://` form) on every run, so the user's
  `bd dolt push` has somewhere to go. Only the URL is recorded; nothing is
  fetched or pushed.
- It never pushes. `bd dolt push` is the user's job; do not run it.
- If `bd` is not installed the script says so and exits 0. Planning can
  proceed, but folding HANDOFF.md into the backlog (below) is blocked until
  the user installs `bd`; tell them at the fold moment.

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

## The beads backlog

The repository's durable issue backlog is the beads database itself — one
bead per item, shared by every worktree of the repository. HANDOFF.md
entries fold into it; there is no file-based backlog.

### Backlog item shape

- Type `task`, one bead per item. The title is the item title; the
  description is the item body.
- Labels are the item's topics — the equivalent of tags — chosen from the
  item's subject matter; check `bd label list-all` first and reuse
  existing labels rather than coining near-duplicates.
- While an item lives it accumulates comments: `Discussion:` comments for
  points worth keeping from exchanges about it, and `Decision:` comments
  for choices made about it with their rationale. Comments are append-only;
  never edit the description to fold them in.
- Closing writes the conclusion as the close reason. The bead keeps its
  description, labels, and comments intact.

      # create — description from stdin, prints only the new ID
      printf '%s\n' "<item body>" | bd create "<item title>" -t task -l <label>,<label> --body-file - --silent

      # discuss / decide
      bd comment <id> "Discussion: <point raised, by whom>"
      bd comment <id> "Decision: <choice made and its rationale>"

      # close — the reason is the conclusion
      bd close <id> --reason "<what resolved it, or why it was dropped>"

### Searching the backlog

Search before folding, to extend or cross-reference an existing item
rather than duplicating it.

- `bd search "<text>" --status all` matches titles and IDs; without
  `--status all` closed items are hidden.
- `bd list --status all -l <label>` lists by label (`--label-any` for OR);
  `bd label list-all` shows every label in use.
- `bd show <id>` prints description, labels, and comments.

### Folding and closing mechanics

- Timing — this happens strictly after the implementation is done **and** the
  user has followed up on it. Never bundle the fold into the same turn as the
  completion report: report the finished work, wait for the user's review and
  approval of the implementation, and only then offer the fold.
- Ask which entries to fold with `AskUserQuestion` (`multiSelect: true`), one
  option per HANDOFF.md entry (topic). At most ~4 options per round; go in
  rounds for a longer ledger. The built-in "Other" choice is how the user
  answers "all of them" or gives a custom instruction. A single-entry
  ledger gets a fold-or-drop question for that entry instead, since the
  tool needs at least two options. Fall back to plain chat when the tool
  is unavailable.
- Create each selected entry as its own bead with `bd create` as above,
  choosing labels from the item's topics. Existing bead text is never
  rewritten — the legal mutations are appending `Discussion:` and
  `Decision:` comments as the item is discussed and decided on, and closing
  it (below).
- The backlog outlives the plan directory, so rewrite each folded item to
  stand alone: real paths and symbols, the reasoning in plain words, and no
  plan paths, decision IDs like `D15`, or plan step numbers.
- Closing an item — when the user says an open item is resolved or dropped,
  `bd close` it with a reason stating the outcome — what resolved it, or
  why it was dropped. Closing happens only on the user's say-so, never
  because you judge the work done.
- Entries the user leaves unselected stay in HANDOFF.md and disappear with
  the plan directory — that is the user's decision to drop them; never fold
  them silently.
- Never run `bd dolt push`; syncing the backlog off the machine is the
  user's job. Tell the user what was folded, with the new bead IDs.
