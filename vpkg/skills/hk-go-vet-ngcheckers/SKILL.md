---
name: hk-go-vet-ngcheckers
description: Scaffold an hk-managed git pre-commit hook that runs go vet with the ngcheckers analyzers.
disable-model-invocation: true
---

# hk-go-vet-ngcheckers

Wire a pre-commit hook into the current repository through [hk](https://hk.jdx.dev).
The hook runs one step when `*.go` files are staged:

- `go-vet-ngcheckers`: `go vet -vettool=<ngcheckers> ./...` in each Go module that holds a staged file.

## Requirements

- `hk` 2.x, `go`, and `ngcheckers` on `PATH`.
  - `hk` missing is blocking; the script stops and says so.
  - `ngcheckers` missing fails the step with "ngcheckers is not installed".
  - Install it with `go install github.com/ngicks/go-ngcheckers/cmd/ngcheckers@latest`.
- A git repository with a `go.mod`.

## Steps

1. Run `scripts/hk-init.sh` from this skill's directory, with the target repository as the working directory.
   - It copies `reference/go-vet-ngcheckers.hk.pkl` to `.hk/go-vet-ngcheckers.pkl`,
     pinned to the hk version the project already uses.
   - It creates `hk.pkl` when the repository has none.
   - It validates the config and runs `hk install`.
2. If the script exits 1 with wiring instructions, `hk.pkl` already exists.
   - Add the printed `import` line after its `amends` line.
   - Add the printed `...go_vet_ngcheckers.steps` line into the `steps` of `hooks["pre-commit"]`;
     create that hook when it is missing.
   - Rerun the script; it exits 0 once wired.
3. Commit `hk.pkl` and `.hk/go-vet-ngcheckers.pkl`.
   - A worktree without them runs no hooks.

## Notes

- Do not edit `.hk/go-vet-ngcheckers.pkl`; rerun the script to update it.
- Put project-specific steps in `hk.pkl`.
- `hk run pre-commit` runs the hook against the staged files without committing.
