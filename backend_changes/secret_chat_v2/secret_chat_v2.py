"""Durable, device-bound secret-chat protocol. No plaintext message bodies."""
import base64
import hashlib
import json
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import UUID, uuid4

from sqlalchemy import Column, Integer, String, Text, UniqueConstraint, select
from app.models.models import Base, Chat, ChatMember, Message, MessageType, Session

PROTOCOL_VERSION = 2


class SecretDeviceCapability(Base):
    __tablename__ = 'secret_device_capabilities'
    user_id = Column(Integer, primary_key=True)
    public_key = Column(String(128), primary_key=True)
    protocol_version = Column(Integer, nullable=False, default=0)


class SecretOperation(Base):
    __tablename__ = 'secret_operations'
    chat_id = Column(Integer, primary_key=True)
    sender_id = Column(Integer, primary_key=True)
    client_id = Column(String(36), primary_key=True)
    request_hash = Column(String(64), nullable=False)
    response_json = Column(Text, nullable=False)


class SecretEvent(Base):
    __tablename__ = 'secret_events'
    __table_args__ = (UniqueConstraint('chat_id', 'sender_id', 'client_id'),
                      {'sqlite_autoincrement': True})
    id = Column(Integer, primary_key=True, autoincrement=True)
    chat_id = Column(Integer, nullable=False, index=True)
    sender_id = Column(Integer, nullable=False)
    client_id = Column(String(36), nullable=False)
    kind = Column(String(16), nullable=False)
    payload_json = Column(Text, nullable=False)


class SecretLegacyCursor(Base):
    __tablename__ = 'secret_legacy_cursors'
    chat_id = Column(Integer, primary_key=True)
    message_id = Column(Integer, nullable=False, default=0)


def _uuid(value):
    try:
        return str(UUID(str(value)))
    except (ValueError, TypeError, AttributeError):
        raise ValueError('SECRET_INVALID_CLIENT_ID') from None


async def require_bound_device(db, chat_id, user, session):
    chat = await db.get(Chat, int(chat_id))
    member = await db.scalar(select(ChatMember.id).where(
        ChatMember.chat_id == chat_id, ChatMember.user_id == user.id,
        ChatMember.is_banned == False))
    if not chat or not chat.is_secret or not member or chat.is_banned:
        raise ValueError('SECRET_CHAT_UNAVAILABLE')
    key = chat.user1_public_key if chat.user1_id == user.id else chat.user2_public_key
    if (session is None or session.user_id != user.id or not session.is_active
            or not key or session.public_key != key):
        raise ValueError('SECRET_DEVICE_MISMATCH')
    return chat


async def register_capability(db, user, session, version):
    if not session or not session.public_key:
        return
    identity = (user.id, session.public_key)
    row = await db.get(SecretDeviceCapability, identity)
    if row is None:
        row = SecretDeviceCapability(user_id=user.id, public_key=session.public_key)
        db.add(row)
    row.protocol_version = PROTOCOL_VERSION if version == PROTOCOL_VERSION else 0
    await db.flush()


async def _append_event(db, chat_id, user_id, client_id, kind, payload):
    event = SecretEvent(chat_id=chat_id, sender_id=user_id, client_id=client_id,
                        kind=kind, payload_json=json.dumps(payload, separators=(',', ':')))
    db.add(event)
    await db.flush()
    db.info.setdefault('secret_wake', set()).add(chat_id)
    return event.id


async def _existing(db, chat_id, user_id, client_id, payload):
    digest = hashlib.sha256(json.dumps(payload, sort_keys=True,
                            separators=(',', ':')).encode()).hexdigest()
    old = await db.get(SecretOperation, (chat_id, user_id, client_id))
    if old:
        if old.request_hash != digest:
            raise ValueError('SECRET_ID_REUSED_WITH_DIFFERENT_CONTENT')
        return digest, json.loads(old.response_json)
    # Reserve the id BEFORE touching uploads or counters. The unique constraint
    # serializes competing retries even across workers. A losing transaction
    # rolls back and the client retries the same immutable request.
    db.add(SecretOperation(chat_id=chat_id, sender_id=user_id, client_id=client_id,
                          request_hash=digest, response_json='null'))
    await db.flush()
    return digest, None


async def _remember(db, chat_id, user_id, client_id, digest, response):
    operation = await db.get(SecretOperation, (chat_id, user_id, client_id))
    operation.response_json = json.dumps(response)
    await db.flush()


