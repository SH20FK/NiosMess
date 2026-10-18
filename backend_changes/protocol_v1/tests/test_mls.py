"""Real SQLite/FastAPI contract tests; no production DB or accounts."""
import asyncio
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import time

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from fastapi import FastAPI, HTTPException, Request
from fastapi.testclient import TestClient
import pytest

from nios_protocol.auth import Principal
from nios_protocol.mls import create_mls_router, validate_mls_delivery
from nios_protocol.store import ProtocolStore


def canonical(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode()


@pytest.fixture
def system(tmp_path):
    store = ProtocolStore(tmp_path / "protocol.db", tmp_path / "files")
    keys = {d: Ed25519PrivateKey.generate() for d in ("alice", "bob", "carol", "outsider")}
    principals = {d: Principal(d, i, i, d) for i, d in enumerate(keys, 1)}
    caps = json.dumps({"mls": {"versions": ["1.0"], "suites": ["0x0001"]}})

    async def seed():
        await store.initialize()
        def transaction(conn):
            for device, who in principals.items():
                public = base64.b64encode(keys[device].public_key().public_bytes_raw()).decode()
                conn.execute("INSERT INTO identities VALUES(?,?,?)", (device, public, int(time.time())))
                conn.execute("INSERT INTO devices(device_id,account_id,user_id,session_id,identity_key,mls_key,link_key,capabilities,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
                             (device, device, who.user_id, who.session_id, public, public, public, caps, 1, 1))
        await store.transaction(transaction)
    asyncio.run(seed())

    async def authenticate(request: Request):
        device = request.headers.get("authorization", "").removeprefix("Bearer ")
        if device not in principals:
            raise HTTPException(401, "test_auth_required")
        return principals[device]

    async def authorize(who, chat, action, target_devices):
        if chat != "chat1" or who.device_id == "outsider" or "outsider" in target_devices:
            return False
        return action == "participate" or who.device_id == "alice"

    def client():
        app = FastAPI()
        app.include_router(create_mls_router(store, authenticate, authorize))
        return TestClient(app)

    yield store, keys, client


def headers(device="alice"):
    return {"Authorization": "Bearer " + device}


def package(client, keys, device):
    data = b"opaque TLS KeyPackage validated by OpenMLS on client:" + device.encode()
    digest = hashlib.sha256(data).hexdigest()
    expires = int(time.time()) + 3600
    signature = keys[device].sign(canonical(["nios-mls-keypackage", 1, device, digest, expires]))
    payload = {"package": base64.b64encode(data).decode(), "expires_at": expires,
               "signature": base64.b64encode(signature).decode()}
    result = client.put(f"/v1/mls/keypackages/{device}/{digest}", headers=headers(device), json=payload)
    assert result.status_code == 200, result.text
    return digest, payload


def group(client):
    result = client.put("/v1/mls/groups/Z3JvdXAx", headers=headers(), json={"chat_id": "chat1", "ciphersuite": "0x0001"})
    assert result.status_code == 200, result.text
    return result.json()


def reservation(client, state, operation="add-bob", add=None, remove=None):
    body = {"operation_id": operation, "base_epoch": state["epoch"], "base_head": state["head"],
            "add_devices": add or [], "remove_devices": remove or []}
    response = client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json=body)
    assert response.status_code == 200, response.text
    return response.json(), body


def commit(client, reserved, welcome=b"welcome"):
    body = {"token": reserved["token"], "base_epoch": reserved["base_epoch"], "epoch": reserved["base_epoch"] + 1,
            "commit": base64.b64encode(b"commit:" + reserved["operation_id"].encode()).decode(),
            "welcome": None if welcome is None else base64.b64encode(welcome).decode()}
    url = "/v1/mls/groups/Z3JvdXAx/commits/" + reserved["operation_id"]
    response = client.put(url, headers=headers(), json=body)
    assert response.status_code == 200, response.text
    return response.json(), body


def test_durable_reservation_exact_retry_single_claim_and_lost_commit_reply(system):
    store, keys, new_client = system
    with new_client() as client:
        digest, _ = package(client, keys, "bob")
        state = group(client)
        reserved, request = reservation(client, state, add=["bob"])
        retry = client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json=request)
        assert retry.json() == reserved
        assert reserved["keypackages"][0]["hash"] == digest
        conflicting = dict(request, operation_id="another-writer")
        assert client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json=conflicting).status_code == 409
        receipt, body = commit(client, reserved)
    # New ASGI application and DB connections simulate response loss/restart.
    with new_client() as client:
        assert client.put("/v1/mls/groups/Z3JvdXAx/commits/add-bob", headers=headers(), json=body).json() == receipt
        changed = dict(body, commit=base64.b64encode(b"different bytes").decode())
        assert client.put("/v1/mls/groups/Z3JvdXAx/commits/add-bob", headers=headers(), json=changed).status_code == 409
        events = client.get("/v1/mls/inbox", headers=headers("bob")).json()["events"]
        assert len(events) == 1 and events[0]["kind"] == "welcome"
        assert client.get("/v1/mls/inbox", headers=headers()).json()["events"] == []
        assert client.post("/v1/mls/confirm", headers=headers(), json={"id": events[0]["id"]}).status_code == 404
        assert client.post("/v1/mls/confirm", headers=headers("bob"), json={"id": events[0]["id"]}).status_code == 200
    counts = asyncio.run(store.read(lambda c: (c.execute("SELECT count(*) FROM mls_commits").fetchone()[0], c.execute("SELECT count(*) FROM protocol_outbox WHERE category='mls'").fetchone()[0])))
    assert counts == (1, 1)


