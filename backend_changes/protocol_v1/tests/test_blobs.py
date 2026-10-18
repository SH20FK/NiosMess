from __future__ import annotations

import base64
import hashlib
import json
import asyncio
import os
from pathlib import Path
import socket
import subprocess
import sys
from contextlib import suppress

import pytest
import httpx
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from fastapi import HTTPException

from nios_protocol.auth import canonical
from nios_protocol.blobs import StreamBlobs
from nios_protocol.store import ProtocolStore
from test_devices import Harness, b64


def encrypted_file(*, seed=1, length=517, segment_size=128):
    plain = bytes((i * 7 + seed) % 256 for i in range(length))
    key = bytes((i + seed) % 256 for i in range(32))
    object_id = f"{seed:032x}"
    nonce = bytes([seed % 256]) * 8
    segments = []
    for index, offset in enumerate(range(0, length, segment_size)):
        value = plain[offset:offset + segment_size]
        aad = canonical(["NiosStream", 1, "A256GCM", object_id, length, segment_size, index, len(value)])
        segments.append(AESGCM(key).encrypt(nonce + index.to_bytes(4, "big"), value, aad))
    manifest = {"version": 1, "algorithm": "A256GCM", "objectId": object_id,
                "plaintextLength": length, "segmentSize": segment_size, "noncePrefix": b64(nonce),
                "segmentHashes": [hashlib.sha256(value).hexdigest() for value in segments]}
    encoded = canonical(manifest)
    return plain, key, manifest, hashlib.sha256(encoded).hexdigest(), b"".join(segments)


async def setup(tmp_path, **limits):
    harness = Harness(tmp_path)
    await harness.enroll("alice-phone")
    await harness.enroll("bob-phone", token="bob")
    allowed = {("account-alice", 77), ("account-bob", 77)}

    async def authorize(principal, chat_id):
        return (principal.account_id, chat_id) in allowed

    async def resolve(principal, chat_id, requested):
        if not await authorize(principal, chat_id) or principal.account_id != "account-alice":
            raise HTTPException(403, "chat_forbidden")
        if requested is not None and requested != ["bob-phone"]:
            raise HTTPException(403, "invalid_recipient")
        return ["bob-phone"]

    blobs = StreamBlobs(harness.store, harness.authenticate, resolve, authorize, **limits)
    harness.app.include_router(blobs.router)
    return harness, blobs, allowed


async def publish(harness, manifest, digest, ciphertext):
    response = await harness.request("PUT", f"/v1/manifests/{digest}", content=canonical(manifest))
    assert response.status_code in (200, 201), response.text
    response = await harness.request("PUT", f"/v1/blobs/{digest}", content=ciphertext)
    assert response.status_code in (200, 201), response.text
    assert response.headers["x-nios-manifest-hash"] == digest
    assert response.headers["x-nios-ciphertext-length"] == str(len(ciphertext))
    return response


