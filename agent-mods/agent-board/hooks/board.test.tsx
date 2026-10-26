import { expect, mock, test } from 'claude-code/testing'

const PANE = {
  plugin: 'agent-board',
  component: 'Pane',
  requestId: 'agent-board',
  props: { title: 'Agenci', isFocused: false, bodyColumns: 60, placement: 'dock', scroll: { offset: 0, bodyRows: 20 }, view: {} },
} as const

test('a spawn opens the pane once; rows show model and age and open the agent', async ($, on) => {
  const clock = mock.clock(on)
  let opened = 0
  const viewed: unknown[] = []
  on('command.register', () => ({ value: { command: 'agenci' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('ui.open', () => (opened++, { value: { isPlaced: true } }))
  on('ui.view', (_, e) => (viewed.push(e), { value: {} }))
  on('tool.call', () => ({ result: {} }))
  on('agent.list', () => ({
    value: [{ id: 'a1', description: 'PR review #31204', type: 'general-purpose', status: 'running' }],
  }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  await $.tool.call({ tool: 'Agent', description: 'PR review #31204', prompt: 'review', model: 'opus' })
  await $.tool.call({ tool: 'Agent', description: 'Slack digest', prompt: 'digest', model: 'sonnet' })
  expect(opened).toBe(1)
  await clock.advance(120_000)

  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    const row = await ui.find({ type: 'Button', key: 'a1' })
    expect(row?.text).toContain('▶ PR review #31204')
    expect(row?.text).toContain('opus 2m')
    await ui.press({ key: 'a1' })
    await ui.unmount()
  }
  expect(viewed[0]).toEqual({ agentId: 'a1' })
})
