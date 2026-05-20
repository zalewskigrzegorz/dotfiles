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
import { drawUrl, saveCanvas, type SaveSource } from "./lib/bridge";

export default function SaveCommand() {
  const { pop } = useNavigation();
  const [source, setSource] = useState<SaveSource>("ai");
  const [name, setName] = useState("");
  const [sourceId, setSourceId] = useState("");
  const [presentToken, setPresentToken] = useState("");
  const [autoDetected, setAutoDetected] = useState<string | null>(null);

  useEffect(() => {
    if (source !== "draw") return;
    (async () => {
      try {
        const tabs = await BrowserExtension.getTabs();
        const drawTab = tabs.find((t) => t.url.startsWith(drawUrl()) && t.url.includes("canvas="));
        if (drawTab) {
          const m = drawTab.url.match(/[?&]canvas=([^&]+)/);
          if (m) {
            setSourceId(m[1]);
            setAutoDetected(m[1]);
          }
        }
      } catch {
        // BrowserExtension not available — leave sourceId empty for manual paste.
      }
    })();
  }, [source]);

  return (
    <Form
      navigationTitle="Draw: Save"
      actions={
        <ActionPanel>
          <Action.SubmitForm
            title="Save Canvas"
            icon={Icon.SaveDocument}
            onSubmit={async (values) => {
              try {
                if (!values.name?.toString().trim()) {
                  await showToast({ style: Toast.Style.Failure, title: "Name is required" });
                  return;
                }
                const toast = await showToast({ style: Toast.Style.Animated, title: "Saving…" });
                const { url } = await saveCanvas({
                  source: values.source as SaveSource,
                  name: values.name.toString().trim(),
                  sourceId: values.sourceId?.toString().trim() || undefined,
                  presentToken: values.presentToken?.toString().trim() || undefined,
                });
                await open(url);
                toast.style = Toast.Style.Success;
                toast.title = "Saved";
                toast.message = values.name.toString();
                pop();
              } catch (e) {
                await showToast({
                  style: Toast.Style.Failure,
                  title: "Save failed",
                  message: e instanceof Error ? e.message : String(e),
                });
              }
            }}
          />
        </ActionPanel>
      }
    >
      <Form.Dropdown
        id="source"
        title="Source"
        value={source}
        onChange={(v) => setSource(v as SaveSource)}
        info="Where to read the scene from"
      >
        <Form.Dropdown.Item value="ai" title="AI (draw-ai.lab / scene.json)" icon={Icon.Stars} />
        <Form.Dropdown.Item value="draw" title="Draw (an existing canvas)" icon={Icon.Pencil} />
        <Form.Dropdown.Item value="present" title="Present (a live preload token)" icon={Icon.Play} />
      </Form.Dropdown>

      <Form.TextField
        id="name"
        title="Name"
        placeholder="e.g. architecture diagram v2"
        value={name}
        onChange={setName}
      />

      {source === "draw" && (
        <Form.TextField
          id="sourceId"
          title="Source canvas ID"
          placeholder={autoDetected ? `auto-detected: ${autoDetected}` : "paste canvas id or URL"}
          value={sourceId}
          onChange={setSourceId}
          info={autoDetected ? "Pulled from your open draw.lab tab" : "Open the canvas in your browser to auto-detect, or paste the id"}
        />
      )}

      {source === "present" && (
        <Form.TextField
          id="presentToken"
          title="Present token"
          placeholder="paste the ?preload=… value from the present URL"
          value={presentToken}
          onChange={setPresentToken}
        />
      )}
    </Form>
  );
}
