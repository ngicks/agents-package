---
name: ngplan
description: 'Create or elaborate a plan directory under ./doc/plan/ (IDEA.md, PLAN.md, STATUS.md, DECISION.md, plus optional presentation previews) — settle how it should be (use cases, usability) first, draft a rough scaffold, record open questions, then resolve them with the user. Use when starting, drafting, editing, reviewing, or continuing a plan/planning, e.g. "make a plan", "look at a plan", "continue on plan/planning".'
---

# ngplan

Draft a rough plan first, mark every open question inside it, then resolve those
questions with the user before finalizing.

A plan is a _directory_, not a single file.

Work draft-first: get something concrete on disk fast so the user has a real
artifact to react to, instead of interrogating them up front.

## Ground yourself first

Before drafting, skim the repo so the plan — and its open questions — are
specific to this codebase, not generic.

- Use Read, Grep, Glob, and `git log`/`git status` to learn the relevant files,
  current behavior, conventions, and constraints.
- Resolve anything answerable by looking. Only unknowns that genuinely need the
  user become open questions.

## Beads

The repository's issue backlog is beads (`bd`), one database shared by every
git worktree. Read [reference/beads.md](reference/beads.md) for the detail.

- On every invocation run `scripts/bd-init.sh`, bundled in this skill's
  `scripts/` directory. It is idempotent and picks the prefix itself; never
  run raw `bd init`, never pass a prefix, never run `bd hooks install`.
- Never run `bd dolt push`; syncing off the machine is the user's job.
- Agent commits get an `Executed-By: <agent>` trailer automatically, from
  `scripts/executed-by-trailer.sh` wired by the user as the
  `prepare-commit-msg` hook. Commit normally; do not set variables, add,
  strip, or edit the trailer.

## Locate the plan directory

- Restate, in one sentence, what the user wants planned. If they never said, ask.
- Check `./doc/plan/` for an existing plan the user refers to. If one matches (or
  the user points at a directory), open it and elaborate it — work from its
  current files.
- Otherwise compute a new location `./doc/plan/<YYYY-MM-DD>-<plan_name>`:
  - `<YYYY-MM-DD>` is today's date — get it from `date "+%Y-%m-%d"` rather than
    guessing.
  - `<plan_name>` is a short snake_case slug from the summary — use `_`, not
    `-`, so it stays a single token that doesn't collide with the `-`s inside
    the date and the one joining the date to the name.
  - If the computed directory already exists and holds a different plan, pick
    a more specific slug — disambiguate by name, never by a serial counter,
    so parallel worktrees never have to coordinate a shared number.
- A sub-plan of an existing plan does not get its own dated entry — it lives
  under its master plan's directory instead; see **Sub-plans** below.

## Idea phase — settle how it should be

Before planning how to build it, settle what it should be. This thinking lands
in IDEA.md, and PLAN.md's goal, scope, and success criteria derive from it.

- Frame every statement as how the feature **should** behave — the behavior a
  user would call right. How it _can_ be — current code structure, effort,
  technical constraints — gets no vote here.
- Walk each use case end to end: who is acting, in what situation, what they are
  trying to get done, and what they experience at each step from invocation to
  done.
- Diagram the workflow where it earns it: when a use case branches, involves
  several actors, or spans more than a few steps, put a mermaid flowchart or
  sequence diagram beside the prose walkthrough in IDEA.md.
- Judge usability concretely: invocation ergonomics and naming, defaults that
  match the common case, feedback while running, the failure experience, and
  discoverability.
- When the ideal later collides with feasibility, the compromise happens in
  PLAN.md and is recorded as a DECISION.md entry — never by quietly editing
  IDEA.md down to what was convenient to build.
- Draft-first applies here too: write the rough IDEA.md, mark uncertain use
  cases and usability calls as open questions rather than guessing silently.

### The idea gate — finalize IDEA.md before planning

IDEA.md is a gate, not a first draft that planning overtakes. Stop and
finalize it with the user before detailing the implementation plan.

- Resolve the idea-level open questions — use cases, usability calls — with
  the user first, before any contract or implementation-step questions.
- Then ask the user to confirm IDEA.md captures how it should be; only after
  that confirmation, detail PLAN.md's contracts and implementation steps.
- Ask that confirmation with `AskUserQuestion`, using this fixed wording and
  option order every time — never reorder or reword it, so the user's answer
  by muscle memory always lands on the same choice:
  - Question: "Does IDEA.md capture how it should be?"
  - Option 1: "No. Need something to change" — the user points out what;
    the gate stays `not confirmed`.
  - Option 2: "Yes. Confirm the gate" — flip the `Gate:` line to confirmed.
- This fixed order overrides the recommended-first convention: even when
  "Yes" is the natural recommendation, do not move it first or append
  "(Recommended)" to it.
- Keep the same wording and order when falling back to plain chat because
  the tool is unavailable.
- The rough scaffold still writes all four files up front, but PLAN.md stays
  a skeleton — goal, scope, known context, open questions — until the gate
  passes.
