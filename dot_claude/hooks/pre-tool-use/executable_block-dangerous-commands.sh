#!/usr/bin/env bash
# Guards dangerous shell commands per Greg's permission policy. PreToolUse hook for Bash.
#
# Two decision tiers (redesigned 2026-07-31, spec: bazgroly/dotfiles/specs/
# 2026-07-31-permissions-auto-yolo-design.md):
#   emit_deny  → hard-block in every mode (catastrophic rm, curl|sh, raw-device
#                writes, mkfs/dd). Reserved for the irreversible.
#   emit_guard → interactive "ask" popup in ANY mode with a human at the keyboard
#                (default/acceptEdits/auto/plan) — verified empirically 2026-07-31
#                that hook "ask" prompts in acceptEdits and auto, it is NOT
#                auto-resolved. Hard-deny only in dontAsk/bypassPermissions or an
#                unknown mode (headless/subagent — nobody to answer the prompt).
#
# JSON permissionDecision is honored only on exit 0; exit 2 hard-blocks and the
# JSON is ignored.
#
# Configurable via env:
#   CLAUDE_PROTECTED_BRANCHES   comma list (default: main,master + git default)
#   CLAUDE_PUSH_ALLOWLIST       repos where push to a protected branch is allowed
#   CLAUDE_COMMIT_ALLOWLIST     repos where commit on a protected branch is allowed
#   CLAUDE_MANUAL_PUSH_REPOS    repos where push is always blocked (Greg pushes)

set -uo pipefail

# YOLO kill-switch — see bin/claude-yolo. If this session ran `claude-yolo on`,
# abstain so the yolo-allow catch-all hook auto-allows (bypasses even absolute denies).
if [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && [ -f "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/claude-yolo/$CLAUDE_CODE_SESSION_ID" ]; then
  exit 0
fi

PERMISSION_MODE=""

emit() {
  local decision="$1" reason="${2//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":"%s"}}\n' "$decision" "$reason"
  exit 0
}
emit_deny() { emit deny "$1"; }
emit_guard() {
  # Interactive ask in every mode with a human at the keyboard. Hook "ask"
  # prompts fine in acceptEdits/auto (verified 2026-07-31). Deny only where
  # nobody can answer: dontAsk, bypassPermissions, or an unrecognized mode.
  case "$PERMISSION_MODE" in
    default|acceptEdits|auto|plan)
      emit ask "$1" ;;
    *)
      emit deny "$1 [Blocked: no human available to approve in mode '${PERMISSION_MODE:-unknown}'. Do not retry or work around — report this to Greg.]" ;;
  esac
}

if ! command -v jq >/dev/null 2>&1; then
  emit_deny "jq is required for command protection hooks but is not installed."
fi

INPUT=$(cat)
PERMISSION_MODE=$(printf '%s' "$INPUT" | jq -r '.permission_mode // ""' 2>/dev/null || echo "")
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$COMMAND" ] && exit 0

# Normalised command for git-subcommand detection only. First blank out quoted
# substrings ('...' and "...") so a "git push" / "git commit" mentioned INSIDE a
# string argument (e.g. `grep 'git push' file`, `git commit -m "git push later"`)
# does NOT trigger the push/commit guards — only real, unquoted git invocations
# do. Then strip git global options (-C <path>, -c <kv>, --git-dir, --work-tree,
# --namespace) so `git -C <worktree> push` matches the same triggers as `git push`.
GIT_NORM=$(printf '%s' "$COMMAND" | sed -E \
  -e "s/'[^']*'//g" \
  -e 's/"[^"]*"//g' \
  -e 's/[[:space:]]-C[[:space:]]+[^[:space:]]+//g' \
  -e 's/[[:space:]]-c[[:space:]]+[^[:space:]]+//g' \
  -e 's/--git-dir=[^[:space:]]+//g' \
  -e 's/--work-tree=[^[:space:]]+//g' \
  -e 's/--namespace=[^[:space:]]+//g')

