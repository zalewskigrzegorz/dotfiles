import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

const PANE = 'shot-pane'
const DIR = '/Users/greg/Library/CloudStorage/GoogleDrive-maksim009@gmail.com/My Drive/Screenshots'
// Image bytes cap is 2 MiB decoded.
const MAX_B64 = Math.floor((2 * 1024 * 1024 * 4) / 3)
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
        // An unasked pane seats only from 144 columns; below that it waits undrawn.
        const opened = await $.ui.open({ id: PANE, title: 'Screen' })
        if (!opened.isPlaced) $.ui.toast('Screen gotowy: /screen otwiera podgląd')
      })().catch(() => {})
    }
    return next(e)
  })

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'screen', description: 'Show the latest CleanShot screenshot in a pane' })
    return next(e)
  })

  on('command.run', { command: 'screen' }, async $ => {
    if ((await read($, shots)).length === 0) {
      const newest = (await $.fs.list(DIR))
        .filter(f => f.kind === 'file' && /\.png$/i.test(f.name))
        .sort((a, b) => b.mtimeMs - a.mtimeMs)[0]
      if (!newest) return { text: 'Brak screenów w folderze CleanShota.' }
      await update($, shots, () => [`${DIR}/${newest.name}`])
    }
    await $.ui.open({ id: PANE, title: 'Screen' })
    return { text: 'Podgląd screena otwarty.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const list = await read($, shots)
    if (e.surface !== 'terminal') {
      const { Text } = $.ui.resolve(e)
      return <Text>{list.map(p => p.split('/').pop()).join('\n')}</Text>
    }
    const { Box, Image, Text } = $.ui.resolve(e)
    // Bytes, not the file name: a multiplexer (herdr, tmux) passes kitty bytes on, a name it may not.
    const sources = await Promise.all(
      list.map(async path => {
        const { base64 } = await $.fs.read(path, { as: 'bytes' }).catch(() => ({ base64: '' }))
        return base64 && base64.length <= MAX_B64 ? { png: base64 } : { file: path, format: 'png' as const }
      }),
    )
    const columns = Math.max(10, Math.min(120, (e.props.bodyColumns ?? 60) - 2))
    const rows = Math.max(6, Math.floor(((e.viewport?.rows ?? 30) - 4) / Math.max(1, list.length)) - 1)

    return (
      <Box flexDirection="column">
        {list.map((path, i) => (
          <Box key={path} flexDirection="column">
            <Text dimColor>{path.split('/').pop()}</Text>
            <Image key={path} source={sources[i] ?? { file: path, format: 'png' }} columns={columns} rows={rows} alt={path.split('/').pop() ?? ' '} />
          </Box>
        ))}
      </Box>
    )
  })
}
