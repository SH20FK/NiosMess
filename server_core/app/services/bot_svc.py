import json, secrets, os, base64, aiofiles
from datetime import datetime, timezone
from typing import Optional, Dict, List
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.models import User, Bot, BotUpdate, Chat, ChatMember, MemberRole, Message, MessageType, ChatType
from app.services.auth_svc import hash_password
from app.services.encryption import encrypt_text
from app.services.utils import static_url, serialise_message, increment_unread
from app.config import settings

# Bot creator user id (set during init)
_BOTCREATOR_ID: Optional[int] = None

def set_botcreator_id(uid: int):
    global _BOTCREATOR_ID
    _BOTCREATOR_ID = uid

def get_botcreator_id() -> Optional[int]:
    return _BOTCREATOR_ID

# In-memory state for interactive BotCreator dialogs (user_id -> state)
botcreator_states: Dict[int, dict] = {}

def get_botcreator_state(user_id: int) -> Optional[dict]:
    return botcreator_states.get(user_id)

def set_botcreator_state(user_id: int, state: dict):
    botcreator_states[user_id] = state

def clear_botcreator_state(user_id: int):
    botcreator_states.pop(user_id, None)


def _bot_token() -> str:
    return secrets.token_urlsafe(32)


async def ensure_botcreator(db: AsyncSession) -> User:
    """Create built-in botcreator account if not exists."""
    r = await db.execute(select(User).where(User.username == "botcreator"))
    user = r.scalar_one_or_none()
    if not user:
        user = User(
            email="botcreator@nios.mess",
            username="botcreator",
            display_name="BotCreator",
            hashed_password=hash_password(secrets.token_urlsafe(32)),
            is_active=True,
            is_verified=True,
            is_bot=True,
        )
        db.add(user)
        await db.flush()
        set_botcreator_id(user.id)
    else:
        set_botcreator_id(user.id)
        if not user.is_bot:
            user.is_bot = True
    return user


async def create_bot(db: AsyncSession, owner_id: int, name: str, username: str) -> dict:
    """Create a new bot for a user."""
    slug = username.lower().strip()
    if not slug.endswith("bot"):
        return {"error": "Username must end with 'bot' (e.g. mycool_bot)"}
    if not all(c.isalnum() or c in "_" for c in slug):
        return {"error": "Username may contain only letters, digits, underscores"}
    if len(slug) < 3 or len(slug) > 32:
        return {"error": "Username must be 3-32 chars"}
    # Check username availability
    ur = await db.execute(select(User).where(User.username == slug))
    if ur.scalar_one_or_none():
        return {"error": "Username already taken"}
    br = await db.execute(select(Bot).where(Bot.username == slug))
    if br.scalar_one_or_none():
        return {"error": "Bot username already taken"}
    # Create bot user
    bot_user = User(
        email=f"bot-{slug}@nios.mess",
        username=slug,
        display_name=name,
        hashed_password=hash_password(secrets.token_urlsafe(32)),
        is_active=True,
        is_verified=True,
        is_bot=True,
    )
    db.add(bot_user)
    await db.flush()
    bot = Bot(
        user_id=bot_user.id,
        owner_id=owner_id,
        token=_bot_token(),
        name=name,
        username=slug,
    )
    db.add(bot)
    await db.flush()
    return {
        "bot_id": bot.id,
        "user_id": bot_user.id,
        "token": bot.token,
        "username": bot.username,
        "name": bot.name,
    }


async def get_bot_by_token(db: AsyncSession, token: str) -> Optional[Bot]:
    r = await db.execute(select(Bot).where(Bot.token == token, Bot.is_active == True))
    return r.scalar_one_or_none()


async def get_bot_by_user_id(db: AsyncSession, user_id: int) -> Optional[Bot]:
    r = await db.execute(select(Bot).where(Bot.user_id == user_id))
    return r.scalar_one_or_none()


async def list_user_bots(db: AsyncSession, owner_id: int) -> List[dict]:
    r = await db.execute(select(Bot).where(Bot.owner_id == owner_id))
    bots = []
    for b in r.scalars().all():
        bots.append({
            "id": b.id,
            "name": b.name,
            "username": b.username,
            "token": b.token,
        })
    return bots


