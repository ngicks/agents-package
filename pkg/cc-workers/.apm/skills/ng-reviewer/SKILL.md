---
name: ng-reviewer
description: >-
  Review a codebase or change by fanning out the five dedicated
  ng-reviewer-* focus subagents in parallel, scoring each finding for
  confidence, keeping only the high-confidence issues, and synthesizing
  them into one report. Use when a review should be broad and parallel
  rather than a single read-through.
---

# Reviewer

Run a parallel, multi-agent review and return only findings you are
confident are real. Modeled on the tiered review pattern: cheap, broad
fan-out for discovery; strict filtering before anything is reported.

## Scope

Review the working diff by default (run `git diff` against the base
yourself). If the caller asks to review the whole code base or a path,
scope to that instead. Establish the scope first and pass the material
itself -- the diff text or file list -- to every worker: the workers
have no Bash and cannot derive it on their own.

## Step 1 -- Fan out the five dedicated reviewers

Use the Agent tool to launch the five dedicated focus reviewers in
parallel, one subagent each:

1. `ng-reviewer-conventions` -- compliance with project rules
   (CLAUDE.md / AGENTS.md, linters, naming, layout).
2. `ng-reviewer-bugs` -- obvious correctness defects in the changed
   code: nil/null, bounds, error handling, concurrency, resource leaks.
3. `ng-reviewer-history` -- git blame/log context: does the change fit
   how this code evolved; does it reintroduce a reverted fix.
4. `ng-reviewer-docs` -- do comments/docstrings match the new
   behavior; stale or misleading docs.
5. `ng-reviewer-tests` -- missing tests, untested error paths, edge
   cases the change introduces.

Each agent already carries its focus, its worker workflow (the
`ng-focused-reviewer` skill: ground findings in real tool runs, report
everything without self-filtering), and a read-only tool set:
Read / Grep / Glob, with Bash granted only to `ng-reviewer-history`
for read-only git digging. Keep each worker's prompt lean: hand it the
scope material, not the answer -- do not pre-list the defects or
describe what it will find.

Because the other four workers have no Bash, you run any command they
need up front and paste the output into their prompts. This keeps
shell execution vetted and out of the parallel fan-out -- only
`ng-reviewer-history` runs git alongside you, and it runs read-only
commands. Running tests stays with ng-test-runner;
`ng-reviewer-tests` only reads for gaps.

Each worker returns findings as: `file:line`, severity
(blocking / minor), its own confidence (0-100), and a one-line
rationale.

## Step 2 -- Score and filter

First discard any reviewer that came back having run **0 tool calls** --
with no reads it cannot have grounded its findings, so treat that whole
return as hallucinated and drop it. For every surviving finding, assign
your own confidence score of 0-100 (is this a real, actionable issue on
this commit, not a false positive) -- treat the worker's self-reported
confidence as one signal, not a verdict. Keep only findings scoring
**>= 80**. Deduplicate findings that multiple workers reported.

## Step 3 -- Synthesize

Merge the surviving findings into one review.

## Boundaries

- Do NOT edit code or fix findings. This is review only.
- Do NOT report low-confidence or speculative findings. If it did not
  clear the bar, drop it.
- Do NOT pad. If nothing clears the bar, say the change looks clean.

## Output contract

Return a markdown review:

- **Verdict** -- approve / approve-with-nits / request-changes.
- **Blocking** -- bullets with `file:line` and the concrete problem.
- **Minor** -- non-blocking suggestions, clearly marked optional.
- **Checked** -- scope reviewed and the five focus agents that ran.
