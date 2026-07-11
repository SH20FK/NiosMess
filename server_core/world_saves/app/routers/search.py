from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from app.database import get_db
from app.models.models import User, Chat, ChatMember, Message, ChatType
from app.services.utils import static_url, chat_link, share_link, get_user_badges, serialise_message
from app.services.encryption import decrypt_text
from app.dependencies import get_current_user

router = APIRouter(prefix="/search", tags=["Search"])

@router.get("")
async def search(q: str = Query(..., min_length=1),
                 current_user: User = Depends(get_current_user),
                 db: AsyncSession = Depends(get_db)):
    results = {"users": [], "chats": [], "messages": []}

    # Users — by username or display_name (includes badges)
    ur = await db.execute(select(User).where(
        or_(User.username.ilike(f"%{q}%"), User.display_name.ilike(f"%{q}%")),
        User.is_active == True, User.is_banned == False).limit(20))
    for u in ur.scalars().all():
        badges = await get_user_badges(db, u.id)
        results["users"].append({
            "id": u.id, "username": u.username, "display_name": u.display_name,
            "bio": u.bio or "", "avatar_url": static_url(u.avatar_path),
            "badges": badges,
        })

    # Groups/Channels — only if member
    cr = await db.execute(select(Chat).where(
        Chat.chat_type != ChatType.DIRECT, Chat.is_banned == False,
        or_(Chat.name.ilike(f"%{q}%"), Chat.username.ilike(f"%{q}%"))).limit(30))
    for chat in cr.scalars().all():
        mr = await db.execute(select(ChatMember).where(
            ChatMember.chat_id == chat.id, ChatMember.user_id == current_user.id,
            ChatMember.is_banned == False))
        if not mr.scalar_one_or_none(): continue
        from sqlalchemy import func
        cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
        results["chats"].append({
            "id": chat.id, "chat_type": chat.chat_type.value, "name": chat.name,
            "username": chat.username, "avatar_url": static_url(chat.avatar_path),
            "members_count": cnt.scalar(),
            "invite_link": chat_link(chat.username), "share_link": share_link(chat.username),
        })

    # Messages — only in user's chats, decrypt to search
    memr = await db.execute(select(ChatMember.chat_id).where(
        ChatMember.user_id == current_user.id, ChatMember.is_banned == False))
    my_chats = [row[0] for row in memr.all()]
    if my_chats:
        msgr = await db.execute(select(Message).where(
            Message.chat_id.in_(my_chats), Message.is_deleted == False,
            Message.encrypted_content != None).order_by(Message.sent_at.desc()).limit(500))
        for msg in msgr.scalars().all():
            try:
                content = decrypt_text(msg.encrypted_content, msg.content_iv, msg.content_tag)
            except Exception:
                continue
            if q.lower() in content.lower():
                out = await serialise_message(msg, db)
                results["messages"].append(out)
                if len(results["messages"]) >= 20: break

    return results
