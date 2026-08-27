# go-project

Go project conventions in one bundle — hooks, instructions, and skills for
authoring Go CLIs, packaged for [apm](https://github.com/microsoft/apm).

Everything here was gathered from the repository's top-level `hooks/`,
`instructions/`, and `skills/` units so a Go project can depend on one
package instead of seven. The former `go-edit-cobra` skill is generalized
into the `go-project` skill — whole-project conventions, with Cobra as the
default for a command with subcommands — and its sibling skills
cross-reference each other by relative path.

## Skills

| Skill | Purpose |
|---|---|
| `go-project` | Scaffold/edit a whole Go project: layout & naming, configuration, versioning, per-user dirs, the Cobra command tree (default for commands with subcommands), code templates, workflows, and the verbatim helper packages (`copy_helper.sh`). |
| `go-cli-config` | The layered configuration model (`Config` / `PartialConfig.Apply`), the `config.go` source template, the `config` subcommand, and per-user (XDG) directory conventions. |
| `go-cli-release` | Versioning & release: the `internal/libver` contract, the `version` subcommand, and the external `bump-libver` flow. |
| `go-check-outdated-patterns` | Post-edit review: replace outdated Go patterns with idioms of the module's declared Go version. |
| `go-review-checklist` | Post-edit review: correctness / structure / personal-preference checklist. |

The first three form one set: `go-project` owns the project layout and
command tree and holds the shared `helpers/` sources; `go-cli-config` and
`go-cli-release` own the configuration and versioning halves and are
referenced from its scaffold / edit workflows.

## Hooks

| Hook | Purpose |
|---|---|
| `go-golangci-lint` | Deny direct `gofmt`; `golangci-lint fmt` + `run` after Edit/Write on Go files. |
| `go-vet-ngcheckers` | `go vet -vettool=ngcheckers` after Edit/Write on Go files. |

Both hook commands run through `crabswarm hook exec`.

## Instructions

| Instruction | Applies to |
|---|---|
| `ngicks.go.basics.instructions.md` | `**/*.go` — concurrency-primitive preferences. |
| `ngicks.go.design-preference.instructions.md` | `**/*.go` — thin entrypoints, package-boundary and context rules. |
