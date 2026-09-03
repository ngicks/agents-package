# Contracts — focus of the plan

Detail for ngplan's **Contracts** section: what a plan must nail down
before implementation steps, and how the **Public surface delta** in PLAN.md
enumerates it. Read this before writing PLAN.md's approach, surface delta,
or implementation steps, and again whenever implementation discovers new
surface.

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

## Public surface delta — fenced code, not prose

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

### Dependency delta — enumerated first, each addition justified

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

### Persistent data delta — schema as DDL, never prose

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

### Expanding the delta during implementation

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

## One code fence per file

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

