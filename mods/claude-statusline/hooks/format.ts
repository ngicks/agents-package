export type StatusParts = {
  model: string
  effort?: string
  percent?: number
  cwd: string
  worktree?: string
}

const SEPARATOR = ' | '
const ELLIPSIS = '…'

// The engine draws a plugin's status as `  ⚠ <plugin>: <text>`, keeps two
// cells free at the right end of the row, and cuts the end of anything wider.
export function statusChromeWidth(plugin: string): number {
  return '  ⚠ '.length + plugin.length + ': '.length + 2
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
