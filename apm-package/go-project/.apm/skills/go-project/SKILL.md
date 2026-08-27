---
name: go-project
description: "Use when authoring or editing a Go project: module layout, package placement/naming, service packages, configuration, versioning, per-user dirs, and CLI command trees (spf13/cobra is the default for a command with subcommands). Auto-triggers on any edit/create of Go files, plus phrases: 'scaffold go project', 'scaffold cli', 'create go command', 'add subcommand', 'add package', 'add flag to <cmd>', 'edit cmd/'."
---

# Go project authoring

Scaffold a new Go project, edit an existing one, or apply its whole-project design rules: layout, naming, configuration, versioning, per-user directories, and the CLI command tree.

The CLI part is built on `spf13/cobra` — the default framework whenever a project grows a command with subcommands.
Everything else (layout, service packages, configuration, versioning) applies to any Go module, CLI or not.

This page holds the always-applied core: pre-flight checks, the general design rules, and the post-edit validation chain.

Everything else — layout details, templates, the Cobra rules, the configuration model, versioning, and the scaffold/edit procedures — lives in the reference files below; read the one a task needs.

## Reference files

- **[reference/layout-and-naming.md](reference/layout-and-naming.md)** — canonical project layout (top-level service package `./<name-without-separator>/`, `./pkg/` for packages not specific to the service, the main-vs-utility entry-point rule, the optional `api/` RPC-schema tree), naming conventions (files / wrappers / run functions / package name / service method `<Method>Option` structs / the subdirectory-nesting variant), and the anti-patterns list.

  Read before deciding where a file goes or how to name it, before adding a new package, binary, or RPC API schema, and before adding or editing a `<name-without-separator>` service method.
- **[reference/cobra.md](reference/cobra.md)** — the Cobra design rules: error handling, positional args & completion, wrapper functions, run-function wiring, flag threading, file naming in `commands/`, and the canonical flag pattern.

  Read before touching anything under `./cmd` or any `cobra.Command`.
- **[reference/command-templates.md](reference/command-templates.md)** — the command-tree code templates: `main.go`, `root.go`, flat-leaf / parent-group / nested-leaf subcommands, and `go.mod` + version policy.
- **[reference/configuration.md](reference/configuration.md)** — the configuration model (layers, `PartialConfig.Apply` merge semantics, file format, path resolution, flag overlay, add-a-field) and the `config` subcommand (three-file split: `cmd` wiring + `<name-without-separator>/cli` rendering + `internal/templateutil` funcs).
- **[reference/config-source.md](reference/config-source.md)** — the `<name-without-separator>/config.go` source template (JSON base) plus the YAML-only / both-format support block.
- **[reference/user-dirs.md](reference/user-dirs.md)** — per-user directory conventions beyond the config file: the base-dir table (config / cache / data / state / runtime / home), the `/<name>` suffix rule (appended in the app-specific layer), the never-`~/.<name>` home rule, cache-vs-data-vs-state selection, runtime-dir handling (`$XDG_RUNTIME_DIR` has no spec default; the helper falls back to a per-user temp dir), creation semantics (0700 at first write), and the always-copied app-agnostic `internal/userdir` helper (base-dir resolvers for data / state / runtime).

  Read before writing any per-user file that is not the config file (caches, downloaded data, logs / history, sockets / locks).
- **[reference/versioning.md](reference/versioning.md)** — the four versioning pieces (the fixed `internal/libver` version constant among them), the external `bump-libver` release-tool flow, submodule tags, and the `libver` / `versioninfo` source.
- **[reference/workflows.md](reference/workflows.md)** — step-by-step scaffold and edit procedures (subcommand / flag / metadata / completion operations) and the helper-package catalog.

## Pre-flight checks

Run before any edit.

