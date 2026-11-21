---
name: hk-python-ruff
description: Scaffold an hk-managed git pre-commit hook that formats and lints Python code with ruff.
disable-model-invocation: true
---

# hk-python-ruff

Wire a pre-commit hook into the current repository through [hk](https://hk.jdx.dev).
The hook runs two steps on staged `*.py` files:

- `ruff-format`: `ruff format` on the staged files; hk stages the fixes.
- `ruff`: `ruff check` on the staged files.
  - `--fix` runs too, because the hook sets `fix = true`.
  - Issues ruff cannot fix fail the commit.

## Requirements

- `hk` 2.x and `ruff` on `PATH`.
  - `hk` missing is blocking; the script stops and says so.
- A git repository with Python sources.

## Steps

1. Run `scripts/hk-init.sh` from this skill's directory, with the target repository as the working directory.
   - It copies `reference/python-ruff.hk.pkl` to `.hk/python-ruff.pkl`,
     pinned to the hk version the project already uses.
   - It creates `hk.pkl` when the repository has none.
   - It validates the config and runs `hk install`.
2. If the script exits 1 with wiring instructions, `hk.pkl` already exists.
   - Add the printed `import` line after its `amends` line.
   - Add the printed `...python_ruff.steps` line into the `steps` of `hooks["pre-commit"]`;
     create that hook when it is missing.
   - Rerun the script; it exits 0 once wired.
3. Commit `hk.pkl` and `.hk/python-ruff.pkl`.
   - A worktree without them runs no hooks.

## Changing a scaffolded step

`hk.pkl` changes a step of the fragment by amending the fragment's `steps` in a `local`.

```pkl
local python_ruff_steps = (python_ruff.steps) {
  ["ruff"] {
    env { ["RUFF_NO_CACHE"] = "true" }
  }
}
```

- Replace `...python_ruff.steps` with `...python_ruff_steps` in the `steps` of `hooks["pre-commit"]`.
- The block sets only the fields it names; the step keeps every other field.
- Do not redefine `["ruff"]` after `...python_ruff.steps` inside `steps`.
  - Pkl rejects it with "Duplicate definition of member".
  - Every `git commit` then fails before any step runs.
- Run `hk validate` after the change.

## Notes

- Do not edit `.hk/python-ruff.pkl`; rerun the script to update it.
- Put project-specific steps in `hk.pkl`.
  - Change a scaffolded step there too; see "Changing a scaffolded step".
- Configure ruff itself in `pyproject.toml` or `ruff.toml`; both steps pass `--force-exclude`, so its `exclude` applies.
- `hk run pre-commit` runs the hook against the staged files without committing.
