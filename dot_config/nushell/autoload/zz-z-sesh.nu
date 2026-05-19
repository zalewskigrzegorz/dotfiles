# Wrap zoxide `z` so that inside tmux it switches sesh sessions instead of just
# `cd`-ing in place.
#
# Why: vendor `z` (vendor/autoload/zoxide.nu) is `cd <resolved>`. In tmux that
# only changes the shell's $PWD — the tmux session name (#S) and #{session_path}
# stay stale. So `z redocly` from a `dotfiles` session leaves you with $PWD =
# ~/Code/Redocly but #S still = `dotfiles`, and anything that reads the session
# name (statusline, agents launched via the tmux socket, hooks) runs in the
# wrong context. Leader+f via `sesh connect` avoids this — this wrapper just
# routes `z` through the same path.
#
# Outside tmux: defer to the vendor __zoxide_z (plain cd). `z -` and bare `z`
# also defer, so $OLDPWD/home behaviour is preserved.
#
# This file is named `zz-…` so it autoloads after `vendor/autoload/zoxide.nu`
# and shadows its `alias z = __zoxide_z` with a real def.

def --env --wrapped z [...rest: string] {
  # No tmux, no args, or `z -` → vendor behaviour
  if (($env.TMUX? | is-empty)
      or ($rest | is-empty)
      or ($rest == ['-'])) {
    __zoxide_z ...$rest
    return
  }

  # Resolve target: literal dir if it exists, else zoxide query
  let target = (match $rest {
    [ $arg ] if (($arg | path expand | path type) == 'dir') => {
      $arg | path expand
    }
    _ => {
      zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n"
    }
  })

  if ($target | is-empty) { return }

  # Bump zoxide rank (sesh connect won't trigger the PWD hook) and hand off.
  zoxide add -- $target
  ^sesh connect $target
}
