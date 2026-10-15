---
description: "Tool preference for formatting, linting, and vetting"
applyTo: ""
---

### Tool preference

Use these tools while editing.
The hk pre-commit hooks scaffolded by the `hk-*` skills run the same commands.

#### Task runner

Prefer the toolchain's built-in task runner within a single project; use `just` for anything the toolchain does not cover.

- Inside one project, use what its toolchain already provides.
  - e.g. Deno has the tasks concept (`deno task`); Go often handles everything through `go generate` and plain `go` commands.
- Add `just` (a `justfile`) when tasks fall outside any single toolchain:
  - The project has no built-in task runner.
  - Tasks span multiple projects — e.g. a mono-repo mixing a node.js WebGUI, other services, and deployment. Put a `justfile` at the repository top even though each subproject has its own runner; let it delegate to them.
- NEVER use make (a `Makefile`); reach for `just` wherever you would otherwise use make.
- If `just` is missing from the environment, do NOT silently fall back to make or any other tool.
  - Ask the user whether to continue with another tool or stop.

#### Go

- Format with `golangci-lint fmt <files>`.
  - Do not run `gofmt` or `go fmt`.
- Lint with `golangci-lint run ./...` at the module root.
  - Add `--fix` to apply automatic fixes.
- Vet with `go vet -vettool="$(command -v ngcheckers)" ./...` at the module root.
  - Plain `go vet ./...` skips the ngcheckers analyzers.

#### Python

- Format with `ruff format <files>`.
- Lint with `ruff check <files>`.
  - Add `--fix` to apply automatic fixes.
- Do not run `black`, `isort`, `flake8`, or `pylint`.

#### Mermaid diagrams

- After editing a mermaid diagram in markdown or `.mmd` files, run `mermaid-lint <files>`.
  - Add `--fix` to repair mechanical errors such as arrows and missing colons.
