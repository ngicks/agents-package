# .tool — repo maintenance CLI (MoonBit)

A small CLI living in `./.tool`, built with MoonBit.
First (and for now only) subcommand: `gen-apm-yml` — generates a valid `apm.yml`
listing every importable package in this repo. The file is a template other
repos take as their own apm.yml; each dependency is fetched from GitHub and
`apm update` keeps consumers current.

Revised after adversarial review; every amendment below was verified against
the apm 0.26.0 source (pipx install) and the on-disk MoonBit `.mbti` interfaces.

## Verified facts (probed on this machine, 2026-07-22)

- Toolchain: `moon 0.1.20260713`, new non-JSON `moon.mod` / `moon.pkg` config format.
  - Template default is `preferred_target = "wasm-gc"`; we need native
    (`@fs.realpath` etc.), so `moon.mod` MUST set `preferred_target = "native"`.
- `moonbitlang/core/argparse` is bundled with core — no dependency entry needed.
  - clap-like: `Command(name, options=[], flags=[], subcommands=[], subcommand_required=true)`.
  - `cmd.parse()` inside `async fn main` reads argv itself.
  - Exit behavior (from argparse source, `runtime_exit*.mbt`): only `--help` /
    `--version` print-and-exit. Parse ERRORS `raise` — the error message is
    display-ready (includes contextual help) but nothing is printed for you.
    Uncaught raise in `async fn main` → `abort()`, exit 255, backtrace. So the
    top level must catch, print to stderr, and exit explicitly.
  - There is NO `@env.exit` in core. Use the same idiom argparse uses internally:
    `#cfg(any(target="native", target="llvm"))`
    `extern "c" fn exit_code(code : Int) = "exit"`.
- `moonbit-community/yaml@0.0.6` (`@yaml`):
  - `pub(all) enum Yaml { String(..); Array(..); Map(Map[String, Yaml]); ... }`.
  - `Map` preserves insertion order on emit — apm.yml key order is reproducible.
  - `Yaml::dump(self) -> String` always prefixes `---\n` (valid YAML; keep it).
- `moonbitlang/async@0.20.2` for IO on native target:
  - `@fs.readdir / exists / write_file / rename / mkdir`, `@stdio` for stderr,
    `@process` to run `git remote get-url origin`.
  - Entry point is plain `async fn main` (requires importing `moonbitlang/async`);
    raising calls must live in a helper fn, `main` wraps it in `try/catch`.
- A throwaway project exercising argparse + `@fs.readdir` + `@yaml` dump built and
  ran successfully with `moon build --target native`.

## What counts as "importable" (apm 0.26 classification cascade)

From `apm_cli/models/format_detection.py` (`NormalizationPlanner.plan`),
first match wins:

1. `marketplace_plugin` — `plugin.json` or `.claude-plugin/` manifest
2. `hybrid` — root `SKILL.md` AND `apm.yml`
3. `claude_skill` — root `SKILL.md` only
4. `skill_bundle` — nested `skills/<name>/SKILL.md` (apm.yml optional)
5. `apm_package` — `apm.yml` AND (`.apm/` content OR declared dependencies)
   — a bare `apm.yml` with neither is INVALID; do not emit such dirs
6. `hook_package` — `hooks/*.json`, nothing else
7. invalid — no signals

Single primitive files (`*.instructions.md`, `*.agent.md`, ...) are importable
as virtual single-file deps.

### Discovery: fixed roots, marker-based walks (17 units today)

Discovery does NOT re-implement the cascade over arbitrary dirs. It walks
exactly four top-level roots; each has a marker that both identifies a unit
and stops the descent (structure under each root may deepen later, so walks
are recursive until the marker):

| Root            | Marker (stop descending here)                     | Unit      | Kind                            |
| --------------- | ------------------------------------------------- | --------- | ------------------------------- |
| `apm-package/`  | dir containing `.apm/`                            | that dir  | apm package (1)                 |
| `hooks/`        | dir containing a `hooks/` subdirectory            | that dir  | hook virtual package (4)        |
| `instructions/` | file suffixed `.instructions.md`                  | that file | instruction virtual package (5) |
| `plugins/`      | dir containing `plugin.json` or `.claude-plugin/` | that dir  | marketplace plugin (0)          |
| `skills/`       | dir containing `SKILL.md`                         | that dir  | skill (7)                       |

- `apm-package/` units must have BOTH `.apm/` and `apm.y[a]ml` (repo
  invariant). A marker dir missing `apm.y[a]ml` is a hard error to stderr,
  exit 1 — fail closed rather than index a broken package.
- A root that does not exist is skipped silently (`plugins/` has no members in
  this repo yet; apm defines the package type, so the walk is ready for it).
