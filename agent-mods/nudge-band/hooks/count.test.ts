import { expect, test } from 'claude-code/testing'

import { countOf } from './register'

test('reads counts from the hook lines', () => {
  expect(countOf('standup-pending: 13 work task(s) logged since', /(\d+) work task/)).toBe(13)
  expect(countOf('retro-pending: 8 session(s) in 3 repo(s)', /(\d+) session\(s\)/)).toBe(8)
  expect(countOf('', /(\d+) work task/)).toBe(0)
})
