import {
  Action,
  ActionPanel,
  Detail,
  Icon,
  openExtensionPreferences,
} from "@raycast/api";
import { bridgeUrl } from "./bridge";

type SetupHelpProps = {
  title: string;
  cause: string;
  hint?: string;
  onRetry?: () => void;
};

export function SetupHelp({ title, cause, hint, onRetry }: SetupHelpProps) {
  const bridge = bridgeUrl();
  const markdown = `# ${title}

**Detected:** ${cause}

${hint ? `**Likely fix:** ${hint}\n\n` : ""}---

## How this extension works

This is a thin Raycast front-end. The actual work happens on **draw-bridge** (\`${bridge}\`),
which talks to **draw.mrglaszki.com** (Excalidraw fork) and **draw-mcp** (scene producer).

\`\`\`
Raycast  →  draw-bridge  →  draw.mrglaszki.com / draw-mcp
            (homelab)        (homelab)
\`\`\`

### What each command does

| Command | Endpoint it calls | Needs |
|---|---|---|
| **Draw: Browse** | \`GET /canvases\` + \`POST /canvases/:id/open\` | a canvas saved on the **draw.mrglaszki.com server** (not just browser localStorage) |
| **Draw: Save** | \`POST /canvases\` | \`/data/draw-mcp/scene.json\` on the homelab host (for \`source=ai\`) |

---

## Setup checklist (homelab side)

- [ ] **\`GET /canvases\`** exposed by draw-bridge — proxies \`GET /api/v2/kv\` on draw.mrglaszki.com using the Bearer JWT, returns \`[{id, title?, modifiedAt?}]\` or \`{canvases:[…]}\`.
- [ ] **Canvases persisted server-side** in excalidraw-full — otherwise canvas IDs only live in browser localStorage and the bridge 404s. Sign in / enable anonymous sync.
- [ ] **\`/data/draw-mcp/scene.json\` exists** on the homelab host — draw-mcp must write it. Without this \`source=ai\` saves ENOENT.
- [ ] *(Optional cosmetic)* In the excalidraw-full fork, on canvas switch: \`window.history.replaceState(null, "", "/#" + canvasId)\`. Lets this extension's "open in browser" badge actually light up.

Use the action panel below (\`⌘ K\`) to open extension preferences, copy curl commands, or retry.
`;

  return (
    <Detail
      navigationTitle={title}
      markdown={markdown}
      actions={
        <ActionPanel>
          {onRetry ? (
            <Action
              title="Retry"
              icon={Icon.ArrowClockwise}
              onAction={onRetry}
            />
          ) : null}
          <Action
            title="Open Extension Preferences"
            icon={Icon.Gear}
            onAction={openExtensionPreferences}
          />
          <Action.CopyToClipboard
            title="Copy: Test /canvases with Curl"
            content={`curl -s ${bridge}/canvases | jq`}
            shortcut={{ modifiers: ["cmd"], key: "c" }}
          />
          <Action.CopyToClipboard
            title="Copy: Test /import-ai-scene with Curl"
            content={`curl -s -X POST ${bridge}/import-ai-scene -H 'Content-Type: application/json' -d '{}' | jq`}
            shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
          />
          <Action.OpenInBrowser
            title="Open Draw.mrglaszki.com"
            url="https://draw.mrglaszki.com/"
            shortcut={{ modifiers: ["cmd"], key: "o" }}
          />
        </ActionPanel>
      }
    />
  );
}
