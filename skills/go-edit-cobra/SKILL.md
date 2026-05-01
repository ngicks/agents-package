---
name: go-edit-cobra
description: "Use this when editing or adding subcommands to Go CLI. Triggers on: 'edit cmd/', 'add subcommand', 'scaffold cli', 'create go command'."
---

# Edit cobra

Generate / Edit a Go CLI project with Cobra subcommands.

## Interview

Before generating files, gather the following from the user. If provided inline (e.g. "scaffold go mytool with serve and migrate"), extract values directly — only ask for missing required fields.

| Parameter         | Required | Default                    | Example                    |
| ----------------- | -------- | -------------------------- | -------------------------- |
| Project name      | yes      | -                          | `mytool`                   |
| Module root       | yes      | -                          | `tools/mytool`             |
| Go module path    | no       | `github.com/watage/<name>` | `github.com/watage/mytool` |
| Short description | no       | `<name> CLI tool.`         | `My awesome tool.`         |
| Subcommands       | no       | _(none)_                   | `serve`, `migrate`         |

**Module root** is the directory that will contain `go.mod`. The binary's package always lives at `<module-root>/cmd/<name>/`, never directly at the module root. See "Project layout" below for the exact tree.

Subcommands can be nested using **dot notation** (`server.start`, `server.stop`) or natural language ("a server group containing start and stop"). When a dotted subcommand is given, the part before the dot becomes a parent group command and the part after becomes a child leaf command.

For each subcommand, ask for a short description if not provided. Default to `<Name> subcommand.`.

## Project layout

The skill always generates this exact tree. `<module-root>` is the path from the Interview; `<name>` is the project name. Subcommand files in `commands/` depend on what the user requested, but everything else is fixed.

```
<module-root>/
├── go.mod
└── cmd/
    ├── <name>/
    │   ├── main.go
    │   └── commands/
    │       ├── root.go
    │       ├── <subcmd>.go              # one per flat subcommand
    │       ├── <parent>.go              # one per parent group (no RunE)
    │       └── <parent>_<child>.go      # one per nested leaf
    └── internal/
        ├── cmdsignals/
        │   └── signals.go         # always generated
        └── stdiopipe/              # only when a subcommand needs cancellable stdio
            └── stdiopipe.go
```

Worked example — `mytool` at `tools/mytool` with subcommands `serve` (long-running, needs cancellable stdout), `db.migrate`, `db.query`:

```
tools/mytool/
├── go.mod
└── cmd/
    ├── mytool/
    │   ├── main.go
    │   └── commands/
    │       ├── root.go
    │       ├── serve.go
    │       ├── db.go              # parent group, no RunE
    │       ├── db_migrate.go      # leaf, init() wires to dbCmd
    │       └── db_query.go        # leaf, init() wires to dbCmd
    └── internal/
        ├── cmdsignals/
        │   └── signals.go
        └── stdiopipe/              # included because `serve` needs it
            └── stdiopipe.go
```

Why this shape:

- Binary entrypoint and its `commands/` package live under `cmd/<name>/` so a future second binary can be added as a sibling `cmd/<other>/` without moving any existing files.
- Shared helpers (`cmdsignals`, `stdiopipe`) live at `cmd/internal/` — siblings of `cmd/<name>/` — so they are reusable across binaries while still scoped to the `cmd/` tree by Go's `internal/` rules.
- Never put `commands/` directly at the module root. See "Anti-patterns" at the bottom.

## Templates

This is templates but you **must** **strictly** follow the order of elements.
DO NOT REORDER THINGS.

### `cmd/{{NAME}}/main.go`

