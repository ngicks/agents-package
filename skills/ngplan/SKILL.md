---
name: ngplan
description: 'Create or elaborate a plan stored in the repository''s beads (`bd`) database — one `epic` issue labelled `plan` holding idea, design, acceptance criteria and notes, child `step` tasks for the implementation, and `Decision:` / `Discussion:` comments — settle how it should be (use cases, usability) first, draft a rough scaffold, record open questions, then resolve them with the user. Use when starting, drafting, editing, reviewing, or continuing a plan/planning, e.g. "make a plan", "look at a plan", "continue on plan/planning".'
---

# ngplan

Draft a rough plan first, mark every open question inside it, then resolve those
questions with the user before finalizing.

A plan is one beads issue plus its children, not a file. The `bd` CLI is the
only data path.

Work draft-first: get something concrete into beads fast so the user has a real
artifact to react to, instead of interrogating them up front.

## Ground yourself first

Before drafting, skim the repo so the plan — and its open questions — are
specific to this codebase, not generic.

- Use Read, Grep, Glob, and `git log`/`git status` to learn the relevant files,
  current behavior, conventions, and constraints.
- Resolve anything answerable by looking. Only unknowns that genuinely need the
  user become open questions.

## Beads

The plan lives in the repository's beads (`bd`) database, one database
shared by every git worktree. Read [reference/beads.md](reference/beads.md)
for the setup, the exact field mapping, and every command this skill uses.

- On every invocation run `scripts/bd-init.sh`, bundled in this skill's
  `scripts/` directory. It is idempotent, picks the prefix itself, and
  mirrors the git origin as the Dolt remote; never run raw `bd init`, never
  pass a prefix, never run `bd hooks install`.
- `bd` missing is blocking: the plan has nowhere to live. Tell the user and
  stop instead of writing files.
- Never run `bd dolt push`; syncing off the machine is the user's job.
- Agent commits get an `Executed-By: <agent>` trailer automatically, from
  `scripts/executed-by-trailer.sh` wired by the user as the
  `prepare-commit-msg` hook. Commit normally; do not set variables, add,
  strip, or edit the trailer.

How the plan maps onto one issue:

| Plan artifact | Where it lives |
|---|---|
| Plan | `epic` issue, label `plan`, title = plan name |
| Idea statement | `description` |
| Idea gate | metadata `idea_gate_passed=YYYY-MM-DD`; absent = not confirmed |
| Implementation plan | `design` |
| Success criteria | `acceptance_criteria` |
| Status narrative | `notes`, append-only |
| Implementation step | child `task`, label `step`, ordered by `blocks` edges |
| Sub-plan | child `epic`, label `plan` |
| Handoff item | `task` with a `discovered-from` edge, status `deferred` |
| Decision | comment `Decision: ...` |
| Open question | comment `Discussion: ...`, closed by a later `Decision:` |
| Plan done | `bd close --reason` |

Existing `doc/plan/` directories are history. Read them when the user points
at one; never migrate or extend them.

## Locate the plan

- Restate, in one sentence, what the user wants planned. If they never said, ask.
- List the existing plans with `bd list -l plan -t epic --status all` and
  search with `bd search "<words>" --status all`. If one matches (or the
  user names an id), open it with `bd show <id>` and elaborate it — work
  from its current fields, children, and comments.
- Otherwise the plan is new: its title is a short, specific name for the
  feature. Disambiguate from a similar existing plan by name, never by a
  serial counter.
- A sub-plan of an existing plan is a child epic of it, not a new top-level
  plan; see **Sub-plans** below.

## Idea phase — settle how it should be

Before planning how to build it, settle what it should be. This thinking lands
in the epic's `description`, and the `design` goal, scope, and
`acceptance_criteria` derive from it.

- Frame every statement as how the feature **should** behave — the behavior a
  user would call right. How it _can_ be — current code structure, effort,
  technical constraints — gets no vote here.
- Walk each use case end to end: who is acting, in what situation, what they are
  trying to get done, and what they experience at each step from invocation to
  done.
