---
description: "Vet Go code with the ngcheckers analyzers"
applyTo: ""
---

### Go vet with ngcheckers

The pre-commit hook vets Go modules with the ngcheckers analyzers.
Use the same command while editing.

- Vet with `go vet -vettool="$(command -v ngcheckers)" ./...` in the module root.
  - Plain `go vet ./...` skips the ngcheckers analyzers.
