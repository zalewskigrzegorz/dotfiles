import {
  Action,
  ActionPanel,
  Form,
  Icon,
  Toast,
  open,
  showToast,
  useNavigation,
} from "@raycast/api";
import { useEffect, useState } from "react";
import { getAiSceneAppState, saveCanvas } from "./lib/bridge";

export default function SaveCommand() {
  const { pop } = useNavigation();
  const [name, setName] = useState("");
  const [detect, setDetect] = useState<{ homelabSourceId: string | null; name: string | null } | null>(null);
  const [mode, setMode] = useState<"new" | "update">("new");

  useEffect(() => {
    (async () => {
      try {
        const d = await getAiSceneAppState();
        setDetect(d);
        if (d.homelabSourceId) {
          setMode("update");
          if (d.name) setName(d.name);
        }
      } catch {
        setDetect({ homelabSourceId: null, name: null });
      }
    })();
  }, []);

  const canOverwrite = detect?.homelabSourceId != null;

  return (
    <Form
      navigationTitle="Draw: Save AI scene"
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
              const toast = await showToast({ style: Toast.Style.Animated, title: "Saving..." });
              try {
                const { url } = await saveCanvas({
                  name: trimmed,
                  mode: canOverwrite && values.mode === "update" ? "update" : "new",
                  targetId: canOverwrite && values.mode === "update" ? detect!.homelabSourceId! : undefined,
                });
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
      <Form.TextField
        id="name"
        title="Name"
        placeholder="e.g. architecture diagram v2"
        value={name}
        onChange={setName}
      />
      {canOverwrite && (
        <Form.Dropdown
          id="mode"
          title="Save mode"
          value={mode}
          onChange={(v) => setMode(v as "new" | "update")}
          info={`Detected source canvas: ${detect!.homelabSourceId}`}
        >
          <Form.Dropdown.Item value="update" title={`Update existing "${detect!.name ?? detect!.homelabSourceId}"`} icon={Icon.ArrowClockwise} />
          <Form.Dropdown.Item value="new" title="Save as new canvas" icon={Icon.PlusCircle} />
        </Form.Dropdown>
      )}
    </Form>
  );
}
