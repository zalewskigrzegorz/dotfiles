#!/usr/bin/env bash
# Table test for dot_claude/hooks/pre-tool-use/executable_block-credential-files.sh:
# fixture PreToolUse JSON on stdin → allow (no output) or deny.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
HOOK="$HERE/../../dot_claude/hooks/pre-tool-use/executable_block-credential-files.sh"
S=/private/tmp/claude-501/-Users-greg-Code-dotfiles/abc/scratchpad/secrets
fail=0

check() { # expect tool json
  got=$(printf '%s' "$3" | bash "$HOOK" | jq -r '.hookSpecificOutput.permissionDecision // empty')
  [ -n "$got" ] || got=allow
  [ "$got" = "$1" ] || { echo "FAIL [$2] expected $1, got $got"; fail=1; }
}
bash_case() { check "$1" "$2" "$(jq -n --arg c "$2" '{tool_name:"Bash",tool_input:{command:$c}}')"; }

bash_case allow "PGPASSWORD=\"\$(< $S/rds)\" psql -h localhost -U u main -c 'select 1' | head -5"
bash_case allow "docker exec -i pg psql -U u -d main < $S/pgpass"
bash_case allow "tuios popup --wait -- secret-in $S/rds"
bash_case allow "test -s $S/rds && echo ok"
bash_case allow "rm -f $S/rds"
bash_case deny  "cat $S/rds"
bash_case deny  "echo \"\$(< $S/rds)\""
bash_case deny  "cat < $S/rds"
bash_case deny  "head -c 3 $S/rds"
bash_case allow "ps -axo pid,etime,command | rg -i pg_dump"
bash_case allow "ps -p 123 -o etime="
bash_case deny  "ps -axE -o command="
bash_case deny  "ps eww 123"
bash_case deny  "ps -ef"
bash_case allow "x=\$(op read op://Dotfiles/A/password); curl -H \"x: \$x\" https://e.x"
bash_case allow "op read op://Dotfiles/A/password | wc -c"
bash_case allow "op read -o $S/tok op://Dotfiles/A/password"
bash_case allow "timeout 8 op read op://Dotfiles/A/password > /tmp/x"
bash_case deny  "op read op://Dotfiles/A/password"
bash_case deny  "env -u OP_SERVICE_ACCOUNT_TOKEN timeout 60 op read op://Work/B/password"
bash_case deny  "cat ~/.npmrc"
bash_case allow "rg -n 'op read' agent-rules"
check deny  "Read secrets file" "$(jq -n --arg p "$S/rds" '{tool_name:"Read",tool_input:{file_path:$p}}')"
check deny  "Grep secrets dir"  "$(jq -n --arg p "$S" '{tool_name:"Grep",tool_input:{pattern:"x",path:($p+"/")}}')"
check allow "Read other file"   "$(jq -n '{tool_name:"Read",tool_input:{file_path:"/Users/greg/Code/dotfiles/README.md"}}')"

[ "$fail" = 0 ] && echo PASS
exit "$fail"
