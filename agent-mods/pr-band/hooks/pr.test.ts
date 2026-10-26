import { expect, test } from 'claude-code/testing'

import { PR_LINK, namesFrom, needsRebase, repoOf, summarize, summarizePeek } from './pr'

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
  expect(pr).toEqual({ number: 7, url: 'u', pass: 2, fail: 2, pending: 2, failed: ['unit', 'ci/legacy'], merge: 'DIRTY', review: 'APPROVED', e2eRun: null })
  expect(needsRebase(pr)).toBe(true)
})

test('no checks yet', () => {
  const pr = summarize({ number: 1, url: 'u' })
  expect([pr.pass, pr.fail, pr.pending, pr.merge]).toEqual([0, 0, 0, ''])
  expect(needsRebase(pr)).toBe(false)
})

test('finds the run of a failed e2e check', () => {
  const pr = summarize({
    number: 3,
    url: 'https://github.com/o/r/pull/3',
    statusCheckRollup: [
      { name: 'lint', status: 'COMPLETED', conclusion: 'FAILURE', detailsUrl: 'https://github.com/o/r/actions/runs/11/job/1' },
      { name: 'e2e (reunite, 4)', status: 'COMPLETED', conclusion: 'FAILURE', detailsUrl: 'https://github.com/o/r/actions/runs/42/job/7' },
    ],
  })
  expect(pr.e2eRun).toBe('42')
  expect(repoOf(pr.url)).toBe('o/r')
})

test('a PR link is a full URL, never a bare number', () => {
  expect(PR_LINK.exec('zobacz https://github.com/o/r/pull/31204 pls')?.[0]).toBe('https://github.com/o/r/pull/31204')
  expect(PR_LINK.exec('zobacz #31204')).toBeNull()
})

test('authors come out as full names, unknown ones say so', () => {
  const names = namesFrom('| Full name | GitHub | Slack ID |\n|---|---|---|\n| Ada Lovelace | `adal` | U1 |\n| Bob | | U2 |')
  expect(names).toEqual({ adal: 'Ada Lovelace' })
  expect(summarizePeek({ number: 1, url: 'u', author: { login: 'AdaL' } }, names).author).toBe('Ada Lovelace')
  expect(summarizePeek({ number: 1, url: 'u', author: { login: 'zz' } }, names).author).toBe('zz (nie wiem kto to)')
})
