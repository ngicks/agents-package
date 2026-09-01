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
  alternatives); a **Public surface delta** section (see Focus of the plan)
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

## Focus of the plan

Spend the plan's precision on the contracts — the parts that are expensive to
change later. Implementation internals can stay rough.

- **Public API** — the exported surface consumers will call: packages, types,
  functions, and their signatures — plus the surface end users actually touch:
  config file keys, CLI flags and subcommands, and environment variables.
- **Dependencies** — what the project pulls in: entries in the manifest
  (`go.mod`, `package.json`, `moon.mod.json`, …). Cheap to add, expensive to
  reverse once code builds on them.
- **RPC schema** — the wire contracts between processes: proto / OpenAPI /
  Connect definitions, endpoints, message shapes.
- **Project layout** — where things live: directories, packages / modules, and
  what depends on what.
- **Persistent data format** — anything that outlives a process: database
  schema, and the data format of files written to disk.

Nail these down concretely (real names, real fields, real paths) before
detailing implementation steps; a change to any of them after implementation
starts invalidates far more work than an internal refactor does.

### Public surface delta — fenced code, not prose

Every plan touching exported, user-visible, or durable surface — dependency
changes included, even when nothing else changes — gets a **Public surface
delta** section in PLAN.md whose authority is fenced code in the source
language. Prose may explain, but the code block defines: at plan time,
anything user-visible that is not in the block is out of scope.
Implementation may still expand the block — but only through the amendment
path below, never silently.

Enumerate in the block:

- added / removed / major-version-bumped dependencies, first — see
  **Dependency delta** below;
- added / changed / removed exported symbols, with full signatures;
- struct fields, with tags;
- config keys, as a literal example-config snippet;
- CLI flags and subcommands, as example invocations;
- durable state vocabulary — option / setting names, and the persistent data
  schema under its hard trigger: see **Persistent data delta** below.

Prose is where omissions hide — a reader cannot notice a missing line in a
paragraph. An enumerated code block makes absence visible and askable: if it
is user-visible or durable and not in the block, ask why.

#### Dependency delta — enumerated first, each addition justified

Dependency changes are surface, not housekeeping: the manifest is a durable,
consumer-visible file, and a dependency is expensive to reverse once code
builds on it. They lead the delta block and never end as prose alone.

- Enumerate added / removed / major-version-bumped dependencies at the top of
  the fenced delta, as a literal manifest diff or snippet — real module paths
  or package names, real versions.
- Every **added** dependency gets a DECISION.md entry stating why this
  dependency fits this project — license, maintenance health, footprint, fit
  with the existing stack — and which alternatives were rejected and why:
  other libraries considered, the standard library, and writing it in-repo.
- A removal states what replaces the removed capability, or that nothing
  needs it anymore.
- The block's authority applies: a dependency not enumerated is out of scope,
  and a mid-implementation addition (`go get`, `npm install`, …) goes through
  the amendment path below, never in silently.

#### Persistent data delta — schema as DDL, never prose

Durability, not visibility, is what makes a contract: data that outlives the
process is expensive to change whether or not an end user ever sees it.
"Not user-visible, therefore internal, therefore rough" is not a valid
escape hatch here.

- Hard trigger: any plan that names a database or an on-disk persistent
  format must include the schema in the Public surface delta — as fenced DDL
  (`CREATE TABLE …`, the file the code will actually embed, e.g. the sqlc
  schema file) **and** an `erDiagram` beside it — in its own subsection
  beside the proto / CLI / config ones. The DDL defines; the diagram shows
  the shape for the human reader.
- The only alternative is an explicit user-approved deferral, recorded as a
  DECISION.md entry. Naming the store in the approach while leaving the
  schema to implementation is exactly the omission this trigger exists to
  kill.
- Mid-implementation schema changes — a new table, column, or file format —
  go through the amendment path below, never in silently.

#### Expanding the delta during implementation

The delta is a gate, not a straitjacket: implementation often reveals surface
the plan missed. Expanding it is legitimate — expanding it silently never is.

- When the user is available, raise the expansion as a question and resolve
  it with them before building on it.
- When the user is away or not answering, decide yourself and keep working —
  never stall. Record the choice as a DECISION.md entry tagged `[automatic]`
  (e.g. `## <topic> [automatic]`) so the user can skim those entries once
  back.
- Either way, edit the fenced delta block in PLAN.md in the same turn: add
  the new symbols, keys, or flags with full signatures — or, for a
  dependency, its real path and version, plus the justifying DECISION.md
  entry **Dependency delta** requires. The block stays the
  single enumeration of user-visible surface — "expanded but recorded only in
  a decision entry" leaves a stale block, the exact failure this section
  exists to prevent.