- Diagram the workflow where it earns it: when a use case branches, involves
  several actors, or spans more than a few steps, put a mermaid flowchart or
  sequence diagram beside the prose walkthrough in the description.
- Judge usability concretely: invocation ergonomics and naming, defaults that
  match the common case, feedback while running, the failure experience, and
  discoverability.
- When the ideal later collides with feasibility, the compromise happens in
  `design` and is recorded as a `Decision:` comment — never by quietly
  editing the description down to what was convenient to build.
- Draft-first applies here too: write the rough description, and raise
  uncertain use cases and usability calls as `Discussion:` comments rather
  than guessing silently.

### The idea gate — finalize the idea before planning

The idea is a gate, not a first draft that planning overtakes. Stop and
finalize it with the user before detailing the implementation plan.

- Resolve the idea-level open questions — use cases, usability calls — with
  the user first, before any contract or implementation-step questions.
- Then ask the user to confirm the description captures how it should be;
  only after that confirmation, detail the `design` contracts and the step
  children.
- Ask that confirmation with `AskUserQuestion`, using this fixed wording and
  option order every time — never reorder or reword it, so the user's answer
  by muscle memory always lands on the same choice:
  - Question: "Does the idea capture how it should be?"
  - Option 1: "No. Need something to change" — the user points out what;
    the gate stays not confirmed.
  - Option 2: "Yes. Confirm the gate" — set the gate metadata.
- This fixed order overrides the recommended-first convention: even when
  "Yes" is the natural recommendation, do not move it first or append
  "(Recommended)" to it.
- Keep the same wording and order when falling back to plain chat because
  the tool is unavailable.
- The rough scaffold still creates the epic up front, but `design` stays a
  skeleton — goal, scope, known context — until the gate passes, and no
  step children exist yet.
- Record the gate state on the epic itself: the scaffold sets no metadata,
  and confirmation runs
  `bd update <id> --set-metadata idea_gate_passed=<YYYY-MM-DD>` with today's
  date from `date "+%Y-%m-%d"`.
- When resuming an existing plan, trust only that recorded metadata — a
  confirmation given in an earlier session's chat does not count. If the
  key is missing, run the gate again before detailing `design`.
- Substantive edits to the description after confirmation reset the gate
  with `bd update <id> --unset-metadata idea_gate_passed`; confirm with the
  user again before planning on.

## Emit the rough scaffold

Create the epic now, as a rough first pass — do not wait for answers.

- New plan — `bd create` the epic with type `epic`, label `plan`, and the
  idea text as its description (see [reference/beads.md](reference/beads.md)
  for the command). Seed `design` with the skeleton and every open question
  as a `Discussion:` comment.
- Existing plan — update the fields in place; keep what still holds. Notes
  and comments are append-only; never rewrite them.
- Fill what is known. Mark everything uncertain as a rough spot rather than
  guessing silently; an incomplete first pass is expected.
- Tell the user the plan's id and call out the rough spots so they can read
  them (`bd show <id>`, or the issues page of `crabswarm preview` where it
  is running).

## Field templates

Each field carries one part of the plan. The shapes below are the templates
for each field's text; write them in markdown.

- **description** — the "how it should be" statement, written in the idea
  phase: use cases (actor, situation, intent, end-to-end walkthrough) and
  usability requirements (ergonomics, defaults, feedback, failure
  experience). Deliberately blind to implementation cost; `design`
  compromises against it only through a `Decision:` comment.
- **design** — the implementation plan: one-line summary; goal and scope
  (both grounded in the description); non-goals; context (real file paths,
  current behavior, and paths of recorded probe fixtures — see
  **Contracts**); approach (chosen design plus rejected alternatives); a
  **Public surface delta** section (see **Contracts**) whenever exported or
  user-visible surface changes; testing and verification; risks. The step
  list itself is the children, not prose here.
- **acceptance_criteria** — the success criteria as a checklist, each item
  observable end to end.
