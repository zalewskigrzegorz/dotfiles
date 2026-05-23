// sketchybar-watcher is a daemon that drives sketchybar from Aerospace events
// and kindaVim state. It listens on a Unix socket for workspace/focus/service
// events, polls kindaVim's environment.json for mode changes, fetches Dock
// notification badges, and watches macOS Focus mode + the NotificationCenter
// sqlite DB for the on-bar notification preview.
package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// Injected at build time via -ldflags '-X main.version=... -X main.buildTime=...'
var (
	version   = "dev"
	buildTime = "unknown"
)

const (
	socketPath       = "/tmp/sketchybar-watcher.sock"
	workspaceCount   = 10
	kindavimEnvFile  = "Library/Application Support/kindaVim/environment.json"
	debounceMs       = 50         // A1: coalesce rapid focus/workspace events
	kindavimPollMs   = 300        // A4: mtime-gated, full read is now rare
	kindavimIdleMs   = 2000       // poll less often when kindaVim not running
	windowCacheTTLMs = 150        // A3: TTL for `aerospace list-windows`
	retryDelayMs     = 500        // B3: base backoff
	retryMaxAttempts = 3          // B3: bounded retry
	readinessMaxMs   = 15000      // B2: max wait for sketchybar items to exist (cold boot needs more headroom)
	readinessStepMs  = 50         // B2: initial probe interval
	recentLRUSize    = 3          // E3: recent-workspace LRU
	pulseDurationMs  = 600        // E4: app-launch pulse
)

var (
	debug        = flag.Bool("debug", false, "verbose logging")
	showVersion  = flag.Bool("version", false, "print version and exit")
	homeDir      string
	kindavimPath string
	globalState  *state // set in main(); used by notif_preview to fire pulses
)

var workspaceOrder = []string{
	"chat", "term", "code", "misc", "notes", "web", "media", "test", "mail", "mac",
}

// Workspace icon colors — Mocha Neon palette (matches dot_config/sketchybar/colors.lua + spaces.lua).
// Was Dracula palette pre-2026-05-23 which read as pastel/wrong-theme on the bar.
var workspaceColors = map[string]string{
	"chat":  "0xff50fa7b", // green bumped
	"web":   "0xff8be9fd", // sky bumped
	"term":  "0xffff8c42", // peach bumped
	"code":  "0xffff80bf", // pink bumped
	"media": "0xffff6b9d", // red bumped
	"test":  "0xffffd700", // gold bumped
	"misc":  "0xff9580ff", // lavender (was pastel grey)
	"notes": "0xff50fa7b", // green
	"mail":  "0xffff6b9d", // red bumped
	"mac":   "0xff8be9fd", // blue/sky (was off-white pastel)
}

// Named tokens — Mocha Neon. Active workspace = colorMauve to match the
// primary border accent used in chips and aerospace/borders.
const (
	colorMauve       = "0xffb347ff" // electric purple — primary Mocha Neon accent
	colorPurple      = "0xff9580ff" // lavender
	colorMagenta     = "0xffff80bf" // pink bumped
	colorYellow      = "0xffffd700" // gold bumped (was Dracula 0xffffff80)
	colorRed         = "0xffff6b9d" // red bumped (was Dracula 0xffff9580)
	colorGrey        = "0xff7f849c" // overlay1 (was Dracula 0xff7970a9)
	colorCyan        = "0xff8be9fd" // sky bumped (was Dracula 0xff80ffea)
	colorTransparent = "0x00000000"
	colorDim         = "0x60" // alpha prefix used when E3 dims a workspace
)

type state struct {
	mu               sync.Mutex
	focusedWorkspace string
	focusedDisplay   int      // aerospace monitor-id (1=DELL, 2=Built-in, 3=C34H89x); 0=unknown
	recentWorkspaces []string // E3: most-recent first, max recentLRUSize
	serviceMode      bool
	vimMode          string // N, I, V, C, R or ""
	debounceTimer    *time.Timer
	retryAttempt     int               // B3
	prevBadges       map[string]string // E4: previous per-app Dock badges for notification-arrival diff
}