def _valid_control(control, chat):
    if not isinstance(control, dict) or len(json.dumps(control)) > 8192:
        raise ValueError('SECRET_INVALID_CONTROL')
    required = {'v', 'kind', 'session_id', 'chat_id', 'from_key', 'to_key', 'dh', 'ed', 'sig'}
    if set(control) != required or control['v'] != PROTOCOL_VERSION:
        raise ValueError('SECRET_INVALID_CONTROL')
    if control['kind'] not in ('init', 'ack', 'reset') or control['chat_id'] != chat.id:
        raise ValueError('SECRET_INVALID_CONTROL')
    _uuid(control['session_id'])
    for field, length in (('from_key', 32), ('to_key', 32), ('dh', 32), ('ed', 32), ('sig', 64)):
        try:
            if len(base64.b64decode(control[field], validate=True)) != length:
                raise ValueError()
        except (ValueError, TypeError):
            raise ValueError('SECRET_INVALID_CONTROL') from None


async def handle_secret_control(payload, db, user, session):
    chat_id = int(payload.get('chat_id', 0))
    chat = await require_bound_device(db, chat_id, user, session)
    await require_protocol(db, chat, user, session)
    client_id = _uuid(payload.get('client_operation_id'))
    control = payload.get('control')
    _valid_control(control, chat)
    peer_key = chat.user2_public_key if chat.user1_id == user.id else chat.user1_public_key
    if control['from_key'] != session.public_key or control['to_key'] != peer_key:
        raise ValueError('SECRET_DEVICE_MISMATCH')
    digest, existing = await _existing(db, chat_id, user.id, client_id, payload)
    if existing is not None:
        return existing
    event_id = await _append_event(db, chat_id, user.id, client_id, 'control', control)
    result = {'event_id': event_id, 'client_operation_id': client_id}
    await _remember(db, chat_id, user.id, client_id, digest, result)
    return result


async def handle_secret_sync(payload, db, user, session):
    chat_id = int(payload.get('chat_id', 0))
    chat = await require_bound_device(db, chat_id, user, session)
    # Import readable old wire formats without turning old HELO envelopes into
    # visible messages or requiring the ordinary history cache to retain them.
    from app.services.utils import serialise_message
    from app.ws.handlers.chat_handler import _secret_handshake_ok
    legacy = await db.get(SecretLegacyCursor, chat_id)
    if legacy is None:
        legacy = SecretLegacyCursor(chat_id=chat_id, message_id=0)
        db.add(legacy)
        await db.flush()
    old_messages = (await db.scalars(select(Message).where(
        Message.chat_id == chat_id, Message.id > legacy.message_id,
        Message.client_message_id.is_(None)).order_by(Message.id).limit(200))).all()
    for old in old_messages:
        data = await serialise_message(old, db)
        legacy.message_id = old.id
        if _secret_handshake_ok(data.get('content', '')):
            continue
        await _append_event(db, chat_id, old.sender_id, f'legacy:{old.id}', 'message', data)
    after = max(0, int(payload.get('after_event_id', 0)))
    limit = min(200, max(1, int(payload.get('limit', 100))))
    peer_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
    peer_key = chat.user2_public_key if chat.user1_id == user.id else chat.user1_public_key
    capability = await db.get(SecretDeviceCapability, (peer_id, peer_key))
    rows = (await db.scalars(select(SecretEvent).where(
        SecretEvent.chat_id == chat_id, SecretEvent.id > after)
        .order_by(SecretEvent.id).limit(limit + 1))).all()
    events = []
    for row in rows[:limit]:
        data = json.loads(row.payload_json)
        if row.kind in ('message', 'edit'):
            # Tombstones prevent replay of deleted/expired history on reinstall.
            message = await db.get(Message, data.get('id', 0))
            expires = message.expires_at if message else None
            if (message is None or message.is_deleted or
                (expires is not None and expires.replace(tzinfo=timezone.utc) <= datetime.now(timezone.utc))):
                data = {'id': data.get('id'), 'chat_id': chat_id, 'sender_id': data.get('sender_id'),
                        'client_message_id': data.get('client_message_id'), 'is_deleted': True,
                        'discard_e2ee_content': data.get('e2ee_content')}
        events.append({'event_id': row.id, 'sender_id': row.sender_id,
                       'kind': row.kind, 'payload': data})
    return {'events': events, 'has_more': len(rows) > limit,
            'cursor': events[-1]['event_id'] if events else after,
            'secret_protocol_version': PROTOCOL_VERSION,
            'peer_protocol_version': capability.protocol_version if capability else 0,
            'peer_public_key': peer_key}


