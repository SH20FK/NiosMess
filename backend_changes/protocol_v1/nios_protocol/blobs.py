"""Authenticated immutable NiosStream ciphertext; no plaintext keys or names.

The manifest and quota reservation commit before receiving a file. Publication
is fsync -> atomic rename -> directory fsync -> SQLite FULL commit. A retry
after any interruption verifies the same bytes and never consumes another slot.
"""
from __future__ import annotations

import asyncio
import base64
from contextlib import asynccontextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import sqlite3
import time
from typing import Awaitable, Callable

from fastapi import APIRouter, HTTPException, Request, Response
from fastapi.responses import JSONResponse, StreamingResponse

from .auth import (Authenticator, Principal, canonical, json_body,
                   registered_in_transaction, require_registered)
from .store import ProtocolStore

HASH = re.compile(r"^[a-f0-9]{64}$")
SCHEMA = """
CREATE TABLE IF NOT EXISTS stream_manifests (
 hash TEXT PRIMARY KEY, owner_device TEXT NOT NULL, owner_user INTEGER NOT NULL,
 manifest BLOB NOT NULL, ciphertext_length INTEGER NOT NULL,
 ready INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL,
 FOREIGN KEY(owner_device) REFERENCES devices(device_id)
);
CREATE INDEX IF NOT EXISTS stream_owner ON stream_manifests(owner_user);
CREATE TABLE IF NOT EXISTS stream_grants (
 hash TEXT NOT NULL, device_id TEXT NOT NULL, chat_id INTEGER NOT NULL,
 PRIMARY KEY(hash, device_id, chat_id),
 FOREIGN KEY(hash) REFERENCES stream_manifests(hash),
 FOREIGN KEY(device_id) REFERENCES devices(device_id)
);
"""

GrantResolver = Callable[[Principal, int, list[str] | None], Awaitable[list[str]]]
ChatAuthorizer = Callable[[Principal, int], Awaitable[bool]]


def parse_manifest(value: dict, expected_hash: str, maximum: int) -> tuple[bytes, int]:
    fields = ("version", "algorithm", "objectId", "plaintextLength", "segmentSize",
              "noncePrefix", "segmentHashes")
    if (set(value) != set(fields) or type(value.get("version")) is not int
            or value["version"] != 1 or value.get("algorithm") != "A256GCM"
            or not isinstance(value.get("objectId"), str)
            or not re.fullmatch(r"[a-f0-9]{32}", value["objectId"])
            or type(value.get("plaintextLength")) is not int
            or not 0 <= value["plaintextLength"] <= (1 << 40)
            or type(value.get("segmentSize")) is not int
            or not 1 <= value["segmentSize"] <= 1_048_576
            or not isinstance(value.get("segmentHashes"), list)
            or not isinstance(value.get("noncePrefix"), str)):
        raise HTTPException(422, "invalid_stream_manifest")
    try:
        nonce = base64.b64decode(value["noncePrefix"], validate=True)
    except (ValueError, TypeError):
        raise HTTPException(422, "invalid_stream_nonce") from None
    if len(nonce) != 8 or base64.b64encode(nonce).decode() != value["noncePrefix"]:
        raise HTTPException(422, "invalid_stream_nonce")
    count = (value["plaintextLength"] + value["segmentSize"] - 1) // value["segmentSize"]
    hashes = value["segmentHashes"]
    if (count > 65_536 or len(hashes) != count
            or any(not isinstance(item, str) or not HASH.fullmatch(item) for item in hashes)):
        raise HTTPException(422, "invalid_stream_segments")
    length = value["plaintextLength"] + count * 16
    if length > maximum:
        raise HTTPException(413, "stream_file_limit")
    encoded = canonical({key: value[key] for key in fields})
    if hashlib.sha256(encoded).hexdigest() != expected_hash:
        raise HTTPException(422, "stream_manifest_hash_mismatch")
    return encoded, length


async def _finish_worker(task):
    """Drain a private worker even if the HTTP task is cancelled repeatedly.

    Cancelling asyncio.to_thread's Future does not stop its OS operation. Never
    let a second cancellation close a file while its worker is still using it.
    """
    while not task.done():
        try:
            await asyncio.shield(task)
        except asyncio.CancelledError:
            continue
    return task.result()


