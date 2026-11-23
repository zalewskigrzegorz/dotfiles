---
description: A coworker is named by full name from the work-people matrix, never by GitHub login or Slack nickname
alwaysApply: true
---

# Coworkers by Full Name, Never by Login

Greg does not map GitHub logins or Slack nicknames to people. Before naming a coworker anywhere (reply, recap, standup, PR or Slack text, agent brief, popup label or `description`), load **`work-people`** and write the full name from its matrix. An unresolvable login stays a login marked "(nie wiem kto to)", never a guessed name.

- A bare first name is the same bug ("który <imię>?", c56d2e79). A reviewer option says in a few words why that person.
- A first name from a DM or quote is not an identity: check `work-people` before a draft with a ping; several matches → one popup with full names and roles.
- In a popup the full name appears once, in `question`; `description` and labels say "reviewer" or the role, never an inflected first name (2f5af49f).
