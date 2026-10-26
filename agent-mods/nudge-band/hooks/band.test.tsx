import { expect, mock, test } from 'claude-code/testing'

const BAND = {
  plugin: 'nudge-band',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 100, scroll: { offset: 0, bodyRows: 6 }, view: {} },
} as const

test('chips run the commands, hide keeps what is beneath', async ($, on) => {
  mock.clock(on)
  const submitted: string[] = []
  on('process.run', (_, e) => ({
    value: {
      exitCode: 0,
      stderr: '',
      isStdoutTruncated: false,
      isStderrTruncated: false,
      stdout: e.argv.join(' ').includes('standup')
        ? 'standup-pending: 13 work task(s) logged since the last standup'
        : 'retro-pending: 8 session(s) in 3 repo(s) never got a /retro',
    },
  }))
  on('command.run', (_, e) => (submitted.push(e.command), { text: '' }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.id', () => ({ value: 's1' }))
  on('session.cwd', () => ({ value: '/' }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Button', key: 'standup' }))?.text).toContain('standup (13)')
  expect((await ui.find({ type: 'Button', key: 'retro' }))?.text).toContain('retro (8)')
  await ui.press({ key: 'standup' })
  await ui.press({ key: 'retro' })
  expect(submitted).toEqual(['g-standup', 'retro-backlog'])

  await ui.press({ key: 'hide' })
  expect(await ui.find({ type: 'Button', key: 'standup' })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /beneath/ })).toBeDefined()
  await ui.unmount()
})

test('the chip goes at the end of the turn that sent the standup', async ($, on) => {
  const clock = mock.clock(on)
  let standup = 'standup-pending: 13 work task(s) logged since the last standup'
  on('process.run', (_, e) => ({
    value: {
      exitCode: 0,
      stderr: '',
      isStdoutTruncated: false,
      isStderrTruncated: false,
      stdout: e.argv.join(' ').includes('standup') ? standup : '',
    },
  }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('session.id', () => ({ value: 's1' }))
  on('session.cwd', () => ({ value: '/' }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Button', key: 'standup' })).toBeDefined()

  standup = ''
  await $.turn.complete({ answer: 'Standup wysłany.', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer' })
  await clock.settle()
  expect(await ui.find({ type: 'Button', key: 'standup' })).toBeUndefined()
  await ui.unmount()
})
