import type { Pr } from '../types'

type Check = { name?: string; context?: string; status?: string; conclusion?: string; state?: string }
type View = { number: number; url: string; mergeStateStatus?: string; reviewDecision?: string; statusCheckRollup?: Check[] }

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
  }
  for (const c of view.statusCheckRollup ?? []) {
    const result = c.state ?? (c.status === 'COMPLETED' ? c.conclusion : 'PENDING') ?? 'PENDING'
    if (result === 'PENDING' || result === 'EXPECTED' || result === '') pr.pending += 1
    else if (FAILED.has(result)) {
      pr.fail += 1
      pr.failed.push(c.name ?? c.context ?? '?')
    } else pr.pass += 1
  }
  return pr
}

export const needsRebase = (pr: Pr) => pr.merge === 'DIRTY' || pr.merge === 'BEHIND'
