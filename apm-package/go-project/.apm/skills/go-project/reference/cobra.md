# Cobra design rules

The Cobra-specific rules for the CLI command tree.

Cobra (`spf13/cobra`) is this skill's default framework for a command with subcommands; these rules govern every file under `./cmd` and every `cobra.Command` literal.

Read this before touching anything under `./cmd` or any `cobra.Command`.

The "thin run function" rule is the Cobra-mechanics consequence of the broader "no business logic under `./cmd`" rule (SKILL.md › General design rules).

The rules are grouped below by what they govern: error handling, positional args, command construction, and file naming.

## Contents

- [Errors & the root command](#errors--the-root-command)
- [Positional arguments & completion](#positional-arguments--completion)
- [Wrappers, run functions & wiring](#wrappers-run-functions--wiring)
- [File naming in `commands/`](#file-naming-in-commands)
- [Canonical flag pattern](#canonical-flag-pattern)

## Errors & the root command

- **`RunE` only**, never `Run`.

  Return errors; do not `os.Exit` from a command body.

- **Root command**: `SilenceUsage: true`, `SilenceErrors: true`.

  Delegate to a named `runRoot`.

## Positional arguments & completion

- **Default `Args`**: `cobra.NoArgs`.

  **Change it** when positional arguments fit the command better — e.g. `cobra.ExactArgs(1)`, `cobra.MinimumNArgs(1)`, `cobra.MaximumNArgs(2)`, `cobra.RangeArgs(1, 3)`, `cobra.MatchAll(cobra.ExactArgs(1), customValidator)`.

  Treat positional args as the natural shape when the command operates on a target (`mytool inspect <path>`, `mytool delete <id>...`); flags are for options on top of that target.

  The templates set `cobra.NoArgs` as a safe placeholder, not a recommendation.

- **Positional-argument completion (`ValidArgsFunction`)**: fill `ValidArgsFunction` on a leaf command's literal to control shell completion of its positional args.

  The stub leaf templates ship this as a TODO — fill it to match `Args`.

  When the command takes no completable positional args (the `cobra.NoArgs` default), set `cobra.NoFileCompletions` so the shell does not fall back to file completion.

  When it does take them, assign a dynamic completion function, a static `ValidArgs` slice, or `cobra.FixedCompletions(...)`.

  `ValidArgs` and `ValidArgsFunction` are mutually exclusive — set at most one (Cobra reports an error when both are present).

## Wrappers, run functions & wiring

- **One wrapper function per command.** Every Cobra construction lives inside an unexported `func {{name}}Cmd(parent *cobra.Command)`.

  The function builds the `cobra.Command` literal, declares flag variables in a local `var (...)` block, binds them via `cmd.Flags().<Type>Var(...)`, calls children's wrapper functions on the new `cmd`, and ends with `parent.AddCommand(cmd)`.

  There are **no package-level `*Cmd` variables** and **no `init()` functions** for wiring.

  (In the [subdirectory-nested variant](layout-and-naming.md#subdirectory-nested-subcommands-allowed-variant), the one wrapper crossing the package boundary is exported — canonically the group's `Cmd(parent *cobra.Command)`; everything else stays unexported.)

- **Every `cobra.Command` field is set inline in the composite literal.** The literal the wrapper builds is the only place command fields are set.

  - No post-construction field assignment — `cmd.Short = ...`, `cmd.Args = ...` are forbidden.
  - No hoisting a non-function field's value into a variable or constant just to name it — write it in place (`Use: "serve"`, `Args: cobra.NoArgs`, `SilenceUsage: true`).
  - **Exception: function-typed fields** (`RunE`, the `*Run`/`*RunE` hooks, `ValidArgsFunction`). They are still *set* inside the literal, but their values follow their own rules — `RunE` per the rule below, hooks and completion per [workflows.md](workflows.md) — so they may reference named package-level functions instead of spelling the body in place.

- **Root is the special case.** `func rootCmd() *cobra.Command` (no `parent`).

  It returns the configured root and is invoked from `Execute(ctx)`.

  All top-level subcommands are wired by `rootCmd()` calling each subcommand's wrapper function.

- **Group parents**: no `RunE`, no `Args` by default.

  They MAY own persistent flags, aliases, or pre-run hooks when intentional.

  When a persistent flag must reach a child's run function, declare the flag's `var` in the parent wrapper and pass its address as an extra parameter to the child wrapper (`{{child}}Cmd(cmd, &flagShared)`).

- **Parent→child flag threading is an unexported internal detail.** The flag `var`s, the child wrappers, and any bundling struct all stay unexported inside the `commands` package, so the threading shape is free to change as the shared-flag count changes — switching forms is a local refactor, never an API change. Pick by size:

  - **Default (up to ~3 shared flags): individual pointer arguments** — `{{child}}Cmd(cmd, &flagConfig)`.
    Each child receives only the flags it actually consumes; the wrapper signature documents the dependency.
  - **Escalation (more than ~3, or two same-typed pointers traveling together): one unexported struct** declared in the parent's file (e.g. `type serveFlags struct { host string; port int }`), passed as `{{child}}Cmd(cmd, &shared)`.
    Named fields remove the swapped-same-type-argument hazard.
  - Reaching the threshold is a smell: before bundling, check whether those values belong in the service's `PartialConfig` (file/env layers) rather than flags at all.
  - **Never** have a child re-read a parent's flag via `cmd.InheritedFlags().Get*` / `cmd.Flags().Get*` — stringly-typed lookups compile fine and break silently on flag renames.

- **Run functions are named** (`run{{Name}}`) and live at package level.

  **Run functions are thin wiring**: read positional args, call a service, return its error.

  Business logic is forbidden under `./cmd`.

- **`RunE` is either a direct reference (`RunE: run{{Name}}`) or a thin closure adapter** that forwards captured flag values: `RunE: func(cmd *cobra.Command, args []string) error { return run{{Name}}(cmd, args, flagFoo, flagBar) }`.

  The closure body must contain only that single forwarding call — no logic.

## File naming in `commands/`

- **Non-subcommand files inside `commands/` MUST be prefixed with `zz_`** (e.g. `zz_helpers.go`, `zz_validation.go`).

  Files without the `zz_` prefix are reserved for the canonical subcommand mapping (`<name>.go` for flat leaves and group parents, `<parent>_<child>.go` for nested leaves).

  The `zz_` prefix marks shared helpers and any other package-level code that is not a single subcommand definition.

  (A leading single `_` cannot be used: `cmd/go` ignores any file whose name starts with `_` or `.`. The `zz_` form is Go-compatible and sorts last in directory listings, mirroring the `zz_generated_*.go` convention.)

- **A leaf file name must not end in an implicit build-constraint suffix.** Go reads a `GOOS` / `GOARCH` / `test` build constraint off the **trailing** `_`-segment(s) of a file name, so a nested-leaf file like `foo_windows.go`, `db_linux_amd64.go`, or `db_test.go` silently compiles on one platform only (or is treated as a test file) and the subcommand disappears from other builds.

  Fix it by `zz`-prefixing the offending **trailing** segment in the file name only — `foo_windows.go` → `foo_zzwindows.go` — while the command's `Use:`, wrapper, and run function keep the real leaf name. Flat single-segment leaves (`windows.go`) and GOOS-named parents (`windows_sub.go`) are already safe and must not be mangled. Full rule: [layout-and-naming.md › Build-constraint suffix collisions](layout-and-naming.md#build-constraint-suffix-collisions-in-leaf-file-names).

## Canonical flag pattern

Inside the wrapper function, declare every flag as a local in a single `var (...)` block at the top, then bind it with the `*Var` family (`StringVar`, `IntVar`, `BoolVarP`, ...) — **never** the pointer-returning form (`String`, `Int`, ...).

This keeps the binding API uniform with `BoolFunc` (which never returns a pointer) and concentrates storage declarations in one block.

```go
func serveCmd(parent *cobra.Command) {
	var (
		flagHost string
		flagPort int
	)

	cmd := &cobra.Command{
		Use:   "serve",
		Short: "run the HTTP server",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runServe(cmd, args, flagHost, flagPort)
		},
	}

	cmd.Flags().StringVar(&flagHost, "host", "0.0.0.0", "listen host")
	cmd.Flags().IntVar(&flagPort, "port", 8080, "listen port")

	parent.AddCommand(cmd)
}

func runServe(cmd *cobra.Command, args []string, host string, port int) error {
	// ...
}
```

Exception: when a flag must bind into an external configuration struct, pass the struct field's address to `*Var`. The local `var` form is the default.

**Caveat:** the service's layered `Config` (see [Service package & configuration](configuration.md)) is **not** such a struct — do not bind flags into it with `&cfg.Field`, or a flag's default value will clobber the file/env layers.

Bind those to locals and overlay only the explicitly-set ones via `cmd.Flags().Changed(...)`.
