import type { Register } from 'claude-code'

// Connectors that dump far more than a task needs. Code (serena), SQL (jamsql), the browser
// and memory writes stay out: their exact text matters.
const CONNECTORS = /^mcp__(claude_ai_Slack|claude_ai_Sentry|claude_ai_Google_Drive|claude_ai_Google_Docs|claude_ai_Gmail|mempalace|n8n-mcp)__/
// ~2,000 tokens at ~4 characters a token.
const MIN_CHARS = 8_000
// Haiku's window with room to answer; past it the head goes and the full file holds the rest.
const MAX_CHARS = 400_000

const SYSTEM = `You condense a tool result for another AI assistant that called the tool.
Keep everything the request below can use: names, ids, numbers, dates, URLs, file paths, error messages, and short quotes where exact wording matters.
Drop what it cannot use: avatars, empty fields, boilerplate, repeated metadata.
Answer with the notes alone, no preamble. If the whole result matters, say so in one line and keep the most important parts.`

export const register: Register = on => {
  let lastPrompt = ''

  on('session.start', async ($, e, next) => {
    await $.command.register({ name: 'mcp-digest', description: 'Haiku digest of big connector results: on, off, or no argument for the state', argumentHint: '[on|off]' }).catch(() => {})
    const home = await $.env.get('HOME')
    if (home) void $.process.run(['find', `${home}/.claude/mcp-digest`, '-type', 'f', '-mtime', '+2', '-delete']).catch(() => null)
    return next(e)
  })

  on('prompt.submit', ($, e, next) => {
    if (!e.isMeta) lastPrompt = e.text.slice(0, 4_000)
    return next(e)
  })

  on('command.run', { command: 'mcp-digest' }, async ($, e) => {
    const arg = e.args.trim()
    if (arg === 'off' || arg === 'on') await $.store.set('off', arg === 'off')
    const off = (await $.store.get('off')) === true
    return { text: `mcp-digest: ${off ? 'off, connector results reach the model whole' : 'on, results over ~2k tokens go through Haiku'}` }
  })

  on('tool.call', { tool: CONNECTORS }, async ($, e, next) => {
    const res = await next(e)
    const full = res.text ?? ''
    if (res.deny !== undefined || res.isError || full.length < MIN_CHARS || (await $.store.get('off')) === true) return res

    const home = await $.env.get('HOME')
    if (!home) return res
    const path = `${home}/.claude/mcp-digest/${e.tool_use_id ?? Date.now()}.txt`
    await $.fs.write(path, full)

    const { tool, tool_use_id, ...args } = e
    const r = await $.model.complete({
      model: 'haiku',
      system: SYSTEM,
      prompt: `The user's request:\n${lastPrompt || '(unknown)'}\n\nTool: ${tool}\nArguments: ${JSON.stringify(args).slice(0, 2_000)}\n\n<result>\n${full.slice(0, MAX_CHARS)}\n</result>`,
      maxTokens: 2_000,
      timeoutMs: 60_000,
    })
    if (!r.isAnswered) return res // Haiku down or too slow: the whole result, as without the mod

    const tokens = Math.round(full.length / 4)
    $.ui.log(`${tool}: ~${tokens} tokens → ~${Math.round(r.text.length / 4)}`, { to: 'debug' })
    const text = `[mcp-digest] The result had ~${tokens} tokens; Haiku kept what your task needs. Full result: ${path} (Grep it or Read with offset/limit when a detail is missing).\n\n${r.text}`
    return { result: { content: [{ type: 'text', text }], isError: false }, context: res.context }
  }).catch(($, e, next) => next(e))
}
