---
name: go-edit-cobra
description: "Use when authoring or editing a Go CLI built on spf13/cobra. Auto-triggers on any edit/create under ./cmd, plus phrases: 'scaffold cli', 'create go command', 'add subcommand', 'rename subcommand', 'remove subcommand', 'add flag to <cmd>', 'move <cmd> under <cmd>', 'edit cmd/'."
---

# Cobra CLI authoring

Scaffold a new Cobra CLI, edit an existing one, or apply Cobra-specific design rules. Cobra-only — see "Out of scope" for non-Cobra layouts.

General Go design philosophy lives in `instructions/go/go-general-design.instructions.md`. Go-version idioms live in `instructions/go/go-basics.instructions.md`. This file owns Cobra-specific structure, naming, helpers, and edit mechanics — do not restate the other two.

## When this skill applies

Activates when **either** condition holds:

- The user message contains: `scaffold cli`, `create go command`, `add subcommand`, `rename subcommand`, `remove subcommand`, `add flag to <cmd>`, `move <cmd> under <cmd>`, `edit cmd/`.
- The agent is about to edit or create files under `./cmd/`.

After activation, run the pre-flight checks below before any edit.

## Pre-flight checks

1. **Cobra detection.** Look for `github.com/spf13/cobra` in `go.mod` or any import. If absent, do not apply Cobra rules — ask whether to introduce Cobra, otherwise stop.
2. **Layout classification.** Categorize the project:
   - **Canonical** — `<root>/cmd/<name>/main.go` + `<root>/cmd/<name>/commands/` + `<root>/cmd/internal/cmdsignals/` exist. → Proceed.
   - **Close variant** — `cmd/<name>/main.go` + `cmd/<name>/commands/` exist but `cmd/internal/` differs (e.g. helpers under module-root `internal/`, no `cmdsignals` yet). → Proceed; do not force-migrate existing files.
   - **Non-canonical Cobra** — e.g. `cmd/root.go` at module root, or `cobra-cli` defaults. → **Stop and ask.** Likely mid-migration or accidental drift.
   - **Non-Cobra** — no Cobra import. → Out of scope; report and stop.

## Cobra design rules

These rules are Cobra-specific. The "thin run function" rule is a Cobra-mechanics consequence of the broader "no business logic under `./cmd`" rule in `go-general-design.instructions.md` — do not restate that rule here.

- **`RunE` only**, never `Run`. Return errors; do not `os.Exit` from a command body.
- **Root command**: `SilenceUsage: true`, `SilenceErrors: true`. Delegate to a named `runRoot`.
- **Default `Args`**: `cobra.NoArgs`. **Change it** when positional arguments fit the command better — e.g. `cobra.ExactArgs(1)`, `cobra.MinimumNArgs(1)`, `cobra.MaximumNArgs(2)`, `cobra.RangeArgs(1, 3)`, `cobra.MatchAll(cobra.ExactArgs(1), customValidator)`. Treat positional args as the natural shape when the command operates on a target (`mytool inspect <path>`, `mytool delete <id>...`); flags are for options on top of that target. The templates set `cobra.NoArgs` as a safe placeholder, not a recommendation.
- **Command vars**: package-level `var xxxCmd = &cobra.Command{...}`. `init()` calls `<parent>Cmd.AddCommand(xxxCmd)`.
- **Run functions are named** (`runXxx`), not inline closures.
- **Run functions are thin wiring**: read flags, read positional args, call a service, return its error.
- **Group parents**: no `RunE`, no `Args` by default. They MAY own persistent flags / aliases / pre-run hooks when intentional.

### Canonical flag pattern

Package-level `var (...)` block whose values are the pointer returned by `xxxCmd.Flags().<Type>(...)` or `xxxCmd.PersistentFlags().<Type>(...)`. Read via the package-level pointer; do not call `cmd.Flags().Get*` from inside `runXxx`.

```go
var (
    flagName = rootCmd.PersistentFlags().String("name", "default", "description of option")
    flagPort = rootCmd.PersistentFlags().Int("port", 8080, "listen port")
)
```

Exception: when a flag must bind into an external configuration struct, use the `var name T` + `init()` `StringVar`-style form. The `*T` form is the default.

