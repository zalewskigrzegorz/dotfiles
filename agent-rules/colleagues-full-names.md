---
description: A coworker is named by full name from the work-people matrix, never by GitHub login or Slack nickname
alwaysApply: true
---

# Coworkers by Full Name, Never by Login

Greg does not map GitHub logins or Slack nicknames to people. Before naming a
coworker anywhere (reply, recap, standup, PR or Slack text, agent brief), load
the **`work-people`** skill and write the full name from its matrix. A login
nobody can resolve stays a login marked "(nie wiem kto to)", never a guessed
name.

Popup labels and `description`s count too: two first names as an option got
"który <imię>?" (c56d2e79). A bare first name is the same bug as a login, and a reviewer
option says in a few words why that person. A first name from a DM or a quote
is not an identity: check `work-people` before a draft with a ping, and when
more than one person fits, one popup with full names and roles (ccb41f8d).
In a popup the full name appears once, in `question`; `description` and labels
say "reviewer" or the role, never an inflected first name (6 sessions,
2f5af49f).