```go
package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"

	"github.com/ngicks/go-common/contextkey"
	"{{MODULE}}/cmd/{{NAME}}/commands"
    "{{MODULE}}/cmd/internal/cmdsignals"
)

func main() {
    logger := slog.New(
		slog.NewJSONHandler(
			os.Stdout,
			&slog.HandlerOptions{
				AddSource: true,
				Level:     slog.LevelDebug,
			},
		),
	)

	ctx, stop := signal.NotifyContext(
		context.Background(),
        cmdsignals.ExitSignals[:]...,
	)
	defer stop()


    ctx = contextkey.WithSlogLogger(ctx, logger)

	if err := commands.Execute(ctx); err != nil {
        logger.ErrorContext(ctx, "stopped with an error", slog.Any("err", err))
		os.Exit(1)
	}
}
```

### `cmd/{{NAME}}/commands/root.go`

```go
package commands

import (
	"context"
	"log/slog"

	"github.com/spf13/cobra"
)

func Execute(ctx context.Context) error {
    return rootCmd.ExecuteContext(ctx)
}

var rootCmd = &cobra.Command{
		Use:           "{{NAME}}",
		Short:         "{{SHORT_DESCRIPTION}}",
		SilenceUsage:  true,
		SilenceErrors: true,
		Args:          cobra.NoArgs,
		RunE: runRoot,
}

var (
   flagA = rootCmd.PersistentFlags().String("name", "default value", "description of opton")
   flagB = rootCmd.PersistentFlags().String(...)
)

func runRoot(cmd *cobra.Command, args []string) error {
    return cmd.Help()
}

// TODO: you may add initialization logic for root internal service construct here.
```

The TODO comment line is marker for implementor: just leave it there.

### `cmd/{{NAME}}/commands/<parent>.go` (parent group command — no `RunE`)

When a subcommand has children (e.g. `server.start`), the parent is a grouping command with no run logic. Cobra shows help by default.

```go
package commands

import "github.com/spf13/cobra"

func init() {
	rootCmd.AddCommand({{parentCamel}}Cmd)
}

var {{parentCamel}}Cmd = &cobra.Command{
    Use:   "{{parent-name}}",
    Short: "{{Parent short description}}",
}

// TODO: you may add initialization logic for sub internal service construct here.
```

The TODO comment line is marker for an implementor: just leave it there.

### `cmd/{{NAME}}/commands/{{parent}}_{{child}}.go` (child leaf command, wired to parent)

```go
package commands

import "github.com/spf13/cobra"

func init() {
	{{parentCamel}}Cmd.AddCommand({{parentCamel}}{{ChildPascal}}Cmd)
}

var {{parentCamel}}{{ChildPascal}}Cmd = &cobra.Command{
    Use:   "{{child-name}}",
    Short: "{{Child short description}}",
    Args:  cobra.NoArgs,
    RunE:  run{{ParentPascal}}{{ChildPascal}},
}

func run{{ParentPascal}}{{ChildPascal}}(cmd *cobra.Command, args []string) error {
    // TODO: implement {{parent-name}} {{child-name}}
    // This function should only wire flags and positional arguments into the
    // configuration of an internal service, then invoke it.
    // Do not put business logic here.
    return nil
}
```

The comment lines are marker for an implementor: just leave it there.

Key differences from flat subcommands:

- Parent command has **no `RunE`/`Args`** — it's just a group (shows help by default)
- Child file name uses **underscore** to join levels: `commands/server_start.go`
- Child var name concatenates: `serverStartCmd`
- Child `init()` wires to **parent var**, not `rootCmd`
- 3rd level follows the same pattern: `commands/server_start_foo.go`, wired to `serverStartCmd`

### Internal helpers

`cmdsignals` is always generated — `main.go` imports it. Import path: `{{MODULE}}/cmd/internal/cmdsignals`.

`stdiopipe` is **only generated on demand** — when a subcommand actually needs cancellable stdio (e.g. a long-running `serve` or a streaming command that must unblock on `ctx.Done()`). Do not generate it speculatively. Import path when used: `{{MODULE}}/cmd/internal/stdiopipe`.

#### `cmd/internal/cmdsignals/signals.go`

```go
package cmdsignals

import (
	"os"
	"syscall"
)

// ExitSignals are the signals that should cancel top-level CLI execution.
var ExitSignals = [...]os.Signal{
	os.Interrupt,
	syscall.SIGTERM,
}
```

