# Command-structure templates

The command-tree scaffolding: the entrypoint, the root command, the three subcommand shapes, and `go.mod`.

These are templates — **strictly follow** the order of elements; do **NOT** reorder.

The two mandatory subcommand templates live with their domains: `version` in [versioning.md](versioning.md), `config` in [configuration.md](configuration.md).

The service config source (`pkg/<name>/config.go`) is in [config-source.md](config-source.md).

## Contents

- [`cmd/{{NAME}}/main.go`](#cmdnamemaingo) — signal wiring + process exit
- [`cmd/{{NAME}}/commands/root.go`](#cmdnamecommandsrootgo) — `rootCmd()` + `Execute` + `runRoot`
- [`cmd/{{NAME}}/commands/<subcmd>.go`](#cmdnamecommandssubcmdgo-flat-leaf) (flat leaf)
- [`cmd/{{NAME}}/commands/<parent>.go`](#cmdnamecommandsparentgo-parent-group--no-rune) (parent group)
- [`cmd/{{NAME}}/commands/<parent>_<child>.go`](#cmdnamecommandsparent_childgo-nested-leaf) (nested leaf)
- [`go.mod`](#gomod) + version policy

## `cmd/{{NAME}}/main.go`

`main.go` only handles signal wiring and process exit.

It builds the root context with `cmdsignals.NotifyContext`, which subscribes to `ExitSignals` (`SIGINT` / `SIGTERM`) and returns a `blockOn` func, the cancellable `ctx`, and a `cancel(error)`.

`blockOn` is what actually cancels `ctx` on a signal, so it runs in a goroutine via `sync.WaitGroup.Go` (Go 1.25+) for the duration of `Execute`; `cancel(nil)` + `wg.Wait()` then unwind it once `Execute` returns.

Do **not** revert to the stdlib `signal.NotifyContext` — the helper's variant is what enables `Pause` / `Resume` (see [Helper catalog](workflows.md)).

When a signal triggered the shutdown, `Execute` returns the bare `context.Canceled` sentinel; `main` recovers the real reason from `context.Cause(ctx)` as a `*cmdsignals.SignalReceivedError` (via `errors.AsType`, Go 1.26+) so the printed message names the signal instead of the opaque `context canceled`.

The guard is `errors.Is(err, ctx.Err())`, **not** the bare `context.Canceled` sentinel: `context.Canceled` is a public value any code may return without this context being cancelled, whereas `ctx.Err()` is non-nil only when _this_ ctx was genuinely cancelled.

It is checked **before** `cancel(nil)` — that cleanup call would otherwise set `ctx.Err()` itself and manufacture a false positive.

The error is otherwise written unconditionally to stderr because logging is opt-in via `--log` / `--log-level`.

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"

	"{{MODULE}}/cmd/{{NAME}}/commands"
	"{{MODULE}}/internal/cmdsignals"
)

func main() {
	blockOn, ctx, cancel := cmdsignals.NotifyContext(context.Background())

	var wg sync.WaitGroup
	wg.Go(blockOn)

	err := commands.Execute(ctx)

	// Check before cancel(nil) below — that call would set ctx.Err() and
	// manufacture a false positive.
	if err != nil && errors.Is(err, ctx.Err()) {
		if sigErr, ok := errors.AsType[*cmdsignals.SignalReceivedError](context.Cause(ctx)); ok {
			err = sigErr
		}
	}

	cancel(nil)
	wg.Wait()

	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
```

Emit `main.go` verbatim — do **not** add comments beyond the single `// Check before cancel(nil)` one.

- The prose above (goroutine lifetime, guard rationale, cause recovery) is documentation for **you**, the editing agent.
- Restating it as comments in the generated file is redundant noise; the one kept comment marks the only ordering constraint the code cannot show.

The template treats a signal as an error (prints it, exits non-zero).

That is just one policy: **callers may instead treat signal cancellation as a normal exit, per an application-specific decision** — e.g. a graceful shutdown where `SIGINT` / `SIGTERM` is the expected stop button.

In that case, in the `errors.AsType` branch where `sigErr` is recovered, return cleanly (print nothing, or a terse notice, and skip `os.Exit(1)`) rather than falling through to the error report; some tools additionally map the signal to the conventional `128 + signum` exit code (`sigErr.Sig`).

The recovery itself — `ctx.Err()` guard, cause via `context.Cause` — stays the same; only what `main` _does_ with `sigErr` changes.

## `cmd/{{NAME}}/commands/root.go`

Owns the root command and its `runRoot`.

The root wrapper delegates persistent log-flag registration to the `loggerfactory` helper and installs a `PersistentPreRun` hook that builds the logger and injects it into `cmd.Context()`.

There is **no** logger glue file under `commands/` — all of it lives in `{{MODULE}}/internal/loggerfactory`.

```go
package commands

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/ngicks/go-common/contextkey"
	"github.com/spf13/cobra"

	"{{MODULE}}/internal/loggerfactory"
)

func Execute(ctx context.Context) error {
	return rootCmd().ExecuteContext(ctx)
}

func rootCmd() *cobra.Command {
	var (
		logConfig   *loggerfactory.Config
		flagVersion bool
		flagConfig  string
	)

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
		RunE: func(cmd *cobra.Command, args []string) error {
			if flagVersion {
				return runVersion(cmd, args)
			}
			return runRoot(cmd, args)
		},
	}

	logConfig = loggerfactory.RegisterFlags(cmd)
	cmd.Flags().BoolVar(&flagVersion, "version", false, "alias for the version subcommand")
	cmd.PersistentFlags().StringVar(&flagConfig, "config", "", "config file path; overrides the default location")

	versionCmd(cmd)
	configCmd(cmd, &flagConfig)

	// TODO: declare additional root flags inside the `var (...)` block above
	// and bind them with `cmd.PersistentFlags().<Type>Var(&flag, ...)`. Extend
	// the RunE closure to forward captured values into runRoot.

	// TODO: wire additional subcommands here, passing &flagConfig to the ones
	// that load config, e.g.:
	//   serveCmd(cmd, &flagConfig)

	// TODO: you may add initialization logic for root internal service construct here.

	return cmd
}

func runRoot(cmd *cobra.Command, args []string) error {
	return cmd.Help()
}
```

The TODO comments are markers for the implementor — leave them.

The `versionCmd(cmd)` / `configCmd(cmd, &flagConfig)` calls, the `--version` flag, and the persistent `--config` flag are **not** TODOs; they are always-present wiring for the two mandatory subcommands — `version` (see [versioning.md](versioning.md)) and `config` (see [configuration.md](configuration.md)).

`--config` is persistent so every config-loading subcommand shares one flag; its value is threaded into those wrappers as `&flagConfig`.

The `loggerfactory` helper (see [Helper catalog](workflows.md)) owns logger config, the persistent log flags, the env-var override reader, and the `BuildLogger` constructor.

Logging is **opt-in** via two persistent flags declared with `pflag.BoolFunc` (presence enables, optional `=value` overrides the default):

- `--log[=text|json]` — enables logging; chooses format.

  Default format when `--log` is given without a value: `json`. Values are case-insensitive.

- `--log-level[=trace|debug|info|warn|error|fatal]` — enables logging; chooses level.

  Default level when `--log-level` is given without a value: `info`.

  Levels map to `slog.Level` values: `trace`=-8, `debug`=-4, `info`=0, `warn`=4, `error`=8, `fatal`=12. Values are case-insensitive.

The presence of either flag enables logging.

When both are absent (and no env-var override applies), the logger is `slog.DiscardHandler`.

`loggerfactory.RegisterFlags(cmd)` returns the logger-related `*Config` populated during flag parsing; `root.go` stores it and its `PersistentPreRun` first calls `loggerfactory.ReadEnv(logConfig, "{{NAME}}", os.Environ())` to layer env-var overrides on top of the parsed flag values, then calls `loggerfactory.BuildLogger(logConfig)` to construct the configured logger.

The env-var names are the helper's contract — `commands/` code passes the app name and the env slice and otherwise stays out of it.

## `cmd/{{NAME}}/commands/<subcmd>.go` (flat leaf)

```go
package commands

import "github.com/spf13/cobra"

func {{subCamel}}Cmd(parent *cobra.Command) {
	cmd := &cobra.Command{
		Use:   "{{sub-name}}",
		Short: "{{Sub short description}}",
		Args:  cobra.NoArgs,
		// TODO: set ValidArgsFunction to control positional-argument completion,
		// e.g. cobra.NoFileCompletions to disable the default file completion.
		RunE: run{{SubPascal}},
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
	// Per-call inputs go through the service method's <Method>Option struct.
	// Do not put business logic here.
	return nil
}
```

After scaffolding, add `{{subCamel}}Cmd(cmd)` to `rootCmd()` (or the enclosing parent's wrapper if nested).

## `cmd/{{NAME}}/commands/<parent>.go` (parent group — no `RunE`)

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

## `cmd/{{NAME}}/commands/<parent>_<child>.go` (nested leaf)

```go
package commands

import "github.com/spf13/cobra"

func {{parentCamel}}{{ChildPascal}}Cmd(parent *cobra.Command) {
	cmd := &cobra.Command{
		Use:   "{{child-name}}",
		Short: "{{Child short description}}",
		Args:  cobra.NoArgs,
		// TODO: set ValidArgsFunction to control positional-argument completion,
		// e.g. cobra.NoFileCompletions to disable the default file completion.
		RunE: run{{ParentPascal}}{{ChildPascal}},
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
	// Per-call inputs go through the service method's <Method>Option struct.
	// Do not put business logic here.
	return nil
}
```

Differences vs. flat:

- Parent group has no `RunE` / `Args`.
- Child file uses underscore between levels.
- Child wrapper concatenates: `serverStartCmd`.

A group may alternatively live as a `commands/<parent>/` subdirectory (its own package, exported `Cmd(parent)` boundary) — an allowed variant used only when the project already nests that way or the user asks. See [layout-and-naming.md › Subdirectory-nested subcommands](layout-and-naming.md#subdirectory-nested-subcommands-allowed-variant).
- Child is wired from the **parent group's wrapper**, not from `rootCmd()`. 3-level follows the same pattern (`server_start_foo.go` is wired from inside `serverStartCmd`).

## `go.mod`

```
module {{MODULE}}

go {{GO_VERSION}} // latest major with .0, e.g. 1.26.0

require (
	github.com/caarlos0/env/v11 v0.0.0            // env parsing; `go get github.com/caarlos0/env/v11@latest` — confirm /v11 is still the current major
	github.com/ngicks/go-common/contextkey v0.0.0 // resolved by `go get @latest`
	github.com/spf13/cobra v0.0.0                 // resolved by `go get @latest`
	// YAML-only or both-format projects only — omit for JSON-only:
	go.yaml.in/yaml/v4 v4.0.0-rc.5                // pinned: v4 is pre-release, so do NOT use @latest
)
```

Version policy:

- **Go version**: latest major with `.0` (e.g. `go 1.26.0`).

  User may override with an explicit version.

- **Direct dependencies**: latest possible.

  Workflow: `go get <module>@latest` for each direct dep, then `go mod tidy`. (Plain `tidy` does not bump already-required modules.)

- **Check the current major version before `go get …@latest`.** Go's `@latest` is scoped to the major version in the import path — it will **not** cross a major boundary.

  `go get github.com/caarlos0/env@latest` resolves to the ancient v0/v1, not `…/env/v11`; you must request the `/vN` path explicitly (`…/env/v11@latest`).

  Before adopting or bumping any module, check pkg.go.dev / the repo for the current highest major and use that `/vN` path. (This is also why a stale local module cache can leave you on an old major without warning.)

- **`caarlos0/env` (core dependency)**: every project uses it for env parsing — current major is `/v11` (verify before bumping, per the rule above).

- **YAML dependency**: add `go.yaml.in/yaml/v4` only for YAML-only / both-format projects (`go.yaml.in/yaml/v3` or `github.com/goccy/go-yaml` are equivalent swaps for the `yaml.Unmarshal` call).

  A JSON-only project needs no YAML dependency.

  **`v4` is pre-release** (`v4.0.0-rc.5` as of mid-2026), so the template **pins** it — `go get go.yaml.in/yaml/v4@v4.0.0-rc.5`, not `@latest` (and check for a newer rc / the GA tag before pinning).

  See [config-source.md](config-source.md) for the YAML support code.
