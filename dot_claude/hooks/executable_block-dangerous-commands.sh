#!/usr/bin/env bash
# Blocks dangerous shell commands: push to protected branches, force push,
# destructive operations. PreToolUse hook for Bash operations.
# Exit 2 = block. Exit 0 = allow.
#
# Configurable via env:
#   CLAUDE_PROTECTED_BRANCHES  comma list (default: derived from git + main,master)

set -uo pipefail

emit_deny() {
  # Emit a JSON deny decision and exit 2.
  local reason="${1//\"/\\\"}"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 2
}

if ! command -v jq >/dev/null 2>&1; then
  emit_deny "jq is required for command protection hooks but is not installed."
fi

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$COMMAND" ] && exit 0

# ── Protected branch list ────────────────────────────────────────────────
DEFAULT_BRANCHES="main,master"
if GIT_DEFAULT=$(git config --get init.defaultBranch 2>/dev/null) && [ -n "$GIT_DEFAULT" ]; then
  DEFAULT_BRANCHES="$DEFAULT_BRANCHES,$GIT_DEFAULT"
fi
PROTECTED_BRANCHES="${CLAUDE_PROTECTED_BRANCHES:-$DEFAULT_BRANCHES}"
# Build a regex alternation: main|master|develop|...
BR_REGEX=$(printf '%s' "$PROTECTED_BRANCHES" | tr ',' '\n' | awk 'NF{printf "%s%s",sep,$0; sep="|"}')

contains_cmd() { printf '%s' "$COMMAND" | grep -qE "$1"; }
contains_icmd() { printf '%s' "$COMMAND" | grep -qiE "$1"; }

# ── Repo resolution helpers ─────────────────────────────────────────────
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

# ── Repo allowlists ─────────────────────────────────────────────────────
# Push allowlist: Claude may `git push` to a protected branch from these repos.
# Default: bazgroly (AI-doc destination, autopushed after every Write/Edit).
# Override: CLAUDE_PUSH_ALLOWLIST=path1,path2 (absolute paths to repo roots).
PUSH_ALLOWLIST="${CLAUDE_PUSH_ALLOWLIST:-$HOME/Code/personal/bazgroly}"

# Commit allowlist: Claude may `git commit` while HEAD is a protected branch here.
# Default: bazgroly + dotfiles + home-lab. Personal repos where master is the working branch.
# Override: CLAUDE_COMMIT_ALLOWLIST=path1,path2.
COMMIT_ALLOWLIST="${CLAUDE_COMMIT_ALLOWLIST:-$HOME/Code/personal/bazgroly,$HOME/Code/dotfiles,$HOME/Code/home-lab}"

# Manual-push repos: commits OK on master, but push blocked with "Greg pushes manually".
# Claude can iterate fast (commit), Greg reviews and pushes himself.
# Override: CLAUDE_MANUAL_PUSH_REPOS=path1,path2.
MANUAL_PUSH_REPOS="${CLAUDE_MANUAL_PUSH_REPOS:-$HOME/Code/dotfiles,$HOME/Code/home-lab}"

# ── Push classification ─────────────────────────────────────────────────
PUSH_ALLOWED=0
PUSH_MANUAL=0
if contains_cmd 'git[[:space:]]+push'; then
  PUSH_REPO_ROOT=$(resolve_target_repo "$COMMAND")
  if [ -n "$PUSH_REPO_ROOT" ]; then
    if path_in_list "$PUSH_REPO_ROOT" "$PUSH_ALLOWLIST"; then
      PUSH_ALLOWED=1
    elif path_in_list "$PUSH_REPO_ROOT" "$MANUAL_PUSH_REPOS"; then
      PUSH_MANUAL=1
    fi
  fi
fi

