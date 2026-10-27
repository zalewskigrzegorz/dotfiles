export type Nudges = { standup: number; retro: number }

declare module 'claude-code' {
  interface PluginState {
    'nudge-band': { nudges: Nudges }
  }
}
