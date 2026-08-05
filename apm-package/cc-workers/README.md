# cc-workers

A fleet of cooperating Claude Code worker subagents, packaged for
[apm](https://github.com/microsoft/apm).

Each worker is split in two: a **skill** holds the reusable workflow, and
a thin **subagent** preloads that skill (via the `skills:` frontmatter
field) and pins the model/tools. The ng-orchestrator ships as a skill only,
so it can be invoked directly (e.g. from `/goal` / `nggoal`).

## Skills

| Skill | Purpose | Used by |
|---|---|---|
| `ng-orchestrator` | Decompose a task, delegate to workers, synthesize. | invoked directly (e.g. nggoal) |
| `ng-explorer` | Read-only codebase mapping. | `ng-explorer` agent |
| `ng-implementer` | Make a scoped code change. | `ng-implementer` agent |
| `ng-reviewer` | Fan out the 5 dedicated focus reviewers, score, synthesize. | `ng-reviewer` agent |
| `ng-focused-reviewer` | Worker-side single-focus review pass: ground, report all, never edit. | `ng-reviewer-*` focus agents |
| `ng-command-invoker` | Run a command, return only the stripped failure. | `ng-test-runner`, `ng-command-invoker` agents |

## Subagents

| Agent | Skill | Model | Tools |
|---|---|---|---|
| `ng-explorer` | `ng-explorer` | sonnet | inherits all |
| `ng-implementer` | `ng-implementer` | opus (effort xhigh) | inherits all |
| `ng-reviewer` | `ng-reviewer` | opus (effort high) | Agent, Read, Grep, Glob, Bash |
| `ng-reviewer-conventions` | `ng-focused-reviewer` | sonnet | Read, Grep, Glob |
| `ng-reviewer-bugs` | `ng-focused-reviewer` | sonnet | Read, Grep, Glob |
| `ng-reviewer-history` | `ng-focused-reviewer` | sonnet | Read, Grep, Glob, Bash |
| `ng-reviewer-docs` | `ng-focused-reviewer` | sonnet | Read, Grep, Glob |
| `ng-reviewer-tests` | `ng-focused-reviewer` | sonnet | Read, Grep, Glob |
| `ng-test-runner` | `ng-command-invoker` | haiku | inherits all |
| `ng-command-invoker` | `ng-command-invoker` | haiku | inherits all |

The non-review agents pin no `tools` or `permissionMode`, so they inherit
all tools and the caller's permission mode; `ng-explorer`'s read-only
boundary is enforced by its prompt. The review agents DO pin `tools` --
prompt-only enforcement proved insufficient there. Four of the five
focus workers get only `Read, Grep, Glob`: no `Edit` / `Write` /
`NotebookEdit`, and no `Bash` either, since an arbitrary shell can
mutate files just as well. `ng-reviewer-history` is the one exception:
its focus needs iterative digging (`git log` / `blame` / `show`), so it
keeps `Bash` -- restricted by prompt to read-only git commands -- while
still pinning no edit tools. Any other shell work happens in the parent
`ng-reviewer`, which runs commands itself and pastes the output into
worker prompts, keeping shell execution vetted and out of the parallel
fan-out. Running tests remains `ng-test-runner`'s job.

`ng-reviewer` pins the `Agent` tool so it can spawn its five dedicated
focus reviewers (`ng-reviewer-conventions`, `ng-reviewer-bugs`,
`ng-reviewer-history`, `ng-reviewer-docs`, `ng-reviewer-tests`), which
share the one `ng-focused-reviewer` skill and each pin their focus in
the agent body. `ng-test-runner` and `ng-command-invoker` share the one
`ng-command-invoker` skill; `ng-test-runner` specializes it to test
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
