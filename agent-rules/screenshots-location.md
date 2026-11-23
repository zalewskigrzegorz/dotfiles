---
description: Greg's screenshots live in the macOS Google Drive Screenshots folder; read the newest there when he references one, instead of asking for a path.
alwaysApply: true
---

# Screenshots location (macOS)

"a screenshot", "screeny", "ss", an image he just took → read the newest file(s) in `/Users/greg/Library/CloudStorage/GoogleDrive-maksim009@gmail.com/My Drive/Screenshots` (CleanShot: `CleanShot_*`, `Bazecor_*`, `X_*` …) directly, never ask for the path; Drive sync may lag a moment. macOS only: the lab has none.

- **Screenshots reach the agent through the hook**, never the clipboard ("mam wtedy cały zawalony") or dragging; never suggest either. A prompt saying screen/ss/zrzut already carries the newest paths from `dot_claude/hooks/executable_screenshot-attach.sh`: read those first, the Drive folder only when none were added. A session started before the hook needs `/exit` + `claude --continue`. A quoted Screenshots path in the prompt was picked with `/shot` or `prefix+Y` (`bin/shot-pick`): read exactly that file.
- **"skan", "zeskanowałem", "skaner"** → `…/My Drive/Dom/Skaner/Epson_DDMMYYYYHHMMSS.pdf`. List the whole folder and sort **by the date in the name**, not mtime; read a candidate with `pdftoppm -r 100 -f 1 -l 1 <pdf> <scratch>/p` and `Read` the PNG; no contact sheets (`magick` is not installed); never "not found" before every file was listed by name.
- **"na dropie"** = `drop.mrglaszki.com` (the lab's file drop), not a local folder: `curl -s 'https://drop.mrglaszki.com/?ls' | jq …`, newest by `ts`, download into the scratchpad, read.
- **"zobacz okno X"** ("spójrz na lazygit / nvim / deploy", "co jest w oknie bg:") is a pane in his tuios session, not CleanShot: `tuios list-windows -s "$TUIOS_SESSION"` (match the name), `tuios screenshot -s "$TUIOS_SESSION" -w <id> -o <scratchpad>/<name>.png`, `Read` it (works without focus). Text only → `tuios capture-pane -w <id> --lines 40`.
