# cc-workers

A fleet of cooperating Claude Code worker subagents, packaged for
[apm](https://github.com/microsoft/apm).

Each worker is split in two: a **skill** holds the reusable workflow, and
a thin **subagent** preloads that skill (via the `skills:` frontmatter
field) and pins the model/tools. The orchestrator ships as a skill only,
so it can be invoked directly (e.g. from `/goal` / `nggoal`).

## Skills

| Skill | Purpose | Used by |
|---|---|---|
| `orchestrator` | Decompose a task, delegate to workers, synthesize. | invoked directly (e.g. nggoal) |
| `explorer` | Read-only codebase mapping. | `explorer` agent |
| `implementer` | Make a scoped code change. | `implementer` agent |
| `reviewer` | Fan out 5 Sonnet reviewers, score, synthesize. | `reviewer` agent |
| `command-invoker` | Run a command, return only the stripped failure. | `test-runner`, `command-invoker` agents |

## Subagents

| Agent | Skill | Model | Tools |
|---|---|---|---|
| `explorer` | `explorer` | sonnet | Read, Grep, Glob |
| `implementer` | `implementer` | opus (effort xhigh) | inherits all |
| `reviewer` | `reviewer` | sonnet | Read, Grep, Glob, Bash, Agent |
| `test-runner` | `command-invoker` | haiku | Bash, Read, Grep, Glob |
| `command-invoker` | `command-invoker` | haiku | Bash, Read, Grep, Glob |

No agent pins `permissionMode`, so each inherits the caller's permission
mode.

The `reviewer` lists `Agent` in `tools` so it can spawn its five nested
Sonnet review subagents. `test-runner` and `command-invoker` share the
one `command-invoker` skill; `test-runner` specializes it to test
commands.

Cooperation is description-driven: an orchestrating agent delegates to a
worker by matching its `description` (via the Agent tool), and the worker
returns its result. Claude Code has no `handoffs` field, so routing lives
in the prompts.

## Install (consumer side)

This package lives in a subdirectory of a monorepo. Reference it by its
subdir path in your `apm.yml`:

```yaml
dependencies:
  apm:
    # the whole fleet
    - ngicks/agents-package/apm-package/cc-workers
    # ...pinned to a per-package monorepo tag
    - ngicks/agents-package/apm-package/cc-workers#cc-workers-v0.0.1
```

Install the whole package, not individual files: each agent depends on
its matching skill (via `skills:`), so installing a single
`.agent.md` would leave the worker without its workflow.

Then `apm install`. Skills compile to `.claude/skills/<name>/SKILL.md`
and agents to `.claude/agents/<name>.md` (verbatim) and
`.codex/agents/<name>.toml` (frontmatter -> TOML).

## Authoring

- Source of truth is `.apm/`. Never edit the compiled copies under
  `.claude/` or `.codex/`.
- The logic lives in the skills; keep agent bodies thin -- they exist to
  preload a skill and pin model/tools.
- `model`, `effort`, and `skills` reach the Claude target verbatim. The
  Codex transformer keeps only `name` + `description` + body, so Codex
  agents fall back to Codex defaults and do not get preloaded skills.
- Validate before shipping:

  ```bash
  apm compile --validate
  apm install --dry-run --target claude
  ```
