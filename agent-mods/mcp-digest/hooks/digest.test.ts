import { expect, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

const BIG = 'x'.repeat(20_000)

function stub(on: Parameters<TestBody>[1], text: string, answered = true, off = false) {
  const asked: string[] = []
  const written: string[] = []
  on('store.get', () => ({ value: off }))
  on('env.get', () => ({ value: '/home/t' }))
  on('fs.write', (_, e) => (written.push(e.path), { value: undefined }))
  const usage = { input_tokens: 1, output_tokens: 1, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 }
  on('model.complete', (_, e) => (asked.push(e.prompt), { value: answered ? { isAnswered: true as const, text: 'NOTES', usage } : { isAnswered: false as const, reason: 'empty-reply' as const, usage } }))
  on('tool.call', () => ({ result: { content: [{ type: 'text', text }], isError: false }, text }))
  return { asked, written }
}

const textOf = (r: { result?: unknown }) => (r.result as { content: { text: string }[] }).content[0]!.text

test('a big Slack result reaches the model as Haiku notes plus the full file', async ($, on) => {
  const { asked, written } = stub(on, BIG)
  const res = await $.tool.call({ tool: 'mcp__claude_ai_Slack__slack_read_thread', tool_use_id: 'tu1', channel: 'C1' } as never)
  expect(written).toEqual(['/home/t/.claude/mcp-digest/tu1.txt'])
  expect(asked[0]).toContain('"channel":"C1"')
  expect(textOf(res)).toContain('/home/t/.claude/mcp-digest/tu1.txt')
  expect(textOf(res)).toContain('NOTES')
})

test('a small result goes through whole', async ($, on) => {
  const { asked } = stub(on, 'short')
  const res = await $.tool.call({ tool: 'mcp__claude_ai_Slack__slack_read_thread' } as never)
  expect(asked).toEqual([])
  expect(textOf(res)).toBe('short')
})

test('no Haiku answer leaves the whole result', async ($, on) => {
  stub(on, BIG, false)
  const res = await $.tool.call({ tool: 'mcp__mempalace__mempalace_search' } as never)
  expect(textOf(res)).toBe(BIG)
})

test('switched off, a big result goes through whole', async ($, on) => {
  const { asked } = stub(on, BIG, true, true)
  const res = await $.tool.call({ tool: 'mcp__claude_ai_Slack__slack_read_thread' } as never)
  expect(asked).toEqual([])
  expect(textOf(res)).toBe(BIG)
})

test('code tools are never digested', async ($, on) => {
  const { asked } = stub(on, BIG)
  await $.tool.call({ tool: 'mcp__serena__find_symbol' } as never)
  expect(asked).toEqual([])
})
