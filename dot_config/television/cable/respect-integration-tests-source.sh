#!/usr/bin/env bash

python3 - <<'PY'
import os
import re
import signal
from pathlib import Path

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

start = Path(os.environ.get("PWD") or os.getcwd()).resolve()
current = start
root = None

while True:
    candidate = current / "api-integration-tests"
    marker = current / "run-integration-tests.sh"
    if candidate.is_dir() and marker.is_file():
        root = current
        break
    if current.parent == current:
        break
    current = current.parent

if root is None:
    raise SystemExit(0)

tests_dir = root / "api-integration-tests"

# Match exclusions in run-integration-tests.sh for the default suite
def is_excluded(rel: Path) -> bool:
    parts = rel.parts
    if rel.name == "petstore.yaml":
        return True
    if rel.name == "close-pr-via-webhook-on-branch-deletion.yaml":
        return True
    cafe_op_dir = "".join(("re", "do", "cly", "-cafe-api-atomic-operations"))
    if len(parts) > 0 and parts[0] == cafe_op_dir:
        return True
    return False

workflow_id_re = re.compile(r"^\s*-\s*workflowId:\s*(\S+)")

yaml_files = sorted(
    (
        p
        for p in tests_dir.rglob("*.yaml")
        if p.is_file() and not is_excluded(p.relative_to(tests_dir))
    ),
    key=lambda p: p.relative_to(tests_dir).as_posix(),
)

for spec in yaml_files:
    rel = spec.relative_to(root).as_posix()
    print(f"spec\t{rel}")

    try:
        lines = spec.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        continue

    for line in lines:
        m = workflow_id_re.match(line)
        if m:
            wf = m.group(1).strip().strip("\"'")
            if wf:
                print(f"workflow\t{rel}\t{wf}")
PY
