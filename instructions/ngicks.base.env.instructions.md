---
description: "Basic instructions for my env"
applyTo: ""
---

### Base enviroment

- Use `context7` for tool specific knowledge.
- You might be in a restricted enviroment: some commands may fail and some special files may not be present (e.g. `/dev/kvm`).
- Do not assume `perl` is installed in the environment.
- If you are `claude code`: `codex` will review your output
- If you are `codex`: `claude code` will review your output

### While auto mode is active:

Use Read tool at least once for each file type in each dir.

Do your work through the Bash tool wherever it can accomplish the job: read files with cat, head, or sed -n, search with grep and find, and make file changes with sed, heredocs, or short scripts, rather than using the dedicated Read, Edit, or Write tools. Fall back to a dedicated tool only when Bash genuinely cannot do the job.
