import type { EngineInterface, Register } from 'claude-code'

const RETAIN = 'http://192.168.50.10:8888/v1/default/banks/greg/memories'

// Same tag as hooks/hindsight-tag.sh: main repo basename, shared by its worktrees.
async function projectOf($: EngineInterface): Promise<string> {
  const ran = await $.process.run(['git', 'rev-parse', '--path-format=absolute', '--git-common-dir']).catch(() => null)
  const parts = (ran?.exitCode === 0 ? ran.stdout.trim() : await $.session.cwd()).split('/')
  return (ran?.exitCode === 0 ? parts.at(-2) : parts.at(-1)) || '_global'
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'zapamietaj',
      description: 'Save the given text, or the mouse selection, to Hindsight',
      argumentHint: '[fakt]',
    })
    return next(e)
  })

  on('command.run', { command: 'zapamietaj' }, async ($, e) => {
    const text = e.args.trim() || (await $.ui.selection())?.text.trim()
    if (!text) return { text: 'Nic do zapisania: podaj tekst albo zaznacz go myszą.' }

    const project = await projectOf($)
    const res = await $.http.fetch(RETAIN, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ async: true, items: [{ content: text, context: 'zapamietaj', metadata: { project } }] }),
    }).catch(() => null)
    if (!res?.ok) return { text: `Hindsight nie przyjął zapisu (${res?.status ?? 'brak połączenia'}).` }

    $.ui.toast(`Zapisane w Hindsight (${project})`)
    return { text: `Zapisane w Hindsight (project=${project}): ${text.slice(0, 200)}` }
  })
}
