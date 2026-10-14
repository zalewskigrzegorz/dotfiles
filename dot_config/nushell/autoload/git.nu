# Git - Version control utilities

# Parse CODEOWNERS file
def parse-codeowners [] {
    open ($env.WORK_PROJECT_DIR | path join ".github/CODEOWNERS")
    | lines
    | each {|line| $line | split row "#" | first | str trim }
    | where {|line| not ($line | is-empty)}
    | each {|line|
        let parts = ($line | split row -r '\s+')
        let pattern = ($parts | first)
        let teams = ($parts | skip 1)
        {pattern: $pattern, regex: (codeowners-regex $pattern), teams: $teams}
    }
}

# Gitignore-style CODEOWNERS pattern as a regex: a pattern with a slash is anchored at the
# repo root, `*` stays inside one path segment, `**` crosses them, a trailing `/` means a directory.
def codeowners-regex [pattern: string] {
    let anchored = ($pattern | str starts-with "/") or ($pattern | str trim --right --char "/" | str contains "/")
    let trimmed = ($pattern | str trim --left --char "/")
    let dir_only = ($trimmed | str ends-with "/")
    let body = ($trimmed
        | str trim --right --char "/"
        | str replace -a -r '([.+^$(){}\[\]|\\])' '\$1'
        | str replace -a '**/' '<<ANYDIR>>'
        | str replace -a '**' '<<ANY>>'
        | str replace -a '*' '[^/]*'
        | str replace -a '?' '[^/]'
        | str replace -a '<<ANYDIR>>' '(?:.*/)?'
        | str replace -a '<<ANY>>' '.*')
    let prefix = if $anchored { '^' } else { '^(?:.*/)?' }
    let suffix = if $dir_only { '/.*$' } else { '(?:/.*)?$' }
    $prefix + $body + $suffix
}

# Pattern matching function for CODEOWNERS
def match-codeowners-pattern [file: string, regex: string] {
    $file =~ $regex
}

# Autocompletion function for PR identifiers
def "nu-complete-pr-identifiers" [] {
    try {
        gh pr list --json number,title,headRefName | from json | each { |pr|
            {
                value: ($pr.number | into string),
                description: $"PR #($pr.number): ($pr.title)"
            }
        }
    } catch {
        []
    }
}

# Check which teams need to review PR files based on CODEOWNERS
def check-team-review-files [
    pr_identifier?: string@"nu-complete-pr-identifiers"  # PR number, title, or branch name
] {
    # Auto-detect or parse PR number
    let pr_num = if ($pr_identifier | is-empty) {
        # Get current branch and find its PR
        let current_branch = (git branch --show-current)
        print $"🔍 Auto-detecting PR for branch: ($current_branch)"

        # Search for PR with this branch
        let prs = (gh pr list --head $current_branch --json number | from json)
        if ($prs | is-empty) {
            error make {msg: $"No PR found for branch ($current_branch)"}
        } else {
            ($prs | first | get number)
        }
    } else {
        # Try to parse as number first
        try {
            $pr_identifier | into int
        } catch {
            error make {msg: $"Invalid PR number: ($pr_identifier)"}
        }
    }

    # Get PR files  
    let pr_files = (gh api --paginate $"repos/($env.WORK_COMPANY)/($env.WORK_MAIN_PROJECT)/pulls/($pr_num)/files" --jq '.[].filename' | lines)

    # Get CODEOWNERS rules
    let codeowners_rules = (parse-codeowners)

    print $"🔍 Analyzing ($pr_files | length) files from PR #($pr_num)"
    print ""

    # Find matches for each file
    let matches = ($pr_files | each { |file|
        let file_matches = ($codeowners_rules | each { |rule|
            if (match-codeowners-pattern $file $rule.regex) {
                {
                    file: $file,
                    pattern: $rule.pattern,
                    teams: $rule.teams
                }
            } else {
                null
            }
        } | where $it != null)

        # The last matching line in CODEOWNERS wins, as on GitHub
        if ($file_matches | is-empty) {
            {file: $file, pattern: "no-match", teams: []}
        } else {
            $file_matches | last
        }
    })

    # Convert to unified table format
    $matches | each { |match|
        {
            file: $match.file,
            pattern: $match.pattern,
            teams: (if ($match.teams | is-empty) { "none" } else { $match.teams | str join ", " }),
            requires_review: (if ($match.teams | is-empty) { false } else { true })
        }
    }
} 