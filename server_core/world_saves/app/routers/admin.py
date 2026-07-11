"""Admin panel — protected by X-Admin-Password header or ?password= query param."""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database import get_db
from app.models.models import User, Chat, Badge, UserBadge, Session, ChatType
from app.services.utils import static_url, get_user_badges
from app.config import settings

router = APIRouter(prefix="/admin", tags=["Admin"])

def _check(pw: str):
    if pw != settings.ADMIN_PASSWORD:
        raise HTTPException(403, "Invalid admin password")

# ── Schemas ───────────────────────────────────────────────────────────────────

class BanUserReq(BaseModel):
    password: str; user_id: int; reason: Optional[str] = None

class UnbanUserReq(BaseModel):
    password: str; user_id: int

class FreezeUserReq(BaseModel):
    password: str; user_id: int; frozen: bool = True

class SpamBlockReq(BaseModel):
    password: str; user_id: int; blocked: bool = True

class BanChatReq(BaseModel):
    password: str; chat_id: int; banned: bool = True

class CreateBadgeReq(BaseModel):
    password: str; name: str; description: str = ""; icon: str = "🏅"; color: str = "#4f46e5"

class AwardBadgeReq(BaseModel):
    password: str; user_id: int; badge_id: int

class RevokeBadgeReq(BaseModel):
    password: str; user_id: int; badge_id: int

class DeleteBadgeReq(BaseModel):
    password: str

# ── User helpers ──────────────────────────────────────────────────────────────

async def _user_row(db, u: User) -> dict:
    badges = await get_user_badges(db, u.id)
    return {"id": u.id, "username": u.username, "email": u.email,
            "display_name": u.display_name, "avatar_url": static_url(u.avatar_path),
            "is_active": u.is_active, "is_banned": u.is_banned,
            "is_frozen": u.is_frozen, "spam_block": u.spam_block,
            "two_fa_enabled": u.two_fa_enabled, "created_at": u.created_at,
            "badges": badges}

# ── User list & detail ────────────────────────────────────────────────────────

@router.get("/users")
async def admin_list_users(password: str, page: int = 1, page_size: int = 50,
                            db: AsyncSession = Depends(get_db)):
    """List all users with badges included."""
    _check(password)
    r = await db.execute(select(User).offset((page-1)*page_size).limit(page_size))
    return [await _user_row(db, u) for u in r.scalars().all()]

@router.get("/users/{user_id}")
async def admin_get_user(user_id: int, password: str, db: AsyncSession = Depends(get_db)):
    _check(password)
    r = await db.execute(select(User).where(User.id == user_id))
    u = r.scalar_one_or_none()
    if not u: raise HTTPException(404, "User not found")
    return await _user_row(db, u)

# ── User moderation ───────────────────────────────────────────────────────────

@router.post("/users/ban")
async def ban_user(body: BanUserReq, db: AsyncSession = Depends(get_db)):
    _check(body.password)
    r = await db.execute(select(User).where(User.id == body.user_id))
    u = r.scalar_one_or_none()
    if not u: raise HTTPException(404, "User not found")
    u.is_banned = True
    sr = await db.execute(select(Session).where(Session.user_id == u.id))
    for s in sr.scalars().all(): s.is_active = False
    return {"message": f"User @{u.username} banned", "reason": body.reason}

@router.post("/users/unban")
async def unban_user(body: UnbanUserReq, db: AsyncSession = Depends(get_db)):
    _check(body.password)
    r = await db.execute(select(User).where(User.id == body.user_id))
    u = r.scalar_one_or_none()
    if not u: raise HTTPException(404, "User not found")
    u.is_banned = False
    return {"message": f"User @{u.username} unbanned"}

@router.post("/users/freeze")
async def freeze_user(body: FreezeUserReq, db: AsyncSession = Depends(get_db)):
    _check(body.password)
    r = await db.execute(select(User).where(User.id == body.user_id))
    u = r.scalar_one_or_none()
    if not u: raise HTTPException(404, "User not found")
    u.is_frozen = body.frozen
    if body.frozen:
        sr = await db.execute(select(Session).where(Session.user_id == u.id))
        for s in sr.scalars().all(): s.is_active = False
    return {"message": f"User @{u.username} {'frozen' if body.frozen else 'unfrozen'}"}

