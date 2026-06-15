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
- **Positional-argument completion (`ValidArgsFunction`)**: fill `ValidArgsFunction` on a leaf command's literal to control shell completion of its positional args. The stub leaf templates ship this as a TODO — fill it to match `Args`. When the command takes no completable positional args (the `cobra.NoArgs` default), set `cobra.NoFileCompletions` so the shell does not fall back to file completion. When it does take them, assign a dynamic completion function, a static `ValidArgs` slice, or `cobra.FixedCompletions(...)`. `ValidArgs` and `ValidArgsFunction` are mutually exclusive — set at most one (Cobra reports an error when both are present).
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

Exception: when a flag must bind into an external configuration struct, pass the struct field's address to `*Var`. The local `var` form is the default. **Caveat:** the service's layered `Config` (see "Service package & configuration") is **not** such a struct — do not bind flags into it with `&cfg.Field`, or a flag's default value will clobber the file/env layers. Bind those to locals and overlay only the explicitly-set ones via `cmd.Flags().Changed(...)`.

## Project layout (canonical)

```
<module-root>/
├── go.mod
├── cmd/
│   ├── <name>/
│   │   ├── main.go
│   │   └── commands/
│   │       ├── root.go                  # rootCmd() + Execute(ctx) + runRoot
│   │       ├── version.go               # always present; "version" subcommand + --version alias
│   │       ├── config.go                # always present; "config" subcommand (prints resolved config)
│   │       ├── zz_<helper>.go           # any non-subcommand helper file (prefix zz_)
│   │       ├── <subcmd>.go              # one per flat leaf
│   │       ├── <parent>.go              # one per group (no RunE)
│   │       └── <parent>_<child>.go      # one per nested leaf
│   └── internal/
│       ├── cmdsignals/
│       │   └── signals.go               # always present
│       └── stdiopipe/                   # only when a subcommand needs cancellable stdio
│           └── stdiopipe.go
├── internal/
│   ├── cmd/
│   │   └── release/
│   │       └── main.go                  # always present; cross-platform release helper
│   ├── loggerfactory/
│   │   └── loggerfactory.go             # always present; --log / --log-level wiring
│   └── versioninfo/
│       └── versioninfo.go               # always present; ReadVersionInfo (Version + VCS info)
└── pkg/
    └── <name>/
        ├── version.go                   # always present; release-controlled `const Version`
        ├── config.go                    # always present; Config + DefaultConfig, PartialConfig + Apply, LoadConfig
        ├── <service>.go                 # internal service implementation
        └── cli/                         # CLI-presentation code (printing, prompts, tables, colors)
            └── <ui>.go
```

Why this shape:

- `cmd/<name>/` lets a future second binary be added as `cmd/<other>/` with no churn.
- `cmd/internal/` is a sibling of all binary packages, sharing helpers under Go's `internal/` rule.
- `internal/loggerfactory/` sits at the module-root `internal/` (not under `cmd/internal/`) so `pkg/<name>` code can import its level constants — notably `LevelTrace` and `LevelFatal` — and emit records at levels the CLI knows how to render. The module-root `internal/` placement keeps it reachable from both `./cmd` and `./pkg/<name>` while blocking external consumers. The flag wiring is still CLI-only; the package is shared because the level constants are shared.
- `pkg/<name>/` holds the actual service. `./cmd` is wiring only — flags, positional args, and (logger-only) env vars feed into a service constructed from `pkg/<name>`.
- `pkg/<name>/cli/` holds CLI-presentation code (printing, prompts, tables, colors, spinners). `RunE` calls into it and returns its error.
- The `zz_` prefix on non-subcommand files makes the file → subcommand mapping unambiguous: any file without `zz_` is a single subcommand definition. (`_` prefix is **not** usable — `cmd/go` ignores files starting with `_` or `.`.)
  - as per Go's file name rule, `<helper>` can not be `test`, `$GOARCH`(e.g. `amd64`, etc), `$GOOS`(e.g. `windows`, etc)
