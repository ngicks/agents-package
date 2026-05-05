---
name: go-edit-cobra
description: "Use when authoring or editing a Go CLI built on spf13/cobra. Auto-triggers on any edit/create under ./cmd, plus phrases: 'scaffold cli', 'create go command', 'add subcommand', 'rename subcommand', 'remove subcommand', 'add flag to <cmd>', 'move <cmd> under <cmd>', 'edit cmd/'."
---

# Cobra CLI authoring

Scaffold a new Cobra CLI, edit an existing one, or apply Cobra-specific design rules. Cobra-only — see "Out of scope" for non-Cobra layouts.

## Pre-flight checks

Run before any edit.

1. **Mode detection.** Inspect `<root>/cmd/`.
   - **Missing or empty** → **Scaffold mode**. Skip the remaining checks; jump to "Scaffold a new project".
   - **Populated** → **Edit mode**; continue.
2. **Cobra detection** (edit mode only). Look for `github.com/spf13/cobra` in `go.mod` or any import.
   - Absent → out of scope; report and stop.
3. **Layout classification** (edit mode only). Categorize the project:
   - **Canonical** — `<root>/cmd/<name>/main.go` + `<root>/cmd/<name>/commands/` + `<root>/cmd/internal/cmdsignals/` exist. → Proceed.
   - **Close variant** — `cmd/<name>/main.go` + `cmd/<name>/commands/` exist but `cmd/internal/` differs (e.g. helpers under module-root `internal/`, no `cmdsignals` yet). → Proceed; do not force-migrate existing files.
   - **Non-canonical Cobra** — e.g. `cmd/root.go` at module root, or `cobra-cli` defaults. → **Stop and ask.** Likely mid-migration or accidental drift.

## Cobra design rules

These rules are Cobra-specific. The "thin run function" rule is the Cobra-mechanics consequence of the broader "no business logic under `./cmd`" rule.

- **`RunE` only**, never `Run`. Return errors; do not `os.Exit` from a command body.
- **Root command**: `SilenceUsage: true`, `SilenceErrors: true`. Delegate to a named `runRoot`.
- **Default `Args`**: `cobra.NoArgs`. **Change it** when positional arguments fit the command better — e.g. `cobra.ExactArgs(1)`, `cobra.MinimumNArgs(1)`, `cobra.MaximumNArgs(2)`, `cobra.RangeArgs(1, 3)`, `cobra.MatchAll(cobra.ExactArgs(1), customValidator)`. Treat positional args as the natural shape when the command operates on a target (`mytool inspect <path>`, `mytool delete <id>...`); flags are for options on top of that target. The templates set `cobra.NoArgs` as a safe placeholder, not a recommendation.
- **One wrapper function per command.** Every Cobra construction lives inside an unexported `func {{name}}Cmd(parent *cobra.Command)`. The function builds the `cobra.Command` literal, declares flag variables in a local `var (...)` block, binds them via `cmd.Flags().<Type>Var(...)`, calls children's wrapper functions on the new `cmd`, and ends with `parent.AddCommand(cmd)`. There are **no package-level `*Cmd` variables** and **no `init()` functions** for wiring.
- **Root is the special case.** `func rootCmd() *cobra.Command` (no `parent`). It returns the configured root and is invoked from `Execute(ctx)`. All top-level subcommands are wired by `rootCmd()` calling each subcommand's wrapper function.
- **Run functions are named** (`run{{Name}}`) and live at package level. **Run functions are thin wiring**: read positional args, call a service, return its error. Business logic is forbidden under `./cmd`.
- **`RunE` is either a direct reference (`RunE: run{{Name}}`) or a thin closure adapter** that forwards captured flag values: `RunE: func(cmd *cobra.Command, args []string) error { return run{{Name}}(cmd, args, flagFoo, flagBar) }`. The closure body must contain only that single forwarding call — no logic.
- **Group parents**: no `RunE`, no `Args` by default. They MAY own persistent flags, aliases, or pre-run hooks when intentional. When a persistent flag must reach a child's run function, declare the flag's `var` in the parent wrapper and pass its address as an extra parameter to the child wrapper (`{{child}}Cmd(cmd, &flagShared)`).
- **Non-subcommand files inside `commands/` MUST be prefixed with `zz_`** (e.g. `zz_helpers.go`, `zz_validation.go`). Files without the `zz_` prefix are reserved for the canonical subcommand mapping (`<name>.go` for flat leaves and group parents, `<parent>_<child>.go` for nested leaves). The `zz_` prefix marks shared helpers and any other package-level code that is not a single subcommand definition. (A leading single `_` cannot be used: `cmd/go` ignores any file whose name starts with `_` or `.`. The `zz_` form is Go-compatible and sorts last in directory listings, mirroring the `zz_generated_*.go` convention.)

