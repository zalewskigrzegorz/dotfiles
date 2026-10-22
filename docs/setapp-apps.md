# Setapp Apps

Setapp itself is installed through Homebrew when `setapp = true` in `~/.config/chezmoi/chezmoi.toml`.

Individual Setapp apps are managed by Setapp after login, not by Homebrew. Keep the expected apps here and run `scripts/check-setapp-apps.sh` to see what is missing.

List currently installed Setapp apps with:

```bash
scripts/list-setapp-apps.sh
```

On a new Mac, install Setapp with Homebrew, sign in, mark the apps below as favorites in Setapp, then use Setapp's Quick Installation/Install Favorites flow. Setapp exposes that workflow in the app UI; there is no stable Homebrew/CLI interface for installing each Setapp app by name.

A Setapp build keeps its settings in a `-setapp` defaults domain (`com.pointum.hazeover-setapp`). Track the keys you chose as `defaults write` lines in `run_onchange_after_14-macos-defaults.sh.tmpl`, not the whole plist, which also holds window frames and run time.

## Expected

- [ ] Boom
- [ ] ChatMate for WhatsApp
- [ ] CleanMyMac
- [ ] CleanShot X
- [ ] ClearVPN
- [ ] DisplayBuddy
- [ ] Filepane
- [ ] FocuSee
- [ ] HazeOver
- [ ] OpenIn
- [ ] Proxyman
- [ ] Spark Mail
- [ ] Timing
- [ ] WiFi Explorer
