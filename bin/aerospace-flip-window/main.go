// aerospace-flip-window moves the focused window between code (Dell-side) and web
// (ultrawide-side) workspaces for AeroSpace. No-op on mac / unknown.
package main

import (
	"os"
	"os/exec"
	"strings"
)

var dellSide = map[string]struct{}{
	"chat": {}, "term": {}, "code": {}, "misc": {}, "notes": {},
}

var ultraSide = map[string]struct{}{
	"web": {}, "media": {}, "test": {}, "mail": {},
}

func main() {
	ws := strings.TrimSpace(focusedWorkspace())
	if ws == "" {
		return
	}
	var args []string
	if _, ok := dellSide[ws]; ok {
		args = []string{"move-node-to-workspace", "web", "--focus-follows-window"}
	} else if _, ok := ultraSide[ws]; ok {
		args = []string{"move-node-to-workspace", "code", "--focus-follows-window"}
	} else {
		return
	}
	cmd := exec.Command("aerospace", args...)
	cmd.Stdin = nil
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	_ = cmd.Run()
}

func focusedWorkspace() string {
	out, err := exec.Command("aerospace", "list-workspaces", "--focused").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}
