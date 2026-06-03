import {
  Action,
  ActionPanel,
  BrowserExtension,
  Form,
  Icon,
  Toast,
  open,
  showToast,
  useNavigation,
} from "@raycast/api";
import { useEffect, useState } from "react";
import {
  bridgeUrl,
  drawUrl,
  getAiSceneAppState,
  presentUrl,
  saveCanvas,
  type SaveSource,
} from "./lib/bridge";

type Detected =
  | { source: "draw"; sourceId: string; label: string }
  | { source: "present"; presentToken: string; label: string }
  | { source: "ai"; label: string };

function matchesHost(url: string, base: string): boolean {
  // base may be http://host or http://host/; tolerate either.
  const baseClean = base.replace(/\/$/, "");
  return url.startsWith(baseClean + "/") || url === baseClean;
}

// Probe open Comet/Chrome tabs (via Raycast BrowserExtension) for a draw.lab
// canvas deep-link or a draw-present.lab preload link. Falls back to AI scene.
async function detectFromBrowser(): Promise<Detected> {
  try {
    const tabs = await BrowserExtension.getTabs();
    const drawTab = tabs.find(
      (t) =>
        matchesHost(t.url, drawUrl()) && /[?&]canvas=([^&]+)/.test(t.url),
    );
    if (drawTab) {
      const id = drawTab.url.match(/[?&]canvas=([^&]+)/)![1];
      return { source: "draw", sourceId: id, label: `draw.lab · canvas=${id.slice(0, 8)}…` };
    }
    const presentTab = tabs.find(
      (t) =>
        matchesHost(t.url, presentUrl()) && /[?&]preload=([^&]+)/.test(t.url),
    );
    if (presentTab) {
      const token = presentTab.url.match(/[?&]preload=([^&]+)/)![1];
      return {
        source: "present",
        presentToken: token,
        label: `draw-present.lab · preload=${token.slice(0, 8)}…`,
      };
    }
  } catch {
    // BrowserExtension API not available — fall through to AI.
  }
  return { source: "ai", label: "draw-ai (live canvas)" };
}

export default function SaveCommand() {
  const { pop } = useNavigation();
  const [name, setName] = useState("");
  const [detected, setDetected] = useState<Detected | null>(null);
  const [aiAppState, setAiAppState] = useState<{
    homelabSourceId: string | null;
    name: string | null;
  } | null>(null);
  const [mode, setMode] = useState<"new" | "update">("new");
  const [sourceOverride, setSourceOverride] = useState<SaveSource | "auto">("auto");

  useEffect(() => {
    (async () => {
      const d = await detectFromBrowser();
      setDetected(d);
      // For AI source we can detect the homelabSourceId stamp → enable update.
      if (d.source === "ai") {
        try {
          const ai = await getAiSceneAppState();
          setAiAppState(ai);
          if (ai.homelabSourceId) {
            setMode("update");
            if (ai.name) setName(ai.name);
          }
        } catch {
          setAiAppState({ homelabSourceId: null, name: null });
        }
      }
    })();
  }, []);

  // Resolve the effective source/payload from auto-detect + user override.
  function resolveArgs() {
    if (!detected) return null;
    const chosen: SaveSource =
      sourceOverride === "auto" ? detected.source : sourceOverride;
    const canOverwrite =
      chosen === "ai" && aiAppState?.homelabSourceId != null;
    const base = {
      source: chosen,
      mode: canOverwrite && mode === "update" ? ("update" as const) : ("new" as const),
      targetId:
        canOverwrite && mode === "update" ? aiAppState!.homelabSourceId! : undefined,
    };
    if (chosen === "draw" && detected.source === "draw") {
      return { ...base, sourceId: detected.sourceId };
    }
    if (chosen === "present" && detected.source === "present") {
      return { ...base, presentToken: detected.presentToken };
    }
    // Override forced a source that we can't pre-fill — bridge will 400 with a
    // clear error message ("sourceId is required …" or "presentToken is …").
    return base;
  }

  const canOverwriteAi =
    detected?.source === "ai" && aiAppState?.homelabSourceId != null;

  return (
    <Form
      isLoading={detected === null}
      navigationTitle="Draw: Save"
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Save Canvas"
            icon={Icon.SaveDocument}
            onSubmit={async (values) => {
              const trimmed = values.name?.toString().trim();
              if (!trimmed) {
                await showToast({ style: Toast.Style.Failure, title: "Name is required" });
                return;
              }
              const args = resolveArgs();
              if (!args) {
                await showToast({ style: Toast.Style.Failure, title: "Detecting source…" });
                return;
              }
              const toast = await showToast({
                style: Toast.Style.Animated,
                title: `Saving from ${args.source}…`,
              });
              try {
                const { url } = await saveCanvas({ name: trimmed, ...args });
                await open(url);
                toast.style = Toast.Style.Success;
                toast.title = "Saved";
                toast.message = trimmed;
                pop();
              } catch (e) {
                toast.style = Toast.Style.Failure;
                toast.title = "Save failed";
                toast.message = e instanceof Error ? e.message : String(e);
              }
            }}
          />
        </ActionPanel>
      }
    >
      <Form.Description
        title="Source"
        text={
          detected
            ? `Auto-detected: ${detected.label}`
            : "Detecting from open browser tabs…"
        }
      />
      <Form.Dropdown
        id="source"
        title="Override source"
        value={sourceOverride}
        onChange={(v) => setSourceOverride(v as SaveSource | "auto")}
        info={`Bridge: ${bridgeUrl()}`}
      >
        <Form.Dropdown.Item value="auto" title="Auto (from active tab)" icon={Icon.Wand} />
        <Form.Dropdown.Item value="ai" title="draw-ai (live)" icon={Icon.Stars} />
        <Form.Dropdown.Item value="draw" title="draw.lab (active canvas tab)" icon={Icon.Pencil} />
        <Form.Dropdown.Item value="present" title="draw-present.lab (active preload)" icon={Icon.Play} />
      </Form.Dropdown>
      <Form.TextField
        id="name"
        title="Name"
        placeholder="e.g. architecture diagram v2"
        value={name}
        onChange={setName}
      />
      {canOverwriteAi && (
        <Form.Dropdown
          id="mode"
          title="Save mode"
          value={mode}
          onChange={(v) => setMode(v as "new" | "update")}
          info={`Detected stamp: ${aiAppState!.homelabSourceId}`}
        >
          <Form.Dropdown.Item
            value="update"
            title={`Update existing "${aiAppState!.name ?? aiAppState!.homelabSourceId}"`}
            icon={Icon.ArrowClockwise}
          />
          <Form.Dropdown.Item value="new" title="Save as new canvas" icon={Icon.PlusCircle} />
        </Form.Dropdown>
      )}
    </Form>
  );
}
