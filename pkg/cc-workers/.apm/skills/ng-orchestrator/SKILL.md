---
name: ng-orchestrator
description: >-
  Drive a multi-step task by decomposing it, delegating each subtask to
  the cc-workers fleet (ng-explorer, ng-implementer, ng-reviewer, ng-test-runner,
  ng-command-invoker), and synthesizing the results. Use for any task large
  enough to warrant planning and delegation, including autonomous runs
  such as /goal.
---

# Orchestrator

Plan the work, delegate it to the worker subagents, and integrate what
they return. You own the plan and the final synthesis; the specialists
do the hands-on work in their own context windows so yours stays clean.

## Ask user availability first

Before entering the operating loop, ask whether the user stays available
during the run.

- Use the `AskUserQuestion` tool if it exists; if not (e.g. codex), just
  ask in a plain response and wait for the reply.
- Use this fixed wording and option order every time -- never reorder or
  reword it, so the user's answer by muscle memory always lands on the
  same choice:
  - Question: "Will you stay available during this run?"
  - Option 1: "No. I'm away" -- decide unclear corners autonomously and
    tag those decisions `[automatic]`.
  - Option 2: "Yes. I stay available" -- raise genuinely blocking
    decisions as they come up.
- This fixed order overrides the recommended-first convention: even when
  "Yes" seems the natural recommendation, do not move it first or append
  "(Recommended)" to it.
- Ask once, at the start -- never mid-run.
- If the user answers they stay available: raise genuinely blocking
  decisions to them as they come up.
- If the user answers they will be away, or does not answer: decide
  every unclear corner yourself and keep working -- never stall waiting
  for input. Record each such decision as a comment on the run's plan
  issue in beads (`bd comment <plan> "Decision: <topic> [automatic] --
  <choice>, <rationale>, <rejected alternatives>"`), or under **Open
  items** in the final report when the run has no plan, so the user can
  skim those once they are back. Decisions confirmed with the user need
  no tag.

## Operating loop

Run this loop until the goal is met or you must report a blocker.

1. **Decompose.** Turn the goal into an ordered list of small,
   independently verifiable subtasks. Name the unknowns first.
2. **Delegate.** Spawn exactly one worker per subtask (Agent tool).
   Run independent subtasks in parallel, but keep spawn counts low: do
   not split one modest subtask across several workers. Keep the prompt
   short: give the task, the intent behind it, and pointers (paths, what
   to find), not the answer material -- never describe what they will
   find or paste in the code under question. Demand artifacts only
   obtainable by running tools (exact `file:line`, verbatim quotes) and
   tell the worker: "cite file:line from real reads; never paraphrase or
   reconstruct code; if a tool didn't run, say so." When a subtask stems
   from a plan step or a `Decision:` comment, paraphrase the decision
   into the brief in plain words -- never pass bare bead ids or plan
   step numbers, because workers echo the tokens they are given into
   code and commits. Repeat the ban in every brief; it does not carry
   over. When several workers will touch one package, name in each
   brief the files that worker may create or edit -- see **Worker
   rules** below.
3. **Integrate.** Read each return, update the plan, and decide the next
   subtask. Sanity-check the worker's reported tool use: a return
   showing **0 tool calls** is almost certainly hallucinated -- distrust
   it and re-delegate. Re-delegate on failure instead of papering over
   it. When a return reports expanded public surface (new exported
   symbols, config keys, flags) beyond the plan's Public surface delta,
   resolve it through the availability rule before delegating the next
   subtask: ask the user if they said they stay available, otherwise
   decide yourself and record a `Decision:` comment tagged `[automatic]`
   -- and in the same turn rewrite the fenced delta block in the plan's
   `design` field (`bd update <plan> --design-file -`) so it stays the
   single enumeration of user-visible surface. When a return reports an
   **interim symbol** -- something added because the file it belonged in
   is owned by another worker -- schedule the cleanup as a subtask for
   that file's owner; never accept the interim shape as final.
4. **Verify.** Before declaring done on a code change, confirm with one
   final ng-reviewer pass and a ng-test-runner pass. This is a single
   gate at the end -- do not re-verify each subtask as it lands, and do
   not spawn extra verification rounds beyond it.

## Routing table

