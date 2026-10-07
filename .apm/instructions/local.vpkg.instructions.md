---
description: "Layout rules for the single-primitive packages under vpkg/"
applyTo: "vpkg/**"
---

### vpkg layout

`vpkg/` holds single-primitive units that consumers pick and swap one by one.
The `v` stands for virtual: apm installs a unit straight from its subdir path without a manifest.
Units are grouped by kind, and each kind has one shape.

- `vpkg/skills/<name>/SKILL.md`: a skill.
  - Consumers depend on `ngicks/agents-package/vpkg/skills/<name>`.
  - Do not add `apm.yml`; a root `SKILL.md` already makes the directory installable.
- `vpkg/instructions/<name>.instructions.md`: a single instruction file.
  - Consumers depend on the file path itself.
- `vpkg/hooks/<name>/`: a hook, wrapped in an apm package.
  - `apm.yml` plus `.apm/hooks/<name>.json`.

Keep the directory or file stem unique across `pkg/`, `vpkg/*/`, `mods/`, and `bundle/`.
apm resolves a semver ref such as `#^1.0.0` against tags named `<leaf>-v<version>` or `<leaf>--v<version>`,
where `<leaf>` is the last path segment only.

### Hooks carry apm.yml as a workaround

A hook is the only virtual kind that gets `apm.yml`.
apm could not install a bare hook directory (`hooks/*.json`, nothing else) as a virtual package.
The `apm.yml` wrapper turns it into an ordinary apm package that installs.

- Keep `apm.yml` minimal: name, version, description, author, license, repository, targets, `includes: auto`.
- Name the JSON file after the directory (`vpkg/hooks/<name>/.apm/hooks/<name>.json`).
- Undo the workaround once apm installs bare hook directories:
  delete `apm.yml` and move `.apm/hooks/<name>.json` to `hooks/hook.json`.

### Verify before shipping

Install the unit into a scratch consumer:

```bash
mkdir -p /tmp/apm-consumer && cd /tmp/apm-consumer
printf 'name: c\nversion: 0.0.1\ntargets: [claude]\ndependencies:\n  apm:\n  - %s\n  mcp: []\n' \
  "/abs/path/to/agents-package/main/vpkg/<kind>/<name>" > apm.yml
apm install --update -t claude
```

- A hook must show `hook(s) integrated`.
- A skill must show `Skill integrated`.
- An instruction must show `rule(s) integrated`.
  - apm cannot install a single file from a local path ("Local package path does not exist").
    Verify an instruction after pushing, with `ngicks/agents-package/vpkg/instructions/<name>.instructions.md#<branch>`.
