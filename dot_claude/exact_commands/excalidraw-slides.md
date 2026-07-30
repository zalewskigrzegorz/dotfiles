---
description: Build animated slide decks in Excalidraw via the `mcp__draw__*` MCP, presented through the excalidraw-smart-presentation fork (e.g. Greg's draw.lab editor + draw-present.lab presenter). Use whenever the user asks to "make slides", "build a deck", "presentation", "prezentacja", "zrób slajdy w draw", references draw.lab / draw-present.lab, wants to animate elements between frames in Excalidraw, or wants to design 16:9 frames that morph one into the next. Covers the critical y-axis frame ordering rule, the same-name-elements animation contract, the MCP-cannot-create-frames quirk, and the auto-mode incompatibility — all of which silently bite first-time users.
---

# Excalidraw Animated Slides via `draw` MCP

How to build a slide deck on an Excalidraw canvas (Greg's setup: edit on `http://draw.lab/`, present on `http://draw-present.lab/`) using the `mcp__draw__*` tools, with elements that animate between slides.

The presenter is a fork of Excalidraw called [`excalidraw-smart-presentation`](https://github.com/excalidraw-smart-presentation/excalidraw-smart-presentation.github.io). Its conventions drive everything in this skill.

## Mental model (read this first)

- **A slide = one Excalidraw native Frame element.** Not a rectangle. A real Frame (created in the UI with the `f` key).
- **Slide order = y-axis position.** The frame highest on the canvas is slide 1, the next one below is slide 2, etc. **Horizontal placement is ignored.**
- **Animation = elements sharing a name across consecutive frames.** When Frame N and Frame N+1 both contain an element named `title`, the presenter interpolates position/size/color/rotation/opacity between them (300 ms linear, not configurable). To prevent animation, give them different names.
- **Duplication preserves names.** `Ctrl+Shift+D` ("Duplicate into next frame") is the intended workflow for keeping an element animated across slides — it copies the element into the next frame at the same position with the same name.
- **Aspect ratio per frame is editable** in Canvas & Shape Properties (`Alt+/` with the frame selected). 1920×1080 is a safe default for video-style 16:9 decks.

## Critical gotchas (these silently bite)

### 1. The MCP cannot create native Frame elements — but the canvas HTTP API can

`mcp__draw__create_element` / `mcp__draw__batch_create_elements` accept only `rectangle, ellipse, diamond, arrow, text, freedraw, line, image`. **Not `frame`.** `mcp__draw__import_scene` reports "Imported 1 element" for a frame payload but the upstream serializer silently strips it. Both routes are dead ends.

**Working route (discovered 2026-06-03):** POST directly to `http://draw-ai.lab/api/elements/sync` with the full elements array including `{type: "frame", ...}` entries. The upstream excalidraw-mcp HTTP server accepts frames; only the MCP wrapper filters them.

Pattern:

1. `GET http://draw-ai.lab/api/elements` → current elements array
2. For each element whose `(x, y)` falls inside a planned slide bbox, set `frameId` to the new frame's id (parenting)
3. Append `type: "frame"` elements with full Excalidraw frame schema (id, type, x, y, width, height, angle, strokeColor, backgroundColor, fillStyle, strokeWidth, strokeStyle, roughness, opacity, groupIds, frameId:null, index, roundness:null, seed, version, versionNonce, isDeleted, boundElements, updated, link, locked, name)
4. `POST http://draw-ai.lab/api/elements/sync` with `{elements: [...new full list...], timestamp: "..."}`

Same POST mechanism is also how you set `customData.name` for animation (see gotcha 7).

**Race condition gotcha:** any open `draw-ai.lab` browser tab pushes its local state back to the server roughly continuously (Excalidraw realtime sync). It does NOT include frame elements (or custom `customData`) in its push payload, so direct POSTs get clobbered seconds later. Two workable patterns:

- **Tab closed during POST:** ask Greg to close the `draw-ai.lab` tab, run the POST, ask Greg to reopen — fresh load pulls server state including frames.
- **Transfer script:** Greg maintains a local script that snapshots `draw-ai.lab/api/elements` and propagates the snapshot to `draw-present.lab`. After your POST, just tell Greg to run his transfer script before the browser overwrites — he handles the rest.

### 2. Auto-mode (`shift_auto`) blocks mutating draw MCP calls

If the user is in Claude Code auto-mode, `batch_create_elements`, `create_element`, `delete_element`, and any other write tool returns:

```
Mutating MCP call: mcp__draw__... [BLOCKED by auto-mode policy. STOP — do not retry...]
```

Read-only tools (`describe_scene`, `get_resource`, `query_elements`, `get_canvas_screenshot`, `read_diagram_guide`) still work. Tell the user to **Shift+Tab** to default mode before slide work; everything else can stay in auto.

### 3. Frames are ordered top-to-bottom, NOT left-to-right

The single most common mistake. If you place slides side-by-side (incrementing x), the presenter still orders them by y — meaning all frames at the same y are siblings, and the order is undefined. **Always stack vertically**: each new slide at a larger y than the previous.

Suggested layout: slide N at `y = y0 + N * (1080 + GAP)` where `GAP` ≈ 200px.

### 4. The canvas may have other content. Don't wipe it.

Greg's draw.lab canvas usually has unrelated drawings (architecture sketches, notes, screenshots) that he's actively using. **Never clear the canvas.** Before adding slides:

1. Call `describe_scene` to read existing elements + bounding box.
2. Pick an empty region far from existing content (e.g. `y0 = max(existing_y) + 2000`).
3. Place slides there. Greg can move them later.

### 5. Custom element `id` ≠ Excalidraw element `name`

Excalidraw element **names** (set in Canvas & Shape Properties) drive animation. The `id` you pass to `create_element` is just a handle for arrow binding and later edits — it does **not** become the animation name. The MCP currently has no way to set Excalidraw names; the user does it via the UI.

In practice this means: if you want elements to animate between frames, your only reliable option is for the user to use `Ctrl+Shift+D` to duplicate them into the next frame (which copies the name). MCP-created elements in different frames will not animate together because each one gets a fresh auto-generated name.

For most decks this is fine — animations are an enhancement. Focus on getting the static composition right first.

### 6. Three URLs, three Excalidraw instances, three localStorages

Greg's setup runs three separate Excalidraw deployments behind Traefik:

- **`draw-ai.lab`** — `ghcr.io/yctimlin/mcp_excalidraw-canvas` fork. The ONLY one with `/api/elements` + `/api/elements/sync` HTTP API. MCP `mcp__draw__*` writes here. **This is the only target you need.**
- **`draw.lab`** — vanilla Excalidraw SPA. No API. Greg uses for manual sketching.
- **`draw-present.lab`** — `excalidraw-smart-presentation` SPA fork. No API. Has the Present feature.

The three do NOT share state (different domains → different localStorage). To get a deck from MCP into the presenter, Greg has a local transfer script that moves elements from draw-ai.lab to draw-present.lab. **You never need to write `.excalidraw` files for the user to manually open or paste.** Just write to draw-ai.lab via MCP; Greg runs his script.

Compose source: `/Users/greg/Code/home-lab/services/draw-mcp/{compose.yaml,Dockerfile.canvas,Dockerfile.mcp,canvas-runner.mjs,http-entry.mjs}`. Canvas state file: `/data/scene.json` inside container, mounted from `<home-lab>/data/draw-mcp/` on the lab host (not on Greg's mac).

### 7. Smart-presentation animation contract — `customData.name`, NOT Excalidraw `name`

Inspected source: `excalidraw-smart-presentation.github.io/excalidraw-app/presentation/{Presentation.tsx, animation.ts}`.

- **Slide order** is determined by `frame.y` (`res.sort((e1, e2) => e1.y - e2.y)` in Presentation.tsx). Frames at identical `y` produce undefined ordering — always stack vertically with strictly different `y`.
- **Slide content** is selected by `e.frameId === frame.id`. Children get repositioned relative to their frame origin via `e.x - frame.x, e.y - frame.y` before being handed to the inner Excalidraw renderer.
- **Animation key** is `getBaseKey(e) = ${e.type}-${e.customData?.name ?? e.id}`. Same key across consecutive frames → element morphs (numerical interp on `x, y, width, height, opacity, strokeWidth, angle, roughness, fontSize`; color interp on `strokeColor, backgroundColor`; point interp for linear elements). Different keys → element fades out from old frame and fades in on new frame.
- **MCP cannot set `customData.name`.** `create_element` / `batch_create_elements` only expose top-level fields; the resulting element gets `customData.name = <element_id>` (i.e. always unique). To get matching names, **post-process via direct API POST** to `draw-ai.lab/api/elements/sync` with the elements list whose target items have their `customData.name` overwritten to a shared string. Same goes for any field MCP doesn't expose (groupIds, locked, link, fontFamily for some text variants, etc.).
- **Duplicate-into-next-frame UI shortcut** (`Ctrl+Shift+D`) propagates `customData.name` from source → duplicate, which is why the README recommends it. The MCP `duplicate_elements` tool does NOT preserve it (it regenerates `customData.name` to the new element's id).

### 8. Known bug — same-name animation can hide elements on landed slide

Symptom: an element with `customData.name` matched across two consecutive frames is visible during the 300ms transition but invisible once the slide settles.

Suspected cause: arrows with `width: 0` (e.g., points `[[0,0],[0,H]]`) get interpolated to width=0 at progress=1, and the renderer treats zero-bbox arrows as non-drawable. Workaround: always give arrows a positive `width` (≥4) plus slightly-diagonal `points`, e.g. `width: 20, height: 260, points: [[0,0],[20,260]]`.

For purely-static elements that you don't want to animate, give them unique `customData.name` (defaults to element id when MCP-created, so this is the implicit default).

### 9. Excalidraw file requirements that bite when generating .excalidraw JSON

The import validator (`loadFromBlob` in `packages/excalidraw/data/blob.ts`) is strict and silent — most failures surface as a generic `"Error: invalid file"` modal with no console hint about which element broke things.

**Required structure:**

- Top-level: `{type: "excalidraw", version: 2, source: "...", elements: [...], appState: {...}, files: {}}`.
- Every element MUST have a `customData` field (use `{}` or `{"name": "<id>"}` — not missing).
- Every element's `index` (fractional indexing string for z-order) MUST be unique. A loop bug that gives every element the same `index: "a000"` will make Excalidraw hang on "Wczytywanie sceny..." / "Loading scene...".

**Critical arrow invariant (discovered 2026-06-03 LDE2 session via bisection):**

For `type: "arrow"`, the element's `width` and `height` MUST equal the actual extent of its `points` array, computed as:

```python
xs = [p[0] for p in points]
ys = [p[1] for p in points]
width  = max(abs(min(xs)), abs(max(xs)))
height = max(abs(min(ys)), abs(max(ys)))
```

If `width`/`height` disagree with the `points` extent — typically because a helper applies `max(width, 4)` padding to avoid zero-sized bounding boxes — Excalidraw's restore path throws inside the validation chain and the whole file fails to import with "Error: invalid file". **Do not floor width/height to a minimum — let zero be zero**; Excalidraw renders the arrow fine when points carry the actual geometry.

Same likely applies to `line` elements but Greg's working exports never contained any, so the constraint wasn't independently verified. To be safe, apply the same `width = extent(points.x)` rule to lines.

**Bisection workflow when "Error: invalid file" surfaces:**

1. Start from a known-working `.excalidraw` export (e.g., the user's own previous export, opened and re-saved).
2. Replace its `elements: [...]` array with progressively larger subsets of your generated elements: first 5 rectangles, then all rectangles, then add text, then arrows, then frames, then lines.
3. Whichever step first triggers the error is the type that's malformed. Inspect that type's fields against a known-good element of the same type.
4. Look for type mismatches (`int` vs `float` is fine), value invariants (width must match points extent), and required-field omissions.

Even with everything correct, the user's `Import URL` flow may still fail for unrelated reasons — but `File → Open` or drag-drop of a properly-shaped `.excalidraw` file always works once the per-element invariants are satisfied.

## Standard slide template (16:9, 1920×1080)

When in doubt, use this layout. Origin `(x0, yN)` where `yN = y0 + N * 1280`.

```
+----------------------------------------------+
|  Top label   (small, gray, 32-40px)          |
|                                              |
|                                              |
|          HERO CONTENT                        |
|       (title, big number, diagram)           |
|                                              |
|                                              |
|  Footer / annotation (small, gray, 24-32px)  |
+----------------------------------------------+
```

Slide content lives inside the 1920×1080 rectangle that the user will later wrap in a Frame. Pad ~80px from all edges so the Frame's chrome doesn't clip text.

**Fonts** (from `mcp__draw__read_diagram_guide` palette, but slide-tuned):
- `fontFamily: 5` (Excalifont) — default for titles, body, prose. Hand-drawn vibe matches Excalidraw aesthetic.
- `fontFamily: 3` (Cascadia mono) — for numbers, code, terminal output, timestamps, IDs.
- Sizes: hero number 180-260, title 60-80, subtitle 48-60, body 24-32, captions 16-24. Slides are zoomed out in present mode, so go bigger than you'd expect for a normal diagram.

**Colors**: call `mcp__draw__read_diagram_guide` once at the start of a session to get the full palette. The light-pastel fills (`#ffd8a8`, `#a5d8ff`, `#eebefa`, `#b2f2bb`, `#ffc9c9`) pair well as card backgrounds; pair each with its matching stroke color from the guide.

**Roughness**: `roughness: 0` (clean rectangle) for slide backgrounds and frames. `roughness: 1` (hand-drawn) for callout cards inside the slide — it adds visual hierarchy.

## Workflow (step-by-step) — CONFIRMED WORKING 2026-06-03

1. **Read diagram guide** — `mcp__draw__read_diagram_guide` once per session for color palette.
2. **Inspect canvas** — `mcp__draw__describe_scene` to find existing content and pick an empty y-range.
3. **Pick a vertical layout** — `y0 = 2000`, `yN = y0 + N*(H+GAP)` where H=1080, GAP=200. **Always vertical**, smart-presentation orders by y.
4. **Batch-create content via MCP** — `mcp__draw__batch_create_elements` with stable ids (`s1-bg`, `s1-title`, etc). For a full 8-slide deck, two batches of ~40-60 elements each is fine. Use width > 0 on arrows (avoid disappearing-at-progress=1 bug).
5. **Wrap into native frames via direct API POST** — MCP can't create frame elements; the canvas HTTP API can. Run a Python script that:
   - GETs `http://draw-ai.lab/api/elements`
   - For each element whose origin falls inside a slide's bbox, sets `frameId` to that slide's frame id
   - Appends 1 `type: "frame"` element per slide (with full Excalidraw frame schema — id, x, y, width, height, name, plus all required defaults — see `/tmp/wrap-8frames.py` from the 2026-06-03 LDE2 session for a reference implementation)
   - POSTs the whole element list back to `/api/elements/sync`
6. **Greg's transfer step (private)** — Greg runs his local script to propagate `draw-ai.lab` → `draw-present.lab`. You don't trigger it; just tell him "frames are in, run your transfer".
7. **User presents** — opens `draw-present.lab` → Present button bottom-right (or arrow keys). Done.

**For animation** (optional): after step 5, also set `customData.name` on matching elements across consecutive frames in the same POST. Smart-presentation interpolates same-name elements between adjacent frames (300ms linear).

## Animation patterns

Use sparingly — bare static slides are clearer than over-animated ones. When you do want animation:

- **Persistent header/footer across slides**: Have the user create the header once in slide 1, then `Ctrl+Shift+D` to clone it into each subsequent slide. The header will appear "static" in present mode (zero animation) because identical positions interpolate to no movement.
- **Element growing/morphing**: clone via `Ctrl+Shift+D`, then resize/recolor in the next frame. The presenter interpolates between the two states.
- **Element entering/exiting**: create a fresh element (different name) in the destination frame — it appears without animation. To make it fade in, use opacity 0 on the source-frame counterpart with the same name, opacity 100 on the destination.
- **Killing unwanted animations**: if two elements happen to share a name (e.g. two text labels both default-named "text"), the presenter will animate between them even if they should be unrelated. Have the user rename one via Canvas & Shape Properties.

## When *not* to use this skill

- Single static diagram, no presentation needed → just use `mcp__draw__*` directly with the diagram guide.
- HTML/Chart.js slides, talk-style presentation → use the `slides` skill instead, which targets a different output format.
- Video walkthrough without slides (pure screencast of a real app) → no slide tooling needed; record the app directly.

## Quick reference

| Need | Tool / Action |
|---|---|
| Read existing canvas | `mcp__draw__describe_scene` |
| Read full element JSON | `mcp__draw__get_resource` (resource: `elements`) |
| Create slide content | `mcp__draw__batch_create_elements` |
| Edit existing element | `mcp__draw__update_element` |
| Delete element | `mcp__draw__delete_element` |
| Save rollback point | `mcp__draw__snapshot_scene` (name it) |
| Restore | `mcp__draw__restore_snapshot` |
| Zoom to slide | `mcp__draw__set_viewport` (scrollToElementId + zoom) |
| Screenshot for verification | `mcp__draw__get_canvas_screenshot` |
| Wrap selection in Frame | **User action**, `Ctrl+Shift+F` in UI |
| Duplicate into next frame (animated) | **User action**, `Ctrl+Shift+D` in UI |
| Rename element | **User action**, Canvas & Shape Properties (`Alt+/`) |
| Start presenting | **User action**, "Present" button bottom-right, or command palette |
| Navigate in present mode | `→` / `←` arrow keys, or click sides |
| Present from specific slide | Select that frame first, then Present |

## Upstream documentation

Smart-presentation README: <https://github.com/excalidraw-smart-presentation/excalidraw-smart-presentation.github.io#excalidraw-smart-presentation>

Limitations to be aware of (from upstream): animation duration is fixed at 300ms linear; presentations can't be shared as a link (the canvas must be opened in the smart-presentation Excalidraw fork to present).
