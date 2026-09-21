---
name: draw-mcp
description: Draw diagrams on Greg's Excalidraw canvas through the `draw` MCP (mcp__draw__*). Use whenever Greg says "narysuj", "wrzuć na draw", "zrób diagram", "rozrysuj opcje", "pokaż na canvasie", or asks for a picture of an architecture, a data model, a flow, or a comparison of options. Covers the gotchas that cost four redraws on 2026-09-21: which frontend the MCP renders into, why mermaid conversion silently does nothing, why shape labels ignore the font, why white boxes turn black, and how to lay out "all the options" so a team can compare them.
---

# draw-mcp

The `draw` MCP server keeps the scene server-side. Elements you create with `create_element` / `batch_create_elements` land immediately and `describe_scene` sees them. The picture Greg looks at is the canvas frontend at **`https://draw-ai.mrglaszki.com`** ("Excalidraw Canvas", with a Sync to Backend button). `https://draw.mrglaszki.com` is a plain Excalidraw with no MCP connection, drawing there changes nothing for the MCP and vice versa.

## Before drawing

1. `describe_scene` first. If the canvas holds someone's diagram, ask before `clear_canvas` (Greg often has a copy already, but ask). Never draw on top of an unrelated scene.
2. Load schemas with one `ToolSearch`: `select:mcp__draw__batch_create_elements,mcp__draw__describe_scene,mcp__draw__clear_canvas,mcp__draw__export_to_excalidraw_url`.
3. Skip `create_from_mermaid`. It only converts when the MCP frontend is open in a browser at that moment, and `describe_scene` stays empty otherwise. `agent-browser` opening `draw.mrglaszki.com` does not help, wrong app. Build elements directly, the layout is yours anyway.

## Building elements

- **One batch call.** Give shapes an `id` and bind arrows with `startElementId` / `endElementId`. Arrows still need `x` and `y` (any point near the start shape), the schema requires them.
- **Text goes in separate `text` elements, not in a shape's `text`.** A rectangle's `text` becomes a bound label that ignores `fontFamily` and renders in the hand-drawn font, which Greg cannot read. Create the rectangle without text, then a `text` element at `(x + 16, y + 12)` with `fontFamily: 2` (Helvetica) and explicit `\n` line breaks.
- **Font sizes:** title 28, band titles 20, column titles 18, box text 16, notes and pros/cons 14 to 15. Nothing under 13.
- **Dark mode inverts near-white.** `#ffffff` backgrounds render black with black text. Use `#dee2e6` for neutral boxes, `#e9ecef` for band backgrounds.
- **Palette** (matches Greg's earlier diagrams): auth/login `#eebefa` stroke `#9c36b5`, the human / database `#99e9f2` stroke `#0c8599`, org / member / app `#a5d8ff` stroke `#1971c2`, external systems and directories `#ffd8a8` stroke `#e8590c`, problems `#ffc9c9` stroke `#e03131`, good / recommended `#b2f2bb` stroke `#2f9e44`, mapping tables `#fff3bf` stroke `#f08c00`.
- **Arrow labels** as free `text` elements next to the arrow, not as the arrow's `text`, and route arrows so they do not cross a box (put the source on the side of its target).
- **Size boxes for the text:** about 22 px per line at 16 px font plus 24 px padding. A box that is too small is the most common redraw.

## Layout for "show me the options"

When Greg asks for a diagram to compare options he wants **every option drawn**, not the recommended one with the rest in a footnote. Pattern that worked:

1. Band 1: TODAY, the current structure with a red "Problems" box on the right.
2. Band 1b: AFTER, the target structure every option shares, with table names.
3. One band per decision, options as equal columns side by side (520 px wide at 1620 px canvas), each column a mini-model with the same shapes so the difference is visible, a plus/minus text block underneath, and the recommended column with `strokeColor: #2f9e44, strokeWidth: 3`.
4. A footer band with what holds regardless of the choice, and the source file in bazgroly.

## After drawing

- The `batch_create_elements` response echoes every element and can exceed the tool output limit (54 KB for 138 elements). When that happens the call still succeeded, check with `rg -o '"count": [0-9]+|"success": true' <saved result file>` instead of reading it.
- Ask Greg to look, you cannot screenshot the MCP canvas (`get_canvas_screenshot` needs the frontend open). Fix what he names with `update_element`, or clear and rebuild when the layout changes.
- `export_to_excalidraw_url` gives a shareable link when the team needs one.
