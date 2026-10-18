"""Exercise the patched *real* host against two isolated databases.

NIOS_HOST_SOURCE selects a staged release. No production DB, messages, media,
accounts or tokens are read by these tests; AsyncSessionLocal is replaced before
the first handler call. This suite additionally runs on the target Python 3.10.
"""
from __future__ import annotations

import base64
from datetime import datetime, timedelta, timezone
import hashlib
import os
from pathlib import Path
import sys
from uuid import uuid4

import httpx
import pytest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from fastapi import FastAPI

HOST = os.environ.get("NIOS_HOST_SOURCE")
pytestmark = pytest.mark.skipif(not HOST, reason="requires a staged actual NiosMess host")


@pytest.fixture
async def host(tmp_path, monkeypatch):
    sys.path.insert(0, str(Path(HOST)))
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
    import app.database as database
    from app.models.models import Base, Chat, ChatMember, ChatType, Session, User
    from app.services import secret_chat_v2 as secret
    from nios_protocol.production_adapter import install_production

    engine = create_async_engine("sqlite+aiosqlite:///" + str(tmp_path / "host.sqlite3"))
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    maker = async_sessionmaker(engine, expire_on_commit=False)
    monkeypatch.setattr(database, "AsyncSessionLocal", maker)
    keys = {1: base64.b64encode(bytes([1]) * 32).decode(),
            2: base64.b64encode(bytes([2]) * 32).decode()}
    async with maker() as db:
        for identity in (1, 2):
            db.add(User(id=identity, email=f"protocol{identity}@example.test", username=f"protocol{identity}",
                        display_name=f"Fixture {identity}", hashed_password="unused", is_active=True,
                        is_verified=True, is_banned=False, is_frozen=False))
            db.add(Session(id=identity, user_id=identity,
                           token_hash=hashlib.sha256(f"fixture-{identity}".encode()).hexdigest(),
                           public_key=keys[identity], is_active=True,
                           expires_at=datetime.now(timezone.utc) + timedelta(hours=1)))
        await db.flush()
        db.add(Chat(id=77, chat_type=ChatType.DIRECT, is_secret=True, is_banned=False,
                    user1_id=1, user2_id=2, user1_public_key=keys[1], user2_public_key=keys[2]))
        await db.flush()
        db.add_all([ChatMember(chat_id=77, user_id=1), ChatMember(chat_id=77, user_id=2)])
        for identity in (1, 2):
            await secret.register_capability(db, await db.get(User, identity), await db.get(Session, identity), 2)
        await db.commit()
    app = FastAPI()
    services = install_production(app, data_root=tmp_path / "protocol")
    client = httpx.AsyncClient(transport=httpx.ASGITransport(app), base_url="https://test.invalid")
    try:
        yield maker, services, client, keys
    finally:
        await client.aclose()
        await engine.dispose()
        sys.path.remove(str(Path(HOST)))


async def enroll(client, user_id, legacy_key):
    from nios_protocol.auth import Principal
    from nios_protocol.devices import enrollment_bytes, protocols, registration_bytes
    from test_devices import b64, public
    principal = Principal(str(user_id), user_id, user_id, legacy_public_key=legacy_key)
    device = f"fixture-device-{user_id}"
    headers = {"Authorization": f"Bearer fixture-{user_id}"}
    response = await client.post(f"/v1/devices/{device}/challenge", headers=headers, json={})
    assert response.status_code == 200, response.text
    identity, link = Ed25519PrivateKey.generate(), Ed25519PrivateKey.generate()
    body = {"challenge": response.json()["challenge"], "identity_key": public(identity),
            "link_key": public(link), "mls_key": None, "endpoint_key": None, "legacy_key": legacy_key,
            "protocols": protocols({"stream": [1]})}
    registration = registration_bytes(str(user_id), device, body, body["protocols"])
    body["identity_signature"] = b64(identity.sign(registration))
    body["device_proof"] = b64(link.sign(enrollment_bytes(principal, device, body["challenge"], registration)))
    response = await client.put(f"/v1/devices/{device}", headers=headers, json=body)
    assert response.status_code == 200, response.text
    return headers


