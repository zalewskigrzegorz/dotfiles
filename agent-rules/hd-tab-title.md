---
description: Keep the herdr tab / statusline title current by calling hd-title at task checkpoints
alwaysApply: true
---

# herdr Tab Title — Set It at Checkpoints

Greg's herdr tab label and statusline both show a per-session title. The colour
is fixed per session; the **text is yours to keep current**. Claude Code's native
`aiTitle` is frozen on the session's first topic, so on a long, multi-task session
the label goes stale and Greg loses track of what a tab is doing — especially
after `/clear`.

Fix: **you** set the text at checkpoints by running `hd-title`.

## When to call it

Run `hd-title "<short current topic>"` when the *topic* meaningfully changes —
NOT every turn:

- Starting a distinctly new task or request ("next thing: …").
- Hitting a real checkpoint in a long task (a phase done, focus shifts).
- Right after `/clear` when a fresh topic begins (the clear itself resets the
  text to the repo/branch automatically; you set the real topic).

Do **not** re-title on every prompt/response, for tiny follow-ups ("yes", "go
on"), or mid-step. Think "would the tab strip now mislead Greg about what this
session is on?" — if yes, retitle; if not, leave it.

## How

```bash
hd-title "deslop gate rollout"
```

- 3–5 words, the *current* focus, in whatever language fits (PL/EN).
- It updates both the herdr tab and the statusline, and keeps the session colour.
- It's fire-and-forget and non-blocking — no need to check output.
- Safe outside herdr too (it just writes the shared store).
