# chezmoi wrapper — strip macOS Tahoe libsystem_malloc spam from stderr.
#
# Background: macOS 26.x prints `nu(PID) MallocStackLogging: can't turn off
# malloc stack logging because it was not enabled.` on every nu subprocess
# exit. nushell 0.113.1 has no fix yet. The baseline env var in env.nu.tmpl
# catches most cases; this wrapper is the belt-and-suspenders for chezmoi
# specifically — it spawns enough short-lived helpers during apply that the
# warning leaks through in rare cases.
#
# Implementation: buffer stderr via `complete`, filter the noise line, re-emit
# stdout verbatim and cleaned stderr. Preserves exit code. Buffers output, so
# you see results after the command finishes — fine for chezmoi (usually fast).

def --wrapped chezmoi [...rest] {
    let r = (do { ^chezmoi ...$rest } | complete)
    if not ($r.stdout | is-empty) {
        print -n $r.stdout
    }
    let clean_err = (
        $r.stderr
        | lines
        | where {|l| not ($l | str contains "MallocStackLogging:")}
        | str join (char nl)
    )
    if not ($clean_err | is-empty) {
        print -e $clean_err
    }
    if $r.exit_code != 0 {
        exit $r.exit_code
    }
}
