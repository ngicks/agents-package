# Workflows & helper catalog

Step-by-step procedures for scaffolding a new project and editing an existing one, plus the catalog of bundled helper packages.

The templates these steps reference live in [command-templates.md](command-templates.md), [configuration.md](configuration.md), [config-source.md](config-source.md), and [versioning.md](versioning.md).

## Contents

- [Scaffold a new project](#scaffold-a-new-project)
- [Edit an existing project](#edit-an-existing-project) — subcommand structure, flags, metadata, completion
- [Helper catalog](#helper-catalog) — library packages, build-time `main` packages, templates

## Scaffold a new project

Interview (extract from user message inline; only ask for missing required fields):

| Parameter          | Required | Default                    | Example                    |
| ------------------ | -------- | -------------------------- | -------------------------- |
| Project name       | yes      | -                          | `mytool`                   |
| Module root        | yes      | -                          | `tools/mytool`             |
| Go module path     | no       | `github.com/watage/<name>` | `github.com/watage/mytool` |
| Short description  | no       | `<name> CLI tool.`         | `My awesome tool.`         |
| Subcommands        | no       | _(none)_                   | `serve`, `migrate`         |
| Config file format | no       | `json`                     | `json` / `yaml` / `both`   |

Subcommands accept dot notation (`server.start`) or natural language ("a server group containing start and stop").

Dotted = parent group + child leaf.

Generation steps (relative to module root):

1. Resolve all parameters.

   **Derive the `<name-without-separator>` package name now**: strip hyphens/underscores from the project name so the top-level service directory follows Go convention, as the placeholder's spelling stresses (`my-tool` → `mytool/`, `package mytool`) — see [Naming conventions › Package name](layout-and-naming.md#package-name-name-without-separator).

   `cmd/<name>/`, `Use:`, the env prefix, and the config-dir path keep the verbatim project name; only the top-level `<name-without-separator>/` directory, the `package` clause, and `{{MODULE}}/<name-without-separator>` imports use the stripped form.

   When the project name is already a valid identifier they are identical.

   The scaffold's binary carries the project's name and is its **main** functionality by definition, so its service package goes top-level without asking. Do **not** scaffold an `api/` directory — it is created only when the user asks for a public RPC API (see [layout-and-naming.md › Public RPC API](layout-and-naming.md#public-rpc-api-api)).
2. Write `go.mod` (placeholder `v0.0.0` lines per the [template](command-templates.md#gomod), except the pinned `go.yaml.in/yaml/v4 v4.0.0-rc.5`).
3. Write `cmd/<name>/main.go` ([template](command-templates.md#cmdnamemaingo)).
4. Write `cmd/<name>/commands/root.go` ([template](command-templates.md#cmdnamecommandsrootgo) already wires `versionCmd(cmd)` and the `--version` flag — leave that in place).
5. Write `<name-without-separator>/config.go` ([template](config-source.md)).

   Fill in the real `Config` fields + `DefaultConfig`, the mirrored `PartialConfig` + `Apply` (one overlay line per field, by kind — scalar / nested / map / slice), and `LoadConfig` (env layer via caarlos0/env's `ParseWithOptions` + the package-level `envOptions`).

   Give every field `json:`, `yaml:`, and `env:` (or `envPrefix:` for a nested sub-config) tags.

   For the chosen **config file format**: JSON-only uses the template as-is; for `yaml`/`both`, apply the [YAML support block](config-source.md#yaml-support-yaml-only-or-both-formats) (format-aware `unmarshalConfigFile`/`configPath` + the `go.yaml.in/yaml/v4` dep).

   Keep it one file.
6. Write `cmd/<name>/commands/version.go` ([template](versioning.md#cmdnamecommandsversiongo-always-present)).
7. Write the `config` subcommand — three files ([templates](configuration.md#cmdnamecommandsconfiggo-always-present)):

   - `internal/templateutil/templateutil.go` — the shared `FuncMap` (`json` baseline) + `FuncDocs` / `FuncHelp`, plus its sync test.
   - `<name-without-separator>/cli/config.go` — `RenderConfig` (JSON / `--format`) + `TemplateFuncHelp`.
   - `cmd/<name>/commands/config.go` — thin wiring; hand-write the `configLongFmt` field tree to match the real `Config`.

   The root template already declares the persistent `--config` flag and wires `configCmd(cmd, &flagConfig)` beside `versionCmd(cmd)` — leave that in place.

8. Write one `cmd/<name>/commands/<subcmd>.go` per flat leaf.

   Then edit `root.go` to call `{{subCamel}}Cmd(cmd)` inside `rootCmd()` for each.

9. For nested commands, write the parent **before** child files.

    Wire the parent into `rootCmd()`.

    Then write children and add `{{parentCamel}}{{ChildPascal}}Cmd(cmd)` calls inside the parent's wrapper function.

    Flat underscore-joined files are the default. Generate a group as a `commands/<parent>/` subdirectory instead only when the user asks for directories — or when re-scaffolding a project whose previous layout used them (the structure preference must survive). Shape and naming: [layout-and-naming.md › Subdirectory-nested subcommands](layout-and-naming.md#subdirectory-nested-subcommands-allowed-variant).

10. Copy the verbatim helper packages into `<root>` by running `"${SKILL-DIR}/copy_helper.sh" <root> --cmdsignals-full` (scaffolding always passes `--cmdsignals-full` — `main.go` calls `cmdsignals.NotifyContext`).

    This copies the `libver`, `loggerfactory`, and `versioninfo` packages — each package's source **and** tests — plus the full `cmdsignals` package to their mirrored paths under `<root>`.

    Without `--cmdsignals-full`, `cmdsignals` contributes only `signals.go` (the project-owned `ExitSignals` set); the `NotifyContext` wiring in `notify.go` + tests stays out. Use the default form when a project only wants the preconfigured signal set.

    `internal/libver/libver.go` arrives with the initial `Version` value `v0.0.0-devel` — nothing to fill in. Releases run the **external** `bump-libver` tool (`go run github.com/ngicks/go-common/tools/bump-libver@latest`), which reads that fixed path; no release code is generated into the project.

11. For each direct dep in `go.mod`: `go get <module>@latest` — using the correct `/vN` major path (e.g. `github.com/caarlos0/env/v11@latest`; confirm the current major first, see [Version policy](command-templates.md#gomod)).

    Exception: pin pre-release YAML with `go get go.yaml.in/yaml/v4@v4.0.0-rc.5` (or omit entirely for a JSON-only project).
12. `go mod tidy`.
13. Run the post-edit validation chain (see SKILL.md › Post-edit validation).
14. Report the generated file list to the user.

Use **Write** for every file.

Write creates parent directories — do not run `mkdir` separately.

## Edit an existing project

Pre-flight checks first (Cobra detection, layout classification — see SKILL.md › Pre-flight checks).

Then pick the operation; each entry below lists what to touch.

### New entry point (second binary)

Adding `cmd/<other>/` reuses the scaffold templates for the wiring layer, but the service package's placement depends on what the binary **is** — see [layout-and-naming.md › Main vs utility entry points](layout-and-naming.md#main-vs-utility-entry-points):

- **Main functionality** → top-level `./<other-without-separator>/` (a peer of `./<name-without-separator>/`, part of the module's public API).
- **Utility** (debug console, importer, admin helper, ...) → service code under `internal/` (e.g. `internal/<other-without-separator>/`), never top-level.

**Ask the user which it is** before writing the service package, unless the request already says so. In a legacy-layout project, a main-functionality package follows the existing `pkg/` placement instead of the top level.

### Subcommand structure

The table below is written for the flat layout. When the target group lives as a `commands/<parent>/` subdirectory (the [subdirectory variant](layout-and-naming.md#subdirectory-nested-subcommands-allowed-variant)), apply the same operations inside that directory with the subpackage naming — child file `<child>.go`, unexported wrapper `{{childCamel}}Cmd`, run function `run{{ChildPascal}}`, wiring inside the group's exported `Cmd` — and mirror the project's existing export pattern.

Preserve the existing shape: never flatten a directory-shaped group or split a flat one into directories unless the user explicitly asks.

| Operation                           | Files / actions                                                                                                                                                                                                          | Ask the user when                                                                                                                     |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Add flat subcommand                 | new `commands/<subcmd>.go` (flat-leaf template); add `{{subCamel}}Cmd(cmd)` call inside `rootCmd()` in `commands/root.go`                                                                                                | Name starts with `co` → [Completion › built-in `completion` prefix collision](#completion)                                            |
| Add nested subcommand               | new `commands/<parent>_<child>.go`; add `{{parentCamel}}{{ChildPascal}}Cmd(cmd)` call inside the parent's wrapper. If parent missing, also write `commands/<parent>.go` and add `{{parentCamel}}Cmd(cmd)` to `rootCmd()` | A newly created root-level parent's name starts with `co` → [Completion › built-in `completion` prefix collision](#completion)        |
| Rename subcommand                   | rename file; rename wrapper `{{old}}Cmd` → `{{new}}Cmd`; rename `run{{Old}}` → `run{{New}}`; update the wiring call in the parent wrapper. Search for any external reference (tests, docs, completion)                   | New root-level name starts with `co` → [Completion › built-in `completion` prefix collision](#completion)                             |
| Remove leaf                         | delete file; remove its wiring call from the parent wrapper                                                                                                                                                              | —                                                                                                                                     |
| Remove group                        | delete file + all children; remove the group's wiring call from `rootCmd()`                                                                                                                                              | If children exist (cascade vs refuse)                                                                                                 |
| Promote leaf → group                | drop `RunE` from leaf cmd literal; split logic into a new child file; add the new child's wiring call inside the (now-promoted) wrapper                                                                                  | Where original `RunE` body, `Args`, `Aliases`, `Example`, `PreRunE`, `PostRunE`, and flags go (parent persistent / new child / split) |
| Demote group → leaf                 | inline child wiring into parent wrapper; give the cmd a `RunE`                                                                                                                                                           | If children exist (merge / refuse)                                                                                                   |
| Move leaf under different parent    | rename file (`<old-parent>_<name>.go` → `<new-parent>_<name>.go`); rename wrapper and run func; remove the wiring call from the old parent wrapper and add it to the new one                                             | If new parent missing                                                                                                                 |
| Move subtree under different parent | rename every descendant file / wrapper / run func; move every affected wiring call to the appropriate parent wrapper                                                                                                     | If new parent missing                                                                                                                 |

When any of these adds, renames, or moves a nested-leaf file, check its **trailing** segment: if the leaf name is a GOOS / GOARCH / `test` token (`foo_windows.go`, `db_linux_amd64.go`, `db_test.go`) the file picks up an implicit build constraint and the command silently drops out of other-platform builds. `zz`-prefix the offending trailing segment in the file name only — `foo_windows.go` → `foo_zzwindows.go` — keeping the wrapper / run-func / `Use:` names intact. See [layout-and-naming.md › Build-constraint suffix collisions](layout-and-naming.md#build-constraint-suffix-collisions-in-leaf-file-names).

### Flag

| Operation                               | Files / actions                                                                                                                                                                                                                                                                               |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Add                                     | extend the local `var (...)` block in the target wrapper; bind via `cmd.Flags().<Type>Var(&flag, ...)` or `cmd.PersistentFlags().<Type>Var(...)`; if `run{{Name}}` consumes it, switch `RunE` to a closure adapter and add the parameter to `run{{Name}}`                                     |
| Remove                                  | drop from the `var` block; remove the binding call; remove the parameter from `run{{Name}}` and update the closure adapter (revert to direct reference if no flags remain)                                                                                                                    |
| Rename                                  | flag-name string + Go identifier in `var` block; binding call; closure adapter (if any); `run{{Name}}` parameter. Check `Flags().Lookup`, `Flag(name)`, `LocalFlags()`, `InheritedFlags()`, `BindPFlag`/Viper bindings, env-var names, `RegisterFlagCompletionFunc`, tests, READMEs, examples |
| Change type                             | update the `var` declaration; switch the binding to the corresponding `<Type>Var`; update the `run{{Name}}` parameter type                                                                                                                                                                    |
| Change default / shorthand / usage text | update the binding call arguments                                                                                                                                                                                                                                                             |
| Move scope (persistent ↔ local)         | move both the `var` declaration and the binding call to the appropriate command's wrapper, and use `Flags()` vs `PersistentFlags()`. When a parent's persistent flag must reach a child's run func, pass `&flag` as an extra parameter to the child wrapper                                   |
| Mark required / hidden / deprecated     | call `cmd.MarkFlagRequired(name)` / `cmd.Flags().MarkHidden(name)` / `cmd.Flags().MarkDeprecated(name, "msg")` inside the wrapper, after binding the flag                                                                                                                                     |

### Command metadata

`Use`, `Short`, `Long`, `Example`, `Aliases`, `Annotations`, `SuggestFor`, `Hidden`, `Deprecated` — edit the `cobra.Command` literal inside the wrapper.

`PreRunE`, `PostRunE`, `PersistentPreRunE`, `PersistentPostRunE` — set on the `cobra.Command` literal; assign a named function (`preRun{{Name}}`, `postRun{{Name}}`) defined in the same file.

Use a closure adapter to forward captured flag values when needed, mirroring the `RunE` rule.

### Completion

- **Positional-argument completion**: set `ValidArgsFunction` (dynamic), `ValidArgs` (static slice), or `cobra.FixedCompletions(...)` on the `cobra.Command` literal inside the wrapper.

  The stub leaf templates leave this as a TODO — fill it to match the command's `Args`: use `cobra.NoFileCompletions` when the command takes no completable positional args (so the shell does not fall back to file completion), otherwise supply real completions.

  `ValidArgs` and `ValidArgsFunction` are mutually exclusive; Cobra reports an error when both are set.
- **Flag-value completion**: call `cmd.RegisterFlagCompletionFunc(name, fn)` inside the wrapper, after binding the flag.
- **Built-in `completion` prefix collision**: when an operation gives the **root** command a subcommand whose name starts with `co`, shell completion of that name now competes with the auto-generated `completion` subcommand (typing `<cli> co<TAB>` no longer completes uniquely).

  Ask the user whether to hide the built-in command from help and completion — use `AskUserQuestion` when the tool is available, otherwise ask as a plain question in the response.

  Hiding means setting on the root literal in `commands/root.go`:

  ```go
  CompletionOptions: cobra.CompletionOptions{HiddenDefaultCmd: true},
  ```

  `<cli> completion <shell>` still works; the command is only dropped from help output and completion suggestions.

  **Skip the question** when the root literal already sets `CompletionOptions.HiddenDefaultCmd` or `CompletionOptions.DisableDefaultCmd`.

## Helper catalog

Brief catalog only — full source lives at `${SKILL-DIR}/helpers/<source-path>/`.

The source path under `helpers/` mirrors the destination path under `<project-root>/`, so `helpers/internal/cmdsignals/` → `<project-root>/internal/cmdsignals/`, `helpers/internal/loggerfactory/` → `<project-root>/internal/loggerfactory/`, etc.

Run `"${SKILL-DIR}/copy_helper.sh" <project-root>` to copy the always-on packages (`libver`, `loggerfactory`, `versioninfo` — source and tests — plus `cmdsignals/signals.go`) in one step; add `--cmdsignals-full` to also copy the rest of `cmdsignals` (`notify.go` + tests). Scaffolding always passes `--cmdsignals-full`.

`<project-root>` must already exist.

### Library packages (copied verbatim)

| Helper          | Import path                          | Purpose                                                                                                                                  | Signature(s)                                                                                                                                                                                                                                                                                                        | Use when                                                                                                              |
| --------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `cmdsignals`    | `{{MODULE}}/internal/cmdsignals`     | signal-cancellable root context for `SIGINT` / `SIGTERM`. Split in two: `signals.go` holds only the project-owned `ExitSignals` set (may evolve per project); `notify.go` is `atomicsignal.NotifyContext` (from `github.com/ngicks/go-common/atomicsignal`, external dep) with `ExitSignals` baked in as the canceling set; callers defer `n.Stop()` (and cancel) to release resources | `NotifyContext(ctx, signals ...os.Signal) (n *Notifier, ctx context.Context, cancel context.CancelCauseFunc)`, `CtxValueNotifier(ctx) (*Notifier, bool)` and `NewHandler(buffer, defaultHandler, handlers) *Handler` (stable proxies of the `atomicsignal` functions), `type Notifier = atomicsignal.Notifier` (methods `Run()` / `Stop()` / `Swap(*Handler)` / `Restore()`), `type Handler = atomicsignal.Handler`, `type SignalReceivedError = atomicsignal.SignalReceivedError` (stable re-exports; recover the cancellation cause via `context.Cause` + `errors.AsType`), `var ExitSignals [...]os.Signal` (project-owned) — callers never import `atomicsignal` directly | Always when scaffolding (`main.go` calls `NotifyContext`; copy with `--cmdsignals-full`). For existing projects, only when adopting this template.   |
| `libver`        | `{{MODULE}}/internal/libver`         | the module-wide, release-controlled `const Version` at a fixed path; rewritten by the external `bump-libver` tool                        | `Version` (a `const`; declared alone)                                                                                                                                                                                                                                                                               | Always when scaffolding (the version subcommand imports it). For existing projects, only when adopting this template. |
| `loggerfactory` | `{{MODULE}}/internal/loggerfactory`  | `--log` / `--log-level` flag wiring, env-var overrides, opt-in `*slog.Logger`; `Level{Trace,Fatal}` constants reusable from `<name-without-separator>` | `RegisterFlags(cmd) *Config`, `ReadEnv(*Config, appName string, env []string) error`, `BuildLogger(*Config) *slog.Logger`, `BuildLoggerTo(*Config, io.Writer) *slog.Logger`, `type Config`, `LevelTrace`, `LevelFatal`                                                                                              | Always when scaffolding (root.go imports it). For existing projects, only when adopting this template.                |
| `versioninfo`   | `{{MODULE}}/internal/versioninfo`    | combine the project's `Version` with VCS info from `runtime/debug.ReadBuildInfo`                                                         | `ReadVersionInfo(version string) Info`, `type Info`                                                                                                                                                                                                                                                                 | Always when scaffolding (the version subcommand imports it). For existing projects, only when adopting this template. |

There are no bespoke pause/resume wrappers — divert signals with `atomicsignal`'s own `Notifier.Swap` / `Restore`.

Do that only in a leaf's `run{{Name}}` that hands the terminal to a child process — exec'ing an editor, an interactive REPL, a `less` pager — where `SIGINT` should reach the child instead of cancelling the CLI. `NotifyContext` stores the `Notifier` in the ctx it returns, so fetch it from `cmd.Context()`:

```go
n, ok := cmdsignals.CtxValueNotifier(cmd.Context())
if ok {
	h := cmdsignals.NewHandler(1, forwardToChild, nil) // func(os.Signal)
	go h.Run()
	defer h.Stop()
	n.Swap(h)         // divert signals to h instead of cancelling ctx
	defer n.Restore() // route back to the canceling handler
}
```

The relay underneath keeps its one channel registered with `os/signal` across swaps, so the process never falls back to the default `SIGINT` / `SIGTERM` behavior mid-swap. The registered signal set is fixed up front — pass extra non-canceling signals to `cmdsignals.NotifyContext(ctx, extraSigs...)` at startup when a swapped-in handler will need them (e.g. `SIGWINCH` for a terminal app).

The default scaffold needs none of this — `NotifyContext` + `n.Run` alone give the standard "signal cancels `ctx`" behavior.

### Cancellable stdio (external — nothing copied)

There is no bundled stdio helper. When a subcommand blocks on `os.Stdin` / `os.Stdout` / `os.Stderr` and must unblock on `ctx.Done()`, depend on the external `github.com/ngicks/go-common/iopipe` package (`go get github.com/ngicks/go-common/iopipe@latest` when first used):

- `iopipe.NewReader(os.Stdin)` / `iopipe.NewWriter(os.Stdout)` return pipe controllers; call their `Run(ctx)` in a goroutine (e.g. `sync.WaitGroup.Go`).
- `Pipe(ctx)` derives an `io.ReadCloser` / `io.WriteCloser` plus a channel that reports exactly once how the pipe ended: `nil` when every piped byte was consumed, else `*iopipe.CloseError` (delivered byte count + cause). Cancelling `ctx` closes the derived pipe with the context error.
- Closing a derived pipe pauses forwarding without closing or interrupting the underlying file; `Pipe` can be called again afterwards (at most one derived pipe is active at a time).

### Release tool (external — nothing copied)

Releases use the published `bump-libver` tool; no release code lives in the project:

```sh
go run github.com/ngicks/go-common/tools/bump-libver@latest <release-version> [<next-dev-version>]
```

It reads the fixed `internal/libver/libver.go` (legacy in-service `version.go` locations — top-level or under `pkg/` — are auto-detected as fallbacks), refuses on a dirty tree or duplicate tag, rewrites + commits + tags, bumps to the next `-devel`, and pushes the branch and tag to `origin` — aborting if either push fails, leaving the local commits + tag in place for manual re-push.

See [Versioning & release](versioning.md) for the contract it expects.

### Templates (filled per project; not copied verbatim)

| Template                           | Destination                             | Purpose                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`{{NAME}}/config.go`](config-source.md)           | `<root>/<name-without-separator>/config.go`           | `Config` + `DefaultConfig`, the exported `PartialConfig` + `Apply` (the single overlay primitive), isolated `unmarshalConfigFile`, and `LoadConfig` (defaults < file < env; env layer via caarlos0/env + `envOptions`). Triple `json:`+`yaml:`+`env:` tags; file format JSON-only / YAML-only / both (YAML wins, one file). Scalars/slices overwrite; nested structs/maps deep-merge. |
| [`cmd/{{NAME}}/commands/version.go`](versioning.md#cmdnamecommandsversiongo-always-present) | `<root>/cmd/<name>/commands/version.go` | The `version` subcommand and `runVersion`. Wired unconditionally by `rootCmd()`; alias of `--version`.                                                                                                                                                                                                                                                                                |
| [`cmd/{{NAME}}/commands/config.go`](configuration.md#cmdnamecommandsconfiggo-always-present)  | `<root>/cmd/<name>/commands/config.go`  | The `config` subcommand and `runConfig` — thin wiring. Wired unconditionally by `rootCmd()`; loads `LoadConfig` and delegates rendering to `cli.RenderConfig`. `Long` hand-writes the `--format` field tree; appends `cli.TemplateFuncHelp()`.                                                                                                                                         |
| [`{{NAME}}/cli/config.go`](configuration.md#cmdnamecommandsconfiggo-always-present)        | `<root>/<name-without-separator>/cli/config.go`       | `RenderConfig` (resolved config → indented JSON, or a Go `text/template` with the shared funcs) + `TemplateFuncHelp`. Presentation lives here, not under `./cmd`; writes to the passed `io.Writer`.                                                                                                                                                                                  |
| [`internal/templateutil/templateutil.go`](configuration.md#cmdnamecommandsconfiggo-always-present) | `<root>/internal/templateutil/templateutil.go` | Shared `text/template` `FuncMap` (`json` baseline + project helpers) and its single-source-of-truth `FuncDocs` / `FuncHelp`. `FuncMap` ↔ `FuncDocs` kept in lockstep by a test.                                                                                                                                                                            |
