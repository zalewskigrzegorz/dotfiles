---
name: share-file
description: Give someone a link to a file (PDF, image, doc) through share.mrglaszki.com, a token link that expires after 7 days. Use on "wrzuć na share", "wrzuć to na share mrglaszki", "udostępnij plik", "daj link do tego pdfa", "zrób link do pliku", "share this file", "give me a link to this PDF". Not for decks he presents (`deck`) or Slack text.
---

# share-file

`share.mrglaszki.com/api/shares` is lab-LAN only: never POST there from the Mac. Go through `deck.mrglaszki.com`, which proxies to it.

**First, one line:** the file leaves the machine, sits on the lab, readable by anyone with the link for 7 days; say explicitly when it holds personal data (VIN, registration, PESEL, ID scans).

## Steps

1. One self-contained `.html` (share serves only html): PDF → `pdftoppm -r 110 -png in.pdf $S/p`, one `<img src="data:image/png;base64,…">` per page, plus `<a download="name.pdf" href="data:application/pdf;base64,…">` for the original. Other files: same, base64-embedded.
2. Deck slot (short, non-identifying kebab slug: no names, no VINs; the deck entry isn't token-protected):
   `curl -sf -F html=@$S/share.html -F title="<title>" https://deck.mrglaszki.com/api/decks/<slug>`
3. Token link: `curl -sf -X POST https://deck.mrglaszki.com/api/decks/<slug>/share` → `{"token":…,"url":"https://share.mrglaszki.com/s/<token>.html"}`.
4. `curl -s -o /dev/null -w '%{http_code}' <url>` must be `200`, else report and don't hand it out.
5. Link first (copy-paste), plus "wygasa po 7 dniach; deck `<slug>` zostaje na deck.mrglaszki.com". A message to a person goes through `greg-voice`.

## Cleanup

`GET …/decks/<slug>/shares` lists tokens; `DELETE …/decks/<slug>/shares/<token>` revokes; `DELETE …/decks/<slug>` deletes the file. Expiry ends only the link, the base64 stays. Re-uploading a slug overwrites the deck; old tokens serve the old blob.

Personal-data document, after the link is delivered: `AskUserQuestion` **Skasuj deck + link** (Recommended: revoke, then delete the slug) · **Zostaw** (link expires, file stays).
