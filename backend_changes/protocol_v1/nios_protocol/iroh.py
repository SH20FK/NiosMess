"""Signed endpoint-address rendezvous; this module is not an Iroh relay.

Postcard addresses remain bounded opaque bytes here. The native recipient must
decode them and compare EndpointAddr.id with its independently pinned identity.
The service never dials a supplied address or dereferences relay URLs.
"""

from __future__ import annotations

import hashlib
import json
from typing import Awaitable, Callable

from fastapi import APIRouter, HTTPException, Request

from .auth import (Authenticator, Principal, base64_bytes, canonical, json_body,
                   registered_in_transaction, require_registered)
from .devices import identifier, now_ms, verify_signature
from .store import ProtocolStore

AddressAuthorizer = Callable[[Principal, int, str], Awaitable[bool]]
SCHEMA = """
CREATE TABLE IF NOT EXISTS iroh_addresses (
 device_id TEXT PRIMARY KEY REFERENCES devices(device_id), revision INTEGER NOT NULL,
 address TEXT NOT NULL, digest TEXT NOT NULL, expires_at INTEGER NOT NULL
);
"""


def address_bytes(account: str, device: str, body: dict) -> bytes:
    return canonical(["nios-iroh-address", 1, account, device, body["endpoint_key"],
                      body["revision"], body["expires"], body["address"]])


def create_iroh_router(store: ProtocolStore, authenticate: Authenticator,
                       authorize_address: AddressAuthorizer) -> APIRouter:
    router = APIRouter()
    initialized = False

    async def principal(request):
        nonlocal initialized
        if not initialized:
            await store.ensure_schema(SCHEMA)
            initialized = True
        return await require_registered(store, await authenticate(request))

    @router.put("/v1/iroh/address")
    async def publish(request: Request):
        who = await principal(request)
        body = await json_body(request, limit=12_288)
        if set(body) != {"v", "endpoint_key", "address", "revision", "expires", "signature", "device_signature"} or type(body.get("v")) is not int or body["v"] != 1:
            raise HTTPException(422, "invalid_iroh_address")
        endpoint = base64_bytes(body["endpoint_key"], 32)
        encoded = base64_bytes(body["address"], maximum=4096)
        if not encoded or type(body["revision"]) is not int or not 1 <= body["revision"] <= 9_007_199_254_740_991:
            raise HTTPException(422, "invalid_iroh_address")
        if type(body["expires"]) is not int or not now_ms() < body["expires"] <= now_ms() + 300_000:
            raise HTTPException(422, "invalid_iroh_expiry")
        signing = address_bytes(who.account_id, who.device_id, body)
        verify_signature(endpoint, body["signature"], signing)
        digest = hashlib.sha256(canonical({name: body[name] for name in
            ("v", "endpoint_key", "address", "revision", "expires", "signature", "device_signature")})).hexdigest()

        def save(connection):
            device = registered_in_transaction(connection, who)
            if (device["endpoint_key"] != body["endpoint_key"]
                    or "nios.link/1" not in json.loads(device["capabilities"]).get("irohAlpn", [])):
                raise HTTPException(409, "iroh_device_not_enrolled")
            verify_signature(base64_bytes(device["link_key"], 32), body["device_signature"], signing)
            previous = connection.execute("SELECT revision,digest FROM iroh_addresses WHERE device_id=?", (who.device_id,)).fetchone()
            if previous is not None:
                if previous["digest"] == digest:
                    return {"stored": True, "revision": body["revision"]}
                if body["revision"] <= previous["revision"]:
                    raise HTTPException(409, "iroh_address_revision_conflict")
            complete = {"account": who.account_id, "device": who.device_id, **body}
            connection.execute("INSERT INTO iroh_addresses VALUES(?,?,?,?,?) ON CONFLICT(device_id) DO UPDATE SET revision=excluded.revision,address=excluded.address,digest=excluded.digest,expires_at=excluded.expires_at",
                               (who.device_id, body["revision"], canonical(complete).decode(), digest, body["expires"]))
            return {"stored": True, "revision": body["revision"]}

        return await store.transaction(save)

    @router.get("/v1/iroh/devices/{device}/address")
    async def lookup(device: str, request: Request):
        who = await principal(request)
        identifier(device)
        try:
            chat_id = int(request.query_params["chat_id"])
        except (KeyError, ValueError):
            raise HTTPException(422, "iroh_chat_required") from None
        if chat_id <= 0 or chat_id > 9_007_199_254_740_991 or set(request.query_params) != {"chat_id"}:
            raise HTTPException(422, "iroh_chat_required")
        if not await authorize_address(who, chat_id, device):
            raise HTTPException(404, "iroh_address_unavailable")

        def load(connection):
            registered_in_transaction(connection, who)
            row = connection.execute("SELECT a.address,a.expires_at,d.revoked,d.endpoint_key,d.capabilities FROM iroh_addresses a JOIN devices d ON d.device_id=a.device_id WHERE a.device_id=?", (device,)).fetchone()
            if row is None or row["revoked"] or row["expires_at"] <= now_ms():
                raise HTTPException(404, "iroh_address_unavailable")
            value = json.loads(row["address"])
            if (row["endpoint_key"] != value["endpoint_key"]
                    or "nios.link/1" not in json.loads(row["capabilities"]).get("irohAlpn", [])):
                raise HTTPException(404, "iroh_address_unavailable")
            return value

        return await store.read(load)

    return router