@pytest.mark.asyncio
async def test_immutable_authenticated_range_and_exact_chat_grants(tmp_path):
    harness, blobs, allowed = await setup(tmp_path)
    try:
        plain, key, manifest, digest, ciphertext = encrypted_file()
        await publish(harness, manifest, digest, ciphertext)
        assert (await harness.request("HEAD", f"/v1/blobs/{digest}", token="bob")).status_code == 404
        assert (await harness.request("POST", f"/v1/blobs/{digest}/grants", json={"chat_id": 999})).status_code == 403
        assert (await harness.request("POST", f"/v1/blobs/{digest}/grants", json={"chat_id": 77, "recipient_device_ids": ["alice-phone"]})).status_code == 403
        response = await harness.request("POST", f"/v1/blobs/{digest}/grants", json={"chat_id": 77})
        assert response.status_code == 200 and response.json() == {"granted": 1}
        # Query through raw client to set Range while keeping the injected auth.
        response = await harness.client.get(f"/v1/blobs/{digest}", headers={"Authorization": "Bearer bob", "Range": "bytes=0-143"})
        assert response.status_code == 206 and response.content == ciphertext[:144]
        assert response.headers["content-range"] == f"bytes 0-143/{len(ciphertext)}"
        assert response.headers["content-encoding"] == "identity"
        assert response.headers["content-length"] == "144"
        aad = canonical(["NiosStream", 1, "A256GCM", manifest["objectId"], len(plain), 128, 0, 128])
        assert AESGCM(key).decrypt(base64.b64decode(manifest["noncePrefix"]) + bytes(4), response.content, aad) == plain[:128]
        for invalid in (None, "bytes=0-", "bytes=-32", "bytes=0-2,4-6", "bytes=1-99999", "bytes=5-4"):
            headers = {"Authorization": "Bearer bob"}
            if invalid is not None:
                headers["Range"] = invalid
            assert (await harness.client.get(f"/v1/blobs/{digest}", headers=headers)).status_code == 416
        assert (await harness.request("GET", f"/v1/manifests/{digest}", token="bob")).content == canonical(manifest)
        allowed.remove(("account-bob", 77))
        assert (await harness.request("HEAD", f"/v1/blobs/{digest}", token="bob")).status_code == 404
        assert blobs.path(digest).read_bytes() == ciphertext
        assert plain not in blobs.path(digest).read_bytes()
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_truncated_corrupted_and_interrupted_uploads_preserve_retry_and_reservation(tmp_path):
    harness, blobs, _ = await setup(tmp_path)
    try:
        _, _, manifest, digest, ciphertext = encrypted_file()
        assert (await harness.request("PUT", f"/v1/manifests/{digest}", content=canonical(manifest))).status_code == 201
        response = await harness.client.put(f"/v1/blobs/{digest}", headers={"Authorization": "Bearer alice", "Content-Length": str(len(ciphertext))}, content=ciphertext[:100])
        assert response.status_code == 422
        assert not blobs.path(digest).exists() and not list(blobs.directory.glob("*.partial"))
        corrupt = bytearray(ciphertext)
        corrupt[0] ^= 1
        assert (await harness.request("PUT", f"/v1/blobs/{digest}", content=bytes(corrupt))).status_code == 422
        assert (await harness.request("HEAD", f"/v1/blobs/{digest}")).status_code == 404

        async def disconnect():
            yield ciphertext[:50]
            raise OSError("simulated_client_disconnect")
        with pytest.raises(Exception):
            await harness.client.put(f"/v1/blobs/{digest}", headers={"Authorization": "Bearer alice", "Content-Length": str(len(ciphertext))}, content=disconnect())
        assert not list(blobs.directory.glob("*.partial"))
        await publish(harness, manifest, digest, ciphertext)
        assert (await harness.request("PUT", f"/v1/blobs/{digest}", content=bytes(corrupt))).status_code == 422
        assert blobs.path(digest).read_bytes() == ciphertext
        assert await harness.store.read(lambda connection: connection.execute("SELECT COUNT(*) FROM stream_manifests").fetchone()[0]) == 1
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_publication_after_rename_before_commit_recovers_without_false_receipt(tmp_path):
    harness, blobs, _ = await setup(tmp_path)
    try:
        _, _, manifest, digest, ciphertext = encrypted_file()
        await harness.request("PUT", f"/v1/manifests/{digest}", content=canonical(manifest))
        await harness.store.ensure_schema("CREATE TRIGGER fail_publication BEFORE UPDATE OF ready ON stream_manifests BEGIN SELECT RAISE(ABORT,'simulated_commit_failure'); END;")
        with pytest.raises(Exception):
            await harness.request("PUT", f"/v1/blobs/{digest}", content=ciphertext)
        assert blobs.path(digest).read_bytes() == ciphertext
        assert (await harness.request("HEAD", f"/v1/blobs/{digest}")).status_code == 404
        await harness.store.ensure_schema("DROP TRIGGER fail_publication;")
        await harness.client.aclose()
        harness.store = ProtocolStore(tmp_path / "protocol.sqlite3", tmp_path / "data")
        harness._open_app()
        async def resolve(*_):
            return ["bob-phone"]
        async def allow(*_):
            return True
        restarted = StreamBlobs(harness.store, harness.authenticate, resolve, allow)
        harness.app.include_router(restarted.router)
        await publish(harness, manifest, digest, ciphertext)
        assert (await harness.request("HEAD", f"/v1/blobs/{digest}")).status_code == 200
        assert not list(restarted.directory.glob("*.partial"))
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_quota_counted_once_unknown_manifest_and_revocation_blocks_access(tmp_path):
    harness, blobs, _ = await setup(tmp_path, maximum_user_bytes=700, maximum_total_bytes=1400)
    try:
        _, _, manifest, digest, ciphertext = encrypted_file(length=500)
        assert (await harness.request("PUT", f"/v1/blobs/{digest}", content=ciphertext)).status_code == 404
        await publish(harness, manifest, digest, ciphertext)
        await publish(harness, manifest, digest, ciphertext)
        _, _, second, second_hash, _ = encrypted_file(seed=2, length=500)
        assert (await harness.request("PUT", f"/v1/manifests/{second_hash}", content=canonical(second))).status_code == 507
        assert (await harness.request("PUT", f"/v1/manifests/{digest}", token="bob", content=canonical(manifest))).status_code == 409
        assert (await harness.request("PUT", f"/v1/manifests/{'0' * 64}", content=canonical(manifest))).status_code == 422
        await harness.request("POST", f"/v1/blobs/{digest}/grants", json={"chat_id": 77})
        await harness.store.transaction(lambda connection: connection.execute("UPDATE devices SET revoked=1 WHERE device_id='bob-phone'").rowcount)
        assert (await harness.request("HEAD", f"/v1/blobs/{digest}", token="bob")).status_code == 403
        assert (await harness.request("POST", f"/v1/blobs/{digest}/grants", json={"chat_id": 77})).status_code == 409
    finally:
        await harness.close()


