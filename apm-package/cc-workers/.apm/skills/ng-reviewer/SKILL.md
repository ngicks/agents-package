---
name: ng-reviewer
description: >-
  Review a codebase or change by fanning out five parallel Sonnet review
  subagents over distinct focuses, scoring each finding for confidence,
  keeping only the high-confidence issues, and synthesizing them into one
  report. Use when a review should be broad and parallel rather than a
  single read-through.
---

# Reviewer

Run a parallel, multi-agent review and return only findings you are
confident are real. Modeled on the tiered review pattern: cheap, broad
fan-out for discovery; strict filtering before anything is reported.

## Scope

Review the working diff by default (`git diff` against the base). If the
caller asks to review the whole code base or a path, scope to that
instead. Establish the scope first and pass it to every worker.

## Step 1 -- Fan out five Sonnet reviewers

Use the Agent tool to launch **five** review subagents in parallel, each
set to the **sonnet** model, each given the scope and exactly one focus:

1. **Conventions** -- compliance with project rules (CLAUDE.md / AGENTS.md,
   linters, naming, layout).
2. **Bugs** -- obvious correctness defects in the changed code: nil/null,
   bounds, error handling, concurrency, resource leaks.
3. **History** -- git blame/log context: does the change fit how this
   code evolved; does it reintroduce a reverted fix.
4. **Comments and docs** -- do comments/docstrings match the new
   behavior; stale or misleading docs.
5. **Tests and edges** -- missing tests, untested error paths, edge
   cases the change introduces.

Keep each worker's prompt lean: hand it the scope and its one focus,
not the answer -- do not pre-list the defects or describe what it will
find. Require artifacts only obtainable by running tools (exact
`file:line`, verbatim quotes) and instruct it: "cite file:line from real
reads; never paraphrase or reconstruct code; if a tool didn't run, say
so."

Each worker returns findings as: `file:line`, severity
(blocking / minor), and a one-line rationale.

## Step 2 -- Score and filter

First discard any reviewer that came back having run **0 tool calls** --
with no reads it cannot have grounded its findings, so treat that whole
return as hallucinated and drop it. For every surviving finding, assign
a confidence score of 0-100 (is this a real, actionable issue on this
commit, not a false positive). Keep only findings scoring **>= 80**.
Deduplicate findings that multiple workers reported.

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
- **Checked** -- scope reviewed and the five focuses that ran.
