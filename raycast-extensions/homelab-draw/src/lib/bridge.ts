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
  name: string;
  thumbnail?: string;
  createdAt?: string;
  updatedAt?: string;
};

export type OpenTarget = "draw" | "ai" | "present";
export type SaveSource = "draw" | "ai" | "present";

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
    throw new Error(`Bridge ${path} returned non-JSON (${res.status}): ${text.slice(0, 200)}`);
  }
  if (!res.ok) {
    const err = (body as BridgeError).error ?? `Bridge ${path} failed (${res.status})`;
    throw new Error(err);
  }
  return body as T;
}

export async function listCanvases(q?: string): Promise<Canvas[]> {
  const query = q ? `?q=${encodeURIComponent(q)}` : "";
  return bridgeJson<Canvas[]>(`/canvases${query}`);
}

export async function getCanvas(id: string): Promise<Canvas & { scene: unknown }> {
  return bridgeJson(`/canvases/${encodeURIComponent(id)}`);
}

export async function openCanvas(id: string, target: OpenTarget): Promise<string> {
  const data = await bridgeJson<{ url: string }>(
    `/canvases/${encodeURIComponent(id)}/open`,
    { method: "POST", body: JSON.stringify({ target }) },
  );
  return data.url;
}

export async function saveCanvas(args: {
  source: SaveSource;
  name: string;
  sourceId?: string;
  presentToken?: string;
}): Promise<{ id: string; url: string }> {
  return bridgeJson<{ id: string; url: string }>(`/canvases`, {
    method: "POST",
    body: JSON.stringify(args),
  });
}
