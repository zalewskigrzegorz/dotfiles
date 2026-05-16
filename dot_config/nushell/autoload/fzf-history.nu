# Fast history search using Nushell history + fzf.
#
# Keybindings:
#   Ctrl+R — primary fzf history search over the full sqlite history.
#   (Television's nu-history channel filters poorly; Atuin's nu integration is still
#   broken upstream — atuinsh/atuin#2900 + #2820 — so fzf owns Ctrl+R for now.)

const history_limit = 20000

def fzf_history_candidates [] {
    history
    | last $history_limit
    | reverse
    | where {|row| ($row.command? | default "" | str trim | is-not-empty) }
    | uniq-by command
    | enumerate
    | each {|row|
        {
            index: $row.index,
            command: $row.item.command
        }
    }
}

def fzf_history_display_rows [candidates: list] {
    $candidates
    | each {|row|
        let display_command = ($row.command | str replace -a "\n" "\\n")
        $"($row.index)\t($display_command)"
    }
}

def fzf_history_pick [query: string] {
    let candidates = (fzf_history_candidates)

    if ($candidates | is-empty) {
        return ""
    }

    let result = (
        echo (fzf_history_display_rows $candidates | str join "\n")
        | fzf
            --height=80%
            --layout=reverse
            --border
            --prompt="history> "
            --scheme=history
            --delimiter="\t"
            --with-nth="2.."
            --nth="2.."
            --query $query
            --bind="ctrl-r:toggle-sort"
            --bind="ctrl-y:execute-silent(printf '%s' {2..} | pbcopy)+abort"
            --header="enter: use | ctrl-y: copy | ctrl-r: toggle sort | esc: cancel"
        | complete
    )

    if $result.exit_code == 0 {
        let selected_index = (
            $result.stdout
            | str trim --right
            | split row "\t"
            | first
            | into int
        )

        $candidates
        | where index == $selected_index
        | get command
        | first
    } else {
        ""
    }
}

def fzf_history_insert [] {
    let selected = (fzf_history_pick (commandline))

    if ($selected | is-not-empty) {
        commandline edit --replace $selected
        commandline set-cursor ($selected | str length)
    }
}

export-env {
    let existing_keybindings = ($env.config?.keybindings? | default [])
    let filtered_keybindings = (
        $existing_keybindings
        | where {|kb|
            let name = ($kb.name? | default "")
            not ($name | str starts-with "fzf_history")
        }
    )

    $env.config = (
        $env.config?
        | default {}
        | upsert keybindings (
            $filtered_keybindings
            | append [
                {
                    name: fzf_history_ctrl_r
                    modifier: control
                    keycode: char_r
                    mode: [emacs, vi_normal, vi_insert]
                    event: {
                        send: executehostcommand
                        cmd: "fzf_history_insert"
                    }
                }
            ]
        )
    )
}
