---
name: go-project
description: "Use when authoring or editing a Go project: module layout, package placement/naming, service packages, configuration, versioning, per-user dirs, and CLIs (std flag for a single-command tool, spf13/cobra for a command with subcommands). Auto-triggers on any edit/create of Go files, plus phrases: 'scaffold go project', 'scaffold cli', 'create go command', 'add subcommand', 'add package', 'add flag to <cmd>', 'edit cmd/'."
---

# Go project authoring

Scaffold a new Go project, edit an existing one, or apply its whole-project design rules: layout, naming, configuration, versioning, per-user directories, and the CLI command tree.

This skill describes strong recommendations for many aspects but users always can slide away from it.
A project's recorded decisions (see [Decision record](#decision-record)) saves user preferences over those defaults.

This page holds the always-applied core: pre-flight checks, the general design rules, and the post-edit validation chain.

Everything else lives in the reference files below; read index below and read referenced files a task needs.

## Reference files

- [reference/layout-and-naming.md](reference/layout-and-naming.md) — project layout, package placement, naming conventions, service method options, anti-patterns.

  Read before placing or naming a file, package, binary, RPC API schema, or service method.

- [reference/cli.md](reference/cli.md) — framework-neutral CLI rules: errors & exit, positionals vs flags, thin `./cmd` wiring.

  Read before any CLI work, **plus exactly one** shape file below, per pre-flight CLI-shape detection.
  - [reference/cli-cobra.md](reference/cli-cobra.md) — Cobra rules: wrappers, `RunE`-only, flag threading, `commands/` file naming, canonical flag pattern.

    Read before touching anything under `./cmd` or any `cobra.Command`.

  - [reference/cli-std-flag.md](reference/cli-std-flag.md) — std-`flag` single-command shape: layout, `run` pattern, `fs.Visit` overlay, `-version` & logging, scaffold deltas.

    Read before touching a std-`flag` CLI or creating a single-command tool.

- [reference/command-templates.md](reference/command-templates.md) — command-tree code templates: `main.go`, `root.go`, subcommand shapes, `go.mod` + version policy.
- [reference/configuration.md](reference/configuration.md) — configuration model: layers, `PartialConfig.Apply`, file format, path resolution, flag overlay, add-a-field; the `config` subcommand.
- [reference/config-source.md](reference/config-source.md) — `<name-without-separator>/config.go` source template; YAML / both-format block.
- [reference/user-dirs.md](reference/user-dirs.md) — per-user dirs beyond the config file: base-dir table, `/<name>` suffix, cache/data/state/runtime selection, the `internal/userdir` helper.

  Read before writing any per-user file that is not the config file.

- [reference/versioning.md](reference/versioning.md) — the four versioning pieces, `bump-libver` release flow, submodule tags, `libver` / `versioninfo` source.
- [reference/workflows.md](reference/workflows.md) — scaffold and edit procedures, helper-package catalog.

## Pre-flight checks

Run before any edit.

0. **Decision record.** Read `<project-root>/.go-project-decision.md` when it exists (both modes — re-scaffolding is the flow it exists for).

   Recorded decisions override this skill's defaults in their area, including choices this skill has no rules for. Never revert one. Format and semantics: [Decision record](#decision-record).