contains_cmd()  { printf '%s' "$COMMAND"  | grep -qE "$1"; }
contains_icmd() { printf '%s' "$COMMAND"  | grep -qiE "$1"; }
contains_git()  { printf '%s' "$GIT_NORM" | grep -qE "$1"; }

# ── Repo resolution helpers ──────────────────────────────────────────────
resolve_target_repo() {
  # Infer the target repo root from a command string (git -C <path>, cd <path>),
  # falling back to the hook's own cwd. Empty if not inside any repo.
  local cmd="$1" target=""
  target=$(printf '%s' "$cmd" | grep -oE 'git[[:space:]]+-C[[:space:]]+[^[:space:];&|]+' | head -1 | awk '{print $NF}')
  if [ -z "$target" ]; then
    target=$(printf '%s' "$cmd" | grep -oE '(^|[;&|]|[[:space:]])cd[[:space:]]+[^[:space:];&|]+' | head -1 | awk '{print $NF}')
  fi
  target="${target//\~/$HOME}"
  target="${target//\$HOME/$HOME}"
  if [ -n "$target" ] && [ -d "$target" ]; then
    git -C "$target" rev-parse --show-toplevel 2>/dev/null || true
  else
    git rev-parse --show-toplevel 2>/dev/null || true
  fi
}

path_in_list() {
  # path_in_list "/repo/root" "p1,p2,p3" — exit 0 if root matches an entry.
  local root="$1" list="$2" p
  IFS=',' read -ra _arr <<< "$list"
  for p in "${_arr[@]}"; do
    [ -z "$p" ] && continue
    p="${p//\~/$HOME}"
    p="${p//\$HOME/$HOME}"
    [ "$root" = "$p" ] && return 0
  done
  return 1
}

# ── sudo: ask (was deny until 2026-07-31) ────────────────────────────────
if contains_cmd '(^|[;&|(]|[[:space:]])sudo([[:space:]]|$)'; then
  emit_guard "sudo — elevated privileges."
fi

# ── Protected branch list ────────────────────────────────────────────────
DEFAULT_BRANCHES="main,master"
if GIT_DEFAULT=$(git config --get init.defaultBranch 2>/dev/null) && [ -n "$GIT_DEFAULT" ]; then
  DEFAULT_BRANCHES="$DEFAULT_BRANCHES,$GIT_DEFAULT"
fi
PROTECTED_BRANCHES="${CLAUDE_PROTECTED_BRANCHES:-$DEFAULT_BRANCHES}"
BR_REGEX=$(printf '%s' "$PROTECTED_BRANCHES" | tr ',' '\n' | awk 'NF{printf "%s%s",sep,$0; sep="|"}')

# ── Repo allowlists ──────────────────────────────────────────────────────
PUSH_ALLOWLIST="${CLAUDE_PUSH_ALLOWLIST:-$HOME/Code/personal/bazgroly}"
COMMIT_ALLOWLIST="${CLAUDE_COMMIT_ALLOWLIST:-$HOME/Code/personal/bazgroly,$HOME/Code/dotfiles,$HOME/Code/home-lab,/opt/homelab}"
MANUAL_PUSH_REPOS="${CLAUDE_MANUAL_PUSH_REPOS:-$HOME/Code/dotfiles,$HOME/Code/home-lab,/opt/homelab}"

