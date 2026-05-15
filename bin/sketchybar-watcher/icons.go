package main

// appIcons maps the macOS app display name (as reported by aerospace) to a glyph
// from sketchybar-app-font (https://github.com/kvndrsslr/sketchybar-app-font).
// One line per app for readability; add new apps alphabetically within their group.
var appIcons = map[string]string{
	// Editors & IDEs
	"Cursor":                  ":cursor:",
	"Visual Studio Code":      ":code:",
	"Zed":                     ":zed:",
	"DataGrip":                ":datagrip:",
	"Insomnia":                ":insomnia:",
	"RapidAPI":                ":code:",
	"chipmunk":                ":code:",
	"DevUtils":                ":script_editor:",
	"Proxyman":                ":proxyman:",
	"Beyond Compare":          ":sublime_merge:",
	"kindaVim":                ":vim:",
	"Claude":                  ":claude:",
	"Claude Code URL Handler": ":claude:",

	// Terminals
	"Ghostty":  ":terminal:",
	"iTerm":    ":iterm:",
	"Terminal": ":terminal:",
	"kitty":    ":kitty:",

	// Browsers
	"Arc":                       ":arc:",
	"Comet":                     ":comet:",
	"Firefox":                   ":firefox:",
	"Firefox Developer Edition": ":firefox_developer_edition:",
	"Google Chrome":             ":google_chrome:",
	"Safari":                    ":safari:",
	"Zen":                       ":zen_browser:",

	// Communication & mail
	"Discord":               ":discord:",
	"Slack":                 ":slack:",
	"Mail":                  ":mail:",
	"Canary Mail":           ":mail:",
	"Spark Mail":            ":spark:",
	"ChatMate for WhatsApp":     ":whats_app:",
	"ChatMate Pro for WhatsApp": ":whats_app:", // aerospace reports this variant
	"WhatsApp":                  ":whats_app:",
	"Messages":              ":messages:",
	"FaceTime":              ":face_time:",

	// Notes, knowledge, productivity
	"Notes":                ":notes:",
	"NotePlan":             ":notes:",
	"Obsidian":             ":obsidian:",
	"Notion":               ":notion:",
	"Drafts":               ":drafts:",
	"Pages Creator Studio": ":pages:",
	"Pencil":               ":sketch:",
	"Expressions":          ":script_editor:",
	"Juicy":                ":default:",
	"Reminders":            ":reminders:",

	// Calendar & time
	"Calendar":        ":calendar:",
	"Notion Calendar": ":calendar:",
	"Fantastical":     ":calendar:",
	"Timing":          ":timingapp:",

	// Media (music / video / audio)
	"Spotify":      ":spotify:",
	"Music Decoy":  ":music:",
	"Endel":        ":music:",
	"Boom":         ":music:",
	"VLC":          ":vlc:",
	"Replay":       ":dvd_player:",
	"superwhisper": ":voice_memos:",
	"AirBuddy":     ":face_time:",
	"Upscayl":      ":image_playground:",

	// Capture & screenshots
	"CleanShot X": ":screencap:",
	"Snagit 2024": ":screencap:",
	"FocuSee":     ":screencap:",
	"Clop":        ":color_picker:",
	"Preview":     ":preview:",

	// Finder / file management
	"Finder":         ":finder:",
	"Path Finder":    ":finder:",
	"The Unarchiver": ":default:",
	"Dropzone":       ":dropbox:",

	// Cloud / drive
	"Google Drive":  ":google_drive:",
	"Google Docs":   ":microsoft_word:",
	"Google Sheets": ":microsoft_excel:",
	"Google Slides": ":microsoft_power_point:",

	// Security & VPN
	"1Password":                ":one_password:",
	"SigmaOS 1Password Linker": ":one_password:",
	"Bitwarden":                ":bit_warden:",
	"ClearVPN":                 ":openvpn_connect:",

	// System / utility
	"Setapp":             ":setapp:",
	"System Settings":    ":gear:",
	"System Preferences": ":gear:",
	"AeroSpace":          ":gear:",
	"Raycast":            ":raycast:",
	"Raycast Beta":       ":raycast:",
	"SF Symbols":         ":sf_symbols:",
	"iStat Menus":        ":activity_monitor:",
	"Activity Monitor":   ":activity_monitor:",
	"CleanMyMac":         ":pearcleaner:",
	"DisplayBuddy":       ":desktop:",
	"NotchNook":          ":default:",
	"OpenIn":             ":default:",
	"StartupFolder":      ":gear:",
	"Wooshy":             ":spotlight:",
	"WiFi Explorer":      ":airport_utility:",

	// Containers
	"Docker":         ":docker:",
	"Docker Desktop": ":docker:",

	// Peripherals & hardware
	"Stream Deck":              ":keyboard:",
	"Elgato Stream Deck":       ":keyboard:",
	"Bazecor":                  ":bazecor:",
	"KeyCastr":                 ":keyboard:",
	"logioptionsplus":          ":keyboard:",
	"KDE Connect":              ":phone:",
	"Poly Studio":              ":phone:",
	"qFlipper":                 ":gear:",
	"Insta360 Link Controller": ":face_time:",
	"Steam Link":               ":gear:",
	"Iru Self Service":         ":gear:",
	"Glyphica Typing Survival": ":default:",

	// PDF / readers
	"CleverPDF":  ":pdf_expert:",
	"reMarkable": ":pdf_expert:",
}

func appIcon(appName string) string {
	if s, ok := appIcons[appName]; ok {
		return s
	}
	return ":default:"
}

// dockAliases maps an aerospace app-name to the corresponding Dock display
// name when they differ. Used to look up Dock badges for an aerospace window.
// Add entries here when you spot a mismatch (e.g. via `osascript -e 'tell
// application "System Events" to tell process "Dock" to get name of every UI
// element of list 1'` vs `aerospace list-windows --all --format '%{app-name}'`).
var dockAliases = map[string]string{
	"ChatMate Pro for WhatsApp": "ChatMate for WhatsApp",
}

// badgeFor returns the Dock badge for an aerospace app, consulting dockAliases.
func badgeFor(appName string, badges map[string]string) string {
	if b, ok := badges[appName]; ok {
		return b
	}
	if alias, ok := dockAliases[appName]; ok {
		return badges[alias]
	}
	return ""
}
