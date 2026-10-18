from __future__ import annotations

import base64
import time

import pytest
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

from nios_protocol.devices import enrollment_bytes, registration_bytes
from nios_protocol.iroh import address_bytes, create_iroh_router
from nios_protocol.store import ProtocolStore
from test_devices import Harness, b64, public


async def setup(tmp_path):
    harness = Harness(tmp_path)
    await harness.enroll("alice-phone")
    endpoint = Ed25519PrivateKey.generate()
    registration = await harness.enrollment("bob-phone", token="bob", native=True,
                                           capability={"link": [1], "irohAlpn": ["nios.link/1"]})
    registration["endpoint_key"] = public(endpoint)
    signing = registration_bytes("account-bob", "bob-phone", registration, registration["protocols"])
    registration["identity_signature"] = b64(harness.identities["account-bob"].sign(signing))
    registration["device_proof"] = b64(harness.links["bob-phone"].sign(enrollment_bytes(harness.principals["bob"], "bob-phone", registration["challenge"], signing)))
    assert (await harness.request("PUT", "/v1/devices/bob-phone", token="bob", json=registration)).status_code == 200
    permitted = {("account-alice", 77, "bob-phone")}
    async def authorize(principal, chat, device):
        return (principal.account_id, chat, device) in permitted
    harness.app.include_router(create_iroh_router(harness.store, harness.authenticate, authorize))
    return harness, endpoint, permitted, authorize


def body(harness, endpoint, *, revision=1):
    # The server intentionally does not interpret opaque native Postcard bytes.
    value = {"v": 1, "endpoint_key": public(endpoint), "address": b64(b"opaque-native-postcard"),
             "revision": revision, "expires": time.time_ns() // 1_000_000 + 120_000}
    signing = address_bytes("account-bob", "bob-phone", value)
    return {**value, "signature": b64(endpoint.sign(signing)),
            "device_signature": b64(harness.links["bob-phone"].sign(signing))}


@pytest.mark.asyncio
async def test_address_double_signature_acl_revision_and_restart(tmp_path):
    harness, endpoint, _, authorize = await setup(tmp_path)
    try:
        first = body(harness, endpoint)
        response = await harness.request("PUT", "/v1/iroh/address", token="bob", json=first)
        assert response.status_code == 200 and response.json() == {"stored": True, "revision": 1}
        assert (await harness.request("PUT", "/v1/iroh/address", token="bob", json=first)).json() == response.json()
        obtained = await harness.request("GET", "/v1/iroh/devices/bob-phone/address?chat_id=77")
        assert obtained.status_code == 200 and obtained.json() == {"account": "account-bob", "device": "bob-phone", **first}
        endpoint.public_key().verify(base64.b64decode(first["signature"]), address_bytes("account-bob", "bob-phone", first))
        assert (await harness.request("GET", "/v1/iroh/devices/bob-phone/address?chat_id=88")).status_code == 404
        assert (await harness.request("PUT", "/v1/iroh/address", token="bob", json=body(harness, endpoint))).status_code == 409
        second = body(harness, endpoint, revision=2)
        assert (await harness.request("PUT", "/v1/iroh/address", token="bob", json=second)).status_code == 200
        await harness.client.aclose()
        harness.store = ProtocolStore(tmp_path / "protocol.sqlite3", tmp_path / "data")
        harness._open_app()
        harness.app.include_router(create_iroh_router(harness.store, harness.authenticate, authorize))
        assert (await harness.request("GET", "/v1/iroh/devices/bob-phone/address?chat_id=77")).json()["revision"] == 2
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_forged_or_expired_address_and_revoked_device_are_unavailable(tmp_path):
    harness, endpoint, _, _ = await setup(tmp_path)
    try:
        valid = body(harness, endpoint)
        for field in ("signature", "device_signature"):
            assert (await harness.request("PUT", "/v1/iroh/address", token="bob", json={**valid, field: b64(bytes(64))})).status_code == 403
        assert (await harness.request("PUT", "/v1/iroh/address", token="bob", json={**valid, "expires": 0})).status_code == 422
        assert (await harness.request("PUT", "/v1/iroh/address", token="alice", json=valid)).status_code == 403
        await harness.request("PUT", "/v1/iroh/address", token="bob", json=valid)
        await harness.store.transaction(lambda connection: connection.execute("UPDATE iroh_addresses SET expires_at=0").rowcount)
        assert (await harness.request("GET", "/v1/iroh/devices/bob-phone/address?chat_id=77")).status_code == 404
        await harness.store.transaction(lambda connection: connection.execute("UPDATE devices SET revoked=1 WHERE device_id='bob-phone'").rowcount)
        assert (await harness.request("PUT", "/v1/iroh/address", token="bob", json=body(harness, endpoint, revision=2))).status_code == 403
    finally:
        await harness.close()
