import { atom, read, update } from 'claude-code'
import type { AgentInfo, EngineInterface, Register } from 'claude-code'

import type { AgentState, Item, Link, Status } from '../types'

const items = atom({ plugin: 'sprawy', key: 'items' } as const, [])

const TOOL = 'mcp__sprawy__sprawa'
const STATUSES: readonly Status[] = ['queued', 'in_progress', 'done']
const MAX_ITEMS = 5 // plus the header: six rows at most
const POLL_MS = 20_000
const KEEP_MS = 7 * 24 * 3600_000 // a list untouched this long is dropped at session start
// Mocha Neon, as nudge-band (docs/mocha-neon-palette.md).
const GOLD = '#FFD700'
const PINK = '#FF79C6'
const AGENT_LABEL: Record<AgentState, string> = {
  working: 'agent pracuje',
  waiting: 'agent czeka na Ciebie',
  done: 'agent skończył',
  failed: 'agent padł',
}

const DESCRIPTION = `Keeps the list of separate things the user raised in this session (requests, complaints, ideas, feedback). The user sees it above the prompt, so nothing gets lost.
When a user message raises something separate (often numbered: "2 sprawa ...", "3 ...", or slipped in while you work on something else), call action=add once per thing before you act on it. Title in the user's language, at most 6 words.
New items join a queue. Finish the item you are on, then take queued items in queue order. Do not jump to a new item mid-work unless the user marks it urgent ("pilne", "najpierw", "teraz"): then add it with urgent=true and switch to it.
Call action=set with status=in_progress when you start an item, and status=done when it is finished.
When you hand an item to an agent that keeps running (a background Agent call, or a tuios agent started with workctl or tuios start-agent), call set with agent=<the agentId the Agent result gave, or the tuios window id>. The list then follows that agent and ticks the item done when the agent finishes.
Do not add your own sub-steps. action=list returns the items with their ids and queue order.`

// The list lives in $.store under the session id, so `claude --resume` finds it; $.state alone starts empty in a new process.
type Saved = { at: number; items: Item[] }
const key = async ($: EngineInterface) => `s:${await $.session.id()}`
async function commit($: EngineInterface, fn: (list: Item[]) => Item[]) {
  await update($, items, fn)
  await $.store.set(await key($), { at: await $.clock.now(), items: await read($, items) } satisfies Saved)
}

// Queue position (1-based) of each queued item, by order.
const queuePositions = (all: readonly Item[]) =>
  new Map(
    all
      .filter(i => i.status === 'queued')
      .sort((a, b) => a.order - b.order)
      .map((i, n) => [i.id, n + 1] as const),
  )

// In progress first, then the queue in order, then the newest done ones in the slots left.
export function visible(all: readonly Item[]): { shown: Item[]; hidden: number } {
  const pos = queuePositions(all)
  const active = [
    ...all.filter(i => i.status === 'in_progress'),
    ...all.filter(i => i.status === 'queued').sort((a, b) => pos.get(a.id)! - pos.get(b.id)!),
  ]
  const room = Math.max(MAX_ITEMS - active.length, 0)
  const done = room ? all.filter(i => i.status === 'done').slice(-room) : []
  const shown = [...active.slice(0, MAX_ITEMS), ...done]
  return { shown, hidden: all.length - shown.length }
}

const subState = (a: AgentInfo | undefined): AgentState => {
  if (!a || a.status === 'completed') return 'done' // the list drops an agent seconds after its end
  if (a.status === 'failed' || a.status === 'killed') return 'failed'
  return a.status === 'waiting' || a.status === 'idle' ? 'waiting' : 'working'
}

type TuiosAgent = { window_id: string; state: string; needs_you: boolean }
async function tuiosAgents($: EngineInterface): Promise<TuiosAgent[] | null> {
  const r = await $.process.run(['tuios', 'list-agents', '--all-sessions', '--json']).catch(() => null)
  if (!r || r.exitCode !== 0) return null
  try {
    return (JSON.parse(r.stdout) as { agents?: TuiosAgent[] }).agents ?? []
  } catch {
    return null
  }
}
const tuiosState = (a: TuiosAgent | undefined): AgentState => {
  if (!a || a.state === 'done') return 'done' // a closed window counts as finished
  return a.needs_you || a.state === 'needs_input' || a.state === 'idle' ? 'waiting' : 'working'
}

const withAgentState = (i: Item, state: AgentState): Item =>
  i.agent && i.agent.state !== state
    ? { ...i, agent: { ...i.agent, state }, status: state === 'done' ? 'done' : i.status }
    : i

// Only runs a lookup while some item follows a live agent.
async function poll($: EngineInterface) {
  const live = (await read($, items)).filter(i => i.agent && i.status !== 'done' && i.agent.state !== 'done')
  if (live.length === 0) return
  const subs = live.some(i => i.agent!.kind === 'sub') ? await $.agent.list() : []
  const windows = live.some(i => i.agent!.kind === 'tuios') ? await tuiosAgents($) : []
  await commit($, list =>
    list.map(i => {
      if (!live.some(l => l.id === i.id)) return i
      const link = i.agent!
      if (link.kind === 'sub') return withAgentState(i, subState(subs.find(a => a.id === link.id)))
      if (windows === null) return i // tuios unreachable: keep the last state
      return withAgentState(i, tuiosState(windows.find(a => a.window_id === link.id)))
    }),
  )
}

