import json, os, uuid, base64, aiofiles, httpx, shutil, asyncio, pickle
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Set, Tuple
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
    UserFCMToken, Report
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

# ── Active call registry (server-side signaling state) ───────────────────────
# room_id -> {
#   chat_id, initiator_id, callee_ids, started_at, message_id, is_video,
#   timeout_task, status ('ringing'|'active'|'ended')
# }
active_calls: Dict[str, dict] = {}
CALL_RINGING_TIMEOUT_SECONDS = 60

# ── Rate limiting ────────────────────────────────────────────────────────────
# Track action timestamps per connection: ws_id -> deque of timestamps
rate_limit_tracker: Dict[int, deque] = defaultdict(lambda: deque(maxlen=100))
# Track seen message IDs to prevent replay attacks: message_id -> expiry_time
seen_message_ids: Dict[str, datetime] = {}
MESSAGE_ID_TTL = 300  # 5 minutes

# ── Security logging ─────────────────────────────────────────────────────────
suspicious_activity_log = deque(maxlen=1000)  # Keep last 1000 events
reporting_bans: Dict[int, datetime] = {}
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

async def push_to_chat(db: AsyncSession, chat_id: int, payload: dict, exclude_user_id: Optional[int] = None, exclude_ws: Optional[WebSocket] = None, skip_offline_fcm: bool = False):
    """Push a message/event to all connected members of a chat, encrypted per connection.

    - exclude_user_id: still sends to other devices of that user (multi-device sync).
    - exclude_ws: excludes only a specific WebSocket connection (e.g. the sender's current tab).
    """
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.is_banned == False))
    member_ids = [m.user_id for m in r.scalars().all()]
    online_user_ids = set()
    for uid in member_ids:
        if uid == exclude_user_id:
            continue
        connections = user_connections.get(uid, [])
        if connections:
            online_user_ids.add(uid)
        for ws in connections:
            if exclude_ws is not None and ws is exclude_ws:
                continue
            encrypt = _ws_id(ws) in connection_keys
            await _send(ws, payload, encrypt=encrypt)

    # If caller asked to skip offline FCM (e.g. call pushes handled separately), do nothing more.
    if skip_offline_fcm:
        return

    # Push to offline members that are NOT the excluded sender.
    try:
        offline_uids = [uid for uid in member_ids if uid != exclude_user_id and uid not in online_user_ids]
        if offline_uids:
            tokens_req = await db.execute(select(UserFCMToken.fcm_token).where(UserFCMToken.user_id.in_(offline_uids)))
            tokens = list(set([row[0] for row in tokens_req.all() if row[0]]))
            if tokens:
                fcm_payload = {
                    "type": payload.get("action", "chat_event"),
                    "chat_id": str(chat_id),
                }
                inner = payload.get("payload", {})
                if isinstance(inner, dict):
                    if "message_id" in inner:
                        fcm_payload["message_id"] = str(inner["message_id"])
                    if "sender_name" in inner:
                        fcm_payload["sender_name"] = str(inner["sender_name"])
                chunked_tokens = [tokens[i:i + 500] for i in range(0, len(tokens), 500)]
                for chunk in chunked_tokens:
                    asyncio.create_task(asyncio.to_thread(send_push, chunk, "NiosMess", "New activity", fcm_payload))
    except Exception as e:
        print(f"[ERROR] push_to_chat offline FCM failed: {e}")

async def _get_user_and_session(db: AsyncSession, token: str) -> Tuple[Optional[User], Optional[Session]]:
    """Get user and their current session by token. Isolates devices."""
    if not token:
        return None, None
    session = await get_session_by_token(db, token)
    if session and session.is_active:
        user = await get_user_by_id(db, session.user_id)
        if user and user.is_active and not user.is_banned and not user.is_frozen:
            session.last_active = datetime.now(timezone.utc)
            return user, session
            
    # Bot token fallback (Bots don't have standard E2EE sessions, return None for session)
    bot_r = await db.execute(select(Bot).where(Bot.token == token))
    bot = bot_r.scalar_one_or_none()
    if bot:
        user = await get_user_by_id(db, bot.user_id)
        if user and user.is_active and not user.is_banned and not user.is_frozen:
            return user, None
            
    return None, None

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

async def handle_set_public_key(payload: dict, db: AsyncSession, user: User, session: Optional[Session]):
    public_key = payload.get("public_key")
    if not public_key or len(public_key) > 10000:
        return {"error": "Invalid public key"}
    
    if not session:
        return {"error": "No active session found for this device"}

    # Привязываем публичный ключ строго к ТЕКУЩЕМУ УСТРОЙСТВУ (СЕССИИ), а не к аккаунту!
    if not hasattr(session, "public_key"):
        return {"error": "Backend model missing public_key in Session. Run migrations."}
        
    session.public_key = public_key
    await db.flush()
    return {"message": "Public key set for this device successfully"}

async def handle_get_public_key(payload: dict, db: AsyncSession, user: User):
    user_id = payload.get("user_id")
    r = await db.execute(select(User).where(User.id == user_id))
    target = r.scalar_one_or_none()
    if not target:
        return {"error": "User not found"}

    # Отдаем список ВСЕХ активных устройств собеседника, у которых сгенерирован ключ
    sr = await db.execute(
        select(Session).where(
            Session.user_id == user_id, 
            Session.is_active == True,
            Session.public_key != None
        )
    )
    sessions = sr.scalars().all()
    
    devices = []
    for s in sessions:
        devices.append({
            "session_id": s.id,
            "device_info": s.device_info or "Unknown Device",
            "public_key": s.public_key
        })

    return {"user_id": target.id, "username": target.username, "devices": devices}

async def handle_erase_secret(payload: dict, db: AsyncSession):
    public_key = payload.get("public_key")
    if not public_key:
        return {"error": "Missing public_key"}

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
        messages_query = await db.execute(
            select(Message).where(Message.chat_id == chat.id)
        )
        messages = messages_query.scalars().all()
        msg_ids = [m.id for m in messages]

        if msg_ids:
            reactions_query = await db.execute(
                select(MessageReaction).where(MessageReaction.message_id.in_(msg_ids))
            )
            for reaction in reactions_query.scalars().all():
                await db.delete(reaction)

        for msg in messages:
            if getattr(msg, "media_path", None):
                full_path = os.path.join(settings.UPLOAD_DIR, msg.media_path)
                if os.path.exists(full_path):
                    try:
                        os.remove(full_path)
                        deleted_files_count += 1
                    except Exception as e:
                        print(f"[ERROR] Failed to delete file {full_path}: {e}")
            
            await db.delete(msg)

        members_query = await db.execute(
            select(ChatMember).where(ChatMember.chat_id == chat.id)
        )
        for member in members_query.scalars().all():
            await db.delete(member)

        unread_query = await db.execute(
            select(UnreadCounter).where(UnreadCounter.chat_id == chat.id)
        )
        for uc in unread_query.scalars().all():
            await db.delete(uc)

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

