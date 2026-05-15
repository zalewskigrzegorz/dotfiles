package main

import (
	"os/exec"
	"strings"
	"sync"
	"time"
)

// DockBadges returns a map of dock-app-name -> badge string (e.g. "3", "•").
// Cached for 2s to avoid spawning osascript on every refresh. Missing badges
// or unreadable Dock return an empty map (rendering falls back to no-badge).
//
// First invocation may trigger a macOS Accessibility prompt for System Events.

const badgeCacheTTL = 2 * time.Second

var (
	badgeCacheMu      sync.Mutex
	badgeCacheData    map[string]string
	badgeCacheExpires time.Time
)

// dockBadgeScript enumerates every Dock app and pulls AXStatusLabel.
// AXStatusLabel is `missing value` when no badge is set; only present labels are emitted.
const dockBadgeScript = `tell application "System Events" to tell process "Dock"
  set out to ""
  repeat with theItem in (UI elements of list 1)
    try
      set badge to value of attribute "AXStatusLabel" of theItem
      if badge is not missing value then
        set out to out & (name of theItem) & "|" & (badge as string) & linefeed
      end if
    end try
  end repeat
  return out
end tell`

func DockBadges() map[string]string {
	badgeCacheMu.Lock()
	if badgeCacheData != nil && time.Now().Before(badgeCacheExpires) {
		out := badgeCacheData
		badgeCacheMu.Unlock()
		return out
	}
	badgeCacheMu.Unlock()

	out, err := exec.Command("osascript", "-e", dockBadgeScript).Output()
	if err != nil {
		logDebug("DockBadges osascript: %v", err)
		return nil
	}
	badges := make(map[string]string)
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		idx := strings.Index(line, "|")
		if idx <= 0 {
			continue
		}
		app := strings.TrimSpace(line[:idx])
		badge := strings.TrimSpace(line[idx+1:])
		if app == "" || badge == "" {
			continue
		}
		badges[app] = badge
	}
	badgeCacheMu.Lock()
	badgeCacheData = badges
	badgeCacheExpires = time.Now().Add(badgeCacheTTL)
	badgeCacheMu.Unlock()
	return badges
}
