import { Toast, open, showHUD, showToast } from "@raycast/api";
import { importAiScene } from "./lib/bridge";

export default async function ImportAiCommand() {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: "Importing AI scene…",
  });
  try {
    const { url } = await importAiScene();
    await open(url);
    toast.style = Toast.Style.Success;
    toast.title = "AI scene imported";
    toast.message = url;
    await showHUD(`🎨 Draw: AI scene imported`);
  } catch (e) {
    toast.style = Toast.Style.Failure;
    toast.title = "Import failed";
    toast.message = e instanceof Error ? e.message : String(e);
  }
}
