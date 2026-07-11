import os, uuid
import aiofiles
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel, field_validator
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.database import get_db
from app.models.models import Chat, ChatMember, User, Message, UnreadCounter, ChatType, MemberRole
from app.services.encryption import decrypt_text
from app.services.utils import static_url, chat_link, share_link, get_user_badges, get_unread, serialise_message
from app.dependencies import get_current_user
from app.config import settings

router = APIRouter(prefix="/chats", tags=["Chats"])

async def assert_admin(db, chat_id, user_id):
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == user_id))
    m = r.scalar_one_or_none()
    if not m or m.role not in (MemberRole.OWNER, MemberRole.ADMIN):
        raise HTTPException(403, "Admin access required")
    return m

async def assert_member(db, chat_id, user_id):
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == user_id,
        ChatMember.is_banned == False))
    m = r.scalar_one_or_none()
    if not m: raise HTTPException(403, "Not a member of this chat")
    return m

async def last_msg_out(db, chat_id):
    r = await db.execute(select(Message).where(
        Message.chat_id == chat_id, Message.is_deleted == False
    ).order_by(Message.sent_at.desc()).limit(1))
    msg = r.scalar_one_or_none()
    if not msg: return None
    return await serialise_message(msg, db)

async def _user_summary(db, u: User) -> dict:
    badges = await get_user_badges(db, u.id)
    return {"id": u.id, "username": u.username, "display_name": u.display_name,
            "avatar_url": static_url(u.avatar_path), "badges": badges}

class CreateGroupRequest(BaseModel):
    name: str
    chat_type: str
    description: Optional[str] = None
    username: Optional[str] = None
    comments_enabled: bool = True
    @field_validator("chat_type")
    @classmethod
    def vt(cls, v):
        if v not in ("group", "channel"): raise ValueError("group or channel only")
        return v

class UpdateChatRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    username: Optional[str] = None
    comments_enabled: Optional[bool] = None

class InviteUserRequest(BaseModel):
    user_id: int

class BanMemberRequest(BaseModel):
    user_id: int
    ban: bool = True

class MuteMemberRequest(BaseModel):
    user_id: int
    mute: bool = True

class PromoteRequest(BaseModel):
    user_id: int
    role: str

# ── List chats ────────────────────────────────────────────────────────────────

@router.get("/list")
async def list_chats(current_user: User = Depends(get_current_user),
                     db: AsyncSession = Depends(get_db)):
    """
    Returns all chats the user belongs to.
    Each chat includes: last message (with sender badges), unread count.
    """
    r = await db.execute(select(ChatMember).where(
        ChatMember.user_id == current_user.id, ChatMember.is_banned == False))
    result = []
    for m in r.scalars().all():
        cr = await db.execute(select(Chat).where(Chat.id == m.chat_id))
        chat = cr.scalar_one_or_none()
        if not chat or chat.is_banned: continue
        cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
        name = chat.name
        avatar = static_url(chat.avatar_path)
        
        partner_badges = []
        if chat.chat_type == ChatType.DIRECT:
            other_id = chat.user2_id if chat.user1_id == current_user.id else chat.user1_id
            ur = await db.execute(select(User).where(User.id == other_id))
            other = ur.scalar_one_or_none()
            if other:
                name = other.display_name
                avatar = avatar or static_url(other.avatar_path)
                try:
                    if not avatar or "None" in avatar:
                        avatar = "https://ni-os.ru/static/avatars/default.jpg"
                except:
                    avatar = "https://ni-os.ru/static/avatars/default.jpg"
                partner_badges = await get_user_badges(db, other.id)
        unread = await get_unread(db, chat.id, current_user.id)
        # Если avatar это None, пустая строка или строка "None"

        result.append({
            "id": chat.id,
            "chat_type": chat.chat_type.value,
            "name": name,
            "username": chat.username,
            "avatar_url": avatar,
            "invite_link": chat_link(chat.username),
            "share_link": share_link(chat.username),
            "last_message": await last_msg_out(db, chat.id),
            "unread_count": unread,
            "members_count": cnt.scalar(),
            "partner_badges": partner_badges,   # for direct chats
        })
    result.sort(key=lambda x: (x["last_message"] or {}).get("sent_at", ""), reverse=True)
    return result

# ── Direct chat ───────────────────────────────────────────────────────────────

