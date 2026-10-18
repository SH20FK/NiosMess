"""Session-bound enrollment. A known account/device key is never silently replaced."""

from __future__ import annotations

import base64
import hashlib
import json
import re
import secrets
import time

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from fastapi import APIRouter, HTTPException, Request

from .auth import Authenticator, Principal, base64_bytes, canonical, json_body, require_registered
from .store import ProtocolStore

ID = re.compile(r"^[A-Za-z0-9._:@/-]{1,160}$")
HASH = re.compile(r"^[a-f0-9]{64}$")


def now_ms() -> int:
    return time.time_ns() // 1_000_000


def identifier(value: object) -> str:
    if not isinstance(value, str) or not ID.fullmatch(value):
        raise HTTPException(422, "invalid_identifier")
    return value


def protocols(value: object) -> dict:
    if not isinstance(value, dict) or set(value) - {"link", "stream", "mls", "irohAlpn", "ktStatements"}:
        raise HTTPException(422, "invalid_protocols")
    normalized = {}
    for key, supported in (("link", [1]), ("stream", [1])):
        items = value.get(key, [])
        if not isinstance(items, list) or len(items) > 4 or any(type(x) is not int or x not in supported for x in items):
            raise HTTPException(422, "unsupported_protocol")
        normalized[key] = sorted(set(items))
    mls = value.get("mls", {})
    if not isinstance(mls, dict) or set(mls) - {"versions", "suites"}:
        raise HTTPException(422, "invalid_mls_protocols")
    for key, allowed in (("versions", ["1.0"]), ("suites", ["0x0001"])):
        values = mls.get(key, [])
        if not isinstance(values, list) or len(values) > 4 or any(x not in allowed for x in values):
            raise HTTPException(422, "unsupported_mls_protocol")
    normalized["mls"] = {"versions": sorted(set(mls.get("versions", []))),
                         "suites": sorted(set(mls.get("suites", [])))}
    for key, allowed in (("irohAlpn", ["nios.link/1"]), ("ktStatements", [1, 2])):
        items = value.get(key, [])
        if (not isinstance(items, list) or len(items) > 4
                or any(x not in allowed or (key == "ktStatements" and type(x) is not int) for x in items)):
            raise HTTPException(422, "unsupported_protocol")
        normalized[key] = sorted(set(items))
    return normalized


def registration_bytes(account: str, device: str, body: dict, capability: dict) -> bytes:
    return canonical(["nios-device-registration", 1, account, device,
                      body["identity_key"], body["link_key"], body.get("mls_key"),
                      body.get("endpoint_key"), body.get("legacy_key"),
                      hashlib.sha256(canonical(capability)).hexdigest()])


def enrollment_bytes(principal: Principal, device: str, challenge: str, registration: bytes) -> bytes:
    return canonical(["nios-device-enrollment", 1, principal.account_id, device,
                      principal.session_id, challenge, hashlib.sha256(registration).hexdigest()])


def verify_signature(key: bytes, signature: object, message: bytes) -> None:
    try:
        Ed25519PublicKey.from_public_bytes(key).verify(base64_bytes(signature, 64), message)
    except InvalidSignature:
        raise HTTPException(403, "invalid_device_signature") from None


def _public_device(row) -> dict:
    return {"account": row["account_id"], "device": row["device_id"],
            "identity_key": row["identity_key"], "link_key": row["link_key"],
            "mls_key": row["mls_key"], "endpoint_key": row["endpoint_key"],
            "protocols": json.loads(row["capabilities"]),
            "revision": row["revision"], "revoked": bool(row["revoked"])}


