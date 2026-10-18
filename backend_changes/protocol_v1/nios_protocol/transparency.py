"""Persistent RFC 6962 proofs and SDK-compatible account-signed device entries.

The service signs its own log. No independent witnesses are fabricated, and
partial streaming-only registrations do not masquerade as MLS device bundles.
"""

from __future__ import annotations

import base64
import hashlib
import json
import re

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from fastapi import APIRouter, HTTPException, Request

from .auth import (Authenticator, base64_bytes, canonical, json_body,
                   registered_in_transaction, require_registered)
from .devices import identifier, now_ms, verify_signature
from .store import ProtocolStore


def leaf_hash(entry: bytes) -> bytes:
    return hashlib.sha256(b"\x00" + entry).digest()


def node_hash(left: bytes, right: bytes) -> bytes:
    return hashlib.sha256(b"\x01" + left + right).digest()


def split(size: int) -> int:
    return 1 << ((size - 1).bit_length() - 1)


def tree_root(connection, offset: int, size: int) -> bytes:
    if size == 0:
        return hashlib.sha256(b"").digest()
    cached = connection.execute("SELECT hash FROM kt_nodes WHERE start_index=? AND node_size=?", (offset, size)).fetchone()
    if cached is not None:
        return bytes(cached[0])
    if size == 1:
        raise RuntimeError("key_log_corrupt")
    left = split(size)
    return node_hash(tree_root(connection, offset, left), tree_root(connection, offset + left, size - left))


def inclusion(connection, index: int, offset: int, size: int) -> list[bytes]:
    if size == 1:
        return []
    left = split(size)
    if index < left:
        return inclusion(connection, index, offset, left) + [tree_root(connection, offset + left, size - left)]
    return inclusion(connection, index - left, offset + left, size - left) + [tree_root(connection, offset, left)]


def consistency(connection, old_size: int, offset: int, new_size: int, complete: bool = True) -> list[bytes]:
    if old_size == new_size:
        return [] if complete else [tree_root(connection, offset, new_size)]
    left = split(new_size)
    if old_size <= left:
        return consistency(connection, old_size, offset, left, complete) + [tree_root(connection, offset + left, new_size - left)]
    return consistency(connection, old_size - left, offset + left, new_size - left, False) + [tree_root(connection, offset, left)]


def statement_bytes(value: dict) -> bytes:
    required = {"account", "device", "revision", "action", "key", "previous", "time"}
    optional = {"linkSigningKey", "transportEndpointKey"}
    if set(value) not in (required, required | optional):
        raise HTTPException(422, "invalid_statement_fields")
    identifier(value.get("account"))
    identifier(value.get("device"))
    for field in ("revision", "time"):
        if type(value.get(field)) is not int or not 0 <= value[field] <= 9_007_199_254_740_991:
            raise HTTPException(422, "invalid_statement_counter")
    if value["revision"] < 1 or value.get("action") not in ("enroll", "revoke"):
        raise HTTPException(422, "invalid_statement_action")
    base64_bytes(value.get("key"), 32)
    base64_bytes(value.get("previous"), 32)
    extended = "linkSigningKey" in value
    if extended:
        base64_bytes(value["linkSigningKey"], 32)
        base64_bytes(value["transportEndpointKey"], 32)
    result = ["nios-device-key-statement", 2 if extended else 1,
              value["account"], value["device"], value["revision"], value["action"],
              value["key"], value["previous"], value["time"]]
    if extended:
        result.extend([value["linkSigningKey"], value["transportEndpointKey"]])
    return canonical(result)