@router.post("/direct/{username}")
async def open_direct(username: str, current_user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)):
    ur = await db.execute(select(User).where(User.username == username.lower()))
    other = ur.scalar_one_or_none()
    if not other: raise HTTPException(404, "User not found")
    if other.id == current_user.id: raise HTTPException(400, "Cannot DM yourself")
    if current_user.spam_block:
        raise HTTPException(403, "Spam-blocked accounts cannot initiate DMs.")
    u1, u2 = sorted([current_user.id, other.id])
    r = await db.execute(select(Chat).where(Chat.chat_type == ChatType.DIRECT,
                                             Chat.user1_id == u1, Chat.user2_id == u2))
    chat = r.scalar_one_or_none()
    if not chat:
        chat = Chat(chat_type=ChatType.DIRECT, user1_id=u1, user2_id=u2)
        db.add(chat); await db.flush()
        for uid in [u1, u2]:
            db.add(ChatMember(chat_id=chat.id, user_id=uid, role=MemberRole.MEMBER))
        await db.flush()
    return {"chat_id": chat.id, "chat_type": "direct",
            "with_user": await _user_summary(db, other)}

# ── Create group/channel ──────────────────────────────────────────────────────

@router.post("/create")
async def create_group(body: CreateGroupRequest, current_user: User = Depends(get_current_user),
                       db: AsyncSession = Depends(get_db)):
    if current_user.spam_block:
        raise HTTPException(403, "Spam-blocked accounts cannot create public chats.")
    slug = (body.username or uuid.uuid4().hex[:12]).lower()
    if not all(c.isalnum() or c in "_-" for c in slug):
        raise HTTPException(400, "Username may contain letters, digits, underscores, hyphens")
    r = await db.execute(select(Chat).where(Chat.username == slug))
    if r.scalar_one_or_none(): raise HTTPException(400, "Username/slug already taken")
    ctype = ChatType.GROUP if body.chat_type == "group" else ChatType.CHANNEL
    chat = Chat(chat_type=ctype, name=body.name, description=body.description,
                username=slug, created_by=current_user.id,
                comments_enabled=body.comments_enabled)
    db.add(chat); await db.flush()
    # For channels with comments: create a linked group chat
    if ctype == ChatType.CHANNEL and body.comments_enabled:
        comments_chat = Chat(chat_type=ChatType.GROUP,
                             name=f"{body.name} — Comments",
                             created_by=current_user.id)
        db.add(comments_chat); await db.flush()
        chat.comments_chat_id = comments_chat.id
        db.add(ChatMember(chat_id=comments_chat.id, user_id=current_user.id, role=MemberRole.OWNER))
    db.add(ChatMember(chat_id=chat.id, user_id=current_user.id, role=MemberRole.OWNER))
    return {"chat_id": chat.id, "name": chat.name, "username": slug,
            "invite_link": chat_link(slug), "share_link": share_link(slug),
            "comments_chat_id": chat.comments_chat_id}

# ── Get chat ──────────────────────────────────────────────────────────────────

@router.get("/{chat_id}")
async def get_chat(chat_id: int, current_user: User = Depends(get_current_user),
                   db: AsyncSession = Depends(get_db)):
    await assert_member(db, chat_id, current_user.id)
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one_or_none()
    if not chat: raise HTTPException(404, "Chat not found")
    if chat.is_banned: raise HTTPException(403, "This chat has been banned by admin")
    cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat_id))
    name = chat.name
    partner = None
    if chat.chat_type == ChatType.DIRECT:
        other_id = chat.user2_id if chat.user1_id == current_user.id else chat.user1_id
        ur = await db.execute(select(User).where(User.id == other_id))
        other = ur.scalar_one_or_none()
        if other:
            name = other.display_name
            partner = await _user_summary(db, other)
    return {"id": chat.id, "chat_type": chat.chat_type.value, "name": name,
            "username": chat.username, "description": chat.description,
            "avatar_url": static_url(chat.avatar_path), "members_count": cnt.scalar(),
            "comments_enabled": chat.comments_enabled,
            "comments_chat_id": chat.comments_chat_id,
            "invite_link": chat_link(chat.username),
            "share_link": share_link(chat.username),
            "unread_count": await get_unread(db, chat_id, current_user.id),
            "last_message": await last_msg_out(db, chat_id),
            "partner": partner}

# ── Members ───────────────────────────────────────────────────────────────────

@router.get("/{chat_id}/members")
async def get_members(chat_id: int, current_user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)):
    await assert_member(db, chat_id, current_user.id)
    r = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id))
    result = []
    for m in r.scalars().all():
        ur = await db.execute(select(User).where(User.id == m.user_id))
        u = ur.scalar_one_or_none()
        if not u: continue
        badges = await get_user_badges(db, u.id)
        result.append({"user_id": u.id, "username": u.username, "display_name": u.display_name,
                        "avatar_url": static_url(u.avatar_path), "badges": badges,
                        "role": m.role.value, "is_muted": m.is_muted, "is_banned": m.is_banned})
    return result

# ── Update ────────────────────────────────────────────────────────────────────

