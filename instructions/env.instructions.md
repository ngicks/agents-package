---
description: "Basic instructions for my env"
applyTo: "*"
---

### Basics

- Use `context7` for tool specific knowledge.
- You might be in a restricted enviroment: some commands may fail and some special files may not be present (e.g. `/dev/kvm`).
- Do not assume `perl` is installed in the environment.
- You may ask back the user to resolve unclear corners, using `AskUserQuestion` (if available) or just a response.
- If you are `claude code`: `codex` will review your output
- If you are `codex`: `claude code` will review your output
