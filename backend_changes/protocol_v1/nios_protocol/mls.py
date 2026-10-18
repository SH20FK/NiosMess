"""Ordered opaque MLS control delivery; group secrets stay on devices.

Reservations deliberately do not expire. The current client merges its own MLS
commit before returning bytes, so handing its reservation to another writer
would fork the group. Coordinator replacement is not part of this protocol.
"""
from __future__ import annotations

import base64
import hashlib
import json
import re
import secrets
import time
from typing import Awaitable, Callable

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from fastapi import APIRouter, HTTPException, Request

from .auth import (Authenticator, Principal, json_body, registered_in_transaction,
                   require_registered)
from .store import ProtocolStore

ChatAuthorizer = Callable[[Principal, str, str, list[str]], Awaitable[bool]]
_ID = re.compile(r"^[A-Za-z0-9._:@-]{1,180}$")
_HASH = re.compile(r"^[a-f0-9]{64}$")
_MAX_EPOCH = 9007199254740991
_SCHEMA = """
CREATE TABLE IF NOT EXISTS mls_groups (
 group_id TEXT PRIMARY KEY, chat_id TEXT NOT NULL,
 coordinator TEXT NOT NULL REFERENCES devices(device_id),
 epoch INTEGER NOT NULL, head TEXT NOT NULL, created_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS mls_members (
 group_id TEXT NOT NULL REFERENCES mls_groups(group_id),
 device_id TEXT NOT NULL REFERENCES devices(device_id),
 active INTEGER NOT NULL, joined_epoch INTEGER NOT NULL,
 removed_epoch INTEGER, PRIMARY KEY(group_id,device_id)
);
CREATE TABLE IF NOT EXISTS mls_keypackages (
 digest TEXT PRIMARY KEY, device_id TEXT NOT NULL REFERENCES devices(device_id),
 package BLOB NOT NULL, expires_at INTEGER NOT NULL, signature BLOB NOT NULL,
 claimed_group TEXT, claimed_operation TEXT, created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS mls_keypackages_available
 ON mls_keypackages(device_id,claimed_group,expires_at,created_at);
CREATE TABLE IF NOT EXISTS mls_reservations (
 group_id TEXT NOT NULL REFERENCES mls_groups(group_id),
 operation_id TEXT NOT NULL, token TEXT NOT NULL, coordinator TEXT NOT NULL,
 base_epoch INTEGER NOT NULL, base_head TEXT NOT NULL, intent TEXT NOT NULL,
 state TEXT NOT NULL, created_at INTEGER NOT NULL,
 PRIMARY KEY(group_id,operation_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS mls_one_reservation
 ON mls_reservations(group_id) WHERE state='reserved';
CREATE TABLE IF NOT EXISTS mls_commits (
 group_id TEXT NOT NULL, operation_id TEXT NOT NULL, digest TEXT NOT NULL,
 epoch INTEGER NOT NULL, head TEXT NOT NULL, commit_bytes BLOB NOT NULL,
 welcome_bytes BLOB, created_at INTEGER NOT NULL,
 PRIMARY KEY(group_id,operation_id),
 FOREIGN KEY(group_id,operation_id)
 REFERENCES mls_reservations(group_id,operation_id)
);
CREATE TABLE IF NOT EXISTS mls_events (
 id INTEGER PRIMARY KEY AUTOINCREMENT, group_id TEXT NOT NULL,
 operation_id TEXT NOT NULL, recipient TEXT NOT NULL REFERENCES devices(device_id),
 epoch INTEGER NOT NULL, kind TEXT NOT NULL, payload BLOB NOT NULL,
 head TEXT NOT NULL, confirmed INTEGER NOT NULL DEFAULT 0,
 UNIQUE(group_id,operation_id,recipient,kind)
);
CREATE INDEX IF NOT EXISTS mls_pending_events ON mls_events(recipient,confirmed,id);
"""


def _canonical(value) -> bytes:
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode()


def _id(value, name="identifier") -> str:
    if not isinstance(value, str) or not _ID.fullmatch(value):
        raise HTTPException(400, f"mls_invalid_{name}")
    return value