- **notes** — living progress narrative, appended with
  `bd update <id> --append-notes`: what changed, what is blocked, the next
  action. Progress itself is the children's status; notes explain it.
- **step children** — one `task` per implementation step, label `step`,
  independently verifiable, naming real files and symbols. The description
  holds what to change and a **verify** line naming the end-to-end
  observation that proves it, not the unit tests. A step that moves a
  surface (a route, a URL, a flag) ends with a grep for the old shape
  across every language in the repository.
- **comments** — `Decision:` for each material decision with the choice,
  the rationale, the rejected alternatives, and the step ids that deliver
  it; `Discussion:` for each open question with the decision needed, the
  options in view, and a tentative default.

Reference actual file paths and symbols, never placeholders.

### Use the right visual artifact

Keep the plan in markdown so it stays readable and diffable.

- Use markdown tables for comparisons, such as options and their trade-offs.
- Diagrams are for the human reader. Whenever a section's material has shape —
  a flow, a hierarchy, relations, states, a layout — default to adding the
  matching mermaid diagram alongside the prose, in description and design
  alike. Diagram and prose co-exist: the diagram shows the shape, the prose
  explains it.
- Skip a diagram only when there is no shape to show: adding a library
  function or a simple refactor / clean-up contains no workflow or structure.
- Pick the diagram type from the catalogue in
  [reference/visuals.md](reference/visuals.md) rather than defaulting to
  flowchart for everything.
- A workflow diagrammed in the description often deserves a design
  counterpart showing which components and steps deliver each leg of the
  flow.
- Mermaid fences in issues are linted (`crabswarm issues lint` and its Stop
  hook); a fence that does not parse blocks the turn, so keep diagrams to
  the long-stable types.

Before actually producing a diagram, preview, or mock, read
[reference/visuals.md](reference/visuals.md): it holds the mermaid type
catalogue, the presentation-preview loop (when a runnable preview is
warranted, where it lives, and how it iterates), the mock limitation and
promotion rules, and how to offload mock generation to a subagent.

## Contracts — focus of the plan

Spend the plan's precision on the contracts — the parts that are expensive to
change later: public API and user-visible surface (config keys, CLI flags,
environment variables), dependencies, RPC schema, project layout, and
persistent data format. Implementation internals can stay rough. Read
[reference/contracts.md](reference/contracts.md) before writing the design's
approach, delta, or the step children; its hard rules in brief:

- Every plan touching exported, user-visible, or durable surface — dependency
  changes included — gets a **Public surface delta** section in `design`
  whose authority is fenced code, not prose; surface not in the block is out
  of scope.
- Dependency changes lead the delta, and every added dependency gets a
  `Decision:` comment justifying it against alternatives.
- Naming a database or on-disk format requires its schema as fenced DDL plus
  an `erDiagram` in the delta, or a user-approved deferral recorded as a
  `Decision:` comment.
- Implementation may expand the delta, never silently: ask the user when
  available, otherwise decide, tag the `Decision:` comment `[automatic]`,
  and edit the block in the same turn.
- Planned code spanning files is written one fence per file, headed by the
  real path; the split is tentative, the enumerated surface is not.
- Keep the fences, cut the prose: describe external behavior (a CLI's JSON,
  a wire format) by recording real probe output as committed fixtures the
  tests will reuse, and name their paths in the context section.

## Sub-plans

A plan that outgrows one issue splits hierarchically into a master plan
that owns the whole scope and sub-plans that are child epics of it — never
by narrowing the plan to a first slice. Splitting, and especially deferring
scope, is a user decision recorded as a `Decision:` comment. Read
[reference/sub-plans.md](reference/sub-plans.md) whenever a split comes up
or a plan already has child epics.

## Handoff items — what leaves the plan

Work that leaves the plan family — deferred tasks, defects found but not
fixed, required follow-ups — is born as its own issue the moment it is
discovered, never in a file and never from memory later.

