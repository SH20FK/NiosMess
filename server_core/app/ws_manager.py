import json, os, uuid, base64, aiofiles, httpx, shutil, asyncio
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Set
from fastapi import WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, or_, case, delete, text
from collections import defaultdict, deque
import re
from collections import Counter
from app.database import AsyncSessionLocal
from app.config import settings
from app.models.models import (
    User, Session, Chat, ChatMember, Message, MessageReaction,
    ChatType, MemberRole, MessageType, Call, CallParticipant, CallStatus,
    Badge, UserBadge, VerificationCode, MediaUploadChunk, UnreadCounter,
    Bot, BotUpdate, Post, PostReaction, PostComment, Subscription,
    UserFCMToken
)
from app.services.auth_svc import (
    validate_password, hash_password, verify_password,
    create_session, get_session_by_token, get_user_by_id, get_user_by_identifier
)
from app.services.email_svc import create_code, check_code, send_verify_email, send_2fa_email, send_email
from app.services.encryption import (
    encrypt_text, decrypt_text,
    generate_connection_key, encrypt_payload_with_key, decrypt_payload_with_key,
    encrypt_file, decrypt_file_to_bytes
)
from app.services.utils import (
    static_url, chat_link, share_link, get_user_badges, serialise_message,
    increment_unread, reset_unread, get_unread, _guess_mime
)
from app.services.bot_svc import (
    get_botcreator_id, create_bot, get_bot_by_user_id, queue_bot_update, build_callback_query_payload,
    botcreator_states, get_botcreator_state, set_botcreator_state, clear_botcreator_state
)

# ── Firebase FCM Init ────────────────────────────────────────────────────────
import firebase_admin
from firebase_admin import credentials, messaging

try:
    firebase_app = firebase_admin.get_app()
except ValueError:
    try:
        cert_path = 'niosmess-firebase-adminsdk-fbsvc-d3c2e349bd.json'
        if not os.path.exists(cert_path):
            cert_path = 'serviceAccountKey.json'
            
        if os.path.exists(cert_path):
            cred = credentials.Certificate(cert_path)
            firebase_app = firebase_admin.initialize_app(cred)
        else:
            print(f"[WARNING] Firebase config '{cert_path}' not found. Push notifications won't work.")
    except Exception as e:
        print(f"[ERROR] Failed to init Firebase: {e}")

# ── FCM Push Function ────────────────────────────────────────────────────────
def send_push(tokens: List[str], title: str, body: str, data: dict):
    if not tokens:
        return
    
    try:
        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    sound='default',
                    channel_id='niosmess_messages',
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound='default', badge=1),
                ),
            ),
        )
        response = messaging.send_multicast(message)
        print(f"[FCM] Sent {response.success_count} messages successfully. Failed: {response.failure_count}")
    except Exception as e:
        print(f"[ERROR] send_push failed: {e}")

# ── Connection registry ──────────────────────────────────────────────────────
user_connections: Dict[int, List[WebSocket]] = {}
anonymous_connections: List[WebSocket] = []
# Per-connection encryption keys: ws_id -> key_b64
connection_keys: Dict[int, str] = {}

# ── Rate limiting ────────────────────────────────────────────────────────────
# Track action timestamps per connection: ws_id -> deque of timestamps
rate_limit_tracker: Dict[int, deque] = defaultdict(lambda: deque(maxlen=100))
# Track seen message IDs to prevent replay attacks: message_id -> expiry_time
seen_message_ids: Dict[str, datetime] = {}
MESSAGE_ID_TTL = 300  # 5 minutes

# ── Security logging ─────────────────────────────────────────────────────────
suspicious_activity_log = deque(maxlen=1000)  # Keep last 1000 events

def log_suspicious_activity(ws: WebSocket, event_type: str, details: str):
    """Log suspicious activity for monitoring."""
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "ws_id": _ws_id(ws),
        "ip": ws.client.host if ws.client else "unknown",
        "event_type": event_type,
        "details": details
    }
    suspicious_activity_log.append(entry)
    print(f"[SECURITY WARNING] {event_type}: {details} from {entry['ip']}")

def validate_input(data: dict, required_fields: list, max_lengths: dict = None) -> Optional[str]:
    """Validate input data. Returns error message if invalid, None if valid."""
    if not isinstance(data, dict):
        return "Invalid data format"

    for field in required_fields:
        if field not in data:
            return f"Missing required field: {field}"

    if max_lengths:
        for field, max_len in max_lengths.items():
            if field in data and isinstance(data[field], str) and len(data[field]) > max_len:
                return f"Field '{field}' exceeds maximum length of {max_len}"

    return None

def _ws_id(ws: WebSocket) -> int:
    return id(ws)

def _check_rate_limit(ws: WebSocket, max_per_minute: int = 60) -> bool:
    """Check if connection exceeds rate limit (max actions per minute)."""
    ws_id = _ws_id(ws)
    now = datetime.now(timezone.utc)
    timestamps = rate_limit_tracker[ws_id]

    # Remove timestamps older than 1 minute
    while timestamps and (now - timestamps[0]).total_seconds() > 60:
        timestamps.popleft()

    if len(timestamps) >= max_per_minute:
        return False  # Rate limit exceeded

    timestamps.append(now)
    return True

def _check_replay_attack(message_id: Optional[str]) -> bool:
    """Check if message_id was already seen (replay attack prevention)."""
    if not message_id:
        return True  # Allow messages without ID (optional feature)

    now = datetime.now(timezone.utc)

    # Clean up expired IDs
    expired = [mid for mid, expiry in seen_message_ids.items() if now > expiry]
    for mid in expired:
        del seen_message_ids[mid]

    if message_id in seen_message_ids:
        return False  # Replay detected

    seen_message_ids[message_id] = now + timedelta(seconds=MESSAGE_ID_TTL)
    return True

async def _send(ws: WebSocket, data: dict, encrypt: bool = False):
    """Send data to WebSocket, optionally encrypting with per-connection key."""
    try:
        if encrypt and _ws_id(ws) in connection_keys:
            key_b64 = connection_keys[_ws_id(ws)]
            encrypted = encrypt_payload_with_key(data, key_b64)
            await ws.send_text(json.dumps({"encrypted": True, "data": encrypted}))
        else:
            await ws.send_text(json.dumps(data))
    except Exception:
        pass

def _decrypt_received(ws: WebSocket, raw: str, require_encryption: bool = False) -> Optional[dict]:
    """Try to decrypt incoming message if it's encrypted, otherwise parse as plain JSON."""
    try:
        data = json.loads(raw)
        # If encryption key is set for this connection, require encrypted messages
        if _ws_id(ws) in connection_keys:
            if not data.get("encrypted"):
                if require_encryption:
                    return None  # Reject unencrypted messages after key exchange
                # Allow unencrypted for backward compatibility during transition
            if data.get("encrypted"):
                key_b64 = connection_keys[_ws_id(ws)]
                return decrypt_payload_with_key(data["data"], key_b64)
        return data
    except Exception:
        return None

async def push_to_chat(db: AsyncSession, chat_id: int, payload: dict, exclude_user_id: Optional[int] = None):
    """Push a message/event to all connected members of a chat, encrypted per connection."""
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.is_banned == False))
    member_ids = [m.user_id for m in r.scalars().all()]
    for uid in member_ids:
        if uid == exclude_user_id:
            continue
        for ws in user_connections.get(uid, []):
            encrypt = _ws_id(ws) in connection_keys
            await _send(ws, payload, encrypt=encrypt)

async def _get_user(db: AsyncSession, token: str) -> Optional[User]:
    if not token:
        return None
    session = await get_session_by_token(db, token)
    if session:
        user = await get_user_by_id(db, session.user_id)
        if not user:
            return None
        if not user.is_active:
            return None
        if user.is_banned or user.is_frozen:
            return None
        session.last_active = datetime.now(timezone.utc)
        return user
    # Bot token fallback
    bot = await get_bot_by_token(db, token)
    if bot:
        user = await get_user_by_id(db, bot.user_id)
        if user and user.is_active and not user.is_banned and not user.is_frozen:
            return user
    return None

def _admin_check(pw: str):
    if pw != settings.ADMIN_PASSWORD:
        raise ValueError("Invalid admin password")

# ── Auth ───────────────────────────────────────────────────────────────────────

async def handle_register(payload: dict, db: AsyncSession):
    email = str(payload.get("email", "")).strip()
    username = str(payload.get("username", "")).strip().lower()
    display_name = str(payload.get("display_name", "")).strip()
    password = str(payload.get("password", ""))
    if not all(c.isalnum() or c in "_." for c in username):
        return {"error": "Bad chars in username"}
    if len(username) < 3 or len(username) > 32:
        return {"error": "Username must be 3-32 chars"}
    if not validate_password(password):
        return {"error": "Password needs ≥8 chars, 1 uppercase letter, 1 digit"}
    r = await db.execute(select(User).where((User.email == email) | (User.username == username)))
    if r.scalar_one_or_none():
        return {"error": "Email or username already taken"}
    user = User(email=email, username=username, display_name=display_name,
                hashed_password=hash_password(password), is_active=False)
    db.add(user); await db.flush()
    code = await create_code(db, user.id, "register", ttl=15)
    await send_verify_email(email, display_name, code)
    return {"message": "Check your email for the verification code.", "user_id": user.id}

async def handle_verify_email(payload: dict, db: AsyncSession):
    email = payload.get("email")
    code = payload.get("code")
    r = await db.execute(select(User).where(User.email == email))
    user = r.scalar_one_or_none()
    if not user:
        return {"error": "User not found"}
    if not await check_code(db, user.id, code, "register"):
        return {"error": "Invalid or expired code"}
    user.is_active = True; user.is_verified = True
    return {"message": "Email verified. You can now log in."}

async def handle_login(payload: dict, db: AsyncSession):
    identifier = payload.get("identifier")
    password = payload.get("password")
    user = await get_user_by_identifier(db, identifier)
    if not user or not verify_password(password, user.hashed_password):
        return {"error": "Invalid credentials"}
    if not user.is_active:
        return {"error": "Account not verified. Check your email."}
    if user.is_banned:
        return {"error": "Account permanently banned."}
    if user.is_frozen:
        return {"error": "Account temporarily frozen."}
    if user.two_fa_enabled:
        code = await create_code(db, user.id, "2fa", ttl=10)
        await send_2fa_email(user.email, user.display_name, code)
        return {"two_fa_required": True, "message": "2FA code sent to your email"}
    tok = await create_session(db, user.id, "", "")
    return {"access_token": tok, "token_type": "bearer", "user_id": user.id,
            "username": user.username, "display_name": user.display_name}

async def handle_verify_2fa(payload: dict, db: AsyncSession):
    identifier = payload.get("identifier")
    code = payload.get("code")
    
    # Защита от отсутствующих данных в запросе
    if not identifier:
        return {"error": "Identifier (username or email) is required"}
    if not code:
        return {"error": "Verification code is required"}
        
    user = await get_user_by_identifier(db, identifier)
    if not user:
        return {"error": "User not found"}
    if not await check_code(db, user.id, code, "2fa"):
        return {"error": "Invalid or expired 2FA code"}
    tok = await create_session(db, user.id, "", "")
    return {"access_token": tok, "token_type": "bearer", "user_id": user.id,
            "username": user.username, "display_name": user.display_name}

async def handle_logout(payload: dict, db: AsyncSession, token: str):
    if token:
        s = await get_session_by_token(db, token)
        if s:
            s.is_active = False
    return {"message": "Logged out"}

async def handle_reset_password_request(payload: dict, db: AsyncSession):
    email = payload.get("email")
    r = await db.execute(select(User).where(User.email == email))
    user = r.scalar_one_or_none()
    if user and user.is_active:
        code = await create_code(db, user.id, "reset_password", ttl=20)
        html = (f"<html><body style='font-family:sans-serif;max-width:480px;margin:auto'>"
                f"<h2 style='color:#4f46e5'>Password Reset</h2>"
                f"<p>Hi <b>{user.display_name}</b>,</p>"
                f"<p>Your password reset code:</p>"
                f"<div style='font-size:36px;font-weight:bold;letter-spacing:8px;"
                f"color:#ef4444;padding:16px;background:#fef2f2;border-radius:8px;"
                f"text-align:center'>{code}</div>"
                f"<p style='color:#6b7280'>Expires in 20 minutes.</p></body></html>")
        await send_email(email, "Messenger — Password Reset", html)
    return {"message": "If an account with that email exists, a reset code has been sent."}

async def handle_reset_password_confirm(payload: dict, db: AsyncSession):
    new_password = payload.get("new_password")
    if not validate_password(new_password):
        return {"error": "New password needs ≥8 chars, 1 uppercase, 1 digit"}
    r = await db.execute(select(User).where(User.email == payload.get("email")))
    user = r.scalar_one_or_none()
    if not user:
        return {"error": "User not found"}
    if not await check_code(db, user.id, payload.get("code"), "reset_password"):
        return {"error": "Invalid or expired reset code"}
    user.hashed_password = hash_password(new_password)
    sr = await db.execute(select(Session).where(Session.user_id == user.id, Session.is_active == True))
    for s in sr.scalars().all():
        s.is_active = False
    return {"message": "Password reset successfully. All sessions have been revoked. Please log in again."}

# ── Profile ────────────────────────────────────────────────────────────────────

