import { expect, mock, test } from 'claude-code/testing'

const answer = (texts: string[]) => ({
  value: { status: 200, ok: true, headers: {}, text: JSON.stringify({ results: texts.map((text, i) => ({ id: String(i), text })) }) },
})

test('a trigger prompt carries the recall as context', async ($, on) => {
  mock.clock(on)
  const bodies: string[] = []
  on('http.fetch', (_, e) => (bodies.push(String(e.init?.body)), answer(['pr-band lives in agent-mods'])))
  on('prompt.submit', (_, e) => ({ text: e.text, context: e.context }))

  const ran = await $.prompt.submit({ text: 'wróćmy do pr-band', wait: false, origin: { kind: 'composer' } })
  expect(ran.context?.at(-1)).toContain('- pr-band lives in agent-mods')
  expect(JSON.parse(bodies[0] ?? '{}')).toMatchObject({ query: 'wróćmy do pr-band', max_tokens: 512 })
})

test('an ordinary prompt never asks Hindsight', async ($, on) => {
  mock.clock(on)
  let calls = 0
  on('http.fetch', () => (calls++, answer([])))
  on('prompt.submit', (_, e) => ({ text: e.text, context: e.context }))

  const ran = await $.prompt.submit({ text: 'zrób commit', wait: false, origin: { kind: 'composer' } })
  expect(calls).toBe(0)
  expect(ran.context ?? []).toEqual([])
})

test('a hung lab lets the prompt through after 4 s', async ($, on) => {
  const clock = mock.clock(on)
  on('http.fetch', async () => (await clock.sleep(60_000), answer(['late'])))
  on('prompt.submit', (_, e) => ({ text: e.text, context: e.context }))

  const ran = $.prompt.submit({ text: 'kontynuuj', wait: false, origin: { kind: 'composer' } })
  await clock.advance(4000)
  expect((await ran).context ?? []).toEqual([])
})
