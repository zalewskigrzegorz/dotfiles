import { expect, mock, test } from 'claude-code/testing'

const PANE = {
  plugin: 'shot-pane',
  component: 'Pane',
  requestId: 'shot-pane',
  props: { title: 'Screen', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 30 }, view: {} },
} as const
const MIN = 60_000

test('a screenshot prompt opens the pane on the recent PNGs, newest first', async ($, on) => {
  const clock = mock.clock(on, { now: 100 * MIN })
  mock.env(on, {})
  let opened = 0
  on('ui.open', () => (opened++, { value: { isPlaced: true } }))
  const resized: string[] = []
  on('fs.stat', () => ({ value: { kind: 'other' as const, size: 0, mtimeMs: 0, isLink: false } }))
  on('process.run', (_, e) => (e.argv[0] === 'sips' && resized.push(String(e.argv[3]).split('/').pop() ?? ''), { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  const read: string[] = []
  on('fs.read', (_, e) => (read.push(e.path), { value: { base64: 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' } }))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('fs.list', () => ({
    value: [
      { name: 'old.png', kind: 'file', size: 1, isLink: false, mtimeMs: 10 * MIN },
      { name: 'new.png', kind: 'file', size: 1, isLink: false, mtimeMs: 99 * MIN },
      { name: 'mid.png', kind: 'file', size: 1, isLink: false, mtimeMs: 95 * MIN },
      { name: 'clip.mp4', kind: 'file', size: 1, isLink: false, mtimeMs: 99 * MIN },
    ],
  }))

  await $.prompt.submit({ text: 'zobacz screen, co tu nie gra', wait: false, origin: { kind: 'composer' } })
  await clock.settle()
  expect(opened).toBe(1)

  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  const names = (await ui.findAll({ type: 'Text' })).map(t => t.text)
  expect(names).toEqual(['new.png', 'mid.png'])
  expect(read.map(p => p.split('/').pop())).toEqual(['new.png', 'mid.png'])
  expect(resized).toEqual(['new.png', 'mid.png'])
  expect(read.every(p => p.startsWith('/Users/greg/Library/Caches/shot-pane/'))).toBe(true)
  await ui.unmount()
})

test('an ordinary prompt leaves the folder alone and closes the preview', async ($, on) => {
  const clock = mock.clock(on)
  let listed = 0
  const closed: string[] = []
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('fs.list', () => (listed++, { value: [] }))
  on('ui.close', (_, e) => (closed.push(e.id), { value: undefined }))
  await $.prompt.submit({ text: 'zrób commit', wait: false, origin: { kind: 'composer' } })
  await clock.settle()
  expect(listed).toBe(0)
  expect(closed).toEqual(['shot-pane'])
})

test('a pane too narrow to seat says how to open it, and /screen opens it', async ($, on) => {
  const clock = mock.clock(on, { now: 100 * MIN })
  mock.env(on, {})
  const toasts: string[] = []
  let opened = 0
  on('ui.open', () => (opened++, { value: opened > 1 ? { isPlaced: true as const } : { isPlaced: false as const, reason: 'narrow' } }))
  on('ui.toast', (_, e) => (toasts.push(e.text), { value: undefined }))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('command.register', () => ({ value: { command: 'screen' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('fs.list', () => ({ value: [{ name: 'new.png', kind: 'file', size: 1, isLink: false, mtimeMs: 99 * MIN }] }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  await $.prompt.submit({ text: 'scr', wait: false, origin: { kind: 'composer' } })
  await clock.settle()
  expect(toasts).toEqual(['Screen gotowy: /screen otwiera podgląd'])

  const ran = await $.command.run({ command: 'screen', args: '', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 120 } })
  expect(ran.text).toBe('Podgląd screena otwarty.')
  expect(opened).toBe(2)
})

test('the preview closes itself after three minutes', async ($, on) => {
  const clock = mock.clock(on, { now: 100 * MIN })
  mock.env(on, {})
  const closed: string[] = []
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('ui.close', (_, e) => (closed.push(e.id), { value: undefined }))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('fs.list', () => ({ value: [{ name: 'new.png', kind: 'file', size: 1, isLink: false, mtimeMs: 99 * MIN }] }))

  await $.prompt.submit({ text: 'scr', wait: false, origin: { kind: 'composer' } })
  await clock.advance(2 * MIN)
  expect(closed).toEqual([])
  await clock.advance(MIN)
  expect(closed).toEqual(['shot-pane'])
})

test('/screen <folder> shows that folder, newest first, at most four', async ($, on) => {
  mock.clock(on)
  mock.env(on, {})
  const listed: string[] = []
  on('ui.open', () => ({ value: { isPlaced: true as const } }))
  on('command.register', () => ({ value: { command: 'screen' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('fs.list', (_, e) => (listed.push(e.path ?? ''), { value: [1, 2, 3, 4, 5].map(n => ({ name: `s${n}.png`, kind: 'file' as const, size: 1, isLink: false, mtimeMs: n })) }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  const ran = await $.command.run({ command: 'screen', args: '/c/e2e-42', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 120 } })
  expect(ran.text).toBe('Podgląd screena otwarty.')
  expect(listed).toEqual(['/c/e2e-42'])
})

test('inside tuios a screenshot prompt and /screen <folder> open a kitty-show popup, not the pane', async ($, on) => {
  const clock = mock.clock(on, { now: 100 * MIN })
  mock.env(on, { TUIOS_PANE_ID: '7', HOME: '/h' })
  let opened = 0
  const runs: string[][] = []
  on('ui.open', () => (opened++, { value: { isPlaced: true as const } }))
  on('fs.stat', () => ({ value: { kind: 'file' as const, size: 1, mtimeMs: 0, isLink: false } }))
  on('process.run', (_, e) => (runs.push([...e.argv]), { value: { exitCode: 0, stdout: '', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('command.register', () => ({ value: { command: 'screen' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('fs.list', () => ({ value: [{ name: 'new.png', kind: 'file', size: 1, isLink: false, mtimeMs: 99 * MIN }] }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  await $.prompt.submit({ text: 'scr', wait: false, origin: { kind: 'composer' } })
  await clock.settle()
  const popup = ['tuios', 'popup', '--width', '90%', '--height', '90%', '--', '/h/bin/kitty-show']
  expect(runs.filter(r => r[0] === 'tuios')).toEqual([[...popup, '/Users/greg/Library/Caches/shot-pane/new.png']])

  const ran = await $.command.run({ command: 'screen', args: '/c/e2e', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 120 } })
  expect(ran.text).toBe('Podgląd screena otwarty.')
  expect(runs.filter(r => r[0] === 'tuios').at(-1)).toEqual([...popup, '/Users/greg/Library/Caches/shot-pane/new.png'])
  expect(opened).toBe(0)
})