def test_membership_event_order_removed_recipient_epoch_gate_and_replay(system):
    _, keys, new_client = system
    with new_client() as client:
        package(client, keys, "bob")
        state = group(client)
        reserved, _ = reservation(client, state, add=["bob"])
        state, _ = commit(client, reserved)
        assert client.post("/v1/mls/groups/Z3JvdXAx/gate", headers=headers("bob"), json={"epoch": 1, "recipients": ["alice"]}).status_code == 409
        first = client.get("/v1/mls/inbox", headers=headers("bob")).json()["events"][0]
        package(client, keys, "carol")
        reserved, _ = reservation(client, state, operation="add-carol", add=["carol"])
        state, _ = commit(client, reserved)
        events = client.get("/v1/mls/inbox", headers=headers("bob")).json()["events"]
        assert [e["kind"] for e in events] == ["welcome", "commit"]
        assert [e["epoch"] for e in events] == [1, 2]
        assert client.post("/v1/mls/confirm", headers=headers("bob"), json={"id": events[1]["id"]}).status_code == 409
        for event in events:
            assert client.post("/v1/mls/confirm", headers=headers("bob"), json={"id": event["id"]}).status_code == 200
        assert first["id"] == events[0]["id"]
        assert client.post("/v1/mls/groups/Z3JvdXAx/gate", headers=headers("bob"), json={"epoch": 2, "recipients": ["alice"]}).status_code == 200
        reserved, _ = reservation(client, state, operation="remove-bob", remove=["bob"])
        state, _ = commit(client, reserved, welcome=None)
        removal = client.get("/v1/mls/inbox", headers=headers("bob")).json()["events"]
        assert len(removal) == 1 and removal[0]["kind"] == "commit"
        assert client.post("/v1/mls/groups/Z3JvdXAx/gate", headers=headers(), json={"epoch": 2, "recipients": ["bob"]}).status_code == 409
        assert client.post("/v1/mls/groups/Z3JvdXAx/gate", headers=headers(), json={"epoch": 3, "recipients": ["bob"]}).status_code == 409
        assert client.post("/v1/mls/groups/Z3JvdXAx/gate", headers=headers("bob"), json={"epoch": 3, "recipients": ["alice"]}).status_code == 403


def test_signature_chat_authorization_no_timeout_takeover_and_transaction_rollback(system):
    store, keys, new_client = system
    with new_client() as client:
        digest, body = package(client, keys, "bob")
        tampered = dict(body, signature=base64.b64encode(bytes(64)).decode())
        assert client.put(f"/v1/mls/keypackages/bob/{digest}", headers=headers("bob"), json=tampered).status_code == 403
        assert client.put(f"/v1/mls/keypackages/bob/{digest}", headers=headers(), json=body).status_code == 403
        assert client.put("/v1/mls/groups/Z3JvdXAx", headers=headers("outsider"), json={"chat_id": "chat1", "ciphersuite": "0x0001"}).status_code == 403
        state = group(client)
        denied = {"operation_id": "bad", "base_epoch": 0, "base_head": state["head"], "add_devices": ["outsider"]}
        assert client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json=denied).status_code == 403
        # If one package is missing, prior claims in the same transaction roll back.
        missing = dict(denied, add_devices=["bob", "carol"])
        assert client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json=missing).status_code == 409
        reserved, request = reservation(client, state, add=["bob"])
        asyncio.run(store.transaction(lambda c: c.execute("UPDATE mls_reservations SET created_at=0")))
        assert client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json=dict(request, operation_id="timed-out-takeover")).status_code == 409
        assert client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers("bob"), json=request).status_code == 403
        assert client.post("/v1/mls/groups/Z3JvdXAx/gate", headers=headers(), json={"epoch": 0, "recipients": ["alice"]}).status_code == 409
        assert reserved["token"] == client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json=request).json()["token"]


def test_concurrent_reservations_exactly_one_wins(system):
    store, keys, new_client = system
    with new_client() as client:
        package(client, keys, "bob")
        state = group(client)
        def reserve(operation):
            return client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json={"operation_id": operation, "base_epoch": 0, "base_head": state["head"], "add_devices": ["bob"]})
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(reserve, ["one", "two"]))
        assert sorted(r.status_code for r in results) == [200, 409]
        assert asyncio.run(store.read(lambda c: c.execute("SELECT count(*) FROM mls_reservations WHERE state='reserved'").fetchone()[0])) == 1