async def send_bot_message(db: AsyncSession, bot: Bot, chat_id: int, text: str, reply_markup: Optional[dict] = None) -> dict:
    """Send a message as bot to a chat."""
    # Ensure bot is member of chat or it's a DM with a user
    msg = Message(
        chat_id=chat_id,
        sender_id=bot.user_id,
        msg_type=MessageType.TEXT,
    )
    enc = encrypt_text(text)
    msg.encrypted_content = enc["ciphertext"]
    msg.content_iv = enc["iv"]
    msg.content_tag = enc["tag"]
    if reply_markup:
        msg.reply_markup = json.dumps(reply_markup)
    db.add(msg)
    await db.flush()
    await increment_unread(db, chat_id, bot.user_id, msg.id)
    result = await serialise_message(msg, db)
    # Push to chat members via ws_manager (inline import to avoid circular)
    from app.ws_manager import push_to_chat
    await push_to_chat(db, chat_id, {"action": "new_message", "payload": result}, exclude_user_id=bot.user_id)
    return result


async def edit_bot_message_reply_markup(db: AsyncSession, bot: Bot, chat_id: int, message_id: int, reply_markup: Optional[dict]) -> dict:
    r = await db.execute(select(Message).where(Message.id == message_id, Message.chat_id == chat_id, Message.sender_id == bot.user_id))
    msg = r.scalar_one_or_none()
    if not msg:
        return {"error": "Message not found or not owned by bot"}
    if reply_markup:
        msg.reply_markup = json.dumps(reply_markup)
    else:
        msg.reply_markup = None
    return await serialise_message(msg, db)


async def delete_bot_message(db: AsyncSession, bot: Bot, chat_id: int, message_id: int) -> dict:
    r = await db.execute(select(Message).where(Message.id == message_id, Message.chat_id == chat_id, Message.sender_id == bot.user_id))
    msg = r.scalar_one_or_none()
    if not msg:
        return {"error": "Message not found or not owned by bot"}
    msg.is_deleted = True
    msg.encrypted_content = None
    msg.content_iv = None
    msg.content_tag = None
    return {"ok": True}


async def queue_bot_update(db: AsyncSession, bot_id: int, update_type: str, payload: dict):
    """Store an update for the bot to retrieve via getUpdates."""
    db.add(BotUpdate(bot_id=bot_id, update_type=update_type, payload=json.dumps(payload)))


async def get_bot_updates(db: AsyncSession, bot_id: int, limit: int = 100) -> List[dict]:
    r = await db.execute(select(BotUpdate).where(
        BotUpdate.bot_id == bot_id, BotUpdate.is_delivered == False
    ).order_by(BotUpdate.created_at.asc()).limit(limit))
    updates = []
    for u in r.scalars().all():
        updates.append({
            "update_id": u.id,
            "type": u.update_type,
            "payload": json.loads(u.payload),
        })
        u.is_delivered = True
    return updates


async def build_callback_query_payload(db: AsyncSession, user: User, message: Message, data: str) -> dict:
    bot = await get_bot_by_user_id(db, message.sender_id)
    return {
        "update_id": None,  # filled later
        "callback_query": {
            "id": secrets.token_hex(16),
            "from": {
                "id": user.id,
                "username": user.username,
                "display_name": user.display_name,
            },
            "message": await serialise_message(message, db),
            "data": data,
        }
    }


async def bot_get_chat(db: AsyncSession, bot: Bot, chat_id: int) -> Optional[dict]:
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one_or_none()
    if not chat:
        return None
    # Check bot membership
    mr = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == bot.user_id))
    if not mr.scalar_one_or_none() and chat.chat_type != ChatType.DIRECT:
        return None
    cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat_id))
    return {
        "id": chat.id,
        "type": chat.chat_type.value,
        "name": chat.name,
        "username": chat.username,
        "members_count": cnt.scalar(),
    }


async def bot_get_chat_member(db: AsyncSession, bot: Bot, chat_id: int, user_id: int) -> Optional[dict]:
    r = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == user_id))
    m = r.scalar_one_or_none()
    if not m:
        return None
    ur = await db.execute(select(User).where(User.id == user_id))
    u = ur.scalar_one_or_none()
    return {
        "user_id": user_id,
        "chat_id": chat_id,
        "role": m.role.value,
        "username": u.username if u else "",
        "display_name": u.display_name if u else "",
    }

