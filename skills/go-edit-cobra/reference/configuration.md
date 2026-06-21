# Service configuration (model & `config` subcommand)

How configuration is layered, merged, and resolved — the design that the `pkg/<name>/config.go` source (see [config-source.md](config-source.md)) implements — plus the always-present `config` subcommand that prints the resolved result.

## Contents

- [Layers & where each input is read](#service-package--configuration)
- [The four pieces in config.go](#the-four-pieces-in-configgo)
- [Merge semantics (`PartialConfig.Apply`)](#merge-semantics-partialconfigapply)
- [Config file format (JSON, YAML, or both)](#config-file-format-json-yaml-or-both)
- [Config-file path resolution](#config-file-path-resolution)
- [Flag overlay (the flags-win step, in `./cmd`)](#flag-overlay-the-flags-win-step-in-cmd)
- [Lint, growth, and adding a field](#lint-growth-and-adding-a-field)
- [The `config` subcommand: `cmd` wiring + `pkg/{{NAME}}/cli` + `templateutil`](#cmdnamecommandsconfiggo-always-present)

## Service package & configuration

The CLI binary is wiring; the service is `./pkg/<name>`.

Configuration is **always present**: every project carries `pkg/<name>/config.go`.

Inputs arrive from four layers, lowest to highest precedence:

> **defaults < config file < environment < flags**

Each layer overlays the previous one **field by field** through one primitive, `PartialConfig.Apply` — a config file that sets only some keys still inherits defaults for the rest; a present env var overrides the file; an explicitly-set flag wins over everything.

Scalars and slices overwrite; nested structs and maps deep-merge (see [Merge semantics](#merge-semantics-partialconfigapply)).

(`loggerfactory` is the one deliberate exception: for the _logger_ config only, it layers env _over_ flags.)

### Where each input is read

- **Env vars MUST NOT be read anywhere under `./cmd`** — no `os.Getenv`, no `os.LookupEnv`, no scanning `os.Environ()`.

  All env reads live in `pkg/<name>/config.go`, where `caarlos0/env` parses them into `PartialConfig` (plus the one hand-read `{{NAME_UPPER}}_CONF` path in `configPath`).

  The single delegated exception reachable from `./cmd` is `loggerfactory.ReadEnv`, called from `root.go`'s `PersistentPreRun`; it owns the logger variable names.

- **The config file is read only in `config.go`.**
- **Flags are bound in `./cmd`** (the wrapper's `var (...)` block) and overlaid onto the loaded config in the run function — see [Flag overlay](#flag-overlay-the-flags-win-step-in-cmd) below.

### The four pieces in `config.go`

1. **`Config` + `DefaultConfig()`.** `Config` is the materialized struct the service consumes; it carries JSON tags so the `config` subcommand can marshal it.

   Its fields are **value** types — the merged config is always concrete.

   `DefaultConfig()` returns the lowest layer, with sub-configs and maps initialized so later layers deep-merge into a populated base.

   The config file is **not** decoded into `Config` — that is `PartialConfig`'s job.

2. **`PartialConfig` + `Apply` + `unmarshalConfigFile`.** `PartialConfig` is the **exported** sparse mirror of `Config`'s serialized shape (the same `json:`/`yaml:` keys, plus `env:`/`envPrefix:` for caarlos0/env) — every scalar a pointer, so `nil` means "key absent, leave the lower layer" and non-nil is an explicit value (including an explicit zero); nested sub-configs are _value_ `PartialXxx` structs.

   It is the decode target for the file **and** the struct `caarlos0/env` fills from the environment, so file and env merge through one method, `func (PartialConfig) Apply(base Config) Config`.

   `unmarshalConfigFile` decodes the file into a fresh **zero** `PartialConfig` (absent file → zero value; ENOENT is not an error; any other read or parse error aborts) and never merges — decoding into a zero value sidesteps the v1 `encoding/json` merge edge cases (the ones `encoding/json/v2` is designed to remove) that decoding into an already-populated struct hits.

3. **The env layer (via `github.com/caarlos0/env`).** `LoadConfig` fills the **same** `PartialConfig` from the environment by calling `env.ParseWithOptions` directly — no wrapper type: the variable names live in `PartialConfig`'s `env:` / `envPrefix:` tags, and the package-level `envOptions` (`env.Options{Prefix: "{{NAME_UPPER}}_"}`) applies the prefix.

   A field is set (non-nil) when its variable is present; absent ones stay nil.

   `caarlos0/env` parses slices/maps natively and recurses into the **value** nested sub-config.

   The error is non-nil only when a present value fails to parse — a hard error that aborts startup.

   `t.Setenv` + `LoadConfig` keeps it unit-testable.

   (The one var read by hand is the config-file path, `{{NAME_UPPER}}_CONF`, in `configPath` — it's needed before parsing and is not a `Config` field.)

4. **`LoadConfig`** — the synthesizer. `cfg := DefaultConfig()`, then `cfg = filePartial.Apply(cfg)`, then `cfg = envPartial.Apply(cfg)` — one overlay primitive for both layers.

   `./cmd` applies explicitly-set flags on top (flags win).

   Name it `LoadConfig` while it lives in `package {{NAME}}`; rename to `Load` if promoted to a `config` sub-package (`config.LoadConfig` would stutter).

### Merge semantics (`PartialConfig.Apply`)

`Apply` overlays the present (non-nil) fields of a `PartialConfig` onto a base `Config` and returns the result.

Because every scalar in `PartialConfig` is a pointer, "present" is always distinguishable from "absent" — so an explicit zero (`false`, `0`, `""`) from a layer applies correctly, with **no per-field "is this zero-meaningful?" decision**: the uniform pointer mirror removes that judgment call entirely.

The four field kinds merge differently:

| Field kind                                | Merge rule                                                                                                                                                                                                    |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Scalar** (`string`, `int`, `bool`, ...) | **overwrite** — a non-nil `*T` replaces the base value, explicit zero included.                                                                                                                               |
| **Nested struct** (sub-config)            | **deep merge** — recurse into the sub-config's own `PartialXxx.Apply` (a _value_ field, always called); a zero sub-partial (all fields nil) merges nothing, so setting one nested key preserves its siblings. |
| **Map**                                   | **deep merge** — entries in the incoming map are added to / overwrite the same key in the base; keys present only in the base are kept. Allocate a fresh map so the base is not mutated.                      |
| **Slice / array**                         | **overwrite** — a non-nil incoming slice replaces the base wholesale (no element-wise merge); a nil slice means "absent" and leaves the base.                                                                 |

Why composites deep-merge but slices overwrite: a struct or map is a _bag of independently-set keys_ — a user setting one usually means "change this, keep the rest."

A slice is a single ordered value — a partial overlay of half its elements is rarely meaningful, so an incoming slice replaces.

(An explicit empty map `{}` decodes non-nil and merges nothing — a no-op, not a clear; an explicit empty slice `[]` decodes non-nil and replaces with empty.)

**Representation.** `Config` fields stay value types (the materialized config is always concrete after merging) and carry plain json/yaml tags — the `config` subcommand prints the _full_ resolved config, so nothing is omitted.

`PartialConfig` mirrors each as: `*T` for a scalar, a **value** `PartialXxx` for a nested struct (with its own `Apply` — value, not pointer, so `caarlos0/env` recurses into it), and a plain `map`/slice for maps/slices — their nil zero already encodes "absent."

Keep the structs' json/yaml/env tags in sync, and tag every `PartialConfig` field `,omitzero` on json (Go 1.24+) so a marshaled partial stays sparse while still preserving explicit empty `[]`/`{}` — `,omitzero`, not `,omitempty` (which would drop them; see [Anti-patterns](layout-and-naming.md#anti-patterns)).

**Why the mirror is universal, not an escalation.** Every project carries `PartialConfig`, even when no field is zero-meaningful.

It earns that ubiquity by being the _single merge primitive_ shared across file, env, and nested deep-merge — not duplicated, hand-rolled overlay code at each layer.

The cost is keeping `Config` and `PartialConfig` in lockstep (the add-a-field checklist lists every site); that one maintenance tax buys a uniform, correct, reusable merge path and removes the "should this field be a pointer?" judgment call from every future edit.

### Config file format (JSON, YAML, or both)

The config file may be **JSON** (the default) or **YAML**.

The developer chooses per project: **JSON-only**, **YAML-only**, or **both** — a scaffold parameter.

Whichever modes are supported, **every `Config` and `PartialConfig` field carries both a `json:` and a `yaml:` struct tag**, so the field set never changes when a project adopts or switches format.

**Key naming: use `snake_case`.** Spell multi-word serialized keys in `snake_case` (`max_conns`, `read_timeout`) — **not** `camelCase` or `PascalCase` — in **both** the `json:` and `yaml:` tags, and keep the two values identical.

snake_case is the idiomatic spelling in YAML and in TOML (a project may adopt either format, now or later), so a single spelling reads consistently across every format the config might be written in, and it maps cleanly onto the `SCREAMING_SNAKE` env names (`max_conns` → `MAX_CONNS`).

Single-word keys (`addr`, `port`) are plain lowercase, which is already snake_case — the example fields are all single-word for that reason.

The Go field identifier stays MixedCaps as the language requires (`MaxConns`); only the tag value is snake_case.

- **JSON-only (default).** Decode with `encoding/json`; no extra dependency.

  Default file `config.json`.

- **YAML-only.** Decode with a library that honors `yaml:` tags — **`go.yaml.in/yaml/v4`** (recommended).

  It is the YAML-organization-maintained continuation of the de-facto-standard `gopkg.in/yaml.v3` (whose original repo is archived; the v1–v3 lines are now frozen, security-fixes only).

  It exports the familiar `yaml.Unmarshal` / `yaml.Marshal` (v3-compatible defaults) alongside a newer `Load`/`Dump` options API; the template uses `yaml.Unmarshal`, so adopting it is just the import path.

  Default file `config.yaml` (`.yml` accepted).

  Alternatives: `github.com/goccy/go-yaml` (a separate reimplementation with superior error messages and comment/anchor handling) is a drop-in for the `yaml.Unmarshal` call; the legacy `gopkg.in/yaml.v3` still works but is frozen — prefer `go.yaml.in/yaml/v3` if you want a stable-tagged release of that lineage today (see the recommendation note below).

  Do **not** use `sigs.k8s.io/yaml` — it reuses `json` tags, defeating the dual-tag requirement.

  > **Version note.** `go.yaml.in/yaml/v4` is at release-candidate (`v4.0.0-rc.x`) as of mid-2026 — `go get @latest` resolves to the RC, and the API may still settle before the final tag.
  >
  > Kubernetes and Prometheus have already migrated.
  >
  > If you want a stable-tagged dependency _now_, use `go.yaml.in/yaml/v3` (same lineage, identical `yaml.Unmarshal`; bump to v4 later is just the major-version path change) or `github.com/goccy/go-yaml`.
  >
  > The recommendation stands as **v4** because it is the actively-developed line; the others are fallbacks for conservatism.

- **Both (mixed).** Accept either; pick the decoder by file **extension** (`.yaml`/`.yml` → YAML, anything else → JSON).

**Format detection is by extension.** An explicit `--config <path>` (or `$<NAME>_CONF`) decodes as its extension dictates; an unrecognized or missing extension falls back to JSON.

**Precedence when both coexist — YAML wins, and exactly one file is ever loaded.** In _both_ mode, with no explicit path given, `configPath` probes the default dir in the order `config.yaml`, `config.yml`, `config.json` and returns the **first** that exists.

If a project has both a YAML and a JSON file, the YAML one is used and the JSON one is ignored.

**Never read both files and blend them** — the layering is `defaults < (one) file < env < flags`, not `defaults < json < yaml`.

There is one config file per run.

The implementing code (format-aware `unmarshalConfigFile` / `configPath`) lives in the [YAML support block](config-source.md#yaml-support-yaml-only-or-both-formats).

### Config-file path resolution

`configPath` resolves the path in order: the `--config` flag value (`""` when unset), then `$<NAME>_CONF`, then — under `os.UserConfigDir()/<name>/` — the format probe above (`config.yaml` → `config.yml` → `config.json` in _both_ mode; the single matching filename in a single-format project).

Use **`os.UserConfigDir`**, not a hand-built `$HOME/.config` — it already consults `$XDG_CONFIG_HOME` and is platform-native (`Library/Application Support` on macOS, `%AppData%` on Windows), and it returns an error when no config dir is resolvable — propagate it.

`<NAME>` is the uppercased project name; `<name>` is the project name verbatim.

Exposing `--config` is recommended but optional — pass `""` to `LoadConfig` to rely on `$<NAME>_CONF` / `os.UserConfigDir` alone.

### Flag overlay (the flags-win step, in `./cmd`)

Service-config flags are **not** bound directly into `Config` — that would let a flag's _default_ value clobber file/env.

Bind them to locals (the default flag pattern; see SKILL.md › Cobra design rules) and, in the run function, overlay only the **explicitly-set** ones onto the loaded config.

The flag layer is present-based — `cmd.Flags().Changed(name)` distinguishes set from unset directly, mirroring `PartialConfig`'s present-semantics; an explicit `--port 0` set by the user wins regardless.

(Flags overlay onto scalar `Config` fields directly; they rarely target nested sub-configs, so a `PartialConfig` round-trip is unnecessary here — but you may build one and call `Apply` if a flag must feed a deep-merged field.)

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

`--config` (the config-file path) is a **persistent flag on the root command**, declared once in `rootCmd()` and threaded to each config-loading run function as a `*string` parameter (the persistent-flag rule) — including the mandatory `config` subcommand, wired as `configCmd(cmd, &flagConfig)`.

Implementors MAY rename it (e.g. `--conf`, `--config-file`) if `--config` would collide with a more-local flag name; keep the name consistent across the binary.

### Lint, growth, and adding a field

- **Env var names** live in `PartialConfig`'s `env:` / `envPrefix:` tags (bare names; the `{{NAME_UPPER}}_` prefix is applied via the package-level `envOptions`).

  There are no `SCREAMING_SNAKE` Go constants to trip naming lint — the only env-name identifier is the MixedCaps `envConfVar`, which needs no directive.

- **Long lines.** The triple-tagged `PartialConfig` fields (`json:` + `yaml:` + `env:` on one line) routinely exceed line-length linters (`lll`, `revive`'s `line-length-limit`).

  Keep one field per line — do **not** wrap tags across lines.

  Suppress the rule for the whole declaration with `//nolint:lll // triple json/yaml/env tags` on its own line directly above each `type Partial<Xxx> struct` (nested sub-partials included).

  The directive form (`//nolint:` with no space) is excluded from rendered godoc, so it doesn't pollute the doc comment.

- **Growth.** Start with one `config.go`.

  If configuration outgrows it (~300 LoC), promote it to a `pkg/<name>/config/` sub-package (`LoadConfig` → `config.Load`).

**Adding a config field** touches several sites in lockstep.

For a plain scalar / map / slice field:

1. `Config` — the field plus its `json:` and `yaml:` tags.
2. `DefaultConfig` — its default value (initialize a map / sub-config so later layers deep-merge into a populated base).
3. `PartialConfig` — the mirrored field with matching `json:` / `yaml:` tags **and** an `env:` tag (to make it env-settable).
4. `PartialConfig.Apply` — one overlay line, picking the rule for its kind (scalar / nested / map / slice).
5. `./cmd` (only when flag-settable) — the flag binding plus the `Changed()` overlay in the run function.
6. `cmd/{{NAME}}/commands/config.go` — add a line to the `configLongFmt` shape block (`.Field  type  // desc  (json_key)`; indent for a nested sub-config). Help text only; a miss never breaks `--format`. The helper-func list there is generated, so it needs no edit.

A **nested sub-config** field additionally needs its own value `Partial<Sub>` type (with the `//nolint:lll` directive above it) + `Apply` method and an `envPrefix:` tag (its inner fields carry the `env:` tags).

Env-settability is now just a tag — no loader code or constant to add.

No "is this zero-meaningful?" decision is needed.

## `cmd/{{NAME}}/commands/config.go` (always present)

The `config` subcommand — the runtime counterpart of the `version` subcommand.

Wired by `rootCmd()` unconditionally via `configCmd(cmd, &flagConfig)`.

It loads the configuration through the canonical `{{NAME}}.LoadConfig` (defaults < file < env), then prints it — indented JSON by default, or a Go `text/template` rendered against the `Config` value when `--format`/`-f` is given.

The work is split across **three files**, keeping presentation out of `./cmd` (the same rule that keeps run functions thin):

- **`cmd/{{NAME}}/commands/config.go`** — thin wiring: builds the command, loads the config, hands the result to the presentation layer. Owns the hand-written `--format` field-shape doc in its `Long`.
- **`pkg/{{NAME}}/cli/config.go`** — presentation: `RenderConfig` does the JSON / template rendering; `TemplateFuncHelp` surfaces the helper-func docs for the command's `Long`.
- **`internal/templateutil`** — the shared template `FuncMap` (`json`, plus any project-specific helpers) and its single-source-of-truth help (`FuncDocs` / `FuncHelp`).

Why a shared `templateutil`: nearly every `--format` template wants at least `json` (to dump a sub-value as JSON), and keeping the func docs beside the func map means the command help can't drift from what the templates actually expose — `TemplateFuncHelp` reads straight from `FuncDocs`.

The config file is selected by the root's **persistent `--config`** flag (threaded in as a `*string`; empty → default location).

### `cmd/{{NAME}}/commands/config.go` (wiring)

The `Long` is a `Sprintf` of a hand-written shape block (Go field name → JSON key) and `cli.TemplateFuncHelp()` — so the field list is authored, the func list is generated. The shape block is the field-list site on the [add-a-field checklist](#lint-growth-and-adding-a-field).

```go
package commands

import (
	"fmt"

	"github.com/spf13/cobra"

	"{{MODULE}}/pkg/{{NAME}}"
	"{{MODULE}}/pkg/{{NAME}}/cli"
)

// configLongFmt documents the resolved-config shape so users can write --format
// templates without reading the source. The %s is filled with the shared
// template-helper docs (cli.TemplateFuncHelp). Keep the field list in sync with
// Config — it is a site on the add-a-field checklist.
const configLongFmt = `config loads every layer (defaults < file < environment), applies any
explicitly-set flags on top, and prints the fully-resolved configuration. With
no flags it prints indented JSON; with --format it renders a Go text/template
against the config value instead.

The value passed to --format has this shape (Go field name, type, JSON key);
nesting is shown as a tree so deep configs stay readable:

  Config
  ├─ .Addr    string             # listen address     (addr)
  ├─ .Port    int                # listen port        (port)
  ├─ .Server                     # server sub-config   (server)
  │   ├─ .TLS      bool          #   enable TLS        (server.tls)
  │   └─ .Timeout  int           #   timeout seconds   (server.timeout)
  ├─ .Labels  map[string]string  # labels              (labels)
  └─ .Hosts   []string           # hosts               (hosts)

Use the Go field names in --format (e.g. {{.Addr}}, or {{.Server.TLS}} for a
nested field); the default JSON output uses the lower-case keys shown in
parentheses. The template also sees these helper functions:

%s`

const configExample = `  {{NAME}} config
  {{NAME}} config --format '{{.Addr}}:{{.Port}}'
  {{NAME}} config --format '{{ json .Server }}'`

func configCmd(parent *cobra.Command, flagConfig *string) {
	var flagFormat string

	cmd := &cobra.Command{
		Use:               "config",
		Short:             "Print the resolved configuration",
		Long:              fmt.Sprintf(configLongFmt, cli.TemplateFuncHelp()),
		Example:           configExample,
		Args:              cobra.NoArgs,
		ValidArgsFunction: cobra.NoFileCompletions,
		RunE: func(cmd *cobra.Command, args []string) error {
			return runConfig(cmd, args, *flagConfig, flagFormat)
		},
	}

	cmd.Flags().StringVarP(
		&flagFormat,
		"format",
		"f",
		"",
		"Go text/template rendered against the resolved config instead of JSON",
	)

	parent.AddCommand(cmd)
}

func runConfig(cmd *cobra.Command, _ []string, flagConfig, flagFormat string) error {
	cfg, err := {{NAME}}.LoadConfig(flagConfig)
	if err != nil {
		return err
	}
	// Presentation (JSON / template rendering) lives in pkg/{{NAME}}/cli; ./cmd
	// only wires it to stdout. cmd.Println would route to stderr.
	return cli.RenderConfig(cmd.OutOrStdout(), cfg, flagFormat)
}
```

### `pkg/{{NAME}}/cli/config.go` (presentation)

```go
// Package cli holds {{NAME}}'s CLI-presentation code — rendering resolved
// configuration and other terminal output. The ./cmd wiring layer calls into
// this package and returns its error; presentation logic never lives under
// ./cmd itself.
package cli

import (
	"encoding/json"
	"fmt"
	"io"
	"text/template"

	"{{MODULE}}/internal/templateutil"
	"{{MODULE}}/pkg/{{NAME}}"
)

// TemplateFuncHelp returns the aligned help block for the helper functions
// available to a --format template, the same set every template renderer
// exposes. Command help embeds it so the docs cannot drift from
// templateutil.FuncMap.
func TemplateFuncHelp() string {
	return templateutil.FuncHelp()
}

// RenderConfig writes the resolved configuration to w.
//
// With format == "" it writes indented JSON. Otherwise format is parsed as a Go
// text/template and executed against cfg (field paths use the Go field names,
// e.g. {{.Addr}}); it sees the shared templateutil.FuncMap helpers (json, ...).
// Either form is terminated with a trailing newline. A malformed or failing
// template is returned as an error attributed to the --format flag.
func RenderConfig(w io.Writer, cfg {{NAME}}.Config, format string) error {
	if format != "" {
		tmpl, err := template.New("config").
			Funcs(templateutil.FuncMap()).
			Parse(format)
		if err != nil {
			return fmt.Errorf("--format: %w", err)
		}
		if err := tmpl.Execute(w, cfg); err != nil {
			return fmt.Errorf("--format: %w", err)
		}
		fmt.Fprintln(w)
		return nil
	}

	b, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	fmt.Fprintln(w, string(b))
	return nil
}
```

### `internal/templateutil/templateutil.go` (shared template funcs)

Generic and reusable — no project identifiers. `json` is the baseline (nearly every template needs it); add project-specific helpers (`env`, `quote`, `which`, …) to **both** `FuncMap` and `FuncDocs`, which a test keeps in lockstep.

```go
// Package templateutil centralizes the [text/template] helpers shared by every
// template-rendering call site (the config subcommand's --format, and any other
// renderer a project adds). One func map means every template sees the same
// functions; one FuncDocs means the help text cannot drift.
package templateutil

import (
	"encoding/json"
	"fmt"
	"strings"
	"text/template"
)

// FuncMap returns the template function map shared across the project's template
// renderers. A fresh map is returned on each call so callers may mutate it
// without affecting one another.
//
//	json VALUE   → VALUE marshaled as indented JSON
//
// Almost every consumer needs json at minimum (dump a sub-value); add
// project-specific helpers (env, quote, which, ...) here and document each in
// FuncDocs.
func FuncMap() template.FuncMap {
	return template.FuncMap{
		"json": JSON,
	}
}

// FuncDoc documents a single helper exposed by FuncMap.
type FuncDoc struct {
	Name  string // bare function name as registered in FuncMap
	Usage string // name plus argument placeholders, e.g. "json VALUE"
	Desc  string // one-line human description
}

// FuncDocs returns documentation for every helper in FuncMap, in a stable
// display order. It is the single source of truth behind FuncHelp and the
// command help text; keep it in sync with FuncMap (guarded by a test).
func FuncDocs() []FuncDoc {
	return []FuncDoc{
		{Name: "json", Usage: "json VALUE", Desc: "VALUE marshaled as indented JSON"},
	}
}

// FuncHelp renders FuncDocs as an aligned, indented block for embedding in
// command help text. Each line is "  <usage>  <desc>" with the usage column
// padded to a common width; the block ends with a trailing newline.
func FuncHelp() string {
	docs := FuncDocs()
	width := 0
	for _, d := range docs {
		width = max(width, len(d.Usage))
	}
	var b strings.Builder
	for _, d := range docs {
		fmt.Fprintf(&b, "  %-*s  %s\n", width, d.Usage, d.Desc)
	}
	return b.String()
}

// JSON marshals v as indented JSON. Handy in a --format template to dump a
// sub-struct, e.g. {{ json .Server }}.
func JSON(v any) (string, error) {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return "", err
	}
	return string(b), nil
}
```

Notes:

- **Mandatory**, like `version`: `rootCmd()` calls `configCmd(cmd, &flagConfig)` unconditionally — no TODO around it.

  The subcommand owns only the local `--format` flag; the config-path flag is the root's **persistent `--config`**, threaded in as a `*string` (the persistent-flag rule — never read it with `cmd.Flags().Get*`).

- **Flag name.** `--config` is the canonical config-path flag name.

  Implementors MAY rename it (e.g. `--conf`, `--config-file`) when `--config` would collide with a more-local flag name on some subcommand; keep the chosen name consistent across the binary.

- **What it shows**: the `defaults < file < env` layers — _not_ a specific service command's flag overrides, which are applied per-command in that command's run function.
- **Presentation lives in `pkg/{{NAME}}/cli`, not `./cmd`.** `RenderConfig` is the render path; the run function only loads the config and writes to `cmd.OutOrStdout()`. This mirrors the thin-run-function rule — `./cmd` wires, the package renders.

  Write to **`cmd.OutOrStdout()`**, not `cmd.Println`: cobra's `Println` routes to **stderr** (`OutOrStderr`), so config output piped to a file or `jq` would vanish.

- **`--format`** renders against the `Config` value with Go `text/template` and the shared helpers: e.g. `{{NAME}} config -f '{{.Port}}'` prints just the port, `-f '{{ json .Server }}'` dumps a sub-struct as JSON. An empty format string prints indented JSON (which is why `Config` carries JSON tags).

  The default output stays **JSON even in a YAML project** — it needs no extra dependency and is valid YAML; swap `json.MarshalIndent` for `yaml.Marshal` in `RenderConfig` if you prefer YAML output.

- **Two halves of the help, two maintenance models.** The `Long` is `Sprintf(configLongFmt, cli.TemplateFuncHelp())`:
  - The **field shape** (the tree block of `.Field  type  (json_key)` lines) is **hand-written** — the agent knows `Config` when it writes the file. The tree layout keeps nested sub-configs legible as the field set grows. It can drift, so it is a site on the [add-a-field checklist](#lint-growth-and-adding-a-field). Help text only — a stale block never breaks `--format`, which runs against the live `Config`.
  - The **func list** (`%s`) is **generated** from `templateutil.FuncDocs` via `TemplateFuncHelp`, so it cannot drift from `FuncMap` — adding a helper updates the help automatically.

- **`templateutil` is `internal` and shared.** It is the one place template helpers live, so every renderer (config `--format` now, any future one) exposes the same funcs. `FuncMap` ↔ `FuncDocs` are kept in lockstep by a test (mirror crabswarm's `TestFuncDocs_MatchesFuncMap`).
- **Secrets**: if `Config` carries credentials, give it a `MarshalJSON` that redacts them (or omit those fields) — `config` prints to stdout, and the `json` helper routes through the marshaler too.
- If the project name is not a valid Go identifier, the `pkg/<name>` directory is already its sanitized form (see [Naming conventions › Package name](layout-and-naming.md#package-name-pkgname)), so the imports need no alias — `import "{{MODULE}}/pkg/mytool"` and `"{{MODULE}}/pkg/mytool/cli"`, matching `version.go`.
