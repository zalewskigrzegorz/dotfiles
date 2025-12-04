# Nomad - HashiCorp Nomad job management

# Login to nomad connected via basti on localhost.
def nomad-login [] {
  # open browser on http://localhost:4647/ui/settings/tokens
  ^open http://localhost:4647/ui/settings/tokens
  echo "Please login to Nomad and copy the token with this command"
  echo "copy(localStorage.getItem('nomadTokenSecret'))"
  "copy(localStorage.getItem('nomadTokenSecret'))" | pbcopy
  echo "The command has been copied to your clipboard!"
  echo "Paste it in the browser console and paste the result below"
  let token = (input "Enter the token: ")
  echo $"NOMAD_TOKEN will be set to ($token)"
  $token
}
# Pull logs from all allocations of a Nomad job and save to temp file
# Saves logs as JSONL format for efficient querying
def nomad-pull-logs [
    job?: string = "api",  # Job name to get logs from (defaults to "api")
    --output (-o): string = "/tmp/nomad-logs.jsonl"  # Output file path
] {
    # Change to the required directory
    cd /Users/greg/Code/Redocly/redocly
    
    # Set default environment if not present
    if ($env.NOMAD_ADDR? == null) {
        $env.NOMAD_ADDR = "http://localhost:4647"
    }
    
    # Get or prompt for token
    let initial_token = $env.NOMAD_TOKEN?
    let token = if ($initial_token == null or ($initial_token | is-empty)) {
        print "🔑 No NOMAD_TOKEN found, prompting for login..."
        let new_token = (nomad-login)
        $env.NOMAD_TOKEN = $new_token
        $new_token
    } else {
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
        print $"⚠️  Nomad command failed (exit code " + $exit_code_str + "): " + $error_output
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

    print $"🔄 Pulling logs for job '($job)' from Nomad..."

    # Get all allocations and their logs
    let allocs_result = (with-env {NOMAD_TOKEN: $final_token} {
        nomad job allocs -namespace api -json $job | complete
    })
    
    if ($allocs_result.exit_code != 0) {
        let error_msg = if ($allocs_result.stderr | is-empty) {
            $allocs_result.stdout
        } else {
            $allocs_result.stderr
        }
        error make {msg: $"❌ Error retrieving allocations: ($error_msg)"}
    }
    
    let allocations = ($allocs_result.stdout | from json)
    
    if ($allocations | is-empty) {
        print $"⚠️  No allocations found for job '($job)'"
        return
    }

    let result = ($allocations | each { |alloc|
        print $"  📥 Getting logs from allocation ($alloc.ID | str substring 0..8)..."
        let log_lines = (with-env {NOMAD_TOKEN: $final_token} {
            nomad alloc logs -namespace api $alloc.ID api | lines
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