---
name: obsidian-notes
description: >-
  Save, find, update notes in Greg's Obsidian vault (iCloud, Knowlage), a
  knowledge journal HE reads: meeting/1:1 talking points, personal reference
  (sizes, measurements), ADHD/health, runbooks, checklists. Primary trigger
  "dodaj do obsidiana"; also "zapisz notatkę", "zanotuj", "żebym nie
  zapomniał", "wrzuć do vaulta", "note this down", "save a note", "znajdź
  notatkę", "dopisz do notatki". Not for agent facts (Hindsight), AI
  plans (bazgroly), session history (MemPalace), tasks (reminders). macOS only.
---

# Obsidian Notes

Vault root `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Knowlage/`, plain markdown via Read/Write/Edit. What matters is that *he* finds it later: descriptive filename, good tags, right folder; content stays simple.

| Folder | Holds |
|---|---|
| `<employer>/` | work runbooks, demo/narration scripts, sync notes; the name comes from *work-context* (`~/.local/state/dotfiles/secrets/work-context.md`), never spelled out here |
| `10 - Projects/<project>/` | active personal/side projects |
| `20 - Areas/<area>/` | life areas (HA, Home, Team, zdrowie, ogród, Prawo…) |
| `30 - Resources/<topic>/` | reference (Tech, Finanse, Hardware, DevDocs…) |
| `Brainstorms/` | brainstorm write-ups |
| `Daily Notes/YYYYMMDD.md` | append, never overwrite |
| `40 - Archive/`, `@Archive/` | read-only |

No fitting folder after a `Grep`/`Glob` over the vault → one short question, don't invent one.

## Format

Filename = natural-language title in the note's language; work notes `Topic — subtopic` (e.g. `Gateway MCP — cafe-api demo runbook.md`). Substantial notes get frontmatter (`title`, `tags: [lowercase-kebab]`, `created: YYYY-MM-DD`); quick appends don't. `[[wikilinks]]` when a related note exists.

## Rules

- Write files directly; iCloud syncs. Never commit (the vault has its own git backup).
- Don't touch `@Templates/`, `.obsidian/`, `*_attachments/`.
- Append to an existing note before creating a duplicate.
- Only when Greg asks: never dual-write here on your own when saving facts elsewhere.
