import type { Register } from 'claude-code'
import { AGENT_TOOL, SECTION_ID, SECTION_TEXT, isDelegatingModel } from './section'

export const register: Register = (on) => {
  // prompt.compose carries the model of each render, so a thread started after
  // /model gets the right answer. The engine does not send a changed answer to
  // a thread that already recorded its prompt; forcing that needs a
  // prompt.section hook with breakPromptCache, which carries no model or tools.
  on('prompt.compose', async (_$, e, next) => {
    const result = await next(e)
    if (!isDelegatingModel(e.model) || !e.tools.includes(AGENT_TOOL)) return result
    return {
      sections: [
        ...result.sections.filter(s => s.id !== SECTION_ID),
        { id: SECTION_ID, text: SECTION_TEXT, scope: 'session' },
      ],
    }
  })
}
