import { expect, test } from 'claude-code/testing'

import { needsRebase, summarize } from './pr'

test('counts check runs and status contexts', () => {
  const pr = summarize({
    number: 7,
    url: 'u',
    mergeStateStatus: 'DIRTY',
    reviewDecision: 'APPROVED',
    statusCheckRollup: [
      { name: 'lint', status: 'COMPLETED', conclusion: 'SUCCESS' },
      { name: 'skip', status: 'COMPLETED', conclusion: 'SKIPPED' },
      { name: 'e2e', status: 'IN_PROGRESS' },
      { name: 'unit', status: 'COMPLETED', conclusion: 'FAILURE' },
      { context: 'ci/legacy', state: 'ERROR' },
      { context: 'ci/wait', state: 'PENDING' },
    ],
  })
  expect(pr).toEqual({ number: 7, url: 'u', pass: 2, fail: 2, pending: 2, failed: ['unit', 'ci/legacy'], merge: 'DIRTY', review: 'APPROVED' })
  expect(needsRebase(pr)).toBe(true)
})

test('no checks yet', () => {
  const pr = summarize({ number: 1, url: 'u' })
  expect([pr.pass, pr.fail, pr.pending, pr.merge]).toEqual([0, 0, 0, ''])
  expect(needsRebase(pr)).toBe(false)
})
