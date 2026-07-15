# reaper.nu — hunt heavy dev processes + Docker containers across ALL your worktrees
# and kill the ones you pick from an fzf checklist. Cross-platform: macOS + the
# Debian lab both run nushell.
#
# Why: with many git worktrees (`work new` → ~/Code/tree/wt-<repo>/, herdr native
# → ~/.herdr/worktrees/<repo>/, plus ad-hoc dirs) a leftover vite / tsc / eslint /
# jest — or a forgotten Docker container — keeps chewing CPU in a dir you're no
# longer sitting in. `pm2 log` can't see them; they're scattered across dirs.
# reaper gathers every heavy dev process (sampled *current* CPU, not lifetime avg),
# shows CPU% / RSS / uptime / working dir, and lets you multi-select what to kill.
#
#   reaper                 scan → fzf checklist (Tab marks, Enter kills) → SIGTERM
#   reaper --min-cpu 5     only rows over 5% CPU
#   reaper --report (-r)   print the table only, kill nothing
#   reaper --hard          SIGKILL / `docker kill` instead of TERM / `docker stop`
#
#   reap-mcp               non-interactive: kill LEAKED stdio MCP docker containers
#   reap-mcp --dry         list what it would kill, kill nothing
#     Every Claude/Cursor session spawns `docker run --rm -i <mcp image>` servers.
#     On an unclean exit (herdr pane closed, crash, kill -9) --rm never fires and
#     the container is orphaned, chewing CPU forever. reap-mcp targets MCP-image
#     containers with Docker's auto-generated `<adjective>_<name>` names (the
#     stdio spawns) and spares anything you named yourself (e.g. a shared
#     long-running `mcp-grafana-shared`). Hook-friendly.

# argv patterns that count as a "dev process". node matches everything that runs
# through it (vite/eslint/tsc/next/…), the rest catch native/binary tools.
const DEV_PATTERN = '(?i)(\bnode\b|\bdeno\b|\bbun\b|vite|esbuild|rollup|webpack|turbo|next(-server)?|nuxt|remix|astro|\btsc\b|tsserver|ts-node|\btsx\b|eslint|prettier|biome|\bjest\b|vitest|mocha|cypress|playwright|karma|nodemon|\bpm2\b|concurrently|storybook|\bnx\b|watchman|\bnpm\b|pnpm|yarn)'

# ~/foo instead of /Users/greg/foo, then keep it short enough for the column.
def reap-short-dir [p: string]: nothing -> string {
    let h = ($env.HOME | default "")
    let s = (if ($h != "" and ($p | str starts-with $h)) {
        $"~($p | str substring ($h | str length)..)"
    } else { $p })
    if (($s | str length) > 34) { $"…($s | str substring (($s | str length) - 33)..)" } else { $s }
}

# pid -> current working directory, for the matched pids only. Batched lsof on
# macOS, /proc readlink on Linux.
def reap-cwds [pids: list<int>]: nothing -> record {
    if ($pids | is-empty) { return {} }
    if $nu.os-info.name == "macos" {
        let out = (do { ^lsof -a -d cwd -Fpn -p ($pids | str join ",") } | complete)
        if $out.exit_code != 0 { return {} }
        mut cur = ""
        mut acc = {}
        for line in ($out.stdout | lines) {
            if ($line | str starts-with "p") {
                $cur = ($line | str substring 1..)
            } else if ($line | str starts-with "n") and ($cur != "") {
                $acc = ($acc | upsert $cur ($line | str substring 1..))
            }
        }
        $acc
    } else {
        $pids | reduce --fold {} {|pid, acc|
            let r = (do { ^readlink -f $"/proc/($pid)/cwd" } | complete)
            if $r.exit_code == 0 {
                $acc | upsert ($pid | into string) ($r.stdout | str trim)
            } else { $acc }
        }
    }
}

