import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { BgTask } from '../types'

// The other mods keep the data and the logic; pulpit only draws it, in one line and one pane.
const items = atom({ plugin: 'sprawy', key: 'items' } as const, [])
const pr = atom({ plugin: 'pr-band', key: 'pr' } as const, null)
const nudges = atom({ plugin: 'nudge-band', key: 'nudges' } as const, { standup: 0, retro: 0 })

const bg = atom({ plugin: 'pulpit', key: 'bg' } as const, [])

const PANE = 'pulpit'
const POLL_MS = 15_000
const KEEP_DONE = 5

// The last non-empty line of a log tail, every escape sequence and control character stripped (a log may set titles or links).
export const lastLine = (tail: string) =>
  tail
    .replace(/\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)|[PX^_][^\x1b]*\x1b\\|.)/g, '')
    .replace(/[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/g, '')
    .split(/\r?\n|\r/)
    .map(l => l.trim())
    .filter(Boolean)
    .at(-1) ?? ''
// A watcher prints the same status with a new clock time each minute: compare without the times.
const sameLine = (a: string, b: string) => a.replace(/\b\d{1,2}:\d{2}(:\d{2})?\b/g, '') === b.replace(/\b\d{1,2}:\d{2}(:\d{2})?\b/g, '')
export const failedLine = (line: string) => /exit(ed)?( with)? code [1-9]|\btimeout\b|\bfailed\b|\berror\b/i.test(line)

const ago = (ms: number) => (ms < 60_000 ? `${Math.round(ms / 1000)} s` : `${Math.round(ms / 60_000)} min`)

// shortcut: the payload carries no output path, so it is globbed from the layout Claude Code 2.1 uses; fix if it moves.
async function outputFile($: EngineInterface, id: string): Promise<string> {
  const sid = await $.session.id()
  const r = await $.process.run(['sh', '-c', `ls /private/tmp/claude-$(id -u)/*/${sid}/tasks/${id}.output`]).catch(() => null)
  return r?.stdout.split('\n')[0]?.trim() ?? ''
}

async function poll($: EngineInterface) {
  const live = (await read($, bg)).filter(t => t.state === 'running')
  if (live.length === 0) return
  const now = await $.clock.now()
  for (const t of live) {
    const tail = await $.process.run(['tail', '-n', '40', t.file]).catch(() => null)
    const last = lastLine(tail?.stdout ?? '') || t.last
    // The background shell holds the file open while it runs.
    const open = await $.process.run(['lsof', '-t', '--', t.file]).catch(() => null)
    const running = !!open?.stdout.trim()
    const state = running ? 'running' : failedLine(last) ? 'failed' : 'done'
    await update($, bg, list =>
      list.map(x =>
        x.id === t.id ? { ...x, last, repeats: sameLine(last, x.last) ? x.repeats + 1 : 0, state, endedAt: running ? undefined : now } : x,
      ),
    )
    if (!running) $.ui.toast(`${state === 'failed' ? '✗' : '✓'} w tle: ${t.desc}`, { timeoutMs: 10_000 })
  }
  // Finished ones stay for a look; only the newest few.
  await update($, bg, list => {
    const done = list.filter(x => x.state !== 'running')
    return list.filter(x => x.state === 'running' || done.indexOf(x) >= done.length - KEEP_DONE)
  })
}

async function openLog($: EngineInterface, t: BgTask) {
  const session = await $.env.get('TUIOS_SESSION')
  if (!session) return void $.ui.toast(`log: ${t.file}`)
  // Workspace 2 is the session's back room; the main screen stays claude + nu.
  await $.process.run([
    'tuios', 'new-window', '-s', session, `bg: ${t.desc.slice(0, 30)}`, '--workspace', '2', '--', 'less', '-R', '-~',
    '-PsF=sledz dalej   /=szukaj   q=zamknij', '+F', t.file,
  ])
  await $.process.run(['tuios', 'select-workspace', '-s', session, '2'])
}
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
    await $.command.register({ name: 'pulpit', description: 'Open or close the pane with items, the PR, standup, retro and background tasks' })
    $.clock.every(POLL_MS, () => void poll($).catch(() => {}))
    return next(e)
  })

  // A command the model sent to the background joins the "W tle" list.
  on('tool.call', { tool: 'Bash' }, async ($, e, next) => {
    const r = await next(e)
    // The command already ran: a failure here must never run it again, so no .catch with next.
    try {
      const id = 'result' in r ? r.result?.backgroundTaskId : undefined
      const file = id ? await outputFile($, id) : ''
      if (id && file) {
        const task: BgTask = { id, desc: e.description ?? e.command.slice(0, 60), file, last: '', repeats: 0, state: 'running', startedAt: await $.clock.now() }
        await update($, bg, list => [...list, task])
      }
    } catch {
      // the list misses one task; the command's own result goes on untouched
    }
    return r
  })

  on('command.run', { command: 'pulpit' }, async $ => {
    await toggle($)
    return { text: '' }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const all = await read($, items)
    const p = await read($, pr)
    const n = await read($, nudges)
    const tasks = await read($, bg)
    if (e.props.hasSurvey || (all.length === 0 && p === null && n.standup === 0 && n.retro === 0 && tasks.length === 0)) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const count = (s: string) => all.filter(i => i.status === s).length
    const running = tasks.filter(t => t.state === 'running').length
    const failed = tasks.filter(t => t.state === 'failed').length
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
          {(running > 0 || failed > 0) && (all.length > 0 || p !== null || n.standup > 0 || n.retro > 0) && sep}
          {running > 0 && <Text color={C.cyan}>⚙ {running}</Text>}
          {failed > 0 && <Text color={C.red}> ✗{failed}</Text>}
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
    const tasks = await read($, bg)
    const now = await $.clock.now()
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

        <Text> </Text>
        <Text bold>W tle</Text>
        {tasks.length === 0 && <Text dimColor>nic nie działa w tle</Text>}
        {tasks.map(t => (
          <Box key={`bg-${t.id}`} flexDirection="column">
            <Box>
              <Text color={t.state === 'failed' ? C.red : t.state === 'done' ? C.green : C.cyan}>
                {t.state === 'running' ? '⚙' : t.state === 'failed' ? '✗' : '✓'} {t.desc}
              </Text>
              <Text dimColor> · {ago((t.endedAt ?? now) - t.startedAt)} </Text>
              <Button key={`log-${t.id}`} plain label="log" onPress={() => void openLog($, t)} />
            </Box>
            <Text wrap="truncate-end" dimColor>
              {'  '}
              {t.last || 'jeszcze nic nie wypisało'}
              {t.repeats > 0 ? `  (bez zmian ×${t.repeats + 1})` : ''}
            </Text>
          </Box>
        ))}
      </Box>
    )
  })
}