### Canonical flag pattern

Inside the wrapper function, declare every flag as a local in a single `var (...)` block at the top, then bind it with the `*Var` family (`StringVar`, `IntVar`, `BoolVarP`, ...) — **never** the pointer-returning form (`String`, `Int`, ...). This keeps the binding API uniform with `BoolFunc` (which never returns a pointer) and concentrates storage declarations in one block.

```go
func serveCmd(parent *cobra.Command) {
	var (
		flagHost string
		flagPort int
	)

	cmd.Flags().StringVar(&flagHost, "host", "0.0.0.0", "listen host")
	cmd.Flags().IntVar(&flagPort, "port", 8080, "listen port")

	cmd := &cobra.Command{
		Use:   "serve",
		Short: "run the HTTP server",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runServe(cmd, args, flagHost, flagPort)
		},
	}


	parent.AddCommand(cmd)
}

func runServe(cmd *cobra.Command, args []string, host string, port int) error {
	// ...
}
```

Exception: when a flag must bind into an external configuration struct, pass the struct field's address to `*Var`. The local `var` form is the default.

## Project layout (canonical)

```
<module-root>/
├── go.mod
├── cmd/
│   ├── <name>/
│   │   ├── main.go
│   │   └── commands/
│   │       ├── root.go                  # rootCmd() + Execute(ctx) + runRoot
│   │       ├── zz_<helper>.go           # any non-subcommand helper file (prefix zz_)
│   │       ├── <subcmd>.go              # one per flat leaf
│   │       ├── <parent>.go              # one per group (no RunE)
│   │       └── <parent>_<child>.go      # one per nested leaf
│   └── internal/
│       ├── cmdsignals/
│       │   └── signals.go               # always present
│       └── stdiopipe/                   # only when a subcommand needs cancellable stdio
│           └── stdiopipe.go
├── loggerfactory/
│   └── loggerfactory.go                 # always present; --log / --log-level wiring
└── pkg/
    └── <name>/
        ├── config.go                    # service config struct + env + config-file loader
        ├── <service>.go                 # internal service implementation
        └── cli/                         # CLI-presentation code (printing, prompts, tables, colors)
            └── <ui>.go
```

Why this shape:

- `cmd/<name>/` lets a future second binary be added as `cmd/<other>/` with no churn.
- `cmd/internal/` is a sibling of all binary packages, sharing helpers under Go's `internal/` rule.
- `loggerfactory/` sits at module root (not under `cmd/internal/`) so `pkg/<name>` code can import its level constants — notably `LevelTrace` and `LevelFatal` — and emit records at levels the CLI knows how to render. The flag wiring is still CLI-only; the package is shared because the level constants are shared.
- `pkg/<name>/` holds the actual service. `./cmd` is wiring only — flags, positional args, and (logger-only) env vars feed into a service constructed from `pkg/<name>`.
- `pkg/<name>/cli/` holds CLI-presentation code (printing, prompts, tables, colors, spinners). `RunE` calls into it and returns its error.
- The `zz_` prefix on non-subcommand files makes the file → subcommand mapping unambiguous: any file without `zz_` is a single subcommand definition. (`_` prefix is **not** usable — `cmd/go` ignores files starting with `_` or `.`.)
  - as per Go's file name rule, `<helper>` can not be `test`, `$GOARCH`(e.g. `amd64`, etc), `$GOOS`(e.g. `windows`, etc)
- Never put `commands/` directly at the module root. See "Anti-patterns".

## Service package & configuration

The CLI binary is wiring; the service is `./pkg/<name>`. Two rules govern where inputs are read.

### Env vars

Env vars MUST NOT be read directly anywhere under `./cmd`. All env-var reads live in `./pkg/<name>/config.go`.

