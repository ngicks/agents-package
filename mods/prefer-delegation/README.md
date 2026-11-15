# prefer-delegation

A Claude Code mod that adds a section to the system prompt on Fable and Mythos models.
The section tells the model to delegate sizable tasks to subagents unless other instructions say otherwise.

The mod adds nothing on other models, and nothing on a request that does not offer the `Agent` tool.
`SKILL.md` describes the conditions and the section.

## Install

Install it globally with apm:

```bash
apm install -g ngicks/agents-package/mods/prefer-delegation
```

apm copies this folder to `~/.claude/skills/prefer-delegation/`.
Claude Code adopts it as the plugin `prefer-delegation@skills-dir` in the next session.
A session that is already running keeps the system prompt it started with.

For a one-off session from a checkout:

```bash
claude --plugin-dir ./mods/prefer-delegation
```

## Develop

```bash
claude plugin validate mods/prefer-delegation
claude plugin test mods/prefer-delegation
```

Claude Code writes the API types to `.claude-plugin/types/` whenever it loads the mod from this folder.
After that, `tsc -p mods/prefer-delegation` type-checks it.

## Layout notes

- `hooks/hooks.json` carries a `description` key.
  - apm merges any `hooks/*.json` whose values are all lists into `settings.json` as settings hooks.
  - A string value stops that merge, so `modules` stays out of the user's settings.
- `.claude-plugin/plugin.json` has no `$schema`.
  - apm 0.29.0 refuses a manifest whose `$schema` is Claude Code's plugin schema.
- `.claude-plugin/plugin.json` makes apm treat this folder as a Claude plugin (`package_type: marketplace_plugin`).
  - apm then deploys the folder whole into `~/.claude/skills/`, which is where Claude Code adopts skill plugins.
