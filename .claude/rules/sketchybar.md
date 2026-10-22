---
paths:
  - "dot_config/sketchybar/**"
  - "bin/sketchybar*"
  - "bin/sketchybar*/**"
---

# sketchybar (Mac)

- **Verify a change with `bin/sketchybar-restart`**, not `--reload` plus one `--query`. Its probe checks every expected item and fails when sketchybar sits above 20% cpu, which is how an event loop shows (2026-10-19: a `forced` handler calling `--update` held 85% cpu while every item looked fine). Add new items to its `EXPECTED` list.
- **`--update` fires `forced`.** Never call it (or `--trigger forced`) from a `forced` handler unless a state change guards it, as `items/compact.lua` does.
- **Per-display questions start with `--query displays`.** An item's `geometry.drawing` is global; which screens show it is `associated_display_mask` (bit n = display n), and `display=2,3` takes a list. "The title still shows on the laptop" was two monitors plugged in, ~6 calls to find.
- **Laptop vs monitor layout lives in `items/compact.lua`**, per display in one process: `spaces.lua` builds two workspace sets (`item.N` full, `item.N.s` small) and `compact.lua` pins them with `display=<arrangement ids>`, plus hides the cpu/mem/wifi widgets and the app title on the laptop when monitors are attached. The watcher updates both sets. A second sketchybar instance, or hiding other monitors' workspaces on the laptop, was rejected (2026-10-21). `settings.compact` (widget text) is still laptop-only-screen.
- **A hidden item (`drawing=off`) gets no custom events**, so `--trigger` never wakes it. Its producer (launchd job, `scriptc` binary) sets it with `--set`; event + `subscribe` only for visible items. Pattern: `items/agent_monitors.lua` (56927b0a).
- **A chip is one number or a short progress mark** (`5 ◔×2 ✓4`); step names, titles and deploy names go to the popup on click. An alert row always says what happened and to what. Check the width on the big monitor, not just the laptop ("nie dopuszczalne i to na dużym ekranie").
- **A green `bin/sketchybar-restart` does not prove the watcher hears events.** A closing old instance once removed the socket the new one listened on. After a watcher change or restart: `test -S /tmp/sketchybar-watcher.sock` as well (95b4a5bd).
- **A new app's icon and workspace come from its category**, not its name: `mdls -name kMDItemAppStoreCategory <App>.app` or `LSApplicationCategoryType` in `Info.plist`. No category → "propozycja: Boom = spotkania" in one line before writing `icons.go` (a1108d95).
