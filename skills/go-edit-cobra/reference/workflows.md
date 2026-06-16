# Workflows & helper catalog

Step-by-step procedures for scaffolding a new project and editing an existing one, plus the catalog of bundled helper packages. The templates these steps reference live in [command-templates.md](command-templates.md), [configuration.md](configuration.md), [config-source.md](config-source.md), and [versioning.md](versioning.md).

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

Subcommands accept dot notation (`server.start`) or natural language ("a server group containing start and stop"). Dotted = parent group + child leaf.

Generation steps (relative to module root):

1. Resolve all parameters. **Derive the `pkg/<name>` package name now**: strip hyphens/underscores from the project name so the directory follows Go convention (`my-tool` → `pkg/mytool/`, `package mytool`) — see [Naming conventions › Package name](layout-and-naming.md#package-name-pkgname). `cmd/<name>/`, `Use:`, the env prefix, and the config-dir path keep the verbatim project name; only `pkg/<name>`, the `package` clause, and `{{MODULE}}/pkg/<name>` imports use the stripped form. When the project name is already a valid identifier they are identical.
2. Write `go.mod` (placeholder `v0.0.0` lines per the [template](command-templates.md#gomod), except the pinned `go.yaml.in/yaml/v4 v4.0.0-rc.5`).
3. Write `cmd/<name>/main.go` ([template](command-templates.md#cmdnamemaingo)).
4. Write `cmd/<name>/commands/root.go` ([template](command-templates.md#cmdnamecommandsrootgo) already wires `versionCmd(cmd)` and the `--version` flag — leave that in place).
5. Write `pkg/<name>/version.go` ([template](versioning.md#pkgnameversiongo-always-present)). The initial `Version` value is `v0.0.0-devel`.
6. Write `pkg/<name>/config.go` ([template](config-source.md)). Fill in the real `Config` fields + `DefaultConfig`, the mirrored `PartialConfig` + `Apply` (one overlay line per field, by kind — scalar / nested / map / slice), and `LoadConfig` (env layer via caarlos0/env's `ParseWithOptions` + the package-level `envOptions`). Give every field `json:`, `yaml:`, and `env:` (or `envPrefix:` for a nested sub-config) tags. For the chosen **config file format**: JSON-only uses the template as-is; for `yaml`/`both`, apply the [YAML support block](config-source.md#yaml-support-yaml-only-or-both-formats) (format-aware `unmarshalConfigFile`/`configPath` + the `go.yaml.in/yaml/v4` dep). Keep it one file.
7. Write `cmd/<name>/commands/version.go` ([template](versioning.md#cmdnamecommandsversiongo-always-present)).
8. Write `cmd/<name>/commands/config.go` ([template](configuration.md#cmdnamecommandsconfiggo-always-present)). The root template already declares the persistent `--config` flag and wires `configCmd(cmd, &flagConfig)` beside `versionCmd(cmd)` — leave that in place.
9. Write one `cmd/<name>/commands/<subcmd>.go` per flat leaf. Then edit `root.go` to call `{{subCamel}}Cmd(cmd)` inside `rootCmd()` for each.
10. For nested commands, write the parent **before** child files. Wire the parent into `rootCmd()`. Then write children and add `{{parentCamel}}{{ChildPascal}}Cmd(cmd)` calls inside the parent's wrapper function.
11. Copy the verbatim helper packages into `<root>` by running `"${SKILL-DIR}/copy_helper.sh" <root>` (add `--stdiopipe` when a subcommand needs cancellable stdio). This copies the `cmdsignals`, `loggerfactory`, `versioninfo`, and `internal/cmd/release` packages — each package's source **and** tests — to their mirrored paths under `<root>`; `--stdiopipe` additionally copies `cmd/internal/stdiopipe`. No build-time edits are needed: the release helper auto-detects `pkg/*/version.go`.
12. For each direct dep in `go.mod`: `go get <module>@latest` — using the correct `/vN` major path (e.g. `github.com/caarlos0/env/v11@latest`; confirm the current major first, see [Version policy](command-templates.md#gomod)). Exception: pin pre-release YAML with `go get go.yaml.in/yaml/v4@v4.0.0-rc.5` (or omit entirely for a JSON-only project).
13. `go mod tidy`.
14. Run the post-edit validation chain (see SKILL.md › Post-edit validation).
15. Report the generated file list to the user.

Use **Write** for every file. Write creates parent directories — do not run `mkdir` separately.

## Edit an existing project

Pre-flight checks first (Cobra detection, layout classification — see SKILL.md › Pre-flight checks). Then pick the operation; each entry below lists what to touch.

### Subcommand structure

| Operation                           | Files / actions                                                                                                                                                                                                          | Ask the user when                                                                                                                     |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Add flat subcommand                 | new `commands/<subcmd>.go` (flat-leaf template); add `{{subCamel}}Cmd(cmd)` call inside `rootCmd()` in `commands/root.go`                                                                                                | —                                                                                                                                     |
| Add nested subcommand               | new `commands/<parent>_<child>.go`; add `{{parentCamel}}{{ChildPascal}}Cmd(cmd)` call inside the parent's wrapper. If parent missing, also write `commands/<parent>.go` and add `{{parentCamel}}Cmd(cmd)` to `rootCmd()` | —                                                                                                                                     |
| Rename subcommand                   | rename file; rename wrapper `{{old}}Cmd` → `{{new}}Cmd`; rename `run{{Old}}` → `run{{New}}`; update the wiring call in the parent wrapper. Search for any external reference (tests, docs, completion)                   | —                                                                                                                                     |
| Remove leaf                         | delete file; remove its wiring call from the parent wrapper                                                                                                                                                              | —                                                                                                                                     |
| Remove group                        | delete file + all children; remove the group's wiring call from `rootCmd()`                                                                                                                                              | If children exist (cascade vs refuse)                                                                                                 |
| Promote leaf → group                | drop `RunE` from leaf cmd literal; split logic into a new child file; add the new child's wiring call inside the (now-promoted) wrapper                                                                                  | Where original `RunE` body, `Args`, `Aliases`, `Example`, `PreRunE`, `PostRunE`, and flags go (parent persistent / new child / split) |
| Demote group → leaf                 | inline child wiring into parent wrapper; give the cmd a `RunE`                                                                                                                                                           | If children exist (merge / refuse)                                                                                                   |
| Move leaf under different parent    | rename file (`<old-parent>_<name>.go` → `<new-parent>_<name>.go`); rename wrapper and run func; remove the wiring call from the old parent wrapper and add it to the new one                                             | If new parent missing                                                                                                                 |
| Move subtree under different parent | rename every descendant file / wrapper / run func; move every affected wiring call to the appropriate parent wrapper                                                                                                     | If new parent missing                                                                                                                 |

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

`PreRunE`, `PostRunE`, `PersistentPreRunE`, `PersistentPostRunE` — set on the `cobra.Command` literal; assign a named function (`preRun{{Name}}`, `postRun{{Name}}`) defined in the same file. Use a closure adapter to forward captured flag values when needed, mirroring the `RunE` rule.

### Completion

- **Positional-argument completion**: set `ValidArgsFunction` (dynamic), `ValidArgs` (static slice), or `cobra.FixedCompletions(...)` on the `cobra.Command` literal inside the wrapper. The stub leaf templates leave this as a TODO — fill it to match the command's `Args`: use `cobra.NoFileCompletions` when the command takes no completable positional args (so the shell does not fall back to file completion), otherwise supply real completions. `ValidArgs` and `ValidArgsFunction` are mutually exclusive; Cobra reports an error when both are set.
- **Flag-value completion**: call `cmd.RegisterFlagCompletionFunc(name, fn)` inside the wrapper, after binding the flag.

## Helper catalog

Brief catalog only — full source lives at `${SKILL-DIR}/helpers/<source-path>/`. The source path under `helpers/` mirrors the destination path under `<project-root>/`, so `helpers/cmd/internal/cmdsignals/` → `<project-root>/cmd/internal/cmdsignals/`, `helpers/internal/loggerfactory/` → `<project-root>/internal/loggerfactory/`, `helpers/internal/cmd/release/` → `<project-root>/internal/cmd/release/`, etc.

Run `"${SKILL-DIR}/copy_helper.sh" <project-root>` to copy the always-on packages (`cmdsignals`, `loggerfactory`, `versioninfo`, `internal/cmd/release`) — source and tests — in one step; add `--stdiopipe` to also copy `cmd/internal/stdiopipe`. `<project-root>` must already exist.

### Library packages (copied verbatim)

| Helper          | Import path                          | Purpose                                                                                                                                  | Signature(s)                                                                                                                                                                                                                                                                                                        | Use when                                                                                                              |
| --------------- | ------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `cmdsignals`    | `{{MODULE}}/cmd/internal/cmdsignals` | signal-cancellable root context for `SIGINT` / `SIGTERM`, with pause/resume for temporarily forwarding signals to a child process        | `NotifyContext(ctx) (blockOn func(), ctx context.Context, cancel func(error))`, `Pause(ctx, installHandler func()) bool`, `Resume(ctx, removeHandler func()) bool`, `type SignalReceivedError{Sig os.Signal}` (cancellation cause; recover via `context.Cause` + `errors.AsType`), `var ExitSignals [...]os.Signal` | Always when scaffolding (`main.go` calls `NotifyContext`). For existing projects, only when adopting this template.   |
| `loggerfactory` | `{{MODULE}}/internal/loggerfactory`  | `--log` / `--log-level` flag wiring, env-var overrides, opt-in `*slog.Logger`; `Level{Trace,Fatal}` constants reusable from `pkg/<name>` | `RegisterFlags(cmd) *Config`, `ReadEnv(*Config, appName string, env []string) error`, `BuildLogger(*Config) *slog.Logger`, `BuildLoggerTo(*Config, io.Writer) *slog.Logger`, `type Config`, `LevelTrace`, `LevelFatal`                                                                                              | Always when scaffolding (root.go imports it). For existing projects, only when adopting this template.                |
| `versioninfo`   | `{{MODULE}}/internal/versioninfo`    | combine the project's `Version` with VCS info from `runtime/debug.ReadBuildInfo`                                                         | `ReadVersionInfo(version string) Info`, `type Info`                                                                                                                                                                                                                                                                 | Always when scaffolding (the version subcommand imports it). For existing projects, only when adopting this template. |
| `stdiopipe`     | `{{MODULE}}/cmd/internal/stdiopipe`  | cancellable `os.Stdin` / `os.Stdout` / `os.Stderr` via `io.Pipe`                                                                         | `Stdin(ctx) io.ReadCloser`, `Stdout(ctx) io.WriteCloser`, `Stderr(ctx) io.WriteCloser`                                                                                                                                                                                                                              | A subcommand blocks on stdio and must unblock on `ctx.Done()`. Single-use per process — second call panics.           |

`cmdsignals.Pause` / `Resume` take the same `ctx` that `NotifyContext` produced (threaded through `cmd.Context()`). Reach for them only in a leaf's `run{{Name}}` that hands the terminal to a child process — exec'ing an editor, an interactive REPL, a `less` pager — where `SIGINT` should reach the child instead of cancelling the CLI. `Pause` stops this package's handler (its `installHandler` callback is where you install the child's own forwarding handler) and `Resume` restores it (`removeHandler` uninstalls yours); both no-op safely if the context carries no manager or is already cancelled. The default scaffold needs neither — `NotifyContext` alone gives the standard "signal cancels `ctx`" behavior.

### Build-time `main` packages (copied verbatim)

| Helper    | Source                                 | Destination                           | Purpose                                                                                                                                      | Use when                                                                                                                      |
| --------- | -------------------------------------- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `release` | `helpers/internal/cmd/release/main.go` | `<root>/internal/cmd/release/main.go` | Cross-platform release helper. Validates inputs, rewrites `pkg/<name>/version.go`'s `const Version`, commits + tags, bumps to next `-devel`. | Always when scaffolding. Invoke during a release with `go run ./internal/cmd/release <release-version> [<next-dev-version>]`. |

The release helper auto-detects `pkg/*/version.go` and refuses on a dirty tree or duplicate tag. It pushes the branch and the new tag to `origin` on success; if either push fails it aborts and leaves the local commits + tag in place for manual re-push. See [Versioning & release](versioning.md) for the contract it expects.

### Templates (filled per project; not copied verbatim)

| Template                           | Destination                             | Purpose                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [`pkg/{{NAME}}/version.go`](versioning.md#pkgnameversiongo-always-present)          | `<root>/pkg/<name>/version.go`          | Declares `const Version`. Rewritten by `internal/cmd/release`. No imports.                                                                                                                                                                                                                                                                                                            |
| [`pkg/{{NAME}}/config.go`](config-source.md)           | `<root>/pkg/<name>/config.go`           | `Config` + `DefaultConfig`, the exported `PartialConfig` + `Apply` (the single overlay primitive), isolated `unmarshalConfigFile`, and `LoadConfig` (defaults < file < env; env layer via caarlos0/env + `envOptions`). Triple `json:`+`yaml:`+`env:` tags; file format JSON-only / YAML-only / both (YAML wins, one file). Scalars/slices overwrite; nested structs/maps deep-merge. |
| [`cmd/{{NAME}}/commands/version.go`](versioning.md#cmdnamecommandsversiongo-always-present) | `<root>/cmd/<name>/commands/version.go` | The `version` subcommand and `runVersion`. Wired unconditionally by `rootCmd()`; alias of `--version`.                                                                                                                                                                                                                                                                                |
| [`cmd/{{NAME}}/commands/config.go`](configuration.md#cmdnamecommandsconfiggo-always-present)  | `<root>/cmd/<name>/commands/config.go`  | The `config` subcommand and `runConfig`. Wired unconditionally by `rootCmd()`; prints `LoadConfig` as JSON, or via a `--template`.                                                                                                                                                                                                                                                    |