1. **Mode detection.**
   - The user asks to scaffold / create a new project or CLI (or the module root is empty — no `go.mod`) → **Scaffold mode**. Skip the remaining checks; jump to [Scaffold a new project](reference/workflows.md#scaffold-a-new-project).

     That workflow produces a CLI project. When the user asks for a **library** (no binary), don't run it — `go mod init` plus the general rules below is the whole scaffold.
   - Otherwise → **Edit mode**; continue.

     A module without `./cmd` is a valid library project — general rules apply, no CLI is forced on it.
2. **CLI-framework detection** (edit mode, only when the task touches the CLI). Look for `github.com/spf13/cobra` in `go.mod` or any import.
   - **Cobra present** → the [Cobra rules](reference/cobra.md) apply; continue with layout classification.
   - **No CLI framework at all** — the task adds the project's first command with subcommands → default to Cobra with this skill's templates.
   - **Another framework** (urfave/cli, kong, hand-rolled `flag`, ...) → the Cobra-specific rules and templates are out of scope; report that, and apply only the general rules (layout, configuration, versioning, user dirs).
3. **Layout classification** (edit mode, Cobra projects only). Categorize the project:
   - **Canonical** — `<root>/cmd/<name>/main.go` + `<root>/cmd/<name>/commands/` + `<root>/internal/cmdsignals/` exist. → Proceed.
   - **Close variant** — `cmd/<name>/main.go` + `cmd/<name>/commands/` exist but the helper packages sit elsewhere (e.g. under an older `cmd/internal/` tree, or `cmdsignals` not yet present), the service package still lives at the legacy `pkg/<name-without-separator>/` instead of the top-level `./<name-without-separator>/`, or subcommand files nest under **subdirectories** of `commands/` (an allowed variant — see [layout-and-naming.md › Subdirectory-nested subcommands](reference/layout-and-naming.md#subdirectory-nested-subcommands-allowed-variant)). → Proceed; mirror the existing structure; do not force-migrate existing files.
   - **Non-canonical Cobra** — e.g. `cmd/root.go` at module root, or `cobra-cli` defaults. → **Stop and ask.** Likely mid-migration or accidental drift.

## General design rules

These apply to every Go project this skill touches, CLI or not.

- **Package placement**, in full: main functionality → top level (`./<name-without-separator>/`); not specific to the service → `pkg/<pkgname>/`; must stay unimportable from other modules → `internal/`.

  `./cmd` holds entry points and is **wiring only** — flags, positional args, and (logger-only) env vars feed into a service constructed from the service package. Business logic is forbidden under `./cmd`.

  Details and the anti-patterns list: [layout-and-naming.md](reference/layout-and-naming.md).
- **Importable package names follow Go convention** — no hyphens, no underscores. Strip separators from the project name for the service directory and `package` clause; only `cmd/<name>/` and user-facing strings keep the verbatim name.
- **Exported service methods take a single `<Method>Option` struct** for their per-call options — never a tail of positional parameters; facades embed their callees' option structs. See [layout-and-naming.md › Service method options](reference/layout-and-naming.md#service-method-options-name-without-separator).
- **Configuration is layered** — `defaults < (one) file < env < flags`, merged through `PartialConfig.Apply`; every project carries `<name-without-separator>/config.go`. See [configuration.md](reference/configuration.md).
- **The version is a release-controlled `const Version`** at the fixed path `internal/libver/libver.go`, bumped only by the external `bump-libver` tool. See [versioning.md](reference/versioning.md).
- **Per-user files go under the platform base dirs plus `/<name>`** — never a `~/.<name>` dotdir, never a hand-built XDG path. See [user-dirs.md](reference/user-dirs.md).
- **CLI work follows the Cobra rules.** Before touching anything under `./cmd` or any `cobra.Command`, read [cobra.md](reference/cobra.md) — wrapper functions, `RunE`-only, the canonical flag pattern, and the `commands/` file-naming contract all live there.

## Post-edit validation

Run after **every** edit and after scaffolding, in this order:

1. `go mod tidy` — only when imports / dependencies changed.
2. **Format the changed files.**

   If the project has a golangci-lint config (`.golangci.{yaml,yml,toml,json}`) with a `formatters.enable` block, run `golangci-lint fmt <changed_files>` — this applies the project's configured formatters (e.g. `goimports`, `golines`) in their configured order.

   Otherwise, run `goimports -w <changed_files>`.

   If `goimports` is missing, fall back to `gofmt -w` and report the missing tool to the user — do not install it.
3. `go vet ./...` — full module, never package-scoped.

   (In a Cobra project the wrapper-function chain crosses package boundaries on `parent.AddCommand`, so package-scoped vet misses breakage — see [cobra.md](reference/cobra.md).)
4. `go test ./...` — full module.

Edits in this skill are best-effort textual changes.

The validation chain (vet + test) is the safety net for rename / move operations that touch identifiers across many files.

## Out of scope

- Migrating non-canonical projects to the canonical layout (skill detects + asks; user drives migration).
- CLI frameworks other than `spf13/cobra` (general rules still apply to such projects; only the CLI-specific rules and templates are skipped).
- `cobra-cli` code generation.
- AST-based rewriting (`go/ast`, `dst`); plain `Edit` / `Write` only.
