export type Spawn = { model: string; startedAt: number }

declare module 'claude-code' {
  interface PluginState {
    // Keyed by the Agent call's description, the one field AgentInfo shares with the call.
    'agent-board': { spawns: Record<string, Spawn> }
  }
}