#### `cmd/internal/stdiopipe/stdiopipe.go`

```go
// Package stdiopipe provides a cancellable reader backed by os.Stdin.
package stdiopipe

import (
	"context"
	"io"
	"os"
	"sync"
)

var (
	onceStdin  sync.Once
	onceStdout sync.Once
	onceStderr sync.Once
)

// Stdin returns an [io.ReadCloser] which is piped to [os.Stdin] through an [io.Pipe].
//
// This is necessary because Read calls on [os.Stdin] cannot be unblocked by closing it.
//
// Only one invocation is allowed per process; a second call will panic.
func Stdin(ctx context.Context) io.ReadCloser {
	var pr *io.PipeReader
	called := false
	onceStdin.Do(func() {
		called = true
		var pw *io.PipeWriter
		pr, pw = io.Pipe()
		go func() {
			<-ctx.Done()
			pr.CloseWithError(ctx.Err())
		}()
		go func() {
			_, err := io.Copy(pw, os.Stdin)
			pw.CloseWithError(err)
		}()
	})
	if !called {
		panic("stdiopipe: Stdin is called more than once")
	}
	return pr
}

func stdout(ctx context.Context, label string, out *os.File, once *sync.Once) io.WriteCloser {
	var pw *io.PipeWriter
	called := false
	once.Do(func() {
		called = true
		var pr *io.PipeReader
		pr, pw = io.Pipe()
		go func() {
			<-ctx.Done()
			pw.CloseWithError(ctx.Err())
		}()
		go func() {
			_, err := io.Copy(out, pr)
			pr.CloseWithError(err)
		}()
	})
	if !called {
		panic("stdiopipe: " + label + " is called more than once")
	}
	return pw
}

// Stdout returns an [io.WriteCloser] which is piped to [os.Stdout] through an [io.Pipe].
//
// This is necessary because Write calls on [os.Stdout] cannot be unblocked by closing it.
//
// Only one invocation is allowed per process; a second call will panic.
func Stdout(ctx context.Context) io.WriteCloser {
	return stdout(ctx, "Stdout", os.Stdout, &onceStdout)
}

// Stderr returns an [io.WriteCloser] which is piped to [os.Stderr] through an [io.Pipe].
//
// This is necessary because Write calls on [os.Stderr] cannot be unblocked by closing it.
//
// Only one invocation is allowed per process; a second call will panic.
func Stderr(ctx context.Context) io.WriteCloser {
	return stdout(ctx, "Stderr", os.Stderr, &onceStderr)
}
```

### `go.mod`

```
module {{MODULE}}

go 1.26.0 // latest major with .0

require (
    github.com/ngicks/go-common/contextkey v0.2.0
    github.com/spf13/cobra v1.10.2
)
```

- Version notation is just for display; use latest possible version.
- Go version must stay .0 of latest major version.
  - The user may instruct to use exact versions like "use go1.26.2", in that case set that value.

## Naming Conventions

### Flat subcommands

- **Command vars**: `{{camelCase}}Cmd` — package-level `var` of `*cobra.Command`. Examples:
  - `serve` -> `serveCmd`
  - `dry-run` -> `dryRunCmd`
  - `db-migrate` -> `dbMigrateCmd`
- **Run functions**: `run{{CamelCase}}` — separate named function, not inline closure. Examples:
  - `serve` -> `runServe`
  - `dry-run` -> `runDryRun`
  - `db-migrate` -> `runDbMigrate`
- **Wiring**: each subcommand file uses `init()` to call `rootCmd.AddCommand(xxxCmd)`
- **File names**: `commands/<subcmd>.go` using the exact subcommand name (e.g. `commands/serve.go`, `commands/dry-run.go`)

### Nested subcommands

- **File names**: `commands/{{parent}}_{{child}}.go` — underscore-joined, preserving hyphens within each segment. Examples:
  - `server start` -> `commands/server_start.go`
  - `db dry-run` -> `commands/db_dry-run.go`
  - `db migrate up` (3 levels) -> `commands/db_migrate_up.go`
