# Pick-and-open from the current tuios pane's scrollback.
# Run inside a tuios pane; reads THIS pane through the tuios daemon.
#   url   — pick a URL seen in the pane → open in the browser
#   of    — pick a file path seen in the pane → open in nvim
# (prefix+u / prefix+f label every pane's text instead; ctrl+label opens it.)

# Open a URL from the recent scrollback.
def url [] {
    let pane = ($env.TUIOS_PANE_ID? | default "")
    if ($pane | is-empty) { print "url: not inside a tuios pane"; return }
    let urls = (
        ^tuios capture-pane -w $pane --scrollback --lines 500
        | parse --regex r#'(https?://[^\s)>\]}"]+)'#
        | get capture0
        | uniq
    )
    if ($urls | is-empty) { print "url: no links in view"; return }
    let pick = ($urls | reverse | str join (char newline) | ^fzf --prompt "url> " | str trim)
    if ($pick | is-not-empty) { ^open $pick }
}

# Open a file path from the recent scrollback (relative paths resolve from $PWD).
def of [] {
    let pane = ($env.TUIOS_PANE_ID? | default "")
    if ($pane | is-empty) { print "of: not inside a tuios pane"; return }
    let files = (
        ^tuios capture-pane -w $pane --scrollback --lines 500
        | parse --regex r#'([~\w./@-]*/[\w./@-]+)'#
        | get capture0
        | each { |t| $t | str trim --right --char ':' | str trim --right --char ')' | str trim --right --char '.' | str trim --right --char ',' | path expand }
        | uniq
        | where { |p| ($p | path exists) and (($p | path type) == "file") }
    )
    if ($files | is-empty) { print "of: no file paths in view"; return }
    let pick = ($files | reverse | str join (char newline) | ^fzf --prompt "file> " | str trim)
    if ($pick | is-not-empty) { nvim $pick }
}
