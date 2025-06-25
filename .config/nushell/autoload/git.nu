# Git - Version control utilities

# Delete merged branches (excluding master/main)
def delete-branches [] {
  let branches = (git branch --merged | lines | where $it !~ '\*' | str trim | where $it != 'master' and $it != 'main')
  if ($branches | is-empty) {
    echo "No merged branches to delete."
  } else {
    echo "The following branches will be deleted:"
    echo $branches
    if (input "Are you sure you want to delete these branches? (y/n) ") == "y" {
      $branches | each { |it| git branch -d $it }
      echo "Branches deleted successfully."
    } else {
      echo "Operation cancelled."
    }
  }
}

# Parse CODEOWNERS file
def parse-codeowners [] {
    open ($env.WORK_PROJECT_DIR | path join ".github/CODEOWNERS")
    | lines
    | where {|line| not ($line | str trim | str starts-with "#") and not ($line | str trim | is-empty)}
    | each {|line|
        let parts = ($line | str trim | split row -r '\s+')
        let pattern = ($parts | first)
        let teams = ($parts | skip 1)
        {pattern: $pattern, teams: $teams}
    }
}

# Pattern matching function for CODEOWNERS
def match-codeowners-pattern [file: string, pattern: string] {
    # Remove leading slash from pattern for comparison
    let clean_pattern = if ($pattern | str starts-with "/") {
        $pattern | str substring 1..
    } else {
        $pattern
    }

    if ($clean_pattern | str ends-with "/**") {
        # Directory pattern like "apps/api/**"
        let dir_pattern = ($clean_pattern | str replace "/**" "/")
        $file | str starts-with $dir_pattern
    } else if ($clean_pattern | str ends-with "/*") {
        # Single level wildcard like "apps/api/*"
        let dir_pattern = ($clean_pattern | str replace "/*" "/")
        ($file | str starts-with $dir_pattern) and not ($file | str replace $dir_pattern "" | str contains "/")
    } else if ($clean_pattern | str contains "*") {
        # Other glob patterns like "*.md" or "apps/ui/**/*.tsx"
        let base_pattern = ($clean_pattern | str replace -a "*" "")
        $file | str contains $base_pattern
    } else {
        # Exact match or prefix match
        ($file == $clean_pattern) or ($file | str starts-with ($clean_pattern + "/"))
    }
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
    let pr_files = (gh api $"repos/($env.WORK_COMPANY)/($env.WORK_MAIN_PROJECT)/pulls/($pr_num)/files" | from json | get filename)

    # Get CODEOWNERS rules
    let codeowners_rules = (parse-codeowners)

    print $"🔍 Analyzing ($pr_files | length) files from PR #($pr_num)"
    print ""

    # Find matches for each file
    let matches = ($pr_files | each { |file|
        let file_matches = ($codeowners_rules | each { |rule|
            if (match-codeowners-pattern $file $rule.pattern) {
                {
                    file: $file,
                    pattern: $rule.pattern,
                    teams: $rule.teams
                }
            } else {
                null
            }
        } | where $it != null)

        # Get the most specific match (longest pattern)
        if ($file_matches | is-empty) {
            {file: $file, pattern: "no-match", teams: []}
        } else {
            # Sort by pattern length to get most specific match
            $file_matches | sort-by { |x| $x.pattern | str length } | last
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