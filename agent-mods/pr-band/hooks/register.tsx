import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Pr } from '../types'
import { needsRebase, summarize } from './pr'

const pr = atom({ plugin: 'pr-band', key: 'pr' } as const, null)
const hiddenFor = atom({ plugin: 'pr-band', key: 'hiddenFor' } as const, null)

const FIELDS = 'number,url,mergeStateStatus,reviewDecision,statusCheckRollup'
const POLL_MS = 90_000

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const poll = async () => {
      const ran = await $.process.run(['gh', 'pr', 'view', '--json', FIELDS], { timeoutMs: 20_000 }).catch(() => null)
      // shortcut: any gh failure reads as "no PR" (no auth, no network), upgrade if it hides real errors.
      const now: Pr | null = ran?.exitCode === 0 ? summarize(JSON.parse(ran.stdout)) : null
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

    return next(e)
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
          <Text>PR #{now.number} </Text>
          <Text color="green">✓{now.pass} </Text>
          {now.fail > 0 && <Text color="red">✗{now.fail} </Text>}
          {now.pending > 0 && <Text color="yellow">⏳{now.pending} </Text>}
          <Text dimColor>
            {now.merge.toLowerCase()}
            {now.review && ` · ${now.review.toLowerCase().replace('_', ' ')}`}{' '}
          </Text>
          {now.fail > 0 && (
            <Button
              key="log"
              label="log-failed"
              onPress={ask(`Przeczytaj gh run view --log-failed dla padniętych checków PR #${now.number} (${now.failed.join(', ')}) i powiedz, co padło.`)}
            />
          )}
          {needsRebase(now) && (
            <Button key="rebase" label="rebase" onPress={ask(`Branch PR #${now.number} jest ${now.merge}: zrebase'uj go na bazę PR-a i uruchom lokalnie to, co CI.`)} />
          )}
          <Button key="open" label="otwórz" onPress={() => void $.process.run(['open', now.url])} />
          <Button key="hide" label="ukryj" onPress={() => update($, hiddenFor, () => now.number)} />
        </Box>
        {below}
      </Box>
    )
  })
}
