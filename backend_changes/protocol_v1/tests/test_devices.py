from __future__ import annotations

import base64
import hashlib
from pathlib import Path
from dataclasses import replace

import httpx
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from fastapi import HTTPException

from nios_protocol.app import create_app
from nios_protocol.auth import Principal, canonical
from nios_protocol.devices import enrollment_bytes, protocols, registration_bytes
from nios_protocol.store import ProtocolStore


def b64(value: bytes) -> str:
    return base64.b64encode(value).decode()


def public(key: Ed25519PrivateKey) -> str:
    return b64(key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw))


class Harness:
    def __init__(self, root: Path, *, log_key=None):
        self.store = ProtocolStore(root / "protocol.sqlite3", root / "data")
        self.principals = {"alice": Principal("account-alice", 1, 101),
                           "alice-new": Principal("account-alice", 1, 102),
                           "bob": Principal("account-bob", 2, 201)}
        self.identities = {"account-alice": Ed25519PrivateKey.generate(),
                           "account-bob": Ed25519PrivateKey.generate()}
        self.links = {}
        self.log_key = log_key
        self._open_app()

    def _open_app(self):
        async def authenticate(request):
            raw = request.headers.get("authorization", "")
            principal = self.principals.get(raw.removeprefix("Bearer "))
            if not raw.startswith("Bearer ") or principal is None:
                raise HTTPException(401, "unauthorized")
            return principal
        self.authenticate = authenticate
        self.app = create_app(self.store, authenticate, log_signing_key=self.log_key)
        self.client = httpx.AsyncClient(transport=httpx.ASGITransport(self.app), base_url="https://test.example")

    async def request(self, method, path, *, token="alice", **kwargs):
        return await self.client.request(method, path, headers={"Authorization": "Bearer " + token}, **kwargs)

    async def enrollment(self, device, *, token="alice", capability=None, native=False, identity=None):
        principal = self.principals[token]
        self.links.setdefault(device, Ed25519PrivateKey.generate())
        challenge_response = await self.request("POST", f"/v1/devices/{device}/challenge", token=token, json={})
        assert challenge_response.status_code == 200, challenge_response.text
        challenge = challenge_response.json()["challenge"]
        identity = identity or self.identities[principal.account_id]
        body = {"challenge": challenge, "identity_key": public(identity), "link_key": public(self.links[device]),
                "mls_key": public(Ed25519PrivateKey.generate()) if native else None,
                "endpoint_key": public(Ed25519PrivateKey.generate()) if native else None,
                "legacy_key": principal.legacy_public_key,
                "protocols": protocols(capability or {"link": [1], "stream": [1]})}
        registration = registration_bytes(principal.account_id, device, body, body["protocols"])
        body["identity_signature"] = b64(identity.sign(registration))
        body["device_proof"] = b64(self.links[device].sign(enrollment_bytes(principal, device, challenge, registration)))
        return body

    async def enroll(self, device, **kwargs):
        body = await self.enrollment(device, **kwargs)
        response = await self.request("PUT", f"/v1/devices/{device}", token=kwargs.get("token", "alice"), json=body)
        assert response.status_code == 200, response.text
        return body

    async def close(self):
        await self.client.aclose()


