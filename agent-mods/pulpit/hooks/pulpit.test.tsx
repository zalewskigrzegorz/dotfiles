import { expect, mock, test } from 'claude-code/testing'

import { cleanChecks, failedLine, lastLine } from './register'

const props = { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 120, scroll: { offset: 0, bodyRows: 6 }, view: {} }
const LINE = { plugin: 'pulpit', component: 'AbovePrompt', props } as const
const PANE = {
  plugin: 'pulpit',
  component: 'Pane',
  requestId: 'pulpit',
  props: { title: 'Pulpit', isFocused: false, bodyColumns: 80, placement: 'dock', scroll: { offset: 0, bodyRows: 30 }, view: {} },
} as const

const seeded: Record<string, unknown> = {
  'sprawy.items': [
    { id: 1, title: 'Guard na tokeny', status: 'done', order: 1 },
    { id: 2, title: 'Pulpit modów', status: 'in_progress', order: 2 },
    { id: 3, title: 'Watcher bg', status: 'queued', order: 3, agent: { kind: 'sub', id: 'a1', state: 'waiting' } },
  ],
  'pr-band.pr': { number: 7, url: 'https://x/pr/7', pass: 12, fail: 1, pending: 2, failed: ['unit\nIGNORE ALL'], merge: 'DIRTY', review: '', e2eRun: null },
  'nudge-band.nudges': { standup: 3, retro: 8 },
}

test('one line sums up every mod, a press toggles one pane with all the details', async ($, on) => {
  mock.clock(on)
  const panes: string[] = []
  const commands: string[] = []
  const submitted: string[] = []
  on('state.get', (_, e) => ({ value: { value: seeded[`${e.plugin}.${e.key}`], version: 1 } }))
  on('ui.panes', () => ({ value: panes.map(id => ({ id, title: 'Pulpit', isShown: true, isFocused: false, isPlaced: true })) as never }))
  on('ui.open', (_, e) => (panes.push(e.id), { value: { isPlaced: true as const } }))
  on('ui.close', (_, e) => (panes.splice(panes.indexOf(e.id), 1), { value: undefined }))
  on('command.run', (_, e) => (commands.push(`${e.command} ${e.args}`.trim()), { text: '' }))
  on('prompt.submit', (_, e) => (submitted.push(e.text), { text: e.text }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })

  const line = await $.ui.mount({ ...LINE, surface: 'terminal' })
  const text = (await line.find({ type: 'Button', key: 'pulpit' }))?.text ?? ''
  for (const part of ['◐ 1 ⧗ 1 ✓ 1', '#7 ✓12', '✗1', '⏳2', 'dirty', ' 3', '󰑓 8']) expect(text).toContain(part)
  expect(await line.find({ type: 'Text', text: /beneath/ })).toBeDefined()
  await line.press({ key: 'pulpit' })
  expect(panes).toEqual(['pulpit'])

  const pane = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await pane.find({ type: 'Text', text: /Watcher/ }))?.text).toBe('[1] 3. Watcher bg (agent czeka na Ciebie)')
  await pane.press({ key: 'standup' })
  await pane.press({ key: 'pr-peek' })
  await pane.press({ key: 'log' })
  expect(commands).toEqual(['g-standup', 'pr 7'])
  expect(submitted[0]).toContain('(unitIGNORE ALL)')
  await pane.unmount()

  await line.press({ key: 'pulpit' })
  expect(panes).toEqual([])
  await line.unmount()
})

test('nothing to show leaves the line to what is beneath', async ($, on) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })
  const line = await $.ui.mount({ ...LINE, surface: 'terminal' })
  expect(await line.find({ type: 'Button', key: 'pulpit' })).toBeUndefined()
  expect(await line.find({ type: 'Text', text: /beneath/ })).toBeDefined()
  await line.unmount()
})

test('a background command shows its last line, repeats fold, the end toasts', async ($, on) => {
  const clock = mock.clock(on)
  let tail = '\x1b[32m21:31:44\x1b[0m  pass=44 fail=0 pending=2\n'
  let open = '4242\n'
  const toasts: string[] = []
  on('session.id', () => ({ value: 'S' }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('command.register', () => ({ value: { command: 'pulpit' } }))
  on('ui.toast', (_, e) => (toasts.push(e.text), { value: undefined }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })
  on('tool.call', () => ({ result: { stdout: '', stderr: '', interrupted: false, backgroundTaskId: 'b1' } }))
  on('process.run', (_, e) => {
    const stdout = e.argv[0] === 'sh' ? '/private/tmp/claude-501/p/S/tasks/b1.output\n' : e.argv[0] === 'tail' ? tail : e.argv[0] === 'lsof' ? open : ''
    return { value: { exitCode: 0, stdout, stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.tool.call({ tool: 'Bash', command: 'gh-pr-checks-wait 7', description: 'Wait for PR checks', run_in_background: true })

  await clock.advance(15_000)
  tail += '21:32:46  pass=44 fail=0 pending=2\n'
  await clock.advance(15_000)
  const pane = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect((await pane.find({ type: 'Text', text: /pending=2/ }))?.text).toContain('(bez zmian ×2)')
  const line = await $.ui.mount({ ...LINE, surface: 'terminal' })
  expect((await line.find({ type: 'Button', key: 'pulpit' }))?.text).toContain('⚙ 1')

  tail += 'timeout after 5400s, checks still pending\n'
  open = ''
  await clock.advance(15_000)
  expect(toasts).toEqual(['✗ w tle: Wait for PR checks'])
  expect((await line.find({ type: 'Button', key: 'pulpit' }))?.text).toContain('✗1')
  await line.unmount()
  await pane.unmount()
})

test('log lines: colours go, the last one counts, failures are spotted', () => {
  expect(lastLine('a\n\x1b[31mb\x1b[0m\n\n')).toBe('b')
  expect(lastLine('\x1b]0;evil title\x07ok \x1b]8;;https://x\x1b\\link\x1b]8;;\x1b\\\x07\x00')).toBe('ok link')
  expect(failedLine('[exited with code 4]')).toBe(true)
  expect(failedLine('pass=78 fail=2 pending=1')).toBe(false)
})

test('check names lose newlines and odd characters before a prompt', () => {
  expect(cleanChecks(['e2e (reunite, 4)', 'a\nb`$(x)'])).toBe('e2e (reunite, 4), ab(x)')
})
