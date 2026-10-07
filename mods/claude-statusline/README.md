# claude-statusline

A Claude Code mod that draws a status on a line of its own below the hint line under the prompt:

```
  ⏵⏵ auto mode on (shift+tab to cycle)
  🤖 Opus 5.5 (1M context) @ medium | 🔋 7% used | 📂 /home/u/src/agents-package/main | ⛕ main
```

The cwd is cut from the left so the whole line fits the terminal width.
`SKILL.md` describes each component.

## Install

Install it globally with apm:

```bash
apm install -g ngicks/agents-package/mods/claude-statusline
```

apm copies this folder to `~/.claude/skills/claude-statusline/`.
Claude Code adopts it as the plugin `statusline@skills-dir` in the next session.
Run `/reload-plugins` to load it into a running session.

For a one-off session from a checkout:

```bash
claude --plugin-dir ./mods/claude-statusline
```

## Develop

```bash
claude plugin validate mods/claude-statusline
claude plugin test mods/claude-statusline
```

Claude Code writes the API types to `.claude-plugin/types/` whenever it loads the mod from this folder.
After that, `tsc -p mods/claude-statusline` type-checks it.

## Layout notes

- The plugin is named `statusline`.
  - Claude Code reserves plugin names starting with `claude-`.
- `hooks/hooks.json` carries a `description` key.
  - apm merges any `hooks/*.json` whose values are all lists into `settings.json` as settings hooks.
  - A string value stops that merge, so `modules` stays out of the user's settings.
- `.claude-plugin/plugin.json` has no `$schema`.
  - apm 0.29.0 refuses a manifest whose `$schema` is Claude Code's plugin schema.
- `.claude-plugin/plugin.json` makes apm treat this folder as a Claude plugin (`package_type: marketplace_plugin`).
  - apm then deploys the folder whole into `~/.claude/skills/`, which is where Claude Code adopts skill plugins.
