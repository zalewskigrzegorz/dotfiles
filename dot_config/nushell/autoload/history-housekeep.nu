# Keep the nushell sqlite history WAL from ballooning, which made fzf Ctrl+R
# (and the `history` builtin) miss recently-typed commands until a shell reload.
#
# Symptom: a 4MB+ history.sqlite3-wal next to a small main db. New rows live in
# WAL but stale reader connections in the same nu session don't see them.
#
# Fix: on every shell startup, force a TRUNCATE checkpoint so the WAL is empty
# and any subsequent reads hit the main db. Runs once per shell start, ~ms cost.
#
# Background reading: https://www.sqlite.org/wal.html#avoiding_excessively_large_wal_files

let history_db = if ($nu.os-info.name == "macos") {
    $"($env.HOME)/Library/Application Support/nushell/history.sqlite3"
} else {
    $"($env.HOME)/.local/share/nushell/history.sqlite3"
}

if ($history_db | path exists) {
    try {
        ^sqlite3 $history_db "PRAGMA wal_checkpoint(TRUNCATE);" out+err> /dev/null
    }
}
