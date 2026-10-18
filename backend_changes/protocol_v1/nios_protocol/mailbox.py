"""Opaque, durable per-device mailboxes with byte-identical retry semantics."""

from __future__ import annotations

import hashlib
import json
import re
from typing import Awaitable, Callable

from fastapi import APIRouter, HTTPException, Request

from .auth import (Authenticator, Principal, base64_bytes, canonical, json_body,
                   registered_in_transaction, require_registered)
from .devices import now_ms, verify_signature
from .store import ProtocolStore

DIGEST = re.compile(r"^[a-f0-9]{64}$")
MAXIMUM_ENVELOPE_BYTES = 1_500_000
MAXIMUM_MAILBOX_BYTES = 128 * 1024 * 1024
MAXIMUM_MAILBOX_RECORDS = 100_000
DeliveryAuthorizer = Callable[[Principal, dict], Awaitable[bool]]


def parse_envelope(body: dict, kind: str) -> tuple[dict, bytes, str]:
    required = {"v", "kind", "sender", "recipient", "session", "id", "sequence", "nonce", "ciphertext", "mac", "signature"}
    if set(body) != required or type(body.get("v")) is not int or body["v"] != 1 or body.get("kind") != kind:
        raise HTTPException(422, "invalid_envelope_domain")
    for field in ("sender", "recipient", "session", "id"):
        value = body.get(field)
        if not isinstance(value, str) or not 1 <= len(value) <= 256:
            raise HTTPException(422, "invalid_envelope_identifier")
        try:
            value.encode("utf-8")
        except UnicodeError:
            raise HTTPException(422, "invalid_envelope_identifier") from None
    sequence = body.get("sequence")
    if type(sequence) is not int or not 1 <= sequence <= 9_007_199_254_740_991:
        raise HTTPException(422, "invalid_envelope_sequence")
    base64_bytes(body.get("nonce"), 12)
    base64_bytes(body.get("ciphertext"), maximum=1_048_576)
    base64_bytes(body.get("mac"), 16)
    base64_bytes(body.get("signature"), 64)
    unsigned = {field: body[field] for field in ("v", "kind", "sender", "recipient", "session", "id", "sequence", "nonce", "ciphertext", "mac")}
    encoded = canonical({**unsigned, "signature": body["signature"]})
    if len(encoded) > MAXIMUM_ENVELOPE_BYTES:
        raise HTTPException(413, "envelope_too_large")
    return unsigned, encoded, hashlib.sha256(encoded).hexdigest()


