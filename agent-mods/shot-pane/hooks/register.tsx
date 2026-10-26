import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

const PANE = 'shot-pane'
const DIR = '/Users/greg/Library/CloudStorage/GoogleDrive-maksim009@gmail.com/My Drive/Screenshots'
const shots = atom({ plugin: 'shot-pane', key: 'shots' } as const, [])

// Same trigger as hooks/screenshot-attach.sh, on the prompt's head only.
export const TRIGGER = /(^|[^\p{L}\p{N}])(screen(y|a|ie|em|ów|ik|shot\p{L}*)?|scr|ss|zrzut\p{L}*)([^\p{L}\p{N}]|$)/iu

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    if (TRIGGER.test(e.text.slice(0, 200))) {
      void (async () => {
        const now = await $.clock.now()
        const pngs = (await $.fs.list(DIR))
          .filter(f => f.kind === 'file' && /\.png$/i.test(f.name))
          .sort((a, b) => b.mtimeMs - a.mtimeMs)
        // Shots from the last 15 min (max 3), else the newest one, as the hook does.
        const recent = pngs.filter(f => now - f.mtimeMs < 15 * 60_000).slice(0, 3)
        const picked = (recent.length > 0 ? recent : pngs.slice(0, 1)).map(f => `${DIR}/${f.name}`)
        if (picked.length === 0) return
        await update($, shots, () => picked)
        await $.ui.open({ id: PANE, title: 'Screen' })
      })().catch(() => {})
    }
    return next(e)
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const list = await read($, shots)
    if (e.surface !== 'terminal') {
      const { Text } = $.ui.resolve(e)
      return <Text>{list.map(p => p.split('/').pop()).join('\n')}</Text>
    }
    const { Box, Image, Text } = $.ui.resolve(e)
    const columns = Math.max(10, Math.min(120, (e.props.bodyColumns ?? 60) - 2))
    const rows = Math.max(6, Math.floor(((e.viewport?.rows ?? 30) - 4) / Math.max(1, list.length)) - 1)

    return (
      <Box flexDirection="column">
        {list.map(path => (
          <Box key={path} flexDirection="column">
            <Text dimColor>{path.split('/').pop()}</Text>
            <Image key={path} source={{ file: path, format: 'png' }} columns={columns} rows={rows} alt={path.split('/').pop() ?? ' '} />
          </Box>
        ))}
      </Box>
    )
  })
}
