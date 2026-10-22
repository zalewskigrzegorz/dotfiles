#!/usr/bin/env bash
# herdr tab / statusline title — a 3–4 word essence of the task, written by Haiku
# (drives bin/hd-title).
#
#   * Stop — after the first answer, then at most once per 3 prompts or 10 min,
#     Haiku reads the recent conversation and keeps or replaces the title. Runs
#     in the background, so the hook returns at once.
#   * SessionStart source=clear — forget the title and hand the tab back to the
#     herdr auto-title plugin until the next answer.
#
# A title the agent set itself with `hd-title` (store differs from <sid>.auto) is
# never overwritten. The first prompt is no longer used as a title: it rarely
# said what the session was about (2026-10-21).
#
#   herdr-claude-title.sh --retitle <transcript>   one pass now, guard ignored
#                                                   (needs CLAUDE_CODE_SESSION_ID)
set -u

# The Haiku call below is a Claude session too; never recurse into it.
[ -n "${HD_TITLE_CHILD:-}" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

HD=$(command -v hd-title 2>/dev/null || echo "$HOME/Code/dotfiles/bin/hd-title")
[ -x "$HD" ] || exit 0
title_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-session-title"
task_log="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-task-log.jsonl"

# Append-only trail for /g-standup: one line per title check, survives /clear.
log_task() {
  [ -n "$1" ] || return 0
  jq -nc --arg ts "$(date +%FT%T%z)" --arg sid "$CLAUDE_CODE_SESSION_ID" --arg cwd "$PWD" \
    --arg br "$(git branch --show-current 2>/dev/null)" --arg t "$1" \
    '{ts:$ts,sid:$sid,cwd:$cwd,branch:$br,title:$t}' >> "$task_log"
}

SYSTEM='Nadajesz tytuł zakładce terminala, w której agent pracuje nad zadaniem użytkownika.
Tytuł ma 2–4 słowa po polsku i mówi, CO użytkownik chce osiągnąć: czynność albo problem plus przedmiot.
Przykłady formy: "Review: limity planów", "Fix: logowanie przez SSO", "Faktury: brakujące koszty", "Plan wyjazdu w góry".
Bez nazw repozytoriów, ścieżek, numerów PR, cudzysłowów i kropki na końcu.
Jeśli dostaniesz obecny tytuł i nadal dobrze opisuje bieżące zadanie, odpowiedz dokładnie: ZOSTAW
Odpowiadasz wyłącznie tytułem albo słowem ZOSTAW.'

# Prompt count + context for Haiku, from the transcript. Real prompts only:
# tool results, hook output and command echoes start with "<" or are arrays
# without text.
context() {
  jq -c 'def txt: if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join(" ")) end;
         select(.type == "user" or .type == "assistant")
         | select((.isMeta // false) | not)
         | select(.message.content | txt | startswith("<") | not)
         | {t: .type, c: (.message.content | txt | gsub("<[^>]*>"; "") | gsub("\\s+"; " ") | ltrimstr(" "))}
         | select(.c != "")' "$1" 2>/dev/null \
  | jq -rs --arg cur "$2" '
      [.[] | select(.t == "user") | .c[0:400]] as $u
      | ([.[] | select(.t == "assistant") | .c] | last // "")[0:700] as $a
      | "\($u | length)\n"
        + (if $cur != "" then "Obecny tytuł: \($cur)\n\n" else "" end)
        + "Pierwsza prośba: \($u[0] // "")\n\nOstatnie prośby:\n"
        + ($u[-4:] | map("- " + .) | join("\n"))
        + "\n\nOstatnia odpowiedź agenta: \($a)"'
}

retitle() {
  local transcript="$1" force="$2" sid="$CLAUDE_CODE_SESSION_ID"
  local store="$title_dir/$sid" auto="$title_dir/$sid.auto" meta="$title_dir/$sid.meta" lock="$title_dir/$sid.lock"
  mkdir -p "$title_dir"
  # A store that is not ours is the agent's own hd-title: hands off.
  if [ "$force" != 1 ] && [ -s "$store" ] && [ "$(cat "$store")" != "$(cat "$auto" 2>/dev/null)" ]; then
    return 0
  fi
  # A lock left by a killed run would block the session for good.
  find "$lock" -maxdepth 0 -mmin +2 -exec rmdir {} \; 2>/dev/null
  mkdir "$lock" 2>/dev/null || return 0
  trap 'rmdir "$lock" 2>/dev/null' RETURN

  local cur ctx n n_last=0 t_last=0 now
  cur=$(cat "$auto" 2>/dev/null)
  ctx=$(context "$transcript" "$cur") || return 0
  n=$(printf '%s\n' "$ctx" | head -1)
  [ "${n:-0}" -gt 0 ] 2>/dev/null || return 0
  [ -f "$meta" ] && read -r n_last t_last < "$meta"
  now=$(date +%s)
  if [ "$force" != 1 ] && [ -n "$cur" ]; then
    # Re-ask only after 3 new prompts, or 10 min with at least one new prompt.
    [ $((n - n_last)) -ge 3 ] || { [ "$n" -gt "$n_last" ] && [ $((now - t_last)) -ge 600 ]; } || return 0
  fi

  local to; to=$(command -v timeout || command -v gtimeout) || return 0
  local out
  out=$(cd /tmp && HD_TITLE_CHILD=1 "$to" 30 claude -p --model claude-haiku-5-5 \
          --no-session-persistence --strict-mcp-config --tools "" --setting-sources "" \
          --system-prompt "$SYSTEM" "$(printf '%s\n' "$ctx" | tail -n +2)" </dev/null 2>/dev/null)
  printf '%s %s\n' "$n" "$now" > "$meta"
  # Haiku sometimes reasons first; the title is the last line.
  out=$(printf '%s\n' "$out" | sed -e '/^[[:space:]]*$/d' | tail -1 \
        | sed -e 's/^[[:space:]"„`*]*//' -e 's/[[:space:]"”`*.]*$//')
  [ -n "$out" ] || return 0
  case "$out" in [Zz][Oo][Ss][Tt][Aa][Ww]*) log_task "$cur"; return 0 ;; esac
  # Guard against an essay instead of a title.
  [ "$(printf '%s' "$out" | wc -w)" -le 6 ] && [ "${#out}" -le 45 ] || return 0
  "$HD" "$out"
  printf '%s' "$out" > "$auto"
  log_task "$out"
}

if [ "${1:-}" = "--retitle" ]; then
  [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ -f "${2:-}" ] || { echo "usage: CLAUDE_CODE_SESSION_ID=<sid> $0 --retitle <transcript>" >&2; exit 2; }
  retitle "$2" 1
  exit 0
fi

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0
sid=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -n "$sid" ] || exit 0
export CLAUDE_CODE_SESSION_ID="$sid"
event=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null)

case "$event" in
  SessionStart)
    src=$(printf '%s' "$INPUT" | jq -r '.source // empty' 2>/dev/null)
    if [ "$src" = "clear" ]; then
      rm -f "$title_dir/$sid" "$title_dir/$sid.auto" "$title_dir/$sid.meta"
      # An empty name hands the tab back to auto-title.
      [ "${HERDR_ENV:-}" = "1" ] && [ -n "${HERDR_TAB_ID:-}" ] \
        && herdr tab rename "$HERDR_TAB_ID" "" >/dev/null 2>&1
    fi
    ;;
  Stop)
    transcript=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
    [ -f "$transcript" ] || exit 0
    cwd=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
    ( cd "${cwd:-.}" 2>/dev/null; retitle "$transcript" 0 ) </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null
    ;;
esac

exit 0