async def _io(callback, *args):
    task = asyncio.create_task(asyncio.to_thread(callback, *args))
    try:
        return await asyncio.shield(task)
    except asyncio.CancelledError as cancellation:
        try:
            await _finish_worker(task)
        finally:
            raise cancellation


async def _acquire_io(callback, cleanup, *args):
    """Return an acquired resource OR dispose it before propagating cancel.

    A cancelled await must not lose a newly acquired OS lease/descriptor/handle.
    Both acquisition and its cancellation cleanup are private shielded workers;
    repeated HTTP cancellation cannot cancel them or skip resource disposal.
    The caller assumes ownership only after this coroutine returns normally.
    """
    task = asyncio.create_task(asyncio.to_thread(callback, *args))
    try:
        return await asyncio.shield(task)
    except asyncio.CancelledError as cancellation:
        try:
            resource = await _finish_worker(task)
        except BaseException:
            # A failed acquisition did not transfer a resource. The callback
            # owns cleanup of a partial acquire (e.g. _file_lease's own try).
            raise cancellation
        cleanup_task = asyncio.create_task(asyncio.to_thread(cleanup, resource))
        await _finish_worker(cleanup_task)
        raise cancellation


def _sync_directory(directory: Path) -> None:
    if os.name == "nt":
        return  # Production is Linux; Windows is used for isolated tests only.
    descriptor = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


