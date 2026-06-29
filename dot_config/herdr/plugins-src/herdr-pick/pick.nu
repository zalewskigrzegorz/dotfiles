# herdr-pick — scan every pane's visible scrollback, fzf-pick a URL or file.
#   pick.nu url   → Enter opens the URL in the browser, ctrl-y copies it.
#   pick.nu file  → Enter opens the file in nvim (new tab via the `edit` entrypoint).
# Runs inside a herdr overlay pane (real TTY → fzf works). Reuses the regex logic
# from autoload/herdr-pick.nu but scans ALL panes, like the fzf-url plugin.

# Read the visible scrollback of every pane and join it into one blob.
def all_scrollback [] {
    let panes = (
        try { ^herdr pane list | from json | get -o result.panes | default [] } catch { [] }
    )
    $panes
    | each { |p| try { ^herdr pane read $p.pane_id --source visible --lines 500 } catch { "" } }
    | str join (char newline)
    | ansi strip
}

# Tiny pause so an error message is readable before the overlay closes.
def hold [msg: string] { print -e $msg; sleep 1200ms }

def pick_url [] {
    let urls = (
        all_scrollback
        | parse --regex r#'(https?://[^\s<>"'`)\]}]+)'#
        | get capture0
        | each { |u| $u | str trim --right --char '.' | str trim --right --char ',' | str trim --right --char ')' }
        | uniq
    )
    if ($urls | is-empty) { hold "herdr-pick: no URLs in any pane"; return }

    let out = (
        $urls | reverse | str join (char newline)
        | ^fzf --ansi --prompt "url> " --expect ctrl-y
        | lines
    )
    if ($out | is-empty) { return }
    let key = ($out | get -o 0 | default "")
    let sel = ($out | get -o 1 | default "" | str trim)
    if ($sel | is-empty) { return }

    if $key == "ctrl-y" {
        if (which pbcopy | is-not-empty) { $sel | ^pbcopy } else if (which wl-copy | is-not-empty) { $sel | ^wl-copy } else if (which xclip | is-not-empty) { $sel | ^xclip -selection clipboard } else { hold $"copied? no clipboard tool — ($sel)" }
    } else {
        if (which open | is-not-empty) { ^open $sel } else { ^xdg-open $sel }
    }
}

def pick_file [] {
    let files = (
        all_scrollback
        | parse --regex r#'([~\w./@-]*/[\w./@-]+)'#
        | get capture0
        | each { |t| $t | str trim --right --char ':' | str trim --right --char ')' | path expand }
        | uniq
        | where { |p| ($p | path exists) and (($p | path type) == "file") }
    )
    if ($files | is-empty) { hold "herdr-pick: no existing file paths in any pane"; return }

    let sel = ($files | reverse | str join (char newline) | ^fzf --prompt "file> " | str trim)
    if ($sel | is-empty) { return }

    # Hand off to the `edit` entrypoint: opens nvim in a new tab with PICK_FILE set.
    ^herdr plugin pane open --plugin greg.herdr-pick --entrypoint edit --placement tab --env $"PICK_FILE=($sel)" --focus
}

def main [mode: string] {
    match $mode {
        "url" => { pick_url }
        "file" => { pick_file }
        _ => { hold $"herdr-pick: unknown mode '($mode)'" }
    }
}
