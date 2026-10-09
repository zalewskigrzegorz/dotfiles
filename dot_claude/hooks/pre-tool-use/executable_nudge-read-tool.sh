#!/bin/bash
# nudge-read-tool — a `cat|head|tail|sed -n <source file>` (alone or in a
# `;`/`&&` chain) gets a one-line reminder that Read / Serena is the tool.
# Never blocks and sets no permission decision (retro 2026-10-02: the rule was
# broken 58 times in one session; 2026-10-09 again). Pipe consumers, redirects,
# globs, `tail -f`, /tmp, scratchpad, logs and non-source files pass silently.
set -uo pipefail
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -n "$COMMAND" ] || exit 0
printf '%s' "$COMMAND" | grep -qE '(^|[;&])[[:space:]]*(cat|head|tail|sed)[[:space:]]' || exit 0
hit=0
# split on ; && newline; a segment containing a pipe is a filter, skip it
while IFS= read -r seg || [ -n "$seg" ]; do
  seg="${seg#"${seg%%[![:space:]]*}"}"
  case "$seg" in
    cat\ *|head\ *|tail\ *|"sed -n "*) ;;
    *) continue ;;
  esac
  case "$seg" in *'|'*|*'>'*|*'<'*|*'$('*|*'`'*|*'*'*|*'?'*|*'{'*|*'['*) continue ;; esac
  [[ "$seg" =~ ^tail[[:space:]].*-[a-zA-Z]*[fF] ]] && continue
  file=${seg##* }
  case "$file" in -*|'') continue ;; esac
  case "$file" in /tmp/*|/private/tmp/*|/var/*|*scratchpad*|*.log|*.out|*.txt|*.jsonl|*.csv|*.tsv) continue ;; esac
  case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.rb|*.java|*.kt|*.swift|*.c|*.h|*.cpp|*.cs|*.php|*.sh|*.lua|*.vue|*.svelte|*.css|*.scss|*.html|*.json|*.yml|*.yaml|*.toml|*.md|*.sql|*.nu|*.tmpl) hit=1 ;;
  esac
done < <(printf '%s' "$COMMAND" | sed -E 's/&&/\n/g; s/;/\n/g')
[ "$hit" = 1 ] || exit 0
jq -n '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:"cat/head/tail/sed -n on a source file: use Read (offset/limit, several files = parallel Read calls) or Serena (symbols overview / find_symbol) instead. Not blocked."}}'
exit 0
