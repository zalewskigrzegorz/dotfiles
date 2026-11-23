---
name: draw-mcp
description: Draw diagrams on Greg's Excalidraw canvas through the `draw` MCP (mcp__draw__*). Use on "narysuj", "wrzuć na draw", "zrób diagram", "rozrysuj opcje", "pokaż na canvasie", or a picture of an architecture, data model, flow or option comparison. Covers which frontend renders, why mermaid conversion does nothing, fonts, dark-mode colours, and the "all options" layout.
---

# draw-mcp

The scene lives server-side; `describe_scene` sees what `create_element` / `batch_create_elements` made. Greg looks at **`https://draw-ai.mrglaszki.com`** ("Excalidraw Canvas", Sync to Backend). `draw.mrglaszki.com` is plain Excalidraw with no MCP link.

## Before drawing

1. `describe_scene`. Someone's diagram there → ask before `clear_canvas`; never draw over an unrelated scene.
2. One `ToolSearch`: `select:mcp__draw__batch_create_elements,mcp__draw__describe_scene,mcp__draw__clear_canvas,mcp__draw__export_to_excalidraw_url`.
3. Skip `create_from_mermaid`: it converts only while the MCP frontend is open in a browser. Build elements directly.

Mermaid written into a `.md` (pitch, doc, PR body), not this MCP: a dotted link with text needs spaces, `A -. label .-> B`; the compact form fails the AI reviewer bot.

## Elements

- **One batch call**, shapes with `id`, arrows bound by `startElementId`/`endElementId` plus required `x`,`y` near the start.
- **Text as separate `text` elements** at `(x + 16, y + 12)`, `fontFamily: 2` (Helvetica), explicit `\n`. A shape's own `text` renders in the hand-drawn font Greg can't read. Same for arrow labels; route arrows around boxes.
- Font sizes: title 28, bands 20, columns 18, box text 16, notes 14–15, never under 13.
- Size boxes: ~22 px per line at 16 px + 24 px padding (too-small boxes are the top redraw cause).
- Dark mode inverts near-white: `#dee2e6` for neutral boxes, `#e9ecef` for bands, never `#ffffff`.
- Palette (fill / stroke): auth `#eebefa`/`#9c36b5`; human, database `#99e9f2`/`#0c8599`; org, member, app `#a5d8ff`/`#1971c2`; external `#ffd8a8`/`#e8590c`; problems `#ffc9c9`/`#e03131`; recommended `#b2f2bb`/`#2f9e44`; mapping tables `#fff3bf`/`#f08c00`.

## "Show me the options"

Draw **every option**, not the recommended one plus a footnote: band TODAY (current + red Problems box) → band AFTER (shared target, table names) → one band per decision with options as equal 520 px columns (1620 px canvas), same shapes in each, plus/minus text under each, recommended column `strokeColor: #2f9e44, strokeWidth: 3` → footer with what holds regardless and the bazgroly source file.

## After drawing

- A big batch response can exceed the output limit (54 KB / 138 elements) yet succeed: `rg -o '"count": [0-9]+|"success": true' <saved file>`.
- You can't screenshot the canvas: ask Greg to look, fix with `update_element` or rebuild. `export_to_excalidraw_url` for a shareable link.
