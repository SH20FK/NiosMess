"""Versioned device notification preferences; no plaintext secrets in payloads."""
import asyncio
import json
from datetime import datetime, timedelta, timezone


def preferences(payload):
    raw = payload.get('notification_preferences') or {}
    if not isinstance(raw, dict):
        raise ValueError('Invalid notification preferences')
    result = {key: raw.get(key) is not False for key in
              ('enabled', 'messages', 'calls', 'activity', 'preview', 'sound')}
    muted = raw.get('muted_chat_ids', [])
    if not isinstance(muted, list) or len(muted) > 10000:
        raise ValueError('Invalid muted chat list')
    result['muted_chat_ids'] = sorted({int(v) for v in muted if str(v).isdigit() and int(v) > 0})
    result['locale'] = 'ru' if str(raw.get('locale', '')).startswith('ru') else 'en'
    result['protocol'] = 2 if payload.get('notification_protocol') == 2 else 1
    return json.dumps(result, separators=(',', ':'))


def prepare_device_push(user_id, raw_preferences, title, body, data, now=None):
    """Return a per-account payload, or None for a disabled/expired event.

    Missing preferences retain legacy behavior. Call cancellation bypasses category
    switches so an already displayed notification can always be removed.
    """
    now = now or datetime.now(timezone.utc)
    try:
        options = json.loads(raw_preferences or '{}')
    except (TypeError, ValueError):
        options = {}
    if not isinstance(options, dict):
        options = {}
    data = dict(data)
    kind = data.get('type', 'new_message')
    call = kind == 'incoming_call'
    cancel = kind in ('call_ended', 'chat_read')
    category = 'calls' if call else 'messages' if data.get('chat_id') else 'activity'
    if not cancel and (options.get('enabled') is False or options.get(category) is False or
        str(data.get('chat_id')) in {str(v) for v in options.get('muted_chat_ids', [])}):
        return None
    ru = options.get('locale') == 'ru'
    if call or kind == 'call_ended':
        data.setdefault('event_id', f"call:{data.get('room_id')}:{kind}")
        data.setdefault('expires_at', (now + timedelta(seconds=60)).isoformat())
        if call:
            body = ('Входящий видеозвонок' if ru else 'Incoming video call') if str(data.get('is_video')).lower() == 'true' else ('Входящий звонок' if ru else 'Incoming call')
    elif kind == 'chat_read':
        data.setdefault('event_id', f"read:{data.get('chat_id')}:{user_id}:{now.isoformat()}")
    else:
        data.setdefault('event_id', f"message:{data.get('chat_id')}:{data.get('message_id')}")
        if data.get('is_secret') == 'true':
            body = 'Зашифрованное сообщение' if ru else 'Encrypted message'
        elif options.get('preview') is False:
            body = 'Новое сообщение' if ru else 'New message'
        elif kind in ('post_like', 'post_comment'):
            actor = data.get('actor_name', 'NiosGram')
            action = ('оценил вашу публикацию' if ru else 'liked your post') if kind == 'post_like' else ('прокомментировал вашу публикацию' if ru else 'commented on your post')
            body = f'{actor} {action}'
    if data.get('expires_at'):
        expiry = datetime.fromisoformat(data['expires_at'].replace('Z', '+00:00'))
        if expiry <= now:
            return None
    data.update(account_id=str(user_id), title=title, body=body,
                locale=options.get('locale', 'en'),
                notification_protocol=str(options.get('protocol', 1)),
                notification_sound='false' if options.get('sound') is False else 'true')
    data.setdefault('created_at', now.isoformat())
    return title, body, data


def queue_push(db, tokens, title, body, data):
    # The router commits before draining this queue. Rollback clears db.info.
    db.info.setdefault('notification_pushes', []).append((list(tokens), title, body, dict(data)))


async def flush_notification_pushes(db):
    from app.ws.connection_manager import send_push_and_prune
    from app.ws.connection_manager import _push_to_user
    for user_id, data in db.info.pop('notification_activity', []):
        try:
            await _push_to_user(db, user_id, {'action': 'notification', 'payload': data})
        except Exception:
            import logging
            logging.getLogger('niosmess.push').warning('ACTIVITY_SOCKET_UNAVAILABLE')
    jobs = db.info.pop('notification_pushes', [])
    for tokens, title, body, data in jobs:
        asyncio.create_task(send_push_and_prune(tokens, title, body, data))


async def queue_activity(db, post, actor, kind, event_id):
    if post.author_id == actor.id:
        return
    from sqlalchemy import select
    from app.models.models import UserFCMToken
    data = {'event_id': event_id, 'type': kind, 'account_id': post.author_id,
            'title': 'NiosGram', 'body': actor.display_name,
            'actor_name': actor.display_name,
            'route': f'/niosgram/post/{post.id}/comments',
            'created_at': datetime.now(timezone.utc).isoformat()}
    db.info.setdefault('notification_activity', []).append((post.author_id, data))
    tokens = (await db.scalars(select(UserFCMToken.fcm_token).where(UserFCMToken.user_id == post.author_id))).all()
    queue_push(db, tokens, 'NiosGram', actor.display_name, data)


async def queue_call_cancellation(db, chat_id, room_id):
    from sqlalchemy import select
    from app.models.models import ChatMember, UserFCMToken
    tokens = (await db.scalars(select(UserFCMToken.fcm_token).join(
        ChatMember, ChatMember.user_id == UserFCMToken.user_id).where(
        ChatMember.chat_id == chat_id, ChatMember.is_banned == False))).all()
    if tokens:
        queue_push(db, set(tokens), 'NiosMess', '', {
            'type': 'call_ended', 'room_id': room_id, 'chat_id': str(chat_id)})
