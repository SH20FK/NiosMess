from __future__ import annotations

import base64
import hashlib

import pytest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from nios_protocol.auth import canonical
from nios_protocol.store import ProtocolStore
from nios_protocol.transparency import statement_bytes
from test_devices import Harness, b64


def model_root(leaves):
    if not leaves:
        return hashlib.sha256(b"").digest()
    if len(leaves) == 1:
        return hashlib.sha256(b"\0" + leaves[0]).digest()
    left = 1
    while left * 2 < len(leaves):
        left *= 2
    return hashlib.sha256(b"\1" + model_root(leaves[:left]) + model_root(leaves[left:])).digest()


def verify_inclusion(leaf, index, size, proof, root):
    first, last = index, size - 1
    current = hashlib.sha256(b"\0" + leaf).digest()
    for sibling in proof:
        if last == 0:
            return False
        if first & 1 or first == last:
            current = hashlib.sha256(b"\1" + sibling + current).digest()
            while first and not first & 1:
                first >>= 1
                last >>= 1
        else:
            current = hashlib.sha256(b"\1" + current + sibling).digest()
        first >>= 1
        last >>= 1
    return last == 0 and current == root


def verify_consistency(old, new, old_root, new_root, proof):
    if old == 0:
        return not proof and old_root == hashlib.sha256(b"").digest()
    if old == new:
        return not proof and old_root == new_root
    first, last = old - 1, new - 1
    while first & 1:
        first >>= 1
        last >>= 1
    if first == 0:
        left = right = old_root
    else:
        if not proof:
            return False
        left = right = proof[0]
        proof = proof[1:]
    for sibling in proof:
        if last == 0:
            return False
        if first & 1 or first == last:
            left = hashlib.sha256(b"\1" + sibling + left).digest()
            right = hashlib.sha256(b"\1" + sibling + right).digest()
            while first and not first & 1:
                first >>= 1
                last >>= 1
        else:
            right = hashlib.sha256(b"\1" + right + sibling).digest()
        first >>= 1
        last >>= 1
    return last == 0 and left == old_root and right == new_root


async def setup_native(harness):
    body = await harness.enroll("alice-phone", native=True, capability={
        "link": [1], "stream": [1], "mls": {"versions": ["1.0"], "suites": ["0x0001"]},
        "irohAlpn": ["nios.link/1"], "ktStatements": [1, 2]})
    return body


def authorized(harness, body, revision, previous, *, action="enroll", extended=True):
    statement = {"account": "account-alice", "device": "alice-phone", "revision": revision,
                 "action": action, "key": body["mls_key"], "previous": b64(previous), "time": 1_791_000_000_000 + revision}
    if extended:
        statement.update(linkSigningKey=body["link_key"], transportEndpointKey=body["endpoint_key"])
    signing = statement_bytes(statement)
    signature = b64(harness.identities["account-alice"].sign(signing))
    entry = canonical(["nios-authorized-device", 1, b64(signing), signature])
    return {"statement": statement, "signature": signature}, entry


