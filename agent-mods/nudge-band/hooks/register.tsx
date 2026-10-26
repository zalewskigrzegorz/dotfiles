import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Nudges } from '../types'

const nudges = atom({ plugin: 'nudge-band', key: 'nudges' } as const, { standup: 0, retro: 0 })
const isHidden = atom({ plugin: 'nudge-band', key: 'isHidden' } as const, false)

const POLL_MS = 5 * 60_000

// Reads the counts out of the SessionStart hooks' own lines, so the logic stays in one place.
export const countOf = (text: string, pattern: RegExp) => Number(pattern.exec(text)?.[1] ?? 0)

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const stdin = JSON.stringify({ session_id: await $.session.id(), cwd: await $.session.cwd() })
    const poll = async () => {
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
    void poll()
    $.clock.every(POLL_MS, () => void poll())

    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const now = await read($, nudges)
    if (e.props.hasSurvey || (now.standup === 0 && now.retro === 0) || (await read($, isHidden))) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    const run = (text: string) => () => void $.prompt.submit({ text, asUser: true })

    const below = await next(e)

    return (
      <Box flexDirection="column">
        <Box>
          {now.standup > 0 && (
            <Button key="standup" label={`standup (${now.standup})`} onPress={run('/g-standup')} />
          )}
          {now.retro > 0 && <Button key="retro" label={`retro (${now.retro})`} onPress={run('/retro-backlog')} />}
          <Text> </Text>
          <Button key="hide" label="ukryj" onPress={() => update($, isHidden, () => true)} />
        </Box>
        {below}
      </Box>
    )
  })
}
