import { describe, expect, test } from 'claude-code/testing'
import { HINT_CHROME_WIDTH, formatStatusLine, modelDisplayName, placeStatus, truncateStart, worktreeNameOf } from '../hooks/format'

const parts = {
  model: 'Opus 5.5 (1M context)',
  effort: 'medium',
  percent: 7,
  cwd: '/home/u/src/agents-package/main',
  worktree: 'main',
}

describe('modelDisplayName', () => {
  test('names a model id the way /model does', () => {
    expect(modelDisplayName('claude-opus-5-5[1m]')).toBe('Opus 5.5 (1M context)')
    expect(modelDisplayName('claude-haiku-4-5-20251001')).toBe('Haiku 4.5')
    expect(modelDisplayName('claude-fable-5-1')).toBe('Fable 5.1')
    expect(modelDisplayName('us.anthropic.claude-sonnet-5-5-v1:0')).toBe('Sonnet 5.5')
  })

  test('keeps an id it does not recognize', () => {
    expect(modelDisplayName('gpt-oss-120b')).toBe('gpt-oss-120b')
  })
})

describe('worktreeNameOf', () => {
  test('names a linked worktree by its git dir', () => {
    expect(worktreeNameOf('/src/repo/.bare/worktrees/main')).toBe('main')
    expect(worktreeNameOf('/src/repo/.git/worktrees/feature-x/')).toBe('feature-x')
  })

  test('has no name for a main working tree', () => {
    expect(worktreeNameOf('/src/repo/.git')).toBeUndefined()
  })
})

describe('truncateStart', () => {
  test('keeps the end of the text behind an ellipsis', () => {
    expect(truncateStart('/a/b/c/d', 5)).toBe('…/c/d')
    expect(truncateStart('/a/b', 4)).toBe('/a/b')
    expect(truncateStart('/a/b', 0)).toBe('')
  })
})

describe('formatStatusLine', () => {
  test('joins every component', () => {
    expect(formatStatusLine(parts)).toBe('Opus 5.5 (1M context) @ medium |   7% used | /home/u/src/agents-package/main | main')
  })

  test('leaves out effort and worktree when absent', () => {
    expect(formatStatusLine({ model: 'Haiku 4.5', cwd: '/x' })).toBe('Haiku 4.5 |   0% used | /x')
  })

  test('cuts the start of cwd so the line fills the width exactly', () => {
    const full = formatStatusLine(parts)
    const line = formatStatusLine(parts, full.length - 10)
    expect(line.length).toBe(full.length - 10)
    expect(line).toBe('Opus 5.5 (1M context) @ medium |   7% used | …/agents-package/main | main')
  })

  test('drops cwd when nothing of it fits', () => {
    expect(formatStatusLine(parts, 10)).toBe('Opus 5.5 (1M context) @ medium |   7% used | main')
  })

})

describe('placeStatus', () => {
  const hint = '⏵⏵ auto mode on (shift+tab to cycle)'
  const status = formatStatusLine(parts)
  const fits = HINT_CHROME_WIDTH + hint.length + ' | '.length + status.length

  test('appends the whole status to the hint line when it fits', () => {
    expect(placeStatus({ hint }, parts, fits)).toEqual({ tail: ` | ${status}` })
  })

  test('keeps a tail another plugin set', () => {
    expect(placeStatus({ hint, tail: ' x' }, parts, fits + 2)).toEqual({ tail: ` x | ${status}` })
  })

  test('moves to a line of its own, cwd cut to the row, when the tail would be cut', () => {
    expect(placeStatus({ hint }, parts, fits - 1)).toEqual({ line: formatStatusLine(parts, fits - 1 - HINT_CHROME_WIDTH) })
  })

  test('moves to a line of its own when the hint already spans lines', () => {
    expect(placeStatus({ hint: `${hint}\nmore` }, parts, 1000)).toEqual({ line: status })
  })

  test('moves to a line of its own while the width is unknown', () => {
    expect(placeStatus({ hint }, parts, undefined)).toEqual({ line: status })
  })
})
