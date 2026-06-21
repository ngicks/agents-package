---
name: nggoal
description: "Explicityly called out when needed"
---

# Goal rules

Standing conventions for a multi-task autonomous run (such as a `/goal`). Apply
them on **every** turn until the run ends — not just the first.

## Record progress in a STATUS file if `/goal` specifies plan files

When `/goal` asks to implement a plan file (e.g. `/goal Implement ./doc/plan/<YYYY-MM-DD>-NN-<plan_name>/PLAN.md`)  
read `STATUS.md` and/or `DECISION.md` if they exist before any action.

- A plan is a _directory_ under `./doc/plan/` (created by `/ngplan`), named
  `<YYYY-MM-DD>-NN-<plan_name>`.
- There may be `STATUS.md`, `DECISION.md` or similar files in the dir `PLAN.md` sits.

Record progress after each task is done in `STATUS.md`.

- Note what is done, what is next, and any decisions or blockers.

You might happen to need to decide unclear corners by yourself while implementing the plan.  
In that case, record your design decision in `DECISION.md`

## Delegate tasks to subagents

Spawn subagents to avoid context-window exhaustion.

- Have each subagent return only the conclusion needed, not raw file dumps.
- You will supervise and review output from subagents.
  - Do not trust them blindly. Instead review them empirically.
