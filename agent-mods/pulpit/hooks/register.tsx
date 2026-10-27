import { atom, read } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

// The other mods keep the data and the logic; pulpit only draws it, in one line and one pane.
const items = atom({ plugin: 'sprawy', key: 'items' } as const, [])
const pr = atom({ plugin: 'pr-band', key: 'pr' } as const, null)
const nudges = atom({ plugin: 'nudge-band', key: 'nudges' } as const, { standup: 0, retro: 0 })

const PANE = 'pulpit'
// Mocha Neon, the statusline's colours (docs/mocha-neon-palette.md).
const C = { green: '#50FA7B', red: '#FF6B9D', gold: '#FFD700', peach: '#FF8C42', cyan: '#8BE9FD', lavender: '#9580FF', pink: '#FF79C6' }

const AGENT_LABEL: Record<string, string> = {
  working: 'agent pracuje',
  waiting: 'agent czeka na Ciebie',
  done: 'agent skończył',
  failed: 'agent padł',
}
type Row = { status: string; note?: string; agent?: { state: string } }
const extraOf = (i: Row) => [i.note, i.agent && i.status !== 'done' ? AGENT_LABEL[i.agent.state] : undefined].filter(Boolean).join(', ')

const needsRebase =(merge: string) => merge === 'DIRTY' || merge === 'BEHIND'
// Check names come from CI config: only plain characters go into a prompt.
export const cleanChecks = (names: readonly string[]) => names.map(n => n.replace(/[^\p{L}\p{N} ._()/,:-]/gu, '').slice(0, 60)).join(', ')

async function toggle($: EngineInterface) {
  if ((await $.ui.panes()).some(p => p.id === PANE)) return void (await $.ui.close({ id: PANE }))
  const opened = await $.ui.open({ id: PANE, title: 'Pulpit' })
  if (!opened.isPlaced) $.ui.toast('Pulpit czeka na miejsce: poszerz okno Claude\'a')
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'pulpit', description: 'Open or close the pane with items, the PR, standup and retro' })
    return next(e)
  })

  on('command.run', { command: 'pulpit' }, async $ => {
    await toggle($)
    return { text: '' }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const all = await read($, items)
    const p = await read($, pr)
    const n = await read($, nudges)
    if (e.props.hasSurvey || (all.length === 0 && p === null && n.standup === 0 && n.retro === 0)) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const count = (s: string) => all.filter(i => i.status === s).length
    const waiting = all.some(i => i.agent?.state === 'waiting' && i.status !== 'done')
    const sep = <Text dimColor> │ </Text>
    const below = await next(e)

    return (
      <Box flexDirection="column">
        <Button key="pulpit" plain hotkey="o" label="pulpit" onPress={() => void toggle($)}>
          {all.length > 0 && (
            <Text color={waiting ? C.pink : count('in_progress') ? C.gold : undefined}>
              ☰ ◐{count('in_progress')} ⧗{count('queued')} ✓{count('done')}
            </Text>
          )}
          {all.length > 0 && p !== null && sep}
          {p !== null && (
            <Text color={C.green}>
              󰘬 #{p.number} ✓{p.pass}
              {p.fail > 0 ? <Text color={C.red}> ✗{p.fail}</Text> : null}
              {p.pending > 0 ? <Text color={C.gold}> ⏳{p.pending}</Text> : null}
              {needsRebase(p.merge) ? <Text color={C.peach}> {p.merge.toLowerCase()}</Text> : null}
            </Text>
          )}
          {(all.length > 0 || p !== null) && (n.standup > 0 || n.retro > 0) && sep}
          {n.standup > 0 && <Text color={C.gold}> {n.standup} </Text>}
          {n.retro > 0 && <Text color={C.lavender}>󰑓 {n.retro}</Text>}
          <Text dimColor>  ▸ szczegóły</Text>
        </Button>
        {below}
      </Box>
    )
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const all = await read($, items)
    const p = await read($, pr)
    const n = await read($, nudges)
    const ask = (text: string) => () => void $.prompt.submit({ text, asUser: true })
    const run = (command: string, args = '') => () => void $.command.run({ command, args })
    const queue = all.filter(i => i.status === 'queued').sort((a, b) => a.order - b.order)
    const ordered = [...all.filter(i => i.status === 'in_progress'), ...queue, ...all.filter(i => i.status === 'done')]

    return (
      <Box flexDirection="column">
        <Text bold>Sprawy</Text>
        {ordered.length === 0 && <Text dimColor>brak</Text>}
        {ordered.map(i => {
          const mark = i.status === 'queued' ? `[${queue.indexOf(i) + 1}]` : i.status === 'done' ? '✓' : '◐'
          const waiting = i.agent?.state === 'waiting' && i.status !== 'done'
          return (
            <Text wrap="truncate-end" dimColor={i.status === 'done'} color={waiting ? C.pink : i.status === 'in_progress' ? C.gold : undefined}>
              {mark} {i.id}. {i.title}
              {extraOf(i) ? ` (${extraOf(i)})` : ''}
            </Text>
          )
        })}

        <Text> </Text>
        <Text bold>PR</Text>
        {p === null ? (
          <Text dimColor>ten branch nie ma PR-a</Text>
        ) : (
          <Box flexDirection="column">
            <Text>
              <Text color={C.green}>
                󰘬 #{p.number} ✓{p.pass}
              </Text>
              {p.fail > 0 ? <Text color={C.red}> ✗{p.fail}</Text> : null}
              {p.pending > 0 ? <Text color={C.gold}> ⏳{p.pending}</Text> : null}
              <Text dimColor>
                {' '}
                {p.merge.toLowerCase()}
                {p.review ? ` · ${p.review.toLowerCase().replace('_', ' ')}` : ''}
              </Text>
            </Text>
            {p.failed.length > 0 && <Text color={C.red}>padło: {cleanChecks(p.failed)}</Text>}
            <Box>
              <Button key="pr-open" plain hotkey="w" label="otwórz w przeglądarce" onPress={() => void $.process.run(['open', p.url])} />
              <Button key="pr-peek" plain hotkey="p" label="podgląd PR" onPress={run('pr', String(p.number))} />
              {p.fail > 0 && (
                <Button
                  key="log"
                  plain
                  hotkey="f"
                  label="log-failed"
                  onPress={ask(`Przeczytaj gh run view --log-failed dla padniętych checków PR #${p.number} (${cleanChecks(p.failed)}) i powiedz, co padło.`)}
                />
              )}
              {needsRebase(p.merge) && (
                <Button key="rebase" plain hotkey="r" label="rebase" onPress={ask(`Branch PR #${p.number} jest ${p.merge}: zrebase'uj go na bazę PR-a i uruchom lokalnie to, co CI.`)} />
              )}
            </Box>
          </Box>
        )}

        <Text> </Text>
        <Text bold>Do zrobienia</Text>
        {n.standup === 0 && n.retro === 0 && <Text dimColor>nic nie czeka</Text>}
        <Box>
          {n.standup > 0 && <Button key="standup" plain hotkey="s" label={` standup (${n.standup})`} onPress={run('g-standup')} />}
          {n.retro > 0 && <Button key="retro" plain hotkey="b" label={`󰑓 retro (${n.retro})`} onPress={run('retro-backlog')} />}
        </Box>
      </Box>
    )
  })
}