@pytest.mark.asyncio
async def test_enrollment_binds_session_and_stream_only_is_honest(tmp_path):
    harness = Harness(tmp_path)
    try:
        body = await harness.enroll("alice-phone", capability={"stream": [1]})
        response = await harness.request("GET", "/v1/devices/alice-phone/protocols")
        assert response.status_code == 200
        assert response.json()["protocols"]["stream"] == [1]
        assert response.json()["protocols"]["mls"] == {"versions": [], "suites": []}
        assert response.json()["mls_key"] is None
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols", token="alice-new")).status_code == 403
        replay = await harness.request("PUT", "/v1/devices/alice-phone", json=body)
        assert replay.status_code == 403
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM device_history").fetchone()[0]) == 1
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_fresh_signed_rebind_fences_old_session_and_cannot_replace_identity(tmp_path):
    harness = Harness(tmp_path)
    try:
        await harness.enroll("alice-phone")
        await harness.enroll("alice-phone", token="alice-new")
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols")).status_code == 403
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols", token="alice-new")).status_code == 200
        foreign = await harness.enrollment("another-phone", token="alice", identity=Ed25519PrivateKey.generate())
        response = await harness.request("PUT", "/v1/devices/another-phone", json=foreign)
        # Stream-only second installs need not possess a shared account secret.
        assert response.status_code == 200
        stolen = await harness.enrollment("alice-phone", token="bob")
        assert (await harness.request("PUT", "/v1/devices/alice-phone", token="bob", json=stolen)).status_code == 409
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_enrollment_rejects_forged_proof_legacy_mismatch_and_false_native_capability(tmp_path):
    harness = Harness(tmp_path)
    try:
        body = await harness.enrollment("alice-phone")
        body["device_proof"] = b64(bytes(64))
        assert (await harness.request("PUT", "/v1/devices/alice-phone", json=body)).status_code == 403
        body = await harness.enrollment("alice-phone")
        body["legacy_key"] = "another-session-key"
        assert (await harness.request("PUT", "/v1/devices/alice-phone", json=body)).status_code == 403
        body = await harness.enrollment("alice-phone", capability={"mls": {"versions": ["1.0"], "suites": ["0x0001"]}})
        assert (await harness.request("PUT", "/v1/devices/alice-phone", json=body)).status_code == 422
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM devices").fetchone()[0]) == 0
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_revocation_requires_account_signature_and_is_a_permanent_tombstone(tmp_path):
    harness = Harness(tmp_path)
    try:
        await harness.enroll("alice-phone")
        challenge = (await harness.request("POST", "/v1/devices/alice-phone/challenge", json={})).json()["challenge"]
        signing = canonical(["nios-device-revocation", 1, "account-alice", "alice-phone", 101, challenge])
        signature = b64(harness.identities["account-alice"].sign(signing))
        response = await harness.request("POST", "/v1/devices/alice-phone/revoke", json={"challenge": challenge, "signature": signature})
        assert response.status_code == 200
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols")).status_code == 403
        body = await harness.enrollment("alice-phone", token="alice-new")
        assert (await harness.request("PUT", "/v1/devices/alice-phone", token="alice-new", json=body)).status_code == 409
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_enrollment_pins_survive_database_restart_and_strict_json(tmp_path):
    harness = Harness(tmp_path)
    try:
        await harness.enroll("alice-phone")
        await harness.client.aclose()
        harness.store = ProtocolStore(tmp_path / "protocol.sqlite3", tmp_path / "data")
        harness._open_app()
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols")).status_code == 200
        duplicate = await harness.request("POST", "/v1/devices/a/challenge", content='{"x":1,"x":2}')
        assert duplicate.status_code == 400
        unauthorized = await harness.client.get("/v1/protocols")
        assert unauthorized.status_code == 401
        journal, synchronous = await harness.store.read(lambda connection: (connection.execute("PRAGMA journal_mode").fetchone()[0], connection.execute("PRAGMA synchronous").fetchone()[0]))
        assert journal == "wal" and synchronous == 2
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_legacy_session_key_change_fences_old_binding_until_fresh_signed_enrollment(tmp_path):
    harness = Harness(tmp_path)
    try:
        harness.principals["alice"] = replace(harness.principals["alice"], legacy_public_key=b64(bytes(range(32))))
        await harness.enroll("alice-phone")
        harness.principals["alice"] = replace(harness.principals["alice"], legacy_public_key=b64(bytes(range(32, 64))))
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols")).status_code == 403
        await harness.enroll("alice-phone")
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols")).status_code == 200
        await harness.enroll("alice-phone")
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM device_history").fetchone()[0]) == 2
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_reused_integer_session_id_cannot_inherit_device_or_replay_old_challenge(tmp_path):
    harness = Harness(tmp_path)
    try:
        harness.principals["alice"] = replace(harness.principals["alice"], session_fingerprint="old-token-hash")
        await harness.enroll("alice-phone")
        stale = await harness.enrollment("alice-phone")
        harness.principals["alice-old"] = harness.principals["alice"]
        # Same account and integer primary key, but a different opaque token.
        harness.principals["alice"] = replace(harness.principals["alice"], session_fingerprint="new-token-hash")
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols")).status_code == 403
        assert (await harness.request("PUT", "/v1/devices/alice-phone", json=stale)).status_code == 403
        await harness.enroll("alice-phone")  # Fresh challenge + both original keys.
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols")).status_code == 200
        assert (await harness.request("GET", "/v1/devices/alice-phone/protocols", token="alice-old")).status_code == 403
        # Account deletion can reuse the same PK for a wholly different person.
        harness.principals["bob"] = replace(harness.principals["bob"], session_id=101, session_fingerprint="bob-token-hash")
        assert (await harness.request("GET", "/v1/inbox", token="bob")).status_code == 403
        await harness.enroll("bob-phone", token="bob")
        old = await harness.store.read(lambda connection: connection.execute("SELECT * FROM devices WHERE device_id='alice-phone'").fetchone())
        assert old["session_id"] is None and old["session_fingerprint"] is None and old["revoked"] == 1
        assert old["link_key"] == public(harness.links["alice-phone"])
        assert (await harness.request("GET", "/v1/devices/bob-phone/protocols", token="bob")).status_code == 200
    finally:
        await harness.close()
