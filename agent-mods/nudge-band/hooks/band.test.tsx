import { expect, mock, test } from 'claude-code/testing'

// pulpit draws the counts; this mod only keeps them fresh: on start, on a timer and after each turn.
test('the hooks are read at start and again after a turn', async ($, on) => {
  const clock = mock.clock(on)
  const ran: string[] = []
  on('process.run', (_, e) => {
    ran.push(e.argv.join(' ').includes('standup') ? 'standup' : 'retro')
    return { value: { exitCode: 0, stderr: '', isStdoutTruncated: false, isStderrTruncated: false, stdout: '' } }
  })
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.id', () => ({ value: 's1' }))
  on('session.cwd', () => ({ value: '/' }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.settle()
  expect(ran.sort()).toEqual(['retro', 'standup'])

  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })
  await clock.settle()
  expect(ran.length).toBe(4)
})
