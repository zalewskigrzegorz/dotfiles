# demo-pr — template: play a short terminal flow with the keycast on, for a PR
# description.
#
# Use:
#   1. cp ~/.config/tuios/tapes/demo-pr.tape <scratch>/my-demo.tape and replace
#      the FLOW block. Or record the flow by hand (prefix+T r … prefix+T s, the
#      file lands in `tuios tape dir`) and paste its lines into FLOW.
#   2. tuios tape validate <scratch>/my-demo.tape
#   3. Start a CleanShot screen recording of the Ghostty window (tuios renders
#      no video), then, from the repo the demo is about:
#        tuios tape play --show-keys --theme mocha-neon <scratch>/my-demo.tape
#      Ctrl+P pauses. Quit with q when the "stop the recording" notice shows.
#   4. Each `Screenshot` saves the focused pane as a framed PNG under
#      ~/Pictures/tuios. For an SVG of one pane after the fact:
#        tuios screenshot -w demo --format svg --out <scratch>/demo.svg
#
# Rules that keep a replay honest: wait on output with WaitFor (match what
# only the output prints, not the typed command); Sleep only to give the
# viewer time to read.

EnableAnimations
EnableTiling
NewWindow "demo"
WaitFor pane "demo"
Sleep 1s

# --- FLOW: replace from here ---
Type@60ms "git log --oneline -3"
Sleep 400ms
Enter
WaitFor text "[0-9a-f]{7,} " in "demo" 10s
Sleep 1.5s
Screenshot
# --- FLOW end ---

Notify "demo done: stop the recording" info
