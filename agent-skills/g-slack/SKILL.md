---
name: g-slack
description: |
  The single gate for sending ANYTHING to Slack on Greg's behalf (post, reply,
  DM, thread). Voices the text through greg-voice and sends it AS GREG with his
  user token (no footer), never the claude.ai Slack MCP (it stamps "*Sent
  using* @Claude"). Trigger on "odpowiedz na slacku", "napisz na slacka",
  "wyślij na slacka", "odpisz w wątku", "napisz do <person> na slacku", "reply
  on slack", "send this to <channel>", "post in the thread", or any Slack
  message about to leave the machine. NOT for bot-style automation (PR bumps
  via g-pr-bump, scheduled notifications, daily briefs): those keep the footer.
license: MIT
compatibility: claude-code
allowed-tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
  - ToolSearch
---

# /g-slack — send to Slack as Greg

Draft → **greg-voice** → confirm → send **as Greg** with his user token.
Reads go through the Slack MCP. Which messages are Greg's vs automation: the
"Slack — send through g-slack" part of `external-output-voice.md` (his reply,
opinion or decision → here; a mechanical ping → automation, footer fine).

Identifiers are private: channel and subteam IDs and the roster in
`~/.local/state/dotfiles/secrets/work-context.md` (Slack sections);
`$WORK_SLACK_POSTER_TOKEN` from `source ~/.local/state/dotfiles/secrets/work.env`
(never `op read` at runtime). Never hardcode a channel, ID or token here.

## Hard rules

- **No send without Greg's explicit ok on the final text.** It posts publicly
  as him. Another task's go-ahead ("rób PR") is not a send, a link-only
  message included.
- **Send with the user token, never `slack_send_message`.**
- **Slack MCP tools are deferred**: load them, don't conclude "no Slack":
  `ToolSearch("select:mcp__claude_ai_Slack__slack_read_thread,mcp__claude_ai_Slack__slack_read_channel")`
  (add others as needed). Nothing comes back while `claude mcp list` shows it
  Connected → this session never registered them: say it needs a restart.
- **Plain text** in the channel's language; a PR or issue is always `<full
  url|#n>`, never a bare `#n` or a long bare URL, already in the draft Greg
  reads. Work only unless Greg says otherwise.

## 1. Target

Channel or DM, plus `thread_ts` for a reply. Names → IDs from work-context.
Ambiguous → ask.

- A thread Greg didn't link: search the run/job ID from the brief or PR body
  (`slack_search_public_and_private`, concise, `limit ≤ 10`); nothing →
  `slack_read_channel` on the team channel with `oldest` at the run date, take
  the root holding the run URL. Never search by PR number or Greg's words
  (they hit his replies).
- A DM: `chat.postMessage` with the user's Slack ID as `channel`; no
  `conversations.open` (`missing_scope`). A thread's `ts` comes from the
  permalink (`p<digits>` → `<10>.<6>`), never from the transcript.
- "Napisz do zespołu" = the team channel from work-context; check its recent
  language first, don't draft in English by default.
- "Zgłoś autorowi / do teamu, który to zakommitował": map the author to a team
  first. Greg's own team → one line to the author, no "zgłoszenie" header.
  Another team → the one-thread request flow from `external-output-voice.md`.

## 2. Read the context

- Read the thread first (`slack_read_thread`, concise): one sentence "what it
  already says and asks"; the reply covers only what's missing. Greg already
  replied → no draft, one line.
- `slack_read_thread` needs `message_ts` (from a channel read or a search hit).
  A DM with no replies returns only the parent: read the DM as a channel
  (`D…` id). Caps and `invalid_union` handling: the MCP-search trap in
  `ops-traps.md` (`limit: 20`, concise).
- `permission_error` ("Connector access could not be verified") → Greg runs
  `/mcp` and reconnects Slack, or pastes the message; don't guess content.
  Fallback read: `conversations.replies` / `conversations.history` with the
  poster token works on work channels (result via `jq` to time, author, text;
  token never to stdout). `missing_scope` elsewhere → `/mcp`.
- A reply defending a decision first collects its evidence (the issue, PR or
  report and the complaints behind it; `gh issue list --search` or one narrow
  Slack search) and asks whether the reader knows that context.

## 3. Draft and voice

What Greg would say, point first, then `greg-voice` in the same pass
(mandatory, no `humanizer`).

## 4. Confirm

Per the popup rules in `adhd-actions-not-walls.md`: a fresh draft, or one
changed after his correction, goes out as plain paragraphs ending in "powiedz
wyślij"; while he keeps editing, every version stays plain text. Only a text
already on his screen gets the send / don't-send popup, the full text in every
option's `preview`, target (channel + thread) in the question. "Don't send" →
repeat the text as plain paragraphs and end the turn without a popup.

## 5. Send as Greg

```bash
source ~/.local/state/dotfiles/secrets/work.env
TOKEN="$WORK_SLACK_POSTER_TOKEN"
case "$TOKEN" in xoxp-*) : ;; *) echo "no user token — falling back to draft-only"; esac
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-type: application/json" \
  -X POST https://slack.com/api/chat.postMessage \
  -d "$(jq -n --arg c "$CHANNEL" --arg t "$TEXT" --arg ts "$THREAD_TS" \
        '{channel:$c, text:$t} + (if $ts != "" then {thread_ts:$ts} else {} end)')" \
  | jq '{ok, error, ts}'
```

Never echo `$TOKEN`. `ok:false` → report `error` (`not_in_channel`,
`channel_not_found`, `invalid_auth`), stop. Keep curl piped straight into
`jq`; a parse error after the POST means "read the channel", never "resend".
Then report the permalink (read it back when it matters: no footer).

**Fallback, draft-only**: no valid token, or Greg sends himself → the voiced
text as a clean copy-paste block.

**Edit a sent message** ("popraw"): `chat.update` with the same token,
`{"channel": $CH, "ts": $TS, "text": $TEXT}`, `ts` from the post response.
Never a second message.

Same token as `/g-standup` (`chat:write`, any channel Greg is in).
