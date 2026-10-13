---
description: "Check mermaid diagrams with mermaid-lint"
applyTo: ""
---

### Mermaid diagrams

The pre-commit hook lints mermaid diagrams in staged markdown and `.mmd` files with mermaid-lint.
Use the same command while editing.

- After editing a mermaid diagram, run `mermaid-lint <files>`.
  - Add `--fix` to repair mechanical errors such as arrows and missing colons.