@router.post("/users/spamblock")
async def spam_block(body: SpamBlockReq, db: AsyncSession = Depends(get_db)):
    """Prevents user from initiating DMs or joining public chats."""
    _check(body.password)
    r = await db.execute(select(User).where(User.id == body.user_id))
    u = r.scalar_one_or_none()
    if not u: raise HTTPException(404, "User not found")
    u.spam_block = body.blocked
    return {"message": f"User @{u.username} spam_block={'on' if body.blocked else 'off'}"}

# ── Chat moderation ───────────────────────────────────────────────────────────

@router.get("/chats")
async def admin_list_chats(password: str, page: int = 1, page_size: int = 50,
                            db: AsyncSession = Depends(get_db)):
    _check(password)
    from sqlalchemy import func
    from app.models.models import ChatMember
    r = await db.execute(select(Chat).where(Chat.chat_type != ChatType.DIRECT)
                         .offset((page-1)*page_size).limit(page_size))
    result = []
    for chat in r.scalars().all():
        cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
        result.append({"id": chat.id, "name": chat.name, "chat_type": chat.chat_type.value,
                        "username": chat.username, "is_banned": chat.is_banned,
                        "members_count": cnt.scalar(), "created_at": chat.created_at})
    return result

@router.post("/chats/ban")
async def ban_chat(body: BanChatReq, db: AsyncSession = Depends(get_db)):
    _check(body.password)
    r = await db.execute(select(Chat).where(Chat.id == body.chat_id))
    chat = r.scalar_one_or_none()
    if not chat: raise HTTPException(404, "Chat not found")
    if chat.chat_type == ChatType.DIRECT: raise HTTPException(400, "Cannot ban direct chats")
    chat.is_banned = body.banned
    return {"message": f"Chat '{chat.name}' {'banned' if body.banned else 'unbanned'}"}

# ── Badge management ──────────────────────────────────────────────────────────

@router.get("/badges")
async def list_badges(password: str, db: AsyncSession = Depends(get_db)):
    _check(password)
    r = await db.execute(select(Badge))
    return [{"id": b.id, "name": b.name, "description": b.description,
             "icon": b.icon, "color": b.color, "created_at": b.created_at}
            for b in r.scalars().all()]

@router.post("/badges/create", status_code=201)
async def create_badge(body: CreateBadgeReq, db: AsyncSession = Depends(get_db)):
    _check(body.password)
    r = await db.execute(select(Badge).where(Badge.name == body.name))
    if r.scalar_one_or_none(): raise HTTPException(400, "Badge name already exists")
    badge = Badge(name=body.name, description=body.description, icon=body.icon, color=body.color)
    db.add(badge); await db.flush()
    return {"id": badge.id, "name": badge.name, "icon": badge.icon, "color": badge.color}

@router.delete("/badges/{badge_id}")
async def delete_badge(badge_id: int, body: DeleteBadgeReq, db: AsyncSession = Depends(get_db)):
    _check(body.password)
    r = await db.execute(select(Badge).where(Badge.id == badge_id))
    badge = r.scalar_one_or_none()
    if not badge: raise HTTPException(404, "Badge not found")
    await db.delete(badge)
    return {"message": "Badge deleted"}

@router.post("/badges/award")
async def award_badge(body: AwardBadgeReq, db: AsyncSession = Depends(get_db)):
    _check(body.password)
    ur = await db.execute(select(User).where(User.id == body.user_id))
    if not ur.scalar_one_or_none(): raise HTTPException(404, "User not found")
    br = await db.execute(select(Badge).where(Badge.id == body.badge_id))
    if not br.scalar_one_or_none(): raise HTTPException(404, "Badge not found")
    ex = await db.execute(select(UserBadge).where(
        UserBadge.user_id == body.user_id, UserBadge.badge_id == body.badge_id))
    if ex.scalar_one_or_none(): raise HTTPException(400, "User already has this badge")
    db.add(UserBadge(user_id=body.user_id, badge_id=body.badge_id))
    return {"message": "Badge awarded"}

@router.post("/badges/revoke")
async def revoke_badge(body: RevokeBadgeReq, db: AsyncSession = Depends(get_db)):
    _check(body.password)
    r = await db.execute(select(UserBadge).where(
        UserBadge.user_id == body.user_id, UserBadge.badge_id == body.badge_id))
    ub = r.scalar_one_or_none()
    if not ub: raise HTTPException(404, "User does not have this badge")
    await db.delete(ub)
    return {"message": "Badge revoked"}
