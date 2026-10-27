import type { Register } from 'claude-code'

// Each deny names the rule file, so the model reads the why there.
// Rules: agent-rules/adhd-actions-not-walls.md, subagent-model-by-weight.md,
// no-native-worktrees.md, commit-message-rules.md, ugrep-not-gnu-grep.md,
// zsh-bash-tool.md, ops-traps.md, memory-location.md. A trap enforced here keeps
// only a one-line pointer in its rule file: the deny text carries the fix.

type Option = { label: string; description?: string; preview?: string }
type Question = { question: string; header: string; options: Option[]; multiSelect?: boolean }

/** A popup that keeps getting denied passes on this try, so Greg is never left without one. */
const MAX_DENIES = 3
const OTHER = /^(other|inne|coś innego|something else)$/i
const BARE_LABEL = /^(\d+[.)]|[A-D][.)]|Q\d+\b|Task\s?\d+|ADR\s?\d+|Opcja\s?\d+)/i

export function popupProblems(questions: Question[]): string[] {
  const out: string[] = []
  if (questions.length > 2) out.push('at most 2 questions per popup, chain the rest')
  for (const q of questions) {
    const opts = q.options ?? []
    if (opts.length < 2 || opts.length > 4) out.push(`"${q.header}": 2-4 options, got ${opts.length}`)
    if ([...(q.header ?? '')].length > 12) out.push(`header "${q.header}" is over 12 chars`)
    if (/\d/.test(q.question)) out.push('`question` has a number: move counts, prices, labels into description or preview')
    opts.forEach((o, i) => {
      if (OTHER.test(o.label.trim())) out.push(`"${o.label}": Other is added automatically, drop it`)
      if (BARE_LABEL.test(o.label.trim())) out.push(`label "${o.label}" only makes sense from the prose above: say the action`)
      if (!o.description?.trim()) out.push(`label "${o.label}" has no description: say the trade-off`)
      if (i > 0 && /\(Recommended\)/i.test(o.label)) out.push('(Recommended) goes on the first option only')
      if (o.preview !== undefined && q.multiSelect) out.push('preview works only with single-select')
      if (o.preview !== undefined && o.preview.split('\n').length > 15)
        out.push('a preview over 15 lines: print the draft as plain text, end with "powiedz wyślij", no popup')
    })
  }
  return out
}

export function agentProblem(e: { model?: string; subagent_type?: string; isolation?: string }): string | undefined {
  if (e.isolation === 'worktree') return 'no isolation: "worktree" in Greg\'s repos (no-native-worktrees.md); use workctl or the shared workspace'
  if (e.subagent_type !== 'fork' && !e.model?.trim())
    return 'every spawn names `model`: score the task first (subagent-model-by-weight.md) and state the score in the spawn line'
  return undefined
}

// Columns that usually hold a whole JSON blob: one of them raw dumps every key, tokens included.
const BLOB = /^(\w+\.)?(details|metadata|meta|data|payload|attributes|settings|config|raw|body|extra|spanattributes|logattributes|resourceattributes)$/i
const SECRET = /token|secret|passw|api_?key|private_?key|credential|session_?id|cookie/i

/** Top-level select-list items of every SELECT in the text, split on commas outside parentheses. */
function selectItems(sql: string): string[] {
  const items: string[] = []
  for (const m of sql.matchAll(/\bselect\b/gi)) {
    let depth = 0
    let item = ''
    for (let i = m.index + m[0].length; i < sql.length; i += 1) {
      const ch = sql[i]
      if (ch === '(') depth += 1
      if (ch === ')' && --depth < 0) break
      if (depth === 0 && /^from\b/i.test(sql.slice(i)) && !/\w/.test(sql[i - 1] ?? ' ')) break
      if (depth === 0 && ch === ',') (items.push(item), (item = ''))
      else item += ch
    }
    items.push(item)
  }
  // An alias goes only after `AS` or a finished expression, so `a - token` keeps its `token`.
  return items.map(s => s.trim().replace(/(\s+as\s+[`"]?\w+[`"]?|(?<=[\w)\]'"`])\s+[`"]?\w+[`"]?)$/i, '').trim()).filter(Boolean)
}

// The whole item is one call that cannot return the value whole: a length, a hash, or at most 4 chars.
const SAFE_WRAP = /^((length|count|uniq\w*|md5|sha\w*|cityhash64|isnull|notempty|empty)\s*\([^()]*\)|left\s*\([^(),]*,\s*[1-4]\s*\))$/i

