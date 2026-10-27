import { expect, mock, test } from 'claude-code/testing'

const BAND = {
  plugin: 'pr-band',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 100, scroll: { offset: 0, bodyRows: 6 }, view: {} },
} as const

const PANE = {
  plugin: 'pr-band',
  component: 'Pane',
  requestId: 'pr-peek',
  props: { title: 'PR', isFocused: false, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 20 }, view: {} },
} as const

const view = (checks: object[]) =>
  JSON.stringify({ number: 7, url: 'https://x/pr/7', title: 'Fix', author: { login: 'x' }, mergeStateStatus: 'DIRTY', reviewDecision: '', statusCheckRollup: checks })

test('the PR segment sits beside what is beneath, a press toggles the pane with the actions, toast when checks finish', async ($, on) => {
  const clock = mock.clock(on)
  let panes: string[] = []
  on('ui.panes', () => ({ value: panes.map(id => ({ id, title: 'PR', isShown: true, isFocused: false, isPlaced: true })) as never }))
  on('ui.open', (_, e) => (panes.push(e.id), { value: { isPlaced: true as const } }))
  on('ui.close', (_, e) => ((panes = panes.filter(p => p !== e.id)), { value: undefined }))
  let checks: object[] = [{ name: 'unit', status: 'IN_PROGRESS' }]
  const toasts: string[] = []
  const submitted: string[] = []
  on('process.run', () => ({ value: { exitCode: 0, stdout: view(checks), stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('ui.toast', (_, e) => (toasts.push(e.text), { value: undefined }))
  on('audio.play', () => ({ value: undefined }))
  on('prompt.submit', (_, e) => (submitted.push(e.text), { text: e.text }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'pr' } }))
  // Stands for another plugin's band (nudge-band) beneath this one.
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })

  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.settle()

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...BAND, surface })
    expect((await ui.find({ type: 'Text', text: /#7/ }))?.text).toBe('󰘬 #7 ')
    expect(await ui.find({ type: 'Text', text: /beneath/ })).toBeDefined()
    expect(await ui.find({ type: 'Text', text: /dirty/ })).toBeDefined()
    await ui.unmount()
  }

  checks = [{ name: 'unit', status: 'COMPLETED', conclusion: 'FAILURE' }]
  await clock.advance(90_000)
  expect(toasts).toEqual(['PR #7: 1 checków padło'])

  const band = await $.ui.mount({ ...BAND, surface: 'terminal' })
  await band.press({ key: 'pr' })
  expect(panes).toEqual(['pr-peek'])
  // Opened by hand, a plain prompt leaves it up.
  await $.prompt.submit({ text: 'ok', wait: false, origin: { kind: 'composer' } })
  await clock.settle()
  expect(panes).toEqual(['pr-peek'])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Button', key: 'rebase' })).toBeDefined()
  await ui.press({ key: 'log' })
  expect(submitted.find(t => t.includes('--log-failed'))).toContain('unit')
  await ui.unmount()
  await band.press({ key: 'pr' })
  expect(panes).toEqual([])
  await band.unmount()
})

test('no PR draws only what is beneath', async ($, on) => {
  mock.clock(on)
  on('process.run', () => ({ value: { exitCode: 1, stdout: '', stderr: 'no pull requests found', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'pr' } }))
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

test('a PR link in the prompt opens the peek, the next prompt closes it', async ($, on) => {
  const clock = mock.clock(on)
  const opened: string[] = []
  const closed: string[] = []
  on('process.run', (_, e) => ({
    value: {
      exitCode: e.argv[0] === 'gh' ? 0 : 1,
      stdout: JSON.stringify({ number: 9, url: 'https://github.com/o/r/pull/9', title: 'Teams in one table', author: { login: 'x' }, additions: 5, deletions: 2, changedFiles: 3 }),
      stderr: '',
      isStdoutTruncated: false,
      isStderrTruncated: false,
    },
  }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'pr' } }))
  on('ui.open', (_, e) => (opened.push(e.id), { value: { isPlaced: true as const } }))
  on('ui.close', (_, e) => (closed.push(e.id), { value: undefined }))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  await $.prompt.submit({ text: 'zrób review https://github.com/o/r/pull/9', wait: false, origin: { kind: 'composer' } })
  await clock.settle()
  expect(opened).toEqual(['pr-peek'])

  const ui = await $.ui.mount({
    plugin: 'pr-band',
    component: 'Pane',
    requestId: 'pr-peek',
    surface: 'terminal',
    props: { title: 'PR', isFocused: false, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 20 }, view: {} },
  })
  expect((await ui.find({ type: 'Text', text: /Teams in one table/ }))?.text).toBe('#9 Teams in one table')
  expect(await ui.find({ type: 'Text', text: /x \(nie wiem kto to\)/ })).toBeDefined()
  // A foreign PR gets no prompt actions.
  expect(await ui.find({ type: 'Button', key: 'log' })).toBeUndefined()
  await ui.unmount()

  await $.prompt.submit({ text: 'ok dzięki', wait: false, origin: { kind: 'composer' } })
  await clock.settle()
  expect(closed).toEqual(['pr-peek'])
})

test('the e2e button pulls the failure shots and hands the folder to /screen', async ($, on) => {
  const clock = mock.clock(on)
  const shown: string[] = []
  const ran: string[] = []
  const failed = JSON.stringify({
    number: 7,
    url: 'https://github.com/o/r/pull/7',
    title: 'Fix',
    author: { login: 'x' },
    statusCheckRollup: [{ name: 'e2e (reunite, 4)', status: 'COMPLETED', conclusion: 'FAILURE', detailsUrl: 'https://github.com/o/r/actions/runs/42/job/1' }],
  })
  on('process.run', (_, e) => {
    ran.push(e.argv.slice(0, 3).join(' '))
    const stdout = e.argv[1] === 'pr' ? failed : e.argv[0] === 'find' && e.argv.includes('*.png') ? '/c/e2e-42/a.png\n' : e.argv[0] === 'find' && e.argv.includes('*.zip') ? '/c/e2e-42/report.zip\n' : ''
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  on('command.run', (_, e) => (shown.push(`${e.command} ${e.args}`), { text: '' }))
  on('ui.toast', () => ({ value: undefined }))
  on('ui.panes', () => ({ value: [] }))
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'pr' } }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await clock.settle()

  const band = await $.ui.mount({ ...BAND, surface: 'terminal' })
  await band.press({ key: 'pr' })
  await band.unmount()
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  await ui.press({ key: 'e2e' })
  expect(ran).toContain('gh run download')
  expect(shown).toEqual(['screen /Users/greg/Library/Caches/shot-pane/e2e-42'])
  await ui.unmount()
})
