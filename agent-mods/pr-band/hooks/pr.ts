import type { Peek, Pr } from '../types'

type Check = { name?: string; context?: string; status?: string; conclusion?: string; state?: string; detailsUrl?: string }
type View = { number: number; url: string; mergeStateStatus?: string; reviewDecision?: string; statusCheckRollup?: Check[] }
type PeekView = View & {
  title?: string
  author?: { login?: string }
  isDraft?: boolean
  additions?: number
  deletions?: number
  changedFiles?: number
}

const FAILED = new Set(['FAILURE', 'TIMED_OUT', 'CANCELLED', 'ACTION_REQUIRED', 'STARTUP_FAILURE', 'ERROR'])

// CheckRun has status/conclusion, StatusContext has state.
export function summarize(view: View): Pr {
  const pr: Pr = {
    number: view.number,
    url: view.url,
    pass: 0,
    fail: 0,
    pending: 0,
    failed: [],
    merge: view.mergeStateStatus ?? '',
    review: view.reviewDecision ?? '',
    e2eRun: null,
  }
  for (const c of view.statusCheckRollup ?? []) {
    const result = c.state ?? (c.status === 'COMPLETED' ? c.conclusion : 'PENDING') ?? 'PENDING'
    if (result === 'PENDING' || result === 'EXPECTED' || result === '') pr.pending += 1
    else if (FAILED.has(result)) {
      const name = c.name ?? c.context ?? '?'
      pr.fail += 1
      pr.failed.push(name)
      if (pr.e2eRun === null && /e2e/i.test(name)) pr.e2eRun = /\/actions\/runs\/(\d+)/.exec(c.detailsUrl ?? '')?.[1] ?? null
    } else pr.pass += 1
  }
  return pr
}

export const needsRebase = (pr: Pr) => pr.merge === 'DIRTY' || pr.merge === 'BEHIND'

// `owner/repo` from a PR url, the -R that gh run download needs.
export const repoOf = (url: string) => /github\.com\/([^/\s]+\/[^/\s]+)\/pull\//.exec(url)?.[1] ?? null

// The first PR link in a prompt: a full URL, never a bare #n (too many false hits).
export const PR_LINK = /https:\/\/github\.com\/[^/\s]+\/[^/\s]+\/pull\/\d+/

export function summarizePeek(view: PeekView, names: Record<string, string>): Peek {
  const login = view.author?.login ?? '?'
  return {
    ...summarize(view),
    title: view.title ?? '',
    author: names[login.toLowerCase()] ?? `${login} (nie wiem kto to)`,
    isDraft: view.isDraft ?? false,
    additions: view.additions ?? 0,
    deletions: view.deletions ?? 0,
    files: view.changedFiles ?? 0,
  }
}

// people.md rows: | Full name | GitHub | Slack ID | … ; logins may sit in backticks.
export function namesFrom(markdown: string): Record<string, string> {
  const names: Record<string, string> = {}
  for (const line of markdown.split('\n')) {
    const cells = line.split('|').map(c => c.trim().replace(/`/g, ''))
    const [, name, login] = cells
    if (!name || !login || name === 'Full name' || /^-+$/.test(name)) continue
    names[login.toLowerCase()] = name
  }
  return names
}
