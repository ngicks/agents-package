import { describe, expect, test } from 'claude-code/testing'
import {
  HINT_CHROME_WIDTH,
  cellWidth,
  contextLabel,
  formatStatusLine,
  formatStatusRow,
  modelDisplayName,
  truncateStart,
  worktreeNameOf,
} from '../hooks/format'

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

describe('cellWidth', () => {
  test('counts the emoji labels as two cells and ⛕ as one', () => {
    expect(cellWidth('🤖🔋🪫📂')).toBe(8)
    expect(cellWidth('⛕ main')).toBe(6)
  })
})

describe('contextLabel', () => {
  test('shows a full battery below 60% and a low battery from 60%', () => {
    expect(contextLabel(0)).toBe('🔋')
    expect(contextLabel(59)).toBe('🔋')
    expect(contextLabel(60)).toBe('🪫')
    expect(contextLabel(100)).toBe('🪫')
  })
})

describe('formatStatusLine', () => {
  test('labels every component', () => {
    expect(formatStatusLine(parts)).toBe(
      '🤖 Opus 5.5 (1M context) @ medium | 🔋 7% used | 📂 /home/u/src/agents-package/main | ⛕ main',
    )
  })

  test('labels a context used from 60% with a low battery', () => {
    expect(formatStatusLine({ ...parts, percent: 60 })).toBe(
      '🤖 Opus 5.5 (1M context) @ medium | 🪫 60% used | 📂 /home/u/src/agents-package/main | ⛕ main',
    )
  })

  test('leaves out effort and worktree when absent', () => {
    expect(formatStatusLine({ model: 'Haiku 4.5', cwd: '/x' })).toBe('🤖 Haiku 4.5 | 🔋 0% used | 📂 /x')
  })

  test('cuts the start of cwd so the line fills the width exactly', () => {
    const full = cellWidth(formatStatusLine(parts))
    const line = formatStatusLine(parts, full - 10)
    expect(cellWidth(line)).toBe(full - 10)
    expect(line).toBe('🤖 Opus 5.5 (1M context) @ medium | 🔋 7% used | 📂 …/agents-package/main | ⛕ main')
  })

  test('drops cwd when nothing of it fits', () => {
    expect(formatStatusLine(parts, 10)).toBe('🤖 Opus 5.5 (1M context) @ medium | 🔋 7% used | ⛕ main')
  })
})

describe('formatStatusRow', () => {
  const status = formatStatusLine(parts)
  const width = cellWidth(status)

  test('leaves room for the hint line chrome', () => {
    expect(formatStatusRow(parts, width + HINT_CHROME_WIDTH)).toBe(status)
    expect(formatStatusRow(parts, width + HINT_CHROME_WIDTH - 1)).toBe(formatStatusLine(parts, width - 1))
  })

  test('keeps the whole status while the width is unknown', () => {
    expect(formatStatusRow(parts, undefined)).toBe(status)
  })
})
