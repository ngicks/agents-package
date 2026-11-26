# Beads — the actor and the plan mechanics

Detail for ngplan's **Beads** section: how to name the actor and the exact
commands that store a plan. Read **Name the actor** at skill start; read
**Plans in beads** whenever creating, editing, or closing plan issues.

Initializing the database and wiring the git hooks belong to the
`beads-init` skill.

Every command below was run against bd 1.2.2 on Git 2.55.
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
  the only reliable carrier.
- `--actor` is a global flag; it is accepted before or after the
  subcommand. The commands below put it right after `bd`.

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

Comments are append-only and carry the decision log. Every comment is
multi-line — the tag line, then one bullet per part — so it always goes
through `--stdin`; there is no one-line form.

    printf '%s\n' "Decision: <topic>
    - choice: <what was chosen>
    - rationale: <why>
    - rejected: <alternatives and why not>
    - steps: <step ids, or: non-goal>" | bd --actor <actor> comment <id> --stdin

    printf '%s\n' "Discussion: <topic>
    - decision needed: <what must be settled>
    - options: <options in view>
    - default: <tentative default>" | bd --actor <actor> comment <id> --stdin

- A `Discussion:` is open until a later `Decision:` names its topic.
- An amendment is a new `Decision:` naming the one it replaces. Never edit
  or delete a comment.
- Decisions made without the user are tagged on the tag line:
  `Decision: <topic> [automatic]`, bullets below as usual.
- The viewer badges `Decision:` and `Discussion:` comments; keep the prefix
  exact, at the start of the comment — the tag opens the quoted text, no
  blank first line.
- Existing comments in another shape are history, not a template; new
  comments follow the shape above even when the thread does not.

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