- The user's later review is then just two reads: the current block, and the
  `[automatic]` decision entries.

### One code fence per file

When planned code spans multiple files, write one fenced code block per file,
each fence headed by the real file path it belongs to — never one big block
mixing several files, and never a fence with no home.

- The per-file layout makes the intended project layout visible and askable,
  the same way the surface delta makes omissions visible.
- The split itself is a plan-phase assumption, not an ultimate decision:
  better splits often appear during implementation, so implementers must not
  treat fence boundaries as binding. What is tentative is only the assignment
  of code to files — the enumerated surface (symbols, keys, flags) itself
  stays authoritative as defined, and amended, in **Public surface delta**
  above.
- When implementation lands on a different split, that is a normal refinement,
  not a deviation to escalate; material layout changes still get a DECISION.md
  entry as usual.

## Sub-plans

A plan that outgrows one directory splits hierarchically: the plan itself
becomes a **master plan** owning the whole scope end-to-end, and the details
move down into sub-plans it manages. Never split by narrowing — shrinking the
plan to a first slice and deferring the rest into succeeding plans hides
dropped scope where the user cannot easily detect it.

### Splitting is a user decision

- Treat any split — and especially any deferral of scope — as a material
  decision: raise it as an open question, resolve it with the user, and
  record the outcome as a DECISION.md entry.
- A reduced-scope follow-up plan is legitimate only when the user explicitly
  chose that reduction; it never happens as a silent default.

### Master plan manages, sub-plans hold the detail

- The master plan keeps IDEA.md, goal, success criteria, and scope for the
  whole feature; none of them shrink when sub-plans appear.
- Master PLAN.md steps say which sub-plan delivers what, in what order, and
  what depends on what; implementation detail lives in the sub-plans.
- Each sub-plan is a full plan directory with the four canonical files,
  nested under the master's `sub/` directory as
  `<master_dir>/sub/NN-<plan_name>/`, with `NN` starting at `01`.
- Master STATUS.md tracks each sub-plan's state alongside its own checklist.

### Keep the boundary explicit

The split boundary is where deliverables fall through the cracks, so make it
explicit in both directions.

- **Boundary ledger, both directions** — the master and every sub-plan each
  carry the same table listing every deliverable the feature needs
  end-to-end, with the plan and step that owns it. An inbound list alone
  ("what the master consumes from us") is not enough; a deliverable owned by
  nobody must appear as a visible empty cell, never as silence.
- **Quote inherited decisions verbatim** — when a sub-plan restates an
  upstream DECISION.md entry, quote its operative sentence or link to it
  directly; never re-summarize. A compressed paraphrase can invert meaning
  and camouflage a requirement through implementation and review.

## HANDOFF.md — ledger of what leaves the plan

Work that leaves the plan family — deferred tasks, defects found but not
fixed, required follow-ups — is recorded in a `HANDOFF.md` in the plan
directory. It is a ledger, not a license: writing an item there does not
authorize deferring it. It is also not the final resting place: once the
implementation is done and the user has reviewed it, the ledger drains into
the durable issue backlog — see **Fold the ledger into the issue backlog**
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

### Fold the ledger into the issue backlog

HANDOFF.md lives in the plan directory, and plan directories are ephemeral —
they may be removed once the work is over. Entries that should survive are
folded into the repository's durable issue backlog under `./doc/plan/issue/`,
but only on the user's say-so — strictly after the implementation is done
**and** the user has followed up on it, never in the same turn as the
completion report.

At that fold moment — and whenever opening, searching, or closing backlog
items — read [reference/issue-backlog.md](reference/issue-backlog.md) and
follow it. It defines the backlog layout (`open/` items as the authority,
`closed/`, the derived `catalog.md`), the frontmatter `tags` field, the
`scripts/issue-search.sh` frontmatter search, and the folding and closing
mechanics.

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
- Then walk the contract areas listed under **Focus of the plan** — public
  API, dependencies, RPC schema, project layout, persistent data format:
  each must either be concretely present as a fenced block in PLAN.md or be
  explicitly marked "no change". An area merely described in prose is
  unfinalized — e.g. SQLite named in the approach with no DDL block anywhere
  fails this check.
- HANDOFF.md is part of the gate: if it exists, every entry must be an
  out-of-scope discovery or link a user-made DECISION.md entry — anything
  else is scope silently dropped, and the plan is not finalized. A ledger
  that passes the gate is what later gets offered for folding into the
  issue backlog under `doc/plan/issue/` — after implementation, once the
  user has followed up on it (see **Fold the ledger into the issue
  backlog**).