async def handle_secret_mutation(action, payload, db, user, session):
    from app.ws.handlers.chat_handler import _can_send
    from app.services.utils import serialise_message, increment_unread
    from app.services.profile_svc import blocked_between, privacy_allows
    from app.models.models import MediaUploadChunk
    from app.services.encryption import encrypt_file
    from app.config import settings

    chat_id = int(payload.get('chat_id', 0))
    chat = await require_bound_device(db, chat_id, user, session)
    client_id = _uuid(payload.get('client_message_id') if action == 'send_message'
                      else payload.get('client_operation_id'))
    digest, existing = await _existing(db, chat_id, user.id, client_id, {'action': action, **payload})
    if existing is not None:
        return existing
    await require_protocol(db, chat, user, session)
    await _can_send(db, chat_id, user.id)
    peer_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
    if await blocked_between(db, user.id, peer_id) or not await privacy_allows(db, peer_id, user.id, 'messages'):
        raise ValueError('SECRET_RECIPIENT_RESTRICTED')
    if payload.get('content') or payload.get('reply_markup') or payload.get('blob_id'):
        raise ValueError('SECRET_CIPHERTEXT_REQUIRED')

    if action == 'delete_message':
        msg = await db.get(Message, int(payload.get('message_id', 0)))
        if not msg or msg.chat_id != chat_id or msg.sender_id != user.id:
            raise ValueError('SECRET_MESSAGE_UNAVAILABLE')
        msg.is_deleted = True
        msg.e2ee_content = None
        msg.encrypted_content = None
        result = {'id': msg.id, 'chat_id': chat_id, 'is_deleted': True}
        kind = 'delete'
    else:
        ciphertext = payload.get('e2ee_content')
        if not isinstance(ciphertext, str) or not ciphertext or len(ciphertext) > 2_000_000:
            raise ValueError('SECRET_CIPHERTEXT_REQUIRED')
        if action == 'send_message':
            reply_id = payload.get('reply_to_id')
            if reply_id:
                reply = await db.get(Message, int(reply_id))
                if not reply or reply.chat_id != chat_id:
                    raise ValueError('SECRET_INVALID_REPLY')
            msg = Message(chat_id=chat_id, sender_id=user.id, msg_type=MessageType.TEXT,
                          reply_to_id=reply_id, client_message_id=client_id)
            if chat.auto_delete_seconds:
                msg.expires_at = datetime.now(timezone.utc) + timedelta(seconds=chat.auto_delete_seconds)
            upload_id = payload.get('upload_id')
            if upload_id:
                upload = await db.scalar(select(MediaUploadChunk).where(
                    MediaUploadChunk.upload_id == upload_id, MediaUploadChunk.user_id == user.id))
                if not upload or upload.received_chunks < upload.total_chunks:
                    raise ValueError('SECRET_UPLOAD_UNAVAILABLE')
                if upload.media_subtype in ('voice', 'circle') and not await privacy_allows(db, peer_id, user.id, 'voice_messages'):
                    raise ValueError('SECRET_RECIPIENT_RESTRICTED')
                # Keep the upload until COMMIT; a failed transaction is retryable.
                source = Path(upload.temp_path)
                output = str(source) + '.enc'
                meta = encrypt_file(str(source), output)
                msg.media_path = os.path.relpath(source, settings.UPLOAD_DIR).replace('\\', '/')
                msg.media_iv, msg.media_tag = meta['iv'], meta['tag']
                msg.media_name, msg.media_type = 'encrypted.bin', 'application/octet-stream'
                msg.media_size = os.path.getsize(output)
                msg.msg_type = {'voice': MessageType.VOICE, 'circle': MessageType.CIRCLE}.get(upload.media_subtype, MessageType.MEDIA)
                await db.delete(upload)
                db.info.setdefault('secret_cleanup', []).append(str(source))
            db.add(msg)
            kind = 'message'
        else:
            msg = await db.get(Message, int(payload.get('message_id', 0)))
            if not msg or msg.chat_id != chat_id or msg.sender_id != user.id or msg.is_deleted:
                raise ValueError('SECRET_MESSAGE_UNAVAILABLE')
            msg.edited_at = datetime.now(timezone.utc)
            kind = 'edit'
        msg.is_e2ee = True
        msg.e2ee_content = ciphertext
        msg.encrypted_content = None
        await db.flush()
        if kind == 'message':
            await increment_unread(db, chat_id, user.id, msg.id)
        result = await serialise_message(msg, db)
    result['client_operation_id'] = client_id
    result['secret_event_id'] = await _append_event(db, chat_id, user.id, client_id, kind, result)
    await _remember(db, chat_id, user.id, client_id, digest, result)
    if kind == 'message':
        db.info.setdefault('secret_messages', []).append((chat_id, user.id, result))
    return result


