import type { Register } from 'claude-code'
import { AGENT_TOOL, SECTION_ID, isDelegatingModel, sectionText } from './section'

export const register: Register = (on) => {
  // The engine sends a thread the prompt of its first render and ignores later
  // answers, so only the first Agent-offering render of a conversation is logged.
  // prompt.compose also fires every turn and after /model; logging those would
  // report sections that are never sent.
  let decided: string | undefined

  // prompt.compose carries the model of each render, so a thread started after
  // /model gets the right answer. The engine does not send a changed answer to
  // a thread that already recorded its prompt; forcing that needs a
  // prompt.section hook with breakPromptCache, which carries no model or tools.
  on('prompt.compose', async ($, e, next) => {
    const result = await next(e)
    if (!e.tools.includes(AGENT_TOOL)) return result
    const isAdding = isDelegatingModel(e.model)
    const conversation = await $.session.id()
    if (decided !== conversation) {
      decided = conversation
      if (isAdding) $.ui.log(`prefer-delegation: delegation section added to the system prompt (${e.model})`)
    }
    if (!isAdding) return result
    return {
      sections: [
        ...result.sections.filter(s => s.id !== SECTION_ID),
        { id: SECTION_ID, text: sectionText(e.model), scope: 'session' },
      ],
    }
  })

  // A compaction starts the prompt over, so its next render decides again.
  on('session.compact', async (_$, e, next) => {
    const result = await next(e)
    decided = undefined
    return result
  })
}
