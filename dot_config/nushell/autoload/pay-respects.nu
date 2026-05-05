def __pr_base [mode: string, command: string] {
    if (which pay-respects | is-empty) {
        return ""
    }

    let alias = (
        help aliases
        | select name expansion
        | each {|row| $row.name + "=" + $row.expansion }
        | str join (char nl)
    )
    let prompt_indicator = ($env.PROMPT_INDICATOR? | default "")
    let prefix = if ($prompt_indicator | is-not-empty) {
        $env.PROMPT_INDICATOR
    } else if (($env.PROMPT_COMMAND? | default null) != null) {
        do $env.PROMPT_COMMAND
    } else {
        ""
    }

    with-env {
        _PR_MODE: $mode
        _PR_PREFIX: $prefix
        _PR_LAST_COMMAND: $command
        _PR_ALIAS: $alias
        _PR_SHELL: nu
    } {
        let result = (^pay-respects | complete)
        if $result.exit_code == 0 {
            $result.stdout
        } else {
            ""
        }
    }
}

export def --env respect [] {
    __pr_main noconfirm respect
}

export def --env __pr_main [mode: string, trigger: string = ""] {
    let command = (__pr_last_command $trigger)
    if ($command | str trim | is-empty) {
        return
    }

    let output = (__pr_base $mode $command)
    if ($output | str trim | is-empty) {
        return
    }

    let wrapped = ('[' + ($output | str replace -r '}\s*{' '},{') + ']')
    let data = (try { $wrapped | from json } catch { null })
    if $data == null {
        return
    }

    for d in $data {
        if ($d.command != "") {
            if $env.config.history.file_format == "plaintext" {
                $"($d.command)\n" | save --append $nu.history-path
            } else {
                [$d.command] | history import
            }

            print $"pay-respects: ($d.command)"
            print "press Up then Enter to run it, or use Ctrl+X before Enter next time"
        }

        if ($d.cd != "") {
            cd $d.cd
        }
    }
}

def __pr_last_command [trigger: string] {
    let candidates = (
        history
        | reverse
        | where {|entry|
            let command = ($entry.command | str trim)
            (($command | is-not-empty) and (($trigger | is-empty) or ($command != $trigger)) and not ($command | str starts-with "__pr_main"))
        }
    )

    if ($candidates | is-empty) {
        return ""
    }

    $candidates | first | get command
}

export def __pr_inline [] {
    let input = (commandline)
    let output = (__pr_base inline $input)

    if ($output | is-not-empty) {
        commandline edit --replace $output
    }
}

export-env {
    let __pr_pid = ($nu.pid | into string)
    if (($env.PAY_RESPECTS_NU_PID? | default "") != $__pr_pid) {
        $env.PAY_RESPECTS_NU_PID = $__pr_pid
        $env.config.keybindings = (
            $env.config.keybindings
            | where {|kb| ($kb.name? | default "") != "__pr_inline" }
            | append [{
                name: __pr_inline
                modifier: control
                keycode: char_x
                mode: [emacs, vi_normal, vi_insert]
                event: {
                    send: executehostcommand
                    cmd: "__pr_inline"
                }
            }]
        )
    }
}