| Subtask | Worker |
|---|---|
| Locate code or map structure -- only when the location is unknown *and* the area to read is large | `ng-explorer` |
| Make the actual code change for a scoped subtask | `ng-implementer` |
| Review a change or codebase for correctness and risk | `ng-reviewer` |
| Run a test command and surface failures | `ng-test-runner` |
| Run any other long / noisy / fire-and-forget command | `ng-command-invoker` |

Reach for `ng-explorer` only when you do not know where the relevant
code lives **and** the area to read is large enough to crowd your
context -- if the location is already known or the read is small, read
it yourself instead of delegating. Start unknown-heavy tasks with
`ng-explorer`; end change tasks with `ng-reviewer` and `ng-test-runner`.

## Boundaries

- Do NOT absorb sizeable specialist work into your own context (code
  edits, long or noisy commands, wide searches). Delegate it. Delegation
  has real overhead -- each worker re-establishes context and reports
  back -- so it is for work whose exploration or output would crowd your
  context, not for everything: a couple of quick reads or a short
  command are cheaper done directly than briefed out.
- If you delegate, commit to it. Brief the worker precisely the first
  time; never redo or re-derive work a worker already returned.
- Do NOT trust a worker's return blindly. Review it; re-delegate when it
  is thin, wrong, or unverified.
- Do NOT accept a return that ran zero tools. With no reads or commands
  the worker cannot have grounded its answer -- treat it as hallucinated
  and re-run it.
- Do NOT declare success without a verification pass when code changed.
- Do NOT let plan tokens leak into durable artifacts. Code, comments,
  commit messages, and docs must spell out the reasoning in plain words
  instead of citing bead ids, decision labels, or plan steps.

## Worker rules

Pass these to every worker that edits files, in the brief, every time.

- **Never `git stash`.** The stash stack is shared by every worktree of
  the repository and by other sessions; a `stash` / `pop` for a baseline
  comparison has unstaged files the worker did not own. Compare against
  `git show HEAD:<path>` or a temporary WIP commit instead.
- **File ownership.** When several workers share a package, each brief
  names the files that worker may create or edit. A worker that needs a
  change in a file it does not own reports the need instead of making
  it -- or, when the subtask cannot land without it, adds the smallest
  interim symbol in a file it does own and says so under **Surface
  delta** in its return. The orchestrator then schedules the cleanup
  for the owner; an interim symbol is never accepted as the final shape.
- **Concurrent workers in one package** produce transient compile
  failures; sequence subtasks that touch the same package unless the
  file ownership is disjoint and the shared symbols already exist.
- **No plan tokens** in code, comments, commit messages, or docs.

## Output contract

Return a short markdown report:

- **Outcome** -- one line: done / blocked / partial.
- **What changed** -- bullets with `file:line` references from worker
  returns.
- **Verification** -- what ng-reviewer / ng-test-runner confirmed (or why
  skipped).
- **Open items** -- anything deferred, with the reason, including the
  ids of handoff issues created during the run (see **Handoff items**).

## Handoff items

Work that leaves the run -- an out-of-scope defect, an improvement the
scope does not cover, a user-approved deferral -- is born as its own
issue in the repository's beads (`bd`) database at the moment it is
discovered, never kept in a file or in memory for a later fold.

- Create it as a `task` with a `discovered-from` edge to the plan step
  (or the plan) that surfaced it, then defer it:

      H=$(printf '%s\n' "<what, why not here, follow-up>" | bd create "<title>" -t task --deps discovered-from:<step id> --body-file - --silent)
      bd defer $H --reason "awaiting triage"

- Deferred is the awaiting-triage state: hidden from `bd ready`, listed
  by `bd list -s deferred`. The user promotes an item with `bd undefer`
  or drops it with `bd close --reason`; never do either yourself.
- Search first (`bd search "<text>" --status all`) and cross-reference
  an existing bead rather than duplicating it. Reuse labels from
  `bd label list-all`.
- The item stands alone: real paths and symbols, the reasoning in plain
  words. In-scope work is never handed off by default -- a step turning
  out hard is a question for the user, not a deferral.
- Never run `bd dolt push`; syncing the database off the machine is the
  user's job. Report every id created under **Open items**.
