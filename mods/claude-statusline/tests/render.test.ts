import { describe, expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const HINT = { isDraft: false, isWorking: false, hint: '⏵⏵ auto mode on (shift+tab to cycle)' }
const STATUS = 'Opus 5.5 (1M context) @ high |   7% used | /src/repo | main'

function engine(on: On, tails: (string | undefined)[], drawn: object = { type: 'engine', ref: 1 }) {
  mock.clock(on)
  on('session.model', () => ({ value: 'claude-opus-5-5[1m]' }))
  on('session.usage', () => ({ value: { context: { percent: 7 } } }) as never)
  on('settings.read', () => ({ value: { effortLevel: 'high' } }))
  on('session.cwd', () => ({ value: '/src/repo' }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: '/src/repo/.bare/worktrees/main\n', stderr: '' } }) as never)
  on('session.start', (_$, e) => ({ cwd: e.cwd }))
  on('ui.render', (_$, e) => {
    tails.push((e.props as { tail?: string }).tail)
    return drawn as never
  })
}

describe('PromptHint', () => {
  test('appends the status to the hint line when it fits', async ($, on) => {
    const tails: (string | undefined)[] = []
    engine(on, tails)
    await $.session.start({ cwd: '/src/repo', surface: 'terminal', isInteractive: true })
    const ui = await $.ui.mount({
      plugin: 'statusline',
      surface: 'terminal',
      component: 'PromptHint',
      props: HINT,
      viewport: { columns: 200, rows: 40 },
    })
    expect(tails.at(-1)).toBe(` | ${STATUS}`)
    expect((await ui.drawn()).type).toBe('engine')
  })

  test('draws the status on a new line when the hint line has no room', async ($, on) => {
    const tails: (string | undefined)[] = []
    engine(on, tails)
    await $.session.start({ cwd: '/src/repo', surface: 'terminal', isInteractive: true })
    const ui = await $.ui.mount({
      plugin: 'statusline',
      surface: 'terminal',
      component: 'PromptHint',
      props: HINT,
      viewport: { columns: 80, rows: 40 },
    })
    expect(tails.at(-1)).toBeUndefined()
    expect((await ui.find({ type: 'Text', text: /7% used/ }))?.text).toBe(STATUS)
  })

  test('keeps the status in the hint line a plugin beneath wrapped', async ($, on) => {
    const tails: (string | undefined)[] = []
    engine(on, tails, {
      type: 'Box',
      props: { flexDirection: 'column' },
      children: [{ type: 'engine', ref: 1 }, { type: 'Text', props: {}, children: ['extra'] }],
    })
    await $.session.start({ cwd: '/src/repo', surface: 'terminal', isInteractive: true })
    const ui = await $.ui.mount({
      plugin: 'statusline',
      surface: 'terminal',
      component: 'PromptHint',
      props: HINT,
      viewport: { columns: 200, rows: 40 },
    })
    expect(tails.at(-1)).toBe(` | ${STATUS}`)
    expect(await ui.findAll({ type: 'Text', text: /7% used/ })).toHaveLength(0)
  })

  test('draws the status on a new line beside a tree that replaced the hint line', async ($, on) => {
    const tails: (string | undefined)[] = []
    engine(on, tails, { type: 'Text', props: {}, children: ['line one'] })
    await $.session.start({ cwd: '/src/repo', surface: 'terminal', isInteractive: true })
    const ui = await $.ui.mount({
      plugin: 'statusline',
      surface: 'terminal',
      component: 'PromptHint',
      props: HINT,
      viewport: { columns: 200, rows: 40 },
    })
    expect(await ui.find({ type: 'Text', text: 'line one' })).toBeDefined()
    expect((await ui.find({ type: 'Text', text: /7% used/ }))?.text).toBe(STATUS)
  })
})