- **Var names**: concatenate camelCase segments. Examples:
  - `server` + `start` -> `serverStartCmd`
  - `db` + `migrate` + `up` -> `dbMigrateUpCmd`
- **Run functions**: concatenate PascalCase segments. Examples:
  - `server start` -> `runServerStart`
  - `db migrate up` -> `runDbMigrateUp`
- **Parent commands**: no `RunE`, no `Args` — cobra shows help by default
- **Wiring**: child `init()` calls `{{parentCamel}}Cmd.AddCommand(...)`, not `rootCmd`

### General rules

- **Always use `RunE`**, never `Run` — return errors instead of calling `os.Exit`
- **Default `Args`**: `cobra.NoArgs` unless the user specifies arguments
- **Root command**: package-level `var rootCmd`, delegates to `runRoot` which calls `cmd.Help()`
- **SilenceUsage + SilenceErrors**: always set on root command
- **Flags**: package-level `var` block using `rootCmd.PersistentFlags()` or `xxxCmd.Flags()` in a separate `init()`

## Generation Steps

Refer to "Project layout" for the canonical tree. Every path below is relative to the **module root** (the directory containing `go.mod`).

1. Resolve all parameters (interview or extract from user message).
2. Write `go.mod` at the module root.
3. Write `cmd/<name>/main.go`.
4. Write `cmd/<name>/commands/root.go` with `rootCmd` var and `Execute` function.
5. Write one `cmd/<name>/commands/<subcmd>.go` per flat subcommand (each with its own `init()` for `rootCmd.AddCommand(...)` wiring).
6. For nested commands, write the **parent file before child files** (children reference parent vars via `init()`):
   - Parent: `cmd/<name>/commands/<parent>.go` with no `RunE`/`Args`.
   - Child: `cmd/<name>/commands/<parent>_<child>.go`, init() calls `<parentCamel>Cmd.AddCommand(...)`.
7. Write `cmd/internal/cmdsignals/signals.go` (always — `main.go` imports it). Write `cmd/internal/stdiopipe/stdiopipe.go` **only if** a generated subcommand needs cancellable stdio; skip otherwise.
8. Run `cd <module-root> && go mod tidy` to resolve dependencies.
9. Report the generated file list to the user.

Use the **Write** tool for every file — Write creates parent directories as needed, so do not run `mkdir` separately.

## Important

- Generate files using the **Write** tool — do not use helper scripts
- Keep generated code minimal — no extra helpers, no unused imports
- If the user provides flags, add them as a separate `init()` block in the subcommand file (persistent flags on `rootCmd`, local flags on `xxxCmd`)
- `main.go` always sets up a `slog.Logger` (JSON handler, debug level, with source) and stores it in context via `contextkey.WithSlogLogger`

## Anti-patterns

Do not generate any of these. They look superficially shorter but break the layout contract.

- **`commands/` at the module root** (i.e. `<module-root>/commands/...` instead of `<module-root>/cmd/<name>/commands/...`). Adding a second binary later forces a rename of every import path. The `cmd/<name>/` wrapper costs nothing today and avoids that churn.
- **`main.go` at the module root**. Same reason — the entrypoint must live at `cmd/<name>/main.go` so a sibling `cmd/<other>/main.go` can be added without moving anything.
- **`internal/` at the module root** for the helpers in this skill. They go at `cmd/internal/` so they are scoped to binaries under `cmd/` and shared across them. (A separate module-root `internal/` for non-CLI library code is fine and unrelated.)
- **Importing `{{MODULE}}/commands`** anywhere. The only correct import for the commands package is `{{MODULE}}/cmd/<name>/commands`. If you find yourself writing the shorter form, the layout is wrong — fix the layout, not the import.
- **Skipping `cmdsignals`**. It is always generated — `main.go` imports it.
- **Generating `stdiopipe` speculatively**. Only generate it when a concrete subcommand actually needs cancellable stdio. An unused helper file is dead weight.
