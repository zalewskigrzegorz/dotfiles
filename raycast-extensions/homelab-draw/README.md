# Homelab Draw — Raycast extension

Drives `draw.mrglaszki.com` + `draw-bridge` from Raycast. Replaces the old `draw-*` shell script commands with a proper TS extension that uses `BrowserExtension.getTabs()` to detect which canvas is open in the browser.

## Commands

- **Draw: Browse** — searches canvases on `draw.mrglaszki.com` (FTS via bridge) and opens one in Draw or AI.
- **Draw: Save** — saves the live AI scene (or the canvas in the active tab) to `draw.mrglaszki.com` under a name.

## Setup (one-off)

```bash
cd ~/Code/dotfiles/raycast-extensions/homelab-draw
npm install
npm run dev   # registers the extension with Raycast in development mode
```

Leave `npm run dev` running while you iterate. Once happy, `npm run build` produces a `dist/` ready for production use; close `dev` and trigger the commands directly from Raycast.

## Preferences (Raycast → Extensions)

- `Bridge URL` — default `http://draw-bridge.mrglaszki.com`
- `Draw URL` — default `http://draw.mrglaszki.com`

## Required bridge endpoints

| Endpoint                       | Body                                       | Used by          |
|--------------------------------|--------------------------------------------|------------------|
| `GET  /canvases?q=`            | —                                          | Browse (list)    |
| `POST /canvases/:id/open`      | `{ target: "draw" \| "ai" }`                | Browse (open)    |
| `POST /canvases`               | `{ source, name, sourceId?, mode?, targetId? }` | Save        |
| `GET  /ai-scene/appstate`      | —                                          | Save (overwrite) |
| `DELETE /canvases/:id`         | —                                          | Browse (delete)  |

## Optional: "open in browser" badge

The Browse picker tags rows whose canvas id appears in any open `draw.mrglaszki.com` browser tab URL. To make that useful, add the canvas id to the URL hash in the excalidraw-full fork — something like:

```js
// when current canvas changes:
window.history.replaceState(null, "", `/#${currentCanvasId}`);
```

Until that ships, the badge will simply never light up; the picker still works.
