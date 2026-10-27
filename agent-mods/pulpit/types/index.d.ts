// A command the model sent to the background: its log's last meaningful line, not the whole stream.
export type BgTask = {
  id: string
  desc: string
  file: string
  last: string
  // How many polls in a row the last line stayed the same once its clock times are dropped.
  repeats: number
  state: 'running' | 'done' | 'failed'
  startedAt: number
  endedAt?: number
}

declare module 'claude-code' {
  interface PluginState {
    pulpit: { bg: BgTask[] }
  }
}