## Project layout (canonical)

```
<module-root>/
├── go.mod
└── cmd/
    ├── <name>/
    │   ├── main.go
    │   └── commands/
    │       ├── root.go
    │       ├── <subcmd>.go              # one per flat leaf
    │       ├── <parent>.go              # one per group (no RunE)
    │       └── <parent>_<child>.go      # one per nested leaf
    └── internal/
        ├── cmdsignals/
        │   └── signals.go               # always present
        └── stdiopipe/                   # only when a subcommand needs cancellable stdio
            └── stdiopipe.go
```

Why this shape:

- `cmd/<name>/` lets a future second binary be added as `cmd/<other>/` with no churn.
- `cmd/internal/` is a sibling of all binary packages, sharing helpers under Go's `internal/` rule.
- Never put `commands/` directly at the module root. See "Anti-patterns".

## Naming conventions

### Flat subcommands

- **Var**: `{{camelCase}}Cmd` — e.g. `serve` → `serveCmd`, `dry-run` → `dryRunCmd`.
- **Run function**: `run{{PascalCase}}` — e.g. `runServe`, `runDryRun`.
- **File name**: `commands/<subcmd>.go` preserving hyphens — `commands/serve.go`, `commands/dry-run.go`.
- **Wiring**: `init()` calls `rootCmd.AddCommand(xxxCmd)`.

### Nested subcommands

- **File name**: `commands/{{parent}}_{{child}}.go` — underscore-joined, hyphens preserved per segment. `server start` → `commands/server_start.go`. 3-level: `commands/db_migrate_up.go`.
- **Var**: concatenate camelCase — `serverStartCmd`, `dbMigrateUpCmd`.
- **Run function**: concatenate PascalCase — `runServerStart`, `runDbMigrateUp`.
- **Parent group**: no `RunE`, no `Args` by default.
- **Wiring**: child `init()` calls `<parentCamel>Cmd.AddCommand(...)`, not `rootCmd`.

## Templates

These are templates. **Strictly follow** the order of elements. Do **NOT** reorder.

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
	RunE:          runRoot,
}

var (
	flagName = rootCmd.PersistentFlags().String("name", "default", "description of option")
)

func runRoot(cmd *cobra.Command, args []string) error {
	return cmd.Help()
}

// TODO: you may add initialization logic for root internal service construct here.
```

The TODO comment is a marker for the implementor — leave it.

### `cmd/{{NAME}}/commands/<subcmd>.go` (flat leaf)

```go
package commands

import "github.com/spf13/cobra"

func init() {
	rootCmd.AddCommand({{subCamel}}Cmd)
}

var {{subCamel}}Cmd = &cobra.Command{
	Use:   "{{sub-name}}",
	Short: "{{Sub short description}}",
	Args:  cobra.NoArgs,
	RunE:  run{{SubPascal}},
}

func run{{SubPascal}}(cmd *cobra.Command, args []string) error {
	// TODO: implement {{sub-name}}
	// This function should only wire flags and positional arguments into the
	// configuration of an internal service, then invoke it.
	// Do not put business logic here.
	return nil
}
```

### `cmd/{{NAME}}/commands/<parent>.go` (parent group — no `RunE`)

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

### `cmd/{{NAME}}/commands/<parent>_<child>.go` (nested leaf)

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

Differences vs. flat:

- Parent has no `RunE` / `Args`.
- Child file uses underscore between levels.
- Child var concatenates: `serverStartCmd`.
- Child `init()` wires to **parent var**, not `rootCmd`.
- 3-level follows the same pattern (`server_start_foo.go`, wired to `serverStartCmd`).

### `go.mod`

```
module {{MODULE}}

go {{GO_VERSION}} // latest major with .0, e.g. 1.26.0