func (s *state) setFocusedDisplay(d int) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.focusedDisplay = d
}

func (s *state) getFocusedDisplay() int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.focusedDisplay
}

func (s *state) snapshot() (focused string, recent []string, svc bool, vim string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	focused = s.focusedWorkspace
	recent = append([]string(nil), s.recentWorkspaces...)
	svc = s.serviceMode
	vim = s.vimMode
	return
}

func (s *state) setFocused(ws string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if ws == "" || ws == s.focusedWorkspace {
		return
	}
	s.focusedWorkspace = ws
	// E3: push to front of recent LRU
	out := []string{ws}
	for _, w := range s.recentWorkspaces {
		if w == ws {
			continue
		}
		out = append(out, w)
		if len(out) >= recentLRUSize {
			break
		}
	}
	s.recentWorkspaces = out
}

func (s *state) setServiceMode(v bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.serviceMode = v
}

func (s *state) setVimMode(v string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.vimMode = v
}

func (s *state) getVimMode() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.vimMode
}

// E4: diff previous per-app Dock badges vs new ones. Return list of workspaces
// where any app gained a new badge OR an existing badge changed (notification
// arrived). This pulses workspaces for incoming notifications, not for new
// windows — more useful in practice (new windows are usually intentional, but
// new notifications are easy to miss).
func (s *state) diffBadges(newBadges map[string]string, windowsByWs windowSet) []string {
	s.mu.Lock()
	defer s.mu.Unlock()
	wsSet := make(map[string]bool)
	for app, badge := range newBadges {
		prev, had := s.prevBadges[app]
		changed := false
		if s.prevBadges == nil {
			changed = false // skip first-tick "all new" noise
		} else if !had {
			changed = true // new badge appeared
		} else if prev != badge {
			changed = true // badge value changed (e.g. count went up)
		}
		if !changed {
			continue
		}
		// Locate which workspace this app lives in.
		for ws, apps := range windowsByWs {
			for _, a := range apps {
				if a == app {
					wsSet[ws] = true
				}
			}
		}
	}
	s.prevBadges = newBadges
	out := make([]string, 0, len(wsSet))
	for ws := range wsSet {
		out = append(out, ws)
	}
	return out
}

func logDebug(format string, args ...interface{}) {
	if *debug {
		log.Printf("[watcher] "+format, args...)
	}
}

func runCmd(name string, args ...string) ([]byte, error) {
	return exec.Command(name, args...).Output()
}

func runAerospace(args ...string) ([]byte, error) {
	return runCmd("aerospace", args...)
}

// ---- window cache (A3) ----

type windowSet map[string][]string // workspace -> apps

var (
	windowCacheMu     sync.Mutex
	windowCacheData   windowSet
	windowCacheExpiry time.Time
)

type windowInfo struct {
	Workspace string `json:"workspace"`
	AppName   string `json:"app-name"`
}

func getWindowsByWorkspace() (windowSet, error) {
	windowCacheMu.Lock()
	if windowCacheData != nil && time.Now().Before(windowCacheExpiry) {
		out := windowCacheData
		windowCacheMu.Unlock()
		return out, nil
	}
	windowCacheMu.Unlock()

	out, err := runAerospace("list-windows", "--all", "--format", "%{workspace}%{app-name}", "--json")
	if err != nil {
		return nil, err
	}
	var list []windowInfo
	if err := json.Unmarshal(out, &list); err != nil {
		return nil, err
	}
	byWs := make(windowSet)
	for _, w := range list {
		if w.Workspace == "" || w.AppName == "" || w.AppName == "kindaVim" {
			continue
		}
		byWs[w.Workspace] = append(byWs[w.Workspace], w.AppName)
	}

	windowCacheMu.Lock()
	windowCacheData = byWs
	windowCacheExpiry = time.Now().Add(windowCacheTTLMs * time.Millisecond)
	windowCacheMu.Unlock()
	return byWs, nil
}

func invalidateWindowCache() {
	windowCacheMu.Lock()
	windowCacheExpiry = time.Time{}
	windowCacheMu.Unlock()
}

