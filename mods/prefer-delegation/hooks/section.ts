export const SECTION_ID = "prefer-delegation:delegation";

export const AGENT_TOOL = "Agent";

export const SECTION_TEXT = `# Delegating sizable work

Default to delegating sizable tasks to subagents through the ${AGENT_TOOL} tool.
For sizable work this section takes precedence over the ${AGENT_TOOL} tool's own advice to avoid spawning when in doubt.

- Sizable means work that needs many tool calls, reading across several files, a multi-step implementation, a broad search, or a long verification run.
- Split independent pieces across several subagents and launch them in one message so they run in parallel.
- Brief each subagent completely: the goal, what is already known or ruled out, the files worth reading, the scope, and the shape of the report you want back.
- Stay the coordinator. Keep decisions, integration and the final report yourself, and check a subagent's result before relying on it.
- Do small work yourself: a handful of tool calls, a lookup whose target is known, or a one-file edit.
- If you are a subagent yourself, do the delegated work directly and do not delegate it again unless otherwise instructed.

Instructions from the user, the project's instruction files, or a loaded skill override this default.
When any of them says to work inline, to avoid subagents, or to limit cost, follow that instead.`;

// Model ids carry provider prefixes and suffixes such as "[1m]", so match by family name.
export function isDelegatingModel(model: string): boolean {
  return /fable|mythos/i.test(model);
}
