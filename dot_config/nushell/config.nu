# TODO find the way to track performance in autoload modules

$env.config = (
    $env.config
    | upsert history {
        max_size: 100000
        sync_on_enter: true
        file_format: "plaintext"
        isolation: false
    }
)

def __dotfiles_history_has_parse_error [command: string] {
    let tmp = (mktemp -t nu-history-check.XXXXXX)

    try {
        $command | save -f $tmp
        let check = (^nu --no-config-file --no-std-lib --ide-check 1 $tmp | complete)
        let has_error = ($check.stdout | str trim | is-not-empty)
        rm -f $tmp
        return $has_error
    } catch {
        rm -f $tmp
        return false
    }
}

def __dotfiles_prune_invalid_history_entry [] {
    if (($env.config.history.file_format? | default "plaintext") != "plaintext") {
        return
    }

    let history_path = $nu.history-path
    if not ($history_path | path exists) {
        return
    }

    let latest_history = (history | last 1)
    if ($latest_history | is-empty) {
        return
    }

    let command = ($latest_history | get command | first)
    if ($command | str trim | is-empty) {
        return
    }

    let is_parse_error = (__dotfiles_history_has_parse_error $command)

    if not $is_parse_error {
        return
    }

    let lines = (open --raw $history_path | lines)
    if ($lines | is-empty) {
        return
    }

    if (($lines | last) == $command) {
        if (($lines | length) == 1) {
            "" | save -f $history_path
        } else {
            (($lines | drop | str join "\n") + "\n") | save -f $history_path
        }
    }
}

let __dotfiles_history_filter_pid = ($nu.pid | into string)
if (($env.DOTFILES_HISTORY_FILTER_PID? | default "") != $__dotfiles_history_filter_pid) {
    $env.DOTFILES_HISTORY_FILTER_PID = $__dotfiles_history_filter_pid
    let existing_pre_prompt_hooks = ($env.config.hooks.pre_prompt? | default [])
    $env.config = (
        $env.config
        | upsert hooks.pre_prompt (
            $existing_pre_prompt_hooks
            | append [{|| __dotfiles_prune_invalid_history_entry }]
        )
    )
}
$env.config.hooks.command_not_found = null

source autoload/vim.nu
source autoload/pay-respects.nu

# Remove dist/build artifacts to fix rspack "Formatting argument out of range" panics
# (stale dist files can trigger the bug). Run from monorepo root.
def clean-build [] {
    print "Removing dist artifacts..."
    let dists = (glob "**/dist" --depth 5 | where { |p| ($p | path type) == "dir" })
    if ($dists | is-empty) {
        print "No dist folders found."
    } else {
        $dists | each { |d|
            rm -rf $d
            print $"  removed ($d)"
        }
    }
    print "Done ✓"
}
