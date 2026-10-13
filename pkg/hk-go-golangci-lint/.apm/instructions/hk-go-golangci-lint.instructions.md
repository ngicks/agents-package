---
description: "Format and lint Go code with golangci-lint"
applyTo: ""
---

### Go formatting and linting

The pre-commit hook formats and lints staged Go files with golangci-lint.
Use the same commands while editing.

- Format with `golangci-lint fmt <files>`.
  - Do not run `gofmt` or `go fmt`.
- Lint with `golangci-lint run ./...` at the module root.
  - Add `--fix` to apply automatic fixes.