async def handle_list_chats(payload: dict, db: AsyncSession, user: User, session: Optional[Session]):
    # Берём публичный ключ ТЕКУЩЕГО девайса.
    client_public_key = getattr(session, "public_key", None) if session else None

    r = await db.execute(select(ChatMember).where(
        ChatMember.user_id == user.id, ChatMember.is_banned == False))
    result = []
    for m in r.scalars().all():
        cr = await db.execute(select(Chat).where(Chat.id == m.chat_id))
        chat = cr.scalar_one_or_none()
        if not chat or chat.is_banned:
            continue

        if chat.is_secret:
            if not client_public_key:
                continue  # Если на этом устройстве нет ключа, скрываем секретные чаты
                
            # Показываем секретный чат, ТОЛЬКО если он был создан для ЭТОГО устройства
            if chat.user1_id == user.id and chat.user1_public_key != client_public_key:
                continue  
            elif chat.user2_id == user.id and chat.user2_public_key != client_public_key:
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

                if chat.is_secret:
                    # Отдаем клиенту ключ конкретного устройства собеседника ИМЕННО ИЗ ЭТОГО ЧАТА
                    other_key = chat.user2_public_key if chat.user1_id == user.id else chat.user1_public_key
                    with_user_data = {
                        "id": other.id,
                        "username": other.username,
                        "display_name": other.display_name,
                        "avatar_url": avatar,
                        "public_key": other_key 
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

async def handle_open_direct(payload: dict, db: AsyncSession, user: User, session: Optional[Session]):
    username = str(payload.get("username", "")).lower()
    is_secret = payload.get("is_secret", False)  
    
    # Ключ нашего текущего устройства (из сессии)
    client_public_key = getattr(session, "public_key", None) if session else None
    
    # Ключ конкретного устройства собеседника (которое мы выбрали)
    target_public_key = payload.get("target_public_key")  

    ur = await db.execute(select(User).where(User.username == username))
    other = ur.scalar_one_or_none()
    if not other:
        return {"error": "User not found"}
    if other.id == user.id:
        return {"error": "Cannot DM yourself"}
    if user.spam_block:
        return {"error": "Spam-blocked accounts cannot initiate DMs."}

    if is_secret:
        if not client_public_key:
            return {"error": "Generate a public key on this device first (Settings -> Privacy)"}
        if not target_public_key:
            return {"error": "Target device public_key is required for secret chats"}

    u1, u2 = sorted([user.id, other.id])

    if is_secret:
        # Ищем секретный чат строго для ЭТОЙ пары устройств
        r = await db.execute(select(Chat).where(
            Chat.chat_type == ChatType.DIRECT,
            Chat.user1_id == u1,
            Chat.user2_id == u2,
            Chat.is_secret == True,
            or_(
                (Chat.user1_public_key == client_public_key) & (Chat.user2_public_key == target_public_key),
                (Chat.user1_public_key == target_public_key) & (Chat.user2_public_key == client_public_key)
            )
        ))
        chat = r.scalar_one_or_none()

        if not chat:
            # Создаем уникальный секретный чат для пары девайсов
            chat = Chat(
                chat_type=ChatType.DIRECT,
                user1_id=u1,
                user2_id=u2,
                is_secret=True
            )

            if user.id == u1:
                chat.user1_public_key = client_public_key
                chat.user2_public_key = target_public_key  
            else:
                chat.user1_public_key = target_public_key
                chat.user2_public_key = client_public_key

            db.add(chat)
            await db.flush()

            for uid in [u1, u2]:
                db.add(ChatMember(chat_id=chat.id, user_id=uid, role=MemberRole.MEMBER))
            await db.flush()
    else:
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
        other_summary["public_key"] = target_public_key

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

# ── Bots Helpers ───────────────────────────────────────────────────────────────

HELP_TEXT = (
    "📖 **Помощь по BotCreator**\n\n"
    "🔹 `/newbot` — Создать нового бота\n"
    "🔹 `/mybots` — Управление вашими ботами\n"
    "🔹 `/token <username>` — Получить полный токен бота\n"
    "🔹 `/deletebot <username>` — Удалить бота навсегда\n\n"
    "Кнопки в меню также дублируют эти команды."
)

async def _get_mybots_text(db: AsyncSession, user_id: int) -> str:
    """Безопасно собирает список ботов, принадлежащих конкретному пользователю."""
    try:
        if hasattr(Bot, 'owner_id'):
            q = select(Bot).where(Bot.owner_id == user_id)
        elif hasattr(Bot, 'creator_id'):
            q = select(Bot).where(Bot.creator_id == user_id)
        elif hasattr(Bot, 'created_by'):
            q = select(Bot).where(Bot.created_by == user_id)
        else:
            return "❌ Функция списка ботов временно недоступна (требуется обновление БД)."
            
        bots = await db.execute(q)
        rows = bots.scalars().all()
        if not rows:
            return "📭 У вас пока нет ботов. Создайте первого с помощью команды /newbot!"
        return "🤖 **Ваши боты:**\n\n" + "\n\n".join([f"🔹 **@{b.username}**\n🔑 Токен: `{b.token[:12]}...`" for b in rows])
    except Exception:
        return "❌ Произошла ошибка при загрузке ваших ботов."

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

async def _push_to_user(user_id: int, payload: dict, exclude_ws: Optional[WebSocket] = None):
    for ws in user_connections.get(user_id, []):
        if exclude_ws is not None and ws is exclude_ws:
            continue
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

    await asyncio.sleep(0.1)

    t = text.strip().lower()
    state = get_botcreator_state(user.id)
    reply_text = ""
    reply_markup = None

    if state and state.get("step") == "name":
        if not text.strip():
            reply_text = "⚠️ Пожалуйста, введите корректное имя для бота."
        else:
            state["name"] = text.strip()
            state["step"] = "username"
            reply_text = "✨ **Отлично!**\n\nТеперь выберите **username** (уникальное короткое имя) для бота.\nОно обязательно должно оканчиваться на `bot` или `_bot`. Например: `Nios_bot`"
            set_botcreator_state(user.id, state)
            
    elif state and state.get("step") == "username":
        uname = text.strip()
        if not uname.lower().endswith("bot"):
            reply_text = "⚠️ Username должен оканчиваться на `bot` или `_bot`. Попробуйте ещё раз."
        else:
            res = await create_bot(db, user.id, state["name"], uname)
            if res.get("error"):
                reply_text = f"❌ **Ошибка:** {res['error']}\n\nПопробуйте другой username."
            else:
                reply_text = (f"🎉 **Бот успешно создан!**\n\n"
                              f"👤 Имя: {res['name']}\n"
                              f"🔗 Username: @{res['username']}\n\n"
                              f"🔑 **Токен:**\n`{res['token']}`\n\n"
                              f"⚠️ *Никому не передавайте этот токен!* Используйте его для подключения бота.")
                clear_botcreator_state(user.id)
                
    elif t.startswith("/start") or t == "start":
        await asyncio.sleep(0.5)
        reply_text = ("👋 **Привет! Я BotCreator** — официальный помощник платформы.\n\n"
                      "Я помогу вам создать и настроить собственных ботов. Выберите действие ниже:")
        reply_markup = {"inline_keyboard": [
            [{"text": "Создать нового бота", "callback_data": "newbot"}],
            [{"text": "Мои боты", "callback_data": "mybots"}],
            [{"text": "Помощь", "callback_data": "help"}],
        ]}
        
    elif t == "/newbot" or t == "newbot":
        await asyncio.sleep(0.5)
        set_botcreator_state(user.id, {"step": "name"})
        reply_text = "🛠 **Создание бота**\n\nКак вы хотите назвать своего нового бота? (Это имя будет отображаться в чатах)"
        
    elif t.startswith("/mybots") or t == "mybots":
        await asyncio.sleep(0.5)
        reply_text = await _get_mybots_text(db, user.id)
        reply_markup = None
        
    elif t.startswith("/help") or t == "help":
        await asyncio.sleep(0.5)
        reply_text = HELP_TEXT
        reply_markup = None
        
    elif t.startswith("/token "):
        uname = text.split(None, 1)[1].strip().lower()
        br = await db.execute(select(Bot).where(Bot.username == uname))
        bot = br.scalar_one_or_none()
        if bot:
            reply_text = f"🔑 **Токен для @{bot.username}:**\n\n`{bot.token}`\n\n⚠️ Никогда не передавайте его третьим лицам!"
        else:
            reply_text = "❌ Бот не найден."
        reply_markup = None
        
    elif t.startswith("/deletebot "):
        uname = text.split(None, 1)[1].strip().lower()
        br = await db.execute(select(Bot).where(Bot.username == uname))
        bot = br.scalar_one_or_none()
        if bot:
            is_owner = False
            for attr in ('owner_id', 'creator_id', 'created_by'):
                if hasattr(bot, attr) and getattr(bot, attr) == user.id:
                    is_owner = True
                    break
                    
            if not is_owner and any(hasattr(bot, a) for a in ('owner_id', 'creator_id', 'created_by')):
                reply_text = "❌ Вы не являетесь владельцем этого бота."
            else:
                # ── БЕЗОПАСНАЯ КАСКАДНАЯ ОЧИСТКА ВСЕХ СВЯЗЕЙ БОТА В БД ──
                bot_user_id = bot.user_id
                
                # 1. Находим все сообщения, отправленные ботом
                msg_ids_q = await db.execute(select(Message.id).where(Message.sender_id == bot_user_id))
                msg_ids = [row[0] for row in msg_ids_q.all()]
                
                # 2. Удаляем реакции на сообщения бота и реакции самого бота
                if msg_ids:
                    await db.execute(delete(MessageReaction).where(MessageReaction.message_id.in_(msg_ids)))
                await db.execute(delete(MessageReaction).where(MessageReaction.user_id == bot_user_id))
                
                # 3. Физически удаляем файлы и записи сообщений бота
                if msg_ids:
                    try:
                        media_msgs_q = await db.execute(select(Message).where(Message.id.in_(msg_ids)))
                        for media_msg in media_msgs_q.scalars().all():
                            if getattr(media_msg, "media_path", None):
                                full_path = os.path.join(settings.UPLOAD_DIR, media_msg.media_path)
                                if os.path.exists(full_path):
                                    os.remove(full_path)
                    except Exception:
                        pass
                    await db.execute(delete(Message).where(Message.id.in_(msg_ids)))
                
                # 4. Удаляем участие бота во всех чатах
                await db.execute(delete(ChatMember).where(ChatMember.user_id == bot_user_id))
                
                # 5. Очищаем сессии и токены уведомлений бота
                await db.execute(delete(Session).where(Session.user_id == bot_user_id))
                await db.execute(delete(UserFCMToken).where(UserFCMToken.user_id == bot_user_id))
                
                # 6. Очищаем бейджи бота
                await db.execute(delete(UserBadge).where(UserBadge.user_id == bot_user_id))
                
                # 7. Жалобы, в которых фигурировал бот
                await db.execute(delete(Report).where((Report.reporter_id == bot_user_id) | (Report.reported_id == bot_user_id)))
                
                # 8. Накапливающиеся обновления для самого бота (BotUpdate)
                await db.execute(delete(BotUpdate).where(BotUpdate.bot_id == bot.id))
                
                # 9. Посты, комментарии и подписки бота (если они есть)
                await db.execute(delete(Subscription).where((Subscription.follower_id == bot_user_id) | (Subscription.followed_id == bot_user_id)))
                await db.execute(delete(PostComment).where(PostComment.author_id == bot_user_id))
                await db.execute(delete(PostReaction).where(PostReaction.user_id == bot_user_id))
                await db.execute(delete(Post).where(Post.author_id == bot_user_id))
                
                # 10. Отвязываем чаты, созданные ботом (чтобы не нарушать FK)
                try:
                    await db.execute(text("UPDATE chats SET created_by=NULL WHERE created_by=:uid").bindparams(uid=bot_user_id))
                except Exception:
                    pass
                
                # 11. Теперь, когда все зависимости удалены, безопасно удаляем системного пользователя и бота
                u_q = await db.execute(select(User).where(User.id == bot_user_id))
                user_row = u_q.scalar_one_or_none()
                if user_row:
                    await db.delete(user_row)
                await db.delete(bot)
                
                reply_text = f"🗑 **Бот @{uname} успешно удалён.**"
        else:
            reply_text = "❌ Бот не найден."
        reply_markup = None
        
    else:
        await asyncio.sleep(0.5)
        reply_text = ("ℹ️ **Я вас не понял.**\n\n"
                      "Отправьте /start для открытия меню или /help для списка команд.")
        reply_markup = {"inline_keyboard": [
            [{"text": "✨ Создать бота", "callback_data": "newbot"}],
            [{"text": "🤖 Мои боты", "callback_data": "mybots"}],
        ]}

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
    import inspect

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
        mr = await db.execute(select(Message).where(Message.id == message_id, Message.chat_id == chat_id))
        msg = mr.scalar_one_or_none()
        if not msg or not msg.reply_markup:
            return {"error": "Message or inline keyboard not found"}
            
        bot = await get_bot_by_user_id(db, msg.sender_id)
        if not bot:
            bot_r = await db.execute(select(Bot).where(Bot.user_id == msg.sender_id))
            bot = bot_r.scalar_one_or_none()
        if not bot:
            bot_r = await db.execute(select(Bot).where(Bot.id == msg.sender_id))
            bot = bot_r.scalar_one_or_none()

        if not bot:
            if msg.sender_id == get_botcreator_id():
                await asyncio.sleep(0.5)
                if data == "newbot":
                    set_botcreator_state(user.id, {"step": "name"})
                    reply_text = "🛠 **Создание бота**\n\nКак вы хотите назвать своего нового бота? (Это имя будет отображаться в чатах)"
                elif data == "mybots":
                    reply_text = await _get_mybots_text(db, user.id)
                elif data == "help":
                    reply_text = HELP_TEXT
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

        if inspect.iscoroutinefunction(build_callback_query_payload):
            update_payload = await build_callback_query_payload(db, user, msg, data)
        else:
            update_payload = build_callback_query_payload(db, user, msg, data)

        await queue_bot_update(db, bot.id, "callback_query", update_payload)
        await _push_to_user(bot.user_id, {"action": "callback_query", "payload": update_payload})
        
        return {"ok": True, "description": "Callback query sent to bot"}
        
    except Exception as e:
        print(f"[CRITICAL ERROR] handle_callback_query failed: {e}")
        return {"error": f"Internal helper failure: {str(e)}"}

async def _require_member(db, chat_id, user_id):
    r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == user_id, ChatMember.is_banned == False))
    if not r.scalar_one_or_none():
        raise ValueError("Not a member")