- Everything outside these roots is never visited (no exclusion list needed).
  `--exclude <glob>` (repeatable, default none) skips units whose repo-relative
  path matches the glob.
- The cascade section above remains the reference for WHY these units are
  importable to apm (e.g. `cc-workers` actually classifies as
  marketplace_plugin via its `.claude-plugin/plugin.json` — irrelevant to
  emission, the dep path is the same).

## Generated apm.yml shape

The emitted file is a TEMPLATE placed in OTHER repos (as their project apm.yml,
or its deps merged in); each package is fetched from GitHub. Every entry
therefore carries this repo's explicit git reference in object form:
`git: <current-git-without-protocol-scheme>` + `path:`. The scheme-less
shorthand `github.com/user/repo` is a verified valid `git:` value
(`_resolve_shorthand_to_parsed_url`, `models/dependency/reference.py:1530`;
allowed remote-git keys are `{alias, allow_insecure, git, path, ref, skills,
targets, type}`).

```yaml
---
name: example
version: 0.0.1
description: example output
targets:
  - claude
  - codex
dependencies:
  apm:
    - git: github.com/ngicks/agents-package
      path: apm-package/cc-workers
    - git: github.com/ngicks/agents-package
      path: hooks/go-vet-ngcheckers
    - git: github.com/ngicks/agents-package
      path: skills/go-edit-cobra
    # ... sorted lexicographically within kind, kinds in fixed order
  mcp: []
```

- The `git:` value is derived from the current repo: `git remote get-url origin`
  (via `@process`), normalized — strip `https://` / `ssh://` scheme, rewrite
  `git@host:owner/repo` to `host/owner/repo`, strip trailing `.git`.
  `--git <url>` overrides the derivation (also what acceptance tests use).
  AMENDED: a pre-path colon is rewritten to `/` only for the scheme-less scp
  form; when the URL carried a `<scheme>://`, that colon is a port and is kept
  (`https://host:8443/o/r.git` → `host:8443/o/r`, which apm's shorthand parser
  accepts).
- Entries are unpinned by default: consumers track the default branch, which is
  the "keep up with updates" goal. Optional `--ref <ref>` adds `ref: <ref>` to
  every entry for consumers who want pinning.