The `loggerfactory` helper is the one delegated reader: `loggerfactory.ReadEnv(config, appName, env)` overrides the logger config from the supplied `env` slice (passed in by `root.go`, typically `os.Environ()`). The helper owns the variable names it recognizes; `./cmd` code never spells them out and never calls `os.Getenv`.

### `./pkg/<name>/config.go`

`config.go` owns the service's configuration struct and centralizes its inputs:

- Cobra flag bindings — the wrapper function under `./cmd/<name>/commands/` may pass `&config.Field` to `*Var` (the "external configuration struct" exception in "Canonical flag pattern").
- Env-var reads.
- Configuration-file unmarshaling.

A single struct definition typically serves both flag binding and file unmarshaling. Split only when an actual conflict appears (e.g. the flag-friendly shape diverges from the on-disk shape).

### Configuration file

Path resolution order:

1. `$<NAME>_CONF` if set.
2. Otherwise `${XDG_CONFIG_HOME:-$HOME/.config}/<name>/config.json`.

`<NAME>` follows the upper-case rule above; `<name>` is the project name verbatim (matching the binary name used elsewhere in this layout).

## Naming conventions

### Flat subcommands

- **Wrapper function**: `{{camelCase}}Cmd` — e.g. `serve` → `serveCmd`, `dry-run` → `dryRunCmd`. Signature: `func {{camelCase}}Cmd(parent *cobra.Command)`.
- **Run function**: `run{{PascalCase}}` — e.g. `runServe`, `runDryRun`.
- **File name**: `commands/<subcmd>.go` preserving hyphens — `commands/serve.go`, `commands/dry-run.go`.
- **Wiring**: `rootCmd()` calls `{{camelCase}}Cmd(cmd)` once.

### Nested subcommands

- **File name**: `commands/{{parent}}_{{child}}.go` — underscore-joined, hyphens preserved per segment. `server start` → `commands/server_start.go`. 3-level: `commands/db_migrate_up.go`.
- **Wrapper function**: concatenate camelCase — `serverStartCmd`, `dbMigrateUpCmd`. Same signature shape as flat.
- **Run function**: concatenate PascalCase — `runServerStart`, `runDbMigrateUp`.
- **Parent group**: no `RunE`, no `Args` by default.
- **Wiring**: parent's wrapper calls `{{parentCamel}}{{ChildPascal}}Cmd(cmd)`. 3-level follows the same chain (`server_start_foo.go` is wired from inside `serverStartCmd`).

### Non-subcommand files

- **File name prefix**: leading `zz_`. Examples: `zz_helpers.go`, `zz_validation.go`.
- These files contain helpers, shared types — anything that is part of the `commands` package but is not a single subcommand definition.
- The file name has no other constraint beyond the `zz_` prefix.
- Do **not** use a leading `_`: `cmd/go` silently ignores files (and directories) whose names begin with `_` or `.`, so an `_logger.go` would never be compiled.

## Templates

These are templates. **Strictly follow** the order of elements. Do **NOT** reorder.

### `cmd/{{NAME}}/main.go`

`main.go` only handles signal wiring and process exit. The final error is written unconditionally to stderr because logging is opt-in via `--log` / `--log-level`.

```go
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"

	"{{MODULE}}/cmd/{{NAME}}/commands"
	"{{MODULE}}/cmd/internal/cmdsignals"
)

func main() {
	ctx, stop := signal.NotifyContext(
		context.Background(),
		cmdsignals.ExitSignals[:]...,
	)
	defer stop()

	if err := commands.Execute(ctx); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
```

### `cmd/{{NAME}}/commands/root.go`

Owns the root command and its `runRoot`. The root wrapper delegates persistent log-flag registration to the `loggerfactory` helper and installs a `PersistentPreRun` hook that builds the logger and injects it into `cmd.Context()`. There is **no** logger glue file under `commands/` — all of it lives in `{{MODULE}}/loggerfactory`.

