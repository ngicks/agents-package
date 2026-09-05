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

### Prefer Write|Edit tool

For hooks to work, prefer Write tool

You can use Bash to edit / read files but it disables hooks from working.
After you've done your task, do some innocent edit using Edit tool.