1. **Mode detection.**
   - The user asks to scaffold / create a new project or CLI (or the module root is empty — no `go.mod`) → **Scaffold mode**. Skip the remaining checks; jump to [Scaffold a new project](reference/workflows.md#scaffold-a-new-project).

     That workflow produces a Cobra CLI project — the default when subcommands are requested (a recorded `cli` decision wins). For a **single-command tool**, scaffold the std-`flag` shape instead via [cli-std-flag.md › Scaffold deltas](reference/cli-std-flag.md#scaffold-deltas). When **nothing decides the shape** — no recorded decision, and the request doesn't reveal whether subcommands exist — ask per [Asking decisions](#asking-decisions). When the user asks for a **library** (no binary), don't run it — `go mod init` plus the general rules below is the whole scaffold.

   - Otherwise → **Edit mode**; continue.

     A module without `./cmd` is a valid library project — general rules apply, no CLI is forced on it.

2. **CLI-shape detection** (edit mode, only when the task touches the CLI). The neutral [cli.md](reference/cli.md) rules apply to every branch that stays in scope.
   - **A recorded `cli` decision wins.** When it names something this skill has no rules for, apply only the general rules (layout, configuration, versioning, user dirs) — do not migrate, do not suggest switching.
   - **Cobra present** (`github.com/spf13/cobra` in `go.mod` or any import) → the [Cobra rules](reference/cli-cobra.md) apply; continue with layout classification.
   - **Std-`flag` single-command CLI** (`cmd/<name>/main.go` parses with the std `flag` package; no subcommand tree) → the [std-`flag` rules](reference/cli-std-flag.md) apply; skip layout classification.
   - **No CLI yet** — the task adds the project's first command: subcommands wanted → Cobra with this skill's templates; a single flat command → the std-`flag` shape; neither inferable from the request → ask per [Asking decisions](#asking-decisions).
   - **Another framework, no record of it** → its specifics are out of scope; report that, apply only the general rules, and suggest recording the choice in `.go-project-decision.md` so it survives future edits and re-scaffolds.
3. **Layout classification** (edit mode, Cobra projects only). Categorize the project:
   - **Canonical** — `<root>/cmd/<name>/main.go` + `<root>/cmd/<name>/commands/` + `<root>/internal/cmdsignals/` exist. → Proceed.
   - **Close variant** — `cmd/<name>/main.go` + `cmd/<name>/commands/` exist but the helper packages sit elsewhere (e.g. under an older `cmd/internal/` tree, or `cmdsignals` not yet present), the service package still lives at the legacy `pkg/<name-without-separator>/` instead of the top-level `./<name-without-separator>/`, or subcommand files nest under **subdirectories** of `commands/` (an allowed variant — see [layout-and-naming.md › Subdirectory-nested subcommands](reference/layout-and-naming.md#subdirectory-nested-subcommands-allowed-variant)). → Proceed; mirror the existing structure; do not force-migrate existing files.
   - **Non-canonical Cobra** — e.g. `cmd/root.go` at module root, or `cobra-cli` defaults. → **Stop and ask.** Likely mid-migration or accidental drift.

## Decision record

`<project-root>/.go-project-decision.md` records the project's **explicit decisions over this skill's defaults** — the minimum description per decision.

Users can always slide away from a skill default, but only a recorded decision survives re-scaffolding after this skill is updated; that survival is the file's whole purpose.

Format: one bullet per area, the decision as a sub-bullet (optionally with a one-line reason):

```markdown
# go-project decisions

- cli
  - <some CLI lib this skill never knew> — team standard
- versioning
  - manual tags, no bump-libver
```

Semantics:

- **Record deviations only, never defaults.** A recorded default would freeze the project against future skill-default improvements.
- **Recorded decisions win** over the corresponding skill default, in every mode — even when the decision names something this skill has no rules for (then apply only the general rules to that area).
- **Never revert or "fix" a recorded decision.** Changing one is the user's call; edit the record only when they ask.
- **Append a record when the user explicitly decides against a default mid-task** (e.g. "use X instead of cobra"); when you detect an unrecorded deviation, report it and suggest recording it.
- Areas are free-form — `cli` is an example, not a schema. Keep each entry minimal: area, decision, at most a one-line reason.

## Asking decisions

Some decisions have **no signal to decide them** — no recorded decision, nothing in the user's request, and nothing in the code base to infer from. Pure scaffolding is the typical case: an empty module and a request that doesn't say whether the tool has subcommands leaves the CLI shape (Cobra vs std `flag`) undecidable. Ask the user; never silently pick.

- Use the `AskUserQuestion` tool when it is available.
- Without that tool, print each pending question as an indexed choice list — `<question#>-<choice#>` — so the user can answer by index alone:

  ```text
  1. CLI shape?
  1-1. cobra
  1-2. std flag
  ```

- **Choice order is fixed per area** and identical in both forms — always the skill's stated order, never reshuffled. For `cli`: `cobra` first, `std flag` bottom.
- Apply the answer, then follow the [Decision record](#decision-record) rules: record it only when it deviates from a skill default that would otherwise apply.

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
- **CLI work follows the CLI rules.** Before touching anything under `./cmd`, read [cli.md](reference/cli.md) plus the shape's file — [cli-cobra.md](reference/cli-cobra.md) for a Cobra tree (wrapper functions, `RunE`-only, the canonical flag pattern, the `commands/` file-naming contract), [cli-std-flag.md](reference/cli-std-flag.md) for a std-`flag` single-command tool.

## Post-edit validation

Run after **every** edit and after scaffolding, in this order:

1. `go mod tidy` — only when imports / dependencies changed.
2. **Format the changed files.**

   If the project has a golangci-lint config (`.golangci.{yaml,yml,toml,json}`) with a `formatters.enable` block, run `golangci-lint fmt <changed_files>` — this applies the project's configured formatters (e.g. `goimports`, `golines`) in their configured order.

   Otherwise, run `goimports -w <changed_files>`.

   If `goimports` is missing, fall back to `gofmt -w` and report the missing tool to the user — do not install it.

3. `go vet ./...` — full module, never package-scoped.

   (In a Cobra project the wrapper-function chain crosses package boundaries on `parent.AddCommand`, so package-scoped vet misses breakage — see [cli-cobra.md](reference/cli-cobra.md).)

4. `go test ./...` — full module.

Edits in this skill are best-effort textual changes.

The validation chain (vet + test) is the safety net for rename / move operations that touch identifiers across many files.

## Out of scope

- Migrating non-canonical projects to the canonical layout (skill detects + asks; user drives migration).
- CLI frameworks other than std `flag` and `spf13/cobra` (general rules still apply to such projects; only the shape-specific rules and templates are skipped — and a recorded `cli` decision naming one is honored, never migrated).
- `cobra-cli` code generation.
- AST-based rewriting (`go/ast`, `dst`); plain `Edit` / `Write` only.
