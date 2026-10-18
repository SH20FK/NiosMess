"""Additive adapter for the active NiosMess FastAPI/SQLAlchemy application.

Imports of the host are lazy so protocol tests need neither production secrets
nor a messenger database. Opaque bearer tokens use the existing NiosID verifier;
the legacy session public_key remains a separate device binding.
"""
from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path

from fastapi import HTTPException, Request

from .app import install
from .auth import Principal, require_registered
from .blobs import HASH, StreamBlobs
from .iroh import create_iroh_router
from .mls import create_mls_router
from .store import ProtocolStore

_services = None


def principal_for_session(user, session) -> Principal:
    if user is None or session is None or session.user_id != user.id or not _session_active(session):
        raise HTTPException(401, "invalid_session")
    return Principal(str(user.id), user.id, session.id,
                     legacy_public_key=session.public_key,
                     session_fingerprint=session.token_hash)


def _session_active(session) -> bool:
    if not session or not session.is_active or not session.expires_at:
        return False
    expires = session.expires_at.replace(tzinfo=session.expires_at.tzinfo or timezone.utc)
    return expires > datetime.now(timezone.utc)


async def authenticate(request: Request) -> Principal:
    authorization = request.headers.get("authorization", "")
    if not authorization.startswith("Bearer ") or not 1 <= len(authorization[7:]) <= 4096:
        raise HTTPException(401, "bearer_required")
    from app.database import AsyncSessionLocal
    from app.services.nios_id_svc import authenticate_human_session
    try:
        async with AsyncSessionLocal() as db:
            user, session = await authenticate_human_session(db, authorization[7:])
            if not user or not session:
                raise HTTPException(401, "invalid_session")
            principal = principal_for_session(user, session)
            await db.commit()
            return principal
    except HTTPException:
        raise
    except Exception:
        # Auth outages must not be interpreted as a device key change or as a
        # reason to delete the client's saved data. Never echo tokens/errors.
        raise HTTPException(503, "identity_service_unavailable") from None