def create_transparency_router(store: ProtocolStore, authenticate: Authenticator,
                               signing_key: Ed25519PrivateKey | bytes, *,
                               log_id: str = "niosmess-key-log-v1") -> APIRouter:
    router = APIRouter()
    identifier(log_id)
    key = Ed25519PrivateKey.from_private_bytes(signing_key) if isinstance(signing_key, bytes) else signing_key
    public_key = key.public_key().public_bytes(serialization.Encoding.Raw, serialization.PublicFormat.Raw)

    def checkpoint(connection, size: int, *, refresh: bool = False) -> dict:
        root = tree_root(connection, 0, size)
        previous = connection.execute("SELECT checkpoint,signature FROM kt_checkpoints WHERE tree_size=?", (size,)).fetchone()
        if previous is not None:
            saved = json.loads(previous[0])
            signing = canonical(["nios-key-log-checkpoint", 1, saved["log"], saved["size"], saved["root"], saved["time"]])
            try:
                key.public_key().verify(base64_bytes(previous[1], 64), signing)
            except InvalidSignature:
                raise RuntimeError("key_log_signer_changed_or_corrupt") from None
            if saved["log"] != log_id or base64_bytes(saved["root"], 32) != root:
                raise RuntimeError("key_log_checkpoint_corrupt")
            if not refresh or now_ms() - saved["time"] < 3_600_000:
                return {"checkpoint": saved, "logSignature": previous[1], "witnesses": []}
        value = {"log": log_id, "size": size, "root": base64.b64encode(root).decode(), "time": now_ms()}
        signature = base64.b64encode(key.sign(canonical(["nios-key-log-checkpoint", 1, log_id, size, value["root"], value["time"]]))).decode()
        connection.execute("INSERT INTO kt_checkpoints VALUES(?,?,?) ON CONFLICT(tree_size) DO UPDATE SET checkpoint=excluded.checkpoint,signature=excluded.signature",
                           (size, canonical(value).decode(), signature))
        return {"checkpoint": value, "logSignature": signature, "witnesses": []}

    @router.post("/v1/kt/statements")
    async def append(request: Request):
        principal = await require_registered(store, await authenticate(request))
        body = await json_body(request, limit=16_384)
        statement = body.get("statement")
        if set(body) != {"statement", "signature"} or not isinstance(statement, dict):
            raise HTTPException(422, "invalid_authorized_statement")
        signing = statement_bytes(statement)
        signature = base64_bytes(body["signature"], 64)
        encoded = canonical(["nios-authorized-device", 1, base64.b64encode(signing).decode(), body["signature"]])
        hashed = leaf_hash(encoded)
        if statement["account"] != principal.account_id:
            raise HTTPException(403, "statement_account_mismatch")

        def save(connection):
            registered_in_transaction(connection, principal)
            identity = connection.execute("SELECT identity_key FROM kt_identity_pins WHERE account_id=?", (principal.account_id,)).fetchone()
            if identity is None:
                raise HTTPException(409, "account_identity_not_enrolled_for_transparency")
            verify_signature(base64_bytes(identity[0], 32), body["signature"], signing)
            previous = connection.execute("SELECT leaf_index FROM kt_leaves WHERE leaf_hash=?", (hashed.hex(),)).fetchone()
            if previous is not None:
                return {"leafIndex": previous[0], "hash": base64.b64encode(hashed).decode()}
            device = connection.execute("SELECT * FROM devices WHERE device_id=? AND account_id=?",
                                         (statement["device"], principal.account_id)).fetchone()
            if device is None or device["mls_key"] != statement["key"]:
                raise HTTPException(409, "statement_device_key_mismatch")
            if "linkSigningKey" in statement and (device["link_key"] != statement["linkSigningKey"] or device["endpoint_key"] != statement["transportEndpointKey"]):
                raise HTTPException(409, "statement_device_key_mismatch")
            if statement["action"] == "enroll" and device["revoked"]:
                raise HTTPException(409, "device_revoked")
            head = connection.execute("SELECT * FROM kt_accounts WHERE account_id=?", (principal.account_id,)).fetchone()
            revision, previous_hash = (0, bytes(32)) if head is None else (head["revision"], bytes.fromhex(head["head_hash"]))
            if statement["revision"] != revision + 1 or base64_bytes(statement["previous"], 32) != previous_hash:
                raise HTTPException(409, "statement_chain_conflict")
            previous_entry = connection.execute("SELECT statement FROM kt_leaves WHERE account_id=? ORDER BY revision DESC LIMIT 1",
                                                (principal.account_id,)).fetchone()
            previous_time = 0 if previous_entry is None else json.loads(previous_entry[0])["time"]
            if statement["time"] < previous_time or statement["time"] > now_ms() + 300_000:
                raise HTTPException(422, "invalid_statement_time")
            index = connection.execute("SELECT COALESCE(MAX(leaf_index),-1)+1 FROM kt_leaves").fetchone()[0]
            if revision >= 100_000 or index >= 1_000_000:
                raise HTTPException(507, "key_log_capacity")
            connection.execute("INSERT INTO kt_leaves VALUES(?,?,?,?,?,?,?,?)", (index, principal.account_id,
                statement["revision"], canonical(statement).decode(), body["signature"], encoded, hashed.hex(), now_ms()))
            connection.execute("INSERT INTO kt_nodes VALUES(?,?,?)", (index, 1, hashed))
            start, size, current = index, 1, hashed
            while start % (size * 2) == size:
                left = tree_root(connection, start - size, size)
                start -= size
                size *= 2
                current = node_hash(left, current)
                connection.execute("INSERT INTO kt_nodes VALUES(?,?,?)", (start, size, current))
            connection.execute("INSERT INTO kt_accounts VALUES(?,?,?) ON CONFLICT(account_id) DO UPDATE SET revision=excluded.revision,head_hash=excluded.head_hash",
                               (principal.account_id, statement["revision"], hashed.hex()))
            connection.execute("UPDATE devices SET statement_hash=? WHERE device_id=?", (hashed.hex(), statement["device"]))
            if statement["action"] == "revoke":
                connection.execute("UPDATE devices SET revoked=1,revision=revision+1,updated_at=? WHERE device_id=?", (now_ms(), statement["device"]))
            checkpoint(connection, index + 1)
            return {"leafIndex": index, "hash": base64.b64encode(hashed).decode()}

        return await store.transaction(save)

    @router.get("/v1/kt/checkpoint")
    async def get_checkpoint(request: Request):
        await require_registered(store, await authenticate(request))
        def load(connection):
            size = connection.execute("SELECT COUNT(*) FROM kt_leaves").fetchone()[0]
            return {**checkpoint(connection, size, refresh=True), "publicKey": base64.b64encode(public_key).decode(),
                    "independentWitnesses": False}
        return await store.transaction(load)

    @router.get("/v1/kt/consistency")
    async def get_consistency(request: Request):
        await require_registered(store, await authenticate(request))
        try:
            old, new = int(request.query_params["from"]), int(request.query_params["to"])
        except (KeyError, ValueError):
            raise HTTPException(422, "invalid_tree_size") from None
        def load(connection):
            size = connection.execute("SELECT COUNT(*) FROM kt_leaves").fetchone()[0]
            if not 0 <= old <= new <= size:
                raise HTTPException(422, "invalid_tree_size")
            proof = [] if old == 0 or old == new else consistency(connection, old, 0, new)
            return {"from": old, "to": new, "proof": [base64.b64encode(x).decode() for x in proof]}
        return await store.read(load)

    @router.get("/v1/kt/accounts/{account}/statements")
    async def get_statements(account: str, request: Request):
        await require_registered(store, await authenticate(request))
        identifier(account)
        try:
            after = int(request.query_params.get("afterRevision", "0"))
            requested = request.query_params.get("atSize")
            target = None if requested is None else int(requested)
        except ValueError:
            raise HTTPException(422, "invalid_statement_cursor") from None
        def load(connection):
            size = connection.execute("SELECT COUNT(*) FROM kt_leaves").fetchone()[0]
            at = size if target is None else target
            if after < 0 or after > 9_007_199_254_740_991 or not 0 <= at <= size:
                raise HTTPException(422, "invalid_statement_cursor")
            rows = connection.execute("SELECT * FROM kt_leaves WHERE account_id=? AND revision>? AND leaf_index<? ORDER BY revision LIMIT 257",
                                      (account, after, at)).fetchall()
            items = [{"statement": json.loads(row["statement"]), "signature": row["signature"],
                      "leafIndex": row["leaf_index"], "inclusionProof": [base64.b64encode(x).decode()
                      for x in inclusion(connection, row["leaf_index"], 0, at)]} for row in rows[:256]]
            return {"atSize": at, "statements": items,
                    "nextRevision": rows[255]["revision"] if len(rows) > 256 else None}
        return await store.read(load)

    return router
