package main

import (
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unicode"

	"howett.net/plist"
)

// notif_preview polls macOS NotificationCenter's sqlite DB every notifPreviewPollMs
// and surfaces the newest delivered notification on a sketchybar item named
// `notif_preview`. The user can read incoming DMs without opening Notification
// Center; the item auto-clears after notifPreviewTTL or when the underlying
// notification is dismissed (poll detects absence).
//
// Schema reference (macOS 14+):
//   ~/Library/Group Containers/group.com.apple.usernoted/db2/db
//   record(rec_id, app_id, uuid, data BLOB, delivered_date, presented, ...)
//   app(app_id, identifier, badge)
//
// data BLOB is a binary plist: { app, date, req: { titl, body, ... }, ... }
//
// Resilience: if schema changes or DB is locked, set enabled=false and stop.

const (
	notifPreviewPollMs        = 3 * time.Second
	notifPreviewItem          = "notif_preview"
	notifPreviewBarChars      = 30 // compact label cap — same on every display because sketchybar mirrors items to all bars
	notifPreviewPopupLines    = 4
	notifPreviewPopupLineChrs = 60 // soft wrap width per popup row
	// lastNotifWsFile holds the workspace name of the most recently pulsed
	// notification. `bin/aerospace-jump-to-notif` reads + deletes it so the
	// user can jump to the workspace that just got a notification.
	lastNotifWsFile = "/tmp/sketchybar-watcher-last-notif-ws"
)

type notifPreview struct {
	recID     int
	bundleID  string
	title     string
	body      string
	workspace string // aerospace workspace that received the pulse, if any
}

var (
	notifMu        sync.Mutex
	notifCurrent   *notifPreview
	lastShownRecID int // sticky — prevents re-showing the same notif
	notifEnabled   = true
	notifDBPath    string
	bundleToApp   = map[string]string{
		"com.tinyspeck.slackmacgap":            "Slack",
		"com.apple.MobileSMS":                  "Messages",
		"com.apple.mail":                       "Mail",
		"com.apple.iCal":                       "Calendar",
		"md.obsidian":                          "Obsidian",
		"com.readdle.smartemail-Mac":           "Spark Mail",
		"com.readdle.sparkdesktop-setapp":      "Spark Mail",
		"com.readdle.sparkdesktop":             "Spark Mail",
		"com.apple.facetime":                   "FaceTime",
		"com.apple.reminders":                  "Reminders",
		"notion.id":                            "Notion",
		"discord":                              "Discord",
		"com.hnc.Discord":                      "Discord",
		"com.spotify.client":                   "Spotify",
		"com.anthropic.claudefordesktop":       "Claude",
		"com.canarymail.canarymail":            "Canary Mail",
		"com.colliderli.iina":                  "VLC",
		"com.google.Chrome":                    "Google Chrome",
		"info.eurocomp.timing-setapp.timinghelper": "Timing",
		"io.sevendegrees.juicy-setapp":         "Juicy",
	}
)

func startNotifPreview(st *state) {
	notifDBPath = filepath.Join(homeDir, "Library/Group Containers/group.com.apple.usernoted/db2/db")
	go func() {
		for {
			if !notifEnabled {
				return
			}
			tick(st)
			time.Sleep(notifPreviewPollMs)
		}
	}()
}

func tick(st *state) {
	_ = st
	latest, err := newestNotification()
	if err != nil {
		logDebug("notif_preview: %v", err)
		// First-error tolerance: only disable on repeated failures, not transient locks.
		return
	}
	notifMu.Lock()
	defer notifMu.Unlock()

	// macOS auto-dismisses notifications quickly when the source app is
	// foregrounded (Ghostty with Claude inside fires Stop hook → notif →
	// notif gone from sqlite within a tick or two). Per memory rule
	// `feedback_notif_preview_no_ttl`, the chip MUST persist until the user
	// explicitly acknowledges (click, workspace focus, or new notif replacing).
	// So when sqlite reports `latest == nil`, we DO NOTHING — keep showing.
	// The chip is cleared only by:
	//   - the Lua click_script (in items/widgets/notif_preview.lua)
	//   - clearNotifPreviewForWorkspace() on aerospace workspace focus
	//   - a strictly newer recID arriving (handled below)
	if latest == nil {
		return
	}
	// Already shown this notif? Keep showing — preview persists until user
	// explicitly dismisses (see comment above).
	if latest.recID <= lastShownRecID {
		return
	}
	// Genuinely new notification — replace and push.
	notifCurrent = latest
	lastShownRecID = latest.recID
	pushPreview(latest)
}

