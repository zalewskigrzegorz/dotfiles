import { expect, mock, test } from 'claude-code/testing'

test('reports num and pr to the tuios rail, and pr= once the PR is gone', async ($, on) => {
  const clock = mock.clock(on)
  mock.env(on, { TUIOS_PANE_ID: 'w7', TUIOS_SESSION: 'dots' })
  let gh = { exitCode: 0, stdout: JSON.stringify({ number: 7, url: 'https://x/pr/7', state: 'OPEN', isDraft: true }), stderr: '' }
  const meta: string[] = []
  on('process.run', (_, e) => {
    if (e.argv[1] === 'set-agent-meta') meta.push(e.argv.join(' '))
    const out = e.argv[0] === 'gh' ? gh : { exitCode: 0, stdout: JSON.stringify([{ name: 'other' }, { name: 'dots' }]), stderr: '' }
    return { value: { ...out, isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'pr' } }))
  on('prompt.submit', (_, e) => ({ text: e.text }))

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.settle()
  expect(meta).toContain('tuios set-agent-meta -w w7 --source greg pr=#7 draft')
  expect(meta.some(m => m.includes('num=2'))).toBe(true)

  meta.length = 0
  await $.prompt.submit({ text: 'hej', wait: false, origin: { kind: 'composer' } })
  await clock.settle()
  expect(meta).toEqual(['tuios set-agent-meta -w w7 --source greg num=2 pr=#7 draft'])

  meta.length = 0
  gh = { exitCode: 1, stdout: '', stderr: 'no pull requests found for branch "x"' }
  await clock.advance(90_000)
  expect(meta).toEqual(['tuios set-agent-meta -w w7 --source greg pr='])
})
