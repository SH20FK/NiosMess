"""Run existing host assertions with valid current X25519 fixture keys.

The old suite used literal 'peer-device-public-key', which the current handler
correctly rejects as not a 32-byte key. Only those two test inputs change; no
assertion, handler or production configuration is weakened or skipped.
"""
from __future__ import annotations

import base64
from pathlib import Path
import sys

import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey


class ValidDeviceKeys:
    def __init__(self, target):
        self.target = target.resolve()

    def pytest_collection_modifyitems(self, items):
        for item in items:
            module = item.module
            if Path(module.__file__).resolve() != self.target:
                continue
            for name, value in (("OWNER_KEY", 1), ("PEER_KEY", 2)):
                public = X25519PrivateKey.from_private_bytes(bytes([value]) * 32).public_key()
                setattr(module, name, base64.b64encode(public.public_bytes(
                    serialization.Encoding.Raw, serialization.PublicFormat.Raw)).decode())


if __name__ == "__main__":
    target = Path(sys.argv[1]) / "tests/test_secret_chat_hardening.py"
    raise SystemExit(pytest.main([str(target), "-q", "--tb=short", "--asyncio-mode=auto"],
                                plugins=[ValidDeviceKeys(target)]))
