# Pick-and-open from the current herdr pane's scrollback — the herdr-native
# replacement for the old tmux fzf-url-picker (prefix u) and open-file-window
# (prefix F/H/G). Run inside a herdr pane; reads THIS pane via the herdr socket.
#   url   — pick a URL seen in the pane → open in the browser
#   of    — pick a file path seen in the pane → open in nvim

# Open a URL from the visible scrollback.
def url [] {
    let pane = ($env.HERDR_PANE_ID? | default "")
    if ($pane | is-empty) { print "url: not inside a herdr pane"; return }
    let urls = (
        ^herdr pane read $pane --source recent --lines 500
        | parse --regex r#'(https?://[^\s)>\]}"]+)'#
        | get capture0
        | uniq
    )
    if ($urls | is-empty) { print "url: no links in view"; return }
    let pick = ($urls | reverse | str join (char newline) | ^fzf --prompt "url> " | str trim)
    if ($pick | is-not-empty) { ^open $pick }
}

# Open a file path from the visible scrollback (relative paths resolve from $PWD).
def of [] {
    let pane = ($env.HERDR_PANE_ID? | default "")
    if ($pane | is-empty) { print "of: not inside a herdr pane"; return }
    let files = (
        ^herdr pane read $pane --source recent --lines 500
        | parse --regex r#'([~\w./@-]*/[\w./@-]+)'#
        | get capture0
        | each { |t| $t | str trim --right --char ':' | str trim --right --char ')' | path expand }
        | uniq
        | where { |p| ($p | path exists) and (($p | path type) == "file") }
    )
    if ($files | is-empty) { print "of: no file paths in view"; return }
    let pick = ($files | reverse | str join (char newline) | ^fzf --prompt "file> " | str trim)
    if ($pick | is-not-empty) { nvim $pick }
}