- Create it as a `task` with a `discovered-from` edge to the step or plan
  that surfaced it, then `bd defer` it. Deferred status is the "awaiting the
  user's triage" state: it stays out of `bd ready`, and
  `bd list -s deferred` lists everything waiting.
- Only two kinds are legitimate:
  - **Out-of-scope discovery** — a defect or improvement found while working
    that the agreed scope does not cover. Recording it is mandatory; fixing
    it silently and staying silent about it are both wrong.
  - **User-approved deferral** — in-scope work moved out by an explicit user
    decision, quoting its `Decision:` comment. A deferral without a decision
    is scope silently dropped, which the traceability gate rejects.
- In-scope work is never handed off by default: it is done, or the plan is
  not done. A step turning out hard or large is a reason to raise a
  `Discussion:` with the user, not to defer it.
- The item stands alone: real paths and symbols, why it is not done here,
  and the concrete follow-up — written so it still reads once the plan is
  closed.
- Promotion and dropping are the user's: they `bd undefer` an item into the
  backlog or `bd close` it. Never do either on your own judgment.
- Tell the user whenever you create one; the deferred list never grows
  quietly.

## Record open questions

Every unresolved decision goes into the plan as an explicit open question, never
into chat-only memory.

- Each open question is one `Discussion:` comment on the epic (or on the
  child it concerns) stating the decision needed, the options in view, and
  a tentative default.
- Start each with a short tag word after `Discussion:` (the topic) so it can
  be referenced while resolving; comments have no numbers.
- A question is open until a later `Decision:` comment names its topic.

## Resolve the open questions

Walk the open questions and resolve every one with the user.

- Order the rounds idea-first: resolve the idea-level questions and pass the
  idea gate (see **The idea gate** above) before raising contract or
  implementation-step questions.
- Prefer the `AskUserQuestion` tool when available: offer concrete options with
  the tentative default first as the recommended choice, and let the user supply
  a custom answer. (Exception: the idea-gate confirmation uses its own fixed
  wording and order — see **The idea gate**.)
- Fall back to plain chat when `AskUserQuestion` is unavailable — ask in your
  reply, listing the questions by topic with their options and your default.
- At most ~4 questions per round; go in rounds until nothing material is open.
- Do not stop early on the grounds of having "enough to start".

## Finalize

After each answer, fold it back into the plan immediately.

- Append a `Decision:` comment naming the topic, the choice, the rationale,
  and the rejected alternatives, at the moment it is decided. An amendment
  is a new `Decision:` comment naming the one it replaces; nothing is edited
  after the fact.
- Write the resolved content into the field it belongs to (`design`,
  `acceptance_criteria`, or the description before the gate).
- Once the gate has passed and the contracts are settled, create the step
  children and chain them with `blocks` edges in execution order, so
  `bd ready` is the executor's queue.
- Append a `notes` line describing the now-current state.

### Traceability gate

Before declaring the plan finalized, verify every decided clause is owned by a
step — review catches what is listed, not what is implied.

- Walk every `Decision:` comment, inherited ones included, clause by clause.
  Each operative clause must name at least one step child id that delivers
  it, or say it is a non-goal. Append the step ids to the decision when
  they were created later, as a new `Decision:` comment amending the old.
- An unmapped clause means the plan is not finalized: give it an owning step,
  hand it to another plan in the family via the boundary ledger, or reopen
  it as a `Discussion:`.
- Then replay each use case in the description against the union of step
  children across the plan family; a use case no step delivers is flagged
  the same way.
- Then walk the contract areas listed under **Contracts** — public
  API, dependencies, RPC schema, project layout, persistent data format:
  each must either be concretely present as a fenced block in `design` or be
  explicitly marked "no change". An area merely described in prose is
  unfinalized — e.g. SQLite named in the approach with no DDL block anywhere
  fails this check.
- Deferred items are part of the gate: every task deferred from this plan
  must be an out-of-scope discovery or quote a user-made `Decision:` —
  anything else is scope silently dropped, and the plan is not finalized.