```go
package commands

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/ngicks/go-common/contextkey"
	"github.com/spf13/cobra"

	"{{MODULE}}/loggerfactory"
)

func Execute(ctx context.Context) error {
	return rootCmd().ExecuteContext(ctx)
}

func rootCmd() *cobra.Command {
	var logConfig *loggerfactory.Config

	cmd := &cobra.Command{
		Use:           "{{NAME}}",
		Short:         "{{SHORT_DESCRIPTION}}",
		SilenceUsage:  true,
		SilenceErrors: true,
		Args:          cobra.NoArgs,
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			if err := loggerfactory.ReadEnv(logConfig, "{{NAME}}", os.Environ()); err != nil {
				fmt.Fprintln(os.Stderr, "warning:", err)
			}
			logger := loggerfactory.BuildLogger(logConfig)
			slog.SetDefault(logger)
			cmd.SetContext(contextkey.WithSlogLogger(cmd.Context(), logger))
		},
		RunE: runRoot,
	}

	logConfig = loggerfactory.RegisterFlags(cmd)

	// TODO: declare root flags inside a `var (...)` block above the literal and
	// bind them with `cmd.PersistentFlags().<Type>Var(&flag, ...)`. When `runRoot`
	// needs the value, switch RunE to a closure adapter:
	//   RunE: func(cmd *cobra.Command, args []string) error {
	//       return runRoot(cmd, args, flagName)
	//   }

	// TODO: wire subcommands here, e.g.:
	//   serveCmd(cmd)

	// TODO: you may add initialization logic for root internal service construct here.

	return cmd
}

func runRoot(cmd *cobra.Command, args []string) error {
	return cmd.Help()
}
```

The TODO comments are markers for the implementor — leave them.

The `loggerfactory` helper (see "Helper catalog") owns logger config, the persistent log flags, the env-var override reader, and the `BuildLogger` constructor. Logging is **opt-in** via two persistent flags declared with `pflag.BoolFunc` (presence enables, optional `=value` overrides the default):

- `--log[=text|json]` — enables logging; chooses format. Default format when `--log` is given without a value: `json`. Values are case-insensitive.
- `--log-level[=trace|debug|info|warn|error|fatal]` — enables logging; chooses level. Default level when `--log-level` is given without a value: `info`. Levels map to `slog.Level` values: `trace`=-8, `debug`=-4, `info`=0, `warn`=4, `error`=8, `fatal`=12. Values are case-insensitive.

The presence of either flag enables logging. When both are absent (and no env-var override applies), the logger is `slog.DiscardHandler`. `loggerfactory.RegisterFlags(cmd)` returns the logger-related `*Config` populated during flag parsing; `root.go` stores it and its `PersistentPreRun` first calls `loggerfactory.ReadEnv(logConfig, "{{NAME}}", os.Environ())` to layer env-var overrides on top of the parsed flag values, then calls `loggerfactory.BuildLogger(logConfig)` to construct the configured logger. The env-var names are the helper's contract — `commands/` code passes the app name and the env slice and otherwise stays out of it.

### `cmd/{{NAME}}/commands/<subcmd>.go` (flat leaf)

```go
package commands

import "github.com/spf13/cobra"

func {{subCamel}}Cmd(parent *cobra.Command) {
	cmd := &cobra.Command{
		Use:   "{{sub-name}}",
		Short: "{{Sub short description}}",
		Args:  cobra.NoArgs,
		RunE:  run{{SubPascal}},
	}

	// TODO: declare flags inside a `var (...)` block above the literal and bind
	// them with `cmd.Flags().<Type>Var(&flag, ...)`. Switch RunE to a closure
	// adapter that forwards captured values into run{{SubPascal}}.

	parent.AddCommand(cmd)
}

func run{{SubPascal}}(cmd *cobra.Command, args []string) error {
	// TODO: implement {{sub-name}}
	// This function should only wire flags and positional arguments into the
	// configuration of an internal service, then invoke it.
	// Do not put business logic here.
	return nil
}
```