require (
	github.com/ngicks/go-common/contextkey v0.0.0 // resolved by `go get @latest`
	github.com/spf13/cobra v0.0.0                 // resolved by `go get @latest`
)
```

Version policy:

- **Go version**: latest major with `.0` (e.g. `go 1.26.0`). User may override with an explicit version.
- **Direct dependencies**: latest possible. Workflow: `go get <module>@latest` for each direct dep, then `go mod tidy`. (Plain `tidy` does not bump already-required modules.)

## Workflows

### Scaffold a new project

Interview (extract from user message inline; only ask for missing required fields):

| Parameter         | Required | Default                    | Example                    |
| ----------------- | -------- | -------------------------- | -------------------------- |
| Project name      | yes      | -                          | `mytool`                   |
| Module root       | yes      | -                          | `tools/mytool`             |
| Go module path    | no       | `github.com/watage/<name>` | `github.com/watage/mytool` |
| Short description | no       | `<name> CLI tool.`         | `My awesome tool.`         |
| Subcommands       | no       | _(none)_                   | `serve`, `migrate`         |

Subcommands accept dot notation (`server.start`) or natural language ("a server group containing start and stop"). Dotted = parent group + child leaf.

Generation steps (relative to module root):

1. Resolve all parameters.
2. Write `go.mod` (with placeholder `v0.0.0` lines per the template).
3. Write `cmd/<name>/main.go`.
4. Write `cmd/<name>/commands/root.go`.
5. Write one `cmd/<name>/commands/<subcmd>.go` per flat leaf.
6. For nested commands, write the parent **before** child files. Then write children.
7. Copy `helpers/cmd/internal/cmdsignals/signals.go` → `<root>/cmd/internal/cmdsignals/signals.go`. Copy `stdiopipe/stdiopipe.go` only if a subcommand needs cancellable stdio.
8. For each direct dep in `go.mod`: `go get <module>@latest`.
9. `go mod tidy`.
10. Run the post-edit validation chain (see below).
11. Report the generated file list to the user.

Use **Write** for every file. Write creates parent directories — do not run `mkdir` separately.

### Edit an existing project

Pre-flight checks first (Cobra detection, layout classification). Then pick the operation; each entry below lists what to touch.

#### Subcommand structure

| Operation                           | Files / actions                                                                                                                                                             | Ask the user when                                                                                                                     |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Add flat subcommand                 | new `commands/<subcmd>.go` (flat-leaf template)                                                                                                                             | —                                                                                                                                     |
| Add nested subcommand               | new `commands/<parent>_<child>.go`; if parent missing, also write `commands/<parent>.go`                                                                                    | —                                                                                                                                     |
| Rename subcommand                   | rename file, rename `<old>Cmd` → `<new>Cmd`, rename `run<Old>` → `run<New>`, update `init()` `AddCommand` call. Search for any external reference (tests, docs, completion) | —                                                                                                                                     |
| Remove leaf                         | delete file                                                                                                                                                                 | —                                                                                                                                     |
| Remove group                        | delete file + all children                                                                                                                                                  | If children exist (cascade vs refuse)                                                                                                 |
| Promote leaf → group                | drop `RunE` from leaf var, split logic into a new child file                                                                                                                | Where original `RunE` body, `Args`, `Aliases`, `Example`, `PreRunE`, `PostRunE`, and flags go (parent persistent / new child / split) |
| Demote group → leaf                 | merge child into parent var, give it a `RunE`                                                                                                                               | If children exist (merge / refuse)                                                                                                    |
| Move leaf under different parent    | rename file (`<old-parent>_<name>.go` → `<new-parent>_<name>.go`), rename var, rename run func, rewire `init()` to new parent                                               | If new parent missing                                                                                                                 |
| Move subtree under different parent | rename every descendant file / var / run func; rewire each `init()`                                                                                                         | If new parent missing                                                                                                                 |

#### Flag

| Operation                               | Files / actions                                                                                                                                                                                                                              |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Add                                     | extend the package-level `var` block in the target command file; choose persistent (root or group) vs local (leaf)                                                                                                                           |
| Remove                                  | drop from `var` block; remove every read                                                                                                                                                                                                     |
| Rename                                  | flag-name string + Go identifier in `var` block; check `Flags().Lookup`, `Flag(name)`, `Flags().Get*`, `LocalFlags()`, `InheritedFlags()`, `BindPFlag`/Viper bindings, env-var names, `RegisterFlagCompletionFunc`, tests, READMEs, examples |
| Change type                             | update the `var` declaration call (`String` → `Int` etc.) and every read                                                                                                                                                                     |
| Change default / shorthand / usage text | update the `var` declaration arguments                                                                                                                                                                                                       |
| Move scope (persistent ↔ local)        | move the `var` declaration to the appropriate command's `Flags()` / `PersistentFlags()`; update reads if scope name changes                                                                                                                  |
| Mark required / hidden / deprecated     | call `cmd.MarkFlagRequired(name)` / `Flags().MarkHidden(name)` / `Flags().MarkDeprecated(name, "msg")` in `init()`                                                                                                                           |

#### Command metadata

`Use`, `Short`, `Long`, `Example`, `Aliases`, `Annotations`, `SuggestFor`, `Hidden`, `Deprecated` — edit the `cobra.Command` literal in the target file.

`PreRunE`, `PostRunE`, `PersistentPreRunE`, `PersistentPostRunE` — set on the `cobra.Command` literal; assign a named function (`preRunXxx`, `postRunXxx`) defined in the same file.

#### Completion

- **Positional-argument completion**: set `ValidArgs`, `ValidArgsFunction`, or `cobra.FixedCompletions(...)` on the `cobra.Command` literal.
- **Flag-value completion**: call `cmd.RegisterFlagCompletionFunc(name, fn)` in `init()`.

## Helper catalog

Brief catalog only — full source lives at `${SKILL-DIR}/helpers/cmd/internal/<helper>/`. To emit, copy the file into `<project-root>/cmd/internal/<helper>/...` (paths line up 1:1).

| Helper       | Import path                          | Purpose                                                          | Signature(s)                                                                           | Use when                                                                                                    |
| ------------ | ------------------------------------ | ---------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `cmdsignals` | `{{MODULE}}/cmd/internal/cmdsignals` | exit-signal list for `signal.NotifyContext`                      | `var ExitSignals [...]os.Signal`                                                       | Always when scaffolding (main.go imports it). For existing projects, only when adopting this template.      |
| `stdiopipe`  | `{{MODULE}}/cmd/internal/stdiopipe`  | cancellable `os.Stdin` / `os.Stdout` / `os.Stderr` via `io.Pipe` | `Stdin(ctx) io.ReadCloser`, `Stdout(ctx) io.WriteCloser`, `Stderr(ctx) io.WriteCloser` | A subcommand blocks on stdio and must unblock on `ctx.Done()`. Single-use per process — second call panics. |

## Post-edit validation

Run after **every** edit and after scaffolding, in this order:

1. `go mod tidy` — only when imports / dependencies changed.
2. `goimports -w <changed_files>`. If `goimports` is missing, run `go install golang.org/x/tools/cmd/goimports@latest`. If install fails, fall back to `gofmt -w` and surface the install failure to the user.
3. `go vet ./...` — full module. Cobra `init()` wiring crosses package boundaries, so package-scoped vet is unsafe.
4. `go test ./...` — full module.

Edits in this skill are best-effort textual changes. The validation chain (vet + test) is the safety net for rename / move operations that touch identifiers across many files.

## Anti-patterns

Do not generate any of these — they look superficially shorter but break the layout contract.

- **`commands/` at the module root** (i.e. `<root>/commands/...` instead of `<root>/cmd/<name>/commands/...`). A second binary forces a rename of every import path.
- **`main.go` at the module root.** Same reason — entrypoint must live at `cmd/<name>/main.go`.
- **`internal/` at the module root for these helpers.** They go at `cmd/internal/`. (A separate module-root `internal/` for non-CLI library code is fine.)
- **Importing `{{MODULE}}/commands`** anywhere. The only correct import is `{{MODULE}}/cmd/<name>/commands`.
- **Skipping `cmdsignals`.** Always generated for scaffold; `main.go` imports it.
- **Generating `stdiopipe` speculatively.** Only when a concrete subcommand needs it.
- **Reading flags via `cmd.Flags().Get*`** when a package-level `*T` pointer exists. Use the pointer.
- **Putting business logic inside `RunE`.** Business logic lives outside `./cmd` per `go-general-design.instructions.md`.

## Out of scope

- Migrating non-canonical projects to the canonical layout (skill detects + asks; user drives migration).
- Frameworks other than `spf13/cobra`.
- `cobra-cli` code generation.
- AST-based rewriting (`go/ast`, `dst`); plain `Edit` / `Write` only.