func newestNotification() (*notifPreview, error) {
	out, err := exec.Command("sqlite3", "-readonly", "-separator", "\t", notifDBPath,
		"SELECT record.rec_id, app.identifier, hex(record.data) FROM record JOIN app ON record.app_id = app.app_id ORDER BY record.delivered_date DESC LIMIT 1").Output()
	if err != nil {
		return nil, fmt.Errorf("sqlite3: %w", err)
	}
	line := strings.TrimSpace(string(out))
	if line == "" {
		return nil, nil
	}
	parts := strings.SplitN(line, "\t", 3)
	if len(parts) != 3 {
		return nil, fmt.Errorf("malformed row: %q", line)
	}
	var recID int
	fmt.Sscanf(parts[0], "%d", &recID)
	bundleID := parts[1]
	blob, err := hex.DecodeString(parts[2])
	if err != nil {
		return nil, fmt.Errorf("hex decode: %w", err)
	}
	title, body, err := parseNotifBlob(blob)
	if err != nil {
		// On schema drift, disable so we don't crash-loop.
		log.Printf("notif_preview: blob parse failed (%v) — disabling", err)
		notifEnabled = false
		return nil, err
	}
	return &notifPreview{
		recID:    recID,
		bundleID: bundleID,
		title:    title,
		body:     body,
	}, nil
}

type notifBlob struct {
	App  interface{} `plist:"app"`
	Date float64     `plist:"date"`
	Req  struct {
		Titl interface{} `plist:"titl"`
		Body interface{} `plist:"body"`
		Subt interface{} `plist:"subt"`
	} `plist:"req"`
	Styl int `plist:"styl"`
}

// notifFieldToString coerces an arbitrary plist value into a single string.
// macOS sometimes encodes notification text fields as an array of strings
// (e.g. multi-line bodies) rather than a single string — the original decoder
// typed them as `string` and a type-mismatch killed the poller. This helper
// keeps the decoder resilient across format drifts.
func notifFieldToString(v interface{}) string {
	switch x := v.(type) {
	case nil:
		return ""
	case string:
		return x
	case []interface{}:
		parts := make([]string, 0, len(x))
		for _, e := range x {
			s := notifFieldToString(e)
			if s != "" {
				parts = append(parts, s)
			}
		}
		return strings.Join(parts, " ")
	default:
		return fmt.Sprintf("%v", x)
	}
}

func parseNotifBlob(b []byte) (title, body string, err error) {
	var n notifBlob
	_, err = plist.Unmarshal(b, &n)
	if err != nil {
		return "", "", err
	}
	title = strings.TrimSpace(notifFieldToString(n.Req.Titl))
	body = strings.TrimSpace(notifFieldToString(n.Req.Body))
	if subt := strings.TrimSpace(notifFieldToString(n.Req.Subt)); subt != "" {
		body = subt + ": " + body
	}
	return
}

func pushPreview(n *notifPreview) {
	appName := bundleToApp[n.bundleID]
	// E4 trigger: pulse the workspace running this app, if any.
	if appName != "" && globalState != nil {
		if windows, err := getWindowsByWorkspace(); err == nil {
			var pulsed []string
		find:
			for ws, apps := range windows {
				for _, a := range apps {
					if a == appName {
						pulsed = []string{ws}
						break find
					}
				}
			}
			if len(pulsed) > 0 {
				go animatePulse(pulsed, globalState)
				_ = os.WriteFile(lastNotifWsFile, []byte(pulsed[0]), 0644)
				n.workspace = pulsed[0]
			}
		}
	}
	renderPreview(n)
}

// wrapLines word-wraps text to `maxLines` rows of up to `lineLen` runes.
// Words longer than lineLen get hard-broken. The last visible row is suffixed
// with "…" if there's leftover content; any unused rows return empty strings.
func wrapLines(text string, lineLen, maxLines int) []string {
	out := make([]string, maxLines)
	runes := []rune(text)
	pos, row := 0, 0
	for row < maxLines && pos < len(runes) {
		end := pos + lineLen
		if end >= len(runes) {
			out[row] = string(runes[pos:])
			pos = len(runes)
			row++
			break
		}
		// Word-boundary backoff: scan back for whitespace within this row.
		brk := end
		for brk > pos && !unicode.IsSpace(runes[brk]) {
			brk--
		}
		if brk == pos {
			brk = end // no whitespace found — hard break
		}
		out[row] = strings.TrimSpace(string(runes[pos:brk]))
		pos = brk
		// Skip leading whitespace for next row.
		for pos < len(runes) && unicode.IsSpace(runes[pos]) {
			pos++
		}
		row++
	}
	// Append ellipsis on the last filled row if content remains.
	if pos < len(runes) && row > 0 {
		last := out[row-1]
		// Make room for "…" if the row is at capacity.
		lastRunes := []rune(last)
		if len(lastRunes) >= lineLen {
			lastRunes = lastRunes[:lineLen-1]
		}
		out[row-1] = string(lastRunes) + "…"
	}
	return out
}

