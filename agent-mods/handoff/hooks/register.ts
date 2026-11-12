import type { Register } from 'claude-code'

// Past this, every message re-reads a long, costly prefix and answers start to slip.
const LIMIT = 250_000

// The summary replaces the chat, so it must carry what a new session would otherwise ask for.
const HANDOFF = `Write this summary as a hand-over to a fresh session that has to continue the work without asking anything:
- the goal, and every decision the user made, with the reason
- what is done: files changed (full paths), commits (sha), PRs, commands that worked
- what is open, and the very next step
- files, skills, links and tools this work relies on
- traps hit and how they were solved, so they are not hit again
- constraints and preferences the user stated
Keep exact paths, ids, shas, numbers and commands. Leave out exploration that led nowhere.`

export const register: Register = on => {
  let nudged = false
  let pending = false

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'handoff', description: 'Compact the chat into a detailed hand-over and go on in a fresh context' }).catch(() => {})
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    const done = await next(e)
    if (e.agentId) return done // a subagent's turn: its context is not the chat's
    if (pending) {
      pending = false
      const r = await $.session.compact({ instructions: HANDOFF }).catch((err: unknown) => ({ skip: String(err) }))
      $.ui.toast('skip' in r ? `handoff: nie poszło (${r.skip})` : 'handoff: rozmowa zastąpiona przekazaniem, kontekst od nowa')
      return done
    }
    const tokens = (await $.session.usage()).context.tokens ?? 0
    if (tokens < LIMIT) nudged = false // a compaction brought it back down: the next crossing nudges again
    else if (!nudged) {
      nudged = true
      $.ui.toast(`Kontekst ${Math.round(tokens / 1000)}k tokenów: /handoff przenosi pracę do świeżego kontekstu`)
    }
    return done
  })

  // The engine compacts only between turns, so the command asks for one short turn
  // (a status line Greg sees before the reset) and turn.complete compacts after it.
  on('command.run', { command: 'handoff' }, async $ => {
    pending = true
    // A timer of its own: a submit from inside this hook would wait on the turn it holds.
    $.clock.after(0, () => void $.prompt.submit({ text: 'Handoff: w 1–3 liniach napisz, na czym stoimy i jaki jest następny krok. Nic więcej nie rób.' }).catch(() => (pending = false)))
    return { text: 'handoff: krótki stan pracy, potem kompakcja do przekazania' }
  })
}