async def handle_send_message(payload: dict, db: AsyncSession, user: User, sender_ws: Optional[WebSocket] = None):
    chat_id = payload.get("chat_id")
    content = payload.get("content")
    e2ee_content = payload.get("e2ee_content")
    reply_to_id = payload.get("reply_to_id")
    upload_id = payload.get("upload_id")
    reply_markup = payload.get("reply_markup")
    await _can_send(db, chat_id, user.id)

    r = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = r.scalar_one_or_none()
    if not chat:
        return {"error": "Chat not found"}

    is_secret = chat.is_secret

    if not content and not e2ee_content and not upload_id:
        return {"error": "Message must have content or media"}

    msg = Message(chat_id=chat_id, sender_id=user.id, reply_to_id=reply_to_id, msg_type=MessageType.TEXT)

    if is_secret and e2ee_content:
        msg.e2ee_content = e2ee_content
        msg.is_e2ee = True
    elif content:
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

        encrypted_path = up.temp_path + ".enc"
        enc_meta = encrypt_file(up.temp_path, encrypted_path)

        try:
            os.remove(up.temp_path)
        except Exception:
            pass

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

    # Push to all chat members, including the sender's other devices (multi-device sync),
    # but exclude the current WebSocket tab to avoid duplicate UI entries.
    await push_to_chat(db, chat_id, {"action": "new_message", "payload": result}, exclude_ws=sender_ws)

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
                    'type': 'new_message',
                    'body': body_text,
                    'title': title,
                }

                chunked_tokens = [tokens[i:i+500] for i in range(0, len(tokens), 500)]
                for chunk in chunked_tokens:
                    asyncio.create_task(asyncio.to_thread(send_push, chunk, title, body_text, data_payload))
    except Exception as e:
        print(f"[ERROR] FCM Push preparation failed: {e}")

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
            
    await db.execute(delete(MessageReaction).where(MessageReaction.message_id == msg.id))
    
    if getattr(msg, "media_path", None):
        full_path = os.path.join(settings.UPLOAD_DIR, msg.media_path)
        if os.path.exists(full_path):
            try:
                os.remove(full_path)
            except Exception:
                pass

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

    if content and content.strip():
        ai_tags = await _generate_tags_for_post(content, media_path)
        if ai_tags:
            content = f"{content}\n\n{ai_tags}" if content else ai_tags

    if not content and not media_path:
        return {"error": "Post must have content or media"}

    post = Post(author_id=user.id, content=content, media_path=media_path)
    db.add(post)
    await db.flush()
    return {"message": "Post created successfully", "post_id": post.id}

