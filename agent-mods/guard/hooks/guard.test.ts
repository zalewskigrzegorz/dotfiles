import { expect, test } from 'claude-code/testing'

import { agentProblem, ambiguousFirstNames, bareFirstNames, bashProblem, mcpProblem, popupProblems } from './register'

const good = {
  question: 'Który mod budujemy?',
  header: 'Mod',
  multiSelect: false,
  options: [
    { label: 'Strażnik (Recommended)', description: 'Mały, od razu działa.' },
    { label: 'Band', description: 'Widoczny, ale rusza ekranem.' },
  ],
}

test('a clean popup passes', () => {
  expect(popupProblems([good])).toEqual([])
})

test('each popup rule fires', () => {
  const bad = {
    question: 'Kupujemy 60 sztuk?',
    header: 'Bardzo długi nagłówek',
    multiSelect: true,
    options: [
      { label: '1) tak', description: '' },
      { label: 'Nie (Recommended)', description: 'x', preview: 'a' },
      { label: 'Other', description: 'x' },
    ],
  }
  const p = popupProblems([bad]).join('\n')
  for (const part of ['over 12 chars', 'has a number', 'only makes sense', 'no description', 'first option only', 'single-select', 'Other is added'])
    expect(p).toContain(part)
  expect(popupProblems([good, good, good]).join()).toContain('at most 2 questions')
  expect(popupProblems([{ ...good, options: [good.options[0]] }]).join()).toContain('2-4 options')
  const long = { ...good, options: [{ ...good.options[0], preview: 'x\n'.repeat(16) }, good.options[1]] }
  expect(popupProblems([long]).join()).toContain('over 15 lines')
})

test('agent spawns', () => {
  expect(agentProblem({ model: 'sonnet' })).toBeUndefined()
  expect(agentProblem({ subagent_type: 'fork' })).toBeUndefined()
  expect(agentProblem({})).toContain('names `model`')
  expect(agentProblem({ model: 'opus', isolation: 'worktree' })).toContain('worktree')
})

test('bash traps', () => {
  for (const ok of ['git add agent-mods .gitignore', 'git add -- a.ts', 'grep -E "a|b" x', 'rg -n -e foo', 'git commit -m "fix: x"', "rg -n 'git add -A|rg -E' agent-rules/", 'git commit -m "never git add ."'])
    expect(bashProblem(ok)).toBeUndefined()
  expect(bashProblem('git add -A && git commit -m x')).toContain('git add -A')
  expect(bashProblem('git add .')).toContain('git add -A')
  expect(bashProblem('git commit -m "x\n\nCo-Authored-By: Claude"')).toContain('Co-Authored-By')
  expect(bashProblem('cat f | rg -E "a|b"')).toContain('--encoding')
})

test('a bad popup is denied, then let through after three denies', async ($, on) => {
  on('tool.call', () => ({ result: {} }))
  const bad = { ...good, header: 'Bardzo długi nagłówek' }
  for (let i = 0; i < 3; i += 1) {
    const r = await $.tool.call({ tool: 'AskUserQuestion', questions: [bad] })
    expect(JSON.stringify(r)).toContain('guard: fix the popup')
  }
  const fourth = await $.tool.call({ tool: 'AskUserQuestion', questions: [bad] })
  expect(JSON.stringify(fourth)).not.toContain('guard:')
  const clean = await $.tool.call({ tool: 'AskUserQuestion', questions: [good] })
  expect(JSON.stringify(clean)).not.toContain('guard:')
})

test('a first name several people share is a bare name unless the surname follows', () => {
  const matrix = '| Full name | GitHub |\n|---|---|\n| Anna Nowak | a |\n| Anna Kowal | b |\n| Roman Lis | r |\n| Roman Bak | s |\n| Alan Turing | t |'
  const amb = ambiguousFirstNames(matrix)
  expect([...amb].sort()).toEqual(['anna', 'roman'])
  expect(bareFirstNames('Odpowiedź dla Romana w wątku', amb)).toEqual(['Romana'])
  expect(bareFirstNames('Daj znać Romanowi i Annie', amb)).toEqual(['Romanowi', 'Annie'])
  expect(bareFirstNames('Anna Nowak robi review', amb)).toEqual([])
  expect(bareFirstNames('Alan robi review, Romantyczny adapter też', amb)).toEqual([])
})