async def _user_summary(db, u: User) -> dict:
    badges = await get_user_badges(db, u.id)
    # Считаем количество подписчиков пользователя
    sub_count_q = await db.execute(select(func.count(Subscription.id)).where(Subscription.followed_id == u.id))
    sub_count = sub_count_q.scalar() or 0
    return {"id": u.id, "username": u.username, "display_name": u.display_name,
            "bio": u.bio or "", "avatar_url": static_url(u.avatar_path), "badges": badges,
            "subscribers_count": sub_count}

async def handle_me_info(payload: dict, db: AsyncSession, user: User):
    d = await _user_summary(db, user)
    d["two_fa_enabled"] = user.two_fa_enabled
    d["spam_block"] = user.spam_block
    return d

async def handle_get_profile(payload: dict, db: AsyncSession, user: User):
    username = str(payload.get("username", "")).lower()
    user_id = payload.get("user_id")
    if user_id:
        r = await db.execute(select(User).where(User.id == user_id))
    else:
        r = await db.execute(select(User).where(User.username == username))
    u = r.scalar_one_or_none()
    if not u or u.is_banned:
        return {"error": "User not found"}
    return await _user_summary(db, u)

async def handle_get_profile_encrypted(payload: dict, db: AsyncSession, user: User):
    import json as _json
    username = str(payload.get("username", "")).lower()
    r = await db.execute(select(User).where(User.username == username))
    u = r.scalar_one_or_none()
    if not u:
        return {"error": "User not found"}
    enc = encrypt_text(_json.dumps(await _user_summary(db, u)))
    return {"encrypted_data": enc["ciphertext"], "iv": enc["iv"], "tag": enc["tag"]}

async def handle_update_profile(payload: dict, db: AsyncSession, user: User):
    r = await db.execute(select(User).where(User.id == user.id))
    u = r.scalar_one()
    if payload.get("display_name"):
        u.display_name = payload.get("display_name")
    if "bio" in payload:
        u.bio = payload.get("bio")
    if payload.get("username"):
        uname = payload.get("username").lower()
        ex = await db.execute(select(User).where(User.username == uname, User.id != u.id))
        if ex.scalar_one_or_none():
            return {"error": "Username taken"}
        u.username = uname
    return await _user_summary(db, u)

async def handle_upload_avatar(payload: dict, db: AsyncSession, user: User):
    b64data = payload.get("data_base64")
    filename = payload.get("filename", "avatar.jpg")
    if not b64data:
        return {"error": "No data"}
    try:
        data = base64.b64decode(b64data)
    except Exception:
        return {"error": "Invalid base64"}
    ext = filename.rsplit(".", 1)[-1] if "." in filename else "jpg"
    fname = f"avatars/{user.id}_{uuid.uuid4().hex}.{ext}"
    fpath = os.path.join(settings.UPLOAD_DIR, fname)
    os.makedirs(os.path.dirname(fpath), exist_ok=True)
    async with aiofiles.open(fpath, "wb") as f:
        await f.write(data)
    r = await db.execute(select(User).where(User.id == user.id))
    u = r.scalar_one(); u.avatar_path = fname
    return {"avatar_url": static_url(fname)}

async def handle_toggle_2fa(payload: dict, db: AsyncSession, user: User):
    enabled = payload.get("enabled")
    password = payload.get("password")
    r = await db.execute(select(User).where(User.id == user.id))
    u = r.scalar_one()
    if not verify_password(password, u.hashed_password):
        return {"error": "Wrong password"}
    u.two_fa_enabled = enabled
    return {"two_fa_enabled": u.two_fa_enabled}

async def handle_list_sessions(payload: dict, db: AsyncSession, user: User):
    r = await db.execute(select(Session).where(Session.user_id == user.id, Session.is_active == True))
    sessions = r.scalars().all()
    return [{"id": s.id, "device_info": s.device_info, "ip_address": s.ip_address,
             "created_at": s.created_at.isoformat() if s.created_at else None,
             "last_active": s.last_active.isoformat() if s.last_active else None} for s in sessions]

async def handle_kick_session(payload: dict, db: AsyncSession, user: User):
    session_id = payload.get("session_id")
    r = await db.execute(select(Session).where(Session.id == session_id, Session.user_id == user.id))
    s = r.scalar_one_or_none()
    if not s:
        return {"error": "Session not found"}
    s.is_active = False
    return {"message": "Session revoked"}

async def handle_register_fcm_token(payload: dict, db: AsyncSession, user: User):
    fcm_token = payload.get("fcm_token")
    platform = payload.get("platform", "unknown")
    
    if not fcm_token:
        return {"error": "fcm_token is required"}
        
    r = await db.execute(select(UserFCMToken).where(UserFCMToken.fcm_token == fcm_token))
    t = r.scalar_one_or_none()
    
    now = datetime.now(timezone.utc)
    if t:
        t.user_id = user.id
        t.platform = platform
        t.updated_at = now
    else:
        db.add(UserFCMToken(
            user_id=user.id,
            fcm_token=fcm_token,
            platform=platform,
            updated_at=now
        ))
        
    return {"message": "FCM token registered successfully"}

# ── Subscriptions ─────────────────────────────────────────────────────────────

async def handle_follow_user(payload: dict, db: AsyncSession, user: User):
    target_id = payload.get("user_id")
    if target_id == user.id:
        return {"error": "Cannot follow yourself"}
    
    target = await db.execute(select(User).where(User.id == target_id))
    if not target.scalar_one_or_none():
        return {"error": "User not found"}
        
    ex = await db.execute(select(Subscription).where(
        Subscription.follower_id == user.id, Subscription.followed_id == target_id))
    if ex.scalar_one_or_none():
        return {"message": "Already following"}
        
    db.add(Subscription(follower_id=user.id, followed_id=target_id))
    await db.flush()
    return {"message": "Followed successfully", "user_id": target_id}

async def handle_unfollow_user(payload: dict, db: AsyncSession, user: User):
    target_id = payload.get("user_id")
    r = await db.execute(select(Subscription).where(
        Subscription.follower_id == user.id, Subscription.followed_id == target_id))
    sub = r.scalar_one_or_none()
    if not sub:
        return {"error": "Not following this user"}
        
    await db.delete(sub)
    await db.flush()
    return {"message": "Unfollowed successfully", "user_id": target_id}

# ── E2EE (End-to-End Encryption) ──────────────────────────────────────────────

async def handle_set_public_key(payload: dict, db: AsyncSession, user: User):
    """Store user's public key for E2EE. Client generates keypair, sends public key here."""
    public_key = payload.get("public_key")
    if not public_key or len(public_key) > 10000:
        return {"error": "Invalid public key"}

    r = await db.execute(select(User).where(User.id == user.id))
    u = r.scalar_one()
    u.public_key = public_key
    return {"message": "Public key set successfully"}

async def handle_get_public_key(payload: dict, db: AsyncSession, user: User):
    """Get another user's public key for encrypting messages to them."""
    user_id = payload.get("user_id")
    r = await db.execute(select(User).where(User.id == user_id))
    target = r.scalar_one_or_none()
    if not target:
        return {"error": "User not found"}

    return {"user_id": target.id, "username": target.username, "public_key": target.public_key}

async def handle_erase_secret(payload: dict, db: AsyncSession):
    """
    Физически удаляет все секретные чаты, связанные с конкретным public_key,
    а также все файлы, отправленные внутри этих чатов, со всей файловой системы.
    """
    public_key = payload.get("public_key")
    if not public_key:
        return {"error": "Missing public_key"}

    # 1. Находим все секретные чаты по паблик кею (как для user1, так и для user2)
    chats_query = await db.execute(
        select(Chat).where(
            Chat.is_secret == True,
            or_(
                Chat.user1_public_key == public_key,
                Chat.user2_public_key == public_key
            )
        )
    )
    secret_chats = chats_query.scalars().all()
    
    deleted_chats_count = 0
    deleted_files_count = 0

    for chat in secret_chats:
        # 2. Вытаскиваем сообщения чтобы снести файлы и сами записи
        messages_query = await db.execute(
            select(Message).where(Message.chat_id == chat.id)
        )
        messages = messages_query.scalars().all()
        msg_ids = [m.id for m in messages]

        # Если есть сообщения, сначала удаляем связанные реакции (если есть)
        if msg_ids:
            reactions_query = await db.execute(
                select(MessageReaction).where(MessageReaction.message_id.in_(msg_ids))
            )
            for reaction in reactions_query.scalars().all():
                await db.delete(reaction)

        for msg in messages:
            # Сносим файлы с диска нахуй
            if getattr(msg, "media_path", None):
                full_path = os.path.join(settings.UPLOAD_DIR, msg.media_path)
                if os.path.exists(full_path):
                    try:
                        os.remove(full_path)
                        deleted_files_count += 1
                    except Exception as e:
                        print(f"[ERROR] Failed to delete file {full_path}: {e}")
            
            await db.delete(msg)

        # 3. Удаляем участников чата
        members_query = await db.execute(
            select(ChatMember).where(ChatMember.chat_id == chat.id)
        )
        for member in members_query.scalars().all():
            await db.delete(member)

        # 4. Удаляем счетчики непрочитанных сообщений
        unread_query = await db.execute(
            select(UnreadCounter).where(UnreadCounter.chat_id == chat.id)
        )
        for uc in unread_query.scalars().all():
            await db.delete(uc)

        # 5. Сносим сам чат
        await db.delete(chat)
        deleted_chats_count += 1

    return {
        "status": "success",
        "deleted_chats_count": deleted_chats_count,
        "deleted_files_count": deleted_files_count,
        "message": "All secret chats and associated files tied to the public key have been physically erased."
    }

# ── Chats ─────────────────────────────────────────────────────────────────────

async def assert_admin(db, chat_id, user_id):
    r = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == user_id))
    m = r.scalar_one_or_none()
    if not m or m.role not in (MemberRole.OWNER, MemberRole.ADMIN):
        raise ValueError("Admin access required")
    return m

async def assert_member(db, chat_id, user_id):
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == user_id, ChatMember.is_banned == False))
    m = r.scalar_one_or_none()
    if not m:
        raise ValueError("Not a member of this chat")
    return m

async def _last_msg_out(db, chat_id):
    r = await db.execute(select(Message).where(
        Message.chat_id == chat_id, Message.is_deleted == False
    ).order_by(Message.sent_at.desc()).limit(1))
    msg = r.scalar_one_or_none()
    if not msg:
        return None
    return await serialise_message(msg, db)

async def handle_list_chats(payload: dict, db: AsyncSession, user: User):
    client_public_key = payload.get("public_key")  # Client's current device public key

    r = await db.execute(select(ChatMember).where(
        ChatMember.user_id == user.id, ChatMember.is_banned == False))
    result = []
    for m in r.scalars().all():
        cr = await db.execute(select(Chat).where(Chat.id == m.chat_id))
        chat = cr.scalar_one_or_none()
        if not chat or chat.is_banned:
            continue

        # Filter secret chats by device public key
        if chat.is_secret and client_public_key:
            # Check if this device's public key matches the one used to create the secret chat
            if chat.user1_id == user.id:
                if chat.user1_public_key != client_public_key:
                    continue  # Skip - this secret chat belongs to another device
            elif chat.user2_id == user.id:
                if chat.user2_public_key != client_public_key:
                    continue  # Skip - this secret chat belongs to another device
        elif chat.is_secret and not client_public_key:
            # No public key provided - skip all secret chats
            continue

        cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
        name = chat.name
        avatar = static_url(chat.avatar_path)
        partner_badges = []
        with_user_data = None

        if chat.chat_type == ChatType.DIRECT:
            other_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
            ur = await db.execute(select(User).where(User.id == other_id))
            other = ur.scalar_one_or_none()
            if other:
                name = other.display_name
                avatar = avatar or static_url(other.avatar_path)
                if not avatar or "None" in avatar:
                    avatar = "https://ni-os.ru/static/avatars/default.jpg"
                partner_badges = await get_user_badges(db, other.id)

                # For secret chats, include partner info with public key
                if chat.is_secret:
                    with_user_data = {
                        "id": other.id,
                        "username": other.username,
                        "display_name": other.display_name,
                        "avatar_url": avatar,
                        "public_key": other.public_key  # Partner's current public key
                    }

        chat_data = {
            "id": chat.id, "chat_type": chat.chat_type.value, "name": name,
            "username": chat.username, "avatar_url": avatar,
            "invite_link": chat_link(chat.username), "share_link": share_link(chat.username),
            "last_message": await _last_msg_out(db, chat.id),
            "unread_count": await get_unread(db, chat.id, user.id),
            "members_count": cnt.scalar(),
            "partner_badges": partner_badges,
            "is_secret": chat.is_secret,
        }

        if with_user_data:
            chat_data["with_user"] = with_user_data

        result.append(chat_data)

    result.sort(key=lambda x: (x["last_message"] or {}).get("sent_at", ""), reverse=True)
    return result

