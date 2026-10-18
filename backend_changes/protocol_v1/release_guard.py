"""Fingerprint complete deployable trees without following shared symlinks."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path

IGNORED_DIRECTORIES = {"__pycache__", ".pytest_cache", ".git"}
MUTABLE_SUFFIXES = (".pyc", ".log", ".sqlite", ".sqlite3", ".db", "-wal", "-shm")


def fingerprint(root: Path) -> dict[str, str]:
    result = {}
    for directory, directories, files in os.walk(root, followlinks=False):
        directories[:] = sorted(name for name in directories if name not in IGNORED_DIRECTORIES)
        for name in list(directories) + sorted(files):
            path = Path(directory) / name
            relative = path.relative_to(root).as_posix()
            if path.is_symlink():
                result[relative] = "link:" + os.readlink(path)
            elif path.is_file() and not path.name.endswith(MUTABLE_SUFFIXES):
                result[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def assert_regular_sources(root: Path, paths):
    for relative in paths:
        target = root / relative
        if target.is_symlink() or not target.is_file() or not target.resolve().is_relative_to(root.resolve()):
            raise RuntimeError("host_source_must_be_regular:" + relative)