# ── Git push protections ────────────────────────────────────────────────
if [ "$PUSH_ALLOWED" -eq 0 ] && contains_cmd '(^|[;&|()]+[[:space:]]*)git[[:space:]]+push'; then
  if [ "$PUSH_MANUAL" -eq 1 ]; then
    DENY_PUSH="Blocked: Greg will push this manually after review. Commit only — no push from Claude in this repo."
  else
    DENY_PUSH="Blocked: pushing to a protected branch isn't allowed in this repo. Create a feature branch and open a PR."
  fi

  # Explicit refspec to a protected branch (origin main, :main, HEAD:main, remote branch)
  if contains_cmd "git[[:space:]]+push[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]*:)?($BR_REGEX)(\$|[[:space:]])"; then
    emit_deny "$DENY_PUSH"
  fi
  if contains_cmd "git[[:space:]]+push.*:($BR_REGEX)(\$|[[:space:]])"; then
    emit_deny "$DENY_PUSH"
  fi
  # Bare `git push` while on protected branch
  if contains_cmd 'git[[:space:]]+push[[:space:]]*($|[;&|])'; then
    CURRENT=$(git branch --show-current 2>/dev/null || true)
    if [ -n "$CURRENT" ] && printf '%s' ",$PROTECTED_BRANCHES," | grep -q ",$CURRENT,"; then
      emit_deny "$DENY_PUSH"
    fi
  fi
fi

# ── Git commit on a protected branch ────────────────────────────────────
# Block `git commit` (incl. --amend) when HEAD is on a protected branch and the
# repo isn't in COMMIT_ALLOWLIST. Forces branching in work repos before committing —
# saves having to repeat "create a branch first" in every conversation.
if contains_cmd '(^|[;&|()]+[[:space:]]*)git[[:space:]]+commit'; then
  COMMIT_REPO_ROOT=$(resolve_target_repo "$COMMAND")
  if [ -n "$COMMIT_REPO_ROOT" ]; then
    COMMIT_BRANCH=$(git -C "$COMMIT_REPO_ROOT" branch --show-current 2>/dev/null || true)
    if [ -n "$COMMIT_BRANCH" ] && printf '%s' ",$PROTECTED_BRANCHES," | grep -q ",$COMMIT_BRANCH,"; then
      if ! path_in_list "$COMMIT_REPO_ROOT" "$COMMIT_ALLOWLIST"; then
        emit_deny "Blocked: committing to protected branch '$COMMIT_BRANCH' isn't allowed in this repo. Create a feature branch first (\`git checkout -b <branch>\`) and commit there."
      fi
    fi
  fi
fi

# Force push protection always applies, even in allowlisted repos.
if contains_cmd '(^|[;&|()]+[[:space:]]*)git[[:space:]]+push' \
   && contains_cmd 'git[[:space:]]+push([[:space:]]+[^[:space:]]+)*[[:space:]]+(-[a-zA-Z]*f[a-zA-Z]*|--force)([[:space:]=]|$)' \
   && ! contains_cmd '\-\-force-with-lease'; then
  emit_deny "Blocked: force push is not allowed. Use --force-with-lease if you must overwrite remote."
fi

