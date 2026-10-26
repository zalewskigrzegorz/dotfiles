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
