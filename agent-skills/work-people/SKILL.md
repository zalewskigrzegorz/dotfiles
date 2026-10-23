---
name: work-people
description: >-
  Turn a work colleague's GitHub login, Slack handle, Slack user ID or bare
  first name into their full name (and back), using the people matrix that
  this skill keeps fresh from GitHub org members and Slack users.list. Use it
  every time you are about to name a coworker: PR authors and reviewers,
  review comments, "who approved", CODEOWNERS, issue assignees, Slack
  threads, standups, recaps, digests, briefs for other agents. Greg does not
  know who `pixelfox42` or `quietstorm` is, so a login in a reply to him is
  a bug even when he did not ask about people. Also triggers on "kto to jest
  <nick>", "who is <login>", "jak się nazywa", "slack id <osoby>", "github
  login <osoby>", "zaktualizuj listę ludzi", "odśwież macierz", "nowa osoba
  w firmie".
---

# work-people

Greg reads GitHub logins and Slack nicknames as noise: `pixelfox42`,
`quietstorm`, "Vlad", "Sasha" say nothing about who the person is, and with two
people sharing a first name a first name alone picks the wrong one.
So every coworker you name gets a **full name**, looked up, never guessed.

## The matrix

```
~/Code/personal/bazgroly/$WORK_GITHUB_ORG_LOWER/people.md            # generated, don't edit rows
~/Code/personal/bazgroly/$WORK_GITHUB_ORG_LOWER/people.overrides.tsv # hand-kept fixes
```

Columns: `Full name | GitHub | Slack ID | Slack name | Title`. Slack-only
people (designers, people ops, guests) have no GitHub cell; bots and people
without Slack have no Slack cell.

bazgroly is private, the dotfiles repo is public: names and IDs live only in
those two files. Never copy rows into this skill, a rule, or anything under
`~/Code/dotfiles`.

## Look up

```bash
f=~/Code/personal/bazgroly/$WORK_GITHUB_ORG_LOWER/people.md
[ -n "$(find "$f" -mtime -7 2>/dev/null)" ] || python3 ~/.claude/skills/work-people/scripts/sync.py
rg -i -F -- 'pixelfox42' "$f"      # a login, a Slack ID (U0…), a surname or a first name
```

Search for several people in one `rg -i 'a|b|c'`. A file older than a week
is rebuilt first: that is what keeps the list current without anyone
remembering to do it.

## Write

| Where | What to write |
|---|---|
| Reply to Greg, recap, standup, digest, agent brief | **Full name**: "Jan Kowalski approved, Anna Nowak left 3 comments" |
| GitHub prose (PR body, review, issue) | Full name. `@login` only where you mean to notify that person |
| Slack text | Full name; `<@U…>` only for a real ping (it renders as their name) |
| Table or list where the login matters (reviewer assignment, CODEOWNERS) | `Full Name (\`login\`)` |

When Greg himself uses a nickname ("co z PR-em Vlada?"), resolve it and
answer with the full name, so you both know it is the same person.

## Miss: login or name not in the matrix

0. Not every reviewer is a person. `gh api users/<login> --jq .type` →
   `Bot` or `Organization` (AI reviewers, CI apps, logins ending in
   `[bot]`) means a tool: call it "bot `<login>`" and skip the steps below.
1. Run `python3 ~/.claude/skills/work-people/scripts/sync.py` once (~5 s):
   new joiners appear on the next sync, and the script prints every GitHub
   login it still could not pair with Slack.
2. Still missing or still unpaired: `gh api users/<login> --jq .name` and
   the Slack MCP `slack_search_users` on the surname. A pair you can prove
   from both sides (the same surname, the same e-mail) goes into
   `people.overrides.tsv` as `login<TAB>U…`, then sync again.
3. Nothing proves it: write the login and say "(nie wiem kto to)". **Never
   invent a full name from a login.** A plausible but wrong name is worse than
   the login, because Greg acts on it.

`people.overrides.tsv` format: `login<TAB>slack_id[<TAB>full name]`; `-` as
the Slack ID marks an account with no Slack (bots). The third column
overrides a full name the sources get wrong.

## When sync fails

- `WORK_GITHUB_ORG is not set`: `set -a; . ~/.local/state/dotfiles/secrets/work.env; set +a`, then again.
- `slack users.list: missing_scope (needed: users:read)`: the Slack app
  behind `WORK_SLACK_POSTER_TOKEN` lost the `users:read` /
  `users:read.email` user scopes. Open the app's OAuth page through `bsk`
  and let Greg add them back and reinstall. The token string does not change.
- `gh` errors: `gh auth status`; the token needs `read:org`.

`python3 ~/.claude/skills/work-people/scripts/sync.py --selftest` checks
the name matching without the network. Run it after editing the script.
