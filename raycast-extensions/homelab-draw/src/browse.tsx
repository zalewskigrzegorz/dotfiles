import {
  Action,
  ActionPanel,
  Alert,
  Icon,
  List,
  Toast,
  confirmAlert,
  open,
  showToast,
} from "@raycast/api";
import { useCallback, useEffect, useState } from "react";
import {
  deleteCanvas,
  listCanvases,
  openCanvas,
  type Canvas,
  type OpenTarget,
} from "./lib/bridge";
import { SetupHelp } from "./lib/setup";

export default function BrowseCommand() {
  const [searchText, setSearchText] = useState("");
  const [canvases, setCanvases] = useState<Canvas[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [reloadKey, setReloadKey] = useState(0);

  const retry = useCallback(() => {
    setError(null);
    setCanvases(null);
    setReloadKey((k) => k + 1);
  }, []);

  const remove = useCallback(
    async (c: Canvas) => {
      const ok = await confirmAlert({
        title: `Delete "${c.name?.trim() || c.id}"?`,
        message: "This cannot be undone.",
        primaryAction: { title: "Delete", style: Alert.ActionStyle.Destructive },
      });
      if (!ok) return;
      const toast = await showToast({ style: Toast.Style.Animated, title: "Deleting…" });
      try {
        await deleteCanvas(c.id);
        toast.style = Toast.Style.Success;
        toast.title = "Deleted";
        toast.message = c.name?.trim() || c.id;
        retry();
      } catch (e) {
        toast.style = Toast.Style.Failure;
        toast.title = "Delete failed";
        toast.message = e instanceof Error ? e.message : String(e);
      }
    },
    [retry],
  );

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const data = await listCanvases(searchText.trim() || undefined);
        if (!cancelled) setCanvases(data);
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : String(e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [searchText, reloadKey]);

  if (error) {
    return (
      <SetupHelp
        title="Can't reach draw-bridge"
        cause={error}
        hint="Confirm draw-bridge is running on the lab and /canvases is reachable."
        onRetry={retry}
      />
    );
  }

  return (
    <List
      isLoading={canvases === null}
      isShowingDetail
      searchBarPlaceholder="Search canvases…"
      onSearchTextChange={setSearchText}
      throttle
      navigationTitle="Draw: Browse"
    >
      {(canvases ?? []).map((c) => (
        <List.Item
          key={c.id}
          title={c.name?.trim() || `Canvas ${c.id.slice(0, 8)}`}
          icon={Icon.Document}
          accessories={c.updatedAt ? [{ date: new Date(c.updatedAt) }] : []}
          detail={
            <List.Item.Detail
              markdown={renderDetailMarkdown(c)}
              metadata={
                <List.Item.Detail.Metadata>
                  <List.Item.Detail.Metadata.Label title="ID" text={c.id} />
                  <List.Item.Detail.Metadata.Label
                    title="Name"
                    text={c.name ?? "—"}
                  />
                  {c.updatedAt && (
                    <List.Item.Detail.Metadata.Label
                      title="Modified"
                      text={new Date(c.updatedAt).toLocaleString()}
                    />
                  )}
                </List.Item.Detail.Metadata>
              }
            />
          }
          actions={
            <ActionPanel>
              <Action
                title="Open in Draw"
                icon={Icon.Pencil}
                shortcut={{ modifiers: ["cmd"], key: "1" }}
                onAction={() => runOpen(c, "draw")}
              />
              <Action
                title="Open in AI"
                icon={Icon.Stars}
                shortcut={{ modifiers: ["cmd"], key: "2" }}
                onAction={() => runOpen(c, "ai")}
              />
              <Action.CopyToClipboard
                title="Copy Canvas Id"
                content={c.id}
                shortcut={{ modifiers: ["cmd"], key: "." }}
              />
              <Action
                title="Delete Canvas"
                icon={Icon.Trash}
                style={Action.Style.Destructive}
                shortcut={{ modifiers: ["cmd"], key: "backspace" }}
                onAction={() => remove(c)}
              />
              <Action
                title="Reload"
                icon={Icon.ArrowClockwise}
                shortcut={{ modifiers: ["cmd"], key: "r" }}
                onAction={retry}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}

function renderDetailMarkdown(c: Canvas): string {
  const thumb = c.thumbnail
    ? `![thumbnail](${c.thumbnail})`
    : "_(no thumbnail yet — open the canvas in draw.lab once and it'll appear)_";
  return `# ${c.name ?? c.id}\n\n${thumb}`;
}

async function runOpen(c: Canvas, target: OpenTarget) {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: `Opening ${target}…`,
  });
  try {
    const url = await openCanvas(c.id, target);
    await open(url);
    toast.style = Toast.Style.Success;
    toast.title = `Opened in ${target}`;
    toast.message = c.name ?? c.id;
  } catch (e) {
    toast.style = Toast.Style.Failure;
    toast.title = `Open in ${target} failed`;
    toast.message = e instanceof Error ? e.message : String(e);
  }
}
