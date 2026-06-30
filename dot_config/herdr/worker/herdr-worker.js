#!/usr/bin/env bun
// herdr-remote Mac-side worker.
//
// Kandji MDM reverts macOS Remote Login (sshd) to Off, so INBOUND ssh to the Mac
// is unreliable. This worker instead connects OUTBOUND over a single WebSocket to
// the lab relay, registers itself as the worker for this host, pushes a full agent
// snapshot every ~2s, and executes pane commands locally via the herdr CLI.
//
// Wire protocol (one JSON object per line, no envelope/ack) — see the locked design
// doc 2026-06-30-herdr-mac-worker.md. This worker is the producer for ONE host slice;
// the relay merges it into the full cross-host store the PWA renders.

const HERDR = process.env.HERDR_BIN || "/opt/homebrew/bin/herdr";
const RELAY_WS = process.env.HERDR_RELAY_WS || "ws://herdr-ws.lab/";
const HOST = process.env.HERDR_WORKER_HOST || "NeuroMancer";
const TOKEN = process.env.HERDR_RELAY_TOKEN || "";

const SNAPSHOT_INTERVAL_MS = 2000;
const RECONNECT_MIN_MS = 1000;
const RECONNECT_MAX_MS = 30000;
const HERDR_TIMEOUT_MS = 15000;

// Mirror of the relay's CHROME_RE — strips herdr/agent UI chrome from the blocked
// prompt so the PWA shows the actual question, not status-line / spinner noise.
const CHROME_RE = new RegExp(
  "^[\\s─━═_—│|└◔◑◕●]+$" +
    "|Kiro\\s[·•]" +
    "|esc to cancel" +
    "|type to queue" +
    "|^\\s*[◔◑◕●]\\s+(Shell|Bash)"
);

const log = (...a) => console.log(new Date().toISOString(), ...a);
const errlog = (...a) => console.error(new Date().toISOString(), ...a);

const basename = (p) => {
  if (!p) return "";
  const parts = String(p).split("/").filter(Boolean);
  return parts.length ? parts[parts.length - 1] : "";
};

// --- herdr CLI -------------------------------------------------------------

// Run herdr with args. Returns stdout string (trimmed) or "" on any failure.
// Never throws — callers run inside the snapshot loop / message handler and must
// not let a single bad invocation tear down the connection.
async function runHerdr(args) {
  try {
    const proc = Bun.spawn([HERDR, ...args], {
      stdout: "pipe",
      stderr: "pipe",
      stdin: "ignore",
    });
    const timer = setTimeout(() => {
      try {
        proc.kill();
      } catch (_) {}
    }, HERDR_TIMEOUT_MS);
    const out = await new Response(proc.stdout).text();
    await proc.exited;
    clearTimeout(timer);
    return out.trim();
  } catch (e) {
    errlog("herdr spawn failed:", args.join(" "), String(e));
    return "";
  }
}

// `herdr pane list` → array of agent dicts (locked-protocol fields), agent panes only.
async function listAgents() {
  const raw = await runHerdr(["pane", "list"]);
  if (!raw) return [];
  let data;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    errlog("pane list JSON parse failed:", String(e));
    return [];
  }
  const panes = data?.result?.panes;
  if (!Array.isArray(panes)) return [];
  const agents = [];
  for (const p of panes) {
    if (!p || !p.agent) continue; // skip non-agent shell panes
    const cwd = p.cwd || "";
    agents.push({
      pane_id: p.pane_id,
      agent: p.agent || "",
      status: p.agent_status || "unknown",
      cwd,
      project: basename(cwd),
      host: HOST,
    });
  }
  return agents;
}

// Read a pane's recent scrollback, strip chrome, keep the last ~6 meaningful lines.
// Used to populate the `prompt` field for blocked agents (the relay needs it to emit
// `blocked` frames with the real question text).
async function readBlockedPrompt(paneId) {
  const raw = await runHerdr(["pane", "read", paneId, "--lines", "20", "--source", "recent"]);
  if (!raw) return "";
  const lines = raw
    .split("\n")
    .filter((l) => l.trim() && !CHROME_RE.test(l));
  return lines.slice(-6).join("\n");
}

// Raw scrollback for a read_pane command reply (no chrome filtering — the PWA wants
// the verbatim pane content).
async function readPaneRaw(paneId, lines) {
  const n = Number.isFinite(Number(lines)) ? String(lines) : "50";
  const out = await runHerdr(["pane", "read", paneId, "--lines", n, "--source", "recent"]);
  // herdr prints a JSON error (e.g. {"code":"pane_not_found"}) to stdout with exit 0
  // for a dead pane. Don't forward that as scrollback — show empty instead (M3).
  if (out.trimStart().startsWith('{"code":')) return "";
  return out;
}

// --- WebSocket lifecycle ---------------------------------------------------

let ws = null;
let snapshotTimer = null;
let reconnectDelay = RECONNECT_MIN_MS;
let reconnectScheduled = false;
let sendingSnapshot = false;

function stopSnapshotLoop() {
  if (snapshotTimer) {
    clearInterval(snapshotTimer);
    snapshotTimer = null;
  }
}

