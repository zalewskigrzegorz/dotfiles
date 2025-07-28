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
    # Set default environment if not present
    if ($env.NOMAD_ADDR? == null) {
        $env.NOMAD_ADDR = "http://localhost:4647"
    }
    if ($env.NOMAD_TOKEN? == null) {
        let token = (nomad-login)
        $env.NOMAD_TOKEN = $token
    }

    # Check if we can connect to Nomad
    let nomad_check = (nomad status | complete)
    print $"Debug: exit_code is ($nomad_check.exit_code)"
    
    if ($nomad_check.exit_code != 0) {
        print "❌ Cannot connect to Nomad"
        let token = (nomad-login)
        
        # Use with-env to ensure the environment variable is available for external commands
        with-env {NOMAD_TOKEN: $token} {
            let nomad_check2 = (nomad status | complete)
            print $"Debug: with-env check exit_code is ($nomad_check2.exit_code)"
        }
    }

    # Remove existing file if it exists
    if ($output | path exists) {
        rm $output
    }

    print $"🔄 Pulling logs for job '($job)' from Nomad..."

    # Get all allocations and their logs
    let result = (nomad job allocs -namespace api -json $job | from json | each { |alloc|
        print $"  📥 Getting logs from allocation ($alloc.ID | str substring 0..8)..."
        let log_lines = (nomad alloc logs -namespace api $alloc.ID api | lines)

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
def nomad-logs [
    --file (-f): string = "/tmp/nomad-logs.jsonl"  # Log file to query from
] {
    if not ($file | path exists) {
        error make {msg: $"❌ Log file ($file) does not exist. Run 'nomad-pull-logs' first."}
    }

    # Load and parse all log entries
    open $file | lines | each { |line|
        try {
            $line | from json
        } catch {
            null
        }
    } | compact
} 