@router.patch("/{chat_id}/update")
async def update_chat(chat_id: int, body: UpdateChatRequest,
                      current_user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)):
    await assert_admin(db, chat_id, current_user.id)
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one_or_none()
    if not chat: raise HTTPException(404, "Chat not found")
    if body.name: chat.name = body.name
    if body.description is not None: chat.description = body.description
    if body.comments_enabled is not None: chat.comments_enabled = body.comments_enabled
    if body.username:
        slug = body.username.lower()
        ex = await db.execute(select(Chat).where(Chat.username == slug, Chat.id != chat_id))
        if ex.scalar_one_or_none(): raise HTTPException(400, "Username taken")
        chat.username = slug
    return {"message": "Updated", "invite_link": chat_link(chat.username),
            "share_link": share_link(chat.username)}

@router.post("/{chat_id}/avatar")
async def chat_avatar_upload(chat_id: int, file: UploadFile = File(...),
                              current_user: User = Depends(get_current_user),
                              db: AsyncSession = Depends(get_db)):
    await assert_admin(db, chat_id, current_user.id)
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(400, "File must be an image")
    ext = file.filename.rsplit(".",1)[-1] if "." in (file.filename or "") else "jpg"
    fname = f"avatars/chat_{chat_id}_{uuid.uuid4().hex}.{ext}"
    fpath = os.path.join(settings.UPLOAD_DIR, fname)
    os.makedirs(os.path.dirname(fpath), exist_ok=True)
    async with aiofiles.open(fpath, "wb") as f:
        while chunk := await file.read(131072): await f.write(chunk)
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one(); chat.avatar_path = fname
    return {"avatar_url": static_url(fname)}

# ── Admin actions ─────────────────────────────────────────────────────────────

@router.post("/{chat_id}/invite")
async def invite_user(chat_id: int, body: InviteUserRequest,
                      current_user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)):
    await assert_admin(db, chat_id, current_user.id)
    ur = await db.execute(select(User).where(User.id == body.user_id))
    target = ur.scalar_one_or_none()
    if not target: raise HTTPException(404, "User not found")
    if target.spam_block: raise HTTPException(403, "User has a spam-block.")
    ex = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == body.user_id))
    if ex.scalar_one_or_none(): raise HTTPException(400, "User already a member")
    db.add(ChatMember(chat_id=chat_id, user_id=body.user_id, role=MemberRole.MEMBER))
    return {"message": "User invited"}

@router.post("/{chat_id}/ban")
async def ban_member(chat_id: int, body: BanMemberRequest,
                     current_user: User = Depends(get_current_user),
                     db: AsyncSession = Depends(get_db)):
    await assert_admin(db, chat_id, current_user.id)
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == body.user_id))
    m = r.scalar_one_or_none()
    if not m: raise HTTPException(404, "Member not found")
    m.is_banned = body.ban
    return {"message": f"User {'banned' if body.ban else 'unbanned'} from chat"}

@router.post("/{chat_id}/mute")
async def mute_member(chat_id: int, body: MuteMemberRequest,
                      current_user: User = Depends(get_current_user),
                      db: AsyncSession = Depends(get_db)):
    await assert_admin(db, chat_id, current_user.id)
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == body.user_id))
    m = r.scalar_one_or_none()
    if not m: raise HTTPException(404, "Member not found")
    m.is_muted = body.mute
    return {"message": f"User {'muted' if body.mute else 'unmuted'}"}

@router.post("/{chat_id}/promote")
async def promote_member(chat_id: int, body: PromoteRequest,
                         current_user: User = Depends(get_current_user),
                         db: AsyncSession = Depends(get_db)):
    await assert_admin(db, chat_id, current_user.id)
    if body.role not in ("admin","member"): raise HTTPException(400, "Role must be admin or member")
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == body.user_id))
    m = r.scalar_one_or_none()
    if not m: raise HTTPException(404, "Member not found")
    m.role = MemberRole.ADMIN if body.role == "admin" else MemberRole.MEMBER
    return {"message": f"Role set to {body.role}"}

@router.post("/{chat_id}/leave")
async def leave_chat(chat_id: int, current_user: User = Depends(get_current_user),
                     db: AsyncSession = Depends(get_db)):
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == current_user.id))
    m = r.scalar_one_or_none()
    if not m: raise HTTPException(404, "Not in this chat")
    await db.delete(m)
    return {"message": "Left chat"}

@router.post("/{chat_id}/read")
async def mark_read(chat_id: int, current_user: User = Depends(get_current_user),
                    db: AsyncSession = Depends(get_db)):
    """Mark all messages in chat as read — resets unread counter."""
    await assert_member(db, chat_id, current_user.id)
    from app.services.utils import reset_unread
    await reset_unread(db, chat_id, current_user.id)
    return {"message": "Marked as read", "unread_count": 0}