After scaffolding, add `{{subCamel}}Cmd(cmd)` to `rootCmd()` (or the enclosing parent's wrapper if nested).

### `cmd/{{NAME}}/commands/<parent>.go` (parent group — no `RunE`)

```go
package commands

import "github.com/spf13/cobra"

func {{parentCamel}}Cmd(parent *cobra.Command) {
	cmd := &cobra.Command{
		Use:   "{{parent-name}}",
		Short: "{{Parent short description}}",
	}

	// TODO: wire children here, e.g.:
	//   {{parentCamel}}{{ChildPascal}}Cmd(cmd)

	parent.AddCommand(cmd)
}

// TODO: you may add initialization logic for sub internal service construct here.
```

### `cmd/{{NAME}}/commands/<parent>_<child>.go` (nested leaf)

```go
package commands

import "github.com/spf13/cobra"

func {{parentCamel}}{{ChildPascal}}Cmd(parent *cobra.Command) {
	cmd := &cobra.Command{
		Use:   "{{child-name}}",
		Short: "{{Child short description}}",
		Args:  cobra.NoArgs,
		RunE:  run{{ParentPascal}}{{ChildPascal}},
	}

	// TODO: declare flags inside a `var (...)` block above the literal and bind
	// them with `cmd.Flags().<Type>Var(&flag, ...)`. Switch RunE to a closure
	// adapter that forwards captured values into run{{ParentPascal}}{{ChildPascal}}.

	parent.AddCommand(cmd)
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

- Parent group has no `RunE` / `Args`.
- Child file uses underscore between levels.
- Child wrapper concatenates: `serverStartCmd`.
- Child is wired from the **parent group's wrapper**, not from `rootCmd()`. 3-level follows the same pattern (`server_start_foo.go` is wired from inside `serverStartCmd`).

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
5. Write one `cmd/<name>/commands/<subcmd>.go` per flat leaf. Then edit `root.go` to call `{{subCamel}}Cmd(cmd)` inside `rootCmd()` for each.
6. For nested commands, write the parent **before** child files. Wire the parent into `rootCmd()`. Then write children and add `{{parentCamel}}{{ChildPascal}}Cmd(cmd)` calls inside the parent's wrapper function.
7. Copy `helpers/cmd/internal/cmdsignals/signals.go` → `<root>/cmd/internal/cmdsignals/signals.go`. Copy `helpers/loggerfactory/loggerfactory.go` → `<root>/loggerfactory/loggerfactory.go`. Copy `helpers/cmd/internal/stdiopipe/stdiopipe.go` → `<root>/cmd/internal/stdiopipe/stdiopipe.go` only if a subcommand needs cancellable stdio.
8. For each direct dep in `go.mod`: `go get <module>@latest`.
9. `go mod tidy`.
10. Run the post-edit validation chain (see below).
11. Report the generated file list to the user.

Use **Write** for every file. Write creates parent directories — do not run `mkdir` separately.

### Edit an existing project

Pre-flight checks first (Cobra detection, layout classification). Then pick the operation; each entry below lists what to touch.

#### Subcommand structure

| Operation                           | Files / actions                                                                                                                                                                                                          | Ask the user when                                                                                                                     |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Add flat subcommand                 | new `commands/<subcmd>.go` (flat-leaf template); add `{{subCamel}}Cmd(cmd)` call inside `rootCmd()` in `commands/root.go`                                                                                                | —                                                                                                                                     |
| Add nested subcommand               | new `commands/<parent>_<child>.go`; add `{{parentCamel}}{{ChildPascal}}Cmd(cmd)` call inside the parent's wrapper. If parent missing, also write `commands/<parent>.go` and add `{{parentCamel}}Cmd(cmd)` to `rootCmd()` | —                                                                                                                                     |
| Rename subcommand                   | rename file; rename wrapper `{{old}}Cmd` → `{{new}}Cmd`; rename `run{{Old}}` → `run{{New}}`; update the wiring call in the parent wrapper. Search for any external reference (tests, docs, completion)                   | —                                                                                                                                     |
| Remove leaf                         | delete file; remove its wiring call from the parent wrapper                                                                                                                                                              | —                                                                                                                                     |
| Remove group                        | delete file + all children; remove the group's wiring call from `rootCmd()`                                                                                                                                              | If children exist (cascade vs refuse)                                                                                                 |
| Promote leaf → group                | drop `RunE` from leaf cmd literal; split logic into a new child file; add the new child's wiring call inside the (now-promoted) wrapper                                                                                  | Where original `RunE` body, `Args`, `Aliases`, `Example`, `PreRunE`, `PostRunE`, and flags go (parent persistent / new child / split) |
| Demote group → leaf                 | inline child wiring into parent wrapper; give the cmd a `RunE`                                                                                                                                                           | If children exist (merge / refuse)                                                                                                    |
| Move leaf under different parent    | rename file (`<old-parent>_<name>.go` → `<new-parent>_<name>.go`); rename wrapper and run func; remove the wiring call from the old parent wrapper and add it to the new one                                             | If new parent missing                                                                                                                 |
| Move subtree under different parent | rename every descendant file / wrapper / run func; move every affected wiring call to the appropriate parent wrapper                                                                                                     | If new parent missing                                                                                                                 |

#### Flag

| Operation                               | Files / actions                                                                                                                                                                                                                                                                               |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Add                                     | extend the local `var (...)` block in the target wrapper; bind via `cmd.Flags().<Type>Var(&flag, ...)` or `cmd.PersistentFlags().<Type>Var(...)`; if `run{{Name}}` consumes it, switch `RunE` to a closure adapter and add the parameter to `run{{Name}}`                                     |
| Remove                                  | drop from the `var` block; remove the binding call; remove the parameter from `run{{Name}}` and update the closure adapter (revert to direct reference if no flags remain)                                                                                                                    |
| Rename                                  | flag-name string + Go identifier in `var` block; binding call; closure adapter (if any); `run{{Name}}` parameter. Check `Flags().Lookup`, `Flag(name)`, `LocalFlags()`, `InheritedFlags()`, `BindPFlag`/Viper bindings, env-var names, `RegisterFlagCompletionFunc`, tests, READMEs, examples |
| Change type                             | update the `var` declaration; switch the binding to the corresponding `<Type>Var`; update the `run{{Name}}` parameter type                                                                                                                                                                    |
| Change default / shorthand / usage text | update the binding call arguments                                                                                                                                                                                                                                                             |
| Move scope (persistent ↔ local)        | move both the `var` declaration and the binding call to the appropriate command's wrapper, and use `Flags()` vs `PersistentFlags()`. When a parent's persistent flag must reach a child's run func, pass `&flag` as an extra parameter to the child wrapper                                   |
| Mark required / hidden / deprecated     | call `cmd.MarkFlagRequired(name)` / `cmd.Flags().MarkHidden(name)` / `cmd.Flags().MarkDeprecated(name, "msg")` inside the wrapper, after binding the flag                                                                                                                                     |

#### Command metadata

`Use`, `Short`, `Long`, `Example`, `Aliases`, `Annotations`, `SuggestFor`, `Hidden`, `Deprecated` — edit the `cobra.Command` literal inside the wrapper.

`PreRunE`, `PostRunE`, `PersistentPreRunE`, `PersistentPostRunE` — set on the `cobra.Command` literal; assign a named function (`preRun{{Name}}`, `postRun{{Name}}`) defined in the same file. Use a closure adapter to forward captured flag values when needed, mirroring the `RunE` rule.

#### Completion

- **Positional-argument completion**: set `ValidArgs`, `ValidArgsFunction`, or `cobra.FixedCompletions(...)` on the `cobra.Command` literal inside the wrapper.
- **Flag-value completion**: call `cmd.RegisterFlagCompletionFunc(name, fn)` inside the wrapper, after binding the flag.

## Helper catalog

Brief catalog only — full source lives at `${SKILL-DIR}/helpers/<source-path>/`. The source path under `helpers/` mirrors the destination path under `<project-root>/`, so `helpers/cmd/internal/cmdsignals/` → `<project-root>/cmd/internal/cmdsignals/`, `helpers/loggerfactory/` → `<project-root>/loggerfactory/`, etc.

| Helper           | Import path                              | Purpose                                                          | Signature(s)                                                                                                                          | Use when                                                                                                    |
| ---------------- | ---------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `cmdsignals`     | `{{MODULE}}/cmd/internal/cmdsignals`     | exit-signal list for `signal.NotifyContext`                      | `var ExitSignals [...]os.Signal`                                                                                                      | Always when scaffolding (main.go imports it). For existing projects, only when adopting this template.      |
| `loggerfactory`  | `{{MODULE}}/loggerfactory`               | `--log` / `--log-level` flag wiring, env-var overrides, opt-in `*slog.Logger`; `Level{Trace,Fatal}` constants reusable from `pkg/<name>` | `RegisterFlags(cmd) *Config`, `ReadEnv(*Config, appName string, env []string) error`, `BuildLogger(*Config) *slog.Logger`, `BuildLoggerTo(*Config, io.Writer) *slog.Logger`, `type Config`, `LevelTrace`, `LevelFatal` | Always when scaffolding (root.go imports it). For existing projects, only when adopting this template.      |
| `stdiopipe`      | `{{MODULE}}/cmd/internal/stdiopipe`      | cancellable `os.Stdin` / `os.Stdout` / `os.Stderr` via `io.Pipe` | `Stdin(ctx) io.ReadCloser`, `Stdout(ctx) io.WriteCloser`, `Stderr(ctx) io.WriteCloser`                                                | A subcommand blocks on stdio and must unblock on `ctx.Done()`. Single-use per process — second call panics. |

## Post-edit validation

Run after **every** edit and after scaffolding, in this order:

1. `go mod tidy` — only when imports / dependencies changed.
2. `goimports -w <changed_files>`. If `goimports` is missing, run `go install golang.org/x/tools/cmd/goimports@latest`. If install fails, fall back to `gofmt -w` and surface the install failure to the user.
3. `go vet ./...` — full module. The wrapper-function chain crosses package boundaries on `parent.AddCommand`, so package-scoped vet is unsafe.
4. `go test ./...` — full module.

Edits in this skill are best-effort textual changes. The validation chain (vet + test) is the safety net for rename / move operations that touch identifiers across many files.

## Anti-patterns

Do not generate any of these — they look superficially shorter but break the layout contract.

- **`commands/` at the module root** (i.e. `<root>/commands/...` instead of `<root>/cmd/<name>/commands/...`). A second binary forces a rename of every import path.
- **`main.go` at the module root.** Same reason — entrypoint must live at `cmd/<name>/main.go`.
- **`internal/` at the module root for these helpers.** They go at `cmd/internal/`. (A separate module-root `internal/` for non-CLI library code is fine.)
- **Importing `{{MODULE}}/commands`** anywhere. The only correct import is `{{MODULE}}/cmd/<name>/commands`.
- **Skipping `cmdsignals`.** Always generated for scaffold; `main.go` imports it.
- **Skipping `loggerfactory`.** Always generated for scaffold; `root.go` imports it for `--log` / `--log-level` wiring.
- **Re-implementing logger glue under `commands/`.** The logger config struct, the `--log` / `--log-level` flag callbacks, and `BuildLogger` MUST live in `<module-root>/loggerfactory`. Do not copy them back into a `zz_logger.go` or any file under `commands/`, and do not relocate the package under `cmd/internal/` — `pkg/<name>` needs to import its `Level` constants.
- **Generating `stdiopipe` speculatively.** Only when a concrete subcommand needs it.
- **Package-level `var xxxCmd = &cobra.Command{...}`** or any `init()` that calls `AddCommand`. All Cobra construction lives inside the wrapper function `{{name}}Cmd(parent)`; wiring happens via the parent calling its children's wrappers.
- **Pointer-returning flag APIs (`Flags().String(...)`, `Flags().Int(...)`)** at any scope. Always use the `*Var` family with a local declared in the wrapper's `var (...)` block. This keeps the binding shape uniform with `pflag.BoolFunc`.
- **Reading flags via `cmd.Flags().Get*`.** Use the captured flag variable from the wrapper's `var (...)` block; pass it into `run{{Name}}` via a `RunE` closure adapter when needed.
- **Non-subcommand files in `commands/` without the `zz_` prefix.** Anything that isn't a single subcommand definition (shared helpers, package-internal types) MUST be `zz_<name>.go`. **Never use a leading `_`** — `cmd/go` ignores files starting with `_` or `.`, so they would silently never compile.
- **Putting business logic inside `RunE`.** Business logic lives outside `./cmd`; `RunE` is wiring only — either a direct `run{{Name}}` reference or a thin closure adapter that forwards captured flag values.
- **Putting CLI-presentation code inside `RunE` or anywhere under `./cmd`.** Printing, prompts, table rendering, color, terminal capability detection, spinners — these live in `<root>/pkg/<name>/cli/`. `RunE` calls into that package and returns its error.
- **Reading env vars under `./cmd`.** No `os.Getenv`, no `os.LookupEnv`, no manual scanning of `os.Environ()`. The only allowed env-var consumer reachable from `./cmd` is `loggerfactory.ReadEnv`, called from `root.go`'s `PersistentPreRun`; it owns the variable names. Every other env var lives in `./pkg/<name>/config.go`.

## Out of scope

- Migrating non-canonical projects to the canonical layout (skill detects + asks; user drives migration).
- Frameworks other than `spf13/cobra`.
- `cobra-cli` code generation.
- AST-based rewriting (`go/ast`, `dst`); plain `Edit` / `Write` only.
