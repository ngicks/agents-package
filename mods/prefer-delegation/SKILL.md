---
name: prefer-delegation
description: Explains the `prefer-delegation` mod that adds a system prompt section preferring subagent delegation for sizable tasks on Fable and Mythos models. Use when the user asks why the model delegates to subagents, or wants to change or debug that behavior.
disable-model-invocation: true
---

# prefer-delegation

This skill folder is also a Claude Code plugin named `prefer-delegation`.
Claude Code adopts every folder under `~/.claude/skills/` that holds `.claude-plugin/plugin.json`,
and loads its hooks module (`hooks/register.ts`) as a mod.

## What the mod does

The mod appends one section to the system prompt through a `prompt.compose` hook.
The section tells the model to delegate sizable tasks to subagents by default.

- The section id is `prefer-delegation:delegation`.
- The section sits last, on the `session` side of the prompt cache boundary.
- `sectionText` in `hooks/section.ts` builds the section text for the model of the request.

## Model tiers

`MODEL_TIERS` in `hooks/section.ts` orders the model families from most to least capable.

- Tier 0: `mythos`, `fable`
- Tier 1: `opus`
- Tier 2: `sonnet`
- Tier 3: `haiku`

The mod reads two answers from the list.

- Only tier 0 receives the section.
- The section names the first family of the next lower tier as the model for subagents.
  - Fable and Mythos tell their subagents to run on `opus`.
  - A subagent without a `model` runs on the model of its parent, so the section names one.

## When the section is added

The mod adds the section when both conditions hold.

- The model id of the request contains a tier 0 family name, in any letter case.
  - Ids with a provider prefix or a suffix such as `[1m]` match too.
- The request offers the `Agent` tool.
  - A thread without the tool cannot delegate, so the section would only mislead it.

Every other request keeps its system prompt unchanged.

## What the section says

- The model has limited usage and consumes it fast, so heavy work should run on a cheaper model.
- Delegate sizable work as a baseline: many tool calls, reading across several files, multi-step implementation, broad searches, long verification runs.
- One subagent per task is enough. The section does not ask for parallel subagents.
- Pass `model: "opus"` on every `Agent` call.
- Stay the coordinator, and verify a subagent's result.
- Do small work inline.
- A subagent does its delegated work directly and does not delegate again.
- Instructions from the user, the project's instruction files, or a loaded skill override the default.

## When a change takes effect

The hook answers every render of the system prompt with the model of that render.

- A new session composes the prompt for its starting model.
- Claude Code keeps the recorded system prompt of a running thread while it stands.
  - A `/model` switch does not change the prompt of the running conversation.
  - `/new`, `/clear` and a compaction start the prompt over, and the section then follows the current model.
  - A session that loads the mod midway gets the section at its next render.

## Transcript line

The mod writes one dim line to the transcript when a conversation receives the section.

- The line reads `prefer-delegation: delegation section added to the system prompt (<model id>)`.
- The model does not see the line.
- A conversation gets the line once, at its first render that offers the `Agent` tool.
  - A `/model` switch in a running conversation writes no line, because that conversation keeps its prompt.
  - `/new`, `/clear` and a compaction decide again.

## Files

- `hooks/register.ts`: the `prompt.compose` hook.
- `hooks/section.ts`: the model tiers, the model check and the section text.
- `tests/`: run with `claude plugin test <this folder>`.

## Debugging

- `claude plugin validate <this folder>` lists what the module hooks and calls.
- `claude --debug` logs a line for every hook that failed.
- `claude plugin disable prefer-delegation@skills-dir` turns the mod off.
