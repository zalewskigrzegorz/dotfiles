import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

const PANE = 'shot-pane'
const DIR = '/Users/greg/Library/CloudStorage/GoogleDrive-maksim009@gmail.com/My Drive/Screenshots'
// Image bytes cap is 2 MiB decoded.
const MAX_B64 = Math.floor((2 * 1024 * 1024 * 4) / 3)
const shots = atom({ plugin: 'shot-pane', key: 'shots' } as const, [])
// Per-user and 0700: the thumbnails are copies of private screenshots.
const THUMBS = '/Users/greg/Library/Caches/shot-pane'

// herdr drops kitty images past ~6 M decoded pixels without a word, a 3024 px Retina shot included.
async function thumbOf($: EngineInterface, path: string): Promise<string> {
  const out = `${THUMBS}/${path.split('/').pop()}`
  const isMade = await $.fs.stat(out).then(s => s.kind === 'file' && !s.isLink, () => false)
  if (isMade) return out
  await $.process.run(['mkdir', '-p', '-m', '700', THUMBS]).catch(() => null)
  const ran = await $.process.run(['sips', '-Z', '1600', path, '--out', out]).catch(() => null)
  return ran?.exitCode === 0 ? out : path
}

// Same trigger as hooks/screenshot-attach.sh, on the prompt's head only.
export const TRIGGER = /(^|[^\p{L}\p{N}])(screen(y|a|ie|em|ów|ik|shot\p{L}*)?|scr|ss|zrzut\p{L}*)([^\p{L}\p{N}]|$)/iu

// PNG width and height sit big-endian at bytes 16..24 (IHDR); 32 base64 chars cover them.
export function pngSize(base64: string): { width: number; height: number } | undefined {
  const head = atob(base64.slice(0, 32))
  if (head.length < 24 || head.slice(12, 16) !== 'IHDR') return undefined
  const u32 = (at: number) => ((head.charCodeAt(at) << 24) | (head.charCodeAt(at + 1) << 16) | (head.charCodeAt(at + 2) << 8) | head.charCodeAt(at + 3)) >>> 0
  return { width: u32(16), height: u32(20) }
}

// A terminal cell is about twice as tall as wide, so rows = columns * h/w / 2.
export function fit(size: { width: number; height: number }, maxColumns: number, maxRows: number) {
  const ratio = size.height / size.width / 2
  let columns = maxColumns
  let rows = Math.max(1, Math.round(columns * ratio))
  if (rows > maxRows) {
    rows = maxRows
    columns = Math.max(1, Math.round(rows / ratio))
  }
  return { columns, rows }
}

// No mouse to press the pane's ×: the preview closes itself after a while.
const CLOSE_AFTER_MS = 3 * 60_000
let closeTimer: { cancel: () => void } | undefined
function closeLater($: EngineInterface) {
  closeTimer?.cancel()
  closeTimer = $.clock.after(CLOSE_AFTER_MS, () => void $.ui.close({ id: PANE }).catch(() => {}))
}

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
        closeLater($)
      })().catch(() => {})
    } else if (!e.command && !e.isMeta) {
      // The talk moved on: the preview goes with the next prompt that names no screenshot.
      void $.ui.close({ id: PANE }).catch(() => {})
    }
    return next(e)
  })

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'screen', description: 'Show the latest CleanShot screenshot, or a folder of PNGs, in a pane', argumentHint: '[folder]' })
    // Thumbnails older than a day go: they are only previews of the Drive originals.
    void $.process.run(['find', THUMBS, '-type', 'f', '-name', '*.png', '-mtime', '+0', '-delete']).catch(() => null)
    return next(e)
  })

  on('command.run', { command: 'screen' }, async ($, e) => {
    // `/screen <folder>` shows that folder's PNGs (pr-band hands over e2e failure shots this way).
    const folder = e.args.trim()
    if (folder) {
      const pngs = (await $.fs.list(folder).catch(() => []))
        .filter(f => f.kind === 'file' && /\.png$/i.test(f.name))
        .sort((a, b) => b.mtimeMs - a.mtimeMs)
        .slice(0, 4)
      if (pngs.length === 0) return { text: `Brak PNG w ${folder}.` }
      await update($, shots, () => pngs.map(f => `${folder}/${f.name}`))
    } else if ((await read($, shots)).length === 0) {
      const newest = (await $.fs.list(DIR))
        .filter(f => f.kind === 'file' && /\.png$/i.test(f.name))
        .sort((a, b) => b.mtimeMs - a.mtimeMs)[0]
      if (!newest) return { text: 'Brak screenów w folderze CleanShota.' }
      await update($, shots, () => [`${DIR}/${newest.name}`])
    }
    await $.ui.open({ id: PANE, title: 'Screen' })
    closeLater($)
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
        const { base64 } = await $.fs.read(await thumbOf($, path), { as: 'bytes' }).catch(() => ({ base64: '' }))
        return base64 && base64.length <= MAX_B64 ? { png: base64 } : { file: path, format: 'png' as const }
      }),
    )
    const maxColumns = Math.max(10, Math.min(120, (e.props.bodyColumns ?? 60) - 2))
    const maxRows = Math.max(6, Math.floor(((e.viewport?.rows ?? 30) - 4) / Math.max(1, list.length)) - 1)
    const boxes = sources.map(src => {
      const size = 'png' in src && src.png ? pngSize(src.png) : undefined
      return size ? fit(size, maxColumns, maxRows) : { columns: maxColumns, rows: maxRows }
    })

    return (
      <Box flexDirection="column">
        {list.map((path, i) => (
          <Box key={path} flexDirection="column">
            <Text dimColor>{path.split('/').pop()}</Text>
            <Image key={path} source={sources[i] ?? { file: path, format: 'png' }} columns={boxes[i]?.columns ?? maxColumns} rows={boxes[i]?.rows ?? maxRows} alt={path.split('/').pop() ?? ' '} />
          </Box>
        ))}
      </Box>
    )
  })
}