async def handle_open_direct(payload: dict, db: AsyncSession, user: User):
    username = str(payload.get("username", "")).lower()
    is_secret = payload.get("is_secret", False)  # Flag for secret chat
    client_public_key = payload.get("public_key")  # Client's device public key

    ur = await db.execute(select(User).where(User.username == username))
    other = ur.scalar_one_or_none()
    if not other:
        return {"error": "User not found"}
    if other.id == user.id:
        return {"error": "Cannot DM yourself"}
    if user.spam_block:
        return {"error": "Spam-blocked accounts cannot initiate DMs."}

    # For secret chats, check that both users have public keys
    if is_secret:
        if not client_public_key:
            return {"error": "Client public_key required for secret chats"}
        if not other.public_key:
            return {"error": "Other user must have a public key set for secret chats"}

    u1, u2 = sorted([user.id, other.id])

    # For secret chats, try to find existing chat with matching public keys
    if is_secret:
        # Check if a secret chat already exists for this device pair
        r = await db.execute(select(Chat).where(
            Chat.chat_type == ChatType.DIRECT,
            Chat.user1_id == u1,
            Chat.user2_id == u2,
            Chat.is_secret == True
        ))
        existing_chats = r.scalars().all()

        # Find chat where client's public key matches
        chat = None
        for existing_chat in existing_chats:
            if user.id == existing_chat.user1_id and existing_chat.user1_public_key == client_public_key:
                chat = existing_chat
                break
            elif user.id == existing_chat.user2_id and existing_chat.user2_public_key == client_public_key:
                chat = existing_chat
                break

        if not chat:
            # Create new secret chat with device-specific keys
            chat = Chat(
                chat_type=ChatType.DIRECT,
                user1_id=u1,
                user2_id=u2,
                is_secret=True
            )

            # Save public keys based on which user is which
            if user.id == u1:
                chat.user1_public_key = client_public_key
                chat.user2_public_key = other.public_key  # Current key from other user's profile
            else:
                chat.user1_public_key = other.public_key
                chat.user2_public_key = client_public_key

            db.add(chat)
            await db.flush()

            # Add both users as members
            for uid in [u1, u2]:
                db.add(ChatMember(chat_id=chat.id, user_id=uid, role=MemberRole.MEMBER))
            await db.flush()
    else:
        # Regular (non-secret) direct chat
        r = await db.execute(select(Chat).where(
            Chat.chat_type == ChatType.DIRECT,
            Chat.user1_id == u1,
            Chat.user2_id == u2,
            Chat.is_secret == False
        ))
        chat = r.scalar_one_or_none()

        if not chat:
            chat = Chat(chat_type=ChatType.DIRECT, user1_id=u1, user2_id=u2, is_secret=False)
            db.add(chat)
            await db.flush()

            for uid in [u1, u2]:
                db.add(ChatMember(chat_id=chat.id, user_id=uid, role=MemberRole.MEMBER))
            await db.flush()

    other_summary = await _user_summary(db, other)
    if is_secret:
        # For secret chats, return the partner's current public key from their profile
        other_summary["public_key"] = other.public_key

    return {"chat_id": chat.id, "chat_type": "direct", "is_secret": chat.is_secret,
            "with_user": other_summary}

async def handle_create_group(payload: dict, db: AsyncSession, user: User):
    if user.spam_block:
        return {"error": "Spam-blocked accounts cannot create public chats."}
    name = payload.get("name")
    chat_type = payload.get("chat_type")
    description = payload.get("description")
    username = payload.get("username")
    comments_enabled = payload.get("comments_enabled", True)
    if chat_type not in ("group", "channel"):
        return {"error": "group or channel only"}
    slug = (username or uuid.uuid4().hex[:12]).lower()
    if not all(c.isalnum() or c in "_-" for c in slug):
        return {"error": "Username may contain letters, digits, underscores, hyphens"}
    r = await db.execute(select(Chat).where(Chat.username == slug))
    if r.scalar_one_or_none():
        return {"error": "Username/slug already taken"}
    ctype = ChatType.GROUP if chat_type == "group" else ChatType.CHANNEL
    chat = Chat(chat_type=ctype, name=name, description=description,
                username=slug, created_by=user.id, comments_enabled=comments_enabled)
    db.add(chat); await db.flush()
    if ctype == ChatType.CHANNEL and comments_enabled:
        comments_chat = Chat(chat_type=ChatType.GROUP, name=f"{name} — Comments", created_by=user.id)
        db.add(comments_chat); await db.flush()
        chat.comments_chat_id = comments_chat.id
        db.add(ChatMember(chat_id=comments_chat.id, user_id=user.id, role=MemberRole.OWNER))
    db.add(ChatMember(chat_id=chat.id, user_id=user.id, role=MemberRole.OWNER))
    return {"chat_id": chat.id, "name": chat.name, "username": slug,
            "invite_link": chat_link(slug), "share_link": share_link(slug),
            "comments_chat_id": chat.comments_chat_id}

async def handle_get_chat(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    await assert_member(db, chat_id, user.id)
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one_or_none()
    if not chat:
        return {"error": "Chat not found"}
    if chat.is_banned:
        return {"error": "This chat has been banned by admin"}
    cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat_id))
    name = chat.name
    partner = None
    if chat.chat_type == ChatType.DIRECT:
        other_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
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
            "invite_link": chat_link(chat.username), "share_link": share_link(chat.username),
            "unread_count": await get_unread(db, chat_id, user.id),
            "last_message": await _last_msg_out(db, chat_id),
            "partner": partner}

async def handle_get_members(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    await assert_member(db, chat_id, user.id)
    r = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id))
    result = []
    for m in r.scalars().all():
        ur = await db.execute(select(User).where(User.id == m.user_id))
        u = ur.scalar_one_or_none()
        if not u:
            continue
        badges = await get_user_badges(db, u.id)
        result.append({"user_id": u.id, "username": u.username, "display_name": u.display_name,
                        "avatar_url": static_url(u.avatar_path), "badges": badges,
                        "role": m.role.value, "is_muted": m.is_muted, "is_banned": m.is_banned})
    return result

async def handle_update_chat(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    await assert_admin(db, chat_id, user.id)
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one_or_none()
    if not chat:
        return {"error": "Chat not found"}
    if payload.get("name"):
        chat.name = payload.get("name")
    if "description" in payload:
        chat.description = payload.get("description")
    if "comments_enabled" in payload:
        chat.comments_enabled = payload.get("comments_enabled")
    if payload.get("username"):
        slug = payload.get("username").lower()
        ex = await db.execute(select(Chat).where(Chat.username == slug, Chat.id != chat_id))
        if ex.scalar_one_or_none():
            return {"error": "Username taken"}
        chat.username = slug
    return {"message": "Updated", "invite_link": chat_link(chat.username), "share_link": share_link(chat.username)}

async def handle_chat_avatar_upload(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    b64data = payload.get("data_base64")
    filename = payload.get("filename", "avatar.jpg")
    await assert_admin(db, chat_id, user.id)
    if not b64data:
        return {"error": "No data"}
    try:
        data = base64.b64decode(b64data)
    except Exception:
        return {"error": "Invalid base64"}
    ext = filename.rsplit(".", 1)[-1] if "." in filename else "jpg"
    fname = f"avatars/chat_{chat_id}_{uuid.uuid4().hex}.{ext}"
    fpath = os.path.join(settings.UPLOAD_DIR, fname)
    os.makedirs(os.path.dirname(fpath), exist_ok=True)
    async with aiofiles.open(fpath, "wb") as f:
        await f.write(data)
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one(); chat.avatar_path = fname
    return {"avatar_url": static_url(fname)}

async def handle_invite_user(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    user_id = payload.get("user_id")
    await assert_admin(db, chat_id, user.id)
    ur = await db.execute(select(User).where(User.id == user_id))
    target = ur.scalar_one_or_none()
    if not target:
        return {"error": "User not found"}
    if target.spam_block:
        return {"error": "User has a spam-block."}
    ex = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == user_id))
    if ex.scalar_one_or_none():
        return {"error": "User already a member"}
    db.add(ChatMember(chat_id=chat_id, user_id=user_id, role=MemberRole.MEMBER))
    return {"message": "User invited"}

async def handle_ban_member(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    user_id = payload.get("user_id")
    ban = payload.get("ban", True)
    await assert_admin(db, chat_id, user.id)
    r = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == user_id))
    m = r.scalar_one_or_none()
    if not m:
        return {"error": "Member not found"}
    m.is_banned = ban
    return {"message": f"User {'banned' if ban else 'unbanned'} from chat"}

async def handle_mute_member(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    user_id = payload.get("user_id")
    mute = payload.get("mute", True)
    await assert_admin(db, chat_id, user.id)
    r = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == user_id))
    m = r.scalar_one_or_none()
    if not m:
        return {"error": "Member not found"}
    m.is_muted = mute
    return {"message": f"User {'muted' if mute else 'unmuted'}"}

async def handle_promote_member(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    user_id = payload.get("user_id")
    role = payload.get("role")
    await assert_admin(db, chat_id, user.id)
    if role not in ("admin", "member"):
        return {"error": "Role must be admin or member"}
    r = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == user_id))
    m = r.scalar_one_or_none()
    if not m:
        return {"error": "Member not found"}
    m.role = MemberRole.ADMIN if role == "admin" else MemberRole.MEMBER
    return {"message": f"Role set to {role}"}

async def handle_leave_chat(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    r = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == user.id))
    m = r.scalar_one_or_none()
    if not m:
        return {"error": "Not in this chat"}
    await db.delete(m)
    return {"message": "Left chat"}

async def handle_mark_read(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    await assert_member(db, chat_id, user.id)
    await reset_unread(db, chat_id, user.id)
    return {"message": "Marked as read", "unread_count": 0}

# ── Messages ───────────────────────────────────────────────────────────────────

async def _can_send(db, chat_id, user_id):
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == user_id,
        ChatMember.is_banned == False, ChatMember.is_muted == False))
    m = r.scalar_one_or_none()
    if not m:
        raise ValueError("Cannot post here (not member, banned, or muted)")
    cr = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = cr.scalar_one_or_none()
    if chat and chat.is_banned:
        raise ValueError("Chat is banned by admins")
    if chat and chat.chat_type == ChatType.CHANNEL and m.role == MemberRole.MEMBER:
        raise ValueError("Only admins can post in channels")
    return m

async def _push_to_user(user_id: int, payload: dict):
    """Push a message/event directly to a specific user by id."""
    for ws in user_connections.get(user_id, []):
        encrypt = _ws_id(ws) in connection_keys
        await _send(ws, payload, encrypt=encrypt)

async def _maybe_botcreator_reply(db: AsyncSession, user: User, chat_id: int, user_msg: Message, text: str):
    """Auto-reply from BotCreator when a user DMs it."""
    bc_id = get_botcreator_id()
    if not bc_id:
        return
    cr = await db.execute(select(Chat).where(Chat.id == chat_id, Chat.chat_type == ChatType.DIRECT))
    chat = cr.scalar_one_or_none()
    if not chat:
        return
    other_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
    if other_id != bc_id:
        return

    # Задержка ответа на 0.1 сек
    await asyncio.sleep(0.1)

    t = text.strip().lower()
    state = get_botcreator_state(user.id)
    reply_text = ""
    reply_markup = None

    if state and state.get("step") == "name":
        # User sent name for new bot
        if not text.strip():
            reply_text = "Пожалуйста, введите корректное имя для бота."
        else:
            state["name"] = text.strip()
            state["step"] = "username"
            reply_text = "Отлично. Теперь выберите username для бота. Он должен оканчиваться на *bot*. Например: NiosBot"
            set_botcreator_state(user.id, state)
    elif state and state.get("step") == "username":
        uname = text.strip()
        if not uname.endswith("bot") and not uname.endswith("_bot"):
            reply_text = "Username должен оканчиваться на *bot*. Попробуйте ещё раз."
        else:
            res = await create_bot(db, user.id, state["name"], uname)
            if res.get("error"):
                reply_text = f"❌ Ошибка: {res['error']}\n\nПопробуйте другой username."
            else:
                reply_text = (f"✅ Бот создан!\n\nИмя: {res['name']}\nUsername: @{res['username']}\n"
                              f"Token:\n<code>{res['token']}</code>\n\n"
                              f"Используйте этот токен для подключения бота через WebSocket или HTTP API.")
                clear_botcreator_state(user.id)
    elif t.startswith("/start") or t == "start":
        await asyncio.sleep(0.5)
        reply_text = "BotCreator — управление ботами\n\nВыберите действие:"
        reply_markup = {"inline_keyboard": [
            [{"text": "Создать бота", "callback_data": "newbot"}],
            [{"text": "Мои боты", "callback_data": "mybots"}],
            [{"text": "Помощь", "callback_data": "help"}],
        ]}
    elif t == "/newbot" or t == "newbot":
        await asyncio.sleep(0.5)
        set_botcreator_state(user.id, {"step": "name"})
        reply_text = "Как вы хотите назвать бота?"
    elif t.startswith("/mybots") or t == "mybots":
        await asyncio.sleep(0.5)
        bots = await db.execute(select(Bot).join(User, Bot.user_id == User.id))
        rows = bots.scalars().all()
        if not rows:
            reply_text = "У вас пока нет ботов."
        else:
            reply_text = "Ваши боты:\n" + "\n".join([f"• @{b.username} (token: {b.token[:8]}...)" for b in rows])
        reply_markup = None
    elif t.startswith("/help") or t == "help":
        await asyncio.sleep(0.5)
        reply_text = ("Команды BotCreator:\n"
                      "/newbot — создать бота (интерактивно)\n"
                      "/mybots — список ботов\n"
                      "/token <username> — получить токен\n"
                      "/deletebot <username> — удалить бота")
        reply_markup = None
    elif t.startswith("/token "):
        uname = text.split(None, 1)[1].strip().lower()
        br = await db.execute(select(Bot).where(Bot.username == uname))
        bot = br.scalar_one_or_none()
        if bot:
            reply_text = f"Token для @{bot.username}:\n*{bot.token}*"
        else:
            reply_text = "Бот не найден."
        reply_markup = None
    elif t.startswith("/deletebot "):
        uname = text.split(None, 1)[1].strip().lower()
        br = await db.execute(select(Bot).where(Bot.username == uname))
        bot = br.scalar_one_or_none()
        if bot:
            u = await db.execute(select(User).where(User.id == bot.user_id))
            user_row = u.scalar_one_or_none()
            if user_row:
                await db.delete(user_row)
            await db.delete(bot)
            reply_text = f"Бот @{uname} удалён."
        else:
            reply_text = "Бот не найден."
        reply_markup = None
    else:
        await asyncio.sleep(0.5)
        reply_text = "Привет! Я BotCreator. Отправьте /start для меню или /help для списка команд."
        reply_markup = {"inline_keyboard": [
            [{"text": "Создать бота", "callback_data": "newbot"}],
            [{"text": "Мои боты", "callback_data": "mybots"}],
        ]}

    # Send BotCreator reply
    await asyncio.sleep(0.2)
    bot_msg = Message(chat_id=chat_id, sender_id=bc_id, msg_type=MessageType.TEXT)
    enc = encrypt_text(reply_text)
    bot_msg.encrypted_content = enc["ciphertext"]
    bot_msg.content_iv = enc["iv"]
    bot_msg.content_tag = enc["tag"]
    if reply_markup:
        bot_msg.reply_markup = json.dumps(reply_markup)
    db.add(bot_msg); await db.flush()
    await increment_unread(db, chat_id, bc_id, bot_msg.id)
    result = await serialise_message(bot_msg, db)
    await push_to_chat(db, chat_id, {"action": "new_message", "payload": result}, exclude_user_id=bc_id)

