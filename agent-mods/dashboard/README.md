# dashboard

One line above the prompt with a summary of the session, and a pane with the details behind it.

- The line shows agenda items (in progress, queued, done), the current branch's PR checks, and commands running in the background.
- Press the line, or run `/dashboard`, to open the pane: the full agenda, the PR with buttons to open it, read the failed logs or rebase, and the last output line of every background command.
- A background command that ends shows a toast, ✓ or ✗.

Needs `agenda` and `pr-band`. Standup and retro counts show only with `nudge-band`, which is optional. The browser buttons use `open`, so they work on macOS.
