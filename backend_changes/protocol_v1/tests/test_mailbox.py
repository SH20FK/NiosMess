from __future__ import annotations

import asyncio
import hashlib

import pytest
import httpx
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from nios_protocol.auth import canonical
from nios_protocol.store import ProtocolStore
from nios_protocol.app import create_app
from test_devices import Harness, b64


def envelope(harness, *, operation="message-1", sequence=1, kind="operation", sender="alice-phone", recipient="bob-phone", text=b"protected text"):
    nonce = bytes([sequence % 256]) * 12
    context = {"v": 1, "kind": kind, "sender": sender, "recipient": recipient,
               "session": "chat-1", "id": operation, "sequence": sequence}
    encrypted = AESGCM(bytes(range(32))).encrypt(nonce, text, canonical(context))
    unsigned = {**context, "nonce": b64(nonce), "ciphertext": b64(encrypted[:-16]), "mac": b64(encrypted[-16:])}
    signature = harness.links[sender].sign(b"nios-link-device-envelope-signature-v1\0" + canonical(unsigned))
    return {**unsigned, "signature": b64(signature)}


@pytest.mark.asyncio
async def test_lost_response_restart_and_concurrent_duplicate_preserve_one_operation(tmp_path):
    harness = Harness(tmp_path)
    try:
        await harness.enroll("alice-phone")
        await harness.enroll("bob-phone", token="bob")
        body = envelope(harness)
        # Ignore the first successful response, then recreate the process store.
        await harness.request("POST", "/v1/messages", json=body)
        await harness.client.aclose()
        harness.store = ProtocolStore(tmp_path / "protocol.sqlite3", tmp_path / "data")
        harness._open_app()
        responses = await asyncio.gather(*[harness.request("POST", "/v1/messages", json=body) for _ in range(12)])
        expected = {"stored": True, "digest": hashlib.sha256(canonical(body)).hexdigest()}
        assert all(response.status_code == 200 and response.json() == expected for response in responses)
        count, events = await harness.store.read(lambda connection: (
            connection.execute("SELECT COUNT(*) FROM envelopes").fetchone()[0],
            connection.execute("SELECT COUNT(*) FROM protocol_outbox").fetchone()[0]))
        assert count == events == 1
        collision = envelope(harness, text=b"changed bytes")
        assert (await harness.request("POST", "/v1/messages", json=collision)).status_code == 409
        inbox = await harness.request("GET", "/v1/inbox", token="bob")
        assert inbox.json() == {"envelopes": [body], "next": None}
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_exact_device_auth_signature_domain_and_confirm(tmp_path):
    harness = Harness(tmp_path)
    try:
        await harness.enroll("alice-phone")
        await harness.enroll("bob-phone", token="bob")
        body = envelope(harness)
        assert (await harness.request("POST", "/v1/messages", token="bob", json=body)).status_code == 403
        forged = {**body, "signature": b64(bytes(64))}
        assert (await harness.request("POST", "/v1/messages", json=forged)).status_code == 403
        assert (await harness.request("POST", "/v1/acks", json=body)).status_code == 422
        response = await harness.request("POST", "/v1/messages", json=body)
        digest = response.json()["digest"]
        assert (await harness.request("POST", "/v1/confirm", json={"digest": digest})).status_code == 404
        assert (await harness.request("POST", "/v1/confirm", token="bob", json={"digest": digest})).status_code == 200
        assert (await harness.request("POST", "/v1/confirm", token="bob", json={"digest": digest})).status_code == 200
        assert (await harness.request("GET", "/v1/inbox", token="bob")).json()["envelopes"] == []
        # A sender retry must not reopen a confirmed receiver inbox item.
        assert (await harness.request("POST", "/v1/messages", json=body)).status_code == 200
        assert (await harness.request("GET", "/v1/inbox", token="bob")).json()["envelopes"] == []
        await harness.store.transaction(lambda connection: connection.execute("UPDATE devices SET revoked=1 WHERE device_id='bob-phone'").rowcount)
        # This receipt describes the previous commit, even after recipient revoke.
        assert (await harness.request("POST", "/v1/messages", json=body)).status_code == 200
        assert (await harness.request("POST", "/v1/messages", json=envelope(harness, operation="new-after-revoke"))).status_code == 409
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_pagination_is_replayable_and_ack_facts_have_distinct_digests(tmp_path):
    harness = Harness(tmp_path)
    try:
        await harness.enroll("alice-phone")
        await harness.enroll("bob-phone", token="bob")
        for i in range(103):
            body = envelope(harness, operation=f"message-{i}", sequence=i + 1)
            assert (await harness.request("POST", "/v1/messages", json=body)).status_code == 200
        first = (await harness.request("GET", "/v1/inbox", token="bob")).json()
        assert len(first["envelopes"]) == 100 and first["next"]
        second = (await harness.request("GET", "/v1/inbox?after=" + first["next"], token="bob")).json()
        assert len(second["envelopes"]) == 3 and second["next"] is None
        assert (await harness.request("GET", "/v1/inbox", token="bob")).json() == first
        for fact in (b"stored", b"applied", b"read"):
            ack = envelope(harness, kind="ack", sender="bob-phone", recipient="alice-phone", text=fact)
            assert (await harness.request("POST", "/v1/acks", token="bob", json=ack)).status_code == 200
        assert len((await harness.request("GET", "/v1/inbox")).json()["envelopes"]) == 3
        assert (await harness.request("GET", "/v1/inbox?after=" + "0" * 64, token="bob")).status_code == 400
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_failed_transaction_leaves_no_envelope_or_outbox_and_revoked_sender_is_blocked(tmp_path):
    harness = Harness(tmp_path)
    try:
        await harness.enroll("alice-phone")
        await harness.enroll("bob-phone", token="bob")
        await harness.store.ensure_schema("CREATE TRIGGER reject_outbox BEFORE INSERT ON protocol_outbox BEGIN SELECT RAISE(ABORT,'test_fault'); END;")
        # The database fault propagates, but the envelope must roll back with it.
        with pytest.raises(Exception, match="test_fault"):
            await harness.request("POST", "/v1/messages", json=envelope(harness))
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM envelopes").fetchone()[0]) == 0
        await harness.store.ensure_schema("DROP TRIGGER reject_outbox;")
        await harness.store.transaction(lambda connection: connection.execute("UPDATE devices SET revoked=1 WHERE device_id='alice-phone'").rowcount)
        assert (await harness.request("POST", "/v1/messages", json=envelope(harness))).status_code == 403
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_host_chat_acl_rejects_new_delivery_but_keeps_existing_retry_receipt(tmp_path):
    harness = Harness(tmp_path)
    try:
        await harness.enroll("alice-phone")
        await harness.enroll("bob-phone", token="bob")
        allowed, calls = [True], []
        async def authorize(principal, value):
            assert principal.device_id == "alice-phone"
            calls.append(value["id"])
            return allowed[0]
        await harness.client.aclose()
        harness.app = create_app(harness.store, harness.authenticate, authorize_delivery=authorize)
        harness.client = httpx.AsyncClient(transport=httpx.ASGITransport(harness.app), base_url="https://test.example")
        original = envelope(harness)
        first = await harness.request("POST", "/v1/messages", json=original)
        assert first.status_code == 200
        allowed[0] = False
        duplicate = await harness.request("POST", "/v1/messages", json=original)
        assert duplicate.status_code == 200 and duplicate.json() == first.json()
        assert calls == ["message-1"]
        denied = await harness.request("POST", "/v1/messages", json=envelope(harness, operation="forbidden-new"))
        assert denied.status_code == 403 and denied.json()["detail"] == "delivery_not_authorized"
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM envelopes").fetchone()[0]) == 1
    finally:
        await harness.close()
