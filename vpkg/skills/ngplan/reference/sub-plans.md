# Sub-plans

Detail for ngplan's **Sub-plans** section. Read this whenever a plan looks
too big for one issue, or when a plan epic already has child epics.

A plan that outgrows one issue splits hierarchically: the plan itself
becomes a **master plan** owning the whole scope end-to-end, and the details
move down into sub-plans it manages. Never split by narrowing — shrinking the
plan to a first slice and deferring the rest into succeeding plans hides
dropped scope where the user cannot easily detect it.

## Splitting is a user decision

- Treat any split — and especially any deferral of scope — as a material
  decision: raise it as a `Discussion:`, resolve it with the user, and
  record the outcome as a `Decision:` comment on the master plan.
- A reduced-scope follow-up plan is legitimate only when the user explicitly
  chose that reduction; it never happens as a silent default.

## Master plan manages, sub-plans hold the detail

- The master plan keeps its description, goal, acceptance criteria, and
  scope for the whole feature; none of them shrink when sub-plans appear.
- The master's `design` says which sub-plan delivers what, in what order,
  and what depends on what; implementation detail lives in the sub-plans.
- Each sub-plan is a child `epic` of the master (see
  [beads.md](beads.md), **Sub-plans**), with its own description, gate,
  `design`, acceptance criteria, notes, step children, and comments. It
  inherits the `plan` label, so it lists as a plan on its own.
- Order between sub-plans is `blocks` edges between the child epics, the
  same way steps are ordered.
- The master's `notes` narrate each sub-plan's state alongside its own;
  `bd show <master>` shows the children with their progress.

## Keep the boundary explicit

The split boundary is where deliverables fall through the cracks, so make it
explicit in both directions.

- **Boundary ledger, both directions** — the master's `design` and every
  sub-plan's `design` each carry the same table listing every deliverable
  the feature needs end-to-end, with the plan id and step id that owns it.
  An inbound list alone ("what the master consumes from us") is not enough;
  a deliverable owned by nobody must appear as a visible empty cell, never
  as silence.
- **Quote inherited decisions verbatim** — when a sub-plan restates an
  upstream `Decision:` comment, append a `Decision:` comment on the
  sub-plan that names the master's id and quotes the operative sentence
  word for word; never re-summarize. A compressed paraphrase can invert
  meaning and camouflage a requirement through implementation and review.
- The traceability gate walks inherited decisions too: each quoted clause
  names the sub-plan step that delivers it, or says non-goal.
