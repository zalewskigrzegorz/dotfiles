# Element off screen (local note)

Kept as its own file because `SKILL.md` is a 1:1 copy of upstream and an edit there disappears on refresh.

- After `ACTION_FAILED … offscreen` or `ACTION_NOT_SUPPORTED` on `scroll-to`, stop trying ref actions on that element.
- `agent-desktop list-windows --app <App>` gives the window bounds.
- Scroll with `--headed mouse-wheel --x <cx> --y <cy> --dy 4` in a loop, at most 3 times (`--dy 15` overshot), and `snapshot` after each step.
- `--headed` takes over the cursor, so tell Greg in one line first.
