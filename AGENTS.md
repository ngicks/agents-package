# AGENTS.md

## The Project

Instructions, hooks, skills for LLM agents, managable with [apm](https://github.com/microsoft/apm).

## Important

- DO NOT refer to other instructions files because they will be compiled down to `AGENTS.md` before shipped to reader LLM agetns.

## Skills

Follow best practices described in

- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

Keep text structured, every lines human-readable.

- Split sections using heading(`#`)
  - but don't go too deep; keep it between h2(`##`) to h4(`####`)
- Use bullet lists(`-`) for structured explanation.
  - again, don't go too deep; keep it like between 1 - 5 nests
- Combine non-list and lists (as this section does)
  - Summary as non-list text, details in lists.
- To split paragraphs, add 2 line breaks.
- To ensure renderer breaks line, add 2 white spaces (`  `) before line break.
  - You can break lines without white-spaces just for easier diff views.
