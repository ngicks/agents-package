---
name: hk-markdown-mermaid-lint
description: Scaffold an hk-managed git pre-commit hook that lints mermaid diagrams in markdown files with mermaid-lint.
disable-model-invocation: true
---

# hk-markdown-mermaid-lint

Wire a pre-commit hook into the current repository through [hk](https://hk.jdx.dev).
The hook runs one step on staged `*.md`, `*.mdx`, `*.markdown`, and `*.mmd` files:

- `mermaid-lint`: `mermaid-lint` on the staged files.
  - `--fix` runs too, because the hook sets `fix = true`.
    It repairs mechanical errors such as arrows and missing colons; hk stages the fixes.
  - Diagrams that still fail to parse fail the commit.

## Requirements

- `hk` 2.x and `mermaid-lint` on `PATH`.
  - `hk` missing is blocking; the script stops and says so.
- A git repository.

## Steps

1. Run `scripts/hk-init.sh` from this skill's directory, with the target repository as the working directory.
   - It copies `reference/markdown-mermaid-lint.hk.pkl` to `.hk/markdown-mermaid-lint.pkl`,
     pinned to the hk version the project already uses.
   - It creates `hk.pkl` when the repository has none.
   - It validates the config and runs `hk install`.
2. If the script exits 1 with wiring instructions, `hk.pkl` already exists.
   - Add the printed `import` line after its `amends` line.
   - Add the printed `...markdown_mermaid_lint.steps` line into the `steps` of `hooks["pre-commit"]`;
     create that hook when it is missing.
   - Rerun the script; it exits 0 once wired.
3. Commit `hk.pkl` and `.hk/markdown-mermaid-lint.pkl`.
   - A worktree without them runs no hooks.

## Notes

- Do not edit `.hk/markdown-mermaid-lint.pkl`; rerun the script to update it.
- Put project-specific steps in `hk.pkl`.
- Configure mermaid-lint itself in `.mermaidlintrc` or `mermaid-lint.config.js`.
- `hk run pre-commit` runs the hook against the staged files without committing.
