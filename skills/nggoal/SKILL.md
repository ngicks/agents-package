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
- Ask once, at the start — never mid-run.
- If the user answers they stay available: raise genuinely blocking decisions
  to them as they come up.
- If the user answers they will be away, or does not answer: decide every
  unclear corner yourself and keep working — never stall waiting for input.
  Record such decisions in `DECISION.md` tagged `[automatic]` (see below).

## Record progress in a STATUS file if `/goal` specifies plan files

When `/goal` asks to implement a plan file (e.g. `/goal Implement ./doc/plan/<YYYY-MM-DD>-NN-<plan_name>/PLAN.html`)  
read `STATUS.md` and/or `DECISION.md` if they exist before any action.

- A plan is a _directory_ under `./doc/plan/` (created by `/ngplan`), named
  `<YYYY-MM-DD>-NN-<plan_name>`.
- There may be `STATUS.md`, `DECISION.md` or similar files in the dir `PLAN.html` sits.

Record progress after each task is done in `STATUS.md`.

- Note what is done, what is next, and any decisions or blockers.
- Record only progress you can point to a tool result for (an edit made, a
  command run, a test observed). If something is not yet verified, write it as
  unverified — never as done.

You might happen to need to decide unclear corners by yourself while implementing the plan.  
In that case, record your design decision in `DECISION.md`

- Tag every entry decided without the user as `[automatic]`, e.g.
  `## <topic> [automatic]`, so the user can skim those entries once they are
  back.
- Entries confirmed with the user need no tag.

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
  Record judgment calls in `DECISION.md` (tagged `[automatic]` when the user
  is away) instead of asking the user.
- Before ending a turn, check your last paragraph: if it is a plan, a
  question, or a promise about work not yet done ("I'll now run X"), do that
  work now with tool calls.
- End the run only when the goal is met or you are blocked on input only the
  user can provide. Do not stop, summarize, or suggest a new session on
  account of context limits — keep working.
