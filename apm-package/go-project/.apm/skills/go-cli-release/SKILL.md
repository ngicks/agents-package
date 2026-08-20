---
name: go-cli-release
description: "Use when cutting a release of a Go project, bumping its version, tagging a Go submodule, or wiring/editing the version subcommand or the internal/libver Version constant. Triggers: 'release', 'bump version', 'tag v', 'bump-libver', 'edit version.go', 'const Version'."
---

# Go versioning & release

The release-controlled version of the canonical Go CLI project: the fixed `internal/libver` version constant, the `version` subcommand's collaborators, the external `bump-libver` release-tool flow, and submodule tags.

Companion to the `go-edit-cobra` skill (same package): that skill owns the command tree; this one owns the version contract and the release flow.

## The contract in one line

`internal/libver/libver.go` declares a single top-level `const Version = "..."` and nothing else; the external `bump-libver` tool (`go run github.com/ngicks/go-common/tools/bump-libver@latest`) is the only thing that rewrites it — commit, tag, next `-devel` bump, and push included.

Core invariants (details and rationale in the reference file):

- The path `internal/libver/libver.go` is fixed by convention; legacy in-service `version.go` locations are preserved, not migrated.
- No release code is ever vendored into the project — no shell scripts, no `internal/cmd/release/` for new code.
- `internal/versioninfo.ReadVersionInfo(libver.Version)` combines the constant with VCS build info; `commands/version.go` is the thin presentation layer.
- `--version` is a local root flag dispatching to `runVersion` — never persistent, never duplicated.
- Submodule releases tag with the directory prefix (`subpkg/v0.2.0`) while the file keeps the bare version.

## Reference files

- **[reference/versioning.md](reference/versioning.md)** — the four collaborating pieces, the step-by-step release flow, submodule tags, the `libver.go` source, the `version.go` subcommand template, the `versioninfo` helper, the `bump-libver` tool's behavior, and the versioning anti-patterns.

  Read before cutting a release, wiring the `version` subcommand, or touching `const Version`.

## Sibling skills

- **`go-edit-cobra`** — command-tree scaffolding/editing; the `libver` / `versioninfo` helper sources ship there and are copied into projects by its `copy_helper.sh`. Entry point: [../go-edit-cobra/SKILL.md](../go-edit-cobra/SKILL.md).
- **`go-cli-config`** — the layered configuration model and per-user directories. Entry point: [../go-cli-config/SKILL.md](../go-cli-config/SKILL.md).
