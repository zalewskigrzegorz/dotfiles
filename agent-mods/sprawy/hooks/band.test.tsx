import { expect, mock, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

const TOOL = 'mcp__sprawy__sprawa' as const

const writes: Record<string, unknown> = {}
const deletes: string[] = []
let agents: { id: string; status: string; description: string; type: string }[] = []
let tuios = { agents: [] as { window_id: string; state: string; needs_you: boolean }[] }

const list = async ($: Parameters<TestBody>[0]) => {
  const r = await $.tool.call({ tool: TOOL, action: 'list' })
  return 'result' in r ? String(r.result) : ''
}

async function start(
  [$, on]: Parameters<TestBody>,
  id = 'A',
  entries: Record<string, unknown> = {},
  now = 0,
) {
  agents = []
  tuios = { agents: [] }
  deletes.length = 0
  for (const k of Object.keys(writes)) delete writes[k]
  const clock = mock.clock(on, { now })
  // mock.store, with the writes and deletes exposed (a second on('store.set') would not load).
  const kv = new Map(Object.entries(entries))
  on('store.get', (_, e) => ({ value: kv.get(e.key) }))
  on('store.set', (_, e) => (kv.set(e.key, e.value), writes[e.key] = e.value, { value: undefined }))
  on('store.delete', (_, e) => (kv.delete(e.key), deletes.push(e.key), { value: undefined }))
  on('store.keys', () => ({ value: [...kv.keys()] }))
  on('session.id', () => ({ value: id }))
  on('tool.register', (_, e) => ({ value: { tool: `mcp__sprawy__${e.name}` } }))
  on('agent.list', () => ({ value: agents as never }))
  on('process.run', () => ({
    value: { exitCode: 0, stdout: JSON.stringify(tuios), stderr: '', isStdoutTruncated: false, isStderrTruncated: false },
  }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('turn.complete', (_, e) => ({ text: e.answer }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })
  return clock
}

test('items queue, urgent jumps, done ones stay listed', async ($, on) => {
  await start([$, on])
  expect(await list($)).toBe('No items yet.')

  await $.tool.call({ tool: TOOL, action: 'add', title: 'Pasek agentów' })
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Kolory w tabach' })
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Popup za szeroki', urgent: true })
  await $.tool.call({ tool: TOOL, action: 'set', id: 1, status: 'done' })

  const rows = await list($)
  expect(rows).toContain('3. Popup za szeroki [queued #1]')
  expect(rows).toContain('2. Kolory w tabach [queued #2]')
  expect(rows).toContain('1. Pasek agentów [done]')

  const bad = await $.tool.call({ tool: TOOL, action: 'set', id: 9, status: 'done' })
  expect('deny' in bad && bad.deny).toContain('No item with id 9')
})

test('an item follows its subagent and its tuios agent, and ticks itself done', async ($, on) => {
  const clock = await start([$, on])
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Review PR' })
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Fix w workctl' })

  agents = [{ id: 'a1', status: 'running', description: 'review', type: 'general-purpose' }]
  tuios = { agents: [{ window_id: 'w1', state: 'working', needs_you: false }] }
  await $.tool.call({ tool: TOOL, action: 'set', id: 1, agent: 'a1' })
  await $.tool.call({ tool: TOOL, action: 'set', id: 2, agent: 'w1' })
  const unknown = await $.tool.call({ tool: TOOL, action: 'set', id: 2, agent: 'nope' })
  expect('deny' in unknown && unknown.deny).toContain('No subagent or tuios window')

  expect(await list($)).toContain('1. Review PR [in_progress]')

  tuios = { agents: [{ window_id: 'w1', state: 'needs_input', needs_you: true }] }
  await clock.advance(20_000)
  await clock.settle()
  expect(JSON.stringify(writes['s:A'])).toContain('"state":"waiting"')

  await $.turn.complete({ answer: 'ok', durationMs: 1, isAborted: false, turnId: 't1', reason: 'answer', agentId: 'a1' })
  expect(await list($)).toContain('1. Review PR [done]')

  tuios = { agents: [{ window_id: 'w1', state: 'done', needs_you: false }] }
  await clock.advance(20_000)
  await clock.settle()
  expect(await list($)).toContain('2. Fix w workctl [done]')
})

test('the list is stored per session id and loads back on a resume, not on a new id', async ($, on) => {
  await start([$, on])
  await $.tool.call({ tool: TOOL, action: 'add', title: 'Przetrwa resume' })
  expect(JSON.stringify(writes['s:A'])).toContain('Przetrwa resume')
})

test('a restart with the same session id gets its list back, a different id starts empty', async ($, on) => {
  const entries = {
    's:A': { at: 0, items: [{ id: 1, title: 'Wrócił po resume', status: 'queued', order: 1 }] },
    's:old': { at: 0, items: [] },
  }
  await start([$, on], 'A', entries)
  expect(await list($)).toContain('1. Wrócił po resume [queued #1]')
})

test('a different session id starts empty and old lists are dropped', async ($, on) => {
  const day = 24 * 3600_000
  const entries = {
    's:A': { at: 0, items: [{ id: 1, title: 'Cudza lista', status: 'queued', order: 1 }] },
    's:old': { at: 0, items: [] },
  }
  await start([$, on], 'B', entries, 8 * day)
  expect(await list($)).toBe('No items yet.')
  expect(deletes.sort()).toEqual(['s:A', 's:old'])
})
