import { expect, mock, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

const BAND = {
  plugin: 'sprawy',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isWorking: false, maxRows: 6, bodyColumns: 100, scroll: { offset: 0, bodyRows: 6 }, view: {} },
} as const
const TOOL = 'mcp__sprawy__sprawa' as const

let agents: { id: string; status: string; description: string; type: string }[] = []
let tuios = { agents: [] as { window_id: string; state: string; needs_you: boolean }[] }

async function start(...[$, on]: Parameters<TestBody>) {
  agents = []
  tuios = { agents: [] }
  const clock = mock.clock(on)
  on('tool.register', (_, e) => ({ value: { tool: `mcp__sprawy__${e.name}` } }))
  on('agent.list', () => ({ value: agents as never }))
  on('process.run', () => ({
    value: { exitCode: 0, stdout: JSON.stringify(tuios), stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>beneath</Text>
  })
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  return clock
}

test('items queue, urgent jumps, done stays dimmed, band composes', async ($, on) => {
  await start($, on)
  const empty = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await empty.find({ type: 'Text', text: /Sprawy/ })).toBeUndefined()
  expect(await empty.find({ type: 'Text', text: /beneath/ })).toBeDefined()
  await empty.unmount()

  await $.tool.call({ tool: TOOL, action: 'add', title: 'Pasek agentów' })
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Kolory w tabach' })
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Popup za szeroki', urgent: true })
  await $.tool.call({ tool: TOOL, action: 'set', id: 1, status: 'done' })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /Sprawy/ }))?.text).toContain('kolejka 2')
  expect((await ui.find({ type: 'Text', text: /Popup/ }))?.text).toContain('[1] 3. Popup za szeroki')
  expect((await ui.find({ type: 'Text', text: /Kolory/ }))?.text).toContain('[2] 2. Kolory w tabach')
  const done = await ui.find({ type: 'Text', text: /Pasek/ })
  expect(done?.text).toContain('✓ 1. Pasek agentów')
  expect(done?.props.dimColor).toBe(true)
  expect(await ui.find({ type: 'Text', text: /beneath/ })).toBeDefined()
  await ui.unmount()

  const bad = await $.tool.call({ tool: TOOL, action: 'set', id: 9, status: 'done' })
  expect('deny' in bad && bad.deny).toContain('No item with id 9')
})

test('an item follows its subagent and its tuios agent, and ticks itself done', async ($, on) => {
  const clock = await start($, on)
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Review PR' })
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Fix w workctl' })

  agents = [{ id: 'a1', status: 'running', description: 'review', type: 'general-purpose' }]
  tuios = { agents: [{ window_id: 'w1', state: 'working', needs_you: false }] }
  await $.tool.call({ tool: TOOL, action: 'set', id: 1, agent: 'a1' })
  await $.tool.call({ tool: TOOL, action: 'set', id: 2, agent: 'w1' })
  const unknown = await $.tool.call({ tool: TOOL, action: 'set', id: 2, agent: 'nope' })
  expect('deny' in unknown && unknown.deny).toContain('No subagent or tuios window')

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect((await ui.find({ type: 'Text', text: /Review/ }))?.text).toContain('◐ 1. Review PR (agent pracuje)')

  tuios = { agents: [{ window_id: 'w1', state: 'needs_input', needs_you: true }] }
  await clock.advance(20_000)
  await clock.settle()
  expect((await ui.find({ type: 'Text', text: /workctl/ }))?.text).toContain('agent czeka na Ciebie')

  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer', agentId: 'a1' })
  expect((await ui.find({ type: 'Text', text: /Review/ }))?.text).toContain('✓ 1. Review PR')

  tuios = { agents: [{ window_id: 'w1', state: 'done', needs_you: false }] }
  await clock.advance(20_000)
  await clock.settle()
  expect((await ui.find({ type: 'Text', text: /workctl/ }))?.text).toContain('✓ 2. Fix w workctl')
  await ui.unmount()
})