async def handle_callback_query(payload: dict, db: AsyncSession, user: User):
    """Handle inline keyboard button press from user."""
    import inspect  # Для безопасного определения асинхронных функций

    # 1. Безопасное приведение типов (клиент может передать ID как строку или число)
    raw_message_id = payload.get("message_id")
    raw_chat_id = payload.get("chat_id")
    data = payload.get("data")
    
    try:
        message_id = int(raw_message_id) if raw_message_id is not None else None
        chat_id = int(raw_chat_id) if raw_chat_id is not None else None
    except (ValueError, TypeError):
        return {"error": "Invalid format for message_id or chat_id"}

    if not message_id or not data:
        return {"error": "message_id and data required"}

    try:
        # Находим сообщение
        mr = await db.execute(select(Message).where(Message.id == message_id, Message.chat_id == chat_id))
        msg = mr.scalar_one_or_none()
        if not msg or not msg.reply_markup:
            return {"error": "Message or inline keyboard not found"}
            
        # 2. Многоуровневый поиск бота во избежание путаницы ID / User_ID
        bot = await get_bot_by_user_id(db, msg.sender_id)
        if not bot:
            # Резервный поиск 1: по user_id напрямую в таблице Bot
            bot_r = await db.execute(select(Bot).where(Bot.user_id == msg.sender_id))
            bot = bot_r.scalar_one_or_none()
        if not bot:
            # Резервный поиск 2: на случай, если msg.sender_id хранит Bot.id
            bot_r = await db.execute(select(Bot).where(Bot.id == msg.sender_id))
            bot = bot_r.scalar_one_or_none()

        if not bot:
            # Если это встроенный BotCreator
            if msg.sender_id == get_botcreator_id():
                await asyncio.sleep(0.5)
                if data == "newbot":
                    set_botcreator_state(user.id, {"step": "name"})
                    reply_text = "Как вы хотите назвать бота?"
                elif data == "mybots":
                    reply_text = "/mybots"
                elif data == "help":
                    reply_text = "/help"
                else:
                    reply_text = "Неизвестная команда."
                bc_id = get_botcreator_id()
                bot_msg = Message(chat_id=chat_id, sender_id=bc_id, msg_type=MessageType.TEXT)
                enc = encrypt_text(reply_text)
                bot_msg.encrypted_content = enc["ciphertext"]
                bot_msg.content_iv = enc["iv"]
                bot_msg.content_tag = enc["tag"]
                db.add(bot_msg)
                await db.flush()
                await increment_unread(db, chat_id, bc_id, bot_msg.id)
                result = await serialise_message(bot_msg, db)
                await push_to_chat(db, chat_id, {"action": "new_message", "payload": result}, exclude_user_id=bc_id)
                return {"ok": True}
                
            return {"error": "Message not from a bot"}

        # 3. Безопасный вызов build_callback_query_payload
        # Если функция в bot_svc синхронная, вызываем её напрямую, иначе — через await
        if inspect.iscoroutinefunction(build_callback_query_payload):
            update_payload = await build_callback_query_payload(db, user, msg, data)
        else:
            update_payload = build_callback_query_payload(db, user, msg, data)

        # Сохраняем обновление в очередь обновлений бота и дублируем по сокету
        await queue_bot_update(db, bot.id, "callback_query", update_payload)
        await _push_to_user(bot.user_id, {"action": "callback_query", "payload": update_payload})
        
        return {"ok": True, "description": "Callback query sent to bot"}
        
    except Exception as e:
        # Логируем ошибку, чтобы она не пропала при откате транзакции
        print(f"[CRITICAL ERROR] handle_callback_query failed: {e}")
        return {"error": f"Internal helper failure: {str(e)}"}

async def _require_member(db, chat_id, user_id):
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == user_id, ChatMember.is_banned == False))
    if not r.scalar_one_or_none():
        raise ValueError("Not a member")

