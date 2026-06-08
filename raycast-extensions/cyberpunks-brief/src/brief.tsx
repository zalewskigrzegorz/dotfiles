import {
  Action,
  ActionPanel,
  Detail,
  Icon,
  Toast,
  getPreferenceValues,
  showToast,
} from "@raycast/api";
import { spawn } from "child_process";
import { useEffect, useState } from "react";
import { BRIEF_PROMPT, cleanBriefOutput } from "./prompt";

interface Preferences {
  claudeBin: string;
  claudeModel: string;
  elevenlabsApiKey: string;
  voiceId: string;
  voiceModel: string;
}

type State =
  | { kind: "loading" }
  | { kind: "ready"; text: string; raw: string; tookMs: number }
  | { kind: "error"; message: string; raw?: string };

// Runs `claude -p --model <model>` headlessly, piping the prompt via stdin.
// Captures stdout (the briefing) and stderr (any tool/permission noise).
//
// We launch through a login shell (`/bin/zsh -lc`) so the subprocess inherits
// the user's full PATH, HOME, USER, and shell-rc side effects — including
// whatever lets `claude` reach the macOS keychain to read its OAuth session.
// Spawning `claude` directly from the Raycast Node host loses the keychain
// access scope and the binary reports "Not logged in · Please run /login".
function shellQuote(s: string): string {
  return `'${s.replace(/'/g, "'\\''")}'`;
}

async function runClaude(
  bin: string,
  model: string,
  prompt: string,
): Promise<{ stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    const modelFlag = model ? ` --model ${shellQuote(model)}` : "";
    const cmd = `${shellQuote(bin)} -p${modelFlag}`;
    const proc = spawn("/bin/zsh", ["-lc", cmd], {
      stdio: ["pipe", "pipe", "pipe"],
      env: {
        ...process.env,
        HOME: process.env.HOME || `/Users/${process.env.USER || "greg"}`,
      },
    });

    let stdout = "";
    let stderr = "";

    proc.stdout.on("data", (chunk: Buffer) => {
      stdout += chunk.toString();
    });
    proc.stderr.on("data", (chunk: Buffer) => {
      stderr += chunk.toString();
    });

    proc.on("error", (err) => reject(err));
    proc.on("close", (code) => {
      if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        reject(
          new Error(
            `claude exited with code ${code}\n--- stderr ---\n${stderr.trim() || "(empty)"}\n--- stdout ---\n${stdout.trim().slice(0, 1000) || "(empty)"}`,
          ),
        );
      }
    });

    proc.stdin.write(prompt);
    proc.stdin.end();
  });
}

export default function BriefCommand() {
  const prefs = getPreferenceValues<Preferences>();
  const [state, setState] = useState<State>({ kind: "loading" });

  async function generate() {
    setState({ kind: "loading" });
    const toast = await showToast({
      style: Toast.Style.Animated,
      title: "Briefuję Cyberpunks…",
      message: `model: ${prefs.claudeModel}`,
    });
    const startedAt = Date.now();
    try {
      const { stdout } = await runClaude(
        prefs.claudeBin,
        prefs.claudeModel,
        BRIEF_PROMPT,
      );
      const text = cleanBriefOutput(stdout);
      const tookMs = Date.now() - startedAt;
      setState({ kind: "ready", text, raw: stdout, tookMs });
      toast.style = Toast.Style.Success;
      toast.title = "Gotowe";
      toast.message = `${Math.round(tookMs / 1000)}s · ${text.split(/\s+/).length} słów`;
    } catch (e) {
      const message = e instanceof Error ? e.message : String(e);
      setState({ kind: "error", message });
      toast.style = Toast.Style.Failure;
      toast.title = "Brief failed";
      toast.message = message.split("\n")[0]?.slice(0, 120);
    }
  }

  useEffect(() => {
    generate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ─── TTS — DISABLED FOR NOW ──────────────────────────────────────────
  // Wire when ELEVENLABS_API_KEY + voiceId are verified. Pseudo:
  //
  // async function speak(text: string) {
  //   const res = await fetch(
  //     `https://api.elevenlabs.io/v1/text-to-speech/${prefs.voiceId}`,
  //     {
  //       method: "POST",
  //       headers: {
  //         "xi-api-key": prefs.elevenlabsApiKey,
  //         "Content-Type": "application/json",
  //       },
  //       body: JSON.stringify({ text, model_id: prefs.voiceModel }),
  //     },
  //   );
  //   if (!res.ok) throw new Error(`11labs ${res.status}: ${await res.text()}`);
  //   const buf = Buffer.from(await res.arrayBuffer());
  //   const out = `${process.env.HOME}/Documents/briefings/${Date.now()}-brief.mp3`;
  //   await fs.promises.mkdir(path.dirname(out), { recursive: true });
  //   await fs.promises.writeFile(out, buf);
  //   spawn("afplay", [out], { detached: true, stdio: "ignore" }).unref();
  // }
  // ─────────────────────────────────────────────────────────────────────

  if (state.kind === "loading") {
    return (
      <Detail
        isLoading
        markdown={`# Cyberpunks Sync Brief\n\n_Generuję briefing… (model: \`${prefs.claudeModel}\`)_`}
      />
    );
  }

  if (state.kind === "error") {
    return (
      <Detail
        navigationTitle="Brief failed"
        markdown={`# Brief failed\n\n\`\`\`\n${state.message}\n\`\`\``}
        actions={
          <ActionPanel>
            <Action
              title="Try Again"
              icon={Icon.ArrowClockwise}
              onAction={generate}
            />
            <Action.CopyToClipboard
              title="Copy Error"
              content={state.message}
            />
          </ActionPanel>
        }
      />
    );
  }

  const meta = `_${Math.round(state.tookMs / 1000)}s · ${state.text.split(/\s+/).length} słów_\n\n`;
  return (
    <Detail
      navigationTitle="Cyberpunks Sync Brief"
      markdown={`# Cyberpunks Sync Brief\n\n${meta}${state.text}`}
      actions={
        <ActionPanel>
          <Action.CopyToClipboard
            title="Copy Brief"
            content={state.text}
            shortcut={{ modifiers: ["cmd"], key: "c" }}
          />
          {/* <Action
            title="Speak with Joniu"
            icon={Icon.SpeakerOn}
            onAction={() => speak(state.text)}
            shortcut={{ modifiers: ["cmd"], key: "s" }}
          /> */}
          <Action
            title="Regenerate"
            icon={Icon.ArrowClockwise}
            onAction={generate}
            shortcut={{ modifiers: ["cmd"], key: "r" }}
          />
          <Action.CopyToClipboard
            title="Copy Raw Output (debug)"
            content={state.raw}
            shortcut={{ modifiers: ["cmd", "shift"], key: "c" }}
          />
        </ActionPanel>
      }
    />
  );
}
