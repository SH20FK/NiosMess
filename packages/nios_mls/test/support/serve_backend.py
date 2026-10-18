"""Loopback-only cross-language test fixture; never installed in production."""
import argparse
import asyncio
import base64
import json
from pathlib import Path
import socket
import sys
import time

parser = argparse.ArgumentParser()
parser.add_argument("--backend", required=True)
parser.add_argument("--directory", required=True)
args = parser.parse_args()
sys.path.insert(0, str(Path(args.backend).resolve()))

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
import uvicorn
from nios_protocol.auth import Principal, base64_bytes, json_body
from nios_protocol.mls import create_mls_router
from nios_protocol.store import ProtocolStore

directory = Path(args.directory).resolve()
directory.mkdir(parents=True, exist_ok=True)
store = ProtocolStore(directory / "protocol.db", directory / "data")
asyncio.run(store.initialize())
app = FastAPI()
fail_next_commit = False


async def authenticate(request: Request):
    device = request.headers.get("authorization", "").removeprefix("Bearer test-only-")
    ids = {"alice": 1, "bob": 2, "carol": 3}
    if device not in ids or request.client.host != "127.0.0.1":
        raise HTTPException(401, "test_auth_required")
    return Principal(device, ids[device], ids[device], device)


async def authorize(who, chat, action, target_devices):
    return (chat == "test-chat" and set(target_devices) <= {"alice", "bob", "carol"}
            and (action == "participate" or who.device_id == "alice"))


@app.post("/test/enroll")
async def enroll(request: Request):
    who = await authenticate(request)
    body = await json_body(request, limit=4096)
    link = base64.b64encode(base64_bytes(body.get("link_key"), 32)).decode()
    mls = base64.b64encode(base64_bytes(body.get("mls_key"), 32)).decode()
    caps = json.dumps({"mls": {"versions": ["1.0"], "suites": ["0x0001"]}})
    def save(conn):
        old = conn.execute("SELECT * FROM devices WHERE device_id=?", (who.device_id,)).fetchone()
        if old:
            if old["link_key"] != link or old["mls_key"] != mls:
                raise HTTPException(409, "test_key_mismatch")
            return
        now = int(time.time())
        conn.execute("INSERT INTO identities VALUES(?,?,?)", (who.account_id, link, now))
        conn.execute("INSERT INTO devices(device_id,account_id,user_id,session_id,identity_key,mls_key,link_key,capabilities,created_at,updated_at) VALUES(?,?,?,?,?,?,?,?,?,?)",
                     (who.device_id, who.account_id, who.user_id, who.session_id, link, mls, link, caps, now, now))
    await store.transaction(save)
    return {"registered": True}


@app.post("/test/fail-next-commit-reply")
async def fail_reply(request: Request):
    global fail_next_commit
    if (await authenticate(request)).device_id != "alice":
        raise HTTPException(403, "test_owner_required")
    fail_next_commit = True
    return {"armed": True}


@app.middleware("http")
async def interrupt_reply(request, call_next):
    global fail_next_commit
    response = await call_next(request)
    if (fail_next_commit and request.method == "PUT" and "/commits/" in request.url.path
            and response.status_code == 200):
        fail_next_commit = False
        return JSONResponse({"detail": "test_commit_reply_lost"}, status_code=503)
    return response


app.include_router(create_mls_router(store, authenticate, authorize))
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
sock.bind(("127.0.0.1", 0))
sock.listen(128)
print(json.dumps({"port": sock.getsockname()[1]}), flush=True)
config = uvicorn.Config(app, log_config=None, access_log=False, log_level="critical")
uvicorn.Server(config).run(sockets=[sock])