# The tool.
export def reaper [
    --min-cpu: float = 0.0   # hide rows below this CPU%
    --report (-r)            # print the table, kill nothing
    --hard                   # SIGKILL / docker kill instead of TERM / docker stop
] {
    # --- processes: current CPU + RSS from nu's sampled ps, args + uptime from system ps
    let procs = (ps | select pid ppid name cpu mem)
    let meta = (
        ^ps -Ao pid=,etime=,args=
        | lines
        | each {|l| $l | str trim }
        | parse -r '(?<pid>\d+)\s+(?<etime>\S+)\s+(?<args>.+)'
    )

    let matched = (
        $procs
        | each {|p|
            let m = ($meta | where pid == ($p.pid | into string))
            let args = (if ($m | is-empty) { $p.name } else { ($m | first | get args) })
            let etime = (if ($m | is-empty) { "?" } else { ($m | first | get etime) })
            { pid: $p.pid, cpu: $p.cpu, mem: $p.mem, etime: $etime, args: $args }
        }
        | where {|r| $r.args =~ $DEV_PATTERN }
        | where cpu >= $min_cpu
        | sort-by cpu --reverse
    )

    let cwds = (reap-cwds ($matched | get pid))

    let proc_rows = (
        $matched | each {|r|
            let dir = ($cwds | get -o ($r.pid | into string) | default "?")
            {
                key: $"p:($r.pid)"
                cpu_disp: $"($r.cpu | math round --precision 1)%"
                mem_disp: ($r.mem | into string)
                etime: $r.etime
                dir: (reap-short-dir $dir)
                cmd: ($r.args | str substring 0..90)
            }
        }
    )

    # --- docker containers (any that are up)
    let docker_rows = (
        if (which docker | is-not-empty) {
            let r = (do { ^docker ps --format '{{.ID}}||{{.Names}}||{{.Image}}||{{.Status}}' } | complete)
            if $r.exit_code == 0 {
                $r.stdout | lines | where {|l| ($l | str trim) != "" } | each {|l|
                    let f = ($l | split row "||")
                    {
                        key: $"d:($f.0)"
                        cpu_disp: "docker"
                        mem_disp: "—"
                        etime: ($f | get -o 3 | default "")
                        dir: "container"
                        cmd: $"($f | get -o 2 | default '') ($f | get -o 1 | default '')"
                    }
                }
            } else { [] }
        } else { [] }
    )

    let rows = ($proc_rows | append $docker_rows)

    if ($rows | is-empty) {
        print "reap: nothing heavy running (no dev processes or docker containers matched)."
        return
    }

    # --- report-only: pretty table, no kill
    if $report {
        print ($rows | select cpu_disp mem_disp etime dir cmd | rename CPU RSS UPTIME DIR COMMAND | table)
        return
    }

    # --- build aligned fzf lines: "<key>\t<visible cols>"; fzf hides field 1.
    let lines = (
        $rows | each {|r|
            let visible = ([
                ($r.cpu_disp | fill --alignment right --width 7)
                ($r.mem_disp | fill --alignment right --width 10)
                ($r.etime    | fill --alignment right --width 12)
                ($r.dir      | fill --alignment left  --width 35)
                $r.cmd
            ] | str join "  ")
            $"($r.key)\t($visible)"
        }
    )

    if (which fzf | is-empty) {
        print "reap: fzf not found — showing report instead."
        print ($rows | select cpu_disp mem_disp etime dir cmd | rename CPU RSS UPTIME DIR COMMAND | table)
        return
    }

    let header = ($"    CPU        RSS       UPTIME  DIR                                  COMMAND")
    let picked = (
        $lines | str join "\n"
        | ^fzf --multi --delimiter "\t" --with-nth "2.."
            --header $header
            --prompt "reap (Tab to mark)> "
            --height "80%" --border --reverse
        | complete
    )

    if $picked.exit_code != 0 or ($picked.stdout | str trim) == "" {
        print "reap: nothing selected."
        return
    }

    let keys = ($picked.stdout | lines | where {|l| ($l | str trim) != "" } | each {|l| $l | split row "\t" | first })

    for k in $keys {
        let parts = ($k | split row ":")
        let kind = $parts.0
        let id = $parts.1
        if $kind == "d" {
            let r = (do { if $hard { ^docker kill $id } else { ^docker stop $id } } | complete)
            if $r.exit_code == 0 { print $"killed docker ($id)" } else { print $"FAILED docker ($id): ($r.stderr | str trim)" }
        } else {
            let sig = (if $hard { "-9" } else { "-15" })
            let r = (do { ^kill $sig $id } | complete)
            if $r.exit_code == 0 { print $"killed pid ($id) (($sig))" } else { print $"FAILED pid ($id): ($r.stderr | str trim)" }
        }
    }
}

# MCP docker images whose stdio spawns leak on unclean session exit.
const MCP_IMAGE_PATTERN = '(?i)(mcp-grafana|cloudwatch-mcp-server|/mcp[-/]|mcp/)'
# Docker's auto-generated container names look like `serene_bardeen` — two
# lowercase words joined by a single underscore, nothing else. Anything you
# --name yourself (mcp-grafana-shared, my_stack_1, …) won't match, so it's spared.
const DOCKER_AUTONAME_PATTERN = '^[a-z]+_[a-z]+$'

# Kill leaked stdio MCP docker containers (orphaned by unclean Claude/Cursor
# exits). Non-interactive — safe to wire into a Stop hook or run on a schedule.
export def reap-mcp [--dry] {
    if (which docker | is-empty) {
        print "reap-mcp: docker not found."
        return
    }
    let r = (do { ^docker ps --format '{{.ID}}||{{.Names}}||{{.Image}}||{{.Status}}' } | complete)
    if $r.exit_code != 0 {
        print $"reap-mcp: docker ps failed: ($r.stderr | str trim)"
        return
    }
    let leaked = (
        $r.stdout | lines | where {|l| ($l | str trim) != "" } | each {|l|
            let f = ($l | split row "||")
            { id: $f.0, name: ($f | get -o 1 | default ""), image: ($f | get -o 2 | default ""), status: ($f | get -o 3 | default "") }
        }
        | where {|c| $c.image =~ $MCP_IMAGE_PATTERN }
        | where {|c| $c.name =~ $DOCKER_AUTONAME_PATTERN }
    )
    if ($leaked | is-empty) {
        print "reap-mcp: no leaked MCP containers."
        return
    }
    if $dry {
        print "reap-mcp --dry — would kill:"
        print ($leaked | select name image status | table)
        return
    }
    for c in $leaked {
        let k = (do { ^docker kill $c.id } | complete)
        if $k.exit_code == 0 { print $"reaped ($c.name) (($c.image))" } else { print $"FAILED ($c.name): ($k.stderr | str trim)" }
    }
    print $"reap-mcp: reaped ($leaked | length) leaked MCP container(s)."
}
