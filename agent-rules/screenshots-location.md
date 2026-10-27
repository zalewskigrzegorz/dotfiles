---
description: Greg's screenshots live in the macOS Google Drive Screenshots folder; read the newest there when he references one, instead of asking for a path.
alwaysApply: true
---

# Screenshots location (macOS)

When Greg references "a screenshot", "the screens", "screeny", "ss" (his shorthand), or mentions/drags an image he just took, read the newest file(s) in:

`/Users/greg/Library/CloudStorage/GoogleDrive-maksim009@gmail.com/My Drive/Screenshots`

CleanShot saves there (`Bazecor_*`, `CleanShot_*`, `X_*`, …). Read directly — don't ask for the path. Google Drive sync can lag, so a just-taken screenshot may take a moment to appear locally.

**macOS only.** That path is a Google Drive mount present on the Mac, not on the lab (Debian) — on the lab there are no screenshots, skip this rule.

## "Skan" lives in `Dom/Skaner`

"skan", "zeskanowałem", "skaner" mean `…/GoogleDrive-maksim009@gmail.com/My Drive/Dom/Skaner/Epson_DDMMYYYYHHMMSS.pdf`. On 2026-10-12 a scan cost ~18 calls (Screenshots, drop, a broad `find`, a 30 dpi contact sheet nobody could read) and ended in a wrong "nie ma go".

1. List the whole folder and sort **by the date in the name**, not mtime (Drive sync lags).
2. Read a candidate with `pdftoppm -r 100 -f 1 -l 1 <pdf> <scratch>/p` and `Read` the PNG.
3. No contact sheets; `magick` is not installed.
4. Never say "not found" before every file in the folder was listed by name.

## "Na dropie" is a different place

"na dropie jest screenshot", "wrzuciłem na drop", "jest na dropie" mean `drop.mrglaszki.com`, the self-hosted file drop on the lab, not the folder above. Go straight to `curl -s 'https://drop.mrglaszki.com/?ls' | jq …`, take the newest entries by `ts`, download them into the session scratchpad and read them. Don't search local dirs first (2026-10-02: ~8 calls across Screenshots, `~/Downloads` and `find ~` before the listing).

## Screenshots reach the agent through the hook, never the clipboard

Greg ruled out the clipboard ("mam wtedy cały zawalony") and dragging
(2026-10-21, bde78708). Never suggest either. A prompt that says screen, ss or
zrzut already carries the newest CleanShot paths from
`dot_claude/hooks/executable_screenshot-attach.sh`; read those first and fall
back to the Drive folder only when none were added. A session started before
the hook needs `/exit` + `claude --continue`.

## "Zobacz okno X" is a tuios window, not CleanShot

"zobacz okno <nazwa>", "spójrz na lazygit / nvim / deploy", "co jest w oknie
bg:" mean a pane in his tuios session. Find it with `tuios list-windows -s
"$TUIOS_SESSION"` (match the name), render it with `tuios screenshot -s
"$TUIOS_SESSION" -w <id> -o <scratchpad>/<name>.png` and `Read` the PNG. The
daemon draws it, so it works without focus and on another workspace
(2026-10-27). Text only → `tuios capture-pane -w <id> --lines 40` is cheaper.