def create_devices_router(store: ProtocolStore, authenticate: Authenticator) -> APIRouter:
    router = APIRouter()

    @router.post("/v1/devices/{device}/challenge")
    async def challenge(device: str, request: Request):
        principal = await authenticate(request)
        identifier(principal.account_id)
        identifier(device)
        await json_body(request, limit=1024)
        nonce, now = secrets.token_hex(32), now_ms()

        def save(connection):
            connection.execute("DELETE FROM enrollment_challenges WHERE expires_at<?", (now,))
            count = connection.execute("SELECT COUNT(*) FROM enrollment_challenges WHERE session_id=? AND consumed=0",
                                       (principal.session_id,)).fetchone()[0]
            if count >= 20:
                raise HTTPException(429, "challenge_limit")
            connection.execute("""INSERT INTO enrollment_challenges(challenge,account_id,session_id,session_fingerprint,device_id,expires_at,consumed)
                               VALUES(?,?,?,?,?,?,0)""",
                               (nonce, principal.account_id, principal.session_id, principal.session_fingerprint, device, now + 300_000))

        await store.transaction(save)
        return {"challenge": nonce, "account": principal.account_id, "device": device,
                "session": principal.session_id, "expires": now + 300_000}

    @router.put("/v1/devices/{device}")
    async def enroll(device: str, request: Request):
        principal = await authenticate(request)
        identifier(device)
        identifier(principal.account_id)
        body = await json_body(request, limit=16_384)
        if set(body) - {"challenge", "identity_key", "link_key", "mls_key", "endpoint_key", "protocols",
                        "legacy_key", "identity_signature", "device_proof"}:
            raise HTTPException(422, "invalid_enrollment_fields")
        nonce = body.get("challenge")
        if not isinstance(nonce, str) or not HASH.fullmatch(nonce):
            raise HTTPException(422, "invalid_challenge")
        identity = base64_bytes(body.get("identity_key"), 32)
        link = base64_bytes(body.get("link_key"), 32)
        for key in ("mls_key", "endpoint_key"):
            if body.get(key) is not None:
                base64_bytes(body[key], 32)
        legacy = body.get("legacy_key")
        if legacy is not None and (not isinstance(legacy, str) or len(legacy) > 4096):
            raise HTTPException(422, "invalid_legacy_key")
        if legacy != principal.legacy_public_key:
            raise HTTPException(403, "legacy_device_binding_mismatch")
        capability = protocols(body.get("protocols", {}))
        if (capability["mls"]["versions"] or capability["mls"]["suites"]) and body.get("mls_key") is None:
            raise HTTPException(422, "mls_key_required")
        if capability["irohAlpn"] and body.get("endpoint_key") is None:
            raise HTTPException(422, "endpoint_key_required")
        if capability["ktStatements"] and (body.get("mls_key") is None or body.get("endpoint_key") is None):
            raise HTTPException(422, "complete_key_bundle_required")
        registration = registration_bytes(principal.account_id, device, body, capability)
        verify_signature(identity, body.get("identity_signature"), registration)
        verify_signature(link, body.get("device_proof"), enrollment_bytes(principal, device, nonce, registration))
        now = now_ms()

        def save(connection):
            challenge_row = connection.execute("SELECT * FROM enrollment_challenges WHERE challenge=?", (nonce,)).fetchone()
            if (challenge_row is None or challenge_row["consumed"] or challenge_row["expires_at"] < now
                    or challenge_row["account_id"] != principal.account_id
                    or challenge_row["session_id"] != principal.session_id
                    or challenge_row["session_fingerprint"] != principal.session_fingerprint
                    or challenge_row["device_id"] != device):
                raise HTTPException(403, "challenge_expired_or_replayed")
            account = connection.execute("SELECT identity_key FROM identities WHERE account_id=?",
                                         (principal.account_id,)).fetchone()
            pinned = connection.execute("SELECT identity_key FROM kt_identity_pins WHERE account_id=?",
                                        (principal.account_id,)).fetchone()
            if capability["ktStatements"] and pinned is not None and pinned[0] != body["identity_key"]:
                raise HTTPException(409, "account_identity_changed")
            old = connection.execute("SELECT * FROM devices WHERE device_id=?", (device,)).fetchone()
            bound = connection.execute("SELECT * FROM devices WHERE session_id=?", (principal.session_id,)).fetchone()
            if bound is not None and bound["device_id"] != device:
                if (bound["session_fingerprint"] == principal.session_fingerprint
                        and bound["account_id"] == principal.account_id and bound["user_id"] == principal.user_id):
                    raise HTTPException(409, "session_already_bound")
                # The authoritative legacy database has reused a deleted integer
                # Session.id. A new token must not inherit the old device's ACL.
                connection.execute("UPDATE devices SET session_id=NULL,session_fingerprint=NULL,revoked=1,revision=revision+1,updated_at=? WHERE device_id=?",
                                   (now, bound["device_id"]))
            if old is not None:
                if old["account_id"] != principal.account_id or old["user_id"] != principal.user_id:
                    raise HTTPException(409, "device_owned_by_another_account")
                if old["revoked"]:
                    raise HTTPException(409, "device_revoked")
                for key in ("identity_key", "link_key", "mls_key", "endpoint_key"):
                    if old[key] is not None and old[key] != body.get(key):
                        raise HTTPException(409, "device_key_changed")
            elif connection.execute("SELECT COUNT(*) FROM devices WHERE account_id=? AND revoked=0",
                                    (principal.account_id,)).fetchone()[0] >= 100:
                raise HTTPException(429, "device_limit")
            if account is None:
                connection.execute("INSERT INTO identities VALUES(?,?,?)", (principal.account_id, body["identity_key"], now))
            # Stream-only installs have independent device identities. A shared
            # account identity is explicitly pinned only for full KT enrollment.
            if capability["ktStatements"] and pinned is None:
                connection.execute("INSERT INTO kt_identity_pins VALUES(?,?,?)", (principal.account_id, body["identity_key"], now))
            encoded = canonical(capability).decode()
            if (old is not None and old["session_id"] == principal.session_id
                    and old["session_fingerprint"] == principal.session_fingerprint
                    and old["legacy_key"] == legacy and old["capabilities"] == encoded
                    and old["mls_key"] == body.get("mls_key") and old["endpoint_key"] == body.get("endpoint_key")):
                # Re-registering an unchanged client after restart consumes the
                # fresh proof without inventing a key revision/audit event.
                connection.execute("UPDATE enrollment_challenges SET consumed=1 WHERE challenge=?", (nonce,))
                return _public_device(old)
            if old is None:
                connection.execute("""INSERT INTO devices(device_id,account_id,user_id,session_id,session_fingerprint,identity_key,
                    mls_key,link_key,endpoint_key,legacy_key,capabilities,created_at,updated_at)
                    VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)""", (device, principal.account_id, principal.user_id,
                    principal.session_id, principal.session_fingerprint, body["identity_key"], body.get("mls_key"), body["link_key"],
                    body.get("endpoint_key"), legacy, encoded, now, now))
            else:
                connection.execute("""UPDATE devices SET session_id=?,session_fingerprint=?,mls_key=?,endpoint_key=?,legacy_key=?,
                    capabilities=?,revision=revision+1,updated_at=? WHERE device_id=?""",
                    (principal.session_id, principal.session_fingerprint, body.get("mls_key"), body.get("endpoint_key"), legacy, encoded, now, device))
            connection.execute("UPDATE enrollment_challenges SET consumed=1 WHERE challenge=?", (nonce,))
            connection.execute("INSERT INTO device_history(account_id,device_id,action,registration,signature,created_at) VALUES(?,?,?,?,?,?)",
                (principal.account_id, device, "enroll" if old is None else "rebind",
                 registration.decode(), body["identity_signature"], now))
            return _public_device(connection.execute("SELECT * FROM devices WHERE device_id=?", (device,)).fetchone())

        return await store.transaction(save)

    @router.get("/v1/devices/{device}/protocols")
    async def device_protocols(device: str, request: Request):
        principal = await require_registered(store, await authenticate(request))
        row = await store.read(lambda connection: connection.execute("SELECT * FROM devices WHERE device_id=?", (device,)).fetchone())
        if row is None or row["account_id"] != principal.account_id:
            # Peer capabilities are supplied through the authorized chat sync.
            raise HTTPException(404, "device_not_found")
        return _public_device(row)

    @router.post("/v1/devices/{device}/revoke")
    async def revoke(device: str, request: Request):
        principal = await authenticate(request)
        identifier(device)
        body = await json_body(request, limit=4096)
        nonce = body.get("challenge")
        message = canonical(["nios-device-revocation", 1, principal.account_id, device, principal.session_id, nonce])
        now = now_ms()

        def save(connection):
            row = connection.execute("SELECT * FROM devices WHERE device_id=? AND account_id=?", (device, principal.account_id)).fetchone()
            if row is None:
                raise HTTPException(404, "device_not_found")
            challenge_row = connection.execute("SELECT * FROM enrollment_challenges WHERE challenge=?", (nonce,)).fetchone()
            if (challenge_row is None or challenge_row["consumed"] or challenge_row["expires_at"] < now
                    or challenge_row["account_id"] != principal.account_id
                    or challenge_row["session_id"] != principal.session_id
                    or challenge_row["session_fingerprint"] != principal.session_fingerprint
                    or challenge_row["device_id"] != device):
                raise HTTPException(403, "challenge_expired_or_replayed")
            verify_signature(base64_bytes(row["identity_key"], 32), body.get("signature"), message)
            connection.execute("UPDATE enrollment_challenges SET consumed=1 WHERE challenge=?", (nonce,))
            if not row["revoked"]:
                connection.execute("UPDATE devices SET revoked=1,revision=revision+1,updated_at=? WHERE device_id=?", (now, device))
                connection.execute("INSERT INTO device_history(account_id,device_id,action,registration,signature,created_at) VALUES(?,?,?,?,?,?)",
                    (principal.account_id, device, "revoke", message.decode(), body["signature"], now))
            return {"revoked": True, "device": device}

        return await store.transaction(save)

    return router
