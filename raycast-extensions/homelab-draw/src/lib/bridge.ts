import { getPreferenceValues } from "@raycast/api";

type Prefs = {
  bridgeUrl?: string;
  drawUrl?: string;
};

export function bridgeUrl(): string {
  const { bridgeUrl } = getPreferenceValues<Prefs>();
  return (bridgeUrl ?? "http://draw-bridge.lab").replace(/\/$/, "");
}

export function drawUrl(): string {
  const { drawUrl } = getPreferenceValues<Prefs>();
  return (drawUrl ?? "http://draw.lab").replace(/\/$/, "");
}

export type Canvas = {
  id: string;
  title?: string;
  modifiedAt?: string;
};

type BridgeError = { error: string };

async function bridgeJson<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${bridgeUrl()}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...(init?.headers ?? {}),
    },
  });
  const text = await res.text();
  let body: unknown;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(
      `Bridge ${path} returned non-JSON (${res.status}): ${text.slice(0, 200)}`,
    );
  }
  if (!res.ok) {
    const err =
      (body as BridgeError).error ?? `Bridge ${path} failed (${res.status})`;
    throw new Error(err);
  }
  return body as T;
}

export async function listCanvases(): Promise<Canvas[]> {
  const data = await bridgeJson<{ canvases: Canvas[] } | Canvas[]>("/canvases");
  return Array.isArray(data) ? data : (data.canvases ?? []);
}

export async function presentCanvas(canvasId: string): Promise<string> {
  const data = await bridgeJson<{ presentUrl: string }>(
    "/scene-to-presentation",
    {
      method: "POST",
      body: JSON.stringify({ source: "draw-lab", canvasId }),
    },
  );
  return data.presentUrl;
}

export async function importAiScene(): Promise<{
  url: string;
  canvasId?: string;
}> {
  const data = await bridgeJson<{ url: string; canvasId?: string }>(
    "/import-ai-scene",
    {
      method: "POST",
      body: JSON.stringify({}),
    },
  );
  return data;
}

export async function fullPipeline(): Promise<{
  presentUrl: string;
  canvasUrl?: string;
}> {
  const data = await bridgeJson<{ presentUrl: string; canvasUrl?: string }>(
    "/full-pipeline",
    {
      method: "POST",
      body: JSON.stringify({}),
    },
  );
  return data;
}
