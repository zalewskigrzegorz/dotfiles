import type { Register } from 'claude-code'

// Browser MCPs whose screenshots the model reads to find its way on a page.
const BROWSER = /^mcp__(browsentic|vimma)__/
// Image tokens ≈ width × height / 750, so half the edge is a quarter of the tokens.
// Below 800 px on the long edge page text stops being legible, so that is the floor.
const MIN_EDGE = 800

// stdin: the image's base64; stdout: the shrunk image's base64; exit 3 when it is already small.
const SHRINK = `set -e
t=$(mktemp -d); trap 'rm -r "$t"' EXIT
base64 -D > "$t/i"
w=$(sips -g pixelWidth "$t/i" | awk '/pixelWidth/{print $2}')
h=$(sips -g pixelHeight "$t/i" | awk '/pixelHeight/{print $2}')
l=$(( w > h ? w : h )); n=$(( l / 2 )); [ "$n" -lt ${MIN_EDGE} ] && n=${MIN_EDGE}
[ "$l" -le "$n" ] && exit 3
sips -Z "$n" "$t/i" --out "$t/o" >/dev/null
base64 -i "$t/o"`

type Block = { type: string; data?: unknown; [k: string]: unknown }

export const register: Register = on => {
  on('tool.call', { tool: BROWSER }, async ($, e, next) => {
    const res = await next(e)
    const content = (res.result as { content?: Block[] } | undefined)?.content
    if (res.deny !== undefined || !Array.isArray(content) || !content.some(b => b.type === 'image')) return res

    let saved = 0
    const shrunk = await Promise.all(
      content.map(async b => {
        if (b.type !== 'image' || typeof b.data !== 'string') return b
        const ran = await $.process.run(['sh', '-c', SHRINK], { stdin: b.data, timeoutMs: 15_000 }).catch(() => null)
        const data = ran?.exitCode === 0 && !ran.isStdoutTruncated ? ran.stdout.trim() : ''
        if (!data) return b // lab without sips, an odd format, already small: the original goes through
        saved += b.data.length - data.length
        return { ...b, data }
      }),
    )
    if (!saved) return res
    $.ui.log(`${e.tool}: screenshot shrunk, ${Math.round(saved / 1024)} KiB of base64 less`, { to: 'debug' })
    // A hook's own result, without core's `ref`/`text`, so core maps the new blocks for the model.
    return { result: { ...(res.result as object), content: shrunk }, context: res.context }
  }).catch(($, e, next) => next(e))
}