func getFocusedWorkspace() (string, error) {
	out, err := runAerospace("list-workspaces", "--focused")
	if err != nil {
		return "", err
	}
	lines := strings.Split(strings.TrimSpace(string(out)), "\n")
	if len(lines) == 0 {
		return "", nil
	}
	return strings.TrimSpace(lines[0]), nil
}

// ---- kindaVim (A4: mtime-gated polling) ----

func readKindavimMode() string {
	data, err := os.ReadFile(kindavimPath)
	if err != nil {
		return ""
	}
	var m struct {
		Mode string `json:"mode"`
	}
	if json.Unmarshal(data, &m) != nil {
		return ""
	}
	switch m.Mode {
	case "normal":
		return "N"
	case "insert":
		return "I"
	case "visual":
		return "V"
	case "command":
		return "C"
	case "replace":
		return "R"
	}
	return ""
}

func kindavimPoller(st *state) {
	interval := kindavimIdleMs * time.Millisecond
	lastMode := ""
	var lastMtime time.Time
	for {
		out, err := runCmd("pgrep", "-x", "kindaVim")
		running := err == nil && len(out) > 0
		if running {
			interval = kindavimPollMs * time.Millisecond
			// A4: only re-read JSON if mtime changed
			fi, statErr := os.Stat(kindavimPath)
			if statErr == nil && fi.ModTime() != lastMtime {
				lastMtime = fi.ModTime()
				mode := readKindavimMode()
				if mode != lastMode {
					lastMode = mode
					st.setVimMode(mode)
					scheduleRefresh(st)
				}
			}
		} else {
			if lastMode != "" {
				lastMode = ""
				lastMtime = time.Time{}
				st.setVimMode("")
				scheduleRefresh(st)
			}
			interval = kindavimIdleMs * time.Millisecond
		}
		time.Sleep(interval)
	}
}

// ---- workspace label rendering (uses C-restored badges + E1 window counts) ----

func buildWorkspaceLabels(windowsByWs windowSet, badges map[string]string) []string {
	labels := make([]string, workspaceCount)
	for i, ws := range workspaceOrder {
		apps := windowsByWs[ws]
		var parts []string
		for _, appName := range apps {
			icon := appIcon(appName)
			badge := ""
			if badges != nil {
				badge = badgeFor(appName, badges)
			}
			if badge != "" {
				parts = append(parts, " "+icon+badge)
			} else {
				parts = append(parts, " "+icon)
			}
		}
		// E1: window-count badge skipped — sketchybar-app-font has no ascii
		// digits/brackets, renders as tofu. Count is implicit in icon count.
		if len(parts) == 0 {
			labels[i] = " —"
		} else {
			labels[i] = strings.Join(parts, "")
		}
	}
	return labels
}

// E3: workspace is "dim" if it's NOT focused AND NOT in the recent-LRU.
func isRecent(ws string, recent []string) bool {
	for _, r := range recent {
		if r == ws {
			return true
		}
	}
	return false
}

// dimColor blends a 0xAARRGGBB color with reduced alpha for E3 dimming.
// We replace the alpha byte (positions 2-3 after "0x") with colorDim's hex pair.
func dimColor(c string) string {
	if len(c) < 4 || !strings.HasPrefix(c, "0x") {
		return c
	}
	return "0x" + strings.TrimPrefix(colorDim, "0x") + c[4:]
}

// ---- sketchybar push ----

