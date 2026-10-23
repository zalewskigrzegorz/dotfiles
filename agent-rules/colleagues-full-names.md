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
option says in a few words why that person.
