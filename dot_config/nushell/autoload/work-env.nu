# Load private work identifiers (org/repo/team names) into the environment.
# Values live OUTSIDE the repo in ~/.local/state/dotfiles/secrets/work.env
# (bash-sourceable KEY=VALUE, restored from 1Password by `sync`), so the public
# dotfiles never name the employer. Consumers: bin/prs, bin/pr-watch,
# bin/pr-brief, bin/pr-watch-open, g-* skills.

let work_env_file = ($nu.home-dir | path join ".local/state/dotfiles/secrets/work.env")

if ($work_env_file | path exists) {
    open $work_env_file
    | lines
    | where {|l| ($l | str trim) != "" and not ($l | str trim | str starts-with "#") }
    | parse "{key}={value}"
    | update value {|row|
        $row.value
        | str trim --char '"'
        | str replace --all '$HOME' $nu.home-dir
    }
    | transpose --header-row --as-record
    | load-env
}