@pytest.mark.asyncio
async def test_actual_auth_secret_send_sync_dedupe_range_and_device_binding(host):
    from sqlalchemy import func, select
    from app.models.models import Chat, Message, Session, UnreadCounter, User
    from app.services import secret_chat_v2 as secret
    from test_blobs import encrypted_file
    from nios_protocol.auth import canonical

    maker, services, client, keys = host
    alice = await enroll(client, 1, keys[1])
    bob = await enroll(client, 2, keys[2])
    assert (await client.get("/v1/protocols", headers=alice)).json()["stream"] == [1]
    assert (await client.get("/v1/protocols")).status_code == 401
    _, _, manifest, digest, ciphertext = encrypted_file(length=10001)
    assert (await client.put(f"/v1/manifests/{digest}", headers=alice, content=canonical(manifest))).status_code == 201
    assert (await client.put(f"/v1/blobs/{digest}", headers=alice, content=ciphertext)).status_code == 201
    assert (await client.post(f"/v1/blobs/{digest}/grants", headers=alice, json={"chat_id": 77})).status_code == 200
    payload = {"chat_id": 77, "client_message_id": str(uuid4()), "e2ee_content": "opaque-authenticated-client-body",
               "upload_id": "nios-stream:" + digest, "media_subtype": "media"}
    async with maker() as db:
        user, session = await db.get(User, 1), await db.get(Session, 1)
        first = await secret.handle_secret_mutation("send_message", payload, db, user, session)
        await db.commit()
    assert first["media_url"] == "https://ni-os.ru/v1/blobs/" + digest
    assert first["media_name"] == "encrypted.bin" and first["media_type"] == "application/octet-stream"
    async with maker() as db:
        replay = await secret.handle_secret_mutation("send_message", payload, db,
                                                    await db.get(User, 1), await db.get(Session, 1))
        await db.commit()
        assert replay["id"] == first["id"]
        assert await db.scalar(select(func.count()).select_from(Message)) == 1
        assert await db.scalar(select(UnreadCounter.count).where(UnreadCounter.user_id == 2)) == 1
        sync = await secret.handle_secret_sync({"chat_id": 77}, db, await db.get(User, 2), await db.get(Session, 2))
        assert sync["peer_stream_protocol_versions"] == [1]
        assert [event["payload"]["id"] for event in sync["events"]] == [first["id"]]
        await db.commit()
    response = await client.get(f"/v1/blobs/{digest}", headers={**bob, "Range": "bytes=200-499"})
    assert response.status_code == 206 and response.content == ciphertext[200:500]
    async with maker() as db:
        chat = await db.get(Chat, 77)
        chat.user2_public_key = "a-different-device"
        await db.commit()
    assert (await client.head(f"/v1/blobs/{digest}", headers=bob)).status_code == 404
    async with maker() as db:
        session = await db.get(Session, 1)
        session.is_active = False
        await db.commit()
    assert (await client.head(f"/v1/blobs/{digest}", headers=alice)).status_code == 401


@pytest.mark.asyncio
async def test_host_membership_privacy_and_unknown_delivery_domains_fail_closed(host):
    from app.models.models import Chat, ChatMember, ChatType, MemberRole, Session, User
    from nios_protocol.auth import require_registered
    from nios_protocol.production_adapter import principal_for_session
    from sqlalchemy import select

    maker, services, client, keys = host
    await enroll(client, 1, keys[1])
    await enroll(client, 2, keys[2])
    async with maker() as db:
        actor = principal_for_session(await db.get(User, 1), await db.get(Session, 1))
        peer = principal_for_session(await db.get(User, 2), await db.get(Session, 2))
        db.add(Chat(id=88, chat_type=ChatType.GROUP, created_by=1, is_secret=False))
        await db.flush()
        db.add_all([ChatMember(chat_id=88, user_id=1, role=MemberRole.OWNER),
                    ChatMember(chat_id=88, user_id=2, role=MemberRole.MEMBER)])
        await db.commit()
    actor = await require_registered(services.store, actor)
    peer = await require_registered(services.store, peer)
    assert await services.authorize_mls(actor, "88", "create", [actor.device_id])
    assert not await services.authorize_mls(peer, "88", "create", [peer.device_id])
    assert await services.authorize_mls(actor, "88", "participate", [peer.device_id])
    assert not await services.authorize_mls(actor, "77", "create", [actor.device_id])
    assert not await services.authorize_delivery(actor, {"kind": "operation", "session": "unscoped",
                                                       "recipient": peer.device_id})
    assert not await services.authorize_delivery(actor, {"kind": "ack", "session": "chat:77",
        "recipient": peer.device_id, "id": "nonexistent", "sequence": 1})
    assert await services.resolve_grants(actor, 77, None) == [peer.device_id]
    async with maker() as db:
        membership = await db.scalar(select(ChatMember).where(ChatMember.chat_id == 77, ChatMember.user_id == 2))
        membership.is_banned = True
        group_membership = await db.scalar(select(ChatMember).where(ChatMember.chat_id == 88, ChatMember.user_id == 2))
        await db.delete(group_membership)
        await db.commit()
    from fastapi import HTTPException
    with pytest.raises(HTTPException):
        await services.resolve_grants(actor, 77, None)
    assert not await services.authorize_mls(actor, "88", "participate", [peer.device_id])
    # An administrator can still remove a departed device's old MLS membership.
    assert await services.authorize_mls(actor, "88", "remove", [peer.device_id])
