---
description: "Layout rules for the Claude Code mods under vpkg/mods/"
applyTo: "vpkg/mods/**"
---

### mods layout

Each directory under `vpkg/mods/` is one Claude Code mod shipped as a skill plugin.
Consumers install it with `apm install -g ngicks/agents-package/vpkg/mods/<name>`,
and apm copies the directory whole into `~/.claude/skills/<name>/`.
Claude Code adopts every folder there that holds `.claude-plugin/plugin.json` as `<plugin>@skills-dir`.

- Files of a mod:
  - `SKILL.md`: the skill the plugin carries.
  - `.claude-plugin/plugin.json`: `name`, `version`, `description`, `author`, `"skills": ["./"]`.
  - `hooks/hooks.json`: `{ "description": "...", "modules": ["./register.ts"] }`.
  - `hooks/register.ts` (or `.tsx` when it uses JSX): the hooks module.
  - `tests/*.test.ts`: run with `claude plugin test vpkg/mods/<name>`.

### The plugin manifest is required here

- `vpkg/mods/**` is the opposite of `pkg/**`: keep `.claude-plugin/`.
  - The manifest makes apm detect `package_type: marketplace_plugin` and deploy the folder whole.
  - Claude Code needs the manifest to adopt the skills folder as a plugin.
- Do not put `$schema` in `plugin.json`.
  - apm 0.29.0 refuses a manifest whose `$schema` is Claude Code's plugin schema.
- Do not start the plugin name with `claude-`.
  - Claude Code reserves it; `claude plugin validate` fails.
  - The directory name may still start with `claude-`.

### Keep apm from merging the hooks module into settings

- `hooks/hooks.json` must carry a string key such as `description` beside `modules`.
  - apm merges any `hooks/*.json` whose values are all lists into the user's `settings.json`.
  - A lone `modules` list lands there as a bogus `hooks.modules` entry.

### Verify before shipping

```bash
claude plugin validate vpkg/mods/<name>
claude plugin test vpkg/mods/<name>
```

Then install it globally into a throwaway home and check that Claude Code loads it:

```bash
H=$(mktemp -d) && mkdir -p "$H/.claude"
HOME=$H CLAUDE_CONFIG_DIR=$H/.claude apm install -g -t claude "$PWD/vpkg/mods/<name>"
CLAUDE_CONFIG_DIR=$H/.claude claude plugin list
```

- The lockfile entry must say `package_type: marketplace_plugin`.
- `settings.json` must not gain any `hooks` entry from the mod.
- `claude plugin list` must show `<plugin>@skills-dir` with `Status: ✔ loaded`.
