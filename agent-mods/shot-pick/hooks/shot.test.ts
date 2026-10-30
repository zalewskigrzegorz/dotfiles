import { expect, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

const RUN = { origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 120 } } as const

async function start($: Parameters<TestBody>[0], on: Parameters<TestBody>[1], exitCode: number) {
  const ran: string[][] = []
  on('process.run', (_, e) => (ran.push([...e.argv]), { value: { exitCode, stdout: '', stderr: exitCode ? 'split failed under x' : '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'shot' } }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  return ran
}

test('/shot <folder> opens the picker under this pane for that folder', async ($, on) => {
  const ran = await start($, on, 0)
  const out = await $.command.run({ command: 'shot', args: '/tmp/e2e-42', ...RUN })
  expect(ran.find(a => a[0] === '/Users/greg/bin/shot-pick')).toEqual(['/Users/greg/bin/shot-pick', '--here', '/tmp/e2e-42'])
  expect(out.text).toBeUndefined()
})

test('a picker that cannot open says why', async ($, on) => {
  await start($, on, 1)
  const out = await $.command.run({ command: 'shot', args: '', ...RUN })
  expect(out.text).toBe('shot-pick: split failed under x')
})
