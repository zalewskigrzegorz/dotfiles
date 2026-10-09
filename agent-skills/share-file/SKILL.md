---
name: share-file
description: Give someone a link to a file (PDF, image, doc) through Greg's share service (share.mrglaszki.com) — a token link that expires after 7 days. Use when Greg says "wrzuć na share", "wrzuć to na share mrglaszki", "udostępnij plik", "daj link do tego pdfa", "zrób link do pliku", "share this file", "give me a link to this PDF". NOT for slide decks he presents (use `deck`) and NOT for text to paste into Slack.
---

# share-file

The route (found the hard way, 2026-10): `share.mrglaszki.com/api/shares` is **internal-only** (lab LAN), so never POST there from the Mac. Go through `deck.mrglaszki.com`, which proxies to share.

## Say this first

One line before uploading: the file leaves the machine, sits on the lab, and is readable by anyone with the token link (7 days). Personal data (VIN, registration, PESEL, ID scans) = say so explicitly.

## Steps

1. **Make one self-contained HTML.** share serves only `.html`.
   - PDF: `pdftoppm -r 110 -png in.pdf $S/p` → `<img src="data:image/png;base64,…">` per page.
   - Add a download button for the original: `<a download="name.pdf" href="data:application/pdf;base64,…">`.
   - Image / other file: same idea, embed as base64.
2. **Put it in a deck slot** (slug = short kebab name):
   ```bash
   curl -sf -F html=@$S/share.html -F title="<title>" https://deck.mrglaszki.com/api/decks/<slug>
   ```
3. **Mint the token link** (deck proxies to share's `POST /api/shares`):
   ```bash
   curl -sf -X POST https://deck.mrglaszki.com/api/decks/<slug>/share
   # → {"token":"…","url":"https://share.mrglaszki.com/s/<token>.html"}
   ```
4. **Verify**: `curl -s -o /dev/null -w '%{http_code}' <url>` must be `200`. Not 200 → report, don't hand out the link.
5. Give Greg the link (copy-paste first), plus "wygasa po 7 dniach; deck `<slug>` zostaje na deck.mrglaszki.com".

## Cleanup

- List live tokens: `curl -s https://deck.mrglaszki.com/api/decks/<slug>/shares`
- Revoke link: `curl -s -X DELETE https://deck.mrglaszki.com/api/decks/<slug>/shares/<token>`
- Delete the deck entry (the file itself): `curl -s -X DELETE https://deck.mrglaszki.com/api/decks/<slug>`

Expiry only ends the link; the deck entry keeps the base64 file forever. For personal-data documents, end with `AskUserQuestion`: **Skasuj deck + link** (Recommended, revokes the token then deletes the slug) · **Zostaw** (link expires in 7 days, file stays on the lab). Ask once the link is delivered, not before.

## Notes

- Keep slugs non-identifying (no names, no VINs); the deck entry is not token-protected.
- Re-upload to the same slug overwrites the deck; existing tokens serve the old blob.
- Nothing here is Slack text; if the link goes to a person, pass the message through `greg-voice`.
