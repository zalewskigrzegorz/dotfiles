# Quick sesh helpers from the nushell prompt.
#
# `s <name>` → sesh connect <name>           (direct jump, e.g. `s redocly`)
# `s`         → tv sesh picker → sesh connect (interactive)
# `sl`        → sesh list -i                  (peek at known sessions)
#
# Inside tmux you'd normally use the `prefix + f` popup (bin/sesh-picker);
# this is the equivalent from a raw shell prompt where the popup isn't available.

def --wrapped s [...rest: string] {
  let target = if ($rest | is-empty) {
    ^tv sesh | str trim -r -c "\n"
  } else {
    $rest | str join " "
  }
  if ($target | is-empty) { return }
  ^sesh connect $target
}

alias sl = ^sesh list -i
