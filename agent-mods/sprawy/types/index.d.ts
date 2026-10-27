export type Status = 'queued' | 'in_progress' | 'done'
export type AgentState = 'working' | 'waiting' | 'done' | 'failed'
// sub = a subagent of this session ($.agent.list), tuios = a tuios window (workctl, start-agent).
export type Link = { kind: 'sub' | 'tuios'; id: string; state: AgentState }
// order: queue position key, lower goes first; urgent items take one below the lowest.
export type Item = { id: number; title: string; status: Status; order: number; note?: string; agent?: Link }

declare module 'claude-code' {
  interface PluginState {
    sprawy: { items: Item[] }
  }
}
