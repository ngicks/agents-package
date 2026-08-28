# General CLI design rules

Framework-neutral rules for every CLI this skill touches — std `flag` and Cobra alike.

Read this together with the framework-specific file the pre-flight checks selected:
[cli-cobra.md](cli-cobra.md) for a Cobra command tree, [cli-std-flag.md](cli-std-flag.md) for a std-`flag` single-command CLI.

The framework **choice** itself (and how a recorded decision overrides it) lives in SKILL.md › Pre-flight checks; this file only holds the rules shared by both shapes.

## Contents

- [Errors & process exit](#errors--process-exit)
- [Positional arguments vs flags](#positional-arguments-vs-flags)
- [Thin wiring under `./cmd`](#thin-wiring-under-cmd)

## Errors & process exit

- **Return errors up the call chain; only `main` calls `os.Exit`.**

  Run functions and command bodies never `os.Exit`, never `log.Fatal`, and never panic on an expected failure — they return the error.

- `main` owns the single exit site: print the final error to stderr, exit non-zero.

  The scaffolded `main.go` ([command-templates.md](command-templates.md#cmdnamemaingo)) additionally recovers the signal cause on cancellation; that template's error handling applies to both framework shapes.

## Positional arguments vs flags

- Positional args are the natural shape when the command operates on a target (`mytool inspect <path>`, `mytool delete <id>...`).

  Flags are for options **on top of** that target, not a replacement for it — `mytool inspect --path <path>` is an anti-pattern.
- Validate the positional-arg count explicitly (each framework file shows its mechanism), and fail with a message naming what was expected.

## Thin wiring under `./cmd`

- Run functions are **thin wiring**: read flags and positional args, construct/call a service from the service package, return its error.

  Business logic is forbidden under `./cmd` (SKILL.md › General design rules).
- CLI-presentation code (printing, prompts, tables, color) lives in `<root>/<name-without-separator>/cli/`, not under `./cmd` — see [layout-and-naming.md](layout-and-naming.md).
- Service-config flags are never bound directly into the service's `Config`; bind to locals and overlay only the explicitly-set ones — see [configuration.md › Flag overlay](configuration.md#flag-overlay-the-flags-win-step-in-cmd). Each framework file shows its set-vs-unset mechanism (`Changed` / `fs.Visit`).
