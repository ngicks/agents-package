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
- Otherwise compute a new location `./doc/plan/<YYYY-MM-DD>-NN-<plan_name>`:
  - `<YYYY-MM-DD>` is today's date — get it from `date "+%Y-%m-%d"` rather than
    guessing.
  - `NN` is the next free 2-digit serial among that day's entries — scan
    `./doc/plan/` for existing `<date>-NN-*` entries sharing today's date, take
    the highest + 1, zero-padded from `01`. No entry for today means start at
    `01`.
  - `<plan_name>` is a short snake*case slug from the summary — use `*`, not
`-`, so it stays a single token that doesn't collide with the `-`joining
the date and`NN`.
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
- The rough scaffold still writes all four files up front, but PLAN.md stays
  a skeleton — goal, scope, known context, open questions — until the gate
  passes.

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
  use cases (actor, situation, intent, end-to-end walkthrough) and usability
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
  PLAN.md steps, what is done / in progress / blocked, and the next action. Seed
  a new one as "not started"; when elaborating, refresh it rather than reset it.
- **DECISION.md** — decision log: one entry per material decision with the choice
  made, the rationale, and the alternatives rejected. Seed stubs from the open
  questions; append a finished entry as each one resolves, rather than rewriting
  history.

Other files are welcome — later agents may add notes, diagrams, or scratch while
planning or implementing. Keep the four canonical files current.

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
- Pick the diagram type from the catalogue below rather than defaulting to
  flowchart for everything.
- A workflow diagrammed in IDEA.md often deserves a PLAN.md counterpart
  showing which components and steps deliver each leg of the flow.

#### Mermaid type catalogue

Match the diagram type to the shape of the material.

Flow and behavior — things that happen over time:

| Type              | Shows                                     | Typical plan use                                          |
| ----------------- | ----------------------------------------- | --------------------------------------------------------- |
| `flowchart`       | steps, branches, decisions                | use-case workflows, control flow, error paths              |
| `sequenceDiagram` | ordered messages between actors           | RPC / protocol exchanges, multi-component use cases        |
| `stateDiagram-v2` | states and transitions                    | lifecycles, modes, connection / session state              |
| `journey`         | user steps scored by experience           | IDEA.md end-to-end walkthroughs, pain-point hunting        |
| `timeline`        | events in chronological order             | rollout, migration, and deprecation phases                 |
| `gantt`           | schedule with durations and dependencies  | ordering across steps or sub-plans                         |

Structure and data — things that are:

| Type                 | Shows                                  | Typical plan use                                         |
| -------------------- | -------------------------------------- | --------------------------------------------------------- |
| `classDiagram`       | types, members, relationships          | public API shape, domain model                             |
| `erDiagram`          | entities, attributes, cardinality      | database schema, persistent data                           |
| `packet`             | bit / byte field layout                | wire formats, binary file headers                          |
| `architecture`       | services, groups, connections          | deployment / infrastructure topology                       |
| `C4Context` (etc.)   | system context / container views       | where the feature sits among surrounding systems           |
| `block`              | nested blocks on a grid                | component layout, memory maps                              |
| `mindmap`            | hierarchy radiating from a root        | idea-phase decomposition, scope maps                       |
| `gitGraph`           | commits, branches, merges              | branching / release strategy                               |
| `requirementDiagram` | requirements linked to elements        | formal requirement traceability                            |

Quantitative and tracking — occasionally useful evidence:

| Type            | Shows                          | Typical plan use                                  |
| --------------- | ------------------------------ | -------------------------------------------------- |
| `pie`           | shares of a whole              | sizing evidence (e.g. where time / bytes go)        |
| `xychart`       | line / bar series              | benchmarks, load or growth data behind a decision   |
| `quadrantChart` | items placed on two axes       | option triage — effort vs impact                    |
| `radar`         | multi-axis comparison          | scoring rejected vs chosen alternatives             |
| `sankey`        | volume flowing between nodes   | data volume moving between components               |
| `kanban`        | work items in status columns   | rarely — STATUS.md's checklist usually suffices     |
| `treemap`       | nested proportions             | relative size of packages / areas touched           |

Newer niche types exist (`venn`, `wardley`, `cynefin`, `ishikawa`,
`railroad`, …). Plan documents are read in many renderers — GitHub, editors,
doc sites — so prefer the long-stable types above when either fits; a diagram
that does not render is worse than prose.

#### Presentation previews

Mermaid describes relationships well, but it is not a presentation layout
language. When material GUI, web, mobile, or terminal-interface decisions need
spatial or interactive evidence, also create a runnable presentation preview.

- Create a preview only when layout or interaction matters to the plan; do not
  create placeholder presentation artifacts for other work.
- Prefer the repository's existing presentation stack, dependencies, components,
  and design tokens. For example, use an isolated React / Preact entrypoint or
  story in a web project, or a small `charm.land/bubbletea/v2` program in a Go TUI project.
- Follow an established preview, story, example, or development-entrypoint
  convention when one exists. Otherwise keep the preview under the plan
  directory so its temporary ownership is obvious.
- Keep the preview isolated from normal application behavior. Do not add a
  production route or dependency merely to host planning UI.
- Link the preview from the relevant PLAN.md section. Record the decision it
  demonstrates, how to run it, and whether it is disposable or expected to
  graduate into production code.
- Use one or more self-contained `display-<NN>-<screen_name>.html` files only as
  a fallback when the repository has no suitable presentation stack or starting
  that stack would be disproportionate. Start numbering at `01`; use semantic
  HTML, embedded CSS, native controls, and no external assets.

#### Offload mock generation to a subagent

Writing a GUI / TUI mock is bulk output that crowds the planning context.
When a preview is warranted, delegate its generation instead of writing it
inline.

- Use available subagent definition that best suits the task
- If the tool supports a per-call model override, choose the subagent's model
  relative to your own: step down one class when you are running as the
  highest-capability model, otherwise stay at your own class — e.g. Fable
  delegates to Opus, and Opus delegates to Opus.
- On return, review the generated files yourself, then link them from PLAN.md
  as described above — the linking and decision record stay your job.
- Fall back to writing the mock directly in the current context only when
  no delegation tool is available.

## Focus of the plan

Spend the plan's precision on the contracts — the parts that are expensive to
change later. Implementation internals can stay rough.

- **Public API** — the exported surface consumers will call: packages, types,
  functions, and their signatures — plus the surface end users actually touch:
  config file keys, CLI flags and subcommands, and environment variables.
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

Every plan touching exported or user-visible surface gets a **Public surface
delta** section in PLAN.md whose authority is fenced code in the source
language. Prose may explain, but the code block defines: anything user-visible
that is not in the block is out of scope by definition.

Enumerate in the block:

- added / changed / removed exported symbols, with full signatures;
- struct fields, with tags;
- config keys, as a literal example-config snippet;
- CLI flags and subcommands, as example invocations;
- durable state vocabulary — option / setting names, DB columns, file formats.

Prose is where omissions hide — a reader cannot notice a missing line in a
paragraph. An enumerated code block makes absence visible and askable: if it
is user-visible and not in the block, ask why.

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
  a custom answer.
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
