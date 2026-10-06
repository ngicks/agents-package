import type { EngineInterface, Register } from 'claude-code'
import { formatStatusLine, modelDisplayName, statusChromeWidth, worktreeNameOf } from './format'
import type { StatusParts } from './format'

const PLUGIN = 'statusline'
// /model and /effort change the line without starting a turn, so poll for them.
const REFRESH_MS = 2000

let parts: StatusParts | undefined
let columns: number | undefined
let shown: string | undefined
// Effort comes from two places: settings (what /effort saves) and each
// model request (what was actually sent). Whichever changed last wins.
let effort: string | undefined
let settingsEffort: unknown
let worktree: { cwd: string; name: string | undefined } | undefined

function draw($: EngineInterface) {
  if (parts === undefined) return
  const text = formatStatusLine(
    parts,
    columns === undefined ? undefined : columns - statusChromeWidth(PLUGIN),
  )
  if (text === shown) return
  shown = text
  $.ui.status(text)
}

async function worktreeOf($: EngineInterface, cwd: string) {
  if (worktree?.cwd === cwd) return worktree.name
  let name: string | undefined
  try {
    const r = await $.process.run(['git', 'rev-parse', '--absolute-git-dir'], { cwd, timeoutMs: 5000 })
    name = r.exitCode === 0 ? worktreeNameOf(r.stdout.trim()) : undefined
  } catch {
    name = undefined
  }
  worktree = { cwd, name }
  return name
}

async function refresh($: EngineInterface) {
  const [model, usage, settings, cwd] = await Promise.all([
    $.session.model(),
    $.session.usage(),
    $.settings.read(),
    $.session.cwd(),
  ])
  const level = (settings as { effortLevel?: unknown }).effortLevel
  if (level !== settingsEffort) {
    settingsEffort = level
    effort = typeof level === 'string' ? level : undefined
  }
  parts = {
    model: modelDisplayName(model),
    effort,
    percent: usage.context.percent,
    cwd,
    worktree: await worktreeOf($, cwd),
  }
  draw($)
}

export const register: Register = (on) => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await refresh($)
    $.clock.every(REFRESH_MS, () => void refresh($))
    return result
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    await refresh($)
    return result
  })

  on('turn.step', async function* ($, e, next) {
    if (e.agentId === undefined) {
      effort = e.effort === undefined ? undefined : String(e.effort)
      if (parts !== undefined) {
        parts = { ...parts, effort }
        draw($)
      }
    }
    return yield* next(e)
  })

  // The status line has no viewport of its own; the hint line under the
  // prompt spans the same width and is drawn again on every resize.
  on('ui.render', { component: 'PromptHint' }, ($, e, next) => {
    const c = e.viewport?.columns
    if (c !== undefined && c !== columns) {
      columns = c
      draw($)
    }
    return next(e)
  })
}
