# agents-package

Skills, hooks, AGENTS.md, etc

Install contents via [apm](https://github.com/microsoft/apm)

## Layout

| Directory | Contents | Depend on it as |
|---|---|---|
| `bundle/<name>/` | Curated `apm.yml` listing units below | `ngicks/agents-package/bundle/<name>`, or copy the file in as your own `apm.yml` |
| `pkg/<name>/` | Self-contained packages shipping several primitives | `ngicks/agents-package/pkg/<name>` |
| `vpkg/skills/<name>/` | Single skill | `ngicks/agents-package/vpkg/skills/<name>` |
| `vpkg/instructions/<name>.instructions.md` | Single instruction file | `ngicks/agents-package/vpkg/instructions/<name>.instructions.md` |
| `vpkg/hooks/<name>/` | Single hook set | `ngicks/agents-package/vpkg/hooks/<name>` |
| `mods/<name>/` | Claude Code mod (skill plugin) | `apm install -g ngicks/agents-package/mods/<name>` |
| `settings/claude/` | Base for Claude Code's `settings.json` | Run `settings/claude/apply.sh` to merge it into the live settings |

## Quick start

Install a bundle in one shot:

```yaml
dependencies:
  apm:
  - ngicks/agents-package/bundle/<name>
```

Or copy `bundle/<name>/apm.yml` into your project, then drop or swap individual units.
