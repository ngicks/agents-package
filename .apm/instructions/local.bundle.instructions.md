---
description: "Layout rules for the bundles under bundle/"
applyTo: ""
---

### bundle layout

Each directory under `bundle/` holds one hand-curated `apm.yml` that lists units from `pkg/`, `vpkg/`, and `mods/`.
A bundle serves two uses with the same file.

- Consumers copy it in as their own `apm.yml`, then edit `name`, `targets`, and the dependency list.
- Consumers depend on it (`ngicks/agents-package/bundle/<name>`) to install every listed unit in one shot.

### Rules

- Write every dependency as a full repository path (`ngicks/agents-package/vpkg/skills/<name>`),
  in either the shorthand string form or the `git:` + `path:` object form.
  - Relative or local paths break once the file is copied elsewhere.
- Set `targets: [codex]` on every instruction dependency of a project-scope bundle (e.g. `go`, `moonbit`).
  - `apm compile` merges instructions into `AGENTS.md`, and Claude Code reads that file.
  - A `claude` target would also deploy them as `.claude/rules/`, so Claude would load each rule twice.
  - The `agents` target is an alias of `copilot`. Use `codex` to compile instructions into `AGENTS.md` without installing them.
  - A consumer who copies the bundle in must keep `codex` in `targets`, or the instructions reach no file.
- Do not limit instruction dependencies to `targets: [codex]` in a user-scope bundle (e.g. `myenv`).
  - A user-scope bundle installs under `~/.apm`, where Claude Code reads no compiled `AGENTS.md`.
  - Claude then sees the instructions only through its `claude` target (`.claude/rules/`).
- Do not depend on another bundle.
  - Copying one in would pull the other in without the reader seeing its list.
- Do not list a `vpkg/` unit that a listed `pkg/` package already ships.
  - apm would install the same primitive twice.
- List `mods/` only in a user-scope bundle, one meant for `apm install -g` (e.g. `myenv`).
  - Mods are user-scope installs; a project bundle leaves them out.
  - Say which scope a bundle targets in its `description`.

### Verify before shipping

A bundle resolves its dependencies from GitHub, so it only verifies after the units it lists are pushed.

```bash
mkdir -p /tmp/apm-consumer && cd /tmp/apm-consumer
cp /abs/path/to/agents-package/main/bundle/<name>/apm.yml apm.yml
apm install --update -t claude,codex
```

- For a project-scope bundle, every instruction must appear in `AGENTS.md` after `apm compile`, and `.claude/rules/` must stay empty.
