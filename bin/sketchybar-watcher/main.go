// sketchybar-watcher is a daemon that drives sketchybar from Aerospace events
// and kindaVim state. It listens on a Unix socket for workspace/focus/service
// events and polls kindaVim's environment.json for mode changes.
package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const (
	socketPath      = "/tmp/sketchybar-watcher.sock"
	debounceMs      = 0
	workspaceCount  = 10
	kindavimPollMs  = 300
	kindavimIdleMs  = 2000 // poll less often when kindaVim not running
	kindavimEnvFile = "Library/Application Support/kindaVim/environment.json"
	startupDelayMs  = 2500
	retryDelayMs    = 2000
)

var (
	debug        = flag.Bool("debug", false, "verbose logging")
	homeDir      string
	kindavimPath string
)

var workspaceOrder = []string{
	"chat", "web", "term", "code", "media", "test", "misc", "notes", "mail", "mac",
}

var workspaceColors = map[string]string{
	"chat":  "0xffa2ff99", "web": "0xff80ffea", "term": "0xffffca80", "code": "0xffff80bf",
	"media": "0xffffaa99", "test": "0xffffff80", "misc": "0xff7970a9", "notes": "0xff8aff80",
	"mail":  "0xffff9580", "mac": "0xfff8f8f2",
}

var appIcons = map[string]string{
	"Cursor": ":cursor:", "Visual Studio Code": ":code:", "Ghostty": ":terminal:",
	"Discord": ":discord:", "Slack": ":slack:", "Spotify": ":spotify:",
	"Firefox": ":firefox:", "Safari": ":safari:", "Arc": ":arc:", "Comet": ":comet:",
	"Notes": ":notes:", "Obsidian": ":obsidian:", "NotePlan": ":notes:", "Notion": ":notion:",
	"Mail": ":mail:", "Canary Mail": ":mail:", "Spark Mail": ":spark:", "Finder": ":finder:",
	"iTerm": ":iterm:", "Terminal": ":terminal:", "kitty": ":kitty:",
	"DataGrip": ":datagrip:",
	"Notion Calendar": ":calendar:", "Fantastical": ":calendar:", "Calendar": ":calendar:",
}

const (
	colorPurple     = "0xff9580ff"
	colorMagenta    = "0xffff80bf"
	colorYellow     = "0xffffff80"
	colorRed        = "0xffff9580"
	colorGrey       = "0xff7970a9"
	colorTransparent = "0x00000000"
)

type state struct {
	mu               sync.Mutex
	focusedWorkspace string
	serviceMode      bool
	vimMode          string // N, I, V, C, R or ""
	debounceTimer    *time.Timer
}

func (s *state) setFocused(ws string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.focusedWorkspace = ws
}

func (s *state) getFocused() string {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.focusedWorkspace
}

func (s *state) setServiceMode(v bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.serviceMode = v
}

func (s *state) getServiceMode() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.serviceMode
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

func logDebug(format string, args ...interface{}) {
	if *debug {
		log.Printf("[watcher] "+format, args...)
	}
}

func runCmd(name string, args ...string) ([]byte, error) {
	cmd := exec.Command(name, args...)
	return cmd.Output()
}

func runAerospace(args ...string) ([]byte, error) {
	return runCmd("aerospace", args...)
}

type windowInfo struct {
	Workspace string `json:"workspace"`
	AppName   string `json:"app-name"`
}

func getWindowsByWorkspace() (map[string][]string, error) {
	out, err := runAerospace("list-windows", "--all", "--format", "%{workspace}%{app-name}", "--json")
	if err != nil {
		return nil, err
	}
	var list []windowInfo
	if err := json.Unmarshal(out, &list); err != nil {
		return nil, err
	}
	byWs := make(map[string][]string)
	for _, w := range list {
		if w.Workspace == "" || w.AppName == "" {
			continue
		}
		if w.AppName == "kindaVim" {
			continue
		}
		byWs[w.Workspace] = append(byWs[w.Workspace], w.AppName)
	}
	return byWs, nil
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
	for {
		out, err := runCmd("pgrep", "-x", "kindaVim")
		running := err == nil && len(out) > 0
		if running {
			interval = kindavimPollMs * time.Millisecond
			mode := readKindavimMode()
			if mode != lastMode {
				lastMode = mode
				st.setVimMode(mode)
				scheduleRefresh(st)
			}
		} else {
			if lastMode != "" {
				lastMode = ""
				st.setVimMode("")
				scheduleRefresh(st)
			}
			interval = kindavimIdleMs * time.Millisecond
		}
		time.Sleep(interval)
	}
}

func getAppNotifications(appNames []string) map[string]string {
	configDir := os.Getenv("CONFIG_DIR")
	if configDir == "" {
		configDir = filepath.Join(homeDir, ".config", "sketchybar")
	}
	script := filepath.Join(configDir, "helpers", "get_app_notifications.nu")
	if _, err := os.Stat(script); err != nil {
		return nil
	}
	out, err := runCmd("nu", script)
	if err != nil || len(out) == 0 {
		return nil
	}
	m := make(map[string]string)
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		idx := strings.Index(line, ":")
		if idx <= 0 {
			continue
		}
		app := line[:idx]
		badge := strings.Trim(line[idx+1:], "\"")
		m[app] = badge
	}
	return m
}

func appIcon(appName string) string {
	if s, ok := appIcons[appName]; ok {
		return s
	}
	return ":default:"
}

