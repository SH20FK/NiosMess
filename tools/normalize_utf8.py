from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]

EXTS = {
    ".dart",
    ".md",
    ".txt",
    ".yaml",
    ".yml",
    ".json",
}

SKIP_DIRS = {
    ".git",
    ".agent",
    ".claude",
    ".dart_tool",
    ".idea",
    ".vscode",
    ".gradle",
    "build",
    "Pods",
}


def should_skip(path: pathlib.Path) -> bool:
    return any(part in SKIP_DIRS for part in path.parts)


def normalize_file(path: pathlib.Path) -> bool:
    data = path.read_bytes()
    if not data:
        return False
    if b"\x00" in data:
        return False

    decoded = None
    used_enc = None
    for enc in ("utf-8", "cp1251", "latin-1"):
        try:
            decoded = data.decode(enc)
            used_enc = enc
            break
        except UnicodeDecodeError:
            continue

    if decoded is None:
        return False

    if decoded.startswith("\ufeff"):
        decoded = decoded[1:]

    out = decoded.encode("utf-8")
    if out != data:
        path.write_bytes(out)
        print(f"normalized ({used_enc} -> utf-8): {path}")
        return True
    return False


def main() -> int:
    changed = 0
    for path in ROOT.rglob("*"):
        if path.is_dir():
            continue
        if should_skip(path):
            continue
        if path.suffix.lower() not in EXTS:
            continue
        try:
            if normalize_file(path):
                changed += 1
        except Exception as exc:
            print(f"skip {path}: {exc}", file=sys.stderr)
    print(f"done. files changed: {changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