class StreamBlobs:
    def __init__(self, store: ProtocolStore, authenticate: Authenticator,
                 resolve_grants: GrantResolver, authorize_chat: ChatAuthorizer, *,
                 maximum_file_bytes: int = 256 * 1024 * 1024,
                 maximum_total_bytes: int = 1024 * 1024 * 1024,
                 maximum_user_bytes: int = 512 * 1024 * 1024,
                 request_timeout: float = 300):
        self.store, self.authenticate = store, authenticate
        self.resolve_grants, self.authorize_chat = resolve_grants, authorize_chat
        self.maximum_file_bytes = maximum_file_bytes
        self.maximum_total_bytes = maximum_total_bytes
        self.maximum_user_bytes = maximum_user_bytes
        self.request_timeout = request_timeout
        self.directory = store.data_root / "ciphertext"
        self._schema_ready = False
        self._schema_lock = asyncio.Lock()
        self._uploads = asyncio.Semaphore(2)
        self._locks = [asyncio.Lock() for _ in range(64)]
        self.router = self._routes()

    async def initialize(self):
        if self._schema_ready:
            return
        async with self._schema_lock:
            if not self._schema_ready:
                await self.store.ensure_schema(SCHEMA)
                await _io(self.directory.mkdir, 0o700, True, True)
                await _io(_reconcile_partials, self.directory)
                self._schema_ready = True

    def path(self, digest: str) -> Path:
        if not HASH.fullmatch(digest):
            raise HTTPException(404, "stream_unavailable")
        return self.directory / (digest + ".nsc")

    async def principal(self, request):
        await self.initialize()
        return await require_registered(self.store, await self.authenticate(request))

    async def accessible(self, principal: Principal, digest: str):
        def load(connection):
            registered_in_transaction(connection, principal)
            return (connection.execute("SELECT * FROM stream_manifests WHERE hash=? AND ready=1",
                                       (digest,)).fetchone(),
                    [item[0] for item in connection.execute(
                        "SELECT chat_id FROM stream_grants WHERE hash=? AND device_id=?",
                        (digest, principal.device_id))])
        row, chats = await self.store.read(load)
        if row is None:
            raise HTTPException(404, "stream_unavailable")
        if row["owner_device"] != principal.device_id:
            allowed = False
            for chat_id in chats:
                if await self.authorize_chat(principal, chat_id):
                    allowed = True
                    break
            if not allowed:
                raise HTTPException(404, "stream_unavailable")
        return row

    @staticmethod
    def receipt(row) -> dict[str, str]:
        return {"X-Nios-Manifest-Hash": row["hash"],
                "X-Nios-Ciphertext-Length": str(row["ciphertext_length"]),
                "Accept-Ranges": "bytes", "Cache-Control": "private, no-store",
                "X-Content-Type-Options": "nosniff", "Content-Encoding": "identity"}

    async def validate_message(self, principal: Principal, digest: str, chat_id: int,
                               targets: list[str]) -> int:
        """The legacy secret send path calls this before committing a reference."""
        await self.initialize()
        principal = await require_registered(self.store, principal)

        def validate(connection):
            registered_in_transaction(connection, principal)
            row = connection.execute("SELECT * FROM stream_manifests WHERE hash=? AND ready=1",
                                     (digest,)).fetchone()
            if row is None or row["owner_device"] != principal.device_id or not targets:
                raise HTTPException(409, "stream_upload_unavailable")
            for target in targets:
                grant = connection.execute(
                    "SELECT 1 FROM stream_grants g JOIN devices d ON d.device_id=g.device_id "
                    "WHERE g.hash=? AND g.chat_id=? AND g.device_id=? AND d.revoked=0",
                    (digest, chat_id, target)).fetchone()
                if grant is None:
                    raise HTTPException(409, "stream_recipient_not_ready")
            return row["ciphertext_length"]
        return await self.store.read(validate)

    async def _receive(self, request: Request, row, manifest: dict, path: Path):
        temporary = self.directory / (row["hash"] + "." + secrets.token_hex(16) + ".partial")
        handle = None
        descriptor = None
        try:
            descriptor = await _acquire_io(os.open, os.close, temporary,
                                           os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            handle = os.fdopen(descriptor, "wb", buffering=0)
            descriptor = None  # fdopen now owns it, including exceptional closes.
            count, segment, in_segment = 0, 0, 0
            digest = hashlib.sha256()
            hashes = manifest["segmentHashes"]
            async for chunk in request.stream():
                offset = 0
                while offset < len(chunk):
                    if segment >= len(hashes):
                        raise HTTPException(422, "stream_length_mismatch")
                    plain = min(manifest["segmentSize"],
                                manifest["plaintextLength"] - segment * manifest["segmentSize"])
                    length = plain + 16
                    take = min(len(chunk) - offset, length - in_segment, 65536)
                    piece = memoryview(chunk)[offset:offset + take]
                    digest.update(piece)
                    await _io(_write_all, handle, piece)
                    offset += take
                    in_segment += take
                    count += take
                    if in_segment == length:
                        if digest.hexdigest() != hashes[segment]:
                            raise HTTPException(422, "stream_segment_hash_mismatch")
                        segment += 1
                        in_segment = 0
                        digest = hashlib.sha256()
            if count != row["ciphertext_length"] or segment != len(hashes) or in_segment:
                raise HTTPException(422, "stream_length_mismatch")
            await _io(os.fsync, handle.fileno())
            await _io(handle.close)
            handle = None
            await _io(os.replace, temporary, path)
            await _io(_sync_directory, self.directory)
        finally:
            if handle is not None:
                await _io(handle.close)
            elif descriptor is not None:
                await _io(os.close, descriptor)
            await _io(temporary.unlink, True)

    def _routes(self) -> APIRouter:
        router = APIRouter()

        @router.put("/v1/manifests/{digest}")
        async def manifest_put(digest: str, request: Request):
            self.path(digest)
            principal = await self.principal(request)
            value = await json_body(request, limit=4_500_000)
            encoded, length = parse_manifest(value, digest, self.maximum_file_bytes)

            def reserve(connection):
                registered_in_transaction(connection, principal)
                old = connection.execute("SELECT * FROM stream_manifests WHERE hash=?", (digest,)).fetchone()
                if old is not None:
                    if old["owner_device"] != principal.device_id or bytes(old["manifest"]) != encoded:
                        raise HTTPException(409, "stream_manifest_conflict")
                    return False
                total, count = connection.execute(
                    "SELECT COALESCE(SUM(ciphertext_length),0), COUNT(*) FROM stream_manifests").fetchone()
                own, own_count = connection.execute(
                    "SELECT COALESCE(SUM(ciphertext_length),0),COUNT(*) FROM stream_manifests WHERE owner_user=?",
                    (principal.user_id,)).fetchone()
                if (total + length > self.maximum_total_bytes or own + length > self.maximum_user_bytes
                        or count >= 4096 or own_count >= 128):
                    raise HTTPException(507, "stream_storage_quota")
                connection.execute(
                    "INSERT INTO stream_manifests(hash,owner_device,owner_user,manifest,ciphertext_length,created_at) "
                    "VALUES(?,?,?,?,?,?)", (digest, principal.device_id, principal.user_id, encoded,
                                           length, int(time.time() * 1000)))
                return True
            created = await self.store.transaction(reserve)
            return Response(status_code=201 if created else 200,
                            headers={"Cache-Control": "no-store"})

        @router.put("/v1/blobs/{digest}")
        async def blob_put(digest: str, request: Request):
            path = self.path(digest)
            principal = await self.principal(request)
            row = await self.store.read(lambda connection: connection.execute(
                "SELECT * FROM stream_manifests WHERE hash=? AND owner_device=?",
                (digest, principal.device_id)).fetchone())
            if row is None:
                raise HTTPException(404, "stream_unavailable")
            try:
                declared = int(request.headers.get("content-length", "-1"))
            except ValueError:
                declared = -1
            if declared != row["ciphertext_length"]:
                raise HTTPException(422, "stream_length_mismatch")
            lock = self._locks[int(digest[:2], 16) % len(self._locks)]
            async with _bounded_lock(self._uploads), _bounded_lock(lock):
                lease = await _acquire_io(_file_lease, _release_lease, self.directory, digest)
                # Even retries validate all supplied bytes before returning an
                # immutable receipt. HEAD allows clients to skip this upload.
                try:
                    await _io(_clear_partials, self.directory, digest)
                    await asyncio.wait_for(self._receive(request, row, json.loads(row["manifest"]), path),
                                           self.request_timeout)
                except asyncio.TimeoutError:
                    raise HTTPException(408, "stream_upload_timeout") from None
                finally:
                    await _io(_release_lease, lease)

                def publish(connection):
                    registered_in_transaction(connection, principal)
                    previous = connection.execute("SELECT ready FROM stream_manifests WHERE hash=?", (digest,)).fetchone()
                    connection.execute("UPDATE stream_manifests SET ready=1 WHERE hash=?", (digest,))
                    return not previous[0]
                created = await self.store.transaction(publish)
            return Response(status_code=201 if created else 200, headers=self.receipt(row))

        @router.post("/v1/blobs/{digest}/grants")
        async def grant(digest: str, request: Request):
            self.path(digest)
            principal = await self.principal(request)
            body = await json_body(request, limit=16384)
            if set(body) - {"chat_id", "recipient_device_ids"} or type(body.get("chat_id")) is not int:
                raise HTTPException(422, "invalid_stream_grant")
            requested = body.get("recipient_device_ids")
            if (requested is not None and (not isinstance(requested, list) or len(requested) > 128
                    or any(not isinstance(item, str) or len(item) > 128 for item in requested))):
                raise HTTPException(422, "invalid_stream_grant")
            targets = await self.resolve_grants(principal, body["chat_id"], requested)
            if not targets:
                raise HTTPException(409, "stream_recipient_not_ready")

            def save(connection):
                registered_in_transaction(connection, principal)
                row = connection.execute("SELECT owner_device,ready FROM stream_manifests WHERE hash=?", (digest,)).fetchone()
                if row is None or row["owner_device"] != principal.device_id or not row["ready"]:
                    raise HTTPException(404, "stream_unavailable")
                for device in targets:
                    if connection.execute("SELECT 1 FROM devices WHERE device_id=? AND revoked=0", (device,)).fetchone() is None:
                        raise HTTPException(409, "stream_recipient_not_ready")
                    connection.execute("INSERT OR IGNORE INTO stream_grants VALUES(?,?,?)",
                                       (digest, device, body["chat_id"]))
            await self.store.transaction(save)
            return JSONResponse({"granted": len(targets)}, headers={"Cache-Control": "no-store"})

        @router.get("/v1/manifests/{digest}")
        async def manifest_get(digest: str, request: Request):
            self.path(digest)
            principal = await self.principal(request)
            row = await self.accessible(principal, digest)
            return Response(content=bytes(row["manifest"]), media_type="application/json",
                            headers={"Cache-Control": "private, no-store"})

        @router.api_route("/v1/blobs/{digest}", methods=["GET", "HEAD"])
        async def blob_get(digest: str, request: Request):
            path = self.path(digest)
            principal = await self.principal(request)
            row = await self.accessible(principal, digest)
            length = row["ciphertext_length"]
            try:
                if (await _io(path.stat)).st_size != length:
                    raise HTTPException(503, "stream_storage_unavailable")
            except FileNotFoundError:
                raise HTTPException(503, "stream_storage_unavailable") from None
            headers = self.receipt(row)
            if request.method == "HEAD":
                return Response(headers={**headers, "Content-Length": str(length)},
                                media_type="application/octet-stream")
            requested = request.headers.get("range", "")
            match = re.fullmatch(r"bytes=(\d+)-(\d+)", requested)
            if not match:
                raise HTTPException(416, "stream_range_required", headers={"Content-Range": f"bytes */{length}"})
            start, end = (int(item) for item in match.groups())
            if start > end or end >= length or end - start + 1 > 1_048_592:
                raise HTTPException(416, "stream_invalid_range", headers={"Content-Range": f"bytes */{length}"})

            async def read():
                handle = await _acquire_io(path.open, lambda value: value.close(), "rb", 0)
                try:
                    await _io(handle.seek, start)
                    remaining = end - start + 1
                    while remaining:
                        piece = await _io(handle.read, min(remaining, 65536))
                        if not piece:
                            raise RuntimeError("stream_storage_truncated")
                        remaining -= len(piece)
                        yield piece
                finally:
                    await _io(handle.close)
            headers.update({"Content-Range": f"bytes {start}-{end}/{length}",
                            "Content-Length": str(end - start + 1)})
            return StreamingResponse(read(), status_code=206, media_type="application/octet-stream", headers=headers)

        return router


def _write_all(handle, value) -> None:
    while value:
        count = handle.write(value)
        if not count:
            raise OSError("stream_storage_write_failed")
        value = value[count:]


@asynccontextmanager
async def _bounded_lock(lock):
    try:
        await asyncio.wait_for(lock.acquire(), 5)
    except asyncio.TimeoutError:
        raise HTTPException(503, "stream_upload_busy", headers={"Retry-After": "5"}) from None
    try:
        yield
    finally:
        lock.release()


def _file_lease(directory: Path, digest: str):
    handle = (directory / (digest + ".lock")).open("a+b")
    try:
        if os.name == "nt":
            import msvcrt
            if handle.tell() == 0:
                handle.write(b"\0")
                handle.flush()
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return handle
    except OSError:
        handle.close()
        raise HTTPException(503, "stream_upload_busy", headers={"Retry-After": "5"}) from None


def _release_lease(handle):
    try:
        if os.name == "nt":
            import msvcrt
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
    finally:
        handle.close()


def _clear_partials(directory: Path, digest: str):
    for path in directory.glob(digest + ".*.partial"):
        if re.fullmatch(r"[a-f0-9]{64}\.[a-f0-9]{32}\.partial", path.name):
            path.unlink(missing_ok=True)


def _reconcile_partials(directory: Path):
    # A process killed during upload leaves only ciphertext. Per-object OS
    # leases permit safe cleanup even if another worker is already receiving
    # that object; this never depends on the lifetime of an asyncio.Lock.
    digests = {path.name[:64] for path in directory.glob("*.partial")
               if re.fullmatch(r"[a-f0-9]{64}\.[a-f0-9]{32}\.partial", path.name)}
    for digest in digests:
        try:
            lease = _file_lease(directory, digest)
        except HTTPException:
            continue
        try:
            _clear_partials(directory, digest)
        finally:
            _release_lease(lease)
