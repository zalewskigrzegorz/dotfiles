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
	notifPreviewPollMs = 3 * time.Second
	notifPreviewMaxLen = 60 // characters of body shown after the icon
	notifPreviewItem   = "notif_preview"
	// lastNotifWsFile holds the workspace name of the most recently pulsed
	// notification. `bin/aerospace-jump-to-notif` reads + deletes it so the
	// user can jump to the workspace that just got a notification.
	lastNotifWsFile = "/tmp/sketchybar-watcher-last-notif-ws"
)

type notifPreview struct {
	recID    int
	bundleID string
	title    string
	body     string
}

var (
	notifMu        sync.Mutex
	notifCurrent   *notifPreview
	lastShownRecID int // sticky after TTL — prevents re-showing the same notif
	notifEnabled   = true
	notifDBPath    string
	bundleToApp   = map[string]string{
		"com.tinyspeck.slackmacgap":            "Slack",
		"com.apple.MobileSMS":                  "Messages",
		"com.apple.mail":                       "Mail",
		"com.apple.iCal":                       "Calendar",
		"md.obsidian":                          "Obsidian",
		"com.readdle.smartemail-Mac":           "Spark Mail",
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

	// Notification dismissed (rec_id gone) → clear our preview if it matched.
	if latest == nil {
		if notifCurrent != nil {
			notifCurrent = nil
			pushClear()
		}
		return
	}
	// Already shown this notif? Keep showing — preview persists until the
	// macOS notification is dismissed (latest==nil branch above), the user
	// clicks the preview (Lua handler clears it locally), or focusing the
	// notif's workspace clears it (see clearNotifPreviewForWorkspace).
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
	App  string `plist:"app"`
	Date float64 `plist:"date"`
	Req  struct {
		Titl string `plist:"titl"`
		Body string `plist:"body"`
		Subt string `plist:"subt"`
	} `plist:"req"`
	Styl int `plist:"styl"`
}

func parseNotifBlob(b []byte) (title, body string, err error) {
	var n notifBlob
	_, err = plist.Unmarshal(b, &n)
	if err != nil {
		return "", "", err
	}
	title = strings.TrimSpace(n.Req.Titl)
	body = strings.TrimSpace(n.Req.Body)
	if n.Req.Subt != "" {
		body = strings.TrimSpace(n.Req.Subt) + ": " + body
	}
	return
}

func pushPreview(n *notifPreview) {
	appName := bundleToApp[n.bundleID]
	icon := ":default:"
	if appName != "" {
		icon = appIcon(appName)
	}
	text := n.body
	if text == "" {
		text = n.title
	}
	if len([]rune(text)) > notifPreviewMaxLen {
		text = string([]rune(text)[:notifPreviewMaxLen-1]) + "…"
	}
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
			}
		}
	}
	logDebug("notif_preview push: icon=%s body=%s bundle=%s", icon, text, n.bundleID)
	// icon uses sketchybar-app-font (set in Lua widget); label uses text font.
	// click_script: open the source app on click. The Lua `mouse.clicked`
	// handler ALSO fires and clears the item, so click both opens + dismisses.
	clickScript := ""
	if n.bundleID != "" {
		clickScript = "open -b " + n.bundleID
	}
	_ = exec.Command("sketchybar",
		"--set", notifPreviewItem,
		"icon="+icon,
		"label="+text,
		"drawing=on",
		"click_script="+clickScript,
	).Run()
}

func pushClear() {
	_ = os.Remove(lastNotifWsFile)
	_ = exec.Command("sketchybar",
		"--set", notifPreviewItem,
		"icon=",
		"label=",
		"drawing=off",
	).Run()
}

// clearNotifPreviewForWorkspace clears the preview when the user focuses the
// workspace that triggered the most recent notification — they've "seen" it.
// Called from main.go on workspace/focus events.
func clearNotifPreviewForWorkspace(ws string) {
	if ws == "" {
		return
	}
	data, err := os.ReadFile(lastNotifWsFile)
	if err != nil {
		return
	}
	if strings.TrimSpace(string(data)) != ws {
		return
	}
	notifMu.Lock()
	defer notifMu.Unlock()
	if notifCurrent != nil {
		notifCurrent = nil
	}
	pushClear()
}
