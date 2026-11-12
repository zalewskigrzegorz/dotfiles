import { expect, test } from 'claude-code/testing'
import type { TestBody } from 'claude-code/testing'

const SHOT = { content: [{ type: 'text', text: 'page' }, { type: 'image', data: 'BIGBIGBIGBIG', mimeType: 'image/png' }], isError: false }

function stub(on: Parameters<TestBody>[1], exitCode: number) {
  const runs: string[] = []
  on('process.run', (_, e) => (runs.push(String(e.init?.stdin)), { value: { exitCode, stdout: exitCode ? '' : 'SMALL\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('tool.call', () => ({ result: SHOT }))
  return runs
}

test('a browser screenshot reaches the model shrunk, its text block untouched', async ($, on) => {
  const runs = stub(on, 0)
  const res = await $.tool.call({ tool: 'mcp__browsentic__page_screenshot' })
  expect(runs).toEqual(['BIGBIGBIGBIG'])
  expect((res.result as typeof SHOT).content).toEqual([SHOT.content[0], { ...SHOT.content[1], data: 'SMALL' }])
})

test('an image that cannot be shrunk goes through as it came', async ($, on) => {
  stub(on, 3)
  const res = await $.tool.call({ tool: 'mcp__vimma__vimma_screenshot' })
  expect((res.result as typeof SHOT).content).toEqual(SHOT.content)
})

test('other MCP tools are not touched', async ($, on) => {
  const runs = stub(on, 0)
  await $.tool.call({ tool: 'mcp__claude_ai_Figma__get_screenshot' })
  expect(runs).toEqual([])
})
