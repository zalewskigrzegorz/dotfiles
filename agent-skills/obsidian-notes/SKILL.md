---
name: obsidian-notes
description: >-
  Save, find, and update notes in Greg's Obsidian vault (iCloud, Knowlage) —
  his personal knowledge-journal, a memory prosthetic for HIM to read, not
  agent memory. Use whenever Greg wants to not-forget something he'll look up
  himself later: what to say at a meeting or 1:1, personal reference data
  (sizes, measurements), ADHD/health knowledge, runbooks, checklists, meeting
  prep. Primary trigger: "dodaj do obsidiana" — that's how Greg usually asks.
  Also: "zapisz notatkę", "zanotuj", "żebym nie zapomniał", "wrzuć do vaulta",
  "note this down", "save a note", "znajdź notatkę", "dopisz do notatki". NOT for atomic facts the agent should recall
  (→ Hindsight retain), NOT for AI plans/analyses (→ bazgroly), NOT for
  session history (→ MemPalace), NOT for tasks (→ reminders skill). macOS
  only — the vault is an iCloud mount absent on the lab.
---

# Obsidian Notes

Greg's vault — plain markdown, read/write directly with Read/Write/Edit tools.

This is his **dziennik-wiedzy**: a simple knowledge base of things he doesn't
want to forget and will search himself — meeting/1:1 talking points, personal
reference (sizes, measurements), ADHD and health knowledge, runbooks. What
matters is that *he* can find it later: good tags, a descriptive filename,
the right folder. Content itself stays simple — whatever fits the note.

**Vault root:** `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Knowlage/`

## Where a note goes

| Folder | What lives there |
|---|---|
| `<employer>/` | Work notes: runbooks, demo scripts, sync notes, narration scripts. Folder is named after the employer — read it from *work-context* (`~/.local/state/dotfiles/secrets/work-context.md`); it is never spelled out in this public repo |
| `10 - Projects/<project>/` | Active personal/side projects (AI, MCP gateway, Academy…) |
| `20 - Areas/<area>/` | Ongoing life areas (HA, Home, Team, zdrowie, ogród, Prawo…) |
| `30 - Resources/<topic>/` | Reference material (Tech, Finanse, Hardware, DevDocs…) |
| `Brainstorms/` | Free-form brainstorm write-ups |
| `Daily Notes/YYYYMMDD.md` | Daily notes — append, don't overwrite |
| `40 - Archive/`, `@Archive/` | Old stuff — read-only, never write here |

Unsure where it fits? Look for an existing folder/note on the topic first
(`Grep`/`Glob` over the vault), and if nothing matches, ask Greg with one short
question rather than guessing a new folder into existence.

## Note format

Filename = descriptive title, natural language (PL or EN — match the note's
content language). Work notes use the `Topic — subtopic` em-dash pattern, e.g.
`Gateway MCP — cafe-api demo runbook.md`.

Frontmatter (used on substantial notes; skip for quick appends):

```markdown
---
title: Gateway MCP — cafe-api demo runbook
tags: [work, gateway-mcp, demo]
created: 2026-07-09
---
```

Tags lowercase kebab-case. `[[wikilinks]]` welcome when a related note exists.

## Rules

- **Write directly** — no Obsidian plugin/API needed; it's just files. iCloud
  syncs to his other devices on its own.
- **Never commit** — the vault has its own git auto-backup.
- **Don't touch `@Templates/`, `.obsidian/`, `*_attachments/`** — config,
  templates and embedded images, not notes.
- **Appending to an existing note beats creating a duplicate** — search first.
- **Routing boundary matters:** a fact the *agent* should recall goes to
  Hindsight, an AI plan/analysis goes to bazgroly, session history lives in
  MemPalace, a task goes to Apple Reminders. Obsidian is only for what *Greg*
  will open and read — and he drives it explicitly ("dodaj do obsidiana");
  don't dual-write here on your own initiative when saving facts elsewhere.
