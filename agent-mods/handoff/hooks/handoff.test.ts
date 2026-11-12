import { expect, mock, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

const RUN = { origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 120 } } as const
const TURN = { answer: 'ok', durationMs: 1, isAborted: false, turnId: 't', reason: 'end_turn' } as never

function stub(on: Parameters<TestBody>[1], sizes: number[]) {
  const toasts: string[] = []
  const compacted: (string | undefined)[] = []
  const submitted: string[] = []
  on('session.usage', () => ({ value: { startedAt: 0, context: { tokens: sizes.shift(), window: 1_000_000 }, rateLimits: [] } }))
  on('ui.toast', (_, e) => (toasts.push(e.text), { value: undefined }))
  on('session.compact', (_, e) => (compacted.push(e.instructions), { messages: [{ role: 'user', text: 'summary', toolUses: [] }] }) as never)
  on('prompt.submit', (_, e) => (submitted.push(e.text), { text: e.text }) as never)
  on('turn.complete', (_, e) => ({ text: e.answer }) as never)
  on('command.register', () => ({ value: { command: 'handoff' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  return { toasts, compacted, submitted, clock: mock.clock(on) }
}

test('crossing 250k toasts once, and again only after the context came back down', async ($, on) => {
  const { toasts } = stub(on, [100_000, 260_000, 300_000, 40_000, 255_000])
  for (let i = 0; i < 5; i++) await $.turn.complete(TURN)
  expect(toasts.length).toBe(2)
  expect(toasts[0]).toContain('260k')
})

test('/handoff asks for a status turn, then compacts with the hand-over instructions', async ($, on) => {
  const { compacted, submitted, toasts, clock } = stub(on, [])
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'handoff', args: '', ...RUN })
  await clock.settle()
  expect(submitted[0]).toContain('następny krok')
  expect(compacted).toEqual([])
  await $.turn.complete(TURN)
  expect(compacted[0]).toContain('hand-over')
  expect(toasts).toEqual(['handoff: rozmowa zastąpiona przekazaniem, kontekst od nowa'])
  await $.turn.complete(TURN) // the next turn does not compact again
  expect(compacted.length).toBe(1)
})
