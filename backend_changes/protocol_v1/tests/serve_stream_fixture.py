"""Loopback integration fixture for the real Dart/Flutter enrollment and stream.

Only test identities/tokens are used. This file is never installed by the host
patch and does not import the production application's credentials or database.
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import json
from pathlib import Path
import socket
import sys

import uvicorn
from fastapi import HTTPException, Request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from nios_protocol.app import create_app
from nios_protocol.auth import Principal
from nios_protocol.blobs import StreamBlobs
from nios_protocol.store import ProtocolStore


def fixture(root: Path):
    store = ProtocolStore(root / "protocol.sqlite3", root / "data")
    principals = {
        "alice-fixture": Principal("101", 101, 1001, legacy_public_key=base64.b64encode(bytes([11]) * 32).decode()),
        "bob-fixture": Principal("202", 202, 2002, legacy_public_key=base64.b64encode(bytes([22]) * 32).decode()),
    }

    async def authenticate(request: Request):
        principal = principals.get(request.headers.get("authorization", "").removeprefix("Bearer "))
        if principal is None:
            raise HTTPException(401, "fixture_unauthorized")
        return principal

    async def authorize(principal, chat_id):
        return chat_id == 77 and principal.account_id in ("101", "202")

    async def resolve(principal, chat_id, requested):
        if not await authorize(principal, chat_id):
            raise HTTPException(403, "fixture_chat_forbidden")
        peer = "202" if principal.account_id == "101" else "101"
        rows = await store.read(lambda db: db.execute(
            "SELECT device_id,capabilities FROM devices WHERE account_id=? AND revoked=0", (peer,)
        ).fetchall())
        devices = [row["device_id"] for row in rows if 1 in json.loads(row["capabilities"])["stream"]]
        if len(devices) != 1 or (requested is not None and requested != devices):
            raise HTTPException(409, "fixture_peer_not_enrolled")
        return devices

    app = create_app(store, authenticate, service_capabilities={"stream": [1]})
    blobs = StreamBlobs(store, authenticate, resolve, authorize)
    app.include_router(blobs.router)
    counters = {"ranges": 0}

    @app.middleware("http")
    async def count_ranges(request, call_next):
        if request.method == "GET" and request.url.path.startswith("/v1/blobs/"):
            counters["ranges"] += 1
        return await call_next(request)

    @app.get("/fixture/stats")
    async def stats(request: Request):
        await authenticate(request)
        return await store.read(lambda db: {
            "devices": db.execute("SELECT COUNT(*) FROM devices WHERE revoked=0").fetchone()[0],
            "blobs": db.execute("SELECT COUNT(*) FROM stream_manifests WHERE ready=1").fetchone()[0],
            "grants": db.execute("SELECT COUNT(*) FROM stream_grants").fetchone()[0],
            "ranges": counters["ranges"],
        })

    return app


async def serve(root: Path):
    listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("127.0.0.1", 0))
    listener.listen(128)
    server = uvicorn.Server(uvicorn.Config(fixture(root), log_level="error", access_log=False,
                                          host="127.0.0.1", loop="asyncio"))
    running = asyncio.create_task(server.serve(sockets=[listener]))
    while not server.started:
        if running.done():
            await running
        await asyncio.sleep(0.01)
    print(json.dumps({"origin": f"http://127.0.0.1:{listener.getsockname()[1]}"}), flush=True)
    await running


if __name__ == "__main__":
    arguments = argparse.ArgumentParser()
    arguments.add_argument("--root", required=True, type=Path)
    options = arguments.parse_args()
    options.root.mkdir(parents=True, exist_ok=True)
    asyncio.run(serve(options.root))
