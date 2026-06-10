import os, subprocess, json, pathlib, sys

key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
if not key:
    print("TTS skipped — brak ELEVENLABS_API_KEY w env (dodaj do privateEnvVars w ~/.config/chezmoi/chezmoi.toml i odpal chezmoi apply)")
    sys.exit(0)
voice = "wHaDY0iHb8cFQwoJek6Q"
model = "eleven_v3"
home = pathlib.Path.home()
txt_path = home / "Documents" / "briefings" / "2026-06-09-1053-daily-brief.txt"
mp3_path = home / "Documents" / "briefings" / "2026-06-09-1053-daily-brief.mp3"
text = txt_path.read_text()
body = json.dumps({"text": text, "model_id": model})
url = "https://api.elevenlabs.io/v1/text-to-speech/" + voice
r = subprocess.run(
    ["curl","-sS","-X","POST",url,
     "-H","xi-api-key: " + key,
     "-H","Content-Type: application/json",
     "-d",body,
     "--output",str(mp3_path)],
    capture_output=True, text=True
)
print("rc=", r.returncode)
print("stderr=", r.stderr[:500])
print("size=", mp3_path.stat().st_size if mp3_path.exists() else "missing")