test('an unbraced zsh modifier after a variable is denied, ports and paths pass', () => {
  expect(bashProblem('git push origin "$c:refs/heads/x"')).toContain('zsh modifier')
  expect(bashProblem('git show $P:tooling/a.ts')).toContain('zsh modifier')
  expect(bashProblem('git push origin "${c}:refs/heads/x"')).toBeUndefined()
  expect(bashProblem('export PATH=$PATH:/usr/bin')).toBeUndefined()
  expect(bashProblem('curl http://$host:8080')).toBeUndefined()
  expect(bashProblem("rg '$x:t' file")).toBeUndefined()
})

test('rule-file traps are denied, their correct forms pass', () => {
  const cases: [string, string | undefined][] = [
    ["rg --type tsx foo src", "-g '*.tsx'"],
    ["rg -n -g '*.ts' -g '*.tsx' foo src", undefined],
    ['rg -l foo src 2>/dev/null', '2>/dev/null'],
    ['rg -n -- "x" src --max-count 3', 'after `--`'],
    ["rg -n -m 3 -- '-x' src", undefined],
    ["rg '(a)\\1' f", 'backreferences'],
    ["rg --pcre2 '(a)\\1' f", undefined],
    ["git diff | grep -v '^\\+\\+\\+'", 'ugrep'],
    ["git diff | grep -E '^\\+[^+]'", undefined],
    ['echo ======', 'command lookup'],
    ['echo "===="', undefined],
    ['echo "$resp" | jq .ok', 'printf'],
    ["printf '%s' \"$resp\" | jq .ok", undefined],
    ['while pgrep -f "artisan import"; do sleep 5; done', 'bracket trick'],
    ['timeout 600 sh -c \'while pgrep -f "[a]rtisan import"; do sleep 5; done\'', undefined],
    ['until gh pr checks 12 | grep -q pass; do sleep 60; done', 'gh-run-wait'],
    ['while read n; do gh pr view $n --json state; done < prs', undefined],
    ['gh run download 123', 'fresh dir'],
    ['gh run download 123 -D /tmp/x/run-123', undefined],
    ['bin/gh-run-wait e2e.yml', 'on PATH'],
    ['collie update --help | head -30', '--help | head'],
    ['collie -h', undefined],
    ['pnpm exec tsc e2e/a/spec.ts --noEmit', 'TS5112'],
    ['pnpm exec tsc -p e2e/a/tsconfig.json --noEmit', undefined],
    ['pnpm test -- src/a.spec.ts', 'vitest run'],
    ['pnpm install', 'confirmModulesPurge'],
    ['CI=true pnpm install', 'lockfile'],
    ['pnpm install --config.confirmModulesPurge=false', undefined],
    ['pnpm install zod', undefined],
    ['npx skills add foo/bar@baz', 'skills use'],
    ['rg -l dagr ~/.claude/projects/*/*.jsonl', 'mp-search'],
  ]
  for (const [cmd, want] of cases) {
    const got = bashProblem(cmd)
    if (want === undefined) expect(got).toBeUndefined()
    else expect(got).toContain(want)
  }
})

test('mcp calls without a size cap are denied', () => {
  expect(mcpProblem('mcp__hindsight__recall', {})).toContain('max_tokens')
  expect(mcpProblem('mcp__hindsight__recall', { max_tokens: 512 })).toBeUndefined()
  expect(mcpProblem('mcp__mempalace__mempalace_search', { limit: 5 })).toContain('limit: 2')
  expect(mcpProblem('mcp__mempalace__mempalace_search', { limit: 2 })).toBeUndefined()
})

test('a denied command also toasts', async ($, on) => {
  on('tool.call', () => ({ result: {} }))
  const r = await $.tool.call({ tool: 'Bash', command: 'pnpm install' })
  expect(JSON.stringify(r)).toContain('guard:')
})