async def _format_posts_for_feed(posts, user, db, page, limit, followed_ids):
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

    sub_q = await db.execute(select(Subscription.followed_id).where(Subscription.follower_id == user.id))
    followed_ids = set(row[0] for row in sub_q.all())

    if offset >= 500:
        q = select(Post).order_by(Post.created_at.desc()).limit(limit).offset(offset)
        fallback_posts = (await db.execute(q)).scalars().all()
        return await _format_posts_for_feed(fallback_posts, user, db, page, limit, followed_ids)

    liked_q = await db.execute(
        select(Post)
        .join(PostReaction, PostReaction.post_id == Post.id)
        .where(PostReaction.user_id == user.id, PostReaction.is_like == True)
        .order_by(PostReaction.id.desc())
        .limit(50)
    )
    liked_posts = liked_q.scalars().all()

    affinity_authors = Counter(p.author_id for p in liked_posts)
    top_authors = set(aid for aid, count in affinity_authors.most_common(10))

    liked_texts = " ".join(p.content for p in liked_posts if p.content).lower()
    hashtags = re.findall(r'#\w+', liked_texts)
    if hashtags:
        top_keywords = set(w for w, c in Counter(hashtags).most_common(10))
    else:
        words = re.findall(r'\b[a-zа-я]{5,}\b', liked_texts)
        top_keywords = set(w for w, c in Counter(words).most_common(15))

    pool_q = await db.execute(select(Post).order_by(Post.created_at.desc()).limit(500))
    pool_posts = pool_q.scalars().all()

    post_ids = [p.id for p in pool_posts]
    post_commenters = defaultdict(set)
    self_comment_counts = defaultdict(int)

    if post_ids:
        comments_q = await db.execute(
            select(PostComment.post_id, PostComment.author_id, func.count(PostComment.id))
            .where(PostComment.post_id.in_(post_ids))
            .group_by(PostComment.post_id, PostComment.author_id)
        )
        comments_data = comments_q.all()

        post_author_map = {p.id: p.author_id for p in pool_posts}

        for pid, aid, count in comments_data:
            post_commenters[pid].add(aid)
            if pid in post_author_map and aid == post_author_map[pid]:
                self_comment_counts[pid] = count

    now = datetime.now(timezone.utc)
    scored_posts = []

    for p in pool_posts:
        likes = p.likes_count or 0
        dislikes = p.dislikes_count or 0
        unique_other_commenters = len({uid for uid in post_commenters[p.id] if uid != p.author_id})
        
        test_interactions = likes + unique_other_commenters

        p_time = p.created_at.replace(tzinfo=timezone.utc) if p.created_at.tzinfo is None else p.created_at
        age_hours = max((now - p_time).total_seconds() / 3600.0, 0.0)

        is_follower = p.author_id in followed_ids
        is_favorite_author = p.author_id in top_authors
        
        has_interest_match = False
        if p.content:
            content_lower = p.content.lower()
            has_interest_match = any(kw in content_lower for kw in top_keywords)

        if test_interactions < 5 and age_hours < 24.0:
            if is_follower or has_interest_match or is_favorite_author:
                points = 8.0
                if is_follower:
                    points += 4.0
            else:
                points = 1.0

        elif test_interactions < 5 and age_hours >= 24.0:
            if is_follower:
                points = 1.5
            else:
                points = 0.2

        else:
            positive_signals = likes * 2.0 + unique_other_commenters * 3.0
            negative_signals = dislikes * 2.5
            
            points = 1.5 + positive_signals - negative_signals
            
            if is_follower:
                points += 8.0
            if has_interest_match:
                points += 4.0

        self_comments_qty = self_comment_counts.get(p.id, 0)
        if self_comments_qty >= 10:
            points *= 0.1  

        points = max(points, 0.1)

        gravity_exponent = 1.6
        final_score = points / ((age_hours + 2.0) ** gravity_exponent)
        
        scored_posts.append((final_score, p))

    scored_posts.sort(key=lambda x: x[0], reverse=True)
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
            if is_like:
                post.likes_count = max(0, post.likes_count - 1)
            else:
                post.dislikes_count = max(0, post.dislikes_count - 1)
            await db.delete(react)
            action = "removed"
        else:
            if is_like:
                post.dislikes_count = max(0, post.dislikes_count - 1)
                post.likes_count += 1
            else:
                post.likes_count = max(0, post.likes_count - 1)
                post.dislikes_count += 1
            react.is_like = is_like
            action = "switched"
    else:
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
    
    await db.execute(delete(PostReaction).where(PostReaction.post_id == post_id))
    await db.execute(delete(PostComment).where(PostComment.post_id == post_id))
    
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
        
    try:
        queries = [
            "UPDATE users SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE users SET updated_at = NULL WHERE updated_at LIKE '%None%'",
            "UPDATE users SET last_active = NULL WHERE last_active LIKE '%None%'",
            "UPDATE users SET last_login = NULL WHERE last_login LIKE '%None%'",
            "UPDATE badges SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE user_badges SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE sessions SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE sessions SET last_active = NULL WHERE last_active LIKE '%None%'",
            "UPDATE posts SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE post_comments SET created_at = NULL WHERE created_at LIKE '%None%'",
            "UPDATE user_fcm_tokens SET updated_at = NULL WHERE updated_at LIKE '%None%'"
        ]
        for q in queries:
            try:
                await db.execute(text(q))
            except Exception:
                pass
        await db.commit()
    except Exception:
        pass

    page = payload.get("page", 1)
    page_size = payload.get("page_size", 50)
    
    try:
        r = await db.execute(select(User).offset((page - 1) * page_size).limit(page_size))
        return [await _admin_user_row(db, u) for u in r.scalars().all()]
    except ValueError as e:
        return {"error": f"Data corruption in DB dates: {str(e)}"}


async def handle_admin_list_posts(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}

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

async def _toggle_status_badge(db: AsyncSession, user_id: int, badge_name: str, icon: str, color: str, award: bool):
    r = await db.execute(select(Badge).where(Badge.name == badge_name))
    badge = r.scalar_one_or_none()
    if not badge:
        badge = Badge(name=badge_name, description=f"Автоматический бейдж: {badge_name}", icon=icon, color=color)
        db.add(badge)
        await db.flush()
    
    ex = await db.execute(select(UserBadge).where(UserBadge.user_id == user_id, UserBadge.badge_id == badge.id))
    ub = ex.scalar_one_or_none()
    
    if award and not ub:
        db.add(UserBadge(user_id=user_id, badge_id=badge.id))
    elif not award and ub:
        await db.delete(ub)
        
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
    u.display_name = "Аккаунт заблокирован"
    await _toggle_status_badge(db, u.id, "Banned", "🚫", "#ef4444", award=True)
    
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
    await _toggle_status_badge(db, u.id, "Banned", "🚫", "#ef4444", award=False)
    
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
        u.display_name = "Аккаунт заморожен"
        await _toggle_status_badge(db, u.id, "Frozen", "❄️", "#3b82f6", award=True)
        sr = await db.execute(select(Session).where(Session.user_id == u.id))
        for s in sr.scalars().all():
            s.is_active = False
    else:
        await _toggle_status_badge(db, u.id, "Frozen", "❄️", "#3b82f6", award=False)
        
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

    try:
        await db.execute(text("UPDATE chats SET created_at = NULL WHERE created_at = 'None'"))
        await db.commit()
    except Exception:
        pass

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
    
    await db.execute(delete(PostReaction).where(PostReaction.post_id == post_id))
    await db.execute(delete(PostComment).where(PostComment.post_id == post_id))
    
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
    import base64
    import re

    has_image = False
    base64_image = None
    mime_type = "image/jpeg"

    if media_path:
        full_path = os.path.join(settings.UPLOAD_DIR, media_path)
        lower_path = media_path.lower()
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

    prompt_text = (
        "Проанализируй пост и сгенерируй 3-5 наиболее подходящих хештегов (тематик). "
        "Они должны быть на русском или английском языке в зависимости от контекста. "
        "Выдай ТОЛЬКО хештеги через пробел (например: #коты #еда #minecraft), без какого-либо дополнительного текста."
    )

    if has_image:
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
        if not content or not content.strip():
            return ""
        model = MISTRAL_MODEL
        payload_content = f"{prompt_text}\n\nТекст поста: {content}"

    async with httpx.AsyncClient() as client:
        for key in MISTRAL_API_KEYS:
            headers = {"Authorization": f"Bearer {key}", "Content-Type": "application/json"}
            payload = {
                "model": model,
                "messages": [{"role": "user", "content": payload_content}],
                "temperature": 0.3
            }
            try:
                response = await client.post(MISTRAL_API_URL, json=payload, headers=headers, timeout=25.0)
                response.raise_for_status()
                data = response.json()
                raw_tags = data["choices"][0]["message"]["content"].strip()
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
        prompt = f"Переведи следующий текст на язык: {target_language}. В ответе выдай ТОЛЬКО перевод, без кавычек:\n\n{text}"
    elif action == "correct":
        prompt = f"Исправь все грамматические ошибки в тексте. Сохрани оригинальный язык текста. В ответе выдай ТОЛЬКО исправленный текст:\n\n{text}"
    elif action == "formalize":
        prompt = f"Перепиши следующий текст в официально-деловом стиле. В ответе выдай ТОЛЬКО переписанный текст:\n\n{text}"
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

# ── Signaling Call Helpers ──────────────────────────────────────────────────

async def _finish_call(db: AsyncSession, room_id: str, was_missed: bool = False, duration: int = 0):
    """Finalize a call on server: update log message, broadcast end_call, cleanup registry."""
    call_info = active_calls.get(room_id)
    if not call_info or call_info.get("status") == "ended":
        return

    call_info["status"] = "ended"
    timeout_task = call_info.get("timeout_task")
    if timeout_task:
        try:
            timeout_task.cancel()
        except Exception:
            pass

    chat_id = call_info["chat_id"]
    message_id = call_info["message_id"]
    is_video = call_info.get("is_video", False)

    r = await db.execute(select(Message).where(Message.id == message_id, Message.chat_id == chat_id))
    msg = r.scalar_one_or_none()
    if msg:
        call_type = "📹 Видеозвонок" if is_video else "📞 Голосовой звонок"
        if was_missed:
            status_text = "Пропущен"
        else:
            status_text = f"Завершен ({duration} сек.)" if duration > 0 else "Завершен"
        text_content = f"{call_type} — {status_text}"
        enc = encrypt_text(text_content)
        msg.encrypted_content = enc["ciphertext"]
        msg.content_iv = enc["iv"]
        msg.content_tag = enc["tag"]
        msg.edited_at = datetime.now(timezone.utc)
        serialized_msg = await serialise_message(msg, db)

        end_payload = {
            "action": "end_call",
            "payload": {
                "chat_id": chat_id,
                "room_id": room_id,
                "message_id": message_id,
                "was_missed": was_missed,
                "duration": duration,
                "message": serialized_msg
            }
        }
        await push_to_chat(db, chat_id, {"action": "edit_message", "payload": serialized_msg})
        await push_to_chat(db, chat_id, end_payload)

    active_calls.pop(room_id, None)


