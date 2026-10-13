---
description: "Format and lint Python code with ruff"
applyTo: ""
---

### Python formatting and linting

The pre-commit hook formats and lints staged Python files with ruff.
Use the same commands while editing.

- Format with `ruff format <files>`.
- Lint with `ruff check <files>`.
  - Add `--fix` to apply automatic fixes.
- Do not run `black`, `isort`, `flake8`, or `pylint`.