- Record the gate state in IDEA.md itself, as a status line near the top:
  the rough scaffold seeds `Gate: not confirmed`, and it flips to
  `Gate: confirmed by user, <YYYY-MM-DD>` when the user confirms.
- When resuming an existing plan, trust only that recorded line — a
  confirmation given in an earlier session's chat does not count. If the
  line is missing or says not confirmed, run the gate again before
  detailing PLAN.md.
- Substantive edits to IDEA.md after confirmation reset the line to
  `Gate: not confirmed`; confirm with the user again before planning on.

## Emit the rough scaffold

Write the plan directory now, as a rough first pass — do not wait for answers.

- New plan — create the directory, including `./doc/plan/` itself if it does not
  yet exist, then write the four canonical files defined under **Canonical
  files** below.
- Existing plan — update them in place; keep what still holds.
- Fill what is known. Mark everything uncertain as a rough spot rather than
  guessing silently; an incomplete first pass is expected.
- Tell the user where it was written and call out the rough spots so they can
  read them.

## Canonical files

- **IDEA.md** — the "how it should be" statement, written in the idea phase:
  a `Gate:` status line near the top (see **The idea gate**), use cases
  (actor, situation, intent, end-to-end walkthrough) and usability
  requirements (ergonomics, defaults, feedback, failure experience).
  Deliberately blind to implementation cost; PLAN.md compromises against it only
  through a DECISION.md entry.
- **PLAN.md** — the implementation plan: title and one-line summary; goal /
  success criteria and scope (both grounded in IDEA.md); non-goals; context
  (real file paths, current behavior); approach (chosen design plus rejected
  alternatives); a **Public surface delta** section (see **Contracts**)
  whenever exported or user-visible surface changes; ordered implementation
  steps, each independently verifiable and naming real files and symbols;
  testing and verification; risks; and a numbered **Open questions** section
  that drains to empty as they resolve.
- **STATUS.md** — living progress log: current state, a checklist mirroring the
  PLAN.md steps, what is done / in progress / blocked, and the next action.
  Checklist items quote or cite the DECISION.md entry or requirement they
  discharge (e.g. `D28: tab completes *paths* ✓`), never just the feature
  name, so completion is judged against the requirement's words rather than
  the implementation's. Seed a new one as "not started"; when elaborating,
  refresh it rather than reset it.
- **DECISION.md** — decision log: one entry per material decision with the choice
  made, the rationale, and the alternatives rejected. Seed stubs from the open
  questions; append a finished entry as each one resolves, rather than rewriting
  history.

Other files are welcome — later agents may add notes, diagrams, or scratch while
planning or implementing. Keep the four canonical files current. One more file
is standardized but deliberately not scaffolded: HANDOFF.md — see
**HANDOFF.md — ledger of what leaves the plan** below.

Reference actual file paths and symbols, never placeholders.

### Use the right visual artifact

Keep the plan itself in markdown so it stays readable, diffable, and easy to
update.

- Use markdown tables for comparisons, such as options and their trade-offs.
- Diagrams are for the human reader. Whenever a section's material has shape —
  a flow, a hierarchy, relations, states, a layout — default to adding the
  matching mermaid diagram alongside the prose, in IDEA.md and PLAN.md alike.
  Diagram and prose co-exist: the diagram shows the shape, the prose explains
  it.
- Skip a diagram only when there is no shape to show: adding a library
  function or a simple refactor / clean-up contains no workflow or structure.
- Pick the diagram type from the catalogue in
  [reference/visuals.md](reference/visuals.md) rather than defaulting to
  flowchart for everything.
- A workflow diagrammed in IDEA.md often deserves a PLAN.md counterpart
  showing which components and steps deliver each leg of the flow.

Before actually producing a diagram, preview, or mock, read
[reference/visuals.md](reference/visuals.md): it holds the mermaid type
catalogue, the presentation-preview rules (when a runnable preview is
warranted and how to keep it isolated), the mock limitation and promotion
rules, and how to offload mock generation to a subagent.

## Contracts — focus of the plan

Spend the plan's precision on the contracts — the parts that are expensive to
change later: public API and user-visible surface (config keys, CLI flags,
environment variables), dependencies, RPC schema, project layout, and
persistent data format. Implementation internals can stay rough. Read
[reference/contracts.md](reference/contracts.md) before writing PLAN.md's
approach, delta, or steps; its hard rules in brief:

- Every plan touching exported, user-visible, or durable surface — dependency
  changes included — gets a **Public surface delta** section in PLAN.md
  whose authority is fenced code, not prose; surface not in the block is out
  of scope.
- Dependency changes lead the delta, and every added dependency gets a
  DECISION.md entry justifying it against alternatives.
- Naming a database or on-disk format requires its schema as fenced DDL plus
  an `erDiagram` in the delta, or a user-approved deferral recorded in
  DECISION.md.
- Implementation may expand the delta, never silently: ask the user when
  available, otherwise decide, tag the DECISION.md entry `[automatic]`, and
  edit the block in the same turn.
- Planned code spanning files is written one fence per file, headed by the
  real path; the split is tentative, the enumerated surface is not.

