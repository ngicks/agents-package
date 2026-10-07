---
name: nggoal
description: "Explicityly called out when needed"
---

# Goal rules

Standing conventions for a multi-task autonomous run (such as a `/goal`). Apply
them on **every** turn until the run ends — not just the first.

## Ask user availability first

Before starting the run, ask whether the user stays available during it.

- Use the `AskUserQuestion` tool if it exists; if not (e.g. codex), just ask
  in a plain response and wait for the reply.
- Use this fixed wording and option order every time — never reorder or
  reword it, so the user's answer by muscle memory always lands on the same
  choice:
  - Question: "Will you stay available during this run?"
  - Option 1: "No. I'm away" — decide unclear corners autonomously and tag
    those decisions `[automatic]`.
  - Option 2: "Yes. I stay available" — raise genuinely blocking decisions
    as they come up.
- This fixed order overrides the recommended-first convention: even when
  "Yes" seems the natural recommendation, do not move it first or append
  "(Recommended)" to it.
- Ask once, at the start — never mid-run.
- If the user answers they stay available: raise genuinely blocking decisions
  to them as they come up.
- If the user answers they will be away, or does not answer: decide every
  unclear corner yourself and keep working — never stall waiting for input.
  Record such decisions as `Decision:` comments tagged `[automatic]` (see
  below).

## Work the plan from beads if `/goal` names a plan

When `/goal` asks to implement a plan (e.g. `/goal Implement <plan id>`),
the plan is a beads (`bd`) `epic` issue labelled `plan`, created by
`/ngplan`. Read it before any action.

- `bd show <id>` prints the idea (description), the implementation plan
  (`design`), the acceptance criteria, the progress notes, the step
  children, and the `Decision:` / `Discussion:` comments.
- `bd ready --exclude-type epic` is the queue: the open steps whose
  blockers are closed. Work them in that order; `bd update <step> --claim`
  when starting one.
- Read every `Decision:` comment before touching a step; an open
  `Discussion:` with no later `Decision:` naming its topic is an open
  question, handled by the availability rule above.

Record progress after each step is done.

- Close the step with what was observed:
  `bd close <step> --reason "<verified how>"`. Record only progress you can
  point to a tool result for (an edit made, a command run, a test
  observed). If something is not yet verified, leave the step open and say
  so in the notes — never close it as done.
- Append a line to the plan's notes after each step:
  `bd update <plan> --append-notes "<what is done, what is next, blockers>"`.
  Notes are append-only; never rewrite them.
- Close the plan epic only when every step is closed and the user has
  accepted the result; closing the last step does not close the epic.

You might happen to need to decide unclear corners by yourself while
implementing the plan. In that case, record your design decision as a
comment on the plan:

    bd comment <plan> "Decision: <topic> [automatic] — <choice>. Because <rationale>. Rejected: <alternatives>."

- Tag every decision made without the user `[automatic]` so the user can
  skim those comments once they are back.
- Decisions confirmed with the user need no tag.
- If the decision expands the public surface, rewrite the fenced delta
  block in `design` in the same turn (`bd update <plan> --design-file -`).

Work that leaves the plan — a defect found but not fixed, a follow-up the
scope does not cover — is born as its own issue at the moment of discovery:
`bd create "<title>" -t task --deps discovered-from:<step id> …`, then
`bd defer <id>`. Deferred is the awaiting-triage state; only the user
undefers or closes it. Tell the user each time you create one.

## Keep plan references out of durable artifacts

Code, code comments, commit messages, and project docs must stand on their
own; a reader of the repository does not have the plan open.

- Never cite plan step numbers, decision labels, or bead ids in code, code
  comments, commit messages, or project docs.
- Write the actual reason in place, in plain words, instead of pointing at a
  decision.
- References between beads (a `Decision:` naming the step ids that deliver
  it, a `discovered-from` edge) are fine — that is what the ids are for.
- Pass this rule down to any subagent you brief: paraphrase decisions into the
  brief instead of passing bare ids, because subagents echo the tokens they
  are given. Repeat it in every brief; it does not carry over.

## Delegate tasks to subagents

Delegate sizeable, independent subtasks to subagents — parallel workstreams,
wide exploration, long or noisy commands — so their output stays out of your
context.

- Do small reads and quick one-off commands yourself; delegation is not worth
  its overhead for them.
- Have each subagent return only the conclusion needed, not raw file dumps.
- If you delegate, commit to it: brief the subagent precisely the first time,
  and do not redo or re-derive work it already returned.
- You will supervise and review output from subagents.
  - Do not trust them blindly. Instead review them empirically.

## Run autonomously

You are operating autonomously; unless the user said they stay available at
the start of the run, they are not watching in real time and cannot answer
questions mid-run.

- For reversible actions that follow from the goal, proceed without asking.
  Record judgment calls as `Decision:` comments on the plan (tagged
  `[automatic]` when the user is away) instead of asking the user.
- Before ending a turn, check your last paragraph: if it is a plan, a
  question, or a promise about work not yet done ("I'll now run X"), do that
  work now with tool calls.
- End the run only when the goal is met or you are blocked on input only the
  user can provide. Do not stop, summarize, or suggest a new session on
  account of context limits — keep working.