- Per-entry deploy targets are deliberately NOT emitted — deployment follows the
  top-level `targets:` (and each child package's declared `targets`). Note:
  `targets` would be a legal per-entry key, but it's the consumer's call, not
  the template's.
  AMENDED: a top-level `targets:` IS emitted, defaulting to `claude`, `codex`
  (apm 0.26 refuses to install without an explicit target declaration, so the
  template must ship one to be installable as-is). Repeatable `--target <t>`
  replaces the default pair; consumers edit the list after adoption.
- Determinism: fixed kind order (apm-package, hooks, instructions, plugins,
  skills), then lexicographic sort inside each kind. Same tree in →
  byte-identical file out.
- Instruction files ride the same form with `path:` pointing at the file;
  confirm during acceptance that virtual single-file paths deploy (string-form
  single-file deps are documented, so this should hold).

## Output & error semantics

- stdout is the document interface: nothing but YAML is ever written to stdout.
- Errors (and any diagnostics) go to stderr via `@stdio`; exit codes:
  0 success, 1 IO/discovery failure, 2 usage error (caught argparse raise —
  its message already embeds the help text; print verbatim to stderr).
- `-o/--output <path>`: create parent directories, write to a temp file in the
  same directory, then `@fs.rename` over the target (atomic, no torn files).
  Overwrites silently — regeneration is the point. Output always ends with `\n`.

## CLI shape

```
tool gen-apm-yml [--root <repo-root>] [--name <pkg-name>] [--pkg-version <ver>]
                 [--git <url>] [--ref <ref>] [-o <path>] [--exclude <glob>]...
                 [--target <t>]...
```

- `--root` defaults to `.` (run from repo root; realpath'd before scanning).
- `--name` defaults to `agents-package-index`, `--pkg-version` to `0.0.1`.
- `--git <url>` overrides the derived repo reference; `--ref <ref>` pins every
  entry (both default off — see the shape section).
- `--exclude <glob>` (repeatable, default none) skips discovered units by glob
  against the repo-relative path (`/`-separated): `*` and `?` match within a
  path segment, `**` crosses segments (e.g. `instructions/**`,
  `skills/go-*`). Hand-rolled matcher in `discover` — pure and unit-tested;
  core has no glob package.
- `--target <t>` (repeatable) sets the emitted top-level `targets:` list;
  when absent the default pair `claude`, `codex` is emitted.
- Output is a template for other repos, not a package of this one. If a
  generated copy is committed here for reference, keep it OUTSIDE the walked
  roots (e.g. repo root) so it can never be discovered.

## Code organization

```
.tool/
  PLAN.md
  moon.mod              # name = "ngicks/agents-package-tool"; preferred_target = "native"
                        # deps: moonbit-community/yaml, moonbitlang/async
  apmyml/               # apm.yml document model + emitter (no IO)
  discover/             # importable-unit discovery (thin IO + pure classification)
  cmd/
    main/               # argparse wiring + dispatch + exit-code FFI only
```

`.gitignore` in `.tool/`: `_build/`, `.mooncakes/`.

### Pub API per package

`apmyml` — knows nothing about the filesystem:

Names mirror the manifest schema
(microsoft.github.io/apm/reference/manifest-schema/, §4.1.2 object form):

```moonbit
pub struct Manifest {
  name : String
  version : String
  description : String?
  dependencies : Dependencies
}
pub struct Dependencies {
  apm : Array[ApmDependency]
  mcp : Array[McpDependency]   // always empty today; type kept for schema parity
}
pub struct ApmDependency {
  git : String    // clone URL / FQDN shorthand
  path : String   // subdirectory or file within the repo
  ref : String?   // branch, tag, or commit SHA; omitted when unpinned
  // alias / type / allow_insecure / skills / targets: legal per schema, not emitted
}
pub fn Manifest::to_yaml(Self) -> @yaml.Yaml   // insertion-ordered Map
```

`discover` — one async entry doing IO; one marker-walk per fixed root, the
marker predicates as pure helpers:

```moonbit
pub(all) enum Kind { ApmPackage; HookPackage; InstructionFile; MarketplacePlugin; Skill }
pub struct ApmUnit {
  repo_path : String   // e.g. "skills/go-edit-cobra", '/'-separated, repo-relative
  kind : Kind
}
pub async fn discover(root : String, exclude~ : Array[String]) -> Array[ApmUnit] raise
pub fn glob_match(pattern : String, path : String) -> Bool
```

`cmd/main` — builds the `Command` tree, dispatches on `matches.subcommand`,
`try/catch` at top level printing to stderr and calling the `exit` FFI.
Adding a future subcommand = one new `Command` in the array + one dispatch arm.

## Testing & acceptance

- `apmyml`: snapshot tests (`inspect`) for `emit` — key order, git-object
  entry shape (with and without `ref:`), quoting, empty `mcp`.
- `discover`: marker predicates unit-tested; `discover` integration-tested
  against a fixture tree under `@fs.tmpdir` (native target) covering: nested
  units (marker deeper than one level, walk stops descending at it), an
  apm-package marker dir (`.apm/`) missing `apm.y[a]ml` (hard error), both
  plugin markers (`plugin.json`, `.claude-plugin/`), an absent root (skipped
  silently), and `--exclude` glob filtering. `glob_match` gets its own unit
  tests (`*` vs `/` boundary, `**`, `?`, literal match).
- Acceptance (scripted, not eyeballed):
  1. Run against this repo; assert the emitted dep set is exactly the expected
     17 paths — no duplicates, no self-reference, no excluded dirs.
  2. Run twice; assert byte-identical output.
  3. `apm install` in a throwaway consumer repo using the generated file as its
     apm.yml, and assert the lockfile contains all 17 units.
     AMENDED during implementation: the `file://` premise was wrong — apm 0.26
     rejects `file://` git URLs by design ("file:// paths are rejected for
     security"); its `git_file_transport` is a sparse-checkout fetcher for
     git/ssh repos, not a `file://` clone transport. The e2e therefore uses the
     real GitHub URL (network required; skipped only when a `git ls-remote`
     probe fails). apm 0.26 also refuses to install without a top-level
     `targets:` declaration — originally a consumer-added key, now shipped in
     the template itself (default `claude`, `codex`), so the generated file is
     installable as-is.
- Housekeeping: `moon info && moon fmt && moon check --target native &&
moon test --target native` (never bare `moon check` — the module targets
  native and `@fs` is native-only).

## Implementation order

1. Scaffold in `.tool/`: `moon.mod` (`preferred_target = "native"`), deps,
   `.gitignore`, exit FFI stub in `cmd/main`.
2. `apmyml` model + emitter + snapshot tests.
3. `discover` marker walks + async discovery + fixture test.
4. `cmd/main` wiring (stderr/exit-code paths included), acceptance script,
   optionally commit a generated reference copy at repo root (outside the
   walked roots).

## Open decisions (defaults chosen, flag-able later)

- Leading `---` document marker kept (emitter hardcodes it; harmless to apm).
- `version` in the template is static (`--pkg-version`); consumers own it after
  adoption — apm tracks git refs, not this version, for updates.
- Top-level `targets:` is emitted, defaulting to `claude`, `codex` (repeatable
  `--target` replaces the pair) — apm refuses to install without one, so the
  template must be installable as-is; per-entry `targets:` was considered and
  dropped (consumer's call, not the template's).
