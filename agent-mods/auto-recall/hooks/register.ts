import type { EngineInterface, Register } from 'claude-code'

const RECALL = 'http://192.168.50.10:8888/v1/default/banks/greg/memories/recall'
const TIMEOUT_MS = 4000

// Phrases from the MemPalace/Hindsight rule: Greg points at earlier work.
export const TRIGGER =
  /(wr[oó][cć](my|imy)? do|kontynuuj|co ustalili[sś]my|jak to wtedy|czemu tak zdecydowali[sś]my|podawa[lł]e[sś]|m[oó]wi[lł]e[sś],? [zż]e|gdzie to zapisa[lł]e[sś]|\bwracamy\b|^\s*(resume|continue)\s*$)/i

async function recall($: EngineInterface, query: string): Promise<string[]> {
  const res = await $.http.fetch(RECALL, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ query, max_tokens: 512, include: { entities: null } }),
  })
  if (!res.ok) return []
  return (JSON.parse(res.text).results ?? []).map((r: { text: string }) => r.text)
}

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    if (e.command || e.isMeta || !TRIGGER.test(e.text.slice(0, 300))) return next(e)

    // A fetch in flight does not count against the hook's budget, so a hung lab would hold the prompt.
    const timeout = new Promise<string[]>(resolve => $.clock.after(TIMEOUT_MS, () => resolve([])))
    const facts = await Promise.race([recall($, e.text.slice(0, 500)).catch(() => []), timeout])
    if (facts.length === 0) return next(e)

    $.ui.status(`Hindsight: ${facts.length} faktów w kontekście`)
    $.clock.after(20_000, () => $.ui.status(undefined))
    const block = `Hindsight recall (auto, max_tokens=512) for this prompt:\n${facts.map(f => `- ${f}`).join('\n')}`

    return next({ ...e, context: [...(e.context ?? []), block] })
  })
}
