import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'
import { formatStatusRow, modelDisplayName, worktreeNameOf } from './format'

// /model and /effort change the line without starting a turn, so poll for them.
const REFRESH_MS = 2000

const status = atom({ plugin: 'statusline', key: 'parts' } as const, null)

// Effort comes from two places: settings (what /effort saves) and each
// model request (what was actually sent). Whichever changed last wins.
let effort: string | undefined
let settingsEffort: unknown
let worktree: { cwd: string; name: string | undefined } | undefined

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
  const parts = {
    model: modelDisplayName(model),
    effort,
    percent: usage.context.percent,
    cwd,
    worktree: await worktreeOf($, cwd),
  }
  // A write redraws the hint line even when the value is unchanged.
  if (JSON.stringify(await read($, status)) !== JSON.stringify(parts)) {
    await update($, status, () => parts)
  }
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
      const prev = await read($, status)
      if (prev !== null && prev.effort !== effort) {
        await update($, status, p => (p === null ? p : { ...p, effort }))
      }
    }
    return yield* next(e)
  })

  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    const parts = await read($, status)
    if (parts === null) return next(e)

    const drawn = await next(e)
    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        {drawn}
        <Text dimColor>{formatStatusRow(parts, e.viewport?.columns)}</Text>
      </Box>
    )
  })
}
