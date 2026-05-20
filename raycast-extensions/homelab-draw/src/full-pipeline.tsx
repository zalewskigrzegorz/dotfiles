import { Toast, open, showHUD, showToast } from "@raycast/api";
import { fullPipeline } from "./lib/bridge";

export default async function FullPipelineCommand() {
  const toast = await showToast({
    style: Toast.Style.Animated,
    title: "Running full draw pipeline…",
  });
  try {
    const { presentUrl } = await fullPipeline();
    await open(presentUrl);
    toast.style = Toast.Style.Success;
    toast.title = "Pipeline OK";
    toast.message = presentUrl;
    await showHUD(`🚀 Draw: Pipeline ready`);
  } catch (e) {
    toast.style = Toast.Style.Failure;
    toast.title = "Pipeline failed";
    toast.message = e instanceof Error ? e.message : String(e);
  }
}
