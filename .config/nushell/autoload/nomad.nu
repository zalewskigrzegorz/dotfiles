# Nomad - HashiCorp Nomad job management

# Completions: job IDs across all namespaces (needs NOMAD_TOKEN for live list).
def nu-complete-nomad-jobs [] {
    let fallback = ["api" "auth-server"]
    if ($env.NOMAD_TOKEN? == null or ($env.NOMAD_TOKEN | is-empty)) {
        $fallback
    } else {
        let r = (with-env {NOMAD_TOKEN: $env.NOMAD_TOKEN} {
            ^nomad job status -namespace '*' -json | complete
        })
        if $r.exit_code != 0 {
            $fallback
        } else {
            try {
                $r.stdout | from json | get ID
            } catch {
                $fallback
            }
        }
    }
}

def nu-complete-nomad-namespaces [] {
    let fallback = ["default" "api" "auth-server"]
    if ($env.NOMAD_TOKEN? == null or ($env.NOMAD_TOKEN | is-empty)) {
        $fallback
    } else {
        let r = (with-env {NOMAD_TOKEN: $env.NOMAD_TOKEN} {
            ^nomad namespace list -json | complete
        })
        if $r.exit_code != 0 {
            $fallback
        } else {
            try {
                $r.stdout | from json | get Name
            } catch {
                $fallback
            }
        }
    }
}

# Persisted token (0600). Env NOMAD_TOKEN overrides when set and non-empty.
def nomad-credentials-path [] {
    ($env.HOME | path join ".config" "nomad" "token")
}

def nomad-read-stored-token [] {
    let p = (nomad-credentials-path)
    if not ($p | path exists) {
        return null
    }
    try {
        let t = (open $p | into string | str trim)
        if ($t | is-empty) { null } else { $t }
    } catch {
        null
    }
}

def nomad-save-token [token: string] {
    let p = (nomad-credentials-path)
    let parent = ($p | path dirname)
    if not ($parent | path exists) {
        mkdir $parent
    }
    ($token | str trim) | save --force $p
    ^chmod 600 $p | complete
}

# Token: non-empty NOMAD_TOKEN, else file ~/.config/nomad/token
def nomad-resolve-token [] {
    if ($env.NOMAD_TOKEN? != null and not ($env.NOMAD_TOKEN | is-empty)) {
        $env.NOMAD_TOKEN
    } else {
        nomad-read-stored-token
    }
}

# Login to Nomad (basti on localhost). Saves token for reuse; optional browser open.
def nomad-login [] {
    let open_ans = (input "Open Nomad token page in browser? [Y/n]: ") | str trim | str downcase
    let open_browser = ($open_ans | is-empty) or $open_ans == "y" or $open_ans == "yes"
    if $open_browser {
        ^open http://localhost:4647/ui/settings/tokens
    }
    print "In the browser DevTools console: copy(localStorage.getItem('nomadTokenSecret'))"
    print "Then paste the token here (value only, no quotes)."
    let token = (input "Enter the token: ") | str trim
    if ($token | is-empty) {
        error make {msg: "Empty token; nothing saved."}
    }
    nomad-save-token $token
    print $"Token saved to (nomad-credentials-path) (0600). Export NOMAD_TOKEN to override."
    $token
}

