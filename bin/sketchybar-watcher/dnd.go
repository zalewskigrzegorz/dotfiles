package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// startDNDPoller periodically checks macOS Focus / Do-Not-Disturb state by parsing
// ~/Library/DoNotDisturb/DB/Assertions.json. When `data[0].storeAssertionRecords`
// has entries, a Focus mode (Sleep, Personal, Work, DND, ...) is currently active.
// On state transition we schedule a refresh so E2 dimming applies immediately.
//
// Graceful degradation: any parse error → assume Focus inactive, log once at debug.

const dndPollInterval = 10 * time.Second

func startDNDPoller(st *state) {
	go func() {
		var last bool
		for {
			active := readFocusActive()
			if active != last {
				last = active
				st.setDND(active)
				scheduleRefresh(st)
				logDebug("focus state: active=%v", active)
			}
			time.Sleep(dndPollInterval)
		}
	}()
}

func readFocusActive() bool {
	path := filepath.Join(homeDir, "Library", "DoNotDisturb", "DB", "Assertions.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	var doc struct {
		Data []struct {
			StoreAssertionRecords []map[string]any `json:"storeAssertionRecords"`
		} `json:"data"`
	}
	if err := json.Unmarshal(data, &doc); err != nil {
		return false
	}
	for _, d := range doc.Data {
		if len(d.StoreAssertionRecords) > 0 {
			return true
		}
	}
	return false
}
