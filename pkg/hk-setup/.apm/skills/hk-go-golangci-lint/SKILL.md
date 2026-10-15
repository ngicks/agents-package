---
name: hk-go-golangci-lint
description: Scaffold an hk-managed git pre-commit hook that formats and lints Go code with golangci-lint.
disable-model-invocation: true
---

# hk-go-golangci-lint

Wire a pre-commit hook into the current repository through [hk](https://hk.jdx.dev).
The hook runs two steps on staged `*.go` files:

- `golangci-lint-fmt`: `golangci-lint fmt` on the staged files; hk stages the fixes.
- `golangci-lint`: `golangci-lint run` in each Go module that holds a staged file.
  - `--fix` runs too, because the hook sets `fix = true`.

## Requirements

- `hk` 2.x and `golangci-lint` v2 on `PATH`.
  - `hk` missing is blocking; the script stops and says so.
- A git repository with a `go.mod`.

## Steps

1. Run `scripts/hk-init.sh` from this skill's directory, with the target repository as the working directory.
   - It copies `reference/go-golangci-lint.hk.pkl` to `.hk/go-golangci-lint.pkl`,
     pinned to the hk version the project already uses.
   - It creates `hk.pkl` when the repository has none.
   - It validates the config and runs `hk install`.
2. If the script exits 1 with wiring instructions, `hk.pkl` already exists.
   - Add the printed `import` line after its `amends` line.
   - Add the printed `...go_golangci_lint.steps` line into the `steps` of `hooks["pre-commit"]`;
     create that hook when it is missing.
   - Rerun the script; it exits 0 once wired.
3. Commit `hk.pkl` and `.hk/go-golangci-lint.pkl`.
   - A worktree without them runs no hooks.

## Notes

- Do not edit `.hk/go-golangci-lint.pkl`; rerun the script to update it.
- Put project-specific steps in `hk.pkl`.
- `hk run pre-commit` runs the hook against the staged files without committing.
