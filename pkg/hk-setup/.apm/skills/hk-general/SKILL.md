---
name: hk-general
description: Scaffold an hk-managed git pre-commit hook with language-independent checks; it rejects large files that are not tracked by git LFS.
disable-model-invocation: true
---

# hk-general

Wire a pre-commit hook into the current repository through [hk](https://hk.jdx.dev).
The hook runs one step on every staged file:

- `no-large-files`: fails the commit when a staged file is 100 MiB or larger.
  - It measures the staged blob, so a file tracked by git LFS passes: its blob is a small pointer.
  - 100 MiB is the smaller of the GitHub and GitLab.com per-file push limits.
  - It applies to text and binary files alike.
  - It prints each offending path with its size.

## Requirements

- `hk` 2.2 or newer on `PATH`.
  - `hk` missing is blocking; the script stops and says so.
- `git` 2.42 or newer.
  - The step uses `git ls-files --format='%(objectsize)'`; an older git fails the step.
- A git repository.

## Steps

1. Run `scripts/hk-init.sh` from this skill's directory, with the target repository as the working directory.
   - It copies `reference/general.hk.pkl` to `.hk/general.pkl`,
     pinned to the hk version the project already uses.
   - It creates `hk.pkl` when the repository has none.
   - It validates the config and runs `hk install`.
2. If the script exits 1 with wiring instructions, `hk.pkl` already exists.
   - Add the printed `import` line after its `amends` line.
   - Add the printed `...general.steps` line into the `steps` of `hooks["pre-commit"]`;
     create that hook when it is missing.
   - Rerun the script; it exits 0 once wired.
3. Commit `hk.pkl` and `.hk/general.pkl`.
   - A worktree without them runs no hooks.

## Changing a scaffolded step

`hk.pkl` changes a step of the fragment by amending the fragment's `steps` in a `local`.
This example lowers the limit to 50 MiB; `HK_LARGE_FILE_MAX_BYTES` takes bytes.

```pkl
local general_steps = (general.steps) {
  ["no-large-files"] {
    env { ["HK_LARGE_FILE_MAX_BYTES"] = "52428800" }
  }
}
```

- Replace `...general.steps` with `...general_steps` in the `steps` of `hooks["pre-commit"]`.
- The block sets only the fields it names; the step keeps every other field.
- Do not redefine `["no-large-files"]` after `...general.steps` inside `steps`.
  - Pkl rejects it with "Duplicate definition of member".
  - Every `git commit` then fails before any step runs.
- Run `hk validate` after the change.

## Notes

- Do not edit `.hk/general.pkl`; rerun the script to update it.
- Put project-specific steps in `hk.pkl`.
  - Change a scaffolded step there too; see "Changing a scaffolded step".
- To commit a large file, track it with git LFS first: `git lfs track <pattern>`, then stage `.gitattributes` and the file again.
- The hook does not run under `git commit --no-verify`, and it does not inspect commits that already exist.
- `hk run pre-commit` runs the hook against the staged files without committing.
