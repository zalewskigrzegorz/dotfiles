export type ShotPath = string

declare module 'claude-code' {
  interface PluginState {
    'shot-pane': { shots: ShotPath[] }
  }
}
