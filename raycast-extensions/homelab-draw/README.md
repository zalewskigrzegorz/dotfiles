# Homelab Draw — Raycast extension

Drives `draw.lab` + `draw-bridge` from Raycast. Replaces the three `draw-*` shell script commands with a proper TS extension that uses `BrowserExtension.getTabs()` to detect which canvas is open in the browser.

## Commands

- **Draw: Present Canvas** — picks a canvas from `draw-bridge` and opens presentation mode.
- **Draw: Import AI Scene** — pushes `draw-mcp/scene.json` into a new draw.lab canvas.
- **Draw: Full Pipeline** — import AI scene → create canvas → open presentation in one go.

## Setup (one-off)

```bash
cd ~/Code/dotfiles/raycast-extensions/homelab-draw
npm install
npm run dev   # registers the extension with Raycast in development mode
```

Leave `npm run dev` running while you iterate. Once happy, `npm run build` produces a `dist/` ready for production use; close `dev` and trigger the commands directly from Raycast.

## Preferences (Raycast → Extensions)

- `Bridge URL` — default `http://draw-bridge.lab`
- `Draw URL` — default `http://draw.lab`

## Required bridge endpoints

| Endpoint                       | Body                                  | Used by             |
|--------------------------------|---------------------------------------|---------------------|
| `GET  /canvases`               | —                                     | Present (picker)    |
| `POST /scene-to-presentation`  | `{ source: "draw-lab", canvasId }`    | Present (open)      |
| `POST /import-ai-scene`        | `{}`                                  | Import AI Scene     |
| `POST /full-pipeline`          | `{}`                                  | Full Pipeline       |

`GET /canvases` is **new** — add it to `draw-bridge` so it proxies `GET draw:3002/api/v2/kv` (Bearer JWT) and returns `[{ id, title?, modifiedAt? }]` or `{ canvases: [...] }`.

## Optional: "open in browser" badge

The Present picker tags rows whose canvas id appears in any open `draw.lab` browser tab URL. To make that useful, add the canvas id to the URL hash in the excalidraw-full fork — something like:

```js
// when current canvas changes:
window.history.replaceState(null, "", `/#${currentCanvasId}`);
```

Until that ships, the badge will simply never light up; the picker still works.
