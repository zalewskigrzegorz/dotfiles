# Spam

Raycast command that turns the **active browser tab's domain** into a per-site
spam-catcher alias and pastes it straight into the focused field:

```
app.figma.com   →  figma.com@mrglaszki.com
mail.google.com →  google.com@mrglaszki.com
foo.sklep.com.pl → sklep.com.pl@mrglaszki.com
```

Idea: give every signup a domain-scoped alias. If a site starts spamming, you
know exactly who leaked it — and you cut that one domain off.

## How it works

- `BrowserExtension.getTabs()` reads the active tab's URL (needs the **Raycast
  Browser Extension** installed in the browser — without it there are no tabs).
- The hostname is reduced to its registrable/apex domain (`www.` stripped,
  two-part TLDs like `com.pl` / `co.uk` handled without the full Public Suffix
  List).
- `Clipboard.paste()` inserts `<domain>@mrglaszki.com` at the cursor in the
  frontmost app — native, no AppleScript keystrokes, no clipboard-only step.

`mode: no-view`, so bind it to a hotkey and it fires silently into whatever
field has focus.

## Install (once per machine)

```bash
cd ~/raycast-extensions/spam   # chezmoi-applied target
npm ci
npm run dev                    # registers it into Raycast; Ctrl+C after it appears
```

`node_modules` is gitignored, so a fresh machine needs the `npm ci` step above.

## Change the catch-all domain

Edit `TARGET_DOMAIN` in `src/spam.ts`.
