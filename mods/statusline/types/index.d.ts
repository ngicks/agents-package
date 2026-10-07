export type StatusParts = {
  model: string
  effort?: string
  percent?: number
  cwd: string
  worktree?: string
}

declare module 'claude-code' {
  interface PluginState {
    statusline: { parts: StatusParts | null }
  }
}
