---
description: Design work — logo, corporate identity, slides, banners, icons, social photos, brand voice, design tokens. Explicit-invoke; not a skill.
argument-hint: "[design-type] [context]"
---

# /design

Unified design entry point: logo, CIP, slides, banners, icons, social photos,
brand identity, design tokens.

**All payload paths below are relative to `~/.claude/design-assets/`.** Read only
the reference you actually need — the tree is large and loading it whole is the
thing this command exists to avoid.

## Routing

| Task | Read this |
|---|---|
| Logo creation, AI generation | `references/logo-design.md` |
| Logo styles / colors / prompts | `references/logo-style-guide.md`, `references/logo-color-psychology.md`, `references/logo-prompt-engineering.md` |
| CIP mockups, deliverables | `references/cip-design.md` |
| CIP styles / deliverables / prompts | `references/cip-style-guide.md`, `references/cip-deliverable-guide.md`, `references/cip-prompt-engineering.md` |
| Presentations, pitch decks | `references/slides-create.md`, then `references/slides-{layout-patterns,html-template,copywriting-formulas,strategies}.md` |
| Banners, covers, headers | `references/banner-sizes-and-styles.md` |
| Social media images | `references/social-photos-design.md` |
| SVG icons, icon sets | `references/icon-design.md` |
| Brand identity, voice, assets | `brand/GUIDE.md` |
| Design tokens, specs, CSS vars | `design-system/GUIDE.md` |
| Cross-domain routing notes | `references/design-routing.md` |
| shadcn/ui + Tailwind implementation | invoke the `ui-styling` **skill** — that one is still a skill, not payload |

## Generators

```bash
python3 ~/.claude/design-assets/scripts/logo/search.py "tech startup modern" --design-brief -p "BrandName"
python3 ~/.claude/design-assets/scripts/logo/generate.py --brand "TechFlow" --style minimalist --industry tech
python3 ~/.claude/design-assets/scripts/cip/search.py "tech startup" --cip-brief -b "BrandName"
python3 ~/.claude/design-assets/scripts/cip/generate.py --brand "TopGroup" --logo /path/to/logo.png --deliverable "business card" --industry "consulting"
python3 ~/.claude/design-assets/scripts/cip/render-html.py --brand "TopGroup" --industry "consulting" --images /path/to/cip-output
python3 ~/.claude/design-assets/scripts/icon/generate.py --prompt "settings gear" --style outlined
```

Logo output always gets a white background. CIP models: `flash` (default,
`gemini-2.5-flash-image`) or `pro` (`gemini-3-pro-image-preview`, 4K text).
Icons use `gemini-3.1-pro-preview` and return SVG as text, so no image API is
involved. When a script fails, fix it rather than working around it.

One-time setup: `export GEMINI_API_KEY=...` (https://aistudio.google.com/apikey)
and `pip install google-genai pillow`.

## Export

Screenshot HTML to PNG at exact dimensions with the `agent-browser` skill
(`--device-scale-factor 2` for retina). Output path convention lives in
`references/banner-sizes-and-styles.md`.

The `ui-ux-pro-max`, `frontend-design`, `ai-artist`, `ai-multimodal` and
`chrome-devtools` skills that the original claudekit text referenced are **not
installed here** — some payload files still name them. Ignore those calls and use
your own design judgment plus `agent-browser` instead.
