export type Pr = {
  number: number
  url: string
  // OPEN, MERGED or CLOSED; missing in values stored before it existed.
  state?: string
  pass: number
  fail: number
  pending: number
  failed: string[]
  merge: string
  review: string
  // Actions run id of the first failed e2e check, for its Playwright screenshots.
  e2eRun: string | null
}

export type Peek = Pr & {
  title: string
  author: string
  isDraft: boolean
  additions: number
  deletions: number
  files: number
}

declare module 'claude-code' {
  interface PluginState {
    'pr-band': { pr: Pr | null; peek: Peek | null }
  }
}
