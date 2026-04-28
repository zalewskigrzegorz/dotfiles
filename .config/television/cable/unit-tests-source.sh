#!/usr/bin/env bash

python3 - <<'PY'
import os
import re
import signal
from pathlib import Path

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

start = Path(os.environ.get("PWD") or os.getcwd()).resolve()


def has_test_runner(directory: Path) -> bool:
    if not (directory / "package.json").exists():
        return False

    runner_configs = (
        "vitest.config.ts",
        "vitest.config.js",
        "jest.config.ts",
        "jest.config.js",
    )
    return any((directory / config).exists() for config in runner_configs)


current = start
test_dir = None

while True:
    nested_test_dir = current / "apps" / "api"
    if has_test_runner(nested_test_dir):
        test_dir = nested_test_dir
        break

    if has_test_runner(current):
        test_dir = current
        break

    if current.parent == current:
        raise SystemExit(0)

    current = current.parent

ignored_parts = {"node_modules", "dist", "coverage"}
spec_patterns = ("*.spec.ts", "*.test.ts", "*.spec.tsx", "*.test.tsx", "*.spec.js", "*.test.js")
specs = sorted(
    {
        spec
        for pattern in spec_patterns
        for spec in test_dir.rglob(pattern)
        if not (set(spec.relative_to(test_dir).parts) & ignored_parts)
    },
    key=lambda path: path.relative_to(test_dir).as_posix(),
)

title_pattern = re.compile(
    r"""^\s*(?:it|test)(?:\.(?:only|skip|todo|concurrent))?\(\s*(['"])(.*?)\1"""
)

for directory in sorted({spec.parent for spec in specs}, key=lambda path: path.relative_to(test_dir).as_posix()):
    print(f"dir\t{directory.relative_to(test_dir).as_posix()}")

for spec in specs:
    relative_spec = spec.relative_to(test_dir).as_posix()
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