# ── git push ─────────────────────────────────────────────────────────────
# Policy: push→protected = DENY; push→feature = ASK; bazgroly = allowed (autopush);
# manual-push repos (dotfiles, home-lab) = DENY (Greg pushes those himself).
if contains_git '(^|[;&|()]+[[:space:]]*)git[[:space:]]+push'; then
  PUSH_REPO_ROOT=$(resolve_target_repo "$COMMAND")
  if [ -n "$PUSH_REPO_ROOT" ] && path_in_list "$PUSH_REPO_ROOT" "$PUSH_ALLOWLIST"; then
    :  # push allowed in this repo — fall through (e.g. bazgroly autopush)
  elif [ -n "$PUSH_REPO_ROOT" ] && path_in_list "$PUSH_REPO_ROOT" "$MANUAL_PUSH_REPOS"; then
    emit_guard "Push in a manual-push repo (Greg normally pushes these himself)."
  else
    PROT=0
    contains_git "git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]*:)?($BR_REGEX)(\$|[[:space:]])" && PROT=1
    contains_git "git[[:space:]]+push.*:($BR_REGEX)(\$|[[:space:]])" && PROT=1
    if contains_git 'git[[:space:]]+push[[:space:]]*($|[;&|])'; then
      CURRENT=$(git -C "${PUSH_REPO_ROOT:-.}" branch --show-current 2>/dev/null || true)
      { [ -n "$CURRENT" ] && printf '%s' ",$PROTECTED_BRANCHES," | grep -q ",$CURRENT,"; } && PROT=1
    fi
    if [ "$PROT" -eq 1 ]; then
      emit_guard "Push to protected branch ($PROTECTED_BRANCHES)."
    else
      # Feature-branch push allowed silently in all modes (Greg, 2026-06-13).
      # Protected-branch push (above), manual-push repos (above), and force
      # push (below) are still blocked.
      :
    fi
  fi
fi

# Force push (any branch, even allowlisted): ask in default, deny in auto.
if contains_git '(^|[;&|()]+[[:space:]]*)git[[:space:]]+push' \
   && contains_git 'git[[:space:]]+push([[:space:]]+[^[:space:]]+)*[[:space:]]+(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]=]|$)'; then
  emit_guard "Force push overwrites remote history."
fi

# ── git commit on a protected branch ─────────────────────────────────────
# Policy: commit→protected = DENY, except COMMIT_ALLOWLIST repos (master is the
# working branch there). commit→feature = allowed (no emit; allowlisted in settings).
if contains_git '(^|[;&|()]+[[:space:]]*)git[[:space:]]+commit'; then
  COMMIT_REPO_ROOT=$(resolve_target_repo "$COMMAND")
  if [ -n "$COMMIT_REPO_ROOT" ]; then
    COMMIT_BRANCH=$(git -C "$COMMIT_REPO_ROOT" branch --show-current 2>/dev/null || true)
    if [ -n "$COMMIT_BRANCH" ] && printf '%s' ",$PROTECTED_BRANCHES," | grep -q ",$COMMIT_BRANCH,"; then
      if ! path_in_list "$COMMIT_REPO_ROOT" "$COMMIT_ALLOWLIST"; then
        emit_guard "Commit on protected branch '$COMMIT_BRANCH' — usually a feature branch is wanted (\`git checkout -b <branch>\`)."
      fi
    fi
  fi
  # ── Review gate (Greg, 2026-06-23; hunk dropped 2026-06-29 → reviewr) ────
  # `git commit` is intentionally NOT in settings.json allow, so EVERY commit
  # stops here. This is a deliberate signal, not friction: the prompt is your
  # cue to review the diff (herdr reviewr, prefix+r) BEFORE the commit lands.
  # Approving = "I've reviewed the diff." Asks in every interactive mode.
  emit_guard "📋 Review gate — przejrzyj diff (reviewr: prefix+r) ZANIM zatwierdzisz. Approve = diff przejrzany."
fi

# ── GitHub PR ops ────────────────────────────────────────────────────────
# gh pr create/edit/ready/close/reopen: allowed silently (Greg, 2026-07-31).
if contains_cmd '(^|[;&|(]|[[:space:]])gh[[:space:]]+pr[[:space:]]+merge'; then
  emit_guard "Merging a PR (Greg normally merges himself)."
fi

