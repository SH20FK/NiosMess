import hashlib, secrets, re
from datetime import datetime, timezone
from typing import Optional
from passlib.context import CryptContext
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.models import User, Session

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
PASSWORD_RE = re.compile(r"^(?=.*[A-Z])(?=.*\d).{8,}$")

def validate_password(pw: str) -> bool:
    return bool(PASSWORD_RE.match(pw))

def hash_password(pw: str) -> str:
    return pwd_context.hash(pw)

def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()

async def create_session(db: AsyncSession, user_id: int,
                         device_info: str = "", ip: str = "") -> str:
    raw = secrets.token_urlsafe(48)
    db.add(Session(user_id=user_id, token_hash=hash_token(raw),
                   device_info=device_info, ip_address=ip))
    await db.flush()
    return raw

async def get_session_by_token(db: AsyncSession, token: str) -> Optional[Session]:
    r = await db.execute(select(Session).where(
        Session.token_hash == hash_token(token), Session.is_active == True))
    return r.scalar_one_or_none()

async def get_user_by_id(db: AsyncSession, uid: int) -> Optional[User]:
    r = await db.execute(select(User).where(User.id == uid))
    return r.scalar_one_or_none()

async def get_user_by_identifier(db: AsyncSession, ident: str) -> Optional[User]:
    r = await db.execute(select(User).where(
        (User.email == ident) | (User.username == ident.lower())))
    return r.scalar_one_or_none()