async function linkFor($: EngineInterface, id: string): Promise<Link | null> {
  const sub = (await $.agent.list()).find(a => a.id === id)
  if (sub) return { kind: 'sub', id, state: subState(sub) }
  const win = (await tuiosAgents($))?.find(a => a.window_id === id)
  return win ? { kind: 'tuios', id, state: tuiosState(win) } : null
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.tool.register({
      name: 'sprawa',
      description: DESCRIPTION,
      isDeferred: false,
      inputSchema: {
        type: 'object',
        properties: {
          action: { type: 'string', enum: ['add', 'set', 'list'] },
          title: { type: 'string', description: 'add: short title, user language, at most 6 words' },
          urgent: { type: 'boolean', description: 'add: the user marked it urgent, it goes to the front of the queue' },
          id: { type: 'number', description: 'set: the item id' },
          status: { type: 'string', enum: STATUSES },
          agent: { type: 'string', description: 'set: agentId of a background subagent, or a tuios window id' },
          note: { type: 'string', description: 'set: a few words shown after the title' },
        },
        required: ['action'],
      },
    })
    const now = await $.clock.now()
    const mine = await key($)
    for (const k of await $.store.keys()) {
      if (!k.startsWith('s:')) continue
      const saved = (await $.store.get(k)) as Saved | undefined
      if (!saved || now - saved.at > KEEP_MS) await $.store.delete(k)
      else if (k === mine && (await read($, items)).length === 0) await update($, items, () => saved.items)
    }
    $.clock.every(POLL_MS, () => void poll($).catch(() => {}))
    return next(e)
  })

  // A subagent's own turn ending is its end: tick the item at once, not at the next poll.
  // shortcut: a teammate ends many turns, so its item ticks after the first; split on teammateId if teammates get used.
  on('turn.complete', async ($, e, next) => {
    if (e.agentId !== undefined) {
      await commit($, list =>
        list.map(i => (i.agent?.kind === 'sub' && i.agent.id === e.agentId ? withAgentState(i, 'done') : i)),
      )
    }
    return next(e)
  })

  on('tool.call', { tool: TOOL }, async ($, e) => {
    const all = await read($, items)

    if (e.action === 'add') {
      if (typeof e.title !== 'string' || !e.title.trim()) return { deny: 'add needs a non-empty title.' }
      const orders = all.filter(i => i.status === 'queued').map(i => i.order)
      const order = e.urgent === true ? Math.min(0, ...orders) - 1 : all.length + 1
      const item: Item = { id: all.length + 1, title: e.title.trim(), status: 'queued', order }
      await commit($, list => [...list, item])
      const pos = queuePositions([...all, item]).get(item.id)
      return { result: `Added ${item.id}. ${item.title}, queue position ${pos}.` }
    }

    if (e.action === 'set') {
      const target = all.find(i => i.id === e.id)
      if (!target) return { deny: `No item with id ${String(e.id)}. Ids: ${all.map(i => i.id).join(', ') || 'none'}.` }
      let agent = target.agent
      if (typeof e.agent === 'string' && e.agent.trim()) {
        const link = await linkFor($, e.agent.trim())
        if (!link) return { deny: `No subagent or tuios window with id ${e.agent}.` }
        agent = link
      }
      const status = STATUSES.find(s => s === e.status) ?? (agent && !target.agent ? 'in_progress' : target.status)
      const note = typeof e.note === 'string' && e.note.trim() ? e.note.trim() : target.note
      await commit($, list => list.map(i => (i.id === target.id ? { ...i, status, note, agent } : i)))
      return { result: `${target.id}: ${status}${agent ? `, follows ${agent.kind} agent ${agent.id}` : ''}` }
    }

    if (e.action === 'list') {
      const pos = queuePositions(all)
      const rows = all.map(i => `${i.id}. ${i.title} [${i.status}${pos.has(i.id) ? ` #${pos.get(i.id)}` : ''}]`)
      return { result: rows.join('\n') || 'No items yet.' }
    }

    return { deny: 'action must be add, set or list.' }
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const all = await read($, items)
    if (e.props.hasSurvey || all.length === 0) return next(e)

    const { Box, Text } = $.ui.resolve(e)
    const { shown, hidden } = visible(all)
    const pos = queuePositions(all)
    const count = (s: Status) => all.filter(i => i.status === s).length
    const below = await next(e)

    return (
      <Box flexDirection="column">
        <Text dimColor>
          Sprawy  ◐ {count('in_progress')}  kolejka {count('queued')}  ✓ {count('done')}
          {hidden > 0 ? `  (+${hidden} ukryte)` : ''}
        </Text>
        {shown.map(i => {
          const mark = i.status === 'queued' ? `[${pos.get(i.id)}]` : i.status === 'done' ? '✓' : '◐'
          const extra = [i.note, i.agent && i.status !== 'done' ? AGENT_LABEL[i.agent.state] : undefined].filter(Boolean)
          const waiting = i.agent?.state === 'waiting' && i.status !== 'done'
          return (
            <Text
              wrap="truncate-end"
              dimColor={i.status === 'done'}
              color={waiting ? PINK : i.status === 'in_progress' ? GOLD : undefined}
            >
              {mark} {i.id}. {i.title}
              {extra.length ? ` (${extra.join(', ')})` : ''}
            </Text>
          )
        })}
        {below}
      </Box>
    )
  })
}