# Remove stored token (still use NOMAD_TOKEN from env if set).
def nomad-token-forget [] {
    let p = (nomad-credentials-path)
    if ($p | path exists) {
        rm $p
        print $"Removed ($p)"
    } else {
        print "No stored Nomad token file."
    }
}
# Pull logs from all allocations of a Nomad job and save to temp file
# Saves logs as JSONL format for efficient querying
def nomad-pull-logs [
    job?: string@nu-complete-nomad-jobs = "api",  # Job name (Nomad job ID)
    --namespace (-n): string@nu-complete-nomad-namespaces = "api",  # Nomad namespace (CLI defaults to default; this matches former script behavior for api)
    --task (-t): string = "",  # Task name inside the group; empty => same as job name
    --output (-o): string = "/tmp/nomad-logs.jsonl"  # Output file path
] {
    # Change to the required directory
    cd /Users/greg/Code/Redocly/redocly
    
    # Set default environment if not present
    if ($env.NOMAD_ADDR? == null) {
        $env.NOMAD_ADDR = "http://localhost:4647"
    }
    
    # Token: env NOMAD_TOKEN, else ~/.config/nomad/token, else interactive login
    let initial_token = (nomad-resolve-token)
    let token = if ($initial_token == null or ($initial_token | is-empty)) {
        print "🔑 No Nomad token in env or stored file; login required..."
        let new_token = (nomad-login)
        $env.NOMAD_TOKEN = $new_token
        $new_token
    } else {
        $env.NOMAD_TOKEN = $initial_token
        $initial_token
    }

    # Check if we can connect to Nomad with the token
    let nomad_check = (with-env {NOMAD_TOKEN: $token} {
        nomad status | complete
    })
    
    let final_token = if ($nomad_check.exit_code != 0) {
        # Show the actual error
        let error_output = if ($nomad_check.stderr | is-empty) {
            $nomad_check.stdout
        } else {
            $nomad_check.stderr
        }
        
        # Exit code 126 usually means command not executable (e.g., asdf version not set)
        if ($nomad_check.exit_code == 126) {
            let error_msg = [
                "❌ Nomad command cannot be executed (exit code 126). This usually means:"
                "  - No version is set in asdf (try: asdf local nomad 1.8.2)"
                "  - Command permissions issue"
                ""
                $"Error output: ($error_output)"
            ] | str join (char newline)
            error make {msg: $error_msg}
        }
        
        # Exit code 1 might be auth issue, but let's show the error
        let exit_code_str = ($nomad_check.exit_code | into string)
        print ("⚠️  Nomad command failed (exit code " + $exit_code_str + "): " + $error_output)
        print "❌ Cannot connect to Nomad with current token, prompting for new token..."
        let new_token = (nomad-login)
        $env.NOMAD_TOKEN = $new_token
        
        # Verify new token works
        let nomad_check2 = (with-env {NOMAD_TOKEN: $new_token} {
            nomad status | complete
        })
        
        if ($nomad_check2.exit_code != 0) {
            let error_output2 = if ($nomad_check2.stderr | is-empty) {
                $nomad_check2.stdout
            } else {
                $nomad_check2.stderr
            }
            let exit_code2_str = ($nomad_check2.exit_code | into string)
            let error_msg = [
                "❌ Failed to connect to Nomad even with new token (exit code " + $exit_code2_str + ")."
                ""
                "Error: " + $error_output2
                ""
                "Please check:"
                "  - Your connection to Nomad server"
                "  - Token validity"
                "  - Nomad command availability (asdf version set?)"
            ] | str join (char newline)
            error make {msg: $error_msg}
        }
        $new_token
    } else {
        $token
    }

    # Set token in environment for subsequent commands
    $env.NOMAD_TOKEN = $final_token

    # Remove existing file if it exists
    if ($output | path exists) {
        rm $output
    }

    # Television cable emits "namespace/job"; plain job name uses -n/--namespace
    let job_segments = ($job | split row "/")
    let effective_job = if ($job_segments | length) > 1 {
        $job_segments | skip 1 | str join "/"
    } else {
        $job
    }
    let ns_flag = $namespace
    # ns/job form: single namespace. Otherwise try a few namespaces (avoids `job status -namespace '*'`
    # which can hang or run very long on big clusters).
    let namespaces_to_try = if ($job_segments | length) > 1 {
        [($job_segments | first)]
    } else {
        [$ns_flag $effective_job "default"] | reduce -f [] {|it, acc|
            if ($acc | any {|x| $x == $it}) { $acc } else { $acc | append $it }
        }
    }

    let task_name = if ($task | is-empty) { $effective_job } else { $task }

    print (
        "🔄 Pulling logs for job '" + $effective_job + "' (task " + $task_name + ")..."
    )

    let alloc_attempt = ($namespaces_to_try | reduce -f {ok: false, ns: "", result: null, err: ""} {|ns, acc|
        if $acc.ok {
            $acc
        } else {
            if ($namespaces_to_try | length) > 1 {
                print ("  … trying ns " + $ns + "...")
            }
            let r = (with-env {NOMAD_TOKEN: $final_token} {
                nomad job allocs -namespace $ns -json $effective_job | complete
            })
            if $r.exit_code == 0 {
                {ok: true, ns: $ns, result: $r, err: ""}
            } else {
                let msg = if ($r.stderr | is-empty) { $r.stdout } else { $r.stderr }
                {ok: false, ns: "", result: null, err: $msg}
            }
        }
    })

    if not $alloc_attempt.ok {
        error make {msg: $"❌ Error retrieving allocations: ($alloc_attempt.err)"}
    }

    let effective_namespace = $alloc_attempt.ns
    let allocs_result = $alloc_attempt.result

    print ("  ✓ using ns " + $effective_namespace)
    
    let allocations = ($allocs_result.stdout | from json)
    
    if ($allocations | is-empty) {
        print $"⚠️  No allocations found for job '($effective_job)'"
        return
    }

    let result = ($allocations | each { |alloc|
        print $"  📥 Getting logs from allocation ($alloc.ID | str substring 0..8)..."
        let log_lines = (with-env {NOMAD_TOKEN: $final_token} {
            nomad alloc logs -namespace $effective_namespace $alloc.ID $task_name | lines
        })

        let parsed_logs = ($log_lines | each { |line|
            try {
                let parsed = ($line | from json)
                {parsed: ($parsed | insert allocation_id $alloc.ID | insert node_name $alloc.NodeName), unparsable: false}
            } catch {
                {parsed: {
                    raw_log: $line,
                    allocation_id: $alloc.ID,
                    node_name: $alloc.NodeName,
                    level: null,
                    time: null,
                    context: "unparsable",
                    msg: $line,
                    _unparsable: true
                }, unparsable: true}
            }
        })

        {logs: ($parsed_logs | get parsed), unparsable_count: ($parsed_logs | where unparsable == true | length)}
    })

    let logs = ($result | get logs | flatten)
    let total_unparsable = ($result | get unparsable_count | math sum)

    # Save new logs
    $logs | each { |log| $log | to json -r } | save $output

    print $"✅ Saved ($logs | length) log entries to ($output)"
    if $total_unparsable > 0 {
        print $"⚠️  Warning: ($total_unparsable) log lines couldn't be parsed as JSON"
    }
}

# Query logs from previously saved Nomad logs file
# Use standard nushell filtering on the returned data
# Returns a normalized table where all records have consistent columns
def nomad-logs [
    --file (-f): string = "/tmp/nomad-logs.jsonl"  # Log file to query from
] {
    if not ($file | path exists) {
        error make {msg: $"❌ Log file ($file) does not exist. Run 'nomad-pull-logs' first."}
    }

    # Load and parse all log entries
    let records = (open $file | lines | each { |line|
        try {
            $line | from json
        } catch {
            null
        }
    } | compact)
    
    if ($records | is-empty) {
        return []
    }
    
    # Collect all unique column names from all records (more efficient)
    let all_columns = ($records | reduce -f [] { |record, acc|
        let record_cols = ($record | columns)
        $acc | append $record_cols | uniq
    })
    
    # Build defaults template with all columns set to null
    let defaults_template = ($all_columns | reduce -f {} { |col, acc|
        $acc | insert $col null
    })
    
    # Normalize all records: start with defaults (all columns), then merge record values
    $records | each { |record|
        $defaults_template | merge $record
    }
} 