// renderPreview pushes the current notif to sketchybar: the compact bar item
// gets a single-line truncated label; the popup gets up to N word-wrapped
// rows of the full body. Background/style are re-pushed every time because
// Lua --reload doesn't always re-apply geometry on items that started with
// drawing=false.
func renderPreview(n *notifPreview) {
	appName := bundleToApp[n.bundleID]
	icon := ":default:"
	if appName != "" {
		icon = appIcon(appName)
	}
	// Compose label as "title — body" so calendar/event reminders show the
	// event name alongside the time. Falls back to whichever field exists
	// when only one is populated (e.g. some apps put everything in title).
	var full string
	switch {
	case n.title != "" && n.body != "":
		full = n.title + " — " + n.body
	case n.title != "":
		full = n.title
	default:
		full = n.body
	}
	short := full
	if len([]rune(short)) > notifPreviewBarChars {
		short = string([]rune(short)[:notifPreviewBarChars-1]) + "…"
	}
	lines := wrapLines(full, notifPreviewPopupLineChrs, notifPreviewPopupLines)
	logDebug("notif_preview push: icon=%s short=%s lines=%d", icon, short, len(lines))
	// Route the click through claude-notif-chip-click. For Claude-waiting
	// banners (title contains "▸") it switches to the waiting tmux session;
	// for every other notification it falls back to `open -b <bundle>`.
	clickScript := "/Users/greg/Code/dotfiles/bin/claude-notif-chip-click " + n.bundleID
	args := []string{
		"--set", notifPreviewItem,
		"icon=" + icon,
		"label=" + short,
		"width=dynamic",
		"scroll_texts=off",
		"background.color=0xff1e1e2e",   // Mocha Neon bg1
		"background.border_color=0xffff80bf", // Mocha Neon pink (per-widget semantic: alerts)
		"background.border_width=1",
		"background.height=26",         // match bracketed widget group
		"drawing=on",
		"click_script=" + clickScript,
	}
	for i, line := range lines {
		args = append(args, "--set", fmt.Sprintf("%s.popup.line%d", notifPreviewItem, i+1), "label="+line)
	}
	_ = exec.Command("sketchybar", args...).Run()
}

// rehydrateNotifPreview re-pushes the current notif. Called when Lua signals
// that sketchybar finished loading its config (sketchybar_ready event) —
// a reload resets every item's geometry/drawing, so without a re-push the
// preview stays invisible even though the watcher still tracks the notif.
func rehydrateNotifPreview() {
	notifMu.Lock()
	defer notifMu.Unlock()
	if notifCurrent != nil {
		renderPreview(notifCurrent)
	}
}

func pushClear() {
	_ = os.Remove(lastNotifWsFile)
	args := []string{
		"--set", notifPreviewItem,
		"icon=",
		"label=",
		"width=dynamic",
		"scroll_texts=off",
		"drawing=off",
		"popup.drawing=off",
	}
	for i := 1; i <= notifPreviewPopupLines; i++ {
		args = append(args, "--set", fmt.Sprintf("%s.popup.line%d", notifPreviewItem, i), "label=")
	}
	_ = exec.Command("sketchybar", args...).Run()
}

// clearNotifPreviewForWorkspace clears the preview when the user focuses the
// workspace that triggered the most recent notification — they've "seen" it.
// Called from main.go on workspace/focus events. Uses the in-memory
// notifCurrent.workspace (not lastNotifWsFile) because aerospace-jump-to-notif
// consumes the file on ctrl-n before the workspace event reaches us.
func clearNotifPreviewForWorkspace(ws string) {
	if ws == "" {
		return
	}
	notifMu.Lock()
	defer notifMu.Unlock()
	if notifCurrent == nil || notifCurrent.workspace != ws {
		return
	}
	notifCurrent = nil
	pushClear()
}
