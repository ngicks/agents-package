# User directories (XDG base dirs & platform equivalents)

Where a CLI writes per-user files that are **not** the config file — caches, downloaded data, logs / history, sockets / locks — and the always-copied `internal/userdir` helper that resolves the base directories stdlib lacks.

The split: the **helper** is app-agnostic base-dir resolution (real logic, copied verbatim); the **app-specific layer** — appending `/<name>`, merging overrides (config fields, env vars à la `$<NAME>_CONF`) — is scaffolded per project (see [The app-specific layer](#the-app-specific-layer-appending-name--overrides)).

Config-**file** resolution is out of scope here: it stays in `<name-without-separator>/config.go`, owned by `configPath` (see [configuration.md › Config-file path resolution](configuration.md#config-file-path-resolution)).

Also out of scope: the rest of the XDG base-dir spec that is not a per-user **write** location — the system-wide search paths `$XDG_CONFIG_DIRS` / `$XDG_DATA_DIRS` (these CLIs load one user config file, no system-config overlay) and `~/.local/bin` (an install target for packagers, not a directory the app writes to at runtime).

## Contents

- [The convention](#the-convention) — the directory-kind table
- [Rules](#rules) — suffix, home-dir, stdlib-vs-hand-rolled, creation semantics
- [Which directory for which file](#which-directory-for-which-file) — cache vs data vs state vs runtime
- [Runtime dir: no spec default](#runtime-dir-no-spec-default)
- [The `internal/userdir` helper (copied verbatim)](#the-internaluserdir-helper-copied-verbatim)
- [The app-specific layer: appending `/<name>` & overrides](#the-app-specific-layer-appending-name--overrides)

## The convention

Every per-app directory is a **base directory** plus a **`/<name>` suffix** (the project name verbatim — the same spelling as `defaultConfigDir`).

Base resolvers return the base only — the suffix is appended by the app-specific layer.

The base resolves per platform; XDG env overrides are honored on Unix only, mirroring how the Go stdlib behaves (see [Rules](#rules)).

| Kind        | Base resolver                           | Unix (Linux, BSD, ...)                                                | macOS                           | Windows          |
| ----------- | --------------------------------------- | --------------------------------------------------------------------- | ------------------------------- | ---------------- |
| **config**  | `os.UserConfigDir()`                    | `$XDG_CONFIG_HOME`, else `~/.config`                                  | `~/Library/Application Support` | `%AppData%`      |
| **cache**   | `os.UserCacheDir()`                     | `$XDG_CACHE_HOME`, else `~/.cache`                                    | `~/Library/Caches`              | `%LocalAppData%` |
| **data**    | `userdir.Data()`                        | `$XDG_DATA_HOME`, else `~/.local/share`                               | `~/Library/Application Support` | `%AppData%`      |
| **state**   | `userdir.State()`                       | `$XDG_STATE_HOME`, else `~/.local/state`                              | `~/Library/Application Support` | `%LocalAppData%` |
| **runtime** | `userdir.Runtime()`                     | `$XDG_RUNTIME_DIR` — **no default**; unset → temp fallback, see below | temp fallback                   | temp fallback    |
| **home**    | `os.UserHomeDir()` — **no suffix ever** | `$HOME`                                                               | `$HOME`                         | `%USERPROFILE%`  |

Those three carry real resolution logic, so they live in the app-agnostic `internal/userdir` helper (copied verbatim into every project), structured to mirror the stdlib resolvers.

Config and cache need no helper — use `os.UserConfigDir` / `os.UserCacheDir` directly.

The non-Linux **data / state** mappings are a deliberate choice (there is no platform consensus; third-party libraries differ): data follows `os.UserConfigDir`'s platform-native locations (durable, user-facing, roams on Windows), state goes to the machine-local equivalent on Windows (`%LocalAppData%` — logs and history should not roam) and to `Application Support` on macOS (`~/Library/Caches` is purgeable by the OS, which state must survive).

## Rules

- **Always suffix `/<name>`** — the project name verbatim, one flat subdirectory, no vendor/org nesting.

  The suffix is appended in the app-specific layer (`filepath.Join(base, "<name>")`), never inside the helper.

  Keep the spelling identical everywhere: `defaultConfigDir` in `config.go` and every `Join` call site.

- **The home directory takes no per-app subdirectory.**

  `os.UserHomeDir()` is for resolving _user-given_ paths (e.g. expanding `~` in a flag value) — never for placing app files.

  A `~/.<name>` dotdir is the legacy layout the XDG spec replaces; creating one is an anti-pattern (see [layout-and-naming.md › Anti-patterns](layout-and-naming.md#anti-patterns)).

- **Use the stdlib resolver when one exists; never hand-build the path.**

  `os.UserConfigDir()` / `os.UserCacheDir()` already consult `$XDG_CONFIG_HOME` / `$XDG_CACHE_HOME` and are platform-native on macOS / Windows; hand-built `$HOME/.config/...` or `$HOME/.cache/...` breaks both.

  For data / state / runtime — where stdlib has no resolver — use the `internal/userdir` helper, not ad-hoc `os.Getenv` at call sites.

- **XDG env vars are honored on Unix only**, matching stdlib: `os.UserConfigDir()` ignores `$XDG_CONFIG_HOME` on macOS / Windows, and the `userdir` helper mirrors that (its `switch runtime.GOOS` shape is lifted from the stdlib resolvers).

  Do not "fix" this by also reading XDG vars on darwin/windows — consistency with stdlib beats cross-platform XDG purism.

- **Resolvers never touch the filesystem.** Every function returns a path (or an error); nothing is created at resolve time.

  Create at first **write**, with `os.MkdirAll(dir, 0o700)` — the XDG spec mandates 0700 for base directories it creates, and the per-app **runtime** subdirectory MUST be 0700 (it holds sockets).

  0700 is the uniform safe choice for the per-app subdirs; relax deliberately if a dir must be shared.

- **Propagate resolver errors** — same rule as `os.UserConfigDir` in `configPath`: when no directory is resolvable, return the error; do not silently fall back to `.` or `$HOME`.

  (The one built-in degradation is `Runtime()`'s temp fallback — see [Runtime dir](#runtime-dir-no-spec-default).)

- **Per-app dir overrides merge in the app-specific layer, as `Config` fields.**

  When a user must be able to relocate a dir per-app (e.g. a cache on a big disk), add a `Config` field: file/env/flag layered like any other, empty value → the convention default.

  The `env:` tag gives it a `<NAME>_DATA_DIR`-style env var for free through the standard env layer — do not add hand-read `os.Getenv` calls; `$<NAME>_CONF` stays the only hand-read variable, and the helper reads only the XDG/platform vars.

## Which directory for which file

Pick by what deleting the file costs the user:

- **cache** — fully disposable; the app rebuilds it on demand.
  Deleting it costs only time (re-download, re-index).
  Examples: HTTP caches, compiled indexes, extracted archives.
- **data** — durable, user-valued data the app manages.
  Deleting it loses something the user cares about.
  Examples: downloaded resources, installed plugins, an app-managed database.
- **state** — persisted but non-portable/re-creatable app state.
  Deleting it loses convenience, not data.
  Examples: logs, command history, cursors ("last sync at ..."), window layout.
- **runtime** — exists only for the login session; gone at logout/reboot.
  Examples: Unix sockets, named pipes, lock files.
- **config** — user-authored settings; the config file and any sidecar files the user edits.

When in doubt between data and state: "would the user want this in a backup / on their next machine?" — yes → data, no → state.

## Runtime dir: no spec default

The XDG spec deliberately defines **no fallback** for `$XDG_RUNTIME_DIR` — `/run/user/$UID` is what systemd's `pam_systemd` provides on login, not a spec default an app may assume (on non-systemd Unix it typically doesn't exist).

The spec's requirements (owned by the user, mode 0700, on a local filesystem, cleared at logout) can't be met by guessing a path, so the helper degrades instead of guessing a spec-compliant one:

- When `$XDG_RUNTIME_DIR` is unset — and always on macOS / Windows, which have no session-runtime equivalent — `userdir.Runtime()` returns the fallback base `os.TempDir()/runtime-<uid>` instead of an error.
  - The `-<uid>` suffix disambiguates the shared `/tmp` on Unix (`os.Getuid` is -1 on Windows — harmless; `os.TempDir` is already per-user there).
- The degradation is **warned in the helper's doc-comment, not at runtime** — callers use the result unconditionally:

```go
base, err := userdir.Runtime()
if err != nil { // only a relative $XDG_RUNTIME_DIR
	return err
}
dir := filepath.Join(base, "{{NAME}}")
if err := os.MkdirAll(dir, 0o700); err != nil {
	return err
}
```

What the fallback loses (the doc-comment's warning, spelled out):

- **No logout-time cleanup** — remove what you create (`defer os.Remove(sock)`).
- **On shared `/tmp` the uid dir can be pre-created by another user** — `os.MkdirAll` silently accepts an existing dir; verify ownership/mode if that matters.
- **No signal that a fallback happened** — a feature that truly requires session scoping (a daemon socket that must die with the login session) must check `$XDG_RUNTIME_DIR` / `runtime.GOOS` itself and fail; `Runtime()` will not error for it.

### "Must stay in tmpfs" is not a portable requirement

`/run/user/$UID` being tmpfs is systemd's choice, not an XDG guarantee (the spec promises only local, 0700, session-scoped) — never design against "tmpfs"; pick the mechanism by what it was actually buying:

- **IPC endpoints** (sockets, pipes, locks) — the medium is irrelevant: a 0700 dir under `os.TempDir()` on macOS, named pipes (`\\.\pipe\<name>`) on Windows.
- **Secrets** — no directory at all: process memory, inherited fds, or OS keystores (Keychain, DPAPI, libsecret).
- **Ephemerality** — cleanup semantics, not the medium: `os.TempDir()` + `O_EXCL` + `defer os.Remove`; memory-backed files (`memfd_create`) are a Linux-only optimization, never the portable path.
- **Write-heavy disposable files** — drop the `fsync`s and bound the size first (page-cache coherence keeps unflushed appends visible to other processes); RAM-backed placement is a Linux-only bonus.

A CLI never mounts a RAM disk. The helper stays unchanged either way — its temp fallback already covers the IPC-endpoint row on macOS (Windows callers wanting named pipes still choose those themselves); the other rows are design decisions, not paths a resolver can hand out.

## The `internal/userdir` helper (copied verbatim)

App-agnostic — no project identifiers; full source and tests live at `${SKILL-DIR}/helpers/internal/userdir/`, copied into every project by `copy_helper.sh` (see [workflows.md › Helper catalog](workflows.md#helper-catalog)).

It contains exactly the resolution logic stdlib lacks, and nothing app-specific:

- `Data() (string, error)` — base data dir.
- `State() (string, error)` — base state dir.
- `Runtime() (string, error)` — base runtime dir; unset `$XDG_RUNTIME_DIR` or non-Unix → per-user fallback under `os.TempDir()`, warned in its doc-comment (errors only on a relative `$XDG_RUNTIME_DIR`).

Notes:

- No `Config()` / `Cache()` wrappers — those bases are `os.UserConfigDir()` / `os.UserCacheDir()`, called directly.
- Copied always, imported on demand: an uncalled package is harmless; the compiler drops it from the binary.
- **plan9** is not covered (the `default` branch treats it as Unix); mirror `os.UserConfigDir`'s plan9 case if you actually target it.

## The app-specific layer: appending `/<name>` & overrides

Everything app-specific — the `/<name>` suffix, any user-facing override — is scaffolded per project in the **service package** (the same home as `config.go`), not in the helper and not inline in run functions.

The minimal shape, for a project that writes state files:

```go
// stateDir returns the directory {{NAME}}'s state files (logs, history) live
// in: Config.StateDir when set, else the platform state base + the app subdir.
// Created at first write with os.MkdirAll(dir, 0o700).
func (c Config) stateDir() (string, error) {
	if c.StateDir != "" {
		return c.StateDir, nil
	}
	base, err := userdir.State()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, defaultConfigDir), nil
}
```

- The suffix reuses `defaultConfigDir` — one constant, one spelling, every per-app dir.
- The override is an ordinary `Config` field (`StateDir string` + `*string` mirror in `PartialConfig`), so it is file-, env- (`<NAME>_STATE_DIR` via the `env:` tag), and flag-settable through the standard layering — no hand-read env vars.
- Add such a method only for the dir kinds the project actually uses; nothing is scaffolded by default.