def _number(value, name, maximum=_MAX_EPOCH) -> int:
    if type(value) is not int or not 0 <= value <= maximum:
        raise HTTPException(400, f"mls_invalid_{name}")
    return value


def _hash(value) -> str:
    if not isinstance(value, str) or not _HASH.fullmatch(value):
        raise HTTPException(400, "mls_invalid_hash")
    return value


def _wire_group(value) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,171}", value):
        raise HTTPException(400, "mls_invalid_group")
    try:
        decoded = base64.b64decode(value + "=" * (-len(value) % 4), altchars=b"-_", validate=True)
    except ValueError:
        raise HTTPException(400, "mls_invalid_group") from None
    if not 1 <= len(decoded) <= 128 or base64.urlsafe_b64encode(decoded).decode().rstrip("=") != value:
        raise HTTPException(400, "mls_invalid_group")
    return value


def _binary(value, maximum, name) -> bytes:
    if not isinstance(value, str) or len(value) > ((maximum + 2) // 3) * 4:
        raise HTTPException(400, f"mls_invalid_{name}")
    try:
        decoded = base64.b64decode(value, validate=True)
    except (ValueError, TypeError):
        raise HTTPException(400, f"mls_invalid_{name}") from None
    if not 0 < len(decoded) <= maximum:
        raise HTTPException(400, f"mls_invalid_{name}")
    return decoded


async def _body(request: Request, maximum: int) -> dict:
    return await json_body(request, limit=maximum, timeout=30)


def _capable(conn, device: str):
    row = conn.execute("SELECT * FROM devices WHERE device_id=?", (device,)).fetchone()
    if row is None or row["revoked"] or not row["mls_key"]:
        raise HTTPException(409, "mls_device_unavailable")
    try:
        profile = json.loads(row["capabilities"]).get("mls", {})
        supported = "1.0" in profile.get("versions", []) and "0x0001" in profile.get("suites", [])
    except (ValueError, TypeError, AttributeError):
        supported = False
    if not supported:
        raise HTTPException(409, "mls_device_upgrade_required")
    return row


def _group(conn, group_id: str):
    row = conn.execute("SELECT * FROM mls_groups WHERE group_id=?", (group_id,)).fetchone()
    if row is None:
        raise HTTPException(404, "mls_group_unavailable")
    return row


def _coordinator(group, principal):
    if group["coordinator"] != principal.device_id:
        raise HTTPException(403, "mls_coordinator_required")


def _reservation_result(conn, row):
    packages = conn.execute(
        "SELECT digest,device_id,package FROM mls_keypackages WHERE claimed_group=? AND claimed_operation=? ORDER BY device_id",
        (row["group_id"], row["operation_id"]),
    ).fetchall()
    return {
        "operation_id": row["operation_id"], "token": row["token"],
        "base_epoch": row["base_epoch"], "base_head": row["base_head"],
        "state": row["state"], "intent": json.loads(row["intent"]),
        "keypackages": [{"device_id": p["device_id"], "hash": p["digest"],
                         "package": base64.b64encode(p["package"]).decode()} for p in packages],
    }


def _event(conn, group_id, operation, device, epoch, kind, payload, head):
    event_id = conn.execute(
        "INSERT INTO mls_events(group_id,operation_id,recipient,epoch,kind,payload,head) VALUES(?,?,?,?,?,?,?)",
        # The authoritative bytes are already in mls_commits. Do not multiply
        # a 4 MiB Welcome/commit by every recipient in a large group. Keep this
        # compatibility column empty and join the immutable control record.
        (group_id, operation, device, epoch, kind, b"", head)).lastrowid
    conn.execute(
        "INSERT INTO protocol_outbox(device_id,category,object_id,created_at) VALUES(?,'mls',?,?)",
        (device, str(event_id), int(time.time())))


def validate_mls_delivery(connection, sender: str, recipient: str, session: str) -> None:
    """Mailbox gate in the same transaction as a NEW operation insertion.

    Exact already-stored retries must be deduplicated before this check. Old
    device ACKs are allowed to finish after membership changes and do not pass
    this gate. Direct transports perform the corresponding authenticated gate
    request themselves; already transmitted old-epoch bytes cannot be revoked.
    """
    parts = session.split(":")
    if (len(parts) != 3 or parts[0] != "mls"
            or not re.fullmatch(r"[A-Za-z0-9_-]{1,171}", parts[1])
            or not re.fullmatch(r"0|[1-9][0-9]{0,15}", parts[2])):
        raise HTTPException(400, "mls_invalid_link_session")
    group_id, epoch = parts[1], int(parts[2])
    try:
        group_bytes = base64.b64decode(group_id + "=" * (-len(group_id) % 4), altchars=b"-_", validate=True)
    except ValueError:
        raise HTTPException(400, "mls_invalid_link_session") from None
    if (not 1 <= len(group_bytes) <= 128
            or base64.urlsafe_b64encode(group_bytes).decode().rstrip("=") != group_id
            or epoch > _MAX_EPOCH):
        raise HTTPException(400, "mls_invalid_link_session")
    if connection.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='mls_groups'").fetchone() is None:
        raise HTTPException(409, "mls_unavailable")
    group = connection.execute("SELECT epoch FROM mls_groups WHERE group_id=?", (group_id,)).fetchone()
    if group is None:
        raise HTTPException(409, "mls_group_unavailable")
    if group["epoch"] != epoch:
        raise HTTPException(409, "mls_epoch_delivery_paused")
    if connection.execute("SELECT 1 FROM mls_reservations WHERE group_id=? AND state='reserved'", (group_id,)).fetchone():
        raise HTTPException(409, "mls_membership_change_pending")
    for device in (sender, recipient):
        _capable(connection, device)
        if connection.execute("SELECT 1 FROM mls_members WHERE group_id=? AND device_id=? AND active=1", (group_id, device)).fetchone() is None:
            raise HTTPException(409, "mls_recipient_or_sender_removed")
    if connection.execute("SELECT 1 FROM mls_events WHERE recipient=? AND group_id=? AND confirmed=0", (sender, group_id)).fetchone():
        raise HTTPException(409, "mls_control_sync_required")


def create_mls_router(store: ProtocolStore, authenticate: Authenticator,
                      authorize_chat: ChatAuthorizer) -> APIRouter:
    router = APIRouter()
    initialized = False

    async def principal(request):
        nonlocal initialized
        if not initialized:
            await store.ensure_schema(_SCHEMA)
            initialized = True
        return await require_registered(store, await authenticate(request))

    async def allowed(who, chat_id, action, devices):
        if not await authorize_chat(who, chat_id, action, devices):
            raise HTTPException(403, "mls_chat_access_denied")

    @router.put("/v1/mls/keypackages/{device}/{digest}")
    async def publish_package(device: str, digest: str, request: Request):
        who = await principal(request)
        if _id(device, "device") != who.device_id:
            raise HTTPException(403, "mls_device_mismatch")
        _hash(digest)
        body = await _body(request, 100000)
        package = _binary(body.get("package"), 65536, "keypackage")
        signature = _binary(body.get("signature"), 64, "signature")
        expires = _number(body.get("expires_at"), "expiry")
        now = int(time.time())
        if len(signature) != 64 or not now < expires <= now + 604800:
            raise HTTPException(400, "mls_invalid_expiry_or_signature")
        if hashlib.sha256(package).hexdigest() != digest:
            raise HTTPException(400, "mls_keypackage_hash_mismatch")

        def save(conn):
            registered_in_transaction(conn, who)
            record = _capable(conn, device)
            # This signs transport publication metadata. The MLS KeyPackage's
            # own credential/lifetime/signatures are checked by OpenMLS clients.
            try:
                link_key = record["link_key"]
                if isinstance(link_key, str):
                    link_key = base64.b64decode(link_key, validate=True)
                Ed25519PublicKey.from_public_bytes(link_key).verify(
                    signature, _canonical(["nios-mls-keypackage", 1, device, digest, expires]))
            except (InvalidSignature, ValueError, TypeError):
                raise HTTPException(403, "mls_invalid_publication_signature") from None
            old = conn.execute("SELECT * FROM mls_keypackages WHERE digest=?", (digest,)).fetchone()
            if old is not None:
                if old["device_id"] != device or old["package"] != package or old["expires_at"] != expires or old["signature"] != signature:
                    raise HTTPException(409, "mls_keypackage_conflict")
                return {"stored": True, "hash": digest}
            count = conn.execute("SELECT count(*) FROM mls_keypackages WHERE device_id=? AND claimed_group IS NULL AND expires_at>?", (device, now)).fetchone()[0]
            if count >= 100:
                raise HTTPException(429, "mls_keypackage_quota")
            conn.execute("INSERT INTO mls_keypackages(digest,device_id,package,expires_at,signature,created_at) VALUES(?,?,?,?,?,?)",
                         (digest, device, package, expires, signature, now))
            return {"stored": True, "hash": digest}
        return await store.transaction(save)

    @router.put("/v1/mls/groups/{group_id}")
    async def create_group(group_id: str, request: Request):
        who = await principal(request)
        _wire_group(group_id)
        body = await _body(request, 4096)
        chat_id = _id(body.get("chat_id"), "chat")
        if body.get("ciphersuite") != "0x0001":
            raise HTTPException(400, "mls_unsupported_ciphersuite")
        await allowed(who, chat_id, "create", [who.device_id])
        head = hashlib.sha256(_canonical(["nios-mls-group", 1, group_id, who.device_id])).hexdigest()

        def save(conn):
            registered_in_transaction(conn, who)
            _capable(conn, who.device_id)
            old = conn.execute("SELECT * FROM mls_groups WHERE group_id=?", (group_id,)).fetchone()
            if old is not None:
                if old["chat_id"] != chat_id or old["coordinator"] != who.device_id:
                    raise HTTPException(409, "mls_group_conflict")
                return {"group_id": group_id, "epoch": old["epoch"], "head": old["head"], "coordinator": old["coordinator"]}
            if conn.execute("SELECT count(*) FROM mls_groups WHERE coordinator=?", (who.device_id,)).fetchone()[0] >= 1024:
                raise HTTPException(429, "mls_group_quota")
            conn.execute("INSERT INTO mls_groups VALUES(?,?,?,?,?,?)", (group_id, chat_id, who.device_id, 0, head, int(time.time())))
            conn.execute("INSERT INTO mls_members VALUES(?,?,1,0,NULL)", (group_id, who.device_id))
            return {"group_id": group_id, "epoch": 0, "head": head, "coordinator": who.device_id}
        return await store.transaction(save)

    @router.get("/v1/mls/groups/{group_id}")
    async def group_state(group_id: str, request: Request):
        who = await principal(request)
        _wire_group(group_id)

        def read(conn):
            registered_in_transaction(conn, who)
            group = _group(conn, group_id)
            if conn.execute("SELECT 1 FROM mls_members WHERE group_id=? AND device_id=? AND active=1", (group_id, who.device_id)).fetchone() is None:
                raise HTTPException(404, "mls_group_unavailable")
            members = [row[0] for row in conn.execute("SELECT device_id FROM mls_members WHERE group_id=? AND active=1 ORDER BY device_id", (group_id,))]
            reservation = conn.execute("SELECT operation_id FROM mls_reservations WHERE group_id=? AND state='reserved'", (group_id,)).fetchone()
            return {"group_id": group_id, "chat_id": group["chat_id"], "epoch": group["epoch"], "head": group["head"], "coordinator": group["coordinator"], "members": members, "pending_operation": reservation[0] if reservation else None}
        result = await store.read(read)
        await allowed(who, result["chat_id"], "participate", [])
        return result

    @router.post("/v1/mls/groups/{group_id}/reservations")
    async def reserve(group_id: str, request: Request):
        who = await principal(request)
        _wire_group(group_id)
        body = await _body(request, 32768)
        operation = _id(body.get("operation_id"), "operation")
        epoch = _number(body.get("base_epoch"), "epoch", _MAX_EPOCH - 1)
        head = _hash(body.get("base_head"))
        additions, removals = body.get("add_devices", []), body.get("remove_devices", [])
        for values in (additions, removals):
            if not isinstance(values, list) or len(values) > 64:
                raise HTTPException(400, "mls_invalid_membership_change")
            for value in values:
                _id(value, "device")
            if len(set(values)) != len(values):
                raise HTTPException(400, "mls_duplicate_device")
        if bool(additions) == bool(removals):
            raise HTTPException(400, "mls_one_membership_change_required")
        additions, removals = sorted(additions), sorted(removals)
        intent = _canonical({"add_devices": additions, "remove_devices": removals}).decode()
        group = await store.read(lambda conn: dict(_group(conn, group_id)))
        _coordinator(group, who)
        await allowed(who, group["chat_id"], "add" if additions else "remove", additions or removals)

        def save(conn):
            registered_in_transaction(conn, who)
            group = _group(conn, group_id)
            _coordinator(group, who)
            _capable(conn, who.device_id)
            old = conn.execute("SELECT * FROM mls_reservations WHERE group_id=? AND operation_id=?", (group_id, operation)).fetchone()
            if old is not None:
                if old["base_epoch"] != epoch or old["base_head"] != head or old["intent"] != intent or old["coordinator"] != who.device_id:
                    raise HTTPException(409, "mls_operation_conflict")
                return _reservation_result(conn, old)
            if group["epoch"] != epoch or group["head"] != head:
                raise HTTPException(409, "mls_stale_group_head")
            if conn.execute("SELECT 1 FROM mls_reservations WHERE group_id=? AND state='reserved'", (group_id,)).fetchone():
                raise HTTPException(409, "mls_reservation_pending")
            active = {row[0] for row in conn.execute("SELECT device_id FROM mls_members WHERE group_id=? AND active=1", (group_id,))}
            if set(additions) & active or not set(removals) <= active or who.device_id in removals:
                raise HTTPException(409, "mls_invalid_membership_change")
            if len(active) + len(additions) - len(removals) > 256:
                raise HTTPException(429, "mls_group_device_quota")
            used_bytes = conn.execute("SELECT coalesce(sum(length(commit_bytes)+coalesce(length(welcome_bytes),0)),0) FROM mls_commits WHERE group_id=?", (group_id,)).fetchone()[0]
            # Reserve enough control capacity BEFORE the client merges a new
            # native epoch. Existing accepted controls are never evicted by TTL.
            if used_bytes > 256 * 1024 * 1024 - 8 * 1024 * 1024:
                raise HTTPException(507, "mls_group_storage_full")
            now = int(time.time())
            for device in additions:
                _capable(conn, device)
                package = conn.execute("SELECT digest FROM mls_keypackages WHERE device_id=? AND claimed_group IS NULL AND expires_at>? ORDER BY created_at,digest LIMIT 1", (device, now)).fetchone()
                if package is None:
                    raise HTTPException(409, "mls_keypackage_unavailable")
                conn.execute("UPDATE mls_keypackages SET claimed_group=?,claimed_operation=? WHERE digest=?", (group_id, operation, package[0]))
            conn.execute("INSERT INTO mls_reservations VALUES(?,?,?,?,?,?,?,'reserved',?)", (group_id, operation, secrets.token_hex(32), who.device_id, epoch, head, intent, now))
            row = conn.execute("SELECT * FROM mls_reservations WHERE group_id=? AND operation_id=?", (group_id, operation)).fetchone()
            return _reservation_result(conn, row)
        return await store.transaction(save)

    @router.put("/v1/mls/groups/{group_id}/commits/{operation}")
    async def publish_commit(group_id: str, operation: str, request: Request):
        who = await principal(request)
        _wire_group(group_id)
        _id(operation, "operation")
        body = await _body(request, 12 * 1024 * 1024)
        token = body.get("token")
        if not isinstance(token, str) or not re.fullmatch(r"[a-f0-9]{64}", token):
            raise HTTPException(400, "mls_invalid_reservation_token")
        commit = _binary(body.get("commit"), 4 * 1024 * 1024, "commit")
        welcome = None if body.get("welcome") is None else _binary(body["welcome"], 4 * 1024 * 1024, "welcome")
        base_epoch = _number(body.get("base_epoch"), "epoch", _MAX_EPOCH - 1)
        new_epoch = _number(body.get("epoch"), "epoch")
        if new_epoch != base_epoch + 1:
            raise HTTPException(409, "mls_epoch_transition_mismatch")
        digest = hashlib.sha256(_canonical(["nios-mls-commit", 1, group_id, operation, base_epoch, new_epoch,
            base64.b64encode(commit).decode(), None if welcome is None else base64.b64encode(welcome).decode()])).hexdigest()
        group = await store.read(lambda conn: dict(_group(conn, group_id)))
        _coordinator(group, who)
        reservation_intent = await store.read(lambda conn: conn.execute(
            "SELECT intent FROM mls_reservations WHERE group_id=? AND operation_id=?",
            (group_id, operation)).fetchone())
        if reservation_intent is None:
            raise HTTPException(409, "mls_reservation_required")
        intent = json.loads(reservation_intent[0])
        await allowed(who, group["chat_id"], "add" if intent["add_devices"] else "remove",
                      intent["add_devices"] or intent["remove_devices"])

        def save(conn):
            registered_in_transaction(conn, who)
            group = _group(conn, group_id)
            _coordinator(group, who)
            _capable(conn, who.device_id)
            reservation = conn.execute("SELECT * FROM mls_reservations WHERE group_id=? AND operation_id=?", (group_id, operation)).fetchone()
            if reservation is None or not secrets.compare_digest(reservation["token"], token):
                raise HTTPException(409, "mls_reservation_required")
            old = conn.execute("SELECT * FROM mls_commits WHERE group_id=? AND operation_id=?", (group_id, operation)).fetchone()
            if old is not None:
                if old["digest"] != digest:
                    raise HTTPException(409, "mls_commit_conflict")
                return {"stored": True, "digest": digest, "epoch": old["epoch"], "head": old["head"]}
            if reservation["base_epoch"] != base_epoch or group["epoch"] != base_epoch or group["head"] != reservation["base_head"] or reservation["state"] != "reserved":
                raise HTTPException(409, "mls_stale_group_head")
            change = json.loads(reservation["intent"])
            if bool(change["add_devices"]) != (welcome is not None):
                raise HTTPException(400, "mls_welcome_mismatch")
            for device in change["add_devices"]:
                _capable(conn, device)
            head = hashlib.sha256(_canonical(["nios-mls-head", 1, group["head"], digest, new_epoch])).hexdigest()
            existing = [row[0] for row in conn.execute("SELECT device_id FROM mls_members WHERE group_id=? AND active=1 ORDER BY device_id", (group_id,))]
            conn.execute("INSERT INTO mls_commits VALUES(?,?,?,?,?,?,?,?)", (group_id, operation, digest, new_epoch, head, commit, welcome, int(time.time())))
            # Existing members include those being removed: they receive the
            # removal commit but never future epochs' application fanout.
            for device in existing:
                if device != who.device_id:
                    _event(conn, group_id, operation, device, new_epoch, "commit", commit, head)
            for device in change["add_devices"]:
                conn.execute("INSERT INTO mls_members VALUES(?,?,1,?,NULL) ON CONFLICT(group_id,device_id) DO UPDATE SET active=1,joined_epoch=excluded.joined_epoch,removed_epoch=NULL", (group_id, device, new_epoch))
                _event(conn, group_id, operation, device, new_epoch, "welcome", welcome, head)
            for device in change["remove_devices"]:
                conn.execute("UPDATE mls_members SET active=0,removed_epoch=? WHERE group_id=? AND device_id=?", (new_epoch, group_id, device))
            conn.execute("UPDATE mls_groups SET epoch=?,head=? WHERE group_id=?", (new_epoch, head, group_id))
            conn.execute("UPDATE mls_reservations SET state='committed' WHERE group_id=? AND operation_id=?", (group_id, operation))
            return {"stored": True, "digest": digest, "epoch": new_epoch, "head": head}
        return await store.transaction(save)

    @router.get("/v1/mls/inbox")
    async def inbox(request: Request, after: int = 0):
        who = await principal(request)
        _number(after, "cursor")

        def read(conn):
            registered_in_transaction(conn, who)
            rows = conn.execute("SELECT e.*,CASE WHEN e.kind='commit' THEN length(c.commit_bytes) ELSE length(c.welcome_bytes) END AS payload_length FROM mls_events e JOIN mls_commits c ON c.group_id=e.group_id AND c.operation_id=e.operation_id WHERE e.recipient=? AND e.confirmed=0 AND e.id>? ORDER BY e.id LIMIT 33", (who.device_id, after)).fetchall()
            # Control events can be large; cap pages by encoded bytes as well.
            page, size = [], 0
            for row in rows[:32]:
                estimated = ((row["payload_length"] + 2) // 3) * 4 + 1024
                if page and size + estimated > 6 * 1024 * 1024:
                    break
                payload = conn.execute("SELECT commit_bytes,welcome_bytes FROM mls_commits WHERE group_id=? AND operation_id=?", (row["group_id"], row["operation_id"])).fetchone()
                payload = payload["commit_bytes"] if row["kind"] == "commit" else payload["welcome_bytes"]
                encoded = {"id": row["id"], "group_id": row["group_id"], "operation_id": row["operation_id"], "epoch": row["epoch"], "kind": row["kind"], "payload": base64.b64encode(payload).decode(), "head": row["head"]}
                item_size = len(_canonical(encoded))
                if page and size + item_size > 6 * 1024 * 1024:
                    break
                page.append(encoded)
                size += item_size
            more = len(rows) > len(page)
            return {"events": page, "next": page[-1]["id"] if more and page else None}
        return await store.read(read)

    @router.post("/v1/mls/confirm")
    async def confirm(request: Request):
        who = await principal(request)
        body = await _body(request, 4096)
        event_id = _number(body.get("id"), "event")

        def save(conn):
            registered_in_transaction(conn, who)
            event = conn.execute("SELECT recipient FROM mls_events WHERE id=?", (event_id,)).fetchone()
            if event is None or event["recipient"] != who.device_id:
                raise HTTPException(404, "mls_event_unavailable")
            # Require ordered confirmation within each group. An ACK must not
            # skip an unprocessed Welcome/commit of the same group.
            group = conn.execute("SELECT group_id FROM mls_events WHERE id=?", (event_id,)).fetchone()[0]
            if conn.execute("SELECT 1 FROM mls_events WHERE recipient=? AND group_id=? AND confirmed=0 AND id<?", (who.device_id, group, event_id)).fetchone():
                raise HTTPException(409, "mls_previous_event_pending")
            conn.execute("UPDATE mls_events SET confirmed=1 WHERE id=?", (event_id,))
            return {"confirmed": True}
        return await store.transaction(save)

    @router.post("/v1/mls/groups/{group_id}/gate")
    async def delivery_gate(group_id: str, request: Request):
        """Fresh permission check before Link/Iroh group application delivery.

        The sender must also enforce this check on the transport's actual bytes.
        This endpoint does not authorize an arbitrary opaque mailbox envelope.
        """
        who = await principal(request)
        _wire_group(group_id)
        body = await _body(request, 32768)
        epoch = _number(body.get("epoch"), "epoch")
        recipients = body.get("recipients")
        if not isinstance(recipients, list) or not 1 <= len(recipients) <= 256:
            raise HTTPException(400, "mls_invalid_recipients")
        for recipient in recipients:
            _id(recipient, "device")
        if len(set(recipients)) != len(recipients):
            raise HTTPException(400, "mls_duplicate_device")

        def read(conn):
            registered_in_transaction(conn, who)
            group = _group(conn, group_id)
            members = {row[0] for row in conn.execute("SELECT device_id FROM mls_members WHERE group_id=? AND active=1", (group_id,))}
            if who.device_id not in members:
                raise HTTPException(403, "mls_sender_removed")
            if epoch != group["epoch"]:
                raise HTTPException(409, "mls_epoch_delivery_paused")
            if not set(recipients) <= members:
                raise HTTPException(409, "mls_recipient_removed")
            if conn.execute("SELECT 1 FROM mls_reservations WHERE group_id=? AND state='reserved'", (group_id,)).fetchone():
                raise HTTPException(409, "mls_membership_change_pending")
            for device in [who.device_id, *recipients]:
                _capable(conn, device)
            if conn.execute("SELECT 1 FROM mls_events WHERE recipient=? AND group_id=? AND confirmed=0", (who.device_id, group_id)).fetchone():
                raise HTTPException(409, "mls_control_sync_required")
            return {"allowed": True, "epoch": epoch, "head": group["head"], "chat_id": group["chat_id"]}
        result = await store.read(read)
        await allowed(who, result.pop("chat_id"), "participate", recipients)
        return result

    return router