async def handle_send_message(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    content = payload.get("content")
    e2ee_content = payload.get("e2ee_content")  # Client-side encrypted content
    reply_to_id = payload.get("reply_to_id")
    upload_id = payload.get("upload_id")
    reply_markup = payload.get("reply_markup")
    await _can_send(db, chat_id, user.id)

    # Check if this is a secret chat
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one_or_none()
    if not chat:
        return {"error": "Chat not found"}

    is_secret = chat.is_secret

    if not content and not e2ee_content and not upload_id:
        return {"error": "Message must have content or media"}

    msg = Message(chat_id=chat_id, sender_id=user.id, reply_to_id=reply_to_id, msg_type=MessageType.TEXT)

    # For secret chats, use E2EE
    if is_secret and e2ee_content:
        msg.e2ee_content = e2ee_content
        msg.is_e2ee = True
    elif content:
        # Regular server-side encryption
        enc = encrypt_text(content)
        msg.encrypted_content = enc["ciphertext"]
        msg.content_iv = enc["iv"]
        msg.content_tag = enc["tag"]

    if upload_id:
        r = await db.execute(select(MediaUploadChunk).where(
            MediaUploadChunk.upload_id == upload_id, MediaUploadChunk.user_id == user.id))
        up = r.scalar_one_or_none()
        if not up:
            return {"error": "Upload session not found"}
        if up.received_chunks < up.total_chunks:
            return {"error": f"Upload incomplete ({up.received_chunks}/{up.total_chunks} chunks)"}

        # Encrypt the uploaded file
        encrypted_path = up.temp_path + ".enc"
        enc_meta = encrypt_file(up.temp_path, encrypted_path)

        # Remove original unencrypted file
        try:
            os.remove(up.temp_path)
        except Exception:
            pass

        # ИЗМЕНЕНИЕ: В БД сохраняем путь с ОРИГИНАЛЬНЫМ расширением (.jpg, .mp4), а не .enc!
        # Так фронтенд сразу поймет, что это картинка/видео
        rel_path = up.temp_path.replace(settings.UPLOAD_DIR + "/", "").replace(settings.UPLOAD_DIR + "\\", "")
        msg.media_path = rel_path 
        msg.media_name = up.filename
        msg.media_type = _guess_mime(up.filename)
        msg.media_iv = enc_meta["iv"]
        msg.media_tag = enc_meta["tag"]
        try:
            msg.media_size = os.path.getsize(encrypted_path)
        except Exception:
            pass
        subtype_map = {"voice": MessageType.VOICE, "circle": MessageType.CIRCLE}
        msg.msg_type = subtype_map.get(up.media_subtype, MessageType.MEDIA)
        await db.delete(up)
    if reply_markup:
        import json
        msg.reply_markup = json.dumps(reply_markup)
    db.add(msg); await db.flush()
    await increment_unread(db, chat_id, user.id, msg.id)
    result = await serialise_message(msg, db)
    
    # Push to other members via WebSocket
    await push_to_chat(db, chat_id, {"action": "new_message", "payload": result}, exclude_user_id=user.id)

    # ── НАЧАЛО: FCM Push-уведомления ──────────────────────────────────────────────
    try:
        chat_members_req = await db.execute(select(ChatMember).where(
            ChatMember.chat_id == chat_id,
            ChatMember.is_banned == False
        ))
        chat_members = chat_members_req.scalars().all()
        
        push_uids = []
        for m in chat_members:
            if m.user_id == user.id:
                continue
            if m.is_muted:
                continue
            push_uids.append(m.user_id)
                
        if push_uids:
            tokens_req = await db.execute(select(UserFCMToken.fcm_token).where(UserFCMToken.user_id.in_(push_uids)))
            tokens = list(set([row[0] for row in tokens_req.all() if row[0]]))
            
            if tokens:
                title = chat.name if (chat.name and chat.chat_type != ChatType.DIRECT) else user.display_name
                
                if is_secret or e2ee_content:
                    body_text = "New secret message"
                elif content:
                    body_text = content[:100] + ("..." if len(content) > 100 else "")
                elif upload_id:
                    body_text = "Sent a media file"
                else:
                    body_text = "New message"
                
                data_payload = {
                    'chat_id': str(chat_id),
                    'message_id': str(msg.id),
                    'sender_name': user.display_name,
                    'type': 'new_message'
                }
                
                # Отправляем пакетами по 500 из-за лимита Firebase Multicast
                chunked_tokens = [tokens[i:i+500] for i in range(0, len(tokens), 500)]
                for chunk in chunked_tokens:
                    asyncio.create_task(asyncio.to_thread(send_push, chunk, title, body_text, data_payload))
    except Exception as e:
        print(f"[ERROR] FCM Push preparation failed: {e}")
    # ── КОНЕЦ: FCM Push-уведомления ───────────────────────────────────────────────

    # ── НАЧАЛО: ДОСТАВКА СООБЩЕНИЙ БОТАМ ЧЕРЕЗ BOT API ───────────────────────
    bots_query = await db.execute(
        select(Bot)
        .join(User, Bot.user_id == User.id)
        .join(ChatMember, ChatMember.user_id == User.id)
        .where(
            ChatMember.chat_id == chat_id,
            ChatMember.is_banned == False,
            User.id != user.id
        )
    )
    chat_bots = bots_query.scalars().all()

    for bot in chat_bots:
        if msg.sent_at:
            if msg.sent_at.tzinfo is None:
                sent_date = int(msg.sent_at.replace(tzinfo=timezone.utc).timestamp())
            else:
                sent_date = int(msg.sent_at.timestamp())
        else:
            sent_date = int(datetime.now(timezone.utc).timestamp())

        update_payload = {
            "message_id": msg.id,
            "from": {
                "id": user.id,
                "is_bot": False,
                "first_name": user.display_name,
                "username": user.username,
            },
            "chat": {
                "id": chat_id,
                "type": "private" if chat.chat_type == ChatType.DIRECT else chat.chat_type.value,
                "title": chat.name if chat.chat_type != ChatType.DIRECT else None,
                "username": chat.username if chat.chat_type != ChatType.DIRECT else None,
            },
            "date": sent_date,
            "text": content or ""
        }
        await queue_bot_update(db, bot.id, "message", update_payload)
        await _push_to_user(bot.user_id, {"action": "message", "payload": update_payload})
    # ── КОНЕЦ: ДОСТАВКА СООБЩЕНИЙ БОТАМ ЧЕРЕЗ BOT API ─────────────────────────

    # BotCreator auto-reply if recipient is botcreator
    await _maybe_botcreator_reply(db, user, chat_id, msg, content or "")
    return result

async def handle_history(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    page = payload.get("page", 1)
    page_size = payload.get("page_size", 1000)
    before_id = payload.get("before_id")
    await _require_member(db, chat_id, user.id)
    q = select(Message).where(Message.chat_id == chat_id)
    if before_id:
        q = q.where(Message.id < before_id)
    total_r = await db.execute(select(func.count()).select_from(Message).where(Message.chat_id == chat_id))
    total = total_r.scalar()
    q = q.order_by(Message.id.desc()).limit(page_size).offset((page - 1) * page_size)
    r = await db.execute(q)
    msgs = list(reversed(r.scalars().all()))
    result = [await serialise_message(msg, db) for msg in msgs]
    return {"messages": result, "total": total, "page": page, "page_size": page_size}

async def handle_edit_message(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    message_id = payload.get("message_id")
    content = payload.get("content")
    r = await db.execute(select(Message).where(
        Message.id == message_id, Message.chat_id == chat_id, Message.sender_id == user.id))
    msg = r.scalar_one_or_none()
    if not msg:
        return {"error": "Message not found or not yours"}
    if msg.is_deleted:
        return {"error": "Cannot edit deleted message"}
    enc = encrypt_text(content)
    msg.encrypted_content = enc["ciphertext"]
    msg.content_iv = enc["iv"]
    msg.content_tag = enc["tag"]
    msg.edited_at = datetime.now(timezone.utc)
    return await serialise_message(msg, db)

async def handle_delete_message(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    message_id = payload.get("message_id")
    r = await db.execute(select(Message).where(Message.id == message_id, Message.chat_id == chat_id))
    msg = r.scalar_one_or_none()
    if not msg:
        return {"error": "Message not found"}
    if msg.sender_id != user.id:
        mr = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat_id, ChatMember.user_id == user.id))
        m = mr.scalar_one_or_none()
        if not m or m.role == MemberRole.MEMBER:
            return {"error": "Not allowed to delete this message"}
            
    # Удаляем реакции к сообщению
    await db.execute(delete(MessageReaction).where(MessageReaction.message_id == msg.id))
    
    # Физически удаляем файл с диска, если он есть
    if getattr(msg, "media_path", None):
        full_path = os.path.join(settings.UPLOAD_DIR, msg.media_path)
        if os.path.exists(full_path):
            try:
                os.remove(full_path)
            except Exception:
                pass

    # Полностью удаляем сообщение из базы
    await db.delete(msg)
    return {"message": "Deleted"}

async def handle_react(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    message_id = payload.get("message_id")
    emoji = payload.get("emoji")
    await _require_member(db, chat_id, user.id)
    r = await db.execute(select(MessageReaction).where(
        MessageReaction.message_id == message_id, MessageReaction.user_id == user.id, MessageReaction.emoji == emoji))
    existing = r.scalar_one_or_none()
    if existing:
        await db.delete(existing)
        return {"action": "removed", "emoji": emoji}
    db.add(MessageReaction(message_id=message_id, user_id=user.id, emoji=emoji))
    return {"action": "added", "emoji": emoji}

async def handle_post_comment(payload: dict, db: AsyncSession, user: User):
    channel_id = payload.get("channel_id")
    post_id = payload.get("post_id")
    content = payload.get("content")
    upload_id = payload.get("upload_id")
    cr = await db.execute(select(Chat).where(Chat.id == channel_id))
    channel = cr.scalar_one_or_none()
    if not channel or channel.chat_type != ChatType.CHANNEL:
        return {"error": "Channel not found"}
    if not channel.comments_chat_id:
        return {"error": "Comments are not enabled for this channel"}
    pr = await db.execute(select(Message).where(Message.id == post_id, Message.chat_id == channel_id))
    post = pr.scalar_one_or_none()
    if not post:
        return {"error": "Post not found"}
    comments_chat_id = channel.comments_chat_id
    ex = await db.execute(select(ChatMember).where(ChatMember.chat_id == comments_chat_id, ChatMember.user_id == user.id))
    if not ex.scalar_one_or_none():
        db.add(ChatMember(chat_id=comments_chat_id, user_id=user.id))
        await db.flush()
    if not content and not upload_id:
        return {"error": "Comment must have content"}
    msg = Message(chat_id=comments_chat_id, sender_id=user.id, reply_to_id=post_id, msg_type=MessageType.TEXT)
    if content:
        enc = encrypt_text(content)
        msg.encrypted_content = enc["ciphertext"]
        msg.content_iv = enc["iv"]
        msg.content_tag = enc["tag"]
    db.add(msg); await db.flush()
    post.comments_count = (post.comments_count or 0) + 1
    await increment_unread(db, comments_chat_id, user.id, msg.id)
    return await serialise_message(msg, db)

async def handle_get_comments(payload: dict, db: AsyncSession, user: User):
    channel_id = payload.get("channel_id")
    post_id = payload.get("post_id")
    page = payload.get("page", 1)
    page_size = payload.get("page_size", 50)
    cr = await db.execute(select(Chat).where(Chat.id == channel_id))
    channel = cr.scalar_one_or_none()
    if not channel or not channel.comments_chat_id:
        return {"error": "Channel or comments not found"}
    comments_chat_id = channel.comments_chat_id
    q = select(Message).where(
        Message.chat_id == comments_chat_id, Message.reply_to_id == post_id, Message.is_deleted == False
    ).order_by(Message.sent_at.asc()).limit(page_size).offset((page - 1) * page_size)
    r = await db.execute(q)
    result = [await serialise_message(m, db) for m in r.scalars().all()]
    return {"comments": result, "page": page, "page_size": page_size}

async def handle_init_upload(payload: dict, db: AsyncSession, user: User):
    filename = payload.get("filename")
    total_chunks = payload.get("total_chunks")
    file_size = payload.get("file_size")
    media_subtype = payload.get("media_subtype", "media")

    # 10 MB limit
    MAX_FILE_SIZE = 30 * 1024 * 1024
    if file_size and file_size > MAX_FILE_SIZE:
        return {"error": f"File size exceeds limit of 30 MB (got {file_size / 1024 / 1024:.2f} MB)"}

    if media_subtype not in ("media", "voice", "circle"):
        return {"error": "media_subtype must be media, voice, or circle"}
    upload_id = uuid.uuid4().hex
    ext = filename.rsplit(".", 1)[-1] if "." in filename else "bin"
    subdir = media_subtype if media_subtype in ("voice", "circles") else "media"
    temp_name = f"{subdir}/{user.id}_{upload_id}.{ext}"
    temp_path = os.path.join(settings.UPLOAD_DIR, temp_name)
    os.makedirs(os.path.dirname(temp_path), exist_ok=True)
    async with aiofiles.open(temp_path, "wb") as f:
        pass
    db.add(MediaUploadChunk(
        upload_id=upload_id, user_id=user.id, filename=filename, media_subtype=media_subtype,
        total_chunks=total_chunks, received_chunks=0, temp_path=temp_path))
    await db.flush()
    return {"upload_id": upload_id, "chunk_size": settings.CHUNK_SIZE}

async def handle_upload_chunk(payload: dict, db: AsyncSession, user: User):
    upload_id = payload.get("upload_id")
    chunk_index = payload.get("chunk_index")
    chunk_b64 = payload.get("chunk_base64")
    r = await db.execute(select(MediaUploadChunk).where(
        MediaUploadChunk.upload_id == upload_id, MediaUploadChunk.user_id == user.id))
    up = r.scalar_one_or_none()
    if not up:
        return {"error": "Upload session not found"}
    try:
        data = base64.b64decode(chunk_b64)
    except Exception:
        return {"error": "Invalid base64 chunk"}
    async with aiofiles.open(up.temp_path, "r+b") as f:
        await f.seek(chunk_index * settings.CHUNK_SIZE)
        await f.write(data)
    up.received_chunks += 1
    complete = up.received_chunks >= up.total_chunks
    return {"upload_id": upload_id, "chunk_index": chunk_index, "received": up.received_chunks,
            "total": up.total_chunks, "complete": complete}

# ── Posts (Feed) ───────────────────────────────────────────────────────────────

async def handle_create_post(payload: dict, db: AsyncSession, user: User):
    content = payload.get("content", "")
    upload_id = payload.get("upload_id")
    media_path = None

    if upload_id:
        r = await db.execute(select(MediaUploadChunk).where(
            MediaUploadChunk.upload_id == upload_id, MediaUploadChunk.user_id == user.id))
        up = r.scalar_one_or_none()
        if not up:
            return {"error": "Upload session not found"}
        if up.received_chunks < up.total_chunks:
            return {"error": f"Upload incomplete ({up.received_chunks}/{up.total_chunks} chunks)"}

        ext = up.filename.rsplit(".", 1)[-1] if "." in up.filename else "jpg"
        final_name = f"posts/{user.id}_{uuid.uuid4().hex}.{ext}"
        final_path = os.path.join(settings.UPLOAD_DIR, final_name)
        os.makedirs(os.path.dirname(final_path), exist_ok=True)
        
        try:
            os.rename(up.temp_path, final_path)
        except Exception:
            shutil.move(up.temp_path, final_path)
            
        media_path = final_name
        await db.delete(up)

    # ── НАЧАЛО: Генерация ИИ-хештегов ──────────────────────────────────────────
    if content and content.strip():
        ai_tags = await _generate_tags_for_post(content, media_path)
        if ai_tags:
            # Если текст был пустой (только фото), пишем только теги, иначе совмещаем
            content = f"{content}\n\n{ai_tags}" if content else ai_tags
    # ── КОНЕЦ: Генерация ИИ-хештегов ───────────────────────────────────────────

    if not content and not media_path:
        return {"error": "Post must have content or media"}

    post = Post(author_id=user.id, content=content, media_path=media_path)
    db.add(post)
    await db.flush()
    return {"message": "Post created successfully", "post_id": post.id}

async def _format_posts_for_feed(posts, user, db, page, limit, followed_ids):
    """Вспомогательная функция для сборки ответа с постами"""
    result = []
    for p in posts:
        ur = await db.execute(select(User).where(User.id == p.author_id))
        author = ur.scalar_one_or_none()
        
        react_r = await db.execute(select(PostReaction).where(
            PostReaction.post_id == p.id, PostReaction.user_id == user.id))
        react = react_r.scalar_one_or_none()
        my_react = "like" if react and react.is_like else ("dislike" if react else None)
            
        result.append({
            "id": p.id,
            "content": p.content,
            "media_url": static_url(p.media_path) if p.media_path else None,
            "likes": p.likes_count,
            "dislikes": p.dislikes_count,
            "comments_count": p.comments_count,
            "created_at": p.created_at.isoformat() if p.created_at else None,
            "my_reaction": my_react,
            "author": {
                "id": author.id, "username": author.username, 
                "display_name": author.display_name, "avatar_url": static_url(author.avatar_path),
                "is_followed": (author.id in followed_ids) if author else False
            } if author else None
        })
    return {"posts": result, "page": page, "limit": limit}


async def handle_get_feed(payload: dict, db: AsyncSession, user: User):
    page = payload.get("page", 1)
    limit = 15
    offset = (page - 1) * limit

    # Подписки юзера
    sub_q = await db.execute(select(Subscription.followed_id).where(Subscription.follower_id == user.id))
    followed_ids = set(row[0] for row in sub_q.all())

    # Если листают очень глубоко (дальше 500 поста), отдаем просто хронологическую ленту (Fallback)
    if offset >= 500:
        q = select(Post).order_by(Post.created_at.desc()).limit(limit).offset(offset)
        fallback_posts = (await db.execute(q)).scalars().all()
        return await _format_posts_for_feed(fallback_posts, user, db, page, limit, followed_ids)

    # 1. СОБИРАЕМ ПРОФИЛЬ ИНТЕРЕСОВ ЮЗЕРА ("Анализ котиков")
    # Берем последние 50 лайкнутых постов
    liked_q = await db.execute(
        select(Post)
        .join(PostReaction, PostReaction.post_id == Post.id)
        .where(PostReaction.user_id == user.id, PostReaction.is_like == True)
        .order_by(PostReaction.id.desc())
        .limit(50)
    )
    liked_posts = liked_q.scalars().all()

    # Скрытые любимые авторы
    affinity_authors = Counter(p.author_id for p in liked_posts)
    top_authors = set(aid for aid, count in affinity_authors.most_common(10))

    # Извлекаем хештеги или ключевые слова (от 5 букв) из лайкнутых постов
    liked_texts = " ".join(p.content for p in liked_posts if p.content).lower()
    hashtags = re.findall(r'#\w+', liked_texts)
    if hashtags:
        top_keywords = set(w for w, c in Counter(hashtags).most_common(10))
    else:
        words = re.findall(r'\b[a-zа-я]{5,}\b', liked_texts)
        top_keywords = set(w for w, c in Counter(words).most_common(15))

    # 2. ПОЛУЧАЕМ КАНДИДАТОВ ДЛЯ ЛЕНТЫ (последние 500 постов)
    pool_q = await db.execute(select(Post).order_by(Post.created_at.desc()).limit(500))
    pool_posts = pool_q.scalars().all()

    # 3. РАНЖИРУЕМ ПОСТЫ (Hacker News Gravity Formula)
    now = datetime.now(timezone.utc)
    scored_posts = []

    for p in pool_posts:
        # Базовая ценность
        points = 1.0 
        
        # Социальные факторы
        points += (p.likes_count or 0) * 2.0
        points += (p.comments_count or 0) * 3.0
        points -= (p.dislikes_count or 0) * 2.0
        
        # Мягкий приоритет подпискам
        if p.author_id in followed_ids:
            points += 15.0  # Дает буст, но со временем он сгорит
            
        # Симпатия к автору без подписки
        if p.author_id in top_authors:
            points += 5.0
            
        # Поиск совпадений по темам (наши "котики")
        if p.content:
            content_lower = p.content.lower()
            matches = sum(1 for kw in top_keywords if kw in content_lower)
            points += matches * 8.0  # +8 очков за каждое совпадение слова из истории лайков
        
        points = max(points, 0.1)  # Защита от деления нуля

        # Время жизни поста (Age Penalty)
        p_time = p.created_at.replace(tzinfo=timezone.utc) if p.created_at.tzinfo is None else p.created_at
        age_hours = max((now - p_time).total_seconds() / 3600.0, 0.0)
        
        # Гравитация! Чем больше часов прошло, тем сильнее падает рейтинг
        gravity_exponent = 1.5
        final_score = points / ((age_hours + 2.0) ** gravity_exponent)
        
        scored_posts.append((final_score, p))

    # Сортируем: сначала самые актуальные/полезные посты, затем все остальные
    scored_posts.sort(key=lambda x: x[0], reverse=True)
    
    # Берем нужную страницу (limit/offset)
    paged_posts = [post for score, post in scored_posts[offset : offset + limit]]

    return await _format_posts_for_feed(paged_posts, user, db, page, limit, followed_ids)

async def handle_react_post(payload: dict, db: AsyncSession, user: User):
    post_id = payload.get("post_id")
    is_like = payload.get("is_like", True)

    r = await db.execute(select(Post).where(Post.id == post_id))
    post = r.scalar_one_or_none()
    if not post: 
        return {"error": "Post not found"}

    rr = await db.execute(select(PostReaction).where(PostReaction.post_id == post_id, PostReaction.user_id == user.id))
    react = rr.scalar_one_or_none()

    if react:
        if react.is_like == is_like:
            # Убираем реакцию, если нажали ту же кнопку
            if is_like:
                post.likes_count = max(0, post.likes_count - 1)
            else:
                post.dislikes_count = max(0, post.dislikes_count - 1)
            await db.delete(react)
            action = "removed"
        else:
            # Меняем реакцию
            if is_like:
                post.dislikes_count = max(0, post.dislikes_count - 1)
                post.likes_count += 1
            else:
                post.likes_count = max(0, post.likes_count - 1)
                post.dislikes_count += 1
            react.is_like = is_like
            action = "switched"
    else:
        # Новая реакция
        new_react = PostReaction(post_id=post_id, user_id=user.id, is_like=is_like)
        db.add(new_react)
        if is_like:
            post.likes_count += 1
        else:
            post.dislikes_count += 1
        action = "added"

    await db.flush()
    return {
        "post_id": post_id,
        "action": action,
        "likes": post.likes_count,
        "dislikes": post.dislikes_count
    }

async def handle_comment_post(payload: dict, db: AsyncSession, user: User):
    post_id = payload.get("post_id")
    content = payload.get("content")

    if not content: 
        return {"error": "Comment cannot be empty"}

    r = await db.execute(select(Post).where(Post.id == post_id))
    post = r.scalar_one_or_none()
    if not post: 
        return {"error": "Post not found"}

    comment = PostComment(post_id=post_id, author_id=user.id, content=content)
    db.add(comment)
    post.comments_count += 1
    await db.flush()

    return {
        "id": comment.id,
        "post_id": post_id,
        "content": content,
        "author_id": user.id,
        "created_at": comment.created_at.isoformat() if comment.created_at else None
    }

async def handle_get_post_comments(payload: dict, db: AsyncSession, user: User):
    post_id = payload.get("post_id")
    page = payload.get("page", 1)
    limit = 50
    offset = (page - 1) * limit

    q = select(PostComment).where(PostComment.post_id == post_id).order_by(PostComment.created_at.asc()).limit(limit).offset(offset)
    r = await db.execute(q)

    result = []
    for c in r.scalars().all():
        ur = await db.execute(select(User).where(User.id == c.author_id))
        author = ur.scalar_one_or_none()
        result.append({
            "id": c.id,
            "content": c.content,
            "created_at": c.created_at.isoformat() if c.created_at else None,
            "author": {
                "id": author.id, "username": author.username, 
                "display_name": author.display_name, "avatar_url": static_url(author.avatar_path)
            } if author else None
        })

    return {"comments": result, "page": page}

# ── Search ────────────────────────────────────────────────────────────────────
async def handle_edit_post(payload: dict, db: AsyncSession, user: User):
    post_id = payload.get("post_id")
    content = payload.get("content")
    r = await db.execute(select(Post).where(Post.id == post_id, Post.author_id == user.id))
    post = r.scalar_one_or_none()
    if not post:
        return {"error": "Post not found or not yours"}
    post.content = content
    await db.flush()
    return {"message": "Post edited successfully", "post_id": post.id}

async def handle_delete_post(payload: dict, db: AsyncSession, user: User):
    post_id = payload.get("post_id")
    r = await db.execute(select(Post).where(Post.id == post_id, Post.author_id == user.id))
    post = r.scalar_one_or_none()
    if not post:
        return {"error": "Post not found or not yours"}
    
    # Удаляем реакции и комментарии
    await db.execute(delete(PostReaction).where(PostReaction.post_id == post_id))
    await db.execute(delete(PostComment).where(PostComment.post_id == post_id))
    
    # Удаляем файл с диска, если он есть
    if post.media_path:
        full_path = os.path.join(settings.UPLOAD_DIR, post.media_path)
        if os.path.exists(full_path):
            try:
                os.remove(full_path)
            except Exception:
                pass

    await db.delete(post)
    await db.flush()
    return {"message": "Post deleted successfully"}

async def handle_search(payload: dict, db: AsyncSession, user: User):
    q = str(payload.get("q", "")).strip()
    if len(q) < 1:
        return {"users": [], "chats": [], "messages": []}
    results = {"users": [], "chats": [], "messages": []}
    ur = await db.execute(select(User).where(
        or_(User.username.ilike(f"%{q}%"), User.display_name.ilike(f"%{q}%")),
        User.is_active == True, User.is_banned == False).limit(20))
    for u in ur.scalars().all():
        badges = await get_user_badges(db, u.id)
        results["users"].append({
            "id": u.id, "username": u.username, "display_name": u.display_name,
            "bio": u.bio or "", "avatar_url": static_url(u.avatar_path), "badges": badges})
    cr = await db.execute(select(Chat).where(
        Chat.chat_type != ChatType.DIRECT, Chat.is_banned == False,
        or_(Chat.name.ilike(f"%{q}%"), Chat.username.ilike(f"%{q}%"))).limit(30))
    for chat in cr.scalars().all():
        mr = await db.execute(select(ChatMember).where(
            ChatMember.chat_id == chat.id, ChatMember.user_id == user.id, ChatMember.is_banned == False))
        if not mr.scalar_one_or_none():
            continue
        cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
        results["chats"].append({
            "id": chat.id, "chat_type": chat.chat_type.value, "name": chat.name,
            "username": chat.username, "avatar_url": static_url(chat.avatar_path),
            "members_count": cnt.scalar(), "invite_link": chat_link(chat.username), "share_link": share_link(chat.username)})
    memr = await db.execute(select(ChatMember.chat_id).where(
        ChatMember.user_id == user.id, ChatMember.is_banned == False))
    my_chats = [row[0] for row in memr.all()]
    if my_chats:
        msgr = await db.execute(select(Message).where(
            Message.chat_id.in_(my_chats), Message.is_deleted == False, Message.encrypted_content != None
        ).order_by(Message.sent_at.desc()).limit(500))
        for msg in msgr.scalars().all():
            try:
                content = decrypt_text(msg.encrypted_content, msg.content_iv, msg.content_tag)
            except Exception:
                continue
            if q.lower() in content.lower():
                out = await serialise_message(msg, db)
                results["messages"].append(out)
                if len(results["messages"]) >= 20:
                    break
    return results

# ── Calls ─────────────────────────────────────────────────────────────────────

async def handle_initiate_call(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    is_video = payload.get("is_video", False)
    mr = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == user.id, ChatMember.is_banned == False))
    if not mr.scalar_one_or_none():
        return {"error": "Not a member of this chat"}
    call = Call(chat_id=chat_id, initiator_id=user.id, is_video=is_video, status=CallStatus.RINGING)
    db.add(call); await db.flush()
    db.add(CallParticipant(call_id=call.id, user_id=user.id))
    call_type = "video" if is_video else "voice"
    return {"call_id": call.id, "chat_id": chat_id, "status": "ringing", "call_type": call_type}

async def handle_answer_call(payload: dict, db: AsyncSession, user: User):
    call_id = payload.get("call_id")
    accept = payload.get("accept")
    r = await db.execute(select(Call).where(Call.id == call_id))
    call = r.scalar_one_or_none()
    if not call:
        return {"error": "Call not found"}
    if call.status not in (CallStatus.RINGING, CallStatus.ACTIVE):
        return {"error": f"Call is already {call.status.value}"}
    if accept:
        call.status = CallStatus.ACTIVE
        db.add(CallParticipant(call_id=call.id, user_id=user.id))
        return {"call_id": call.id, "status": "active"}
    else:
        call.status = CallStatus.DECLINED
        call.ended_at = datetime.now(timezone.utc)
        await _log_call_message(db, call, user.id, "declined")
        return {"call_id": call.id, "status": "declined"}

async def handle_end_call(payload: dict, db: AsyncSession, user: User):
    call_id = payload.get("call_id")
    r = await db.execute(select(Call).where(Call.id == call_id))
    call = r.scalar_one_or_none()
    if not call:
        return {"error": "Call not found"}
    now = datetime.now(timezone.utc)
    was_missed = call.status == CallStatus.RINGING
    call.status = CallStatus.MISSED if was_missed else CallStatus.ENDED
    call.ended_at = now
    if call.started_at and not was_missed:
        delta = now - call.started_at.replace(tzinfo=timezone.utc) if call.started_at.tzinfo is None else now - call.started_at
        call.duration_seconds = int(delta.total_seconds())
    pr = await db.execute(select(CallParticipant).where(CallParticipant.call_id == call.id, CallParticipant.user_id == user.id))
    p = pr.scalar_one_or_none()
    if p:
        p.left_at = now; p.is_active = False
    status_str = "missed" if was_missed else f"ended ({call.duration_seconds}s)"
    await _log_call_message(db, call, user.id, status_str)
    return {"call_id": call.id, "status": call.status.value, "duration_seconds": call.duration_seconds}

async def handle_get_call(payload: dict, db: AsyncSession, user: User):
    call_id = payload.get("call_id")
    r = await db.execute(select(Call).where(Call.id == call_id))
    call = r.scalar_one_or_none()
    if not call:
        return {"error": "Call not found"}
    pr = await db.execute(select(CallParticipant).where(CallParticipant.call_id == call_id, CallParticipant.is_active == True))
    participants = [{"user_id": p.user_id, "joined_at": p.joined_at.isoformat() if p.joined_at else None} for p in pr.scalars().all()]
    return {"call_id": call.id, "chat_id": call.chat_id, "initiator_id": call.initiator_id,
            "is_video": call.is_video, "status": call.status.value,
            "started_at": call.started_at.isoformat() if call.started_at else None,
            "ended_at": call.ended_at.isoformat() if call.ended_at else None,
            "duration_seconds": call.duration_seconds, "participants": participants}

async def _log_call_message(db, call, user_id, status_str):
    call_type = "📹 Video" if call.is_video else "📞 Voice"
    text = f"{call_type} call — {status_str}"
    enc = encrypt_text(text)
    msg = Message(chat_id=call.chat_id, sender_id=user_id, msg_type=MessageType.CALL_LOG,
                  encrypted_content=enc["ciphertext"], content_iv=enc["iv"], content_tag=enc["tag"])
    db.add(msg)

# ── Invite ────────────────────────────────────────────────────────────────────

async def handle_get_invite_info(payload: dict, db: AsyncSession):
    slug = str(payload.get("slug", "")).lower()
    r = await db.execute(select(Chat).where(Chat.username == slug))
    chat = r.scalar_one_or_none()
    if not chat or chat.chat_type == ChatType.DIRECT or chat.is_banned:
        return {"error": "Invite link not found"}
    cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
    return {"name": chat.name, "chat_type": chat.chat_type.value, "description": chat.description or "",
            "avatar_url": static_url(chat.avatar_path), "members_count": cnt.scalar(), "slug": slug}

async def handle_join_chat(payload: dict, db: AsyncSession, user: User):
    slug = str(payload.get("slug", "")).lower()
    if user.spam_block:
        return {"error": "Spam-blocked accounts cannot join public chats."}
    r = await db.execute(select(Chat).where(Chat.username == slug))
    chat = r.scalar_one_or_none()
    if not chat or chat.chat_type == ChatType.DIRECT or chat.is_banned:
        return {"error": "Invite link not found"}
    ex = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat.id, ChatMember.user_id == user.id))
    m = ex.scalar_one_or_none()
    if m:
        if m.is_banned:
            return {"error": "You are banned from this chat"}
        return {"message": "Already a member", "chat_id": chat.id}
    db.add(ChatMember(chat_id=chat.id, user_id=user.id, role=MemberRole.MEMBER))
    if chat.comments_chat_id:
        ex2 = await db.execute(select(ChatMember).where(ChatMember.chat_id == chat.comments_chat_id, ChatMember.user_id == user.id))
        if not ex2.scalar_one_or_none():
            db.add(ChatMember(chat_id=chat.comments_chat_id, user_id=user.id, role=MemberRole.MEMBER))
    return {"message": "Joined successfully", "chat_id": chat.id, "name": chat.name,
            "invite_link": chat_link(slug), "share_link": share_link(slug)}

