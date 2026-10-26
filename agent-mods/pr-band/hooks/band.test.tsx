import { expect, mock, test } from 'claude-code/testing'

const BAND = {
  plugin: 'pr-band',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 100, scroll: { offset: 0, bodyRows: 6 }, view: {} },
} as const

const view = (checks: object[]) =>
  JSON.stringify({ number: 7, url: 'https://x/pr/7', mergeStateStatus: 'DIRTY', reviewDecision: '', statusCheckRollup: checks })

test('draws the PR above what is beneath, buttons work, toast when checks finish', async ($, on) => {
  const clock = mock.clock(on)
  let checks: object[] = [{ name: 'unit', status: 'IN_PROGRESS' }]
  const toasts: string[] = []
  const submitted: string[] = []
  on('process.run', () => ({ value: { exitCode: 0, stdout: view(checks), stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('ui.toast', (_, e) => (toasts.push(e.text), { value: undefined }))
  on('audio.play', () => ({ value: undefined }))
  on('prompt.submit', (_, e) => (submitted.push(e.text), { text: e.text }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  // Stands for another plugin's band (nudge-band) beneath this one.
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.settle()

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    expect((await ui.find({ type: 'Text', text: /PR #7/ }))?.text).toBe('PR #7 ')
    expect(await ui.find({ type: 'Text', text: /beneath/ })).toBeDefined()
    expect(await ui.find({ type: 'Button', key: 'rebase' })).toBeDefined()
    await ui.unmount()
  }

  checks = [{ name: 'unit', status: 'COMPLETED', conclusion: 'FAILURE' }]
  await clock.advance(90_000)
  expect(toasts).toEqual(['PR #7: 1 checków padło'])

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  await ui.press({ key: 'log' })
  expect(submitted[0]).toContain('--log-failed')
  expect(submitted[0]).toContain('unit')
  await ui.unmount()
})

test('no PR draws only what is beneath', async ($, on) => {
  mock.clock(on)
  on('process.run', () => ({ value: { exitCode: 1, stdout: '', stderr: 'no pull requests found', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /PR #/ })).toBeUndefined()
  expect(await ui.find({ type: 'Text', text: /beneath/ })).toBeDefined()
  await ui.unmount()
})