## Sub-plans

A plan that outgrows one directory splits hierarchically into a master plan
that owns the whole scope and sub-plans under its `sub/` directory — never
by narrowing the plan to a first slice. Splitting, and especially deferring
scope, is a user decision recorded in DECISION.md. Read
[reference/sub-plans.md](reference/sub-plans.md) whenever a split comes up
or a plan already has a `sub/` directory.

## HANDOFF.md — ledger of what leaves the plan

Work that leaves the plan family — deferred tasks, defects found but not
fixed, required follow-ups — is recorded in a `HANDOFF.md` in the plan
directory. It is a ledger, not a license: writing an item there does not
authorize deferring it. It is also not the final resting place: once the
implementation is done and the user has reviewed it, the ledger drains into
the beads backlog — see **Fold the ledger into the beads backlog**
below.

- Do not scaffold it. Create the file only when the first real item appears.
  No HANDOFF.md means nothing was left behind; the file's very existence is a
  signal the user should see.
- Only two kinds of entries are legitimate:
  - **Out-of-scope discovery** — a defect or improvement found while working
    that the agreed scope does not cover. Recording it is mandatory; fixing
    it silently and staying silent about it are both wrong.
  - **User-approved deferral** — in-scope work moved out by an explicit user
    decision, linking its DECISION.md entry. A deferral without a decision
    entry is scope silently dropped, which the traceability gate rejects.
- In-scope work is never handed off by default: it is done, or the plan is
  not done. A step turning out hard or large is a reason to raise an open
  question with the user, not to write a HANDOFF entry.
- Each entry records what the item is (real paths and symbols), why it is not
  done here (discovery, or the linked decision), and the concrete follow-up
  required — who or which future plan should pick it up.
- Tell the user whenever you add an entry; the file never grows quietly.

### Fold the ledger into the beads backlog

HANDOFF.md lives in the plan directory, and plan directories are ephemeral —
they may be removed once the work is over. Entries that should survive are
folded into the repository's durable issue backlog — the beads database,
one bead per item — but only on the user's say-so — strictly after the
implementation is done **and** the user has followed up on it, never in the
same turn as the completion report.

At that fold moment — and whenever opening, searching, or closing backlog
items — read **The beads backlog** in
[reference/beads.md](reference/beads.md) and follow it. It defines the item
shape (type, labels, `Discussion:` / `Decision:` comments, close reason),
how to search before folding, and the folding and closing mechanics.

## Record open questions

Every unresolved decision goes into the plan as an explicit open question, never
into chat-only memory.

- Keep a numbered **Open questions** section in PLAN.md, and seed DECISION.md
  stubs for the material ones.
- Each question states the decision needed, the options in view, and a tentative
  default.
- Number them so they can be referenced while resolving.

## Resolve the open questions

Walk the open questions and resolve every one with the user.

- Order the rounds idea-first: resolve IDEA.md questions and pass the idea
  gate (see **The idea gate** above) before raising contract or
  implementation-step questions.
- Prefer the `AskUserQuestion` tool when available: offer concrete options with
  the tentative default first as the recommended choice, and let the user supply
  a custom answer. (Exception: the idea-gate confirmation uses its own fixed
  wording and order — see **The idea gate**.)
- Fall back to plain chat when `AskUserQuestion` is unavailable — ask in your
  reply, listing the numbered questions with their options and your default.
- At most ~4 questions per round; go in rounds until nothing material is open.
- Do not stop early on the grounds of having "enough to start".

## Finalize

After each answer, fold it back into the plan files immediately.

- Move the resolved item out of **Open questions** into the section it belongs.
- Append a DECISION.md entry with the choice, the rationale, and the rejected
  alternatives.
- Refresh STATUS.md to reflect the now-current plan.

### Traceability gate

Before declaring the plan finalized, verify every decided clause is owned by a
step — review catches what is listed, not what is implied.

- Walk every DECISION.md entry, inherited ones included, clause by clause, and
  record for each operative clause the step that delivers it:

      D15 "via config" -> step 4 | parent plan step 15 | open question

- An unmapped clause means the plan is not finalized: give it an owning step,
  hand it to another plan in the family via the boundary ledger, or reopen it
  as an open question.
- Then replay each IDEA.md use case against the union of planned steps across
  the plan family; a use case no step delivers is flagged the same way.
- Then walk the contract areas listed under **Contracts** — public
  API, dependencies, RPC schema, project layout, persistent data format:
  each must either be concretely present as a fenced block in PLAN.md or be
  explicitly marked "no change". An area merely described in prose is
  unfinalized — e.g. SQLite named in the approach with no DDL block anywhere
  fails this check.
- HANDOFF.md is part of the gate: if it exists, every entry must be an
  out-of-scope discovery or link a user-made DECISION.md entry — anything
  else is scope silently dropped, and the plan is not finalized. A ledger
  that passes the gate is what later gets offered for folding into the
  beads backlog — after implementation, once the user has followed up on
  it (see **Fold the ledger into the beads backlog**).