# ── Admin ─────────────────────────────────────────────────────────────────────

async def _admin_user_row(db, u: User):
    badges = await get_user_badges(db, u.id)
    return {"id": u.id, "username": u.username, "email": u.email, "display_name": u.display_name,
            "avatar_url": static_url(u.avatar_path), "is_active": u.is_active, "is_banned": u.is_banned,
            "is_frozen": u.is_frozen, "spam_block": u.spam_block, "two_fa_enabled": u.two_fa_enabled,
            "created_at": u.created_at.isoformat() if u.created_at else None, "badges": badges}

async def handle_admin_list_users(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
        
    # --- РАСШИРЕННЫЙ АГРЕССИВНЫЙ ФИКС БАЗЫ ДАННЫХ ---
    # Мы стираем 'None' из ВСЕХ возможных DateTime полей, 
    # чтобы ORM не падал при чтении модели User и её связей.
    try:
        queries = [
            # Пользователи
            "UPDATE users SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE users SET updated_at = NULL WHERE updated_at LIKE '%None%'",
            "UPDATE users SET last_active = NULL WHERE last_active LIKE '%None%'",
            "UPDATE users SET last_login = NULL WHERE last_login LIKE '%None%'",
            
            # Бейджи
            "UPDATE badges SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE user_badges SET created_at = NULL WHERE created_at LIKE '%None%'",
            
            # Сессии (если они подгружаются через eager loading)
            "UPDATE sessions SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE sessions SET last_active = NULL WHERE last_active LIKE '%None%'",
            
            # Прочие связи
            "UPDATE posts SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE post_comments SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE user_fcm_tokens SET updated_at = NULL WHERE updated_at LIKE '%None%'"
        ]
        for q in queries:
            try:
                await db.execute(text(q))
            except Exception:
                # Игнорируем ошибки отсутствия колонок (например, если updated_at нет в БД)
                pass
        await db.commit()
    except Exception:
        pass
    # ------------------------------------

    page = payload.get("page", 1)
    page_size = payload.get("page_size", 50)
    
    try:
        r = await db.execute(select(User).offset((page - 1) * page_size).limit(page_size))
        return [await _admin_user_row(db, u) for u in r.scalars().all()]
    except ValueError as e:
        # Резервный перехват, если всё равно где-то остался битый формат
        return {"error": f"Data corruption in DB dates: {str(e)}"}


async def handle_admin_list_posts(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}

    # Чистим даты у постов, на случай если там тоже 'None'
    try:
        await db.execute(text("UPDATE posts SET created_at = NULL WHERE created_at LIKE '%None%'"))
        await db.commit()
    except Exception:
        pass

    page = payload.get("page", 1)
    page_size = payload.get("page_size", 50)
    
    r = await db.execute(select(Post).order_by(Post.id.desc()).offset((page - 1) * page_size).limit(page_size))
    posts = r.scalars().all()
    
    result = []
    for p in posts:
        ur = await db.execute(select(User).where(User.id == p.author_id))
        u = ur.scalar_one_or_none()
        
        created_at_str = None
        try:
            created_at_str = p.created_at.isoformat() if p.created_at else None
        except Exception:
            pass
            
        result.append({
            "id": p.id,
            "content": p.content[:100] + "..." if p.content and len(p.content) > 100 else (p.content or ""),
            "media_path": p.media_path,
            "author_id": p.author_id,
            "author_username": u.username if u else "Unknown",
            "likes": p.likes_count,
            "comments": p.comments_count,
            "created_at": created_at_str
        })
    return result


async def handle_admin_get_user(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    user_id = payload.get("user_id")
    r = await db.execute(select(User).where(User.id == user_id))
    u = r.scalar_one_or_none()
    if not u:
        return {"error": "User not found"}
    return await _admin_user_row(db, u)

async def handle_ban_user(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    user_id = payload.get("user_id")
    r = await db.execute(select(User).where(User.id == user_id))
    u = r.scalar_one_or_none()
    if not u:
        return {"error": "User not found"}
    u.is_banned = True
    sr = await db.execute(select(Session).where(Session.user_id == u.id))
    for s in sr.scalars().all():
        s.is_active = False
    return {"message": f"User @{u.username} banned", "reason": payload.get("reason")}

async def handle_unban_user(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    user_id = payload.get("user_id")
    r = await db.execute(select(User).where(User.id == user_id))
    u = r.scalar_one_or_none()
    if not u:
        return {"error": "User not found"}
    u.is_banned = False
    return {"message": f"User @{u.username} unbanned"}

async def handle_freeze_user(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    user_id = payload.get("user_id")
    frozen = payload.get("frozen", True)
    r = await db.execute(select(User).where(User.id == user_id))
    u = r.scalar_one_or_none()
    if not u:
        return {"error": "User not found"}
    u.is_frozen = frozen
    if frozen:
        sr = await db.execute(select(Session).where(Session.user_id == u.id))
        for s in sr.scalars().all():
            s.is_active = False
    return {"message": f"User @{u.username} {'frozen' if frozen else 'unfrozen'}"}

async def handle_spam_block(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    user_id = payload.get("user_id")
    blocked = payload.get("blocked", True)
    r = await db.execute(select(User).where(User.id == user_id))
    u = r.scalar_one_or_none()
    if not u:
        return {"error": "User not found"}
    u.spam_block = blocked
    return {"message": f"User @{u.username} spam_block={'on' if blocked else 'off'}"}

async def handle_admin_clear_bio(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    user_id = payload.get("user_id")
    r = await db.execute(select(User).where(User.id == user_id))
    u = r.scalar_one_or_none()
    if not u:
        return {"error": "User not found"}
    u.bio = ""
    return {"message": f"User @{u.username} bio cleared"}

async def handle_admin_list_chats(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}

    # --- АВТО-ФИКС ИСПОРЧЕННЫХ ДАТ ---
    try:
        await db.execute(text("UPDATE chats SET created_at = NULL WHERE created_at = 'None'"))
        await db.commit()
    except Exception:
        pass
    # ---------------------------------

    page = payload.get("page", 1)
    page_size = payload.get("page_size", 50)
    r = await db.execute(select(Chat).where(Chat.chat_type != ChatType.DIRECT).offset((page - 1) * page_size).limit(page_size))
    result = []
    for chat in r.scalars().all():
        cnt = await db.execute(select(func.count()).select_from(ChatMember).where(ChatMember.chat_id == chat.id))
        result.append({"id": chat.id, "name": chat.name, "chat_type": chat.chat_type.value,
                        "username": chat.username, "is_banned": chat.is_banned,
                        "members_count": cnt.scalar(), "created_at": chat.created_at.isoformat() if chat.created_at else None})
    return result

async def handle_ban_chat(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    chat_id = payload.get("chat_id")
    banned = payload.get("banned", True)
    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one_or_none()
    if not chat:
        return {"error": "Chat not found"}
    if chat.chat_type == ChatType.DIRECT:
        return {"error": "Cannot ban direct chats"}
    chat.is_banned = banned
    return {"message": f"Chat '{chat.name}' {'banned' if banned else 'unbanned'}"}

async def handle_admin_delete_post(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    post_id = payload.get("post_id")
    r = await db.execute(select(Post).where(Post.id == post_id))
    post = r.scalar_one_or_none()
    if not post:
        return {"error": "Post not found"}
    
    # Удаляем реакции и комментарии
    await db.execute(delete(PostReaction).where(PostReaction.post_id == post_id))
    await db.execute(delete(PostComment).where(PostComment.post_id == post_id))
    
    # Удаляем файл с диска
    if getattr(post, "media_path", None):
        full_path = os.path.join(settings.UPLOAD_DIR, post.media_path)
        if os.path.exists(full_path):
            try:
                os.remove(full_path)
            except Exception:
                pass

    await db.delete(post)
    return {"message": f"Post {post_id} deleted successfully"}

async def handle_list_badges(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    r = await db.execute(select(Badge))
    return [{"id": b.id, "name": b.name, "description": b.description,
             "icon": b.icon, "color": b.color, "created_at": b.created_at.isoformat() if b.created_at else None}
            for b in r.scalars().all()]

async def handle_create_badge(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    name = payload.get("name")
    description = payload.get("description", "")
    icon = payload.get("icon", "🏅")
    color = payload.get("color", "#4f46e5")
    r = await db.execute(select(Badge).where(Badge.name == name))
    if r.scalar_one_or_none():
        return {"error": "Badge name already exists"}
    badge = Badge(name=name, description=description, icon=icon, color=color)
    db.add(badge); await db.flush()
    return {"id": badge.id, "name": badge.name, "icon": badge.icon, "color": badge.color}

async def handle_delete_badge(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    badge_id = payload.get("badge_id")
    r = await db.execute(select(Badge).where(Badge.id == badge_id))
    badge = r.scalar_one_or_none()
    if not badge:
        return {"error": "Badge not found"}
    await db.delete(badge)
    return {"message": "Badge deleted"}

async def handle_award_badge(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    user_id = payload.get("user_id")
    badge_id = payload.get("badge_id")
    ur = await db.execute(select(User).where(User.id == user_id))
    if not ur.scalar_one_or_none():
        return {"error": "User not found"}
    br = await db.execute(select(Badge).where(Badge.id == badge_id))
    if not br.scalar_one_or_none():
        return {"error": "Badge not found"}
    ex = await db.execute(select(UserBadge).where(UserBadge.user_id == user_id, UserBadge.badge_id == badge_id))
    if ex.scalar_one_or_none():
        return {"error": "User already has this badge"}
    db.add(UserBadge(user_id=user_id, badge_id=badge_id))
    return {"message": "Badge awarded"}

async def handle_revoke_badge(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}
    user_id = payload.get("user_id")
    badge_id = payload.get("badge_id")
    r = await db.execute(select(UserBadge).where(UserBadge.user_id == user_id, UserBadge.badge_id == badge_id))
    ub = r.scalar_one_or_none()
    if not ub:
        return {"error": "User does not have this badge"}
    await db.delete(ub)
    return {"message": "Badge revoked"}

# ── AI ──────────────────────────────────────────────────────────────────────────

MISTRAL_API_KEYS = [
    "ydbvYyjwYxYgKsKqxJbGLugedWG1BCju",
    "DPdMuZFMS3pUQDKgVfM1LPvOA5KKD3OG"
]
MISTRAL_API_URL = "https://api.mistral.ai/v1/chat/completions"
MISTRAL_MODEL = "ministral-3b-latest"

async def _generate_tags_for_post(content: str, media_path: Optional[str]) -> str:
    """Генерирует релевантные хештеги для поста с помощью ИИ.
    Если у поста есть картинка, используется мультимодальная модель Pixtral-12B,
    которая умеет «видеть» изображение. Если только текст — быстрая текстовая модель.
    """
    import base64
    import re

    # 1. Проверяем наличие локального файла картинки на диске
    has_image = False
    base64_image = None
    mime_type = "image/jpeg"

    if media_path:
        full_path = os.path.join(settings.UPLOAD_DIR, media_path)
        lower_path = media_path.lower()
        # Проверяем, что это поддерживаемый формат картинки
        if os.path.exists(full_path) and lower_path.endswith(('.jpg', '.jpeg', '.png', '.webp')):
            try:
                with open(full_path, "rb") as f:
                    base64_image = base64.b64encode(f.read()).decode('utf-8')
                has_image = True
                if lower_path.endswith('.png'):
                    mime_type = "image/png"
                elif lower_path.endswith('.webp'):
                    mime_type = "image/webp"
            except Exception as e:
                print(f"[ERROR] Failed to read image for tagging: {e}")

    # Инструкция для ИИ
    prompt_text = (
        "Проанализируй пост и сгенерируй 3-5 наиболее подходящих хештегов (тематик). "
        "Они должны быть на русском или английском языке в зависимости от контекста. "
        "Выдай ТОЛЬКО хештеги через пробел (например: #коты #еда #minecraft), без какого-либо дополнительного текста, вступлений или кавычек."
    )

    # 2. Выбор модели и подготовка payload
    if has_image:
        # Для картинок используем мультимодальную модель Pixtral
        model = "pixtral-12b-2409"
        
        full_prompt = prompt_text
        if content and content.strip():
            full_prompt += f"\n\nТекст поста: {content}"
            
        payload_content = [
            {"type": "text", "text": full_prompt},
            {
                "type": "image_url",
                "image_url": f"data:{mime_type};base64,{base64_image}"
            }
        ]
    else:
        # Если только текст (без изображения), используем быструю текстовую модель
        if not content or not content.strip():
            return ""
        model = MISTRAL_MODEL
        payload_content = f"{prompt_text}\n\nТекст поста: {content}"

    # 3. Отправка запроса в Mistral API
    async with httpx.AsyncClient() as client:
        for key in MISTRAL_API_KEYS:
            headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
            payload = {
                "model": model,
                "messages": [{"role": "user", "content": payload_content}],
                "temperature": 0.3
            }
            try:
                # Даем таймаут побольше для обработки картинок (25 сек)
                response = await client.post(MISTRAL_API_URL, json=payload, headers=headers, timeout=25.0)
                response.raise_for_status()
                data = response.json()
                raw_tags = data["choices"][0]["message"]["content"].strip()
                
                # Фильтруем, оставляя только хештеги
                cleaned_tags = " ".join(re.findall(r'#\w+', raw_tags.lower()))
                return cleaned_tags
            except Exception as e:
                print(f"[Mistral API Error ({model})]: {e}")
                continue

    return ""
async def _call_mistral(prompt: str) -> str:
    async with httpx.AsyncClient() as client:
        for key in MISTRAL_API_KEYS:
            headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
            payload = {"model": MISTRAL_MODEL, "messages": [{"role": "user", "content": prompt}], "temperature": 0.3}
            try:
                response = await client.post(MISTRAL_API_URL, json=payload, headers=headers, timeout=15.0)
                response.raise_for_status()
                data = response.json()
                return data["choices"][0]["message"]["content"].strip()
            except (httpx.HTTPStatusError, httpx.RequestError) as e:
                if isinstance(e, httpx.HTTPStatusError) and e.response.status_code == 400:
                    raise ValueError(f"Mistral API error: {e.response.text}")
                continue
    raise ValueError("All AI servers currently unavailable. Try again later.")

async def handle_ai_process_text(payload: dict, db: AsyncSession, user: User):
    text = payload.get("text", "")
    action = payload.get("action")
    target_language = payload.get("target_language")
    if action == "translate":
        if not target_language:
            return {"error": "target_language required for translate"}
        prompt = f"Переведи следующий текст на язык: {target_language}. В ответе выдай ТОЛЬКО перевод, без кавычек, без приветствий и без твоих комментариев:\n\n{text}"
    elif action == "correct":
        prompt = f"Исправь все грамматические, орфографические и пунктуационные ошибки в следующем тексте. Сохрани оригинальный язык текста. В ответе выдай ТОЛЬКО исправленный текст, без кавычек и комментариев:\n\n{text}"
    elif action == "formalize":
        prompt = f"Перепиши следующий текст в официально-деловом стиле. Сделай его вежливым и профессиональным. Сохрани оригинальный язык. В ответе выдай ТОЛЬКО переписанный текст, без кавычек и комментариев:\n\n{text}"
    else:
        return {"error": "Unknown action"}
    try:
        result = await _call_mistral(prompt)
    except ValueError as e:
        return {"error": str(e)}
    return {"original_text": text, "result_text": result, "action": action}

# ── Save / Load ───────────────────────────────────────────────────────────────

SAVES_DIR = "world_saves"
if not os.path.exists(SAVES_DIR):
    os.makedirs(SAVES_DIR)

async def handle_world_save(payload: dict, db: AsyncSession, user: User):
    owner_id = payload.get("owner_id")
    if not owner_id:
        return {"error": "Missing ownerId"}
    file_path = os.path.join(SAVES_DIR, f"{owner_id}.json")
    if "chunkPos" in payload:
        world_data = {"ownerId": owner_id, "data": "[]"}
        if os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8") as f:
                world_data = json.load(f)
        chunks = json.loads(world_data["data"])
        new_chunk = {"p": payload["chunkPos"], "s": payload["vSize"], "d": payload["data"]}
        found = False
        for i, c in enumerate(chunks):
            if c["p"] == payload["chunkPos"]:
                chunks[i] = new_chunk; found = True; break
        if not found:
            chunks.append(new_chunk)
        world_data["data"] = json.dumps(chunks)
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(world_data, f, indent=4)
        return {"status": "success", "mode": "partial"}
    else:
        with open(file_path, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=4)
        return {"status": "success", "mode": "full"}

async def handle_world_load(payload: dict, db: AsyncSession, user: User):
    owner_id = payload.get("owner_id")
    file_path = os.path.join(SAVES_DIR, f"{owner_id}.json")
    if not os.path.exists(file_path):
        return {"error": "Not Found"}
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data
    except Exception:
        return {"error": "Read Error"}

# ── Main dispatcher ────────────────────────────────────────────────────────────

async def ws_endpoint(websocket: WebSocket):
    await websocket.accept()
    anonymous_connections.append(websocket)
    current_user_id = None
    current_token = None

    # Generate per-connection encryption key and send to client
    conn_key = generate_connection_key()
    connection_keys[_ws_id(websocket)] = conn_key
    await _send(websocket, {"action": "key_exchange", "key": conn_key}, encrypt=False)

    try:
        while True:
            raw = await websocket.receive_text()

            # Rate limiting check
           

            # Try to decrypt if message is encrypted
            data = _decrypt_received(websocket, raw)
            if data is None:
                log_suspicious_activity(websocket, "DECRYPTION_FAILED", "Invalid or undecryptable message")
                await _send(websocket, {"action": "error", "error": "Invalid or undecryptable message", "payload": {}}, encrypt=True)
                continue

            action = data.get("action")
            payload = data.get("payload", {})
            req_id = data.get("request_id")
            token = data.get("token")
            message_id = data.get("message_id")  # Optional for replay attack prevention

            # Basic input validation
            if not action or not isinstance(action, str) or len(action) > 64:
                log_suspicious_activity(websocket, "INVALID_ACTION", f"Action: {action}")
                await _send(websocket, {"action": "error", "error": "Invalid action", "payload": {}}, encrypt=True)
                continue

            # Replay attack check
            if not _check_replay_attack(message_id):
                log_suspicious_activity(websocket, "REPLAY_ATTACK", f"Message ID: {message_id}, Action: {action}")
                await _send(websocket, {"action": "error", "error": "Duplicate message detected (replay attack)", "payload": {}}, encrypt=True)
                continue

            async with AsyncSessionLocal() as db:
                try:
                    user = await _get_user(db, token) if token else None
                    # --- НАЧАЛО: КРИТИЧЕСКИЙ ФИКС ---
                    if user and current_user_id != user.id:
                        current_user_id = user.id
                        if websocket in anonymous_connections:
                            anonymous_connections.remove(websocket)
                        user_connections.setdefault(user.id, []).append(websocket)
                    # --- КОНЕЦ: КРИТИЧЕСКИЙ ФИКС ---
                    result = {}

                    if action == "register":
                        if not _check_rate_limit(websocket, max_per_minute=60):
                            log_suspicious_activity(websocket, "RATE_LIMIT_EXCEEDED", f"Action: Limit reached")
                            await _send(websocket, {"action": "error", "error": "Rate limit exceeded. Slow down.", "payload": {}}, encrypt=True)
                            continue
                        result = await handle_register(payload, db)
                    elif action == "verify_email":
                        result = await handle_verify_email(payload, db)
                    elif action == "login":
                        if not _check_rate_limit(websocket, max_per_minute=60):
                            log_suspicious_activity(websocket, "RATE_LIMIT_EXCEEDED", f"Action: Limit reached")
                            await _send(websocket, {"action": "error", "error": "Rate limit exceeded. Slow down.", "payload": {}}, encrypt=True)
                            continue
                        result = await handle_login(payload, db)
                        if "access_token" in result and "error" not in result:
                            current_token = result["access_token"]
                            user2 = await _get_user(db, current_token)
                            if user2:
                                current_user_id = user2.id
                                if websocket in anonymous_connections:
                                    anonymous_connections.remove(websocket)
                                user_connections.setdefault(user2.id, []).append(websocket)
                    elif action == "verify_2fa":
                        result = await handle_verify_2fa(payload, db)
                        if "access_token" in result and "error" not in result:
                            current_token = result["access_token"]
                            user2 = await _get_user(db, current_token)
                            if user2:
                                current_user_id = user2.id
                                if websocket in anonymous_connections:
                                    anonymous_connections.remove(websocket)
                                user_connections.setdefault(user2.id, []).append(websocket)
                    elif action == "logout":
                        if current_token and current_user_id:
                            if websocket in user_connections.get(current_user_id, []):
                                user_connections[current_user_id].remove(websocket)
                            if not user_connections.get(current_user_id):
                                user_connections.pop(current_user_id, None)
                            current_user_id = None
                            current_token = None
                        result = await handle_logout(payload, db, token)

                    elif action == "reset_password_request":
                        result = await handle_reset_password_request(payload, db)
                    elif action == "reset_password_confirm":
                        result = await handle_reset_password_confirm(payload, db)

                    elif action == "me_info":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_me_info(payload, db, user)
                    elif action == "get_profile":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_profile(payload, db, user)
                    elif action == "get_profile_encrypted":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_profile_encrypted(payload, db, user)
                    elif action == "update_profile":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_update_profile(payload, db, user)
                    elif action == "upload_avatar":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_upload_avatar(payload, db, user)
                    elif action == "toggle_2fa":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_toggle_2fa(payload, db, user)
                    elif action == "list_sessions":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_list_sessions(payload, db, user)
                    elif action == "kick_session":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_kick_session(payload, db, user)
                    elif action == "register_fcm_token":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_register_fcm_token(payload, db, user)

                    # --- Subscriptions ---
                    elif action == "follow_user":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_follow_user(payload, db, user)
                    elif action == "unfollow_user":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_unfollow_user(payload, db, user)

                    elif action == "set_public_key":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_set_public_key(payload, db, user)
                    elif action == "get_public_key":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_public_key(payload, db, user)
                    
                    elif action == "erase_secret":
                        result = await handle_erase_secret(payload, db)

                    elif action == "list_chats":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_list_chats(payload, db, user)
                    elif action == "open_direct":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_open_direct(payload, db, user)
                    elif action == "create_group":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_create_group(payload, db, user)
                    elif action == "get_chat":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_chat(payload, db, user)
                    elif action == "get_members":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_members(payload, db, user)
                    elif action == "update_chat":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_update_chat(payload, db, user)
                    elif action == "chat_avatar_upload":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_chat_avatar_upload(payload, db, user)
                    elif action == "invite_user":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_invite_user(payload, db, user)
                    elif action == "ban_member":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_ban_member(payload, db, user)
                    elif action == "mute_member":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_mute_member(payload, db, user)
                    elif action == "promote_member":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_promote_member(payload, db, user)
                    elif action == "leave_chat":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_leave_chat(payload, db, user)
                    elif action == "mark_read":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_mark_read(payload, db, user)

                    elif action == "send_message":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_send_message(payload, db, user)
                    elif action == "history":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_history(payload, db, user)
                    elif action == "edit_message":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_edit_message(payload, db, user)
                    elif action == "delete_message":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_delete_message(payload, db, user)
                    elif action == "react":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_react(payload, db, user)
                    elif action == "post_comment":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_post_comment(payload, db, user)
                    elif action == "get_comments":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_comments(payload, db, user)
                    elif action == "init_upload":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_init_upload(payload, db, user)
                    elif action == "upload_chunk":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_upload_chunk(payload, db, user)

                    # --- POSTS ---
                    elif action == "create_post":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_create_post(payload, db, user)
                    elif action == "get_feed":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_feed(payload, db, user)
                    elif action == "react_post":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_react_post(payload, db, user)
                    elif action == "comment_post":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_comment_post(payload, db, user)
                    elif action == "get_post_comments":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_post_comments(payload, db, user)
                    elif action == "edit_post":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_edit_post(payload, db, user)
                    elif action == "delete_post":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_delete_post(payload, db, user)
                    elif action == "search":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_search(payload, db, user)

                    elif action == "initiate_call":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_initiate_call(payload, db, user)
                    elif action == "answer_call":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_answer_call(payload, db, user)
                    elif action == "end_call":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_end_call(payload, db, user)
                    elif action == "get_call":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_call(payload, db, user)

                    elif action == "get_invite_info":
                        result = await handle_get_invite_info(payload, db)
                    elif action == "join_chat":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_join_chat(payload, db, user)

                    elif action == "admin_list_users":
                        result = await handle_admin_list_users(payload, db)
                    elif action == "admin_get_user":
                        result = await handle_admin_get_user(payload, db)
                    elif action == "ban_user":
                        result = await handle_ban_user(payload, db)
                    elif action == "unban_user":
                        result = await handle_unban_user(payload, db)
                    elif action == "freeze_user":
                        result = await handle_freeze_user(payload, db)
                    elif action == "spam_block":
                        result = await handle_spam_block(payload, db)
                    elif action == "admin_clear_bio":
                        result = await handle_admin_clear_bio(payload, db)
                    elif action == "admin_list_chats":
                        result = await handle_admin_list_chats(payload, db)
                    elif action == "ban_chat":
                        result = await handle_ban_chat(payload, db)
                    elif action == "admin_delete_post":
                        result = await handle_admin_delete_post(payload, db)
                    elif action == "admin_list_posts":  
                        result = await handle_admin_list_posts(payload, db) 
                    elif action == "list_badges":
                        result = await handle_list_badges(payload, db)
                    elif action == "create_badge":
                        result = await handle_create_badge(payload, db)
                    elif action == "delete_badge":
                        result = await handle_delete_badge(payload, db)
                    elif action == "award_badge":
                        result = await handle_award_badge(payload, db)
                    elif action == "revoke_badge":
                        result = await handle_revoke_badge(payload, db)

                    elif action == "callback_query":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_callback_query(payload, db, user)

                    elif action == "ai_process_text":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_ai_process_text(payload, db, user)

                    elif action == "world_save":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_world_save(payload, db, user)
                    elif action == "world_load":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_world_load(payload, db, user)

                    else:
                        result = {"error": "Unknown action"}

                    err = result.get("error") if isinstance(result, dict) else None
                    await _send(websocket, {"action": action, "payload": result if not err else {}, "request_id": req_id, "error": err}, encrypt=True)
                    await db.commit()
                except Exception as e:
                    await db.rollback()
                    await _send(websocket, {"action": action, "payload": {}, "request_id": req_id, "error": str(e)}, encrypt=True)
    except WebSocketDisconnect:
        pass
    finally:
        if websocket in anonymous_connections:
            anonymous_connections.remove(websocket)
        if current_user_id and websocket in user_connections.get(current_user_id, []):
            user_connections[current_user_id].remove(websocket)
            if not user_connections[current_user_id]:
                user_connections.pop(current_user_id, None)
        # Clean up connection key
        connection_keys.pop(_ws_id(websocket), None)