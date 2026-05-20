import {
  Action,
  ActionPanel,
  BrowserExtension,
  Icon,
  List,
  Toast,
  open,
  showToast,
} from "@raycast/api";
import { useEffect, useState } from "react";
import {
  drawUrl,
  listCanvases,
  presentCanvas,
  type Canvas,
} from "./lib/bridge";

type OpenTab = { id: number; url: string; title?: string; active: boolean };

export default function PresentCommand() {
  const [canvases, setCanvases] = useState<Canvas[] | null>(null);
  const [tabs, setTabs] = useState<OpenTab[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const [c, t] = await Promise.all([
          listCanvases(),
          BrowserExtension.getTabs().catch(() => [] as OpenTab[]),
        ]);
        if (cancelled) return;
        setCanvases(c);
        setTabs(t.filter((x) => x.url.startsWith(drawUrl())));
      } catch (e) {
        if (cancelled) return;
        setError(e instanceof Error ? e.message : String(e));
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <List
      isLoading={canvases === null && !error}
      searchBarPlaceholder="Search canvases…"
      navigationTitle="Draw: Present canvas"
    >
      {error ? (
        <List.EmptyView
          icon={Icon.Warning}
          title="Cannot reach draw-bridge"
          description={error}
        />
      ) : (canvases ?? []).length === 0 ? (
        <List.EmptyView
          icon={Icon.Document}
          title="No canvases yet"
          description={`Create one in ${drawUrl()} first.`}
        />
      ) : (
        (canvases ?? []).map((c) => {
          const matchingTab = tabs.find((t) => tabUrlHasCanvasId(t.url, c.id));
          const openInBrowser = Boolean(matchingTab);
          return (
            <List.Item
              key={c.id}
              icon={openInBrowser ? Icon.Eye : Icon.Document}
              title={c.title?.trim() || `Canvas ${c.id.slice(0, 8)}`}
              subtitle={c.id}
              accessories={[
                ...(openInBrowser ? [{ tag: "open", icon: Icon.Globe }] : []),
                ...(c.modifiedAt ? [{ date: new Date(c.modifiedAt) }] : []),
              ]}
              actions={
                <ActionPanel>
                  <Action
                    title="Present"
                    icon={Icon.Play}
                    onAction={() => runPresent(c)}
                  />
                  <Action
                    title="Open in Draw"
                    icon={Icon.Window}
                    shortcut={{ modifiers: ["cmd"], key: "o" }}
                    onAction={() => open(`${drawUrl()}/#${c.id}`)}
                  />
                  <Action.CopyToClipboard
                    title="Copy Canvas Id"
                    content={c.id}
                    shortcut={{ modifiers: ["cmd"], key: "." }}
                  />
                </ActionPanel>
              }
            />
          );
        })
      )}
    </List>
  );
}

function tabUrlHasCanvasId(url: string, canvasId: string): boolean {
  return url.includes(canvasId);
}

async function runPresent(canvas: Canvas) {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: "Preparing presentation…",
  });
  try {
    const url = await presentCanvas(canvas.id);
    await open(url);
    toast.style = Toast.Style.Success;
    toast.title = "Presentation opened";
    toast.message = canvas.title ?? canvas.id;
  } catch (e) {
    toast.style = Toast.Style.Failure;
    toast.title = "Present failed";
    toast.message = e instanceof Error ? e.message : String(e);
  }
}
