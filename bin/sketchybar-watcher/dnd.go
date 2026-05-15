package main

// E2: macOS DND/Focus detection has no clean public API in 2026 — Apple's
// `~/Library/DoNotDisturb/DB/Assertions.json` only stores invalidation
// history (not active state), `notifyutil -g com.apple.do-not-disturb`
// returns 0 even when DND is on, and Control Center menu bar items expose
// no human-readable description. So we expose a manual subcommand that
// flips the in-memory state via the watcher socket:
//
//   sketchybar-watcher dnd on     # tell watcher DND is active
//   sketchybar-watcher dnd off    # tell watcher DND is inactive
//   sketchybar-watcher dnd toggle # flip current state
//
// Bind via Raycast script, aerospace keybind, or Shortcuts. The watcher dims
// the apple icon (E2 visual) and suppresses notif_preview pushes (E5
// interaction) when state=on.

// handleDNDEvent updates the dnd state on the watcher and triggers a refresh.
// "toggle" handling is done client-side via two socket calls is impractical
// (no read-back), so toggle is handled here against current state.
func handleDNDEvent(st *state, action string) {
	st.mu.Lock()
	cur := st.dndActive
	switch action {
	case "on", "1", "true":
		st.dndActive = true
	case "off", "0", "false":
		st.dndActive = false
	case "toggle":
		st.dndActive = !cur
	}
	new := st.dndActive
	st.mu.Unlock()
	logDebug("dnd %s -> %v", action, new)
	scheduleRefresh(st)
}