async def _call_timeout_worker(room_id: str):
    """Wait 60 seconds; if call is still ringing, mark it as missed."""
    try:
        await asyncio.sleep(CALL_RINGING_TIMEOUT_SECONDS)
    except asyncio.CancelledError:
        return

    call_info = active_calls.get(room_id)
    if not call_info or call_info.get("status") != "ringing":
        return

    async with AsyncSessionLocal() as db:
        try:
            await _finish_call(db, room_id, was_missed=True, duration=0)
            await db.commit()
        except Exception as e:
            await db.rollback()
            print(f"[ERROR] call_timeout_worker failed: {e}")
        finally:
            active_calls.pop(room_id, None)


async def handle_start_call(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    room_id = payload.get("room_id")  # 32-значный hex комнаты от клиента
    caller_nickname = payload.get("caller_nickname", user.display_name)
    is_video = payload.get("is_video", False)

    if not chat_id or not room_id:
        return {"error": "chat_id and room_id are required"}

    await _can_send(db, chat_id, user.id)

    # Clean up any stale call in the same room (should not normally happen).
    if room_id in active_calls:
        active_calls.pop(room_id, None)

    # Создаем сообщение-лог в чате со статусом "Вызов..."
    call_type = "📹 Видеозвонок" if is_video else "📞 Голосовой звонок"
    text_content = f"{call_type} — Вызов..."
    enc = encrypt_text(text_content)

    msg = Message(
        chat_id=chat_id,
        sender_id=user.id,
        msg_type=MessageType.CALL_LOG,
        encrypted_content=enc["ciphertext"],
        content_iv=enc["iv"],
        content_tag=enc["tag"]
    )
    db.add(msg)
    await db.flush()

    serialized_msg = await serialise_message(msg, db)

    # Determine callee(s): all chat members except the initiator.
    members_req = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == chat_id,
        ChatMember.is_banned == False
    ))
    callee_ids = [m.user_id for m in members_req.scalars().all() if m.user_id != user.id]

    # Register the call server-side.
    active_calls[room_id] = {
        "chat_id": chat_id,
        "initiator_id": user.id,
        "callee_ids": callee_ids,
        "started_at": datetime.now(timezone.utc),
        "message_id": msg.id,
        "is_video": is_video,
        "status": "ringing",
        "timeout_task": asyncio.create_task(_call_timeout_worker(room_id)),
    }

    # Формируем пакет "new_call" для других участников чата (включая callee)
    new_call_payload = {
        "action": "new_call",
        "payload": {
            "chat_id": chat_id,
            "room_id": room_id,
            "message_id": msg.id,
            "caller_id": user.id,
            "caller_nickname": caller_nickname,
            "is_video": is_video,
            "message": serialized_msg
        }
    }

    # Рассылаем обычное сообщение-лог и сигнал "new_call" всем участникам, кроме инициатора.
    # Инициатору ответ придет отдельно в результате экшена.
    await push_to_chat(db, chat_id, {"action": "new_message", "payload": serialized_msg}, exclude_user_id=user.id, skip_offline_fcm=True)
    await push_to_chat(db, chat_id, new_call_payload, exclude_user_id=user.id, skip_offline_fcm=True)

    # Send FCM push to callee devices even when app is in background/killed.
    if callee_ids:
        try:
            tokens_req = await db.execute(select(UserFCMToken.fcm_token).where(UserFCMToken.user_id.in_(callee_ids)))
            tokens = list(set([row[0] for row in tokens_req.all() if row[0]]))
            if tokens:
                title = caller_nickname or "NiosMess"
                body = "📹 Видеозвонок" if is_video else "📞 Голосовой звонок"
                data_payload = {
                    "type": "incoming_call",
                    "chat_id": str(chat_id),
                    "room_id": str(room_id),
                    "message_id": str(msg.id),
                    "caller_id": str(user.id),
                    "caller_nickname": str(caller_nickname),
                    "is_video": str(bool(is_video)).lower(),
                }
                chunked_tokens = [tokens[i:i + 500] for i in range(0, len(tokens), 500)]
                for chunk in chunked_tokens:
                    asyncio.create_task(asyncio.to_thread(send_push, chunk, title, body, data_payload))
        except Exception as e:
            print(f"[ERROR] Call FCM push failed: {e}")

    return {
        "status": "ringing",
        "room_id": room_id,
        "message_id": msg.id,
        "message": serialized_msg
    }

