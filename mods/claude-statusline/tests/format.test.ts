import { describe, expect, test } from 'claude-code/testing'
import { formatStatusLine, modelDisplayName, statusChromeWidth, truncateStart, worktreeNameOf } from '../hooks/format'

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

  test('budgets for the prefix and the right margin the engine draws', () => {
    expect(statusChromeWidth('statusline')).toBe('  ⚠ statusline: '.length + 2)
  })
})
