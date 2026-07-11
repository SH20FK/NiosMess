"""Shared utilities: message serialiser, unread helpers, mime detection."""
import os
from typing import Optional
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import settings
from app.models.models import User, Chat, ChatMember, Message, UnreadCounter, ChatType, MessageType, Badge, UserBadge
from app.services.encryption import decrypt_text


def static_url(path: Optional[str]) -> Optional[str]:
    return f"https://ni-os.ru/static/{path}" if path else None

def chat_link(username: Optional[str]) -> Optional[str]:
    return f"https://ni-os.ru/join/{username}" if username else None

def share_link(username: Optional[str]) -> Optional[str]:
    return f"https://ni-os.ru/{username}" if username else None

def _guess_mime(filename: str) -> str:
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    return {"jpg":"image/jpeg","jpeg":"image/jpeg","png":"image/png","gif":"image/gif",
            "webp":"image/webp","mp4":"video/mp4","mov":"video/quicktime","webm":"video/webm",
            "mp3":"audio/mpeg","ogg":"audio/ogg","wav":"audio/wav","m4a":"audio/mp4",
            "pdf":"application/pdf","zip":"application/zip"}.get(ext, "application/octet-stream")

async def get_user_badges(db: AsyncSession, user_id: int) -> list:
    r = await db.execute(select(UserBadge).where(UserBadge.user_id == user_id))
    badges = []
    for ub in r.scalars().all():
        br = await db.execute(select(Badge).where(Badge.id == ub.badge_id))
        bg = br.scalar_one_or_none()
        if bg:
            badges.append({"id": bg.id, "name": bg.name, "icon": bg.icon, "color": bg.color})
    return badges

async def serialise_message(msg: Message, db: AsyncSession) -> dict:
    content = None
    if msg.encrypted_content and not msg.is_deleted:
        try:
            content = decrypt_text(msg.encrypted_content, msg.content_iv, msg.content_tag)
        except Exception:
            content = "[decryption error]"

    sr = await db.execute(select(User).where(User.id == msg.sender_id))
    sender = sr.scalar_one_or_none()
    sender_badges = await get_user_badges(db, msg.sender_id) if sender else []

    # Reactions summary
    from app.models.models import MessageReaction
    rr = await db.execute(select(MessageReaction).where(MessageReaction.message_id == msg.id))
    reactions: dict = {}
    for rxn in rr.scalars().all():
        reactions[rxn.emoji] = reactions.get(rxn.emoji, 0) + 1

    return {
        "id": msg.id,
        "chat_id": msg.chat_id,
        "sender_id": msg.sender_id,
        "sender_username": sender.username if sender else "",
        "sender_display_name": sender.display_name if sender else "",
        "sender_avatar_url": static_url(sender.avatar_path) if sender else None,
        "sender_badges": sender_badges,
        "msg_type": msg.msg_type.value,
        "content": content,
        "reply_to_id": msg.reply_to_id,
        "media_url": static_url(msg.media_path),
        "media_type": msg.media_type,
        "media_name": msg.media_name,
        "media_size": msg.media_size,
        "media_duration": msg.media_duration,
        "comments_count": msg.comments_count or 0,
        "reactions": reactions,
        "is_deleted": msg.is_deleted,
        "sent_at": msg.sent_at.isoformat() if msg.sent_at else None,
        "edited_at": msg.edited_at.isoformat() if msg.edited_at else None,
    }

async def increment_unread(db: AsyncSession, chat_id: int, sender_id: int, message_id: int):
    """Bump unread counter for all chat members except the sender."""
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id != sender_id,
        ChatMember.is_banned == False))
    for member in r.scalars().all():
        uc_r = await db.execute(select(UnreadCounter).where(
            UnreadCounter.chat_id == chat_id, UnreadCounter.user_id == member.user_id))
        uc = uc_r.scalar_one_or_none()
        if uc:
            uc.count += 1
            uc.last_message_id = message_id
        else:
            db.add(UnreadCounter(chat_id=chat_id, user_id=member.user_id,
                                  count=1, last_message_id=message_id))

async def reset_unread(db: AsyncSession, chat_id: int, user_id: int):
    """Reset unread counter for a user in a chat."""
    r = await db.execute(select(UnreadCounter).where(
        UnreadCounter.chat_id == chat_id, UnreadCounter.user_id == user_id))
    uc = r.scalar_one_or_none()
    if uc:
        uc.count = 0

async def get_unread(db: AsyncSession, chat_id: int, user_id: int) -> int:
    r = await db.execute(select(UnreadCounter).where(
        UnreadCounter.chat_id == chat_id, UnreadCounter.user_id == user_id))
    uc = r.scalar_one_or_none()
    return uc.count if uc else 0
