#!/usr/bin/env bash

python3 - <<'PY'
import os
import re
from pathlib import Path

root = Path(os.environ.get("PWD") or os.getcwd()).resolve()
current = root
playwright_dir = None

while True:
    if (current / "playwright.config.ts").exists() or (current / "playwright.config.js").exists():
        playwright_dir = current
        break

    reunite_dir = current / "e2e" / "reunite"
    if (reunite_dir / "playwright.config.ts").exists():
        playwright_dir = reunite_dir
        break

    if current.parent == current:
        playwright_dir = root
        break

    current = current.parent

tests_dir = playwright_dir / "tests"
if not tests_dir.exists():
    raise SystemExit(0)

title_pattern = re.compile(r"""^\s*test(?:\.only)?\(\s*(['"])(.*?)\1""")

for spec in sorted(tests_dir.rglob("*.spec.ts")):
    relative_spec = spec.relative_to(playwright_dir).as_posix()
    print(f"spec\t{relative_spec}")

    try:
        lines = spec.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        continue

    for line in lines:
        match = title_pattern.match(line)
        if match:
            print(f"test\t{relative_spec}\t{match.group(2)}")
PY
