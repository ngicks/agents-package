# Visual artifacts for plans

Detail for ngplan's **Use the right visual artifact** section: the mermaid
type catalogue, the presentation-preview loop, mock limitation and promotion
rules, and offloading mock generation. Read this when a plan warrants a
diagram, preview, or mock.

## Mermaid type catalogue

Match the diagram type to the shape of the material.

Flow and behavior — things that happen over time:

| Type              | Shows                                     | Typical plan use                                          |
| ----------------- | ----------------------------------------- | --------------------------------------------------------- |
| `flowchart`       | steps, branches, decisions                | use-case workflows, control flow, error paths              |
| `sequenceDiagram` | ordered messages between actors           | RPC / protocol exchanges, multi-component use cases        |
| `stateDiagram-v2` | states and transitions                    | lifecycles, modes, connection / session state              |
| `journey`         | user steps scored by experience           | idea-phase end-to-end walkthroughs, pain-point hunting     |
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
| `kanban`        | work items in status columns   | rarely — the step children usually suffice          |
| `treemap`       | nested proportions             | relative size of packages / areas touched           |

Newer niche types exist (`venn`, `wardley`, `cynefin`, `ishikawa`,
`railroad`, …). Plan fields are rendered by the issues viewer and linted by
`crabswarm issues lint`, which refuses a fence `mermaid-lint` refuses and
re-blocks every turn until it is fixed — so prefer the long-stable types
above when either fits; a diagram that does not render is worse than prose.

Headless screenshots do not prove a diagram renders: font substitution
(measure in one face, draw in another) clips labels invisibly. Open the
page once yourself before relying on it.

## Presentation previews

Mermaid describes relationships well, but it is not a presentation layout
language. When material GUI, web, mobile, or terminal-interface decisions need
spatial or interactive evidence, also create a runnable presentation preview.

- Create a preview only when layout or interaction matters to the plan; do not
  create placeholder presentation artifacts for other work.
- Prefer the repository's existing presentation stack, dependencies, components,
  and design tokens. For example, use an isolated React / Preact entrypoint or
  story in a web project, or a small `charm.land/bubbletea/v2` program in a Go
  TUI project.
- Follow an established preview, story, example, or development-entrypoint
  convention when one exists.
- A mock that imports application code lives under the application's own
  toolchain (next to the code it imports, in a clearly named `mock` or
  `preview` entry) and is expected to graduate: the plan's reorganisation
  step either promotes it into the real feature or deletes it, and moves its
  limits file into the plan (a `notes` entry or a comment on the step).
- Keep the preview isolated from normal application behavior. Do not add a
  production route or dependency merely to host planning UI.
- Link the preview from the relevant `design` section. Record the decision it
  demonstrates, how to run it, and whether it is disposable or expected to
  graduate into production code.
- Use one or more self-contained `display-<NN>-<screen_name>.html` files only
  as a fallback when the repository has no suitable presentation stack or
  starting that stack would be disproportionate. Put them under
  `doc/mock/<plan id>/`, start numbering at `01`, use semantic HTML,
  embedded CSS, native controls, and no external assets; the reorganisation
  step deletes the directory.

### The preview loop

A preview is refined over many user-driven passes, not delivered once; a
real mock went through about fifteen (tabs, fonts, sizes, query bar,
labels page, graph zoom, section cards, borders, lightbox, TOC). Run it as
a loop:

- One subagent pass per user request (see **Offload mock generation**
  below); the brief names the one change asked for and the files the pass
  may touch.
- The planner reviews the result — screenshots and the driver's assertions
  — and opens the page once in a real browser for anything font- or
  layout-sensitive.
- One commit per pass, so a pass can be reverted alone.
- Findings appended to the limits file after every pass: what the pass
  proved, what it faked, what it could not show.
- The loop ends when the user says so, and the state of the mock at that
  point is what the `Decision:` comments cite.

## Mock limitations and promotion

A mock validates interaction decisions by silently substituting fake
everything else — data sources, filesystem, timing, fixture data. State that
substitution explicitly at the moment it is cheapest to see.

- Every mock or preview states, in its header comment or a sibling
  `MOCK_LIMITS.md` next to the mock: what the mock fakes, and which
  requirements it therefore cannot validate.
- A `Decision:` comment justified by "validated in the mock" must name which
  mock, and holds only for behaviors outside that mock's known-limitations
  list.
- When mock code is lifted into production, read its claimed semantics — its
  own comments — side by side against the `Decision:` wording it implements.
  A discrepancy is a deviation to raise with the user, never to copy forward.

## Offload mock generation to a subagent

Writing a GUI / TUI mock is bulk output that crowds the planning context.
When a preview is warranted, delegate its generation instead of writing it
inline — on the first pass and on every later one.

- Use the available subagent definition that best suits the task.
- If the tool supports a per-call model override, choose the subagent's model
  relative to your own: step down one class when you are running as the
  highest-capability model, otherwise stay at your own class — e.g. Fable
  delegates to Opus, and Opus delegates to Opus.
- On return, review the generated files yourself — including that the
  known-limitations list is present — then link them from `design` as
  described above; the linking and decision record stay your job.
- Fall back to writing the mock directly in the current context only when
  no delegation tool is available.
