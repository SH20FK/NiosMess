"""Loopback-only fixture using the real WS router and an isolated SQLite DB.

Authentication alone is replaced with two fixture accounts. Never import this
module in production. Run against a patched code snapshot using PYTHONPATH.
"""
import os
import sys
import tempfile
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path

fixture_root = Path(tempfile.mkdtemp(prefix='niosmess-secret-integration-'))
os.environ['DATABASE_URL'] = 'sqlite+aiosqlite:///' + (fixture_root / 'fixture.db').as_posix()
os.environ['SECRET_KEY'] = 'isolated-test-only'
os.environ['ENCRYPTION_KEY'] = '00000000000000000000000000000000'
os.environ['UPLOAD_DIR'] = str(fixture_root / 'uploads')

# Dependency shims used by the existing backend tests, never live services.
import test_secret_chat_hardening
from fastapi import FastAPI
import uvicorn
from sqlalchemy import select
from app.database import engine, AsyncSessionLocal
from app.models.models import Base, User, Session
from app.ws import router, connection_manager
from app.services import secret_chat_v2


async def authenticate(db, token):
    if token not in ('secret-test-1', 'secret-test-2'):
        return None, None
    uid = 1200 + int(token[-1])
    return await db.get(User, uid), await db.scalar(select(Session).where(Session.user_id == uid))


async def no_op(*args, **kwargs):
    return None


async def allow_fixture(*args, **kwargs):
    return True


router._get_user_and_session = authenticate
router._init_system_accounts = no_op
router._notify_user_presence = no_op
connection_manager.central_identity_allows_user = allow_fixture


@asynccontextmanager
async def lifespan(app):
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
    async with AsyncSessionLocal() as db:
        for uid in (1201, 1202):
            db.add(test_secret_chat_hardening._user(uid))
            db.add(test_secret_chat_hardening._session(uid, f'fixture-{uid}', ''))
        await db.commit()
    yield
    await engine.dispose()


app = FastAPI(lifespan=lifespan)
app.websocket('/ws')(router.ws_endpoint)


if __name__ == '__main__':
    uvicorn.run(app, host='127.0.0.2', port=int(sys.argv[1]), access_log=False)