class ProductionServices:
    def __init__(self, store: ProtocolStore):
        self.store = store
        self.blobs = StreamBlobs(store, authenticate, self.resolve_grants, self.authorize_secret_chat)

    async def _bound_chat(self, principal, chat_id):
        from app.database import AsyncSessionLocal
        from app.models.models import Session, User
        from app.services.secret_chat_v2 import require_bound_device
        async with AsyncSessionLocal() as db:
            session = await db.get(Session, principal.session_id)
            user = await db.get(User, principal.user_id)
            if (not _session_active(session) or not user or not user.is_active
                    or user.is_banned or user.is_frozen
                    or session.user_id != principal.user_id
                    or session.token_hash != principal.session_fingerprint
                    or session.public_key != principal.legacy_public_key):
                raise HTTPException(403, "stream_chat_unavailable")
            try:
                chat = await require_bound_device(db, chat_id, user, session)
            except (ValueError, TypeError):
                raise HTTPException(403, "stream_chat_unavailable") from None
            if principal.user_id not in (chat.user1_id, chat.user2_id):
                raise HTTPException(403, "stream_chat_unavailable")
            return chat

    async def authorize_secret_chat(self, principal: Principal, chat_id: int) -> bool:
        try:
            await self._bound_chat(principal, chat_id)
            return True
        except HTTPException:
            return False

    async def resolve_grants(self, principal: Principal, chat_id: int,
                             requested: list[str] | None) -> list[str]:
        return await self._secret_targets(principal, chat_id, requested, "stream")

    async def _secret_targets(self, principal: Principal, chat_id: int,
                              requested: list[str] | None, protocol: str) -> list[str]:
        chat = await self._bound_chat(principal, chat_id)
        peer_id = chat.user2_id if chat.user1_id == principal.user_id else chat.user1_id
        peer_key = chat.user2_public_key if chat.user1_id == principal.user_id else chat.user1_public_key
        from app.database import AsyncSessionLocal
        from app.models.models import ChatMember
        from app.services.profile_svc import blocked_between, privacy_allows
        from sqlalchemy import select
        async with AsyncSessionLocal() as db:
            member = await db.scalar(select(ChatMember.id).where(
                ChatMember.chat_id == chat_id, ChatMember.user_id == peer_id,
                ChatMember.is_banned.is_(False)))
            if (not member or await blocked_between(db, principal.user_id, peer_id)
                    or not await privacy_allows(db, peer_id, principal.user_id, "messages")):
                raise HTTPException(403, "stream_chat_unavailable")
        targets = await self.devices_for_legacy_peer(peer_id, peer_key, protocol=protocol)
        if requested is not None and set(requested) != set(targets):
            raise HTTPException(403, "stream_recipient_mismatch")
        return targets

    async def devices_for_legacy_peer(self, user_id: int, key: str | None, *, protocol="stream") -> list[str]:
        if not key:
            return []
        from app.database import AsyncSessionLocal
        from app.models.models import Session, User
        from sqlalchemy import select
        async with AsyncSessionLocal() as db:
            user = await db.get(User, user_id)
            if not user or not user.is_active or user.is_banned or user.is_frozen:
                return []
            sessions = (await db.scalars(select(Session).where(
                Session.user_id == user_id, Session.public_key == key,
                Session.is_active.is_(True)))).all()
            live = {item.id: item.token_hash for item in sessions if _session_active(item)}
        if not live:
            return []
        rows = await self.store.read(lambda connection: connection.execute(
            "SELECT device_id,session_id,session_fingerprint,capabilities FROM devices "
            "WHERE user_id=? AND legacy_key=? AND revoked=0", (user_id, key)).fetchall())
        return sorted(row["device_id"] for row in rows if row["session_id"] in live
                      and row["session_fingerprint"] == live[row["session_id"]]
                      and ("nios.link/1" if protocol == "irohAlpn" else 1)
                      in json.loads(row["capabilities"]).get(protocol, []))

    async def authorize_mls(self, principal, chat_id: str, action: str, target_devices: list[str]) -> bool:
        if not chat_id.isdecimal() or len(chat_id) > 16:
            return False
        from app.database import AsyncSessionLocal
        from app.models.models import Chat, ChatMember, Session, User
        from sqlalchemy import select
        async with AsyncSessionLocal() as db:
            chat = await db.get(Chat, int(chat_id))
            member = await db.scalar(select(ChatMember).where(
                ChatMember.chat_id == int(chat_id), ChatMember.user_id == principal.user_id,
                ChatMember.is_banned.is_(False)))
            if not chat or chat.is_banned or chat.is_secret or not member:
                return False
            kind = getattr(chat.chat_type, "value", chat.chat_type)
            if kind != "group":
                return False
            role = getattr(member.role, "value", member.role)
            if action in ("create", "add", "remove") and role not in ("owner", "admin"):
                return False
            if action not in ("create", "add", "remove", "participate"):
                return False
            rows = await self.store.read(lambda connection: [dict(row) for device in target_devices
                for row in connection.execute("SELECT * FROM devices WHERE device_id=?", (device,))])
            if len(rows) != len(set(target_devices)):
                return False
            for device in rows:
                # Removed/expired devices may still need an MLS Remove. The
                # MLS service itself checks that they belonged to this group.
                if action == "remove":
                    continue
                session = await db.get(Session, device["session_id"])
                user = await db.get(User, device["user_id"])
                active_member = await db.scalar(select(ChatMember.id).where(
                    ChatMember.chat_id == int(chat_id), ChatMember.user_id == device["user_id"],
                    ChatMember.is_banned.is_(False)))
                if (device["revoked"] or not _session_active(session) or not user
                        or session.user_id != device["user_id"]
                        or session.token_hash != device["session_fingerprint"]
                        or (device["legacy_key"] is not None and session.public_key != device["legacy_key"])
                        or not user.is_active or user.is_banned or user.is_frozen or not active_member):
                    return False
            return True

    async def authorize_address(self, principal: Principal, chat_id: int, target: str) -> bool:
        from app.database import AsyncSessionLocal
        from app.models.models import Chat
        async with AsyncSessionLocal() as db:
            chat = await db.get(Chat, chat_id)
        if not chat:
            return False
        if chat.is_secret:
            try:
                return target in await self._secret_targets(principal, chat_id, None, "irohAlpn")
            except HTTPException:
                return False
        return await self.authorize_mls(principal, str(chat_id), "participate", [target])

    async def authorize_delivery(self, principal: Principal, envelope: dict) -> bool:
        session_id = envelope["session"]
        if envelope["kind"] == "ack":
            # Finishing a previously stored operation is allowed after a
            # membership change. An ACK may not become a new arbitrary inbox.
            original = await self.store.read(lambda connection: connection.execute(
                "SELECT envelope FROM envelopes WHERE kind='operation' AND sender=? "
                "AND recipient=? AND session=? AND operation_id=?",
                (envelope["recipient"], principal.device_id, session_id, envelope["id"])).fetchone())
            return bool(original and json.loads(original["envelope"])["sequence"] == envelope["sequence"])
        if session_id.startswith("chat:"):
            chat_id = session_id.removeprefix("chat:")
            if not chat_id.isdecimal() or len(chat_id) > 16 or str(int(chat_id)) != chat_id:
                return False
            try:
                return envelope["recipient"] in await self._secret_targets(principal, int(chat_id), None, "link")
            except HTTPException:
                return False
        if session_id.startswith("mls:"):
            parts = session_id.split(":")
            if len(parts) != 3:
                return False
            def group_chat(connection):
                if not connection.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='mls_groups'").fetchone():
                    return None
                return connection.execute("SELECT chat_id FROM mls_groups WHERE group_id=?", (parts[1],)).fetchone()
            group = await self.store.read(group_chat)
            return bool(group and await self.authorize_mls(principal, group["chat_id"], "participate",
                                                           [envelope["recipient"]]))
        return False


