# Versioning & release

The release-controlled version: which packages collaborate, the release-tool flow, submodule tags, and the `libver` / `versioninfo` / `release` source.

Read this when cutting a release, wiring the `version` subcommand, or touching `const Version`.

## Contents

- [Versioning (the four collaborating pieces)](#versioning)
- [Release flow](#release-flow)
- [Submodule tags](#submodule-tags)
- [`internal/libver/libver.go`](#internallibverlibvergo-always-present)
- [`cmd/{{NAME}}/commands/version.go` template](#cmdnamecommandsversiongo-always-present)
- [`internal/versioninfo/versioninfo.go`](#internalversioninfoversioninfogo-always-present)
- [`internal/cmd/release/main.go`](#internalcmdreleasemaingo-always-present)

## Versioning

Every project carries a release-controlled version.

Four pieces collaborate:

| Piece                            | Responsibility                                                                                                                                                                                       |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `internal/libver/libver.go`      | Source of truth for the version string. `package libver` declares `const Version = "v0.0.0-devel"` and **nothing else**. The path is fixed by convention, so the release helper always knows where to rewrite.        |
| `internal/versioninfo`           | Reusable helper exporting `type Info` and `ReadVersionInfo(version string) Info`. Combines the supplied `Version` with VCS info from `runtime/debug.ReadBuildInfo`.                                  |
| `cmd/<name>/commands/version.go` | The `version` subcommand. Imports both `internal/libver` (for `Version`) and `internal/versioninfo` (for `ReadVersionInfo`); prints to `cmd.OutOrStdout()`. Wired by `rootCmd()` unconditionally.         |
| `cmd/<name>/commands/root.go`    | Declares `--version` as a local (not persistent) flag on the root command. The root's `RunE` closure dispatches to `runVersion` when the flag is set.                                                |
| `internal/cmd/release`           | Cross-platform Go `main` package. Rewrites `internal/libver/libver.go`'s `Version` line, commits, tags, then bumps to the next `-devel` and commits again. Run with `go run ./internal/cmd/release ...`. |

Design notes:

- **`Version` is a `const`.** The release tool rewrites the source line, commits, and tags — that is the canonical mutation path, so build-time `-ldflags=-X` override would be redundant (and doesn't work on `const` anyway).

  Tests do not swap the value.

- **`libver` is the whole module's version, so it lives under `internal/`, not in the service package.** The constant describes the module, not one service, and the fixed `internal/libver/libver.go` path means the release helper — and any reader — never has to hunt for it.

  (Older revisions of this layout kept a `version.go` inside the service package — top-level `<name-without-separator>/version.go`, or `pkg/<name-without-separator>/version.go` before that. Preserve those in projects that already use them; the release helper auto-detects them as fallbacks.)
- **`libver.go` declares only `const Version` — no imports, nothing else.** Anything richer (VCS info, etc.) lives in `internal/versioninfo`.
- **`--version` is local, not persistent.** `mytool serve --version` is intentionally an unknown-flag error; only the root command exposes the alias.
- **`mytool --version` and `mytool version` produce identical output.** They share `runVersion`; the alias is implemented as a closure dispatch, not a duplicated command.
- **The `config` subcommand is the one `commands/` file that imports `<name-without-separator>` directly** (for `Config` + `LoadConfig`); `version` needs only the internal `libver` / `versioninfo` pair.

  Other commands go through the service constructed in their wrappers / `runRoot`.
- **One Go source base, every host OS.** The release helper is a Go `main` package precisely so Linux, macOS, and Windows users do not have to maintain parallel bash + PowerShell scripts.

  Running it requires only the Go toolchain, which the project already needs.

## Release flow

`go run ./internal/cmd/release` automates the version dance.

It is the canonical release entry point; do not re-introduce shell scripts in parallel.

Steps the tool performs:

1. Validate the requested release version (`vMAJOR.MINOR.PATCH[-suffix]`, must NOT end in `-devel`) and the next-dev version (must end in `-devel`).

   Both may carry an optional submodule path prefix — see [Submodule tags](#submodule-tags) below.

2. Locate the version file at the fixed `<prefix>/internal/libver/libver.go` (override with `-file <path>`).

   When that file is absent (a legacy layout), it globs the top-level `*/version.go` — skipping the directories that never hold the service package (`cmd/`, `internal/`, `api/`, `pkg/`) — then falls back to the older `pkg/*/version.go`; a glob must match exactly one file.

   The prefix is empty for root-module releases.
3. Refuse if the working tree is dirty or the release tag already exists.
4. Rewrite the `Version` line to the release version (bare, no prefix), commit, and create an annotated tag `<tag>`.
5. Rewrite the `Version` line to the next-dev version (bare, no prefix) and commit.
6. `git push` the branch, then `git push origin <tag>` to publish the new tag.

   The tool aborts if either push fails (e.g. missing upstream, network failure, remote rejection); fix and re-push manually since the commits and tag already exist locally.

Usage:

```sh
go run ./internal/cmd/release v0.2.0                # next dev defaults to v0.2.1-devel
go run ./internal/cmd/release v0.2.0 v0.3.0-devel   # explicit next dev (must end in -devel; the tool does NOT append it)
go run ./internal/cmd/release -file other/version.go v0.2.0   # non-standard location
go run ./internal/cmd/release subpkg/v0.2.0         # Go submodule at ./subpkg/; tags as subpkg/v0.2.0
go run ./internal/cmd/release nested/dir/v0.2.0     # deeper submodule at ./nested/dir/
```

The default next-dev calculation bumps the patch component.

If the release is a minor or major bump, pass the next-dev explicitly.

The argument must already include the `-devel` suffix — the tool validates rather than appends so a typo can't silently produce an unexpected version.

### Submodule tags

A Go repository can host multiple modules.

Submodule versions are tagged with the directory as a prefix (`subpkg/v1.0.0`, `nested/dir/v1.0.0`); `go list -m <module>@<prefixed-tag>` is how Go resolves them.

The release tool accepts these tags and applies a two-rule split:

- **Tag-shaped names** (`subpkg/v0.2.0`, `subpkg/v0.2.1-devel`) — the full prefixed string is the git tag, commit message, and `go push` reference.
- **File-shaped content** (`const Version = "v0.2.0"`) — only the bare version is written into `libver.go`.

  The submodule's package doesn't know about the path prefix; only git tooling does.

Location of the version file follows the prefix: `subpkg/v0.2.0` ⇒ `subpkg/internal/libver/libver.go`.

The same `internal/libver/libver.go` convention applies inside each submodule (including the legacy `<name-without-separator>/version.go` / `pkg/<name-without-separator>/version.go` fallbacks).

If the submodule deviates from this layout, pass `-file <path>` explicitly.

`defaultNextDev` preserves the prefix: `subpkg/v0.2.0` ⇒ `subpkg/v0.2.1-devel`.

The patch-bump rule and `-devel` suffix policy are otherwise unchanged.

## `internal/libver/libver.go` (always present)

Source of truth for the version string.

Project-agnostic — the package name (`libver`) and the path are fixed, so the file is copied verbatim from `${SKILL-DIR}/helpers/internal/libver/libver.go` (it is **not** a template):

```go
// Package libver pins the module-wide, release-controlled version string.
//
// The file lives at the fixed path internal/libver/libver.go so the release
// helper (internal/cmd/release) always knows where to rewrite it; the
// package declares Version and nothing else.
package libver

// Version is the human-readable version string for the whole module. The
// release helper rewrites this declaration when cutting a release, then
// bumps it to the next "-devel" version after tagging.
//
// Edit by hand only when the release helper is unavailable (e.g. cherry-pick
// of a release commit).
const Version = "v0.0.0-devel"
```

The contract with the release helper is a single top-level `const Version = "..."` line, identifier spelled `Version`.

Anything that changes this shape (renaming the identifier, switching to `var`, multiple declarations, struct-wrapping) breaks the helper's rewrite; update the helper in lockstep if you must change the shape.

`libver.go` declares only `Version` — no imports, no other symbols.

Combine the `Version` value with VCS info via `internal/versioninfo.ReadVersionInfo(libver.Version)` from the call site (typically `cmd/{{NAME}}/commands/version.go`).

## `cmd/{{NAME}}/commands/version.go` (always present)

The `version` subcommand.

Wired by `rootCmd()` unconditionally; also reachable via the `--version` alias on the root command.

`runVersion` lives here so the root's `RunE` closure can dispatch to it.

```go
package commands

import (
	"github.com/spf13/cobra"

	"{{MODULE}}/internal/libver"
	"{{MODULE}}/internal/versioninfo"
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
	info := versioninfo.ReadVersionInfo(libver.Version)
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
- Imports two internal packages: `internal/libver` for the `Version` constant, and `internal/versioninfo` for the `ReadVersionInfo` helper — it does **not** import the service package.

  That leaves [`config.go`](configuration.md#cmdnamecommandsconfiggo-always-present) as the one `commands/` file that imports `{{NAME}}` directly.

## `internal/versioninfo/versioninfo.go` (always present)

Reusable, project-agnostic helper.

Copied verbatim from `${SKILL-DIR}/helpers/internal/versioninfo/versioninfo.go`.

Exposes `type Info` and `ReadVersionInfo(version string) Info`.

The caller passes the project's `Version` constant; the helper layers VCS info from `runtime/debug.ReadBuildInfo` on top.

This file is **not** a template; copy it as-is. See [Helper catalog](workflows.md) for the full path.

## `internal/cmd/release/main.go` (always present)

Cross-platform release helper.

Copied verbatim from `${SKILL-DIR}/helpers/internal/cmd/release/main.go`.

A `main` package living under `internal/` so it cannot be `go install`ed externally — it's a build-time tool of this module only.

Runs as `go run ./internal/cmd/release`.

This file is **not** a template; copy it as-is. The same source compiles on Linux, macOS, and Windows; that is the entire reason for picking a Go program over parallel shell + PowerShell scripts.
