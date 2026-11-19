#!/usr/bin/env python3
"""Fail when a workflow or composite action uses a remote action that is not a full commit SHA.

Local actions (./ or ../) are ignored. Every other `uses:` value must be
`owner/repo[/path]@` followed by exactly 40 lowercase hex characters.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
SHA = re.compile(r"^[0-9a-f]{40}$")
USES = re.compile(
    r"""^(?:\s*(?:-\s*)?)uses:\s*(?P<quote>['\"]?)(?P<value>[^\s'\"#]+)(?P=quote)\s*(?:#.*)?$"""
)
SKIP_DIRS = {".git", "vendor", "node_modules", "tmp", "log", "storage"}


def files_to_scan(root: Path) -> list[Path]:
    files: list[Path] = []
    workflows = root / ".github" / "workflows"
    if workflows.is_dir():
        files.extend(workflows.glob("*.yml"))
        files.extend(workflows.glob("*.yaml"))
    for name in ("action.yml", "action.yaml"):
        for path in root.rglob(name):
            if SKIP_DIRS.intersection(path.parts):
                continue
            files.append(path)
    return sorted(set(files))


def is_local(value: str) -> bool:
    return value.startswith("./") or value.startswith("../")


def unpinned_remote(value: str) -> bool:
    if is_local(value):
        return False
    ref = value.rsplit("@", 1)[1] if "@" in value else ""
    return SHA.fullmatch(ref) is None


def main() -> int:
    problems: list[str] = []
    scanned = files_to_scan(REPO_ROOT)
    for path in scanned:
        lines = path.read_text(encoding="utf-8").splitlines()
        for lineno, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue
            match = USES.match(line.rstrip("\r"))
            if not match:
                continue
            value = match.group("value")
            if unpinned_remote(value):
                rel = path.relative_to(REPO_ROOT)
                problems.append(
                    f"{rel}:{lineno}: remote action is not pinned to a 40-character commit SHA: {value}"
                )
    if problems:
        print("Unpinned remote GitHub Actions:", file=sys.stderr)
        for problem in problems:
            print(problem, file=sys.stderr)
        return 1
    noun = "file" if len(scanned) == 1 else "files"
    print(f"All remote actions are pinned to a 40-character commit SHA ({len(scanned)} {noun} scanned).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
