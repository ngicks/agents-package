# Visual artifacts for plans

Detail for ngplan's **Use the right visual artifact** section: the mermaid
type catalogue, presentation previews, mock limitation and promotion rules,
and offloading mock generation. Read this when a plan warrants a diagram,
preview, or mock.

## Mermaid type catalogue

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

## Presentation previews

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

## Mock limitations and promotion

A mock validates interaction decisions by silently substituting fake
everything else — data sources, filesystem, timing, fixture data. State that
substitution explicitly at the moment it is cheapest to see.

- Every mock or preview states, in its header comment or a sibling
  `MOCK_LIMITS.md`: what the mock fakes, and which requirements it therefore
  cannot validate.
- A DECISION.md entry justified by "validated in the mock" must name which
  mock, and holds only for behaviors outside that mock's known-limitations
  list.
- When mock code is lifted into production, read its claimed semantics — its
  own comments — side by side against the DECISION.md wording it implements.
  A discrepancy is a deviation to raise with the user, never to copy forward.

## Offload mock generation to a subagent

Writing a GUI / TUI mock is bulk output that crowds the planning context.
When a preview is warranted, delegate its generation instead of writing it
inline.

- Use available subagent definition that best suits the task
- If the tool supports a per-call model override, choose the subagent's model
  relative to your own: step down one class when you are running as the
  highest-capability model, otherwise stay at your own class — e.g. Fable
  delegates to Opus, and Opus delegates to Opus.
- On return, review the generated files yourself — including that the
  known-limitations list is present — then link them from PLAN.md as
  described above; the linking and decision record stay your job.
- Fall back to writing the mock directly in the current context only when
  no delegation tool is available.
