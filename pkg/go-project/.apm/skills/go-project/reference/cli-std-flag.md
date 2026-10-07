# Std `flag` CLI rules

The std-`flag` shape for a **single-command** CLI: one binary, flags, positional args, no subcommand tree.

The framework-neutral rules in [cli.md](cli.md) apply on top of everything here.

When the tool later grows subcommands, the default is migrating to Cobra ([cli-cobra.md](cli-cobra.md)); staying on `flag` (or hand-rolling dispatch) is an explicit decision to record in `.go-project-decision.md` (SKILL.md › Decision record).

## Contents

- [Layout](#layout)
- [The run pattern](#the-run-pattern)
- [Flags](#flags)
- [Config overlay without `Changed`](#config-overlay-without-changed)
- [Version & logging](#version--logging)
- [Scaffold deltas](#scaffold-deltas)

## Layout

- `cmd/<name>/main.go` is the whole wiring layer — there is **no** `commands/` package.

  `run` and its helpers may split into sibling files of `package main` when `main.go` grows.
- Everything non-CLI is unchanged: service package at top-level `<name-without-separator>/`, layered configuration, `internal/libver` versioning, user dirs, and the helper packages all apply exactly as in a Cobra project.

## The run pattern

`main` keeps the same signal wiring as the Cobra template ([command-templates.md › main.go](command-templates.md#cmdnamemaingo)) — `cmdsignals.NotifyContext`, `wg.Go(n.Run)`, the `ctx.Err()` guard, signal-cause recovery, the single `os.Exit(1)` site.

Only the call in the middle changes: `commands.Execute(ctx)` becomes `run(ctx, os.Args)`.

- `run(ctx context.Context, args []string) error` owns flag parsing and service invocation; it returns errors, never exits.
- Use an explicit `flag.NewFlagSet(name, flag.ContinueOnError)` — never the global `flag.CommandLine`, whose `ExitOnError` mode would bypass `main`'s error path and skip defers.
- `-h` / `-help` surfaces as `flag.ErrHelp` from `fs.Parse`; treat it as a clean exit.

```go
func run(ctx context.Context, args []string) error {
	var (
		flagConfig  string
		flagVersion bool
	)

	fs := flag.NewFlagSet("{{NAME}}", flag.ContinueOnError)
	fs.StringVar(&flagConfig, "config", "", "path to config file")
	fs.BoolVar(&flagVersion, "version", false, "print version information and exit")

	if err := fs.Parse(args[1:]); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			return nil
		}
		return err
	}

	if flagVersion {
		return printVersion(os.Stdout)
	}

	cfg, err := {{NAME}}.LoadConfig(flagConfig)
	if err != nil {
		return err
	}
	// overlay explicitly-set flags onto cfg (see below),
	// construct the service from cfg, then run it with ctx.
	return nil
}
```

## Flags

The [canonical flag pattern](cli-cobra.md#canonical-flag-pattern) translates directly:

- Declare every flag as a local in a single `var (...)` block at the top of `run`, then bind with the `*Var` family (`fs.StringVar`, `fs.IntVar`, `fs.BoolVar`, `fs.BoolFunc`, ...) — **never** the pointer-returning form (`fs.String`, `fs.Int`, ...).
- Positional args are `fs.Args()` after parsing.

  Std `flag` has no `cobra.ExactArgs`-style validators — check the count explicitly (`if len(fs.Args()) != 1 { return fmt.Errorf("expected exactly one <path> argument, got %d", len(fs.Args())) }`).
- Std `flag` stops parsing at the first non-flag argument — flags must precede positionals. Note it in the usage text when the tool takes both.

## Config overlay without `Changed`

The [flag overlay rule](configuration.md#flag-overlay-the-flags-win-step-in-cmd) still applies: never bind service-config flags into `Config` directly.

Std `flag` has no `Changed(name)`; the set-vs-unset probe is `fs.Visit`, which visits **only** flags actually set on the command line:

```go
fs.Visit(func(f *flag.Flag) {
	switch f.Name {
	case "addr":
		cfg.Addr = flagAddr
	case "port":
		cfg.Port = flagPort
	}
})
```

An explicit `-port 0` set by the user wins regardless, mirroring `PartialConfig`'s present-semantics.

## Version & logging

- **`-version` flag replaces the `version` subcommand.** Print the same fields as [versioning.md › version.go](versioning.md#cmdnamecommandsversiongo-always-present)'s `runVersion` (`versioninfo.ReadVersionInfo(libver.Version)`; version / commit / commit time / go version), writing to stdout.
- **`loggerfactory.RegisterFlags` is Cobra-only** (it takes a `*cobra.Command`); do not import it into flag binding.

  Bind the two flags manually — `fs.BoolFunc("log", ...)` and `fs.BoolFunc("log-level", ...)` populating a `loggerfactory.Config{Format: "json", Level: slog.LevelInfo}`, mirroring the `RegisterFlags` callbacks in `${SKILL-DIR}/helpers/internal/loggerfactory/loggerfactory.go` — then use `ReadEnv` and `BuildLogger` as usual. (In a scaffolded std-`flag` project the copied helper has `RegisterFlags` removed — see [Scaffold deltas](#scaffold-deltas).)
- **The `config` subcommand is a command-tree feature; skip it.** Add a config-rendering flag only when the user asks; render through `<name-without-separator>/cli` just like the Cobra shape.

## Scaffold deltas

Follow [workflows.md › Scaffold a new project](workflows.md#scaffold-a-new-project) with these substitutions:

- Skip the `commands/` steps entirely: no `root.go`, no `version.go`, no `config` subcommand files.
- Write `cmd/<name>/main.go` from the Cobra template's `main.go` with `run(ctx, os.Args)` in place of `commands.Execute(ctx)`, plus the `run` pattern above (same file or a sibling `package main` file).
- `go.mod` per [command-templates.md › go.mod](command-templates.md#gomod) **minus** `github.com/spf13/cobra`.
- Helper copying is unchanged (`copy_helper.sh <root> --cmdsignals-full`), with one post-copy edit: in the copied `internal/loggerfactory/loggerfactory.go`, delete the `RegisterFlags` function and the `github.com/spf13/cobra` import (its only user) — otherwise `go mod tidy` drags Cobra back in. The manual `fs.BoolFunc` binding above replaces it; `loggerfactory_test.go` doesn't reference it, and the other helpers don't import Cobra.
- The service package, `config.go`, and validation steps are identical.
