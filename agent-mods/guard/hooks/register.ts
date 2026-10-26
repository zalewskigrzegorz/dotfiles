import type { Register } from 'claude-code'

// Each deny names the rule file, so the model reads the why there.
// Rules: agent-rules/adhd-actions-not-walls.md, subagent-model-by-weight.md,
// no-native-worktrees.md, commit-message-rules.md, ugrep-not-gnu-grep.md.

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

export function bashProblem(command: string): string | undefined {
  if (/\bgit\s+add\s+(-A\b|--all\b|\.(\s|$))/.test(command))
    return 'no `git add -A` / `git add .`: stage only your own paths, other agents share the checkout (commit-message-rules.md)'
  if (/\bgit\s+commit\b[\s\S]*Co-Authored-By/i.test(command))
    return 'no Co-Authored-By trailer in commits (commit-message-rules.md)'
  if (/(^|[|;&]\s*)rg\b[^|;&]*\s-E\s/.test(command))
    return '`rg -E` means --encoding, not ERE: drop -E, rg regex is extended already (ugrep-not-gnu-grep.md)'
  return undefined
}

const denied = new Map<string, number>()

export const register: Register = on => {
  on('tool.call', { tool: 'AskUserQuestion' }, ($, e, next) => {
    const questions = e.questions as Question[]
    const problems = popupProblems(questions)
    if (problems.length === 0) return next(e)
    const key = questions.map(q => q.question).join('\n')
    const count = (denied.get(key) ?? 0) + 1
    denied.set(key, count)
    if (count > MAX_DENIES) {
      $.ui.toast(`guard: popup let through after ${MAX_DENIES} denies`)
      return next(e)
    }
    return { deny: `guard: fix the popup and ask again (adhd-actions-not-walls.md):\n- ${problems.join('\n- ')}` }
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: 'Agent' }, ($, e, next) => {
    const problem = agentProblem(e)
    return problem ? { deny: `guard: ${problem}` } : next(e)
  }).catch(($, e, next) => next(e))

  on('tool.call', { tool: 'EnterWorktree' }, () => ({
    deny: 'guard: no Claude-managed worktrees (no-native-worktrees.md); use workctl',
  }))

  on('tool.call', { tool: 'Bash' }, ($, e, next) => {
    const problem = bashProblem(e.command)
    return problem ? { deny: `guard: ${problem}` } : next(e)
  }).catch(($, e, next) => next(e))
}
