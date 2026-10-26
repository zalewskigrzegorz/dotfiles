import { expect, mock, test } from 'claude-code/testing'

test('pings every 5 min, at most three times, and stops once answered', async ($, on) => {
  const clock = mock.clock(on)
  const notes: string[] = []
  on('session.cwd', () => ({ value: '/Users/greg/Code/dotfiles' }))
  on('ui.notify', (_, e) => (notes.push(e.text), { value: { isSent: true, channel: 'iterm2' } }))
  on('audio.play', () => ({ value: undefined }))
  // The popup stays open for 25 min, then Greg answers.
  on('tool.call', async () => (await clock.sleep(25 * 60_000), { result: {} }))

  const call = $.tool.call({
    tool: 'AskUserQuestion',
    questions: [{ question: 'Co dalej?', header: 'Dalej', multiSelect: false, options: [{ label: 'a', description: 'a' }, { label: 'b', description: 'b' }] }],
  })
  await clock.advance(5 * 60_000)
  expect(notes).toEqual(['Popup czeka od 5 min'])
  await clock.advance(20 * 60_000)
  await call
  expect(notes).toEqual(['Popup czeka od 5 min', 'Popup czeka od 10 min', 'Popup czeka od 15 min'])
})

test('an answer before 5 min sends nothing', async ($, on) => {
  const clock = mock.clock(on)
  const notes: string[] = []
  on('session.cwd', () => ({ value: '/x' }))
  on('ui.notify', (_, e) => (notes.push(e.text), { value: { isSent: true, channel: 'iterm2' } }))
  on('tool.call', async () => (await clock.sleep(60_000), { result: {} }))

  const call = $.tool.call({
    tool: 'AskUserQuestion',
    questions: [{ question: 'Co dalej?', header: 'Dalej', multiSelect: false, options: [{ label: 'a', description: 'a' }, { label: 'b', description: 'b' }] }],
  })
  await clock.advance(60_000)
  await call
  await clock.advance(30 * 60_000)
  expect(notes).toEqual([])
})
