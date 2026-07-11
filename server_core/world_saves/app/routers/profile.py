import os, uuid
import aiofiles
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.models import User, Session, Badge, UserBadge
from app.services.auth_svc import verify_password
from app.services.encryption import encrypt_text
from app.services.utils import static_url, get_user_badges
from app.dependencies import get_current_user
from app.config import settings

router = APIRouter(prefix="/profile", tags=["Profile"])

async def full_user_out(db, u: User) -> dict:
    badges = await get_user_badges(db, u.id)
    return {"id": u.id, "username": u.username, "display_name": u.display_name,
            "bio": u.bio or "", "avatar_url": static_url(u.avatar_path), "badges": badges}

class UpdateProfileRequest(BaseModel):
    display_name: Optional[str] = None
    username: Optional[str] = None
    bio: Optional[str] = None

class Toggle2FARequest(BaseModel):
    enabled: bool
    password: str

@router.get("/me/info")
async def my_profile(current_user: User = Depends(get_current_user),
                     db: AsyncSession = Depends(get_db)):
    d = await full_user_out(db, current_user)
    d["two_fa_enabled"] = current_user.two_fa_enabled
    d["spam_block"] = current_user.spam_block
    return d

@router.get("/{username}")
async def get_profile(username: str, db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(User).where(User.username == username.lower()))
    u = r.scalar_one_or_none()
    if not u or u.is_banned: raise HTTPException(404, "User not found")
    return await full_user_out(db, u)

@router.get("/{username}/encrypted")
async def get_profile_encrypted(username: str, db: AsyncSession = Depends(get_db)):
    """Returns profile JSON encrypted with AES-256-GCM."""
    import json
    r = await db.execute(select(User).where(User.username == username.lower()))
    u = r.scalar_one_or_none()
    if not u: raise HTTPException(404, "User not found")
    enc = encrypt_text(json.dumps(await full_user_out(db, u)))
    return {"encrypted_data": enc["ciphertext"], "iv": enc["iv"], "tag": enc["tag"]}

@router.patch("/me/update")
async def update_profile(body: UpdateProfileRequest,
                         current_user: User = Depends(get_current_user),
                         db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(User).where(User.id == current_user.id))
    u = r.scalar_one()
    if body.display_name: u.display_name = body.display_name
    if body.bio is not None: u.bio = body.bio
    if body.username:
        uname = body.username.lower()
        ex = await db.execute(select(User).where(User.username == uname, User.id != u.id))
        if ex.scalar_one_or_none(): raise HTTPException(400, "Username taken")
        u.username = uname
    return await full_user_out(db, u)

@router.post("/me/avatar")
async def upload_avatar(file: UploadFile = File(...),
                        current_user: User = Depends(get_current_user),
                        db: AsyncSession = Depends(get_db)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "File must be an image")
    ext = file.filename.rsplit(".",1)[-1] if "." in (file.filename or "") else "jpg"
    fname = f"avatars/{current_user.id}_{uuid.uuid4().hex}.{ext}"
    fpath = os.path.join(settings.UPLOAD_DIR, fname)
    os.makedirs(os.path.dirname(fpath), exist_ok=True)
    async with aiofiles.open(fpath, "wb") as f:
        while chunk := await file.read(131072): await f.write(chunk)
    r = await db.execute(select(User).where(User.id == current_user.id))
    u = r.scalar_one(); u.avatar_path = fname
    return {"avatar_url": static_url(fname)}

@router.post("/me/2fa")
async def toggle_2fa(body: Toggle2FARequest,
                     current_user: User = Depends(get_current_user),
                     db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(User).where(User.id == current_user.id))
    u = r.scalar_one()
    if not verify_password(body.password, u.hashed_password):
        raise HTTPException(403, "Wrong password")
    u.two_fa_enabled = body.enabled
    return {"two_fa_enabled": u.two_fa_enabled}

@router.get("/me/sessions")
async def list_sessions(current_user: User = Depends(get_current_user),
                        db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(Session).where(
        Session.user_id == current_user.id, Session.is_active == True))
    sessions = r.scalars().all()
    return [{"id": s.id, "device_info": s.device_info, "ip_address": s.ip_address,
             "created_at": s.created_at, "last_active": s.last_active} for s in sessions]

@router.delete("/me/sessions/{session_id}")
async def kick_session(session_id: int, current_user: User = Depends(get_current_user),
                       db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(Session).where(
        Session.id == session_id, Session.user_id == current_user.id))
    s = r.scalar_one_or_none()
    if not s: raise HTTPException(404, "Session not found")
    s.is_active = False
    return {"message": "Session revoked"}
