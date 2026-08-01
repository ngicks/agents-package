---
name: ngplan
description: 'Create or elaborate a plan directory under ./doc/plan/ (PLAN.md, STATUS.md, DECISION.md, plus optional presentation previews) — draft a rough scaffold first, record open questions, then resolve them with the user. Use when starting, drafting, editing, reviewing, or continuing a plan/planning, e.g. "make a plan", "look at a plan", "continue on plan/planning".'
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

## Emit the rough scaffold

Write the plan directory now, as a rough first pass — do not wait for answers.

- New plan — create the directory, including `./doc/plan/` itself if it does not
  yet exist, then write the three canonical files defined under **Canonical
  files** below.
- Existing plan — update them in place; keep what still holds.
- Fill what is known. Mark everything uncertain as a rough spot rather than
  guessing silently; an incomplete first pass is expected.
- Tell the user where it was written and call out the rough spots so they can
  read them.

## Canonical files

- **PLAN.md** — the implementation plan: title and one-line summary; goal /
  success criteria; scope and non-goals; context (real file paths, current
  behavior); approach (chosen design plus rejected alternatives); ordered
  implementation steps, each independently verifiable and naming real files and
  symbols; testing and verification; risks; and a numbered **Open questions**
  section that drains to empty as they resolve.
- **STATUS.md** — living progress log: current state, a checklist mirroring the
  PLAN.md steps, what is done / in progress / blocked, and the next action. Seed
  a new one as "not started"; when elaborating, refresh it rather than reset it.
- **DECISION.md** — decision log: one entry per material decision with the choice
  made, the rationale, and the alternatives rejected. Seed stubs from the open
  questions; append a finished entry as each one resolves, rather than rewriting
  history.

Other files are welcome — later agents may add notes, diagrams, or scratch while
planning or implementing. Keep the three canonical files current.

Reference actual file paths and symbols, never placeholders.

### Use the right visual artifact

Keep the plan itself in markdown so it stays readable, diffable, and easy to
update.

- Use markdown tables for comparisons, such as options and their trade-offs.
- Use mermaid code fences when structure beats prose: architecture /
  component relationships, data flow, state machines, sequence interactions,
  and navigation between GUI screens.
- A diagram that restates a one-line fact is noise; leave simple sections as
  prose.

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

## Focus of the plan

Spend the plan's precision on the contracts — the parts that are expensive to
change later. Implementation internals can stay rough.

- **Public API** — the exported surface consumers will call: packages, types,
  functions, and their signatures.
- **RPC schema** — the wire contracts between processes: proto / OpenAPI /
  Connect definitions, endpoints, message shapes.
- **Project layout** — where things live: directories, packages / modules, and
  what depends on what.
- **Persistent data format** — anything that outlives a process: database
  schema, and the data format of files written to disk.

Nail these down concretely (real names, real fields, real paths) before
detailing implementation steps; a change to any of them after implementation
starts invalidates far more work than an internal refactor does.

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
