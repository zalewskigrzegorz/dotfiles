import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Pr } from '../types'
import { PR_LINK, namesFrom, needsRebase, railPr, repoOf, summarize, summarizePeek } from './pr'

const pr = atom({ plugin: 'pr-band', key: 'pr' } as const, null)
const hiddenFor = atom({ plugin: 'pr-band', key: 'hiddenFor' } as const, null)
const peek = atom({ plugin: 'pr-band', key: 'peek' } as const, null)

const FIELDS = 'number,url,state,isDraft,mergeStateStatus,reviewDecision,statusCheckRollup'
const PEEK_FIELDS = `${FIELDS},title,author,isDraft,additions,deletions,changedFiles`
const POLL_MS = 90_000
const PEEK = 'pr-peek'
const PEEK_CLOSE_MS = 5 * 60_000
// Shared with shot-pane: its daily cleanup sweeps this folder too.
const CACHE = '/Users/greg/Library/Caches/shot-pane'
const REVIEW_COMMANDS = new Set(['g-pr-review', 'code-review'])
// Mocha Neon, the statusline's colours (docs/mocha-neon-palette.md).
const C = { green: '#50FA7B', red: '#FF6B9D', gold: '#FFD700', peach: '#FF8C42', cyan: '#8BE9FD', lavender: '#9580FF', muted: '#A6ADC8' }

let names: Record<string, string> = {}
let peekTimer: { cancel: () => void } | undefined
// Last `$pr` rail value sent; undefined until the first poll that knows.
let railSent: string | undefined

// The tuios rail tokens `$num` / `$pr` ([appearance.sidebar.agent_row]); "pr=" removes the key.
// No pane or no tuios daemon: nothing happens. Repeated values change nothing in tuios.
async function railMeta($: EngineInterface, pairs: string[]) {
  const pane = await $.env.get('TUIOS_PANE_ID')
  if (!pane || pairs.length === 0) return
  await $.process.run(['tuios', 'set-agent-meta', '-w', pane, '--source', 'greg', ...pairs], { timeoutMs: 5_000 })
}

// 1-based position of this pane's session in `tuios ls` (creation order, the rail's), what "sesja N" means.
async function sessionNum($: EngineInterface): Promise<string | undefined> {
  const name = await $.env.get('TUIOS_SESSION')
  if (!name) return undefined
  const ran = await $.process.run(['tuios', 'ls', '--json'], { timeoutMs: 5_000 })
  if (ran.exitCode !== 0) return undefined
  const i = (JSON.parse(ran.stdout) as { name?: string }[]).findIndex(s => s.name === name)
  return i < 0 ? undefined : String(i + 1)
}

// shortcut: no tuios event for a session added or dragged, so num is re-read on session start and each prompt.
async function sendRail($: EngineInterface) {
  const num = await sessionNum($).catch(() => undefined)
  await railMeta($, [...(num ? [`num=${num}`] : []), ...(railSent === undefined ? [] : [`pr=${railSent}`])])
}

// Failure screenshots sit in blob-report-* → report.zip → resources/*.png.
async function e2eShots($: EngineInterface, repo: string, run: string): Promise<string | null> {
  const dir = `${CACHE}/e2e-${run}`
  await $.process.run(['mkdir', '-p', '-m', '700', dir])
  const got = await $.process.run(['gh', 'run', 'download', run, '-R', repo, '-p', 'blob-report-*', '-D', dir], { timeoutMs: 120_000 })
  const zips = await $.process.run(['find', dir, '-name', '*.zip'])
  for (const zip of zips.stdout.split('\n').filter(Boolean)) {
    await $.process.run(['unzip', '-o', '-j', '-q', zip, 'resources/*.png', '-d', dir])
  }
  const pngs = await $.process.run(['find', dir, '-maxdepth', '1', '-name', '*.png'])
  return got.exitCode === 0 && pngs.stdout.trim() ? dir : null
}