# ── Destructive filesystem operations ───────────────────────────────────
# rm -rf targeting root, home, $HOME, $VAR (any unresolved expansion), or parent traversal.
# We normalise quotes before matching so "my folder", '$HOME/trash', etc. Are all inspected.
CMD_NOQUOTE=$(printf '%s' "$COMMAND" | tr -d "'\"")
if printf '%s' "$CMD_NOQUOTE" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*[[:space:]]+)*-?[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+(/([[:space:]]|\*|$)|~|\$HOME|\$[A-Za-z_][A-Za-z0-9_]*|\.\./\.\.)' ; then
  emit_deny "Blocked: recursive force-delete on /, ~, \$HOME, an unresolved \$VAR, or .../.. Path. Specify a concrete safe target."
fi
# rm -rf /usr, /etc, /var, /bin, etc.
if printf '%s' "$CMD_NOQUOTE" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*-?[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*[[:space:]]+/(usr|etc|var|bin|sbin|lib|opt|root|boot)([[:space:]/]|$)'; then
  emit_deny "Blocked: recursive delete targeting a system directory."
fi

# ── Dangerous database operations ───────────────────────────────────────
# DROP TABLE|DATABASE|SCHEMA
if contains_icmd 'DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)[[:space:]]+'; then
  emit_deny "Blocked: DROP TABLE/DATABASE/SCHEMA detected. Run manually if intended."
fi
# DELETE FROM without a WHERE on the SAME statement.
# Split on ';' so multi-statement inputs are analysed per-statement.
if printf '%s\n' "$COMMAND" | awk '
  BEGIN { IGNORECASE=1; RS=";" }
  /DELETE[[:space:]]+FROM[[:space:]]+[A-Za-z_][A-Za-z0-9_.]*/ {
    if ($0 !~ /WHERE/) { print "BAD"; exit }
  }
' | grep -q BAD; then
  emit_deny "Blocked: DELETE FROM without a WHERE clause. Add a WHERE or run manually."
fi
if contains_icmd 'TRUNCATE[[:space:]]+TABLE'; then
  emit_deny "Blocked: TRUNCATE TABLE detected. Run manually if intended."
fi

# ── Dangerous system commands ───────────────────────────────────────────
# chmod: any world-writable/universal mode (0?777 or a+rwx)
if contains_cmd 'chmod([[:space:]]+-[a-zA-Z]+)*[[:space:]]+0?777([[:space:]]|$)' \
  || contains_cmd 'chmod([[:space:]]+-[a-zA-Z]+)*[[:space:]]+a\+rwx([[:space:]]|$)'; then
  emit_deny "Blocked: chmod 777 / a+rwx grants everyone full access. Use restrictive perms."
fi

# curl/wget piped to a shell
if contains_cmd '(curl|wget)[[:space:]].*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh|zsh|ksh|fish|dash|csh)([[:space:]]|$)'; then
  emit_deny "Blocked: piping downloaded content directly to a shell is dangerous."
fi

# Disk / partition. Note: only REDIRECTIONS to /dev/ are destructive. `2>/dev/null` is not.
# Pattern matches: `>[ ]*/dev/<something>` but NOT `2>/dev/null` or `&>/dev/null` style for fd-null.
# Strategy: match `>` optionally with whitespace, followed by /dev/<name>, EXCLUDING /dev/null and /dev/stderr/stdout.
if printf '%s' "$COMMAND" | grep -qE '(^|[^0-9&])>[[:space:]]*/dev/[a-zA-Z][a-zA-Z0-9]*' \
   && ! printf '%s' "$COMMAND" | grep -qE '>[[:space:]]*/dev/(null|stdout|stderr|tty|zero|random|urandom)([[:space:]]|$)' ; then
  emit_deny "Blocked: redirection into a raw device file can destroy data."
fi
if contains_cmd '(^|[;&|[:space:]])(mkfs|mkfs\.[a-z0-9]+)([[:space:]]|$)' \
  || contains_cmd '(^|[;&|[:space:]])dd[[:space:]]+[^|]*(if|of)=/dev/[a-zA-Z]' ; then
  emit_deny "Blocked: mkfs/dd against a device node. Irreversible data loss."
fi

# ── Destructive git ─────────────────────────────────────────────────────
if contains_cmd 'git[[:space:]]+reset[[:space:]]+--hard'; then
  emit_deny "Blocked: git reset --hard discards uncommitted changes permanently."
fi
if contains_cmd 'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'; then
  emit_deny "Blocked: git clean -f permanently deletes untracked files."
fi

# ── Accidental package publishing ───────────────────────────────────────
# Allow --dry-run variants (npm publish --dry-run is safe and common in CI).
publish_patterns=(
  '(npm|yarn|pnpm|bun)[[:space:]]+publish'
  'cargo[[:space:]]+publish'
  'gem[[:space:]]+push'
  'twine[[:space:]]+upload'
)
for pat in "${publish_patterns[@]}"; do
  if contains_cmd "$pat" && ! contains_cmd '(^|[[:space:]])(--dry-run|-n)([[:space:]=]|$)'; then
    emit_deny "Blocked: publishing packages should run in CI or manually, not via Claude."
  fi
done

exit 0
