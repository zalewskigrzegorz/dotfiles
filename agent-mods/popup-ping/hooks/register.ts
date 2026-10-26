import type { Register } from 'claude-code'

const EVERY_MS = 5 * 60_000
const MAX_PINGS = 3

export const register: Register = on => {
  // next(e) resolves only once the popup is answered, so the timer lives exactly as long as the wait.
  on('tool.call', { tool: 'AskUserQuestion' }, async ($, e, next) => {
    const repo = (await $.session.cwd()).split('/').pop()
    let pings = 0
    const timer = $.clock.every(EVERY_MS, () => {
      pings += 1
      if (pings > MAX_PINGS) return timer.cancel()
      void $.ui.notify(`Popup czeka od ${pings * 5} min`, { title: `Claude · ${repo}` })
      void $.audio.play({ asset: 'sounds/waiting.mp3' }).catch(() => {})
    })
    try {
      return await next(e)
    } finally {
      timer.cancel()
    }
  })
}
