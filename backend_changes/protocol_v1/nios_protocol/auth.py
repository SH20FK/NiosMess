"""Authentication is supplied by the host's existing central-session verifier."""

from __future__ import annotations

import asyncio
import base64
from dataclasses import dataclass, replace
import json
from typing import Awaitable, Callable

from fastapi import HTTPException, Request

from .store import ProtocolStore


@dataclass(frozen=True)
class Principal:
    account_id: str
    user_id: int
    session_id: int
    device_id: str | None = None
    legacy_public_key: str | None = None
    session_fingerprint: str | None = None


Authenticator = Callable[[Request], Awaitable[Principal]]


def canonical(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8")


def base64_bytes(value: object, size: int | None = None, *, maximum: int = 4_194_304) -> bytes:
    if not isinstance(value, str) or len(value) > (maximum * 4 // 3 + 8):
        raise HTTPException(422, "invalid_base64")
    try:
        result = base64.b64decode(value, validate=True)
    except (ValueError, TypeError):
        raise HTTPException(422, "invalid_base64") from None
    if (size is not None and len(result) != size) or len(result) > maximum:
        raise HTTPException(422, "invalid_base64_size")
    if base64.b64encode(result).decode() != value:
        raise HTTPException(422, "noncanonical_base64")
    return result


def _unique_object(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate_json_key")
        result[key] = value
    return result


async def json_body(request: Request, *, limit: int = 1_500_000, timeout: float = 15) -> dict:
    declared = request.headers.get("content-length")
    if declared is not None:
        try:
            length = int(declared)
        except ValueError:
            raise HTTPException(400, "invalid_length") from None
        if length < 0 or length > limit:
            raise HTTPException(413, "body_too_large")

    async def read() -> bytes:
        result = bytearray()
        async for chunk in request.stream():
            if len(result) + len(chunk) > limit:
                raise HTTPException(413, "body_too_large")
            result.extend(chunk)
        return bytes(result)

    try:
        encoded = await asyncio.wait_for(read(), timeout)
        value = json.loads(encoded.decode("utf-8"), object_pairs_hook=_unique_object,
                           parse_constant=lambda _: (_ for _ in ()).throw(ValueError("nonfinite_json")))
    except asyncio.TimeoutError:
        raise HTTPException(408, "body_timeout") from None
    except (ValueError, UnicodeError):
        raise HTTPException(400, "invalid_json") from None
    if not isinstance(value, dict):
        raise HTTPException(422, "json_object_required")
    return value


async def require_registered(store: ProtocolStore, principal: Principal) -> Principal:
    row = await store.read(lambda connection: connection.execute(
        "SELECT device_id, account_id, user_id, revoked, legacy_key, session_fingerprint FROM devices WHERE session_id=?",
        (principal.session_id,),
    ).fetchone())
    if (row is None or row["revoked"] or row["account_id"] != principal.account_id
            or row["user_id"] != principal.user_id
            or row["session_fingerprint"] != principal.session_fingerprint
            or (row["legacy_key"] is not None and row["legacy_key"] != principal.legacy_public_key)
            or (principal.device_id is not None and principal.device_id != row["device_id"])):
        raise HTTPException(403, "registered_device_required")
    return replace(principal, device_id=row["device_id"])


def registered_in_transaction(connection, principal: Principal):
    """Recheck bindings in the mutation transaction to fence concurrent revokes."""
    row = connection.execute("SELECT * FROM devices WHERE device_id=? AND session_id=?",
                             (principal.device_id, principal.session_id)).fetchone()
    if (row is None or row["revoked"] or row["account_id"] != principal.account_id
            or row["user_id"] != principal.user_id
            or row["session_fingerprint"] != principal.session_fingerprint
            or (row["legacy_key"] is not None and row["legacy_key"] != principal.legacy_public_key)):
        raise HTTPException(403, "registered_device_required")
    return row
