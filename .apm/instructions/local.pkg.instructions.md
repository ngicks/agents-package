---
description: "Layout rules for the apm packages under pkg/"
applyTo: ""
---

### pkg layout

Each directory under `pkg/` is one self-contained apm package shipping several primitives together.
Consumers depend on it by its monorepo subdir path (`ngicks/agents-package/pkg/<name>`).
Everything a package ships lives under its `.apm/` directory
(`agents/`, `skills/`, `instructions/`, `hooks/`, `prompts/`),
and the metadata lives in its `apm.yml`.

- Keep every instruction conditionless: `applyTo: ""`.
  - Instructions reach agents only through the compiled `AGENTS.md`, which has no path scoping.
- A package never depends on other units in this repository.
  - Copy a primitive into `.apm/` when the package needs it, even if `vpkg/` holds the same one.
- Keep the directory name unique across `pkg/`, `vpkg/*/`, `mods/`, and `bundle/`.
  - apm resolves a semver ref such as `#^1.0.0` against tags named `<leaf>-v<version>` or `<leaf>--v<version>`,
    where `<leaf>` is the last path segment only.

### Never add a Claude plugin manifest

- DO NOT create `.claude-plugin/` (or a root `plugin.json`) inside a package.
  - apm detects package type by a first-match cascade, and a plugin manifest wins over `apm.yml`.
  - The package is then treated as a Claude marketplace plugin, not an APM package.
  - In plugin mode apm maps only a root `skills/` directory into deployable skills;
    `.apm/skills/` is ignored, so the skills silently never deploy.
    Agents under `.apm/agents/` still deploy, so the failure looks like
    "subagents installed, skills missing" with no error printed.
  - This happened once to `cc-workers` and `go-project`.
- `apm.yml` already carries name, version, description, author, license, repository.
  There is nothing a plugin manifest adds.
- If a package must also be a Claude plugin someday,
  mirror `.apm/skills/` and `.apm/agents/` into root `skills/` and `agents/`
  and re-verify the install output shows both "agents integrated" and "skill(s) integrated".

### Verify before shipping

Install the package into a scratch consumer and check every primitive kind deploys:

```bash
mkdir -p /tmp/apm-consumer && cd /tmp/apm-consumer
printf 'name: c\nversion: 0.0.1\ntargets: [claude]\ndependencies:\n  apm:\n  - %s\n  mcp: []\n' \
  "/abs/path/to/agents-package/main/pkg/<name>" > apm.yml
apm install --update -t claude
```

- The lockfile entry must say `package_type: apm_package`.
- The install output must list every kind the package ships:
  `agents integrated`, `skill(s) integrated`, `rule(s) integrated` (instructions), `hook(s) integrated`.
