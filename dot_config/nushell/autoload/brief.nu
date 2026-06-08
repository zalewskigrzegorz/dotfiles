# Daily-brief CLI — generate, list, or replay your morning briefings.
#
# `brief`         → fire a fresh brief (alias of `brief new`)
# `brief new`     → run the daily-brief skill via `claude -p /daily-brief`
# `brief ls`      → Television picker over saved briefs (preview = transcript, Enter = afplay)
# `brief help`    → print the cheat sheet
#
# Storage convention (set by the daily-brief skill):
#   ~/Documents/briefings/YYYY-MM-DD-HHMMSS-daily-brief.mp3
#   ~/Documents/briefings/YYYY-MM-DD-HHMMSS-daily-brief.txt  (same basename)
#
# Television channel: ~/.config/television/cable/briefs.toml
# (source: ~/Code/dotfiles/dot_config/television/cable/briefs.toml)

# Fire a fresh daily brief. Wraps the Claude Code skill `/daily-brief`,
# which uses Greg's Max OAuth (no API tokens), auto-fires TTS through Rick,
# and saves both mp3 + transcript under ~/Documents/briefings/.
def brief [] {
  ^claude -p "/daily-brief"
}

# Explicit form of `brief` — fire a fresh daily brief.
def "brief new" [] {
  ^claude -p "/daily-brief"
}

# Open a Television picker over saved briefs (channel: briefs). Preview shows
# the transcript that was saved alongside the mp3; pressing Enter plays the
# chosen mp3 via afplay (synchronous — Ctrl+C to stop).
def "brief ls" [] {
  let sel = (^tv briefs | str trim -r -c "\n")
  if ($sel | is-empty) { return }
  if not ($sel | path exists) {
    print -e $"brief ls: selected path does not exist: ($sel)"
    return
  }
  print $"▶ ($sel | path basename)"
  ^afplay $sel
}

# Print the brief cheat sheet.
def "brief help" [] {
  print "brief — daily-brief CLI"
  print ""
  print "  brief          fire a fresh brief (alias of `brief new`)"
  print "  brief new      run the daily-brief skill (claude -p /daily-brief)"
  print "  brief ls       Television picker over saved briefs"
  print "  brief help     this message"
  print ""
  print "Storage:"
  print "  ~/Documents/briefings/*.mp3    audio (auto-played on generate)"
  print "  ~/Documents/briefings/*.txt    transcript (preview in `brief ls`)"
  print ""
  print "Television channel: ~/.config/television/cable/briefs.toml"
}