@pytest.mark.asyncio
async def test_empty_file_and_single_byte_ranges_are_well_defined(tmp_path):
    harness, _, _ = await setup(tmp_path)
    try:
        _, _, manifest, digest, ciphertext = encrypted_file(length=0)
        await publish(harness, manifest, digest, ciphertext)
        head = await harness.request("HEAD", f"/v1/blobs/{digest}")
        assert head.status_code == 200 and head.headers["content-length"] == "0"
        response = await harness.client.get(f"/v1/blobs/{digest}", headers={"Authorization": "Bearer alice", "Range": "bytes=0-0"})
        assert response.status_code == 416
        _, _, manifest, digest, ciphertext = encrypted_file(seed=2, length=1)
        await publish(harness, manifest, digest, ciphertext)
        response = await harness.client.get(f"/v1/blobs/{digest}", headers={"Authorization": "Bearer alice", "Range": "bytes=16-16"})
        assert response.status_code == 206 and response.content == ciphertext[16:]
    finally:
        await harness.close()


_UPLOAD_PROCESS = r'''
import sys
from pathlib import Path
import uvicorn
from fastapi import HTTPException
from nios_protocol.app import create_app
from nios_protocol.auth import Principal
from nios_protocol.store import ProtocolStore
from nios_protocol.blobs import StreamBlobs
root=Path(sys.argv[1])
async def auth(request):
    if request.headers.get('authorization')!='Bearer alice':
        raise HTTPException(401,'unauthorized')
    return Principal('account-alice',1,101)
async def grants(*args):
    return ['bob-phone']
async def allow(*args):
    return True
store=ProtocolStore(root/'protocol.sqlite3',root/'data')
app=create_app(store,auth)
blobs=StreamBlobs(store,auth,grants,allow)
app.include_router(blobs.router)
uvicorn.run(app,host='127.0.0.1',port=int(sys.argv[2]),log_level='critical',access_log=False)
'''


@pytest.mark.asyncio
async def test_real_process_kill_releases_upload_lease_and_restart_cleans_only_orphans(tmp_path):
    harness, blobs, _ = await setup(tmp_path)
    process, upload_task = None, None
    try:
        _, _, manifest, digest, ciphertext = encrypted_file(length=300_000, segment_size=65_536)
        await harness.request("PUT", f"/v1/manifests/{digest}", content=canonical(manifest))
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]
        environment = dict(os.environ)
        environment["PYTHONPATH"] = str(Path(__file__).resolve().parents[1])
        process = subprocess.Popen([sys.executable, "-c", _UPLOAD_PROCESS, str(tmp_path), str(port)],
            env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        async with httpx.AsyncClient(base_url=f"http://127.0.0.1:{port}", timeout=5) as client:
            for _ in range(200):
                assert process.poll() is None, "isolated_upload_service_failed"
                try:
                    response = await client.get("/v1/protocols", headers={"Authorization": "Bearer alice"})
                    if response.status_code == 200:
                        break
                except httpx.TransportError:
                    pass
                await asyncio.sleep(0.025)
            else:
                pytest.fail("isolated_upload_service_not_ready")
            never = asyncio.Event()
            async def partial_upload():
                yield ciphertext[:32_768]
                await never.wait()
            upload_task = asyncio.create_task(client.put(f"/v1/blobs/{digest}",
                headers={"Authorization": "Bearer alice", "Content-Length": str(len(ciphertext))},
                content=partial_upload()))
            for _ in range(200):
                active = list(blobs.directory.glob("*.partial"))
                if active and active[0].stat().st_size:
                    break
                await asyncio.sleep(0.025)
            else:
                pytest.fail("upload_never_reached_durable_staging")
            # A second worker must preserve another process's live ciphertext.
            verifier = StreamBlobs(harness.store, harness.authenticate, blobs.resolve_grants, blobs.authorize_chat)
            await verifier.initialize()
            assert active[0].exists()
            process.kill()
            await asyncio.to_thread(process.wait, 10)
            upload_task.cancel()
            with suppress(asyncio.CancelledError, Exception):
                await upload_task
            upload_task = None
            assert active[0].exists()  # SIGKILL/TerminateProcess bypassed finally.
            restarted = StreamBlobs(harness.store, harness.authenticate, blobs.resolve_grants, blobs.authorize_chat)
            await restarted.initialize()
            assert not list(blobs.directory.glob("*.partial"))
            assert (await harness.request("HEAD", f"/v1/blobs/{digest}")).status_code == 404
            await publish(harness, manifest, digest, ciphertext)
            assert blobs.path(digest).read_bytes() == ciphertext
    finally:
        if upload_task is not None:
            upload_task.cancel()
            with suppress(asyncio.CancelledError, Exception):
                await upload_task
        if process is not None and process.poll() is None:
            process.kill()
            await asyncio.to_thread(process.wait, 10)
        await harness.close()