@pytest.mark.asyncio
async def test_persistent_sdk_canonical_log_proofs_for_every_prefix(tmp_path):
    log_key = Ed25519PrivateKey.generate()
    harness = Harness(tmp_path, log_key=log_key)
    leaves, previous = [], bytes(32)
    try:
        registration = await setup_native(harness)
        for revision in range(1, 14):
            body, entry = authorized(harness, registration, revision, previous, extended=revision % 2 == 1)
            response = await harness.request("POST", "/v1/kt/statements", json=body)
            assert response.status_code == 200, response.text
            assert response.json()["leafIndex"] == revision - 1
            leaves.append(entry)
            previous = hashlib.sha256(b"\0" + entry).digest()
            assert response.json()["hash"] == b64(previous)
            assert (await harness.request("POST", "/v1/kt/statements", json=body)).json() == response.json()
        checkpoint = (await harness.request("GET", "/v1/kt/checkpoint")).json()
        assert checkpoint["witnesses"] == [] and checkpoint["independentWitnesses"] is False
        cp = checkpoint["checkpoint"]
        assert base64.b64decode(cp["root"]) == model_root(leaves)
        log_key.public_key().verify(base64.b64decode(checkpoint["logSignature"]),
            canonical(["nios-key-log-checkpoint", 1, cp["log"], cp["size"], cp["root"], cp["time"]]))
        for size in range(1, len(leaves) + 1):
            items = (await harness.request("GET", f"/v1/kt/accounts/account-alice/statements?atSize={size}")).json()["statements"]
            assert len(items) == size
            for item in items:
                proof = [base64.b64decode(x) for x in item["inclusionProof"]]
                assert verify_inclusion(leaves[item["leafIndex"]], item["leafIndex"], size, proof, model_root(leaves[:size]))
            for old in range(size + 1):
                proof = (await harness.request("GET", f"/v1/kt/consistency?from={old}&to={size}")).json()["proof"]
                assert verify_consistency(old, size, model_root(leaves[:old]), model_root(leaves[:size]), [base64.b64decode(x) for x in proof])
        await harness.client.aclose()
        harness.store = ProtocolStore(tmp_path / "protocol.sqlite3", tmp_path / "data")
        harness._open_app()
        assert (await harness.request("GET", "/v1/kt/checkpoint")).json() == checkpoint
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_signed_conflicts_forged_signature_and_account_identity_are_rejected(tmp_path):
    harness = Harness(tmp_path, log_key=Ed25519PrivateKey.generate())
    try:
        registration = await setup_native(harness)
        body, entry = authorized(harness, registration, 1, bytes(32))
        forged = {**body, "signature": b64(bytes(64))}
        assert (await harness.request("POST", "/v1/kt/statements", json=forged)).status_code == 403
        assert (await harness.request("POST", "/v1/kt/statements", json=body)).status_code == 200
        wrong_previous, _ = authorized(harness, registration, 2, bytes(32))
        assert (await harness.request("POST", "/v1/kt/statements", json=wrong_previous)).status_code == 409
        conflict, _ = authorized(harness, registration, 1, bytes(32), extended=False)
        assert (await harness.request("POST", "/v1/kt/statements", json=conflict)).status_code == 409
        second = await harness.enrollment("second-native", token="alice-new", native=True,
            capability={"ktStatements": [1, 2]}, identity=Ed25519PrivateKey.generate())
        assert (await harness.request("PUT", "/v1/devices/second-native", token="alice-new", json=second)).status_code == 409
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM kt_leaves").fetchone()[0]) == 1
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_key_revocation_blocks_future_device_requests_without_erasing_history(tmp_path):
    harness = Harness(tmp_path, log_key=Ed25519PrivateKey.generate())
    try:
        registration = await setup_native(harness)
        first, entry = authorized(harness, registration, 1, bytes(32))
        await harness.request("POST", "/v1/kt/statements", json=first)
        revoke, _ = authorized(harness, registration, 2, hashlib.sha256(b"\0" + entry).digest(), action="revoke")
        assert (await harness.request("POST", "/v1/kt/statements", json=revoke)).status_code == 200
        assert (await harness.request("GET", "/v1/inbox")).status_code == 403
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM kt_leaves").fetchone()[0]) == 2
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_stream_only_registration_cannot_implicitly_claim_shared_account_trust(tmp_path):
    harness = Harness(tmp_path, log_key=Ed25519PrivateKey.generate())
    try:
        registration = await harness.enroll("alice-phone", native=True)
        statement, _ = authorized(harness, registration, 1, bytes(32))
        response = await harness.request("POST", "/v1/kt/statements", json=statement)
        assert response.status_code == 409 and response.json()["detail"] == "account_identity_not_enrolled_for_transparency"
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM kt_leaves").fetchone()[0]) == 0
    finally:
        await harness.close()
