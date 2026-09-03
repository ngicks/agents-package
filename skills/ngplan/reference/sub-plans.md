# Sub-plans

Detail for ngplan's **Sub-plans** section. Read this whenever a plan looks
too big for one directory, or when a plan already has a `sub/` directory.

A plan that outgrows one directory splits hierarchically: the plan itself
becomes a **master plan** owning the whole scope end-to-end, and the details
move down into sub-plans it manages. Never split by narrowing — shrinking the
plan to a first slice and deferring the rest into succeeding plans hides
dropped scope where the user cannot easily detect it.

## Splitting is a user decision

- Treat any split — and especially any deferral of scope — as a material
  decision: raise it as an open question, resolve it with the user, and
  record the outcome as a DECISION.md entry.
- A reduced-scope follow-up plan is legitimate only when the user explicitly
  chose that reduction; it never happens as a silent default.

## Master plan manages, sub-plans hold the detail

- The master plan keeps IDEA.md, goal, success criteria, and scope for the
  whole feature; none of them shrink when sub-plans appear.
- Master PLAN.md steps say which sub-plan delivers what, in what order, and
  what depends on what; implementation detail lives in the sub-plans.
- Each sub-plan is a full plan directory with the four canonical files,
  nested under the master's `sub/` directory as
  `<master_dir>/sub/NN-<plan_name>/`, with `NN` starting at `01`.
- Master STATUS.md tracks each sub-plan's state alongside its own checklist.

## Keep the boundary explicit

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

