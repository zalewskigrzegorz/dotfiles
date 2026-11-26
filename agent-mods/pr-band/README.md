# pr-band

Keeps the current branch's pull request in view and tells you when its checks finish.

- Polls `gh pr view` every 90 s: checks passed, failed and pending, merge state, review state.
- A toast when the pending checks finish, green or red.
- `/pr-peek <number|url>`, or a PR link in your prompt, opens a pane with the PR: title, author, size, checks, and buttons to open it, read the failed logs or rebase.
- When an e2e check fails, a button downloads the Playwright failure screenshots from the run's artifacts.

Needs the GitHub CLI (`gh`) logged in. The browser button uses `open`, so it works on macOS.
