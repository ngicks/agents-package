import type { StatusParts } from '../types'

const SEPARATOR = ' | '
const ELLIPSIS = '…'

// The engine indents the hint line by two cells. The two cells kept free at
// the right end err toward a new line, since a tail wider than the row is cut
// at its end.
export const HINT_CHROME_WIDTH = 4

export type StatusPlacement = { tail: string } | { line: string }

// The status rides at the end of the hint line only while it shows whole
// there; otherwise it takes a row of its own, where cwd is cut to fit.
export function placeStatus(
  hint: { hint: string; tail?: string },
  parts: StatusParts,
  columns: number | undefined,
): StatusPlacement {
  const before = hint.hint + (hint.tail ?? '')
  const tail = (hint.tail ?? '') + (before === '' ? '' : SEPARATOR) + formatStatusLine(parts)
  const width = HINT_CHROME_WIDTH + Array.from(hint.hint).length + Array.from(tail).length
  if (columns !== undefined && !before.includes('\n') && width <= columns) {
    return { tail }
  }
  return { line: formatStatusRow(parts, columns) }
}

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

export function formatStatusLine(parts: StatusParts, width?: number): string {
  const head = parts.effort === undefined ? parts.model : `${parts.model} @ ${parts.effort}`
  const used = `${String(parts.percent ?? 0).padStart(3)}% used`
  const tail = parts.worktree === undefined ? [] : [parts.worktree]
  if (width === undefined) return [head, used, parts.cwd, ...tail].join(SEPARATOR)

  const fixed = [head, used, ...tail]
  const fixedWidth = fixed.reduce((sum, s) => sum + Array.from(s).length, 0) + SEPARATOR.length * fixed.length
  const cwd = truncateStart(parts.cwd, width - fixedWidth)
  return (cwd === '' ? fixed : [head, used, cwd, ...tail]).join(SEPARATOR)
}