async function showE2e($: EngineInterface, now: Pr) {
  const repo = repoOf(now.url)
  if (!repo || !now.e2eRun) return
  $.ui.toast(`Ściągam screeny e2e z runu ${now.e2eRun}…`)
  const dir = await e2eShots($, repo, now.e2eRun).catch(() => null)
  if (dir) await $.command.run({ command: 'screen', args: dir })
  else $.ui.toast('W artefaktach e2e nie ma screenów')
}

async function openPeek($: EngineInterface, ref: string) {
  const ran = await $.process.run(['gh', 'pr', 'view', ref, '--json', PEEK_FIELDS], { timeoutMs: 20_000 }).catch(() => null)
  if (ran?.exitCode !== 0) return false
  await update($, peek, () => summarizePeek(JSON.parse(ran.stdout), names))
  const opened = await $.ui.open({ id: PEEK, title: 'PR' })
  if (!opened.isPlaced) $.ui.toast('Podgląd PR-a gotowy: /pr go otwiera')
  peekTimer?.cancel()
  peekTimer = $.clock.after(PEEK_CLOSE_MS, () => void $.ui.close({ id: PEEK }).catch(() => {}))
  return true
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'pr', description: 'Show a PR (number or URL) in a pane: checks, merge state, review', argumentHint: '<n|url>' })
    // Full names, never logins: the work-people matrix, found by shape so no org name sits in this public repo.
    void $.process
      .run(['find', '/Users/greg/Code/personal/bazgroly', '-maxdepth', '2', '-name', 'people.md'])
      .then(found => found.stdout.split('\n').find(Boolean))
      .then(path => (path ? $.fs.read(path) : ''))
      .then(text => (names = namesFrom(text)))
      .catch(() => {})

    const poll = async () => {
      const ran = await $.process.run(['gh', 'pr', 'view', '--json', FIELDS], { timeoutMs: 20_000 }).catch(() => null)
      // shortcut: any gh failure reads as "no PR" (no auth, no network), upgrade if it hides real errors.
      const view = ran?.exitCode === 0 ? JSON.parse(ran.stdout) : null
      const now: Pr | null = view ? summarize(view) : null
      // The rail keeps its last value on a gh hiccup and drops it only when gh says there is no PR.
      const rail = view ? railPr(view) : ran?.stderr.includes('no pull requests found') ? '' : undefined
      if (rail !== undefined && rail !== railSent) {
        railSent = rail
        void railMeta($, [`pr=${rail}`]).catch(() => {})
      }
      const before = await read($, pr)
      await update($, pr, () => now)
      if (before && now && before.number === now.number && before.pending > 0 && now.pending === 0) {
        const red = now.fail > 0
        $.ui.toast(red ? `PR #${now.number}: ${now.fail} checków padło` : `PR #${now.number}: checki zielone`, { timeoutMs: 10_000 })
        void $.audio.play({ asset: red ? 'sounds/error.mp3' : 'sounds/done.mp3' }).catch(() => {})
      }
    }
    void poll()
    $.clock.every(POLL_MS, () => void poll())
    void sendRail($).catch(() => {})

    return next(e)
  })

  // A PR link in the prompt, or a review command, opens the peek; a prompt with neither closes it.
  on('prompt.submit', async ($, e, next) => {
    // Also re-sends pr, so a restarted tuios daemon gets both back.
    void sendRail($).catch(() => {})
    const link = PR_LINK.exec(e.text)?.[0]
    const review = e.command && REVIEW_COMMANDS.has(e.command.name) ? (PR_LINK.exec(e.command.args)?.[0] ?? /\d+/.exec(e.command.args)?.[0]) : undefined
    const ref = link ?? review
    if (ref) void openPeek($, ref).catch(() => {})
    else if (!e.command && !e.isMeta) void $.ui.close({ id: PEEK }).catch(() => {})
    return next(e)
  })

  on('command.run', { command: 'pr' }, async ($, e) => {
    const ref = e.args.trim() || String((await read($, pr))?.number ?? '')
    if (!ref) return { text: 'Podaj numer albo link PR-a.' }
    return { text: (await openPeek($, ref)) ? `Podgląd PR-a ${ref} otwarty.` : `gh nie znalazł PR-a ${ref}.` }
  })

  on('ui.render', { component: 'Pane', requestId: PEEK }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const p = await read($, peek)
    if (p === null) return <Text dimColor>Brak PR-a.</Text>

    return (
      <Box flexDirection="column">
        <Text bold>
          #{p.number} {p.title}
        </Text>
        <Text dimColor>
          {p.author}
          {p.isDraft ? ' · draft' : ''} · +{p.additions} −{p.deletions} · {p.files} plików
        </Text>
        <Box>
          <Text color={C.green}>✓{p.pass} </Text>
          {p.fail > 0 && <Text color={C.red}>✗{p.fail} </Text>}
          {p.pending > 0 && <Text color={C.gold}>⏳{p.pending} </Text>}
          <Text dimColor>
            {p.merge.toLowerCase()}
            {p.review && ` · ${p.review.toLowerCase().replace('_', ' ')}`}
          </Text>
        </Box>
        {p.failed.length > 0 && <Text color={C.red}>{p.failed.join(', ')}</Text>}
        <Box>
          <Button key="open" plain hotkey="o" label="otwórz" onPress={() => void $.process.run(['open', p.url])} />
          {p.e2eRun && <Button key="e2e" plain hotkey="e" label="screeny e2e" onPress={() => void showE2e($, p)} />}
        </Box>
      </Box>
    )
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const now = await read($, pr)
    if (e.props.hasSurvey || now === null || (await read($, hiddenFor)) === now.number) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const ask = (text: string) => () => void $.prompt.submit({ text, asUser: true })

    const below = await next(e)

    return (
      <Box flexDirection="column">
        <Box>
          <Text color={C.green} bold>
            󰘬 #{now.number}{' '}
          </Text>
          <Text color={C.green}>✓{now.pass} </Text>
          {now.fail > 0 && <Text color={C.red}>✗{now.fail} </Text>}
          {now.pending > 0 && <Text color={C.gold}>⏳{now.pending} </Text>}
          <Text color={needsRebase(now) || now.merge === 'BLOCKED' ? C.peach : C.muted}>
            {now.merge.toLowerCase()}
            {now.review && ` · ${now.review.toLowerCase().replace('_', ' ')}`}{' '}
          </Text>
          {now.fail > 0 && (
            <Button
              key="log"
              plain
              hotkey="f"
              label="log-failed"
              onPress={ask(`Przeczytaj gh run view --log-failed dla padniętych checków PR #${now.number} (${now.failed.join(', ')}) i powiedz, co padło.`)}
            >
              <Text color={C.red}>log-failed</Text>
            </Button>
          )}
          {now.e2eRun && (
            <Button key="e2e" plain hotkey="e" label="screeny e2e" onPress={() => void showE2e($, now)}>
              <Text color={C.red}>screeny e2e</Text>
            </Button>
          )}
          {needsRebase(now) && (
            <Button key="rebase" plain hotkey="r" label="rebase" onPress={ask(`Branch PR #${now.number} jest ${now.merge}: zrebase'uj go na bazę PR-a i uruchom lokalnie to, co CI.`)}>
              <Text color={C.peach}>rebase</Text>
            </Button>
          )}
          <Button key="open" plain hotkey="o" label="otwórz" onPress={() => void $.process.run(['open', now.url])}>
            <Text color={C.cyan}>otwórz</Text>
          </Button>
          <Button key="hide" plain hotkey="x" label="ukryj" dimColor onPress={() => update($, hiddenFor, () => now.number)} />
        </Box>
        {below}
      </Box>
    )
  })
}