# ── Destructive filesystem operations ────────────────────────────────────
# Catastrophic rm targets → always deny (never legitimate).
CMD_NOQUOTE=$(printf '%s' "$COMMAND" | tr -d "'\"")
if printf '%s' "$CMD_NOQUOTE" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*[[:space:]]+)*-?[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+(/([[:space:]]|\*|$)|~|\$HOME|\$[A-Za-z_][A-Za-z0-9_]*|\.\./\.\.)' ; then
  emit_deny "Recursive force-delete on /, ~, \$HOME, an unresolved \$VAR, or .../.. — never allowed."
fi
if printf '%s' "$CMD_NOQUOTE" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-?[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+/(usr|etc|var|bin|sbin|lib|opt|root|boot)([[:space:]/]|$)'; then
  emit_deny "Recursive delete targeting a system directory — never allowed."
fi
# Plain rm allowed silently in all modes (Greg, 2026-06-13). The catastrophic
# rm -rf targets above (/, ~, $HOME, unresolved $VAR, system dirs) stay denied.

# ── Dangerous database operations → ask (was deny until 2026-07-31) ──────
if contains_icmd 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)[[:space:]]+'; then
  emit_guard "DROP TABLE/DATABASE/SCHEMA detected."
fi
if printf '%s\n' "$COMMAND" | awk '
  BEGIN { IGNORECASE=1; RS=";" }
  /DELETE[[:space:]]+FROM[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*/ {
    if ($0 !~ /WHERE/) { print "BAD"; exit }
  }
' | grep -q BAD; then
  emit_guard "DELETE FROM without a WHERE clause."
fi
if contains_icmd 'TRUNCATE[[:space:]]+TABLE'; then
  emit_guard "TRUNCATE TABLE detected."
fi

# ── chmod 777 / a+rwx: allowed silently (Greg, 2026-07-31) ───────────────

# ── curl|sh, raw-device writes, mkfs/dd → always deny ────────────────────
if contains_cmd '(curl|wget)[[:space:]].*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh|zsh|ksh|fish|dash|csh)([[:space:]]|$)'; then
  emit_deny "Piping downloaded content directly into a shell — classic attack vector."
fi
if printf '%s' "$COMMAND" | grep -qE '(^|[^0-9&])>[[:space:]]*/dev/[a-zA-Z][a-zA-Z0-9]*' \
   && ! printf '%s' "$COMMAND" | grep -qE '>[[:space:]]*/dev/(null|stdout|stderr|tty|zero|random|urandom)([[:space:]]|$)' ; then
  emit_deny "Redirection into a raw device file can destroy data."
fi
if contains_cmd '(^|[;&|[:space:]])(mkfs|mkfs\.[a-z0-9]+)([[:space:]]|$)' \
  || contains_cmd '(^|[;&|[:space:]])dd[[:space:]]+[^|]*(if|of)=/dev/[a-zA-Z]' ; then
  emit_deny "mkfs/dd against a device node — irreversible data loss."
fi

# ── HTTP write requests: allowed silently (Greg, 2026-07-31) ─────────────
# curl/wget/httpie POST/PUT/DELETE/PATCH no longer prompt; curl|sh stays denied above.

# ── Destructive local git → ask ──────────────────────────────────────────
if contains_git 'git[[:space:]]+reset[[:space:]]+--hard'; then
  emit_guard "git reset --hard discards uncommitted changes permanently."
fi
if contains_git 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'; then
  emit_guard "git clean -f permanently deletes untracked files."
fi

# ── Installing dependencies ──────────────────────────────────────────────
# Allowed silently in all modes (Greg, 2026-06-13): npm/pnpm/yarn/bun install,
# pip install, brew/cargo/gem/go install. Package PUBLISH stays hard-denied below.

# ── Package publishing → ask (was deny until 2026-07-31) ─────────────────
# Allow --dry-run variants (npm publish --dry-run is safe and common in CI).
publish_patterns=(
  '(npm|yarn|pnpm|bun)[[:space:]]+publish'
  'cargo[[:space:]]+publish'
  'gem[[:space:]]+push'
  'twine[[:space:]]+upload'
)
for pat in "${publish_patterns[@]}"; do
  if contains_cmd "$pat" && ! contains_cmd '(^|[[:space:]])(--dry-run|-n)([[:space:]=]|$)'; then
    emit_guard "Publishing a package to a registry."
  fi
done

exit 0
