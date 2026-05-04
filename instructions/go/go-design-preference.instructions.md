---
description: "General Go Design Preference"
applyTo: "**/*.go"
---

### Go Personal Design Preference

Trigger `go-edit-cobra` skill when editing empty or `github.com/spf13/cobra`-backed `./cmd/**/*` .

#### Keep entrypoints thin

- **No business logic under `./cmd`.** Files under `./cmd` only parse flags / arguments and hand off to a service. Same rule for any other binary entrypoint package — it composes, it does not compute.
- **No CLI-presentation logic under `./cmd` either.** Printing, prompts, table rendering, color, terminal capability detection, spinners, and other terminal control belong in `<root>/pkg/<name>/cli/` (or a similarly named package outside `./cmd`). `./cmd` calls into that package; it does not implement it.
- Run / `main` functions return errors; never `os.Exit` from inside business code.
- When editing or creating files under `./cmd/`, use the **`go-edit-cobra` skill**. It owns Cobra-specific structure, naming, helpers, and edit operations.

#### Push logic across the package boundary

- Domain logic lives outside the entrypoint package.
- Entrypoint imports services; services do not import the entrypoint.
- A service should be usable without the CLI — designed for a programmatic caller first, a CLI wrapper second.

#### Context first

- Long-running or cancellable work takes `ctx context.Context` as the first parameter.
- Use it for cancellation, deadlines, request-scoped values; do not stash a context in a struct.

#### Dependency injection over package globals

- Pass dependencies in (constructors, function parameters). Do not rely on package-level mutable state inside service code.
- Configuration values flow in from the caller; the service does not read environment variables or files itself unless that is its only purpose.

#### Small interfaces at the consumer

- Define interfaces where they are used, not where they are implemented.
- Prefer composition over embedding tricks.

#### One responsibility per package

- A package has a single coherent purpose. Don't pile unrelated helpers into a "util" or "common" package.
- Test code lives next to the package (`_test.go`), not in a sibling "tests" directory.

#### Errors are values

- Wrap with `fmt.Errorf("...: %w", err)` when adding context.
- Return errors; do not `panic` for normal failures. `panic` is for invariants that genuinely cannot hold.

#### Don't reach into other packages' internals

- If you need it, expose it. If you can't expose it, the boundary is wrong.
- `internal/` is for packages whose API surface is not stable or not meant for external consumers — use it deliberately, not as a default dumping ground.
