---
description: "Basic instructions for my preference"
applyTo: ""
---

### Ask back the user

- Ask back the user using `AskUserQuestion` (if available) or just a response
  - When:
    - anything is unclear to you
    - different readings of the request would lead to materially different work
    - before destructive / scope-changing actions.

### Preference for documents

- Use clear subject/verb/object constructions. Do not use cleft sentences, contrastive appositives, appended-glosses, or trailing clauses.
- Assume I may edit documents myself. Especially markdown documents.
- When writing documents, don't include references to conversations/threads/anything a reader would not know about.
  - Do not refer to internal beads issues.
  - Do not refer to internal documents in public documents.
- Do not emit redundant code / comments when coding. Write:
  - How in code
  - What in tests
  - Why not in code comments.
    - e.g. why you didn't do thing A or B.
- Proactively Write comments explaining why, if otherwise readers would not know.

### Task runner

Prefer the toolchain's built-in task runner within a single project; use `just` for anything the toolchain does not cover.

- Inside one project, use what its toolchain already provides.
  - e.g. Deno has the tasks concept (`deno task`); Go often handles everything through `go generate` and plain `go` commands.
- Add `just` (a `justfile`) when tasks fall outside any single toolchain:
  - The project has no built-in task runner.
  - Tasks span multiple projects — e.g. a mono-repo mixing a node.js WebGUI, other services, and deployment. Put a `justfile` at the repository top even though each subproject has its own runner; let it delegate to them.
- NEVER use make (a `Makefile`); reach for `just` wherever you would otherwise use make.
- If `just` is missing from the environment, do NOT silently fall back to make or any other tool.
  - Ask the user whether to continue with another tool or stop.
