package main

import (
	"os"
	"strings"
	"testing"
)

// testdata/app-font-glyphs.txt = every glyph name in sketchybar-app-font's icon_map.lua.
// Refresh it when bumping the font; an unknown name renders as a blank icon.
func TestAppIconsExistInFont(t *testing.T) {
	data, err := os.ReadFile("testdata/app-font-glyphs.txt")
	if err != nil {
		t.Fatal(err)
	}
	known := map[string]bool{":default:": true}
	for _, name := range strings.Fields(string(data)) {
		known[name] = true
	}
	for app, glyph := range appIcons {
		if !known[glyph] {
			t.Errorf("%q maps to %q, which sketchybar-app-font does not have", app, glyph)
		}
	}
}
