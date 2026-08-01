---
description: "Basic instructions for my preference"
applyTo: "*"
---

### Base preference

- Make routine judgment calls (naming, defaults, choice among equivalent approaches) yourself and note them.
- Ask back the user — using `AskUserQuestion` (if available) or just a response — when different readings of the request would lead to materially different work, or before destructive / scope-changing actions.
- Do not emit redundant code / comments when coding. Write:
  - How in code
  - What in tests
  - Why not in code comments.
    - e.g. why you didn't do thing A or B.

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