async def handle_join_call(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    room_id = payload.get("room_id")
    message_id = payload.get("message_id")

    if not chat_id or not room_id or not message_id:
        return {"error": "chat_id, room_id, and message_id are required"}

    await _require_member(db, chat_id, user.id)

    call_info = active_calls.get(room_id)
    if call_info and call_info.get("status") == "ringing":
        call_info["status"] = "active"
        timeout_task = call_info.get("timeout_task")
        if timeout_task:
            try:
                timeout_task.cancel()
            except Exception:
                pass
        call_info["timeout_task"] = None

    # Находим лог-сообщение и переводим его в статус "Активен"
    r = await db.execute(select(Message).where(Message.id == message_id, Message.chat_id == chat_id))
    msg = r.scalar_one_or_none()
    if msg:
        try:
            decrypted = decrypt_text(msg.encrypted_content, msg.content_iv, msg.content_tag)
            call_type = "📹 Видеозвонок" if "Видеозвонок" in decrypted else "📞 Голосовой звонок"
        except Exception:
            call_type = "📞 Голосовой звонок"

        text_content = f"{call_type} — В процессе"
        enc = encrypt_text(text_content)
        msg.encrypted_content = enc["ciphertext"]
        msg.content_iv = enc["iv"]
        msg.content_tag = enc["tag"]
        msg.edited_at = datetime.now(timezone.utc)

        serialized_msg = await serialise_message(msg, db)

        # Рассылаем обновление сообщения и сигнал "join_call"
        join_payload = {
            "action": "join_call",
            "payload": {
                "chat_id": chat_id,
                "room_id": room_id,
                "message_id": message_id,
                "user_id": user.id,
                "display_name": user.display_name,
                "message": serialized_msg
            }
        }
        await push_to_chat(db, chat_id, {"action": "edit_message", "payload": serialized_msg})
        await push_to_chat(db, chat_id, join_payload, exclude_user_id=user.id)

        # Notify caller's other devices about pickup.
        await _push_to_user(user.id, {"action": "call_joined", "payload": join_payload["payload"]})

        return {"status": "active", "message": serialized_msg}

    return {"error": "Call message log not found"}

async def handle_end_call_signaling(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    room_id = payload.get("room_id")
    message_id = payload.get("message_id")
    duration = payload.get("duration", 0)  # в секундах
    was_missed = payload.get("was_missed", False)

    if not chat_id or not room_id or not message_id:
        return {"error": "chat_id, room_id, and message_id are required"}

    await _require_member(db, chat_id, user.id)

    await _finish_call(db, room_id, was_missed=was_missed, duration=duration)
    return {"status": "ended"}

# ── Автомодерация ИИ & Жалобы ──────────────────────────────────────────────────

ft_model = None
sklearn_model = None

try:
    import fasttext
    if os.path.exists("automod_model.bin"):
        ft_model = fasttext.load_model("automod_model.bin")
except ImportError:
    pass

try:
    if os.path.exists("automod_sklearn.pkl"):
        with open("automod_sklearn.pkl", "rb") as f:
            sklearn_model = pickle.load(f)
except Exception:
    pass


def _classify_text_local(text: str) -> str:
    if ft_model:
        try:
            labels, probabilities = ft_model.predict(text.replace("\n", " "), k=1)
            if probabilities[0] > 0.6:
                return labels[0].replace("__label__", "")
        except Exception:
            pass
            
    if sklearn_model:
        try:
            vec = sklearn_model["vectorizer"]
            clf = sklearn_model["model"]
            features = vec.transform([text])
            return clf.predict(features)[0]
        except Exception:
            pass
            
    return "clean"


async def _automod_check(db: AsyncSession, chat, reported_user, reporter_id: int, message_ids: List[int], reason: str) -> str:
    if reason == "spam":
        first_msg_q = await db.execute(
            select(Message).where(Message.chat_id == chat.id).order_by(Message.sent_at.asc()).limit(1)
        )
        first_msg = first_msg_q.scalar_one_or_none()
        
        if first_msg and first_msg.sender_id == reported_user.id:
            msgs_q = await db.execute(select(Message).where(Message.chat_id == chat.id))
            all_msgs = msgs_q.scalars().all()
            
            reporter_count = sum(1 for m in all_msgs if m.sender_id == reporter_id)
            reported_count = sum(1 for m in all_msgs if m.sender_id == reported_user.id)
            
            if reporter_count <= 2 and reported_count >= 3:
                return "spam_detected"

    if chat.is_secret:
        return "clean"

    # Извлекаем последние 15 сообщений для контекста
    context_msgs = []
    try:
        context_q = await db.execute(
            select(Message)
            .where(Message.chat_id == chat.id)
            .order_by(Message.id.desc())
            .limit(15)
        )
        context_msgs = list(reversed(context_q.scalars().all()))
    except Exception as e:
        print(f"[Automod Context Fetch Error]: {e}")

    # ── 1. ДЕТЕРМИНИРОВАННАЯ (АЛГОРИТМИЧЕСКАЯ) ПРОВЕРКА НА ЗЕРКАЛИРОВАНИЕ ──
    # Собираем все тексты сообщений РЕПОРТЕРА из контекста
    reporter_texts = []
    for m in context_msgs:
        if m.sender_id == reporter_id and m.encrypted_content:
            try:
                dec = decrypt_text(m.encrypted_content, m.content_iv, m.content_tag)
                dec_clean = dec.strip().lower()
                if dec_clean:
                    reporter_texts.append(dec_clean)
            except Exception:
                pass

    # Собираем тексты ЖАЛОБНЫХ сообщений подозреваемого
    reported_texts = []
    if message_ids:
        try:
            msgs_q = await db.execute(select(Message).where(Message.id.in_(message_ids), Message.chat_id == chat.id))
            for msg in msgs_q.scalars().all():
                if msg.encrypted_content:
                    dec = decrypt_text(msg.encrypted_content, m.content_iv, m.content_tag)
                    dec_clean = dec.strip().lower()
                    if dec_clean:
                        reported_texts.append(dec_clean)
        except Exception:
            pass

    # Если массив message_ids пуст, подстрахуемся и проверим последнее сообщение подозреваемого в контексте
    if not reported_texts:
        for m in reversed(context_msgs):
            if m.sender_id == reported_user.id and m.encrypted_content:
                try:
                    dec = decrypt_text(m.encrypted_content, m.content_iv, m.content_tag)
                    dec_clean = dec.strip().lower()
                    if dec_clean:
                        reported_texts.append(dec_clean)
                        break
                except Exception:
                    pass

    # Проверяем, продублировал ли подозреваемый сообщение репортера (или его часть)
    is_mirroring = False
    for r_text in reported_texts:
        if r_text in reporter_texts:
            is_mirroring = True
            break
        # Проверим частичное совпадение (длиной > 5 символов, чтобы избежать ложных совпадений на "да", "ок")
        for rep_text in reporter_texts:
            if len(r_text) > 5 and (r_text in rep_text or rep_text in r_text):
                is_mirroring = True
                break

    # Если обнаружено прямое копирование текста репортера — это 100% провокация
    if is_mirroring:
        return "provocation_detected"

    # ── 2. АНАЛИЗ КОНТЕКСТА С ПОМОЩЬЮ ИИ (ЕСЛИ КОПИРОВАНИЕ НЕОЧЕВИДНОЕ) ──
    try:
        transcript_lines = []
        for m in context_msgs:
            content = ""
            if m.encrypted_content:
                try:
                    content = decrypt_text(m.encrypted_content, m.content_iv, m.content_tag)
                except Exception:
                    content = "[Decryption Failed]"
            elif m.media_path:
                content = f"[Media: {m.media_name}]"
            else:
                content = "[No text content]"

            sender_q = await db.execute(select(User.username).where(User.id == m.sender_id))
            sender_uname = sender_q.scalar_one_or_none() or f"User_{m.sender_id}"
            transcript_lines.append(f"ID: {m.sender_id} (@{sender_uname}): {content}")

        combined_transcript = "\n".join(transcript_lines)
        
        if combined_transcript.strip():
            prompt = (
    f"Ты — строгий AI-модератор. Тебе нужно проанализировать переписку и определить, "
    f"является ли жалоба со стороны Репортера (ID: {reporter_id}) на Подозреваемого (ID: {reported_user.id}) провокацией (подстрекательством).\n\n"
    f"ОПИСАНИЕ ТИПОВ НАРУШЕНИЙ:\n"
    f"Тип 'scam' (мошенничество): обман на деньги, фишинг, финансовые пирамиды, фейковые инвестиции, вымогательство, обманные ссылки.\n"
    f"Тип 'illegal' (нелегал): продажа наркотиков, поиск «кладменов» / «трафаретчиков» / наркокурьеров, оружие, поддельные документы, экстремизм.\n\n"
    f"ОБХОД ФИЛЬТРОВ И ЗАВУАЛИРОВАННЫЙ СЛЕНГ:\n"
    f"Нарушители часто используют маскировку текста, транслит, смесь латиницы и кириллицы, намеренные опечатки или специфический сленг "
    f"для предложения незаконной работы или мошенничества. Обращай внимание на такие завуалированные фразы и приравнивай их к прямому нарушению:\n"
    f"- Предложение сомнительной работы/скама: 'priвеt xoчеub ворк????', 'vork', 'wоrk', 'р_а_б_о_т_а', 'тема на 50к', 'есть темка/прогрев'.\n"
    f"- Поиск курьеров/кладменов: 'kлaд', 'курьер', 'набираю спортиков', 'граффити/трафареты', 'мины'.\n\n"
    f"ОПИСАНИЕ ПРОВОКАЦИИ:\n"
    f"Провокация — это когда Репортер (ID: {reporter_id}) сам просит, заставляет, умоляет, манипулирует или явно "
    f"подстрекает Подозреваемого (ID: {reported_user.id}) написать запрещенный контент (например, написать нелегальное предложение, скинуть ссылку на наркотики/скам, написать фишинг-ссылку), "
    f"чтобы потом отправить на него репорт и забанить.\n"
    f"Также ПРОВОКАЦИЕЙ считается, если Репортер сам первым отправляет запрещенную или завуалированную фразу (например, 'продам наркотики' или 'priвеt xoчеub ворк????'), а Подозреваемый просто зеркально копирует, дублирует или повторяет её в чате.\n\n"
    f"ИСТОРИЯ ПЕРЕПИСКИ (в хронологическом порядке):\n"
    f"{combined_transcript}\n\n"
    f"ТИП НАРУШЕНИЯ ДЛЯ ПРОВЕРКИ: {reason}\n\n"
    f"ПРАВИЛА ОЦЕНКИ:\n"
    f"1. Тщательно изучи переписку. Кто первый начал говорить о запрещенном (включая завуалированный сленг и транслит)? Репортер (ID: {reporter_id}) просил/провоцировал/подстрекал Подозреваемого (ID: {reported_user.id}) написать запрещенку, или сам первый её написал, а Подозреваемый её скопировал?\n"
    f"2. Если Репортер (ID: {reporter_id}) спровоцировал Подозреваемого или сам первый написал это нарушение (включая завуалированные фразы вроде 'priвеt xoчеub ворк????'), ответь строго 'PROVOKER_DETECTED'.\n"
    f"3. Если Подозреваемый (ID: {reported_user.id}) действительно совершил нарушение типа {reason} САМ, по своей инициативе (включая отправку завуалированных предложений первым), без провокации/манипуляций Репортера и без зеркального копирования его фраз, ответь строго 'TARGET_DETECTED'.\n"
    f"4. Если в переписке нет нарушений указанного типа ({reason}), ответь строго 'CLEAN'.\n\n"
    f"Ответь строго ОДНИМ словом: PROVOKER_DETECTED, TARGET_DETECTED или CLEAN (без точек, кавычек и пояснений)."
            )
            res = await _call_mistral(prompt)
            res_clean = res.strip().upper()
            
            if "PROVOKER_DETECTED" in res_clean:
                return "provocation_detected"
            elif "TARGET_DETECTED" in res_clean:
                return f"{reason}_detected"
            elif "CLEAN" in res_clean:
                return "clean"
    except Exception as e:
        print(f"[Automod Mistral Context Check Error]: {e}")

    # ── 3. ФОЛЛБЕК НА ЛОКАЛЬНУЮ КЛАССИФИКАЦИЮ (ЕСЛИ ИИ И ЗЕРКАЛИРОВАНИЕ НЕ ДАЛИ ОТВЕТА) ──
    combined_text = " ".join(reported_texts).strip()
    if combined_text:
        local_label = _classify_text_local(combined_text)
        if local_label == reason:
            return f"{reason}_detected"

    return "clean"


async def handle_report(payload: dict, db: AsyncSession, user: User):
    chat_id = payload.get("chat_id")
    reported_id = payload.get("reported_user_id")
    message_ids = payload.get("message_ids", [])
    reason = payload.get("reason")

    if reason not in ("spam", "scam", "illegal"):
        return {"error": "Invalid report reason"}

    # ── ПРОВЕРКА НАЛИЧИЯ ВРЕМЕННОГО БАНА НА ЖАЛОБЫ ──
    now = datetime.now(timezone.utc)
    if user.id in reporting_bans:
        expiry = reporting_bans[user.id]
        if now < expiry:
            remaining = expiry - now
            hours = int(remaining.total_seconds() // 3600)
            minutes = int((remaining.total_seconds() % 3600) // 60)
            return {
                "error": f"Вы временно лишены возможности отправлять жалобы за злоупотребление или провокации. До разблокировки осталось: {hours}ч {minutes}м."
            }
        else:
            # Срок бана истек, удаляем из списка
            reporting_bans.pop(user.id, None)

    # ── ЗАЩИТА СИСТЕМНЫХ АККАУНТОВ ОТ ЖАЛОБ ──
    protected_ids = {1, 2, 20}
    bc_id = get_botcreator_id()
    if bc_id:
        protected_ids.add(bc_id)

    if reported_id in protected_ids:
        return {"error": "Эти системные аккаунты не могут быть зарепорчены."}

    chat_q = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = chat_q.scalar_one_or_none()
    if not chat:
        return {"error": "Chat not found"}

    # ── ЗАПРЕТ ЖАЛОБ ИЗ СЕКРЕТНЫХ ЧАТОВ ──
    if chat.is_secret:
        return {"error": "Вы в секретном чате, подать жалобу не возможно. Сохраните материал и отправьте в поддержку: ni-os.ru/support"}

    reported_q = await db.execute(select(User).where(User.id == reported_id))
    reported_user = reported_q.scalar_one_or_none()
    if not reported_user:
        return {"error": "Reported user not found"}

    # Запускаем контекстный анализ ИИ
    verdict = await _automod_check(db, chat, reported_user, user.id, message_ids, reason)

    if verdict == "provocation_detected":
        # 1. Выдаем запрет на отправку жалоб репортеру на 3 часа
        reporting_bans[user.id] = datetime.now(timezone.utc) + timedelta(hours=3)

        # 2. Физически удаляем сообщения подозреваемого, где зафиксировано нарушение
        if message_ids:
            try:
                msgs_to_delete = await db.execute(
                    select(Message).where(Message.id.in_(message_ids), Message.chat_id == chat_id)
                )
                for msg_to_del in msgs_to_delete.scalars().all():
                    # Удаляем связанные реакции
                    await db.execute(delete(MessageReaction).where(MessageReaction.message_id == msg_to_del.id))
                    # Удаляем медиафайлы при их наличии
                    if getattr(msg_to_del, "media_path", None):
                        full_path = os.path.join(settings.UPLOAD_DIR, msg_to_del.media_path)
                        if os.path.exists(full_path):
                            try:
                                os.remove(full_path)
                            except Exception:
                                pass
                    # Удаляем само сообщение
                    await db.delete(msg_to_del)
                await db.flush()
            except Exception as e:
                print(f"[Error] Failed to auto-delete bait messages: {e}")

        # Записываем жалобу в историю с соответствующим вердиктом
        report = Report(
            reporter_id=user.id,
            reported_id=reported_user.id,
            chat_id=chat.id,
            reason=reason,
            automod_verdict=verdict,
            reported_messages_json=json.dumps(message_ids)
        )
        db.add(report)
        await db.flush()

        # 3. Выводим предупреждение о провокации
        return {"error": "Судя по контексту, вы сами спровоцировали пользователя на нарушение."}

    # Стандартная обработка, если провокации не было обнаружено
    elif verdict == "spam_detected":
        reported_user.spam_block = True
    elif verdict in ("scam_detected", "illegal_detected"):
        reported_user.is_frozen = True
        reported_user.display_name = "Аккаунт заморожен"
        await _toggle_status_badge(db, reported_user.id, "Frozen", "❄️", "#3b82f6", award=True)
        
        sess_q = await db.execute(select(Session).where(Session.user_id == reported_user.id))
        for s in sess_q.scalars().all():
            s.is_active = False

    report = Report(
        reporter_id=user.id,
        reported_id=reported_user.id,
        chat_id=chat.id,
        reason=reason,
        automod_verdict=verdict,
        reported_messages_json=json.dumps(message_ids)
    )
    db.add(report)
    await db.flush()

    return {
        "status": "success",
        "report_id": report.id,
        "automod_verdict": verdict,
        "message": "Report processed"
    }
async def handle_get_file(payload: dict, db: AsyncSession, user: User):
    file_path = payload.get("file_path")
    if not file_path:
        return {"error": "file_path is required"}
        
    # Защита от выхода за пределы директории (Directory Traversal)
    file_path = file_path.replace("\\", "/").replace("../", "")
    db_path = file_path

    # 1. Проверяем, привязан ли файл к какому-то сообщению
    from app.models.models import Message, ChatMember
    r = await db.execute(select(Message).where(Message.media_path == db_path))
    msg = r.scalar_one_or_none()
    
    if not msg:
        return {"error": "File not found or not associated with any chat"}
        
    # 2. Проверяем, состоит ли запрашивающий пользователь в чате этого сообщения
    mem_r = await db.execute(select(ChatMember).where(
        ChatMember.chat_id == msg.chat_id,
        ChatMember.user_id == user.id,
        ChatMember.is_banned == False
    ))
    if not mem_r.scalar_one_or_none():
        return {"error": "You're fucked up: You are not a member of this chat"}

    # 3. Читаем физический файл с диска
    full_path = os.path.join(settings.UPLOAD_DIR, file_path)
    enc_path = full_path + ".enc"
    target_path = enc_path if os.path.exists(enc_path) else full_path
    
    if not os.path.exists(target_path):
        return {"error": "Physical file not found on server"}
        
    async with aiofiles.open(target_path, "rb") as f:
        file_bytes = await f.read()

    # 4. Если чат обычный (серверное шифрование), расшифровываем байты на стороне сервера
    if not msg.is_e2ee and msg.media_iv and msg.media_tag:
        from app.services.encryption import decrypt_file_to_bytes
        try:
            file_bytes = decrypt_file_to_bytes(target_path, msg.media_iv, msg.media_tag)
        except Exception as e:
            return {"error": f"Failed to decrypt file on server: {str(e)}"}

    # 5. Кодируем в Base64 для передачи по WebSocket
    file_b64 = base64.b64encode(file_bytes).decode("utf-8")
    
    return {
        "file_path": file_path,
        "filename": msg.media_name,
        "mime_type": msg.media_type or "application/octet-stream",
        "is_e2ee": msg.is_e2ee, # Если True, клиент должен расшифровать локально своим E2EE-ключом
        "data_base64": file_b64
    }
async def handle_admin_list_reports(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}

    r_q = await db.execute(select(Report).order_by(Report.id.desc()))
    reports = r_q.scalars().all()
    
    result = []
    for r in reports:
        rep_user_q = await db.execute(select(User).where(User.id == r.reporter_id))
        reported_user_q = await db.execute(select(User).where(User.id == r.reported_id))
        chat_q = await db.execute(select(Chat).where(Chat.id == r.chat_id))
        
        rep_u = rep_user_q.scalar_one_or_none()
        red_u = reported_user_q.scalar_one_or_none()
        ch = chat_q.scalar_one_or_none()
        
        result.append({
            "id": r.id,
            "reporter_username": rep_u.username if rep_u else "Unknown",
            "reported_id": r.reported_id,
            "reported_username": red_u.username if red_u else "Unknown",
            "reported_is_frozen": red_u.is_frozen if red_u else False,
            "reported_spam_block": red_u.spam_block if red_u else False,
            "reported_is_banned": red_u.is_banned if red_u else False,
            "chat_id": r.chat_id,
            "chat_name": ch.name if ch else f"DM {r.chat_id}",
            "chat_is_secret": ch.is_secret if ch else False,
            "reason": r.reason,
            "status": r.status,
            "automod_verdict": r.automod_verdict,
            "created_at": r.created_at.isoformat() if r.created_at else None
        })
    return result


async def handle_admin_resolve_report(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}

    report_id = payload.get("report_id")
    action = payload.get("action")
    
    rep_q = await db.execute(select(Report).where(Report.id == report_id))
    report = rep_q.scalar_one_or_none()
    if not report:
        return {"error": "Report not found"}

    user_q = await db.execute(select(User).where(User.id == report.reported_id))
    user = user_q.scalar_one_or_none()
    if not user:
        return {"error": "User not found"}

    if action == "ban":
        user.is_banned = True
        user.is_frozen = False
        user.display_name = "Аккаунт заблокирован"
        await _toggle_status_badge(db, user.id, "Banned", "🚫", "#ef4444", award=True)
        await _toggle_status_badge(db, user.id, "Frozen", "❄️", "#3b82f6", award=False)
        
        sess_q = await db.execute(select(Session).where(Session.user_id == user.id))
        for s in sess_q.scalars().all():
            s.is_active = False
    elif action == "unfreeze":
        user.is_frozen = False
        await _toggle_status_badge(db, user.id, "Frozen", "❄️", "#3b82f6", award=False)
    elif action == "keep_spam":
        user.spam_block = True
    elif action == "remove_spam":
        user.spam_block = False
    elif action == "dismiss":
        pass
    else:
        return {"error": "Unknown action"}

    report.status = "resolved"
    await db.flush()
    return {"message": "Report resolved successfully", "status": "resolved"}


async def handle_admin_get_reported_chat_history(payload: dict, db: AsyncSession):
    try:
        _admin_check(payload.get("password"))
    except Exception as e:
        return {"error": str(e)}

    chat_id = payload.get("chat_id")
    chat_q = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = chat_q.scalar_one_or_none()
    if not chat:
        return {"error": "Chat not found"}

    if chat.is_secret:
        return {"error": "Secret chats are E2EE. Encryption is done on clients, messages cannot be read by admin."}

    msg_q = await db.execute(
        select(Message)
        .where(Message.chat_id == chat_id)
        .order_by(Message.sent_at.asc())
        .limit(100)
    )
    result = []
    for msg in msg_q.scalars().all():
        sender_q = await db.execute(select(User).where(User.id == msg.sender_id))
        sender = sender_q.scalar_one_or_none()
        
        content = "[Encrypted or media]"
        if msg.encrypted_content:
            try:
                content = decrypt_text(msg.encrypted_content, msg.content_iv, msg.content_tag)
            except Exception:
                content = "[Decryption Failed]"
        elif msg.media_path:
            content = f"[Media: {msg.media_name}]"

        result.append({
            "id": msg.id,
            "sender_username": sender.username if sender else "Unknown",
            "content": content,
            "sent_at": msg.sent_at.isoformat() if msg.sent_at else None
        })
    return result

# ── Main dispatcher ────────────────────────────────────────────────────────────

_botcreator_initialized = False

async def _init_system_accounts(db: AsyncSession):
    """Инициализация и восстановление прав и имён у системных аккаунтов (BotCreator и админы)"""
    global _botcreator_initialized
    if _botcreator_initialized:
        return
        
    bc_id = get_botcreator_id()
    sys_ids = {1, 2, 20}
    if bc_id:
        sys_ids.add(bc_id)
        
    for sys_id in sys_ids:
        sys_r = await db.execute(select(User).where(User.id == sys_id))
        sys_user = sys_r.scalar_one_or_none()
        if sys_user:
            if sys_id == bc_id or sys_id == 20:
                sys_user.display_name = "BotCreator"
            sys_user.is_frozen = False
            sys_user.is_banned = False
            sys_user.spam_block = False
            await _toggle_status_badge(db, sys_user.id, "Frozen", "❄️", "#3b82f6", award=False)
            await _toggle_status_badge(db, sys_user.id, "Banned", "🚫", "#ef4444", award=False)
    
    await db.flush()
    _botcreator_initialized = True

async def ws_endpoint(websocket: WebSocket):
    await websocket.accept()
    anonymous_connections.append(websocket)
    current_user_id = None
    current_token = None
    current_session = None

    conn_key = generate_connection_key()
    connection_keys[_ws_id(websocket)] = conn_key
    await _send(websocket, {"action": "key_exchange", "key": conn_key}, encrypt=False)

    try:
        while True:
            raw = await websocket.receive_text()

            data = _decrypt_received(websocket, raw)
            if data is None:
                log_suspicious_activity(websocket, "DECRYPTION_FAILED", "Invalid message")
                await _send(websocket, {"action": "error", "error": "Invalid message", "payload": {}}, encrypt=True)
                continue

            action = data.get("action")
            payload = data.get("payload", {})
            req_id = data.get("request_id")
            token = data.get("token")
            message_id = data.get("message_id")

            if not action or not isinstance(action, str) or len(action) > 64:
                log_suspicious_activity(websocket, "INVALID_ACTION", f"Action: {action}")
                await _send(websocket, {"action": "error", "error": "Invalid action", "payload": {}}, encrypt=True)
                continue

            if not _check_replay_attack(message_id):
                log_suspicious_activity(websocket, "REPLAY_ATTACK", f"Message ID: {message_id}")
                await _send(websocket, {"action": "error", "error": "Replay detected", "payload": {}}, encrypt=True)
                continue

            async with AsyncSessionLocal() as db:
                try:
                    if not _botcreator_initialized:
                        await _init_system_accounts(db)

                    # Получаем пользователя И текущую сессию
                    user, session_data = await _get_user_and_session(db, token) if token else (None, None)
                    current_session = session_data

                    if user and current_user_id != user.id:
                        current_user_id = user.id
                        if websocket in anonymous_connections:
                            anonymous_connections.remove(websocket)
                        user_connections.setdefault(user.id, []).append(websocket)
                    result = {}

                    if action == "register":
                        if not _check_rate_limit(websocket, max_per_minute=60):
                            log_suspicious_activity(websocket, "RATE_LIMIT_EXCEEDED", "Limit reached")
                            await _send(websocket, {"action": "error", "error": "Rate limit exceeded", "payload": {}}, encrypt=True)
                            continue
                        result = await handle_register(payload, db)
                    elif action == "verify_email":
                        result = await handle_verify_email(payload, db)
                    elif action == "login":
                        if not _check_rate_limit(websocket, max_per_minute=60):
                            log_suspicious_activity(websocket, "RATE_LIMIT_EXCEEDED", "Limit reached")
                            await _send(websocket, {"action": "error", "error": "Rate limit exceeded", "payload": {}}, encrypt=True)
                            continue
                        result = await handle_login(payload, db)
                        if "access_token" in result and "error" not in result:
                            current_token = result["access_token"]
                            user2, session2 = await _get_user_and_session(db, current_token)
                            if user2:
                                current_user_id = user2.id
                                current_session = session2
                                if websocket in anonymous_connections:
                                    anonymous_connections.remove(websocket)
                                user_connections.setdefault(user2.id, []).append(websocket)
                    elif action == "verify_2fa":
                        result = await handle_verify_2fa(payload, db)
                        if "access_token" in result and "error" not in result:
                            current_token = result["access_token"]
                            user2, session2 = await _get_user_and_session(db, current_token)
                            if user2:
                                current_user_id = user2.id
                                current_session = session2
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
                            current_session = None
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

                    elif action == "follow_user":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_follow_user(payload, db, user)
                    elif action == "unfollow_user":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_unfollow_user(payload, db, user)

                    elif action == "set_public_key":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_set_public_key(payload, db, user, current_session)
                    elif action == "get_public_key":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_public_key(payload, db, user)
                    
                    elif action == "erase_secret":
                        result = await handle_erase_secret(payload, db)

                    elif action == "list_chats":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_list_chats(payload, db, user, current_session)
                    elif action == "open_direct":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_open_direct(payload, db, user, current_session)
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
                        result = await handle_send_message(payload, db, user, websocket)
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
                    elif action == "get_file":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_get_file(payload, db, user)
                    
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

                    elif action == "start_call":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_start_call(payload, db, user)
                    elif action == "join_call":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_join_call(payload, db, user)
                    elif action == "end_call":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_end_call_signaling(payload, db, user)

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

                    elif action == "report":
                        if not user: raise ValueError("Unauthorized")
                        result = await handle_report(payload, db, user)
                    elif action == "admin_list_reports":
                        result = await handle_admin_list_reports(payload, db)
                    elif action == "admin_resolve_report":
                        result = await handle_admin_resolve_report(payload, db)
                    elif action == "admin_get_reported_chat_history":
                        result = await handle_admin_get_reported_chat_history(payload, db)

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
        connection_keys.pop(_ws_id(websocket), None)