async def after_commit(db):
    """Best-effort wakeups. Durable secret_sync is authoritative after reconnect."""
    from app.ws.connection_manager import push_to_chat
    for chat_id in db.info.pop('secret_wake', set()):
        try:
            await push_to_chat(db, chat_id, {'action': 'secret_changed', 'payload': {'chat_id': chat_id}})
        except Exception:
            pass
    for chat_id, sender_id, message in db.info.pop('secret_messages', []):
        try:
            await push_to_chat(db, chat_id, {'action': 'new_message', 'payload': message},
                               exclude_user_id=sender_id)
        except Exception:
            pass
        try:
            import asyncio
            from app.models.models import UserFCMToken
            from app.ws.connection_manager import send_push_and_prune, is_user_online
            chat = await db.get(Chat, chat_id)
            peer_id = chat.user2_id if chat.user1_id == sender_id else chat.user1_id
            peer_key = chat.user2_public_key if chat.user1_id == sender_id else chat.user1_public_key
            member = await db.scalar(select(ChatMember).where(
                ChatMember.chat_id == chat_id, ChatMember.user_id == peer_id))
            if member and not member.is_muted and not is_user_online(peer_id):
                tokens = (await db.scalars(select(UserFCMToken.fcm_token).join(
                    Session, UserFCMToken.session_id == Session.id).where(
                    UserFCMToken.user_id == peer_id, Session.public_key == peer_key,
                    Session.is_active == True, Session.expires_at > datetime.now(timezone.utc)))).all()
                if tokens:
                    asyncio.create_task(send_push_and_prune(list(set(tokens)), 'NiosMess',
                        'New secret message', {'type': 'new_message', 'is_secret': 'true',
                        'chat_id': str(chat_id), 'message_id': str(message['id']),
                        'title': 'NiosMess', 'body': 'New secret message'}))
        except Exception:
            pass
    for path in db.info.pop('secret_cleanup', []):
        try:
            Path(path).unlink(missing_ok=True)
        except OSError:
            pass


async def guard_secret_access(payload, db, user, session):
    chat_id = payload.get('chat_id')
    if not chat_id:
        return
    chat = await db.get(Chat, int(chat_id))
    if chat is not None and chat.is_secret:
        await require_bound_device(db, chat.id, user, session)


async def record_secret_metadata(action, payload, result, db, user):
    if result.get('error'):
        return
    chat_id = payload.get('chat_id')
    chat = await db.get(Chat, chat_id) if chat_id else None
    if chat is None or not chat.is_secret:
        return
    if action == 'mark_read':
        await _append_event(db, chat_id, user.id, str(uuid4()), 'read', {'user_id': user.id})
    elif action == 'react':
        from app.services.utils import serialise_message
        message = await db.get(Message, payload.get('message_id'))
        if message:
            data = await serialise_message(message, db)
            await _append_event(db, chat_id, user.id, str(uuid4()), 'reaction', {
                'message_id': message.id, 'reactions': data['reactions']})


async def bind_fcm_session(payload, db, user, session):
    from app.models.models import UserFCMToken
    if session is None:
        return
    token = payload.get('fcm_token') or payload.get('token')
    row = await db.scalar(select(UserFCMToken).where(
        UserFCMToken.user_id == user.id, UserFCMToken.fcm_token == token))
    if row:
        row.session_id = session.id
        await db.flush()


async def require_protocol(db, chat, user, session):
    peer_id = chat.user2_id if chat.user1_id == user.id else chat.user1_id
    peer_key = chat.user2_public_key if chat.user1_id == user.id else chat.user1_public_key
    for uid, key in ((user.id, session.public_key), (peer_id, peer_key)):
        capability = await db.get(SecretDeviceCapability, (uid, key))
        if capability is None or capability.protocol_version != PROTOCOL_VERSION:
            raise ValueError('SECRET_PROTOCOL_UPGRADE_REQUIRED')


async def guard_legacy_secret_send(payload, db):
    chat_id = payload.get('chat_id')
    chat = await db.get(Chat, chat_id) if chat_id else None
    if chat is not None and chat.is_secret and not payload.get('client_message_id'):
        raise ValueError('SECRET_PROTOCOL_UPGRADE_REQUIRED')
