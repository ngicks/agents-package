import type { StatusParts } from '../types'

const SEPARATOR = ' | '
const ELLIPSIS = '…'
const MODEL_LABEL = '🤖'
const CONTEXT_LABEL = '🔋'
const CONTEXT_LOW_LABEL = '🪫'
const CONTEXT_LOW_AT = 60
const CWD_LABEL = '📂'
const WORKTREE_LABEL = '⛕'

// The engine indents the hint line by two cells. Two more cells stay free at
// the right end so the terminal never wraps the row.
export const HINT_CHROME_WIDTH = 4

export function formatStatusRow(parts: StatusParts, columns: number | undefined): string {
  return formatStatusLine(parts, columns === undefined ? undefined : columns - HINT_CHROME_WIDTH)
}

export function modelDisplayName(id: string): string {
  const bracket = /\[(\d+)([km])\]$/i.exec(id)
  const base = bracket ? id.slice(0, bracket.index) : id
  const m = /claude-([a-z]+)-(\d+)(?:-(\d{1,2}))?(?:-\d{8})?/i.exec(base)
  if (!m) return id
  const [, family = '', major = '', minor] = m
  const name = `${family[0]?.toUpperCase() ?? ''}${family.slice(1)} ${minor === undefined ? major : `${major}.${minor}`}`
  return bracket ? `${name} (${bracket[1]}${bracket[2]?.toUpperCase()} context)` : name
}

export function worktreeNameOf(gitDir: string): string | undefined {
  const parts = gitDir.replace(/\/+$/, '').split('/')
  return parts.at(-2) === 'worktrees' ? parts.at(-1) : undefined
}

export function truncateStart(text: string, width: number): string {
  const chars = Array.from(text)
  if (chars.length <= width) return text
  if (width <= 0) return ''
  return ELLIPSIS + chars.slice(chars.length - (width - 1)).join('')
}

// Only the emoji labels are expected to be wide; ⛕ has no emoji presentation and takes one cell.
export function cellWidth(text: string): number {
  return Array.from(text).reduce((sum, c) => sum + ((c.codePointAt(0) ?? 0) >= 0x1f000 ? 2 : 1), 0)
}

export function contextLabel(percent: number): string {
  return percent < CONTEXT_LOW_AT ? CONTEXT_LABEL : CONTEXT_LOW_LABEL
}

export function formatStatusLine(parts: StatusParts, width?: number): string {
  const percent = parts.percent ?? 0
  const head = `${MODEL_LABEL} ${parts.effort === undefined ? parts.model : `${parts.model} @ ${parts.effort}`}`
  const used = `${contextLabel(percent)} ${percent}% used`
  const tail = parts.worktree === undefined ? [] : [`${WORKTREE_LABEL} ${parts.worktree}`]
  const cwdPrefix = `${CWD_LABEL} `
  if (width === undefined) return [head, used, cwdPrefix + parts.cwd, ...tail].join(SEPARATOR)

  const fixed = [head, used, ...tail]
  const fixedWidth = fixed.reduce((sum, s) => sum + cellWidth(s), 0) + SEPARATOR.length * fixed.length
  const cwd = truncateStart(parts.cwd, width - fixedWidth - cellWidth(cwdPrefix))
  return (cwd === '' ? fixed : [head, used, cwdPrefix + cwd, ...tail]).join(SEPARATOR)
}
