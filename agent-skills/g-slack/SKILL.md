---
name: g-slack
description: |
  The single gate for sending ANYTHING to Slack on Greg's behalf. Whenever you
  are about to post, reply, DM, or drop a message in a thread on Slack — this
  skill runs first. It voices the text through greg-voice and sends it AS GREG
  via his personal user token (footer-free), NOT the claude.ai Slack MCP (that
  one stamps "*Sent using* @Claude" on every message). Trigger on "odpowiedz na
  slacku", "napisz na slacka", "wyślij na slacka", "odpisz w wątku", "napisz do
  <person> na slacku", "reply on slack", "send this to <channel>", "post in the
  thread", or any moment a Slack reply/message is about to leave the machine.
  NOT for automation that intentionally shows it's a bot — PR bumps
  (g-pr-bump), scheduled notifications, daily-brief posts — those keep the
  Claude footer and are out of scope here.
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

The one path for outbound Slack. Draft → **greg-voice** → confirm → send **as
Greg** with his user token (no footer). Reads go through the Slack MCP.

> **All identifiers are private.** Read
> `~/.local/state/dotfiles/secrets/work-context.md` → the **Slack** sections for
> channel IDs, subteam IDs, and the roster. `source
> ~/.local/state/dotfiles/secrets/work.env` for **`$WORK_SLACK_POSTER_TOKEN`**
> (the footer-free user token — already in the env file, so **never `op read` at
> runtime**; no vault prompt). Never hardcode a channel, ID, or token here.

## The rule (why this skill exists)

Two things went wrong once and this skill exists so they never do again:

1. **Voiced, always.** Every word going to Slack in Greg's name is his voice —
   run it through `greg-voice` (point-first, casual, just the meat). No stiff
   AI register, ever.
2. **Sent as Greg, no footer.** Post with the **user token** + `chat.postMessage`
   so it lands cleanly as Greg. **Never** send a Greg-reply through the claude.ai
   Slack MCP (`slack_send_message`) — it appends `*Sent using* @Claude`, which
   shows publicly and screams "a bot typed this". Reads through the MCP are fine
   (no footer on reads).

## Footer carve-out — automation only

The Claude footer is *correct* for messages that are transparently automation and
didn't need Greg's judgement to write: **PR bumps (`g-pr-bump`), scheduled
notifications, daily-brief drops.** Those are out of scope here — leave them on
their own flow / the MCP. This skill is only for messages that speak as Greg.

If you're unsure which bucket a message is in: does it represent Greg's own reply
/ opinion / decision? → g-slack, as Greg, no footer. Is it a mechanical ping the
recipients read as "the system nudged me"? → automation, footer fine.

## Hard rules (do not relitigate)

- **Never send without Greg's explicit "ok" on the final drafted text.** It posts
  publicly as him. Draft, show, wait for a clear yes. No yes → don't send.
- **Send via the user token, not the MCP** (see above). Reads via the MCP.
- **Slack MCP tools are DEFERRED** — absent from the tool list until loaded. Do
  NOT conclude "no Slack in this session". Load first:
  `ToolSearch("select:mcp__claude_ai_Slack__slack_read_thread,mcp__claude_ai_Slack__slack_read_channel")`
  (add other `mcp__claude_ai_Slack__*` as needed), then call normally. If
  ToolSearch returns nothing even though `claude mcp list` shows the connector
  Connected, the tools never registered in THIS session — tell Greg it needs a
  restart, or hand the reads to a session that has them.
- **Plain, clean text.** Normal channels render Slack mrkdwn fine, but keep links
  bare unless a real `<url|label>` helps. Match the channel's language (PL/EN).
- **Work only, unless Greg says otherwise.** Don't post personal-repo noise.

## Workflow

### 1. Find the target

Channel (or DM) + optional `thread_ts` for an in-thread reply. Greg usually
points at it ("odpisz w tym wątku", a Slack link, a channel name). Resolve
channel names/IDs from work-context. If it's ambiguous which channel/thread,
**ask** — don't guess where a public message lands.

### 2. Read the context

Load the Slack MCP read tools and read the thread/channel so the reply actually
answers what's there:

```
ToolSearch("select:mcp__claude_ai_Slack__slack_read_thread,mcp__claude_ai_Slack__slack_read_channel")
```

### 3. Draft the reply

Write what Greg would say — point first, just the meat.

### 4. Voice it — greg-voice (mandatory)

Run the draft through `greg-voice` in the same pass (casual, expressive,
specifics intact, AI tells gone). This is not optional and not a second
`humanizer` step — greg-voice is the whole voice gate.

### 5. Confirm

Show the final text (and where it's going — channel + thread). Wait for Greg's
explicit yes. He can trim/redirect here.

### 6. Send as Greg

```bash
source ~/.local/state/dotfiles/secrets/work.env
TOKEN="$WORK_SLACK_POSTER_TOKEN"
case "$TOKEN" in xoxp-*) : ;; *) echo "no user token — falling back to draft-only"; esac   # → step 8

# thread reply: add  thread_ts:$TS  to the payload; top-level post: omit it.
curl -s -H "Authorization: Bearer $TOKEN" -H "Content-type: application/json" \
  -X POST https://slack.com/api/chat.postMessage \
  -d "$(jq -n --arg c "$CHANNEL" --arg t "$TEXT" --arg ts "$THREAD_TS" \
        '{channel:$c, text:$t} + (if $ts != "" then {thread_ts:$ts} else {} end)')" \
  | jq '{ok, error, ts}'
```

Never echo `$TOKEN`. `ok:true` = sent; on `ok:false` report the `error`
(`not_in_channel`, `channel_not_found`, `invalid_auth`) and stop — don't retry
blind.

### 7. Verify

Confirm it posted as Greg with **no footer** (read the channel/thread back if it
matters). Report the permalink.

### 8. Fallback — draft-only

Token missing/invalid, or Greg prefers to send himself: **don't auto-send.**
Output the voiced text as a clean copy-paste block. Draft → voice → confirm stays
the same.

## Notes

- Same user token as `/g-standup` (`$WORK_SLACK_POSTER_TOKEN`) — one footer-free
  poster identity, `chat:write`, posts to any channel Greg is in.
- `chat:write` **cannot read history** — reads always go through the MCP.