function safeSend(obj) {
  if (!ws || ws.readyState !== WebSocket.OPEN) return false;
  try {
    ws.send(JSON.stringify(obj));
    return true;
  } catch (e) {
    errlog("ws send failed:", String(e));
    return false;
  }
}

async function sendSnapshot() {
  if (sendingSnapshot) return; // a slow herdr call shouldn't let ticks pile up
  if (!ws || ws.readyState !== WebSocket.OPEN) return;
  sendingSnapshot = true;
  try {
    const agents = await listAgents();
    // Worker pre-reads blocked panes so the relay can emit `blocked` frames.
    for (const a of agents) {
      if (a.status === "blocked") {
        a.prompt = await readBlockedPrompt(a.pane_id);
      }
    }
    safeSend({ type: "host_snapshot", host: HOST, agents });
  } catch (e) {
    errlog("snapshot build failed:", String(e));
  } finally {
    sendingSnapshot = false;
  }
}

function startSnapshotLoop() {
  stopSnapshotLoop();
  // Fire one immediately so the dashboard populates without a 2s wait.
  sendSnapshot();
  snapshotTimer = setInterval(sendSnapshot, SNAPSHOT_INTERVAL_MS);
}

// Inbound commands from the relay (forwarded PWA actions). Each maps to one local
// herdr invocation. read_pane additionally replies with a pane_content frame.
async function handleCommand(msg) {
  const type = msg?.type;
  const paneId = msg?.pane_id;
  switch (type) {
    case "read_pane": {
      if (!paneId) return;
      const content = await readPaneRaw(paneId, msg.lines);
      safeSend({ type: "pane_content", pane_id: paneId, content });
      break;
    }
    case "respond": {
      if (!paneId) return;
      // respond = submit an answer; worker appends the newline to send it.
      await runHerdr(["pane", "send-text", paneId, (msg.text ?? "") + "\n"]);
      break;
    }
    case "send_keys": {
      if (!paneId) return;
      const keys = Array.isArray(msg.keys) ? msg.keys.map(String) : [];
      if (!keys.length) return;
      await runHerdr(["pane", "send-keys", paneId, ...keys]);
      break;
    }
    case "send_text": {
      if (!paneId) return;
      // send_text = literal text, NO newline.
      await runHerdr(["pane", "send-text", paneId, msg.text ?? ""]);
      break;
    }
    // Relay→PWA frames we may see echoed; ignore.
    case "agents":
    case "blocked":
    case "pane_content":
      break;
    default:
      break;
  }
}

function scheduleReconnect() {
  if (reconnectScheduled) return;
  reconnectScheduled = true;
  const delay = reconnectDelay;
  log(`reconnecting in ${delay}ms`);
  setTimeout(() => {
    reconnectScheduled = false;
    connect();
  }, delay);
  // Exponential backoff, capped.
  reconnectDelay = Math.min(reconnectDelay * 2, RECONNECT_MAX_MS);
}

function connect() {
  stopSnapshotLoop();
  const url = RELAY_WS + (TOKEN ? "?token=" + encodeURIComponent(TOKEN) : "");
  log(`connecting to ${RELAY_WS} as host=${HOST}`);
  try {
    ws = new WebSocket(url);
  } catch (e) {
    errlog("WebSocket construct failed:", String(e));
    scheduleReconnect();
    return;
  }

  ws.addEventListener("open", () => {
    log("connected");
    reconnectDelay = RECONNECT_MIN_MS; // reset backoff on a clean connect
    if (safeSend({ type: "worker_hello", host: HOST })) {
      startSnapshotLoop();
    } else {
      // Couldn't even send hello — treat as a failed connect.
      try {
        ws.close();
      } catch (_) {}
    }
  });

  ws.addEventListener("message", (ev) => {
    let msg;
    try {
      msg = JSON.parse(typeof ev.data === "string" ? ev.data : String(ev.data));
    } catch (_) {
      return; // ignore non-JSON
    }
    handleCommand(msg).catch((e) => errlog("command handler error:", String(e)));
  });

  ws.addEventListener("close", (ev) => {
    log(`disconnected (code=${ev?.code ?? "?"})`);
    stopSnapshotLoop();
    scheduleReconnect();
  });

  ws.addEventListener("error", (ev) => {
    errlog("ws error:", ev?.message || ev?.error || "unknown");
    // 'close' fires after 'error' and owns the reconnect; don't double-schedule.
  });
}

// --- entry -----------------------------------------------------------------

// --dry: parse + basic self-check, then exit (used for syntax verification offline).
if (process.argv.includes("--dry")) {
  log("dry run ok", { HERDR, RELAY_WS, HOST, hasToken: !!TOKEN });
  process.exit(0);
}

process.on("SIGINT", () => process.exit(0));
process.on("SIGTERM", () => process.exit(0));
// Never let an unexpected rejection kill the daemon.
process.on("unhandledRejection", (r) => errlog("unhandledRejection:", String(r)));
process.on("uncaughtException", (e) => errlog("uncaughtException:", String(e)));

connect();
