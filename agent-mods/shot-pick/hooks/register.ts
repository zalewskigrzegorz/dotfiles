import type { Register } from 'claude-code'

// bin/shot-pick: fzf with a kitty image preview in a split under this pane; types the picked paths
// into the prompt itself (tuios send-text), so the command only starts it.
const PICK = '/Users/greg/bin/shot-pick'
// The picker's thumbnails and pr-band's e2e shots; per-user copies of private screenshots.
const CACHE = '/Users/greg/Library/Caches/shot-pick'

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'shot', description: 'Pick screenshots in a split below and type their paths into the prompt', argumentHint: '[folder]' }).catch(() => {})
    // Older than a day goes: thumbnails and e2e downloads are copies, the originals stay.
    void $.process.run(['find', CACHE, '-type', 'f', '-mtime', '+0', '-delete']).catch(() => null)
    return next(e)
  })

  // `/shot <folder>` picks from that folder (pr-band hands over e2e failure shots this way).
  on('command.run', { command: 'shot' }, async ($, e) => {
    const folder = e.args.trim()
    const ran = await $.process
      .run([PICK, '--here', ...(folder ? [folder] : [])], { timeoutMs: 20_000 })
      .catch((err: unknown) => ({ exitCode: 1, stdout: '', stderr: String(err) }))
    if (ran.exitCode !== 0) return { text: `shot-pick: ${ran.stderr.trim() || `exit ${ran.exitCode}`}` }
    return {}
  })
}