def create_mailbox_router(store: ProtocolStore, authenticate: Authenticator,
                          authorize_delivery: DeliveryAuthorizer | None = None) -> APIRouter:
    router = APIRouter()

    async def publish(request: Request, kind: str):
        principal = await require_registered(store, await authenticate(request))
        body = await json_body(request, limit=MAXIMUM_ENVELOPE_BYTES)
        unsigned, encoded, digest = parse_envelope(body, kind)
        if unsigned["sender"] != principal.device_id:
            raise HTTPException(403, "sender_device_mismatch")
        if authorize_delivery is not None:
            async def already_stored():
                return await store.read(lambda connection: connection.execute(
                    "SELECT 1 FROM envelopes WHERE digest=?", (digest,)).fetchone()) is not None
            if not await already_stored() and not await authorize_delivery(principal, body):
                # If another request committed during the async host ACL check,
                # this remains an idempotent receipt for that earlier commit.
                if not await already_stored():
                    raise HTTPException(403, "delivery_not_authorized")
        now = now_ms()

        def save(connection):
            sender = registered_in_transaction(connection, principal)
            verify_signature(base64_bytes(sender["link_key"], 32), body["signature"],
                             b"nios-link-device-envelope-signature-v1\x00" + canonical(unsigned))
            previous = connection.execute("SELECT digest FROM envelopes WHERE digest=?", (digest,)).fetchone()
            if previous is not None:
                return {"stored": True, "digest": digest}
            if 1 not in json.loads(sender["capabilities"]).get("link", []):
                raise HTTPException(409, "link_protocol_unavailable")
            recipient = connection.execute("SELECT * FROM devices WHERE device_id=? AND revoked=0", (unsigned["recipient"],)).fetchone()
            if recipient is None or 1 not in json.loads(recipient["capabilities"]).get("link", []):
                raise HTTPException(409, "recipient_protocol_unavailable")
            if kind == "operation":
                previous = connection.execute("""SELECT digest FROM envelopes
                    WHERE sender=? AND recipient=? AND session=? AND operation_id=? AND kind='operation'""",
                    (unsigned["sender"], unsigned["recipient"], unsigned["session"], unsigned["id"])).fetchone()
                if previous is not None:
                    raise HTTPException(409, "operation_collision")
                if unsigned["session"].startswith("mls:"):
                    from .mls import validate_mls_delivery
                    validate_mls_delivery(connection, unsigned["sender"], unsigned["recipient"], unsigned["session"])
            usage = connection.execute("SELECT record_count,byte_count FROM mailbox_usage WHERE device_id=?",
                                       (principal.device_id,)).fetchone()
            if usage is None:
                # Once-only migration for a database created before usage counters.
                count, size = connection.execute("SELECT COUNT(*),COALESCE(SUM(size),0) FROM envelopes WHERE sender=?",
                                                  (principal.device_id,)).fetchone()
                connection.execute("INSERT INTO mailbox_usage VALUES(?,?,?)", (principal.device_id, count, size))
            else:
                count, size = usage
            if count >= MAXIMUM_MAILBOX_RECORDS or size + len(encoded) > MAXIMUM_MAILBOX_BYTES:
                raise HTTPException(507, "mailbox_capacity")
            connection.execute("""INSERT INTO envelopes(digest,sender,recipient,session,operation_id,kind,envelope,size,created_at)
                VALUES(?,?,?,?,?,?,?,?,?)""", (digest, unsigned["sender"], unsigned["recipient"], unsigned["session"],
                unsigned["id"], kind, encoded.decode(), len(encoded), now))
            connection.execute("INSERT INTO protocol_outbox(device_id,category,object_id,created_at) VALUES(?,?,?,?)",
                               (unsigned["recipient"], "link", digest, now))
            connection.execute("UPDATE mailbox_usage SET record_count=record_count+1,byte_count=byte_count+? WHERE device_id=?",
                               (len(encoded), principal.device_id))
            return {"stored": True, "digest": digest}

        # The response is created only after SQLite has completed the commit.
        return await store.transaction(save)

    @router.post("/v1/messages")
    async def message(request: Request):
        return await publish(request, "operation")

    @router.post("/v1/acks")
    async def acknowledgement(request: Request):
        return await publish(request, "ack")

    @router.get("/v1/inbox")
    async def inbox(request: Request):
        principal = await require_registered(store, await authenticate(request))
        after = request.query_params.get("after")
        if set(request.query_params) - {"after"} or (after is not None and not DIGEST.fullmatch(after)):
            raise HTTPException(422, "invalid_cursor")

        def load(connection):
            registered_in_transaction(connection, principal)
            ordinal = 0
            if after is not None:
                cursor = connection.execute("SELECT ordinal FROM envelopes WHERE digest=? AND recipient=?", (after, principal.device_id)).fetchone()
                if cursor is None:
                    raise HTTPException(400, "unknown_cursor")
                ordinal = cursor[0]
            rows = connection.execute("""SELECT digest,envelope,size FROM envelopes
                WHERE recipient=? AND pending=1 AND ordinal>? ORDER BY ordinal LIMIT 101""",
                (principal.device_id, ordinal)).fetchall()
            items, size, next_cursor = [], 0, None
            for row in rows:
                if len(items) >= 100 or (items and size + row["size"] > 1_800_000):
                    next_cursor = hashlib.sha256(canonical(items[-1])).hexdigest()
                    break
                items.append(json.loads(row["envelope"]))
                size += row["size"]
            return {"envelopes": items, "next": next_cursor}

        return await store.read(load)

    @router.post("/v1/confirm")
    async def confirm(request: Request):
        principal = await require_registered(store, await authenticate(request))
        body = await json_body(request, limit=1024)
        digest = body.get("digest")
        if set(body) != {"digest"} or not isinstance(digest, str) or not DIGEST.fullmatch(digest):
            raise HTTPException(422, "invalid_digest")

        def save(connection):
            registered_in_transaction(connection, principal)
            row = connection.execute("SELECT recipient FROM envelopes WHERE digest=?", (digest,)).fetchone()
            if row is None or row[0] != principal.device_id:
                raise HTTPException(404, "envelope_not_found")
            connection.execute("UPDATE envelopes SET pending=0 WHERE digest=?", (digest,))
            return {"confirmed": True}

        return await store.transaction(save)

    return router
