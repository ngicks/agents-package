import { describe, expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'
import { SECTION_ID, SECTION_TEXT, isDelegatingModel } from '../hooks/section'

const CORE = [
  { id: 'intro', text: 'intro', scope: 'shared' },
  { id: 'memory', text: 'memory', scope: 'session' },
] as const

function engine(on: On) {
  on('prompt.compose', () => ({ sections: CORE }))
}

// The engine skips a hook whose input lacks any of these facts.
function facts(model: string, tools: readonly string[]) {
  return { model, promptModel: model, surfaces: ['terminal'], tools, outputStyle: null, traits: [] } as const
}

describe('isDelegatingModel', () => {
  test('accepts Fable and Mythos ids with prefixes and suffixes', () => {
    for (const id of [
      'claude-fable-5-2',
      'claude-fable-5-2[1m]',
      'claude-mythos-5-2',
      'us.anthropic.claude-mythos-5-2-v1:0',
      'Fable',
    ]) {
      expect(isDelegatingModel(id)).toBe(true)
    }
  })

  test('rejects other model families', () => {
    for (const id of ['claude-opus-5-5', 'claude-sonnet-5-5[1m]', 'claude-haiku-5-5', 'opus']) {
      expect(isDelegatingModel(id)).toBe(false)
    }
  })
})

describe('prompt.compose', () => {
  test('appends the section last, as session, for Fable and Mythos', async ($, on) => {
    engine(on)
    for (const model of ['claude-fable-5-2', 'claude-mythos-5-2[1m]']) {
      const { sections } = await $.prompt.compose(facts(model, ['Bash', 'Agent']))
      expect(sections).toEqual([...CORE, { id: SECTION_ID, text: SECTION_TEXT, scope: 'session' }])
    }
  })

  test('leaves the prompt of other models unchanged', async ($, on) => {
    engine(on)
    for (const model of ['claude-opus-5-5', 'claude-sonnet-5-5', 'claude-haiku-5-5']) {
      const { sections } = await $.prompt.compose(facts(model, ['Bash', 'Agent']))
      expect(sections).toEqual([...CORE])
    }
  })

  test('leaves the prompt unchanged when the Agent tool is not offered', async ($, on) => {
    engine(on)
    const { sections } = await $.prompt.compose(facts('claude-fable-5-2', ['Bash', 'Read']))
    expect(sections).toEqual([...CORE])
  })
})
