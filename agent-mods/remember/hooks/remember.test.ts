import { expect, test } from 'claude-code/testing'

const PERSON = { origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 120 } } as const

test('saves the args with the repo as project', async ($, on) => {
  const bodies: string[] = []
  on('command.register', () => ({ value: { command: 'zapamietaj' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: '/Users/greg/Code/dotfiles/.git\n', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('http.fetch', (_, e) => (bodies.push(String(e.init?.body)), { value: { status: 200, ok: true, headers: {}, text: '{}' } }))
  on('ui.toast', () => ({ value: undefined }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  const ran = await $.command.run({ command: 'zapamietaj', args: 'Greg trzyma mody w agent-mods', ...PERSON })
  expect(ran.text).toContain('project=dotfiles')
  expect(JSON.parse(bodies[0] ?? '{}').items[0]).toMatchObject({ content: 'Greg trzyma mody w agent-mods', metadata: { project: 'dotfiles' } })
})

test('nothing given and nothing selected saves nothing', async ($, on) => {
  let calls = 0
  on('command.register', () => ({ value: { command: 'zapamietaj' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('ui.selection', () => ({ value: undefined }))
  on('http.fetch', () => (calls++, { value: { status: 200, ok: true, headers: {}, text: '{}' } }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  const ran = await $.command.run({ command: 'zapamietaj', args: '', ...PERSON })
  expect(ran.text).toContain('Nic do zapisania')
  expect(calls).toBe(0)
})

test('a refused save says so', async ($, on) => {
  on('command.register', () => ({ value: { command: 'zapamietaj' } }))
  on('session.start', (_, e) => ({ cwd: e.cwd }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: '/r/x/.git', stderr: '', isStdoutTruncated: false, isStderrTruncated: false } }))
  on('http.fetch', () => ({ value: { status: 500, ok: false, headers: {}, text: '' } }))
  await $.session.start({ cwd: '/', surface: 'terminal', isInteractive: true })

  expect((await $.command.run({ command: 'zapamietaj', args: 'x', ...PERSON })).text).toContain('(500)')
})
