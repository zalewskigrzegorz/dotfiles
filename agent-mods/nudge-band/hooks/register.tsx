import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Nudges } from '../types'

const nudges = atom({ plugin: 'nudge-band', key: 'nudges' } as const, { standup: 0, retro: 0 })
// Hidden for one set of counts: a new standup or retro brings the band back.
const hiddenAt = atom({ plugin: 'nudge-band', key: 'hiddenAt' } as const, null)
const countsOf = (n: Nudges) => `${n.standup}/${n.retro}`

const POLL_MS = 5 * 60_000

// Reads the counts out of the SessionStart hooks' own lines, so the logic stays in one place.
export const countOf = (text: string, pattern: RegExp) => Number(pattern.exec(text)?.[1] ?? 0)

async function poll($: EngineInterface) {
  const stdin = JSON.stringify({ session_id: await $.session.id(), cwd: await $.session.cwd() })
  const [standup, retro] = await Promise.all([
    $.process.run(['bash', '-c', '~/.claude/hooks/standup-pending.sh']).catch(() => null),
    $.process.run(['bash', '-c', '~/.claude/hooks/retro-pending.sh start'], { stdin }).catch(() => null),
  ])
  const now: Nudges = {
    standup: countOf(standup?.stdout ?? '', /(\d+) work task/),
    retro: countOf(retro?.stdout ?? '', /(\d+) session\(s\)/),
  }
  await update($, nudges, () => now)
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    void poll($)
    $.clock.every(POLL_MS, () => void poll($))

    return next(e)
  })

  // A turn that ran /g-standup or /retro-backlog clears its chip right away, not at the next tick.
  on('turn.complete', async ($, e, next) => {
    void poll($).catch(() => {})
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const now = await read($, nudges)
    if (e.props.hasSurvey || (now.standup === 0 && now.retro === 0) || (await read($, hiddenAt)) === countsOf(now)) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const run = (command: string) => () => void $.command.run({ command, args: '' })

    const below = await next(e)

    return (
      <Box flexDirection="column">
        <Box>
          {now.standup > 0 && (
            <Button key="standup" plain hotkey="s" label={`standup (${now.standup})`} onPress={run('g-standup')} />
          )}
          {now.retro > 0 && <Button key="retro" plain hotkey="b" label={`retro (${now.retro})`} onPress={run('retro-backlog')} />}
          <Text> </Text>
          <Button key="hide" plain hotkey="u" label="ukryj" onPress={() => update($, hiddenAt, () => countsOf(now))} />
        </Box>
        {below}
      </Box>
    )
  })
}
