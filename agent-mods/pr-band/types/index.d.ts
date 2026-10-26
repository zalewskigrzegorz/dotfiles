export type Pr = {
  number: number
  url: string
  pass: number
  fail: number
  pending: number
  failed: string[]
  merge: string
  review: string
}

declare module 'claude-code' {
  interface PluginState {
    'pr-band': { pr: Pr | null; hiddenFor: number | null }
  }
}
