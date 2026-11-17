export const SECTION_ID = "prefer-delegation:delegation";

export const AGENT_TOOL = "Agent";

// Most capable tier first. A name is both the family matched inside a model id
// and the value the Agent tool takes as `model`, so the first name of a tier
// must be one the tool accepts.
export const MODEL_TIERS: readonly (readonly string[])[] = [
  ["mythos", "fable"],
  ["opus"],
  ["sonnet"],
  ["haiku"],
];

// Model ids carry provider prefixes and suffixes such as "[1m]", so match by family name.
function tierOf(model: string): number {
  const id = model.toLowerCase();
  return MODEL_TIERS.findIndex((names) =>
    names.some((name) => id.includes(name))
  );
}

// Only the top tier delegates by default. A lower tier keeps the Agent tool's
// own advice, which spawns less.
export function isDelegatingModel(model: string): boolean {
  return tierOf(model) === 0;
}

// The model one tier below the given one, for the subagents it spawns.
// Without it a subagent inherits the parent model and runs on the top tier too.
export function subagentModel(model: string): string | undefined {
  const tier = tierOf(model);
  if (tier < 0) return undefined;
  return MODEL_TIERS[tier + 1]?.[0];
}

export function sectionText(model: string): string {
  const subagent = subagentModel(model);
  const modelLine = subagent === undefined
    ? ""
    : `\n- Pass \`model: "${subagent}"\` on every ${AGENT_TOOL} call. A subagent without it runs on your own model and saves nothing.`;
  // The text gives the reason so the model weighs delegation against it. It
  // does not ask for parallel subagents: the aim is to move load off this
  // model, and fanning out spends more in total.
  return `# Delegating sizable work

Your model has limited usage and consumes it fast, so heavy work should run on a cheaper model.
As a baseline, hand sizable tasks to a subagent through the ${AGENT_TOOL} tool.
For sizable work this baseline takes precedence over the ${AGENT_TOOL} tool's own advice to avoid spawning when in doubt.

- Sizable means work that needs many tool calls, reading across several files, a multi-step implementation, a broad search, or a long verification run.
- One subagent per task is enough. The ${AGENT_TOOL} tool's own advice decides when to split work or run subagents in parallel.${modelLine}
- Stay the coordinator. Keep decisions, integration and the final report yourself, and check a subagent's result before relying on it.
- Do small work yourself: a handful of tool calls, a lookup whose target is known, or a one-file edit.
- If you are a subagent yourself, do the delegated work directly and do not delegate it again unless otherwise instructed.

Instructions from the user, the project's instruction files, or a loaded skill override this default.
When any of them says to work inline, to avoid subagents, to limit cost, or to use another model, follow that instead.`;
}