func pushToSketchybar(labels []string, focused string, recent []string, svc bool, vim string) error {
	args := make([]string, 0, 256)
	for i := 1; i <= workspaceCount; i++ {
		ws := workspaceOrder[i-1]
		selected := ws == focused
		color := workspaceColors[ws]
		if color == "" {
			color = colorGrey
		}
		drawColor := color
		if selected {
			drawColor = colorMauve
		} else if !isRecent(ws, recent) {
			// E3: dim non-recent workspaces
			drawColor = dimColor(color)
		}
		borderWidth := "1"
		if selected {
			borderWidth = "3"
		}
		bgColor := colorTransparent
		if selected {
			bgColor = "0x19b347ff"
		}
		label := " —"
		if i <= len(labels) {
			label = labels[i-1]
		}
		args = append(args,
			"--set", fmt.Sprintf("item.%d", i),
			"label="+label,
			fmt.Sprintf("icon.highlight=%v", selected),
			"icon.color="+drawColor,
			fmt.Sprintf("label.highlight=%v", selected),
			"label.color="+drawColor,
			"background.border_color="+drawColor,
			"background.border_width="+borderWidth,
			"background.color="+bgColor,
		)
	}
	// Apple item: service > kindaVim N/V/C/R > unicorn (insert or default).
	// Default = mauve (primary Mocha Neon accent) to match focused workspace + chip borders.
	appleColor := colorMauve
	appleBorder := "1"
	appleString := "🦄"
	appleHighlight := "false"
	if svc {
		appleString = "☢️"
		appleColor = colorRed
		appleBorder = "3"
		appleHighlight = "true"
	} else if vim == "N" || vim == "V" || vim == "C" || vim == "R" {
		appleString = vim
		appleBorder = "2"
		switch vim {
		case "V":
			appleColor = colorMagenta
		case "C":
			appleColor = colorRed
		case "R":
			appleColor = colorYellow
		default:
			appleColor = colorMauve // N = normal mode — primary accent
		}
	}
	args = append(args,
		"--set", "apple",
		"icon.string="+appleString,
		"icon.color="+appleColor,
		"icon.highlight="+appleHighlight,
		"background.border_color="+appleColor,
		"background.border_width="+appleBorder,
	)
	logDebug("sketchybar %s", strings.Join(args, " "))
	cmd := exec.Command("sketchybar", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// ---- refresh orchestration ----

func refresh(st *state) {
	focused, recent, svc, vim := st.snapshot()
	if focused == "" {
		if f, err := getFocusedWorkspace(); err == nil {
			focused = f
			st.setFocused(f)
			_, recent, _, _ = st.snapshot()
		}
	}
	windowsByWs, err := getWindowsByWorkspace()
	if err != nil {
		logDebug("getWindowsByWorkspace: %v", err)
		windowsByWs = make(windowSet)
	}
	badges := DockBadges()
	labels := buildWorkspaceLabels(windowsByWs, badges)
	pulsed := st.diffBadges(badges, windowsByWs)
	if err := pushToSketchybar(labels, focused, recent, svc, vim); err != nil {
		log.Printf("pushToSketchybar: %v", err)
		st.mu.Lock()
		st.retryAttempt++
		attempt := st.retryAttempt
		st.mu.Unlock()
		if attempt <= retryMaxAttempts {
			backoff := time.Duration(retryDelayMs*(1<<(attempt-1))) * time.Millisecond
			time.AfterFunc(backoff, func() { refresh(st) })
		} else {
			log.Printf("pushToSketchybar: giving up after %d attempts", attempt-1)
		}
		return
	}
	st.mu.Lock()
	st.retryAttempt = 0
	st.mu.Unlock()
	// E4: pulse workspaces whose app gained/changed a Dock badge. Uses
	// sketchybar's `--animate sin` to ease background + border to cyan,
	// then a follow-up animate back to normal. Visible app-icon "attention".
	if len(pulsed) > 0 {
		animatePulse(pulsed, st)
	}
}

// E4: animate a notification-arrival pulse on each workspace in `pulsed`.
// Three on-off cycles using sketchybar's sin animation for a clearly visible
// "attention" effect. Total ~1.8s per workspace.
func animatePulse(pulsed []string, st *state) {
	for _, ws := range pulsed {
		idx := workspaceIndex(ws)
		if idx == 0 {
			continue
		}
		item := fmt.Sprintf("item.%d", idx)
		focused, _, _, _ := st.snapshot()
		color := workspaceColors[ws]
		if color == "" {
			color = colorGrey
		}
		baseBorder := color
		baseBg := colorTransparent
		baseBorderW := "1"
		if ws == focused {
			baseBorder = colorMauve
			baseBg = "0x19b347ff"
			baseBorderW = "3"
		}
		go pulseCycles(item, baseBg, baseBorder, baseBorderW)
	}
}

// pulseCycles runs 3 ON/OFF cycles on a workspace item. Each cycle: animate
// to bright cyan over 15 frames (~250ms), then back to base over 15 frames.
func pulseCycles(item, baseBg, baseBorder, baseBorderW string) {
	const cycles = 3
	const halfMs = 250
	for i := 0; i < cycles; i++ {
		_ = exec.Command("sketchybar",
			"--animate", "sin", "15",
			"--set", item,
			"background.color="+colorCyan,
			"background.border_color="+colorCyan,
			"background.border_width=3",
		).Run()
		time.Sleep(halfMs * time.Millisecond)
		_ = exec.Command("sketchybar",
			"--animate", "sin", "15",
			"--set", item,
			"background.color="+baseBg,
			"background.border_color="+baseBorder,
			"background.border_width="+baseBorderW,
		).Run()
		time.Sleep(halfMs * time.Millisecond)
	}
}

func workspaceIndex(ws string) int {
	for i, w := range workspaceOrder {
		if w == ws {
			return i + 1
		}
	}
	return 0
}

func scheduleRefresh(st *state) {
	st.mu.Lock()
	defer st.mu.Unlock()
	if st.debounceTimer != nil {
		st.debounceTimer.Stop()
	}
	st.debounceTimer = time.AfterFunc(debounceMs*time.Millisecond, func() {
		refresh(st)
	})
}

func handleEvent(st *state, event string, env map[string]string) {
	logDebug("event %q env %v", event, env)
	switch event {
	case "workspace", "focus":
		// A5: trust FOCUSED_WORKSPACE from event payload; never fall back to subprocess.
		if ws := env["FOCUSED_WORKSPACE"]; ws != "" {
			st.setFocused(ws)
			// Clear notif preview if user just entered the workspace that
			// triggered the latest notification — they've seen it.
			clearNotifPreviewForWorkspace(ws)
		}
		if d := env["FOCUSED_DISPLAY"]; d != "" {
			if n, err := strconv.Atoi(d); err == nil {
				st.setFocusedDisplay(n)
			}
		}
		invalidateWindowCache()
		scheduleRefresh(st)
	case "window-changed": // B4: emitted by aerospace on-window-detected
		invalidateWindowCache()
		scheduleRefresh(st)
	case "manual-pulse": // test trigger for E4 animation
		if ws := env["WORKSPACE"]; ws != "" {
			go animatePulse([]string{ws}, st)
		}
	case "sketchybar_ready": // Lua signals sketchybar config finished loading
		// Reset retry counter so failures during pre-ready window don't
		// carry over and immediately trip the give-up cap after reload.
		st.retryAttempt = 0
		rehydrateNotifPreview()
		// Re-push workspace items (item.1..10) and apple icon, which
		// sketchybar wipes on every reload. Without this, widgets go
		// blank until the next aerospace focus/window event.
		scheduleRefresh(st)
	case "enter_service":
		st.setServiceMode(true)
		scheduleRefresh(st)
	case "leave_service":
		st.setServiceMode(false)
		scheduleRefresh(st)
	default:
		logDebug("unknown event %q", event)
	}
}

// ---- socket daemon ----

func daemon(st *state) (net.Listener, error) {
	if err := os.Remove(socketPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		log.Printf("os.Remove(%s): %v", socketPath, err) // B5
	}
	l, err := net.Listen("unix", socketPath)
	if err != nil {
		return nil, fmt.Errorf("listen: %w", err)
	}
	logDebug("listening on %s", socketPath)
	go func() {
		for {
			conn, err := l.Accept()
			if err != nil {
				return // listener closed during shutdown
			}
			go handleConn(conn, st)
		}
	}()
	return l, nil
}

func handleConn(c net.Conn, st *state) {
	defer c.Close()
	sc := bufio.NewScanner(c)
	if !sc.Scan() {
		return
	}
	line := strings.TrimSpace(sc.Text())
	parts := strings.SplitN(line, " ", 2)
	event := parts[0]
	env := make(map[string]string)
	if len(parts) > 1 {
		for _, kv := range strings.Fields(parts[1]) {
			if idx := strings.Index(kv, "="); idx > 0 {
				env[kv[:idx]] = kv[idx+1:]
			}
		}
	}
	handleEvent(st, event, env)
}

func notifyClient(event string, env []string) error {
	conn, err := net.Dial("unix", socketPath)
	if err != nil {
		return fmt.Errorf("dial: %w", err)
	}
	defer conn.Close()
	line := event
	if len(env) > 0 {
		line += " " + strings.Join(env, " ")
	}
	_, err = conn.Write(append([]byte(line), '\n'))
	return err
}

// ---- B2: sketchybar readiness probe ----

func waitForSketchybar(maxWait time.Duration) error {
	step := readinessStepMs * time.Millisecond
	deadline := time.Now().Add(maxWait)
	for time.Now().Before(deadline) {
		out, err := exec.Command("sketchybar", "--query", "item.1").Output()
		if err == nil && len(out) > 0 && !strings.Contains(string(out), "not found") {
			return nil
		}
		time.Sleep(step)
		if step < 500*time.Millisecond {
			step *= 2
		}
	}
	return fmt.Errorf("sketchybar items not ready after %v", maxWait)
}

// ---- main ----

func main() {
	flag.Parse()
	if *showVersion {
		fmt.Printf("sketchybar-watcher %s (built %s)\n", version, buildTime)
		return
	}
	// Manual pulse test: `sketchybar-watcher pulse chat` — fires the E4
	// animation against the named workspace. Bypasses the badge-diff path so
	// you can verify the effect without a real notification.
	if len(os.Args) >= 3 && os.Args[1] == "pulse" {
		if err := notifyClient("manual-pulse", []string{"WORKSPACE=" + os.Args[2]}); err != nil {
			log.Fatal(err)
		}
		return
	}
	if len(os.Args) >= 2 && os.Args[1] == "notify" {
		var event string
		var toSend []string
		for i := 2; i < len(os.Args); i++ {
			arg := os.Args[i]
			switch {
			case strings.HasPrefix(arg, "--event="):
				event = strings.TrimPrefix(arg, "--event=")
			case arg == "--event" && i+1 < len(os.Args):
				event = os.Args[i+1]
				i++
			case strings.Contains(arg, "="):
				toSend = append(toSend, arg)
			}
		}
		if event == "" {
			log.Fatal("notify requires --event <name>")
		}
		if err := notifyClient(event, toSend); err != nil {
			log.Fatal(err)
		}
		return
	}
	homeDir = os.Getenv("HOME")
	if homeDir == "" {
		log.Fatal("HOME not set")
	}
	kindavimPath = filepath.Join(homeDir, kindavimEnvFile)

	st := &state{}
	globalState = st

	listener, err := daemon(st)
	if err != nil {
		log.Fatal(err)
	}

	// B1: graceful shutdown + SIGHUP reload
	sigCh := make(chan os.Signal, 2)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM, syscall.SIGHUP)

	go func() {
		if err := waitForSketchybar(readinessMaxMs * time.Millisecond); err != nil {
			log.Printf("readiness: %v (continuing anyway)", err)
		}
		if f, _ := getFocusedWorkspace(); f != "" {
			st.setFocused(f)
		}
		st.setVimMode(readKindavimMode())
		refresh(st)
		startNotifPreview(st) // E5: kicks off sqlite poller goroutine
	}()
	go kindavimPoller(st)

	for sig := range sigCh {
		switch sig {
		case syscall.SIGHUP:
			log.Printf("SIGHUP: full refresh")
			invalidateWindowCache()
			scheduleRefresh(st)
		case syscall.SIGINT, syscall.SIGTERM:
			log.Printf("shutdown: %s", sig)
			st.mu.Lock()
			if st.debounceTimer != nil {
				st.debounceTimer.Stop()
			}
			st.mu.Unlock()
			_ = listener.Close()
			_ = os.Remove(socketPath)
			return
		}
	}
}