def install_production(app, *, data_root: str | Path | None = None):
    global _services
    root = Path(data_root or os.environ.get("NIOS_PROTOCOL_DATA", "/var/lib/niosmess/protocol-v1"))
    store = ProtocolStore(root / "protocol.sqlite3", root)
    services = ProductionServices(store)
    key_path = root / "key-log.seed"
    signing_key = key_path.read_bytes() if key_path.exists() else None
    if signing_key is not None and len(signing_key) != 32:
        raise RuntimeError("protocol_log_key_invalid")
    install(app, store, authenticate, log_signing_key=signing_key,
            authorize_delivery=services.authorize_delivery,
            service_capabilities={
                "stream": [1], "mls": {"versions": ["1.0"], "suites": ["0x0001"]},
                "irohAlpn": ["nios.link/1"], "irohRelay": False,
                "independentWitnesses": False,
                "limits": {"envelopeBytes": 1_500_000, "inboxPage": 100,
                           "streamFileBytes": services.blobs.maximum_file_bytes,
                           "streamRangeBytes": 1_048_592},
            })
    app.include_router(services.blobs.router)
    app.include_router(create_mls_router(store, authenticate, services.authorize_mls))
    app.include_router(create_iroh_router(store, authenticate, services.authorize_address))
    app.state.nios_protocol = services
    _services = services
    return services


async def peer_stream_versions(db, user_id: int, public_key: str | None) -> list[int]:
    if _services is None:
        return []
    return [1] if await _services.devices_for_legacy_peer(user_id, public_key) else []


async def registered_stream_versions(user, session, versions) -> list[int]:
    if versions not in (None, [], [1]):
        raise ValueError("SECRET_INVALID_STREAM_VERSION")
    if versions != [1] or _services is None:
        return []
    principal = await require_registered(_services.store, principal_for_session(user, session))
    row = await _services.store.read(lambda connection: connection.execute(
        "SELECT capabilities FROM devices WHERE device_id=?", (principal.device_id,)).fetchone())
    return [1] if 1 in json.loads(row["capabilities"]).get("stream", []) else []


async def apply_stream_upload(msg, upload_id, subtype, chat, user, session, db):
    if _services is None or not isinstance(upload_id, str) or not upload_id.startswith("nios-stream:"):
        raise ValueError("SECRET_UPLOAD_UNAVAILABLE")
    digest = upload_id.removeprefix("nios-stream:")
    if not HASH.fullmatch(digest) or subtype not in ("media", "image", "file", "video", "voice", "circle"):
        raise ValueError("SECRET_INVALID_STREAM_UPLOAD")
    from app.models.models import MessageType
    from app.services.profile_svc import privacy_allows
    principal = await require_registered(_services.store, principal_for_session(user, session))
    targets = await _services.resolve_grants(principal, chat.id, None)
    peer_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
    if subtype in ("voice", "circle") and not await privacy_allows(db, peer_id, user.id, "voice_messages"):
        raise ValueError("SECRET_RECIPIENT_RESTRICTED")
    try:
        length = await _services.blobs.validate_message(principal, digest, chat.id, targets)
    except HTTPException:
        raise ValueError("SECRET_STREAM_RECIPIENT_NOT_READY") from None
    msg.media_path = upload_id
    msg.media_iv, msg.media_tag = None, None
    msg.media_name, msg.media_type, msg.media_size = "encrypted.bin", "application/octet-stream", length
    msg.msg_type = {"voice": MessageType.VOICE, "circle": MessageType.CIRCLE}.get(subtype, MessageType.MEDIA)
