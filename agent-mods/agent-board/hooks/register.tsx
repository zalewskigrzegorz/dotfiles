import { atom, read, update } from 'claude-code'
import type { AgentStatus, Register } from 'claude-code'

const PANE = 'agent-board'
const spawns = atom({ plugin: 'agent-board', key: 'spawns' } as const, {})

const GLYPH: Record<AgentStatus, string> = {
  pending: '…',
  running: '▶',
  waiting: '⏸',
  idle: '·',
  completed: '✓',
  failed: '✗',
  killed: '■',
}

const age = (ms: number) => (ms < 60_000 ? `${Math.round(ms / 1000)}s` : `${Math.round(ms / 60_000)}m`)

export const register: Register = on => {
  let isOpened = false

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'agenci', description: 'Show the subagents of this session in a pane' })
    // agent.list is not state, so poll a redraw while anything still runs.
    $.clock.every(3000, () => {
      void $.agent.list().then(list => list.some(a => a.status === 'running') && $.ui.invalidate('ui.render'))
    })
    return next(e)
  })

  on('command.run', { command: 'agenci' }, async $ => {
    await $.ui.open({ id: PANE, title: 'Agenci' })
    return { text: 'Panel agentów otwarty.' }
  })

  on('tool.call', { tool: 'Agent' }, async ($, e, next) => {
    const startedAt = await $.clock.now()
    await update($, spawns, all => ({ ...all, [e.description]: { model: e.model ?? 'inherit', startedAt } }))
    if (!isOpened) {
      isOpened = true
      void $.ui.open({ id: PANE, title: 'Agenci' })
    }
    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const [list, known, now] = await Promise.all([$.agent.list(), read($, spawns), $.clock.now()])
    const show = (agentId: string) => () => void $.ui.view({ agentId })

    return (
      <Box flexDirection="column">
        {list.length === 0 && <Text dimColor>Brak subagentów w tej sesji.</Text>}
        {list.map((a, i) => {
          const spawn = known[a.description]
          return (
            <Button key={a.id} plain onPress={show(a.id)}>
              {GLYPH[a.status]} {a.description}{' '}
              <Text dimColor>
                {spawn?.model ?? a.type} {spawn ? age(now - spawn.startedAt) : ''}
              </Text>
            </Button>
          )
        })}
        <Button key="main" label="główny wątek" onPress={() => void $.ui.view({})} />
      </Box>
    )
  })
}