def test_revoked_and_unsupported_device_cannot_publish_or_receive(system):
    store, keys, new_client = system
    with new_client() as client:
        digest, body = package(client, keys, "bob")
        asyncio.run(store.transaction(lambda c: c.execute("UPDATE devices SET revoked=1 WHERE device_id='bob'")))
        assert client.get("/v1/mls/inbox", headers=headers("bob")).status_code == 403
        state = group(client)
        response = client.post("/v1/mls/groups/Z3JvdXAx/reservations", headers=headers(), json={"operation_id": "revoked", "base_epoch": 0, "base_head": state["head"], "add_devices": ["bob"]})
        assert response.status_code == 409
        asyncio.run(store.transaction(lambda c: c.execute("UPDATE devices SET capabilities='{}' WHERE device_id='alice'")))
        assert client.put("/v1/mls/groups/Z3JvdXAy", headers=headers(), json={"chat_id": "chat1", "ciphersuite": "0x0001"}).status_code == 409


def test_mailbox_gate_uses_same_transaction_epoch_membership_and_control_state(system):
    store, keys, new_client = system
    with new_client() as client:
        package(client, keys, "bob")
        state = group(client)
        reserved, _ = reservation(client, state, add=["bob"])
        state, _ = commit(client, reserved)
        def gate(sender="alice", recipient="bob", session="mls:Z3JvdXAx:1"):
            return asyncio.run(store.transaction(lambda c: validate_mls_delivery(c, sender, recipient, session)))
        gate()
        for session in ("mls:Z3JvdXAx=:1", "mls:Z3JvdXAx:01", "mls:Z3JvdXAx:9007199254740992", "mls:bad*:1", "mls:Z3JvdXAx:1:extra"):
            with pytest.raises(HTTPException):
                gate(session=session)
        with pytest.raises(HTTPException, match="mls_control_sync_required"):
            gate(sender="bob", recipient="alice")
        event = client.get("/v1/mls/inbox", headers=headers("bob")).json()["events"][0]
        assert client.post("/v1/mls/confirm", headers=headers("bob"), json={"id": event["id"]}).status_code == 200
        gate(sender="bob", recipient="alice")
        reserved, _ = reservation(client, state, operation="remove-bob", remove=["bob"])
        with pytest.raises(HTTPException, match="mls_membership_change_pending"):
            gate()
        commit(client, reserved, welcome=None)
        with pytest.raises(HTTPException, match="mls_epoch_delivery_paused"):
            gate()
        with pytest.raises(HTTPException, match="mls_recipient_or_sender_removed"):
            gate(session="mls:Z3JvdXAx:2")


def test_control_fanout_references_single_immutable_commit_blob(system):
    store, keys, new_client = system
    with new_client() as client:
        package(client, keys, "bob")
        package(client, keys, "carol")
        state = group(client)
        reserved, _ = reservation(client, state, operation="add-both", add=["bob", "carol"])
        commit(client, reserved, welcome=b"large welcome" * 10000)
        rows = asyncio.run(store.read(lambda c: c.execute("SELECT sum(length(payload)),count(*) FROM mls_events").fetchone()))
        assert tuple(rows) == (0, 2)
        bob = client.get("/v1/mls/inbox", headers=headers("bob")).json()["events"]
        carol = client.get("/v1/mls/inbox", headers=headers("carol")).json()["events"]
        assert base64.b64decode(bob[0]["payload"]) == b"large welcome" * 10000
        assert bob[0]["payload"] == carol[0]["payload"]
        assert bob[0]["id"] != carol[0]["id"]


def test_control_inbox_page_cursor_does_not_confirm_or_skip_pending(system):
    store, keys, new_client = system
    with new_client() as client:
        package(client, keys, "bob")
        state = group(client)
        reserved, _ = reservation(client, state, add=["bob"])
        commit(client, reserved)
        def add_controls(conn):
            for number in range(1, 35):
                operation = f"event-{number}"
                conn.execute("INSERT INTO mls_reservations VALUES(?,?,?,?,?,?,?,'committed',?)",
                             ("Z3JvdXAx", operation, "a" * 64, "alice", number, "b" * 64, '{}', 1))
                conn.execute("INSERT INTO mls_commits VALUES(?,?,?,?,?,?,?,?)",
                             ("Z3JvdXAx", operation, "c" * 64, number + 1, "d" * 64, b"opaque commit", None, 1))
                conn.execute("INSERT INTO mls_events(group_id,operation_id,recipient,epoch,kind,payload,head) VALUES(?,?,?,?,?,?,?)",
                             ("Z3JvdXAx", operation, "bob", number + 1, "commit", b"", "d" * 64))
        asyncio.run(store.transaction(add_controls))
        first = client.get("/v1/mls/inbox", headers=headers("bob")).json()
        assert len(first["events"]) == 32 and first["next"] == first["events"][-1]["id"]
        second = client.get(f"/v1/mls/inbox?after={first['next']}", headers=headers("bob")).json()
        assert len(second["events"]) == 3 and second["next"] is None
        replay = client.get("/v1/mls/inbox", headers=headers("bob")).json()
        assert replay == first
        assert client.get("/v1/mls/inbox", headers=headers("carol")).json()["events"] == []
