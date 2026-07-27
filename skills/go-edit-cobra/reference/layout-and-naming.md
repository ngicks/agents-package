# Layout, naming & anti-patterns

Structural conventions for a canonical Cobra project: where each file lives, how to name files / wrappers / run functions, and the mistakes that silently break the layout contract.

Read this when scaffolding, adding/renaming/moving subcommands, or deciding where a new file belongs.

## Contents

- [Project layout (canonical)](#project-layout-canonical)
- [Main vs utility entry points](#main-vs-utility-entry-points) — when a binary earns a top-level service package, and when to ask
- [Public RPC API (`api/`)](#public-rpc-api-api) — schema + generated-code layout, buf/proto3 rules, the collision-avoiding path prefix
- [Naming conventions](#naming-conventions) — flat, nested, the subdirectory variant, non-subcommand files, package name, service method options
- [Anti-patterns](#anti-patterns) — grouped: layout & placement · mandatory pieces · naming · construction & wiring · run functions & the `./cmd` boundary · service method options · versioning · configuration model

## Project layout (canonical)

```
<module-root>/
├── go.mod
├── cmd/
│   └── <name>/
│       ├── main.go
│       └── commands/
│           ├── root.go                  # rootCmd() + Execute(ctx) + runRoot
│           ├── version.go               # always present; "version" subcommand + --version alias
│           ├── config.go                # always present; "config" subcommand (prints resolved config)
│           ├── zz_<helper>.go           # any non-subcommand helper file (prefix zz_)
│           ├── <subcmd>.go              # one per flat leaf
│           ├── <parent>.go              # one per group (no RunE)
│           └── <parent>_<child>.go      # one per nested leaf (zz-prefix a trailing GOOS/GOARCH/test leaf: foo_windows.go → foo_zzwindows.go)
├── internal/
│   ├── cmdsignals/
│   │   └── signals.go                   # always present
│   ├── stdiopipe/                       # only when a subcommand needs cancellable stdio
│   │   └── stdiopipe.go
│   ├── cmd/
│   │   └── release/
│   │       └── main.go                  # always present; cross-platform release helper
│   ├── loggerfactory/
│   │   └── loggerfactory.go             # always present; --log / --log-level wiring
│   ├── templateutil/
│   │   └── templateutil.go              # always present; shared text/template FuncMap + FuncDocs (json, + project helpers)
│   └── versioninfo/
│       └── versioninfo.go               # always present; ReadVersionInfo (Version + VCS info)
├── api/                                 # only when the project exposes a public RPC API — see below
│   ├── buf.yaml
│   ├── gen/
│   └── schema/
└── <name-without-separator>/            # the service package — the project's MAIN functionality
    ├── version.go                       # always present; release-controlled `const Version`
    ├── config.go                        # always present; Config + DefaultConfig, PartialConfig + Apply, LoadConfig
    ├── <service>.go                     # internal service implementation
    └── cli/                             # CLI-presentation code (printing, prompts, tables, colors)
        ├── config.go                    # always present; RenderConfig (config subcommand JSON / --format)
        └── <ui>.go
```

The placeholder is deliberately spelled `<name-without-separator>`: it is an importable Go package directory, so it follows Go package-name convention — the project name with every `-` / `_` stripped (see [Package name](#package-name-name-without-separator)). `cmd/<name>/` keeps the verbatim project name.

Subcommand files MAY alternatively nest under subdirectories of `commands/` (one directory per group, one Go package per directory).

That is an **allowed variant**, not the canonical default — it exists so a project's structure preference survives edits and re-scaffolding; never flatten or introduce it unprompted. See [Subdirectory-nested subcommands](#subdirectory-nested-subcommands-allowed-variant).

Why this shape:

- `cmd/<name>/` lets a future second binary be added as `cmd/<other>/` with no churn.
- `internal/` holds every internal helper package — `cmdsignals`, `stdiopipe`, `loggerfactory`, `templateutil`, `versioninfo`, and the build-time `cmd/release` — in one module-root tree, reachable from both `./cmd` and `./<name-without-separator>` while blocked to external modules under Go's `internal/` rule.

  `templateutil` is the shared `text/template` `FuncMap` + `FuncDocs` (`json` baseline, plus any project helpers) that every renderer exposes; the `config` subcommand's `--format` uses it via `<name-without-separator>/cli`. One copy keeps the func set — and its help text — identical across call sites.
- `internal/loggerfactory/` is genuinely shared, not CLI-only: `<name-without-separator>` code imports its level constants — notably `LevelTrace` and `LevelFatal` — and emits records at levels the CLI knows how to render.

  That cross-package use is why the logger glue is a library under `internal/`, not `zz_`-prefixed code under `commands/`.

  The flag wiring is still CLI-only; the package is shared because the level constants are shared.

- `<name-without-separator>/` holds the actual service, as a **top-level** package at the module root.

  `./cmd` is wiring only — flags, positional args, and (logger-only) env vars feed into a service constructed from `<name-without-separator>`.

  The top level is reserved for the project's **main** functionality; a binary that is merely a utility does not earn a top-level package — see [Main vs utility entry points](#main-vs-utility-entry-points).

  (An older revision of this layout placed the service at `pkg/<name-without-separator>/`. That is now a **legacy variant**: preserve it in projects that already use it — new files follow the existing `pkg/` placement — and migrate to top-level only on explicit user request.)

- `api/` (optional) holds the public RPC API schema and its generated code — see [Public RPC API](#public-rpc-api-api).

  Never scaffold it speculatively; create it only when the project actually exposes an RPC API.

- `<name-without-separator>/cli/` holds CLI-presentation code (printing, prompts, tables, colors, spinners).

  `RunE` calls into it and returns its error.

  The `config` subcommand's rendering lives here as `cli.RenderConfig` (JSON default / `--format` template) — `./cmd` only loads the config and writes `RenderConfig`'s output to stdout.

- The `zz_` prefix on non-subcommand files makes the file → subcommand mapping unambiguous: any file without `zz_` is a single subcommand definition.

  (`_` prefix is **not** usable — `cmd/go` ignores files starting with `_` or `.`.)

  - as per Go's file name rule, `<helper>` (the part after `zz_`) can not be `test`, `$GOARCH`(e.g. `amd64`, etc), `$GOOS`(e.g. `windows`, etc) — `zz_windows.go` would compile on Windows only.

    The same rule constrains a subcommand whose **leaf** file segment is such a token; the fix there is to `zz`-prefix that segment in place. See [Build-constraint suffix collisions in leaf file names](#build-constraint-suffix-collisions-in-leaf-file-names).

- `version.go` is split across **three** packages by design.

  `<name-without-separator>/version.go` declares only `const Version`, kept import-free so external consumers of `<name-without-separator>` don't drag in `internal/`.

  `internal/versioninfo/versioninfo.go` provides `ReadVersionInfo(version) Info` — the reusable VCS-info combiner consumed by the binary.

  `cmd/<name>/commands/version.go` is the thin CLI presentation layer that calls `versioninfo.ReadVersionInfo(<name-without-separator>.Version)`.

  `version.go` is the one canonical-mapping leaf that does **not** need the `zz_` prefix because `version` is itself a real subcommand.

- `internal/cmd/release/` is a `main` package, not a runtime helper.

  It lives under `internal/` so it cannot be `go install`ed by external modules (it's a build-time tool of this module only).

  One Go source base replaces what would otherwise be parallel bash + PowerShell scripts.

- Never put `commands/` directly at the module root. See [Anti-patterns](#anti-patterns).

## Main vs utility entry points

`cmd/<name>/` maps to the top-level service package `./<name-without-separator>/` only when that binary is a **main functionality** of the project.

A project may grow additional binaries (`cmd/<other>/`) that are merely utilities — a debug console, a data importer, an admin helper. Those do **not** earn a top-level package.

- **Main functionality** → service code lives at the top level: `./<other-without-separator>/` (sanitized name, same rules as `./<name-without-separator>/`).

  The project then has two peer service packages at the module root — both part of its public Go API surface.
- **Utility** → service code lives under `internal/` (e.g. `internal/<other-without-separator>/`), keeping the module's importable surface to the main package(s).

  The `cmd/<other>/` wiring layer is identical either way; only the service package's placement changes.
- **When adding a new entry point, ask the user which it is** — main or utility — unless the request already says so.

  Do not silently default to a top-level package: the top level is a public-API statement, not a dumping ground.
- The scaffold's first binary needs no ask: it carries the project's name and **is** the main functionality by definition.
- If a would-be top-level package name collides with a reserved directory (`cmd`, `internal`, `api`, or a legacy `pkg`), stop and ask the user for an alternative name.

## Public RPC API (`api/`)

Optional top-level directory holding the project's **public RPC API**: the schema sources and the code generated from them.

Create it only when the project actually exposes an RPC API — never speculatively.

```
<module-root>/api/
├── buf.yaml                     # buf module config — lives here, not at the module root
├── gen/                         # generated code, committed
│   ├── proto/
│   │   ├── go/                  # Go stubs — imported by <name-without-separator>/, never called directly from ./cmd
│   │   └── <lang>/              # one directory per additional target language
│   └── <schema format>/         # generated code for a non-proto schema format
└── schema/
    └── proto/                   # or another schema format's directory (openapi/, jsonschema/, ...)
        └── <prefix>/<name-without-separator>/v1/<name-without-separator>.proto
```

Rules:

- **Prefer `buf`.** Consequently write **`proto3` only** — never `proto2` — for protocol buffers.

  `buf.yaml` lives under `./api` (alongside `buf.gen.yaml` when code is generated), with `api/schema/proto` as the module's proto root.
- **Always prefix the proto package/service path** with `<username>` or `<organizationname>` (or both) so it cannot collide with other projects' schemas.

  `<prefix>` in the tree above is that segment — e.g. `watage/mytool/v1/mytool.proto` with `package watage.mytool.v1;`.
- **Resolving the prefix convention**, in order:
  1. An explicit user instruction for the name — use it verbatim.
  2. A convention already present in the repo (existing `api/schema` paths, proto `package` lines) — follow it.
  3. Neither — **ask the user** which prefix (username, organization, or both) to use before writing any schema.
- Generated code lands under `api/gen/<format>/<lang>/` and is committed; regenerate rather than hand-edit.

  The service package `<name-without-separator>/` implements the generated interfaces; `./cmd` stays wiring-only, as always.

## Naming conventions

### Flat subcommands

- **Wrapper function**: `{{camelCase}}Cmd` — e.g. `serve` → `serveCmd`, `dry-run` → `dryRunCmd`.

  Signature: `func {{camelCase}}Cmd(parent *cobra.Command)`.
- **Run function**: `run{{PascalCase}}` — e.g. `runServe`, `runDryRun`.
- **File name**: `commands/<subcmd>.go` preserving hyphens — `commands/serve.go`, `commands/dry-run.go`.
- **Wiring**: `rootCmd()` calls `{{camelCase}}Cmd(cmd)` once.

### Nested subcommands

- **File name**: `commands/{{parent}}_{{child}}.go` — underscore-joined, hyphens preserved per segment.

  `server start` → `commands/server_start.go`. 3-level: `commands/db_migrate_up.go`.

- **Wrapper function**: concatenate camelCase — `serverStartCmd`, `dbMigrateUpCmd`.

  Same signature shape as flat.
- **Run function**: concatenate PascalCase — `runServerStart`, `runDbMigrateUp`.
- **Parent group**: no `RunE`, no `Args` by default.
- **Wiring**: parent's wrapper calls `{{parentCamel}}{{ChildPascal}}Cmd(cmd)`.

  3-level follows the same chain (`server_start_foo.go` is wired from inside `serverStartCmd`).

### Subdirectory-nested subcommands (allowed variant)

A group MAY live as a subdirectory of `commands/` instead of underscore-joined files — one directory per group, one Go package per directory.

This variant is **allowed, not preferred**: it exists so a project that organizes its command tree in directories keeps that shape through skill edits and re-scaffolding.

- **Preserve, never migrate.** When the project already nests, keep nesting: new children of a directory-shaped group go into its directory; new children of a flat group stay flat.

  Do not flatten a nested tree into `<parent>_<child>.go` files, and do not split a flat tree into directories, unless the user explicitly asks.
- **Scaffold default stays flat.** Generate directories only when the user asks for them — or when re-scaffolding a project whose previous layout used them.
- **Mirror in-project precedent first.** An existing project may wire its subpackages differently (e.g. exported per-child wrappers like `server.StartCmd`); follow whatever pattern its other subdirectories use.

  The canonical shape below applies when there is no precedent — the project's first directory-shaped group.

Canonical shape:

- **Directory**: `commands/<parent>/`, keeping the verbatim group name.
- **Package clause**: the sanitized group name — strip `-` / `_`, same rule as [`<name-without-separator>`](#package-name-name-without-separator) (`dry-run/` → `package dryrun`).
- **Group file**: `commands/<parent>/<parent>.go` exports the subpackage's one boundary symbol, `func Cmd(parent *cobra.Command)`.

  It builds the group's `cobra.Command`, calls the children's (unexported) wrappers, and ends with `parent.AddCommand(cmd)` — the standard group wrapper, exported because it crosses the package boundary.
- **Child files drop the prefix the directory already expresses**: `server start` → `commands/server/start.go`, wrapper `startCmd`, run function `runStart`.

  Inside the subpackage the flat rules apply verbatim — unexported wrappers, `zz_` prefix for non-subcommand files, the [build-constraint suffix rule](#build-constraint-suffix-collisions-in-leaf-file-names) on trailing `_`-segments of file names.
- **Wiring**: the enclosing package imports `{{MODULE}}/cmd/<name>/commands/<parent>` and calls `<parent>.Cmd(cmd)` — from `rootCmd()` for a top-level group.

  Persistent-flag threading is unchanged: pass `&flag` as extra parameters on `Cmd`.
- **Deeper levels**: inside the subpackage, use underscore-joined files (`start_foo.go`) or a further subdirectory — mirror whichever the project already does.

```go
// commands/server/server.go
package server

import "github.com/spf13/cobra"

// Cmd is the subpackage's one exported symbol; rootCmd() calls server.Cmd(cmd).
func Cmd(parent *cobra.Command) {
	cmd := &cobra.Command{
		Use:   "server",
		Short: "manage the server",
	}

	startCmd(cmd)
	stopCmd(cmd)

	parent.AddCommand(cmd)
}
```

### Build-constraint suffix collisions in leaf file names

Go derives an implicit `GOOS` / `GOARCH` / `test` build constraint from the **trailing** `_`-delimited segment(s) of a file name (everything before the first `_` is exempt).

A file whose name ends in `_<GOOS>`, `_<GOARCH>`, `_<GOOS>_<GOARCH>`, or `_test` is silently compiled only on the matching platform (or treated as a test file). A subcommand whose file name lands such a suffix then **vanishes from normal builds** — `go vet` / `go build` pass on your host, and the command is just missing elsewhere.

This bites **nested-leaf file names**, and only when the offending name is in the **trailing** position (i.e. the leaf segment):

- **Leaf segment is a GOOS / GOARCH / `test`** → constrained.

  `foo windows` → `foo_windows.go` compiles on Windows only.

  3-level `db linux amd64` → `db_linux_amd64.go` compiles on linux/amd64 only (the trailing `_linux_amd64` pair).

  `db test` → `db_test.go` is treated as a test file, dropped from the normal build.
- **Flat leaves and group parents are never affected.** A single-segment file has no `_`, so Go exempts it — `windows.go`, `linux.go`, `amd64.go` compile everywhere.
- **A GOOS / GOARCH-named parent is harmless.** It sits before the first `_` (a non-trailing segment), which Go ignores.

  `windows sub` → `windows_sub.go` (trailing `_sub`) compiles everywhere — leave it as is.

**Fix — `zz`-prefix the offending trailing segment in the file name only:**

- `foo_windows.go` → `foo_zzwindows.go`
- `db_linux_amd64.go` → `db_linux_zzamd64.go`
- `db_test.go` → `db_zztest.go`

`zzwindows` / `zzamd64` / `zztest` are not known GOOS / GOARCH / `test` tokens, so the implicit constraint disappears.

Only the **file name** changes. The command's `Use:` string, the wrapper function (`fooWindowsCmd`), and the run function (`runFooWindows`) keep the **real** leaf name — the command tree and wiring are unaffected.

Do **not** over-apply: never mangle a non-trailing segment. `windows_sub.go` stays `windows_sub.go`, never `zzwindows_sub.go`. Only the last `_`-segment can carry the constraint, so only it ever needs the prefix.

This is the same Go rule that constrains a `zz_<helper>` file's `<helper>` part (see [Non-subcommand files](#non-subcommand-files)); only the fix differs — a leaf file keeps its real name with the offending segment `zz`-prefixed in place, rather than gaining a leading `zz_`.

### Non-subcommand files

- **File name prefix**: leading `zz_`.

  Examples: `zz_helpers.go`, `zz_validation.go`.
- These files contain helpers, shared types — anything that is part of the `commands` package but is not a single subcommand definition.
- The file name has no other constraint beyond the `zz_` prefix.
- Do **not** use a leading `_`: `cmd/go` silently ignores files (and directories) whose names begin with `_` or `.`, so an `_logger.go` would never be compiled.

### Package name (`<name-without-separator>/`)

The top-level `<name-without-separator>/` is an importable Go package, so the **name part must follow Go convention: no hyphens (`-`), no underscores (`_`)** — the placeholder is spelled `-without-separator` to keep that rule in view.

Derive it from the project name by stripping those characters — `my-tool` → `mytool/` with `package mytool`.

This is the **only** place the name is sanitized: the binary directory `cmd/<name>/` (e.g. `cmd/my-tool/`), the `Use:` string, the env prefix, and the `os.UserConfigDir()/<name>/` path all keep the verbatim project name.

- In the templates, `{{NAME}}` resolves to this sanitized form wherever it appears as a **Go package identifier or inside the service import path** — `package {{NAME}}`, `{{NAME}}/version.go`, `import "{{MODULE}}/{{NAME}}"`, `{{NAME}}.Version`, `{{NAME}}.LoadConfig`.

  When the project name is already a valid identifier (the common case, e.g. `mytool`), the sanitized and verbatim forms coincide and there is nothing to strip.
- Because the directory name, the `package` clause, and the import path now all agree, the import needs **no alias**: write `import "{{MODULE}}/mytool"`, not `import mytool "{{MODULE}}/my-tool"`.
- In a legacy-layout project the same rules apply at `pkg/<name-without-separator>/` — keep the `pkg/` placement there (see [Anti-patterns › Layout & file placement](#anti-patterns)).

### Service method options (`<name-without-separator>`)

Exported service methods take their per-call options as a **single option struct named `<Method>Option`** — the method name plus the singular `Option` suffix.

- **Always emit the option struct.** A method's optional/tunable inputs go in one `<Method>Option` value parameter, placed after `ctx` and the required target arguments — not as a tail of positional parameters.

  `Serve` → `ServeOption`, `Fetch` → `FetchOption`, `DryRun` → `DryRunOption`.
- **The suffix is singular `Option`**, never `Options`, `Params`, `Config`, or an `Opt` abbreviation.

  (The service's layered `Config` is a different thing — process-wide configuration, not per-call options; see [configuration.md](configuration.md).)
- **Facade methods embed, never re-define.** When a method `XX` is merely a facade that calls other exported methods, `XXOption` does **not** re-declare fields for those callees.

  Instead it **embeds** each callee's option struct (`YYOption` for every exported `YY` the facade calls), plus only the fields the facade itself consumes.

  The facade then passes each embedded value through verbatim: `s.YY(ctx, target, opt.YYOption)`.

```go
type FetchOption struct {
	Depth int
	Force bool
}

func (s *Service) Fetch(ctx context.Context, repo string, opt FetchOption) error { /* ... */ }

type CheckoutOption struct {
	Branch string
}

func (s *Service) Checkout(ctx context.Context, repo string, opt CheckoutOption) error { /* ... */ }

// Sync is a facade over Fetch + Checkout: SyncOption embeds their option
// structs instead of re-declaring Depth / Force / Branch.
type SyncOption struct {
	FetchOption
	CheckoutOption
}

func (s *Service) Sync(ctx context.Context, repo string, opt SyncOption) error {
	if err := s.Fetch(ctx, repo, opt.FetchOption); err != nil {
		return err
	}
	return s.Checkout(ctx, repo, opt.CheckoutOption)
}
```

Why:

- The run functions under `./cmd` construct one literal per call; embedding keeps the facade's flag wiring in sync with the callees' options automatically.
- Adding a field to `FetchOption` reaches every facade that embeds it — no drift, no field-by-field copying inside the facade.

## Anti-patterns

Do not generate any of these — they look superficially shorter but break the layout contract.

Grouped by the part of the layout each one violates.

### Layout & file placement

- **`commands/` at the module root** (i.e. `<root>/commands/...` instead of `<root>/cmd/<name>/commands/...`). A second binary forces a rename of every import path.
- **Flattening a subdirectory-nested command tree — or splitting a flat one into directories — during any edit or re-scaffold.** Directory nesting under `commands/` is an allowed structure preference that must survive; migrate between the two shapes only on explicit user request.

  See [Subdirectory-nested subcommands](#subdirectory-nested-subcommands-allowed-variant).
- **`main.go` at the module root.** Same reason — entrypoint must live at `cmd/<name>/main.go`.
- **Helper packages under `cmd/<name>/commands/` or a separate `cmd/internal/` tree.** Every internal helper — `cmdsignals`, `stdiopipe`, `loggerfactory`, `versioninfo` — lives under the module-root `internal/`, reachable from both `./cmd` and `./<name-without-separator>` while blocked to external modules.

  The module-root `internal/` also holds build-time `main` packages such as `internal/cmd/release` that should not be `go install`-able by external modules. Do not reintroduce a `cmd/internal/` layer or scatter helpers beside the subcommand files.
- **Importing `{{MODULE}}/commands`** anywhere. The only correct import is `{{MODULE}}/cmd/<name>/commands`.
- **Re-implementing logger glue under `commands/`.** The logger config struct, the `--log` / `--log-level` flag callbacks, and `BuildLogger` MUST live in `<module-root>/internal/loggerfactory`.

  Do not copy them back into a `zz_logger.go` or any file under `commands/`, and do not relocate the package anywhere under `cmd/` — `<name-without-separator>` needs to import its `Level` constants, so it must stay at the module-root `internal/loggerfactory`.
- **Putting the release helper anywhere other than `internal/cmd/release/`.** Specifically: not `cmd/release/` (that would make it `go install`-able by external consumers) and not `scripts/` (no shell-script parity to maintain).
- **Generating `stdiopipe` speculatively.** Only when a concrete subcommand needs it.
- **Placing a new service package under `pkg/` in a top-level-layout project — or migrating a legacy `pkg/<name-without-separator>/` to the top level unprompted.** The service package lives at the module root (`./<name-without-separator>/`); `pkg/` is the legacy placement.

  Whichever shape a project already has must survive edits and re-scaffolding: new files follow the existing placement, and migration between the two happens only on explicit user request (same preserve rule as the subdirectory command variant).
- **Giving a utility binary a top-level service package.** Only a **main** functionality earns `./<other-without-separator>/`; a utility's service code goes under `internal/`.

  When it is not clear which kind a new entry point is, ask — see [Main vs utility entry points](#main-vs-utility-entry-points).
- **Generating `api/` speculatively, using `proto2`, or writing an unprefixed proto package path.** `api/` exists only when the project exposes a public RPC API; protobuf schemas are `proto3` managed with `buf` (`buf.yaml` under `./api`); proto package/service paths always carry the `<username>`/`<organizationname>` prefix — repo convention first, ask when there is none. See [Public RPC API](#public-rpc-api-api).

### Mandatory pieces — never skip these

- **Skipping `cmdsignals`.** Always generated for scaffold; `main.go` imports it.
- **Skipping `loggerfactory`.** Always generated for scaffold; `root.go` imports it for `--log` / `--log-level` wiring.
- **Skipping `versioninfo`.** Always generated for scaffold; `commands/version.go` imports it.
- **Skipping `internal/cmd/release`.** Always generated for scaffold; the release flow assumes it.

  The Go program intentionally replaces parallel bash + PowerShell scripts; do not re-introduce them.
- **Skipping `version.go` (either copy).** Both `<name-without-separator>/version.go` and `cmd/<name>/commands/version.go` are mandatory; `rootCmd()` wires `versionCmd(cmd)` unconditionally and the `--version` flag dispatches to `runVersion`.
- **Skipping the `config` subcommand.** `cmd/<name>/commands/config.go` is mandatory alongside `<name-without-separator>/config.go`; `rootCmd()` wires `configCmd(cmd, &flagConfig)` unconditionally.

  It prints `LoadConfig` as JSON, or renders `--format` against it — via `cli.RenderConfig` in `<name-without-separator>/cli`, using the `internal/templateutil` func map. All three files (`cmd` wiring, `cli/config.go`, `internal/templateutil`) are part of the mandatory set; see [configuration.md](configuration.md#cmdnamecommandsconfiggo-always-present).
- **Skipping `<name-without-separator>/config.go`.** Configuration is always present; every project carries it (even when `Config` starts with a single field).

### Naming

- **Non-subcommand files in `commands/` without the `zz_` prefix.** Anything that isn't a single subcommand definition (shared helpers, package-internal types) MUST be `zz_<name>.go`.

  **Never use a leading `_`** — `cmd/go` ignores files starting with `_` or `.`, so they would silently never compile.

- **Hyphens or underscores in the `<name-without-separator>` directory.** It is an importable package, so the name part must follow Go convention (which is what the placeholder's spelling stresses) — `mytool/`, never `my-tool/` or `my_tool/`.

  Strip those characters from the project name for the directory, the `package` clause, and the `{{MODULE}}/<name-without-separator>` import (they then agree, so no import alias is needed).

  The binary directory `cmd/<name>/` keeps the verbatim name. See [Naming conventions › Package name](#package-name-name-without-separator).

- **A leaf file name whose trailing `_`-segment is a GOOS / GOARCH / `test` token** (e.g. `foo_windows.go`, `db_linux_amd64.go`, `db_test.go`). Go gives it an implicit build constraint, so the subcommand silently drops out of builds on other platforms — green on your host, missing elsewhere.

  `zz`-prefix the offending trailing segment in the file name only (`foo_windows.go` → `foo_zzwindows.go`), keeping the command's real name. Do **not** mangle a non-trailing GOOS/GOARCH-named parent — `windows_sub.go` is fine as is. See [Build-constraint suffix collisions in leaf file names](#build-constraint-suffix-collisions-in-leaf-file-names).

### Command construction & wiring

- **Package-level `var xxxCmd = &cobra.Command{...}`** or any `init()` that calls `AddCommand`.

  All Cobra construction lives inside the wrapper function `{{name}}Cmd(parent)`; wiring happens via the parent calling its children's wrappers.
- **Pointer-returning flag APIs (`Flags().String(...)`, `Flags().Int(...)`)** at any scope. Always use the `*Var` family with a local declared in the wrapper's `var (...)` block.

  This keeps the binding shape uniform with `pflag.BoolFunc`.
- **Reading flags via `cmd.Flags().Get*`.** Use the captured flag variable from the wrapper's `var (...)` block; pass it into `run{{Name}}` via a `RunE` closure adapter when needed.

### Run functions & the `./cmd` boundary

- **Putting business logic inside `RunE`.** Business logic lives outside `./cmd`; `RunE` is wiring only — either a direct `run{{Name}}` reference or a thin closure adapter that forwards captured flag values.
- **Putting CLI-presentation code inside `RunE` or anywhere under `./cmd`.** Printing, prompts, table rendering, color, terminal capability detection, spinners — these live in `<root>/<name-without-separator>/cli/`.

  `RunE` calls into that package and returns its error.

- **Reading env vars under `./cmd`.** No `os.Getenv`, no `os.LookupEnv`, no manual scanning of `os.Environ()`.

  The only allowed env-var consumer reachable from `./cmd` is `loggerfactory.ReadEnv`, called from `root.go`'s `PersistentPreRun`; it owns the variable names.

  Every other env var lives in `./<name-without-separator>/config.go`.

### Service method options

- **Passing a service method's options as positional parameters** (a tail of `depth int, force bool, ...` after the target args). Per-call options go in a single struct named `<Method>Option` — see [Naming conventions › Service method options](#service-method-options-name-without-separator).
- **Naming the option struct anything other than `<Method>Option`.** Not `ServeOptions`, `ServeParams`, `ServeConfig`, `ServeOpt` — the singular `Option` suffix on the method name is the convention.
- **Re-declaring callee option fields in a facade's option struct.** When method `XX` merely calls other exported methods, `XXOption` must **embed** each callee's `YYOption` (passing it through as `opt.YYOption`), not copy its fields.

  Copied fields drift the moment a callee's option grows.

### Versioning

- **Hand-editing `const Version = "..."` outside a release.** Use `go run ./internal/cmd/release`; manual edits drift from the tag/commit pair the helper produces.
- **Renaming `Version` or switching it to `var`.** The required source shape is a single top-level `const Version = "..."`; the release helper relies on it.

  Update the helper in lockstep if you must diverge.

  There is no compelling reason to switch to `var` — `-ldflags=-X` is redundant under the rewrite-and-commit flow, and tests do not need to swap the value.

- **Adding imports to `<name-without-separator>/version.go`.** It must stay import-free so external consumers of `<name-without-separator>` are not forced to pull `internal/`.

  Anything richer (VCS info, runtime/debug glue) lives in `internal/versioninfo`.

- **Putting version printing under any other subcommand or in `main.go`.** Version output lives in `runVersion` only.

  The root `--version` flag is implemented as a closure dispatch into `runVersion`, not a copy.

- **Making `--version` persistent.** It is a local flag on the root command.

  `mytool serve --version` is intentionally an unknown-flag error; only `mytool --version` and `mytool version` print the version.

### Configuration model

- **Decoding the config file (or env) into a defaults-populated struct.** Decode into a **fresh zero `PartialConfig`** (all `nil`) and let `Apply` do the merge.

  Unmarshaling JSON into an already-populated struct hits the v1 `encoding/json` merge edge cases; keep `unmarshalConfigFile` decode-only.

- **Decoding the file straight into `Config`, or hand-rolling per-layer overlay code.** The file and env both decode/build into `PartialConfig` and merge through the one `Apply` method.

  Do not write separate `if x != "" { cfg.X = x }` overlay loops per layer — that is the duplicated, drift-prone ceremony `Apply` exists to replace.

  `Config` is materialized-only; nothing decodes into it.

- **Getting the merge kind wrong in `Apply`.** Scalars and slices **overwrite** (a non-nil incoming value replaces); nested structs and maps **deep-merge** (recurse / key-union).

  Do not element-wise-merge a slice, and do not blind-overwrite a nested sub-config or map (that silently clears the user's other keys).

  Allocate a fresh map when merging so `Apply` does not mutate its base.
- **Putting pointers on `Config` fields.** `Config` is the materialized type — value fields only; it always holds a concrete, fully-merged value.

  The present/absent distinction lives in `PartialConfig` (`*T`, `*PartialSub`, nil map/slice), never in `Config`.

  (Sole exception: a field the _service_ genuinely needs as three-state at runtime, with no sensible default.)

- **Letting `Config` and `PartialConfig` drift.** They mirror each other field-for-field with identical json tags (and each nested `Sub` / `PartialSub` pair likewise).

  Adding a field means touching both, plus the `Apply` line and the env read — see the add-a-field checklist in [configuration.md](configuration.md).

- **Using `,omitempty` on `PartialConfig`'s JSON tag.** The JSON tag uses `,omitzero` (Go 1.24+): `,omitempty` drops a non-nil empty slice/map on marshal — erasing the "present, overwrite with empty" signal — and an untagged field serializes every absent field as explicit `null`.

  `,omitzero` drops only true absence (nil) and keeps explicit zeros.

  (The YAML tag _must_ use `,omitempty` because YAML has no `omitzero`; that's an accepted limitation — JSON is the faithful medium for serializing a partial. `Config` itself takes no omit option on either tag, since the `config` subcommand prints the full resolved config.)
- **Giving config fields only one format's tags.** Every `Config` / `PartialConfig` field carries **both** `json:` and `yaml:` tags, even in a single-format project, so adopting or switching format never touches the field set.

  Omitting the `yaml:` tag makes a YAML key silently fall back to Go's field-name casing.

- **Loading and blending more than one config file.** There is exactly one config file per run.

  In _both_ mode, `configPath` returns the first existing of `config.yaml` → `config.yml` → `config.json` (YAML wins) and stops; do **not** read several and merge them.

  The layering is `defaults < (one) file < env < flags`, never `defaults < json-file < yaml-file`.

- **Binding service-config flags directly into `Config` (`&cfg.Field`).** That lets a flag's default clobber file/env values, inverting the `defaults < file < env < flags` order.

  Bind to locals and overlay only `cmd.Flags().Changed(...)` ones in the run function. (`loggerfactory` is the lone env-over-flags exception, and only for logger config.)

- **Hand-building the config path as `$HOME/.config/...`.** Use `os.UserConfigDir()` — it honors `$XDG_CONFIG_HOME` and is platform-native on macOS / Windows.

  Resolution order: `--config` flag, then `$<NAME>_CONF`, then `os.UserConfigDir()`.
