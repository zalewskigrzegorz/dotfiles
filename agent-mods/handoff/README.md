# handoff

Long sessions get slow and expensive. This mod helps you move on to a fresh context without losing the thread.

- When the context passes 250k tokens, a toast suggests `/handoff`.
- `/handoff` asks Claude for a 1–3 line status (where things stand, what comes next), then compacts the chat into a detailed hand-over. The session goes on with that hand-over instead of the full history.
