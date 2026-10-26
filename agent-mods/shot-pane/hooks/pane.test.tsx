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
  await ui.unmount()
})

test('an ordinary prompt leaves the folder alone', async ($, on) => {
  mock.clock(on)
  let listed = 0
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('fs.list', () => (listed++, { value: [] }))
  await $.prompt.submit({ text: 'zrób commit', wait: false, origin: { kind: 'composer' } })
  expect(listed).toBe(0)
})