export function sqlProblem(sql: string): string | undefined {
  const fix = 'name only the fields you need (JSONExtract…(col, \'key\'), `col->>\'key\'`, `* EXCEPT(col)`); a secret-named field only as `length(x)` / `left(x, 4)`. A printed token stays in the transcript and in MemPalace (ops-traps.md)'
  for (const item of selectItems(sql)) {
    if (/^(\w+\.)?\*$/.test(item)) return `\`SELECT ${item}\` can carry tokens: ${fix}`
    // A cast or serialiser around a blob still prints all of it: `details::text`, `toString(details)`.
    const unwrapped = item.replace(/::\w+$/, '').replace(/^(tostring|to_json\w*|row_to_json|cast)\s*\(\s*([\w.]+)(\s+as\s+\w+)?\s*\)$/i, '$2')
    if (BLOB.test(unwrapped)) return `raw JSON column \`${item}\` dumps every key, tokens included: ${fix}`
    const named = item.replace(/\blike\s+'[^']*'/gi, '')
    if (SECRET.test(named) && !SAFE_WRAP.test(named))
      return `\`${item.slice(0, 60)}\` reads a secret-named field: ${fix}`
  }
  return undefined
}

export function bashProblem(command: string): string | undefined {
  // Quoted text is a pattern or a message, not a command: `rg 'git add -A'` must pass.
  const bare = command.replace(/'[^']*'|"[^"]*"/g, "''")
  // Raw command, not `bare`: the client often sits inside quotes (`ssh lab 'psql …'`, `sh -c "…"`).
  if (/\b(psql|clickhouse(-client)?|ch-query|gq\.sh|mysql|sqlite3|duckdb)\b/.test(command)) {
    const problem = sqlProblem(command)
    if (problem) return problem
  }
  if (/\bgit\s+add\s+(-A\b|--all\b|\.(\s|$))/.test(bare))
    return 'no `git add -A` / `git add .`: stage only your own paths, other agents share the checkout (commit-message-rules.md)'
  if (/\bgit\s+commit\b[\s\S]*Co-Authored-By/i.test(command))
    return 'no Co-Authored-By trailer in commits (commit-message-rules.md)'
  // zsh reads `$var:t` / `:h :r :e :l :u` as a modifier, inside double quotes too.
  if (/\$[A-Za-z_]\w*:[htrelu]/.test(command.replace(/'[^']*'/g, "''")))
    return 'unbraced `$var:<letter>` is a zsh modifier (`$c:refs` → `…efs`): write `${var}:…` (zsh traps)'
  if (/(^|[|;&]\s*)rg\b[^|;&]*\s-E\s/.test(bare))
    return '`rg -E` means --encoding, not ERE: drop -E, rg regex is extended already (ugrep-not-gnu-grep.md)'
  if (/(^|[|;&]\s*)rg\b[^|;&]*\s(--type[= ]|-t\s*)tsx\b/.test(bare))
    return '`rg --type tsx` does not exist and `ts` skips .tsx: use `-g \'*.ts\' -g \'*.tsx\'` (ugrep-not-gnu-grep.md)'
  if (/(^|[|;&]\s*)rg\b[^|;&]*\s2>\s*\/dev\/null/.test(bare))
    return 'no `2>/dev/null` on rg: a swallowed error reads as "no hits" (ugrep-not-gnu-grep.md)'
  if (/(^|[|;&]\s*)rg\b[^|;&]*\s--\s[^|;&]*\s-[-\w]/.test(bare))
    return 'everything after `--` is a path for rg: put every flag before `--`, and use `--` only for a pattern starting with `-` (ugrep-not-gnu-grep.md)'
  if (/\brg\b/.test(bare) && !/--pcre2|\s-P\b|\b(sed|perl|awk)\b/.test(bare) && /\\[1-9]/.test(command))
    return 'rg has no backreferences: `rg --pcre2 \'…\\1…\'` (ugrep-not-gnu-grep.md)'
  for (const m of command.matchAll(/(?:^|[|;&(]\s*)grep((?:\s+-[A-Za-z]+)*)\s+(?:-e\s+)?(?:'([^']*)'|"([^"]*)")/g))
    if (!/[EFP]/.test(m[1] ?? '') && /\\[+?{|]/.test(m[2] ?? m[3] ?? ''))
      return 'grep is ugrep: BRE `\\+ \\? \\{ \\|` are errors here; use `grep -E` with escapes, `grep -F`, or rg (ugrep-not-gnu-grep.md)'
  if (/(^|[;&|]\s*)echo\s+=/.test(bare))
    return 'zsh reads a word starting with `=` as a command lookup: quote it, `echo \'====\'` (zsh-bash-tool.md)'
  if (/\becho\s+"?\$\{?\w+\}?"?\s*\|\s*jq\b/.test(command))
    return '`echo` expands `\\n` inside JSON: pipe curl straight into jq, or `printf \'%s\' "$x" | jq`. A parse error after a send means check the channel, never resend (zsh-bash-tool.md)'
  if (/\b(while|until)\b/.test(command) && /\bpgrep\s+-\w*f\w*\s+(?!['"]?\[)/.test(command))
    return '`pgrep -f` in a wait loop matches its own shell: bracket trick `pgrep -f "[a]rtisan …"`, `pgrep -x`, or poll a log/marker; every loop gets a `timeout` (zsh-bash-tool.md)'
  if (/\b(while|until)\b/.test(command) && /\bsleep\b/.test(command) && /\bgh\s+(pr|run)\s+(checks|view|list)\b/.test(command))
    return 'no hand-written loop around gh: `gh-run-wait <workflow> --sha <sha>`, `timeout 1800 gh run watch <id> --exit-status`, or `gh-pr-checks-wait <n>` in the background (never `gh pr checks --watch`: no output without a TTY, the bg pane stays empty). Waiting for a human (merge, approval) ends the turn instead (zsh-bash-tool.md)'
  if (/\bgh\s+run\s+download\b(?![^|;&]*\s(-D|--dir)\b)/.test(bare))
    return '`gh run download -D <scratch>/run-<id>`, always a fresh dir: a reused one dies on "file exists" (zsh-bash-tool.md)'
  if (/(^|[\s;&|])(\.\/)?bin\/gh-run-wait\b/.test(bare))
    return '`gh-run-wait` is on PATH; `bin/gh-run-wait` is missing in worktrees and the watcher dies silently (zsh-bash-tool.md)'
  if (/(^|[;&|]\s*)\S+\s+[a-z][\w-]*\s+--help\b[^|;&]*\|\s*head\b/.test(bare))
    return 'no `<cmd> <sub> --help | head`: a CLI without --help runs the subcommand for real. Read its source/docs, or probe only top-level `-h`/`--version` (ops-traps.md)'
  if (/(^|[\s;&|])tsc\b(?![^|;&]*\s(-p|--project|-b|--build)\b)[^|;&]*\s\S+\.tsx?\b/.test(bare))
    return '`tsc <file>.ts` next to a tsconfig dies on TS5112: `pnpm exec tsc -p <dir>/tsconfig.json --noEmit` (`test -f` it first), never `--ignoreConfig` (ops-traps.md)'
  if (/\bpnpm\s+(run\s+)?test\s+--\s+\S/.test(bare))
    return '`pnpm test -- <file>` runs the whole nx target: `cd apps/<app> && pnpm exec vitest run <file>` (ops-traps.md)'
  if (/\bCI=(true|1)\s+pnpm\s+(install|i)\b/.test(bare))
    return 'no `CI=true pnpm install`, it changes lockfile behaviour: `pnpm install --config.confirmModulesPurge=false` (no-native-worktrees.md)'
  const install = bare.match(/\bpnpm\s+(?:install|i)((?:\s+-[\w=.-]+)*)\s*($|[;&|)])/)
  if (install && !install[1]?.includes('confirmModulesPurge'))
    return 'the Bash tool has no TTY and pnpm asks before purging modules: `pnpm install --config.confirmModulesPurge=false` (no-native-worktrees.md)'
  if (/\bnpx\s+(-y\s+)?skills\s+add\b/.test(bare))
    return '`npx skills add` writes into ~/.claude/skills, which stage 30 wipes: `npx skills use <owner/repo@skill>` via skill-scout, or copy into agent-skills/'
  if (/(^|[|;&]\s*)(rg|grep)\b[^|;&]*\.claude\/projects\/["']?\*/.test(command))
    return 'never search every session transcript: `mp-search \'<literal token>\'` first, then `recall(max_tokens=512)` (memory-location.md)'
  return undefined
}

export function mcpProblem(tool: string, e: { max_tokens?: number; limit?: number }): string | undefined {
  if (tool === 'mcp__hindsight__recall' && !e.max_tokens)
    return 'pass `max_tokens` to recall (start at 512): the default returns ~82 KB and overflows the client (memory-location.md)'
  if (tool === 'mcp__mempalace__mempalace_search' && !(e.limit && e.limit <= 3))
    return 'start mempalace_search at `limit: 2` (5 overflowed twice); for a literal token use `bin/mp-search` (ops-traps.md)'
  return undefined
}

type Toaster = { ui: { toast(text: string): unknown } }

/** Every deny also toasts, so Greg sees the guard fire, not only the model. */
function deny($: Toaster, reason: string) {
  $.ui.toast(`🛡 guard: ${(reason.split('\n')[0] ?? '').slice(0, 90)}`)
  return { deny: `guard: ${reason}` }
}

// First names worn by 2+ people in the work-people matrix: alone in a popup they name nobody.
export function ambiguousFirstNames(markdown: string): Set<string> {
  const counts = new Map<string, number>()
  for (const line of markdown.split('\n')) {
    const name = line.split('|')[1]?.trim() ?? ''
    if (!name || name === 'Full name' || /^-+$/.test(name)) continue
    const first = name.split(/\s+/)[0]?.toLowerCase()
    if (first && first.length >= 3) counts.set(first, (counts.get(first) ?? 0) + 1)
  }
  return new Set([...counts].filter(([, n]) => n >= 2).map(([first]) => first))
}

// A capitalised word that is an ambiguous first name, inflected or not ("Romana",
// "Romanowi"), with no capitalised surname right after it.
export function bareFirstNames(text: string, ambiguous: Set<string>): string[] {
  const words = text.split(/[^\p{L}]+/u).filter(Boolean)
  const hits: string[] = []
  words.forEach((w, i) => {
    if (!/^\p{Lu}/u.test(w)) return
    // Polish swaps the last vowel (Anna → Anny, Annie), so match on the name without it.
    const stem = [...ambiguous].find(f => {
      const root = f.length > 3 ? f.replace(/[aeiouy]$/, '') : f
      return w.toLowerCase().startsWith(root) && w.length <= f.length + 3
    })
    if (stem && !/^\p{Lu}/u.test(words[i + 1] ?? '')) hits.push(w)
  })
  return hits
}

let ambiguous = new Set<string>()
const denied = new Map<string, number>()

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    // Found by shape, so no org name sits in this public repo.
    void $.process
      .run(['find', '/Users/greg/Code/personal/bazgroly', '-maxdepth', '2', '-name', 'people.md'])
      .then(found => found.stdout.split('\n').find(Boolean))
      .then(path => (path ? $.fs.read(path) : ''))
      .then(text => (ambiguous = ambiguousFirstNames(text)))
      .catch(() => {})
    return next(e)
  })

  on('tool.call', { tool: 'AskUserQuestion' }, ($, e, next) => {
    const questions = e.questions as Question[]
    const texts = questions.flatMap(q => [q.question, ...q.options.flatMap(o => [o.label, o.description ?? ''])])
    const bare = [...new Set(texts.flatMap(t => bareFirstNames(t, ambiguous)))]
    const problems = [
      ...popupProblems(questions),
      ...(bare.length ? [`bare first name ${bare.join(', ')}: several people share it, write the full name from work-people (coworkers-by-full-name)`] : []),
    ]
    if (problems.length === 0) return next(e)
    const key = questions.map(q => q.question).join('\n')
    const count = (denied.get(key) ?? 0) + 1
    denied.set(key, count)
    if (count > MAX_DENIES) {
      $.ui.toast(`guard: popup let through after ${MAX_DENIES} denies`)
      return next(e)
    }
    $.ui.toast(`🛡 guard: popup — ${(problems[0] ?? '').slice(0, 80)}`)
    return { deny: `guard: fix the popup and ask again (adhd-actions-not-walls.md):\n- ${problems.join('\n- ')}` }
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: 'Agent' }, ($, e, next) => {
    const problem = agentProblem(e)
    return problem ? deny($, problem) : next(e)
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: 'EnterWorktree' }, $ => deny($, 'no Claude-managed worktrees (no-native-worktrees.md); use workctl'))

  on('tool.call', { tool: 'Bash' }, ($, e, next) => {
    const problem = bashProblem(e.command)
    return problem ? deny($, problem) : next(e)
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: /^mcp__jamsql__(query_execute\w*|ui_execute_query)$/ }, ($, e, next) => {
    const problem = sqlProblem(Object.values(e).filter(v => typeof v === 'string').join('\n'))
    return problem ? deny($, problem) : next(e)
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: /^mcp__(hindsight__recall|mempalace__mempalace_search)$/ }, ($, e, next) => {
    const problem = mcpProblem(e.tool, e as { max_tokens?: number; limit?: number })
    return problem ? deny($, problem) : next(e)
  }).catch(($, e, next) => next(e))
}
