# workctl-picker-test — TUI regression test for the workctl branch picker.
#
# The picker must not offer a branch checked out in another worktree, the root
# checkout included: picking `main` there once ended in a raw JSON error
# (.claude/rules/workctl-gh-dash.md). This builds a throwaway repo whose root
# checkout is on main, with one other branch, opens `workctl`, types "main" and
# waits for fzf's counter to read 0/1: nothing matches, the one row left is
# feat/other. A `main` row, or a "create main" row, makes it 1/2 or 2/3 and
# the WaitFor fails the tape on that line.
#
# Run:   tuios tape play ~/.config/tuios/tapes/workctl-picker-test.tape
#        (prefix+r runs it in the current session too; it closes its window)
# Pass:  a green "workctl-picker-test: PASS" notification.
# Fail:  the progress indicator says FAILED; quit with q and `tape play`
#        exits non-zero naming the line.
# Touches only /tmp/tuios-tape-workctl. Esc leaves the picker, so no worktree
# is ever created.

DisableAnimations
EnableTiling
NewWindow "workctl-test"
WaitFor pane "workctl-test"

# sh -c: the pane's shell is nushell. fsmonitor off, or every test run leaks a
# git fsmonitor daemon on the scratch repo.
Run "sh -c 'rm -rf /tmp/tuios-tape-workctl && mkdir -p /tmp/tuios-tape-workctl && cd /tmp/tuios-tape-workctl && git init -q -b main --bare origin.git && git init -q -b main work && cd work && git config core.fsmonitor false && git commit -q --allow-empty -m init && git remote add origin ../origin.git && git push -q -u origin main && git remote set-head origin main && git branch feat/other && echo setup-$((40+2))'"
WaitFor text "setup-42" in "workctl-test" 30s

Run "cd /tmp/tuios-tape-workctl/work; workctl"
WaitFor text "feat/other" in "workctl-test" 30s

# fzf draws the rows before its start:reload settles; keys sent sooner are lost.
Sleep 1s
Type@80ms "main"
WaitFor text "[^0-9]0/1( |$)" in "workctl-test" 10s

Escape
Run "cd /tmp; rm -rf /tmp/tuios-tape-workctl"
CloseWindow "workctl-test"
Notify "workctl-picker-test: PASS" success
