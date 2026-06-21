---
name: go-edit-cobra
description: "Use when authoring or editing a Go CLI built on spf13/cobra. Auto-triggers on any edit/create under ./cmd, plus phrases: 'scaffold cli', 'create go command', 'add subcommand', 'rename subcommand', 'remove subcommand', 'add flag to <cmd>', 'move <cmd> under <cmd>', 'edit cmd/'."
---

# Cobra CLI authoring

Scaffold a new Cobra CLI, edit an existing one, or apply Cobra-specific design rules.

Cobra-only — see [Out of scope](#out-of-scope) for non-Cobra layouts.

This page holds the always-applied core: pre-flight checks, the Cobra design rules, and the post-edit validation chain.

Everything else — layout, templates, the configuration model, versioning, and the scaffold/edit procedures — lives in the reference files below; read the one a task needs.

## Reference files

- **[reference/layout-and-naming.md](reference/layout-and-naming.md)** — canonical project layout, naming conventions (files / wrappers / run functions / package name), and the anti-patterns list.

  Read before deciding where a file goes or how to name it.
- **[reference/command-templates.md](reference/command-templates.md)** — the command-tree code templates: `main.go`, `root.go`, flat-leaf / parent-group / nested-leaf subcommands, and `go.mod` + version policy.
- **[reference/configuration.md](reference/configuration.md)** — the configuration model (layers, `PartialConfig.Apply` merge semantics, file format, path resolution, flag overlay, add-a-field) and the `config` subcommand (three-file split: `cmd` wiring + `pkg/<name>/cli` rendering + `internal/templateutil` funcs).
- **[reference/config-source.md](reference/config-source.md)** — the `pkg/<name>/config.go` source template (JSON base) plus the YAML-only / both-format support block.
- **[reference/versioning.md](reference/versioning.md)** — the four versioning pieces, the release-tool flow, submodule tags, and the `version.go` / `versioninfo` / `release` source.
- **[reference/workflows.md](reference/workflows.md)** — step-by-step scaffold and edit procedures (subcommand / flag / metadata / completion operations) and the helper-package catalog.

## Pre-flight checks

Run before any edit.

1. **Mode detection.** Inspect `<root>/cmd/`.
   - **Missing or empty** → **Scaffold mode**. Skip the remaining checks; jump to [Scaffold a new project](reference/workflows.md#scaffold-a-new-project).
   - **Populated** → **Edit mode**; continue.
2. **Cobra detection** (edit mode only). Look for `github.com/spf13/cobra` in `go.mod` or any import.
   - Absent → out of scope; report and stop.
3. **Layout classification** (edit mode only). Categorize the project:
   - **Canonical** — `<root>/cmd/<name>/main.go` + `<root>/cmd/<name>/commands/` + `<root>/internal/cmdsignals/` exist. → Proceed.
   - **Close variant** — `cmd/<name>/main.go` + `cmd/<name>/commands/` exist but the helper packages sit elsewhere (e.g. under an older `cmd/internal/` tree, or `cmdsignals` not yet present). → Proceed; do not force-migrate existing files.
   - **Non-canonical Cobra** — e.g. `cmd/root.go` at module root, or `cobra-cli` defaults. → **Stop and ask.** Likely mid-migration or accidental drift.

## Cobra design rules

These rules are Cobra-specific.

The "thin run function" rule is the Cobra-mechanics consequence of the broader "no business logic under `./cmd`" rule.

They are grouped below by what they govern: error handling, positional args, command construction, and file naming.

### Errors & the root command

- **`RunE` only**, never `Run`.

  Return errors; do not `os.Exit` from a command body.

- **Root command**: `SilenceUsage: true`, `SilenceErrors: true`.

  Delegate to a named `runRoot`.

### Positional arguments & completion

- **Default `Args`**: `cobra.NoArgs`.

  **Change it** when positional arguments fit the command better — e.g. `cobra.ExactArgs(1)`, `cobra.MinimumNArgs(1)`, `cobra.MaximumNArgs(2)`, `cobra.RangeArgs(1, 3)`, `cobra.MatchAll(cobra.ExactArgs(1), customValidator)`.

  Treat positional args as the natural shape when the command operates on a target (`mytool inspect <path>`, `mytool delete <id>...`); flags are for options on top of that target.

  The templates set `cobra.NoArgs` as a safe placeholder, not a recommendation.

- **Positional-argument completion (`ValidArgsFunction`)**: fill `ValidArgsFunction` on a leaf command's literal to control shell completion of its positional args.

  The stub leaf templates ship this as a TODO — fill it to match `Args`.

  When the command takes no completable positional args (the `cobra.NoArgs` default), set `cobra.NoFileCompletions` so the shell does not fall back to file completion.

  When it does take them, assign a dynamic completion function, a static `ValidArgs` slice, or `cobra.FixedCompletions(...)`.

  `ValidArgs` and `ValidArgsFunction` are mutually exclusive — set at most one (Cobra reports an error when both are present).

### Wrappers, run functions & wiring

- **One wrapper function per command.** Every Cobra construction lives inside an unexported `func {{name}}Cmd(parent *cobra.Command)`.

  The function builds the `cobra.Command` literal, declares flag variables in a local `var (...)` block, binds them via `cmd.Flags().<Type>Var(...)`, calls children's wrapper functions on the new `cmd`, and ends with `parent.AddCommand(cmd)`.

  There are **no package-level `*Cmd` variables** and **no `init()` functions** for wiring.

- **Root is the special case.** `func rootCmd() *cobra.Command` (no `parent`).

  It returns the configured root and is invoked from `Execute(ctx)`.

  All top-level subcommands are wired by `rootCmd()` calling each subcommand's wrapper function.

- **Group parents**: no `RunE`, no `Args` by default.

  They MAY own persistent flags, aliases, or pre-run hooks when intentional.

  When a persistent flag must reach a child's run function, declare the flag's `var` in the parent wrapper and pass its address as an extra parameter to the child wrapper (`{{child}}Cmd(cmd, &flagShared)`).

- **Run functions are named** (`run{{Name}}`) and live at package level.

  **Run functions are thin wiring**: read positional args, call a service, return its error.

  Business logic is forbidden under `./cmd`.

- **`RunE` is either a direct reference (`RunE: run{{Name}}`) or a thin closure adapter** that forwards captured flag values: `RunE: func(cmd *cobra.Command, args []string) error { return run{{Name}}(cmd, args, flagFoo, flagBar) }`.

  The closure body must contain only that single forwarding call — no logic.

### File naming in `commands/`

- **Non-subcommand files inside `commands/` MUST be prefixed with `zz_`** (e.g. `zz_helpers.go`, `zz_validation.go`).

  Files without the `zz_` prefix are reserved for the canonical subcommand mapping (`<name>.go` for flat leaves and group parents, `<parent>_<child>.go` for nested leaves).

  The `zz_` prefix marks shared helpers and any other package-level code that is not a single subcommand definition.

  (A leading single `_` cannot be used: `cmd/go` ignores any file whose name starts with `_` or `.`. The `zz_` form is Go-compatible and sorts last in directory listings, mirroring the `zz_generated_*.go` convention.)

- **A leaf file name must not end in an implicit build-constraint suffix.** Go reads a `GOOS` / `GOARCH` / `test` build constraint off the **trailing** `_`-segment(s) of a file name, so a nested-leaf file like `foo_windows.go`, `db_linux_amd64.go`, or `db_test.go` silently compiles on one platform only (or is treated as a test file) and the subcommand disappears from other builds.

  Fix it by `zz`-prefixing the offending **trailing** segment in the file name only — `foo_windows.go` → `foo_zzwindows.go` — while the command's `Use:`, wrapper, and run function keep the real leaf name. Flat single-segment leaves (`windows.go`) and GOOS-named parents (`windows_sub.go`) are already safe and must not be mangled. Full rule: [layout-and-naming.md › Build-constraint suffix collisions](reference/layout-and-naming.md#build-constraint-suffix-collisions-in-leaf-file-names).

### Canonical flag pattern

Inside the wrapper function, declare every flag as a local in a single `var (...)` block at the top, then bind it with the `*Var` family (`StringVar`, `IntVar`, `BoolVarP`, ...) — **never** the pointer-returning form (`String`, `Int`, ...).

This keeps the binding API uniform with `BoolFunc` (which never returns a pointer) and concentrates storage declarations in one block.

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

**Caveat:** the service's layered `Config` (see [Service package & configuration](reference/configuration.md)) is **not** such a struct — do not bind flags into it with `&cfg.Field`, or a flag's default value will clobber the file/env layers.

Bind those to locals and overlay only the explicitly-set ones via `cmd.Flags().Changed(...)`.

## Post-edit validation

Run after **every** edit and after scaffolding, in this order:

1. `go mod tidy` — only when imports / dependencies changed.
2. **Format the changed files.**

   If the project has a golangci-lint config (`.golangci.{yaml,yml,toml,json}`) with a `formatters.enable` block, run `golangci-lint fmt <changed_files>` — this applies the project's configured formatters (e.g. `goimports`, `golines`) in their configured order.

   Otherwise, run `goimports -w <changed_files>`.

   If `goimports` is missing, fall back to `gofmt -w` and report the missing tool to the user — do not install it.
3. `go vet ./...` — full module.

   The wrapper-function chain crosses package boundaries on `parent.AddCommand`, so package-scoped vet is unsafe.
4. `go test ./...` — full module.

Edits in this skill are best-effort textual changes.

The validation chain (vet + test) is the safety net for rename / move operations that touch identifiers across many files.

## Out of scope

- Migrating non-canonical projects to the canonical layout (skill detects + asks; user drives migration).
- Frameworks other than `spf13/cobra`.
- `cobra-cli` code generation.
- AST-based rewriting (`go/ast`, `dst`); plain `Edit` / `Write` only.