func buildWorkspaceLabels(windowsByWs map[string][]string, notifications map[string]string) []string {
	labels := make([]string, workspaceCount)
	for i, ws := range workspaceOrder {
		apps := windowsByWs[ws]
		var parts []string
		for _, appName := range apps {
			icon := appIcon(appName)
			badge := ""
			if notifications != nil {
				badge = notifications[appName]
			}
			if badge != "" {
				parts = append(parts, " "+icon+badge)
			} else {
				parts = append(parts, " "+icon)
			}
		}
		if len(parts) == 0 {
			labels[i] = " —"
		} else {
			labels[i] = strings.Join(parts, "")
		}
	}
	return labels
}

func pushToSketchybar(labels []string, focusedWorkspace string, serviceMode bool, vimMode string) error {
	args := make([]string, 0, 256)
	for i := 1; i <= workspaceCount; i++ {
		ws := workspaceOrder[i-1]
		selected := ws == focusedWorkspace
		color := workspaceColors[ws]
		if color == "" {
			color = colorGrey
		}
		if selected {
			color = colorPurple
		}
		borderWidth := "1"
		if selected {
			borderWidth = "3"
		}
		bgColor := colorTransparent
		if selected {
			bgColor = "0x199580ff" // purple with alpha
		}
		label := " —"
		if i <= len(labels) {
			label = labels[i-1]
		}
		args = append(args,
			"--set", fmt.Sprintf("item.%d", i),
			"label="+label,
			fmt.Sprintf("icon.highlight=%v", selected),
			"icon.color="+color,
			fmt.Sprintf("label.highlight=%v", selected),
			"label.color="+color,
			"background.border_color="+color,
			"background.border_width="+borderWidth,
			"background.color="+bgColor,
		)
	}
	// Apple item: service > kindaVim N/V/C/R > unicorn (insert or default)
	// Insert (I) = unicorn; N,V,C,R = show letter
	if serviceMode {
		args = append(args,
			"--set", "apple",
			"icon.string=💀",
			"icon.color="+colorRed,
			"icon.highlight=true",
			"background.border_color="+colorRed,
			"background.border_width=3",
		)
	} else if vimMode == "N" || vimMode == "V" || vimMode == "C" || vimMode == "R" {
		color := colorPurple
		switch vimMode {
		case "V":
			color = colorMagenta
		case "C":
			color = colorRed
		case "R":
			color = colorYellow
		}
		args = append(args,
			"--set", "apple",
			"icon.string="+vimMode,
			"icon.color="+color,
			"icon.highlight=false",
			"background.border_color="+color,
			"background.border_width=2",
		)
	} else {
		// Insert (I) or no kindaVim = unicorn
		args = append(args,
			"--set", "apple",
			"icon.string=🦄",
			"icon.color="+colorPurple,
			"icon.highlight=false",
			"background.border_color="+colorPurple,
			"background.border_width=1",
		)
	}
	logDebug("sketchybar %s", strings.Join(args, " "))
	cmd := exec.Command("sketchybar", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func refresh(st *state) {
	focused := st.getFocused()
	serviceMode := st.getServiceMode()
	// If we never got focus from event, query
	if focused == "" {
		var err error
		focused, err = getFocusedWorkspace()
		if err != nil {
			logDebug("getFocusedWorkspace: %v", err)
		}
	}
	windowsByWs, err := getWindowsByWorkspace()
	if err != nil {
		logDebug("getWindowsByWorkspace: %v", err)
		windowsByWs = make(map[string][]string)
	}
	var appNames []string
	for _, apps := range windowsByWs {
		appNames = append(appNames, apps...)
	}
	notifications := getAppNotifications(appNames)
	labels := buildWorkspaceLabels(windowsByWs, notifications)
	vimMode := st.getVimMode()
	if err := pushToSketchybar(labels, focused, serviceMode, vimMode); err != nil {
		log.Printf("pushToSketchybar: %v (sketchybar may still be loading)", err)
		time.AfterFunc(retryDelayMs*time.Millisecond, func() { refresh(st) })
	}
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
		if ws := env["FOCUSED_WORKSPACE"]; ws != "" {
			st.setFocused(ws)
		}
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

func daemon(st *state) error {
	os.Remove(socketPath)
	l, err := net.Listen("unix", socketPath)
	if err != nil {
		return fmt.Errorf("listen: %w", err)
	}
	defer l.Close()
	logDebug("listening on %s", socketPath)
	for {
		conn, err := l.Accept()
		if err != nil {
			return err
		}
		go func(c net.Conn) {
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
						key := kv[:idx]
						val := kv[idx+1:]
						env[key] = val
					}
				}
			}
			handleEvent(st, event, env)
		}(conn)
	}
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

func main() {
	flag.Parse()
	if len(os.Args) >= 2 && os.Args[1] == "notify" {
		// Client: sketchybar-watcher notify --event workspace FOCUSED_WORKSPACE=chat FOCUSED_DISPLAY=...
		var event string
		var toSend []string
		for i := 2; i < len(os.Args); i++ {
			arg := os.Args[i]
			if strings.HasPrefix(arg, "--event=") {
				event = strings.TrimPrefix(arg, "--event=")
			} else if arg == "--event" && i+1 < len(os.Args) {
				event = os.Args[i+1]
				i++
			} else if strings.Contains(arg, "=") {
				toSend = append(toSend, arg)
			}
		}
		if event == "" {
			log.Fatal("notify requires --event workspace|focus|enter_service|leave_service")
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
	go func() {
		time.Sleep(startupDelayMs * time.Millisecond)
		if f, _ := getFocusedWorkspace(); f != "" {
			st.setFocused(f)
		}
		st.setVimMode(readKindavimMode())
		refresh(st)
	}()
	go kindavimPoller(st)
	if err := daemon(st); err != nil {
		log.Fatal(err)
	}
}