- `version.go` is split across **three** packages by design. `pkg/<name>/version.go` declares only `const Version`, kept import-free so external consumers of `pkg/<name>` don't drag in `internal/`. `internal/versioninfo/versioninfo.go` provides `ReadVersionInfo(version) Info` — the reusable VCS-info combiner consumed by the binary. `cmd/<name>/commands/version.go` is the thin CLI presentation layer that calls `versioninfo.ReadVersionInfo(<name>.Version)`. `version.go` is the one canonical-mapping leaf that does **not** need the `zz_` prefix because `version` is itself a real subcommand.
- `internal/cmd/release/` is a `main` package, not a runtime helper. It lives under `internal/` so it cannot be `go install`ed by external modules (it's a build-time tool of this module only). One Go source base replaces what would otherwise be parallel bash + PowerShell scripts.
- Never put `commands/` directly at the module root. See "Anti-patterns".

## Service package & configuration

The CLI binary is wiring; the service is `./pkg/<name>`. Configuration is **always present**: every project carries `pkg/<name>/config.go`. Inputs arrive from four layers, lowest to highest precedence:

> **defaults < config file < environment < flags**

Each layer overlays the previous one **field by field** through one primitive, `PartialConfig.Apply` — a config file that sets only some keys still inherits defaults for the rest; a present env var overrides the file; an explicitly-set flag wins over everything. Scalars and slices overwrite; nested structs and maps deep-merge (see "Merge semantics"). (`loggerfactory` is the one deliberate exception: for the _logger_ config only, it layers env _over_ flags.)

### Where each input is read

- **Env vars MUST NOT be read anywhere under `./cmd`** — no `os.Getenv`, no `os.LookupEnv`, no scanning `os.Environ()`. All env reads live in `pkg/<name>/config.go`, where `caarlos0/env` parses them into `PartialConfig` (plus the one hand-read `{{NAME_UPPER}}_CONF` path in `configPath`). The single delegated exception reachable from `./cmd` is `loggerfactory.ReadEnv`, called from `root.go`'s `PersistentPreRun`; it owns the logger variable names.
- **The config file is read only in `config.go`.**
- **Flags are bound in `./cmd`** (the wrapper's `var (...)` block) and overlaid onto the loaded config in the run function — see "Flag overlay" below.

### The four pieces in `config.go`

1. **`Config` + `DefaultConfig()`.** `Config` is the materialized struct the service consumes; it carries JSON tags so the `config` subcommand can marshal it. Its fields are **value** types — the merged config is always concrete. `DefaultConfig()` returns the lowest layer, with sub-configs and maps initialized so later layers deep-merge into a populated base. The config file is **not** decoded into `Config` — that is `PartialConfig`'s job.
2. **`PartialConfig` + `Apply` + `unmarshalConfigFile`.** `PartialConfig` is the **exported** sparse mirror of `Config`'s serialized shape (the same `json:`/`yaml:` keys, plus `env:`/`envPrefix:` for caarlos0/env) — every scalar a pointer, so `nil` means "key absent, leave the lower layer" and non-nil is an explicit value (including an explicit zero); nested sub-configs are _value_ `PartialXxx` structs. It is the decode target for the file **and** the struct `caarlos0/env` fills from the environment, so file and env merge through one method, `func (PartialConfig) Apply(base Config) Config`. `unmarshalConfigFile` decodes the file into a fresh **zero** `PartialConfig` (absent file → zero value; ENOENT is not an error; any other read or parse error aborts) and never merges — decoding into a zero value sidesteps the v1 `encoding/json` merge edge cases (the ones `encoding/json/v2` is designed to remove) that decoding into an already-populated struct hits.
3. **The env layer (via `github.com/caarlos0/env`).** `LoadConfig` fills the **same** `PartialConfig` from the environment by calling `env.ParseWithOptions` directly — no wrapper type: the variable names live in `PartialConfig`'s `env:` / `envPrefix:` tags, and the package-level `envOptions` (`env.Options{Prefix: "{{NAME_UPPER}}_"}`) applies the prefix. A field is set (non-nil) when its variable is present; absent ones stay nil. `caarlos0/env` parses slices/maps natively and recurses into the **value** nested sub-config. The error is non-nil only when a present value fails to parse — a hard error that aborts startup. `t.Setenv` + `LoadConfig` keeps it unit-testable. (The one var read by hand is the config-file path, `{{NAME_UPPER}}_CONF`, in `configPath` — it's needed before parsing and is not a `Config` field.)
4. **`LoadConfig`** — the synthesizer. `cfg := DefaultConfig()`, then `cfg = filePartial.Apply(cfg)`, then `cfg = envPartial.Apply(cfg)` — one overlay primitive for both layers. `./cmd` applies explicitly-set flags on top (flags win). Name it `LoadConfig` while it lives in `package {{NAME}}`; rename to `Load` if promoted to a `config` sub-package (`config.LoadConfig` would stutter).

### Merge semantics (`PartialConfig.Apply`)

`Apply` overlays the present (non-nil) fields of a `PartialConfig` onto a base `Config` and returns the result. Because every scalar in `PartialConfig` is a pointer, "present" is always distinguishable from "absent" — so an explicit zero (`false`, `0`, `""`) from a layer applies correctly, with **no per-field "is this zero-meaningful?" decision**: the uniform pointer mirror removes that judgment call entirely. The four field kinds merge differently:

| Field kind                                | Merge rule                                                                                                                                                                                                    |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scalar** (`string`, `int`, `bool`, ...) | **overwrite** — a non-nil `*T` replaces the base value, explicit zero included.                                                                                                                               |
| **Nested struct** (sub-config)            | **deep merge** — recurse into the sub-config's own `PartialXxx.Apply` (a _value_ field, always called); a zero sub-partial (all fields nil) merges nothing, so setting one nested key preserves its siblings. |
| **Map**                                   | **deep merge** — entries in the incoming map are added to / overwrite the same key in the base; keys present only in the base are kept. Allocate a fresh map so the base is not mutated.                      |
| **Slice / array**                         | **overwrite** — a non-nil incoming slice replaces the base wholesale (no element-wise merge); a nil slice means "absent" and leaves the base.                                                                 |

Why composites deep-merge but slices overwrite: a struct or map is a _bag of independently-set keys_ — a user setting one usually means "change this, keep the rest." A slice is a single ordered value — a partial overlay of half its elements is rarely meaningful, so an incoming slice replaces. (An explicit empty map `{}` decodes non-nil and merges nothing — a no-op, not a clear; an explicit empty slice `[]` decodes non-nil and replaces with empty.)

**Representation.** `Config` fields stay value types (the materialized config is always concrete after merging) and carry plain json/yaml tags — the `config` subcommand prints the _full_ resolved config, so nothing is omitted. `PartialConfig` mirrors each as: `*T` for a scalar, a **value** `PartialXxx` for a nested struct (with its own `Apply` — value, not pointer, so `caarlos0/env` recurses into it), and a plain `map`/slice for maps/slices — their nil zero already encodes "absent." Keep the structs' json/yaml/env tags in sync, and tag every `PartialConfig` field `,omitzero` on json (Go 1.24+) so a marshaled partial stays sparse while still preserving explicit empty `[]`/`{}` — `,omitzero`, not `,omitempty` (which would drop them; see anti-patterns).

**Why the mirror is universal, not an escalation.** Every project carries `PartialConfig`, even when no field is zero-meaningful. It earns that ubiquity by being the _single merge primitive_ shared across file, env, and nested deep-merge — not duplicated, hand-rolled overlay code at each layer. The cost is keeping `Config` and `PartialConfig` in lockstep (the add-a-field checklist lists every site); that one maintenance tax buys a uniform, correct, reusable merge path and removes the "should this field be a pointer?" judgment call from every future edit.

### Config file format (JSON, YAML, or both)

The config file may be **JSON** (the default) or **YAML**. The developer chooses per project: **JSON-only**, **YAML-only**, or **both** — a scaffold parameter. Whichever modes are supported, **every `Config` and `PartialConfig` field carries both a `json:` and a `yaml:` struct tag**, so the field set never changes when a project adopts or switches format.

- **JSON-only (default).** Decode with `encoding/json`; no extra dependency. Default file `config.json`.
- **YAML-only.** Decode with a library that honors `yaml:` tags — **`go.yaml.in/yaml/v4`** (recommended). It is the YAML-organization-maintained continuation of the de-facto-standard `gopkg.in/yaml.v3` (whose original repo is archived; the v1–v3 lines are now frozen, security-fixes only). It exports the familiar `yaml.Unmarshal` / `yaml.Marshal` (v3-compatible defaults) alongside a newer `Load`/`Dump` options API; the template uses `yaml.Unmarshal`, so adopting it is just the import path. Default file `config.yaml` (`.yml` accepted). Alternatives: `github.com/goccy/go-yaml` (a separate reimplementation with superior error messages and comment/anchor handling) is a drop-in for the `yaml.Unmarshal` call; the legacy `gopkg.in/yaml.v3` still works but is frozen — prefer `go.yaml.in/yaml/v3` if you want a stable-tagged release of that lineage today (see the recommendation note below). Do **not** use `sigs.k8s.io/yaml` — it reuses `json` tags, defeating the dual-tag requirement.

  > **Version note.** `go.yaml.in/yaml/v4` is at release-candidate (`v4.0.0-rc.x`) as of mid-2026 — `go get @latest` resolves to the RC, and the API may still settle before the final tag. Kubernetes and Prometheus have already migrated. If you want a stable-tagged dependency _now_, use `go.yaml.in/yaml/v3` (same lineage, identical `yaml.Unmarshal`; bump to v4 later is just the major-version path change) or `github.com/goccy/go-yaml`. The recommendation stands as **v4** because it is the actively-developed line; the others are fallbacks for conservatism.

- **Both (mixed).** Accept either; pick the decoder by file **extension** (`.yaml`/`.yml` → YAML, anything else → JSON).

**Format detection is by extension.** An explicit `--config <path>` (or `$<NAME>_CONF`) decodes as its extension dictates; an unrecognized or missing extension falls back to JSON.

**Precedence when both coexist — YAML wins, and exactly one file is ever loaded.** In _both_ mode, with no explicit path given, `configPath` probes the default dir in the order `config.yaml`, `config.yml`, `config.json` and returns the **first** that exists. If a project has both a YAML and a JSON file, the YAML one is used and the JSON one is ignored. **Never read both files and blend them** — the layering is `defaults < (one) file < env < flags`, not `defaults < json < yaml`. There is one config file per run.

### Config-file path resolution

`configPath` resolves the path in order: the `--config` flag value (`""` when unset), then `$<NAME>_CONF`, then — under `os.UserConfigDir()/<name>/` — the format probe above (`config.yaml` → `config.yml` → `config.json` in _both_ mode; the single matching filename in a single-format project). Use **`os.UserConfigDir`**, not a hand-built `$HOME/.config` — it already consults `$XDG_CONFIG_HOME` and is platform-native (`Library/Application Support` on macOS, `%AppData%` on Windows), and it returns an error when no config dir is resolvable — propagate it. `<NAME>` is the uppercased project name; `<name>` is the project name verbatim. Exposing `--config` is recommended but optional — pass `""` to `LoadConfig` to rely on `$<NAME>_CONF` / `os.UserConfigDir` alone.

### Flag overlay (the flags-win step, in `./cmd`)

Service-config flags are **not** bound directly into `Config` — that would let a flag's _default_ value clobber file/env. Bind them to locals (the default flag pattern) and, in the run function, overlay only the **explicitly-set** ones onto the loaded config. The flag layer is present-based — `cmd.Flags().Changed(name)` distinguishes set from unset directly, mirroring `PartialConfig`'s present-semantics; an explicit `--port 0` set by the user wins regardless. (Flags overlay onto scalar `Config` fields directly; they rarely target nested sub-configs, so a `PartialConfig` round-trip is unnecessary here — but you may build one and call `Apply` if a flag must feed a deep-merged field.)

```go
func runServe(cmd *cobra.Command, args []string, flagConfig, flagAddr string, flagPort int) error {
	cfg, err := {{NAME}}.LoadConfig(flagConfig) // flagConfig = persistent --config value
	if err != nil {
		return err
	}
	if cmd.Flags().Changed("addr") {
		cfg.Addr = flagAddr
	}
	if cmd.Flags().Changed("port") {
		cfg.Port = flagPort
	}
	// construct the service from cfg, then run it
	return nil
}
```

`--config` (the config-file path) is a **persistent flag on the root command**, declared once in `rootCmd()` and threaded to each config-loading run function as a `*string` parameter (the persistent-flag rule) — including the mandatory `config` subcommand, wired as `configCmd(cmd, &flagConfig)`. Implementors MAY rename it (e.g. `--conf`, `--config-file`) if `--config` would collide with a more-local flag name; keep the name consistent across the binary.

### Lint, growth, and adding a field

- **Env var names** live in `PartialConfig`'s `env:` / `envPrefix:` tags (bare names; the `{{NAME_UPPER}}_` prefix is applied via the package-level `envOptions`). There are no `SCREAMING_SNAKE` Go constants to trip naming lint — the only env-name identifier is the MixedCaps `envConfVar`, which needs no directive.
- **Long lines.** The triple-tagged `PartialConfig` fields (`json:` + `yaml:` + `env:` on one line) routinely exceed line-length linters (`lll`, `revive`'s `line-length-limit`). Keep one field per line — do **not** wrap tags across lines. Suppress the rule for the whole declaration with `//nolint:lll // triple json/yaml/env tags` on its own line directly above each `type Partial<Xxx> struct` (nested sub-partials included). The directive form (`//nolint:` with no space) is excluded from rendered godoc, so it doesn't pollute the doc comment.
- **Growth.** Start with one `config.go`. If configuration outgrows it (~300 LoC), promote it to a `pkg/<name>/config/` sub-package (`LoadConfig` → `config.Load`).
- **Adding a config field** touches: `Config` (+ json/yaml tags), `DefaultConfig`, `PartialConfig` (+ matching json/yaml tags **and** an `env:` tag to make it env-settable), and the field's line in `PartialConfig.Apply` (pick the rule for its kind — scalar / nested / map / slice); when flag-settable, also the flag binding and `Changed()` overlay in `./cmd`. A **nested sub-config** field additionally needs its own value `Partial<Sub>` type (with the `//nolint:lll` directive above it) + `Apply` method and an `envPrefix:` tag (its inner fields carry the `env:` tags). Env-settability is now just a tag — no loader code or constant to add. No "is this zero-meaningful?" decision is needed.

## Versioning

Every project carries a release-controlled version. Four pieces collaborate:

| Piece                            | Responsibility                                                                                                                                                                                       |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pkg/<name>/version.go`          | Source of truth for the version string. Declares `const Version = "v0.0.0-devel"` and **nothing else** — kept import-free so external consumers of `pkg/<name>` don't pull `internal/`.              |
| `internal/versioninfo`           | Reusable helper exporting `type Info` and `ReadVersionInfo(version string) Info`. Combines the supplied `Version` with VCS info from `runtime/debug.ReadBuildInfo`.                                  |
| `cmd/<name>/commands/version.go` | The `version` subcommand. Imports both `pkg/<name>` (for `Version`) and `internal/versioninfo` (for `ReadVersionInfo`); prints to `cmd.OutOrStdout()`. Wired by `rootCmd()` unconditionally.         |
| `cmd/<name>/commands/root.go`    | Declares `--version` as a local (not persistent) flag on the root command. The root's `RunE` closure dispatches to `runVersion` when the flag is set.                                                |
| `internal/cmd/release`           | Cross-platform Go `main` package. Rewrites `pkg/<name>/version.go`'s `Version` line, commits, tags, then bumps to the next `-devel` and commits again. Run with `go run ./internal/cmd/release ...`. |

Design notes:

- **`Version` is a `const`.** The release tool rewrites the source line, commits, and tags — that is the canonical mutation path, so build-time `-ldflags=-X` override would be redundant (and doesn't work on `const` anyway). Tests do not swap the value.
- **`pkg/<name>/version.go` has no imports.** Anything richer (VCS info, etc.) lives in `internal/versioninfo`. Keep `pkg/<name>` cleanly publishable.
- **`--version` is local, not persistent.** `mytool serve --version` is intentionally an unknown-flag error; only the root command exposes the alias.
- **`mytool --version` and `mytool version` produce identical output.** They share `runVersion`; the alias is implemented as a closure dispatch, not a duplicated command.
- **The `version` and `config` subcommands are the `commands/` files that import `pkg/<name>` directly** (`version` for `Version`, `config` for `Config` + `LoadConfig`). Other commands go through the service constructed in their wrappers / `runRoot`.
- **One Go source base, every host OS.** The release helper is a Go `main` package precisely so Linux, macOS, and Windows users do not have to maintain parallel bash + PowerShell scripts. Running it requires only the Go toolchain, which the project already needs.

### Release flow

`go run ./internal/cmd/release` automates the version dance. It is the canonical release entry point; do not re-introduce shell scripts in parallel.

Steps the tool performs:

1. Validate the requested release version (`vMAJOR.MINOR.PATCH[-suffix]`, must NOT end in `-devel`) and the next-dev version (must end in `-devel`). Both may carry an optional submodule path prefix — see "Submodule tags" below.
2. Auto-detect `<prefix>/pkg/*/version.go` (must match exactly one; override with `-file <path>`). The prefix is empty for root-module releases.
3. Refuse if the working tree is dirty or the release tag already exists.
4. Rewrite the `Version` line to the release version (bare, no prefix), commit, and create an annotated tag `<tag>`.
5. Rewrite the `Version` line to the next-dev version (bare, no prefix) and commit.
6. `git push` the branch, then `git push origin <tag>` to publish the new tag. The tool aborts if either push fails (e.g. missing upstream, network failure, remote rejection); fix and re-push manually since the commits and tag already exist locally.

Usage:

```sh
go run ./internal/cmd/release v0.2.0                # next dev defaults to v0.2.1-devel
go run ./internal/cmd/release v0.2.0 v0.3.0-devel   # explicit next dev (must end in -devel; the tool does NOT append it)
go run ./internal/cmd/release -file pkg/other/version.go v0.2.0
go run ./internal/cmd/release subpkg/v0.2.0         # Go submodule at ./subpkg/; tags as subpkg/v0.2.0
go run ./internal/cmd/release nested/dir/v0.2.0     # deeper submodule at ./nested/dir/
```

The default next-dev calculation bumps the patch component. If the release is a minor or major bump, pass the next-dev explicitly. The argument must already include the `-devel` suffix — the tool validates rather than appends so a typo can't silently produce an unexpected version.

#### Submodule tags

A Go repository can host multiple modules. Submodule versions are tagged with the directory as a prefix (`subpkg/v1.0.0`, `nested/dir/v1.0.0`); `go list -m <module>@<prefixed-tag>` is how Go resolves them. The release tool accepts these tags and applies a two-rule split:

- **Tag-shaped names** (`subpkg/v0.2.0`, `subpkg/v0.2.1-devel`) — the full prefixed string is the git tag, commit message, and `go push` reference.
- **File-shaped content** (`const Version = "v0.2.0"`) — only the bare version is written into `version.go`. The submodule's package doesn't know about the path prefix; only git tooling does.

Auto-detection of the version file follows the prefix: `subpkg/v0.2.0` ⇒ `subpkg/pkg/*/version.go`. The same `pkg/<name>/version.go` convention applies inside each submodule. If the submodule deviates from this layout, pass `-file <path>` explicitly.

`defaultNextDev` preserves the prefix: `subpkg/v0.2.0` ⇒ `subpkg/v0.2.1-devel`. The patch-bump rule and `-devel` suffix policy are otherwise unchanged.

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

### Package name (`pkg/<name>`)

`pkg/<name>` is an importable Go package, so the **name part must follow Go convention: no hyphens (`-`), no underscores (`_`)**. Derive it from the project name by stripping those characters — `my-tool` → `pkg/mytool/` with `package mytool`. This is the **only** place the name is sanitized: the binary directory `cmd/<name>/` (e.g. `cmd/my-tool/`), the `Use:` string, the env prefix, and the `os.UserConfigDir()/<name>/` path all keep the verbatim project name.

- In the templates, `{{NAME}}` resolves to this sanitized form wherever it appears as a **Go package identifier or inside a `pkg/…` import path** — `package {{NAME}}`, `pkg/{{NAME}}/version.go`, `import "{{MODULE}}/pkg/{{NAME}}"`, `{{NAME}}.Version`, `{{NAME}}.LoadConfig`. When the project name is already a valid identifier (the common case, e.g. `mytool`), the sanitized and verbatim forms coincide and there is nothing to strip.
- Because the directory name, the `package` clause, and the import path now all agree, the import needs **no alias**: write `import "{{MODULE}}/pkg/mytool"`, not `import mytool "{{MODULE}}/pkg/my-tool"`.

## Templates

These are templates. **Strictly follow** the order of elements. Do **NOT** reorder.

### `cmd/{{NAME}}/main.go`

`main.go` only handles signal wiring and process exit. It builds the root context with `cmdsignals.NotifyContext`, which subscribes to `ExitSignals` (`SIGINT` / `SIGTERM`) and returns a `blockOn` func, the cancellable `ctx`, and a `cancel(error)`. `blockOn` is what actually cancels `ctx` on a signal, so it runs in a goroutine via `sync.WaitGroup.Go` (Go 1.25+) for the duration of `Execute`; `cancel(nil)` + `wg.Wait()` then unwind it once `Execute` returns. Do **not** revert to the stdlib `signal.NotifyContext` — the helper's variant is what enables `Pause` / `Resume` (see "Helper catalog"). When a signal triggered the shutdown, `Execute` returns the bare `context.Canceled` sentinel; `main` recovers the real reason from `context.Cause(ctx)` as a `*cmdsignals.SignalReceivedError` (via `errors.AsType`, Go 1.26+) so the printed message names the signal instead of the opaque `context canceled`. The guard is `errors.Is(err, ctx.Err())`, **not** the bare `context.Canceled` sentinel: `context.Canceled` is a public value any code may return without this context being cancelled, whereas `ctx.Err()` is non-nil only when _this_ ctx was genuinely cancelled. It is checked **before** `cancel(nil)` — that cleanup call would otherwise set `ctx.Err()` itself and manufacture a false positive. The error is otherwise written unconditionally to stderr because logging is opt-in via `--log` / `--log-level`.

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sync"

	"{{MODULE}}/cmd/{{NAME}}/commands"
	"{{MODULE}}/cmd/internal/cmdsignals"
)

func main() {
	blockOn, ctx, cancel := cmdsignals.NotifyContext(context.Background())

	// blockOn watches ExitSignals and cancels ctx when one arrives; it must run
	// for signal propagation to work, so start it before Execute. cancel + Wait
	// tear the goroutine down afterwards — whether Execute returned on its own or
	// because a signal already cancelled ctx (cancel is a no-op in that case).
	var wg sync.WaitGroup
	wg.Go(blockOn)

	err := commands.Execute(ctx)

	// Recover the cancellation reason while ctx still reflects it. The guard is
	// errors.Is(err, ctx.Err()) — not the bare context.Canceled sentinel, which
	// any code may return without this ctx being cancelled — so it fires only
	// when *this* context was actually cancelled. Read it before cancel(nil)
	// below, or that cleanup call would set ctx.Err() and manufacture a false
	// positive. Execute surfaces only context.Canceled; the signal lives in the
	// cause as *SignalReceivedError.
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

The template treats a signal as an error (prints it, exits non-zero). That is just one policy: **callers may instead treat signal cancellation as a normal exit, per an application-specific decision** — e.g. a graceful shutdown where `SIGINT` / `SIGTERM` is the expected stop button. In that case, in the `errors.AsType` branch where `sigErr` is recovered, return cleanly (print nothing, or a terse notice, and skip `os.Exit(1)`) rather than falling through to the error report; some tools additionally map the signal to the conventional `128 + signum` exit code (`sigErr.Sig`). The recovery itself — `ctx.Err()` guard, cause via `context.Cause` — stays the same; only what `main` _does_ with `sigErr` changes.

### `cmd/{{NAME}}/commands/root.go`

Owns the root command and its `runRoot`. The root wrapper delegates persistent log-flag registration to the `loggerfactory` helper and installs a `PersistentPreRun` hook that builds the logger and injects it into `cmd.Context()`. There is **no** logger glue file under `commands/` — all of it lives in `{{MODULE}}/internal/loggerfactory`.

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

The TODO comments are markers for the implementor — leave them. The `versionCmd(cmd)` / `configCmd(cmd, &flagConfig)` calls, the `--version` flag, and the persistent `--config` flag are **not** TODOs; they are always-present wiring for the two mandatory subcommands — `version` (see "Versioning") and `config` (see "Service package & configuration"). `--config` is persistent so every config-loading subcommand shares one flag; its value is threaded into those wrappers as `&flagConfig`.

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
	// Do not put business logic here.
	return nil
}
```

Differences vs. flat:

- Parent group has no `RunE` / `Args`.
- Child file uses underscore between levels.
- Child wrapper concatenates: `serverStartCmd`.
- Child is wired from the **parent group's wrapper**, not from `rootCmd()`. 3-level follows the same pattern (`server_start_foo.go` is wired from inside `serverStartCmd`).

### `pkg/{{NAME}}/version.go` (always present)

Source of truth for the version string. Deliberately tiny: only the `const Version` declaration, no imports, so external consumers of `pkg/{{NAME}}` are not forced to pull `internal/`.

```go
// Package {{NAME}} implements the {{NAME}} service backing the binary of the
// same name.
package {{NAME}}

// Version is the human-readable version string. The release helper at
// internal/cmd/release rewrites this declaration when cutting a release,
// then bumps it to the next "-devel" version after tagging.
//
// Edit by hand only when the release helper is unavailable (e.g. cherry-pick
// of a release commit).
const Version = "v0.0.0-devel"
```

The contract with the release helper is a single top-level `const Version = "..."` line, identifier spelled `Version`. Anything that changes this shape (renaming the identifier, switching to `var`, multiple declarations, struct-wrapping) breaks the helper's rewrite; update the helper in lockstep if you must change the shape.

`pkg/{{NAME}}/version.go` should remain import-free. Combine the `Version` value with VCS info via `internal/versioninfo.ReadVersionInfo(Version)` from the call site (typically `cmd/{{NAME}}/commands/version.go`).

If the project name contains characters invalid in a Go identifier (e.g. `my-tool`), the `pkg/<name>` directory itself is the stripped, Go-convention form — `pkg/mytool/` with `package mytool` (see _Naming conventions › Package name_). Since the directory, the `package` clause, and the import path all agree, no alias is needed: `import "{{MODULE}}/pkg/mytool"` in `cmd/<name>/commands/version.go`.

### `pkg/{{NAME}}/config.go` (always present)

The service configuration. Assembles **defaults < file < env** through one overlay primitive, `PartialConfig.Apply`; the `./cmd` run function overlays explicitly-set flags on top (see "Service package & configuration" and "Merge semantics" for the rules). Replace the example fields with the real config. It is a **single** `config.go` — the env layer is just the package-level `envOptions` plus a direct `env.ParseWithOptions` call inside `LoadConfig`.

The example deliberately exercises all four merge kinds: a **scalar** (`Addr`, `Port`), a **nested sub-config** (`Server` — deep-merged; note its `TLS bool` defaults `true`, a zero-meaningful field the pointer mirror handles for free), a **map** (`Labels` — deep-merged by key), and a **slice** (`Hosts` — overwritten wholesale).

```go
package {{NAME}}

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/caarlos0/env/v11"
)

// Config is the materialized configuration the service consumes, after every
// layer (defaults < file < env < flags) is applied. Its fields are value types
// (the merged config is always concrete) and carry both json and yaml tags so the
// `config` subcommand can marshal it and a project can adopt either file format
// without touching fields. The file is NOT decoded into Config — PartialConfig is
// the decode target; Config only ever holds a fully-merged result.
type Config struct {
	Addr   string            `json:"addr" yaml:"addr"`
	Port   int               `json:"port" yaml:"port"`
	Server ServerConfig      `json:"server" yaml:"server"` // nested sub-config: deep-merged
	Labels map[string]string `json:"labels" yaml:"labels"` // map: deep-merged (key union)
	Hosts  []string          `json:"hosts" yaml:"hosts"`   // slice: overwritten wholesale
}

// ServerConfig is a sub-config. TLS defaults true, so its zero value (false) is a
// meaningful override — handled for free because PartialServerConfig.TLS is a
// pointer (nil = unset, &false = explicit off).
type ServerConfig struct {
	TLS     bool `json:"tls" yaml:"tls"`
	Timeout int  `json:"timeout" yaml:"timeout"`
}

// DefaultConfig is the lowest-precedence layer. Initialize maps and sub-configs
// here so later layers deep-merge into a populated base.
func DefaultConfig() Config {
	return Config{
		Addr:   "0.0.0.0",
		Port:   8080,
		Server: ServerConfig{TLS: true, Timeout: 30},
		Labels: map[string]string{"managed-by": "{{NAME}}"},
		Hosts:  nil,
	}
}

// PartialConfig is the exported sparse mirror of Config's serialized shape (the
// same keys): a nil/zero field means "absent, leave the lower layer"; a set field
// is an explicit value, including an explicit zero. It is the decode target for
// the config file (JSON or YAML) AND the struct LoadConfig fills via
// caarlos0/env, so file and env merge through one method, Apply. Exported so other
// code can build or inspect partial overrides.
//
// Carries three tag sets, kept in sync with Config field-for-field: json + yaml
// for the file decode, and env / envPrefix for caarlos0/env. Field kinds:
//   - scalar:        *T (nil = absent; *false / *0 = explicit zero). env:"NAME".
//   - nested struct: a VALUE PartialXxx (not a pointer) with its own Apply, and
//                    envPrefix:"NAME_". caarlos0/env recurses into value nested
//                    structs but leaves nil pointer-structs unset; a zero value
//                    sub-partial still means "nothing set" for the file too.
//   - map / slice:   plain map/slice (nil = absent). env:"NAME"; caarlos0/env
//                    parses "k:v,k2:v2" / "a,b,c" natively.
// The {{NAME_UPPER}}_ prefix is applied once via envOptions, so the tags hold
// only the bare names (ADDR -> {{NAME_UPPER}}_ADDR, SERVER_ + TLS -> ..._SERVER_TLS).
//
// JSON tags use ",omitzero" (Go 1.24+): when a PartialConfig is marshaled back out
// (e.g. to write a sparse override file or a diff), omitzero drops nil/absent
// fields but preserves an EXPLICIT zero — including a non-nil empty []/{}, which
// the merge rules treat as "present, set to empty". (Tags affect only marshaling,
// never decoding, so this is free on the load path.)
//
// YAML has no omitzero, so the yaml tags use ",omitempty" — which DOES drop a
// non-nil empty []/{} on marshal. Decoding is unaffected (the normal path); only a
// YAML round-trip of a partial loses the explicit-empty signal. Marshal partials
// to JSON when that distinction matters.
//
//nolint:lll // triple json/yaml/env tags; one field per line, never wrap tags
type PartialConfig struct {
	Addr   *string             `json:"addr,omitzero" yaml:"addr,omitempty" env:"ADDR"`
	Port   *int                `json:"port,omitzero" yaml:"port,omitempty" env:"PORT"`
	Server PartialServerConfig `json:"server,omitzero" yaml:"server,omitempty" envPrefix:"SERVER_"`
	Labels map[string]string   `json:"labels,omitzero" yaml:"labels,omitempty" env:"LABELS"`
	Hosts  []string            `json:"hosts,omitzero" yaml:"hosts,omitempty" env:"HOSTS"`
}

//nolint:lll // triple json/yaml/env tags; one field per line, never wrap tags
type PartialServerConfig struct {
	TLS     *bool `json:"tls,omitzero" yaml:"tls,omitempty" env:"TLS"`
	Timeout *int  `json:"timeout,omitzero" yaml:"timeout,omitempty" env:"TIMEOUT"`
}

// Apply overlays p's present fields onto base and returns the merged Config.
// Merge rules by field kind:
//   - scalar:        non-nil pointer overwrites (explicit zero included).
//   - nested struct: deep-merged via the sub-partial's Apply — always called; a
//                    zero sub-partial (all fields nil) merges nothing.
//   - map:           deep-merged key by key into a fresh map (incoming wins;
//                    base-only keys kept; base not mutated).
//   - slice/array:   non-nil incoming slice overwrites wholesale (nil = leave base).
func (p PartialConfig) Apply(base Config) Config {
	if p.Addr != nil {
		base.Addr = *p.Addr
	}
	if p.Port != nil {
		base.Port = *p.Port
	}
	base.Server = p.Server.Apply(base.Server)
	if p.Labels != nil {
		merged := make(map[string]string, len(base.Labels)+len(p.Labels))
		for k, v := range base.Labels {
			merged[k] = v
		}
		for k, v := range p.Labels {
			merged[k] = v
		}
		base.Labels = merged
	}
	if p.Hosts != nil {
		base.Hosts = p.Hosts
	}
	return base
}

func (p PartialServerConfig) Apply(base ServerConfig) ServerConfig {
	if p.TLS != nil {
		base.TLS = *p.TLS
	}
	if p.Timeout != nil {
		base.Timeout = *p.Timeout
	}
	return base
}

// envOptions configures caarlos0/env for the env layer in LoadConfig. The
// variable names live in the env: / envPrefix: tags on PartialConfig; the
// {{NAME_UPPER}}_ prefix is applied here, yielding {{NAME_UPPER}}_ADDR,
// {{NAME_UPPER}}_SERVER_TLS, {{NAME_UPPER}}_LABELS, etc.
var envOptions = env.Options{Prefix: "{{NAME_UPPER}}_"}

// LoadConfig assembles defaults < config file < environment through Apply. The
// ./cmd layer applies explicitly-set flags on top (flags win). flagPath is the
// --config value ("" when the flag is unset). Rename to config.Load in a sub-package.
//
// The env layer fills a PartialConfig with caarlos0/env: a scalar/slice/map is
// set (non-nil) only when its variable is present; absent ones stay nil so Apply
// leaves the lower layer untouched. caarlos0/env parses slices ("a,b,c") and
// maps ("k:v,k2:v2") natively, and recurses into the value nested sub-config via
// envPrefix. ParseWithOptions errors when a present value fails to parse (e.g. a
// non-numeric PORT) — a hard error that aborts startup. t.Setenv + LoadConfig
// keeps the layer unit-testable.
func LoadConfig(flagPath string) (Config, error) {
	cfg := DefaultConfig()

	path, err := configPath(flagPath)
	if err != nil {
		return cfg, err
	}
	filePartial, err := unmarshalConfigFile(path)
	if err != nil {
		return cfg, err
	}
	cfg = filePartial.Apply(cfg)

	var envPartial PartialConfig
	if err := env.ParseWithOptions(&envPartial, envOptions); err != nil {
		return cfg, err
	}
	cfg = envPartial.Apply(cfg)

	return cfg, nil
}

// unmarshalConfigFile only reads + decodes; it never merges. It decodes into a
// fresh zero PartialConfig (all nil) and returns the zero value when the file
// does not exist. A non-ENOENT read error or a JSON parse error aborts.
//
// Decoding into a zero value — never a defaults-populated struct — sidesteps the
// v1 encoding/json merge edge cases that decoding into a populated struct hits;
// Apply does the merge afterward.
func unmarshalConfigFile(path string) (PartialConfig, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return PartialConfig{}, nil
		}
		return PartialConfig{}, fmt.Errorf("read config %q: %w", path, err)
	}
	var p PartialConfig
	if err := json.Unmarshal(b, &p); err != nil {
		return PartialConfig{}, fmt.Errorf("parse config %q: %w", path, err)
	}
	return p, nil
}

// envConfVar names the config-file-path override. It is the one env var read by
// hand (the file path is needed before parsing, and is not a Config field); every
// other variable lives in PartialConfig's env tags. MixedCaps, so no naming-lint
// directive is needed.
const envConfVar = "{{NAME_UPPER}}_CONF"

// configPath resolves the file path: --config (flagPath), else $envConfVar, else
// os.UserConfigDir()/{{NAME}}/config.json.
func configPath(flagPath string) (string, error) {
	if flagPath != "" {
		return flagPath, nil
	}
	if p, ok := os.LookupEnv(envConfVar); ok {
		return p, nil
	}
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, "{{NAME}}", "config.json"), nil
}
```

- `Config` and `PartialConfig` mirror each other and carry the **same** json **and** yaml keys (`Config` is what the `config` subcommand marshals; `PartialConfig` is the file/env decode target). `PartialConfig` additionally carries `env:` / `envPrefix:` tags for caarlos0/env. Keep all of them — and each nested `Sub` / `PartialSub` pair — in sync. The json/yaml tags are present even in a JSON-only project, so adopting YAML later is an import + `configPath`/`unmarshalConfigFile` change, never a field change.
- This template is the **JSON-only** file default (no YAML dependency). For YAML-only or both-format projects, swap `unmarshalConfigFile`/`configPath` and `go.mod` per the "YAML support" block below. The env layer (caarlos0/env) is unchanged across all file formats.
- **caarlos0/env handles maps and slices from env natively** — `{{NAME_UPPER}}_LABELS=k:v,k2:v2` and `{{NAME_UPPER}}_HOSTS=a,b,c` (override the separators with `envSeparator` / `envKeyValSeparator` tags). A field with **no** `env`/`envPrefix` tag is simply not env-settable (file-only).
- **Nested sub-configs are VALUE structs, not pointers.** caarlos0/env populates a value nested struct (via `envPrefix`) but leaves a nil pointer-struct unset, so a pointer here would silently never read its env vars. The value form costs nothing: a zero sub-partial merges nothing in `Apply` and is omitted on marshal (`omitzero` drops a zero struct; YAML `omitempty` drops a struct whose public fields are all zero).
- **Apply is pure w.r.t. its base**: it returns a new `Config` and allocates a fresh map rather than mutating the base's map. That makes `PartialConfig` + `Apply` reusable outside `LoadConfig` (tests, programmatic overrides) without aliasing surprises.

#### YAML support (YAML-only or both formats)

The fields already carry `yaml:` tags. To accept YAML, add a YAML decoder and make `unmarshalConfigFile` pick by extension; for _both_ mode, make `configPath` probe YAML before JSON (YAML wins; one file only — never blended). Add the dependency with `go get go.yaml.in/yaml/v4@v4.0.0-rc.5` (pinned — v4 is pre-release; check for a newer rc/GA first) — or `go.yaml.in/yaml/v3` / `github.com/goccy/go-yaml`, for which the `yaml.Unmarshal` call is identical.

```go
import (
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"go.yaml.in/yaml/v4"
)

type fileFormat int

const (
	formatJSON fileFormat = iota
	formatYAML
)

// detectFormat picks a decoder from the file extension; anything that is not a
// known YAML extension decodes as JSON (the default).
func detectFormat(path string) fileFormat {
	switch strings.ToLower(filepath.Ext(path)) {
	case ".yaml", ".yml":
		return formatYAML
	default:
		return formatJSON
	}
}

// unmarshalConfigFile reads + decodes into a fresh zero PartialConfig, choosing
// the decoder by extension. Absent file -> zero value. Never merges.
func unmarshalConfigFile(path string) (PartialConfig, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return PartialConfig{}, nil
		}
		return PartialConfig{}, fmt.Errorf("read config %q: %w", path, err)
	}
	var p PartialConfig
	switch detectFormat(path) {
	case formatYAML:
		if err := yaml.Unmarshal(b, &p); err != nil {
			return PartialConfig{}, fmt.Errorf("parse config %q: %w", path, err)
		}
	default:
		if err := json.Unmarshal(b, &p); err != nil {
			return PartialConfig{}, fmt.Errorf("parse config %q: %w", path, err)
		}
	}
	return p, nil
}

// configPath (both mode): --config / $envConfVar win as explicit paths (format by
// extension); otherwise probe the default dir YAML-first and return the first that
// exists. YAML takes precedence over JSON; only that one file is loaded.
func configPath(flagPath string) (string, error) {
	if flagPath != "" {
		return flagPath, nil
	}
	if p, ok := os.LookupEnv(envConfVar); ok {
		return p, nil
	}
	dir, err := os.UserConfigDir()
	if err != nil {
		return "", err
	}
	base := filepath.Join(dir, "{{NAME}}")
	for _, name := range []string{"config.yaml", "config.yml", "config.json"} {
		p := filepath.Join(base, name)
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	return filepath.Join(base, "config.json"), nil // absent -> defaults
}
```

For **YAML-only**, drop the `encoding/json` branch (and import) and the `config.json` probe entry; decode with `yaml.Unmarshal` unconditionally and default the path to `config.yaml`. For **both**, keep the switch as shown.

### `internal/versioninfo/versioninfo.go` (always present)

Reusable, project-agnostic helper. Copied verbatim from `${SKILL-DIR}/helpers/internal/versioninfo/versioninfo.go`. Exposes `type Info` and `ReadVersionInfo(version string) Info`. The caller passes the project's `Version` constant; the helper layers VCS info from `runtime/debug.ReadBuildInfo` on top.

This file is **not** a template; copy it as-is. See "Helper catalog" for the full path.

### `internal/cmd/release/main.go` (always present)

Cross-platform release helper. Copied verbatim from `${SKILL-DIR}/helpers/internal/cmd/release/main.go`. A `main` package living under `internal/` so it cannot be `go install`ed externally — it's a build-time tool of this module only. Runs as `go run ./internal/cmd/release`.

This file is **not** a template; copy it as-is. The same source compiles on Linux, macOS, and Windows; that is the entire reason for picking a Go program over parallel shell + PowerShell scripts.

### `cmd/{{NAME}}/commands/version.go` (always present)

The `version` subcommand. Wired by `rootCmd()` unconditionally; also reachable via the `--version` alias on the root command. `runVersion` lives here so the root's `RunE` closure can dispatch to it.

```go
package commands

import (
	"github.com/spf13/cobra"

	"{{MODULE}}/internal/versioninfo"
	"{{MODULE}}/pkg/{{NAME}}"
)

func versionCmd(parent *cobra.Command) {
	cmd := &cobra.Command{
		Use:   "version",
		Short: "Print version information",
		Args:  cobra.NoArgs,
		RunE:  runVersion,
	}

	parent.AddCommand(cmd)
}

func runVersion(cmd *cobra.Command, args []string) error {
	info := versioninfo.ReadVersionInfo({{NAME}}.Version)
	cmd.Printf("version:     %s\n", info.Version)
	if info.Commit != "" {
		modified := ""
		if info.Modified {
			modified = " (modified)"
		}
		cmd.Printf("commit:      %s%s\n", info.Commit, modified)
	}
	if info.CommitTime != "" {
		cmd.Printf("commit time: %s\n", info.CommitTime)
	}
	if info.GoVersion != "" {
		cmd.Printf("go version:  %s\n", info.GoVersion)
	}
	return nil
}
```

Differences from a regular flat-leaf:

- File name (`version.go`) collides with the canonical `<sub>.go` mapping intentionally — `version` IS the canonical subcommand for that file.
- Wired by `rootCmd()` unconditionally; do **not** add a TODO around the `versionCmd(cmd)` call.
- Imports two packages: `pkg/{{NAME}}` for the `Version` var, and `internal/versioninfo` for the `ReadVersionInfo` helper. Together with `config.go` it is one of the two `commands/` files that import `pkg/{{NAME}}` directly.

### `cmd/{{NAME}}/commands/config.go` (always present)

The `config` subcommand — the runtime counterpart of the `version` subcommand. Wired by `rootCmd()` unconditionally via `configCmd(cmd, &flagConfig)`. It loads the configuration through the canonical `{{NAME}}.LoadConfig` (defaults < file < env) and prints it as indented JSON, or renders a Go `text/template` against the `Config` value when `--template`/`-t` is given. The file is selected by the root's **persistent `--config`** flag (threaded in as a `*string`; empty → default location).

```go
package commands

import (
	"encoding/json"
	"fmt"
	"text/template"

	"github.com/spf13/cobra"

	"{{MODULE}}/pkg/{{NAME}}"
)

func configCmd(parent *cobra.Command, flagConfig *string) {
	var flagTemplate string

	cmd := &cobra.Command{
		Use:   "config",
		Short: "Print the resolved configuration",
		Args:  cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runConfig(cmd, args, *flagConfig, flagTemplate)
		},
	}

	cmd.Flags().StringVarP(&flagTemplate, "template", "t", "", "Go text/template rendered against the config instead of JSON")

	parent.AddCommand(cmd)
}

func runConfig(cmd *cobra.Command, args []string, flagConfig, flagTemplate string) error {
	cfg, err := {{NAME}}.LoadConfig(flagConfig)
	if err != nil {
		return err
	}

	if flagTemplate != "" {
		tmpl, err := template.New("config").Parse(flagTemplate)
		if err != nil {
			return err
		}
		if err := tmpl.Execute(cmd.OutOrStdout(), cfg); err != nil {
			return err
		}
		fmt.Fprintln(cmd.OutOrStdout())
		return nil
	}

	b, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	cmd.Println(string(b))
	return nil
}
```

Notes:

- **Mandatory**, like `version`: `rootCmd()` calls `configCmd(cmd, &flagConfig)` unconditionally — no TODO around it. The subcommand owns only the local `--template` flag; the config-path flag is the root's **persistent `--config`**, threaded in as a `*string` (the persistent-flag rule — never read it with `cmd.Flags().Get*`).
- **Flag name.** `--config` is the canonical config-path flag name. Implementors MAY rename it (e.g. `--conf`, `--config-file`) when `--config` would collide with a more-local flag name on some subcommand; keep the chosen name consistent across the binary.
- **What it shows**: the `defaults < file < env` layers — _not_ a specific service command's flag overrides, which are applied per-command in that command's run function.
- **`--template`** renders against the `Config` value with Go `text/template`: e.g. `mytool config -t '{{.Port}}'` prints just the port; an empty template prints indented JSON (which is why `Config` carries JSON tags). The default output stays **JSON even in a YAML project** — it needs no extra dependency and is valid YAML; swap `json.MarshalIndent` for `yaml.Marshal` if you prefer YAML output.
- **Secrets**: if `Config` carries credentials, give it a `MarshalJSON` that redacts them (or omit those fields) — `config` prints to stdout.
- If the project name is not a valid Go identifier, the `pkg/<name>` directory is already its sanitized form (see _Naming conventions › Package name_), so the import needs no alias — `import "{{MODULE}}/pkg/mytool"`, matching `version.go`.

### `go.mod`

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

- **Go version**: latest major with `.0` (e.g. `go 1.26.0`). User may override with an explicit version.
- **Direct dependencies**: latest possible. Workflow: `go get <module>@latest` for each direct dep, then `go mod tidy`. (Plain `tidy` does not bump already-required modules.)
- **Check the current major version before `go get …@latest`.** Go's `@latest` is scoped to the major version in the import path — it will **not** cross a major boundary. `go get github.com/caarlos0/env@latest` resolves to the ancient v0/v1, not `…/env/v11`; you must request the `/vN` path explicitly (`…/env/v11@latest`). Before adopting or bumping any module, check pkg.go.dev / the repo for the current highest major and use that `/vN` path. (This is also why a stale local module cache can leave you on an old major without warning.)
- **`caarlos0/env` (core dependency)**: every project uses it for env parsing — current major is `/v11` (verify before bumping, per the rule above).
- **YAML dependency**: add `go.yaml.in/yaml/v4` only for YAML-only / both-format projects (`go.yaml.in/yaml/v3` or `github.com/goccy/go-yaml` are equivalent swaps for the `yaml.Unmarshal` call). A JSON-only project needs no YAML dependency. **`v4` is pre-release** (`v4.0.0-rc.5` as of mid-2026), so the template **pins** it — `go get go.yaml.in/yaml/v4@v4.0.0-rc.5`, not `@latest` (and check for a newer rc / the GA tag before pinning).

## Workflows

### Scaffold a new project

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

1. Resolve all parameters. **Derive the `pkg/<name>` package name now**: strip hyphens/underscores from the project name so the directory follows Go convention (`my-tool` → `pkg/mytool/`, `package mytool`) — see _Naming conventions › Package name_. `cmd/<name>/`, `Use:`, the env prefix, and the config-dir path keep the verbatim project name; only `pkg/<name>`, the `package` clause, and `{{MODULE}}/pkg/<name>` imports use the stripped form. When the project name is already a valid identifier they are identical.
2. Write `go.mod` (placeholder `v0.0.0` lines per the template, except the pinned `go.yaml.in/yaml/v4 v4.0.0-rc.5`).
3. Write `cmd/<name>/main.go`.
4. Write `cmd/<name>/commands/root.go` (the template already wires `versionCmd(cmd)` and the `--version` flag — leave that in place).
5. Write `pkg/<name>/version.go` (`pkg/{{NAME}}/version.go` template). The initial `Version` value is `v0.0.0-devel`.
6. Write `pkg/<name>/config.go` (`pkg/{{NAME}}/config.go` template). Fill in the real `Config` fields + `DefaultConfig`, the mirrored `PartialConfig` + `Apply` (one overlay line per field, by kind — scalar / nested / map / slice), and `LoadConfig` (env layer via caarlos0/env's `ParseWithOptions` + the package-level `envOptions`). Give every field `json:`, `yaml:`, and `env:` (or `envPrefix:` for a nested sub-config) tags. For the chosen **config file format**: JSON-only uses the template as-is; for `yaml`/`both`, apply the "YAML support" block (format-aware `unmarshalConfigFile`/`configPath` + the `go.yaml.in/yaml/v4` dep). Keep it one file.
7. Write `cmd/<name>/commands/version.go` (`cmd/{{NAME}}/commands/version.go` template).
8. Write `cmd/<name>/commands/config.go` (`cmd/{{NAME}}/commands/config.go` template). The root template already declares the persistent `--config` flag and wires `configCmd(cmd, &flagConfig)` beside `versionCmd(cmd)` — leave that in place.
9. Write one `cmd/<name>/commands/<subcmd>.go` per flat leaf. Then edit `root.go` to call `{{subCamel}}Cmd(cmd)` inside `rootCmd()` for each.
10. For nested commands, write the parent **before** child files. Wire the parent into `rootCmd()`. Then write children and add `{{parentCamel}}{{ChildPascal}}Cmd(cmd)` calls inside the parent's wrapper function.
11. Copy the verbatim helper packages into `<root>` by running `"${SKILL-DIR}/copy_helper.sh" <root>` (add `--stdiopipe` when a subcommand needs cancellable stdio). This copies the `cmdsignals`, `loggerfactory`, `versioninfo`, and `internal/cmd/release` packages — each package's source **and** tests — to their mirrored paths under `<root>`; `--stdiopipe` additionally copies `cmd/internal/stdiopipe`. No build-time edits are needed: the release helper auto-detects `pkg/*/version.go`.
12. For each direct dep in `go.mod`: `go get <module>@latest` — using the correct `/vN` major path (e.g. `github.com/caarlos0/env/v11@latest`; confirm the current major first, see Version policy). Exception: pin pre-release YAML with `go get go.yaml.in/yaml/v4@v4.0.0-rc.5` (or omit entirely for a JSON-only project).
13. `go mod tidy`.
14. Run the post-edit validation chain (see below).
15. Report the generated file list to the user.

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
| Move scope (persistent ↔ local)         | move both the `var` declaration and the binding call to the appropriate command's wrapper, and use `Flags()` vs `PersistentFlags()`. When a parent's persistent flag must reach a child's run func, pass `&flag` as an extra parameter to the child wrapper                                   |
| Mark required / hidden / deprecated     | call `cmd.MarkFlagRequired(name)` / `cmd.Flags().MarkHidden(name)` / `cmd.Flags().MarkDeprecated(name, "msg")` inside the wrapper, after binding the flag                                                                                                                                     |

#### Command metadata

`Use`, `Short`, `Long`, `Example`, `Aliases`, `Annotations`, `SuggestFor`, `Hidden`, `Deprecated` — edit the `cobra.Command` literal inside the wrapper.

`PreRunE`, `PostRunE`, `PersistentPreRunE`, `PersistentPostRunE` — set on the `cobra.Command` literal; assign a named function (`preRun{{Name}}`, `postRun{{Name}}`) defined in the same file. Use a closure adapter to forward captured flag values when needed, mirroring the `RunE` rule.

#### Completion

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

The release helper auto-detects `pkg/*/version.go` and refuses on a dirty tree or duplicate tag. It pushes the branch and the new tag to `origin` on success; if either push fails it aborts and leaves the local commits + tag in place for manual re-push. See the Versioning section for the contract it expects.

### Templates (filled per project; not copied verbatim)

| Template                           | Destination                             | Purpose                                                                                                                                                                                                                                                                                                                                                                               |
| ---------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pkg/{{NAME}}/version.go`          | `<root>/pkg/<name>/version.go`          | Declares `const Version`. Rewritten by `internal/cmd/release`. No imports.                                                                                                                                                                                                                                                                                                            |
| `pkg/{{NAME}}/config.go`           | `<root>/pkg/<name>/config.go`           | `Config` + `DefaultConfig`, the exported `PartialConfig` + `Apply` (the single overlay primitive), isolated `unmarshalConfigFile`, and `LoadConfig` (defaults < file < env; env layer via caarlos0/env + `envOptions`). Triple `json:`+`yaml:`+`env:` tags; file format JSON-only / YAML-only / both (YAML wins, one file). Scalars/slices overwrite; nested structs/maps deep-merge. |
| `cmd/{{NAME}}/commands/version.go` | `<root>/cmd/<name>/commands/version.go` | The `version` subcommand and `runVersion`. Wired unconditionally by `rootCmd()`; alias of `--version`.                                                                                                                                                                                                                                                                                |
| `cmd/{{NAME}}/commands/config.go`  | `<root>/cmd/<name>/commands/config.go`  | The `config` subcommand and `runConfig`. Wired unconditionally by `rootCmd()`; prints `LoadConfig` as JSON, or via a `--template`.                                                                                                                                                                                                                                                    |

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
- **CLI-only helpers under module-root `internal/`.** `cmdsignals` and `stdiopipe` go at `cmd/internal/`, not `<root>/internal/`. The module-root `internal/` is reserved for two cases: (a) library packages shared between `./cmd` and `./pkg/<name>` — `loggerfactory` (whose `Level*` constants are imported from `pkg/<name>`) and `versioninfo` (consumed by `commands/version.go`); and (b) build-time `main` packages such as `internal/cmd/release` that should not be `go install`-able by external modules.
- **Importing `{{MODULE}}/commands`** anywhere. The only correct import is `{{MODULE}}/cmd/<name>/commands`.
- **Skipping `cmdsignals`.** Always generated for scaffold; `main.go` imports it.
- **Skipping `loggerfactory`.** Always generated for scaffold; `root.go` imports it for `--log` / `--log-level` wiring.
- **Skipping `versioninfo`.** Always generated for scaffold; `commands/version.go` imports it.
- **Skipping `internal/cmd/release`.** Always generated for scaffold; the release flow assumes it. The Go program intentionally replaces parallel bash + PowerShell scripts; do not re-introduce them.
- **Skipping `version.go` (either copy).** Both `pkg/<name>/version.go` and `cmd/<name>/commands/version.go` are mandatory; `rootCmd()` wires `versionCmd(cmd)` unconditionally and the `--version` flag dispatches to `runVersion`.
- **Skipping the `config` subcommand.** `cmd/<name>/commands/config.go` is mandatory alongside `pkg/<name>/config.go`; `rootCmd()` wires `configCmd(cmd, &flagConfig)` unconditionally. It prints `LoadConfig`'s result as JSON, or renders `--template` against it.
- **Hand-editing `const Version = "..."` outside a release.** Use `go run ./internal/cmd/release`; manual edits drift from the tag/commit pair the helper produces.
- **Renaming `Version` or switching it to `var`.** The required source shape is a single top-level `const Version = "..."`; the release helper relies on it. Update the helper in lockstep if you must diverge. There is no compelling reason to switch to `var` — `-ldflags=-X` is redundant under the rewrite-and-commit flow, and tests do not need to swap the value.
- **Adding imports to `pkg/<name>/version.go`.** It must stay import-free so external consumers of `pkg/<name>` are not forced to pull `internal/`. Anything richer (VCS info, runtime/debug glue) lives in `internal/versioninfo`.
- **Putting version printing under any other subcommand or in `main.go`.** Version output lives in `runVersion` only. The root `--version` flag is implemented as a closure dispatch into `runVersion`, not a copy.
- **Making `--version` persistent.** It is a local flag on the root command. `mytool serve --version` is intentionally an unknown-flag error; only `mytool --version` and `mytool version` print the version.
- **Putting the release helper anywhere other than `internal/cmd/release/`.** Specifically: not `cmd/release/` (that would make it `go install`-able by external consumers) and not `scripts/` (no shell-script parity to maintain).
- **Re-implementing logger glue under `commands/`.** The logger config struct, the `--log` / `--log-level` flag callbacks, and `BuildLogger` MUST live in `<module-root>/internal/loggerfactory`. Do not copy them back into a `zz_logger.go` or any file under `commands/`, and do not relocate the package under `cmd/internal/` — `pkg/<name>` needs to import its `Level` constants.
- **Generating `stdiopipe` speculatively.** Only when a concrete subcommand needs it.
- **Package-level `var xxxCmd = &cobra.Command{...}`** or any `init()` that calls `AddCommand`. All Cobra construction lives inside the wrapper function `{{name}}Cmd(parent)`; wiring happens via the parent calling its children's wrappers.
- **Pointer-returning flag APIs (`Flags().String(...)`, `Flags().Int(...)`)** at any scope. Always use the `*Var` family with a local declared in the wrapper's `var (...)` block. This keeps the binding shape uniform with `pflag.BoolFunc`.
- **Reading flags via `cmd.Flags().Get*`.** Use the captured flag variable from the wrapper's `var (...)` block; pass it into `run{{Name}}` via a `RunE` closure adapter when needed.
- **Non-subcommand files in `commands/` without the `zz_` prefix.** Anything that isn't a single subcommand definition (shared helpers, package-internal types) MUST be `zz_<name>.go`. **Never use a leading `_`** — `cmd/go` ignores files starting with `_` or `.`, so they would silently never compile.
- **Putting business logic inside `RunE`.** Business logic lives outside `./cmd`; `RunE` is wiring only — either a direct `run{{Name}}` reference or a thin closure adapter that forwards captured flag values.
- **Putting CLI-presentation code inside `RunE` or anywhere under `./cmd`.** Printing, prompts, table rendering, color, terminal capability detection, spinners — these live in `<root>/pkg/<name>/cli/`. `RunE` calls into that package and returns its error.
- **Reading env vars under `./cmd`.** No `os.Getenv`, no `os.LookupEnv`, no manual scanning of `os.Environ()`. The only allowed env-var consumer reachable from `./cmd` is `loggerfactory.ReadEnv`, called from `root.go`'s `PersistentPreRun`; it owns the variable names. Every other env var lives in `./pkg/<name>/config.go`.
- **Skipping `pkg/<name>/config.go`.** Configuration is always present; every project carries it (even when `Config` starts with a single field).
- **Hyphens or underscores in the `pkg/<name>` directory.** It is an importable package, so the name part must follow Go convention — `pkg/mytool/`, never `pkg/my-tool/` or `pkg/my_tool/`. Strip those characters from the project name for the directory, the `package` clause, and the `{{MODULE}}/pkg/<name>` import (they then agree, so no import alias is needed). The binary directory `cmd/<name>/` keeps the verbatim name. See _Naming conventions › Package name_.
- **Decoding the config file (or env) into a defaults-populated struct.** Decode into a **fresh zero `PartialConfig`** (all `nil`) and let `Apply` do the merge. Unmarshaling JSON into an already-populated struct hits the v1 `encoding/json` merge edge cases; keep `unmarshalConfigFile` decode-only.
- **Decoding the file straight into `Config`, or hand-rolling per-layer overlay code.** The file and env both decode/build into `PartialConfig` and merge through the one `Apply` method. Do not write separate `if x != "" { cfg.X = x }` overlay loops per layer — that is the duplicated, drift-prone ceremony `Apply` exists to replace. `Config` is materialized-only; nothing decodes into it.
- **Getting the merge kind wrong in `Apply`.** Scalars and slices **overwrite** (a non-nil incoming value replaces); nested structs and maps **deep-merge** (recurse / key-union). Do not element-wise-merge a slice, and do not blind-overwrite a nested sub-config or map (that silently clears the user's other keys). Allocate a fresh map when merging so `Apply` does not mutate its base.
- **Putting pointers on `Config` fields.** `Config` is the materialized type — value fields only; it always holds a concrete, fully-merged value. The present/absent distinction lives in `PartialConfig` (`*T`, `*PartialSub`, nil map/slice), never in `Config`. (Sole exception: a field the _service_ genuinely needs as three-state at runtime, with no sensible default.)
- **Letting `Config` and `PartialConfig` drift.** They mirror each other field-for-field with identical json tags (and each nested `Sub` / `PartialSub` pair likewise). Adding a field means touching both, plus the `Apply` line and the env read — see the add-a-field checklist.
- **Using `,omitempty` on `PartialConfig`'s JSON tag.** The JSON tag uses `,omitzero` (Go 1.24+): `,omitempty` drops a non-nil empty slice/map on marshal — erasing the "present, overwrite with empty" signal — and an untagged field serializes every absent field as explicit `null`. `,omitzero` drops only true absence (nil) and keeps explicit zeros. (The YAML tag _must_ use `,omitempty` because YAML has no `omitzero`; that's an accepted limitation — JSON is the faithful medium for serializing a partial. `Config` itself takes no omit option on either tag, since the `config` subcommand prints the full resolved config.)
- **Giving config fields only one format's tags.** Every `Config` / `PartialConfig` field carries **both** `json:` and `yaml:` tags, even in a single-format project, so adopting or switching format never touches the field set. Omitting the `yaml:` tag makes a YAML key silently fall back to Go's field-name casing.
- **Loading and blending more than one config file.** There is exactly one config file per run. In _both_ mode, `configPath` returns the first existing of `config.yaml` → `config.yml` → `config.json` (YAML wins) and stops; do **not** read several and merge them. The layering is `defaults < (one) file < env < flags`, never `defaults < json-file < yaml-file`.
- **Binding service-config flags directly into `Config` (`&cfg.Field`).** That lets a flag's default clobber file/env values, inverting the `defaults < file < env < flags` order. Bind to locals and overlay only `cmd.Flags().Changed(...)` ones in the run function. (`loggerfactory` is the lone env-over-flags exception, and only for logger config.)
- **Hand-building the config path as `$HOME/.config/...`.** Use `os.UserConfigDir()` — it honors `$XDG_CONFIG_HOME` and is platform-native on macOS / Windows. Resolution order: `--config` flag, then `$<NAME>_CONF`, then `os.UserConfigDir()`.

## Out of scope

- Migrating non-canonical projects to the canonical layout (skill detects + asks; user drives migration).
- Frameworks other than `spf13/cobra`.
- `cobra-cli` code generation.
- AST-based rewriting (`go/ast`, `dst`); plain `Edit` / `Write` only.
